/**
 * Shared Global Oilfield Directory Live-Audit, Phone Extraction, Deduplication
 * & Firestore Batch Publisher Utilities (Used by Bot 9 & Bot 10)
 */

import {execSync} from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";

const require = createRequire(import.meta.url);
export const {
  GLOBAL_COUNTRIES_LIST,
  COUNTRY_BY_CODE,
  CATEGORY_BY_CODE,
  WORLD_CONTINENTS,
  inferCountryAndRegion,
  classifyCategoriesFromText,
  countryCodesForContinent,
} = require("../../firebase/functions/yellow_pages_taxonomy.js");

export const {
  normalizeGlobalPhone,
  normalizedCompanyName,
  buildPublicEntry,
  isPublicationEligible,
  buildAdminSearchTokens,
} = require("../../firebase/functions/yellow_pages_policy.js");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = path.resolve(__dirname, "../..");
export const LEDGER_DIR = path.join(REPO_ROOT, "data/yellow_pages/ledger");
export const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");

export const TIMESTAMP_KEYS = new Set(["createdAt", "updatedAt", "publishedAt", "paidThrough"]);
export const SANCTIONED_SKIP_CODES = new Set(["CU", "IR", "KP", "SY", "RU", "BY"]);
export const BASELINE_COMPLETED_CODES = new Set(["CA", "US"]);

export const BROWSER_USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36";
export const SEC_USER_AGENT = "PipeBuyerGlobalDirectoryAudit/1.0 (https://pipebuyer.com; admin@pipebuyer.com)";

export const AGGREGATOR_BLOCKLIST =
  /(?:cossd\.com|namesandnumbers\.com|yelp\.|yellowpages\.|yp\.ca|411\.|mapquest\.|manta\.|bbb\.org|linkedin\.|facebook\.|instagram\.|youtube\.|twitter\.|x\.com|tiktok\.|pinterest\.|indeed\.|glassdoor\.|ziprecruiter\.|wikipedia\.org|wikidata\.org|wikimedia\.org|britannica\.com|dnb\.com|zoominfo\.|rocketreach\.|lusha\.com|apollo\.io|pitchbook\.com|crunchbase\.com|bloomberg\.com|reuters\.com|yahoo\.com|msn\.com|bing\.com|microsoft\.com|google\.com|chamberofcommerce\.|thomasnet\.|reddit\.|sec\.gov|cybo\.|cylex|hotfrog\.|brownbook\.|tupalo\.|findglocal\.|kompass\.|rigzone\.com|offshore-technology\.com|oilandgasiq\.com|gulfoilandgas\.com|energyglobal\.com|oilprice\.com|worldoil\.com|hartenergy\.com|spglobal\.com|woodmac\.com|rystadenergy\.com|statista\.com|researchandmarkets\.com|mordorintelligence\.com|fortunebusinessinsights\.com|clutch\.co|goodfirms\.co|sortlist\.com|ensun\.io|tracxn\.com|owler\.com|cbinsights\.com|datanyze\.com|signalhire\.com|contactout\.com|gov\.uk|europa\.eu|trade\.gov)/iu;

export const OILFIELD_SIGNAL_RE =
  /\b(?:oilfield|oil\s*(?:&|and)\s*gas|petroleum|petrochemical|drilling|workover|octg|tubular|tubulars|casing|tubing|line\s*pipe|steel\s*pipe|pipeline|piping|wellhead|valve|valves|bop|pressure\s*control|subsea|offshore|onshore|wireline|slickline|coiled\s*tubing|cementing|completions|stimulation|rig\s*moving|heavy\s*haul|heavy\s*lift|crane|rigging|ndt|non-destructive|inspection|hydrotesting|hydrovac|vacuum\s*truck|mud|drilling\s*fluids|lubricant|bunkering|midstream|upstream|downstream|refinery|refining|terminal|storage\s*tank|pressure\s*vessel|fpso|fso|lng|lpg|epc|epci|fabrication|welding|machining|marine\s*services|vessel|supply\s*base|oil\s*tools|artificial\s*lift|compressor|compression|turbomachinery|pumps|scada|instrumentation|automation|geophysical|seismic|geotechnical|decommissioning|remediation|energy\s*services|industrial\s*services|fuel\s*supply|power\s*generation)\b/iu;

