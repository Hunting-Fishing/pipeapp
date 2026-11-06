"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  AFFILIATE_PLATFORMS_DIRECTORY,
  buildMonetizedDestinationUrl,
  detectAffiliatePlatform,
  normalizeStoreSettings,
  parseAffiliateSubmission,
  validateShopProductInput,
} = require("../shop_store_policy");
const {createShopStoreCommands} = require("../shop_store_commands");
const {createAdminUserPermissionsCommands} = require("../admin_user_permissions_commands");
const {
  assertNotRestrictedFor,
  requireAuthenticatedIdentity,
} = require("../account_security");
const {isAdministrator} = require("../administrator_authorization");

function createFakeAdminRuntime(initialUsers = []) {
  const store = new Map();
  const usersByUid = new Map();
  let autoId = 0;

  for (const raw of initialUsers) {
    usersByUid.set(raw.uid, {
      uid: raw.uid,
      email: raw.email,
      displayName: raw.displayName || "",
      emailVerified: raw.emailVerified !== false,
      disabled: Boolean(raw.disabled),
      providerData: raw.providerData || [],
      multiFactor: raw.multiFactor || {enrolledFactors: []},
      customClaims: {...(raw.customClaims || {})},
      metadata: {
        creationTime: raw.creationTime || "2026-11-06T10:00:00Z",
        lastSignInTime: raw.lastSignInTime || "2026-11-06T10:05:00Z",
      },
    });
  }

  function makeDocRef(col, id) {
    const key = `${col}/${id}`;
    return {
      id,
      path: key,
      async get() {
        const exists = store.has(key);
        return {
          id,
          exists,
          data: () => (exists ? {...store.get(key)} : undefined),
        };
      },
      async set(data, opts) {
        const prev = opts && opts.merge && store.has(key) ? store.get(key) : {};
        store.set(key, {...prev, ...data});
      },
      async update(data) {
        const prev = store.get(key) || {};
        store.set(key, {...prev, ...data});
      },
      async delete() {
        store.delete(key);
      },
      collection(subCol) {
        return makeCollection(`${col}/${id}/${subCol}`);
      },
    };
  }

  function makeCollection(col) {
    const prefix = `${col}/`;
    const queryApi = (predicate = () => true) => ({
      where(field, op, expected) {
        return queryApi((doc) => predicate(doc) && (op === "==" ? doc[field] === expected : true));
      },
      orderBy() {
        return queryApi(predicate);
      },
      limit() {
        return queryApi(predicate);
      },
      async get() {
        const docs = [];
        for (const [key, val] of store.entries()) {
          if (key.startsWith(prefix)) {
            const rest = key.slice(prefix.length);
            if (!rest.includes("/") && predicate(val)) {
              docs.push({id: rest, data: () => ({...val})});
            }
          }
        }
        return {empty: docs.length === 0, size: docs.length, docs};
      },
    });
    return {
      ...queryApi(),
      doc(id) {
        return makeDocRef(col, id || `doc_${++autoId}`);
      },
      async add(data) {
        const ref = makeDocRef(col, `doc_${++autoId}`);
        await ref.set(data);
        return ref;
      },
    };
  }

  return {
    store,
    usersByUid,
    runtime: {
      auth: () => ({
        async listUsers() {
          return {users: Array.from(usersByUid.values())};
        },
        async getUser(uid) {
          const found = usersByUid.get(uid);
          if (!found) {
            const err = new Error("not found");
            err.code = "auth/user-not-found";
            throw err;
          }
          return found;
        },
        async getUserByEmail(email) {
          const norm = String(email || "").trim().toLowerCase();
          for (const u of usersByUid.values()) {
            if (String(u.email || "").toLowerCase() === norm) return u;
          }
          const err = new Error("not found");
          err.code = "auth/user-not-found";
          throw err;
        },
        async setCustomUserClaims(uid, claims) {
          const found = usersByUid.get(uid);
          if (found) found.customClaims = {...claims};
        },
        async updateUser(uid, patch) {
          const found = usersByUid.get(uid);
          if (found && typeof patch.disabled === "boolean") {
            found.disabled = patch.disabled;
          }
          return found;
        },
        async revokeRefreshTokens() {},
      }),
      firestore: Object.assign(
          () => ({
            collection: (col) => makeCollection(col),
            batch() {
              const ops = [];
              return {
                set: (ref, d, o) => ops.push(() => ref.set(d, o)),
                update: (ref, d) => ops.push(() => ref.update(d)),
                delete: (ref) => ops.push(() => ref.delete()),
                async commit() {
                  for (const op of ops) await op();
                },
              };
            },
          }),
          {
            FieldValue: {
              serverTimestamp: () => "SERVER_TS",
              increment: (n) => n,
            },
          },
      ),
    },
  };
}

