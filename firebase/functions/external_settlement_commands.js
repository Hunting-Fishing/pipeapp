"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  loadPhase1FeatureFlags,
  requirePhase1Feature,
} = require("./phase1_feature_flags");
const {
  loadProviderReadiness,
  stripeSecretKey,
} = require("./stripe_marketplace_commands");
const {
  assertMarketplaceFeeCheckoutSessionIdentity,
  marketplaceExecutionCurrency,
  requirePlatformFeeBillingReady,
  safeConfiguredUrl,
  stripeCheckoutRequestSnapshot,
  stripeCheckoutSessionState,
  stripeFormRequest,
} = require("./stripe_checkout_commands");
const {
  automaticTaxEnabled,
  provisionalTaxReserveMinor,
  taxCollectionStatus,
} = require("./pending_tax_policy");

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function transactionIdFromRequest(request) {
  const value = String(request.data && request.data.transactionId || "").trim();
  if (!value || value.length > 180 || value.includes("/")) {
    throw new HttpsError("invalid-argument", "The transaction is invalid.");
  }
  return value;
}

function participantRole(sale, uid) {
  if (sale && sale.buyerUid === uid) return "buyer";
  if (sale && sale.sellerUid === uid) return "seller";
  throw new HttpsError(
      "permission-denied",
      "Only the buyer or seller can update this transaction.",
  );
}

function stripeCheckoutHasStarted(sale = {}) {
  const providerStatus = String(sale.paymentProviderStatus || "").trim();
  return String(sale.settlementMode || "").trim() === "stripe_checkout" ||
    String(sale.paymentMethod || "").trim() === "stripe_checkout" ||
    String(sale.paymentProvider || "").trim() === "stripe" ||
    !["", "not_started", "failed", "external_agreed"].includes(providerStatus) ||
    Boolean(
        sale.stripeCheckoutAttemptId ||
        sale.stripeCheckoutIdempotencyKey ||
        sale.stripeCheckoutSessionId ||
        sale.stripePaymentIntentId ||
        sale.stripeChargeId ||
        sale.stripeSellerTransferId,
    );
}

function reserveExternalSettlementState(sale = {}) {
  const currentMode = String(sale.settlementMode || "").trim();
  if (stripeCheckoutHasStarted(sale) ||
      (currentMode && currentMode !== "external_settlement")) {
    throw new HttpsError(
        "failed-precondition",
        "A Stripe marketplace checkout has already started for this transaction.",
    );
  }
  const currentGeneration = Number(sale.settlementGeneration || 0);
  const safeGeneration = Number.isSafeInteger(currentGeneration) &&
    currentGeneration >= 0 ? currentGeneration : 0;
  return {
    settlementMode: "external_settlement",
    settlementGeneration: currentMode === "external_settlement" ?
      Math.max(1, safeGeneration) : safeGeneration + 1,
  };
}

function validateExternalSettlementWithdrawal(sale = {}, role) {
  const buyerConfirmed = sale.externalSettlementBuyerConfirmed === true;
  const sellerConfirmed = sale.externalSettlementSellerConfirmed === true;
  const currentGeneration = Number(sale.settlementGeneration || 0);
  const safeGeneration = Number.isSafeInteger(currentGeneration) &&
    currentGeneration >= 0 ? currentGeneration : 0;
  const currentMode = String(sale.settlementMode || "").trim();
  if (!currentMode && !buyerConfirmed && !sellerConfirmed) {
    return {alreadyApplied: true, settlementGeneration: safeGeneration};
  }
  const actorConfirmed = role === "buyer" ? buyerConfirmed : sellerConfirmed;
  if (currentMode !== "external_settlement" || !actorConfirmed) {
    throw new HttpsError(
        "failed-precondition",
        "Only your pending external-settlement confirmation can be withdrawn.",
    );
  }
  if ((buyerConfirmed && sellerConfirmed) ||
      stripeCheckoutHasStarted(sale) ||
      String(sale.paymentMethod || "") === "external_settlement" ||
      String(sale.paymentProvider || "") === "external" ||
      String(sale.paymentProviderStatus || "") === "external_agreed" ||
      ["checkout_creating", "checkout_created", "processing", "collected"]
          .includes(String(sale.marketplaceFeeStatus || "")) ||
      sale.stripeMarketplaceFeeAttemptId ||
      sale.stripeMarketplaceFeeSessionId ||
      sale.stripeMarketplaceFeePaymentIntentId ||
      sale.stripeMarketplaceFeeChargeId) {
    throw new HttpsError(
        "failed-precondition",
        "External settlement cannot be withdrawn after both parties agree or " +
        "fee collection starts.",
    );
  }
  return {
    alreadyApplied: false,
    settlementGeneration: safeGeneration + 1,
  };
}

