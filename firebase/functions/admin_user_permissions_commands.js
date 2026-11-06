"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  administratorClaimUpdate,
  enrolledFactorCount,
  hasVerifiedFederatedProvider,
  requireAdministrator,
  validateAdministratorCandidate,
} = require("./administrator_authorization");
const {
  PRIMARY_ADMIN_MANAGER_EMAIL,
  normalizedEmail,
} = require("./administrator_role_commands");
const {USER_RESTRICTION_CODES} = require("./account_security");
const {
  AFFILIATE_PLATFORMS_DIRECTORY,
  SHOP_SOURCE_TYPES,
  SHOP_STAFF_ROLES,
  cleanText,
} = require("./shop_store_policy");

const VALID_ACCOUNT_TYPES = new Set(["personal", "business", "carrier"]);
const VALID_YELLOW_PAGES_ROLES = new Set(["agent", "manager"]);

const RESTRICTION_CATALOG = Object.freeze([
  {
    code: "restrict_store_products",
    label: "Block Store & Affiliate Uploads",
    description: "Prevents adding, editing, or importing affiliate products in the PipeBuyer Store.",
  },
  {
    code: "restrict_marketplace_selling",
    label: "Block Marketplace Listings",
    description: "Prevents creating or publishing equipment, pipe, or property listings.",
  },
  {
    code: "restrict_messaging_offers",
    label: "Block Messaging & Offers",
    description: "Prevents opening conversations, sending messages, or submitting offers.",
  },
  {
    code: "restrict_dispatch",
    label: "Block Freight Dispatch",
    description: "Prevents posting freight jobs or submitting carrier dispatch quotes.",
  },
]);

function jsonSafe(value) {
  if (value == null) return value;
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(jsonSafe);
  if (typeof value === "object") {
    return Object.fromEntries(
        Object.entries(value).map(([k, v]) => [k, jsonSafe(v)]),
    );
  }
  return value;
}

function normalizeAllowedPlatforms(value) {
  if (!Array.isArray(value) || value.length === 0) return ["all"];
  const cleaned = value
      .map((item) => cleanText(item, 48).toLowerCase())
      .filter((item) => item === "all" || SHOP_SOURCE_TYPES.has(item));
  if (cleaned.length === 0 || cleaned.includes("all")) return ["all"];
  return Array.from(new Set(cleaned));
}

function normalizeRestrictions(value) {
  if (!Array.isArray(value)) return [];
  const validSet = new Set(USER_RESTRICTION_CODES);
  const cleaned = value
      .map((item) => cleanText(item, 64).toLowerCase())
      .filter((item) => validSet.has(item));
  return Array.from(new Set(cleaned));
}

function wrapCommand(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      if (error && error.code === "auth/user-not-found") {
        throw new HttpsError(
            "not-found",
            "No Pipe Buyer account was found for that user or email address.",
        );
      }
      console.error("Admin user permissions command failed", error);
      throw new HttpsError(
          "internal",
          "User permissions could not be updated.",
      );
    }
  };
}

