"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  GLOBAL_COUNTRIES_LIST,
  WORLD_CONTINENTS,
  YELLOW_PAGES_CATEGORIES,
  canonicalizeCityName,
  canonicalizeCompanyName,
  classifyCategoriesFromText,
  countryCodesForContinent,
  expandServiceSearchTerms,
  inferCountryAndRegion,
  inferGeoFromNanpaPhone,
} = require("../yellow_pages_taxonomy");
const {createYellowPagesCommands} = require("../yellow_pages_commands");
const {
  buildAdminSearchTokens,
  buildPublicEntry,
  computePriorityScore,
  isPublicEntryCurrent,
  normalizeGlobalPhone,
  normalizeNorthAmericanPhone,
  normalizePhoneHistory,
  resolveEffectiveTier,
} = require("../yellow_pages_policy");

test("normalizes North American phone numbers and tracks legacy-to-new history", () => {
  const local = normalizeNorthAmericanPhone("780-458-0248");
  assert.equal(local.digits10, "7804580248");
  assert.equal(local.e164, "+17804580248");
  assert.equal(local.display, "(780) 458-0248");
  assert.equal(local.validNanpa, true);
  assert.equal(local.isTollFree, false);

  const tollFree = normalizeNorthAmericanPhone("1 (800) 555-2368");
  assert.equal(tollFree.isTollFree, true);
  assert.equal(tollFree.validNanpa, true);

  const history = normalizePhoneHistory([], ["403-222-3333"], "780-458-0248");
  assert.equal(history.length, 2);
  assert.equal(history[0].status, "current_active");
  assert.equal(history[0].digits10, "7804580248");
  assert.equal(history[1].status, "legacy_replaced");
  assert.equal(history[1].digits10, "4032223333");
});

test("expands oilfield slang queries and classifies service categories", () => {
  const vac = expandServiceSearchTerms("hydrovac");
  assert.ok(vac.terms.includes("vacuum"));
  assert.ok(vac.matchedCategoryCodes.includes("vacuum_hydrovac_fluid"));

  const ndt = expandServiceSearchTerms("ndt tubing inspection");
  assert.ok(ndt.matchedCategoryCodes.includes("pipe_inspection_ndt"));

  const codes = classifyCategoriesFromText(
      ["Winch Truck", "Rig Moving", "B Pressure Welding"],
      "24/7 heavy haul across Alberta and Texas",
  );
  assert.ok(codes.includes("trucking_heavy_haul"));
  assert.ok(codes.includes("welding_machining_fab"));
});

