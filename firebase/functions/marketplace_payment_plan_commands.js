"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  PaymentPlanPolicyError,
  validateDepositApproval,
  validateDepositDecline,
  validateDepositProposal,
} = require("./marketplace_payment_plan_policy");

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function cleanId(value, field) {
  const id = String(value || "").trim();
  if (!id || id.length > 180 || id.includes("/")) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return id;
}

function commandError(error) {
  if (error instanceof HttpsError) return error;
  if (error instanceof AccountSecurityError || error instanceof PaymentPlanPolicyError) {
    return new HttpsError(error.code, error.message);
  }
  console.error("Marketplace payment-plan command failed", error);
  return new HttpsError("internal", "Payment terms could not be updated.");
}

function createMarketplacePaymentPlanCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  function receiptRef(requestId) {
    return db.collection("marketplace_payment_plan_receipts").doc(requestId);
  }

  async function proposeMarketplaceDepositPlan(request) {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "offers"});
      const transactionId = cleanId(request.data && request.data.transactionId, "transactionId");
      const requestId = cleanId(request.data && request.data.requestId, "requestId");
      const depositAmountMinor = Number(request.data && request.data.depositAmountMinor);
      const saleRef = db.collection("marketplace_transactions").doc(transactionId);
      const commandRef = receiptRef(requestId);
      return await db.runTransaction(async (transaction) => {
        const [saleSnapshot, receiptSnapshot] = await Promise.all([
          transaction.get(saleRef),
          transaction.get(commandRef),
        ]);
        if (receiptSnapshot.exists) {
          const receipt = receiptSnapshot.data();
          if (receipt.actorUid !== uid || receipt.transactionId !== transactionId ||
              receipt.command !== "propose_deposit") {
            throw new HttpsError("already-exists", "This request ID is already in use.");
          }
          return {...receipt.result, alreadyApplied: true};
        }
        const sale = saleSnapshot.exists ? saleSnapshot.data() : null;
        const proposal = validateDepositProposal({sale, actorUid: uid, depositAmountMinor});
        const proposalValues = {
          paymentPlan: proposal.paymentPlan,
          paymentRequiredMinor: proposal.paymentRequiredMinor,
          depositAmountMinor: proposal.depositAmountMinor,
          balanceAmountMinor: proposal.balanceAmountMinor,
          buyerApproved: proposal.buyerApproved,
          sellerApproved: proposal.sellerApproved,
          proposedByUid: uid,
          status: proposal.status,
          proposedAt: FieldValue.serverTimestamp(),
        };
        const result = {
          transactionId,
          proposalRevision: proposal.proposalRevision,
          depositAmountMinor: proposal.depositAmountMinor,
          balanceAmountMinor: proposal.balanceAmountMinor,
          status: proposal.status,
        };
        transaction.update(saleRef, {
          paymentPlanStatus: "proposal_pending",
          paymentPlanProposal: proposalValues,
          paymentPlanProposalRevision: proposal.proposalRevision,
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.create(
            saleRef.collection("payment_plan_revisions")
                .doc(String(proposal.proposalRevision)),
            {
              event: "deposit_proposed",
              actorUid: uid,
              ...proposalValues,
              revision: proposal.proposalRevision,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
        const recipientUid = proposal.actorRole === "buyer" ?
          String(sale.sellerUid || "") : String(sale.buyerUid || "");
        if (recipientUid) {
          transaction.set(
              db.collection("users").doc(recipientUid)
                  .collection("notifications").doc(requestId),
              {
                recipientUid,
                actorUid: uid,
                type: "transaction_payment_terms",
                transactionId,
                listingId: String(sale.listingId || ""),
                title: "Deposit payment terms need your approval",
                read: false,
                createdAt: FieldValue.serverTimestamp(),
              },
          );
        }
        transaction.create(commandRef, {
          actorUid: uid,
          transactionId,
          command: "propose_deposit",
          result,
          createdAt: FieldValue.serverTimestamp(),
        });
        return {...result, alreadyApplied: false};
      });
    } catch (error) {
      throw commandError(error);
    }
  }

  async function approveMarketplaceDepositPlan(request) {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "offers"});
      const transactionId = cleanId(request.data && request.data.transactionId, "transactionId");
      const requestId = cleanId(request.data && request.data.requestId, "requestId");
      const expectedRevision = Number(request.data && request.data.expectedRevision);
      const saleRef = db.collection("marketplace_transactions").doc(transactionId);
      const commandRef = receiptRef(requestId);
      return await db.runTransaction(async (transaction) => {
        const [saleSnapshot, receiptSnapshot] = await Promise.all([
          transaction.get(saleRef),
          transaction.get(commandRef),
        ]);
        if (receiptSnapshot.exists) {
          const receipt = receiptSnapshot.data();
          if (receipt.actorUid !== uid || receipt.transactionId !== transactionId ||
              receipt.command !== "approve_deposit") {
            throw new HttpsError("already-exists", "This request ID is already in use.");
          }
          return {...receipt.result, alreadyApplied: true};
        }
        const sale = saleSnapshot.exists ? saleSnapshot.data() : null;
        const approval = validateDepositApproval({
          sale,
          actorUid: uid,
          expectedRevision,
        });
        const nextProposal = {
          ...sale.paymentPlanProposal,
          buyerApproved: approval.buyerApproved,
          sellerApproved: approval.sellerApproved,
          status: approval.activate ? "approved" : "pending_counterparty",
          updatedAt: FieldValue.serverTimestamp(),
        };
        const result = {
          transactionId,
          proposalRevision: approval.proposalRevision,
          paymentPlan: approval.paymentPlan,
          depositAmountMinor: approval.depositAmountMinor,
          balanceAmountMinor: approval.balanceAmountMinor,
          active: approval.activate,
        };
        transaction.update(saleRef, {
          paymentPlanProposal: nextProposal,
          ...(approval.activate ? {
            paymentPlan: "deposit_balance",
            paymentPlanStatus: "active",
            paymentRequiredMinor: approval.paymentRequiredMinor,
            depositAmountMinor: approval.depositAmountMinor,
            balanceAmountMinor: approval.balanceAmountMinor,
            amountPaidMinor: 0,
            balanceRemainingMinor: approval.paymentRequiredMinor,
            paymentProviderStatus: "pending_payment",
            paymentPlanActivatedAt: FieldValue.serverTimestamp(),
          } : {}),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.create(
            saleRef.collection("payment_plan_revisions")
                .doc(`${approval.proposalRevision}_approval_${approval.actorRole}`),
            {
              event: approval.activate ? "deposit_plan_activated" : "deposit_approved",
              actorUid: uid,
              buyerApproved: approval.buyerApproved,
              sellerApproved: approval.sellerApproved,
              depositAmountMinor: approval.depositAmountMinor,
              balanceAmountMinor: approval.balanceAmountMinor,
              revision: approval.proposalRevision,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
        if (approval.activate) {
          const currency = String(sale.currency || "CAD").toUpperCase();
          transaction.create(saleRef.collection("payment_parts").doc("deposit"), {
            partId: "deposit",
            sequence: 1,
            amountMinor: approval.depositAmountMinor,
            currency,
            status: "pending",
            refundedMinor: 0,
            disputedMinor: 0,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
          transaction.create(saleRef.collection("payment_parts").doc("balance"), {
            partId: "balance",
            sequence: 2,
            amountMinor: approval.balanceAmountMinor,
            currency,
            status: "blocked_until_deposit_paid",
            refundedMinor: 0,
            disputedMinor: 0,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        transaction.create(commandRef, {
          actorUid: uid,
          transactionId,
          command: "approve_deposit",
          result,
          createdAt: FieldValue.serverTimestamp(),
        });
        return {...result, alreadyApplied: false};
      });
    } catch (error) {
      throw commandError(error);
    }
  }

  async function declineMarketplaceDepositPlan(request) {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "offers"});
      const transactionId = cleanId(request.data && request.data.transactionId, "transactionId");
      const requestId = cleanId(request.data && request.data.requestId, "requestId");
      const expectedRevision = Number(request.data && request.data.expectedRevision);
      const saleRef = db.collection("marketplace_transactions").doc(transactionId);
      const commandRef = receiptRef(requestId);
      return await db.runTransaction(async (transaction) => {
        const [saleSnapshot, receiptSnapshot] = await Promise.all([
          transaction.get(saleRef),
          transaction.get(commandRef),
        ]);
        if (receiptSnapshot.exists) {
          const receipt = receiptSnapshot.data();
          if (receipt.actorUid !== uid || receipt.transactionId !== transactionId ||
              receipt.command !== "decline_deposit") {
            throw new HttpsError("already-exists", "This request ID is already in use.");
          }
          return {...receipt.result, alreadyApplied: true};
        }
        const sale = saleSnapshot.exists ? saleSnapshot.data() : null;
        const decline = validateDepositDecline({
          sale,
          actorUid: uid,
          expectedRevision,
        });
        const result = {
          transactionId,
          proposalRevision: decline.proposalRevision,
          status: decline.status,
        };
        transaction.update(saleRef, {
          paymentPlanStatus: "full_payment_default",
          "paymentPlanProposal.status": "declined",
          "paymentPlanProposal.declinedByUid": uid,
          "paymentPlanProposal.declinedAt": FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.create(
            saleRef.collection("payment_plan_revisions")
                .doc(`${decline.proposalRevision}_declined`),
            {
              event: "deposit_declined",
              actorUid: uid,
              revision: decline.proposalRevision,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
        transaction.create(commandRef, {
          actorUid: uid,
          transactionId,
          command: "decline_deposit",
          result,
          createdAt: FieldValue.serverTimestamp(),
        });
        return {...result, alreadyApplied: false};
      });
    } catch (error) {
      throw commandError(error);
    }
  }

  return {
    approveMarketplaceDepositPlan,
    declineMarketplaceDepositPlan,
    proposeMarketplaceDepositPlan,
  };
}

module.exports = {createMarketplacePaymentPlanCommands};
