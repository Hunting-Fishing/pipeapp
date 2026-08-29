from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one target in {path}; found {count}")
    p.write_text(text.replace(old, new, 1))


# Seller financial recovery must recognize every transfer created by a split sale.
replace_once(
    "firebase/functions/marketplace_seller_funds.js",
    '''  const values = [\n    String(sale && sale.stripeSellerTransferId || ""),\n    ...(Array.isArray(sale && sale.sellerPayoutTransferIds) ?\n      sale.sellerPayoutTransferIds.map((value) => String(value || "")) : []),\n  ];''',
    '''  const values = [\n    String(sale && sale.stripeSellerTransferId || ""),\n    ...(Array.isArray(sale && sale.sellerPayoutTransferIds) ?\n      sale.sellerPayoutTransferIds.map((value) => String(value || "")) : []),\n    ...(Array.isArray(sale && sale.stripeSellerTransfers) ?\n      sale.stripeSellerTransfers.map((record) =>\n        String(record && record.transferId || "")) : []),\n  ];''',
)

# Full Checkout cannot race or bypass an agreed/proposed split payment plan.
replace_once(
    "firebase/functions/stripe_checkout_commands.js",
    '''      const sale = transactionSnapshot.data();\n      if (sale.buyerUid !== uid) {''',
    '''      const sale = transactionSnapshot.data();\n      if (sale.paymentPlanStatus === "proposal_pending" ||\n          (sale.paymentPlan === "deposit_balance" &&\n            sale.paymentPlanStatus === "active")) {\n        throw new HttpsError(\n            "failed-precondition",\n            "Resolve the deposit and balance terms before starting a full payment.",\n        );\n      }\n      if (sale.buyerUid !== uid) {''',
)

# Split checkout has its own production activation gate in addition to core Checkout readiness.
replace_once(
    "firebase/functions/marketplace_split_checkout_commands.js",
    '''      requireCheckoutReady(readiness);\n\n      const transactionId = cleanId(''',
    '''      requireCheckoutReady(readiness);\n      if (readiness.marketplaceSplitPaymentsEnabled !== true) {\n        throw new HttpsError(\n            "failed-precondition",\n            "Deposit and balance payments are not enabled yet.",\n        );\n      }\n\n      const transactionId = cleanId(''',
)

# Webhook settlement routes payment-part Checkout sessions before the legacy full-sale path.
replace_once(
    "firebase/functions/stripe_webhook.js",
    '''  const financialResolution = options.marketplaceFinancialResolution || null;\n  const subscriptionMonetization = createSubscriptionMonetization(''',
    '''  const financialResolution = options.marketplaceFinancialResolution || null;\n  const paymentPartSettlement = options.marketplacePaymentPartSettlement || null;\n  const subscriptionMonetization = createSubscriptionMonetization(''',
)
replace_once(
    "firebase/functions/stripe_webhook.js",
    '''  async function markCheckoutFailure(session) {\n    if (billingType(session) === "dispatch_subscription") {''',
    '''  async function markCheckoutFailure(session) {\n    if (billingType(session) === "marketplace_payment_part" &&\n        paymentPartSettlement) {\n      await paymentPartSettlement.markPaymentPartFailure(session);\n      return;\n    }\n    if (billingType(session) === "dispatch_subscription") {''',
)
replace_once(
    "firebase/functions/stripe_webhook.js",
    '''  async function settleSuccessfulCheckout(session) {\n    if (billingType(session) === "marketplace_fee_only") {''',
    '''  async function settleSuccessfulCheckout(session) {\n    if (billingType(session) === "marketplace_payment_part" &&\n        paymentPartSettlement) {\n      await paymentPartSettlement.settleSuccessfulPaymentPart(session);\n      return;\n    }\n    if (billingType(session) === "marketplace_fee_only") {''',
)
replace_once(
    "firebase/functions/stripe_webhook.js",
    '''  async function markCheckoutProcessing(session) {\n    if (billingType(session) === "dispatch_subscription") {''',
    '''  async function markCheckoutProcessing(session) {\n    if (billingType(session) === "marketplace_payment_part" &&\n        paymentPartSettlement) {\n      await paymentPartSettlement.markPaymentPartProcessing(session);\n      return;\n    }\n    if (billingType(session) === "dispatch_subscription") {''',
)
replace_once(
    "firebase/functions/stripe_webhook.js",
    '''    if (type === "checkout.session.async_payment_failed") {\n      await markCheckoutFailure(object);\n      return;\n    }\n    if (type === "invoice.paid") {''',
    '''    if (type === "checkout.session.async_payment_failed") {\n      await markCheckoutFailure(object);\n      return;\n    }\n    if (type === "checkout.session.expired") {\n      await markCheckoutFailure(object);\n      return;\n    }\n    if (type === "invoice.paid") {''',
)

# Add a separately auditable split-payment activation switch.
replace_once(
    "firebase/functions/payment_readiness_admin.js",
    '''  "marketplaceFinancialResolutionEnabled",\n  "marketplaceDisputeAutomationEnabled",''',
    '''  "marketplaceFinancialResolutionEnabled",\n  "marketplaceSplitPaymentsEnabled",\n  "marketplaceRefundAutomationEnabled",\n  "marketplaceDisputeAutomationEnabled",''',
)
replace_once(
    "firebase/functions/payment_readiness_admin.js",
    '''  if (next.marketplaceDisputeAutomationEnabled &&\n      !next.marketplaceFinancialResolutionEnabled) {''',
    '''  if (next.marketplaceSplitPaymentsEnabled && !(\n    next.stripeCheckoutEnabled &&\n    next.stripeWebhookVerified &&\n    next.stripeReconciliationReady\n  )) {\n    throw new HttpsError(\n        "failed-precondition",\n        "Split marketplace payments require live Checkout, verified webhooks, and reconciliation readiness.",\n    );\n  }\n  if (next.marketplaceRefundAutomationEnabled &&\n      !next.marketplaceFinancialResolutionEnabled) {\n    throw new HttpsError(\n        "failed-precondition",\n        "Refund automation requires marketplace financial resolution.",\n    );\n  }\n  if (next.marketplaceDisputeAutomationEnabled &&\n      !next.marketplaceFinancialResolutionEnabled) {''',
)

