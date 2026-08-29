import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_subscription_billing_policy.dart';

void main() {
  test('hosted membership billing is allowed only on web', () {
    expect(marketplaceHostedMembershipBillingAllowed(isWeb: true), isTrue);
    expect(marketplaceHostedMembershipBillingAllowed(isWeb: false), isFalse);
  });
}
