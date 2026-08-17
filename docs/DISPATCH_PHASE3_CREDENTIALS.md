# Dispatch Phase 3 - Credentials and Insurance Metadata

## Purpose

This slice completes the private credential/insurance foundation required before the Dispatch Directory can be unlocked.

It is intentionally not a verification system. Providers can organize self-reported credential metadata and private supporting evidence, but Pipe Buyer must not display a public `Verified` claim until a separate protected review workflow exists.

## Data boundary

Private Firestore owner record:

```text
business_private/{uid}
    dispatchCredentials {
        general_liability_insurance {}
        cargo_insurance {}
        commercial_auto_insurance {}
        workers_compensation {}
        operating_authority {}
        safety_certificate {}
        pilot_escort_certification {}
        crane_rigging_qualification {}
    }
```

Private Storage evidence:

```text
business_documents/{uid}/dispatch_credential_<credential_code>_evidence
```

The existing Storage rule for `business_documents/{userId}/{fileName}` permits reads only to the owner or an administrator. Credential evidence must never be copied into `public_business_profiles` or a future Dispatch Directory projection.

## Stable credential codes

- `general_liability_insurance`
- `cargo_insurance`
- `commercial_auto_insurance`
- `workers_compensation`
- `operating_authority`
- `safety_certificate`
- `pilot_escort_certification`
- `crane_rigging_qualification`

## Self-reported states

The client may store only self-reported operational states:

- `not_provided`
- `self_reported_current`
- `self_reported_expired`
- `not_applicable`

A value such as `verified` is not accepted by the model as a self-reported state. Future verification must be server/admin controlled and stored separately from provider-editable metadata.

## Metadata fields

Each private credential record can contain:

- credential type code;
- self-reported state;
- insurer / issuer / authority;
- policy / certificate / reference number;
- expiry date;
- private notes;
- private evidence storage path.

None of those fields are added to the public company profile projection in this phase.

## Evidence upload

The first UI uses the existing `image_picker` dependency so providers can upload a photo/image of supporting evidence without adding another dependency. The existing private Storage rule also supports PDF business documents; a future file-picker workflow can add PDF selection without changing the privacy boundary.

Uploading evidence does not mean the credential is verified.

## Company Profile integration

Registered providers reach the feature from:

```text
Dispatch
-> Company Profile
-> Credentials & insurance
-> Manage credentials
```

The Company Profile keeps the credential controls separate from public identity/services so non-technical users can understand what is public versus private.

## Phase 3 acceptance gate

Before awarding the final credential point:

1. strict analyzer passes for the new credential source and Company Profile wiring;
2. credential model tests pass;
3. privacy contract tests pass;
4. Phase 3 company profile/equipment/service-area regressions pass;
5. Phase 2 taxonomy and Phase 1 navigation/auth regressions pass;
6. browser acceptance proves metadata survives leaving/reopening the page;
7. private evidence upload remains owner/admin-only and is not visible in public profile data.

Phase 4 remains blocked until the service-area browser acceptance and credential browser acceptance are both complete.
