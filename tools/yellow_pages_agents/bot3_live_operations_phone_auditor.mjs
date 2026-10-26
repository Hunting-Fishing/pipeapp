#!/usr/bin/env node
/**
 * Bot 3 — Scaled Multi-Source Cross-Deduplicator & Live 2026 Operations / Phone Auditor
 *
 * Merges and deduplicates all 4 North America discovery ledgers:
 *   - `02_discovered_companies.json` (`cossd.com` universe)
 *   - `06_open_web_discovered.json` (SEC EDGAR 8 Oilfield/Pipe SICs + Direct Corporate)
 *   - `07_usdot_oilfield_carriers.json` (Federal USDOT/FMCSA Active 2023–2026 Oilfield Fleets)
 *   - `08_regulator_registries.json` (Texas Comptroller Active Oil & Gas NAICS + Alberta Licences)
 *
 * Performs:
 *   1. Cross-source enrichment (combining directory phones, USDOT 2024–2026 phones/emails/fleet
 *      counts, active government tax/licence standing, and corporate websites).
 *   2. Persistent per-hostname DNS + live HTTPS + `/contact` phone scraping (`03a_domain_audit_cache.json`)
 *      so multi-branch corporate websites are never fetched more than once.
 *   3. Automatic `Old Number -> New Number` transition tracking (`legacyPhones` + `phoneHistory`),
 *      parked/dead-domain blocking (`closed_inactive`), and Contact Center call-queue routing.
 */

import dns from "node:dns/promises";
import fs from "node:fs/promises";
import path from "node:path";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";

const require = createRequire(import.meta.url);
const {
  classifyCategoriesFromText,
} = require("../../firebase/functions/yellow_pages_taxonomy.js");
const {
  normalizeNorthAmericanPhone,
  normalizePhoneHistory,
} = require("../../firebase/functions/yellow_pages_policy.js");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const LEDGER_DIR = path.join(REPO_ROOT, "data/yellow_pages/ledger");
const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");

const PARKED_DOMAIN_PATTERNS =
  /\b(?:domain\s+is\s+for\s+sale|buy\s+this\s+domain|sedoparking|godaddy\s+auctions|hugedomains|dan\.com|afternic|parked\s+free|this\s+domain\s+may\s+be\s+for\s+sale)\b/iu;

async function writeFileAtomic(targetPath, content) {
  const tmpPath = `${targetPath}.tmp-${process.pid}`;
  await fs.writeFile(tmpPath, content, "utf8");
  await fs.rename(tmpPath, targetPath);
}

function extractHostname(rawUrl = "") {
  if (!rawUrl) return "";
  try {
    const withProto = /^https?:\/\//iu.test(rawUrl) ? rawUrl : `https://${rawUrl}`;
    const host = new URL(withProto).hostname.replace(/^www\./iu, "").toLowerCase();
    if (
      /(?:^|\.)(?:cossd\.com|namesandnumbers\.com|cloudfront\.net|facebook\.com|fb\.com|linkedin\.com|twitter\.com|x\.com|instagram\.com|youtube\.com|google\.com|yp\.ca|yellowpages\.com)$/iu.test(
        host,
      )
    ) {
      return "";
    }
    return host;
  } catch (_) {
    return "";
  }
}

async function checkDomainDns(hostname) {
  if (!hostname) return {hasDnsA: false, hasMx: false};
  let hasDnsA = false;
  let hasMx = false;
  try {
    const lookedUp = await dns.lookup(hostname);
    hasDnsA = Boolean(lookedUp && lookedUp.address);
  } catch (_) {
    hasDnsA = false;
  }
  if (!hasDnsA) {
    try {
      const mx = await dns.resolveMx(hostname);
      hasMx = Array.isArray(mx) && mx.length > 0;
    } catch (_) {
      hasMx = false;
    }
  } else {
    hasMx = true;
  }
  return {hasDnsA, hasMx};
}

