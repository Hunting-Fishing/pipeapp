# Pipe Buyer Phase 1 Launch Finalization Plan

Status: In progress  
Plan owner: Pipe Buyer product and engineering  
Baseline branch: `agent/phase1-commerce-feedback-safety`
Created: July 20, 2026

Current gate: Gate 6 — Mobile, accessibility, and product identity

Current overall launch-readiness estimate: 93%

Completed gates: 1 of 8

Detailed evidence: `docs/PHASE_1_PROGRESS_AUDIT.md`

| Gate | Status |
| --- | --- |
| 0 — Scope lock and safe defaults | 100% — complete |
| 1 — Environments, builds, and diagnostics | 82% — in progress |
| 2 — Backend parity and server commands | 92% — reviewed command boundary, zero-vulnerability runtime lock, emulator coverage, staged App Check release records, and parity controls locally verified |
| 3 — Identity, authorization, and abuse | 93% — ownership, reviewed verification, MFA admin controls, password recovery, remembered-device history, export, session revocation, and staged deletion locally verified |
| 4 — Product workflows | 89% — listing/transaction lifecycles, review-based Dispatch provider approval, bounded discovery, indexed structured filters, and recoverable Marketplace/Dispatch entity routes locally verified |
| 5 — Trust, notifications, and policies | 91% — protected reporting, exact stored-photo duplicate signals, private message-safety evidence, human-only review, appeals, private support, and versioned policy acceptance/enforcement locally verified |
| 6 — Accessibility, performance, and QA | 91% — cross-platform identity, release artwork, Apple privacy declarations, accessible focus/traversal, AA semantic feedback, bounded activity/history/operations streams, concurrent abuse tests, a high-text viewport matrix, resilient listing media, fail-closed signed-artifact/store/device evidence controls, a green unsigned macOS `iphoneos` release compile gate, and a protected signed-candidate workflow awaiting real credentials and execution |
| 7 — Release readiness | 14% — schema-version-2 release-SHA evidence contract covers product/recovery journeys, signed artifacts, store/privacy review, physical-device/browser scenarios, defects, and approvals; execution remains incomplete |

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

- Release manifests derive and declare the exact 70 expected Function exports
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
- Auth, Firestore, and Functions emulator integration verifies 37 marketplace
  receipts plus 2 communication receipts across saved listings, Marketplace
  listing lifecycle, Offers, Auctions, Buy It Now, Dispatch, messages, uploads,
  and reports, including repeated-request idempotency and state assertions
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
- The July 28 staging Function retry authenticated as the project owner and
  selected `pipebuyer-5c77f`, but Google still reported that exact project was
  not on Blaze and rejected both Cloud Build and Artifact Registry enablement;
  no Function was created
- The Functions dependency lock overrides the vulnerable transitive UUID below
  11.1.1. The moderate audit count fell from 7 to 0 while 105 Function tests, 36
  Firestore/Storage Rules tests, and the authenticated four-emulator workflow
  continued to pass
- Controlled deploys now record App Check as `disabled`, `observe`, or
  `enforce`; production rejects every mode except `enforce`, while staging can
  bootstrap safely before progressing through token observation
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
- Conversation creation, unread updates, message sending, reporting, and
  chat/report uploads now use verified, throttled commands. Uploads require a
  15-minute, single-purpose authorization matching owner, target, exact size,
  MIME type, and Firebase object path; direct Firestore writes are denied.
- Auth signup/provider throttling and listing-event abuse controls still require
  provider-level enforcement or server command migration.
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
- Staging Functions remain blocked because Google still reports
  `pipebuyer-5c77f` is not on Blaze; the authenticated July 28 retry created no
  Function and left the deployed inventory at zero
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
- Complete indexed full-text search; structured category, listing-type,
  condition, price, sort, pagination, and bounded queries are source verified.
- Finish approved-domain Android App Links and Apple Universal Links for the
  source-verified listing, profile, Auction, participant-conversation, and
  authenticated Dispatch-job routes.

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

