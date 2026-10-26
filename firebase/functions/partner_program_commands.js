"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  PARTNER_BRAND_CATEGORIES,
  PARTNER_COMMERCIAL_MODELS,
  PARTNER_PROGRAM_TYPES,
  PartnerProgramPolicyError,
  assertPartnerInquiryStatusTransition,
  normalizePartnerShowcaseDeal,
  toPublicPartnerShowcaseDeal,
  validatePartnerDealInterestInput,
  validatePartnerInquiryInput,
} = require("./partner_program_policy");

const PUBLIC_SHOWCASES = "partner_public_showcases";
const ADMIN_SHOWCASES = "partner_showcases";
const PARTNER_INQUIRIES = "partner_inquiries";
const PARTNER_DEAL_LEADS = "partner_deal_leads";
const PARTNER_AUDIT_EVENTS = "partner_program_audit_events";

function command(handler) {
  return async (request) => {
    try {
      return await handler(request || {});
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError ||
          error instanceof AdministratorAuthorizationError ||
          error instanceof PartnerProgramPolicyError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Partner program command failed", error);
      throw new HttpsError(
          "internal",
          "The partner program request could not be completed.",
      );
    }
  };
}

function requiredId(data, fieldName) {
  const value = String(data && data[fieldName] || "").trim();
  if (!value || value.length > 140 || value.includes("/")) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} is missing or invalid.`,
    );
  }
  return value;
}

function serializeTimestamp(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (typeof value === "string") return value;
  return null;
}

function anonymousActorBucket(request) {
  const rawIp = String(
      request && request.rawRequest &&
      (request.rawRequest.ip ||
        (request.rawRequest.headers &&
          request.rawRequest.headers["x-forwarded-for"])) ||
      "public",
  ).split(",")[0].trim();
  const digest = crypto.createHash("sha256")
      .update(`partner-intake|${rawIp}`)
      .digest("hex")
      .slice(0, 24);
  return `anon_partner_${digest}`;
}

async function enforcePublicOrUserRateLimit({db, admin, request, limit = 12}) {
  if (request && request.auth && request.auth.uid) {
    await enforceUserRateLimit({
      db,
      admin,
      request,
      scope: "directory",
      limitOverride: limit,
    });
    return;
  }
  const bucketRequest = {
    ...request,
    auth: {uid: anonymousActorBucket(request)},
  };
  await enforceUserRateLimit({
    db,
    admin,
    request: bucketRequest,
    scope: "directory",
    limitOverride: limit,
  });
}

function createPartnerProgramCommands(admin, {notifyAdministrators} = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function writeAuditEvent(actorUid, action, targetId, details = {}) {
    await db.collection(PARTNER_AUDIT_EVENTS).add({
      actorUid,
      action,
      targetId,
      details,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  return {
    getPartnerProgramTaxonomy: command(async () => ({
      brandCategories: PARTNER_BRAND_CATEGORIES,
      programTypes: PARTNER_PROGRAM_TYPES,
      commercialModels: PARTNER_COMMERCIAL_MODELS,
    })),

    listPartnerShowcaseDeals: command(async (request) => {
      const data = request.data || {};
      const brandCategory = String(data.brandCategory || "").trim();
      const programType = String(data.programType || "").trim();
      const region = String(data.region || "").trim().toLowerCase();
      const query = String(data.query || "").trim().toLowerCase();
      const featuredOnly = data.featuredOnly === true;

      const snapshot = await db.collection(PUBLIC_SHOWCASES)
          .limit(120)
          .get();

      const items = [];
      snapshot.forEach((doc) => {
        const raw = doc.data() || {};
        if (raw.active === false) return;
        const pub = toPublicPartnerShowcaseDeal(doc.id, raw);
        if (featuredOnly && !pub.featured) return;
        if (brandCategory && pub.brandCategory !== brandCategory) return;
        if (programType && !pub.programTypes.includes(programType)) return;
        if (region) {
          const regionMatch = pub.targetRegions.some(
              (r) => r.toLowerCase().includes(region) ||
                r.toLowerCase() === "global",
          );
          if (!regionMatch) return;
        }
        if (query) {
          const haystack = [
            pub.partnerName,
            pub.headline,
            pub.summary,
            pub.offerBadge,
            pub.discountDetails,
            ...pub.productHighlights,
            ...pub.targetRegions,
          ].join(" ").toLowerCase();
          if (!haystack.includes(query)) return;
        }
        items.push(pub);
      });

      items.sort((a, b) => {
        if (a.featured !== b.featured) return a.featured ? -1 : 1;
        if (a.priorityRank !== b.priorityRank) {
          return a.priorityRank - b.priorityRank;
        }
        return a.partnerName.localeCompare(b.partnerName);
      });

      return {
        items,
        totalMatched: items.length,
      };
    }),

    submitPartnerInquiry: command(async (request) => {
      await enforcePublicOrUserRateLimit({db, admin, request, limit: 10});
      const validated = validatePartnerInquiryInput(request.data || {});
      const submitterUid = request.auth && request.auth.uid ?
        request.auth.uid : null;
      const ref = db.collection(PARTNER_INQUIRIES).doc();
      const record = {
        ...validated,
        inquiryId: ref.id,
        submitterUid,
        status: "new",
        adminNotes: "",
        publishedShowcaseId: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };
      await ref.set(record);

      if (typeof notifyAdministrators === "function") {
        await notifyAdministrators({
          notificationId: `partner-inquiry-${ref.id}`,
          type: "partner_program_inquiry",
          title: `New Partner Inquiry: ${validated.companyName}`,
          body: `${validated.headline} (${validated.brandCategory})`,
          inquiryId: ref.id,
          read: false,
        });
      }

      return {
        inquiryId: ref.id,
        status: "new",
        companyName: validated.companyName,
      };
    }),

    submitPartnerDealInterest: command(async (request) => {
      await enforcePublicOrUserRateLimit({db, admin, request, limit: 15});
      const validated = validatePartnerDealInterestInput(request.data || {});
      const submitterUid = request.auth && request.auth.uid ?
        request.auth.uid : null;
      const ref = db.collection(PARTNER_DEAL_LEADS).doc();
      await ref.set({
        ...validated,
        leadId: ref.id,
        submitterUid,
        status: "new",
        createdAt: FieldValue.serverTimestamp(),
      });

      if (typeof notifyAdministrators === "function") {
        await notifyAdministrators({
          notificationId: `partner-deal-lead-${ref.id}`,
          type: "partner_deal_lead",
          title: `Partner Fleet/Deal Lead: ${validated.companyName}`,
          body: `Interested in ${validated.partnerName || validated.showcaseId}`,
          leadId: ref.id,
          showcaseId: validated.showcaseId,
          read: false,
        });
      }

      return {
        leadId: ref.id,
        status: "new",
      };
    }),

    listMyPartnerInquiries: command(async (request) => {
      const identity = requireAuthenticatedIdentity(request, {
        requireEmail: false,
        requirePhone: false,
        allowUnverified: true,
      });
      const snapshot = await db.collection(PARTNER_INQUIRIES)
          .where("submitterUid", "==", identity.uid)
          .limit(50)
          .get();
      const items = [];
      snapshot.forEach((doc) => {
        const d = doc.data() || {};
        items.push({
          inquiryId: doc.id,
          companyName: d.companyName || "",
          brandCategory: d.brandCategory || "",
          programTypes: Array.isArray(d.programTypes) ? d.programTypes : [],
          commercialModel: d.commercialModel || "",
          headline: d.headline || "",
          dealOrDiscountOffer: d.dealOrDiscountOffer || "",
          status: d.status || "new",
          publishedShowcaseId: d.publishedShowcaseId || null,
          createdAt: serializeTimestamp(d.createdAt),
        });
      });
      items.sort((a, b) =>
        String(b.createdAt || "").localeCompare(String(a.createdAt || "")),
      );
      return {items};
    }),

    listAdminPartnerProgramDashboard: command(async (request) => {
      requireAdministrator(request);
      const [inquiriesSnap, showcasesSnap, leadsSnap] = await Promise.all([
        db.collection(PARTNER_INQUIRIES).limit(150).get(),
        db.collection(ADMIN_SHOWCASES).limit(150).get(),
        db.collection(PARTNER_DEAL_LEADS).limit(150).get(),
      ]);

      const inquiries = [];
      inquiriesSnap.forEach((doc) => {
        const d = doc.data() || {};
        inquiries.push({
          ...d,
          inquiryId: doc.id,
          createdAt: serializeTimestamp(d.createdAt),
          updatedAt: serializeTimestamp(d.updatedAt),
        });
      });
      inquiries.sort((a, b) =>
        String(b.createdAt || "").localeCompare(String(a.createdAt || "")),
      );

      const showcases = [];
      showcasesSnap.forEach((doc) => {
        const d = doc.data() || {};
        showcases.push({
          ...d,
          showcaseId: doc.id,
          createdAt: serializeTimestamp(d.createdAt),
          updatedAt: serializeTimestamp(d.updatedAt),
        });
      });
      showcases.sort((a, b) => (a.priorityRank || 100) - (b.priorityRank || 100));

      const dealLeads = [];
      leadsSnap.forEach((doc) => {
        const d = doc.data() || {};
        dealLeads.push({
          ...d,
          leadId: doc.id,
          createdAt: serializeTimestamp(d.createdAt),
        });
      });
      dealLeads.sort((a, b) =>
        String(b.createdAt || "").localeCompare(String(a.createdAt || "")),
      );

      return {
        inquiries,
        showcases,
        dealLeads,
        counts: {
          newInquiries: inquiries.filter((i) => i.status === "new").length,
          totalInquiries: inquiries.length,
          activeShowcases: showcases.filter((s) => s.active !== false).length,
          totalDealLeads: dealLeads.length,
        },
      };
    }),

    reviewPartnerInquiry: command(async (request) => {
      const actorUid = requireAdministrator(request);
      await enforceUserRateLimit({
        db,
        admin,
        request,
        scope: "administration",
      });
      const data = request.data || {};
      const inquiryId = requiredId(data, "inquiryId");
      const nextStatus = String(data.status || "").trim();
      const adminNotes = String(data.adminNotes || "").trim().slice(0, 1500);
      const publishShowcase = data.publishShowcase === true;

      const inquiryRef = db.collection(PARTNER_INQUIRIES).doc(inquiryId);
      const snapshot = await inquiryRef.get();
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Partner inquiry was not found.");
      }
      const existing = snapshot.data() || {};
      const validatedStatus = assertPartnerInquiryStatusTransition(
          existing.status || "new",
          nextStatus,
      );

      let publishedShowcaseId = existing.publishedShowcaseId || null;
      if (publishShowcase && validatedStatus === "approved") {
        const showcaseRef = publishedShowcaseId ?
          db.collection(ADMIN_SHOWCASES).doc(publishedShowcaseId) :
          db.collection(ADMIN_SHOWCASES).doc();
        publishedShowcaseId = showcaseRef.id;

        const normalizedShowcase = normalizePartnerShowcaseDeal({
          partnerName: existing.companyName,
          brandCategory: existing.brandCategory,
          programTypes: existing.programTypes,
          headline: existing.headline,
          summary: existing.productSummary,
          offerBadge: data.offerBadge ||
            (existing.dealOrDiscountOffer ? "Oilfield Partner Deal" : "Featured Partner"),
          discountDetails: existing.dealOrDiscountOffer || "",
          productHighlights: Array.isArray(data.productHighlights) ?
            data.productHighlights : [],
          targetRegions: existing.targetRegions,
          ctaLabel: data.ctaLabel || "Request Fleet / Deal Info",
          ctaUrl: existing.website || "",
          contactEmail: existing.email || "",
          contactPhone: existing.phone || "",
          featured: data.featured === true,
          active: true,
          priorityRank: data.priorityRank,
          adminNotes,
        });

        await showcaseRef.set({
          ...normalizedShowcase,
          showcaseId: publishedShowcaseId,
          sourceInquiryId: inquiryId,
          updatedByUid: actorUid,
          updatedAt: FieldValue.serverTimestamp(),
          createdAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        await db.collection(PUBLIC_SHOWCASES).doc(publishedShowcaseId).set({
          ...toPublicPartnerShowcaseDeal(publishedShowcaseId, normalizedShowcase),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      await inquiryRef.set({
        status: validatedStatus,
        adminNotes,
        publishedShowcaseId,
        reviewedByUid: actorUid,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      if (existing.submitterUid) {
        await db.collection("users")
            .doc(existing.submitterUid)
            .collection("notifications")
            .doc(`partner-inquiry-${inquiryId}-${validatedStatus}`)
            .set({
              recipientUid: existing.submitterUid,
              type: "partner_inquiry_status_updated",
              title: `Partner Proposal Status: ${validatedStatus.toUpperCase()}`,
              body: publishedShowcaseId ?
                `Your ${existing.companyName || "partner"} showcase has been approved and published live on Pipe Buyer.` :
                `Your partnership proposal for ${existing.companyName || "your organization"} is now ${validatedStatus}.`,
              inquiryId,
              publishedShowcaseId,
              status: validatedStatus,
              read: false,
              createdAt: FieldValue.serverTimestamp(),
            }, {merge: true});
      }

      await writeAuditEvent(actorUid, "review_partner_inquiry", inquiryId, {
        status: validatedStatus,
        publishedShowcaseId,
      });

      return {
        inquiryId,
        status: validatedStatus,
        publishedShowcaseId,
      };
    }),

    upsertPartnerShowcaseDeal: command(async (request) => {
      const actorUid = requireAdministrator(request);
      await enforceUserRateLimit({
        db,
        admin,
        request,
        scope: "administration",
      });
      const data = request.data || {};
      const existingId = String(data.showcaseId || "").trim();
      if (existingId && existingId.includes("/")) {
        throw new HttpsError("invalid-argument", "Invalid showcaseId.");
      }

      const normalized = normalizePartnerShowcaseDeal(data);
      const adminRef = existingId ?
        db.collection(ADMIN_SHOWCASES).doc(existingId) :
        db.collection(ADMIN_SHOWCASES).doc();
      const showcaseId = adminRef.id;

      await adminRef.set({
        ...normalized,
        showcaseId,
        updatedByUid: actorUid,
        updatedAt: FieldValue.serverTimestamp(),
        ...(existingId ? {} : {createdAt: FieldValue.serverTimestamp()}),
      }, {merge: true});

      const publicRef = db.collection(PUBLIC_SHOWCASES).doc(showcaseId);
      if (normalized.active) {
        await publicRef.set({
          ...toPublicPartnerShowcaseDeal(showcaseId, normalized),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        await publicRef.delete();
      }

      await writeAuditEvent(actorUid, "upsert_partner_showcase", showcaseId, {
        active: normalized.active,
        featured: normalized.featured,
      });

      return {
        showcaseId,
        active: normalized.active,
        featured: normalized.featured,
      };
    }),
  };
}

module.exports = {
  createPartnerProgramCommands,
};
