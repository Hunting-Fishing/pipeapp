"use strict";

async function hasDeletionTombstone(db, uid) {
  if (!uid) return false;
  const snapshot = await db
      .collection("account_deletion_tombstones")
      .doc(uid)
      .get();
  return snapshot.exists;
}

module.exports = {hasDeletionTombstone};
