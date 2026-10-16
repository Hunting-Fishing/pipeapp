# PipeBuyer Yellow Pages + Contact Center architecture

**Status:** implementation contract for the `feature/pipebuyer-yellow-pages-contact-center` workstream  
**Product:** Pipe Buyer  
**Public surface:** **PipeBuyer Yellow Pages**  
**Private surface:** **PipeBuyer Contact Center**

## Product boundary

PipeBuyer Yellow Pages and the private Contact Center use the same canonical company identity, but they are deliberately different data surfaces.

- The **Contact Center** is a private employee workspace behind Firebase Authentication and server-authorized role claims.
- The **PipeBuyer Yellow Pages** is a public-safe projection of eligible company records.
- Private phone/email notes, contact history, assignments, internal verification evidence, billing evidence, suppression reasons, and employee metadata must never be copied automatically into the public projection.
- A company is public only after the server proves the required verification, billing, and publication states.
- The existing Dispatch Directory remains a separate service-discovery feature and is not repurposed as the Yellow Pages source of truth.

## Canonical collections

### `yellow_pages_companies/{companyId}`

Private, authoritative company/workflow record. Client Firestore access is not required; normal application access goes through protected callable Functions.

Core fields:

- `schemaVersion`
- `companyName`
- `normalizedCompanyName`
- `website`
- `countryCode`
- `regionCode`
- `city`
- `postalCode`
- `streetAddress` (private by default)
- `mainPhone` (private workflow contact)
- `generalEmail` (private workflow contact)
- `publicPhone` (optional public listing value)
- `publicEmail` (optional public listing value)
- `categories[]`
- `services[]`
- `description`
- `sourceReferences[]`
- `assignedAgentUid`
- `outreachStatus`
- `verificationStatus`
- `billingStatus`
- `publicationStatus`
- `doNotContact`
- `doNotContactReason`
- `verifiedAt`
- `verifiedByUid`
- `paidThrough`
- `publishedAt`
- `publishedByUid`
- `createdAt`
- `createdByUid`
- `updatedAt`
- `updatedByUid`

### `yellow_pages_company_contacts/{contactId}`

Private people/department contacts linked by `companyId`.

Suggested fields:

- `companyId`
- `name`
- `title`
- `department`
- `phone`
- `email`
- `isPrimary`
- `sourceReference`
- `lastVerifiedAt`
- `createdAt`
- `updatedAt`

### `yellow_pages_contact_events/{eventId}`

Append-only private activity history. This is the audit trail for calls, emails, callbacks, notes, status changes, and contact outcomes.

Suggested fields:

- `companyId`
- `actorUid`
- `eventType`
- `disposition`
- `summary`
- `contactId`
- `nextFollowUpAt`
- `createdAt`

Do not overwrite historical events to make metrics look cleaner. Corrections should create a new event that references the superseded event.

### `yellow_pages_staff/{uid}`

Server-owned Contact Center roster metadata. Authorization is still based on Firebase custom claims, not on this document alone.

Suggested fields:

- `uid`
- `role`: `agent` or `manager`
- `active`
- `displayName`
- `createdAt`
- `createdByUid`
- `updatedAt`
- `updatedByUid`

### `yellow_pages_audit_events/{eventId}`

Append-only security/business audit records for privileged mutations such as verification, billing state, publishing, unpublishing, DNC changes, assignment changes, and staff-role changes.

### `yellow_pages_public_entries/{companyId}`

Server-owned public-safe projection. Clients never write this collection directly.

Only fields explicitly approved for public display may be emitted, for example:

- `schemaVersion`
- `companyId`
- `companyName`
- `website`
- `publicPhone`
- `publicEmail`
- `countryCode`
- `regionCode`
- `city`
- `categories[]`
- `services[]`
- `description`
- `verified`
- `paidThrough`
- `publishedAt`
- `updatedAt`

