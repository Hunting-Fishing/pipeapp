"use strict";

const YELLOW_PAGES_CATEGORIES = Object.freeze([
  {
    code: "trucking_heavy_haul",
    label: "Trucking, Towing, Winch & Heavy Haul",
    section: "yellow",
    keywords: [
      "trucking", "towing", "tow truck", "heavy tow", "wrecker", "recovery",
      "heavy haul", "winch truck", "bed truck", "rig moving",
      "rig movers", "lowboy", "step deck", "flatbed", "texas bed", "scissorneck",
      "picker haul", "pipe hauling", "oilfield hauling", "freight", "transport",
    ],
  },
  {
    code: "vacuum_hydrovac_fluid",
    label: "Vacuum, Hydrovac & Fluid Hauling",
    section: "yellow",
    keywords: [
      "vac truck", "vacuum truck", "hydrovac", "combo vac", "water hauling",
      "fluid hauling", "produced water", "tank cleaning", "steamer", "pressure truck",
      "kill truck", "hot oiler", "flushby", "suction",
    ],
  },
  {
    code: "hotshot_pilot_logistics",
    label: "Hot Shot, Pilot Cars & Logistics",
    section: "yellow",
    keywords: [
      "hotshot", "hot shot", "pilot car", "oversize escort", "high pole",
      "route survey", "traffic control", "expedited freight", "courier", "dispatch",
      "oilfield logistics", "marine logistics", "supply base",
    ],
  },
  {
    code: "crane_picker_rigging",
    label: "Cranes, Picker Trucks & Rigging",
    section: "yellow",
    keywords: [
      "crane", "picker", "picker truck", "boom truck", "knuckle boom",
      "rigging", "hoisting", "telehandler", "heavy lift", "jack and roll", "lifting",
    ],
  },
  {
    code: "pipe_octg_supply",
    label: "Pipe, OCTG, Casing & Tubing Supply",
    section: "yellow",
    keywords: [
      "pipe", "octg", "casing", "tubing", "drill pipe", "drill stem",
      "line pipe", "sucker rod", "structural pipe", "piling", "culvert",
      "flanges", "fittings", "steel pipe", "surplus pipe", "tubular", "tubulars",
    ],
  },
  {
    code: "pipe_inspection_ndt",
    label: "Pipe Inspection, NDT & Reclamation",
    section: "yellow",
    keywords: [
      "pipe inspection", "ndt", "non destructive testing", "emi", "ultrasonic",
      "magnetic particle", "radiography", "threading", "pipe straightening",
      "pipe cleaning", "reclamation", "drift", "hydrotesting", "hardbanding", "octg inspection",
    ],
  },
  {
    code: "drilling_rigs_directional",
    label: "Drilling, Service Rigs & Directional",
    section: "yellow",
    keywords: [
      "drilling", "drilling rig", "service rig", "workover", "directional drilling",
      "mwd", "lwd", "mud motor", "corings", "rathole", "conductor barrel", "spud",
      "offshore drilling", "jackup", "drillship",
    ],
  },
  {
    code: "completions_frac_wireline",
    label: "Completions, Frac, Coil & Wireline",
    section: "yellow",
    keywords: [
      "completions", "fracturing", "frac", "acidizing", "cementing",
      "coiled tubing", "coil tubing", "wireline", "slickline", "e-line",
      "perforating", "well testing", "flowback", "nitrogen", "stimulation", "well intervention",
    ],
  },
  {
    code: "wellhead_valves_pressure",
    label: "Wellheads, Valves & Pressure Control",
    section: "yellow",
    keywords: [
      "wellhead", "valves", "bop", "blowout preventer", "pressure control",
      "snubbing", "choke manifold", "frac stack", "christmas tree", "actuator",
      "greasing", "torquing", "pressure testing", "subsea tree",
    ],
  },
  {
    code: "pumps_artificial_lift",
    label: "Artificial Lift, Pumps & Compression",
    section: "yellow",
    keywords: [
      "artificial lift", "pumpjack", "rod pump", "esp", "pcp", "plunger lift",
      "gas lift", "compressor", "compression", "generator", "genset", "downhole pump",
      "turbomachinery",
    ],
  },
  {
    code: "tanks_vessels_process",
    label: "Tanks, Vessels & Process Equipment",
    section: "yellow",
    keywords: [
      "frac tank", "storage tank", "water tank", "fuel tank", "separator",
      "treater", "heater treater", "pressure vessel", "dehydrator", "flare stack",
      "scrubber", "line heater", "skid package", "absa", "process equipment", "fpso",
    ],
  },
  {
    code: "welding_machining_fab",
    label: "Mobile Welding, Machining & Fabrication",
    section: "yellow",
    keywords: [
      "welding", "mobile welding", "b pressure", "rig welder", "pipefitting",
      "machine shop", "cnc machining", "custom fabrication", "structural steel",
      "sandblasting", "coating", "millwright", "offshore fabrication",
    ],
  },
  {
    code: "equipment_rentals_tools",
    label: "Oilfield Rentals, Boilers & Downhole Tools",
    section: "yellow",
    keywords: [
      "equipment rental", "oilfield rentals", "boiler", "light tower",
      "heater", "flameless heater", "trash pump", "downhole tools", "fishing tools",
      "jar", "stabilizer", "rigwash", "containment", "oilfield supply", "oilfield equipment",
    ],
  },
  {
    code: "matting_lease_civil",
    label: "Access Matting, Civil & Lease Construction",
    section: "yellow",
    keywords: [
      "rig mats", "access mats", "swamp mats", "crane mats", "bridges",
      "lease construction", "earthworks", "mulching", "clearing", "slash",
      "road building", "excavation", "dozer", "grader", "gravel", "civil contractor",
    ],
  },
  {
    code: "pipeline_facility_construction",
    label: "Pipeline & Facility Construction",
    section: "yellow",
    keywords: [
      "pipeline", "pipeline contractor", "facility construction", "plant turnaround",
      "integrity dig", "hdd", "horizontal directional drilling", "trenching",
      "tie-in", "pigging", "composite pipe", "fiberglass pipe", "subsea pipeline", "epci",
    ],
  },
  {
    code: "electrical_automation_scada",
    label: "Electrical, Instrumentation & SCADA",
    section: "yellow",
    keywords: [
      "electrical", "instrumentation", "scada", "automation", "plc",
      "controls", "meter proving", "measurement", "solar skid", "cathodic protection",
      "fiber optic", "communications", "rov", "subsea controls",
    ],
  },
  {
    code: "safety_h2s_medics",
    label: "Safety, H2S, Industrial Medics & Fire",
    section: "yellow",
    keywords: [
      "safety", "h2s", "breathing air", "scba", "gas detection", "medics",
      "industrial medic", "mtc", "ambulance", "firewatch", "fire suppression",
      "firefighting", "well control", "confined space", "ppe", "hse",
    ],
  },
  {
    code: "environmental_remediation_waste",
    label: "Environmental, Waste & Remediation",
    section: "yellow",
    keywords: [
      "environmental", "remediation", "reclamation", "spill response",
      "waste management", "landfill", "disposal well", "norm", "soil sampling",
      "bioremediation", "abandonment", "decommissioning", "plug and abandonment",
    ],
  },
  {
    code: "chemical_mud_lubricants",
    label: "Drilling Fluids, Chemicals & Fuel",
    section: "yellow",
    keywords: [
      "drilling fluids", "mud", "production chemicals", "methanol", "glycol",
      "scavenger", "corrosion inhibitor", "bulk fuel", "cardlock", "lubricants",
      "propane", "industrial gases", "bunkering", "specialty chemicals",
    ],
  },
  {
    code: "fleet_heavy_duty_repair",
    label: "Heavy-Duty Mechanics, Hydraulics & Fleet",
    section: "yellow",
    keywords: [
      "heavy duty mechanic", "mobile mechanic", "truck repair", "trailer repair",
      "cvip", "dot inspection", "hydraulics", "hose", "diesel repair", "tires",
      "driveline", "transmission", "marine repair",
    ],
  },
  {
    code: "camps_catering_accommodations",
    label: "Remote Camps, Catering & Portable Buildings",
    section: "yellow",
    keywords: [
      "camp", "remote camp", "workforce housing", "catering", "wellsite trailer",
      "skid shack", "office trailer", "sleeper", "washcar", "septic", "potable water",
      "security", "gate guard", "offshore catering",
    ],
  },
  {
    code: "surveying_engineering_geomatics",
    label: "Engineering, Surveying & Line Locating",
    section: "yellow",
    keywords: [
      "surveying", "land survey", "engineering", "epcm", "geomatics", "gis",
      "line locating", "ground disturbance", "drone", "lidar", "geotechnical",
      "geology", "seismic", "geophysical", "subsea survey",
    ],
  },
  {
    code: "staffing_training_compliance",
    label: "Staffing, Safety Training & Compliance",
    section: "white",
    keywords: [
      "staffing", "recruiting", "labour", "crew transport", "safety training",
      "first aid", "isnetworld", "complyworks", "avetta", "cor", "drug testing",
      "bosiet", "opito", "iwcf", "manpower",
    ],
  },
  {
    code: "explorers_producers_midstream",
    label: "Explorers, Producers (E&P) & Midstream",
    section: "blue",
    keywords: [
      "oil and gas producer", "exploration", "operator", "midstream",
      "gas plant", "battery", "terminal", "refinery", "petrochemical", "lng",
      "petroleum", "upstream",
    ],
  },
]);

