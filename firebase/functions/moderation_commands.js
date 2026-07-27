"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  ModerationPolicyError,
  appealDeadlineMillis,
  validateModerationAppeal,
  validateModerationAppealDecision,
  validateModerationDecision,
} = require("./moderation_policy");

function requiredId(data, fieldName) {
  const value = String(data && data[fieldName] || "").trim();
  if (!value || value.length > 180 || value.includes("/")) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} is missing or invalid.`,
    );
  }
  return value;
}

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError ||
          error instanceof AdministratorAuthorizationError ||
          error instanceof ModerationPolicyError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Moderation command failed", error);
      throw new HttpsError(
          "internal",
          "The Trust & Safety action could not be completed.",
      );
    }
  };
}

function receiptId(actorUid, commandName, requestId) {
  return crypto.createHash("sha256")
      .update(`${actorUid}|${commandName}|${requestId}`)
      .digest("hex");
}

function timestampMillis(value) {
  return value && typeof value.toMillis === "function" ? value.toMillis() : 0;
}

function createModerationCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  function receiptReference(actorUid, commandName, requestId) {
    return db.collection("moderation_command_receipts")
        .doc(receiptId(actorUid, commandName, requestId));
  }

  function eventReference(reportId, requestId) {
    return db.collection("trust_report_events")
        .doc(`${reportId}-${requestId}`);
  }

  function noticeReference(reportId) {
    return db.collection("moderation_notices").doc(reportId);
  }

  function notificationReference(uid, reportId, event) {
    return db.collection("users").doc(uid).collection("notifications")
        .doc(`moderation-${reportId}-${event}`);
  }

  function targetReference(report) {
    if (report.targetType === "listing" && report.listingId) {
      return db.collection("public_listings").doc(String(report.listingId));
    }
    if (report.targetType === "message" && report.conversationId &&
        report.messageId) {
      return db.collection("conversations")
          .doc(String(report.conversationId))
          .collection("messages").doc(String(report.messageId));
    }
    return null;
  }

  const reviewModerationReport = command(async (request) => {
    const administratorUid = requireAdministrator(request);
    await enforceUserRateLimit({
      db,
      admin,
      request,
      scope: "administration",
    });
    const reportId = requiredId(request.data, "reportId");
    const requestId = requiredId(request.data, "requestId");
    const {decision, reason, enforcementAction} =
      validateModerationDecision(request.data);
    const reportRef = db.collection("trust_reports").doc(reportId);
    const receiptRef = receiptReference(
        administratorUid,
        "reviewModerationReport",
        requestId,
    );

    return db.runTransaction(async (transaction) => {
      const [receiptSnapshot, reportSnapshot] = await Promise.all([
        transaction.get(receiptRef),
        transaction.get(reportRef),
      ]);
      if (receiptSnapshot.exists) return receiptSnapshot.data().result;
      if (!reportSnapshot.exists) {
        throw new HttpsError("not-found", "This moderation case is unavailable.");
      }
      const report = reportSnapshot.data();
      if (!["pending", "information_requested"].includes(report.status)) {
        throw new HttpsError(
            "failed-precondition",
            "This moderation case has already received a final decision.",
        );
      }
      const targetRef = enforcementAction === "content_removed" ?
        targetReference(report) : null;
      const targetSnapshot = targetRef ? await transaction.get(targetRef) : null;
      if (enforcementAction === "content_removed" &&
          (!targetRef || !targetSnapshot.exists)) {
        throw new HttpsError(
            "failed-precondition",
            "The reported content cannot be removed because it is unavailable.",
        );
      }
      const status = decision;
      const result = {reportId, status, enforcementAction};
      const appealDeadline = decision === "violation_confirmed" ?
        Timestamp.fromMillis(appealDeadlineMillis(Date.now())) : null;
      transaction.update(reportRef, {
        status,
        decision,
        reviewReason: reason,
        enforcementAction,
        reviewedByUid: administratorUid,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        ...(appealDeadline ? {appealDeadline} : {}),
      });
      transaction.create(eventReference(reportId, requestId), {
        reportId,
        event: "reviewed",
        status,
        decision,
        enforcementAction,
        reason,
        actorUid: administratorUid,
        createdAt: FieldValue.serverTimestamp(),
      });
      if (targetRef && targetSnapshot) {
        if (report.targetType === "listing") {
          transaction.update(targetRef, {
            moderationStatus: "removed",
            moderationReportId: reportId,
            preModerationStatus: targetSnapshot.data().status || "active",
            status: "moderation_removed",
            updatedAt: FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(targetRef, {
            moderationVisibility: "hidden",
            moderationReportId: reportId,
            moderatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
      if (decision === "violation_confirmed") {
        transaction.set(noticeReference(reportId), {
          reportId,
          reportedUid: report.reportedUid,
          targetType: report.targetType,
          reasonLabel: report.reasonLabel || report.reason || "Safety concern",
          status,
          decision,
          enforcementAction,
          reviewReason: reason,
          appealAvailable: true,
          appealDeadline,
          updatedAt: FieldValue.serverTimestamp(),
          createdAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      if (report.source === "user" && report.reporterUid) {
        transaction.set(
            notificationReference(report.reporterUid, reportId, status),
            {
              recipientUid: report.reporterUid,
              type: "moderation_report_reviewed",
              title: decision === "information_requested" ?
                "More report information is needed" : "Safety report reviewed",
              message: reason,
              reportId,
              status,
              read: false,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
      }
      if (decision === "violation_confirmed") {
        transaction.set(
            notificationReference(report.reportedUid, reportId, status),
            {
              recipientUid: report.reportedUid,
              type: "moderation_decision",
              title: "Trust & Safety decision",
              message: reason,
              reportId,
              status,
              enforcementAction,
              read: false,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
      }
      transaction.create(receiptRef, {
        actorUid: administratorUid,
        command: "reviewModerationReport",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  });

  const appealModerationDecision = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request);
    await enforceUserRateLimit({db, admin, request, scope: "reporting"});
    const reportId = requiredId(request.data, "reportId");
    const requestId = requiredId(request.data, "requestId");
    const {reason} = validateModerationAppeal(request.data);
    const reportRef = db.collection("trust_reports").doc(reportId);
    const receiptRef = receiptReference(
        identity.uid,
        "appealModerationDecision",
        requestId,
    );
    return db.runTransaction(async (transaction) => {
      const [receiptSnapshot, reportSnapshot] = await Promise.all([
        transaction.get(receiptRef),
        transaction.get(reportRef),
      ]);
      if (receiptSnapshot.exists) return receiptSnapshot.data().result;
      if (!reportSnapshot.exists) {
        throw new HttpsError("not-found", "This moderation decision is unavailable.");
      }
      const report = reportSnapshot.data();
      if (report.reportedUid !== identity.uid) {
        throw new HttpsError(
            "permission-denied",
            "Only the affected account can appeal this decision.",
        );
      }
      if (report.status !== "violation_confirmed") {
        throw new HttpsError(
            "failed-precondition",
            "Only a confirmed violation can be appealed.",
        );
      }
      const deadline = timestampMillis(report.appealDeadline);
      if (!deadline || deadline < Date.now()) {
        throw new HttpsError(
            "failed-precondition",
            "The 30-day appeal period has ended.",
        );
      }
      const result = {reportId, status: "appealed"};
      transaction.update(reportRef, {
        status: "appealed",
        appealReason: reason,
        appealedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(noticeReference(reportId), {
        status: "appealed",
        appealAvailable: false,
        appealReason: reason,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.create(eventReference(reportId, requestId), {
        reportId,
        event: "appealed",
        status: "appealed",
        reason,
        actorUid: identity.uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(receiptRef, {
        actorUid: identity.uid,
        command: "appealModerationDecision",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  });

  const reviewModerationAppeal = command(async (request) => {
    const administratorUid = requireAdministrator(request);
    await enforceUserRateLimit({
      db,
      admin,
      request,
      scope: "administration",
    });
    const reportId = requiredId(request.data, "reportId");
    const requestId = requiredId(request.data, "requestId");
    const {decision, reason} = validateModerationAppealDecision(request.data);
    const reportRef = db.collection("trust_reports").doc(reportId);
    const receiptRef = receiptReference(
        administratorUid,
        "reviewModerationAppeal",
        requestId,
    );
    return db.runTransaction(async (transaction) => {
      const [receiptSnapshot, reportSnapshot] = await Promise.all([
        transaction.get(receiptRef),
        transaction.get(reportRef),
      ]);
      if (receiptSnapshot.exists) return receiptSnapshot.data().result;
      if (!reportSnapshot.exists || reportSnapshot.data().status !== "appealed") {
        throw new HttpsError(
            "failed-precondition",
            "This appeal is no longer awaiting review.",
        );
      }
      const report = reportSnapshot.data();
      const targetRef = decision === "overturned" &&
          report.enforcementAction === "content_removed" ?
        targetReference(report) : null;
      const targetSnapshot = targetRef ? await transaction.get(targetRef) : null;
      const status = decision === "upheld" ? "appeal_upheld" :
        "appeal_overturned";
      const result = {reportId, status};
      transaction.update(reportRef, {
        status,
        appealDecision: decision,
        appealReviewReason: reason,
        appealReviewedByUid: administratorUid,
        appealReviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (targetRef && targetSnapshot && targetSnapshot.exists) {
        if (report.targetType === "listing" &&
            targetSnapshot.data().moderationReportId === reportId) {
          transaction.update(targetRef, {
            status: targetSnapshot.data().preModerationStatus || "active",
            moderationStatus: "overturned",
            moderationReportId: FieldValue.delete(),
            preModerationStatus: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        } else if (report.targetType === "message" &&
            targetSnapshot.data().moderationReportId === reportId) {
          transaction.update(targetRef, {
            moderationVisibility: FieldValue.delete(),
            moderationReportId: FieldValue.delete(),
            moderatedAt: FieldValue.delete(),
          });
        }
      }
      transaction.set(noticeReference(reportId), {
        status,
        appealDecision: decision,
        appealReviewReason: reason,
        appealAvailable: false,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.create(eventReference(reportId, requestId), {
        reportId,
        event: "appeal_reviewed",
        status,
        decision,
        reason,
        actorUid: administratorUid,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
          notificationReference(report.reportedUid, reportId, status),
          {
            recipientUid: report.reportedUid,
            type: "moderation_appeal_reviewed",
            title: decision === "overturned" ?
              "Trust & Safety decision overturned" : "Appeal decision upheld",
            message: reason,
            reportId,
            status,
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.create(receiptRef, {
        actorUid: administratorUid,
        command: "reviewModerationAppeal",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  });

  return {
    appealModerationDecision,
    reviewModerationAppeal,
    reviewModerationReport,
  };
}

module.exports = {createModerationCommands};
