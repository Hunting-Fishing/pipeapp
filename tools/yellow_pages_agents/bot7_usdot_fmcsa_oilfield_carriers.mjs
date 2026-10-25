#!/usr/bin/env node
/**
 * Bot 7 — Federal USDOT / FMCSA Active Oilfield Equipment, Pipe & Fluid Carrier Census Crawler
 *
 * Queries the official U.S. Department of Transportation Company Census SODA API
 * (`https://data.transportation.gov/resource/az4n-8mr2.json`) across BOTH:
 *   1. Canada (`phy_country = 'CA'` — AB, SK, BC, MB, ON, QC, NB, NS, NL):
 *      Active (`status_code = 'A'`) cross-border & federally registered Oilfield Equipment,
 *      Liquids/Gases (Vac/Water/Fluid/NGL), Heavy Machinery/Rig Moving, and Pipe/Metal fleets
 *      with recent MCS-150 biennial updates (`mcs150_date >= '20230101'`) and verified phones.
 *   2. USA (`phy_country = 'US'` — TX, ND, OK, NM, WY, LA, CO, PA, OH, WV, KS, MT, UT, AK, CA, AR, MS):
 *      Active (`status_code = 'A'`) Oilfield Equipment (`crgo_oilfield = 'X'`) fleets updated
 *      in 2024–2026 (`mcs150_date >= '20240101'`), strictly filtered to exclude general-freight
 *      "checked-every-box" spam (excluding household goods, meat, produce, cold food, beverages)
 *      and keeping dedicated oilpatch carriers & verified multi-unit oilfield fleets.
 *
 * Outputs:
 *   - `data/yellow_pages/ledger/07_usdot_oilfield_carriers.json`
 *   - `data/yellow_pages/reports/07_usdot_oilfield_carriers_report.md`
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

const USDOT_API = "https://data.transportation.gov/resource/az4n-8mr2.json";
const USER_AGENT = "PipeBuyerDirectoryAudit/1.2 (+https://pipebuyer.com; federal-open-data)";

const OILPATCH_NAME_SIGNAL =
  /\b(?:oil|oilfield|gas|energy|petro|pipe|pipeline|tubular|octg|drill|rig|winch|heavy|haul|hotshot|hot\s*shot|vac|vacuum|hydrovac|water|fluid|tank|frac|wireline|well|wellhead|valve|crane|picker|weld|fab|roustabout|field\s*service|midstream|permian|bakken|eagle\s*ford|panhandle|lonestar|lone\s*star|texas|west\s*tx|odessa|midland|albertan?|foothills|chinook|prairie|northern|badlands|wyoming|sooner|red\s*river|industrial|specialized|crude|condensate|chemical|sand|proppant|matting|lease|environmental|remediation|disposal)\b/iu;

const NON_OILPATCH_CARRIER_EXCLUDE =
  /\b(?:moving\s+and\s+storage|van\s+lines|auto\s+transport|car\s+hauler|towing\s+and\s+recovery|lawn\s+care|landscaping|tree\s+service|roofing|plumbing\s+and\s+heating|limousine|charter\s+bus|tour\s+bus|courier|parcel|amazon|fedex|ups\s+freight|food\s+service|grocery|dairy|poultry|livestock|cattle\s+co|grain\s+farm|logging\s+inc)\b/iu;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function titleCaseBusiness(raw = "") {
  const str = String(raw || "").trim().replace(/\s+/gu, " ");
  if (!str) return "";
  // Preserve common industry acronyms in uppercase
  const upperKeep = new Set([
    "LLC", "LP", "LLP", "INC", "CORP", "LTD", "CO", "USA", "US", "TX", "ND", "OK", "AB", "BC", "SK",
    "OCTG", "NDT", "BOP", "SWD", "NGL", "H2S", "HSE", "API", "JB", "JJ", "JR", "RJ", "DJ", "CJ", "TJ",
  ]);
  return str
    .split(" ")
    .map((word) => {
      const clean = word.replace(/[^A-Za-z0-9]/gu, "").toUpperCase();
      if (upperKeep.has(clean)) return word.toUpperCase();
      if (word.length <= 2 && /^[A-Z0-9&]+$/u.test(word)) return word;
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    })
    .join(" ");
}

async function fetchSocrataPage(whereClause, limit = 1000, offset = 0) {
  const params = new URLSearchParams({
    $where: whereClause,
    $limit: String(limit),
    $offset: String(offset),
    $order: "dot_number ASC",
  });
  const url = `${USDOT_API}?${params.toString()}`;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      const res = await fetch(url, {
        headers: {"User-Agent": USER_AGENT, Accept: "application/json"},
        signal: AbortSignal.timeout(25000),
      });
      if (res.ok) {
        return await res.json();
      }
      if (res.status === 429 || res.status >= 500) {
        await sleep(800 * attempt);
        continue;
      }
      return [];
    } catch (_) {
      await sleep(800 * attempt);
    }
  }
  return [];
}

function isHighSignalOilpatchCarrier(row, country) {
  const dba = String(row.dba_name || "").trim();
  const legal = String(row.legal_name || "").trim();
  const displayName = dba || legal;
  if (!displayName || NON_OILPATCH_CARRIER_EXCLUDE.test(displayName)) return false;

  const powerUnits = Number(row.power_units || row.truck_units || 0);
  const hasNameSignal = OILPATCH_NAME_SIGNAL.test(`${legal} ${dba}`);
  const isDedicatedNoGenFreight = row.crgo_genfreight !== "X";
  const hasTankOrPipeOrMachinery =
    row.crgo_liqgas === "X" || row.crgo_metalsheet === "X" || row.crgo_chem === "X";

  if (country === "CA") {
    // Canadian cross-border & federally registered oilfield/tank/machinery carriers:
    // Require either oilpatch name signal, dedicated oilfield flag (`crgo_oilfield='X'`), or >= 2 power units in AB/SK/BC
    if (row.crgo_oilfield === "X") {
      return hasNameSignal || isDedicatedNoGenFreight || powerUnits >= 2;
    }
    return hasNameSignal || (["AB", "SK", "BC"].includes(String(row.phy_state || "").toUpperCase()) && isDedicatedNoGenFreight && powerUnits >= 3);
  }

  // US (`crgo_oilfield === 'X'`):
  // Filter out 1-truck general-freight spammers who checked every box on MCS-150
  if (hasNameSignal) return true;
  if (isDedicatedNoGenFreight && powerUnits >= 1) return true;
  if (hasTankOrPipeOrMachinery && powerUnits >= 3 && ["TX", "ND", "OK", "NM", "WY", "LA"].includes(String(row.phy_state || "").toUpperCase())) {
    return true;
  }
  return false;
}

function mapCarrierRowToRecord(row) {
  const dba = String(row.dba_name || "").trim();
  const legal = String(row.legal_name || "").trim();
  // Prefer DBA if legal name looks like an individual person name and DBA is a trade name
  const chosenRawName =
    dba && (row.business_org_desc === "INDIVIDUAL" || OILPATCH_NAME_SIGNAL.test(dba))
      ? dba
      : legal || dba;
  const companyName = titleCaseBusiness(chosenRawName);
  if (!companyName) return null;

  const phonePrimary = normalizeNorthAmericanPhone(row.phone || "");
  const phoneCell = normalizeNorthAmericanPhone(row.cell_phone || "");
  const bestLocal =
    phonePrimary.validNanpa && !phonePrimary.isTollFree
      ? phonePrimary
      : phoneCell.validNanpa && !phoneCell.isTollFree
        ? phoneCell
        : phonePrimary.validNanpa
          ? phonePrimary
          : phoneCell;
  if (!bestLocal.validNanpa) return null;

  const tollFree =
    phonePrimary.validNanpa && phonePrimary.isTollFree
      ? phonePrimary.display
      : phoneCell.validNanpa && phoneCell.isTollFree
        ? phoneCell.display
        : "";

  const geo = inferCountryAndRegion(
    String(row.phy_country || "US").toUpperCase(),
    String(row.phy_state || "").toUpperCase(),
  );

  const powerUnits = Number(row.power_units || row.truck_units || 0);
  const drivers = Number(row.total_drivers || 0);
  const services = [];
  const baseCats = new Set();

  if (row.crgo_oilfield === "X") {
    services.push("Oilfield Equipment Hauling");
    if (powerUnits > 0 && powerUnits <= 2) {
      baseCats.add("hotshot_pilot_logistics");
    } else {
      baseCats.add("trucking_heavy_haul");
    }
  }
  if (row.crgo_liqgas === "X") {
    services.push("Oilfield Fluids, Water & Tank Hauling");
    baseCats.add("vacuum_hydrovac_fluid");
  }
  if (row.crgo_machlrg === "X") {
    services.push("Heavy Machinery & Rig Moving");
    baseCats.add("trucking_heavy_haul");
  }
  if (row.crgo_metalsheet === "X") {
    services.push("Pipe, Tubular & Steel Hauling");
    baseCats.add("trucking_heavy_haul");
  }
  if (row.crgo_chem === "X") {
    services.push("Oilfield Chemicals Transport");
    baseCats.add("chemical_mud_lubricants");
  }
  if (powerUnits > 0) {
    services.push(`Active Fleet: ${powerUnits} Power Unit${powerUnits === 1 ? "" : "s"}`);
  }

  const classified = classifyCategoriesFromText(
    [companyName, ...services, ...baseCats],
    services.join(" "),
  );
  const categoryCodes = Array.from(new Set([...baseCats, ...classified]));

  const certifications = [`USDOT #${row.dot_number}`];
  if (row.docket1prefix && row.docket1 && row.docket1_status_code === "A") {
    certifications.push(`${row.docket1prefix}-${row.docket1}`);
  }
  if (row.hm_ind === "Y") {
    certifications.push("HAZMAT Certified");
  }

  const rawEmail = String(row.email_address || "").trim().toLowerCase();
  const cleanEmail =
    rawEmail && /^[^\s@]+@[^\s@]+\.[a-z]{2,12}$/iu.test(rawEmail) ? rawEmail : "";

  const dotNum = String(row.dot_number || "").trim();
  return {
    recordId: `usdot-${dotNum}`,
    discoveryChannel: "usdot_fmcsa_oilfield_census",
    externalSourceId: dotNum,
    mcs150Date: String(row.mcs150_date || ""),
    powerUnits,
    totalDrivers: drivers,
    companyName,
    normalizedCompanyName: normalizedCompanyName(companyName),
    countryCode: geo.countryCode,
    regionCode: geo.regionCode,
    regionName: geo.regionName,
    timezone: geo.timezone,
    basins: geo.defaultBasins || [],
    city: titleCaseBusiness(row.phy_city || ""),
    postalCode: String(row.phy_zip || "").trim(),
    streetAddress: titleCaseBusiness(row.phy_street || ""),
    directoryPhone: bestLocal.isTollFree ? "" : bestLocal.display,
    tollFreePhone: tollFree || (bestLocal.isTollFree ? bestLocal.display : ""),
    generalEmail: cleanEmail,
    website: "",
    categoryCodes,
    services,
    certifications,
    emergency24x7: false,
    sourceReferences: [
      {
        sourceType: "federal_usdot_fmcsa_census",
        sourceLabel: `USDOT / FMCSA Active Carrier Census (DOT #${dotNum}, MCS-150 ${row.mcs150_date || "Active"})`,
        sourceUrl: `https://safer.fmcsa.dot.gov/query.asp?searchtype=ANY&query_type=queryCarrierSnapshot&query_param=USDOT&query_string=${dotNum}`,
        discoveredAt: new Date().toISOString(),
      },
    ],
  };
}

export async function runUsdotFmcsaOilfieldCrawler({maxUsPages = 18, maxCaPages = 4} = {}) {
  await fs.mkdir(LEDGER_DIR, {recursive: true});
  await fs.mkdir(REPORTS_DIR, {recursive: true});

  const byKey = new Map();
  let rawRowsScanned = 0;

  // 1. Pull Canadian Active Oilfield / Fluid / Heavy Machinery Carriers (`phy_country='CA'`)
  const caWhere =
    "status_code='A' AND phy_country='CA' AND mcs150_date >= '20230101' AND phone IS NOT NULL AND (crgo_oilfield='X' OR crgo_liqgas='X' OR crgo_machlrg='X') AND crgo_household IS NULL AND crgo_meat IS NULL AND crgo_produce IS NULL";

  for (let page = 0; page < maxCaPages; page += 1) {
    const rows = await fetchSocrataPage(caWhere, 1000, page * 1000);
    if (!rows.length) break;
    rawRowsScanned += rows.length;
    for (const row of rows) {
      if (!isHighSignalOilpatchCarrier(row, "CA")) continue;
      const rec = mapCarrierRowToRecord(row);
      if (rec && rec.normalizedCompanyName) {
        const key = `${rec.normalizedCompanyName}|${rec.countryCode}|${rec.regionCode}`;
        if (!byKey.has(key)) byKey.set(key, rec);
      }
    }
    if (rows.length < 1000) break;
    await sleep(200);
  }

  // 2. Pull US Oilpatch States Active 2024–2026 Oilfield Equipment Carriers (`phy_country='US'`)
  const usWhere =
    "status_code='A' AND phy_country='US' AND phy_state in('TX','ND','OK','NM','WY','LA','CO','PA','OH','WV','KS','MT','UT','AK','CA','AR','MS') AND mcs150_date >= '20240101' AND phone IS NOT NULL AND crgo_oilfield='X' AND crgo_household IS NULL AND crgo_meat IS NULL AND crgo_produce IS NULL AND crgo_coldfood IS NULL AND crgo_beverages IS NULL";

  for (let page = 0; page < maxUsPages; page += 1) {
    const rows = await fetchSocrataPage(usWhere, 1000, page * 1000);
    if (!rows.length) break;
    rawRowsScanned += rows.length;
    for (const row of rows) {
      if (!isHighSignalOilpatchCarrier(row, "US")) continue;
      const rec = mapCarrierRowToRecord(row);
      if (rec && rec.normalizedCompanyName) {
        const key = `${rec.normalizedCompanyName}|${rec.countryCode}|${rec.regionCode}`;
        if (!byKey.has(key)) byKey.set(key, rec);
      }
    }
    if (rows.length < 1000) break;
    await sleep(200);
  }

  const companies = Array.from(byKey.values());
  const byRegion = {};
  for (const c of companies) {
    const k = `${c.countryCode}-${c.regionCode}`;
    byRegion[k] = (byRegion[k] || 0) + 1;
  }

  const out = {
    generatedAt: new Date().toISOString(),
    rawCensusRowsScanned: rawRowsScanned,
    totalHighSignalOilfieldCarriers: companies.length,
    byCountry: {
      CA: companies.filter((c) => c.countryCode === "CA").length,
      US: companies.filter((c) => c.countryCode === "US").length,
    },
    byRegion,
    companies,
  };

  const outJsonPath = path.join(LEDGER_DIR, "07_usdot_oilfield_carriers.json");
  await fs.writeFile(outJsonPath, JSON.stringify(out, null, 2), "utf8");

  const md = [
    "# Bot 7 — Federal USDOT / FMCSA Active Oilfield Equipment & Fluid Carrier Census Report",
    "",
    `- **Generated At**: \`${out.generatedAt}\``,
    `- **Raw Active Census Rows Scanned**: **${rawRowsScanned.toLocaleString()}**`,
    `- **High-Signal Pure Oilpatch Carriers Retained**: **${companies.length.toLocaleString()}** (Canada: **${out.byCountry.CA.toLocaleString()}**, USA: **${out.byCountry.US.toLocaleString()}**)`,
    `- **Province / State Breakdown**: ${Object.entries(byRegion).sort((a, b) => b[1] - a[1]).map(([k, v]) => `\`${k}\`: ${v}`).join(" • ")}`,
    "",
    "## Sample of Verified Active USDOT Oilfield Fleets (First 60 Shown)",
    "",
    "| Company | City / Region | Country | Phone | Power Units | Services / Certifications |",
    "| :--- | :--- | :---: | :--- | ---: | :--- |",
    ...companies.slice(0, 60).map(
      (c) =>
        `| ${c.companyName} | ${[c.city, c.regionCode].filter(Boolean).join(", ")} | ${c.countryCode} | ${c.directoryPhone || c.tollFreePhone} | ${c.powerUnits || 1} | ${c.certifications.join(", ")} |`,
    ),
    "",
  ];
  await fs.writeFile(
    path.join(REPORTS_DIR, "07_usdot_oilfield_carriers_report.md"),
    md.join("\n"),
    "utf8",
  );

  console.log(
    `[Bot 7] USDOT/FMCSA Census: Scanned ${rawRowsScanned} active rows -> ${companies.length} pure Oilfield fleets (CA: ${out.byCountry.CA}, US: ${out.byCountry.US}) -> ${outJsonPath}`,
  );
  return out;
}

if (process.argv[1]?.endsWith("bot7_usdot_fmcsa_oilfield_carriers.mjs")) {
  runUsdotFmcsaOilfieldCrawler().catch((err) => {
    console.error("[Bot 7 Error]", err.message);
    process.exitCode = 1;
  });
}