test("enforces paid vs unpaid priority ranking, visibility toggle, and flagged prohibition", () => {
  const now = Date.parse("2026-10-25T00:00:00Z");
  const futurePaid = "2027-10-25T00:00:00Z";

  const featuredCompany = {
    companyName: "Apex Hydrovac & Rig Moving Ltd.",
    countryCode: "CA",
    regionCode: "AB",
    city: "Grande Prairie",
    mainPhone: "780-532-4400",
    publicPhone: "780-532-4400",
    website: "https://apexoilfield.example.ca",
    publicEmail: "dispatch@apexoilfield.example.ca",
    categories: ["Vacuum Trucks", "Rig Moving"],
    services: ["24/7 Hydrovac", "Combo Vac", "Heavy Haul"],
    certifications: ["COR", "ISNetworld", "ComplyWorks"],
    emergency24x7: true,
    verificationStatus: "verified",
    operationalStatus: "active_in_operation",
    billingStatus: "paid",
    listingTier: "featured_platinum",
    paidThrough: futurePaid,
    publicationStatus: "published",
    adminViewingEnabled: true,
    isFlaggedProhibited: false,
  };

  const paidProCompany = {
    ...featuredCompany,
    companyName: "Permian Wellhead & Valve Inc.",
    countryCode: "US",
    regionCode: "TX",
    city: "Midland",
    listingTier: "paid_verified",
  };

  const unpaidVerifiedCompany = {
    ...featuredCompany,
    companyName: "Peace Country Pipe Inspection Ltd.",
    billingStatus: "unpaid",
    listingTier: "free_verified",
    paidThrough: null,
  };

  const featuredEntry = buildPublicEntry(featuredCompany, "comp-1", "SERVER_TS", now);
  const paidProEntry = buildPublicEntry(paidProCompany, "comp-2", "SERVER_TS", now);
  const freeEntry = buildPublicEntry(unpaidVerifiedCompany, "comp-3", "SERVER_TS", now);

  assert.equal(featuredEntry.effectiveTier, "featured_platinum");
  assert.equal(featuredEntry.isFeatured, true);
  assert.equal(featuredEntry.isPaidTier, true);
  assert.equal(featuredEntry.claimable, false);
  assert.ok(featuredEntry.website.includes("apexoilfield"));

  assert.equal(paidProEntry.effectiveTier, "paid_verified");
  assert.equal(paidProEntry.countryCode, "US");
  assert.equal(paidProEntry.regionCode, "TX");

  // Basic Verified (Unpaid) shows audited name/city/phone below paid tiers, without website SEO link
  assert.equal(freeEntry.effectiveTier, "free_verified");
  assert.equal(freeEntry.isPaidTier, false);
  assert.equal(freeEntry.claimable, true);
  assert.equal(freeEntry.website, "");
  assert.equal(freeEntry.publicEmail, "");

  assert.ok(featuredEntry.priorityScore > paidProEntry.priorityScore ||
    computePriorityScore(featuredCompany, "featured_platinum") > computePriorityScore(paidProCompany, "paid_verified"));
  assert.ok(paidProEntry.priorityScore > freeEntry.priorityScore);

  // Turning Admin Viewing OFF hides company immediately
  const hiddenEntry = buildPublicEntry(
      {...featuredCompany, adminViewingEnabled: false},
      "comp-hidden",
      "SERVER_TS",
      now,
  );
  assert.equal(hiddenEntry, null);

  // Flagging a prohibited business blocks public projection even if paid
  const flaggedEntry = buildPublicEntry(
      {...featuredCompany, isFlaggedProhibited: true},
      "comp-flagged",
      "SERVER_TS",
      now,
  );
  assert.equal(flaggedEntry, null);
  assert.equal(resolveEffectiveTier({...featuredCompany, operationalStatus: "closed_inactive"}, now), null);
  assert.equal(isPublicEntryCurrent(featuredEntry, now), true);
  assert.equal(isPublicEntryCurrent(freeEntry, now), true);

  // Admin search tokens include both legacy (2015/2016) and current phone numbers
  const adminTokens = buildAdminSearchTokens({
    ...featuredCompany,
    legacyPhones: ["(403) 777-8899"],
  });
  assert.ok(adminTokens.includes("7805324400"));
  assert.ok(adminTokens.includes("4037778899"));

  const usGeo = inferCountryAndRegion("", "Texas");
  assert.equal(usGeo.countryCode, "US");
  assert.equal(usGeo.regionCode, "TX");
});

test("supports global 197-country taxonomy, Middle East + Continent filters, and E.164 international phone numbers", () => {
  assert.ok(GLOBAL_COUNTRIES_LIST.length >= 195);
  assert.equal(WORLD_CONTINENTS.length, 7);

  const naCodes = countryCodesForContinent("north_america");
  assert.equal(naCodes.length, 23);
  assert.ok(naCodes.includes("CA"));
  assert.ok(naCodes.includes("US"));
  assert.ok(naCodes.includes("MX"));
  assert.ok(naCodes.includes("TT"));

  const meCodes = countryCodesForContinent("middle_east");
  const asiaCodes = countryCodesForContinent("asia");
  assert.ok(meCodes.includes("AE"));
  assert.ok(meCodes.includes("SA"));
  assert.ok(asiaCodes.includes("AE"));
  assert.ok(asiaCodes.includes("SA"));

  const ukPhone = normalizeGlobalPhone("+44 1224 723456", "GB");
  assert.equal(ukPhone.validPhone, true);
  assert.equal(ukPhone.e164, "+441224723456");

  const uaePhone = normalizeGlobalPhone("02 554 1234", "AE");
  assert.equal(uaePhone.validPhone, true);
  assert.equal(uaePhone.e164, "+97125541234");

  const mxPhone = normalizeGlobalPhone("+52 938 382 1400", "MX");
  assert.equal(mxPhone.validPhone, true);
  assert.equal(mxPhone.e164, "+529383821400");

  const uaeEntry = buildPublicEntry({
    companyName: "Gulf Offshore Well Services LLC",
    countryCode: "AE",
    regionCode: "AZ",
    city: "Abu Dhabi",
    mainPhone: "+971 2 554 1234",
    publicPhone: "+971 2 554 1234",
    categories: ["Wellheads, Valves & Pressure Control"],
    services: ["Wellhead Maintenance", "BOP Testing"],
    verificationStatus: "verified",
    operationalStatus: "active_in_operation",
    billingStatus: "unpaid",
    listingTier: "free_verified",
    publicationStatus: "published",
    adminViewingEnabled: true,
    isFlaggedProhibited: false,
  }, "comp-uae-1", "SERVER_TS");

  assert.equal(uaeEntry.countryCode, "AE");
  assert.equal(uaeEntry.countryName, "United Arab Emirates");
  assert.equal(uaeEntry.continentCode, "asia");
  assert.equal(uaeEntry.isMiddleEast, true);
  assert.ok(uaeEntry.searchTokens.includes("emirates"));
  assert.ok(uaeEntry.searchTokens.includes("middle"));
});

