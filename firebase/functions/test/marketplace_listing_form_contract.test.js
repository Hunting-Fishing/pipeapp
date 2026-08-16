"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  validateMarketplaceListingInput,
} = require("../marketplace_listing_policy");

const now = new Date("2026-08-16T06:00:00.000Z");

test("Timed Buying transport listing accepts professional structured asset facts", () => {
  const start = now.getTime() + 60 * 60 * 1000;
  const end = start + 7 * 24 * 60 * 60 * 1000;
  const listing = validateMarketplaceListingInput(
    {
      title: "2018 Ford E-Series Service Truck",
      category: "Transport & Hauling",
      productType: "Winch Truck",
      brand: "Ford",
      model: "E-Series",
      modelYear: 2018,
      machineHours: 6420,
      serialNumber: "1FDXE4FS0JDC00001",
      engineDetails: "Gas engine • automatic transmission",
      operatingStatus: "Operational",
      maintenanceHistory: "Partial maintenance records",
      attachments: "Service body, compressor and tool storage",
      quantity: 1,
      condition: "Good",
      inspectionStatus: "Seller visual inspection only",
      transactionType: "Auction",
      price: 25000,
      startingBid: 25000,
      minimumBidIncrement: 500,
      reservePrice: 30000,
      buyItNowPrice: 42500,
      auctionStartAt: start,
      auctionEndAt: end,
      priceBasis: "Total asking price",
      priceFlexibility: "Open to offers",
      currency: "CAD",
      description: "Service truck with field equipment and maintenance records.",
    },
    now,
  );

  assert.equal(listing.transactionType, "Auction");
  assert.equal(listing.modelYear, 2018);
  assert.equal(listing.machineHours, 6420);
  assert.equal(listing.serialNumber, "1FDXE4FS0JDC00001");
  assert.equal(listing.minimumBidIncrement, 500);
  assert.equal(listing.auctionStatus, "scheduled");
});

test("standard pipe listing retains structured comparison fields", () => {
  const listing = validateMarketplaceListingInput(
    {
      title: "2-7/8 in Used Production Tubing — 120 Joints",
      category: "Pipe, Tubing & Materials",
      productType: "Tubing",
      pipeSize: "2-7/8 in",
      quantity: 120,
      quantityAndLength: "120 joints",
      condition: "Used — serviceable, class unknown",
      inspectionStatus: "Seller visual inspection only",
      inspectionDetails: "Stored on racks; buyer inspection welcome.",
      pipeBand: "Yellow band",
      transactionType: "For Sale",
      price: 48,
      priceBasis: "Per joint",
      priceFlexibility: "Open to offers",
      currency: "CAD",
      description: "Used production tubing available for pickup.",
    },
    now,
  );

  assert.equal(listing.transactionType, "For Sale");
  assert.equal(listing.pipeSize, "2-7/8 in");
  assert.equal(listing.quantity, 120);
  assert.equal(listing.auctionStartAt, undefined);
  assert.equal(listing.minimumBidIncrement, undefined);
});
