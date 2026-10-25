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
      "picker haul", "pipe hauling", "oilfield hauling", "freight",
    ],
  },
  {
    code: "vacuum_hydrovac_fluid",
    label: "Vacuum, Hydrovac & Fluid Hauling",
    section: "yellow",
    keywords: [
      "vac truck", "vacuum truck", "hydrovac", "combo vac", "water hauling",
      "fluid hauling", "produced water", "tank cleaning", "steamer", "pressure truck",
      "kill truck", "hot oiler", "flushby",
    ],
  },
  {
    code: "hotshot_pilot_logistics",
    label: "Hot Shot, Pilot Cars & Logistics",
    section: "yellow",
    keywords: [
      "hotshot", "hot shot", "pilot car", "oversize escort", "high pole",
      "route survey", "traffic control", "expedited freight", "courier", "dispatch",
    ],
  },
  {
    code: "crane_picker_rigging",
    label: "Cranes, Picker Trucks & Rigging",
    section: "yellow",
    keywords: [
      "crane", "picker", "picker truck", "boom truck", "knuckle boom",
      "rigging", "hoisting", "telehandler", "heavy lift", "jack and roll",
    ],
  },
  {
    code: "pipe_octg_supply",
    label: "Pipe, OCTG, Casing & Tubing Supply",
    section: "yellow",
    keywords: [
      "pipe", "octg", "casing", "tubing", "drill pipe", "drill stem",
      "line pipe", "sucker rod", "structural pipe", "piling", "culvert",
      "flanges", "fittings", "steel pipe", "surplus pipe",
    ],
  },
  {
    code: "pipe_inspection_ndt",
    label: "Pipe Inspection, NDT & Reclamation",
    section: "yellow",
    keywords: [
      "pipe inspection", "ndt", "non destructive testing", "emi", "ultrasonic",
      "magnetic particle", "radiography", "threading", "pipe straightening",
      "pipe cleaning", "reclamation", "drift", "hydrotesting", "hardbanding",
    ],
  },
  {
    code: "drilling_rigs_directional",
    label: "Drilling, Service Rigs & Directional",
    section: "yellow",
    keywords: [
      "drilling", "drilling rig", "service rig", "workover", "directional drilling",
      "mwd", "lwd", "mud motor", "corings", "rathole", "conductor barrel", "spud",
    ],
  },
  {
    code: "completions_frac_wireline",
    label: "Completions, Frac, Coil & Wireline",
    section: "yellow",
    keywords: [
      "completions", "fracturing", "frac", "acidizing", "cementing",
      "coiled tubing", "coil tubing", "wireline", "slickline", "e-line",
      "perforating", "well testing", "flowback", "nitrogen", "stimulation",
    ],
  },
  {
    code: "wellhead_valves_pressure",
    label: "Wellheads, Valves & Pressure Control",
    section: "yellow",
    keywords: [
      "wellhead", "valves", "bop", "blowout preventer", "pressure control",
      "snubbing", "choke manifold", "frac stack", "christmas tree", "actuator",
      "greasing", "torquing", "pressure testing",
    ],
  },
  {
    code: "pumps_artificial_lift",
    label: "Artificial Lift, Pumps & Compression",
    section: "yellow",
    keywords: [
      "artificial lift", "pumpjack", "rod pump", "esp", "pcp", "plunger lift",
      "gas lift", "compressor", "compression", "generator", "genset", "downhole pump",
    ],
  },
  {
    code: "tanks_vessels_process",
    label: "Tanks, Vessels & Process Equipment",
    section: "yellow",
    keywords: [
      "frac tank", "storage tank", "water tank", "fuel tank", "separator",
      "treater", "heater treater", "pressure vessel", "dehydrator", "flare stack",
      "scrubber", "line heater", "skid package", "absa",
    ],
  },
  {
    code: "welding_machining_fab",
    label: "Mobile Welding, Machining & Fabrication",
    section: "yellow",
    keywords: [
      "welding", "mobile welding", "b pressure", "rig welder", "pipefitting",
      "machine shop", "cnc machining", "custom fabrication", "structural steel",
      "sandblasting", "coating", "millwright",
    ],
  },
  {
    code: "equipment_rentals_tools",
    label: "Oilfield Rentals, Boilers & Downhole Tools",
    section: "yellow",
    keywords: [
      "equipment rental", "oilfield rentals", "boiler", "light tower",
      "heater", "flameless heater", "trash pump", "downhole tools", "fishing tools",
      "jar", "stabilizer", "rigwash", "containment",
    ],
  },
  {
    code: "matting_lease_civil",
    label: "Access Matting, Civil & Lease Construction",
    section: "yellow",
    keywords: [
      "rig mats", "access mats", "swamp mats", "crane mats", "bridges",
      "lease construction", "earthworks", "mulching", "clearing", "slash",
      "road building", "excavation", "dozer", "grader", "gravel",
    ],
  },
  {
    code: "pipeline_facility_construction",
    label: "Pipeline & Facility Construction",
    section: "yellow",
    keywords: [
      "pipeline", "pipeline contractor", "facility construction", "plant turnaround",
      "integrity dig", "hdd", "horizontal directional drilling", "trenching",
      "tie-in", "pigging", "composite pipe", "fiberglass pipe",
    ],
  },
  {
    code: "electrical_automation_scada",
    label: "Electrical, Instrumentation & SCADA",
    section: "yellow",
    keywords: [
      "electrical", "instrumentation", "scada", "automation", "plc",
      "controls", "meter proving", "measurement", "solar skid", "cathodic protection",
      "fiber optic", "communications",
    ],
  },
  {
    code: "safety_h2s_medics",
    label: "Safety, H2S, Industrial Medics & Fire",
    section: "yellow",
    keywords: [
      "safety", "h2s", "breathing air", "scba", "gas detection", "medics",
      "industrial medic", "mtc", "ambulance", "firewatch", "fire suppression",
      " firefighting", "well control", "confined space", "ppe",
    ],
  },
  {
    code: "environmental_remediation_waste",
    label: "Environmental, Waste & Remediation",
    section: "yellow",
    keywords: [
      "environmental", "remediation", "reclamation", "spill response",
      "waste management", "landfill", "disposal well", "norm", "soil sampling",
      "bioremediation", "abandonment", "decommissioning",
    ],
  },
  {
    code: "chemical_mud_lubricants",
    label: "Drilling Fluids, Chemicals & Fuel",
    section: "yellow",
    keywords: [
      "drilling fluids", "mud", "production chemicals", "methanol", "glycol",
      "scavenger", "corrosion inhibitor", "bulk fuel", "cardlock", "lubricants",
      "propane", "industrial gases",
    ],
  },
  {
    code: "fleet_heavy_duty_repair",
    label: "Heavy-Duty Mechanics, Hydraulics & Fleet",
    section: "yellow",
    keywords: [
      "heavy duty mechanic", "mobile mechanic", "truck repair", "trailer repair",
      "cvip", "dot inspection", "hydraulics", "hose", "diesel repair", "tires",
      "driveline", "transmission",
    ],
  },
  {
    code: "camps_catering_accommodations",
    label: "Remote Camps, Catering & Portable Buildings",
    section: "yellow",
    keywords: [
      "camp", "remote camp", "workforce housing", "catering", "wellsite trailer",
      "skid shack", "office trailer", "sleeper", "washcar", "septic", "potable water",
      "security", "gate guard",
    ],
  },
  {
    code: "surveying_engineering_geomatics",
    label: "Engineering, Surveying & Line Locating",
    section: "yellow",
    keywords: [
      "surveying", "land survey", "engineering", "epcm", "geomatics", "gis",
      "line locating", "ground disturbance", "drone", "lidar", "geotechnical",
      "geology",
    ],
  },
  {
    code: "staffing_training_compliance",
    label: "Staffing, Safety Training & Compliance",
    section: "white",
    keywords: [
      "staffing", "recruiting", "labour", "crew transport", "safety training",
      "first aid", "isnetworld", "complyworks", "avetta", "cor", "drug testing",
    ],
  },
  {
    code: "explorers_producers_midstream",
    label: "Explorers, Producers (E&P) & Midstream",
    section: "blue",
    keywords: [
      "oil and gas producer", "exploration", "operator", "midstream",
      "gas plant", "battery", "terminal", "refinery", "petrochemical",
    ],
  },
]);

