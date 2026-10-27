import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';

const String defaultPipeBuyerOrigin = 'https://pipebuyer.com';

/// Builds [ActionCodeSettings] that return users directly to Pipe Buyer after
/// clicking an email verification or password-reset link.
ActionCodeSettings marketplaceEmailActionCodeSettings({
  String returnPath = '/?emailVerified=1',
  Uri? currentUri,
}) {
  final origin = resolvePipeBuyerActionOrigin(currentUri: currentUri);
  final normalizedPath =
      returnPath.startsWith('/') ? returnPath : '/$returnPath';
  return ActionCodeSettings(
    url: '$origin$normalizedPath',
    handleCodeInApp: false,
  );
}

String resolvePipeBuyerActionOrigin({Uri? currentUri}) {
  final uri = currentUri ?? (kIsWeb ? Uri.base : null);
  if (uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      _isAuthorizedPipeBuyerActionHost(uri.host)) {
    return uri.origin;
  }
  return defaultPipeBuyerOrigin;
}

bool _isAuthorizedPipeBuyerActionHost(String rawHost) {
  final host = rawHost.trim().toLowerCase();
  if (host.isEmpty) return false;
  return host == 'pipebuyer.com' ||
      host == 'www.pipebuyer.com' ||
      host.endsWith('.pipebuyer.com') ||
      host.endsWith('.web.app') ||
      host.endsWith('.firebaseapp.com') ||
      host == 'localhost' ||
      host == '127.0.0.1';
}

bool isFirebaseAuthActionMode(String? rawMode) {
  final normalized = rawMode?.trim().toLowerCase() ?? '';
  return normalized == 'verifyemail' ||
      normalized == 'verifyandchangeemail' ||
      normalized == 'resetpassword' ||
      normalized == 'recoveremail';
}

String resolveSafeContinueRoute(String? continueUrl) {
  final trimmed = continueUrl?.trim() ?? '';
  if (trimmed.isEmpty) return '/';
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null) return '/';
  if (!parsed.hasScheme) {
    final path = parsed.path.startsWith('/') ? parsed.path : '/${parsed.path}';
    if (path.startsWith('/auth/action') || path.startsWith('/__/auth/action')) {
      return '/';
    }
    return Uri(
      path: path,
      queryParameters:
          parsed.queryParameters.isEmpty ? null : parsed.queryParameters,
    ).toString();
  }
  if (!_isAuthorizedPipeBuyerActionHost(parsed.host)) {
    return '/';
  }
  final path = parsed.path.isEmpty ? '/' : parsed.path;
  if (path.startsWith('/auth/action') || path.startsWith('/__/auth/action')) {
    return '/';
  }
  return Uri(
    path: path,
    queryParameters:
        parsed.queryParameters.isEmpty ? null : parsed.queryParameters,
  ).toString();
}

enum _AuthActionStatus {
  processing,
  verified,
  awaitingNewPassword,
  passwordUpdated,
  emailRecovered,
  failed,
}

/// Branded in-app handler for email verification, password reset, and email
/// recovery links on `pipebuyer.com/auth/action` so users never get stranded on
/// a generic `firebaseapp.com` action screen.
class MarketplaceAuthActionPage extends StatefulWidget {
  const MarketplaceAuthActionPage({
    super.key,
    required this.mode,
    required this.oobCode,
    this.continueUrl,
    this.autoRedirectDelay = const Duration(milliseconds: 950),
    this.applyActionCodeOverride,
    this.verifyPasswordResetCodeOverride,
    this.confirmPasswordResetOverride,
    this.onNavigateRoute,
  });

  final String mode;
  final String oobCode;
  final String? continueUrl;
  final Duration autoRedirectDelay;
  final Future<void> Function(String code)? applyActionCodeOverride;
  final Future<String?> Function(String code)? verifyPasswordResetCodeOverride;
  final Future<void> Function(String code, String newPassword)?
      confirmPasswordResetOverride;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<MarketplaceAuthActionPage> createState() =>
      _MarketplaceAuthActionPageState();
}

