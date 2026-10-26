#!/usr/bin/env node
/**
 * Bot 15 — Full Production Directory Consistency, Town Consolidation & Field Hygiene Auditor
 *
 * Audits 100% of `yellow_pages_public_entries` and `yellow_pages_companies` in Firestore:
 *   1. Consolidates fragmented/county/abbreviated/misspelled town names (`Co of GrandPr`,
 *      `Co of GrndPr #1`, `County of Grande Prairie`, `Grande Prairie County No. 1`,
 *      `Grand Prairie` in AB -> `Grande Prairie`; `Rocky Mtn Hse` -> `Rocky Mountain House`;
 *      `EL Paso` -> `El Paso`; `LA Porte` -> `La Porte`; postal suffixes, etc.).
 *   2. Repairs misattributed `countryCode` / missing `regionCode` / empty `city` using
 *      3-digit NANPA area codes, 6-digit `NPA-NXX` oilfield exchange prefixes, and explicit
 *      city tokens in company names.
 *   3. Normalizes ALL-CAPS / HTML-entity `companyName` strings while preserving oilfield
 *      acronyms (`LLC`, `LTD`, `INC`, `OCTG`, `NDT`, `H2S`, `BOP`, `SCADA`, `IWCF`, `OPITO`).
 *   4. Backfills missing `basins` from canonical `(countryCode, regionCode)` and classifies
 *      empty-category listings + Oil & Gas Training Facilities (`--include-training`).
 *   5. Deduplicates exact duplicate public entries `(normalizedCompanyName, digits10, city, regionCode)`
 *      and rebuilds `searchTokens` while keeping all crawled listings `unverified` (`free_basic`).
 */

import fs from "node:fs/promises";
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
  normalizeText,
} = require("../../firebase/functions/yellow_pages_taxonomy.js");
const {
  normalizedCompanyName,
} = require("../../firebase/functions/yellow_pages_policy.js");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const INCLUDE_TRAINING = args.includes("--include-training");
const projIdx = args.indexOf("--project");
const PROJECT_ID = projIdx !== -1 && args[projIdx + 1] ? args[projIdx + 1] : "flutter-flow-pipe";

const EXPLICIT_NAME_CITIES = [
  [/\bEdmonton\b/iu, "CA", "AB", "Edmonton"],
  [/\bCalgary\b/iu, "CA", "AB", "Calgary"],
  [/\bNisku\b/iu, "CA", "AB", "Nisku"],
  [/\bGrande\s+Prairie\b/iu, "CA", "AB", "Grande Prairie"],
  [/\bRed\s+Deer\b/iu, "CA", "AB", "Red Deer"],
  [/\bFort\s+McMurray\b/iu, "CA", "AB", "Fort McMurray"],
  [/\bLeduc\b/iu, "CA", "AB", "Leduc"],
  [/\bLloydminster\b/iu, "CA", "AB", "Lloydminster"],
  [/\bDrayton\s+Valley\b/iu, "CA", "AB", "Drayton Valley"],
  [/\bBonnyville\b/iu, "CA", "AB", "Bonnyville"],
  [/\bMedicine\s+Hat\b/iu, "CA", "AB", "Medicine Hat"],
  [/\bBrooks\b/iu, "CA", "AB", "Brooks"],
  [/\bWhitecourt\b/iu, "CA", "AB", "Whitecourt"],
  [/\bFort\s+St\.?\s+John\b/iu, "CA", "BC", "Fort St. John"],
  [/\bEstevan\b/iu, "CA", "SK", "Estevan"],
  [/\bSaskatoon\b/iu, "CA", "SK", "Saskatoon"],
  [/\bRegina\b/iu, "CA", "SK", "Regina"],
  [/\bMidland\b/iu, "US", "TX", "Midland"],
  [/\bOdessa\b/iu, "US", "TX", "Odessa"],
  [/\bHouston\b/iu, "US", "TX", "Houston"],
  [/\bWilliston\b/iu, "US", "ND", "Williston"],
];

function strVal(f, k) {
  return f?.[k]?.stringValue || "";
}
function boolVal(f, k, defVal = false) {
  return f?.[k]?.booleanValue !== undefined ? f[k].booleanValue : defVal;
}
function arrStr(f, k) {
  return (f?.[k]?.arrayValue?.values || []).map((v) => v.stringValue || "").filter(Boolean);
}

