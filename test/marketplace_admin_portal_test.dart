import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_admin_access.dart';

void main() {
  group('Marketplace Admin Access Tests', () {
    test('Claims validator checks admin role and second factor', () {
      final validClaims = {
        'admin': true,
        'role': 'administrator',
        'firebase': {'sign_in_second_factor': 'phone'},
      };
      expect(marketplaceAdministratorClaims(validClaims), isTrue);

      final invalidClaims = {
        'admin': true,
        'role': 'user',
      };
      expect(marketplaceAdministratorClaims(invalidClaims), isFalse);
    });
  });
}
