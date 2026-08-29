"use strict";

function marketplaceChargeIds(sale = {}) {
  const values = [
    String(sale.stripeChargeId || ""),
    ...(Array.isArray(sale.stripeChargeIds) ?
      sale.stripeChargeIds.map((value) => String(value || "")) : []),
  ];
  return [...new Set(values.filter((value) => /^ch_[A-Za-z0-9]+$/u.test(value)))];
}

function normalizeChargeState(charges) {
  if (!Array.isArray(charges) || charges.length === 0) {
    throw new TypeError("At least one Stripe charge is required.");
  }
  return charges.map((charge) => {
    const id = String(charge && charge.id || "");
    const amountMinor = Number(charge && charge.amountMinor);
    const refundedMinor = Number(charge && charge.refundedMinor || 0);
    if (!/^ch_[A-Za-z0-9]+$/u.test(id) ||
        !Number.isSafeInteger(amountMinor) || amountMinor <= 0 ||
        !Number.isSafeInteger(refundedMinor) || refundedMinor < 0 ||
        refundedMinor > amountMinor) {
      throw new TypeError("Stripe charge state is invalid.");
    }
    return {
      id,
      amountMinor,
      refundedMinor,
      refundableMinor: amountMinor - refundedMinor,
    };
  });
}

function aggregateChargeState(charges) {
  const normalized = normalizeChargeState(charges);
  return normalized.reduce((result, charge) => ({
    chargedMinor: result.chargedMinor + charge.amountMinor,
    refundedMinor: result.refundedMinor + charge.refundedMinor,
    refundableMinor: result.refundableMinor + charge.refundableMinor,
  }), {chargedMinor: 0, refundedMinor: 0, refundableMinor: 0});
}

function allocateRefundAcrossCharges(requestedMinor, charges) {
  const requested = Number(requestedMinor);
  const normalized = normalizeChargeState(charges);
  const available = normalized.reduce(
      (total, charge) => total + charge.refundableMinor,
      0,
  );
  if (!Number.isSafeInteger(requested) || requested <= 0 || requested > available) {
    throw new TypeError("Requested refund exceeds the refundable charge balance.");
  }

  // Newest payment first: for deposit/balance this refunds the balance charge
  // before touching the deposit. This is deterministic and preserves the
  // earliest payment as long as possible for partial refunds.
  let remaining = requested;
  const allocations = [];
  for (const charge of [...normalized].reverse()) {
    if (remaining <= 0) break;
    const amountMinor = Math.min(remaining, charge.refundableMinor);
    if (amountMinor <= 0) continue;
    allocations.push({chargeId: charge.id, amountMinor});
    remaining -= amountMinor;
  }
  if (remaining !== 0) {
    throw new TypeError("Refund allocation did not consume the requested amount.");
  }
  return allocations;
}

module.exports = {
  aggregateChargeState,
  allocateRefundAcrossCharges,
  marketplaceChargeIds,
  normalizeChargeState,
};