function buildPublicSearchTokens({
  companyName,
  countryCode,
  regionCode,
  regionName,
  city,
  categories,
  categoryCodes,
  services,
  basins,
  certifications,
  publicPhone,
  tollFreePhone,
}) {
  const bag = [
    companyName,
    countryCode,
    regionCode,
    regionName,
    city,
    ...(categories || []),
    ...(categoryCodes || []),
    ...(services || []),
    ...(basins || []),
    ...(certifications || []),
  ].join(" ");
  const words = normalizeText(bag).split(" ").filter((w) => w.length >= 2 && w.length <= 32);
  const set = new Set(words);
  for (const ph of [publicPhone, tollFreePhone]) {
    const d = String(ph || "").replace(/\D+/gu, "");
    if (d.length >= 7) {
      set.add(d.slice(-10));
      set.add(d.slice(-7));
      if (d.length >= 10) set.add(d.slice(-10, -7));
    }
  }
  return [...set].slice(0, 80);
}

async function fetchCollectionDocs(projectId, collectionId, selectFields) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const all = [];
  let lastDocName = null;
  while (true) {
    const token = await resolveAccessToken(projectId);
    const structuredQuery = {
      from: [{collectionId}],
      select: {fields: selectFields.map((fieldPath) => ({fieldPath}))},
      orderBy: [{field: {fieldPath: "__name__"}, direction: "ASCENDING"}],
      limit: 2500,
    };
    if (lastDocName) {
      structuredQuery.startAt = {values: [{referenceValue: lastDocName}], before: false};
    }
    const res = await fetch(url, {
      method: "POST",
      headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
      body: JSON.stringify({structuredQuery}),
      signal: AbortSignal.timeout(40000),
    });
    if (!res.ok) {
      throw new Error(`runQuery ${collectionId} HTTP ${res.status}: ${await res.text()}`);
    }
    const rows = await res.json();
    const docs = rows.filter((r) => r.document).map((r) => r.document);
    if (!docs.length) break;
    all.push(...docs);
    lastDocName = docs[docs.length - 1].name;
    console.log(`[bot15] Scanned ${all.length} docs in ${collectionId}...`);
    if (docs.length < 2500) break;
  }
  return all;
}

async function commitWritesInBatches(projectId, writes, label) {
  if (!writes.length) return;
  const commitUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  const chunkSize = 150;
  let done = 0;
  for (let i = 0; i < writes.length; i += chunkSize) {
    const slice = writes.slice(i, i + chunkSize);
    let ok = false;
    for (let attempt = 1; attempt <= 4; attempt++) {
      const token = await resolveAccessToken(projectId);
      const res = await fetch(commitUrl, {
        method: "POST",
        headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
        body: JSON.stringify({writes: slice}),
        signal: AbortSignal.timeout(45000),
      });
      if (res.ok) {
        ok = true;
        break;
      }
      if (attempt === 4) {
        throw new Error(`Commit failed (${label}) HTTP ${res.status}: ${await res.text()}`);
      }
      await new Promise((r) => setTimeout(r, 1200 * attempt));
    }
    if (ok) {
      done += slice.length;
      if (done % 1500 === 0 || done === writes.length) {
        console.log(`[bot15] Committed ${done}/${writes.length} ${label} writes...`);
      }
    }
  }
}