const CATEGORY_BY_CODE = new Map(
    YELLOW_PAGES_CATEGORIES.map((cat) => [cat.code, cat]),
);

const SYNONYM_GROUPS = Object.freeze([
  ["vac", "vacuum", "hydrovac", "combo vac", "suction", "fluid hauling"],
  ["ndt", "inspection", "emi", "ultrasonic", "tubing inspection", "casing inspection"],
  ["octg", "casing", "tubing", "drill pipe", "line pipe", "pipe", "sucker rod", "tubulars"],
  ["hotshot", "hot shot", "expedited", "pilot car", "escort", "logistics"],
  ["picker", "boom truck", "crane", "rigging", "hoisting", "heavy lift"],
  ["winch", "bed truck", "heavy haul", "rig moving", "lowboy", "step deck", "towing", "tow truck"],
  ["frac", "fracturing", "stimulation", "coil", "coiled tubing", "acidizing", "cementing"],
  ["wireline", "slickline", "perforating", "well testing", "flowback", "well intervention"],
  ["bop", "wellhead", "valve", "valves", "pressure control", "snubbing", "christmas tree"],
  ["welder", "welding", "b pressure", "fabrication", "machine shop", "machining"],
  ["rig mat", "rig mats", "access mats", "swamp mats", "matting", "lease construction"],
  ["h2s", "medic", "medics", "safety", "breathing air", "firewatch", "hse"],
  ["camp", "camps", "catering", "wellsite trailer", "skid shack", "sleeper"],
  ["scada", "instrumentation", "automation", "electrical", "plc", "rov"],
  ["mechanic", "heavy duty", "hydraulics", "cvip", "fleet repair"],
  ["boiler", "heater", "light tower", "rental", "rentals", "downhole tools"],
]);

// ============================================================================
// WORLD CONTINENTS & MACRO-REGIONS (countries-ofthe-world.com + Middle East)
// ============================================================================
const WORLD_CONTINENTS = Object.freeze([
  {code: "north_america", label: "North America"},
  {code: "middle_east", label: "Middle East"},
  {code: "europe", label: "Europe"},
  {code: "asia", label: "Asia"},
  {code: "south_america", label: "South America"},
  {code: "africa", label: "Africa"},
  {code: "oceania", label: "Australia & Oceania"},
]);

