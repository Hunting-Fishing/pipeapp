from pathlib import Path
import re

PATH = Path("firebase/functions/marketplace_financial_resolution.js")
text = PATH.read_text()


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected one financial-resolution target; found {count}: {old[:80]!r}")
    text = text.replace(old, new, 1)


def replace_between(start_pattern: str, end_pattern: str, replacement: str) -> None:
    global text
    pattern = re.compile(start_pattern + r".*?(?=" + end_pattern + r")", re.S)
    next_text, count = pattern.subn(replacement, text, count=1)
    if count != 1:
        raise SystemExit(f"Expected one function block for {start_pattern!r}; found {count}")
    text = next_text


replace_once(
    '''const {\n  createMarketplaceSellerFunds,\n  proportionalRecoveryTarget,\n} = require("./marketplace_seller_funds");''',
    '''const {\n  createMarketplaceSellerFunds,\n  proportionalRecoveryTarget,\n  uniqueSellerTransferIds,\n} = require("./marketplace_seller_funds");\nconst {\n  aggregateChargeState,\n  allocateRefundAcrossCharges,\n  marketplaceChargeIds,\n} = require("./marketplace_multi_charge_policy");''',
)

replace_once(
    '''      financialResolutionEnabled:\n        data.marketplaceFinancialResolutionEnabled === true,\n      disputeAutomationEnabled:''',
    '''      financialResolutionEnabled:\n        data.marketplaceFinancialResolutionEnabled === true,\n      refundAutomationEnabled:\n        data.marketplaceRefundAutomationEnabled === true,\n      disputeAutomationEnabled:''',
)

new_find_and_helpers = r'''  async function findTransactionForCharge(chargeId) {
    if (!isStripeChargeId(chargeId)) return null;
    const saleQuery = await db.collection("marketplace_transactions")
        .where("stripeChargeId", "==", chargeId)
        .limit(2)
        .get();
    if (!saleQuery.empty) {
      const document = saleQuery.docs[0];
      return {
        id: document.id,
        ref: document.ref,
        sale: document.data(),
        billingType: "marketplace_sale",
      };
    }
    const splitQuery = await db.collection("marketplace_transactions")
        .where("stripeChargeIds", "array-contains", chargeId)
        .limit(2)
        .get();
    if (!splitQuery.empty) {
      const document = splitQuery.docs[0];
      return {
        id: document.id,
        ref: document.ref,
        sale: document.data(),
        billingType: "marketplace_sale",
      };
    }
    const feeQuery = await db.collection("marketplace_transactions")
        .where("stripeMarketplaceFeeChargeId", "==", chargeId)
        .limit(2)
        .get();
    if (feeQuery.empty) return null;
    const document = feeQuery.docs[0];
    return {
      id: document.id,
      ref: document.ref,
      sale: document.data(),
      billingType: "marketplace_fee_only",
    };
  }

  async function loadStripeChargeStates(sale) {
    const ids = marketplaceChargeIds(sale);
    if (ids.length === 0) {
      throw new HttpsError(
          "failed-precondition",
          "The Pipe Buyer Stripe charge ledger is unavailable.",
      );
    }
    const states = [];
    for (const id of ids) {
      const charge = await stripeFinancialRequest({
        secretKey: stripeSecretKey.value(),
        path: `/v1/charges/${encodeURIComponent(id)}`,
        method: "GET",
      });
      const amountMinor = Number(charge.amount || 0);
      const refundedMinor = Number(charge.amount_refunded || 0);
      if (!Number.isSafeInteger(amountMinor) || amountMinor <= 0 ||
          !Number.isSafeInteger(refundedMinor) || refundedMinor < 0 ||
          refundedMinor > amountMinor) {
        throw new HttpsError(
            "failed-precondition",
            "Stripe returned an invalid marketplace charge balance.",
        );
      }
      states.push({id, amountMinor, refundedMinor, raw: charge});
    }
    return states;
  }

  async function syncPaymentPartRefundState(transactionRef, chargeState) {
    const chargeId = String(chargeState && chargeState.id || "");
    if (!chargeId) return;
    for (const partId of ["deposit", "balance"]) {
      const ref = transactionRef.collection("payment_parts").doc(partId);
      const snapshot = await ref.get();
      if (!snapshot.exists || String(snapshot.data().stripeChargeId || "") !== chargeId) {
        continue;
      }
      const refundedMinor = Math.max(0, Number(chargeState.refundedMinor || 0));
      const amountMinor = Math.max(0, Number(chargeState.amountMinor || 0));
      await ref.set({
        refundedMinor,
        status: refundedMinor >= amountMinor && amountMinor > 0 ?
          "refunded" : refundedMinor > 0 ? "partially_refunded" : snapshot.data().status,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return;
    }
  }

  async function syncPaymentPartDisputeState({
    transactionRef,
    chargeId,
    disputeAmountMinor,
    outcome,
  }) {
    for (const partId of ["deposit", "balance"]) {
      const ref = transactionRef.collection("payment_parts").doc(partId);
      const snapshot = await ref.get();
      if (!snapshot.exists || String(snapshot.data().stripeChargeId || "") !== chargeId) {
        continue;
      }
      await ref.set({
        disputedMinor: outcome === "won" || outcome === "warning_closed" ?
          0 : Math.max(0, Number(disputeAmountMinor || 0)),
        disputeStatus: outcome,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return;
    }
  }

  async function rebalanceSellerFundsIfReleased(values) {
    if (uniqueSellerTransferIds(values.sale).length === 0) {
      return {
        desiredNetMinor: 0,
        actualNetMinor: 0,
        outstandingRecoveryMinor: 0,
        outstandingRestorationMinor: 0,
        reversalIds: [],
        restorationTransferId: null,
        restorationMinor: 0,
        failures: [],
      };
    }
    return sellerFunds.rebalanceSellerFunds(values);
  }

'''
replace_between(
    r"  async function findTransactionForCharge\(chargeId\) \{",
    r"  async function disputeCases\(transactionId\) \{",
    new_find_and_helpers,
)

