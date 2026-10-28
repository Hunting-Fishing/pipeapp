#!/usr/bin/env node
/**
 * Bot 13 — PipeBuyer Live Directory Area & Town Business Counts Indexer
 *
 * 1. Scans all active public entries in `yellow_pages_public_entries`.
 * 2. Optionally canonicalizes town/city spellings (`--fix-cities`: `Ft McMurray` ->
 *    `Fort McMurray`, `HOUSTON` -> `Houston`, `Fort St John` -> `Fort St. John`, etc.)
 *    across `yellow_pages_public_entries` and `yellow_pages_companies` via field-masked
 *    updates so `where("city", "==", ...)` matches 100% of records in each town.
 * 3. Publishes the compact 1-document facet index `yellow_pages_meta/directory_counts`
 *    (`totalBusinesses`, `byContinent`, `byCountry`, `byRegion`, `byCategory`, `townsPacked`)
 *    for single-read (`~15ms`) town/region/country/continent filter badges in `/services`.
 */

import {createRequire} from "node:module";
import {resolveAccessToken, toFirestoreValue} from "./global_shared_utils.mjs";

const require = createRequire(import.meta.url);
const {
  COUNTRY_BY_CODE,
  canonicalizeCityName,
  canonicalizeRegionCode,
  inferRegionFromCountryAndCity,
  normalizeCityKey,
} = require("../../firebase/functions/yellow_pages_taxonomy.js");

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const FIX_CITIES = args.includes("--fix-cities");
const projIdx = args.indexOf("--project");
const PROJECT_ID = projIdx !== -1 && args[projIdx + 1] ? args[projIdx + 1] : "flutter-flow-pipe";

function strVal(fields, k) {
  return fields?.[k]?.stringValue || "";
}
function boolVal(fields, k, defVal = false) {
  return fields?.[k]?.booleanValue !== undefined ? fields[k].booleanValue : defVal;
}
function arrStr(fields, k) {
  const vals = fields?.[k]?.arrayValue?.values || [];
  return vals.map((v) => v.stringValue || "").filter(Boolean);
}

async function fetchAllPublicEntries(projectId) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const all = [];
  let lastDocName = null;

  while (true) {
    const token = await resolveAccessToken(projectId);
    const structuredQuery = {
      from: [{collectionId: "yellow_pages_public_entries"}],
      select: {
        fields: [
          {fieldPath: "verified"},
          {fieldPath: "effectiveTier"},
          {fieldPath: "isPaidTier"},
          {fieldPath: "nonExpiringPaid"},
          {fieldPath: "paidThrough"},
          {fieldPath: "countryCode"},
          {fieldPath: "regionCode"},
          {fieldPath: "city"},
          {fieldPath: "continentCode"},
          {fieldPath: "isMiddleEast"},
          {fieldPath: "categoryCodes"},
          {fieldPath: "publicVisible"},
          {fieldPath: "publicationStatus"},
          {fieldPath: "isFlaggedProhibited"},
          {fieldPath: "adminViewingEnabled"},
        ],
      },
      orderBy: [{field: {fieldPath: "__name__"}, direction: "ASCENDING"}],
      limit: 2500,
    };
    if (lastDocName) {
      structuredQuery.startAt = {
        values: [{referenceValue: lastDocName}],
        before: false,
      };
    }

    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({structuredQuery}),
      signal: AbortSignal.timeout(30000),
    });
    if (!res.ok) {
      throw new Error(`Firestore runQuery HTTP ${res.status}: ${await res.text()}`);
    }
    const rows = await res.json();
    const docs = rows.filter((r) => r.document).map((r) => r.document);
    if (docs.length === 0) break;
    all.push(...docs);
    lastDocName = docs[docs.length - 1].name;
    console.log(`[bot13] Scanned ${all.length} public entries...`);
    if (docs.length < 2500) break;
  }
  return all;
}