function createAdminUserPermissionsCommands(admin) {
  const auth = () => admin.auth();
  const db = () => admin.firestore();
  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp();

  function actorContext(request) {
    const uid = requireAdministrator(request);
    const token = (request && request.auth && request.auth.token) || {};
    const email = normalizedEmail(token.email);
    const isPrimaryManager =
      email === PRIMARY_ADMIN_MANAGER_EMAIL || token.primaryAdmin === true;
    const canManageAdmins = isPrimaryManager || token.canGrantPermissions === true;
    return {uid, email, isPrimaryManager, canManageAdmins};
  }

  function mergeUserRecord({
    uid,
    authUser,
    userDoc,
    adminRoleDoc,
    shopStaffDoc,
    ypStaffDoc,
    permDoc,
  }) {
    const claims = (authUser && authUser.customClaims) || {};
    const email = normalizedEmail(
        (authUser && authUser.email) ||
        (userDoc && userDoc.email) ||
        (permDoc && permDoc.email) ||
        (shopStaffDoc && shopStaffDoc.email),
    );
    const displayName = cleanText(
        (authUser && authUser.displayName) ||
        (userDoc && (userDoc.displayName || userDoc.display_name || userDoc.publicName)) ||
        (permDoc && permDoc.displayName) ||
        (shopStaffDoc && shopStaffDoc.displayName),
        160,
    );
    const providers = authUser && Array.isArray(authUser.providerData) ?
      authUser.providerData
          .map((p) => cleanText(p && p.providerId, 64).toLowerCase())
          .filter(Boolean) :
      [];

    const isPrimaryAdmin =
      email === PRIMARY_ADMIN_MANAGER_EMAIL || claims.primaryAdmin === true;
    const isAdmin = Boolean(
        isPrimaryAdmin ||
        (claims.admin === true && claims.role === "administrator") ||
        (adminRoleDoc && adminRoleDoc.active === true),
    );

    const activeShopRole = (shopStaffDoc && shopStaffDoc.active === true && shopStaffDoc.role) ?
      cleanText(shopStaffDoc.role, 40).toLowerCase() :
      (SHOP_STAFF_ROLES.has(cleanText(claims.shopRole, 40).toLowerCase()) &&
        (!shopStaffDoc || shopStaffDoc.active !== false)) ?
        cleanText(claims.shopRole, 40).toLowerCase() :
        "none";

    const activeYpRole = (ypStaffDoc && ypStaffDoc.active === true && ypStaffDoc.role) ?
      cleanText(ypStaffDoc.role, 40).toLowerCase() :
      "none";

    const rawPerms = (permDoc && permDoc.permissions) || (userDoc && userDoc.permissions) || {};
    const hasShopAccess = isAdmin || activeShopRole !== "none";
    const permissions = {
      addAffiliateProducts: Boolean(hasShopAccess || rawPerms.addAffiliateProducts),
      bulkImportCatalog: Boolean(
          isAdmin ||
          activeShopRole === "catalog_editor" ||
          activeShopRole === "store_manager" ||
          rawPerms.bulkImportCatalog,
      ),
      manageStoreVendors: Boolean(
          isAdmin ||
          activeShopRole === "store_manager" ||
          rawPerms.manageStoreVendors,
      ),
      verifiedSeller: Boolean(
          (userDoc && userDoc.accountVerified === true) ||
          rawPerms.verifiedSeller,
      ),
      canGrantPermissions: Boolean(
          isPrimaryAdmin ||
          claims.canGrantPermissions === true ||
          rawPerms.canGrantPermissions,
      ),
    };

    const allowedAffiliatePlatforms = isAdmin ?
      ["all"] :
      normalizeAllowedPlatforms(
          (shopStaffDoc && shopStaffDoc.allowedPlatforms) ||
          (permDoc && permDoc.allowedAffiliatePlatforms),
      );

    const restricted = Boolean(
        claims.restricted === true ||
        (permDoc && permDoc.restricted === true) ||
        (userDoc && userDoc.restricted === true) ||
        (userDoc && userDoc.accountStatus === "restricted"),
    );
    const loginDisabled = Boolean(
        (authUser && authUser.disabled === true) ||
        (permDoc && permDoc.loginDisabled === true),
    );
    const restrictions = normalizeRestrictions(
        claims.restrictions ||
        (permDoc && permDoc.restrictions) ||
        (userDoc && userDoc.restrictions),
    );
    const restrictionReason = cleanText(
        (permDoc && permDoc.restrictionReason) ||
        (userDoc && userDoc.restrictionReason),
        300,
    );

    const accountTypeRaw = cleanText(
        (userDoc && userDoc.accountType) || claims.accountType || "personal",
        32,
    ).toLowerCase();
    const accountType = VALID_ACCOUNT_TYPES.has(accountTypeRaw) ?
      accountTypeRaw :
      "personal";

    const createdRaw = authUser && authUser.metadata && authUser.metadata.creationTime;
    const lastSignInRaw = authUser && authUser.metadata && authUser.metadata.lastSignInTime;
    let createdIso = null;
    let createdEpochMs = 0;
    if (createdRaw) {
      const parsedTs = Date.parse(createdRaw);
      if (Number.isFinite(parsedTs)) {
        createdIso = new Date(parsedTs).toISOString();
        createdEpochMs = parsedTs;
      }
    }
    let lastSignInIso = null;
    if (lastSignInRaw) {
      const parsedSign = Date.parse(lastSignInRaw);
      if (Number.isFinite(parsedSign)) {
        lastSignInIso = new Date(parsedSign).toISOString();
      }
    }

    return {
      uid,
      email,
      displayName: displayName || (email ? email.split("@")[0] : uid),
      photoUrl: cleanText(authUser && authUser.photoURL, 500),
      emailVerified: Boolean(
          (authUser && authUser.emailVerified === true) ||
          (userDoc && userDoc.emailOwnershipVerified === true),
      ),
      phoneNumber: cleanText(
          (authUser && authUser.phoneNumber) || (userDoc && userDoc.phoneE164),
          32,
      ),
      enrolledFactorCount: authUser ? enrolledFactorCount(authUser) : 0,
      providers,
      isGoogleSignIn: providers.includes("google.com"),
      accountType,
      userScore: Number((userDoc && userDoc.userScore) ?? 70),
      isAdmin,
      isPrimaryAdmin,
      shopRole: activeShopRole,
      allowedAffiliatePlatforms,
      yellowPagesRole: activeYpRole,
      permissions,
      restricted,
      loginDisabled,
      restrictions,
      restrictionReason,
      createdAt: createdIso,
      lastSignInAt: lastSignInIso,
      _sortCreatedMs: createdEpochMs,
    };
  }

  const listAdminUsersAndPermissions = wrapCommand(async (request) => {
    const actor = actorContext(request);

    const [
      authListResult,
      usersSnap,
      adminRolesSnap,
      shopStaffSnap,
      ypStaffSnap,
      permsSnap,
    ] = await Promise.all([
      auth().listUsers(1000),
      db().collection("users").limit(1000).get(),
      db().collection("administrator_roles").limit(250).get(),
      db().collection("shop_staff").limit(500).get(),
      db().collection("yellow_pages_staff").limit(500).get(),
      db().collection("user_permissions").limit(1000).get(),
    ]);

    const authByUid = new Map(
        (authListResult.users || []).map((u) => [u.uid, u]),
    );
    const userDocsByUid = new Map(
        usersSnap.docs.map((d) => [d.id, jsonSafe(d.data() || {})]),
    );
    const adminRolesByUid = new Map(
        adminRolesSnap.docs.map((d) => [d.id, jsonSafe(d.data() || {})]),
    );
    const shopStaffByUid = new Map(
        shopStaffSnap.docs.map((d) => [d.id, jsonSafe(d.data() || {})]),
    );
    const ypStaffByUid = new Map(
        ypStaffSnap.docs.map((d) => [d.id, jsonSafe(d.data() || {})]),
    );
    const permsByUid = new Map(
        permsSnap.docs.map((d) => [d.id, jsonSafe(d.data() || {})]),
    );

    const allUids = new Set([
      ...authByUid.keys(),
      ...userDocsByUid.keys(),
      ...shopStaffByUid.keys(),
      ...permsByUid.keys(),
    ]);

    const users = [];
    for (const uid of allUids) {
      const merged = mergeUserRecord({
        uid,
        authUser: authByUid.get(uid) || null,
        userDoc: userDocsByUid.get(uid) || null,
        adminRoleDoc: adminRolesByUid.get(uid) || null,
        shopStaffDoc: shopStaffByUid.get(uid) || null,
        ypStaffDoc: ypStaffByUid.get(uid) || null,
        permDoc: permsByUid.get(uid) || null,
      });
      users.push(merged);
    }

    users.sort((a, b) => {
      if (a.isPrimaryAdmin !== b.isPrimaryAdmin) return a.isPrimaryAdmin ? -1 : 1;
      if (a.isAdmin !== b.isAdmin) return a.isAdmin ? -1 : 1;
      const aStaff = a.shopRole !== "none" || a.yellowPagesRole !== "none";
      const bStaff = b.shopRole !== "none" || b.yellowPagesRole !== "none";
      if (aStaff !== bStaff) return aStaff ? -1 : 1;
      if (b._sortCreatedMs !== a._sortCreatedMs) return b._sortCreatedMs - a._sortCreatedMs;
      return String(a.email || a.uid).localeCompare(String(b.email || b.uid));
    });

    for (const item of users) {
      delete item._sortCreatedMs;
    }

    return {
      actor: {
        uid: actor.uid,
        email: actor.email,
        isPrimaryManager: actor.isPrimaryManager,
        canManageAdmins: actor.canManageAdmins,
      },
      primaryManagerEmail: PRIMARY_ADMIN_MANAGER_EMAIL,
      users,
      affiliatePlatforms: AFFILIATE_PLATFORMS_DIRECTORY,
      restrictionCatalog: RESTRICTION_CATALOG,
    };
  });

  const updateAdminUserPermissions = wrapCommand(async (request) => {
    const actor = actorContext(request);
    const data = (request && request.data) || {};

    const targetUidInput = cleanText(data.uid, 128);
    const targetEmailInput = normalizedEmail(data.email);
    if (!targetUidInput && (!targetEmailInput || !targetEmailInput.includes("@"))) {
      throw new HttpsError(
          "invalid-argument",
          "Provide a valid user UID or account email address.",
      );
    }

    const targetUser = targetUidInput ?
      await auth().getUser(targetUidInput) :
      await auth().getUserByEmail(targetEmailInput);

    const targetEmail = normalizedEmail(targetUser.email || targetEmailInput);
    const isTargetPrimary =
      targetEmail === PRIMARY_ADMIN_MANAGER_EMAIL ||
      Boolean(targetUser.customClaims && targetUser.customClaims.primaryAdmin === true);

    // Permanently protect primary administrator from lockout, restriction, or admin removal
    if (isTargetPrimary) {
      if (data.grantAdmin === false) {
        throw new HttpsError(
            "failed-precondition",
            "The primary Pipe Buyer administrator cannot have Administrator access revoked.",
        );
      }
      if (
        data.restricted === true ||
        data.loginDisabled === true ||
        (Array.isArray(data.restrictions) && data.restrictions.length > 0)
      ) {
        throw new HttpsError(
            "failed-precondition",
            "The primary Pipe Buyer administrator account cannot be restricted or suspended.",
        );
      }
    }

    const existingClaims = {...(targetUser.customClaims || {})};
    const targetCurrentlyAdmin =
      existingClaims.admin === true && existingClaims.role === "administrator";

    if (
      typeof data.grantAdmin === "boolean" &&
      data.grantAdmin !== targetCurrentlyAdmin &&
      !actor.canManageAdmins
    ) {
      throw new HttpsError(
          "permission-denied",
          "Only the Primary Administrator or an Administrator with Grant-Admin authority can change Administrator roles.",
      );
    }

    if (
      targetCurrentlyAdmin &&
      !actor.canManageAdmins &&
      (data.restricted === true || data.loginDisabled === true)
    ) {
      throw new HttpsError(
          "permission-denied",
          "Only the Primary Administrator can restrict or suspend another Administrator account.",
      );
    }

    const [existingUserSnap, existingPermSnap, existingShopSnap, existingYpSnap] =
      await Promise.all([
        db().collection("users").doc(targetUser.uid).get(),
        db().collection("user_permissions").doc(targetUser.uid).get(),
        db().collection("shop_staff").doc(targetUser.uid).get(),
        db().collection("yellow_pages_staff").doc(targetUser.uid).get(),
      ]);

    const existingUserDoc = existingUserSnap.exists ? (existingUserSnap.data() || {}) : null;
    const existingPermDoc = existingPermSnap.exists ? (existingPermSnap.data() || {}) : {};
    const existingShopDoc = existingShopSnap.exists ? (existingShopSnap.data() || {}) : {};
    const existingYpDoc = existingYpSnap.exists ? (existingYpSnap.data() || {}) : {};

    // 1. Account Type
    const requestedAccountType = data.accountType !== undefined ?
      cleanText(data.accountType, 32).toLowerCase() :
      cleanText(
          (existingUserDoc && existingUserDoc.accountType) ||
          existingClaims.accountType ||
          "personal",
          32,
      ).toLowerCase();
    if (!VALID_ACCOUNT_TYPES.has(requestedAccountType)) {
      throw new HttpsError(
          "invalid-argument",
          "Account type must be personal, business, or carrier.",
      );
    }

    // 2. Restrictions & Login Suspension
    const nextRestricted = typeof data.restricted === "boolean" ?
      data.restricted :
      Boolean(existingClaims.restricted === true || existingPermDoc.restricted === true);
    const nextLoginDisabled = typeof data.loginDisabled === "boolean" ?
      data.loginDisabled :
      Boolean(targetUser.disabled === true);
    const nextRestrictions = data.restrictions !== undefined ?
      normalizeRestrictions(data.restrictions) :
      normalizeRestrictions(existingClaims.restrictions || existingPermDoc.restrictions);
    const nextRestrictionReason = data.restrictionReason !== undefined ?
      cleanText(data.restrictionReason, 300) :
      cleanText(existingPermDoc.restrictionReason, 300);

    // 3. Store & Affiliate Role + Platform Scopes
    let nextShopRole = data.shopRole !== undefined ?
      cleanText(data.shopRole, 40).toLowerCase() :
      (existingShopDoc.active === true && existingShopDoc.role ?
        cleanText(existingShopDoc.role, 40).toLowerCase() :
        "none");
    if (!nextShopRole || nextShopRole === "none") {
      nextShopRole = "none";
    } else if (!SHOP_STAFF_ROLES.has(nextShopRole)) {
      throw new HttpsError(
          "invalid-argument",
          "Store role must be none, affiliate_contributor, catalog_editor, or store_manager.",
      );
    }

    // Convenience: if caller sets permissions.addAffiliateProducts = true and didn't pick a shopRole, default to catalog_editor / affiliate_contributor
    const inputPermissions = (data.permissions && typeof data.permissions === "object") ?
      data.permissions :
      {};
    if (
      data.shopRole === undefined &&
      inputPermissions.addAffiliateProducts === true &&
      nextShopRole === "none"
    ) {
      nextShopRole = inputPermissions.bulkImportCatalog === true ?
        "catalog_editor" :
        "affiliate_contributor";
    }

    if (nextShopRole !== "none" && targetUser.emailVerified !== true) {
      throw new HttpsError(
          "failed-precondition",
          "The user must have a verified email address before receiving Store affiliate product permissions.",
      );
    }

    const nextAllowedPlatforms = data.allowedAffiliatePlatforms !== undefined ?
      normalizeAllowedPlatforms(data.allowedAffiliatePlatforms) :
      normalizeAllowedPlatforms(
          existingShopDoc.allowedPlatforms || existingPermDoc.allowedAffiliatePlatforms,
      );

    // 4. Yellow Pages Contact Center Role
    let nextYpRole = data.yellowPagesRole !== undefined ?
      cleanText(data.yellowPagesRole, 40).toLowerCase() :
      (existingYpDoc.active === true && existingYpDoc.role ?
        cleanText(existingYpDoc.role, 40).toLowerCase() :
        "none");
    if (!nextYpRole || nextYpRole === "none") {
      nextYpRole = "none";
    } else if (!VALID_YELLOW_PAGES_ROLES.has(nextYpRole)) {
      throw new HttpsError(
          "invalid-argument",
          "Directory role must be none, agent, or manager.",
      );
    }

    // 5. Administrator Role
    let nextClaims = {...existingClaims};
    let nextIsAdmin = targetCurrentlyAdmin || isTargetPrimary;
    if (typeof data.grantAdmin === "boolean") {
      if (data.grantAdmin) {
        validateAdministratorCandidate(targetUser, {
          allowPrimaryWithoutMfa: isTargetPrimary,
          allowVerifiedFederated: true,
        });
      }
      nextClaims = administratorClaimUpdate(nextClaims, data.grantAdmin, {
        primaryAdmin: isTargetPrimary,
        federatedAdminApproved: hasVerifiedFederatedProvider(targetUser),
      });
      nextIsAdmin = data.grantAdmin;
    } else if (isTargetPrimary) {
      nextClaims = administratorClaimUpdate(nextClaims, true, {
        primaryAdmin: true,
        federatedAdminApproved: hasVerifiedFederatedProvider(targetUser),
      });
      nextIsAdmin = true;
    }

    // 6. Granular Permissions
    const prevPerms = existingPermDoc.permissions || {};
    const nextCanGrantPermissions = isTargetPrimary ?
      true :
      (typeof inputPermissions.canGrantPermissions === "boolean" && actor.canManageAdmins ?
        inputPermissions.canGrantPermissions :
        Boolean(prevPerms.canGrantPermissions));
    const nextVerifiedSeller = typeof inputPermissions.verifiedSeller === "boolean" ?
      inputPermissions.verifiedSeller :
      Boolean(
          (existingUserDoc && existingUserDoc.accountVerified === true) ||
          prevPerms.verifiedSeller,
      );

    const effectiveShopActive = nextShopRole !== "none" &&
      !nextRestricted &&
      !nextRestrictions.includes("restrict_store_products");

    const nextPermissions = {
      addAffiliateProducts: Boolean(nextIsAdmin || effectiveShopActive),
      bulkImportCatalog: Boolean(
          nextIsAdmin ||
          (effectiveShopActive &&
            (nextShopRole === "catalog_editor" ||
              nextShopRole === "store_manager" ||
              inputPermissions.bulkImportCatalog === true)),
      ),
      manageStoreVendors: Boolean(
          nextIsAdmin ||
          (effectiveShopActive && nextShopRole === "store_manager"),
      ),
      verifiedSeller: nextVerifiedSeller,
      canGrantPermissions: Boolean(nextIsAdmin && nextCanGrantPermissions),
    };

    // Update Custom Claims cleanly (stay well within Firebase 1,000-byte customClaims limit)
    nextClaims.accountType = requestedAccountType;
    nextClaims.personal = requestedAccountType === "personal";
    nextClaims.business = requestedAccountType !== "personal";

    if (effectiveShopActive) {
      nextClaims.shopRole = nextShopRole;
    } else {
      delete nextClaims.shopRole;
    }

    if (nextYpRole !== "none" && !nextRestricted) {
      nextClaims.yellowPagesRole = nextYpRole;
    } else {
      delete nextClaims.yellowPagesRole;
    }

    if (nextPermissions.canGrantPermissions) {
      nextClaims.canGrantPermissions = true;
    } else {
      delete nextClaims.canGrantPermissions;
    }

    if (nextRestricted) {
      nextClaims.restricted = true;
    } else {
      delete nextClaims.restricted;
    }

    if (nextRestrictions.length > 0) {
      nextClaims.restrictions = nextRestrictions;
    } else {
      delete nextClaims.restrictions;
    }

    if (nextLoginDisabled !== Boolean(targetUser.disabled)) {
      await auth().updateUser(targetUser.uid, {disabled: nextLoginDisabled});
    }
    await auth().setCustomUserClaims(targetUser.uid, nextClaims);

    const displayName = cleanText(
        targetUser.displayName ||
        (existingUserDoc && (existingUserDoc.displayName || existingUserDoc.display_name)) ||
        (targetEmail ? targetEmail.split("@")[0] : ""),
        160,
    );

    const batch = db().batch();

    // Sync user_permissions/{uid}
    const permRef = db().collection("user_permissions").doc(targetUser.uid);
    batch.set(permRef, {
      uid: targetUser.uid,
      email: targetEmail,
      displayName,
      accountType: requestedAccountType,
      isAdmin: nextIsAdmin,
      shopRole: nextShopRole,
      allowedAffiliatePlatforms: nextAllowedPlatforms,
      yellowPagesRole: nextYpRole,
      permissions: nextPermissions,
      restricted: nextRestricted,
      loginDisabled: nextLoginDisabled,
      restrictions: nextRestrictions,
      restrictionReason: (nextRestricted || nextLoginDisabled || nextRestrictions.length > 0) ?
        nextRestrictionReason :
        "",
      updatedByUid: actor.uid,
      updatedByEmail: actor.email,
      updatedAt: serverTimestamp(),
      ...(existingPermSnap.exists ? {} : {createdAt: serverTimestamp()}),
    }, {merge: true});

    // Sync shop_staff/{uid}
    const shopRef = db().collection("shop_staff").doc(targetUser.uid);
    batch.set(shopRef, {
      uid: targetUser.uid,
      email: targetEmail,
      displayName,
      role: nextShopRole !== "none" ? nextShopRole : null,
      allowedPlatforms: nextShopRole !== "none" ? nextAllowedPlatforms : [],
      active: effectiveShopActive,
      restricted: nextRestricted || nextRestrictions.includes("restrict_store_products"),
      updatedByUid: actor.uid,
      updatedAt: serverTimestamp(),
      ...(existingShopSnap.exists ? {} : {
        createdByUid: actor.uid,
        createdAt: serverTimestamp(),
      }),
    }, {merge: true});

    // Sync yellow_pages_staff/{uid} if changed or present
    if (data.yellowPagesRole !== undefined || existingYpSnap.exists) {
      const ypRef = db().collection("yellow_pages_staff").doc(targetUser.uid);
      batch.set(ypRef, {
        uid: targetUser.uid,
        email: targetEmail,
        displayName,
        role: nextYpRole !== "none" ? nextYpRole : null,
        active: nextYpRole !== "none" && !nextRestricted,
        updatedByUid: actor.uid,
        updatedAt: serverTimestamp(),
        ...(existingYpSnap.exists ? {} : {
          createdByUid: actor.uid,
          createdAt: serverTimestamp(),
        }),
      }, {merge: true});
    }

    // Sync administrator_roles/{uid} when admin role is explicitly managed
    if (typeof data.grantAdmin === "boolean" || isTargetPrimary) {
      const adminRoleRef = db().collection("administrator_roles").doc(targetUser.uid);
      batch.set(adminRoleRef, {
        active: nextIsAdmin,
        role: "administrator",
        mfaRequired: !isTargetPrimary && !hasVerifiedFederatedProvider(targetUser),
        federatedApproved: hasVerifiedFederatedProvider(targetUser),
        updatedBy: actor.uid,
        updatedAt: serverTimestamp(),
      }, {merge: true});
    }

    // Sync users/{uid} so Admin Dashboard and Account Hub reflect status immediately
    const userRef = db().collection("users").doc(targetUser.uid);
    const userWrite = {
      uid: targetUser.uid,
      email: targetEmail || null,
      ...(displayName ? {displayName} : {}),
      accountType: requestedAccountType,
      emailOwnershipVerified: targetUser.emailVerified === true,
      accountVerified: nextVerifiedSeller,
      shopRole: effectiveShopActive ? nextShopRole : null,
      allowedAffiliatePlatforms: effectiveShopActive ? nextAllowedPlatforms : [],
      permissions: nextPermissions,
      accountStatus: (nextRestricted || nextLoginDisabled) ? "restricted" : "active",
      restricted: nextRestricted,
      loginDisabled: nextLoginDisabled,
      restrictions: nextRestrictions,
      restrictionReason: (nextRestricted || nextLoginDisabled || nextRestrictions.length > 0) ?
        nextRestrictionReason :
        "",
      updatedAt: serverTimestamp(),
    };
    if (!existingUserSnap.exists) {
      userWrite.userScore = 70;
      userWrite.createdAt = serverTimestamp();
    }
    batch.set(userRef, userWrite, {merge: true});

    // Record immutable audit event
    const auditRef = db().collection("admin_permission_audits").doc();
    batch.set(auditRef, {
      actorUid: actor.uid,
      actorEmail: actor.email,
      targetUid: targetUser.uid,
      targetEmail,
      accountType: requestedAccountType,
      isAdmin: nextIsAdmin,
      shopRole: nextShopRole,
      allowedAffiliatePlatforms: nextAllowedPlatforms,
      yellowPagesRole: nextYpRole,
      permissions: nextPermissions,
      restricted: nextRestricted,
      loginDisabled: nextLoginDisabled,
      restrictions: nextRestrictions,
      restrictionReason: nextRestrictionReason,
      createdAt: serverTimestamp(),
    });

    // Notify user in-app if Store contributor permissions were newly granted
    const hadShopBefore = Boolean(existingShopDoc.active === true && existingShopDoc.role);
    if (!hadShopBefore && effectiveShopActive) {
      const notifRef = db()
          .collection("users")
          .doc(targetUser.uid)
          .collection("notifications")
          .doc(`store_permissions_${Date.now()}`);
      batch.set(notifRef, {
        recipientUid: targetUser.uid,
        type: "permissions_granted",
        title: "Store & Affiliate Product Access Enabled",
        body: "An Administrator granted your account permission to add affiliate products (Amazon, AliExpress, Lazada, Shopee & more) to the Pipe Buyer Store.",
        read: false,
        createdAt: serverTimestamp(),
      });
    }

    await batch.commit();
    await auth().revokeRefreshTokens(targetUser.uid);

    const refreshedAuthUser = await auth().getUser(targetUser.uid);
    const updatedUser = mergeUserRecord({
      uid: targetUser.uid,
      authUser: refreshedAuthUser,
      userDoc: {...(existingUserDoc || {}), ...userWrite},
      adminRoleDoc: {active: nextIsAdmin},
      shopStaffDoc: {
        email: targetEmail,
        displayName,
        role: nextShopRole !== "none" ? nextShopRole : null,
        allowedPlatforms: nextAllowedPlatforms,
        active: effectiveShopActive,
      },
      ypStaffDoc: {
        role: nextYpRole !== "none" ? nextYpRole : null,
        active: nextYpRole !== "none" && !nextRestricted,
      },
      permDoc: {
        email: targetEmail,
        displayName,
        allowedAffiliatePlatforms: nextAllowedPlatforms,
        permissions: nextPermissions,
        restricted: nextRestricted,
        loginDisabled: nextLoginDisabled,
        restrictions: nextRestrictions,
        restrictionReason: nextRestrictionReason,
      },
    });
    delete updatedUser._sortCreatedMs;

    return {
      updated: true,
      signInRefreshRecommended: true,
      user: updatedUser,
    };
  });

  return {
    listAdminUsersAndPermissions,
    updateAdminUserPermissions,
  };
}

module.exports = {
  RESTRICTION_CATALOG,
  createAdminUserPermissionsCommands,
  normalizeAllowedPlatforms,
  normalizeRestrictions,
};