replace_once(
    '''      if (!isStripeChargeId(sale.stripeChargeId)) {\n        throw new HttpsError(\n            "failed-precondition",\n            "This transaction was not paid through Pipe Buyer Stripe Checkout.",\n        );\n      }''',
    '''      if (marketplaceChargeIds(sale).length === 0) {\n        throw new HttpsError(\n            "failed-precondition",\n            "This transaction was not paid through Pipe Buyer Stripe Checkout.",\n        );\n      }''',
)

replace_once(
    '''        reason,\n        status: "requested",\n        createdAt: FieldValue.serverTimestamp(),''',
    '''        reason,\n        requesterRole: uid === String(sale.buyerUid || "") ? "buyer" : "seller",\n        buyerApproved: uid === String(sale.buyerUid || ""),\n        sellerApproved: uid === String(sale.sellerUid || "") &&\n          uid !== String(sale.buyerUid || ""),\n        status: "awaiting_counterparty",\n        createdAt: FieldValue.serverTimestamp(),''',
)
replace_once(
    '''      await transactionRef.set({\n        financialStatus: "refund_requested",\n        activeFinancialCaseId: requestId,\n        updatedAt: FieldValue.serverTimestamp(),\n      }, {merge: true});''',
    '''      await transactionRef.set({\n        financialStatus: "refund_requested",\n        financialHold: true,\n        activeFinancialCaseId: requestId,\n        refundRequestCaseId: requestId,\n        refundRequestStatus: "awaiting_counterparty",\n        refundRequestedMinor: requestedAmount,\n        refundRequestedByUid: uid,\n        refundRequestReason: reason.slice(0, 500),\n        updatedAt: FieldValue.serverTimestamp(),\n      }, {merge: true});''',
)
replace_once(
    '''        status: "requested",\n        alreadyCreated: false,''',
    '''        status: "awaiting_counterparty",\n        alreadyCreated: false,''',
)

replace_once(
    '''      if (financialCase.status !== "requested") {''',
    '''      if (financialCase.status !== "awaiting_counterparty") {''',
)
replace_once(
    '''        await db.collection("marketplace_transactions").doc(transactionId).set({\n          activeFinancialCaseId: null,\n          updatedAt: FieldValue.serverTimestamp(),\n        }, {merge: true});''',
    '''        await db.collection("marketplace_transactions").doc(transactionId).set({\n          activeFinancialCaseId: null,\n          refundRequestStatus: "cancelled",\n          financialStatus: "refund_request_cancelled",\n          financialHold: false,\n          updatedAt: FieldValue.serverTimestamp(),\n        }, {merge: true});''',
)

