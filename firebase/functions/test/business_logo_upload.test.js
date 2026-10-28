"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  BusinessLogoUploadError,
  createBusinessLogoUploadCommands,
  detectImageFormatFromMagicBytes,
  normalizeLogoUrl,
  validateBusinessLogoUpload,
} = require("../business_logo_upload");
const {
  computeProviderPriorityScore,
  toPublicInsuranceProvider,
  validateInsuranceProviderApplication,
} = require("../insurance_marketplace_policy");
const {
  buildPublicEntry,
  computePriorityScore,
} = require("../yellow_pages_policy");
const {
  normalizePartnerShowcaseDeal,
  toPublicPartnerShowcaseDeal,
  validatePartnerInquiryInput,
} = require("../partner_program_policy");

const VALID_PNG_BYTES = Buffer.from([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
]);

const VALID_JPEG_BYTES = Buffer.from([
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46,
  0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01,
  0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
]);

const VALID_WEBP_BYTES = Buffer.from([
  0x52, 0x49, 0x46, 0x46, 0x1A, 0x00, 0x00, 0x00,
  0x57, 0x45, 0x42, 0x50, 0x56, 0x50, 0x38, 0x20,
  0x0E, 0x00, 0x00, 0x00,
]);

function createFakeAdminForLogoUpload() {
  const savedFiles = new Map();
  const rateLimits = new Map();

  const firestore = () => ({
    collection(colName) {
      return {
        doc(docId) {
          return {
            id: docId,
            path: `${colName}/${docId}`,
          };
        },
      };
    },
    async runTransaction(fn) {
      const tx = {
        async get(ref) {
          const val = rateLimits.get(ref.path);
          return {
            exists: val !== undefined,
            data: () => val,
          };
        },
        set(ref, value) {
          rateLimits.set(ref.path, value);
        },
      };
      return fn(tx);
    },
  });
  firestore.FieldValue = {
    serverTimestamp: () => "SERVER_TS",
  };
  firestore.Timestamp = {
    now: () => ({toMillis: () => 1760000000000}),
    fromMillis: (ms) => ({toMillis: () => ms}),
  };

  return {
    savedFiles,
    admin: {
      firestore,
      storage: () => ({
        bucket: (name = "flutter-flow-pipe.firebasestorage.app") => ({
          name,
          file(objectPath) {
            return {
              async save(buffer, options) {
                savedFiles.set(objectPath, {buffer, options});
              },
            };
          },
        }),
      }),
    },
  };
}

test("detectImageFormatFromMagicBytes accepts PNG, JPEG, WebP and rejects SVG/HTML", () => {
  assert.deepEqual(detectImageFormatFromMagicBytes(VALID_PNG_BYTES), {
    contentType: "image/png",
    extension: "png",
  });
  assert.deepEqual(detectImageFormatFromMagicBytes(VALID_JPEG_BYTES), {
    contentType: "image/jpeg",
    extension: "jpg",
  });
  assert.deepEqual(detectImageFormatFromMagicBytes(VALID_WEBP_BYTES), {
    contentType: "image/webp",
    extension: "webp",
  });

  const svgPayload = Buffer.from("<svg xmlns='http://www.w3.org/2000/svg'><script>alert(1)</script></svg>");
  assert.throws(
      () => detectImageFormatFromMagicBytes(svgPayload),
      (err) => err instanceof BusinessLogoUploadError && err.code === "invalid-argument",
  );
});

test("validateBusinessLogoUpload strips data URL prefix and validates purpose", () => {
  const dataUri = `data:image/png;base64,${VALID_PNG_BYTES.toString("base64")}`;
  const result = validateBusinessLogoUpload({
    base64Data: dataUri,
    purpose: "insurance_provider",
  });
  assert.equal(result.contentType, "image/png");
  assert.equal(result.extension, "png");
  assert.equal(result.purpose, "insurance_provider");
  assert.equal(result.sizeBytes, VALID_PNG_BYTES.length);

  assert.throws(
      () => validateBusinessLogoUpload({
        base64Data: VALID_PNG_BYTES.toString("base64"),
        purpose: "unknown_purpose",
      }),
      /Unsupported business logo upload purpose/,
  );
});