test("canonicalizes oilfield town spellings and aggregates live business counts per town, region, country, and continent", async () => {
  assert.equal(canonicalizeCityName("Ft McMurray", "AB", "CA"), "Fort McMurray");
  assert.equal(canonicalizeCityName("Fort Mcmurray", "AB", "CA"), "Fort McMurray");
  assert.equal(canonicalizeCityName("HOUSTON", "TX", "US"), "Houston");
  assert.equal(canonicalizeCityName("Fort St John", "BC", "CA"), "Fort St. John");
  assert.equal(canonicalizeCityName("Saint Albert", "AB", "CA"), "St. Albert");
  assert.equal(canonicalizeCityName("CALGARY ALBERTA", "AB", "CA"), "Calgary");

  const sampleDocs = [
    buildPublicEntry({
      companyName: "Apex Hydrovac GP",
      countryCode: "CA",
      regionCode: "AB",
      city: "Grande Prairie",
      mainPhone: "780-555-0101",
      publicPhone: "780-555-0101",
      categories: ["Vacuum, Hydrovac & Fluid Hauling"],
      verificationStatus: "verified",
      operationalStatus: "active_in_operation",
      billingStatus: "unpaid",
      listingTier: "free_verified",
      publicationStatus: "published",
      adminViewingEnabled: true,
      isFlaggedProhibited: false,
    }, "c1", "TS"),
    buildPublicEntry({
      companyName: "Peace Rig Hauling",
      countryCode: "CA",
      regionCode: "AB",
      city: "Grande Prairie",
      mainPhone: "780-555-0102",
      publicPhone: "780-555-0102",
      categories: ["Trucking, Towing, Winch & Heavy Haul"],
      verificationStatus: "verified",
      operationalStatus: "active_in_operation",
      billingStatus: "unpaid",
      listingTier: "free_verified",
      publicationStatus: "published",
      adminViewingEnabled: true,
      isFlaggedProhibited: false,
    }, "c2", "TS"),
    buildPublicEntry({
      companyName: "Athabasca Oil Sands Wireline",
      countryCode: "CA",
      regionCode: "AB",
      city: "Ft McMurray",
      mainPhone: "780-555-0103",
      publicPhone: "780-555-0103",
      categories: ["Completions, Frac, Coiled Tubing & Wireline"],
      verificationStatus: "verified",
      operationalStatus: "active_in_operation",
      billingStatus: "unpaid",
      listingTier: "free_verified",
      publicationStatus: "published",
      adminViewingEnabled: true,
      isFlaggedProhibited: false,
    }, "c3", "TS"),
    buildPublicEntry({
      companyName: "Gulf Offshore Tubulars",
      countryCode: "AE",
      regionCode: "AZ",
      city: "Abu Dhabi",
      mainPhone: "+971 2 554 1234",
      publicPhone: "+971 2 554 1234",
      categories: ["Pipe, OCTG, Casing & Tubulars"],
      verificationStatus: "verified",
      operationalStatus: "active_in_operation",
      billingStatus: "unpaid",
      listingTier: "free_verified",
      publicationStatus: "published",
      adminViewingEnabled: true,
      isFlaggedProhibited: false,
    }, "c4", "TS"),
  ];

  const metaStore = new Map();
  const fakeAdmin = {
    firestore: Object.assign(() => ({
      collection(name) {
        if (name === "yellow_pages_meta") {
          return {
            doc(id) {
              return {
                async get() {
                  return {
                    exists: metaStore.has(id),
                    data: () => metaStore.get(id),
                  };
                },
                async set(val) {
                  metaStore.set(id, val);
                },
              };
            },
          };
        }
        return {
          limit() {
            return {
              async get() {
                return {docs: sampleDocs.map((d, i) => ({id: `c${i + 1}`, data: () => d}))};
              },
            };
          },
        };
      },
    }), {
      FieldValue: {
        serverTimestamp: () => "SERVER_TS",
        increment: (n) => n,
      },
    }),
    auth: () => ({}),
  };

  const commands = createYellowPagesCommands(fakeAdmin);
  const tax = await commands.getYellowPagesTaxonomy({});
  assert.equal(tax.counts.totalBusinesses, 4);
  assert.equal(tax.counts.byCountry.CA, 3);
  assert.equal(tax.counts.byCountry.AE, 1);
  assert.equal(tax.counts.byContinent.north_america, 3);
  assert.equal(tax.counts.byContinent.middle_east, 1);
  assert.equal(tax.counts.byContinent.asia, 1);
  assert.equal(tax.counts.byRegion["CA:AB"], 3);
  assert.equal(tax.counts.byRegion["AE:AZ"], 1);
  const gpTown = tax.counts.towns.find((t) => t[0] === "Grande Prairie");
  const fmTown = tax.counts.towns.find((t) => t[0] === "Fort McMurray");
  assert.deepEqual(gpTown, ["Grande Prairie", "AB", "CA", 2]);
  assert.deepEqual(fmTown, ["Fort McMurray", "AB", "CA", 1]);
});

