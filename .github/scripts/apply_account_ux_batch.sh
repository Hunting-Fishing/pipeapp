#!/usr/bin/env bash
set -euo pipefail

patch_file=".github/batch/account_ux/account_ux_batch.patch"
workflow_file=".github/workflows/apply_account_ux_batch.yml"
script_file=".github/scripts/apply_account_ux_batch.sh"

if [[ ! -f "$patch_file" ]]; then
  echo "Batch patch is missing: $patch_file" >&2
  exit 1
fi

git apply --check "$patch_file"
git apply "$patch_file"
git diff --check

git rm "$patch_file" "$workflow_file" "$script_file"

git add \
  lib/marketplace/open_address_autocomplete.dart \
  lib/marketplace/marketplace_profile_community.dart \
  lib/marketplace/marketplace_profile_page.dart \
  lib/marketplace/marketplace_account_hub.dart \
  lib/marketplace/marketplace_admin_dashboard.dart

if git diff --cached --quiet; then
  echo "No account UX batch changes were produced." >&2
  exit 1
fi

git config user.name "366 Industries"
git config user.email "103216816+Hunting-Fishing@users.noreply.github.com"
git commit -m "Complete account community notification and admin UX batch"
git push origin HEAD