test("normalizeLogoUrl accepts https and emulator http URLs while rejecting unsafe protocols", () => {
  const validHttps = "https://firebasestorage.googleapis.com/v0/b/flutter-flow-pipe.firebasestorage.app/o/business_logos%2Fpublic%2Flogo_abc.png?alt=media&token=123";
  assert.equal(normalizeLogoUrl(validHttps), validHttps);
  assert.equal(
      normalizeLogoUrl("http://127.0.0.1:9199/v0/b/demo/o/logo.png?alt=media"),
      "http://127.0.0.1:9199/v0/b/demo/o/logo.png?alt=media",
  );
  assert.equal(normalizeLogoUrl(""), "");
  assert.equal(normalizeLogoUrl("javascript:alert(1)"), "");
  assert.throws(
      () => normalizeLogoUrl("http://insecure-example.com/logo.png", {
        ErrorClass: BusinessLogoUploadError,
      }),
      /must use https/,
  );
});

test("uploadBusinessLogo callable stores validated image for both guest and signed-in callers", async () => {
  const {admin, savedFiles} = createFakeAdminForLogoUpload();
  const commands = createBusinessLogoUploadCommands(admin);

  const guestRes = await commands.uploadBusinessLogo({
    data: {
      base64Data: VALID_PNG_BYTES.toString("base64"),
      purpose: "insurance_provider",
    },
    rawRequest: {ip: "203.0.113.42"},
  });
  assert.ok(guestRes.logoUrl.startsWith("https://firebasestorage.googleapis.com/"));
  assert.ok(guestRes.objectPath.startsWith("business_logos/public/logo_"));
  assert.ok(guestRes.objectPath.endsWith(".png"));
  assert.equal(savedFiles.has(guestRes.objectPath), true);

  const authRes = await commands.uploadBusinessLogo({
    auth: {uid: "company_uid_77"},
    data: {
      base64Data: VALID_WEBP_BYTES.toString("base64"),
      purpose: "business_directory",
    },
  });
  assert.ok(authRes.objectPath.startsWith("business_logos/company_uid_77/logo_"));
  assert.ok(authRes.objectPath.endsWith(".webp"));
  assert.equal(authRes.contentType, "image/webp");
});

test("logoUrl is preserved across Insurance, Yellow Pages, and Partner Program policies", () => {
  const sampleLogo = "https://firebasestorage.googleapis.com/v0/b/flutter-flow-pipe.firebasestorage.app/o/business_logos%2Fpublic%2Flogo_123456.png?alt=media&token=abc";

  // 1. Insurance provider application & public projection
  const insApp = validateInsuranceProviderApplication({
    companyName: "Lone Star Energy Underwriters",
    providerType: "specialty_broker",
    contactName: "Dana Vance",
    email: "dana@lonestar-example.com",
    phone: "432-555-0144",
    website: "https://lonestar-example.com",
    logoUrl: sampleLogo,
    licenseSummary: "TX TDI #991042",
    licensedCountries: ["US"],
    licensedRegions: ["TX"],
    coverageLines: ["commercial_auto_fleet", "oilfield_general_liability"],
  });
  assert.equal(insApp.logoUrl, sampleLogo);
  const pubIns = toPublicInsuranceProvider({
    providerId: "prov_1",
    ...insApp,
  });
  assert.equal(pubIns.logoUrl, sampleLogo);
  assert.ok(
      computeProviderPriorityScore({...insApp, logoUrl: sampleLogo}) >
      computeProviderPriorityScore({...insApp, logoUrl: ""}),
  );

  // 2. Yellow Pages public projection
  const ypCompany = {
    companyName: "Apex Rigging & Tubular Services",
    verificationStatus: "verified",
    publicationStatus: "published",
    operationalStatus: "active_in_operation",
    billingStatus: "unpaid",
    listingTier: "free_verified",
    allowUnpaidPublic: true,
    adminViewingEnabled: true,
    countryCode: "US",
    regionCode: "TX",
    city: "Midland",
    mainPhone: "(432) 555-0199",
    services: ["Pipe Inspection"],
    logoUrl: sampleLogo,
  };
  const ypPublic = buildPublicEntry(ypCompany, "comp_1", "TS");
  assert.equal(ypPublic.logoUrl, sampleLogo);
  assert.ok(
      computePriorityScore(ypCompany, "free_verified") >
      computePriorityScore({...ypCompany, logoUrl: ""}, "free_verified"),
  );

  // 3. Partner Program inquiry & showcase projection
  const partnerInq = validatePartnerInquiryInput({
    companyName: "Apex Fleet Upfitters",
    brandCategory: "oem_fleet_crew_trucks",
    programTypes: ["showcase_sell_products"],
    commercialModel: "sponsored_showcase",
    headline: "Crew Truck Packages for Basin Contractors",
    productSummary: "Turnkey commercial crew truck upfits and fleet rebates.",
    contactName: "Alex Mercer",
    email: "alex@apexfleet-example.com",
    phone: "713-555-0188",
    logoUrl: sampleLogo,
  });
  assert.equal(partnerInq.logoUrl, sampleLogo);
  const showcase = normalizePartnerShowcaseDeal({
    partnerName: partnerInq.companyName,
    brandCategory: partnerInq.brandCategory,
    programTypes: partnerInq.programTypes,
    headline: partnerInq.headline,
    summary: partnerInq.productSummary,
    logoUrl: sampleLogo,
  });
  const pubShowcase = toPublicPartnerShowcaseDeal("sc_1", showcase);
  assert.equal(pubShowcase.logoUrl, sampleLogo);
});

