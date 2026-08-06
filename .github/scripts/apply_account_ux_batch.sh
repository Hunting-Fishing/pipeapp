#!/usr/bin/env bash
set -euo pipefail

chunk_dir=".github/batch/account_ux/transform_chunks"
patch_file=".github/batch/account_ux/account_ux_batch.patch"
workflow_file=".github/workflows/apply_account_ux_batch.yml"
script_file=".github/scripts/apply_account_ux_batch.sh"
transformer="$(mktemp)"

if [[ ! -d "$chunk_dir" ]]; then
  echo "Transformer chunks are missing: $chunk_dir" >&2
  exit 1
fi

cat "$chunk_dir"/*.b64 | base64 --decode > "$transformer"
python3 -m py_compile "$transformer"
if ! python3 "$transformer"; then
  echo "Remaining administrator email references after transformation:" >&2
  grep -n -C 3 "jordilwbailey@gmail.com" \
    lib/marketplace/marketplace_account_hub.dart >&2 || true
  exit 1
fi
git diff --check

git rm -r "$chunk_dir"
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
