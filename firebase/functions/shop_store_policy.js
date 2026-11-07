"use strict";

const {HttpsError} = require("firebase-functions/v2/https");

const SHOP_CATEGORIES = Object.freeze([
  {
    code: "pipe_welding_fab",
    label: "Pipefitting, Welding & Fab",
    shortLabel: "Pipe & Welding",
    subtitle: "Pipe wrenches, chain vises, beveling, welding helmets, leads & flange alignment tools.",
    marketplaceCategories: ["Pipe", "Oilfield Equipment"],
    iconAsset: "assets/images/industrial_icons/26-marketplace-catalog-photos/welding-machine.svg",
    subcategories: [
      "Pipe Wrenches, Chain Tongs & Vises",
      "Pipe Cutting, Threading & Beveling",
      "Pipe Alignment, Jacks & Fit-Up Tools",
      "Welding Machines, Leads & Torches",
      "Welding Rods, Wire & Abrasives",
      "Valves, Pipe Fittings, Flanges & Sealants",
    ],
  },
  {
    code: "power_hand_tools",
    label: "Power & Cordless Tools",
    shortLabel: "Power Tools",
    subtitle: "High-torque impacts, grinders, portable bandsaws, torque wrenches & jobsite tool kits.",
    marketplaceCategories: ["Heavy Equipment", "Oilfield Equipment", "Pipe"],
    iconAsset: "assets/images/industrial_icons/09-software-and-administration/04-maintenance-tools.svg",
    subcategories: [
      "Cordless Impact Wrenches & Socket Sets",
      "Angle Grinders, Bandsaws & Mag Drills",
      "Heavy Wrenches, Ratchets & Torque Tools",
      "Pliers, Hammers, Spuds & Pry Bars",
      "Mechanics, Electrician & Tap/Die Kits",
      "Cordless Batteries, Chargers & Packout",
    ],
  },
  {
    code: "rigging_hauling_cargo",
    label: "Rigging, Chains & Cargo Control",
    shortLabel: "Rigging & Hauling",
    subtitle: "Grade 70/100 transport chains, load binders, lifting slings, shackles & oversize load gear.",
    marketplaceCategories: ["Transport & Hauling"],
    iconAsset: "assets/images/industrial_icons/20-transport-and-dispatch-equipment/05-pipe-hauling-truck-trailer.svg",
    subcategories: [
      "Shackles, Hooks, Swivels & Hardware",
      "Web Slings, Round Slings & Wire Chokers",
      "Chain Hoists, Lever Pullers & Clamps",
      "Grade 70/100 Chains & Load Binders",
      "Flatbed Winch Straps, Tarps & Stakes",
      "Oversize Load Banners, Beacons & Safety",
    ],
  },
  {
    code: "ppe_fr_safety",
    label: "FR Workwear, PPE & Gas Detection",
    shortLabel: "FR & Safety PPE",
    subtitle: "Flame-resistant workwear, H2S/4-gas monitors, ANSI impact gloves, hard hats & spill kits.",
    marketplaceCategories: ["Oilfield Equipment", "Tanks & Containers", "Portable Buildings"],
    iconAsset: "assets/images/industrial_icons/08-safety-and-security/06-safety-hardhat.svg",
    subcategories: [
      "FR Shirts, Coveralls & Winter Outerwear",
      "Pipeline & Oilfield Safety Work Boots",
      "Hard Hats, Welding Shields & Safety Glasses",
      "ANSI Impact, Rigging & Cut Gloves",
      "H2S / 4-Gas Monitors & Respiratory",
      "Fall Protection, Spill Kits & First Aid",
    ],
  },
  {
    code: "hydraulics_fleet_shop",
    label: "Fleet, Hydraulics & Field Service",
    shortLabel: "Fleet & Hydraulics",
    subtitle: "Cordless grease guns, diesel transfer pumps, jump starters, hydraulic gauges & shop gear.",
    marketplaceCategories: ["Heavy Equipment", "Tanks & Containers", "Transport & Hauling"],
    iconAsset: "assets/images/industrial_icons/03-fuel-and-fluid-equipment/05-industrial-pump.svg",
    subcategories: [
      "Diesel Transfer Pumps, Meters & Filters",
      "Grease Guns, Hose Reels & Lubrication",
      "Hydraulic Jacks, Rams, Pumps & Couplers",
      "Service Truck Compressors & Air Tools",
      "12V/24V Jump Packs, Chargers & HD Scanners",
      "Tire Service, Mud Flaps & Shop Consumables",
    ],
  },
  {
    code: "lighting_power_jobsite",
    label: "Jobsite Lighting, Power & Comms",
    shortLabel: "Lighting & Power",
    subtitle: "Magnetic LED work lights, inverter generators, heavy cords, two-way radios & jobsite boxes.",
    marketplaceCategories: ["Portable Buildings", "Heavy Equipment", "Land & Commercial Property"],
    iconAsset: "assets/images/industrial_icons/07-oil-and-gas-equipment/05-generator-units.svg",
    subcategories: [
      "Cordless Tower, Magnetic & Flood Lights",
      "Intrinsically Safe Flashlights & Headlamps",
      "Generators, Power Stations & Spider Boxes",
      "Heavy Cold-Weather Cords & Welding Adapters",
      "Jobsite Gang Boxes, Truck Chests & Cases",
      "Two-Way Radios, Coolers & Jobsite Heaters",
    ],
  },
  {
    code: "measuring_inspection",
    label: "Inspection, Gauges & Pipe Testing",
    shortLabel: "Inspection & Gauges",
    subtitle: "Ultrasonic wall-thickness gauges, pipe calipers, thread gauges, thermal & laser levels.",
    marketplaceCategories: ["Pipe", "Oilfield Equipment"],
    iconAsset: "assets/images/industrial_icons/17-pipe-and-materials/12-pipe-inspection-equipment.svg",
    subcategories: [
      "Ultrasonic Wall Thickness & NDT Kits",
      "Liquid-Filled Pressure Gauges & Hydrotest",
      "Pipe Calipers, Tally Tapes & Thread Gauges",
      "Borescopes, Sewer Cameras & Pipe Locators",
      "Thermal Imagers, Pyrometers & Leak Detectors",
      "Rotary Lasers, Digital Levels & Multimeters",
    ],
  },
  {
    code: "ranch_fencing_ag",
    label: "Farm, Ranch & Pipe Fencing Gear",
    shortLabel: "Ranch & Fencing",
    subtitle: "Post drivers, weld-on pipe hinges, gate latches, solar fencers & livestock water hardware.",
    marketplaceCategories: ["Farm & Ranch"],
    iconAsset: "assets/images/industrial_icons/18-farm-ranch-listings/10-custom-pipe-fabrication.svg",
    subcategories: [
      "Pipe Fence Coping, Saddles & Notchers",
      "Weld-On Hinges, Latches & Gate Hardware",
      "Gas Post Drivers, Augers & T-Post Tools",
      "Solar Fence Chargers, Wire & Strainers",
      "Stock Tank Valves, Waterers & Ag Pumps",
      "Livestock Chute, Trailer & Ranch Hardware",
    ],
  },
]);

const SHOP_CATEGORY_BY_CODE = new Map(
    SHOP_CATEGORIES.map((category) => [category.code, category]),
);

const SHOP_SOURCE_TYPES = new Set([
  "amazon_affiliate",
  "aliexpress_affiliate",
  "shopee_affiliate",
  "lazada_affiliate",
  "ebay_partner",
  "walmart_affiliate",
  "temu_affiliate",
  "tiktok_shop_affiliate",
  "alibaba_b2b",
  "hardware_pro_retail",
  "affiliate_network",
  "brand_partner",
  "distributor_affiliate",
  "vendor_catalog",
]);

const AFFILIATE_PLATFORMS_DIRECTORY = Object.freeze([
  {
    id: "amazon_associates",
    name: "Amazon Associates (US / CA / UK / AU / SG)",
    sourceType: "amazon_affiliate",
    categoryGroup: "global_marketplace",
    regions: ["US", "CA", "UK", "AU", "SG", "Global"],
    commissionRange: "1% - 10% (3% - 5.5% Tools & Industrial)",
    cookieWindow: "24 hours (90 days add-to-cart)",
    signupUrl: "https://affiliate-program.amazon.com/",
    trackingParamHint: "tag=pipebuyer-20 (auto-injected for US/CA/UK/AU/SG)",
    bestFor: "Cordless tools, RIDGID pipe wrenches, PPE, welding helmets, consumables",
    sampleDomains: ["amazon.com", "amazon.ca", "amazon.sg", "amzn.to", "a.co"],
  },
  {
    id: "aliexpress_portals",
    name: "AliExpress Portals Affiliate",
    sourceType: "aliexpress_affiliate",
    categoryGroup: "global_marketplace",
    regions: ["Global", "US", "CA", "SEA", "EU"],
    commissionRange: "3% - 9% standard (up to 50% Hot Products)",
    cookieWindow: "3 days",
    signupUrl: "https://portals.aliexpress.com/",
    trackingParamHint: "s.click.aliexpress.com short links or sk=<trackingId>",
    bestFor: "Ultrasonic NDT gauges, laser levels, welding accessories, shop tooling, electronics",
    sampleDomains: ["aliexpress.com", "aliexpress.us", "s.click.aliexpress.com", "a.aliexpress.com"],
  },
  {
    id: "shopee_affiliate",
    name: "Shopee Affiliate Program",
    sourceType: "shopee_affiliate",
    categoryGroup: "sea_marketplace",
    regions: ["SG", "MY", "PH", "TH", "ID", "VN", "TW", "BR"],
    commissionRange: "2% - 14% (+ Seller Xtra Commissions up to 25%)",
    cookieWindow: "7 days",
    signupUrl: "https://affiliate.shopee.sg/",
    trackingParamHint: "shope.ee / s.shopee.* short links or alphanumeric sub_id",
    bestFor: "Workwear, safety boots, hand tools, LED work lights, hardware in APAC & LATAM",
    sampleDomains: ["shopee.sg", "shopee.ph", "shopee.com.my", "shope.ee", "s.shopee.ph"],
  },
  {
    id: "lazada_lazaffiliate",
    name: "Lazada LazAffiliate Program",
    sourceType: "lazada_affiliate",
    categoryGroup: "sea_marketplace",
    regions: ["SG", "MY", "PH", "TH", "ID", "VN"],
    commissionRange: "4% - 12% (+ LazMall bonus commissions up to 25%)",
    cookieWindow: "7 days",
    signupUrl: "https://www.lazada.sg/lazaffiliate/",
    trackingParamHint: "s.lazada.* / c.lazada.* links or aff_sub=<subId>",
    bestFor: "LazMall authorized brand power tools (Bosch, Makita, Stanley), PPE & generators",
    sampleDomains: ["lazada.sg", "lazada.com.ph", "lazada.com.my", "s.lazada.com.ph"],
  },
  {
    id: "involve_asia",
    name: "Involve Asia (Unified Shopee + Lazada + AliExpress + TikTok Hub)",
    sourceType: "affiliate_network",
    categoryGroup: "affiliate_network",
    regions: ["SEA", "Global", "PH", "MY", "SG", "ID", "TH"],
    commissionRange: "2% - 20% across 500+ marketplaces & brands",
    cookieWindow: "1 - 30 days",
    signupUrl: "https://involve.asia/",
    trackingParamHint: "invol.co / invl.io deep links + ?subid=<involveAsiaSubId>",
    bestFor: "One dashboard & single payout for Shopee, Lazada, AliExpress, TikTok Shop & Tokopedia",
    sampleDomains: ["invol.co", "invl.io", "invle.co"],
  },
  {
    id: "ebay_partner_network",
    name: "eBay Partner Network (EPN)",
    sourceType: "ebay_partner",
    categoryGroup: "global_marketplace",
    regions: ["US", "CA", "UK", "AU", "DE", "Global"],
    commissionRange: "1% - 4% (Business & Industrial + Heavy Equipment Parts)",
    cookieWindow: "24 hours",
    signupUrl: "https://partnernetwork.ebay.com/",
    trackingParamHint: "ebay.us short links or campid=<10-digit EPN Campaign ID>",
    bestFor: "Surplus industrial valves, NOS pipe fittings, PLC controls, heavy truck & Cat parts",
    sampleDomains: ["ebay.com", "ebay.ca", "ebay.us"],
  },
  {
    id: "walmart_affiliate",
    name: "Walmart Affiliate Program",
    sourceType: "walmart_affiliate",
    categoryGroup: "global_marketplace",
    regions: ["US", "CA"],
    commissionRange: "1% - 4%",
    cookieWindow: "3 days",
    signupUrl: "https://affiliates.walmart.com/",
    trackingParamHint: "goto.walmart.com Impact tracking links",
    bestFor: "Automotive fluids, DEF, shop storage, coolers, workwear, jobsite consumables",
    sampleDomains: ["walmart.com", "walmart.ca", "goto.walmart.com"],
  },
  {
    id: "temu_affiliate",
    name: "Temu Affiliate Program",
    sourceType: "temu_affiliate",
    categoryGroup: "global_marketplace",
    regions: ["US", "CA", "UK", "AU", "EU", "SEA"],
    commissionRange: "10% - 30% order commission + new-app-download bonuses",
    cookieWindow: "7 days",
    signupUrl: "https://www.temu.com/affiliate.html",
    trackingParamHint: "temu.com / share.temu.com referral & product links",
    bestFor: "High-conversion budget workshop organizers, LED magnetic lights, Mechanic consumables",
    sampleDomains: ["temu.com", "share.temu.com"],
  },
  {
    id: "tiktok_shop_affiliate",
    name: "TikTok Shop Creator & Affiliate Partner",
    sourceType: "tiktok_shop_affiliate",
    categoryGroup: "global_marketplace",
    regions: ["US", "UK", "SG", "MY", "PH", "TH", "ID", "VN"],
    commissionRange: "8% - 25%",
    cookieWindow: "7 - 14 days",
    signupUrl: "https://seller.tiktok.com/",
    trackingParamHint: "vt.tiktok.com / vm.tiktok.com / shop.tiktok.com showcase links",
    bestFor: "Viral cordless tools, welding gadgets, magnetic work lights & workwear",
    sampleDomains: ["tiktok.com", "vt.tiktok.com", "vm.tiktok.com", "shop.tiktok.com"],
  },
  {
    id: "alibaba_dhgate_b2b",
    name: "Alibaba.com & DHgate Wholesale Affiliates",
    sourceType: "alibaba_b2b",
    categoryGroup: "global_marketplace",
    regions: ["Global"],
    commissionRange: "3% - 15% (high AOV bulk orders)",
    cookieWindow: "7 - 30 days",
    signupUrl: "https://alliance.alibaba.com/",
    trackingParamHint: "s.click.alibaba.com or dhgate.com affiliate links",
    bestFor: "Bulk pipe flanges, valves, rigging hardware, solar ranch pumps, wholesale PPE",
    sampleDomains: ["alibaba.com", "s.click.alibaba.com", "dhgate.com"],
  },
  {
    id: "vevor_affiliate",
    name: "VEVOR Industrial Equipment Affiliate",
    sourceType: "hardware_pro_retail",
    categoryGroup: "industrial_retail",
    regions: ["US", "CA", "UK", "AU", "EU"],
    commissionRange: "5% - 8% (high average order value $150 - $1,200)",
    cookieWindow: "30 days",
    signupUrl: "https://www.vevor.com/pages/affiliate-program",
    trackingParamHint: "Direct VEVOR / ShareASale / CJ links + UTM attribution",
    bestFor: "Pipe threaders, chain hoists, mag drills, diesel transfer pumps, pipe stands, jacks",
    sampleDomains: ["vevor.com", "ca.vevor.com"],
  },
  {
    id: "home_depot_pro",
    name: "The Home Depot Pro & Affiliate Program",
    sourceType: "hardware_pro_retail",
    categoryGroup: "industrial_retail",
    regions: ["US", "CA"],
    commissionRange: "1% - 8% (via Impact)",
    cookieWindow: "1 - 30 days",
    signupUrl: "https://www.homedepot.com/c/SF_MS_The_Home_Depot_Affiliate_Program",
    trackingParamHint: "homedepot.com or hd.sjv.io Impact tracking links",
    bestFor: "Milwaukee Packout, DeWalt, RIDGID, generators, jobsite boxes & cordless kits",
    sampleDomains: ["homedepot.com", "homedepot.ca", "thd.co"],
  },
  {
    id: "tractor_supply_ranch",
    name: "Tractor Supply Co. & Northern Tool Affiliates",
    sourceType: "hardware_pro_retail",
    categoryGroup: "industrial_retail",
    regions: ["US"],
    commissionRange: "3% - 7%",
    cookieWindow: "14 - 30 days",
    signupUrl: "https://www.tractorsupply.com/tsc/cms/affiliate-program",
    trackingParamHint: "tractorsupply.com / northerntool.com / Impact / CJ links",
    bestFor: "Truck transfer tanks, ranch fencing, post drivers, Traveller winches, welders",
    sampleDomains: ["tractorsupply.com", "northerntool.com"],
  },
  {
    id: "acme_tools_zoro",
    name: "Acme Tools & Zoro (Grainger Industrial Supply)",
    sourceType: "hardware_pro_retail",
    categoryGroup: "industrial_retail",
    regions: ["US"],
    commissionRange: "4% - 6% (industrial MRO high ticket)",
    cookieWindow: "14 - 30 days",
    signupUrl: "https://www.zoro.com/affiliates/",
    trackingParamHint: "acmetools.com (Impact) / zoro.com (CJ) / grainger.com",
    bestFor: "Authorized Lincoln/Miller welders, Crosby rigging, MRO valves, Enerpac hydraulics",
    sampleDomains: ["acmetools.com", "zoro.com", "grainger.com"],
  },
  {
    id: "bakers_gas_welding",
    name: "Baker's Gas & Welding / FR Workwear Retailers (Boot Barn, Ariat, Carhartt)",
    sourceType: "hardware_pro_retail",
    categoryGroup: "industrial_retail",
    regions: ["US", "CA"],
    commissionRange: "4% - 10% ($50 - $300+ per engine-driven welder sale)",
    cookieWindow: "30 days",
    signupUrl: "https://bakersgas.com/",
    trackingParamHint: "bakersgas.com / bootbarn.com / etrailer.com affiliate links",
    bestFor: "Miller Bobcat / Lincoln Ranger welders, plasma cutters, FR shirts, pipeline boots, trailer hitches",
    sampleDomains: ["bakersgas.com", "bootbarn.com", "etrailer.com", "lowes.com"],
  },
  {
    id: "impact_cj_shareasale_skimlinks",
    name: "Impact, CJ, ShareASale/Awin, Rakuten, Skimlinks & PartnerStack",
    sourceType: "affiliate_network",
    categoryGroup: "affiliate_network",
    regions: ["Global", "US", "CA", "UK", "AU", "SEA"],
    commissionRange: "3% - 30% (up to 30% recurring for fleet/ELD/SaaS on PartnerStack)",
    cookieWindow: "14 - 90 days",
    signupUrl: "https://impact.com/",
    trackingParamHint: "pxf.io, sjv.io, dpbolvw.net, shrsl.com, awin1.com, go.redirectingat.com",
    bestFor: "Universal affiliate shortlinks across 50,000+ tool, fleet, safety, insurance & software brands",
    sampleDomains: [
      "pxf.io",
      "sjv.io",
      "7eer.net",
      "dpbolvw.net",
      "anrdoezrs.net",
      "jdoqocy.com",
      "shareasale.com",
      "shrsl.com",
      "awin1.com",
      "click.linksynergy.com",
      "go.redirectingat.com",
      "partnerstack.com",
    ],
  },
]);