new_refund_execution = r'''  async function executeRefundCase({
    caseId,
    approvedByUid,
    refundReasonCodeValue,
    allowPlatformFunding = false,
    automated = false,
  }) {
    const readiness = await loadReadiness();
    requireResolutionReady(readiness);
    if (automated && readiness.refundAutomationEnabled !== true) {
      throw new HttpsError(
          "failed-precondition",
          "Mutually approved automatic refunds are not enabled yet.",
      );
    }
    if (automated && allowPlatformFunding) {
      throw new HttpsError(
          "failed-precondition",
          "Automatic refunds can never use Pipe Buyer platform funds.",
      );
    }
    if (allowPlatformFunding && !readiness.platformFundedRefundOverrideEnabled) {
      throw new HttpsError(
          "failed-precondition",
          "Platform-funded refund overrides are disabled.",
      );
    }

    const caseRef = db.collection("marketplace_financial_cases").doc(caseId);
    const caseSnapshot = await caseRef.get();
    if (!caseSnapshot.exists) throw new HttpsError("not-found", "Refund request not found.");
    const financialCase = caseSnapshot.data();
    if (financialCase.type !== "refund_request") {
      throw new HttpsError("failed-precondition", "This case is not a refund request.");
    }
    if (["succeeded", "pending"].includes(String(financialCase.refundStatus || ""))) {
      return {
        caseId,
        transactionId: financialCase.transactionId,
        refundId: financialCase.stripeRefundId || null,
        refundIds: Array.isArray(financialCase.stripeRefundIds) ?
          financialCase.stripeRefundIds : [],
        status: financialCase.refundStatus,
        alreadyExecuted: true,
      };
    }
    if (automated && !(financialCase.buyerApproved === true &&
        financialCase.sellerApproved === true)) {
      throw new HttpsError(
          "failed-precondition",
          "Both transaction parties must approve the exact refund before automatic execution.",
      );
    }
    if (!["requested", "awaiting_counterparty", "approved_processing",
      "blocked_seller_recovery", "refund_retry_required"]
        .includes(String(financialCase.status || ""))) {
      throw new HttpsError(
          "failed-precondition",
          "This refund request is not eligible for execution.",
      );
    }

    const transactionId = String(financialCase.transactionId || "");
    const transactionRef = db.collection("marketplace_transactions").doc(transactionId);
    const saleSnapshot = await transactionRef.get();
    if (!saleSnapshot.exists) throw new HttpsError("not-found", "Transaction not found.");
    const sale = saleSnapshot.data();
    const currentExposure = await exposureSnapshot(transactionId, sale);
    if (currentExposure.activeDisputeIds.length > 0) {
      throw new HttpsError(
          "failed-precondition",
          "Do not issue a refund while a cardholder dispute is open.",
      );
    }

    const requested = Number(financialCase.requestedRefundMinor || 0);
    if (!Number.isSafeInteger(requested) || requested <= 0) {
      throw new HttpsError("failed-precondition", "The refund amount is invalid.");
    }
    let chargeStates = await loadStripeChargeStates(sale);
    let aggregate = aggregateChargeState(chargeStates);
    let allocations = Array.isArray(financialCase.refundAllocations) ?
      financialCase.refundAllocations.map((item) => ({
        chargeId: String(item && item.chargeId || ""),
        amountMinor: Number(item && item.amountMinor || 0),
      })) : [];
    let refundTargetMinor = Number(financialCase.refundTargetMinor || 0);
    if (allocations.length === 0) {
      if (requested > aggregate.refundableMinor) {
        throw new HttpsError(
            "failed-precondition",
            "The requested refund exceeds Stripe's remaining refundable balance.",
        );
      }
      allocations = allocateRefundAcrossCharges(requested, chargeStates);
      refundTargetMinor = aggregate.refundedMinor + requested;
      await caseRef.set({
        refundAllocations: allocations,
        refundBaseMinor: aggregate.refundedMinor,
        refundTargetMinor,
        status: "approved_processing",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    } else {
      const allocated = allocations.reduce(
          (total, item) => total + Number(item.amountMinor || 0), 0);
      if (allocated !== requested || !Number.isSafeInteger(refundTargetMinor) ||
          refundTargetMinor <= 0) {
        throw new HttpsError(
            "failed-precondition",
            "The stored refund allocation is invalid and requires financial review.",
        );
      }
    }

    const projectedExposure = Math.min(
        aggregate.chargedMinor,
        refundTargetMinor + currentExposure.disputeExposureMinor,
    );
    const recovery = await rebalanceSellerFundsIfReleased({
      transactionId,
      sale: {...sale, buyerChargedMinor: aggregate.chargedMinor},
      caseId,
      customerExposureMinor: projectedExposure,
      reason: automated ? "mutually_approved_refund" : "approved_refund",
      allowRestoration: false,
    });
    if (recovery.outstandingRecoveryMinor > 0 && !allowPlatformFunding) {
      await caseRef.set({
        status: "blocked_seller_recovery",
        sellerRecoveryOutstandingMinor: recovery.outstandingRecoveryMinor,
        sellerRecoveryFailures: recovery.failures.slice(0, 10),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await transactionRef.set({
        refundRequestStatus: "blocked_seller_recovery",
        financialHold: true,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      throw new HttpsError(
          "failed-precondition",
          "Seller proceeds could not be recovered. The refund is safely blocked for review.",
      );
    }

    const refunds = [];
    try {
      for (const allocation of allocations) {
        const refund = await stripeFinancialRequest({
          secretKey: stripeSecretKey.value(),
          path: "/v1/refunds",
          idempotencyKey:
            `pipebuyer-refund-${caseId}-${allocation.chargeId}`,
          fields: {
            charge: allocation.chargeId,
            amount: allocation.amountMinor,
            reason: refundReasonCode(refundReasonCodeValue),
            "metadata[pipeBuyerTransactionId]": transactionId,
            "metadata[pipeBuyerFinancialCaseId]": caseId,
            "metadata[approvedByUid]": approvedByUid,
            "metadata[automatedMutualApproval]": automated ? "true" : "false",
          },
        });
        refunds.push(refund);
      }
    } catch (error) {
      await caseRef.set({
        status: "refund_retry_required",
        sellerRecoveryCompletedBeforeRefund:
          recovery.outstandingRecoveryMinor === 0,
        refundProviderErrorCode: String(error.stripeCode || "provider_error"),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await transactionRef.set({
        refundRequestStatus: "refund_retry_required",
        financialHold: true,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      throw error;
    }

    chargeStates = await loadStripeChargeStates(sale);
    aggregate = aggregateChargeState(chargeStates);
    for (const state of chargeStates) {
      await syncPaymentPartRefundState(transactionRef, state);
    }
    const allSucceeded = refunds.length === allocations.length &&
      refunds.every((refund) => String(refund.status || "") === "succeeded") &&
      aggregate.refundedMinor >= refundTargetMinor;
    const refundStatus = allSucceeded ? "succeeded" : "pending";
    const refundIds = refunds.map((refund) => String(refund.id || ""))
        .filter((id) => id.startsWith("re_"));

    await caseRef.set({
      status: allSucceeded ? "completed" : "refund_pending",
      refundStatus,
      stripeRefundId: refundIds[0] || null,
      stripeRefundIds: refundIds,
      approvedByUid,
      approvedAt: FieldValue.serverTimestamp(),
      automatedMutualApproval: automated,
      sellerRecoveryOutstandingMinor: recovery.outstandingRecoveryMinor,
      platformFundedOverrideUsed:
        allowPlatformFunding && recovery.outstandingRecoveryMinor > 0,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    if (allSucceeded) {
      await transactionRef.set({
        buyerChargedMinor: aggregate.chargedMinor,
        refundedMinor: aggregate.refundedMinor,
        paymentProviderStatus: aggregate.refundedMinor >= aggregate.chargedMinor ?
          "refunded" : "partially_refunded",
        refundRequestStatus: "succeeded",
        financialHold: false,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await syncTransactionFinancialState({
        transactionId,
        sale: {
          ...sale,
          buyerChargedMinor: aggregate.chargedMinor,
          refundedMinor: aggregate.refundedMinor,
        },
      });
    } else {
      await transactionRef.set({
        refundRequestStatus: "pending",
        financialStatus: "refund_pending",
        financialHold: true,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    await createFinancialEvent({
      transactionId,
      sale,
      caseId,
      type: automated ? "refund_auto_executed" : "refund_executed",
      values: {
        actorUid: approvedByUid,
        amountMinor: requested,
        stripeRefundIds: refundIds,
        refundStatus,
        sellerRecoveryOutstandingMinor: recovery.outstandingRecoveryMinor,
      },
    });
    return {
      caseId,
      transactionId,
      refundId: refundIds[0] || null,
      refundIds,
      status: refundStatus,
      sellerRecoveryOutstandingMinor: recovery.outstandingRecoveryMinor,
      platformFundedOverrideUsed:
        allowPlatformFunding && recovery.outstandingRecoveryMinor > 0,
      alreadyExecuted: false,
    };
  }

  async function approveMarketplaceRefundRequest(request) {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "offers"});
      const readiness = await loadReadiness();
      requireResolutionReady(readiness);
      if (readiness.refundAutomationEnabled !== true) {
        throw new HttpsError(
            "failed-precondition",
            "Mutually approved automatic refunds are not enabled yet.",
        );
      }
      const caseId = cleanId(request.data && request.data.caseId, "caseId");
      const caseRef = db.collection("marketplace_financial_cases").doc(caseId);
      const snapshot = await caseRef.get();
      if (!snapshot.exists || snapshot.data().type !== "refund_request") {
        throw new HttpsError("not-found", "Refund request not found.");
      }
      const financialCase = snapshot.data();
      const transactionId = String(financialCase.transactionId || "");
      const transactionRef = db.collection("marketplace_transactions").doc(transactionId);
      const saleSnapshot = await transactionRef.get();
      if (!saleSnapshot.exists) throw new HttpsError("not-found", "Transaction not found.");
      const sale = saleSnapshot.data();
      if (!isParticipant(sale, uid)) {
        throw new HttpsError(
            "permission-denied",
            "Only the buyer or seller can approve this refund.",
        );
      }
      if (uid === String(financialCase.requestedByUid || "") &&
          !(financialCase.buyerApproved === true && financialCase.sellerApproved === true)) {
        throw new HttpsError(
            "failed-precondition",
            "The other transaction party must approve this refund request.",
        );
      }
      if (financialCase.status === "cancelled") {
        throw new HttpsError("failed-precondition", "This refund request was cancelled.");
      }
      const buyerApproved = financialCase.buyerApproved === true ||
        uid === String(sale.buyerUid || "");
      const sellerApproved = financialCase.sellerApproved === true ||
        uid === String(sale.sellerUid || "");
      if (!buyerApproved || !sellerApproved) {
        throw new HttpsError(
            "failed-precondition",
            "Both transaction parties must approve this exact refund amount.",
        );
      }
      await caseRef.set({
        buyerApproved,
        sellerApproved,
        counterpartyApprovedByUid: uid,
        counterpartyApprovedAt: FieldValue.serverTimestamp(),
        status: "approved_processing",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await transactionRef.set({
        refundRequestStatus: "approved_processing",
        financialHold: true,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return executeRefundCase({
        caseId,
        approvedByUid: uid,
        refundReasonCodeValue: "requested_by_customer",
        allowPlatformFunding: false,
        automated: true,
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Mutually approved marketplace refund failed", {
        stripeCode: error && error.stripeCode || null,
        error,
      });
      throw new HttpsError(
          "failed-precondition",
          "The approved refund could not be completed safely. No platform-funded override was used.",
      );
    }
  }

  async function executeMarketplaceRefund(request) {
    let administratorUid = null;
    try {
      administratorUid = requireAdministrator(request);
      await enforceUserRateLimit({db, admin, request, scope: "administration"});
      const caseId = cleanId(request.data && request.data.caseId, "caseId");
      return await executeRefundCase({
        caseId,
        approvedByUid: administratorUid,
        refundReasonCodeValue:
          request.data && request.data.refundReasonCode,
        allowPlatformFunding:
          request.data && request.data.allowPlatformFunding === true,
        automated: false,
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError ||
          error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Marketplace refund execution failed", {
        administratorUid,
        stripeCode: error && error.stripeCode || null,
        error,
      });
      throw new HttpsError(
          "failed-precondition",
          "The refund could not be completed safely. Review the financial case before retrying.",
      );
    }
  }

'''
replace_between(
    r"  async function executeMarketplaceRefund\(request\) \{",
    r"  async function reconcileChargeRefund\(charge\) \{",
    new_refund_execution,
)

