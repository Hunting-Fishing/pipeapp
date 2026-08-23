# Pipe Buyer Dependency and Provider Policy

Status: mandatory engineering contract

## Default

Do not add a package, SDK, framework, API, SaaS provider, or cloud service merely because it reduces the amount of code in one task. Every dependency expands security, compatibility, cost, privacy, and operational surface.

## Package dependency requirements

Before adding a runtime dependency, identify:

- capability gap not reasonably satisfied by current dependencies/platform libraries;
- package owner/maintenance activity and release history;
- compatibility with supported Flutter/Dart/Node/platform versions;
- security/advisory posture;
- licence suitability for intended commercial distribution;
- transitive dependency impact;
- binary/app-size or build impact when relevant;
- upgrade/pinning strategy;
- replacement/removal path.

Development/test-only dependencies still require justification but may have a lower operational risk.

## Framework proliferation

Do not introduce a second routing, state-management, design-system, networking, database abstraction, logging framework, or test framework for a localized feature unless a recorded architecture decision approves it.

Prefer one coherent established project pattern.

## Version and lockfile policy

- Manifests and lockfiles move together when the package manager expects them to.
- Do not manually edit generated lockfile internals unless the toolchain requires it.
- Broad dependency upgrades are separate tasks from unrelated feature work.
- Security updates should still be bounded and tested for behavior/build regressions.
- Do not silently accept a major version change produced by automated tooling without reviewing migration notes and affected APIs.

## Third-party provider requirements

For a business-critical external provider (payments, maps/routing, notifications, identity, media, AI, analytics, storage, search, etc.), document:

1. exact capability used;
2. internal adapter/contract boundary;
3. authentication/secret ownership;
4. data sent/received and privacy implications;
5. quotas/rate limits;
6. pricing and cost driver;
7. timeout/retry/idempotency behavior;
8. degradation/fail-closed behavior;
9. webhook/event authenticity where applicable;
10. monitoring/alert ownership;
11. data export/portability;
12. replacement/exit strategy.

## Paid provider activation

Autonomous development may implement an adapter against documented/test configuration, mocks, fixtures, or a local/staging sandbox where already approved. It may not create a new paid subscription, increase a paid tier, enable production billing, purchase credits, or accept new financial/provider liability.

## AI providers and coding tools

AI usage has two separate surfaces:

### Development AI

Codex/ChatGPT/Claude/Lovable/Replit/Manus or similar tools may assist development, but their outputs are untrusted changes subject to the same repository contracts, review, tests, security, and cost controls. A second tool's agreement is not evidence; repository tests and independent review are evidence.

### Product AI

Any AI inference used by the product requires a bounded server-side contract, abuse/quota controls, cost model, privacy review, content/error handling, auditability appropriate to the feature, and safe behavior when the provider is unavailable.

Do not expose a provider API key in Flutter/web client code.

## Vendor lock-in rule

Lock-in may be accepted deliberately when the operational value exceeds migration cost, but it must be visible. Critical domain logic should not be unnecessarily embedded in provider-specific presentation or webhook code.

## Provider failure rule

Define what the user sees and what state changes occur when the provider:

- times out;
- returns invalid/malformed data;
- rejects authentication;
- rate limits;
- is partially unavailable;
- sends duplicate/out-of-order events;
- changes an object asynchronously after the client has left.

## Autonomous result requirements

If a manifest, lockfile, provider adapter, provider endpoint, or provider configuration contract changes, the result must declare `dependency_change` and/or `provider_change`, explain why, list verification, and state cost/privacy/rollback implications.