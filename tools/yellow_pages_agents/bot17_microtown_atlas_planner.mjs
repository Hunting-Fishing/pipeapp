#!/usr/bin/env node
/**
 * Bot 17 — North America (Canada -> USA) Micro-Town Atlas & Adaptive Frontier Planner
 *
 * Merges:
 *   1. Curated Unlisted Oilpatch Micro-Town Atlas (680+ Canadian & US rural field towns,
 *      pipeline terminals, well-servicing bases, and offshore ports).
 *   2. Live Firestore `yellow_pages_meta/directory_counts` (`townsPacked` — 2,670+ proven
 *      North American towns).
 *   3. Dynamic rural towns mined from Google Maps street addresses during Bot 18 waves.
 *
 * Maintains a 4-Stage Adaptive Yield Escalation State Machine per micro-town so the
 * multi-agent fleet runs autonomously UNTIL ZERO NEW BUSINESSES EMERGE:
 *   - Stage 1 (`PROBE` — 3 queries): Broad Oilfield, Safety/Training, Trucking/Hydrovac/Welding.
 *       -> Escalates to Stage 2 if `newBusinesses >= 1` or `localCards >= 2`; else `EXHAUSTED`.
 *   - Stage 2 (`SECTOR_SWEEP` — 15 queries): Core oilfield & accredited training sectors.
 *       -> Escalates to Stage 3 if `newBusinesses >= 1`; else `EXHAUSTED`.
 *   - Stage 3 (`ALPHA_SWEEP` — 26 `A->Z` queries): Strict alphabetical sweep in `<Town>, <Region>`.
 *       -> Escalates to Stage 4 if `newBusinesses >= 3`; else `EXHAUSTED`.
 *   - Stage 4 (`EXTENDED_SYNONYM_TAIL` — 10 queries): Long-tail field crews & technical schools
 *       -> Transitions to `EXHAUSTED`.
 */

import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";
import {resolveAccessToken} from "./global_shared_utils.mjs";

const require = createRequire(import.meta.url);
const {
  canonicalizeCityName,
  canonicalizeRegionCode,
  normalizeCityKey,
} = require("../../firebase/functions/yellow_pages_taxonomy.js");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const LEDGER_DIR = path.join(REPO_ROOT, "data/yellow_pages/ledger");
const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");

export const STATE_PATH = path.join(LEDGER_DIR, "17_microtown_frontier_state.json");
export const QUEUE_PATH = path.join(LEDGER_DIR, "17_microtown_pending_queue.json");
export const DYNAMIC_TOWNS_PATH = path.join(LEDGER_DIR, "18_dynamic_discovered_towns.jsonl");
export const PLAN_REPORT_PATH = path.join(REPORTS_DIR, "17_MICROTOWN_PLAN_REPORT.md");

const args = process.argv.slice(2);
const projIdx = args.indexOf("--project");
const PROJECT_ID = projIdx !== -1 && args[projIdx + 1] ? args[projIdx + 1] : "flutter-flow-pipe";
const RESET = args.includes("--reset");

// Already exhausted in Bot 16 Tier 1/2 sweep (kept in known-town dictionary for True-Town geo resolution)
export const BOT16_COMPLETED_HUBS = [
  // Canada (47)
  ["CA", "AB", "Grande Prairie"], ["CA", "AB", "Nisku"], ["CA", "AB", "Edmonton"], ["CA", "AB", "Calgary"],
  ["CA", "AB", "Red Deer"], ["CA", "AB", "Fort McMurray"], ["CA", "BC", "Fort St. John"], ["CA", "SK", "Estevan"],
  ["CA", "AB", "Lloydminster"], ["CA", "AB", "Drayton Valley"], ["CA", "AB", "Bonnyville"], ["CA", "AB", "Leduc"],
  ["CA", "AB", "Acheson"], ["CA", "AB", "Whitecourt"], ["CA", "AB", "Brooks"], ["CA", "AB", "Medicine Hat"],
  ["CA", "AB", "Rocky Mountain House"], ["CA", "AB", "Cold Lake"], ["CA", "AB", "Edson"], ["CA", "AB", "Hinton"],
  ["CA", "AB", "Fox Creek"], ["CA", "AB", "Slave Lake"], ["CA", "AB", "Peace River"], ["CA", "AB", "High Level"],
  ["CA", "AB", "Sylvan Lake"], ["CA", "AB", "Sherwood Park"], ["CA", "AB", "Fort Saskatchewan"], ["CA", "AB", "Stettler"],
  ["CA", "AB", "Provost"], ["CA", "AB", "Wainwright"], ["CA", "AB", "Lac La Biche"], ["CA", "AB", "Sundre"],
  ["CA", "AB", "Taber"], ["CA", "AB", "Lethbridge"], ["CA", "BC", "Dawson Creek"], ["CA", "BC", "Fort Nelson"],
  ["CA", "BC", "Kitimat"], ["CA", "SK", "Weyburn"], ["CA", "SK", "Kindersley"], ["CA", "SK", "Swift Current"],
  ["CA", "SK", "Saskatoon"], ["CA", "SK", "Regina"], ["CA", "MB", "Virden"], ["CA", "NL", "St. John's"],
  ["CA", "NS", "Dartmouth"], ["CA", "ON", "Sarnia"],
  // USA (58)
  ["US", "TX", "Midland"], ["US", "TX", "Odessa"], ["US", "TX", "Houston"], ["US", "ND", "Williston"],
  ["US", "OK", "Oklahoma City"], ["US", "LA", "Lafayette"], ["US", "NM", "Hobbs"], ["US", "WY", "Casper"],
  ["US", "TX", "Corpus Christi"], ["US", "TX", "Kilgore"], ["US", "TX", "Pecos"], ["US", "CO", "Greeley"],
  ["US", "PA", "Canonsburg"], ["US", "CA", "Bakersfield"], ["US", "OK", "Tulsa"], ["US", "LA", "Houma"],
  ["US", "LA", "Broussard"], ["US", "LA", "Shreveport"], ["US", "LA", "Lake Charles"], ["US", "NM", "Carlsbad"],
  ["US", "NM", "Farmington"], ["US", "ND", "Watford City"], ["US", "ND", "Dickinson"], ["US", "WY", "Gillette"],
  ["US", "WY", "Rock Springs"], ["US", "OK", "Elk City"], ["US", "OK", "Enid"], ["US", "OK", "Woodward"],
  ["US", "TX", "Andrews"], ["US", "TX", "Big Spring"], ["US", "TX", "Snyder"], ["US", "TX", "San Angelo"],
  ["US", "TX", "Pleasanton"], ["US", "TX", "Alice"], ["US", "TX", "Victoria"], ["US", "TX", "Longview"],
  ["US", "TX", "Wichita Falls"], ["US", "TX", "Beaumont"], ["US", "TX", "La Porte"], ["US", "TX", "Conroe"],
  ["US", "CO", "Grand Junction"], ["US", "CO", "Fort Lupton"], ["US", "CO", "Denver"], ["US", "PA", "Williamsport"],
  ["US", "PA", "Pittsburgh"], ["US", "WV", "Morgantown"], ["US", "WV", "Bridgeport"], ["US", "OH", "Canton"],
  ["US", "OH", "Cambridge"], ["US", "AK", "Anchorage"], ["US", "AK", "Kenai"], ["US", "MT", "Sidney"],
  ["US", "MT", "Billings"], ["US", "UT", "Vernal"], ["US", "KS", "Great Bend"], ["US", "AR", "Fort Smith"],
  ["US", "AR", "El Dorado"], ["US", "MS", "Laurel"],
];

