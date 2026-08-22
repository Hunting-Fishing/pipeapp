import 'package:flutter_test/flutter_test.dart';

import 'package:pipe_app/marketplace/marketplace_external_settlement_client.dart';

void main() {
  test('Stripe fee checkout accepts only checkout.stripe.com HTTPS links', () {
    expect(
      validatedStripeCheckoutUri('https://checkout.stripe.com/c/pay/cs_test_123')
          .host,
      'checkout.stripe.com',
    );
    expect(
      () => validatedStripeCheckoutUri('http://checkout.stripe.com/c/pay/test'),
      throwsStateError,
    );
    expect(
      () => validatedStripeCheckoutUri('https://evil.example/checkout'),
      throwsStateError,
    );
  });

  test('unpaid fee checkout requires a secure provider URL', () {
    expect(
      () => ExternalSettlementFeeCheckoutResult.fromMap({
        'transactionId': 'tx_1',
        'checkoutSessionId': 'cs_test_1',
        'alreadyPaid': false,
      }),
      throwsStateError,
    );
  });

  test('already-paid fee response does not require a checkout URL', () {
    final result = ExternalSettlementFeeCheckoutResult.fromMap({
      'transactionId': 'tx_1',
      'checkoutSessionId': 'cs_live_1',
      'alreadyPaid': true,
    });
    expect(result.alreadyPaid, isTrue);
    expect(result.checkoutUri, isNull);
  });

  test('external settlement confirmation maps both-party state', () {
    final result = ExternalSettlementConfirmationResult.fromMap({
      'transactionId': 'tx_1',
      'role': 'seller',
      'buyerConfirmed': true,
      'sellerConfirmed': true,
      'fullyConfirmed': true,
    });
    expect(result.transactionId, 'tx_1');
    expect(result.role, 'seller');
    expect(result.buyerConfirmed, isTrue);
    expect(result.sellerConfirmed, isTrue);
    expect(result.fullyConfirmed, isTrue);
  });
}
