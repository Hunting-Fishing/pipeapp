"use strict";

const crypto = require("node:crypto");

const REGULATOR_REGISTRIES = Object.freeze({
  "CA-AB (Alberta)": Object.freeze({
    regulatorName: "Real Estate Council of Alberta (RECA)",
    lookupUrl: "https://www.myreca.ca/public-search/",
    liveGovApi: false,
  }),
  "CA-BC (British Columbia)": Object.freeze({
    regulatorName: "BC Financial Services Authority (BCFSA)",
    lookupUrl: "https://www.bcfsa.ca/public-protection/find-professional",
    liveGovApi: false,
  }),
  "CA-SK (Saskatchewan)": Object.freeze({
    regulatorName: "Saskatchewan Real Estate Commission (SREC)",
    lookupUrl: "https://www.srec.ca/consumers/find-a-registrant/",
    liveGovApi: false,
  }),
  "CA-MB (Manitoba)": Object.freeze({
    regulatorName: "Manitoba Securities Commission — Real Estate",
    lookupUrl: "https://mbrealestate.ca/",
    liveGovApi: false,
  }),
  "CA-ON (Ontario)": Object.freeze({
    regulatorName: "Real Estate Council of Ontario (RECO)",
    lookupUrl: "https://www.reco.on.ca/public-register",
    liveGovApi: false,
  }),
  "CA-QC (Quebec)": Object.freeze({
    regulatorName: "Organisme d'autoréglementation du courtage immobilier du Québec (OACIQ)",
    lookupUrl: "https://www.oaciq.com/en/find-a-broker",
    liveGovApi: false,
  }),
  "CA-NB (New Brunswick)": Object.freeze({
    regulatorName: "Financial and Consumer Services Commission of New Brunswick (FCNB)",
    lookupUrl: "https://fcnb.ca/en/real-estate",
    liveGovApi: false,
  }),
  "CA-NS (Nova Scotia)": Object.freeze({
    regulatorName: "Nova Scotia Real Estate Commission (NSREC)",
    lookupUrl: "https://nsrec.ns.ca/consumers/licensee-search",
    liveGovApi: false,
  }),
  "CA-NL (Newfoundland & Labrador)": Object.freeze({
    regulatorName: "Digital Government and Service NL — Real Estate Licensing",
    lookupUrl: "https://www.gov.nl.ca/dgsnl/licences/real-estate/",
    liveGovApi: false,
  }),
  "CA-NL / Atlantic Canada": Object.freeze({
    regulatorName: "Atlantic Canada Provincial Real Estate Regulators (NSREC / FCNB / NL)",
    lookupUrl: "https://nsrec.ns.ca/consumers/licensee-search",
    liveGovApi: false,
  }),
  "US-TX (Texas)": Object.freeze({
    regulatorName: "Texas Real Estate Commission (TREC)",
    lookupUrl: "https://www.trec.texas.gov/apps/license-holder-search/",
    liveGovApi: true,
    apiProvider: "Texas Open Data Portal (TREC s7ft-44qi)",
    apiEndpoint: "https://data.texas.gov/resource/s7ft-44qi.json",
  }),
  "US-ND (North Dakota)": Object.freeze({
    regulatorName: "North Dakota Real Estate Commission (NDREC)",
    lookupUrl: "https://www.realestatend.org/licensee_search/",
    liveGovApi: false,
  }),
  "US-NM (New Mexico)": Object.freeze({
    regulatorName: "New Mexico Real Estate Commission (NMREC)",
    lookupUrl: "https://nmrld.my.site.com/bcd/s/public-search-license",
    liveGovApi: false,
  }),
  "US-OK (Oklahoma)": Object.freeze({
    regulatorName: "Oklahoma Real Estate Commission (OREC)",
    lookupUrl: "https://orec.us.thentiacloud.net/webs/orec/register/",
    liveGovApi: false,
  }),
  "US-LA (Louisiana)": Object.freeze({
    regulatorName: "Louisiana Real Estate Commission (LREC)",
    lookupUrl: "https://lrec.gov/consumers/active-licensee-search/",
    liveGovApi: false,
  }),
  "US-WY (Wyoming)": Object.freeze({
    regulatorName: "Wyoming Real Estate Commission (WREC)",
    lookupUrl: "https://realestate.wyo.gov/consumers/verify-a-license",
    liveGovApi: false,
  }),
  "US-MT (Montana)": Object.freeze({
    regulatorName: "Montana Board of Realty Regulation",
    lookupUrl: "https://ebizws.mt.gov/PUBLICPORTAL/searchform?mylist=licenses",
    liveGovApi: false,
  }),
  "US-CO (Colorado)": Object.freeze({
    regulatorName: "Colorado Division of Real Estate (DORA)",
    lookupUrl: "https://apps2.colorado.gov/dora/licensing/lookup/licenselookup.aspx",
    liveGovApi: true,
    apiProvider: "Colorado Open Data Portal (DORA 7s5z-vewr)",
    apiEndpoint: "https://data.colorado.gov/resource/7s5z-vewr.json",
  }),
  "US-PA (Pennsylvania)": Object.freeze({
    regulatorName: "Pennsylvania State Real Estate Commission (PALS)",
    lookupUrl: "https://www.pals.pa.gov/#/page/search",
    liveGovApi: false,
  }),
  "US-OH (Ohio)": Object.freeze({
    regulatorName: "Ohio Division of Real Estate & Professional Licensing",
    lookupUrl: "https://elicense3.com.ohio.gov/",
    liveGovApi: false,
  }),
  "US-CA (California)": Object.freeze({
    regulatorName: "California Department of Real Estate (CalDRE)",
    lookupUrl: "https://www2.dre.ca.gov/PublicASP/pplinfo.asp",
    liveGovApi: false,
  }),
  "US-FL (Florida)": Object.freeze({
    regulatorName: "Florida Real Estate Commission (DBPR / FREC)",
    lookupUrl: "https://www.myfloridalicense.com/wl11.asp",
    liveGovApi: false,
  }),
  "US-AK (Alaska)": Object.freeze({
    regulatorName: "Alaska Real Estate Commission",
    lookupUrl: "https://www.commerce.alaska.gov/cbp/main/search/professional",
    liveGovApi: false,
  }),
  "MX (Mexico)": Object.freeze({
    regulatorName: "AMPI / PROFECO Registro de Asesores Inmobiliarios",
    lookupUrl: "https://ampi.org/",
    liveGovApi: false,
  }),
  "MX (Mexico - AMPI / PROFECO)": Object.freeze({
    regulatorName: "AMPI / PROFECO Registro de Asesores Inmobiliarios",
    lookupUrl: "https://ampi.org/",
    liveGovApi: false,
  }),
});

class ExpIntegrationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ExpIntegrationError";
    this.code = code;
  }
}

function sanitizeSoqlToken(value, maxLength = 48) {
  return String(value || "")
      .trim()
      .replace(/[^A-Za-z0-9 .-]/gu, "")
      .slice(0, maxLength)
      .trim();
}

function registryMetadataForJurisdiction(jurisdiction) {
  const key = String(jurisdiction || "").trim();
  if (Object.prototype.hasOwnProperty.call(REGULATOR_REGISTRIES, key)) {
    return REGULATOR_REGISTRIES[key];
  }
  return Object.freeze({
    regulatorName: "Provincial / State Real Estate Regulator",
    lookupUrl: "https://www.arello.org/",
    liveGovApi: false,
  });
}

function validateSafeExternalHttpsUrl(rawUrl) {
  const trimmed = String(rawUrl || "").trim();
  if (!trimmed) {
    throw new ExpIntegrationError(
        "invalid-argument",
        "Provide a valid HTTPS webhook URL.",
    );
  }
  let parsed;
  try {
    parsed = new URL(trimmed);
  } catch {
    throw new ExpIntegrationError(
        "invalid-argument",
        "The webhook URL is not a valid URL.",
    );
  }
  if (parsed.protocol !== "https:") {
    throw new ExpIntegrationError(
        "invalid-argument",
        "Outbound CRM webhooks must use HTTPS.",
    );
  }
  const host = parsed.hostname.toLowerCase();
  if (host === "localhost" ||
      host.endsWith(".local") ||
      host.endsWith(".internal") ||
      host === "0.0.0.0" ||
      host === "::1" ||
      /^127\./u.test(host) ||
      /^10\./u.test(host) ||
      /^192\.168\./u.test(host) ||
      /^169\.254\./u.test(host) ||
      /^172\.(1[6-9]|2\d|3[01])\./u.test(host)) {
    throw new ExpIntegrationError(
        "invalid-argument",
        "Private, loopback, or internal webhook hosts are not permitted.",
    );
  }
  return parsed.toString();
}

