import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/firebase_auth/google_auth.dart';
import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_account_security_page.dart';
import 'marketplace_command_client.dart';
import 'marketplace_mfa.dart';
import 'regional_phone_field.dart';

class MarketplaceAuthPage extends StatefulWidget {
  const MarketplaceAuthPage({super.key});

  @override
  State<MarketplaceAuthPage> createState() => _MarketplaceAuthPageState();
}

class _MarketplaceAuthPageState extends State<MarketplaceAuthPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _businessName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  bool _hidePassword = true;
  bool _rememberMe = true;
  String _accountType = 'personal';
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void dispose() {
    _name.dispose();
    _businessName.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final largeText = media.textScaler.scale(12) >= 18;
    final compactChrome = media.size.width < 420 || largeText;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pipe Buyer'),
        actions: [
          if (compactChrome)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'Secure access',
                child: Center(
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: PipeBuyerColors.success,
                  ),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: PipeBuyerStatusBadge(
                  label: 'SECURE ACCESS',
                  tone: PipeBuyerStatusTone.success,
                  icon: Icons.lock_outline_rounded,
                ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1120 &&
              constraints.maxHeight >= 640 &&
              !largeText;
          if (wide) {
            return Row(
              children: [
                Expanded(flex: 11, child: _brandPanel(context)),
                Expanded(
                  flex: 9,
                  child: ColoredBox(
                    color: theme.scaffoldBackgroundColor,
                    child: _formViewport(context, compact: false),
                  ),
                ),
              ],
            );
          }
          return _formViewport(context, compact: true);
        },
      ),
    );
  }

  Widget _brandPanel(BuildContext context) {
    return Container(
      constraints: const BoxConstraints.expand(),
      padding: const EdgeInsets.fromLTRB(54, 52, 54, 44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PipeBuyerColors.ink,
            PipeBuyerColors.charcoal,
            Color(0xFF111820),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -120,
            top: -90,
            child: Container(
              width: 390,
              height: 390,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: PipeBuyerColors.orange.withValues(alpha: .18),
                  width: 46,
                ),
              ),
            ),
          ),
          Positioned(
            right: -30,
            bottom: -130,
            child: Container(
              width: 330,
              height: 330,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .055),
                  width: 72,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _wordmark(),
              const Spacer(),
              const Text(
                'Industrial commerce. Built for serious transactions.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  height: 1.08,
                  letterSpacing: -1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _signup
                    ? 'Create a verified marketplace identity for pipe, equipment, buildings, transport and energy inventory.'
                    : 'Access listings, negotiations, timed auctions, secure payments and Pipe Buyer Dispatch from one account.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DarkTrustPill(
                    icon: Icons.verified_user_outlined,
                    label: 'Verified marketplace identities',
                  ),
                  _DarkTrustPill(
                    icon: Icons.shield_outlined,
                    label: 'Fraud protection',
                  ),
                  _DarkTrustPill(
                    icon: Icons.local_shipping_outlined,
                    label: 'Dispatch & freight',
                  ),
                  _DarkTrustPill(
                    icon: Icons.gavel_outlined,
                    label: 'Timed auctions',
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(
                    Icons.public_rounded,
                    color: PipeBuyerColors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Built for North America. Designed for global industry.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .66),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formViewport(BuildContext context, {required bool compact}) {
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(12) >= 18;
    final horizontalPadding = compact ? (largeText ? 10.0 : 18.0) : 40.0;
    final verticalPadding = compact ? (largeText ? 12.0 : 22.0) : 34.0;
    final cardPadding = compact ? (largeText ? 14.0 : 20.0) : 30.0;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (compact) ...[
                      Center(child: _wordmark(darkText: true)),
                      const SizedBox(height: 22),
                    ],
                    PipeBuyerPageHeader(
                      eyebrow:
                          _signup ? 'Create your account' : 'Secure sign in',
                      title: _signup ? 'Join Pipe Buyer' : 'Welcome back',
                      subtitle: _signup
                          ? 'Choose how you will buy, sell and represent yourself in the marketplace.'
                          : 'Sign in to manage listings, negotiate offers, bid on auctions and access Dispatch.',
                      icon: _signup
                          ? Icons.person_add_alt_1_outlined
                          : Icons.lock_open_outlined,
                    ),
                    const SizedBox(height: 24),
                    if (_signup) ...[
                      const Text(
                        'Account type',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'personal',
                            icon: Icon(Icons.person_outline),
                            label: Text('Personal'),
                          ),
                          ButtonSegment(
                            value: 'business',
                            icon: Icon(Icons.business_outlined),
                            label: Text('Business'),
                          ),
                        ],
                        selected: {_accountType},
                        onSelectionChanged: (value) =>
                            setState(() => _accountType = value.first),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter your name'
                                : null,
                      ),
                      if (_accountType == 'business') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _businessName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Public business name',
                            prefixIcon: Icon(Icons.storefront_outlined),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter the business name'
                                  : null,
                        ),
                      ],
                      const SizedBox(height: 12),
                      RegionalPhoneField(
                        label: 'Mobile phone number (optional)',
                        initialValue: _phone.text,
                        required: false,
                        onChanged: (value) => _phone.text = value,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) => value == null ||
                              !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)
                          ? 'Enter a valid email address'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      autofillHints: _signup
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip:
                              _hidePassword ? 'Show password' : 'Hide password',
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.length < 6
                          ? 'Use at least 6 characters'
                          : null,
                    ),
                    if (!_signup)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _rememberMe,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Remember me',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Keep me signed in on this device.',
                          style: TextStyle(fontSize: 12),
                        ),
                        onChanged: _busy
                            ? null
                            : (value) =>
                                setState(() => _rememberMe = value ?? true),
                      ),
                    const SizedBox(height: 16),
                    if (_statusMessage != null) ...[
                      PipeStatusSurface(
                        tone: _statusIsError
                            ? PipeStatusTone.error
                            : PipeStatusTone.success,
                        message: _statusMessage!,
                        liveRegion: true,
                      ),
                      const SizedBox(height: 14),
                    ],
                    FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _signup
                                  ? Icons.arrow_forward_rounded
                                  : Icons.login_rounded,
                            ),
                      label: Text(
                        _busy
                            ? 'Please wait…'
                            : _signup
                                ? 'Create ${_accountType == 'business' ? 'business' : 'personal'} account'
                                : 'Sign in securely',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: .50),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: const Icon(Icons.g_mobiledata, size: 30),
                      label: const Text('Continue with Google'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _signup = !_signup),
                      child: Text(
                        _signup
                            ? 'Already have an account? Sign in'
                            : 'New to Pipe Buyer? Create an account',
                      ),
                    ),
                    if (!_signup)
                      TextButton.icon(
                        onPressed: _busy ? null : _startAccountRecovery,
                        icon: const Icon(Icons.health_and_safety_outlined),
                        label: const Text('Recover account'),
                      ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    if (largeText)
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CompactTrustItem(
                            icon: Icons.verified_user_outlined,
                            label: 'Verified accounts',
                            expanded: true,
                          ),
                          SizedBox(height: 8),
                          _CompactTrustItem(
                            icon: Icons.shield_outlined,
                            label: 'Fraud protection',
                            expanded: true,
                          ),
                          SizedBox(height: 8),
                          _CompactTrustItem(
                            icon: Icons.lock_outline_rounded,
                            label: 'Protected access',
                            expanded: true,
                          ),
                        ],
                      )
                    else
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _CompactTrustItem(
                            icon: Icons.verified_user_outlined,
                            label: 'Verified accounts',
                          ),
                          _CompactTrustItem(
                            icon: Icons.shield_outlined,
                            label: 'Fraud protection',
                          ),
                          _CompactTrustItem(
                            icon: Icons.lock_outline_rounded,
                            label: 'Protected access',
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wordmark({bool darkText = false}) {
    final primary = darkText ? PipeBuyerColors.ink : Colors.white;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PIPE',
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w900,
              fontSize: 25,
              letterSpacing: -.7,
            ),
          ),
          const Text(
            'BUYER',
            style: TextStyle(
              color: PipeBuyerColors.orange,
              fontWeight: FontWeight.w900,
              fontSize: 25,
              letterSpacing: -.7,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(
            _rememberMe ? Persistence.LOCAL : Persistence.SESSION);
      }
      UserCredential? credential;
      try {
        credential = await googleSignInFunc();
      } on FirebaseAuthMultiFactorException catch (error) {
        if (!mounted) return;
        credential = await resolveFirebaseMultiFactorSignIn(
          context: context,
          exception: error,
        );
      }
      final user = credential?.user;
      if (user == null) return;

      final profileRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final profile = await profileRef.get();
      if (!profile.exists) {
        await profileRef.set({
          'uid': user.uid,
          'email': user.email ?? '',
          'display_name': user.displayName ?? '',
          'photo_url': user.photoURL ?? '',
          'accountType': 'personal',
          'roleVersion': 0,
          'signupRegion': 'unknown',
          'profileComplete': false,
          'profileCompletion': 0,
          'accountVerified': false,
          'userScore': 70,
          'userScoreStanding': 'new',
          'created_time': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      final googlePhoneVerified =
          normalizePhoneNumber(user.phoneNumber ?? '').isNotEmpty;
      if (!user.emailVerified && !googlePhoneVerified) {
        await Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => const MarketplaceAccountSecurityPage(
                  onboarding: true,
                  initialAccountType: 'personal',
                )));
        return;
      }
      await _syncVerificationBestEffort();
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (error) {
      _notice(_friendlyGoogleAuthError(error),
          error: true, icon: _authErrorIcon(error.code));
    } catch (_) {
      _notice('Google sign-in could not finish. Please try again.',
          error: true, icon: Icons.login_outlined);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      if (_signup) {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
                email: _email.text.trim(), password: _password.text);
        await credential.user!.updateDisplayName(_name.text.trim());
        final uid = credential.user!.uid;
        final normalizedPhone = normalizePhoneNumber(_phone.text);
        final batch = FirebaseFirestore.instance.batch();
        batch.set(FirebaseFirestore.instance.collection('users').doc(uid), {
          'uid': uid,
          'email': _email.text.trim(),
          'display_name': _name.text.trim(),
          'pendingPhoneE164': normalizedPhone,
          'accountType': _accountType,
          'roleVersion': 0,
          'signupRegion': 'unknown',
          'profileComplete': false,
          'profileCompletion': 0,
          'accountVerified': false,
          'userScore': 70,
          'userScoreStanding': 'new',
          'created_time': FieldValue.serverTimestamp(),
        });
        if (_accountType == 'business') {
          batch.set(
              FirebaseFirestore.instance
                  .collection('public_business_profiles')
                  .doc(uid),
              {
                'ownerUid': uid,
                'publicName': _businessName.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });
          batch.set(
              FirebaseFirestore.instance
                  .collection('business_private')
                  .doc(uid),
              {
                'ownerUid': uid,
                'memberUids': [uid],
                'createdAt': FieldValue.serverTimestamp(),
              });
        }
        try {
          await batch.commit();
        } on FirebaseException {
          await credential.user?.delete();
          rethrow;
        }
        String? verificationNotice;
        try {
          await credential.user?.sendEmailVerification();
        } on FirebaseAuthException {
          verificationNotice =
              'Your account was created, but the verification email was not delivered yet. Use “Resend email” on the next screen.';
        }
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => MarketplaceAccountSecurityPage(
                  onboarding: true,
                  initialPhone: normalizedPhone,
                  initialAccountType: _accountType,
                  initialNotice: verificationNotice,
                )));
        return;
      } else {
        if (kIsWeb) {
          await FirebaseAuth.instance.setPersistence(
              _rememberMe ? Persistence.LOCAL : Persistence.SESSION);
        }
        UserCredential credential;
        try {
          credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: _email.text.trim(), password: _password.text);
        } on FirebaseAuthMultiFactorException catch (error) {
          if (!mounted) return;
          credential = await resolveFirebaseMultiFactorSignIn(
            context: context,
            exception: error,
          );
        }
        await credential.user?.reload();
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'The account could not be loaded.');
        }
        await user.getIdToken(true);
        DocumentSnapshot<Map<String, dynamic>>? securityProfile;
        try {
          securityProfile = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
        } on FirebaseException {
          // Ownership recovery must remain reachable during a profile outage.
        }
        final securityAccountType =
            '${securityProfile?.data()?['accountType'] ?? 'personal'}';
        final phoneVerified =
            normalizePhoneNumber(user.phoneNumber ?? '').isNotEmpty;
        if (!user.emailVerified && !phoneVerified) {
          if (!mounted) return;
          await Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => MarketplaceAccountSecurityPage(
                    onboarding: true,
                    initialPhone:
                        '${securityProfile?.data()?['pendingPhoneE164'] ?? ''}',
                    initialAccountType: securityAccountType,
                  )));
          return;
        }
        await _syncVerificationBestEffort();
        final profileRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        final profile = await profileRef.get();
        if (!profile.exists) {
          await profileRef.set({
            'uid': user.uid,
            'email': user.email ?? _email.text.trim(),
            'display_name': user.displayName ?? '',
            'accountType': 'personal',
            'roleVersion': 0,
            'signupRegion': 'unknown',
            'profileComplete': false,
            'profileCompletion': 0,
            'accountVerified': false,
            'userScore': 70,
            'userScoreStanding': 'new',
            'created_time': FieldValue.serverTimestamp(),
            'profileRecoveredAt': FieldValue.serverTimestamp(),
          });
        } else if ('${profile.data()?['accountType'] ?? 'personal'}' ==
            'personal') {
          await FirebaseFirestore.instance
              .collection('public_seller_profiles')
              .doc(user.uid)
              .set({
            'ownerUid': user.uid,
            'displayName':
                profile.data()?['display_name'] ?? user.displayName ?? '',
            'description': profile.data()?['sellerBio'],
            'baseCommunity': profile.data()?['baseCommunity'],
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        _notice('Signed in successfully. Welcome back.',
            error: false, icon: Icons.check_circle);
      }
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use' && mounted) {
        setState(() => _signup = false);
      }
      _notice(_friendlyAuthError(error),
          error: true, icon: _authErrorIcon(error.code));
    } on FirebaseException catch (error) {
      _notice(
          error.code == 'permission-denied' || error.code == 'already-exists'
              ? 'This phone number is already connected to another Pipe Buyer account. Sign in to the existing account or use account recovery.'
              : error.code == 'not-found' ||
                      error.message?.contains('database') == true
                  ? 'Firestore is not created for this Firebase project yet. An administrator must create the default database.'
                  : error.message ?? 'Firebase could not finish account setup.',
          error: true);
    } catch (_) {
      _notice('Could not finish account setup. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncVerificationBestEffort() async {
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

  Future<void> _startAccountRecovery() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      return _notice('Enter the email address used for your account first.',
          error: true, icon: Icons.email_outlined);
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.health_and_safety_outlined, size: 36),
            title: const Text('Recover your account'),
            content: Text(
                'Pipe Buyer will send password-reset instructions to $email if it belongs to an account. The message may take a few minutes; check your spam folder as well.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: const Text('Send recovery email')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _notice(
          'If that email belongs to a Pipe Buyer account, recovery instructions have been sent. Check your inbox and spam folder.',
          error: false,
          icon: Icons.mark_email_read_outlined);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        _notice(
            'If that email belongs to a Pipe Buyer account, recovery instructions have been sent. Check your inbox and spam folder.',
            error: false,
            icon: Icons.mark_email_read_outlined);
      } else {
        _notice(_friendlyAuthError(error),
            error: true, icon: _authErrorIcon(error.code));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String text,
      {bool error = false, IconData icon = Icons.info_outline}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = text;
      _statusIsError = error;
    });
    PipeFeedback.show(
      context,
      message: text,
      tone: error ? PipeStatusTone.error : PipeStatusTone.success,
      icon: icon,
    );
  }

  IconData _authErrorIcon(String code) => switch (code) {
        'user-not-found' => Icons.person_search_outlined,
        'wrong-password' || 'invalid-credential' => Icons.lock_outline,
        'invalid-email' => Icons.alternate_email,
        'network-request-failed' => Icons.wifi_off_outlined,
        'invalid-verification-code' ||
        'mfa-timeout' =>
          Icons.sms_failed_outlined,
        'user-disabled' => Icons.block_outlined,
        _ => Icons.error_outline,
      };

  String _friendlyAuthError(FirebaseAuthException error) {
    return switch (error.code) {
      'configuration-not-found' ||
      'operation-not-allowed' =>
        'Email/password authentication is not enabled for this Firebase project yet.',
      'email-already-in-use' =>
        'This email already has an account. Select “Already have an account? Sign in” and use the existing password.',
      'invalid-credential' ||
      'invalid-login-credentials' =>
        'The email or password is incorrect. Check both fields or reset your password.',
      'wrong-password' =>
        'That password is incorrect. Try again or select “Forgot password?”.',
      'user-not-found' =>
        'No account was found for this email address. Check the spelling or create an account.',
      'invalid-email' => 'Enter a valid email address.',
      'user-disabled' =>
        'This account has been disabled. Please contact marketplace support.',
      'mfa-cancelled' => 'Second-factor verification was cancelled.',
      'mfa-timeout' =>
        'The security-code session timed out. Sign in again and request a new code.',
      'invalid-verification-code' =>
        'That security code is incorrect or expired. Sign in again and request a new code.',
      'unsupported-second-factor' =>
        'This account has no supported SMS second factor. Contact support to recover access.',
      'quota-exceeded' ||
      'too-many-requests' =>
        'Authentication is temporarily limited. Wait a few minutes before trying again.',
      'weak-password' =>
        'Choose a stronger password with at least 6 characters.',
      'network-request-failed' =>
        'Could not reach Firebase. Check your internet connection.',
      _ => error.message ?? 'Authentication failed (${error.code}).',
    };
  }

  String _friendlyGoogleAuthError(FirebaseAuthException error) {
    return switch (error.code) {
      'operation-not-allowed' =>
        'Google sign-in is not enabled for this Firebase project yet.',
      'unauthorized-domain' =>
        'This Pipe Buyer domain is not authorized for Google sign-in.',
      'popup-blocked' =>
        'Your browser blocked the Google sign-in window. Allow pop-ups for Pipe Buyer and try again.',
      'popup-closed-by-user' ||
      'cancelled-popup-request' =>
        'Google sign-in was cancelled.',
      'account-exists-with-different-credential' =>
        'An account already uses this email with another sign-in method. Sign in that way first, then connect Google.',
      'mfa-cancelled' => 'Second-factor verification was cancelled.',
      'mfa-timeout' =>
        'The security-code session timed out. Start Google sign-in again.',
      'invalid-verification-code' =>
        'That security code is incorrect or expired. Start Google sign-in again.',
      'unsupported-second-factor' =>
        'This account has no supported SMS second factor. Contact support to recover access.',
      'quota-exceeded' ||
      'too-many-requests' =>
        'Authentication is temporarily limited. Wait a few minutes before trying again.',
      'network-request-failed' =>
        'Could not reach Google or Firebase. Check your internet connection.',
      _ => error.message ?? 'Google authentication failed (${error.code}).',
    };
  }
}

class _DarkTrustPill extends StatelessWidget {
  const _DarkTrustPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: PipeBuyerColors.orange),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _CompactTrustItem extends StatelessWidget {
  const _CompactTrustItem({
    required this.icon,
    required this.label,
    this.expanded = false,
  });

  final IconData icon;
  final String label;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelText = Text(
      label,
      softWrap: true,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: .62),
        fontWeight: FontWeight.w700,
      ),
    );
    return Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        const SizedBox(width: 1),
        Icon(icon, size: 16, color: PipeBuyerColors.success),
        const SizedBox(width: 5),
        if (expanded) Expanded(child: labelText) else labelText,
      ],
    );
  }
}
