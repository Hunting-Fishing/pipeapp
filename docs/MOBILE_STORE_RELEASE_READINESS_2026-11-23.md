# Pipe Buyer mobile-store release readiness — 2026-11-23

Status: source and native compile candidate verified; controlled store testing
remains blocked by the external gates below. No signed distribution artifact,
store submission, production deployment, or paid-feature activation is
authorized by this document.

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

Historical App Store Connect evidence from October 2026 identified Apple app
ID `6795847447`, bundle ID `Pipe.Buyerapp`, an uploaded `1.0.0 (9)` build, and
prepared monthly/yearly Dispatch products. App Store Connect redirected the
November 23 read-only review to a signed-out login, so those facts are not
current enough to authorize a candidate. The Account Holder must sign in and
recheck agreements, Digital Services Act status, banking, tax, privacy answers,
product status, highest build number, capabilities, and manual release mode.

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
enabled. Firebase App Check, however, shows Android, iOS, and Web as not
registered, with the reviewed product APIs unenforced. Play Integrity and Apple
App Attest/DeviceCheck registration plus real-device token acceptance are
required before controlled external testing; enforcement is a later deliberate
rollout after valid-traffic monitoring, not an assumption made by this branch.

A November 23 read-only GitHub check found that `production`, `staging`,
`mobile-release-production`, and `mobile-release-staging` have no required
reviewer rules or deployment branch policy. The production Environment also
lacks `PIPE_ANDROID_APP_SIGNING_SHA256`, and the protected iOS provisioning
profile predates the newly required Apple login and Associated Domains
capabilities. Public release remains blocked until an owner deliberately adds
the environment protections, the Play-console-confirmed public fingerprint,
and a regenerated Apple profile. Those external mutations are not made by this
source branch.

The committed source version is currently `1.0.5+6`. It must not be used for a
signed candidate because its build number is lower than the historically
observed Apple build 9. After both consoles are current, commit one shared
version/build greater than every accepted store build; the candidate workflow
will reject any requested value that differs from source.

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
| 1 — Mobile compliance source | Complete and verified for source/compile scope | Apple login, privacy/export declarations, account deletion, permissions, association contracts, and current-SDK unsigned iOS compile pass; signed entitlements remain Gate 4 evidence |
| 2 — Release and dependency controls | Complete and verified for source/compile scope | Full local gate plus Android/iOS preflight CI pass with zero production dependency advisories |
| 3 — Store records and owner agreements | Active; 1 of 8 subchecks verified | Firebase providers verified; Apple live records, Apple agreements, Google identity/account type, Google app/testing records, App Check, GitHub protections, and store-aligned version/signing remain open |
| 4 — Exact signed candidates | Pending after Gates 1–3 | Current-main AAB and IPA, unique console-confirmed build number, hashes, certificates, and store processing records |
| 5 — Internal physical-device acceptance | Pending | TestFlight and Play internal/closed-track matrix on supported phone/tablet devices |
| 6 — Store content and review | Pending | Approved screenshots, descriptions, App Privacy/Data Safety, ratings, app access, review notes, and reviewer acceptance |
| 7 — Controlled public rollout | Pending | Manual owner go/no-go, monitoring, support coverage, rollback, staged rollout, and post-release checks |

The older Phase 1 ledger's `99% overall`, `Gate 7 86%`, and `4 of 8` figures are
explicitly historical and provisional. They are not a substitute for the
mobile gates above and must not be reported as present store approval.

Current mobile-store checkpoint: **37.5% overall verified (3 of 8 gates)**.
The active Gate 3 is **12.5% verified (1 of 8 defined live subchecks)**. These
percentages describe evidence completed as of November 23, 2026; they are not
estimates of store-review approval or elapsed calendar time.

Local verification for this branch completed with clean Dart analysis, 664
Flutter tests, 36 repository-control tests, both Functions suites and linters,
zero npm audit findings, syntax checks, and a release web build. The Android
AAB disposable-signing compile and current-App-Store-SDK unsigned iOS compile
also passed on exact commit `4f36bd129c10f99c3dbd8b33e55bccafc6247371` in
[mobile preflight run 45109548962](https://github.com/Hunting-Fishing/pipeapp/actions/runs/45109548962).
The exact-SHA repository gate passed in
[quality run 45109569638](https://github.com/Hunting-Fishing/pipeapp/actions/runs/45109569638).
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
3. Sign in to App Store Connect and verify the app, agreements, compliance,
   products, privacy answers, and highest accepted build.
4. Register the native apps with Firebase App Check, validate real-device
   tokens, regenerate the Apple profile with every required capability, and
   confirm the Play App Signing SHA-256.
5. Add required-reviewer and `main`-only protections to production release
   environments, then store the console-confirmed Android fingerprint.
6. Read the highest build number in both consoles; commit one higher shared
   `major.minor.patch+build` value before producing candidates.
7. Merge only after owner review, then build the exact committed `main` SHA
   through the protected mobile release environment.
8. Upload Android to an internal/closed track and iOS to TestFlight; do not
   select a public release.
9. Complete the matrix with named reviewers and preserve the acceptance bundle.
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
