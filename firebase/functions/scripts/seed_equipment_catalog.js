"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {applicationDefault, deleteApp, initializeApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");

const MAX_DOC_BYTES = 500 * 1024; // Strict 500 KB per-shard ceiling (Firestore hard limit is 1 MiB)
const MAX_BATCH_DOCS = 15;
const MAX_BATCH_BYTES = 2 * 1024 * 1024;

function parseArgs(argv) {
  const options = {
    dryRun: false,
    projectId: process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || "flutter-flow-pipe",
    emulatorHost: process.env.FIRESTORE_EMULATOR_HOST || "",
    catalogPath: path.resolve(__dirname, "../../../assets/data/equipment_catalog_50yr.json"),
  };

  for (const arg of argv) {
    if (arg === "--dry-run" || arg === "-n") {
      options.dryRun = true;
    } else if (arg.startsWith("--project=")) {
      options.projectId = arg.slice("--project=".length).trim();
    } else if (arg.startsWith("--emulator=")) {
      options.emulatorHost = arg.slice("--emulator=".length).trim();
    } else if (arg.startsWith("--catalog=")) {
      options.catalogPath = path.resolve(arg.slice("--catalog=".length).trim());
    } else if (arg === "--help" || arg === "-h") {
      options.help = true;
    } else {
      throw new Error(`Unknown CLI argument: ${arg}`);
    }
  }
  return options;
}

function printUsage() {
  console.log(
      [
        "Usage: node firebase/functions/scripts/seed_equipment_catalog.js [options]",
        "",
        "Options:",
        "  --dry-run, -n          Validate catalog & shard sizes without writing to Firestore",
        "  --project=<id>         Firebase project ID (default: flutter-flow-pipe)",
        "  --emulator=<host:port> Target local Firestore emulator (or set FIRESTORE_EMULATOR_HOST)",
        "  --catalog=<path>       Override path to equipment_catalog_50yr.json",
        "  --help, -h             Show this help message",
      ].join("\n"),
  );
}

function buildEquipmentBrandsMap(manufacturers) {
  const brands = {};
  for (const mfr of manufacturers) {
    if (mfr.manualEntryOnly) {
      brands[mfr.name] = [...mfr.exampleModels];
    } else {
      brands[mfr.name] = mfr.models.map((m) => m.model);
    }
  }
  return brands;
}

