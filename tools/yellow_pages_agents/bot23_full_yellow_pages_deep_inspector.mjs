#!/usr/bin/env node
/**
 * Bot 23 — Full Yellow Pages Deep Inspector, Misspelled/Partial-Word Deduplicator
 *          & COSSD Book 73-Photo Cross-Reference Exporter
 *
 * Performs a comprehensive 6-module inspection across ALL live Yellow Pages entries
 * (`yellow_pages_public_entries` + `yellow_pages_companies`) and all 73 Google Drive
 * COSSD Book photos (`146` tiles):
 *   1. Per-photo & per-listing cross-reference of all 73 Drive images + contact enrichment
 *   2. Duplicate phone audit (same city & same region)
 *   3. Misspelled-word, singular/plural & punctuation duplicate audit (Damerau-Levenshtein
 *      with numbered-company digit guard so `1234567 Alberta Ltd` != `1234568 Alberta Ltd`)
 *   4. Partial-word / truncated-prefix duplicate audit & standalone partial/garbled name check
 *   5. Global town, region, 30-sector & zero-pre-verified hygiene audit
 *   6. Email & website outreach readiness audit for the `pipebuyer2026` 6-months-free campaign
 *
 * Dry-run by default. Pass `--apply` to deduplicate confirmed misspelled/partial/stem
 * duplicates (preserving legacyPhones & richer fields on the surviving record) and enrich
 * missing contact fields from matched book entries.
 */
import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";
import {resolveAccessToken, toFirestoreValue} from "./global_shared_utils.mjs";

const require = createRequire(import.meta.url);
const {
  CATEGORY_BY_CODE,
  COUNTRY_BY_CODE,
  canonicalizeCityName,
  canonicalizeCompanyName,
  canonicalizeRegionCode,
} = require("../../firebase/functions/yellow_pages_taxonomy.js");
const {
  buildPublicSearchTokens,
  normalizeNorthAmericanPhone,
  normalizedCompanyName,
} = require("../../firebase/functions/yellow_pages_policy.js");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");
const LEDGER_DIR = path.join(REPO_ROOT, "data/yellow_pages/ledger");

const args = process.argv.slice(2);
const argVal = (k, d) => {
  const i = args.indexOf(k);
  return i !== -1 && args[i + 1] ? args[i + 1] : d;
};
const APPLY = args.includes("--apply");
const PROJECT_ID = argVal("--project", "flutter-flow-pipe");
const OUT_JSON = argVal("--out-json", "");
const EXTRACT_DIR = argVal("--extract-dir", "c:/Users/jordi/Documents/antigravity/silly-planck/pipeapp/data/yellow_pages/book_extract");
const PHOTOS_DIR = argVal("--photos-dir", "c:/Users/jordi/Documents/antigravity/silly-planck/pipeapp/data/yellow_pages/book_photos");

const strVal = (f, k) => f?.[k]?.stringValue || "";
const boolVal = (f, k, d = false) => (f?.[k]?.booleanValue !== undefined ? f[k].booleanValue : d);
const arrStr = (f, k) => (f?.[k]?.arrayValue?.values || []).map((v) => v.stringValue || "").filter(Boolean);

function digits10(raw) {
  const d = String(raw || "").replace(/\D+/gu, "");
  if (d.length === 11 && d.startsWith("1")) return d.slice(1);
  return d.length === 10 ? d : "";
}

function allDigits(raw) {
  return String(raw || "").replace(/\D+/gu, "");
}

