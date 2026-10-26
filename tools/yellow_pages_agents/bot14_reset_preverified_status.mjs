#!/usr/bin/env node
/**
 * Bot 14 — Reset Pre-Verified Crawler Status Across Yellow Pages Collections
 *
 * Ensures ZERO crawled/seeded directory records are pre-marked as verified while
 * keeping 100% of active directory listings live and published on `pipebuyer.com`:
 *   1. Scans `yellow_pages_companies` and identifies records without human/admin
 *      verification (`!verifiedByUid && !claimedByUid && billingStatus !== "paid"`).
 *      Updates `verificationStatus -> "unverified"` and `listingTier -> "free_basic"`
 *      using field-masked commits.
 *   2. Scans `yellow_pages_public_entries` and updates unverified unpaid records to
 *      `verified -> false` and `effectiveTier -> "free_basic"` while preserving all
 *      search tokens, phone numbers, and published status.
 *
 * IMPORTANT: Deploy updated Cloud Functions (`isPublicEntryCurrent` accepting
 * `effectiveTier === "free_basic"` and `verified === false`) BEFORE running with `--apply`.
 */

import {resolveAccessToken} from "./global_shared_utils.mjs";

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const projIdx = args.indexOf("--project");
const PROJECT_ID =
  projIdx !== -1 && args[projIdx + 1] ? args[projIdx + 1] : "flutter-flow-pipe";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function strVal(fields, k) {
  return fields?.[k]?.stringValue || "";
}

function boolVal(fields, k, defVal = false) {
  return fields?.[k]?.booleanValue !== undefined ? fields[k].booleanValue : defVal;
}

async function scanCollection(projectId, collectionId, fieldNames) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`;
  const all = [];
  let lastDocName = null;

  while (true) {
    const token = await resolveAccessToken(projectId);
    const structuredQuery = {
      from: [{collectionId}],
      select: {
        fields: fieldNames.map((fieldPath) => ({fieldPath})),
      },
      orderBy: [{field: {fieldPath: "__name__"}, direction: "ASCENDING"}],
      limit: 2500,
    };
    if (lastDocName) {
      structuredQuery.startAt = {
        values: [{referenceValue: lastDocName}],
        before: false,
      };
    }

    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({structuredQuery}),
      signal: AbortSignal.timeout(30000),
    });
    if (!res.ok) {
      throw new Error(
        `Firestore runQuery (${collectionId}) HTTP ${res.status}: ${await res.text()}`,
      );
    }
    const rows = await res.json();
    const docs = rows.filter((r) => r.document).map((r) => r.document);
    if (docs.length === 0) break;
    all.push(...docs);
    lastDocName = docs[docs.length - 1].name;
    console.log(`[bot14] Scanned ${all.length} docs in ${collectionId}...`);
    if (docs.length < 2500) break;
  }
  return all;
}

async function commitMaskedWrites(projectId, writes, label, {batchSize = 200, concurrency = 10} = {}) {
  if (writes.length === 0) return;
  const commitUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
  const chunks = [];
  for (let i = 0; i < writes.length; i += batchSize) {
    chunks.push(writes.slice(i, i + batchSize));
  }

  let done = 0;
  for (let i = 0; i < chunks.length; i += concurrency) {
    const wave = chunks.slice(i, i + concurrency);
    await Promise.all(
      wave.map(async (slice) => {
        const bodyStr = JSON.stringify({writes: slice});
        for (let attempt = 1; attempt <= 5; attempt += 1) {
          try {
            const token = await resolveAccessToken(projectId);
            const res = await fetch(commitUrl, {
              method: "POST",
              headers: {
                Authorization: `Bearer ${token}`,
                "Content-Type": "application/json",
              },
              body: bodyStr,
              signal: AbortSignal.timeout(30000),
            });
            if (res.ok) break;
            const errTxt = await res.text();
            if ((res.status === 429 || res.status >= 500 || res.status === 401) && attempt < 5) {
              await sleep(500 * attempt * attempt);
              continue;
            }
            throw new Error(`Commit HTTP ${res.status} (${label}): ${errTxt.slice(0, 300)}`);
          } catch (err) {
            if (attempt === 5) throw err;
            await sleep(500 * attempt * attempt);
          }
        }
        done += slice.length;
      }),
    );
    console.log(`[bot14] Committed ${done}/${writes.length} ${label} updates...`);
  }
}

async function countMatching(projectId, collectionId, whereFilter = null) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runAggregationQuery`;
  const token = await resolveAccessToken(projectId);
  const structuredQuery = {
    from: [{collectionId}],
    ...(whereFilter ? {where: whereFilter} : {}),
  };
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      structuredAggregationQuery: {
        structuredQuery,
        aggregations: [{alias: "cnt", count: {}}],
      },
    }),
    signal: AbortSignal.timeout(30000),
  });
  if (!res.ok) {
    throw new Error(`Aggregation HTTP ${res.status}: ${await res.text()}`);
  }
  const rows = await res.json();
  const val = rows?.[0]?.result?.aggregateFields?.cnt?.integerValue;
  return Number(val || 0);
}

