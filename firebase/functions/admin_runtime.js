const { getApps, initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const {
  FieldValue,
  GeoPoint,
  Timestamp,
  getFirestore,
} = require("firebase-admin/firestore");

// Command factories receive this narrow adapter so their existing dependency
// injection and policy tests remain independent of the Admin SDK. The adapter
// itself uses only the supported modular Firebase Admin 14 APIs.
function createAdminRuntime() {
  if (getApps().length === 0) initializeApp();

  const firestore = () => getFirestore();
  firestore.FieldValue = FieldValue;
  firestore.GeoPoint = GeoPoint;
  firestore.Timestamp = Timestamp;

  return {
    auth: () => getAuth(),
    firestore,
  };
}

module.exports = { createAdminRuntime };
