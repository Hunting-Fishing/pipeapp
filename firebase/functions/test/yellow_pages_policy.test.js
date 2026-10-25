"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  classifyCategoriesFromText,
  expandServiceSearchTerms,
  inferCountryAndRegion,
} = require("../yellow_pages_taxonomy");
const {
  buildAdminSearchTokens,
  buildPublicEntry,
  computePriorityScore,
  isPublicEntryCurrent,
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
