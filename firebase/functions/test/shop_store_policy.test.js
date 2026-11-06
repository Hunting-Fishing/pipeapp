"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  DEFAULT_STORE_SETTINGS,
  SHOP_CATEGORIES,
  buildMonetizedDestinationUrl,
  buildPublicShopProduct,
  extractAmazonAsin,
  normalizeStoreSettings,
  parseAmazonAffiliateSubmission,
  parseSafeHttpsUrl,
  validateShopProductInput,
  validateVendorApplicationInput,
} = require("../shop_store_policy");
const {createShopStoreCommands} = require("../shop_store_commands");

test("extractAmazonAsin parses standalone ASINs and standard Amazon URL shapes", () => {
  assert.equal(extractAmazonAsin("b08xyz1234"), "B08XYZ1234");
  assert.equal(
      extractAmazonAsin("https://www.amazon.com/Milwaukee-2767-20-Impact-Wrench/dp/B077H7JP1D/ref=sr_1_2"),
      "B077H7JP1D",
  );
  assert.equal(
      extractAmazonAsin("https://www.amazon.ca/gp/product/B001P30BVO?th=1"),
      "B001P30BVO",
  );
  assert.equal(
      extractAmazonAsin("https://www.amazon.com/gp/aw/d/B09ABC9876/"),
      "B09ABC9876",
  );
  assert.equal(extractAmazonAsin("https://www.milwaukeetool.com/Products/2767-20"), "");
});

test("buildMonetizedDestinationUrl injects US and CA Amazon Associate tags and respects forceOverride", () => {
  const settings = normalizeStoreSettings({
    amazonAssociateTagUs: "pipebuyer-20",
    amazonAssociateTagCa: "pipebuyerca-20",
    forceOverrideAmazonTag: false,
  });

  const rawProduct = {
    sourceType: "amazon_affiliate",
    categoryCode: "power_hand_tools",
    asin: "B077H7JP1D",
    destinationUrl: "https://www.amazon.com/dp/B077H7JP1D",
  };

  const usUrl = new URL(buildMonetizedDestinationUrl(rawProduct, settings, {regionCode: "US"}));
  assert.equal(usUrl.hostname, "www.amazon.com");
  assert.equal(usUrl.searchParams.get("tag"), "pipebuyer-20");

  const caUrl = new URL(buildMonetizedDestinationUrl(rawProduct, settings, {regionCode: "CA"}));
  assert.equal(caUrl.hostname, "www.amazon.ca");
  assert.equal(caUrl.searchParams.get("tag"), "pipebuyerca-20");

  // Existing tag preserved when forceOverrideAmazonTag is false
  const preTagged = {
    sourceType: "amazon_affiliate",
    destinationUrl: "https://www.amazon.com/dp/B077H7JP1D?tag=custom-campaign-20",
  };
  const preservedUrl = new URL(buildMonetizedDestinationUrl(preTagged, settings));
  assert.equal(preservedUrl.searchParams.get("tag"), "custom-campaign-20");

  // Existing tag overridden when forceOverrideAmazonTag is true
  const overrideSettings = normalizeStoreSettings({
    ...settings,
    forceOverrideAmazonTag: true,
  });
  const overriddenUrl = new URL(buildMonetizedDestinationUrl(preTagged, overrideSettings));
  assert.equal(overriddenUrl.searchParams.get("tag"), "pipebuyer-20");

  // Short amzn.to and link.amazon links stay intact
  assert.equal(
      buildMonetizedDestinationUrl(
          {sourceType: "amazon_affiliate", destinationUrl: "https://amzn.to/3PipeGear"},
          overrideSettings,
      ),
      "https://amzn.to/3PipeGear",
  );
  assert.equal(
      buildMonetizedDestinationUrl(
          {sourceType: "amazon_affiliate", destinationUrl: "https://link.amazon/B0iZoQG46"},
          overrideSettings,
      ),
      "https://link.amazon/B0iZoQG46",
  );
  const parsedLinkAmazon = parseAmazonAffiliateSubmission(
      "https://link.amazon/B0iZoQG46",
      overrideSettings,
  );
  assert.equal(parsedLinkAmazon.isAmazonLink, true);
  assert.equal(parsedLinkAmazon.isShortLink, true);
  assert.equal(parsedLinkAmazon.monetizedPreviewUs, "https://link.amazon/B0iZoQG46");
});