new_reconcile = r'''  async function reconcileChargeRefund(charge) {
    const chargeId = String(charge && charge.id || "");
    const match = await findTransactionForCharge(chargeId);
    if (!match) return null;
    const {id: transactionId, ref: transactionRef, sale, billingType} = match;
    const refundedForCharge = Math.max(0, Number(charge.amount_refunded || 0));
    if (billingType === "marketplace_fee_only") {
      await transactionRef.set({
        marketplaceFeeStatus: charge.refunded ? "refunded" : "partially_refunded",
        marketplaceFeeRefundedMinor: refundedForCharge,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {transactionId, billingType};
    }

    const chargeStates = await loadStripeChargeStates(sale);
    const aggregate = aggregateChargeState(chargeStates);
    for (const state of chargeStates) {
      await syncPaymentPartRefundState(transactionRef, state);
    }
    if (aggregate.refundedMinor <= 0) return {transactionId, billingType};
    await transactionRef.set({
      buyerChargedMinor: aggregate.chargedMinor,
      refundedMinor: aggregate.refundedMinor,
      paymentProviderStatus: aggregate.refundedMinor >= aggregate.chargedMinor ?
        "refunded" : "partially_refunded",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    const updatedSale = {
      ...sale,
      buyerChargedMinor: aggregate.chargedMinor,
      refundedMinor: aggregate.refundedMinor,
    };
    const exposure = await exposureSnapshot(transactionId, updatedSale);
    const caseId = `stripe_refund_${chargeId}_${refundedForCharge}`;
    const recovery = await rebalanceSellerFundsIfReleased({
      transactionId,
      sale: updatedSale,
      caseId,
      customerExposureMinor: exposure.customerExposureMinor,
      reason: "stripe_refund_reconciliation",
      allowRestoration: false,
    });
    await db.collection("marketplace_financial_cases").doc(caseId).set({
      type: "stripe_refund_reconciliation",
      transactionId,
      listingId: String(sale.listingId || ""),
      buyerUid: String(sale.buyerUid || ""),
      sellerUid: String(sale.sellerUid || ""),
      currency: String(sale.currency || "CAD").toUpperCase(),
      stripeChargeId: chargeId,
      chargeRefundedMinor: refundedForCharge,
      refundedMinor: aggregate.refundedMinor,
      status: recovery.outstandingRecoveryMinor > 0 ?
        "seller_recovery_required" : "completed",
      sellerRecoveryOutstandingMinor: recovery.outstandingRecoveryMinor,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await syncTransactionFinancialState({transactionId, sale: updatedSale});
    return {transactionId, billingType, caseId};
  }

'''
replace_between(
    r"  async function reconcileChargeRefund\(charge\) \{",
    r"  async function handleRefundStatusEvent\(refund, eventType\) \{",
    new_reconcile,
)

