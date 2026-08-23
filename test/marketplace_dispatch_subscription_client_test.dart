import 'package:flutter_test/flutter_test.dart';

import 'package:pipe_app/marketplace/marketplace_dispatch_subscription_client.dart';

Map<String, dynamic> statusPayload({
  String plan = '',
  String providerStatus = 'not_subscribed',
  bool hasRecord = false,
  bool entitlementActive = false,
  bool paymentIssue = false,
  bool reviewRequired = false,
  bool checkoutOpen = false,
  bool processing = false,
  bool alreadySubscribed = false,
  bool billingAvailable = true,
  bool canStartCheckout = true,
  bool canManageBilling = false,
}) =>
    {
      'hasRecord': hasRecord,
      'plan': plan,
      'providerStatus': providerStatus,
      'billingStatus': '',
      'entitlementActive': entitlementActive,
      'paymentIssue': paymentIssue,
      'reviewRequired': reviewRequired,
      'checkoutOpen': checkoutOpen,
      'processing': processing,
      'alreadySubscribed': alreadySubscribed,
      'billingAvailable': billingAvailable,
      'canStartCheckout': canStartCheckout,
      'canManageBilling': canManageBilling,
      'plans': {
        'monthly': {
          'currency': 'CAD',
          'unitAmountMinor': 2500,
          'interval': 'month',
        },
        'yearly': {
          'currency': 'CAD',
          'unitAmountMinor': 30000,
          'interval': 'year',
        },
      },
    };

void main() {
  test('Dispatch pricing is parsed from server catalog', () {
    final status = MarketplaceDispatchSubscriptionStatus.fromMap(statusPayload());
    expect(status.monthly.formattedPrice, r'CAD $25');
    expect(status.yearly.formattedPrice, r'CAD $300');
    expect(status.monthly.interval, 'month');
    expect(status.yearly.interval, 'year');
    expect(status.billingAvailable, isTrue);
  });

  test('billing availability is fail-closed when an older backend omits it', () {
    final payload = statusPayload()..remove('billingAvailable');
    final status = MarketplaceDispatchSubscriptionStatus.fromMap(payload);
    expect(status.billingAvailable, isFalse);
  });

  test('active subscription status is server-authoritative', () {
    final status = MarketplaceDispatchSubscriptionStatus.fromMap(statusPayload(
      plan: 'monthly',
      providerStatus: 'active',
      hasRecord: true,
      entitlementActive: true,
      alreadySubscribed: true,
      canStartCheckout: false,
      canManageBilling: true,
    ));
    expect(status.entitlementActive, isTrue);
    expect(status.alreadySubscribed, isTrue);
    expect(status.canStartCheckout, isFalse);
    expect(status.canManageBilling, isTrue);
  });

  test('billing unavailable status is distinct from user subscription state', () {
    final status = MarketplaceDispatchSubscriptionStatus.fromMap(statusPayload(
      billingAvailable: false,
      canStartCheckout: false,
    ));
    expect(status.billingAvailable, isFalse);
    expect(status.alreadySubscribed, isFalse);
    expect(status.canStartCheckout, isFalse);
  });

  test('Stripe Checkout accepts only exact secure checkout host', () {
    expect(
      isValidStripeCheckoutUrl(
        'https://checkout.stripe.com/c/pay/cs_test_dispatch',
      ),
      isTrue,
    );
    expect(
      isValidStripeCheckoutUrl(
        'http://checkout.stripe.com/c/pay/cs_test_dispatch',
      ),
      isFalse,
    );
    expect(
      isValidStripeCheckoutUrl(
        'https://checkout.stripe.com.evil.example/c/pay/test',
      ),
      isFalse,
    );
    expect(
      isValidStripeCheckoutUrl('https://evil.example/checkout'),
      isFalse,
    );
  });

  test('Stripe Billing Portal accepts only exact secure billing host', () {
    expect(
      isValidStripeBillingPortalUrl(
        'https://billing.stripe.com/p/session/test',
      ),
      isTrue,
    );
    expect(
      isValidStripeBillingPortalUrl(
        'https://billing.stripe.com.evil.example/session',
      ),
      isFalse,
    );
  });

  test('Billing Portal response requires validated Stripe link', () {
    final result = MarketplaceDispatchBillingPortalResult.fromMap({
      'portalUrl': 'https://billing.stripe.com/p/session/test',
    });
    expect(result.portalUrl, contains('billing.stripe.com'));
    expect(
      () => MarketplaceDispatchBillingPortalResult.fromMap({
        'portalUrl': 'https://evil.example/billing',
      }),
      throwsStateError,
    );
  });

  test('open Checkout response exposes a validated provider link', () {
    final result = MarketplaceDispatchCheckoutResult.fromMap({
      'plan': 'yearly',
      'alreadySubscribed': false,
      'processing': false,
      'alreadyCreated': true,
      'checkoutUrl': 'https://checkout.stripe.com/c/pay/cs_test_dispatch',
    });
    expect(result.plan, 'yearly');
    expect(result.alreadyCreated, isTrue);
    expect(result.canLaunchCheckout, isTrue);
  });

  test('processing response does not require a browser link', () {
    final result = MarketplaceDispatchCheckoutResult.fromMap({
      'plan': 'monthly',
      'alreadySubscribed': false,
      'processing': true,
      'alreadyCreated': true,
    });
    expect(result.processing, isTrue);
    expect(result.canLaunchCheckout, isFalse);
  });

  test('non-processing unpaid response must include secure Checkout link', () {
    expect(
      () => MarketplaceDispatchCheckoutResult.fromMap({
        'plan': 'monthly',
        'alreadySubscribed': false,
        'processing': false,
      }),
      throwsStateError,
    );
  });

  test('invalid plan or malformed catalog fails closed', () {
    expect(
      () => MarketplaceDispatchSubscriptionStatus.fromMap(
        statusPayload(plan: 'weekly'),
      ),
      throwsStateError,
    );
    final malformed = statusPayload();
    (malformed['plans'] as Map<String, dynamic>)['monthly'] = {
      'currency': 'CAD',
      'unitAmountMinor': -1,
      'interval': 'month',
    };
    expect(
      () => MarketplaceDispatchSubscriptionStatus.fromMap(malformed),
      throwsStateError,
    );
  });
}
