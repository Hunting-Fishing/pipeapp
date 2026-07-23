# Phase 1 progress audit

Audit date: July 23, 2026

Branch: `agent/account-verification-controls`

Audited commit baseline: Gate 1 environment and deployment checkpoint

## Completion rule

A gate is marked complete only when every mandatory workflow in that gate has
reviewed source, error handling, automated tests, staging acceptance evidence,
a deployment record, and a rollback procedure. A working screen or callable
present only in source counts as partial implementation, not completion.

Percentages are conservative engineering estimates based on the mandatory
checklist in `PHASE_1_LAUNCH_FINALIZATION_PLAN.md`:

- complete and evidenced item: full credit
- implemented but not deployed or end-to-end verified: partial credit
- placeholder, unsafe direct write, or missing lifecycle: no completion credit

## Gate status

| Gate | Complete | Estimate | Current evidence |
| --- | --- | ---: | --- |
| 0 — Scope lock and safe defaults | **Yes** | **100%** | Runtime flags, build locks, callable/rules enforcement, unit/emulator coverage, and clean CI pass. An isolated staging rehearsal proved the missing-configuration case denies Marketplace, Auction, regulated-property, paid-boost, and Dispatch direct writes and cleans up its disposable identity. |
| 1 — Environments, builds, diagnostics | No | 82% | `flutter-flow-pipe` remains the single production backend. Isolated staging project `pipebuyer-5c77f` now has separate Web, Android, and iOS registrations, Standard Firestore in `nam5`, deployed rules/indexes, provisioned Email/Password Auth, runtime project locks, passing staging Web/Android builds, the seven public GitHub Environment values, a proven Hosting deployment/rollback, a default-off native Crashlytics adapter, and repeatable mobile/desktop web visual checks. Staging Storage/Functions, App Check, Workload Identity, environment reviewer protection, CI full-service deployment, data recovery proof, approved monitoring ownership/native-device evidence remain incomplete. |
| 2 — Backend parity and commands | No | 76% | The 37 reviewed Function exports include idempotent account-verification sync, saved-listing, Marketplace listing lifecycle, offer completion, auction finalization/settlement, and the complete Dispatch award-to-closure command. Direct clients cannot author authoritative verification, saved, listing revision, reserve, offer, bid, settlement, delivery-proof, default-report, dispute, or Dispatch state. A real Auth, Firestore, and Functions emulator suite verifies 37 command receipts and repeated-request idempotency, including expired-auction winner calculation, Marketplace confirmations, Dispatch delivery closure, and verified-identity enforcement. Unit-tested release automation rejects missing, unexpected, or inactive deployed handlers. Staging deployment and exact deployed parity remain blocked on the billing-plan decision. |
| 3 — Identity and abuse protection | No | 35% | Signup and sign-in now enter a cross-platform ownership screen until the Firebase Auth email and mobile-phone providers are verified. Protected Marketplace, Offer, Auction, and Dispatch commands require verified Auth claims; phone uniqueness is provided by Firebase Auth and synchronized into a hashed, server-owned registry. Forged verification/profile/registry writes and unverified Dispatch signup are denied in emulator tests. Staging Phone Auth/App Check activation, MFA, rate limits, recovery, deletion, export, and administrator claim migration remain incomplete. |
| 4 — Product workflows | No | 64% | Saved listings and normal listing lifecycle are locally verified. Offers and winning auctions have participant-only confirmations, controlled disputes/default reports, notifications, and immutable history. Dispatch awards now create participant-only transactions with carrier acceptance, scheduling, in-transit, structured delivery proof, customer closure, pre-transit cancellation, dispute, administrator resolution, notifications, and immutable history. Payment release/refund, provider approval, truck-route calculation, and carrier billing remain incomplete. |
| 5 — Trust, notifications, policies | No | 15% | User reporting with attachments and some in-app notifications exist. Moderation operations, appeals, delivery providers, policies, and support operations remain incomplete. |
| 6 — Accessibility, performance, QA | No | 15% | Money/phone formatting and some mobile widget coverage exist. Accessibility, bounded data performance, device/network matrices, and abuse/load testing remain incomplete. |
| 7 — Release readiness | No | 5% | A quality workflow exists. Staging rehearsal, operational ownership, backups, rollback proof, launch review, and monitoring are not complete. |

Overall Phase 1 launch readiness estimate: **56%**.

Completed gates: **1 of 8**.

## Mandatory workflow audit

