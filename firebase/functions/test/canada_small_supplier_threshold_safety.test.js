"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createCanadaSmallSupplierThresholdCommands,
  smallSupplierBillingSafetyDecision,
} = require("../canada_small_supplier_threshold_commands");

const FieldValue = {
  serverTimestamp() {
    return "server-time";
  },
};

function fakeAdmin(initial = {}) {
  const docs = new Map(Object.entries(initial));
  let generated = 0;
  const makeRef = (path) => ({path});
  const db = {
    docs,
    collection(name) {
      return {
        doc(id) {
          const resolved = id || `generated-${++generated}`;
          const ref = makeRef(`${name}/${resolved}`);
          ref.get = async () => {
            const value = docs.get(ref.path);
            return {exists: value != null, data: () => value};
          };
          return ref;
        },
      };
    },
    async runTransaction(callback) {
      const writes = [];
      const transaction = {
        async get(ref) {
          const value = docs.get(ref.path);
          return {exists: value != null, data: () => value};
        },
        set(ref, value, options) {
          writes.push({kind: "set", ref, value, options});
        },
        create(ref, value) {
          writes.push({kind: "create", ref, value});
        },
      };
      const result = await callback(transaction);
      for (const write of writes) {
        const current = docs.get(write.ref.path) || {};
        docs.set(
            write.ref.path,
            write.options && write.options.merge ?
              {...current, ...write.value} : write.value,
        );
      }
      return result;
    },
  };
  function firestore() {
    return db;
  }
  firestore.FieldValue = FieldValue;
  return {firestore, db};
}

function adminRequest({singleQuarter = 500000, rolling = 1200000} = {}) {
  return {
    auth: {
      uid: "admin-1",
      token: {
        admin: true,
        role: "administrator",
        firebase: {sign_in_second_factor: "phone"},
      },
    },
    data: {
      periodLabel: "2026 Q3",
      sourceNote:
        "Reviewed bookkeeping, worldwide taxable supplies, and associated-business totals.",
      worldwideAndAssociatedIncluded: true,
      singleQuarterCadMinor: singleQuarter,
      rollingFourQuarterCadMinor: rolling,
    },
  };
}

function activeSmallSupplierReadiness(overrides = {}) {
  return {
    stripeMode: "production",
    stripeFeeBillingEnabled: true,
    stripeSubscriptionsEnabled: true,
    stripeWebhookVerified: true,
    stripeReconciliationReady: true,
    canadaGstHstSmallSupplier: true,
    canadaGstHstSmallSupplierAssessmentRevision: 2,
    stripeTaxReady: false,
    stripeTaxRegistrationPending: false,
    revision: 7,
    ...overrides,
  };
}

function priorAssessment(overrides = {}) {
  return {
    revision: 2,
    periodLabel: "2026 Q2",
    sourceNote: "Previous audited bookkeeping and associated-business review.",
    worldwideAndAssociatedIncluded: true,
    thresholdCadMinor: 3000000,
    singleQuarterCadMinor: 400000,
    rollingFourQuarterCadMinor: 900000,
    governingAmountCadMinor: 900000,
    remainingCadMinor: 2100000,
    level: "within_threshold",
    exceeded: false,
    exceededSingleQuarter: false,
    exceededRolling: false,
    requiresRegistrationReview: false,
    ...overrides,
  };
}

test("safety decision refreshes active readiness below threshold and disables it above threshold", () => {
  const refreshed = smallSupplierBillingSafetyDecision({
    requiresRegistrationReview: false,
  }, activeSmallSupplierReadiness());
  assert.equal(refreshed.disableBilling, false);
  assert.equal(refreshed.refreshBinding, true);
  assert.equal(refreshed.reason, "small_supplier_assessment_refreshed");
  const inactive = smallSupplierBillingSafetyDecision({
    requiresRegistrationReview: true,
  }, {canadaGstHstSmallSupplier: false});
  assert.equal(inactive.disableBilling, false);
  assert.equal(inactive.refreshBinding, false);
  const exceeded = smallSupplierBillingSafetyDecision({
    requiresRegistrationReview: true,
  }, activeSmallSupplierReadiness());
  assert.equal(exceeded.disableBilling, true);
  assert.equal(exceeded.refreshBinding, false);
  assert.equal(exceeded.reason, "small_supplier_threshold_exceeded");
});

