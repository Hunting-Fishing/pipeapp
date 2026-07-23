# Pipe Buyer Phase 1 Launch Finalization Plan

Status: In progress  
Plan owner: Pipe Buyer product and engineering  
Baseline branch: `agent/server-abuse-throttles`
Created: July 20, 2026

Current gate: Gate 3 — Identity, authorization, App Check, and abuse protection

Current overall launch-readiness estimate: 57%

Completed gates: 1 of 8

Detailed evidence: `docs/PHASE_1_PROGRESS_AUDIT.md`

| Gate | Status |
| --- | --- |
| 0 — Scope lock and safe defaults | 100% — complete |
| 1 — Environments, builds, and diagnostics | 82% — in progress |
| 2 — Backend parity and server commands | 77% — local integration verified |
| 3 — Identity, authorization, and abuse | 45% — ownership and callable throttles locally verified |
| 4 — Product workflows | 64% — listing, offer, auction, and Dispatch transaction lifecycles locally verified |
| 5 — Trust, notifications, and policies | 15% — incomplete |
| 6 — Accessibility, performance, and QA | 15% — incomplete |
| 7 — Release readiness | 5% — incomplete |

Gate 0 implementation evidence:

- Runtime configuration contract and rollback procedure:
  `docs/PHASE_1_FEATURE_FLAGS.md`
- Flutter, callable Function, and Firestore rule enforcement implemented for
  all seven Phase 1 feature controls
- High-risk missing-configuration defaults verified by unit and emulator tests
- Clean local verification and remote CI pass
- Isolated staging rehearsal proved an authenticated stale client receives
  HTTP 403 for Marketplace, Auction, regulated-property, paid-boost, and
  Dispatch direct writes when runtime configuration is absent
- The disposable staging identity was removed in a guaranteed cleanup path;
  the repeatable rehearsal refuses to target the production Firebase project

Gate 2 implementation evidence in progress:

- Release manifests declare the exact 36 expected Function exports
- Unit-tested parity tooling compares that manifest with the deployed
  `marketplace` codebase and fails on missing, unexpected, or inactive handlers
- Every controlled deploy now performs this comparison after deployment and
  records the structured result in its release summary
- The last read-only production inventory fails safely: 15 handlers were
  deployed; with the new conversion command, 15 expected handlers are missing
  and 2 obsolete handlers remain
- Client listing creation and Marketplace-to-Auction conversion now use
  authenticated server commands; direct clients cannot author public listing,
  private reserve, bid, offer, or Dispatch transaction state
- Auth, Firestore, and Functions emulator integration verifies 37 command
  receipts across saved listings, Marketplace listing lifecycle, Offers,
  Auctions, Buy It Now, and Dispatch, including repeated-request idempotency
  and transaction state assertions
- Normal Marketplace listing owners can edit revision-safe details, pause or
  reactivate, mark sold, archive, and relist to a new identifier. Every command
  writes immutable history that only the owner or an administrator may read.
- Saved listings restore from the authenticated account across sessions, use
  authoritative listing identifiers and live documents, and update through an
  idempotent command that keeps analytics and saved state consistent.
- Accepted offers create participant-only transaction records. Buyer and seller
  completion confirmations, early cancellation, disputes, notifications, and
  immutable transaction revisions are enforced by idempotent server commands.
  Payment release and refund states remain disabled until a settlement provider
  is approved and integrated.
- Expired auctions finalize atomically to a winning bidder or no sale through a
  bounded scheduler or retry-safe callable. Buy It Now and below-reserve
  acceptance use the same participant-only settlement model. Completion needs
  both parties; dispute and default reports enter an immutable review queue.
- Dispatch awards create participant-only transactions. Carrier acceptance,
  scheduling, in-transit, structured delivery proof, customer closure, safe
  cancellation, dispute, administrator resolution, notifications, and
  immutable revisions are enforced through one idempotent server command.
- Functions discovery and CI now use the declared Node 22 runtime, and App
  Check enforcement is a concrete deployment option rather than an unsupported
  parameter expression
- Staging Function deployment and exact deployed parity remain blocked on the
  staging billing-plan decision
- Verified-email and linked-phone claims now guard protected Marketplace,
  Offer, Auction, and Dispatch commands. Signup/sign-in route incomplete users
  through an ownership screen; Firebase Auth phone uniqueness is synchronized
  to a server-owned hashed registry that clients cannot forge.
- The account verification checkpoint passes 49 Function tests, 20 Firestore
  Rules tests, the Flutter analyzer, and authenticated callable emulation,
  including rejection of an unverified listing publisher. Staging Phone Auth
  enablement and physical Web/Android/Apple OTP acceptance remain required.