async function commitCityFixes(projectId, fixes) {
  if (fixes.length === 0) return;
  const commitUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  const writes = [];
  for (const fix of fixes) {
    const fields = {};
    const fieldPaths = [];
    if (fix.cleanCity !== undefined) {
      fields.city = {stringValue: fix.cleanCity};
      fieldPaths.push("city");
    }
    if (fix.cleanRc !== undefined) {
      fields.regionCode = {stringValue: fix.cleanRc};
      fieldPaths.push("regionCode");
    }
    for (const col of ["yellow_pages_public_entries", "yellow_pages_companies"]) {
      writes.push({
        update: {
          name: `projects/${projectId}/databases/(default)/documents/${col}/${encodeURIComponent(fix.docId)}`,
          fields,
        },
        updateMask: {fieldPaths},
        currentDocument: {exists: true},
      });
    }
  }

  // Batch 100 masked updates per commit
  for (let i = 0; i < writes.length; i += 100) {
    const slice = writes.slice(i, i + 100);
    const token = await resolveAccessToken(projectId);
    const res = await fetch(commitUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({writes: slice}),
      signal: AbortSignal.timeout(30000),
    });
    if (!res.ok) {
      // Fallback: apply public_entries only if any private company docId didn't exist
      const pubOnly = slice.filter((w) => w.update.name.includes("/yellow_pages_public_entries/"));
      if (pubOnly.length > 0) {
        await fetch(commitUrl, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({writes: pubOnly}),
          signal: AbortSignal.timeout(30000),
        });
      }
    }
  }
  console.log(`[bot13] Canonicalized city spelling on ${fixes.length} directory entries.`);
}

async function writeDirectoryCountsDoc(projectId, countsDoc) {
  const commitUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  const token = await resolveAccessToken(projectId);
  const fields = {
    schemaVersion: toFirestoreValue(1),
    totalBusinesses: toFirestoreValue(countsDoc.totalBusinesses),
    verifiedBusinesses: toFirestoreValue(countsDoc.verifiedBusinesses || 0),
    byContinent: toFirestoreValue(countsDoc.byContinent),
    byCountry: toFirestoreValue(countsDoc.byCountry),
    byRegion: toFirestoreValue(countsDoc.byRegion),
    byCategory: toFirestoreValue(countsDoc.byCategory),
    townsPacked: toFirestoreValue(countsDoc.townsPacked),
    updatedAt: toFirestoreValue(new Date().toISOString(), "updatedAt"),
  };

  const res = await fetch(commitUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      writes: [
        {
          update: {
            name: `projects/${projectId}/databases/(default)/documents/yellow_pages_meta/directory_counts`,
            fields,
          },
        },
      ],
    }),
    signal: AbortSignal.timeout(30000),
  });
  if (!res.ok) {
    throw new Error(`Failed writing directory_counts HTTP ${res.status}: ${await res.text()}`);
  }
  console.log(`[bot13] Published yellow_pages_meta/directory_counts to ${projectId}!`);
}

