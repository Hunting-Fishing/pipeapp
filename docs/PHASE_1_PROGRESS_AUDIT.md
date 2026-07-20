# Phase 1 progress audit

Audit date: July 20, 2026

Branch: `agent/north-america-foundation`

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
| 0 — Scope lock and safe defaults | No | 90% | Runtime flags, high-risk defaults, clean local verification, and remote CI evidence pass. A controlled isolated Firebase rehearsal is still required. |
| 1 — Environments, builds, diagnostics | No | 42% | Web builds select Firebase configuration by environment and controlled environments fail closed. Hosting serves the verified `build/web` artifact. Exact-commit deployment, deterministic release manifests, and backup/restore procedures now exist. Separate projects, native flavors, a staging deployment/rollback rehearsal, backup/restore proof, deployed release IDs, and monitoring ownership remain incomplete. |
| 2 — Backend parity and commands | No | 25% | Offer, Auction, and Dispatch commands exist and have policy tests in source, but are not deployed to the live Firebase project. Deployed/source parity automation is missing. |
| 3 — Identity and abuse protection | No | 10% | Basic Firebase authentication and a client-written phone registry exist. Verified email enforcement, phone OTP ownership, server uniqueness, App Check enforcement, MFA, rate limits, recovery, deletion, and export remain incomplete. |
| 4 — Product workflows | No | 25% | Rich listing, offer, auction, and Dispatch UI foundations exist. The mandatory persisted and terminal transaction lifecycles remain incomplete. |
| 5 — Trust, notifications, policies | No | 15% | User reporting with attachments and some in-app notifications exist. Moderation operations, appeals, delivery providers, policies, and support operations remain incomplete. |
| 6 — Accessibility, performance, QA | No | 15% | Money/phone formatting and some mobile widget coverage exist. Accessibility, bounded data performance, device/network matrices, and abuse/load testing remain incomplete. |
| 7 — Release readiness | No | 5% | A quality workflow exists. Staging rehearsal, operational ownership, backups, rollback proof, launch review, and monitoring are not complete. |

Overall Phase 1 launch readiness estimate: **29%**.

Completed gates: **0 of 8**.

## Mandatory workflow audit

### Accounts and profiles

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Email ownership | Incomplete | Signup sends a verification email, but marketplace commands and rules do not require `email_verified`. |
| Phone ownership | Incomplete | Phone Auth support exists in generated authentication code, but signup/profile workflows claim a phone registry without completing OTP ownership verification. |
| Account verification meaning | Incomplete | `accountVerified` is driven by profile readiness/review rather than an approved identity-verification workflow. |
| Administrator verification queue | Incomplete | Users can submit `verification_requests`; no complete administrator queue, evidence review, decision, notification, and audit workflow exists. |
| Account deletion | Incomplete | No user-facing coordinated Auth, Firestore, Storage, and registry deletion workflow. |
| Data export | Incomplete | No user-facing export request, generation, download, or audit workflow. |
| Administrator MFA | Incomplete | No MFA enrollment or enforcement evidence. |
| Session/device management | Incomplete | No device list, session revocation, or suspicious-session workflow. |

### Marketplace

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Persisted saved listings | Incomplete | Saves are written to `users/{uid}/saved_listings`, but `_saved` is not loaded after authentication and the Saved page still filters demo fixtures with inconsistent identifiers. |
| Listing lifecycle | Incomplete | Normal listings do not have a complete server command/UI lifecycle for edit, pause, deactivate, archive, sold, and relist. |
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
| Post-acceptance lifecycle | Incomplete | Acceptance stops at `pending_sale`. |
| Terminal states | Incomplete | No complete completed, cancelled, failed, disputed, refunded, or released command/state workflow. |
| Transaction checklist | Incomplete | Dates are displayed, but final buyer/seller confirmations and a controlled completion checklist are absent. |
| External notifications | Incomplete | In-app Firestore notifications exist; no verified push/email delivery and retry workflow. |
| Message spam controls | Incomplete | Messages still use direct client writes without reviewed server throttling. |

### Auctions

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Bid and Buy It Now commands | Source only; live incomplete | Bid, Buy It Now, below-reserve acceptance, and withdrawal commands exist in source but are absent from deployed Functions. |
| Fees and boosts | Safely disabled; payments incomplete | Runtime/build controls hide paid features, but checkout, invoices, receipts, refunds, and reconciliation do not exist. |
| Winning-auction completion | Incomplete | Winning state still relies on messages rather than a settlement workflow. |
| Terminal/default/dispute states | Incomplete | No complete settlement, dispute, buyer-default, seller-default, cancellation, and completed-sale command lifecycle. |

### Dispatch

| Workflow | Status | Evidence or remaining work |
| --- | --- | --- |
| Dispatch commands | Source only; live incomplete | Create, edit, publish, quote, revise quote, and award commands exist in source but are absent from deployed Functions. |
| Provider approval | Incomplete | Signup writes `status: active` and `availableForHire: true` immediately. |
| Route distance | Incomplete | Distance is a labelled straight-line estimate, not reviewed truck routing. |
| Post-award lifecycle | Incomplete | Accepted, scheduled, in-transit, delivered, proof-of-delivery, cancelled, disputed, and closed commands are absent. |
| Carrier billing | Incomplete | No invoice, payment, adjustment, refund, or reconciliation lifecycle. |
| Bounded job/bid queries | Incomplete | Several UI queries remain unbounded or client-filtered. |

## Live Firebase parity finding

The July 20 live inventory for project `flutter-flow-pipe` contains
`createMarketplaceListing` and `updateMarketplaceListingMedia`, plus older
event/scheduled Functions. It does not contain the new Offer, Auction, or
Dispatch callable command exports. Those workflows must remain disabled until
a reviewed staging deployment and end-to-end acceptance pass.

## Gate 1 checkpoint evidence

- `PIPE_ENV` and complete `PIPE_FIREBASE_*` web build values select the target
  Firebase project. Staging and production reject missing or mixed values.
- `firebase/firebase.json` serves `../build/web`; the Hosting emulator returned
  HTTP 200 from the generated Flutter release.
- The manual deployment workflow checks out a full SHA, reruns the verification
  suite, authenticates through Workload Identity Federation, and deploys only
  to the explicitly configured project in a protected GitHub Environment.
- Local verification passed with 0 analyzer issues, 52 Flutter tests,
  31 Functions policy tests, 14 Firestore rules tests, and a release web build.
- Workflow YAML lint passed.
- Release manifest controls passed 4 unit tests and recorded 27 expected
  Functions, deterministic Functions/rules/index/config hashes, and the
  319-file web artifact hash.
- A least-privilege backup, isolated restore, validation, and application
  rollback runbook now exists. It is prepared procedure, not recovery proof.
- This is not deployment evidence. Gate 1 remains open until isolated projects
  are configured and staging deploy/rollback and backup/restore are rehearsed.
