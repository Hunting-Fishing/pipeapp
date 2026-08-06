# Pipe Buyer Firebase and Store Publication Runbook

Status: production release procedure  
Firebase production project: `flutter-flow-pipe`  
Web domain: `https://www.pipebuyer.com`  
Android application ID: `Pipe.Buyerapp`  
Apple bundle ID: `Pipe.Buyerapp`

## Release boundary

Publish only an exact commit that:

1. is contained in `main`
2. has a fully successful `Quality` workflow
3. keeps payments, token purchases, custody, settlement, refunds, payouts, and
   commission collection disabled unless a separate paid-feature release has
   passed provider, legal, operational, webhook, and reconciliation approval
4. has retained release-manifest and deployment evidence

## 1. GitHub protected environments

The repository uses these protected environments:

- `staging`
- `production`
- `mobile-release-production`

### Production Firebase variables

Configure these as GitHub Environment variables in `production`:

- `PIPE_FIREBASE_API_KEY`
- `PIPE_FIREBASE_AUTH_DOMAIN`
- `PIPE_FIREBASE_PROJECT_ID` = `flutter-flow-pipe`
- `PIPE_FIREBASE_STORAGE_BUCKET`
- `PIPE_FIREBASE_MESSAGING_SENDER_ID`
- `PIPE_FIREBASE_WEB_APP_ID`
- `PIPE_FIREBASE_MEASUREMENT_ID` when Analytics is enabled
- `PIPE_PUBLIC_SUPPORT_EMAIL`
- `PIPE_APP_CHECK_WEB_RECAPTCHA_KEY`
- `PIPE_FIREBASE_WEB_PUSH_VAPID_KEY`

Configure these as GitHub Environment secrets in `production`:

- `PIPE_DEPLOY_ENVIRONMENT_GUARD` = `production`
- `FIREBASE_TOKEN`
- `PIPE_APP_CHECK_WEB_DEBUG_TOKEN` for controlled visual acceptance only

Do not store payment-provider secrets in Flutter variables or Firestore.
Future Stripe, PayPal, webhook, and settlement secrets belong in protected
server secret storage and remain unused while payments are disabled.

### Mobile release variables

Copy the reviewed Firebase public configuration variables into
`mobile-release-production` and configure:

- `MOBILE_RELEASE_ENVIRONMENT_GUARD` = `mobile-release-production`
- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_UPLOAD_STORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`
- Apple distribution certificate and password required by the workflow
- Apple provisioning profile for bundle ID `Pipe.Buyerapp`
- App Store Connect API issuer, key ID, and private key required by the workflow

Secret values must be entered directly in GitHub or the provider console and
must never be committed or pasted into issues, pull requests, logs, or chat.

## 2. Firebase Console production configuration

Complete these checks in project `flutter-flow-pipe`:

- Billing is enabled for production Functions and other paid Firebase services.
- Web, Android, and Apple apps are registered with the exact identifiers used
  by the repository.
- Authentication providers required at launch are enabled.
- `pipebuyer.com`, `www.pipebuyer.com`, and the Firebase Hosting domains are in
  Authentication > Settings > Authorized domains.
- The public support email and OAuth consent branding identify Pipe Buyer.
- Firestore is in the intended production region.
- Storage is in the intended production region and uses the reviewed rules.
- Cloud Functions use the reviewed region and runtime.
- Cloud Messaging has the web VAPID key configured.
- Apple push notifications have an approved APNs authentication key or
  certificate when iOS notifications are enabled.
- Budget alerts, billing alerts, Crashlytics, and operational contacts are
  configured.

## 3. App Check

Register every production app before enforcement:

- Android: Play Integrity for `Pipe.Buyerapp`
- Apple: App Attest or DeviceCheck for `Pipe.Buyerapp`
- Web: the approved Firebase web App Check provider and production site key

Verify real production builds first. Then deploy with `app_check_mode=enforce`.
Do not enforce a Firebase product until its legitimate production app traffic
is receiving valid App Check tokens.

## 4. Domain and OAuth

In Firebase Hosting, connect both:

- `pipebuyer.com`
- `www.pipebuyer.com`

Keep the Firebase ownership TXT record in DNS and add every A, AAAA, or CNAME
record shown by Firebase. Wait for Firebase to report the domain as connected
and the TLS certificate as active.

In Firebase Authentication and the Google OAuth client configuration:

- authorize the production domain
- authorize the Firebase Hosting domains
- confirm the redirect handler works on the production domain
- verify `/about`, `/privacy`, and `/terms` return HTTP 200 and identify Pipe
  Buyer

## 5. Administrator accounts

The approved administrator accounts are:

- `jordilwbailey@gmail.com`
- `goldcity4u@icloud.com`

Before provisioning, each account must:

1. exist in Firebase Authentication
2. have a verified email address
3. enroll Firebase multi-factor authentication

Then run the reviewed script in `firebase/functions` with production operator
credentials. Use the dry-run commands in `docs/ADMIN_ROLE_PROVISIONING.md`,
review the resolved UID, and apply with the exact UID and production-project
confirmation. The script sets custom claims, writes the role and audit record,
and revokes existing sessions.

Each administrator must sign in again and complete MFA before the Admin Portal
appears.

## 6. Production Firebase deployment

After the release PR is merged and the exact `main` commit is green:

1. Open GitHub Actions.
2. Select `Deploy verified Firebase release`.
3. Select `Run workflow`.
4. Set environment to `production`.
5. Paste the full 40-character green `main` commit SHA.
6. Set App Check mode to `enforce` only after Section 3 is verified.
7. Run the workflow and do not bypass the protected environment gate.

The workflow performs analysis, Flutter tests, Functions checks, security-rules
emulator tests, authenticated callable tests, production web build, exact-SHA
manifest generation, Firebase deployment, deployed-Function parity checks, and
mobile/desktop web visual acceptance.

Retain the `firebase-release-evidence-*` artifact and the workflow URL.

## 7. Android publication

- Create or verify the Google Play application for package `Pipe.Buyerapp`.
- Enroll in Play App Signing.
- Keep the upload key separate from the Google-managed app-signing key.
- Add the Play app-signing SHA-1 and SHA-256 certificate fingerprints to the
  Android app in Firebase.
- Complete the Data safety form, privacy-policy URL, content rating, target
  audience, app access instructions, ads declaration, contact details, store
  listing, screenshots, and country availability.
- Link the Play application for Play Integrity/App Check.
- Run `Build signed mobile release candidates` with the exact green `main` SHA,
  production environment, semantic version, and a new positive build number.
- Download the signed `.aab` artifact, verify its SHA-256 evidence, and upload
  it to an internal test track first.
- Complete internal testing, closed/open testing requirements when applicable,
  pre-launch report review, then promote the approved build to production.

The repository currently compiles and targets Android API 36.

## 8. Apple publication

- Verify the Apple Developer team owns App ID `Pipe.Buyerapp`.
- Confirm the distribution certificate and App Store provisioning profile named
  by the release configuration are valid.
- Register the Apple app in Firebase with bundle ID `Pipe.Buyerapp`.
- Add the APNs authentication key in Firebase when notifications are enabled.
- Create the App Store Connect app and complete privacy details, age rating,
  export-compliance answers, support URL, privacy-policy URL, app description,
  keywords, screenshots, review contact, and review notes.
- Run `Build signed mobile release candidates` using the exact green `main` SHA
  and a build number not previously uploaded.
- Upload the signed IPA through the controlled release workflow or approved
  App Store Connect tooling.
- Test through TestFlight, resolve review findings, select the approved build,
  and submit it for App Review.

## 9. Final launch acceptance

Before public rollout, verify:

- production web sign-in and sign-out
- administrator MFA and role visibility
- listing creation, image upload, browse, search, saved listings, messaging,
  reporting, auctions, and Dispatch according to enabled feature flags
- Firestore and Storage denied-access behavior
- callable command retries and idempotency
- notifications on supported web, Android, and Apple devices
- `/about`, `/privacy`, and `/terms`
- domain TLS and OAuth redirects
- monitoring, budget alerts, support inbox, incident contacts, backups, and
  rollback ownership
- billing/payment readiness still reports disabled unless a later approved
  paid-feature release has been deployed

Record the released commit SHA, Firebase deployment workflow, mobile candidate
workflow, store build numbers, approval dates, and retained evidence artifacts.