Provider-approval source checkpoint: applications now use verified Firebase
Auth contact claims, enter `pending_review`, and cannot quote until an
MFA-authorized administrator approves. Approve, request-changes, reject, and
suspend decisions require notes, notify the provider, and append immutable
history. Unit, Rules, and authenticated four-emulator coverage is green;
staging reviewer acceptance remains required.

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

Current engineering evidence: listing publication now calculates trusted
SHA-256 fingerprints from the stored Firebase objects and rejects client hash
mismatches. A bounded indexed trigger creates a private exact-photo comparison
case for same-seller reuse. Conservative message signals create private,
bounded evidence excerpts. Both paths are idempotent, notify active
administrators, require human review, and never hide content or penalize an
account automatically. The authenticated four-emulator suite proves these
invariants. This is exact-file detection, not perceptual similarity or a claim
that a reviewed external AI classifier has been selected; those items and the
staging deployment remain open.

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

Current engineering evidence is recorded in
`docs/MOBILE_RELEASE_AND_ACCESSIBILITY.md`. Gate 5 remains at 91% while its
policy approval, external delivery, staffing, alerting, and staging-acceptance
evidence is completed by the responsible owners.

The repository now owns one hash-pinned release-art master and generated
launcher/splash assets for Android, iOS, web, Windows, and macOS. The Apple
privacy manifest declares current app-level collection without tracking,
advertising, or analytics purposes. An unreferenced notification-service sample
is archived outside the active iOS project. Local verification passes 88
Flutter tests, the analyzer, an ARM64 Android build, and the production web/Wasm
build. Store-console review, signed mobile artifacts, linked-SDK privacy review,
physical-device accessibility, and device/network matrices remain mandatory.

The application root now applies reading-order keyboard traversal and visible,
high-contrast focus treatments across light and dark themes. Automated 200
percent text acceptance covers compact portrait, phone portrait/landscape, and
tablet sign-in plus account creation and offer decisions. It caught and drove
repairs for clipped offer milestones and inaccessible compact-dialog actions.
The complete checkpoint passes 99 Flutter tests, the analyzer, ARM64 Android,
and production web/Wasm builds. Full manual screen-reader, keyboard, contrast,
orientation, and physical-device acceptance remains mandatory.

Success, information, warning, and failure feedback now share a release-wide
semantic palette with distinct text, icons, borders, and backgrounds in both
light and dark themes. Automated tests enforce WCAG AA text contrast, live
screen-reader announcements, dismissible feedback, and 200-percent-text
rendering. Startup failures, framework recovery, sign-in/account creation, and
profile-photo upload outcomes use this system. The checkpoint passes 103
Flutter tests, a clean analyzer, an ARM64 Android APK, production web, and an
actual WebAssembly build.

The account notification, notification badge, and conversation surfaces now
read only the 100 newest indexed records instead of opening unbounded realtime
listeners. At the boundary, the UI states that only the newest activity is in
view. Listing notification updates use an indexed listing/read query and stay
below Firestore's 500-operation batch ceiling. Contract tests prevent these
limits from being removed. Backend load tests also prove that 64 simultaneous
unique requests cannot exceed a 20-request quota and 50 simultaneous retries
consume one quota unit. The Function suite now passes 98 tests.

Bid histories, negotiation revisions, message threads, saved listings,
verification queues, moderation notices, and profile/tag data now have
explicit live-query ceilings. Offer histories are scoped to the active listing
and participant before download, with a checked buyer-side composite index.
User-facing history surfaces disclose when the latest-100 window has been
reached instead of implying that the visible set is complete. This expanded
checkpoint passes a clean analyzer, 103 Flutter tests, 99 Function/policy
tests, a validated Firestore index file, an ARM64 Android artifact, and a
production web build with a successful Wasm dry run.

Critical auction, offer, marketplace-transaction, Dispatch-transaction,
message, and chat-image outcomes now use the same accessible live-region
feedback system. Success and failure are conveyed through text, icon, border,
and AA-checked colors. A shared command-error boundary preserves short
actionable server messages while suppressing raw Firebase internals and unknown
exception text. Source contracts prevent critical commerce surfaces from
returning to raw SnackBars. The checkpoint passes a clean analyzer, 107 Flutter
tests, an ARM64 Android artifact, and a production web build with a successful
Wasm dry run.

