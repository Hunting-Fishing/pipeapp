"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createPaymentReadinessAdmin,
} = require("../payment_readiness_admin");

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
        if (write.kind === "create" && docs.has(write.ref.path)) {
          throw new Error("document already exists");
        }
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

function adminRequest() {
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
      confirmProduction: true,
      reason: "Activate audited Canadian small supplier billing state.",
      patch: {
        stripeMode: "production",
        stripeFeeBillingEnabled: true,
        stripeWebhookVerified: true,
        canadaGstHstSmallSupplier: true,
        stripeReconciliationReady: true,
      },
    },
  };
}

function validAssessment(overrides = {}) {
  return {
    revision: 3,
    worldwideAndAssociatedIncluded: true,
    thresholdCadMinor: 3000000,
    singleQuarterCadMinor: 500000,
    rollingFourQuarterCadMinor: 1200000,
    exceeded: false,
    requiresRegistrationReview: false,
    ...overrides,
  };
}

test("small supplier readiness cannot activate without audited assessment", async () => {
  const {firestore} = fakeAdmin();
  const commands = createPaymentReadinessAdmin({firestore});
  await assert.rejects(
      () => commands.setPaymentProviderReadiness(adminRequest()),
      (error) => error.code === "failed-precondition" &&
        /assessment_missing/.test(error.message),
  );
});

test("valid audited assessment revision is bound to readiness activation", async () => {
  const {firestore, db} = fakeAdmin({
    "tax_threshold_assessments/canada_gst_hst_current": validAssessment(),
  });
  const commands = createPaymentReadinessAdmin({firestore});
  const result = await commands.setPaymentProviderReadiness(adminRequest());
  assert.equal(result.readiness.canadaGstHstSmallSupplier, true);
  assert.equal(result.canadaGstHstSmallSupplierAssessmentRevision, 3);
  const readiness = db.docs.get(
      "platform_configuration/payment_provider_readiness",
  );
  assert.equal(readiness.canadaGstHstSmallSupplier, true);
  assert.equal(readiness.canadaGstHstSmallSupplierAssessmentRevision, 3);
  const audit = [...db.docs.entries()]
      .find(([path]) => path.startsWith("payment_readiness_audit/"));
  assert.ok(audit);
  assert.equal(audit[1].canadaGstHstSmallSupplierAssessmentRevision, 3);
});

test("exceeded threshold assessment blocks small supplier activation", async () => {
  const {firestore} = fakeAdmin({
    "tax_threshold_assessments/canada_gst_hst_current": validAssessment({
      rollingFourQuarterCadMinor: 3000001,
      exceeded: true,
      requiresRegistrationReview: true,
    }),
  });
  const commands = createPaymentReadinessAdmin({firestore});
  await assert.rejects(
      () => commands.setPaymentProviderReadiness(adminRequest()),
      (error) => error.code === "failed-precondition" &&
        /threshold_exceeded/.test(error.message),
  );
});
