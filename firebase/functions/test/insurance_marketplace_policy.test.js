"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const {
  ANNUAL_REVENUE_BANDS,
  FLEET_SIZE_BANDS,
  INSURANCE_COVERAGE_LINES,
  INSURANCE_PROVIDER_TYPES,
  InsurancePolicyError,
  MSA_ENDORSEMENTS,
  PROVIDER_APPLICATION_STATUSES,
  RATE_APPLICATION_STATUSES,
  assertRateApplicationStatusTransition,
  normalizeInsuranceProviderRecord,
  toPublicInsuranceProvider,
  validateInsuranceProviderApplication,
  validateInsuranceRateApplication,
} = require("../insurance_marketplace_policy");
const {
  createInsuranceMarketplaceCommands,
} = require("../insurance_marketplace_commands");

function createFakeAdmin() {
  const store = new Map();
  let autoIdCounter = 0;

  function cloneValue(val) {
    if (val == null) return val;
    if (typeof val.toDate === "function") return val;
    if (Array.isArray(val)) return val.map(cloneValue);
    if (typeof val === "object") {
      return Object.fromEntries(
          Object.entries(val).map(([k, v]) => [k, cloneValue(v)]),
      );
    }
    return val;
  }

  function resolveFieldValues(obj) {
    if (obj == null) return obj;
    if (obj.__serverTimestamp === true) {
      const now = new Date();
      return {
        toDate: () => now,
        toMillis: () => now.getTime(),
      };
    }
    if (typeof obj.toDate === "function") return obj;
    if (Array.isArray(obj)) return obj.map(resolveFieldValues);
    if (typeof obj === "object") {
      return Object.fromEntries(
          Object.entries(obj).map(([k, v]) => [k, resolveFieldValues(v)]),
      );
    }
    return obj;
  }

  function makeDocRef(collectionPath, docId) {
    const id = docId || `auto_${++autoIdCounter}`;
    const fullPath = `${collectionPath}/${id}`;
    return {
      id,
      path: fullPath,
      async get() {
        const exists = store.has(fullPath);
        const data = exists ? cloneValue(store.get(fullPath)) : undefined;
        return {
          id,
          exists,
          ref: makeDocRef(collectionPath, id),
          data: () => data,
        };
      },
      async set(payload, options = {}) {
        const resolved = resolveFieldValues(payload);
        if (options && options.merge && store.has(fullPath)) {
          store.set(fullPath, {...store.get(fullPath), ...resolved});
        } else {
          store.set(fullPath, resolved);
        }
      },
      async update(payload) {
        if (!store.has(fullPath)) {
          throw new Error(`Document not found: ${fullPath}`);
        }
        store.set(fullPath, {
          ...store.get(fullPath),
          ...resolveFieldValues(payload),
        });
      },
      async delete() {
        store.delete(fullPath);
      },
      collection(subName) {
        return makeCollection(`${fullPath}/${subName}`);
      },
    };
  }

  function makeQuery(collectionPath, filters = [], maxDocs = null) {
    return {
      where(field, op, value) {
        return makeQuery(collectionPath, [...filters, {field, op, value}], maxDocs);
      },
      limit(count) {
        return makeQuery(collectionPath, filters, count);
      },
      async get() {
        const prefix = `${collectionPath}/`;
        const docs = [];
        for (const [key, value] of store.entries()) {
          if (!key.startsWith(prefix)) continue;
          const remainder = key.slice(prefix.length);
          if (remainder.includes("/")) continue;
          const matchesAll = filters.every(({field, op, value: expected}) => {
            const actual = value[field];
            if (op === "==") return actual === expected;
            if (op === "array-contains") {
              return Array.isArray(actual) && actual.includes(expected);
            }
            return true;
          });
          if (matchesAll) {
            docs.push({
              id: remainder,
              exists: true,
              ref: makeDocRef(collectionPath, remainder),
              data: () => cloneValue(value),
            });
          }
        }
        const sliced = maxDocs == null ? docs : docs.slice(0, maxDocs);
        return {
          empty: sliced.length === 0,
          size: sliced.length,
          docs: sliced,
        };
      },
    };
  }

  function makeCollection(collectionPath) {
    const baseQuery = makeQuery(collectionPath);
    return {
      ...baseQuery,
      doc(docId) {
        return makeDocRef(collectionPath, docId);
      },
      async add(payload) {
        const ref = makeDocRef(collectionPath);
        await ref.set(payload);
        return ref;
      },
    };
  }

  const firestoreInstance = {
    collection(name) {
      return makeCollection(name);
    },
    async runTransaction(callback) {
      const tx = {
        async get(ref) {
          return ref.get();
        },
        set(ref, payload, options) {
          return ref.set(payload, options);
        },
        create(ref, payload) {
          return ref.set(payload);
        },
        update(ref, payload) {
          return ref.update(payload);
        },
        delete(ref) {
          return ref.delete();
        },
      };
      return callback(tx);
    },
  };

  const firestoreFn = () => firestoreInstance;
  firestoreFn.FieldValue = {
    serverTimestamp: () => ({__serverTimestamp: true}),
  };
  firestoreFn.Timestamp = {
    now: () => ({
      toMillis: () => Date.now(),
      toDate: () => new Date(),
    }),
    fromMillis: (ms) => ({
      toMillis: () => ms,
      toDate: () => new Date(ms),
    }),
    fromDate: (date) => ({
      toMillis: () => date.getTime(),
      toDate: () => date,
    }),
  };

  return {
    store,
    admin: {
      firestore: firestoreFn,
    },
  };
}

