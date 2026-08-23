# Repair record — P2 production Dispatch/Paid Features build gate

Date: 2026-08-23  
Branch: `p2-dispatch-subscription-hardening`

## Root cause

The hardened P2 server correctly requires both runtime Phase 1 feature flags before Dispatch subscription activation and Checkout:

- `dispatch == true`
- `paidFeatures == true`

However, the Flutter compile-time policy still contained:

```dart
bool get paidFeaturesEnabled => !isProduction && paidFeaturesRequested;
```

That made Paid Features impossible in a production client artifact even when the accepted server/payment configuration was correct.

At the same time, the verified Firebase deploy workflow did not pass either:

- `PIPE_ENABLE_DISPATCH`
- `PIPE_ENABLE_PAID_FEATURES`

to `flutter build web`.

`PIPE_ENABLE_DISPATCH` also defaulted to true in the client policy, which meant Dispatch production build approval was implicit while Paid Features was permanently clamped off.

The result was an inconsistent release contract: the server could become financially ready while the exact production Flutter artifact could not expose the paid Dispatch workflow correctly.

## Exact repair

### 1. Production paid features use explicit compile-time approval

`lib/core/config/phase1_feature_policy.dart`

Paid Features now use:

```dart
bool get paidFeaturesEnabled => paidFeaturesRequested;
```

with `PIPE_ENABLE_PAID_FEATURES` defaulting to false.

This does **not** make Paid Features production-default-on. A production artifact must explicitly compile with:

```text
PIPE_ENABLE_PAID_FEATURES=true
```

and the remote runtime feature flag must separately be true.

### 2. Dispatch production build approval now defaults closed

`PIPE_ENABLE_DISPATCH` now defaults to false in `Phase1FeaturePolicy.current`.

Development remains usable because `dispatchEnabledForBuild` permits Dispatch outside production. Production requires an explicit artifact approval.

### 3. Verified Firebase deploy exposes explicit manual approvals

`.github/workflows/deploy.yml`

Added manual workflow inputs, both default false:

- `enable_dispatch`
- `enable_paid_features`

The exact values are exported as:

- `PIPE_ENABLE_DISPATCH`
- `PIPE_ENABLE_PAID_FEATURES`

and passed to Flutter through `--dart-define`.

Selecting these build approvals still does not enable the Firestore runtime flags or `stripeSubscriptionsEnabled`.

### 4. Release manifest records exact client build approvals

`tool/release_manifest.mjs`

Manifest schema was advanced to version 3.

The release record now contains:

```json
{
  "release": {
    "clientFeatureBuildApprovals": {
      "dispatch": true,
      "paidFeatures": true
    }
  }
}
```

for an accepted P2 artifact.

These values sit beside the exact commit SHA and the hashed `build/web` artifact, so the deployed client capability is auditable rather than inferred from workflow memory.

CLI options:

- `--dispatch-build-enabled true|false`
- `--paid-features-build-enabled true|false`

Boolean parsing fails closed on values other than exact true/false semantics.

### 5. Emergency local production deploy follows the same policy

`tool/deploy_production_local.ps1`

Added switches:

```powershell
-EnableDispatch
-EnablePaidFeatures
```

Both are absent/off by default.

The switches are written into the Dart define file and passed to the release manifest, so the emergency local path cannot silently produce a different build policy from GitHub deployment.

For the accepted P2 Dispatch subscription artifact the intended invocation is:

```powershell
.\tool\deploy_production_local.ps1 -EnableDispatch -EnablePaidFeatures
```

### 6. Runtime feature flags remain the immediate kill switch

The compile-time approvals only make the exact artifact capable of exposing the feature.

The server still requires the revision-controlled Firestore flags:

```text
dispatch = true
paidFeatures = true
```

and P2 subscription billing independently requires the eight stored launch prerequisites plus `stripeSubscriptionsEnabled`.

Therefore the safety model is:

**artifact approval AND runtime feature flags AND payment readiness**.

A build approval by itself cannot create a Checkout or entitlement.

### 7. Activation command now rejects feature mismatch

`payment_readiness_admin.js` transactionally reads `platform_configuration/phase1_features` before accepting `stripeSubscriptionsEnabled == true`.

It fails closed unless both Dispatch and Paid Features are enabled, preventing an internally inconsistent payment-readiness record.

### 8. Customer/admin projections use the same server readiness policy

`dispatch_subscription_readiness_policy.js` centralizes the stored Dispatch subscription prerequisites, including the Phase 1 feature flags.

Both customer purchase availability and the MFA-admin readiness snapshot consume this policy, preventing the UI from appearing ready when the server would reject Checkout.

## Verification contracts added/updated

Coverage now includes:

- production Paid Features are off without explicit build approval;
- explicit production paid approval is allowed while regulated listings remain blocked;
- production Dispatch build approval defaults closed;
- deploy workflow exposes both manual inputs with default false;
- deploy workflow passes both values into Flutter;
- release manifest accepts/records exact boolean build approvals;
- emergency local deploy includes both switches/defines/manifest arguments;
- server activation refuses Dispatch subscriptions when `dispatch` or `paidFeatures` is false;
- customer billing availability fails closed when either feature flag is false;
- admin readiness exposes feature availability as an independent prerequisite.

Full Flutter/Functions/emulator execution remains required from the complete repository toolchain before merge/deploy.

## Do not repeat

- Do not hard-disable a server-approved paid feature in production Flutter while simultaneously building launch controls for it.
- Do not rely on `String.fromEnvironment` defaults for a controlled production feature; pass the approval explicitly in the release workflow.
- Do not make Dispatch or Paid Features default ON in the verified production deployment workflow.
- Do not treat a compile-time approval as runtime activation.
- Do not let the runtime feature flags override a stricter artifact; both layers must agree.
- Do not enable `stripeSubscriptionsEnabled` while either runtime `dispatch` or `paidFeatures` is false.
- Do not ship P2 without retaining the release manifest that records both client build approvals and the exact web-artifact hash.
- Do not broaden this P2 build rule into assumptions about unrelated future paid products; their own release policy must be reviewed separately.
