"use strict";

// Pipe Buyer visual sandbox seeder.
//
// This script is intentionally hard-locked to local Firebase emulators. It
// creates stable demo accounts and representative marketplace data so the
// Flutter UI can be reviewed without reading or writing production data.

const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {GeoPoint, Timestamp, getFirestore} = require("firebase-admin/firestore");

function loopbackHost(value, label) {
  const normalized = String(value || "").trim();
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(normalized)) {
    throw new Error(
        `${label} must point to a local emulator. Refusing value: ${normalized}`,
    );
  }
  return normalized;
}

process.env.FIREBASE_AUTH_EMULATOR_HOST = loopbackHost(
    process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099",
    "FIREBASE_AUTH_EMULATOR_HOST",
);
process.env.FIRESTORE_EMULATOR_HOST = loopbackHost(
    process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080",
    "FIRESTORE_EMULATOR_HOST",
);

const projectId = process.env.GCLOUD_PROJECT || "flutter-flow-pipe";
const password = "PipeBuyerDemo!2026";
const app = initializeApp({projectId}, `visual-sandbox-${Date.now()}`);
const auth = getAuth(app);
const db = getFirestore(app);
const now = Date.now();
const day = 24 * 60 * 60 * 1000;

const demoUsers = [
  {
    uid: "visual-buyer",
    email: "buyer.visual@pipebuyer.test",
    displayName: "Alex Buyer",
    phoneNumber: "+15875550101",
    accountType: "personal",
  },
  {
    uid: "visual-seller",
    email: "seller.visual@pipebuyer.test",
    displayName: "Prairie Tubular & Equipment",
    phoneNumber: "+15875550102",
    accountType: "business",
  },
  {
    uid: "visual-carrier",
    email: "carrier.visual@pipebuyer.test",
    displayName: "Northline Heavy Haul",
    phoneNumber: "+17805550103",
    accountType: "business",
  },
];

function atDays(offset) {
  return Timestamp.fromMillis(now + offset * day);
}

function atHours(offset) {
  return Timestamp.fromMillis(now + offset * 60 * 60 * 1000);
}

function location({
  name = "Grande Prairie area, AB",
  town = "Grande Prairie",
  region = "Alberta",
  country = "Canada",
  latitude = 55.1707,
  longitude = -118.7947,
} = {}) {
  return {
    locationVisibility: "approximate",
    publicLocationName: name,
    nearestTown: town,
    region,
    country,
    approximateRadiusKm: 10,
    publicGeoPoint: new GeoPoint(latitude, longitude),
  };
}

async function ensureAuthUser(user) {
  try {
    await auth.getUser(user.uid);
    await auth.updateUser(user.uid, {
      email: user.email,
      password,
      displayName: user.displayName,
      phoneNumber: user.phoneNumber,
      emailVerified: true,
      disabled: false,
    });
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    await auth.createUser({
      uid: user.uid,
      email: user.email,
      password,
      displayName: user.displayName,
      phoneNumber: user.phoneNumber,
      emailVerified: true,
    });
  }
}

function sellerListing(id, values = {}) {
  const ageDays = Number(values.ageDays ?? -2);
  const previousPrice = values.previousPrice;
  const listing = {
    sellerUid: "visual-seller",
    sellerName: "Prairie Tubular & Equipment",
    sellerPhotoUrl: "",
    sellerVerified: true,
    status: "active",
    source: "visual_sandbox",
    currency: "CAD",
    transactionType: "For Sale",
    condition: "Good",
    imageUrls: [],
    thumbnailUrl: null,
    mediaPhotoCount: 0,
    mediaUploadStatus: "none",
    searchIndexVersion: 1,
    createdAt: atDays(ageDays),
    updatedAt: atHours(-2),
    ...location(),
    ...values,
  };
  delete listing.ageDays;
  delete listing.previousPrice;
  if (typeof previousPrice === "number") listing.previousPrice = previousPrice;
  if (typeof listing.price === "number" && listing.initialPrice == null) {
    listing.initialPrice = previousPrice ?? listing.price;
  }
  listing.visualSandboxId = id;
  return listing;
}