### Accounts and profiles

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Email ownership | Source and emulator verified; staging pending | Signup and incomplete sign-ins are held on the account-ownership screen. Protected commands require the Firebase Auth `email_verified` claim, and the callable emulator proves an unverified user cannot publish. Staging email-link acceptance remains required. |
| Phone ownership | Source and emulator verified; staging pending | Web uses Firebase phone-link confirmation and native clients use OTP credentials linked to the existing account. Protected Marketplace/Offer/Auction/Dispatch commands require the Firebase Auth phone claim. Firebase Auth provides provider-level uniqueness; a callable synchronizes a SHA-256 registry key and verified profile fields that clients cannot forge. Phone Auth, authorized web domains, APNs/SHA configuration, quota and physical-device acceptance remain pending. |
| Account verification meaning | Incomplete | `accountVerified` is driven by profile readiness/review rather than an approved identity-verification workflow. |
| Administrator verification queue | Incomplete | Users can submit `verification_requests`; no complete administrator queue, evidence review, decision, notification, and audit workflow exists. |
| Account deletion | Incomplete | No user-facing coordinated Auth, Firestore, Storage, and registry deletion workflow. |
| Data export | Incomplete | No user-facing export request, generation, download, or audit workflow. |
| Administrator MFA | Incomplete | No MFA enrollment or enforcement evidence. |
| Session/device management | Incomplete | No device list, session revocation, or suspicious-session workflow. |

### Marketplace

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Persisted saved listings | Source and emulator verified; staging pending | Save and unsave use an idempotent server command, restore from `users/{uid}/saved_listings` after authentication, use consistent document IDs, and render live listing documents. Rules deny cross-user reads, direct saved-state writes, and forged save analytics. Staging acceptance remains outstanding. |
| Listing lifecycle | Source and emulator verified; staging pending | Normal listings have revision-safe server commands and owner UI for editing, pause/reactivate, mark sold, archive, and relist. Immutable owner/admin revision history is enforced. Staging deployment and acceptance evidence remain outstanding. |
| Search and filtering | Incomplete | Browse loads the active collection and performs search, filters, and sorting on the client. |
| Pagination/geospatial search | Incomplete | No cursor pagination or bounded server/geospatial query workflow. |
| Home notification action | Resolved in source | The former dead Home bell is no longer exposed. Account Notifications remains the working destination. |
| View/See all actions | Resolved in source | Featured `See all` opens Browse and offer revision history opens its complete history dialog. |
| Help placeholder | Resolved in source | The dead drawer item was removed pending a real support workflow. |
| Wanted ads and RFQs | Source repaired; verification pending | The drawer now opens Create Listing preselected as a Wanted ad rather than redirecting to ordinary Browse. |
| Shareable routes | Incomplete | GoRouter currently exposes only `/`; entity routes and deep-link restoration are absent. |

### Offers and transactions

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Live Offer commands | Source only; live incomplete | `createMarketplaceOffer` and `acceptMarketplaceOffer` exist in source and are used by Flutter, but are absent from the deployed `flutter-flow-pipe` Functions inventory. |
| Post-acceptance lifecycle | Source and emulator verified; staging pending | Acceptance creates a participant-only transaction. Buyer and seller confirmations advance independently and both are required to complete the sale; early cancellation reopens the listing, disputes preserve the pending sale, and each transition is revisioned and idempotent. |
| Terminal states | Partially implemented | Completed, pre-confirmation cancelled, and disputed states have server commands and emulator coverage. Failed, payment-refunded, and funds-released states remain intentionally unavailable until a payment and settlement provider is approved. |
| Transaction checklist | Source and emulator verified; staging pending | The accepted-offer UI shows agreed amount, quantity, both participant confirmations, controlled actions, and permanent revision history. Purchase, transfer, trucking, and Dispatch terms remain copied from the accepted offer. |
| External notifications | Incomplete | In-app Firestore notifications exist; no verified push/email delivery and retry workflow. |
| Message spam controls | Incomplete | Messages still use direct client writes without reviewed server throttling. |

### Auctions

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Bid and Buy It Now commands | Source only; live incomplete | Bid, Buy It Now, below-reserve acceptance, and withdrawal commands exist in source but are absent from deployed Functions. |
| Fees and boosts | Safely disabled; payments incomplete | Runtime/build controls hide paid features, but checkout, invoices, receipts, refunds, and reconciliation do not exist. |
| Winning-auction completion | Source and emulator verified; staging pending | Expired auctions are finalized through a bounded scheduled query or on-demand idempotent command. Reserve is evaluated server-side, winner/no-sale is atomic, and Buy It Now/below-reserve acceptance create the same participant settlement record. Buyer and seller must both confirm before the listing becomes sold. |
| Terminal/default/dispute states | Partially implemented | Completed sales, disputes, buyer-default reports, seller-default reports, and administrator cancellation have server-controlled state and immutable history. A complete administrator investigation, decision, appeal, and reversal workflow remains outstanding. |