async function main() {
  console.log(`[bot13] Indexing live directory counts on project=${PROJECT_ID} (apply=${APPLY}, fixCities=${FIX_CITIES})...`);
  const docs = await fetchAllPublicEntries(PROJECT_ID);

  let totalBusinesses = 0;
  let verifiedBusinesses = 0;
  const byContinent = {};
  const byCountry = {};
  const byRegion = {};
  const byCategory = {};
  const byTown = new Map();
  const cityFixes = [];

  for (const doc of docs) {
    const f = doc.fields || {};
    if (boolVal(f, "publicVisible", true) === false) continue;
    const pubStatus = strVal(f, "publicationStatus");
    if (pubStatus && pubStatus !== "published") continue;
    if (boolVal(f, "isFlaggedProhibited", false) === true) continue;
    if (boolVal(f, "adminViewingEnabled", true) === false) continue;
    const effTier = strVal(f, "effectiveTier");
    if (
      effTier &&
      !["featured_platinum", "paid_verified", "free_verified", "free_basic"].includes(effTier)
    ) {
      continue;
    }

    totalBusinesses += 1;
    if (boolVal(f, "verified", false) === true) {
      verifiedBusinesses += 1;
    }
    const cc = strVal(f, "countryCode").trim().toUpperCase();
    const rawRc = strVal(f, "regionCode");
    const rawCity = strVal(f, "city");
    let rc = canonicalizeRegionCode(rawRc, cc);
    const cleanCity = canonicalizeCityName(rawCity, rc, cc);
    if (!rc && cc && cleanCity) {
      const inferredRc = inferRegionFromCountryAndCity(cc, cleanCity);
      if (inferredRc) rc = inferredRc;
    }
    const countryMeta = COUNTRY_BY_CODE.get(cc);

    if (cc) byCountry[cc] = (byCountry[cc] || 0) + 1;
    if (countryMeta) {
      const cCode = countryMeta.continent || countryMeta.continentCode;
      if (cCode) byContinent[cCode] = (byContinent[cCode] || 0) + 1;
      if (countryMeta.alsoAsia && cCode !== "asia") {
        byContinent.asia = (byContinent.asia || 0) + 1;
      }
      if (countryMeta.alsoEurope && cCode !== "europe") {
        byContinent.europe = (byContinent.europe || 0) + 1;
      }
      if (countryMeta.isMiddleEast || boolVal(f, "isMiddleEast", false)) {
        byContinent.middle_east = (byContinent.middle_east || 0) + 1;
      }
    }

    if (cc && rc) {
      const rKey = `${cc}:${rc}`;
      byRegion[rKey] = (byRegion[rKey] || 0) + 1;
    }

    for (const cat of arrStr(f, "categoryCodes")) {
      byCategory[cat] = (byCategory[cat] || 0) + 1;
    }

    const cityChanged = Boolean(rawCity.trim() && rawCity !== cleanCity);
    const rcChanged = Boolean(rc && rawRc.trim() !== rc && rawRc.trim().toUpperCase() !== cc);
    if (cityChanged || rcChanged) {
      const docId = decodeURIComponent(doc.name.split("/").pop());
      cityFixes.push({
        docId,
        cleanCity: cityChanged ? cleanCity : undefined,
        cleanRc: rcChanged ? rc : undefined,
      });
    }

    if (cleanCity && cc) {
      const tKey = `${cc}|${rc}|${normalizeCityKey(cleanCity)}`;
      const existing = byTown.get(tKey);
      if (existing) {
        existing.count += 1;
      } else {
        byTown.set(tKey, {
          city: cleanCity,
          regionCode: rc,
          countryCode: cc,
          count: 1,
        });
      }
    }
  }

  const towns = [...byTown.values()]
      .sort((a, b) => a.city.localeCompare(b.city))
      .map((t) => [t.city, t.regionCode, t.countryCode, t.count]);

  const townsPacked = towns
      .map(([city, regionCode, countryCode, count]) =>
        `${city.replace(/[\t\r\n]+/gu, " ")}\t${regionCode}\t${countryCode}\t${count}`,
      )
      .join("\n");

  console.log(`[bot13] Summary:`);
  console.log(`  • Total Active Public Businesses: ${totalBusinesses} (Verified: ${verifiedBusinesses})`);
  console.log(`  • Continents:`, byContinent);
  console.log(`  • Populated Countries: ${Object.keys(byCountry).length}`);
  console.log(`  • Populated Sub-Regions: ${Object.keys(byRegion).length}`);
  console.log(`  • Unique Towns/Cities: ${towns.length} (${(Buffer.byteLength(townsPacked, "utf8") / 1024).toFixed(1)} KB packed)`);
  console.log(`  • Non-canonical City Spellings Found: ${cityFixes.length}`);

  if (APPLY && FIX_CITIES && cityFixes.length > 0) {
    await commitCityFixes(PROJECT_ID, cityFixes);
  }
  if (APPLY) {
    await writeDirectoryCountsDoc(PROJECT_ID, {
      totalBusinesses,
      byContinent,
      byCountry,
      byRegion,
      byCategory,
      townsPacked,
    });
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
