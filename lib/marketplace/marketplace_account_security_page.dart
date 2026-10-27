import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_auth_action_page.dart';
import 'marketplace_command_client.dart';
import 'marketplace_payout_settings.dart';
import 'marketplace_profile_page.dart';
import 'marketplace_trust_readiness.dart';
import 'regional_phone_field.dart';

class MarketplaceAccountSecurityPage extends StatefulWidget {
  const MarketplaceAccountSecurityPage({
    super.key,
    this.onboarding = false,
    this.embedded = false,
    this.initialPhone,
    this.initialAccountType = 'personal',
    this.initialNotice,
  });

  final bool onboarding;
  final bool embedded;
  final String? initialPhone;
  final String initialAccountType;
  final String? initialNotice;

  @override
  State<MarketplaceAccountSecurityPage> createState() =>
      _MarketplaceAccountSecurityPageState();
}

class _MarketplaceAccountSecurityPageState
    extends State<MarketplaceAccountSecurityPage> with WidgetsBindingObserver {
  final _code = TextEditingController();
  final _mfaCode = TextEditingController();
  final _commands = MarketplaceCommandClient();
  String _phone = '';
  String? _verificationId;
  String? _mfaVerificationId;
  ConfirmationResult? _webConfirmation;
  bool _busy = false;
  bool _silentChecking = false;
  bool _codeSent = false;
  bool _mfaCodeSent = false;
  List<MultiFactorInfo> _enrolledFactors = const [];
  String? _message;
  bool _error = false;
  Timer? _emailPollTimer;
  StreamSubscription<User?>? _authSubscription;

  User? get _user => FirebaseAuth.instance.currentUser;
  bool get _emailVerified => _user?.emailVerified == true;
  bool get _phoneVerified =>
      normalizePhoneNumber(_user?.phoneNumber ?? '').isNotEmpty;
  bool get _mfaEnrolled =>
      _enrolledFactors.any((factor) => factor is PhoneMultiFactorInfo);
  bool get _mfaSupported =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.windows;
  MarketplaceTrustReadiness get _readiness => MarketplaceTrustReadiness(
        emailVerified: _emailVerified,
        phoneVerified: _phoneVerified,
        mfaEnrolled: _mfaEnrolled,
      );
  int get _trustScore => _readiness.score;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _phone = normalizePhoneNumber(widget.initialPhone ?? '');
    _message = widget.initialNotice;
    _loadPendingPhone();
    _loadMfaFactors();
    _configureEmailPolling();
    _authSubscription = FirebaseAuth.instance.userChanges().listen((_) {
      if (!mounted) return;
      _configureEmailPolling();
      setState(() {});
    });
    if (!_emailVerified) {
      unawaited(_silentCheckEmailVerified());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailPollTimer?.cancel();
    _authSubscription?.cancel();
    _code.dispose();
    _mfaCode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_emailVerified) {
      unawaited(_silentCheckEmailVerified());
    }
  }

  void _configureEmailPolling() {
    if (_emailVerified || _user == null) {
      _emailPollTimer?.cancel();
      _emailPollTimer = null;
      return;
    }
    _emailPollTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_silentCheckEmailVerified()),
    );
  }

  Future<void> _silentCheckEmailVerified() async {
    if (_silentChecking || _busy || !mounted) return;
    final user = _user;
    if (user == null || user.emailVerified) {
      _configureEmailPolling();
      return;
    }
    _silentChecking = true;
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed?.emailVerified == true) {
        _configureEmailPolling();
        await refreshed?.getIdToken(true);
        await _syncVerificationBestEffort();
        if (!mounted) return;
        _notice('Email ownership verified.');
      }
    } catch (_) {
      // Ignore transient network errors during background checks.
    } finally {
      _silentChecking = false;
    }
  }

  Future<void> _loadPendingPhone() async {
    final user = _user;
    if (user == null || _phone.isNotEmpty) return;
    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final pending =
          normalizePhoneNumber('${profile.data()?['pendingPhoneE164'] ?? ''}');
      if (mounted && pending.isNotEmpty) setState(() => _phone = pending);
    } catch (_) {}
  }

  Future<void> _loadMfaFactors() async {
    final user = _user;
    if (user == null || !_mfaSupported) return;
    try {
      final factors = await user.multiFactor.getEnrolledFactors();
      if (mounted) setState(() => _enrolledFactors = factors);
    } on FirebaseAuthException catch (error) {
      if (mounted) _notice(_friendlyPhoneError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      const signedOutBody = Center(child: Text('Sign in to continue.'));
      if (widget.embedded) return signedOutBody;
      return const Scaffold(body: signedOutBody);
    }

    final content = Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1020),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _summaryHeader(),
              if (_message != null) ...[
                const SizedBox(height: 14),
                PipeBuyerSectionCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _error
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: _error
                            ? PipeBuyerColors.danger
                            : PipeBuyerColors.success,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_message!)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final identity = _identitySection(user);
                  final rightColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _advancedSecuritySection(),
                      const SizedBox(height: 14),
                      _payoutsCard(),
                    ],
                  );
                  if (constraints.maxWidth < 820) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        const SizedBox(height: 14),
                        rightColumn,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 14),
                      Expanded(child: rightColumn),
                    ],
                  );
                },
              ),
              if (widget.onboarding) ...[
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _skipForNow,
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('Explore Pipe Buyer'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _continueToProfile,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Edit profile'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification & Security'),
      ),
      body: content,
    );
  }

  Widget _summaryHeader() {
    final allCoreVerified = _emailVerified && _phoneVerified;
    final badgeLabel = _trustScore == MarketplaceTrustReadiness.totalPoints
        ? 'FULLY PROTECTED'
        : allCoreVerified
            ? 'EMAIL & MOBILE VERIFIED'
            : _emailVerified
                ? 'EMAIL VERIFIED'
                : _phoneVerified
                    ? 'MOBILE VERIFIED'
                    : 'OPTIONAL SETUP';
    final badgeTone = allCoreVerified || _emailVerified || _phoneVerified
        ? PipeBuyerStatusTone.success
        : PipeBuyerStatusTone.info;

    return PipeBuyerSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.orangeSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: PipeBuyerColors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification & Security',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Confirm your email and mobile number at your own pace to strengthen buyer trust and protect account recovery.',
                          style: TextStyle(
                            fontSize: 13,
                            color: PipeBuyerColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              PipeBuyerStatusBadge(
                label: badgeLabel,
                tone: badgeTone,
                icon: (_emailVerified || _phoneVerified)
                    ? Icons.verified_rounded
                    : Icons.shield_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _trustScore / MarketplaceTrustReadiness.totalPoints,
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusSummaryChip(
                icon: Icons.mark_email_read_outlined,
                label: _emailVerified ? 'Email verified' : 'Email unverified',
                complete: _emailVerified,
              ),
              _StatusSummaryChip(
                icon: Icons.phone_android_outlined,
                label: _phoneVerified
                    ? 'Mobile verified'
                    : 'Mobile optional',
                complete: _phoneVerified,
              ),
              _StatusSummaryChip(
                icon: Icons.phonelink_lock_outlined,
                label: _mfaEnrolled ? '2-step SMS on' : '2-step SMS optional',
                complete: _mfaEnrolled,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _identitySection(User user) => PipeBuyerSectionCard(
        title: 'Contact verification',
        subtitle:
            'Confirm the email address and optional mobile phone connected to your account.',
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: PipeBuyerColors.orangeSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              const Icon(Icons.badge_outlined, color: PipeBuyerColors.orange),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VerificationCard(
              icon: Icons.mark_email_read_outlined,
              title: 'Email address',
              value: user.email ?? 'No email available',
              verified: _emailVerified,
              pendingLabel: 'UNVERIFIED',
              actionLabel:
                  _emailVerified ? null : 'Resend verification email',
              onAction: _emailVerified || _busy ? null : _resendEmail,
            ),
            if (!_emailVerified) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _refreshEmail,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh email status'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Click the link in your email to verify automatically — this status updates as soon as you return.',
                style: TextStyle(fontSize: 12, color: PipeBuyerColors.muted),
              ),
            ],
            const SizedBox(height: 14),
            _VerificationCard(
              icon: Icons.phone_android_outlined,
              title: 'Mobile phone (optional)',
              value: _phoneVerified
                  ? formatPhoneNumber(user.phoneNumber ?? '')
                  : 'Add an SMS-verified number for stronger trust and account recovery',
              verified: _phoneVerified,
              pendingLabel: 'OPTIONAL',
            ),
            if (!_phoneVerified) ...[
              const SizedBox(height: 10),
              RegionalPhoneField(
                key: ValueKey(_phone),
                label: 'Mobile phone number (optional)',
                initialValue: _phone,
                required: false,
                onChanged: (value) => _phone = normalizePhoneNumber(value),
              ),
              const SizedBox(height: 9),
              if (!_codeSent)
                FilledButton.icon(
                  onPressed: _busy ? null : _sendPhoneCode,
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(_busy ? 'Sending…' : 'Send SMS verification code'),
                )
              else ...[
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: const InputDecoration(
                    labelText: '6-digit SMS code',
                    prefixIcon: Icon(Icons.password_outlined),
                  ),
                ),
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _sendPhoneCode,
                      child: const Text('New code'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _confirmPhoneCode,
                      child: Text(_busy ? 'Checking…' : 'Verify phone'),
                    ),
                  ),
                ]),
              ],
            ],
          ],
        ),
      );

  Widget _advancedSecuritySection() => PipeBuyerSectionCard(
        title: 'Two-step sign-in security',
        subtitle:
            'Optional SMS verification when signing in from a new device.',
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: PipeBuyerColors.orangeSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.phonelink_lock_outlined,
            color: PipeBuyerColors.orange,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VerificationCard(
              icon: Icons.phonelink_lock_outlined,
              title: 'Two-step verification (SMS)',
              value: !_mfaSupported
                  ? 'Available on web, iOS, and Android.'
                  : _mfaEnrolled
                      ? '${_enrolledFactors.length} second factor${_enrolledFactors.length == 1 ? '' : 's'} enrolled'
                      : 'Protect your account with a one-time text code at sign-in.',
              verified: _mfaEnrolled,
              pendingLabel: 'OPTIONAL',
            ),
            if (_mfaSupported && !_mfaEnrolled) ...[
              const SizedBox(height: 10),
              if (!_emailVerified || !_phoneVerified)
                const Text(
                  'Verify your email address and mobile phone first to turn on two-step SMS sign-in.',
                  style: TextStyle(fontSize: 12.5, color: PipeBuyerColors.muted),
                )
              else if (!_mfaCodeSent)
                FilledButton.icon(
                  onPressed: _busy ? null : _sendMfaEnrollmentCode,
                  icon: const Icon(Icons.phonelink_lock_outlined),
                  label: Text(_busy
                      ? 'Preparing…'
                      : 'Enable SMS two-step verification'),
                )
              else ...[
                TextField(
                  controller: _mfaCode,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '6-digit MFA enrollment code',
                    prefixIcon: Icon(Icons.password_outlined),
                  ),
                ),
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _sendMfaEnrollmentCode,
                      child: const Text('New code'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _confirmMfaEnrollmentCode,
                      child: Text(_busy ? 'Enrolling…' : 'Enable two-step'),
                    ),
                  ),
                ]),
              ],
            ],
          ],
        ),
      );

  Widget _payoutsCard() => PipeBuyerSectionCard(
        title: 'Seller payouts',
        subtitle:
            'Selling equipment with online checkout? Connect Stripe payouts whenever you are ready.',
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: PipeBuyerColors.orangeSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.account_balance_outlined,
            color: PipeBuyerColors.orange,
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MarketplacePayoutSettingsPage(),
              ),
            ),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Manage Seller Payouts'),
          ),
        ),
      );

  Future<void> _resendEmail() async {
    await _run(() async {
      await _user!.sendEmailVerification(
        marketplaceEmailActionCodeSettings(),
      );
      _notice('Verification email sent. Check your inbox and spam folder.');
    });
  }

  Future<void> _refreshEmail() async {
    await _run(() async {
      await _user!.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (FirebaseAuth.instance.currentUser?.emailVerified != true) {
        _notice(
            'Your email is not verified yet. Click the link in your email, and this page will update automatically.',
            error: true);
        return;
      }
      _configureEmailPolling();
      await _syncVerificationBestEffort();
      _notice('Email ownership verified.');
      if (mounted) setState(() {});
    });
  }

  Future<void> _sendPhoneCode() async {
    final phone = normalizePhoneNumber(_phone);
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      return _notice('Enter a complete phone number including country code.',
          error: true);
    }
    await _run(() async {
      if (kIsWeb) {
        _webConfirmation = await _user!.linkWithPhoneNumber(phone);
        if (mounted) setState(() => _codeSent = true);
        _notice('Verification code sent by SMS.');
        return;
      }
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          await _completePhoneCredential(credential);
        },
        verificationFailed: (error) {
          _notice(_friendlyPhoneError(error), error: true);
          if (mounted) setState(() => _busy = false);
        },
        codeSent: (verificationId, _) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _busy = false;
          });
          _notice('Verification code sent by SMS.');
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    }, completeBusy: kIsWeb);
  }

  Future<void> _confirmPhoneCode() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return _notice('Enter the 6-digit code from the SMS.', error: true);
    }
    await _run(() async {
      if (kIsWeb) {
        final confirmation = _webConfirmation;
        if (confirmation == null) {
          throw StateError('Request a new verification code.');
        }
        await confirmation.confirm(code);
        await _afterPhoneVerified();
      } else {
        final verificationId = _verificationId;
        if (verificationId == null) {
          throw StateError('Request a new verification code.');
        }
        await _completePhoneCredential(PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        ));
      }
    });
  }

  Future<void> _completePhoneCredential(PhoneAuthCredential credential) async {
    await _user!.linkWithCredential(credential);
    await _afterPhoneVerified();
  }

  Future<void> _afterPhoneVerified() async {
    await _user!.reload();
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
    await _syncVerification();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _codeSent = false;
      _verificationId = null;
      _webConfirmation = null;
    });
    _notice('Mobile phone ownership verified.');
  }

  Future<void> _sendMfaEnrollmentCode() async {
    if (!_mfaSupported) {
      return _notice(
          'Open Pipe Buyer on the web, Android, or iOS to enroll MFA.',
          error: true);
    }
    final user = _user;
    final phone = normalizePhoneNumber(user?.phoneNumber ?? '');
    if (user == null || !user.emailVerified) {
      return _notice('Verify your email address before enabling two-step SMS.',
          error: true);
    }
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      return _notice(
          'Verify a complete mobile phone number before enabling two-step SMS.',
          error: true);
    }

    await _run(() async {
      await user.reload();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || !currentUser.emailVerified) {
        throw StateError(
            'Verify your email address before enabling two-step SMS.');
      }
      final session = await currentUser.multiFactor.getSession();
      await FirebaseAuth.instance.verifyPhoneNumber(
        multiFactorSession: session,
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          try {
            await _completeMfaEnrollment(credential);
          } on FirebaseAuthException catch (error) {
            _notice(_friendlyPhoneError(error), error: true);
          } finally {
            if (mounted) setState(() => _busy = false);
          }
        },
        verificationFailed: (error) {
          _notice(_friendlyPhoneError(error), error: true);
          if (mounted) setState(() => _busy = false);
        },
        codeSent: (verificationId, _) {
          if (!mounted) return;
          setState(() {
            _mfaVerificationId = verificationId;
            _mfaCodeSent = true;
            _busy = false;
          });
          _notice('Two-step verification code sent by SMS.');
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _mfaVerificationId = verificationId;
        },
      );
    });
  }

  Future<void> _confirmMfaEnrollmentCode() async {
    final code = _mfaCode.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return _notice('Enter the 6-digit code from the SMS.', error: true);
    }
    final verificationId = _mfaVerificationId;
    if (verificationId == null) {
      return _notice('Request a new enrollment code.', error: true);
    }
    await _run(() async {
      await _completeMfaEnrollment(PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      ));
    });
  }

  Future<void> _completeMfaEnrollment(PhoneAuthCredential credential) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in again before enrolling two-step SMS.');
    }
    await user.multiFactor.enroll(
      PhoneMultiFactorGenerator.getAssertion(credential),
      displayName: 'Pipe Buyer security phone',
    );
    await user.getIdToken(true);
    final factors = await user.multiFactor.getEnrolledFactors();
    if (!mounted) return;
    setState(() {
      _enrolledFactors = factors;
      _mfaCodeSent = false;
      _mfaVerificationId = null;
      _mfaCode.clear();
    });
    _notice('Two-step SMS verification is enabled.');
  }

  Future<void> _syncVerification() async {
    await _commands.execute('syncAccountVerification', const {});
  }

  Future<void> _syncVerificationBestEffort() async {
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
    await _syncVerificationBestEffort();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _run(Future<void> Function() work,
      {bool completeBusy = true}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await work();
    } on FirebaseAuthException catch (error) {
      _notice(_friendlyPhoneError(error), error: true);
    } catch (error) {
      _notice(
        marketplaceCommandErrorMessage(
          error,
          fallback:
              'Account verification could not sync right now. Please try again in a moment.',
        ),
        error: true,
      );
    } finally {
      if (mounted && completeBusy) setState(() => _busy = false);
    }
  }

  String _friendlyPhoneError(FirebaseAuthException error) =>
      switch (error.code) {
        'credential-already-in-use' =>
          'This mobile number belongs to another account. Sign in to that account or use account recovery.',
        'invalid-verification-code' =>
          'That SMS code is incorrect or expired. Request a new code.',
        'invalid-phone-number' =>
          'Enter a valid mobile number including the country code.',
        'second-factor-already-in-use' =>
          'This phone is already enrolled as a second factor.',
        'maximum-second-factor-count-exceeded' =>
          'This account already has the maximum number of second factors.',
        'unsupported-first-factor' =>
          'This account sign-in method cannot be used with Firebase MFA.',
        'invalid-multi-factor-session' ||
        'missing-multi-factor-session' =>
          'The enrollment session expired. Sign out, sign in again, and retry.',
        'quota-exceeded' ||
        'too-many-requests' =>
          'Verification requests are temporarily rate-limited. Wait a moment before trying again.',
        'operation-not-allowed' =>
          'Phone SMS authentication or SMS multi-factor authentication is not enabled in Firebase Console.',
        'requires-recent-login' =>
          'For security, sign out and sign back in before changing verification.',
        _ => error.message ?? 'Verification failed (${error.code}).',
      };

  void _notice(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _error = error;
    });
  }
}

class _StatusSummaryChip extends StatelessWidget {
  const _StatusSummaryChip({
    required this.icon,
    required this.label,
    required this.complete,
  });

  final IconData icon;
  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final accent = complete ? PipeBuyerColors.success : PipeBuyerColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: complete
            ? PipeBuyerColors.success.withValues(alpha: .09)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
                  alpha: .45,
                ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: complete
              ? PipeBuyerColors.success.withValues(alpha: .28)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : icon,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: complete ? PipeBuyerColors.success : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.verified,
    this.pendingLabel = 'PENDING',
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool verified;
  final String pendingLabel;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOptionalUnverified = !verified && pendingLabel == 'OPTIONAL';
    final accent = verified
        ? PipeBuyerColors.success
        : isOptionalUnverified
            ? PipeBuyerColors.industrialBlue
            : PipeBuyerColors.orange;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: .20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              verified ? Icons.check_rounded : icon,
              color: accent,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    PipeBuyerStatusBadge(
                      label: verified ? 'VERIFIED' : pendingLabel,
                      tone: verified
                          ? PipeBuyerStatusTone.success
                          : isOptionalUnverified
                              ? PipeBuyerStatusTone.info
                              : PipeBuyerStatusTone.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .68),
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