function splitContactName(fullName, email) {
  const cleaned = String(fullName || "").trim();
  if (cleaned) {
    const parts = cleaned.split(/\s+/u);
    return {
      firstName: parts[0] || "Marketplace",
      lastName: parts.slice(1).join(" ") || "Inquiry",
    };
  }
  const emailPrefix = String(email || "").split("@")[0].replace(/[^A-Za-z0-9]+/gu, " ").trim();
  return {
    firstName: emailPrefix || "Marketplace",
    lastName: "Lead",
  };
}

async function verifyRealtorLicensePublicRegistry({
  jurisdiction,
  licenseNumber,
  agentName = "",
  fetchImpl = globalThis.fetch,
}) {
  const registry = registryMetadataForJurisdiction(jurisdiction);
  const safeLicense = sanitizeSoqlToken(licenseNumber, 40).toUpperCase();
  const safeName = sanitizeSoqlToken(agentName, 64).toUpperCase();
  const checkedAt = new Date().toISOString();

  if (!safeLicense) {
    throw new ExpIntegrationError(
        "invalid-argument",
        "Provide a license number to verify.",
    );
  }

  if (jurisdiction === "US-TX (Texas)") {
    const numericCore = safeLicense.replace(/-(SA|B|BB|ER)$/u, "");
    const clauses = [
      `upper(license_number)='${safeLicense}'`,
      `upper(license_number) like '${numericCore}%'`,
    ];
    if (safeName.length >= 4) {
      clauses.push(`upper(full_name)='${safeName}'`);
    }
    const url = new URL(registry.apiEndpoint);
    url.searchParams.set("$limit", "5");
    url.searchParams.set("$where", clauses.join(" OR "));
    const response = await fetchImpl(url.toString(), {
      method: "GET",
      headers: {"Accept": "application/json"},
    });
    if (!response.ok) {
      throw new ExpIntegrationError(
          "unavailable",
          `Texas TREC open-data registry returned HTTP ${response.status}.`,
      );
    }
    const rows = await response.json();
    const match = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
    return {
      jurisdiction,
      regulatorName: registry.regulatorName,
      lookupUrl: registry.lookupUrl,
      liveGovApi: true,
      apiProvider: registry.apiProvider,
      queriedLicense: safeLicense,
      matched: Boolean(match),
      status: match ? String(match.status || "Unknown") : "Not found in TREC registry",
      holderName: match ? String(match.full_name || "") : "",
      licenseNumber: match ? String(match.license_number || "") : safeLicense,
      licenseType: match ? String(match.license_type || "") : "",
      sponsoringBrokerage: match ? String(match.related_license_full_name || "") : "",
      expirationDate: match ? String(match.license_expiration_date || "") : "",
      checkedAt,
    };
  }

  if (jurisdiction === "US-CO (Colorado)") {
    const digitsOnly = safeLicense.replace(/^[A-Z.]+/u, "").replace(/[^0-9]/gu, "");
    const clauses = [`upper(licensenumber)='${safeLicense}'`];
    if (digitsOnly.length >= 4) {
      clauses.push(`licensenumber='${digitsOnly}'`);
    }
    const url = new URL(registry.apiEndpoint);
    url.searchParams.set("$limit", "5");
    url.searchParams.set("$where", clauses.join(" OR "));
    const response = await fetchImpl(url.toString(), {
      method: "GET",
      headers: {"Accept": "application/json"},
    });
    if (!response.ok) {
      throw new ExpIntegrationError(
          "unavailable",
          `Colorado DORA open-data registry returned HTTP ${response.status}.`,
      );
    }
    const rows = await response.json();
    const match = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
    const holderName = match ?
      [match.firstname, match.middlename, match.lastname]
          .filter(Boolean)
          .join(" ")
          .trim() || String(match.entityname || "") :
      "";
    const directVerifyUrl = match &&
      match.linktoverifylicense &&
      typeof match.linktoverifylicense.url === "string" ?
      match.linktoverifylicense.url :
      registry.lookupUrl;
    return {
      jurisdiction,
      regulatorName: registry.regulatorName,
      lookupUrl: directVerifyUrl,
      liveGovApi: true,
      apiProvider: registry.apiProvider,
      queriedLicense: safeLicense,
      matched: Boolean(match),
      status: match ?
        String(match.licensestatusdescription || "Unknown") :
        "Not found in Colorado DORA registry",
      holderName,
      licenseNumber: match ? String(match.licensenumber || "") : safeLicense,
      licenseType: match ? String(match.licensetype || "") : "",
      sponsoringBrokerage: "",
      expirationDate: match ? String(match.licenseexpirationdate || "") : "",
      checkedAt,
    };
  }

  return {
    jurisdiction: String(jurisdiction || ""),
    regulatorName: registry.regulatorName,
    lookupUrl: registry.lookupUrl,
    liveGovApi: false,
    apiProvider: "Official Public Regulator Portal",
    queriedLicense: safeLicense,
    matched: null,
    status: "Manual portal verification ready",
    holderName: "",
    licenseNumber: safeLicense,
    licenseType: "",
    sponsoringBrokerage: "",
    expirationDate: "",
    checkedAt,
  };
}

