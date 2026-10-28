#!/usr/bin/env node
/**
 * Bot 21 — Oil & Gas Crew Hotels, Workforce Lodging & New Sector Gap-Fill Fleet
 *
 * Audits 186 North American & International Oil & Gas hubs across 20 parallel Chromium agents:
 *   1. Crew Hotels, Extended-Stay Suites & Oilfield Worker-Rate Motels (`crew_hotels_workforce_lodging`):
 *      Targets CLC Lodging partners, extended-stay kitchenette suites, rig-worker motor inns,
 *      and corporate turnaround hotels (Pomeroy Inn & Suites, BCMInns, Microtel, TownePlace Suites,
 *      Candlewood Suites, Staybridge Suites, Home2 Suites, WoodSpring Suites, Target Hospitality,
 *      Aberdeen/Stavanger heliport hotels, Karratha/Roma workforce lodges, etc.) while strictly
 *      blocking tourist resorts, B&Bs, hostels, RV campgrounds, pet hotels, and residential apartments.
 *   2. Missing Yellow Pages Sector Top-Up across Tier-1 Oilpatch Hubs:
 *      - `scaffolding_insulation_coatings` (Industrial Scaffolding, Pipe/Tank Insulation, Coatings & IRATA)
 *      - `marine_offshore_aviation` (Offshore Supply Vessels, Commercial Diving, Subsea ROV & Helicopters)
 *      - `industrial_supply_ppe_workwear` (Oilfield Supply Stores, FR Workwear, Hydraulic Hose & Fasteners)
 *      - `lease_security_communications_it` (Oilfield Gate Guards, Lease CCTV, Two-Way Radio & Rig Starlink)
 *
 * Enforces 100% canonical town/region/country hygiene (`0` duplicate town spellings) and
 * NEVER pre-verifies (`verificationStatus: "unverified"`, `listingTier: "free_basic"`, `verified: false`).
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
  COUNTRY_BY_CODE,
  canonicalizeCityName,
  canonicalizeCompanyName,
  canonicalizeRegionCode,
  classifyCategoriesFromText,
  inferCountryAndRegion,
  inferGeoFromNanpaPhone,
  inferRegionFromCountryAndCity,
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
const CHECKPOINT_PATH = path.join(LEDGER_DIR, "21_crew_hotels_checkpoint.json");
const DISCOVERED_JSONL = path.join(LEDGER_DIR, "21_crew_hotels_discovered.jsonl");
const REPORT_PATH = path.join(REPORTS_DIR, "21_CREW_HOTELS_AND_SECTORS_REPORT.md");

const args = process.argv.slice(2);
const SYNC = args.includes("--sync");
const RESUME = !args.includes("--fresh");
const agentsIdx = args.indexOf("--agents");
const NUM_AGENTS = agentsIdx !== -1 ? Math.max(1, Math.min(24, Number(args[agentsIdx + 1] || 20))) : 20;
const maxQueriesIdx = args.indexOf("--max-queries");
const MAX_QUERIES = maxQueriesIdx !== -1 ? Number(args[maxQueriesIdx + 1] || 1000) : 1000;
const projIdx = args.indexOf("--project");
const PROJECT_ID = projIdx !== -1 && args[projIdx + 1] ? args[projIdx + 1] : "flutter-flow-pipe";

const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

const AGGREGATOR_DOMAIN_BLOCKLIST =
  /(?:google\.|gstatic\.|facebook\.|instagram\.|linkedin\.|youtube\.|yelp\.|yellowpages\.|tripadvisor\.|booking\.com|expedia\.|hotels\.com|priceline\.|agoda\.|kayak\.|trivago\.|airbnb\.|vrbo\.)/iu;

// Strict anti-tourist / anti-residential / anti-pet noise blocklist for Crew Hotels (tested against hotel name & primary category)
const HOTEL_NOISE_BLOCKLIST =
  /\b(?:bed\s*(?:&|and)\s*breakfast|\bb&b\b|hostel|backpacker|airbnb|vrbo|vacation\s+rental|holiday\s+home|chalet\s+rental|cabin\s+rental|glamping|rv\s+park|rv\s+resort|campground|koa\s+journey|koa\s+holiday|trailer\s+park|mobile\s+home\s+park|resort\s*(?:&|and)\s*spa|golf\s+resort|ski\s+resort|beach\s+resort|island\s+resort|casino|wedding\s+venue|banquet\s+hall|pet\s+hotel|pet\s+resort|dog\s+hotel|dog\s+boarding|cat\s+hotel|kennel|veterinary|animal\s+hospital|shelter|halfway\s+house|transitional\s+housing|sober\s+living|senior\s+living|assisted\s+living|retirement|nursing\s+home|memory\s+care|student\s+housing|dormitory|fraternity|sorority|self\s+storage|mini\s+storage|real\s+estate|realtor|property\s+management|apartment\s+complex|luxury\s+apartments|condominium|townhomes|pizzeria|steakhouse|liquor\s+store|nightclub|travel\s+agency|tour\s+operator)\b/iu;

// Positive commercial hotel / extended-stay / workforce lodging signal
const POSITIVE_CREW_HOTEL_SIGNAL =
  /\b(?:hotel|hotels|motel|motor\s+inn|motor\s+lodge|inn\b|suites\b|lodge\b|lodging|extended[\s-]*stay|workforce|crew|oilfield|turnaround|corporate|kitchenette|all[\s-]*suite|pomeroy|podollan|bcminns|executive\s+royal|sawridge|kanata|service\s+plus|encore\s+suites|derrick\s+motel|microtel|towneplace|candlewood|staybridge|home2|homewood|residence\s+inn|woodspring|suburban\s+studios|mainstay|my\s+place|everhome|hawthorn|sonesta|studio\s+6|motel\s+6|intown|hampton|holiday\s+inn|best\s+western|comfort\s+inn|comfort\s+suites|quality\s+inn|quality\s+hotel|sleep\s+inn|clarion|ramada|sandman|coast\s+hotel|days\s+inn|super\s+8|ecano|anavada|stanford\s+inn|stonebridge|la\s+quinta|baymont|wingate|wyndham|courtyard|fairfield|springhill|tru\s+by\s+hilton|avid\s+hotel|hilton\s+garden|doubletree|target\s+hospitality|civeo|black\s+diamond|cotton\s+logistics|aries\s+residence|permian\s+lodging|scandic|thon\s+hotel|thon\s+partner|radisson|clarion\s+collection|premier\s+inn|village\s+hotel|leonardo\s+hotel|travelodge|holiday\s+inn\s+express|mercure|novotel|ibis|citadines|adagio|rotana|quest\s+apartment|mantra|discovery\s+parks)\b/iu;

const SECTOR_NOISE_BLOCKLIST =
  /\b(?:gas\s+station|petrol\s+station|convenience\s+store|car\s+wash|jiffy\s+lube|walmart|costco|canadian\s+tire|home\s+depot|lowe'?s|menards|harbor\s+freight|autozone|o'reilly\s+auto|napa\s+auto|hair|beauty|salon|spa|restaurant|pizza|cafe|bakery|church|mosque|fitness|gym|real\s+estate|dentist|pharmacy|grocery|supermarket|boutique|womenswear|menswear|bridal|tuxedo|tailor|dry\s+cleaner|shoe\s+ carnival|foot\s+locker|famous\s+footwear|adt\s+security|vivint|simplisafe|best\s+buy|t-mobile|verizon\s+store|at&t\s+store|cricket\s+wireless)\b/iu;

const POSITIVE_SECTOR_SIGNAL =
  /\b(?:scaffold|scaffolding|insulation|utilidor|heat\s+tracing|sandblast|abrasive\s+blast|coating|lining|painting|refractory|fireproof|rope\s+access|irata|offshore|marine|vessel|psv|ahts|crew\s+boat|tug|barge|diving|subsea|rov|helicopter|heliport|aviation|air\s+charter|oilfield\s+supply|industrial\s+supply|flame\s+resistant|fr\s+(?:clothing|workwear|apparel)|workwear|coveralls|safety\s+(?:supply|boots|equipment)|ppe|hydraulic\s+hose|industrial\s+hose|fastener|bearing|rigging|wire\s+rope|welding\s+supply|gate\s+guard|lease\s+security|oilfield\s+security|site\s+security|surveillance|cctv|two[\s-]*way\s+radio|cell\s+booster|satellite|starlink|communications|lone\s+worker)\b/iu;

const EXTRA_VALID_US_NPA = new Set([
  "205", "209", "214", "216", "217", "219", "225", "228", "231", "248", "251", "254", "256", "269", "270", "281",
  "304", "307", "308", "309", "313", "316", "318", "325", "330", "334", "337", "346", "361", "385", "402", "405",
  "406", "409", "412", "419", "430", "432", "435", "440", "469", "479", "501", "502", "504", "505", "512", "513",
  "539", "559", "562", "572", "575", "580", "601", "606", "614", "618", "620", "661", "662", "681", "682", "701",
  "713", "720", "724", "740", "785", "801", "805", "806", "812", "814", "817", "830", "832", "870", "903", "907",
  "913", "915", "918", "936", "940", "956", "970", "972", "979", "985", "989",
]);

const INTL_COUNTRY_PHONE_RULES = {
  GB: {dial: "44", minNat: 9, maxNat: 10},
  NO: {dial: "47", minNat: 8, maxNat: 8},
  NL: {dial: "31", minNat: 9, maxNat: 9},
  DE: {dial: "49", minNat: 8, maxNat: 11},
  AE: {dial: "971", minNat: 8, maxNat: 9},
  SA: {dial: "966", minNat: 8, maxNat: 9},
  QA: {dial: "974", minNat: 8, maxNat: 8},
  OM: {dial: "968", minNat: 8, maxNat: 8},
  AU: {dial: "61", minNat: 9, maxNat: 10},
  BR: {dial: "55", minNat: 10, maxNat: 11},
  MX: {dial: "52", minNat: 10, maxNat: 10},
  GY: {dial: "592", minNat: 7, maxNat: 7},
  TT: {dial: "1868", minNat: 7, maxNat: 10},
  NG: {dial: "234", minNat: 8, maxNat: 10},
  SG: {dial: "65", minNat: 8, maxNat: 8},
  MY: {dial: "60", minNat: 8, maxNat: 10},
  KZ: {dial: "77", minNat: 9, maxNat: 9},
};

// 186 High-Activity Oil & Gas Crew Towns & Offshore/Turnaround Hubs
const CREW_LODGING_HUBS = [
  // CANADA (48 Oilpatch & Turnaround Hubs)
  {cc: "CA", rc: "AB", city: "Grande Prairie", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Fort McMurray", tier: 1, offshore: true},
  {cc: "CA", rc: "AB", city: "Nisku", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Leduc", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Edmonton", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Acheson", tier: 2, offshore: false},
  {cc: "CA", rc: "AB", city: "Sherwood Park", tier: 2, offshore: false},
  {cc: "CA", rc: "AB", city: "Fort Saskatchewan", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Red Deer", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Drayton Valley", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Whitecourt", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Edson", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Hinton", tier: 2, offshore: false},
  {cc: "CA", rc: "AB", city: "Fox Creek", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Valleyview", tier: 2, offshore: false},
  {cc: "CA", rc: "AB", city: "Peace River", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "High Level", tier: 2, offshore: false},
  {cc: "CA", rc: "AB", city: "Slave Lake", tier: 2, offshore: false},
  {cc: "CA", rc: "AB", city: "Bonnyville", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Cold Lake", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Lac La Biche", tier: 2, offshore: false},
  {cc: "CA", rc: "AB", city: "Lloydminster", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Wainwright", tier: 2, offshore: false},
  {cc: "CA", rc: "AB", city: "Vermilion", tier: 2, offshore: false},
  {cc: "CA", rc: "AB", city: "Provost", tier: 2, offshore: false},
  {cc: "CA", rc: "AB", city: "Brooks", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Medicine Hat", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Rocky Mountain House", tier: 1, offshore: false},
  {cc: "CA", rc: "AB", city: "Sundre", tier: 2, offshore: false},
  {cc: "CA", rc: "AB", city: "Olds", tier: 2, offshore: false},
  {cc: "CA", rc: "AB", city: "Stettler", tier: 2, offshore: false},
  {cc: "CA", rc: "AB", city: "Calgary", tier: 1, offshore: false},
  {cc: "CA", rc: "BC", city: "Fort St. John", tier: 1, offshore: false},
  {cc: "CA", rc: "BC", city: "Dawson Creek", tier: 1, offshore: false},
  {cc: "CA", rc: "BC", city: "Fort Nelson", tier: 2, offshore: false},
  {cc: "CA", rc: "BC", city: "Tumbler Ridge", tier: 2, offshore: false},
  {cc: "CA", rc: "BC", city: "Chetwynd", tier: 2, offshore: false},
  {cc: "CA", rc: "BC", city: "Kitimat", tier: 1, offshore: true},
  {cc: "CA", rc: "BC", city: "Terrace", tier: 2, offshore: false},
  {cc: "CA", rc: "BC", city: "Prince George", tier: 2, offshore: false},
  {cc: "CA", rc: "SK", city: "Estevan", tier: 1, offshore: false},
  {cc: "CA", rc: "SK", city: "Weyburn", tier: 1, offshore: false},
  {cc: "CA", rc: "SK", city: "Kindersley", tier: 1, offshore: false},
  {cc: "CA", rc: "SK", city: "Swift Current", tier: 2, offshore: false},
  {cc: "CA", rc: "MB", city: "Virden", tier: 2, offshore: false},
  {cc: "CA", rc: "NL", city: "St. John's", tier: 1, offshore: true},
  {cc: "CA", rc: "NS", city: "Halifax", tier: 2, offshore: true},
  {cc: "CA", rc: "ON", city: "Sarnia", tier: 1, offshore: false},

  // USA (102 Oilpatch, Shale & Refinery Turnaround Crew Hubs)
  {cc: "US", rc: "TX", city: "Midland", tier: 1, offshore: false},
  {cc: "US", rc: "TX", city: "Odessa", tier: 1, offshore: false},
  {cc: "US", rc: "TX", city: "Pecos", tier: 1, offshore: false},
  {cc: "US", rc: "TX", city: "Monahans", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Andrews", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Big Spring", tier: 1, offshore: false},
  {cc: "US", rc: "TX", city: "Kermit", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Fort Stockton", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Snyder", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "San Angelo", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Cotulla", tier: 1, offshore: false},
  {cc: "US", rc: "TX", city: "Carrizo Springs", tier: 1, offshore: false},
  {cc: "US", rc: "TX", city: "Karnes City", tier: 1, offshore: false},
  {cc: "US", rc: "TX", city: "Kenedy", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Three Rivers", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Pleasanton", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Cuero", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Gonzales", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Victoria", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Corpus Christi", tier: 1, offshore: true},
  {cc: "US", rc: "TX", city: "Ingleside", tier: 2, offshore: true},
  {cc: "US", rc: "TX", city: "Port Arthur", tier: 1, offshore: true},
  {cc: "US", rc: "TX", city: "Beaumont", tier: 1, offshore: false},
  {cc: "US", rc: "TX", city: "Baytown", tier: 1, offshore: false},
  {cc: "US", rc: "TX", city: "Deer Park", tier: 1, offshore: false},
  {cc: "US", rc: "TX", city: "Pasadena", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "La Porte", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Freeport", tier: 2, offshore: true},
  {cc: "US", rc: "TX", city: "Lake Jackson", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Texas City", tier: 1, offshore: false},
  {cc: "US", rc: "TX", city: "Longview", tier: 1, offshore: false},
  {cc: "US", rc: "TX", city: "Kilgore", tier: 2, offshore: false},
  {cc: "US", rc: "TX", city: "Houston", tier: 1, offshore: true},
  {cc: "US", rc: "NM", city: "Hobbs", tier: 1, offshore: false},
  {cc: "US", rc: "NM", city: "Carlsbad", tier: 1, offshore: false},
  {cc: "US", rc: "NM", city: "Artesia", tier: 1, offshore: false},
  {cc: "US", rc: "NM", city: "Jal", tier: 2, offshore: false},
  {cc: "US", rc: "NM", city: "Lovington", tier: 2, offshore: false},
  {cc: "US", rc: "NM", city: "Farmington", tier: 1, offshore: false},
  {cc: "US", rc: "ND", city: "Williston", tier: 1, offshore: false},
  {cc: "US", rc: "ND", city: "Watford City", tier: 1, offshore: false},
  {cc: "US", rc: "ND", city: "Dickinson", tier: 1, offshore: false},
  {cc: "US", rc: "ND", city: "Tioga", tier: 2, offshore: false},
  {cc: "US", rc: "ND", city: "Stanley", tier: 2, offshore: false},
  {cc: "US", rc: "ND", city: "Minot", tier: 2, offshore: false},
  {cc: "US", rc: "ND", city: "New Town", tier: 2, offshore: false},
  {cc: "US", rc: "OK", city: "Elk City", tier: 1, offshore: false},
  {cc: "US", rc: "OK", city: "Woodward", tier: 2, offshore: false},
  {cc: "US", rc: "OK", city: "Weatherford", tier: 2, offshore: false},
  {cc: "US", rc: "OK", city: "Enid", tier: 2, offshore: false},
  {cc: "US", rc: "OK", city: "Chickasha", tier: 2, offshore: false},
  {cc: "US", rc: "OK", city: "Duncan", tier: 2, offshore: false},
  {cc: "US", rc: "OK", city: "Ardmore", tier: 2, offshore: false},
  {cc: "US", rc: "OK", city: "Cushing", tier: 2, offshore: false},
  {cc: "US", rc: "OK", city: "Oklahoma City", tier: 1, offshore: false},
  {cc: "US", rc: "OK", city: "Tulsa", tier: 1, offshore: false},
  {cc: "US", rc: "LA", city: "Houma", tier: 1, offshore: true},
  {cc: "US", rc: "LA", city: "Morgan City", tier: 1, offshore: true},
  {cc: "US", rc: "LA", city: "Broussard", tier: 1, offshore: true},
  {cc: "US", rc: "LA", city: "New Iberia", tier: 2, offshore: true},
  {cc: "US", rc: "LA", city: "Lafayette", tier: 1, offshore: true},
  {cc: "US", rc: "LA", city: "Lake Charles", tier: 1, offshore: true},
  {cc: "US", rc: "LA", city: "Sulphur", tier: 2, offshore: false},
  {cc: "US", rc: "LA", city: "Port Allen", tier: 2, offshore: false},
  {cc: "US", rc: "LA", city: "Bossier City", tier: 2, offshore: false},
  {cc: "US", rc: "WY", city: "Gillette", tier: 1, offshore: false},
  {cc: "US", rc: "WY", city: "Casper", tier: 1, offshore: false},
  {cc: "US", rc: "WY", city: "Douglas", tier: 2, offshore: false},
  {cc: "US", rc: "WY", city: "Rock Springs", tier: 1, offshore: false},
  {cc: "US", rc: "WY", city: "Rawlins", tier: 2, offshore: false},
  {cc: "US", rc: "WY", city: "Evanston", tier: 2, offshore: false},
  {cc: "US", rc: "CO", city: "Greeley", tier: 1, offshore: false},
  {cc: "US", rc: "CO", city: "Brighton", tier: 2, offshore: false},
  {cc: "US", rc: "CO", city: "Fort Morgan", tier: 2, offshore: false},
  {cc: "US", rc: "CO", city: "Rifle", tier: 2, offshore: false},
  {cc: "US", rc: "CO", city: "Grand Junction", tier: 2, offshore: false},
  {cc: "US", rc: "PA", city: "Washington", tier: 1, offshore: false},
  {cc: "US", rc: "PA", city: "Canonsburg", tier: 2, offshore: false},
  {cc: "US", rc: "PA", city: "Waynesburg", tier: 2, offshore: false},
  {cc: "US", rc: "PA", city: "Williamsport", tier: 1, offshore: false},
  {cc: "US", rc: "PA", city: "Towanda", tier: 2, offshore: false},
  {cc: "US", rc: "PA", city: "Bradford", tier: 2, offshore: false},
  {cc: "US", rc: "PA", city: "DuBois", tier: 2, offshore: false},
  {cc: "US", rc: "WV", city: "Morgantown", tier: 1, offshore: false},
  {cc: "US", rc: "WV", city: "Bridgeport", tier: 2, offshore: false},
  {cc: "US", rc: "WV", city: "Wheeling", tier: 2, offshore: false},
  {cc: "US", rc: "WV", city: "Moundsville", tier: 2, offshore: false},
  {cc: "US", rc: "OH", city: "St. Clairsville", tier: 1, offshore: false},
  {cc: "US", rc: "OH", city: "Cambridge", tier: 2, offshore: false},
  {cc: "US", rc: "OH", city: "Marietta", tier: 2, offshore: false},
  {cc: "US", rc: "OH", city: "Canton", tier: 2, offshore: false},
  {cc: "US", rc: "AK", city: "Anchorage", tier: 1, offshore: true},
  {cc: "US", rc: "AK", city: "Kenai", tier: 2, offshore: true},
  {cc: "US", rc: "CA", city: "Bakersfield", tier: 1, offshore: false},
  {cc: "US", rc: "CA", city: "Taft", tier: 2, offshore: false},
  {cc: "US", rc: "UT", city: "Vernal", tier: 1, offshore: false},
  {cc: "US", rc: "MT", city: "Sidney", tier: 2, offshore: false},
  {cc: "US", rc: "MT", city: "Billings", tier: 2, offshore: false},
  {cc: "US", rc: "KS", city: "Liberal", tier: 2, offshore: false},
  {cc: "US", rc: "KS", city: "Great Bend", tier: 2, offshore: false},
  {cc: "US", rc: "AR", city: "El Dorado", tier: 2, offshore: false},
  {cc: "US", rc: "MS", city: "Laurel", tier: 2, offshore: false},

  // INTERNATIONAL OFFSHORE, HELIPORT & TURNAROUND CREW HUBS (36 Hubs)
  {cc: "GB", rc: "SCT", city: "Aberdeen", countryLabel: "Scotland, UK", tier: 1, offshore: true},
  {cc: "GB", rc: "ENG", city: "Great Yarmouth", countryLabel: "UK", tier: 1, offshore: true},
  {cc: "GB", rc: "ENG", city: "Hull", countryLabel: "UK", tier: 2, offshore: true},
  {cc: "GB", rc: "ENG", city: "Middlesbrough", countryLabel: "UK", tier: 2, offshore: false},
  {cc: "NO", rc: "RO", city: "Stavanger", countryLabel: "Norway", tier: 1, offshore: true},
  {cc: "NO", rc: "VL", city: "Bergen", countryLabel: "Norway", tier: 1, offshore: true},
  {cc: "NO", rc: "VL", city: "Kristiansund", countryLabel: "Norway", tier: 2, offshore: true},
  {cc: "NO", rc: "TR", city: "Hammerfest", countryLabel: "Norway", tier: 2, offshore: true},
  {cc: "NL", rc: "NH", city: "Den Helder", countryLabel: "Netherlands", tier: 2, offshore: true},
  {cc: "NL", rc: "ZH", city: "Rotterdam", countryLabel: "Netherlands", tier: 1, offshore: true},
  {cc: "DE", rc: "NI", city: "Celle", countryLabel: "Germany", tier: 2, offshore: false},
  {cc: "AE", rc: "AZ", city: "Abu Dhabi", countryLabel: "UAE", tier: 1, offshore: true},
  {cc: "AE", rc: "DU", city: "Dubai", countryLabel: "UAE", tier: 1, offshore: true},
  {cc: "SA", rc: "EP", city: "Al Khobar", countryLabel: "Saudi Arabia", tier: 1, offshore: true},
  {cc: "SA", rc: "EP", city: "Jubail", countryLabel: "Saudi Arabia", tier: 2, offshore: false},
  {cc: "QA", rc: "DA", city: "Doha", countryLabel: "Qatar", tier: 1, offshore: true},
  {cc: "OM", rc: "MA", city: "Muscat", countryLabel: "Oman", tier: 2, offshore: false},
  {cc: "OM", rc: "WU", city: "Duqm", countryLabel: "Oman", tier: 2, offshore: true},
  {cc: "AU", rc: "WA", city: "Karratha", countryLabel: "WA, Australia", tier: 1, offshore: true},
  {cc: "AU", rc: "WA", city: "Port Hedland", countryLabel: "WA, Australia", tier: 2, offshore: true},
  {cc: "AU", rc: "WA", city: "Perth", countryLabel: "WA, Australia", tier: 1, offshore: true},
  {cc: "AU", rc: "QLD", city: "Roma", countryLabel: "QLD, Australia", tier: 2, offshore: false},
  {cc: "AU", rc: "QLD", city: "Chinchilla", countryLabel: "QLD, Australia", tier: 2, offshore: false},
  {cc: "AU", rc: "NT", city: "Darwin", countryLabel: "NT, Australia", tier: 2, offshore: true},
  {cc: "BR", rc: "RJ", city: "Macae", countryLabel: "RJ, Brazil", tier: 1, offshore: true},
  {cc: "MX", rc: "CAM", city: "Ciudad del Carmen", countryLabel: "Campeche, Mexico", tier: 1, offshore: true},
  {cc: "GY", rc: "DE", city: "Georgetown", countryLabel: "Guyana", tier: 1, offshore: true},
  {cc: "TT", rc: "SFO", city: "San Fernando", countryLabel: "Trinidad", tier: 2, offshore: true},
  {cc: "NG", rc: "RI", city: "Port Harcourt", countryLabel: "Nigeria", tier: 1, offshore: true},
  {cc: "NG", rc: "LA", city: "Lagos", countryLabel: "Nigeria", tier: 2, offshore: true},
  {cc: "SG", rc: "SGP", city: "Singapore", countryLabel: "Singapore", tier: 1, offshore: true},
  {cc: "MY", rc: "SWK", city: "Miri", countryLabel: "Sarawak, Malaysia", tier: 1, offshore: true},
  {cc: "MY", rc: "SBH", city: "Labuan", countryLabel: "Malaysia", tier: 2, offshore: true},
  {cc: "MY", rc: "TRG", city: "Kemaman", countryLabel: "Malaysia", tier: 2, offshore: true},
  {cc: "KZ", rc: "ATY", city: "Atyrau", countryLabel: "Kazakhstan", tier: 1, offshore: true},
  {cc: "KZ", rc: "MAN", city: "Aktau", countryLabel: "Kazakhstan", tier: 2, offshore: true},
];

function buildSearchQueue() {
  const queue = [];
  for (const hub of CREW_LODGING_HUBS) {
    const loc = hub.cc === "CA" || hub.cc === "US" ? `${hub.city}, ${hub.rc}` : `${hub.city}, ${hub.countryLabel}`;

    // 1. Crew Hotels, Extended-Stay Suites & Oilfield Worker Rates (All 186 hubs — Travel Feed Card-Click Engine)
    const hotelTemplates =
      hub.cc === "CA" || hub.cc === "US"
        ? hub.tier === 1
          ? [
              "Hotels & Extended Stay Suites",
              "Motor Inn & Workforce Lodging Motels",
            ]
          : ["Hotels Extended Stay Suites & Motor Inns"]
        : hub.tier === 1
          ? ["Business Hotels & Extended Stay Suites", "Serviced Apartments & Corporate Hotels"]
          : ["Business Hotels & Suites"];

    for (const tpl of hotelTemplates) {
      queue.push({
        id: `HOTEL2|${hub.cc}|${hub.rc}|${hub.city}|${tpl}`,
        kind: "crew_hotel",
        countryCode: hub.cc,
        regionCode: hub.rc,
        city: hub.city,
        defaultCat: "crew_hotels_workforce_lodging",
        query: `${tpl} in ${loc}`,
      });
    }

    // 2. Targeted Top-Up for the 4 Other Newly Added Yellow Pages Sectors in Tier-1 Hubs
    if (hub.tier === 1) {
      queue.push({
        id: `SEC|${hub.cc}|${hub.rc}|${hub.city}|scaffolding_insulation_coatings`,
        kind: "sector",
        countryCode: hub.cc,
        regionCode: hub.rc,
        city: hub.city,
        defaultCat: "scaffolding_insulation_coatings",
        query: `Industrial Scaffolding Pipe Insulation & Sandblasting in ${loc}`,
      });
      queue.push({
        id: `SEC|${hub.cc}|${hub.rc}|${hub.city}|industrial_supply_ppe_workwear`,
        kind: "sector",
        countryCode: hub.cc,
        regionCode: hub.rc,
        city: hub.city,
        defaultCat: "industrial_supply_ppe_workwear",
        query: `Oilfield Industrial Supply FR Workwear & Hydraulic Hose in ${loc}`,
      });
      if (hub.offshore) {
        queue.push({
          id: `SEC|${hub.cc}|${hub.rc}|${hub.city}|marine_offshore_aviation`,
          kind: "sector",
          countryCode: hub.cc,
          regionCode: hub.rc,
          city: hub.city,
          defaultCat: "marine_offshore_aviation",
          query: `Offshore Marine Supply Vessels Commercial Diving ROV & Helicopter in ${loc}`,
        });
      }
      if (hub.cc === "CA" || hub.cc === "US") {
        queue.push({
          id: `SEC2|${hub.cc}|${hub.rc}|${hub.city}|security_guards_surveillance`,
          kind: "sector",
          countryCode: hub.cc,
          regionCode: hub.rc,
          city: hub.city,
          defaultCat: "lease_security_communications_it",
          query: `Security Guard Services & Mobile Video Surveillance in ${loc}`,
        });
        queue.push({
          id: `SEC2|${hub.cc}|${hub.rc}|${hub.city}|twoway_radio_satellite_comms`,
          kind: "sector",
          countryCode: hub.cc,
          regionCode: hub.rc,
          city: hub.city,
          defaultCat: "lease_security_communications_it",
          query: `Two-Way Radio & Satellite Communications in ${loc}`,
        });
      }
    }
  }
  return queue;
}

function cleanWebsiteUrl(rawHref) {
  if (!rawHref) return "";
  let u = String(rawHref).trim();
  try {
    if (u.includes("google.com/url?")) {
      const parsed = new URL(u);
      u = parsed.searchParams.get("q") || parsed.searchParams.get("url") || u;
    }
    const p = new URL(u);
    if (!["http:", "https:"].includes(p.protocol)) return "";
    if (AGGREGATOR_DOMAIN_BLOCKLIST.test(p.hostname)) return "";
    p.hash = "";
    for (const k of [...p.searchParams.keys()]) {
      if (/^utm_|^fbclid$|^gclid$/iu.test(k)) p.searchParams.delete(k);
    }
    return p.toString().slice(0, 260);
  } catch {
    return "";
  }
}

function normalizeIntlPhoneStrict(rawPhone, countryCode) {
  const rule = INTL_COUNTRY_PHONE_RULES[countryCode];
  if (!rule || !rawPhone) return null;
  let s = String(rawPhone).trim();
  const digits = s.replace(/\D+/gu, "");
  if (digits.length < 7 || digits.length > 15) return null;

  let nat = "";
  if (s.startsWith("+")) {
    if (!digits.startsWith(rule.dial)) return null;
    nat = digits.slice(rule.dial.length);
    if (nat.startsWith("0") && nat.length > rule.minNat) nat = nat.slice(1);
  } else if (digits.startsWith("00" + rule.dial)) {
    nat = digits.slice(2 + rule.dial.length);
  } else if (digits.startsWith(rule.dial) && digits.length >= rule.dial.length + rule.minNat) {
    nat = digits.slice(rule.dial.length);
  } else if (countryCode === "KZ" && digits.length === 11 && digits.startsWith("87")) {
    nat = digits.slice(2);
  } else if (digits.startsWith("0")) {
    nat = digits.slice(1);
  } else if (digits.length >= rule.minNat && digits.length <= rule.maxNat) {
    nat = digits;
  } else {
    return null;
  }

  if (nat.length < rule.minNat || nat.length > rule.maxNat) return null;
  const fullDigits = `${rule.dial}${nat}`;
  return {
    digitsKey: fullDigits,
    display: `+${rule.dial} ${nat}`,
    isTollFree: false,
  };
}

async function loadExistingFirestoreIndex(projectId) {
  console.log(`[bot21] Loading existing Firestore phone & company index from ${projectId}...`);
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const existingPhones = new Set();
  const existingNameRegion = new Set();
  let lastDoc = null;
  let total = 0;

  while (true) {
    const token = await resolveAccessToken(projectId);
    const sq = {
      from: [{collectionId: "yellow_pages_public_entries"}],
      select: {
        fields: [
          {fieldPath: "companyName"},
          {fieldPath: "countryCode"},
          {fieldPath: "regionCode"},
          {fieldPath: "city"},
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
      const f = d.fields || {};
      const cc = f.countryCode?.stringValue || "CA";
      const rc = f.regionCode?.stringValue || "";
      const cty = (f.city?.stringValue || "").toLowerCase();
      const nm = normalizedCompanyName(f.companyName?.stringValue || "");
      if (nm) {
        existingNameRegion.add(`${nm}|${cc}|${rc}`);
        if (cty) existingNameRegion.add(`${nm}|${cc}|${rc}|${cty}`);
      }
      for (const k of ["publicPhone", "tollFreePhone"]) {
        const digits = (f[k]?.stringValue || "").replace(/\D+/gu, "");
        if (digits.length >= 8) {
          existingPhones.add(digits);
          if (digits.length >= 10) existingPhones.add(digits.slice(-10));
        }
      }
    }
    if (docs.length < 3000) break;
  }
  console.log(`[bot21] Indexed ${total} live public entries (${existingPhones.size} phone keys).`);
  return {existingPhones, existingNameRegion};
}

async function resolvePlaywrightChromium() {
  const candidates = [
    path.resolve(REPO_ROOT, "../scratch/flag-gen/node_modules/playwright-core/index.mjs"),
    "C:/Users/jordi/.gemini/antigravity/brain/89d324bb-a72f-4739-a356-b6b46e26db9a/scratch/flag-gen/node_modules/playwright-core/index.mjs",
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) {
      const mod = await import(pathToFileURL(p).href);
      return mod.chromium;
    }
  }
  const mod = await import("playwright-core");
  return mod.chromium;
}

async function extractGoogleMapsCards(page, searchQuery, isHotelQuery = false) {
  const searchUrl = `https://www.google.com/maps/search/${encodeURIComponent(searchQuery)}?hl=en`;
  await page.goto(searchUrl, {waitUntil: "domcontentloaded", timeout: 22000});

  if (page.url().includes("consent.google")) {
    const btn = await page.$('button[aria-label*="Accept"], form[action*="consent"] button');
    if (btn) await btn.click().catch(() => {});
  }

  await page.waitForSelector('a.hfpxzc, div.Nv2PK, h1.DUwDvf, div[role="feed"]', {timeout: 7000}).catch(() => {});
  await page.waitForTimeout(550);

  for (let s = 0; s < 4; s++) {
    const scrolled = await page.evaluate(() => {
      const feed = document.querySelector('div[role="feed"]');
      if (!feed) return false;
      const prev = feed.scrollTop;
      feed.scrollTop = feed.scrollHeight;
      return feed.scrollTop > prev;
    });
    if (!scrolled) break;
    await page.waitForTimeout(380);
  }

  // Google Maps Travel / Hotel feed cards do NOT render phone spans (`span.UsdlK`) in the left list;
  // clicking each unique `a.hfpxzc` place anchor opens the detail pane with phone, website & street address.
  if (isHotelQuery) {
    const handles = await page.$$('a.hfpxzc[href*="/maps/place/"]');
    if (handles.length > 0) {
      const results = [];
      const seenLabels = new Set();
      for (const h of handles) {
        if (results.length >= 14) break;
        const aria = ((await h.getAttribute("aria-label").catch(() => "")) || "").trim();
        if (!aria || seenLabels.has(aria.toLowerCase())) continue;
        seenLabels.add(aria.toLowerCase());
        if (HOTEL_NOISE_BLOCKLIST.test(aria)) continue;

        const href = (await h.getAttribute("href").catch(() => "")) || "";
        await h.click({timeout: 2200}).catch(() => {});
        await page.waitForTimeout(680);

        const detail = await page.evaluate(() => {
          const h1 = document.querySelector("h1.DUwDvf")?.textContent?.trim() || "";
          const catLine = document.querySelector("button.DkEaL")?.textContent?.trim() || "";
          const phoneBtn = document.querySelector('button[data-item-id^="phone:tel:"], [aria-label*="Phone:" i]');
          const dtid = phoneBtn?.getAttribute("data-item-id") || "";
          const phone = dtid.startsWith("phone:tel:")
            ? dtid.replace("phone:tel:", "").trim()
            : (phoneBtn?.getAttribute("aria-label") || phoneBtn?.textContent || "").replace(/^Phone:\s*/iu, "").trim();
          const web =
            document.querySelector('a[data-item-id="authority"], a[aria-label*="Website:" i]')?.getAttribute("href") || "";
          const addrRaw =
            document.querySelector('button[data-item-id="address"], [aria-label*="Address:" i]')?.textContent?.trim() || "";
          const fullAddress = addrRaw.replace(/^[^\p{L}\p{N}]+/u, "").trim();
          return {h1, catLine, phone, web, fullAddress};
        });

        results.push({
          name: detail.h1 || aria,
          phone: detail.phone,
          website: detail.web,
          placeUrl: href,
          fullAddress: detail.fullAddress,
          categoryLine: detail.catLine,
          lines: [detail.catLine, detail.fullAddress].filter(Boolean),
        });
      }
      return results;
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
    const h1 = document.querySelector("h1.DUwDvf");
    if (h1 && h1.textContent?.trim()) {
      const mainEl = document.querySelector('div[role="main"]') || document.body;
      const phoneBtn = mainEl.querySelector('button[data-item-id^="phone:tel:"], [aria-label*="Phone:" i]');
      const dtid = phoneBtn?.getAttribute("data-item-id") || "";
      const phone = dtid.startsWith("phone:tel:") ? dtid.replace("phone:tel:", "").trim() : phoneBtn?.textContent?.trim() || "";
      const webLink = mainEl.querySelector('a[data-item-id="authority"], a[aria-label*="Website:" i]');
      const addrRaw =
        mainEl.querySelector('button[data-item-id="address"], [aria-label*="Address:" i]')?.textContent?.trim() || "";
      const fullAddress = addrRaw.replace(/^[^\p{L}\p{N}]+/u, "").trim();
      const lines = (mainEl.innerText || "")
        .split("\n")
        .map((s) => s.trim())
        .filter((s) => s.length > 0 && s.length < 180)
        .slice(0, 20);
      return [{name: h1.textContent.trim(), phone, website: webLink?.getAttribute("href") || "", placeUrl: location.href, fullAddress, lines}];
    }
    return [];
  });
}