// Curated North American Oilpatch Micro-Town Atlas (CA first, US second)
export const CURATED_MICROTOWN_ATLAS = {
  "CA:AB": [
    "Valleyview", "Beaverlodge", "Wembley", "Sexsmith", "Clairmont", "Hythe", "La Glace", "Grimshaw", "Fairview",
    "Spirit River", "Rycroft", "Manning", "Rainbow Lake", "Zama City", "Swan Hills", "Mayerthorpe", "Barrhead",
    "Westlock", "Athabasca", "Boyle", "Smoky Lake", "Redwater", "Gibbons", "Bon Accord", "Morinville", "Bruderheim",
    "Lamont", "Vegreville", "Two Hills", "Vermilion", "Kitscoty", "Blackfoot", "Elk Point", "St. Paul", "Plamondon",
    "Conklin", "Anzac", "Janvier", "Calling Lake", "Wabasca", "Red Earth Creek", "Devon", "Calmar", "Thorsby",
    "Breton", "Warburg", "Spruce Grove", "Stony Plain", "Entwistle", "Evansburg", "Wildwood", "Cynthia", "Lodgepole",
    "Camrose", "Wetaskiwin", "Ponoka", "Lacombe", "Blackfalds", "Innisfail", "Bowden", "Olds", "Didsbury",
    "Carstairs", "Crossfield", "Airdrie", "Cochrane", "Strathmore", "Okotoks", "High River", "Diamond Valley",
    "Turner Valley", "Black Diamond", "Nanton", "Claresholm", "Fort Macleod", "Pincher Creek", "Blairmore",
    "Vauxhall", "Bow Island", "Redcliff", "Bassano", "Hanna", "Drumheller", "Three Hills", "Trochu", "Castor",
    "Coronation", "Consort", "Veteran", "Hardisty", "Hughenden", "Czar", "Irma", "Chauvin", "Edgerton", "Killam",
    "Sedgewick", "Forestburg", "Viking", "Tofield", "Ryley", "Caroline", "Eckville", "Rimbey", "Bentley", "Alix",
    "Clive", "Mirror", "Delburne", "Big Valley", "Oyen", "Empress", "Jenner",
  ],
  "CA:SK": [
    "Carnduff", "Oxbow", "Carlyle", "Alameda", "Lampman", "Bienfait", "Midale", "Stoughton", "Redvers", "Arcola",
    "Kisbey", "Kipling", "Wawota", "Moosomin", "Rocanville", "Fleming", "Maryfield", "Radville", "Pangman",
    "Assiniboia", "Shaunavon", "Gull Lake", "Maple Creek", "Cabri", "Pennant", "Success", "Leader", "Eatonia",
    "Eston", "Coleville", "Dodsland", "Plenty", "Kerrobert", "Luseland", "Macklin", "Denzil", "Unity", "Wilkie",
    "Biggar", "Rosetown", "Elrose", "Kyle", "Maidstone", "Lashburn", "Marshall", "Waseca", "Paynton", "Neilburg",
    "Marsden", "Edam", "Vawn", "Meota", "Turtleford", "Spruce Lake", "St. Walburg", "Paradise Hill", "Loon Lake",
    "Pierceland", "Meadow Lake", "North Battleford", "Battleford", "Humboldt", "Lanigan", "Moose Jaw", "Belle Plaine",
  ],
  "CA:BC": [
    "Taylor", "Charlie Lake", "Chetwynd", "Tumbler Ridge", "Hudson's Hope", "Pouce Coupe", "Rolla", "Buick",
    "Prespatou", "Wonowon", "Pink Mountain", "Prophet River", "Toad River", "Mackenzie", "Prince George",
    "Vanderhoof", "Burns Lake", "Houston", "Smithers", "Terrace", "Prince Rupert", "Kamloops", "Clearwater",
    "Valemount", "Blue River", "Hope", "Chilliwack", "Abbotsford", "Langley", "Burnaby", "Delta", "Squamish",
    "Sparwood", "Elkford", "Fernie", "Cranbrook",
  ],
  "CA:MB": [
    "Melita", "Pierson", "Waskada", "Deloraine", "Reston", "Pipestone", "Cromer", "Sinclair", "Elkhorn", "Kola",
    "Miniota", "Hamiota", "Oak Lake", "Souris", "Hartney", "Boissevain", "Killarney", "Brandon", "Minnedosa",
    "Neepawa", "Portage la Prairie", "Winkler", "Morden", "Altona", "Steinbach", "Selkirk", "Winnipeg",
  ],
  "CA:ON": [
    "Petrolia", "Oil Springs", "Corunna", "Courtright", "Mooretown", "Brigden", "Wyoming", "Watford", "Wallaceburg",
    "Dresden", "Chatham", "Tilbury", "Blenheim", "Leamington", "Windsor", "Strathroy", "London", "St. Thomas",
    "Aylmer", "Tillsonburg", "Simcoe", "Nanticoke", "Port Colborne", "Welland", "Hamilton", "Burlington", "Oakville",
    "Mississauga", "Brampton", "Vaughan", "Oshawa", "Sudbury", "Thunder Bay",
  ],
  "CA:NL": [
    "Mount Pearl", "Paradise", "Conception Bay South", "Torbay", "Portugal Cove", "Bay Bulls", "Witless Bay",
    "Placentia", "Argentia", "Long Harbour", "Come By Chance", "Arnold's Cove", "Clarenville", "Marystown",
    "Burin", "Grand Falls-Windsor", "Gander", "Deer Lake", "Corner Brook", "Stephenville",
  ],
  "CA:NS": [
    "Halifax", "Bedford", "Lower Sackville", "Burnside", "Truro", "New Glasgow", "Stellarton", "Antigonish",
    "Port Hawkesbury", "Point Tupper", "Mulgrave", "Sydney", "North Sydney", "Glace Bay", "Goldboro",
  ],
  "CA:NB": ["Saint John", "Moncton", "Dieppe", "Sussex", "Bathurst", "Miramichi", "Fredericton", "Edmundston"],
  "CA:NT": ["Norman Wells", "Inuvik", "Tuktoyaktuk", "Hay River", "Fort Simpson", "Fort Liard", "Yellowknife"],
  "CA:QC": ["Montreal-Est", "Varennes", "Sorel-Tracy", "Becancour", "Trois-Rivieres", "Levis", "Sept-Iles"],

  // USA Core Oilpatch Micro-Towns
  "US:TX": [
    "Kermit", "Monahans", "Crane", "McCamey", "Rankin", "Iraan", "Sheffield", "Ozona", "Sonora", "Eldorado",
    "Barnhart", "Big Lake", "Mertzon", "Sterling City", "Garden City", "Stanton", "Lenorah", "Ackerly", "Coahoma",
    "Forsan", "Westbrook", "Colorado City", "Sweetwater", "Roscoe", "Merkel", "Abilene", "Clyde", "Baird", "Cisco",
    "Eastland", "Ranger", "Strawn", "Breckenridge", "Albany", "Anson", "Hamlin", "Stamford", "Haskell", "Seymour",
    "Graham", "Olney", "Jacksboro", "Bridgeport", "Chico", "Alvord", "Decatur", "Bowie", "Nocona", "Saint Jo",
    "Muenster", "Gainesville", "Whitesboro", "Sherman", "Denton", "Justin", "Krum", "Sanger", "Springtown",
    "Weatherford", "Mineral Wells", "Granbury", "Tolar", "Glen Rose", "Cleburne", "Joshua", "Alvarado", "Burleson",
    "Stephenville", "Comanche", "Brownwood", "Coleman", "Ballinger", "Winters", "Miles", "Wall", "Seminole",
    "Seagraves", "Denver City", "Plains", "Sundown", "Levelland", "Brownfield", "Meadow", "Ropesville", "Lubbock",
    "Slaton", "Post", "Tahoka", "O'Donnell", "Lamesa", "Welch", "Gail", "Jayton", "Snyder", "Hermleigh",
    "Orla", "Mentone", "Pyote", "Wink", "Barstow", "Toyah", "Balmorhea", "Fort Stockton", "Sanderson", "Imperial",
    "Coyanosa", "Grandfalls", "Goldsmith", "Gardendale", "Greenwood", "Amarillo", "Canyon", "Hereford", "Dumas",
    "Sunray", "Stratford", "Dalhart", "Spearman", "Gruver", "Stinnett", "Fritch", "Borger", "Skellytown", "Pampa",
    "Lefors", "McLean", "Shamrock", "Wheeler", "Mobeetie", "Allison", "Briscoe", "Canadian", "Miami", "Perryton",
    "Booker", "Darrouzett", "Follett", "Higgins", "Childress", "Vernon", "Electra", "Iowa Park", "Burkburnett",
    "Henrietta", "Archer City", "Holliday", "Windthorst", "Karnes City", "Kenedy", "Runge", "Falls City", "Poth",
    "Floresville", "Stockdale", "Nixon", "Smiley", "Westhoff", "Cuero", "Yorktown", "Nordheim", "Meyersville",
    "Goliad", "Gonzales", "Waelder", "Shiner", "Yoakum", "Hallettsville", "Moulton", "Flatonia", "Schulenburg",
    "Weimar", "Columbus", "La Grange", "Giddings", "Caldwell", "Somerville", "Brenham", "Bryan", "College Station",
    "Hearne", "Madisonville", "Huntsville", "Jourdanton", "Pleasanton", "Poteet", "Charlotte", "Christine", "Tilden",
    "Calliham", "Three Rivers", "George West", "Beeville", "Skidmore", "Pettus", "Tuleta", "Kenedy", "Refugio",
    "Woodsboro", "Bayside", "Sinton", "Odem", "Taft", "Gregory", "Portland", "Ingleside", "Aransas Pass", "Mathis",
    "Orange Grove", "Agua Dulce", "Banquete", "Robstown", "Bishop", "Driscoll", "Kingsville", "Riviera", "Premont",
    "Falfurrias", "San Diego", "Benavides", "Freer", "Bruni", "Mirando City", "Oilton", "Hebbronville", "Zapata",
    "Laredo", "Encinal", "Cotulla", "Millett", "Dilley", "Pearsall", "Moore", "Devine", "Natalia", "Lytle", "Hondo",
    "Sabinal", "Uvalde", "Batesville", "La Pryor", "Crystal City", "Carrizo Springs", "Asherton", "Big Wells",
    "Catarina", "Eagle Pass", "Carthage", "Beckville", "Tatum", "Henderson", "Overton", "New London", "Arp",
    "Troup", "Whitehouse", "Tyler", "Lindale", "Mineola", "Quitman", "Winnsboro", "Gilmer", "Gladewater",
    "White Oak", "Hallsville", "Marshall", "Waskom", "Uncertain", "Jefferson", "Linden", "Atlanta", "Texarkana",
    "Mount Pleasant", "Pittsburg", "Daingerfield", "Sulphur Springs", "Athens", "Malakoff", "Trinidad", "Corsicana",
    "Fairfield", "Teague", "Mexia", "Groesbeck", "Buffalo", "Centerville", "Jewett", "Palestine", "Elkhart",
    "Grapeland", "Crockett", "Jacksonville", "Rusk", "Nacogdoches", "Garrison", "Timpson", "Tenaha", "Center",
    "Joaquin", "Logansport", "San Augustine", "Hemphill", "Lufkin", "Diboll", "Jasper", "Woodville", "Livingston",
    "Cleveland", "Dayton", "Liberty", "Daisetta", "Hull", "Hardin", "Sour Lake", "Silsbee", "Lumberton", "Vidor",
    "Orange", "Bridge City", "Port Neches", "Groves", "Nederland", "Port Arthur", "Sabine Pass", "Winnie", "Anahuac",
    "Mont Belvieu", "Baytown", "Highlands", "Channelview", "Sheldon", "Crosby", "Huffman", "Humble", "Kingwood",
    "Spring", "Tomball", "Magnolia", "Waller", "Hockley", "Katy", "Brookshire", "Sealy", "Rosenberg", "Richmond",
    "Sugar Land", "Stafford", "Missouri City", "Pearland", "Manvel", "Alvin", "Rosharon", "Santa Fe", "Hitchcock",
    "La Marque", "Texas City", "Dickinson", "League City", "Seabrook", "Kemah", "Pasadena", "Deer Park", "Galena Park",
    "South Houston", "Galveston", "Pelican Island", "Angleton", "Danbury", "Brazoria", "West Columbia", "Sweeny",
    "Old Ocean", "Clute", "Lake Jackson", "Freeport", "Surfside Beach", "Quintana", "Bay City", "Wadsworth",
    "Matagorda", "Palacios", "Port Lavaca", "Point Comfort", "Seadrift", "bloomington", "Edna", "Ganado", "Louise",
    "El Campo", "Wharton", "Boling", "East Bernard", "Eagle Lake",
  ],
  "US:NM": [
    "Jal", "Eunice", "Monument", "Nadine", "Knowles", "Lovington", "Tatum", "Maljamar", "Loco Hills", "Artesia",
    "Atoka", "Lake Arthur", "Hagerman", "Dexter", "Roswell", "Loving", "Malaga", "Otis", "Whites City", "Portales",
    "Clovis", "Tucumcari", "Santa Rosa", "Vaughn", "Aztec", "Flora Vista", "Bloomfield", "Blanco", "Navajo Dam",
    "Kirtland", "Waterflow", "Shiprock", "Cuba", "Counselor", "Lybrook", "Nageezi", "Gallup", "Grants", "Milan",
  ],
  "US:OK": [
    "Cushing", "Drumright", "Oilton", "Yale", "Cleveland", "Hominy", "Pawhuska", "Barnsdall", "Dewey", "Bartlesville",
    "Nowata", "Skiatook", "Collinsville", "Owasso", "Catoosa", "Claremore", "Pryor", "Sand Springs", "Sapulpa",
    "Kiefer", "Mounds", "Glenpool", "Bixby", "Broken Arrow", "Coweta", "Wagoner", "Muskogee", "Okmulgee", "Beggs",
    "Morris", "Henryetta", "Weleetka", "Okemah", "Bristow", "Depew", "Stroud", "Davenport", "Chandler", "Wellston",
    "Luther", "Prague", "Meeker", "Shawnee", "Tecumseh", "Maud", "Konawa", "Seminole", "Wewoka", "Holdenville",
    "Wetumka", "Allen", "Ada", "Stratford", "Byng", "Stonewall", "Coalgate", "Atoka", "Durant", "Madill", "Kingston",
    "Marietta", "Thackerville", "Ardmore", "Lone Grove", "Wilson", "Healdton", "Ringling", "aurika", "Waurika",
    "Ryan", "Comanche", "Duncan", "Marlow", "Bray", "Velma", "Countyline", "Ratliff City", "Tatums", "Elmore City",
    "Maysville", "Pauls Valley", "Wynnewood", "Davis", "Sulphur", "Lindsay", "Alex", "Bradley", "Blanchard",
    "Newcastle", "Tuttle", "Amber", "Pocasset", "Chickasha", "Ninnekah", "Rush Springs", "Cyril", "Cement", "Apache",
    "Anadarko", "Carnegie", "Fort Cobb", "Binger", "Hinton", "Geary", "Calumet", "El Reno", "Union City", "Minco",
    "Mustang", "Yukon", "Piedmont", "Cashion", "Okarche", "Kingfisher", "Dover", "Hennessey", "Loyal", "Okeene",
    "Watonga", "canton", "Seiling", "Taloga", "Putnam", "Thomas", "Custer City", "Arapaho", "Clinton", "Weatherford",
    "Hydro", "Cordell", "Burns Flat", "Canute", "Foss", "Sayre", "Erick", "Texola", "Sweetwater", "Reydon",
    "Cheyenne", "Hammon", "Leedey", "Rhea", "Vici", "Camargo", "Sharon", "Mutual", "Mooreland", "Waynoka", "Alva",
    "Cherokee", "Helena", "Ringwood", "Lahoma", "Garber", "Covington", "Marshall", "Crescent", "Guthrie", "Mulhall",
    "Orlando", "Perry", "Billings", "Tonkawa", "Blackwell", "Braman", "Newkirk", "Ponca City", "Fairfax", "Pawnee",
    "Stillwater", "Perkins", "Cushing", "Shattuck", "Gage", "Fargo", "Arnett", "Laverne", "Buffalo", "Slapout",
    "Beaver", "Forgan", "Turpin", "Balko", "Elmwood", "Hooker", "Tyrone", "Guymon", "Goodwell", "Texhoma", "Boise City",
    "McAlester", "Hartshorne", "Haileyville", "Wilburton", "Red Oak", "Panola", "Stigler", "Keota", "Spiro", "Poteau",
  ],
  "US:ND": [
    "Tioga", "Ray", "Wheelock", "Epping", "Springbrook", "Trenton", "Alexander", "Rawson", "Arnegard", "Keene",
    "Mandaree", "New Town", "Sanish", "Parshall", "Plaza", "Makoti", "Ryder", "Stanley", "Ross", "Palermo",
    "Berthold", "Carpio", "Burlington", "Minot", "Surrey", "Velva", "Granville", "Towner", "Bottineau", "Westhope",
    "Newburg", "Maxbass", "Lansford", "Glenburn", "Mohall", "Sherwood", "Tolley", "Kenmare", "Bowbells", "Flaxton",
    "Lignite", "Portal", "Columbus", "Noonan", "Crosby", "Ambrose", "Fortuna", "Grenora", "Zahl", "Wildrose",
    "Powers Lake", "McGregor", "Killdeer", "Manning", "Dunn Center", "Halliday", "Dodge", "Golden Valley", "Zap",
    "Beulah", "Hazen", "Stanton", "Washburn", "Underwood", "Garrison", "Max", "Turtle Lake", "South Heart",
    "Belfield", "Fryburg", "Medora", "Sentinel Butte", "Beach", "Golva", "New England", "Regent", "Mott", "Hettinger",
    "Reeder", "Scranton", "Gascoyne", "Bowman", "Rhame", "Marmarth", "Amidon",
  ],
  "US:LA": [
    "Scott", "Duson", "Rayne", "Crowley", "Egan", "Iota", "Evangeline", "Jennings", "Roanoke", "Welsh", "Iowa",
    "Sulphur", "Westlake", "Vinton", "Starks", "DeQuincy", "moss Bluff", "Hackberry", "Cameron", "Creole",
    "Grand Chenier", "Kaplan", "Gueydan", "Lake Arthur", "Abbeville", "Erath", "Delcambre", "Maurice", "Milton",
    "Youngsville", "Carencro", "Sunset", "Grand Coteau", "Opelousas", "Port Barre", "Krotz Springs", "Eunice",
    "Mamou", "Ville Platte", "Breaux Bridge", "Parks", "St. Martinville", "Cade", "New Iberia", "Lydia", "Jeanerette",
    "Baldwin", "Charenton", "Franklin", "Centerville", "Garden City", "Patterson", "Bayou Vista", "Berwick",
    "Morgan City", "Amelia", "Gibson", "Donner", "Chacahoula", "Schriever", "Gray", "Thibodaux", "Labadieville",
    "Napoleonville", "Pierre Part", "Belle River", "Raceland", "Mathews", "Lockport", "Larose", "Cut Off",
    "Galliano", "Golden Meadow", "Leeville", "Port Fourchon", "Grand Isle", "Montegut", "Chauvin", "Dulac",
    "Theriot", "Cocodrie", "Bourg", "Des Allemands", "Paradis", "Boutte", "Luling", "Hahnville", "Destrehan",
    "St. Rose", "Norco", "LaPlace", "Reserve", "Garyville", "Gramercy", "Lutcher", "Convent", "Uncle Sam",
    "Donaldsonville", "Gonzales", "Geismar", "St. Gabriel", "Sunshine", "Plaquemine", "Addis", "Brusly", "Port Allen",
    "Baton Rouge", "Zachary", "Baker", "Westwego", "Marrero", "Harvey", "Gretna", "Terrytown", "Belle Chasse",
    "Jesuit Bend", "Alliance", "Myrtle Grove", "Port Sulphur", "Empire", "Buras", "Boothville", "Venice", "Chalmette",
    "Violet", "Poydras", "St. Bernard", "Bossier City", "Benton", "Plain Dealing", "Haughton", "Princeton", "Doyline",
    "Minden", "Sibley", "Dubberly", "Heflin", "Cotton Valley", "Sarepta", "Springhill", "Cullen", "Shongaloo",
    "Haynesville", "Homer", "Lisbon", "Athens", "Arcadia", "Gibsland", "Ringgold", "Castor", "Coushatta", "Hall Summit",
    "East Point", "Grand Cane", "Mansfield", "Stonewall", "Frierson", "Keachi", "Logansport", "Stanley", "Pelican",
    "Pleasant Hill", "Zwolle", "Many", "Converse", "Noble", "anchard", "Blanchard", "Mooringsport", "Oil City",
    "Vivian", "Rodessa", "Hosston", "Gilliam", "Belcher", "Greenwood", "Keithville", "Natchitoches", "Campti",
    "Clarence", "Winnfield", "Tullos", "Urania", "Olla", "Jena", "Jonesville", "Ferriday", "Vidalia", "Monterey",
    "Ruston", "Simsboro", "Grambling", "Choudrant", "Calhoun", "West Monroe", "Monroe", "Sterlington", "Bastrop",
    "Farmerville", "Bernice", "Dubach",
  ],
  "US:WY": [
    "Douglas", "Glenrock", "Rolling Hills", "Evansville", "Mills", "Bar Nunn", "Midwest", "Edgerton", "Kaycee",
    "Buffalo", "Sheridan", "Ranchester", "Dayton", "Wright", "Reno Junction", "Rozet", "Moorcroft", "Pine Haven",
    "Sundance", "Hulett", "Upton", "Osage", "Newcastle", "Lusk", "Manville", "Lance Creek", "Guernsey", "Wheatland",
    "Chugwater", "Torrington", "Pine Bluffs", "Burns", "Cheyenne", "Laramie", "Medicine Bow", "Hanna", "Sinclair",
    "Rawlins", "Bairoil", "Wamsutter", "Table Rock", "Point of Rocks", "Superior", "Reliance", "Green River",
    "James Town", "Granger", "Little America", "Lyman", "Mountain View", "Fort Bridger", "Robertson", "Evanston",
    "Bear River", "Opal", "Diamondville", "Kemmerer", "Frontier", "La Barge", "Big Piney", "Marbleton", "Daniel",
    "Boulder", "Pinedale", "Farson", "Eden", "Lander", "Hudson", "Riverton", "Arapahoe", "St. Stephens", "Pavillion",
    "Kinnear", "Morton", "Dubois", "Shoshoni", "Lysite", "Lost Cabin", "Thermopolis", "Kirby", "Lucerne", "Worland",
    "Ten Sleep", "Manderson", "Basin", "Greybull", "Emblem", "Burlington", "Otto", "Lovell", "Byron", "Cowley",
    "Deaver", "Frannie", "Powell", "Ralston", "Cody", "Meeteetse",
  ],
  "US:CO": [
    "Brighton", "Henderson", "Commerce City", "Thornton", "Dacono", "Frederick", "Firestone", "Mead", "Erie",
    "Longmont", "Berthoud", "Loveland", "Johnstown", "Milliken", "Gilcrest", "Platteville", "Ione", "Aristocrat Ranchettes",
    "Hudson", "Lochbuie", "Keenesburg", "Roggen", "Wiggins", "Orchard", "Weldona", "Fort Morgan", "Log Lane Village",
    "Brush", "Hillrose", "Merino", "Atwood", "Sterling", "Iliff", "Crook", "Sedgwick", "Julesburg", "Fleming",
    "Haxtun", "Holyoke", "Akron", "Otis", "Yuma", "Eckley", "Wray", "Idalia", "Byers", "Strasburg", "Bennett",
    "Watkins", "Deer Trail", "Agate", "Limon", "Hugo", "Cheyenne Wells", "Kit Carson", "Eads", "Lamar", "LaSalle",
    "Evans", "Garden City", "Kersey", "Gill", "Galeton", "Eaton", "Lucerne", "Ault", "Pierce", "Nunn", "Carr",
    "Briggsdale", "Grover", "Hereford", "New Raymer", "Stoneham", "Windsor", "Severance", "Timnath", "Wellington",
    "Fort Collins", "Rifle", "Silt", "New Castle", "Glenwood Springs", "Carbondale", "Parachute", "Battlement Mesa",
    "De Beque", "Collbran", "Mesa", "Palisade", "Clifton", "Fruita", "Loma", "Mack", "Meeker", "Dinosaur", "Rangely",
    "Maybell", "Craig", "Hayden", "Steamboat Springs", "Oak Creek", "Delta", "Montrose", "Cortez", "Mancos",
    "Dolores", "Dove Creek", "Ignacio", "Bayfield", "Durango", "Trinidad", "Aguilar", "Walsenburg",
  ],
  "US:UT": [
    "Roosevelt", "Ballard", "Ft. Duchesne", "Fort Duchesne", "Randlett", "gusher", "Myton", "Bridgeland", "Duchesne",
    "Fruitland", "Tabiona", "Altamont", "Bluebell", "Neola", "Whiterocks", "Lapoint", "Maeser", "Naples", "Jensen",
    "Bonanza", "Ouray", "Wellington", "Price", "Helper", "Spring Glen", "Carbonville", "East Carbon", "Sunnyside",
    "Huntington", "Cleveland", "Elmo", "Castle Dale", "Orangeville", "Ferron", "Emery", "Green River", "Thompson Springs",
    "Moab", "Spanish Valley", "La Sal", "Monticello", "Blanding", "Bluff", "Mexican Hat", "Aneth", "Montezuma Creek",
    "Coalville", "Kamas", "Evanston", "Woods Cross", "North Salt Lake",
  ],
  "US:PA": [
    "Southpointe", "Cecil", "McDonald", "Midway", "Burgettstown", "Avella", "Hickory", "Houston", "Meadow Lands",
    "Washington", "Claysville", "West Alexander", "Amity", "Prosperity", "Bentleyville", "Eighty Four", "Finleyville",
    "Monongahela", "Donora", "Charleroi", "Belle Vernon", "California", "Centerville", "Fredericktown", "Waynesburg",
    "Morrisville", "Jefferson", "Mather", "Clarksville", "Carmichaels", "Crucible", "Nemacolin", "Greensboro",
    "Mt. Morris", "Mount Morris", "Spraggs", "Holbrook", "Graysville", "Wind Ridge", "Uniontown", "Hopwood", "Fairchance",
    "Smithfield", "Point Marion", "Masontown", "McClellandtown", "Brownsville", "Grindstone", "Perryopolis", "Connellsville",
    "Dunbar", "Mt. Pleasant", "Mount Pleasant", "Scottdale", "New Stanton", "Youngwood", "Greensburg", "Latrobe",
    "Blairsville", "Homer City", "Indiana", "Clymer", "Marion Center", "Punxsutawney", "Reynoldsville", "Brookville",
    "Clarion", "Knox", "Shippenville", "New Bethlehem", "Rimersburg", "East Brady", "Kittanning", "Ford City",
    "Worthington", "Freeport", "Leechburg", "Apollo", "Vandergrift", "Butler", "Lyndora", "East Butler", "Chicora",
    "Karns City", "Petrolia", "Bruin", "Parker", "Emlenton", "Eau Claire", "Slippery Rock", "Grove City", "Mercer",
    "Zelienople", "Harmony", "Evans City", "Mars", "Valencia", "Gibsonia", "Wexford", "Cranberry Township", "Baden",
    "Conway", "Monaca", "Aliquippa", "Ambridge", "Coraopolis", "Imperial", "Oakdale", "Bridgeville", "New Castle",
    "Ellwood City", "Beaver Falls", "Sharon", "Hermitage", "Greenville", "Meadville", "Cochranton", "Titusville",
    "Pleasantville", "Oil City", "Seneca", "Reno", "Rouseville", "Franklin", "Polk", "Sugarcreek", "Warren",
    "Youngsville", "Sheffield", "Clarendon", "Tidioute", "Marienville", "Kane", "Ludlow", "Mt. Jewett", "Smethport",
    "Port Allegany", "Eldred", "Bradford", "Lewis Run", "Custer City", "Derrick City", "Duke Center", "Rixford",
    "St. Marys", "Ridgway", "Johnsonburg", "Wilcox", "DuBois", "Falls Creek", "Clearfield", "Curwensville",
    "Philipsburg", "Snow Shoe", "Lock Haven", "Renovo", "Jersey Shore", "Montoursville", "Muncy", "Hughesville",
    "Canton", "Troy", "Towanda", "Wysox", "Wyalusing", "Meshoppen", "Tunkhannock", "Factoryville", "Nicholson",
    "Montrose", "New Milford", "Hallstead", "Susquehanna", "Wellsboro", "Mansfield", "Blossburg", "Lawrenceville",
    "Tioga", "Elkland", "Westfield", "Galeton", "Coudersport", "Ulysses", "Shinglehouse",
  ],
  "US:WV": [
    "Westover", "Star City", "Granville", "Cheat Lake", "Sabraton", "Masontown", "Reedsville", "Kingwood", "Terra Alta",
    "Bruceton Mills", "Fairmont", "Whitehall", "Pleasant Valley", "Barrackville", "Farmington", "Mannington",
    "Hundred", "Littleton", "Burton", "Shinnston", "Lumberport", "Wallace", "Bridgeport", "Clarksburg", "Nutter Fort",
    "Stonewood", "Anmoore", "Salem", "Bristol", "West Union", "Smithburg", "Pennsboro", "Ellenboro", "Harrisville",
    "Cairo", "St. Marys", "Belmont", "Waverly", "Williamstown", "Vienna", "Parkersburg", "Mineral Wells", "Washington",
    "Elizabeth", "Palestine", "Ravenswood", "Ripley", "Evans", "Cottageville", "Sistersville", "Friendly", "Paden City",
    "New Martinsville", "Proctor", "Reader", "Pine Grove", "Jacksonburg", "Smithfield", "Moundsville", "Glen Dale",
    "McMechen", "Benwood", "Wheeling", "Triadelphia", "Valley Grove", "Wellsburg", "Follansbee", "Weirton", "Chester",
    "New Cumberland", "Jane Lew", "Weston", "Alum Bridge", "Linn", "Glenville", "Sand Fork", "Burnsville", "Flatwoods",
    "Sutton", "Gassaway", "Buckhannon", "Philippi", "Belington", "Elkins", "Spencer", "Walton", "Clendenin", "Elkview",
    "Pinch", "Big Chimney", "Charleston", "South Charleston", "Dunbar", "Institute", "St. Albans", "Nitro", "Poca",
    "Cross Lanes", "Hurricane", "Teays Valley", "Winfield", "Ripley", "Madison", "Danville", "Logan", "Chapmanville",
    "Williamson", "Welch", "Pineville", "Beckley", "Oak Hill", "Summersville", "Craigsville",
  ],
  "US:OH": [
    "Marietta", "Reno", "Devola", "Beverly", "Lowell", "Waterford", "Belpre", "Little Hocking", "Coolville",
    "Caldwell", "Dexter City", "Sarahsville", "Belle Valley", "Byesville", "Senecaville", "Quaker City", "Lore City",
    "Old Washington", "Kimbolton", "New Concord", "Zanesville", "South Zanesville", "Philo", "Duncan Falls", "Dresden",
    "Frazeysburg", "Newark", "Heath", "Hebron", "Utica", "Mt. Vernon", "Mount Vernon", "Danville", "Fredericktown",
    "Coshocton", "West Lafayette", "Newcomerstown", "Gnadenhutten", "Uhrichsville", "Dennison", "Midvale", "New Philadelphia",
    "Dover", "Strasburg", "Bolivar", "Zoar", "Mineral City", "Magnolia", "Waynesburg", "Malvern", "Minerva", "Carrollton",
    "Dellroy", "Sherrodsville", "Bowerston", "Scio", "Jewett", "Hopedale", "Cadiz", "Freeport", "Piedmont", "Flushing",
    "Holloway", "Barnesville", "Bethesda", "Belmont", "Morristown", "St. Clairsville", "Bannock", "Lafferty", "Bridgeport",
    "Martins Ferry", "Yorkville", "Tiltonsville", "Rayland", "Dillonvale", "Mt. Pleasant", "Adena", "Smithfield",
    "Brilliant", "Mingo Junction", "Steubenville", "Wintersville", "Richmond", "Toronto", "Empire", "Stratton",
    "Wellsville", "East Liverpool", "Calcutta", "Lisbon", "Salineville", "Columbiana", "Salem", "Leetonia", "East Palestine",
    "North Lima", "Boardman", "Poland", "Struthers", "Lowellville", "Campbell", "Youngstown", "Austintown", "Canfield",
    "Girard", "Niles", "McDonald", "Hubbard", "Brookfield", "Masury", "Vienna", "Cortland", "Warren", "Newton Falls",
    "Ravenna", "Rootstown", "Atwater", "Alliance", "Sebring", "Beloit", "Damascus", "Louisville", "East Canton",
    "North Canton", "Massillon", "Navarre", "Brewster", "Beach City", "Dalton", "Orrville", "Smithville", "Wooster",
    "Shreve", "Millersburg", "Killbuck", "Loudonville", "Ashland", "Woodsfield", "Sardis", "Hannibal", "Clarington",
    "Powhatan Point", "Shadyside", "Bellaire", "Beallsville", "Jerusalem", "Graysville", "New Matamoras", "Newport",
    "Lima", "Elida", "Cridersville", "Wapakoneta", "Findlay", "Cygnet", "North Baltimore", "Bowling Green", "Oregon", "Toledo",
  ],
  "US:MT": [
    "Fairview", "Crane", "Savage", "Lambert", "Richey", "Vida", "Wolf Point", "Poplar", "Brockton", "Culbertson",
    "Bainville", "Froid", "Medicine Lake", "Reserve", "Dagmar", "Antelope", "Plentywood", "Outlook", "redstone",
    "Scobey", "Flaxville", "Opheim", "Glasgow", "Nashua", "Fort Peck", "Malta", "Saco", "Hinsdale", "Chinook", "Havre",
    "Chester", "Joplin", "Rudyard", "Shelby", "Kevin", "Sunburst", "Sweet Grass", "Oilmont", "Ferdig", "Ethridge",
    "Cut Bank", "Browning", "Valier", "Conrad", "Brady", "Dutton", "Choteau", "Fairfield", "Augusta", "Great Falls",
    "Belt", "Stanford", "Hobson", "Moore", "Lewistown", "Grass Range", "Winnett", "Jordan", "Circle", "Lindsay",
    "Glendive", "West Glendive", "Wibaux", "Fallon", "Terry", "Miles City", "Broadus", "Biddle", "Alzada", "Ekalaka",
    "Plevna", "Ismay", "Baker", "Forsyth", "Rosebud", "Colstrip", "Lame Deer", "Busby", "Hardin", "Crow Agency",
    "Lodge Grass", "Roundup", "Melstone", "Musselshell", "Lavina", "Broadview", "Laurel", "Park City", "Columbus",
    "Absarokee", "Red Lodge", "Bridger", "Fromberg", "Belfry",
  ],
  "US:KS": [
    "Hays", "Ellis", "Victoria", "Gorham", "Walker", "Russell", "Bunker Hill", "Dorrance", "Wilson", "Lucas", "Luray",
    "Natoma", "Codell", "Plainville", "Zurich", "Palco", "Damar", "Bogue", "Hill City", "Morland", "Stockton",
    "Woodston", "Alton", "Phillipsburg", "Logan", "Speed", "Norton", "Oberlin", "Colby", "Oakley", "Grinnell", "Grainfield",
    "Park", "Quinter", "WaKeeney", "Ogallah", "Ransom", "Utica", "Ness City", "Bazine", "Alexander", "McCracken",
    "La Crosse", "Rush Center", "Otis", "Bison", "Timken", "Hoisington", "Susank", "Odin", "Claflin", "Ellinwood",
    "Pawnee Rock", "Larned", "Garfield", "Kinsley", "Greensburg", "Haviland", "Mullinville", "Bucklin", "Ford",
    "Spearville", "Dodge City", "Cimarron", "Ingalls", "Charleston", "Pierceville", "Garden City", "Holcomb",
    "Deerfield", "Lakin", "Syracuse", "Dighton", "Scott City", "Leoti", "Tribune", "Ulysses", "Hickok", "Satanta",
    "Sublette", "Copeland", "Montezuma", "Meade", "Fowler", "Plains", "Kismet", "Liberal", "Tyrone", "Moscow",
    "Hugoton", "Rolla", "Richfield", "Elkhart", "Johnson City", "Manter", "Pratt", "Iuka", "Preston", "Cullison",
    "Coats", "Sawyer", "Isabel", "Nashville", "Zenda", "Spivey", "Kingman", "Cunningham", "Norwich", "Harper",
    "Anthony", "Attica", "Sharon", "Medicine Lodge", "Sun City", "Lake City", "Kiowa", "Hardtner", "Coldwater",
    "Protection", "Ashland", " Hutchinson", "South Hutchinson", "Buhler", "Haven", "Burrton", "Halstead", "Newton",
    "Hesston", "Moundridge", "Galva", "Canton", "McPherson", "Inman", "Lindsborg", "Marquette", "Lyons", "Chase",
    "Bushton", "Raymond", "Alden", "Sterling", "Nickerson", "Stafford", "St. John", "Macksville", "Hudson",
    "El Dorado", "Towanda", "Benton", "Andover", "Augusta", "Douglass", "Rose Hill", "Derby", "Haysville", "Wichita",
    "Valley Center", "Park City", "Mulvane", "Belle Plaine", "Wellington", "Oxford", "Winfield", "Arkansas City",
    "Sedan", "Peru", "Caney", "Tyro", "Coffeyville", "Independence", "Cherryvale", "Neodesha", "Fredonia", "Altoona",
    "buffalo", "Yates Center", "Eureka", "Madison", "Virgil", "Gridley", "Burlington", "Chanute", "Humboldt", "Iola",
    "Moran", "La Harpe", "Garnett", "Osawatomie", "Paola", "Louisburg",
  ],
  "US:CA": [
    "Oildale", "Rosedale", "Lamont", "Arvin", "Weedpatch", "Edison", "Taft", "Ford City", "South Taft", "Maricopa",
    "Fellows", "Derby Acres", "McKittrick", "Buttonwillow", "Tupman", "Lost Hills", "Shafter", "Wasco", "McFarland",
    "Delano", "Richgrove", "Earlimart", "Kettleman City", "Avenal", "Coalinga", "Huron", "San Ardo", "King City",
    "Santa Maria", "Orcutt", "Guadalupe", "Sisquoc", "Garey", "Los Alamos", "Buellton", "Lompoc", "Goleta",
    "Carpinteria", "La Conchita", "Ventura", "Montalvo", "Saticoy", "Santa Paula", "Fillmore", "Piru", "Ojai", "Oak View",
    "Oxnard", "Port Hueneme", "Camarillo", "Newhall", "Santa Clarita", "Castaic", "Valencia", "Sylmar", "Torrance",
    "Carson", "Wilmington", "San Pedro", "Terminal Island", "Harbor City", "Lomita", "El Segundo", "Manhattan Beach",
    "Redondo Beach", "Compton", "Paramount", "Downey", "Santa Fe Springs", "Norwalk", "Whittier", "La Habra", "Brea",
    "Placentia", "Yorba Linda", "Fullerton", "Signal Hill", "Long Beach", "Seal Beach", "Sunset Beach", "Huntington Beach",
    "Martinez", "Benicia", "Vallejo", "Rodeo", "Hercules", "Pinole", "Richmond", "Pittsburg", "Antioch", "Rio Vista",
  ],
  "US:AK": [
    "Eagle River", "Chugiak", "Palmer", "Wasilla", "Big Lake", "Willow", "Talkeetna", "Girdwood", "Whittier", "Seward",
    "Cooper Landing", "Sterling", "Soldotna", "Ridgeway", "Kalifornsky", "Kasilof", "Clam Gulch", "Ninilchik",
    "Anchor Point", "Homer", "Nikiski", "Tyonek", "Beluga", "Valdez", "Glennallen", "Delta Junction", "North Pole",
    "Fairbanks", "Eielson", "Healy", "Nenana", "Prudhoe Bay", "Deadhorse", "Kuparuk", "Nuiqsut", "Utqiagvik", "Barrow",
  ],
  "US:AR": [
    "Smackover", "Norphlet", "Calion", "Louann", "Stephens", "Camden", "East Camden", "Bearden", "Fordyce", "Magnolia",
    "Waldo", "Stamps", "Lewisville", "Bradley", "Taylor", "Emerson", "Junction City", "Strong", "Huttig", "Crossett",
    "Hamburg", "Warren", "Monticello", "Texarkana", "Ashdown", "Hope", "Prescott", "Arkadelphia", "Malvern", "Benton",
    "Little Rock", "North Little Rock", "Conway", "Greenbrier", "Damascus", "Bee Branch", "Clinton", "Quitman",
    "Heber Springs", "Pangburn", "Searcy", "Judsonia", "Bald Knob", "Kensett", "Beebe", "Cabot", "Morrilton",
    "Plumerville", "Atkins", "Pottsville", "Russellville", "Dardanelle", "London", "Lamar", "Knoxville", "Clarksville",
    "Hartman", "Coal Hill", "Altus", "Ozark", "Mulberry", "Alma", "Van Buren", "Barling", "Greenwood", "Huntington",
    "Mansfield", "Hartford", "Hackett", "Booneville", "Paris", "Charleston", "Lavaca",
  ],
  "US:MS": [
    "Sandersville", "Heidelberg", "Vossburg", "Eucutta", "Shubuta", "Quitman", "Stonewall", "Enterprise", "Meridian",
    "Waynesboro", "Buckatunna", "State Line", "Clara", "Richton", "Beaumont", "New Augusta", "Petal", "Hattiesburg",
    "Purvis", "Lumberton", "Poplarville", "Picayune", "Wiggins", "Ellisville", "Moselle", "Seminary", "Collins",
    "Mt. Olive", "Magee", "Mendenhall", "Taylorsville", "Raleigh", "Bay Springs", "Stringer", "Soso", "Prentiss",
    "Bassfield", "Sumrall", "Columbia", "Foxworth", "Tylertown", "Kokomo", "McComb", "Summit", "Magnolia", "Osyka",
    "Liberty", "Gloster", "Crosby", "Centreville", "Woodville", "Natchez", "Morgantown", "Washington", "Fayette",
    "Lorman", "Port Gibson", "Meadville", "Bude", "Roxie", "Brookhaven", "Wesson", "Hazlehurst", "Crystal Springs",
    "Terry", "Byram", "Raymond", "Clinton", "Jackson", "Pearl", "Brandon", "Flowood", "Richland", "Florence",
    "Yazoo City", "Bentonia", "Flora", "Canton", "Madison", "Vicksburg", "Pascagoula", "Moss Point", "Gautier",
    "Ocean Springs", "Biloxi", "Gulfport",
  ],
  "US:AL": [
    "Citronelle", "Mount Vernon", "Calvert", "McIntosh", "Chatom", "Millry", "Gilbertown", "Toxey", "Butler",
    "Lisman", "Pennington", "Thomasville", "Grove Hill", "Jackson", "Leroy", "Monroeville", "Frisco City", "Excel",
    "Repton", "Evergreen", "Castleberry", "Brewton", "East Brewton", "Flomaton", "Pollard", "Atmore", "Huxford",
    "Uriah", "Bay Minette", "Stockton", "Spanish Fort", "Daphne", "Fairhope", "Foley", "Saraland", "Satsuma",
    "Creola", "Axis", "Chickasaw", "Prichard", "Mobile", "Theodore", "Tillmans Corner", "Irvington", "Bayou La Batre",
    "Coden", "Dauphin Island", "Tuscaloosa", "Northport", "Brookwood", "Vance", "Moundville", "Berry", "Fayette",
    "Vernon", "Sulligent", "Millport", "Reform", "Gordo", "Oakman", "Jasper", "Birmingham", "Bessemer",
  ],
  "US:IL": [
    "Carmi", "Crossville", "Grayville", "Albion", "Mt. Carmel", "Mount Carmel", "Allendale", "St. Francisville",
    "Bridgeport", "Sumner", "Lawrenceville", "Flat Rock", "Palestine", "Robinson", "Oblong", "Stoy", "Casey",
    "Martinsville", "Marshall", "Newton", "Ste. Marie", "Olney", "Noble", "Clay City", "Flora", "Louisville",
    "Xenia", "Cisne", "Fairfield", "Wayne City", "McLeansboro", "Norris City", "Enfield", "Eldorado", "Harrisburg",
    "Benton", "West Frankfort", "Marion", "Mt. Vernon", "Mount Vernon", "Woodlawn", "Salem", "Odin", "Sandoval",
    "Centralia", "Wamac", "Vandalia", "St. Elmo", "Brownstown", "Altamont", "Effingham", "Teutopolis", "Mattoon",
    "Robinson", "Wood River", "Roxana", "Hartford", "East Alton", "Granite City", "Joliet", "Channahon", "Lemont",
  ],
  "US:IN": [
    "Mt. Vernon", "Mount Vernon", "New Harmony", "Poseyville", "Cynthiana", "Evansville", "Newburgh", "Boonville",
    "Princeton", "Patoka", "Hazleton", "Owensville", "Fort Branch", "Haubstadt", "Oakland City", "Francisco",
    "Petersburg", "Winslow", "Vincennes", "Monroe City", "Bicknell", "Sullivan", "farmersburg", "Terre Haute",
    "Whiting", "East Chicago", "Hammond", "Gary",
  ],
  "US:KY": [
    "Pikeville", "Coal Run Village", "Elkhorn City", "Shelbiana", "Virgie", "Jenkins", "Whitesburg", "Neon",
    "Prestonsburg", "Allen", "Martin", "Wayland", "Wheelwright", "McDowell", "Paintsville", "Van Lear", "Staffordsville",
    "Oil Springs", "Salyersville", "Louisa", "Blaine", "Inez", "Warfield", "Lovely", "Beauty", "Hazard", "Lothair",
    "Jeff", "Viper", "Hindman", "Jackson", "Beattyville", "Campton", "Stanton", "Irvine", "Ravenna", "Manchester",
    "Hyden", "Harlan", "Cumberland", "Benham", "Lynch", "Middlesboro", "Pineville", "Barbourville", "Corbin",
    "London", "East Bernstadt", "Somerset", "Monticello", "Albany", "Burkesville", "Edmonton", "glasgow", "Greensburg",
    "Columbia", "Campbellsville", "Bowling Green", "Morgantown", "Hartford", "Beaver Dam", "Central City", "Greenville",
    "Madisonville", "Earlington", "Hanson", "Slaughters", "Sebree", "Dixon", "Providence", "Clay", "Morganfield",
    "Sturgis", "Uniontown", "Waverly", "Corydon", "Henderson", "Spottsville", "Owensboro", "Whitesville", "Hawesville",
    "Catlettsburg", "Ashland", "Russell", "Greenup",
  ],
  "US:MI": [
    "Mt. Pleasant", "Mount Pleasant", "Shepherd", "Rosebush", "Clare", "Farwell", "Harrison", "Gladwin", "Beaverton",
    "Coleman", "Sanford", "Midland", "Auburn", "Bay City", "Saginaw", "Alma", "St. Louis", "Breckenridge", "Ithaca",
    "West Branch", "St. Helen", "Roscommon", "Houghton Lake", "Prudenville", "Grayling", "Frederic", "Gaylord",
    "Vanderbilt", "Johannesburg", "Lewiston", "Atlanta", "Mio", "Kalkaska", "South Boardman", "Fife Lake", "Mancelona",
    "Bellaire", "Alden", "Rapid City", "Williamsburg", "Acme", "Traverse City", "Kingsley", "Buckley", "Mesick",
    "Cadillac", "Manton", "Marion", "Evart", "Reed City", "Big Rapids", "Manistee", "Bear Lake", "Onekama", "Kaleva",
    "Ludington", "Scottville", "Hart", "Shelby", "Muskegon", "Grand Haven", "Holland", "Wayland", "Allegan",
    "Albion", "Marshall", "Homer", "Litchfield", "Jonesville", "Hillsdale", "Jackson", "Detroit", "Melvindale",
    "River Rouge", "Ecorse", "Wyandotte", "Trenton", "Flat Rock", "Monroe", "Marysville", "Port Huron", "St. Clair",
  ],
  "US:NE": [
    "Kimball", "Bushnell", "Dix", "Potter", "Sidney", "Lodgepole", "Chappell", "Oshkosh", "Bridgeport", "Bayard",
    "Scottsbluff", "Gering", "Mitchell", "Morrill", "Alliance", "Hemingford", "Chadron", "Gordon", "Ogallala",
    "Grant", "Imperial", "Wauneta", "Palisade", "Trenton", "Culbertson", "McCook", "Indianola", "Bartley", "Cambridge",
    "Arapahoe", "Holdrege", "Kearney", "Grand Island", "Hastings", "Falls City",
  ],
};

