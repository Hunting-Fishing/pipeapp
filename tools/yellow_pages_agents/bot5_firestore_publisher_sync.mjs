#!/usr/bin/env node
/**
 * Bot 5 — Large-Scale Firestore Yellow Pages Reconciler, JSONL Streamer & Batch Publisher
 *
 * Converts `03_audited_companies.json` (22,646+ North American Oil & Gas companies) into:
 *   1. `data/yellow_pages/ledger/05_private_companies.jsonl` (`yellow_pages_companies`)
 *   2. `data/yellow_pages/ledger/05_public_entries.jsonl` (`yellow_pages_public_entries`,
 *      built directly via `buildPublicEntry()` from `firebase/functions/yellow_pages_policy.js`
 *      for 100% schema parity with Cloud Functions!)
 *   3. `data/yellow_pages/ledger/05_firestore_ready_bundle.json`
 *   4. `data/yellow_pages/reports/05_sync_readiness_report.md`
 *
 * When `--apply --project <projectId>` is passed:
 *   - Automatically refreshes Firebase CLI OAuth access token if near expiry.
 *   - Uses `batchSize = 25` (staying well below Firestore's 40,000 index-entry per-commit ceiling
 *     given `adminSearchTokens` + `searchTokens` arrays) across `concurrency = 12` parallel
 *     workers with exponential backoff retry on 429/5xx.
 */

import {execSync} from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";

const require = createRequire(import.meta.url);
const {
  CATEGORY_BY_CODE,
  inferCountryAndRegion,
} = require("../../firebase/functions/yellow_pages_taxonomy.js");
const {
  normalizeNorthAmericanPhone,
  buildPublicEntry,
  isPublicationEligible,
  buildAdminSearchTokens,
} = require("../../firebase/functions/yellow_pages_policy.js");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const LEDGER_DIR = path.join(REPO_ROOT, "data/yellow_pages/ledger");
const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");

const TIMESTAMP_KEYS = new Set(["createdAt", "updatedAt", "publishedAt", "paidThrough"]);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function writeFileAtomic(targetPath, content) {
  const tmpPath = `${targetPath}.tmp-${process.pid}`;
  await fs.writeFile(tmpPath, content, "utf8");
  await fs.rename(tmpPath, targetPath);
}

async function resolveAccessToken(projectId = "pipebuyer-5c77f") {
  if (process.env.FIREBASE_ACCESS_TOKEN) return process.env.FIREBASE_ACCESS_TOKEN.trim();
  const configPath = path.join(os.homedir(), ".config", "configstore", "firebase-tools.json");

  const readToken = async () => {
    const raw = JSON.parse(await fs.readFile(configPath, "utf8"));
    const tokens = raw?.tokens || {};
    if (tokens.access_token && Number(tokens.expires_at || 0) > Date.now() + 5 * 60_000) {
      return tokens.access_token;
    }
    return null;
  };

  let token = await readToken().catch(() => null);
  if (!token) {
    // Trigger Firebase CLI silent OAuth refresh using stored refresh_token
    execSync(`firebase apps:list --project ${projectId}`, {stdio: "ignore", timeout: 25000});
    token = await readToken();
  }
  if (!token) {
    throw new Error("Firebase CLI access token missing or expired.");
  }
  return token;
}

function sanitizeDocId(rawId = "", fallbackIndex = 0) {
  const cleaned = String(rawId || "")
    .trim()
    .replace(/[^a-zA-Z0-9_-]+/gu, "-")
    .replace(/^-+|-+$/gu, "")
    .slice(0, 140);
  return cleaned || `yp-na-${fallbackIndex}`;
}