test("bannerUrl and promo banner upload purposes are supported across Insurance and Partner policies", () => {
  const insBanner = validateBusinessLogoUpload({
    base64Data: VALID_PNG_BYTES.toString("base64"),
    purpose: "insurance_banner",
  });
  assert.equal(insBanner.purpose, "insurance_banner");

  const partnerBanner = validateBusinessLogoUpload({
    base64Data: VALID_WEBP_BYTES.toString("base64"),
    purpose: "partner_banner",
  });
  assert.equal(partnerBanner.purpose, "partner_banner");

  const sampleBanner = "https://firebasestorage.googleapis.com/v0/b/flutter-flow-pipe.firebasestorage.app/o/business_logos%2Fpartner_banner%2Fbanner_1.png?alt=media&token=xyz";

  const insApp = validateInsuranceProviderApplication({
    companyName: "Lone Star Energy Underwriters",
    providerType: "specialty_broker",
    contactName: "Dana Vance",
    email: "dana@lonestar-example.com",
    phone: "432-555-0144",
    bannerUrl: sampleBanner,
    licenseSummary: "TX TDI #991042",
    licensedCountries: ["US"],
    licensedRegions: ["TX"],
    coverageLines: ["commercial_auto_fleet"],
  });
  assert.equal(insApp.bannerUrl, sampleBanner);
  const pubIns = toPublicInsuranceProvider({providerId: "prov_banner", ...insApp});
  assert.equal(pubIns.bannerUrl, sampleBanner);

  const partnerInq = validatePartnerInquiryInput({
    companyName: "Apex Fleet Upfitters",
    brandCategory: "oem_fleet_crew_trucks",
    programTypes: ["showcase_sell_products"],
    commercialModel: "sponsored_showcase",
    headline: "Crew Truck Packages for Basin Contractors",
    productSummary: "Turnkey commercial crew truck upfits and fleet rebates.",
    contactName: "Alex Mercer",
    email: "alex@apexfleet-example.com",
    phone: "713-555-0188",
    bannerUrl: sampleBanner,
  });
  assert.equal(partnerInq.bannerUrl, sampleBanner);
  const showcase = normalizePartnerShowcaseDeal({
    partnerName: partnerInq.companyName,
    brandCategory: partnerInq.brandCategory,
    programTypes: partnerInq.programTypes,
    headline: partnerInq.headline,
    summary: partnerInq.productSummary,
    bannerUrl: sampleBanner,
  });
  const pubShowcase = toPublicPartnerShowcaseDeal("sc_banner", showcase);
  assert.equal(pubShowcase.bannerUrl, sampleBanner);
});
