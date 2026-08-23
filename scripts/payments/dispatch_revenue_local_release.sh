#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-validate}"
PROJECT_ID="${FIREBASE_PROJECT_ID:-flutter-flow-pipe}"
EXPECTED_STRIPE_ACCOUNT="${EXPECTED_STRIPE_ACCOUNT:-acct_1U2QmKDkO07WMXyR}"
WEBHOOK_URL="${STRIPE_WEBHOOK_URL:-https://us-central1-flutter-flow-pipe.cloudfunctions.net/stripeMarketplaceWebhook}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' is not installed."
}

require_repo() {
  [[ -f firebase.json ]] || fail "Run this script from the Pipe Buyer repository."
  [[ -f firebase/functions/package.json ]] || fail "Firebase Functions package is missing."
}

validate_branch_state() {
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  echo "Repository branch: ${branch:-unknown}"
  if [[ -n "$(git status --porcelain 2>/dev/null || true)" ]]; then
    echo "WARNING: working tree has uncommitted changes."
    if [[ "$MODE" != "validate" && "${PIPEBUYER_ALLOW_DIRTY_DEPLOY:-}" != "YES" ]]; then
      fail "Refusing deployment from a dirty tree. Commit changes or set PIPEBUYER_ALLOW_DIRTY_DEPLOY=YES deliberately."
    fi
  fi
}

validate_functions() {
  echo "== Functions validation =="
  npm ci --prefix firebase/functions
  npm audit --omit=dev --audit-level=high --prefix firebase/functions
  npm run lint --prefix firebase/functions
  npm run check --prefix firebase/functions
}

validate_flutter() {
  if [[ "${PIPEBUYER_SKIP_FLUTTER:-}" == "YES" ]]; then
    echo "Flutter validation explicitly skipped by PIPEBUYER_SKIP_FLUTTER=YES."
    return
  fi
  require_cmd flutter
  echo "== Flutter validation =="
  flutter pub get
  flutter analyze
  flutter test
}

print_policy_hashes() {
  echo "== Policy publication hashes =="
  node <<'NODE'
const fs = require('node:fs');
const crypto = require('node:crypto');
for (const file of ['web/terms.html', 'web/privacy.html']) {
  const data = fs.readFileSync(file);
  const hash = crypto.createHash('sha256').update(data).digest('hex');
  console.log(`${file}: ${hash}`);
}
NODE
  echo "Publish the reviewed Terms and Privacy versions through publishPolicyDocument before live billing activation."
}

verify_firebase_login() {
  require_cmd firebase
  echo "== Firebase project access =="
  firebase projects:list --json >/tmp/pipebuyer-firebase-projects.json
  node - "$PROJECT_ID" <<'NODE'
const fs = require('node:fs');
const projectId = process.argv[2];
const payload = JSON.parse(fs.readFileSync('/tmp/pipebuyer-firebase-projects.json', 'utf8'));
const projects = Array.isArray(payload.result) ? payload.result : [];
if (!projects.some((p) => p.projectId === projectId || p.id === projectId)) {
  throw new Error(`Firebase CLI session cannot access ${projectId}. Run firebase login with the correct account.`);
}
console.log(`Firebase CLI access confirmed for ${projectId}.`);
NODE
  rm -f /tmp/pipebuyer-firebase-projects.json
}

deploy_dispatch_functions() {
  [[ "${PIPEBUYER_CONTROLLED_DEPLOY:-}" == "YES" ]] || \
    fail "Deployment requires PIPEBUYER_CONTROLLED_DEPLOY=YES. This deploys code only; it does not enable charging."

  verify_firebase_login
  echo "== Controlled Dispatch revenue code deployment =="
  local targets=(
    publishPolicyDocument
    acceptRequiredPolicies
    setPolicyEnforcement
    getPaymentProviderReadiness
    setPaymentProviderReadiness
    getDispatchSubscriptionCatalog
    getDispatchSubscriptionStatus
    createDispatchSubscriptionCheckout
    createDispatchSubscriptionPortalSession
    submitDispatchQuote
    stripeMarketplaceWebhook
  )
  local only=""
  local name
  for name in "${targets[@]}"; do
    only="${only:+$only,}functions:marketplace:$name"
  done

  firebase deploy \
    --project "$PROJECT_ID" \
    --config firebase.json \
    --only "$only" \
    --message "Pipe Buyer controlled Dispatch revenue deployment $(git rev-parse --short HEAD)" \
    --force \
    --non-interactive

  echo "Code deployment complete. Payment readiness flags were NOT changed."
}

