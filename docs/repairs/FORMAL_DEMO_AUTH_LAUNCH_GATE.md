# Formal demo Auth launch gate

## Symptom

`tool/launch_formal_flutter_client.ps1` could successfully open the Pipe Buyer web client while the published local demo accounts could not sign in.

The launcher previously proved only that emulator ports were listening. A listening Auth emulator does not prove that deterministic accounts exist, that their passwords are current, or that the real `signInWithPassword` endpoint accepts them.

The legacy sandbox script already contained direct Auth REST probes for several demo accounts, but that protection was not shared by the formal fast client launcher.

## Root cause

Formal launch readiness was split across scripts:

- `reseed_formal_test_data.ps1` verified account existence through the Admin SDK;
- `launch_formal_flutter_client.ps1` verified ports;
- direct email/password authentication was not a mandatory launch gate.

As a result, restarting or partially refreshing emulator state could leave the browser launchable while demo credentials were unusable.

## Permanent control

The formal branch now uses these controls:

- `firebase/functions/scripts/verify_formal_demo_auth_passwords.mjs` — signs in VIP Buyer, Standard Buyer, Seller, and Carrier through the actual local Auth REST endpoint and verifies the expected UID plus ID token;
- `firebase/functions/scripts/ensure_formal_demo_auth.js` — Auth-only deterministic repair for the four published accounts; it does not modify Firestore;
- `tool/verify_formal_demo_auth.ps1` — branch/port-locked wrapper for the direct password verifier;
- `tool/ensure_formal_acceptance_ready.ps1` — verifies the complete deterministic fixture set before launch, performs one controlled repair only when required, and re-verifies before returning success;
- `tool/reseed_formal_test_data.ps1` — now requires direct password verification after seeding;
- `tool/launch_formal_flutter_client.ps1` — now refuses to open Flutter until the readiness gate passes.

## Repair policy

The readiness gate does not blindly reseed on every launch.

1. If deterministic fixtures and passwords are healthy, it makes no data changes.
2. If Firestore fixtures are healthy but passwords fail, it repairs Auth accounts only and re-proves all four logins.
3. If the fixture set is missing or stale, it performs one deterministic full reseed, which includes direct password verification.
4. If that one repair attempt fails, it stops before Flutter opens.

## Published local credentials

All four formal local accounts use:

```text
Password: PipeBuyerDemo!2026
```

Accounts:

```text
buyer.visual@pipebuyer.test
standard.visual@pipebuyer.test
seller.visual@pipebuyer.test
carrier.visual@pipebuyer.test
```

These controls are hard-locked to the local emulator and formal development branch. They must never target production Auth.

## Do not repeat

Do not diagnose demo login failure by repeatedly typing passwords in the Flutter screen or repeatedly reseeding without evidence.

Run the direct gate first:

```powershell
.\tool\verify_formal_demo_auth.ps1
```

For the normal fast-launch path, use:

```powershell
.\tool\launch_formal_flutter_client.ps1
```

The launcher now performs the readiness decision automatically before Chrome opens.
