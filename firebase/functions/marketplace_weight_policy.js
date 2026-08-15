"use strict";

const STEEL_DENSITY_KG_M3 = 7850;
const KG_PER_LB = 0.45359237;
const METRES_PER_FOOT = 0.3048;

function keyPart(value) {
  return String(value || "")
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "");
}

function catalogCandidateIds(listing) {
  const ids = [];
  const make = keyPart(listing.brand || listing.make);
  const model = keyPart(listing.model);
  const productType = keyPart(listing.productType);
  const pipeSize = keyPart(listing.pipeSize);
  const category = keyPart(listing.category);
  const modelYear = Number(listing.modelYear);
  if (make && model) {
    if (Number.isInteger(modelYear) && modelYear > 1900 && modelYear < 2200) {
      ids.push(`equipment_${make}_${model}_${modelYear}`);
    }
    ids.push(`equipment_${make}_${model}`);
  }
  if (productType && pipeSize) ids.push(`pipe_${productType}_${pipeSize}`);
  if (category && productType) ids.push(`product_${category}_${productType}`);
  return [...new Set(ids)];
}

function positive(value) {
  const number = Number(value);
  return Number.isFinite(number) && number > 0 ? number : null;
}

function integerQuantity(value) {
  const number = Number(value);
  return Number.isInteger(number) && number > 0 ? number : 1;
}

function modelYearMatches(entry, listing) {
  const year = Number(listing.modelYear);
  if (!Number.isInteger(year)) return true;
  const from = Number(entry.modelYearFrom);
  const to = Number(entry.modelYearTo);
  if (Number.isFinite(from) && year < from) return false;
  if (Number.isFinite(to) && year > to) return false;
  return true;
}

function pipeLengthMetres(listing) {
  const direct = positive(listing.jointLengthM || listing.lengthM);
  if (direct) return direct;
  const feet = positive(listing.jointLengthFt || listing.lengthFt);
  return feet ? feet * METRES_PER_FOOT : null;
}

function catalogEstimate(entry, listing) {
  const quantity = integerQuantity(listing.quantity);
  const lengthM = pipeLengthMetres(listing);
  const shipping = positive(entry.shippingWeightKg);
  const operating = positive(entry.operatingWeightKg);
  const unit = positive(entry.unitWeightKg);
  const kgPerM = positive(entry.kgPerM);
  const lbFt = positive(entry.nominalWeightLbFt);
  const minEach = positive(entry.operatingWeightMinKg) ||
      positive(entry.shippingWeightMinKg);
  const maxEach = positive(entry.operatingWeightMaxKg) ||
      positive(entry.shippingWeightMaxKg);
  let kg = null;
  let method = "catalog reference";
  if (shipping) {
    kg = shipping * quantity;
    method = "catalog shipping weight × quantity";
  } else if (operating) {
    kg = operating * quantity;
    method = "manufacturer operating weight × quantity";
  } else if (unit) {
    kg = unit * quantity;
    method = "catalog unit weight × quantity";
  } else if (kgPerM && lengthM) {
    kg = kgPerM * lengthM * quantity;
    method = "catalog kg/m × joint length × quantity";
  } else if (lbFt && lengthM) {
    kg = lbFt * (lengthM / METRES_PER_FOOT) * quantity * KG_PER_LB;
    method = "catalog lb/ft × joint length × quantity";
  } else if (maxEach) {
    // Configuration-dependent equipment can legitimately have several weights.
    // Use the upper reviewed value for planning so the UI does not understate
    // the load while still displaying the range and legal-weight disclaimer.
    kg = maxEach * quantity;
    method = "catalog range — conservative upper planning value";
  }
  return {
    kg,
    minimumKg: minEach ? minEach * quantity : null,
    maximumKg: maxEach ? maxEach * quantity : null,
    method,
  };
}

function pipeGeometryEstimate(listing) {
  const odMm = positive(listing.outsideDiameterMm || listing.pipeOdMm);
  const wallMm = positive(listing.wallThicknessMm);
  const lengthM = pipeLengthMetres(listing);
  const quantity = integerQuantity(listing.quantity);
  if (!odMm || !wallMm || !lengthM || odMm <= wallMm * 2) return null;
  const outer = odMm / 1000;
  const inner = (odMm - wallMm * 2) / 1000;
  const area = Math.PI / 4 * (outer * outer - inner * inner);
  return area * lengthM * STEEL_DENSITY_KG_M3 * quantity;
}

function pipeNominalEstimate(listing) {
  const lbFt = positive(listing.nominalWeightLbFt || listing.pipeWeightLbFt);
  const lengthM = pipeLengthMetres(listing);
  const quantity = integerQuantity(listing.quantity);
  if (!lbFt || !lengthM) return null;
  return lbFt * (lengthM / METRES_PER_FOOT) * quantity * KG_PER_LB;
}

