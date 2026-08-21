# Policy publication and acceptance control

Status: Source verified; Terms/Privacy live-hash verified; remaining three public policy pages added to the release branch and pending Hosting deployment/hash verification before policy publication

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

As of August 22, 2026, the reviewed Terms and Privacy build files were deployed
to Firebase Hosting and independently fetched from the public domain. Their
live bytes matched the release build SHA-256 values exactly. The other three
policy pages now exist on the controlled release branch; they are not yet
considered published policy records until Hosting deployment, independent live
hash verification, owner approval, and operator publication are complete.

## Publication control

An administrator with reviewed role claims and a current Firebase MFA session
may use `publishPolicyDocument`. Production operations may also use
`firebase/functions/scripts/policy_ops.js`, which preserves the policy document
and immutable publication-event model, computes the SHA-256 from the live HTTPS
URL, defaults to dry-run, and requires an explicit production-project
confirmation before a write.

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

`WebLegal` must validate and build all five public policy pages. Its release
script prints a SHA-256 for each built file and instructs the operator to fetch
all five public URLs independently before policy publication.

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

Disable enforcement only for an incident with an approved reason. Disabling
does not delete policy or acceptance history.
