# Pipe Buyer Release Governance

Status: mandatory release contract

## Principle

Autonomous engineering may prepare a releasable commit. It may not decide that production should change. Release is a separate, human-controlled process tied to an exact reviewed SHA.

## Release stages

1. **Development** — local/emulator-first implementation and tests.
2. **Verified branch** — autonomous guard, independent review, and full repository verification pass.
3. **Pull request** — human review plus required GitHub checks.
4. **Staging** — exact reviewed SHA deployed through the controlled environment-specific workflow.
5. **Staging acceptance** — representative journeys, provider/environment checks, migration canaries, visual/device acceptance as applicable.
6. **Production approval** — explicit human decision after all applicable legal, tax, billing, provider, security, data, and operational gates are satisfied.
7. **Production deployment** — exact accepted SHA through controlled workflow.
8. **Post-release verification** — smoke/health/reconciliation checks and retained evidence.

No stage is skipped because the previous stage was green.

## Exact-SHA rule

Do not deploy a working tree, an unreviewed branch tip, or 'latest main'. The deployed artifact must identify the exact accepted commit and environment.

Release manifests and deployment evidence should include hashes/identifiers needed to prove what was deployed.

## Staging rule

Staging must use isolated provider/data/environment configuration and must never silently fall back to production. Production is not used as the first environment to test:

- migrations/backfills;
- provider integration;
- webhook configuration;
- App Check/security settings;
- routing/maps;
- payments;
- notifications;
- environment-specific build values.

## Rollback readiness

Before a high-risk production change, identify:

- previous accepted release SHA/artifact;
- current Hosting/release identifier where applicable;
- Function/rules/index configuration to restore;
- feature flag/kill switch if available;
- data migration restore/reversal procedure;
- provider-state recovery/reconciliation steps;
- post-rollback smoke tests.

If data/provider effects are not safely reversible, deployment approval requires stronger canary/backup/restore evidence.

## Feature activation versus deployment

Deployment and feature activation are separate when a safe server-side flag/configuration allows it. Shipping dormant code does not authorize enabling a paid, regulated, financial, high-cost, or provider-dependent feature.

## Database/data release rule

Schema-compatible code should generally deploy before irreversible cleanup. Backfills/migrations follow `docs/DATA_CHANGE_POLICY.md`. A source rollback cannot be treated as a data rollback.

## Payment release rule

Payment-related release requires the applicable items in `docs/PAYMENTS_EXECUTION_TRACKER.md`. Do not activate money movement based solely on unit tests or a green build.

## Security release rule

Security-sensitive changes require explicit negative-path testing and staging evidence where environment behavior matters. Do not temporarily weaken App Check, Rules, MFA, authorization, signature verification, or secret handling to facilitate a deployment.

## Emergency fixes

Emergency work still requires an isolated branch/commit, focused regression test, and review appropriate to urgency. Do not patch production consoles/files manually when the repository workflow can produce a controlled fix.

## Evidence retention

For material releases, retain as applicable:

- reviewed SHA/PR;
- verification results;
- release manifest;
- staging acceptance evidence;
- migration/backfill report;
- provider acceptance/reconciliation evidence;
- deployment workflow/run identifier;
- rollback identifiers;
- incident/correlation reference if release responds to an incident.

## Existing detailed Firebase procedure

`docs/FIREBASE_ENVIRONMENTS_AND_DEPLOYMENT.md` remains the detailed Firebase environment/deployment/rollback procedure. This document supplies the cross-project release principles the autonomous builder must understand.