function snapshotBase({status, sourceLabel, confidence, method}) {
  return {
    schemaVersion: 1,
    status,
    sourceLabel,
    confidence,
    method,
    legalUse: false,
    legalDisclaimer:
      "Approximate planning weight only. Confirm actual loaded and axle weights using appropriate certified scales and all applicable route, axle, permit, and jurisdictional requirements.",
  };
}

function sellerSnapshot(listing) {
  const kg = positive(listing.sellerEstimatedWeightKg);
  if (!kg) return null;
  return {
    ...snapshotBase({
      status: "estimated",
      sourceLabel: "Seller-entered approximate shipping weight",
      confidence: "seller estimate",
      method: "seller-entered total load estimate",
    }),
    estimatedWeightKg: kg,
  };
}

function unknownSnapshot() {
  return snapshotBase({
    status: "unknown",
    sourceLabel: "Seller does not know the load weight",
    confidence: "unknown",
    method: "weight to confirm before transport",
  });
}

function formulaSnapshot(listing) {
  const nominal = pipeNominalEstimate(listing);
  if (nominal) {
    return {
      ...snapshotBase({
        status: "estimated",
        sourceLabel: "Pipe nominal mass calculation",
        confidence: "engineering estimate",
        method: "nominal lb/ft × joint length × quantity",
      }),
      estimatedWeightKg: nominal,
    };
  }
  const geometry = pipeGeometryEstimate(listing);
  if (geometry) {
    return {
      ...snapshotBase({
        status: "estimated",
        sourceLabel: "Carbon-steel pipe geometry calculation",
        confidence: "engineering estimate",
        method: "steel cross-section × length × 7,850 kg/m³ × quantity",
      }),
      estimatedWeightKg: geometry,
    };
  }
  return null;
}

function catalogSnapshot(id, entry, listing) {
  if (!entry || entry.active === false || !modelYearMatches(entry, listing)) {
    return null;
  }
  const estimate = catalogEstimate(entry, listing);
  if (!estimate.kg) return null;
  return {
    ...snapshotBase({
      status: "estimated",
      sourceLabel: String(entry.sourceLabel || entry.sourceName ||
        "Approved weight catalog"),
      confidence: String(entry.verificationStatus || "admin reviewed"),
      method: estimate.method,
    }),
    catalogId: id,
    catalogRevision: Number(entry.revision || 1),
    estimatedWeightKg: estimate.kg,
    ...(estimate.minimumKg ? {estimatedWeightMinKg: estimate.minimumKg} : {}),
    ...(estimate.maximumKg ? {estimatedWeightMaxKg: estimate.maximumKg} : {}),
    sourceName: String(entry.sourceName || "").slice(0, 300),
    sourceUrl: String(entry.sourceUrl || "").slice(0, 2000),
    sourceReference: String(entry.sourceReference || "").slice(0, 500),
    catalogKind: String(entry.kind || "").slice(0, 40),
    variant: String(entry.variant || "").slice(0, 160),
  };
}

async function resolveListingWeightSnapshot(db, listing) {
  const mode = String(listing.weightInputMode || "catalog_estimate");
  if (mode === "unknown") return unknownSnapshot();
  if (mode === "seller_estimate") {
    return sellerSnapshot(listing) || unknownSnapshot();
  }
  for (const id of catalogCandidateIds(listing)) {
    const document = await db.collection("weight_catalog").doc(id).get();
    if (!document.exists) continue;
    const snapshot = catalogSnapshot(id, document.data(), listing);
    if (snapshot) return snapshot;
  }
  return formulaSnapshot(listing) || unknownSnapshot();
}

function applyWeightSnapshot(listing, snapshot) {
  const next = {...listing, weightSnapshot: snapshot};
  next.weightStatus = snapshot.status;
  next.weightSource = snapshot.sourceLabel;
  next.weightConfidence = snapshot.confidence;
  if (positive(snapshot.estimatedWeightKg)) {
    next.shippingWeightKg = snapshot.estimatedWeightKg;
    if (snapshot.catalogId) next.catalogWeightKg = snapshot.estimatedWeightKg;
  } else {
    delete next.shippingWeightKg;
    delete next.catalogWeightKg;
  }
  return next;
}

module.exports = {
  KG_PER_LB,
  METRES_PER_FOOT,
  STEEL_DENSITY_KG_M3,
  applyWeightSnapshot,
  catalogCandidateIds,
  catalogEstimate,
  catalogSnapshot,
  formulaSnapshot,
  keyPart,
  modelYearMatches,
  pipeGeometryEstimate,
  pipeNominalEstimate,
  resolveListingWeightSnapshot,
  sellerSnapshot,
  unknownSnapshot,
};