// All 197 sovereign countries organized by countries-ofthe-world.com continent.
// Countries in West Asia / GCC also carry `isMiddleEast: true` so they appear
// in the Middle East quick-filter tab AND alphabetically inside Asia.
const GLOBAL_COUNTRIES_LIST = Object.freeze([
  // --- NORTH AMERICA (23 countries) ---
  {code: "AG", name: "Antigua and Barbuda", continent: "north_america", dialCode: "+1", tz: "America/Antigua"},
  {code: "BS", name: "Bahamas", continent: "north_america", dialCode: "+1", tz: "America/Nassau"},
  {code: "BB", name: "Barbados", continent: "north_america", dialCode: "+1", tz: "America/Barbados"},
  {code: "BZ", name: "Belize", continent: "north_america", dialCode: "+501", tz: "America/Belize"},
  {code: "CA", name: "Canada", continent: "north_america", isPopularOilGas: true, dialCode: "+1", tz: "America/Edmonton", basins: ["WCSB", "Montney", "Oil Sands"]},
  {code: "CR", name: "Costa Rica", continent: "north_america", dialCode: "+506", tz: "America/Costa_Rica"},
  {code: "CU", name: "Cuba", continent: "north_america", dialCode: "+53", tz: "America/Havana"},
  {code: "DM", name: "Dominica", continent: "north_america", dialCode: "+1", tz: "America/Dominica"},
  {code: "DO", name: "Dominican Republic", continent: "north_america", dialCode: "+1", tz: "America/Santo_Domingo"},
  {code: "SV", name: "El Salvador", continent: "north_america", dialCode: "+503", tz: "America/El_Salvador"},
  {code: "GD", name: "Grenada", continent: "north_america", dialCode: "+1", tz: "America/Grenada"},
  {code: "GT", name: "Guatemala", continent: "north_america", dialCode: "+502", tz: "America/Guatemala"},
  {code: "HT", name: "Haiti", continent: "north_america", dialCode: "+509", tz: "America/Port-au-Prince"},
  {code: "HN", name: "Honduras", continent: "north_america", dialCode: "+504", tz: "America/Tegucigalpa"},
  {code: "JM", name: "Jamaica", continent: "north_america", dialCode: "+1", tz: "America/Jamaica"},
  {code: "MX", name: "Mexico", continent: "north_america", isPopularOilGas: true, dialCode: "+52", tz: "America/Mexico_City", basins: ["Gulf of Mexico / Sureste", "Burgos", "Tampico-Misantla"]},
  {code: "NI", name: "Nicaragua", continent: "north_america", dialCode: "+505", tz: "America/Managua"},
  {code: "PA", name: "Panama", continent: "north_america", dialCode: "+507", tz: "America/Panama"},
  {code: "KN", name: "Saint Kitts and Nevis", continent: "north_america", dialCode: "+1", tz: "America/St_Kitts"},
  {code: "LC", name: "Saint Lucia", continent: "north_america", dialCode: "+1", tz: "America/St_Lucia"},
  {code: "VC", name: "Saint Vincent and the Grenadines", continent: "north_america", dialCode: "+1", tz: "America/St_Vincent"},
  {code: "TT", name: "Trinidad and Tobago", continent: "north_america", isPopularOilGas: true, dialCode: "+1", tz: "America/Port_of_Spain", basins: ["Columbus Basin / Caribbean Offshore"]},
  {code: "US", name: "United States", continent: "north_america", isPopularOilGas: true, dialCode: "+1", tz: "America/Chicago", basins: ["Permian Basin", "Eagle Ford", "Bakken / Williston", "Haynesville", "Gulf Coast"]},

  // --- SOUTH AMERICA (12 countries) ---
  {code: "AR", name: "Argentina", continent: "south_america", isPopularOilGas: true, dialCode: "+54", tz: "America/Argentina/Buenos_Aires", basins: ["Vaca Muerta / Neuquén", "San Jorge"]},
  {code: "BO", name: "Bolivia", continent: "south_america", dialCode: "+591", tz: "America/La_Paz"},
  {code: "BR", name: "Brazil", continent: "south_america", isPopularOilGas: true, dialCode: "+55", tz: "America/Sao_Paulo", basins: ["Brazil Pre-Salt (Santos & Campos)"]},
  {code: "CL", name: "Chile", continent: "south_america", dialCode: "+56", tz: "America/Santiago"},
  {code: "CO", name: "Colombia", continent: "south_america", isPopularOilGas: true, dialCode: "+57", tz: "America/Bogota", basins: ["Llanos Basin", "Magdalena Valley"]},
  {code: "EC", name: "Ecuador", continent: "south_america", dialCode: "+593", tz: "America/Guayaquil", basins: ["Oriente Basin"]},
  {code: "GY", name: "Guyana", continent: "south_america", isPopularOilGas: true, dialCode: "+592", tz: "America/Guyana", basins: ["Guyana-Suriname Basin"]},
  {code: "PY", name: "Paraguay", continent: "south_america", dialCode: "+595", tz: "America/Asuncion"},
  {code: "PE", name: "Peru", continent: "south_america", dialCode: "+51", tz: "America/Lima"},
  {code: "SR", name: "Suriname", continent: "south_america", dialCode: "+597", tz: "America/Paramaribo", basins: ["Guyana-Suriname Basin"]},
  {code: "UY", name: "Uruguay", continent: "south_america", dialCode: "+598", tz: "America/Montevideo"},
  {code: "VE", name: "Venezuela", continent: "south_america", dialCode: "+58", tz: "America/Caracas", basins: ["Orinoco Belt", "Maracaibo"]},

  // --- EUROPE (51 countries) ---
  {code: "AL", name: "Albania", continent: "europe", dialCode: "+355", tz: "Europe/Tirane"},
  {code: "AD", name: "Andorra", continent: "europe", dialCode: "+376", tz: "Europe/Andorra"},
  {code: "AM", name: "Armenia", continent: "europe", dialCode: "+374", tz: "Asia/Yerevan"},
  {code: "AT", name: "Austria", continent: "europe", dialCode: "+43", tz: "Europe/Vienna"},
  {code: "AZ", name: "Azerbaijan", continent: "europe", alsoAsia: true, isPopularOilGas: true, dialCode: "+994", tz: "Asia/Baku", basins: ["Caspian Basin"]},
  {code: "BY", name: "Belarus", continent: "europe", dialCode: "+375", tz: "Europe/Minsk"},
  {code: "BE", name: "Belgium", continent: "europe", dialCode: "+32", tz: "Europe/Brussels"},
  {code: "BA", name: "Bosnia and Herzegovina", continent: "europe", dialCode: "+387", tz: "Europe/Sarajevo"},
  {code: "BG", name: "Bulgaria", continent: "europe", dialCode: "+359", tz: "Europe/Sofia"},
  {code: "HR", name: "Croatia", continent: "europe", dialCode: "+385", tz: "Europe/Zagreb"},
  {code: "CY", name: "Cyprus", continent: "europe", alsoAsia: true, isMiddleEast: true, dialCode: "+357", tz: "Asia/Nicosia", basins: ["Eastern Mediterranean"]},
  {code: "CZ", name: "Czechia", continent: "europe", dialCode: "+420", tz: "Europe/Prague"},
  {code: "DK", name: "Denmark", continent: "europe", dialCode: "+45", tz: "Europe/Copenhagen", basins: ["North Sea (UK & Norway)"]},
  {code: "EE", name: "Estonia", continent: "europe", dialCode: "+372", tz: "Europe/Tallinn"},
  {code: "FI", name: "Finland", continent: "europe", dialCode: "+358", tz: "Europe/Helsinki"},
  {code: "FR", name: "France", continent: "europe", dialCode: "+33", tz: "Europe/Paris"},
  {code: "GE", name: "Georgia", continent: "europe", alsoAsia: true, dialCode: "+995", tz: "Asia/Tbilisi"},
  {code: "DE", name: "Germany", continent: "europe", isPopularOilGas: true, dialCode: "+49", tz: "Europe/Berlin"},
  {code: "GR", name: "Greece", continent: "europe", dialCode: "+30", tz: "Europe/Athens"},
  {code: "HU", name: "Hungary", continent: "europe", dialCode: "+36", tz: "Europe/Budapest"},
  {code: "IS", name: "Iceland", continent: "europe", dialCode: "+354", tz: "Atlantic/Reykjavik"},
  {code: "IE", name: "Ireland", continent: "europe", dialCode: "+353", tz: "Europe/Dublin"},
  {code: "IT", name: "Italy", continent: "europe", isPopularOilGas: true, dialCode: "+39", tz: "Europe/Rome"},
  {code: "XK", name: "Kosovo", continent: "europe", dialCode: "+383", tz: "Europe/Belgrade"},
  {code: "LV", name: "Latvia", continent: "europe", dialCode: "+371", tz: "Europe/Riga"},
  {code: "LI", name: "Liechtenstein", continent: "europe", dialCode: "+423", tz: "Europe/Vaduz"},
  {code: "LT", name: "Lithuania", continent: "europe", dialCode: "+370", tz: "Europe/Vilnius"},
  {code: "LU", name: "Luxembourg", continent: "europe", dialCode: "+352", tz: "Europe/Luxembourg"},
  {code: "MT", name: "Malta", continent: "europe", dialCode: "+356", tz: "Europe/Malta"},
  {code: "MD", name: "Moldova", continent: "europe", dialCode: "+373", tz: "Europe/Chisinau"},
  {code: "MC", name: "Monaco", continent: "europe", dialCode: "+377", tz: "Europe/Monaco"},
  {code: "ME", name: "Montenegro", continent: "europe", dialCode: "+382", tz: "Europe/Podgorica"},
  {code: "NL", name: "Netherlands", continent: "europe", isPopularOilGas: true, dialCode: "+31", tz: "Europe/Amsterdam", basins: ["North Sea (UK & Norway)"]},
  {code: "MK", name: "North Macedonia", continent: "europe", dialCode: "+389", tz: "Europe/Skopje"},
  {code: "NO", name: "Norway", continent: "europe", isPopularOilGas: true, dialCode: "+47", tz: "Europe/Oslo", basins: ["North Sea (UK & Norway)", "Norwegian Sea / Barents"]},
  {code: "PL", name: "Poland", continent: "europe", dialCode: "+48", tz: "Europe/Warsaw"},
  {code: "PT", name: "Portugal", continent: "europe", dialCode: "+351", tz: "Europe/Lisbon"},
  {code: "RO", name: "Romania", continent: "europe", isPopularOilGas: true, dialCode: "+40", tz: "Europe/Bucharest", basins: ["Black Sea / Carpathian"]},
  {code: "RU", name: "Russia", continent: "europe", alsoAsia: true, dialCode: "+7", tz: "Europe/Moscow"},
  {code: "SM", name: "San Marino", continent: "europe", dialCode: "+378", tz: "Europe/San_Marino"},
  {code: "RS", name: "Serbia", continent: "europe", dialCode: "+381", tz: "Europe/Belgrade"},
  {code: "SK", name: "Slovakia", continent: "europe", dialCode: "+421", tz: "Europe/Bratislava"},
  {code: "SI", name: "Slovenia", continent: "europe", dialCode: "+386", tz: "Europe/Ljubljana"},
  {code: "ES", name: "Spain", continent: "europe", dialCode: "+34", tz: "Europe/Madrid"},
  {code: "SE", name: "Sweden", continent: "europe", dialCode: "+46", tz: "Europe/Stockholm"},
  {code: "CH", name: "Switzerland", continent: "europe", dialCode: "+41", tz: "Europe/Zurich"},
  {code: "UA", name: "Ukraine", continent: "europe", dialCode: "+380", tz: "Europe/Kyiv"},
  {code: "GB", name: "United Kingdom", continent: "europe", isPopularOilGas: true, dialCode: "+44", tz: "Europe/London", basins: ["North Sea (UK & Norway)"]},
  {code: "VA", name: "Vatican City", continent: "europe", dialCode: "+379", tz: "Europe/Vatican"},

  // --- ASIA & MIDDLE EAST (46 primary Asia + transcontinental KZ/TR) ---
  {code: "AF", name: "Afghanistan", continent: "asia", dialCode: "+93", tz: "Asia/Kabul"},
  {code: "BH", name: "Bahrain", continent: "asia", isMiddleEast: true, isPopularOilGas: true, dialCode: "+973", tz: "Asia/Bahrain", basins: ["Middle East / Arabian Basin"]},
  {code: "BD", name: "Bangladesh", continent: "asia", dialCode: "+880", tz: "Asia/Dhaka"},
  {code: "BT", name: "Bhutan", continent: "asia", dialCode: "+975", tz: "Asia/Thimphu"},
  {code: "BN", name: "Brunei", continent: "asia", isPopularOilGas: true, dialCode: "+673", tz: "Asia/Brunei", basins: ["Southeast Asia / Borneo"]},
  {code: "KH", name: "Cambodia", continent: "asia", dialCode: "+855", tz: "Asia/Phnom_Penh"},
  {code: "CN", name: "China", continent: "asia", isPopularOilGas: true, dialCode: "+86", tz: "Asia/Shanghai", basins: ["Bohai / Tarim / Ordos"]},
  {code: "IN", name: "India", continent: "asia", isPopularOilGas: true, dialCode: "+91", tz: "Asia/Kolkata", basins: ["Mumbai High / KG Basin"]},
  {code: "ID", name: "Indonesia", continent: "asia", isPopularOilGas: true, dialCode: "+62", tz: "Asia/Jakarta", basins: ["Southeast Asia / Borneo"]},
  {code: "IR", name: "Iran", continent: "asia", isMiddleEast: true, dialCode: "+98", tz: "Asia/Tehran"},
  {code: "IQ", name: "Iraq", continent: "asia", isMiddleEast: true, isPopularOilGas: true, dialCode: "+964", tz: "Asia/Baghdad", basins: ["Middle East / Mesopotamian Basin"]},
  {code: "IL", name: "Israel", continent: "asia", isMiddleEast: true, dialCode: "+972", tz: "Asia/Jerusalem", basins: ["Eastern Mediterranean"]},
  {code: "JP", name: "Japan", continent: "asia", dialCode: "+81", tz: "Asia/Tokyo"},
  {code: "JO", name: "Jordan", continent: "asia", isMiddleEast: true, dialCode: "+962", tz: "Asia/Amman"},
  {code: "KZ", name: "Kazakhstan", continent: "asia", alsoEurope: true, isPopularOilGas: true, dialCode: "+7", tz: "Asia/Almaty", basins: ["Caspian Basin"]},
  {code: "KW", name: "Kuwait", continent: "asia", isMiddleEast: true, isPopularOilGas: true, dialCode: "+965", tz: "Asia/Kuwait", basins: ["Middle East / Arabian Basin"]},
  {code: "KG", name: "Kyrgyzstan", continent: "asia", dialCode: "+996", tz: "Asia/Bishkek"},
  {code: "LA", name: "Laos", continent: "asia", dialCode: "+856", tz: "Asia/Vientiane"},
  {code: "LB", name: "Lebanon", continent: "asia", isMiddleEast: true, dialCode: "+961", tz: "Asia/Beirut"},
  {code: "MY", name: "Malaysia", continent: "asia", isPopularOilGas: true, dialCode: "+60", tz: "Asia/Kuala_Lumpur", basins: ["Southeast Asia / Borneo"]},
  {code: "MV", name: "Maldives", continent: "asia", dialCode: "+960", tz: "Indian/Maldives"},
  {code: "MN", name: "Mongolia", continent: "asia", dialCode: "+976", tz: "Asia/Ulaanbaatar"},
  {code: "MM", name: "Myanmar", continent: "asia", dialCode: "+95", tz: "Asia/Yangon"},
  {code: "NP", name: "Nepal", continent: "asia", dialCode: "+977", tz: "Asia/Kathmandu"},
  {code: "KP", name: "North Korea", continent: "asia", dialCode: "+850", tz: "Asia/Pyongyang"},
  {code: "OM", name: "Oman", continent: "asia", isMiddleEast: true, isPopularOilGas: true, dialCode: "+968", tz: "Asia/Muscat", basins: ["Middle East / Arabian Basin"]},
  {code: "PK", name: "Pakistan", continent: "asia", dialCode: "+92", tz: "Asia/Karachi"},
  {code: "PS", name: "Palestine", continent: "asia", isMiddleEast: true, dialCode: "+970", tz: "Asia/Hebron"},
  {code: "PH", name: "Philippines", continent: "asia", dialCode: "+63", tz: "Asia/Manila"},
  {code: "QA", name: "Qatar", continent: "asia", isMiddleEast: true, isPopularOilGas: true, dialCode: "+974", tz: "Asia/Qatar", basins: ["Middle East / Arabian Basin"]},
  {code: "SA", name: "Saudi Arabia", continent: "asia", isMiddleEast: true, isPopularOilGas: true, dialCode: "+966", tz: "Asia/Riyadh", basins: ["Middle East / Arabian Basin"]},
  {code: "SG", name: "Singapore", continent: "asia", isPopularOilGas: true, dialCode: "+65", tz: "Asia/Singapore", basins: ["Southeast Asia / Borneo"]},
  {code: "KR", name: "South Korea", continent: "asia", dialCode: "+82", tz: "Asia/Seoul"},
  {code: "LK", name: "Sri Lanka", continent: "asia", dialCode: "+94", tz: "Asia/Colombo"},
  {code: "SY", name: "Syria", continent: "asia", isMiddleEast: true, dialCode: "+963", tz: "Asia/Damascus"},
  {code: "TW", name: "Taiwan", continent: "asia", dialCode: "+886", tz: "Asia/Taipei"},
  {code: "TJ", name: "Tajikistan", continent: "asia", dialCode: "+992", tz: "Asia/Dushanbe"},
  {code: "TH", name: "Thailand", continent: "asia", dialCode: "+66", tz: "Asia/Bangkok", basins: ["Gulf of Thailand"]},
  {code: "TL", name: "Timor-Leste", continent: "asia", dialCode: "+670", tz: "Asia/Dili"},
  {code: "TR", name: "Turkey", continent: "asia", alsoEurope: true, isMiddleEast: true, dialCode: "+90", tz: "Europe/Istanbul"},
  {code: "TM", name: "Turkmenistan", continent: "asia", dialCode: "+993", tz: "Asia/Ashgabat", basins: ["Caspian Basin"]},
  {code: "AE", name: "United Arab Emirates", continent: "asia", isMiddleEast: true, isPopularOilGas: true, dialCode: "+971", tz: "Asia/Dubai", basins: ["Middle East / Arabian Basin"]},
  {code: "UZ", name: "Uzbekistan", continent: "asia", dialCode: "+998", tz: "Asia/Tashkent"},
  {code: "VN", name: "Vietnam", continent: "asia", dialCode: "+84", tz: "Asia/Ho_Chi_Minh"},
  {code: "YE", name: "Yemen", continent: "asia", isMiddleEast: true, dialCode: "+967", tz: "Asia/Aden"},

  // --- AFRICA (54 countries) ---
  {code: "DZ", name: "Algeria", continent: "africa", isPopularOilGas: true, dialCode: "+213", tz: "Africa/Algiers", basins: ["Hassi Messaoud / Berkine"]},
  {code: "AO", name: "Angola", continent: "africa", isPopularOilGas: true, dialCode: "+244", tz: "Africa/Luanda", basins: ["West Africa / Lower Congo"]},
  {code: "BJ", name: "Benin", continent: "africa", dialCode: "+229", tz: "Africa/Porto-Novo"},
  {code: "BW", name: "Botswana", continent: "africa", dialCode: "+267", tz: "Africa/Gaborone"},
  {code: "BF", name: "Burkina Faso", continent: "africa", dialCode: "+226", tz: "Africa/Ouagadougou"},
  {code: "BI", name: "Burundi", continent: "africa", dialCode: "+257", tz: "Africa/Bujumbura"},
  {code: "CV", name: "Cabo Verde", continent: "africa", dialCode: "+238", tz: "Atlantic/Cape_Verde"},
  {code: "CM", name: "Cameroon", continent: "africa", dialCode: "+237", tz: "Africa/Douala"},
  {code: "CF", name: "Central African Republic", continent: "africa", dialCode: "+236", tz: "Africa/Bangui"},
  {code: "TD", name: "Chad", continent: "africa", dialCode: "+235", tz: "Africa/Ndjamena"},
  {code: "KM", name: "Comoros", continent: "africa", dialCode: "+269", tz: "Indian/Comoro"},
  {code: "CG", name: "Congo (Republic of the)", continent: "africa", dialCode: "+242", tz: "Africa/Brazzaville", basins: ["West Africa / Lower Congo"]},
  {code: "CD", name: "Congo (Democratic Republic)", continent: "africa", dialCode: "+243", tz: "Africa/Kinshasa"},
  {code: "CI", name: "Cote d'Ivoire", continent: "africa", dialCode: "+225", tz: "Africa/Abidjan"},
  {code: "DJ", name: "Djibouti", continent: "africa", dialCode: "+253", tz: "Africa/Djibouti"},
  {code: "EG", name: "Egypt", continent: "africa", isMiddleEast: true, isPopularOilGas: true, dialCode: "+20", tz: "Africa/Cairo", basins: ["Gulf of Suez / Nile Delta"]},
  {code: "GQ", name: "Equatorial Guinea", continent: "africa", dialCode: "+240", tz: "Africa/Malabo", basins: ["West Africa / Gulf of Guinea"]},
  {code: "ER", name: "Eritrea", continent: "africa", dialCode: "+291", tz: "Africa/Asmara"},
  {code: "SZ", name: "Eswatini", continent: "africa", dialCode: "+268", tz: "Africa/Mbabane"},
  {code: "ET", name: "Ethiopia", continent: "africa", dialCode: "+251", tz: "Africa/Addis_Ababa"},
  {code: "GA", name: "Gabon", continent: "africa", dialCode: "+241", tz: "Africa/Libreville", basins: ["West Africa / Gabon Basin"]},
  {code: "GM", name: "Gambia", continent: "africa", dialCode: "+220", tz: "Africa/Banjul"},
  {code: "GH", name: "Ghana", continent: "africa", isPopularOilGas: true, dialCode: "+233", tz: "Africa/Accra", basins: ["West Africa / Tano Basin"]},
  {code: "GN", name: "Guinea", continent: "africa", dialCode: "+224", tz: "Africa/Conakry"},
  {code: "GW", name: "Guinea-Bissau", continent: "africa", dialCode: "+245", tz: "Africa/Bissau"},
  {code: "KE", name: "Kenya", continent: "africa", dialCode: "+254", tz: "Africa/Nairobi"},
  {code: "LS", name: "Lesotho", continent: "africa", dialCode: "+266", tz: "Africa/Maseru"},
  {code: "LR", name: "Liberia", continent: "africa", dialCode: "+231", tz: "Africa/Monrovia"},
  {code: "LY", name: "Libya", continent: "africa", isPopularOilGas: true, dialCode: "+218", tz: "Africa/Tripoli", basins: ["Sirte Basin"]},
  {code: "MG", name: "Madagascar", continent: "africa", dialCode: "+261", tz: "Indian/Antananarivo"},
  {code: "MW", name: "Malawi", continent: "africa", dialCode: "+265", tz: "Africa/Blantyre"},
  {code: "ML", name: "Mali", continent: "africa", dialCode: "+223", tz: "Africa/Bamako"},
  {code: "MR", name: "Mauritania", continent: "africa", dialCode: "+222", tz: "Africa/Nouakchott"},
  {code: "MU", name: "Mauritius", continent: "africa", dialCode: "+230", tz: "Indian/Mauritius"},
  {code: "MA", name: "Morocco", continent: "africa", dialCode: "+212", tz: "Africa/Casablanca"},
  {code: "MZ", name: "Mozambique", continent: "africa", isPopularOilGas: true, dialCode: "+258", tz: "Africa/Maputo", basins: ["Rovuma Basin"]},
  {code: "NA", name: "Namibia", continent: "africa", isPopularOilGas: true, dialCode: "+264", tz: "Africa/Windhoek", basins: ["Orange Basin"]},
  {code: "NE", name: "Niger", continent: "africa", dialCode: "+227", tz: "Africa/Niamey"},
  {code: "NG", name: "Nigeria", continent: "africa", isPopularOilGas: true, dialCode: "+234", tz: "Africa/Lagos", basins: ["West Africa / Niger Delta"]},
  {code: "RW", name: "Rwanda", continent: "africa", dialCode: "+250", tz: "Africa/Kigali"},
  {code: "ST", name: "Sao Tome and Principe", continent: "africa", dialCode: "+239", tz: "Africa/Sao_Tome"},
  {code: "SN", name: "Senegal", continent: "africa", dialCode: "+221", tz: "Africa/Dakar", basins: ["MSGBC Basin"]},
  {code: "SC", name: "Seychelles", continent: "africa", dialCode: "+248", tz: "Indian/Mahe"},
  {code: "SL", name: "Sierra Leone", continent: "africa", dialCode: "+232", tz: "Africa/Freetown"},
  {code: "SO", name: "Somalia", continent: "africa", dialCode: "+252", tz: "Africa/Mogadishu"},
  {code: "ZA", name: "South Africa", continent: "africa", dialCode: "+27", tz: "Africa/Johannesburg"},
  {code: "SS", name: "South Sudan", continent: "africa", dialCode: "+211", tz: "Africa/Juba"},
  {code: "SD", name: "Sudan", continent: "africa", dialCode: "+249", tz: "Africa/Khartoum"},
  {code: "TZ", name: "Tanzania", continent: "africa", dialCode: "+255", tz: "Africa/Dar_es_Salaam"},
  {code: "TG", name: "Togo", continent: "africa", dialCode: "+228", tz: "Africa/Lome"},
  {code: "TN", name: "Tunisia", continent: "africa", dialCode: "+216", tz: "Africa/Tunis"},
  {code: "UG", name: "Uganda", continent: "africa", dialCode: "+256", tz: "Africa/Kampala", basins: ["Albertine Graben"]},
  {code: "ZM", name: "Zambia", continent: "africa", dialCode: "+260", tz: "Africa/Lusaka"},
  {code: "ZW", name: "Zimbabwe", continent: "africa", dialCode: "+263", tz: "Africa/Harare"},

  // --- AUSTRALIA & OCEANIA (14 countries) ---
  {code: "AU", name: "Australia", continent: "oceania", isPopularOilGas: true, dialCode: "+61", tz: "Australia/Perth", basins: ["North West Shelf / Carnarvon", "Cooper Basin", "Surat / Bowen"]},
  {code: "FJ", name: "Fiji", continent: "oceania", dialCode: "+679", tz: "Pacific/Fiji"},
  {code: "KI", name: "Kiribati", continent: "oceania", dialCode: "+686", tz: "Pacific/Tarawa"},
  {code: "MH", name: "Marshall Islands", continent: "oceania", dialCode: "+692", tz: "Pacific/Majuro"},
  {code: "FM", name: "Micronesia", continent: "oceania", dialCode: "+691", tz: "Pacific/Pohnpei"},
  {code: "NR", name: "Nauru", continent: "oceania", dialCode: "+674", tz: "Pacific/Nauru"},
  {code: "NZ", name: "New Zealand", continent: "oceania", isPopularOilGas: true, dialCode: "+64", tz: "Pacific/Auckland", basins: ["Taranaki Basin"]},
  {code: "PW", name: "Palau", continent: "oceania", dialCode: "+680", tz: "Pacific/Palau"},
  {code: "PG", name: "Papua New Guinea", continent: "oceania", isPopularOilGas: true, dialCode: "+675", tz: "Pacific/Port_Moresby", basins: ["Papuan Basin"]},
  {code: "WS", name: "Samoa", continent: "oceania", dialCode: "+685", tz: "Pacific/Apia"},
  {code: "SB", name: "Solomon Islands", continent: "oceania", dialCode: "+677", tz: "Pacific/Guadalcanal"},
  {code: "TO", name: "Tonga", continent: "oceania", dialCode: "+676", tz: "Pacific/Tongatapu"},
  {code: "TV", name: "Tuvalu", continent: "oceania", dialCode: "+688", tz: "Pacific/Funafuti"},
  {code: "VU", name: "Vanuatu", continent: "oceania", dialCode: "+678", tz: "Pacific/Efate"},
]);

