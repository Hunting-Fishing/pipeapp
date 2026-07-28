import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/config/public_release_config.dart';

void main() {
  test('controlled releases require a professional public support address', () {
    const missing = PublicReleaseConfiguration(
      environment: 'production',
      supportEmail: '',
    );
    const malformed = PublicReleaseConfiguration(
      environment: 'staging',
      supportEmail: 'support at pipebuyer.com',
    );
    expect(missing.validate, throwsStateError);
    expect(malformed.validate, throwsStateError);
  });

  test('development stays usable without claiming release readiness', () {
    const configuration = PublicReleaseConfiguration(
      environment: 'development',
      supportEmail: '',
    );
    expect(configuration.validate, returnsNormally);
    expect(configuration.hasValidSupportEmail, isFalse);
    expect(configuration.supportMailto, isNull);
  });

  test('support address is normalized and produces a safe mail link', () {
    const configuration = PublicReleaseConfiguration(
      environment: 'production',
      supportEmail: ' Support@PipeBuyer.com ',
    );
    expect(configuration.validate, returnsNormally);
    expect(configuration.normalizedSupportEmail, 'support@pipebuyer.com');
    expect(configuration.supportMailto?.scheme, 'mailto');
    expect(configuration.supportMailto?.path, 'support@pipebuyer.com');
  });

  test('support email validation rejects unsafe or malformed domains', () {
    for (final value in <String>[
      'user@example',
      'user@@example.com',
      '.user@example.com',
      'user..name@example.com',
      'user@-example.com',
      'user@example-.com',
    ]) {
      expect(
        PublicReleaseConfiguration.isValidPublicSupportEmail(value),
        isFalse,
        reason: value,
      );
    }
  });
}