const CATEGORY_BY_CODE = new Map(
    YELLOW_PAGES_CATEGORIES.map((cat) => [cat.code, cat]),
);

const SYNONYM_GROUPS = Object.freeze([
  ["vac", "vacuum", "hydrovac", "combo vac", "suction", "fluid hauling"],
  ["ndt", "inspection", "emi", "ultrasonic", "tubing inspection", "casing inspection"],
  ["octg", "casing", "tubing", "drill pipe", "line pipe", "pipe", "sucker rod"],
  ["hotshot", "hot shot", "expedited", "pilot car", "escort"],
  ["picker", "boom truck", "crane", "rigging", "hoisting"],
  ["winch", "bed truck", "heavy haul", "rig moving", "lowboy", "step deck"],
  ["frac", "fracturing", "stimulation", "coil", "coiled tubing", "acidizing"],
  ["wireline", "slickline", "perforating", "well testing", "flowback"],
  ["bop", "wellhead", "valve", "valves", "pressure control", "snubbing"],
  ["welder", "welding", "b pressure", "fabrication", "machine shop", "machining"],
  ["rig mat", "rig mats", "access mats", "swamp mats", "matting", "lease construction"],
  ["h2s", "medic", "medics", "safety", "breathing air", "firewatch"],
  ["camp", "camps", "catering", "wellsite trailer", "skid shack", "sleeper"],
  ["scada", "instrumentation", "automation", "electrical", "plc"],
  ["mechanic", "heavy duty", "hydraulics", "cvip", "fleet repair"],
  ["boiler", "heater", "light tower", "rental", "rentals"],
]);

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
  };

  if (regionNameMap[region]) {
    if (!country) country = regionNameMap[region][0];
    region = regionNameMap[region][1];
  }
  if (country === "CANADA" || country === "CAN") country = "CA";
  if (country === "USA" || country === "UNITED STATES") country = "US";

  if (!country && region) {
    country = CANADIAN_PROVINCE_CODES.has(region) ? "CA" : "US";
  }
  const meta = NORTH_AMERICA_REGIONS[`${country}-${region}`] || null;
  return {
    countryCode: country || "CA",
    regionCode: region,
    regionName: meta ? meta.name : region,
    timeZone: meta ? meta.tz : (country === "US" ? "America/Chicago" : "America/Edmonton"),
    defaultBasins: meta ? meta.basins : [],
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
    // Standard respectful B2B oilfield calling hours: Mon-Fri 08:00 - 17:30 local
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
  NORTH_AMERICA_REGIONS,
  SYNONYM_GROUPS,
  YELLOW_PAGES_CATEGORIES,
  checkB2BCallingWindow,
  classifyCategoriesFromText,
  expandServiceSearchTerms,
  inferCountryAndRegion,
  normalizeText,
};