test("keeps crawled unverified companies published as free_basic (verified=false) without pre-verification and ranks admin-verified companies higher", async () => {
  const now = Date.parse("2026-10-26T00:00:00Z");

  const crawledUnverifiedCompany = {
    companyName: "Red Deer Wireline & Slickline Ltd.",
    countryCode: "CA",
    regionCode: "AB",
    city: "Red Deer",
    mainPhone: "403-555-0199",
    publicPhone: "403-555-0199",
    categories: ["Completions, Frac, Coiled Tubing & Wireline"],
    services: ["Slickline", "Wireline"],
    verificationStatus: "unverified",
    operationalStatus: "active_in_operation",
    billingStatus: "unpaid",
    listingTier: "free_basic",
    publicationStatus: "published",
    adminViewingEnabled: true,
    isFlaggedProhibited: false,
  };

  const adminVerifiedCompany = {
    ...crawledUnverifiedCompany,
    companyName: "Leduc Pressure Control Ltd.",
    city: "Leduc",
    verificationStatus: "verified",
    listingTier: "free_verified",
  };

  const basicEntry = buildPublicEntry(crawledUnverifiedCompany, "comp-basic", "TS", now);
  const verifiedEntry = buildPublicEntry(adminVerifiedCompany, "comp-ver", "TS", now);

  assert.ok(basicEntry, "unverified published company should still build a public entry");
  assert.equal(basicEntry.effectiveTier, "free_basic");
  assert.equal(basicEntry.verified, false);
  assert.equal(isPublicEntryCurrent(basicEntry, now), true);

  assert.equal(verifiedEntry.effectiveTier, "free_verified");
  assert.equal(verifiedEntry.verified, true);
  assert.equal(isPublicEntryCurrent(verifiedEntry, now), true);
  assert.ok(
      verifiedEntry.priorityScore > basicEntry.priorityScore,
      "genuinely verified unpaid listings outrank unverified basic listings",
  );

  // Rejected or inactive verification status never publishes publicly
  assert.equal(
      buildPublicEntry({...crawledUnverifiedCompany, verificationStatus: "rejected"}, "c-rej", "TS", now),
      null,
  );
  assert.equal(
      buildPublicEntry({...crawledUnverifiedCompany, verificationStatus: "inactive"}, "c-inact", "TS", now),
      null,
  );

  // Search tierFilter === "verified_only" returns only verified === true entries
  const publicDocs = [basicEntry, verifiedEntry];
  const fakeAdmin = {
    firestore: Object.assign(() => ({
      collection() {
        const makeChain = (items) => ({
          where(field, op, val) {
            const filtered = items.filter((it) => op === "==" ? it[field] === val : true);
            return makeChain(filtered);
          },
          limit() {
            return {
              async get() {
                return {docs: items.map((d, idx) => ({id: d.companyId || `id-${idx}`, data: () => d}))};
              },
            };
          },
        });
        return makeChain(publicDocs);
      },
    }), {
      FieldValue: {
        serverTimestamp: () => "TS",
        increment: (n) => n,
      },
    }),
    auth: () => ({}),
  };

  const commands = createYellowPagesCommands(fakeAdmin);
  const allRes = await commands.searchPipeBuyerYellowPages({data: {}});
  assert.equal(allRes.totalMatched, 2);
  assert.equal(allRes.entries[0].companyId, "comp-ver");
  assert.equal(allRes.entries[0].verified, true);
  assert.equal(allRes.entries[1].companyId, "comp-basic");
  assert.equal(allRes.entries[1].verified, false);

  const verOnlyRes = await commands.searchPipeBuyerYellowPages({
    data: {tierFilter: "verified_only"},
  });
  assert.equal(verOnlyRes.totalMatched, 1);
  assert.equal(verOnlyRes.entries[0].companyId, "comp-ver");
  assert.equal(verOnlyRes.entries[0].verified, true);
});

