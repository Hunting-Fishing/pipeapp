"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  NotificationDeliveryError,
  deliveryCopy,
  deliveryEventId,
  endpointDocumentId,
  invalidEndpointErrorCode,
  normalizeEndpointRegistration,
} = require("./notification_delivery_policy");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError ||
          error instanceof NotificationDeliveryError ||
          error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Notification endpoint command failed", error);
      throw new HttpsError(
          "internal",
          "Notification settings could not be updated. Please try again.",
      );
    }
  };
}

function createNotificationDelivery(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const registerNotificationEndpoint = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
    const endpoint = normalizeEndpointRegistration(request.data);
    await enforceUserRateLimit({db, admin, request, scope: "privacy"});
    const id = endpointDocumentId(identity.uid, endpoint.token);
    const reference = db.collection("users").doc(identity.uid)
        .collection("notification_endpoints").doc(id);
    const snapshot = await reference.get();
    await reference.set({
      ownerUid: identity.uid,
      token: endpoint.token,
      platform: endpoint.platform,
      installationId: endpoint.installationId,
      status: "active",
      updatedAt: FieldValue.serverTimestamp(),
      revokedAt: FieldValue.delete(),
      ...(!snapshot.exists ? {createdAt: FieldValue.serverTimestamp()} : {}),
    }, {merge: true});
    return {endpointId: id, active: true};
  });

  const unregisterNotificationEndpoint = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
    const endpoint = normalizeEndpointRegistration(request.data);
    await enforceUserRateLimit({db, admin, request, scope: "privacy"});
    const id = endpointDocumentId(identity.uid, endpoint.token);
    const reference = db.collection("users").doc(identity.uid)
        .collection("notification_endpoints").doc(id);
    const snapshot = await reference.get();
    if (snapshot.exists) {
      await reference.set({
        status: "revoked",
        revokedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        token: FieldValue.delete(),
      }, {merge: true});
    }
    return {endpointId: id, active: false};
  });

  const resolveNotificationDeliveryFailure = command(async (request) => {
    const administratorUid = requireAdministrator(request);
    const failureId = String(request.data && request.data.failureId || "").trim();
    const note = String(request.data && request.data.note || "").trim();
    if (!/^[a-f0-9]{64}$/.test(failureId)) {
      throw new NotificationDeliveryError(
          "invalid-argument", "The delivery failure reference is invalid.",
      );
    }
    if (note.length < 10 || note.length > 500) {
      throw new NotificationDeliveryError(
          "invalid-argument", "Add a 10-500 character resolution note.",
      );
    }
    const reference = db.collection("notification_delivery_failures").doc(failureId);
    const snapshot = await reference.get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "This delivery failure no longer exists.");
    }
    await reference.set({
      status: "resolved",
      resolutionNote: note,
      resolvedByUid: administratorUid,
      resolvedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {failureId, status: "resolved"};
  });

  const deliverNotification = async ({uid, notificationId, notification}) => {
    if (!uid || !notificationId || !notification) return null;
    if (notification.externalDelivery === false) return null;
    const eventId = deliveryEventId(uid, notificationId);
    const eventRef = db.collection("notification_delivery_events").doc(eventId);
    const notificationRef = db.collection("users").doc(uid)
        .collection("notifications").doc(notificationId);
    const leaseUntil = admin.firestore.Timestamp.fromMillis(Date.now() + 120000);
    const claimed = await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(eventRef);
      if (existing.exists) {
        const data = existing.data();
        if (data.status === "delivered" || data.status === "no_endpoint") {
          return false;
        }
        if (data.status === "processing" &&
            data.leaseUntil && data.leaseUntil.toMillis() > Date.now()) {
          return false;
        }
      }
      transaction.set(eventRef, {
        ownerUid: uid,
        notificationId,
        status: "processing",
        attemptCount: FieldValue.increment(1),
        leaseUntil,
        updatedAt: FieldValue.serverTimestamp(),
        ...(!existing.exists ? {createdAt: FieldValue.serverTimestamp()} : {}),
      }, {merge: true});
      return true;
    });
    if (!claimed) return null;

    const endpointSnapshot = await db.collection("users").doc(uid)
        .collection("notification_endpoints")
        .where("status", "==", "active")
        .limit(20)
        .get();
    const endpoints = endpointSnapshot.docs
        .map((document) => ({document, ...document.data()}))
        .filter((endpoint) => typeof endpoint.token === "string" &&
          endpoint.token.length >= 20);
    if (endpoints.length === 0) {
      await Promise.all([
        eventRef.set({
          status: "no_endpoint",
          completedAt: FieldValue.serverTimestamp(),
          leaseUntil: FieldValue.delete(),
        }, {merge: true}),
        notificationRef.set({
          externalDeliveryStatus: "no_endpoint",
          externalDeliveryUpdatedAt: FieldValue.serverTimestamp(),
        }, {merge: true}),
      ]);
      return {delivered: 0, failed: 0, noEndpoint: true};
    }

    const copy = deliveryCopy(notification);
    const messages = endpoints.map((endpoint) => ({
      token: endpoint.token,
      notification: {title: copy.title, body: copy.body},
      data: {
        notificationId,
        route: copy.route,
        type: copy.type,
      },
      android: {
        collapseKey: eventId,
        priority: copy.critical ? "high" : "normal",
        notification: {tag: eventId},
      },
      apns: {
        headers: {"apns-collapse-id": eventId},
        payload: {aps: {sound: copy.critical ? "default" : undefined}},
      },
      webpush: {
        headers: {Urgency: copy.critical ? "high" : "normal"},
        notification: {tag: eventId},
      },
    }));

    try {
      const response = await admin.messaging().sendEach(messages);
      const writer = db.bulkWriter();
      const failureCodes = [];
      response.responses.forEach((result, index) => {
        if (result.success) {
          writer.set(endpoints[index].document.ref, {
            lastDeliveredAt: FieldValue.serverTimestamp(),
            lastFailureCode: FieldValue.delete(),
          }, {merge: true});
          return;
        }
        const code = String(result.error && result.error.code || "unknown");
        failureCodes.push(code);
        writer.set(endpoints[index].document.ref, {
          lastFailedAt: FieldValue.serverTimestamp(),
          lastFailureCode: code.slice(0, 120),
          ...(invalidEndpointErrorCode(code) ? {
            status: "invalid",
            token: FieldValue.delete(),
            revokedAt: FieldValue.serverTimestamp(),
          } : {}),
        }, {merge: true});
      });
      await writer.close();
      const status = response.successCount > 0 ? "delivered" : "failed";
      await Promise.all([
        eventRef.set({
          status,
          deliveredCount: response.successCount,
          failedCount: response.failureCount,
          failureCodes: [...new Set(failureCodes)].slice(0, 10),
          completedAt: FieldValue.serverTimestamp(),
          leaseUntil: FieldValue.delete(),
        }, {merge: true}),
        notificationRef.set({
          externalDeliveryStatus: status,
          externalDeliverySuccessCount: response.successCount,
          externalDeliveryFailureCount: response.failureCount,
          externalDeliveryUpdatedAt: FieldValue.serverTimestamp(),
        }, {merge: true}),
      ]);
      if (response.successCount === 0 && copy.critical) {
        await db.collection("notification_delivery_failures").doc(eventId).set({
          ownerUid: uid,
          notificationId,
          notificationType: copy.type,
          critical: true,
          status: "open",
          failureCodes: [...new Set(failureCodes)].slice(0, 10),
          createdAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      return {
        delivered: response.successCount,
        failed: response.failureCount,
        noEndpoint: false,
      };
    } catch (error) {
      await eventRef.set({
        status: "retry",
        lastFailureCode: String(error && error.code || "unknown").slice(0, 120),
        leaseUntil: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      throw error;
    }
  };

  return {
    deliverNotification,
    registerNotificationEndpoint,
    resolveNotificationDeliveryFailure,
    unregisterNotificationEndpoint,
  };
}

module.exports = {createNotificationDelivery};