const COUNTRY_BY_CODE = new Map(
    GLOBAL_COUNTRIES_LIST.map((c) => [c.code, c]),
);

const COUNTRY_NAME_ALIASES = new Map([
  ["USA", "US"],
  ["U S A", "US"],
  ["UNITED STATES OF AMERICA", "US"],
  ["UNITED STATES", "US"],
  ["CAN", "CA"],
  ["CANADA", "CA"],
  ["MEX", "MX"],
  ["MEXICO", "MX"],
  ["UK", "GB"],
  ["UNITED KINGDOM", "GB"],
  ["GREAT BRITAIN", "GB"],
  ["SCOTLAND", "GB"],
  ["ENGLAND", "GB"],
  ["UAE", "AE"],
  ["U A E", "AE"],
  ["EMIRATES", "AE"],
  ["UNITED ARAB EMIRATES", "AE"],
  ["KSA", "SA"],
  ["SAUDI ARABIA", "SA"],
  ["TRINIDAD", "TT"],
  ["TRINIDAD AND TOBAGO", "TT"],
  ["TRINIDAD & TOBAGO", "TT"],
  ["BAHAMAS THE", "BS"],
  ["THE BAHAMAS", "BS"],
  ["CZECH REPUBLIC", "CZ"],
  ["IVORY COAST", "CI"],
  ["REPUBLIC OF THE CONGO", "CG"],
  ["DRC", "CD"],
  ["SOUTH KOREA", "KR"],
  ["PNG", "PG"],
]);
for (const c of GLOBAL_COUNTRIES_LIST) {
  COUNTRY_NAME_ALIASES.set(c.name.toUpperCase(), c.code);
  COUNTRY_NAME_ALIASES.set(
      c.name.toUpperCase().replace(/[^A-Z0-9]+/gu, " ").trim(),
      c.code,
  );
}