test("consolidates county/USDOT/FMCSA town variants, infers NANPA & intl geo, and classifies 30 sectors including Crew Hotels", () => {
  const {inferRegionFromCountryAndCity} = require("../yellow_pages_taxonomy");
  assert.equal(YELLOW_PAGES_CATEGORIES.length, 30);
  assert.equal(canonicalizeCityName("Co of GrandPr", "AB", "CA"), "Grande Prairie");
  assert.equal(canonicalizeCityName("Co of GrndPr #1", "AB", "CA"), "Grande Prairie");
  assert.equal(canonicalizeCityName("County of Grande Prairie", "AB", "CA"), "Grande Prairie");
  assert.equal(canonicalizeCityName("Grande Prairie County No. 1", "AB", "CA"), "Grande Prairie");
  assert.equal(canonicalizeCityName("Grand Prairie", "AB", "CA"), "Grande Prairie");
  assert.equal(canonicalizeCityName("Grand Prairie", "TX", "US"), "Grand Prairie");
  assert.equal(canonicalizeCityName("Fort Saint John", "BC", "CA"), "Fort St. John");
  assert.equal(canonicalizeCityName("Watford", "ND", "US"), "Watford City");
  assert.equal(canonicalizeCityName("Dubois", "PA", "US"), "DuBois");
  assert.equal(canonicalizeCityName("Macaé", "RJ", "BR"), "Macae");
  assert.equal(canonicalizeCityName("Neuquén", "NQ", "AR"), "Neuquen");
  assert.equal(canonicalizeCityName("Bogotá", "DC", "CO"), "Bogota");
  assert.equal(canonicalizeCityName("None", "AB", "CA"), "");
  assert.equal(inferRegionFromCountryAndCity("GB", "Aberdeen"), "SCT");
  assert.equal(inferRegionFromCountryAndCity("AU", "Perth"), "WA");
  assert.equal(inferRegionFromCountryAndCity("NG", "Port Harcourt"), "RI");
  assert.equal(canonicalizeCityName("Rocky Mtn Hse", "AB", "CA"), "Rocky Mountain House");
  assert.equal(canonicalizeCityName("EL Paso", "TX", "US"), "El Paso");
  assert.equal(canonicalizeCityName("LA Porte", "TX", "US"), "La Porte");
  assert.equal(canonicalizeCityName("Calgary, T3e 0b4", "AB", "CA"), "Calgary");
  assert.equal(canonicalizeCompanyName("WESTPRO SAFETY AND TRAINING LTD"), "Westpro Safety And Training LTD");

  const gpGeo = inferGeoFromNanpaPhone("+1 780-539-5353");
  assert.equal(gpGeo.countryCode, "CA");
  assert.equal(gpGeo.regionCode, "AB");
  assert.equal(gpGeo.hubCity, "Grande Prairie");

  const ndGeo = inferGeoFromNanpaPhone("(701) 444-2697");
  assert.equal(ndGeo.countryCode, "US");
  assert.equal(ndGeo.regionCode, "ND");
  assert.equal(ndGeo.hubCity, "Watford City");

  const trainCats = classifyCategoriesFromText(["H2S Alive", "IWCF Well Control", "Safety Training Center"]);
  assert.ok(trainCats.includes("oil_gas_training_courses"));

  const hotelCats = classifyCategoriesFromText(["Pomeroy Inn & Suites", "CLC Lodging", "Oil and Gas Rate"]);
  assert.ok(hotelCats.includes("crew_hotels_workforce_lodging"));

  const scaffCats = classifyCategoriesFromText(["Industrial Scaffolding", "Pipe Insulation", "IRATA Rope Access"]);
  assert.ok(scaffCats.includes("scaffolding_insulation_coatings"));

  const pumpCats = classifyCategoriesFromText(["Pump Supplier"]);
  assert.ok(pumpCats.includes("pumps_artificial_lift"));
});
