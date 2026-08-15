import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();

function full(rel) {
  return path.join(root, rel);
}

function load(rel) {
  return fs.readFileSync(full(rel), 'utf8').replace(/\r\n/g, '\n');
}

function save(rel, text) {
  fs.writeFileSync(full(rel), text, 'utf8');
}

function replaceOnce(rel, before, after, label) {
  let text = load(rel);
  if (text.includes(after)) {
    console.log(`already applied: ${label}`);
    return;
  }
  const index = text.indexOf(before);
  if (index < 0) {
    throw new Error(`Patch anchor not found for ${label} in ${rel}`);
  }
  text = text.slice(0, index) + after + text.slice(index + before.length);
  save(rel, text);
  console.log(`patched: ${label}`);
}

function writeIfDifferent(rel, content, label) {
  const normalized = content.replace(/\r\n/g, '\n');
  if (fs.existsSync(full(rel)) && load(rel) === normalized) {
    console.log(`already current: ${label}`);
    return;
  }
  fs.mkdirSync(path.dirname(full(rel)), {recursive: true});
  save(rel, normalized);
  console.log(`wrote: ${label}`);
}

writeIfDifferent(
  'lib/marketplace/marketplace_trust_readiness.dart',
  `class MarketplaceTrustReadiness {
  const MarketplaceTrustReadiness({
    required this.emailVerified,
    required this.phoneVerified,
    required this.mfaEnrolled,
  });

  static const int emailOwnershipPoints = 40;
  static const int phoneOwnershipPoints = 40;
  static const int twoStepPoints = 20;
  static const int totalPoints =
      emailOwnershipPoints + phoneOwnershipPoints + twoStepPoints;

  final bool emailVerified;
  final bool phoneVerified;
  final bool mfaEnrolled;

  bool get marketplaceAccessReady => emailVerified || phoneVerified;

  int get score =>
      (emailVerified ? emailOwnershipPoints : 0) +
      (phoneVerified ? phoneOwnershipPoints : 0) +
      (mfaEnrolled ? twoStepPoints : 0);

  int get missingPoints => totalPoints - score;
}
`,
  'central trust-readiness model',
);

writeIfDifferent(
  'test/marketplace_trust_readiness_test.dart',
  `import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_trust_readiness.dart';

void main() {
  group('MarketplaceTrustReadiness', () {
    test('email verification alone unlocks marketplace access at 40 points', () {
      const readiness = MarketplaceTrustReadiness(
        emailVerified: true,
        phoneVerified: false,
        mfaEnrolled: false,
      );
      expect(readiness.marketplaceAccessReady, isTrue);
      expect(readiness.score, 40);
      expect(readiness.missingPoints, 60);
    });

    test('phone verification alone unlocks marketplace access at 40 points', () {
      const readiness = MarketplaceTrustReadiness(
        emailVerified: false,
        phoneVerified: true,
        mfaEnrolled: false,
      );
      expect(readiness.marketplaceAccessReady, isTrue);
      expect(readiness.score, 40);
    });

    test('unverified accounts remain blocked from marketplace access', () {
      const readiness = MarketplaceTrustReadiness(
        emailVerified: false,
        phoneVerified: false,
        mfaEnrolled: false,
      );
      expect(readiness.marketplaceAccessReady, isFalse);
      expect(readiness.score, 0);
    });

    test('email and phone total 80 and MFA completes 100', () {
      const withoutMfa = MarketplaceTrustReadiness(
        emailVerified: true,
        phoneVerified: true,
        mfaEnrolled: false,
      );
      const complete = MarketplaceTrustReadiness(
        emailVerified: true,
        phoneVerified: true,
        mfaEnrolled: true,
      );
      expect(withoutMfa.score, 80);
      expect(complete.score, MarketplaceTrustReadiness.totalPoints);
      expect(complete.missingPoints, 0);
    });
  });
}
`,
  'trust-readiness regression tests',
);

replaceOnce(
  'lib/marketplace/marketplace_command_client.dart',
  `  if (message.isEmpty ||
      message.length > 220 ||
      RegExp(r'(FIRESTORE|firebasejs|gstatic|stack trace|#\\d+)',
              caseSensitive: false)
          .hasMatch(message)) {`,
  `  if (message.isEmpty ||
      message.length > 220 ||
      RegExp(r'^(internal|unknown|error)$', caseSensitive: false)
          .hasMatch(message) ||
      RegExp(r'(FIRESTORE|firebasejs|gstatic|stack trace|#\\d+)',
              caseSensitive: false)
          .hasMatch(message)) {`,
  'generic backend error codes are never shown to users',
);

