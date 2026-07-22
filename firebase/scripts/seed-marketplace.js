const fs = require("fs");
const os = require("os");
const path = require("path");

const project = "flutter-flow-pipe";
const tokenFile = path.join(os.homedir(), ".config", "configstore", "firebase-tools.json");
const accessToken = JSON.parse(fs.readFileSync(tokenFile, "utf8"))?.tokens?.access_token;
if (!accessToken) throw new Error("Firebase CLI login token not found. Run firebase login first.");

const pipeSizes = ["1/4 in","3/8 in","1/2 in","5/8 in","3/4 in","7/8 in","1 in","1-1/4 in","1-1/2 in","1-3/4 in","2 in","2-1/8 in","2-3/8 in","2-1/2 in","2-7/8 in","3 in","3-1/2 in","3-7/8 in","4 in","4-1/2 in","5 in","5-1/2 in","5-7/8 in","6 in","6-5/8 in","7 in","7-5/8 in","8 in","8-5/8 in","9-5/8 in","10 in","10-3/4 in","11-3/4 in","12 in","13-3/8 in","14 in","16 in","18 in","20 in","24 in","30 in","36 in","42 in","48 in"];
const suckerRodSizes = ["5/8 in","3/4 in","7/8 in","1 in","1-1/8 in"];
const wallTypes = ["Not sure — buyer can verify","Thin wall / light wall","Standard wall","Heavy wall","Extra heavy wall","Drill stem / drill pipe","Production tubing","Casing","Sucker rod","Yellow band / yellow coated","Painted or powder coated","Galvanized","New surplus","Used oilfield pipe"];
const brands = {
  "Caterpillar":["301.8","305 CR","320","336","950 GC","966","D6","D8"],
  "Komatsu":["PC55MR-5","PC210LC-11","PC360LC-11","WA270-8","D65EX-18"],
  "Volvo CE":["EC18E","ECR58","EC220E","EC300E","L90H","A40G"],
  "John Deere":["35 P-Tier","210 P-Tier","350 P-Tier","544 P-Tier","850K"],
  "Hitachi":["ZX50U-5N","ZX210LC-7","ZX350LC-7","ZW220-6"],
  "JCB":["3CX","4CX","220X","540-170","270T"],
  "Bobcat":["E35","E60","S650","T76","TL619"],
  "Case":["580SV","CX210D","621G","TV450B"],
  "Sullair":["185 Series","375 Series","900H"],
  "Atlas Copco":["XAS 188","XAS 400","QAS 45","QAS 150"],
  "Lincoln Electric":["Ranger 250","Vantage 322","Air Vantage 600"],
  "Miller":["Bobcat 265","Trailblazer 330","Big Blue 600"],
  "National Oilwell Varco":["TDS-11SA","14-P-220","FD-1600"],
  "Weatherford":["MPD Package","Wellhead System","Rod Pump"],
  "New Holland":["B75D","B95D","B110D","C337","E57C"],
  "Kubota":["BX23S","M62","KX040-5","KX057-5","SVL75-3"],
  "Terex":["860SX","970 Elite","TL80","TA300"],
  "Mecalac":["TLB830","TLB870","12MTX","15MC"],
  "Manitou":["MLT 737","MLT 840","MTA 10055","MRT 2660"],
  "LiuGong":["766A","777A","915E","922F","856H"],
  "Develon":["DX62R-7","DX225LC-7","DX350LC-7","DL320-7"],
  "Hyundai CE":["HX60A","HX220A L","HX350A L","HL960A"],
  "Takeuchi":["TB240","TB260","TB290","TL10V2","TL12V2"],
  "Wacker Neuson":["EZ36","ET65","ET90","ST31","WL34"],
  "Yanmar":["ViO35-7","ViO55-6A","SV100-7","TL100VS"],
  "Liebherr":["A 914","R 920","R 945","L 550","PR 736"],
  "Kobelco":["SK55SRX-7","SK210LC-11","SK350LC-11","SK850LC-10"],
  "Link-Belt":["145 X4S","210 X4S","300 X4S","350 X4S"],
  "Gradall":["XL 3100 V","XL 4100 V","XL 5100 V","D152"],
  "Bell":["B20E","B30E","B40E","B50E"],
  "Genie":["GTH-5519","GTH-844","GTH-1056","S-65 XC"],
  "SkyTrak":["6034","6042","8042","10054","12054"],
  "Mahindra":["1626B","2638 HST","3650B","6075"],
  "Massey Ferguson":["MF 50","MF 60","MF 65","MF 750" ]
};

