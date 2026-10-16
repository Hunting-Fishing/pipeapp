"use strict";

function financialEpoch(sale = {}) {
  const value = Number(sale.financialEpoch || 0);
  return Number.isSafeInteger(value) && value >= 0 ? value : 0;
}

function financialMutationValues(sale = {}, values = {}, {hold = true} = {}) {
  const nextEpoch = financialEpoch(sale) + 1;
  const releaseStatus = String(sale.sellerPayoutStatus || "");
  const releaseWasActive = new Set([
    "release_processing",
    "release_reserved",
    "release_dispatching",
    "release_outcome_unknown",
  ]).has(releaseStatus);
  const releaseRequestMayHaveEscaped = new Set([
    "release_dispatching",
    "release_outcome_unknown",
  ]).has(releaseStatus);
  return {
    ...values,
    financialEpoch: nextEpoch,
    financialHold: hold === true,
    ...(releaseWasActive ? {
      sellerPayoutStatus: releaseRequestMayHaveEscaped ?
        "release_invalidated_attempt_unknown" : hold ?
          "blocked_financial_hold" : "pending_release",
      sellerReleaseInvalidatedByFinancialEpoch: nextEpoch,
    } : {}),
  };
}

async function mutateMarketplaceFinancialState({
  db,
  transactionRef,
  FieldValue,
  hold = true,
  values = {},
  buildValues = null,
}) {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(transactionRef);
    if (!snapshot.exists) return null;
    const sale = snapshot.data();
    const requestedValues = typeof buildValues === "function" ?
      buildValues(sale) : values;
    const patch = {
      ...financialMutationValues(sale, requestedValues, {hold}),
      updatedAt: FieldValue.serverTimestamp(),
    };
    transaction.set(transactionRef, patch, {merge: true});
    return {sale, patch};
  });
}

module.exports = {
  financialEpoch,
  financialMutationValues,
  mutateMarketplaceFinancialState,
};
