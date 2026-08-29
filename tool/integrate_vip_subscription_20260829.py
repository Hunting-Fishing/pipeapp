#!/usr/bin/env python3
"""Deterministically wire Pipe Buyer VIP billing into existing payment runtime."""

from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Expected integration anchor missing in {path}: {old[:100]!r}")
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8")


# Separate production readiness switch. Generic Stripe subscription readiness
# remains necessary, but it is not enough to expose VIP Checkout by itself.
replace_once(
    "firebase/functions/payment_readiness_admin.js",
    '  "stripeSubscriptionsEnabled",\n  "stripeDispatchPortalEnabled",',
    '  "stripeSubscriptionsEnabled",\n'
    '  "stripeVipSubscriptionsEnabled",\n'
    '  "stripeDispatchPortalEnabled",',
)
replace_once(
    "firebase/functions/payment_readiness_admin.js",
    '  if (next.stripeDispatchPortalEnabled && !(\n',
    '  if (next.stripeVipSubscriptionsEnabled && !(\n'
    '    next.stripeSubscriptionsEnabled &&\n'
    '    next.stripeMode === "production" &&\n'
    '    next.stripeWebhookVerified &&\n'
    '    taxBillingPrepared(next) &&\n'
    '    next.stripeReconciliationReady\n'
    '  )) {\n'
    '    throw new HttpsError(\n'
    '        "failed-precondition",\n'
    '        "Pipe Buyer VIP subscriptions require the verified production subscription billing gate.",\n'
    '    );\n'
    '  }\n'
    '  if (next.stripeDispatchPortalEnabled && !(\n',
)

# Wire dedicated VIP modules into the established Firebase Functions runtime.
replace_once(
    "firebase/functions/bootstrap.js",
    'const {\n  createDispatchSubscriptionStatus,\n} = require("./dispatch_subscription_status");\n',
    'const {\n  createDispatchSubscriptionStatus,\n} = require("./dispatch_subscription_status");\n'
    'const {\n  createVipSubscriptionCatalog,\n} = require("./vip_subscription_catalog");\n'
    'const {\n  createVipSubscriptionCommands,\n} = require("./vip_subscription_commands");\n'
    'const {\n  createVipSubscriptionLifecycle,\n} = require("./vip_subscription_lifecycle");\n'
    'const {\n  createVipSubscriptionManagement,\n} = require("./vip_subscription_management");\n'
    'const {\n  createVipSubscriptionStatus,\n} = require("./vip_subscription_status");\n',
)
replace_once(
    "firebase/functions/bootstrap.js",
    'const dispatchSubscriptionStatus = createDispatchSubscriptionStatus(admin);\n',
    'const dispatchSubscriptionStatus = createDispatchSubscriptionStatus(admin);\n'
    'const vipSubscriptionCatalog = createVipSubscriptionCatalog(admin);\n'
    'const vipSubscriptionCommands = createVipSubscriptionCommands(admin);\n'
    'const vipSubscriptionLifecycle = createVipSubscriptionLifecycle(admin);\n'
    'const vipSubscriptionManagement = createVipSubscriptionManagement(admin);\n'
    'const vipSubscriptionStatus = createVipSubscriptionStatus(admin);\n',
)
replace_once(
    "firebase/functions/bootstrap.js",
    '  dispatchSubscriptionLifecycle,\n  stripeWebhookSecret,\n});\n',
    '  dispatchSubscriptionLifecycle,\n'
    '  vipSubscriptionLifecycle,\n'
    '  stripeWebhookSecret,\n});\n',
)
replace_once(
    "firebase/functions/bootstrap.js",
    'exports.getDispatchSubscriptionStatus = onCall(\n'
    '    protectedCallableOptions,\n'
    '    dispatchSubscriptionStatus.getDispatchSubscriptionStatus,\n'
    ');\n',
    'exports.getDispatchSubscriptionStatus = onCall(\n'
    '    protectedCallableOptions,\n'
    '    dispatchSubscriptionStatus.getDispatchSubscriptionStatus,\n'
    ');\n'
    'exports.getVipSubscriptionCatalog = onCall(\n'
    '    protectedCallableOptions,\n'
    '    vipSubscriptionCatalog.getVipSubscriptionCatalog,\n'
    ');\n'
    'exports.getVipSubscriptionStatus = onCall(\n'
    '    protectedCallableOptions,\n'
    '    vipSubscriptionStatus.getVipSubscriptionStatus,\n'
    ');\n',
)
replace_once(
    "firebase/functions/bootstrap.js",
    'exports.createDispatchSubscriptionPortalSession = onCall(\n'
    '    stripeCallableOptions,\n'
    '    dispatchSubscriptionPortal.createDispatchSubscriptionPortalSession,\n'
    ');\n',
    'exports.createDispatchSubscriptionPortalSession = onCall(\n'
    '    stripeCallableOptions,\n'
    '    dispatchSubscriptionPortal.createDispatchSubscriptionPortalSession,\n'
    ');\n'
    'exports.createVipSubscriptionCheckout = onCall(\n'
    '    stripeCallableOptions,\n'
    '    policyAcceptanceCommands.requireCurrentPolicies(\n'
    '        vipSubscriptionCommands.createVipSubscriptionCheckout,\n'
    '    ),\n'
    ');\n'
    'exports.updateVipSubscriptionRenewal = onCall(\n'
    '    stripeCallableOptions,\n'
    '    vipSubscriptionManagement.updateVipSubscriptionRenewal,\n'
    ');\n',
)