const CORE_OILPATCH_REGIONS_CA = new Set(["AB", "SK", "BC", "MB", "NL", "NS", "NT", "NB", "ON", "QC"]);
const CORE_OILPATCH_REGIONS_US = new Set([
  "TX", "NM", "OK", "ND", "LA", "WY", "CO", "UT", "PA", "WV", "OH",
  "MT", "KS", "CA", "AK", "AR", "MS", "AL", "IL", "IN", "KY", "MI", "NE",
]);

export function buildQueriesForTownStage(town, stage) {
  const {countryCode: cc, regionCode: rc, city} = town;
  const loc = `${city}, ${rc}`;
  const trainTerm = cc === "CA" ? "Oilfield Safety & H2S Alive Training" : "Oilfield Safety & SafeLand Training";

  if (stage === 1) {
    return [
      {
        id: `MT|${cc}|${rc}|${city}|S1|oilfield_services`,
        stage: 1,
        countryCode: cc,
        regionCode: rc,
        city,
        isTrainingQuery: false,
        defaultCat: "equipment_rentals_tools",
        query: `Oilfield & Energy Services in ${loc}`,
      },
      {
        id: `MT|${cc}|${rc}|${city}|S1|safety_training`,
        stage: 1,
        countryCode: cc,
        regionCode: rc,
        city,
        isTrainingQuery: true,
        defaultCat: "oil_gas_training_courses",
        query: `${trainTerm} in ${loc}`,
      },
      {
        id: `MT|${cc}|${rc}|${city}|S1|trucking_hydrovac_welding`,
        stage: 1,
        countryCode: cc,
        regionCode: rc,
        city,
        isTrainingQuery: false,
        defaultCat: "trucking_heavy_haul",
        query: `Oilfield Trucking Hydrovac & Welding in ${loc}`,
      },
    ];
  }

  if (stage === 2) {
    const sectorTemplates = [
      {cat: "drilling_rigs_directional", q: "Drilling & Well Service Rig Contractor", train: false},
      {cat: "completions_frac_wireline", q: "Wireline Coiled Tubing & Well Completions", train: false},
      {cat: "wellhead_valves_pressure", q: "Wellhead Valve & Pressure Control", train: false},
      {cat: "pipe_octg_supply", q: "OCTG Pipe Casing & Oilfield Supply", train: false},
      {cat: "pipeline_facility_construction", q: "Pipeline & Oilfield Facility Construction", train: false},
      {cat: "vacuum_hydrovac_fluid", q: "Vacuum Truck & Oilfield Water Hauling", train: false},
      {cat: "crane_picker_rigging", q: "Crane Picker Truck & Rigging Service", train: false},
      {cat: "hotshot_pilot_logistics", q: "Oilfield Hot Shot & Freight Service", train: false},
      {cat: "welding_machining_fab", q: "Oilfield Welding Fabrication & Machine Shop", train: false},
      {cat: "pumps_artificial_lift", q: "Oilfield Pumps Artificial Lift & Compression", train: false},
      {cat: "tanks_vessels_compression", q: "Oilfield Tanks Separators & Vessel Rental", train: false},
      {cat: "matting_lease_civil", q: "Oilfield Lease Construction & Access Matting", train: false},
      {cat: "instrumentation_electrical_scada", q: "Oilfield Electrical Instrumentation & Automation", train: false},
      {cat: "environmental_remediation_waste", q: "Oilfield Environmental Remediation & Disposal", train: false},
      {cat: "oil_gas_training_courses", q: "Well Control Crane Welding & Safety Training", train: true},
    ];
    return sectorTemplates.map((t, idx) => ({
      id: `MT|${cc}|${rc}|${city}|S2|${idx}_${t.cat}`,
      stage: 2,
      countryCode: cc,
      regionCode: rc,
      city,
      isTrainingQuery: t.train,
      defaultCat: t.cat,
      query: `${t.q} in ${loc}`,
    }));
  }

  if (stage === 3) {
    return "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("").map((letter) => ({
      id: `MT|${cc}|${rc}|${city}|S3|ALPHA_${letter}`,
      stage: 3,
      countryCode: cc,
      regionCode: rc,
      city,
      isTrainingQuery: false,
      defaultCat: "equipment_rentals_tools",
      query: `"${letter}" Oilfield & Energy Services ${loc}`,
    }));
  }

  if (stage === 4) {
    const tailTemplates = [
      {cat: "pipeline_facility_construction", q: "Roustabout & Oilfield Maintenance Crew", train: false},
      {cat: "vacuum_hydrovac_fluid", q: "Saltwater Disposal & Frac Water Transfer", train: false},
      {cat: "welding_machining_fab", q: "Mobile Welding & Pipe Inspection NDT", train: false},
      {cat: "completions_frac_wireline", q: "Slickline Fishing & Downhole Tools", train: false},
      {cat: "explorers_producers_midstream", q: "Oil & Gas Producer Midstream & Tank Battery", train: false},
      {cat: "trucking_heavy_haul", q: "Rig Moving Winch Tractor & Heavy Haul", train: false},
      {cat: "safety_h2s_medics", q: "H2S Safety Industrial Medic & Fire Watch", train: false},
      {cat: "surveying_engineering_geomatics", q: "Oilfield Surveying & Underground Line Locating", train: false},
      {cat: "fleet_heavy_duty_repair", q: "Heavy Duty Diesel & Hydraulic Field Repair", train: false},
      {cat: "oil_gas_training_courses", q: "CDL Truck Driving & Industrial Safety School", train: true},
    ];
    return tailTemplates.map((t, idx) => ({
      id: `MT|${cc}|${rc}|${city}|S4|${idx}_${t.cat}`,
      stage: 4,
      countryCode: cc,
      regionCode: rc,
      city,
      isTrainingQuery: t.train,
      defaultCat: t.cat,
      query: `${t.q} in ${loc}`,
    }));
  }

  return [];
}