async function dispatchLeadToConfiguredCrms({
  lead,
  leadId,
  credentials,
  fetchImpl = globalThis.fetch,
}) {
  const creds = credentials || {};
  const results = [];
  const {firstName, lastName} = splitContactName(
      lead.requesterName,
      lead.requesterEmail,
  );
  const inquiryType = String(lead.inquiryType || "Buyer Representation");
  const isSeller = inquiryType.toLowerCase().includes("seller");
  const summaryNote = [
    `Pipe Buyer Site & Property Inquiry (${inquiryType})`,
    `Listing: ${lead.listingTitle || "Property Listing"} (${lead.listingId || "N/A"})`,
    `Location: ${lead.locationLabel || "N/A"}`,
    `Notes: ${lead.notes || "No additional notes"}`,
  ].join("\n");

  // 1. BoldTrail / kvCORE Public API v2 (free with eXp Realty CRM)
  if (creds.boldTrailEnabled === true &&
      typeof creds.boldTrailApiToken === "string" &&
      creds.boldTrailApiToken.trim() !== "") {
    try {
      const response = await fetchImpl("https://api.kvcore.com/v2/public/contact", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": `Bearer ${creds.boldTrailApiToken.trim()}`,
        },
        body: JSON.stringify({
          first_name: firstName,
          last_name: lastName,
          email: String(lead.requesterEmail || "").trim(),
          cell_phone_1: String(lead.requesterPhone || "").trim(),
          deal_type: isSeller ? "seller" : "buyer",
          status: 0,
          source: "Pipe Buyer Marketplace",
          system_type: "Pipe Buyer eXp Desk",
          hashtags: ["pipebuyer", "site_and_property"],
          notes: summaryNote,
        }),
      });
      results.push({
        provider: "boldtrail_kvcore",
        ok: response.ok,
        status: response.status,
      });
    } catch (error) {
      results.push({
        provider: "boldtrail_kvcore",
        ok: false,
        error: error && error.message || "network_error",
      });
    }
  }

  // 2. Lofty (Chime) Open API v1.0 (free with eXp Realty CRM)
  if (creds.loftyEnabled === true &&
      typeof creds.loftyApiKey === "string" &&
      creds.loftyApiKey.trim() !== "") {
    try {
      const email = String(lead.requesterEmail || "").trim();
      const phone = String(lead.requesterPhone || "").trim();
      const response = await fetchImpl("https://api.lofty.com/v1.0/leads", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": `Bearer ${creds.loftyApiKey.trim()}`,
        },
        body: JSON.stringify({
          firstName,
          lastName,
          emails: email ? [email] : [],
          phones: phone ? [phone] : [],
          source: "Pipe Buyer Marketplace",
          stage: "New Lead",
          tags: ["PipeBuyer", "SiteAndProperty", isSeller ? "Seller" : "Buyer"],
          notes: summaryNote,
        }),
      });
      results.push({
        provider: "lofty_crm",
        ok: response.ok,
        status: response.status,
      });
    } catch (error) {
      results.push({
        provider: "lofty_crm",
        ok: false,
        error: error && error.message || "network_error",
      });
    }
  }

  // 3. Universal HTTPS Webhook (Zapier / Make / Rechat / Team Intake)
  if (creds.webhookEnabled === true &&
      typeof creds.webhookUrl === "string" &&
      creds.webhookUrl.trim() !== "") {
    const targetUrl = validateSafeExternalHttpsUrl(creds.webhookUrl);
    const bodyString = JSON.stringify({
      event: "exp_realty.lead.created",
      leadId,
      occurredAt: new Date().toISOString(),
      source: "Pipe Buyer Marketplace",
      inquiryType,
      listingId: lead.listingId || "",
      listingTitle: lead.listingTitle || "",
      locationLabel: lead.locationLabel || "",
      requesterEmail: lead.requesterEmail || "",
      requesterPhone: lead.requesterPhone || "",
      notes: lead.notes || "",
    });
    const headers = {
      "Content-Type": "application/json",
      "User-Agent": "PipeBuyer-ExpRealty-Webhook/1.0",
    };
    if (typeof creds.webhookSigningSecret === "string" &&
        creds.webhookSigningSecret.trim() !== "") {
      const digest = crypto
          .createHmac("sha256", creds.webhookSigningSecret.trim())
          .update(bodyString)
          .digest("hex");
      headers["X-PipeBuyer-Signature"] = `sha256=${digest}`;
    }
    try {
      const response = await fetchImpl(targetUrl, {
        method: "POST",
        headers,
        body: bodyString,
      });
      results.push({
        provider: "https_webhook",
        ok: response.ok,
        status: response.status,
      });
    } catch (error) {
      results.push({
        provider: "https_webhook",
        ok: false,
        error: error && error.message || "network_error",
      });
    }
  }

  const attempted = results.length;
  const succeeded = results.filter((item) => item.ok).length;
  return {
    status: attempted === 0 ?
      "no_crm_configured" :
      (succeeded === attempted ? "synced" : (succeeded > 0 ? "partial" : "failed")),
    attempted,
    succeeded,
    results,
    syncedAt: new Date().toISOString(),
  };
}

