# Mobile release and accessibility baseline

Status: Engineering baseline verified locally; store signing and physical-device
acceptance remain pending.

## Product identity

The user-facing product name is **Pipe Buyer** on Android, iOS, web, Windows,
Linux, and macOS. Public metadata must not contain the FlutterFlow template name
or the former `PipeApp` display name.

The existing Android application ID and Apple bundle ID remain
`Pipe.Buyerapp`. They match the currently installed Firebase registrations and
must not be changed as an incidental source edit. A future identifier migration
requires coordinated Firebase, App Store, Play Console, deep-link, signing, and
upgrade-path approval.

## Android release signing

`android/key.properties` is excluded from source control. A release build is
allowed only when it contains all four fields and the referenced keystore
exists:

```properties
storeFile=C:/secure/path/pipe-buyer-upload.jks
storePassword=provided-out-of-band
keyAlias=pipe-buyer-upload
keyPassword=provided-out-of-band
```

The build rejects an incomplete configuration before producing an APK or AAB.
It never falls back to the debug signing key. Keep the upload keystore and
passwords in the approved secret manager, record recovery ownership, and use a
Play App Signing upload key for production distribution.

Locally verified on July 28, 2026:

- Android ARM64 debug APK built successfully with the release configuration
  present in the Gradle model.
- A dry-run release task without `key.properties` failed with the intended,
  actionable signing diagnostic.

Production completion still requires a real repository-excluded keystore,
signed AAB, Play Console upload validation, and install/upgrade testing on
supported physical devices.

## Media and location disclosures

Android declares camera access for user-initiated captures and no longer opts
into legacy external storage. iOS explains camera, photo-library, and foreground
location use. Store privacy declarations must be checked against the final
runtime behavior before submission.

## Accessibility baseline

The application theme enforces padded Material touch targets with a minimum of
48 logical pixels for icon buttons and primary button controls. Important
icon-only actions now expose visible tooltips and explicit semantic labels.
Automated widget coverage verifies minimum target size, a 200 percent text-scale
scenario, and an accessible icon action.

The baseline does not replace human acceptance. Gate 6 still requires:

- TalkBack and VoiceOver journey testing;
- keyboard-only web and desktop testing, including visible focus order;
- contrast review for all state and analytics colors;
- 200 percent text testing across authentication, listing, offer, auction,
  messaging, reporting, support, and Dispatch workflows;
- portrait/landscape and phone/tablet layout checks;
- camera, gallery, denied-permission, expired-session, offline, slow-network,
  retry, and interrupted-upload tests;
- Apple archive validation, privacy manifest review, capabilities, signing, and
  TestFlight installation;
- final icons, splash screens, store screenshots, support URL, and approved
  policy URLs.

No gate is complete until the corresponding signed artifact and physical-device
acceptance evidence are retained with the release record.
