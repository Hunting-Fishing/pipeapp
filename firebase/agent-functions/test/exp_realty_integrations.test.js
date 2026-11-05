"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  REGULATOR_REGISTRIES,
  buildPublicIntegrationStatus,
  dispatchLeadToConfiguredCrms,
  mapCreaDdfPropertyToListing,
  registryMetadataForJurisdiction,
  syncCreaDdfToFirestore,
  validateSafeExternalHttpsUrl,
  verifyRealtorLicensePublicRegistry,
} = require("../exp_realty_integrations");

test("official regulator lookup URLs cover all 25 supported jurisdiction keys", () => {
  assert.equal(Object.keys(REGULATOR_REGISTRIES).length, 25);
  assert.match(
      registryMetadataForJurisdiction("CA-AB (Alberta)").lookupUrl,
      /^https:\/\/www\.myreca\.ca\//u,
  );
  assert.equal(
      registryMetadataForJurisdiction("US-TX (Texas)").liveGovApi,
      true,
  );
  assert.equal(
      registryMetadataForJurisdiction("US-CO (Colorado)").liveGovApi,
      true,
  );
});

test("Texas TREC and Colorado DORA open-data license checks parse live schemas safely", async () => {
  const txCalls = [];
  const txResult = await verifyRealtorLicensePublicRegistry({
    jurisdiction: "US-TX (Texas)",
    licenseNumber: "679418-B'; DROP--",
    agentName: "Jesse Watson",
    fetchImpl: async (url) => {
      txCalls.push(url);
      return {
        ok: true,
        status: 200,
        json: async () => [{
          license_number: "679418-B",
          license_type: "Broker Individual",
          full_name: "JESSE WATSON",
          status: "Active",
          related_license_full_name: "EXP REALTY LLC",
          license_expiration_date: "11/30/2028",
        }],
      };
    },
  });
  assert.equal(txCalls.length, 1);
  assert.ok(!txCalls[0].includes("';"), "SoQL unsafe quotes must be stripped");
  assert.equal(txResult.matched, true);
  assert.equal(txResult.status, "Active");
  assert.equal(txResult.sponsoringBrokerage, "EXP REALTY LLC");

  const coResult = await verifyRealtorLicensePublicRegistry({
    jurisdiction: "US-CO (Colorado)",
    licenseNumber: "FA.1000711991",
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      json: async () => [{
        firstname: "Alex",
        lastname: "Mercer",
        licensenumber: "1000711991",
        licensetype: "FA",
        licensestatusdescription: "Active",
        licenseexpirationdate: "2028-12-31T00:00:00.000",
        linktoverifylicense: {url: "https://www.colorado.gov/dora/verify/123"},
      }],
    }),
  });
  assert.equal(coResult.matched, true);
  assert.equal(coResult.status, "Active");
  assert.equal(coResult.holderName, "Alex Mercer");
  assert.equal(coResult.lookupUrl, "https://www.colorado.gov/dora/verify/123");
});

test("outbound webhook validator enforces HTTPS and blocks SSRF loopback/private hosts", () => {
  assert.equal(
      validateSafeExternalHttpsUrl("https://hooks.zapier.com/hooks/catch/123/abc"),
      "https://hooks.zapier.com/hooks/catch/123/abc",
  );
  assert.throws(() => validateSafeExternalHttpsUrl("http://hooks.zapier.com/test"));
  assert.throws(() => validateSafeExternalHttpsUrl("https://localhost:8080/hook"));
  assert.throws(() => validateSafeExternalHttpsUrl("https://169.254.169.254/latest"));
  assert.throws(() => validateSafeExternalHttpsUrl("https://192.168.1.50/hook"));
  assert.throws(() => validateSafeExternalHttpsUrl("https://10.0.0.8/hook"));
});

