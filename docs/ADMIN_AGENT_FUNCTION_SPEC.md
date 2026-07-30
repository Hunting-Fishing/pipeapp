# Admin Agent Cloud Function Specification (`adminAgent`)

## Overview

The `adminAgent` Cloud Function is a high-capacity, standalone 1st-generation Cloud Function provisioned on Firebase for high-performance administrative and AI agent tasks.

## Deployment Details

- **Function Name**: `adminAgent`
- **Region**: `us-central1`
- **Gen**: 1st Generation Cloud Function
- **Runtime**: Node.js 20
- **Allocated Memory**: 8 GB RAM
- **Minimum Instances**: 3 (`minInstances: 3`)
- **Status**: Approved & Retained (Active in production Firebase environment `flutter-flow-pipe`)

## Purpose & Future Utilization

1. **High-Memory Processing**: Allocated 8 GB RAM per instance to execute intensive background workloads, LLM embeddings, automated compliance scoring, or catalog analysis.
2. **Zero-Cold-Start Latency**: Kept at a minimum of 3 warm instances so administrative agent requests execute instantly without startup latency.
3. **Phase 2 Expansion**: Designated to serve as the server-side entry point for automated administrative agents, automated listing verification, and high-throughput background pipelines.

## Audit Policy

- Automated CI/CD and release readiness audits MUST treat `adminAgent` as an **approved, intentional resource**.
- Total expected production Cloud Functions count: **75 Functions** (74 Marketplace codebase handlers + 1 standalone `adminAgent` handler).
