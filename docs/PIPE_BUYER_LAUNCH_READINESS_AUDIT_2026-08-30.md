# Pipe Buyer launch readiness audit — 2026-08-30

Last reconciled: 2026-08-31

## Purpose

This document is the current launch-readiness checkpoint for Pipe Buyer. It reconciles the live repository and production release with older planning/checkpoint Markdown files and the later repair records in `docs/repairs/`.

It intentionally does **not** invent a new completion percentage. Older percentages in Phase 1/2 and Dispatch planning documents were snapshots taken before substantial later work. Current readiness is expressed by launch domain and by whether a remaining item actually blocks the intended launch surface.

## Audited production baseline

- Repository: `Hunting-Fishing/pipeapp`
- Production source / release pointer: `3790fc600b6d83ac072486b9ca3b6a8e8c311898`
- Protected Firebase production run: `33325938428`
- Production deployment job: `99295953757` — **success**
- Visual acceptance job: `99296786437` — **success**
- Firebase project: `flutter-flow-pipe`
- Production deployment passed full Flutter tests, release-manifest controls, Functions validation, Firestore rules tests, authenticated callable workflows, exact web build, Firebase deployment, deployed Function parity, release identity, and mobile/desktop web visual acceptance.

The preceding failed run `33308967311` is not a current defect. It stopped before deployment and led to the documented lazy-Firebase repair in `docs/repairs/MARKETPLACE_COMMAND_CLIENT_LAZY_FIREBASE_INITIALIZATION_2026-08-30.md`.

## Status legend

- **GREEN** — implementation and current production evidence support launch of this surface.
- **YELLOW** — substantial implementation exists, but a specific acceptance, policy, provider, or UX gap remains before broad launch.
- **RED** — do not activate or advertise this capability until the named blocker is completed.
- **NOT CURRENT SCOPE** — intentionally disabled/gated and not a blocker if it remains disabled.

## Current launch-readiness matrix

