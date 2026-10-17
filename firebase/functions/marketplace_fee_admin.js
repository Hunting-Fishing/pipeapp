"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  BASIS_POINTS,
  MARKETPLACE_FEE_CLASS_SOURCE,
  MARKETPLACE_FEE_CLASSIFICATION_REVISION,
  fromMinorUnits,
  isCanonicalPipeCatalogListing,
  launchMarketplaceFeeSchedule,
  listingRevision,
} = require("./marketplace_fee_policy");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");

function moneyMap(minorByCurrency = {}) {
  return Object.fromEntries(
      Object.entries(minorByCurrency).map(([currency, minor]) => [
        currency,
        Object.freeze({
          minor: Number(minor),
          amount: fromMinorUnits(minor),
        }),
      ]),
  );
}

function feeCatalog() {
  const schedule = launchMarketplaceFeeSchedule;
  const products = stripeMarketplaceConfig.products;
  return {
    scheduleRevision: String(schedule.revision),
    feePayer: String(schedule.payer),
    listingFeeByCurrency: moneyMap(schedule.listingFeeMinorByCurrency),
    collectionTiming: String(schedule.collectionTiming),
    affiliate: {
      shareBps: Number(schedule.affiliateShareBps),
      sharePercent: Number(
          (Number(schedule.affiliateShareBps) * 100 / BASIS_POINTS).toFixed(2),
      ),
    },
    pipe: {
      unitFeeByCurrency: moneyMap(schedule.pipe.unitFeeMinorByCurrency),
      percentageCapBps: Number(schedule.pipe.percentageCapBps),
      percentageCap: Number(
          (Number(schedule.pipe.percentageCapBps) * 100 / BASIS_POINTS)
              .toFixed(2),
      ),
      maximumFeeByCurrency: moneyMap(schedule.pipe.maximumFeeMinorByCurrency),
      stripeProductId: products.pipeMarketplaceFeeCad.productId,
      stripePriceId: products.pipeMarketplaceFeeCad.priceId,
      stripeTaxCode: products.pipeMarketplaceFeeCad.taxCode,
    },
    equipment: {
      minimumFeeByCurrency: moneyMap(schedule.equipment.minimumFeeMinorByCurrency),
      maximumFeeByCurrency: moneyMap(schedule.equipment.maximumFeeMinorByCurrency),
      brackets: schedule.equipment.brackets.map((bracket) => ({
        upToExclusiveMinor: bracket.upToExclusiveMinor,
        upToExclusive: bracket.upToExclusiveMinor == null ? null :
          fromMinorUnits(bracket.upToExclusiveMinor),
        feeBps: Number(bracket.feeBps),
        feePercent: Number(
            (Number(bracket.feeBps) * 100 / BASIS_POINTS).toFixed(2),
        ),
      })),
      stripeProductId: products.equipmentMarketplaceFee.productId,
      stripeTaxCode: products.equipmentMarketplaceFee.taxCode,
    },
    dispatch: {
      monthly: {
        currency: products.dispatchMonthlyUsd.currency,
        amountMinor: products.dispatchMonthlyUsd.unitAmountMinor,
        amount: fromMinorUnits(products.dispatchMonthlyUsd.unitAmountMinor),
        interval: products.dispatchMonthlyUsd.billingInterval,
        stripeProductId: products.dispatchMonthlyUsd.productId,
        stripePriceId: products.dispatchMonthlyUsd.priceId,
        stripeTaxCode: products.dispatchMonthlyUsd.taxCode,
      },
      yearly: {
        currency: products.dispatchYearlyUsd.currency,
        amountMinor: products.dispatchYearlyUsd.unitAmountMinor,
        amount: fromMinorUnits(products.dispatchYearlyUsd.unitAmountMinor),
        interval: products.dispatchYearlyUsd.billingInterval,
        stripeProductId: products.dispatchYearlyUsd.productId,
        stripePriceId: products.dispatchYearlyUsd.priceId,
        stripeTaxCode: products.dispatchYearlyUsd.taxCode,
      },
    },
    taxCodes: {
      defaultPhysicalGoods: stripeMarketplaceConfig.defaultPhysicalGoodsTaxCode,
      marketplaceService: products.pipeMarketplaceFeeCad.taxCode,
      dispatchSaas: products.dispatchMonthlyUsd.taxCode,
    },
  };
}

