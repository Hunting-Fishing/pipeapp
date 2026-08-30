import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_command_client.dart';

void main() {
  test('command client construction does not require initialized Firebase', () {
    expect(() => MarketplaceCommandClient(), returnsNormally);
  });

  test('command errors retain short actionable server messages', () {
    expect(
      marketplaceCommandErrorMessage(
        StateError('Your session expired. Sign in and try again.'),
      ),
      'Your session expired. Sign in and try again.',
    );
  });

  test('raw Firebase internals never reach transaction feedback', () {
    expect(
      marketplaceCommandErrorMessage(
        StateError('FIRESTORE internal assertion at gstatic/firebasejs #12'),
      ),
      'The marketplace action could not be completed. Try again.',
    );
  });

  test('unknown exceptions use the controlled fallback', () {
    expect(
      marketplaceCommandErrorMessage(Exception('private implementation')),
      'The marketplace action could not be completed. Try again.',
    );
  });
}
