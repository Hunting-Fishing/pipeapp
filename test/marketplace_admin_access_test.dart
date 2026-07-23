import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_admin_access.dart';

void main() {
  test('administrator UI requires the complete signed claim set', () {
    expect(marketplaceAdministratorClaims(null), isFalse);
    expect(marketplaceAdministratorClaims({'admin': true}), isFalse);
    expect(
        marketplaceAdministratorClaims({
          'admin': true,
          'role': 'administrator',
          'firebase': {'sign_in_second_factor': 'phone'}
        }),
        isTrue);
  });

  test('email and public profile fields cannot grant administrator UI', () {
    expect(
        marketplaceAdministratorClaims({
          'email': 'jordilwbailey@gmail.com',
          'email_verified': true,
          'isAdmin': true,
        }),
        isFalse);
  });
}