const SHOP_PRODUCT_STATUSES = new Set([
  "active",
  "paused",
  "draft",
  "archived",
]);

const VENDOR_PARTNERSHIP_TRACKS = new Set([
  "oem_heavy_equipment_dealer",
  "brand_manufacturer",
  "industrial_distributor",
  "verified_business_vendor",
  "affiliate_network_partner",
]);

const VENDOR_APPLICATION_EXTRA_CATEGORIES = Object.freeze([
  {
    code: "heavy_equipment_oem",
    label: "Heavy Equipment, Tractors & Attachments",
    shortLabel: "Heavy Equipment & Tractors",
  },
  {
    code: "oem_parts_undercarriage",
    label: "OEM Parts, Undercarriage & Wear Components",
    shortLabel: "OEM Parts & Wear",
  },
  {
    code: "diagnostic_service_truck",
    label: "Diagnostics, Torque & Service Truck Tooling",
    shortLabel: "Diagnostics & Fleet Tooling",
  },
]);

const VENDOR_APPLICATION_CATEGORY_CODES = new Set([
  ...SHOP_CATEGORIES.map((category) => category.code),
  ...VENDOR_APPLICATION_EXTRA_CATEGORIES.map((category) => category.code),
]);

const VENDOR_REQUESTED_PLACEMENTS = new Set([
  "shop_storefront",
  "heavy_equipment_listings",
  "brand_spotlight_deals",
  "contextual_recommendations",
]);

const VENDOR_AUTHORIZATION_LEVELS = new Set([
  "oem_direct",
  "authorized_dealer",
  "national_distributor",
  "reseller_affiliate",
]);

const VENDOR_INTEGRATION_METHODS = new Set([
  "direct_dealer_link",
  "csv_spreadsheet",
  "api_xml_feed",
  "manual_curated",
  "affiliate_network",
]);

const VENDOR_APPLICATION_STATUSES = new Set([
  "pending",
  "under_review",
  "approved",
  "waitlisted",
  "declined",
]);

const SHOP_PLACEMENTS = new Set([
  "store_grid",
  "store_detail",
  "home_showcase",
  "listing_contextual",
  "brand_spotlight",
  "admin_preview",
]);

const SHOP_STAFF_ROLES = new Set([
  "affiliate_contributor",
  "catalog_editor",
  "store_manager",
]);

const ALL_SHOP_ROLES = new Set([
  "affiliate_contributor",
  "catalog_editor",
  "store_manager",
  "administrator",
]);

const KNOWN_INDUSTRIAL_BRANDS = Object.freeze([
  "Lincoln Electric",
  "BW Technologies",
  "Brandt Tractor",
  "Caterpillar",
  "Klein Tools",
  "John Deere",
  "Milwaukee",
  "Snap-on",
  "Snap-On",
  "Komatsu",
  "RIDGID",
  "DeWalt",
  "DEWALT",
  "Miller",
  "Bobcat",
  "Brandt",
  "Carhartt",
  "Crosby",
  "Fluke",
  "Ariat",
  "Honeywell",
  "MSA",
  "Starrett",
  "Makita",
  "Bosch",
  "Knipex",
  "Proto",
  "Enerpac",
  "Fill-Rite",
  "Honda",
  "Pelican",
  "Midland",
  "Gallagher",
  "Sumner",
  "ESAB",
  "Hobart",
  "VEVOR",
  "Ingco",
  "Total Tools",
  "Stanley",
]);

const DEFAULT_STORE_SETTINGS = Object.freeze({
  storeEnabled: true,
  vendorApplicationsOpen: true,
  amazonAssociateTagUs: "pipebuyer-20",
  amazonAssociateTagCa: "pipebuyer0c-20",
  amazonAssociateTagUk: "",
  amazonAssociateTagAu: "",
  amazonAssociateTagSg: "",
  aliexpressTrackingId: "",
  shopeeAffiliateSubId: "",
  lazadaAffiliateSubId: "",
  involveAsiaSubId: "",
  ebayCampaignId: "",
  skimlinksPublisherId: "",
  forceOverrideAmazonTag: false,
  defaultUtmSource: "pipebuyer",
  defaultUtmMedium: "affiliate_store",
  disclosureText:
    "As an Amazon Associate and authorized global affiliate partner (including AliExpress, Lazada, Shopee, eBay & industrial retailers), Pipe Buyer earns from qualifying purchases at no additional cost to you.",
  priceDisclaimerText:
    "Product prices and availability are accurate as of the time shown on the partner site and are subject to change.",
  hiddenStarterIds: Object.freeze([]),
  adminNotificationEmails: Object.freeze([]),
});

function cleanText(value, maxLength = 240) {
  if (value == null) return "";
  return String(value)
      .replace(/[\u0000-\u001F\u007F]/g, " ")
      .replace(/\s+/g, " ")
      .trim()
      .slice(0, maxLength);
}

function cleanStringList(value, {maxItems = 20, maxItemLength = 80} = {}) {
  if (!Array.isArray(value)) return [];
  const seen = new Set();
  const output = [];
  for (const raw of value) {
    const item = cleanText(raw, maxItemLength);
    if (!item) continue;
    const key = item.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    output.push(item);
    if (output.length >= maxItems) break;
  }
  return output;
}

function normalizeAssociateTag(value) {
  const tag = cleanText(value, 64);
  if (!tag) return "";
  if (!/^[A-Za-z0-9._-]{2,64}$/.test(tag)) {
    throw new HttpsError(
        "invalid-argument",
        `Affiliate tag "${tag}" may only contain letters, numbers, hyphens, underscores, or dots.`,
    );
  }
  return tag;
}

function isPrivateOrLocalHostname(hostname) {
  const host = String(hostname || "").trim().toLowerCase();
  if (!host) return true;
  if (
    host === "localhost" ||
    host.endsWith(".localhost") ||
    host.endsWith(".local") ||
    host === "[::1]" ||
    host === "::1"
  ) {
    return true;
  }
  const ipv4Match = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (ipv4Match) {
    const octets = ipv4Match.slice(1).map((part) => Number(part));
    if (octets.some((n) => n < 0 || n > 255)) return true;
    const [a, b] = octets;
    if (a === 10 || a === 127 || a === 0) return true;
    if (a === 169 && b === 254) return true;
    if (a === 192 && b === 168) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
  }
  return false;
}

function parseSafeHttpsUrl(rawUrl, fieldLabel = "Destination URL") {
  const trimmed = cleanText(rawUrl, 2000);
  if (!trimmed) {
    throw new HttpsError("invalid-argument", `${fieldLabel} is required.`);
  }
  let parsed;
  try {
    parsed = new URL(trimmed);
  } catch {
    throw new HttpsError("invalid-argument", `${fieldLabel} must be a valid HTTPS URL.`);
  }
  if (parsed.protocol !== "https:") {
    throw new HttpsError("invalid-argument", `${fieldLabel} must use HTTPS.`);
  }
  if (parsed.username || parsed.password) {
    throw new HttpsError("invalid-argument", `${fieldLabel} must not embed credentials.`);
  }
  if (isPrivateOrLocalHostname(parsed.hostname) || !parsed.hostname.includes(".")) {
    throw new HttpsError("invalid-argument", `${fieldLabel} must point to a public domain.`);
  }
  return parsed;
}

function isAmazonFullHostname(hostname) {
  const host = String(hostname || "").toLowerCase();
  return (
    host === "amazon.com" ||
    host.endsWith(".amazon.com") ||
    host === "amazon.ca" ||
    host.endsWith(".amazon.ca") ||
    host === "amazon.co.uk" ||
    host.endsWith(".amazon.co.uk") ||
    host === "amazon.com.au" ||
    host.endsWith(".amazon.com.au") ||
    host === "amazon.sg" ||
    host.endsWith(".amazon.sg") ||
    host === "amazon.ae" ||
    host.endsWith(".amazon.ae") ||
    host === "amazon.sa" ||
    host.endsWith(".amazon.sa") ||
    host === "amazon.de" ||
    host.endsWith(".amazon.de") ||
    host === "amazon.co.jp" ||
    host.endsWith(".amazon.co.jp") ||
    host === "amazon.com.mx" ||
    host.endsWith(".amazon.com.mx") ||
    host === "amazon.com.br" ||
    host.endsWith(".amazon.com.br")
  );
}

