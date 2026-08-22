"use strict";

const {REQUIRED_POLICY_IDS} = require("./policy_acceptance_policy");

function policyAcceptanceMatches({acceptance, policies}) {
  if (!acceptance) return false;
  const versions = acceptance.acceptedVersions || {};
  const hashes = acceptance.acceptedHashes || {};
  for (const id of REQUIRED_POLICY_IDS) {
    const policy = policies[id];
    if (!policy || policy.status !== "published") return false;
    if (String(versions[id] || "") !== String(policy.version || "")) return false;
    if (String(hashes[id] || "") !== String(policy.contentSha256 || "")) return false;
  }
  return true;
}

async function currentPolicyAcceptanceStatus(db, uid) {
  const enforcementSnapshot = await db.collection("platform_configuration")
      .doc("policy_enforcement")
      .get();
  const enforcementEnabled = enforcementSnapshot.exists &&
    enforcementSnapshot.data().enabled === true;
  if (!enforcementEnabled) {
    return {
      enforcementEnabled: false,
      current: true,
      reason: "not_enforced",
    };
  }

  const references = [
    db.collection("policy_acceptances").doc(uid),
    ...REQUIRED_POLICY_IDS.map((id) =>
      db.collection("platform_policies").doc(id)),
  ];
  const [acceptanceSnapshot, ...policySnapshots] = await db.getAll(...references);
  const policies = {};
  for (const snapshot of policySnapshots) {
    if (snapshot.exists) policies[snapshot.id] = snapshot.data();
  }
  const acceptance = acceptanceSnapshot.exists ? acceptanceSnapshot.data() : null;
  const current = policyAcceptanceMatches({acceptance, policies});
  return {
    enforcementEnabled: true,
    current,
    reason: current ? "current" : "review_required",
  };
}

module.exports = {
  currentPolicyAcceptanceStatus,
  policyAcceptanceMatches,
};
