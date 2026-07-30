import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../flutter_flow/nav/nav.dart';
import '../core/accessibility/pipe_status_feedback.dart';
import '../core/diagnostics/app_diagnostics.dart';
import 'marketplace_account_device_repository.dart';
import 'marketplace_command_client.dart';

const marketplaceWebPushVapidKey =
    String.fromEnvironment('PIPE_FIREBASE_WEB_PUSH_VAPID_KEY');

enum MarketplaceNotificationStatus {
  enabled,
  notEnabled,
  denied,
  unsupported,
  missingWebConfiguration,
  unavailable,
}

class MarketplaceNotificationService {
  MarketplaceNotificationService._();

  static final instance = MarketplaceNotificationService._();
  static const _tokenPreference = 'pipe_notification_token_v1';
  static const _enabledPreference = 'pipe_notifications_enabled_v1';

  final _messaging = FirebaseMessaging.instance;
  final _commands = MarketplaceCommandClient();
  final _devices = MarketplaceAccountDeviceRepository();
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _openedMessage;
  StreamSubscription<RemoteMessage>? _foregroundMessage;
  StreamSubscription<User?>? _authState;
  bool _navigationReady = false;
  String? _activeUid;

  bool get _supportedPlatform => kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<MarketplaceNotificationStatus> status() async {
    if (!_supportedPlatform) {
      return MarketplaceNotificationStatus.unsupported;
    }
    if (kIsWeb && marketplaceWebPushVapidKey.trim().isEmpty) {
      return MarketplaceNotificationStatus.missingWebConfiguration;
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(_enabledPreference) != true) {
        return MarketplaceNotificationStatus.notEnabled;
      }
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return MarketplaceNotificationStatus.denied;
      }
      final enabled = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      return enabled
          ? MarketplaceNotificationStatus.enabled
          : MarketplaceNotificationStatus.notEnabled;
    } catch (error, stackTrace) {
      AppDiagnostics.record(
        error,
        stackTrace,
        subsystem: 'notifications',
        operation: 'read_permission_status',
        fatal: false,
      );
      return MarketplaceNotificationStatus.unavailable;
    }
  }

  Future<MarketplaceNotificationStatus> enable() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to enable device notifications.');
    if (!user.emailVerified) {
      throw StateError('Verify your email before enabling device notifications.');
    }
    if (!_supportedPlatform) {
      return MarketplaceNotificationStatus.unsupported;
    }
    if (kIsWeb && marketplaceWebPushVapidKey.trim().isEmpty) {
      return MarketplaceNotificationStatus.missingWebConfiguration;
    }
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return MarketplaceNotificationStatus.denied;
      }
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return MarketplaceNotificationStatus.notEnabled;
      }
      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? marketplaceWebPushVapidKey.trim() : null,
      );
      if (token == null || token.trim().length < 20) {
        throw StateError(
          'This device did not provide a notification address. Restart the app and try again.',
        );
      }
      await _registerToken(token);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_tokenPreference, token);
      await preferences.setBool(_enabledPreference, true);
      _listenForTokenRefresh();
      return MarketplaceNotificationStatus.enabled;
    } catch (error, stackTrace) {
      AppDiagnostics.record(
        error,
        stackTrace,
        subsystem: 'notifications',
        operation: 'enable_device_notifications',
        fatal: false,
      );
      rethrow;
    }
  }

  Future<MarketplaceNotificationStatus> disable() async {
    if (!_supportedPlatform) return MarketplaceNotificationStatus.unsupported;
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenPreference)?.trim() ?? '';
    try {
      if (token.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
        await _commands.execute('unregisterNotificationEndpoint', {
          'token': token,
          'platform': _platform,
          'installationId': await _devices.installationId(),
        });
      }
      await _messaging.deleteToken();
      await preferences.remove(_tokenPreference);
      await preferences.setBool(_enabledPreference, false);
      await _tokenRefresh?.cancel();
      _tokenRefresh = null;
      return MarketplaceNotificationStatus.notEnabled;
    } catch (error, stackTrace) {
      AppDiagnostics.record(
        error,
        stackTrace,
        subsystem: 'notifications',
        operation: 'disable_device_notifications',
        fatal: false,
      );
      rethrow;
    }
  }

  Future<void> initializeNavigation() async {
    if (_navigationReady || !_supportedPlatform) return;
    _navigationReady = true;
    _authState = FirebaseAuth.instance.authStateChanges().listen(_handleAuthState);
    _openedMessage = FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
    _foregroundMessage = FirebaseMessaging.onMessage.listen((message) {
      final context = appNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      PipeFeedback.show(
        context,
        message: message.notification?.title?.trim().isNotEmpty == true
            ? message.notification!.title!
            : 'New Pipe Buyer activity',
        tone: PipeStatusTone.info,
      );
    });
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openMessage(initial));
    }
    await _handleAuthState(FirebaseAuth.instance.currentUser);
  }

  Future<void> _registerToken(String token) async {
    await _commands.execute('registerNotificationEndpoint', {
      'token': token.trim(),
      'platform': _platform,
      'installationId': await _devices.installationId(),
    });
  }

  void _listenForTokenRefresh() {
    if (_tokenRefresh != null) return;
    _tokenRefresh = _messaging.onTokenRefresh.listen((token) async {
      try {
        await _registerToken(token);
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(_tokenPreference, token);
      } catch (error, stackTrace) {
        AppDiagnostics.record(
          error,
          stackTrace,
          subsystem: 'notifications',
          operation: 'refresh_device_endpoint',
          fatal: false,
        );
      }
    });
  }

  Future<void> _handleAuthState(User? user) async {
    final previousUid = _activeUid;
    _activeUid = user?.uid;
    if (user == null || (previousUid != null && previousUid != user.uid)) {
      await _tokenRefresh?.cancel();
      _tokenRefresh = null;
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_tokenPreference);
      await preferences.setBool(_enabledPreference, false);
      try {
        await _messaging.deleteToken();
      } catch (error, stackTrace) {
        AppDiagnostics.record(
          error,
          stackTrace,
          subsystem: 'notifications',
          operation: 'remove_signed_out_endpoint',
          fatal: false,
        );
      }
      if (user == null) return;
    }
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_enabledPreference) != true ||
        !user.emailVerified) {
      return;
    }
    try {
      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? marketplaceWebPushVapidKey.trim() : null,
      );
      if (token != null && token.trim().length >= 20) {
        await _registerToken(token);
        await preferences.setString(_tokenPreference, token);
        _listenForTokenRefresh();
      }
    } catch (error, stackTrace) {
      AppDiagnostics.record(
        error,
        stackTrace,
        subsystem: 'notifications',
        operation: 'restore_signed_in_endpoint',
        fatal: false,
      );
    }
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  void _openMessage(RemoteMessage message) {
    final route = '${message.data['route'] ?? ''}'.trim();
    if (!_safeRoute(route)) return;
    final context = appNavigatorKey.currentContext;
    if (context != null) GoRouter.of(context).go(route);
  }

  bool _safeRoute(String route) =>
      RegExp(r'^/(listings|auctions|profiles|conversations)/[A-Za-z0-9_-]{1,160}$')
          .hasMatch(route) ||
      RegExp(r'^/dispatch/jobs/[A-Za-z0-9_-]{1,160}$').hasMatch(route);

  Future<void> dispose() async {
    await _tokenRefresh?.cancel();
    await _openedMessage?.cancel();
    await _foregroundMessage?.cancel();
    await _authState?.cancel();
  }
}
