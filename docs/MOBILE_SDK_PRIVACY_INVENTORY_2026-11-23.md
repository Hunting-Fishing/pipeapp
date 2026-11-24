# Pipe Buyer mobile SDK and privacy inventory — 2026-11-23

Status: engineering evidence draft. Privacy/legal approval, Apple App Privacy,
Google Data Safety, and store approval are **not complete**.

This inventory records dependencies and network/data surfaces visible in the
current source and lockfiles. It does not decide whether a store classifies a
particular transfer as collection, sharing, tracking, or a service-provider
operation. Those decisions require the exact signed candidate, provider terms,
backend/retention evidence, regional behavior, and privacy/legal approval.

## Evidence boundary

- Flutter dependencies are declared in `pubspec.yaml` and resolved in
  `pubspec.lock`; the versions below were also confirmed with
  `flutter pub deps --json`.
- Android uses compile/target SDK 36. Its checked-in build plugins include
  Android Gradle Plugin 8.11.1, Kotlin 2.2.21, Google Services 4.5.0, and the
  Firebase Crashlytics Gradle plugin 3.0.7.
- iOS targets iOS 15 and includes `ios/Runner/PrivacyInfo.xcprivacy`. The
  checked-in iOS tree has no `Package.resolved`, so the exact transitive Apple
  native graph must be exported from the final Xcode archive/build evidence.
- A dependency's presence is not proof that every feature or default collection
  mode is active. The confirmed source use and unresolved review questions are
  separated below.

Regenerate this inventory for every store candidate whenever a lockfile,
platform build file, SDK setting, backend provider, or data flow changes.

## Mobile and data-relevant SDKs

