# Pipe Buyer mobile-store release readiness — 2026-11-23

Status: active release-candidate preparation. No store submission or paid-feature
activation is authorized by this document.

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

The mobile-readiness branch is responsible for these changes before it may be
proposed for `main`:

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

## Store and account facts that require live re-verification

Historical App Store Connect evidence from October 2026 identified Apple app
ID `6795847447`, bundle ID `Pipe.Buyerapp`, an uploaded `1.0.0 (9)` build, and
prepared monthly/yearly Dispatch products. That evidence is not current enough
to authorize submission. The Account Holder must recheck agreements, Digital
Services Act status, banking, tax, privacy answers, product status, build list,
and release mode in the live portal.

The live Android association document identifies package `Pipe.Buyerapp` and a
Play app-signing certificate, but the current Play Console application, highest
accepted `versionCode`, account verification, testing requirement, Data Safety
answers, app access instructions, and listing state still require authenticated
console review.

A November 23 read-only GitHub check found that `production`, `staging`,
`mobile-release-production`, and `mobile-release-staging` have no required
reviewer rules or deployment branch policy. The production Environment also
lacks `PIPE_ANDROID_APP_SIGNING_SHA256`, and the protected iOS provisioning
profile predates the newly required Apple login and Associated Domains
capabilities. Public release remains blocked until an owner deliberately adds
the environment protections, the Play-console-confirmed public fingerprint,
and a regenerated Apple profile. Those external mutations are not made by this
source branch.

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
| 1 — Mobile compliance source | Locally verified; native CI pending | Apple login, privacy/export declarations, account deletion, permissions, and association contracts pass |
| 2 — Release and dependency controls | Local gates complete; native CI pending | Full local gate plus Android/iOS preflight CI pass with zero production dependency advisories |
| 3 — Store records and owner agreements | Pending authenticated review | Apple/Google account, agreement, tax/banking, identity, app-record, product, policy, and release-mode evidence |
| 4 — Exact signed candidates | Pending after Gates 1–3 | Current-main AAB and IPA, unique console-confirmed build number, hashes, certificates, and store processing records |
| 5 — Internal physical-device acceptance | Pending | TestFlight and Play internal/closed-track matrix on supported phone/tablet devices |
| 6 — Store content and review | Pending | Approved screenshots, descriptions, App Privacy/Data Safety, ratings, app access, review notes, and reviewer acceptance |
| 7 — Controlled public rollout | Pending | Manual owner go/no-go, monitoring, support coverage, rollback, staged rollout, and post-release checks |

The older Phase 1 ledger's `99% overall`, `Gate 7 86%`, and `4 of 8` figures are
explicitly historical and provisional. They are not a substitute for the
mobile gates above and must not be reported as present store approval.

Local verification for this branch completed with clean Dart analysis, 664
Flutter tests, 36 repository-control tests, both Functions suites and linters,
zero npm audit findings, syntax checks, and a release web build. The Android
AAB and iOS application still require the new GitHub native preflight on the
committed branch before Gates 1 or 2 can be called fully verified.

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

1. Merge only after code review and all source/CI gates pass.
2. Read the highest build number in both consoles; commit one higher shared
   `major.minor.patch+build` value before producing candidates.
3. Build the exact committed `main` SHA through the protected mobile release
   environment.
4. Upload Android to the internal track and iOS to TestFlight; do not select a
   public release.
5. Complete the matrix with named reviewers and preserve the acceptance bundle.
6. Complete store metadata and submit for review with manual release selected.
7. After approval and owner confirmation, release to a limited cohort or use
   the stores' phased/staged release controls. Monitor authentication, App
   Check, crashes, messages, uploads, notifications, support, and deletion.
8. Pause or halt rollout on any identity, data-loss, payment, security,
   moderation, or crash regression. Promote only after the observation window
   is clean.
9. For every update, increment the committed build number, repeat automated
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
