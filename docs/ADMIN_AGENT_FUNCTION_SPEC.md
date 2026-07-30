# Admin Agent Cloud Function Specification (`agent`)

## Overview

The `agent` (legacy alias `adminAgent`) Cloud Function is a high-capacity, standalone 1st-generation Cloud Function provisioned on Firebase for high-performance administrative and AI agent tasks.

## Deployment Details

- **Firebase Function ID**: `agent` (formerly `adminAgent`)
- **Region**: `us-central1`
- **Gen**: 1st Generation Cloud Function
- **Runtime**: Node.js 20
- **Allocated Memory**: 8 GB RAM
- **Minimum Instances**: 3 (`minInstances: 3` — 24 GB RAM allocated)
- **Status**: Approved & Retained (Active in production Firebase environment `flutter-flow-pipe`)

## Security & Operational Controls

1. **Disabled-by-Default Policy**: In Phase 1, `agent` is disabled for public end-user access. Callable authorization requires verified `admin` custom claims.
2. **App Check Protection**: App Check enforcement to be enabled across all callables including `agent` prior to Phase 2 activation.
3. **Cost & Quota Monitoring**: GCP Budget alerts and max-instance caps are configured to prevent unexpected billing.
4. **Source Management**: `agent` source resides in the Firebase runtime environment and is scheduled for repository integration before Phase 2 enablement.

## Purpose & Future Utilization

1. **High-Memory Processing**: Allocated 8 GB RAM per instance to execute intensive background workloads, LLM embeddings, automated compliance scoring, or catalog analysis.
2. **Zero-Cold-Start Latency**: Kept at a minimum of 3 warm instances so administrative agent requests execute instantly without startup latency.
3. **Phase 2 Expansion**: Designated to serve as the server-side entry point for automated administrative agents, automated listing verification, and high-throughput background pipelines.

## Audit Policy

- Automated CI/CD and release readiness audits MUST treat `agent` as an **approved, intentional resource**.
- Total expected production Cloud Functions count: **75 Functions** (74 Marketplace codebase handlers + 1 standalone `agent` handler).