| SDK/group | Locked Flutter package versions | Confirmed source surface | Required disclosure/acceptance review |
| --- | --- | --- | --- |
| Firebase data plane | `firebase_core` 4.12.1; `cloud_firestore` 6.7.1; `cloud_functions` 6.3.5; `firebase_storage` 13.4.5 | Authentication-linked profiles, listings, offers, auctions, messages, reports, Dispatch records, callable commands, and user media use Firebase clients | Inventory every collection/object/callable payload, region, retention, deletion/export behavior, operator access, and downstream processor before answering either store |
| Firebase Authentication | `firebase_auth` 6.5.6 | Email/password, phone verification/MFA, Google, and Apple credential flows; user identifiers and provider profile fields are linked to app accounts | Confirm required/optional fields, identity linking, phone/SMS provider behavior, private-relay handling, token retention, and account deletion |
| Google and Apple sign-in | `google_sign_in` 6.3.0; `google_sign_in_android` 6.2.1; `google_sign_in_ios` 5.9.0; `sign_in_with_apple` 8.1.0 | Native Google sign-in and native iOS Apple sign-in feed Firebase credentials | Review provider disclosures for identifiers, email/name/photo availability, scopes, tokens, and account-link conflict handling; retain device acceptance for both providers |
| App integrity | `firebase_app_check` 0.4.5+2 | Release code selects Play Integrity on Android and App Attest with DeviceCheck fallback on Apple, enables token refresh, and can fail closed when `PIPE_APP_CHECK_REQUIRED=true`; the exact `flutter-flow-pipe` Android, iOS, and web apps have Play Integrity, App Attest, DeviceCheck, and reCAPTCHA configurations, while supported services remain unenforced | Validate real-device tokens, document integrity/app/device-token handling, confirm the future Play App Signing SHA-256, then stage enforcement only after valid-traffic monitoring |
| Push notifications | `firebase_messaging` 16.4.3 | Requests notification permission, obtains/refreshes FCM tokens, associates notification state with the signed-in user, and handles foreground/open events | Confirm token-to-user linkage, message metadata/content, lock-screen exposure, retention/deletion, consent/permission behavior, and notification processor terms |
| Diagnostics | `firebase_crashlytics` 5.2.6 | Crashlytics is disabled in native manifests by default and enabled by code only when explicitly requested for staging/production native builds; safe error context and stack traces are then sent. The unused `firebase_performance` dependency was removed on November 23 because the SDK automatically collects lifecycle and HTTP/S performance data when included | Verify final build flags, identifiers, stack traces, custom keys, retention, user opt-out requirements, and console settings. Re-admit Performance Monitoring only through a separately approved privacy and release change |
| Media selection and delivery | `image_picker` 1.2.3; `image_picker_android` 0.8.13+19; `image_picker_ios` 0.8.13+6; `cached_network_image` 3.4.1 | User-initiated camera/gallery selection supports listing, profile, message, report, credential, tax, and Dispatch media; uploads use Firebase Storage; remote listing/shop images are fetched in-app | Map photos/videos and embedded metadata from selection through resize/upload/storage/download/deletion. Review camera/photo permission copy and every automatic remote-image host request |
| Location and maps | `geolocator` 13.0.3; `geolocator_android` 4.6.2; `geolocator_apple` 2.3.14; `flutter_map` 8.3.1 | Foreground coarse/fine location is requested only in location/service-area flows; OpenStreetMap tiles and external geocoding/reverse-geocoding endpoints are called | Confirm when precise versus coarse location leaves the device, query retention, provider terms, IP/device metadata, user choice, and whether location is linked to account/listing/Dispatch records |
| Native billing | `in_app_purchase` 3.3.0; `in_app_purchase_android` 0.5.3; `in_app_purchase_storekit` 0.4.11+2 | Store product queries/purchase streams are present, but purchase controls depend on server-returned Apple/Google enablement and the current free-core test plan keeps native digital purchasing fail closed | Before activation, document product identifiers, store account/order identifiers, receipt/token transmission, verification, lifecycle notifications, restore/refund/revoke behavior, reconciliation, and retention separately for Apple and Google |
| Local preferences and database | `shared_preferences` 2.5.3; `shared_preferences_android` 2.4.10; `shared_preferences_foundation` 2.5.4; `sqflite` 2.4.3; `sqflite_android` 2.4.3; `sqflite_darwin` 2.4.3+1 | Preferences retain theme/language and selected device/notification/shop state; SQLite support is linked into native builds | Enumerate stored keys/tables from the exact candidate, verify no credentials or sensitive records use unencrypted preference storage, and distinguish local-only data from data transmitted off device |
| General network and external navigation | `http` 1.6.0; `url_launcher` 6.3.1 | Direct HTTP clients support geocoding, VIN decoding, generated API calls, and uploads; external marketplace, subscription-management, policy, regulator, and retailer URLs can open outside the app | Inventory request bodies/headers/query strings and automatic versus user-initiated requests. Disclose external-browser handoff and affiliate behavior accurately |
| Google Fonts | `google_fonts` 6.3.3 | Legacy unused `ThemeTypography` getters call `GoogleFonts.outfit` and `GoogleFonts.manrope`, but no current source calls those getters. The active `PipeBuyerTheme` uses bundled Plus Jakarta Sans assets | No Google Fonts request is reachable in the current entrypoint. Keep the legacy getters unreachable or remove/guard them before any future reuse; re-audit if typography wiring changes |

## Direct external service surfaces

These are source-observed destinations, not a claim that each provider receives
the same data in every journey.

| Service/destination | Trigger and possible request content | Release review |
| --- | --- | --- |
| Firebase/Google Cloud | Authentication, database, callables, media, push, diagnostics, and App Check | Match client behavior to Firebase project settings, Functions, retention/deletion, subprocessors, and all store answers |
| Apple and Google identity/store services | Sign-in, integrity, product lookup, purchase/restore, and subscription-management links | Review separate Apple/Google identifiers, tokens, purchase data, and server notifications before enabling billing |
| `tile.openstreetmap.org` | Map tile requests while viewing the location picker | Confirm tile-use policy, attribution, caching, and network metadata disclosure |
| `photon.komoot.io` | Default address autocomplete/reverse-geocoder queries | Confirm query/location/IP handling, terms, rate limits, regional routing, and privacy disclosure; replace with the approved proxy if required |
| `nominatim.openstreetmap.org` | Service-area lookup and reverse-geocoding queries | Confirm query/location/IP handling, User-Agent/contact policy, rate limits, and privacy disclosure |
| `vpic.nhtsa.dot.gov` | User-entered VIN decoding | Confirm whether VIN/search interaction must be disclosed and ensure no unrelated account data is sent |
| `ewywtstucdofdwvyqgpl.supabase.co` | Generated `NotinUse*` query definitions remain only in `lib/backend/api_requests/api_calls.dart`; no app/test source imports their API files or references those classes | No request is reachable in the current entrypoint and the dormant definitions are not a controlled-test blocker. Remove or keep them unreferenced, and re-audit before any future use |
| Google Fonts endpoints | Unused legacy Outfit/Manrope getters could fetch at runtime only if reintroduced; the active theme uses bundled Plus Jakarta Sans | No request is reachable in the current app. Keep a source-regression check or remove the dormant typography path before it can become active |
| Remote media/retailer domains | In-app images can load from Firebase Storage, user-provided hosts, and catalog hosts such as Amazon; taps can open retailer/affiliate destinations | Separate automatic image requests from explicit link taps, review affiliate disclosure, and restrict unsafe/unapproved remote media hosts where appropriate |

