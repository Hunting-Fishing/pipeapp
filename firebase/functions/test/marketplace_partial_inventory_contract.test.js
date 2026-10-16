"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const commandSource = fs.readFileSync(
    path.join(__dirname, "..", "marketplace_commands.js"),
    "utf8",
);
const communicationSource = fs.readFileSync(
    path.join(__dirname, "..", "communication_commands.js"),
    "utf8",
);

test("offer acceptance stores an authoritative inventory reservation", () => {
  assert.match(commandSource, /marketplaceOfferInventoryReservation/);
  assert.match(commandSource, /reservedQuantity: inventoryReservation/);
  assert.match(commandSource, /remainingQuantityAfterReservation/);
  assert.match(commandSource, /\.\.\.inventoryReservation/);
});

test("partial completion reopens only the remaining inventory", () => {
  assert.match(commandSource, /marketplaceOfferInventoryCompletion/);
  assert.match(
      commandSource,
      /if \(inventoryCompletion\.partialQuantitySale\)[\s\S]*status: "active"[\s\S]*quantity: inventoryCompletion\.remainingQuantity/,
  );
  assert.match(
      commandSource,
      /else \{[\s\S]*status: "sold"[\s\S]*saleStatus: "completed"/,
  );
});

test("completed partial buyers retain protected contact authorization", () => {
  assert.match(commandSource, /collection\("completed_buyers"\)/);
  assert.match(communicationSource, /completedBuyerUid/);
  assert.match(communicationSource, /reason: "completed_offer"/);
});

