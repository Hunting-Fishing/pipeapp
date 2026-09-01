# Phase 1 progress audit

## 2026-09-01 P1 Marketplace blocking production release

The P1 Marketplace user-blocking slice moved from source/emulator acceptance to **verified production** on `0dd8f9c4ab69868b4b8fc8e6cb2c05dbf1ca80de`. Protected production run `33464230471` (#55) used App Check `enforce` and passed exact-source checkout, Flutter tests, release-manifest/parity tests, Functions validation, Firestore security rules, authenticated callable workflows/retries, exact web build, Firebase deployment, post-deploy Function parity, release identity, and production visual acceptance (job `99722538441`). Pre-merge Quality `33463954448` and Callable Safety `33463955489` were also green.

Production evidence: `firebase-release-evidence-production-0dd8f9c4ab69868b4b8fc8e6cb2c05dbf1ca80de-33464230471` (artifact `9784473533`) and `visual-acceptance-production-33464230471` (artifact `9784489576`). New exports `readMarketplaceUserBlockStatus` and `setMarketplaceUserBlocked` are discovered by the generated release manifest; no static allowlist entry is required.

The accepted repair was narrowly client-side: reciprocal blocking was originally disabled when the other member had blocked first. That restriction was removed so either party can create an independent directional block, and a regression contract test now preserves the rule. Server send enforcement, retained conversation history, and retained moderation evidence were unchanged.

This record supersedes historical statements below that App Check, exact committed-candidate deployment, or Function parity were still pending for this release. Historical July percentages remain historical rather than being recomputed.


## 2026-09-01 reconciliation

This July 30 audit is preserved as a historical engineering checkpoint. Do not use its provisional percentages as current launch status. Current launch authority is `docs/PIPE_BUYER_LAUNCH_READINESS_AUDIT_2026-08-30.md`. Since this checkpoint, production has closed major gaps including protected App Check/release parity, server-authoritative marketplace payment/Connect flows, Timed Buying, web membership upgrades and promotion-code handling, OpenStreetMap/geolocation, substantial Dispatch Directory stabilization, and the brighter responsive Marketplace home hero.

The controlled North American web surface is now in late P1 acceptance. Native store publication and unrestricted international expansion remain separate readiness tracks.

Audit date: July 30, 2026

Branch: `main`

Current verified production release: `main` at `0dd8f9c4ab69868b4b8fc8e6cb2c05dbf1ca80de` via run `33464230471`; the July audit below remains historical

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
| 0 — Scope lock and safe defaults | **Yes** | **100%** | Runtime flags, build locks, callable/rules enforcement, unit/emulator coverage, and clean CI pass. |
| 1 — Environments, builds, diagnostics | **Yes** | **100%** | Production signed Android AAB (79.2MB) and Apple IPA (41.8MB) release candidates generated, verified, and retained in GitHub CI. Production Firestore security rules, indexes, and Storage rules deployed to `flutter-flow-pipe`. |
| 2 — Backend parity and commands | **Yes** | **100%** | July 30 production inventory: all 74 Marketplace Cloud Functions are active on Node 22 plus 1 approved standalone 8 GB 1st-gen `agent` Cloud Function on Node 20 (75 total functions). Rules, indexes, server commands, and zero-vulnerability Marketplace runtime locks are verified. The tracked Node 22 `agent` replacement remains disabled pending controlled deployment. |
| 3 — Identity and abuse protection | No | 95% | Signup, sign-in, reviewed verification, MFA admin controls, rate limits, data export, session revocation, and scheduled deletion implemented; production App Check and physical OTP/MFA acceptance remain. |
| 4 — Product workflows | No | 96% | Saved listings, listing/transaction lifecycles, media publication, indexed Marketplace keyword search, Dispatch provider enrollment, entity routes, and cursor pagination verified locally. Search index deployment/backfill and staging acceptance remain. |
| 5 — Trust, notifications, policies | No | 96% | User reporting, evidence authorization, administrator decisions, appeals, private support, versioned policies, and privacy-safe external-notification delivery/retry controls are source and emulator verified. FCM/APNs activation, physical-device delivery, alert ownership, policy approval, and staffed operations remain. |
| 6 — Accessibility, performance, QA | **Yes** | **100%** | Product identity, WCAG AA semantic feedback, Apple privacy manifest, public support/terms/deletion routes, signed Android AAB and Apple IPA candidates generated and verified. |
| 7 — Release readiness | No | 86% | Unified local gate, production web packaging, a 74-Function release manifest, and emulator-backed mobile visual acceptance pass. Exact committed-candidate CI, protected staging, physical devices, App Check enforcement, provider activation, and store submission remain. |

Overall Phase 1 engineering completion estimate: **99% provisional**.

Active Gate 7 estimate: **86% provisional**.

Completed gates: **4 of 8**.



## Mandatory workflow audit

### Accounts and profiles

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Email ownership | Source and emulator verified; staging pending | Signup and incomplete sign-ins are held on the account-ownership screen. Protected commands require the Firebase Auth `email_verified` claim, and the callable emulator proves an unverified user cannot publish. Staging email-link acceptance remains required. |
| Phone ownership | Source and emulator verified; staging pending | Web uses Firebase phone-link confirmation and native clients use OTP credentials linked to the existing account. Protected Marketplace/Offer/Auction/Dispatch commands require the Firebase Auth phone claim. Firebase Auth provides provider-level uniqueness; a callable synchronizes a SHA-256 registry key and verified profile fields that clients cannot forge. Phone Auth, authorized web domains, APNs/SHA configuration, quota and physical-device acceptance remain pending. |
| Account recovery | Password path source verified; assisted recovery incomplete | Sign-in now presents a confirmation-based recovery flow, validates the address, uses Firebase password-reset delivery, shows the same result for registered and unknown addresses to prevent account enumeration, and preserves the existing post-sign-in profile reconstruction path. A reviewed support/evidence process for users who have lost both email and phone access remains intentionally unavailable. |
| Account verification meaning | Source and emulator verified; staging pending | A reviewed account requires Firebase-owned email and mobile claims, a complete public profile snapshot, and an approved server-side review revision. Legacy profile-completeness flags do not satisfy the reviewed-verification check. Staging acceptance and operational reviewer evidence remain pending. |
| Administrator verification queue | Source and emulator verified; staging pending | Submission and review are callable commands with retry receipts and bounded quotas. The MFA-protected queue supports approve, request-changes, and reject decisions with mandatory notes, current Auth ownership rechecks before approval, immutable history, and deterministic notifications. Staging deployment and reviewer acceptance remain pending. |
| Account deletion | Source and emulator verified; staging/policy pending | Account Settings schedules deletion only after recent authentication, exact typed confirmation, and server-side checks for active listings, offers, settlements, Dispatch work, and administrator responsibility. Users receive a 14-day cancellation period. A bounded scheduled finalizer rechecks obligations, removes private profiles and owned media, releases the phone registry, anonymizes retained listings, deletes Firebase Auth last, and writes a non-identifying audit. Staging execution, approved retention/legal policy, and scheduled-finalizer failure-injection proof remain pending. |
| Data export | Source and emulator verified; staging pending | A recent-auth callable builds a private JSON export containing authentication metadata, profiles, saved data, listing/offer/conversation history, transaction revisions, auctions, Dispatch records, and user-submitted safety history. Conservative Firestore chunks are owner-only, server-written, audited, and expire after seven days; web downloads and native file saving are wired in Account Settings. Staging acceptance and assisted exports above the automated safety ceiling remain pending. |
| Administrator MFA and role authorization | Source and emulator verified; staging pending | Runtime authorization requires reviewed `admin` and `role: administrator` custom claims plus Firebase's reserved per-session `firebase.sign_in_second_factor` claim across Functions, Firestore, Storage, and Flutter. A dry-run-first operator script verifies email ownership and an enrolled Firebase MFA factor before granting the role, preserves unrelated claims, records role/audit documents, and revokes existing refresh tokens. Hard-coded administrator email authorization is removed. Identity Platform MFA activation, real-factor enrollment, staging acceptance, recovery-admin proof, and a reviewed production grant remain pending. |
| Session/device management | Source and emulator verified; staging pending | Each verified account records a server-owned, owner-readable history of remembered app installations with current-device identification, bounded labels, first/last activity, authentication time, active/revoked state, and a new-device notification. No IP address, GPS location, advertising identifier, or hardware fingerprint is stored; inactive entries expire after 180 days. Account Settings revokes all Firebase refresh sessions and accurately notes that current ID tokens may remain active briefly. Firebase cannot selectively revoke one refresh token in this architecture, so the UI does not make that false promise. Physical-device, suspicious-device response, and staging acceptance remain incomplete. |

### Marketplace

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Persisted saved listings | Source and emulator verified; staging pending | Save and unsave use an idempotent server command, restore from `users/{uid}/saved_listings` after authentication, use consistent document IDs, and render live listing documents. Rules deny cross-user reads, direct saved-state writes, and forged save analytics. Staging acceptance remains outstanding. |
| Listing lifecycle | Source and emulator verified; staging pending | Normal listings have revision-safe server commands and owner UI for editing, pause/reactivate, mark sold, archive, and relist. Immutable owner/admin revision history is enforced. Staging deployment and acceptance evidence remain outstanding. |
| Listing media publication | Source and emulator verified; staging pending | The create form now saves an owner-private server draft first, uploads selected media with visible progress, preserves failed uploads for retry, sends the selected thumbnail explicitly, and publishes only after the server verifies exact media counts, Firebase Storage ownership path, type, size, and object existence. Direct draft writes and uploads without an owned open draft are denied. Thirty-day expiry cleanup and account export/deletion handling are included. Staging web/native upload acceptance remains outstanding. |
| Search and filtering | Source/emulator verified; deployment/backfill pending | Browse queries active Marketplace inventory with bounded cursor continuation and indexed structured filters. Keyword search now uses server-owned normalized token arrays generated by listing commands, a required composite index, and a dry-run-first paginated legacy-listing backfill. Client input is normalized and bounded. The index must be deployed before Functions, legacy production listings must be backfilled with the reviewed confirmation guard, and representative-volume staging acceptance remains. |
| Pagination/geospatial search | Source verified; route search pending | Marketplace Browse, Auctions, public profiles, owner listings, open Dispatch jobs, personal requests, quotes, bids, and histories use bounded cursor pages. The map is capped at 200 current public records and the Dispatch listing picker at 50. True truck-route and server-side geospatial search remain incomplete. |
| Home notification action | Resolved in source | The former dead Home bell is no longer exposed. Account Notifications remains the working destination. |
| View/See all actions | Resolved in source | Featured `See all` opens Browse and offer revision history opens its complete history dialog. |
| Help placeholder | Resolved in source | The dead drawer item was removed pending a real support workflow. |
| Wanted ads and RFQs | Source repaired; verification pending | The drawer now opens Create Listing preselected as a Wanted ad rather than redirecting to ordinary Browse. |
| Shareable routes | Source verified; staging/native association pending | Encoded GoRouter paths now restore listings, Auctions, public profiles, participant-only conversations, and authenticated Dispatch jobs with loading, offline/access, unavailable, privacy, and return-home states. Cards, seller links, message lists, simple conversation entry points, and Dispatch load-board share actions use the routes; shares copy a browser URL on web and a safe relative app path on native. Firebase Hosting already rewrites browser refreshes to `index.html`. Hosted refresh acceptance and approved-domain Android App Links/Apple Universal Links remain pending. |

### Offers and transactions

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Live Offer commands | Production parity verified; staging UX acceptance pending | `createMarketplaceOffer` and `acceptMarketplaceOffer` are present in the July 30 production inventory and used by Flutter. Exact-candidate staging acceptance remains. |
| Post-acceptance lifecycle | Source and emulator verified; staging pending | Acceptance creates a participant-only transaction. Buyer and seller confirmations advance independently and both are required to complete the sale; early cancellation reopens the listing, disputes preserve the pending sale, and each transition is revisioned and idempotent. |
| Terminal states | Partially implemented | Completed, pre-confirmation cancelled, and disputed states have server commands and emulator coverage. Failed, payment-refunded, and funds-released states remain intentionally unavailable until a payment and settlement provider is approved. |
| Transaction checklist | Source and emulator verified; staging pending | The accepted-offer UI shows agreed amount, quantity, both participant confirmations, controlled actions, and permanent revision history. Purchase, transfer, trucking, and Dispatch terms remain copied from the accepted offer. |
| External notifications | Source and emulator verified; provider/device acceptance pending | Durable in-app notifications now drive an idempotent Firebase Cloud Messaging delivery trigger. Explicit user opt-in, protected endpoint registration, token refresh/revocation, generic lock-screen copy, invalid-token cleanup, retry state, critical-failure records, an MFA administrator resolution queue, and a generated environment-specific web worker are implemented. FCM/APNs/VAPID activation, exact-candidate deployment, physical-device delivery, alert ownership, and any future transactional-email provider remain pending. |
| Message spam controls | Source and emulator verified; staging pending | Conversation creation, unread state, sending, notification creation, and attachment consumption are verified server commands. Messaging has an independent hourly quota, retry receipts prevent duplicate messages, and Rules reject direct conversation/message writes. |

### Auctions

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Bid and Buy It Now commands | Production parity verified; launch locked pending acceptance | Bid, Buy It Now, below-reserve acceptance, and withdrawal commands are present in the July 30 production inventory. Production UI remains fail-closed unless both the build approval and remote flag are enabled after staging acceptance. |
| Fees and boosts | Safely disabled; payments incomplete | Runtime/build controls hide paid features, but checkout, invoices, receipts, refunds, and reconciliation do not exist. |
| Winning-auction completion | Source and emulator verified; staging pending | Expired auctions are finalized through a bounded scheduled query or on-demand idempotent command. Reserve is evaluated server-side, winner/no-sale is atomic, and Buy It Now/below-reserve acceptance create the same participant settlement record. Buyer and seller must both confirm before the listing becomes sold. |
| Terminal/default/dispute states | Partially implemented | Completed sales, disputes, buyer-default reports, seller-default reports, and administrator cancellation have server-controlled state and immutable history. A complete administrator investigation, decision, appeal, and reversal workflow remains outstanding. |

### Dispatch

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Dispatch commands | Production parity verified; launch locked pending acceptance | Create, edit, publish, quote, revise quote, award, and post-award lifecycle commands are idempotent and server-controlled and present in the July 30 production inventory. Production UI remains fail-closed unless both the build approval and remote flag are enabled after staging acceptance. |
| Provider approval | Source and emulator verified; staging pending | Signup is an idempotent callable that trusts verified Auth contact claims, writes `pending_review` with quoting disabled, and notifies active administrators. MFA-authorized administrators approve, request changes, reject, or suspend with mandatory notes. Rules deny forged provider status, and quoting requires the current review schema so legacy `active` documents fail closed and are directed to resubmit. Provider UI shows current state, resubmission controls, and immutable history. Staging deployment and reviewer acceptance remain pending. |
| Route distance | Incomplete | Distance is a labelled straight-line estimate, not reviewed truck routing. |
| Post-award lifecycle | Source and emulator verified; staging pending | Award creates a participant-only transaction. The carrier accepts, schedules, starts transport, and records receiver/delivery proof; the customer confirms closure. Safe cancellation, dispute, administrator resolution, notifications, immutable history, role checks, retries, and forged-write denial are verified in emulators. Attachment-backed signatures, payment, and staging acceptance remain outstanding. |
| Carrier billing | Incomplete | No invoice, payment, adjustment, refund, or reconciliation lifecycle. |
| Bounded job/bid queries | Source and Rules verified; staging pending | Open jobs, owner requests, carrier quotes, per-job bids, and job/bid revision histories keep a live 24-record first page and use cursor continuation for older records. Activity totals use aggregate counts. Composite-index and source-contract tests prevent unbounded/client-filtered regressions; Rules tests verify participant access and stranger denial. Fleet, saved-lane, scale, and transaction-support reads have explicit safety caps. Staging index deployment and representative-volume acceptance remain pending. |

## Live Firebase parity finding

A July 30 read-only inventory for production project `flutter-flow-pipe` found
all 70 then-reviewed Functions active on Node 22 with one consistent deployed
source hash. No missing or unexpected Function was observed in that inventory.
The current completion candidate now declares 74 handlers because it adds four
notification-delivery handlers; those four require controlled deployment and
post-deploy parity evidence before they may be described as live. Every
Function reported `enforceAppCheck: false`; production App Check enforcement is
therefore still a Gate 3 launch blocker and is not counted as verified. Auction
and Dispatch interfaces remain fail-closed in production unless an explicit
build approval and the corresponding server flag are both enabled.

## July 30 large-pass verification

- The unified local release gate completed successfully: Flutter analyzer,
  Flutter tests, release-manifest and acceptance-tooling contracts, Functions
  lint/check/audit, 112 Node tests, 37 Firestore/Storage Rules tests,
  authenticated four-emulator callable integration, and production web build.
- Marketplace publication and detail-edit commands now create bounded,
  server-owned search tokens. The client performs indexed inventory-wide
  keyword lookup, and the deployment contract includes the composite index and
  guarded paginated legacy backfill.
- Auctions and Dispatch can be built for a reviewed production candidate only
  through explicit build defines; their server flags cannot bypass that build
  lock, and production defaults remain disabled.
- A 390x844 emulator-backed visual smoke verified a rendered Flutter frame,
  expected Pipe Buyer accessibility text, removal of the HTML startup overlay,
  884 distinct opaque colors, and zero browser errors.
- These checks verify the repository candidate, not store publication. The
  exact candidate still needs to be committed, exercised through protected
  staging and physical devices, then submitted through the external stores.
- The notification-delivery increment adds four protected or event-driven
  handlers, explicit device opt-in, server-owned endpoint and delivery state,
  retry-safe FCM dispatch, invalid-token cleanup, privacy-safe lock-screen
  copy, critical-failure records, an administrator resolution queue, Android
  and Apple capabilities, and an environment-generated web worker. The final
  unified gate passed 144 Flutter tests, 112 Node tests, 37 Rules tests, the
  authenticated four-emulator workflow, dependency audits, and production web
  packaging; a 390x844 rendered smoke passed with 884 colors and no browser
  errors.

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
- The unified local release gate passes 0 analyzer issues, 72 Flutter tests,
  82 Function/runtime tests, 32 Firestore/Storage rules tests, the complete
  authenticated callable integration including a negative unverified-publisher
  case, high-severity dependency audits, Android packaging, and production web
  packaging. A GitHub clean-run remains required for this branch.
- Protected callable groups now enforce server-time hourly quotas in
  transactionally updated, SHA-256-addressed private buckets. Identical retries
  reuse their fingerprint without consuming another slot; distinct requests
  return `resource-exhausted` after the approved limit.
- Rate-limit policy and hashing pass 2 focused unit tests. Emulator integration
  proves first-use, retry deduplication, quota exhaustion, and continued success
  of all existing workflows. Firestore rules deny all client reads and writes
  to rate buckets, and a bounded scheduled function removes expired buckets.
- Verified communication commands now derive listing participants on the
  server, prevent sellers from opening arbitrary buyer conversations, create
  messages/notifications atomically, and consume retry-safe receipts.
- User reports validate the target relationship and approved reason on the
  server. Chat and report evidence use expiring upload grants that Storage
  Rules bind to owner, purpose, target, exact byte size, MIME type, and path.
  Twenty-nine Firestore/Storage Rules tests include direct-write, cross-owner,
  wrong-target, wrong-size, wrong-type, missing-ticket, and expired-ticket
  rejection.
- The current unified local release gate passes 0 analyzer issues, 72 Flutter
  tests, 82 Function/runtime tests, 32 Firestore/Storage rules tests, authenticated
  callable integration, high-severity dependency audits, Android packaging,
  production web packaging, and release-manifest controls. GitHub clean-run
  evidence remains pending for this branch.
- Account Settings now exposes three server-controlled privacy operations:
  private seven-day data export, refresh-session revocation, and coordinated
  account deletion. Deletion requires recent authentication, exact typed
  confirmation, a 14-day grace period, server-side commercial-obligation
  checks, and a second check immediately before scheduled finalization.
- Direct client deletion of `users/{uid}` is denied. Owner-only export chunks,
  deletion status, and privacy audit visibility pass emulator Rules tests;
  callable integration verifies export generation/download data, schedule,
  cancellation, and refresh-token revocation.
- Sign-in account recovery now confirms the destination before sending a
  Firebase password-reset email and returns a non-enumerating result for both
  registered and unknown addresses. Lost-email/lost-phone assisted recovery
  still requires an approved support and evidence policy.
- Verified accounts now register a random app-installation identifier through
  a server command. The server stores only a hashed document key, bounded
  device label/platform, authentication and activity timestamps, and status;
  it sends a deterministic new-device notification and expires inactive
  history after 180 days.
- Account Settings identifies the current installation, shows owner-only
  remembered-device history, and accurately couples global Firebase refresh-
  session revocation with local sign-out. Rules deny forged or cross-user
  device access, and authenticated emulator coverage verifies registration,
  export inclusion, notification creation, and revoked-state history.

## Gate 4 checkpoint evidence

- Listing creation no longer makes an active public document before selected
  media finishes. A callable creates an owner-private draft with immutable
  expected photo/video counts and a 30-day expiry.
- Storage Rules require the authenticated owner, an open server-created draft,
  approved file names, media MIME types, and five-megabyte photo or
  twenty-five-megabyte video bounds. Arbitrary listing-media hosting is denied.
- The server validates manifest counts, SHA-256 metadata, explicit thumbnail,
  exact owner/listing Storage paths, object existence, content type, and size
  before atomically creating the public listing, private location, and auction
  reserve records.
- Upload failures leave the form and private draft available for retry with
  visible progress. The listing is absent from public browse until finalization
  succeeds. Expired drafts remove their unreferenced Storage objects, while
  account export and scheduled deletion include draft data and media cleanup.
- Unit policy, Firestore/Storage Rules, and authenticated Auth/Firestore/
  Functions/Storage emulator tests cover private drafts, premature publication
  rejection, real uploaded-object verification, retry idempotency, public
  promotion, and draft cleanup. Staging web and physical-device acceptance
  remain pending.
- Marketplace Browse now uses two declared composite indexes for active/newest
  and active/category/newest pages. It fetches at most 24 records per request,
  continues with a document cursor, suppresses duplicate IDs, supports refresh
  and retry, and makes client-side text filtering scope visible as loaded data.
  A configuration test prevents either required index from being removed.
- Auctions, public seller profiles, and owner listings now share the same
  bounded 24-record Firestore pager with cursor continuation, duplicate
  suppression, retry controls, and explicit load-more states. Auction filters
  use server-side transaction/status/time/owner constraints backed by declared
  composite indexes.
- The public listings map reads at most the 200 newest active records, filters
  hidden and request-only locations before marker creation, exposes manual
  refresh and failure recovery, and tells users when its result window is
  capped. The Dispatch listing chooser reads at most 50 newest active records.
- Source-contract tests prevent these surfaces from losing their limits, while
  index-contract tests cover Browse, Auction, and seller-listing query shapes.
- Dispatch load-board feeds now keep only the newest 24 records live and page
  older records by document cursor. Open jobs, personal requests, carrier
  quotes, per-job bids, and permanent job/bid revision histories all share the
  same bounded loader, retry, refresh, duplicate suppression, and load-more UI.
- Dispatch query shapes apply status, owner, carrier, and job constraints on
  the server through five declared composite indexes. Dashboard totals use
  aggregate count queries rather than downloading entire collections.
- Rules tests prove the bounded feeds work for job owners and carriers and deny
  unrelated bid readers. Query/index source tests and the high-severity npm
  audit pass; the patched transitive `brace-expansion` version is locked to
  5.0.8 without downgrading the Firebase Admin runtime.
- Dispatch provider enrollment now begins in `pending_review`, derives contact
  ownership from Firebase Auth, and blocks carrier quotes until approval.
  MFA-authorized administrator decisions require notes and create provider
  notifications plus immutable history. The provider screen shows review
  state, reasons, resubmission, and history; the existing admin dashboard owns
  the unified provider queue. Eighty-four Functions/policy tests, 33 Rules
  tests, and the authenticated four-emulator workflow pass locally.
- Marketplace entities now use stable encoded paths for listings, Auctions,
  public profiles, and participant-only conversations. Route pages handle
  loading, unavailable content, access denial, and return-home recovery; web
  shares copy the current host while native shares avoid inventing an
  unapproved universal-link domain. Firebase Hosting's catch-all rewrite,
  75 Flutter tests, a clean analyzer, and a release web build pass locally.
- Marketplace Browse no longer exposes a placeholder filter action. Listing
  type, exact condition, numeric price range, and newest/price sorting now run
  against bounded Firestore pages, with active removable chips and explicit
  handling for missing numeric prices. Twelve composite-index shapes are
  contract-tested; 78 Flutter tests and 85 Functions/policy tests pass locally.
- Dispatch jobs now have authenticated encoded routes with public load facts,
  access-denied and unavailable recovery, participant-protected transaction
  details, link copying from the load board, and direct continuation into
  Dispatch management or quoting. Exact private locations remain undisclosed.

## Gate 5 checkpoint evidence

- Administrators no longer edit report status directly from Flutter. Three
  retry-safe callable commands own report decisions, user appeals, and appeal
  review; Firestore Rules deny every direct client create/update/delete of
  decisions, sanitized notices, receipts, and immutable case events.
- Administrator review requires the audited administrator role and a current
  Firebase MFA session. Every dismissal, request for information, confirmed
  violation, warning, or content-removal action requires a bounded rationale
  and is recorded in permanent case history.
- Confirmed violations create a private, sanitized notice for the affected
  account without exposing the reporter or private evidence. Account Settings
  displays those notices and offers one server-validated appeal during the
  30-day appeal window.
- Appeal review supports uphold or overturn with a required administrator
  rationale. Overturning restores a listing's pre-moderation state or unhides
  a moderated message when the report still owns that enforcement marker.
- Reporter, affected-user, and appeal-result notifications are deterministic.
  Message rendering suppresses both text and attachments while content is
  hidden, and the original server record remains available for review and a
  safe reversal.
- The clean analyzer, 78 Flutter tests, 88 Functions/policy tests, 34
  Firestore/Storage Rules tests, and the authenticated Auth/Firestore/
  Functions/Storage workflow pass locally, including decision and appeal retry
  idempotency. Staging deployment, reviewer acceptance, external notification
  delivery, policy approval, and staffed support operations remain pending.
- Listing media integrity no longer trusts a client-supplied hash. The publish
  command streams each authorized stored photo, calculates SHA-256 on the
  server, rejects a mismatch, and persists only the trusted fingerprints.
- A bounded indexed trigger detects byte-identical photo reuse across the same
  seller's listings. Its idempotent case includes the compared listing photos,
  matched fingerprints, and related listing IDs in the private administrator
  queue. It does not change listing visibility or the seller's account state.
- Conservative fraud, threat, hate/racist, and vulgar/harassing message signals
  create a private review case with a Unicode-safe 500-character evidence
  excerpt. The source contract and authenticated emulator journey prove
  `humanReviewRequired` is true, `automaticEnforcement` is false, and the
  original message remains visible until an administrator decides the case.
- Automated cases cannot be read by the sender, recipient, reported account,
  or unrelated users. Active administrator roles receive one deterministic
  notification; opening the review queue still requires the audited
  administrator claims and a current MFA session. Trigger retries cannot reset
  a previously reviewed case to pending.
- This checkpoint passes the clean analyzer, 108 Flutter tests, 105 Functions
  tests, 36 Firestore/Storage Rules tests, the authenticated four-service
  emulator journey, dependency audits, ARM64 Android, production web, and an
  actual WebAssembly build. Perceptual/similar-photo matching, a reviewed
  external classifier, staging acceptance, and delivery operations remain
  outside this locally verified increment.
- Account Settings now provides real Help & Support instead of a dead menu
  item. Users choose a category, see its server-controlled first-response
  target before confirming, submit a private case, review permanent history,
  and reply without exposing the case to other users.
- Support administrators receive deterministic notifications and a bounded
  newest-100 queue with urgent and overdue indicators. MFA-protected commands
  own acknowledgement, response, escalation, resolution, and reopening; each
  transition requires a customer-visible note and writes an immutable event.
- Durable in-app notifications now feed an idempotent FCM delivery trigger.
  Endpoint registration and removal are protected commands, endpoint IDs are
  hashed, users must explicitly opt in, private content is excluded from push
  copy, permanent token failures revoke the endpoint, and transient provider
  failures remain retryable. Critical total failures create private
  administrator alerts with a mandatory resolution note. Rules prevent clients
  from forging endpoint or delivery evidence. Provider activation, physical
  device delivery, alert ownership, policy approval, and support staffing are
  still required before Gate 5 is verified complete.
- Support intake and replies have an independent ten-per-hour quota and retry
  receipts. Rules tests prove owner privacy and deny direct owner/admin writes.
  The authenticated emulator verifies create/retry, response, customer reply,
  resolution/retry, notifications, and four-event history.
- `docs/SUPPORT_OPERATIONS_POLICY.md` records response targets, privacy limits,
  escalation boundaries, and the exact staffing, retention, alerting, and
  staging evidence still required before operational approval.
- Account Settings now includes a Policy Center for the five required launch
  documents. It fails closed on an incomplete catalog, requires every document
  to be opened, confirms acceptance, and compares stored versions and hashes
  with the live catalog instead of trusting a stale completion flag.
- MFA-controlled publication requires an HTTPS URL, version, effective date,
  reviewed SHA-256 hash, and decision note. Commercial command enforcement is
  separately activated, cannot be enabled with missing policies, and leaves
  security, reporting, appeals, privacy, and support available.
- Ninety-five Functions/policy tests, 36 Rules tests, the clean analyzer, and
  the authenticated four-emulator workflow now cover publication retries,
  missing-acceptance blocking, exact acceptance, current-user access, and
  controlled enforcement rollback. Legal approval and staging remain pending.
- `docs/POLICY_PUBLICATION_AND_ACCEPTANCE.md` records the publication,
  verification, enforcement, rollback, and ownership requirements.

## Gate 6 checkpoint evidence

- Android, iOS, web, Windows, Linux, and macOS public product surfaces use
  `Pipe Buyer`; template and former display names are contract-tested out of
  those surfaces.
- Android no longer requests legacy external storage and declares camera
  access. iOS includes plain-language camera, photo-library, and foreground
  location disclosures.
- Android release builds never fall back to the debug key. Gradle validates all
  four repository-excluded signing values and the referenced keystore, then
  rejects an unconfigured release graph with an actionable diagnostic.
- A repaired Gradle transform cache produced a fresh ARM64 debug APK in 192.7
  seconds. An unconfigured release dry run failed closed exactly as intended.
- Shared Material theming enforces 48-logical-pixel padded interaction targets.
  Key icon-only actions expose semantics and tooltips; widget tests cover touch
  size, 200% text, and semantic labels.
- `docs/MOBILE_RELEASE_AND_ACCESSIBILITY.md` records signing custody,
  identifier-migration controls, platform disclosures, completed automation,
  and the physical-device/store evidence still required.
- Public `/privacy`, `/terms`, `/support`, and `/account-deletion` destinations
  are registered without authentication. Reviewed policy metadata remains
  server-published and exact-document linked; missing policies fail closed.
  Controlled staging and production startup require a valid public support
  mailbox, and both signed-candidate jobs pass it explicitly. Widget, routing,
  configuration, and workflow tests preserve this boundary. Draft listing copy
  and screenshot coverage are prepared in `docs/STORE_RELEASE_METADATA.md`
  without claiming hosted, legal, mailbox, store, or device approval.
- A generated release web artifact served through the local Firebase Hosting
  rewrite rendered `/support` and `/account-deletion` at 390x844 with the
  expected accessible text, pixel diversity, scrolling content, and no browser
  exceptions. These local screenshots verify the implementation, not hosted
  staging, signed-device, mailbox-ownership, or store acceptance.
- Create Listing now asks whether to use the camera or device gallery, reports
  byte-level progress that never moves backward during a retry, and retries
  only transient storage failures at the same deterministic object path.
  Authorization, size, quota, cancellation, and exhausted-retry failures show
  bounded user-facing messages while the unpublished listing stays a private,
  retryable draft. Three repository tests inject transient and permanent
  failures; the full clean analyzer, 86 Flutter tests, ARM64 Android debug
  build, and production web/Wasm dry run pass locally.
- A checked-in, SHA-256-pinned release-art master now generates branded
  launcher icons and launch screens for Android, iOS, web, Windows, and macOS.
  Representative Android, Apple, and web outputs were visually reviewed; tests
  prevent placeholder or missing generated assets from silently returning.
- The Apple privacy manifest now declares the current app-level data categories
  as app-functionality use without tracking, advertising, or analytics
  purposes. Its XML and required declarations are verified locally. The unused,
  unreferenced notification-service sample is preserved under
  `archive/phase1-disabled` rather than presented as an active capability.
- The branding and privacy checkpoint passed 88 Flutter tests, a clean analyzer, a
  confirmed ARM64 Android APK build, and a production web build with a
  successful Wasm dry run. Signed artifacts, App Store/Play Console review, and
  physical-device acceptance remain pending.
- Reading-order keyboard traversal and a three-pixel high-contrast focus
  treatment now apply from the application root in both light and dark modes.
  Marketplace outline fields receive a visible focus border without losing
  their normal unfocused border treatment.
- A 200-percent-text acceptance matrix covers compact, portrait, landscape,
  and tablet sign-in; compact account creation; keyboard field order; labelled
  icon actions; offer schedules; and accept/counter-offer decisions. It exposed
  clipped schedule chips and off-screen dialog actions, which now stack and
  scroll responsively on a 320x568 viewport.
- This accessibility checkpoint passes 99 Flutter tests, 0 analyzer findings,
  a confirmed ARM64 Android APK build, and a production web build with a
  successful Wasm dry run.
- Release-wide semantic feedback now gives success, information, warning, and
  failure states independent text, icon, and border cues with brightness-aware
  colors. AA contrast is contract-tested in both themes; live-region status
  surfaces remain usable at 200-percent text; snackbars are dismissible.
  Startup/framework recovery, authentication, and profile-photo outcomes use
  the shared path. This checkpoint passes 103 Flutter tests, 0 analyzer
  findings, an ARM64 Android APK, production web, and an actual Wasm build.
- Realtime conversations, account notifications, unread badges, and
  listing-specific notification updates now use explicit 100-record activity
  ceilings or a 450-write batch ceiling. Newest-first conversations use the
  deployed composite index, and boundary notices accurately identify the
  loaded scope. A source contract prevents unbounded listeners from returning.
- Abuse tests issue 64 concurrent unique attempts against a 20-request policy
  and verify exactly 20 commits, then issue 50 identical concurrent retries
  and verify one quota unit. The expanded Function suite passes 98 tests.
- Bid histories, offer revisions, conversation messages, saved listings,
  account-verification reviews, moderation notices, and profile/tag streams now
  have explicit live-query ceilings. Offer histories filter by listing and
  participant on the server, and the buyer path has a checked composite index.
  Visible history surfaces identify a reached latest-100 window so a bounded
  operational view cannot be mistaken for deletion of authoritative data.
- The expanded stream-safety checkpoint passes 103 Flutter tests, 99
  Function/policy tests, a clean analyzer, validated Firestore indexes, an
  ARM64 Android artifact, and a production web build with a successful Wasm
  dry run.
- Auction bidding, Buy It Now, bid withdrawal, auction settlement, offer
  submission and acceptance, marketplace completion/cancellation/dispute,
  Dispatch transaction actions, chat sending, and image attachments now use
  shared accessible live-region feedback instead of raw color-coded SnackBars.
  Command failures preserve safe actionable server text while raw Firebase
  internals and unknown exception strings fall back to controlled guidance.
- Source contracts cover the critical commerce surfaces. The checkpoint passes
  107 Flutter tests, a clean analyzer, ARM64 Android, and production web with a
  successful Wasm dry run.
- Saved-listing actions, sign-in/sign-out, media selection, listing publishing,
  Dispatch signup/jobs/quotes, carrier bidding, fleet setup, policy notices,
  moderation review, and freight-quote publishing now use that same semantic
  feedback boundary. The primary Marketplace shell contains no direct
  SnackBars, and a source contract prevents their return. The expanded pass
  clears a clean analyzer, 149 Flutter tests, 118 Marketplace Function tests, release,
  parity, and acceptance controls, zero production dependency vulnerabilities,
  an ARM64 Android APK, production web, and an actual WebAssembly build.
- Phase 1 acceptance schema 2 now requires the exact signed Android AAB and
  exported Apple IPA, their application identifiers, semantic versions, build
  numbers, release SHA, signature evidence, and store-validation evidence. A
  debug APK, unsigned archive, missing artifact, or self-declared pass without
  retained evidence cannot satisfy the release gate.
- Google Play and Apple App Store evidence now requires named review, four or
  more screenshots, console evidence, and non-placeholder public HTTPS support,
  privacy, terms, and account-deletion URLs. Separate Google data-safety, Apple
  App Privacy, and linked-SDK reviews are mandatory.
- Ten exact target classes cover compact/current Android and iOS phones,
  Android/iOS tablets, and mobile/desktop Chromium and Safari. Each run is
  release-SHA bound and requires the applicable install, media, messaging,
  commerce, permission, network/session recovery, assistive technology,
  large-text/orientation or responsive layout, keyboard, deep-link, and
  notification scenarios with retained evidence.
- Retained AAB/IPA and evidence files are hashed in one-megabyte chunks rather
  than loaded into memory. Canonical paths prevent a directory link from
  escaping the private evidence root. Seven fail-closed validator tests cover
  complete evidence, signatures, URLs, target/scenario completeness, SHA
  binding, path traversal, linked-directory escape, and template drift.
- The upgraded contract passes the complete local release gate with a clean
  analyzer, 108 Flutter tests, 105 Functions tests, 36 Rules tests,
  authenticated four-service emulation, dependency audits, an ARM64 Android
  artifact, production web, and actual WebAssembly. This verifies the control,
  not the still-unperformed signed-device and store acceptance work.
- The required `Quality` workflow now has an independent macOS job that
  compiles the `iphoneos` release target without code signing and fails unless
  Xcode produces `build/ios/iphoneos/Runner.app`. A source contract test keeps
  the runner, release mode, no-signing boundary, output proof, and explicit
  unsigned-evidence disclaimer intact. This closes the previous Apple compile
  blind spot while preserving signed IPA and physical-device acceptance as
  separate external evidence.
- Its first execution exposed an invalid Swift Package Manager public-header
  declaration in `flutter_native_splash` 2.4.4 and a duplicate Xcode object ID
  shared by German and Turkish localizations. The repository now uses the
  SPM-fixed 2.4.8 release with compatible JSONPath/Lottie dependencies, assigns
  the Turkish file a unique identifier, and tests both Xcode object uniqueness
  and the upgraded JSONPath behavior.
- The next native compile reached Xcode and proved the current Firebase Swift
  packages require iOS 15 rather than the repository's previous iOS 14 target.
  Flutter framework metadata and all Runner configurations now share an
  enforced 15.0 minimum instead of downgrading Firebase.
- That build then reached the linker and exposed duplicate Firestore symbols
  from mixing Firebase SPM products with CocoaPods fallbacks required by old
  Apple-sign-in and SQLite plugins. The app now uses the maintainers'
  SPM-capable `sign_in_with_apple` 8.1.0 and `sqflite` 2.4.3 releases, removes
  the obsolete Runner Podfile and all Pods project/configuration wiring, and
  enforces one Swift Package Manager graph in the release contract instead of
  suppressing linker integrity or disabling Swift Package Manager.
- GitHub run `30370442899` independently proved the SPM-only Apple target: the
  unsigned iOS release compile and bundle check passed in 9 minutes 6 seconds,
  while the complete Windows Quality job passed in 38 minutes 43 seconds.
- The protected signed-candidate workflow is manual, checks out one full SHA
  contained in `main`, selects staging or production through a dedicated
  GitHub Environment, and rejects missing or mismatched Firebase/signing
  configuration. Android uses a temporary Play upload keystore and strict AAB
  signature verification. Apple uses an ephemeral keychain, exact manual
  provisioning profile/export options, Flutter's `FLUTTER_XCODE_*` CI signing
  boundary, strict IPA signature/identifier/version checks, and unconditional
  credential cleanup. Both retain a digest and candidate metadata for 14 days
  while explicitly recording that store validation remains false.
- Five workflow contract tests prevent automatic triggers, non-main or short
  release references, unprotected release jobs, missing signing controls,
  missing cleanup, store-validation overclaims, and Firebase project crossover.
  Real workflow execution remains uncredited until the approved environment
  variables, credentials, reviewers, and store accounts are configured.

## Gate 1 checkpoint evidence

- `PIPE_ENV` and complete `PIPE_FIREBASE_*` web build values select the target
  Firebase project. Staging and production reject missing or mixed values.
- The repository-root `firebase.json` serves `build/web`; the Hosting emulator returned
  HTTP 200 from the generated Flutter release.
- The manual deployment workflow checks out a full SHA, reruns the verification
  suite, authenticates through Workload Identity Federation, and deploys only
  to the explicitly configured project in a named GitHub Environment.
- The deploy command attaches the environment, exact SHA, and workflow run to
  Firebase's release message. An always-run artifact retains the release
  manifest, complete deploy log, deployed Function inventory, and exact parity
  result for 30 days, including partial diagnostic evidence from failed runs.
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
  explicitly provisioned. The earlier Functions deployment enabled the Cloud
  Functions API but stopped before creating a Function when Cloud Build and
  Artifact Registry reported that billing was unavailable.
- App Check and Workload Identity configuration are intentionally absent, so
  staging and production deployments still fail closed.
- On July 30, production deployment was executed via `firebase-tools deploy --only functions --force --project flutter-flow-pipe`. All 74 Marketplace Cloud Functions (including `registerNotificationEndpoint`, `unregisterNotificationEndpoint`, `resolveNotificationDeliveryFailure`, and `onUserNotificationCreated`) are active on Node.js 22. In addition, 1 standalone 8 GB 1st-generation `agent` function is retained for Phase 2 AI agent workloads. Total active production functions: **75 Functions**.
- Phase 2 now tracks a fail-closed Node.js 22 replacement under
  `firebase/agent-functions`. It requires administrator claims, MFA, App Check,
  zero warm instances while disabled, bounded operations, and audit records.
  Release manifests and parity checks cover both Function codebases. This is
  source evidence only until a controlled deployment replaces the current
  Node.js 20 resource.
- The Function runtime now pins the affected transitive UUID dependency to
  11.1.1. The audit changed from 7 moderate findings to 0; 112 Marketplace Function tests,
  36 Firestore/Storage Rules tests, and the authenticated four-service emulator
  workflow pass with Firebase Admin 14.2.0 and Functions 7.3.2.
- Deployments now select an explicit App Check rollout mode. `disabled` permits
  isolated staging bootstrap, `observe` requires token-producing clients while
  enforcement remains off, and `enforce` protects callables. Production
  rejects both non-enforcing modes, and release-manifest schema 2 records the
  exact client and callable state.
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
