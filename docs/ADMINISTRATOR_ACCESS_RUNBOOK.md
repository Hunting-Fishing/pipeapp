# Administrator access runbook

Administrator access is controlled by Firebase Authentication custom claims.
An email address, a public profile field, or a Firestore user document never
grants administrator authority.

## Required controls

- Enable Firebase Authentication with Identity Platform before using MFA.
- The administrator must have a verified email and at least one supported
  multi-factor method enrolled.
- Use a supported administrator client. Firebase Authentication MFA is not
  supported by the Flutter Windows plugin, so the application fails closed for
  Windows administrator sessions.
- Keep normal users and administrators as separate operational accounts.
- Run role changes from a secured operator workstation with Application Default
  Credentials. Never ship service account credentials in the application.

The role uses two custom claims together: `admin: true` and
`role: administrator`. Those claims are not enough by themselves. Firestore
Rules, Storage Rules, Cloud Functions, and the Flutter administrator entry
points also require Firebase's reserved `firebase.sign_in_second_factor` token
claim. That reserved claim proves the current session completed MFA and avoids
trusting a stale enrollment flag.

## Review a change without writing

From `firebase/functions`:

```powershell
$env:GOOGLE_CLOUD_PROJECT = '<staging-project-id>'
node scripts/set_administrator_role.js --project '<staging-project-id>' --email '<administrator-email>' --grant
```

The command is a dry run unless `--apply` is supplied. It resolves the account,
shows the UID, confirms email ownership and MFA enrollment, and prints the
claims that would result.

## Apply in staging

Repeat the command with the exact UID displayed by the dry run:

```powershell
node scripts/set_administrator_role.js --project '<staging-project-id>' --uid '<uid>' --grant --apply --confirm-uid '<uid>'
```

Revocation uses `--revoke` with the same confirmation. The script preserves
unrelated claims, writes an administrator role record and audit event, and
revokes existing refresh tokens so stale sessions cannot retain privileges.

## Production safeguard

Production additionally requires the exact project acknowledgement:

```powershell
node scripts/set_administrator_role.js --project 'flutter-flow-pipe' --uid '<uid>' --grant --apply --confirm-uid '<uid>' --confirm-production-project 'flutter-flow-pipe'
```

Do not run this production command until staging acceptance, recovery access,
and a second reviewed administrator are ready.

## Firebase references

- [Control access with custom claims](https://firebase.google.com/docs/auth/admin/custom-claims)
- [Flutter multi-factor authentication](https://firebase.google.com/docs/auth/flutter/multi-factor)
- [Decoded ID token reserved second-factor claim](https://firebase.google.com/docs/reference/admin/node/firebase-admin.auth.decodedidtoken)