function externalFeeCheckoutMatchesReservation(sale = {}, reservation = {}) {
  const expectedSessionId = String(reservation.sessionId || "").trim();
  return String(sale.settlementMode || "") === "external_settlement" &&
    Number(sale.settlementGeneration || 0) ===
      Number(reservation.settlementGeneration || 0) &&
    Number(sale.stripeMarketplaceFeeSettlementGeneration || 0) ===
      Number(reservation.settlementGeneration || 0) &&
    String(sale.stripeMarketplaceFeeAttemptId || "") ===
      String(reservation.attemptId || "") &&
    (!expectedSessionId ||
      String(sale.stripeMarketplaceFeeSessionId || "") === expectedSessionId);
}

function createExternalSettlementCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const confirmExternalSettlement = async (request) => {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "offers"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "marketplace");
      requirePhase1Feature(flags, "offers");
      const transactionId = transactionIdFromRequest(request);
      const transactionRef = db.collection("marketplace_transactions")
          .doc(transactionId);
      return db.runTransaction(async (firestoreTransaction) => {
        const snapshot = await firestoreTransaction.get(transactionRef);
        if (!snapshot.exists) {
          throw new HttpsError("not-found", "This marketplace transaction is unavailable.");
        }
        const sale = snapshot.data();
        const role = participantRole(sale, uid);
        if (["cancelled", "disputed"].includes(String(sale.status || ""))) {
          throw new HttpsError(
              "failed-precondition",
              "This transaction cannot switch to external settlement.",
          );
        }
        const settlementReservation = reserveExternalSettlementState(sale);
        const buyerConfirmed = role === "buyer" ? true :
          sale.externalSettlementBuyerConfirmed === true;
        const sellerConfirmed = role === "seller" ? true :
          sale.externalSettlementSellerConfirmed === true;
        const fullyConfirmed = buyerConfirmed && sellerConfirmed;
        const existingFeeStatus = String(sale.marketplaceFeeStatus || "").trim();
        firestoreTransaction.set(transactionRef, {
          ...settlementReservation,
          externalSettlementBuyerConfirmed: buyerConfirmed,
          externalSettlementSellerConfirmed: sellerConfirmed,
          [`externalSettlement${role === "buyer" ? "Buyer" : "Seller"}ConfirmedAt`]:
            FieldValue.serverTimestamp(),
          ...(fullyConfirmed ? {
            paymentMethod: "external_settlement",
            paymentProvider: "external",
            paymentProviderStatus: "external_agreed",
            marketplaceFeeStatus: existingFeeStatus || "pending_collection",
            externalSettlementAgreedAt: FieldValue.serverTimestamp(),
          } : {}),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {
          transactionId,
          role,
          buyerConfirmed,
          sellerConfirmed,
          fullyConfirmed,
          settlementGeneration: settlementReservation.settlementGeneration,
        };
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("External settlement confirmation failed", error);
      throw new HttpsError("internal", "External settlement could not be confirmed.");
    }
  };

  const withdrawExternalSettlement = async (request) => {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "offers"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "marketplace");
      requirePhase1Feature(flags, "offers");
      const transactionId = transactionIdFromRequest(request);
      const transactionRef = db.collection("marketplace_transactions")
          .doc(transactionId);
      return db.runTransaction(async (firestoreTransaction) => {
        const snapshot = await firestoreTransaction.get(transactionRef);
        if (!snapshot.exists) {
          throw new HttpsError(
              "not-found",
              "This marketplace transaction is unavailable.",
          );
        }
        const sale = snapshot.data();
        const role = participantRole(sale, uid);
        const withdrawal = validateExternalSettlementWithdrawal(sale, role);
        if (!withdrawal.alreadyApplied) {
          firestoreTransaction.set(transactionRef, {
            settlementMode: FieldValue.delete(),
            settlementGeneration: withdrawal.settlementGeneration,
            externalSettlementBuyerConfirmed: false,
            externalSettlementSellerConfirmed: false,
            externalSettlementBuyerConfirmedAt: FieldValue.delete(),
            externalSettlementSellerConfirmedAt: FieldValue.delete(),
            externalSettlementAgreedAt: FieldValue.delete(),
            externalSettlementWithdrawnByUid: uid,
            externalSettlementWithdrawnAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
        return {
          transactionId,
          role,
          withdrawn: true,
          alreadyApplied: withdrawal.alreadyApplied,
          settlementGeneration: withdrawal.settlementGeneration,
        };
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("External settlement withdrawal failed", error);
      throw new HttpsError(
          "internal",
          "External settlement could not be withdrawn.",
      );
    }
  };

  const createExternalSettlementFeeCheckout = async (request) => {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "offers"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "marketplace");
      requirePhase1Feature(flags, "offers");
      requirePhase1Feature(flags, "paidFeatures");
      const readinessSnapshot = await db.collection("platform_configuration")
          .doc("payment_provider_readiness").get();
      const readinessData = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      const readiness = {
        ...(await loadProviderReadiness(db)),
        stripeFeeBillingEnabled: readinessData.stripeFeeBillingEnabled === true,
        stripeTaxRegistrationPending:
          readinessData.stripeTaxRegistrationPending === true,
        checkoutSuccessUrl: String(readinessData.checkoutSuccessUrl || ""),
        checkoutCancelUrl: String(readinessData.checkoutCancelUrl || ""),
      };
      requirePlatformFeeBillingReady(readiness);
      const collectionStatus = taxCollectionStatus(readiness);
      const transactionId = transactionIdFromRequest(request);
      const transactionRef = db.collection("marketplace_transactions")
          .doc(transactionId);
      const successUrl = safeConfiguredUrl(
          readiness.checkoutSuccessUrl,
          "Stripe Checkout success URL",
      );
      const cancelUrl = safeConfiguredUrl(
          readiness.checkoutCancelUrl,
          "Stripe Checkout cancel URL",
      );
      const buildCheckoutFields = ({
        sale,
        fee,
        attemptId,
        settlementGeneration,
      }) => stripeCheckoutRequestSnapshot({
        mode: "payment",
        success_url: successUrl,
        cancel_url: cancelUrl,
        client_reference_id: transactionId,
        billing_address_collection: "required",
        "automatic_tax[enabled]": automaticTaxEnabled(readiness) ?
          "true" : "false",
        "line_items[0][quantity]": 1,
        "line_items[0][price_data][currency]":
          marketplaceExecutionCurrency(fee, sale),
        "line_items[0][price_data][unit_amount]":
          Number(fee.marketplaceFeeMinor),
        "line_items[0][price_data][tax_behavior]": "exclusive",
        "line_items[0][price_data][product_data][name]":
          fee.feeClass === "pipe" ?
            "Pipe Buyer Marketplace Fee - Pipe" :
            "Pipe Buyer Marketplace Fee - Equipment & Assets",
        "line_items[0][price_data][product_data][tax_code]": "txcd_10000000",
        "payment_intent_data[metadata][pipeBuyerTransactionId]": transactionId,
        "payment_intent_data[metadata][billingType]": "marketplace_fee_only",
        "payment_intent_data[metadata][pipeBuyerFeeCheckoutAttemptId]":
          attemptId,
        "payment_intent_data[metadata][pipeBuyerSettlementGeneration]":
          settlementGeneration,
        "metadata[pipeBuyerTransactionId]": transactionId,
        "metadata[billingType]": "marketplace_fee_only",
        "metadata[pipeBuyerFeeCheckoutAttemptId]": attemptId,
        "metadata[pipeBuyerSettlementGeneration]": settlementGeneration,
        "metadata[feeScheduleRevision]": String(fee.scheduleRevision || ""),
        "metadata[listingId]": String(sale.listingId || ""),
        "metadata[buyerUid]": String(sale.buyerUid || ""),
        "metadata[sellerUid]": String(sale.sellerUid || ""),
        "metadata[taxCollectionStatus]": collectionStatus,
      });

      const reserveFeeCheckout = (proposedAttemptId) =>
        db.runTransaction(async (firestoreTransaction) => {
          const transactionSnapshot = await firestoreTransaction.get(
              transactionRef,
          );
          if (!transactionSnapshot.exists) {
            throw new HttpsError(
                "not-found",
                "This marketplace transaction is unavailable.",
            );
          }
          const sale = transactionSnapshot.data();
          if (sale.sellerUid !== uid) {
            throw new HttpsError(
                "permission-denied",
                "The seller is responsible for the current Pipe Buyer marketplace fee.",
            );
          }
          const settlementGeneration = Number(sale.settlementGeneration || 0);
          if (sale.settlementMode !== "external_settlement" ||
              !Number.isSafeInteger(settlementGeneration) ||
              settlementGeneration < 1 ||
              sale.paymentMethod !== "external_settlement" ||
              sale.externalSettlementBuyerConfirmed !== true ||
              sale.externalSettlementSellerConfirmed !== true) {
            throw new HttpsError(
                "failed-precondition",
                "Both parties must confirm external settlement before the marketplace fee is billed.",
            );
          }
          if (sale.marketplaceFeeStatus === "collected") {
            return {
              kind: "paid",
              checkoutSessionId: String(
                  sale.stripeMarketplaceFeeSessionId || "",
              ),
            };
          }
          const fee = sale.marketplaceFeeSnapshot || {};
          const feeMinor = Number(fee.marketplaceFeeMinor);
          if (!Number.isSafeInteger(feeMinor) || feeMinor <= 0) {
            throw new HttpsError(
                "failed-precondition",
                "The Pipe Buyer marketplace fee snapshot is not ready.",
            );
          }
          const currency = marketplaceExecutionCurrency(fee, sale);
          const currentFeeStatus = String(sale.marketplaceFeeStatus || "");
          const resumableStatuses = new Set([
            "checkout_creating",
            "checkout_created",
            "processing",
          ]);
          if (resumableStatuses.has(currentFeeStatus)) {
            const attemptId = String(
                sale.stripeMarketplaceFeeAttemptId || "",
            ).trim();
            const attemptNumber = Number(
                sale.stripeMarketplaceFeeAttemptNumber || 0,
            );
            const idempotencyKey = String(
                sale.stripeMarketplaceFeeIdempotencyKey || "",
            ).trim();
            const attemptGeneration = Number(
                sale.stripeMarketplaceFeeSettlementGeneration || 0,
            );
            let fields;
            try {
              fields = stripeCheckoutRequestSnapshot(JSON.parse(String(
                  sale.stripeMarketplaceFeeRequestSnapshot || "",
              )));
            } catch (_) {
              fields = null;
            }
            if (fields) {
              safeConfiguredUrl(
                  fields.success_url,
                  "Stored Stripe Checkout success URL",
              );
              safeConfiguredUrl(
                  fields.cancel_url,
                  "Stored Stripe Checkout cancel URL",
              );
            }
            if (!attemptId || !Number.isSafeInteger(attemptNumber) ||
                attemptNumber < 1 ||
                idempotencyKey !== `pipebuyer-external-fee-${attemptId}` ||
                attemptGeneration !== settlementGeneration ||
                !fields ||
                fields.mode !== "payment" ||
                fields.client_reference_id !== transactionId ||
                fields["line_items[0][price_data][currency]"] !== currency ||
                Number(fields["line_items[0][price_data][unit_amount]"]) !==
                  feeMinor ||
                fields["metadata[billingType]"] !== "marketplace_fee_only" ||
                fields["metadata[pipeBuyerTransactionId]"] !== transactionId ||
                fields["metadata[pipeBuyerFeeCheckoutAttemptId]"] !==
                  attemptId ||
                Number(fields["metadata[pipeBuyerSettlementGeneration]"]) !==
                  settlementGeneration ||
                fields[
                    "payment_intent_data[metadata][pipeBuyerTransactionId]"
                ] !== transactionId ||
                fields[
                    "payment_intent_data[metadata]" +
                    "[pipeBuyerFeeCheckoutAttemptId]"
                ] !== attemptId ||
                Number(fields[
                    "payment_intent_data[metadata]" +
                    "[pipeBuyerSettlementGeneration]"
                ]) !== settlementGeneration) {
              throw new HttpsError(
                  "failed-precondition",
                  "The existing marketplace fee checkout cannot be resumed safely.",
              );
            }
            const sessionId = String(
                sale.stripeMarketplaceFeeSessionId || "",
            ).trim();
            if (sessionId && !sessionId.startsWith("cs_")) {
              throw new HttpsError(
                  "failed-precondition",
                  "The active marketplace fee checkout has an invalid session.",
              );
            }
            if (!sessionId && currentFeeStatus !== "checkout_creating") {
              throw new HttpsError(
                  "failed-precondition",
                  "The active marketplace fee checkout is missing its Stripe session.",
              );
            }
            return {
              kind: sessionId ? "existing" : "reserved",
              sale,
              sessionId,
              attemptId,
              attemptNumber,
              fields,
              idempotencyKey,
              settlementGeneration,
              reserveIfCollectedMinor: provisionalTaxReserveMinor(
                  feeMinor,
                  collectionStatus,
              ),
            };
          }
          if (!["", "pending_collection", "payment_failed"].includes(
              currentFeeStatus,
          )) {
            throw new HttpsError(
                "failed-precondition",
                "The marketplace fee cannot be checked out in its current state.",
            );
          }
          const previousAttemptNumber = Number(
              sale.stripeMarketplaceFeeAttemptNumber || 0,
          );
          const attemptNumber = Number.isSafeInteger(previousAttemptNumber) &&
            previousAttemptNumber >= 0 ? previousAttemptNumber + 1 : 1;
          const attemptId = proposedAttemptId;
          const idempotencyKey = `pipebuyer-external-fee-${attemptId}`;
          const fields = buildCheckoutFields({
            sale,
            fee,
            attemptId,
            settlementGeneration,
          });
          firestoreTransaction.set(transactionRef, {
            marketplaceFeeStatus: "checkout_creating",
            stripeMarketplaceFeeAttemptId: attemptId,
            stripeMarketplaceFeeAttemptNumber: attemptNumber,
            stripeMarketplaceFeeIdempotencyKey: idempotencyKey,
            stripeMarketplaceFeeSettlementGeneration: settlementGeneration,
            stripeMarketplaceFeeRequestSnapshot: JSON.stringify(fields),
            stripeMarketplaceFeeSessionId: null,
            marketplaceFeeCheckoutReservedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
          return {
            kind: "reserved",
            sale: {
              ...sale,
              marketplaceFeeStatus: "checkout_creating",
              stripeMarketplaceFeeAttemptId: attemptId,
              stripeMarketplaceFeeSettlementGeneration: settlementGeneration,
              stripeMarketplaceFeeSessionId: null,
            },
            sessionId: "",
            attemptId,
            attemptNumber,
            fields,
            idempotencyKey,
            settlementGeneration,
            reserveIfCollectedMinor: provisionalTaxReserveMinor(
                feeMinor,
                collectionStatus,
            ),
          };
        });

      let reservation = await reserveFeeCheckout(crypto.randomUUID());
      for (let probe = 0; reservation.kind === "existing" && probe < 3; probe++) {
        const existingSession = await stripeFormRequest({
          secretKey: stripeSecretKey.value(),
          path: `/v1/checkout/sessions/${encodeURIComponent(
              reservation.sessionId,
          )}`,
          method: "GET",
        });
        assertMarketplaceFeeCheckoutSessionIdentity({
          sale: reservation.sale,
          session: existingSession,
          transactionId,
        });
        const existingState = stripeCheckoutSessionState(existingSession);
        if (existingState.state === "open") {
          return {
            transactionId,
            checkoutSessionId: reservation.sessionId,
            checkoutUrl: existingState.checkoutUrl,
            alreadyCreated: true,
            alreadyPaid: false,
            taxCollectionStatus: collectionStatus,
          };
        }
        if (existingState.state !== "expired") {
          throw new HttpsError(
              "failed-precondition",
              "This fee checkout is already completing. Refresh the transaction shortly.",
          );
        }

        const expiredReservation = reservation;
        const replacementAttemptId = crypto.randomUUID();
        reservation = await db.runTransaction(async (firestoreTransaction) => {
          const current = await firestoreTransaction.get(transactionRef);
          if (!current.exists) {
            throw new HttpsError(
                "not-found",
                "This marketplace transaction is unavailable.",
            );
          }
          const currentSale = current.data();
          if (currentSale.marketplaceFeeStatus === "collected") {
            return {
              kind: "paid",
              checkoutSessionId: String(
                  currentSale.stripeMarketplaceFeeSessionId || "",
              ),
            };
          }
          if (!externalFeeCheckoutMatchesReservation(
              currentSale,
              expiredReservation,
          )) {
            return {kind: "superseded"};
          }
          if (!["checkout_creating", "checkout_created", "processing",
            "payment_failed"].includes(String(
              currentSale.marketplaceFeeStatus || "",
          ))) {
            throw new HttpsError(
                "failed-precondition",
                "The expired marketplace fee checkout cannot be replaced.",
            );
          }
          const fee = currentSale.marketplaceFeeSnapshot || {};
          const feeMinor = Number(fee.marketplaceFeeMinor);
          const previousAttemptNumber = Number(
              currentSale.stripeMarketplaceFeeAttemptNumber || 0,
          );
          if (!Number.isSafeInteger(feeMinor) || feeMinor <= 0 ||
              !Number.isSafeInteger(previousAttemptNumber) ||
              previousAttemptNumber < 1) {
            throw new HttpsError(
                "failed-precondition",
                "The expired marketplace fee checkout cannot be replaced safely.",
            );
          }
          const settlementGeneration = Number(
              currentSale.settlementGeneration || 0,
          );
          const attemptNumber = previousAttemptNumber + 1;
          const idempotencyKey =
            `pipebuyer-external-fee-${replacementAttemptId}`;
          const fields = buildCheckoutFields({
            sale: currentSale,
            fee,
            attemptId: replacementAttemptId,
            settlementGeneration,
          });
          firestoreTransaction.set(transactionRef, {
            marketplaceFeeStatus: "checkout_creating",
            stripeMarketplaceFeeAttemptId: replacementAttemptId,
            stripeMarketplaceFeeAttemptNumber: attemptNumber,
            stripeMarketplaceFeeIdempotencyKey: idempotencyKey,
            stripeMarketplaceFeeSettlementGeneration: settlementGeneration,
            stripeMarketplaceFeeRequestSnapshot: JSON.stringify(fields),
            stripeMarketplaceFeeSessionId: null,
            stripeMarketplaceFeeExpiredSessionId:
              expiredReservation.sessionId,
            stripeMarketplaceFeeExpiredAttemptId:
              expiredReservation.attemptId,
            stripeMarketplaceFeeExpiredSettlementGeneration:
              expiredReservation.settlementGeneration,
            marketplaceFeeCheckoutExpiredAt: FieldValue.serverTimestamp(),
            marketplaceFeeCheckoutReservedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
          return {
            kind: "reserved",
            sale: {
              ...currentSale,
              marketplaceFeeStatus: "checkout_creating",
              stripeMarketplaceFeeAttemptId: replacementAttemptId,
              stripeMarketplaceFeeSettlementGeneration: settlementGeneration,
              stripeMarketplaceFeeSessionId: null,
            },
            sessionId: "",
            attemptId: replacementAttemptId,
            attemptNumber,
            fields,
            idempotencyKey,
            settlementGeneration,
            reserveIfCollectedMinor: provisionalTaxReserveMinor(
                feeMinor,
                collectionStatus,
            ),
          };
        });
        if (reservation.kind === "superseded") {
          reservation = await reserveFeeCheckout(crypto.randomUUID());
        }
      }
      if (reservation.kind === "paid") {
        return {
          transactionId,
          checkoutSessionId: reservation.checkoutSessionId,
          alreadyPaid: true,
        };
      }
      if (reservation.kind !== "reserved") {
        throw new HttpsError(
            "aborted",
            "The marketplace fee checkout changed while it was being resumed.",
        );
      }
      let session;
      try {
        session = await stripeFormRequest({
          secretKey: stripeSecretKey.value(),
          path: "/v1/checkout/sessions",
          idempotencyKey: reservation.idempotencyKey,
          fields: reservation.fields,
        });
      } catch (error) {
        if (error && error.details &&
            error.details.stripeRequestDefinitiveFailure === true) {
          await db.runTransaction(async (firestoreTransaction) => {
            const current = await firestoreTransaction.get(transactionRef);
            if (!current.exists) return;
            const currentSale = current.data();
            if (currentSale.marketplaceFeeStatus !== "checkout_creating" ||
                currentSale.stripeMarketplaceFeeAttemptId !==
                  reservation.attemptId ||
                Number(currentSale.settlementGeneration || 0) !==
                  reservation.settlementGeneration) return;
            firestoreTransaction.set(transactionRef, {
              marketplaceFeeStatus: "payment_failed",
              marketplaceFeePaymentFailedAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            }, {merge: true});
          });
        }
        throw error;
      }
      const sessionId = String(session.id || "");
      const checkoutUrl = String(session.url || "");
      if (!sessionId.startsWith("cs_") || !checkoutUrl.startsWith("https://")) {
        throw new HttpsError("internal", "Stripe did not return a valid fee checkout session.");
      }
      assertMarketplaceFeeCheckoutSessionIdentity({
        sale: reservation.sale,
        session,
        transactionId,
      });
      const finalState = await db.runTransaction(async (firestoreTransaction) => {
        const current = await firestoreTransaction.get(transactionRef);
        if (!current.exists) {
          throw new HttpsError("not-found", "This marketplace transaction is unavailable.");
        }
        const currentSale = current.data();
        if (!externalFeeCheckoutMatchesReservation(
            currentSale,
            reservation,
        )) {
          throw new HttpsError(
              "aborted",
              "The marketplace fee checkout was replaced by a newer settlement attempt.",
          );
        }
        const storedSessionId = String(
            currentSale.stripeMarketplaceFeeSessionId || "",
        );
        if (storedSessionId && storedSessionId !== sessionId) {
          throw new HttpsError(
              "aborted",
              "The marketplace fee checkout session identity changed.",
          );
        }
        const currentFeeStatus = String(currentSale.marketplaceFeeStatus || "");
        if (currentFeeStatus === "collected") {
          return {alreadyPaid: true};
        }
        if (!["checkout_creating", "checkout_created", "processing"].includes(
            currentFeeStatus,
        )) {
          throw new HttpsError(
              "failed-precondition",
              "The marketplace fee checkout is no longer payable.",
          );
        }
        firestoreTransaction.set(transactionRef, {
          marketplaceFeeStatus: currentFeeStatus === "checkout_creating" ?
            "checkout_created" : currentFeeStatus,
          stripeMarketplaceFeeSessionId: sessionId,
          marketplaceFeeTaxCollectionStatus: collectionStatus,
          marketplaceFeeTaxExposureReviewRequired:
            collectionStatus === "registration_pending",
          marketplaceFeeProvisionalTaxReserveIfCollectedMinor:
            reservation.reserveIfCollectedMinor,
          marketplaceFeeAutomaticTaxEnabled: automaticTaxEnabled(readiness),
          marketplaceFeeCheckoutCreatedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {alreadyPaid: false};
      });
      return {
        transactionId,
        checkoutSessionId: sessionId,
        checkoutUrl,
        alreadyPaid: finalState.alreadyPaid,
        taxCollectionStatus: collectionStatus,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("External settlement marketplace fee checkout failed", error);
      throw new HttpsError(
          "internal",
          "The Pipe Buyer marketplace fee checkout could not be started.",
      );
    }
  };

  return {
    confirmExternalSettlement,
    createExternalSettlementFeeCheckout,
    withdrawExternalSettlement,
  };
}

module.exports = {
  createExternalSettlementCommands,
  externalFeeCheckoutMatchesReservation,
  participantRole,
  reserveExternalSettlementState,
  stripeCheckoutHasStarted,
  validateExternalSettlementWithdrawal,
};
