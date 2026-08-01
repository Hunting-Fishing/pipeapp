import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_invoice_generator.dart';

void main() {
  group('MarketplaceInvoice Model Tests', () {
    test('Calculates subtotal, fees, and total due accurately', () {
      final invoice = MarketplaceInvoice(
        invoiceId: 'INV-1001',
        listingTitle: '3 1/2 EUE Tubing J-55 9.3#',
        sellerName: 'Calgary Tubular Ltd',
        buyerName: 'Permian Energy Resources',
        unitPrice: 12.50,
        quantity: 1000,
        unitLabel: 'ft',
        freightCharge: 850.00,
        issueDate: DateTime(2026, 8, 1),
        dueDate: DateTime(2026, 8, 8),
      );

      expect(invoice.subtotal, equals(12500.00));
      expect(invoice.sellerCommissionFee, equals(312.50)); // 2.5% of 12500
      expect(invoice.escrowProtectionFee, equals(125.00)); // 1.0% of 12500
      expect(invoice.totalDue, equals(12500.00 + 125.00 + 850.00)); // 13475.00
      expect(invoice.status, equals('Unpaid'));
    });

    test('Serializes invoice data to JSON cleanly', () {
      final invoice = MarketplaceInvoice(
        invoiceId: 'INV-2002',
        listingTitle: 'Frac Tank 500 BBL',
        sellerName: 'Midland Fleet Inc',
        buyerName: 'Houston Oilfields',
        unitPrice: 28000.00,
        quantity: 1,
        unitLabel: 'unit',
        issueDate: DateTime(2026, 8, 1),
        dueDate: DateTime(2026, 8, 8),
      );

      final json = invoice.toJson();
      expect(json['invoiceId'], equals('INV-2002'));
      expect(json['subtotal'], equals(28000.00));
      expect(json['sellerCommissionFee'], equals(700.00)); // 2.5%
      expect(json['escrowProtectionFee'], equals(280.00)); // 1.0%
      expect(json['totalDue'], equals(28280.00));
    });
  });
}