// Customer-facing pricing must come from the same immutable schedule used to
// stamp transactions, but it must never disclose provider identifiers, tax
// configuration, affiliate economics, or readiness state.
function publicFeeCatalog() {
  const schedule = launchMarketplaceFeeSchedule;
  return {
    scheduleRevision: String(schedule.revision),
    feePayer: String(schedule.payer),
    listingFeeByCurrency: moneyMap(schedule.listingFeeMinorByCurrency),
    collectionTiming: String(schedule.collectionTiming),
    pipe: {
      unitFeeByCurrency: moneyMap(schedule.pipe.unitFeeMinorByCurrency),
      percentageCapBps: Number(schedule.pipe.percentageCapBps),
      percentageCap: Number(
          (Number(schedule.pipe.percentageCapBps) * 100 / BASIS_POINTS)
              .toFixed(2),
      ),
      maximumFeeByCurrency: moneyMap(schedule.pipe.maximumFeeMinorByCurrency),
    },
    equipment: {
      minimumFeeByCurrency: moneyMap(schedule.equipment.minimumFeeMinorByCurrency),
      maximumFeeByCurrency: moneyMap(schedule.equipment.maximumFeeMinorByCurrency),
      brackets: schedule.equipment.brackets.map((bracket) => ({
        upToExclusiveMinor: bracket.upToExclusiveMinor,
        upToExclusive: bracket.upToExclusiveMinor == null ? null :
          fromMinorUnits(bracket.upToExclusiveMinor),
        feeBps: Number(bracket.feeBps),
        feePercent: Number(
            (Number(bracket.feeBps) * 100 / BASIS_POINTS).toFixed(2),
        ),
      })),
    },
  };
}

function buildMarketplaceFeeClassificationRecord({
  listingId,
  listing,
  feeClass,
  administratorUid,
  reason,
  decisionRevision,
}) {
  const normalizedListingId = String(listingId || "").trim();
  const normalizedAdministratorUid = String(administratorUid || "").trim();
  const normalizedReason = String(reason || "").trim();
  const normalizedFeeClass = String(feeClass || "").trim();
  const revision = listingRevision(listing);
  const normalizedDecisionRevision = Number(decisionRevision);
  if (!normalizedListingId || normalizedListingId.length > 180 ||
      normalizedListingId.includes("/")) {
    throw new HttpsError(
        "invalid-argument",
        "The marketplace listing identifier is invalid.",
    );
  }
  if (!normalizedAdministratorUid) {
    throw new HttpsError(
        "permission-denied",
        "An administrator identity is required.",
    );
  }
  if (!listing || !String(listing.sellerUid || "").trim() || revision == null) {
    throw new HttpsError(
        "failed-precondition",
        "The listing identity or revision is incomplete.",
    );
  }
  if (!new Set(["pipe", "equipment_asset"]).has(normalizedFeeClass)) {
    throw new HttpsError(
        "invalid-argument",
        "Select pipe approval or the default equipment fee class.",
    );
  }
  if (normalizedReason.length < 10 || normalizedReason.length > 1000) {
    throw new HttpsError(
        "invalid-argument",
        "A concise fee-class decision reason is required.",
    );
  }
  if (!Number.isSafeInteger(normalizedDecisionRevision) ||
      normalizedDecisionRevision < 1) {
    throw new HttpsError(
        "failed-precondition",
        "The fee-class decision revision is invalid.",
    );
  }
  if (normalizedFeeClass === "pipe" &&
      !isCanonicalPipeCatalogListing(listing)) {
    throw new HttpsError(
        "failed-precondition",
        "Only a reviewed canonical pipe catalog listing can receive pipe pricing.",
    );
  }
  const approved = normalizedFeeClass === "pipe";
  return Object.freeze({
    listingId: normalizedListingId,
    sellerUid: String(listing.sellerUid).trim(),
    listingRevision: revision,
    category: String(listing.category || ""),
    productType: String(listing.productType || ""),
    status: approved ? "approved" : "revoked",
    marketplaceFeeClass: approved ? "pipe" : "equipment_asset",
    marketplaceFeeUnit: approved ? "item" : "sale_value",
    marketplaceFeeClassSource: MARKETPLACE_FEE_CLASS_SOURCE,
    marketplaceFeeClassificationRevision:
      MARKETPLACE_FEE_CLASSIFICATION_REVISION,
    decisionRevision: normalizedDecisionRevision,
    decisionReason: normalizedReason,
    decidedByUid: normalizedAdministratorUid,
  });
}