- Account, Marketplace, Offer, Auction, and Dispatch callable groups now use
  transactional hourly abuse quotas. Identical retry fingerprints are not
  double-counted; distinct excess requests fail with a safe retry response.
  Buckets are private hashed records with bounded scheduled expiry cleanup.
- Direct-client messaging, reporting, media-upload, and Auth signup throttles
  still require server command migration or provider-level enforcement.
- The abuse-throttle checkpoint passes the unified local gate with 68 Flutter
  tests, 51 Function tests, 20 Firestore Rules tests, authenticated callable
  integration, Android and production web builds, and release-manifest checks.

Gate 1 implementation evidence in progress:

- Web Firebase project selection is build-environment controlled; staging and
  production fail closed on incomplete or mixed configuration
- Native production builds are locked to the approved `flutter-flow-pipe`
  platform registrations; staging selects its isolated Android/iOS
  registrations. Both verify the initialized project.
- Non-production startup defaults to the local Firebase Emulator Suite for
  Auth, Firestore, Functions, and Storage with no cloud fallback
- Firebase Hosting serves the generated `build/web` release directly
- An exact-commit staging/production workflow and rollback procedure are
  present but have not yet been exercised; production is restricted to a SHA
  contained in `main`
- Deterministic release manifests record expected Functions, deployable source
  hashes, rules/index hashes, and the generated web artifact hash
- Backup, isolated restore, validation, and rollback procedures are documented
- The isolated staging project now has Web, Android, and iOS registrations,
  Standard Firestore in `nam5`, deployed rules/indexes, passing staging Web
  and Android builds, its public GitHub Environment configuration, and a live
  Hosting deployment-and-rollback rehearsal
- Staging Storage/Functions, App Check, Workload Identity,
  environment reviewer protection, full-service deployed release IDs,
  monitoring ownership, and data backup/restore rehearsal remain required
- Staging Email/Password Authentication is provisioned from the reviewed
  `firebase.json` declaration and passed a disposable create/delete smoke test
- Staging Functions are blocked on the owner's Blaze billing-plan decision;
  no Function was created by the failed deployment attempt
- Native staging/production diagnostics now use a centralized, release-tagged
  Crashlytics adapter with manifest-level default-off collection, an explicit
  build-time opt-in, safe correlation IDs, and a triage/validation runbook.
  Device evidence and approved alert ownership remain required.
- The diagnostics checkpoint passed the clean GitHub Windows/Android quality
  run. Staging also passed deterministic 390x844 mobile-web and 1440x1000
  desktop rendering checks with no browser exceptions. The deployment workflow
  now reruns both checks and retains their screenshots after every release.

## 1. Phase 1 launch decision

Phase 1 is a controlled equipment, materials, wanted-ad, offer, auction, and
Dispatch marketplace release. It is not the public launch of real estate,
business sales, mineral rights, royalty interests, surface interests, or
regulated asset transfers.

The release is a no-go until every mandatory gate below is complete. A feature
that misses its gate is disabled through a server-controlled feature flag; it
is not shipped with a warning label or an unfinished button.

### Included after acceptance

- Verified accounts and recoverable profiles
- Equipment and materials listings with user-selected media
- Wanted ads
- Saved listings
- Listing-scoped messaging and supported attachments
- Offers, revisions, counteroffers, acceptance, and closure
- Timed auctions when the complete auction gate passes
- Dispatch requests, quote revisions, awards, and closure when the complete
  Dispatch gate passes
- User reporting, evidence, administrator review, decisions, and appeals

### Disabled for Phase 1

- Real property and property-rights publishing
- Business-sale listings
- Mineral, royalty, lease, and surface-rights transactions
- eXp-controlled workflows that do not yet have approved jurisdiction packs
- Paid boosts and paid custom-auction fees until charging, receipts, refunds,
  and reconciliation are implemented
- Platform-held deposits, escrow, trust funds, or settlement money

## 2. Rules that apply to every gate

Every implementation and build must include:

1. User-safe loading, empty, offline, validation, permission, timeout, and
   retry states.
2. Structured diagnostics containing environment, release identifier,
   subsystem, operation, and a non-sensitive correlation identifier.
3. No raw stack traces, Firebase internals, secrets, private addresses, message
   contents, or personal documents in user-facing errors or telemetry.
4. Idempotency for every command that can create financial, offer, bid,
   Dispatch, moderation, or notification state.
5. Web, Android, and Apple behavior reviewed. Unsupported platforms must fail
   closed with an understandable explanation.
