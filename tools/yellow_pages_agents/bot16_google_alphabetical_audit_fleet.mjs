#!/usr/bin/env node
/**
 * Bot 16 — Multi-Agent Google Maps & Web Alphabetical (A–Z) Oil & Gas + Training Audit Fleet
 *
 * Orchestrates 8 parallel Chromium Google Maps discovery & audit agents starting strictly
 * with North America:
 *   - Stage 1: CANADA (`CA` — AB, BC, SK, MB, NL, NS, ON, NB, NT) Alphabetical `A -> Z` + All 25 Sectors + Oil & Gas Training Facilities & Courses
 *   - Stage 2: USA (`US` — TX, ND, OK, LA, NM, WY, CO, PA, WV, OH, CA, AK, MT, UT, KS, AR, MS) Alphabetical `A -> Z` + All 25 Sectors + Oil & Gas Training Facilities & Courses
 *
 * Strict Schema & Hygiene Guarantees:
 *   - Rejects permanently/temporarily closed listings (and flags any existing live entry found closed on Google).
 *   - Rejects retail gas stations, auto lube shops, residential services, and non-industrial consumer schools.
 *   - Enforces NANPA area-code anti-zoom-out verification so Google Maps zoom-outs never misassign cities/states.
 *   - Passes every `companyName`, `city`, `regionCode`, `countryCode`, `publicPhone`, `website`, `basins`,
 *     and `categoryCodes` (including `oil_gas_training_courses`) through canonical taxonomy validators.
 *   - NEVER pre-verifies (`verificationStatus: "unverified"`, `listingTier: "free_basic"`, `verified: false`).
 *   - Checkpoints atomically every 15 queries and streams directly to Firestore when `--sync` is passed.
 */

import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import {createRequire} from "node:module";
import {fileURLToPath, pathToFileURL} from "node:url";
import {resolveAccessToken, toFirestoreValue} from "./global_shared_utils.mjs";