replace_once(
    '''    await caseRef.set({\n      type: "stripe_dispute",''',
    '''    await caseRef.set({\n      type: "stripe_dispute",''',
)
# Insert payment-part dispute state immediately after the dispute case write.
needle = '''    }, {merge: true});\n\n    const exposure = await exposureSnapshot(transactionId, sale);'''
replacement = '''    }, {merge: true});\n    await syncPaymentPartDisputeState({\n      transactionRef,\n      chargeId,\n      disputeAmountMinor: Math.max(0, Number(dispute.amount || 0)),\n      outcome,\n    });\n\n    const exposure = await exposureSnapshot(transactionId, sale);'''
# There are multiple `}, {merge: true});` blocks before exposure in the file;
# anchor on the exact exposure line and replace the first occurrence before it.
count = text.count(needle)
if count != 1:
    raise SystemExit(f"Expected one dispute exposure insertion point; found {count}")
text = text.replace(needle, replacement, 1)

replace_once(
    '''      rebalance = await sellerFunds.rebalanceSellerFunds({\n        transactionId,\n        sale,\n        caseId,\n        customerExposureMinor: exposure.customerExposureMinor,\n        reason: outcome === "won" || outcome === "warning_closed" ?\n          "dispute_closed_restoration" : "stripe_dispute",\n        allowRestoration: outcome === "won" || outcome === "warning_closed",\n      });''',
    '''      rebalance = await rebalanceSellerFundsIfReleased({\n        transactionId,\n        sale,\n        caseId,\n        customerExposureMinor: exposure.customerExposureMinor,\n        reason: outcome === "won" || outcome === "warning_closed" ?\n          "dispute_closed_restoration" : "stripe_dispute",\n        allowRestoration: outcome === "won" || outcome === "warning_closed",\n      });''',
)

replace_once(
    '''  return {\n    cancelMarketplaceRefundRequest,\n    executeMarketplaceRefund,''',
    '''  return {\n    approveMarketplaceRefundRequest,\n    cancelMarketplaceRefundRequest,\n    executeMarketplaceRefund,''',
)

PATH.write_text(text)
print("Refund automation and multi-charge financial resolution patches applied.")
