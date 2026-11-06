"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {isAdministrator} = require("./administrator_authorization");
const {
  isCountryBlockedForStripePayments,
} = require("./global_payment_policy");
const {
  CATEGORY_BY_CODE,
  COUNTRY_BY_CODE,
} = require("./yellow_pages_taxonomy");
const {
  STAFF_ROLES,
  text,
} = require("./yellow_pages_policy");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");

const PRIVATE_COMPANIES = "yellow_pages_companies";
const PRIVATE_CONTACT_EVENTS = "yellow_pages_contact_events";
const OUTREACH_LOGS = "yellow_pages_outreach_logs";
const STAFF = "yellow_pages_staff";
const OUTREACH_CONFIG_COLLECTION = "platform_configuration";
const OUTREACH_CONFIG_DOC = "yellow_pages_outreach";

const DEFAULT_PROMO_CODE =
  (stripeMarketplaceConfig.promotions &&
    stripeMarketplaceConfig.promotions.pipebuyer2026 &&
    stripeMarketplaceConfig.promotions.pipebuyer2026.code) ||
  "pipebuyer2026";
const DEFAULT_FROM_EMAIL = "PipeBuyer Oilfield Directory <directory@pipebuyer.com>";
const DEFAULT_REPLY_TO_EMAIL = "support@pipebuyer.com";
const DEFAULT_SITE_ORIGIN = "https://pipebuyer.com";
const DEFAULT_COOLDOWN_DAYS = 90;
const MAX_BATCH_SIZE = 100;

const BLOCKED_EMAIL_DOMAINS = new Set([
  "example.com",
  "example.org",
  "example.net",
  "test.com",
  "domain.com",
  "yourdomain.com",
  "company.com",
  "email.com",
  "sentry.io",
  "sentry-next.wixpress.com",
  "wixpress.com",
  "squarespace.com",
  "godaddy.com",
  "cloudflare.com",
  "googleapis.com",
  "w3.org",
  "schema.org",
]);

const ASSET_EXTENSION_RE = /\.(?:png|jpe?g|gif|svg|webp|ico|css|js|woff2?|ttf|eot|pdf|mp4|zip)$/iu;
const SIMPLE_EMAIL_RE = /^[a-z0-9._%+-]+@([a-z0-9-]+\.)+[a-z]{2,24}$/iu;

let cachedSecretManagerKey = "";
let cachedSecretManagerKeyAt = 0;
const SECRET_CACHE_TTL_MS = 5 * 60 * 1000;

let cachedOutreachStats = null;
let cachedOutreachStatsAt = 0;
const STATS_CACHE_TTL_MS = 2 * 60 * 1000;

