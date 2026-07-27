# Phase 1 progress audit

Audit date: July 28, 2026

Branch: `agent/phase1-release-acceptance-control`

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
| 2 — Backend parity and commands | No | 92% | The 70 reviewed Function exports cover the Phase 1 command boundary and direct clients cannot author authoritative verification, privacy, device, listing, provider, rate-limit, commerce, communication, moderation, support, policy, dispute, or Dispatch state. The Firebase runtime dependency lock now resolves the vulnerable UUID chain at 11.1.1 with 0 npm audit findings. Ninety-five Function tests, 36 Firestore/Storage Rules tests, and the authenticated Auth/Firestore/Functions/Storage workflow pass. Exact release manifests record `disabled`, `observe`, or `enforce` App Check state, production requires enforcement, and parity automation rejects missing, unexpected, or inactive deployed handlers. Staging deployment and exact deployed parity remain pending because Google still reports `pipebuyer-5c77f` is not on Blaze. |
| 3 — Identity and abuse protection | No | 93% | Signup and sign-in enter a cross-platform ownership screen until Firebase Auth email and mobile-phone providers are verified. Protected Marketplace, Offer, Auction, Dispatch, messaging, reporting, media, and privacy commands require current Auth claims and bounded quotas; phone uniqueness is synchronized into a hashed server-owned registry. Account verification requires verified ownership, complete public-profile evidence, a server submission, and an MFA-authorized administrator decision with a required note, immutable history, and notifications. Administrator authorization requires an audited custom role plus a current-session MFA claim. Users can review privacy-limited remembered app installations, receive a new-device notification, generate a private expiring export, revoke all refresh sessions, schedule or cancel coordinated deletion, and start non-enumerating email/password recovery. Staging Phone Auth/App Check/MFA activation, assisted recovery for lost email/phone access, physical-device acceptance, live administrator acceptance, suspicious-device operations, and retention-policy approval remain incomplete. |
| 4 — Product workflows | No | 89% | Saved listings, normal listing lifecycle, draft-first media publication, bounded Marketplace/Dispatch discovery, review-based Dispatch provider enrollment, recoverable entity routes, and indexed Marketplace filters are locally verified. Browse supports server-side listing type, exact condition, minimum/maximum price, newest, and price sorting across bounded pages, while clearly labelling keyword search as loaded-result scope. Browse, Auctions, seller profiles, owner listings, open Dispatch jobs, personal requests, carrier quotes, per-job bids, and revision histories use one indexed 24-record cursor pager with retry/load-more controls. Listings, Auctions, public profiles, participant conversations, and authenticated Dispatch jobs have encoded GoRouter paths with loading, not-found, access-denied, privacy, and return-to-Marketplace states; Firebase Hosting rewrites browser refreshes to Flutter. Dispatch job links expose only public route/load facts and participant-authorized transaction data, then open Dispatch management or quoting. Dispatch provider applications use verified Auth contact claims, begin in `pending_review`, require an MFA-authorized administrator decision, block quoting until approval, and retain notifications and immutable review history. Dispatch keeps only its newest page live, uses server-side owner/carrier/job filters, and obtains activity totals through aggregate counts instead of downloading records. The map is capped to the 200 newest active records, exposes refresh/error/result-scope states, and excludes private locations; the Dispatch listing picker is capped to 50 newest active records. Offers and winning auctions have participant-only confirmations, controlled disputes/default reports, notifications, and immutable history. Dispatch awards create participant-only transactions with carrier acceptance, scheduling, in-transit, structured delivery proof, customer closure, pre-transit cancellation, dispute, administrator resolution, notifications, and immutable history. Indexed full-text search, true truck-route/geospatial search, native universal-link association, payment release/refund, route calculation, and carrier billing remain incomplete. |
| 5 — Trust, notifications, policies | No | 88% | User reporting, evidence attachment authorization, safe retry receipts, rate limits, MFA-authorized administrator decisions, required rationale, immutable case history, private affected-user notices, reversible content removal, a 30-day user appeal, administrator appeal review, private support operations, and exact-version policy publication/acceptance/enforcement are locally and emulator verified. External push/email delivery, approved policy text/retention ownership, support staffing, alerting, and staging acceptance remain incomplete. |
| 6 — Accessibility, performance, QA | No | 82% | Pipe Buyer now has consistent public product naming; generated release artwork; a checked Apple privacy manifest; permission disclosures; no legacy Android storage opt-in; 48-pixel interactions; reading-order keyboard traversal; high-contrast light/dark focus indicators; focused form borders; semantic labels/tooltips; responsive compact offer controls; resilient listing media; a shared success/information/warning/error system with text, icon, and border cues; and bounded conversation, notification, bid, offer, message, saved-item, verification, moderation, and tag streams. Automated tests enforce WCAG AA status-text contrast in both themes, live screen-reader announcements, dismissible feedback, concurrent abuse quotas/retries, bounded activity/history/operations reads, participant-scoped offer queries, batch ceilings, 200% text, viewport, touch-target, branding, privacy, permission, signing, retry, authorization, and size contracts. The clean analyzer, 103 Flutter tests, 99 Function tests, validated indexes, ARM64 Android, production web, an actual WebAssembly build, and the fail-closed signing guard pass locally. Signed mobile installation, Apple archive and linked-SDK privacy review, complete manual screen-reader/keyboard/contrast acceptance, physical-device matrices, store metadata/screenshots, and representative staging load testing remain incomplete. |
| 7 — Release readiness | No | 10% | A quality workflow and a release-SHA-bound acceptance validator exist. The validator requires all ten journeys, measured Hosting/Functions/Rules/data recovery controls, a reviewed defect inventory with no open P0/critical/high defects, and named product, engineering, security, Trust & Safety, support, privacy, and legal approvals. It rejects missing, stale, mismatched, unsafe-path, and incomplete evidence and hashes retained artifacts. Actual staging rehearsal, operational ownership, backup restore, rollback proof, launch review, monitoring, approvals, and invitation-only pilot remain incomplete. |