async function main() {
  console.log(
    `[bot14] Auditing pre-verified crawler records on project=${PROJECT_ID} (apply=${APPLY})...`,
  );

  const privateDocs = await scanCollection(PROJECT_ID, "yellow_pages_companies", [
    "verificationStatus",
    "listingTier",
    "billingStatus",
    "verifiedByUid",
    "claimedByUid",
  ]);

  const humanOrPaidVerifiedIds = new Set();
  const privateWrites = [];

  for (const doc of privateDocs) {
    const docId = decodeURIComponent(doc.name.split("/").pop());
    const f = doc.fields || {};
    const verifiedByUid = strVal(f, "verifiedByUid");
    const claimedByUid = strVal(f, "claimedByUid");
    const billingStatus = strVal(f, "billingStatus");
    const verificationStatus = strVal(f, "verificationStatus");
    const listingTier = strVal(f, "listingTier");

    if (verifiedByUid || claimedByUid || billingStatus === "paid") {
      if (verificationStatus === "verified" || billingStatus === "paid") {
        humanOrPaidVerifiedIds.add(docId);
      }
      continue;
    }

    if (verificationStatus === "verified" || listingTier === "free_verified") {
      privateWrites.push({
        update: {
          name: doc.name,
          fields: {
            verificationStatus: {stringValue: "unverified"},
            listingTier: {stringValue: "free_basic"},
          },
        },
        updateMask: {
          fieldPaths: ["verificationStatus", "listingTier"],
        },
        currentDocument: {exists: true},
      });
    }
  }

  const publicDocs = await scanCollection(PROJECT_ID, "yellow_pages_public_entries", [
    "verified",
    "effectiveTier",
    "isPaidTier",
  ]);

  const publicWrites = [];
  for (const doc of publicDocs) {
    const docId = decodeURIComponent(doc.name.split("/").pop());
    const f = doc.fields || {};
    const isPaidTier = boolVal(f, "isPaidTier", false);
    const verified = boolVal(f, "verified", false);
    const effectiveTier = strVal(f, "effectiveTier");

    if (isPaidTier || humanOrPaidVerifiedIds.has(docId)) {
      continue;
    }

    if (verified === true || effectiveTier === "free_verified") {
      publicWrites.push({
        update: {
          name: doc.name,
          fields: {
            verified: {booleanValue: false},
            effectiveTier: {stringValue: "free_basic"},
          },
        },
        updateMask: {
          fieldPaths: ["verified", "effectiveTier"],
        },
        currentDocument: {exists: true},
      });
    }
  }

  console.log(`[bot14] Audit Summary:`);
  console.log(`  • Total yellow_pages_companies: ${privateDocs.length}`);
  console.log(`  • Genuinely Human/Paid Verified Companies Preserved: ${humanOrPaidVerifiedIds.size}`);
  console.log(`  • Pre-verified Private Companies to Reset -> unverified: ${privateWrites.length}`);
  console.log(`  • Total yellow_pages_public_entries (All Live): ${publicDocs.length}`);
  console.log(`  • Pre-verified Public Entries to Reset -> verified=false (free_basic): ${publicWrites.length}`);

  if (!APPLY) {
    console.log(`[bot14] Dry run complete. Pass --apply to execute updates.`);
    return;
  }

  await commitMaskedWrites(PROJECT_ID, publicWrites, "yellow_pages_public_entries");
  await commitMaskedWrites(PROJECT_ID, privateWrites, "yellow_pages_companies");

  const [totalPublic, verifiedPublic, verifiedPrivate] = await Promise.all([
    countMatching(PROJECT_ID, "yellow_pages_public_entries"),
    countMatching(PROJECT_ID, "yellow_pages_public_entries", {
      fieldFilter: {
        field: {fieldPath: "verified"},
        op: "EQUAL",
        value: {booleanValue: true},
      },
    }),
    countMatching(PROJECT_ID, "yellow_pages_companies", {
      fieldFilter: {
        field: {fieldPath: "verificationStatus"},
        op: "EQUAL",
        value: {stringValue: "verified"},
      },
    }),
  ]);

  console.log(`[bot14] Post-Apply Live Verification (${PROJECT_ID}):`);
  console.log(`  • Live Published Entries (yellow_pages_public_entries): ${totalPublic}`);
  console.log(`  • Public Entries Marked verified==true: ${verifiedPublic}`);
  console.log(`  • Private Companies Marked verificationStatus=="verified": ${verifiedPrivate}`);
}

main().catch((err) => {
  console.error("[bot14] Fatal error:", err);
  process.exit(1);
});