| Domain | Status | Current code / production evidence | Markdown reconciliation | Launch decision / next exact action |
| --- | --- | --- | --- | --- |
| Protected Firebase release process | **GREEN** | Production run `33325938428` passed exact-source validation, full Flutter tests, Functions/rules/integration checks, Firebase deploy, Function parity, release identity, and visual acceptance. | `README.md`, `docs/APP_CHECK_ROLLOUT.md`, and later release repair records align with the current protected-release model. | Keep release-pointer + exact-SHA workflow. Do not bypass parity/App Check/rules gates for speed. |
| Firebase App Check / rules / authenticated callables | **GREEN** for current production web | Production release requires the production App Check mode and passed Firestore security rules + authenticated callable workflows. | `docs/APP_CHECK_ROLLOUT.md` is still useful architecture. Its staged rollout language is historical; production now rejects non-enforced mode. | Preserve `enforce` production contract. Native store builds still need their own physical-device attestation acceptance before store publication. |
| Web authentication and account access | **GREEN** | Current repository includes account/security surfaces and protected auth gates; production integration tests passed. | Later auth repair docs supersede older demo/root-routing issues. | No launch repair indicated. Exercise real user sign-in/sign-out/password/social flows during final human acceptance. |
| Public Terms / Privacy / account rights | **GREEN/YELLOW** | Public `web/terms.html` and `web/privacy.html` exist; account hub contains account-management/data-rights surfaces. Payment release controls require exact legal-surface verification during billing activation. | Older Phase docs treated these as acceptance work; later release work made the public surfaces part of the production baseline. | Technically present. Obtain/maintain jurisdiction-specific legal review before expanding beyond the currently intended North American scope. |
| Core marketplace listings / discovery | **GREEN/YELLOW** | Current `lib/marketplace/` contains listing, discovery, filtering, listing-detail, seller/buyer-center, Wanted, auction and related production code. Full repository tests pass. | `docs/PHASE_2_PROGRESS_AUDIT.md` July percentages are historical and should not be read as current completion. | Suitable for controlled web launch. Complete final human buyer/seller journeys with ordinary non-admin accounts before broad promotion. |
| Wanted Ads / matching | **GREEN/YELLOW** | Current repository includes Wanted workflows and matching modules. | The July Phase 2 audit's Wanted percentage is superseded by later code; however this audit did not reproduce every historical backfill/matching acceptance fixture. | Keep enabled if current tests and manual journey pass; validate create → match → contact journey in staging/production-safe test accounts. |
| Timed Buying / accepted-offer marketplace payments | **GREEN** for the documented one-charge web model | Server-authoritative Stripe Checkout, signed webhook state, immutable fee snapshots, Timed Buying transaction mirroring, delayed seller release, and Connect transfer architecture are documented and deployed. | `docs/repairs/MARKETPLACE_PAYMENT_FLOW_TIMED_BUYING_2026-08-29.md`, `PAYMENT_RELEASE_CONTROLS_2026-08-29.md`, and `STRIPE_INTEGRATION_CLOSURE_2026-08-29.md` supersede the earlier Phase 2 statement that paid operation was not yet enabled. | Keep the current separate-charge-and-transfer design. Do not represent it as escrow. Do not add split/deposit charging without a payment-parts ledger. |
| Seller Stripe Connect onboarding / payout readiness | **GREEN** | Express onboarding, return routing, readiness refresh, recipient capability checks, and delayed release are documented and production deployed. | Aug. 30 Connect repair records are canonical for current recipient/API behavior. | No redesign. Continue to require transfer capability + payouts enabled before release. |
| Refund / payment-problem customer UX | **GREEN** | Production SHA `3790fc600...` adds the participant-facing `Payment problem / Request refund review` path after a paid Pipe Buyer transaction. The client sends only the request/transaction identifiers and bounded reason; the existing server workflow calculates refundable amount, creates the financial case, and keeps actual Stripe refund execution administrator/readiness controlled. Protected run `33325938428` and visual job `99296786437` both passed. | `docs/repairs/MARKETPLACE_PAYMENT_REVIEW_REQUEST_UI_2026-08-31.md` closes the follow-up named by `STRIPE_INTEGRATION_CLOSURE_2026-08-29.md`. | Keep clients non-authoritative for refund amount/execution. Actual refund execution remains a separate reviewed server/admin operation. |
| Deposit / split payments | **RED if advertised; otherwise NOT CURRENT SCOPE** | Current financial model is one marketplace charge plus later seller transfer. | `PAYMENT_RELEASE_CONTROLS_2026-08-29.md` explicitly requires a separate immutable payment-parts ledger before deposits/balances. | Keep disabled and out of marketing until payment-parts, charge-specific refund, and dispute attribution are implemented. |
| Web Dispatch/VIP memberships | **GREEN** | Unified Free → Dispatch Monthly/Yearly → VIP model is production deployed. Approved Stripe Price IDs are tier authority; VIP includes Dispatch; app controls plan transitions; dedicated billing portal remains restricted. | `docs/repairs/MEMBERSHIP_TIER_MIGRATION_AND_NATIVE_BILLING_2026-08-30.md`, Dispatch promo and portal repair records supersede older subscription checkpoints. | Web membership is production-ready. Keep generic Stripe portal price switching disabled; Pipe Buyer owns approved migrations. |
| Native Apple/Google paid memberships | **RED for store launch** | Flutter IAP/native provider foundation exists, but production purchase verification/reconciliation is deliberately fail-closed/unexported until real store setup exists. | The membership repair record explicitly states native billing is preparation, not activation. README also treats store publication as separate. | Provision App Store Connect + Google Play products/credentials, test sandbox/TestFlight/Play purchases/restores/renewals/plan changes, then activate server verification/reconciliation. Do not route native digital memberships through Stripe as a shortcut. |
| Messaging | **GREEN/YELLOW** | Current messaging page uses real Firestore conversations, unread state, attachments, offer/transaction integration and report entry points. Notification infrastructure is present and the production web notification worker passed release validation. | Earlier Phase docs list messages/transactions as UX work; current repository is materially beyond that checkpoint. | Web messaging is suitable for controlled launch. Validate push/deep-link behavior on physical Android/iOS devices before native store launch. |
| Reporting / anti-scam evidence / admin moderation | **GREEN/YELLOW** | `marketplace_reporting.dart` supports structured report reasons, private evidence uploads, authenticated report submission, and admin moderation queues including reports, Dispatch providers, delivery alerts, and support. | This is stronger than the old planning checkpoints. | Reporting/moderation is launch-capable. A user-to-user block/mute feature was not evidenced in this audit; treat that as P1 trust UX rather than pretending it exists. |
| User block / mute | **YELLOW** | No clear current implementation was found by repository search during this audit. | No later repair record was found establishing this as complete. | Add a simple block/mute contract if launch policy requires users to stop direct contact from another account. Ensure it affects messaging/contact visibility without destroying evidence needed by moderation. |
| Notifications | **GREEN/YELLOW** | Notification service/plugin infrastructure exists; production release verified the web notification worker and includes delivery-failure admin visibility. | Older Phase acceptance requirements for physical mobile notification journeys remain relevant. | Web notification infrastructure is green. Physical iOS/Android permission, token refresh, foreground/background/deep-link acceptance remains P1 for native launch. |
| Dispatch provider profiles / credentials | **GREEN/YELLOW** | Current repository contains company profile, service taxonomy, equipment capability, credentials, admin/provider management and analytics/reminder code. Numerous credential repair records show later stabilization. | `docs/DISPATCH_NETWORK_MASTER_PLAN.md` stating 50% / Phase 4 blocked is demonstrably stale: Phase 4 Directory and credential repair records exist in the same repository. | Do not use the old 50% figure. Run one current provider onboarding/profile/credential human journey and record a new Dispatch acceptance checkpoint before broad provider recruitment. |
| Dispatch Directory / discovery | **GREEN/YELLOW** | `marketplace_dispatch_directory.dart` and many Phase 4 Directory repair/test records exist, including seeded lifecycle, filters, scroll, dropdown, interaction and runtime stability. | This directly supersedes the Aug. 17 master plan's “Phase 4 = 0/20” status. | Directory implementation is real. Validate production data quality, privacy, filters and empty/error states with real provider records before broad launch. |
| Dispatch requests / quotes / award / completion | **YELLOW** | Repository contains Dispatch dashboard, main page, quote form/planner, transaction, trucking plan, freight quote and digital BOL modules; later quote/Phase 3 repair records exist. | Old master-plan phase ledger is no longer a reliable completion measure. | Perform a fresh end-to-end request → provider discovery → quote → messaging → award → work/completion journey and document the exact accepted path. Do not infer completeness only from file presence. |
| Dispatch freight charging / settlement | **RED if transaction fees are intended at launch** | Existing Stripe closure documentation explicitly says a separate Dispatch freight ledger is required before charging transaction fees on hauling jobs. | This later payment repair constraint is more authoritative than generic Dispatch planning language. | Keep Dispatch job charging/settlement disabled until a freight-specific ledger, refund/dispute attribution and payout boundary are designed/tested. Membership fees may remain live separately. |
| Open maps / geolocation | **GREEN** for map/location foundation | `marketplace_location_picker.dart` uses `flutter_map`, configurable `MAP_TILE_URL`, and defaults to OpenStreetMap tiles. `open_address_autocomplete.dart` uses configurable `GEOCODER_URL` and defaults to Photon. Location UI distinguishes exact/approximate/on-request/hidden visibility and explicitly keeps private Dispatch/community pins private. | This materially advances the older Phase 2/Dispatch map checklist. `SERVICE_AREA_TOWN_REGION_BOUNDARY_CLASSIFICATION.md` and Directory repair records preserve later geography fixes. | Open-map requirement is implemented. Preserve configurable providers and privacy classes. Do not expose private exact pins in public Directory/search documents. |
| Advanced routing / route optimization / fleet capacity | **YELLOW** | Map/geocoder foundation is present, but this audit did not establish a production-grade truck-routing provider, saved-route optimization, or full fleet-capacity dispatch engine. | Those items remain named in older Phase 2 / Dispatch planning docs and were not proven superseded here. | Treat as P2 unless the launch promise includes automated trucking routes/ETA optimization. If promised, choose and contract a routing provider first. |
| Tax readiness | **YELLOW** | Production payment controls allow Checkout under audited tax-collection deferral while `stripeTaxReady=false`; automatic tax is not falsely enabled. | `PAYMENT_RELEASE_CONTROLS_2026-08-29.md` is the current constraint. | Do not turn on Stripe automatic tax until actual registrations/readiness are complete. Obtain tax/accounting review for each launch jurisdiction and payment type. |
| International expansion | **YELLOW for North America; RED for unrestricted international launch** | Data models include country/region/postal fields and open map providers, but current UX/defaults and payment/tax/store policies are still strongly North-America oriented. | Project plans say international eventually, but current repair records focus on Canadian/North-American production. | Launch North America first. Before other regions add currency, tax/legal, unit/localization, sanctions/payment-provider and address-format acceptance per country. |
| Regulated property publishing | **NOT CURRENT SCOPE** | README says regulated property publishing stays disabled pending legal/brokerage requirements. | This remains an intentional safety boundary. | Keep disabled; it is not a launch blocker for pipe/equipment/Dispatch. |
| Weight/catalog confidence and analytics definitions | **YELLOW / P2** | Current repository contains weight/catalog/admin and analytics-related code, but the July audit's source-attribution/confidence and analytics-definition gaps were not fully re-proven here. | Old percentages are stale, but the underlying quality goals remain valid. | Improve provenance/confidence/history and freeze launch KPI definitions after core transaction/support journeys are accepted. |
| Native physical-device/store acceptance | **RED for native store publication** | Production web visual acceptance passed mobile and desktop browser sizes, but that is not equivalent to TestFlight/Play physical-device acceptance. | Phase 1.1 and Phase 2 both correctly require physical mobile/offline/accessibility acceptance; README says store publication is separate. | Complete Android/iOS signing, App Check attestation, store billing, push permissions, deep links, offline/error states, accessibility and store review before native public release. |

