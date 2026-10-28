#!/usr/bin/env node
/**
 * Bot 18 — 12-Agent Parallel Google Maps Micro-Town Harvester & True-Town Geo-Resolver
 *
 * Executes a memory-bounded wave of micro-town queries from `17_microtown_pending_queue.json`,
 * updates per-town local yield metrics in `17_microtown_frontier_state.json` (driving Bot 17's
 * Stage 1 -> 2 -> 3 -> 4 -> EXHAUSTED escalation), and streams newly discovered North American
 * Oil & Gas businesses and Training facilities live to Firestore (`verified: false`).
 */

import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import {createRequire} from "node:module";
import {fileURLToPath, pathToFileURL} from "node:url";
import {resolveAccessToken, toFirestoreValue} from "./global_shared_utils.mjs";
import {DYNAMIC_TOWNS_PATH, QUEUE_PATH, STATE_PATH} from "./bot17_microtown_atlas_planner.mjs";

const require = createRequire(import.meta.url);
const {
  CATEGORY_BY_CODE,
  canonicalizeCityName,
  canonicalizeCompanyName,
  canonicalizeRegionCode,
  classifyCategoriesFromText,
  inferCountryAndRegion,
  inferGeoFromNanpaPhone,
  normalizeCityKey,
} = require("../../firebase/functions/yellow_pages_taxonomy.js");
const {
  buildAdminSearchTokens,
  buildPublicEntry,
  normalizeNorthAmericanPhone,
  normalizedCompanyName,
} = require("../../firebase/functions/yellow_pages_policy.js");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const LEDGER_DIR = path.join(REPO_ROOT, "data/yellow_pages/ledger");
const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");
const DISCOVERED_JSONL_PATH = path.join(LEDGER_DIR, "18_microtown_discovered.jsonl");
const INDEX_CACHE_PATH = path.join(LEDGER_DIR, "18_firestore_index_cache.json");
const WAVE_REPORT_PATH = path.join(REPORTS_DIR, "18_MICROTOWN_HARVEST_REPORT.md");

const args = process.argv.slice(2);
const SYNC = args.includes("--sync");
const REFRESH_INDEX = args.includes("--refresh-index");
const agentsIdx = args.indexOf("--agents");
const NUM_AGENTS = agentsIdx !== -1 ? Math.max(1, Math.min(28, Number(args[agentsIdx + 1] || 20))) : 20;
const waveIdx = args.indexOf("--wave-size");
const WAVE_SIZE = waveIdx !== -1 ? Math.max(1, Number(args[waveIdx + 1] || 900)) : 900;
const countryIdx = args.indexOf("--country");
const COUNTRY_FILTER = countryIdx !== -1 ? String(args[countryIdx + 1] || "").toUpperCase() : "";
const projIdx = args.indexOf("--project");
const PROJECT_ID = projIdx !== -1 && args[projIdx + 1] ? args[projIdx + 1] : "flutter-flow-pipe";

const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