Overall Phase 1 launch readiness estimate: **90%**.

Completed gates: **1 of 8**.

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
| Search and filtering | Source verified for structured filters; full text pending | Browse queries active Marketplace inventory by category, listing type, exact condition, and optional numeric price bounds, with indexed newest or price ordering and bounded cursor continuation. Invalid/reversed money ranges are rejected before querying; listings without numeric prices are explicitly excluded from price filters. Active filters are visible and individually removable. Keyword search is accurately labelled as loaded-result scope; a reviewed indexed full-text strategy remains incomplete. |
| Pagination/geospatial search | Source verified; route search pending | Marketplace Browse, Auctions, public profiles, owner listings, open Dispatch jobs, personal requests, quotes, bids, and histories use bounded cursor pages. The map is capped at 200 current public records and the Dispatch listing picker at 50. True truck-route and server-side geospatial search remain incomplete. |
| Home notification action | Resolved in source | The former dead Home bell is no longer exposed. Account Notifications remains the working destination. |
| View/See all actions | Resolved in source | Featured `See all` opens Browse and offer revision history opens its complete history dialog. |
| Help placeholder | Resolved in source | The dead drawer item was removed pending a real support workflow. |
| Wanted ads and RFQs | Source repaired; verification pending | The drawer now opens Create Listing preselected as a Wanted ad rather than redirecting to ordinary Browse. |
| Shareable routes | Source verified; staging/native association pending | Encoded GoRouter paths now restore listings, Auctions, public profiles, participant-only conversations, and authenticated Dispatch jobs with loading, offline/access, unavailable, privacy, and return-home states. Cards, seller links, message lists, simple conversation entry points, and Dispatch load-board share actions use the routes; shares copy a browser URL on web and a safe relative app path on native. Firebase Hosting already rewrites browser refreshes to `index.html`. Hosted refresh acceptance and approved-domain Android App Links/Apple Universal Links remain pending. |

