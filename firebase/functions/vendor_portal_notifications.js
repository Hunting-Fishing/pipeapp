"use strict";

const {PRIMARY_ADMIN_MANAGER_EMAIL} = require("./administrator_role_commands");
const {
  SHOP_CATEGORY_BY_CODE,
  VENDOR_APPLICATION_EXTRA_CATEGORIES,
  cleanText,
} = require("./shop_store_policy");

const DEFAULT_FROM_EMAIL =
  "Pipe Buyer Partnerships <directory@pipebuyer.com>";
const DEFAULT_REPLY_TO_EMAIL = "support@pipebuyer.com";
const DEFAULT_SITE_ORIGIN = "https://pipebuyer.com";

const EXTRA_CATEGORY_BY_CODE = new Map(
    VENDOR_APPLICATION_EXTRA_CATEGORIES.map((item) => [item.code, item]),
);

const TRACK_LABELS = Object.freeze({
  oem_heavy_equipment_dealer: "Heavy Equipment OEM / Authorized Dealer",
  brand_manufacturer: "Tool, Welding & Industrial Brand / OEM",
  industrial_distributor: "Authorized Industrial & Oilfield Distributor",
  verified_business_vendor: "Verified Business Vendor Storefront",
  affiliate_network_partner: "Catalog Feed / Affiliate Network Partner",
});

const AUTH_LEVEL_LABELS = Object.freeze({
  oem_direct: "Direct Manufacturer / Brand Owner",
  authorized_dealer: "Factory-Authorized Dealer / Franchise",
  national_distributor: "Regional / National Authorized Distributor",
  reseller_affiliate: "Verified Reseller / Affiliate Partner",
});

const PLACEMENT_LABELS = Object.freeze({
  shop_storefront: "Pipe Buyer Storefront Catalog",
  heavy_equipment_listings: "Heavy Equipment, Tractors & Dealer Listings",
  brand_spotlight_deals: "Featured Brand Spotlight & Fleet Deals",
  contextual_recommendations: "Contextual In-Listing Gear Placement",
});

const INTEGRATION_LABELS = Object.freeze({
  direct_dealer_link: "Direct Product / Dealer Quote Links",
  csv_spreadsheet: "Spreadsheet / CSV Catalog Import",
  api_xml_feed: "Automated XML / JSON / Dealer Feed",
  manual_curated: "Curated Featured Lineup with Pipe Buyer Team",
  affiliate_network: "Affiliate Network Feed (Impact / CJ / Amazon / eBay)",
});

const DECISION_LABELS = Object.freeze({
  pending: "Pending Review",
  under_review: "Under Admin Review",
  approved: "Approved Partner",
  waitlisted: "Waitlisted",
  declined: "Not Approved at This Time",
});

let cachedResendSecret = "";
let cachedResendSecretAt = 0;
const SECRET_CACHE_TTL_MS = 5 * 60 * 1000;

