# Policy publication and acceptance control

Status: All five Phase 1 policy documents are live-hash verified and published in production at version `2026.08.22`, revision `1`; policy enforcement remains disabled pending acceptance and stale-version verification

Owner: Product, privacy/legal, Trust & Safety, and engineering

Last updated: August 22, 2026

## Purpose

Pipe Buyer records acceptance only for the exact reviewed policy version a user
opened. The application does not ship placeholder legal text and does not allow
a client or an administrator console write to silently replace a document.

The five Phase 1 policies are:

- Terms of Service (`terms_of_service`) — `https://www.pipebuyer.com/terms`
- Privacy Notice (`privacy_notice`) — `https://www.pipebuyer.com/privacy`
- Prohibited Items Policy (`prohibited_items`) — `https://www.pipebuyer.com/prohibited-items`
- Mapping and Location Policy (`mapping_location`) — `https://www.pipebuyer.com/mapping-location`
- Communications Policy (`communications`) — `https://www.pipebuyer.com/communications`

On August 22, 2026, all five reviewed policy build files were deployed to
Firebase Hosting and independently fetched from the public domain. Every live
file matched the release build SHA-256 exactly. The approving owner authorized
publication, the guarded operator path recomputed each live hash, and all five
production policy records were published at version `2026.08.22`, revision `1`.
A post-publication status check confirmed policy enforcement remained disabled.

## Publication control

An administrator with reviewed role claims and a current Firebase MFA session
may use `publishPolicyDocument`. Production operations may also use
`firebase/functions/scripts/policy_ops.js`, which preserves the policy document
and immutable publication-event model, computes the SHA-256 from the live HTTPS
URL, defaults to dry-run, validates the approval actor, and requires an explicit
production-project confirmation before a write.

Each publication requires:

- the controlled policy identifier and version;
- a public HTTPS document URL;
- the SHA-256 hash of the reviewed document;
- an effective date;
- a short user-facing summary; and
- a 20-1000 character approval note.

The command writes the public current metadata and an administrator-only
immutable publication event. Firestore Rules deny direct client writes to those
records.

Do not publish until the named policy owner has approved the document and an
operator has independently verified that the public URL content produces the
submitted SHA-256 hash.

`WebLegal` validates and builds all five public policy pages. Its release script
prints a SHA-256 for each built file. `VerifyPolicies` independently fetches all
five public URLs and fails closed unless every live byte matches the local
release build before policy publication.

## User acceptance

Account Settings opens the Policy Center. The center fails closed when any
required policy is missing, opens each document externally, and requires the
user to review all five current documents before confirmation.

`acceptRequiredPolicies` re-reads all five current documents in a transaction.
It rejects missing, unpublished, duplicated, or stale versions and records:

- the accepted version and content hash for each policy;
- a deterministic fingerprint for the full set;
- a private current acceptance record;
- an immutable private acceptance event; and
- an idempotency receipt.

The UI determines current status by comparing the acceptance record with the
live policy versions. A stored boolean is deliberately not trusted because a
later publication can make an older acceptance stale.

The next production gate after publication is acceptance verification with new
and existing users plus proof that a stale version is blocked and must be
reaccepted. Do not enable enforcement before that evidence is complete.

## Enforcement rollout

Commercial enforcement is off until explicitly enabled. An MFA administrator
uses `setPolicyEnforcement`, or the guarded operator path, with a recorded actor.
Enabling is rejected unless all five current policies are published. Once
enabled, Marketplace listing, offer, Auction, Dispatch, saved-listing,
transaction, conversation, and message commands reject accounts whose
acceptance is missing or stale.

Account security, data export/deletion, reporting, appeals, and Help & Support
remain available so a user can protect or close an account and seek assistance
without accepting commercial terms.

Before enabling in production:

1. approve the five documents and their retention owner;
2. deploy all five public documents and independently verify their live hashes;
3. publish all five exact versions and record the approval actor/note;
4. complete web, Android, and iOS acceptance with new and existing users;
5. prove stale-version blocking and reacceptance;
6. publish customer communication and support instructions;
7. enable in staging/controlled production rollout and monitor failures; and
8. record the production approval and rollback owner.

Steps 1-3 are complete for version `2026.08.22`. Steps 4-8 remain open.

Disable enforcement only for an incident with an approved reason. Disabling
does not delete policy or acceptance history.
