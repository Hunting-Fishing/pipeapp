import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_invoice_generator.dart';

Map<String, dynamic> marketplaceTransaction({
  Map<String, dynamic>? feeSnapshot,
  String paymentStatus = 'paid',
  String payoutStatus = 'pending_release',
}) =>
    <String, dynamic>{
      'listingTitle': '3 1/2 EUE Tubing J-55 9.3#',
      'currency': 'USD',
      'paymentProviderStatus': paymentStatus,
      'sellerPayoutStatus': payoutStatus,
      'marketplaceFeeSnapshot': feeSnapshot ??
          <String, dynamic>{
            'source': 'server_fee_policy',
            'scheduleRevision': '2026-10-16-sale-v3',
            'feePayer': 'seller',
            'currency': 'USD',
            'agreedTotalMinor': 1250000,
            'marketplaceFeeMinor': 125000,
            'sellerProceedsBeforeTaxMinor': 1125000,
          },
    };

void main() {
  group('MarketplaceInvoice server snapshot', () {
    test('uses immutable gross sale, seller fee, and seller proceeds', () {
      final invoice = MarketplaceInvoice.fromMarketplaceTransaction(
        transactionId: 'auction-listing-1',
        transaction: marketplaceTransaction(),
        sellerName: 'Calgary Tubular Ltd',
        buyerName: 'Permian Energy Resources',
      );

      expect(invoice.grossSaleMinor, 1250000);
      expect(invoice.marketplaceFeeMinor, 125000);
      expect(invoice.sellerProceedsBeforeTaxMinor, 1125000);
      expect(invoice.feeScheduleRevision, '2026-10-16-sale-v3');
      expect(invoice.paymentProviderStatusLabel, 'Paid');
      expect(invoice.sellerPayoutStatusLabel, 'Pending release');
      expect(invoice.money(invoice.grossSaleMinor), r'USD 12,500.00');
    });

    test('rejects missing, unverified, or inconsistent fee data', () {
      expect(
        () => MarketplaceInvoice.fromMarketplaceTransaction(
          transactionId: 'missing',
          transaction: const <String, dynamic>{},
        ),
        throwsFormatException,
      );
      expect(
        () => MarketplaceInvoice.fromMarketplaceTransaction(
          transactionId: 'client-authored',
          transaction: marketplaceTransaction(
            feeSnapshot: <String, dynamic>{
              'source': 'client',
              'scheduleRevision': 'revision',
              'currency': 'USD',
              'agreedTotalMinor': 10000,
              'marketplaceFeeMinor': 1000,
              'sellerProceedsBeforeTaxMinor': 9000,
            },
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => MarketplaceInvoice.fromMarketplaceTransaction(
          transactionId: 'inconsistent',
          transaction: marketplaceTransaction(
            feeSnapshot: <String, dynamic>{
              'source': 'server_fee_policy',
              'scheduleRevision': 'revision',
              'currency': 'USD',
              'agreedTotalMinor': 10000,
              'marketplaceFeeMinor': 1000,
              'sellerProceedsBeforeTaxMinor': 9500,
            },
          ),
        ),
        throwsFormatException,
      );
    });

    test('serializes provider-authored amounts without legacy fee fields', () {
      final json = MarketplaceInvoice.fromMarketplaceTransaction(
        transactionId: 'auction-listing-2',
        transaction: marketplaceTransaction(
          paymentStatus: 'checkout_created',
          payoutStatus: 'not_released',
        ),
      ).toJson();

      expect(json['grossSaleMinor'], 1250000);
      expect(json['marketplaceFeeMinor'], 125000);
      expect(json['sellerProceedsBeforeTaxMinor'], 1125000);
      expect(json['paymentProviderStatus'], 'checkout_created');
      expect(json, isNot(contains('sellerCommissionFee')));
      expect(json, isNot(contains('escrowProtectionFee')));
    });

    test('auction settlement loads the server transaction before rendering',
        () {
      final settlement = File(
        'lib/marketplace/marketplace_auction_settlement.dart',
      ).readAsStringSync();
      final generator = File(
        'lib/marketplace/marketplace_invoice_generator.dart',
      ).readAsStringSync();

      expect(settlement, contains("collection('marketplace_transactions')"));
      expect(settlement, contains("'auction_\${widget.listingId}'"));
      expect(
        settlement,
        contains('MarketplaceInvoice.fromMarketplaceTransaction('),
      );
      expect(settlement, isNot(contains('View Itemized Invoice')));
      expect(generator, isNot(contains('sellerFeeRate')));
      expect(generator, isNot(contains('escrowFeeRate')));
      expect(generator, isNot(contains('Escrow Protection Fee')));
      expect(generator, isNot(contains("'Pay Now'")));
    });
  });
}