export const BAD_TITLE_RE =
  /^(?:just a moment|attention required|access denied|403\b|404\b|500\b|502\b|503\b|error|page not found|home|welcome|index of|contact(?:\s+us)?|about(?:\s+us)?|login|sign in|privacy policy|terms|directory|top \d+|best \d+|list of |category:|oil and gas companies|oilfield services in )/iu;

export const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Shield long-running crawlers from Node v22 undici TLSSocket parser assertions on malformed foreign servers
process.on("uncaughtException", (err) => {
  if (err?.code === "ERR_ASSERTION" || /paused|undici|socket|ECONNRESET|HPE_/iu.test(String(err?.stack || err))) {
    return;
  }
  console.warn("[Non-fatal Uncaught Error]", err?.message || err);
});
process.on("unhandledRejection", (err) => {
  console.warn("[Non-fatal Unhandled Rejection]", err?.message || err);
});

export async function fetchText(url, {headers = {}, timeoutMs = 8000, method = "GET", body} = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      method,
      headers,
      body,
      redirect: "follow",
      signal: controller.signal,
    });
    if (!res.ok) return {ok: false, status: res.status, text: "", finalUrl: res.url || url};
    const ctype = String(res.headers.get("content-type") || "").toLowerCase();
    if (ctype && !/(?:html|xml|json|text)/u.test(ctype)) {
      return {ok: false, status: res.status, text: "", finalUrl: res.url || url};
    }
    const text = await res.text();
    const isJson = ctype.includes("json");
    return {
      ok: true,
      status: res.status,
      text: isJson ? text : text.slice(0, 450_000),
      finalUrl: res.url || url,
    };
  } catch (err) {
    return {ok: false, status: 0, text: "", finalUrl: url, error: err.message};
  } finally {
    clearTimeout(timer);
  }
}

function cleanRawPhoneCandidate(raw) {
  let s = String(raw || "")
    .replace(/&nbsp;|&#160;/giu, " ")
    .replace(/[\u00A0\u2000-\u200B\u202F]/gu, " ")
    .trim();
  // Strip "(0)" trunk prefix commonly written inside international phones e.g. "+44 (0) 1224 851000"
  s = s.replace(/^(\+\s*\d{1,3})\s*\(\s*0\s*\)\s*/u, "$1 ");
  s = s.replace(/^(00\s*\d{1,3})\s*\(\s*0\s*\)\s*/u, "$1 ");
  // Trim trailing punctuation
  s = s.replace(/[.,;:|/\\]+$/gu, "").trim();
  return s;
}

function looksLikeDateOrBogusNumber(raw) {
  const trimmed = String(raw || "").trim();
  if (/^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}$/u.test(trimmed)) return true;
  if (/^(?:19|20)\d{2}\s*[-–—/]\s*(?:19|20)\d{2}$/u.test(trimmed)) return true;
  const digits = trimmed.replace(/\D+/gu, "");
  if (digits.length < 7 || digits.length > 15) return true;
  if (/^(\d)\1{6,}$/u.test(digits)) return true;
  if (/^(?:1234567|0000000)/u.test(digits)) return true;
  return false;
}

function websiteMatchesCountryTld(websiteOrigin = "", countryCode = "") {
  if (!websiteOrigin || !countryCode) return false;
  try {
    const host = new URL(websiteOrigin).hostname.toLowerCase();
    const cc = countryCode.toLowerCase();
    if (cc === "gb" && (host.endsWith(".uk") || host.endsWith(".scot"))) return true;
    return host.endsWith(`.${cc}`);
  } catch (_) {
    return false;
  }
}

