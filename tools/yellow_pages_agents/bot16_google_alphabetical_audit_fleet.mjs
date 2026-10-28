#!/usr/bin/env node
/**
 * Bot 16 — Multi-Agent Google Maps & Web Alphabetical (A–Z) Oil & Gas + Training Audit Fleet
 *
 * Supports two full geographic scopes (`--scope north_america` [default] or `--scope international`):
 *
 *   A) North America (`--scope north_america`):
 *      - Stage 1: CANADA (`CA` — AB, BC, SK, MB, NL, NS, ON, NB, NT) A -> Z + All 25 Sectors + Training
 *      - Stage 2: USA (`US` — TX, ND, OK, LA, NM, WY, CO, PA, WV, OH, CA, AK, MT, UT, KS, AR, MS) A -> Z + All 25 Sectors + Training
 *
 *   B) International Oil & Gas & Training Hubs (`--scope international`, optional `--corridor <name>`):
 *      - Corridor 1 (`uk_norway`): UK (`GB`), Norway (`NO`), Netherlands (`NL`), Germany (`DE`) — North Sea, Norwegian & Barents Sea
 *      - Corridor 2 (`middle_east`): UAE (`AE`), Saudi Arabia (`SA`), Qatar (`QA`), Oman (`OM`), Kuwait (`KW`), Bahrain (`BH`) — Arabian Basin
 *      - Corridor 3 (`latin_america`): Brazil (`BR`), Mexico (`MX`), Argentina (`AR`), Colombia (`CO`), Guyana (`GY`), Trinidad & Tobago (`TT`)
 *      - Corridor 4 (`australia`): Australia (`AU` — WA, QLD, NT, SA, VIC) — North West Shelf, Surat/Bowen, Cooper, Bonaparte, Gippsland
 *      - Corridor 5 (`africa`): Nigeria (`NG`), Angola (`AO`), Egypt (`EG`), Ghana (`GH`), Algeria (`DZ`), South Africa (`ZA`), Namibia (`NA`), Mozambique (`MZ`), Gabon (`GA`), Congo (`CG`), Cote d'Ivoire (`CI`), Senegal (`SN`), Uganda (`UG`), Tanzania (`TZ`), Libya (`LY`)
 *      - Corridor 6 (`asia_caspian`): Singapore (`SG`), Malaysia (`MY`), Indonesia (`ID`), Brunei (`BN`), Thailand (`TH`), Vietnam (`VN`), Kazakhstan (`KZ`), Azerbaijan (`AZ`), India (`IN`)
 *
 * Strict Schema & Hygiene Guarantees:
 *   - Rejects permanently/temporarily closed listings (and unpublishes any existing live entry found closed).
 *   - Rejects retail gas/petrol stations, auto lube shops, residential services, and non-industrial consumer schools.
 *   - Enforces NANPA area-code (North America) and ITU Country Dial-Code + True-Hub Geo-Resolution (International)
 *     so Google Maps zoom-outs never misassign countries, regions, or cities.
 *   - Passes every `companyName`, `city`, `regionCode`, `countryCode`, `publicPhone`, `website`, `basins`,
 *     and `categoryCodes` (including `oil_gas_training_courses`) through canonical taxonomy validators.
 *   - NEVER pre-verifies (`verificationStatus: "unverified"`, `listingTier: "free_basic"`, `verified: false`).
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
  normalizeCityKey,
} = require("../../firebase/functions/yellow_pages_taxonomy.js");
const {
  buildAdminSearchTokens,
  buildPublicEntry,
  normalizeGlobalPhone,
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
const REFRESH_INDEX = args.includes("--refresh-index");
const INCLUDE_TRAINING_CODE = !args.includes("--legacy-24-cats");
const scopeIdx = args.indexOf("--scope");
const SCOPE =
  scopeIdx !== -1 && String(args[scopeIdx + 1] || "").toLowerCase().startsWith("int")
    ? "international"
    : args.includes("--international")
      ? "international"
      : "north_america";
const corridorIdx = args.indexOf("--corridor");
const CORRIDOR_FILTER = corridorIdx !== -1 ? String(args[corridorIdx + 1] || "").toLowerCase() : "";
const agentsIdx = args.indexOf("--agents");
const NUM_AGENTS = agentsIdx !== -1 ? Math.max(1, Math.min(24, Number(args[agentsIdx + 1] || 16))) : 16;
const maxQueriesIdx = args.indexOf("--max-queries");
const MAX_QUERIES = maxQueriesIdx !== -1 ? Number(args[maxQueriesIdx + 1] || 700) : 700;
const countryOnlyIdx = args.indexOf("--country");
const COUNTRY_FILTER = countryOnlyIdx !== -1 ? String(args[countryOnlyIdx + 1] || "").toUpperCase() : "";
const projIdx = args.indexOf("--project");
const PROJECT_ID = projIdx !== -1 && args[projIdx + 1] ? args[projIdx + 1] : "flutter-flow-pipe";

const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

const CONSUMER_NOISE_BLOCKLIST =
  /\b(?:gas station|petrol station|petrol pump|filling station|fuel station|bensinstasjon|tankstation|tankstelle|station-service|posto de combust[ií]vel|posto ipiranga|posto br|sonangol posto|gasolinera|estaci[oó]n de servicio|spbu|kedai mesra|petronas station|totalenergies station|oando station|conoil station|mrs oil station|bovas|ardova|rubis station|engen garage|sasol garage|caltex station|astron energy|puma energy station|ptt station|petrolimex|hp petrol pump|indian oil petrol|bharat petroleum pump|cng pump|lpg cylinder|convenience store|service station|truck stop|car wash|auto oil change|oil change service|engine oil shop|lube shop|tyre shop|jiffy lube|mr\.?\s*lube|great canadian oil change|valvoline instant|take 5 oil|grease monkey|midas|meineke|kal tire|fountain tire|canadian tire|walmart|costco|7-eleven|circle k|esso|petro-canada|shell station|chevron station|mobil station|exxon station|husky|co-op gas|love's travel|pilot travel|flying j|buc-ee|quiktrip|wawa|hair|beauty|barber|nail|spa|aromatherapy|essential oil|olive oil|cooking oil|palm oil|coconut oil|edible oil|mustard oil|vegetable oil|cbd oil|massage|yoga|pilates|martial arts|karate|taekwondo|dance|music school|driving school|ielts|toefl|spoken english|coaching classes|tuition centre|kumon|sylvan learning|mathnasium|tutoring|daycare|preschool|montessori|primary school|high school|dog training|pet|real estate|mortgage|dental|dentist|chiropractic|optometrist|pharmacy|restaurant|pizza|cafe|coffee|bakery|hotel|motel|inn|church|mosque|cathedral|temple|fitness|gym|crossfit|hunter safety|wilderness survival|aviation learning|scout aviation|allcpr|hero for life|mind body|dole accredited|saferphilippines|1philsafe|feati maritime|bacoor branch|supermarket|grocery|tailor|boutique)\b/iu;

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

const POSITIVE_OILFIELD_OR_TRAINING_SIGNAL =
  /\b(?:oilfield|oil\s*&\s*gas|oil\s+and\s+gas|petroleum|petr[oó]leo|p[eé]trolier|[oó]leo\s+e\s+g[aá]s|olje|gass|migas|minyak\s+dan\s+gas|perminyakan|dầu\s+khí|нефтегаз|нефть|бурение|скважин|neft|qazma|offshore|onshore|subsea|lepas\s+pantai|energy|energ[ií]a|[eé]nergie|drilling|perfura[cç][aã]o|perforaci[oó]n|forage|pengeboran|khoan|boring|br[øo]nn|well\s+service|well\s+intervention|workover|wireline|slickline|coiled\s+tubing|frac|fracturing|cementing|completions|wellhead|valve|bop|pressure\s+control|octg|casing|tubing|tubular|pipe|pipeline|midstream|upstream|fpso|fso|epci|epcm|hydrovac|vac\s+truck|vacuum\s+truck|water\s+hauling|fluid\s+hauling|winch|heavy\s+haul|heavy\s+lift|levage|rig\s+mov|bed\s+truck|hot\s*shot|pilot\s+car|crane|picker|rigging|lifting|welding|soudure|b-pressure|fabrication|shipyard|marine\s+engineering|machine\s+shop|ndt|non-destructive|inspection|inspe[cç][aã]o|inspecci[oó]n|artificial\s+lift|pumpjack|compressor|compression|turbomachinery|tank|vessel|treater|separator|boiler|rental|downhole|fishing\s+tool|rig\s+mat|access\s+mat|lease\s+construction|earthwork|scada|instrumentation|automation|rov|oilfield\s+electrical|h2s|hse|industrial\s+medic|safety|seguridad\s+industrial|seguran[cç]a|s[eé]curit[eé]|sikkerhet|fire\s+watch|remediation|reclamation|decommissioning|environmental|disposal|mud|drilling\s+fluid|chemical|lubricant|bunkering|bulk\s+fuel|heavy\s+duty\s+mechanic|hydraulics|remote\s+camp|offshore\s+catering|wellsite\s+trailer|surveying|geomatics|seismic|geophysical|line\s+locat|training|courses|treinamento|capacitaci[oó]n|formation|pelatihan|kurssenter|sikkerhetssenter|academy|institute|polytechnic|college|well\s+control|iwcf|wellsharp|iadc|opito|bosiet|foet|huet|cbsp|t-bosiet|irata|nebosh|niosh|gwo|nopsema|safeland|veriforce|rigpass|confined\s+space|fall\s+protection|ground\s+disturbance|class\s+1|cdl\s+training)\b/iu;

const AGGREGATOR_DOMAIN_BLOCKLIST =
  /(?:google\.|gstatic\.|ggpht\.|facebook\.|instagram\.|linkedin\.|youtube\.|twitter\.|x\.com|yelp\.|yellowpages\.|yp\.ca|411\.ca|bbb\.org|mapquest\.|manta\.|cossd\.com|indeed\.|glassdoor\.|dnb\.com|zoominfo\.|chamberofcommerce\.|yell\.com|1881\.no|gulesider\.no|paginasamarillas\.|apontador\.com\.br|truelocal\.com\.au|indiamart\.com|justdial\.com|vconnect\.com|businesslist\.com\.ng|streetdirectory\.com)/iu;

// Strict ITU country dial rules for International Scope anti-zoom-out verification
const INTL_COUNTRY_PHONE_RULES = {
  // Corridor 1: UK / Norway & North Sea
  GB: {dial: "44", minNat: 9, maxNat: 10, countryRx: /\b(?:UK|United Kingdom|Scotland|England|Wales|AB\d{1,2}|NR\d{1,2}|TS\d{1,2}|NE\d{1,2}|HU\d{1,2})\b/iu},
  NO: {dial: "47", minNat: 8, maxNat: 8, countryRx: /\b(?:Norway|Norge|Stavanger|Tananger|Forus|Sandnes|Bergen|Oslo|Hammerfest|Kristiansund|\d{4}\s+[A-ZÆØÅ])/iu},
  NL: {dial: "31", minNat: 9, maxNat: 9, countryRx: /\b(?:Netherlands|Nederland|Rotterdam|Den Helder|IJmuiden|Groningen|Emmen|\d{4}\s*[A-Z]{2})\b/iu},
  DE: {dial: "49", minNat: 8, maxNat: 11, countryRx: /\b(?:Germany|Deutschland|Celle|Lingen|Hamburg|\b\d{5}\s+[A-ZÄÖÜ])/iu},
  // Corridor 2: Middle East
  AE: {dial: "971", minNat: 8, maxNat: 9, countryRx: /\b(?:UAE|United Arab Emirates|Abu Dhabi|Mussafah|Musaffah|Ruwais|Dubai|Jebel Ali|Sharjah|Hamriyah|Fujairah|Ras Al Khaimah)\b/iu},
  SA: {dial: "966", minNat: 8, maxNat: 9, countryRx: /\b(?:Saudi Arabia|KSA|Dammam|Khobar|Al Khobar|Dhahran|Jubail|Ras Tanura|Abqaiq|Riyadh|Yanbu|Jeddah)\b/iu},
  QA: {dial: "974", minNat: 8, maxNat: 8, countryRx: /\b(?:Qatar|Doha|Ras Laffan|Mesaieed|Al Khor|Al Wakrah)\b/iu},
  OM: {dial: "968", minNat: 8, maxNat: 8, countryRx: /\b(?:Oman|Muscat|Sohar|Duqm|Nizwa|Ruwi|Ghala|Azaiba|Al Khuwair)\b/iu},
  KW: {dial: "965", minNat: 8, maxNat: 8, countryRx: /\b(?:Kuwait|Ahmadi|Al Ahmadi|Shuaiba|Fahaheel|Safat|Sharq)\b/iu},
  BH: {dial: "973", minNat: 8, maxNat: 8, countryRx: /\b(?:Bahrain|Manama|Sitra|Awali|Hidd|Juffair)\b/iu},
  // Corridor 3: Latin America & Caribbean
  BR: {dial: "55", minNat: 10, maxNat: 11, countryRx: /\b(?:Brazil|Brasil|Maca[eé]|Rio de Janeiro|Niter[oó]i|Rio das Ostras|Campos|Santos|S[aã]o Paulo|Vit[oó]ria|Salvador|Cama[cç]ari|\bRJ\b|\bSP\b|\bES\b|\bBA\b|\d{5}-\d{3})\b/iu},
  MX: {dial: "52", minNat: 10, maxNat: 10, countryRx: /\b(?:Mexico|M[eé]xico|Villahermosa|Para[ií]so|Comalcalco|Ciudad del Carmen|Carmen|Reynosa|Tampico|Altamira|Coatzacoalcos|Poza Rica|Veracruz|Monterrey|Tabasco|Campeche|Tamaulipas)\b/iu},
  AR: {dial: "54", minNat: 8, maxNat: 11, countryRx: /\b(?:Argentina|Neuqu[eé]n|A[ñn]elo|Centenario|Rinc[oó]n de los Sauces|Comodoro Rivadavia|Caleta Olivia|Buenos Aires|Bah[ií]a Blanca|Chubut)\b/iu},
  CO: {dial: "57", minNat: 7, maxNat: 10, countryRx: /\b(?:Colombia|Bogot[aá]|Barrancabermeja|Yopal|Villavicencio|Cartagena|Santander|Casanare|Meta)\b/iu},
  GY: {dial: "592", minNat: 7, maxNat: 7, countryRx: /\b(?:Guyana|Georgetown|Demerara|East Bank|Eccles|Houston)\b/iu},
  TT: {dial: "1868", minNat: 7, maxNat: 10, countryRx: /\b(?:Trinidad|Tobago|San Fernando|Point Lisas|Couva|La Brea|Point Fortin|Port of Spain|Chaguaramas|Marabella)\b/iu},
  // Corridor 4: Australia
  AU: {dial: "61", minNat: 9, maxNat: 10, countryRx: /\b(?:Australia|Perth|Welshpool|Henderson|Kewdale|Karratha|Dampier|Port Hedland|Onslow|Brisbane|Toowoomba|Roma|Chinchilla|Gladstone|Darwin|Adelaide|Moomba|Melbourne|Sale|\bWA\b|\bQLD\b|\bNT\b|\bSA\b|\bVIC\b)\b/iu},
  // Corridor 5: Africa (West, North, East & Southern Africa Energy Basins)
  NG: {dial: "234", minNat: 8, maxNat: 10, countryRx: /\b(?:Nigeria|Port Harcourt|Trans[\s-]*Amadi|Onne|Rivers State|Lagos|Victoria Island|Lekki|Ikoyi|Apapa|Warri|Effurun|Delta State|Eket|Akwa Ibom|Abuja)\b/iu},
  AO: {dial: "244", minNat: 9, maxNat: 9, countryRx: /\b(?:Angola|Luanda|Talatona|Belas|Sonils|Viana|Cabinda|Malongo|Soyo|Zaire|Lobito|Benguela)\b/iu},
  EG: {dial: "20", minNat: 8, maxNat: 10, countryRx: /\b(?:Egypt|Cairo|Maadi|New Cairo|Nasr City|Heliopolis|Katameya|Giza|Alexandria|Amreya|Abu Qir|Suez|Ain Sokhna|Port Said|Ras Gharib|Red Sea)\b/iu},
  GH: {dial: "233", minNat: 9, maxNat: 9, countryRx: /\b(?:Ghana|Takoradi|Sekondi|Western Region|Accra|Airport Residential|East Legon|Tema)\b/iu},
  DZ: {dial: "213", minNat: 8, maxNat: 9, countryRx: /\b(?:Algeria|Alg[eé]rie|Hassi Messaoud|Ouargla|Algiers|Alger|Hydra|Oran|Arzew|Skikda)\b/iu},
  ZA: {dial: "27", minNat: 9, maxNat: 9, countryRx: /\b(?:South Africa|Cape Town|Saldanha|Paarden Eiland|Montague Gardens|Bellville|Durban|Umhlanga|Richards Bay|Johannesburg|Sandton|Midrand|Secunda)\b/iu},
  NA: {dial: "264", minNat: 8, maxNat: 9, countryRx: /\b(?:Namibia|Walvis Bay|Swakopmund|Erongo|L[üu]deritz|Windhoek)\b/iu},
  MZ: {dial: "258", minNat: 8, maxNat: 9, countryRx: /\b(?:Mozambique|Mo[cç]ambique|Maputo|Matola|Pemba|Cabo Delgado|Afungi|Beira)\b/iu},
  GA: {dial: "241", minNat: 7, maxNat: 9, countryRx: /\b(?:Gabon|Port[\s-]*Gentil|Libreville|Owendo)\b/iu},
  CG: {dial: "242", minNat: 9, maxNat: 9, countryRx: /\b(?:Congo|Pointe[\s-]*Noire|Brazzaville)\b/iu},
  CI: {dial: "225", minNat: 8, maxNat: 10, countryRx: /\b(?:C[oô]te d'Ivoire|Ivory Coast|Abidjan|Treichville|Marcory|Cocody|Port[\s-]*Bou[eë]t)\b/iu},
  SN: {dial: "221", minNat: 9, maxNat: 9, countryRx: /\b(?:Senegal|S[eé]n[eé]gal|Dakar|Almadies|Plateau)\b/iu},
  UG: {dial: "256", minNat: 9, maxNat: 9, countryRx: /\b(?:Uganda|Kampala|Kololo|Bugolobi|Nakasero|Hoima|Buliisa|Entebbe)\b/iu},
  TZ: {dial: "255", minNat: 9, maxNat: 9, countryRx: /\b(?:Tanzania|Dar es Salaam|Masaki|Mikocheni|Mtwara|Tanga)\b/iu},
  LY: {dial: "218", minNat: 8, maxNat: 10, countryRx: /\b(?:Libya|Tripoli|Janzour|Hay Al Andalus|Benghazi|Misrata|Brega|Ras Lanuf)\b/iu},
  // Corridor 6: Southeast, South & Central (Caspian) Asia
  SG: {dial: "65", minNat: 8, maxNat: 8, countryRx: /\b(?:Singapore|Tuas|Jurong|Pioneer|Benoi|Gul Circle|Loyang|Changi|Woodlands|Ubi|Suntec)\b/iu},
  MY: {dial: "60", minNat: 8, maxNat: 10, countryRx: /\b(?:Malaysia|Kuala Lumpur|KLCC|Petaling Jaya|Shah Alam|Subang|Klang|Selangor|Miri|Bintulu|Sarawak|Labuan|Kota Kinabalu|Sabah|Kemaman|Kerteh|Terengganu|Johor Bahru|Pasir Gudang|Pengerang)\b/iu},
  ID: {dial: "62", minNat: 8, maxNat: 12, countryRx: /\b(?:Indonesia|Jakarta|Cilandak|Simatupang|Kuningan|Bekasi|Cikarang|Balikpapan|Kalimantan|Samarinda|Batam|Batu Ampar|Kabil|Kepulauan Riau|Duri|Pekanbaru|Riau|Surabaya|Gresik|Jawa Timur)\b/iu},
  BN: {dial: "673", minNat: 7, maxNat: 7, countryRx: /\b(?:Brunei|Kuala Belait|Seria|Lumut|Bandar Seri Begawan|Gadong|Muara)\b/iu},
  TH: {dial: "66", minNat: 8, maxNat: 9, countryRx: /\b(?:Thailand|Rayong|Map Ta Phut|Chonburi|Sattahip|Laem Chabang|Songkhla|Singhanakhon|Bangkok)\b/iu},
  VN: {dial: "84", minNat: 8, maxNat: 10, countryRx: /\b(?:Vietnam|Vi[eệ]t Nam|Vung Tau|Vũng Tàu|B[aà] R[iị]a|Ho Chi Minh|TP\.?\s*HCM|Saigon|Th[uủ] Đ[uứ]c)\b/iu},
  KZ: {dial: "77", minNat: 9, maxNat: 9, countryRx: /\b(?:Kazakhstan|Казахстан|Atyrau|Атырау|Tengiz|Aktau|Актау|Mangystau|Uralsk|Oral|Уральск|Aksai|Аксай|Almaty|Алматы)\b/iu},
  AZ: {dial: "994", minNat: 9, maxNat: 9, countryRx: /\b(?:Azerbaijan|Azərbaycan|Baku|Bak[ıi]|Sabail|Khatai|Narimanov|Garadagh|Qaradağ|Sangachal|Sumqay[ıi]t)\b/iu},
  IN: {dial: "91", minNat: 10, maxNat: 10, countryRx: /\b(?:India|Mumbai|Navi Mumbai|Andheri|Powai|Thane|Maharashtra|Kakinada|Visakhapatnam|Andhra Pradesh|Vadodara|Baroda|Surat|Hazira|Ankleshwar|Ahmedabad|Gujarat|Duliajan|Dibrugarh|Assam)\b/iu},
};

const WRONG_COUNTRY_BLOCK_NAMES = {
  United_States: "US",
  USA: "US",
  Canada: "CA",
  United_Kingdom: "GB",
  Russia: "RU",
  India: "IN",
  Philippines: "PH",
  Pakistan: "PK",
  Nigeria: "NG",
  China: "CN",
  South_Africa: "ZA",
  Singapore: "SG",
  Malaysia: "MY",
  Indonesia: "ID",
};

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

// International Oil & Gas + Training Hubs ordered: UK / Norway -> Middle East -> Latin America -> Australia
const INTERNATIONAL_HUBS = [
  // 1. UK / Norway & North Sea
  {corridor: "uk_norway", city: "Aberdeen", regionCode: "SCT", countryCode: "GB", countryLabel: "Scotland, UK", tier: 1, alpha: true},
  {corridor: "uk_norway", city: "Dyce", regionCode: "SCT", countryCode: "GB", countryLabel: "Aberdeen, UK", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Westhill", regionCode: "SCT", countryCode: "GB", countryLabel: "Aberdeenshire, UK", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Altens", regionCode: "SCT", countryCode: "GB", countryLabel: "Aberdeen, UK", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Peterhead", regionCode: "SCT", countryCode: "GB", countryLabel: "Scotland, UK", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Montrose", regionCode: "SCT", countryCode: "GB", countryLabel: "Scotland, UK", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Dundee", regionCode: "SCT", countryCode: "GB", countryLabel: "Scotland, UK", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Invergordon", regionCode: "SCT", countryCode: "GB", countryLabel: "Scotland, UK", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Edinburgh", regionCode: "SCT", countryCode: "GB", countryLabel: "Scotland, UK", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Glasgow", regionCode: "SCT", countryCode: "GB", countryLabel: "Scotland, UK", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Lerwick", regionCode: "SCT", countryCode: "GB", countryLabel: "Shetland, UK", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Great Yarmouth", regionCode: "ENG", countryCode: "GB", countryLabel: "UK", tier: 1, alpha: true},
  {corridor: "uk_norway", city: "Lowestoft", regionCode: "ENG", countryCode: "GB", countryLabel: "UK", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Norwich", regionCode: "ENG", countryCode: "GB", countryLabel: "UK", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Middlesbrough", regionCode: "ENG", countryCode: "GB", countryLabel: "Teesside, UK", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Stockton-on-Tees", regionCode: "ENG", countryCode: "GB", countryLabel: "UK", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Newcastle upon Tyne", regionCode: "ENG", countryCode: "GB", countryLabel: "UK", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Blyth", regionCode: "ENG", countryCode: "GB", countryLabel: "Northumberland, UK", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Hull", regionCode: "ENG", countryCode: "GB", countryLabel: "UK", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Immingham", regionCode: "ENG", countryCode: "GB", countryLabel: "UK", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "London", regionCode: "ENG", countryCode: "GB", countryLabel: "UK", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Stavanger", regionCode: "RO", countryCode: "NO", countryLabel: "Norway", tier: 1, alpha: true},
  {corridor: "uk_norway", city: "Tananger", regionCode: "RO", countryCode: "NO", countryLabel: "Norway", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Forus", regionCode: "RO", countryCode: "NO", countryLabel: "Stavanger, Norway", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Sandnes", regionCode: "RO", countryCode: "NO", countryLabel: "Norway", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Haugesund", regionCode: "RO", countryCode: "NO", countryLabel: "Norway", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Bergen", regionCode: "VL", countryCode: "NO", countryLabel: "Norway", tier: 1, alpha: true},
  {corridor: "uk_norway", city: "Ågotnes", regionCode: "VL", countryCode: "NO", countryLabel: "Norway", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Mongstad", regionCode: "VL", countryCode: "NO", countryLabel: "Norway", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Florø", regionCode: "VL", countryCode: "NO", countryLabel: "Norway", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Oslo", regionCode: "OS", countryCode: "NO", countryLabel: "Norway", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Asker", regionCode: "OS", countryCode: "NO", countryLabel: "Norway", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Kongsberg", regionCode: "OS", countryCode: "NO", countryLabel: "Norway", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Kristiansund", regionCode: "TR", countryCode: "NO", countryLabel: "Norway", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Hammerfest", regionCode: "TR", countryCode: "NO", countryLabel: "Norway", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "Rotterdam", regionCode: "ZH", countryCode: "NL", countryLabel: "Netherlands", tier: 1, alpha: true},
  {corridor: "uk_norway", city: "Den Helder", regionCode: "NH", countryCode: "NL", countryLabel: "Netherlands", tier: 1, alpha: false},
  {corridor: "uk_norway", city: "IJmuiden", regionCode: "NH", countryCode: "NL", countryLabel: "Netherlands", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Emmen", regionCode: "GR", countryCode: "NL", countryLabel: "Netherlands", tier: 2, alpha: false},
  {corridor: "uk_norway", city: "Celle", regionCode: "NI", countryCode: "DE", countryLabel: "Germany", tier: 1, alpha: false},

  // 2. Middle East
  {corridor: "middle_east", city: "Abu Dhabi", regionCode: "AZ", countryCode: "AE", countryLabel: "UAE", tier: 1, alpha: true},
  {corridor: "middle_east", city: "Mussafah", regionCode: "AZ", countryCode: "AE", countryLabel: "Abu Dhabi, UAE", tier: 1, alpha: true},
  {corridor: "middle_east", city: "Ruwais", regionCode: "AZ", countryCode: "AE", countryLabel: "Abu Dhabi, UAE", tier: 2, alpha: false},
  {corridor: "middle_east", city: "Dubai", regionCode: "DU", countryCode: "AE", countryLabel: "UAE", tier: 1, alpha: true},
  {corridor: "middle_east", city: "Jebel Ali", regionCode: "DU", countryCode: "AE", countryLabel: "Dubai, UAE", tier: 1, alpha: false},
  {corridor: "middle_east", city: "Sharjah", regionCode: "SH", countryCode: "AE", countryLabel: "UAE", tier: 1, alpha: false},
  {corridor: "middle_east", city: "Hamriyah", regionCode: "SH", countryCode: "AE", countryLabel: "Sharjah, UAE", tier: 2, alpha: false},
  {corridor: "middle_east", city: "Fujairah", regionCode: "FU", countryCode: "AE", countryLabel: "UAE", tier: 1, alpha: false},
  {corridor: "middle_east", city: "Dammam", regionCode: "EP", countryCode: "SA", countryLabel: "Saudi Arabia", tier: 1, alpha: true},
  {corridor: "middle_east", city: "Al Khobar", regionCode: "EP", countryCode: "SA", countryLabel: "Saudi Arabia", tier: 1, alpha: true},
  {corridor: "middle_east", city: "Dhahran", regionCode: "EP", countryCode: "SA", tier: 1, countryLabel: "Saudi Arabia", alpha: false},
  {corridor: "middle_east", city: "Jubail", regionCode: "EP", countryCode: "SA", countryLabel: "Saudi Arabia", tier: 1, alpha: true},
  {corridor: "middle_east", city: "Ras Tanura", regionCode: "EP", countryCode: "SA", countryLabel: "Saudi Arabia", tier: 2, alpha: false},
  {corridor: "middle_east", city: "Abqaiq", regionCode: "EP", countryCode: "SA", countryLabel: "Saudi Arabia", tier: 2, alpha: false},
  {corridor: "middle_east", city: "Riyadh", regionCode: "RI", countryCode: "SA", countryLabel: "Saudi Arabia", tier: 2, alpha: false},
  {corridor: "middle_east", city: "Yanbu", regionCode: "MK", countryCode: "SA", countryLabel: "Saudi Arabia", tier: 1, alpha: false},
  {corridor: "middle_east", city: "Jeddah", regionCode: "MK", countryCode: "SA", countryLabel: "Saudi Arabia", tier: 2, alpha: false},
  {corridor: "middle_east", city: "Doha", regionCode: "DA", regionNameOverride: "Doha", countryCode: "QA", countryLabel: "Qatar", tier: 1, alpha: true},
  {corridor: "middle_east", city: "Ras Laffan", regionCode: "RL", regionNameOverride: "Al Khor / Ras Laffan", countryCode: "QA", countryLabel: "Qatar", tier: 1, alpha: false},
  {corridor: "middle_east", city: "Mesaieed", regionCode: "MS", regionNameOverride: "Mesaieed", countryCode: "QA", countryLabel: "Qatar", tier: 1, alpha: false},
  {corridor: "middle_east", city: "Muscat", regionCode: "MA", regionNameOverride: "Muscat", countryCode: "OM", countryLabel: "Oman", tier: 1, alpha: true},
  {corridor: "middle_east", city: "Sohar", regionCode: "BN", regionNameOverride: "Al Batinah (Sohar)", countryCode: "OM", countryLabel: "Oman", tier: 1, alpha: false},
  {corridor: "middle_east", city: "Duqm", regionCode: "WU", regionNameOverride: "Al Wusta (Duqm)", countryCode: "OM", countryLabel: "Oman", tier: 2, alpha: false},
  {corridor: "middle_east", city: "Nizwa", regionCode: "DA", regionNameOverride: "Ad Dakhiliyah", countryCode: "OM", countryLabel: "Oman", tier: 2, alpha: false},
  {corridor: "middle_east", city: "Ahmadi", regionCode: "AH", regionNameOverride: "Al Ahmadi", countryCode: "KW", countryLabel: "Kuwait", tier: 1, alpha: true},
  {corridor: "middle_east", city: "Kuwait City", regionCode: "KU", regionNameOverride: "Al Asimah (Kuwait City)", countryCode: "KW", countryLabel: "Kuwait", tier: 2, alpha: false},
  {corridor: "middle_east", city: "Shuaiba", regionCode: "AH", regionNameOverride: "Al Ahmadi", countryCode: "KW", countryLabel: "Kuwait", tier: 2, alpha: false},
  {corridor: "middle_east", city: "Manama", regionCode: "CA", regionNameOverride: "Capital Governorate (Manama)", countryCode: "BH", countryLabel: "Bahrain", tier: 1, alpha: false},
  {corridor: "middle_east", city: "Sitra", regionCode: "CA", regionNameOverride: "Sitra / Awali", countryCode: "BH", countryLabel: "Bahrain", tier: 2, alpha: false},

  // 3. Latin America
  {corridor: "latin_america", city: "Macaé", regionCode: "RJ", countryCode: "BR", countryLabel: "RJ, Brazil", tier: 1, alpha: true},
  {corridor: "latin_america", city: "Rio de Janeiro", regionCode: "RJ", countryCode: "BR", countryLabel: "RJ, Brazil", tier: 1, alpha: true},
  {corridor: "latin_america", city: "Niterói", regionCode: "RJ", countryCode: "BR", countryLabel: "RJ, Brazil", tier: 1, alpha: false},
  {corridor: "latin_america", city: "Rio das Ostras", regionCode: "RJ", countryCode: "BR", countryLabel: "RJ, Brazil", tier: 2, alpha: false},
  {corridor: "latin_america", city: "Campos dos Goytacazes", regionCode: "RJ", countryCode: "BR", countryLabel: "RJ, Brazil", tier: 2, alpha: false},
  {corridor: "latin_america", city: "Santos", regionCode: "SP", countryCode: "BR", countryLabel: "SP, Brazil", tier: 1, alpha: false},
  {corridor: "latin_america", city: "São Paulo", regionCode: "SP", countryCode: "BR", countryLabel: "SP, Brazil", tier: 2, alpha: false},
  {corridor: "latin_america", city: "Vitória", regionCode: "ES", countryCode: "BR", countryLabel: "ES, Brazil", tier: 1, alpha: false},
  {corridor: "latin_america", city: "Camaçari", regionCode: "BA", countryCode: "BR", countryLabel: "BA, Brazil", tier: 2, alpha: false},
  {corridor: "latin_america", city: "Villahermosa", regionCode: "TAB", countryCode: "MX", countryLabel: "Tabasco, Mexico", tier: 1, alpha: true},
  {corridor: "latin_america", city: "Paraíso", regionCode: "TAB", countryCode: "MX", countryLabel: "Tabasco, Mexico", tier: 1, alpha: false},
  {corridor: "latin_america", city: "Ciudad del Carmen", regionCode: "CAM", countryCode: "MX", countryLabel: "Campeche, Mexico", tier: 1, alpha: true},
  {corridor: "latin_america", city: "Reynosa", regionCode: "TAM", countryCode: "MX", countryLabel: "Tamaulipas, Mexico", tier: 1, alpha: false},
  {corridor: "latin_america", city: "Tampico", regionCode: "TAM", countryCode: "MX", countryLabel: "Tamaulipas, Mexico", tier: 1, alpha: false},
  {corridor: "latin_america", city: "Altamira", regionCode: "TAM", countryCode: "MX", countryLabel: "Tamaulipas, Mexico", tier: 2, alpha: false},
  {corridor: "latin_america", city: "Coatzacoalcos", regionCode: "VER", countryCode: "MX", countryLabel: "Veracruz, Mexico", tier: 1, alpha: false},
  {corridor: "latin_america", city: "Poza Rica", regionCode: "VER", countryCode: "MX", countryLabel: "Veracruz, Mexico", tier: 1, alpha: false},
  {corridor: "latin_america", city: "Veracruz", regionCode: "VER", countryCode: "MX", countryLabel: "Mexico", tier: 2, alpha: false},
  {corridor: "latin_america", city: "Monterrey", regionCode: "NL", countryCode: "MX", countryLabel: "Nuevo Leon, Mexico", tier: 2, alpha: false},
  {corridor: "latin_america", city: "Neuquén", regionCode: "NQ", countryCode: "AR", countryLabel: "Neuquen, Argentina", tier: 1, alpha: true},
  {corridor: "latin_america", city: "Añelo", regionCode: "NQ", countryCode: "AR", countryLabel: "Neuquen, Argentina", tier: 1, alpha: true},
  {corridor: "latin_america", city: "Rincón de los Sauces", regionCode: "NQ", countryCode: "AR", countryLabel: "Neuquen, Argentina", tier: 2, alpha: false},
  {corridor: "latin_america", city: "Comodoro Rivadavia", regionCode: "CH", countryCode: "AR", countryLabel: "Chubut, Argentina", tier: 1, alpha: true},
  {corridor: "latin_america", city: "Caleta Olivia", regionCode: "CH", countryCode: "AR", countryLabel: "Argentina", tier: 2, alpha: false},
  {corridor: "latin_america", city: "Buenos Aires", regionCode: "BA", countryCode: "AR", countryLabel: "Argentina", tier: 2, alpha: false},
  {corridor: "latin_america", city: "Bahía Blanca", regionCode: "BA", countryCode: "AR", countryLabel: "Argentina", tier: 2, alpha: false},
  {corridor: "latin_america", city: "Bogotá", regionCode: "DC", countryCode: "CO", countryLabel: "Colombia", tier: 1, alpha: true},
  {corridor: "latin_america", city: "Barrancabermeja", regionCode: "SAN", countryCode: "CO", countryLabel: "Santander, Colombia", tier: 1, alpha: false},
  {corridor: "latin_america", city: "Yopal", regionCode: "CAS", countryCode: "CO", countryLabel: "Casanare, Colombia", tier: 1, alpha: false},
  {corridor: "latin_america", city: "Villavicencio", regionCode: "CAS", countryCode: "CO", countryLabel: "Meta, Colombia", tier: 2, alpha: false},
  {corridor: "latin_america", city: "Georgetown", regionCode: "DE", regionNameOverride: "Demerara-Mahaica (Georgetown)", countryCode: "GY", countryLabel: "Guyana", tier: 1, alpha: true},
  {corridor: "latin_america", city: "San Fernando", regionCode: "SFO", countryCode: "TT", countryLabel: "Trinidad and Tobago", tier: 1, alpha: true},
  {corridor: "latin_america", city: "Point Lisas", regionCode: "SFO", countryCode: "TT", countryLabel: "Trinidad and Tobago", tier: 1, alpha: false},
  {corridor: "latin_america", city: "Port of Spain", regionCode: "POS", countryCode: "TT", countryLabel: "Trinidad and Tobago", tier: 1, alpha: false},
  {corridor: "latin_america", city: "Chaguaramas", regionCode: "POS", countryCode: "TT", countryLabel: "Trinidad and Tobago", tier: 2, alpha: false},

  // 4. Australia
  {corridor: "australia", city: "Perth", regionCode: "WA", countryCode: "AU", countryLabel: "WA, Australia", tier: 1, alpha: true},
  {corridor: "australia", city: "Welshpool", regionCode: "WA", countryCode: "AU", countryLabel: "Perth WA, Australia", tier: 1, alpha: false},
  {corridor: "australia", city: "Henderson", regionCode: "WA", countryCode: "AU", countryLabel: "WA, Australia", tier: 1, alpha: false},
  {corridor: "australia", city: "Kewdale", regionCode: "WA", countryCode: "AU", countryLabel: "Perth WA, Australia", tier: 2, alpha: false},
  {corridor: "australia", city: "Karratha", regionCode: "WA", countryCode: "AU", countryLabel: "WA, Australia", tier: 1, alpha: true},
  {corridor: "australia", city: "Dampier", regionCode: "WA", countryCode: "AU", countryLabel: "WA, Australia", tier: 1, alpha: false},
  {corridor: "australia", city: "Port Hedland", regionCode: "WA", countryCode: "AU", countryLabel: "WA, Australia", tier: 2, alpha: false},
  {corridor: "australia", city: "Onslow", regionCode: "WA", countryCode: "AU", countryLabel: "WA, Australia", tier: 2, alpha: false},
  {corridor: "australia", city: "Brisbane", regionCode: "QLD", countryCode: "AU", countryLabel: "QLD, Australia", tier: 1, alpha: true},
  {corridor: "australia", city: "Toowoomba", regionCode: "QLD", countryCode: "AU", countryLabel: "QLD, Australia", tier: 1, alpha: false},
  {corridor: "australia", city: "Roma", regionCode: "QLD", countryCode: "AU", countryLabel: "QLD, Australia", tier: 1, alpha: true},
  {corridor: "australia", city: "Chinchilla", regionCode: "QLD", countryCode: "AU", countryLabel: "QLD, Australia", tier: 2, alpha: false},
  {corridor: "australia", city: "Gladstone", regionCode: "QLD", countryCode: "AU", countryLabel: "QLD, Australia", tier: 1, alpha: false},
  {corridor: "australia", city: "Darwin", regionCode: "NT", countryCode: "AU", countryLabel: "NT, Australia", tier: 1, alpha: true},
  {corridor: "australia", city: "Adelaide", regionCode: "SA", countryCode: "AU", countryLabel: "SA, Australia", tier: 1, alpha: false},
  {corridor: "australia", city: "Moomba", regionCode: "SA", countryCode: "AU", countryLabel: "SA, Australia", tier: 2, alpha: false},
  {corridor: "australia", city: "Sale", regionCode: "VIC", countryCode: "AU", countryLabel: "VIC, Australia", tier: 1, alpha: false},
  {corridor: "australia", city: "Melbourne", regionCode: "VIC", countryCode: "AU", countryLabel: "VIC, Australia", tier: 2, alpha: false},

  // 5. Africa (West, North, East & Southern Africa Energy Basins)
  {corridor: "africa", city: "Port Harcourt", regionCode: "RI", countryCode: "NG", countryLabel: "Rivers, Nigeria", tier: 1, alpha: true},
  {corridor: "africa", city: "Onne", regionCode: "RI", countryCode: "NG", countryLabel: "Rivers, Nigeria", tier: 1, alpha: false},
  {corridor: "africa", city: "Lagos", regionCode: "LA", countryCode: "NG", countryLabel: "Nigeria", tier: 1, alpha: true},
  {corridor: "africa", city: "Warri", regionCode: "DE", countryCode: "NG", countryLabel: "Delta, Nigeria", tier: 1, alpha: true},
  {corridor: "africa", city: "Eket", regionCode: "AK", countryCode: "NG", countryLabel: "Akwa Ibom, Nigeria", tier: 2, alpha: false},
  {corridor: "africa", city: "Abuja", regionCode: "FC", countryCode: "NG", countryLabel: "Nigeria", tier: 2, alpha: false},
  {corridor: "africa", city: "Luanda", regionCode: "LUA", countryCode: "AO", countryLabel: "Angola", tier: 1, alpha: true},
  {corridor: "africa", city: "Cabinda", regionCode: "CAB", countryCode: "AO", countryLabel: "Angola", tier: 1, alpha: false},
  {corridor: "africa", city: "Soyo", regionCode: "ZAI", countryCode: "AO", countryLabel: "Angola", tier: 1, alpha: false},
  {corridor: "africa", city: "Lobito", regionCode: "BGU", countryCode: "AO", countryLabel: "Angola", tier: 2, alpha: false},
  {corridor: "africa", city: "Cairo", regionCode: "CAI", countryCode: "EG", countryLabel: "Egypt", tier: 1, alpha: true},
  {corridor: "africa", city: "Alexandria", regionCode: "ALX", countryCode: "EG", countryLabel: "Egypt", tier: 1, alpha: true},
  {corridor: "africa", city: "Suez", regionCode: "SUZ", countryCode: "EG", countryLabel: "Egypt", tier: 1, alpha: false},
  {corridor: "africa", city: "Port Said", regionCode: "PTS", countryCode: "EG", countryLabel: "Egypt", tier: 1, alpha: false},
  {corridor: "africa", city: "Ras Gharib", regionCode: "BA", countryCode: "EG", countryLabel: "Red Sea, Egypt", tier: 2, alpha: false},
  {corridor: "africa", city: "Takoradi", regionCode: "WP", countryCode: "GH", countryLabel: "Ghana", tier: 1, alpha: true},
  {corridor: "africa", city: "Accra", regionCode: "AA", countryCode: "GH", countryLabel: "Ghana", tier: 1, alpha: true},
  {corridor: "africa", city: "Tema", regionCode: "AA", countryCode: "GH", countryLabel: "Ghana", tier: 1, alpha: false},
  {corridor: "africa", city: "Hassi Messaoud", regionCode: "OUA", countryCode: "DZ", countryLabel: "Algeria", tier: 1, alpha: true},
  {corridor: "africa", city: "Algiers", regionCode: "ALG", countryCode: "DZ", countryLabel: "Algeria", tier: 1, alpha: false},
  {corridor: "africa", city: "Oran", regionCode: "ORA", countryCode: "DZ", countryLabel: "Algeria", tier: 1, alpha: false},
  {corridor: "africa", city: "Cape Town", regionCode: "WC", countryCode: "ZA", countryLabel: "South Africa", tier: 1, alpha: true},
  {corridor: "africa", city: "Durban", regionCode: "KZN", countryCode: "ZA", countryLabel: "South Africa", tier: 1, alpha: false},
  {corridor: "africa", city: "Johannesburg", regionCode: "GP", countryCode: "ZA", countryLabel: "South Africa", tier: 1, alpha: false},
  {corridor: "africa", city: "Walvis Bay", regionCode: "ER", countryCode: "NA", countryLabel: "Namibia", tier: 1, alpha: true},
  {corridor: "africa", city: "Lüderitz", regionCode: "KA", countryCode: "NA", countryLabel: "Namibia", tier: 1, alpha: false},
  {corridor: "africa", city: "Windhoek", regionCode: "KH", countryCode: "NA", countryLabel: "Namibia", tier: 2, alpha: false},
  {corridor: "africa", city: "Maputo", regionCode: "MPM", countryCode: "MZ", countryLabel: "Mozambique", tier: 1, alpha: false},
  {corridor: "africa", city: "Pemba", regionCode: "CD", countryCode: "MZ", countryLabel: "Mozambique", tier: 1, alpha: false},
  {corridor: "africa", city: "Port-Gentil", regionCode: "OG", countryCode: "GA", countryLabel: "Gabon", tier: 1, alpha: false},
  {corridor: "africa", city: "Libreville", regionCode: "ES", countryCode: "GA", countryLabel: "Gabon", tier: 2, alpha: false},
  {corridor: "africa", city: "Pointe-Noire", regionCode: "PNR", countryCode: "CG", countryLabel: "Republic of the Congo", tier: 1, alpha: false},
  {corridor: "africa", city: "Abidjan", regionCode: "AB", countryCode: "CI", countryLabel: "Cote d'Ivoire", tier: 1, alpha: false},
  {corridor: "africa", city: "Dakar", regionCode: "DK", countryCode: "SN", countryLabel: "Senegal", tier: 1, alpha: false},
  {corridor: "africa", city: "Kampala", regionCode: "CMP", countryCode: "UG", countryLabel: "Uganda", tier: 1, alpha: false},
  {corridor: "africa", city: "Dar es Salaam", regionCode: "DAR", countryCode: "TZ", countryLabel: "Tanzania", tier: 2, alpha: false},
  {corridor: "africa", city: "Tripoli", regionCode: "TB", countryCode: "LY", countryLabel: "Libya", tier: 1, alpha: false},

  // 6. Southeast, South & Central (Caspian) Asia
  {corridor: "asia_caspian", city: "Singapore", regionCode: "SGP", countryCode: "SG", countryLabel: "Singapore", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Tuas", regionCode: "JRG", countryCode: "SG", countryLabel: "Singapore", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Jurong", regionCode: "JRG", countryCode: "SG", countryLabel: "Singapore", tier: 1, alpha: false},
  {corridor: "asia_caspian", city: "Loyang", regionCode: "LYG", countryCode: "SG", countryLabel: "Singapore", tier: 1, alpha: false},
  {corridor: "asia_caspian", city: "Kuala Lumpur", regionCode: "KUL", countryCode: "MY", countryLabel: "Malaysia", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Shah Alam", regionCode: "SLG", countryCode: "MY", countryLabel: "Selangor, Malaysia", tier: 1, alpha: false},
  {corridor: "asia_caspian", city: "Miri", regionCode: "SWK", countryCode: "MY", countryLabel: "Sarawak, Malaysia", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Bintulu", regionCode: "SWK", countryCode: "MY", countryLabel: "Sarawak, Malaysia", tier: 1, alpha: false},
  {corridor: "asia_caspian", city: "Labuan", regionCode: "SBH", countryCode: "MY", countryLabel: "Malaysia", tier: 1, alpha: false},
  {corridor: "asia_caspian", city: "Kota Kinabalu", regionCode: "SBH", countryCode: "MY", countryLabel: "Sabah, Malaysia", tier: 1, alpha: false},
  {corridor: "asia_caspian", city: "Kemaman", regionCode: "TRG", countryCode: "MY", countryLabel: "Terengganu, Malaysia", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Johor Bahru", regionCode: "JHR", countryCode: "MY", countryLabel: "Johor, Malaysia", tier: 1, alpha: false},
  {corridor: "asia_caspian", city: "Jakarta", regionCode: "JK", countryCode: "ID", countryLabel: "Indonesia", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Balikpapan", regionCode: "KI", countryCode: "ID", countryLabel: "East Kalimantan, Indonesia", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Batam", regionCode: "KR", countryCode: "ID", countryLabel: "Indonesia", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Duri", regionCode: "RIU", countryCode: "ID", countryLabel: "Riau, Indonesia", tier: 1, alpha: false},
  {corridor: "asia_caspian", city: "Pekanbaru", regionCode: "RIU", countryCode: "ID", countryLabel: "Riau, Indonesia", tier: 2, alpha: false},
  {corridor: "asia_caspian", city: "Surabaya", regionCode: "JI", countryCode: "ID", countryLabel: "East Java, Indonesia", tier: 1, alpha: false},
  {corridor: "asia_caspian", city: "Kuala Belait", regionCode: "BEL", countryCode: "BN", countryLabel: "Brunei", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Bandar Seri Begawan", regionCode: "BM", countryCode: "BN", countryLabel: "Brunei", tier: 2, alpha: false},
  {corridor: "asia_caspian", city: "Rayong", regionCode: "RYG", countryCode: "TH", countryLabel: "Thailand", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Songkhla", regionCode: "SKA", countryCode: "TH", countryLabel: "Thailand", tier: 1, alpha: false},
  {corridor: "asia_caspian", city: "Bangkok", regionCode: "BKK", countryCode: "TH", countryLabel: "Thailand", tier: 2, alpha: false},
  {corridor: "asia_caspian", city: "Vung Tau", regionCode: "BRV", countryCode: "VN", countryLabel: "Vietnam", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Ho Chi Minh City", regionCode: "SGN", countryCode: "VN", countryLabel: "Vietnam", tier: 2, alpha: false},
  {corridor: "asia_caspian", city: "Atyrau", regionCode: "ATY", countryCode: "KZ", countryLabel: "Kazakhstan", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Aktau", regionCode: "MAN", countryCode: "KZ", countryLabel: "Kazakhstan", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Uralsk", regionCode: "ZAP", countryCode: "KZ", countryLabel: "Kazakhstan", tier: 1, alpha: false},
  {corridor: "asia_caspian", city: "Almaty", regionCode: "ALA", countryCode: "KZ", countryLabel: "Kazakhstan", tier: 2, alpha: false},
  {corridor: "asia_caspian", city: "Baku", regionCode: "BAK", countryCode: "AZ", countryLabel: "Azerbaijan", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Sumqayit", regionCode: "SMQ", countryCode: "AZ", countryLabel: "Azerbaijan", tier: 2, alpha: false},
  {corridor: "asia_caspian", city: "Mumbai", regionCode: "MH", countryCode: "IN", countryLabel: "Maharashtra, India", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Kakinada", regionCode: "AP", countryCode: "IN", countryLabel: "Andhra Pradesh, India", tier: 1, alpha: true},
  {corridor: "asia_caspian", city: "Vadodara", regionCode: "GJ", countryCode: "IN", countryLabel: "Gujarat, India", tier: 1, alpha: false},
  {corridor: "asia_caspian", city: "Duliajan", regionCode: "AS", countryCode: "IN", countryLabel: "Assam, India", tier: 2, alpha: false},
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

const TRAINING_SEARCH_TEMPLATES_INTL = [
  "OPITO BOSIET Offshore Survival Training",
  "IWCF IADC Well Control Training",
  "Oil & Gas HSE H2S Safety Training",
  "IRATA Rope Access Lifting & Rigging Training",
  "Welding & NDT Inspection Training Center",
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

const INTL_SECTOR_SEARCH_TEMPLATES = [
  {q: "Oilfield & Offshore Energy Services", cat: "equipment_rentals_tools"},
  {q: "Drilling & Well Intervention Services", cat: "drilling_rigs_directional"},
  {q: "OCTG Pipe Casing & Steel Tubular Supply", cat: "pipe_octg_supply"},
  {q: "Wellhead Valves BOP & Pressure Control", cat: "wellhead_valves_pressure"},
  {q: "Wireline Slickline Coiled Tubing & Well Testing", cat: "completions_frac_wireline"},
  {q: "Subsea Pipeline & Oilfield EPCI Contractor", cat: "pipeline_facility_construction"},
  {q: "Offshore Fabrication Welding & Machining", cat: "welding_machining_fab"},
  {q: "Pipe Inspection NDT & Lifting Inspection", cat: "pipe_inspection_ndt"},
  {q: "Heavy Lift Crane Rigging & Supply Base Logistics", cat: "crane_picker_rigging"},
  {q: "Pumps Artificial Lift & Gas Compression", cat: "pumps_artificial_lift"},
  {q: "Subsea Controls ROV Electrical & Instrumentation", cat: "electrical_automation_scada"},
  {q: "Drilling Fluids Production Chemicals & Bunkering", cat: "chemical_mud_lubricants"},
  {q: "Decommissioning Oilfield Waste & Environmental", cat: "environmental_remediation_waste"},
  {q: "Offshore Catering & Modular Workforce Camps", cat: "camps_catering_accommodations"},
];

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");

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
  s = s.replace(/\b(?:ndt|octg|h2s|hse|ehs|bop|iwcf|iadc|opito|cdl|osha|ems|cpr|llc|llp|plc|bv|nv|as|sa|fzco|fze|wll|pty)\b/giu, (m) =>
    m.toUpperCase(),
  );
  s = s.replace(/\b(?:ltd|inc|corp)\b\.?/giu, (m) => {
    const clean = m.replace(/\./gu, "").toLowerCase();
    return clean.charAt(0).toUpperCase() + clean.slice(1);
  });
  const connectors = new Set(["and", "of", "the", "in", "for", "on", "at", "to", "by", "de", "da", "do", "dos", "la", "el", "del"]);
  s = s
    .split(/\s+/u)
    .map((w, idx) => {
      if (/^[a-z]{3,}$/u.test(w) && (idx === 0 || !connectors.has(w))) {
        return w.charAt(0).toUpperCase() + w.slice(1);
      }
      return w;
    })
    .join(" ");
  return s;
}

async function loadPlaywright() {
  const candidates = [
    process.env.PLAYWRIGHT_CORE_PATH,
    "C:\\Users\\jordi\\.gemini\\antigravity\\brain\\89d324bb-a72f-4739-a356-b6b46e26db9a\\scratch\\flag-gen\\node_modules\\playwright-core\\index.mjs",
    path.join(REPO_ROOT, "node_modules/playwright-core/index.mjs"),
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
  if (/\b(?:h2s\s*alive|energy\s+safety\s+canada)\b/iu.test(textBlob)) certs.add("Energy Safety Canada / H2S Alive");
  if (/\b(?:iwcf|wellsharp|iadc)\b/iu.test(textBlob)) certs.add("IWCF / IADC WellSharp");
  if (/\b(?:safeland|safegulf|veriforce|pec)\b/iu.test(textBlob)) certs.add("PEC SafeLand / Veriforce");
  if (/\b(?:opito|bosiet|t-bosiet|foet|huet)\b/iu.test(textBlob)) certs.add("OPITO / IWCF");
  if (/\b(?:dnv)\b/iu.test(textBlob)) certs.add("DNV Certified");
  if (/\b(?:achilles|fpal)\b/iu.test(textBlob)) certs.add("Achilles / FPAL");
  if (/\b(?:iktva|aramco|adnoc|icv)\b/iu.test(textBlob)) certs.add("Aramco IKTVA / ADNOC ICV");
  if (/\b(?:petronas|cidb|niosh)\b/iu.test(textBlob)) certs.add("PETRONAS / NIOSH");
  if (/\b(?:ncdmb|nipex|nuprc|\bdpr\b)\b/iu.test(textBlob)) certs.add("NCDMB / NIPEX");
  if (/\b(?:migas|bnsp)\b/iu.test(textBlob)) certs.add("MIGAS / BNSP");
  if (/\b(?:iso\s*9001|iso\s*45001|iso\s*14001)\b/iu.test(textBlob)) certs.add("ISO 9001 / ISO 45001");
  if (/\b(?:secor|\bcor\b)\b/iu.test(textBlob)) certs.add("COR / SECOR");
  if (/\bisnetworld\b/iu.test(textBlob)) certs.add("ISNetworld");
  if (/\bcomplyworks\b/iu.test(textBlob)) certs.add("ComplyWorks");
  if (/\babsa\b/iu.test(textBlob)) certs.add("ABSA");
  if (/\bapi\s*(?:q1|q2|spec)\b/iu.test(textBlob)) certs.add("API Spec Q1 / Q2");
  if (/\bcwb\b/iu.test(textBlob)) certs.add("CSA / CWB");
  return [...certs];
}

function buildNorthAmericaSearchQueue() {
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

function buildInternationalSearchQueue() {
  const queue = [];
  const defaultTrainCat = INCLUDE_TRAINING_CODE ? "oil_gas_training_courses" : "staffing_training_compliance";

  const corridors = ["uk_norway", "middle_east", "latin_america", "australia", "africa", "asia_caspian"];
  for (const corridor of corridors) {
    if (CORRIDOR_FILTER && corridor !== CORRIDOR_FILTER) continue;

    const hubs = INTERNATIONAL_HUBS.filter(
      (h) => h.corridor === corridor && (!COUNTRY_FILTER || h.countryCode === COUNTRY_FILTER),
    );
    if (!hubs.length) continue;

    // 1. Accredited Offshore / Onshore Oil & Gas Training Sweep per Corridor
    for (const hub of hubs) {
      const loc = `${hub.city}, ${hub.countryLabel}`;
      const templates = hub.tier === 1 ? [...TRAINING_SEARCH_TEMPLATES_INTL] : TRAINING_SEARCH_TEMPLATES_INTL.slice(0, 2);
      if (["BR", "AO", "MZ"].includes(hub.countryCode) && hub.tier === 1) {
        templates.push("Treinamento Offshore CBSP HUET");
      }
      if (["MX", "AR", "CO"].includes(hub.countryCode) && hub.tier === 1) {
        templates.push("Capacitación Petrolera Well Control RigPass");
      }
      if (hub.countryCode === "NO" && hub.tier === 1) templates.push("Sikkerhetssenter Offshore Kurs GSK");
      if (["DZ", "GA", "CG", "CI", "SN"].includes(hub.countryCode) && hub.tier === 1) {
        templates.push("Formation Sécurité Pétrolière Offshore H2S IWCF");
      }
      if (hub.countryCode === "ID" && hub.tier === 1) {
        templates.push("Pelatihan Sertifikasi Migas K3 Lepas Pantai");
      }
      if (hub.countryCode === "MY" && hub.tier === 1) {
        templates.push("PETRONAS Offshore Safety Training T-BOSIET");
      }

      for (const tpl of templates) {
        queue.push({
          id: `INTL|${corridor}|${hub.countryCode}|${hub.regionCode}|${hub.city}|TRAIN|${tpl}`,
          corridor,
          countryCode: hub.countryCode,
          regionCode: hub.regionCode,
          regionNameOverride: hub.regionNameOverride || "",
          city: hub.city,
          letter: "TRAIN",
          isTrainingQuery: true,
          defaultCat: defaultTrainCat,
          query: `${tpl} in ${loc}`,
        });
      }
    }

    // 2. Deep Oilfield & Offshore Sector Sweep per Corridor
    for (const hub of hubs) {
      const loc = `${hub.city}, ${hub.countryLabel}`;
      const sectors = hub.tier === 1 ? [...INTL_SECTOR_SEARCH_TEMPLATES] : INTL_SECTOR_SEARCH_TEMPLATES.slice(0, 6);
      if (["BR", "AO", "MZ"].includes(hub.countryCode) && hub.tier === 1) {
        sectors.push({q: "Serviços de Petróleo Óleo e Gás Offshore", cat: "equipment_rentals_tools"});
      }
      if (["MX", "AR", "CO"].includes(hub.countryCode) && hub.tier === 1) {
        sectors.push({q: "Servicios Petroleros Perforación y Pozos", cat: "drilling_rigs_directional"});
      }
      if (hub.countryCode === "NO" && hub.tier === 1) {
        sectors.push({q: "Offshore Subsea & Oljeservice", cat: "equipment_rentals_tools"});
      }
      if (["DZ", "GA", "CG", "CI", "SN"].includes(hub.countryCode) && hub.tier === 1) {
        sectors.push({q: "Services Pétroliers Forage & Offshore", cat: "drilling_rigs_directional"});
      }
      if (hub.countryCode === "ID" && hub.tier === 1) {
        sectors.push({q: "Kontraktor Jasa Penunjang Migas Pengeboran", cat: "drilling_rigs_directional"});
      }
      if (hub.countryCode === "KZ" && hub.tier === 1) {
        sectors.push({q: "Нефтесервисные компании бурение КРС", cat: "drilling_rigs_directional"});
      }

      for (const sec of sectors) {
        queue.push({
          id: `INTL|${corridor}|${hub.countryCode}|${hub.regionCode}|${hub.city}|SEC|${sec.q}`,
          corridor,
          countryCode: hub.countryCode,
          regionCode: hub.regionCode,
          regionNameOverride: hub.regionNameOverride || "",
          city: hub.city,
          letter: hub.city[0].toUpperCase(),
          isTrainingQuery: false,
          defaultCat: sec.cat,
          query: `${sec.q} in ${loc}`,
        });
      }
    }

    // 3. Strict Alphabetical A -> Z Sweep across Core Tier-1 International Hubs
    const alphaHubs = hubs.filter((h) => h.alpha);
    for (const letter of ALPHABET) {
      for (const hub of alphaHubs) {
        const loc = `${hub.city}, ${hub.countryLabel}`;
        queue.push({
          id: `INTL|${corridor}|${hub.countryCode}|${hub.regionCode}|${hub.city}|ALPHA-${letter}`,
          corridor,
          countryCode: hub.countryCode,
          regionCode: hub.regionCode,
          regionNameOverride: hub.regionNameOverride || "",
          city: hub.city,
          letter,
          isTrainingQuery: false,
          defaultCat: "equipment_rentals_tools",
          query: `"${letter}" Oil & Gas Offshore Services ${loc}`,
        });
      }
    }
  }

  return queue;
}

function buildInternationalHubLookup() {
  const byCountry = new Map();
  for (const h of INTERNATIONAL_HUBS) {
    if (!byCountry.has(h.countryCode)) byCountry.set(h.countryCode, []);
    byCountry.get(h.countryCode).push(h);
  }
  for (const list of byCountry.values()) {
    list.sort((a, b) => b.city.length - a.city.length);
  }
  return byCountry;
}
const INTL_HUBS_BY_COUNTRY = buildInternationalHubLookup();

async function mergeJsonlIntoIndex(jsonlPath, indexState) {
  if (!fs.existsSync(jsonlPath)) return;
  const raw = await fsp.readFile(jsonlPath, "utf8");
  for (const line of raw.split("\n")) {
    if (!line.trim()) continue;
    try {
      const obj = JSON.parse(line);
      const pr = obj.privateRecord || {};
      const cc = String(pr.countryCode || "").toUpperCase();
      const rc = String(pr.regionCode || "").toUpperCase();
      const norm = pr.normalizedCompanyName || normalizedCompanyName(pr.companyName || "");
      if (norm) indexState.existingNameRegion.add(`${norm}|${cc}|${rc}`);
      for (const k of ["publicPhone", "tollFreePhone", "mainPhone"]) {
        const digits = String(pr[k] || "").replace(/\D+/gu, "");
        if (digits.length >= 7) {
          indexState.existingPhones.add(digits);
          if (digits.length >= 10) indexState.existingPhones.add(digits.slice(-10));
        }
      }
    } catch (_) {}
  }
}

async function loadExistingFirestoreIndex(projectId, cachePath, jsonlPath) {
  if (!REFRESH_INDEX && fs.existsSync(cachePath)) {
    try {
      const cached = JSON.parse(await fsp.readFile(cachePath, "utf8"));
      if (cached && Date.now() - Number(cached.fetchedAtMs || 0) < 90 * 60 * 1000) {
        const indexState = {
          existingPhones: new Set(cached.existingPhones || []),
          existingNameRegion: new Set(cached.existingNameRegion || []),
          phoneToDocIds: new Map(cached.phoneToDocIds || []),
          blockedPhones: new Set(cached.blockedPhones || []),
        };
        await mergeJsonlIntoIndex(jsonlPath, indexState);
        console.log(
          `[bot16] Loaded cached Firestore index (${indexState.existingPhones.size} phone keys, ${indexState.existingNameRegion.size} companies).`,
        );
        return indexState;
      }
    } catch (_) {}
  }

  console.log(`[bot16] Loading existing Firestore phone & company index from ${projectId}...`);
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
      body: JSON.stringify({
        structuredQuery: {from: [{collectionId: "yellow_pages_blocked_numbers"}], limit: 1000},
      }),
    });
    if (res.ok) {
      const rows = await res.json();
      for (const r of rows) {
        if (!r.document) continue;
        const id = r.document.name.split("/").pop().replace(/\D+/gu, "");
        if (id.length >= 7) {
          blockedPhones.add(id);
          if (id.length >= 10) blockedPhones.add(id.slice(-10));
        }
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
          {fieldPath: "countryCode"},
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
      const cc = (f?.countryCode?.stringValue || "").toUpperCase();
      const rc = (f?.regionCode?.stringValue || "").toUpperCase();
      const norm = normalizedCompanyName(name);
      if (norm) {
        existingNameRegion.add(`${norm}|${rc}`);
        existingNameRegion.add(`${norm}|${cc}|${rc}`);
      }
      for (const k of ["publicPhone", "tollFreePhone"]) {
        const digits = String(f?.[k]?.stringValue || "").replace(/\D+/gu, "");
        if (digits.length >= 7) {
          existingPhones.add(digits);
          const d10 = digits.slice(-10);
          if (d10.length === 10) {
            existingPhones.add(d10);
            if (!phoneToDocIds.has(d10)) phoneToDocIds.set(d10, []);
            phoneToDocIds.get(d10).push(docId);
          }
          if (!phoneToDocIds.has(digits)) phoneToDocIds.set(digits, []);
          phoneToDocIds.get(digits).push(docId);
        }
      }
    }
    if (docs.length < 3000) break;
  }

  const indexState = {existingPhones, existingNameRegion, phoneToDocIds, blockedPhones};
  await mergeJsonlIntoIndex(jsonlPath, indexState);
  await fsp.writeFile(
    cachePath,
    JSON.stringify({
      fetchedAtMs: Date.now(),
      existingPhones: [...indexState.existingPhones],
      existingNameRegion: [...indexState.existingNameRegion],
      phoneToDocIds: [...indexState.phoneToDocIds.entries()],
      blockedPhones: [...indexState.blockedPhones],
    }),
    "utf8",
  );
  console.log(`[bot16] Indexed & cached ${total} live public entries (${indexState.existingPhones.size} phone keys).`);
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

  await page.waitForSelector('div.Nv2PK, h1.DUwDvf, div.Q2vNVc, div[role="main"]', {timeout: 6000}).catch(() => {});
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
      await page.waitForTimeout(380);
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

function validateAndBuildNorthAmericaRecord(card, task, indexState, seqNum) {
  const fullText = [card.name, ...card.lines].join(" · ");

  if (/\b(?:permanently\s+closed|temporarily\s+closed)\b/iu.test(fullText)) {
    const pNorm = normalizeNorthAmericanPhone(card.phone);
    if (pNorm.validNanpa && indexState.phoneToDocIds.has(pNorm.digits10)) {
      return {status: "closed_existing", docIds: indexState.phoneToDocIds.get(pNorm.digits10), name: card.name};
    }
    return {status: "rejected_closed"};
  }

  const cleanName = polishDiscoveredCompanyName(card.name);
  if (!cleanName || cleanName.length < 3) return {status: "rejected_invalid"};
  if (CONSUMER_NOISE_BLOCKLIST.test(fullText)) return {status: "rejected_noise"};

  if (!POSITIVE_OILFIELD_OR_TRAINING_SIGNAL.test(fullText)) {
    if (
      !/\b(?:industrial|equipment|contractor|supply|supplier|transport|freight|logistics|machining|steel|manufactur|engineering|testing|laboratory|safety|training)\b/iu.test(
        fullText,
      )
    ) {
      return {status: "rejected_non_oilfield"};
    }
  }
  if (task.isTrainingQuery) {
    if (
      !/\b(?:safety|oilfield|energy|well\s+control|h2s|iwcf|opito|safeland|industrial|emergency|first\s+aid|rescue|confined\s+space|fall\s+protection|crane|rigging|truck|driver|cdl|class\s+1|weld|ndt|polytechnic|college|institute|technical|occupational|compliance|enviro|training\s+cent(?:er|re)|simulated\s+worksite)\b/iu.test(
        fullText,
      )
    ) {
      return {status: "rejected_non_oilfield_school"};
    }
  }

  let rawPhone = String(card.phone || "").trim();
  if (/^(?:09\d\d|\+(?!1\b)\d+)/u.test(rawPhone)) {
    return {status: "rejected_foreign_phone"};
  }
  if (!rawPhone) {
    const m = fullText.match(/(?:\+?1[\s.-]?)?\(?([2-9]\d{2})\)?[\s.-]?(\d{3})[\s.-]?(\d{4})\b/u);
    if (m) rawPhone = `${m[1]}-${m[2]}-${m[3]}`;
  }
  const phoneNorm = normalizeNorthAmericanPhone(rawPhone);
  if (!phoneNorm.validNanpa) return {status: "rejected_no_phone"};
  if (indexState.blockedPhones.has(phoneNorm.digits10)) return {status: "rejected_blocked"};

  const npa = phoneNorm.digits10.slice(0, 3);
  const phoneGeo = inferGeoFromNanpaPhone(phoneNorm.digits10);
  const targetCc = task.countryCode;
  let finalRc = canonicalizeRegionCode(task.regionCode, targetCc);
  let finalCity = task.city;

  const borderTwinOk = finalCity === "Lloydminster" && (phoneGeo?.regionCode === "AB" || phoneGeo?.regionCode === "SK");

  if (phoneGeo && !phoneGeo.isTollFree) {
    if (phoneGeo.countryCode !== targetCc) return {status: "rejected_zoom_out_country"};
    if (phoneGeo.regionCode !== finalRc && !borderTwinOk) {
      const cityRx = new RegExp(`\\b${task.city.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&")}\\b`, "iu");
      if (!cityRx.test(fullText)) return {status: "rejected_zoom_out_region"};
    }
  } else if (phoneNorm.isTollFree) {
    const otherStateMatch = fullText.match(/,\s*([A-Z]{2})\s+\d{5}\b/u);
    if (otherStateMatch && otherStateMatch[1] !== finalRc) return {status: "rejected_zoom_out_tollfree"};
  } else {
    if (targetCc !== "US" || !EXTRA_VALID_US_NPA.has(npa)) return {status: "rejected_unmapped_npa"};
    const cityRx = new RegExp(`\\b${task.city.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&")}\\b`, "iu");
    if (!cityRx.test(fullText)) return {status: "rejected_zoom_out_region"};
  }

  let streetAddress = "";
  for (const line of card.lines) {
    if (/^\d\.\d\s*\(/u.test(line) || /^Open\b|^Closed\b|^Closes\b/iu.test(line)) continue;
    if (line.includes("·")) {
      const parts = line
        .split("·")
        .map((p) => p.replace(/[^\x20-\x7E]/gu, "").trim())
        .filter(Boolean);
      const addrPart = parts.find(
        (p) => /\d+\s+[A-Za-z0-9]/u.test(p) || /\b(?:Ave|St|Rd|Dr|Blvd|Hwy|Fwy|Pkwy|Way|Ln|Ct|Twp)\b/iu.test(p),
      );
      if (addrPart) {
        streetAddress = addrPart.slice(0, 140);
        break;
      }
    }
  }

  finalCity = canonicalizeCityName(finalCity, finalRc, targetCc);
  const normName = normalizedCompanyName(cleanName);
  if (!normName) return {status: "rejected_invalid"};

  if (
    indexState.existingPhones.has(phoneNorm.digits10) ||
    indexState.existingNameRegion.has(`${normName}|${finalRc}`) ||
    indexState.existingNameRegion.has(`${normName}|${targetCc}|${finalRc}`)
  ) {
    return {status: "duplicate_existing"};
  }

  indexState.existingPhones.add(phoneNorm.digits10);
  indexState.existingNameRegion.add(`${normName}|${targetCc}|${finalRc}`);

  return finalizeDiscoveredRecord({
    card,
    task,
    cleanName,
    normName,
    targetCc,
    finalRc,
    regionNameOverride: "",
    finalCity,
    streetAddress,
    phoneDisplay: phoneNorm.display,
    isTollFree: phoneNorm.isTollFree,
    phoneExternalId: phoneNorm.digits10,
    fullText,
    seqNum,
  });
}

function validateAndBuildInternationalRecord(card, task, indexState, seqNum) {
  const fullText = [card.name, ...card.lines].join(" · ");
  const targetCc = task.countryCode;
  const phoneRule = INTL_COUNTRY_PHONE_RULES[targetCc];
  if (!phoneRule) return {status: "rejected_unsupported_country"};

  // 1. Permanently/temporarily closed check
  if (
    /\b(?:permanently\s+closed|temporarily\s+closed|permanent\s+stengt|fechado\s+permanentemente|cerrado\s+permanentemente|ferm[eé]\s+d[eé]finitivement|tutup\s+permanen|закрыто\s+навсегда)\b/iu.test(
      fullText,
    )
  ) {
    const pNorm = normalizeGlobalPhone(card.phone, targetCc);
    if (pNorm.validPhone && indexState.phoneToDocIds.has(pNorm.digitsKey)) {
      return {status: "closed_existing", docIds: indexState.phoneToDocIds.get(pNorm.digitsKey), name: card.name};
    }
    return {status: "rejected_closed"};
  }

  // 2. Clean & validate company name + consumer noise gate
  const cleanName = polishDiscoveredCompanyName(card.name);
  if (!cleanName || cleanName.length < 3) return {status: "rejected_invalid"};
  if (CONSUMER_NOISE_BLOCKLIST.test(fullText)) return {status: "rejected_noise"};

  if (!POSITIVE_OILFIELD_OR_TRAINING_SIGNAL.test(fullText)) {
    if (
      !/\b(?:industrial|equipment|contractor|supply|supplier|transport|freight|logistics|marine|shipping|port|machining|steel|manufactur|engineering|engenharia|ingenier[ií]a|ing[eé]nierie|testing|laboratory|safety|training)\b/iu.test(
        fullText,
      )
    ) {
      return {status: "rejected_non_oilfield"};
    }
  }
  if (task.isTrainingQuery) {
    if (
      !/\b(?:safety|sikkerhet|seguran[cç]a|seguridad|s[eé]curit[eé]|oilfield|offshore|migas|energy|well\s+control|h2s|iwcf|iadc|opito|bosiet|t-bosiet|foet|huet|cbsp|irata|nebosh|niosh|gwo|industrial|emergency|first\s+aid|rescue|confined\s+space|crane|rigging|lifting|weld|ndt|polytechnic|college|institute|academy|kurssenter|treinamento|capacitaci[oó]n|formation|pelatihan|technical|training)\b/iu.test(
        fullText,
      )
    ) {
      return {status: "rejected_non_oilfield_school"};
    }
  }

  // 3. Extract & Strictly Validate Country Dial Code + National Subscriber Digits
  let rawPhone = String(card.phone || "").trim();
  if (!rawPhone) {
    const dialEsc = targetCc === "KZ" ? "7[\\s.()-]*7" : phoneRule.dial;
    const plusRx = new RegExp(`\\+${dialEsc}[\\s.()-]*[0-9][0-9\\s.()-]{5,14}`, "u");
    const m = fullText.match(plusRx);
    if (m) rawPhone = m[0].trim();
  }
  if (!rawPhone) return {status: "rejected_no_phone"};

  const trimmedPhone = rawPhone.replace(/\s*(?:ext\.?|extension|x)\s*\d+\s*$/iu, "").trim();
  const hadExplicitPlus = trimmedPhone.startsWith("+") || trimmedPhone.startsWith("00");
  const rawDigits = (trimmedPhone.startsWith("00") ? trimmedPhone.slice(2) : trimmedPhone).replace(/\D+/gu, "");

  if (hadExplicitPlus) {
    // Reject immediately if explicit international prefix belongs to ANY other country!
    if (!rawDigits.startsWith(phoneRule.dial)) {
      return {status: "rejected_zoom_out_country"};
    }
    const natLen = rawDigits.length - phoneRule.dial.length;
    if (natLen < phoneRule.minNat || natLen > phoneRule.maxNat + 1) {
      return {status: "rejected_invalid_phone_len"};
    }
  } else {
    // Domestic format without '+': require valid national length AND explicit city/country geo-signal in card text
    let subDigits = rawDigits;
    if (targetCc === "TT") {
      if (subDigits.length === 10 && !subDigits.startsWith("868")) return {status: "rejected_zoom_out_country"};
      if (subDigits.length === 11 && !subDigits.startsWith("1868")) return {status: "rejected_zoom_out_country"};
      if (subDigits.length !== 7 && subDigits.length !== 10 && subDigits.length !== 11) {
        return {status: "rejected_invalid_phone_len"};
      }
    } else if (targetCc === "KZ") {
      // Kazakhstan CIS domestic format starts with trunk 8 followed by 7xx (11 digits total) or 7xx (10 digits)
      if (subDigits.length === 11 && (subDigits.startsWith("87") || subDigits.startsWith("77"))) {
        subDigits = subDigits.slice(2);
      } else if (subDigits.length === 10 && subDigits.startsWith("7")) {
        subDigits = subDigits.slice(1);
      } else {
        return {status: "rejected_zoom_out_country"};
      }
      if (subDigits.length !== 9) return {status: "rejected_invalid_phone_len"};
    } else {
      if (subDigits.startsWith("0") && !subDigits.startsWith(phoneRule.dial)) {
        subDigits = subDigits.slice(1);
      } else if (subDigits.startsWith(phoneRule.dial) && subDigits.length >= phoneRule.dial.length + phoneRule.minNat) {
        subDigits = subDigits.slice(phoneRule.dial.length);
      }
      if (subDigits.length < phoneRule.minNat || subDigits.length > phoneRule.maxNat) {
        return {status: "rejected_invalid_phone_len"};
      }
    }

    // Block foreign country names when '+' was omitted
    for (const [label, cc] of Object.entries(WRONG_COUNTRY_BLOCK_NAMES)) {
      if (cc !== targetCc) {
        const rx = new RegExp(`\\b${label.replace(/_/gu, "\\s+")}\\b`, "iu");
        if (rx.test(fullText)) return {status: "rejected_zoom_out_country"};
      }
    }
  }

  let formattedRaw = trimmedPhone;
  if (targetCc === "TT" && !hadExplicitPlus) {
    if (rawDigits.length === 7) formattedRaw = `+1 868-${rawDigits.slice(0, 3)}-${rawDigits.slice(3)}`;
    else if (rawDigits.length === 10 && rawDigits.startsWith("868")) {
      formattedRaw = `+1 868-${rawDigits.slice(3, 6)}-${rawDigits.slice(6)}`;
    }
  } else if (targetCc === "KZ" && !hadExplicitPlus) {
    const kzSub = rawDigits.length === 11 ? rawDigits.slice(1) : rawDigits;
    formattedRaw = `+7 ${kzSub}`;
  }

  const phoneNorm = normalizeGlobalPhone(formattedRaw, targetCc);
  if (!phoneNorm.validPhone || !phoneNorm.digitsKey) return {status: "rejected_no_phone"};
  const validPrefix =
    phoneNorm.digitsKey.startsWith(phoneRule.dial) ||
    (targetCc === "TT" && phoneNorm.digitsKey.startsWith("868") && phoneNorm.digitsKey.length === 10);
  if (!validPrefix) return {status: "rejected_zoom_out_country"};
  if (indexState.blockedPhones.has(phoneNorm.digitsKey)) return {status: "rejected_blocked"};

  // 4. Intra-Country True-Hub Resolution & Local Verification
  let finalCity = task.city;
  let finalRc = task.regionCode;
  let regionNameOverride = task.regionNameOverride || "";
  const cityEsc = task.city.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&");
  const mentionsSearchedCity = new RegExp(`\\b${cityEsc}\\b`, "iu").test(fullText);

  if (!mentionsSearchedCity) {
    const countryHubs = INTL_HUBS_BY_COUNTRY.get(targetCc) || [];
    let matchedHub = null;
    for (const h of countryHubs) {
      const hEsc = h.city.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&");
      if (new RegExp(`\\b${hEsc}\\b`, "iu").test(fullText)) {
        matchedHub = h;
        break;
      }
    }
    if (matchedHub) {
      finalCity = matchedHub.city;
      finalRc = matchedHub.regionCode;
      regionNameOverride = matchedHub.regionNameOverride || "";
    } else if (!hadExplicitPlus && !phoneRule.countryRx.test(fullText)) {
      return {status: "rejected_unconfirmed_local"};
    }
  }

  // Extract street address
  let streetAddress = "";
  for (const line of card.lines) {
    if (/^\d[.,]\d\s*\(/u.test(line) || /^Open\b|^Closed\b|^Closes\b/iu.test(line)) continue;
    if (line.includes("·")) {
      const parts = line
        .split("·")
        .map((p) => p.replace(/\s+/gu, " ").trim())
        .filter(Boolean);
      if (parts.length >= 2) {
        const candidate = parts[parts.length - 1];
        if (candidate.length >= 5 && !/^\+?\d[\d\s()-]{6,}$/u.test(candidate)) {
          streetAddress = candidate.slice(0, 140);
          break;
        }
      }
    }
  }

  finalRc = canonicalizeRegionCode(finalRc, targetCc) || finalRc;
  finalCity = canonicalizeCityName(finalCity, finalRc, targetCc) || finalCity;
  const normName = normalizedCompanyName(cleanName);
  if (!normName) return {status: "rejected_invalid"};

  // 5. Deduplicate against existing Firestore + current session
  if (
    indexState.existingPhones.has(phoneNorm.digitsKey) ||
    indexState.existingNameRegion.has(`${normName}|${targetCc}|${finalRc}`)
  ) {
    return {status: "duplicate_existing"};
  }

  indexState.existingPhones.add(phoneNorm.digitsKey);
  indexState.existingNameRegion.add(`${normName}|${targetCc}|${finalRc}`);

  return finalizeDiscoveredRecord({
    card,
    task,
    cleanName,
    normName,
    targetCc,
    finalRc,
    regionNameOverride,
    finalCity,
    streetAddress,
    phoneDisplay: phoneNorm.display,
    isTollFree: Boolean(phoneNorm.isTollFree),
    phoneExternalId: phoneNorm.digitsKey,
    fullText,
    seqNum,
  });
}

function finalizeDiscoveredRecord({
  card,
  task,
  cleanName,
  normName,
  targetCc,
  finalRc,
  regionNameOverride,
  finalCity,
  streetAddress,
  phoneDisplay,
  isTollFree,
  phoneExternalId,
  fullText,
  seqNum,
}) {
  const website = cleanWebsiteUrl(card.website);
  const emergency24x7 = /\b(?:open\s+24\s+hours|24\/7|24\s*hr|aberto\s+24|abierto\s+24|døgnåpent)\b/iu.test(fullText);

  const gmapsTypeHint =
    card.lines.find((l) => l.includes("·") && !/^Open|^Closed/iu.test(l))?.split("·")[0]?.trim() || "";
  const rawHints = [cleanName, gmapsTypeHint, task.isTrainingQuery ? "Oilfield Safety Training Courses" : ""].filter(
    Boolean,
  );
  let catCodes = classifyCategoriesFromText(rawHints, fullText).filter(
    (c) => CATEGORY_BY_CODE.has(c) && (INCLUDE_TRAINING_CODE || c !== "oil_gas_training_courses"),
  );
  if (task.isTrainingQuery && INCLUDE_TRAINING_CODE && !catCodes.includes("oil_gas_training_courses")) {
    catCodes = ["oil_gas_training_courses", ...catCodes];
  }
  if (catCodes.length === 0) catCodes = [task.defaultCat];
  catCodes = [...new Set(catCodes)].slice(0, 6);
  const categories = catCodes.map((c) => CATEGORY_BY_CODE.get(c)?.label || c);

  const services = [];
  if (gmapsTypeHint && gmapsTypeHint.length <= 48 && !/^\d/u.test(gmapsTypeHint)) {
    services.push(gmapsTypeHint);
  }
  if (task.isTrainingQuery) {
    if (/\bh2s\b/iu.test(fullText)) services.push("H2S Safety Training");
    if (/\b(?:well\s+control|iwcf|wellsharp|iadc)\b/iu.test(fullText)) services.push("IWCF / IADC Well Control Training");
    if (/\b(?:opito|bosiet|foet|huet|cbsp|offshore)\b/iu.test(fullText)) {
      services.push("OPITO / BOSIET Offshore Survival Training");
    }
    if (/\b(?:irata|rope\s+access)\b/iu.test(fullText)) services.push("IRATA Rope Access Training");
    if (/\b(?:safeland|veriforce|rigpass)\b/iu.test(fullText)) services.push("SafeLand / RigPass Orientation");
    if (services.length <= 1) services.push("Oil & Gas Safety & Technical Courses");
  }

  const geo = inferCountryAndRegion(targetCc, finalRc);
  if (COUNTRY_BY_CODE.has(targetCc)) {
    geo.countryCode = targetCc;
    geo.countryName = COUNTRY_BY_CODE.get(targetCc).name;
  }
  if (regionNameOverride) geo.regionName = regionNameOverride;

  const certifications = extractCertifications(fullText);
  const nowIso = new Date().toISOString();
  const slug = normName.replace(/[^a-z0-9]+/gu, "-").replace(/^-+|-+$/gu, "").slice(0, 46);
  const companyId = `gmaps-${targetCc.toLowerCase()}-${finalRc.toLowerCase()}-${slug}-${phoneExternalId.slice(-4)}-${seqNum}`;

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
    services: [...new Set(services)].slice(0, 8),
    basins: geo.defaultBasins || [],
    serviceAreas: [finalCity, geo.regionName, geo.countryName].filter(Boolean),
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
        sourceName: `Google Maps ${targetCc} Alphabetical & Training Audit`,
        sourceUrl: card.placeUrl || "",
        sourceExternalId: phoneExternalId,
        observedAt: nowIso,
        bookPage: "",
      },
    ],
    liveAuditSummary: {
      auditedAt: nowIso,
      googleMapsActive: true,
      queryId: task.id,
      scope: SCOPE,
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
  await fsp.mkdir(LEDGER_DIR, {recursive: true});
  await fsp.mkdir(REPORTS_DIR, {recursive: true});

  const isIntl = SCOPE === "international";
  const checkpointPath = path.join(
    LEDGER_DIR,
    isIntl ? "16_intl_alpha_checkpoint.json" : "16_google_alpha_checkpoint.json",
  );
  const jsonlPath = path.join(
    LEDGER_DIR,
    isIntl ? "16_intl_alpha_discovered.jsonl" : "16_google_alpha_discovered.jsonl",
  );
  const indexCachePath = path.join(
    LEDGER_DIR,
    isIntl ? "16_intl_firestore_index_cache.json" : "16_na_firestore_index_cache.json",
  );
  const reportPath = path.join(
    REPORTS_DIR,
    isIntl ? "16_INTERNATIONAL_ALPHA_AUDIT_REPORT.md" : "16_GOOGLE_ALPHA_AUDIT_REPORT.md",
  );

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
  let priorStats = null;
  if (RESUME && fs.existsSync(checkpointPath)) {
    try {
      const cp = JSON.parse(await fsp.readFile(checkpointPath, "utf8"));
      visitedQueryIds = new Set(cp.visitedQueryIds || []);
      priorStats = cp.stats || null;
    } catch (_) {}
  }

  const fullQueue = isIntl ? buildInternationalSearchQueue() : buildNorthAmericaSearchQueue();
  const pendingQueue = fullQueue.filter((q) => !visitedQueryIds.has(q.id)).slice(0, MAX_QUERIES);

  if (pendingQueue.length === 0) {
    console.log(
      `[bot16] CONVERGED (${SCOPE})! 0 pending queries remaining (${visitedQueryIds.size}/${fullQueue.length} visited).`,
    );
    process.exit(0);
  }

  const indexState = await loadExistingFirestoreIndex(PROJECT_ID, indexCachePath, jsonlPath);

  console.log(
    `[bot16] Launching ${NUM_AGENTS} parallel Google Maps Audit Agents (${SCOPE}) | Wave: ${pendingQueue.length}/${fullQueue.length} (visited=${visitedQueryIds.size}, sync=${SYNC})...`,
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

  const stats = {
    startedAt: priorStats?.startedAt || new Date().toISOString(),
    queriesCompleted: priorStats?.queriesCompleted || 0,
    cardsInspected: priorStats?.cardsInspected || 0,
    newBusinessesDiscovered: priorStats?.newBusinessesDiscovered || 0,
    newCanada: priorStats?.newCanada || 0,
    newUSA: priorStats?.newUSA || 0,
    newUkNorway: priorStats?.newUkNorway || 0,
    newMiddleEast: priorStats?.newMiddleEast || 0,
    newLatinAmerica: priorStats?.newLatinAmerica || 0,
    newAustralia: priorStats?.newAustralia || 0,
    newAfrica: priorStats?.newAfrica || 0,
    newAsiaCaspian: priorStats?.newAsiaCaspian || 0,
    newTrainingFacilities: priorStats?.newTrainingFacilities || 0,
    duplicatesAlreadyInDb: priorStats?.duplicatesAlreadyInDb || 0,
    closedOnGoogleRemoved: priorStats?.closedOnGoogleRemoved || 0,
    rejectedNoiseOrZoomOut: priorStats?.rejectedNoiseOrZoomOut || 0,
    byCountry: {...(priorStats?.byCountry || {})},
    byRegion: {...(priorStats?.byRegion || {})},
  };

  let cursor = 0;
  let waveCompleted = 0;
  let seqCounter = Date.now() % 100000;
  const unsyncedBuffer = [];
  const closedExistingBuffer = [];
  let persistChain = Promise.resolve();

  const persistState = () => {
    persistChain = persistChain
      .then(async () => {
        if (SYNC && (unsyncedBuffer.length > 0 || closedExistingBuffer.length > 0)) {
          const toSync = unsyncedBuffer.splice(0, unsyncedBuffer.length);
          const toClose = closedExistingBuffer.splice(0, closedExistingBuffer.length);
          await syncBatchToFirestore(PROJECT_ID, toSync, toClose);
        }

        await fsp.writeFile(
          checkpointPath,
          JSON.stringify(
            {
              updatedAt: new Date().toISOString(),
              scope: SCOPE,
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

        const md = isIntl
          ? [
              "# Bot 16 — International Oil & Gas + Training Alphabetical (A–Z) Audit Dashboard",
              "",
              `- **Updated At**: \`${new Date().toISOString()}\``,
              `- **Active Parallel Agents**: **${NUM_AGENTS}** Chromium Google Maps Agents`,
              `- **International Queries Audited**: **${visitedQueryIds.size.toLocaleString()} / ${fullQueue.length.toLocaleString()}**`,
              `- **Google Business Cards Inspected**: **${stats.cardsInspected.toLocaleString()}**`,
              `- **Brand-New International Businesses Discovered**: **${stats.newBusinessesDiscovered.toLocaleString()}**`,
              `  - **UK / Norway & North Sea (\`GB\`, \`NO\`, \`NL\`, \`DE\`)**: **${stats.newUkNorway.toLocaleString()}**`,
              `  - **Middle East (\`AE\`, \`SA\`, \`QA\`, \`OM\`, \`KW\`, \`BH\`)**: **${stats.newMiddleEast.toLocaleString()}**`,
              `  - **Latin America (\`BR\`, \`MX\`, \`AR\`, \`CO\`, \`GY\`, \`TT\`)**: **${stats.newLatinAmerica.toLocaleString()}**`,
              `  - **Australia (\`AU\`)**: **${stats.newAustralia.toLocaleString()}**`,
              `  - **Africa (\`NG\`, \`AO\`, \`EG\`, \`GH\`, \`DZ\`, \`ZA\`, \`NA\`, \`MZ\`, \`GA\`, \`CG\`, \`CI\`, \`SN\`, \`UG\`, \`TZ\`, \`LY\`)**: **${stats.newAfrica.toLocaleString()}**`,
              `  - **Southeast, South & Central Asia (\`SG\`, \`MY\`, \`ID\`, \`BN\`, \`TH\`, \`VN\`, \`KZ\`, \`AZ\`, \`IN\`)**: **${stats.newAsiaCaspian.toLocaleString()}**`,
              `  - **International Oil & Gas Training Facilities & Courses**: **${stats.newTrainingFacilities.toLocaleString()}**`,
              `- **Already in PipeBuyer Directory (Verified Active)**: **${stats.duplicatesAlreadyInDb.toLocaleString()}**`,
              `- **Permanently Closed Businesses Caught on Google**: **${stats.closedOnGoogleRemoved.toLocaleString()}**`,
              `- **Consumer / Noise / Foreign Zoom-Out Cards Blocked**: **${stats.rejectedNoiseOrZoomOut.toLocaleString()}**`,
              "",
              "## New Businesses by Country",
              "",
              ...Object.entries(stats.byCountry)
                .sort((a, b) => b[1] - a[1])
                .map(([k, v]) => `- **\`${k}\`**: ${v.toLocaleString()} new businesses`),
              "",
              "## New Businesses by Sub-Region",
              "",
              ...Object.entries(stats.byRegion)
                .sort((a, b) => b[1] - a[1])
                .map(([k, v]) => `- **\`${k}\`**: ${v.toLocaleString()} new businesses`),
              "",
            ]
          : [
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
      })
      .catch((err) => console.warn(`[bot16] persistState warning: ${err.message}`));
    return persistChain;
  };

  const openFreshAgentSession = async () => {
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
    const workers = Array.from({length: NUM_AGENTS}, async (_, agentIdx) => {
      const agentName = `Agent-${agentIdx + 1}`;
      let session = await openFreshAgentSession();
      let queriesOnSession = 0;

      while (true) {
        const myIdx = cursor++;
        if (myIdx >= pendingQueue.length) break;
        const task = pendingQueue[myIdx];

        if (queriesOnSession >= 25) {
          await Promise.race([session.context.close().catch(() => {}), new Promise((r) => setTimeout(r, 2500))]);
          session = await openFreshAgentSession();
          queriesOnSession = 0;
        }

        try {
          let timerId = null;
          const cards = await Promise.race([
            scrapeGoogleMapsQuery(session.page, task),
            new Promise((_, reject) => {
              timerId = setTimeout(() => reject(new Error("Hard query watchdog 26000ms")), 26000);
            }),
          ]).finally(() => {
            if (timerId) clearTimeout(timerId);
          });
          queriesOnSession += 1;
          waveCompleted += 1;
          stats.queriesCompleted += 1;
          stats.cardsInspected += cards.length;
          visitedQueryIds.add(task.id);

          const jsonlLines = [];
          for (const card of cards) {
            seqCounter += 1;
            const res = isIntl
              ? validateAndBuildInternationalRecord(card, task, indexState, seqCounter)
              : validateAndBuildNorthAmericaRecord(card, task, indexState, seqCounter);
            if (res.status === "accepted") {
              stats.newBusinessesDiscovered += 1;
              const cc = res.privateRecord.countryCode;
              if (cc === "CA") stats.newCanada += 1;
              if (cc === "US") stats.newUSA += 1;
              if (task.corridor === "uk_norway") stats.newUkNorway += 1;
              if (task.corridor === "middle_east") stats.newMiddleEast += 1;
              if (task.corridor === "latin_america") stats.newLatinAmerica += 1;
              if (task.corridor === "australia") stats.newAustralia += 1;
              if (task.corridor === "africa") stats.newAfrica += 1;
              if (task.corridor === "asia_caspian") stats.newAsiaCaspian += 1;
              if (res.isTraining) stats.newTrainingFacilities += 1;
              stats.byCountry[cc] = (stats.byCountry[cc] || 0) + 1;
              const rk = `${cc}-${res.privateRecord.regionCode}`;
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

          if (waveCompleted % 20 === 0) {
            console.log(
              `[${agentName}] Wave ${waveCompleted}/${pendingQueue.length} (Total ${visitedQueryIds.size}/${fullQueue.length}) | Cards: ${stats.cardsInspected} | NEW: ${stats.newBusinessesDiscovered} (Training=${stats.newTrainingFacilities}) | Dups: ${stats.duplicatesAlreadyInDb}`,
            );
            await persistState();
          }
        } catch (err) {
          console.warn(`[${agentName}] Query error (${task.id}): ${err.message}`);
          visitedQueryIds.add(task.id);
          await Promise.race([session.context.close().catch(() => {}), new Promise((r) => setTimeout(r, 2500))]);
          session = await Promise.race([
            openFreshAgentSession(),
            new Promise((_, rej) => setTimeout(() => rej(new Error("reopen timeout")), 6000)),
          ]).catch(() => session);
          queriesOnSession = 0;
        }
      }

      await Promise.race([session.context.close().catch(() => {}), new Promise((r) => setTimeout(r, 2500))]);
    });

    await Promise.all(workers);
    await persistState();
  } finally {
    await Promise.race([browser.close().catch(() => {}), new Promise((r) => setTimeout(r, 3000))]);
  }

  console.log(`[bot16] Wave complete (${SCOPE})! Visited ${visitedQueryIds.size}/${fullQueue.length}:`, stats);
  process.exit(0);
}

main().catch((err) => {
  console.error("[bot16] FATAL:", err);
  process.exit(1);
});