test("multi-platform affiliate directory, detection, parsing, and monetization cover Amazon, AliExpress, Lazada, Shopee, Involve Asia, eBay, VEVOR, and networks", () => {
  assert.ok(AFFILIATE_PLATFORMS_DIRECTORY.length >= 15);

  const settings = normalizeStoreSettings({
    amazonAssociateTagUs: "pipebuyer-20",
    amazonAssociateTagCa: "pipebuyerca-20",
    amazonAssociateTagSg: "pipebuyersg-22",
    aliexpressTrackingId: "_dPipeAli",
    shopeeAffiliateSubId: "PipeBuyerShopee1",
    lazadaAffiliateSubId: "pipebuyer_laz",
    involveAsiaSubId: "pb_involve",
    ebayCampaignId: "5338999999",
  });

  // 1. AliExpress short link & full URL
  const aliShort = parseAffiliateSubmission(
      "Just found this amazing item on AliExpress: Ultrasonic Pipe Wall Thickness Gauge https://s.click.aliexpress.com/e/_DmPipe99",
      settings,
  );
  assert.equal(aliShort.sourceType, "aliexpress_affiliate");
  assert.equal(aliShort.platformName, "AliExpress");
  assert.equal(aliShort.isShortLink, true);
  assert.equal(aliShort.suggestedCategoryCode, "measuring_inspection");
  assert.equal(aliShort.monetizedPreviewUs, "https://s.click.aliexpress.com/e/_DmPipe99");

  const aliFull = buildMonetizedDestinationUrl(
      {
        sourceType: "aliexpress_affiliate",
        categoryCode: "pipe_welding_fab",
        destinationUrl: "https://www.aliexpress.com/item/10050067890123.html",
      },
      settings,
  );
  assert.match(aliFull, /sk=_dPipeAli/);

  // 2. Shopee short link & full regional URL
  const shopeeParsed = parseAffiliateSubmission(
      "Check out ANSI Cut Kevlar Safety Gloves https://shope.ee/8pPipeGear",
      settings,
  );
  assert.equal(shopeeParsed.sourceType, "shopee_affiliate");
  assert.equal(shopeeParsed.suggestedCategoryCode, "ppe_fr_safety");
  assert.equal(shopeeParsed.monetizedPreviewUs, "https://shope.ee/8pPipeGear");

  const shopeeFull = buildMonetizedDestinationUrl(
      {
        sourceType: "shopee_affiliate",
        categoryCode: "ppe_fr_safety",
        destinationUrl: "https://shopee.ph/Heavy-Duty-Welding-Gloves-i.12345.67890",
      },
      settings,
  );
  assert.match(shopeeFull, /sub_id=PipeBuyerShopee1/);

  // 3. Lazada full & short URL
  const lazadaParsed = parseAffiliateSubmission(
      "https://www.lazada.com.ph/products/bosch-angle-grinder-heavy-duty-i987654-s123456.html",
      settings,
  );
  assert.equal(lazadaParsed.sourceType, "lazada_affiliate");
  assert.equal(lazadaParsed.suggestedBrand, "Bosch");
  assert.match(lazadaParsed.monetizedPreviewUs, /aff_sub=pipebuyer_laz/);

  // 4. Involve Asia unified SEA link
  const involveParsed = parseAffiliateSubmission(
      "https://invol.co/clPipe123",
      settings,
  );
  assert.equal(involveParsed.sourceType, "affiliate_network");
  assert.equal(involveParsed.platformId, "involve_asia");
  assert.match(involveParsed.monetizedPreviewUs, /subid=pb_involve/);

  // 5. eBay Partner Network
  const ebayParsed = parseAffiliateSubmission(
      "https://www.ebay.com/itm/RIDGID-300-Pipe-Threading-Machine/285123456789",
      settings,
  );
  assert.equal(ebayParsed.sourceType, "ebay_partner");
  assert.match(ebayParsed.monetizedPreviewUs, /campid=5338999999/);
  assert.match(ebayParsed.monetizedPreviewUs, /mkcid=1/);

  // 6. VEVOR & Hardware Pro Retail
  const vevorDetected = detectAffiliatePlatform("https://www.vevor.com/pipe-threading-machine-c_10829");
  assert.equal(vevorDetected.sourceType, "hardware_pro_retail");
  assert.equal(vevorDetected.vendorName, "VEVOR");

  const validatedShopee = validateShopProductInput({
    rawAffiliateInput: "Makita Cordless Impact Wrench https://shope.ee/9xyzTools",
  });
  assert.equal(validatedShopee.sourceType, "shopee_affiliate");
  assert.equal(validatedShopee.vendorName, "Shopee");
  assert.equal(validatedShopee.ctaLabel, "View on Shopee");
});

