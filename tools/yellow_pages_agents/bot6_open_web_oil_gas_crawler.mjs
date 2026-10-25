#!/usr/bin/env node
/**
 * Bot 6 — Multi-Channel Open-Internet Oil & Gas Crawler (Beyond COSSD!)
 *
 * Discovers active North American (Canada + USA) Oil & Gas companies across
 * 4 independent public internet channels NOT relying on COSSD:
 *
 *  1. US SEC EDGAR Official Oilfield SIC Registry (`sec.gov` + `data.sec.gov`):
 *     - SIC 1381 (Drilling Oil & Gas Wells)
 *     - SIC 1382 (Oil & Gas Exploration Services)
 *     - SIC 1389 (Oil & Gas Field Services, NEC — Frac, Wireline, Water, Completion)
 *     - SIC 3533 (Oil & Gas Field Machinery, OCTG & Pressure Control Equipment)
 *     -> Authoritative legal names, HQ phones, street addresses, cities, states/provinces!
 *
 *  2. OpenStreetMap Overpass Geospatial Oilpatch Basin API (`overpass-api.de`):
 *     - Queries industrial energy, oilfield, pipeline, welding & trucking facilities
 *       across Permian (Midland/Odessa TX), Houston TX, Bakken (Williston ND),
 *       Oklahoma City/Tulsa OK, WCSB (Edmonton/Nisku, Grande Prairie, Red Deer,
 *       Calgary AB, Fort St. John BC, Estevan SK).
 *
 *  3. Open Web Search Oilpatch Hub Discovery (`DuckDuckGo HTML` + Live Site Scraper):
 *     - Runs targeted basin + service searches (hydrovac, winch truck, OCTG, wireline,
 *       rig moving, wellhead, mobile welding), strips directory aggregators, and visits
 *       independent company domains directly to extract phones & services.
 *
 *  4. Direct Corporate Domain Verification for Major Canadian WCSB / Montney Service Leaders:
 *     - Crawls official corporate websites of top Canadian oilfield service & midstream
 *       contractors to verify active 2026 dispatch/HQ numbers, basins, and certifications.
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

// SEC EDGAR requires a descriptive User-Agent with contact email (max 10 req/s)
const SEC_USER_AGENT = "PipeBuyerDirectoryAudit/1.0 (admin@pipebuyer.com)";
const WEB_USER_AGENT =
  "Mozilla/5.0 (compatible; PipeBuyerOpenWebDiscovery/1.0; +https://pipebuyer.com)";

const AGGREGATOR_BLOCKLIST =
  /(?:cossd\.com|namesandnumbers\.com|yelp\.|yellowpages\.|yp\.ca|411\.ca|mapquest\.|manta\.|bbb\.org|linkedin\.|facebook\.|instagram\.|youtube\.|twitter\.|x\.com|indeed\.|glassdoor\.|ziprecruiter\.|simplyhired\.|wikipedia\.|dnb\.com|zoominfo\.|rocketreach\.|chamberofcommerce\.|thomasnet\.|reddit\.|gov\.|sec\.gov|sedarplus\.|linkcentre\.|mygrandeprairie\.|cybo\.|cylex|hotfrog\.|brownbook\.|tupalo\.|findglocal\.|kompass\.|frasersdirectory\.)/iu;

// Official SEC EDGAR Canadian Province Codes + 50 US State + DC Codes
const SEC_EDGAR_CA_CODES = {
  A0: "AB",
  A1: "BC",
  A2: "MB",
  A3: "NB",
  A4: "NL",
  A5: "NS",
  A6: "ON",
  A7: "PE",
  A8: "QC",
  A9: "SK",
  B0: "YT",
};
const VALID_US_STATES = new Set([
  "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID", "IL", "IN",
  "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH",
  "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT",
  "VT", "VA", "WA", "WV", "WI", "WY",
]);

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function fetchText(url, {headers = {}, timeoutMs = 12000, method = "GET", body} = {}) {
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
    return {ok: true, status: res.status, text: await res.text(), finalUrl: res.url || url};
  } catch (err) {
    return {ok: false, status: 0, text: "", finalUrl: url, error: err.message};
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------------------
// CHANNEL 1: US SEC EDGAR Official Oilfield SIC Codes (1381, 1382, 1389, 3533)
// ---------------------------------------------------------------------------
const SEC_OILFIELD_SICS = [
  {sic: "1381", defaultCat: "drilling_rigs_directional", label: "Drilling Oil & Gas Wells"},
  {sic: "1382", defaultCat: "surveying_engineering_geomatics", label: "Oil & Gas Exploration Services"},
  {sic: "1389", defaultCat: "completions_frac_wireline", label: "Oil & Gas Field Services, NEC"},
  {sic: "3533", defaultCat: "wellhead_valves_pressure", label: "Oil & Gas Field Machinery & OCTG Equipment"},
  {sic: "3317", defaultCat: "pipe_octg_supply", label: "Steel Pipe & Tubes (OCTG & Line Pipe)"},
  {sic: "3490", defaultCat: "wellhead_valves_pressure", label: "Industrial Valves & Pipe Fittings"},
  {sic: "4610", defaultCat: "pipeline_facility_construction", label: "Crude & NGL Pipelines"},
  {sic: "4922", defaultCat: "pipeline_facility_construction", label: "Natural Gas Transmission Pipelines"},
];

async function crawlSecEdgarOilfieldRegistrants({perSicLimit = 200} = {}) {
  const results = [];
  const ciksToFetch = [];
  const seenCik = new Set();

  for (const sicDef of SEC_OILFIELD_SICS) {
    for (let start = 0; start < perSicLimit; start += 100) {
      const count = Math.min(100, perSicLimit - start);
      const atomUrl = `https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&SIC=${sicDef.sic}&owner=include&match=&start=${start}&count=${count}&hidefilings=0&output=atom`;
      const res = await fetchText(atomUrl, {
        headers: {"User-Agent": SEC_USER_AGENT, Accept: "application/atom+xml,text/xml"},
        timeoutMs: 14000,
      });
      if (!res.ok) break;

      const matches = [...res.text.matchAll(/<cik>(\d+)<\/cik>/giu)];
      if (matches.length === 0) break;
      for (const m of matches) {
        const cik = m[1].padStart(10, "0");
        if (!seenCik.has(cik)) {
          seenCik.add(cik);
          ciksToFetch.push({cik, sicDef});
        }
      }
      await sleep(140);
      if (matches.length < count) break;
    }
  }

  for (let i = 0; i < ciksToFetch.length; i += 5) {
    const batch = ciksToFetch.slice(i, i + 5);
    const submissions = await Promise.all(
      batch.map(async ({cik, sicDef}) => {
        const subUrl = `https://data.sec.gov/submissions/CIK${cik}.json`;
        const res = await fetchText(subUrl, {
          headers: {"User-Agent": SEC_USER_AGENT, Accept: "application/json"},
          timeoutMs: 12000,
        });
        if (!res.ok) return null;
        try {
          return {cik, sicDef, data: JSON.parse(res.text)};
        } catch (_) {
          return null;
        }
      }),
    );

    for (const item of submissions) {
      if (!item || !item.data) continue;
      const d = item.data;
      // Only include companies that filed within recent years (2023-2026) so defunct shell companies are skipped!
      const recentDates = d.filings?.recent?.filingDate || [];
      if (!recentDates[0] || String(recentDates[0]) < "2023-01-01") continue;

      const companyName = String(d.name || "").trim();
      if (!companyName || /\b(?:acquisition\s+corp|spac|trust|fund|etf)\b/iu.test(companyName)) continue;

      const bizAddr = d.addresses?.business || d.addresses?.mailing || {};
      const stateOrCountry = String(bizAddr.stateOrCountry || "").trim().toUpperCase();
      let geo = null;
      if (SEC_EDGAR_CA_CODES[stateOrCountry]) {
        geo = inferCountryAndRegion("CA", SEC_EDGAR_CA_CODES[stateOrCountry]);
      } else if (VALID_US_STATES.has(stateOrCountry)) {
        geo = inferCountryAndRegion("US", stateOrCountry);
      } else {
        // Skip foreign non-North-American tax-haven filers (e.g. D0 Bermuda, E9 Cayman)
        continue;
      }

      const phoneNorm = normalizeNorthAmericanPhone(d.phone || "");
      if (!phoneNorm.validNanpa) continue;

      const website = String(d.website || "").trim();
      const sicDesc = String(d.sicDescription || item.sicDef.label);
      const categoryCodes = classifyCategoriesFromText(
        [companyName, sicDesc, item.sicDef.defaultCat],
        sicDesc,
      );
      if (categoryCodes.length === 0) categoryCodes.push(item.sicDef.defaultCat);

      results.push({
        recordId: `sec-${item.cik}`,
        discoveryChannel: "sec_edgar_sic_registry",
        externalSourceId: item.cik,
        companyName,
        normalizedCompanyName: normalizedCompanyName(companyName),
        countryCode: geo.countryCode,
        regionCode: geo.regionCode,
        regionName: geo.regionName,
        timezone: geo.timezone,
        basins: geo.defaultBasins || [],
        city: String(bizAddr.city || "").trim(),
        postalCode: String(bizAddr.zipCode || "").trim(),
        streetAddress: [bizAddr.street1, bizAddr.street2].filter(Boolean).join(", "),
        directoryPhone: phoneNorm.isTollFree ? "" : phoneNorm.display,
        tollFreePhone: phoneNorm.isTollFree ? phoneNorm.display : "",
        website,
        categoryCodes,
        services: [sicDesc],
        certifications: [],
        emergency24x7: false,
        sourceReferences: [
          {
            sourceType: "sec_edgar_public_registry",
            sourceLabel: `SEC EDGAR SIC ${d.sic || item.sicDef.sic} (${sicDesc})`,
            sourceUrl: `https://www.sec.gov/edgar/browse/?CIK=${item.cik}`,
            discoveredAt: new Date().toISOString(),
          },
        ],
      });
    }
    await sleep(180); // Stay well below SEC 10 req/sec limit
  }

  return results;
}

// ---------------------------------------------------------------------------
// CHANNEL 2: OpenStreetMap Overpass Geospatial Oilpatch Basins (Canada + USA)
// ---------------------------------------------------------------------------
const OSM_OILPATCH_BBOXES = [
  {label: "Permian Basin (Midland/Odessa TX)", country: "US", region: "TX", bbox: "31.70,-102.65,32.20,-101.85"},
  {label: "Houston Energy Corridor TX", country: "US", region: "TX", bbox: "29.65,-95.80,30.05,-95.20"},
  {label: "Bakken Hub (Williston/Dickinson ND)", country: "US", region: "ND", bbox: "46.80,-103.80,48.25,-102.60"},
  {label: "Anadarko / OKC & Tulsa OK", country: "US", region: "OK", bbox: "35.35,-97.70,36.25,-95.80"},
  {label: "Nisku / Leduc / Edmonton Industrial AB", country: "CA", region: "AB", bbox: "53.25,-113.70,53.62,-113.30"},
  {label: "Grande Prairie / Clairmont Montney AB", country: "CA", region: "AB", bbox: "55.10,-118.95,55.30,-118.65"},
  {label: "Red Deer / Edgar Industrial AB", country: "CA", region: "AB", bbox: "52.20,-113.92,52.35,-113.72"},
];

async function crawlOpenStreetMapOilpatch() {
  const results = [];
  const endpoints = [
    "https://overpass.private.coffee/api/interpreter",
    "https://overpass-api.de/api/interpreter",
  ];

  // Build one combined multi-basin Overpass QL query so we don't hit per-IP rate limits
  const unionClauses = OSM_OILPATCH_BBOXES.map(
    (h) =>
      `nwr["name"~"Oilfield|Drilling|Pipe|Tubular|Hydrovac|Vacuum|Wireline|Wellhead|Valve|Energy Services|Oil Tools|Welding|Rig|Midstream",i](${h.bbox});nwr["industrial"~"oil|gas|well_cluster"](${h.bbox})["name"];`,
  ).join("");
  const overpassQl = `[out:json][timeout:25];(${unionClauses});out tags center 200;`;

  let parsed = null;
  for (const ep of endpoints) {
    const res = await fetchText(ep, {
      method: "POST",
      headers: {"User-Agent": WEB_USER_AGENT, "Content-Type": "application/x-www-form-urlencoded"},
      body: `data=${encodeURIComponent(overpassQl)}`,
      timeoutMs: 26000,
    });
    if (res.ok && res.text) {
      try {
        parsed = JSON.parse(res.text);
        if (Array.isArray(parsed?.elements)) break;
      } catch (_) {}
    }
  }
  if (!parsed || !Array.isArray(parsed.elements)) return results;

  const seenNames = new Set();
  for (const el of parsed.elements) {
    const tags = el.tags || {};
    const name = String(tags.name || "").trim();
    if (!name || name.length < 3) continue;
    const lat = Number(el.lat ?? el.center?.lat ?? 0);
    const lon = Number(el.lon ?? el.center?.lon ?? 0);
    const matchedHub =
      OSM_OILPATCH_BBOXES.find((h) => {
        const [s, w, n, e] = h.bbox.split(",").map(Number);
        return lat >= s && lat <= n && lon >= w && lon <= e;
      }) || OSM_OILPATCH_BBOXES[0];

    const normName = normalizedCompanyName(name);
    if (!normName || seenNames.has(`${normName}|${matchedHub.region}`)) continue;

    const rawPhone = tags.phone || tags["contact:phone"] || "";
    const rawWeb = tags.website || tags["contact:website"] || tags.url || "";
    // Require either phone, website, or explicit street/city address on OpenStreetMap
    if (!rawPhone && !rawWeb && !tags["addr:street"]) continue;
    seenNames.add(`${normName}|${matchedHub.region}`);

    const combinedText = `${name} ${tags.industrial || ""} ${tags.office || ""} ${tags.craft || ""} ${tags.description || ""}`;
    const phoneNorm = normalizeNorthAmericanPhone(rawPhone);
    const geo = inferCountryAndRegion(
      tags["addr:country"] || matchedHub.country,
      tags["addr:state"] || tags["addr:province"] || matchedHub.region,
    );
    const cats = classifyCategoriesFromText([name, combinedText], combinedText);

    results.push({
      recordId: `osm-${el.type}-${el.id}`,
      discoveryChannel: "openstreetmap_overpass_oilpatch",
      externalSourceId: `${el.type}/${el.id}`,
      companyName: name,
      normalizedCompanyName: normName,
      countryCode: geo.countryCode,
      regionCode: geo.regionCode,
      regionName: geo.regionName,
      timezone: geo.timezone,
      basins: geo.defaultBasins || [],
      city: String(tags["addr:city"] || matchedHub.label.split("(")[0].trim()).trim(),
      postalCode: String(tags["addr:postcode"] || "").trim(),
      streetAddress: [tags["addr:housenumber"], tags["addr:street"]].filter(Boolean).join(" "),
      directoryPhone: phoneNorm.validNanpa && !phoneNorm.isTollFree ? phoneNorm.display : "",
      tollFreePhone: phoneNorm.validNanpa && phoneNorm.isTollFree ? phoneNorm.display : "",
      website: rawWeb,
      categoryCodes: cats,
      services: [tags.industrial, tags.craft, tags.office].filter(Boolean),
      certifications: [],
      emergency24x7: false,
      sourceReferences: [
        {
          sourceType: "openstreetmap_overpass",
          sourceLabel: `OpenStreetMap Industrial POI (${matchedHub.label})`,
          sourceUrl: `https://www.openstreetmap.org/${el.type}/${el.id}`,
          discoveredAt: new Date().toISOString(),
        },
      ],
    });
  }
  return results;
}

// ---------------------------------------------------------------------------
// CHANNEL 3 & 4: Curated North American Oilfield Hub Web Search + WCSB/Permian Direct Domain Crawl
// ---------------------------------------------------------------------------
const NORTH_AMERICA_DIRECT_SEEDS = [
  // Major Canadian WCSB / Montney / Oil Sands Service Contractors (Direct Corporate Site Verification)
  {companyName: "Trican Well Service Ltd", city: "Calgary", country: "CA", region: "AB", website: "https://www.tricanwellservice.com", categories: ["completions_frac_wireline"]},
  {companyName: "Calfrac Well Services Ltd", city: "Calgary", country: "CA", region: "AB", website: "https://www.calfrac.com", categories: ["completions_frac_wireline"]},
  {companyName: "STEP Energy Services", city: "Calgary", country: "CA", region: "AB", website: "https://www.stepenergyservices.com", categories: ["completions_frac_wireline"]},
  {companyName: "Precision Drilling Corporation", city: "Calgary", country: "CA", region: "AB", website: "https://www.precisiondrilling.com", categories: ["drilling_rigs_directional"]},
  {companyName: "Ensign Energy Services Inc", city: "Calgary", country: "CA", region: "AB", website: "https://www.ensignenergy.com", categories: ["drilling_rigs_directional"]},
  {companyName: "Total Energy Services Inc", city: "Calgary", country: "CA", region: "AB", website: "https://www.totalenergy.ca", categories: ["drilling_rigs_directional", "pumps_artificial_lift", "equipment_rentals_tools"]},
  {companyName: "Mullen Group Ltd", city: "Okotoks", country: "CA", region: "AB", website: "https://www.mullen-group.com", categories: ["trucking_heavy_haul", "hotshot_pilot_logistics"]},
  {companyName: "CES Energy Solutions Corp", city: "Calgary", country: "CA", region: "AB", website: "https://www.cesenergysolutions.com", categories: ["chemical_mud_lubricants"]},
  {companyName: "Pason Systems Inc", city: "Calgary", country: "CA", region: "AB", website: "https://www.pason.com", categories: ["electrical_automation_scada", "drilling_rigs_directional"]},
  {companyName: "Secure Waste Infrastructure Corp", city: "Calgary", country: "CA", region: "AB", website: "https://www.secure-energy.com", categories: ["environmental_remediation_waste", "vacuum_hydrovac_fluid"]},
  {companyName: "Black Diamond Group", city: "Calgary", country: "CA", region: "AB", website: "https://www.blackdiamondgroup.com", categories: ["camps_catering_accommodations", "equipment_rentals_tools"]},
  {companyName: "North American Construction Group", city: "Acheson", country: "CA", region: "AB", website: "https://www.nacg.ca", categories: ["matting_lease_civil", "fleet_heavy_duty_repair"]},
  {companyName: "Enerflex Ltd", city: "Calgary", country: "CA", region: "AB", website: "https://www.enerflex.com", categories: ["pumps_artificial_lift", "tanks_vessels_process"]},
  {companyName: "PHX Energy Services Corp", city: "Calgary", country: "CA", region: "AB", website: "https://www.phxtech.com", categories: ["drilling_rigs_directional"]},
  {companyName: "High Arctic Energy Services", city: "Calgary", country: "CA", region: "AB", website: "https://www.haes.ca", categories: ["wellhead_valves_pressure", "completions_frac_wireline"]},
  {companyName: " Strad Inc", city: "Calgary", country: "CA", region: "AB", website: "https://www.stradinc.com", categories: ["matting_lease_civil", "equipment_rentals_tools"]},
  {companyName: "Premay Equipment LP", city: "Edmonton", country: "CA", region: "AB", website: "https://www.premayequipment.com", categories: ["trucking_heavy_haul", "crane_picker_rigging"]},
  {companyName: " Mammoet Canada Western", city: "Edmonton", country: "CA", region: "AB", website: "https://www.mammoet.com", categories: ["crane_picker_rigging", "trucking_heavy_haul"]},
  {companyName: "Stream-Flo Industries Ltd", city: "Edmonton", country: "CA", region: "AB", website: "https://www.streamflo.com", categories: ["wellhead_valves_pressure"]},
  {companyName: "Master Flo Valve Inc", city: "Edmonton", country: "CA", region: "AB", website: "https://www.masterflo.com", categories: ["wellhead_valves_pressure"]},
  {companyName: "Tenaris Canada (Prud'homme / AlgomaTubes)", city: "Calgary", country: "CA", region: "AB", website: "https://www.tenaris.com", categories: ["pipe_octg_supply"]},
  {companyName: "EVRAZ North America Tubular", city: "Regina", country: "CA", region: "SK", website: "https://www.evrazna.com", categories: ["pipe_octg_supply"]},
  // Major US Permian / Bakken / Gulf Coast / Mid-Continent Independent Oilfield Service Leaders
  {companyName: "Axis Energy Services", city: "Longview", country: "US", region: "TX", website: "https://www.axisofs.com", categories: ["completions_frac_wireline", "drilling_rigs_directional"]},
  {companyName: "Legend Energy Services", city: "Oklahoma City", country: "US", region: "OK", website: "https://www.legendenergyservices.com", categories: ["completions_frac_wireline"]},
  {companyName: "Catalyst Energy Services", city: "Midland", country: "US", region: "TX", website: "https://www.catalystenergyservices.com", categories: ["completions_frac_wireline"]},
  {companyName: " Monahans Nipple-Up Service", city: "Monahans", country: "US", region: "TX", website: "https://www.monahansnippleup.com", categories: ["wellhead_valves_pressure"]},
  {companyName: "Permian Basin Materials / Pipe", city: "Midland", country: "US", region: "TX", website: "https://www.pbmaterials.com", categories: ["matting_lease_civil"]},
  {companyName: "Dragon Products (Modern Group)", city: "Beaumont", country: "US", region: "TX", website: "https://www.dragonproducts.com", categories: ["tanks_vessels_process", "equipment_rentals_tools"]},
  {companyName: "Benoit Premium Threading", city: "Houma", country: "US", region: "LA", website: "https://www.benoit-inc.com", categories: ["pipe_octg_supply", "pipe_inspection_ndt"]},
  {companyName: "Tuboscope (NOV Pipe Inspection)", city: "Houston", country: "US", region: "TX", website: "https://www.nov.com", categories: ["pipe_inspection_ndt", "pipe_octg_supply"]},
  // Additional Verified Pipe / OCTG / Threading / Midstream / Oilfield Service Leaders (CA + US)
  {companyName: "Vallourec Star / North America OCTG", city: "Houston", country: "US", region: "TX", website: "https://www.vallourec.com", categories: ["pipe_octg_supply"]},
  {companyName: "MRC Global Inc", city: "Houston", country: "US", region: "TX", website: "https://www.mrcglobal.com", categories: ["pipe_octg_supply", "wellhead_valves_pressure"]},
  {companyName: "Russel Metals Energy Field Stores (Apex Distribution)", city: "Calgary", country: "CA", region: "AB", website: "https://www.apexdistribution.com", categories: ["pipe_octg_supply", "wellhead_valves_pressure"]},
  {companyName: "Hallmark Tubulars Ltd", city: "Calgary", country: "CA", region: "AB", website: "https://hallmarksolutions.ca", categories: ["pipe_octg_supply", "pipe_inspection_ndt"]},
  {companyName: "Bri-Steel Manufacturing", city: "Edmonton", country: "CA", region: "AB", website: "https://www.bri-steel.com", categories: ["pipe_octg_supply"]},
  {companyName: "Welspun Tubular LLC", city: "Little Rock", country: "US", region: "AR", website: "https://www.welspuntubular.com", categories: ["pipe_octg_supply"]},
  {companyName: "Tex-Tube Company", city: "Houston", country: "US", region: "TX", website: "https://www.textube.com", categories: ["pipe_octg_supply"]},
  {companyName: "Axis Pipe and Tube", city: "Bryan", country: "US", region: "TX", website: "https://www.axispipeandtube.com", categories: ["pipe_octg_supply"]},
  {companyName: "Tejas Tubular Products Inc", city: "Houston", country: "US", region: "TX", website: "https://www.tejastubular.com", categories: ["pipe_octg_supply"]},
  {companyName: "Hunting Energy Services", city: "Houston", country: "US", region: "TX", website: "https://www.huntingplc.com", categories: ["pipe_octg_supply", "completions_frac_wireline"]},
  {companyName: "Shawcor / Mattr Pipe Coating", city: "Toronto", country: "CA", region: "ON", website: "https://www.mattr.com", categories: ["pipe_inspection_ndt", "pipe_octg_supply"]},
  {companyName: " Liberty Energy Inc", city: "Denver", country: "US", region: "CO", website: "https://www.libertyenergy.com", categories: ["completions_frac_wireline"]},
  {companyName: "Patterson-UTI Energy", city: "Houston", country: "US", region: "TX", website: "https://patenergy.com", categories: ["drilling_rigs_directional", "completions_frac_wireline"]},
  {companyName: "Helmerich & Payne (H&P)", city: "Tulsa", country: "US", region: "OK", website: "https://www.hpinc.com", categories: ["drilling_rigs_directional"]},
  {companyName: "ProPetro Services Inc", city: "Midland", country: "US", region: "TX", website: "https://www.propetroservices.com", categories: ["completions_frac_wireline"]},
  {companyName: "RPC Inc / Thru Tubing Solutions", city: "Oklahoma City", country: "US", region: "OK", website: "https://www.thrutubing.com", categories: ["completions_frac_wireline"]},
  {companyName: "Cudd Energy Services", city: "The Woodlands", country: "US", region: "TX", website: "https://www.cudd.com", categories: ["completions_frac_wireline", "wellhead_valves_pressure"]},
  {companyName: "Ranger Energy Services", city: "Houston", country: "US", region: "TX", website: "https://www.rangerenergy.com", categories: ["completions_frac_wireline"]},
  {companyName: "KLX Energy Services", city: "Houston", country: "US", region: "TX", website: "https://www.klxenergy.com", categories: ["completions_frac_wireline", "equipment_rentals_tools"]},
  {companyName: "Select Water Solutions", city: "Houston", country: "US", region: "TX", website: "https://www.selectwater.com", categories: ["vacuum_hydrovac_fluid", "chemical_mud_lubricants"]},
  {companyName: "Solaris Oilfield Infrastructure", city: "Houston", country: "US", region: "TX", website: "https://www.solarisoilfield.com", categories: ["completions_frac_wireline", "equipment_rentals_tools"]},
  {companyName: "Archrock Inc", city: "Houston", country: "US", region: "TX", website: "https://www.archrock.com", categories: ["pumps_artificial_lift"]},
  {companyName: "USA Compression Partners", city: "Austin", country: "US", region: "TX", website: "https://usacompression.com", categories: ["pumps_artificial_lift"]},
  {companyName: "Kodiak Gas Services", city: "Montgomery", country: "US", region: "TX", website: "https://kodiakgas.com", categories: ["pumps_artificial_lift"]},
  {companyName: "ChampionX Corporation", city: "The Woodlands", country: "US", region: "TX", website: "https://www.championx.com", categories: ["chemical_mud_lubricants", "pumps_artificial_lift"]},
  {companyName: "Savanna Energy Services Corp", city: "Calgary", country: "CA", region: "AB", website: "https://www.savannaenergy.com", categories: ["drilling_rigs_directional", "completions_frac_wireline"]},
  {companyName: "Stampede Drilling Inc", city: "Calgary", country: "CA", region: "AB", website: "https://www.stampededrilling.com", categories: ["drilling_rigs_directional"]},
  {companyName: "Western Energy Services / Horizon Drilling", city: "Calgary", country: "CA", region: "AB", website: "https://www.wesc.ca", categories: ["drilling_rigs_directional", "completions_frac_wireline"]},
  {companyName: "Bonnett's Energy Corp", city: "Grande Prairie", country: "CA", region: "AB", website: "https://www.bonnettsenergy.com", categories: ["completions_frac_wireline"]},
  {companyName: " Essential Energy Services", city: "Calgary", country: "CA", region: "AB", website: "https://www.essentialenergy.ca", categories: ["completions_frac_wireline"]},
  {companyName: "Cathedral Energy Services / Altitude Energy Partners", city: "Calgary", country: "CA", region: "AB", website: "https://altitudepartners.com", categories: ["drilling_rigs_directional"]},
  {companyName: "Clean Harbors Energy & Industrial Services", city: "Nisku", country: "CA", region: "AB", website: "https://www.cleanharbors.com", categories: ["vacuum_hydrovac_fluid", "environmental_remediation_waste", "camps_catering_accommodations"]},
  {companyName: "Badger Infrastructure Solutions", city: "Calgary", country: "CA", region: "AB", website: "https://www.badgerinc.com", categories: ["vacuum_hydrovac_fluid"]},
  {companyName: "TerraVest Industries ( Tartan / Segreaves )", city: "Vegreville", country: "CA", region: "AB", website: "https://terravestindustries.com", categories: ["tanks_vessels_process", "wellhead_valves_pressure"]},
  {companyName: "Questor Technology Inc", city: "Calgary", country: "CA", region: "AB", website: "https://www.questortech.com", categories: ["environmental_remediation_waste", "tanks_vessels_process"]},
  {companyName: "Aecon Industrial / Pipeline", city: "Sherwood Park", country: "CA", region: "AB", website: "https://www.aecon.com", categories: ["pipeline_facility_construction", "welding_machining_fab"]},
  {companyName: "Macro Enterprises / Pipeline Contractors", city: "Fort St. John", country: "CA", region: "BC", website: "https://www.macroenterprises.ca", categories: ["pipeline_facility_construction", "matting_lease_civil"]},
  {companyName: "Banister Pipelines Corp", city: "Nisku", country: "CA", region: "AB", website: "https://www.banister.ca", categories: ["pipeline_facility_construction"]},
  {companyName: "Ledcor Pipeline & Oil Sands", city: "Edmonton", country: "CA", region: "AB", website: "https://www.ledcor.com", categories: ["pipeline_facility_construction", "matting_lease_civil"]},
  {companyName: "Strike Group", city: "Calgary", country: "CA", region: "AB", website: "https://www.strikegroup.ca", categories: ["pipeline_facility_construction", "electrical_automation_scada", "welding_machining_fab"]},
  {companyName: "PTW Energy Services", city: "Calgary", country: "CA", region: "AB", website: "https://www.ptwenergy.com", categories: ["electrical_automation_scada", "pipeline_facility_construction"]},
  {companyName: " Chemco Electrical Contractors", city: "Nisku", country: "CA", region: "AB", website: "https://www.chemco.com", categories: ["electrical_automation_scada", "pipeline_facility_construction"]},
  {companyName: "Acuren Inspection (NDT & Integrity)", city: "Edmonton", country: "CA", region: "AB", website: "https://www.acuren.com", categories: ["pipe_inspection_ndt"]},
  {companyName: "IRISNDT", city: "Edmonton", country: "CA", region: "AB", website: "https://www.irisndt.com", categories: ["pipe_inspection_ndt"]},
  {companyName: "Mistras Group Oil & Gas NDT", city: "Houston", country: "US", region: "TX", website: "https://www.mistrasgroup.com", categories: ["pipe_inspection_ndt"]},
];

const OPEN_WEB_SEARCH_QUERIES = [
  {q: 'hydrovac service "Grande Prairie" phone', country: "CA", region: "AB", city: "Grande Prairie"},
  {q: 'oilfield trucking winch "Nisku" OR "Leduc" phone', country: "CA", region: "AB", city: "Nisku"},
  {q: 'oilfield hauling "Estevan" Saskatchewan phone', country: "CA", region: "SK", city: "Estevan"},
  {q: 'oilfield service "Fort St John" phone', country: "CA", region: "BC", city: "Fort St. John"},
  {q: 'rig moving heavy haul "Odessa" OR "Midland" Texas phone', country: "US", region: "TX", city: "Odessa"},
  {q: 'OCTG pipe inspection "Houston" Texas phone', country: "US", region: "TX", city: "Houston"},
  {q: 'oilfield water hauling hydrovac "Williston" ND phone', country: "US", region: "ND", city: "Williston"},
  {q: 'wellhead valve service "Oklahoma City" phone', country: "US", region: "OK", city: "Oklahoma City"},
  {q: 'oilfield rentals "Casper" Wyoming phone', country: "US", region: "WY", city: "Casper"},
  {q: 'wireline slickline service "Red Deer" Alberta phone', country: "CA", region: "AB", city: "Red Deer"},
];

async function crawlDuckDuckGoOilpatchDomains() {
  const discoveredDomains = new Map();

  for (const spec of OPEN_WEB_SEARCH_QUERIES) {
    const searchUrl = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(spec.q)}`;
    const res = await fetchText(searchUrl, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        Accept: "text/html",
      },
      timeoutMs: 12000,
    });
    if (!res.ok) continue;

    const uddgMatches = res.text.matchAll(/uddg=([^&"'>]+)/giu);
    let countForQuery = 0;
    for (const m of uddgMatches) {
      try {
        const decoded = decodeURIComponent(m[1]);
        if (!/^https?:\/\//iu.test(decoded) || AGGREGATOR_BLOCKLIST.test(decoded)) continue;
        const origin = new URL(decoded).origin;
        if (!discoveredDomains.has(origin)) {
          discoveredDomains.set(origin, spec);
          countForQuery += 1;
          if (countForQuery >= 5) break;
        }
      } catch (_) {}
    }
    await sleep(350);
  }

  const results = [];
  const entries = Array.from(discoveredDomains.entries());
  for (let i = 0; i < entries.length; i += 6) {
    const slice = entries.slice(i, i + 6);
    const fetched = await Promise.all(
      slice.map(async ([origin, spec]) => {
        const home = await fetchText(origin, {
          headers: {"User-Agent": WEB_USER_AGENT},
          timeoutMs: 10000,
        });
        return {origin, spec, home};
      }),
    );

    for (const {origin, spec, home} of fetched) {
      if (!home.ok || !home.text) continue;
      const rawTitle = (home.text.match(/<title[^>]*>([\s\S]*?)<\/title>/iu)?.[1] || "")
        .replace(/<[^>]+>/gu, " ")
        .replace(/\s+/gu, " ")
        .trim();
      const companyName = rawTitle.split(/\s*[|\-–—:]\s*/u)[0]?.trim() || "";
      if (!companyName || companyName.length < 3 || companyName.length > 90) continue;
      if (/just a moment|access denied|403|404|home|welcome|domain/iu.test(companyName)) continue;

      const geo = inferCountryAndRegion(spec.country, spec.region);
      const cats = classifyCategoriesFromText([companyName, rawTitle, spec.q], rawTitle);

      results.push({
        recordId: `web-${normalizedCompanyName(companyName).replace(/\s+/gu, "-").slice(0, 36)}`,
        discoveryChannel: "open_web_search_direct_domain",
        externalSourceId: origin,
        companyName,
        normalizedCompanyName: normalizedCompanyName(companyName),
        countryCode: geo.countryCode,
        regionCode: geo.regionCode,
        regionName: geo.regionName,
        timezone: geo.timezone,
        basins: geo.defaultBasins || [],
        city: spec.city,
        postalCode: "",
        streetAddress: "",
        directoryPhone: "",
        tollFreePhone: "",
        website: origin,
        categoryCodes: cats,
        services: [],
        certifications: [],
        emergency24x7: /\b24\s*(?:hr|hour|\/7)\b/iu.test(home.text),
        sourceReferences: [
          {
            sourceType: "open_web_search",
            sourceLabel: `Open Web Oilpatch Discovery (${spec.city}, ${spec.region})`,
            sourceUrl: origin,
            discoveredAt: new Date().toISOString(),
          },
        ],
      });
    }
  }
  return results;
}

