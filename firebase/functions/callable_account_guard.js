"use strict";

const {HttpsError} = require("firebase-functions/v2/https");

async function requireCallableAccountActive(admin, request) {
  const uid = request && request.auth && request.auth.uid;
  if (!uid) return;
  const tombstone = await admin
      .firestore()
      .collection("account_deletion_tombstones")
      .doc(uid)
      .get();
  if (tombstone.exists) {
    throw new HttpsError(
        "failed-precondition",
        "Account deletion is processing. Sign-in actions are no longer available.",
    );
  }
}

function guardCallableHandler(admin, handler) {
  return async (request) => {
    await requireCallableAccountActive(admin, request);
    return handler(request);
  };
}

module.exports = {
  guardCallableHandler,
  requireCallableAccountActive,
};