### Offers and transactions

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Live Offer commands | Source only; live incomplete | `createMarketplaceOffer` and `acceptMarketplaceOffer` exist in source and are used by Flutter, but are absent from the deployed `flutter-flow-pipe` Functions inventory. |
| Post-acceptance lifecycle | Source and emulator verified; staging pending | Acceptance creates a participant-only transaction. Buyer and seller confirmations advance independently and both are required to complete the sale; early cancellation reopens the listing, disputes preserve the pending sale, and each transition is revisioned and idempotent. |
| Terminal states | Partially implemented | Completed, pre-confirmation cancelled, and disputed states have server commands and emulator coverage. Failed, payment-refunded, and funds-released states remain intentionally unavailable until a payment and settlement provider is approved. |
| Transaction checklist | Source and emulator verified; staging pending | The accepted-offer UI shows agreed amount, quantity, both participant confirmations, controlled actions, and permanent revision history. Purchase, transfer, trucking, and Dispatch terms remain copied from the accepted offer. |
| External notifications | Incomplete | In-app Firestore notifications exist; no verified push/email delivery and retry workflow. |
| Message spam controls | Source and emulator verified; staging pending | Conversation creation, unread state, sending, notification creation, and attachment consumption are verified server commands. Messaging has an independent hourly quota, retry receipts prevent duplicate messages, and Rules reject direct conversation/message writes. |

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
| Provider approval | Source and emulator verified; staging pending | Signup is an idempotent callable that trusts verified Auth contact claims, writes `pending_review` with quoting disabled, and notifies active administrators. MFA-authorized administrators approve, request changes, reject, or suspend with mandatory notes. Rules deny forged provider status, and quoting requires the current review schema so legacy `active` documents fail closed and are directed to resubmit. Provider UI shows current state, resubmission controls, and immutable history. Staging deployment and reviewer acceptance remain pending. |
| Route distance | Incomplete | Distance is a labelled straight-line estimate, not reviewed truck routing. |
| Post-award lifecycle | Source and emulator verified; staging pending | Award creates a participant-only transaction. The carrier accepts, schedules, starts transport, and records receiver/delivery proof; the customer confirms closure. Safe cancellation, dispute, administrator resolution, notifications, immutable history, role checks, retries, and forged-write denial are verified in emulators. Attachment-backed signatures, payment, and staging acceptance remain outstanding. |
| Carrier billing | Incomplete | No invoice, payment, adjustment, refund, or reconciliation lifecycle. |
| Bounded job/bid queries | Source and Rules verified; staging pending | Open jobs, owner requests, carrier quotes, per-job bids, and job/bid revision histories keep a live 24-record first page and use cursor continuation for older records. Activity totals use aggregate counts. Composite-index and source-contract tests prevent unbounded/client-filtered regressions; Rules tests verify participant access and stranger denial. Fleet, saved-lane, scale, and transaction-support reads have explicit safety caps. Staging index deployment and representative-volume acceptance remain pending. |

## Live Firebase parity finding

The July 23 read-only inventory for project `flutter-flow-pipe` predates the
current 70-export reviewed source. The automated parity control therefore
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
- Account Settings now provides real Help & Support instead of a dead menu
  item. Users choose a category, see its server-controlled first-response
  target before confirming, submit a private case, review permanent history,
  and reply without exposing the case to other users.
- Support administrators receive deterministic notifications and a bounded
  newest-100 queue with urgent and overdue indicators. MFA-protected commands
  own acknowledgement, response, escalation, resolution, and reopening; each
  transition requires a customer-visible note and writes an immutable event.
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
- The July 28 retry used the pinned Firebase CLI 15.24.0, authenticated as
  `jordilwbailey@gmail.com`, confirmed zero staging Functions and 70 reviewed
  exports, then stopped when Google again rejected Cloud Build and Artifact
  Registry enablement because `pipebuyer-5c77f` was not on Blaze. No Function
  was created and production was never selected.
- The Function runtime now pins the affected transitive UUID dependency to
  11.1.1. The audit changed from 7 moderate findings to 0; 95 Function tests,
  36 Firestore/Storage Rules tests, and the authenticated four-service emulator
  workflow pass with Firebase Admin 14.2.0 and Functions 7.3.0.
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