replaceOnce(
  'lib/marketplace/marketplace_command_client.dart',
  `      throw StateError(
        error.message?.trim().isNotEmpty == true ? error.message! : fallback,
      );`,
  `      final serverMessage = error.message?.trim() ?? '';
      final normalizedMessage = serverMessage.toLowerCase();
      final normalizedCode = error.code.toLowerCase();
      final exposeServerMessage = error.code != 'internal' &&
          serverMessage.isNotEmpty &&
          normalizedMessage != normalizedCode &&
          normalizedMessage != 'internal' &&
          normalizedMessage != 'unknown';
      throw StateError(exposeServerMessage ? serverMessage : fallback);`,
  'Firebase Functions internal codes use friendly fallback copy',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  `      if (normalizePhoneNumber(user.phoneNumber ?? '').isEmpty) {`,
  `      final googlePhoneVerified =
          normalizePhoneNumber(user.phoneNumber ?? '').isNotEmpty;
      if (!user.emailVerified && !googlePhoneVerified) {`,
  'Google sign-in only gates when neither ownership method is verified',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  `        if (!user.emailVerified ||
            normalizePhoneNumber(user.phoneNumber ?? '').isEmpty) {`,
  `        final phoneVerified =
            normalizePhoneNumber(user.phoneNumber ?? '').isNotEmpty;
        if (!user.emailVerified && !phoneVerified) {`,
  'email/password sign-in only gates when neither ownership method is verified',
);

{
  const rel = 'lib/marketplace/marketplace_auth_page.dart';
  let text = load(rel);
  if (!text.includes('Future<void> _syncVerificationBestEffort() async')) {
    const marker = `  Future<void> _startAccountRecovery() async {`;
    const helper = `  Future<void> _syncVerificationBestEffort() async {
    try {
      await MarketplaceCommandClient().execute(
        'syncAccountVerification',
        const {},
        timeout: const Duration(seconds: 6),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Account verification sync deferred: $error');
      }
    }
  }

`;
    const index = text.indexOf(marker);
    if (index < 0) throw new Error(`Patch anchor not found for auth sync helper in ${rel}`);
    text = text.slice(0, index) + helper + text.slice(index);
  }
  const syncPattern = /([ \t]*)await MarketplaceCommandClient\(\)\n[ \t]*\.execute\('syncAccountVerification', const \{\}\);/g;
  let replacements = 0;
  text = text.replace(syncPattern, (_, indent) => {
    replacements += 1;
    return `${indent}await _syncVerificationBestEffort();`;
  });
  if (replacements === 0 && !text.includes('await _syncVerificationBestEffort();')) {
    throw new Error(`Account verification sync call anchors not found in ${rel}`);
  }
  save(rel, text);
  console.log(`patched: auth sync is best-effort (${replacements} call(s) updated)`);
}

replaceOnce(
  'lib/marketplace/marketplace_account_security_page.dart',
  `import 'marketplace_profile_page.dart';\nimport 'regional_phone_field.dart';`,
  `import 'marketplace_profile_page.dart';\nimport 'marketplace_trust_readiness.dart';\nimport 'regional_phone_field.dart';`,
  'trust-readiness model import',
);

replaceOnce(
  'lib/marketplace/marketplace_account_security_page.dart',
  `  final _commands = MarketplaceCommandClient();\n  String _phone = '';`,
  `  final _commands = MarketplaceCommandClient();
  final _readinessKey = GlobalKey();
  final _identityKey = GlobalKey();
  final _advancedSecurityKey = GlobalKey();
  String _phone = '';`,
  'actionable section anchors',
);

replaceOnce(
  'lib/marketplace/marketplace_account_security_page.dart',
  `  bool get _mfaSupported =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.windows;
  int get _trustScore =>
      (_emailVerified ? 40 : 0) + (_phoneVerified ? 40 : 0) + (_mfaEnrolled ? 20 : 0);`,
  `  bool get _mfaSupported =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.windows;
  MarketplaceTrustReadiness get _readiness => MarketplaceTrustReadiness(
        emailVerified: _emailVerified,
        phoneVerified: _phoneVerified,
        mfaEnrolled: _mfaEnrolled,
      );
  bool get _marketplaceAccessReady => _readiness.marketplaceAccessReady;
  int get _trustScore => _readiness.score;`,
  'centralized trust readiness calculation',
);

