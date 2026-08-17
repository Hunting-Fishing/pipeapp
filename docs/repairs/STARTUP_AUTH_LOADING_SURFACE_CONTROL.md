# Startup + auth loading surface control

## Symptom

A local run on `design/formal-beautification-foundation` showed multiple startup surfaces in sequence and then opened the signed-out Marketplace Home shell instead of controlling entry through the existing Pipe Buyer sign-in / signup page.

The visible sequence was:

1. a large Pipe Buyer logo-only Flutter/router surface;
2. a separate HTML Pipe Buyer loading surface;
3. signed-out Marketplace Home with a `Sign in` button.

## What actually happened

This was not two Git branches running at the same time.

The local checkout was on the correct branch name, but its local `HEAD` was behind the remote branch while the working tree also contained many uncommitted changes. The remote branch already contained the recorded marketplace-root auth-control repair and its verifier, but the older local checkout did not yet contain those repair files.

The legacy `pipebuyer-premium-ui` branch remains a base/legacy branch and must not be switched to for current formal acceptance.

## Canonical control

Repository:

`D:\Game Development\pipeapp`

Active development branch:

`design/formal-beautification-foundation`

Formal local URL:

`http://127.0.0.1:5050`

Firebase emulator ports:

- Auth: `19099`
- Firestore: `18080`
- Functions: `15001`
- Storage: `19199`

## Permanent repair strategy

Two existing concerns are kept separate and then verified together.

### 1. Marketplace root auth control

Reuse the already-recorded repair:

- `tool/repair_marketplace_root_auth_control.mjs`
- `tool/verify_marketplace_root_auth_control.ps1`
- `test/marketplace_root_auth_control_contract_test.dart`

This preserves the established sign-in, signup, verification, and account-security onboarding flow while blocking the signed-out Marketplace Home shell.

### 2. One visible startup surface

`tool/repair_startup_service_route.mjs` removes the duplicate router logo loading surface and keeps the web bootstrap as the one visible branded startup surface.

The startup surface uses:

- the large Pipe Buyer logo;
- one progress route;
- a service truck that advances with startup progress;
- a pumpjack at the destination;
- a short first-frame hold so the initial Firebase Auth event and enforced auth route can settle underneath before the loader disappears.

The truck/pumpjack motion honors reduced-motion browser preferences.

## Verification

Run:

`tool/verify_startup_auth_loading_surface.ps1`

The verifier first runs the previously recorded marketplace root-auth verification, then applies the startup surface repair, runs strict analysis, and executes both startup contracts.

## Do not repeat

- Do not switch to `pipebuyer-premium-ui` to make the current emulator run.
- Do not run the legacy sandbox launcher directly for formal acceptance.
- Do not treat the signed-out Marketplace Home shell as an authentication surface.
- Do not add another branded Flutter loading logo behind the web startup surface.
- Do not erase or broadly restore the working tree to fix startup/auth regressions.
- Do not reseed Firebase repeatedly when the problem is routing or startup presentation.
- Do not merge or pull the entire remote branch over a heavily modified local working tree without first reconciling the local work.