test("under-threshold reassessment preserves billing and binds readiness to the new assessment revision", async () => {
  const {firestore, db} = fakeAdmin({
    "tax_threshold_assessments/canada_gst_hst_current": priorAssessment(),
    "platform_configuration/payment_provider_readiness":
      activeSmallSupplierReadiness(),
  });
  const commands = createCanadaSmallSupplierThresholdCommands({firestore});
  const result = await commands.setCanadaGstHstThresholdAssessment(
      adminRequest(),
  );
  assert.equal(result.revision, 3);
  assert.equal(result.billingSafetyAction, "none");
  assert.equal(result.readinessBindingAction,
      "small_supplier_assessment_refreshed");
  assert.equal(result.readinessRevision, 8);
  const readiness = db.docs.get(
      "platform_configuration/payment_provider_readiness",
  );
  assert.equal(readiness.canadaGstHstSmallSupplier, true);
  assert.equal(readiness.canadaGstHstSmallSupplierAssessmentRevision, 3);
  assert.equal(readiness.stripeFeeBillingEnabled, true);
  assert.equal(readiness.stripeSubscriptionsEnabled, true);
  assert.equal(readiness.revision, 8);
  const audit = [...db.docs.entries()].find(([path]) =>
    path.startsWith("payment_readiness_audit/"));
  assert.ok(audit);
  assert.equal(audit[1].readinessBindingAction,
      "small_supplier_assessment_refreshed");
  assert.equal(audit[1].triggeringThresholdAssessmentRevision, 3);
});

test("exceeded assessment immediately disables small supplier fee and subscription billing", async () => {
  const {firestore, db} = fakeAdmin({
    "tax_threshold_assessments/canada_gst_hst_current": priorAssessment(),
    "platform_configuration/payment_provider_readiness":
      activeSmallSupplierReadiness(),
  });
  const commands = createCanadaSmallSupplierThresholdCommands({firestore});
  const result = await commands.setCanadaGstHstThresholdAssessment(
      adminRequest({rolling: 3000001}),
  );
  assert.equal(result.revision, 3);
  assert.equal(result.billingSafetyAction, "small_supplier_billing_disabled");
  assert.equal(result.readinessBindingAction, "none");
  assert.equal(result.readinessRevision, 8);
  const readiness = db.docs.get(
      "platform_configuration/payment_provider_readiness",
  );
  assert.equal(readiness.canadaGstHstSmallSupplier, false);
  assert.equal(readiness.canadaGstHstSmallSupplierAssessmentRevision, null);
  assert.equal(readiness.stripeFeeBillingEnabled, false);
  assert.equal(readiness.stripeSubscriptionsEnabled, false);
  assert.equal(readiness.stripeTaxReady, false);
  assert.equal(readiness.stripeTaxRegistrationPending, false);
  assert.equal(readiness.revision, 8);
  assert.match(readiness.lastChangeReason, /Automatic safety shutdown/i);
  const audit = [...db.docs.entries()].find(([path]) =>
    path.startsWith("payment_readiness_audit/"));
  assert.ok(audit);
  assert.equal(audit[1].automaticSafetyAction,
      "small_supplier_threshold_exceeded");
  assert.equal(audit[1].triggeringThresholdAssessmentRevision, 3);
});

test("exceeded assessment does not rewrite registered tax readiness when small supplier is inactive", async () => {
  const registered = activeSmallSupplierReadiness({
    canadaGstHstSmallSupplier: false,
    canadaGstHstSmallSupplierAssessmentRevision: null,
    stripeTaxReady: true,
    stripeFeeBillingEnabled: true,
    stripeSubscriptionsEnabled: true,
  });
  const {firestore, db} = fakeAdmin({
    "tax_threshold_assessments/canada_gst_hst_current": priorAssessment(),
    "platform_configuration/payment_provider_readiness": registered,
  });
  const commands = createCanadaSmallSupplierThresholdCommands({firestore});
  const result = await commands.setCanadaGstHstThresholdAssessment(
      adminRequest({singleQuarter: 3000001}),
  );
  assert.equal(result.revision, 3);
  assert.equal(result.billingSafetyAction, "none");
  assert.equal(result.readinessBindingAction, "none");
  assert.equal(result.readinessRevision, null);
  const readiness = db.docs.get(
      "platform_configuration/payment_provider_readiness",
  );
  assert.equal(readiness.stripeTaxReady, true);
  assert.equal(readiness.stripeFeeBillingEnabled, true);
  assert.equal(readiness.stripeSubscriptionsEnabled, true);
  assert.equal(readiness.revision, 7);
});
