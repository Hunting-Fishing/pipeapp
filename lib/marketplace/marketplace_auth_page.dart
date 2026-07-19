import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'marketplace_profile_page.dart';
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _statusIsError
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _statusIsError
                                ? Colors.red.shade200
                                : Colors.green.shade200),
                      ),
                      child: Row(children: [
                        Icon(
                            _statusIsError
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: _statusIsError
                                ? Colors.red.shade700
                                : Colors.green.shade700),
                        const SizedBox(width: 9),
                        Expanded(child: Text(_statusMessage!))
                      ]),
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
                    TextButton(
                        onPressed: _busy ? null : _resetPassword,
                        child: const Text('Forgot password?')),
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
        final phoneKey = normalizedPhone.replaceAll(RegExp(r'\D'), '');
        final batch = FirebaseFirestore.instance.batch();
        batch.set(
            FirebaseFirestore.instance
                .collection('account_phone_registry')
                .doc(phoneKey),
            {
              'uid': uid,
              'phoneE164': normalizedPhone,
              'createdAt': FieldValue.serverTimestamp(),
            });
        batch.set(FirebaseFirestore.instance.collection('users').doc(uid), {
          'uid': uid,
          'email': _email.text.trim(),
          'display_name': _name.text.trim(),
          'phone_number': formatPhoneNumber(normalizedPhone),
          'phoneE164': normalizedPhone,
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
        await credential.user?.sendEmailVerification();
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => MarketplaceProfilePage(
                  onboarding: true,
                  initialAccountType: _accountType,
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

  Future<void> _resetPassword() async {
    if (_email.text.trim().isEmpty) {
      return _notice('Enter your email address first.',
          error: true, icon: Icons.email_outlined);
    }
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _email.text.trim());
      _notice('Password reset email sent. Check your inbox and spam folder.',
          error: false, icon: Icons.mark_email_read_outlined);
    } on FirebaseAuthException catch (error) {
      _notice(_friendlyAuthError(error),
          error: true, icon: _authErrorIcon(error.code));
    }
  }

  void _notice(String text,
      {bool error = false, IconData icon = Icons.info_outline}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = text;
      _statusIsError = error;
    });
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? Colors.red.shade800 : Colors.green.shade700,
      content: Row(children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(text))
      ]),
    ));
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
