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
  COVERAGE_LINE_BY_CODE,
  InsurancePolicyError,
  assertRateApplicationStatusTransition,
  normalizeInsuranceProviderRecord,
  toPublicInsuranceProvider,
  validateInsuranceProviderApplication,
  validateInsuranceRateApplication,
} = require("./insurance_marketplace_policy");

const PUBLIC_PROVIDERS = "insurance_public_providers";
const PROVIDERS = "insurance_providers";
const PROVIDER_APPLICATIONS = "insurance_provider_applications";
const RATE_APPLICATIONS = "insurance_rate_applications";
const AUDIT_EVENTS = "insurance_audit_events";

function jsonSafe(value) {
  if (value == null) return value;
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(jsonSafe);
  if (typeof value === "object") {
    return Object.fromEntries(
        Object.entries(value).map(([key, child]) => [key, jsonSafe(child)]),
    );
  }
  return value;
}

function timestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (typeof value.toDate === "function") return value.toDate().getTime();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

function boundedPageSize(value, fallback = 60, max = 120) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.min(max, Math.trunc(parsed)));
}

function requiredEntityId(data, fieldName) {
  const value = String(data && data[fieldName] != null ? data[fieldName] : "").trim();
  if (!value || value.length > 180 || value.includes("/")) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} is missing or invalid.`,
    );
  }
  return value;
}

function optionalEntityId(data, fieldName) {
  const value = String(data && data[fieldName] != null ? data[fieldName] : "").trim();
  if (!value) return "";
  if (value.length > 180 || value.includes("/")) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} is invalid.`,
    );
  }
  return value;
}

function normalizeStringArray(raw, maxItems = 20, maxLength = 160) {
  if (!Array.isArray(raw)) return [];
  const seen = new Set();
  const result = [];
  for (const item of raw) {
    const clean = String(item == null ? "" : item).trim().slice(0, maxLength);
    if (!clean) continue;
    const lower = clean.toLowerCase();
    if (seen.has(lower)) continue;
    seen.add(lower);
    result.push(clean);
    if (result.length >= maxItems) break;
  }
  return result;
}

function guestRateLimitActorKey(request, fallbackHint = "") {
  const rawReq = (request && request.rawRequest) || {};
  const forwarded = rawReq.headers && rawReq.headers["x-forwarded-for"];
  const ipCandidate = Array.isArray(forwarded) ?
    forwarded[0] :
    (typeof forwarded === "string" ? forwarded.split(",")[0] : rawReq.ip);
  const ip = String(ipCandidate || "").trim();
  const source = ip || String(fallbackHint || "anonymous").trim().toLowerCase();
  const digest = crypto.createHash("sha256").update(source).digest("hex").slice(0, 24);
  return `guest_ins_${digest}`;
}

function command(handler) {
  return async (request) => {
    try {
      return await handler(request || {});
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof InsurancePolicyError ||
          error instanceof AccountSecurityError ||
          error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Insurance marketplace command failed", error);
      throw new HttpsError(
          "internal",
          "The insurance marketplace action could not be completed.",
      );
    }
  };
}

function matchesProviderFilters(provider, {
  query,
  coverageLine,
  countryCode,
  regionCode,
  providerType,
  msaOnly,
  fastCoiOnly,
}) {
  if (!provider || provider.active === false) return false;

  if (coverageLine) {
    const lines = Array.isArray(provider.coverageLines) ? provider.coverageLines : [];
    if (!lines.includes(coverageLine)) return false;
  }

  if (countryCode) {
    const countries = Array.isArray(provider.licensedCountries) ?
      provider.licensedCountries.map((c) => String(c).toUpperCase()) :
      [];
    const primaryCountry = String(provider.countryCode || "").toUpperCase();
    if (!countries.includes(countryCode) && primaryCountry !== countryCode) {
      return false;
    }
  }

  if (regionCode) {
    const regions = Array.isArray(provider.licensedRegions) ?
      provider.licensedRegions.map((r) => String(r).toUpperCase()) :
      [];
    const primaryRegion = String(provider.regionCode || "").toUpperCase();
    if (!regions.includes(regionCode) && primaryRegion !== regionCode) {
      return false;
    }
  }

  if (providerType && String(provider.providerType || "").toLowerCase() !== providerType) {
    return false;
  }

  if (msaOnly && provider.msaCompliant !== true) return false;
  if (fastCoiOnly && provider.fastCoi24x7 !== true) return false;

  if (query) {
    const normalizedQuery = query.toLowerCase().trim();
    const haystack = [
      provider.companyName,
      provider.providerType,
      provider.headquartersCity,
      provider.countryCode,
      provider.regionCode,
      provider.amBestRating,
      provider.summary,
      ...(provider.coverageLines || []),
      ...(provider.coverageLabels || []),
      ...(provider.licensedCountries || []),
      ...(provider.licensedRegions || []),
      ...(provider.operatingBasins || []),
      ...(provider.highlights || []),
    ].join(" ").toLowerCase();

    const tokenSet = new Set(
        (provider.searchTokens || []).map((t) => String(t).toLowerCase()),
    );
    const words = normalizedQuery.split(/\s+/u).filter((w) => w.length >= 2);
    const phraseHit = haystack.includes(normalizedQuery);
    const wordsHit = words.length > 0 &&
      words.every((w) => tokenSet.has(w) || haystack.includes(w));
    if (!phraseHit && !wordsHit) return false;
  }

  return true;
}

