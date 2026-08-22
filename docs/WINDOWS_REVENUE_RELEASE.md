# Pipe Buyer Windows Revenue Release

Status: active  
Primary development repository: `D:\Game Development\pipeapp`  
Clean payment release workspace: `D:\Game Development\pipeapp-stripe-release`  
Release branch: `fix/dispatch-checkout-hardening`  
Firebase project: `flutter-flow-pipe`

## Purpose

This is the Windows workstation procedure for validating and deploying the Pipe Buyer Dispatch revenue work without GitHub Actions billing.

The primary development repository may contain active uncommitted Dispatch/Marketplace work. Do not switch or pull the payment release branch over that work. Use the clean payment release workspace for Stripe/Firebase release validation and deployment.

The root launcher in the release workspace is:

`D:\Game Development\pipeapp-stripe-release\pipebuyer.ps1`

The controller underneath it is:

`D:\Game Development\pipeapp-stripe-release\scripts\payments\pipebuyer_revenue_windows.ps1`

It wraps the guarded release scripts already stored in the repository and provides Windows-safe handling for repository paths containing spaces.

## First-time / each-session setup

Open **PowerShell**.

Allow project scripts for the current PowerShell process only:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

Go to the clean release workspace:

```powershell
Set-Location -LiteralPath 'D:\Game Development\pipeapp-stripe-release'
```

Prepare the branch safely:

```powershell
.\pipebuyer.ps1 -Action Prepare
```

`Prepare`:

- verifies `origin` is exactly `Hunting-Fishing/pipeapp`;
- refuses a dirty working tree unless deliberately overridden;
- fetches `origin`;
- checks out `fix/dispatch-checkout-hardening`;
- uses `git pull --ff-only`;
- normalizes payment Bash scripts to LF if an older Windows checkout contains CRLF; and
- prints the exact local branch/commit/status.

## Safe read-only status

```powershell
.\pipebuyer.ps1 -Action Status
```

## Revenue validation — run this first

```powershell
.\pipebuyer.ps1 -Action Validate
```

This performs the current Functions and Flutter validation through `dispatch_revenue_local_release.sh validate`. It does not deploy or enable customer charging.

## Read-only production Stripe probe

```powershell
.\pipebuyer.ps1 -Action Probe
```

This reads the production Stripe account/prices/webhook/Portal configuration through Firebase-held production credentials. It does not mutate Stripe.

## Controlled Firebase Functions deployment

Only after validation passes and the policy/tax gates required for the current stage are satisfied:

```powershell
.\pipebuyer.ps1 -Action Deploy -ConfirmControlledDeploy
```

This deploys the controlled Dispatch/payment Functions. It does **not** enable payment readiness or customer charging.

## Reviewed web + policy deployment

Only after the current five public policy pages have been reviewed:

```powershell
.\pipebuyer.ps1 -Action WebLegal -ConfirmWebLegalDeploy
```

The guarded script builds Flutter web, rejects obsolete Dispatch billing language, verifies current recurring pricing language, requires all five policy pages in the release build, checks policy-specific markers, prints SHA-256 hashes for all five, and deploys Firebase Hosting.

The five public policy routes are:

- `/terms`
- `/privacy`
- `/prohibited-items`
- `/mapping-location`
- `/communications`

## One-command public policy hash verification

After `WebLegal` completes, independently compare every live policy document with the exact local release build:

```powershell
.\pipebuyer.ps1 -Action VerifyPolicies
```

This read-only action downloads all five public policy pages, computes local and live SHA-256 values, and fails closed if even one byte differs. It is safe to run when Flutter has regenerated local platform registrant files because it does not mutate production or require a clean Git tree.

Do not publish policy records if `VerifyPolicies` reports any mismatch.

## Policy publication operator path

The repository already contains `firebase/functions/scripts/policy_ops.js` for guarded policy operations. It:

- computes the policy SHA-256 from the live HTTPS URL itself;
- defaults to dry-run;
- reuses the same publication validator as the callable path;
- records the policy document and immutable publication event;
- rejects missing, email-address, overlong, or obvious placeholder `--actor-uid` values; and
- requires `--confirm-production-project flutter-flow-pipe` before a production write.

Before applying a publication, copy the approving administrator's **actual Firebase Authentication User UID** and use that exact value as `--actor-uid`. Do not use an email address, GitHub username, display name, or placeholder text. Record the version, effective date, summary, and approval note as well. Do not enable policy enforcement until all five policies are published and acceptance/stale-reacceptance behavior has been verified.