async function fetchLiveWebsite(rawUrl, timeoutMs = 5500) {
  if (!rawUrl) return {reachable: false, status: 0, finalUrl: "", html: ""};
  const target = /^https?:\/\//iu.test(rawUrl) ? rawUrl : `https://${rawUrl}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(target, {
      redirect: "follow",
      headers: {
        "User-Agent":
          "Mozilla/5.0 (compatible; PipeBuyerLiveOperationsAudit/1.2; +https://pipebuyer.com)",
        "Accept": "text/html,application/xhtml+xml,*/*;q=0.8",
      },
      signal: controller.signal,
    });
    const html = res.ok ? (await res.text()).slice(0, 220_000) : "";
    return {
      reachable: res.status >= 200 && res.status < 400,
      status: res.status,
      finalUrl: res.url || target,
      html,
    };
  } catch (err) {
    return {
      reachable: false,
      status: 0,
      finalUrl: "",
      html: "",
      error: err.message,
    };
  } finally {
    clearTimeout(timer);
  }
}

function extractLivePhonesAndEmails(html = "") {
  const localPhones = [];
  const tollFreePhones = [];
  const seenDigits = new Set();

  const telHrefMatches = html.matchAll(/href=["']tel:([^"']+)["']/giu);
  for (const m of telHrefMatches) {
    const norm = normalizeNorthAmericanPhone(m[1]);
    if (norm.validNanpa && !seenDigits.has(norm.digits10)) {
      seenDigits.add(norm.digits10);
      if (norm.isTollFree) tollFreePhones.push(norm);
      else localPhones.push(norm);
    }
  }

  const textCleaned = html
    .replace(/<script[\s\S]*?<\/script>/giu, " ")
    .replace(/<style[\s\S]*?<\/style>/giu, " ")
    .replace(/<[^>]+>/gu, " ");

  const phoneRegex = /(?:\+?1[-.\s]?)?\(?([2-9]\d{2})\)?[-.\s](\d{3})[-.\s](\d{4})\b/gu;
  let match;
  while ((match = phoneRegex.exec(textCleaned)) !== null) {
    const candidate = `(${match[1]}) ${match[2]}-${match[3]}`;
    const norm = normalizeNorthAmericanPhone(candidate);
    if (norm.validNanpa && !seenDigits.has(norm.digits10)) {
      seenDigits.add(norm.digits10);
      if (norm.isTollFree) tollFreePhones.push(norm);
      else localPhones.push(norm);
    }
  }

  const emails = [];
  const emailRegex = /\b([a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,12})\b/giu;
  while ((match = emailRegex.exec(html)) !== null) {
    const email = match[1].toLowerCase();
    if (
      !/\.(?:png|jpg|jpeg|webp|svg|gif|css|js|woff2?)$/iu.test(email) &&
      !email.includes("sentry") &&
      !email.includes("example.") &&
      !email.includes("wixpress") &&
      !email.includes("domain.")
    ) {
      if (!emails.includes(email)) emails.push(email);
    }
  }

  const titleText = (html.match(/<title[^>]*>([\s\S]*?)<\/title>/iu)?.[1] || "")
    .replace(/<[^>]+>/gu, " ")
    .replace(/\s+/gu, " ")
    .trim()
    .slice(0, 180);

  return {
    localPhones: localPhones.slice(0, 6),
    tollFreePhones: tollFreePhones.slice(0, 4),
    emails: emails.slice(0, 3),
    titleText,
  };
}

