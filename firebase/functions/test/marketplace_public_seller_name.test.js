"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  marketplacePublicBuyerName,
  marketplacePublicSellerName,
} = require("../marketplace_commands");

test("email-only auth identity is never published as the seller name", () => {
  assert.equal(marketplacePublicSellerName({
    user: {},
    business: {},
    authToken: {email: "seller@example.com"},
  }), "Marketplace seller");
});

test("contact-bearing profile names fall back to a safe public alias", () => {
  assert.equal(marketplacePublicSellerName({
    user: {
      accountType: "business",
      businessName: "sales@example.com",
      displayName: "+1 555 867 5309",
    },
    business: {publicName: "example.com"},
    authToken: {name: "@direct_deals"},
  }), "Marketplace seller");
});

test("a contact-free verified profile name remains public", () => {
  assert.equal(marketplacePublicSellerName({
    user: {displayName: "Prairie Pipe Supply"},
    authToken: {email: "private@example.com"},
  }), "Prairie Pipe Supply");
});

test("public bidder identity rejects business email, phone, and URL fields", () => {
  assert.equal(marketplacePublicBuyerName({
    user: {
      accountType: "business",
      businessName: "sales@example.com",
      displayName: "+1 (555) 867-5309",
    },
    business: {publicName: "https://direct-deals.example"},
    authToken: {name: "www.direct-deals.example"},
  }), "Marketplace buyer");
});

test("public bidder identity rejects personal email, phone, and URL fields", () => {
  assert.equal(marketplacePublicBuyerName({
    user: {
      display_name: "buyer@example.com",
      displayName: "+1 (555) 867-5309",
      fullName: "https://direct-deals.example",
    },
    authToken: {name: "www.direct-deals.example"},
  }), "Marketplace buyer");
});

test("a contact-free bidder name remains available for safe public masking", () => {
  assert.equal(marketplacePublicBuyerName({
    user: {displayName: "Jordan Bailey"},
    authToken: {email: "private@example.com"},
  }), "Jordan Bailey");
});