async function fetchFirestoreTowns(projectId) {
  try {
    const token = await resolveAccessToken(projectId);
    const res = await fetch(
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/yellow_pages_meta/directory_counts`,
      {headers: {Authorization: `Bearer ${token}`}, signal: AbortSignal.timeout(25000)},
    );
    if (!res.ok) return [];
    const doc = await res.json();
    const packed = doc?.fields?.townsPacked?.stringValue || "";
    const out = [];
    for (const line of packed.split("\n")) {
      if (!line.trim()) continue;
      const [rawCity, rawRc, rawCc, cntStr] = line.split("\t");
      const cc = String(rawCc || "").trim().toUpperCase();
      if (cc !== "CA" && cc !== "US") continue;
      const rc = canonicalizeRegionCode(rawRc, cc);
      if (!/^[A-Z]{2}$/u.test(rc)) continue;
      const city = canonicalizeCityName(rawCity, rc, cc);
      if (!city || city.length < 2 || /\d/u.test(city)) continue;
      out.push({countryCode: cc, regionCode: rc, city, dbCount: Number(cntStr || 0)});
    }
    return out;
  } catch (err) {
    console.warn(`[bot17] Warning fetching directory_counts: ${err.message}`);
    return [];
  }
}

function computePriorityBand(cc, rc, isCurated, dbCount) {
  // Strictly Canada first (Bands 10-19), USA second (Bands 20-39)
  if (cc === "CA") {
    if (CORE_OILPATCH_REGIONS_CA.has(rc) && isCurated) return 10;
    if (CORE_OILPATCH_REGIONS_CA.has(rc) && dbCount >= 2) return 12;
    if (CORE_OILPATCH_REGIONS_CA.has(rc)) return 14;
    return 18;
  }
  if (CORE_OILPATCH_REGIONS_US.has(rc) && isCurated) return 20;
  if (CORE_OILPATCH_REGIONS_US.has(rc) && dbCount >= 3) return 22;
  if (CORE_OILPATCH_REGIONS_US.has(rc)) return 25;
  if (dbCount >= 3) return 30;
  return 35;
}

export async function runMicrotownPlanner({projectId = PROJECT_ID, reset = RESET} = {}) {
  await fsp.mkdir(LEDGER_DIR, {recursive: true});
  await fsp.mkdir(REPORTS_DIR, {recursive: true});

  const bot16CompletedSet = new Set(
    BOT16_COMPLETED_HUBS.map(([cc, rc, city]) => `${cc}|${rc}|${normalizeCityKey(canonicalizeCityName(city, rc, cc))}`),
  );

  let state = {
    version: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    visitedQueryIds: [],
    towns: {},
  };

  if (!reset && fs.existsSync(STATE_PATH)) {
    try {
      state = JSON.parse(await fsp.readFile(STATE_PATH, "utf8"));
      state.visitedQueryIds = state.visitedQueryIds || [];
      state.towns = state.towns || {};
    } catch (_) {}
  }

  const visitedSet = new Set(state.visitedQueryIds);

  const registerCandidateTown = (cc, rcRaw, rawCity, {isCurated = false, dbCount = 0} = {}) => {
    const rc = canonicalizeRegionCode(rcRaw, cc);
    if (!/^[A-Z]{2}$/u.test(rc)) return;
    const city = canonicalizeCityName(rawCity, rc, cc);
    if (!city || city.length < 2 || /\d/u.test(city)) return;
    const normKey = normalizeCityKey(city);
    if (!normKey) return;
    const fullKey = `${cc}|${rc}|${normKey}`;
    if (bot16CompletedSet.has(fullKey)) return;

    const existing = state.towns[fullKey];
    if (existing) {
      if (isCurated) existing.isCuratedOilpatch = true;
      if (dbCount > (existing.initialDbCount || 0)) existing.initialDbCount = dbCount;
      existing.priorityBand = computePriorityBand(
        cc,
        rc,
        existing.isCuratedOilpatch,
        existing.initialDbCount || 0,
      );
      return;
    }

    state.towns[fullKey] = {
      key: fullKey,
      countryCode: cc,
      regionCode: rc,
      city,
      isCuratedOilpatch: Boolean(isCurated),
      initialDbCount: dbCount,
      priorityBand: computePriorityBand(cc, rc, isCurated, dbCount),
      currentStage: 1, // 1=PROBE, 2=SECTOR_SWEEP, 3=ALPHA_SWEEP, 4=EXTENDED_TAIL, 5=EXHAUSTED
      totalLocalCards: 0,
      totalNewBusinesses: 0,
      stageStats: {
        1: {queriesDone: 0, localCards: 0, newBusinesses: 0},
        2: {queriesDone: 0, localCards: 0, newBusinesses: 0},
        3: {queriesDone: 0, localCards: 0, newBusinesses: 0},
        4: {queriesDone: 0, localCards: 0, newBusinesses: 0},
      },
    };
  };

  // 1. Ingest Curated Unlisted Oilpatch Micro-Town Atlas
  for (const [regKey, townList] of Object.entries(CURATED_MICROTOWN_ATLAS)) {
    const [cc, rc] = regKey.split(":");
    for (const rawCity of townList) {
      registerCandidateTown(cc, rc, rawCity, {isCurated: true, dbCount: 0});
    }
  }

  // 2. Ingest Live Firestore Proven Towns (`townsPacked`)
  const dbTowns = await fetchFirestoreTowns(projectId);
  for (const t of dbTowns) {
    registerCandidateTown(t.countryCode, t.regionCode, t.city, {isCurated: false, dbCount: t.dbCount});
  }

  // 3. Ingest Dynamically Mined Street-Address Towns from Bot 18
  if (fs.existsSync(DYNAMIC_TOWNS_PATH)) {
    const dynLines = (await fsp.readFile(DYNAMIC_TOWNS_PATH, "utf8")).split("\n").filter(Boolean);
    for (const line of dynLines) {
      try {
        const d = JSON.parse(line);
        if (d.countryCode === "CA" || d.countryCode === "US") {
          registerCandidateTown(d.countryCode, d.regionCode, d.city, {isCurated: true, dbCount: 1});
        }
      } catch (_) {}
    }
  }

  // 4. Evaluate Adaptive Stage Transitions ("Run Till No More Come Up")
  // Empirical yield order: Stage 1 (PROBE, 3q) -> Stage 2 (SECTOR_SWEEP, 15q) ->
  // Stage 4 (EXTENDED_TAIL, 10q) -> Stage 3 (ALPHA_SWEEP A-Z, 26q for high-density hubs) -> Stage 5 (EXHAUSTED).
  let promotionsCount = 0;
  let newlyExhaustedCount = 0;
  for (const town of Object.values(state.towns)) {
    // Fast-path: if a town was placed in Stage 3 under the old rule before reaching 25+ businesses,
    // route it to Stage 4 (EXTENDED_TAIL) if not yet run, or EXHAUSTED if already run.
    if (town.currentStage === 3 && (town.totalNewBusinesses || 0) < 25) {
      const s4Done = buildQueriesForTownStage(town, 4).filter((q) => visitedSet.has(q.id)).length >= 10;
      const st2 = town.stageStats[2] || {newBusinesses: 0, localCards: 0};
      if (!s4Done && (st2.newBusinesses >= 2 || st2.localCards >= 8)) {
        town.currentStage = 4;
      } else {
        town.currentStage = 5;
        newlyExhaustedCount += 1;
      }
    }

    let guard = 0;
    while (town.currentStage >= 1 && town.currentStage <= 4 && guard++ < 8) {
      const stageQueries = buildQueriesForTownStage(town, town.currentStage);
      const completedInStage = stageQueries.filter((q) => visitedSet.has(q.id)).length;
      const st = town.stageStats[town.currentStage] || {queriesDone: 0, localCards: 0, newBusinesses: 0};
      st.queriesDone = completedInStage;
      town.stageStats[town.currentStage] = st;

      if (completedInStage < stageQueries.length) {
        break; // Current stage still has pending queries
      }

      // Stage completed -> evaluate convergence vs escalation
      if (town.currentStage === 1) {
        if (st.newBusinesses >= 1 || st.localCards >= 2) {
          town.currentStage = 2;
          promotionsCount += 1;
        } else {
          town.currentStage = 5;
          newlyExhaustedCount += 1;
        }
      } else if (town.currentStage === 2) {
        if (st.newBusinesses >= 2 || st.localCards >= 8) {
          town.currentStage = 4;
          promotionsCount += 1;
        } else {
          town.currentStage = 5;
          newlyExhaustedCount += 1;
        }
      } else if (town.currentStage === 4) {
        const s3Done = buildQueriesForTownStage(town, 3).filter((q) => visitedSet.has(q.id)).length >= 26;
        if (!s3Done && (st.newBusinesses >= 6 || (town.totalNewBusinesses || 0) >= 25)) {
          town.currentStage = 3;
          promotionsCount += 1;
        } else {
          town.currentStage = 5;
          newlyExhaustedCount += 1;
        }
      } else if (town.currentStage === 3) {
        const s4Done = buildQueriesForTownStage(town, 4).filter((q) => visitedSet.has(q.id)).length >= 10;
        if (!s4Done && (st.newBusinesses >= 3 || (town.totalNewBusinesses || 0) >= 25)) {
          town.currentStage = 4;
          promotionsCount += 1;
        } else {
          town.currentStage = 5;
          newlyExhaustedCount += 1;
        }
      }
    }
  }

  // 5. Build Priority-Ordered Pending Query Queue
  // Order: Canada first -> USA second; within each country, finish escalated high-yield towns (Stages 2-4) + Priority Bands + DB count + A-Z!
  const allTowns = Object.values(state.towns).sort((a, b) => {
    if (a.countryCode !== b.countryCode) return a.countryCode === "CA" ? -1 : 1;
    const aEscalated = a.currentStage >= 2 && a.currentStage <= 4 ? 0 : 1;
    const bEscalated = b.currentStage >= 2 && b.currentStage <= 4 ? 0 : 1;
    if (aEscalated !== bEscalated) return aEscalated - bEscalated;
    if (a.priorityBand !== b.priorityBand) return a.priorityBand - b.priorityBand;
    if ((b.initialDbCount || 0) !== (a.initialDbCount || 0)) return (b.initialDbCount || 0) - (a.initialDbCount || 0);
    return a.city.localeCompare(b.city);
  });

  const pendingQueue = [];
  for (const town of allTowns) {
    if (town.currentStage >= 1 && town.currentStage <= 4) {
      const qs = buildQueriesForTownStage(town, town.currentStage);
      for (const q of qs) {
        if (!visitedSet.has(q.id)) {
          pendingQueue.push({...q, townKey: town.key});
        }
      }
    }
  }

  // Known-town dictionary per region (including Bot 16 hubs) for True-Town intra-state zoom-out resolution
  const knownTownsByRegion = {};
  for (const [cc, rc, city] of BOT16_COMPLETED_HUBS) {
    const rk = `${cc}:${rc}`;
    if (!knownTownsByRegion[rk]) knownTownsByRegion[rk] = new Set();
    knownTownsByRegion[rk].add(canonicalizeCityName(city, rc, cc));
  }
  for (const town of allTowns) {
    const rk = `${town.countryCode}:${town.regionCode}`;
    if (!knownTownsByRegion[rk]) knownTownsByRegion[rk] = new Set();
    knownTownsByRegion[rk].add(town.city);
  }
  const serializedKnownTowns = {};
  for (const [rk, set] of Object.entries(knownTownsByRegion)) {
    serializedKnownTowns[rk] = [...set].sort((a, b) => b.length - a.length);
  }

  state.updatedAt = new Date().toISOString();
  await fsp.writeFile(STATE_PATH, JSON.stringify(state, null, 2), "utf8");
  await fsp.writeFile(
    QUEUE_PATH,
    JSON.stringify(
      {
        generatedAt: state.updatedAt,
        pendingCount: pendingQueue.length,
        knownTownsByRegion: serializedKnownTowns,
        queue: pendingQueue,
      },
      null,
      2,
    ),
    "utf8",
  );

  // Summary metrics
  const summary = {
    totalMicroTowns: allTowns.length,
    caMicroTowns: allTowns.filter((t) => t.countryCode === "CA").length,
    usMicroTowns: allTowns.filter((t) => t.countryCode === "US").length,
    stage1Probe: allTowns.filter((t) => t.currentStage === 1).length,
    stage2Sector: allTowns.filter((t) => t.currentStage === 2).length,
    stage3Alpha: allTowns.filter((t) => t.currentStage === 3).length,
    stage4Tail: allTowns.filter((t) => t.currentStage === 4).length,
    exhaustedTowns: allTowns.filter((t) => t.currentStage === 5).length,
    visitedQueries: visitedSet.size,
    pendingQueriesInFrontier: pendingQueue.length,
    totalNewBusinessesFromMicroTowns: allTowns.reduce((s, t) => s + (t.totalNewBusinesses || 0), 0),
    promotionsInPass: promotionsCount,
    newlyExhaustedInPass: newlyExhaustedCount,
  };

  const topYieldTowns = [...allTowns]
    .filter((t) => (t.totalNewBusinesses || 0) > 0)
    .sort((a, b) => b.totalNewBusinesses - a.totalNewBusinesses)
    .slice(0, 25);

  const md = [
    "# Bot 17 — North America Micro-Town Exhaustive Frontier Dashboard",
    "",
    `- **Updated At**: \`${state.updatedAt}\``,
    `- **Total Micro-Towns in Frontier Universe**: **${summary.totalMicroTowns.toLocaleString()}** (excluding 104 Tier-1/2 Bot 16 hubs)`,
    `  - **Canada (\`CA\`) Micro-Towns**: **${summary.caMicroTowns.toLocaleString()}**`,
    `  - **United States (\`US\`) Micro-Towns**: **${summary.usMicroTowns.toLocaleString()}**`,
    `- **Convergence State Machine**:`,
    `  - **Stage 1 (\`PROBE\`)**: **${summary.stage1Probe.toLocaleString()}** towns`,
    `  - **Stage 2 (\`SECTOR_SWEEP\` — Escalated)**: **${summary.stage2Sector.toLocaleString()}** towns`,
    `  - **Stage 3 (\`ALPHA_SWEEP A–Z\` — Escalated)**: **${summary.stage3Alpha.toLocaleString()}** towns`,
    `  - **Stage 4 (\`EXTENDED_TAIL\` — Escalated)**: **${summary.stage4Tail.toLocaleString()}** towns`,
    `  - **Stage 5 (\`EXHAUSTED — Zero Remaining Yield\`)**: **${summary.exhaustedTowns.toLocaleString()}** towns`,
    `- **Queries Completed**: **${summary.visitedQueries.toLocaleString()}** | **Current Stage Pending Queue**: **${summary.pendingQueriesInFrontier.toLocaleString()}**`,
    `- **Cumulative New Micro-Town Businesses Published**: **${summary.totalNewBusinessesFromMicroTowns.toLocaleString()}**`,
    "",
    "## Top Productive Micro-Towns Discovered So Far",
    "",
    ...(topYieldTowns.length
      ? topYieldTowns.map(
          (t) =>
            `- **${t.city}, ${t.regionCode} (${t.countryCode})**: **+${t.totalNewBusinesses}** new businesses (Stage ${t.currentStage === 5 ? "EXHAUSTED" : t.currentStage})`,
        )
      : ["- *(Initial frontier built — awaiting Wave 1 harvest)*"]),
    "",
  ];
  await fsp.writeFile(PLAN_REPORT_PATH, md.join("\n"), "utf8");

  console.log("[bot17] Micro-Town Frontier Summary:", summary);
  return summary;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  runMicrotownPlanner()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("[bot17] FATAL:", err);
      process.exit(1);
    });
}