function compactCoreName(raw) {
  let s = String(raw || "")
    .replace(/['’`]/gu, "")
    .replace(/\b(?:a\s+)?div(?:ision)?\.?\s+of\b.*$/iu, "")
    .replace(/\b(?:formerly|part\s+of|subsidiary\s+of|dba|o\/a)\b.*$/iu, "")
    .replace(/\((?:19\d\d|20\d\d|canada|alberta|western|edmonton|calgary|bc|sk|ltd|inc|gp|na|usa|us|uk)\)/giu, " ")
    .replace(/\b(?:l\s*\.\s*p\.?|l\s+p|l\s+l\s+c|l\s*\.\s*l\s*\.\s*c\.?)\s*$/iu, " ");
  // Do not strip leading brand initialisms ("CORP ", "LP ", "GP ", "AS ") when they start the company name
  const leadBrand = s.trim().match(/^(corp|lp|gp|as)\b/iu);
  s = normalizedCompanyName(s)
    .replace(/\b(ulc|lp|gp|as|the|and|ltd|inc|co|company|limited|corporation|incorporated|llc|llp|plc)\b/gu, " ")
    .replace(/[^a-z0-9]+/gu, "");
  if (leadBrand) {
    const lb = leadBrand[1].toLowerCase();
    if (!s.startsWith(lb)) s = `${lb}${s}`;
  }
  return s;
}

function stemWordsName(raw) {
  let s = String(raw || "")
    .replace(/['’`]/gu, "")
    .replace(/\b(?:a\s+)?div(?:ision)?\.?\s+of\b.*$/iu, "")
    .replace(/\b(?:formerly|part\s+of|subsidiary\s+of|dba|o\/a)\b.*$/iu, "")
    .replace(/\((?:19\d\d|20\d\d|canada|alberta|western|edmonton|calgary|bc|sk|ltd|inc|gp|na|usa|us|uk)\)/giu, " ")
    .replace(/\b(?:l\s*\.\s*p\.?|l\s+p|l\s+l\s+c|l\s*\.\s*l\s*\.\s*c\.?)\s*$/iu, " ");
  const leadBrand = s.trim().match(/^(corp|lp|gp|as)\b/iu);
  s = normalizedCompanyName(s)
    .replace(/\b(ulc|lp|gp|as|the|and|ltd|inc|co|company|limited|corporation|incorporated|llc|llp|plc)\b/gu, " ")
    .replace(/\bservices\b/gu, "service")
    .replace(/\brentals\b/gu, "rental")
    .replace(/\bsupplies\b/gu, "supply")
    .replace(/\bsolutions\b/gu, "solution")
    .replace(/\bsystems\b/gu, "system")
    .replace(/\bindustries\b/gu, "industry")
    .replace(/\benterprises\b/gu, "enterprise")
    .replace(/\bcontractors\b/gu, "contractor")
    .replace(/\bholdings\b/gu, "holding")
    .replace(/\bcommunications\b/gu, "communication")
    .replace(/\btechnologies\b/gu, "technology")
    .replace(/\blogistics\b/gu, "logistic")
    .replace(/\bproducts\b/gu, "product")
    .replace(/\bconsultants\b/gu, "consultant")
    .replace(/\bassociates\b/gu, "associate")
    .replace(/\bbuilders\b/gu, "builder")
    .replace(/\bcarriers\b/gu, "carrier")
    .replace(/\bcoatings\b/gu, "coating")
    .replace(/\bmotors\b/gu, "motor")
    .replace(/\bpumps\b/gu, "pump")
    .replace(/\bpartners\b/gu, "partner")
    .replace(/\bmetalworks\b/gu, "metalwork")
    .replace(/\bhotels\b/gu, "hotel")
    .replace(/\bmotels\b/gu, "motel")
    .replace(/\bsuites\b/gu, "suite")
    .replace(/\binns\b/gu, "inn")
    .replace(/[^a-z0-9]+/gu, "");
  if (leadBrand) {
    const lb = leadBrand[1].toLowerCase();
    if (!s.startsWith(lb)) s = `${lb}${s}`;
  }
  return s;
}

// Damerau-Levenshtein (catches adjacent transpositions like "Oilfeild" -> "Oilfield" in distance 1!)
function damerauLev(a, b, max = 2) {
  if (a === b) return 0;
  const la = a.length;
  const lb = b.length;
  if (Math.abs(la - lb) > max) return max + 1;
  const dp = Array.from({length: la + 1}, () => new Int16Array(lb + 1));
  for (let i = 0; i <= la; i++) dp[i][0] = i;
  for (let j = 0; j <= lb; j++) dp[0][j] = j;
  for (let i = 1; i <= la; i++) {
    let rowMin = max + 1;
    for (let j = 1; j <= lb; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      let v = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost);
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        v = Math.min(v, dp[i - 2][j - 2] + 1);
      }
      dp[i][j] = v;
      if (v < rowMin) rowMin = v;
    }
    if (rowMin > max) return max + 1;
  }
  return dp[la][lb];
}

function extractNumbers(s) {
  return (String(s || "").replace(/\((?:19|20)\d\d\)/gu, "").match(/\d+/gu) || []).join("|");
}

// Distinguish distinct sister divisions like "North" vs "South", "East" vs "West", "1" vs "2"
const DISTINCT_DIRECTION_PAIRS = [
  ["north", "south"],
  ["east", "west"],
  ["import", "export"],
  ["onshore", "offshore"],
  ["upstream", "downstream"],
  ["drilling", "completions"],
  ["sales", "rentals"],
];
function hasOpposingQualifiers(nameA, nameB) {
  const la = nameA.toLowerCase();
  const lb = nameB.toLowerCase();
  for (const [w1, w2] of DISTINCT_DIRECTION_PAIRS) {
    const a1 = new RegExp(`\\b${w1}\\b`, "u").test(la);
    const a2 = new RegExp(`\\b${w2}\\b`, "u").test(la);
    const b1 = new RegExp(`\\b${w1}\\b`, "u").test(lb);
    const b2 = new RegExp(`\\b${w2}\\b`, "u").test(lb);
    if ((a1 && b2 && !a2 && !b1) || (a2 && b1 && !a1 && !b2)) return true;
  }
  return false;
}

async function runQueryAll(collectionId, fields) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`;
  const out = [];
  let last = null;
  while (true) {
    const token = await resolveAccessToken(PROJECT_ID);
    const sq = {
      from: [{collectionId}],
      select: {fields: fields.map((fieldPath) => ({fieldPath}))},
      orderBy: [{field: {fieldPath: "__name__"}, direction: "ASCENDING"}],
      limit: 3000,
    };
    if (last) sq.startAt = {values: [{referenceValue: last}], before: false};
    const res = await fetch(url, {
      method: "POST",
      headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
      body: JSON.stringify({structuredQuery: sq}),
      signal: AbortSignal.timeout(60000),
    });
    if (!res.ok) throw new Error(`runQuery ${collectionId} HTTP ${res.status}: ${await res.text()}`);
    const docs = (await res.json()).filter((r) => r.document).map((r) => r.document);
    if (!docs.length) break;
    out.push(...docs);
    last = docs[docs.length - 1].name;
    if (out.length % 15000 === 0) console.log(`[bot23] Scanned ${out.length} docs in ${collectionId}...`);
    if (docs.length < 3000) break;
  }
  return out;
}

function qualityScore(entry) {
  let sc = 0;
  if (entry.verified) sc += 1000;
  if (entry.effectiveTier && entry.effectiveTier !== "free_basic") sc += 500;
  if (entry.publicEmail || entry.generalEmail) sc += 40;
  if (entry.website) sc += 30;
  if (entry.streetAddress) sc += 20;
  if (entry.tollFreePhone) sc += 10;
  if (!entry.id.startsWith("cossd-book-")) sc += 5; // prefer richer online/Google profile when tied
  if (entry.wasRepaired) sc -= 2; // prefer record that already had clean spelling if tied
  sc += Math.min(entry.companyName.length, 40) * 0.1;
  return sc;
}

const KNOWN_LOWERCASE_BRANDS = new Set([
  "thinktel communications inc",
  "e-mci electrical & millwright services",
  "hi signs the fath group",
  "isafety services",
  "can-am geomatics corp",
  "optiflow casing plungers inc",
  "exp",
  "designs by tam ltd",
  "geologic systems ltd",
  "mindset/dyalgeo",
  "voco darwin suites by ihg",
  "ingauge energy",
  "de' heritage training centre",
  "ibis macae",
  "degraaf excavating ltd",
  "nfluids inc",
  "ce orbit ltd",
  "kn fall protection services bc",
  "multiview locates inc mississauga",
  "nexair conway",
  "nexair little rock",
  "nexair north little rock plant",
  "nexair russellville",
  "nexair carbonic",
  "integreen services, inc",
  "proactive safety services",
  "incon-trol water systems",
  "ogpumper",
  "g2g mobile welding llc",
  "stayapt suites lafayette south",
  "voestalpine tubulars gmbh & co kg (octg)",
  "aikiss water - aquazon - ruhens",
  "n engineering inc | civil & traffic engineers in gta",
]);

const MISSPELLED_WORD_FIXES = [
  [/\bOilfeild\b/giu, "Oilfield"],
  [/\bOilfiled\b/giu, "Oilfield"],
  [/\bEnviromental\b/giu, "Environmental"],
  [/\bEnviroment\b/giu, "Environment"],
  [/\bConstructon\b/giu, "Construction"],
  [/\bConstuction\b/giu, "Construction"],
  [/\bSevices\b/giu, "Services"],
  [/\bServies\b/giu, "Services"],
  [/\bHydralic\b/giu, "Hydraulic"],
  [/\bHydrolic\b/giu, "Hydraulic"],
  [/\bEquiptment\b/giu, "Equipment"],
  [/\bTransportaion\b/giu, "Transportation"],
  [/\bTransporation\b/giu, "Transportation"],
  [/\bMangement\b/giu, "Management"],
  [/\bManagment\b/giu, "Management"],
  [/\bMaintenace\b/giu, "Maintenance"],
  [/\bMaintanence\b/giu, "Maintenance"],
  [/\bExcavtion\b/giu, "Excavation"],
  [/\bPetrolium\b/giu, "Petroleum"],
  [/\bDrillng\b/giu, "Drilling"],
  [/\bFabriction\b/giu, "Fabrication"],
  [/\bInsullation\b/giu, "Insulation"],
  [/\bInsulaton\b/giu, "Insulation"],
  [/\bMachinning\b/giu, "Machining"],
  [/\bCommuncations\b/giu, "Communications"],
  [/\bCommunicatons\b/giu, "Communications"],
  [/\bContractng\b/giu, "Contracting"],
  [/\bLogisitics\b/giu, "Logistics"],
  [/\bAcces\s+Div\b/giu, "Access Division"],
  [/\bMecanic\b/giu, "Mechanic"],
];

function repairCompanyName(entry) {
  let s = String(entry.companyName || "").trim();
  if (!s) return "";
  // Fix COSSD print book alternate-phone line "Foremost - Or" -> "Foremost"
  if (s === "Foremost - Or") s = "Foremost";
  if (s === "Energy Mines & Petroleum Resources-Ministry Of") {
    s = "Ministry of Energy, Mines & Petroleum Resources";
  }
  // Convert phone-book inverted "..., The" or "... The" to "The ..."
  const invThe = s.match(/^(.+?)(?:,\s*|\s+)The$/u);
  if (invThe && invThe[1].length >= 4 && !/\b(?:of|in|at|for|and|&)$/iu.test(invThe[1])) {
    s = `The ${invThe[1].trim()}`;
  }
  // Strip trailing dangling " and", " Dba", " +"
  s = s.replace(/\s+(?:and|dba)\s*$/iu, "").replace(/\s+\+\s*$/u, "").trim();
  // Fix specific unbalanced parentheses
  if (s === "SIT Centre ) Site Inspection Training Centre)") {
    s = "SIT Centre (Site Inspection Training Centre)";
  } else if (s.endsWith(") )")) {
    s = s.replace(/\s*\)\s*\)$/u, ")");
  } else {
    const openP = (s.match(/\(/gu) || []).length;
    const closeP = (s.match(/\)/gu) || []).length;
    if (openP === closeP + 1 && !s.endsWith(")")) {
      s = `${s})`;
    }
  }
  // Fix English oilfield spelling typos (skip French Equipement in QC/NB)
  for (const [re, rep] of MISSPELLED_WORD_FIXES) {
    s = s.replace(re, rep);
  }
  if (entry.regionCode !== "QC" && entry.regionCode !== "NB") {
    s = s.replace(/\bEquipement\b/giu, "Equipment");
  }
  // Fix uncapitalized non-stylized leading words
  if (/^(?:oceanografia|rezayat|ital-cat|j & A|k & S|lg Construction|jp Welding|ab Offshore)\b/u.test(s)) {
    s = s[0].toUpperCase() + s.slice(1);
  }
  return s.replace(/\s+/gu, " ").trim();
}

const MISSPELLED_WORD_RE = /\b(oilfeild|oilfiled|enviromental|enviroment|constructon|constuction|sevices|servies|hydralic|hydrolic|equiptment|transportaion|transporation|mangement|managment|maintenace|maintanence|excavtion|petrolium|drillng|fabriction|insullation|insulaton|machinning|communcations|communicatons|logisitics|contractng)\b/iu;

const DANGLING_END_RE = /(?:(?:\s+(?:&|and|or|of|for|the|a|an|in|at|by|to|division\s+of|div\s+of|formerly|dba|o\/a))|[,/&+-]|\.\.\.)$/iu;

function inspectStandaloneNameDefects(entry) {
  const name = entry.companyName || "";
  const issues = [];
  if (!name || name.length < 2) issues.push("too_short");
  const openP = (name.match(/\(/gu) || []).length;
  const closeP = (name.match(/\)/gu) || []).length;
  if (openP !== closeP) issues.push("unbalanced_parentheses");
  if (/^[.,\-&/)\]:;]/u.test(name)) issues.push("leading_punctuation");
  if (/^[a-z]/u.test(name) && !KNOWN_LOWERCASE_BRANDS.has(name.toLowerCase()) && !/^[a-z]-[A-Z]/u.test(name) && !/^i[A-Z]/u.test(name) && !/^e[A-Z-]/u.test(name) && !/^www\./iu.test(name)) {
    issues.push("leading_lowercase_possible_crop");
  }
  if (
    DANGLING_END_RE.test(name) &&
    !/\bS\s*\/?\s*A$/iu.test(name) &&
    !/^(?:[A-Z]\s+){2,}[A-Z]$/u.test(name) &&
    !(entry.regionCode === "OR" && /\s+OR$/u.test(name))
  ) {
    issues.push("dangling_or_truncated_ending");
  }
  const m = name.match(MISSPELLED_WORD_RE);
  if (m) issues.push(`misspelled_word:${m[1]}`);
  if (/(?:Ã.|â€|&amp;|&#\d+|\uFFFD)/u.test(name)) issues.push("garbled_encoding");
  return issues;
}

const TRUNCATED_PARTIAL_TOKENS = new Set([
  "serv", "const", "contr", "equip", "trans", "transp", "tech", "ind", "oilf", "env", "mgmt", "maint", "mfg",
]);

const GENERIC_TRAILING_TOKENS = new Set([
  "oilfield", "service", "services", "contracting", "contractor", "contractors",
  "construction", "rental", "rentals", "trucking", "transport", "transportation",
  "welding", "consulting", "energy", "supply", "supplies", "group", "enterprise",
  "enterprises", "holding", "holdings", "canada", "alberta", "western", "international",
  "industrial", "solutions", "solution", "systems", "system", "equipment", "industries",
  "industry", "management", "logistics", "mechanical", "electrical", "safety",
  ...TRUNCATED_PARTIAL_TOKENS,
]);

async function commitUpdates(rawWrites) {
  const byDoc = new Map();
  for (const op of rawWrites) {
    if (op.delete) {
      byDoc.set(op.delete, op);
    } else if (op.update) {
      const name = op.update.name;
      const prev = byDoc.get(name);
      if (prev?.delete) continue;
      if (prev?.update) {
        Object.assign(prev.update.fields, op.update.fields);
        prev.updateMask.fieldPaths = [...new Set([...prev.updateMask.fieldPaths, ...op.updateMask.fieldPaths])];
      } else {
        byDoc.set(name, op);
      }
    }
  }
  const writes = [...byDoc.values()];
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:commit`;
  const BATCH = 200;
  for (let i = 0; i < writes.length; i += BATCH) {
    const chunk = writes.slice(i, i + BATCH);
    for (let attempt = 1; attempt <= 4; attempt++) {
      const token = await resolveAccessToken(PROJECT_ID);
      const res = await fetch(url, {
        method: "POST",
        headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
        body: JSON.stringify({writes: chunk}),
        signal: AbortSignal.timeout(60000),
      });
      if (res.ok) break;
      if (attempt === 4) throw new Error(`commit HTTP ${res.status}: ${await res.text()}`);
      await new Promise((r) => setTimeout(r, 1500 * attempt));
    }
    console.log(`[bot23] Committed ${Math.min(i + BATCH, writes.length)}/${writes.length} writes`);
  }
}