### Dispatch

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Dispatch commands | Source and emulator verified; staging pending | Create, edit, publish, quote, revise quote, award, and post-award lifecycle commands are idempotent and server-controlled in source but remain absent from the current production deployment. |
| Provider approval | Incomplete | Signup writes `status: active` and `availableForHire: true` immediately. |
| Route distance | Incomplete | Distance is a labelled straight-line estimate, not reviewed truck routing. |
| Post-award lifecycle | Source and emulator verified; staging pending | Award creates a participant-only transaction. The carrier accepts, schedules, starts transport, and records receiver/delivery proof; the customer confirms closure. Safe cancellation, dispute, administrator resolution, notifications, immutable history, role checks, retries, and forged-write denial are verified in emulators. Attachment-backed signatures, payment, and staging acceptance remain outstanding. |
| Carrier billing | Incomplete | No invoice, payment, adjustment, refund, or reconciliation lifecycle. |
| Bounded job/bid queries | Incomplete | Several UI queries remain unbounded or client-filtered. |

## Live Firebase parity finding

The July 23 read-only inventory for project `flutter-flow-pipe` predates the
current 37-export reviewed source. The automated parity control therefore
continues to fail closed on missing current handlers and two unexpected legacy
handlers (`onDispatchBidCreated` and `onDispatchJobAwarded`). Offer, Auction,
and Dispatch workflows must remain disabled until a refreshed, reviewed
staging deployment matches exactly and passes end-to-end acceptance.

## Gate 0 completion evidence

- The live isolated-staging configuration document was intentionally absent,
  exercising the documented missing-configuration safe default.
- A disposable Email/Password user attempted direct Firestore creates for a
  normal Marketplace listing, Auction listing, regulated property listing,
  paid boost, and Dispatch carrier. Every attempt returned HTTP 403.
- Cleanup runs from `finally`; the disposable staging Auth identity was deleted
  after the rehearsal and no test document was created.
- `tool/phase1_safe_default_rehearsal.ps1` blocks the production project ID and
  production-like project names before making a request.
- `.github/workflows/safe-default-rehearsal.yml` repeats the evidence in the
  protected staging environment and retains its structured artifact once the
  workflow reaches the default branch.
- The Dispatch full local release gate passed with 0 analyzer issues, 68 Flutter
  tests, 46 Functions/runtime tests, 19 Firestore rules tests, 37 authenticated
  command receipts, dependency high-severity audits, and a release web build.

## Gate 3 checkpoint evidence

- Account signup no longer lets a client claim a phone number by writing a
  predictable registry document. It stores only a pending phone hint until an
  OTP credential is linked to the signed-in Firebase Auth identity.
- The ownership screen supports email resend/status refresh, web phone linking,
  native OTP linking, actionable error states, sign-out recovery, and a guarded
  continuation into profile onboarding.
- The server synchronizes only Firebase Auth ownership claims into protected
  user fields and a SHA-256 phone registry key. Direct clients cannot write or
  transfer the registry or forge verified ownership fields.
- All sensitive Marketplace, Offer, Auction, and Dispatch commands now require
  verified email and phone claims. Saved-listing state requires verified email
  but remains usable without forcing phone verification.
- The unified local release gate passes 0 analyzer issues, 68 Flutter tests,
  49 Function/runtime tests, 20 Firestore rules tests, the complete
  authenticated callable integration including a negative unverified-publisher
  case, high-severity dependency audits, Android packaging, and production web
  packaging. A GitHub clean-run remains required for this branch.

## Gate 1 checkpoint evidence

- `PIPE_ENV` and complete `PIPE_FIREBASE_*` web build values select the target
  Firebase project. Staging and production reject missing or mixed values.
- The repository-root `firebase.json` serves `build/web`; the Hosting emulator returned
  HTTP 200 from the generated Flutter release.
- The manual deployment workflow checks out a full SHA, reruns the verification
  suite, authenticates through Workload Identity Federation, and deploys only
  to the explicitly configured project in a named GitHub Environment.