function toFirestoreValue(val, key = "") {
  if (val === null || val === undefined) return {nullValue: null};
  if (
    TIMESTAMP_KEYS.has(key) &&
    typeof val === "string" &&
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/u.test(val)
  ) {
    return {timestampValue: val};
  }
  if (typeof val === "boolean") return {booleanValue: val};
  if (typeof val === "number") {
    if (!Number.isFinite(val)) return {integerValue: "0"};
    return Number.isInteger(val) ? {integerValue: String(val)} : {doubleValue: val};
  }
  if (typeof val === "string") return {stringValue: val};
  if (Array.isArray(val)) {
    return {arrayValue: {values: val.map((item) => toFirestoreValue(item, ""))}};
  }
  if (typeof val === "object") {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      if (v !== undefined) fields[k] = toFirestoreValue(v, k);
    }
    return {mapValue: {fields}};
  }
  return {stringValue: String(val)};
}

function normalizeSourceRefs(refs = []) {
  if (!Array.isArray(refs)) return [];
  return refs.slice(0, 8).map((r) => ({
    sourceType: String(r?.sourceType || ""),
    sourceName: String(r?.sourceName || r?.sourceLabel || ""),
    sourceUrl: String(r?.sourceUrl || ""),
    sourceExternalId: String(r?.sourceExternalId || ""),
    observedAt: String(r?.observedAt || r?.discoveredAt || ""),
    bookPage: String(r?.bookPage || ""),
  }));
}

function buildPreparedRecords(auditedCompanies, blockedDigitsSet = new Set()) {
  const privateDocs = [];
  const publicDocs = [];
  const blockedSkipped = [];
  const seenDocIds = new Set();
  const nowIso = new Date().toISOString();

  for (let idx = 0; idx < auditedCompanies.length; idx += 1) {
    const c = auditedCompanies[idx];
    let docId = sanitizeDocId(c.recordId || c.companyId, idx + 1);
    if (seenDocIds.has(docId)) {
      let suffix = 2;
      while (seenDocIds.has(`${docId}-${suffix}`)) suffix += 1;
      docId = `${docId}-${suffix}`;
    }
    seenDocIds.add(docId);

    const allPhones = [
      c.mainPhone,
      c.tollFreePhone,
      c.oldDirectoryPhone,
      ...(c.legacyPhones || []),
    ];
    const hitBlocked = allPhones
      .map((p) => normalizeNorthAmericanPhone(p))
      .find((p) => p.validNanpa && blockedDigitsSet.has(p.digits10));

    const isFlagged = Boolean(hitBlocked);
    const isPublishableActive =
      !isFlagged &&
      (c.operationalStatus === "active_in_operation" ||
        c.operationalStatus === "active_number_updated") &&
      Boolean(c.mainPhone || c.tollFreePhone);
    const isHumanVerified = Boolean(c.verifiedByUid) && !isFlagged;

    const geo = inferCountryAndRegion(c.countryCode || "CA", c.regionCode || "");
    const categoryLabels = (c.categoryCodes || [])
      .map((code) => CATEGORY_BY_CODE.get(code)?.label || code)
      .slice(0, 12);

    const privateRecord = {
      schemaVersion: 2,
      companyId: docId,
      discoveryChannel: c.discoveryChannel || "cossd_directory",
      companyName: c.companyName,
      normalizedCompanyName: c.normalizedCompanyName,
      countryCode: geo.countryCode,
      regionCode: geo.regionCode,
      regionName: geo.regionName,
      city: c.city || "",
      postalCode: c.postalCode || "",
      streetAddress: c.streetAddress || "",
      mainPhone: c.mainPhone || "",
      publicPhone: c.mainPhone || c.tollFreePhone || "",
      tollFreePhone: c.tollFreePhone || "",
      legacyPhones: c.legacyPhones || [],
      phoneHistory: c.phoneHistory || [],
      generalEmail: c.generalEmail || "",
      publicEmail: c.publicEmail || "",
      website: c.website || "",
      powerUnits: Number(c.powerUnits || 0),
      categoryCodes: c.categoryCodes || [],
      categories: categoryLabels,
      services: c.services || [],
      basins: c.basins && c.basins.length > 0 ? c.basins : geo.defaultBasins || [],
      serviceAreas: [c.city, geo.regionName].filter(Boolean),
      certifications: c.certifications || [],
      emergency24x7: c.emergency24x7 === true,
      description: "",
      verificationStatus: isHumanVerified ?
        "verified" :
        (isFlagged ? "rejected" : "unverified"),
      operationalStatus: isFlagged ? "flagged_prohibited" : c.operationalStatus || "unverified",
      outreachStatus: "not_contacted",
      billingStatus: "unpaid",
      listingTier: isHumanVerified ? "free_verified" : "free_basic",
      nonExpiringPaid: false,
      allowUnpaidPublic: true,
      publicationStatus: isPublishableActive ? "published" : "unpublished",
      adminViewingEnabled: !isFlagged,
      isFlaggedProhibited: isFlagged,
      flagReason: hitBlocked ? `Matched blocked phone ${hitBlocked.display}` : "",
      doNotContact: isFlagged,
      sourceReferences: normalizeSourceRefs(c.sourceReferences),
      liveAuditSummary: c.liveAudit || {},
      publishedAt: isPublishableActive ? nowIso : null,
      createdAt: nowIso,
      updatedAt: nowIso,
    };
    privateRecord.adminSearchTokens = buildAdminSearchTokens(privateRecord);
    privateDocs.push(privateRecord);

    if (hitBlocked) {
      blockedSkipped.push({companyName: c.companyName, phone: hitBlocked.display});
      continue;
    }

    if (isPublicationEligible(privateRecord)) {
      const publicEntry = buildPublicEntry(privateRecord, docId, nowIso);
      if (publicEntry) {
        publicDocs.push(publicEntry);
      }
    }
  }

  return {privateDocs, publicDocs, blockedSkipped};
}