const NORTH_AMERICA_REGIONS = Object.freeze({
  // Canada
  "CA-AB": {country: "CA", code: "AB", name: "Alberta", tz: "America/Edmonton", basins: ["WCSB", "Montney", "Duvernay", "Oil Sands"]},
  "CA-BC": {country: "CA", code: "BC", name: "British Columbia", tz: "America/Vancouver", basins: ["WCSB", "Montney", "Horn River"]},
  "CA-SK": {country: "CA", code: "SK", name: "Saskatchewan", tz: "America/Regina", basins: ["WCSB", "Bakken", "Heavy Oil"]},
  "CA-MB": {country: "CA", code: "MB", name: "Manitoba", tz: "America/Winnipeg", basins: ["WCSB", "Williston"]},
  "CA-ON": {country: "CA", code: "ON", name: "Ontario", tz: "America/Toronto", basins: ["Eastern Canada"]},
  "CA-QC": {country: "CA", code: "QC", name: "Quebec", tz: "America/Toronto", basins: ["Eastern Canada"]},
  "CA-NL": {country: "CA", code: "NL", name: "Newfoundland and Labrador", tz: "America/St_Johns", basins: ["Atlantic Offshore"]},
  "CA-NS": {country: "CA", code: "NS", name: "Nova Scotia", tz: "America/Halifax", basins: ["Atlantic Offshore"]},
  "CA-NB": {country: "CA", code: "NB", name: "New Brunswick", tz: "America/Moncton", basins: ["Atlantic Canada"]},
  "CA-NT": {country: "CA", code: "NT", name: "Northwest Territories", tz: "America/Yellowknife", basins: ["Mackenzie / Northern"]},
  "CA-YT": {country: "CA", code: "YT", name: "Yukon", tz: "America/Whitehorse", basins: ["Northern"]},
  // United States
  "US-TX": {country: "US", code: "TX", name: "Texas", tz: "America/Chicago", basins: ["Permian Basin", "Eagle Ford", "Haynesville", "Barnett", "Gulf Coast"]},
  "US-ND": {country: "US", code: "ND", name: "North Dakota", tz: "America/Chicago", basins: ["Bakken / Williston"]},
  "US-OK": {country: "US", code: "OK", name: "Oklahoma", tz: "America/Chicago", basins: ["Anadarko", "SCOOP / STACK"]},
  "US-NM": {country: "US", code: "NM", name: "New Mexico", tz: "America/Denver", basins: ["Permian / Delaware", "San Juan"]},
  "US-WY": {country: "US", code: "WY", name: "Wyoming", tz: "America/Denver", basins: ["Powder River", "Green River"]},
  "US-LA": {country: "US", code: "LA", name: "Louisiana", tz: "America/Chicago", basins: ["Haynesville", "Gulf Coast"]},
  "US-PA": {country: "US", code: "PA", name: "Pennsylvania", tz: "America/New_York", basins: ["Marcellus / Appalachian"]},
  "US-CO": {country: "US", code: "CO", name: "Colorado", tz: "America/Denver", basins: ["DJ / Niobrara", "Piceance"]},
  "US-OH": {country: "US", code: "OH", name: "Ohio", tz: "America/New_York", basins: ["Utica / Marcellus"]},
  "US-WV": {country: "US", code: "WV", name: "West Virginia", tz: "America/New_York", basins: ["Marcellus / Appalachian"]},
  "US-AK": {country: "US", code: "AK", name: "Alaska", tz: "America/Anchorage", basins: ["North Slope", "Cook Inlet"]},
  "US-CA": {country: "US", code: "CA", name: "California", tz: "America/Los_Angeles", basins: ["San Joaquin"]},
  "US-MT": {country: "US", code: "MT", name: "Montana", tz: "America/Denver", basins: ["Bakken / Williston", "Powder River"]},
  "US-UT": {country: "US", code: "UT", name: "Utah", tz: "America/Denver", basins: ["Uinta Basin"]},
  "US-KS": {country: "US", code: "KS", name: "Kansas", tz: "America/Chicago", basins: ["Hugoton / Mid-Continent"]},
  "US-AR": {country: "US", code: "AR", name: "Arkansas", tz: "America/Chicago", basins: ["Fayetteville"]},
  "US-MS": {country: "US", code: "MS", name: "Mississippi", tz: "America/Chicago", basins: ["Gulf Coast"]},
  // International Energy Sub-Regions
  "MX-TAB": {country: "MX", code: "TAB", name: "Tabasco", tz: "America/Mexico_City", basins: ["Gulf of Mexico / Sureste"]},
  "MX-CAM": {country: "MX", code: "CAM", name: "Campeche", tz: "America/Merida", basins: ["Gulf of Mexico / Sureste"]},
  "MX-TAM": {country: "MX", code: "TAM", name: "Tamaulipas", tz: "America/Matamoros", basins: ["Burgos"]},
  "MX-VER": {country: "MX", code: "VER", name: "Veracruz", tz: "America/Mexico_City", basins: ["Tampico-Misantla"]},
  "MX-NL": {country: "MX", code: "NL", name: "Nuevo Leon", tz: "America/Monterrey", basins: ["Burgos"]},
  "GB-SCT": {country: "GB", code: "SCT", name: "Scotland", tz: "Europe/London", basins: ["North Sea (UK & Norway)"]},
  "GB-ENG": {country: "GB", code: "ENG", name: "England", tz: "Europe/London", basins: ["North Sea (UK & Norway)"]},
  "NO-RO": {country: "NO", code: "RO", name: "Rogaland (Stavanger)", tz: "Europe/Oslo", basins: ["North Sea (UK & Norway)"]},
  "NO-VL": {country: "NO", code: "VL", name: "Vestland (Bergen)", tz: "Europe/Oslo", basins: ["North Sea (UK & Norway)"]},
  "AE-AZ": {country: "AE", code: "AZ", name: "Abu Dhabi", tz: "Asia/Dubai", basins: ["Middle East / Arabian Basin"]},
  "AE-DU": {country: "AE", code: "DU", name: "Dubai", tz: "Asia/Dubai", basins: ["Middle East / Arabian Basin"]},
  "AE-SH": {country: "AE", code: "SH", name: "Sharjah", tz: "Asia/Dubai", basins: ["Middle East / Arabian Basin"]},
  "SA-EP": {country: "SA", code: "EP", name: "Eastern Province", tz: "Asia/Riyadh", basins: ["Middle East / Arabian Basin"]},
  "BR-RJ": {country: "BR", code: "RJ", name: "Rio de Janeiro", tz: "America/Sao_Paulo", basins: ["Brazil Pre-Salt (Santos & Campos)"]},
  "AR-NQ": {country: "AR", code: "NQ", name: "Neuquen", tz: "America/Argentina/Salta", basins: ["Vaca Muerta / Neuquén"]},
  "AU-WA": {country: "AU", code: "WA", name: "Western Australia", tz: "Australia/Perth", basins: ["North West Shelf / Carnarvon"]},
  "AU-QLD": {country: "AU", code: "QLD", name: "Queensland", tz: "Australia/Brisbane", basins: ["Surat / Bowen", "Cooper Basin"]},
});