test("buildMonetizedDestinationUrl appends clean UTM attribution for brand partners and distributors", () => {
  const milwaukeePartner = {
    sourceType: "brand_partner",
    categoryCode: "power_hand_tools",
    destinationUrl: "https://www.milwaukeetool.com/Products/Power-Tools/Fastening/2767-20?irclickid=abc123",
  };
  const result = new URL(buildMonetizedDestinationUrl(milwaukeePartner, DEFAULT_STORE_SETTINGS));
  assert.equal(result.searchParams.get("irclickid"), "abc123");
  assert.equal(result.searchParams.get("utm_source"), "pipebuyer");
  assert.equal(result.searchParams.get("utm_medium"), "affiliate_store");
  assert.equal(result.searchParams.get("utm_campaign"), "power_hand_tools");
});

test("parseSafeHttpsUrl blocks non-HTTPS, localhost, private IPs, and embedded credentials", () => {
  assert.throws(() => parseSafeHttpsUrl("http://www.amazon.com/dp/B077H7JP1D"), /HTTPS/);
  assert.throws(() => parseSafeHttpsUrl("javascript:alert(1)"), /HTTPS/);
  assert.throws(() => parseSafeHttpsUrl("https://localhost:8080/deal"), /public domain/);
  assert.throws(() => parseSafeHttpsUrl("https://192.168.1.10/deal"), /public domain/);
  assert.throws(() => parseSafeHttpsUrl("https://10.0.0.1/deal"), /public domain/);
  assert.throws(() => parseSafeHttpsUrl("https://user:pass@amazon.com/dp/B077H7JP1D"), /credentials/);
});

test("validateShopProductInput and buildPublicShopProduct normalize active vs paused items", () => {
  assert.equal(SHOP_CATEGORIES.length >= 8, true);

  const normalized = validateShopProductInput({
    title: "RIDGID 31040 Model 48 Heavy-Duty Straight Pipe Wrench",
    brand: "RIDGID",
    sourceType: "amazon_affiliate",
    categoryCode: "pipe_welding_fab",
    asin: "B0000224J8",
    priceDisplay: "$249.00",
    badgeText: "Pipeline Standard",
    featured: true,
    highlights: ["48-inch ductile-iron housing", "6-inch pipe capacity"],
  });

  assert.equal(normalized.asin, "B0000224J8");
  assert.equal(normalized.destinationUrl, "https://www.amazon.com/dp/B0000224J8");
  assert.equal(normalized.marketplaceCategories.includes("Pipe"), true);
  assert.equal(normalized.searchTokens.includes("ridgid"), true);

  const projected = buildPublicShopProduct("ridgid-48", normalized, DEFAULT_STORE_SETTINGS);
  assert.ok(projected);
  assert.match(projected.destinationUrl, /tag=pipebuyer-20/);
  assert.match(projected.destinationUrlCa, /amazon\.ca/);

  const paused = buildPublicShopProduct("ridgid-48", {...normalized, status: "paused"});
  assert.equal(paused, null);
});

test("validateVendorApplicationInput enforces business fields and categories", () => {
  const valid = validateVendorApplicationInput(
      {
        companyName: "Milwaukee Industrial Authorized Supply",
        contactName: "Dana Mercer",
        email: "dana@industrial-tools.example.com",
        phone: "+1 (780) 555-0192",
        websiteUrl: "industrial-tools.example.com",
        partnershipTrack: "brand_manufacturer",
        categories: ["power_hand_tools", "pipe_welding_fab"],
        brandsCarried: ["Milwaukee", "RIDGID"],
        fulfillmentRegions: ["US", "CA"],
        estimatedSkuCount: "250+ SKUs",
      },
      "uid_applicant_1",
  );
  assert.equal(valid.status, "pending");
  assert.equal(valid.websiteUrl, "https://industrial-tools.example.com/");
  assert.deepEqual(valid.categories, ["power_hand_tools", "pipe_welding_fab"]);

  assert.throws(
      () => validateVendorApplicationInput({companyName: "A"}, "uid_1"),
      /Company or brand name/,
  );
});