# Extend the single verified webhook pipeline. Checkout redirects never grant
# VIP; only invoice.paid writes paid membership state.
replace_once(
    "firebase/functions/stripe_webhook.js",
    'const {\n  createSubscriptionMonetization,\n} = require("./subscription_monetization");\n',
    'const {\n  createSubscriptionMonetization,\n} = require("./subscription_monetization");\n'
    'const {\n  createVipSubscriptionMonetization,\n} = require("./vip_subscription_monetization");\n',
)
replace_once(
    "firebase/functions/stripe_webhook.js",
    '  const subscriptionMonetization = createSubscriptionMonetization(\n'
    '      admin,\n'
    '      stripeMarketplaceConfig,\n'
    '  );\n',
    '  const subscriptionMonetization = createSubscriptionMonetization(\n'
    '      admin,\n'
    '      stripeMarketplaceConfig,\n'
    '  );\n'
    '  const vipSubscriptionMonetization = createVipSubscriptionMonetization(\n'
    '      admin,\n'
    '      stripeMarketplaceConfig,\n'
    '  );\n',
)
replace_once(
    "firebase/functions/stripe_webhook.js",
    '    if (billingType(session) === "dispatch_subscription") {\n'
    '      await db.collection("subscription_checkout_sessions")\n'
    '          .doc(String(session.id || "")).set({\n'
    '            status: "payment_failed",\n'
    '            paymentFailedAt: FieldValue.serverTimestamp(),\n'
    '            updatedAt: FieldValue.serverTimestamp(),\n'
    '          }, {merge: true});\n'
    '      return;\n'
    '    }\n',
    '    if (billingType(session) === "dispatch_subscription") {\n'
    '      await db.collection("subscription_checkout_sessions")\n'
    '          .doc(String(session.id || "")).set({\n'
    '            status: "payment_failed",\n'
    '            paymentFailedAt: FieldValue.serverTimestamp(),\n'
    '            updatedAt: FieldValue.serverTimestamp(),\n'
    '          }, {merge: true});\n'
    '      return;\n'
    '    }\n'
    '    if (billingType(session) === "vip_subscription") {\n'
    '      await db.collection("vip_subscription_checkout_sessions")\n'
    '          .doc(String(session.id || "")).set({\n'
    '            status: "payment_failed",\n'
    '            paymentFailedAt: FieldValue.serverTimestamp(),\n'
    '            updatedAt: FieldValue.serverTimestamp(),\n'
    '          }, {merge: true});\n'
    '      return;\n'
    '    }\n',
)
replace_once(
    "firebase/functions/stripe_webhook.js",
    '    if (billingType(session) === "dispatch_subscription") {\n'
    '      const customerId = typeof session.customer === "string" ?\n'
    '        session.customer : String(session.customer && session.customer.id || "");\n'
    '      await db.collection("subscription_checkout_sessions")\n'
    '          .doc(String(session.id || "")).set({\n'
    '            status: session.payment_status === "paid" ? "active" : "processing",\n'
    '            stripeSubscriptionId: typeof session.subscription === "string" ?\n'
    '              session.subscription :\n'
    '              String(session.subscription && session.subscription.id || ""),\n'
    '            stripeCustomerId: customerId.startsWith("cus_") ? customerId : null,\n'
    '            updatedAt: FieldValue.serverTimestamp(),\n'
    '          }, {merge: true});\n'
    '      return;\n'
    '    }\n',
    '    if (billingType(session) === "dispatch_subscription") {\n'
    '      const customerId = typeof session.customer === "string" ?\n'
    '        session.customer : String(session.customer && session.customer.id || "");\n'
    '      await db.collection("subscription_checkout_sessions")\n'
    '          .doc(String(session.id || "")).set({\n'
    '            status: session.payment_status === "paid" ? "active" : "processing",\n'
    '            stripeSubscriptionId: typeof session.subscription === "string" ?\n'
    '              session.subscription :\n'
    '              String(session.subscription && session.subscription.id || ""),\n'
    '            stripeCustomerId: customerId.startsWith("cus_") ? customerId : null,\n'
    '            updatedAt: FieldValue.serverTimestamp(),\n'
    '          }, {merge: true});\n'
    '      return;\n'
    '    }\n'
    '    if (billingType(session) === "vip_subscription") {\n'
    '      const customerId = typeof session.customer === "string" ?\n'
    '        session.customer : String(session.customer && session.customer.id || "");\n'
    '      await db.collection("vip_subscription_checkout_sessions")\n'
    '          .doc(String(session.id || "")).set({\n'
    '            status: session.payment_status === "paid" ? "processing" : "processing",\n'
    '            stripeSubscriptionId: typeof session.subscription === "string" ?\n'
    '              session.subscription :\n'
    '              String(session.subscription && session.subscription.id || ""),\n'
    '            stripeCustomerId: customerId.startsWith("cus_") ? customerId : null,\n'
    '            updatedAt: FieldValue.serverTimestamp(),\n'
    '          }, {merge: true});\n'
    '      return;\n'
    '    }\n',
)
replace_once(
    "firebase/functions/stripe_webhook.js",
    '    if (billingType(session) === "dispatch_subscription") {\n'
    '      await db.collection("subscription_checkout_sessions")\n'
    '          .doc(String(session.id || "")).set({\n'
    '            status: "processing",\n'
    '            updatedAt: FieldValue.serverTimestamp(),\n'
    '          }, {merge: true});\n'
    '      return;\n'
    '    }\n',
    '    if (billingType(session) === "dispatch_subscription") {\n'
    '      await db.collection("subscription_checkout_sessions")\n'
    '          .doc(String(session.id || "")).set({\n'
    '            status: "processing",\n'
    '            updatedAt: FieldValue.serverTimestamp(),\n'
    '          }, {merge: true});\n'
    '      return;\n'
    '    }\n'
    '    if (billingType(session) === "vip_subscription") {\n'
    '      await db.collection("vip_subscription_checkout_sessions")\n'
    '          .doc(String(session.id || "")).set({\n'
    '            status: "processing",\n'
    '            updatedAt: FieldValue.serverTimestamp(),\n'
    '          }, {merge: true});\n'
    '      return;\n'
    '    }\n',
)
replace_once(
    "firebase/functions/stripe_webhook.js",
    '      await subscriptionMonetization.handleDispatchInvoicePaid(\n'
    '          object,\n'
    '          stripeSecretKey.value(),\n'
    '      );\n'
    '      return;\n',
    '      await subscriptionMonetization.handleDispatchInvoicePaid(\n'
    '          object,\n'
    '          stripeSecretKey.value(),\n'
    '      );\n'
    '      await vipSubscriptionMonetization.handleVipInvoicePaid(\n'
    '          object,\n'
    '          stripeSecretKey.value(),\n'
    '      );\n'
    '      return;\n',
)
replace_once(
    "firebase/functions/stripe_webhook.js",
    '      await subscriptionMonetization.handleDispatchInvoicePaymentFailed(\n'
    '          object,\n'
    '          stripeSecretKey.value(),\n'
    '      );\n'
    '      return;\n',
    '      await subscriptionMonetization.handleDispatchInvoicePaymentFailed(\n'
    '          object,\n'
    '          stripeSecretKey.value(),\n'
    '      );\n'
    '      await vipSubscriptionMonetization.handleVipInvoicePaymentFailed(\n'
    '          object,\n'
    '          stripeSecretKey.value(),\n'
    '      );\n'
    '      return;\n',
)