# Bootstrap additive payment-plan commands, payment-part webhook settlement, and split seller release.
replace_once(
    "firebase/functions/bootstrap.js",
    '''const {\n  createMarketplacePaymentLifecycle,\n} = require("./marketplace_payment_lifecycle");''',
    '''const {\n  createMarketplacePaymentLifecycle,\n} = require("./marketplace_payment_lifecycle");\nconst {\n  createMarketplacePaymentPlanCommands,\n} = require("./marketplace_payment_plan_commands");\nconst {\n  createMarketplaceSplitCheckoutCommands,\n} = require("./marketplace_split_checkout_commands");\nconst {\n  createMarketplacePaymentPartSettlement,\n} = require("./marketplace_payment_part_settlement");\nconst {\n  createMarketplaceSplitSellerRelease,\n} = require("./marketplace_split_seller_release");''',
)
replace_once(
    "firebase/functions/bootstrap.js",
    '''const stripeCheckoutCommands = createStripeCheckoutCommands(admin);\nconst marketplacePaymentLifecycle = createMarketplacePaymentLifecycle(admin);\nconst externalSettlementCommands = createExternalSettlementCommands(admin);''',
    '''const stripeCheckoutCommands = createStripeCheckoutCommands(admin);\nconst marketplacePaymentLifecycle = createMarketplacePaymentLifecycle(admin);\nconst marketplacePaymentPlanCommands = createMarketplacePaymentPlanCommands(admin);\nconst marketplaceSplitCheckoutCommands =\n  createMarketplaceSplitCheckoutCommands(admin);\nconst marketplacePaymentPartSettlement =\n  createMarketplacePaymentPartSettlement(admin);\nconst marketplaceSplitSellerRelease =\n  createMarketplaceSplitSellerRelease(admin);\nconst externalSettlementCommands = createExternalSettlementCommands(admin);''',
)
replace_once(
    "firebase/functions/bootstrap.js",
    '''const baseStripeWebhookHandler = createStripeWebhookHandler(admin, {\n  marketplaceFinancialResolution: marketplaceRefundWebhookGate,\n});''',
    '''const baseStripeWebhookHandler = createStripeWebhookHandler(admin, {\n  marketplaceFinancialResolution: marketplaceRefundWebhookGate,\n  marketplacePaymentPartSettlement,\n});''',
)
replace_once(
    "firebase/functions/bootstrap.js",
    '''exports.cancelMarketplaceRefundRequest = onCall(\n    protectedCallableOptions,\n    marketplaceFinancialResolution.cancelMarketplaceRefundRequest,\n);\nexports.getDispatchSubscriptionCatalog = onCall(''',
    '''exports.cancelMarketplaceRefundRequest = onCall(\n    protectedCallableOptions,\n    marketplaceFinancialResolution.cancelMarketplaceRefundRequest,\n);\nexports.proposeMarketplaceDepositPlan = onCall(\n    protectedCallableOptions,\n    policyAcceptanceCommands.requireCurrentPolicies(\n        marketplacePaymentPlanCommands.proposeMarketplaceDepositPlan,\n    ),\n);\nexports.approveMarketplaceDepositPlan = onCall(\n    protectedCallableOptions,\n    policyAcceptanceCommands.requireCurrentPolicies(\n        marketplacePaymentPlanCommands.approveMarketplaceDepositPlan,\n    ),\n);\nexports.declineMarketplaceDepositPlan = onCall(\n    protectedCallableOptions,\n    policyAcceptanceCommands.requireCurrentPolicies(\n        marketplacePaymentPlanCommands.declineMarketplaceDepositPlan,\n    ),\n);\nexports.getDispatchSubscriptionCatalog = onCall(''',
)
replace_once(
    "firebase/functions/bootstrap.js",
    '''exports.createMarketplaceCheckout = onCall(\n    stripeCallableOptions,\n    stripeCheckoutCommands.createMarketplaceCheckout,\n);\nexports.createExternalSettlementFeeCheckout = onCall(''',
    '''exports.createMarketplaceCheckout = onCall(\n    stripeCallableOptions,\n    stripeCheckoutCommands.createMarketplaceCheckout,\n);\nexports.createMarketplacePaymentPartCheckout = onCall(\n    stripeCallableOptions,\n    policyAcceptanceCommands.requireCurrentPolicies(\n        marketplaceSplitCheckoutCommands.createMarketplacePaymentPartCheckout,\n    ),\n);\nexports.createExternalSettlementFeeCheckout = onCall(''',
)
replace_once(
    "firebase/functions/bootstrap.js",
    '''    async (event) => marketplacePaymentLifecycle.releaseSellerFunds({\n      transactionId: event.params.transactionId,\n    }),\n);''',
    '''    async (event) => {\n      const after = event.data && event.data.after && event.data.after.data();\n      if (after && after.paymentPlan === "deposit_balance") {\n        return marketplaceSplitSellerRelease.releaseSplitSellerFunds({\n          transactionId: event.params.transactionId,\n        });\n      }\n      return marketplacePaymentLifecycle.releaseSellerFunds({\n        transactionId: event.params.transactionId,\n      });\n    },\n);''',
)

print("Split-payment integration patches applied.")
