"use strict";

const COUNTRY_CODES = new Set(["CA", "US", "MX"]);
const POLICY_STATUSES = new Set([
  "designOnly",
  "pendingApproval",
  "active",
  "suspended",
  "retired",
]);
const FEATURES = new Set([
  "propertyDraftIntake",
  "publicPropertyListings",
  "propertyOffers",
  "rightsListings",
  "regulatedEnergyAssets",
  "businessSales",
  "clientFunds",
]);

function asDate(value) {
  if (!value) return null;
  const parsed = value instanceof Date ? value : new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function jurisdictionKey(jurisdiction) {
  if (!jurisdiction || !COUNTRY_CODES.has(jurisdiction.countryCode)) {
    return null;
  }
  const subdivision = String(jurisdiction.subdivisionCode || "")
      .trim()
      .toUpperCase();
  return subdivision ?
    `${jurisdiction.countryCode}-${subdivision}` :
    jurisdiction.countryCode;
}

function validatePolicy(policy, at = new Date()) {
  const issues = [];
  const key = jurisdictionKey(policy && policy.jurisdiction);
  const entity = policy && policy.responsibleEntity;
  const license = policy && policy.brokerageLicense;
  const enabled = new Set(
      policy && policy.features && policy.features.enabledFeatures || [],
  );

  if (!policy || policy.schemaVersion !== 1) {
    issues.push("Unsupported jurisdiction policy schema version.");
  }
  if (!policy || !String(policy.id || "").trim()) {
    issues.push("Policy identifier is missing.");
  }
  if (!key) {
    issues.push("Jurisdiction is invalid.");
  } else if (!key.includes("-")) {
    issues.push(
        "Country baseline policies cannot authorize production features.",
    );
  }
  if (!policy || !POLICY_STATUSES.has(policy.status)) {
    issues.push("Jurisdiction policy status is invalid.");
  } else if (policy.status !== "active") {
    issues.push("Jurisdiction policy is not active.");
  }
  if (!entity || entity.active !== true) {
    issues.push("Responsible brokerage entity is not active.");
  } else if (
    policy.jurisdiction &&
    entity.countryCode !== policy.jurisdiction.countryCode
  ) {
    issues.push("Responsible entity does not match the jurisdiction country.");
  }
  if (!license) {
    issues.push("Brokerage licence is missing.");
  } else {
    if (!entity || license.entityId !== entity.id) {
      issues.push("Brokerage licence belongs to a different entity.");
    }
    if (jurisdictionKey(license.jurisdiction) !== key) {
      issues.push("Brokerage licence does not match the jurisdiction.");
    }
    const validFrom = asDate(license.validFrom);
    const validUntil = asDate(license.validUntil);
    if (
      license.active !== true ||
      !validFrom ||
      at < validFrom ||
      (validUntil && at >= validUntil)
    ) {
      issues.push("Brokerage licence is not valid at the requested time.");
    }
  }
  if (!String(policy && policy.complianceOwnerId || "").trim()) {
    issues.push("Supervising compliance owner is missing.");
  }
  if (!String(policy && policy.requiredFormSetVersion || "").trim()) {
    issues.push("Approved form set version is missing.");
  }
  if (!String(policy && policy.legalReviewVersion || "").trim()) {
    issues.push("Legal review version is missing.");
  }
  const effectiveAt = asDate(policy && policy.effectiveAt);
  const expiresAt = asDate(policy && policy.expiresAt);
  if (!effectiveAt || at < effectiveAt) {
    issues.push("Policy is not yet effective.");
  }
  if (expiresAt && at >= expiresAt) {
    issues.push("Policy has expired.");
  }
  for (const feature of enabled) {
    if (!FEATURES.has(feature)) {
      issues.push(`Unsupported controlled property feature: ${feature}.`);
    }
  }
  if (
    enabled.has("clientFunds") &&
    !String(policy && policy.trustFundsApprovalVersion || "").trim()
  ) {
    issues.push(
        "Client-funds handling requires a separate trust approval version.",
    );
  }
  return issues;
}

function canUseFeature(policy, feature, at = new Date()) {
  const reasons = validatePolicy(policy, at);
  const enabled = new Set(
      policy && policy.features && policy.features.enabledFeatures || [],
  );
  if (!FEATURES.has(feature)) {
    reasons.push(`Unknown controlled property feature: ${feature}.`);
  } else if (!enabled.has(feature)) {
    reasons.push(`Feature ${feature} is disabled for this jurisdiction.`);
  }
  return {
    allowed: reasons.length === 0,
    reasons,
  };
}

function resolveExactPolicy(policies, jurisdiction) {
  const requestedKey = jurisdictionKey(jurisdiction);
  if (!requestedKey) return null;
  return policies.find(
      (policy) => jurisdictionKey(policy.jurisdiction) === requestedKey,
  ) || null;
}

module.exports = {
  COUNTRY_CODES,
  FEATURES,
  POLICY_STATUSES,
  canUseFeature,
  jurisdictionKey,
  resolveExactPolicy,
  validatePolicy,
};