Private contact-center evidence, employee UIDs, private addresses, private phone/email values, DNC reason, source notes, internal notes, billing identifiers, and contact history are forbidden from this projection.

## Workflow states

Do not collapse the lifecycle into one overloaded status. Use independent dimensions.

### Outreach

- `not_contacted`
- `assigned`
- `attempted`
- `follow_up`
- `unreachable`
- `do_not_contact`

### Verification

- `unverified`
- `verified`
- `rejected`
- `inactive`

### Billing

- `unpaid`
- `paid`
- `expired`

### Publication

- `unpublished`
- `pending`
- `published`
- `suspended`

This supports the requested dashboard sections without destroying other state. For example, a company can be `verified` + `expired` + `unpublished` without losing its verification history.

## Public publication rule

The server is the only publication authority.

A company is eligible for the public PipeBuyer Yellow Pages only when all of the following are true:

1. `verificationStatus == verified`
2. `billingStatus == paid`
3. `publicationStatus == published`
4. `paidThrough` is absent only for a deliberately non-expiring paid entitlement; otherwise it must still be current
5. required public identity fields pass validation

When eligibility stops being true, the server removes or disables the public projection. Expiration must not leave a stale paid listing visible.

`doNotContact` is a private outbound-contact suppression state. It must stop employee outreach immediately. Whether a DNC company may remain publicly listed is a separate business-policy decision and must not be inferred by client code.

## Dashboard sections

The private Contact Center should expose these operational views:

- **My Queue**
- **Not Contacted**
- **Follow-Ups**
- **Unverified**
- **Verified / Unpaid**
- **Paid / Confirmed**
- **Published**
- **Unpaid / Expired**
- **Do Not Contact**
- **All Companies** (manager/admin)
- **Agents** (manager/admin as permitted)
- **Audit** (admin)

Dashboard counts must be server-derived or based on bounded queries; do not download the entire company collection merely to calculate tiles.

## Authentication and roles

PipeBuyer continues to use Firebase Authentication. The Contact Center gets its own route and access gate; it does **not** create a second password database.

Every employee receives an individual Firebase Auth account. Shared logins are prohibited.

### Existing Pipe Buyer administrators

Existing Pipe Buyer administrator authorization remains authoritative:

- custom claim `admin == true`
- custom claim `role == administrator`
- verified email
- MFA evidence in the current Firebase sign-in

An authorized Pipe Buyer administrator automatically has full Contact Center access.

### Contact Center role claim

Use a dedicated claim so Contact Center authorization does not collide with the existing global `role` claim:

- `yellowPagesRole == agent`
- `yellowPagesRole == manager`

A user must also be active in the server-owned Contact Center roster. The roster is defense-in-depth and operational metadata; a client-writable profile field never grants access.

### Agent

Can:

- load their assigned queue;
- read companies assigned to them or made available by a server queue policy;
- add contact attempts and notes;
- schedule follow-ups;
- correct bounded contact/company fields;
- move normal outreach states.

Cannot:

- publish/unpublish;
- mark billing paid;
- grant verification;
- remove DNC;
- change employee roles;
- access administrator audit/security controls.

### Manager

Can additionally:

- inspect team queues;
- assign/reassign companies;
- review verification candidates;
- manage normal queue operations;
- view team activity metrics.

Manager publication/billing authority remains off unless a later explicit policy grants it.

### Administrator

Full access, including:

- all companies and contacts;
- staff role management;
- verification approval/reversal;
- billing-status administration;
- publish/unpublish/suspend;
- DNC administration;
- imports/exports;
- audit logs;
- configuration.

Initial business requirement: **Jordi and Randall require administrator access**. Jordi's existing Pipe Buyer administrator mechanism should be reused. Randall must be provisioned only after his exact Firebase Auth account is identified, email is verified, MFA is enrolled, and the existing protected administrator provisioning workflow is completed. Do not authorize either person by a Flutter email allowlist.

## Contact suppression / DNC

DNC is a protected control, not a cosmetic tag.