const require = createRequire(import.meta.url);
const {
  CATEGORY_BY_CODE,
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
const LEDGER_DIR = path.join(REPO_ROOT, "data/yellow_pages/ledger");
const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");

const args = process.argv.slice(2);
const SYNC = args.includes("--sync");
const RESUME = !args.includes("--fresh");
const INCLUDE_TRAINING_CODE = !args.includes("--legacy-24-cats");
const agentsIdx = args.indexOf("--agents");
const NUM_AGENTS = agentsIdx !== -1 ? Math.max(1, Math.min(12, Number(args[agentsIdx + 1] || 8))) : 8;
const maxQueriesIdx = args.indexOf("--max-queries");
const MAX_QUERIES = maxQueriesIdx !== -1 ? Number(args[maxQueriesIdx + 1] || 600) : 600;
const countryOnlyIdx = args.indexOf("--country");
const COUNTRY_FILTER = countryOnlyIdx !== -1 ? String(args[countryOnlyIdx + 1] || "").toUpperCase() : "";
const projIdx = args.indexOf("--project");
const PROJECT_ID = projIdx !== -1 && args[projIdx + 1] ? args[projIdx + 1] : "flutter-flow-pipe";

const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

const CONSUMER_NOISE_BLOCKLIST =
  /\b(?:gas station|convenience store|service station|truck stop|car wash|auto oil change|oil change service|jiffy lube|mr\.?\s*lube|great canadian oil change|valvoline instant|take 5 oil|grease monkey|midas|meineke|kal tire|fountain tire|canadian tire|walmart|costco|7-eleven|circle k|esso|petro-canada|shell station|chevron station|mobil station|exxon station|husky|co-op gas|love's travel|pilot travel|flying j|buc-ee|quiktrip|wawa|hair|beauty|barber|nail|spa|yoga|pilates|martial arts|karate|taekwondo|dance|music school|kumon|sylvan learning|mathnasium|tutoring|daycare|preschool|montessori|dog training|pet|real estate|mortgage|dental|chiropractic|optometrist|pharmacy|restaurant|pizza|cafe|coffee|bakery|hotel|motel|inn|church|fitness|gym|crossfit)\b/iu;

const POSITIVE_OILFIELD_OR_TRAINING_SIGNAL =
  /\b(?:oilfield|oil\s*&\s*gas|oil\s+and\s+gas|petroleum|energy|drilling|well\s+service|workover|wireline|slickline|coiled\s+tubing|frac|fracturing|cementing|completions|wellhead|valve|bop|pressure\s+control|octg|casing|tubing|pipe|pipeline|midstream|hydrovac|vac\s+truck|vacuum\s+truck|water\s+hauling|fluid\s+hauling|winch|heavy\s+haul|rig\s+mov|bed\s+truck|hot\s*shot|pilot\s+car|crane|picker|rigging|welding|b-pressure|fabrication|machine\s+shop|ndt|inspection|artificial\s+lift|pumpjack|compressor|compression|tank|vessel|treater|separator|boiler|rental|downhole|fishing\s+tool|rig\s+mat|access\s+mat|lease\s+construction|earthwork|scada|instrumentation|automation|oilfield\s+electrical|h2s|industrial\s+medic|safety|fire\s+watch|remediation|reclamation|environmental|disposal|mud|chemical|lubricant|bulk\s+fuel|heavy\s+duty\s+mechanic|hydraulics|remote\s+camp|wellsite\s+trailer|skid\s+shack|surveying|geomatics|line\s+locat|training|courses|academy|institute|polytechnic|college|well\s+control|iwcf|wellsharp|opito|bosiet|safeland|veriforce|rigpass|confined\s+space|fall\s+protection|ground\s+disturbance|class\s+1|cdl\s+training)\b/iu;

const AGGREGATOR_DOMAIN_BLOCKLIST =
  /(?:google\.|gstatic\.|ggpht\.|facebook\.|instagram\.|linkedin\.|youtube\.|twitter\.|x\.com|yelp\.|yellowpages\.|yp\.ca|411\.ca|bbb\.org|mapquest\.|manta\.|cossd\.com|indeed\.|glassdoor\.|dnb\.com|zoominfo\.|chamberofcommerce\.)/iu;

// Priority-ordered Canadian Hubs (Stage 1) -> US Hubs (Stage 2)
const CANADA_HUBS = [
  {city: "Grande Prairie", regionCode: "AB", countryCode: "CA", tier: 1},
  {city: "Nisku", regionCode: "AB", countryCode: "CA", tier: 1},
  {city: "Edmonton", regionCode: "AB", countryCode: "CA", tier: 1},
  {city: "Calgary", regionCode: "AB", countryCode: "CA", tier: 1},
  {city: "Red Deer", regionCode: "AB", countryCode: "CA", tier: 1},
  {city: "Fort McMurray", regionCode: "AB", countryCode: "CA", tier: 1},
  {city: "Fort St. John", regionCode: "BC", countryCode: "CA", tier: 1},
  {city: "Estevan", regionCode: "SK", countryCode: "CA", tier: 1},
  {city: "Lloydminster", regionCode: "AB", countryCode: "CA", tier: 1},
  {city: "Drayton Valley", regionCode: "AB", countryCode: "CA", tier: 1},
  {city: "Bonnyville", regionCode: "AB", countryCode: "CA", tier: 1},
  {city: "Leduc", regionCode: "AB", countryCode: "CA", tier: 1},
  {city: "Acheson", regionCode: "AB", countryCode: "CA", tier: 1},
  {city: "Whitecourt", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Brooks", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Medicine Hat", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Rocky Mountain House", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Cold Lake", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Edson", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Hinton", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Fox Creek", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Slave Lake", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Peace River", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "High Level", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Sylvan Lake", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Sherwood Park", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Fort Saskatchewan", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Stettler", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Provost", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Wainwright", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Lac La Biche", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Sundre", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Taber", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Lethbridge", regionCode: "AB", countryCode: "CA", tier: 2},
  {city: "Dawson Creek", regionCode: "BC", countryCode: "CA", tier: 1},
  {city: "Fort Nelson", regionCode: "BC", countryCode: "CA", tier: 2},
  {city: "Kitimat", regionCode: "BC", countryCode: "CA", tier: 2},
  {city: "Weyburn", regionCode: "SK", countryCode: "CA", tier: 1},
  {city: "Kindersley", regionCode: "SK", countryCode: "CA", tier: 1},
  {city: "Swift Current", regionCode: "SK", countryCode: "CA", tier: 2},
  {city: "Saskatoon", regionCode: "SK", countryCode: "CA", tier: 1},
  {city: "Regina", regionCode: "SK", countryCode: "CA", tier: 2},
  {city: "Virden", regionCode: "MB", countryCode: "CA", tier: 1},
  {city: "St. John's", regionCode: "NL", countryCode: "CA", tier: 1},
  {city: "Dartmouth", regionCode: "NS", countryCode: "CA", tier: 2},
  {city: "Sarnia", regionCode: "ON", countryCode: "CA", tier: 1},
];

const USA_HUBS = [
  {city: "Midland", regionCode: "TX", countryCode: "US", tier: 1},
  {city: "Odessa", regionCode: "TX", countryCode: "US", tier: 1},
  {city: "Houston", regionCode: "TX", countryCode: "US", tier: 1},
  {city: "Williston", regionCode: "ND", countryCode: "US", tier: 1},
  {city: "Oklahoma City", regionCode: "OK", countryCode: "US", tier: 1},
  {city: "Lafayette", regionCode: "LA", countryCode: "US", tier: 1},
  {city: "Hobbs", regionCode: "NM", countryCode: "US", tier: 1},
  {city: "Casper", regionCode: "WY", countryCode: "US", tier: 1},
  {city: "Corpus Christi", regionCode: "TX", countryCode: "US", tier: 1},
  {city: "Kilgore", regionCode: "TX", countryCode: "US", tier: 1},
  {city: "Pecos", regionCode: "TX", countryCode: "US", tier: 1},
  {city: "Greeley", regionCode: "CO", countryCode: "US", tier: 1},
  {city: "Canonsburg", regionCode: "PA", countryCode: "US", tier: 1},
  {city: "Bakersfield", regionCode: "CA", countryCode: "US", tier: 1},
  {city: "Tulsa", regionCode: "OK", countryCode: "US", tier: 1},
  {city: "Houma", regionCode: "LA", countryCode: "US", tier: 1},
  {city: "Broussard", regionCode: "LA", countryCode: "US", tier: 1},
  {city: "Shreveport", regionCode: "LA", countryCode: "US", tier: 2},
  {city: "Lake Charles", regionCode: "LA", countryCode: "US", tier: 2},
  {city: "Carlsbad", regionCode: "NM", countryCode: "US", tier: 1},
  {city: "Farmington", regionCode: "NM", countryCode: "US", tier: 2},
  {city: "Watford City", regionCode: "ND", countryCode: "US", tier: 1},
  {city: "Dickinson", regionCode: "ND", countryCode: "US", tier: 1},
  {city: "Gillette", regionCode: "WY", countryCode: "US", tier: 1},
  {city: "Rock Springs", regionCode: "WY", countryCode: "US", tier: 2},
  {city: "Elk City", regionCode: "OK", countryCode: "US", tier: 1},
  {city: "Enid", regionCode: "OK", countryCode: "US", tier: 2},
  {city: "Woodward", regionCode: "OK", countryCode: "US", tier: 2},
  {city: "Andrews", regionCode: "TX", countryCode: "US", tier: 2},
  {city: "Big Spring", regionCode: "TX", countryCode: "US", tier: 2},
  {city: "Snyder", regionCode: "TX", countryCode: "US", tier: 2},
  {city: "San Angelo", regionCode: "TX", countryCode: "US", tier: 2},
  {city: "Pleasanton", regionCode: "TX", countryCode: "US", tier: 2},
  {city: "Alice", regionCode: "TX", countryCode: "US", tier: 2},
  {city: "Victoria", regionCode: "TX", countryCode: "US", tier: 2},
  {city: "Longview", regionCode: "TX", countryCode: "US", tier: 2},
  {city: "Wichita Falls", regionCode: "TX", countryCode: "US", tier: 2},
  {city: "Beaumont", regionCode: "TX", countryCode: "US", tier: 2},
  {city: "La Porte", regionCode: "TX", countryCode: "US", tier: 2},
  {city: "Conroe", regionCode: "TX", countryCode: "US", tier: 2},
  {city: "Grand Junction", regionCode: "CO", countryCode: "US", tier: 2},
  {city: "Fort Lupton", regionCode: "CO", countryCode: "US", tier: 2},
  {city: "Denver", regionCode: "CO", countryCode: "US", tier: 2},
  {city: "Williamsport", regionCode: "PA", countryCode: "US", tier: 2},
  {city: "Pittsburgh", regionCode: "PA", countryCode: "US", tier: 2},
  {city: "Morgantown", regionCode: "WV", countryCode: "US", tier: 1},
  {city: "Bridgeport", regionCode: "WV", countryCode: "US", tier: 2},
  {city: "Canton", regionCode: "OH", countryCode: "US", tier: 1},
  {city: "Cambridge", regionCode: "OH", countryCode: "US", tier: 2},
  {city: "Anchorage", regionCode: "AK", countryCode: "US", tier: 1},
  {city: "Kenai", regionCode: "AK", countryCode: "US", tier: 2},
  {city: "Sidney", regionCode: "MT", countryCode: "US", tier: 2},
  {city: "Billings", regionCode: "MT", countryCode: "US", tier: 2},
  {city: "Vernal", regionCode: "UT", countryCode: "US", tier: 1},
  {city: "Great Bend", regionCode: "KS", countryCode: "US", tier: 2},
  {city: "Fort Smith", regionCode: "AR", countryCode: "US", tier: 2},
  {city: "El Dorado", regionCode: "AR", countryCode: "US", tier: 2},
  {city: "Laurel", regionCode: "MS", countryCode: "US", tier: 2},
];

const TRAINING_SEARCH_TEMPLATES_CA = [
  "Oilfield Safety Training",
  "H2S Alive Safety Training",
  "Well Control Training IWCF",
  "Energy Safety Training Center",
  "Confined Space Fall Protection Training",
  "Class 1 Truck & Crane Training",
  "Welding & NDT Training Institute",
];

const TRAINING_SEARCH_TEMPLATES_US = [
  "Oilfield Safety Training SafeLand",
  "Well Control School IADC WellSharp",
  "H2S & HAZWOPER Safety Training",
  "Offshore Survival Training BOSIET HUET",
  "Oilfield CDL & Crane Training School",
  "Welding & NDT Training Academy",
];

const SECTOR_SEARCH_TEMPLATES = [
  {q: "Oilfield Services", cat: "equipment_rentals_tools"},
  {q: "Hydrovac & Vacuum Truck Service", cat: "vacuum_hydrovac_fluid"},
  {q: "Oilfield Trucking & Winch Heavy Haul", cat: "trucking_heavy_haul"},
  {q: "OCTG Pipe Casing & Tubular Supply", cat: "pipe_octg_supply"},
  {q: "Wireline Coiled Tubing & Completions", cat: "completions_frac_wireline"},
  {q: "Drilling & Workover Rig Contractor", cat: "drilling_rigs_directional"},
  {q: "Wellhead Valves & Pressure Control", cat: "wellhead_valves_pressure"},
  {q: "Mobile Rig Welding & Oilfield Fabrication", cat: "welding_machining_fab"},
  {q: "Pipe Inspection NDT & Threading", cat: "pipe_inspection_ndt"},
  {q: "Crane Picker Truck & Rigging", cat: "crane_picker_rigging"},
  {q: "Pipeline Construction Contractor", cat: "pipeline_facility_construction"},
  {q: "Oilfield Electrical Instrumentation SCADA", cat: "electrical_automation_scada"},
  {q: "H2S Safety Industrial Medic & Breathing Air", cat: "safety_h2s_medics"},
  {q: "Artificial Lift Pumpjack & Gas Compression", cat: "pumps_artificial_lift"},
  {q: "Oilfield Rentals Boilers & Frac Tanks", cat: "equipment_rentals_tools"},
  {q: "Rig Mats & Oilfield Lease Construction", cat: "matting_lease_civil"},
  {q: "Oilfield Environmental & Remediation", cat: "environmental_remediation_waste"},
  {q: "Hot Shot & Pilot Car Service", cat: "hotshot_pilot_logistics"},
  {q: "Drilling Fluids & Production Chemicals", cat: "chemical_mud_lubricants"},
  {q: "Heavy Duty Truck & Hydraulic Repair", cat: "fleet_heavy_duty_repair"},
  {q: "Oilfield Land Surveying & Line Locating", cat: "surveying_engineering_geomatics"},
  {q: "Remote Workforce Camp & Wellsite Trailers", cat: "camps_catering_accommodations"},
];

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");

async function loadPlaywright() {
  const candidates = [
    process.env.PLAYWRIGHT_CORE_PATH,
    "C:\\Users\\jordi\\.gemini\\antigravity\\brain\\89d324bb-a72f-4739-a356-b6b46e26db9a\\scratch\\flag-gen\\node_modules\\playwright-core\\index.mjs",
  ].filter(Boolean);
  for (const p of candidates) {
    if (fs.existsSync(p)) {
      return import(pathToFileURL(p).href);
    }
  }
  return import("playwright-core");
}

function findBrowserExe() {
  const candidates = [
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  throw new Error("No Chrome or Edge executable found for Google Maps Playwright agents.");
}

function cleanWebsiteUrl(rawUrl) {
  if (!rawUrl) return "";
  let u = String(rawUrl).trim();
  if (u.includes("google.com/url?")) {
    try {
      const parsed = new URL(u);
      u = parsed.searchParams.get("q") || parsed.searchParams.get("url") || u;
    } catch (_) {}
  }
  try {
    const parsed = new URL(u);
    if (!/^https?:$/iu.test(parsed.protocol)) return "";
    if (AGGREGATOR_DOMAIN_BLOCKLIST.test(parsed.hostname)) return "";
    for (const k of [...parsed.searchParams.keys()]) {
      if (/^utm_|^gclid|^fbclid/iu.test(k)) parsed.searchParams.delete(k);
    }
    return parsed.toString().slice(0, 260);
  } catch (_) {
    return "";
  }
}

function extractCertifications(textBlob) {
  const certs = new Set();
  if (/\b(?:h2s\s*alive|energy\s+safety\s+canada)\b/iu.test(textBlob)) {
    certs.add("Energy Safety Canada / H2S Alive");
  }
  if (/\b(?:iwcf|wellsharp|iadc)\b/iu.test(textBlob)) {
    certs.add("IWCF / IADC WellSharp");
  }
  if (/\b(?:safeland|safegulf|veriforce|pec)\b/iu.test(textBlob)) {
    certs.add("PEC SafeLand / Veriforce");
  }
  if (/\b(?:opito|bosiet|huet)\b/iu.test(textBlob)) {
    certs.add("OPITO / IWCF");
  }
  if (/\b(?:secor|\bcor\b)\b/iu.test(textBlob)) {
    certs.add("COR / SECOR");
  }
  if (/\bisnetworld\b/iu.test(textBlob)) certs.add("ISNetworld");
  if (/\bcomplyworks\b/iu.test(textBlob)) certs.add("ComplyWorks");
  if (/\babsa\b/iu.test(textBlob)) certs.add("ABSA");
  if (/\bapi\s*(?:q1|q2|spec)\b/iu.test(textBlob)) certs.add("API Spec Q1 / Q2");
  if (/\bcwb\b/iu.test(textBlob)) certs.add("CSA / CWB");
  return [...certs];
}

function buildSearchQueue() {
  const queue = [];
  const defaultTrainCat = INCLUDE_TRAINING_CODE ? "oil_gas_training_courses" : "staffing_training_compliance";

  const caSorted = [...CANADA_HUBS].sort((a, b) => a.tier - b.tier || a.city.localeCompare(b.city));
  const usSorted = [...USA_HUBS].sort((a, b) => a.tier - b.tier || a.city.localeCompare(b.city));
  const caCoreAlphaHubs = caSorted.filter((h) =>
    ["Calgary", "Edmonton", "Grande Prairie", "Nisku", "Red Deer", "Fort McMurray", "Fort St. John", "Estevan", "Lloydminster", "Leduc"].includes(h.city),
  );
  const usCoreAlphaHubs = usSorted.filter((h) =>
    ["Houston", "Midland", "Odessa", "Williston", "Oklahoma City", "Tulsa", "Lafayette", "Houma", "Corpus Christi", "Kilgore", "Hobbs", "Casper", "Greeley", "Canonsburg", "Bakersfield"].includes(h.city),
  );

  // WAVE 1 (CANADA FIRST): Accredited Oil & Gas Training Facilities + Strict Alphabetical A -> Z across Core Canadian Oilpatch Hubs
  if (!COUNTRY_FILTER || COUNTRY_FILTER === "CA") {
    for (const hub of caSorted) {
      const templates = hub.tier === 1 ? TRAINING_SEARCH_TEMPLATES_CA : TRAINING_SEARCH_TEMPLATES_CA.slice(0, 2);
      for (const tpl of templates) {
        queue.push({
          id: `CA|${hub.regionCode}|${hub.city}|TRAIN|${tpl}`,
          countryCode: "CA",
          regionCode: hub.regionCode,
          city: hub.city,
          letter: "TRAIN",
          isTrainingQuery: true,
          defaultCat: defaultTrainCat,
          query: `${tpl} in ${hub.city}, ${hub.regionCode}`,
        });
      }
    }
    for (const letter of ALPHABET) {
      for (const hub of caCoreAlphaHubs) {
        queue.push({
          id: `CA|${hub.regionCode}|${hub.city}|ALPHA-${letter}`,
          countryCode: "CA",
          regionCode: hub.regionCode,
          city: hub.city,
          letter,
          isTrainingQuery: false,
          defaultCat: "equipment_rentals_tools",
          query: `"${letter}" Oilfield & Energy Services ${hub.city}, ${hub.regionCode}`,
        });
      }
    }
  }

  // WAVE 2 (USA SECOND): Accredited Oil & Gas Training Facilities + Strict Alphabetical A -> Z across Core US Oilpatch Hubs
  if (!COUNTRY_FILTER || COUNTRY_FILTER === "US") {
    for (const hub of usSorted) {
      const templates = hub.tier === 1 ? TRAINING_SEARCH_TEMPLATES_US : TRAINING_SEARCH_TEMPLATES_US.slice(0, 2);
      for (const tpl of templates) {
        queue.push({
          id: `US|${hub.regionCode}|${hub.city}|TRAIN|${tpl}`,
          countryCode: "US",
          regionCode: hub.regionCode,
          city: hub.city,
          letter: "TRAIN",
          isTrainingQuery: true,
          defaultCat: defaultTrainCat,
          query: `${tpl} in ${hub.city}, ${hub.regionCode}`,
        });
      }
    }
    for (const letter of ALPHABET) {
      for (const hub of usCoreAlphaHubs) {
        queue.push({
          id: `US|${hub.regionCode}|${hub.city}|ALPHA-${letter}`,
          countryCode: "US",
          regionCode: hub.regionCode,
          city: hub.city,
          letter,
          isTrainingQuery: false,
          defaultCat: "equipment_rentals_tools",
          query: `"${letter}" Oilfield & Energy Services ${hub.city}, ${hub.regionCode}`,
        });
      }
    }
  }

  // WAVE 3: Deep 22-Sector Sweep (Canada Hubs A->Z first, then USA Hubs A->Z)
  if (!COUNTRY_FILTER || COUNTRY_FILTER === "CA") {
    for (const hub of caSorted) {
      const sectors = hub.tier === 1 ? SECTOR_SEARCH_TEMPLATES : SECTOR_SEARCH_TEMPLATES.slice(0, 8);
      for (const sec of sectors) {
        queue.push({
          id: `CA|${hub.regionCode}|${hub.city}|SEC|${sec.cat}`,
          countryCode: "CA",
          regionCode: hub.regionCode,
          city: hub.city,
          letter: hub.city[0].toUpperCase(),
          isTrainingQuery: false,
          defaultCat: sec.cat,
          query: `${sec.q} in ${hub.city}, ${hub.regionCode}`,
        });
      }
    }
  }
  if (!COUNTRY_FILTER || COUNTRY_FILTER === "US") {
    for (const hub of usSorted) {
      const sectors = hub.tier === 1 ? SECTOR_SEARCH_TEMPLATES : SECTOR_SEARCH_TEMPLATES.slice(0, 8);
      for (const sec of sectors) {
        queue.push({
          id: `US|${hub.regionCode}|${hub.city}|SEC|${sec.cat}`,
          countryCode: "US",
          regionCode: hub.regionCode,
          city: hub.city,
          letter: hub.city[0].toUpperCase(),
          isTrainingQuery: false,
          defaultCat: sec.cat,
          query: `${sec.q} in ${hub.city}, ${hub.regionCode}`,
        });
      }
    }
  }

  return queue;
}

async function loadExistingFirestoreIndex(projectId) {
  console.log(`[bot16] Loading existing Firestore phone & company index from ${projectId}...`);
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const existingPhones = new Set();
  const existingNameRegion = new Set();
  const phoneToDocIds = new Map();
  const blockedPhones = new Set();

  // Load blocked numbers
  {
    const token = await resolveAccessToken(projectId);
    const res = await fetch(url, {
      method: "POST",
      headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
      body: JSON.stringify({
        structuredQuery: {from: [{collectionId: "yellow_pages_blocked_numbers"}], limit: 1000},
      }),
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
  console.log(
    `[bot16] Indexed ${total} live public entries (${existingPhones.size} phones, ${blockedPhones.size} blocked).`,
  );
  return {existingPhones, existingNameRegion, phoneToDocIds, blockedPhones};
}

async function scrapeGoogleMapsQuery(page, task) {
  const searchUrl = `https://www.google.com/maps/search/${encodeURIComponent(task.query)}?hl=en`;
  await page.goto(searchUrl, {waitUntil: "domcontentloaded", timeout: 22000});

  // Dismiss Google consent banner if ever shown
  const title = await page.title().catch(() => "");
  if (/before you continue/iu.test(title)) {
    const btn = await page.$('button[aria-label*="Accept"], form[action*="consent"] button');
    if (btn) await btn.click().catch(() => {});
  }

  await page.waitForSelector('div.Nv2PK, div[role="main"]', {timeout: 9000}).catch(() => {});
  await page.waitForTimeout(1600);

  // Scroll results feed up to 3 times to load ~30-40 local Google Business cards
  for (let s = 0; s < 3; s++) {
    const scrolled = await page.evaluate(() => {
      const feed = document.querySelector('div[role="feed"]');
      if (!feed) return false;
      const prev = feed.scrollTop;
      feed.scrollTop = feed.scrollHeight;
      return feed.scrollTop > prev;
    });
    if (!scrolled) break;
    await page.waitForTimeout(850);
  }

  const rawCards = await page.evaluate(() => {
    const cards = Array.from(document.querySelectorAll("div.Nv2PK"));
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
  });

  return rawCards;
}

function validateAndBuildRecord(card, task, indexState, seqNum) {
  const fullText = [card.name, ...card.lines].join(" · ");

  // 1. Check permanently/temporarily closed
  if (/\b(?:permanently\s+closed|temporarily\s+closed)\b/iu.test(fullText)) {
    const pNorm = normalizeNorthAmericanPhone(card.phone);
    if (pNorm.validNanpa && indexState.phoneToDocIds.has(pNorm.digits10)) {
      return {status: "closed_existing", docIds: indexState.phoneToDocIds.get(pNorm.digits10), name: card.name};
    }
    return {status: "rejected_closed"};
  }

  // 2. Clean & validate company name
  let cleanName = canonicalizeCompanyName(
    String(card.name || "").replace(/\s+-\s+(?:Main|North|South|East|West)\s+Campus$/iu, ""),
  );
  if (!cleanName || cleanName.length < 3) return {status: "rejected_invalid"};

  // 3. Consumer / retail / gas-station / non-industrial blocklist
  if (CONSUMER_NOISE_BLOCKLIST.test(fullText)) {
    return {status: "rejected_noise"};
  }
  if (!POSITIVE_OILFIELD_OR_TRAINING_SIGNAL.test(`${fullText} ${task.isTrainingQuery ? "" : ""}`)) {
    // Allow if non-training oilfield query returned a Google category like Welding, Trucking, Machine shop, Crane, Environmental, Industrial
    if (!/\b(?:industrial|equipment|contractor|supply|supplier|transport|freight|logistics|machining|steel|manufactur|engineering|testing|laboratory|safety|training)\b/iu.test(fullText)) {
      return {status: "rejected_non_oilfield"};
    }
  }
  if (task.isTrainingQuery) {
    // Extra strictness on Training queries: must have genuine safety / technical / industrial / oilfield / college / trade signal
    if (!/\b(?:safety|oilfield|energy|well\s+control|h2s|iwcf|opito|safeland|industrial|emergency|first\s+aid|rescue|confined\s+space|fall\s+protection|crane|rigging|truck|driver|cdl|class\s+1|weld|ndt|polytechnic|college|institute|technical|occupational|compliance|enviro|training\s+cent(?:er|re)|simulated\s+worksite)\b/iu.test(fullText)) {
      return {status: "rejected_non_oilfield_school"};
    }
  }

  // 4. Phone validation & blocked number check
  let rawPhone = card.phone;
  if (!rawPhone) {
    const m = fullText.match(/(?:\+?1[\s.-]?)?\(?([2-9]\d{2})\)?[\s.-]?(\d{3})[\s.-]?(\d{4})\b/u);
    if (m) rawPhone = `${m[1]}-${m[2]}-${m[3]}`;
  }
  const phoneNorm = normalizeNorthAmericanPhone(rawPhone);
  if (!phoneNorm.validNanpa) return {status: "rejected_no_phone"};
  if (indexState.blockedPhones.has(phoneNorm.digits10)) return {status: "rejected_blocked"};

  // 5. Anti-Zoom-Out Geographical Verification
  const phoneGeo = inferGeoFromNanpaPhone(phoneNorm.digits10);
  const targetCc = task.countryCode;
  let finalRc = canonicalizeRegionCode(task.regionCode, targetCc);
  let finalCity = task.city;

  const borderTwinOk =
    (finalCity === "Lloydminster" && (phoneGeo?.regionCode === "AB" || phoneGeo?.regionCode === "SK"));

  if (phoneGeo && !phoneGeo.isTollFree) {
    if (phoneGeo.countryCode !== targetCc) {
      return {status: "rejected_zoom_out_country"};
    }
    if (phoneGeo.regionCode !== finalRc && !borderTwinOk) {
      // Only accept if card text explicitly states the searched city & state
      const cityRx = new RegExp(`\\b${task.city.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&")}\\b`, "iu");
      if (!cityRx.test(fullText)) {
        return {status: "rejected_zoom_out_region"};
      }
    }
  } else {
    // Toll-free number: verify card address doesn't explicitly belong to a different state
    const otherStateMatch = fullText.match(/,\s*([A-Z]{2})\s+\d{5}\b/u);
    if (otherStateMatch && otherStateMatch[1] !== finalRc) {
      return {status: "rejected_zoom_out_tollfree"};
    }
  }

  // Extract street address from Google Maps category/address line (e.g. "Training center · 11901 97 Ave")
  let streetAddress = "";
  for (const line of card.lines) {
    if (/^\d\.\d\s*\(/u.test(line) || /^Open\b|^Closed\b|^Closes\b/iu.test(line)) continue;
    if (line.includes("·")) {
      const parts = line.split("·").map((p) => p.replace(/[^\x20-\x7E]/gu, "").trim()).filter(Boolean);
      const addrPart = parts.find((p) => /\d+\s+[A-Za-z0-9]/u.test(p) || /\b(?:Ave|St|Rd|Dr|Blvd|Hwy|Fwy|Pkwy|Way|Ln|Ct|Twp)\b/iu.test(p));
      if (addrPart) {
        streetAddress = addrPart.slice(0, 140);
        break;
      }
    }
  }

  finalCity = canonicalizeCityName(finalCity, finalRc, targetCc);
  const normName = normalizedCompanyName(cleanName);
  if (!normName) return {status: "rejected_invalid"};

  // 6. Deduplicate against existing Firestore + current session discoveries
  if (
    indexState.existingPhones.has(phoneNorm.digits10) ||
    indexState.existingNameRegion.has(`${normName}|${finalRc}`)
  ) {
    return {status: "duplicate_existing"};
  }

  indexState.existingPhones.add(phoneNorm.digits10);
  indexState.existingNameRegion.add(`${normName}|${finalRc}`);

  // 7. Build strict canonical private & public records (UNVERIFIED / free_basic!)
  const website = cleanWebsiteUrl(card.website);
  const emergency24x7 = /\b(?:open\s+24\s+hours|24\/7|24\s*hr)\b/iu.test(fullText);

  const gmapsTypeHint = card.lines.find((l) => l.includes("·") && !/^Open|^Closed/iu.test(l))?.split("·")[0]?.trim() || "";
  const rawHints = [cleanName, gmapsTypeHint, task.isTrainingQuery ? "Oilfield Safety Training Courses" : ""].filter(Boolean);
  let catCodes = classifyCategoriesFromText(rawHints, fullText).filter(
    (c) => CATEGORY_BY_CODE.has(c) && (INCLUDE_TRAINING_CODE || c !== "oil_gas_training_courses"),
  );
  if (task.isTrainingQuery && INCLUDE_TRAINING_CODE && !catCodes.includes("oil_gas_training_courses")) {
    catCodes = ["oil_gas_training_courses", ...catCodes];
  }
  if (catCodes.length === 0) {
    catCodes = [task.defaultCat];
  }
  catCodes = [...new Set(catCodes)].slice(0, 6);
  const categories = catCodes.map((c) => CATEGORY_BY_CODE.get(c)?.label || c);

  const services = [];
  if (gmapsTypeHint && gmapsTypeHint.length <= 48 && !/^\d/.test(gmapsTypeHint)) {
    services.push(gmapsTypeHint);
  }
  if (task.isTrainingQuery) {
    if (/\bh2s\b/iu.test(fullText)) services.push("H2S Alive Training");
    if (/\b(?:well\s+control|iwcf|wellsharp)\b/iu.test(fullText)) services.push("Well Control Training");
    if (/\b(?:opito|bosiet|huet|offshore)\b/iu.test(fullText)) services.push("Offshore Survival Training");
    if (/\b(?:safeland|veriforce|rigpass)\b/iu.test(fullText)) services.push("SafeLand / RigPass Orientation");
    if (services.length <= 1) services.push("Oil & Gas Safety & Technical Courses");
  }

  const geo = inferCountryAndRegion(targetCc, finalRc);
  const certifications = extractCertifications(fullText);
  const nowIso = new Date().toISOString();
  const slug = normName.replace(/[^a-z0-9]+/gu, "-").replace(/^-+|-+$/gu, "").slice(0, 48);
  const companyId = `gmaps-${targetCc.toLowerCase()}-${finalRc.toLowerCase()}-${slug}-${phoneNorm.digits10.slice(-4)}-${seqNum}`;

  const privateRecord = {
    schemaVersion: 2,
    companyId,
    discoveryChannel: task.isTrainingQuery ? "google_maps_training_audit" : "google_maps_alpha_audit",
    companyName: cleanName,
    normalizedCompanyName: normName,
    countryCode: geo.countryCode,
    regionCode: geo.regionCode,
    regionName: geo.regionName,
    city: finalCity,
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
    serviceAreas: [finalCity, geo.regionName].filter(Boolean),
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
        sourceType: "google_maps_audit",
        sourceName: `Google Maps ${task.countryCode} Alphabetical & Training Audit`,
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
    },
    publishedAt: nowIso,
    createdAt: nowIso,
    updatedAt: nowIso,
  };
  privateRecord.adminSearchTokens = buildAdminSearchTokens(privateRecord);
  const publicEntry = buildPublicEntry(privateRecord, companyId, nowIso);

  return {
    status: "accepted",
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
      console.error(`[bot16] Firestore batch sync HTTP ${res.status}: ${await res.text()}`);
    }
  }

  if (closedDocIds.length > 0) {
    const uniqueClosed = [...new Set(closedDocIds)];
    const writes = [];
    const nowIso = new Date().toISOString();
    for (const docId of uniqueClosed) {
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
      body: JSON.stringify({writes: writes.slice(0, 200)}),
      signal: AbortSignal.timeout(30000),
    }).catch(() => {});
  }
}

async function main() {
  await fsp.mkdir(LEDGER_DIR, {recursive: true});
  await fsp.mkdir(REPORTS_DIR, {recursive: true});

  const checkpointPath = path.join(LEDGER_DIR, "16_google_alpha_checkpoint.json");
  const jsonlPath = path.join(LEDGER_DIR, "16_google_alpha_discovered.jsonl");
  const reportPath = path.join(REPORTS_DIR, "16_GOOGLE_ALPHA_AUDIT_REPORT.md");

  if (args.includes("--sync-jsonl")) {
    if (!fs.existsSync(jsonlPath)) {
      console.log("[bot16] No JSONL file found to sync.");
      return;
    }
    const lines = (await fsp.readFile(jsonlPath, "utf8")).split("\n").filter((l) => l.trim());
    const parsed = lines.map((l) => JSON.parse(l));
    console.log(`[bot16] Streaming ${parsed.length} discovered Google businesses from JSONL to ${PROJECT_ID}...`);
    await syncBatchToFirestore(PROJECT_ID, parsed, []);
    console.log(`[bot16] Successfully published ${parsed.length} Google-audited businesses to ${PROJECT_ID}!`);
    return;
  }

  let visitedQueryIds = new Set();
  if (RESUME && fs.existsSync(checkpointPath)) {
    try {
      const cp = JSON.parse(await fsp.readFile(checkpointPath, "utf8"));
      visitedQueryIds = new Set(cp.visitedQueryIds || []);
    } catch (_) {}
  }

  const indexState = await loadExistingFirestoreIndex(PROJECT_ID);
  const fullQueue = buildSearchQueue();
  const pendingQueue = fullQueue.filter((q) => !visitedQueryIds.has(q.id)).slice(0, MAX_QUERIES);

  console.log(
    `[bot16] Launching ${NUM_AGENTS} parallel Google Maps Audit Agents | Pending queries in wave: ${pendingQueue.length}/${fullQueue.length} (sync=${SYNC})...`,
  );

  const {chromium} = await loadPlaywright();
  const browser = await chromium.launch({
    executablePath: findBrowserExe(),
    headless: true,
    args: ["--disable-blink-features=AutomationControlled", "--disable-gpu"],
  });

  const stats = {
    startedAt: new Date().toISOString(),
    queriesCompleted: 0,
    cardsInspected: 0,
    newBusinessesDiscovered: 0,
    newCanada: 0,
    newUSA: 0,
    newTrainingFacilities: 0,
    duplicatesAlreadyInDb: 0,
    closedOnGoogleRemoved: 0,
    rejectedNoiseOrZoomOut: 0,
    byRegion: {},
  };

  let cursor = 0;
  let seqCounter = Date.now() % 100000;
  const unsyncedBuffer = [];
  const closedExistingBuffer = [];

  const saveCheckpointAndReport = async () => {
    await fsp.writeFile(
      checkpointPath,
      JSON.stringify(
        {
          updatedAt: new Date().toISOString(),
          stats,
          visitedCount: visitedQueryIds.size,
          totalUniverseQueries: fullQueue.length,
          visitedQueryIds: [...visitedQueryIds],
        },
        null,
        2,
      ),
      "utf8",
    );

    const md = [
      "# Bot 16 — Multi-Agent Google Alphabetical (A–Z) & Training Audit Dashboard",
      "",
      `- **Updated At**: \`${new Date().toISOString()}\``,
      `- **Active Parallel Agents**: **${NUM_AGENTS}** Chromium Google Maps Agents`,
      `- **Queries Audited**: **${visitedQueryIds.size.toLocaleString()} / ${fullQueue.length.toLocaleString()}**`,
      `- **Google Business Cards Inspected**: **${stats.cardsInspected.toLocaleString()}**`,
      `- **Brand-New Missing Businesses Discovered**: **${stats.newBusinessesDiscovered.toLocaleString()}**`,
      `  - **Canada (\`CA\`)**: **${stats.newCanada.toLocaleString()}**`,
      `  - **United States (\`US\`)**: **${stats.newUSA.toLocaleString()}**`,
      `  - **Oil & Gas Training Facilities & Courses**: **${stats.newTrainingFacilities.toLocaleString()}**`,
      `- **Already in PipeBuyer Directory (Verified Active)**: **${stats.duplicatesAlreadyInDb.toLocaleString()}**`,
      `- **Permanently Closed Businesses Caught on Google**: **${stats.closedOnGoogleRemoved.toLocaleString()}**`,
      `- **Consumer / Noise / Zoom-Out Cards Blocked**: **${stats.rejectedNoiseOrZoomOut.toLocaleString()}**`,
      "",
      "## New Businesses by Province / State",
      "",
      ...Object.entries(stats.byRegion)
        .sort((a, b) => b[1] - a[1])
        .map(([k, v]) => `- **\`${k}\`**: ${v.toLocaleString()} new businesses`),
      "",
    ];
    await fsp.writeFile(reportPath, md.join("\n"), "utf8");
  };

  const flushUnsynced = async () => {
    if (!SYNC || (!unsyncedBuffer.length && !closedExistingBuffer.length)) return;
    const toSync = unsyncedBuffer.splice(0, unsyncedBuffer.length);
    const toClose = closedExistingBuffer.splice(0, closedExistingBuffer.length);
    await syncBatchToFirestore(PROJECT_ID, toSync, toClose);
  };

  try {
    const workers = Array.from({length: NUM_AGENTS}, async (_, agentIdx) => {
      const agentName = `Agent-${agentIdx + 1}`;
      const context = await browser.newContext({
        userAgent: USER_AGENT,
        locale: "en-US",
        viewport: {width: 1280, height: 900},
      });
      await context.route("**/*", (route) => {
        const rt = route.request().resourceType();
        if (rt === "image" || rt === "media" || rt === "font") {
          return route.abort();
        }
        return route.continue();
      });
      const page = await context.newPage();

      while (true) {
        const myIdx = cursor++;
        if (myIdx >= pendingQueue.length) break;
        const task = pendingQueue[myIdx];

        try {
          const cards = await scrapeGoogleMapsQuery(page, task);
          stats.queriesCompleted += 1;
          stats.cardsInspected += cards.length;
          visitedQueryIds.add(task.id);

          const jsonlLines = [];
          for (const card of cards) {
            seqCounter += 1;
            const res = validateAndBuildRecord(card, task, indexState, seqCounter);
            if (res.status === "accepted") {
              stats.newBusinessesDiscovered += 1;
              if (res.privateRecord.countryCode === "CA") stats.newCanada += 1;
              if (res.privateRecord.countryCode === "US") stats.newUSA += 1;
              if (res.isTraining) stats.newTrainingFacilities += 1;
              const rk = `${res.privateRecord.countryCode}-${res.privateRecord.regionCode}`;
              stats.byRegion[rk] = (stats.byRegion[rk] || 0) + 1;
              jsonlLines.push(JSON.stringify({privateRecord: res.privateRecord, publicEntry: res.publicEntry}));
              unsyncedBuffer.push(res);
            } else if (res.status === "duplicate_existing") {
              stats.duplicatesAlreadyInDb += 1;
            } else if (res.status === "closed_existing") {
              stats.closedOnGoogleRemoved += res.docIds.length;
              closedExistingBuffer.push(...res.docIds);
            } else {
              stats.rejectedNoiseOrZoomOut += 1;
            }
          }

          if (jsonlLines.length > 0) {
            await fsp.appendFile(jsonlPath, `${jsonlLines.join("\n")}\n`, "utf8");
          }

          if (stats.queriesCompleted % 15 === 0) {
            console.log(
              `[${agentName}] Progress ${stats.queriesCompleted}/${pendingQueue.length} | Cards: ${stats.cardsInspected} | NEW: ${stats.newBusinessesDiscovered} (CA=${stats.newCanada}, US=${stats.newUSA}, Training=${stats.newTrainingFacilities}) | Dups: ${stats.duplicatesAlreadyInDb}`,
            );
            await flushUnsynced();
            await saveCheckpointAndReport();
          }
        } catch (err) {
          console.warn(`[${agentName}] Query error (${task.id}): ${err.message}`);
        }
      }

      await context.close().catch(() => {});
    });

    await Promise.all(workers);
    await flushUnsynced();
    await saveCheckpointAndReport();
  } finally {
    await browser.close().catch(() => {});
  }

  console.log("[bot16] Wave complete! Final summary:", stats);
}

main().catch((err) => {
  console.error("[bot16] FATAL:", err);
  process.exit(1);
});