function createMarketplaceFeeAdmin(admin) {
  const getMarketplaceFeeCatalog = async (request) => {
    try {
      requireAdministrator(request);
      return feeCatalog();
    } catch (error) {
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Marketplace fee catalog failed", error);
      throw new HttpsError("internal", "The marketplace fee catalog is unavailable.");
    }
  };

  const getPublicMarketplaceFeeCatalog = async () => publicFeeCatalog();

  const setMarketplaceListingFeeClassification = async (request) => {
    try {
      const administratorUid = requireAdministrator(request);
      const listingId = String(
          request.data && request.data.listingId || "",
      ).trim();
      const feeClass = String(
          request.data && request.data.feeClass || "",
      ).trim();
      const reason = String(request.data && request.data.reason || "").trim();
      if (!listingId || listingId.length > 180 || listingId.includes("/")) {
        throw new HttpsError(
            "invalid-argument",
            "The marketplace listing identifier is invalid.",
        );
      }
      if (!admin || typeof admin.firestore !== "function") {
        throw new HttpsError(
            "failed-precondition",
            "The marketplace fee administration service is unavailable.",
        );
      }
      const db = admin.firestore();
      const FieldValue = admin.firestore.FieldValue;
      const listingRef = db.collection("public_listings").doc(listingId);
      const classificationRef = db
          .collection("marketplace_fee_classifications").doc(listingId);
      const auditRef = db
          .collection("marketplace_fee_classification_events").doc();
      return await db.runTransaction(async (transaction) => {
        const listingSnapshot = await transaction.get(listingRef);
        const currentSnapshot = await transaction.get(classificationRef);
        if (!listingSnapshot.exists) {
          throw new HttpsError("not-found", "The marketplace listing was not found.");
        }
        const decisionRevision = Number(
            currentSnapshot.exists &&
            currentSnapshot.data().decisionRevision || 0,
        ) + 1;
        const record = buildMarketplaceFeeClassificationRecord({
          listingId,
          listing: listingSnapshot.data(),
          feeClass,
          administratorUid,
          reason,
          decisionRevision,
        });
        const decidedAt = FieldValue.serverTimestamp();
        transaction.set(classificationRef, {
          ...record,
          decidedAt,
          updatedAt: decidedAt,
        }, {merge: false});
        transaction.create(auditRef, {
          ...record,
          event: record.status === "approved" ?
            "pipe_fee_class_approved" : "pipe_fee_class_revoked",
          createdAt: decidedAt,
        });
        return {
          listingId: record.listingId,
          feeClass: record.marketplaceFeeClass,
          status: record.status,
          listingRevision: record.listingRevision,
          decisionRevision: record.decisionRevision,
          classificationRevision:
            record.marketplaceFeeClassificationRevision,
        };
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Marketplace fee classification update failed", error);
      throw new HttpsError(
          "internal",
          "The marketplace fee classification could not be saved.",
      );
    }
  };

  return {
    getMarketplaceFeeCatalog,
    getPublicMarketplaceFeeCatalog,
    setMarketplaceListingFeeClassification,
  };
}

module.exports = {
  buildMarketplaceFeeClassificationRecord,
  createMarketplaceFeeAdmin,
  feeCatalog,
  moneyMap,
  publicFeeCatalog,
};
