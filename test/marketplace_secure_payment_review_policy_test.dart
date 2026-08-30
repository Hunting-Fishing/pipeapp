import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_secure_payment.dart';

void main() {
  group('marketplace payment review policy', () {
    test('review is available only after a Pipe Buyer payment is paid', () {
      expect(
        marketplacePaymentReviewAvailable(<String, dynamic>{
          'paymentProviderStatus': 'not_started',
        }),
        isFalse,
      );
      expect(
        marketplacePaymentReviewAvailable(<String, dynamic>{
          'paymentProviderStatus': 'paid',
          'financialStatus': 'settled',
        }),
        isTrue,
      );
    });

    test('an active review disables another request', () {
      final sale = <String, dynamic>{
        'paymentProviderStatus': 'paid',
        'financialStatus': 'refund_requested',
        'activeFinancialCaseId': 'refund-case-1',
      };

      expect(marketplacePaymentReviewPending(sale), isTrue);
      expect(marketplacePaymentReviewAvailable(sale), isFalse);
    });

    test('terminal financial states do not expose refund review action', () {
      for (final status in const ['refunded', 'disputed', 'charged_back']) {
        expect(
          marketplacePaymentReviewAvailable(<String, dynamic>{
            'paymentProviderStatus': 'paid',
            'financialStatus': status,
          }),
          isFalse,
          reason: status,
        );
      }
    });

    test('payload never sends a client-selected monetary amount', () {
      final payload = marketplaceRefundReviewPayload(
        requestId: 'refund-transaction-1-abc',
        transactionId: 'transaction-1',
        reason: '  The item was not received as agreed.  ',
      );

      expect(payload, <String, Object?>{
        'requestId': 'refund-transaction-1-abc',
        'transactionId': 'transaction-1',
        'reason': 'The item was not received as agreed.',
      });
      expect(payload.containsKey('amountMinor'), isFalse);
      expect(payload.containsKey('stripeChargeId'), isFalse);
    });

    test('reason validation stays bounded for review quality and safety', () {
      expect(marketplaceRefundReviewReasonValid('too short'), isFalse);
      expect(
        marketplaceRefundReviewReasonValid('Item was not received as agreed.'),
        isTrue,
      );
      expect(
        marketplaceRefundReviewReasonValid(
          List<String>.filled(
            marketplaceRefundReviewMaxReasonLength + 1,
            'x',
          ).join(),
        ),
        isFalse,
      );
    });

    test('request id remains server-safe even with a long transaction id', () {
      final longTransactionId = '${List<String>.filled(30, 'transaction').join()}/unsafe';
      final requestId = marketplaceRefundReviewRequestId(
        longTransactionId,
        123456789,
      );

      expect(requestId.length, lessThanOrEqualTo(180));
      expect(requestId, isNot(contains('/')));
      expect(requestId, startsWith('refund-'));
    });
  });
}