The feedback boundary now also covers saved listings, sign-in/sign-out,
listing publishing and media validation, Dispatch signup/jobs/quotes/fleet,
policy notices, reporting review, and freight-quote publication. The primary
Marketplace shell contains no direct SnackBars. This expanded checkpoint
passes a clean analyzer, 108 Flutter tests, 105 Function tests, all local
release/parity/acceptance controls, a zero-vulnerability production dependency
audit, ARM64 Android, production web, and actual WebAssembly.

Phase 1 acceptance schema 2 now makes Gate 6 evidence mandatory rather than an
unstructured external checklist. It requires the exact signed AAB and IPA,
signature and store validation, public policy/support/deletion URLs, store
screenshots and review output, Google/Apple/linked-SDK privacy reviews, and ten
release-SHA-bound physical-device/browser targets with exact scenario coverage.
Large artifacts are hashed in bounded chunks, canonical paths cannot escape the
private evidence root through traversal or directory links, and a synchronized
operator template is checked in. Seven validator tests and the complete local
release gate pass. No signed artifact, store approval, privacy review, or
device execution is credited until its real evidence is supplied.

The required `Quality` workflow now also uses a separate macOS runner to compile
the unsigned `iphoneos` release target and prove that Xcode produced the
application bundle. A Flutter contract test prevents removal of the runner,
release mode, no-signing boundary, output assertion, or unsigned-evidence
disclaimer. The job detects Apple-native compilation regressions but cannot be
used as evidence of distribution signing, IPA export, store validation, or a
physical-device pass.

The first macOS execution correctly failed on malformed Swift Package Manager
metadata from `flutter_native_splash` 2.4.4 and a duplicated Xcode object ID for
localized `InfoPlist.strings`. The repair updates the splash generator and its
compatible JSONPath/Lottie dependency chain, gives every Xcode object a unique
identifier, and preserves both behaviors with focused tests instead of
disabling Swift Package Manager.

The migrated Firebase Swift packages also require iOS 15. Flutter framework
metadata and every Runner build configuration declare the same 15.0 baseline,
and a release contract test prevents a partial or incompatible deployment-
target rollback.

The subsequent link phase found duplicate Firestore symbols because the old
Apple-sign-in and SQLite plugins forced a CocoaPods fallback alongside Firebase
SPM products. Those plugins now use their SPM-capable production releases,
and the obsolete Runner Podfile, Pods build phases, Pods framework, and Pods
xcconfig includes are removed. CI explicitly enables Swift Package Manager and
a source contract rejects renewed CocoaPods integration. This removes the mixed
native ownership instead of suppressing the linker error or turning Swift
Package Manager off.

A separate protected manual workflow now accepts only a full release SHA
contained in `main`, builds a signed Android AAB and Apple IPA with
environment-scoped credentials, verifies their identifiers, versions,
signatures, and digests, removes decoded signing material on every outcome, and
retains candidate evidence for 14 days. Its metadata remains explicitly not
store-validated, so this repository control does not credit store submission,
physical-device installation, or final acceptance before those external steps
are performed.

Exit evidence:

- Signed Android and Apple release candidates install and complete the Phase 1
  acceptance suite.
- Store metadata, privacy declarations, screenshots, support URL, and policy
  URLs are complete.

### Gate 7 — Launch rehearsal and approval

Goal: Prove the service can launch and recover.

`tool/phase1_acceptance.mjs` now binds final evidence to one controlled
environment and full release SHA. It requires all ten acceptance journeys,
measured Hosting/Functions/Rules/data recovery controls, signed Android/Apple
release candidates, store and privacy review, ten physical-device/browser
targets, a reviewed defect inventory with no open P0/critical/high defects, and
named approvals from all seven required owner roles. Evidence paths cannot
escape the controlled bundle; retained files are streamed into hashed readiness
records. The validator and its fail-closed tests are part of local and CI
verification. This control does not credit the still-unperformed rehearsals,
signed artifacts, store/device execution, or approvals.

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