test("dispatchLeadToConfiguredCrms delivers to BoldTrail, Lofty, and signed HTTPS webhook", async () => {
  const requests = [];
  const summary = await dispatchLeadToConfiguredCrms({
    leadId: "lead_99",
    lead: {
      requesterName: "Jordan Vance",
      requesterEmail: "jordan@example.com",
      requesterPhone: "+17805551234",
      inquiryType: "Seller / Listing Representation",
      listingId: "yard-42",
      listingTitle: "15-Acre Nisku Pipe Yard",
      locationLabel: "Nisku, AB",
      notes: "Looking to list industrial yard.",
    },
    credentials: {
      boldTrailEnabled: true,
      boldTrailApiToken: "bt-secret-token",
      loftyEnabled: true,
      loftyApiKey: "lofty-secret-key",
      webhookEnabled: true,
      webhookUrl: "https://hooks.example.com/exp-intake",
      webhookSigningSecret: "hmac-secret-123",
    },
    fetchImpl: async (url, options) => {
      requests.push({url, options});
      return {ok: true, status: 200};
    },
  });

  assert.equal(summary.status, "synced");
  assert.equal(summary.attempted, 3);
  assert.equal(summary.succeeded, 3);
  assert.equal(requests[0].url, "https://api.kvcore.com/v2/public/contact");
  assert.equal(requests[0].options.headers.Authorization, "Bearer bt-secret-token");
  assert.equal(JSON.parse(requests[0].options.body).deal_type, "seller");
  assert.equal(requests[1].url, "https://api.lofty.com/v1.0/leads");
  assert.equal(requests[1].options.headers.Authorization, "Bearer lofty-secret-key");
  assert.equal(requests[2].url, "https://hooks.example.com/exp-intake");
  assert.match(requests[2].options.headers["X-PipeBuyer-Signature"], /^sha256=[a-f0-9]{64}$/u);
});

test("CREA DDF OAuth2 + OData sync maps commercial properties and archives stale DDF listings", async () => {
  const mapped = mapCreaDdfPropertyToListing({
    ListingKey: "29481022",
    ListingId: "E4410992",
    PropertySubType: "Industrial Warehouse",
    ListPrice: 1850000,
    City: "Leduc",
    StateOrProvince: "Alberta",
    LotSizeArea: 6.5,
    LotSizeUnits: "Acres",
    BuildingAreaTotal: 14000,
    ZoningDescription: "M2 Heavy Industrial",
    ListOfficeName: "eXp Realty of Canada, Inc.",
    ListAgentMlsId: "AB-88210",
    ListingURL: "https://www.realtor.ca/real-estate/29481022/leduc",
    PublicRemarks: "Graveled pipe & rig yard with 4 drive-through bays.",
    Media: [{MediaURL: "https://cdn.realtor.ca/photo1.jpg"}],
  }, "seller_admin");

  assert.equal(mapped.docId, "ddf_29481022");
  assert.equal(mapped.payload.category, "Site & Property");
  assert.equal(mapped.payload.productType, "Shop & Building");
  assert.equal(mapped.payload.mlsNumber, "E4410992");
  assert.equal(mapped.payload.ddfSynced, true);
  assert.match(mapped.payload.description, /Powered by REALTOR\.ca/u);

  const writes = [];
  const fakeDb = {
    batch() {
      return {
        set(ref, data) {
          writes.push({id: ref.id, data});
        },
        async commit() {},
      };
    },
    collection() {
      return {
        doc(id) {
          return {id};
        },
        where() {
          return {
            limit() {
              return {
                async get() {
                  return {
                    docs: [{
                      id: "ddf_stale_old",
                      ref: {id: "ddf_stale_old"},
                      data: () => ({status: "active", ddfSynced: true}),
                    }],
                  };
                },
              };
            },
          };
        },
      };
    },
  };

  const syncResult = await syncCreaDdfToFirestore({
    db: fakeDb,
    FieldValue: {serverTimestamp: () => "SERVER_TS"},
    credentials: {
      creaDdfClientId: "ddf-id",
      creaDdfClientSecret: "ddf-secret",
    },
    actorUid: "admin_1",
    dryRun: false,
    fetchImpl: async (url) => {
      if (url === "https://identity.crea.ca/connect/token") {
        return {ok: true, status: 200, json: async () => ({access_token: "tok_abc"})};
      }
      return {
        ok: true,
        status: 200,
        json: async () => ({
          "@odata.count": 1,
          value: [{
            ListingKey: "29481022",
            ListingId: "E4410992",
            PropertySubType: "Vacant Land",
            ListPrice: 450000,
            City: "Grande Prairie",
            StateOrProvince: "Alberta",
          }],
        }),
      };
    },
  });

  assert.equal(syncResult.upsertedCount, 1);
  assert.equal(syncResult.archivedCount, 1);
  assert.equal(writes.find((w) => w.id === "ddf_stale_old").data.status, "archived");
});

test("buildPublicIntegrationStatus masks secrets and never returns raw tokens", () => {
  const status = buildPublicIntegrationStatus({
    boldTrailEnabled: true,
    boldTrailApiToken: "super-secret-bt",
    loftyEnabled: false,
    loftyApiKey: "super-secret-lofty",
    creaDdfClientId: "client-id",
    creaDdfClientSecret: "super-secret-ddf",
  });
  const serialized = JSON.stringify(status);
  assert.equal(status.boldTrailConfigured, true);
  assert.equal(status.loftyConfigured, true);
  assert.equal(status.creaDdfConfigured, true);
  assert.ok(!serialized.includes("super-secret"));
});