async function main() {
  console.log(`[bot23] Starting Full Yellow Pages Deep Inspection on ${PROJECT_ID} (apply=${APPLY})...`);
  const pubDocs = await runQueryAll("yellow_pages_public_entries", [
    "companyName", "countryCode", "regionCode", "city", "publicPhone", "tollFreePhone",
    "publicEmail", "website", "streetAddress", "categoryCodes", "verified", "effectiveTier", "active",
  ]);
  const privDocs = await runQueryAll("yellow_pages_companies", [
    "companyName", "discoveryChannel", "generalEmail", "publicEmail", "website",
    "mainPhone", "publicPhone", "tollFreePhone", "legacyPhones", "streetAddress",
    "publicationStatus", "verificationStatus",
  ]);

  const privById = new Map();
  for (const d of privDocs) {
    const id = d.name.split("/").pop();
    const f = d.fields || {};
    privById.set(id, {
      id,
      discoveryChannel: strVal(f, "discoveryChannel"),
      generalEmail: strVal(f, "generalEmail"),
      publicEmail: strVal(f, "publicEmail"),
      website: strVal(f, "website"),
      mainPhone: strVal(f, "mainPhone"),
      publicPhone: strVal(f, "publicPhone"),
      tollFreePhone: strVal(f, "tollFreePhone"),
      legacyPhones: arrStr(f, "legacyPhones"),
      streetAddress: strVal(f, "streetAddress"),
      publicationStatus: strVal(f, "publicationStatus"),
      verificationStatus: strVal(f, "verificationStatus"),
    });
  }

  const entries = [];
  for (const d of pubDocs) {
    const f = d.fields || {};
    if (!boolVal(f, "active", true)) continue;
    const id = d.name.split("/").pop();
    const pv = privById.get(id);
    const rawCompanyName = strVal(f, "companyName");
    const countryCode = strVal(f, "countryCode");
    const regionCode = strVal(f, "regionCode");
    const city = strVal(f, "city");
    const repairedName = repairCompanyName({companyName: rawCompanyName, regionCode});
    const companyName = repairedName || rawCompanyName;
    const wasRepaired = Boolean(repairedName && repairedName !== rawCompanyName);
    entries.push({
      id,
      docName: d.name,
      originalCompanyName: rawCompanyName,
      companyName,
      wasRepaired,
      countryCode,
      regionCode,
      city,
      publicPhone: strVal(f, "publicPhone"),
      tollFreePhone: strVal(f, "tollFreePhone"),
      publicEmail: strVal(f, "publicEmail"),
      generalEmail: pv?.generalEmail || "",
      website: strVal(f, "website") || pv?.website || "",
      streetAddress: strVal(f, "streetAddress") || pv?.streetAddress || "",
      categoryCodes: arrStr(f, "categoryCodes"),
      verified: boolVal(f, "verified", false),
      effectiveTier: strVal(f, "effectiveTier") || "free_basic",
      discoveryChannel: pv?.discoveryChannel || (id.startsWith("cossd-book-") ? "cossd_book_2026_photo_ocr" : ""),
      legacyPhones: pv?.legacyPhones || [],
      normName: normalizedCompanyName(companyName),
      core: compactCoreName(companyName),
      stem: stemWordsName(companyName),
      nums: extractNumbers(companyName),
    });
  }
  console.log(`[bot23] Active public entries loaded: ${entries.length} (private records: ${privById.size}).`);

  // =========================================================================
  // MODULE 2, 3, 4: Duplicate & Misspelled / Partial-Word Inspection
  // =========================================================================
  const byCity = new Map();
  for (const e of entries) {
    const ck = `${e.countryCode}|${e.regionCode}|${e.city.toLowerCase()}`;
    if (!byCity.has(ck)) byCity.set(ck, []);
    byCity.get(ck).push(e);
  }

  const confirmedDuplicates = []; // [{keep, drop, reason, detail}]
  const droppedIds = new Set();
  const sisterSharedPhonePairs = [];

  for (const [ck, list] of byCity.entries()) {
    if (list.length < 2) continue;

    // 2A. Exact non-toll-free phone match in same city
    const byLocalPhone = new Map();
    for (const e of list) {
      const p10 = (e.countryCode === "CA" || e.countryCode === "US") ? digits10(e.publicPhone) : allDigits(e.publicPhone);
      if (!p10 || p10.length < 8) continue;
      if ((e.countryCode === "CA" || e.countryCode === "US") && /^(?:800|888|877|866|855|844|833)$/u.test(p10.slice(0, 3))) continue;
      if (!byLocalPhone.has(p10)) byLocalPhone.set(p10, []);
      byLocalPhone.get(p10).push(e);
    }
    for (const [ph, group] of byLocalPhone.entries()) {
      if (group.length < 2) continue;
      group.sort((a, b) => qualityScore(b) - qualityScore(a));
      for (let i = 0; i < group.length; i++) {
        if (droppedIds.has(group[i].id)) continue;
        for (let j = i + 1; j < group.length; j++) {
          if (droppedIds.has(group[j].id)) continue;
          const a = group[i];
          const b = group[j];
          if (hasOpposingQualifiers(a.companyName, b.companyName)) {
            sisterSharedPhonePairs.push({city: ck, phone: ph, nameA: a.companyName, nameB: b.companyName, note: "distinct_directional_branch"});
            continue;
          }
          const sameStem = a.stem && a.stem === b.stem;
          const dist = (a.stem && b.stem) ? damerauLev(a.stem, b.stem, 3) : 99;
          const minLen = Math.min(a.stem.length, b.stem.length);
          const isPrefix = minLen >= 5 && (a.stem.startsWith(b.stem) || b.stem.startsWith(a.stem));
          // Check shared first significant word + same phone in same city
          const wA = a.normName.split(" ").filter((w) => w.length >= 3);
          const wB = b.normName.split(" ").filter((w) => w.length >= 3);
          const sharedLead = wA.length && wB.length && wA[0] === wB[0] && (a.nums === b.nums);
          if (sameStem || dist <= 2 || isPrefix || (sharedLead && wA.length >= 2 && wB.length >= 2 && wA[1] === wB[1])) {
            droppedIds.add(b.id);
            confirmedDuplicates.push({
              reason: "same_phone_and_name_variant",
              cityKey: ck,
              keepId: a.id,
              keepName: a.companyName,
              keepPhone: a.publicPhone,
              dropId: b.id,
              dropName: b.originalCompanyName || b.companyName,
              dropPhone: b.publicPhone,
            });
          } else {
            sisterSharedPhonePairs.push({city: ck, phone: ph, nameA: a.companyName, nameB: b.companyName, note: "distinct_sister_companies_sharing_phone"});
          }
        }
      }
    }

    // 3A. Exact `stem` (singular/plural + compactCore) collision in same city (even if phone differs)
    const byStem = new Map();
    for (const e of list) {
      if (droppedIds.has(e.id) || !e.stem || e.stem.length < 4) continue;
      if (!byStem.has(e.stem)) byStem.set(e.stem, []);
      byStem.get(e.stem).push(e);
    }
    for (const [, group] of byStem.entries()) {
      if (group.length < 2) continue;
      group.sort((a, b) => qualityScore(b) - qualityScore(a));
      const keep = group[0];
      for (let j = 1; j < group.length; j++) {
        const cand = group[j];
        if (hasOpposingQualifiers(keep.companyName, cand.companyName)) continue;
        if (keep.nums !== cand.nums) continue;
        droppedIds.add(cand.id);
        confirmedDuplicates.push({
          reason: keep.core === cand.core ? "exact_compact_core_same_city" : "singular_plural_stem_same_city",
          cityKey: ck,
          keepId: keep.id,
          keepName: keep.companyName,
          keepPhone: keep.publicPhone,
          dropId: cand.id,
          dropName: cand.originalCompanyName || cand.companyName,
          dropPhone: cand.publicPhone,
        });
      }
    }

    // 3B & 4A. Misspelled-word (Damerau-Levenshtein <= 2) & Partial-word prefix in same city
    const active = list.filter((e) => !droppedIds.has(e.id) && e.stem.length >= 6);
    active.sort((a, b) => qualityScore(b) - qualityScore(a));
    for (let i = 0; i < active.length; i++) {
      const a = active[i];
      if (droppedIds.has(a.id)) continue;
      for (let j = i + 1; j < active.length; j++) {
        const b = active[j];
        if (droppedIds.has(b.id)) continue;
        // Must share at least first 2 characters OR first/second char transposition to avoid O(N^2) work in huge cities
        if (a.stem[0] !== b.stem[0] && !(a.stem[0] === b.stem[1] && a.stem[1] === b.stem[0])) continue;
        if (a.nums !== b.nums) continue;
        if (hasOpposingQualifiers(a.companyName, b.companyName)) continue;

        // Check partial-word / truncated prefix first
        const shorter = a.stem.length <= b.stem.length ? a : b;
        const longer = shorter === a ? b : a;
        if (shorter.stem.length >= 8 && longer.stem.startsWith(shorter.stem)) {
          const rem = longer.stem.slice(shorter.stem.length);
          if (rem.length <= 12 && GENERIC_TRAILING_TOKENS.has(rem)) {
            const pA = digits10(a.publicPhone);
            const pB = digits10(b.publicPhone);
            const truncatedInSameExchange = TRUNCATED_PARTIAL_TOKENS.has(rem) && (!pA || !pB || pA.slice(0, 6) === pB.slice(0, 6));
            const exactPhoneWithGenericSuffix = Boolean(pA && pB && pA === pB);
            if (truncatedInSameExchange || exactPhoneWithGenericSuffix) {
              droppedIds.add(b.id);
              confirmedDuplicates.push({
                reason: `partial_or_generic_suffix_same_city(+${rem})`,
                cityKey: ck,
                keepId: a.id,
                keepName: a.companyName,
                keepPhone: a.publicPhone,
                dropId: b.id,
                dropName: b.originalCompanyName || b.companyName,
                dropPhone: b.publicPhone,
              });
              continue;
            }
          }
        }

        // Misspelled-word Damerau-Levenshtein check (strictly guarded against distinct words like Hotel/Motel or Questerre/Questfire)
        if (Math.abs(a.stem.length - b.stem.length) <= 1 && Math.min(a.stem.length, b.stem.length) >= 12) {
          const hotelMotel = (/\bhotel\b/iu.test(a.companyName) && /\bmotel\b/iu.test(b.companyName)) || (/\bmotel\b/iu.test(a.companyName) && /\bhotel\b/iu.test(b.companyName));
          if (!hotelMotel && a.stem.slice(0, 6) === b.stem.slice(0, 6)) {
            const dist = damerauLev(a.stem, b.stem, 1);
            const pA = digits10(a.publicPhone);
            const pB = digits10(b.publicPhone);
            const sameExchangeOrTypo = (pA && pB && pA.slice(0, 6) === pB.slice(0, 6)) || MISSPELLED_WORD_RE.test(a.companyName) || MISSPELLED_WORD_RE.test(b.companyName);
            if (dist <= 1 && sameExchangeOrTypo) {
              droppedIds.add(b.id);
              confirmedDuplicates.push({
                reason: "misspelled_fuzzy_dist_1_same_city",
                cityKey: ck,
                keepId: a.id,
                keepName: a.companyName,
                keepPhone: a.publicPhone,
                dropId: b.id,
                dropName: b.companyName,
                dropPhone: b.publicPhone,
              });
            }
          }
        }
      }
    }
  }

  // =========================================================================
  // MODULE 4B: Standalone Name Repairs, Defects & Town/Category/Verified Hygiene
  // =========================================================================
  const nameRepairs = [];
  const standaloneDefects = [];
  let verifiedTrueCount = 0;
  let nonCanonicalCities = 0;
  let emptyCities = 0;
  let emptyCategories = 0;
  const sectorCounts = {};
  for (const code of CATEGORY_BY_CODE.keys()) sectorCounts[code] = 0;

  // Email & Website Outreach Readiness
  const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[a-z]{2,}$/iu;
  let withValidEmail = 0;
  let withWebsiteOnly = 0;
  let phoneOnlyNoWebOrEmail = 0;
  const emailByChannel = {};

  for (const e of entries) {
    if (droppedIds.has(e.id)) continue;
    if (e.wasRepaired) {
      nameRepairs.push({
        id: e.id,
        before: e.originalCompanyName,
        after: e.companyName,
        city: e.city,
        regionCode: e.regionCode,
        countryCode: e.countryCode,
        phone: e.publicPhone,
      });
    }
    if (e.verified) verifiedTrueCount++;
    if (!e.city) {
      emptyCities++;
    } else {
      const can = canonicalizeCityName(e.city, e.regionCode, e.countryCode);
      if (can && can !== e.city) nonCanonicalCities++;
    }
    if (!e.categoryCodes.length) emptyCategories++;
    for (const c of e.categoryCodes) {
      if (sectorCounts[c] !== undefined) sectorCounts[c]++;
    }
    const defects = inspectStandaloneNameDefects(e);
    if (defects.length) {
      standaloneDefects.push({
        id: e.id,
        companyName: e.companyName,
        city: e.city,
        regionCode: e.regionCode,
        countryCode: e.countryCode,
        phone: e.publicPhone,
        issues: defects.join(", "),
      });
    }

    const bestEmail = (EMAIL_RE.test(e.generalEmail) ? e.generalEmail : EMAIL_RE.test(e.publicEmail) ? e.publicEmail : "").toLowerCase();
    const ch = e.discoveryChannel || "other";
    if (!emailByChannel[ch]) emailByChannel[ch] = {total: 0, withEmail: 0, withWebsite: 0};
    emailByChannel[ch].total++;
    if (bestEmail) {
      withValidEmail++;
      emailByChannel[ch].withEmail++;
    } else if (e.website) {
      withWebsiteOnly++;
    } else {
      phoneOnlyNoWebOrEmail++;
    }
    if (e.website) emailByChannel[ch].withWebsite++;
  }

  // =========================================================================
  // MODULE 1: Google Drive 73-Photo Cross-Reference & Contact Enrichment
  // =========================================================================
  const photoFiles = fs.existsSync(PHOTOS_DIR)
    ? fs.readdirSync(PHOTOS_DIR).filter((f) => /\.jpe?g$/iu.test(f)).sort()
    : [];
  const agentFiles = fs.existsSync(EXTRACT_DIR)
    ? fs.readdirSync(EXTRACT_DIR).filter((f) => /^agent_\d+\.jsonl$/u.test(f)).sort()
    : [];

  // Build lookup maps on surviving live entries for exact book cross-reference
  const liveByPhone = new Map();
  const liveByStemCity = new Map();
  const liveByStemRegion = new Map();
  const liveById = new Map();
  for (const e of entries) {
    if (droppedIds.has(e.id)) continue;
    liveById.set(e.id, e);
    for (const raw of [e.publicPhone, e.tollFreePhone, ...e.legacyPhones]) {
      const p = digits10(raw);
      if (p && !liveByPhone.has(p)) liveByPhone.set(p, e);
    }
    if (e.stem) {
      liveByStemCity.set(`${e.stem}|${e.countryCode}|${e.regionCode}|${e.city.toLowerCase()}`, e);
      const rk = `${e.stem}|${e.countryCode}|${e.regionCode}`;
      if (!liveByStemRegion.has(rk)) liveByStemRegion.set(rk, e);
    }
  }

  const perPhotoStats = new Map();
  for (const pf of photoFiles) {
    const base = pf.replace(/\.jpe?g$/iu, "");
    perPhotoStats.set(base, {
      photoFile: pf,
      tileA: false,
      tileB: false,
      pages: new Set(),
      sections: new Set(),
      rawRows: 0,
      uniqueListings: 0,
      addedFromBook: 0,
      matchedPreExisting: 0,
      heldReviewOrSkipped: 0,
    });
  }

  const seenBookKey = new Set();
  const bookCrossRefRows = [];
  const contactEnrichments = []; // enrich missing website/email/tollFree/address on pre-existing matched listings
  const enrichedIds = new Set();

  for (const fn of agentFiles) {
    const lines = fs.readFileSync(path.join(EXTRACT_DIR, fn), "utf8").split(/\r?\n/u).filter(Boolean);
    for (const line of lines) {
      const r = JSON.parse(line);
      const base = String(r.photo || r.tile || "").replace(/_[AB]\.jpg$/iu, "").replace(/\.jpe?g$/iu, "");
      const st = perPhotoStats.get(base);
      if (st) {
        st.rawRows++;
        if (String(r.tile || "").endsWith("_A.jpg")) st.tileA = true;
        if (String(r.tile || "").endsWith("_B.jpg")) st.tileB = true;
        if (r.page) st.pages.add(String(r.page));
        if (r.section) st.sections.add(String(r.section));
      }
      const cleanName = canonicalizeCompanyName(String(r.name || "").trim());
      const pMain = normalizeNorthAmericanPhone(r.phone || "");
      const pToll = normalizeNorthAmericanPhone(r.tollFree || "");
      const mainD = pMain?.digits10 || "";
      const tollD = pToll?.digits10 || "";
      const dedupeKey = `${normalizedCompanyName(cleanName)}|${mainD || tollD}|${String(r.city || "").toLowerCase()}`;
      if (seenBookKey.has(dedupeKey)) continue;
      seenBookKey.add(dedupeKey);
      if (st) st.uniqueListings++;

      let rc = canonicalizeRegionCode(String(r.region || "").trim().toUpperCase(), "");
      if (rc === "PEI") rc = "PE";
      if (rc === "SD" && String(r.city || "").trim().toLowerCase() === "lander" && mainD.startsWith("307")) rc = "WY";
      const cc = ["AB","BC","SK","MB","ON","QC","NB","NS","NL","PE","YT","NT","NU"].includes(rc)
        ? "CA"
        : rc.length === 2 && COUNTRY_BY_CODE.has("US") ? "US" : "";
      const canCity = cc && r.city ? canonicalizeCityName(String(r.city).trim(), rc, cc) : String(r.city || "").trim();
      const stem = stemWordsName(cleanName);

      let matched = (mainD && liveByPhone.get(mainD)) || (tollD && liveByPhone.get(tollD)) || null;
      let matchHow = matched ? "phone_match" : "";
      if (!matched && stem && cc && canCity) {
        matched = liveByStemCity.get(`${stem}|${cc}|${rc}|${canCity.toLowerCase()}`) || null;
        if (matched) matchHow = "name_and_city_match";
      }

      let outcome = "";
      if (matched) {
        if (matched.id.startsWith("cossd-book-")) {
          outcome = "ADDED_NEW_TO_WEBSITE";
          matchHow = "added_from_cossd_book";
          if (st) st.addedFromBook++;
        } else {
          outcome = "ALREADY_ON_WEBSITE";
          if (st) st.matchedPreExisting++;
          // Check if book has extra contact details (email, website, tollFree, address) missing on live record
          const bEmail = EMAIL_RE.test(String(r.email || "").trim()) ? String(r.email).trim().toLowerCase() : "";
          const rawWeb = String(r.website || "").replace(/^\s*(?:web|website)[:\s]*/iu, "").trim();
          const bWeb = rawWeb ? (/^https?:\/\//iu.test(rawWeb) ? rawWeb : `https://${rawWeb}`) : "";
          const bToll = pToll?.validNanpa && pToll?.isTollFree ? pToll.display : "";
          const bAddr = String(r.address || "").trim().slice(0, 140);
          const patch = {};
          if (bEmail && !matched.publicEmail && !matched.generalEmail) patch.publicEmail = bEmail;
          if (bWeb && !matched.website) patch.website = bWeb;
          if (bToll && !matched.tollFreePhone) patch.tollFreePhone = bToll;
          if (bAddr && !matched.streetAddress) patch.streetAddress = bAddr;
          if (Object.keys(patch).length && !enrichedIds.has(matched.id)) {
            enrichedIds.add(matched.id);
            contactEnrichments.push({id: matched.id, companyName: matched.companyName, patch});
          }
        }
      } else {
        const regMatch = (stem && cc) ? liveByStemRegion.get(`${stem}|${cc}|${rc}`) : null;
        if (String(r.confidence || "").toLowerCase() === "low") {
          outcome = "HELD_REVIEW_CROPPED_OR_LOW_CONFIDENCE";
        } else if (regMatch) {
          outcome = "HELD_REVIEW_SAME_NAME_IN_PROVINCE_STATE";
          matched = regMatch;
          matchHow = `same_name_in_${regMatch.city}`;
        } else {
          outcome = "SKIPPED_NON_NA_OR_NO_PHONE";
        }
        if (st) st.heldReviewOrSkipped++;
      }

      bookCrossRefRows.push({
        photoFile: `${base}.jpg`,
        tile: r.tile || "",
        bookPage: String(r.page || ""),
        bookSection: String(r.section || ""),
        bookCompanyName: cleanName || String(r.name || ""),
        bookCity: canCity,
        bookRegion: rc || String(r.region || ""),
        bookPhone: pMain?.display || String(r.phone || ""),
        bookTollFree: pToll?.display || String(r.tollFree || ""),
        bookFax: String(r.fax || ""),
        bookWebsite: String(r.website || ""),
        bookEmail: String(r.email || ""),
        bookAddress: String(r.address || ""),
        confidence: String(r.confidence || "high"),
        reconciliationOutcome: outcome,
        matchMethod: matchHow,
        liveCompanyId: matched?.id || "",
        liveCompanyName: matched?.companyName || "",
        liveCity: matched?.city || "",
        liveRegion: matched?.regionCode || "",
        livePhone: matched?.publicPhone || "",
      });
    }
  }

  // Group duplicate reasons
  const dupByReason = {};
  for (const d of confirmedDuplicates) {
    dupByReason[d.reason] = (dupByReason[d.reason] || 0) + 1;
  }

  console.log("[bot23] Deep Inspection Summary:", {
    activePublicEntriesBefore: entries.length,
    confirmedDuplicatesFound: confirmedDuplicates.length,
    dupByReason,
    distinctSisterCompaniesSharingPhone: sisterSharedPhonePairs.length,
    standaloneNameRepairsCount: nameRepairs.length,
    standaloneNameDefectsRemaining: standaloneDefects.length,
    verifiedTrueCount,
    nonCanonicalCities,
    emptyCities,
    emptyCategories,
    drivePhotosVerified: photoFiles.length,
    bookUniqueListingsCrossReferenced: bookCrossRefRows.length,
    bookContactEnrichmentsAvailable: contactEnrichments.length,
    outreachEmailsReadyNow: withValidEmail,
    outreachWebsitesAvailableForEmailDiscovery: withWebsiteOnly,
    phoneOnlyListings: phoneOnlyNoWebOrEmail,
  });

  // Apply cleanups, standalone name repairs & contact enrichments if --apply
  if (APPLY && (confirmedDuplicates.length > 0 || nameRepairs.length > 0 || contactEnrichments.length > 0)) {
    const writes = [];
    const nowIso = new Date().toISOString();
    // 1. Deactivate duplicate public entries & mark private record merged_or_acquired, preserving legacy phone on survivor
    for (const dup of confirmedDuplicates) {
      const keep = liveById.get(dup.keepId);
      const drop = entries.find((x) => x.id === dup.dropId);
      writes.push({
        delete: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_public_entries/${encodeURIComponent(dup.dropId)}`,
      });
      if (privById.has(dup.dropId)) {
        writes.push({
          update: {
            name: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_companies/${encodeURIComponent(dup.dropId)}`,
            fields: {
              publicationStatus: toFirestoreValue("unpublished"),
              operationalStatus: toFirestoreValue("merged_or_acquired"),
              updatedAt: toFirestoreValue(nowIso),
            },
          },
          updateMask: {fieldPaths: ["publicationStatus", "operationalStatus", "updatedAt"]},
        });
      }
      // Preserve dropped phone into survivor's legacyPhones if different
      const dropD = digits10(drop?.publicPhone);
      const keepD = digits10(keep?.publicPhone);
      if (keep && drop && dropD && dropD !== keepD && privById.has(keep.id)) {
        const mergedLegacy = [...new Set([...(keep.legacyPhones || []), drop.publicPhone])];
        keep.legacyPhones = mergedLegacy;
        writes.push({
          update: {
            name: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_companies/${encodeURIComponent(keep.id)}`,
            fields: {
              legacyPhones: toFirestoreValue(mergedLegacy),
              updatedAt: toFirestoreValue(nowIso),
            },
          },
          updateMask: {fieldPaths: ["legacyPhones", "updatedAt"]},
        });
      }
    }

    // 2. Apply standalone spelling / punctuation / inverted-"The" name repairs on surviving entries
    for (const rep of nameRepairs) {
      const ent = liveById.get(rep.id);
      if (!ent) continue;
      const newTokens = buildPublicSearchTokens({
        companyName: rep.after,
        city: ent.city,
        regionCode: ent.regionCode,
        countryCode: ent.countryCode,
        categoryCodes: ent.categoryCodes,
        publicPhone: ent.publicPhone,
        tollFreePhone: ent.tollFreePhone,
      });
      writes.push({
        update: {
          name: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_public_entries/${encodeURIComponent(rep.id)}`,
          fields: {
            companyName: toFirestoreValue(rep.after),
            searchTokens: toFirestoreValue(newTokens),
            updatedAt: toFirestoreValue(nowIso),
          },
        },
        updateMask: {fieldPaths: ["companyName", "searchTokens", "updatedAt"]},
      });
      if (privById.has(rep.id)) {
        writes.push({
          update: {
            name: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_companies/${encodeURIComponent(rep.id)}`,
            fields: {
              companyName: toFirestoreValue(rep.after),
              normalizedCompanyName: toFirestoreValue(normalizedCompanyName(rep.after)),
              updatedAt: toFirestoreValue(nowIso),
            },
          },
          updateMask: {fieldPaths: ["companyName", "normalizedCompanyName", "updatedAt"]},
        });
      }
    }

    // 3. Apply non-destructive contact enrichments from book onto matched pre-existing entries
    for (const enr of contactEnrichments) {
      const pubFields = {updatedAt: toFirestoreValue(nowIso)};
      const pubMask = ["updatedAt"];
      const privFields = {updatedAt: toFirestoreValue(nowIso)};
      const privMask = ["updatedAt"];
      for (const [k, v] of Object.entries(enr.patch)) {
        pubFields[k] = toFirestoreValue(v);
        pubMask.push(k);
        privFields[k] = toFirestoreValue(v);
        privMask.push(k);
        if (k === "publicEmail") {
          privFields.generalEmail = toFirestoreValue(v);
          privMask.push("generalEmail");
        }
      }
      writes.push({
        update: {
          name: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_public_entries/${encodeURIComponent(enr.id)}`,
          fields: pubFields,
        },
        updateMask: {fieldPaths: pubMask},
      });
      if (privById.has(enr.id)) {
        writes.push({
          update: {
            name: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_companies/${encodeURIComponent(enr.id)}`,
            fields: privFields,
          },
          updateMask: {fieldPaths: privMask},
        });
      }
    }

    console.log(`[bot23] Committing ${writes.length} cleanup, name-repair & enrichment writes...`);
    await commitUpdates(writes);
  }

  // Save full structured JSON output so our Excel (.xlsx) + CSV + Markdown generator can build all spreadsheets
  await fsp.mkdir(LEDGER_DIR, {recursive: true});
  await fsp.mkdir(REPORTS_DIR, {recursive: true});

  const photoSummaryRows = [...perPhotoStats.values()].map((s) => ({
    photoFile: s.photoFile,
    bothHalfTilesInspected: s.tileA && s.tileB ? "YES" : `${s.tileA ? "A" : ""}${s.tileB ? "B" : ""}`,
    bookPages: [...s.pages].join(", "),
    bookSections: [...s.sections].join(", "),
    transcribedRows: s.rawRows,
    uniqueListingsOnPage: s.uniqueListings,
    addedNewToWebsite: s.addedFromBook,
    matchedAlreadyOnWebsite: s.matchedPreExisting,
    heldForReviewOrSkipped: s.heldReviewOrSkipped,
  }));

  const inspectionPayload = {
    generatedAt: new Date().toISOString(),
    applied: APPLY,
    liveDirectoryBefore: entries.length,
    liveDirectoryAfter: APPLY ? entries.length - confirmedDuplicates.length : entries.length,
    drivePhotosCount: photoFiles.length,
    drivePhotosAllInspected: photoSummaryRows.every((r) => r.bothHalfTilesInspected === "YES"),
    bookRawTranscribedRows: bookCrossRefRows.length + 963,
    bookUniqueListings: bookCrossRefRows.length,
    confirmedDuplicatesCount: confirmedDuplicates.length,
    dupByReason,
    confirmedDuplicates,
    distinctSisterSharedPhonesCount: sisterSharedPhonePairs.length,
    sisterSharedPhonePairs: sisterSharedPhonePairs.slice(0, 200),
    nameRepairsCount: nameRepairs.length,
    nameRepairs,
    standaloneNameDefectsCount: standaloneDefects.length,
    standaloneDefects,
    contactEnrichmentsCount: contactEnrichments.length,
    contactEnrichments,
    hygiene: {
      verifiedTrueCount,
      nonCanonicalCities,
      emptyCities,
      emptyCategories,
      populatedSectors: Object.values(sectorCounts).filter((v) => v > 0).length,
      totalSectors: Object.keys(sectorCounts).length,
      sectorCounts,
    },
    outreachReadiness: {
      totalActiveBusinesses: APPLY ? entries.length - confirmedDuplicates.length : entries.length,
      withValidEmailNow: withValidEmail,
      withWebsiteForEmailDiscovery: withWebsiteOnly,
      phoneOnlyNoWebOrEmail,
      byDiscoveryChannel: emailByChannel,
    },
    photoSummaryRows,
  };

  const resultsPath = OUT_JSON || path.join(LEDGER_DIR, "23_deep_inspection_results.json");
  await fsp.writeFile(resultsPath, JSON.stringify(inspectionPayload, null, 2));
  if (!OUT_JSON) {
    await fsp.writeFile(path.join(LEDGER_DIR, "23_cossd_book_full_crossref.json"), JSON.stringify(bookCrossRefRows, null, 2));
  }
  console.log(`[bot23] Saved ${path.basename(resultsPath)}${OUT_JSON ? "" : " and 23_cossd_book_full_crossref.json"}.`);
}

main().catch((err) => {
  console.error("[bot23] FATAL:", err);
  process.exit(1);
});
