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

  test('open unpaid fee checkout requires a secure provider URL', () {
    expect(
      () => ExternalSettlementFeeCheckoutResult.fromMap({
        'transactionId': 'tx_1',
        'checkoutSessionId': 'cs_test_1',
        'alreadyPaid': false,
        'processing': false,
        'paymentFailed': false,
      }),
      throwsStateError,
    );
  });

  test('open fee checkout exposes a launchable Stripe link', () {
    final result = ExternalSettlementFeeCheckoutResult.fromMap({
      'transactionId': 'tx_1',
      'checkoutSessionId': 'cs_test_1',
      'checkoutUrl': 'https://checkout.stripe.com/c/pay/cs_test_1',
      'alreadyPaid': false,
      'alreadyCreated': true,
      'processing': false,
      'paymentFailed': false,
      'checkoutAttempt': 2,
      'taxCollectionStatus': 'registration_pending',
    });
    expect(result.canLaunchCheckout, isTrue);
    expect(result.alreadyCreated, isTrue);
    expect(result.checkoutAttempt, 2);
  });

  test('processing fee response does not require a checkout URL', () {
    final result = ExternalSettlementFeeCheckoutResult.fromMap({
      'transactionId': 'tx_1',
      'checkoutSessionId': 'cs_live_1',
      'alreadyPaid': false,
      'alreadyCreated': true,
      'processing': true,
      'paymentFailed': false,
    });
    expect(result.processing, isTrue);
    expect(result.canLaunchCheckout, isFalse);
    expect(result.checkoutUri, isNull);
  });

  test('failed fee response allows a clean retry without a stale URL', () {
    final result = ExternalSettlementFeeCheckoutResult.fromMap({
      'transactionId': 'tx_1',
      'checkoutSessionId': 'cs_failed_1',
      'alreadyPaid': false,
      'alreadyCreated': true,
      'processing': false,
      'paymentFailed': true,
    });
    expect(result.paymentFailed, isTrue);
    expect(result.canLaunchCheckout, isFalse);
    expect(result.checkoutUri, isNull);
  });

  test('already-paid fee response does not require a checkout URL', () {
    final result = ExternalSettlementFeeCheckoutResult.fromMap({
      'transactionId': 'tx_1',
      'checkoutSessionId': 'cs_live_1',
      'alreadyPaid': true,
    });
    expect(result.alreadyPaid, isTrue);
    expect(result.canLaunchCheckout, isFalse);
    expect(result.checkoutUri, isNull);
  });

  test('contradictory paid and processing states are rejected', () {
    expect(
      () => ExternalSettlementFeeCheckoutResult.fromMap({
        'transactionId': 'tx_1',
        'alreadyPaid': true,
        'processing': true,
      }),
      throwsStateError,
    );
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

  test('inconsistent fully-confirmed settlement state is rejected', () {
    expect(
      () => ExternalSettlementConfirmationResult.fromMap({
        'transactionId': 'tx_1',
        'role': 'buyer',
        'buyerConfirmed': true,
        'sellerConfirmed': false,
        'fullyConfirmed': true,
      }),
      throwsStateError,
    );
  });

  test('Stripe fee receipt accepts only HTTPS Stripe domains', () {
    expect(
      validatedStripeReceiptUri(
        'https://pay.stripe.com/receipts/payment/example',
      ).host,
      'pay.stripe.com',
    );
    expect(
      () => validatedStripeReceiptUri(
        'https://stripe.com.evil.example/receipt',
      ),
      throwsStateError,
    );
  });

  test('paid fee receipt maps provider reference and amount', () {
    final result = ExternalSettlementFeeReceiptResult.fromMap({
      'transactionId': 'tx_1',
      'chargeId': 'ch_live_123',
      'amountMinor': 2875,
      'currency': 'CAD',
      'receiptUrl': 'https://pay.stripe.com/receipts/payment/example',
    });
    expect(result.chargeId, 'ch_live_123');
    expect(result.amountMinor, 2875);
    expect(result.currency, 'CAD');
    expect(result.receiptUri, isNotNull);
  });

  test('receipt may retain provider reference when hosted URL is unavailable', () {
    final result = ExternalSettlementFeeReceiptResult.fromMap({
      'transactionId': 'tx_1',
      'chargeId': 'ch_live_123',
      'amountMinor': 2875,
      'currency': 'CAD',
      'receiptUrl': '',
    });
    expect(result.receiptUri, isNull);
    expect(result.chargeId, 'ch_live_123');
  });
}
