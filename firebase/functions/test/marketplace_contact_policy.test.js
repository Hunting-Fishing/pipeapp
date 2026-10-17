"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  contactSharingSignals,
  hasContactHandle,
  hasEmail,
  hasPhone,
  hasWebsite,
  listingContactSignals,
} = require("../marketplace_contact_policy");

test("detects normal and deliberately obfuscated email addresses", () => {
  for (const value of [
    "sales@example.com",
    "sales (at) example (dot) com",
    "sales [at] example [dot] ca",
    "sales at example dot energy",
  ]) {
    assert.equal(hasEmail(value), true, value);
    assert.ok(contactSharingSignals(value).includes("email"), value);
  }
});

test("detects international, formatted, and compact phone numbers", () => {
  for (const value of [
    "Call 780-555-1212",
    "Phone: (780) 555 1212",
    "WhatsApp +971 50 123 4567",
    "7805551212",
    "555-1234",
    "Local number 555.1234",
  ]) {
    assert.equal(hasPhone(value), true, value);
    assert.ok(contactSharingSignals(value).includes("phone"), value);
  }
});

test("detects domains, generic TLDs, and social handles", () => {
  for (const value of [
    "x.com",
    "pipebuyer.ai",
    "pipebuyer dot ai",
    "seller.technology",
    "pipebuyer.com",
    "pipebuyer dot global",
    "https://pipebuyer.example/path",
    "www.pipebuyer.ca",
  ]) {
    assert.equal(hasWebsite(value), true, value);
  }
  for (const value of [
    "@pipe_sales",
    "Message (@seller.support)",
    "Telegram @pipe_sales",
    "Instagram: @pipe_sales",
    "LINE ID: pipe_sales",
    "Signal username: pipe.sales",
  ]) {
    assert.equal(hasContactHandle(value), true, value);
  }
  assert.equal(hasContactHandle("sales@example.com"), false);
});

test("does not treat industrial specifications, prices, or dates as contact", () => {
  for (const value of [
    "API 5CT casing",
    "5-1/2 pipe",
    "CAT-320-2026 excavator",
    "$100,000 asking price",
    "Inspection completed 2026-10-16",
    "Signal light package",
    "Line pipe inspected and drifted",
  ]) {
    assert.deepEqual(contactSharingSignals(value), [], value);
  }
});

test("listing scanner covers alternate public text fields", () => {
  assert.deepEqual(listingContactSignals({
    model: "See pipebuyer.com for details",
  }), ["website"]);
  assert.deepEqual(listingContactSignals({
    propertyFeatures: ["Fenced", "Telegram @seller_support"],
  }), ["contact_handle"]);
  assert.deepEqual(listingContactSignals({
    title: "API 5CT CAT-320-2026",
    pipeSize: "5-1/2 pipe",
    description: "$100,000 inspected 2026-10-16",
  }), []);
});
