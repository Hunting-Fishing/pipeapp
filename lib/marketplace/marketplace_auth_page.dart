import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import 'marketplace_account_security_page.dart';
import 'marketplace_command_client.dart';
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_signup ? 'Create account' : 'Sign in')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                child: Column(children: [
                  Image.asset('assets/images/pipe_buyer_logo.png',
                      width: 220, height: 100, fit: BoxFit.contain),
                  Text(_signup ? 'Join the marketplace' : 'Welcome back',
                      style: const TextStyle(
                          fontSize: 27, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                      _signup
                          ? 'Choose how you will buy and sell.'
                          : 'Sign in to message sellers, make offers and save listings.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF66758A))),
                  const SizedBox(height: 20),
                  if (_signup) ...[
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'personal',
                            icon: Icon(Icons.person_outline),
                            label: Text('Personal')),
                        ButtonSegment(
                            value: 'business',
                            icon: Icon(Icons.business_outlined),
                            label: Text('Business')),
                      ],
                      selected: {_accountType},
                      onSelectionChanged: (value) =>
                          setState(() => _accountType = value.first),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'Your name',
                          prefixIcon: Icon(Icons.person_outline)),
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
                            prefixIcon: Icon(Icons.storefront_outlined)),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter the business name'
                                : null,
                      )
                    ],
                    const SizedBox(height: 12),
                    RegionalPhoneField(
                        label: 'Mobile phone number',
                        initialValue: _phone.text,
                        required: true,
                        onChanged: (value) => _phone.text = value),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined)),
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
                          icon: Icon(_hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined)),
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
                      title: const Text('Remember me',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Keep me signed in on this device.',
                          style: TextStyle(fontSize: 12)),
                      onChanged: _busy
                          ? null
                          : (value) =>
                              setState(() => _rememberMe = value ?? true),
                    ),
                  const SizedBox(height: 18),
                  if (_statusMessage != null) ...[
                    PipeStatusSurface(
                      tone: _statusIsError
                          ? PipeStatusTone.error
                          : PipeStatusTone.success,
                      message: _statusMessage!,
                      liveRegion: true,
                    ),
                    const SizedBox(height: 12)
                  ],
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54)),
                    child: Text(_busy
                        ? 'Please wait…'
                        : _signup
                            ? 'Create ${_accountType == 'business' ? 'business' : 'personal'} account'
                            : 'Sign in'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _signup = !_signup),
                      child: Text(_signup
                          ? 'Already have an account? Sign in'
                          : 'New to Pipe Buyer? Create an account')),
                  if (!_signup)
                    TextButton.icon(
                        onPressed: _busy ? null : _startAccountRecovery,
                        icon: const Icon(Icons.health_and_safety_outlined),
                        label: const Text('Recover account')),
                ]),
              ),
            ),
          ),
        ),
      );

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
              'Your account was created, but the verification email was not '
              'delivered yet. Use “Resend email” on the next screen.';
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
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
                email: _email.text.trim(), password: _password.text);
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
        if (!user.emailVerified ||
            normalizePhoneNumber(user.phoneNumber ?? '').isEmpty) {
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
        await MarketplaceCommandClient()
            .execute('syncAccountVerification', const {});
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
    } catch (error) {
      _notice('Could not finish account setup. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
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
        // Do not reveal whether an email is registered; this prevents account
        // discovery while preserving the same helpful recovery response.
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
      'too-many-requests' =>
        'Too many sign-in attempts. Wait a few minutes or reset your password.',
      'weak-password' =>
        'Choose a stronger password with at least 6 characters.',
      'network-request-failed' =>
        'Could not reach Firebase. Check your internet connection.',
      _ => error.message ?? 'Authentication failed (${error.code}).',
    };
  }
}
