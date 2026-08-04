import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Completes a Firebase SMS multi-factor challenge after the first sign-in
/// factor succeeds.
Future<UserCredential> resolveFirebaseMultiFactorSignIn({
  required BuildContext context,
  required FirebaseAuthMultiFactorException exception,
  FirebaseAuth? auth,
}) async {
  final resolver = exception.resolver;
  final phoneHints = resolver.hints.whereType<PhoneMultiFactorInfo>().toList();
  if (phoneHints.isEmpty) {
    throw FirebaseAuthException(
      code: 'unsupported-second-factor',
      message:
          'This account has no supported SMS second factor. Contact support to recover access.',
    );
  }

  final selected = phoneHints.length == 1
      ? phoneHints.first
      : await _selectPhoneFactor(context, phoneHints);
  if (selected == null) {
    throw FirebaseAuthException(
      code: 'mfa-cancelled',
      message: 'Second-factor verification was cancelled.',
    );
  }

  final result = Completer<UserCredential>();
  final firebaseAuth = auth ?? FirebaseAuth.instance;

  Future<void> resolve(PhoneAuthCredential credential) async {
    if (result.isCompleted) return;
    try {
      final signedIn = await resolver.resolveSignIn(
        PhoneMultiFactorGenerator.getAssertion(credential),
      );
      if (!result.isCompleted) result.complete(signedIn);
    } catch (error, stackTrace) {
      if (!result.isCompleted) result.completeError(error, stackTrace);
    }
  }

  await firebaseAuth.verifyPhoneNumber(
    multiFactorSession: resolver.session,
    multiFactorInfo: selected,
    verificationCompleted: resolve,
    verificationFailed: (error) {
      if (!result.isCompleted) {
        result.completeError(error, StackTrace.current);
      }
    },
    codeSent: (verificationId, _) async {
      if (result.isCompleted) return;
      if (!context.mounted) {
        result.completeError(
          FirebaseAuthException(
            code: 'mfa-cancelled',
            message: 'The verification screen was closed.',
          ),
          StackTrace.current,
        );
        return;
      }
      final code = await _requestSmsCode(context, selected);
      if (code == null) {
        if (!result.isCompleted) {
          result.completeError(
            FirebaseAuthException(
              code: 'mfa-cancelled',
              message: 'Second-factor verification was cancelled.',
            ),
            StackTrace.current,
          );
        }
        return;
      }
      await resolve(PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      ));
    },
    codeAutoRetrievalTimeout: (_) {},
  );

  return result.future.timeout(
    const Duration(minutes: 5),
    onTimeout: () => throw FirebaseAuthException(
      code: 'mfa-timeout',
      message: 'The second-factor verification timed out. Request a new code.',
    ),
  );
}

Future<PhoneMultiFactorInfo?> _selectPhoneFactor(
  BuildContext context,
  List<PhoneMultiFactorInfo> factors,
) {
  return showDialog<PhoneMultiFactorInfo>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.phonelink_lock_outlined, size: 36),
      title: const Text('Choose a verification phone'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select the enrolled SMS factor that should receive the sign-in code.',
            ),
            const SizedBox(height: 12),
            ...factors.map(
              (factor) => ListTile(
                leading: const Icon(Icons.sms_outlined),
                title: Text(
                  factor.displayName?.trim().isNotEmpty == true
                      ? factor.displayName!
                      : 'SMS verification',
                ),
                subtitle: Text(factor.phoneNumber),
                onTap: () => Navigator.pop(dialogContext, factor),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

Future<String?> _requestSmsCode(
  BuildContext context,
  PhoneMultiFactorInfo factor,
) async {
  final controller = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.sms_outlined, size: 36),
        title: const Text('Enter your security code'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Firebase sent a six-digit code to ${factor.phoneNumber}.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '6-digit SMS code',
                  prefixIcon: Icon(Icons.password_outlined),
                ),
                onSubmitted: (value) {
                  final code = value.trim();
                  if (RegExp(r'^\d{6}$').hasMatch(code)) {
                    Navigator.pop(dialogContext, code);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final code = controller.text.trim();
              if (!RegExp(r'^\d{6}$').hasMatch(code)) return;
              Navigator.pop(dialogContext, code);
            },
            child: const Text('Verify and sign in'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