export function extractPhonesFromHtml(html = "", countryCode = "US", dialCode = "+1", websiteOrigin = "") {
  if (!html) return [];
  const candidates = [];

  // 1. Explicit tel: hrefs (highest precision!)
  for (const m of html.matchAll(/href=["'](?:tel|callto):([^"'?#<>]+)["']/giu)) {
    const cleaned = cleanRawPhoneCandidate(decodeURIComponent(m[1]));
    if (cleaned) candidates.push({raw: cleaned, source: "tel_href"});
  }

  // 2. JSON-LD / Schema.org / inline JSON telephone fields BEFORE stripping <script>
  for (const m of html.matchAll(/"(?:telephone|phone|contactPhone|tel|phoneNumber)"\s*:\s*"([^"\\]{6,32})"/giu)) {
    const cleaned = cleanRawPhoneCandidate(m[1]);
    if (cleaned) candidates.push({raw: cleaned, source: "json_ld"});
  }

  // Strip scripts/styles/tags for visible text extraction
  const stripped = html
    .replace(/<script[\s\S]*?<\/script>/giu, " ")
    .replace(/<style[\s\S]*?<\/style>/giu, " ")
    .replace(/<svg[\s\S]*?<\/svg>/giu, " ")
    .replace(/<[^>]+>/gu, " ")
    .replace(/&nbsp;|&#160;/giu, " ")
    .replace(/\s+/gu, " ");

  const dialDigits = String(dialCode || "").replace(/\D+/gu, "");

  // 3. International +CC / 00CC phone numbers with 1 to 6 groups (fixes 8-digit SG/NO/DK/QA/KW/OM/BH/PA/CR numbers!)
  for (const m of stripped.matchAll(/(?:\+|00)\s*\d{1,3}(?:\s*\(\s*0\s*\))?(?:[\s().-]*\d{1,10}){1,6}/gu)) {
    const cleaned = cleanRawPhoneCandidate(m[0]);
    if (cleaned) candidates.push({raw: cleaned, source: "intl_plus"});
  }

  // 4. Labeled phone numbers in visible text ("Tel:", "Phone:", "Teléfono:", "Telefone:", "T:", "Ph:")
  for (const m of stripped.matchAll(
    /\b(?:tel(?:ephone|éfono|efone|efon)?|phone|ph|tél|call(?:\s+us)?|switchboard|office)\s*[.:#-]{0,3}\s*(\+?\(?\d[\d\s().-]{5,20}\d)/giu,
  )) {
    const cleaned = cleanRawPhoneCandidate(m[1]);
    if (cleaned) candidates.push({raw: cleaned, source: "labeled_text"});
  }

  // 5. NANPA domestic format for +1 countries, OR trunk-0 / parenthesized area-code domestic format
  const isCountryTld = websiteMatchesCountryTld(websiteOrigin, countryCode);
  const cName = COUNTRY_BY_CODE.get(countryCode)?.name || "";
  const pageMentionsCountry =
    isCountryTld || (cName && new RegExp(`\\b${cName.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&")}\\b`, "iu").test(stripped));
  if (dialDigits === "1") {
    for (const m of stripped.matchAll(/\(?\b[2-9]\d{2}\)?[\s.-]\d{3}[\s.-]\d{4}\b/gu)) {
      candidates.push({raw: cleanRawPhoneCandidate(m[0]), source: "nanpa_text"});
    }
  } else if (pageMentionsCountry) {
    for (const m of stripped.matchAll(/\b0[1-9]\d{1,3}[\s().-]+\d{3,4}[\s().-]*\d{3,4}\b/gu)) {
      candidates.push({raw: cleanRawPhoneCandidate(m[0]), source: "domestic_tld"});
    }
    for (const m of stripped.matchAll(/\([1-9]\d{1,2}\)\s*\d{3,5}[\s.-]\d{3,4}\b/gu)) {
      candidates.push({raw: cleanRawPhoneCandidate(m[0]), source: "domestic_paren"});
    }
  }

  const matchedDial = [];
  const fallbackValid = [];
  const seenE164 = new Set();

  for (const {raw, source} of candidates) {
    if (looksLikeDateOrBogusNumber(raw)) continue;
    const norm = normalizeGlobalPhone(raw, countryCode);
    if (!norm.validPhone || !norm.e164 || seenE164.has(norm.e164)) continue;

    const startsWithTargetDial = dialDigits && norm.e164.startsWith(`+${dialDigits}`);
    if (startsWithTargetDial || norm.isTollFree) {
      seenE164.add(norm.e164);
      matchedDial.push(norm);
    } else if (
      (source === "tel_href" || source === "json_ld" || (source === "intl_plus" && raw.startsWith("+"))) &&
      norm.e164.length >= 9 &&
      isCountryTld
    ) {
      seenE164.add(norm.e164);
      fallbackValid.push(norm);
    }
  }

  return matchedDial.length > 0 ? matchedDial : fallbackValid;
}

export function cleanCompanyTitle(rawTitle = "", fallbackHost = "") {
  if (!rawTitle) return fallbackHost;
  const decoded = rawTitle
    .replace(/&amp;/giu, "&")
    .replace(/&#038;/giu, "&")
    .replace(/&ndash;|&#8211;/giu, "-")
    .replace(/&mdash;|&#8212;/giu, "-")
    .replace(/&quot;/giu, '"')
    .replace(/&#039;|&apos;/giu, "'")
    .replace(/<[^>]+>/gu, " ")
    .replace(/\s+/gu, " ")
    .trim();

  const parts = decoded.split(/\s*(?:\||—|–|\s-\s|::|•|»)\s*/u).map((p) => p.trim()).filter(Boolean);
  for (const part of parts) {
    if (part.length >= 3 && part.length <= 90 && !BAD_TITLE_RE.test(part)) {
      return part;
    }
  }
  return decoded.slice(0, 85);
}

export async function auditWebsiteLive(websiteUrl, countryCode, dialCode) {
  if (!websiteUrl) return {reachable: false, phones: [], emergency24x7: false, title: "", hasOilfieldSignal: false};
  const normalizedUrl = /^https?:\/\//iu.test(websiteUrl) ? websiteUrl : `https://${websiteUrl}`;
  let origin = "";
  try {
    origin = new URL(normalizedUrl).origin;
  } catch (_) {
    return {reachable: false, phones: [], emergency24x7: false, title: "", hasOilfieldSignal: false};
  }

  const home = await fetchText(normalizedUrl, {
    headers: {"User-Agent": BROWSER_USER_AGENT, Accept: "text/html,application/xhtml+xml"},
    timeoutMs: 8000,
  });
  if (!home.ok || !home.text) {
    return {reachable: false, status: home.status, phones: [], emergency24x7: false, title: "", hasOilfieldSignal: false};
  }

  try {
    origin = new URL(home.finalUrl || normalizedUrl).origin;
  } catch (_) {}

  const rawTitle = home.text.match(/<title[^>]*>([\s\S]*?)<\/title>/iu)?.[1] || "";
  const metaDesc =
    home.text.match(/<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/iu)?.[1] ||
    home.text.match(/<meta[^>]+content=["']([^"']+)["'][^>]+name=["']description["']/iu)?.[1] ||
    "";
  const title = cleanCompanyTitle(rawTitle);

  let phones = extractPhonesFromHtml(home.text, countryCode, dialCode, origin);
  let combinedHtml = `${rawTitle} ${metaDesc} ${home.text.slice(0, 120_000)}`;

  // Check contact page if homepage didn't expose a target-country phone
  if (phones.length === 0) {
    try {
      const contactHrefMatch = home.text.match(
        /href=["']([^"'#<>]*(?:contact|contacto|contato|kontakt|contatti|nous-contacter|reach-us|get-in-touch|locations|offices)[^"'#<>]*)["']/iu,
      );
      const candidateUrls = [];
      if (contactHrefMatch?.[1]) {
        const resolved = new URL(contactHrefMatch[1], origin).toString();
        if (resolved.startsWith(origin)) candidateUrls.push(resolved);
      }
      candidateUrls.push(`${origin}/contact`, `${origin}/contact-us`);

      const uniqueUrls = [...new Set(candidateUrls)].slice(0, 2);
      for (const cUrl of uniqueUrls) {
        const contactRes = await fetchText(cUrl, {
          headers: {"User-Agent": BROWSER_USER_AGENT, Accept: "text/html"},
          timeoutMs: 6500,
        });
        if (contactRes.ok && contactRes.text) {
          combinedHtml += " " + contactRes.text.slice(0, 100_000);
          phones = extractPhonesFromHtml(contactRes.text, countryCode, dialCode, origin);
          if (phones.length > 0) break;
        }
      }
    } catch (_) {}
  }

  return {
    reachable: true,
    status: home.status,
    finalUrl: home.finalUrl || normalizedUrl,
    origin,
    title,
    metaDesc,
    phones,
    hasOilfieldSignal: OILFIELD_SIGNAL_RE.test(combinedHtml),
    emergency24x7: /\b24\s*(?:hr|hour|\/7)\b/iu.test(combinedHtml),
  };
}

export async function searchBingRssDomains(queries = [], maxOrigins = 20) {
  const discovered = new Map();
  for (const qObj of queries) {
    const q = typeof qObj === "string" ? qObj : qObj.q;
    const city = typeof qObj === "object" ? qObj.city || "" : "";
    const seedCat = typeof qObj === "object" ? qObj.cat || "" : "";

    const rssUrl = `https://www.bing.com/search?format=rss&count=15&q=${encodeURIComponent(q)}`;
    const res = await fetchText(rssUrl, {
      headers: {
        "User-Agent": BROWSER_USER_AGENT,
        Accept: "application/rss+xml,application/xml,text/xml",
      },
      timeoutMs: 6500,
    });
    if (res.ok && res.text) {
      for (const itemMatch of res.text.matchAll(/<item>([\s\S]*?)<\/item>/giu)) {
        const itemXml = itemMatch[1];
        const link = itemXml.match(/<link>(https?:\/\/[^<\s]+)<\/link>/iu)?.[1]?.trim() || "";
        const itemTitle = itemXml.match(/<title>([\s\S]*?)<\/title>/iu)?.[1]?.trim() || "";
        const itemDesc = itemXml.match(/<description>([\s\S]*?)<\/description>/iu)?.[1]?.trim() || "";
        if (!link || AGGREGATOR_BLOCKLIST.test(link)) continue;
        try {
          const parsedUrl = new URL(link);
          if (/\.(?:gov|edu|ac\.|mil|org\.uk|wikipedia\.org)$/iu.test(parsedUrl.hostname)) continue;
          const origin = parsedUrl.origin;
          if (!discovered.has(origin)) {
            discovered.set(origin, {
              q,
              city,
              seedCat,
              deepUrl: link,
              rssTitle: itemTitle,
              rssDesc: itemDesc,
            });
            if (discovered.size >= maxOrigins) return discovered;
          }
        } catch (_) {}
      }
    }
    await sleep(120);
  }
  return discovered;
}

export function buildGlobalCompanyRecords({
  cand,
  audit,
  countryCode,
  globalSeenKeys,
  blockedPhones = new Set(),
  nowIso = new Date().toISOString(),
}) {
  if (!countryCode || BASELINE_COMPLETED_CODES.has(countryCode) || SANCTIONED_SKIP_CODES.has(countryCode)) {
    return null;
  }
  const rawName = String(cand.companyName || audit?.title || "").trim();
  if (!rawName || rawName.length < 3 || rawName.length > 110 || BAD_TITLE_RE.test(rawName)) {
    return null;
  }
  const normName = normalizedCompanyName(rawName);
  if (!normName || normName.length < 3) return null;

  const dedupeKey = `${countryCode}|${normName}`;
  if (globalSeenKeys.has(dedupeKey)) return null;

  let hostKey = "";
  const website = String(audit?.origin || cand.website || "").trim();
  if (website) {
    try {
      const host = new URL(/^https?:\/\//iu.test(website) ? website : `https://${website}`).hostname
        .toLowerCase()
        .replace(/^www\./u, "");
      hostKey = `host|${countryCode}|${host}`;
    } catch (_) {}
  }
  if (hostKey && globalSeenKeys.has(hostKey)) return null;

  const seedPhoneNorm = normalizeGlobalPhone(cand.rawPhone || "", countryCode);
  const livePhoneNorm = audit?.phones?.[0] || null;
  const bestPhone = livePhoneNorm?.validPhone
    ? livePhoneNorm
    : seedPhoneNorm.validPhone
      ? seedPhoneNorm
      : null;

  if (!bestPhone && !audit?.reachable) return null;
  if (bestPhone?.e164 && blockedPhones.has(bestPhone.e164)) return null;

  const combinedDesc = [
    rawName,
    cand.combinedText || "",
    audit?.title || "",
    audit?.metaDesc || "",
  ].join(" ");

  const cats = [
    ...new Set([
      ...(cand.seedCategories || []).filter((c) => CATEGORY_BY_CODE.has(c)),
      ...classifyCategoriesFromText([rawName, cand.combinedText || "", audit?.title || ""], combinedDesc),
    ]),
  ];

  if (cats.length === 0) {
    if (OILFIELD_SIGNAL_RE.test(combinedDesc)) {
      cats.push("equipment_rentals_tools");
    } else {
      return null;
    }
  }

  if (bestPhone?.e164) {
    const phoneKey = `phone|${bestPhone.e164}`;
    if (globalSeenKeys.has(phoneKey)) return null;
    globalSeenKeys.add(phoneKey);
  }
  globalSeenKeys.add(dedupeKey);
  if (hostKey) globalSeenKeys.add(hostKey);

  const geo = inferCountryAndRegion(countryCode, cand.regionInput || "");
  const slug = normName
    .replace(/[^a-z0-9]+/gu, "-")
    .replace(/^-+|-+$/gu, "")
    .slice(0, 52);
  const docId = `yp-gl-${geo.countryCode.toLowerCase()}-${slug || Date.now().toString(36)}`;

  const categoryLabels = cats
    .map((code) => CATEGORY_BY_CODE.get(code)?.label || code)
    .slice(0, 10);

  const legacyPhones = [];
  const phoneHistory = [];
  if (seedPhoneNorm.validPhone && livePhoneNorm?.validPhone && seedPhoneNorm.e164 !== livePhoneNorm.e164) {
    legacyPhones.push(seedPhoneNorm.display);
    phoneHistory.push({
      oldPhone: seedPhoneNorm.display,
      newPhone: livePhoneNorm.display,
      detectedAt: nowIso,
      source: "live_website_audit",
    });
  }

  const hasDialablePhone = Boolean(bestPhone?.validPhone);
  const privateRecord = {
    schemaVersion: 3,
    companyId: docId,
    discoveryChannel: cand.sourceType || "open_web_country_crawl",
    companyName: rawName,
    normalizedCompanyName: normName,
    continentCode: geo.continentCode,
    isMiddleEast: geo.isMiddleEast === true,
    countryCode: geo.countryCode,
    countryName: geo.countryName,
    regionCode: geo.regionCode || "",
    regionName: geo.regionName || "",
    city: String(cand.city || "").trim(),
    postalCode: String(cand.postalCode || "").trim(),
    streetAddress: String(cand.streetAddress || "").trim(),
    mainPhone: bestPhone ? bestPhone.display : "",
    publicPhone: bestPhone ? bestPhone.display : "",
    tollFreePhone: bestPhone?.isTollFree ? bestPhone.display : "",
    legacyPhones,
    phoneHistory,
    generalEmail: "",
    publicEmail: "",
    website,
    powerUnits: 0,
    categoryCodes: cats,
    categories: categoryLabels,
    services: categoryLabels.slice(0, 4),
    basins: geo.defaultBasins || [],
    serviceAreas: [cand.city, geo.regionName, geo.countryName].filter(Boolean),
    certifications: [],
    emergency24x7: Boolean(audit?.emergency24x7),
    description: String(audit?.metaDesc || "").slice(0, 280),
    verificationStatus: "unverified",
    operationalStatus: hasDialablePhone ? "active_in_operation" : "unverified",
    outreachStatus: "not_contacted",
    billingStatus: "unpaid",
    listingTier: "free_basic",
    nonExpiringPaid: false,
    allowUnpaidPublic: true,
    publicationStatus: hasDialablePhone ? "published" : "unpublished",
    adminViewingEnabled: true,
    isFlaggedProhibited: false,
    flagReason: "",
    doNotContact: false,
    sourceReferences: [
      {
        sourceType: cand.sourceType || "open_web_country_crawl",
        sourceName: cand.sourceName || `Global Oilfield Discovery (${geo.countryName})`,
        sourceUrl: cand.sourceUrl || website || "",
        sourceExternalId: cand.externalId || website || "",
        observedAt: nowIso,
        bookPage: "",
      },
    ],
    liveAuditSummary: {
      auditedAt: nowIso,
      websiteReachable: Boolean(audit?.reachable),
      httpStatus: audit?.status || 0,
      phoneE164: bestPhone?.e164 || "",
    },
    publishedAt: hasDialablePhone ? nowIso : null,
    createdAt: nowIso,
    updatedAt: nowIso,
  };
  privateRecord.adminSearchTokens = buildAdminSearchTokens(privateRecord);

  let publicRecord = null;
  if (hasDialablePhone && isPublicationEligible(privateRecord)) {
    publicRecord = buildPublicEntry(privateRecord, docId, nowIso);
  }

  return {privateRecord, publicRecord};
}

// ---------------------------------------------------------------------------
// Fast Cached OAuth Token + Firestore Commit & Blocked-Number Reader
// ---------------------------------------------------------------------------
let cachedAccessToken = null;
let cachedTokenExpiresAt = 0;

export async function resolveAccessToken(projectId = "flutter-flow-pipe") {
  if (process.env.FIREBASE_ACCESS_TOKEN) return process.env.FIREBASE_ACCESS_TOKEN.trim();
  if (cachedAccessToken && cachedTokenExpiresAt > Date.now() + 8 * 60_000) {
    return cachedAccessToken;
  }

  const configPath = path.join(os.homedir(), ".config", "configstore", "firebase-tools.json");
  const readTokenObj = async () => {
    const raw = JSON.parse(await fs.readFile(configPath, "utf8"));
    return raw?.tokens || {};
  };

  let tokens = await readTokenObj().catch(() => ({}));
  if (tokens.access_token && Number(tokens.expires_at || 0) > Date.now() + 8 * 60_000) {
    cachedAccessToken = tokens.access_token;
    cachedTokenExpiresAt = Number(tokens.expires_at);
    return cachedAccessToken;
  }

  if (tokens.refresh_token) {
    try {
      const fbAuthPath = path.join(
        process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming"),
        "npm",
        "node_modules",
        "firebase-tools",
        "lib",
        "auth.js",
      );
      const fbAuth = require(fbAuthPath);
      const refreshed = await fbAuth.getAccessToken(tokens.refresh_token, tokens.scopes || []);
      if (refreshed?.access_token) {
        cachedAccessToken = refreshed.access_token;
        cachedTokenExpiresAt = Date.now() + 50 * 60_000;
        return cachedAccessToken;
      }
    } catch (_) {}
  }

  execSync(`firebase apps:list --project ${projectId}`, {stdio: "ignore", timeout: 60000});
  tokens = await readTokenObj();
  if (!tokens.access_token) throw new Error("Firebase CLI access token missing or expired.");
  cachedAccessToken = tokens.access_token;
  cachedTokenExpiresAt = Number(tokens.expires_at || Date.now() + 45 * 60_000);
  return cachedAccessToken;
}

export function toFirestoreValue(val, key = "") {
  if (val === null || val === undefined) return {nullValue: null};
  if (
    TIMESTAMP_KEYS.has(key) &&
    typeof val === "string" &&
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/u.test(val)
  ) {
    return {timestampValue: val};
  }
  if (typeof val === "boolean") return {booleanValue: val};
  if (typeof val === "number") {
    if (!Number.isFinite(val)) return {integerValue: "0"};
    return Number.isInteger(val) ? {integerValue: String(val)} : {doubleValue: val};
  }
  if (typeof val === "string") return {stringValue: val};
  if (Array.isArray(val)) {
    return {arrayValue: {values: val.map((item) => toFirestoreValue(item, ""))}};
  }
  if (typeof val === "object") {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      if (v !== undefined) fields[k] = toFirestoreValue(v, k);
    }
    return {mapValue: {fields}};
  }
  return {stringValue: String(val)};
}

export async function commitDocsToFirestore(projectId, collectionName, docs, batchSize = 25) {
  if (!docs || docs.length === 0) return;
  const commitUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;

  const slices = [];
  for (let i = 0; i < docs.length; i += batchSize) {
    slices.push(docs.slice(i, i + batchSize));
  }

  // Commit up to 4 batches concurrently with fresh token check
  for (let w = 0; w < slices.length; w += 4) {
    const group = slices.slice(w, w + 4);
    const token = await resolveAccessToken(projectId);
    await Promise.all(
      group.map(async (slice) => {
        const writes = slice.map((doc) => {
          const fields = {};
          for (const [k, v] of Object.entries(doc)) {
            if (v !== undefined) fields[k] = toFirestoreValue(v, k);
          }
          return {
            update: {
              name: `projects/${projectId}/databases/(default)/documents/${collectionName}/${encodeURIComponent(doc.companyId)}`,
              fields,
            },
          };
        });

        for (let attempt = 1; attempt <= 4; attempt += 1) {
          const freshToken = attempt > 1 ? await resolveAccessToken(projectId) : token;
          const res = await fetch(commitUrl, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${freshToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({writes}),
            signal: AbortSignal.timeout(30000),
          });
          if (res.ok) break;
          if (res.status === 401) {
            cachedAccessToken = null;
            cachedTokenExpiresAt = 0;
          }
          const errTxt = await res.text();
          if (attempt === 4) {
            throw new Error(`Firestore commit HTTP ${res.status} on ${collectionName}: ${errTxt.slice(0, 300)}`);
          }
          await sleep(500 * attempt * attempt);
        }
      }),
    );
  }
}

export async function loadBlockedPhones(projectId = "flutter-flow-pipe") {
  const blocked = new Set();
  try {
    const token = await resolveAccessToken(projectId);
    const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/yellow_pages_blocked_numbers?pageSize=300`;
    const res = await fetch(url, {
      headers: {Authorization: `Bearer ${token}`},
      signal: AbortSignal.timeout(10000),
    });
    if (res.ok) {
      const json = await res.json();
      for (const doc of json.documents || []) {
        const e164 = doc.fields?.e164?.stringValue || doc.fields?.phoneE164?.stringValue || "";
        if (e164) blocked.add(e164);
      }
    }
  } catch (_) {}
  return blocked;
}

export async function loadGlobalSeenKeysFromJsonl(jsonlPaths = []) {
  const seen = new Set();
  for (const p of jsonlPaths) {
    try {
      const raw = await fs.readFile(p, "utf8");
      for (const line of raw.split("\n")) {
        if (!line.trim()) continue;
        const obj = JSON.parse(line);
        if (obj.countryCode && obj.normalizedCompanyName) {
          seen.add(`${obj.countryCode}|${obj.normalizedCompanyName}`);
        }
        if (obj.liveAuditSummary?.phoneE164) {
          seen.add(`phone|${obj.liveAuditSummary.phoneE164}`);
        }
        if (obj.website && obj.countryCode) {
          try {
            const host = new URL(/^https?:\/\//iu.test(obj.website) ? obj.website : `https://${obj.website}`).hostname
              .toLowerCase()
              .replace(/^www\./u, "");
            seen.add(`host|${obj.countryCode}|${host}`);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
  return seen;
}
