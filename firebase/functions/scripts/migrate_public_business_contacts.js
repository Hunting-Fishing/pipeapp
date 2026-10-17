"use strict";

const crypto = require("node:crypto");
const admin = require("firebase-admin");

const EXPECTED_PROJECT_ID = "flutter-flow-pipe";
const PAGE_SIZE = 100;
const SOURCE_COLLECTIONS = Object.freeze([
  "public_business_profiles",
  "public_seller_profiles",
]);
const PRIVATE_COLLECTION = "business_private";
const DIRECTORY_COLLECTION = "dispatch_directory_entries";

function clean(value) {
  return String(value || "").trim();
}

function argumentValue(args, name) {
  const equalsPrefix = `${name}=`;
  const equalsValue = args.find((value) => value.startsWith(equalsPrefix));
  if (equalsValue) return clean(equalsValue.slice(equalsPrefix.length));
  const index = args.indexOf(name);
  return index >= 0 ? clean(args[index + 1]) : "";
}

function migrationTarget(
    args = process.argv.slice(2),
    environment = process.env,
) {
  const apply = args.includes("--apply");
  const projectId = argumentValue(args, "--project");
  if (projectId !== EXPECTED_PROJECT_ID) {
    throw new Error(
        `Pass --project=${EXPECTED_PROJECT_ID} to identify the intended target.`,
    );
  }
  const confirmedProjectId = argumentValue(args, "--confirm-project");
  if (apply && confirmedProjectId !== EXPECTED_PROJECT_ID) {
    throw new Error(
        `Apply mode also requires --confirm-project=${EXPECTED_PROJECT_ID}.`,
    );
  }
  const endpoint = clean(environment.FIRESTORE_EMULATOR_HOST) ||
    "google-firestore";
  const database = "(default)";
  const fingerprint = crypto.createHash("sha256")
      .update([
        projectId,
        database,
        endpoint,
        ...SOURCE_COLLECTIONS,
        PRIVATE_COLLECTION,
        DIRECTORY_COLLECTION,
      ].join("|"))
      .digest("hex")
      .slice(0, 16);
  return {
    apply,
    projectId,
    database,
    endpoint,
    fingerprint,
  };
}

function legacyContacts(data) {
  const dispatch = data.dispatchProfile &&
    typeof data.dispatchProfile === "object" ? data.dispatchProfile : {};
  const website = clean(data.website);
  const dispatchWebsite = clean(dispatch.website);
  return {
    phone: clean(data.publicPhone),
    email: clean(data.publicEmail),
    website: website || dispatchWebsite,
    profileWebsite: website,
    dispatchWebsite,
  };
}

function hasLegacyContacts(contacts) {
  return Boolean(
      contacts.phone || contacts.email || contacts.profileWebsite ||
      contacts.dispatchWebsite,
  );
}

function privateContactValues({
  uid,
  sourceCollection,
  contacts,
  existing,
  FieldValue,
}) {
  return {
    ownerUid: uid,
    ...(!clean(existing.contactPhone) && contacts.phone ?
      {contactPhone: contacts.phone} : {}),
    ...(!clean(existing.contactEmail) && contacts.email ?
      {contactEmail: contacts.email} : {}),
    ...(!clean(existing.website) && contacts.website ?
      {website: contacts.website} : {}),
    legacyPublicContacts: {
      [sourceCollection]: {
        ...(contacts.phone ? {publicPhone: contacts.phone} : {}),
        ...(contacts.email ? {publicEmail: contacts.email} : {}),
        ...(contacts.profileWebsite ? {website: contacts.profileWebsite} : {}),
        ...(contacts.dispatchWebsite ?
          {dispatchWebsite: contacts.dispatchWebsite} : {}),
        migratedAt: FieldValue.serverTimestamp(),
      },
    },
    contactPrivacyMigratedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

async function migrateCollection({
  db,
  FieldValue,
  sourceCollection,
  apply,
}) {
  let cursor = null;
  let reviewed = 0;
  let affected = 0;

  while (true) {
    let query = db.collection(sourceCollection)
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    const candidates = page.docs
        .map((document) => ({
          document,
          contacts: legacyContacts(document.data() || {}),
        }))
        .filter((candidate) => hasLegacyContacts(candidate.contacts));
    reviewed += page.size;
    affected += candidates.length;

    if (apply && candidates.length > 0) {
      const batch = db.batch();
      for (const {document, contacts} of candidates) {
        const privateRef = db.collection(PRIVATE_COLLECTION).doc(document.id);
        const privateSnapshot = await privateRef.get();
        const existing = privateSnapshot.exists ?
          privateSnapshot.data() || {} : {};
        batch.set(privateRef, privateContactValues({
          uid: document.id,
          sourceCollection,
          contacts,
          existing,
          FieldValue,
        }), {merge: true});

        const publicDeletes = {
          publicPhone: FieldValue.delete(),
          publicEmail: FieldValue.delete(),
          website: FieldValue.delete(),
          contactPrivacyMigratedAt: FieldValue.serverTimestamp(),
        };
        if (sourceCollection === "public_business_profiles" &&
            contacts.dispatchWebsite) {
          publicDeletes["dispatchProfile.website"] = FieldValue.delete();
        }
        batch.update(document.ref, publicDeletes);

        if (sourceCollection === "public_business_profiles") {
          const directoryRef = db.collection(DIRECTORY_COLLECTION)
              .doc(document.id);
          if ((await directoryRef.get()).exists) {
            batch.update(directoryRef, {website: FieldValue.delete()});
          }
        }
      }
      await batch.commit();
    }
    cursor = page.docs[page.docs.length - 1];
  }

  return {reviewed, affected};
}

async function main() {
  const target = migrationTarget();
  console.log(JSON.stringify({
    event: "migration_target",
    mode: target.apply ? "apply" : "dry-run",
    projectId: target.projectId,
    database: target.database,
    endpoint: target.endpoint,
    fingerprint: target.fingerprint,
    sourceCollections: SOURCE_COLLECTIONS,
    privateCollection: PRIVATE_COLLECTION,
  }));

  admin.initializeApp({projectId: target.projectId});
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const collections = {};
  let reviewed = 0;
  let affected = 0;
  for (const sourceCollection of SOURCE_COLLECTIONS) {
    const result = await migrateCollection({
      db,
      FieldValue,
      sourceCollection,
      apply: target.apply,
    });
    collections[sourceCollection] = result;
    reviewed += result.reviewed;
    affected += result.affected;
  }

  console.log(JSON.stringify({
    event: "migration_result",
    mode: target.apply ? "apply" : "dry-run",
    projectId: target.projectId,
    fingerprint: target.fingerprint,
    reviewed,
    affected,
    collections,
  }));
  if (!target.apply && affected > 0) {
    console.log(
        "Review the dry-run result before using --apply with the required " +
        "--confirm-project guard.",
    );
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error && error.message || error);
    process.exitCode = 1;
  });
}

module.exports = {
  EXPECTED_PROJECT_ID,
  PAGE_SIZE,
  SOURCE_COLLECTIONS,
  argumentValue,
  hasLegacyContacts,
  legacyContacts,
  migrationTarget,
  privateContactValues,
};
