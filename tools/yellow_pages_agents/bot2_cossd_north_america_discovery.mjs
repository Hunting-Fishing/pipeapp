#!/usr/bin/env node
/**
 * Bot 2 — Full COSSD Sitemap Universe Analyzer & Scaled North America Batch Crawler
 *
 * Step 2A: Downloads 100% of `https://www.cossd.com/sitemap-biz.xml` (17,945 business URLs)
 *          and `sitemap-product.xml` (2,579 category/region pages), classifies Oil & Gas
 *          relevance (filtering out non-oilfield hotels/restaurants/salons), and records
 *          the complete COSSD North America universe catalog (`02a_cossd_universe_catalog.json`
 *          + `02a_cossd_universe_breakdown.md`).
 * Step 2B: Runs a polite, concurrent, checkpoint-resumable batch crawl across 36 Canada + USA
 *          Oil & Gas hub category pages + the prioritized `sitemap-biz.xml` queue, saving
 *          cumulative results into `02_discovered_companies.json` and `02_cossd_checkpoint.json`.
 */

import fs from "node:fs/promises";
import path from "node:path";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";

const require = createRequire(import.meta.url);
const {
  inferCountryAndRegion,
  classifyCategoriesFromText,
} = require("../../firebase/functions/yellow_pages_taxonomy.js");
const {
  normalizeNorthAmericanPhone,
  normalizedCompanyName,
} = require("../../firebase/functions/yellow_pages_policy.js");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const LEDGER_DIR = path.join(REPO_ROOT, "data/yellow_pages/ledger");
const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");

const USER_AGENT =
  "PipeBuyerDirectoryVerificationBot/1.1 (+https://pipebuyer.com; factual-contact-audit)";

// Non-Oil-&-Gas filler filter (COSSD includes random motels, pizza shops, dentists, law firms, etc.)
const NON_OILFIELD_FILLER_REGEX =
  /\b(?:super-?8|days-?inn|holiday-?inn|best-?western|ramada|motel|hotel|resort|pizza|sushi|steakhouse|restaurant|bakery|cafe|coffee|dentist|dental|orthodont|chiropract|optometr|hair-?salon|barber|beauty|spa|nail-?salon|florist|flower-?shop|funeral|church|daycare|preschool|veterinar|pet-?groom|real-?estate|realtor|family-?law|field-?law|law-?firm|lawyer|attorney|divorce|wedding|jewelry)\b/iu;

const BLOCKED_EXTERNAL_HOST_REGEX =
  /(?:^|\.)(?:cossd\.com|namesandnumbers\.com|cloudfront\.net|facebook\.com|fb\.com|linkedin\.com|twitter\.com|x\.com|instagram\.com|youtube\.com|google\.com|goo\.gl|apple\.com|yp\.ca|yellowpages\.com)$/iu;

