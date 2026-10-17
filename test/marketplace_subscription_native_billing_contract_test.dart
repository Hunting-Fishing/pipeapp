import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/native_membership_billing.dart';

void main() {
  test('annual store savings copy is derived from live localized prices', () {
    expect(
      nativeMembershipAnnualSavingsLabel(
        monthlyPrice: 24.99,
        annualPrice: 249.99,
      ),
      'Save 17% • about 2 months free with annual billing',
    );
    expect(
      nativeMembershipAnnualSavingsLabel(
        monthlyPrice: 24.99,
        annualPrice: 299.99,
      ),
      isNull,
      reason: 'the UI must not claim savings before the store price changes',
    );
  });

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
    final verifyIndex =
        nativeBilling.indexOf("'verifyNativeMembershipPurchase'");
    final completeIndex = nativeBilling.indexOf('completePurchase(purchase)');
    final preflightIndex =
        nativeBilling.indexOf("'preflightNativeMembershipPurchase'");
    final buyIndex = nativeBilling.indexOf('_iap.buyNonConsumable');

    expect(preflightIndex, greaterThanOrEqualTo(0));
    expect(buyIndex, greaterThan(preflightIndex));
    expect(nativeBilling, contains("preflight['purchaseIntentToken']"));
    expect(nativeBilling, contains("'purchaseIntentToken': intent.token"));
    expect(nativeBilling, contains('SharedPreferences.getInstance()'));
    expect(
      nativeBilling,
      contains("'releaseNativeMembershipPurchaseIntent'"),
    );
    expect(verifyIndex, greaterThanOrEqualTo(0));
    expect(completeIndex, greaterThan(verifyIndex));
    expect(nativeBilling, contains('applicationUserName: accountToken'));
    expect(nativeBilling, contains('ReplacementMode.deferred'));
    expect(nativeBilling, contains('ReplacementMode.withTimeProration'));
    expect(nativeBilling, contains('restorePurchases'));
  });

  test('native restore always leaves its busy state', () {
    final nativeBilling = File(
      'lib/marketplace/native_membership_billing.dart',
    ).readAsStringSync();
    final restoreIndex = nativeBilling.indexOf(
      'await _iap.restorePurchases(applicationUserName: accountToken);',
    );
    final finallyIndex = nativeBilling.indexOf('} finally {', restoreIndex);
    final resetIndex = nativeBilling.indexOf(
      'setState(() => _restoreBusy = false);',
      finallyIndex,
    );

    expect(restoreIndex, greaterThanOrEqualTo(0));
    expect(
      nativeBilling.indexOf("'preflightNativeMembershipRestore'"),
      lessThan(restoreIndex),
    );
    expect(finallyIndex, greaterThan(restoreIndex));
    expect(resetIndex, greaterThan(finallyIndex));
  });

  test(
      'purchase updates bind account/product and reject unbound terminal release',
      () {
    expect(
      nativePurchaseIntentMatchesUpdate(
        intentPlatform: 'ios',
        intentProductId: 'pipebuyer_dispatch_monthly',
        intentOwnerUid: 'user-1',
        restore: false,
        updatePlatform: 'ios',
        updateProductId: 'pipebuyer_dispatch_monthly',
        currentOwnerUid: 'user-1',
      ),
      isTrue,
    );
    expect(
      nativePurchaseIntentMatchesUpdate(
        intentPlatform: 'ios',
        intentProductId: 'pipebuyer_dispatch_monthly',
        intentOwnerUid: 'user-1',
        restore: false,
        updatePlatform: 'ios',
        updateProductId: 'pipebuyer_dispatch_yearly',
        currentOwnerUid: 'user-1',
      ),
      isFalse,
    );
    expect(
      nativePurchaseIntentMatchesUpdate(
        intentPlatform: 'ios',
        intentProductId: 'pipebuyer_dispatch_monthly',
        intentOwnerUid: 'user-1',
        restore: false,
        updatePlatform: 'ios',
        updateProductId: 'pipebuyer_dispatch_monthly',
        currentOwnerUid: 'user-2',
      ),
      isFalse,
    );
    expect(
      nativePurchaseIntentMatchesUpdate(
        intentPlatform: 'ios',
        intentProductId: '*',
        intentOwnerUid: 'user-1',
        restore: true,
        updatePlatform: 'ios',
        updateProductId: 'pipebuyer_dispatch_yearly',
        currentOwnerUid: 'user-1',
      ),
      isTrue,
    );
    expect(
      nativePurchaseTerminalMayReleaseIntent(
        accountPlatformProductMatch: true,
        exactProviderAttemptBound: false,
      ),
      isFalse,
      reason: 'a stale same-product terminal update has no server nonce',
    );
  });

  test('pending purchase keeps a server-authoritative token-bound reservation',
      () {
    final nativeBilling = File(
      'lib/marketplace/native_membership_billing.dart',
    ).readAsStringSync();

    expect(nativeBilling, contains("'markNativeMembershipPurchasePending'"));
    expect(nativeBilling, contains("productId: '*'"));
    expect(nativeBilling, contains('_intentRecordKeyPrefix'));
    expect(nativeBilling, contains('jsonEncode(<String, Object?>'));
    expect(nativeBilling, contains('preferences.setString(key, encoded)'));
    expect(nativeBilling, contains('preferences.getString(key) == encoded'));
    expect(nativeBilling, contains("'resumeNativeMembershipPurchaseIntent'"));
    expect(nativeBilling,
        contains('SharedPreferences is only a best-effort cache'));
    expect(nativeBilling, contains('clearPurchaseIntentIfMatches'));
  });

  test('restart recovery consults the server before any same-product cache',
      () {
    final nativeBilling = File(
      'lib/marketplace/native_membership_billing.dart',
    ).readAsStringSync();
    final resolveStart = nativeBilling.indexOf(
      'Future<_NativePurchaseIntentRecord> _resolvePurchaseIntent',
    );
    final resolveEnd = nativeBilling.indexOf(
      'String _purchaseKey',
      resolveStart,
    );
    final recovery = nativeBilling.substring(resolveStart, resolveEnd);

    expect(resolveStart, greaterThanOrEqualTo(0));
    expect(recovery, contains("'resumeNativeMembershipPurchaseIntent'"));
    expect(recovery, isNot(contains('_loadPurchaseIntent(ownerUid)')));
    expect(recovery, contains('resumedOwnerUid != ownerUid'));
  });

  test('one app-lifetime coordinator observes prior-session store updates', () {
    final nativeBilling = File(
      'lib/marketplace/native_membership_billing.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(
      RegExp(r'purchaseStream\.listen').allMatches(nativeBilling).length,
      1,
    );
    expect(
        nativeBilling, contains('class NativeMembershipPurchaseCoordinator'));
    expect(nativeBilling, contains('FirebaseAuth.instance.authStateChanges()'));
    expect(nativeBilling, contains('_deferredPurchases'));
    expect(
      main,
      contains('NativeMembershipPurchaseCoordinator.instance.initialize()'),
    );
    final bootstrapCall = main.indexOf('await _initializePipeBuyer');
    final runApp = main.indexOf('runApp(ChangeNotifierProvider', bootstrapCall);
    final firebaseInit = main.indexOf('await initFirebase(');
    final observerInit = main
        .indexOf('NativeMembershipPurchaseCoordinator.instance.initialize()');
    expect(bootstrapCall, greaterThanOrEqualTo(0));
    expect(runApp, greaterThan(bootstrapCall));
    expect(observerInit, greaterThan(firebaseInit));
  });

  test('empty restore result settles only the active wildcard intent', () {
    final nativeBilling = File(
      'lib/marketplace/native_membership_billing.dart',
    ).readAsStringSync();
    final emptyBatch = nativeBilling.indexOf('if (purchases.isEmpty)');
    final restoreBinding = nativeBilling.indexOf(
      'intent.token == _activeRestoreIntentToken',
      emptyBatch,
    );
    final release = nativeBilling.indexOf(
      'await releasePurchaseIntent(intent.token)',
      restoreBinding,
    );
    final clear = nativeBilling.indexOf(
      'await clearPurchaseIntentIfMatches(',
      release,
    );

    expect(emptyBatch, greaterThanOrEqualTo(0));
    expect(restoreBinding, greaterThan(emptyBatch));
    expect(release, greaterThan(restoreBinding));
    expect(clear, greaterThan(release));
  });

  test('iOS subscription UI includes renewal and legal disclosures', () {
    final nativeBilling = File(
      'lib/marketplace/native_membership_billing.dart',
    ).readAsStringSync();

    expect(nativeBilling, contains("nativeMembershipPlatformName() == 'ios'"));
    expect(nativeBilling, contains('renews automatically unless canceled'));
    expect(
      nativeBilling,
      contains('least 24 hours before the current period ends.'),
    );
    expect(nativeBilling, contains('https://www.pipebuyer.com/terms'));
    expect(nativeBilling, contains('https://www.pipebuyer.com/privacy'));
    expect(nativeBilling, contains("const Text('Terms of Service')"));
    expect(nativeBilling, contains("const Text('Privacy Policy')"));
  });

  test('Android subscription UI includes renewal and legal disclosures', () {
    final nativeBilling = File(
      'lib/marketplace/native_membership_billing.dart',
    ).readAsStringSync();

    expect(
      nativeBilling,
      contains("nativeMembershipPlatformName() == 'android'"),
    );
    expect(
      nativeBilling,
      contains('Payment is charged to your Google Play account'),
    );
    expect(nativeBilling, contains('renews automatically unless'));
    expect(nativeBilling, contains('price and billing period shown above'));
    expect(nativeBilling, contains("'Play subscription settings.'"));
    expect(nativeBilling, contains("const Text('Google Play subscriptions')"));
    expect(
      "const Text('Terms of Service')".allMatches(nativeBilling).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      "const Text('Privacy Policy')".allMatches(nativeBilling).length,
      greaterThanOrEqualTo(2),
    );
  });

  test('native product lookup prefers platform-specific server catalogs', () {
    final nativeBilling = File(
      'lib/marketplace/native_membership_billing.dart',
    ).readAsStringSync();

    expect(nativeBilling, contains("status['appleProductIds']"));
    expect(nativeBilling, contains("status['googleProductIds']"));
    expect(nativeBilling, contains("<String, Object?>{'platform': platform}"));
    expect(
      nativeBilling,
      contains(
        "platformProductIds is List ? platformProductIds : status['productIds']",
      ),
    );
  });

  test('native verification is limited to the Apple Sandbox pilot surface', () {
    final bootstrap = File(
      'firebase/functions/production_bootstrap.js',
    ).readAsStringSync();

    expect(bootstrap, contains('exports.getNativeMembershipBillingStatus'));
    expect(bootstrap, contains('exports.preflightNativeMembershipPurchase'));
    expect(bootstrap, contains('exports.preflightNativeMembershipRestore'));
    expect(
      bootstrap,
      contains('exports.releaseNativeMembershipPurchaseIntent'),
    );
    expect(
      bootstrap,
      contains('exports.resumeNativeMembershipPurchaseIntent'),
    );
    expect(
      bootstrap,
      contains('exports.markNativeMembershipPurchasePending'),
    );
    expect(bootstrap, contains('exports.verifyNativeMembershipPurchase'));
    expect(bootstrap, contains('appleSandboxCohortOnly: true'));
    expect(bootstrap, contains('secrets: APPLE_IAP_SECRET_NAMES'));
    expect(
      bootstrap,
      isNot(contains('exports.reconcileNativeMembershipSubscriptions')),
    );
    expect(
      bootstrap,
      isNot(contains('exports.appStoreServerNotifications =')),
    );
  });
}