const CANADIAN_PROVINCE_CODES = new Set([
  "AB", "BC", "SK", "MB", "ON", "QC", "NL", "NS", "NB", "PE", "NT", "YT", "NU",
]);

function normalizeText(value) {
  return String(value == null ? "" : value)
      .toLowerCase()
      .normalize("NFKD")
      .replace(/[\u0300-\u036f]/gu, "")
      .replace(/[^a-z0-9]+/gu, " ")
      .trim()
      .replace(/\s+/gu, " ");
}

function countryCodesForContinent(continentInput) {
  const norm = String(continentInput || "").trim().toLowerCase();
  if (!norm) return [];
  if (norm === "middle_east") {
    return GLOBAL_COUNTRIES_LIST.filter((c) => c.isMiddleEast === true).map((c) => c.code);
  }
  return GLOBAL_COUNTRIES_LIST.filter((c) => {
    if (c.continent === norm) return true;
    if (norm === "asia" && c.alsoAsia === true) return true;
    if (norm === "europe" && c.alsoEurope === true) return true;
    return false;
  }).map((c) => c.code);
}

function inferCountryAndRegion(countryInput, regionInput) {
  let region = String(regionInput || "").trim().toUpperCase();
  let country = String(countryInput || "").trim().toUpperCase();

  const regionNameMap = {
    "ALBERTA": ["CA", "AB"],
    "BRITISH COLUMBIA": ["CA", "BC"],
    "SASKATCHEWAN": ["CA", "SK"],
    "MANITOBA": ["CA", "MB"],
    "ONTARIO": ["CA", "ON"],
    "QUEBEC": ["CA", "QC"],
    "NEWFOUNDLAND": ["CA", "NL"],
    "NEWFOUNDLAND AND LABRADOR": ["CA", "NL"],
    "NOVA SCOTIA": ["CA", "NS"],
    "NEW BRUNSWICK": ["CA", "NB"],
    "NORTHWEST TERRITORIES": ["CA", "NT"],
    "YUKON": ["CA", "YT"],
    "TEXAS": ["US", "TX"],
    "NORTH DAKOTA": ["US", "ND"],
    "OKLAHOMA": ["US", "OK"],
    "NEW MEXICO": ["US", "NM"],
    "WYOMING": ["US", "WY"],
    "LOUISIANA": ["US", "LA"],
    "PENNSYLVANIA": ["US", "PA"],
    "COLORADO": ["US", "CO"],
    "OHIO": ["US", "OH"],
    "WEST VIRGINIA": ["US", "WV"],
    "ALASKA": ["US", "AK"],
    "CALIFORNIA": ["US", "CA"],
    "MONTANA": ["US", "MT"],
    "UTAH": ["US", "UT"],
    "KANSAS": ["US", "KS"],
    "ARKANSAS": ["US", "AR"],
    "MISSISSIPPI": ["US", "MS"],
    "ABU DHABI": ["AE", "AZ"],
    "DUBAI": ["AE", "DU"],
    "SHARJAH": ["AE", "SH"],
    "SCOTLAND": ["GB", "SCT"],
    "ENGLAND": ["GB", "ENG"],
    "TABASCO": ["MX", "TAB"],
    "CAMPECHE": ["MX", "CAM"],
    "TAMAULIPAS": ["MX", "TAM"],
    "VERACRUZ": ["MX", "VER"],
    "WESTERN AUSTRALIA": ["AU", "WA"],
    "QUEENSLAND": ["AU", "QLD"],
  };

  if (regionNameMap[region]) {
    if (!country) country = regionNameMap[region][0];
    region = regionNameMap[region][1];
  }

  if (country && !COUNTRY_BY_CODE.has(country)) {
    const cleanKey = country.replace(/[^A-Z0-9]+/gu, " ").trim();
    country = COUNTRY_NAME_ALIASES.get(country) ||
      COUNTRY_NAME_ALIASES.get(cleanKey) ||
      country.slice(0, 2);
  }

  if (!country && region) {
    country = CANADIAN_PROVINCE_CODES.has(region) ? "CA" : "US";
  }

  const finalCountryCode = country || "CA";
  const countryMeta = COUNTRY_BY_CODE.get(finalCountryCode) || null;
  const subMeta = NORTH_AMERICA_REGIONS[`${finalCountryCode}-${region}`] || null;

  return {
    countryCode: finalCountryCode,
    countryName: countryMeta ? countryMeta.name : finalCountryCode,
    continentCode: countryMeta ? countryMeta.continent : "north_america",
    isMiddleEast: Boolean(countryMeta && countryMeta.isMiddleEast === true),
    dialCode: countryMeta ? countryMeta.dialCode : "+1",
    regionCode: region,
    regionName: subMeta ? subMeta.name : region,
    timeZone: subMeta ? subMeta.tz : (countryMeta ? countryMeta.tz : (finalCountryCode === "US" ? "America/Chicago" : "America/Edmonton")),
    defaultBasins: subMeta ? subMeta.basins : (countryMeta && countryMeta.basins ? countryMeta.basins : []),
  };
}