function isCleanCompanyWebsite(rawUrl = "") {
  if (!rawUrl) return false;
  try {
    const parsed = new URL(rawUrl);
    if (!/^https?:$/iu.test(parsed.protocol)) return false;
    const host = parsed.hostname.toLowerCase();
    if (BLOCKED_EXTERNAL_HOST_REGEX.test(host)) return false;
    if (/\.(?:png|jpg|jpeg|gif|svg|ico|css|js|pdf|woff2?)(?:\?|$)/iu.test(parsed.pathname)) {
      return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}

const OILFIELD_SIGNAL_SLUG_REGEX =
  /\b(?:oil|gas|energy|petro|pipe|pipeline|octg|tubular|casing|drill|rig|snub|wireline|slickline|coil|frac|well|wellhead|valve|bop|pump|compress|tank|vessel|process|weld|machin|fab|steel|truck|haul|winch|hotshot|hot-?shot|pilot|crane|picker|vac|hydrovac|fluid|water|boiler|rental|tool|mat|matting|lease|civil|earthwork|mulch|electr|instrument|scada|automat|control|safety|h2s|medic|fire|enviro|remediat|waste|disposal|chem|mud|lube|fuel|propane|mechanic|hydraul|diesel|fleet|tire|camp|cater|trailer|skid|shack|survey|geomat|eng|locat|ndt|inspect|test|coat|insul|sandblast|midstream|terminal)\b/iu;

// 36 Balanced North America (18 Canada + 18 USA) Oil & Gas Hub Category Pages
const NORTH_AMERICA_HUB_SEEDS = [
  // Canada — Alberta, BC, Saskatchewan, Manitoba, Ontario, Newfoundland
  "https://www.cossd.com/l/grande-prairie-ab/trucking-oilfield",
  "https://www.cossd.com/l/nisku-ab/oilfield-equipment-and-supplies",
  "https://www.cossd.com/l/red-deer-ab/vacuum-trucks",
  "https://www.cossd.com/l/edmonton-ab/welding",
  "https://www.cossd.com/l/calgary-ab/drilling-contractors",
  "https://www.cossd.com/l/lloydminster-ab/oilfield-service",
  "https://www.cossd.com/l/drayton-valley-ab/oilfield-hauling",
  "https://www.cossd.com/l/fort-mcmurray-ab/crane-service",
  "https://www.cossd.com/l/brooks-ab/well-servicing",
  "https://www.cossd.com/l/ab/pipes-fabrication",
  "https://www.cossd.com/l/ab/non-destructive-inspection",
  "https://www.cossd.com/l/ab/wireline-services",
  "https://www.cossd.com/l/fort-st-john-bc/oilfield-service",
  "https://www.cossd.com/l/dawson-creek-bc/trucking-oilfield",
  "https://www.cossd.com/l/estevan-sk/oilfield-hauling",
  "https://www.cossd.com/l/weyburn-sk/oilfield-service",
  "https://www.cossd.com/l/virden-mb/oilfield-service",
  "https://www.cossd.com/l/nl/oilfield-equipment-and-supplies",
  // USA — Texas, North Dakota, Oklahoma, Louisiana, Wyoming, New Mexico, Colorado, Pennsylvania, Ohio, Alaska, California
  "https://www.cossd.com/l/tx/drilling-contractors",
  "https://www.cossd.com/l/tx/pipes-fabrication",
  "https://www.cossd.com/l/tx/well-service",
  "https://www.cossd.com/l/tx/oilfield-equipment-manufacturers",
  "https://www.cossd.com/l/tx/pipeline-contractors",
  "https://www.cossd.com/l/tx/wireline-services",
  "https://www.cossd.com/l/tx/valves",
  "https://www.cossd.com/l/tx/non-destructive-inspection",
  "https://www.cossd.com/l/nd/oilfield-general-contractors",
  "https://www.cossd.com/l/nd/well-service",
  "https://www.cossd.com/l/ok/oilfield-equipment-manufacturers",
  "https://www.cossd.com/l/ok/drilling-contractors",
  "https://www.cossd.com/l/la/pipeline-contractors",
  "https://www.cossd.com/l/la/oilfield-general-contractors",
  "https://www.cossd.com/l/wy/drilling-contractors",
  "https://www.cossd.com/l/co/oilfield-general-contractors",
  "https://www.cossd.com/l/nm/oilfield-general-contractors",
  "https://www.cossd.com/l/pa/pipeline-contractors",
];

const US_STATE_CODES = new Set([
  "tx", "nd", "ok", "nm", "wy", "la", "co", "pa", "oh", "wv", "ak", "ca", "ks", "mt", "ut", "ar", "ms", "mi", "il", "in", "ky", "al", "ny", "va",
]);
const CA_PROVINCE_CODES = new Set([
  "ab", "bc", "sk", "mb", "on", "qc", "nb", "ns", "pe", "nl", "nt", "yt", "nu",
]);

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function decodeHtmlEntities(str = "") {
  return String(str)
    .replace(/&amp;/giu, "&")
    .replace(/&quot;/giu, '"')
    .replace(/&#x27;|&#39;|&apos;/giu, "'")
    .replace(/&lt;/giu, "<")
    .replace(/&gt;/giu, ">")
    .replace(/\s+/gu, " ")
    .trim();
}

async function writeJsonAtomic(targetPath, payload) {
  const tmpPath = `${targetPath}.tmp-${process.pid}`;
  const isLarge =
    (Array.isArray(payload?.companies) && payload.companies.length > 1500) ||
    (Array.isArray(payload?.visitedUrls) && payload.visitedUrls.length > 3000);
  const serialized = isLarge ? JSON.stringify(payload) : JSON.stringify(payload, null, 2);
  await fs.writeFile(tmpPath, serialized, "utf8");
  await fs.rename(tmpPath, targetPath);
}

async function fetchPolite(url, timeoutMs = 14000, maxRetries = 2) {
  for (let attempt = 0; attempt <= maxRetries; attempt += 1) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await fetch(url, {
        headers: {
          "User-Agent": USER_AGENT,
          "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        },
        signal: controller.signal,
      });
      clearTimeout(timer);
      if (res.ok) {
        return {ok: true, status: res.status, text: await res.text()};
      }
      if ((res.status === 429 || res.status >= 500) && attempt < maxRetries) {
        await sleep(500 * (attempt + 1));
        continue;
      }
      return {ok: false, status: res.status, text: ""};
    } catch (err) {
      clearTimeout(timer);
      if (attempt < maxRetries) {
        await sleep(400 * (attempt + 1));
        continue;
      }
      return {ok: false, status: 0, text: "", error: err.message};
    }
  }
  return {ok: false, status: 0, text: ""};
}

async function verifyRobotsTxt() {
  const res = await fetchPolite("https://www.cossd.com/robots.txt", 10000);
  if (!res.ok) return {checked: true, allowed: true, note: "robots.txt unreachable; proceeding politely"};
  const disallowedBiz = /Disallow:\s*\/biz\b/iu.test(res.text);
  return {
    checked: true,
    allowed: !disallowedBiz,
    sitemapListed: /sitemap\.xml/iu.test(res.text),
  };
}

export async function catalogFullCossdUniverse({useCache = true} = {}) {
  const catalogPath = path.join(LEDGER_DIR, "02a_cossd_universe_catalog.json");
  if (useCache) {
    try {
      const cached = JSON.parse(await fs.readFile(catalogPath, "utf8"));
      if (
        Array.isArray(cached?.prioritizedQueue) &&
        cached.prioritizedQueue.length > 10000 &&
        cached.totalSitemapBizProfiles
      ) {
        return {
          summary: cached,
          prioritizedQueue: cached.prioritizedQueue,
          productUrls: [],
        };
      }
    } catch (_) {}
  }

  const [bizRes, prodRes] = await Promise.all([
    fetchPolite("https://www.cossd.com/sitemap-biz.xml", 25000),
    fetchPolite("https://www.cossd.com/sitemap-product.xml", 25000),
  ]);

  const allBizUrls = [];
  const highSignalOilfieldUrls = [];
  const generalIndustrialUrls = [];
  let filteredFillerCount = 0;

  if (bizRes.ok) {
    const locRegex = /<loc>(https?:\/\/www\.cossd\.com\/biz\/(\d+)\/([^<]+))<\/loc>/giu;
    let m;
    while ((m = locRegex.exec(bizRes.text)) !== null) {
      const fullUrl = m[1].trim();
      const slug = m[3].trim();
      allBizUrls.push(fullUrl);
      if (NON_OILFIELD_FILLER_REGEX.test(slug)) {
        filteredFillerCount += 1;
      } else if (OILFIELD_SIGNAL_SLUG_REGEX.test(slug)) {
        highSignalOilfieldUrls.push(fullUrl);
      } else {
        generalIndustrialUrls.push(fullUrl);
      }
    }
  }

  const productPagesByCountry = {CA: 0, US: 0, other: 0};
  const topProductCategories = new Map();
  const productUrls = [];

  if (prodRes.ok) {
    const prodRegex = /<loc>(https?:\/\/www\.cossd\.com\/l\/([a-z0-9-]+)\/([a-z0-9-]+))<\/loc>/giu;
    let m;
    while ((m = prodRegex.exec(prodRes.text)) !== null) {
      const url = m[1].trim();
      const geoSlug = m[2].toLowerCase();
      const catSlug = m[3].toLowerCase();
      productUrls.push(url);
      const tail = geoSlug.split("-").pop();
      if (CA_PROVINCE_CODES.has(tail)) productPagesByCountry.CA += 1;
      else if (US_STATE_CODES.has(tail)) productPagesByCountry.US += 1;
      else productPagesByCountry.other += 1;
      topProductCategories.set(catSlug, (topProductCategories.get(catSlug) || 0) + 1);
    }
  }

  const topCategoriesSorted = [...topProductCategories.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 30)
    .map(([categorySlug, hubCount]) => ({categorySlug, hubCount}));

  const summary = {
    catalogedAt: new Date().toISOString(),
    totalSitemapBizProfiles: allBizUrls.length,
    highSignalOilfieldNameMatches: highSignalOilfieldUrls.length,
    generalB2BCandidates: generalIndustrialUrls.length,
    excludedNonOilfieldFiller: filteredFillerCount,
    importableOilAndGasUniverse: highSignalOilfieldUrls.length + generalIndustrialUrls.length,
    totalProductCategoryGeoPages: productUrls.length,
    productGeoBreakdown: productPagesByCountry,
    topCategoriesSorted,
    sampleHighSignalUrls: highSignalOilfieldUrls.slice(0, 50),
  };

  await fs.writeFile(
    path.join(LEDGER_DIR, "02a_cossd_universe_catalog.json"),
    JSON.stringify({...summary, prioritizedQueue: [...highSignalOilfieldUrls, ...generalIndustrialUrls]}, null, 2),
    "utf8",
  );

  const md = [
    "# COSSD (`www.cossd.com`) Complete Sitemap & Importable Business Universe Audit",
    "",
    `- **Cataloged At**: \`${summary.catalogedAt}\``,
    `- **Total \`/biz/\` Profiles on \`cossd.com\`**: **${summary.totalSitemapBizProfiles.toLocaleString()}**`,
    `- **Importable Oil & Gas / Industrial Candidates**: **${summary.importableOilAndGasUniverse.toLocaleString()}**`,
    `  - Direct Oilfield / Industrial Keyword Slugs: **${summary.highSignalOilfieldNameMatches.toLocaleString()}**`,
    `  - General B2B Contractors (Need Category Check): **${summary.generalB2BCandidates.toLocaleString()}**`,
    `- **Excluded Non-Oilfield Filler (Hotels/Motels/Restaurants/Salons/Law)**: **${summary.excludedNonOilfieldFiller.toLocaleString()}** *(filtered automatically so PipeBuyer stays 100% pure industrial/oilfield)*`,
    `- **Category × City/State Landing Pages (\`sitemap-product.xml\`)**: **${summary.totalProductCategoryGeoPages.toLocaleString()}** (Canada: **${productPagesByCountry.CA}**, USA: **${productPagesByCountry.US}**)`,
    "",
    "## Top 20 Oil & Gas Service Categories on COSSD",
    "",
    "| Category Slug | Regional Hub Pages |",
    "| :--- | ---: |",
    ...topCategoriesSorted.slice(0, 20).map((c) => `| \`${c.categorySlug}\` | ${c.hubCount} |`),
    "",
  ];
  await fs.writeFile(
    path.join(REPORTS_DIR, "02a_cossd_universe_breakdown.md"),
    md.join("\n"),
    "utf8",
  );

  return {
    summary,
    prioritizedQueue: [...highSignalOilfieldUrls, ...generalIndustrialUrls],
    productUrls,
  };
}

function extractBizLinksFromHtml(html) {
  const links = [];
  const seen = new Set();
  const regex = /href=["']((?:https?:\/\/www\.cossd\.com)?\/biz\/\d+\/([a-z0-9-]+))["']/giu;
  let match;
  while ((match = regex.exec(html)) !== null) {
    const raw = match[1];
    const slug = match[2];
    if (NON_OILFIELD_FILLER_REGEX.test(slug)) continue;
    const full = raw.startsWith("http") ? raw : `https://www.cossd.com${raw}`;
    if (!seen.has(full)) {
      seen.add(full);
      links.push(full);
    }
  }
  return links;
}

function parseBizPageFactual(html, sourceUrl) {
  const idMatch = sourceUrl.match(/\/biz\/(\d+)\//u);
  const externalId = idMatch ? idMatch[1] : "";

  let ld = {};
  const ldRegex = /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/giu;
  let match;
  while ((match = ldRegex.exec(html)) !== null) {
    try {
      const parsed = JSON.parse(match[1].trim());
      const items = Array.isArray(parsed) ? parsed : [parsed];
      for (const item of items) {
        if (item && (item["@type"] === "LocalBusiness" || item.name)) {
          ld = item;
          break;
        }
      }
    } catch (_) {
      // Ignore malformed JSON-LD blocks
    }
  }

  const companyName = decodeHtmlEntities(
    ld.name || (html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/iu)?.[1] || "").replace(/<[^>]+>/gu, ""),
  );
  if (!companyName) return null;
  if (NON_OILFIELD_FILLER_REGEX.test(companyName.replace(/\s+/gu, "-"))) return null;

  const addr = ld.address || {};
  const city = decodeHtmlEntities(addr.addressLocality || "");
  const rawRegion = decodeHtmlEntities(addr.addressRegion || "");
  const rawCountry = decodeHtmlEntities(addr.addressCountry || "");
  const postalCode = decodeHtmlEntities(addr.postalCode || "");
  const streetAddress = decodeHtmlEntities(addr.streetAddress || "");

  const geo = inferCountryAndRegion(rawCountry, rawRegion);

  const rawPhones = [];
  if (ld.telephone) rawPhones.push(String(ld.telephone));
  const telHrefMatches = html.matchAll(/href=["']tel:([^"']+)["']/giu);
  for (const m of telHrefMatches) rawPhones.push(m[1]);
  const bizPhoneMatches = html.matchAll(/class=["'][^"']*biz-phone[^"']*["'][^>]*>([^<]+)</giu);
  for (const m of bizPhoneMatches) rawPhones.push(m[1]);
  const jsonTelMatches = html.matchAll(/"telephone"\s*:\s*"([^"]+)"/giu);
  for (const m of jsonTelMatches) rawPhones.push(m[1]);

  let mainPhone = "";
  let tollFreePhone = "";
  for (const p of rawPhones) {
    const norm = normalizeNorthAmericanPhone(p);
    if (!norm.validNanpa) continue;
    if (norm.isTollFree && !tollFreePhone) {
      tollFreePhone = norm.display;
    } else if (!norm.isTollFree && !mainPhone) {
      mainPhone = norm.display;
    } else if (!mainPhone) {
      mainPhone = norm.display;
    }
  }

  let website = "";
  if (ld.url && isCleanCompanyWebsite(String(ld.url).trim())) {
    website = String(ld.url).trim();
  } else {
    const extMatches = html.matchAll(/<a\b[^>]*href=["'](https?:\/\/[^"'\s>]+)["']/giu);
    for (const m of extMatches) {
      const candidate = m[1].trim();
      if (isCleanCompanyWebsite(candidate)) {
        website = candidate;
        break;
      }
    }
  }

  const rawCategories = new Set();
  const catMatches = html.matchAll(/\/l\/[a-z0-9-]+\/([a-z0-9-]+)["'][^>]*>([^<]{2,70})</giu);
  for (const m of catMatches) {
    const label = decodeHtmlEntities(m[2]);
    if (label && !/home|search|login|register|directory/iu.test(label)) {
      rawCategories.add(label);
    }
  }

  const certifications = [];
  if (/\bISNetworld\b/iu.test(html)) certifications.push("ISNetworld");
  if (/\bComplyWorks\b/iu.test(html)) certifications.push("ComplyWorks");
  if (/\b(?:COR|SECOR)\b/u.test(html)) certifications.push("COR / SECOR");
  if (/\bABSA\b/u.test(html)) certifications.push("ABSA");
  if (/\bAvetta\b/iu.test(html)) certifications.push("Avetta");
  if (/\bAPI\s*(?:Spec|Certified|Q1|6A|5CT)\b/iu.test(html)) certifications.push("API Certified");

  const servicesList = Array.from(rawCategories).slice(0, 12);
  if (servicesList.some((s) => /hotel|motel|accommodations\s+hotels|restaurants|lawyers|attorneys/iu.test(s))) {
    return null;
  }

  const categoryCodes = classifyCategoriesFromText(
    [companyName, ...servicesList],
    servicesList.join(" "),
  );

  return {
    recordId: externalId ? `cossd-${externalId}` : `na-${normalizedCompanyName(companyName).slice(0, 40)}`,
    discoveryChannel: "cossd_directory",
    externalSourceId: externalId,
    companyName,
    normalizedCompanyName: normalizedCompanyName(companyName),
    countryCode: geo.countryCode,
    regionCode: geo.regionCode,
    regionName: geo.regionName,
    timezone: geo.timezone,
    basins: geo.defaultBasins || [],
    city,
    postalCode,
    streetAddress,
    directoryPhone: mainPhone,
    tollFreePhone,
    website,
    categoryCodes,
    services: servicesList,
    certifications,
    emergency24x7: /\b24\s*(?:hr|hour|\/7)\b/iu.test(html),
    sourceReferences: [
      {
        sourceType: "public_web_directory",
        sourceLabel: "COSSD Public Directory Index",
        sourceUrl,
        discoveredAt: new Date().toISOString(),
      },
    ],
  };
}

export async function runNorthAmericaDiscovery({
  limit = 220,
  concurrency = 14,
  resume = true,
  skipRobotsIfResuming = false,
} = {}) {
  await fs.mkdir(LEDGER_DIR, {recursive: true});
  await fs.mkdir(REPORTS_DIR, {recursive: true});

  let robots = {checked: true, allowed: true, cached: true};
  if (!skipRobotsIfResuming) {
    robots = await verifyRobotsTxt();
    if (!robots.allowed) {
      throw new Error("robots.txt disallows crawling /biz paths; aborting discovery.");
    }
  }

  const universe = await catalogFullCossdUniverse({useCache: resume});

  // Load checkpoint if resuming
  const checkpointPath = path.join(LEDGER_DIR, "02_cossd_checkpoint.json");
  const hubCachePath = path.join(LEDGER_DIR, "02b_hub_seeds_cache.json");
  const ledgerPath = path.join(LEDGER_DIR, "02_discovered_companies.json");
  const visitedUrls = new Set();
  const byKey = new Map();

  if (resume) {
    try {
      const prevCp = JSON.parse(await fs.readFile(checkpointPath, "utf8"));
      for (const u of prevCp.visitedUrls || []) visitedUrls.add(u);
    } catch (_) {}
    try {
      const prevLedger = JSON.parse(await fs.readFile(ledgerPath, "utf8"));
      for (const c of prevLedger.companies || []) {
        if (!NON_OILFIELD_FILLER_REGEX.test((c.companyName || "").replace(/\s+/gu, "-"))) {
          if (c.website && !isCleanCompanyWebsite(c.website)) {
            c.website = "";
          }
          byKey.set(`${c.normalizedCompanyName}|${c.regionCode}`, c);
        }
      }
    } catch (_) {}
  }

  // Gather balanced Canada + USA hub business URLs once (cached on subsequent waves)
  let hubSeedLinks = [];
  if (resume) {
    try {
      hubSeedLinks = JSON.parse(await fs.readFile(hubCachePath, "utf8")).links || [];
    } catch (_) {}
  }
  if (hubSeedLinks.length === 0) {
    const hubCollected = [];
    const hubSeen = new Set();
    for (let i = 0; i < NORTH_AMERICA_HUB_SEEDS.length; i += 6) {
      const hubBatch = NORTH_AMERICA_HUB_SEEDS.slice(i, i + 6);
      const hubResponses = await Promise.all(hubBatch.map((u) => fetchPolite(u, 12000)));
      for (const res of hubResponses) {
        if (!res.ok) continue;
        for (const link of extractBizLinksFromHtml(res.text)) {
          if (!hubSeen.has(link)) {
            hubSeen.add(link);
            hubCollected.push(link);
          }
        }
      }
      await sleep(120);
    }
    hubSeedLinks = hubCollected;
    await writeJsonAtomic(hubCachePath, {cachedAt: new Date().toISOString(), links: hubSeedLinks});
  }

  const candidateUrls = [];
  const candidateSeen = new Set(visitedUrls);
  for (const link of hubSeedLinks) {
    if (candidateUrls.length >= limit) break;
    if (!candidateSeen.has(link)) {
      candidateSeen.add(link);
      candidateUrls.push(link);
    }
  }

  // Supplement from prioritized high-signal Oil & Gas + general industrial sitemap URLs up to `limit`
  for (const smUrl of universe.prioritizedQueue) {
    if (candidateUrls.length >= limit) break;
    if (!candidateSeen.has(smUrl)) {
      candidateSeen.add(smUrl);
      candidateUrls.push(smUrl);
    }
  }

  const batchToCrawl = candidateUrls.slice(0, limit);
  let newlyDiscoveredCount = 0;

  for (let i = 0; i < batchToCrawl.length; i += concurrency) {
    const slice = batchToCrawl.slice(i, i + concurrency);
    const pages = await Promise.all(
      slice.map(async (url) => {
        const res = await fetchPolite(url, 12000, 2);
        visitedUrls.add(url);
        return {url, res};
      }),
    );
    for (const {url, res} of pages) {
      if (!res.ok) continue;
      const parsed = parseBizPageFactual(res.text, url);
      if (parsed && parsed.companyName) {
        const dedupeKey = `${parsed.normalizedCompanyName}|${parsed.regionCode}`;
        if (!byKey.has(dedupeKey)) {
          byKey.set(dedupeKey, parsed);
          newlyDiscoveredCount += 1;
        }
      }
    }
    await sleep(95); // Polite pacing between slices
  }

  const companies = Array.from(byKey.values());
  let unvisitedInQueue = 0;
  for (const smUrl of universe.prioritizedQueue) {
    if (!visitedUrls.has(smUrl)) unvisitedInQueue += 1;
  }

  await writeJsonAtomic(checkpointPath, {
    updatedAt: new Date().toISOString(),
    totalVisitedCount: visitedUrls.size,
    remainingInUniverse: unvisitedInQueue,
    visitedUrls: Array.from(visitedUrls),
  });

  const outLedger = {
    generatedAt: new Date().toISOString(),
    robotsCheck: robots,
    cossdUniverseSummary: {
      totalSitemapBizProfiles: universe.summary.totalSitemapBizProfiles,
      importableOilAndGasUniverse: universe.summary.importableOilAndGasUniverse,
      excludedNonOilfieldFiller: universe.summary.excludedNonOilfieldFiller,
      visitedSoFar: visitedUrls.size,
      remainingInUniverse: unvisitedInQueue,
    },
    crawledUrlsInThisWave: batchToCrawl.length,
    newlyAddedInThisRun: newlyDiscoveredCount,
    totalDiscovered: companies.length,
    byCountry: {
      CA: companies.filter((c) => c.countryCode === "CA").length,
      US: companies.filter((c) => c.countryCode === "US").length,
    },
    companies,
  };

  await writeJsonAtomic(ledgerPath, outLedger);

  const byRegionCounts = {};
  for (const c of companies) {
    const key = `${c.countryCode}-${c.regionCode || "NA"}`;
    byRegionCounts[key] = (byRegionCounts[key] || 0) + 1;
  }

  const md = [
    "# Bot 2 — Scaled COSSD North America Oil & Gas Discovery Report",
    "",
    `- **Generated At**: \`${outLedger.generatedAt}\``,
    `- **COSSD Total Sitemap Universe**: **${universe.summary.totalSitemapBizProfiles.toLocaleString()}** profiles (**${universe.summary.importableOilAndGasUniverse.toLocaleString()}** Oil & Gas/B2B candidates; **${universe.summary.excludedNonOilfieldFiller.toLocaleString()}** non-oilfield hotels/restaurants/law excluded)`,
    `- **Total Unique Oil & Gas Companies Imported So Far**: **${companies.length}** (Canada: **${outLedger.byCountry.CA}**, USA: **${outLedger.byCountry.US}**)`,
    `- **Province / State Coverage**: ${Object.entries(byRegionCounts).sort((a, b) => b[1] - a[1]).map(([k, v]) => `\`${k}\`: ${v}`).join(" • ")}`,
    "",
    "## Sample of Imported COSSD Companies (First 60 Shown)",
    "",
    "| Company | City / Region | Country | Directory Phone | Website | Mapped Categories |",
    "| :--- | :--- | :---: | :--- | :--- | :--- |",
    ...companies.slice(0, 60).map(
      (c) =>
        `| ${c.companyName} | ${[c.city, c.regionCode].filter(Boolean).join(", ")} | ${c.countryCode} | ${c.directoryPhone || c.tollFreePhone || "—"} | ${c.website || "—"} | ${c.categoryCodes.slice(0, 3).join(", ") || "general"} |`,
    ),
    "",
  ];
  await fs.writeFile(path.join(REPORTS_DIR, "02_discovery_report.md"), md.join("\n"), "utf8");
  console.log(
    `[Bot 2] COSSD Universe: ${universe.summary.totalSitemapBizProfiles} total (${universe.summary.importableOilAndGasUniverse} Oil & Gas). Cumulative imported: ${companies.length} (CA: ${outLedger.byCountry.CA}, US: ${outLedger.byCountry.US})`,
  );
  return outLedger;
}

if (process.argv[1]?.endsWith("bot2_cossd_north_america_discovery.mjs")) {
  const limitArg = process.argv.indexOf("--limit");
  const concArg = process.argv.indexOf("--concurrency");
  const noResume = process.argv.includes("--fresh");
  const limit = limitArg !== -1 ? Number(process.argv[limitArg + 1] || 220) : 220;
  const concurrency = concArg !== -1 ? Number(process.argv[concArg + 1] || 8) : 8;
  runNorthAmericaDiscovery({limit, concurrency, resume: !noResume}).catch((err) => {
    console.error("[Bot 2 Error]", err.message);
    process.exitCode = 1;
  });
}
