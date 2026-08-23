import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String controllerSource() => File(
        'lib/marketplace/marketplace_dispatch_subscription_launch_readiness_panel.dart',
      ).readAsStringSync();
  String viewSource() => File(
        'lib/marketplace/marketplace_dispatch_subscription_readiness_view.dart',
      ).readAsStringSync();

  test('Dispatch launch readiness uses only audited server controls', () {
    final controller = controllerSource();
    final view = viewSource();
    final page = File(
      'lib/marketplace/marketplace_dispatch_subscription_admin_page.dart',
    ).readAsStringSync();
    final combined = '$controller\n$view';

    expect(page, contains('MarketplaceDispatchSubscriptionLaunchReadinessPanel'));
    expect(controller, contains("'getPaymentProviderReadiness'"));
    expect(controller, contains("'getDispatchBillingPortalReadiness'"));
    expect(controller, contains("'getCanadaGstHstThresholdAssessment'"));
    expect(controller, contains("'verifyDispatchSubscriptionLifecycleWebhook'"));
    expect(controller, contains("'setPaymentProviderReadiness'"));
    expect(controller, contains("'stripeSubscriptionRecoveryVerified'"));
    expect(controller, contains('I verified this'));
    expect(view, contains('Nothing on this card activates public subscriptions'));
    expect(combined, isNot(contains("'stripeSubscriptionsEnabled': true")));
    expect(combined, isNot(contains('FirebaseFirestore')));
    expect(combined, isNot(contains('.set(')));
    expect(combined, isNot(contains('.update(')));
    expect(combined, isNot(contains('.delete(')));
  });

  test('Dispatch readiness requires provider-bound Portal proof and gives one next action', () {
    final view = viewSource();

    expect(view, contains("portal['providerVerified'] == true"));
    expect(view, contains('providerVerifiedConfigurationId'));
    expect(view, contains('providerVerificationRevision'));
    expect(view, contains('LinearProgressIndicator'));
    expect(view, contains('Recommended next action'));
    expect(view, contains('BILLING OFF'));
    expect(view, contains('prerequisiteStates.length'));
    expect(view, contains('dispatchSubscriptionNextAction'));
  });

  test('GST HST readiness requires server-projected small-supplier evidence', () {
    final controller = controllerSource();
    final view = viewSource();

    expect(controller, contains('_taxEvidence'));
    expect(controller, contains('getCanadaGstHstThresholdAssessment'));
    expect(controller, contains('taxEvidence: _taxEvidence'));
    expect(view, contains("taxEvidence['smallSupplierBillingEvidenceReady'] == true"));
    expect(view, contains('smallSupplierBillingEvidenceReason'));
    expect(view, contains('smallSupplierAssessmentRevision'));
    expect(view, contains('smallSupplierBoundRevision'));
    expect(view, contains('dispatchTaxReadinessDetail'));
    expect(view, contains('assessment is stale'));
    expect(view, contains('threshold has been exceeded'));
  });

  test('stateful readiness controller delegates pure presentation to extracted view', () {
    final controller = controllerSource();

    expect(
      controller,
      contains("import 'marketplace_dispatch_subscription_readiness_view.dart';"),
    );
    expect(controller, contains('MarketplaceDispatchSubscriptionReadinessView'));
    expect(controller, isNot(contains('LinearProgressIndicator')));
    expect(controller, isNot(contains('class _GateRow')));
    expect(controller, isNot(contains('class _StatusPill')));
  });

  test('Dispatch billing operations workspace stays focused and protected', () {
    final page = File(
      'lib/marketplace/marketplace_dispatch_subscription_admin_page.dart',
    ).readAsStringSync();

    expect(page, contains('Protected financial operations'));
    expect(page, contains('maxWidth: 1080'));
    expect(page, contains("number: '1'"));
    expect(page, contains("number: '2'"));
    expect(page, contains("number: '3'"));
    expect(page, contains('It does not contain a public subscription-activation button'));
  });
}