async function main() {
  console.log("Seeding Pipe Buyer local visual sandbox...");
  await Promise.all(demoUsers.map(ensureAuthUser));

  const batch = db.batch();
  const set = (path, value) => batch.set(db.doc(path), value, {merge: false});

  set("platform_configuration/phase1_features", {
    marketplace: true,
    wantedAds: true,
    offers: true,
    auctions: true,
    dispatch: true,
    paidFeatures: false,
    regulatedListings: false,
    revision: 1,
    source: "visual_sandbox",
  });

  set("users/visual-buyer", {
    displayName: "Alex Buyer",
    display_name: "Alex Buyer",
    email: "buyer.visual@pipebuyer.test",
    phone_number: "+15875550101",
    verifiedPhoneE164: "+15875550101",
    accountType: "personal",
    preferredContact: "In-app message",
    baseCommunity: "Grande Prairie, Alberta",
    sellerBio: "Oilfield procurement buyer reviewing pipe, equipment and transport options.",
    accountVerified: true,
    accountVerificationStatus: "approved",
    accountVerificationReviewVersion: 1,
    accountVerificationRevision: 1,
    userScore: 94,
    profileCompletion: 100,
    roleVersion: 1,
    visualSandbox: true,
    updatedAt: atHours(-1),
  });
  set("users/visual-seller", {
    displayName: "Prairie Tubular & Equipment",
    display_name: "Prairie Tubular & Equipment",
    businessName: "Prairie Tubular & Equipment Ltd.",
    email: "seller.visual@pipebuyer.test",
    phone_number: "+15875550102",
    verifiedPhoneE164: "+15875550102",
    accountType: "business",
    preferredContact: "In-app message",
    baseCommunity: "Grande Prairie, Alberta",
    sellerBio: "Northwestern Alberta supplier of surplus oilfield pipe, equipment and field assets.",
    accountVerified: true,
    accountVerificationStatus: "approved",
    accountVerificationReviewVersion: 1,
    accountVerificationRevision: 1,
    userScore: 97,
    profileCompletion: 100,
    roleVersion: 1,
    visualSandbox: true,
    updatedAt: atHours(-1),
  });
  set("users/visual-carrier", {
    displayName: "Northline Heavy Haul",
    display_name: "Northline Heavy Haul",
    businessName: "Northline Heavy Haul Ltd.",
    email: "carrier.visual@pipebuyer.test",
    phone_number: "+17805550103",
    verifiedPhoneE164: "+17805550103",
    accountType: "business",
    preferredContact: "In-app message",
    baseCommunity: "Edmonton, Alberta",
    sellerBio: "Approved-carrier visual fixture for heavy haul, pipe hauling and pilot services.",
    accountVerified: true,
    accountVerificationStatus: "approved",
    accountVerificationReviewVersion: 1,
    accountVerificationRevision: 1,
    userScore: 95,
    profileCompletion: 100,
    roleVersion: 1,
    visualSandbox: true,
    updatedAt: atHours(-1),
  });

  set("public_seller_profiles/visual-buyer", {
    ownerUid: "visual-buyer",
    displayName: "Alex Buyer",
    accountType: "personal",
    baseCommunity: "Grande Prairie, Alberta",
    description: "Industrial buyer sourcing tubulars, field equipment and transport.",
    approvedTagIds: ["pipe", "heavy-equipment", "dispatch"],
    accountVerified: true,
    visualSandbox: true,
  });
  set("public_seller_profiles/visual-seller", {
    ownerUid: "visual-seller",
    displayName: "Prairie Tubular & Equipment",
    accountType: "business",
    baseCommunity: "Grande Prairie, Alberta",
    description: "Surplus oilfield pipe, equipment, tanks, buildings and field inventory.",
    approvedTagIds: ["pipe", "oilfield-equipment", "portable-buildings"],
    accountVerified: true,
    visualSandbox: true,
  });
  set("public_seller_profiles/visual-carrier", {
    ownerUid: "visual-carrier",
    displayName: "Northline Heavy Haul",
    accountType: "business",
    baseCommunity: "Edmonton, Alberta",
    description: "Heavy haul, flat deck, lowboy, pipe hauling and pilot support.",
    approvedTagIds: ["dispatch", "heavy-haul", "pipe-hauling"],
    accountVerified: true,
    visualSandbox: true,
  });

  set("public_business_profiles/visual-seller", {
    ownerUid: "visual-seller",
    publicName: "Prairie Tubular & Equipment Ltd.",
    publicPhone: "+1 587 555 0102",
    publicEmail: "seller.visual@pipebuyer.test",
    website: "https://www.pipebuyer.com",
    description: "Surplus tubulars, production equipment, tanks and field assets serving the Peace Country and northern Alberta.",
    serviceAreaLabel: "Grande Prairie and within 350 km",
    serviceArea: {
      mode: "radius",
      center: {latitude: 55.1707, longitude: -118.7947},
      centerLabel: "Grande Prairie, Alberta",
      radiusKm: 350,
      places: [],
    },
    serviceCountryCodes: ["CA"],
    serviceRegionKeys: ["CA-AB", "CA-BC"],
    servicePlaceKeys: ["grande-prairie-ab", "dawson-creek-bc"],
    photoUrl: "",
    visualSandbox: true,
  });
  set("business_private/visual-seller", {
    ownerUid: "visual-seller",
    legalName: "Prairie Tubular & Equipment Ltd.",
    privateAddress: "Visual sandbox yard — Grande Prairie, AB",
    visualSandbox: true,
  });
  set("public_business_profiles/visual-carrier", {
    ownerUid: "visual-carrier",
    publicName: "Northline Heavy Haul Ltd.",
    publicPhone: "+1 780 555 0103",
    publicEmail: "carrier.visual@pipebuyer.test",
    website: "https://www.pipebuyer.com",
    description: "Heavy-haul carrier fixture serving Alberta, British Columbia and Saskatchewan.",
    serviceAreaLabel: "Western Canada",
    serviceArea: {
      mode: "radius",
      center: {latitude: 53.5461, longitude: -113.4938},
      centerLabel: "Edmonton, Alberta",
      radiusKm: 900,
      places: [],
    },
    serviceCountryCodes: ["CA"],
    serviceRegionKeys: ["CA-AB", "CA-BC", "CA-SK"],
    servicePlaceKeys: ["edmonton-ab", "grande-prairie-ab", "dawson-creek-bc"],
    photoUrl: "",
    visualSandbox: true,
  });
  set("business_private/visual-carrier", {
    ownerUid: "visual-carrier",
    legalName: "Northline Heavy Haul Ltd.",
    privateAddress: "Visual sandbox terminal — Edmonton, AB",
    visualSandbox: true,
  });

  const tags = {
    pipe: "Pipe & Tubulars",
    "heavy-equipment": "Heavy Equipment",
    "oilfield-equipment": "Oil & Gas Equipment",
    "portable-buildings": "Portable Buildings",
    dispatch: "Trucking & Dispatch",
    "heavy-haul": "Heavy Haul",
    "pipe-hauling": "Pipe Hauling",
  };
  for (const [id, name] of Object.entries(tags)) {
    set(`marketplace_tags/${id}`, {
      name,
      label: name,
      status: "approved",
      active: true,
      visualSandbox: true,
    });
  }

  const listings = {
    "visual-pipe-drill": sellerListing("visual-pipe-drill", {
      title: "4½ in E-75 Drill Pipe — 54 Joints",
      category: "Pipe, Tubing & Materials",
      productType: "Drill Pipe",
      price: 73,
      previousPrice: 82,
      priceBasis: "Per piece",
      quantity: 54,
      pipeSize: "4-1/2 in",
      pipeBand: "Yellow band",
      condition: "Used — Premium class",
      inspectionStatus: "Visual inspection completed",
      description: "54 straight joints of used drill pipe. Yard loaded. Buyer to verify final grade and dimensions before purchase.",
      pendingOfferCount: 3,
      boostStatus: "active",
      ageDays: -1,
    }),
    "visual-casing": sellerListing("visual-casing", {
      title: "9⅝ in J55 Casing — 32 ft Range 2",
      category: "Pipe, Tubing & Materials",
      productType: "Casing",
      price: 118,
      priceBasis: "Per joint",
      quantity: 86,
      pipeSize: "9-5/8 in",
      condition: "Used — serviceable, class unknown",
      description: "Mixed lot of casing available near Grande Prairie. Thread protectors included on most joints.",
      ageDays: -5,
    }),
    "visual-excavator": sellerListing("visual-excavator", {
      title: "2021 Caterpillar 320 Excavator",
      category: "Heavy Equipment",
      productType: "Excavator",
      brand: "Caterpillar",
      model: "320",
      modelYear: 2021,
      machineHours: 4380,
      operatingStatus: "Work ready",
      price: 189500,
      priceBasis: "Total",
      quantity: 1,
      condition: "Good",
      description: "Work-ready 320 with hydraulic thumb, cleanup bucket and digging bucket.",
      pendingOfferCount: 1,
      ...location({
        name: "Whitecourt area, AB",
        town: "Whitecourt",
        latitude: 54.1428,
        longitude: -115.6844,
      }),
      ageDays: -3,
    }),
    "visual-loader": sellerListing("visual-loader", {
      title: "2019 CAT 950 GC Wheel Loader",
      category: "Heavy Equipment",
      productType: "Loader",
      brand: "Caterpillar",
      model: "950 GC",
      modelYear: 2019,
      machineHours: 6120,
      operatingStatus: "Operational",
      price: 142000,
      priceBasis: "Total",
      quantity: 1,
      condition: "Good",
      description: "General-purpose bucket, ride control and heated cab.",
      ageDays: -8,
    }),
    "visual-office": sellerListing("visual-office", {
      title: "12 × 60 ft Skidded Crew Shack / Office",
      category: "Portable Buildings",
      productType: "Crew Shack",
      price: 38500,
      priceBasis: "Total",
      quantity: 1,
      condition: "Ready for use",
      description: "Insulated skidded building with office, lunch area, boot room and electric heat.",
      ...location({
        name: "Dawson Creek area, BC",
        town: "Dawson Creek",
        region: "British Columbia",
        latitude: 55.7596,
        longitude: -120.2377,
      }),
      ageDays: -2,
    }),
    "visual-tank": sellerListing("visual-tank", {
      title: "400 bbl Vertical Production Tank",
      category: "Tanks & Containers",
      productType: "Vertical Tank",
      price: 14500,
      priceBasis: "Each",
      quantity: 4,
      condition: "Used — cleaned and inspected",
      description: "Four matching vertical tanks removed from service. Buyer to confirm suitability for intended product.",
      ageDays: -4,
    }),
    "visual-semi": sellerListing("visual-semi", {
      title: "2018 Peterbilt 389 Heavy Spec Tractor",
      category: "Transport & Hauling",
      productType: "Semi Truck",
      brand: "Peterbilt",
      model: "389",
      modelYear: 2018,
      price: 124900,
      priceBasis: "Total",
      quantity: 1,
      condition: "Good",
      description: "Heavy-spec highway tractor configured for oilfield and flat-deck work.",
      ...location({
        name: "Edmonton area, AB",
        town: "Edmonton",
        latitude: 53.5461,
        longitude: -113.4938,
      }),
      ageDays: -6,
    }),
    "visual-wanted-line-pipe": sellerListing("visual-wanted-line-pipe", {
      sellerUid: "visual-buyer",
      sellerName: "Alex Buyer",
      title: "WANTED — 6 in Used Line Pipe, 500+ ft",
      category: "Pipe, Tubing & Materials",
      productType: "Line Pipe",
      transactionType: "Wanted / Seeking",
      price: 0,
      priceBasis: "Contact buyer",
      quantity: 500,
      condition: "Used — serviceable, class unknown",
      sellerVerified: true,
      description: "Looking for 6 inch line pipe in Alberta or northeast BC. Structural/serviceable material considered.",
      pendingOfferCount: 0,
      ageDays: -1,
    }),
    "visual-auction-dozer": sellerListing("visual-auction-dozer", {
      title: "Timed Auction — CAT D6 Dozer",
      category: "Heavy Equipment",
      productType: "Bulldozer",
      transactionType: "Auction",
      price: 35000,
      startingBid: 35000,
      currentBid: 42500,
      minimumBidIncrement: 1000,
      buyItNowPrice: 57500,
      priceBasis: "Total",
      auctionPricingBasis: "Total",
      auctionQuantity: 1,
      bidCount: 6,
      highBidderUid: "visual-buyer",
      currentBidId: "visual-auction-bid-006",
      auctionStatus: "active",
      auctionStartAt: atDays(-1),
      auctionEndAt: atHours(6),
      condition: "Good",
      description: "Live visual-sandbox auction with six bids and a closing-time urgency state.",
      ageDays: -1,
    }),
    "visual-auction-upcoming": sellerListing("visual-auction-upcoming", {
      title: "Upcoming Auction — 2020 Bobcat T76",
      category: "Heavy Equipment",
      productType: "Skid Steer",
      transactionType: "Auction",
      price: 28000,
      startingBid: 28000,
      currentBid: 0,
      minimumBidIncrement: 500,
      priceBasis: "Total",
      auctionPricingBasis: "Total",
      auctionQuantity: 1,
      bidCount: 0,
      auctionStatus: "scheduled",
      auctionStartAt: atDays(1),
      auctionEndAt: atDays(3),
      condition: "Excellent",
      description: "Upcoming visual-sandbox auction used to review scheduled states.",
      ageDays: -2,
    }),
    "visual-auction-ended": sellerListing("visual-auction-ended", {
      title: "Ended Auction — 48 ft Step Deck Trailer",
      category: "Transport & Hauling",
      productType: "Step Deck",
      transactionType: "Auction",
      price: 18000,
      startingBid: 18000,
      currentBid: 26750,
      minimumBidIncrement: 250,
      priceBasis: "Total",
      auctionPricingBasis: "Total",
      auctionQuantity: 1,
      bidCount: 9,
      highBidderUid: "visual-buyer",
      currentBidId: "visual-ended-bid-009",
      auctionStatus: "won",
      saleStatus: "pending_completion",
      auctionStartAt: atDays(-5),
      auctionEndAt: atDays(-1),
      condition: "Good",
      description: "Completed visual-sandbox auction for ended and settlement-state review.",
      ageDays: -7,
    }),
  };

  for (const [id, listing] of Object.entries(listings)) {
    set(`public_listings/${id}`, listing);
    set(`listing_private_locations/${id}`, {
      ownerUid: listing.sellerUid,
      exactGeoPoint: listing.publicGeoPoint || new GeoPoint(55.1707, -118.7947),
      fullAddress: `Visual sandbox location for ${id}`,
      nearestTown: listing.nearestTown || "Grande Prairie",
      region: listing.region || "Alberta",
      country: listing.country || "Canada",
      accessNotes: "Visual sandbox only — call before arrival.",
      visibility: listing.locationVisibility || "approximate",
      publicName: listing.publicLocationName || "Grande Prairie area, AB",
      updatedAt: atHours(-1),
      visualSandbox: true,
    });
  }

  set("auction_private/visual-auction-dozer", {
    ownerUid: "visual-seller",
    reservePrice: 40000,
    reserveTotal: 40000,
    visualSandbox: true,
  });
  set("auction_private/visual-auction-upcoming", {
    ownerUid: "visual-seller",
    reservePrice: 32000,
    reserveTotal: 32000,
    visualSandbox: true,
  });
  set("auction_private/visual-auction-ended", {
    ownerUid: "visual-seller",
    reservePrice: 24000,
    reserveTotal: 24000,
    visualSandbox: true,
  });

  const liveBidAmounts = [36000, 37500, 39000, 40500, 41500, 42500];
  liveBidAmounts.forEach((amount, index) => {
    const number = String(index + 1).padStart(3, "0");
    set(`auction_bids/visual-auction-bid-${number}`, {
      listingId: "visual-auction-dozer",
      bidderUid: "visual-buyer",
      amount,
      status: index === liveBidAmounts.length - 1 ? "leading" : "outbid",
      createdAt: atHours(-6 + index),
      visualSandbox: true,
    });
  });
  set("auction_bids/visual-ended-bid-009", {
    listingId: "visual-auction-ended",
    bidderUid: "visual-buyer",
    amount: 26750,
    status: "won",
    createdAt: atDays(-1),
    visualSandbox: true,
  });

  set("offers/visual-offer-pipe-1", {
    listingId: "visual-pipe-drill",
    buyerUid: "visual-buyer",
    sellerUid: "visual-seller",
    buyerDisplayName: "Alex Buyer",
    offeredUnitPrice: 68,
    requestedQuantity: 54,
    offeredTotal: 3672,
    priceBasis: "Per piece",
    status: "pending",
    note: "Offer is subject to visual inspection and loading availability.",
    truckingPlan: "buyer_arranged",
    purchaseDate: atDays(4),
    truckingDate: atDays(6),
    createdAt: atHours(-5),
    updatedAt: atHours(-5),
    visualSandbox: true,
  });
  set("offers/visual-offer-pipe-2", {
    listingId: "visual-pipe-drill",
    buyerUid: "visual-buyer",
    sellerUid: "visual-seller",
    buyerDisplayName: "Alex Buyer",
    offeredUnitPrice: 70,
    requestedQuantity: 54,
    offeredTotal: 3780,
    priceBasis: "Per piece",
    status: "pending",
    note: "Revised offer after discussing pickup timing.",
    truckingPlan: "request_dispatch",
    dispatchDelivery: "Dawson Creek, BC",
    purchaseDate: atDays(4),
    truckingDate: atDays(7),
    createdAt: atHours(-2),
    updatedAt: atHours(-2),
    visualSandbox: true,
  });

  set("conversations/visual-conversation-pipe", {
    memberUids: ["visual-buyer", "visual-seller"],
    listingId: "visual-pipe-drill",
    listingTitle: "4½ in E-75 Drill Pipe — 54 Joints",
    sellerUid: "visual-seller",
    sellerName: "Prairie Tubular & Equipment",
    buyerDisplayName: "Alex Buyer",
    openedByUid: "visual-buyer",
    openedAt: atDays(-2),
    messageCount: 4,
    lastMessage: "That works. I can arrange inspection tomorrow afternoon.",
    lastMessageAt: atHours(-1),
    unreadCounts: {"visual-buyer": 2, "visual-seller": 0},
    latestNegotiation: {
      unitPrice: 70,
      quantity: 54,
      offerId: "visual-offer-pipe-2",
      status: "pending",
    },
    visualSandbox: true,
  });
  set("conversations/visual-conversation-pipe/messages/visual-msg-001", {
    senderUid: "visual-buyer",
    text: "Hi, are all 54 joints still available?",
    createdAt: atHours(-8),
    visualSandbox: true,
  });
  set("conversations/visual-conversation-pipe/messages/visual-msg-002", {
    senderUid: "visual-seller",
    text: "Yes. All 54 are still in the Grande Prairie yard and can be viewed this week.",
    createdAt: atHours(-7),
    visualSandbox: true,
  });
  set("conversations/visual-conversation-pipe/messages/visual-msg-003", {
    senderUid: "visual-buyer",
    text: "I sent a revised offer and would need trucking to Dawson Creek.",
    createdAt: atHours(-3),
    visualSandbox: true,
  });
  set("conversations/visual-conversation-pipe/messages/visual-msg-004", {
    senderUid: "visual-seller",
    text: "That works. I can arrange inspection tomorrow afternoon.",
    createdAt: atHours(-1),
    visualSandbox: true,
  });

  set("conversations/visual-conversation-excavator", {
    memberUids: ["visual-buyer", "visual-seller"],
    listingId: "visual-excavator",
    listingTitle: "2021 Caterpillar 320 Excavator",
    sellerUid: "visual-seller",
    sellerName: "Prairie Tubular & Equipment",
    buyerDisplayName: "Alex Buyer",
    openedByUid: "visual-buyer",
    openedAt: atDays(-1),
    messageCount: 2,
    lastMessage: "Service records can be reviewed with the machine.",
    lastMessageAt: atHours(-4),
    unreadCounts: {"visual-buyer": 0, "visual-seller": 1},
    visualSandbox: true,
  });
  set("conversations/visual-conversation-excavator/messages/visual-msg-001", {
    senderUid: "visual-buyer",
    text: "Do you have service records and undercarriage measurements?",
    createdAt: atHours(-5),
    visualSandbox: true,
  });
  set("conversations/visual-conversation-excavator/messages/visual-msg-002", {
    senderUid: "visual-seller",
    text: "Service records can be reviewed with the machine.",
    createdAt: atHours(-4),
    visualSandbox: true,
  });

  set("marketplace_transactions/visual-offer-pipe-2", {
    offerId: "visual-offer-pipe-2",
    listingId: "visual-pipe-drill",
    buyerUid: "visual-buyer",
    sellerUid: "visual-seller",
    status: "pending_completion",
    buyerConfirmed: false,
    sellerConfirmed: false,
    agreedUnitPrice: 70,
    agreedQuantity: 54,
    agreedTotal: 3780,
    currency: "CAD",
    priceBasis: "Per piece",
    revision: 1,
    createdAt: atHours(-2),
    updatedAt: atHours(-2),
    visualSandbox: true,
  });

  set("dispatch_carriers/visual-carrier", {
    ownerUid: "visual-carrier",
    operatingName: "Northline Heavy Haul",
    companyName: "Northline Heavy Haul Ltd.",
    status: "active",
    serviceAreaLabel: "Western Canada",
    approvedAt: atDays(-30),
    services: ["Flat deck", "Lowboy", "Pipe hauling", "Heavy equipment", "Pilot / escort"],
    visualSandbox: true,
  });
  set("dispatch_carriers/visual-carrier/vehicles/tractor-01", {
    ownerUid: "visual-carrier",
    name: "Unit 301 — Heavy Spec Tractor",
    vehicleType: "Tractor",
    maximumPayloadKg: 31000,
    available: true,
    registrationWeightKg: 31000,
    weightSource: "Vehicle registration",
    services: ["Flat deck", "Pipe hauling", "Heavy equipment"],
    visualSandbox: true,
  });
  set("dispatch_carriers/visual-carrier/vehicles/pilot-01", {
    ownerUid: "visual-carrier",
    name: "Pilot 12",
    vehicleType: "Pilot / escort pickup",
    maximumPayloadKg: 1200,
    available: true,
    services: ["Pilot / escort", "Route survey"],
    visualSandbox: true,
  });
  set("dispatch_carriers/visual-carrier/saved_quotes/gp-dc", {
    ownerUid: "visual-carrier",
    name: "Grande Prairie → Dawson Creek",
    pickupLabel: "Grande Prairie, AB",
    deliveryLabel: "Dawson Creek, BC",
    ratePerKm: 3.85,
    deadheadRatePerKm: 2.25,
    minimumCharge: 1250,
    revision: 1,
    updatedAt: atDays(-3),
    visualSandbox: true,
  });

  set("dispatch_jobs/visual-dispatch-open", {
    createdByUid: "visual-buyer",
    title: "54 joints drill pipe — GP to Dawson Creek",
    pickupLabel: "Grande Prairie yard",
    deliveryLabel: "Dawson Creek yard",
    status: "open",
    bidCount: 3,
    revision: 1,
    truckingDate: atDays(7),
    loadDetails: "54 joints of 4½ in drill pipe. Approx. 32 ft lengths.",
    sourceType: "marketplace",
    listingId: "visual-pipe-drill",
    estimatedWeightKg: 15800,
    estimatedDistanceKm: 132,
    pickupGeoPoint: new GeoPoint(55.1707, -118.7947),
    deliveryGeoPoint: new GeoPoint(55.7596, -120.2377),
    createdAt: atDays(-1),
    updatedAt: atHours(-3),
    visualSandbox: true,
  });
  set("dispatch_bids/visual-dispatch-bid-1", {
    jobId: "visual-dispatch-open",
    carrierUid: "visual-carrier",
    carrierName: "Northline Heavy Haul",
    status: "pending",
    allInAmount: 1850,
    amount: 1850,
    currency: "CAD",
    revision: 1,
    createdAt: atHours(-6),
    updatedAt: atHours(-6),
    visualSandbox: true,
  });
  set("dispatch_bids/visual-dispatch-bid-2", {
    jobId: "visual-dispatch-open",
    carrierUid: "visual-carrier-alt",
    carrierName: "Peace Country Transport",
    status: "pending",
    allInAmount: 2125,
    amount: 2125,
    currency: "CAD",
    revision: 1,
    createdAt: atHours(-5),
    updatedAt: atHours(-5),
    visualSandbox: true,
  });
  set("dispatch_jobs/visual-dispatch-awarded", {
    createdByUid: "visual-buyer",
    customerUid: "visual-buyer",
    carrierUid: "visual-carrier",
    title: "CAT 320 — Whitecourt to Grande Prairie",
    pickupLabel: "Whitecourt, AB",
    deliveryLabel: "Grande Prairie, AB",
    status: "awarded",
    bidCount: 4,
    awardedAmount: 3250,
    allInAmount: 3250,
    revision: 2,
    truckingDate: atDays(3),
    loadDetails: "2021 CAT 320 excavator. Lowboy required.",
    sourceType: "marketplace",
    listingId: "visual-excavator",
    estimatedWeightKg: 22500,
    estimatedDistanceKm: 190,
    createdAt: atDays(-3),
    updatedAt: atHours(-2),
    visualSandbox: true,
  });
  set("dispatch_transactions/visual-dispatch-awarded", {
    jobId: "visual-dispatch-awarded",
    customerUid: "visual-buyer",
    carrierUid: "visual-carrier",
    status: "scheduled",
    allInAmount: 3250,
    currency: "CAD",
    scheduledAt: atDays(3),
    pickupLabel: "Whitecourt, AB",
    deliveryLabel: "Grande Prairie, AB",
    revision: 3,
    createdAt: atDays(-2),
    updatedAt: atHours(-2),
    visualSandbox: true,
  });
  set("dispatch_transactions/visual-dispatch-awarded/revisions/1", {
    revision: 1,
    event: "carrier_awarded",
    actorUid: "visual-buyer",
    status: "awarded",
    createdAt: atDays(-2),
    visualSandbox: true,
  });
  set("dispatch_transactions/visual-dispatch-awarded/revisions/2", {
    revision: 2,
    event: "accepted",
    actorUid: "visual-carrier",
    status: "accepted",
    createdAt: atDays(-1),
    visualSandbox: true,
  });
  set("dispatch_transactions/visual-dispatch-awarded/revisions/3", {
    revision: 3,
    event: "scheduled",
    actorUid: "visual-carrier",
    status: "scheduled",
    scheduledAt: atDays(3),
    createdAt: atHours(-2),
    visualSandbox: true,
  });

  set("users/visual-buyer/saved_listings/visual-excavator", {
    listingId: "visual-excavator",
    createdAt: atHours(-12),
    visualSandbox: true,
  });
  set("users/visual-buyer/followed_sellers/visual-seller", {
    sellerUid: "visual-seller",
    notificationsEnabled: true,
    createdAt: atDays(-4),
    visualSandbox: true,
  });
  set("users/visual-buyer/saved_locations/dawson-creek-yard", {
    ownerUid: "visual-buyer",
    label: "Dawson Creek Receiving Yard",
    purpose: "delivery",
    exactGeoPoint: new GeoPoint(55.7596, -120.2377),
    publicName: "Dawson Creek, BC",
    privacy: "private",
    nearbyNotifications: true,
    radiusKm: 75,
    createdAt: atDays(-8),
    visualSandbox: true,
  });

  set("users/visual-buyer/notifications/visual-notification-1", {
    recipientUid: "visual-buyer",
    actorUid: "visual-seller",
    type: "message",
    listingId: "visual-pipe-drill",
    conversationId: "visual-conversation-pipe",
    title: "New marketplace message",
    message: "Prairie Tubular replied about your drill pipe inquiry.",
    read: false,
    createdAt: atHours(-1),
    visualSandbox: true,
  });
  set("users/visual-buyer/notifications/visual-notification-2", {
    recipientUid: "visual-buyer",
    actorUid: "visual-seller",
    type: "auction",
    listingId: "visual-auction-dozer",
    title: "Auction ending soon",
    message: "The CAT D6 auction closes in less than 24 hours.",
    read: false,
    createdAt: atHours(-2),
    visualSandbox: true,
  });
  set("users/visual-buyer/notifications/visual-notification-3", {
    recipientUid: "visual-buyer",
    actorUid: "visual-carrier",
    type: "dispatch",
    jobId: "visual-dispatch-awarded",
    title: "Dispatch job scheduled",
    message: "Northline Heavy Haul scheduled your CAT 320 move.",
    read: false,
    createdAt: atHours(-3),
    visualSandbox: true,
  });

  set("verification_requests/visual-buyer", {
    userUid: "visual-buyer",
    accountType: "personal",
    displayName: "Alex Buyer",
    status: "approved",
    revision: 1,
    emailOwnershipVerified: true,
    phoneOwnershipVerified: true,
    requestedAt: atDays(-20),
    updatedAt: atDays(-18),
    reviewedAt: atDays(-18),
    reviewedByUid: "visual-sandbox-system",
    reviewReason: "Visual sandbox verified account fixture.",
    visualSandbox: true,
  });
  set("verification_requests/visual-seller", {
    userUid: "visual-seller",
    accountType: "business",
    displayName: "Prairie Tubular & Equipment",
    status: "approved",
    revision: 1,
    emailOwnershipVerified: true,
    phoneOwnershipVerified: true,
    requestedAt: atDays(-30),
    updatedAt: atDays(-28),
    reviewedAt: atDays(-28),
    reviewedByUid: "visual-sandbox-system",
    reviewReason: "Visual sandbox verified business fixture.",
    visualSandbox: true,
  });

  await batch.commit();

  console.log("");
  console.log("Pipe Buyer visual sandbox ready.");
  console.log(`Project namespace: ${projectId} (LOCAL EMULATORS ONLY)`);
  console.log("");
  console.log("Demo logins:");
  for (const user of demoUsers) {
    console.log(`  ${user.accountType.padEnd(8)} ${user.email}  /  ${password}`);
  }
  console.log("");
  console.log("Seeded: seller/company profiles, buyer profile, 11 listings, 3 auction states,");
  console.log("offers, 2 conversations, notifications, carrier fleet, Dispatch jobs and transaction history.");
}

main()
    .catch((error) => {
      console.error("Visual sandbox seed failed:", error);
      process.exitCode = 1;
    })
    .finally(async () => {
      await deleteApp(app);
    });