test("createShopStoreCommands projects products, updates associate tags, and approves vendors", async () => {
  const store = new Map();

  function docKey(col, id) {
    return `${col}/${id}`;
  }

  function makeDocRef(col, id) {
    return {
      id,
      _col: col,
      async get() {
        const key = docKey(col, id);
        const val = store.get(key);
        return {
          id,
          exists: val !== undefined,
          data: () => (val ? {...val} : undefined),
        };
      },
      async set(data, opts) {
        const key = docKey(col, id);
        const prev = opts && opts.merge ? store.get(key) || {} : {};
        store.set(key, {...prev, ...data});
      },
      async update(data) {
        const key = docKey(col, id);
        const prev = store.get(key) || {};
        store.set(key, {...prev, ...data});
      },
      async delete() {
        store.delete(docKey(col, id));
      },
      collection(subCol) {
        return makeCollection(`${col}/${id}/${subCol}`);
      },
    };
  }

  let autoCounter = 0;
  function makeCollection(col) {
    const queryApi = (predicate = () => true) => ({
      where(field, op, expected) {
        return queryApi((data) => {
          if (!predicate(data)) return false;
          if (op === "==") return data[field] === expected;
          return true;
        });
      },
      orderBy() {
        return queryApi(predicate);
      },
      limit() {
        return queryApi(predicate);
      },
      async get() {
        const prefix = `${col}/`;
        const docs = [];
        for (const [key, val] of store.entries()) {
          if (key.startsWith(prefix)) {
            const rest = key.slice(prefix.length);
            if (!rest.includes("/") && predicate(val)) {
              docs.push({
                id: rest,
                data: () => ({...val}),
              });
            }
          }
        }
        return {
          empty: docs.length === 0,
          size: docs.length,
          docs,
        };
      },
    });

    return {
      ...queryApi(),
      doc(id) {
        const effectiveId = id || `auto_${++autoCounter}`;
        return makeDocRef(col, effectiveId);
      },
      async add(data) {
        const ref = makeDocRef(col, `auto_${++autoCounter}`);
        await ref.set(data);
        return ref;
      },
    };
  }

  const fakeDb = {
    collection: (col) => makeCollection(col),
    batch() {
      const ops = [];
      return {
        set(ref, data, opts) {
          ops.push(() => ref.set(data, opts));
        },
        update(ref, data) {
          ops.push(() => ref.update(data));
        },
        delete(ref) {
          ops.push(() => ref.delete());
        },
        async commit() {
          for (const op of ops) await op();
        },
      };
    },
    async runTransaction(fn) {
      return fn({
        get: (ref) => ref.get(),
        set: (ref, data, opts) => ref.set(data, opts),
      });
    },
  };

  const mockAdmin = {
    firestore: Object.assign(() => fakeDb, {
      FieldValue: {
        serverTimestamp: () => "SERVER_TS",
        increment: (n) => n,
      },
      Timestamp: {
        now: () => ({toMillis: () => Date.now()}),
        fromMillis: (ms) => ({toMillis: () => ms}),
      },
    }),
  };

  const notifications = [];
  const commands = createShopStoreCommands(mockAdmin, {
    notifyAdministrators: async (payload) => notifications.push(payload),
  });

  const adminRequest = {
    auth: {
      uid: "admin_1",
      token: {
        admin: true,
        role: "administrator",
        email_verified: true,
        firebase: {sign_in_second_factor: "phone"},
      },
    },
  };

  // 1. Admin creates an active Amazon affiliate item
  const created = await commands.upsertShopProduct({
    ...adminRequest,
    data: {
      id: "milwaukee-m18-impact",
      title: "Milwaukee M18 FUEL 1/2 High-Torque Impact Wrench",
      brand: "Milwaukee",
      sourceType: "amazon_affiliate",
      categoryCode: "power_hand_tools",
      asin: "B077H7JP1D",
      featured: true,
    },
  });
  assert.equal(created.productId, "milwaukee-m18-impact");

  // 2. Admin updates US Associate Tag -> public projection updates immediately
  await commands.updateShopStoreSettings({
    ...adminRequest,
    data: {
      amazonAssociateTagUs: "pipebuyer-live-20",
      amazonAssociateTagCa: "pipebuyer-ca-20",
    },
  });

  const catalog = await commands.listShopStoreCatalog({data: {}});
  assert.equal(catalog.products.length, 1);
  assert.match(catalog.products[0].destinationUrl, /tag=pipebuyer-live-20/);
  assert.match(catalog.products[0].destinationUrlCa, /tag=pipebuyer-ca-20/);

  // 3. Record click telemetry
  const clickRes = await commands.recordShopAffiliateClick({
    data: {
      productId: "milwaukee-m18-impact",
      categoryCode: "power_hand_tools",
      sourceType: "amazon_affiliate",
      brand: "Milwaukee",
      placement: "store_grid",
    },
  });
  assert.equal(clickRes.recorded, true);

  // 4. Distributor / Brand submits vendor application & Admin approves
  const applicantReq = {
    auth: {
      uid: "vendor_user_1",
      token: {email_verified: true},
    },
    data: {
      companyName: "Apex Rigging & Milwaukee Supply",
      contactName: "Jordan Vance",
      email: "jordan@apexrigging.example.com",
      phone: "+1-403-555-0199",
      websiteUrl: "https://apexrigging.example.com",
      partnershipTrack: "industrial_distributor",
      categories: ["rigging_hauling_cargo", "power_hand_tools"],
      brandsCarried: ["Milwaukee", "Crosby"],
    },
  };
  const appSubmitted = await commands.submitShopVendorApplication(applicantReq);
  assert.equal(appSubmitted.status, "pending");
  assert.equal(notifications.length, 1);

  const reviewed = await commands.reviewShopVendorApplication({
    ...adminRequest,
    data: {
      applicationId: appSubmitted.applicationId,
      status: "approved",
      reviewNotes: "Authorized regional distributor verified.",
    },
  });
  assert.equal(reviewed.status, "approved");
  assert.ok(reviewed.vendorId);

  const catalogAfterVendor = await commands.listShopStoreCatalog({data: {}});
  assert.equal(catalogAfterVendor.vendors.length, 1);
  assert.equal(catalogAfterVendor.vendors[0].companyName, "Apex Rigging & Milwaukee Supply");
});

