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
  fail "Set PIPEBUYER_DEPLOY_WEB_LEGAL=YES only after reviewing the August 22, 2026 Pipe Buyer policy changes."

if [[ -n "$(git status --porcelain 2>/dev/null || true)" && "${PIPEBUYER_ALLOW_DIRTY_DEPLOY:-}" != "YES" ]]; then
  fail "Refusing hosting deployment from a dirty working tree."
fi

echo "== Validate Flutter web source =="
flutter pub get
flutter analyze
flutter test

echo "== Build Pipe Buyer web =="
flutter build web --release

POLICY_FILES=(
  "build/web/terms.html"
  "build/web/privacy.html"
  "build/web/prohibited-items.html"
  "build/web/mapping-location.html"
  "build/web/communications.html"
)
for file in "${POLICY_FILES[@]}"; do
  [[ -f "$file" ]] || fail "$file is missing. Flutter did not include the reviewed policy document."
done

node <<'NODE'
const fs = require('node:fs');
const crypto = require('node:crypto');

const files = {
  terms: 'build/web/terms.html',
  privacy: 'build/web/privacy.html',
  prohibited: 'build/web/prohibited-items.html',
  mapping: 'build/web/mapping-location.html',
  communications: 'build/web/communications.html',
};
const contents = Object.fromEntries(
  Object.entries(files).map(([key, file]) => [key, fs.readFileSync(file, 'utf8')]),
);

const requiredTerms = [
  'CA$25 per month',
  'CA$300 per year',
  'renews automatically',
  'end of the current paid billing period',
  'Stripe',
];
for (const text of requiredTerms) {
  if (!contents.terms.includes(text)) {
    throw new Error(`Built Terms are missing required billing language: ${text}`);
  }
}
for (const obsolete of ['$10 per dispatched job', 'No fee is currently charged', '$25 per year']) {
  if (contents.terms.includes(obsolete)) {
    throw new Error(`Built Terms still contain obsolete pilot language: ${obsolete}`);
  }
}
if (!contents.privacy.includes('Stripe') ||
    !contents.privacy.includes('Payment and subscription records')) {
  throw new Error('Built Privacy Policy does not contain the reviewed Stripe/payment disclosure.');
}

const requiredMarkers = {
  prohibited: [
    'Prohibited Items Policy for Pipe Buyer',
    'Illegal, Stolen, Counterfeit, or Fraudulent Property',
    'Dispatch Restrictions',
  ],
  mapping: [
    'Mapping and Location Policy for Pipe Buyer',
    'Maps are planning tools, not legal routing instructions.',
    'Carrier and Driver Responsibilities',
  ],
  communications: [
    'Communications Policy for Pipe Buyer',
    'Fraud, Impersonation, and Phishing',
    'Automated Safety Signals and Human Review',
  ],
};
for (const [policy, markers] of Object.entries(requiredMarkers)) {
  for (const marker of markers) {
    if (!contents[policy].includes(marker)) {
      throw new Error(`Built ${policy} policy is missing required marker: ${marker}`);
    }
  }
}

console.log('== Policy SHA-256 hashes ==');
for (const file of Object.values(files)) {
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
  --message "Pipe Buyer reviewed policy/web release $(git rev-parse --short HEAD)" \
  --non-interactive

echo "Hosting deployed without GitHub Actions."
echo "Next: independently fetch /terms, /privacy, /prohibited-items, /mapping-location, and /communications and verify their SHA-256 hashes before policy publication."
