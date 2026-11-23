# Pipe Buyer mobile-store release readiness — 2026-11-23

Status: the previously tested source/native-compile baseline is verified. The
current privacy and account-deletion delta is provisionally ready for exact-head
validation; controlled store testing remains blocked by that validation and the
external gates below. No signed distribution artifact, store submission,
production deployment, or paid-feature activation is authorized by this
document.

## Release source

This work started from clean remote `main` at
`402b410263178b2007b5250bf5040ec7b00f4873`, after PR #269. A branch and
worktree audit confirmed that current `main` already contains the recent Home,
Marketplace, Shop, directory, profile, affiliate, insurance, partner, admin,
navigation, performance, and responsive-UI improvements. Those changes were
not lost or left in an older app checkout.

PR #212 is deliberately not merged. It is based on an older product surface
and combines Apple work with unrelated Stripe, Marketplace, fee, settlement,
and UI changes. Only isolated, reviewable release improvements may be ported
from it.

## Source-side release work

The mobile-readiness branch completed these changes before it was proposed for
`main`:

- expose Sign in with Apple on native iOS wherever Google login is offered;
- declare the Apple capability, entitlement, and export-compliance answer;
- reject an Apple release profile that lacks the required Apple-login
  entitlement;
- cryptographically verify the Android AAB and require its signer certificate
  to match the protected upload key;
- bind requested store version/build values to the version committed in source;
- compile unsigned iOS and disposable-key Android release targets on pull
  requests, without retaining or uploading either artifact;
- pin the live mobile-link association documents in the release inputs so a
  normal Hosting deploy cannot silently remove them;
- selectively retain only messaging improvements that remain correct on the
  current account, routing, offer, and administrative implementation;
- update supported backend dependencies and retain zero production npm audit
  findings;
- pass the full Flutter, Functions, rules, release-tooling, web-build, and
  native-compile gates.

## Live store, account, and release-control findings

The authenticated November 23 App Store Connect audit confirmed Apple app ID
`6795847447`, bundle ID `Pipe.Buyerapp`, SKU `PIPE-BUYER-001`, and version
`1.0.0` in **Prepare for Submission**. No build is selected for that version.
The highest TestFlight build is `1.0.0 (9)`: its binary is validated, but it is
**Missing Compliance**, has no tester group or individual tester, and has no
**What to Test** text. Build 9 predates the current source work and its signed
entitlements do not include Sign in with Apple or Associated Domains, so it is
not a release candidate.

The same live audit found no release media: both the Dynamic-Island iPhone and
13-inch iPad sets show 0 of 3 previews and 0 of 10 screenshots, and the header
asset is 0 of 1. Description, promotional text, subtitle, and categories are
blank, and Support and Marketing still use the staging origin. On November 23,
the owner authorized and the live console verified **Manually release this
version**. The current content-rights answer says the
marketplace does not contain, show, or access third-party content and therefore
requires product/legal review before submission.

The Free Apps Agreement is active. The Paid Apps Agreement is **Pending User
Info**; DSA/trader status, banking, and U.S./Canadian tax information remain
incomplete. China mainland security-assessment, synthetic-content, and ICP
information is also incomplete. The approved controlled-test configuration now
excludes China mainland; App Store Connect shows 174 regions and China
**Processing to Not Available**, so those China-specific filings are not part
of the initial release scope.
The App Privacy page did not render, so the questionnaire could not be verified.
The monthly and yearly Dispatch products remain **Prepare for Submission**; the
sandbox server-notification URL exists, while the production URL is unset.