## Source-declared data categories

`ios/Runner/PrivacyInfo.xcprivacy` currently declares no tracking and lists 19
data types: name, email, phone, physical address, other
contact information, other financial information, precise and coarse location,
messages, photos/videos, customer support, other user content, user ID, device
ID, purchase history, product interaction, search history, crash data, and other
diagnostic data. Product interaction is declared for Analytics and App
Functionality because affiliate clicks can be stored with `actorUid`. Crash and
other diagnostic data are marked not linked; the other listed types are marked
linked.

These declarations are a conservative engineering input, not proof that the
manifest, Apple questionnaire, Google questionnaire, published privacy policy,
and actual production behavior agree. In particular, the final review must
decide for every flow:

1. whether data leaves the device and meets each store's definition of
   collection;
2. whether it is linked to identity, used for tracking, or shared under each
   store's definitions and provider relationships;
3. whether collection is required or optional and user initiated or automatic;
4. the purpose, retention period, deletion/export behavior, encryption, and
   regional/version differences; and
5. whether third-party SDK defaults or backend logs add data not represented by
   the client-facing feature.

## Candidate-close procedure

Before completing Apple App Privacy or Google Data Safety for a release:

1. Freeze the candidate SHA and committed version/build.
2. Save `flutter pub deps --json` with the acceptance evidence.
3. Export the Android release runtime dependency graph/SBOM from the protected
   candidate build, including native Google/Firebase/Billing versions.
4. Export the Xcode archive's resolved Swift/native dependencies, embedded
   privacy manifests, entitlements, and App Store privacy report. The repository
   currently has no checked-in `Package.resolved`, so this evidence is required.
5. Run a fresh-install network capture on physical Android and Apple devices for
   signed-out startup, each login method, location/map/geocoder, browsing and
   remote images, media upload, messaging/notifications, reporting, account
   export/deletion, diagnostics-enabled and diagnostics-disabled modes, and any
   admitted billing sandbox flow.
6. Compare the capture and backend logs to Firestore/Storage/Functions schemas,
   processor settings, retention schedules, public policy, and account-deletion
   results.
7. Have privacy/legal owners approve a versioned answer matrix, then enter it in
   both consoles and retain screenshots/exported evidence. Do not store reviewer
   credentials, identity documents, private keys, or other secrets in this file.

## Primary source pointers

- Dependency declarations: `pubspec.yaml`, `pubspec.lock`
- Android plugins/SDK/signing boundary: `android/settings.gradle`,
  `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`
- Apple declarations/permissions: `ios/Runner/PrivacyInfo.xcprivacy`,
  `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`
- Firebase/App Check: `lib/backend/firebase/firebase_config.dart`,
  `lib/backend/firebase/firebase_app_check_config.dart`
- Diagnostics: `lib/core/diagnostics/diagnostic_reporting_policy.dart`,
  `lib/core/diagnostics/diagnostic_reporting_native.dart`
- Notifications: `lib/marketplace/marketplace_notification_service.dart`
- Location/maps/geocoding: `lib/marketplace/marketplace_location_picker.dart`,
  `lib/marketplace/marketplace_service_area.dart`,
  `lib/marketplace/open_address_autocomplete.dart`
- Media: `lib/marketplace/marketplace_media_repository.dart`,
  `lib/marketplace/marketplace_messages_page.dart`,
  `lib/marketplace/marketplace_reporting.dart`
- Billing: `lib/marketplace/native_membership_billing.dart`
- Direct API calls: `lib/backend/api_requests/api_calls.dart`,
  `lib/marketplace/marketplace_serial_decoder.dart`
- Store submission boundary: `docs/STORE_RELEASE_METADATA.md`,
  `docs/MOBILE_STORE_RELEASE_READINESS_2026-11-23.md`