function escapeHtml(value) {
  return String(value == null ? "" : value)
      .replace(/&/gu, "&amp;")
      .replace(/</gu, "&lt;")
      .replace(/>/gu, "&gt;")
      .replace(/"/gu, "&quot;")
      .replace(/'/gu, "&#39;");
}

function isDeliverableExternalEmail(rawEmail) {
  const email = cleanText(rawEmail, 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) return false;
  const domain = email.slice(email.lastIndexOf("@") + 1);
  if (
    domain === "example.com" ||
    domain === "example.org" ||
    domain === "example.net" ||
    domain.endsWith(".example.com") ||
    domain.endsWith(".example.org") ||
    domain.endsWith(".example.net") ||
    domain.endsWith(".test") ||
    domain.endsWith(".invalid") ||
    domain.endsWith(".localhost")
  ) {
    return false;
  }
  return true;
}

function formatCategoryLabel(code) {
  const shopCat = SHOP_CATEGORY_BY_CODE.get(code);
  if (shopCat) return shopCat.label;
  const extraCat = EXTRA_CATEGORY_BY_CODE.get(code);
  if (extraCat) return extraCat.label;
  return code;
}

function formatTrackLabel(track) {
  return TRACK_LABELS[track] || track || "Authorized Partner";
}

function formatPlacementLabels(codes) {
  if (!Array.isArray(codes) || codes.length === 0) {
    return [PLACEMENT_LABELS.shop_storefront];
  }
  return codes.map((code) => PLACEMENT_LABELS[code] || code);
}

async function resolveResendApiKey(admin) {
  const envKey = String(process.env.RESEND_API_KEY || "").trim();
  if (envKey) return envKey;

  const now = Date.now();
  if (cachedResendSecret && now - cachedResendSecretAt < SECRET_CACHE_TTL_MS) {
    return cachedResendSecret;
  }
  try {
    if (!admin || typeof admin.app !== "function") return "";
    const app = admin.app();
    const credential = app && app.options && app.options.credential;
    if (!credential || typeof credential.getAccessToken !== "function") {
      return "";
    }
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
      `/secrets/RESEND_API_KEY/versions/latest:access`;
    const res = await fetch(url, {
      headers: {Authorization: `Bearer ${accessToken}`},
    });
    if (!res.ok) return "";
    const body = await res.json();
    const b64 = body && body.payload && body.payload.data;
    if (!b64) return "";
    const decoded = Buffer.from(b64, "base64").toString("utf8").trim();
    if (decoded) {
      cachedResendSecret = decoded;
      cachedResendSecretAt = now;
    }
    return decoded;
  } catch {
    return "";
  }
}

async function sendResendEmail({
  apiKey,
  from = DEFAULT_FROM_EMAIL,
  replyTo = DEFAULT_REPLY_TO_EMAIL,
  to,
  subject,
  html,
  text,
  idempotencyKey,
  tags,
  fetchFn,
}) {
  const effectiveFetch =
    fetchFn || (typeof globalThis.fetch === "function" ? globalThis.fetch.bind(globalThis) : null);
  if (!effectiveFetch) {
    return {sent: false, reason: "fetch_unavailable"};
  }
  const recipients = (Array.isArray(to) ? to : [to])
      .map((item) => cleanText(item, 254).toLowerCase())
      .filter(isDeliverableExternalEmail);
  if (recipients.length === 0) {
    return {sent: false, reason: "no_deliverable_recipient"};
  }
  const headers = {
    "Authorization": `Bearer ${apiKey}`,
    "Content-Type": "application/json",
  };
  if (idempotencyKey) {
    headers["Idempotency-Key"] = String(idempotencyKey).slice(0, 250);
  }
  const response = await effectiveFetch("https://api.resend.com/emails", {
    method: "POST",
    headers,
    body: JSON.stringify({
      from,
      to: recipients,
      ...(replyTo ? {reply_to: replyTo} : {}),
      subject,
      html,
      text,
      ...(Array.isArray(tags) && tags.length > 0 ? {tags} : {}),
    }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const errMsg =
      (payload && (payload.message || (payload.error && payload.error.message))) ||
      `HTTP ${response.status}`;
    return {sent: false, reason: errMsg};
  }
  return {
    sent: true,
    id: String((payload && payload.id) || ""),
    recipientCount: recipients.length,
  };
}

function buildAdminVendorApplicationAlertEmail({
  applicationId,
  application,
  siteOrigin = DEFAULT_SITE_ORIGIN,
}) {
  const cleanOrigin = String(siteOrigin || DEFAULT_SITE_ORIGIN).replace(/\/+$/u, "");
  const adminQueueUrl = `${cleanOrigin}/admin/shop?tab=applications`;
  const trackLabel = formatTrackLabel(application.partnershipTrack);
  const authLabel =
    AUTH_LEVEL_LABELS[application.authorizationLevel] ||
    application.authorizationLevel ||
    "Authorized Representative";
  const placementList = formatPlacementLabels(application.requestedPlacements).join(", ");
  const categoryList = (application.categories || []).map(formatCategoryLabel).join(", ");
  const brandsList = Array.isArray(application.brandsCarried) && application.brandsCarried.length > 0 ?
    application.brandsCarried.join(", ") :
    application.companyName;
  const regionsList = Array.isArray(application.fulfillmentRegions) &&
    application.fulfillmentRegions.length > 0 ?
    application.fulfillmentRegions.join(", ") :
    "US, CA";
  const integrationLabel =
    INTEGRATION_LABELS[application.catalogIntegrationMethod] ||
    application.catalogIntegrationMethod ||
    "Direct Product / Dealer Quote Links";

  const subject =
    `[New Brand / Vendor Request] ${application.companyName} requested to list on Pipe Buyer`;

  const contactLine = application.contactTitle ?
    `${application.contactName} (${application.contactTitle})` :
    application.contactName;

  const rows = [
    ["Reference ID", applicationId],
    ["Company / Brand", application.companyName],
    ["Partnership Track", trackLabel],
    ["Authorization Level", authLabel],
    ["Primary Contact", contactLine],
    ["Business Email", application.email],
    ["Direct Phone", application.phone],
    ...(application.headquartersLocation ?
      [["Headquarters / Territory", application.headquartersLocation]] :
      []),
    ...(application.websiteUrl ? [["Website / Dealer URL", application.websiteUrl]] : []),
    ...(application.sampleCatalogUrl ?
      [["Sample Catalog / Spec URL", application.sampleCatalogUrl]] :
      []),
    ["Requested App Placements", placementList],
    ["Brands Represented", brandsList],
    ["Product Categories", categoryList],
    ["Catalog Size & Feed", `${application.estimatedSkuCount || "50–250 SKUs"} • ${integrationLabel}`],
    ["Coverage Regions", regionsList],
    ...(application.affiliateProgramDetails ?
      [["Commercial / Dealer Structure", application.affiliateProgramDetails]] :
      []),
    ...(application.catalogNotes ? [["Notes & Highlights", application.catalogNotes]] : []),
  ];

  const htmlRows = rows.map(([label, val]) => `
    <tr>
      <td style="padding:10px 12px;border-bottom:1px solid #E2E8F0;font-weight:700;color:#334155;width:34%;vertical-align:top;font-size:13px;">
        ${escapeHtml(label)}
      </td>
      <td style="padding:10px 12px;border-bottom:1px solid #E2E8F0;color:#0F172A;font-size:13.5px;line-height:1.45;">
        ${escapeHtml(val)}
      </td>
    </tr>`).join("");

  const html = `<!DOCTYPE html>
<html>
<body style="margin:0;padding:24px;background:#F1F5F9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <div style="max-width:680px;margin:0 auto;background:#FFFFFF;border-radius:14px;overflow:hidden;border:1px solid #CBD5E1;">
    <div style="background:#0F172A;padding:22px 26px;border-bottom:4px solid #F97316;">
      <div style="color:#F97316;font-size:11px;font-weight:800;letter-spacing:1.2px;text-transform:uppercase;">
        PIPE BUYER ADMIN ALERT • VENDOR, DISTRIBUTOR &amp; BRAND PORTAL
      </div>
      <h1 style="margin:8px 0 0;color:#FFFFFF;font-size:20px;line-height:1.3;">
        ${escapeHtml(application.companyName)} requested to list products on Pipe Buyer
      </h1>
    </div>
    <div style="padding:24px 26px;">
      <p style="margin:0 0 16px;color:#334155;font-size:14px;line-height:1.5;">
        A new OEM, distributor, or brand listing request is waiting in the Pipe Buyer Store &amp; Brand Admin queue. Reply directly to this email to reach <strong>${escapeHtml(application.contactName)}</strong> (${escapeHtml(application.email)}).
      </p>
      <table style="width:100%;border-collapse:collapse;border:1px solid #E2E8F0;border-radius:8px;">
        ${htmlRows}
      </table>
      <div style="margin-top:22px;">
        <a href="${escapeHtml(adminQueueUrl)}" style="display:inline-block;background:#F97316;color:#FFFFFF;text-decoration:none;font-weight:800;font-size:14px;padding:12px 22px;border-radius:8px;">
          Review &amp; Approve in Pipe Buyer Admin
        </a>
      </div>
    </div>
  </div>
</body>
</html>`;

  const text = [
    "PIPE BUYER ADMIN ALERT — NEW VENDOR, DISTRIBUTOR & BRAND REQUEST",
    "================================================================",
    ...rows.map(([label, val]) => `${label}: ${val}`),
    "",
    `Review in Pipe Buyer Admin: ${adminQueueUrl}`,
  ].join("\n");

  return {subject, html, text, adminQueueUrl};
}

function buildApplicantVendorReceiptEmail({
  applicationId,
  application,
  siteOrigin = DEFAULT_SITE_ORIGIN,
}) {
  const cleanOrigin = String(siteOrigin || DEFAULT_SITE_ORIGIN).replace(/\/+$/u, "");
  const portalUrl = `${cleanOrigin}/shop/apply`;
  const trackLabel = formatTrackLabel(application.partnershipTrack);
  const placementList = formatPlacementLabels(application.requestedPlacements).join(", ");
  const brandsList = Array.isArray(application.brandsCarried) && application.brandsCarried.length > 0 ?
    application.brandsCarried.join(", ") :
    application.companyName;

  const subject =
    `Pipe Buyer Listing Request Received — ${application.companyName} (Ref: ${applicationId})`;

  const html = `<!DOCTYPE html>
<html>
<body style="margin:0;padding:24px;background:#F1F5F9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <div style="max-width:640px;margin:0 auto;background:#FFFFFF;border-radius:14px;overflow:hidden;border:1px solid #CBD5E1;">
    <div style="background:#0F172A;padding:22px 26px;border-bottom:4px solid #F97316;">
      <div style="color:#F97316;font-size:11px;font-weight:800;letter-spacing:1.2px;text-transform:uppercase;">
        PIPE BUYER VENDOR, DISTRIBUTOR &amp; BRAND PORTAL
      </div>
      <h1 style="margin:8px 0 0;color:#FFFFFF;font-size:20px;line-height:1.3;">
        We received your request to list on Pipe Buyer
      </h1>
    </div>
    <div style="padding:24px 26px;color:#334155;font-size:14px;line-height:1.55;">
      <p style="margin:0 0 14px;">Hi ${escapeHtml(application.contactName)},</p>
      <p style="margin:0 0 16px;">
        Thank you for submitting a listing request for <strong>${escapeHtml(application.companyName)}</strong>. Our Store &amp; Brand Partnerships team has been notified immediately and will review your product lines, dealer/brand authorization, and preferred integration model.
      </p>
      <div style="background:#F8FAFC;border:1px solid #E2E8F0;border-radius:10px;padding:14px 16px;margin-bottom:18px;">
        <div><strong>Reference ID:</strong> ${escapeHtml(applicationId)}</div>
        <div><strong>Partnership Track:</strong> ${escapeHtml(trackLabel)}</div>
        <div><strong>Brands / Equipment:</strong> ${escapeHtml(brandsList)}</div>
        <div><strong>Requested Placements:</strong> ${escapeHtml(placementList)}</div>
      </div>
      <p style="margin:0 0 18px;">
        If you need to share a catalog spreadsheet, spec sheets, or dealer territory map right away, simply reply to this email.
      </p>
      <a href="${escapeHtml(portalUrl)}" style="display:inline-block;background:#0F172A;color:#FFFFFF;text-decoration:none;font-weight:700;font-size:13.5px;padding:11px 18px;border-radius:8px;">
        Open Pipe Buyer Brand &amp; Vendor Portal
      </a>
    </div>
  </div>
</body>
</html>`;

  const text = [
    `Hi ${application.contactName},`,
    "",
    `We received your request to list ${application.companyName} on Pipe Buyer.`,
    `Reference ID: ${applicationId}`,
    `Partnership Track: ${trackLabel}`,
    `Brands / Equipment: ${brandsList}`,
    `Requested Placements: ${placementList}`,
    "",
    "Our Partnerships & Store Admin team has been notified and will follow up directly.",
    `Portal: ${portalUrl}`,
  ].join("\n");

  return {subject, html, text};
}

function buildApplicantVendorDecisionEmail({
  applicationId,
  application,
  decision,
  reviewNotes = "",
  siteOrigin = DEFAULT_SITE_ORIGIN,
}) {
  const cleanOrigin = String(siteOrigin || DEFAULT_SITE_ORIGIN).replace(/\/+$/u, "");
  const portalUrl = decision === "approved" ?
    `${cleanOrigin}/shop` :
    `${cleanOrigin}/shop/apply`;
  const decisionLabel = DECISION_LABELS[decision] || decision;

  const leadParagraph = {
    approved:
      `Great news — ${application.companyName} has been approved as an official partner on Pipe Buyer! Our team is ready to onboard your products, equipment links, or catalog feed.`,
    under_review:
      `Your Pipe Buyer listing request for ${application.companyName} is currently under active review by our Store & Brand Partnerships team.`,
    waitlisted:
      `Thank you for applying to list ${application.companyName} on Pipe Buyer. We have placed your application on our priority waitlist for the next category onboarding wave.`,
    declined:
      `Thank you for your interest in listing ${application.companyName} on Pipe Buyer. After reviewing your submission, we are unable to onboard this catalog at this time.`,
  }[decision] ||
    `Your Pipe Buyer partner application (${applicationId}) status is now: ${decisionLabel}.`;

  const subject =
    `Pipe Buyer Partner Application Update: ${decisionLabel} — ${application.companyName}`;

  const notesHtml = reviewNotes ? `
    <div style="background:#FFF7ED;border-left:4px solid #F97316;padding:12px 14px;margin:16px 0;color:#0F172A;">
      <div style="font-weight:800;font-size:12px;text-transform:uppercase;color:#C2410C;margin-bottom:4px;">
        Message from Pipe Buyer Partnerships Team
      </div>
      <div>${escapeHtml(reviewNotes)}</div>
    </div>` : "";

  const html = `<!DOCTYPE html>
<html>
<body style="margin:0;padding:24px;background:#F1F5F9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <div style="max-width:640px;margin:0 auto;background:#FFFFFF;border-radius:14px;overflow:hidden;border:1px solid #CBD5E1;">
    <div style="background:#0F172A;padding:22px 26px;border-bottom:4px solid #F97316;">
      <div style="color:#F97316;font-size:11px;font-weight:800;letter-spacing:1.2px;text-transform:uppercase;">
        PIPE BUYER VENDOR &amp; BRAND APPLICATION UPDATE
      </div>
      <h1 style="margin:8px 0 0;color:#FFFFFF;font-size:20px;line-height:1.3;">
        ${escapeHtml(application.companyName)} — ${escapeHtml(decisionLabel)}
      </h1>
    </div>
    <div style="padding:24px 26px;color:#334155;font-size:14px;line-height:1.55;">
      <p style="margin:0 0 14px;">Hi ${escapeHtml(application.contactName || "Partner")},</p>
      <p style="margin:0 0 14px;">${escapeHtml(leadParagraph)}</p>
      ${notesHtml}
      <p style="margin:0 0 18px;font-size:12.5px;color:#64748B;">
        Application Reference: ${escapeHtml(applicationId)}
      </p>
      <a href="${escapeHtml(portalUrl)}" style="display:inline-block;background:#F97316;color:#FFFFFF;text-decoration:none;font-weight:800;font-size:13.5px;padding:11px 18px;border-radius:8px;">
        Open Pipe Buyer
      </a>
    </div>
  </div>
</body>
</html>`;

  const text = [
    `Hi ${application.contactName || "Partner"},`,
    "",
    leadParagraph,
    ...(reviewNotes ? ["", `Notes from Pipe Buyer Team: ${reviewNotes}`] : []),
    "",
    `Application Reference: ${applicationId}`,
    `Open Pipe Buyer: ${portalUrl}`,
  ].join("\n");

  return {subject, html, text};
}

function createVendorPortalNotifier(admin, {
  notifyAdministrators,
  sendEmailImpl,
  fetchImpl,
} = {}) {
  const db = () => admin.firestore();
  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp();

  async function resolveRecipientTargets(settings = {}) {
    const adminRoleUids = new Set();
    const extraRecipientUids = new Set();
    const recipientEmails = new Set();

    if (Array.isArray(settings.adminNotificationEmails)) {
      for (const email of settings.adminNotificationEmails) {
        const cleaned = cleanText(email, 254).toLowerCase();
        if (cleaned) recipientEmails.add(cleaned);
      }
    }
    if (PRIMARY_ADMIN_MANAGER_EMAIL) {
      recipientEmails.add(PRIMARY_ADMIN_MANAGER_EMAIL.toLowerCase());
    }

    try {
      const [adminRolesSnap, shopStaffSnap] = await Promise.all([
        db().collection("administrator_roles").where("active", "==", true).get(),
        db().collection("shop_staff").where("active", "==", true).get(),
      ]);

      for (const doc of adminRolesSnap.docs || []) {
        if (doc.id) adminRoleUids.add(doc.id);
        const data = (typeof doc.data === "function" ? doc.data() : {}) || {};
        const email = cleanText(data.email, 254).toLowerCase();
        if (email) recipientEmails.add(email);
      }

      for (const doc of shopStaffSnap.docs || []) {
        const data = (typeof doc.data === "function" ? doc.data() : {}) || {};
        const role = cleanText(data.role, 40).toLowerCase();
        if (role === "store_manager" && data.restricted !== true) {
          if (doc.id && !adminRoleUids.has(doc.id)) {
            extraRecipientUids.add(doc.id);
          }
          const email = cleanText(data.email, 254).toLowerCase();
          if (email) recipientEmails.add(email);
        }
      }
    } catch (err) {
      console.warn("Vendor notifier roster lookup warning", err);
    }

    // Fallback: ensure primary administrator UID receives in-app notification even if
    // administrator_roles has not yet been seeded in Firestore.
    if (
      adminRoleUids.size === 0 &&
      extraRecipientUids.size === 0 &&
      PRIMARY_ADMIN_MANAGER_EMAIL &&
      admin &&
      typeof admin.auth === "function"
    ) {
      try {
        const authService = admin.auth();
        if (authService && typeof authService.getUserByEmail === "function") {
          const primaryUser = await authService.getUserByEmail(PRIMARY_ADMIN_MANAGER_EMAIL);
          if (primaryUser && primaryUser.uid) {
            extraRecipientUids.add(primaryUser.uid);
          }
        }
      } catch {
        // Primary admin account may not exist in local/test emulators
      }
    }

    const allUids = new Set([...adminRoleUids, ...extraRecipientUids]);
    return {
      uids: Array.from(allUids),
      adminRoleUids: Array.from(adminRoleUids),
      extraRecipientUids: Array.from(extraRecipientUids),
      emails: Array.from(recipientEmails),
    };
  }

  async function deliverEmailBatch(params) {
    if (typeof sendEmailImpl === "function") {
      return sendEmailImpl(params);
    }
    const apiKey = await resolveResendApiKey(admin);
    if (!apiKey) {
      return {sent: false, reason: "resend_api_key_not_configured"};
    }
    return sendResendEmail({
      ...params,
      apiKey,
      fetchFn: fetchImpl,
    });
  }

  async function dispatchVendorApplicationSubmittedNotifications({
    applicationId,
    application,
    settings = {},
  }) {
    const notificationId = `shop_vendor_app_${applicationId}`;
    const trackLabel = formatTrackLabel(application.partnershipTrack);
    const brandsPreview = Array.isArray(application.brandsCarried) &&
      application.brandsCarried.length > 0 ?
      ` • Brands: ${application.brandsCarried.slice(0, 4).join(", ")}` :
      "";
    const notificationPayload = {
      notificationId,
      type: "shop_vendor_application",
      priority: "high",
      route: "/admin/shop?tab=applications",
      title: `New Brand / Vendor Request: ${application.companyName}`,
      body:
        `${application.companyName} (${trackLabel}) requested to list products on Pipe Buyer${brandsPreview}. ` +
        `Contact: ${application.contactName} (${application.email} • ${application.phone}).`,
      pushTitle: "New Brand / Vendor Request",
      pushBody: `${application.companyName} requested to list products on Pipe Buyer.`,
      applicationId,
      companyName: application.companyName,
      contactName: application.contactName,
      contactEmail: application.email,
      partnershipTrack: application.partnershipTrack,
      brandsCarried: Array.isArray(application.brandsCarried) ?
        application.brandsCarried.slice(0, 10) :
        [],
      requestedPlacements: Array.isArray(application.requestedPlacements) ?
        application.requestedPlacements :
        ["shop_storefront"],
      read: false,
    };

    const targets = await resolveRecipientTargets(settings);
    let inAppCount = 0;

    if (typeof notifyAdministrators === "function") {
      await notifyAdministrators(notificationPayload);
      inAppCount = Math.max(1, targets.uids.length);
    }

    // Also notify active Store Managers (and primary admin fallback) directly in users/{uid}/notifications
    // without duplicating docs already written by notifyAdministrators.
    const directWriteUids = typeof notifyAdministrators === "function" ?
      targets.extraRecipientUids :
      targets.uids;
    if (directWriteUids.length > 0) {
      const payloadWithoutId = {...notificationPayload};
      delete payloadWithoutId.notificationId;
      await Promise.all(directWriteUids.map(async (uid) => {
        try {
          await db()
              .collection("users")
              .doc(uid)
              .collection("notifications")
              .doc(notificationId)
              .set({
                ...payloadWithoutId,
                recipientUid: uid,
                createdAt: serverTimestamp(),
              }, {merge: true});
        } catch (err) {
          console.warn(`Failed writing vendor notification for ${uid}`, err);
        }
      }));
      inAppCount = Math.max(inAppCount, targets.uids.length);
    }

    // Dispatch Admin Alert Email via Resend
    let adminEmailStatus = "skipped";
    let adminEmailsSent = 0;
    if (typeof sendEmailImpl !== "function" && !isDeliverableExternalEmail(application.email)) {
      adminEmailStatus = "synthetic_test_sender";
    } else {
      try {
        const adminRendered = buildAdminVendorApplicationAlertEmail({
          applicationId,
          application,
        });
        const adminEmailRes = await deliverEmailBatch({
          to: targets.emails,
          replyTo: application.email || DEFAULT_REPLY_TO_EMAIL,
          subject: adminRendered.subject,
          html: adminRendered.html,
          text: adminRendered.text,
          idempotencyKey: `vendor-admin-alert-${applicationId}`,
          tags: [
            {name: "category", value: "vendor_portal_admin_alert"},
            {name: "application_id", value: String(applicationId).slice(0, 64)},
          ],
        });
        if (adminEmailRes && adminEmailRes.sent) {
          adminEmailStatus = "sent";
          adminEmailsSent = Number(adminEmailRes.recipientCount || targets.emails.length || 1);
        } else if (adminEmailRes && adminEmailRes.reason) {
          adminEmailStatus = String(adminEmailRes.reason);
        }
      } catch (emailErr) {
        console.warn("Vendor admin alert email failed", emailErr);
        adminEmailStatus = "failed";
      }
    }

    // Dispatch Applicant Confirmation Email via Resend
    let applicantConfirmationSent = false;
    try {
      const receiptRendered = buildApplicantVendorReceiptEmail({
        applicationId,
        application,
      });
      const receiptRes = await deliverEmailBatch({
        to: [application.email],
        replyTo: DEFAULT_REPLY_TO_EMAIL,
        subject: receiptRendered.subject,
        html: receiptRendered.html,
        text: receiptRendered.text,
        idempotencyKey: `vendor-applicant-receipt-${applicationId}`,
        tags: [
          {name: "category", value: "vendor_portal_receipt"},
          {name: "application_id", value: String(applicationId).slice(0, 64)},
        ],
      });
      applicantConfirmationSent = Boolean(receiptRes && receiptRes.sent);
    } catch (receiptErr) {
      console.warn("Vendor applicant receipt email failed", receiptErr);
    }

    return {
      inAppAdminCount: inAppCount,
      adminEmailStatus,
      adminEmailsNotifiedCount: adminEmailsSent,
      applicantConfirmationSent,
    };
  }

  async function dispatchVendorApplicationDecisionNotifications({
    applicationId,
    application,
    decision,
    reviewNotes = "",
    vendorId = null,
    notifyApplicant = true,
  }) {
    if (!notifyApplicant) {
      return {
        inAppApplicantNotified: false,
        applicantEmailSent: false,
        status: "skipped_by_reviewer",
      };
    }

    let targetUid = cleanText(application.submitterUid, 128) || "";
    if (
      !targetUid &&
      application.email &&
      admin &&
      typeof admin.auth === "function"
    ) {
      try {
        const authService = admin.auth();
        if (authService && typeof authService.getUserByEmail === "function") {
          const matchedUser = await authService.getUserByEmail(
              String(application.email).trim().toLowerCase(),
          );
          if (matchedUser && matchedUser.uid) {
            targetUid = matchedUser.uid;
          }
        }
      } catch {
        // Applicant may not have created a consumer account yet
      }
    }

    const decisionLabel = DECISION_LABELS[decision] || decision;
    let inAppApplicantNotified = false;
    if (targetUid) {
      try {
        const bodyBase = decision === "approved" ?
          `Your listing application for ${application.companyName} has been approved!` :
          `Your listing application for ${application.companyName} is now ${decisionLabel}.`;
        const fullBody = reviewNotes ? `${bodyBase} Note: ${reviewNotes}` : bodyBase;
        await db()
            .collection("users")
            .doc(targetUid)
            .collection("notifications")
            .doc(`shop_vendor_app_${applicationId}_${decision}`)
            .set({
              recipientUid: targetUid,
              type: "shop_vendor_application_status",
              priority: "high",
              route: "/shop/apply",
              title: `Partner Application Update: ${decisionLabel}`,
              body: fullBody.slice(0, 500),
              pushTitle: `Partner Application: ${decisionLabel}`,
              pushBody:
                `Open Pipe Buyer to view the latest update for ${application.companyName}.`.slice(
                    0,
                    160,
                ),
              applicationId,
              companyName: application.companyName || "",
              status: decision,
              vendorId: vendorId || null,
              read: false,
              createdAt: serverTimestamp(),
            }, {merge: true});
        inAppApplicantNotified = true;
      } catch (err) {
        console.warn("Failed writing applicant vendor status notification", err);
      }
    }

    let applicantEmailSent = false;
    let emailStatus = "skipped";
    if (application.email) {
      try {
        const rendered = buildApplicantVendorDecisionEmail({
          applicationId,
          application,
          decision,
          reviewNotes,
        });
        const emailRes = await deliverEmailBatch({
          to: [application.email],
          replyTo: DEFAULT_REPLY_TO_EMAIL,
          subject: rendered.subject,
          html: rendered.html,
          text: rendered.text,
          idempotencyKey: `vendor-decision-${applicationId}-${decision}`,
          tags: [
            {name: "category", value: "vendor_portal_decision"},
            {name: "decision", value: String(decision).slice(0, 32)},
          ],
        });
        applicantEmailSent = Boolean(emailRes && emailRes.sent);
        emailStatus = applicantEmailSent ?
          "sent" :
          String((emailRes && emailRes.reason) || "skipped");
      } catch (err) {
        console.warn("Failed sending applicant decision email", err);
        emailStatus = "failed";
      }
    }

    return {
      inAppApplicantNotified,
      applicantEmailSent,
      emailStatus,
    };
  }

  return {
    dispatchVendorApplicationDecisionNotifications,
    dispatchVendorApplicationSubmittedNotifications,
    resolveRecipientTargets,
  };
}

module.exports = {
  AUTH_LEVEL_LABELS,
  DECISION_LABELS,
  INTEGRATION_LABELS,
  PLACEMENT_LABELS,
  TRACK_LABELS,
  buildAdminVendorApplicationAlertEmail,
  buildApplicantVendorDecisionEmail,
  buildApplicantVendorReceiptEmail,
  createVendorPortalNotifier,
  formatCategoryLabel,
  formatPlacementLabels,
  formatTrackLabel,
  isDeliverableExternalEmail,
};
