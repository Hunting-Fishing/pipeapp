#!/usr/bin/env node
/**
 * Bot 22 — COSSD Printed Book Reconciler & Publisher
 *
 * Reads transcribed listings from the photographed COSSD 35th Edition book
 * (`book_extract/agent_NN.jsonl`, produced from the Drive "OIL FIELD BOOK" photos),
 * compares EVERY listing against the live directory (`yellow_pages_public_entries`
 * + private `yellow_pages_companies` incl. legacy phones) and classifies each as:
 *
 *   duplicate_phone         phone / toll-free matches an existing listing  -> skip
 *   duplicate_name_city     same normalized name in same city+region       -> skip
 *   duplicate_fuzzy         near-identical name (edit distance) same city  -> skip
 *   review_same_name_region same name elsewhere in region (branch OR an OCR digit
 *                           slip) -> NOT published, listed for review
 *   new                     no phone / name evidence anywhere              -> publish
 *   rejected_*              unreadable phone, bad region, etc.             -> skip
 *
 * Dry-run by default. `--apply` publishes only `new` rows (verified:false, free_basic).
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
  classifyCategoriesFromText,
  inferCountryAndRegion,
  inferGeoFromNanpaPhone,
} = require("../../firebase/functions/yellow_pages_taxonomy.js");
const {
  buildAdminSearchTokens,
  buildPublicEntry,
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
const EXTRACT_DIR = argVal("--extract-dir", path.join(REPO_ROOT, "data/yellow_pages/book_extract"));

const CA_REGIONS = new Set(["AB", "BC", "SK", "MB", "ON", "QC", "NB", "NS", "NL", "PE", "PEI", "YT", "NT", "NU"]);
const US_REGIONS = new Set([
  "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA",
  "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR",
  "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
]);

function lev(a, b, max = 2) {
  if (a === b) return 0;
  if (Math.abs(a.length - b.length) > max) return max + 1;
  let prev = Array.from({length: b.length + 1}, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    let rowMin = i;
    for (let j = 1; j <= b.length; j++) {
      const v = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
      cur.push(v);
      if (v < rowMin) rowMin = v;
    }
    if (rowMin > max) return max + 1;
    prev = cur;
  }
  return prev[b.length];
}

const strVal = (f, k) => f?.[k]?.stringValue || "";
const arrStr = (f, k) => (f?.[k]?.arrayValue?.values || []).map((v) => v.stringValue || "").filter(Boolean);

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
    if (docs.length < 3000) break;
  }
  return out;
}

function digits10(raw) {
  const d = String(raw || "").replace(/\D+/gu, "");
  if (d.length === 11 && d.startsWith("1")) return d.slice(1);
  return d.length === 10 ? d : "";
}

function compactCoreName(raw) {
  let s = String(raw || "")
    .replace(/['’`]/gu, "")
    .replace(/\b(?:a\s+)?div(?:ision)?\.?\s+of\b.*$/iu, "")
    .replace(/\b(?:formerly|part\s+of|subsidiary\s+of|dba|o\/a)\b.*$/iu, "")
    .replace(/\((?:19\d\d|20\d\d|canada|alberta|western|edmonton|calgary|bc|sk|ltd|inc|gp)\)/giu, " ");
  s = normalizedCompanyName(s)
    .replace(/\b(ulc|lp|gp|the|and|ltd|inc|corp|co|company|limited|corporation)\b/gu, " ")
    .replace(/[^a-z0-9]+/gu, "");
  return s;
}

async function loadExisting() {
  console.log("[bot22] Loading live directory index...");
  const pub = await runQueryAll("yellow_pages_public_entries", [
    "companyName", "countryCode", "regionCode", "city", "publicPhone", "tollFreePhone",
  ]);
  const priv = await runQueryAll("yellow_pages_companies", ["legacyPhones", "mainPhone", "publicPhone", "tollFreePhone"]);
  const phones = new Map(); // digits10 -> docId
  const byNameCity = new Map(); // normName|cc|rc|city -> docId
  const byNameRegion = new Map(); // normName|cc|rc -> [{city, docId}]
  const byCoreCity = new Map(); // compactCore|cc|rc|city -> docId
  const byCoreRegion = new Map(); // compactCore|cc|rc -> [{city, id}]
  const fuzzyBuckets = new Map(); // cc|rc|city|first3 -> [{norm, docId}]
  for (const d of pub) {
    const f = d.fields || {};
    const id = d.name.split("/").pop();
    const cc = strVal(f, "countryCode");
    const rc = strVal(f, "regionCode");
    const city = strVal(f, "city").toLowerCase();
    const rawName = strVal(f, "companyName");
    const nm = normalizedCompanyName(rawName);
    const core = compactCoreName(rawName);
    for (const k of ["publicPhone", "tollFreePhone"]) {
      const p = digits10(strVal(f, k));
      if (p) phones.set(p, id);
    }
    if (!nm) continue;
    byNameCity.set(`${nm}|${cc}|${rc}|${city}`, id);
    const rk = `${nm}|${cc}|${rc}`;
    if (!byNameRegion.has(rk)) byNameRegion.set(rk, []);
    byNameRegion.get(rk).push({city, id});
    if (core && core.length >= 4) {
      byCoreCity.set(`${core}|${cc}|${rc}|${city}`, id);
      const crk = `${core}|${cc}|${rc}`;
      if (!byCoreRegion.has(crk)) byCoreRegion.set(crk, []);
      byCoreRegion.get(crk).push({city, id});
    }
    const fk = `${cc}|${rc}|${city}|${nm.slice(0, 3)}`;
    if (!fuzzyBuckets.has(fk)) fuzzyBuckets.set(fk, []);
    fuzzyBuckets.get(fk).push({nm, id});
  }
  for (const d of priv) {
    const f = d.fields || {};
    const id = d.name.split("/").pop();
    for (const k of ["mainPhone", "publicPhone", "tollFreePhone"]) {
      const p = digits10(strVal(f, k));
      if (p && !phones.has(p)) phones.set(p, id);
    }
    for (const v of arrStr(f, "legacyPhones")) {
      const p = digits10(v);
      if (p && !phones.has(p)) phones.set(p, id);
    }
  }
  console.log(`[bot22] Indexed ${pub.length} public + ${priv.length} private entries (${phones.size} phone keys).`);
  return {phones, byNameCity, byNameRegion, byCoreCity, byCoreRegion, fuzzyBuckets, publicCount: pub.length};
}

async function loadExtract() {
  const files = (await fsp.readdir(EXTRACT_DIR)).filter((n) => /^agent_\d+\.jsonl$/u.test(n)).sort();
  const rows = [];
  let bad = 0;
  for (const fn of files) {
    const txt = await fsp.readFile(path.join(EXTRACT_DIR, fn), "utf8");
    for (const line of txt.split(/\r?\n/u)) {
      const s = line.trim();
      if (!s) continue;
      try {
        const o = JSON.parse(s);
        o._agent = fn;
        rows.push(o);
      } catch {
        bad += 1;
      }
    }
  }
  console.log(`[bot22] Loaded ${rows.length} transcribed rows from ${files.length} files (${bad} unparseable lines).`);
  return rows;
}

function classify(row, idx) {
  if (row.section === "non_listing_page") return {status: "non_listing_page"};
  const name = canonicalizeCompanyName(String(row.name || "").trim());
  if (!name || name.length < 3) return {status: "rejected_name"};
  let rc = canonicalizeRegionCode(String(row.region || "").trim().toUpperCase(), "");
  if (rc === "PEI") rc = "PE";
  const pMain = normalizeNorthAmericanPhone(row.phone || "");
  const pToll = normalizeNorthAmericanPhone(row.tollFree || "");
  const mainD = pMain?.digits10 || "";
  const tollD = pToll?.digits10 || "";
  if (!mainD && !tollD) return {status: "rejected_no_phone", name};

  // Global 10-digit phone check first (catches toll-free statewide rows & legacy phone matches immediately)
  for (const d of [mainD, tollD]) {
    if (d && idx.phones.has(d)) return {status: "duplicate_phone", name, matchId: idx.phones.get(d)};
  }

  // Fix known COSSD print misfiling where Lander WY (307) was printed at the bottom of US South Dakota
  if (rc === "SD" && String(row.city || "").trim().toLowerCase() === "lander" && mainD.startsWith("307")) {
    rc = "WY";
  }

  let cc = CA_REGIONS.has(rc) ? "CA" : US_REGIONS.has(rc) ? "US" : "";
  if (!cc) return {status: "rejected_region", name};

  const nm = normalizedCompanyName(name);
  if (!nm) return {status: "rejected_name"};

  const rawCity = String(row.city || "").trim();
  if (!rawCity) {
    const nr = idx.byNameRegion.get(`${nm}|${cc}|${rc}`);
    if (nr && nr.length) return {status: "duplicate_name_region_no_city", name, matchId: nr[0].id};
    return {status: "review_missing_city", name, rc};
  }
  const city = canonicalizeCityName(rawCity, rc, cc);
  if (!city) return {status: "review_missing_city", name, rc};

  const cityKey = city.toLowerCase();
  const nc = idx.byNameCity.get(`${nm}|${cc}|${rc}|${cityKey}`);
  if (nc) return {status: "duplicate_name_city", name, matchId: nc};
  const core = compactCoreName(name);
  if (core && core.length >= 4) {
    const ccHit = idx.byCoreCity.get(`${core}|${cc}|${rc}|${cityKey}`);
    if (ccHit) return {status: "duplicate_name_city", name, matchId: ccHit};
  }
  const fk = `${cc}|${rc}|${cityKey}|${nm.slice(0, 3)}`;
  for (const cand of idx.fuzzyBuckets.get(fk) || []) {
    if (cand.nm.length >= 8 && lev(cand.nm, nm, 2) <= (nm.length >= 14 ? 2 : 1)) {
      return {status: "duplicate_fuzzy", name, matchId: cand.id};
    }
  }
  const nr = idx.byNameRegion.get(`${nm}|${cc}|${rc}`);
  if (nr && nr.length) return {status: "review_same_name_region", name, matchId: nr[0].id, matchCity: nr[0].city};
  if (core && core.length >= 4) {
    const cr = idx.byCoreRegion.get(`${core}|${cc}|${rc}`);
    if (cr && cr.length) return {status: "review_same_name_region", name, matchId: cr[0].id, matchCity: cr[0].city};
  }
  if (String(row.confidence || "").toLowerCase() === "low") {
    return {status: "review_low_confidence", name, cc, rc, city, mainD, tollD, pMain, pToll, nm, core};
  }
  return {status: "new", name, cc, rc, city, mainD, tollD, pMain, pToll, nm, core};
}

const BOOK_HOTEL_RE = /\b(?:hotel|hotels|motel|motels|inn|inns|lodge|lodges|resort|suites|ramada|super\s*8|travelodge|days\s*inn|best\s*western|comfort\s*inn|holiday\s*inn|hampton\s*inn|quality\s*inn|canalta|pomeroy|microtel|econolodge|econo\s*lodge|sandman|sawridge|baron\s*motor|coast\s*hotel)\b/iu;

function buildRecord(row, c, seq) {
  const geo = inferCountryAndRegion(c.cc, c.rc);
  if (COUNTRY_BY_CODE.has(c.cc)) {
    geo.countryCode = c.cc;
    geo.countryName = COUNTRY_BY_CODE.get(c.cc).name;
  }
  const nowIso = new Date().toISOString();
  const phoneDisplay = c.pMain?.display || c.pToll?.display || "";
  const tollDisplay = c.pToll && c.mainD ? c.pToll.display : "";
  const slug = c.nm.replace(/[^a-z0-9]+/gu, "-").replace(/^-+|-+$/gu, "").slice(0, 38);
  const key = c.mainD || c.tollD;
  const companyId = `cossd-book-${c.cc.toLowerCase()}-${c.rc.toLowerCase()}-${slug}-${key}`;
  let cats = classifyCategoriesFromText([c.name], `${row.address || ""}`).filter((x) => CATEGORY_BY_CODE.has(x));
  if (BOOK_HOTEL_RE.test(c.name) && !cats.includes("crew_hotels_workforce_lodging")) {
    cats.unshift("crew_hotels_workforce_lodging");
  }
  if (!cats.length) cats = ["equipment_rentals_tools"];
  cats = cats.slice(0, 5);
  const website = String(row.website || "").replace(/^\s*(?:web|website)[:\s]*/iu, "").trim();
  const email = String(row.email || "").trim();
  const rec = {
    schemaVersion: 2,
    companyId,
    discoveryChannel: "cossd_book_2026_photo_ocr",
    companyName: c.name,
    normalizedCompanyName: c.nm,
    countryCode: geo.countryCode,
    regionCode: geo.regionCode,
    regionName: geo.regionName,
    city: c.city,
    postalCode: "",
    streetAddress: String(row.address || "").slice(0, 140),
    mainPhone: c.mainD ? c.pMain.display : "",
    publicPhone: phoneDisplay,
    tollFreePhone: tollDisplay || (!c.mainD && c.tollD ? c.pToll.display : ""),
    legacyPhones: [],
    phoneHistory: [],
    generalEmail: "",
    publicEmail: email,
    website: website && /^https?:\/\//iu.test(website) ? website : website ? `https://${website.replace(/^www\./iu, "www.")}` : "",
    powerUnits: 0,
    categoryCodes: cats,
    categories: cats.map((x) => CATEGORY_BY_CODE.get(x)?.label || x),
    services: [],
    basins: geo.defaultBasins || [],
    serviceAreas: [c.city, geo.regionName, geo.countryName].filter(Boolean),
    certifications: [],
    emergency24x7: false,
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
        sourceType: "cossd_book",
        sourceName: "COSSD 35th Edition printed directory (photographed page)",
        sourceUrl: "",
        sourceExternalId: `${row.photo || ""}#p${row.page || ""}`,
        observedAt: nowIso,
        bookPage: String(row.page || ""),
      },
    ],
    publishedAt: nowIso,
    createdAt: nowIso,
    updatedAt: nowIso,
  };
  rec.adminSearchTokens = buildAdminSearchTokens(rec);
  return {privateRecord: rec, publicEntry: buildPublicEntry(rec, companyId, nowIso)};
}

