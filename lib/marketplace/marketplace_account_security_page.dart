import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'marketplace_command_client.dart';
import 'marketplace_payout_settings.dart';
import 'marketplace_profile_page.dart';
import 'regional_phone_field.dart';

class MarketplaceAccountSecurityPage extends StatefulWidget {
  const MarketplaceAccountSecurityPage({
    super.key,
    this.onboarding = false,
    this.initialPhone,
    this.initialAccountType = 'personal',
    this.initialNotice,
  });

  final bool onboarding;
  final String? initialPhone;
  final String initialAccountType;
  final String? initialNotice;

  @override
  State<MarketplaceAccountSecurityPage> createState() =>
      _MarketplaceAccountSecurityPageState();
}

class _MarketplaceAccountSecurityPageState
    extends State<MarketplaceAccountSecurityPage> {
  final _code = TextEditingController();
  final _mfaCode = TextEditingController();
  final _commands = MarketplaceCommandClient();
  String _phone = '';
  String? _verificationId;
  String? _mfaVerificationId;
  ConfirmationResult? _webConfirmation;
  bool _busy = false;
  bool _codeSent = false;
  bool _mfaCodeSent = false;
  List<MultiFactorInfo> _enrolledFactors = const [];
  String? _message;
  bool _error = false;

  User? get _user => FirebaseAuth.instance.currentUser;
  bool get _emailVerified => _user?.emailVerified == true;
  bool get _phoneVerified =>
      normalizePhoneNumber(_user?.phoneNumber ?? '').isNotEmpty;
  bool get _mfaEnrolled =>
      _enrolledFactors.any((factor) => factor is PhoneMultiFactorInfo);
  bool get _mfaSupported =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _phone = normalizePhoneNumber(widget.initialPhone ?? '');
    _message = widget.initialNotice;
    _loadPendingPhone();
    _loadMfaFactors();
  }

  @override
  void dispose() {
    _code.dispose();
    _mfaCode.dispose();
    super.dispose();
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
    } catch (_) {
      // The field remains editable when the optional profile hint is unavailable.
    }
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
      return const Scaffold(body: Center(child: Text('Sign in to continue.')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onboarding ? 'Verify your account' : 'Security'),
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.verified_user_outlined,
                      size: 54, color: Color(0xFF0878E8)),
                  const SizedBox(height: 10),
                  Text(
                    widget.onboarding
                        ? 'Protect your Pipe Buyer account'
                        : 'Account ownership',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Verified contact methods reduce duplicate accounts and protect '
                    'listings, offers, auctions, and Dispatch jobs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF66758A)),
                  ),
                  const SizedBox(height: 18),
                  _VerificationCard(
                    icon: Icons.mark_email_read_outlined,
                    title: 'Email ownership',
                    value: user.email ?? 'No email available',
                    verified: _emailVerified,
                    actionLabel: _emailVerified ? 'Verified' : 'Resend email',
                    onAction: _emailVerified || _busy ? null : _resendEmail,
                  ),
                  if (!_emailVerified) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _refreshEmail,
                      icon: const Icon(Icons.refresh),
                      label: const Text('I verified my email — refresh status'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _VerificationCard(
                    icon: Icons.phone_android_outlined,
                    title: 'Mobile phone ownership',
                    value: _phoneVerified
                        ? formatPhoneNumber(user.phoneNumber ?? '')
                        : 'A one-time SMS code is required',
                    verified: _phoneVerified,
                    actionLabel: _phoneVerified ? 'Verified' : null,
                  ),
                  if (!_phoneVerified) ...[
                    const SizedBox(height: 10),
                    RegionalPhoneField(
                      key: ValueKey(_phone),
                      label: 'Mobile phone number (optional)',
                      initialValue: _phone,
                      required: false,
                      onChanged: (value) =>
                          _phone = normalizePhoneNumber(value),
                    ),
                    const SizedBox(height: 9),
                    if (!_codeSent)
                      FilledButton.icon(
                        onPressed: _busy ? null : _sendPhoneCode,
                        icon: const Icon(Icons.sms_outlined),
                        label:
                            Text(_busy ? 'Sending…' : 'Send verification code'),
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
                            child: const Text('Send a new code'),
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
                    if (!_emailVerified && !_phoneVerified)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                            'Verify either email ownership or mobile phone ownership to continue to your profile.',
                            style: TextStyle(color: Color(0xFF66758A))),
                      ),
                  ],
                  const SizedBox(height: 14),
                  _VerificationCard(
                    icon: Icons.phonelink_lock_outlined,
                    title: 'Two-step verification',
                    value: !_mfaSupported
                        ? 'Firebase MFA is not supported in the Windows desktop build.'
                        : _mfaEnrolled
                            ? '${_enrolledFactors.length} second factor${_enrolledFactors.length == 1 ? '' : 's'} enrolled'
                            : 'Enroll SMS MFA before administrator access can be granted.',
                    verified: _mfaEnrolled,
                    actionLabel: _mfaEnrolled ? 'Enabled' : null,
                  ),
                  if (_mfaSupported && !_mfaEnrolled) ...[
                    const SizedBox(height: 9),
                    const Text(
                      'Firebase will send a security code to the verified phone. '
                      'That code will be required on future administrator sign-ins. '
                      'Standard SMS rates may apply.',
                      style: TextStyle(color: Color(0xFF66758A)),
                    ),
                    const SizedBox(height: 9),
                    if (!_emailVerified || !_phoneVerified)
                      const Text(
                        'Verify the email and mobile phone above before enrolling two-step verification.',
                        style: TextStyle(
                            color: Color(0xFF9A5B00),
                            fontWeight: FontWeight.w700),
                      )
                    else if (!_mfaCodeSent)
                      FilledButton.icon(
                        onPressed: _busy ? null : _sendMfaEnrollmentCode,
                        icon: const Icon(Icons.phonelink_lock_outlined),
                        label: Text(_busy
                            ? 'Preparing…'
                            : 'Enroll SMS two-step verification'),
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
                            onPressed:
                                _busy ? null : _sendMfaEnrollmentCode,
                            child: const Text('Send a new code'),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                _busy ? null : _confirmMfaEnrollmentCode,
                            child:
                                Text(_busy ? 'Enrolling…' : 'Enable two-step'),
                          ),
                        ),
                      ]),
                    ],
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 13),
                    Material(
                      color: _error ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Icon(
                              _error
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              color: _error
                                  ? Colors.red.shade700
                                  : Colors.green.shade700),
                          const SizedBox(width: 9),
                          Expanded(child: Text(_message!)),
                        ]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MarketplacePayoutSettingsPage(),
                      ),
                    ),
                    icon: const Icon(Icons.account_balance_outlined,
                        color: Color(0xFF0878E8)),
                    label: const Text('Configure Banking & Payout Vault'),
                  ),
                  const SizedBox(height: 12),
                  if (widget.onboarding)
                    FilledButton.icon(
                      onPressed: (_emailVerified || _phoneVerified) && !_busy
                          ? _continueToProfile
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continue to your profile'),
                    ),
                  if (widget.onboarding)
                    TextButton.icon(
                      onPressed: _busy ? null : _signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out and finish later'),
                    ),
                ]),
          ),
        ),
      ),
    );
  }

  Future<void> _resendEmail() async {
    await _run(() async {
      await _user!.sendEmailVerification();
      _notice('Verification email sent. Check your inbox and spam folder.');
    });
  }

  Future<void> _refreshEmail() async {
    await _run(() async {
      await _user!.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (FirebaseAuth.instance.currentUser?.emailVerified != true) {
        _notice(
            'The email is not verified yet. Open the verification link, then try again.',
            error: true);
        return;
      }
      await _syncVerification();
      _notice('Email ownership verified. You can now verify your phone.');
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
      return _notice('Verify the account email before enrolling MFA.',
          error: true);
    }
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      return _notice('Verify a complete mobile phone number before enrolling MFA.',
          error: true);
    }

    await _run(() async {
      await user.reload();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || !currentUser.emailVerified) {
        throw StateError('Verify the account email before enrolling MFA.');
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
          _notice('MFA enrollment code sent by SMS.');
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
      return _notice('Enter the 6-digit MFA code from the SMS.', error: true);
    }
    final verificationId = _mfaVerificationId;
    if (verificationId == null) {
      return _notice('Request a new MFA enrollment code.', error: true);
    }
    await _run(() async {
      await _completeMfaEnrollment(PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      ));
    });
  }

  Future<void> _completeMfaEnrollment(
      PhoneAuthCredential credential) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in again before enrolling MFA.');
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
    _notice(
        'Two-step verification is enabled. Sign out and sign in again to test the SMS challenge.');
  }

  Future<void> _syncVerification() async {
    await _commands.execute('syncAccountVerification', const {});
  }

  Future<void> _continueToProfile() async {
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
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.of(context).pop(false);
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
          error is StateError
              ? error.message
              : 'Account verification could not be completed. Try again.',
          error: true);
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
          'The MFA enrollment session expired. Sign out, sign in again, and retry.',
        'quota-exceeded' ||
        'too-many-requests' =>
          'SMS verification is temporarily limited. Wait before trying again.',
        'operation-not-allowed' =>
          'Phone SMS authentication or SMS multi-factor authentication is not enabled in Firebase Console.',
        'requires-recent-login' =>
          'For security, sign out and sign back in before changing verification.',
        _ => error.message ?? 'Phone verification failed (${error.code}).',
      };

  void _notice(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _error = error;
    });
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.verified,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool verified;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Material(
        color: verified ? Colors.green.shade50 : const Color(0xFFF0F5FA),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: verified ? Colors.green.shade100 : Colors.white,
              child: Icon(verified ? Icons.check : icon,
                  color: verified
                      ? Colors.green.shade800
                      : const Color(0xFF0878E8)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(color: Color(0xFF66758A))),
              ],
            )),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ]),
        ),
      );
}