function isAmazonShortHostname(hostname) {
  const host = String(hostname || "").toLowerCase();
  return (
    host === "amzn.to" ||
    host === "a.co" ||
    host === "link.amazon" ||
    host.endsWith(".link.amazon") ||
    host === "amzlinks.in" ||
    host.endsWith(".amzlinks.in")
  );
}

const SHOP_COUNTRY_CODES = new Set([
  "GLOBAL",
  "US",
  "CA",
  "MX",
  "BR",
  "PH",
  "SG",
  "MY",
  "TH",
  "ID",
  "VN",
  "TW",
  "AU",
  "NZ",
  "GB",
  "EU",
  "AE",
  "SA",
  "JP",
  "IN",
]);

const SHOP_COUNTRY_ALIASES = Object.freeze({
  WORLDWIDE: "GLOBAL",
  ALL: "GLOBAL",
  INTERNATIONAL: "GLOBAL",
  INTL: "GLOBAL",
  USA: "US",
  CAN: "CA",
  UK: "GB",
  UAE: "AE",
  KSA: "SA",
  PHL: "PH",
  SGP: "SG",
  MYS: "MY",
  THA: "TH",
  IDN: "ID",
  VNM: "VN",
  AUS: "AU",
});

function normalizeCountryCodeToken(raw) {
  const upper = cleanText(raw, 24).toUpperCase();
  if (!upper) return "";
  const mapped = SHOP_COUNTRY_ALIASES[upper] || upper;
  return SHOP_COUNTRY_CODES.has(mapped) ? mapped : "";
}

function normalizeEligibleCountries(value, fallback = ["GLOBAL"]) {
  const rawTokens = Array.isArray(value) ?
    value :
    typeof value === "string" ?
      value.split(/[,;|/\s]+/) :
      [];
  const seen = new Set();
  const output = [];
  for (const item of rawTokens) {
    const code = normalizeCountryCodeToken(item);
    if (!code || seen.has(code)) continue;
    if (code === "GLOBAL") {
      return ["GLOBAL"];
    }
    seen.add(code);
    output.push(code);
    if (output.length >= 20) break;
  }
  if (output.length > 0) {
    return output;
  }
  return Array.isArray(fallback) && fallback.length > 0 ? [...fallback] : ["GLOBAL"];
}

function inferEligibleCountries(hostnameOrUrl, sourceType = "", asin = "") {
  let host = String(hostnameOrUrl || "").trim().toLowerCase();
  if (host.includes("://")) {
    try {
      host = new URL(host).hostname.toLowerCase();
    } catch {
      host = "";
    }
  }
  if (!host) {
    return ["GLOBAL"];
  }
  if (hostMatches(host, ["lazada.com.ph", "s.lazada.com.ph", "c.lazada.com.ph", "shopee.ph", "s.shopee.ph", "ebay.ph"])) {
    return ["PH"];
  }
  if (hostMatches(host, ["lazada.sg", "s.lazada.sg", "c.lazada.sg", "shopee.sg", "s.shopee.sg", "amazon.sg", "ebay.com.sg", "ebay.sg"])) {
    return ["SG"];
  }
  if (hostMatches(host, ["lazada.com.my", "s.lazada.com.my", "c.lazada.com.my", "shopee.com.my", "s.shopee.com.my", "ebay.com.my"])) {
    return ["MY"];
  }
  if (hostMatches(host, ["lazada.co.th", "s.lazada.co.th", "shopee.co.th", "s.shopee.co.th"])) {
    return ["TH"];
  }
  if (hostMatches(host, ["lazada.co.id", "s.lazada.co.id", "shopee.co.id", "s.shopee.co.id"])) {
    return ["ID"];
  }
  if (hostMatches(host, ["lazada.vn", "s.lazada.vn", "shopee.vn", "s.shopee.vn"])) {
    return ["VN"];
  }
  if (hostMatches(host, ["shopee.tw", "s.shopee.tw"])) {
    return ["TW"];
  }
  if (hostMatches(host, ["shopee.com.br", "s.shopee.com.br", "amazon.com.br"])) {
    return ["BR"];
  }
  if (hostMatches(host, ["shopee.com.mx", "amazon.com.mx"])) {
    return ["MX"];
  }
  if (hostMatches(host, ["amazon.co.uk", "ebay.co.uk"])) {
    return ["GB"];
  }
  if (hostMatches(host, ["amazon.com.au", "ebay.com.au"])) {
    return ["AU"];
  }
  if (hostMatches(host, ["amazon.ae"])) {
    return ["AE"];
  }
  if (hostMatches(host, ["amazon.sa"])) {
    return ["SA"];
  }
  if (hostMatches(host, ["amazon.de", "amazon.fr", "amazon.it", "amazon.es", "amazon.nl"])) {
    return ["EU"];
  }
  if (hostMatches(host, ["amazon.co.jp"])) {
    return ["JP"];
  }
  if (hostMatches(host, ["canadiantire.ca", "princessauto.com", "homedepot.ca", "lowes.ca", "walmart.ca", "vevor.ca", "ebay.ca"])) {
    return ["CA"];
  }
  if (hostMatches(host, ["amazon.ca"])) {
    return asin ? ["US", "CA"] : ["CA"];
  }
  if (hostMatches(host, [
    "tractorsupply.com",
    "northerntool.com",
    "harborfreight.com",
    "acmetools.com",
    "zoro.com",
    "grainger.com",
    "homedepot.com",
    "thd.co",
    "lowes.com",
    "walmart.com",
    "goto.walmart.com",
    "bootbarn.com",
    "bakersgas.com",
    "etrailer.com",
  ])) {
    return ["US"];
  }
  if (hostMatches(host, ["vevor.com"])) {
    return ["US", "CA"];
  }
  if (hostMatches(host, [
    "aliexpress.com",
    "aliexpress.us",
    "aliexpress.ru",
    "s.click.aliexpress.com",
    "a.aliexpress.com",
    "star.aliexpress.com",
    "ali.ski",
    "alibaba.com",
    "s.click.alibaba.com",
    "dhgate.com",
    "dhg.to",
    "temu.com",
    "temu.to",
  ])) {
    return ["GLOBAL"];
  }
  if (hostMatches(host, ["shope.ee", "shp.ee", "shopee.com", "lazada.com", "lzd.co"])) {
    return ["PH", "SG", "MY", "TH", "ID", "VN"];
  }
  if (isAmazonShortHostname(host) || hostMatches(host, ["amazon.com"])) {
    return ["US", "CA"];
  }
  if (hostMatches(host, ["ebay.com", "ebay.us", "ebay.to"])) {
    return ["US", "CA", "GB", "AU"];
  }
  if (sourceType === "aliexpress_affiliate" || sourceType === "alibaba_b2b" || sourceType === "temu_affiliate") {
    return ["GLOBAL"];
  }
  return ["GLOBAL"];
}

function doesProductShipToCountry(eligibleCountries, countryCode) {
  const rawCountry = cleanText(countryCode, 24).toUpperCase();
  if (!rawCountry || rawCountry === "ALL" || rawCountry === "GLOBAL" || rawCountry === "WORLDWIDE") {
    return true;
  }
  const normalizedTarget = normalizeCountryCodeToken(rawCountry);
  if (!normalizedTarget || normalizedTarget === "GLOBAL") {
    return true;
  }
  const list = normalizeEligibleCountries(eligibleCountries, ["GLOBAL"]);
  if (list.includes("GLOBAL")) {
    return true;
  }
  return list.includes(normalizedTarget);
}

function cleanMarketplaceTitle(rawTitle) {
  let title = cleanText(decodeHtmlEntities(String(rawTitle || "")), 220);
  if (!title) return "";
  if (/^(?:sorry! something went wrong|robot check|access denied|just a moment|page not found|404)/i.test(title)) {
    return "";
  }
  title = title
      .replace(/^(?:amazon\.(?:com|ca|co\.uk|com\.au|sg)\s*[:|-]\s*)/i, "")
      .replace(/\s*[|-]\s*(?:amazon\.(?:com|ca|co\.uk|com\.au|sg)|lazada(?:\s+ph|\s+philippines|\s+sg|\s+my)?|shopee(?:\s+philippines|\s+singapore|\s+malaysia)?|aliexpress|ebay|walmart\.com|temu|tiktok\s*shop).*$/i, "")
      .replace(/\s*:\s*(?:tools\s*&\s*home\s*improvement|industrial\s*&\s*scientific|automotive|patio,\s*lawn\s*&\s*garden|electronics).*$/i, "")
      .trim();
  return cleanText(title, 160);
}

function extractMetaContent(html, attrPattern) {
  const tagRegex = new RegExp(`<meta[^>]+(?:property|name)=["'](?:${attrPattern})["'][^>]*>`, "gi");
  let match;
  while ((match = tagRegex.exec(html)) !== null) {
    const contentMatch = match[0].match(/content=["']([^"']+)["']/i);
    if (contentMatch && contentMatch[1]) {
      return decodeHtmlEntities(contentMatch[1]).trim();
    }
  }
  const revRegex = new RegExp(`<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["'](?:${attrPattern})["'][^>]*>`, "gi");
  const revMatch = revRegex.exec(html);
  if (revMatch && revMatch[1]) {
    return decodeHtmlEntities(revMatch[1]).trim();
  }
  return "";
}

function toValidProductImageUrl(candidate, baseUrlStr = "") {
  const raw = decodeHtmlEntities(String(candidate || "").trim());
  if (!raw) return "";
  let resolved = raw;
  if (resolved.startsWith("//")) {
    resolved = `https:${resolved}`;
  } else if (resolved.startsWith("/") && baseUrlStr) {
    try {
      resolved = new URL(resolved, baseUrlStr).toString();
    } catch {
      return "";
    }
  }
  try {
    const parsed = parseSafeHttpsUrl(resolved, "Image URL");
    if (/ir-na\.amazon-adsystem\.com|assoc-amazon\.com|pixel|1x1|spacer|sprite|logo|favicon/i.test(parsed.href)) {
      return "";
    }
    return parsed.toString();
  } catch {
    return "";
  }
}

function upgradeAmazonCdnImageResolution(urlStr) {
  if (!urlStr || !/m\.media-amazon\.com\/images\/I\//i.test(urlStr)) {
    return urlStr;
  }
  return urlStr.replace(/\._AC_[A-Z0-9,_]+_\./i, "._AC_SL1000_.");
}

function isAmazonSearchPageUrl(rawUrl) {
  const text = cleanText(rawUrl, 2000);
  if (!text) return false;
  try {
    const parsed = new URL(text);
    if (!isAmazonFullHostname(parsed.hostname)) return false;
    if (/^\/s(?:\/|$)/i.test(parsed.pathname)) return true;
    if (parsed.searchParams.has("k") || parsed.searchParams.has("field-keywords")) return true;
    if (String(parsed.searchParams.get("ar_mt") || "").toUpperCase() === "SEARCH_PAGE") return true;
    return false;
  } catch {
    return false;
  }
}