async function commitSingleChunkWithRetry(commitUrl, getTokenFn, collectionName, projectId, slice) {
  const writes = slice.map((doc) => {
    const fields = {};
    for (const [k, v] of Object.entries(doc)) {
      if (v !== undefined) fields[k] = toFirestoreValue(v, k);
    }
    return {
      update: {
        name: `projects/${projectId}/databases/(default)/documents/${collectionName}/${encodeURIComponent(doc.companyId)}`,
        fields,
      },
    };
  });
  const bodyStr = JSON.stringify({writes});

  for (let attempt = 1; attempt <= 5; attempt += 1) {
    try {
      const token = await getTokenFn();
      const res = await fetch(commitUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: bodyStr,
        signal: AbortSignal.timeout(30000),
      });
      if (res.ok) return;
      const errTxt = await res.text();
      if ((res.status === 429 || res.status >= 500 || res.status === 401) && attempt < 5) {
        await sleep(600 * attempt * attempt);
        continue;
      }
      throw new Error(`Firestore commit HTTP ${res.status} on ${collectionName}: ${errTxt.slice(0, 400)}`);
    } catch (err) {
      if (attempt === 5) throw err;
      await sleep(600 * attempt * attempt);
    }
  }
}

async function batchCommitFirestore(projectId, collectionName, docs, {batchSize = 25, concurrency = 12} = {}) {
  const commitUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  let cachedToken = await resolveAccessToken(projectId);
  let lastTokenCheckMs = Date.now();

  const getTokenFn = async () => {
    if (Date.now() - lastTokenCheckMs > 10 * 60_000) {
      cachedToken = await resolveAccessToken(projectId);
      lastTokenCheckMs = Date.now();
    }
    return cachedToken;
  };

  const chunks = [];
  for (let i = 0; i < docs.length; i += batchSize) {
    chunks.push(docs.slice(i, i + batchSize));
  }

  let committedDocs = 0;
  const startMs = Date.now();

  for (let cIdx = 0; cIdx < chunks.length; cIdx += concurrency) {
    const wave = chunks.slice(cIdx, cIdx + concurrency);
    await Promise.all(
      wave.map(async (slice) => {
        await commitSingleChunkWithRetry(commitUrl, getTokenFn, collectionName, projectId, slice);
        committedDocs += slice.length;
      }),
    );
    if ((cIdx / concurrency) % 10 === 0 || cIdx + concurrency >= chunks.length) {
      const sec = Math.max(1, Math.round((Date.now() - startMs) / 1000));
      console.log(
        `[Firestore Commit] ${collectionName} (${projectId}): ${committedDocs.toLocaleString()} / ${docs.length.toLocaleString()} docs (${Math.round(committedDocs / sec)} docs/s)`,
      );
    }
  }
}

