#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${FIREBASE_PROJECT_ID:-flutter-flow-pipe}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

fail() { echo "ERROR: $*" >&2; exit 1; }
command -v flutter >/dev/null 2>&1 || fail "Flutter is required."
command -v firebase >/dev/null 2>&1 || fail "Firebase CLI is required."
command -v node >/dev/null 2>&1 || fail "Node is required."

[[ "${PIPEBUYER_DEPLOY_WEB_LEGAL:-}" == "YES" ]] || \
  fail "Set PIPEBUYER_DEPLOY_WEB_LEGAL=YES only after reviewing the August 22, 2026 Terms and Privacy changes."

if [[ -n "$(git status --porcelain 2>/dev/null || true)" && "${PIPEBUYER_ALLOW_DIRTY_DEPLOY:-}" != "YES" ]]; then
  fail "Refusing hosting deployment from a dirty working tree."
fi

echo "== Validate Flutter web source =="
flutter pub get
flutter analyze
flutter test

echo "== Build Pipe Buyer web =="
flutter build web --release

[[ -f build/web/terms.html ]] || fail "build/web/terms.html is missing. Flutter did not include the reviewed Terms document."
[[ -f build/web/privacy.html ]] || fail "build/web/privacy.html is missing. Flutter did not include the reviewed Privacy document."

node <<'NODE'
const fs = require('node:fs');
const crypto = require('node:crypto');
const terms = fs.readFileSync('build/web/terms.html', 'utf8');
const privacy = fs.readFileSync('build/web/privacy.html', 'utf8');

const requiredTerms = [
  'CA$25 per month',
  'CA$300 per year',
  'renews automatically',
  'end of the current paid billing period',
  'Stripe',
];
for (const text of requiredTerms) {
  if (!terms.includes(text)) throw new Error(`Built Terms are missing required billing language: ${text}`);
}
for (const obsolete of ['$10 per dispatched job', 'No fee is currently charged', '$25 per year']) {
  if (terms.includes(obsolete)) throw new Error(`Built Terms still contain obsolete pilot language: ${obsolete}`);
}
if (!privacy.includes('Stripe') || !privacy.includes('Payment and subscription records')) {
  throw new Error('Built Privacy Policy does not contain the reviewed Stripe/payment disclosure.');
}

for (const file of ['build/web/terms.html', 'build/web/privacy.html']) {
  const data = fs.readFileSync(file);
  const hash = crypto.createHash('sha256').update(data).digest('hex');
  console.log(`${file} SHA-256 ${hash}`);
}
NODE

echo "== Deploy reviewed web build to Firebase Hosting =="
firebase deploy \
  --project "$PROJECT_ID" \
  --config firebase.json \
  --only hosting \
  --message "Pipe Buyer Dispatch billing legal/web release $(git rev-parse --short HEAD)" \
  --non-interactive

echo "Hosting deployed without GitHub Actions."
echo "Next: independently fetch https://www.pipebuyer.com/terms and /privacy and verify their SHA-256 hashes before publishPolicyDocument."
