# Local Auth origin and root routing findings

## Symptom

During Phase 4 Directory browser acceptance, Chrome opened the local Flutter client at `http://localhost:5050`. The carrier test email was present in the sign-in form, but the form reported invalid credentials. Returning from the auth page showed the full marketplace navigation shell while signed out, which looked like an authenticated dashboard rather than a distinct public front page.

## Findings

These are two separate concerns and must not be repaired as one issue.

### Local Auth acceptance origin

The formal local test contract uses `http://127.0.0.1:5050`, while the Flutter launch commands previously supplied only `--web-port=5050`. Chrome could therefore open the development app as `localhost:5050` even though the scripts and Firebase emulator configuration use `127.0.0.1`.

Browser persistence, autofill, and local storage are origin-scoped. Formal acceptance must use one canonical origin so stale browser state from another origin does not become part of an Auth diagnosis.

Permanent repair:

- both `tool/launch_formal_visual_client.ps1` and `tool/launch_formal_flutter_client.ps1` explicitly pass `--web-hostname=127.0.0.1`;
- both launchers print that `localhost:5050` is not the formal acceptance origin;
- `tool/diagnose_formal_local_auth.ps1` proves the exact fixture credentials directly against the Auth emulator before any Flutter Auth source is changed;
- do not reseed or alter Firebase Auth code when the direct credential probe succeeds and only the browser UI fails. Inspect the client connection and browser state next.

### Root routing

The current root GoRouter route `/` directly builds `OilGasMarketplaceApp`. That widget always builds the marketplace adaptive navigation shell; signed-out state changes only the available account controls and signed-out hero content inside the shell.

Therefore the signed-out shell is current source behavior, not an unexplained redirect.

If Pipe Buyer requires a distinct public front page before users enter the application workspace, that must be implemented as an explicit auth-aware root composition. Do not fake this by changing the initial tab or by redirecting all `/` traffic to the sign-in page. The final routing must preserve public browse intent, signed-in workspace entry, sign-out return behavior, and existing deep links.

## Rule going forward

When local Auth or startup behavior looks inconsistent:

1. identify the exact browser origin;
2. prove the fixture directly against the Auth emulator;
3. prove the Flutter launcher uses the intended local emulator defines;
4. only then inspect Auth UI/source behavior;
5. treat public-front-page routing as a separate product routing contract, not as an Auth repair.
