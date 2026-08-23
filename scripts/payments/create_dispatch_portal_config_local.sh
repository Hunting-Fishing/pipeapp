#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${FIREBASE_PROJECT_ID:-flutter-flow-pipe}"
EXPECTED_STRIPE_ACCOUNT="${EXPECTED_STRIPE_ACCOUNT:-acct_1U2QmKDkO07WMXyR}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

fail() { echo "ERROR: $*" >&2; exit 1; }
command -v firebase >/dev/null 2>&1 || fail "Firebase CLI is required."
command -v node >/dev/null 2>&1 || fail "Node is required."
[[ "${PIPEBUYER_CREATE_LIVE_PORTAL_CONFIG:-}" == "YES" ]] || \
  fail "Set PIPEBUYER_CREATE_LIVE_PORTAL_CONFIG=YES only after the current Terms and Privacy pages are live and reviewed."

umask 077
KEY_FILE="$(mktemp)"
cleanup() { rm -f "$KEY_FILE"; }
trap cleanup EXIT

firebase functions:secrets:access STRIPE_SECRET_PRODUCTION \
  --project "$PROJECT_ID" | tail -n 1 > "$KEY_FILE"
[[ -s "$KEY_FILE" ]] || fail "STRIPE_SECRET_PRODUCTION could not be read."

STRIPE_KEY_FILE="$KEY_FILE" EXPECTED_STRIPE_ACCOUNT="$EXPECTED_STRIPE_ACCOUNT" node <<'NODE'
const fs = require('node:fs');
const {stripeMarketplaceConfig} = require('./firebase/functions/stripe_marketplace_config');

const key = fs.readFileSync(process.env.STRIPE_KEY_FILE, 'utf8').trim();
const expectedAccount = process.env.EXPECTED_STRIPE_ACCOUNT;
const termsUrl = 'https://www.pipebuyer.com/terms';
const privacyUrl = 'https://www.pipebuyer.com/privacy';
const returnUrl = 'https://www.pipebuyer.com/payments/dispatch';

async function stripe(path, options = {}) {
  const response = await fetch(`https://api.stripe.com${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${key}`,
      'Stripe-Version': stripeMarketplaceConfig.apiVersion,
      ...(options.headers || {}),
    },
  });
  const payload = await response.json();
  if (!response.ok) throw new Error(`Stripe request failed (${response.status}) for ${path}.`);
  return payload;
}

function isSafeDispatchPortal(config) {
  const f = config && config.features || {};
  return config && config.active === true &&
    f.payment_method_update && f.payment_method_update.enabled === true &&
    f.subscription_cancel && f.subscription_cancel.enabled === true &&
    f.subscription_cancel.mode === 'at_period_end' &&
    (!f.subscription_update || f.subscription_update.enabled !== true);
}

(async () => {
  const account = await stripe('/v1/account');
  if (account.id !== expectedAccount) {
    throw new Error('Refusing Portal configuration: Stripe key is not the Pipe Buyer production account.');
  }

  const listed = await stripe('/v1/billing_portal/configurations?limit=100');
  const existing = (listed.data || []).find((item) =>
    item.metadata && item.metadata.pipebuyerPurpose === 'dispatch_subscription' &&
    isSafeDispatchPortal(item));
  if (existing) {
    console.log(`Safe Dispatch Portal already exists: ${existing.id}`);
    console.log('No Stripe mutation performed.');
    return;
  }

  const form = new URLSearchParams();
  form.set('business_profile[headline]', 'Manage your Pipe Buyer Dispatch membership');
  form.set('business_profile[privacy_policy_url]', privacyUrl);
  form.set('business_profile[terms_of_service_url]', termsUrl);
  form.set('default_return_url', returnUrl);
  form.set('features[customer_update][enabled]', 'false');
  form.set('features[invoice_history][enabled]', 'true');
  form.set('features[payment_method_update][enabled]', 'true');
  form.set('features[subscription_cancel][enabled]', 'true');
  form.set('features[subscription_cancel][mode]', 'at_period_end');
  form.set('features[subscription_cancel][proration_behavior]', 'none');
  form.set('features[subscription_cancel][cancellation_reason][enabled]', 'true');
  for (const reason of ['too_expensive', 'missing_features', 'switched_service', 'unused', 'other']) {
    form.append('features[subscription_cancel][cancellation_reason][options][]', reason);
  }
  form.set('features[subscription_update][enabled]', 'false');
  form.set('login_page[enabled]', 'false');
  form.set('metadata[pipebuyerPurpose]', 'dispatch_subscription');
  form.set('metadata[pipebuyerPolicy]', 'payment_method_update_and_cancel_at_period_end_only');

  const created = await stripe('/v1/billing_portal/configurations', {
    method: 'POST',
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: form.toString(),
  });
  if (!String(created.id || '').startsWith('bpc_') || !isSafeDispatchPortal(created)) {
    throw new Error('Stripe created a Portal configuration that does not match the required Pipe Buyer safety policy.');
  }
  console.log(`Created safe live Dispatch Portal configuration: ${created.id}`);
  console.log('IMPORTANT: Pipe Buyer Portal readiness remains OFF until this ID is explicitly reviewed and saved through the audited payment-readiness control.');
})().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
NODE
