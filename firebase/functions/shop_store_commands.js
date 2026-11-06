"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  isAdministrator,
} = require("./administrator_authorization");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  AFFILIATE_PLATFORMS_DIRECTORY,
  DEFAULT_STORE_SETTINGS,
  SHOP_CATEGORIES,
  SHOP_PLACEMENTS,
  SHOP_PRODUCT_STATUSES,
  SHOP_SOURCE_TYPES,
  SHOP_STAFF_ROLES,
  VENDOR_APPLICATION_STATUSES,
  buildPublicShopProduct,
  cleanText,
  detectAffiliatePlatform,
  doesProductShipToCountry,
  extractAmazonAsin,
  extractHtmlProductMetadata,
  extractTitleFromAmazonSlug,
  extractTitleFromGenericSlug,
  inferBrandFromText,
  inferCategoryCodeFromText,
  inferEligibleCountries,
  isAmazonFullHostname,
  normalizeHiddenStarterIds,
  normalizeStoreSettings,
  parseAmazonAffiliateSubmission,
  parseSafeHttpsUrl,
  validateShopProductInput,
  validateVendorApplicationInput,
} = require("./shop_store_policy");

const SHOP_SETTINGS_COLLECTION = "shop_settings";
const PUBLIC_CONFIG_DOC = "public_config";
const ADMIN_CONFIG_DOC = "admin_config";
const SHOP_PRODUCTS_COLLECTION = "shop_products";
const SHOP_PUBLIC_PRODUCTS_COLLECTION = "shop_public_products";
const SHOP_VENDORS_COLLECTION = "shop_vendors";
const SHOP_APPLICATIONS_COLLECTION = "shop_vendor_applications";
const SHOP_CLICKS_COLLECTION = "shop_click_events";
const SHOP_AUDIT_COLLECTION = "shop_audit_events";
const SHOP_STAFF_COLLECTION = "shop_staff";

function normalizeAllowedPlatforms(value) {
  if (!Array.isArray(value) || value.length === 0) return ["all"];
  const cleaned = value
      .map((item) => cleanText(item, 48).toLowerCase())
      .filter((item) => item === "all" || SHOP_SOURCE_TYPES.has(item));
  if (cleaned.length === 0 || cleaned.includes("all")) return ["all"];
  return Array.from(new Set(cleaned));
}

function assertActorPlatformAllowed(actor, sourceType) {
  if (!actor || actor.isAdmin) return;
  const allowed = Array.isArray(actor.allowedPlatforms) ? actor.allowedPlatforms : ["all"];
  if (allowed.includes("all") || allowed.includes(sourceType)) return;
  throw new HttpsError(
      "permission-denied",
      `Your Store contributor permissions do not include "${sourceType}" links. Ask an Administrator to enable this platform.`,
  );
}

function jsonSafe(value) {
  if (value == null) return value;
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(jsonSafe);
  if (typeof value === "object") {
    return Object.fromEntries(
        Object.entries(value).map(([key, child]) => [key, jsonSafe(child)]),
    );
  }
  return value;
}

function wrapCommand(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (
        error instanceof AdministratorAuthorizationError ||
        error instanceof AccountSecurityError
      ) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Shop store command failed", error);
      throw new HttpsError("internal", "The PipeBuyer Store action could not be completed.");
    }
  };
}

function sanitizeDocId(rawId) {
  const cleaned = cleanText(rawId, 96)
      .toLowerCase()
      .replace(/[^a-z0-9_-]+/g, "-")
      .replace(/^-+|-+$/g, "");
  return cleaned.slice(0, 80);
}

async function readBodyUpToBytes(response, maxBytes = 262144) {
  if (!response) return "";
  if (response.body && typeof response.body.getReader === "function") {
    const reader = response.body.getReader();
    const decoder = new TextDecoder("utf-8", {fatal: false});
    let total = 0;
    let out = "";
    try {
      while (total < maxBytes) {
        const {done, value} = await reader.read();
        if (done || !value) break;
        const slice = total + value.byteLength > maxBytes ?
          value.subarray(0, maxBytes - total) :
          value;
        total += slice.byteLength;
        out += decoder.decode(slice, {stream: true});
      }
      out += decoder.decode();
    } finally {
      try {
        await reader.cancel();
      } catch {
        // Ignore stream cancel errors
      }
    }
    return out;
  }
  if (typeof response.text === "function") {
    const full = await response.text();
    return String(full || "").slice(0, maxBytes);
  }
  return "";
}