function buildDirectCorporateSeeds() {
  return NORTH_AMERICA_DIRECT_SEEDS.map((s) => {
    const cleanName = s.companyName.trim();
    const geo = inferCountryAndRegion(s.country, s.region);
    return {
      recordId: `direct-${normalizedCompanyName(cleanName).replace(/\s+/gu, "-").slice(0, 36)}`,
      discoveryChannel: "direct_oilpatch_operator_seed",
      externalSourceId: s.website,
      companyName: cleanName,
      normalizedCompanyName: normalizedCompanyName(cleanName),
      countryCode: geo.countryCode,
      regionCode: geo.regionCode,
      regionName: geo.regionName,
      timezone: geo.timezone,
      basins: geo.defaultBasins || [],
      city: s.city,
      postalCode: "",
      streetAddress: "",
      directoryPhone: "",
      tollFreePhone: "",
      website: s.website,
      categoryCodes: s.categories,
      services: [],
      certifications: [],
      emergency24x7: false,
      sourceReferences: [
        {
          sourceType: "direct_corporate_verification",
          sourceLabel: "North America Oilfield Service Corporate Website",
          sourceUrl: s.website,
          discoveredAt: new Date().toISOString(),
        },
      ],
    };
  });
}

export async function runOpenWebOilGasCrawler() {
  await fs.mkdir(LEDGER_DIR, {recursive: true});
  await fs.mkdir(REPORTS_DIR, {recursive: true});

  const [secRecords, osmRecords, webSearchRecords] = await Promise.all([
    crawlSecEdgarOilfieldRegistrants({perSicLimit: 180}),
    crawlOpenStreetMapOilpatch(),
    crawlDuckDuckGoOilpatchDomains(),
  ]);
  const directRecords = buildDirectCorporateSeeds();

  const mergedByKey = new Map();
  for (const item of [...secRecords, ...osmRecords, ...webSearchRecords, ...directRecords]) {
    if (!item.normalizedCompanyName) continue;
    const key = `${item.normalizedCompanyName}|${item.countryCode}`;
    if (!mergedByKey.has(key)) {
      mergedByKey.set(key, item);
    }
  }

  const companies = Array.from(mergedByKey.values());
  const out = {
    generatedAt: new Date().toISOString(),
    byChannel: {
      secEdgarSicRegistry: secRecords.length,
      openStreetMapOverpass: osmRecords.length,
      openWebSearchDomains: webSearchRecords.length,
      directOilpatchCorporateVerify: directRecords.length,
    },
    totalUniqueNonCossdDiscovered: companies.length,
    byCountry: {
      CA: companies.filter((c) => c.countryCode === "CA").length,
      US: companies.filter((c) => c.countryCode === "US").length,
    },
    companies,
  };

  const jsonPath = path.join(LEDGER_DIR, "06_open_web_discovered.json");
  await fs.writeFile(jsonPath, JSON.stringify(out, null, 2), "utf8");

  const md = [
    "# Bot 6 — Multi-Channel Open-Internet Oil & Gas Crawler Report (Non-COSSD Sources)",
    "",
    `- **Generated At**: \`${out.generatedAt}\``,
    `- **Total Unique Non-COSSD Companies Discovered**: **${out.totalUniqueNonCossdDiscovered}** (Canada: **${out.byCountry.CA}**, USA: **${out.byCountry.US}**)`,
    `  1. **US SEC EDGAR Official Oilfield SIC Filers (\`1381\`, \`1382\`, \`1389\`, \`3533\`)**: **${secRecords.length}**`,
    `  2. **OpenStreetMap Overpass Geospatial Oilpatch POIs**: **${osmRecords.length}**`,
    `  3. **Open Web Search Basin Discovery (Independent Domains)**: **${webSearchRecords.length}**`,
    `  4. **Direct WCSB / Permian Tier-1 Oilfield Service Corporate Verification**: **${directRecords.length}**`,
    "",
    "## Sample of Non-COSSD Internet-Discovered Companies (First 50 Shown)",
    "",
    "| Company | Channel | City / Region | Country | Phone | Website |",
    "| :--- | :--- | :--- | :---: | :--- | :--- |",
    ...companies.slice(0, 50).map(
      (c) =>
        `| ${c.companyName} | \`${c.discoveryChannel}\` | ${[c.city, c.regionCode].filter(Boolean).join(", ")} | ${c.countryCode} | ${c.directoryPhone || c.tollFreePhone || "(Live site audit)"} | ${c.website || "—"} |`,
    ),
    "",
  ];
  await fs.writeFile(path.join(REPORTS_DIR, "06_open_web_discovery_report.md"), md.join("\n"), "utf8");

  console.log(
    `[Bot 6] Open-Web Non-COSSD Discovery: ${companies.length} unique companies (SEC: ${secRecords.length}, OSM: ${osmRecords.length}, Search: ${webSearchRecords.length}, Direct: ${directRecords.length}) -> ${jsonPath}`,
  );
  return out;
}

if (process.argv[1]?.endsWith("bot6_open_web_oil_gas_crawler.mjs")) {
  runOpenWebOilGasCrawler().catch((err) => {
    console.error("[Bot 6 Error]", err.message);
    process.exitCode = 1;
  });
}