function buildSearchTokensFromText(...parts) {
  const tokens = new Set();
  for (const part of parts) {
    const words = String(part || "")
        .toLowerCase()
        .split(/[^a-z0-9]+/u)
        .filter((word) => word.length >= 2 && word.length <= 32);
    for (const word of words) {
      tokens.add(word);
      if (tokens.size >= 60) break;
    }
  }
  return [...tokens];
}

function mapCreaDdfPropertyToListing(property, sellerUid) {
  const listingKey = String(property.ListingKey || property.ListingId || "").trim();
  if (!listingKey) return null;
  const mlsNumber = String(property.ListingId || listingKey).trim();
  const city = String(property.City || "").trim();
  const province = String(property.StateOrProvince || "Alberta").trim();
  const subType = String(property.PropertySubType || property.PropertyType || "").toLowerCase();
  let productType = "Real Estate & Property";
  if (subType.includes("vacant") || subType.includes("lot")) {
    productType = "Lots & Vacant Land";
  } else if (subType.includes("agri") || subType.includes("farm") || subType.includes("land")) {
    productType = "Land & Acreage";
  } else if (subType.includes("business")) {
    productType = "Business for Sale";
  } else if (subType.includes("industrial") || subType.includes("warehouse")) {
    productType = "Shop & Building";
  } else if (subType.includes("commercial") || subType.includes("retail") || subType.includes("office")) {
    productType = "Commercial Facility";
  }

  const rawPrice = Number(property.ListPrice || property.LeaseAmount || 0);
  const price = Number.isFinite(rawPrice) && rawPrice > 0 ? rawPrice : 0;
  const isLease = Boolean(!property.ListPrice && property.LeaseAmount);
  const mediaList = Array.isArray(property.Media) ? property.Media : [];
  const imageUrls = mediaList
      .map((item) => item && typeof item.MediaURL === "string" ? item.MediaURL.trim() : "")
      .filter((url) => url.startsWith("https://"))
      .slice(0, 12);

  const officeName = String(
      property.ListOfficeName || "eXp Realty of Canada, Inc.",
  ).trim();
  const titleSummary = String(
      property.UnparsedAddress ||
      [city, province].filter(Boolean).join(", ") ||
      `MLS® ${mlsNumber}`,
  ).trim();
  const title = `${productType} — ${titleSummary}`.slice(0, 120);
  const remarks = String(property.PublicRemarks || "").trim();
  const realtorCaUrl = typeof property.ListingURL === "string" &&
    property.ListingURL.trim().startsWith("http") ?
    (property.ListingURL.trim().startsWith("https://") ?
      property.ListingURL.trim() :
      `https://${property.ListingURL.trim().replace(/^http:\/\//iu, "")}`) :
    "https://www.realtor.ca/";

  const description = [
    remarks || `${title} listed by ${officeName}.`,
    "",
    `MLS® #${mlsNumber} • Listing Brokerage: ${officeName}.`,
    "Powered by REALTOR.ca — Data provided via CREA DDF®.",
  ].join("\n").slice(0, 3800);

  const locationLabel = [city, province, "Canada"].filter(Boolean).join(", ");
  const lotSize = property.LotSizeArea != null ? String(property.LotSizeArea) : "";
  const lotUnits = String(property.LotSizeUnits || "Acres").trim() || "Acres";
  const buildingArea = property.BuildingAreaTotal != null ?
    String(property.BuildingAreaTotal) :
    "";

  return {
    docId: `ddf_${listingKey.replace(/[^A-Za-z0-9_-]/gu, "_")}`,
    payload: {
      title,
      category: "Site & Property",
      productType,
      transactionType: isLease ? "For Rent / Lease" : "For Sale",
      status: "active",
      currency: "CAD",
      price,
      priceBasis: price > 0 ?
        (isLease ? "Lease rate" : "Total property") :
        "Call for price",
      quantity: 1,
      condition: "Existing site / facility",
      description,
      location: locationLabel,
      publicLocationLabel: locationLabel,
      nearestTown: city,
      region: province,
      country: "Canada",
      landArea: lotSize,
      landAreaUnit: lotUnits,
      buildingArea,
      buildingAreaUnit: "Square feet",
      zoningOrUse: String(property.ZoningDescription || property.Zoning || "").trim(),
      propertyOffering: productType === "Business for Sale" ?
        "Turnkey business & real estate" :
        (buildingArea ? "Land & buildings" : "Land only"),
      propertyInterest: isLease ? "Commercial lease" : "Freehold / fee simple",
      listingRepresentation: "Licensed Realtor / Brokerage",
      brokerageEntityId: "exp-realty-canada",
      brokerageName: officeName,
      agentLicenseNumber: String(property.ListAgentMlsId || "").trim(),
      agentJurisdiction: `CA-${province.slice(0, 2).toUpperCase()}`,
      mlsNumber,
      realtorCaUrl,
      ddfSynced: true,
      ddfListingKey: listingKey,
      sellerUid,
      imageUrls,
      primaryImageUrl: imageUrls[0] || "",
      searchTokens: buildSearchTokensFromText(
          title,
          productType,
          city,
          province,
          officeName,
          mlsNumber,
          property.ZoningDescription,
      ),
    },
  };
}

