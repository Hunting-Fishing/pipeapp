from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    target = Path(path)
    text = target.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one match, found {count}\n--- needle ---\n{old}")
    target.write_text(text.replace(old, new, 1))


activation = ".github/workflows/activate-live-billing-pending-tax.yml"
replace_once(
    activation,
    'on:\n  push:\n    branches:\n      - main\n    paths:\n      - ".github/workflows/activate-live-billing-pending-tax.yml"\n  workflow_dispatch:\n',
    'on:\n  workflow_dispatch:\n',
)
replace_once(
    activation,
    '    name: Activate production billing with tax registration pending\n',
    '    name: Activate production billing with deferred marketplace tax collection\n',
)
replace_once(
    activation,
    '                    stripeCheckoutEnabled: false,\n',
    '                    stripeCheckoutEnabled: true,\n',
)
replace_once(
    activation,
    '                    stripeTaxReady: false,\n                    stripeTaxRegistrationPending: true,\n                    stripeReconciliationReady: true,\n',
    '                    stripeTaxReady: false,\n'
    '                    stripeTaxRegistrationPending: true,\n'
    '                    marketplaceTaxCollectionDeferredApproved: true,\n'
    '                    stripeReconciliationReady: true,\n',
)
replace_once(
    activation,
    '                    lastChangeReason:\n                      "Live Pipe Buyer billing enabled while CRA GST/HST registration is pending.",\n',
    '                    lastChangeReason:\n'
    '                      "Live Pipe Buyer marketplace Checkout enabled with an audited tax-collection deferral while registration/name documents are pending.",\n',
)
replace_once(
    activation,
    '                    stripeTaxRegistrationPending:\n                      readiness.stripeTaxRegistrationPending,\n                    stripeTaxReady: readiness.stripeTaxReady,\n',
    '                    stripeTaxRegistrationPending:\n'
    '                      readiness.stripeTaxRegistrationPending,\n'
    '                    marketplaceTaxCollectionDeferredApproved:\n'
    '                      readiness.marketplaceTaxCollectionDeferredApproved,\n'
    '                    stripeTaxReady: readiness.stripeTaxReady,\n',
)
replace_once(
    activation,
    "              result.stripeCheckoutEnabled !== false ||\n              result.stripeTaxRegistrationPending !== true ||\n              result.stripeTaxReady !== false) {\n            throw new Error('Production billing activation did not match the authorized pending-tax profile.');\n",
    "              result.stripeCheckoutEnabled !== true ||\n"
    "              result.stripeTaxRegistrationPending !== true ||\n"
    "              result.marketplaceTaxCollectionDeferredApproved !== true ||\n"
    "              result.stripeTaxReady !== false) {\n"
    "            throw new Error('Production billing activation did not match the authorized deferred-tax marketplace profile.');\n",
)
replace_once(
    activation,
    '            echo "- Tax registration: pending"\n            echo "- Full buyer-to-seller marketplace checkout: intentionally disabled until tax registration is confirmed"\n',
    '            echo "- Tax registration/name documents: pending"\n'
    '            echo "- Marketplace tax collection: deferred by audited launch decision"\n'
    '            echo "- Stripe automatic tax: disabled until registration is finalized"\n'
    '            echo "- Full buyer-to-seller marketplace checkout: enabled"\n',
)

safe = ".github/workflows/deploy-payment-backend-safe.yml"
replace_once(
    safe,
    '          targets=(\n            updateMarketplaceTransaction\n',
    '          targets=(\n'
    '            updateMarketplaceTransaction\n'
    '            updateAuctionTransaction\n'
    '            onAuctionTransactionCreatedPaymentMirror\n'
    '            onAuctionTransactionUpdatedPaymentMirror\n'
    '            onMarketplaceTransactionUpdatedSellerRelease\n',
)
replace_once(
    safe,
    "          const required = [\n            'getDispatchSubscriptionCatalog',\n",
    "          const required = [\n"
    "            'updateMarketplaceTransaction',\n"
    "            'updateAuctionTransaction',\n"
    "            'onAuctionTransactionCreatedPaymentMirror',\n"
    "            'onAuctionTransactionUpdatedPaymentMirror',\n"
    "            'onMarketplaceTransactionUpdatedSellerRelease',\n"
    "            'getDispatchSubscriptionCatalog',\n",
)
replace_once(
    safe,
    '# Release retry trigger: stale settlement-label regression test repaired 2026-08-29.\n',
    '# Release trigger: marketplace checkout, Timed Buying mirror, and delayed seller release validated 2026-08-29.\n',
)

release = ".github/workflows/release-stripe-live-alignment-2026-08-29.yml"
replace_once(
    release,
    '      - name: Dispatch tax-pending live billing activation\n',
    '      - name: Dispatch deferred-tax live marketplace activation\n',
)
replace_once(
    release,
    '            echo "- Full buyer-to-seller Stripe Checkout: held pending Canadian tax readiness"\n',
    '            echo "- Full buyer-to-seller Stripe Checkout: activated with automatic tax disabled under audited collection deferral"\n',
)
replace_once(
    release,
    'name: Release Stripe Live Alignment 2026-08-29\n',
    'name: Release Stripe Live Alignment 2026-08-29\n# Retry trigger: validated marketplace checkout + Timed Buying + delayed seller release.\n',
)

print("Payment release controls updated for deferred-tax live marketplace Checkout.")
