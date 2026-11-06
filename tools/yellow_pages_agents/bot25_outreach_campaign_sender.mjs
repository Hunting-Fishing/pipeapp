#!/usr/bin/env node
/**
 * Bot 25 — PipeBuyer Yellow Pages `pipebuyer2026` (First 6 Months Free) Email Campaign Sender
 *
 * Sends compliant B2B directory claim & PipeBuyer App invitations via Resend (`pipebuyer.com`)
 * with 1-click HMAC-signed unsubscribe headers (`List-Unsubscribe` + `List-Unsubscribe-Post`)
 * and promo code `pipebuyer2026` (100% off first 6 months on Dispatch, Verified Pro, and
 * Featured Platinum monthly plans).
 *
 * Modes:
 *   --dry-run                Preview eligible count & sample recipients (default)
 *   --test-to <email>        Send a single live test preview email to <email>
 *   --apply --batch <N>      Send a live throttled batch of <N> invitations and log to Firestore
 *   --country <CC>           Optional ISO-2 country filter (e.g., CA, US)
 *   --region <RC>            Optional region/province/state filter (e.g., AB, TX)
 *   --sector <code>          Optional 30-sector category code filter
 */
import {execSync} from "node:child_process";
import {createRequire} from "node:module";
import {resolveAccessToken, toFirestoreValue} from "./global_shared_utils.mjs";

const require = createRequire(import.meta.url);
const {
  DEFAULT_PROMO_CODE,
  buildYellowPagesOutreachEmail,
  evaluateOutreachEligibility,
  normalizeOutreachEmail,
  signUnsubscribeToken,
} = require("../../firebase/functions/yellow_pages_outreach.js");

const args = process.argv.slice(2);
const argVal = (k, d) => {
  const i = args.indexOf(k);
  return i !== -1 && args[i + 1] ? args[i + 1] : d;
};
const APPLY = args.includes("--apply");
const TEST_TO = normalizeOutreachEmail(argVal("--test-to", ""));
const BATCH_SIZE = Math.max(1, Math.min(500, Number(argVal("--batch", "50")) || 50));
const COUNTRY_FILTER = String(argVal("--country", "")).trim().toUpperCase();
const REGION_FILTER = String(argVal("--region", "")).trim().toUpperCase();
const SECTOR_FILTER = String(argVal("--sector", "")).trim();
const PROJECT_ID = argVal("--project", "flutter-flow-pipe");
const FROM_EMAIL = argVal("--from", "PipeBuyer Oilfield Directory <directory@pipebuyer.com>");
const REPLY_TO = argVal("--reply-to", "support@pipebuyer.com");
const SITE_ORIGIN = "https://pipebuyer.com";

const strVal = (f, k) => f?.[k]?.stringValue || "";
const intVal = (f, k) => Number(f?.[k]?.integerValue || 0);
const boolVal = (f, k, d = false) => (f?.[k]?.booleanValue !== undefined ? f[k].booleanValue : d);
const arrStr = (f, k) => (f?.[k]?.arrayValue?.values || []).map((v) => v.stringValue || "").filter(Boolean);

function readGcloudSecret(secretName) {
  const fromEnv = String(process.env[secretName] || "").trim();
  if (fromEnv) return fromEnv;
  try {
    return execSync(
      `gcloud secrets versions access latest --secret=${secretName} --project=${PROJECT_ID}`,
      {encoding: "utf8", stdio: ["ignore", "pipe", "pipe"]},
    ).trim();
  } catch (_) {
    return "";
  }
}

async function sendResendEmail({apiKey, to, subject, html, text, unsubscribeUrl, idempotencyKey, tags}) {
  const headers = {
    Authorization: `Bearer ${apiKey}`,
    "Content-Type": "application/json",
  };
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers,
    body: JSON.stringify({
      from: FROM_EMAIL,
      to: [to],
      reply_to: REPLY_TO,
      subject,
      html,
      text,
      headers: {
        "List-Unsubscribe": `<${unsubscribeUrl}>`,
        "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
      },
      tags,
    }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(body?.message || body?.error?.message || `Resend HTTP ${res.status}`);
  }
  return String(body.id || "");
}

