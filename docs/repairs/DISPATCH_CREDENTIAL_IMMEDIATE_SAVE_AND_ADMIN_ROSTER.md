# Dispatch credential immediate-save + administrator roster control

## Symptoms

1. A carrier edited **General liability insurance**, pressed **Save metadata**, left Credentials & insurance, and the values were gone when the page was reopened.
2. The credential intelligence build was not discoverable enough; users did not know where **Analytics & alerts** lived.
3. The generic Admin Portal user-role menu included an `Administrator` profile-field option even though real administrator authorization correctly uses Firebase custom claims plus MFA.
4. The platform needs an initial two-account administrator roster, with only the primary administrator permitted to add or remove administrators.

## Root causes

### Credential persistence

The metadata dialog returned an updated `DispatchCredentialRecord` and only called `_replaceRecord(updated)`. That changed Flutter in-memory state but did **not** write Firestore. Persistence happened only if the user later found and pressed the separate **Save all credential metadata** button. The dialog therefore used the word "Save" for an action that was not durable.

### Analytics discoverability

The intelligence design used an app-bar tab. When an older credential source was still materialized, the tab did not exist at all; even in the intelligence source, the Records page had no obvious in-content route to the analytics screen.

### Administrator role management

The generic user directory edited `users/{uid}.role`, but `administrator_authorization.js` intentionally ignores that client/profile field and requires trusted custom claims plus second-factor evidence. The UI therefore exposed a misleading action that could never correctly provision administrator authority.

## Permanent repair

- `tool/apply_dispatch_credential_acceptance_v2.ps1` first materializes the complete credential-intelligence foundation, then makes dialog Save durable by writing the private business record before the action completes.
- Failed credential writes roll the local record back instead of leaving the UI looking saved.
- The Records page includes a visible **Analytics & alerts** card/button in addition to the app-bar tab.
- `test/marketplace_dispatch_credential_persistence_discoverability_test.dart` protects the immediate-save and discoverability contracts.
- `firebase/functions/administrator_role_commands.js` provides protected administrator roster list/grant/revoke callables.
- The trusted server requires normal administrator claims, current MFA evidence, verified email, and the primary manager account before any roster mutation.
- New administrator targets must have verified email and enrolled MFA; successful changes revoke refresh tokens and append an audit record.
- The generic Admin Portal user-role menu no longer offers a fake `Administrator` profile-field action.
- `lib/marketplace/marketplace_admin_role_manager.dart` is the dedicated roster UI.
- `tool/run_dispatch_phase3_acceptance_repair.ps1` is the single-entry bounded repair/gate for this acceptance slice.

## Initial administrator policy

Initial approved accounts:

- `jordilwbailey@gmail.com` — administrator + sole in-app roster manager.
- `goldcity4u@icloud.com` — administrator only.

Email alone never grants authority. Both accounts still require server-provisioned administrator custom claims and MFA.
