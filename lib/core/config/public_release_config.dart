class PublicReleaseConfiguration {
  const PublicReleaseConfiguration({
    required this.environment,
    required this.supportEmail,
  });

  static const current = PublicReleaseConfiguration(
    environment: String.fromEnvironment(
      'PIPE_ENV',
      defaultValue: 'development',
    ),
    supportEmail: String.fromEnvironment(
      'PIPE_PUBLIC_SUPPORT_EMAIL',
      defaultValue: 'support@pipebuyer.com',
    ),
  );

  static const appVersion = '1.0.0+1';
  static const releaseSha = String.fromEnvironment('PIPE_RELEASE_SHA', defaultValue: 'dev');

  static String get formattedReleaseLabel {
    final env = current.environment.isNotEmpty ? current.environment : 'development';
    final shaLabel = releaseSha.isNotEmpty && releaseSha != 'dev'
        ? ' (${releaseSha.length >= 7 ? releaseSha.substring(0, 7) : releaseSha})'
        : '';
    return 'v$appVersion • $env$shaLabel';
  }

  final String environment;
  final String supportEmail;

  String get normalizedEnvironment => environment.trim().toLowerCase();


  String get normalizedSupportEmail => supportEmail.trim().toLowerCase();

  bool get isControlledRelease =>
      normalizedEnvironment == 'staging' ||
      normalizedEnvironment == 'production';

  bool get hasValidSupportEmail =>
      isValidPublicSupportEmail(normalizedSupportEmail);

  Uri? get supportMailto => hasValidSupportEmail
      ? Uri(
          scheme: 'mailto',
          path: normalizedSupportEmail,
          queryParameters: const {
            'subject': 'Pipe Buyer support request',
          },
        )
      : null;

  void validate() {
    if (isControlledRelease && !hasValidSupportEmail) {
      throw StateError(
        'PIPE_PUBLIC_SUPPORT_EMAIL must be a valid public support address for '
        '$normalizedEnvironment releases.',
      );
    }
  }

  static bool isValidPublicSupportEmail(String value) {
    final candidate = value.trim().toLowerCase();
    if (candidate.isEmpty ||
        candidate.length > 254 ||
        candidate.contains(' ')) {
      return false;
    }
    final separator = candidate.indexOf('@');
    if (separator <= 0 || separator != candidate.lastIndexOf('@')) return false;
    final local = candidate.substring(0, separator);
    final domain = candidate.substring(separator + 1);
    if (local.length > 64 ||
        local.startsWith('.') ||
        local.endsWith('.') ||
        local.contains('..') ||
        domain.length < 3 ||
        domain.startsWith('.') ||
        domain.endsWith('.') ||
        !domain.contains('.')) {
      return false;
    }
    final localPattern = RegExp(r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+$");
    final domainPattern = RegExp(r'^[a-z0-9-]+(?:\.[a-z0-9-]+)+$');
    return localPattern.hasMatch(local) &&
        domainPattern.hasMatch(domain) &&
        !domain.split('.').any(
              (label) => label.startsWith('-') || label.endsWith('-'),
            );
  }
}