verify_live_stripe_read_only() {
  verify_firebase_login
  umask 077
  local key_file
  key_file="$(mktemp)"
  trap 'rm -f "$key_file"' RETURN

  firebase functions:secrets:access STRIPE_SECRET_PRODUCTION \
    --project "$PROJECT_ID" | tail -n 1 > "$key_file"
  [[ -s "$key_file" ]] || fail "STRIPE_SECRET_PRODUCTION could not be read."

  STRIPE_KEY_FILE="$key_file" \
  EXPECTED_STRIPE_ACCOUNT="$EXPECTED_STRIPE_ACCOUNT" \
  STRIPE_WEBHOOK_URL="$WEBHOOK_URL" \
  node <<'NODE'
const fs = require('node:fs');
const key = fs.readFileSync(process.env.STRIPE_KEY_FILE, 'utf8').trim();
const expectedAccount = process.env.EXPECTED_STRIPE_ACCOUNT;
const webhookUrl = process.env.STRIPE_WEBHOOK_URL;
const config = require('./firebase/functions/stripe_marketplace_config');
const {STRIPE_WEBHOOK_EVENTS} = require('./firebase/functions/stripe_webhook_event_catalog');

async function stripe(path) {
  const response = await fetch(`https://api.stripe.com${path}`, {
    headers: {
      Authorization: `Bearer ${key}`,
      'Stripe-Version': config.stripeMarketplaceConfig.apiVersion,
    },
  });
  const payload = await response.json();
  if (!response.ok) throw new Error(`Stripe read failed ${response.status}: ${path}`);
  return payload;
}

function priceChecks() {
  return [
    ['monthly', config.stripeMarketplaceConfig.products.dispatchMonthlyCad.priceId, 2500, 'month'],
    ['yearly', config.stripeMarketplaceConfig.products.dispatchYearlyCad.priceId, 30000, 'year'],
  ];
}

(async () => {
  const account = await stripe('/v1/account');
  if (account.id !== expectedAccount) throw new Error('Stripe account does not match Pipe Buyer production account.');

  for (const [label, priceId, expectedUnitAmount, expectedInterval] of priceChecks()) {
    const price = await stripe(`/v1/prices/${encodeURIComponent(priceId)}`);
    if (price.active !== true || price.currency !== 'cad' ||
        Number(price.unit_amount) !== expectedUnitAmount ||
        !price.recurring || price.recurring.interval !== expectedInterval) {
      throw new Error(`Stripe ${label} price does not match the approved Dispatch catalog.`);
    }
    console.log(`Stripe ${label} price verified: ${priceId}`);
  }

  const endpoints = await stripe('/v1/webhook_endpoints?limit=100');
  const matches = (endpoints.data || []).filter((item) => item.url === webhookUrl);
  if (matches.length !== 1) throw new Error(`Expected exactly one Pipe Buyer webhook endpoint; found ${matches.length}.`);
  const endpoint = matches[0];
  if (endpoint.livemode !== true || endpoint.status !== 'enabled') {
    throw new Error('Pipe Buyer production webhook is not enabled in live mode.');
  }
  const current = new Set(endpoint.enabled_events || []);
  const missing = STRIPE_WEBHOOK_EVENTS.filter((event) => !current.has(event));
  console.log(`Live webhook: ${endpoint.id}`);
  if (missing.length) {
    console.log(`Webhook catalog still needs post-deploy synchronization: ${missing.join(', ')}`);
  } else {
    console.log('Live webhook already matches the current repository event catalog.');
  }

  const portals = await stripe('/v1/billing_portal/configurations?active=true&limit=100');
  const safePortals = (portals.data || []).filter((portal) => {
    const f = portal.features || {};
    return portal.active === true &&
      f.payment_method_update && f.payment_method_update.enabled === true &&
      f.subscription_cancel && f.subscription_cancel.enabled === true &&
      f.subscription_cancel.mode === 'at_period_end' &&
      (!f.subscription_update || f.subscription_update.enabled !== true);
  });
  if (safePortals.length === 0) {
    console.log('No approved narrow Dispatch Customer Portal configuration exists yet. Portal readiness must remain OFF.');
  } else {
    console.log(`Candidate safe Portal configuration(s): ${safePortals.map((p) => p.id).join(', ')}`);
  }
})().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
NODE

  rm -f "$key_file"
  trap - RETURN
}

require_repo
require_cmd git
require_cmd node
require_cmd npm
validate_branch_state

case "$MODE" in
  validate)
    validate_functions
    validate_flutter
    print_policy_hashes
    ;;
  deploy)
    validate_functions
    validate_flutter
    print_policy_hashes
    deploy_dispatch_functions
    ;;
  probe)
    print_policy_hashes
    verify_live_stripe_read_only
    ;;
  all)
    validate_functions
    validate_flutter
    print_policy_hashes
    deploy_dispatch_functions
    verify_live_stripe_read_only
    ;;
  *)
    echo "Usage: $0 [validate|deploy|probe|all]" >&2
    exit 2
    ;;
esac

echo "Done. No GitHub Actions billing was used by this script."