function escapeHtml(value) {
  return String(value || "")
      .replace(/&/gu, "&amp;")
      .replace(/</gu, "&lt;")
      .replace(/>/gu, "&gt;")
      .replace(/"/gu, "&quot;")
      .replace(/'/gu, "&#39;");
}

function normalizeOutreachEmail(raw) {
  const cleaned = String(raw || "")
      .trim()
      .replace(/^mailto:/iu, "")
      .split(/[?#,;\s]+/u)[0]
      .replace(/^[<("']+|[>)"'.]+$/gu, "")
      .toLowerCase();
  if (!cleaned || cleaned.length > 254) return "";
  if (!SIMPLE_EMAIL_RE.test(cleaned)) return "";
  if (ASSET_EXTENSION_RE.test(cleaned)) return "";
  const atIdx = cleaned.lastIndexOf("@");
  const local = cleaned.slice(0, atIdx);
  const domain = cleaned.slice(atIdx + 1).replace(/^www\./u, "");
  if (!local || !domain || !domain.includes(".") || BLOCKED_EMAIL_DOMAINS.has(domain)) {
    return "";
  }
  if (
    local.startsWith("noreply") ||
    local.startsWith("no-reply") ||
    local.startsWith("donotreply") ||
    local.startsWith("do-not-reply") ||
    local.startsWith("postmaster") ||
    local.startsWith("mailer-daemon")
  ) {
    return "";
  }
  return `${local}@${domain}`;
}

function resolveCompanyOutreachEmail(company) {
  if (!company || typeof company !== "object") return "";
  const candidates = [
    company.publicEmail,
    company.generalEmail,
    company.email,
    company.contactEmail,
  ];
  for (const candidate of candidates) {
    const valid = normalizeOutreachEmail(candidate);
    if (valid) return valid;
  }
  return "";
}

function timestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (typeof value.toDate === "function") return value.toDate().getTime();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : 0;
}

const INACTIVE_OPERATIONAL_STATUSES = new Set([
  "closed_inactive",
  "merged_or_acquired",
  "acquired_merged",
  "flagged_prohibited",
  "inactive",
]);

function evaluateOutreachEligibility(company, {
  nowMillis = Date.now(),
  cooldownDays = DEFAULT_COOLDOWN_DAYS,
  forceResend = false,
  includeClaimed = false,
} = {}) {
  if (!company || typeof company !== "object") {
    return {eligible: false, reason: "missing_company", email: ""};
  }
  if (company.publicationStatus && company.publicationStatus !== "published") {
    return {eligible: false, reason: "not_published", email: ""};
  }
  const opStatus = String(company.operationalStatus || "").trim().toLowerCase();
  if (opStatus && INACTIVE_OPERATIONAL_STATUSES.has(opStatus)) {
    return {eligible: false, reason: "inactive_business", email: ""};
  }
  if (company.isFlaggedProhibited === true) {
    return {eligible: false, reason: "flagged_prohibited", email: ""};
  }
  if (company.doNotContact === true || company.emailUnsubscribed === true) {
    return {eligible: false, reason: "do_not_contact", email: ""};
  }
  if (company.emailBounced === true || company.emailComplained === true) {
    return {eligible: false, reason: "bounced_or_complained", email: ""};
  }
  const countryCode = String(company.countryCode || "").trim().toUpperCase();
  if (countryCode && isCountryBlockedForStripePayments(countryCode)) {
    return {eligible: false, reason: "sanctioned_jurisdiction", email: ""};
  }
  if (!includeClaimed && (company.claimedByUid || company.billingStatus === "paid")) {
    return {eligible: false, reason: "already_claimed_or_paid", email: ""};
  }
  const email = resolveCompanyOutreachEmail(company);
  if (!email) {
    return {eligible: false, reason: "missing_valid_email", email: ""};
  }
  if (!forceResend && cooldownDays > 0) {
    const lastSentMillis = timestampMillis(company.lastOutreachEmailAt);
    if (lastSentMillis > 0 &&
        nowMillis - lastSentMillis < cooldownDays * 24 * 60 * 60 * 1000) {
      return {eligible: false, reason: "recently_emailed", email};
    }
  }
  return {eligible: true, reason: "ok", email};
}

function signUnsubscribeToken(companyId, signingSecret) {
  const cleanId = String(companyId || "").trim();
  const secret = String(signingSecret || "").trim();
  if (!cleanId || !secret) {
    throw new Error("companyId and signingSecret are required for unsubscribe token.");
  }
  return crypto
      .createHmac("sha256", secret)
      .update(`yp-unsub-v1:${cleanId}`)
      .digest("base64url");
}

function verifyUnsubscribeToken(companyId, providedToken, signingSecret) {
  const cleanId = String(companyId || "").trim();
  const token = String(providedToken || "").trim();
  const secret = String(signingSecret || "").trim();
  if (!cleanId || !token || !secret || cleanId.includes("/")) return false;
  const expected = signUnsubscribeToken(cleanId, secret);
  const expectedBuf = Buffer.from(expected, "utf8");
  const providedBuf = Buffer.from(token, "utf8");
  if (expectedBuf.length !== providedBuf.length) return false;
  return crypto.timingSafeEqual(expectedBuf, providedBuf);
}

function formatSectorSummary(company) {
  const codes = Array.isArray(company && company.categoryCodes) ?
    company.categoryCodes : [];
  const names = codes
      .map((code) => {
        const cat = CATEGORY_BY_CODE.get(String(code || "").trim());
        return cat ? cat.label : "";
      })
      .filter(Boolean);
  if (names.length > 0) return names.slice(0, 3).join(", ");
  const rawCats = Array.isArray(company && company.categories) ?
    company.categories.filter(Boolean) : [];
  if (rawCats.length > 0) return rawCats.slice(0, 3).join(", ");
  return "Oilfield Services & Supply";
}

function formatLocationLabel(company) {
  const city = String(company && company.city || "").trim();
  const region = String(company && company.regionCode || "").trim().toUpperCase();
  const country = String(company && company.countryCode || "").trim().toUpperCase();
  const countryMeta = COUNTRY_BY_CODE.get(country);
  const countryName = countryMeta ? countryMeta.name : country;
  const parts = [city, region && region !== country ? region : "", countryName].filter(Boolean);
  return parts.join(", ") || "Oilpatch Directory";
}

function buildYellowPagesOutreachEmail({
  companyId,
  company,
  promoCode = DEFAULT_PROMO_CODE,
  siteOrigin = DEFAULT_SITE_ORIGIN,
  unsubscribeUrl,
}) {
  const cleanOrigin = String(siteOrigin || DEFAULT_SITE_ORIGIN).replace(/\/+$/u, "");
  const cleanCode = String(promoCode || DEFAULT_PROMO_CODE).trim();
  const companyName = String(company && company.companyName || "Your Business").trim();
  const locationLabel = formatLocationLabel(company);
  const sectorLabel = formatSectorSummary(company);

  const claimUrl =
    `${cleanOrigin}/services/list` +
    `?claim=${encodeURIComponent(companyId)}&promo=${encodeURIComponent(cleanCode)}`;
  const dispatchUrl =
    `${cleanOrigin}/payments/dispatch?promo=${encodeURIComponent(cleanCode)}`;
  const directoryUrl = `${cleanOrigin}/yellow-pages`;

  const subject =
    `${companyName} — Claim Your PipeBuyer Directory Listing (First 6 Months Free: ${cleanCode})`;

  const safeName = escapeHtml(companyName);
  const safeLocation = escapeHtml(locationLabel);
  const safeSector = escapeHtml(sectorLabel);
  const safeCode = escapeHtml(cleanCode);
  const safeClaimUrl = escapeHtml(claimUrl);
  const safeDispatchUrl = escapeHtml(dispatchUrl);
  const safeDirectoryUrl = escapeHtml(directoryUrl);
  const safeUnsubUrl = escapeHtml(unsubscribeUrl);

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${escapeHtml(subject)}</title>
</head>
<body style="margin:0;padding:0;background-color:#f4f6f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#18212f;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#f4f6f9;padding:28px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width:600px;width:100%;background-color:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #dde3ec;">
          <tr>
            <td style="background-color:#0f1d2e;padding:24px 28px;border-bottom:3px solid #e08a1e;">
              <div style="font-size:12px;letter-spacing:1.4px;text-transform:uppercase;color:#f5b14c;font-weight:700;">PipeBuyer Oilfield Directory &amp; Dispatch</div>
              <h1 style="margin:8px 0 0 0;font-size:22px;line-height:1.3;color:#ffffff;font-weight:700;">Verify ${safeName} on PipeBuyer &amp; Get Your First 6 Months Free</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:28px;">
              <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#273449;">
                Hello <strong>${safeName}</strong> team,
              </p>
              <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#273449;">
                Your business is currently listed as an unverified oilfield directory entry in the <a href="${safeDirectoryUrl}" style="color:#0f5cc0;text-decoration:underline;">PipeBuyer Global Oilfield Yellow Pages</a> under <strong>${safeSector}</strong> (${safeLocation}).
              </p>
              <p style="margin:0 0 18px 0;font-size:15px;line-height:1.6;color:#273449;">
                We are inviting listed oil &amp; gas suppliers, contractors, and service companies to claim their profile and join the <strong>PipeBuyer App</strong> — connecting operators, buyers, and field coordinators with verified vendors, pipe &amp; equipment listings, and live Dispatch quotes.
              </p>

              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#fff9ef;border:1px dashed #e08a1e;border-radius:10px;padding:18px;margin:0 0 22px 0;">
                <tr>
                  <td>
                    <div style="font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:1px;color:#b36200;">Early Partner Launch Offer — First 6 Months 100% Free</div>
                    <div style="margin:8px 0 6px 0;font-size:20px;font-weight:800;color:#0f1d2e;font-family:Consolas,Monaco,monospace;">Promo Code: ${safeCode}</div>
                    <div style="font-size:13px;line-height:1.5;color:#415067;">
                      Use code <strong>${safeCode}</strong> on any Monthly plan for <strong>100% off your first 6 months</strong> — eligible on <strong>Verified Pro ($29/mo)</strong>, <strong>Featured Platinum ($79/mo)</strong>, and <strong>PipeBuyer Dispatch Membership ($25/mo)</strong>. Basic listing verification is always $0 free.
                    </div>
                  </td>
                </tr>
              </table>

              <table role="presentation" cellspacing="0" cellpadding="0" style="margin:0 0 18px 0;">
                <tr>
                  <td style="border-radius:8px;background-color:#e08a1e;">
                    <a href="${safeClaimUrl}" style="display:inline-block;padding:14px 24px;font-size:15px;font-weight:700;color:#0f1d2e;text-decoration:none;">Claim &amp; Verify Your Listing (6 Months Free) &rarr;</a>
                  </td>
                </tr>
              </table>

              <p style="margin:0 0 18px 0;font-size:14px;line-height:1.6;color:#415067;">
                Want to bid on live field transport, hotshot, and service requests in the app?
                <a href="${safeDispatchUrl}" style="color:#0f5cc0;font-weight:600;text-decoration:underline;">Activate PipeBuyer Dispatch Membership with 6 Months Free (${safeCode})</a>.
              </p>

              <hr style="border:none;border-top:1px solid #e5eaf1;margin:22px 0;" />
              <p style="margin:0;font-size:12px;line-height:1.6;color:#68778d;">
                <strong>Why you received this email:</strong> You are receiving this one-time business directory verification invitation because ${safeName} is published in the public oilfield directory on PipeBuyer.com.<br />
                <strong>Sender:</strong> PipeBuyer Oilfield Marketplace &amp; Directory &bull; Alberta, Canada &bull; <a href="${safeDirectoryUrl}" style="color:#68778d;">pipebuyer.com</a><br />
                Prefer no further emails from PipeBuyer? <a href="${safeUnsubUrl}" style="color:#0f5cc0;text-decoration:underline;">One-click Unsubscribe / Do Not Contact</a>.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

  const textBody = [
    `Hello ${companyName} team,`,
    "",
    `Your business is currently listed as an unverified entry in the PipeBuyer Global Oilfield Yellow Pages under ${sectorLabel} (${locationLabel}):`,
    directoryUrl,
    "",
    "We are inviting oil & gas service companies, suppliers, and contractors to claim their profile and join the PipeBuyer App — connecting operators and field buyers with verified vendors, pipe & equipment listings, and live Dispatch quotes.",
    "",
    "EARLY PARTNER OFFER — FIRST 6 MONTHS 100% FREE",
    `Promo Code: ${cleanCode}`,
    "Valid on Monthly plans for Verified Pro ($29/mo), Featured Platinum ($79/mo), and PipeBuyer Dispatch Membership ($25/mo). Basic listing verification is always $0 free.",
    "",
    "1) Claim & Verify Your Directory Listing (6 Months Free):",
    claimUrl,
    "",
    "2) Activate PipeBuyer Dispatch Membership (6 Months Free):",
    dispatchUrl,
    "",
    "---",
    "PipeBuyer Oilfield Marketplace & Directory | Alberta, Canada | https://pipebuyer.com",
    `One-click Unsubscribe / Do Not Contact: ${unsubscribeUrl}`,
  ].join("\n");

  return {
    subject,
    html,
    text: textBody,
    claimUrl,
    dispatchUrl,
    unsubscribeUrl,
    promoCode: cleanCode,
  };
}

function safeResendTagValue(value) {
  return String(value || "")
      .replace(/[^A-Za-z0-9_-]/gu, "_")
      .slice(0, 200) || "unknown";
}

function verifySvixWebhookSignature(rawBodyBuffer, headers, webhookSecret) {
  const secretRaw = String(webhookSecret || "").trim();
  if (!secretRaw) return false;
  const svixId = String(headers["svix-id"] || "").trim();
  const svixTimestamp = String(headers["svix-timestamp"] || "").trim();
  const svixSignature = String(headers["svix-signature"] || "").trim();
  if (!svixId || !svixTimestamp || !svixSignature) return false;

  const tsSeconds = Number(svixTimestamp);
  if (!Number.isFinite(tsSeconds)) return false;
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (Math.abs(nowSeconds - tsSeconds) > 300) return false;

  const base64Secret = secretRaw.startsWith("whsec_") ?
    secretRaw.slice("whsec_".length) :
    secretRaw;
  const keyBytes = Buffer.from(base64Secret, "base64");
  const signedPayload = `${svixId}.${svixTimestamp}.${rawBodyBuffer.toString("utf8")}`;
  const expectedSig = crypto
      .createHmac("sha256", keyBytes)
      .update(signedPayload)
      .digest("base64");
  const expectedBuf = Buffer.from(expectedSig, "utf8");

  const candidates = svixSignature
      .split(/\s+/u)
      .map((part) => part.trim())
      .filter((part) => part.startsWith("v1,"))
      .map((part) => part.slice(3));

  for (const candidate of candidates) {
    const candBuf = Buffer.from(candidate, "utf8");
    if (candBuf.length === expectedBuf.length &&
        crypto.timingSafeEqual(candBuf, expectedBuf)) {
      return true;
    }
  }
  return false;
}

async function fetchSecretFromGcpSecretManager(admin, secretName) {
  const now = Date.now();
  if (secretName === "RESEND_API_KEY" &&
      cachedSecretManagerKey &&
      now - cachedSecretManagerKeyAt < SECRET_CACHE_TTL_MS) {
    return cachedSecretManagerKey;
  }
  try {
    const app = admin.app();
    const credential = app && app.options && app.options.credential;
    if (!credential || typeof credential.getAccessToken !== "function") return "";
    const tokenObj = await credential.getAccessToken();
    const accessToken = tokenObj && tokenObj.access_token;
    if (!accessToken) return "";
    const projectId = String(
        process.env.GCLOUD_PROJECT ||
        process.env.GCP_PROJECT ||
        (app.options && app.options.projectId) ||
        "flutter-flow-pipe",
    ).trim();
    const url =
      `https://secretmanager.googleapis.com/v1/projects/${encodeURIComponent(projectId)}` +
      `/secrets/${encodeURIComponent(secretName)}/versions/latest:access`;
    const res = await fetch(url, {
      headers: {Authorization: `Bearer ${accessToken}`},
    });
    if (!res.ok) return "";
    const body = await res.json();
    const b64 = body && body.payload && body.payload.data;
    if (!b64) return "";
    const decoded = Buffer.from(b64, "base64").toString("utf8").trim();
    if (secretName === "RESEND_API_KEY" && decoded) {
      cachedSecretManagerKey = decoded;
      cachedSecretManagerKeyAt = now;
    }
    return decoded;
  } catch (_) {
    return "";
  }
}

async function resolveResendApiKey(admin) {
  const envKey = String(process.env.RESEND_API_KEY || "").trim();
  if (envKey) return envKey;
  return fetchSecretFromGcpSecretManager(admin, "RESEND_API_KEY");
}

async function sendViaResend({
  apiKey,
  from,
  replyTo,
  to,
  subject,
  html,
  textBody,
  unsubscribeUrl,
  tags,
  idempotencyKey,
}) {
  const headers = {
    "Authorization": `Bearer ${apiKey}`,
    "Content-Type": "application/json",
  };
  if (idempotencyKey) {
    headers["Idempotency-Key"] = String(idempotencyKey).slice(0, 250);
  }
  const emailHeaders = {};
  if (unsubscribeUrl) {
    emailHeaders["List-Unsubscribe"] = `<${unsubscribeUrl}>`;
    emailHeaders["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click";
  }
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers,
    body: JSON.stringify({
      from,
      to: [to],
      ...(replyTo ? {reply_to: replyTo} : {}),
      subject,
      html,
      text: textBody,
      ...(Object.keys(emailHeaders).length > 0 ? {headers: emailHeaders} : {}),
      ...(Array.isArray(tags) && tags.length > 0 ? {tags} : {}),
    }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const errMessage =
      (payload && (payload.message || (payload.error && payload.error.message))) ||
      `Resend HTTP ${response.status}`;
    throw new HttpsError(
        "failed-precondition",
        `Resend email delivery failed: ${errMessage}`,
    );
  }
  return {
    id: String(payload && payload.id || ""),
  };
}

function secondFactorPresent(token) {
  const value = token && token.firebase && token.firebase.sign_in_second_factor;
  return typeof value === "string" && value.trim().length > 0;
}

function createYellowPagesOutreach(admin, {stripeSecretKey, fetchImpl} = {}) {
  const db = () => admin.firestore();
  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp();
  const increment = (n) => admin.firestore.FieldValue.increment(n);

  function getSigningSecret() {
    if (stripeSecretKey && typeof stripeSecretKey.value === "function") {
      const val = String(stripeSecretKey.value() || "").trim();
      if (val) return val;
    }
    const fallback = String(
        process.env.YP_OUTREACH_SIGNING_SECRET ||
        process.env.STRIPE_SECRET_PRODUCTION ||
        "",
    ).trim();
    return fallback;
  }

  async function loadOutreachConfig() {
    let data = {};
    try {
      const snap = await db()
          .collection(OUTREACH_CONFIG_COLLECTION)
          .doc(OUTREACH_CONFIG_DOC)
          .get();
      if (snap.exists) data = snap.data() || {};
    } catch (_) {
      // Defaults used if config document does not exist yet
    }
    const siteOrigin = text(data.siteOrigin, 200) || DEFAULT_SITE_ORIGIN;
    return {
      fromEmail: text(data.fromEmail, 200) || DEFAULT_FROM_EMAIL,
      replyToEmail: text(data.replyToEmail, 200) || DEFAULT_REPLY_TO_EMAIL,
      promoCode: text(data.promoCode, 64) || DEFAULT_PROMO_CODE,
      siteOrigin: siteOrigin.replace(/\/+$/u, ""),
      cooldownDays: Number.isFinite(Number(data.cooldownDays)) ?
        Math.max(0, Math.trunc(Number(data.cooldownDays))) :
        DEFAULT_COOLDOWN_DAYS,
    };
  }

  async function requireOutreachActor(request) {
    if (!request || !request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Sign in to manage Yellow Pages outreach.");
    }
    const uid = request.auth.uid;
    const token = request.auth.token || {};
    if (token.email_verified !== true) {
      throw new HttpsError(
          "permission-denied",
          "A verified email is required for Yellow Pages outreach.",
      );
    }
    if (isAdministrator(request)) {
      return {uid, role: "administrator"};
    }
    const claimRole = text(token.yellowPagesRole, 40).toLowerCase();
    if (!STAFF_ROLES.has(claimRole) ||
        !["manager", "administrator"].includes(claimRole)) {
      throw new HttpsError(
          "permission-denied",
          "Manager or administrator access is required for email outreach.",
      );
    }
    if (!secondFactorPresent(token)) {
      throw new HttpsError(
          "permission-denied",
          "Multi-factor authentication is required for email outreach.",
      );
    }
    const roster = await db().collection(STAFF).doc(uid).get();
    const rosterData = roster.exists ? roster.data() || {} : {};
    if (!roster.exists || rosterData.active !== true || rosterData.role !== claimRole) {
      throw new HttpsError("permission-denied", "Staff roster entry is inactive.");
    }
    return {uid, role: claimRole};
  }

  function buildCompanyUnsubscribeUrl(companyId, siteOrigin, signingSecret) {
    const token = signUnsubscribeToken(companyId, signingSecret);
    return `${siteOrigin}/api/outreach/unsubscribe` +
      `?cid=${encodeURIComponent(companyId)}&t=${encodeURIComponent(token)}`;
  }

  async function getYellowPagesOutreachStats(request) {
    await requireOutreachActor(request);
    const forceRefresh = Boolean(request.data && request.data.forceRefresh);
    const now = Date.now();
    const [config, apiKey] = await Promise.all([
      loadOutreachConfig(),
      resolveResendApiKey(admin),
    ]);

    if (!forceRefresh && cachedOutreachStats &&
        now - cachedOutreachStatsAt < STATS_CACHE_TTL_MS) {
      return {
        ...cachedOutreachStats,
        resendConfigured: Boolean(apiKey),
        fromEmail: config.fromEmail,
        replyToEmail: config.replyToEmail,
        promoCode: config.promoCode,
      };
    }

    const col = db().collection(PRIVATE_COMPANIES);
    const projected = typeof col.select === "function" ?
      col.select(
          "publicationStatus",
          "operationalStatus",
          "isFlaggedProhibited",
          "doNotContact",
          "emailUnsubscribed",
          "emailBounced",
          "emailComplained",
          "countryCode",
          "claimedByUid",
          "billingStatus",
          "publicEmail",
          "generalEmail",
          "emailSource",
          "website",
          "outreachStatus",
          "outreachEmailCount",
          "lastOutreachEmailAt",
          "lastOutreachDeliveredAt",
          "lastOutreachOpenedAt",
          "lastOutreachClickedAt",
      ) :
      col;
    const snap = await projected.get();

    const stats = {
      totalActiveCompanies: 0,
      companiesWithValidEmail: 0,
      eligibleReadyToSend: 0,
      websiteEnrichedEmails: 0,
      websitesPendingEmailEnrichment: 0,
      invitedCount: 0,
      deliveredCount: 0,
      openedCount: 0,
      clickedCount: 0,
      bouncedCount: 0,
      unsubscribedCount: 0,
      claimedOrPaidCount: 0,
    };

    for (const doc of snap.docs) {
      const c = doc.data() || {};
      if (c.publicationStatus && c.publicationStatus !== "published") continue;
      const opStatus = String(c.operationalStatus || "").trim().toLowerCase();
      if (opStatus && INACTIVE_OPERATIONAL_STATUSES.has(opStatus)) continue;
      if (c.isFlaggedProhibited === true) continue;
      stats.totalActiveCompanies += 1;

      if (c.claimedByUid || c.billingStatus === "paid") {
        stats.claimedOrPaidCount += 1;
      }
      if (c.doNotContact === true || c.emailUnsubscribed === true) {
        stats.unsubscribedCount += 1;
      }
      if (c.emailBounced === true || c.emailComplained === true) {
        stats.bouncedCount += 1;
      }
      if (Number(c.outreachEmailCount || 0) > 0 || c.outreachStatus === "invited_email") {
        stats.invitedCount += 1;
      }
      if (c.lastOutreachDeliveredAt) stats.deliveredCount += 1;
      if (c.lastOutreachOpenedAt) stats.openedCount += 1;
      if (c.lastOutreachClickedAt) stats.clickedCount += 1;

      const email = resolveCompanyOutreachEmail(c);
      if (email) {
        stats.companiesWithValidEmail += 1;
        if (c.emailSource === "company_website_public") {
          stats.websiteEnrichedEmails += 1;
        }
        const check = evaluateOutreachEligibility(c, {
          nowMillis: now,
          cooldownDays: config.cooldownDays,
        });
        if (check.eligible) {
          stats.eligibleReadyToSend += 1;
        }
      } else if (String(c.website || "").trim().startsWith("http")) {
        stats.websitesPendingEmailEnrichment += 1;
      }
    }

    cachedOutreachStats = stats;
    cachedOutreachStatsAt = now;

    return {
      ...stats,
      resendConfigured: Boolean(apiKey),
      fromEmail: config.fromEmail,
      replyToEmail: config.replyToEmail,
      promoCode: config.promoCode,
    };
  }

  async function sendYellowPagesOutreachPreview(request) {
    const actor = await requireOutreachActor(request);
    const data = request.data || {};
    const dryRun = data.dryRun === true;
    const toEmail = normalizeOutreachEmail(
        data.toEmail || (request.auth.token && request.auth.token.email),
    );
    if (!dryRun && !toEmail) {
      throw new HttpsError(
          "invalid-argument",
          "Enter a valid destination email address for the test preview.",
      );
    }

    const config = await loadOutreachConfig();
    const companyId = text(data.companyId, 200) || "sample-oilfield-company";
    let company = {
      companyName: " Foothills Tubular & Oilfield Hauling Ltd.".trim(),
      city: "Grande Prairie",
      regionCode: "AB",
      countryCode: "CA",
      categoryCodes: ["octg_pipe_tubulars", "trucking_transportation"],
    };
    if (data.companyId && !String(data.companyId).includes("/")) {
      const snap = await db().collection(PRIVATE_COMPANIES).doc(companyId).get();
      if (snap.exists) company = snap.data() || company;
    }

    const signingSecret = getSigningSecret() || "preview-only-secret";
    const unsubscribeUrl = buildCompanyUnsubscribeUrl(
        companyId,
        config.siteOrigin,
        signingSecret,
    );
    const rendered = buildYellowPagesOutreachEmail({
      companyId,
      company,
      promoCode: config.promoCode,
      siteOrigin: config.siteOrigin,
      unsubscribeUrl,
    });

    if (dryRun) {
      return {
        ok: true,
        dryRun: true,
        companyId,
        toEmail: toEmail || null,
        ...rendered,
      };
    }

    const apiKey = await resolveResendApiKey(admin);
    if (!apiKey) {
      throw new HttpsError(
          "failed-precondition",
          "RESEND_API_KEY is not configured in Secret Manager yet. Add RESEND_API_KEY to send live emails.",
      );
    }

    const sendFn = fetchImpl || sendViaResend;
    const result = await sendFn({
      apiKey,
      from: config.fromEmail,
      replyTo: config.replyToEmail,
      to: toEmail,
      subject: `[TEST PREVIEW] ${rendered.subject}`,
      html: rendered.html,
      textBody: rendered.text,
      unsubscribeUrl,
      tags: [
        {name: "campaign", value: "yp_pipebuyer2026_preview"},
        {name: "company_id", value: safeResendTagValue(companyId)},
        {name: "actor_uid", value: safeResendTagValue(actor.uid)},
      ],
    });

    return {
      ok: true,
      dryRun: false,
      resendEmailId: result.id,
      toEmail,
      companyId,
      subject: rendered.subject,
      claimUrl: rendered.claimUrl,
      dispatchUrl: rendered.dispatchUrl,
      promoCode: rendered.promoCode,
    };
  }

  async function sendYellowPagesOutreachBatch(request) {
    const actor = await requireOutreachActor(request);
    const data = request.data || {};
    const dryRun = data.dryRun === true;
    const forceResend = data.forceResend === true;
    const requestedLimit = Math.max(
        1,
        Math.min(MAX_BATCH_SIZE, Math.trunc(Number(data.limit) || 25)),
    );
    const filterCountry = text(data.countryCode, 8).toUpperCase();
    const filterRegion = text(data.regionCode, 16).toUpperCase();
    const filterCategory = text(data.categoryCode, 80);
    const explicitIds = Array.isArray(data.companyIds) ?
      data.companyIds
          .map((id) => text(id, 200))
          .filter((id) => id && !id.includes("/"))
          .slice(0, MAX_BATCH_SIZE) :
      [];

    const config = await loadOutreachConfig();
    const signingSecret = getSigningSecret();
    if (!signingSecret) {
      throw new HttpsError(
          "failed-precondition",
          "Outreach unsubscribe signing secret is unavailable.",
      );
    }
    const apiKey = dryRun ? "dry_run" : await resolveResendApiKey(admin);
    if (!dryRun && !apiKey) {
      throw new HttpsError(
          "failed-precondition",
          "RESEND_API_KEY is not configured in Secret Manager yet. Add RESEND_API_KEY before launching live outreach batches.",
      );
    }

    const candidateDocs = [];
    if (explicitIds.length > 0) {
      const snaps = await Promise.all(
          explicitIds.map((id) => db().collection(PRIVATE_COMPANIES).doc(id).get()),
      );
      for (const snap of snaps) {
        if (snap.exists) candidateDocs.push(snap);
      }
    } else {
      let query = db().collection(PRIVATE_COMPANIES);
      if (filterCountry) {
        query = query.where("countryCode", "==", filterCountry);
      }
      if (filterRegion) {
        query = query.where("regionCode", "==", filterRegion);
      }
      if (filterCategory) {
        query = query.where("categoryCodes", "array-contains", filterCategory);
      }
      const scanLimit = Math.min(2500, requestedLimit * 15);
      const snap = await query.limit(scanLimit).get();
      for (const doc of snap.docs) {
        candidateDocs.push(doc);
      }
    }

    const nowMillis = Date.now();
    const eligibleTargets = [];
    const skippedReasons = {};

    for (const doc of candidateDocs) {
      if (eligibleTargets.length >= requestedLimit) break;
      const company = doc.data() || {};
      const check = evaluateOutreachEligibility(company, {
        nowMillis,
        cooldownDays: config.cooldownDays,
        forceResend: forceResend && explicitIds.length > 0,
      });
      if (!check.eligible) {
        skippedReasons[check.reason] = (skippedReasons[check.reason] || 0) + 1;
        continue;
      }
      eligibleTargets.push({
        companyId: doc.id,
        ref: doc.ref,
        company,
        email: check.email,
      });
    }

    if (dryRun) {
      return {
        ok: true,
        dryRun: true,
        promoCode: config.promoCode,
        candidateCount: eligibleTargets.length,
        skippedReasons,
        recipients: eligibleTargets.map((t) => ({
          companyId: t.companyId,
          companyName: t.company.companyName || "",
          email: t.email,
          city: t.company.city || "",
          regionCode: t.company.regionCode || "",
          countryCode: t.company.countryCode || "",
        })),
      };
    }

    const sendFn = fetchImpl || sendViaResend;
    const sent = [];
    const failed = [];
    const dayBucket = new Date(nowMillis).toISOString().slice(0, 10);

    for (let i = 0; i < eligibleTargets.length; i += 1) {
      const target = eligibleTargets[i];
      const unsubscribeUrl = buildCompanyUnsubscribeUrl(
          target.companyId,
          config.siteOrigin,
          signingSecret,
      );
      const rendered = buildYellowPagesOutreachEmail({
        companyId: target.companyId,
        company: target.company,
        promoCode: config.promoCode,
        siteOrigin: config.siteOrigin,
        unsubscribeUrl,
      });

      try {
        const res = await sendFn({
          apiKey,
          from: config.fromEmail,
          replyTo: config.replyToEmail,
          to: target.email,
          subject: rendered.subject,
          html: rendered.html,
          textBody: rendered.text,
          unsubscribeUrl,
          idempotencyKey: `yp-outreach-${target.companyId}-${config.promoCode}-${dayBucket}`,
          tags: [
            {name: "campaign", value: "yp_pipebuyer2026"},
            {name: "company_id", value: safeResendTagValue(target.companyId)},
          ],
        });

        const logId = res.id || `${target.companyId}_${nowMillis}`;
        await Promise.all([
          target.ref.set({
            outreachStatus: "invited_email",
            lastOutreachEmailAt: serverTimestamp(),
            lastOutreachEmailTo: target.email,
            lastOutreachMessageId: res.id || null,
            lastOutreachPromoCode: config.promoCode,
            outreachEmailCount: increment(1),
            updatedAt: serverTimestamp(),
          }, {merge: true}),
          db().collection(OUTREACH_LOGS).doc(logId).set({
            companyId: target.companyId,
            companyName: target.company.companyName || "",
            toEmail: target.email,
            promoCode: config.promoCode,
            resendEmailId: res.id || null,
            status: "sent",
            actorUid: actor.uid,
            sentAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
          }, {merge: true}),
          db().collection(PRIVATE_CONTACT_EVENTS).add({
            companyId: target.companyId,
            channel: "email_outreach",
            outcome: "invited_pipebuyer2026",
            notes: `Sent PipeBuyer 6-months-free (${config.promoCode}) invitation to ${target.email}.`,
            actorUid: actor.uid,
            resendEmailId: res.id || null,
            createdAt: serverTimestamp(),
          }),
        ]);

        sent.push({
          companyId: target.companyId,
          companyName: target.company.companyName || "",
          email: target.email,
          resendEmailId: res.id || "",
        });
      } catch (err) {
        failed.push({
          companyId: target.companyId,
          email: target.email,
          error: err && err.message ? err.message : "send_failed",
        });
      }

      if (i + 1 < eligibleTargets.length) {
        await new Promise((resolve) => setTimeout(resolve, 220));
      }
    }

    cachedOutreachStats = null;
    cachedOutreachStatsAt = 0;

    return {
      ok: true,
      dryRun: false,
      promoCode: config.promoCode,
      sentCount: sent.length,
      failedCount: failed.length,
      skippedReasons,
      sent,
      failed,
    };
  }

  async function handleOutreachUnsubscribeHttp(req, res) {
    if (req.method !== "GET" && req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    const cid = text(
        (req.query && req.query.cid) || (req.body && req.body.cid),
        200,
    );
    const token = text(
        (req.query && req.query.t) || (req.body && req.body.t),
        256,
    );
    const signingSecret = getSigningSecret();
    if (!cid || !token || !verifyUnsubscribeToken(cid, token, signingSecret)) {
      res.status(400).send("Invalid or expired unsubscribe link.");
      return;
    }

    const companyRef = db().collection(PRIVATE_COMPANIES).doc(cid);
    const snap = await companyRef.get();
    const companyName = snap.exists ?
      String((snap.data() || {}).companyName || "Your business") :
      "Your business";

    if (snap.exists) {
      await Promise.all([
        companyRef.set({
          doNotContact: true,
          emailUnsubscribed: true,
          emailUnsubscribedAt: serverTimestamp(),
          outreachStatus: "unsubscribed",
          updatedAt: serverTimestamp(),
        }, {merge: true}),
        db().collection(PRIVATE_CONTACT_EVENTS).add({
          companyId: cid,
          channel: "email_outreach",
          outcome: "unsubscribed",
          notes: "Recipient clicked one-click email unsubscribe link.",
          actorUid: "recipient_self_service",
          createdAt: serverTimestamp(),
        }),
      ]);
      cachedOutreachStats = null;
      cachedOutreachStatsAt = 0;
    }

    if (req.method === "POST") {
      res.status(200).json({unsubscribed: true, companyId: cid});
      return;
    }

    res.status(200).type("html").send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Unsubscribed — PipeBuyer Directory</title>
</head>
<body style="margin:0;padding:40px 16px;background:#f4f6f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#18212f;">
  <div style="max-width:480px;margin:0 auto;background:#fff;border-radius:12px;padding:28px;border:1px solid #dde3ec;text-align:center;">
    <h1 style="margin:0 0 12px 0;font-size:20px;color:#0f1d2e;">You Have Been Unsubscribed</h1>
    <p style="margin:0 0 18px 0;font-size:15px;line-height:1.5;color:#415067;">
      <strong>${escapeHtml(companyName)}</strong> has been marked as <strong>Do Not Contact</strong> for PipeBuyer directory outreach emails.
    </p>
    <a href="https://pipebuyer.com/yellow-pages" style="color:#0f5cc0;font-size:14px;text-decoration:underline;">Return to PipeBuyer.com</a>
  </div>
</body>
</html>`);
  }

  async function handleResendWebhookHttp(req, res) {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    const webhookSecret =
      String(process.env.RESEND_WEBHOOK_SECRET || "").trim() ||
      await fetchSecretFromGcpSecretManager(admin, "RESEND_WEBHOOK_SECRET");
    if (webhookSecret) {
      const rawBuf = Buffer.isBuffer(req.rawBody) ?
        req.rawBody :
        Buffer.from(JSON.stringify(req.body || {}), "utf8");
      if (!verifySvixWebhookSignature(rawBuf, req.headers || {}, webhookSecret)) {
        res.status(401).json({error: "Invalid webhook signature"});
        return;
      }
    }

    const event = req.body && typeof req.body === "object" ? req.body : {};
    const eventType = String(event.type || "").trim();
    const payload = event.data && typeof event.data === "object" ? event.data : {};
    const emailId = text(payload.email_id || payload.id, 200);

    let companyId = "";
    if (Array.isArray(payload.tags)) {
      const tag = payload.tags.find((t) => t && t.name === "company_id");
      if (tag && tag.value) companyId = text(tag.value, 200);
    } else if (payload.tags && typeof payload.tags === "object" && payload.tags.company_id) {
      companyId = text(payload.tags.company_id, 200);
    }

    if (emailId && !emailId.includes("/")) {
      const logRef = db().collection(OUTREACH_LOGS).doc(emailId);
      const logSnap = await logRef.get();
      if (logSnap.exists && !companyId) {
        companyId = text((logSnap.data() || {}).companyId, 200);
      }
      await logRef.set({
        lastEventType: eventType || "unknown",
        updatedAt: serverTimestamp(),
      }, {merge: true});
    }

    if (companyId && !companyId.includes("/")) {
      const compRef = db().collection(PRIVATE_COMPANIES).doc(companyId);
      const compSnap = await compRef.get();
      if (compSnap.exists) {
        const patch = {updatedAt: serverTimestamp()};
        if (eventType === "email.delivered") {
          patch.lastOutreachDeliveredAt = serverTimestamp();
        } else if (eventType === "email.opened") {
          patch.lastOutreachOpenedAt = serverTimestamp();
        } else if (eventType === "email.clicked") {
          patch.lastOutreachClickedAt = serverTimestamp();
        } else if (eventType === "email.bounced") {
          patch.emailBounced = true;
          patch.outreachStatus = "email_bounced";
        } else if (eventType === "email.complained") {
          patch.emailComplained = true;
          patch.doNotContact = true;
          patch.outreachStatus = "complained_do_not_contact";
        }
        await compRef.set(patch, {merge: true});
        cachedOutreachStats = null;
        cachedOutreachStatsAt = 0;
      }
    }

    res.status(200).json({received: true});
  }

  return {
    getYellowPagesOutreachStats,
    handleOutreachUnsubscribeHttp,
    handleResendWebhookHttp,
    sendYellowPagesOutreachBatch,
    sendYellowPagesOutreachPreview,
  };
}

module.exports = {
  DEFAULT_PROMO_CODE,
  buildYellowPagesOutreachEmail,
  createYellowPagesOutreach,
  evaluateOutreachEligibility,
  normalizeOutreachEmail,
  resolveCompanyOutreachEmail,
  signUnsubscribeToken,
  verifySvixWebhookSignature,
  verifyUnsubscribeToken,
};