## Documentation reconciliation

### `README.md`

Treat as the best high-level repository overview. Its protected-production baseline is consistent with the current release. Its statement that Android/Apple store publication is separate remains correct.

### `docs/PHASE_1_1_EXPERIENCE_UPGRADE.md`

Treat as a **historical delivery plan**, not a current percentage/progress authority. Its safety boundaries remain binding: UX work must not weaken Auth, App Check, rules, server commands, idempotency, moderation/reporting, feature flags, or exact-release evidence. Its physical-device/accessibility acceptance requirements also remain useful.

### `docs/PHASE_2_PROGRESS_AUDIT.md`

Treat as a **historical July 31 checkpoint**. The recorded 70% overall / 24% end-to-end figures are superseded by later implementation and production releases. Do not copy those figures into current launch reporting. Individual unfinished goals may still be valid where this audit has not found later evidence of completion.

### `docs/DISPATCH_NETWORK_MASTER_PLAN.md`

Treat its product principles and privacy/security rules as active, but treat the **50% / Phase 4 blocked** ledger as superseded. Later repository evidence includes Phase 4 Directory implementation and repair records plus extensive credential/quote stabilization. A new current Dispatch acceptance checkpoint should replace the old phase percentage rather than attempting to reverse-engineer a percentage from file counts.