test("parseAmazonAffiliateSubmission handles SiteStripe short links, full links, HTML snippets, and mobile share text", () => {
  const settings = normalizeStoreSettings({
    amazonAssociateTagUs: "pipebuyer-20",
    amazonAssociateTagCa: "pipebuyer0c-20",
  });

  // 1. SiteStripe Full Link with URL slug + linkCode + linkId
  const fullSiteStripe = parseAmazonAffiliateSubmission(
      "https://www.amazon.com/RIDGID-31020-Heavy-Duty-Straight-Wrench/dp/B0000224J8?linkCode=ll1&tag=pipebuyer-20&linkId=abc123&language=en_US&ref_=as_li_ss_tl",
      settings,
  );
  assert.equal(fullSiteStripe.asin, "B0000224J8");
  assert.equal(fullSiteStripe.suggestedBrand, "RIDGID");
  assert.equal(fullSiteStripe.suggestedCategoryCode, "pipe_welding_fab");
  assert.match(fullSiteStripe.suggestedTitle, /RIDGID 31020 Heavy Duty Straight Wrench/i);
  assert.equal(fullSiteStripe.effectiveAssociateTag, "pipebuyer-20");
  assert.match(fullSiteStripe.monetizedPreviewUs, /linkCode=ll1/);

  // 2. Amazon Mobile App Associate Share text + amzn.to short link
  const mobileShare = parseAmazonAffiliateSubmission(
      "Check this out on Amazon: Crosby 3/4 Screw Pin Anchor Shackle Rigging https://amzn.to/3XyZ789",
      settings,
  );
  assert.equal(mobileShare.destinationUrl, "https://amzn.to/3XyZ789");
  assert.equal(mobileShare.isShortLink, true);
  assert.equal(mobileShare.suggestedBrand, "Crosby");
  assert.equal(mobileShare.suggestedCategoryCode, "rigging_hauling_cargo");
  assert.match(mobileShare.suggestedTitle, /Crosby 3\/4 Screw Pin Anchor Shackle Rigging/);

  // 3. Associates Central HTML <a href> + <img src> with &amp; entities
  const htmlSnippet = parseAmazonAffiliateSubmission(
      `<a target="_blank" href="https://www.amazon.com/dp/B077H7JP1D?linkCode=li2&amp;tag=pipebuyer-20"><img border="0" src="https://m.media-amazon.com/images/I/71abcXYZ._AC_SL1500_.jpg" />Milwaukee M18 FUEL High Torque Impact</a><img src="https://ir-na.amazon-adsystem.com/e/ir?t=pipebuyer-20" width="1" height="1" />`,
      settings,
  );
  assert.equal(htmlSnippet.asin, "B077H7JP1D");
  assert.equal(htmlSnippet.imageUrl, "https://m.media-amazon.com/images/I/71abcXYZ._AC_SL1500_.jpg");
  assert.equal(htmlSnippet.suggestedBrand, "Milwaukee");
  assert.equal(htmlSnippet.suggestedTitle, "Milwaukee M18 FUEL High Torque Impact");
  assert.equal(htmlSnippet.embeddedAssociateTag, "pipebuyer-20");

  // 4. Bare 10-char ASIN
  const bareAsin = parseAmazonAffiliateSubmission("b0000224j8", settings);
  assert.equal(bareAsin.asin, "B0000224J8");
  assert.equal(bareAsin.destinationUrl, "https://www.amazon.com/dp/B0000224J8");
  assert.match(bareAsin.monetizedPreviewUs, /tag=pipebuyer-20/);
  assert.match(bareAsin.monetizedPreviewCa, /amazon\.ca\/dp\/B0000224J8\?tag=pipebuyer0c-20/);
});

