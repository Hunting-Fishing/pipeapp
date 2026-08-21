# Pipe Buyer Windows Revenue Release

Status: active  
Canonical Windows repository: `D:\Game Development\pipeapp`  
Release branch: `fix/dispatch-checkout-hardening`  
Firebase project: `flutter-flow-pipe`

## Purpose

This is the Windows workstation path for validating and deploying the Pipe Buyer Dispatch revenue work without GitHub Actions billing.

The controller is:

`D:\Game Development\pipeapp\scripts\payments\pipebuyer_revenue_windows.ps1`

It wraps the guarded Bash release scripts already stored in the repository and provides Windows-safe handling for the repository path containing a space.

## First-time / each-session setup

Open **PowerShell**.

Allow project scripts for the current PowerShell process only:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

Go to the repository:

```powershell
Set-Location -LiteralPath 'D:\Game Development\pipeapp'
```

Prepare the branch safely:

```powershell
& '.\scripts\payments\pipebuyer_revenue_windows.ps1' -Action Prepare
```

`Prepare`:

- verifies `origin` is exactly `Hunting-Fishing/pipeapp`;
- refuses a dirty working tree unless deliberately overridden;
- fetches `origin`;
- checks out `fix/dispatch-checkout-hardening`;
- uses `git pull --ff-only`; and
- prints the exact local branch/commit/status.

## Safe read-only status

```powershell
& '.\scripts\payments\pipebuyer_revenue_windows.ps1' -Action Status
```

## Revenue validation — run this first

```powershell
& '.\scripts\payments\pipebuyer_revenue_windows.ps1' -Action Validate
```

This performs the current Functions and Flutter validation through `dispatch_revenue_local_release.sh validate`. It does not deploy or enable customer charging.

## Read-only production Stripe probe

```powershell
& '.\scripts\payments\pipebuyer_revenue_windows.ps1' -Action Probe
```

This reads the production Stripe account/prices/webhook/Portal configuration through Firebase-held production credentials. It does not mutate Stripe.

## Controlled Firebase Functions deployment

Only after validation passes:

```powershell
& '.\scripts\payments\pipebuyer_revenue_windows.ps1' `
  -Action Deploy `
  -ConfirmControlledDeploy
```

This deploys the controlled Dispatch/payment Functions. It does **not** enable payment readiness or customer charging.

## Reviewed web + legal deployment

Only after the current Terms and Privacy changes have been reviewed:

```powershell
& '.\scripts\payments\pipebuyer_revenue_windows.ps1' `
  -Action WebLegal `
  -ConfirmWebLegalDeploy
```

The guarded script builds Flutter web, rejects obsolete Dispatch billing language, verifies current recurring pricing language, prints SHA-256 hashes, and deploys Firebase Hosting.

After deployment, independently verify the live `/terms` and `/privacy` pages before publishing their versions/hashes through Pipe Buyer's audited policy commands.

## Create the narrow Stripe Customer Portal configuration

Only after the live Terms and Privacy pages are current and reviewed:

```powershell
& '.\scripts\payments\pipebuyer_revenue_windows.ps1' `
  -Action CreatePortal `
  -ConfirmPortalCreate
```

The configuration permits payment-method updates and cancel-at-period-end while keeping plan switching off. Creating the Stripe configuration does not enable the Portal in Pipe Buyer.

## Synchronize live Stripe webhook events

Only after the new `stripeMarketplaceWebhook` Function has been deployed:

```powershell
& '.\scripts\payments\pipebuyer_revenue_windows.ps1' `
  -Action SyncWebhook `
  -ConfirmWebhookSync
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

## Release order

1. `Prepare`
2. `Validate`
3. Review Terms/Privacy
4. `WebLegal`
5. Verify public policy pages/hashes and publish current policy versions
6. Verify exact-version policy enforcement
7. `Deploy`
8. `Probe`
9. Create/review Portal configuration
10. `SyncWebhook`
11. Controlled Monthly/Yearly/free-promotion/renewal/failure/cancellation acceptance
12. Reconciliation
13. Enable only the approved web Dispatch subscription readiness profile

Do not enable full buyer-to-seller Marketplace Checkout, affiliate cash payouts, or VIP billing as part of this Dispatch revenue release.

## Repair rule

If a command fails, stop on the first real error and record:

- root cause;
- exact repair;
- validation used to prove the repair; and
- commit/PR evidence.

Do not repeatedly change unrelated payment code to chase an infrastructure or workstation error.