replaceOnce(
  'lib/marketplace/marketplace_account_security_page.dart',
  `    final allCoreVerified = _emailVerified && _phoneVerified;`,
  `    final marketplaceAccessReady = _marketplaceAccessReady;`,
  'marketplace access readiness state',
);

replaceOnce(
  'lib/marketplace/marketplace_account_security_page.dart',
  `                  subtitle:
                      'Verified ownership protects listings, offers, timed auctions, Dispatch jobs and protected marketplace actions.',
                  icon: Icons.verified_user_outlined,
                  actions: [
                    PipeBuyerStatusBadge(
                      label: allCoreVerified ? 'IDENTITY READY' : 'ACTION NEEDED',
                      tone: allCoreVerified
                          ? PipeBuyerStatusTone.success
                          : PipeBuyerStatusTone.warning,
                      icon: allCoreVerified
                          ? Icons.verified_rounded
                          : Icons.pending_actions_rounded,
                    ),
                  ],`,
  `                  subtitle:
                      'Verify either your email or mobile number to enter Pipe Buyer. Additional verification increases account protection and unlocks sensitive security features.',
                  icon: Icons.verified_user_outlined,
                  actions: [
                    PipeBuyerStatusBadge(
                      label: marketplaceAccessReady
                          ? 'MARKETPLACE ACCESS READY'
                          : 'VERIFY EMAIL OR MOBILE',
                      tone: marketplaceAccessReady
                          ? PipeBuyerStatusTone.success
                          : PipeBuyerStatusTone.warning,
                      icon: marketplaceAccessReady
                          ? Icons.verified_rounded
                          : Icons.pending_actions_rounded,
                    ),
                  ],`,
  'clear marketplace access rule in page header',
);

replaceOnce(
  'lib/marketplace/marketplace_account_security_page.dart',
  `                    PipeBuyerMetricCard(
                      label: 'Trust readiness',
                      value: '$_trustScore%',
                      icon: Icons.security_rounded,
                      caption: _trustScore == 100
                          ? 'Core security complete'
                          : 'Complete the steps below',
                      tone: _trustScore == 100
                          ? PipeBuyerStatusTone.success
                          : PipeBuyerStatusTone.premium,
                    ),`,
  `                    PipeBuyerMetricCard(
                      label: 'Trust readiness',
                      value: '$_trustScore / 100',
                      icon: Icons.security_rounded,
                      caption: _trustScore == 100
                          ? 'All protection points earned'
                          : '${_readiness.missingPoints} points available • Tap for breakdown',
                      tone: _trustScore == 100
                          ? PipeBuyerStatusTone.success
                          : PipeBuyerStatusTone.premium,
                      onTap: () => _scrollTo(_readinessKey),
                    ),`,
  'actionable trust readiness metric',
);

replaceOnce(
  'lib/marketplace/marketplace_account_security_page.dart',
  `                    PipeBuyerMetricCard(
                      label: 'Email ownership',
                      value: _emailVerified ? 'Verified' : 'Pending',
                      icon: Icons.mark_email_read_outlined,
                      tone: _emailVerified
                          ? PipeBuyerStatusTone.success
                          : PipeBuyerStatusTone.warning,
                    ),`,
  `                    PipeBuyerMetricCard(
                      label: 'Email ownership',
                      value: _emailVerified ? 'Verified' : 'Pending',
                      icon: Icons.mark_email_read_outlined,
                      caption: _emailVerified ? '+40 points earned' : '+40 points available',
                      tone: _emailVerified
                          ? PipeBuyerStatusTone.success
                          : PipeBuyerStatusTone.warning,
                      onTap: () => _scrollTo(_identityKey),
                    ),`,
  'actionable email metric',
);

replaceOnce(
  'lib/marketplace/marketplace_account_security_page.dart',
  `                    PipeBuyerMetricCard(
                      label: 'Mobile ownership',
                      value: _phoneVerified ? 'Verified' : 'Pending',
                      icon: Icons.phone_android_outlined,
                      tone: _phoneVerified
                          ? PipeBuyerStatusTone.success
                          : PipeBuyerStatusTone.warning,
                    ),`,
  `                    PipeBuyerMetricCard(
                      label: 'Mobile ownership',
                      value: _phoneVerified ? 'Verified' : 'Pending',
                      icon: Icons.phone_android_outlined,
                      caption: _phoneVerified ? '+40 points earned' : '+40 points available',
                      tone: _phoneVerified
                          ? PipeBuyerStatusTone.success
                          : PipeBuyerStatusTone.warning,
                      onTap: () => _scrollTo(_identityKey),
                    ),`,
  'actionable mobile metric',
);