async function requestCreaDdfAccessToken({
  clientId,
  clientSecret,
  fetchImpl = globalThis.fetch,
}) {
  const id = String(clientId || "").trim();
  const secret = String(clientSecret || "").trim();
  if (!id || !secret) {
    throw new ExpIntegrationError(
        "failed-precondition",
        "Configure your free CREA DDF® Client ID and Client Secret first.",
    );
  }
  const body = new URLSearchParams({
    grant_type: "client_credentials",
    client_id: id,
    client_secret: secret,
    scope: "DDFApi_Read",
  });
  const response = await fetchImpl("https://identity.crea.ca/connect/token", {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: body.toString(),
  });
  if (!response.ok) {
    throw new ExpIntegrationError(
        "permission-denied",
        `CREA identity server rejected DDF credentials (HTTP ${response.status}).`,
    );
  }
  const tokenJson = await response.json();
  if (!tokenJson || typeof tokenJson.access_token !== "string") {
    throw new ExpIntegrationError(
        "unavailable",
        "CREA identity server did not return an access_token.",
    );
  }
  return tokenJson.access_token;
}

async function fetchCreaDdfProperties({
  accessToken,
  odataFilter = "",
  top = 50,
  fetchImpl = globalThis.fetch,
}) {
  const boundedTop = Math.min(Math.max(Number(top) || 25, 1), 100);
  const url = new URL("https://ddfapi.realtor.ca/odata/v1/Property");
  url.searchParams.set("$top", String(boundedTop));
  url.searchParams.set("$count", "true");
  if (typeof odataFilter === "string" && odataFilter.trim() !== "") {
    url.searchParams.set("$filter", odataFilter.trim());
  }
  const response = await fetchImpl(url.toString(), {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Accept": "application/json",
    },
  });
  if (!response.ok) {
    throw new ExpIntegrationError(
        "unavailable",
        `CREA DDF® Property endpoint returned HTTP ${response.status}.`,
    );
  }
  const payload = await response.json();
  const records = payload && Array.isArray(payload.value) ? payload.value : [];
  const totalCount = typeof payload["@odata.count"] === "number" ?
    payload["@odata.count"] :
    records.length;
  return {records, totalCount};
}