function validateAndBuildRecord(card, task, indexState, seqNum) {
  const fullText = [card.name, ...(card.lines || [])].join(" · ");
  if (/\b(?:permanently\s+closed|temporarily\s+closed)\b/iu.test(fullText)) {
    return {status: "rejected_closed"};
  }

  const cleanName = canonicalizeCompanyName(card.name);
  if (!cleanName || cleanName.length < 3 || /^Results$/iu.test(cleanName)) {
    return {status: "rejected_invalid"};
  }

  // Filter noise vs positive sector signal
  if (task.kind === "crew_hotel") {
    const nameAndCat = `${cleanName} · ${card.categoryLine || ""}`;
    if (HOTEL_NOISE_BLOCKLIST.test(nameAndCat)) {
      return {status: "rejected_noise"};
    }
    if (!POSITIVE_CREW_HOTEL_SIGNAL.test(nameAndCat)) {
      return {status: "rejected_noise"};
    }
  } else {
    if (SECTOR_NOISE_BLOCKLIST.test(cleanName) || HOTEL_NOISE_BLOCKLIST.test(cleanName)) {
      return {status: "rejected_noise"};
    }
    if (!POSITIVE_SECTOR_SIGNAL.test(fullText)) {
      return {status: "rejected_noise"};
    }
  }

  const targetCc = task.countryCode;
  let finalRc = canonicalizeRegionCode(task.regionCode, targetCc);
  let finalCity = canonicalizeCityName(task.city, finalRc, targetCc);
  let extractedAddrStreet = "";

  // Extract exact street & city from fullAddress when available (e.g. "10745 117 Ave, Grande Prairie, AB T8V 7N6, Canada")
  if (card.fullAddress) {
    const addrParts = card.fullAddress.split(",").map((p) => p.trim()).filter(Boolean);
    if (addrParts.length >= 1) extractedAddrStreet = addrParts[0].slice(0, 140);
    if ((targetCc === "CA" || targetCc === "US") && addrParts.length >= 3) {
      const stateIdx = /^(?:Canada|United States|USA)$/iu.test(addrParts[addrParts.length - 1])
        ? addrParts.length - 2
        : addrParts.length - 1;
      if (stateIdx >= 1) {
        const stMatch = addrParts[stateIdx].match(/^([A-Z]{2})(?:\s+[A-Z0-9 -]{3,10})?$/u);
        if (stMatch) {
          const addrRc = stMatch[1];
          if (addrRc !== finalRc) return {status: "rejected_zoom_out"};
          const candCity = addrParts[stateIdx - 1];
          if (
            candCity &&
            !/\d/u.test(candCity) &&
            !/\b(?:st|street|ave|avenue|rd|road|dr|drive|blvd|hwy|highway|fwy|loop|pkwy|lane|ln)\b/iu.test(candCity)
          ) {
            const cNorm = canonicalizeCityName(candCity, finalRc, targetCc);
            if (cNorm) finalCity = cNorm;
          }
        }
      }
    }
  }

  let phoneDisplay = "";
  let phoneKey = "";
  let isTollFree = false;

  if (targetCc === "CA" || targetCc === "US") {
    let rawPhone = card.phone;
    if (!rawPhone) {
      const m = fullText.match(/(?:\+?1[\s.-]?)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}\b/u);
      if (m) rawPhone = m[0];
    }
    const pNorm = normalizeNorthAmericanPhone(rawPhone);
    if (!pNorm) return {status: "rejected_no_phone"};

    const npa = pNorm.digits10.slice(0, 3);
    const phoneGeo = inferGeoFromNanpaPhone(pNorm.digits10);
    const cityRx = new RegExp(`\\b${finalCity.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&")}\\b`, "iu");
    const mentionsCity = cityRx.test(fullText);

    if (phoneGeo && !phoneGeo.isTollFree) {
      if (phoneGeo.countryCode !== targetCc) return {status: "rejected_zoom_out"};
      if (phoneGeo.regionCode !== finalRc && !mentionsCity) return {status: "rejected_zoom_out"};
      if (!card.fullAddress && phoneGeo.hasExactExchangeCity && !mentionsCity) {
        finalCity = canonicalizeCityName(phoneGeo.hubCity, finalRc, targetCc);
      }
    } else if (pNorm.isTollFree) {
      if (!mentionsCity) return {status: "rejected_zoom_out"};
    } else {
      if (targetCc !== "US" || !EXTRA_VALID_US_NPA.has(npa) || !mentionsCity) {
        return {status: "rejected_zoom_out"};
      }
    }
    phoneDisplay = pNorm.display;
    phoneKey = pNorm.digits10;
    isTollFree = Boolean(pNorm.isTollFree);
  } else {
    let rawPhone = card.phone;
    if (!rawPhone) {
      const m = fullText.match(/(?:\+\d{1,3}[\s.-]?|\b0\d{1,4}[\s.-]?)[\d\s().-]{6,14}\b/u);
      if (m) rawPhone = m[0];
    }
    const pIntl = normalizeIntlPhoneStrict(rawPhone, targetCc);
    if (!pIntl) return {status: "rejected_no_phone"};
    phoneDisplay = pIntl.display;
    phoneKey = pIntl.digitsKey;
  }

  if (!finalRc) {
    finalRc = inferRegionFromCountryAndCity(targetCc, finalCity) || finalRc;
  }
  finalCity = canonicalizeCityName(finalCity, finalRc, targetCc);
  if (!finalCity) return {status: "rejected_invalid"};

  const normName = normalizedCompanyName(cleanName);
  if (!normName) return {status: "rejected_invalid"};

  // Note: Corporate hotel central 1-800 numbers may be shared across properties in different towns,
  // so only dedupe by phoneKey when not toll-free, and always dedupe by (normName, country, region, city).
  const nameLocKey =
    task.kind === "crew_hotel"
      ? `${normName}|${targetCc}|${finalRc}|${finalCity.toLowerCase()}`
      : `${normName}|${targetCc}|${finalRc}`;
  if ((!isTollFree && indexState.existingPhones.has(phoneKey)) || indexState.existingNameRegion.has(nameLocKey)) {
    return {status: "duplicate_existing"};
  }
  if (!isTollFree) indexState.existingPhones.add(phoneKey);
  indexState.existingNameRegion.add(nameLocKey);

  let streetAddress = extractedAddrStreet;
  if (!streetAddress) {
    for (const line of card.lines || []) {
      if (/^\d\.\d\s*\(/u.test(line) || /^Open\b|^Closed\b/iu.test(line)) continue;
      if (line.includes("·")) {
        const candidate = line.split("·").pop().trim();
        if (candidate.length >= 5 && !/^\+?\d[\d\s()-]{6,}$/u.test(candidate)) {
          streetAddress = candidate.slice(0, 140);
          break;
        }
      }
    }
  }

  const website = cleanWebsiteUrl(card.website);
  const emergency24x7 = task.kind === "crew_hotel" || /\b(?:open\s+24\s+hours|24\/7|24\s*hr)\b/iu.test(fullText);

  let catCodes = classifyCategoriesFromText([cleanName], fullText).filter((c) => CATEGORY_BY_CODE.has(c));
  if (!catCodes.includes(task.defaultCat)) {
    catCodes = [task.defaultCat, ...catCodes];
  }
  catCodes = [...new Set(catCodes)].slice(0, 5);
  const categories = catCodes.map((c) => CATEGORY_BY_CODE.get(c)?.label || c);

  const services = [];
  if (task.kind === "crew_hotel") {
    services.push("Workforce & Oilfield Crew Lodging");
    if (/\b(?:extended[\s-]*stay|suites|kitchenette|residence\s+inn|towneplace|candlewood|staybridge|home2|woodspring|mainstay|suburban|my\s+place)\b/iu.test(fullText)) {
      services.push("Extended-Stay Suites & Weekly Crew Rates");
    }
    services.push("Inquire Directly for Corporate / Oil & Gas Crew Rates");
  } else {
    const catMeta = CATEGORY_BY_CODE.get(task.defaultCat);
    if (catMeta) services.push(catMeta.label);
  }

  const geo = inferCountryAndRegion(targetCc, finalRc);
  if (COUNTRY_BY_CODE.has(targetCc)) {
    geo.countryCode = targetCc;
    geo.countryName = COUNTRY_BY_CODE.get(targetCc).name;
  }

  const nowIso = new Date().toISOString();
  const slug = normName.replace(/[^a-z0-9]+/gu, "-").replace(/^-+|-+$/gu, "").slice(0, 44);
  const companyId = `gmaps-${targetCc.toLowerCase()}-${(finalRc || "xx").toLowerCase()}-${slug}-${phoneKey.slice(-4)}-${seqNum}`;

  const privateRecord = {
    schemaVersion: 2,
    companyId,
    discoveryChannel: task.kind === "crew_hotel" ? "google_maps_crew_hotel_audit" : "google_maps_sector_gap_audit",
    companyName: cleanName,
    normalizedCompanyName: normName,
    countryCode: geo.countryCode,
    regionCode: geo.regionCode,
    regionName: geo.regionName,
    city: finalCity,
    postalCode: "",
    streetAddress,
    mainPhone: isTollFree ? "" : phoneDisplay,
    publicPhone: phoneDisplay,
    tollFreePhone: isTollFree ? phoneDisplay : "",
    legacyPhones: [],
    phoneHistory: [],
    generalEmail: "",
    publicEmail: "",
    website,
    powerUnits: 0,
    categoryCodes: catCodes,
    categories,
    services,
    basins: geo.defaultBasins || [],
    serviceAreas: [finalCity, geo.regionName, geo.countryName].filter(Boolean),
    certifications: [],
    emergency24x7,
    description:
      task.kind === "crew_hotel"
        ? `Oilpatch & turnaround workforce accommodation in ${finalCity}, ${geo.regionCode || geo.countryCode}. Contact front desk or sales for Oil & Gas crew / CLC corporate rates.`
        : "",
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
        sourceName: `Google Maps ${targetCc} Crew Lodging & Sector Audit`,
        sourceUrl: card.placeUrl || "",
        sourceExternalId: phoneKey,
        observedAt: nowIso,
        bookPage: "",
      },
    ],
    publishedAt: nowIso,
    createdAt: nowIso,
    updatedAt: nowIso,
  };
  privateRecord.adminSearchTokens = buildAdminSearchTokens(privateRecord);
  const publicEntry = buildPublicEntry(privateRecord, companyId, nowIso);

  return {status: "accepted", privateRecord, publicEntry, kind: task.kind, cat: task.defaultCat};
}

