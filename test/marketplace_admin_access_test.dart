import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_admin_access.dart';

void main() {
  group('administrator access state', () {
    test('requires both administrator claims', () {
      expect(
        marketplaceAdministratorClaimsState(const {'admin': true}),
        MarketplaceAdministratorState.roleMissing,
      );
      expect(
        marketplaceAdministratorClaimsState(
          const {'role': 'administrator'},
        ),
        MarketplaceAdministratorState.roleMissing,
      );
    });

    test('reports MFA requirement for a provisioned administrator role', () {
      expect(
        marketplaceAdministratorClaimsState(
          const {'admin': true, 'role': 'administrator'},
        ),
        MarketplaceAdministratorState.mfaRequired,
      );
    });

    test('authorizes only a role with second-factor evidence', () {
      const claims = {
        'admin': true,
        'role': 'administrator',
        'firebase': {'sign_in_second_factor': 'phone'},
      };
      expect(
        marketplaceAdministratorClaimsState(claims),
        MarketplaceAdministratorState.authorized,
      );
      expect(marketplaceAdministratorClaims(claims), isTrue);
    });

    test('email and public profile fields cannot grant administrator UI', () {
      expect(
        marketplaceAdministratorClaims({
          'email': 'administrator@example.com',
          'email_verified': true,
          'isAdmin': true,
        }),
        isFalse,
      );
    });
  });
}