async function syncCreaDdfToFirestore({
  db,
  FieldValue,
  credentials,
  actorUid,
  dryRun = false,
  fetchImpl = globalThis.fetch,
}) {
  const token = await requestCreaDdfAccessToken({
    clientId: credentials.creaDdfClientId,
    clientSecret: credentials.creaDdfClientSecret,
    fetchImpl,
  });
  const {records, totalCount} = await fetchCreaDdfProperties({
    accessToken: token,
    odataFilter: credentials.creaDdfOdataFilter || "",
    top: credentials.creaDdfMaxListings || 50,
    fetchImpl,
  });

  const sellerUid = String(credentials.creaDdfSellerUid || actorUid || "").trim();
  const mapped = records
      .map((item) => mapCreaDdfPropertyToListing(item, sellerUid))
      .filter(Boolean);

  if (dryRun) {
    return {
      ok: true,
      dryRun: true,
      totalAvailableInFeed: totalCount,
      fetchedCount: records.length,
      mappableCount: mapped.length,
      checkedAt: new Date().toISOString(),
    };
  }

  const activeDocIds = new Set(mapped.map((entry) => entry.docId));
  const batch = db.batch();
  for (const entry of mapped) {
    const ref = db.collection("public_listings").doc(entry.docId);
    batch.set(ref, {
      ...entry.payload,
      updatedAt: FieldValue.serverTimestamp(),
      ddfLastSyncedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  // CREA DDF® 24-hour freshness compliance: archive previously synced DDF
  // listings that are no longer present in the active feed response.
  const existingSnapshot = await db
      .collection("public_listings")
      .where("ddfSynced", "==", true)
      .limit(200)
      .get();
  let archivedCount = 0;
  for (const existingDoc of existingSnapshot.docs) {
    if (!activeDocIds.has(existingDoc.id) &&
        existingDoc.data().status === "active") {
      batch.set(existingDoc.ref, {
        status: "archived",
        ddfArchivedReason: "removed_from_crea_ddf_feed",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      archivedCount += 1;
    }
  }

  await batch.commit();
  return {
    ok: true,
    dryRun: false,
    totalAvailableInFeed: totalCount,
    upsertedCount: mapped.length,
    archivedCount,
    syncedAt: new Date().toISOString(),
  };
}

function buildPublicIntegrationStatus(secretDocData = {}) {
  return {
    boldTrailEnabled: secretDocData.boldTrailEnabled === true,
    boldTrailConfigured: Boolean(
        typeof secretDocData.boldTrailApiToken === "string" &&
        secretDocData.boldTrailApiToken.trim() !== "",
    ),
    loftyEnabled: secretDocData.loftyEnabled === true,
    loftyConfigured: Boolean(
        typeof secretDocData.loftyApiKey === "string" &&
        secretDocData.loftyApiKey.trim() !== "",
    ),
    webhookEnabled: secretDocData.webhookEnabled === true,
    webhookConfigured: Boolean(
        typeof secretDocData.webhookUrl === "string" &&
        secretDocData.webhookUrl.trim() !== "",
    ),
    webhookUrl: typeof secretDocData.webhookUrl === "string" ?
      secretDocData.webhookUrl :
      "",
    webhookSigningConfigured: Boolean(
        typeof secretDocData.webhookSigningSecret === "string" &&
        secretDocData.webhookSigningSecret.trim() !== "",
    ),
    creaDdfAutoSyncEnabled: secretDocData.creaDdfAutoSyncEnabled === true,
    creaDdfConfigured: Boolean(
        typeof secretDocData.creaDdfClientId === "string" &&
        secretDocData.creaDdfClientId.trim() !== "" &&
        typeof secretDocData.creaDdfClientSecret === "string" &&
        secretDocData.creaDdfClientSecret.trim() !== "",
    ),
    creaDdfOdataFilter: typeof secretDocData.creaDdfOdataFilter === "string" ?
      secretDocData.creaDdfOdataFilter :
      "",
    lastDdfSyncAt: secretDocData.lastDdfSyncIso || null,
    lastDdfSyncSummary: secretDocData.lastDdfSyncSummary || null,
    registries: REGULATOR_REGISTRIES,
  };
}

module.exports = {
  ExpIntegrationError,
  REGULATOR_REGISTRIES,
  buildPublicIntegrationStatus,
  dispatchLeadToConfiguredCrms,
  fetchCreaDdfProperties,
  mapCreaDdfPropertyToListing,
  registryMetadataForJurisdiction,
  requestCreaDdfAccessToken,
  sanitizeSoqlToken,
  syncCreaDdfToFirestore,
  validateSafeExternalHttpsUrl,
  verifyRealtorLicensePublicRegistry,
};