class _MarketplaceAuthActionPageState extends State<MarketplaceAuthActionPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  _AuthActionStatus _status = _AuthActionStatus.processing;
  String? _accountEmail;
  String? _message;
  bool _submittingPassword = false;
  bool _obscurePassword = true;
  Timer? _redirectTimer;

  String get _normalizedMode => widget.mode.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    unawaited(_processAction());
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _processAction() async {
    final code = widget.oobCode.trim();
    if (code.isEmpty || !isFirebaseAuthActionMode(widget.mode)) {
      if (!mounted) return;
      setState(() {
        _status = _AuthActionStatus.failed;
        _message =
            'This email verification link is incomplete. Open Pipe Buyer to continue or request a fresh email.';
      });
      return;
    }

    switch (_normalizedMode) {
      case 'verifyemail':
      case 'verifyandchangeemail':
        await _handleVerifyEmail(code);
        return;
      case 'resetpassword':
        await _handlePreparePasswordReset(code);
        return;
      case 'recoveremail':
        await _handleRecoverEmail(code);
        return;
      default:
        if (!mounted) return;
        setState(() {
          _status = _AuthActionStatus.failed;
          _message = 'This link action is not recognized.';
        });
    }
  }

  Future<void> _handleVerifyEmail(String code) async {
    try {
      if (widget.applyActionCodeOverride != null) {
        await widget.applyActionCodeOverride!(code);
      } else {
        await FirebaseAuth.instance.applyActionCode(code);
        await _refreshAndSyncCurrentUserBestEffort();
      }
      if (!mounted) return;
      setState(() {
        _status = _AuthActionStatus.verified;
        _message =
            'Your email address is verified. Redirecting you into Pipe Buyer…';
      });
      _scheduleAutoRedirect();
    } on FirebaseAuthException catch (error) {
      final alreadyVerified = await _isCurrentUserAlreadyVerified();
      if (!mounted) return;
      if (alreadyVerified) {
        setState(() {
          _status = _AuthActionStatus.verified;
          _message =
              'Your email address is already verified. Taking you into Pipe Buyer…';
        });
        _scheduleAutoRedirect();
        return;
      }
      setState(() {
        _status = _AuthActionStatus.failed;
        _message = _friendlyActionError(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _AuthActionStatus.failed;
        _message =
            'We could not complete email verification right now. You can still open Pipe Buyer and try again from Account > Verification & Security.';
      });
    }
  }

  Future<void> _handlePreparePasswordReset(String code) async {
    try {
      final email = widget.verifyPasswordResetCodeOverride != null
          ? await widget.verifyPasswordResetCodeOverride!(code)
          : await FirebaseAuth.instance.verifyPasswordResetCode(code);
      if (!mounted) return;
      setState(() {
        _accountEmail = email;
        _status = _AuthActionStatus.awaitingNewPassword;
        _message = null;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _AuthActionStatus.failed;
        _message = _friendlyActionError(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _AuthActionStatus.failed;
        _message =
            'This password reset link is no longer valid. Request a new password reset email from Sign In.';
      });
    }
  }

  Future<void> _submitNewPassword() async {
    if (!(_formKey.currentState?.validate() ?? false) || _submittingPassword) {
      return;
    }
    setState(() {
      _submittingPassword = true;
      _message = null;
    });
    final code = widget.oobCode.trim();
    final password = _newPassword.text;
    try {
      if (widget.confirmPasswordResetOverride != null) {
        await widget.confirmPasswordResetOverride!(code, password);
      } else {
        await FirebaseAuth.instance.confirmPasswordReset(
          code: code,
          newPassword: password,
        );
      }
      if (!mounted) return;
      setState(() {
        _submittingPassword = false;
        _status = _AuthActionStatus.passwordUpdated;
        _message =
            'Your password has been updated. Redirecting you to Pipe Buyer…';
      });
      _scheduleAutoRedirect();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _submittingPassword = false;
        _message = _friendlyActionError(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submittingPassword = false;
        _message = 'Could not update your password. Please try again.';
      });
    }
  }

  Future<void> _handleRecoverEmail(String code) async {
    try {
      if (widget.applyActionCodeOverride != null) {
        await widget.applyActionCodeOverride!(code);
      } else {
        final info = await FirebaseAuth.instance.checkActionCode(code);
        _accountEmail = info.data['email'];
        await FirebaseAuth.instance.applyActionCode(code);
        await _refreshAndSyncCurrentUserBestEffort();
      }
      if (!mounted) return;
      setState(() {
        _status = _AuthActionStatus.emailRecovered;
        _message =
            'Your sign-in email address has been restored. Taking you back to Pipe Buyer…';
      });
      _scheduleAutoRedirect();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _AuthActionStatus.failed;
        _message = _friendlyActionError(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _AuthActionStatus.failed;
        _message = 'This recovery link could not be applied.';
      });
    }
  }

  Future<void> _refreshAndSyncCurrentUserBestEffort() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      await MarketplaceCommandClient().execute(
        'syncAccountVerification',
        const {},
        timeout: const Duration(seconds: 6),
      );
    } catch (_) {
      // Non-blocking: verification is already recorded in Firebase Auth.
    }
  }

  Future<bool> _isCurrentUserAlreadyVerified() async {
    if (widget.applyActionCodeOverride != null) return false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed?.emailVerified == true) {
        unawaited(_refreshAndSyncCurrentUserBestEffort());
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _scheduleAutoRedirect() {
    _redirectTimer?.cancel();
    _redirectTimer = Timer(widget.autoRedirectDelay, _openPipeBuyer);
  }

  void _openPipeBuyer() {
    _redirectTimer?.cancel();
    if (!mounted) return;
    final target = resolveSafeContinueRoute(widget.continueUrl);
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(target);
      return;
    }
    context.go(target);
  }

  String _friendlyActionError(FirebaseAuthException error) =>
      switch (error.code) {
        'expired-action-code' =>
          'This email link has expired. Open Pipe Buyer and send a fresh link anytime from Account > Verification & Security.',
        'invalid-action-code' =>
          'This email link has already been used or is no longer active. If you already verified your email, continue straight into Pipe Buyer.',
        'user-disabled' =>
          'This account has been disabled. Contact Pipe Buyer support if you need assistance.',
        'weak-password' => 'Choose a stronger password with at least 8 characters.',
        _ => error.message ?? 'This email link could not be completed.',
      };

  @override
  Widget build(BuildContext context) {
    final title = switch (_status) {
      _AuthActionStatus.processing => _normalizedMode == 'resetpassword'
          ? 'Checking your reset link…'
          : 'Verifying your email…',
      _AuthActionStatus.verified => 'Email verified',
      _AuthActionStatus.awaitingNewPassword => 'Choose a new password',
      _AuthActionStatus.passwordUpdated => 'Password updated',
      _AuthActionStatus.emailRecovered => 'Sign-in email restored',
      _AuthActionStatus.failed => 'Link already used or expired',
    };

    final icon = switch (_status) {
      _AuthActionStatus.processing => Icons.mark_email_read_outlined,
      _AuthActionStatus.verified ||
      _AuthActionStatus.passwordUpdated ||
      _AuthActionStatus.emailRecovered =>
        Icons.verified_rounded,
      _AuthActionStatus.awaitingNewPassword => Icons.lock_reset_rounded,
      _AuthActionStatus.failed => Icons.info_outline_rounded,
    };

    final accent = switch (_status) {
      _AuthActionStatus.verified ||
      _AuthActionStatus.passwordUpdated ||
      _AuthActionStatus.emailRecovered =>
        PipeBuyerColors.success,
      _AuthActionStatus.failed => PipeBuyerColors.warning,
      _ => PipeBuyerColors.orange,
    };

    return Scaffold(
      backgroundColor: PipeBuyerColors.ink,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(icon, color: accent, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PIPE BUYER',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                    color: PipeBuyerColors.orange,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_status == _AuthActionStatus.processing) ...[
                        const LinearProgressIndicator(minHeight: 6),
                        const SizedBox(height: 14),
                        const Text(
                          'Confirming your request securely and preparing Pipe Buyer…',
                          style: TextStyle(color: PipeBuyerColors.muted),
                        ),
                      ] else if (_status ==
                          _AuthActionStatus.awaitingNewPassword) ...[
                        if ((_accountEmail ?? '').isNotEmpty) ...[
                          Text(
                            'Resetting password for $_accountEmail',
                            style: const TextStyle(
                              color: PipeBuyerColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _newPassword,
                                obscureText: _obscurePassword,
                                autofillHints: const [AutofillHints.newPassword],
                                decoration: InputDecoration(
                                  labelText: 'New password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                    icon: Icon(_obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.length < 8) {
                                    return 'Use at least 8 characters.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPassword,
                                obscureText: _obscurePassword,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm new password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                validator: (value) {
                                  if (value != _newPassword.text) {
                                    return 'Passwords do not match.';
                                  }
                                  return null;
                                },
                              ),
                              if (_message != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _message!,
                                  style: const TextStyle(
                                    color: PipeBuyerColors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _submittingPassword
                                    ? null
                                    : _submitNewPassword,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                ),
                                icon: const Icon(Icons.check_rounded),
                                label: Text(_submittingPassword
                                    ? 'Saving…'
                                    : 'Save new password'),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        if (_message != null)
                          Text(
                            _message!,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _openPipeBuyer,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Open Pipe Buyer'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
