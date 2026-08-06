# Approved administrator provisioning

Admin UI visibility must come from Firebase custom claims plus second-factor evidence. Do not add email allowlists to Flutter code.

Approved accounts requested for provisioning:

- `jordilwbailey@gmail.com`
- `goldcity4u@icloud.com`

Run from `firebase/functions` with production operator credentials.

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

The script writes `administrator_roles/{uid}`, appends an audit record, sets the custom claims, and revokes existing refresh tokens. Each administrator must sign in again using MFA before the Admin Portal tab appears.
