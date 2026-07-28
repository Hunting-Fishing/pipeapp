# Archived iOS notification service extension

These files were found under `ios/ImageNotification` but were not referenced by
the Xcode project, did not have an Xcode target, and depended on
`FirebaseMessaging` while the Flutter application has no `firebase_messaging`
dependency. They therefore did not provide push notification delivery and were
removed from the active iOS platform tree during the Phase 1 release audit.

Do not copy this folder back as if it were operational. External notifications
remain a Gate 5 blocker. A future implementation must add and test all of the
following together:

- approved notification product behavior, permissions, and privacy language;
- Firebase Messaging Flutter dependency and application initialization;
- APNs key/certificate and Firebase project configuration;
- an Xcode notification-service target only if rich media is required;
- bundle identifier, entitlements, capabilities, provisioning, and Pod support;
- token registration/revocation, server delivery, retries, user preferences,
  opt-out, quiet hours, and delivery-failure alerting;
- physical-device foreground, background, terminated, denied-permission, and
  token-rotation acceptance evidence.

The original `Info.plist` and `NotificationService.swift` are retained beside
this note solely as recoverable reference material.