function buildCatalogIndexPayload(catalog) {
  return {
    schemaVersion: catalog.schemaVersion,
    generatedAt: catalog.generatedAt,
    yearFloor: catalog.yearFloor,
    yearCeiling: catalog.yearCeiling,
    licensing: catalog.licensing,
    stats: catalog.stats,
    manufacturers: catalog.manufacturers.map((mfr) => ({
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
}

function buildPlannedDocuments(catalog) {
  if (!catalog || catalog.schemaVersion !== 2 || !Array.isArray(catalog.manufacturers)) {
    throw new Error("Invalid equipment_catalog_50yr.json payload (expected schemaVersion 2).");
  }
  if (catalog.licensing?.prohibitedSourcesUsed !== false) {
    throw new Error("Refusing to seed catalog: licensing.prohibitedSourcesUsed must be false.");
  }

  const planned = [];

  const indexPayload = buildCatalogIndexPayload(catalog);
  planned.push({
    collection: "marketplace_catalog",
    docId: "equipment_catalog_index",
    data: indexPayload,
  });

  const brandsPayload = {
    brands: buildEquipmentBrandsMap(catalog.manufacturers),
    schemaVersion: catalog.schemaVersion,
    generatedAt: catalog.generatedAt,
    yearFloor: catalog.yearFloor,
    yearCeiling: catalog.yearCeiling,
  };
  planned.push({
    collection: "marketplace_catalog",
    docId: "equipment_brands",
    data: brandsPayload,
  });

  for (const mfr of catalog.manufacturers) {
    if (!mfr.id || !/^[a-z0-9_]+$/.test(mfr.id)) {
      throw new Error(`Invalid manufacturer id: ${mfr.id}`);
    }
    const shardPayload = {
      schemaVersion: catalog.schemaVersion,
      generatedAt: catalog.generatedAt,
      yearFloor: catalog.yearFloor,
      yearCeiling: catalog.yearCeiling,
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
    };
    planned.push({
      collection: "marketplace_catalog",
      docId: `equipment_mfr_${mfr.id}`,
      data: shardPayload,
    });
  }

  for (const entry of planned) {
    entry.bytes = Buffer.byteLength(JSON.stringify(entry.data), "utf8");
    if (entry.bytes >= MAX_DOC_BYTES) {
      throw new Error(
          `Document ${entry.collection}/${entry.docId} is ${entry.bytes} bytes, exceeding 500 KB safety ceiling.`,
      );
    }
  }

  return planned;
}

function chunkIntoBatches(planned) {
  const chunks = [];
  let current = [];
  let currentBytes = 0;

  for (const entry of planned) {
    if (
      current.length > 0 &&
      (current.length >= MAX_BATCH_DOCS || currentBytes + entry.bytes > MAX_BATCH_BYTES)
    ) {
      chunks.push(current);
      current = [];
      currentBytes = 0;
    }
    current.push(entry);
    currentBytes += entry.bytes;
  }
  if (current.length > 0) chunks.push(current);
  return chunks;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    printUsage();
    return;
  }

  if (!fs.existsSync(options.catalogPath)) {
    throw new Error(`Catalog JSON not found at ${options.catalogPath}. Run tool/build_equipment_catalog.mjs first.`);
  }

  const catalog = JSON.parse(fs.readFileSync(options.catalogPath, "utf8"));
  const planned = buildPlannedDocuments(catalog);
  const batches = chunkIntoBatches(planned);
  const totalBytes = planned.reduce((sum, d) => sum + d.bytes, 0);
  const largest = planned.reduce((max, d) => (d.bytes > max.bytes ? d : max), planned[0]);

  if (options.dryRun) {
    console.log("================================================================");
    console.log("PipeBuyer Equipment Catalog Seeder — DRY RUN");
    console.log("================================================================");
    console.log(`Catalog Source:           ${options.catalogPath}`);
    console.log(`Schema Version:           ${catalog.schemaVersion} (${catalog.yearFloor}–${catalog.yearCeiling})`);
    console.log(`Manufacturers:            ${catalog.stats.totalManufacturers} (${catalog.stats.fullCatalogManufacturers} full + ${catalog.stats.manualEntryManufacturers} manual-entry)`);
    console.log(`Total Models / Engines:   ${catalog.stats.totalModels} models / ${catalog.stats.totalEngineOptions} engine options`);
    console.log(`Planned Firestore Docs:   ${planned.length} (1 index + 1 equipment_brands + ${catalog.manufacturers.length} manufacturer shards)`);
    console.log(`Planned Write Batches:    ${batches.length}`);
    console.log(`Total Payload Size:       ${(totalBytes / 1024).toFixed(1)} KB`);
    console.log(`Largest Document:         ${largest.collection}/${largest.docId} (${(largest.bytes / 1024).toFixed(1)} KB < 500.0 KB limit)`);
    console.log("Dry-run validation PASSED (zero Firestore writes executed).");
    return;
  }

  if (options.emulatorHost) {
    process.env.FIRESTORE_EMULATOR_HOST = options.emulatorHost;
  }

  const appConfig = process.env.FIRESTORE_EMULATOR_HOST ?
    {projectId: options.projectId} :
    {credential: applicationDefault(), projectId: options.projectId};

  const app = initializeApp(appConfig, `equipment-catalog-seed-${Date.now()}`);
  try {
    const db = getFirestore(app);
    const now = Timestamp.now();

    for (let i = 0; i < batches.length; i++) {
      const chunk = batches[i];
      const batch = db.batch();
      for (const entry of chunk) {
        const ref = db.collection(entry.collection).doc(entry.docId);
        batch.set(ref, {
          ...entry.data,
          updatedAt: now,
          updatedBy: "seed_equipment_catalog",
        });
      }
      await batch.commit();
      console.log(`Committed batch ${i + 1}/${batches.length} (${chunk.length} docs)`);
    }

    const targetDesc = process.env.FIRESTORE_EMULATOR_HOST ?
      `emulator (${process.env.FIRESTORE_EMULATOR_HOST})` :
      `project ${options.projectId}`;
    console.log(
        `Successfully seeded ${planned.length} equipment catalog documents to ${targetDesc}.`,
    );
  } finally {
    await deleteApp(app);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = {
  buildCatalogIndexPayload,
  buildEquipmentBrandsMap,
  buildPlannedDocuments,
};