function extractHtmlProductMetadata(html, finalUrlStr = "") {
  const source = String(html || "");
  if (!source) {
    return {
      asin: "",
      title: "",
      imageUrl: "",
      brand: "",
      priceDisplay: "",
      breadcrumbs: [],
      highlights: [],
    };
  }

  let ldTitle = "";
  let ldImage = "";
  let ldBrand = "";
  let ldPrice = "";
  const ldRegex = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let ldMatch;
  while ((ldMatch = ldRegex.exec(source)) !== null) {
    const rawJson = (ldMatch[1] || "").trim();
    if (!rawJson || rawJson.length > 150000) continue;
    try {
      const parsed = JSON.parse(rawJson);
      const queue = Array.isArray(parsed) ? [...parsed] : [parsed];
      while (queue.length > 0) {
        const node = queue.shift();
        if (!node || typeof node !== "object") continue;
        if (Array.isArray(node["@graph"])) queue.push(...node["@graph"]);
        const typeVal = Array.isArray(node["@type"]) ? node["@type"].join(" ") : String(node["@type"] || "");
        if (/product/i.test(typeVal)) {
          if (!ldTitle && typeof node.name === "string") ldTitle = cleanMarketplaceTitle(node.name);
          if (!ldImage) {
            const rawImg = Array.isArray(node.image) ? node.image[0] :
              (node.image && typeof node.image === "object" ? node.image.url : node.image);
            ldImage = toValidProductImageUrl(rawImg, finalUrlStr);
          }
          if (!ldBrand && node.brand) {
            const b = typeof node.brand === "string" ? node.brand : node.brand.name;
            if (typeof b === "string") ldBrand = cleanText(decodeHtmlEntities(b), 80);
          }
          if (!ldPrice && node.offers) {
            const offer = Array.isArray(node.offers) ? node.offers[0] : node.offers;
            if (offer && (offer.price || offer.lowPrice)) {
              const currency = cleanText(offer.priceCurrency || "", 8);
              const amount = cleanText(String(offer.price || offer.lowPrice), 24);
              const sym = currency === "USD" ? "$" : currency === "CAD" ? "CA$" : currency === "PHP" ? "₱" : currency === "SGD" ? "S$" : (currency ? `${currency} ` : "$");
              ldPrice = `${sym}${amount}`;
            }
          }
        }
      }
    } catch {
      // Ignore malformed JSON-LD blocks on partner pages
    }
  }

  const amzProductTitleMatch = source.match(/id=["']productTitle["'][^>]*>([\s\S]*?)<\/span>/i);
  const amzProductTitle = amzProductTitleMatch && amzProductTitleMatch[1] ?
    cleanMarketplaceTitle(amzProductTitleMatch[1].replace(/<[^>]+>/g, " ")) :
    "";
  const ogTitle = cleanMarketplaceTitle(extractMetaContent(source, "og:title|twitter:title"));
  const htmlTitleMatch = source.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  const docTitle = htmlTitleMatch && htmlTitleMatch[1] ?
    cleanMarketplaceTitle(htmlTitleMatch[1].replace(/<[^>]+>/g, " ")) :
    "";

  const amzHiResMatch =
    source.match(/"hiRes"\s*:\s*"(https:\/\/m\.media-amazon\.com\/images\/I\/[^"]+)"/i) ||
    source.match(/"large"\s*:\s*"(https:\/\/m\.media-amazon\.com\/images\/I\/[^"]+)"/i) ||
    source.match(/data-old-hires=["'](https:[^"']+)["']/i) ||
    source.match(/id=["']landingImage["'][^>]*src=["'](https:[^"']+)["']/i);
  const amzImg = amzHiResMatch && amzHiResMatch[1] ?
    upgradeAmazonCdnImageResolution(
        toValidProductImageUrl(amzHiResMatch[1].replace(/\\u0026/g, "&"), finalUrlStr),
    ) :
    "";
  const ogImg = toValidProductImageUrl(
      extractMetaContent(source, "og:image:secure_url|og:image|twitter:image:src|twitter:image"),
      finalUrlStr,
  );

  const metaPriceAmt = extractMetaContent(source, "product:price:amount|og:price:amount");
  const metaPriceCur = extractMetaContent(source, "product:price:currency|og:price:currency");
  let metaPrice = "";
  if (metaPriceAmt) {
    const sym = metaPriceCur === "PHP" ? "₱" : metaPriceCur === "CAD" ? "CA$" : metaPriceCur === "SGD" ? "S$" : (metaPriceCur && metaPriceCur !== "USD" ? `${metaPriceCur} ` : "$");
    metaPrice = cleanText(`${sym}${metaPriceAmt}`, 48);
  }
  const amzOffscreenPriceMatch = source.match(
      /class=["'][^"']*a-price[^"']*["'][^>]*>\s*<span[^>]*class=["'][^"']*a-offscreen[^"']*["'][^>]*>(\$[0-9,]+(?:\.[0-9]{2})?)<\/span>/i,
  );
  const amzDomPrice = amzOffscreenPriceMatch && amzOffscreenPriceMatch[1] ?
    cleanText(decodeHtmlEntities(amzOffscreenPriceMatch[1]), 48) :
    "";

  const bylineMatch = source.match(/id=["']bylineInfo["'][^>]*>([\s\S]*?)<\/a>/i);
  let amzBylineBrand = "";
  if (bylineMatch && bylineMatch[1]) {
    amzBylineBrand = cleanText(
        decodeHtmlEntities(bylineMatch[1].replace(/<[^>]+>/g, " "))
            .replace(/^visit the\s+/i, "")
            .replace(/\s+store$/i, "")
            .replace(/^brand:\s*/i, ""),
        80,
    );
  }

  const asinInputMatch =
    source.match(/<input[^>]+(?:id|name)=["']ASIN["'][^>]+value=["']([A-Z0-9]{10})["']/i) ||
    source.match(/<link[^>]+rel=["']canonical["'][^>]+href=["'][^"']*\/dp\/([A-Z0-9]{10})(?:[/?#"']|$)/i);
  const htmlAsin = asinInputMatch && asinInputMatch[1] ? asinInputMatch[1].toUpperCase() : "";

  const breadcrumbs = [];
  const crumbBlockMatch = source.match(
      /id=["']wayfinding-breadcrumbs_feature_div["'][\s\S]*?<\/ul>/i,
  );
  if (crumbBlockMatch && crumbBlockMatch[0]) {
    const crumbLinkRegex = /<a[^>]*>([\s\S]*?)<\/a>/gi;
    let cMatch;
    while ((cMatch = crumbLinkRegex.exec(crumbBlockMatch[0])) !== null) {
      const label = cleanText(decodeHtmlEntities(cMatch[1].replace(/<[^>]+>/g, " ")), 80);
      if (label && breadcrumbs.length < 8) {
        breadcrumbs.push(label);
      }
    }
  }

  const highlights = [];
  const bulletsBlockMatch = source.match(
      /id=["']feature-bullets["'][\s\S]*?<\/ul>/i,
  );
  if (bulletsBlockMatch && bulletsBlockMatch[0]) {
    const bulletRegex = /<span[^>]+class=["'][^"']*a-list-item[^"']*["'][^>]*>([\s\S]*?)<\/span>/gi;
    let bMatch;
    while ((bMatch = bulletRegex.exec(bulletsBlockMatch[0])) !== null) {
      const bullet = cleanText(decodeHtmlEntities(bMatch[1].replace(/<[^>]+>/g, " ")), 100);
      if (
        bullet.length >= 12 &&
        !/^(?:make sure this fits|enter your model number)/i.test(bullet) &&
        highlights.length < 4
      ) {
        highlights.push(bullet);
      }
    }
  }

  const bestTitle = amzProductTitle || ldTitle || ogTitle || docTitle;
  const bestImage = amzImg || ogImg || ldImage;
  const bestBrand = ldBrand || inferBrandFromText(bestTitle) || amzBylineBrand;
  const bestPrice = ldPrice || metaPrice || amzDomPrice;

  return {
    asin: htmlAsin,
    title: bestTitle,
    imageUrl: bestImage,
    brand: bestBrand,
    priceDisplay: bestPrice,
    breadcrumbs,
    highlights,
  };
}

function extractAmazonSearchCandidates(html, settings = DEFAULT_STORE_SETTINGS) {
  const source = String(html || "");
  if (!source) return [];
  const mergedSettings = {...DEFAULT_STORE_SETTINGS, ...(settings || {})};
  const cardRegex = /<div[^>]+data-asin=["']([A-Z0-9]{10})["'][^>]*data-component-type=["']s-search-result["'][^>]*>|<div[^>]+data-component-type=["']s-search-result["'][^>]*data-asin=["']([A-Z0-9]{10})["'][^>]*>/gi;
  const matches = [];
  let m;
  while ((m = cardRegex.exec(source)) !== null) {
    matches.push({asin: (m[1] || m[2] || "").toUpperCase(), start: m.index});
  }

  const seen = new Set();
  const candidates = [];
  for (let i = 0; i < matches.length; i++) {
    const {asin, start} = matches[i];
    if (!asin || seen.has(asin)) continue;
    const end = i + 1 < matches.length ?
      Math.min(matches[i + 1].start, start + 24000) :
      Math.min(source.length, start + 24000);
    const block = source.slice(start, end);

    const h2Match = block.match(/<h2[^>]*>([\s\S]*?)<\/h2>/i);
    const imgAltMatch = block.match(/<img[^>]+class=["'][^"']*s-image[^"']*["'][^>]+alt=["']([^"']+)["']/i);
    const rawTitle = h2Match && h2Match[1] ?
      h2Match[1].replace(/<[^>]+>/g, " ") :
      (imgAltMatch && imgAltMatch[1] ? imgAltMatch[1] : "");
    const title = cleanMarketplaceTitle(rawTitle.replace(/^Sponsored Ad\s*[-–—:]?\s*/i, ""));
    if (!title || title.length < 4) continue;

    const imgSrcMatch =
      block.match(/<img[^>]+class=["'][^"']*s-image[^"']*["'][^>]+src=["'](https:\/\/m\.media-amazon\.com\/images\/I\/[^"']+)["']/i) ||
      block.match(/src=["'](https:\/\/m\.media-amazon\.com\/images\/I\/[^"']+)["']/i);
    const rawImg = imgSrcMatch && imgSrcMatch[1] ? imgSrcMatch[1] : "";
    const imageUrl = upgradeAmazonCdnImageResolution(toValidProductImageUrl(rawImg, "https://www.amazon.com"));

    const priceMatch = block.match(
        /class=["'][^"']*a-price[^"']*["'][^>]*>\s*<span[^>]*class=["'][^"']*a-offscreen[^"']*["'][^>]*>(\$[0-9,]+(?:\.[0-9]{2})?)<\/span>/i,
    );
    const priceDisplay = priceMatch && priceMatch[1] ? cleanText(decodeHtmlEntities(priceMatch[1]), 32) : "";

    const brand = inferBrandFromText(title);
    const categoryCode = inferCategoryCodeFromText(`${title} ${brand}`);
    const subcategory = inferSubcategoryFromText(`${title} ${brand}`, categoryCode);
    const baseDpUrl = `https://www.amazon.com/dp/${asin}?linkCode=ll1`;
    const destinationUrl = buildMonetizedDestinationUrl(
        {sourceType: "amazon_affiliate", asin, categoryCode, destinationUrl: baseDpUrl},
        mergedSettings,
        {regionCode: "US"},
    );

    seen.add(asin);
    candidates.push({
      asin,
      title,
      brand,
      categoryCode,
      subcategory,
      imageUrl,
      priceDisplay,
      destinationUrl,
    });
    if (candidates.length >= 6) break;
  }
  return candidates;
}

function hostMatches(hostname, candidates) {
  const host = String(hostname || "").toLowerCase();
  return candidates.some((domain) => host === domain || host.endsWith(`.${domain}`));
}

function detectAffiliatePlatform(hostnameOrUrl) {
  let host = String(hostnameOrUrl || "").trim().toLowerCase();
  if (host.includes("://")) {
    try {
      host = new URL(host).hostname.toLowerCase();
    } catch {
      host = "";
    }
  }
  if (!host) {
    return {
      platformId: "amazon_associates",
      platformName: "Amazon",
      sourceType: "amazon_affiliate",
      vendorName: "Amazon",
      ctaLabel: "View on Amazon",
      isShortLink: false,
    };
  }

  if (isAmazonShortHostname(host) || isAmazonFullHostname(host)) {
    return {
      platformId: "amazon_associates",
      platformName: "Amazon",
      sourceType: "amazon_affiliate",
      vendorName: "Amazon",
      ctaLabel: "View on Amazon",
      isShortLink: isAmazonShortHostname(host),
    };
  }

  const aliShort = hostMatches(host, ["s.click.aliexpress.com", "a.aliexpress.com", "star.aliexpress.com"]);
  if (aliShort || hostMatches(host, ["aliexpress.com", "aliexpress.us", "aliexpress.ru"])) {
    return {
      platformId: "aliexpress_portals",
      platformName: "AliExpress",
      sourceType: "aliexpress_affiliate",
      vendorName: "AliExpress",
      ctaLabel: "View on AliExpress",
      isShortLink: aliShort,
    };
  }

  const shopeeShort = host === "shope.ee" ||
    host.endsWith(".shope.ee") ||
    /^s\.shopee\.[a-z.]+$/.test(host) ||
    /^shp\.ee$/.test(host);
  if (
    shopeeShort ||
    hostMatches(host, [
      "shopee.sg",
      "shopee.com.my",
      "shopee.ph",
      "shopee.co.th",
      "shopee.co.id",
      "shopee.vn",
      "shopee.tw",
      "shopee.com.br",
      "shopee.com",
    ])
  ) {
    return {
      platformId: "shopee_affiliate",
      platformName: "Shopee",
      sourceType: "shopee_affiliate",
      vendorName: "Shopee",
      ctaLabel: "View on Shopee",
      isShortLink: shopeeShort,
    };
  }

  const lazadaShort = /^(?:s|c)\.lazada\.[a-z.]+$/.test(host) || host === "lzd.co" || host.endsWith(".lzd.co");
  if (
    lazadaShort ||
    hostMatches(host, [
      "lazada.sg",
      "lazada.com.my",
      "lazada.com.ph",
      "lazada.co.th",
      "lazada.co.id",
      "lazada.vn",
      "lazada.com",
    ])
  ) {
    return {
      platformId: "lazada_lazaffiliate",
      platformName: "Lazada",
      sourceType: "lazada_affiliate",
      vendorName: "Lazada",
      ctaLabel: "View on Lazada",
      isShortLink: lazadaShort,
    };
  }

  const ebayShort = host === "ebay.us" || host.endsWith(".ebay.us") || host === "ebay.to";
  if (
    ebayShort ||
    hostMatches(host, ["ebay.com", "ebay.ca", "ebay.co.uk", "ebay.com.au", "ebay.ph", "ebay.sg"])
  ) {
    return {
      platformId: "ebay_partner_network",
      platformName: "eBay",
      sourceType: "ebay_partner",
      vendorName: "eBay",
      ctaLabel: "View on eBay",
      isShortLink: ebayShort,
    };
  }

  const walmartShort = hostMatches(host, ["goto.walmart.com", "walmart.pxf.io"]);
  if (walmartShort || hostMatches(host, ["walmart.com", "walmart.ca"])) {
    return {
      platformId: "walmart_affiliate",
      platformName: "Walmart",
      sourceType: "walmart_affiliate",
      vendorName: "Walmart",
      ctaLabel: "View on Walmart",
      isShortLink: walmartShort,
    };
  }

  const temuShort = hostMatches(host, ["share.temu.com", "app.temu.com"]);
  if (temuShort || hostMatches(host, ["temu.com"])) {
    return {
      platformId: "temu_affiliate",
      platformName: "Temu",
      sourceType: "temu_affiliate",
      vendorName: "Temu",
      ctaLabel: "View on Temu",
      isShortLink: temuShort,
    };
  }

  const tiktokShort = hostMatches(host, ["vt.tiktok.com", "vm.tiktok.com"]);
  if (tiktokShort || hostMatches(host, ["tiktok.com", "shop.tiktok.com"])) {
    return {
      platformId: "tiktok_shop_affiliate",
      platformName: "TikTok Shop",
      sourceType: "tiktok_shop_affiliate",
      vendorName: "TikTok Shop",
      ctaLabel: "View on TikTok Shop",
      isShortLink: tiktokShort,
    };
  }

  const alibabaShort = hostMatches(host, ["s.click.alibaba.com"]);
  if (alibabaShort || hostMatches(host, ["alibaba.com", "dhgate.com"])) {
    const isDhgate = hostMatches(host, ["dhgate.com"]);
    return {
      platformId: "alibaba_dhgate_b2b",
      platformName: isDhgate ? "DHgate" : "Alibaba",
      sourceType: "alibaba_b2b",
      vendorName: isDhgate ? "DHgate" : "Alibaba",
      ctaLabel: isDhgate ? "View on DHgate" : "View on Alibaba",
      isShortLink: alibabaShort,
    };
  }

  if (hostMatches(host, ["invol.co", "invl.io", "invle.co"])) {
    return {
      platformId: "involve_asia",
      platformName: "Involve Asia",
      sourceType: "affiliate_network",
      vendorName: "Verified Marketplace Partner",
      ctaLabel: "View Partner Offer",
      isShortLink: true,
    };
  }

  if (
    hostMatches(host, [
      "pxf.io",
      "sjv.io",
      "7eer.net",
      "evyy.net",
      "ojrq.net",
      "dpbolvw.net",
      "anrdoezrs.net",
      "jdoqocy.com",
      "tkqlhce.com",
      "kqzyfj.com",
      "shareasale.com",
      "shrsl.com",
      "awin1.com",
      "click.linksynergy.com",
      "go.redirectingat.com",
      "redirect.viglink.com",
      "partnerstack.com",
      "psxid.com",
      "flexoffers.com",
      "avantlink.com",
    ])
  ) {
    return {
      platformId: "impact_cj_shareasale_skimlinks",
      platformName: "Affiliate Network",
      sourceType: "affiliate_network",
      vendorName: "Authorized Partner",
      ctaLabel: "View Partner Offer",
      isShortLink: true,
    };
  }

  const proRetailMap = [
    {domains: ["vevor.com", "vevor.ca"], id: "vevor_affiliate", name: "VEVOR"},
    {domains: ["homedepot.com", "homedepot.ca", "thd.co"], id: "home_depot_pro", name: "Home Depot"},
    {domains: ["lowes.com", "lowes.ca"], id: "bakers_gas_welding", name: "Lowe's"},
    {domains: ["tractorsupply.com"], id: "tractor_supply_ranch", name: "Tractor Supply"},
    {domains: ["northerntool.com"], id: "tractor_supply_ranch", name: "Northern Tool"},
    {domains: ["acmetools.com"], id: "acme_tools_zoro", name: "Acme Tools"},
    {domains: ["zoro.com"], id: "acme_tools_zoro", name: "Zoro"},
    {domains: ["grainger.com"], id: "acme_tools_zoro", name: "Grainger"},
    {domains: ["bakersgas.com"], id: "bakers_gas_welding", name: "Baker's Gas"},
    {domains: ["etrailer.com"], id: "bakers_gas_welding", name: "etrailer"},
    {domains: ["bootbarn.com"], id: "bakers_gas_welding", name: "Boot Barn"},
    {domains: ["harborfreight.com"], id: "acme_tools_zoro", name: "Harbor Freight"},
    {domains: ["princessauto.com"], id: "tractor_supply_ranch", name: "Princess Auto"},
    {domains: ["canadiantire.ca"], id: "home_depot_pro", name: "Canadian Tire"},
  ];
  for (const entry of proRetailMap) {
    if (hostMatches(host, entry.domains)) {
      return {
        platformId: entry.id,
        platformName: entry.name,
        sourceType: "hardware_pro_retail",
        vendorName: entry.name,
        ctaLabel: `View at ${entry.name}`,
        isShortLink: host === "thd.co",
      };
    }
  }

  return {
    platformId: "brand_partner",
    platformName: "Brand Partner",
    sourceType: "brand_partner",
    vendorName: "",
    ctaLabel: "",
    isShortLink: false,
  };
}

function extractAmazonAsin(value) {
  const raw = cleanText(value, 2000);
  if (!raw) return "";
  if (/^[A-Z0-9]{10}$/i.test(raw)) {
    return raw.toUpperCase();
  }
  const patterns = [
    /\/dp\/([A-Z0-9]{10})(?:[/?#]|$)/i,
    /\/gp\/product\/([A-Z0-9]{10})(?:[/?#]|$)/i,
    /\/gp\/aw\/d\/([A-Z0-9]{10})(?:[/?#]|$)/i,
    /\/exec\/obidos\/ASIN\/([A-Z0-9]{10})(?:[/?#]|$)/i,
    /\/product\/([A-Z0-9]{10})(?:[/?#]|$)/i,
  ];
  for (const pattern of patterns) {
    const match = raw.match(pattern);
    if (match && match[1]) {
      return match[1].toUpperCase();
    }
  }
  return "";
}

function resolveAmazonHostForRegion(regionCode) {
  const normalized = cleanText(regionCode, 8).toUpperCase();
  if (normalized === "CA") return "www.amazon.ca";
  if (normalized === "UK" || normalized === "GB") return "www.amazon.co.uk";
  if (normalized === "AU") return "www.amazon.com.au";
  if (normalized === "SG") return "www.amazon.sg";
  return "www.amazon.com";
}

function resolveAmazonAssociateTag(hostname, settings = DEFAULT_STORE_SETTINGS) {
  const host = String(hostname || "").toLowerCase();
  const merged = {...DEFAULT_STORE_SETTINGS, ...(settings || {})};
  if (host === "amazon.ca" || host.endsWith(".amazon.ca")) {
    return cleanText(merged.amazonAssociateTagCa || merged.amazonAssociateTagUs, 64);
  }
  if (host === "amazon.co.uk" || host.endsWith(".amazon.co.uk")) {
    return cleanText(merged.amazonAssociateTagUk || merged.amazonAssociateTagUs, 64);
  }
  if (host === "amazon.com.au" || host.endsWith(".amazon.com.au")) {
    return cleanText(merged.amazonAssociateTagAu || merged.amazonAssociateTagUs, 64);
  }
  if (host === "amazon.sg" || host.endsWith(".amazon.sg")) {
    return cleanText(merged.amazonAssociateTagSg || merged.amazonAssociateTagUs, 64);
  }
  return cleanText(merged.amazonAssociateTagUs, 64);
}

function buildMonetizedDestinationUrl(product, settings = DEFAULT_STORE_SETTINGS, options = {}) {
  const mergedSettings = {...DEFAULT_STORE_SETTINGS, ...(settings || {})};
  const regionCode = cleanText(options.regionCode, 8).toUpperCase();
  const sourceType = cleanText(product && product.sourceType, 40) || "amazon_affiliate";
  const asin = extractAmazonAsin(product && (product.asin || product.destinationUrl));
  const rawDestination = cleanText(product && product.destinationUrl, 2000);
  const rawCaDestination = cleanText(product && product.destinationUrlCa, 2000);

  let effectiveRawUrl = rawDestination;
  if (regionCode === "CA" && rawCaDestination) {
    effectiveRawUrl = rawCaDestination;
  } else if (!effectiveRawUrl && asin) {
    const effectiveRegion =
      regionCode === "CA" && !cleanText(mergedSettings.amazonAssociateTagCa, 64) ?
        "US" :
        regionCode;
    effectiveRawUrl = `https://${resolveAmazonHostForRegion(effectiveRegion)}/dp/${asin}`;
  }

  const parsed = parseSafeHttpsUrl(effectiveRawUrl, "Product destination URL");
  const detected = detectAffiliatePlatform(parsed.hostname);

  if (isAmazonShortHostname(parsed.hostname)) {
    return parsed.toString();
  }

  if (sourceType === "amazon_affiliate" || isAmazonFullHostname(parsed.hostname)) {
    if (
      regionCode === "CA" &&
      !rawCaDestination &&
      parsed.hostname.endsWith("amazon.com") &&
      cleanText(mergedSettings.amazonAssociateTagCa, 64)
    ) {
      parsed.hostname = "www.amazon.ca";
    }
    const associateTag = resolveAmazonAssociateTag(parsed.hostname, mergedSettings);
    const existingTag = cleanText(parsed.searchParams.get("tag"), 64);
    if (associateTag && (!existingTag || mergedSettings.forceOverrideAmazonTag === true)) {
      parsed.searchParams.set("tag", associateTag);
    }
    return parsed.toString();
  }

  // Involve Asia unified shortlinks allow optional ?subid= attribution
  if (detected.platformId === "involve_asia") {
    const subId = cleanText(mergedSettings.involveAsiaSubId, 64);
    if (subId && !parsed.searchParams.has("subid") && !parsed.searchParams.has("aff_sub")) {
      parsed.searchParams.set("subid", subId);
    }
    return parsed.toString();
  }

  // Preserve pre-generated affiliate shortlinks untouched so redirect signatures never break
  if (detected.isShortLink) {
    return parsed.toString();
  }

  const campaign = cleanText(product && product.categoryCode, 64) || "pipebuyer_shop";

  // AliExpress full product URLs
  if (detected.platformId === "aliexpress_portals" || sourceType === "aliexpress_affiliate") {
    const aliKey = cleanText(mergedSettings.aliexpressTrackingId, 64);
    if (aliKey && !parsed.searchParams.has("aff_fcid") && !parsed.searchParams.has("sk")) {
      parsed.searchParams.set("aff_platform", "portals-tool");
      parsed.searchParams.set("sk", aliKey);
    }
    if (!parsed.searchParams.has("af")) {
      parsed.searchParams.set("af", campaign.replace(/[^a-zA-Z0-9_-]/g, "").slice(0, 32));
    }
    return parsed.toString();
  }

  // Shopee full product URLs (sub_id must be strictly alphanumeric)
  if (detected.platformId === "shopee_affiliate" || sourceType === "shopee_affiliate") {
    const rawSubId = cleanText(mergedSettings.shopeeAffiliateSubId, 64)
        .replace(/[^a-zA-Z0-9]/g, "");
    if (rawSubId && !parsed.searchParams.has("sub_id")) {
      parsed.searchParams.set("sub_id", rawSubId);
    }
    if (!parsed.searchParams.has("utm_source")) {
      parsed.searchParams.set("utm_source", cleanText(mergedSettings.defaultUtmSource, 64) || "pipebuyer");
    }
    return parsed.toString();
  }

  // Lazada full product URLs
  if (detected.platformId === "lazada_lazaffiliate" || sourceType === "lazada_affiliate") {
    const lazSub = cleanText(mergedSettings.lazadaAffiliateSubId, 64);
    if (lazSub && !parsed.searchParams.has("aff_sub") && !parsed.searchParams.has("sub_id")) {
      parsed.searchParams.set("aff_sub", lazSub);
    }
    if (!parsed.searchParams.has("utm_source")) {
      parsed.searchParams.set("utm_source", cleanText(mergedSettings.defaultUtmSource, 64) || "pipebuyer");
    }
    return parsed.toString();
  }

  // eBay Partner Network full URLs
  if (detected.platformId === "ebay_partner_network" || sourceType === "ebay_partner") {
    const campId = cleanText(mergedSettings.ebayCampaignId, 32);
    if (campId && !parsed.searchParams.has("campid")) {
      const host = parsed.hostname.toLowerCase();
      const mkrid = host.endsWith("ebay.ca") ?
        "706-53473-19255-0" :
        host.endsWith("ebay.co.uk") ?
          "710-53481-19255-0" :
          host.endsWith("ebay.com.au") ?
            "705-53470-19255-0" :
            "711-53200-19255-0";
      parsed.searchParams.set("mkcid", "1");
      parsed.searchParams.set("mkrid", mkrid);
      parsed.searchParams.set("campid", campId);
      parsed.searchParams.set("toolid", "10001");
      parsed.searchParams.set("customid", campaign);
    }
    return parsed.toString();
  }

  // Brand partner, pro retail, Walmart, Temu, Alibaba, distributor, or verified vendor storefront
  const utmSource = cleanText(mergedSettings.defaultUtmSource, 64) || "pipebuyer";
  const utmMedium = cleanText(mergedSettings.defaultUtmMedium, 64) || "affiliate_store";
  if (!parsed.searchParams.has("utm_source")) {
    parsed.searchParams.set("utm_source", utmSource);
  }
  if (!parsed.searchParams.has("utm_medium")) {
    parsed.searchParams.set("utm_medium", utmMedium);
  }
  if (!parsed.searchParams.has("utm_campaign")) {
    parsed.searchParams.set("utm_campaign", campaign);
  }
  return parsed.toString();
}

function decodeHtmlEntities(value) {
  return String(value || "")
      .replace(/&amp;/gi, "&")
      .replace(/&quot;/gi, "\"")
      .replace(/&#39;|&apos;/gi, "'")
      .replace(/&lt;/gi, "<")
      .replace(/&gt;/gi, ">");
}

function inferBrandFromText(rawText) {
  const haystack = String(rawText || "").toLowerCase();
  if (!haystack) return "";
  for (const candidate of KNOWN_INDUSTRIAL_BRANDS) {
    const escaped = candidate.toLowerCase().replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    if (new RegExp(`(?:^|[^a-z0-9])${escaped}(?:$|[^a-z0-9])`, "i").test(haystack)) {
      return candidate === "DEWALT" ? "DeWalt" : candidate;
    }
  }
  return "";
}

function inferCategoryCodeFromText(rawText) {
  const text = String(rawText || "").toLowerCase();
  if (!text) return "power_hand_tools";
  if (/\b(chain|binder|shackle|sling|rigging|winch|cargo|strap|tie[- ]down|clevis|tow)\b/.test(text)) {
    return "rigging_hauling_cargo";
  }
  if (/\b(weld|welding|welder|tig|mig|stick|pipe wrench|straight wrench|ridgid|chain vise|tristand|bevel|flange|threader|threading|torch)\b/.test(text)) {
    return "pipe_welding_fab";
  }
  if (/\b(fr\b|flame[- ]resistant|hardhat|hard hat|h2s|gas monitor|gas detector|gloves?|boots?|respirators?|ppe|eyewear|safety|harness|fall protection|spill)\b/.test(text)) {
    return "ppe_fr_safety";
  }
  if (/\b(grease gun|transfer pump|diesel|fuel|hydraulic|hose|jump starter|oil filter|lubricat)\b/.test(text)) {
    return "hydraulics_fleet_shop";
  }
  if (/\b(work light|floodlight|lantern|headlamp|generator|inverter|extension cord|radio|jobsite box|gang box|site[- ]vault)\b/.test(text)) {
    return "lighting_power_jobsite";
  }
  if (/\b(ultrasonic|thickness gauge|caliper|micrometer|laser level|thermal|multimeter|clamp meter|pressure test|thread gauge)\b/.test(text)) {
    return "measuring_inspection";
  }
  if (/\b(fence|fencing|post driver|ranch|livestock|gate latch|hinge|t-post|cattle)\b/.test(text)) {
    return "ranch_fencing_ag";
  }
  return "power_hand_tools";
}

function inferSubcategoryFromText(rawText, categoryCode = "") {
  const text = String(rawText || "").toLowerCase();
  const effectiveCategory = SHOP_CATEGORY_BY_CODE.has(categoryCode) ?
    categoryCode :
    inferCategoryCodeFromText(text);
  const category = SHOP_CATEGORY_BY_CODE.get(effectiveCategory);
  if (!category || !Array.isArray(category.subcategories) || category.subcategories.length === 0) {
    return "";
  }
  if (!text) return category.subcategories[0];

  switch (effectiveCategory) {
    case "pipe_welding_fab":
      if (/\b(bevel|cutter|cutting|threader|threading|die head|reamer)\b/.test(text)) {
        return "Pipe Cutting, Threading & Beveling";
      }
      if (/\b(flange|two[- ]hole|alignment|jack stand|pipe stand|fit[- ]up|center punch)\b/.test(text)) {
        return "Pipe Alignment, Jacks & Fit-Up Tools";
      }
      if (/\b(weld.*helmet|viking|auto[- ]darkening|welder|tig|mig|stick|electrode|ground clamp|torch)\b/.test(text)) {
        return "Welding Machines, Leads & Torches";
      }
      if (/\b(rod|7018|6010|flux|mig wire|flap disc|grinding wheel|wire wheel|abrasive)\b/.test(text)) {
        return "Welding Rods, Wire & Abrasives";
      }
      if (/\b(valve|gasket|ptfe|sealant|dope|fitting|nipple|union)\b/.test(text)) {
        return "Valves, Pipe Fittings, Flanges & Sealants";
      }
      return "Pipe Wrenches, Chain Tongs & Vises";
    case "power_hand_tools":
      if (/\b(grinder|band\s*saw|bandsaw|mag\s*drill|cut[- ]off|chop saw|reciprocating|sawzall)\b/.test(text)) {
        return "Angle Grinders, Bandsaws & Mag Drills";
      }
      if (/\b(torque wrench|breaker bar|ratchet|combination wrench|adjustable wrench)\b/.test(text)) {
        return "Heavy Wrenches, Ratchets & Torque Tools";
      }
      if (/\b(plier|knipex|hammer|sledge|spud|pry bar|chisel|punch)\b/.test(text)) {
        return "Pliers, Hammers, Spuds & Pry Bars";
      }
      if (/\b(tap.*die|mechanic.*set|electrician|crimper|stripper|bit set)\b/.test(text)) {
        return "Mechanics, Electrician & Tap/Die Kits";
      }
      if (/\b(battery|charger|packout|redlithium|flexvolt)\b/.test(text)) {
        return "Cordless Batteries, Chargers & Packout";
      }
      return "Cordless Impact Wrenches & Socket Sets";
    case "rigging_hauling_cargo":
      if (/\b(shackle|crosby|clevis hook|eye hook|swivel|turnbuckle|thimble|wire rope clip)\b/.test(text)) {
        return "Shackles, Hooks, Swivels & Hardware";
      }
      if (/\b(sling|round sling|web sling|choker|lifting strap)\b/.test(text)) {
        return "Web Slings, Round Slings & Wire Chokers";
      }
      if (/\b(hoist|come[- ]along|lever puller|chain block|plate clamp|beam clamp)\b/.test(text)) {
        return "Chain Hoists, Lever Pullers & Clamps";
      }
      if (/\b(winch strap|ratchet strap|tarp|bungee|corner protector|stake pocket)\b/.test(text)) {
        return "Flatbed Winch Straps, Tarps & Stakes";
      }
      if (/\b(oversize|wide load|beacon|strobe|safety flag|wheel chock)\b/.test(text)) {
        return "Oversize Load Banners, Beacons & Safety";
      }
      return "Grade 70/100 Chains & Load Binders";
    case "ppe_fr_safety":
      if (/\b(boot|steel toe|composite toe|metatarsal|muck)\b/.test(text)) {
        return "Pipeline & Oilfield Safety Work Boots";
      }
      if (/\b(hard\s*hat|safety glass|goggle|face shield)\b/.test(text)) {
        return "Hard Hats, Welding Shields & Safety Glasses";
      }
      if (/\b(glove|rig lizard|cut[- ]resistant)\b/.test(text)) {
        return "ANSI Impact, Rigging & Cut Gloves";
      }
      if (/\b(h2s|gas monitor|gas detector|clip4|multi[- ]gas|respirator|half[- ]mask)\b/.test(text)) {
        return "H2S / 4-Gas Monitors & Respiratory";
      }
      if (/\b(harness|lanyard|srl|fall protection|spill kit|absorbent|first aid|eyewash)\b/.test(text)) {
        return "Fall Protection, Spill Kits & First Aid";
      }
      return "FR Shirts, Coveralls & Winter Outerwear";
    case "hydraulics_fleet_shop":
      if (/\b(grease gun|grease coupler|zerk|hose reel|lubricat|oil drain)\b/.test(text)) {
        return "Grease Guns, Hose Reels & Lubrication";
      }
      if (/\b(bottle jack|hydraulic ram|porta[- ]power|enerpac|hydraulic coupler)\b/.test(text)) {
        return "Hydraulic Jacks, Rams, Pumps & Couplers";
      }
      if (/\b(air compressor|air hose|air impact|inflator|blow gun)\b/.test(text)) {
        return "Service Truck Compressors & Air Tools";
      }
      if (/\b(jump starter|jump pack|noco|battery charger|obd|scanner)\b/.test(text)) {
        return "12V/24V Jump Packs, Chargers & HD Scanners";
      }
      if (/\b(tire|mud flap|shop towel|degreaser|brake cleaner)\b/.test(text)) {
        return "Tire Service, Mud Flaps & Shop Consumables";
      }
      return "Diesel Transfer Pumps, Meters & Filters";
    case "lighting_power_jobsite":
      if (/\b(headlamp|flashlight|intrinsically safe|penlight)\b/.test(text)) {
        return "Intrinsically Safe Flashlights & Headlamps";
      }
      if (/\b(generator|inverter|power station|spider box)\b/.test(text)) {
        return "Generators, Power Stations & Spider Boxes";
      }
      if (/\b(extension cord|soow|sjoow|welding adapter)\b/.test(text)) {
        return "Heavy Cold-Weather Cords & Welding Adapters";
      }
      if (/\b(jobox|gang box|site[- ]vault|truck chest|weather guard|pelican|tool chest)\b/.test(text)) {
        return "Jobsite Gang Boxes, Truck Chests & Cases";
      }
      if (/\b(two[- ]way radio|walkie|cooler|heater|fan)\b/.test(text)) {
        return "Two-Way Radios, Coolers & Jobsite Heaters";
      }
      return "Cordless Tower, Magnetic & Flood Lights";
    case "measuring_inspection":
      if (/\b(pressure gauge|hydrotest|deadweight|test manifold)\b/.test(text)) {
        return "Liquid-Filled Pressure Gauges & Hydrotest";
      }
      if (/\b(caliper|mitutoyo|micrometer|tally|pi tape|thread gauge|feeler)\b/.test(text)) {
        return "Pipe Calipers, Tally Tapes & Thread Gauges";
      }
      if (/\b(borescope|endoscope|sewer camera|inspection camera|pipe locator)\b/.test(text)) {
        return "Borescopes, Sewer Cameras & Pipe Locators";
      }
      if (/\b(thermal|flir|infrared|pyrometer|temp gun|leak detector)\b/.test(text)) {
        return "Thermal Imagers, Pyrometers & Leak Detectors";
      }
      if (/\b(laser level|rotary laser|digital level|torpedo level|multimeter|fluke|clamp meter)\b/.test(text)) {
        return "Rotary Lasers, Digital Levels & Multimeters";
      }
      return "Ultrasonic Wall Thickness & NDT Kits";
    case "ranch_fencing_ag":
      if (/\b(notcher|coping|pipe saddle|template)\b/.test(text)) {
        return "Pipe Fence Coping, Saddles & Notchers";
      }
      if (/\b(hinge|barrel hinge|gate latch|bulldog|cane bolt|gate wheel)\b/.test(text)) {
        return "Weld-On Hinges, Latches & Gate Hardware";
      }
      if (/\b(solar.*fence|energizer|barbed wire|wire strainer|wire stretcher)\b/.test(text)) {
        return "Solar Fence Chargers, Wire & Strainers";
      }
      if (/\b(stock tank|float valve|waterer|trough|trash pump)\b/.test(text)) {
        return "Stock Tank Valves, Waterers & Ag Pumps";
      }
      if (/\b(chute|headgate|cattle|ear tag|livestock)\b/.test(text)) {
        return "Livestock Chute, Trailer & Ranch Hardware";
      }
      return "Gas Post Drivers, Augers & T-Post Tools";
    default:
      return category.subcategories[0];
  }
}

function extractTitleFromAmazonSlug(urlObject) {
  if (!urlObject || !urlObject.pathname) return "";
  const match = urlObject.pathname.match(/^\/([^/]+)\/(?:dp|gp\/product)\/[A-Z0-9]{10}/i);
  if (!match || !match[1]) return "";
  const rawSlug = decodeURIComponent(match[1]);
  if (!rawSlug || rawSlug.toLowerCase() === "gp" || rawSlug.toLowerCase() === "dp") return "";
  return cleanText(
      rawSlug
          .replace(/[-_]+/g, " ")
          .replace(/\s+/g, " "),
      160,
  );
}

function extractTitleFromGenericSlug(urlObject) {
  if (!urlObject || !urlObject.pathname) return "";
  const segments = urlObject.pathname
      .split("/")
      .map((s) => {
        try {
          return decodeURIComponent(s);
        } catch {
          return s;
        }
      })
      .filter(Boolean);
  for (const seg of segments) {
    const cleaned = seg
        .replace(/\.html?$/i, "")
        .replace(/-i\.\d+\.\d+$/i, "")
        .replace(/-s\d+\.html?$/i, "");
    if (/^(?:dp|gp|product|products|item|itm|ip|p|e|s|d|c)$/i.test(cleaned)) continue;
    if (/^\d{6,}$/.test(cleaned)) continue;
    if (cleaned.includes("-") && /[a-z]{3,}/i.test(cleaned) && cleaned.length >= 8) {
      return cleanText(cleaned.replace(/[-_]+/g, " ").replace(/\s+/g, " "), 160);
    }
  }
  return "";
}

function parseAmazonAffiliateSubmission(rawInput, settings = DEFAULT_STORE_SETTINGS) {
  const mergedSettings = {...DEFAULT_STORE_SETTINGS, ...(settings || {})};
  const decoded = decodeHtmlEntities(String(rawInput || "")).trim();
  if (!decoded) {
    throw new HttpsError(
        "invalid-argument",
        "Paste an affiliate link (Amazon, AliExpress, Lazada, Shopee, Involve Asia, eBay, VEVOR, etc.), HTML snippet, or 10-character ASIN.",
    );
  }

  // Case 1: Bare 10-character Amazon ASIN
  if (/^[A-Z0-9]{10}$/i.test(decoded)) {
    const asin = decoded.toUpperCase();
    const baseUrl = `https://www.amazon.com/dp/${asin}`;
    const monetizedUs = buildMonetizedDestinationUrl(
        {sourceType: "amazon_affiliate", asin, destinationUrl: baseUrl},
        mergedSettings,
        {regionCode: "US"},
    );
    const monetizedCa = buildMonetizedDestinationUrl(
        {sourceType: "amazon_affiliate", asin, destinationUrl: baseUrl},
        mergedSettings,
        {regionCode: "CA"},
    );
    return {
      destinationUrl: baseUrl,
      asin,
      sourceType: "amazon_affiliate",
      platformId: "amazon_associates",
      platformName: "Amazon",
      suggestedVendorName: "Amazon",
      suggestedCtaLabel: "View on Amazon",
      suggestedTitle: "",
      suggestedBrand: "",
      suggestedCategoryCode: "power_hand_tools",
      suggestedSubcategory: "Cordless Impact Wrenches & Socket Sets",
      suggestedHighlights: [],
      imageUrl: "",
      eligibleCountries: ["US", "CA"],
      isAmazonLink: true,
      isShortLink: false,
      isSearchPageLink: false,
      embeddedAssociateTag: "",
      effectiveAssociateTag: mergedSettings.amazonAssociateTagUs || "",
      monetizedPreviewUs: monetizedUs,
      monetizedPreviewCa: monetizedCa,
      complianceWarnings: mergedSettings.amazonAssociateTagUs ?
        [] :
        ["Configure your US Amazon Associate Tag in Store Settings so ASIN links earn commissions."],
    };
  }

  let extractedHref = "";
  let extractedImg = "";
  let anchorTitle = "";

  // Case 2: Affiliate HTML snippet (<a href="...">...</a> / <img src="...">)
  const hrefMatch = decoded.match(/href\s*=\s*["']([^"']+)["']/i);
  if (hrefMatch && hrefMatch[1]) {
    extractedHref = hrefMatch[1].trim();
  }
  const imgMatch = decoded.match(/<img[^>]*\ssrc\s*=\s*["']([^"']+)["']/i);
  if (imgMatch && imgMatch[1]) {
    const candidateImg = imgMatch[1].trim();
    const normalizedImg = candidateImg.startsWith("//") ? `https:${candidateImg}` : candidateImg;
    try {
      const parsedImg = parseSafeHttpsUrl(normalizedImg, "Image URL");
      // Ignore 1x1 tracking pixels from legacy Associates HTML snippets
      if (!/ir-na\.amazon-adsystem\.com|assoc-amazon\.com/i.test(parsedImg.hostname)) {
        extractedImg = parsedImg.toString();
      }
    } catch {
      extractedImg = "";
    }
  }
  const anchorTextMatch = decoded.match(/<a[^>]*>([\s\S]*?)<\/a>/i);
  if (anchorTextMatch && anchorTextMatch[1]) {
    anchorTitle = cleanText(anchorTextMatch[1].replace(/<[^>]+>/g, " "), 160);
  }

  // Case 3: Mobile App Share text ("Check out this on Shopee/AliExpress/Lazada/Amazon ... https://...") or direct URL
  let surroundingText = "";
  if (!extractedHref) {
    const urlMatch = decoded.match(/https?:\/\/[^\s"'<>]+/i);
    if (urlMatch && urlMatch[0]) {
      extractedHref = urlMatch[0].replace(/[),.;!?]+$/, "");
      surroundingText = cleanText(
          decoded
              .replace(urlMatch[0], " ")
              .replace(
                  /^(check (?:this )?out(?: on (?:amazon|shopee|lazada|aliexpress|ebay|temu|tiktok))?|just found this amazing item on aliexpress|share from (?:lazada|shopee)|deal(?: of the day)?|amazon(?:\.com|\.ca)?)[\s:!,|-]*/i,
                  "",
              ),
          160,
      );
    } else {
      extractedHref = decoded;
    }
  }

  if (
    /^http:\/\/(?:www\.)?(?:amazon\.|amzn\.to|a\.co|link\.amazon|amzlinks\.in|s\.click\.aliexpress\.com|a\.aliexpress\.com|aliexpress\.|shopee\.|shope\.ee|s\.shopee\.|lazada\.|s\.lazada\.|c\.lazada\.|invol\.co|invl\.io|ebay\.)/i.test(
        extractedHref,
    )
  ) {
    extractedHref = extractedHref.replace(/^http:\/\//i, "https://");
  } else if (
    /^(?:www\.)?(?:amazon\.com|amazon\.ca|amzn\.to|a\.co|link\.amazon|amzlinks\.in|s\.click\.aliexpress\.com|aliexpress\.com|shope\.ee|shopee\.[a-z.]+|lazada\.[a-z.]+|invol\.co|ebay\.com)\//i.test(
        extractedHref,
    )
  ) {
    extractedHref = `https://${extractedHref}`;
  }

  const parsedUrl = parseSafeHttpsUrl(extractedHref, "Affiliate link");
  const detected = detectAffiliatePlatform(parsedUrl.hostname);
  const isShort = detected.isShortLink;
  const isFullAmazon = isAmazonFullHostname(parsedUrl.hostname);
  const isAmazon = isAmazonShortHostname(parsedUrl.hostname) || isFullAmazon;
  const sourceType = detected.sourceType;
  const asin = isAmazon ? extractAmazonAsin(parsedUrl.toString()) : "";
  const slugTitle = isFullAmazon ?
    extractTitleFromAmazonSlug(parsedUrl) :
    extractTitleFromGenericSlug(parsedUrl);
  const suggestedTitle = anchorTitle || surroundingText || slugTitle;
  const combinedHint = [suggestedTitle, slugTitle, parsedUrl.pathname].filter(Boolean).join(" ");
  const suggestedBrand = inferBrandFromText(combinedHint);
  const suggestedCategoryCode = inferCategoryCodeFromText(combinedHint);
  const suggestedSubcategory = inferSubcategoryFromText(combinedHint, suggestedCategoryCode);
  const eligibleCountries = inferEligibleCountries(parsedUrl.hostname, sourceType, asin);
  const isSearchPage = isAmazonSearchPageUrl(parsedUrl.toString());

  const embeddedTag = isAmazon ?
    cleanText(parsedUrl.searchParams.get("tag"), 64) :
    cleanText(
        parsedUrl.searchParams.get("aff_fcid") ||
        parsedUrl.searchParams.get("sk") ||
        parsedUrl.searchParams.get("sub_id") ||
        parsedUrl.searchParams.get("aff_sub") ||
        parsedUrl.searchParams.get("subid") ||
        parsedUrl.searchParams.get("campid"),
        64,
    );
  const storeTag = isAmazon ? resolveAmazonAssociateTag(parsedUrl.hostname, mergedSettings) : "";
  let effectiveTag = "";
  if (isAmazonShortHostname(parsedUrl.hostname)) {
    effectiveTag = "Embedded in Amazon Short Link";
  } else if (isAmazon) {
    effectiveTag = (embeddedTag && !mergedSettings.forceOverrideAmazonTag) ? embeddedTag : storeTag;
  } else if (isShort) {
    effectiveTag = `Embedded in ${detected.platformName} Short Link`;
  } else {
    effectiveTag = embeddedTag || `${detected.platformName} Attribution`;
  }

  const draftProduct = {
    sourceType,
    asin,
    categoryCode: suggestedCategoryCode,
    destinationUrl: parsedUrl.toString(),
  };
  const monetizedPreviewUs = buildMonetizedDestinationUrl(draftProduct, mergedSettings, {regionCode: "US"});
  const monetizedPreviewCa = buildMonetizedDestinationUrl(draftProduct, mergedSettings, {regionCode: "CA"});

  const warnings = [];
  if (isFullAmazon && !embeddedTag && !storeTag) {
    warnings.push("No Amazon Associate tag is set yet. Enter your Tracking ID in Store Settings.");
  }
  if (isSearchPage) {
    warnings.push(
        "This link opens an Amazon search results page instead of a direct product page. Select a matched SKU below to auto-fill its photo and direct Buy link.",
    );
  }

  return {
    destinationUrl: parsedUrl.toString(),
    asin,
    sourceType,
    platformId: detected.platformId,
    platformName: detected.platformName,
    suggestedVendorName: detected.vendorName || suggestedBrand || "Partner Store",
    suggestedCtaLabel: detected.ctaLabel || (detected.vendorName ? `View on ${detected.vendorName}` : "View Offer"),
    suggestedTitle,
    suggestedBrand,
    suggestedCategoryCode,
    suggestedSubcategory,
    suggestedHighlights: [],
    imageUrl: extractedImg,
    eligibleCountries,
    isAmazonLink: isAmazon,
    isShortLink: isShort,
    isSearchPageLink: isSearchPage,
    embeddedAssociateTag: embeddedTag,
    effectiveAssociateTag: effectiveTag,
    monetizedPreviewUs,
    monetizedPreviewCa,
    complianceWarnings: warnings,
  };
}

const parseAffiliateSubmission = parseAmazonAffiliateSubmission;

function normalizeHiddenStarterIds(value) {
  if (!Array.isArray(value)) return [];
  const seen = new Set();
  const output = [];
  for (const raw of value) {
    const id = cleanText(raw, 80)
        .toLowerCase()
        .replace(/[^a-z0-9_-]+/g, "-")
        .replace(/^-+|-+$/g, "");
    if (!id || seen.has(id)) continue;
    seen.add(id);
    output.push(id);
    if (output.length >= 500) break;
  }
  return output;
}

function normalizeAdminNotificationEmails(value) {
  const rawList = Array.isArray(value) ?
    value :
    typeof value === "string" ?
      value.split(/[,;\n]+/) :
      [];
  const seen = new Set();
  const output = [];
  for (const item of rawList) {
    const email = cleanText(item, 254).toLowerCase();
    if (!email) continue;
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
      throw new HttpsError(
          "invalid-argument",
          `Admin notification email "${email}" is not a valid email address.`,
      );
    }
    if (seen.has(email)) continue;
    seen.add(email);
    output.push(email);
    if (output.length >= 10) break;
  }
  return output;
}

function normalizeStoreSettings(input = {}, existing = {}) {
  const base = {...DEFAULT_STORE_SETTINGS, ...(existing || {})};
  const next = {
    storeEnabled:
      typeof input.storeEnabled === "boolean" ? input.storeEnabled : Boolean(base.storeEnabled),
    vendorApplicationsOpen:
      typeof input.vendorApplicationsOpen === "boolean" ?
        input.vendorApplicationsOpen :
        Boolean(base.vendorApplicationsOpen),
    amazonAssociateTagUs:
      input.amazonAssociateTagUs !== undefined ?
        normalizeAssociateTag(input.amazonAssociateTagUs) :
        normalizeAssociateTag(base.amazonAssociateTagUs),
    amazonAssociateTagCa:
      input.amazonAssociateTagCa !== undefined ?
        normalizeAssociateTag(input.amazonAssociateTagCa) :
        normalizeAssociateTag(base.amazonAssociateTagCa),
    amazonAssociateTagUk:
      input.amazonAssociateTagUk !== undefined ?
        normalizeAssociateTag(input.amazonAssociateTagUk) :
        normalizeAssociateTag(base.amazonAssociateTagUk),
    amazonAssociateTagAu:
      input.amazonAssociateTagAu !== undefined ?
        normalizeAssociateTag(input.amazonAssociateTagAu) :
        normalizeAssociateTag(base.amazonAssociateTagAu),
    amazonAssociateTagSg:
      input.amazonAssociateTagSg !== undefined ?
        normalizeAssociateTag(input.amazonAssociateTagSg) :
        normalizeAssociateTag(base.amazonAssociateTagSg),
    aliexpressTrackingId:
      input.aliexpressTrackingId !== undefined ?
        normalizeAssociateTag(input.aliexpressTrackingId) :
        normalizeAssociateTag(base.aliexpressTrackingId),
    shopeeAffiliateSubId:
      input.shopeeAffiliateSubId !== undefined ?
        normalizeAssociateTag(input.shopeeAffiliateSubId) :
        normalizeAssociateTag(base.shopeeAffiliateSubId),
    lazadaAffiliateSubId:
      input.lazadaAffiliateSubId !== undefined ?
        normalizeAssociateTag(input.lazadaAffiliateSubId) :
        normalizeAssociateTag(base.lazadaAffiliateSubId),
    involveAsiaSubId:
      input.involveAsiaSubId !== undefined ?
        normalizeAssociateTag(input.involveAsiaSubId) :
        normalizeAssociateTag(base.involveAsiaSubId),
    ebayCampaignId:
      input.ebayCampaignId !== undefined ?
        normalizeAssociateTag(input.ebayCampaignId) :
        normalizeAssociateTag(base.ebayCampaignId),
    skimlinksPublisherId:
      input.skimlinksPublisherId !== undefined ?
        normalizeAssociateTag(input.skimlinksPublisherId) :
        normalizeAssociateTag(base.skimlinksPublisherId),
    forceOverrideAmazonTag:
      typeof input.forceOverrideAmazonTag === "boolean" ?
        input.forceOverrideAmazonTag :
        Boolean(base.forceOverrideAmazonTag),
    defaultUtmSource:
      cleanText(input.defaultUtmSource ?? base.defaultUtmSource, 64) || "pipebuyer",
    defaultUtmMedium:
      cleanText(input.defaultUtmMedium ?? base.defaultUtmMedium, 64) || "affiliate_store",
    disclosureText:
      cleanText(input.disclosureText ?? base.disclosureText, 400) ||
      DEFAULT_STORE_SETTINGS.disclosureText,
    priceDisclaimerText:
      cleanText(input.priceDisclaimerText ?? base.priceDisclaimerText, 400) ||
      DEFAULT_STORE_SETTINGS.priceDisclaimerText,
    hiddenStarterIds:
      input.hiddenStarterIds !== undefined ?
        normalizeHiddenStarterIds(input.hiddenStarterIds) :
        normalizeHiddenStarterIds(base.hiddenStarterIds),
    adminNotificationEmails:
      input.adminNotificationEmails !== undefined ?
        normalizeAdminNotificationEmails(input.adminNotificationEmails) :
        normalizeAdminNotificationEmails(base.adminNotificationEmails),
  };
  return next;
}

function buildProductSearchTokens(product) {
  const combined = [
    product.title,
    product.brand,
    product.vendorName,
    product.categoryCode,
    product.subcategory,
    product.asin,
    product.sku,
    ...(Array.isArray(product.highlights) ? product.highlights : []),
    ...(Array.isArray(product.tags) ? product.tags : []),
    ...(Array.isArray(product.marketplaceCategories) ? product.marketplaceCategories : []),
  ]
      .filter(Boolean)
      .join(" ")
      .toLowerCase()
      .replace(/[^a-z0-9+#/-]+/g, " ");

  const seen = new Set();
  const tokens = [];
  for (const part of combined.split(/\s+/)) {
    if (part.length < 2) continue;
    if (seen.has(part)) continue;
    seen.add(part);
    tokens.push(part);
    if (tokens.length >= 60) break;
  }
  return tokens;
}

function validateShopProductInput(raw = {}, existing = null) {
  const base = existing || {};
  const rawSubmission = cleanText(raw.rawAffiliateInput ?? raw.destinationUrl ?? "", 3000);
  let parsedSubmission = null;
  if (rawSubmission && (
    Boolean(raw.rawAffiliateInput) ||
    /^https?:\/\//i.test(rawSubmission) ||
    /<a\s/i.test(rawSubmission) ||
    /&amp;/i.test(rawSubmission) ||
    /\shttps?:\/\//i.test(rawSubmission) ||
    /^[A-Z0-9]{10}$/i.test(rawSubmission)
  )) {
    try {
      parsedSubmission = parseAmazonAffiliateSubmission(rawSubmission);
    } catch {
      parsedSubmission = null;
    }
  }

  const title = cleanText(
      raw.title ?? (parsedSubmission && parsedSubmission.suggestedTitle) ?? base.title,
      160,
  );
  if (title.length < 3) {
    throw new HttpsError("invalid-argument", "Product title must be at least 3 characters.");
  }

  const categoryCode = cleanText(
      raw.categoryCode ??
      (parsedSubmission && parsedSubmission.suggestedCategoryCode) ??
      base.categoryCode,
      64,
  );
  if (!SHOP_CATEGORY_BY_CODE.has(categoryCode)) {
    throw new HttpsError("invalid-argument", "Select a valid Store category.");
  }
  const category = SHOP_CATEGORY_BY_CODE.get(categoryCode);

  const sourceType = cleanText(
      raw.sourceType ?? (parsedSubmission && parsedSubmission.sourceType) ?? base.sourceType,
      40,
  ) || "amazon_affiliate";
  if (!SHOP_SOURCE_TYPES.has(sourceType)) {
    throw new HttpsError("invalid-argument", "Select a valid partner source type.");
  }

  const status = cleanText(raw.status ?? base.status, 24) || "active";
  if (!SHOP_PRODUCT_STATUSES.has(status)) {
    throw new HttpsError("invalid-argument", "Select a valid product status.");
  }

  const explicitAsin = extractAmazonAsin(
      raw.asin ?? (parsedSubmission && parsedSubmission.asin) ?? base.asin,
  );
  const rawDestination = decodeHtmlEntities(
      cleanText(
          (parsedSubmission && parsedSubmission.destinationUrl) ||
          (raw.destinationUrl ?? base.destinationUrl),
          2000,
      ),
  );
  const inferredAsin = explicitAsin || extractAmazonAsin(rawDestination);

  let normalizedDestination = rawDestination;
  if (!normalizedDestination && sourceType === "amazon_affiliate" && inferredAsin) {
    normalizedDestination = `https://www.amazon.com/dp/${inferredAsin}`;
  }
  const parsedDestination = parseSafeHttpsUrl(normalizedDestination, "Product destination URL");
  normalizedDestination = parsedDestination.toString();

  const rawDestinationCa = decodeHtmlEntities(
      cleanText(raw.destinationUrlCa ?? base.destinationUrlCa, 2000),
  );
  const normalizedDestinationCa = rawDestinationCa ?
    parseSafeHttpsUrl(rawDestinationCa, "Canada destination URL").toString() :
    "";

  const rawImageUrl = decodeHtmlEntities(
      cleanText(
          raw.imageUrl ||
          (parsedSubmission && parsedSubmission.imageUrl) ||
          base.imageUrl,
          2000,
      ),
  );
  const normalizedImageUrl = rawImageUrl ?
    parseSafeHttpsUrl(rawImageUrl, "Product image URL").toString() :
    "";

  const detectedDestination = detectAffiliatePlatform(parsedDestination.hostname);
  const brand = cleanText(
      raw.brand || (parsedSubmission && parsedSubmission.suggestedBrand) || base.brand,
      80,
  ) || "Industrial Select";
  const vendorName = cleanText(
      raw.vendorName ?? base.vendorName,
      100,
  ) || (sourceType === "amazon_affiliate" ? "Amazon" : (detectedDestination.vendorName || brand));

  const priceDisplay = cleanText(raw.priceDisplay ?? base.priceDisplay, 48);
  const badgeText = cleanText(raw.badgeText ?? base.badgeText, 48);
  const ctaLabel = cleanText(raw.ctaLabel ?? base.ctaLabel, 48) ||
    (sourceType === "amazon_affiliate" ?
      "View on Amazon" :
      (detectedDestination.ctaLabel || `Shop ${vendorName}`));
  const description = cleanText(raw.description ?? base.description, 1200);
  const subcategory = cleanText(
      raw.subcategory ??
      (parsedSubmission && parsedSubmission.suggestedSubcategory) ??
      base.subcategory,
      80,
  ) || inferSubcategoryFromText(`${title} ${brand}`, categoryCode);
  const sku = cleanText(raw.sku ?? base.sku, 80);
  const vendorId = cleanText(raw.vendorId ?? base.vendorId, 80);
  const featured =
    typeof raw.featured === "boolean" ? raw.featured : Boolean(base.featured);
  const priorityRank = Math.max(
      0,
      Math.min(1000, Math.trunc(Number(raw.priorityRank ?? base.priorityRank ?? 100) || 100)),
  );

  const highlights = cleanStringList(raw.highlights ?? base.highlights, {
    maxItems: 8,
    maxItemLength: 100,
  });
  const tags = cleanStringList(raw.tags ?? base.tags, {
    maxItems: 16,
    maxItemLength: 48,
  });
  const marketplaceCategories = cleanStringList(
      raw.marketplaceCategories ?? base.marketplaceCategories ?? category.marketplaceCategories,
      {maxItems: 10, maxItemLength: 64},
  );
  const defaultCountries = (parsedSubmission && parsedSubmission.eligibleCountries) ||
    inferEligibleCountries(parsedDestination.hostname, sourceType, inferredAsin);
  const eligibleCountries = raw.eligibleCountries !== undefined ?
    normalizeEligibleCountries(raw.eligibleCountries, defaultCountries) :
    (Array.isArray(base.eligibleCountries) && base.eligibleCountries.length > 0 ?
      normalizeEligibleCountries(base.eligibleCountries, defaultCountries) :
      defaultCountries);

  const normalized = {
    title,
    brand,
    vendorName,
    vendorId: vendorId || null,
    sourceType,
    status,
    categoryCode,
    categoryLabel: category.label,
    subcategory,
    description,
    asin: inferredAsin,
    sku,
    destinationUrl: normalizedDestination,
    destinationUrlCa: normalizedDestinationCa,
    destinationHost: parsedDestination.hostname.toLowerCase(),
    imageUrl: normalizedImageUrl,
    fallbackIconAsset: cleanText(raw.fallbackIconAsset ?? base.fallbackIconAsset, 240) ||
      category.iconAsset,
    priceDisplay,
    badgeText,
    ctaLabel,
    featured,
    priorityRank,
    highlights,
    tags,
    eligibleCountries,
    marketplaceCategories: marketplaceCategories.length > 0 ?
      marketplaceCategories :
      category.marketplaceCategories,
  };
  normalized.searchTokens = buildProductSearchTokens(normalized);
  return normalized;
}

function buildPublicShopProduct(id, productData, settings = DEFAULT_STORE_SETTINGS) {
  if (!productData || productData.status !== "active") {
    return null;
  }
  const monetizedUrlUs = buildMonetizedDestinationUrl(productData, settings, {regionCode: "US"});
  const monetizedUrlCa = buildMonetizedDestinationUrl(productData, settings, {regionCode: "CA"});
  const fallbackCountries = inferEligibleCountries(
      productData.destinationHost || productData.destinationUrl,
      productData.sourceType,
      productData.asin,
  );
  return {
    id,
    title: productData.title,
    brand: productData.brand,
    vendorName: productData.vendorName,
    vendorId: productData.vendorId || null,
    sourceType: productData.sourceType,
    categoryCode: productData.categoryCode,
    categoryLabel: productData.categoryLabel,
    subcategory: productData.subcategory || "",
    description: productData.description || "",
    asin: productData.asin || "",
    destinationUrl: monetizedUrlUs,
    destinationUrlCa: monetizedUrlCa,
    destinationHost: productData.destinationHost || "",
    imageUrl: productData.imageUrl || "",
    fallbackIconAsset: productData.fallbackIconAsset || "",
    priceDisplay: productData.priceDisplay || "",
    badgeText: productData.badgeText || "",
    ctaLabel: productData.ctaLabel || "View Offer",
    featured: Boolean(productData.featured),
    priorityRank: Number(productData.priorityRank || 100),
    highlights: Array.isArray(productData.highlights) ? productData.highlights : [],
    tags: Array.isArray(productData.tags) ? productData.tags : [],
    eligibleCountries: normalizeEligibleCountries(productData.eligibleCountries, fallbackCountries),
    marketplaceCategories: Array.isArray(productData.marketplaceCategories) ?
      productData.marketplaceCategories :
      [],
    searchTokens: Array.isArray(productData.searchTokens) ? productData.searchTokens : [],
    clickCount: Number(productData.clickCount || 0),
    updatedAt: productData.updatedAt || null,
  };
}

function defaultAuthorizationForTrack(track) {
  switch (track) {
    case "brand_manufacturer":
      return "oem_direct";
    case "oem_heavy_equipment_dealer":
      return "authorized_dealer";
    case "industrial_distributor":
      return "national_distributor";
    default:
      return "reseller_affiliate";
  }
}

function validateVendorApplicationInput(raw = {}, submitterUid = null) {
  const resolvedUid = cleanText(submitterUid, 128) || null;
  const companyName = cleanText(raw.companyName, 140);
  if (companyName.length < 2) {
    throw new HttpsError("invalid-argument", "Company or brand name is required.");
  }
  const contactName = cleanText(raw.contactName, 120);
  if (contactName.length < 2) {
    throw new HttpsError("invalid-argument", "Primary contact name is required.");
  }
  const contactTitle = cleanText(raw.contactTitle, 100);
  const email = cleanText(raw.email, 160).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
    throw new HttpsError("invalid-argument", "Enter a valid business email address.");
  }
  const phone = cleanText(raw.phone, 40);
  if (phone.replace(/\D/g, "").length < 7) {
    throw new HttpsError("invalid-argument", "Enter a valid contact phone number.");
  }
  const headquartersLocation = cleanText(raw.headquartersLocation, 120);
  const partnershipTrack = cleanText(raw.partnershipTrack, 48) || "industrial_distributor";
  if (!VENDOR_PARTNERSHIP_TRACKS.has(partnershipTrack)) {
    throw new HttpsError("invalid-argument", "Select a valid partnership track.");
  }

  const rawWebsite = cleanText(raw.websiteUrl, 1000);
  let websiteUrl = "";
  if (rawWebsite) {
    const withProtocol = /^https?:\/\//i.test(rawWebsite) ?
      rawWebsite.replace(/^http:\/\//i, "https://") :
      `https://${rawWebsite}`;
    websiteUrl = parseSafeHttpsUrl(withProtocol, "Company website URL").toString();
  }

  const rawSampleCatalog = cleanText(raw.sampleCatalogUrl, 1000);
  let sampleCatalogUrl = "";
  if (rawSampleCatalog) {
    const withProtocol = /^https?:\/\//i.test(rawSampleCatalog) ?
      rawSampleCatalog.replace(/^http:\/\//i, "https://") :
      `https://${rawSampleCatalog}`;
    sampleCatalogUrl = parseSafeHttpsUrl(
        withProtocol,
        "Sample catalog or inventory URL",
    ).toString();
  }

  const rawAuthLevel = cleanText(raw.authorizationLevel, 48).toLowerCase();
  const authorizationLevel = VENDOR_AUTHORIZATION_LEVELS.has(rawAuthLevel) ?
    rawAuthLevel :
    defaultAuthorizationForTrack(partnershipTrack);

  const requestedPlacementsRaw = cleanStringList(raw.requestedPlacements, {
    maxItems: 6,
    maxItemLength: 48,
  }).filter((code) => VENDOR_REQUESTED_PLACEMENTS.has(code));
  const requestedPlacements = requestedPlacementsRaw.length > 0 ?
    requestedPlacementsRaw :
    (partnershipTrack === "oem_heavy_equipment_dealer" ?
      ["heavy_equipment_listings", "shop_storefront"] :
      ["shop_storefront"]);

  const categories = cleanStringList(raw.categories, {maxItems: 12, maxItemLength: 64})
      .filter((code) => VENDOR_APPLICATION_CATEGORY_CODES.has(code));
  if (categories.length === 0) {
    throw new HttpsError("invalid-argument", "Select at least one Store product category.");
  }

  const brandsCarried = cleanStringList(raw.brandsCarried, {maxItems: 25, maxItemLength: 80});
  const fulfillmentRegions = cleanStringList(raw.fulfillmentRegions, {
    maxItems: 10,
    maxItemLength: 40,
  });

  const rawIntegration = cleanText(raw.catalogIntegrationMethod, 48).toLowerCase();
  const catalogIntegrationMethod = VENDOR_INTEGRATION_METHODS.has(rawIntegration) ?
    rawIntegration :
    "direct_dealer_link";

  const estimatedSkuCount = cleanText(raw.estimatedSkuCount, 60) || "1-50 SKUs";
  const affiliateProgramDetails = cleanText(raw.affiliateProgramDetails, 600);
  const catalogNotes = cleanText(raw.catalogNotes, 1500);

  return {
    submitterUid: resolvedUid,
    companyName,
    contactName,
    contactTitle,
    email,
    phone,
    headquartersLocation,
    websiteUrl,
    sampleCatalogUrl,
    partnershipTrack,
    authorizationLevel,
    requestedPlacements,
    categories,
    brandsCarried,
    fulfillmentRegions: fulfillmentRegions.length > 0 ? fulfillmentRegions : ["US", "CA"],
    catalogIntegrationMethod,
    estimatedSkuCount,
    affiliateProgramDetails,
    catalogNotes,
    status: "pending",
  };
}

module.exports = {
  AFFILIATE_PLATFORMS_DIRECTORY,
  ALL_SHOP_ROLES,
  DEFAULT_STORE_SETTINGS,
  KNOWN_INDUSTRIAL_BRANDS,
  SHOP_CATEGORIES,
  SHOP_CATEGORY_BY_CODE,
  SHOP_COUNTRY_CODES,
  SHOP_PLACEMENTS,
  SHOP_PRODUCT_STATUSES,
  SHOP_SOURCE_TYPES,
  SHOP_STAFF_ROLES,
  VENDOR_APPLICATION_CATEGORY_CODES,
  VENDOR_APPLICATION_EXTRA_CATEGORIES,
  VENDOR_APPLICATION_STATUSES,
  VENDOR_AUTHORIZATION_LEVELS,
  VENDOR_INTEGRATION_METHODS,
  VENDOR_PARTNERSHIP_TRACKS,
  VENDOR_REQUESTED_PLACEMENTS,
  buildMonetizedDestinationUrl,
  buildProductSearchTokens,
  buildPublicShopProduct,
  cleanStringList,
  cleanText,
  decodeHtmlEntities,
  detectAffiliatePlatform,
  doesProductShipToCountry,
  extractAmazonAsin,
  extractAmazonSearchCandidates,
  extractHtmlProductMetadata,
  extractTitleFromAmazonSlug,
  extractTitleFromGenericSlug,
  inferBrandFromText,
  inferCategoryCodeFromText,
  inferEligibleCountries,
  inferSubcategoryFromText,
  isAmazonFullHostname,
  isAmazonSearchPageUrl,
  isAmazonShortHostname,
  isPrivateOrLocalHostname,
  normalizeAdminNotificationEmails,
  normalizeAssociateTag,
  normalizeEligibleCountries,
  normalizeHiddenStarterIds,
  normalizeStoreSettings,
  parseAffiliateSubmission,
  parseAmazonAffiliateSubmission,
  parseSafeHttpsUrl,
  resolveAmazonAssociateTag,
  resolveAmazonHostForRegion,
  upgradeAmazonCdnImageResolution,
  validateShopProductInput,
  validateVendorApplicationInput,
};
