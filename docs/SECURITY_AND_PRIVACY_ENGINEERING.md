# Pipe Buyer Security and Privacy Engineering

Status: mandatory engineering contract

## Security model

Assume every client input, network response, uploaded file, external webhook, and provider payload can be malformed, stale, duplicated, malicious, or unauthorized until verified by the correct trust boundary.

## Authentication and authorization

- Authentication proves identity; it does not grant privileged capability by itself.
- Role/ownership/participant checks remain server or Rules authoritative.
- Administrative actions require explicit administrator controls and any configured MFA/App Check requirements.
- Do not accept client-authored role, verification, moderation, financial, lifecycle, or privileged analytics state.

## App Check and abuse protection

Existing App Check and abuse-throttle controls must not be weakened for convenience. Local/emulator development should use supported local paths rather than production bypasses.

High-value/expensive endpoints require bounded input, rate/abuse awareness, and cost amplification analysis.

## Secret handling

Never commit or include in model prompts/logs/issues/screenshots:

- private keys;
- service-account JSON credentials;
- Stripe secret/webhook values;
- API bearer tokens;
- OAuth client secrets;
- database/admin credentials;
- provider signing secrets;
- private environment files.

Public Firebase/Web identifiers are not equivalent to private credentials, but they still belong in the established environment configuration rather than random source duplication.

## Webhook/provider authenticity

Webhook handlers must verify provider authenticity/signatures using the raw payload when required, enforce appropriate timestamp/replay controls, validate expected object/mode/currency/amount, and remain idempotent for duplicate/out-of-order delivery.

## Input and file validation

Validate type, length, range, enum/domain membership, ownership, lifecycle preconditions, and file/media constraints at authoritative boundaries. Client-side validation improves UX but is not a security boundary.

## Data minimization

Store and expose only data needed for a defined product/operational purpose. Keep private participant data out of public marketplace records.

Exact location, identity evidence, private conversation contents, sensitive support evidence, and financial/provider-sensitive metadata require explicit access boundaries.

## Logging and diagnostics

Logs must support failure classification without becoming a secondary sensitive-data store. Prefer identifiers and bounded safe metadata over full payloads/documents.

## Security-sensitive changes

Treat changes to these areas as `HIGH` risk at minimum:

- authentication/session handling;
- authorization/custom claims/roles;
- Firestore/Storage Rules;
- App Check;
- admin tooling;
- payment/webhook/provider signature code;
- file upload/download authorization;
- private-data visibility;
- notification targeting;
- secrets/environment handling;
- audit history;
- abuse/rate limits.

Security changes require negative-path tests. A happy-path test is insufficient.

## Critical prohibited autonomous actions

Autonomous development must not:

- disable production security controls;
- rotate/live-edit credentials;
- grant production roles or service-account permissions;
- expose private collections to simplify UI development;
- bypass signature verification;
- modify production branch/environment protection;
- copy live user data into local fixtures;
- execute destructive remediation against production data.

## Dependency and supply-chain security

New/upgraded dependencies follow `docs/DEPENDENCY_AND_PROVIDER_POLICY.md`. Keep package audits and lockfiles in the verified workflow. Do not accept an unknown binary/script download merely because an AI tool recommends it.

## Privacy changes

A feature that newly collects, derives, exposes, transmits, retains, or deletes personal/user data must state:

- purpose;
- data fields/categories;
- visibility/recipients;
- third parties;
- retention/deletion behavior;
- authorization;
- user-facing disclosure/consent requirement if applicable.

Policy/legal approval remains human-controlled where required.

## Security review result

An autonomous worker changing security-relevant behavior must declare `security_change=true`, identify the trust boundary affected, name negative-path tests, and state any remaining human/environment evidence.