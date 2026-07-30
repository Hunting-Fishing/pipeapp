# Phase 1 notification delivery

Pipe Buyer retains every notification in the signed-in user's private in-app
notification feed. Firebase Cloud Messaging adds an external delivery channel;
it does not replace the durable in-app record.

## Implemented controls

- Users explicitly enable or disable notifications from Account >
  Notifications.
- Android, iOS, and web notification endpoints are registered through
  App-Check-protected callable commands.
- Endpoints are stored under the authenticated user with a SHA-256 document
  identifier and cannot be written by clients.
- Lock-screen copy is generic and never includes private message text, report
  evidence, addresses, phone numbers, or offer terms.
- Notification routes are restricted to recognized listing, Auction, profile,
  conversation, and Dispatch-job deep links.
- Delivery is leased and event-addressed so Function retries do not start
  concurrent delivery for the same notification.
- Permanent invalid-token responses revoke the endpoint. Transient provider
  failures remain retryable.
- A complete failure for a critical notification creates a private
  administrator-readable failure record and structured Function error logs.
- Users may update only `read` and `readAt`; external delivery evidence is
  server-owned.
- The deployment build generates a Firebase Messaging service worker for the
  selected environment and requires its VAPID public key.

## External setup required

1. Enable the Firebase Cloud Messaging API in staging and production.
2. Create and store `PIPE_FIREBASE_WEB_PUSH_VAPID_KEY` in each protected GitHub
   Environment.
3. Register the Android app for FCM and confirm Android 13+ permission behavior.
4. Upload the Apple APNs authentication key to Firebase. The distribution
   provisioning profile must contain production Push Notifications; the mobile
   candidate workflow now rejects a profile that does not.
5. Exercise foreground, background, terminated, permission-denied, token
   refresh, sign-out, and invalid-token cases on physical devices.
6. Configure alert ownership for `notification_delivery_failures` and Cloud
   Function delivery errors.

Production delivery is not marked verified until this matrix is completed with
the exact release SHA. Provider activation is intentionally not performed by a
local build.