- Any authorized Contact Center employee may record a DNC request.
- Normal agent actions must fail closed once DNC is set.
- Removing DNC requires administrator authority and an audit reason.
- Bulk import must never clear an existing DNC state.
- Deduplication must preserve DNC across merged company records.

## Data import and provenance

Every imported/discovered company should retain source provenance so PipeBuyer can verify freshness and resolve conflicts.

Suggested source record fields:

- `sourceType`
- `sourceName`
- `sourceUrl`
- `sourceExternalId`
- `observedAt`
- `verifiedAt`

Import rules:

- normalize company names/domains/phones before duplicate matching;
- never overwrite a newer verified value with an older imported value silently;
- never overwrite DNC, paid state, verification evidence, or publication state from a bulk import;
- imported companies start `not_contacted`, `unverified`, `unpaid`, `unpublished` unless an administrator explicitly performs a trusted migration;
- bulk import is an administrator/server operation, not an ordinary client write.

## Server command boundary

A dedicated Yellow Pages module inside the repository's existing `firebase/agent-functions` Functions codebase exposes the narrow callable command surface. Reusing the existing codebase keeps the repository's current CI, lint, release-gate, and Firebase deployment wiring intact while keeping Yellow Pages logic in separate source modules.

Public-safe:

- `listPipeBuyerYellowPages`
- `getPipeBuyerYellowPagesEntry`

Private:

- `getYellowPagesAccess`
- `listYellowPagesCompanies`
- `getYellowPagesCompany`
- `upsertYellowPagesCompany`
- `recordYellowPagesContactEvent`
- `assignYellowPagesCompany`
- `setYellowPagesDoNotContact`
- `reviewYellowPagesVerification`
- `setYellowPagesBillingStatus`
- `setYellowPagesPublicationStatus`
- `listYellowPagesStaff`
- `manageYellowPagesStaff`

All private mutations must be server-authorized and audit logged. App Check remains enforced on callable Functions in production.

## Public data projection

Publishing is a one-way sanitizing projection, not a copy of the private company document.

The projection builder must construct a new object from an allowlist of public fields. Never spread (`...privateRecord`) an authoritative private company document into a public object and then try to delete sensitive keys afterward.

## Billing boundary

`billingStatus=paid` must ultimately come from server-authoritative billing evidence. During early controlled setup an administrator may set a manual paid record only through an audited server command that records the payment source/reference and paid-through date.

When Yellow Pages subscription/payment automation is added, Stripe/webhook provider state must replace manual status as authority. A browser redirect must never create paid status.

## Existing Dispatch Directory

Pipe Buyer already has a server-owned Dispatch Directory projection. Preserve it.

The Yellow Pages should not read private Dispatch carrier records or overwrite `dispatch_directory_entries`. A business may later link the same canonical `companyId` to both products, but each public projection keeps its own eligibility and privacy rules.

## Delivery sequence

1. Add isolated Yellow Pages modules to the existing `firebase/agent-functions` codebase and test authorization/status/public projection policy.
2. Add private Contact Center Flutter access client + role-gated dashboard shell.
3. Add public PipeBuyer Yellow Pages page backed by public-safe server data.
4. Add company/contact editing, queue assignment, event history, DNC, and follow-ups.
5. Add verification review and paid/publish workflow.
6. Add employee administration.
7. Add bounded import/deduplication tooling with provenance.
8. Add billing-provider integration and expiry automation.
9. Run emulator, Flutter, Functions, release-manifest, App Check, privacy, and production-safe acceptance gates before activation.

## Non-negotiable security checks

- no shared employee credentials;
- no client-only admin flags;
- no email allowlist as an authorization mechanism;
- no direct client write to public Yellow Pages projection;
- no public projection of private notes/contact history;
- no client authority for paid/verified/published state;
- no agent ability to clear DNC;
- all privileged changes append an audit event;
- bounded/paginated queries for large company inventories;
- keep production deployment behind the repository's existing verified release process.
