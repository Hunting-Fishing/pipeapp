import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_payment_terms.dart';

void main() {
  test('parses deposit money into exact minor units without floating math', () {
    expect(parseMarketplaceMoneyMinor('500'), 50000);
    expect(parseMarketplaceMoneyMinor('500.5'), 50050);
    expect(parseMarketplaceMoneyMinor(r'$1,250.05'), 125005);
    expect(parseMarketplaceMoneyMinor('0'), isNull);
    expect(parseMarketplaceMoneyMinor('10.999'), isNull);
    expect(parseMarketplaceMoneyMinor('-10'), isNull);
  });

  test('formats marketplace money labels clearly by currency', () {
    expect(marketplaceMoneyLabel(2500, 'CAD'), r'CA$25');
    expect(marketplaceMoneyLabel(250050, 'USD'), r'US$2500.50');
    expect(marketplaceMoneyLabel(12345, 'EUR'), 'EUR 123.45');
  });
}