async function loadCompanies() {
  const token = await resolveAccessToken();
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`;
  const out = [];
  let last = null;
  while (true) {
    const sq = {
      from: [{collectionId: "yellow_pages_companies"}],
      orderBy: [{field: {fieldPath: "__name__"}, direction: "ASCENDING"}],
      limit: 3000,
    };
    if (last) sq.startAt = {values: [{referenceValue: last}], before: false};
    const res = await fetch(url, {
      method: "POST",
      headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
      body: JSON.stringify({structuredQuery: sq}),
      signal: AbortSignal.timeout(60000),
    });
    if (!res.ok) throw new Error(`runQuery HTTP ${res.status}`);
    const docs = (await res.json()).filter((r) => r.document).map((r) => r.document);
    if (!docs.length) break;
    out.push(...docs);
    last = docs[docs.length - 1].name;
    if (docs.length < 3000) break;
  }
  return out;
}

async function recordOutreachSentInFirestore({companyDocName, companyId, companyName, email, resendId, prevCount}) {
  const token = await resolveAccessToken();
  const nowIso = new Date().toISOString();
  const logId = resendId || `${companyId}_${Date.now()}`;
  const writes = [
    {
      update: {
        name: companyDocName,
        fields: {
          outreachStatus: toFirestoreValue("invited_email"),
          lastOutreachEmailAt: toFirestoreValue(nowIso),
          lastOutreachEmailTo: toFirestoreValue(email),
          lastOutreachMessageId: toFirestoreValue(resendId),
          lastOutreachPromoCode: toFirestoreValue(DEFAULT_PROMO_CODE),
          outreachEmailCount: toFirestoreValue(prevCount + 1),
          updatedAt: toFirestoreValue(nowIso),
        },
      },
      updateMask: {
        fieldPaths: [
          "outreachStatus",
          "lastOutreachEmailAt",
          "lastOutreachEmailTo",
          "lastOutreachMessageId",
          "lastOutreachPromoCode",
          "outreachEmailCount",
          "updatedAt",
        ],
      },
    },
    {
      update: {
        name: `projects/${PROJECT_ID}/databases/(default)/documents/yellow_pages_outreach_logs/${encodeURIComponent(logId)}`,
        fields: {
          companyId: toFirestoreValue(companyId),
          companyName: toFirestoreValue(companyName),
          toEmail: toFirestoreValue(email),
          promoCode: toFirestoreValue(DEFAULT_PROMO_CODE),
          resendEmailId: toFirestoreValue(resendId),
          status: toFirestoreValue("sent"),
          actorUid: toFirestoreValue("cli_bot25"),
          sentAt: toFirestoreValue(nowIso),
          updatedAt: toFirestoreValue(nowIso),
        },
      },
    },
  ];
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:commit`,
    {
      method: "POST",
      headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
      body: JSON.stringify({writes}),
      signal: AbortSignal.timeout(30000),
    },
  );
  if (!res.ok) throw new Error(`Firestore log commit failed: HTTP ${res.status}`);
}