function sortPublicProviders(providers) {
  return [...providers].sort((left, right) => {
    const featuredDiff = Number(right.featured === true) - Number(left.featured === true);
    if (featuredDiff !== 0) return featuredDiff;
    const scoreDiff = Number(right.priorityScore || 0) - Number(left.priorityScore || 0);
    if (scoreDiff !== 0) return scoreDiff;
    return String(left.companyName || "").localeCompare(String(right.companyName || ""));
  });
}

function createInsuranceMarketplaceCommands(admin, {notifyAdministrators} = {}) {
  const db = () => admin.firestore();
  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp();

  async function enforceSubmissionRateLimit(request, emailHint, limitOverride) {
    const effectiveRequest = request && request.auth && request.auth.uid ?
      request :
      {
        ...(request || {}),
        auth: {uid: guestRateLimitActorKey(request, emailHint)},
      };
    await enforceUserRateLimit({
      db: db(),
      admin,
      request: effectiveRequest,
      scope: "directory",
      limitOverride,
    });
  }

  async function recordAuditEvent({
    actorUid,
    action,
    targetType,
    targetId,
    details = {},
  }) {
    await db().collection(AUDIT_EVENTS).add({
      schemaVersion: 1,
      actorUid,
      actorRole: "administrator",
      action,
      targetType,
      targetId,
      details,
      createdAt: serverTimestamp(),
    });
  }

  const listInsuranceProviders = command(async (request) => {
    const data = (request && request.data) || {};
    const limit = boundedPageSize(data.pageSize, 60, 120);
    const query = String(data.query == null ? "" : data.query).trim().slice(0, 120);
    const rawLine = String(
        data.coverageLine == null ? "" : data.coverageLine,
    ).trim().toLowerCase();
    const coverageLine = rawLine && COVERAGE_LINE_BY_CODE.has(rawLine) ? rawLine : "";
    const countryCode = String(
        data.countryCode == null ? "" : data.countryCode,
    ).trim().toUpperCase();
    const regionCode = String(
        data.regionCode == null ? "" : data.regionCode,
    ).trim().toUpperCase();
    const providerType = String(
        data.providerType == null ? "" : data.providerType,
    ).trim().toLowerCase();
    const msaOnly = data.msaOnly === true;
    const fastCoiOnly = data.fastCoiOnly === true;

    const snapshot = await db().collection(PUBLIC_PROVIDERS).limit(300).get();
    const candidates = snapshot.docs.map((doc) => ({
      id: doc.id,
      providerId: doc.id,
      ...doc.data(),
    }));

    const matched = sortPublicProviders(
        candidates.filter((provider) => matchesProviderFilters(provider, {
          query,
          coverageLine,
          countryCode,
          regionCode,
          providerType,
          msaOnly,
          fastCoiOnly,
        })),
    );

    return {
      providers: matched.slice(0, limit).map(jsonSafe),
      totalMatched: matched.length,
    };
  });

  const submitInsuranceRateApplication = command(async (request) => {
    const data = (request && request.data) || {};
    const validated = validateInsuranceRateApplication(data);
    await enforceSubmissionRateLimit(request, validated.email, 15);

    let resolvedTargetProviderName = validated.targetProviderName;
    if (validated.targetProviderId && !resolvedTargetProviderName) {
      const targetSnap = await db()
          .collection(PUBLIC_PROVIDERS)
          .doc(validated.targetProviderId)
          .get();
      if (targetSnap.exists) {
        resolvedTargetProviderName = String(
            (targetSnap.data() || {}).companyName || "",
        ).trim();
      }
    }

    const submitterUid = (request && request.auth && request.auth.uid) || null;
    const docRef = await db().collection(RATE_APPLICATIONS).add({
      schemaVersion: 1,
      submitterUid,
      ...validated,
      targetProviderName: resolvedTargetProviderName,
      status: "new",
      matchedProviderIds: validated.targetProviderId ? [validated.targetProviderId] : [],
      matchedProviderNames: resolvedTargetProviderName ? [resolvedTargetProviderName] : [],
      brokerResponseNotes: "",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    if (typeof notifyAdministrators === "function") {
      await notifyAdministrators({
        notificationId: `ins-rate-${docRef.id}`,
        type: "insurance_rate_application",
        title: `New Commercial Insurance Rate Request: ${validated.companyName}`,
        body: `${validated.companyName} (${validated.regionCode || validated.countryCode}) requested quotes for ${validated.coverageLines.length} coverage line(s).`,
        applicationId: docRef.id,
        read: false,
      });
    }

    return {
      applicationId: docRef.id,
      status: "new",
      distributionMode: validated.distributionMode,
      coverageLines: validated.coverageLines,
      targetProviderId: validated.targetProviderId,
      targetProviderName: resolvedTargetProviderName,
    };
  });

  const listMyInsuranceRateApplications = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request, {
      requireEmail: false,
      requirePhone: false,
      allowUnverified: true,
    });

    const snapshot = await db()
        .collection(RATE_APPLICATIONS)
        .where("submitterUid", "==", identity.uid)
        .limit(100)
        .get();

    const items = snapshot.docs
        .map((doc) => ({id: doc.id, applicationId: doc.id, ...doc.data()}))
        .sort((left, right) => timestampMillis(right.createdAt) - timestampMillis(left.createdAt))
        .map(jsonSafe);

    return {applications: items};
  });

  const submitInsuranceProviderApplication = command(async (request) => {
    const data = (request && request.data) || {};
    const validated = validateInsuranceProviderApplication(data);
    await enforceSubmissionRateLimit(request, validated.email, 10);

    const submitterUid = (request && request.auth && request.auth.uid) || null;
    const docRef = await db().collection(PROVIDER_APPLICATIONS).add({
      schemaVersion: 1,
      submitterUid,
      ...validated,
      status: "pending_review",
      providerId: null,
      reviewNote: "",
      reviewedByUid: null,
      reviewedAt: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    if (typeof notifyAdministrators === "function") {
      await notifyAdministrators({
        notificationId: `ins-provider-${docRef.id}`,
        type: "insurance_provider_application",
        title: `New Insurance Provider Application: ${validated.companyName}`,
        body: `${validated.companyName} (${validated.providerType.replace(/_/gu, " ")}) applied to list on Pipe Buyer Insurance.`,
        applicationId: docRef.id,
        read: false,
      });
    }

    return {
      applicationId: docRef.id,
      status: "pending_review",
    };
  });

  const listAdminInsuranceDashboard = command(async (request) => {
    requireAdministrator(request);

    const [providerAppsSnap, rateAppsSnap, providersSnap] = await Promise.all([
      db().collection(PROVIDER_APPLICATIONS).limit(150).get(),
      db().collection(RATE_APPLICATIONS).limit(150).get(),
      db().collection(PROVIDERS).limit(150).get(),
    ]);

    const providerApplications = providerAppsSnap.docs
        .map((doc) => ({id: doc.id, applicationId: doc.id, ...doc.data()}))
        .sort((a, b) => timestampMillis(b.createdAt) - timestampMillis(a.createdAt))
        .map(jsonSafe);

    const rateApplications = rateAppsSnap.docs
        .map((doc) => ({id: doc.id, applicationId: doc.id, ...doc.data()}))
        .sort((a, b) => timestampMillis(b.createdAt) - timestampMillis(a.createdAt))
        .map(jsonSafe);

    const providers = sortPublicProviders(
        providersSnap.docs.map((doc) => ({
          id: doc.id,
          providerId: doc.id,
          ...doc.data(),
        })),
    ).map(jsonSafe);

    const counts = {
      pendingProviderApplications: providerApplications
          .filter((item) => item.status === "pending_review").length,
      totalProviderApplications: providerApplications.length,
      newRateApplications: rateApplications
          .filter((item) => item.status === "new").length,
      activeRateApplications: rateApplications
          .filter((item) => ["new", "matching", "quoted"].includes(item.status)).length,
      boundRateApplications: rateApplications
          .filter((item) => item.status === "bound").length,
      totalRateApplications: rateApplications.length,
      activeProviders: providers.filter((item) => item.active !== false).length,
      totalProviders: providers.length,
    };

    return {
      providerApplications,
      rateApplications,
      providers,
      counts,
    };
  });

  const reviewInsuranceProviderApplication = command(async (request) => {
    const adminUid = requireAdministrator(request);
    await enforceUserRateLimit({
      db: db(),
      admin,
      request,
      scope: "administration",
    });

    const data = (request && request.data) || {};
    const applicationId = requiredEntityId(data, "applicationId");
    const decision = String(data.decision == null ? "" : data.decision)
        .trim()
        .toLowerCase();
    if (!["approved", "declined"].includes(decision)) {
      throw new HttpsError(
          "invalid-argument",
          "decision must be approved or declined.",
      );
    }
    const reviewNote = String(data.reviewNote == null ? "" : data.reviewNote)
        .trim()
        .slice(0, 1500);
    const featured = data.featured === true;

    const appRef = db().collection(PROVIDER_APPLICATIONS).doc(applicationId);
    const appSnap = await appRef.get();
    if (!appSnap.exists) {
      throw new HttpsError("not-found", "Insurance provider application not found.");
    }
    const appData = appSnap.data() || {};

    let providerId = optionalEntityId(data, "providerId") ||
      optionalEntityId(appData, "providerId");

    if (decision === "approved") {
      if (!providerId) {
        providerId = `ins_prov_${applicationId}`;
      }
      const normalizedProvider = normalizeInsuranceProviderRecord({
        ...appData,
        publicEmail: appData.email,
        publicPhone: appData.phone,
        featured,
        verified: true,
        active: true,
        adminNotes: reviewNote,
        internalContactEmail: appData.email,
        internalContactPhone: appData.phone,
      });

      const masterRef = db().collection(PROVIDERS).doc(providerId);
      const publicRef = db().collection(PUBLIC_PROVIDERS).doc(providerId);
      const existingMaster = await masterRef.get();

      await masterRef.set({
        schemaVersion: 1,
        providerId,
        sourceApplicationId: applicationId,
        ...normalizedProvider,
        updatedByUid: adminUid,
        updatedAt: serverTimestamp(),
        ...(existingMaster.exists ? {} : {createdAt: serverTimestamp()}),
      }, {merge: true});

      const publicRecord = toPublicInsuranceProvider({
        providerId,
        ...normalizedProvider,
      });
      await publicRef.set({
        schemaVersion: 1,
        ...publicRecord,
        updatedAt: serverTimestamp(),
        ...(existingMaster.exists ? {} : {publishedAt: serverTimestamp()}),
      }, {merge: true});
    }

    await appRef.set({
      status: decision,
      providerId: decision === "approved" ? providerId : (appData.providerId || null),
      reviewNote,
      reviewedByUid: adminUid,
      reviewedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }, {merge: true});

    if (appData.submitterUid) {
      await db()
          .collection("users")
          .doc(appData.submitterUid)
          .collection("notifications")
          .doc(`ins-prov-app-${applicationId}-${decision}`)
          .set({
            recipientUid: appData.submitterUid,
            type: "insurance_provider_application_reviewed",
            title: `Insurance Provider Application: ${decision.toUpperCase()}`,
            body: decision === "approved" ?
              `${appData.companyName || "Your organization"} is now approved and listed in the Pipe Buyer Commercial Insurance Directory.` :
              (reviewNote || `Your insurance provider application for ${appData.companyName || "your organization"} was updated (${decision}).`),
            applicationId,
            providerId: decision === "approved" ? providerId : null,
            status: decision,
            read: false,
            createdAt: serverTimestamp(),
          }, {merge: true});
    }

    await recordAuditEvent({
      actorUid: adminUid,
      action: "review_provider_application",
      targetType: "insurance_provider_application",
      targetId: applicationId,
      details: {
        decision,
        providerId: decision === "approved" ? providerId : null,
        featured,
        reviewNote,
      },
    });

    return {
      applicationId,
      status: decision,
      providerId: decision === "approved" ? providerId : null,
    };
  });

  const upsertInsuranceProvider = command(async (request) => {
    const adminUid = requireAdministrator(request);
    await enforceUserRateLimit({
      db: db(),
      admin,
      request,
      scope: "administration",
    });

    const data = (request && request.data) || {};
    const payload = (data.provider && typeof data.provider === "object") ?
      data.provider :
      data;
    const requestedId = optionalEntityId(data, "providerId") ||
      optionalEntityId(payload, "providerId");

    const normalized = normalizeInsuranceProviderRecord(payload);
    const masterCollection = db().collection(PROVIDERS);
    const masterRef = requestedId ?
      masterCollection.doc(requestedId) :
      masterCollection.doc();
    const providerId = masterRef.id;
    const existingSnap = await masterRef.get();

    await masterRef.set({
      schemaVersion: 1,
      providerId,
      ...normalized,
      updatedByUid: adminUid,
      updatedAt: serverTimestamp(),
      ...(existingSnap.exists ? {} : {createdAt: serverTimestamp()}),
    }, {merge: true});

    const publicRef = db().collection(PUBLIC_PROVIDERS).doc(providerId);
    if (normalized.active === true) {
      const publicProjection = toPublicInsuranceProvider({
        providerId,
        ...normalized,
      });
      await publicRef.set({
        schemaVersion: 1,
        ...publicProjection,
        updatedAt: serverTimestamp(),
        ...(existingSnap.exists ? {} : {publishedAt: serverTimestamp()}),
      }, {merge: true});
    } else {
      await publicRef.delete();
    }

    await recordAuditEvent({
      actorUid: adminUid,
      action: existingSnap.exists ? "update_provider" : "create_provider",
      targetType: "insurance_provider",
      targetId: providerId,
      details: {
        companyName: normalized.companyName,
        active: normalized.active,
        featured: normalized.featured,
      },
    });

    return {
      providerId,
      active: normalized.active,
      featured: normalized.featured,
    };
  });

  const updateInsuranceRateApplicationStatus = command(async (request) => {
    const adminUid = requireAdministrator(request);
    await enforceUserRateLimit({
      db: db(),
      admin,
      request,
      scope: "administration",
    });

    const data = (request && request.data) || {};
    const applicationId = requiredEntityId(data, "applicationId");
    const appRef = db().collection(RATE_APPLICATIONS).doc(applicationId);
    const appSnap = await appRef.get();
    if (!appSnap.exists) {
      throw new HttpsError("not-found", "Insurance rate application not found.");
    }
    const current = appSnap.data() || {};
    const nextStatus = assertRateApplicationStatusTransition(
        current.status || "new",
        data.status,
    );

    const matchedProviderIds = data.matchedProviderIds !== undefined ?
      normalizeStringArray(data.matchedProviderIds, 12, 180) :
      normalizeStringArray(current.matchedProviderIds, 12, 180);
    const matchedProviderNames = data.matchedProviderNames !== undefined ?
      normalizeStringArray(data.matchedProviderNames, 12, 200) :
      normalizeStringArray(current.matchedProviderNames, 12, 200);
    const brokerResponseNotes = data.brokerResponseNotes !== undefined ?
      String(data.brokerResponseNotes == null ? "" : data.brokerResponseNotes)
          .trim()
          .slice(0, 2500) :
      String(current.brokerResponseNotes || "");

    await appRef.set({
      status: nextStatus,
      matchedProviderIds,
      matchedProviderNames,
      brokerResponseNotes,
      updatedByUid: adminUid,
      updatedAt: serverTimestamp(),
    }, {merge: true});

    if (current.submitterUid) {
      await db()
          .collection("users")
          .doc(current.submitterUid)
          .collection("notifications")
          .doc(`ins-rate-${applicationId}-${nextStatus}`)
          .set({
            recipientUid: current.submitterUid,
            type: "insurance_rate_application_updated",
            title: `Insurance Rate Application: ${nextStatus.toUpperCase()}`,
            body: brokerResponseNotes ||
              `Your commercial insurance rate request for ${current.companyName || "your company"} is now ${nextStatus}.`,
            applicationId,
            status: nextStatus,
            read: false,
            createdAt: serverTimestamp(),
          }, {merge: true});
    }

    await recordAuditEvent({
      actorUid: adminUid,
      action: "update_rate_application_status",
      targetType: "insurance_rate_application",
      targetId: applicationId,
      details: {
        fromStatus: current.status || "new",
        toStatus: nextStatus,
        matchedProviderIds,
        matchedProviderNames,
      },
    });

    return {
      applicationId,
      status: nextStatus,
      matchedProviderIds,
      matchedProviderNames,
    };
  });

  return {
    listInsuranceProviders,
    submitInsuranceRateApplication,
    listMyInsuranceRateApplications,
    submitInsuranceProviderApplication,
    listAdminInsuranceDashboard,
    reviewInsuranceProviderApplication,
    upsertInsuranceProvider,
    updateInsuranceRateApplicationStatus,
  };
}

module.exports = {createInsuranceMarketplaceCommands};