6. Unit/policy tests plus an end-to-end acceptance test for the changed user
   journey.
7. A rollback instruction and evidence that existing user data remains valid.
8. A feature flag or kill switch for externally visible high-risk features.

## 3. Ordered delivery gates

### Gate 0 — Scope lock and safe defaults

Goal: Prevent unfinished or regulated features from being presented as live.

- Remove production demo listings or label them as non-transactional samples
  in non-production builds only.
- Disable property, business, rights, paid boosts, and unpaid auction-fee
  paths at both UI and server boundaries.
- Add server-controlled feature flags for Marketplace, Wanted Ads, Offers,
  Auctions, Dispatch, paid features, and regulated categories.
- Replace dead Home, RFQ, Help, View all, See all, and notification actions
  with working destinations or remove them.

Exit evidence:

- A production build cannot expose a disabled feature through navigation,
  direct URL, stale client, or direct Firebase write.
- An empty production database shows an empty state, never fictional sellers.

### Gate 1 — Reproducible environments, builds, and diagnostics

Goal: Make every release identifiable, observable, repeatable, and reversible.

- Create separate development, staging, and production Firebase projects.
- Replace the hard-coded web Firebase project with environment-selected build
  configuration.
- Make `build/web` the single Hosting artifact and remove the local junction
  dependency.
- Add controlled staging and production deployment workflows that deploy only
  a verified commit.
- Record release SHA, environment, Firebase project, rules version, Functions
  hash, Hosting version, and rollback version.
- Add centralized Flutter, platform, asynchronous, startup, and callable error
  handling.
- Add crash/error reporting adapters and production alert ownership.
- Add Firestore backup, restore, migration, and deployment rollback runbooks.

Exit evidence:

- A clean checkout produces the same verified artifacts.
- Staging deploys from CI without manual file copying.
- A failed startup shows a recovery screen and records a structured diagnostic.
- The previous Hosting, Functions, and Rules release can be restored.

### Gate 2 — Backend parity and server command boundary

Goal: Make deployed Firebase behavior exactly match reviewed source.

- Deploy every current callable and event function to staging.
- Remove or explicitly retain every stale deployed function.
- Deny direct client changes to authoritative listing, offer, bid, Dispatch,
  trust-score, verification, fee, and moderation state.
- Add idempotency receipts and transactional conflict handling to every
  sensitive state transition.
- Add callable integration tests against Firebase emulators.
- Compare expected and deployed Functions automatically in the release gate.

Exit evidence:

- Expected and deployed Function names and source hashes match.
- Repeated taps and retried requests do not duplicate state.
- Stale clients cannot bypass current server validation.

### Gate 3 — Identity, authorization, App Check, and abuse protection

Goal: Ensure one accountable identity and least-privilege access.

- Require verified email before marketplace participation.
- Verify phone ownership with OTP before listing, offering, bidding, or
  Dispatch signup.
- Make phone uniqueness a server-controlled claim with recovery and cleanup.
- Add bot, signup, message, report, listing-event, upload, offer, bid, and
  Dispatch rate limits.
- Register and monitor App Check providers, then enforce callable, Firestore,
  and Storage protection in controlled stages.
- Replace hard-coded administrator email authorization with reviewed role
  assignments and custom claims.
- Require MFA for administrative users.
- Prevent deletion/recreation from resetting User Score or verification.
- Add account recovery, account deletion, data export, and orphan cleanup.
- Add Firestore and Storage emulator tests for every role and file path.

Exit evidence:

- Unverified, duplicate, automated, suspended, and stale clients are blocked.
- A normal user cannot forge verification, analytics, boosts, trust score,
  offers, bids, or administrative state.
- Administrators use least-privilege roles and MFA.

### Gate 4 — Complete Phase 1 marketplace journeys

Goal: Finish every user-visible transaction lifecycle included in Phase 1.

Marketplace:

- Load saved listings from Firestore and support save/unsave across sessions.
- Create media as a draft, retry failed uploads, choose a thumbnail, and only
  publish when required data is complete.
- Edit, pause, archive, relist, mark pending, mark sold, and close listings.
- Add indexed search, pagination, sorting, filters, and bounded queries.
- Add shareable routes for listings, profiles, auctions, conversations, and
  Dispatch jobs where access permits.

Offers and messages:

- Complete offer, counteroffer, acceptance, competing-offer archive, decline,
  cancellation, completion, and dispute states.
- Add spam controls, delivery/read behavior, attachment retry, and permanent
  revision history.
- Keep purchase, transfer, and trucking milestones visible and auditable.