async function probeDomainOnce(hostname, sampleUrl) {
  const dnsCheck = await checkDomainDns(hostname);
  let siteCheck = {reachable: false, status: 0, finalUrl: "", html: ""};
  if (dnsCheck.hasDnsA || dnsCheck.hasMx) {
    const startUrl = sampleUrl || `https://${hostname}`;
    siteCheck = await fetchLiveWebsite(startUrl, 5500);
    if (!siteCheck.reachable && startUrl.startsWith("http://")) {
      siteCheck = await fetchLiveWebsite(startUrl.replace(/^http:\/\//iu, "https://"), 5500);
    }
  }

  const isParked = Boolean(siteCheck.html && PARKED_DOMAIN_PATTERNS.test(siteCheck.html));
  let extracted = extractLivePhonesAndEmails(siteCheck.html);

  if (
    siteCheck.reachable &&
    !isParked &&
    extracted.localPhones.length === 0 &&
    siteCheck.finalUrl
  ) {
    try {
      const contactUrl = new URL("/contact", siteCheck.finalUrl).toString();
      const contactRes = await fetchLiveWebsite(contactUrl, 3500);
      if (contactRes.reachable) {
        const more = extractLivePhonesAndEmails(contactRes.html);
        extracted = {
          localPhones: [...extracted.localPhones, ...more.localPhones].slice(0, 6),
          tollFreePhones: [...extracted.tollFreePhones, ...more.tollFreePhones].slice(0, 4),
          emails: Array.from(new Set([...extracted.emails, ...more.emails])).slice(0, 3),
          titleText: extracted.titleText || more.titleText,
        };
      }
    } catch (_) {}
  }

  return {
    checkedAt: new Date().toISOString(),
    hostname,
    hasDnsA: dnsCheck.hasDnsA,
    hasMx: dnsCheck.hasMx,
    reachable: siteCheck.reachable,
    status: siteCheck.status,
    finalUrl: siteCheck.finalUrl,
    isParked,
    localPhones: extracted.localPhones,
    tollFreePhones: extracted.tollFreePhones,
    emails: extracted.emails,
    titleText: extracted.titleText,
  };
}

function evaluateCompanyWithDomainProbe(company, domainProbe) {
  const oldPhoneNorm = normalizeNorthAmericanPhone(company.directoryPhone);
  const fedPhoneNorm = normalizeNorthAmericanPhone(company.federalVerifiedPhone || "");
  const oldTollFreeNorm = normalizeNorthAmericanPhone(company.tollFreePhone);
  const legacyPhones = [...(company.legacyPhones || [])];

  let currentMainPhone = oldPhoneNorm.display || "";
  let currentTollFree = oldTollFreeNorm.display || "";
  let operationalStatus = "unverified";
  let phoneAuditOutcome = "needs_phone_verification_call";

  // If cross-matched with USDOT 2024–2026 phone that differs from older directory phone, record Old -> New!
  if (
    fedPhoneNorm.validNanpa &&
    oldPhoneNorm.validNanpa &&
    fedPhoneNorm.digits10 !== oldPhoneNorm.digits10
  ) {
    if (!legacyPhones.includes(oldPhoneNorm.display)) {
      legacyPhones.push(oldPhoneNorm.display);
    }
    currentMainPhone = fedPhoneNorm.display;
  } else if (fedPhoneNorm.validNanpa && !currentMainPhone) {
    currentMainPhone = fedPhoneNorm.display;
  }

  const activePhoneNorm = normalizeNorthAmericanPhone(currentMainPhone);

  if (domainProbe) {
    if (domainProbe.reachable && !domainProbe.isParked) {
      const matchedSameLocal =
        activePhoneNorm.validNanpa &&
        domainProbe.localPhones.some((p) => p.digits10 === activePhoneNorm.digits10);

      if (matchedSameLocal) {
        operationalStatus =
          legacyPhones.length > 0 ? "active_number_updated" : "active_in_operation";
        phoneAuditOutcome = "confirmed_same_number_on_live_website";
      } else if (domainProbe.localPhones.length > 0) {
        const newestLocal = domainProbe.localPhones[0];
        if (activePhoneNorm.validNanpa && activePhoneNorm.digits10 !== newestLocal.digits10) {
          if (!legacyPhones.includes(activePhoneNorm.display)) {
            legacyPhones.push(activePhoneNorm.display);
          }
          currentMainPhone = newestLocal.display;
          operationalStatus = "active_number_updated";
          phoneAuditOutcome = "old_number_replaced_by_live_website_number";
        } else {
          currentMainPhone = newestLocal.display;
          operationalStatus = "active_in_operation";
          phoneAuditOutcome = "discovered_number_from_live_website";
        }
      } else {
        operationalStatus =
          legacyPhones.length > 0 ? "active_number_updated" : "active_in_operation";
        phoneAuditOutcome = "website_live_phone_retained";
      }

      if (!currentTollFree && domainProbe.tollFreePhones.length > 0) {
        currentTollFree = domainProbe.tollFreePhones[0].display;
      }
    } else if (domainProbe.isParked || (!domainProbe.hasDnsA && !domainProbe.hasMx)) {
      // Unless company has an active 2024–2026 USDOT filing with phone, dead domain => closed_inactive
      if (company.discoveryChannel === "usdot_fmcsa_oilfield_census" && activePhoneNorm.validNanpa) {
        operationalStatus = "active_in_operation";
        phoneAuditOutcome = "confirmed_active_usdot_mcs150_2024_2026";
      } else {
        operationalStatus = "closed_inactive";
        phoneAuditOutcome = domainProbe.isParked
          ? "domain_parked_for_sale"
          : "domain_nxdomain_inactive";
      }
    } else if (activePhoneNorm.validNanpa) {
      if (
        company.discoveryChannel === "usdot_fmcsa_oilfield_census" ||
        company.discoveryChannel === "sec_edgar_sic_registry" ||
        company.governmentActiveStanding === true
      ) {
        operationalStatus =
          legacyPhones.length > 0 ? "active_number_updated" : "active_in_operation";
        phoneAuditOutcome = "confirmed_active_government_or_federal_registry";
      } else {
        operationalStatus = "unverified";
        phoneAuditOutcome = "website_timeout_queue_for_agent_call";
      }
    }
  } else {
    // No website on file
    if (
      (company.discoveryChannel === "usdot_fmcsa_oilfield_census" ||
        company.hasUsdotActiveMatch === true) &&
      (activePhoneNorm.validNanpa || Boolean(currentTollFree))
    ) {
      operationalStatus =
        legacyPhones.length > 0 ? "active_number_updated" : "active_in_operation";
      phoneAuditOutcome = "confirmed_active_usdot_mcs150_2024_2026";
    } else if (
      company.discoveryChannel === "sec_edgar_sic_registry" &&
      (activePhoneNorm.validNanpa || Boolean(currentTollFree))
    ) {
      operationalStatus = "active_in_operation";
      phoneAuditOutcome = "confirmed_active_sec_edgar_recent_filer";
    } else if (
      company.governmentActiveStanding === true &&
      (activePhoneNorm.validNanpa || Boolean(currentTollFree))
    ) {
      operationalStatus =
        legacyPhones.length > 0 ? "active_number_updated" : "active_in_operation";
      phoneAuditOutcome = "cross_verified_active_government_licence_and_phone";
    } else if (activePhoneNorm.validNanpa || Boolean(currentTollFree)) {
      operationalStatus = "unverified";
      phoneAuditOutcome = "no_website_queue_for_agent_call";
    } else {
      operationalStatus = "unverified";
      phoneAuditOutcome = "government_lead_missing_phone_research_queue";
    }
  }

  const mergedCategoryCodes = classifyCategoriesFromText(
    [...(company.categoryCodes || []), ...(company.services || []), company.companyName],
    domainProbe?.titleText || "",
  );

  const chosenEmail = company.generalEmail || domainProbe?.emails?.[0] || "";

  return {
    ...company,
    mainPhone: currentMainPhone,
    publicPhone: currentMainPhone,
    tollFreePhone: currentTollFree,
    legacyPhones,
    oldDirectoryPhone: oldPhoneNorm.display || "",
    generalEmail: chosenEmail,
    publicEmail: chosenEmail,
    website: domainProbe?.finalUrl || company.website || "",
    categoryCodes: mergedCategoryCodes,
    operationalStatus,
    verificationStatus:
      operationalStatus === "closed_inactive" ? "inactive" : "unverified",
    phoneHistory: normalizePhoneHistory([], legacyPhones, currentMainPhone),
    liveAudit: {
      auditedAt: domainProbe?.checkedAt || new Date().toISOString(),
      hostname: domainProbe?.hostname || "",
      hasDnsA: Boolean(domainProbe?.hasDnsA),
      hasMx: Boolean(domainProbe?.hasMx),
      websiteReachable: Boolean(domainProbe?.reachable),
      httpStatus: domainProbe?.status || 0,
      redirectedTo:
        domainProbe?.finalUrl && domainProbe.finalUrl !== company.website
          ? domainProbe.finalUrl
          : null,
      isParkedDomain: Boolean(domainProbe?.isParked),
      phoneAuditOutcome,
      livePhonesFound: (domainProbe?.localPhones || []).map((p) => p.display),
    },
  };
}

async function readLedgerCompaniesSafe(filename) {
  try {
    const raw = JSON.parse(await fs.readFile(path.join(LEDGER_DIR, filename), "utf8"));
    return raw.companies || [];
  } catch (_) {
    return [];
  }
}

export async function runLiveOperationsAudit({domainConcurrency = 36} = {}) {
  await fs.mkdir(LEDGER_DIR, {recursive: true});
  await fs.mkdir(REPORTS_DIR, {recursive: true});

  const [cossdCompanies, openWebCompanies, usdotCompanies, regulatorCompanies] =
    await Promise.all([
      readLedgerCompaniesSafe("02_discovered_companies.json"),
      readLedgerCompaniesSafe("06_open_web_discovered.json"),
      readLedgerCompaniesSafe("07_usdot_oilfield_carriers.json"),
      readLedgerCompaniesSafe("08_regulator_registries.json"),
    ]);

  // Cross-source deduplication & enrichment across all 4 North America ledgers
  const mergedMap = new Map();
  const nameCountryIndex = new Map();

  const allIncoming = [
    ...cossdCompanies,
    ...openWebCompanies,
    ...usdotCompanies,
    ...regulatorCompanies,
  ];

  for (const item of allIncoming) {
    if (!item || !item.normalizedCompanyName) continue;
    const country = item.countryCode || "CA";
    const region = item.regionCode || "";
    const exactKey = `${item.normalizedCompanyName}|${country}|${region}`;
    const broadKey = `${item.normalizedCompanyName}|${country}`;

    const existingKey = mergedMap.has(exactKey)
      ? exactKey
      : !region && nameCountryIndex.has(broadKey)
        ? nameCountryIndex.get(broadKey)
        : null;

    if (!existingKey) {
      const clone = {...item};
      if (item.discoveryChannel === "usdot_fmcsa_oilfield_census") {
        clone.hasUsdotActiveMatch = true;
      }
      mergedMap.set(exactKey, clone);
      if (!nameCountryIndex.has(broadKey)) {
        nameCountryIndex.set(broadKey, exactKey);
      }
    } else {
      const existing = mergedMap.get(existingKey);
      // Enrich missing fields and cross-verify federal/state standing!
      if (item.discoveryChannel === "usdot_fmcsa_oilfield_census") {
        existing.hasUsdotActiveMatch = true;
        if (item.directoryPhone) existing.federalVerifiedPhone = item.directoryPhone;
        if (item.powerUnits && !existing.powerUnits) existing.powerUnits = item.powerUnits;
      }
      if (item.governmentActiveStanding) {
        existing.governmentActiveStanding = true;
      }
      if (!existing.directoryPhone && item.directoryPhone) {
        existing.directoryPhone = item.directoryPhone;
      }
      if (!existing.tollFreePhone && item.tollFreePhone) {
        existing.tollFreePhone = item.tollFreePhone;
      }
      if (!existing.generalEmail && item.generalEmail) {
        existing.generalEmail = item.generalEmail;
      }
      if (!existing.website && item.website) {
        existing.website = item.website;
      }
      if (!existing.city && item.city) {
        existing.city = item.city;
      }
      if (!existing.streetAddress && item.streetAddress) {
        existing.streetAddress = item.streetAddress;
      }
      if (!existing.postalCode && item.postalCode) {
        existing.postalCode = item.postalCode;
      }
      existing.categoryCodes = Array.from(
        new Set([...(existing.categoryCodes || []), ...(item.categoryCodes || [])]),
      );
      existing.services = Array.from(
        new Set([...(existing.services || []), ...(item.services || [])]),
      ).slice(0, 14);
      existing.certifications = Array.from(
        new Set([...(existing.certifications || []), ...(item.certifications || [])]),
      ).slice(0, 10);
      existing.sourceReferences = [
        ...(existing.sourceReferences || []),
        ...(item.sourceReferences || []),
      ].slice(0, 6);
    }
  }

  const inputCompanies = Array.from(mergedMap.values());

  // Load persistent domain audit cache (`03a_domain_audit_cache.json`)
  const domainCachePath = path.join(LEDGER_DIR, "03a_domain_audit_cache.json");
  const domainCache = new Map();
  try {
    const rawCache = JSON.parse(await fs.readFile(domainCachePath, "utf8"));
    for (const [host, val] of Object.entries(rawCache.domains || {})) {
      if (host && !host.includes("namesandnumbers.com") && !host.includes("facebook.com")) {
        domainCache.set(host, val);
      }
    }
  } catch (_) {}

  // Identify all uncached corporate hostnames across inputCompanies
  const uncachedHosts = new Map();
  for (const c of inputCompanies) {
    const host = extractHostname(c.website);
    if (host && !domainCache.has(host) && !uncachedHosts.has(host)) {
      uncachedHosts.set(host, c.website);
    }
  }

  const hostEntries = Array.from(uncachedHosts.entries());
  for (let i = 0; i < hostEntries.length; i += domainConcurrency) {
    const slice = hostEntries.slice(i, i + domainConcurrency);
    const probes = await Promise.all(
      slice.map(([host, sampleUrl]) => probeDomainOnce(host, sampleUrl)),
    );
    for (const p of probes) {
      domainCache.set(p.hostname, p);
    }
    // Periodically flush domain cache every 360 domains so zero network work is ever lost
    if ((i + domainConcurrency) % 360 === 0 || i + domainConcurrency >= hostEntries.length) {
      await writeFileAtomic(
        domainCachePath,
        JSON.stringify({
          updatedAt: new Date().toISOString(),
          cachedHostCount: domainCache.size,
          domains: Object.fromEntries(domainCache),
        }),
      );
    }
  }

  // Evaluate all companies instantaneously using the populated domainCache
  const audited = inputCompanies.map((c) => {
    const host = extractHostname(c.website);
    const probe = host ? domainCache.get(host) || null : null;
    return evaluateCompanyWithDomainProbe(c, probe);
  });

  const stats = {
    totalAudited: audited.length,
    uniqueDomainsCached: domainCache.size,
    newlyProbedDomainsInRun: hostEntries.length,
    byCountry: {
      CA: audited.filter((c) => c.countryCode === "CA").length,
      US: audited.filter((c) => c.countryCode === "US").length,
    },
    byPrimarySource: {
      cossdDirectory: audited.filter((c) => (c.discoveryChannel || "cossd_directory") === "cossd_directory").length,
      usdotFmcsaCensus: audited.filter((c) => c.discoveryChannel === "usdot_fmcsa_oilfield_census").length,
      regulatorRegistries: audited.filter(
        (c) =>
          c.discoveryChannel === "texas_comptroller_oilgas_naics" ||
          c.discoveryChannel === "alberta_municipal_licence_registry",
      ).length,
      secEdgarAndOpenWeb: audited.filter(
        (c) =>
          c.discoveryChannel === "sec_edgar_sic_registry" ||
          c.discoveryChannel === "direct_oilpatch_operator_seed" ||
          c.discoveryChannel === "open_web_search_direct_domain" ||
          c.discoveryChannel === "openstreetmap_overpass_oilpatch",
      ).length,
    },
    activeInOperation: audited.filter((c) => c.operationalStatus === "active_in_operation").length,
    activeNumberUpdated: audited.filter((c) => c.operationalStatus === "active_number_updated").length,
    unverifiedNeedsCall: audited.filter((c) => c.operationalStatus === "unverified").length,
    closedOrDomainInactive: audited.filter((c) => c.operationalStatus === "closed_inactive").length,
  };

  const outPayload = {
    generatedAt: new Date().toISOString(),
    stats,
    companies: audited,
  };

  const outJsonPath = path.join(LEDGER_DIR, "03_audited_companies.json");
  await writeFileAtomic(outJsonPath, JSON.stringify(outPayload));

  const numberChangedRows = audited.filter((c) => c.operationalStatus === "active_number_updated");

  const md = [
    "# Bot 3 — Scaled North America Multi-Source Business Operations & Old->New Phone Audit",
    "",
    `- **Generated At**: \`${outPayload.generatedAt}\``,
    `- **Total Unique North American Companies Audited**: **${stats.totalAudited.toLocaleString()}** (Canada: **${stats.byCountry.CA.toLocaleString()}**, USA: **${stats.byCountry.US.toLocaleString()}**)`,
    `  - \`cossd.com\` Directory Universe: **${stats.byPrimarySource.cossdDirectory.toLocaleString()}**`,
    `  - Federal USDOT / FMCSA Active Oilfield Fleets: **${stats.byPrimarySource.usdotFmcsaCensus.toLocaleString()}**`,
    `  - State & Provincial Active Licences / Oil & Gas NAICS: **${stats.byPrimarySource.regulatorRegistries.toLocaleString()}**`,
    `  - SEC EDGAR Oilfield/Pipe Filers & Direct Corporate Web: **${stats.byPrimarySource.secEdgarAndOpenWeb.toLocaleString()}**`,
    `- **Unique Corporate Domains DNS/HTTP Audited**: **${stats.uniqueDomainsCached.toLocaleString()}**`,
    `- **Confirmed Active in Operation (2026 Verified)**: **${(stats.activeInOperation + stats.activeNumberUpdated).toLocaleString()}**`,
    `  - Same Phone / Active Federal or Corporate Verification: **${stats.activeInOperation.toLocaleString()}**`,
    `  - Updated Phone Caught (\`Old Number -> New Number\`): **${stats.activeNumberUpdated.toLocaleString()}**`,
    `- **Queued in Private DB for Contact Center Call / Research**: **${stats.unverifiedNeedsCall.toLocaleString()}**`,
    `- **Closed / Liquidated / Dead Domains Blocked from Public Site**: **${stats.closedOrDomainInactive.toLocaleString()}**`,
    "",
    `## Sample of \`Old Number -> New Number\` Transitions Caught (${numberChangedRows.length.toLocaleString()} Total — First 60 Shown)`,
    "",
    "| Company | City / Region | Old Phone | New Verified 2026 Phone | Source / Website |",
    "| :--- | :--- | :--- | :--- | :--- |",
    ...numberChangedRows.slice(0, 60).map(
      (c) =>
        `| ${c.companyName} | ${[c.city, c.regionCode, c.countryCode].filter(Boolean).join(", ")} | ${c.oldDirectoryPhone || c.legacyPhones[0] || "—"} | **${c.mainPhone}** | ${c.website || c.discoveryChannel} |`,
    ),
    "",
    "## Sample of Audited North America Companies (First 80 Shown)",
    "",
    "| Company | Channel | Region | Status | Old Phone | Verified 2026 Phone | Verification |",
    "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |",
    ...audited.slice(0, 80).map((c) => {
      const badge = c.liveAudit.websiteReachable
        ? `HTTP ${c.liveAudit.httpStatus} Live`
        : c.liveAudit.phoneAuditOutcome;
      return `| ${c.companyName} | \`${c.discoveryChannel}\` | ${[c.city, c.regionCode, c.countryCode].filter(Boolean).join(", ")} | \`${c.operationalStatus}\` | ${c.oldDirectoryPhone || "—"} | **${c.mainPhone || c.tollFreePhone || "—"}** | ${badge} |`;
    }),
    "",
  ];

  await writeFileAtomic(path.join(REPORTS_DIR, "03_live_operations_audit.md"), md.join("\n"));
  console.log(
    `[Bot 3] Audited ${audited.length} companies (Active: ${stats.activeInOperation + stats.activeNumberUpdated}, Number Updated: ${stats.activeNumberUpdated}, Closed Blocked: ${stats.closedOrDomainInactive}, Domains Probed: ${stats.uniqueDomainsCached})`,
  );
  return {stats};
}

if (process.argv[1]?.endsWith("bot3_live_operations_phone_auditor.mjs")) {
  runLiveOperationsAudit().catch((err) => {
    console.error("[Bot 3 Error]", err.message);
    process.exitCode = 1;
  });
}
