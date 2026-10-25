const fs = require("fs");
const os = require("os");
const path = require("path");

const project = "flutter-flow-pipe";
const isDryRun = process.argv.includes("--dry-run") || process.argv.includes("-n");
const confirmProduction = process.argv.includes("--confirm-production");
const emulatorHost = String(process.env.FIRESTORE_EMULATOR_HOST || "").trim();
const tokenFile = path.join(os.homedir(), ".config", "configstore", "firebase-tools.json");

function readAccessToken() {
  if (!fs.existsSync(tokenFile)) {
    throw new Error("Firebase CLI login token not found. Run firebase login first.");
  }
  const accessToken = JSON.parse(fs.readFileSync(tokenFile, "utf8"))?.tokens?.access_token;
  if (!accessToken) throw new Error("Firebase CLI login token not found. Run firebase login first.");
  return accessToken;
}

const pipeSizes = ["1/4 in","3/8 in","1/2 in","5/8 in","3/4 in","7/8 in","1 in","1-1/4 in","1-1/2 in","1-3/4 in","2 in","2-1/8 in","2-3/8 in","2-1/2 in","2-7/8 in","3 in","3-1/2 in","3-7/8 in","4 in","4-1/2 in","5 in","5-1/2 in","5-7/8 in","6 in","6-5/8 in","7 in","7-5/8 in","8 in","8-5/8 in","9-5/8 in","10 in","10-3/4 in","11-3/4 in","12 in","13-3/8 in","14 in","16 in","18 in","20 in","24 in","30 in","36 in","42 in","48 in"];
const suckerRodSizes = ["5/8 in","3/4 in","7/8 in","1 in","1-1/8 in"];
const wallTypes = ["Not sure — buyer can verify","Thin wall / light wall","Standard wall","Heavy wall","Extra heavy wall","Drill stem / drill pipe","Production tubing","Casing","Sucker rod","Yellow band / yellow coated","Painted or powder coated","Galvanized","New surplus","Used oilfield pipe"];

const equipmentCatalogPath = path.resolve(__dirname, "../../assets/data/equipment_catalog_50yr.json");
const equipmentCatalog = JSON.parse(fs.readFileSync(equipmentCatalogPath, "utf8"));

const brands = Object.fromEntries(
  equipmentCatalog.manufacturers.map((mfr) => [
    mfr.name,
    mfr.manualEntryOnly ? mfr.exampleModels : mfr.models.map((m) => m.model),
  ]),
);

const equipmentCatalogIndex = {
  schemaVersion: equipmentCatalog.schemaVersion,
  generatedAt: equipmentCatalog.generatedAt,
  yearFloor: equipmentCatalog.yearFloor,
  yearCeiling: equipmentCatalog.yearCeiling,
  licensing: equipmentCatalog.licensing,
  stats: equipmentCatalog.stats,
  manufacturers: equipmentCatalog.manufacturers.map((mfr) => ({
    id: mfr.id,
    shardDocId: `equipment_mfr_${mfr.id}`,
    name: mfr.name,
    aliases: mfr.aliases,
    categories: mfr.categories,
    manualEntryOnly: mfr.manualEntryOnly,
    manualEntryReason: mfr.manualEntryReason,
    wmiPrefixes: mfr.wmiPrefixes,
    modelCount: mfr.models.length,
    exampleModels: mfr.exampleModels,
  })),
};

const equipmentManufacturerDocs = Object.fromEntries(
  equipmentCatalog.manufacturers.map((mfr) => [
    `equipment_mfr_${mfr.id}`,
    {
      schemaVersion: equipmentCatalog.schemaVersion,
      generatedAt: equipmentCatalog.generatedAt,
      yearFloor: equipmentCatalog.yearFloor,
      yearCeiling: equipmentCatalog.yearCeiling,
      id: mfr.id,
      name: mfr.name,
      aliases: mfr.aliases,
      categories: mfr.categories,
      manualEntryOnly: mfr.manualEntryOnly,
      manualEntryReason: mfr.manualEntryReason,
      wmiPrefixes: mfr.wmiPrefixes,
      exampleModels: mfr.exampleModels,
      modelCount: mfr.models.length,
      models: mfr.models,
    },
  ]),
);

function value(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(value) } };
  if (typeof v === "object") return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k,x]) => [k,value(x)])) } };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "number") return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  return { stringValue: String(v) };
}

const docs = {
  pipe_sizes: { values: pipeSizes, suckerRodSizes, schemaVersion: 1 },
  pipe_descriptions: { values: wallTypes, schemaVersion: 1 },
  equipment_brands: {
    brands,
    schemaVersion: equipmentCatalog.schemaVersion,
    generatedAt: equipmentCatalog.generatedAt,
    yearFloor: equipmentCatalog.yearFloor,
    yearCeiling: equipmentCatalog.yearCeiling,
  },
  equipment_catalog_index: equipmentCatalogIndex,
  ...equipmentManufacturerDocs,
  schema: { version: 2, currency: "CAD", region: "CA", updatedBy: "seed-marketplace" }
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
  if (isDryRun) {
    let serializedBytes = 0;
    for (const [id, data] of Object.entries(docs)) {
      const body = JSON.stringify({ fields: Object.fromEntries(Object.entries(data).map(([k,v]) => [k,value(v)])) });
      const bytes = Buffer.byteLength(body, "utf8");
      if (bytes >= 950 * 1024) throw new Error(`REST payload for marketplace_catalog/${id} too large: ${bytes} bytes`);
      serializedBytes += bytes;
    }
    console.log(`Dry-run serialized ${Object.keys(docs).length} marketplace_catalog docs (${(serializedBytes / 1024).toFixed(1)} KB REST JSON) + ${Object.keys(geographyDocs).length} geography_catalog docs + ${Object.keys(marketplaceTags).length} marketplace_tags docs.`);
    return;
  }
  if (!emulatorHost && !confirmProduction) {
    throw new Error(
      `Refusing unconfirmed write to live Firestore project "${project}". ` +
      `Set FIRESTORE_EMULATOR_HOST, pass --dry-run, or explicitly pass --confirm-production.`
    );
  }
  const accessToken = readAccessToken();
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