async function enrichParsedAffiliateWithLiveMetadata(parsed, fetchFn) {
  if (!parsed || !parsed.destinationUrl || typeof fetchFn !== "function") {
    return parsed;
  }
  const result = {...parsed};
  let currentUrl = parseSafeHttpsUrl(parsed.destinationUrl, "Affiliate link");
  let finalResponse = null;

  try {
    for (let hop = 0; hop < 6; hop++) {
      const res = await fetchFn(currentUrl.toString(), {
        method: "GET",
        redirect: "manual",
        signal: typeof AbortSignal !== "undefined" && AbortSignal.timeout ?
          AbortSignal.timeout(6500) :
          undefined,
        headers: {
          "user-agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
          "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          "accept-language": "en-US,en;q=0.9",
        },
      });
      if (res && res.status >= 300 && res.status < 400) {
        const rawLoc = res.headers && typeof res.headers.get === "function" ?
          res.headers.get("location") :
          "";
        if (!rawLoc) {
          finalResponse = res;
          break;
        }
        const resolvedCandidate = new URL(rawLoc, currentUrl.toString()).toString()
            .replace(/^http:\/\//i, "https://");
        currentUrl = parseSafeHttpsUrl(resolvedCandidate, "Redirect target URL");
        continue;
      }
      finalResponse = res;
      break;
    }

    const resolvedUrlStr = currentUrl.toString();
    const resolvedHost = currentUrl.hostname.toLowerCase();
    result.resolvedUrl = resolvedUrlStr;
    result.resolvedHost = resolvedHost;

    const resolvedAsin = result.asin || extractAmazonAsin(resolvedUrlStr);
    if (resolvedAsin && !result.asin) {
      result.asin = resolvedAsin;
    }

    const resolvedDetected = detectAffiliatePlatform(resolvedHost);
    const resolvedCountries = inferEligibleCountries(
        resolvedHost,
        resolvedDetected.sourceType,
        resolvedAsin,
    );
    if (result.isShortLink && resolvedHost) {
      result.eligibleCountries = resolvedCountries;
      if (
        result.sourceType === "affiliate_network" &&
        resolvedDetected.vendorName &&
        resolvedDetected.vendorName !== "Amazon"
      ) {
        result.suggestedVendorName = resolvedDetected.vendorName;
      }
    }

    let htmlMeta = {title: "", imageUrl: "", brand: "", priceDisplay: ""};
    if (finalResponse && finalResponse.status >= 200 && finalResponse.status < 400) {
      const contentType = finalResponse.headers && typeof finalResponse.headers.get === "function" ?
        String(finalResponse.headers.get("content-type") || "").toLowerCase() :
        "text/html";
      if (!contentType || contentType.includes("html") || contentType.includes("xml")) {
        const html = await readBodyUpToBytes(finalResponse, 262144);
        htmlMeta = extractHtmlProductMetadata(html, resolvedUrlStr);
      }
    }

    const resolvedSlugTitle = isAmazonFullHostname(resolvedHost) ?
      extractTitleFromAmazonSlug(currentUrl) :
      extractTitleFromGenericSlug(currentUrl);
    const searchQueryTitle = cleanText(
        currentUrl.searchParams.get("k") || currentUrl.searchParams.get("q") || "",
        160,
    );

    if (!result.imageUrl && htmlMeta.imageUrl) {
      result.imageUrl = htmlMeta.imageUrl;
    }
    if (!result.suggestedTitle) {
      result.suggestedTitle = htmlMeta.title || resolvedSlugTitle || searchQueryTitle;
    }
    if (!result.suggestedBrand) {
      result.suggestedBrand =
        htmlMeta.brand || inferBrandFromText(`${result.suggestedTitle} ${resolvedUrlStr}`);
    }
    if (result.suggestedTitle) {
      result.suggestedCategoryCode = inferCategoryCodeFromText(
          `${result.suggestedTitle} ${result.suggestedBrand}`,
      );
    }
    if (htmlMeta.priceDisplay) {
      result.suggestedPriceDisplay = htmlMeta.priceDisplay;
    }
    result.metadataFetched = Boolean(result.imageUrl || htmlMeta.title);
  } catch {
    result.metadataFetched = false;
  }

  // Amazon CDN ASIN image fallback when HTML is bot-gated or shortlink resolved an ASIN
  if (!result.imageUrl && result.asin && typeof fetchFn === "function") {
    const cdnImgUrl = `https://m.media-amazon.com/images/P/${result.asin}.01._SCLZZZZZZZ_SX500_.jpg`;
    try {
      const imgRes = await fetchFn(cdnImgUrl, {
        method: "GET",
        signal: typeof AbortSignal !== "undefined" && AbortSignal.timeout ?
          AbortSignal.timeout(4000) :
          undefined,
      });
      if (imgRes && imgRes.status === 200) {
        const cType = imgRes.headers && typeof imgRes.headers.get === "function" ?
          String(imgRes.headers.get("content-type") || "").toLowerCase() :
          "";
        const buf = typeof imgRes.arrayBuffer === "function" ?
          await imgRes.arrayBuffer() :
          null;
        const size = buf ? buf.byteLength : 0;
        if (cType.includes("jpeg") && size > 800) {
          result.imageUrl = cdnImgUrl;
          result.metadataFetched = true;
        }
      }
    } catch {
      // Ignore optional CDN image fallback failure
    }
  }

  return result;
}

function createShopStoreCommands(admin, {notifyAdministrators, fetchImpl} = {}) {
  const db = () => admin.firestore();
  const auth = () => admin.auth();
  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp();
  const increment = (n) => admin.firestore.FieldValue.increment(n);
  const effectiveFetch = fetchImpl || (typeof globalThis.fetch === "function" ? globalThis.fetch.bind(globalThis) : null);

  async function resolveShopActor(request) {
    if (!request || !request.auth || !request.auth.uid) {
      return {
        authorized: false,
        reason: "signed_out",
        uid: null,
        role: null,
        isAdmin: false,
        allowedPlatforms: [],
      };
    }

    const uid = request.auth.uid;
    const token = request.auth.token || {};
    const restrictions = Array.isArray(token.restrictions) ? token.restrictions : [];
    if (token.restricted === true || restrictions.includes("restrict_store_products")) {
      return {
        authorized: false,
        reason: "restricted",
        uid,
        role: null,
        isAdmin: false,
        allowedPlatforms: [],
      };
    }

    const hasAdminClaims = token.admin === true && token.role === "administrator";

    if (isAdministrator(request)) {
      return {
        authorized: true,
        reason: "authorized",
        uid,
        role: "administrator",
        isAdmin: true,
        allowedPlatforms: ["all"],
      };
    }

    const rosterSnap = await db().collection(SHOP_STAFF_COLLECTION).doc(uid).get();
    const rosterData = rosterSnap.exists ? (rosterSnap.data() || {}) : {};
    const rosterRole = cleanText(rosterData.role, 40).toLowerCase();
    const claimRole = cleanText(token.shopRole, 40).toLowerCase();

    if (rosterSnap.exists && rosterData.active === true && SHOP_STAFF_ROLES.has(rosterRole)) {
      if (rosterData.restricted === true) {
        return {
          authorized: false,
          reason: "restricted",
          uid,
          role: null,
          isAdmin: false,
          allowedPlatforms: [],
        };
      }
      if (token.email_verified !== true) {
        return {
          authorized: false,
          reason: "verified_email_required",
          uid,
          role: rosterRole,
          isAdmin: false,
          allowedPlatforms: [],
        };
      }
      return {
        authorized: true,
        reason: "authorized",
        uid,
        role: rosterRole,
        isAdmin: false,
        allowedPlatforms: normalizeAllowedPlatforms(rosterData.allowedPlatforms),
      };
    }

    if (hasAdminClaims) {
      return {
        authorized: false,
        reason: "mfa_required",
        uid,
        role: "administrator",
        isAdmin: false,
        allowedPlatforms: [],
      };
    }

    if (SHOP_STAFF_ROLES.has(claimRole)) {
      if (token.email_verified !== true) {
        return {
          authorized: false,
          reason: "verified_email_required",
          uid,
          role: claimRole,
          isAdmin: false,
          allowedPlatforms: [],
        };
      }
      return {
        authorized: false,
        reason: "roster_inactive",
        uid,
        role: null,
        isAdmin: false,
        allowedPlatforms: [],
      };
    }

    return {
      authorized: false,
      reason: "role_missing",
      uid,
      role: null,
      isAdmin: false,
      allowedPlatforms: [],
    };
  }

  async function requireShopActor(
      request,
      allowedRoles = ["affiliate_contributor", "catalog_editor", "store_manager", "administrator"],
  ) {
    if (!request || !request.auth) {
      throw new HttpsError(
          "unauthenticated",
          "Sign in before using PipeBuyer Store management tools.",
      );
    }
    const actor = await resolveShopActor(request);
    if (!actor.authorized || !allowedRoles.includes(actor.role)) {
      if (actor.reason === "restricted") {
        throw new HttpsError(
            "permission-denied",
            "Your account has been restricted from adding or editing Store products by an Administrator.",
        );
      }
      if (actor.reason === "mfa_required") {
        throw new HttpsError(
            "permission-denied",
            "Multi-factor authentication is required to use Administrator Store permissions.",
        );
      }
      if (actor.reason === "verified_email_required") {
        throw new HttpsError(
            "permission-denied",
            "Verify your account email before using Store management tools.",
        );
      }
      if (allowedRoles.length === 1 && allowedRoles[0] === "administrator") {
        throw new HttpsError(
            "permission-denied",
            "Only a PipeBuyer Administrator can change Store-wide affiliate tags or staff roles.",
        );
      }
      throw new HttpsError(
          "permission-denied",
          "Store product management requires an approved Administrator, Store Manager, Catalog Editor, or Affiliate Contributor permission.",
      );
    }
    return actor;
  }

  async function loadEffectiveSettings() {
    const snap = await db().collection(SHOP_SETTINGS_COLLECTION).doc(ADMIN_CONFIG_DOC).get();
    if (!snap.exists) {
      return {...DEFAULT_STORE_SETTINGS};
    }
    return normalizeStoreSettings(snap.data(), DEFAULT_STORE_SETTINGS);
  }

  async function persistHiddenStarterIds(nextHiddenIds, actorUid) {
    const cleaned = normalizeHiddenStarterIds(nextHiddenIds);
    const batch = db().batch();
    batch.set(
        db().collection(SHOP_SETTINGS_COLLECTION).doc(ADMIN_CONFIG_DOC),
        {
          hiddenStarterIds: cleaned,
          updatedByUid: actorUid,
          updatedAt: serverTimestamp(),
        },
        {merge: true},
    );
    batch.set(
        db().collection(SHOP_SETTINGS_COLLECTION).doc(PUBLIC_CONFIG_DOC),
        {
          hiddenStarterIds: cleaned,
          updatedAt: serverTimestamp(),
        },
        {merge: true},
    );
    await batch.commit();
    return cleaned;
  }

  async function recordAudit(actor, action, targetId, details = {}) {
    const actorUid = typeof actor === "string" ? actor : (actor && actor.uid) || null;
    const actorRole = typeof actor === "object" && actor ? actor.role || null : "administrator";
    await db().collection(SHOP_AUDIT_COLLECTION).add({
      schemaVersion: 2,
      actorUid,
      actorRole,
      action,
      targetId: targetId || null,
      details,
      createdAt: serverTimestamp(),
    });
  }

  const getShopSession = wrapCommand(async (request) => {
    const actor = await resolveShopActor(request);
    return {
      authorized: actor.authorized,
      reason: actor.reason,
      uid: actor.uid,
      role: actor.role,
      isAdmin: actor.isAdmin,
      allowedPlatforms: actor.allowedPlatforms || [],
      canManageCatalog: actor.authorized &&
        ["affiliate_contributor", "catalog_editor", "store_manager", "administrator"].includes(actor.role),
      canReviewVendors: actor.authorized &&
        ["store_manager", "administrator"].includes(actor.role),
      canManageSettingsAndRoles: actor.authorized && actor.role === "administrator",
      affiliatePlatforms: AFFILIATE_PLATFORMS_DIRECTORY,
    };
  });

  const parseShopAffiliateLink = wrapCommand(async (request) => {
    await requireShopActor(
        request,
        ["affiliate_contributor", "catalog_editor", "store_manager", "administrator"],
    );
    const settings = await loadEffectiveSettings();
    const data = (request && request.data) || {};
    const rawInput = data.rawInput || "";
    const parsed = parseAmazonAffiliateSubmission(rawInput, settings);
    if (data.fetchMetadata === true && effectiveFetch) {
      if (typeof db().runTransaction === "function") {
        await enforceUserRateLimit({db: db(), admin, request, scope: "search"});
      }
      return enrichParsedAffiliateWithLiveMetadata(parsed, effectiveFetch);
    }
    return parsed;
  });

  const listShopStoreCatalog = wrapCommand(async (request) => {
    const data = (request && request.data) || {};
    const categoryFilter = cleanText(data.categoryCode, 64);
    const subcategoryFilter = cleanText(data.subcategory, 120).toLowerCase();
    const sourceFilter = cleanText(data.sourceType, 40);
    const brandFilter = cleanText(data.brand, 80).toLowerCase();
    const countryFilter = cleanText(data.countryCode, 24).toUpperCase();
    const queryText = cleanText(data.query, 120).toLowerCase();

    const [publicConfigSnap, productsSnap, allProductsSnap, vendorsSnap] = await Promise.all([
      db().collection(SHOP_SETTINGS_COLLECTION).doc(PUBLIC_CONFIG_DOC).get(),
      db().collection(SHOP_PUBLIC_PRODUCTS_COLLECTION).limit(1500).get(),
      db().collection(SHOP_PRODUCTS_COLLECTION).limit(1500).get(),
      db().collection(SHOP_VENDORS_COLLECTION).where("active", "==", true).limit(150).get(),
    ]);

    const settings = publicConfigSnap.exists ?
      normalizeStoreSettings(publicConfigSnap.data(), DEFAULT_STORE_SETTINGS) :
      {...DEFAULT_STORE_SETTINGS};

    const suppressedSet = new Set(settings.hiddenStarterIds || []);
    for (const doc of allProductsSnap.docs) {
      const pData = doc.data() || {};
      if (pData.status && pData.status !== "active") {
        suppressedSet.add(doc.id);
      }
    }

    let products = productsSnap.docs
        .map((doc) => ({
          id: doc.id,
          ...jsonSafe(doc.data()),
        }))
        .filter((item) => !suppressedSet.has(item.id));

    if (countryFilter && countryFilter !== "ALL") {
      products = products.filter((item) =>
        doesProductShipToCountry(item.eligibleCountries, countryFilter),
      );
    }
    if (categoryFilter) {
      products = products.filter((item) => item.categoryCode === categoryFilter);
    }
    if (subcategoryFilter) {
      products = products.filter(
          (item) => String(item.subcategory || "").toLowerCase() === subcategoryFilter,
      );
    }
    if (sourceFilter && SHOP_SOURCE_TYPES.has(sourceFilter)) {
      products = products.filter((item) => item.sourceType === sourceFilter);
    }
    if (brandFilter) {
      products = products.filter(
          (item) => String(item.brand || "").toLowerCase() === brandFilter,
      );
    }
    if (queryText) {
      const terms = queryText.split(/\s+/).filter(Boolean);
      products = products.filter((item) => {
        const haystack = [
          item.title,
          item.brand,
          item.vendorName,
          item.categoryLabel,
          item.subcategory,
          item.description,
          ...(Array.isArray(item.tags) ? item.tags : []),
        ]
            .filter(Boolean)
            .join(" ")
            .toLowerCase();
        return terms.every((term) => haystack.includes(term));
      });
    }

    products.sort((a, b) => {
      if (Boolean(a.featured) !== Boolean(b.featured)) {
        return a.featured ? -1 : 1;
      }
      const rankDiff = Number(a.priorityRank ?? 100) - Number(b.priorityRank ?? 100);
      if (rankDiff !== 0) return rankDiff;
      return String(a.title || "").localeCompare(String(b.title || ""));
    });

    const vendors = vendorsSnap.docs.map((doc) => ({
      id: doc.id,
      ...jsonSafe(doc.data()),
    }));

    return {
      settings: {
        storeEnabled: settings.storeEnabled,
        vendorApplicationsOpen: settings.vendorApplicationsOpen,
        amazonAssociateTagUs: settings.amazonAssociateTagUs,
        amazonAssociateTagCa: settings.amazonAssociateTagCa,
        amazonAssociateTagSg: settings.amazonAssociateTagSg,
        aliexpressTrackingId: settings.aliexpressTrackingId,
        shopeeAffiliateSubId: settings.shopeeAffiliateSubId,
        lazadaAffiliateSubId: settings.lazadaAffiliateSubId,
        involveAsiaSubId: settings.involveAsiaSubId,
        ebayCampaignId: settings.ebayCampaignId,
        disclosureText: settings.disclosureText,
        priceDisclaimerText: settings.priceDisclaimerText,
        hiddenStarterIds: settings.hiddenStarterIds || [],
      },
      suppressedProductIds: Array.from(suppressedSet),
      categories: SHOP_CATEGORIES,
      affiliatePlatforms: AFFILIATE_PLATFORMS_DIRECTORY,
      products,
      vendors,
    };
  });

  const recordShopAffiliateClick = wrapCommand(async (request) => {
    const data = (request && request.data) || {};
    const productId = sanitizeDocId(data.productId);
    if (!productId) {
      throw new HttpsError("invalid-argument", "A valid product identifier is required.");
    }
    if (request && request.auth && request.auth.uid) {
      await enforceUserRateLimit({db: db(), admin, request, scope: "search"});
    }

    const placementRaw = cleanText(data.placement, 40) || "store_grid";
    const placement = SHOP_PLACEMENTS.has(placementRaw) ? placementRaw : "store_grid";
    const sourceTypeRaw = cleanText(data.sourceType, 40) || "amazon_affiliate";
    const sourceType = SHOP_SOURCE_TYPES.has(sourceTypeRaw) ? sourceTypeRaw : "amazon_affiliate";
    const categoryCode = cleanText(data.categoryCode, 64);
    const brand = cleanText(data.brand, 80);
    const regionCode = cleanText(data.regionCode, 8).toUpperCase() || "US";
    const destinationHost = cleanText(data.destinationHost, 120).toLowerCase();
    const actorUid = (request && request.auth && request.auth.uid) || null;

    const clickPayload = {
      schemaVersion: 1,
      productId,
      categoryCode,
      sourceType,
      brand,
      placement,
      regionCode,
      destinationHost,
      actorUid,
      createdAt: serverTimestamp(),
    };

    const productRef = db().collection(SHOP_PRODUCTS_COLLECTION).doc(productId);
    const publicRef = db().collection(SHOP_PUBLIC_PRODUCTS_COLLECTION).doc(productId);
    const [productSnap, publicSnap] = await Promise.all([
      productRef.get(),
      publicRef.get(),
    ]);

    const batch = db().batch();
    batch.set(db().collection(SHOP_CLICKS_COLLECTION).doc(), clickPayload);
    if (productSnap.exists) {
      batch.update(productRef, {
        clickCount: increment(1),
        lastClickedAt: serverTimestamp(),
      });
    }
    if (publicSnap.exists) {
      batch.update(publicRef, {
        clickCount: increment(1),
        lastClickedAt: serverTimestamp(),
      });
    }
    await batch.commit();

    return {recorded: true};
  });

  const toggleSavedShopProduct = wrapCommand(async (request) => {
    const uid = requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
    await enforceUserRateLimit({db: db(), admin, request, scope: "account"});
    const data = (request && request.data) || {};
    const productId = sanitizeDocId(data.productId);
    if (!productId) {
      throw new HttpsError("invalid-argument", "A valid product identifier is required.");
    }
    const saved = Boolean(data.saved);
    const ref = db()
        .collection("users")
        .doc(uid)
        .collection("saved_shop_items")
        .doc(productId);

    if (saved) {
      await ref.set({
        productId,
        title: cleanText(data.title, 160),
        categoryCode: cleanText(data.categoryCode, 64),
        brand: cleanText(data.brand, 80),
        savedAt: serverTimestamp(),
      }, {merge: true});
    } else {
      await ref.delete();
    }
    return {productId, saved};
  });

  const submitShopVendorApplication = wrapCommand(async (request) => {
    const uid = requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
    await enforceUserRateLimit({db: db(), admin, request, scope: "account"});

    const settings = await loadEffectiveSettings();
    if (!settings.vendorApplicationsOpen) {
      throw new HttpsError(
          "failed-precondition",
          "Store vendor & distributor applications are temporarily paused.",
      );
    }

    const validated = validateVendorApplicationInput(
        (request && request.data) || {},
        uid,
    );

    const docRef = db().collection(SHOP_APPLICATIONS_COLLECTION).doc();
    await docRef.set({
      ...validated,
      schemaVersion: 1,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    if (typeof notifyAdministrators === "function") {
      try {
        await notifyAdministrators({
          notificationId: `shop_vendor_app_${docRef.id}`,
          type: "shop_vendor_application",
          title: "New Store Vendor / Brand Application",
          body: `${validated.companyName} (${validated.partnershipTrack}) applied to list in the PipeBuyer Store.`,
          applicationId: docRef.id,
          read: false,
        });
      } catch (notifyErr) {
        console.warn("Admin notification for shop vendor application failed", notifyErr);
      }
    }

    return {
      applicationId: docRef.id,
      status: "pending",
    };
  });

  const getShopAdminDashboard = wrapCommand(async (request) => {
    const actor = await requireShopActor(
        request,
        ["affiliate_contributor", "catalog_editor", "store_manager", "administrator"],
    );
    const canSeeVendorsAndStaff = ["store_manager", "administrator"].includes(actor.role);

    const [settings, productsSnap, appsSnap, vendorsSnap, clicksSnap, staffSnap] =
      await Promise.all([
        loadEffectiveSettings(),
        db().collection(SHOP_PRODUCTS_COLLECTION).limit(1500).get(),
        canSeeVendorsAndStaff ?
          db().collection(SHOP_APPLICATIONS_COLLECTION).orderBy("createdAt", "desc").limit(150).get() :
          Promise.resolve({docs: []}),
        db().collection(SHOP_VENDORS_COLLECTION).limit(150).get(),
        db().collection(SHOP_CLICKS_COLLECTION).orderBy("createdAt", "desc").limit(500).get(),
        canSeeVendorsAndStaff ?
          db().collection(SHOP_STAFF_COLLECTION).limit(150).get() :
          Promise.resolve({docs: [], size: 0}),
      ]);

    const products = productsSnap.docs.map((doc) => ({
      id: doc.id,
      ...jsonSafe(doc.data()),
    }));
    const applications = appsSnap.docs.map((doc) => ({
      id: doc.id,
      ...jsonSafe(doc.data()),
    }));
    const vendors = vendorsSnap.docs.map((doc) => ({
      id: doc.id,
      ...jsonSafe(doc.data()),
    }));
    const staff = staffSnap.docs.map((doc) => ({
      uid: doc.id,
      ...jsonSafe(doc.data()),
    }));

    const clicksBySource = {};
    const clicksByPlacement = {};
    const clicksByCategory = {};
    for (const doc of clicksSnap.docs) {
      const event = doc.data() || {};
      const src = String(event.sourceType || "amazon_affiliate");
      const plc = String(event.placement || "store_grid");
      const cat = String(event.categoryCode || "uncategorized");
      clicksBySource[src] = (clicksBySource[src] || 0) + 1;
      clicksByPlacement[plc] = (clicksByPlacement[plc] || 0) + 1;
      clicksByCategory[cat] = (clicksByCategory[cat] || 0) + 1;
    }

    const totalProductClicks = products.reduce(
        (sum, item) => sum + Number(item.clickCount || 0),
        0,
    );

    return {
      actor: {
        uid: actor.uid,
        role: actor.role,
        isAdmin: actor.isAdmin,
        allowedPlatforms: actor.allowedPlatforms || ["all"],
      },
      settings,
      categories: SHOP_CATEGORIES,
      affiliatePlatforms: AFFILIATE_PLATFORMS_DIRECTORY,
      products,
      applications,
      vendors,
      staff,
      analytics: {
        totalRecordedClicks: Math.max(totalProductClicks, clicksSnap.size),
        recentSampledClicks: clicksSnap.size,
        activeProductCount: products.filter((p) => p.status === "active").length,
        pendingApplicationCount: applications.filter((a) => a.status === "pending").length,
        approvedVendorCount: vendors.filter((v) => v.active === true).length,
        activeStaffCount: staff.filter((s) => s.active === true).length,
        clicksBySource,
        clicksByPlacement,
        clicksByCategory,
      },
    };
  });

  const updateShopStoreSettings = wrapCommand(async (request) => {
    const actor = await requireShopActor(request, ["administrator"]);
    const existing = await loadEffectiveSettings();
    const updated = normalizeStoreSettings((request && request.data) || {}, existing);

    const batch = db().batch();
    batch.set(
        db().collection(SHOP_SETTINGS_COLLECTION).doc(ADMIN_CONFIG_DOC),
        {
          ...updated,
          updatedByUid: actor.uid,
          updatedAt: serverTimestamp(),
        },
        {merge: true},
    );
    batch.set(
        db().collection(SHOP_SETTINGS_COLLECTION).doc(PUBLIC_CONFIG_DOC),
        {
          storeEnabled: updated.storeEnabled,
          vendorApplicationsOpen: updated.vendorApplicationsOpen,
          amazonAssociateTagUs: updated.amazonAssociateTagUs,
          amazonAssociateTagCa: updated.amazonAssociateTagCa,
          amazonAssociateTagUk: updated.amazonAssociateTagUk,
          amazonAssociateTagAu: updated.amazonAssociateTagAu,
          amazonAssociateTagSg: updated.amazonAssociateTagSg,
          aliexpressTrackingId: updated.aliexpressTrackingId,
          shopeeAffiliateSubId: updated.shopeeAffiliateSubId,
          lazadaAffiliateSubId: updated.lazadaAffiliateSubId,
          involveAsiaSubId: updated.involveAsiaSubId,
          ebayCampaignId: updated.ebayCampaignId,
          skimlinksPublisherId: updated.skimlinksPublisherId,
          forceOverrideAmazonTag: updated.forceOverrideAmazonTag,
          defaultUtmSource: updated.defaultUtmSource,
          defaultUtmMedium: updated.defaultUtmMedium,
          disclosureText: updated.disclosureText,
          priceDisclaimerText: updated.priceDisclaimerText,
          hiddenStarterIds: updated.hiddenStarterIds || [],
          updatedAt: serverTimestamp(),
        },
        {merge: true},
    );
    await batch.commit();

    // Re-project active public products in safe chunks (<500 ops/batch) so updated Associate tags apply immediately across 1,000+ items
    const activeSnap = await db()
        .collection(SHOP_PRODUCTS_COLLECTION)
        .where("status", "==", "active")
        .limit(1500)
        .get();
    if (!activeSnap.empty) {
      const chunkSize = 400;
      for (let i = 0; i < activeSnap.docs.length; i += chunkSize) {
        const chunk = activeSnap.docs.slice(i, i + chunkSize);
        const syncBatch = db().batch();
        for (const doc of chunk) {
          const projected = buildPublicShopProduct(doc.id, doc.data(), updated);
          if (projected) {
            syncBatch.set(
                db().collection(SHOP_PUBLIC_PRODUCTS_COLLECTION).doc(doc.id),
                {
                  ...projected,
                  updatedAt: serverTimestamp(),
                },
                {merge: true},
            );
          }
        }
        await syncBatch.commit();
      }
    }

    await recordAudit(actor, "update_store_settings", ADMIN_CONFIG_DOC, {
      amazonAssociateTagUs: updated.amazonAssociateTagUs,
      amazonAssociateTagCa: updated.amazonAssociateTagCa,
      forceOverrideAmazonTag: updated.forceOverrideAmazonTag,
      storeEnabled: updated.storeEnabled,
      vendorApplicationsOpen: updated.vendorApplicationsOpen,
    });

    return {settings: updated};
  });

  const upsertShopProduct = wrapCommand(async (request) => {
    const actor = await requireShopActor(
        request,
        ["affiliate_contributor", "catalog_editor", "store_manager", "administrator"],
    );
    const payload = (request && request.data) || {};
    const requestedId = sanitizeDocId(payload.id || payload.productId);
    const productRef = requestedId ?
      db().collection(SHOP_PRODUCTS_COLLECTION).doc(requestedId) :
      db().collection(SHOP_PRODUCTS_COLLECTION).doc();

    const [existingSnap, settings] = await Promise.all([
      productRef.get(),
      loadEffectiveSettings(),
    ]);

    const existingData = existingSnap.exists ? existingSnap.data() : null;
    if (
      existingData &&
      actor.role === "affiliate_contributor" &&
      existingData.createdByUid &&
      existingData.createdByUid !== actor.uid
    ) {
      throw new HttpsError(
          "permission-denied",
          "Affiliate Contributors can edit products they submitted; ask a Catalog Editor or Admin to edit other listings.",
      );
    }
    const normalized = validateShopProductInput(payload, existingData);
    assertActorPlatformAllowed(actor, normalized.sourceType);
    const clickCount = existingData ? Number(existingData.clickCount || 0) : 0;

    const recordToSave = {
      ...normalized,
      clickCount,
      updatedByUid: actor.uid,
      updatedAt: serverTimestamp(),
      ...(existingSnap.exists ? {} : {
        createdByUid: actor.uid,
        createdAt: serverTimestamp(),
      }),
    };

    const publicRef = db().collection(SHOP_PUBLIC_PRODUCTS_COLLECTION).doc(productRef.id);
    const projected = buildPublicShopProduct(
        productRef.id,
        {...recordToSave, clickCount},
        settings,
    );

    const batch = db().batch();
    batch.set(productRef, recordToSave, {merge: true});
    if (projected) {
      batch.set(publicRef, {
        ...projected,
        updatedAt: serverTimestamp(),
      });
    } else {
      batch.delete(publicRef);
    }
    await batch.commit();

    // If re-adding or activating an item that was previously in hiddenStarterIds, unhide it
    if (
      normalized.status === "active" &&
      Array.isArray(settings.hiddenStarterIds) &&
      settings.hiddenStarterIds.includes(productRef.id)
    ) {
      const nextHidden = settings.hiddenStarterIds.filter((id) => id !== productRef.id);
      await persistHiddenStarterIds(nextHidden, actor.uid);
    }

    await recordAudit(
        actor,
        existingSnap.exists ? "update_product" : "create_product",
        productRef.id,
        {
          title: normalized.title,
          sourceType: normalized.sourceType,
          status: normalized.status,
          categoryCode: normalized.categoryCode,
          asin: normalized.asin || "",
        },
    );

    return {
      productId: productRef.id,
      product: {
        id: productRef.id,
        ...normalized,
        clickCount,
      },
    };
  });

  const bulkUpsertShopProducts = wrapCommand(async (request) => {
    const actor = await requireShopActor(
        request,
        ["affiliate_contributor", "catalog_editor", "store_manager", "administrator"],
    );
    const payload = (request && request.data) || {};
    const rawItems = Array.isArray(payload.items) ? payload.items : [];
    if (rawItems.length === 0) {
      throw new HttpsError("invalid-argument", "Provide at least one spreadsheet item row to import.");
    }
    if (rawItems.length > 250) {
      throw new HttpsError(
          "invalid-argument",
          "Import at most 250 items per batch call (the Admin importer chunks larger spreadsheets automatically).",
      );
    }

    const [settings, existingSnap] = await Promise.all([
      loadEffectiveSettings(),
      db().collection(SHOP_PRODUCTS_COLLECTION).limit(1500).get(),
    ]);
    const existingById = new Map(
        existingSnap.docs.map((doc) => [doc.id, doc.data() || {}]),
    );

    let importedCount = 0;
    let skippedBlankCount = 0;
    const errors = [];
    const preparedWrites = [];
    const activatedIds = new Set();

    for (let index = 0; index < rawItems.length; index++) {
      const row = rawItems[index];
      if (!row || typeof row !== "object") continue;

      const rawLink = cleanText(
          row.rawAffiliateInput || row.amazonAffiliateLink || row.destinationUrl || row.asin,
          2000,
      );
      if (!rawLink) {
        skippedBlankCount += 1;
        continue;
      }

      try {
        const requestedId = sanitizeDocId(row.id || row.productId || row.itemId || row.title);
        const productRef = requestedId ?
          db().collection(SHOP_PRODUCTS_COLLECTION).doc(requestedId) :
          db().collection(SHOP_PRODUCTS_COLLECTION).doc();
        const existingData = existingById.get(productRef.id) || null;
        const normalized = validateShopProductInput(
            {
              ...row,
              rawAffiliateInput: row.rawAffiliateInput || row.amazonAffiliateLink || row.destinationUrl || "",
              destinationUrl: row.destinationUrl || row.amazonAffiliateLink || "",
            },
            existingData,
        );
        assertActorPlatformAllowed(actor, normalized.sourceType);
        const clickCount = existingData ? Number(existingData.clickCount || 0) : 0;
        const recordToSave = {
          ...normalized,
          clickCount,
          updatedByUid: actor.uid,
          updatedAt: serverTimestamp(),
          ...(existingData ? {} : {
            createdByUid: actor.uid,
            createdAt: serverTimestamp(),
          }),
        };
        const projected = buildPublicShopProduct(
            productRef.id,
            {...recordToSave, clickCount},
            settings,
        );
        preparedWrites.push({
          id: productRef.id,
          productRef,
          publicRef: db().collection(SHOP_PUBLIC_PRODUCTS_COLLECTION).doc(productRef.id),
          recordToSave,
          projected,
        });
        if (normalized.status === "active") {
          activatedIds.add(productRef.id);
        }
        importedCount += 1;
      } catch (err) {
        if (errors.length < 25) {
          errors.push({
            rowNumber: index + 1,
            title: cleanText(row.title, 80) || `Row ${index + 1}`,
            message: err && err.message ? String(err.message) : "Invalid product row.",
          });
        }
      }
    }

    // Commit up to 200 items (400 ops) per Firestore WriteBatch
    const batchItemLimit = 200;
    for (let offset = 0; offset < preparedWrites.length; offset += batchItemLimit) {
      const slice = preparedWrites.slice(offset, offset + batchItemLimit);
      const batch = db().batch();
      for (const entry of slice) {
        batch.set(entry.productRef, entry.recordToSave, {merge: true});
        if (entry.projected) {
          batch.set(entry.publicRef, {
            ...entry.projected,
            updatedAt: serverTimestamp(),
          });
        } else {
          batch.delete(entry.publicRef);
        }
      }
      await batch.commit();
    }

    if (
      activatedIds.size > 0 &&
      Array.isArray(settings.hiddenStarterIds) &&
      settings.hiddenStarterIds.some((id) => activatedIds.has(id))
    ) {
      const nextHidden = settings.hiddenStarterIds.filter((id) => !activatedIds.has(id));
      await persistHiddenStarterIds(nextHidden, actor.uid);
    }

    if (importedCount > 0) {
      await recordAudit(actor, "bulk_upsert_products", "spreadsheet_import", {
        importedCount,
        skippedBlankCount,
        failedCount: errors.length,
      });
    }

    return {
      importedCount,
      skippedBlankCount,
      failedCount: errors.length,
      errors,
    };
  });

  const setShopProductVisibility = wrapCommand(async (request) => {
    const actor = await requireShopActor(
        request,
        ["catalog_editor", "store_manager", "administrator"],
    );
    const payload = (request && request.data) || {};
    const productId = sanitizeDocId(payload.productId);
    if (!productId) {
      throw new HttpsError("invalid-argument", "A valid productId is required.");
    }

    const productRef = db().collection(SHOP_PRODUCTS_COLLECTION).doc(productId);
    const [existingSnap, settings] = await Promise.all([
      productRef.get(),
      loadEffectiveSettings(),
    ]);

    if (!existingSnap.exists) {
      if (payload.starterProduct && typeof payload.starterProduct === "object") {
        const normalizedStarter = validateShopProductInput({
          ...payload.starterProduct,
          status: payload.status || "active",
          ...(typeof payload.featured === "boolean" ? {featured: payload.featured} : {}),
        });
        const publicRef = db().collection(SHOP_PUBLIC_PRODUCTS_COLLECTION).doc(productId);
        const projected = buildPublicShopProduct(productId, normalizedStarter, settings);
        const batch = db().batch();
        batch.set(productRef, {
          ...normalizedStarter,
          clickCount: 0,
          createdByUid: actor.uid,
          createdAt: serverTimestamp(),
          updatedByUid: actor.uid,
          updatedAt: serverTimestamp(),
        }, {merge: true});
        if (projected) {
          batch.set(publicRef, {...projected, updatedAt: serverTimestamp()});
        } else {
          batch.delete(publicRef);
        }
        await batch.commit();
        await recordAudit(actor, "set_product_visibility", productId, {
          status: normalizedStarter.status,
          featured: normalizedStarter.featured,
        });
        return {
          productId,
          status: normalizedStarter.status,
          featured: normalizedStarter.featured,
        };
      }
      throw new HttpsError("not-found", "Store product was not found.");
    }

    const current = existingSnap.data() || {};
    const nextStatus = payload.status !== undefined ?
      cleanText(payload.status, 24) :
      String(current.status || "active");
    if (!SHOP_PRODUCT_STATUSES.has(nextStatus)) {
      throw new HttpsError("invalid-argument", "Invalid product status.");
    }
    const nextFeatured = typeof payload.featured === "boolean" ?
      payload.featured :
      Boolean(current.featured);

    const merged = {
      ...current,
      status: nextStatus,
      featured: nextFeatured,
    };

    const publicRef = db().collection(SHOP_PUBLIC_PRODUCTS_COLLECTION).doc(productId);
    const projected = buildPublicShopProduct(productId, merged, settings);

    const batch = db().batch();
    batch.update(productRef, {
      status: nextStatus,
      featured: nextFeatured,
      updatedByUid: actor.uid,
      updatedAt: serverTimestamp(),
    });
    if (projected) {
      batch.set(publicRef, {
        ...projected,
        updatedAt: serverTimestamp(),
      });
    } else {
      batch.delete(publicRef);
    }
    await batch.commit();

    if (
      nextStatus === "active" &&
      Array.isArray(settings.hiddenStarterIds) &&
      settings.hiddenStarterIds.includes(productId)
    ) {
      await persistHiddenStarterIds(
          settings.hiddenStarterIds.filter((id) => id !== productId),
          actor.uid,
      );
    }

    await recordAudit(actor, "set_product_visibility", productId, {
      status: nextStatus,
      featured: nextFeatured,
    });

    return {
      productId,
      status: nextStatus,
      featured: nextFeatured,
    };
  });

  const deleteShopProduct = wrapCommand(async (request) => {
    const actor = await requireShopActor(
        request,
        ["catalog_editor", "store_manager", "administrator"],
    );
    const payload = (request && request.data) || {};
    const productId = sanitizeDocId(payload.productId || payload.id);
    if (!productId) {
      throw new HttpsError("invalid-argument", "A valid productId is required to remove a link.");
    }

    const productRef = db().collection(SHOP_PRODUCTS_COLLECTION).doc(productId);
    const publicRef = db().collection(SHOP_PUBLIC_PRODUCTS_COLLECTION).doc(productId);
    const [existingSnap, publicSnap, settings] = await Promise.all([
      productRef.get(),
      publicRef.get(),
      loadEffectiveSettings(),
    ]);

    const existingTitle = existingSnap.exists ?
      cleanText((existingSnap.data() || {}).title, 160) :
      cleanText(payload.title, 160);

    const batch = db().batch();
    if (existingSnap.exists) {
      batch.delete(productRef);
    }
    if (publicSnap.exists) {
      batch.delete(publicRef);
    }
    await batch.commit();

    // Suppress starter fallback if this productId belongs to starter items or hideStarterFallback is requested
    const nextHidden = new Set(settings.hiddenStarterIds || []);
    if (payload.hideStarterFallback !== false) {
      nextHidden.add(productId);
      await persistHiddenStarterIds(Array.from(nextHidden), actor.uid);
    }

    await recordAudit(actor, "delete_product", productId, {
      title: existingTitle,
      existedInFirestore: existingSnap.exists,
    });

    return {
      productId,
      removed: true,
      hiddenStarterIds: Array.from(nextHidden),
    };
  });

  const restoreStarterShopProducts = wrapCommand(async (request) => {
    const actor = await requireShopActor(
        request,
        ["catalog_editor", "store_manager", "administrator"],
    );
    const payload = (request && request.data) || {};
    const mode = cleanText(payload.mode, 24).toLowerCase() || "restore";
    const settings = await loadEffectiveSettings();
    const currentHidden = settings.hiddenStarterIds || [];

    if (mode === "hide") {
      const rawIds = Array.isArray(payload.productIds) ? payload.productIds : [];
      const sanitizedIds = rawIds.map((id) => sanitizeDocId(id)).filter(Boolean);
      const mergedHidden = await persistHiddenStarterIds(
          [...currentHidden, ...sanitizedIds],
          actor.uid,
      );
      await recordAudit(actor, "hide_starter_products", "batch", {
        hiddenCount: mergedHidden.length,
      });
      return {
        hiddenStarterIds: mergedHidden,
        hiddenCount: mergedHidden.length,
      };
    }

    const singleId = sanitizeDocId(payload.productId);
    const nextHidden = singleId ?
      currentHidden.filter((id) => id !== singleId) :
      [];
    await persistHiddenStarterIds(nextHidden, actor.uid);
    await recordAudit(actor, "restore_starter_products", singleId || "all", {
      restoredCount: currentHidden.length - nextHidden.length,
    });
    return {
      hiddenStarterIds: nextHidden,
    };
  });

  const reviewShopVendorApplication = wrapCommand(async (request) => {
    const actor = await requireShopActor(request, ["store_manager", "administrator"]);
    const payload = (request && request.data) || {};
    const applicationId = sanitizeDocId(payload.applicationId);
    if (!applicationId) {
      throw new HttpsError("invalid-argument", "A valid applicationId is required.");
    }

    const decision = cleanText(payload.status, 32);
    if (!VENDOR_APPLICATION_STATUSES.has(decision)) {
      throw new HttpsError("invalid-argument", "Select a valid review decision.");
    }
    const reviewNotes = cleanText(payload.reviewNotes, 800);

    const appRef = db().collection(SHOP_APPLICATIONS_COLLECTION).doc(applicationId);
    const appSnap = await appRef.get();
    if (!appSnap.exists) {
      throw new HttpsError("not-found", "Vendor application was not found.");
    }
    const appData = appSnap.data() || {};

    const batch = db().batch();
    batch.update(appRef, {
      status: decision,
      reviewNotes,
      reviewedByUid: actor.uid,
      reviewedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    let vendorId = appData.vendorId || null;
    if (decision === "approved") {
      vendorId = vendorId || `vendor-${applicationId}`;
      const vendorRef = db().collection(SHOP_VENDORS_COLLECTION).doc(vendorId);
      batch.set(vendorRef, {
        vendorId,
        applicationId,
        ownerUid: appData.submitterUid || null,
        companyName: appData.companyName,
        contactName: appData.contactName,
        email: appData.email,
        phone: appData.phone,
        websiteUrl: appData.websiteUrl || "",
        partnershipTrack: appData.partnershipTrack,
        categories: Array.isArray(appData.categories) ? appData.categories : [],
        brandsCarried: Array.isArray(appData.brandsCarried) ? appData.brandsCarried : [],
        fulfillmentRegions: Array.isArray(appData.fulfillmentRegions) ?
          appData.fulfillmentRegions :
          ["US", "CA"],
        active: true,
        approvedByUid: actor.uid,
        approvedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }, {merge: true});
      batch.update(appRef, {vendorId});
    }

    await batch.commit();

    await recordAudit(actor, "review_vendor_application", applicationId, {
      companyName: appData.companyName,
      decision,
      vendorId,
    });

    return {
      applicationId,
      status: decision,
      vendorId,
    };
  });

  const listShopStaff = wrapCommand(async (request) => {
    await requireShopActor(request, ["store_manager", "administrator"]);
    const snap = await db().collection(SHOP_STAFF_COLLECTION).limit(200).get();
    return {
      staff: snap.docs.map((doc) => ({
        uid: doc.id,
        ...jsonSafe(doc.data() || {}),
      })),
    };
  });

  const manageShopStaff = wrapCommand(async (request) => {
    const actor = await requireShopActor(request, ["administrator"]);
    const data = (request && request.data) || {};
    const email = cleanText(data.email, 254).toLowerCase();
    const active = data.active !== false;
    const role = cleanText(data.role, 40).toLowerCase();

    if (!email || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "Enter a valid Pipe Buyer account email address.");
    }
    if (active && !SHOP_STAFF_ROLES.has(role)) {
      throw new HttpsError(
          "invalid-argument",
          "Store role must be affiliate_contributor, catalog_editor, or store_manager.",
      );
    }

    let user;
    try {
      user = await auth().getUserByEmail(email);
    } catch (error) {
      if (error && error.code === "auth/user-not-found") {
        throw new HttpsError(
            "not-found",
            "No Pipe Buyer account was found for that email. Create the account first.",
        );
      }
      throw error;
    }

    if (active && user.emailVerified !== true) {
      throw new HttpsError(
          "failed-precondition",
          "The account must have a verified email before receiving a Store management role.",
      );
    }

    const allowedPlatforms = normalizeAllowedPlatforms(data.allowedPlatforms);
    const claims = {...(user.customClaims || {})};
    if (active) {
      claims.shopRole = role;
    } else {
      delete claims.shopRole;
    }
    await auth().setCustomUserClaims(user.uid, claims);

    const rosterRef = db().collection(SHOP_STAFF_COLLECTION).doc(user.uid);
    const rosterSnap = await rosterRef.get();
    const rosterWrite = {
      uid: user.uid,
      email,
      displayName: cleanText(user.displayName, 160),
      role: active ? role : null,
      allowedPlatforms: active ? allowedPlatforms : [],
      active,
      updatedAt: serverTimestamp(),
      updatedByUid: actor.uid,
    };
    if (!rosterSnap.exists) {
      rosterWrite.createdAt = serverTimestamp();
      rosterWrite.createdByUid = actor.uid;
    }
    await rosterRef.set(rosterWrite, {merge: true});
    await auth().revokeRefreshTokens(user.uid);

    await recordAudit(
        actor,
        active ? "shop_staff_granted" : "shop_staff_revoked",
        user.uid,
        {
          targetEmail: email,
          role: active ? role : null,
        },
    );

    return {
      uid: user.uid,
      email,
      active,
      role: active ? role : null,
      signInAgainRequired: true,
    };
  });

  return {
    bulkUpsertShopProducts,
    deleteShopProduct,
    getShopAdminDashboard,
    getShopSession,
    listShopStaff,
    listShopStoreCatalog,
    manageShopStaff,
    parseShopAffiliateLink,
    recordShopAffiliateClick,
    restoreStarterShopProducts,
    reviewShopVendorApplication,
    setShopProductVisibility,
    submitShopVendorApplication,
    toggleSavedShopProduct,
    updateShopStoreSettings,
    upsertShopProduct,
  };
}

module.exports = {
  createShopStoreCommands,
  sanitizeDocId,
};