replaceOnce(
  'lib/marketplace/marketplace_account_security_page.dart',
  `                    PipeBuyerMetricCard(
                      label: 'Two-step security',
                      value: _mfaEnrolled ? 'Enabled' : 'Optional',
                      icon: Icons.phonelink_lock_outlined,
                      tone: _mfaEnrolled
                          ? PipeBuyerStatusTone.success
                          : PipeBuyerStatusTone.info,
                    ),`,
  `                    PipeBuyerMetricCard(
                      label: 'Two-step security',
                      value: _mfaEnrolled ? 'Enabled' : 'Optional',
                      icon: Icons.phonelink_lock_outlined,
                      caption: _mfaEnrolled ? '+20 points earned' : '+20 optional protection points',
                      tone: _mfaEnrolled
                          ? PipeBuyerStatusTone.success
                          : PipeBuyerStatusTone.info,
                      onTap: () => _scrollTo(_advancedSecurityKey),
                    ),`,
  'actionable MFA metric',
);

replaceOnce(
  'lib/marketplace/marketplace_account_security_page.dart',
  `                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final identity = _identitySection(user);
                    final advanced = _advancedSecuritySection();`,
  `                  ],
                ),
                const SizedBox(height: 14),
                _trustReadinessExplanation(),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final identity = KeyedSubtree(
                      key: _identityKey,
                      child: _identitySection(user),
                    );
                    final advanced = KeyedSubtree(
                      key: _advancedSecurityKey,
                      child: _advancedSecuritySection(),
                    );`,
  'readiness breakdown and scroll targets',
);

replaceOnce(
  'lib/marketplace/marketplace_account_security_page.dart',
  `                if (widget.onboarding) ...[
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: (_emailVerified || _phoneVerified) && !_busy
                        ? _continueToProfile
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Continue to your profile'),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _busy ? null : _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out and finish later'),
                  ),
                ],`,
  `                if (widget.onboarding) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (_marketplaceAccessReady
                              ? PipeBuyerColors.success
                              : PipeBuyerColors.warning)
                          .withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (_marketplaceAccessReady
                                ? PipeBuyerColors.success
                                : PipeBuyerColors.warning)
                            .withValues(alpha: .24),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _marketplaceAccessReady
                              ? Icons.lock_open_rounded
                              : Icons.lock_clock_outlined,
                          color: _marketplaceAccessReady
                              ? PipeBuyerColors.success
                              : PipeBuyerColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _marketplaceAccessReady
                                ? 'Marketplace access is unlocked because ${_emailVerified ? 'email' : 'mobile'} ownership is verified. You can finish the remaining trust steps later.'
                                : 'Verify either your email or mobile number to enter Pipe Buyer.',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _marketplaceAccessReady && !_busy
                        ? _continueToProfile
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Continue to your profile'),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _marketplaceAccessReady && !_busy
                            ? _skipForNow
                            : null,
                        icon: const Icon(Icons.skip_next_rounded),
                        label: const Text('Skip for now'),
                      ),
                      TextButton.icon(
                        onPressed: _busy ? null : _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out and finish later'),
                      ),
                    ],
                  ),
                ],`,
  'skip-for-now onboarding controls',
);