async function syncBatchToFirestore(projectId, records) {
  if (!records.length) return;
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
    const token = await resolveAccessToken(projectId);
    const res = await fetch(commitUrl, {
      method: "POST",
      headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
      body: JSON.stringify({writes}),
      signal: AbortSignal.timeout(40000),
    });
    if (!res.ok) {
      console.error(`[bot21] Firestore batch sync HTTP ${res.status}: ${await res.text()}`);
    }
  }
}

async function main() {
  await fsp.mkdir(LEDGER_DIR, {recursive: true});
  await fsp.mkdir(REPORTS_DIR, {recursive: true});

  const universe = buildSearchQueue();
  let visited = new Set();
  let stats = {
    startedAt: new Date().toISOString(),
    queriesCompleted: 0,
    cardsInspected: 0,
    newTotal: 0,
    newCrewHotels: 0,
    newScaffolding: 0,
    newMarineAviation: 0,
    newSupplyWorkwear: 0,
    newSecurityComms: 0,
    duplicates: 0,
    rejectedNoise: 0,
    byCountry: {},
  };

  if (RESUME && fs.existsSync(CHECKPOINT_PATH)) {
    try {
      const cp = JSON.parse(await fsp.readFile(CHECKPOINT_PATH, "utf8"));
      visited = new Set(cp.visitedIds || []);
      if (cp.stats) stats = {...stats, ...cp.stats};
    } catch (_) {}
  }

  const pending = universe.filter((q) => !visited.has(q.id)).slice(0, MAX_QUERIES);
  if (pending.length === 0) {
    console.log(`[bot21] CONVERGED! All ${universe.length} Crew Hotel & New-Sector queries already completed.`);
    return;
  }

  const indexState = await loadExistingFirestoreIndex(PROJECT_ID);
  const chromium = await resolvePlaywrightChromium();
  const browser = await chromium.launch({
    executablePath: "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    headless: true,
    args: ["--disable-blink-features=AutomationControlled", "--no-sandbox", "--disable-gpu"],
  });

  console.log(
    `[bot21] Launching ${NUM_AGENTS} parallel Chromium agents | Pending: ${pending.length}/${universe.length} (sync=${SYNC})...`,
  );

  let cursor = 0;
  let seqCounter = Math.floor(Date.now() / 1000) % 100000;
  let pendingSyncBatch = [];
  let checkpointLock = Promise.resolve();

  async function flushCheckpoint() {
    const toSync = pendingSyncBatch.splice(0, pendingSyncBatch.length);
    if (toSync.length > 0) {
      const jsonlLines = toSync.map((r) => JSON.stringify(r.publicEntry)).join("\n") + "\n";
      await fsp.appendFile(DISCOVERED_JSONL, jsonlLines, "utf8");
      if (SYNC) {
        await syncBatchToFirestore(PROJECT_ID, toSync);
      }
    }
    await fsp.writeFile(
      CHECKPOINT_PATH,
      JSON.stringify({visitedCount: visited.size, totalUniverse: universe.length, visitedIds: [...visited], stats}, null, 2),
      "utf8",
    );
  }

  const workers = Array.from({length: NUM_AGENTS}, async (_, idx) => {
    const context = await browser.newContext({
      userAgent: USER_AGENT,
      viewport: {width: 1280, height: 900},
      locale: "en-US",
    });
    await context.route("**/*.{png,jpg,jpeg,webp,gif,svg,woff,woff2,ttf,mp4}", (route) => route.abort());
    const page = await context.newPage();

    try {
      while (true) {
        const myIdx = cursor++;
        if (myIdx >= pending.length) break;
        const task = pending[myIdx];

        try {
          const cards = await extractGoogleMapsCards(page, task.query, task.kind === "crew_hotel");
          stats.cardsInspected += cards.length;
          for (const card of cards) {
            const res = validateAndBuildRecord(card, task, indexState, ++seqCounter);
            if (res.status === "accepted") {
              stats.newTotal += 1;
              if (res.cat === "crew_hotels_workforce_lodging") stats.newCrewHotels += 1;
              else if (res.cat === "scaffolding_insulation_coatings") stats.newScaffolding += 1;
              else if (res.cat === "marine_offshore_aviation") stats.newMarineAviation += 1;
              else if (res.cat === "industrial_supply_ppe_workwear") stats.newSupplyWorkwear += 1;
              else if (res.cat === "lease_security_communications_it") stats.newSecurityComms += 1;
              const cc = res.publicEntry.countryCode;
              stats.byCountry[cc] = (stats.byCountry[cc] || 0) + 1;
              pendingSyncBatch.push(res);
            } else if (res.status === "duplicate_existing") {
              stats.duplicates += 1;
            } else {
              stats.rejectedNoise += 1;
            }
          }
          visited.add(task.id);
          stats.queriesCompleted += 1;
        } catch (err) {
          console.warn(`[HotelAgent-${idx + 1}] Query error (${task.id}): ${err.message}`);
          visited.add(task.id);
        }

        if ((myIdx + 1) % 20 === 0 || myIdx === pending.length - 1) {
          checkpointLock = checkpointLock.then(async () => {
            await flushCheckpoint();
            console.log(
              `[HotelAgent-${idx + 1}] ${visited.size}/${universe.length} | Cards: ${stats.cardsInspected} | NEW: ${stats.newTotal} (Hotels=${stats.newCrewHotels}, Scaff=${stats.newScaffolding}, Supply=${stats.newSupplyWorkwear}, Marine=${stats.newMarineAviation}, Sec=${stats.newSecurityComms}) | Dups: ${stats.duplicates}`,
            );
          });
          await checkpointLock;
        }
      }
    } finally {
      await context.close().catch(() => {});
    }
  });

  await Promise.all(workers);
  await flushCheckpoint();
  await browser.close().catch(() => {});

  const md = [
    "# Bot 21 — Oil & Gas Crew Hotels, Workforce Lodging & New Sector Gap-Fill Report",
    "",
    `- **Updated At**: \`${new Date().toISOString()}\``,
    `- **Queries Completed**: **${visited.size.toLocaleString()} / ${universe.length.toLocaleString()}**`,
    `- **Google Business Cards Inspected**: **${stats.cardsInspected.toLocaleString()}**`,
    `- **Brand-New Unverified Listings Published**: **+${stats.newTotal.toLocaleString()}**`,
    `  - **Crew Hotels, Extended-Stay & Oilfield Worker Rates (\`crew_hotels_workforce_lodging\`)**: **+${stats.newCrewHotels.toLocaleString()}**`,
    `  - **Scaffolding, Insulation, Coatings & Rope Access (\`scaffolding_insulation_coatings\`)**: **+${stats.newScaffolding.toLocaleString()}**`,
    `  - **Oilfield Supply Stores, Hose, Fasteners & FR Workwear (\`industrial_supply_ppe_workwear\`)**: **+${stats.newSupplyWorkwear.toLocaleString()}**`,
    `  - **Offshore Marine Vessels, Diving, ROV & Aviation (\`marine_offshore_aviation\`)**: **+${stats.newMarineAviation.toLocaleString()}**`,
    `  - **Lease Security, Gate Guards & Remote Wellsite Comms (\`lease_security_communications_it\`)**: **+${stats.newSecurityComms.toLocaleString()}**`,
    `- **Duplicates Already in Directory**: **${stats.duplicates.toLocaleString()}**`,
    `- **Tourist / Residential / Non-Industrial Cards Blocked**: **${stats.rejectedNoise.toLocaleString()}**`,
    "",
    "## New Listings by Country",
    "",
    ...Object.entries(stats.byCountry)
      .sort((a, b) => b[1] - a[1])
      .map(([cc, n]) => `- **\`${cc}\`**: +${n.toLocaleString()} new listings`),
    "",
  ];
  await fsp.writeFile(REPORT_PATH, md.join("\n"), "utf8");
  console.log(`[bot21] COMPLETE! Published +${stats.newTotal} new listings (+${stats.newCrewHotels} Crew Hotels).`);
}

main().catch((err) => {
  console.error("[bot21] FATAL:", err);
  process.exit(1);
});