test("exports complete commercial & oilfield insurance taxonomy and status constants", () => {
  assert.equal(INSURANCE_COVERAGE_LINES.length, 8);
  const codes = INSURANCE_COVERAGE_LINES.map((line) => line.code);
  assert.deepEqual(codes, [
    "commercial_auto_fleet",
    "oilfield_general_liability",
    "rig_equipment_inland_marine",
    "motor_truck_cargo_hazmat",
    "pollution_environmental",
    "umbrella_excess_liability",
    "workers_comp_crew",
    "commercial_property_yards",
  ]);

  assert.deepEqual(
      MSA_ENDORSEMENTS.map((item) => item.code),
      [
        "waiver_of_subrogation",
        "additional_insured",
        "primary_non_contributory",
        "thirty_day_cancellation_notice",
        "hired_non_owned_auto",
        "sudden_accidental_pollution",
      ],
  );
  assert.ok(ANNUAL_REVENUE_BANDS.length >= 5);
  assert.ok(FLEET_SIZE_BANDS.length >= 5);
  assert.deepEqual(INSURANCE_PROVIDER_TYPES, [
    "carrier",
    "mga",
    "specialty_broker",
  ]);
  assert.deepEqual(RATE_APPLICATION_STATUSES, [
    "new",
    "matching",
    "quoted",
    "bound",
    "closed",
  ]);
  assert.deepEqual(PROVIDER_APPLICATION_STATUSES, [
    "pending_review",
    "approved",
    "declined",
  ]);
});