### `docs/APP_CHECK_ROLLOUT.md`

Architecture remains valid. The early staged rollout sections are historical; current production release controls enforce the production App Check contract.

### `docs/repairs/*.md`

For closed defects and financial/security invariants, later repair records are the canonical source. In particular, do not undo these constraints merely because an older phase plan describes a broader aspiration:

- marketplace uses server-authoritative Checkout and separate charge/transfer release architecture;
- Pipe Buyer does not claim escrow/trust custody;
- deposits/split payments need a payment-parts ledger;
- Dispatch job monetization needs a freight-specific financial ledger;
- Stripe tier entitlement is determined from approved Price IDs;
- native membership verification stays fail-closed until Apple/Google provider readiness exists;
- production App Check/release parity gates are not optional;
- deterministic/test-only paths must not eagerly initialize production Firebase dependencies.

## Launch scope decision

### Controlled North American web launch

**Current assessment: launch-capable with P1 acceptance work, not blocked by the old phase percentages.**

The strongest production foundations are release security, current web memberships, seller Connect, one-charge marketplace payment/release architecture, controlled payment-problem/refund-case intake, open-map location handling, reporting/moderation, and substantial marketplace/Dispatch implementation.

Before broad paid promotion, close or explicitly accept the remaining P1 items: a fresh ordinary-user end-to-end acceptance pass, physical-device notification testing if mobile web/app is promoted, provider Directory data/privacy acceptance, a deliberate block/mute product decision, and current legal/tax review for the exact launch jurisdictions/payment types.

