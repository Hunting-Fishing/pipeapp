"use strict";

const functions = require("firebase-functions/v1");
const {getApps, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const {
  AgentPolicyError,
  createAgentHandler,
  loadAgentConfiguration,
} = require("./agent_policy");
const {
  YellowPagesError,
  createYellowPagesCommands,
} = require("./yellow_pages_commands");
const {
  listYellowPagesDashboardView,
} = require("./yellow_pages_views");

if (getApps().length === 0) initializeApp();

const db = getFirestore();
const auth = getAuth();
const configuration = loadAgentConfiguration();
const handler = createAgentHandler({
  configuration,
  writeAudit: async (event) => db
      .collection("administrator_agent_audit")
      .doc(event.requestId)
      .create({...event, createdAt: FieldValue.serverTimestamp()}),
});
const yellowPages = createYellowPagesCommands({db, auth});

exports.agent = functions
    .runWith({
      enforceAppCheck: true,
      memory: "8GB",
      minInstances: configuration.minInstances,
      maxInstances: configuration.maxInstances,
      timeoutSeconds: 60,
    })
    .https.onCall(async (data, context) => {
      try {
        return await handler(data, context);
      } catch (error) {
        if (error instanceof AgentPolicyError) {
          throw new functions.https.HttpsError(error.code, error.message);
        }
        functions.logger.error("Administrative agent request failed.", {
          errorName: error && error.name,
        });
        throw new functions.https.HttpsError(
            "internal",
            "The administrative request could not be completed.",
        );
      }
    });

function yellowPagesCallable(name, command) {
  return functions
      .runWith({
        enforceAppCheck: true,
        memory: "256MB",
        minInstances: 0,
        maxInstances: 20,
        timeoutSeconds: 30,
      })
      .https.onCall(async (data, context) => {
        try {
          return await command(data || {}, context);
        } catch (error) {
          if (error instanceof YellowPagesError) {
            throw new functions.https.HttpsError(error.code, error.message);
          }
          functions.logger.error("PipeBuyer Yellow Pages callable failed.", {
            functionName: name,
            errorName: error && error.name,
          });
          throw new functions.https.HttpsError(
              "internal",
              "The PipeBuyer Yellow Pages service could not complete this request.",
          );
        }
      });
}

exports.getYellowPagesAccess = yellowPagesCallable(
    "getYellowPagesAccess",
    yellowPages.getAccess,
);
exports.listPipeBuyerYellowPages = yellowPagesCallable(
    "listPipeBuyerYellowPages",
    yellowPages.listPublic,
);
exports.getPipeBuyerYellowPagesEntry = yellowPagesCallable(
    "getPipeBuyerYellowPagesEntry",
    yellowPages.getPublic,
);
exports.listYellowPagesCompanies = yellowPagesCallable(
    "listYellowPagesCompanies",
    yellowPages.listCompanies,
);
exports.listYellowPagesDashboardView = yellowPagesCallable(
    "listYellowPagesDashboardView",
    (data, context) => listYellowPagesDashboardView(db, data, context),
);
exports.getYellowPagesCompany = yellowPagesCallable(
    "getYellowPagesCompany",
    yellowPages.getCompany,
);
exports.upsertYellowPagesCompany = yellowPagesCallable(
    "upsertYellowPagesCompany",
    yellowPages.upsertCompany,
);
exports.assignYellowPagesCompany = yellowPagesCallable(
    "assignYellowPagesCompany",
    yellowPages.assignCompany,
);
exports.recordYellowPagesContactEvent = yellowPagesCallable(
    "recordYellowPagesContactEvent",
    yellowPages.recordContactEvent,
);
exports.setYellowPagesDoNotContact = yellowPagesCallable(
    "setYellowPagesDoNotContact",
    yellowPages.setDoNotContact,
);
exports.reviewYellowPagesVerification = yellowPagesCallable(
    "reviewYellowPagesVerification",
    yellowPages.reviewVerification,
);
exports.setYellowPagesBillingStatus = yellowPagesCallable(
    "setYellowPagesBillingStatus",
    yellowPages.setBillingStatus,
);
exports.setYellowPagesPublicationStatus = yellowPagesCallable(
    "setYellowPagesPublicationStatus",
    yellowPages.setPublicationStatus,
);
exports.listYellowPagesStaff = yellowPagesCallable(
    "listYellowPagesStaff",
    yellowPages.listStaff,
);
exports.manageYellowPagesStaff = yellowPagesCallable(
    "manageYellowPagesStaff",
    yellowPages.manageStaff,
);
