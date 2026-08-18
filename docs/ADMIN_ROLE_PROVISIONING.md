# Approved administrator provisioning

Administrator UI visibility and authorization come from Firebase custom claims plus second-factor evidence. Do not add administrator email allowlists to Flutter authorization code, and do not treat a client-writable user profile field as an administrator grant.

## Initial approved administrator roster

The requested initial administrator accounts are:

- `jordilwbailey@gmail.com` — primary administrator and the only account permitted to add or remove administrators from the in-app roster manager.
- `goldcity4u@icloud.com` — administrator, without administrator-roster management authority.

The primary-manager email restriction is enforced only on the trusted Functions server **after** the normal administrator custom-claim and MFA checks pass. An email address by itself never grants administrator access.

Run initial provisioning from `firebase/functions` with production operator credentials.

## 1. Dry run and resolve each UID

```bash
node scripts/set_administrator_role.js \
  --project flutter-flow-pipe \
  --email jordilwbailey@gmail.com \
  --grant

node scripts/set_administrator_role.js \
  --project flutter-flow-pipe \
  --email goldcity4u@icloud.com \
  --grant
```

The script refuses a grant unless the account is eligible, including verified email and required MFA enrollment.

## 2. Apply after reviewing the dry-run output

Replace each placeholder with the exact UID printed by the dry run.

```bash
ADMIN_CHANGE_ACTOR="approved-production-operator" \
node scripts/set_administrator_role.js \
  --project flutter-flow-pipe \
  --email jordilwbailey@gmail.com \
  --grant \
  --apply \
  --confirm-uid <JORDIL_UID> \
  --confirm-production-project flutter-flow-pipe

ADMIN_CHANGE_ACTOR="approved-production-operator" \
node scripts/set_administrator_role.js \
  --project flutter-flow-pipe \
  --email goldcity4u@icloud.com \
  --grant \
  --apply \
  --confirm-uid <GOLDCITY_UID> \
  --confirm-production-project flutter-flow-pipe
```

The script writes `administrator_roles/{uid}`, appends an audit record, sets the custom claims, and revokes existing refresh tokens. Each administrator must sign in again using MFA before the Admin Portal becomes authorized.

## 3. In-app administrator roster management

After the initial administrator claims are provisioned, the Admin Portal exposes **Administrator access management** under System Config.

The callable command boundary requires all of the following before a roster change is accepted:

1. signed-in Firebase user;
2. `admin == true` custom claim;
3. `role == administrator` custom claim;
4. Firebase second-factor evidence on the current sign-in;
5. verified email;
6. the primary-manager account `jordilwbailey@gmail.com`.

A new administrator target must already exist as a Pipe Buyer Auth user, have verified email, and have at least one enrolled Firebase MFA factor. A successful grant or revocation updates the custom claims, writes the private administrator-role record and audit event, and revokes the target user's refresh tokens so the new authorization state takes effect on a fresh sign-in.

The primary administrator cannot remove its own administrator access through the app. That protects the platform from accidentally removing the last roster manager. Emergency primary-role changes remain an explicit production-operator action.

`goldcity4u@icloud.com` remains a normal administrator and cannot change the administrator roster.