test("Google Sign-in user granted permissions by Primary Admin can immediately add multi-platform affiliate products and be restricted/unrestricted", async () => {
  const {runtime, usersByUid} = createFakeAdminRuntime([
    {
      uid: "N6ljgn83doc61zBn4Aqwwnbv92B2",
      email: "jordilwbailey@gmail.com",
      displayName: "Jordi Bailey",
      emailVerified: true,
      providerData: [{providerId: "google.com"}],
      customClaims: {
        admin: true,
        role: "administrator",
        primaryAdmin: true,
        accountType: "personal",
      },
    },
    {
      uid: "M0t7A7npFFZAxLKVlGWxAkztgty2",
      email: "ashleynicole062490@gmail.com",
      displayName: "Joan Gadin",
      emailVerified: true,
      providerData: [{providerId: "google.com"}],
      customClaims: {
        accountType: "personal",
      },
    },
  ]);

  const adminPermCommands = createAdminUserPermissionsCommands(runtime);
  const shopCommands = createShopStoreCommands(runtime);

  const primaryAdminReq = {
    auth: {
      uid: "N6ljgn83doc61zBn4Aqwwnbv92B2",
      token: {
        email: "jordilwbailey@gmail.com",
        email_verified: true,
        admin: true,
        role: "administrator",
        primaryAdmin: true,
      },
    },
  };

  assert.equal(isAdministrator(primaryAdminReq), true);

  // 1. List users includes brand-new Google Sign-in account even before Firestore users doc exists
  const initialRoster = await adminPermCommands.listAdminUsersAndPermissions(primaryAdminReq);
  assert.equal(initialRoster.users.length, 2);
  const joanBefore = initialRoster.users.find((u) => u.email === "ashleynicole062490@gmail.com");
  assert.ok(joanBefore);
  assert.equal(joanBefore.isGoogleSignIn, true);
  assert.equal(joanBefore.shopRole, "none");

  // 2. Primary Admin cannot restrict or remove Admin from jordilwbailey@gmail.com
  await assert.rejects(
      () => adminPermCommands.updateAdminUserPermissions({
        ...primaryAdminReq,
        data: {
          uid: "N6ljgn83doc61zBn4Aqwwnbv92B2",
          restricted: true,
        },
      }),
      /primary Pipe Buyer administrator account cannot be restricted/i,
  );

  // 3. Primary Admin grants Joan Gadin (Google Sign-In, NO SMS MFA) catalog_editor permissions for all affiliate platforms
  const grantResult = await adminPermCommands.updateAdminUserPermissions({
    ...primaryAdminReq,
    data: {
      uid: "M0t7A7npFFZAxLKVlGWxAkztgty2",
      shopRole: "catalog_editor",
      allowedAffiliatePlatforms: ["all"],
      permissions: {
        addAffiliateProducts: true,
        bulkImportCatalog: true,
      },
    },
  });
  assert.equal(grantResult.updated, true);
  assert.equal(grantResult.user.shopRole, "catalog_editor");
  assert.equal(grantResult.user.permissions.addAffiliateProducts, true);
  assert.equal(
      usersByUid.get("M0t7A7npFFZAxLKVlGWxAkztgty2").customClaims.shopRole,
      "catalog_editor",
  );

  // 4. Joan can IMMEDIATELY add Amazon, AliExpress, Lazada, and Shopee products even before JWT refresh!
  const joanPreRefreshReq = {
    auth: {
      uid: "M0t7A7npFFZAxLKVlGWxAkztgty2",
      token: {
        email: "ashleynicole062490@gmail.com",
        email_verified: true,
      },
    },
  };
  const joanSession = await shopCommands.getShopSession(joanPreRefreshReq);
  assert.equal(joanSession.authorized, true);
  assert.equal(joanSession.canManageCatalog, true);

  for (const sample of [
    {id: "amz-1", rawAffiliateInput: "RIDGID Pipe Wrench https://amzn.to/3PipeAmz"},
    {id: "ali-1", rawAffiliateInput: "Ultrasonic Thickness Gauge https://s.click.aliexpress.com/e/_DmAli1"},
    {id: "laz-1", rawAffiliateInput: "Bosch Angle Grinder https://www.lazada.com.ph/products/bosch-grinder-i123456.html"},
    {id: "shp-1", rawAffiliateInput: "Heavy Duty Welding Gloves https://shope.ee/8pShopee1"},
  ]) {
    const res = await shopCommands.upsertShopProduct({
      ...joanPreRefreshReq,
      data: sample,
    });
    assert.equal(res.productId, sample.id);
  }

  const publicCatalog = await shopCommands.listShopStoreCatalog({data: {}});
  assert.equal(publicCatalog.products.length, 4);

  // 5. Admin restricts user -> Store and Marketplace actions fail closed immediately
  const restrictRes = await adminPermCommands.updateAdminUserPermissions({
    ...primaryAdminReq,
    data: {
      uid: "M0t7A7npFFZAxLKVlGWxAkztgty2",
      restricted: true,
      restrictions: ["restrict_store_products", "restrict_marketplace_selling"],
      restrictionReason: "Temporary compliance review",
    },
  });
  assert.equal(restrictRes.user.restricted, true);

  const restrictedSession = await shopCommands.getShopSession({
    auth: {
      uid: "M0t7A7npFFZAxLKVlGWxAkztgty2",
      token: {
        email: "ashleynicole062490@gmail.com",
        email_verified: true,
        ...usersByUid.get("M0t7A7npFFZAxLKVlGWxAkztgty2").customClaims,
      },
    },
  });
  assert.equal(restrictedSession.authorized, false);
  assert.equal(restrictedSession.reason, "restricted");

  assert.throws(
      () => requireAuthenticatedIdentity({
        auth: {
          uid: "M0t7A7npFFZAxLKVlGWxAkztgty2",
          token: {
            email_verified: true,
            restricted: true,
          },
        },
      }),
      /restricted by a Pipe Buyer Administrator/i,
  );

  assert.throws(
      () => assertNotRestrictedFor({
        auth: {
          uid: "u2",
          token: {
            email_verified: true,
            restrictions: ["restrict_messaging_offers"],
          },
        },
      }, "restrict_messaging_offers"),
      /restricted from performing this action/i,
  );
});