test("Store roles (Admin like jordilwbailey@gmail.com + Catalog Editor) can add and remove affiliate links", async () => {
  const store = new Map();
  let autoCounter = 0;

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
        return makeDocRef(col, id || `auto_${++autoCounter}`);
      },
      async add(data) {
        const ref = makeDocRef(col, `auto_${++autoCounter}`);
        await ref.set(data);
        return ref;
      },
    };
  }

  const fakeUsersByEmail = new Map([
    [
      "editor@pipebuyer.example.com",
      {
        uid: "editor_uid_1",
        email: "editor@pipebuyer.example.com",
        displayName: "Shop Editor",
        emailVerified: true,
        multiFactor: {enrolledFactors: [{uid: "mfa_1"}]},
        customClaims: {accountType: "business"},
      },
    ],
  ]);

  const mockAdmin = {
    auth: () => ({
      async getUserByEmail(email) {
        const found = fakeUsersByEmail.get(email);
        if (!found) {
          const err = new Error("not found");
          err.code = "auth/user-not-found";
          throw err;
        }
        return found;
      },
      async setCustomUserClaims(uid, claims) {
        for (const u of fakeUsersByEmail.values()) {
          if (u.uid === uid) u.customClaims = claims;
        }
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
          Timestamp: {
            now: () => ({toMillis: () => Date.now()}),
            fromMillis: (ms) => ({toMillis: () => ms}),
          },
        },
    ),
  };

  const commands = createShopStoreCommands(mockAdmin);

  // Admin account (e.g. jordilwbailey@gmail.com with admin: true, role: administrator + MFA)
  const jordiAdminReq = {
    auth: {
      uid: "jordi_admin_uid",
      token: {
        email: "jordilwbailey@gmail.com",
        email_verified: true,
        admin: true,
        role: "administrator",
        firebase: {sign_in_second_factor: "totp"},
      },
    },
  };

  // Admin without MFA gets clear mfa_required session reason
  const missingMfaSession = await commands.getShopSession({
    auth: {
      uid: "jordi_admin_uid",
      token: {
        email: "jordilwbailey@gmail.com",
        email_verified: true,
        admin: true,
        role: "administrator",
        firebase: {},
      },
    },
  });
  assert.equal(missingMfaSession.authorized, false);
  assert.equal(missingMfaSession.reason, "mfa_required");

  // Full MFA Admin gets full Store capabilities
  const adminSession = await commands.getShopSession(jordiAdminReq);
  assert.equal(adminSession.authorized, true);
  assert.equal(adminSession.role, "administrator");
  assert.equal(adminSession.canManageCatalog, true);
  assert.equal(adminSession.canManageSettingsAndRoles, true);

  // Admin grants catalog_editor role to team member
  const staffGrant = await commands.manageShopStaff({
    ...jordiAdminReq,
    data: {
      email: "editor@pipebuyer.example.com",
      role: "catalog_editor",
      active: true,
    },
  });
  assert.equal(staffGrant.role, "catalog_editor");
  assert.equal(
      fakeUsersByEmail.get("editor@pipebuyer.example.com").customClaims.shopRole,
      "catalog_editor",
  );

  // Catalog editor can add a SiteStripe affiliate link via rawAffiliateInput
  const editorReq = {
    auth: {
      uid: "editor_uid_1",
      token: {
        email: "editor@pipebuyer.example.com",
        email_verified: true,
        shopRole: "catalog_editor",
        firebase: {sign_in_second_factor: "phone"},
      },
    },
  };
  const added = await commands.upsertShopProduct({
    ...editorReq,
    data: {
      id: "lincoln-viking-helmet",
      rawAffiliateInput:
        "Lincoln Electric Viking 3350 Welding Helmet https://amzn.to/4abcDEF",
    },
  });
  assert.equal(added.productId, "lincoln-viking-helmet");
  assert.equal(added.product.brand, "Lincoln Electric");
  assert.equal(added.product.categoryCode, "pipe_welding_fab");

  // Catalog editor CANNOT overwrite global Store Associate tags (admin-only)
  await assert.rejects(
      () => commands.updateShopStoreSettings({
        ...editorReq,
        data: {amazonAssociateTagUs: "unauthorized-20"},
      }),
      /Only a PipeBuyer Administrator/,
  );

  // Admin removes both custom link AND a starter catalog link
  await commands.deleteShopProduct({
    ...jordiAdminReq,
    data: {productId: "lincoln-viking-helmet"},
  });
  await commands.deleteShopProduct({
    ...jordiAdminReq,
    data: {productId: "starter-ridgid-31020-pipe-wrench"},
  });

  const afterRemoveCatalog = await commands.listShopStoreCatalog({data: {}});
  assert.equal(afterRemoveCatalog.products.length, 0);
  assert.ok(
      afterRemoveCatalog.suppressedProductIds.includes(
          "starter-ridgid-31020-pipe-wrench",
      ),
  );

  // Admin can restore removed starter links anytime
  const restored = await commands.restoreStarterShopProducts({
    ...jordiAdminReq,
    data: {productId: "starter-ridgid-31020-pipe-wrench"},
  });
  assert.ok(!restored.hiddenStarterIds.includes("starter-ridgid-31020-pipe-wrench"));

  // Bulk spreadsheet import publishes filled link rows and skips blank pending rows
  const bulkRes = await commands.bulkUpsertShopProducts({
    ...jordiAdminReq,
    data: {
      items: [
        {
          id: "pb-0025-ridgid-824",
          categoryCode: "pipe_welding_fab",
          subcategory: "Pipe Wrenches, Chain Tongs & Vises",
          title: "RIDGID 31105 Model 824 24-Inch Aluminum Straight Pipe Wrench",
          brand: "RIDGID",
          rawAffiliateInput: "https://amzn.to/3XYZPipe",
        },
        {
          id: "pb-0026-pending-blank",
          categoryCode: "pipe_welding_fab",
          subcategory: "Pipe Cutting, Threading & Beveling",
          title: "RIDGID 32820 Model 2-A Heavy-Duty Pipe Cutter",
          brand: "RIDGID",
          rawAffiliateInput: "",
          destinationUrl: "",
        },
      ],
    },
  });
  assert.equal(bulkRes.importedCount, 1);
  assert.equal(bulkRes.skippedBlankCount, 1);

  const subFiltered = await commands.listShopStoreCatalog({
    data: {
      categoryCode: "pipe_welding_fab",
      subcategory: "Pipe Wrenches, Chain Tongs & Vises",
    },
  });
  assert.equal(subFiltered.products.length, 1);
  assert.equal(subFiltered.products[0].id, "pb-0025-ridgid-824");
});

test("SHOP_CATEGORIES defines 8 categories and 48 trade subcategories", () => {
  assert.equal(SHOP_CATEGORIES.length, 8);
  const allSubs = SHOP_CATEGORIES.flatMap((c) => c.subcategories || []);
  assert.equal(allSubs.length, 48);
  assert.equal(new Set(allSubs).size, 48);
});
