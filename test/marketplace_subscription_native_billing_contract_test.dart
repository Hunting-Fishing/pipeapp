import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VIP and Dispatch route native builds to store billing controls', () {
    final dispatch = File(
      'lib/marketplace/marketplace_dispatch_subscription_checkout.dart',
    ).readAsStringSync();
    final vip = File(
      'lib/marketplace/marketplace_vip_subscription_checkout.dart',
    ).readAsStringSync();

    for (final source in [dispatch, vip]) {
      expect(source, contains('marketplace_subscription_billing_policy.dart'));
      expect(source, contains('marketplaceHostedMembershipBillingAllowed()'));
      expect(source, contains("import 'native_membership_billing.dart';"));
      expect(source, contains('NativeMembershipPlanButton'));
    }

    expect(dispatch, contains("'dispatch_monthly'"));
    expect(dispatch, contains("'dispatch_yearly'"));
    expect(vip, contains("targetPlan: 'vip_monthly'"));
    expect(
      dispatch,
      contains("if (!marketplaceHostedMembershipBillingAllowed()) return;"),
    );
    expect(
      vip,
      contains(
        "if (_busy || !marketplaceHostedMembershipBillingAllowed()) return;",
      ),
    );
  });

  test('native purchase waits for server verification before completion', () {
    final nativeBilling = File(
      'lib/marketplace/native_membership_billing.dart',
    ).readAsStringSync();
    final verifyIndex = nativeBilling.indexOf("'verifyNativeMembershipPurchase'");
    final completeIndex = nativeBilling.indexOf('completePurchase(purchase)');

    expect(verifyIndex, greaterThanOrEqualTo(0));
    expect(completeIndex, greaterThan(verifyIndex));
    expect(nativeBilling, contains('applicationUserName: accountToken'));
    expect(nativeBilling, contains('ReplacementMode.deferred'));
    expect(nativeBilling, contains('ReplacementMode.withTimeProration'));
    expect(nativeBilling, contains('restorePurchases'));
  });

  test('native verification stays fail-closed until store secrets activate', () {
    final bootstrap = File(
      'firebase/functions/production_bootstrap.js',
    ).readAsStringSync();

    expect(bootstrap, contains('exports.getNativeMembershipBillingStatus'));
    expect(bootstrap, isNot(contains('exports.verifyNativeMembershipPurchase')));
    expect(
      bootstrap,
      isNot(contains('exports.reconcileNativeMembershipSubscriptions')),
    );
  });
}