# The existing wrapper already verifies signatures. Route VIP Checkout and
# subscription lifecycle events through that same verified path.
replace_once(
    "firebase/functions/stripe_webhook_dispatch_lifecycle.js",
    'function isDispatchProviderStateEvent(event) {\n'
    '  return isDispatchSubscriptionLifecycleEvent(event) ||\n'
    '    isDispatchCheckoutCompletedEvent(event);\n'
    '}\n',
    'function isVipCheckoutCompletedEvent(event) {\n'
    '  const session = event && event.data && event.data.object;\n'
    '  return Boolean(event &&\n'
    '    event.type === "checkout.session.completed" &&\n'
    '    session &&\n'
    '    session.metadata &&\n'
    '    session.metadata.billingType === "vip_subscription");\n'
    '}\n\n'
    'function isDispatchProviderStateEvent(event) {\n'
    '  return isDispatchSubscriptionLifecycleEvent(event) ||\n'
    '    isDispatchCheckoutCompletedEvent(event);\n'
    '}\n',
)
replace_once(
    "firebase/functions/stripe_webhook_dispatch_lifecycle.js",
    '  dispatchSubscriptionLifecycle,\n  stripeWebhookSecret,\n}) {\n',
    '  dispatchSubscriptionLifecycle,\n'
    '  vipSubscriptionLifecycle,\n'
    '  stripeWebhookSecret,\n}) {\n',
)
replace_once(
    "firebase/functions/stripe_webhook_dispatch_lifecycle.js",
    '    if (!isDispatchProviderStateEvent(event)) {\n'
    '      return baseHandler(request, response);\n'
    '    }\n',
    '    if (!isDispatchProviderStateEvent(event) &&\n'
    '        !isVipCheckoutCompletedEvent(event)) {\n'
    '      return baseHandler(request, response);\n'
    '    }\n',
)
replace_once(
    "firebase/functions/stripe_webhook_dispatch_lifecycle.js",
    '      if (event.type === "checkout.session.completed") {\n'
    '        await dispatchSubscriptionLifecycle\n'
    '            .handleDispatchCheckoutCompleted(object);\n'
    '      } else if (event.type === "customer.subscription.created") {\n'
    '        await dispatchSubscriptionLifecycle\n'
    '            .handleDispatchSubscriptionCreated(object);\n'
    '      } else if (event.type === "customer.subscription.deleted") {\n'
    '        await dispatchSubscriptionLifecycle\n'
    '            .handleDispatchSubscriptionDeleted(object);\n'
    '      } else if ([\n'
    '        "customer.subscription.updated",\n'
    '        "customer.subscription.paused",\n'
    '        "customer.subscription.resumed",\n'
    '      ].includes(event.type)) {\n'
    '        await dispatchSubscriptionLifecycle\n'
    '            .handleDispatchSubscriptionUpdated(object);\n'
    '      }\n',
    '      const billing = String(object && object.metadata &&\n'
    '        object.metadata.billingType || "");\n'
    '      const vip = billing === "vip_subscription";\n'
    '      if (event.type === "checkout.session.completed") {\n'
    '        if (vip) {\n'
    '          await vipSubscriptionLifecycle.handleVipCheckoutCompleted(object);\n'
    '        } else {\n'
    '          await dispatchSubscriptionLifecycle\n'
    '              .handleDispatchCheckoutCompleted(object);\n'
    '        }\n'
    '      } else if (event.type === "customer.subscription.created") {\n'
    '        if (vip) {\n'
    '          await vipSubscriptionLifecycle.handleVipSubscriptionCreated(object);\n'
    '        } else {\n'
    '          await dispatchSubscriptionLifecycle\n'
    '              .handleDispatchSubscriptionCreated(object);\n'
    '        }\n'
    '      } else if (event.type === "customer.subscription.deleted") {\n'
    '        if (vip) {\n'
    '          await vipSubscriptionLifecycle.handleVipSubscriptionDeleted(object);\n'
    '        } else {\n'
    '          await dispatchSubscriptionLifecycle\n'
    '              .handleDispatchSubscriptionDeleted(object);\n'
    '        }\n'
    '      } else if ([\n'
    '        "customer.subscription.updated",\n'
    '        "customer.subscription.paused",\n'
    '        "customer.subscription.resumed",\n'
    '      ].includes(event.type)) {\n'
    '        if (vip) {\n'
    '          await vipSubscriptionLifecycle.handleVipSubscriptionUpdated(object);\n'
    '        } else {\n'
    '          await dispatchSubscriptionLifecycle\n'
    '              .handleDispatchSubscriptionUpdated(object);\n'
    '        }\n'
    '      }\n',
)
replace_once(
    "firebase/functions/stripe_webhook_dispatch_lifecycle.js",
    '      console.error("Dispatch subscription provider-state webhook failed", {\n',
    '      console.error("Subscription provider-state webhook failed", {\n',
)
replace_once(
    "firebase/functions/stripe_webhook_dispatch_lifecycle.js",
    '  isDispatchProviderStateEvent,\n  isDispatchSubscriptionLifecycleEvent,\n',
    '  isDispatchProviderStateEvent,\n'
    '  isDispatchSubscriptionLifecycleEvent,\n'
    '  isVipCheckoutCompletedEvent,\n',
)

# Replace only the intentional VIP placeholder in the existing responsive plan
# dialog. Dispatch card behavior remains unchanged.
replace_once(
    "lib/marketplace/marketplace_vip_access.dart",
    "import 'marketplace_dispatch_subscription_checkout.dart';\n",
    "import 'marketplace_dispatch_subscription_checkout.dart';\n"
    "import 'marketplace_vip_subscription_checkout.dart';\n",
)
replace_once(
    "lib/marketplace/marketplace_vip_access.dart",
    """        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'VIP billing is not configured yet. No VIP charge will be started.',
                  ),
                ),
              ),
              icon: Icon(icon),
              label: const Text('VIP billing coming soon'),
            ),
          ),
""",
    """        else
          const VipSubscriptionCheckoutButton(),
""",
)

print("VIP subscription integration patches applied.")
