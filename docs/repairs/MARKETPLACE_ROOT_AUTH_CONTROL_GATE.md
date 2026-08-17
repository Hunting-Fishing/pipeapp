# Marketplace root auth control gate repair

## Symptom

During Phase 4 Directory browser acceptance, a cold local launch at `127.0.0.1:5050` opened the signed-out Marketplace Home shell instead of the Pipe Buyer sign-in / account-creation screen. The rail still exposed a `Sign in` button, so an anonymous user could enter the marketplace shell before authentication.

An earlier browser attempt also reported `The email or password is incorrect` for the approved carrier fixture. The visual launcher had already proven that exact fixture directly against the Auth emulator before starting Flutter, so routing and fixture health must be diagnosed separately.

## Root cause

The marketplace root route intentionally built `OilGasMarketplaceApp` for `/` regardless of authentication state. `OilGasMarketplaceApp` subscribed to Firebase Auth only to refresh saved listings and account chrome. It never used that auth state to control root access.

The existing `MarketplaceAuthPage` was opened only from explicit `Sign in` buttons in the rail or drawer. That is why a signed-out cold launch showed Home instead of the access screen.

This is separate from the Dispatch auth-reactivity repair. Dispatch already reacts to auth state after it is entered; this repair controls whether the marketplace shell itself can be entered while signed out.

## Permanent repair

`tool/repair_marketplace_root_auth_control.mjs` adds an enforced root access gate to the existing marketplace shell without replacing the established sign-in, signup, verification, or profile onboarding flows.

The gate:

- waits until the initial Firebase Auth state is resolved;
- never renders the Marketplace Home shell while `FirebaseAuth.instance.currentUser` is null;
- automatically pushes the existing `MarketplaceAuthPage` after the first frame;
- prevents duplicate auth routes;
- reopens the auth route if it is dismissed while the user is still signed out;
- preserves the existing route-based auth page so signup can still push the account-security onboarding page and normal sign-in can pop back into the shell;
- automatically restores the gate after sign-out.

A neutral Pipe Buyer access backdrop is shown only while the enforced auth route is being opened. The public Home dashboard is not used as the signed-out control surface.

## Login fixture diagnostic rule

Do not diagnose an `invalid-credential` browser message by reseeding repeatedly or changing passwords first.

Run `tool/verify_formal_carrier_auth_fixture.ps1` while the emulator environment is running. It tests the exact carrier email/password directly against `127.0.0.1:19099` and requires UID `visual-carrier` plus a returned ID token.

Interpretation:

- direct fixture PASS + browser login FAIL: inspect Flutter-to-emulator routing or the actual browser-entered credentials; do not reseed blindly;
- direct fixture FAIL: inspect/reseed the Auth emulator fixture before changing application auth code;
- always use the canonical visual URL `http://127.0.0.1:5050` for acceptance rather than an older `localhost:5050` process.

## Regression protection

`test/marketplace_root_auth_control_contract_test.dart` locks the structural root-control behavior.

`tool/verify_marketplace_root_auth_control.ps1` applies the repair idempotently, formats and strictly analyzes the affected source, runs the root auth contract, and reruns Dispatch auth/navigation regressions.

## Do not repeat

- Do not make the signed-out Marketplace Home page the authentication control surface again.
- Do not replace the established auth/onboarding pages just to enforce root access.
- Do not weaken Dispatch auth reactivity while fixing root access.
- Do not reseed the sandbox repeatedly when the direct Auth-emulator credential probe is already green.
- Do not accept `localhost:5050` and `127.0.0.1:5050` as interchangeable acceptance sessions when an older Flutter process may still be running.