## Create the narrow Stripe Customer Portal configuration

Only after the current legal/policy gates are satisfied:

```powershell
.\pipebuyer.ps1 -Action CreatePortal -ConfirmPortalCreate
```

The configuration permits payment-method updates and cancel-at-period-end while keeping plan switching off. Creating the Stripe configuration does not enable the Portal in Pipe Buyer.

## Synchronize live Stripe webhook events

Only after the new `stripeMarketplaceWebhook` Function has been deployed:

```powershell
.\pipebuyer.ps1 -Action SyncWebhook -ConfirmWebhookSync
```

The script first performs a signed round-trip probe against the deployed Firebase webhook. It refuses to expand the Stripe event catalog unless the probe passes and exactly one expected live webhook endpoint is found.

## Required local tools

The Windows controller requires:

- Git for Windows
- Git Bash (`bash.exe`)
- Node.js 22 / npm
- Flutter SDK
- Firebase CLI

The controller finds Git Bash from PATH or common Git-for-Windows installation locations.

For Firebase deployment/probes, authenticate the correct Google/Firebase account using:

```powershell
firebase login
firebase projects:list
```

The expected project is `flutter-flow-pipe`.

The policy operator uses Firebase Admin application-default credentials. If that operator path reports missing application-default credentials, authenticate the approved operator account before retrying. Do not substitute service-account secrets into shell history.

## Release order

1. `Prepare`
2. `Validate`
3. Review all five public policy pages
4. `WebLegal`
5. `VerifyPolicies`
6. Dry-run and publish all five exact policy versions through the guarded operator path
7. Verify policy acceptance, stale-version reacceptance, and exact-version enforcement
8. Read/record production payment-provider readiness and resolve tax authorization evidence
9. `Deploy`
10. `Probe`
11. Create/review Portal configuration
12. `SyncWebhook`
13. Controlled Monthly/Yearly/free-promotion/renewal/failure/cancellation acceptance
14. Reconciliation
15. Enable only the approved web Dispatch subscription readiness profile

Do not enable full buyer-to-seller Marketplace Checkout, affiliate cash payouts, or VIP billing as part of this Dispatch revenue release.

## Recorded repair: Windows Bash CRLF failure — 2026-08-22

**Symptom**

`dispatch_revenue_local_release.sh` failed immediately at line 2 with an error around `set: pipefail` / `invalid option name` when launched from PowerShell through Git Bash.

**Root cause**

The repository `.gitattributes` had explicit line-ending rules for Dart, JavaScript, JSON, Markdown and PowerShell, but no explicit `*.sh` rule. Git for Windows therefore checked the Bash release scripts out with CRLF on a workstation configured to convert text files. Bash parsed the hidden carriage return in `set -euo pipefail` as part of the option name.

**Repair**

- `.gitattributes` now contains `*.sh text eol=lf`.
- `pipebuyer_revenue_windows.ps1` also normalizes any existing CRLF files under `scripts\payments\*.sh` to UTF-8 without BOM + LF before invoking Bash. This covers already-created Windows clones that predate the Git attribute fix.

**Verification**

Pull the repair into the clean release workspace and rerun:

```powershell
git pull --ff-only origin fix/dispatch-checkout-hardening
.\pipebuyer.ps1 -Action Validate
```

The validation must progress beyond Bash line 2 and into the Functions validation stage. Any later failure is a separate real validation failure and must be repaired on its own evidence.

**Repository evidence**

The repair is committed on PR #88 / branch `fix/dispatch-checkout-hardening`.

## Recorded repair: policy publication placeholder actor UID — 2026-08-22

**Symptom**

A publication dry run displayed `Approved by PASTE_FIREBASE_ADMIN_UID_HERE` because the PowerShell variable still held the example placeholder.

**Root cause**

The operator previously required a non-empty `--actor-uid` but did not distinguish a real Firebase Authentication User UID from obvious placeholder text.

**Repair**

`policy_ops.js` now rejects missing, email-address, overlong, and obvious placeholder actor UID values before both publication and enforcement operations. The operator must use the real Firebase Authentication User UID of the approving administrator.

**Verification**

A retry with the placeholder must fail before fetching or writing a policy document. A dry run with the real UID must show that UID in `Approved by` and still end with `DRY RUN — nothing was written.`

## Repair rule

If a command fails, stop on the first real error and record:

- root cause;
- exact repair;
- validation used to prove the repair; and
- commit/PR evidence.

Do not repeatedly change unrelated payment code to chase an infrastructure or workstation error.