const CONSUMER_NOISE_BLOCKLIST =
  /\b(?:gas station|convenience store|service station|truck stop|car wash|auto oil change|oil change service|jiffy lube|mr\.?\s*lube|great canadian oil change|valvoline instant|take 5 oil|grease monkey|midas|meineke|kal tire|fountain tire|canadian tire|walmart|costco|7-eleven|circle k|esso|petro-canada|shell station|chevron station|mobil station|exxon station|husky|co-op gas|love's travel|pilot travel|flying j|buc-ee|quiktrip|wawa|hair|beauty|barber|nail|spa|yoga|pilates|martial arts|karate|taekwondo|dance|music school|kumon|sylvan learning|mathnasium|tutoring|daycare|preschool|montessori|dog training|pet|real estate|mortgage|dental|chiropractic|optometrist|pharmacy|restaurant|pizza|cafe|coffee|bakery|hotel|motel|inn|church|fitness|gym|crossfit|hunter safety|wilderness survival|aviation learning|aviation maintenance|scout aviation|allcpr|hero for life|mind body|dole accredited|philippines|saferphilippines|1philsafe|feati maritime|bacoor branch|funeral|florist|grocery|supermarket|liquor|cannabis|dispensary)\b/iu;

const POSITIVE_OILFIELD_OR_TRAINING_SIGNAL =
  /\b(?:oilfield|oil\s*&\s*gas|oil\s+and\s+gas|petroleum|energy|drilling|well\s+service|workover|wireline|slickline|coiled\s+tubing|frac|fracturing|cementing|completions|wellhead|valve|bop|pressure\s+control|octg|casing|tubing|pipe|pipeline|midstream|hydrovac|vac\s+truck|vacuum\s+truck|water\s+hauling|fluid\s+hauling|saltwater|roustabout|winch|heavy\s+haul|rig\s+mov|bed\s+truck|hot\s*shot|pilot\s+car|crane|picker|rigging|welding|b-pressure|fabrication|machine\s+shop|ndt|inspection|artificial\s+lift|pumpjack|compressor|compression|tank|vessel|treater|separator|boiler|rental|downhole|fishing\s+tool|rig\s+mat|access\s+mat|lease\s+construction|earthwork|scada|instrumentation|automation|oilfield\s+electrical|h2s|industrial\s+medic|safety|fire\s+watch|remediation|reclamation|environmental|disposal|mud|chemical|lubricant|bulk\s+fuel|heavy\s+duty\s+mechanic|hydraulics|remote\s+camp|wellsite\s+trailer|skid\s+shack|surveying|geomatics|line\s+locat|training|courses|academy|institute|polytechnic|college|well\s+control|iwcf|wellsharp|opito|bosiet|safeland|veriforce|rigpass|confined\s+space|fall\s+protection|ground\s+disturbance|class\s+1|cdl\s+training)\b/iu;

const AGGREGATOR_DOMAIN_BLOCKLIST =
  /(?:google\.|gstatic\.|ggpht\.|facebook\.|instagram\.|linkedin\.|youtube\.|twitter\.|x\.com|yelp\.|yellowpages\.|yp\.ca|411\.ca|bbb\.org|mapquest\.|manta\.|cossd\.com|indeed\.|glassdoor\.|dnb\.com|zoominfo\.|chamberofcommerce\.)/iu;

const EXTRA_VALID_US_NPA = new Set([
  "205", "209", "214", "216", "217", "219", "231", "248", "251", "256", "269", "270", "281",
  "308", "309", "313", "316", "318", "330", "334", "337", "346", "361", "402", "405", "406",
  "408", "409", "412", "419", "432", "440", "469", "479", "501", "502", "504", "505", "512",
  "513", "517", "539", "559", "562", "572", "575", "580", "586", "601", "606", "614", "616",
  "618", "620", "661", "662", "681", "682", "701", "713", "714", "720", "724", "734", "740",
  "765", "785", "805", "806", "810", "812", "814", "815", "817", "818", "830", "832", "850",
  "859", "870", "903", "907", "915", "916", "918", "920", "928", "936", "937", "940", "956",
  "970", "972", "979", "985", "989",
]);

function findBrowserExe() {
  for (const c of [
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
  ]) {
    if (fs.existsSync(c)) return c;
  }
  throw new Error("No Chrome or Edge executable found.");
}

async function loadPlaywright() {
  for (const p of [
    "C:/Users/jordi/.gemini/antigravity/brain/89d324bb-a72f-4739-a356-b6b46e26db9a/scratch/flag-gen/node_modules/playwright-core/index.mjs",
    path.join(REPO_ROOT, "node_modules/playwright-core/index.mjs"),
  ]) {
    if (fs.existsSync(p)) return import(pathToFileURL(p).href);
  }
  return import("playwright-core");
}

function cleanWebsiteUrl(rawUrl) {
  const s = String(rawUrl || "").trim();
  if (!s) return "";
  try {
    let target = s;
    if (target.includes("google.com/url?")) {
      const u = new URL(target);
      target = u.searchParams.get("q") || u.searchParams.get("url") || target;
    }
    const parsed = new URL(target.startsWith("http") ? target : `https://${target}`);
    if (AGGREGATOR_DOMAIN_BLOCKLIST.test(parsed.hostname)) return "";
    return `${parsed.protocol}//${parsed.hostname}${parsed.pathname === "/" ? "" : parsed.pathname}`.slice(0, 220);
  } catch {
    return "";
  }
}

function polishDiscoveredCompanyName(rawName) {
  let s = String(rawName || "")
    .replace(/\s+-\s+(?:Main|North|South|East|West)\s+Campus$/iu, "")
    .trim();
  if (s.includes(" | ")) {
    const parts = s.split(" | ").map((x) => x.trim()).filter(Boolean);
    if (parts.length >= 2 && (parts.length > 2 || /\b(?:best|license|testing|courses)\b/iu.test(parts[1]))) {
      s = parts[0];
    }
  }
  s = canonicalizeCompanyName(s);
  s = s.replace(/\b(?:ndt|octg|h2s|hse|ehs|bop|iwcf|iadc|opito|cdl|osha|ems|cpr|llc|llp|plc)\b/giu, (m) =>
    m.toUpperCase(),
  );
  s = s.replace(/\b(?:ltd|inc|corp)\b\.?/giu, (m) => {
    const clean = m.replace(/\./gu, "").toLowerCase();
    return clean.charAt(0).toUpperCase() + clean.slice(1);
  });
  const connectors = new Set(["and", "of", "the", "in", "for", "on", "at", "to", "by", "de", "la"]);
  return s
    .split(/\s+/u)
    .map((w, idx) => (/^[a-z]{3,}$/u.test(w) && (idx === 0 || !connectors.has(w)) ? w[0].toUpperCase() + w.slice(1) : w))
    .join(" ");
}

function extractCertifications(textBlob) {
  const certs = new Set();
  if (/\b(?:h2s\s*alive|energy\s+safety\s+canada)\b/iu.test(textBlob)) certs.add("Energy Safety Canada / H2S Alive");
  if (/\b(?:iwcf|wellsharp|iadc)\b/iu.test(textBlob)) certs.add("IWCF / IADC WellSharp");
  if (/\b(?:safeland|safegulf|veriforce|pec)\b/iu.test(textBlob)) certs.add("PEC SafeLand / Veriforce");
  if (/\b(?:opito|bosiet|huet)\b/iu.test(textBlob)) certs.add("OPITO / IWCF");
  if (/\b(?:secor|\bcor\b)\b/iu.test(textBlob)) certs.add("COR / SECOR");
  if (/\bisnetworld\b/iu.test(textBlob)) certs.add("ISNetworld");
  if (/\bcomplyworks\b/iu.test(textBlob)) certs.add("ComplyWorks");
  if (/\babsa\b/iu.test(textBlob)) certs.add("ABSA");
  if (/\bapi\s*(?:q1|q2|spec)\b/iu.test(textBlob)) certs.add("API Spec Q1 / Q2");
  if (/\bcwb\b/iu.test(textBlob)) certs.add("CSA / CWB");
  return [...certs];
}

function escapeRx(str) {
  return String(str || "").replace(/[.*+?^${}()|[\]\\]/gu, "\\$&");
}

function buildRegionTownMatcher(knownTownsByRegion) {
  const compiled = new Map();
  for (const [rk, towns] of Object.entries(knownTownsByRegion || {})) {
    const clean = (towns || []).filter((t) => t && t.length >= 3);
    if (!clean.length) continue;
    const rx = new RegExp(`\\b(${clean.map(escapeRx).join("|")})\\b`, "iu");
    const canonicalLookup = new Map(clean.map((t) => [t.toLowerCase(), t]));
    compiled.set(rk, {rx, canonicalLookup});
  }
  return compiled;
}

async function mergeLocalDiscoveredIntoIndex(indexState) {
  if (!fs.existsSync(DISCOVERED_JSONL_PATH)) return;
  const raw = await fsp.readFile(DISCOVERED_JSONL_PATH, "utf8");
  for (const line of raw.split("\n")) {
    if (!line.trim()) continue;
    try {
      const obj = JSON.parse(line);
      const pr = obj.privateRecord || {};
      const rc = String(pr.regionCode || "").toUpperCase();
      const norm = pr.normalizedCompanyName || normalizedCompanyName(pr.companyName || "");
      if (norm && rc) indexState.existingNameRegion.add(`${norm}|${rc}`);
      for (const k of ["publicPhone", "tollFreePhone", "mainPhone"]) {
        const d10 = String(pr[k] || "").replace(/\D+/gu, "").slice(-10);
        if (d10.length === 10) {
          indexState.existingPhones.add(d10);
          if (pr.companyId) {
            if (!indexState.phoneToDocIds.has(d10)) indexState.phoneToDocIds.set(d10, []);
            const arr = indexState.phoneToDocIds.get(d10);
            if (!arr.includes(pr.companyId)) arr.push(pr.companyId);
          }
        }
      }
    } catch (_) {}
  }
}

async function loadExistingFirestoreIndex(projectId) {
  if (!REFRESH_INDEX && fs.existsSync(INDEX_CACHE_PATH)) {
    try {
      const cached = JSON.parse(await fsp.readFile(INDEX_CACHE_PATH, "utf8"));
      if (cached && Date.now() - Number(cached.fetchedAtMs || 0) < 90 * 60 * 1000) {
        const indexState = {
          existingPhones: new Set(cached.existingPhones || []),
          existingNameRegion: new Set(cached.existingNameRegion || []),
          phoneToDocIds: new Map(cached.phoneToDocIds || []),
          blockedPhones: new Set(cached.blockedPhones || []),
        };
        await mergeLocalDiscoveredIntoIndex(indexState);
        console.log(
          `[bot18] Loaded cached Firestore index + local ledger (${indexState.existingPhones.size} phones, ${indexState.existingNameRegion.size} companies).`,
        );
        return indexState;
      }
    } catch (_) {}
  }

  console.log(`[bot18] Loading existing Firestore phone & company index from ${projectId}...`);
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const existingPhones = new Set();
  const existingNameRegion = new Set();
  const phoneToDocIds = new Map();
  const blockedPhones = new Set();

  {
    const token = await resolveAccessToken(projectId);
    const res = await fetch(url, {
      method: "POST",
      headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
      body: JSON.stringify({structuredQuery: {from: [{collectionId: "yellow_pages_blocked_numbers"}], limit: 1000}}),
    });
    if (res.ok) {
      const rows = await res.json();
      for (const r of rows) {
        if (!r.document) continue;
        const id = r.document.name.split("/").pop().replace(/\D+/gu, "").slice(-10);
        if (id.length === 10) blockedPhones.add(id);
      }
    }
  }

  let lastDoc = null;
  let total = 0;
  while (true) {
    const token = await resolveAccessToken(projectId);
    const sq = {
      from: [{collectionId: "yellow_pages_public_entries"}],
      select: {
        fields: [
          {fieldPath: "companyName"},
          {fieldPath: "regionCode"},
          {fieldPath: "publicPhone"},
          {fieldPath: "tollFreePhone"},
        ],
      },
      orderBy: [{field: {fieldPath: "__name__"}, direction: "ASCENDING"}],
      limit: 3000,
    };
    if (lastDoc) sq.startAt = {values: [{referenceValue: lastDoc}], before: false};
    const res = await fetch(url, {
      method: "POST",
      headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
      body: JSON.stringify({structuredQuery: sq}),
    });
    if (!res.ok) break;
    const rows = await res.json();
    const docs = rows.filter((r) => r.document).map((r) => r.document);
    if (!docs.length) break;
    total += docs.length;
    lastDoc = docs[docs.length - 1].name;
    for (const d of docs) {
      const docId = d.name.split("/").pop();
      const f = d.fields || {};
      const name = f?.companyName?.stringValue || "";
      const rc = (f?.regionCode?.stringValue || "").toUpperCase();
      const norm = normalizedCompanyName(name);
      if (norm) existingNameRegion.add(`${norm}|${rc}`);
      for (const k of ["publicPhone", "tollFreePhone"]) {
        const d10 = String(f?.[k]?.stringValue || "").replace(/\D+/gu, "").slice(-10);
        if (d10.length === 10) {
          existingPhones.add(d10);
          if (!phoneToDocIds.has(d10)) phoneToDocIds.set(d10, []);
          phoneToDocIds.get(d10).push(docId);
        }
      }
    }
    if (docs.length < 3000) break;
  }

  const indexState = {existingPhones, existingNameRegion, phoneToDocIds, blockedPhones};
  await mergeLocalDiscoveredIntoIndex(indexState);
  await fsp.writeFile(
    INDEX_CACHE_PATH,
    JSON.stringify({
      fetchedAtMs: Date.now(),
      existingPhones: [...indexState.existingPhones],
      existingNameRegion: [...indexState.existingNameRegion],
      phoneToDocIds: [...indexState.phoneToDocIds.entries()],
      blockedPhones: [...indexState.blockedPhones],
    }),
    "utf8",
  );
  console.log(`[bot18] Indexed & cached ${total} live public entries (${indexState.existingPhones.size} phones).`);
  return indexState;
}

async function scrapeGoogleMapsQuery(page, task) {
  const searchUrl = `https://www.google.com/maps/search/${encodeURIComponent(task.query)}?hl=en`;
  await page.goto(searchUrl, {waitUntil: "domcontentloaded", timeout: 20000});

  const title = await page.title().catch(() => "");
  if (/before you continue/iu.test(title)) {
    const btn = await page.$('button[aria-label*="Accept"], form[action*="consent"] button');
    if (btn) await btn.click().catch(() => {});
  }

  await page
    .waitForSelector('div.Nv2PK, h1.DUwDvf, div.Q2vNVc, div[role="main"]', {timeout: 5500})
    .catch(() => {});
  await page.waitForTimeout(450);

  const initialCount = await page.evaluate(() => document.querySelectorAll("div.Nv2PK").length).catch(() => 0);
  if (initialCount >= 6) {
    for (let s = 0; s < 3; s++) {
      const scrolled = await page.evaluate(() => {
        const feed = document.querySelector('div[role="feed"]');
        if (!feed) return false;
        const prev = feed.scrollTop;
        feed.scrollTop = feed.scrollHeight;
        return feed.scrollTop > prev;
      });
      if (!scrolled) break;
      await page.waitForTimeout(350);
    }
  }

  return page.evaluate(() => {
    const cards = Array.from(document.querySelectorAll("div.Nv2PK"));
    if (cards.length > 0) {
      return cards.map((card) => {
        const placeLink = card.querySelector('a[href*="/maps/place/"]');
        const webLink = card.querySelector('a[data-value="Website"], a[aria-label*="website" i]');
        const phoneSpan = card.querySelector("span.UsdlK");
        const lines = card.innerText
          .split("\n")
          .map((s) => s.trim())
          .filter((s) => s.length > 0 && !/^[\ue000-\uf8ff]+$/u.test(s));
        return {
          name: placeLink?.getAttribute("aria-label") || lines[0] || "",
          phone: phoneSpan?.textContent?.trim() || "",
          website: webLink?.getAttribute("href") || "",
          placeUrl: placeLink?.href || "",
          lines,
        };
      });
    }

    // Fallback: Direct Single-Place Panel when a micro-town has exactly 1 matching business
    const h1 = document.querySelector("h1.DUwDvf");
    if (h1 && h1.textContent?.trim()) {
      const mainEl = document.querySelector('div[role="main"]') || document.body;
      const phoneBtn = mainEl.querySelector('button[data-item-id^="phone:tel:"], [aria-label*="Phone:" i]');
      let phone = "";
      const dtid = phoneBtn?.getAttribute("data-item-id") || "";
      if (dtid.startsWith("phone:tel:")) {
        phone = dtid.replace("phone:tel:", "").trim();
      } else {
        phone = phoneBtn?.textContent?.trim() || "";
      }
      const webLink = mainEl.querySelector('a[data-item-id="authority"], a[aria-label*="Website:" i]');
      const addrBtn = mainEl.querySelector('button[data-item-id="address"], [aria-label*="Address:" i]');
      const catBtn = mainEl.querySelector('button[jsaction*="pane.rating.category"]');
      const rawLines = (mainEl.innerText || "")
        .split("\n")
        .map((s) => s.trim())
        .filter((s) => s.length > 0 && s.length < 180 && !/^[\ue000-\uf8ff]+$/u.test(s))
        .slice(0, 25);
      const extra = [catBtn?.textContent?.trim(), addrBtn?.textContent?.trim()].filter(Boolean);
      return [
        {
          name: h1.textContent.trim(),
          phone,
          website: webLink?.getAttribute("href") || "",
          placeUrl: location.href,
          lines: [...extra, ...rawLines],
        },
      ];
    }

    return [];
  });
}

function validateAndResolveMicrotownCard(card, task, indexState, regionTownMatchers, dynamicTownBuffer, seqNum) {
  const fullText = [card.name, ...card.lines].join(" · ");

  // 1. Permanently/temporarily closed check
  if (/\b(?:permanently\s+closed|temporarily\s+closed)\b/iu.test(fullText)) {
    const pNorm = normalizeNorthAmericanPhone(card.phone);
    if (pNorm.validNanpa && indexState.phoneToDocIds.has(pNorm.digits10)) {
      return {status: "closed_existing", docIds: indexState.phoneToDocIds.get(pNorm.digits10), isLocalToTaskTown: false};
    }
    return {status: "rejected_closed", isLocalToTaskTown: false};
  }

  // 2. Company name polish & consumer noise filter
  const cleanName = polishDiscoveredCompanyName(card.name);
  if (!cleanName || cleanName.length < 3) return {status: "rejected_invalid", isLocalToTaskTown: false};
  if (CONSUMER_NOISE_BLOCKLIST.test(fullText)) return {status: "rejected_noise", isLocalToTaskTown: false};

  if (!POSITIVE_OILFIELD_OR_TRAINING_SIGNAL.test(fullText)) {
    if (
      !/\b(?:industrial|equipment|contractor|supply|supplier|transport|freight|logistics|machining|steel|manufactur|engineering|testing|laboratory|safety|training)\b/iu.test(
        fullText,
      )
    ) {
      return {status: "rejected_non_oilfield", isLocalToTaskTown: false};
    }
  }
  if (task.isTrainingQuery) {
    if (
      !/\b(?:safety|oilfield|energy|well\s+control|h2s|iwcf|opito|safeland|industrial|emergency|first\s+aid|rescue|confined\s+space|fall\s+protection|crane|rigging|truck|driver|cdl|class\s+1|weld|ndt|polytechnic|college|institute|technical|occupational|compliance|enviro|training\s+cent(?:er|re)|simulated\s+worksite)\b/iu.test(
        fullText,
      )
    ) {
      return {status: "rejected_non_oilfield_school", isLocalToTaskTown: false};
    }
  }

  // 3. Phone validation & foreign 09xx/+xx gate
  let rawPhone = String(card.phone || "").trim();
  if (/^(?:09\d\d|\+(?!1\b)\d+)/u.test(rawPhone)) {
    return {status: "rejected_foreign_phone", isLocalToTaskTown: false};
  }
  if (!rawPhone) {
    const m = fullText.match(/(?:\+?1[\s.-]?)?\(?([2-9]\d{2})\)?[\s.-]?(\d{3})[\s.-]?(\d{4})\b/u);
    if (m) rawPhone = `${m[1]}-${m[2]}-${m[3]}`;
  }
  const phoneNorm = normalizeNorthAmericanPhone(rawPhone);
  if (!phoneNorm.validNanpa) return {status: "rejected_no_phone", isLocalToTaskTown: false};
  if (indexState.blockedPhones.has(phoneNorm.digits10)) return {status: "rejected_blocked", isLocalToTaskTown: false};

  // 4. NANPA Area-Code + True-Town Intra-Province/State Geo-Resolver
  const npa = phoneNorm.digits10.slice(0, 3);
  const phoneGeo = inferGeoFromNanpaPhone(phoneNorm.digits10);
  const targetCc = task.countryCode;
  const finalRc = canonicalizeRegionCode(task.regionCode, targetCc);
  const targetCityCanon = canonicalizeCityName(task.city, finalRc, targetCc);
  const taskCityRx = new RegExp(`\\b${escapeRx(task.city)}\\b`, "iu");
  const explicitlyMentionsTaskCity = taskCityRx.test(fullText);

  if (phoneGeo && !phoneGeo.isTollFree) {
    if (phoneGeo.countryCode !== targetCc) {
      return {status: "rejected_zoom_out_country", isLocalToTaskTown: false};
    }
    if (phoneGeo.regionCode !== finalRc && !explicitlyMentionsTaskCity) {
      return {status: "rejected_zoom_out_region", isLocalToTaskTown: false};
    }
  } else if (phoneNorm.isTollFree) {
    const otherStateMatch = fullText.match(/,\s*([A-Z]{2})\s+\d{5}\b/u);
    if (otherStateMatch && otherStateMatch[1] !== finalRc) {
      return {status: "rejected_zoom_out_tollfree", isLocalToTaskTown: false};
    }
    if (!explicitlyMentionsTaskCity) {
      // Toll-free cards on small micro-towns must mention the town to avoid national-ad zoom-outs
      return {status: "rejected_tollfree_nonlocal", isLocalToTaskTown: false};
    }
  } else {
    if (targetCc !== "US" || !EXTRA_VALID_US_NPA.has(npa) || !explicitlyMentionsTaskCity) {
      return {status: "rejected_unmapped_npa", isLocalToTaskTown: false};
    }
  }

  // Determine True Canonical City (prevents assigning intra-state zoom-outs to the small micro-town)
  let resolvedCity = targetCityCanon;
  let isLocalToTaskTown = explicitlyMentionsTaskCity;

  if (!explicitlyMentionsTaskCity) {
    const addressText = card.lines
      .join(" · ")
      .replace(/\b(?:Business|Industrial|Office|Corporate|Commerce)\s+Park\b/giu, "")
      .replace(/\bPark\s+(?:Dr|Drive|Rd|Road|St|Street|Ave|Blvd|Ln|Way|Pkwy)\b/giu, "");
    const matcher = regionTownMatchers.get(`${targetCc}:${finalRc}`);
    const otherMatch = matcher ? addressText.match(matcher.rx) : null;
    if (otherMatch && !/^(?:Park|Oklahoma|Texas|Kansas|Alberta)$/iu.test(otherMatch[1].trim())) {
      const matchedCanon =
        matcher.canonicalLookup.get(otherMatch[1].toLowerCase()) ||
        canonicalizeCityName(otherMatch[1], finalRc, targetCc);
      resolvedCity = matchedCanon;
      isLocalToTaskTown = normalizeCityKey(matchedCanon) === normalizeCityKey(targetCityCanon);
    } else {
      // Check if address contains ", <NewRuralTown>, <RC>"
      const dynMatch = addressText.match(/,\s*([A-Z][a-zA-Z.' -]{2,28}),\s*([A-Z]{2})\b/u);
      if (dynMatch && dynMatch[2] === finalRc) {
        const dynCity = canonicalizeCityName(dynMatch[1], finalRc, targetCc);
        if (dynCity && !/\b(?:Ave|St|Rd|Dr|Blvd|Hwy|Fwy|County|Twp|Rge)\b/iu.test(dynCity)) {
          resolvedCity = dynCity;
          isLocalToTaskTown = normalizeCityKey(dynCity) === normalizeCityKey(targetCityCanon);
          dynamicTownBuffer.push({countryCode: targetCc, regionCode: finalRc, city: dynCity});
        }
      } else if (phoneGeo?.cityHint) {
        resolvedCity = canonicalizeCityName(phoneGeo.cityHint, finalRc, targetCc);
        isLocalToTaskTown = normalizeCityKey(resolvedCity) === normalizeCityKey(targetCityCanon);
      } else {
        // Rural range road / highway / street in same area code & state
        resolvedCity = targetCityCanon;
        isLocalToTaskTown = true;
      }
    }
  }

  const normName = normalizedCompanyName(cleanName);
  if (!normName) return {status: "rejected_invalid", isLocalToTaskTown: false};

  // 5. Deduplicate against existing Firestore + current session
  if (
    indexState.existingPhones.has(phoneNorm.digits10) ||
    indexState.existingNameRegion.has(`${normName}|${finalRc}`)
  ) {
    return {status: "duplicate_existing", isLocalToTaskTown};
  }

  indexState.existingPhones.add(phoneNorm.digits10);
  indexState.existingNameRegion.add(`${normName}|${finalRc}`);

  // 6. Extract street address & classify categories (UNVERIFIED / free_basic)
  let streetAddress = "";
  for (const line of card.lines) {
    if (/^\d\.\d\s*\(/u.test(line) || /^Open\b|^Closed\b|^Closes\b/iu.test(line)) continue;
    if (line.includes("·")) {
      const parts = line
        .split("·")
        .map((p) => p.replace(/[^\x20-\x7E]/gu, "").trim())
        .filter(Boolean);
      const addrPart = parts.find(
        (p) => /\d+\s+[A-Za-z0-9]/u.test(p) || /\b(?:Ave|St|Rd|Dr|Blvd|Hwy|Fwy|Pkwy|Way|Ln|Ct|Twp|Rge|FM|CR)\b/iu.test(p),
      );
      if (addrPart) {
        streetAddress = addrPart.slice(0, 140);
        break;
      }
    }
  }

  const website = cleanWebsiteUrl(card.website);
  const emergency24x7 = /\b(?:open\s+24\s+hours|24\/7|24\s*hr)\b/iu.test(fullText);
  const gmapsTypeHint =
    card.lines.find((l) => l.includes("·") && !/^Open|^Closed/iu.test(l))?.split("·")[0]?.trim() || "";
  const rawHints = [cleanName, gmapsTypeHint, task.isTrainingQuery ? "Oilfield Safety Training Courses" : ""].filter(
    Boolean,
  );
  let catCodes = classifyCategoriesFromText(rawHints, fullText).filter((c) => CATEGORY_BY_CODE.has(c));
  if (task.isTrainingQuery && !catCodes.includes("oil_gas_training_courses")) {
    catCodes = ["oil_gas_training_courses", ...catCodes];
  }
  if (catCodes.length === 0) catCodes = [task.defaultCat];
  catCodes = [...new Set(catCodes)].slice(0, 6);
  const categories = catCodes.map((c) => CATEGORY_BY_CODE.get(c)?.label || c);

  const services = [];
  if (gmapsTypeHint && gmapsTypeHint.length <= 48 && !/^\d/u.test(gmapsTypeHint)) services.push(gmapsTypeHint);
  if (task.isTrainingQuery) {
    if (/\bh2s\b/iu.test(fullText)) services.push("H2S Alive Training");
    if (/\b(?:well\s+control|iwcf|wellsharp)\b/iu.test(fullText)) services.push("Well Control Training");
    if (/\b(?:safeland|veriforce|rigpass)\b/iu.test(fullText)) services.push("SafeLand / RigPass Orientation");
    if (services.length <= 1) services.push("Oil & Gas Safety & Technical Courses");
  }

  const geo = inferCountryAndRegion(targetCc, finalRc);
  const certifications = extractCertifications(fullText);
  const nowIso = new Date().toISOString();
  const slug = normName.replace(/[^a-z0-9]+/gu, "-").replace(/^-+|-+$/gu, "").slice(0, 48);
  const companyId = `gmaps-mt-${targetCc.toLowerCase()}-${finalRc.toLowerCase()}-${slug}-${phoneNorm.digits10.slice(-4)}-${seqNum}`;

  const privateRecord = {
    schemaVersion: 2,
    companyId,
    discoveryChannel: task.isTrainingQuery ? "google_maps_microtown_training" : "google_maps_microtown_audit",
    companyName: cleanName,
    normalizedCompanyName: normName,
    countryCode: geo.countryCode,
    regionCode: geo.regionCode,
    regionName: geo.regionName,
    city: resolvedCity,
    postalCode: "",
    streetAddress,
    mainPhone: phoneNorm.isTollFree ? "" : phoneNorm.display,
    publicPhone: phoneNorm.display,
    tollFreePhone: phoneNorm.isTollFree ? phoneNorm.display : "",
    legacyPhones: [],
    phoneHistory: [],
    generalEmail: "",
    publicEmail: "",
    website,
    powerUnits: 0,
    categoryCodes: catCodes,
    categories,
    services: [...new Set(services)].slice(0, 8),
    basins: geo.defaultBasins || [],
    serviceAreas: [resolvedCity, geo.regionName].filter(Boolean),
    certifications,
    emergency24x7,
    description: "",
    verificationStatus: "unverified",
    operationalStatus: "active_in_operation",
    outreachStatus: "not_contacted",
    billingStatus: "unpaid",
    listingTier: "free_basic",
    nonExpiringPaid: false,
    allowUnpaidPublic: true,
    publicationStatus: "published",
    adminViewingEnabled: true,
    isFlaggedProhibited: false,
    flagReason: "",
    doNotContact: false,
    sourceReferences: [
      {
        sourceType: "google_maps_microtown_audit",
        sourceName: `Google Maps ${targetCc} Micro-Town Exhaustive Audit (Stage ${task.stage})`,
        sourceUrl: card.placeUrl || "",
        sourceExternalId: phoneNorm.digits10,
        observedAt: nowIso,
        bookPage: "",
      },
    ],
    liveAuditSummary: {
      auditedAt: nowIso,
      googleMapsActive: true,
      queryId: task.id,
      resolvedTrueCity: resolvedCity,
    },
    publishedAt: nowIso,
    createdAt: nowIso,
    updatedAt: nowIso,
  };
  privateRecord.adminSearchTokens = buildAdminSearchTokens(privateRecord);
  const publicEntry = buildPublicEntry(privateRecord, companyId, nowIso);

  return {
    status: "accepted",
    isLocalToTaskTown,
    privateRecord,
    publicEntry,
    isTraining: catCodes.includes("oil_gas_training_courses") || task.isTrainingQuery,
  };
}

async function syncBatchToFirestore(projectId, records, closedDocIds = []) {
  if (!records.length && !closedDocIds.length) return;
  const commitUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;

  const chunkSize = 25;
  for (let i = 0; i < records.length; i += chunkSize) {
    const slice = records.slice(i, i + chunkSize);
    const writes = [];
    for (const item of slice) {
      const privFields = {};
      for (const [k, v] of Object.entries(item.privateRecord)) {
        if (v !== undefined) privFields[k] = toFirestoreValue(v, k);
      }
      writes.push({
        update: {
          name: `projects/${projectId}/databases/(default)/documents/yellow_pages_companies/${encodeURIComponent(item.privateRecord.companyId)}`,
          fields: privFields,
        },
      });
      if (item.publicEntry) {
        const pubFields = {};
        for (const [k, v] of Object.entries(item.publicEntry)) {
          if (v !== undefined) pubFields[k] = toFirestoreValue(v, k);
        }
        writes.push({
          update: {
            name: `projects/${projectId}/databases/(default)/documents/yellow_pages_public_entries/${encodeURIComponent(item.privateRecord.companyId)}`,
            fields: pubFields,
          },
        });
      }
    }
    const token = await resolveAccessToken(projectId);
    const res = await fetch(commitUrl, {
      method: "POST",
      headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
      body: JSON.stringify({writes}),
      signal: AbortSignal.timeout(40000),
    });
    if (!res.ok) {
      console.error(`[bot18] Firestore batch sync HTTP ${res.status}: ${await res.text()}`);
    }
  }

  if (closedDocIds.length > 0) {
    const uniqueClosed = [...new Set(closedDocIds)];
    const writes = [];
    const nowIso = new Date().toISOString();
    for (const docId of uniqueClosed.slice(0, 100)) {
      writes.push({
        delete: `projects/${projectId}/databases/(default)/documents/yellow_pages_public_entries/${encodeURIComponent(docId)}`,
      });
      writes.push({
        update: {
          name: `projects/${projectId}/databases/(default)/documents/yellow_pages_companies/${encodeURIComponent(docId)}`,
          fields: {
            operationalStatus: {stringValue: "closed_inactive"},
            publicationStatus: {stringValue: "unpublished"},
            updatedAt: {timestampValue: nowIso},
          },
        },
        updateMask: {fieldPaths: ["operationalStatus", "publicationStatus", "updatedAt"]},
      });
    }
    const token = await resolveAccessToken(projectId);
    await fetch(commitUrl, {
      method: "POST",
      headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
      body: JSON.stringify({writes}),
      signal: AbortSignal.timeout(30000),
    }).catch(() => {});
  }
}

async function main() {
  if (!fs.existsSync(QUEUE_PATH) || !fs.existsSync(STATE_PATH)) {
    throw new Error("Run bot17_microtown_atlas_planner.mjs first to generate the micro-town frontier queue.");
  }

  const queueDoc = JSON.parse(await fsp.readFile(QUEUE_PATH, "utf8"));
  const state = JSON.parse(await fsp.readFile(STATE_PATH, "utf8"));
  const visitedSet = new Set(state.visitedQueryIds || []);

  const filteredQueue = (queueDoc.queue || [])
    .filter((q) => !visitedSet.has(q.id) && (!COUNTRY_FILTER || q.countryCode === COUNTRY_FILTER))
    .slice(0, WAVE_SIZE);

  if (filteredQueue.length === 0) {
    console.log("[bot18] 0 pending queries in current frontier wave — ready for planner escalation or converged!");
    process.exit(0);
  }

  const regionTownMatchers = buildRegionTownMatcher(queueDoc.knownTownsByRegion || {});
  const indexState = await loadExistingFirestoreIndex(PROJECT_ID);

  console.log(
    `[bot18] Starting Micro-Town Wave (${filteredQueue.length} queries across ${NUM_AGENTS} Chromium agents, sync=${SYNC})...`,
  );

  const {chromium} = await loadPlaywright();
  const browser = await chromium.launch({
    executablePath: findBrowserExe(),
    headless: true,
    args: [
      "--disable-blink-features=AutomationControlled",
      "--disable-gpu",
      "--disable-dev-shm-usage",
      "--renderer-process-limit=24",
    ],
  });

  const waveStats = {
    startedAt: new Date().toISOString(),
    queriesCompleted: 0,
    cardsInspected: 0,
    newBusinesses: 0,
    newCanada: 0,
    newUSA: 0,
    newTraining: 0,
    duplicates: 0,
    closedRemoved: 0,
    rejectedNoiseOrZoomOut: 0,
  };

  let cursor = 0;
  let seqCounter = Date.now() % 100000;
  const unsyncedBuffer = [];
  const closedBuffer = [];
  const dynamicTownBuffer = [];
  let persistChain = Promise.resolve();

  const persistProgress = () => {
    persistChain = persistChain
      .then(async () => {
        state.visitedQueryIds = [...visitedSet];
        state.updatedAt = new Date().toISOString();
        await fsp.writeFile(STATE_PATH, JSON.stringify(state, null, 2), "utf8");

        if (dynamicTownBuffer.length > 0) {
          const batch = dynamicTownBuffer.splice(0, dynamicTownBuffer.length);
          await fsp.appendFile(DYNAMIC_TOWNS_PATH, `${batch.map((d) => JSON.stringify(d)).join("\n")}\n`, "utf8");
        }

        if (SYNC && (unsyncedBuffer.length > 0 || closedBuffer.length > 0)) {
          const toSync = unsyncedBuffer.splice(0, unsyncedBuffer.length);
          const toClose = closedBuffer.splice(0, closedBuffer.length);
          await syncBatchToFirestore(PROJECT_ID, toSync, toClose);
        }

        const md = [
          "# Bot 18 — Latest Micro-Town Harvester Wave Report",
          "",
          `- **Updated At**: \`${new Date().toISOString()}\``,
          `- **Wave Queries Completed**: **${waveStats.queriesCompleted} / ${filteredQueue.length}**`,
          `- **Google Business Cards Inspected**: **${waveStats.cardsInspected.toLocaleString()}**`,
          `- **New Businesses Discovered in Wave**: **${waveStats.newBusinesses.toLocaleString()}** (\`CA\`: **${waveStats.newCanada}**, \`US\`: **${waveStats.newUSA}**, \`Training\`: **${waveStats.newTraining}**)`,
          `- **Existing Active Verified**: **${waveStats.duplicates.toLocaleString()}**`,
          `- **Closed Businesses Unpublished**: **${waveStats.closedRemoved}**`,
          `- **Zoom-Out / Consumer Noise Blocked**: **${waveStats.rejectedNoiseOrZoomOut.toLocaleString()}**`,
          "",
        ];
        await fsp.writeFile(WAVE_REPORT_PATH, md.join("\n"), "utf8");
      })
      .catch((err) => console.warn(`[bot18] persistProgress warning: ${err.message}`));
    return persistChain;
  };

  const openSession = async () => {
    const context = await browser.newContext({
      userAgent: USER_AGENT,
      locale: "en-US",
      viewport: {width: 1280, height: 900},
    });
    await context.route("**/*", (route) => {
      const req = route.request();
      const rt = req.resourceType();
      if (rt === "image" || rt === "media" || rt === "font") return route.abort();
      const url = req.url();
      if (
        /\/maps\/vt|\/kh\/|streetview|photometa|ggpht\.com|googleusercontent\.com|play\.google\.com\/log|gen_204/iu.test(
          url,
        )
      ) {
        return route.abort();
      }
      return route.continue();
    });
    const page = await context.newPage();
    return {context, page};
  };

  try {
    const workers = Array.from({length: NUM_AGENTS}, async (_, idx) => {
      const agentName = `MT-Agent-${idx + 1}`;
      let session = await openSession();
      let sessionQueries = 0;

      while (true) {
        const myIdx = cursor++;
        if (myIdx >= filteredQueue.length) break;
        const task = filteredQueue[myIdx];

        if (sessionQueries >= 25) {
          await Promise.race([session.context.close().catch(() => {}), new Promise((r) => setTimeout(r, 2500))]);
          session = await openSession();
          sessionQueries = 0;
        }

        try {
          let timerId = null;
          const cards = await Promise.race([
            scrapeGoogleMapsQuery(session.page, task),
            new Promise((_, rej) => {
              timerId = setTimeout(() => rej(new Error("Watchdog 26000ms")), 26000);
            }),
          ]).finally(() => {
            if (timerId) clearTimeout(timerId);
          });

          sessionQueries += 1;
          waveStats.queriesCompleted += 1;
          waveStats.cardsInspected += cards.length;
          visitedSet.add(task.id);

          let localOilfieldCardsInQuery = 0;
          let localNewInQuery = 0;
          const jsonlLines = [];

          for (const card of cards) {
            seqCounter += 1;
            const res = validateAndResolveMicrotownCard(
              card,
              task,
              indexState,
              regionTownMatchers,
              dynamicTownBuffer,
              seqCounter,
            );
            if (res.status === "accepted") {
              waveStats.newBusinesses += 1;
              if (res.privateRecord.countryCode === "CA") waveStats.newCanada += 1;
              if (res.privateRecord.countryCode === "US") waveStats.newUSA += 1;
              if (res.isTraining) waveStats.newTraining += 1;
              if (res.isLocalToTaskTown) {
                localOilfieldCardsInQuery += 1;
                localNewInQuery += 1;
              }
              // Credit true resolved town's totalNewBusinesses as well
              const trueTownKey = `${res.privateRecord.countryCode}|${res.privateRecord.regionCode}|${normalizeCityKey(res.privateRecord.city)}`;
              if (state.towns[trueTownKey]) {
                state.towns[trueTownKey].totalNewBusinesses =
                  (state.towns[trueTownKey].totalNewBusinesses || 0) + 1;
              }
              jsonlLines.push(JSON.stringify({privateRecord: res.privateRecord, publicEntry: res.publicEntry}));
              unsyncedBuffer.push(res);
            } else if (res.status === "duplicate_existing") {
              waveStats.duplicates += 1;
              if (res.isLocalToTaskTown) localOilfieldCardsInQuery += 1;
            } else if (res.status === "closed_existing") {
              waveStats.closedRemoved += res.docIds.length;
              closedBuffer.push(...res.docIds);
            } else {
              waveStats.rejectedNoiseOrZoomOut += 1;
            }
          }

          // Update Stage Escalation counters on task's micro-town
          const townEntry = state.towns[task.townKey];
          if (townEntry) {
            townEntry.totalLocalCards = (townEntry.totalLocalCards || 0) + localOilfieldCardsInQuery;
            const st = townEntry.stageStats[task.stage] || {queriesDone: 0, localCards: 0, newBusinesses: 0};
            st.localCards += localOilfieldCardsInQuery;
            st.newBusinesses += localNewInQuery;
            townEntry.stageStats[task.stage] = st;
          }

          if (jsonlLines.length > 0) {
            await fsp.appendFile(DISCOVERED_JSONL_PATH, `${jsonlLines.join("\n")}\n`, "utf8");
          }

          if (waveStats.queriesCompleted % 20 === 0) {
            console.log(
              `[${agentName}] Wave ${waveStats.queriesCompleted}/${filteredQueue.length} | Cards: ${waveStats.cardsInspected} | NEW: ${waveStats.newBusinesses} (CA=${waveStats.newCanada}, US=${waveStats.newUSA}, Training=${waveStats.newTraining}) | Dups: ${waveStats.duplicates}`,
            );
            await persistProgress();
          }
        } catch (err) {
          console.warn(`[${agentName}] Query timeout/err (${task.id}): ${err.message}`);
          // Mark query visited if it timed out so single bad queries never block stage transitions
          visitedSet.add(task.id);
          await Promise.race([session.context.close().catch(() => {}), new Promise((r) => setTimeout(r, 2500))]);
          session = await Promise.race([
            openSession(),
            new Promise((_, rej) => setTimeout(() => rej(new Error("reopen timeout")), 6000)),
          ]).catch(() => session);
          sessionQueries = 0;
        }
      }

      await Promise.race([session.context.close().catch(() => {}), new Promise((r) => setTimeout(r, 2500))]);
    });

    await Promise.all(workers);
    await persistProgress();
  } finally {
    await Promise.race([browser.close().catch(() => {}), new Promise((r) => setTimeout(r, 3000))]);
  }

  console.log("[bot18] Micro-Town Wave Complete!", waveStats);
  process.exit(0);
}

main().catch((err) => {
  console.error("[bot18] FATAL:", err);
  process.exit(1);
});
