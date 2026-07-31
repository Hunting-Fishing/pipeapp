"use strict";

const functions = require("firebase-functions/v1");
const {getApps, initializeApp} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const {
  AgentPolicyError,
  createAgentHandler,
  loadAgentConfiguration,
} = require("./agent_policy");

if (getApps().length === 0) initializeApp();

const configuration = loadAgentConfiguration();
const handler = createAgentHandler({
  configuration,
  writeAudit: async (event) => getFirestore()
      .collection("administrator_agent_audit")
      .doc(event.requestId)
      .create({...event, createdAt: FieldValue.serverTimestamp()}),
});

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