Auctions:

- Complete bid, reserve privacy, Buy It Now, below-reserve acceptance,
  withdrawal, expiration, winner, default, cancellation, settlement status,
  completion, and notifications.
- Disable fees or implement checkout, receipt, refund, and reconciliation.

Dispatch:

- Complete request, edit, publish, quote, quote revision, award, accept,
  schedule, in-transit, delivered, cancelled, disputed, and closed states.
- Replace straight-line distance with a reviewed truck-route provider or label
  and limit the estimate as non-binding.
- Add provider approval status without collecting unnecessary private
  documents.

Exit evidence:

- Buyer, seller, bidder, auction seller, Dispatch customer, and Dispatch
  provider acceptance suites pass on staging.
- Every terminal state is visible, recoverable, and auditable.

### Gate 5 — Trust, notifications, policies, and support

Goal: Operate the marketplace safely after users arrive.

- Deploy duplicate-image and message-safety moderation.
- Add reviewed image/text classifiers with human decisions; automated signals
  never punish a user without review.
- Add case assignment, evidence integrity, reviewer notes, action, reversal,
  user response, appeal, and escalation.
- Make confirmed actions update content/account state and immutable audit
  records transactionally.
- Add in-app and push notifications, transactional email, delivery status, and
  retry. Add critical SMS only where an approved use case exists.
- Publish versioned Terms, Privacy, Marketplace, Auction, Dispatch,
  Moderation/Appeal, Prohibited Items, Mapping, and Communications policies.
- Record user acceptance of applicable policy versions.
- Add support contact, case intake, incident escalation, and response targets.

Exit evidence:

- A report moves from submission through evidence review, decision,
  notification, appeal, and reversal.
- Critical transaction notifications are delivered and failures are alerted.
- Every active user has accepted the current required policy versions.

### Gate 6 — Mobile, accessibility, and product identity

Goal: Produce installable, professional release artifacts.

- Replace all `VehicleAppPageTemplates`, `PipeApp`, and placeholder branding.
- Finalize application IDs before store enrollment.
- Configure Android release signing and build an AAB.
- Configure Apple bundle identity, signing, capabilities, privacy manifest,
  and archive validation.
- Confirm icons, splash screens, deep links, permissions, photo selection,
  camera access, notifications, and location disclosures.
- Run screen-reader, keyboard, text-scale, contrast, large-touch-target, and
  orientation testing.
- Test supported phones, tablets, browsers, slow networks, and expired
  sessions.

Exit evidence:

- Signed Android and Apple release candidates install and complete the Phase 1
  acceptance suite.
- Store metadata, privacy declarations, screenshots, support URL, and policy
  URLs are complete.

### Gate 7 — Launch rehearsal and approval

Goal: Prove the service can launch and recover.

- Run the complete staging acceptance matrix with new test identities.
- Run load, abuse, upload, notification, and moderation queue tests.
- Rehearse Hosting, Functions, Rules, index, and data rollback.
- Restore a Firestore backup into an isolated project and validate it.
- Review security, privacy, legal, support, and operational sign-off.
- Run an invitation-only pilot before public availability.

Exit evidence:

- All P0 defects are closed.
- No critical or high unresolved security defects remain.
- Rollback and recovery objectives are proven.
- Named owners approve product, engineering, security, Trust & Safety,
  support, privacy, and applicable legal boundaries.

## 4. Release acceptance journeys

The final automated and manual suite must cover:

1. Signup, email verification, phone verification, recovery, profile, and
   avatar upload.
2. Listing draft, media retry, thumbnail, publish, edit, pause, sold, archive,
   and relist.
3. Save, unsave, refresh, sign out, sign in, and saved-state recovery.
4. Message, attachment, report, moderation decision, appeal, and reversal.
5. Offer, counteroffer, schedule, acceptance, archive, decline, cancellation,
   completion, and dispute.
6. Auction bid, minimum increment, reserve, Buy It Now, expiry, withdrawal,
   seller decision, and completion.
7. Dispatch request, edit, publish, quote, revision, award, delivery, close,
   and history.
8. Duplicate command, slow connection, offline transition, permission denial,
   expired session, upload failure, and service outage.
9. Administrator MFA, least-privilege access, audit review, and emergency
   feature shutdown.
10. Staging deploy, production release, rollback, backup restore, and customer
    communication.

## 5. Work tracking rule

Only one gate is `in progress` at a time. A gate is marked complete only when
its code, tests, staging evidence, error handling, deployment record, and
rollback evidence are committed together. Passing compilation alone does not
close a gate.