function value(v) {
  if (Array.isArray(v)) return { arrayValue: { values: v.map(value) } };
  if (v && typeof v === "object") return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k,x]) => [k,value(x)])) } };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "number") return { integerValue: String(v) };
  return { stringValue: String(v) };
}

const docs = {
  pipe_sizes: { values: pipeSizes, suckerRodSizes, schemaVersion: 1 },
  pipe_descriptions: { values: wallTypes, schemaVersion: 1 },
  equipment_brands: { brands, schemaVersion: 1 },
  schema: { version: 1, currency: "CAD", region: "CA", updatedBy: "seed-marketplace" }
};

const geographyDocs = {
  schema: {
    version: 1,
    hierarchy: ["country", "state_province", "region", "municipality", "town", "community"],
    liveSearchProvider: "Photon / OpenStreetMap",
    bulkGazetteerSource: "GeoNames",
    boundarySource: "Natural Earth",
    normalizedKeyFormat: "COUNTRY_CODE:region:place",
  }
};

const marketplaceTags = {
  retailer: ["Retailer", "sales"],
  dealer: ["Equipment Dealer", "sales"],
  "used-equipment": ["Used Equipment", "sales"],
  "new-equipment": ["New Equipment", "sales"],
  rentals: ["Equipment Rentals", "rental"],
  repairs: ["Equipment Repairs", "service"],
  "mobile-repair": ["Mobile Repair", "service"],
  "parts-supplier": ["Parts Supplier", "sales"],
  "used-pipe": ["Used Pipe", "pipe"],
  "new-pipe": ["New Pipe", "pipe"],
  "drill-pipe": ["Drill Pipe", "pipe"],
  casing: ["Casing", "pipe"],
  tubing: ["Production Tubing", "pipe"],
  "sucker-rod": ["Sucker Rod", "pipe"],
  "pipe-inspection": ["Pipe Inspection", "service"],
  "pipe-reclamation": ["Pipe Reclamation", "service"],
  fabrication: ["Custom Fabrication", "service"],
  welding: ["Welding", "service"],
  trucking: ["Trucking", "transport"],
  hauling: ["Heavy Hauling", "transport"],
  "hot-shot": ["Hot Shot Service", "transport"],
  "vacuum-truck": ["Vacuum Truck Service", "transport"],
  "water-hauling": ["Water Hauling", "transport"],
  "oilfield-services": ["Oilfield Services", "service"],
  "farm-ranch": ["Farm & Ranch Supplier", "sales"],
  auction: ["Auction Company", "sales"],
  "consignment-sales": ["Consignment Sales", "sales"],
};

async function run() {
  for (const [id, data] of Object.entries(docs)) {
    const url = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/marketplace_catalog/${id}`;
    const response = await fetch(url, {
      method: "PATCH",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({ fields: Object.fromEntries(Object.entries(data).map(([k,v]) => [k,value(v)])) })
    });
    if (!response.ok) throw new Error(`${id}: ${response.status} ${await response.text()}`);
    console.log(`Seeded marketplace_catalog/${id}`);
  }
  for (const [id, data] of Object.entries(geographyDocs)) {
    const url = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/geography_catalog/${id}`;
    const response = await fetch(url, {
      method: "PATCH",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({ fields: Object.fromEntries(Object.entries(data).map(([k,v]) => [k,value(v)])) })
    });
    if (!response.ok) throw new Error(`${id}: ${response.status} ${await response.text()}`);
    console.log(`Seeded geography_catalog/${id}`);
  }
  for (const [id, values] of Object.entries(marketplaceTags)) {
    const data = {
      label: values[0],
      normalizedLabel: id,
      category: values[1],
      status: "approved",
      source: "pipe_buyer_seed",
      schemaVersion: 1,
    };
    const url = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/marketplace_tags/${id}`;
    const response = await fetch(url, {
      method: "PATCH",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({ fields: Object.fromEntries(Object.entries(data).map(([k,v]) => [k,value(v)])) })
    });
    if (!response.ok) throw new Error(`${id}: ${response.status} ${await response.text()}`);
    console.log(`Seeded marketplace_tags/${id}`);
  }
}

run().catch((error) => { console.error(error.message); process.exitCode = 1; });