function classifyCategoriesFromText(rawLabels = [], description = "") {
  const combined = normalizeText([...rawLabels, description].join(" "));
  const matched = new Set();

  for (const raw of rawLabels) {
    const codeCandidate = String(raw || "").trim().toLowerCase();
    if (CATEGORY_BY_CODE.has(codeCandidate)) {
      matched.add(codeCandidate);
    }
  }

  for (const cat of YELLOW_PAGES_CATEGORIES) {
    for (const kw of cat.keywords) {
      const normalizedKw = normalizeText(kw);
      if (normalizedKw && combined.includes(normalizedKw)) {
        matched.add(cat.code);
        break;
      }
    }
  }

  return [...matched];
}

function expandServiceSearchTerms(rawQuery) {
  const normalized = normalizeText(rawQuery);
  if (!normalized) return {normalized: "", terms: [], matchedCategoryCodes: []};
  const words = normalized.split(" ").filter((w) => w.length >= 2);
  const expanded = new Set(words);
  const matchedCategoryCodes = new Set();

  for (const group of SYNONYM_GROUPS) {
    const hit = group.some((phrase) => {
      const normPhrase = normalizeText(phrase);
      return normalized.includes(normPhrase) || words.includes(normPhrase);
    });
    if (hit) {
      for (const synonym of group) {
        for (const w of normalizeText(synonym).split(" ")) {
          if (w.length >= 2) expanded.add(w);
        }
      }
    }
  }

  for (const cat of YELLOW_PAGES_CATEGORIES) {
    const labelNorm = normalizeText(cat.label);
    if (labelNorm.includes(normalized) || normalized.includes(cat.code.replace(/_/gu, " "))) {
      matchedCategoryCodes.add(cat.code);
    }
    for (const kw of cat.keywords) {
      const kwNorm = normalizeText(kw);
      if (kwNorm && (normalized.includes(kwNorm) || (normalized.length >= 3 && kwNorm.includes(normalized)))) {
        matchedCategoryCodes.add(cat.code);
      }
    }
  }

  return {
    normalized,
    terms: [...expanded].slice(0, 24),
    matchedCategoryCodes: [...matchedCategoryCodes],
  };
}

