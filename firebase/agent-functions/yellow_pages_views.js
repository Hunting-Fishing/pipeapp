"use strict";

const {FieldPath} = require("firebase-admin/firestore");
const {
  YellowPagesError,
  jsonSafe,
  resolveActor,
} = require("./yellow_pages_commands");
const {text} = require("./yellow_pages_policy");

const PRIVATE_COMPANIES = "yellow_pages_companies";
const ALLOWED_VIEWS = new Set([
  "my_queue",
  "not_contacted",
  "follow_up",
  "unverified",
  "verified_unpaid",
  "paid_confirmed",
  "published",
  "expired",
  "do_not_contact",
  "all",
]);

function pageSize(value, fallback = 50) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.max(1, Math.min(100, Math.trunc(number)));
}

async function listYellowPagesDashboardView(db, data, context) {
  if (!context || !context.auth) {
    throw new YellowPagesError(
        "unauthenticated",
        "Sign in to the PipeBuyer Contact Center.",
    );
  }
  const actor = await resolveActor(db, context);
  if (!actor.authorized) {
    throw new YellowPagesError(
        "permission-denied",
        actor.reason === "mfa_required" ?
          "Multi-factor authentication is required for Contact Center access." :
          "Your account is not authorized for the PipeBuyer Contact Center.",
    );
  }

  const requestedView = text(data && data.view, 40).toLowerCase() || "my_queue";
  if (!ALLOWED_VIEWS.has(requestedView)) {
    throw new YellowPagesError("invalid-argument", "The requested Contact Center view is invalid.");
  }
  const limit = pageSize(data && data.pageSize, 50);
  const cursor = text(data && data.cursor, 200);

  let query = db.collection(PRIVATE_COMPANIES);
  if (actor.role === "agent") {
    query = query.where("assignedAgentUid", "==", actor.uid);
  } else if (requestedView === "my_queue") {
    query = query.where("assignedAgentUid", "==", actor.uid);
  }

  switch (requestedView) {
    case "not_contacted":
      query = query.where("outreachStatus", "==", "not_contacted");
      break;
    case "follow_up":
      query = query.where("outreachStatus", "==", "follow_up");
      break;
    case "unverified":
      query = query.where("verificationStatus", "==", "unverified");
      break;
    case "verified_unpaid":
      query = query
          .where("verificationStatus", "==", "verified")
          .where("billingStatus", "==", "unpaid");
      break;
    case "paid_confirmed":
      query = query
          .where("verificationStatus", "==", "verified")
          .where("billingStatus", "==", "paid");
      break;
    case "published":
      query = query.where("publicationStatus", "==", "published");
      break;
    case "expired":
      query = query.where("billingStatus", "==", "expired");
      break;
    case "do_not_contact":
      query = query.where("doNotContact", "==", true);
      break;
    case "my_queue":
    case "all":
      break;
    default:
      throw new YellowPagesError("invalid-argument", "The requested Contact Center view is invalid.");
  }

  query = query.orderBy(FieldPath.documentId()).limit(limit + 1);
  if (cursor) query = query.startAfter(cursor);
  const snapshot = await query.get();
  const docs = snapshot.docs.slice(0, limit);
  return {
    view: requestedView,
    companies: docs.map((doc) => ({id: doc.id, ...jsonSafe(doc.data())})),
    nextCursor: snapshot.docs.length > limit ? docs[docs.length - 1].id : null,
  };
}

module.exports = {
  listYellowPagesDashboardView,
};
