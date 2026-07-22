# Production diagnostics runbook

Date: July 22, 2026

## Scope and collection boundary

Pipe Buyer uses one centralized Flutter error boundary. Every diagnostic has
the build environment, release SHA, subsystem, operation, UTC timestamp,
severity, error type, and a non-user correlation identifier. Common email,
phone, and URL values are redacted before the safe error message is recorded.

Firebase Crashlytics is the native reporter for Android, iOS, and macOS.
Collection is disabled in the native application manifests and is enabled at
runtime only when all of these conditions are true:

- `PIPE_ENV` is exactly `staging` or `production`;
- `PIPE_REMOTE_DIAGNOSTICS_ENABLED=true` was compiled into the build;
- the platform is Android, iOS, or macOS; and
- the correct Firebase application initialized successfully.

Local, development, test, CI, web, Windows, and Linux builds remain
console-only. Web reporting requires a separately reviewed provider and is not
represented as operational by this implementation.

## Release procedure

1. Verify the exact release SHA through `tool/verify.ps1` and the GitHub
   `Quality` workflow.
2. Build the staging native artifact with
   `PIPE_REMOTE_DIAGNOSTICS_ENABLED=true` and the complete staging Firebase
   configuration.
3. Install the artifact on a staging Android or Apple device.
4. Generate one controlled, non-sensitive test exception from a test-only
   build entry point. Never expose a crash button in a customer build.
5. Confirm the event appears under the staging Firebase project with the
   expected `environment`, `release_sha`, `subsystem`, `operation`, and
   `correlation_id` keys.
6. Record the Firebase issue link, device/OS, release SHA, tester, and UTC time
   in the launch evidence.
7. Repeat on one Android and one Apple device before enabling production
   collection.

## Triage and escalation

- Fatal startup, authentication, data-loss, transaction, offer, auction,
  Dispatch, moderation, or permission-boundary errors are launch blockers.
- The on-call owner must acknowledge a new fatal production issue, connect it
  to the deployed SHA, and decide whether to disable the affected feature or
  roll back.
- User-facing support must use the correlation identifier. Support must not
  request passwords, authentication codes, private documents, or raw Firebase
  errors.
- Disable the affected feature flag first when a safe server control exists.
  For a broad diagnostics fault, rebuild with
  `PIPE_REMOTE_DIAGNOSTICS_ENABLED=false`; native manifest defaults prevent
  collection before runtime opt-in.

## Ownership still required before Gate 1 closes

The production alert recipient, backup recipient, business-hours coverage,
after-hours coverage, severity response targets, and incident channel must be
approved outside source control. Do not place personal phone numbers or
private escalation addresses in this repository. Crashlytics must also receive
and display the controlled staging events before this integration is counted
as operational evidence.