test("validates and normalizes company insurance rate applications", () => {
  const valid = validateInsuranceRateApplication({
    companyName: "Permian Basin Tubular Hauling LLC",
    contactName: "Wyatt Reynolds",
    email: "Wyatt@PermianTubular.com",
    phone: "432-555-0194",
    countryCode: "us",
    regionCode: "tx",
    city: "Midland",
    operatingBasins: ["Permian Basin", "Eagle Ford", "permian basin"],
    coverageLines: [
      "commercial_auto_fleet",
      "Oilfield General Liability & MSA",
      "umbrella_excess_liability",
    ],
    msaRequirements: [
      "waiver_of_subrogation",
      "additional_insured",
      "primary_non_contributory",
    ],
    fleetVehicleCount: 14,
    equipmentValueUsd: 2450000,
    annualRevenueBand: "2m_10m",
    dotOrMcNumber: "USDOT 3981124",
    desiredEffectiveDate: "2026-11-15",
    claimsSummary: "Zero reportable DOT losses in 36 months.",
    notes: "Need $5M umbrella for Tier-1 Permian operator MSA.",
  });

  assert.equal(valid.email, "wyatt@permiantubular.com");
  assert.equal(valid.phone, "(432) 555-0194");
  assert.equal(valid.countryCode, "US");
  assert.equal(valid.regionCode, "TX");
  assert.equal(valid.operatingBasins.length, 2);
  assert.deepEqual(valid.coverageLines, [
    "commercial_auto_fleet",
    "oilfield_general_liability",
    "umbrella_excess_liability",
  ]);
  assert.equal(valid.fleetSizeBand, "6_25_units");
  assert.equal(valid.distributionMode, "multi_carrier");
  assert.equal(valid.targetProviderId, null);

  const targeted = validateInsuranceRateApplication({
    ...valid,
    targetProviderId: "prov_lonestar_energy",
    targetProviderName: "Lone Star Energy Underwriters",
  });
  assert.equal(targeted.distributionMode, "single_provider");
  assert.equal(targeted.targetProviderId, "prov_lonestar_energy");

  assert.throws(
      () => validateInsuranceRateApplication({...valid, coverageLines: []}),
      (err) => err instanceof InsurancePolicyError && err.code === "invalid-argument",
  );
  assert.throws(
      () => validateInsuranceRateApplication({...valid, msaRequirements: ["fake_endorsement"]}),
      (err) => err instanceof InsurancePolicyError && err.code === "invalid-argument",
  );
  assert.throws(
      () => validateInsuranceRateApplication({...valid, email: "not-an-email"}),
      (err) => err instanceof InsurancePolicyError && err.code === "invalid-argument",
  );
  assert.throws(
      () => validateInsuranceRateApplication({...valid, targetProviderId: "bad/id"}),
      (err) => err instanceof InsurancePolicyError && err.code === "invalid-argument",
  );
});

test("validates carrier/broker onboarding applications and sanitizes public provider projection", () => {
  const providerApp = validateInsuranceProviderApplication({
    companyName: "Western Basin Energy Risk MGA Inc.",
    providerType: "mga",
    contactName: "claire henderson",
    contactTitle: "VP Oil & Gas Underwriting",
    email: "underwriting@westernbasinmga.ca",
    phone: "403-555-0148",
    website: "westernbasinmga.ca",
    licenseSummary: "Alberta AIC #99214, Saskatchewan RIBO, Texas Surplus Lines #88120",
    licensedCountries: ["ca", "us"],
    licensedRegions: ["ab", "sk", "bc", "tx", "nd"],
    coverageLines: [
      "oilfield_general_liability",
      "pollution_environmental",
      "rig_equipment_inland_marine",
    ],
    amBestRating: "A (Excellent)",
    maxLimitUsd: 25000000,
    fastCoi24x7: true,
    msaCompliant: true,
    minimumPremiumUsd: 7500,
    summary: "Dedicated upstream & midstream oilfield MGA binding MSA-compliant packages.",
  });

  assert.equal(providerApp.providerType, "mga");
  assert.equal(providerApp.website, "https://westernbasinmga.ca/");
  assert.deepEqual(providerApp.licensedCountries, ["CA", "US"]);
  assert.deepEqual(providerApp.licensedRegions, ["AB", "SK", "BC", "TX", "ND"]);

  const masterRecord = normalizeInsuranceProviderRecord({
    ...providerApp,
    featured: true,
    adminNotes: "CONFIDENTIAL: 15% MGA binding authority treaty verified on 2026-10-20.",
    internalContactEmail: "compliance-private@westernbasinmga.ca",
    internalContactPhone: "403-555-9999",
  });

  assert.ok(masterRecord.adminNotes.includes("CONFIDENTIAL"));
  const publicProjected = toPublicInsuranceProvider({
    providerId: "prov_western_basin",
    ...masterRecord,
  });

  assert.equal(publicProjected.providerId, "prov_western_basin");
  assert.equal(publicProjected.featured, true);
  assert.equal(publicProjected.msaCompliant, true);
  assert.equal(publicProjected.fastCoi24x7, true);
  assert.equal("adminNotes" in publicProjected, false);
  assert.equal("internalContactEmail" in publicProjected, false);
  assert.equal("internalContactPhone" in publicProjected, false);
});