async function verifyRemoteCount(projectId, collectionName) {
  const token = await resolveAccessToken(projectId);
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runAggregationQuery`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      structuredAggregationQuery: {
        structuredQuery: {
          from: [{collectionId: collectionName}],
        },
        aggregations: [{alias: "total", count: {}}],
      },
    }),
  });
  if (!res.ok) return null;
  const data = await res.json();
  const rawCount = data?.[0]?.result?.aggregateFields?.total?.integerValue;
  return rawCount !== undefined ? Number(rawCount) : null;
}

export async function runFirestorePublisherSync({
  apply = false,
  projectId = "pipebuyer-5c77f",
} = {}) {
  await fs.mkdir(LEDGER_DIR, {recursive: true});
  await fs.mkdir(REPORTS_DIR, {recursive: true});

  const auditedRaw = JSON.parse(
    await fs.readFile(path.join(LEDGER_DIR, "03_audited_companies.json"), "utf8"),
  );
  const {privateDocs, publicDocs, blockedSkipped} = buildPreparedRecords(
    auditedRaw.companies || [],
  );

  // Stream-friendly JSONL outputs
  const privateJsonlPath = path.join(LEDGER_DIR, "05_private_companies.jsonl");
  const publicJsonlPath = path.join(LEDGER_DIR, "05_public_entries.jsonl");
  await writeFileAtomic(privateJsonlPath, privateDocs.map((d) => JSON.stringify(d)).join("\n") + "\n");
  await writeFileAtomic(publicJsonlPath, publicDocs.map((d) => JSON.stringify(d)).join("\n") + "\n");

  const publicByCountry = {
    CA: publicDocs.filter((d) => d.countryCode === "CA").length,
    US: publicDocs.filter((d) => d.countryCode === "US").length,
  };
  const publicByRegion = {};
  const publicByCategory = {};
  for (const d of publicDocs) {
    const rk = `${d.countryCode}-${d.regionCode || "NA"}`;
    publicByRegion[rk] = (publicByRegion[rk] || 0) + 1;
    for (const c of d.categories || ["General Oilfield Services"]) {
      publicByCategory[c] = (publicByCategory[c] || 0) + 1;
    }
  }

  let verifiedRemoteCounts = null;
  if (apply) {
    console.log(
      `[Bot 5 Apply] Publishing ${privateDocs.length.toLocaleString()} private & ${publicDocs.length.toLocaleString()} public docs to Firestore project "${projectId}"...`,
    );
    await batchCommitFirestore(projectId, "yellow_pages_companies", privateDocs, {
      batchSize: 25,
      concurrency: 12,
    });
    await batchCommitFirestore(projectId, "yellow_pages_public_entries", publicDocs, {
      batchSize: 30,
      concurrency: 12,
    });
    const [remotePrivate, remotePublic] = await Promise.all([
      verifyRemoteCount(projectId, "yellow_pages_companies"),
      verifyRemoteCount(projectId, "yellow_pages_public_entries"),
    ]);
    verifiedRemoteCounts = {
      projectId,
      yellow_pages_companies: remotePrivate,
      yellow_pages_public_entries: remotePublic,
    };
    console.log(`[Bot 5 Verified Live Counts]`, JSON.stringify(verifiedRemoteCounts));
  }

  const summaryMeta = {
    generatedAt: new Date().toISOString(),
    mode: apply ? `applied:${projectId}` : "dry_run",
    verifiedRemoteCounts,
    counts: {
      privateCompanyRecordsPrepared: privateDocs.length,
      publicWebsiteEntriesEligible: publicDocs.length,
      publicByCountry,
      heldPrivateForCallOrInactive: privateDocs.length - publicDocs.length,
      blockedPhoneMatchesRejected: blockedSkipped.length,
    },
    publicByRegion,
    publicByCategory,
    files: {
      privateJsonl: "05_private_companies.jsonl",
      publicJsonl: "05_public_entries.jsonl",
    },
  };

  const bundlePath = path.join(LEDGER_DIR, "05_firestore_ready_bundle.json");
  const includeInlineArrays = privateDocs.length <= 8000;
  await writeFileAtomic(
    bundlePath,
    JSON.stringify({
      ...summaryMeta,
      inlineArraysIncluded: includeInlineArrays,
      privateDocs: includeInlineArrays ? privateDocs : privateDocs.slice(0, 500),
      publicDocs: includeInlineArrays ? publicDocs : publicDocs.slice(0, 500),
    }),
  );

  const topRegions = Object.entries(publicByRegion).sort((a, b) => b[1] - a[1]);
  const topCats = Object.entries(publicByCategory).sort((a, b) => b[1] - a[1]);

  const md = [
    "# Bot 5 — PipeBuyer Yellow Pages Full North America Sync & Publication Readiness Report",
    "",
    `- **Generated At**: \`${summaryMeta.generatedAt}\``,
    `- **Execution Mode**: \`${summaryMeta.mode}\``,
    ...(verifiedRemoteCounts
      ? [
          `- **Live Firestore Count Verified (\`${verifiedRemoteCounts.projectId}\`)**:`,
          `  - \`yellow_pages_companies\`: **${Number(verifiedRemoteCounts.yellow_pages_companies || 0).toLocaleString()}** live documents`,
          `  - \`yellow_pages_public_entries\`: **${Number(verifiedRemoteCounts.yellow_pages_public_entries || 0).toLocaleString()}** live documents`,
        ]
      : []),
    `- **Private Admin / Contact Center Records Prepared (\`05_private_companies.jsonl\`)**: **${summaryMeta.counts.privateCompanyRecordsPrepared.toLocaleString()}**`,
    `- **Public Website Search Entries Eligible (\`05_public_entries.jsonl\`)**: **${summaryMeta.counts.publicWebsiteEntriesEligible.toLocaleString()}** (Canada: **${publicByCountry.CA.toLocaleString()}**, USA: **${publicByCountry.US.toLocaleString()}**)`,
    `- **Held Private for Contact Center Call Verification or Blocked Dead Domains**: **${summaryMeta.counts.heldPrivateForCallOrInactive.toLocaleString()}**`,
    "",
    "## Public Verified Entries by Province / State",
    "",
    "| Country-Region | Verified Public Companies |",
    "| :--- | ---: |",
    ...topRegions.slice(0, 28).map(([r, cnt]) => `| \`${r}\` | ${cnt.toLocaleString()} |`),
    "",
    "## Public Verified Entries by Oil & Gas Service Category",
    "",
    "| Service Category | Verified Public Companies |",
    "| :--- | ---: |",
    ...topCats.slice(0, 24).map(([cat, cnt]) => `| ${cat} | ${cnt.toLocaleString()} |`),
    "",
  ];
  await writeFileAtomic(path.join(REPORTS_DIR, "05_sync_readiness_report.md"), md.join("\n"));

  console.log(
    `[Bot 5] Prepared ${privateDocs.length} private records & ${publicDocs.length} public verified entries (CA: ${publicByCountry.CA}, US: ${publicByCountry.US}) [${summaryMeta.mode}]`,
  );
  return summaryMeta;
}

if (process.argv[1]?.endsWith("bot5_firestore_publisher_sync.mjs")) {
  const apply = process.argv.includes("--apply");
  const projIdx = process.argv.indexOf("--project");
  const projectId = projIdx !== -1 ? process.argv[projIdx + 1] : "pipebuyer-5c77f";
  runFirestorePublisherSync({apply, projectId}).catch((err) => {
    console.error("[Bot 5 Error]", err.message);
    process.exitCode = 1;
  });
}