- Local verification passed with 0 analyzer issues, 66 Flutter tests,
  32 Functions/runtime tests, 14 Firestore rules tests, and a release web build.
- Workflow YAML lint passed.
- Release manifest controls passed 4 unit tests and recorded 27 expected
  Functions, deterministic Functions/rules/index/config hashes, and the
  319-file web artifact hash.
- A least-privilege backup, isolated restore, validation, and application
  rollback runbook now exists. It is prepared procedure, not recovery proof.
- Native staging selects separate Android and iOS registrations for
  `pipebuyer-5c77f` and verifies the declared and initialized project IDs.
  Native production remains locked to the installed `flutter-flow-pipe`
  registrations. Development and CI Android initialization still builds.
- Staging now has separate Web, Android, and iOS registrations plus a Standard
  `(default)` Firestore database in `nam5`. The reviewed Firestore rules and
  indexes deployed successfully without modifying production.
- Both GitHub environments contain all seven verified public Firebase Web
  identifiers. Required-reviewer and branch-policy environment
  protection were rejected by the current private repository plan, so the
  workflow independently restricts production SHAs to `origin/main`.
- Staging Web and Android builds compiled successfully, and the staging
  manifest recorded 27 Functions and 319 web files. Hosting version
  `c5b6e2f11524c0eb` is live at `https://pipebuyer-5c77f.web.app`; read-only
  endpoint checks returned HTTP 200 and Flutter version metadata. The staged
  Home screen now also passes pixel-diversity and browser-exception checks at
  390x844 and 1440x1000. Physical Android and Apple acceptance remains pending.
- The first Hosting rehearsal caught Firebase rejecting a public directory
  outside its configured project root. The deploy root was moved to the
  repository-level `firebase.json`, which now references `build/web` directly;
  the successful rehearsal uses that layout without a junction or copy.
- Hosting version `9c53baeec68b39a9` was released after retaining the accepted
  `c5b6e2f11524c0eb` version in an expiring rollback channel. Cloning that
  baseline back to `live` produced release `1784695881916000` with type
  `ROLLBACK`; the live channel again resolves to `c5b6e2f11524c0eb`.
- Email/Password Authentication is declared in the root Firebase config and
  deployed to staging. A disposable `example.invalid` account was created and
  deleted through Identity Toolkit successfully, leaving no smoke-test user.
- Staging Storage stopped safely because its default bucket has not been
  explicitly provisioned. Functions deployment enabled the Cloud Functions API
  but stopped before creating any Function because Cloud Build and Artifact
  Registry require the staging project to be upgraded to the Blaze plan.
- App Check and Workload Identity configuration are intentionally absent, so
  staging and production deployments still fail closed.
- Android, iOS, and macOS now share a centralized Crashlytics adapter. Native
  manifest collection defaults to off; only explicit staging/production builds
  can enable it. Reports carry release context, safe operation fields, and a
  non-user correlation ID. Local/test/web/unsupported builds remain
  console-only. The production diagnostics runbook records the required device
  proof and alert-ownership decisions, which are still outstanding.
- The pushed diagnostics commit `2cf6b71` passed GitHub's clean Windows
  quality runner, including its Android build. A checked-in visual-smoke tool
  waits beyond the Flutter splash, rejects blank/monochrome frames and browser
  exceptions, and captures both mobile and desktop evidence. The protected
  deployment workflow runs it after deployment and retains screenshots as
  workflow artifacts.
- Local, development, test, verification, and CI startup redirect Auth,
  Firestore, Functions, and Storage to the local Emulator Suite. The complete
  four-service emulator configuration started and stopped successfully.
- The PowerShell quality gate now checks every native process exit code and
  stops immediately on a failed analyzer, test, emulator, build, or manifest
  command and runs the same high-severity npm audits as CI. These controls
  detected and prevented false-positive local verification during this
  checkpoint.
- Firebase Admin was upgraded to supported stable version 14.2.0 after CI
  detected a new high-severity transitive XML parser advisory. High-severity
  production dependency audit is clean; seven moderate upstream `uuid`
  findings remain documented rather than forcing npm's unsafe Admin 10.3.0
  downgrade.
- Functions now use a modular Admin 14 runtime adapter. Source loading is part
  of `npm run check`, and the four-service emulator smoke test invoked the real
  `createDispatchJob` callable and received its expected validation response.
- This is partial staging evidence, not a full application deployment. Gate 1
  remains open until the remaining staging services are configured and
  deploy/rollback and backup/restore are rehearsed.