async function commitRecords(records) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:commit`;
  const BATCH = 150; // 300 writes per commit (Firestore max 500)
  for (let i = 0; i < records.length; i += BATCH) {
    const writes = [];
    for (const r of records.slice(i, i + BATCH)) {
      const mk = (obj) => Object.fromEntries(Object.entries(obj).filter(([, v]) => v !== undefined).map(([k, v]) => [k, toFirestoreValue(v, k)]));
      const id = encodeURIComponent(r.privateRecord.companyId);
      writes.push({update: {name: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_companies/${id}`, fields: mk(r.privateRecord)}});
      writes.push({update: {name: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_public_entries/${id}`, fields: mk(r.publicEntry)}});
    }
    for (let attempt = 1; attempt <= 4; attempt++) {
      const token = await resolveAccessToken(PROJECT_ID);
      const res = await fetch(url, {
        method: "POST",
        headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
        body: JSON.stringify({writes}),
        signal: AbortSignal.timeout(60000),
      });
      if (res.ok) break;
      if (attempt === 4) throw new Error(`commit HTTP ${res.status}: ${await res.text()}`);
      await new Promise((r) => setTimeout(r, 1500 * attempt));
    }
    console.log(`[bot22] committed ${Math.min(i + BATCH, records.length)}/${records.length}`);
  }
}

async function main() {
  const rows = await loadExtract();
  const idx = await loadExisting();

  // De-duplicate transcription overlap (A/B tiles & repeated photos of same page) before comparing.
  const seen = new Set();
  const uniqueRows = [];
  let overlapDupes = 0;
  for (const r of rows) {
    const k = `${normalizedCompanyName(String(r.name || ""))}|${digits10(r.phone) || digits10(r.tollFree)}|${String(r.city || "").toLowerCase()}`;
    if (seen.has(k)) {
      overlapDupes += 1;
      continue;
    }
    seen.add(k);
    uniqueRows.push(r);
  }

  const stats = {};
  const buckets = {
    new: [],
    review_same_name_region: [],
    review_low_confidence: [],
    review_missing_city: [],
    duplicate_fuzzy: [],
  };
  const toPublish = [];
  let seq = Math.floor(Date.now() / 1000) % 100000;
  for (const r of uniqueRows) {
    const c = classify(r, idx);
    stats[c.status] = (stats[c.status] || 0) + 1;
    if (c.status === "new") {
      // later rows must not duplicate earlier "new" ones (phone or name+city or compactCore+city)
      for (const d of [c.mainD, c.tollD]) if (d) idx.phones.set(d, "pending");
      idx.byNameCity.set(`${c.nm}|${c.cc}|${c.rc}|${c.city.toLowerCase()}`, "pending");
      if (c.core && c.core.length >= 4) {
        idx.byCoreCity.set(`${c.core}|${c.cc}|${c.rc}|${c.city.toLowerCase()}`, "pending");
      }
      buckets.new.push({name: c.name, city: c.city, rc: c.rc, phone: c.pMain?.display || c.pToll?.display, photo: r.photo, tile: r.tile, page: r.page, confidence: r.confidence});
      toPublish.push(buildRecord(r, c, ++seq));
    } else if (buckets[c.status]) {
      buckets[c.status].push({name: c.name, bookCity: r.city, bookRegion: r.region, bookPhone: r.phone || r.tollFree, existingId: c.matchId || "", existingCity: c.matchCity || "", photo: r.photo, tile: r.tile, page: r.page, confidence: r.confidence});
    }
  }

  const summary = {
    transcribedRows: rows.length,
    overlapDuplicatesInBook: overlapDupes,
    uniqueBookListings: uniqueRows.length,
    liveDirectoryEntries: idx.publicCount,
    ...stats,
  };
  console.log("[bot22] Summary:", summary);

  await fsp.mkdir(REPORTS_DIR, {recursive: true});
  await fsp.mkdir(LEDGER_DIR, {recursive: true});
  await fsp.writeFile(path.join(LEDGER_DIR, "22_book_new_candidates.json"), JSON.stringify(buckets.new, null, 2));
  await fsp.writeFile(
    path.join(LEDGER_DIR, "22_book_review.json"),
    JSON.stringify({
      sameNameOtherCityOrOcrSlip: buckets.review_same_name_region,
      lowConfidenceCroppedOrBlurry: buckets.review_low_confidence,
      missingCityRows: buckets.review_missing_city,
      fuzzyDuplicates: buckets.duplicate_fuzzy,
    }, null, 2),
  );
  const md = [
    "# Bot 22 — COSSD Book vs Live Directory Reconciliation",
    "",
    `- **Generated**: \`${new Date().toISOString()}\` (apply=${APPLY})`,
    `- **Transcribed listing rows**: **${rows.length.toLocaleString()}** (overlap/duplicate rows inside the book transcription removed: ${overlapDupes.toLocaleString()})`,
    `- **Unique book listings compared**: **${uniqueRows.length.toLocaleString()}** against **${idx.publicCount.toLocaleString()}** live directory entries`,
    "",
    "| Result | Count |",
    "|---|---|",
    ...Object.entries(stats).sort((a, b) => b[1] - a[1]).map(([k, v]) => `| ${k} | ${v.toLocaleString()} |`),
    "",
    "`new` = no phone/name match anywhere -> published unverified. `review_same_name_region` = same company name already listed in that province/state (branch office or a single mis-read digit) -> **not** published, listed in `22_book_review.json`.",
    "",
  ].join("\n");
  await fsp.writeFile(path.join(REPORTS_DIR, "22_COSSD_BOOK_RECONCILIATION_REPORT.md"), md);

  if (!APPLY) {
    console.log("[bot22] Dry-run complete — re-run with --apply to publish the `new` listings.");
    return;
  }
  await commitRecords(toPublish);
  console.log(`[bot22] Published ${toPublish.length} new unverified listings.`);
}

main().catch((e) => {
  console.error("[bot22] FATAL:", e);
  process.exit(1);
});
