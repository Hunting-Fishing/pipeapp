#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${FIREBASE_PROJECT_ID:-flutter-flow-pipe}"
EXPECTED_STRIPE_ACCOUNT="${EXPECTED_STRIPE_ACCOUNT:-acct_1U2QmKDkO07WMXyR}"
WEBHOOK_URL="${STRIPE_WEBHOOK_URL:-https://us-central1-flutter-flow-pipe.cloudfunctions.net/stripeMarketplaceWebhook}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

fail() { echo "ERROR: $*" >&2; exit 1; }
command -v firebase >/dev/null 2>&1 || fail "Firebase CLI is required."
command -v node >/dev/null 2>&1 || fail "Node 22 is required."
[[ "${PIPEBUYER_SYNC_LIVE_WEBHOOK:-}" == "YES" ]] || \
  fail "Set PIPEBUYER_SYNC_LIVE_WEBHOOK=YES only after the new stripeMarketplaceWebhook code has been deployed and validated."

umask 077
KEY_FILE="$(mktemp)"
SECRET_FILE="$(mktemp)"
cleanup() { rm -f "$KEY_FILE" "$SECRET_FILE"; }
trap cleanup EXIT

firebase functions:secrets:access STRIPE_SECRET_PRODUCTION \
  --project "$PROJECT_ID" | tail -n 1 > "$KEY_FILE"
firebase functions:secrets:access STRIPE_WEBHOOK_SECRET \
  --project "$PROJECT_ID" | tail -n 1 > "$SECRET_FILE"
[[ -s "$KEY_FILE" && -s "$SECRET_FILE" ]] || fail "Stripe production secrets are unavailable from Firebase Secret Manager."

STRIPE_KEY_FILE="$KEY_FILE" \
STRIPE_WEBHOOK_SECRET_FILE="$SECRET_FILE" \
EXPECTED_STRIPE_ACCOUNT="$EXPECTED_STRIPE_ACCOUNT" \
STRIPE_WEBHOOK_URL="$WEBHOOK_URL" \
node <<'NODE'
const crypto = require('node:crypto');
const fs = require('node:fs');
const {stripeMarketplaceConfig} = require('./firebase/functions/stripe_marketplace_config');
const {STRIPE_WEBHOOK_EVENTS} = require('./firebase/functions/stripe_webhook_event_catalog');

const key = fs.readFileSync(process.env.STRIPE_KEY_FILE, 'utf8').trim();
const webhookSecret = fs.readFileSync(process.env.STRIPE_WEBHOOK_SECRET_FILE, 'utf8').trim();
const expectedAccount = process.env.EXPECTED_STRIPE_ACCOUNT;
const webhookUrl = process.env.STRIPE_WEBHOOK_URL;

if (!key || !webhookSecret.startsWith('whsec_')) {
  throw new Error('Stripe credentials are invalid or unavailable.');
}

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
  if (!response.ok) {
    throw new Error(`Stripe request failed (${response.status}) for ${path}.`);
  }
  return payload;
}

function sameEvents(actual) {
  const expected = [...STRIPE_WEBHOOK_EVENTS].sort();
  const received = Array.isArray(actual) ? [...actual].sort() : [];
  return expected.length === received.length &&
    expected.every((event, index) => event === received[index]);
}

async function signedProbe() {
  const timestamp = Math.floor(Date.now() / 1000);
  const payload = JSON.stringify({
    id: `evt_pipebuyer_local_probe_${Date.now()}`,
    object: 'event',
    type: 'pipebuyer.local_release.probe',
    data: {object: {id: 'pipebuyer_local_release_probe'}},
  });
  const signature = crypto.createHmac('sha256', webhookSecret)
    .update(`${timestamp}.${payload}`)
    .digest('hex');
  const response = await fetch(webhookUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Stripe-Signature': `t=${timestamp},v1=${signature}`,
    },
    body: payload,
  });
  const text = (await response.text()).trim();
  if (!response.ok || !['OK', 'Already processed'].includes(text)) {
    throw new Error(`Deployed webhook failed signed probe: HTTP ${response.status} ${text}`);
  }
  console.log('Signed deployed-webhook probe passed.');
}

(async () => {
  const account = await stripe('/v1/account');
  if (account.id !== expectedAccount) {
    throw new Error('Refusing webhook mutation: Stripe key belongs to a different account.');
  }

  const listed = await stripe('/v1/webhook_endpoints?limit=100');
  const matches = (listed.data || []).filter((item) => item.url === webhookUrl);
  if (matches.length !== 1) {
    throw new Error(`Refusing webhook mutation: expected exactly one endpoint for ${webhookUrl}, found ${matches.length}.`);
  }
  let endpoint = matches[0];
  if (endpoint.livemode !== true || endpoint.status !== 'enabled') {
    throw new Error('Refusing webhook mutation: current production endpoint is not enabled live-mode.');
  }

  // Never expand provider delivery until the deployed code has proven that the
  // Firebase signing secret and handler are correctly paired.
  await signedProbe();

  const form = new URLSearchParams();
  form.set('disabled', 'false');
  form.set('description', 'Pipe Buyer production marketplace, subscription, refund, and dispute webhook');
  for (const event of STRIPE_WEBHOOK_EVENTS) form.append('enabled_events[]', event);
  endpoint = await stripe(`/v1/webhook_endpoints/${encodeURIComponent(endpoint.id)}`, {
    method: 'POST',
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: form.toString(),
  });

  if (endpoint.status !== 'enabled' || endpoint.livemode !== true || !sameEvents(endpoint.enabled_events)) {
    throw new Error('Stripe webhook update returned an unexpected status or event catalog.');
  }
  console.log(`Stripe webhook synchronized successfully: ${endpoint.id}`);
  console.log(`Enabled event count: ${endpoint.enabled_events.length}`);
})().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
NODE

echo "Live Stripe webhook synchronization completed without GitHub Actions."