async function main() {
  console.log(
    `[bot15] Running Full Consistency Audit on project=${PROJECT_ID} (apply=${APPLY}, includeTraining=${INCLUDE_TRAINING})...`,
  );

  const publicDocs = await fetchCollectionDocs(PROJECT_ID, "yellow_pages_public_entries", [
    "companyName",
    "countryCode",
    "countryName",
    "continentCode",
    "isMiddleEast",
    "regionCode",
    "regionName",
    "city",
    "publicPhone",
    "tollFreePhone",
    "website",
    "categoryCodes",
    "categories",
    "services",
    "basins",
    "serviceAreas",
    "certifications",
    "verified",
    "effectiveTier",
    "publicVisible",
    "publicationStatus",
  ]);

  const stats = {
    totalPublicScanned: publicDocs.length,
    cityCanonicalized: 0,
    emptyCityRecovered: 0,
    regionOrCountryRepaired: 0,
    companyNameNormalized: 0,
    basinsBackfilled: 0,
    categoriesEnriched: 0,
    trainingTagged: 0,
    duplicatesRemoved: 0,
    totalDocsModified: 0,
  };

  const sampleChanges = [];
  const publicWrites = [];
  const privateWrites = [];
  const seenDedupKeys = new Map();

  for (const doc of publicDocs) {
    const docId = doc.name.split("/").pop();
    const f = doc.fields || {};
    const origName = strVal(f, "companyName");
    const origCc = strVal(f, "countryCode").trim().toUpperCase();
    const origRc = strVal(f, "regionCode").trim();
    const origCity = strVal(f, "city");
    const pubPhone = strVal(f, "publicPhone");
    const tfPhone = strVal(f, "tollFreePhone");
    const origCats = arrStr(f, "categoryCodes");
    const origCatLabels = arrStr(f, "categories");
    const origServices = arrStr(f, "services");
    const origBasins = arrStr(f, "basins");
    const origCerts = arrStr(f, "certifications");

    let newName = canonicalizeCompanyName(origName) || origName;
    let newCc = origCc;
    let newRc = canonicalizeRegionCode(origRc, newCc);
    let newCity = origCity;

    // Cross-check North American records missing regionCode or misattributed countryCode via NANPA area code
    const phoneGeo = inferGeoFromNanpaPhone(pubPhone);
    if ((newCc === "CA" || newCc === "US" || !newCc) && phoneGeo && !phoneGeo.isTollFree) {
      if (!newRc) {
        newCc = phoneGeo.countryCode;
        newRc = phoneGeo.regionCode;
      } else if (newCc === "CA" && phoneGeo.countryCode === "US" && !origCity) {
        newCc = "US";
        newRc = phoneGeo.regionCode;
      }
    }

    // Recover empty city from explicit name match or NANPA exchange / area code hub
    if (!newCity.trim()) {
      for (const [rx, eCc, eRc, eCity] of EXPLICIT_NAME_CITIES) {
        if (rx.test(newName) && (!newCc || newCc === eCc)) {
          newCc = eCc;
          if (!newRc) newRc = eRc;
          newCity = eCity;
          break;
        }
      }
      if (!newCity.trim() && phoneGeo && !phoneGeo.isTollFree && phoneGeo.hubCity) {
        newCity = phoneGeo.hubCity;
        if (!newRc) newRc = phoneGeo.regionCode;
        if (!newCc) newCc = phoneGeo.countryCode;
      }
    }

    // Handle "Perth, Wa" -> rc="WA" when AU
    if (newCc === "AU" && /,\s*Wa$/iu.test(origCity) && !newRc) {
      newRc = "WA";
    }

    newCity = canonicalizeCityName(newCity, newRc, newCc);

    const geo = inferCountryAndRegion(newCc || "CA", newRc);
    if (newCc && COUNTRY_BY_CODE.has(newCc)) {
      geo.countryCode = newCc;
    }

    // Deduplicate exact duplicate (normalizedCompanyName, digits10, canonicalCity, regionCode)
    const digits10 = String(pubPhone || tfPhone || "").replace(/\D+/gu, "").slice(-10);
    const normName = normalizedCompanyName(newName);
    const dedupKey = digits10.length === 10 && normName ?
      `${normName}|${digits10}|${newCity.toLowerCase()}|${geo.regionCode}` :
      "";
    if (dedupKey && seenDedupKeys.has(dedupKey)) {
      stats.duplicatesRemoved += 1;
      publicWrites.push({
        delete: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_public_entries/${encodeURIComponent(docId)}`,
      });
      privateWrites.push({
        update: {
          name: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_companies/${encodeURIComponent(docId)}`,
          fields: {
            publicationStatus: {stringValue: "unpublished"},
            updatedAt: {timestampValue: new Date().toISOString()},
          },
        },
        updateMask: {fieldPaths: ["publicationStatus", "updatedAt"]},
      });
      continue;
    }
    if (dedupKey) seenDedupKeys.set(dedupKey, docId);

    // Basins backfill
    let newBasins = origBasins;
    if (newBasins.length === 0 && geo.defaultBasins && geo.defaultBasins.length > 0) {
      newBasins = geo.defaultBasins;
    }

    // Categories backfill (only when empty) + Oil & Gas Training classification
    const validExistingCats = origCats.filter((c) =>
      CATEGORY_BY_CODE.has(c) && (INCLUDE_TRAINING || c !== "oil_gas_training_courses"),
    );
    const mergedCatSet = new Set(validExistingCats);

    // Check if existing or newly scanned company provides Oil & Gas Training / Safety Courses
    if (INCLUDE_TRAINING) {
      const trainCheck = classifyCategoriesFromText([newName, ...origServices], "");
      if (trainCheck.includes("oil_gas_training_courses")) {
        mergedCatSet.add("oil_gas_training_courses");
      }
    }

    if (mergedCatSet.size === 0) {
      const classified = classifyCategoriesFromText(
        [newName, ...origServices, ...origCatLabels],
        "",
      ).filter((c) => INCLUDE_TRAINING || c !== "oil_gas_training_courses");
      for (const c of classified) mergedCatSet.add(c);
    }

    if (mergedCatSet.size === 0) {
      // Fallback sector based on company name / services so zero public entries have empty categoryCodes
      if (/\b(?:truck|transport|haul|freight|logistics|towing)\b/iu.test(newName)) {
        mergedCatSet.add("trucking_heavy_haul");
      } else if (/\b(?:weld|fab|machine|steel|coating|metal)\b/iu.test(newName)) {
        mergedCatSet.add("welding_machining_fab");
      } else if (/\b(?:drill|rig|well)\b/iu.test(newName)) {
        mergedCatSet.add("drilling_rigs_directional");
      } else if (/\b(?:pipe|tubular|casing|octg|valve)\b/iu.test(newName)) {
        mergedCatSet.add("pipe_octg_supply");
      } else if (/\b(?:pump|compressor|power|engine)\b/iu.test(newName)) {
        mergedCatSet.add("pumps_artificial_lift");
      } else {
        mergedCatSet.add("equipment_rentals_tools");
      }
    }
    const newCats = [...mergedCatSet].slice(0, 8);
    const newCatLabels = newCats.map((c) => CATEGORY_BY_CODE.get(c)?.label || c);

    const cityChanged = newCity !== origCity;
    const rcOrCcChanged = geo.regionCode !== origRc || geo.countryCode !== origCc;
    const nameChanged = newName !== origName;
    const basinsChanged = newBasins.length !== origBasins.length;
    const catsChanged =
      newCats.length !== origCats.length ||
      newCats.some((c, idx) => c !== origCats[idx]);

    if (cityChanged) {
      if (!origCity.trim() && newCity) stats.emptyCityRecovered += 1;
      else stats.cityCanonicalized += 1;
    }
    if (rcOrCcChanged) stats.regionOrCountryRepaired += 1;
    if (nameChanged) stats.companyNameNormalized += 1;
    if (basinsChanged) stats.basinsBackfilled += 1;
    if (catsChanged) {
      stats.categoriesEnriched += 1;
      if (newCats.includes("oil_gas_training_courses") && !origCats.includes("oil_gas_training_courses")) {
        stats.trainingTagged += 1;
      }
    }

    if (cityChanged || rcOrCcChanged || nameChanged || basinsChanged || catsChanged) {
      stats.totalDocsModified += 1;
      if (sampleChanges.length < 35) {
        sampleChanges.push({
          docId,
          before: `${origName} | ${origCity}, ${origRc}, ${origCc} | cats=${origCats.length}`,
          after: `${newName} | ${newCity}, ${geo.regionCode}, ${geo.countryCode} | cats=${newCats.join(",")}`,
        });
      }

      const newServiceAreas = [newCity, geo.regionName].filter(Boolean);
      const newSearchTokens = buildPublicSearchTokens({
        companyName: newName,
        countryCode: geo.countryCode,
        regionCode: geo.regionCode,
        regionName: geo.regionName,
        city: newCity,
        categories: newCatLabels,
        categoryCodes: newCats,
        services: origServices,
        basins: newBasins,
        certifications: origCerts,
        publicPhone: pubPhone,
        tollFreePhone: tfPhone,
      });

      const nowIso = new Date().toISOString();
      const pubFields = {
        companyName: toFirestoreValue(newName),
        countryCode: toFirestoreValue(geo.countryCode),
        countryName: toFirestoreValue(geo.countryName),
        continentCode: toFirestoreValue(geo.continentCode),
        isMiddleEast: toFirestoreValue(geo.isMiddleEast),
        regionCode: toFirestoreValue(geo.regionCode),
        regionName: toFirestoreValue(geo.regionName),
        city: toFirestoreValue(newCity),
        basins: toFirestoreValue(newBasins),
        serviceAreas: toFirestoreValue(newServiceAreas),
        categoryCodes: toFirestoreValue(newCats),
        categories: toFirestoreValue(newCatLabels),
        searchTokens: toFirestoreValue(newSearchTokens),
        updatedAt: toFirestoreValue(nowIso, "updatedAt"),
      };
      publicWrites.push({
        update: {
          name: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_public_entries/${encodeURIComponent(docId)}`,
          fields: pubFields,
        },
        updateMask: {fieldPaths: Object.keys(pubFields)},
        currentDocument: {exists: true},
      });

      const privFields = {
        companyName: toFirestoreValue(newName),
        normalizedCompanyName: toFirestoreValue(normName),
        countryCode: toFirestoreValue(geo.countryCode),
        regionCode: toFirestoreValue(geo.regionCode),
        regionName: toFirestoreValue(geo.regionName),
        city: toFirestoreValue(newCity),
        basins: toFirestoreValue(newBasins),
        serviceAreas: toFirestoreValue(newServiceAreas),
        categoryCodes: toFirestoreValue(newCats),
        categories: toFirestoreValue(newCatLabels),
        updatedAt: toFirestoreValue(nowIso, "updatedAt"),
      };
      privateWrites.push({
        update: {
          name: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_companies/${encodeURIComponent(docId)}`,
          fields: privFields,
        },
        updateMask: {fieldPaths: Object.keys(privFields)},
      });
    }
  }

  console.log("[bot15] Audit Summary:", stats);
  console.log("[bot15] Sample Repairs:", sampleChanges.slice(0, 18));

  await fs.mkdir(REPORTS_DIR, {recursive: true});
  const reportLines = [
    "# Bot 15 — Full Directory Field Consistency & Town Consolidation Audit Report",
    "",
    `- **Generated At**: \`${new Date().toISOString()}\``,
    `- **Project**: \`${PROJECT_ID}\` (\`apply=${APPLY}\`, \`includeTraining=${INCLUDE_TRAINING}\`)`,
    `- **Total Public Entries Audited**: **${stats.totalPublicScanned.toLocaleString()}**`,
    `- **Total Entries Repaired / Standardized**: **${stats.totalDocsModified.toLocaleString()}**`,
    `  - Town / County / USDOT / FMCSA City Names Canonicalized: **${stats.cityCanonicalized.toLocaleString()}**`,
    `  - Empty \`city\` Records Recovered via NANPA Exchange / Name: **${stats.emptyCityRecovered.toLocaleString()}**`,
    `  - \`countryCode\` / \`regionCode\` Repaired via Area Code: **${stats.regionOrCountryRepaired.toLocaleString()}**`,
    `  - ALL-CAPS / HTML-Entity Company Names Normalized: **${stats.companyNameNormalized.toLocaleString()}**`,
    `  - Missing \`basins\` Backfilled: **${stats.basinsBackfilled.toLocaleString()}**`,
    `  - Service Categories Enriched / Fixed: **${stats.categoriesEnriched.toLocaleString()}** (Oil & Gas Training Tagged: **${stats.trainingTagged.toLocaleString()}**)`,
    `  - Exact Duplicate Public Entries Removed: **${stats.duplicatesRemoved.toLocaleString()}**`,
    "",
    "## Sample Field Standardizations",
    "",
    ...sampleChanges.slice(0, 25).map((s) => `- \`${s.docId}\`: \`${s.before}\` → **\`${s.after}\`**`),
    "",
  ];
  await fs.writeFile(path.join(REPORTS_DIR, "15_CONSISTENCY_AUDIT_REPORT.md"), reportLines.join("\n"), "utf8");

  if (!APPLY) {
    console.log("[bot15] Dry-run complete. Re-run with --apply to write repairs to Firestore.");
    return;
  }

  await commitWritesInBatches(PROJECT_ID, publicWrites, "yellow_pages_public_entries");
  await commitWritesInBatches(PROJECT_ID, privateWrites, "yellow_pages_companies");
  console.log("[bot15] All consistency repairs committed to Firestore!");
}

main().catch((err) => {
  console.error("[bot15] FATAL:", err);
  process.exit(1);
});