test("enforces rate application status state machine transitions", () => {
  assert.equal(assertRateApplicationStatusTransition("new", "matching"), "matching");
  assert.equal(assertRateApplicationStatusTransition("matching", "quoted"), "quoted");
  assert.equal(assertRateApplicationStatusTransition("quoted", "quoted"), "quoted");
  assert.equal(assertRateApplicationStatusTransition("quoted", "bound"), "bound");
  assert.equal(assertRateApplicationStatusTransition("bound", "closed"), "closed");

  assert.throws(
      () => assertRateApplicationStatusTransition("new", "bound"),
      (err) => err instanceof InsurancePolicyError && err.code === "failed-precondition",
  );
  assert.throws(
      () => assertRateApplicationStatusTransition("bound", "matching"),
      (err) => err instanceof InsurancePolicyError && err.code === "failed-precondition",
  );
  assert.throws(
      () => assertRateApplicationStatusTransition("closed", "quoted"),
      (err) => err instanceof InsurancePolicyError && err.code === "failed-precondition",
  );
  assert.throws(
      () => assertRateApplicationStatusTransition("new", "invalid_state"),
      (err) => err instanceof InsurancePolicyError && err.code === "invalid-argument",
  );
});

test("executes full provider onboarding, public filtering, rate application, and admin workflow", async () => {
  const {admin, store} = createFakeAdmin();
  const adminNotifications = [];
  const commands = createInsuranceMarketplaceCommands(admin, {
    notifyAdministrators: async (payload) => {
      adminNotifications.push(payload);
    },
  });

  const mfaAdminAuth = {
    uid: "admin_uid_1",
    token: {
      admin: true,
      role: "administrator",
      email_verified: true,
      firebase: {sign_in_second_factor: "totp"},
    },
  };

  // 1. Carrier applies to list on Pipe Buyer
  const providerAppRes = await commands.submitInsuranceProviderApplication({
    rawRequest: {ip: "203.0.113.10"},
    data: {
      companyName: "Permian Shield Specialty Insurance",
      providerType: "carrier",
      contactName: "Marcus Vance",
      contactTitle: "Chief Underwriting Officer",
      email: "quotes@permianshield.example.com",
      phone: "432-555-0188",
      website: "https://permianshield.example.com",
      licenseSummary: "Admitted P&C Carrier NAIC #44219 (TX, NM, OK, ND, LA, WY)",
      licensedCountries: ["US"],
      licensedRegions: ["TX", "NM", "OK", "ND"],
      operatingBasins: ["Permian Basin", "Williston / Bakken"],
      coverageLines: [
        "commercial_auto_fleet",
        "oilfield_general_liability",
        "umbrella_excess_liability",
      ],
      amBestRating: "A+ (Superior)",
      maxLimitUsd: 25000000,
      fastCoi24x7: true,
      msaCompliant: true,
      minimumPremiumUsd: 10000,
      summary: "Direct oilfield fleet and $25M MSA excess carrier.",
    },
  });
  assert.equal(providerAppRes.status, "pending_review");
  assert.equal(adminNotifications.length, 1);

  // Non-admin user cannot review applications
  await assert.rejects(
      () => commands.reviewInsuranceProviderApplication({
        auth: {uid: "regular_user", token: {email_verified: true}},
        data: {applicationId: providerAppRes.applicationId, decision: "approved"},
      }),
      (err) => err.code === "permission-denied",
  );

  // 2. MFA Administrator approves & features the provider
  const reviewRes = await commands.reviewInsuranceProviderApplication({
    auth: mfaAdminAuth,
    data: {
      applicationId: providerAppRes.applicationId,
      decision: "approved",
      featured: true,
      reviewNote: "Verified NAIC #44219 active authority.",
    },
  });
  assert.equal(reviewRes.status, "approved");
  assert.ok(reviewRes.providerId);

  // Verify public projection strips adminNotes
  const publicDoc = store.get(`insurance_public_providers/${reviewRes.providerId}`);
  assert.ok(publicDoc);
  assert.equal(publicDoc.companyName, "Permian Shield Specialty Insurance");
  assert.equal("adminNotes" in publicDoc, false);

  // 3. Public browse filters active providers
  const browseHit = await commands.listInsuranceProviders({
    data: {
      coverageLine: "commercial_auto_fleet",
      countryCode: "US",
      regionCode: "TX",
      msaOnly: true,
      fastCoiOnly: true,
    },
  });
  assert.equal(browseHit.totalMatched, 1);
  assert.equal(browseHit.providers[0].providerId, reviewRes.providerId);

  const browseMiss = await commands.listInsuranceProviders({
    data: {countryCode: "CA"},
  });
  assert.equal(browseMiss.totalMatched, 0);

  // 4. Signed-in company applies for commercial insurance rates directly on site
  const memberAuth = {
    uid: "buyer_company_uid_7",
    token: {email: "ops@redwaterhauling.com", email_verified: true},
  };
  const rateRes = await commands.submitInsuranceRateApplication({
    auth: memberAuth,
    data: {
      companyName: "Redwater Heavy Haul & Pipe LLC",
      contactName: "Elena Morales",
      email: "ops@redwaterhauling.com",
      phone: "432-555-0133",
      countryCode: "US",
      regionCode: "TX",
      city: "Odessa",
      operatingBasins: ["Permian Basin"],
      coverageLines: ["commercial_auto_fleet", "motor_truck_cargo_hazmat"],
      msaRequirements: ["waiver_of_subrogation", "additional_insured"],
      fleetVehicleCount: 9,
      equipmentValueUsd: 1850000,
      annualRevenueBand: "2m_10m",
      targetProviderId: reviewRes.providerId,
    },
  });
  assert.equal(rateRes.status, "new");
  assert.equal(rateRes.distributionMode, "single_provider");
  assert.equal(rateRes.targetProviderName, "Permian Shield Specialty Insurance");

  // 5. User views their own rate applications
  const myApps = await commands.listMyInsuranceRateApplications({auth: memberAuth});
  assert.equal(myApps.applications.length, 1);
  assert.equal(myApps.applications[0].companyName, "Redwater Heavy Haul & Pipe LLC");

  // 6. Admin views dashboard & updates status to matching -> quoted
  const dash = await commands.listAdminInsuranceDashboard({auth: mfaAdminAuth});
  assert.equal(dash.counts.activeProviders, 1);
  assert.equal(dash.counts.totalRateApplications, 1);

  await commands.updateInsuranceRateApplicationStatus({
    auth: mfaAdminAuth,
    data: {
      applicationId: rateRes.applicationId,
      status: "matching",
      matchedProviderIds: [reviewRes.providerId],
      matchedProviderNames: ["Permian Shield Specialty Insurance"],
      brokerResponseNotes: "Underwriting submission dispatched to Permian Shield.",
    },
  });

  const quotedRes = await commands.updateInsuranceRateApplicationStatus({
    auth: mfaAdminAuth,
    data: {
      applicationId: rateRes.applicationId,
      status: "quoted",
      brokerResponseNotes: "Indicative annual fleet + cargo quote ready for review.",
    },
  });
  assert.equal(quotedRes.status, "quoted");

  // 7. Deactivating a provider via upsertInsuranceProvider removes it from public directory
  await commands.upsertInsuranceProvider({
    auth: mfaAdminAuth,
    data: {
      providerId: reviewRes.providerId,
      companyName: "Permian Shield Specialty Insurance",
      providerType: "carrier",
      licensedCountries: ["US"],
      licensedRegions: ["TX"],
      coverageLines: ["commercial_auto_fleet"],
      active: false,
    },
  });
  const afterDeactivate = await commands.listInsuranceProviders({data: {}});
  assert.equal(afterDeactivate.totalMatched, 0);
});

test("firestore.rules enforces server-only writes across all insurance_* collections", () => {
  const rulesPath = path.resolve(__dirname, "..", "..", "firestore.rules");
  const rules = fs.readFileSync(rulesPath, "utf8");

  for (const collectionName of [
    "insurance_public_providers",
    "insurance_providers",
    "insurance_provider_applications",
    "insurance_rate_applications",
    "insurance_audit_events",
  ]) {
    assert.match(
        rules,
        new RegExp(`match /${collectionName}/\\{[^}]+\\}[\\s\\S]*?allow write: if false;`),
        `Expected server-only write lock for ${collectionName}`,
    );
  }
});
