"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  PARTNER_BRAND_CATEGORIES,
  PARTNER_PROGRAM_TYPES,
  PartnerProgramPolicyError,
  assertPartnerInquiryStatusTransition,
  normalizePartnerShowcaseDeal,
  toPublicPartnerShowcaseDeal,
  validatePartnerDealInterestInput,
  validatePartnerInquiryInput,
} = require("../partner_program_policy");

test("partner taxonomy exposes OEM fleet, oilfield deals, and advertising programs", () => {
  assert.ok(PARTNER_BRAND_CATEGORIES.length >= 6);
  assert.ok(
      PARTNER_BRAND_CATEGORIES.some((c) => c.code === "oem_fleet_crew_trucks"),
  );
  assert.ok(
      PARTNER_BRAND_CATEGORIES.some((c) => c.code === "oilfield_deals_discounts"),
  );
  assert.deepEqual(
      PARTNER_PROGRAM_TYPES.map((p) => p.code),
      [
        "promote_brand",
        "advertise_campaigns",
        "showcase_sell_products",
        "oilfield_deals_discounts",
      ],
  );
});

test("validatePartnerInquiryInput normalizes OEM crew truck partnership proposal", () => {
  const result = validatePartnerInquiryInput({
    companyName: "  Ford Pro Commercial Fleet  ",
    brandCategory: "oem_fleet_crew_trucks",
    programTypes: [
      "promote_brand",
      "showcase_sell_products",
      "oilfield_deals_discounts",
    ],
    commercialModel: "member_fleet_discount",
    headline: "2026 Super Duty F-350 / F-550 Oilfield Crew Truck Program",
    productSummary:
      "Showcase commercial crew trucks, chassis cabs, and service bodies with oilfield fleet rebates across Permian and WCSB.",
    dealOrDiscountOffer: "Up to $3,500 Commercial Upfit & Fleet Allowance",
    targetRegions: ["Permian Basin", "WCSB Alberta", "permian basin"],
    estimatedMonthlyBudgetUsd: "25000",
    contactName: "Jordan Mitchell",
    contactTitle: "North America Fleet Partnerships",
    email: "FleetPartners@FordCommercialExample.com",
    phone: "+1 (800) 555-0199",
    website: "fordpro.example.com/oilfield",
    notes: "Interested in Q4 crew truck spotlight and direct lead routing.",
  });

  assert.equal(result.companyName, "Ford Pro Commercial Fleet");
  assert.equal(result.brandCategory, "oem_fleet_crew_trucks");
  assert.equal(result.programTypes.length, 3);
  assert.equal(result.commercialModel, "member_fleet_discount");
  assert.deepEqual(result.targetRegions, ["Permian Basin", "WCSB Alberta"]);
  assert.equal(result.estimatedMonthlyBudgetUsd, 25000);
  assert.equal(result.email, "fleetpartners@fordcommercialexample.com");
  assert.equal(result.website, "https://fordpro.example.com/oilfield");
});

test("validatePartnerInquiryInput rejects invalid category, empty programs, or bad contact", () => {
  assert.throws(
      () => validatePartnerInquiryInput({
        companyName: "Test Co",
        brandCategory: "unknown_category",
        programTypes: ["promote_brand"],
        headline: "Valid Headline",
        productSummary: "Valid summary of products for the site.",
        contactName: "Alex",
        email: "alex@example.com",
        phone: "4035550100",
      }),
      PartnerProgramPolicyError,
  );

  assert.throws(
      () => validatePartnerInquiryInput({
        companyName: "Test Co",
        brandCategory: "oem_fleet_crew_trucks",
        programTypes: [],
        headline: "Valid Headline",
        productSummary: "Valid summary of products for the site.",
        contactName: "Alex",
        email: "alex@example.com",
        phone: "4035550100",
      }),
      PartnerProgramPolicyError,
  );

  assert.throws(
      () => validatePartnerInquiryInput({
        companyName: "Test Co",
        brandCategory: "oem_fleet_crew_trucks",
        programTypes: ["promote_brand"],
        headline: "Valid Headline",
        productSummary: "Valid summary of products for the site.",
        contactName: "Alex",
        email: "not-an-email",
        phone: "4035550100",
      }),
      PartnerProgramPolicyError,
  );
});

test("toPublicPartnerShowcaseDeal strips internal admin and contact fields", () => {
  const normalized = normalizePartnerShowcaseDeal({
    partnerName: "Lone Star Commercial Upfitters",
    brandCategory: "oem_fleet_crew_trucks",
    programTypes: ["showcase_sell_products", "oilfield_deals_discounts"],
    headline: "Turnkey Welding & Mechanic Service Trucks",
    summary: "Work-ready 4x4 crew and crane body packages with oilfield member rebates.",
    offerBadge: "Oilfield Fleet Rebate",
    discountDetails: "$2,500 off fleet orders of 3+ units",
    productHighlights: ["4x4 Crew Cab", "Crane & Compressor Ready"],
    targetRegions: ["Texas", "Alberta"],
    contactEmail: "private-sales@lonestar.example.com",
    contactPhone: "+1-432-555-0144",
    adminNotes: "Internal contract tier A - do not expose publicly",
    featured: true,
    active: true,
    priorityRank: 5,
  });

  const pub = toPublicPartnerShowcaseDeal("show-1", normalized);
  assert.equal(pub.showcaseId, "show-1");
  assert.equal(pub.featured, true);
  assert.equal(pub.priorityRank, 5);
  assert.equal("adminNotes" in pub, false);
  assert.equal("contactEmail" in pub, false);
  assert.equal("contactPhone" in pub, false);
});

test("validatePartnerDealInterestInput and inquiry status transitions enforce rules", () => {
  const lead = validatePartnerDealInterestInput({
    showcaseId: "ford-fleet-2026",
    partnerName: "Ford Pro Commercial",
    companyName: "Permian Rig Services LLC",
    contactName: "Sam Carter",
    email: "sam@permianrig.example.com",
    phone: "432-555-0188",
    fleetOrQuantityNeed: "6 Crew Trucks (F-350 4x4)",
    region: "Midland, TX",
    message: "Looking for Q1 delivery and upfit pricing.",
  });
  assert.equal(lead.showcaseId, "ford-fleet-2026");
  assert.equal(lead.email, "sam@permianrig.example.com");

  assert.equal(assertPartnerInquiryStatusTransition("new", "in_review"), "in_review");
  assert.equal(assertPartnerInquiryStatusTransition("in_review", "approved"), "approved");
  assert.throws(
      () => assertPartnerInquiryStatusTransition("archived", "approved"),
      PartnerProgramPolicyError,
  );
});
