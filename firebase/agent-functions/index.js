"use strict";

const functions = require("firebase-functions/v1");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {getApps, initializeApp} = require("firebase-admin/app");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const {
  AgentPolicyError,
  createAgentHandler,
  loadAgentConfiguration,
} = require("./agent_policy");
const {
  ExpIntegrationError,
  buildPublicIntegrationStatus,
  dispatchLeadToConfiguredCrms,
  syncCreaDdfToFirestore,
  validateSafeExternalHttpsUrl,
  verifyRealtorLicensePublicRegistry,
} = require("./exp_realty_integrations");

if (getApps().length === 0) initializeApp();

const enforceAppCheck = String(process.env.PIPE_ENFORCE_APP_CHECK || "")
    .trim()
    .toLowerCase() === "true";

const v2BaseOptions = Object.freeze({
  cpu: 0.25,
  concurrency: 1,
});

function requireV2Administrator(request) {
  if (!request || !request.auth) {
    throw new HttpsError(
        "unauthenticated",
        "Sign in before using administrator tools.",
    );
  }
  const token = request.auth.token || {};
  const firebase = token.firebase || {};
  const hasSecondFactor = typeof firebase.sign_in_second_factor === "string" &&
    firebase.sign_in_second_factor.trim() !== "";
  const hasPrimaryAdminClaim = token.primaryAdmin === true &&
    token.email_verified === true;
  if (token.admin !== true || token.role !== "administrator" ||
      (!hasSecondFactor && !hasPrimaryAdminClaim)) {
    throw new HttpsError(
        "permission-denied",
        "Administrator privileges are required.",
    );
  }
  return request.auth.uid;
}