{
  const rel = 'lib/marketplace/marketplace_account_security_page.dart';
  let text = load(rel);
  if (!text.includes('Widget _trustReadinessExplanation()')) {
    const marker = `  Widget _identitySection(User user) => PipeBuyerSectionCard(`;
    const methods = `  Widget _trustReadinessExplanation() => KeyedSubtree(
        key: _readinessKey,
        child: PipeBuyerSectionCard(
          title: 'How Trust Readiness works',
          subtitle:
              'Trust Readiness is a 100-point account-protection score. It does not block marketplace access once either email or mobile ownership is verified.',
          trailing: PipeBuyerStatusBadge(
            label: '$_trustScore / ${MarketplaceTrustReadiness.totalPoints}',
            tone: _trustScore == MarketplaceTrustReadiness.totalPoints
                ? PipeBuyerStatusTone.success
                : PipeBuyerStatusTone.premium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _trustScore / MarketplaceTrustReadiness.totalPoints,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 14),
              _readinessRow(
                icon: Icons.mark_email_read_outlined,
                title: 'Email ownership',
                points: MarketplaceTrustReadiness.emailOwnershipPoints,
                complete: _emailVerified,
                note: _emailVerified
                    ? 'Verified — marketplace access requirement satisfied.'
                    : 'Verify your email to unlock marketplace access.',
                onTap: () => _scrollTo(_identityKey),
              ),
              const Divider(height: 18),
              _readinessRow(
                icon: Icons.phone_android_outlined,
                title: 'Mobile ownership',
                points: MarketplaceTrustReadiness.phoneOwnershipPoints,
                complete: _phoneVerified,
                note: _phoneVerified
                    ? 'Verified — marketplace access requirement satisfied.'
                    : 'Optional for entry if email is verified; adds stronger ownership proof.',
                onTap: () => _scrollTo(_identityKey),
              ),
              const Divider(height: 18),
              _readinessRow(
                icon: Icons.phonelink_lock_outlined,
                title: 'Two-step security',
                points: MarketplaceTrustReadiness.twoStepPoints,
                complete: _mfaEnrolled,
                note: _mfaEnrolled
                    ? 'Enabled for stronger sensitive-action protection.'
                    : 'Optional for standard marketplace access; required for administrator access.',
                onTap: () => _scrollTo(_advancedSecurityKey),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_marketplaceAccessReady
                          ? PipeBuyerColors.success
                          : PipeBuyerColors.warning)
                      .withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _marketplaceAccessReady
                          ? Icons.check_circle_outline_rounded
                          : Icons.info_outline_rounded,
                      color: _marketplaceAccessReady
                          ? PipeBuyerColors.success
                          : PipeBuyerColors.warning,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _marketplaceAccessReady
                            ? 'Marketplace access: READY. Complete the remaining ${_readiness.missingPoints} points when convenient.'
                            : 'Marketplace access: LOCKED. Verify either email or mobile ownership first.',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _readinessRow({
    required IconData icon,
    required String title,
    required int points,
    required bool complete,
    required String note,
    required VoidCallback onTap,
  }) {
    final accent = complete ? PipeBuyerColors.success : PipeBuyerColors.orange;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(complete ? Icons.check_circle_rounded : icon,
                color: accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        complete ? '+$points earned' : '+$points available',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(note),
                  const SizedBox(height: 4),
                  Text(
                    complete ? 'Review' : 'Go to this step',
                    style: const TextStyle(
                      color: PipeBuyerColors.industrialBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: .08,
    );
  }

`;
    const index = text.indexOf(marker);
    if (index < 0) throw new Error(`Patch anchor not found for readiness methods in ${rel}`);
    text = text.slice(0, index) + methods + text.slice(index);
    save(rel, text);
    console.log('patched: trust-readiness breakdown UI');
  } else {
    console.log('already applied: trust-readiness breakdown UI');
  }
}

replaceOnce(
  'lib/marketplace/marketplace_account_security_page.dart',
  `  Future<void> _continueToProfile() async {
    await _run(() async {
      await _syncVerification();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => MarketplaceProfilePage(
          onboarding: true,
          initialAccountType: widget.initialAccountType,
        ),
      ));
    });
  }`,
  `  Future<void> _syncVerificationBestEffort() async {
    try {
      await _commands.execute(
        'syncAccountVerification',
        const {},
        timeout: const Duration(seconds: 6),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Account verification sync deferred: $error');
      }
    }
  }

  Future<void> _continueToProfile() async {
    if (!_marketplaceAccessReady) {
      return _notice('Verify either your email or mobile number first.',
          error: true);
    }
    await _run(() async {
      await _syncVerificationBestEffort();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => MarketplaceProfilePage(
          onboarding: true,
          initialAccountType: widget.initialAccountType,
        ),
      ));
    });
  }

  Future<void> _skipForNow() async {
    if (!_marketplaceAccessReady) {
      return _notice('Verify either your email or mobile number first.',
          error: true);
    }
    await _syncVerificationBestEffort();
    if (mounted) Navigator.of(context).pop(true);
  }`,
  'non-blocking continue and skip-for-now behavior',
);

replaceOnce(
  'lib/marketplace/marketplace_account_security_page.dart',
  `    } catch (error) {
      _notice(
          error is StateError
              ? error.message
              : 'Account verification could not be completed. Try again.',
          error: true);
    } finally {`,
  `    } catch (error) {
      _notice(
        marketplaceCommandErrorMessage(
          error,
          fallback:
              'Account verification could not sync right now. If your email or mobile is verified, you can still continue and try the remaining security steps later.',
        ),
        error: true,
      );
    } finally {`,
  'friendly account verification error handling',
);

console.log('Trust onboarding repair applied.');
