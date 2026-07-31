# Admin Agent Cloud Function Specification (`agent`)

## Overview

The `agent` Cloud Function is the fail-closed entry point reserved for approved administrative automation. It is not a general user assistant and cannot perform unapproved AI operations.

## Deployment Details

- **Firebase Function ID**: `agent`
- **Region**: `us-central1`
- **Current production generation**: 1st Generation Cloud Function
- **Current production runtime**: Node.js 20
- **Tracked Phase 2 runtime**: Node.js 22
- **Allocated Memory**: 8 GB RAM
- **Current production minimum instances**: 3
- **Tracked disabled default**: 0 minimum instances, 3 maximum instances
- **Status**: Production resource retained; tracked Phase 2 replacement is disabled until a controlled deployment is approved

## Security & Operational Controls

1. **Disabled-by-Default Policy**: `PIPE_AGENT_ENABLED` defaults to `false`. A disabled deployment also requires zero minimum instances.
2. **Administrator Authorization**: Requests require authenticated `admin: true` and `role: administrator` custom claims plus a Firebase MFA session claim.
3. **App Check Protection**: The tracked callable always enables App Check and independently rejects a missing App Check context.
4. **Bounded Operations**: The first Phase 2 source accepts only the non-mutating `status` operation. Every other operation fails closed until separately designed, reviewed, and tested.
5. **Auditability**: Authorized requests create deterministic administrator audit records without storing prompts, credentials, or provider secrets.
6. **Cost & Quota Controls**: Source clamps minimum instances to 0–3 and maximum instances to 1–10. GCP Budget alerts remain external release evidence and must be verified before enablement.
7. **Source Management**: The deployable source is tracked in `firebase/agent-functions`; release manifests and deployment parity include its standalone `functions` codebase.

## Purpose & Future Utilization

1. **Current Foundation**: Provides an authenticated, App Check protected, audited readiness endpoint without executing a model or mutating marketplace data.
2. **Future Expansion**: Each listing-review, catalog, moderation, or operational action must be added as a separately authorized command with bounded inputs, immutable audit history, quotas, human-review rules, and rollback behavior.
3. **Capacity Activation**: Warm instances may be increased only in an approved release with retained budget, quota, load, and rollback evidence.

## Audit Policy

- Automated CI/CD and release readiness audits MUST treat `agent` as an **approved, intentional resource**.
- Total expected production Cloud Functions count: **75 Functions** (74 Marketplace codebase handlers + 1 standalone `agent` handler).
- The live production resource remains Node.js 20 with three warm instances until the tracked Node.js 22 replacement is deployed and parity-verified. Documentation does not count as deployment evidence.