async function notifyActiveAdmins(db, notification) {
  const roles = await db.collection("administrator_roles")
      .where("active", "==", true)
      .get();
  if (roles.empty) return;
  const notificationId = String(notification.notificationId || "").trim();
  const payload = {...notification};
  delete payload.notificationId;
  await Promise.all(roles.docs.map((roleDoc) => {
    const col = db.collection("users").doc(roleDoc.id).collection("notifications");
    const ref = notificationId ? col.doc(notificationId) : col.doc();
    return ref.set({
      ...payload,
      recipientUid: roleDoc.id,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }));
}

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

exports.manageExpRealtyIntegrations = onCall(
    {
      ...v2BaseOptions,
      enforceAppCheck,
      timeoutSeconds: 60,
    },
    async (request) => {
      const adminUid = requireV2Administrator(request);
      const db = getFirestore();
      const secretRef = db.collection("platform_secrets").doc("exp_realty_credentials");
      const publicConfigRef = db
          .collection("platform_configuration")
          .doc("exp_realty_integration");
      const data = request.data && typeof request.data === "object" ?
        request.data :
        {};
      const action = String(data.action || "getStatus").trim();

      try {
        if (action === "getStatus") {
          const snap = await secretRef.get();
          return buildPublicIntegrationStatus(snap.exists ? snap.data() : {});
        }

        if (action === "saveCredentials") {
          const snap = await secretRef.get();
          const current = snap.exists ? snap.data() : {};
          const next = {...current};

          if (typeof data.boldTrailEnabled === "boolean") {
            next.boldTrailEnabled = data.boldTrailEnabled;
          }
          if (typeof data.boldTrailApiToken === "string" &&
              data.boldTrailApiToken.trim() !== "") {
            next.boldTrailApiToken = data.boldTrailApiToken.trim();
          } else if (data.clearBoldTrailToken === true) {
            delete next.boldTrailApiToken;
          }

          if (typeof data.loftyEnabled === "boolean") {
            next.loftyEnabled = data.loftyEnabled;
          }
          if (typeof data.loftyApiKey === "string" &&
              data.loftyApiKey.trim() !== "") {
            next.loftyApiKey = data.loftyApiKey.trim();
          } else if (data.clearLoftyKey === true) {
            delete next.loftyApiKey;
          }

          if (typeof data.webhookEnabled === "boolean") {
            next.webhookEnabled = data.webhookEnabled;
          }
          if (typeof data.webhookUrl === "string") {
            const trimmedUrl = data.webhookUrl.trim();
            next.webhookUrl = trimmedUrl ?
              validateSafeExternalHttpsUrl(trimmedUrl) :
              "";
          }
          if (typeof data.webhookSigningSecret === "string" &&
              data.webhookSigningSecret.trim() !== "") {
            next.webhookSigningSecret = data.webhookSigningSecret.trim();
          } else if (data.clearWebhookSecret === true) {
            delete next.webhookSigningSecret;
          }

          if (typeof data.creaDdfAutoSyncEnabled === "boolean") {
            next.creaDdfAutoSyncEnabled = data.creaDdfAutoSyncEnabled;
          }
          if (typeof data.creaDdfClientId === "string" &&
              data.creaDdfClientId.trim() !== "") {
            next.creaDdfClientId = data.creaDdfClientId.trim();
          }
          if (typeof data.creaDdfClientSecret === "string" &&
              data.creaDdfClientSecret.trim() !== "") {
            next.creaDdfClientSecret = data.creaDdfClientSecret.trim();
          } else if (data.clearCreaDdfCredentials === true) {
            delete next.creaDdfClientId;
            delete next.creaDdfClientSecret;
          }
          if (typeof data.creaDdfOdataFilter === "string") {
            next.creaDdfOdataFilter = data.creaDdfOdataFilter.trim().slice(0, 400);
          }
          next.creaDdfSellerUid = adminUid;
          next.updatedAt = FieldValue.serverTimestamp();
          next.updatedByUid = adminUid;

          await secretRef.set(next);
          const summary = buildPublicIntegrationStatus(next);
          await publicConfigRef.set({
            crmAutoSyncReady: Boolean(
                (summary.boldTrailEnabled && summary.boldTrailConfigured) ||
                (summary.loftyEnabled && summary.loftyConfigured) ||
                (summary.webhookEnabled && summary.webhookConfigured),
            ),
            creaDdfConfigured: summary.creaDdfConfigured,
            creaDdfAutoSyncEnabled: summary.creaDdfAutoSyncEnabled,
            updatedAt: FieldValue.serverTimestamp(),
            updatedByUid: adminUid,
          }, {merge: true});
          return summary;
        }

        if (action === "testCrmLead") {
          const snap = await secretRef.get();
          const creds = snap.exists ? snap.data() : {};
          const dispatchResult = await dispatchLeadToConfiguredCrms({
            leadId: `test_lead_${Date.now()}`,
            lead: {
              requesterName: "Pipe Buyer CRM Test",
              requesterEmail: "crm-test@pipebuyer.com",
              requesterPhone: "+15875550100",
              inquiryType: "Buyer Representation (Test)",
              listingId: "test-site-property",
              listingTitle: "10-Acre Industrial Pipe Yard — Test Verification",
              locationLabel: "Nisku, Alberta, Canada",
              notes: "Automated test ping from Pipe Buyer Admin Settings.",
            },
            credentials: creds,
          });
          return dispatchResult;
        }

        if (action === "verifyLicense") {
          const verification = await verifyRealtorLicensePublicRegistry({
            jurisdiction: String(data.jurisdiction || ""),
            licenseNumber: String(data.licenseNumber || ""),
            agentName: String(data.agentName || ""),
          });
          const applicantUid = String(data.applicantUid || "").trim();
          if (applicantUid) {
            await db.collection("realtor_agent_applications")
                .doc(applicantUid)
                .set({
                  registryLookupUrl: verification.lookupUrl,
                  registryVerification: {
                    ...verification,
                    verifiedLicenseFingerprint:
                      `${verification.jurisdiction}::${verification.queriedLicense}`,
                  },
                }, {merge: true});
          }
          return verification;
        }

        if (action === "testCreaDdf" || action === "syncCreaDdf") {
          const snap = await secretRef.get();
          const creds = snap.exists ? snap.data() : {};
          const dryRun = action === "testCreaDdf";
          const syncSummary = await syncCreaDdfToFirestore({
            db,
            FieldValue,
            credentials: creds,
            actorUid: adminUid,
            dryRun,
          });
          if (!dryRun) {
            await secretRef.set({
              lastDdfSyncIso: syncSummary.syncedAt,
              lastDdfSyncSummary: syncSummary,
              updatedAt: FieldValue.serverTimestamp(),
            }, {merge: true});
          }
          return syncSummary;
        }

        throw new HttpsError(
            "invalid-argument",
            `Unsupported eXp Realty integration action: ${action}`,
        );
      } catch (error) {
        if (error instanceof HttpsError) throw error;
        if (error instanceof ExpIntegrationError) {
          throw new HttpsError(error.code, error.message);
        }
        console.error("manageExpRealtyIntegrations failed:", error);
        throw new HttpsError(
            "internal",
            "The eXp Realty integration request could not be completed.",
        );
      }
    },
);

exports.onExpRealtyLeadCreated = onDocumentCreated(
    {
      ...v2BaseOptions,
      document: "exp_realty_leads/{leadId}",
    },
    async (event) => {
      if (!event.data) return null;
      const lead = event.data.data() || {};
      const leadId = event.params.leadId;
      const db = getFirestore();

      await notifyActiveAdmins(db, {
        notificationId: `exp-lead-${leadId}`,
        type: "exp_realty_lead",
        title: "New eXp Realty property representation inquiry",
        body: `${lead.listingTitle || "Property inquiry"} • ${lead.inquiryType || "Lead"} (${lead.requesterEmail || "signed-in user"})`,
        leadId,
        listingId: lead.listingId || null,
      });

      const secretSnap = await db
          .collection("platform_secrets")
          .doc("exp_realty_credentials")
          .get();
      if (!secretSnap.exists) return null;

      const syncSummary = await dispatchLeadToConfiguredCrms({
        lead,
        leadId,
        credentials: secretSnap.data(),
      });
      await event.data.ref.set({
        crmSyncStatus: syncSummary.status,
        crmSyncAttempted: syncSummary.attempted,
        crmSyncSucceeded: syncSummary.succeeded,
        crmSyncResults: syncSummary.results,
        crmSyncedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return null;
    },
);

exports.onRealtorApplicationWritten = onDocumentWritten(
    {
      ...v2BaseOptions,
      document: "realtor_agent_applications/{uid}",
    },
    async (event) => {
      if (!event.data || !event.data.after.exists) return null;
      const after = event.data.after.data() || {};
      if (after.status !== "pending") return null;

      const jurisdiction = String(after.jurisdiction || "").trim();
      const rawLicense = String(after.licenseNumber || "").trim();
      if (!rawLicense) return null;

      const fingerprint = `${jurisdiction}::${rawLicense.toUpperCase().replace(/[^A-Z0-9 .-]/gu, "")}`;
      const existingCheck = after.registryVerification || {};
      if (existingCheck.verifiedLicenseFingerprint === fingerprint) {
        return null;
      }

      const db = getFirestore();
      let verification;
      try {
        verification = await verifyRealtorLicensePublicRegistry({
          jurisdiction,
          licenseNumber: rawLicense,
          agentName: String(after.agentName || ""),
        });
      } catch (error) {
        verification = {
          jurisdiction,
          liveGovApi: false,
          status: `Registry check deferred: ${error && error.message || "unavailable"}`,
          checkedAt: new Date().toISOString(),
        };
      }

      await event.data.after.ref.set({
        registryLookupUrl: verification.lookupUrl || "",
        registryVerification: {
          ...verification,
          verifiedLicenseFingerprint: fingerprint,
        },
      }, {merge: true});

      await notifyActiveAdmins(db, {
        notificationId: `realtor-app-${event.params.uid}-${Date.now()}`,
        type: "realtor_application",
        title: "New Realtor license verification application",
        body: `${after.agentName || after.email || "Applicant"} (${jurisdiction} • License #${rawLicense})`,
        applicantUid: event.params.uid,
      });
      return null;
    },
);

exports.scheduledExpRealtyCreaDdfSync = onSchedule(
    {
      ...v2BaseOptions,
      schedule: "every 24 hours",
      timeoutSeconds: 180,
    },
    async () => {
      const db = getFirestore();
      const [publicSnap, secretSnap] = await Promise.all([
        db.collection("platform_configuration").doc("exp_realty_integration").get(),
        db.collection("platform_secrets").doc("exp_realty_credentials").get(),
      ]);
      if (!publicSnap.exists || publicSnap.data().enabled !== true) return;
      if (!secretSnap.exists || secretSnap.data().creaDdfAutoSyncEnabled !== true) {
        return;
      }
      const creds = secretSnap.data();
      const summary = await syncCreaDdfToFirestore({
        db,
        FieldValue,
        credentials: creds,
        actorUid: creds.creaDdfSellerUid || "scheduled-crea-ddf-sync",
        dryRun: false,
      });
      await secretSnap.ref.set({
        lastDdfSyncIso: summary.syncedAt,
        lastDdfSyncSummary: summary,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    },
);
