# Policy publication and acceptance control

Status: Source and emulator verified; legal approval and staging publication pending

Owner: Product, privacy/legal, Trust & Safety, and engineering

Last updated: July 27, 2026

## Purpose

Pipe Buyer records acceptance only for the exact reviewed policy version a user
opened. The application does not ship placeholder legal text and does not allow
a client or an administrator console write to silently replace a document.

The five Phase 1 policies are:

- Terms of Service (`terms_of_service`)
- Privacy Notice (`privacy_notice`)
- Prohibited Items Policy (`prohibited_items`)
- Mapping and Location Policy (`mapping_location`)
- Communications Policy (`communications`)

## Publication control

An administrator with reviewed role claims and a current Firebase MFA session
uses `publishPolicyDocument`. Each publication requires:

- the controlled policy identifier and version;
- a public HTTPS document URL;
- the SHA-256 hash of the reviewed document;
- an effective date;
- a short user-facing summary; and
- a 20-1000 character approval note.

The command writes the public current metadata, an administrator-only immutable
publication event, and a retry receipt in one transaction. Firestore Rules deny
all direct writes to those records.

Do not publish until the named policy owner has approved the document and an
operator has independently verified that the public URL content produces the
submitted SHA-256 hash.

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
uses `setPolicyEnforcement` with a decision note. Enabling is rejected unless
all five current policies are published. Once enabled, Marketplace listing,
offer, Auction, Dispatch, saved-listing, transaction, conversation, and message
commands reject accounts whose acceptance is missing or stale.

Account security, data export/deletion, reporting, appeals, and Help & Support
remain available so a user can protect or close an account and seek assistance
without accepting commercial terms.

Before enabling in production:

1. approve the five documents and their retention owner;
2. publish and hash-verify them in staging;
3. complete web, Android, and iOS acceptance with new and existing users;
4. prove stale-version blocking and reacceptance;
5. publish customer communication and support instructions;
6. enable in staging and monitor failures; and
7. record the production approval and rollback owner.

Disable enforcement only for an incident with an approved reason. Disabling
does not delete policy or acceptance history.