async function main() {
  const signingSecret = readGcloudSecret("STRIPE_SECRET_PRODUCTION");
  if (!signingSecret) {
    throw new Error("Could not load STRIPE_SECRET_PRODUCTION from Secret Manager for HMAC unsubscribe signing.");
  }

  if (TEST_TO) {
    const apiKey = readGcloudSecret("RESEND_API_KEY");
    if (!apiKey) {
      throw new Error("RESEND_API_KEY is not set in Secret Manager or environment yet.");
    }
    const sampleId = "sample-oilfield-company";
    const token = signUnsubscribeToken(sampleId, signingSecret);
    const unsubscribeUrl = `${SITE_ORIGIN}/api/outreach/unsubscribe?cid=${encodeURIComponent(sampleId)}&t=${encodeURIComponent(token)}`;
    const rendered = buildYellowPagesOutreachEmail({
      companyId: sampleId,
      company: {
        companyName: "Foothills Tubular & Oilfield Hauling Ltd.",
        city: "Grande Prairie",
        regionCode: "AB",
        countryCode: "CA",
        categoryCodes: ["octg_pipe_tubulars", "trucking_transportation"],
      },
      promoCode: DEFAULT_PROMO_CODE,
      siteOrigin: SITE_ORIGIN,
      unsubscribeUrl,
    });
    const resendId = await sendResendEmail({
      apiKey,
      to: TEST_TO,
      subject: `[TEST PREVIEW] ${rendered.subject}`,
      html: rendered.html,
      text: rendered.text,
      unsubscribeUrl,
      tags: [{name: "campaign", value: "yp_pipebuyer2026_cli_test"}],
    });
    console.log(JSON.stringify({ok: true, mode: "test_preview", to: TEST_TO, resendId, claimUrl: rendered.claimUrl}, null, 2));
    return;
  }

  const docs = await loadCompanies();
  const eligible = [];
  const skippedReasons = {};

  for (const doc of docs) {
    const id = doc.name.split("/").pop();
    const f = doc.fields || {};
    const cc = strVal(f, "countryCode").toUpperCase();
    const rc = strVal(f, "regionCode").toUpperCase();
    const cats = arrStr(f, "categoryCodes");
    if (COUNTRY_FILTER && cc !== COUNTRY_FILTER) continue;
    if (REGION_FILTER && rc !== REGION_FILTER) continue;
    if (SECTOR_FILTER && !cats.includes(SECTOR_FILTER)) continue;

    const companyObj = {
      companyName: strVal(f, "companyName"),
      publicationStatus: strVal(f, "publicationStatus") || "published",
      operationalStatus: strVal(f, "operationalStatus") || "active",
      isFlaggedProhibited: boolVal(f, "isFlaggedProhibited"),
      doNotContact: boolVal(f, "doNotContact"),
      emailUnsubscribed: boolVal(f, "emailUnsubscribed"),
      emailBounced: boolVal(f, "emailBounced"),
      emailComplained: boolVal(f, "emailComplained"),
      countryCode: cc,
      regionCode: rc,
      city: strVal(f, "city"),
      claimedByUid: strVal(f, "claimedByUid"),
      billingStatus: strVal(f, "billingStatus"),
      publicEmail: strVal(f, "publicEmail"),
      generalEmail: strVal(f, "generalEmail"),
      lastOutreachEmailAt: f.lastOutreachEmailAt?.timestampValue || strVal(f, "lastOutreachEmailAt"),
      categoryCodes: cats,
      categories: arrStr(f, "categories"),
    };

    const check = evaluateOutreachEligibility(companyObj);
    if (!check.eligible) {
      skippedReasons[check.reason] = (skippedReasons[check.reason] || 0) + 1;
      continue;
    }
    eligible.push({
      id,
      docName: doc.name,
      company: companyObj,
      email: check.email,
      prevCount: intVal(f, "outreachEmailCount"),
    });
  }

  if (!APPLY) {
    console.log(JSON.stringify({
      ok: true,
      mode: "dry_run",
      promoCode: DEFAULT_PROMO_CODE,
      totalEligibleInFilter: eligible.length,
      batchPreviewCount: Math.min(BATCH_SIZE, eligible.length),
      skippedReasons,
      sampleBatch: eligible.slice(0, 15).map((item) => ({
        companyId: item.id,
        companyName: item.company.companyName,
        email: item.email,
        location: `${item.company.city}, ${item.company.regionCode || item.company.countryCode}`,
        claimUrl: `${SITE_ORIGIN}/services/list?claim=${encodeURIComponent(item.id)}&promo=${DEFAULT_PROMO_CODE}`,
      })),
    }, null, 2));
    return;
  }

  const apiKey = readGcloudSecret("RESEND_API_KEY");
  if (!apiKey) {
    throw new Error("RESEND_API_KEY is not configured in Secret Manager yet. Add RESEND_API_KEY first.");
  }

  const batch = eligible.slice(0, BATCH_SIZE);
  const dayBucket = new Date().toISOString().slice(0, 10);
  let sentCount = 0;
  const failures = [];

  for (let i = 0; i < batch.length; i += 1) {
    const item = batch[i];
    const token = signUnsubscribeToken(item.id, signingSecret);
    const unsubscribeUrl = `${SITE_ORIGIN}/api/outreach/unsubscribe?cid=${encodeURIComponent(item.id)}&t=${encodeURIComponent(token)}`;
    const rendered = buildYellowPagesOutreachEmail({
      companyId: item.id,
      company: item.company,
      promoCode: DEFAULT_PROMO_CODE,
      siteOrigin: SITE_ORIGIN,
      unsubscribeUrl,
    });
    try {
      const resendId = await sendResendEmail({
        apiKey,
        to: item.email,
        subject: rendered.subject,
        html: rendered.html,
        text: rendered.text,
        unsubscribeUrl,
        idempotencyKey: `yp-outreach-${item.id}-${DEFAULT_PROMO_CODE}-${dayBucket}`,
        tags: [
          {name: "campaign", value: "yp_pipebuyer2026"},
          {name: "company_id", value: item.id.replace(/[^A-Za-z0-9_-]/gu, "_").slice(0, 200)},
        ],
      });
      await recordOutreachSentInFirestore({
        companyDocName: item.docName,
        companyId: item.id,
        companyName: item.company.companyName,
        email: item.email,
        resendId,
        prevCount: item.prevCount,
      });
      sentCount += 1;
    } catch (err) {
      failures.push({companyId: item.id, email: item.email, error: err.message});
    }
    if (i + 1 < batch.length) {
      await new Promise((r) => setTimeout(r, 220));
    }
  }

  console.log(JSON.stringify({
    ok: true,
    mode: "live_batch",
    promoCode: DEFAULT_PROMO_CODE,
    sentCount,
    failedCount: failures.length,
    remainingEligible: Math.max(0, eligible.length - sentCount),
    failures: failures.slice(0, 10),
  }, null, 2));
}

main().catch((err) => {
  console.error("[bot25] Error:", err.message);
  process.exit(1);
});