function checkB2BCallingWindow(timeZone, now = new Date()) {
  try {
    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: timeZone || "America/Edmonton",
      weekday: "short",
      hour: "numeric",
      minute: "numeric",
      hour12: false,
    });
    const parts = Object.fromEntries(
        formatter.formatToParts(now).map((p) => [p.type, p.value]),
    );
    const weekday = parts.weekday;
    const hour = Number(parts.hour || 0);
    const minute = Number(parts.minute || 0);
    const totalMinutes = hour * 60 + minute;
    const isWeekday = !["Sat", "Sun"].includes(weekday);
    const allowed = isWeekday && totalMinutes >= 8 * 60 && totalMinutes <= 17 * 60 + 30;
    return {
      allowed,
      timeZone: timeZone || "America/Edmonton",
      localTimeLabel: `${weekday} ${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`,
    };
  } catch (err) {
    return {
      allowed: false,
      timeZone: "America/Edmonton",
      localTimeLabel: "Unknown",
    };
  }
}

module.exports = {
  CATEGORY_BY_CODE,
  COUNTRY_BY_CODE,
  GLOBAL_COUNTRIES_LIST,
  NORTH_AMERICA_REGIONS,
  SYNONYM_GROUPS,
  WORLD_CONTINENTS,
  YELLOW_PAGES_CATEGORIES,
  checkB2BCallingWindow,
  classifyCategoriesFromText,
  countryCodesForContinent,
  expandServiceSearchTerms,
  inferCountryAndRegion,
  normalizeText,
};