The authenticated Play Console review found developer account `366 Industries`
configured as Personal, with setup and identity verification incomplete,
trader status undeclared, contact-phone verification unavailable until the
identity review completes, and **Create app** disabled. No Play application
record exists, so there is no internal/closed track or console-confirmed Play
App Signing certificate yet. Google supports converting a fully verified
Personal account to Organization; for this LLC publisher, that is the
policy-aligned sequence. Complete verification, convert using the verified
organization website/payments profile/D-U-N-S details, wait Google's advised
72 hours, and only then create the app. Google does not promise that conversion
waives the closed-test rule, so retain a real closed-test plan. See Google's
[account conversion](https://support.google.com/googleplay/android-developer/answer/16260648?hl=en),
[account-type guidance](https://support.google.com/googleplay/android-developer/answer/13634885?hl=en-EN),
and [personal-account testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en).

Firebase Authentication currently has Email/Password, Phone, Google, and Apple
enabled. A follow-up API audit resolved an earlier project mix-up: the native
candidate is configured against Firebase project `flutter-flow-pipe`, not the
separate `pipebuyer-5c77f` staging project. In the exact candidate project,
Play Integrity, App Attest, DeviceCheck fallback, and web reCAPTCHA are already
configured. Firestore, Storage, Authentication, OAuth2, and Data Connect are all
**UNENFORCED**, matching the approved monitoring-only state. Physical-device
token acceptance remains Gate 5 evidence; enforcement is a later deliberate
rollout after valid-traffic monitoring.

The owner-approved controlled-test setup now restricts both `production` and
`mobile-release-production` deployments to `main` and requires approval from
the repository's only admin account, `Hunting-Fishing`. Existing environment
secrets and variables were preserved. This is an intentionally solo-owner
repository, so self-review prevention remains disabled; the owner's explicit
environment approval is the manual release gate. The production Environment
still lacks `PIPE_ANDROID_APP_SIGNING_SHA256`, which cannot be finalized until
the Play app and Play App Signing certificate exist. Staging environments were
not changed.

The `main` branch is also protected for the solo-owner workflow: it requires an
up-to-date branch and successful Android and Apple native preflight checks,
enforces the rules for administrators, requires linear history and resolved
conversations, and blocks force-pushes and deletion. Pull requests require zero
approving reviews, so the sole owner is not deadlocked. The preflight workflow
now runs for every pull request to `main`, preventing path-filtered changes from
waiting forever on checks that were never created.

The live Apple Developer audit confirmed that the active App Store profile for
`Pipe.Buyerapp` includes App Attest, Associated Domains, Push Notifications,
Sign in with Apple, In-App Purchase, Apple Pay, StoreKit external-purchase
capabilities, and Wallet, and expires July 29, 2027. Its decoded entitlements
contain the production push environment, Associated Domains, Sign in with
Apple, and both App Attest environments. The protected CI secret cannot be read
back; its update timing is consistent with this profile but is not proof of
identity. The exact candidate workflow must decode the protected profile and
verify the signed archive entitlements. Regenerate the profile only if that
proof fails or the approved capability set changes. Public release remains
blocked on the Play-console-confirmed public fingerprint and the remaining
external gates.

The committed source version is now `1.0.5+10`: it preserves the current product
version and uses the first shared build number above Apple's confirmed build 9.
No Play app record or accepted Android version code exists, so build 10 has no
known Google collision. Before any Apple upload, change the App Store Connect
version record from `1.0.0` to `1.0.5`; the candidate workflow will reject any
requested version/build that differs from source. Once build 10 is processed by
either store, every replacement must use build 11 or higher.

Never copy bank, tax, identity, private-key, service-account, reviewer-login,
or other secret values into source, CI logs, screenshots, or this document.

## First real-world test scope

The first candidate should be a controlled free-core/internal-testing build.
It may recognize an existing valid membership, but it must not route native
digital-subscription purchasing through Stripe and must keep native Apple and
Google purchase verification fail closed until their independent store
products, credentials, server reconciliation, and acceptance matrices pass.

This scope allows real users to test account creation, Apple/Google/email/phone
login, browsing, listings, wanted ads, offers, timed buying, messaging,
reporting, account deletion, and eligible Dispatch workflows without using an
unapproved native billing path.

## Mobile release gates

| Gate | Current boundary | Completion evidence |
| --- | --- | --- |
| 0 — Source reconciliation | Complete for the audited baseline | Remote-main identity plus branch/worktree/PR comparison |
| 1 — Mobile compliance source | Complete and verified for the baseline; current privacy/deletion delta pending exact-head evidence | Apple login, privacy/export declarations, account deletion, permissions, association contracts, and current-SDK unsigned iOS compile pass; signed entitlements remain Gate 4 evidence |
| 2 — Release and dependency controls | Complete and verified for the baseline; current delta pending exact-head evidence | Full local gate plus Android/iOS preflight CI pass with zero production dependency advisories |
| 3 — Store records and owner agreements | Active; 4 of 8 subchecks verified | Apple app/build records, Firebase authentication providers, exact-project App Check registration, and GitHub production protections verified; Apple owner agreements, Google identity/account type, and Google app/testing records remain open; store-aligned version/signing is only partial |
| 4 — Exact signed candidates | Pending after Gates 1–3 | Current-main AAB and IPA, unique console-confirmed build number, hashes, certificates, and store processing records |
| 5 — Internal physical-device acceptance | Pending | TestFlight and Play internal/closed-track matrix on supported phone/tablet devices |
| 6 — Store content and review | Pending | Approved screenshots, descriptions, App Privacy/Data Safety, ratings, app access, review notes, and reviewer acceptance |
| 7 — Controlled public rollout | Pending | Manual owner go/no-go, monitoring, support coverage, rollback, staged rollout, and post-release checks |

The older Phase 1 ledger's `99% overall`, `Gate 7 86%`, and `4 of 8` figures are
explicitly historical and provisional. They are not a substitute for the
mobile gates above and must not be reported as present store approval.

Current mobile-store checkpoint: **37.5% overall (3 of 8 gates), verified for
the baseline and provisional for the current privacy/deletion delta**. The
active Gate 3 is **50% verified (4 of 8 defined live subchecks)**. These
percentages describe evidence completed as of November 23, 2026; they are not
estimates of store-review approval or elapsed calendar time.

The engineering privacy matrix is now drafted in
[`STORE_PRIVACY_ANSWER_MATRIX_2026-11-23.md`](STORE_PRIVACY_ANSWER_MATRIX_2026-11-23.md),
but no store privacy answers are approved or submitted. Immediate account
deletion is implemented in source. On Apple devices, the client performs fresh
Apple reauthentication and calls Firebase Auth's official
`revokeTokenWithAuthorizationCode` API before requesting deletion; the backend
uses a short-lived authorization record to enforce normal-client sequencing,
but it does not receive the Apple authorization code or cryptographically prove
that revocation succeeded. The configured external deletion-request email path
is designed to meet Google Play's external-request requirement. These remain
release blockers until the Functions/web changes are deployed, the inbox and
ownership-verification runbook are proven operational, and a physical Apple
device demonstrates successful revocation/deletion against the exact signed
candidate.

The November 23 privacy-policy source edits are a proposed revision, not a new
effective policy. Privacy/legal approval and deliberate production publication
are required before its effective date or version may change.

A Pixel 8 Android 16/API 36 emulator came online, but no device acceptance is
credited: the repository has no mobile integration harness, the local Flutter
tool selected incompatible JDK 25, and the bounded JDK 21 isolated-cache retry
stalled during dependency resolution before producing or installing an APK.
The protected Android compile is green; this result is a local tooling blocker,
not a confirmed runtime pass or an app-source failure.

The earlier baseline completed with clean Dart analysis, 664 Flutter tests, 36
repository-control tests, both Functions suites and linters, zero npm audit
findings, syntax checks, and a release web build. The Android AAB
disposable-signing compile and current-App-Store-SDK unsigned iOS compile also
passed on exact baseline commit `aff013cfc97e1dfdea5bc217c0a370c3aba62358` in
[mobile preflight run 45113439343](https://github.com/Hunting-Fishing/pipeapp/actions/runs/45113439343).
The baseline repository gate passed in
[quality run 45113455182](https://github.com/Hunting-Fishing/pipeapp/actions/runs/45113455182).
These runs predate the current privacy and deletion changes and are not
exact-head release evidence; exact-head results must replace this paragraph
after the branch is pushed.
Neither run produced a store-distribution artifact or store acceptance.

## Physical-device acceptance matrix

Retain timestamped evidence for the exact AAB/IPA and release commit:

- fresh install, update, relaunch, background/foreground, and sign-out/sign-in;
- email/password, phone, Google, and native iOS Apple login, including Apple
  private relay, cancellation, account conflict, and MFA where applicable;
- App Attest/DeviceCheck and Play Integrity/App Check token acceptance;
- notification permission, token refresh, foreground/background receipt, tap
  routing, and privacy-safe lock-screen text;
- HTTPS app/universal links for apex and `www` hosts plus legacy custom links;
- camera, gallery, denied permission, foreground location, interrupted upload,
  offline, slow network, and session expiry;
- listing, wanted ad, offer, timed-buying, messaging, reporting, support,
  export, and account-deletion journeys;
- VoiceOver/TalkBack, 200% text, contrast, keyboard/switch navigation where
  applicable, portrait/landscape, phone/tablet, and smallest supported OS;
- no native Stripe digital-subscription purchase path in the free-core cohort;
- crash, performance, backend error, abuse, and support-monitoring review.

## Store rollout sequence

1. Keep draft PR #270 unmerged while the external owner gates remain open.
2. Finish Play identity setup, convert to Organization, wait 72 hours, and
   create the Play app; do not submit organization identity or trader details
   from repository logs or chat.
3. Complete the remaining Apple owner gates: DSA/trader status, paid agreement,
   tax and banking information where applicable, App Privacy, export compliance,
   approved production URLs and metadata, and media. Manual release is selected
   and China mainland is excluded from the initial scope.
4. Validate App Check tokens on physical Android and Apple devices, prove that
   the protected CI profile matches the current active Apple profile and
   required signed entitlements, and confirm the future Play App Signing
   SHA-256. Regenerate the Apple profile only if the proof fails or capabilities
   change; leave App Check enforcement off through the observation period.
5. Production environments are now owner-approval-gated and `main`-only for the
   solo-owner workflow. Store the console-confirmed Android fingerprint when the
   Play app exists.
6. Apple build 9 is the current confirmed ceiling, so shared candidate identity
   `1.0.5+10` is reserved. Confirm no Play collision after its app record exists;
   if build 10 is uploaded anywhere, increment before any replacement upload.
7. Merge only after owner review, then build the exact committed `main` SHA
   through the protected mobile release environment.
8. Upload Android to an internal/closed track and iOS to TestFlight; do not
   select a public release.
9. Complete the matrix with named owner/tester evidence and preserve the
   acceptance bundle.
10. Complete store metadata and submit for review with manual release selected.
11. After approval and owner confirmation, release to a limited cohort or use
   the stores' phased/staged release controls. Monitor authentication, App
   Check, crashes, messages, uploads, notifications, support, and deletion.
12. Pause or halt rollout on any identity, data-loss, payment, security,
   moderation, or crash regression. Promote only after the observation window
   is clean.
13. For every update, increment the committed build number, repeat automated
   and device gates in proportion to risk, attach release notes, and retain the
   exact artifact-to-commit evidence.

## Separate paid-membership track

Paid native membership is a later, separately approved track. Apple and Google
must each have approved product metadata, a store-specific server credential,
server-authoritative verification, lifecycle notifications, reconciliation,
restore/renew/cancel/refund/revoke coverage, conflict prevention with Stripe,
monitoring, and sandbox/TestFlight/Play acceptance. Enabling one provider does
not authorize the other provider or any broader Marketplace/Dispatch money
movement.
