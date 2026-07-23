# Firebase App Check rollout

App Check protects Firebase resources from requests that do not originate from
a registered Pipe Buyer client. It complements Firebase Authentication; it does
not replace user identity, authorization rules, rate limits, or moderation.

This repository deliberately stages App Check before enforcing it. Do not turn
on enforcement until registered clients have been distributed and the Firebase
App Check request metrics show that legitimate traffic is producing valid
tokens.

## Current application registrations

- Firebase project: `flutter-flow-pipe`
- Web Firebase app ID: `1:426221783223:web:179633eb8c8378e6e26532`
- Android application ID: `Pipe.Buyerapp`
- Apple bundle ID: `Pipe.Buyerapp`

Confirm these identifiers in Firebase Console before registration. Correct any
production identifier or signing configuration before distributing a release.

## Stage 1 — Register attestation providers

In Firebase Console, open **App Check > Apps** and register:

1. Web with the supported reCAPTCHA provider. Record the public site key.
2. Android with Play Integrity. Link the Firebase Google Cloud project in the
   Google Play Console and confirm the production signing certificate.
3. iOS and macOS with App Attest and DeviceCheck fallback.

The compatible FlutterFire generation currently pinned by this application
does not activate App Check for native Windows or Linux builds. Do not mark
those builds as enforcement-ready. Web on Windows remains supported.

## Stage 2 — Build token-producing clients

Production web builds must supply the registered public site key and require a
successful App Check bootstrap:

```powershell
flutter build web `
  --dart-define=PIPE_APP_CHECK_WEB_RECAPTCHA_KEY=PUBLIC_SITE_KEY `
  --dart-define=PIPE_APP_CHECK_REQUIRED=true
```

Android, iOS, and macOS release builds use Play Integrity or App Attest with
DeviceCheck fallback automatically. Build those releases with:

```powershell
flutter build appbundle --dart-define=PIPE_APP_CHECK_REQUIRED=true
```

Use the equivalent release command for the Apple target.

For local web testing, provide the same public site key. The localhost-only
bootstrap in `web/index.html` asks Firebase for a per-browser debug token. Copy
the token printed in the browser console into Firebase Console under the web
app's App Check debug tokens. Never commit a debug token.

Mobile debug builds use the Firebase debug provider. Register each printed
debug token in Firebase Console and remove obsolete tokens when a developer or
device no longer needs access.

If the web key is omitted while `PIPE_APP_CHECK_REQUIRED` is false, the app
continues in staged mode and logs that App Check is inactive. If readiness is
required, a missing key or unsupported platform stops startup instead of
silently shipping an unprotected client.

## Stage 3 — Monitor before enforcement

Deploy and distribute the token-producing clients while enforcement remains
off. Review Firebase App Check metrics for callable Functions, Firestore, and
Storage. Confirm:

- current web and mobile releases produce valid requests;
- development and administrative workflows have registered debug tokens;
- unsupported or retired clients are understood;
- authentication, uploads, messages, offers, auctions, and Dispatch workflows
  still complete normally;
- support has a rollback owner and a user communication plan.

## Stage 4 — Enforce callable Functions

Callable enforcement is compiled into the callable deployment options from the
strict boolean deployment environment value `PIPE_ENFORCE_APP_CHECK`. It
defaults to `false`; only the exact value `true` enables enforcement.

Create the ignored project-specific environment file
`firebase/functions/.env.flutter-flow-pipe`:

```dotenv
PIPE_ENFORCE_APP_CHECK=true
```

From `firebase/`, deploy the Functions codebase:

```powershell
firebase deploy --only functions:marketplace --project flutter-flow-pipe
```

Verify a registered release succeeds and an unregistered client receives an
App Check rejection. Monitor Functions errors, support reports, and valid versus
invalid request metrics immediately after deployment.

To roll back callable enforcement, set the deployment value to `false` and redeploy
the same reviewed commit. Do not weaken Firestore rules as a workaround.

## Stage 5 — Enforce Firebase products

Only after callable enforcement is stable, enable Firestore and Storage
enforcement from Firebase Console one product at a time. Observe metrics and
run the complete buyer, seller, auction, messaging, avatar, reporting, and
Dispatch acceptance journeys after each change.

App Check does not authorize data access. Firestore and Storage rules remain
the source of truth for which authenticated user may read or change a record.