### Native App Store / Google Play launch

**Not ready yet.** Repository preparation is not the same as store activation. Store products, credentials, server verification/reconciliation activation, TestFlight/Play transactions, App Check attestation and physical-device acceptance are still required.

### Dispatch per-job transaction-fee launch

**Not ready yet.** Keep Dispatch membership monetization separate from hauling-job settlement until the documented freight-specific financial ledger exists.

### Unrestricted international launch

**Not ready yet.** Keep North America as the first operating scope while jurisdiction-specific tax/legal/payment/localization work is completed.

## Prioritized work queue

### P0 — only for the launch surface named

1. **Native stores:** provision Apple/Google subscriptions + credentials; implement/activate production verification and renewal reconciliation only after sandbox/TestFlight/Play acceptance.
2. **Dispatch per-job charging:** build the separate freight ledger before enabling transaction fees or payout automation for hauling jobs.
3. **New jurisdictions:** do not expand internationally until tax/legal/payment/localization acceptance exists for the target jurisdiction.

### P1 — before broad public promotion

1. Run and record fresh ordinary-user journeys for buyer, seller, Timed Buying/auction, reporter/admin, and Dispatch requester/provider; use staging/test-mode payment rails where a real charge is not appropriate.
2. Decide and, if required, implement user block/mute while preserving moderation evidence.
3. Validate push permissions/token refresh/deep links on physical Android and iOS devices.
4. Run current Dispatch Directory/provider data-quality + privacy acceptance with real representative records.
5. Obtain current legal/tax review for the exact North American launch jurisdictions and enabled payment types.

### P2 — post-core launch hardening

1. Advanced truck routing / ETA / saved-route / fleet-capacity provider integration.
2. Weight/catalog source attribution, confidence and correction history.
3. Freeze product/operations analytics definitions and launch KPIs.
4. Localization, currency, units and jurisdictional policy expansion beyond North America.

## Do-not-repeat / repair discipline

- Do not use stale phase percentages as evidence of current readiness.
- Do not mark a capability complete merely because a source file exists; require a tested journey or production evidence.
- Do not create fake live Stripe subscriptions/charges to satisfy an acceptance checkbox.
- Do not weaken Auth, App Check, Firestore/Storage rules, Stripe webhook authority, or payout gates to make UI tests pass.
- Do not make clients authoritative for prices, discounts, entitlements, refunds, payouts, or store purchases.
- Do not describe separate charges + delayed transfers as escrow.
- Do not activate deposit/split or Dispatch job charging on top of a ledger that cannot attribute each charge/refund/dispute.
- Do not re-run one-time production activators merely to test them after successful activation.
- When a repair is required, identify the root cause, validate the exact repair, and add/update the relevant repair record.

## Next audit checkpoint

Update this document after a material launch-domain change, especially:

- Apple/Google store activation,
- Dispatch freight financial ledger,
- user block/mute launch decision,
- final ordinary-user journey acceptance,
- international jurisdiction activation.

Historical phase plans should remain available for context, but current launch decisions should reference this audit plus the later domain-specific repair records.