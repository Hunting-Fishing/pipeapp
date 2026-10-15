import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'marketplace_command_client.dart';
import 'marketplace_subscription_billing_policy.dart';

const nativeMembershipProductIds = <String, String>{
  'dispatch_monthly': 'pipebuyer_dispatch_monthly',
  'dispatch_yearly': 'pipebuyer_dispatch_yearly',
  'vip_monthly': 'pipebuyer_vip_monthly',
};

const nativeMembershipTermsUrl = 'https://www.pipebuyer.com/terms';
const nativeMembershipPrivacyUrl = 'https://www.pipebuyer.com/privacy';

String? nativeMembershipPlatformName({TargetPlatform? platform}) {
  final value = platform ?? defaultTargetPlatform;
  return switch (value) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => null,
  };
}

int nativeMembershipPlanRank(String plan) => switch (plan) {
      'vip_monthly' => 2,
      'dispatch_monthly' || 'dispatch_yearly' => 1,
      _ => 0,
    };

ReplacementMode nativeAndroidReplacementMode({
  required String currentPlan,
  required String targetPlan,
}) {
  if (nativeMembershipPlanRank(targetPlan) >
      nativeMembershipPlanRank(currentPlan)) {
    return ReplacementMode.withTimeProration;
  }
  return ReplacementMode.deferred;
}

String nativeMembershipPlanLabel(String plan) => switch (plan) {
      'dispatch_monthly' => 'Monthly',
      'dispatch_yearly' => 'Yearly',
      'vip_monthly' => 'VIP',
      _ => 'Membership',
    };

bool nativePurchaseIntentMatchesUpdate({
  required String intentPlatform,
  required String intentProductId,
  required String intentOwnerUid,
  required bool restore,
  required String updatePlatform,
  required String updateProductId,
  required String currentOwnerUid,
}) {
  if (intentPlatform.isEmpty ||
      intentPlatform != updatePlatform ||
      intentOwnerUid.isEmpty ||
      intentOwnerUid != currentOwnerUid) {
    return false;
  }
  return intentProductId == updateProductId ||
      (restore && intentProductId == '*');
}

bool nativePurchaseTerminalMayReleaseIntent({
  required bool accountPlatformProductMatch,
  required bool exactProviderAttemptBound,
}) =>
    accountPlatformProductMatch && exactProviderAttemptBound;

class NativeMembershipPurchaseEvent {
  const NativeMembershipPurchaseEvent({
    required this.productId,
    required this.message,
    this.verified = false,
  });

  final String productId;
  final String message;
  final bool verified;
}

typedef _NativePurchaseIntentRecord = ({
  String token,
  String platform,
  String productId,
  String ownerUid,
  bool restore,
});

class _NativeProviderAttempt {
  const _NativeProviderAttempt({
    required this.token,
    required this.platform,
    required this.productId,
    required this.ownerUid,
  });

  final String token;
  final String platform;
  final String productId;
  final String ownerUid;
}

class NativeMembershipPurchaseCoordinator {
  NativeMembershipPurchaseCoordinator._();

  static final instance = NativeMembershipPurchaseCoordinator._();

  static const _intentRecordKeyPrefix =
      'pipeBuyerNativeMembershipIntentRecord:';

  final _commands = MarketplaceCommandClient();
  final _iap = InAppPurchase.instance;
  final _events = StreamController<NativeMembershipPurchaseEvent>.broadcast();
  final _deferredPurchases = <String, PurchaseDetails>{};
  final _intentMemory = <String, _NativePurchaseIntentRecord>{};
  Future<void> _work = Future<void>.value();
  Future<void> _intentStorageWork = Future<void>.value();
  final _activeRestoreIntentTokens = <String, String>{};
  _NativeProviderAttempt? _activeProviderAttempt;
  bool _initialized = false;

  Stream<NativeMembershipPurchaseEvent> get events => _events.stream;

  Future<void> initialize() async {
    if (_initialized || kIsWeb || nativeMembershipPlatformName() == null)
      return;
    _initialized = true;
    _iap.purchaseStream.listen(
      (purchases) => _enqueue(() => _handlePurchaseUpdates(purchases)),
      onError: (Object error) => _events.add(
        const NativeMembershipPurchaseEvent(
          productId: '',
          message: 'The app store purchase could not be completed.',
        ),
      ),
    );
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && _deferredPurchases.isNotEmpty) {
        final purchases = _deferredPurchases.values.toList(growable: false);
        _deferredPurchases.clear();
        _enqueue(() => _handlePurchaseUpdates(purchases));
      }
    });
  }

  void _enqueue(Future<void> Function() operation) {
    _work = _work.then((_) => operation()).catchError((Object _) {});
  }

  Future<T> _serializeIntentStorage<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _intentStorageWork = _intentStorageWork.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<bool> savePurchaseIntent({
    required String token,
    required String platform,
    required String productId,
    required String ownerUid,
    required bool restore,
  }) =>
      _serializeIntentStorage(() => _savePurchaseIntentUnlocked(
            token: token,
            platform: platform,
            productId: productId,
            ownerUid: ownerUid,
            restore: restore,
          ));

  Future<bool> _savePurchaseIntentUnlocked({
    required String token,
    required String platform,
    required String productId,
    required String ownerUid,
    required bool restore,
  }) async {
    final record = (
      token: token,
      platform: platform,
      productId: productId,
      ownerUid: ownerUid,
      restore: restore,
    );
    _intentMemory[ownerUid] = record;
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(<String, Object?>{
      'token': token,
      'platform': platform,
      'productId': productId,
      'ownerUid': ownerUid,
      'restore': restore,
    });
    final key = '$_intentRecordKeyPrefix$ownerUid';
    final saved = await preferences.setString(key, encoded);
    if (restore) _activeRestoreIntentTokens[ownerUid] = token;
    // SharedPreferences is only a best-effort cache. The authenticated server
    // intent remains authoritative and can be resumed after process loss.
    return saved && preferences.getString(key) == encoded;
  }

  Future<_NativePurchaseIntentRecord> _loadPurchaseIntent(String ownerUid) =>
      _serializeIntentStorage(() => _loadPurchaseIntentUnlocked(ownerUid));

  Future<_NativePurchaseIntentRecord> _loadPurchaseIntentUnlocked(
      String ownerUid) async {
    final inMemory = _intentMemory[ownerUid];
    if (inMemory != null) return inMemory;
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString('$_intentRecordKeyPrefix$ownerUid');
    try {
      final value = encoded == null ? null : jsonDecode(encoded);
      final record = value is Map ? Map<String, dynamic>.from(value) : null;
      if (record == null || '${record['ownerUid'] ?? ''}' != ownerUid) {
        throw const FormatException('intent owner mismatch');
      }
      final intent = (
        token: '${record['token'] ?? ''}',
        platform: '${record['platform'] ?? ''}',
        productId: '${record['productId'] ?? ''}',
        ownerUid: '${record['ownerUid'] ?? ''}',
        restore: record['restore'] == true,
      );
      if (intent.token.isNotEmpty) _intentMemory[ownerUid] = intent;
      return intent;
    } catch (_) {
      return (
        token: '',
        platform: '',
        productId: '',
        ownerUid: ownerUid,
        restore: false,
      );
    }
  }

  Future<bool> clearPurchaseIntentIfMatches({
    required String intentToken,
    required String ownerUid,
  }) =>
      _serializeIntentStorage(() => _clearPurchaseIntentIfMatchesUnlocked(
            intentToken: intentToken,
            ownerUid: ownerUid,
          ));

  Future<bool> _clearPurchaseIntentIfMatchesUnlocked({
    required String intentToken,
    required String ownerUid,
  }) async {
    if (intentToken.isEmpty || ownerUid.isEmpty) return false;
    final preferences = await SharedPreferences.getInstance();
    final key = '$_intentRecordKeyPrefix$ownerUid';
    final current = await _loadPurchaseIntentUnlocked(ownerUid);
    if (current.token != intentToken || current.ownerUid != ownerUid) {
      return false;
    }
    final removed = await preferences.remove(key);
    if (!removed && preferences.getString(key) != null) return false;
    _intentMemory.remove(ownerUid);
    if (_activeRestoreIntentTokens[ownerUid] == intentToken) {
      _activeRestoreIntentTokens.remove(ownerUid);
    }
    return true;
  }

  Future<void> releasePurchaseIntent(String token) async {
    if (token.isEmpty) return;
    try {
      await _commands.execute(
        'releaseNativeMembershipPurchaseIntent',
        <String, Object?>{'purchaseIntentToken': token},
      );
    } catch (_) {
      // The bounded server TTL remains the fail-safe if release cannot be sent.
    }
  }

  bool beginProviderAttempt({
    required String token,
    required String platform,
    required String productId,
    required String ownerUid,
  }) {
    if (_activeProviderAttempt != null) return false;
    _activeProviderAttempt = _NativeProviderAttempt(
      token: token,
      platform: platform,
      productId: productId,
      ownerUid: ownerUid,
    );
    return true;
  }

  bool _matchesActiveProviderAttempt({
    required _NativePurchaseIntentRecord intent,
    required String platform,
    required String productId,
    required String ownerUid,
  }) {
    final attempt = _activeProviderAttempt;
    return attempt != null &&
        attempt.token == intent.token &&
        attempt.platform == platform &&
        attempt.productId == productId &&
        attempt.ownerUid == ownerUid;
  }

  void finishProviderAttempt(String token) {
    if (_activeProviderAttempt?.token == token) _activeProviderAttempt = null;
  }

  Future<_NativePurchaseIntentRecord> _resolvePurchaseIntent({
    required String ownerUid,
    required String platform,
    required PurchaseDetails purchase,
  }) async {
    // Verification already requires the server. Resolve its authoritative
    // record first so a stale same-product cache token can never shadow a newer
    // preflight intent after a process crash.
    final resumed = await _commands.execute(
      'resumeNativeMembershipPurchaseIntent',
      <String, Object?>{
        'platform': platform,
        'productId': purchase.productID,
        'restore': purchase.status == PurchaseStatus.restored,
      },
    );
    final currentOwnerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final resumedOwnerUid = '${resumed['intentOwnerUid'] ?? ''}'.trim();
    final resumedPlatform = '${resumed['platform'] ?? ''}'.trim();
    final resumedProductId = '${resumed['productId'] ?? ''}'.trim();
    final resumedToken = '${resumed['purchaseIntentToken'] ?? ''}'.trim();
    final restore = resumed['restore'] == true;
    final validProductBinding = resumedProductId == purchase.productID ||
        (restore &&
            purchase.status == PurchaseStatus.restored &&
            resumedProductId == '*');
    if (resumed['found'] != true ||
        currentOwnerUid != ownerUid ||
        resumedOwnerUid != ownerUid ||
        resumedPlatform != platform ||
        resumedToken.isEmpty ||
        !validProductBinding) {
      return (
        token: '',
        platform: '',
        productId: '',
        ownerUid: ownerUid,
        restore: false,
      );
    }
    final recovered = (
      token: resumedToken,
      platform: resumedPlatform,
      productId: resumedProductId,
      ownerUid: resumedOwnerUid,
      restore: restore,
    );
    await savePurchaseIntent(
      token: recovered.token,
      platform: recovered.platform,
      productId: recovered.productId,
      ownerUid: recovered.ownerUid,
      restore: recovered.restore,
    );
    return recovered;
  }

  String _purchaseKey(PurchaseDetails purchase) =>
      '${purchase.productID}:${purchase.purchaseID ?? ''}:'
      '${purchase.verificationData.serverVerificationData.hashCode}';

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    final platform = nativeMembershipPlatformName();
    if (platform == null) return;
    final currentOwnerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (purchases.isEmpty) {
      final intent = await _loadPurchaseIntent(currentOwnerUid);
      final exactActiveRestore = currentOwnerUid.isNotEmpty &&
          intent.restore &&
          intent.productId == '*' &&
          intent.platform == platform &&
          intent.ownerUid == currentOwnerUid &&
          intent.token.isNotEmpty &&
          intent.token == _activeRestoreIntentTokens[currentOwnerUid];
      if (exactActiveRestore) {
        await releasePurchaseIntent(intent.token);
        await clearPurchaseIntentIfMatches(
          intentToken: intent.token,
          ownerUid: intent.ownerUid,
        );
        _events.add(const NativeMembershipPurchaseEvent(
          productId: '*',
          message: 'No store purchases were available to restore.',
        ));
      }
      return;
    }
    if (currentOwnerUid.isEmpty) {
      for (final purchase in purchases) {
        _deferredPurchases[_purchaseKey(purchase)] = purchase;
      }
      return;
    }
    for (final purchase in purchases) {
      if (!nativeMembershipProductIds.values.contains(purchase.productID)) {
        continue;
      }
      _NativePurchaseIntentRecord intent;
      try {
        intent = await _resolvePurchaseIntent(
          ownerUid: currentOwnerUid,
          platform: platform,
          purchase: purchase,
        );
      } catch (_) {
        _deferredPurchases[_purchaseKey(purchase)] = purchase;
        _events.add(NativeMembershipPurchaseEvent(
          productId: purchase.productID,
          message:
              'Pipe Buyer could not recover the store purchase authorization yet. Sign in and retry Restore store purchase.',
        ));
        continue;
      }
      final matchesIntent = intent.token.isNotEmpty &&
          nativePurchaseIntentMatchesUpdate(
            intentPlatform: intent.platform,
            intentProductId: intent.productId,
            intentOwnerUid: intent.ownerUid,
            restore: intent.restore,
            updatePlatform: platform,
            updateProductId: purchase.productID,
            currentOwnerUid: currentOwnerUid,
          );
      if (purchase.status == PurchaseStatus.pending) {
        if (matchesIntent && !intent.restore) {
          try {
            await _commands.execute(
              'markNativeMembershipPurchasePending',
              <String, Object?>{
                'platform': platform,
                'productId': purchase.productID,
                'purchaseIntentToken': intent.token,
              },
            );
          } catch (_) {
            // The initial reservation already spans the approval window.
          }
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        if (matchesIntent) {
          final exactActiveAttempt = _matchesActiveProviderAttempt(
            intent: intent,
            platform: platform,
            productId: purchase.productID,
            ownerUid: currentOwnerUid,
          );
          // StoreKit/Play stream events do not include the server nonce. Even
          // an in-memory same-product attempt cannot prove this is not a stale
          // terminal event from an earlier provider attempt, so retain the
          // bounded server fence. Only a synchronous non-start result releases
          // it. The local attempt may settle so the UI can recover safely.
          if (exactActiveAttempt) finishProviderAttempt(intent.token);
          _events.add(NativeMembershipPurchaseEvent(
            productId: purchase.productID,
            message: purchase.error?.message ??
                'The store purchase was not completed. You can retry it safely.',
          ));
        }
        continue;
      }
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        continue;
      }
      if (!matchesIntent) {
        _deferredPurchases[_purchaseKey(purchase)] = purchase;
        _events.add(NativeMembershipPurchaseEvent(
          productId: purchase.productID,
          message:
              'Use Restore store purchase to securely finish this purchase.',
        ));
        continue;
      }
      try {
        final payload = <String, Object?>{
          'platform': platform,
          'productId': purchase.productID,
          'purchaseIntentToken': intent.token,
          'restore': intent.restore,
        };
        if (platform == 'ios') {
          payload['purchaseId'] = purchase.purchaseID ?? '';
        } else {
          payload['serverVerificationData'] =
              purchase.verificationData.serverVerificationData;
        }
        final result = await _commands.execute(
          'verifyNativeMembershipPurchase',
          payload,
        );
        if (result['verified'] != true) {
          throw StateError(
            'The store purchase was not verified by Pipe Buyer.',
          );
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        await clearPurchaseIntentIfMatches(
          intentToken: intent.token,
          ownerUid: intent.ownerUid,
        );
        finishProviderAttempt(intent.token);
        final currentPlan = '${result['currentPlan'] ?? ''}';
        final pendingPlan = '${result['pendingPlan'] ?? ''}';
        _events.add(NativeMembershipPurchaseEvent(
          productId: purchase.productID,
          verified: true,
          message: pendingPlan.isNotEmpty
              ? '${nativeMembershipPlanLabel(pendingPlan)} is scheduled for the end of the current paid period.'
              : '${nativeMembershipPlanLabel(currentPlan)} membership verified.',
        ));
      } catch (error) {
        _deferredPurchases[_purchaseKey(purchase)] = purchase;
        _events.add(NativeMembershipPurchaseEvent(
          productId: purchase.productID,
          message: marketplaceCommandErrorMessage(
            error,
            fallback:
                'The purchase is still with the store but Pipe Buyer could not verify it yet. Use Restore store purchase to retry.',
          ),
        ));
      }
    }
  }
}

class NativeMembershipPlanButton extends StatefulWidget {
  const NativeMembershipPlanButton({
    super.key,
    required this.targetPlan,
  });

  final String targetPlan;

  @override
  State<NativeMembershipPlanButton> createState() =>
      _NativeMembershipPlanButtonState();
}

class _NativeMembershipPlanButtonState
    extends State<NativeMembershipPlanButton> {
  final _commands = MarketplaceCommandClient();
  final _iap = InAppPurchase.instance;
  final _purchaseCoordinator = NativeMembershipPurchaseCoordinator.instance;
  StreamSubscription<NativeMembershipPurchaseEvent>? _eventSubscription;
  late Future<Map<String, dynamic>> _viewFuture;
  Map<String, dynamic>? _lastView;
  bool _busy = false;
  bool _restoreBusy = false;

  @override
  void initState() {
    super.initState();
    _viewFuture = _loadView();
    _eventSubscription = _purchaseCoordinator.events.listen((event) {
      if (!mounted) return;
      final targetProduct = nativeMembershipProductIds[widget.targetPlan];
      if (event.productId.isNotEmpty &&
          event.productId != '*' &&
          event.productId != targetProduct) {
        return;
      }
      setState(() {
        _busy = false;
        _restoreBusy = false;
      });
      _showMessage(event.message);
      if (event.verified) _reload();
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadView() async {
    final platform = nativeMembershipPlatformName();
    if (kIsWeb || platform == null) {
      return const <String, dynamic>{'supported': false};
    }
    final status = await _commands.execute(
      'getNativeMembershipBillingStatus',
      <String, Object?>{'platform': platform},
    );
    final enabled = status['available'] == true &&
        (platform == 'ios'
            ? status['appleEnabled'] == true
            : status['googleEnabled'] == true);
    if (!enabled) {
      return <String, dynamic>{
        'supported': true,
        'enabled': false,
        'status': status,
      };
    }
    final storeAvailable = await _iap.isAvailable();
    if (!storeAvailable) {
      return <String, dynamic>{
        'supported': true,
        'enabled': true,
        'storeAvailable': false,
        'status': status,
      };
    }
    final platformProductIds = platform == 'ios'
        ? status['appleProductIds']
        : status['googleProductIds'];
    final configuredProductIds =
        platformProductIds is List ? platformProductIds : status['productIds'];
    final productIds = (configuredProductIds is List)
        ? configuredProductIds
            .map((value) => '$value')
            .where(nativeMembershipProductIds.values.contains)
            .toSet()
        : nativeMembershipProductIds.values.toSet();
    final response = await _iap.queryProductDetails(productIds);
    final products = <String, ProductDetails>{
      for (final product in response.productDetails) product.id: product,
    };
    return <String, dynamic>{
      'supported': true,
      'enabled': true,
      'storeAvailable': true,
      'status': status,
      'products': products,
      'notFound': response.notFoundIDs,
      'storeError': response.error?.message ?? '',
    };
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _viewFuture = _loadView());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _viewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                label: const Text('Checking app store…'),
              ),
            );
          }
          if (snapshot.hasError) {
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry mobile billing'),
              ),
            );
          }
          final view = snapshot.data ?? const <String, dynamic>{};
          _lastView = view;
          if (view['supported'] != true) return const SizedBox.shrink();
          final status = view['status'] is Map
              ? Map<String, dynamic>.from(view['status'] as Map)
              : const <String, dynamic>{};
          final currentPlan = '${status['currentPlan'] ?? 'free'}';
          final currentProvider = '${status['currentProvider'] ?? 'free'}';
          final enabled = view['enabled'] == true;
          final storeAvailable = view['storeAvailable'] == true;
          final targetProductId = nativeMembershipProductIds[widget.targetPlan];
          final products = view['products'] is Map
              ? Map<String, ProductDetails>.from(view['products'] as Map)
              : const <String, ProductDetails>{};
          final product =
              targetProductId == null ? null : products[targetProductId];
          final targetLabel = nativeMembershipPlanLabel(widget.targetPlan);

          if (!enabled) {
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.phone_iphone_rounded),
                label:
                    const Text(marketplaceNativeSubscriptionUnavailableMessage),
              ),
            );
          }
          if (status['purchaseBlockedByStripe'] == true ||
              currentProvider == 'stripe') {
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.language_rounded),
                label: const Text('Membership billed on Pipe Buyer web'),
              ),
            );
          }
          if (!storeAvailable || product == null) {
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.storefront_outlined),
                label: Text(
                  !storeAvailable
                      ? 'App store temporarily unavailable'
                      : '$targetLabel store product unavailable',
                ),
              ),
            );
          }

          final isCurrent = currentPlan == widget.targetPlan;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isCurrent)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _openStoreSubscriptionManagement,
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: Text('Manage $targetLabel • ${product.price}'),
                )
              else
                FilledButton.icon(
                  onPressed: _busy || _restoreBusy
                      ? null
                      : () => _startPurchase(product),
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline_rounded),
                  label: Text(
                    _busy
                        ? 'Opening app store…'
                        : currentPlan == 'free'
                            ? 'Subscribe • ${product.price}'
                            : 'Change to $targetLabel • ${product.price}',
                  ),
                ),
              if (widget.targetPlan == 'dispatch_monthly') ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _busy || _restoreBusy ? null : _restorePurchases,
                  icon: _restoreBusy
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore_rounded),
                  label: Text(
                    _restoreBusy ? 'Restoring…' : 'Restore store purchase',
                  ),
                ),
              ],
              if (nativeMembershipPlatformName() == 'ios') ...[
                const SizedBox(height: 8),
                Text(
                  'Payment is charged to your Apple Account at confirmation. '
                  'The subscription renews automatically unless canceled at '
                  'least 24 hours before the current period ends. Manage or '
                  'cancel it in your App Store subscription settings.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _openLegalDocument(
                        nativeMembershipTermsUrl,
                        'Terms of Service',
                      ),
                      child: const Text('Terms of Service'),
                    ),
                    TextButton(
                      onPressed: () => _openLegalDocument(
                        nativeMembershipPrivacyUrl,
                        'Privacy Policy',
                      ),
                      child: const Text('Privacy Policy'),
                    ),
                  ],
                ),
              ],
              if (nativeMembershipPlatformName() == 'android') ...[
                const SizedBox(height: 8),
                Text(
                  'Payment is charged to your Google Play account at '
                  'confirmation. The subscription renews automatically unless '
                  'canceled. The price and billing period shown above are '
                  'supplied by Google Play. Manage or cancel it in your Google '
                  'Play subscription settings.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _openLegalDocument(
                        nativeMembershipTermsUrl,
                        'Terms of Service',
                      ),
                      child: const Text('Terms of Service'),
                    ),
                    TextButton(
                      onPressed: () => _openLegalDocument(
                        nativeMembershipPrivacyUrl,
                        'Privacy Policy',
                      ),
                      child: const Text('Privacy Policy'),
                    ),
                    TextButton(
                      onPressed: _openStoreSubscriptionManagement,
                      child: const Text('Google Play subscriptions'),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      );

  Future<void> _startPurchase(ProductDetails product) async {
    final view = _lastView;
    if (view == null || _busy) return;
    setState(() => _busy = true);
    var purchaseIntentToken = '';
    var releaseIntentOnError = true;
    var intentSavedByThisAttempt = false;
    var intentWasReused = false;
    final initiatingOwnerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final platform = nativeMembershipPlatformName();
      if (platform == null) {
        throw StateError('Mobile store billing is unavailable.');
      }
      final preflight = await _commands.execute(
        'preflightNativeMembershipPurchase',
        <String, Object?>{
          'platform': platform,
          'productId': product.id,
        },
      );
      if (preflight['ready'] != true ||
          '${preflight['productId'] ?? ''}' != product.id) {
        throw StateError('Pipe Buyer could not authorize this store purchase.');
      }
      final accountToken = '${preflight['storeAccountToken'] ?? ''}'.trim();
      purchaseIntentToken = '${preflight['purchaseIntentToken'] ?? ''}'.trim();
      intentWasReused = preflight['purchaseIntentReused'] == true;
      final currentPlan = '${preflight['currentPlan'] ?? 'free'}'.trim();
      final serverOwnerUid = '${preflight['intentOwnerUid'] ?? ''}'.trim();
      final currentOwnerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (accountToken.isEmpty ||
          purchaseIntentToken.isEmpty ||
          initiatingOwnerUid.isEmpty ||
          serverOwnerUid != initiatingOwnerUid ||
          currentOwnerUid != initiatingOwnerUid) {
        throw StateError('Pipe Buyer could not prepare secure store billing.');
      }
      await _purchaseCoordinator.savePurchaseIntent(
        token: purchaseIntentToken,
        platform: platform,
        productId: product.id,
        ownerUid: initiatingOwnerUid,
        restore: false,
      );
      intentSavedByThisAttempt = true;
      PurchaseParam purchaseParam;
      if (platform == 'android') {
        GooglePlayPurchaseDetails? oldPurchase;
        if (currentPlan != 'free') {
          final addition =
              _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
          final previous = await addition.queryPastPurchases(
            applicationUserName: accountToken,
          );
          final currentProductId = nativeMembershipProductIds[currentPlan];
          for (final purchase in previous.pastPurchases) {
            if (purchase.productID == currentProductId) {
              oldPurchase = purchase;
              break;
            }
          }
          if (oldPurchase == null) {
            throw StateError(
              'Google Play could not find the current subscription to change.',
            );
          }
        }
        purchaseParam = GooglePlayPurchaseParam(
          productDetails: product,
          applicationUserName: accountToken,
          changeSubscriptionParam: oldPurchase == null
              ? null
              : ChangeSubscriptionParam(
                  oldPurchaseDetails: oldPurchase,
                  replacementMode: nativeAndroidReplacementMode(
                    currentPlan: currentPlan,
                    targetPlan: widget.targetPlan,
                  ),
                ),
        );
      } else {
        purchaseParam = PurchaseParam(
          productDetails: product,
          applicationUserName: accountToken,
        );
      }
      if (FirebaseAuth.instance.currentUser?.uid != initiatingOwnerUid ||
          !_purchaseCoordinator.beginProviderAttempt(
            token: purchaseIntentToken,
            platform: platform,
            productId: product.id,
            ownerUid: initiatingOwnerUid,
          )) {
        throw StateError(
          'Another store purchase is already being completed securely.',
        );
      }
      // Once StoreKit/Play has been called, an exception can be ambiguous: the
      // provider may still have accepted the purchase. Keep the bounded intent
      // in that case so Stripe cannot race an unseen store transaction.
      releaseIntentOnError = false;
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started) {
        _purchaseCoordinator.finishProviderAttempt(purchaseIntentToken);
        releaseIntentOnError = true;
        throw StateError(
            'The app store did not start the subscription purchase.');
      }
    } catch (error) {
      if (releaseIntentOnError &&
          purchaseIntentToken.isNotEmpty &&
          !intentWasReused) {
        await _purchaseCoordinator.releasePurchaseIntent(purchaseIntentToken);
      }
      if (releaseIntentOnError &&
          intentSavedByThisAttempt &&
          !intentWasReused) {
        await _purchaseCoordinator.clearPurchaseIntentIfMatches(
          intentToken: purchaseIntentToken,
          ownerUid: initiatingOwnerUid,
        );
      }
      if (releaseIntentOnError) {
        _purchaseCoordinator.finishProviderAttempt(purchaseIntentToken);
      }
      if (mounted) {
        _showMessage(
          marketplaceCommandErrorMessage(
            error,
            fallback: 'The store could not start this membership change.',
          ),
        );
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restorePurchases() async {
    final view = _lastView;
    if (view == null || _restoreBusy) return;
    final platform = nativeMembershipPlatformName();
    if (platform == null) return;
    setState(() => _restoreBusy = true);
    var purchaseIntentToken = '';
    var releaseIntentOnError = true;
    var intentSavedByThisAttempt = false;
    var intentWasReused = false;
    final initiatingOwnerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final preflight = await _commands.execute(
        'preflightNativeMembershipRestore',
        <String, Object?>{'platform': platform},
      );
      final accountToken = '${preflight['storeAccountToken'] ?? ''}'.trim();
      purchaseIntentToken = '${preflight['purchaseIntentToken'] ?? ''}'.trim();
      intentWasReused = preflight['purchaseIntentReused'] == true;
      final serverOwnerUid = '${preflight['intentOwnerUid'] ?? ''}'.trim();
      final currentOwnerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (preflight['ready'] != true ||
          accountToken.isEmpty ||
          purchaseIntentToken.isEmpty ||
          initiatingOwnerUid.isEmpty ||
          serverOwnerUid != initiatingOwnerUid ||
          currentOwnerUid != initiatingOwnerUid) {
        throw StateError('Pipe Buyer could not prepare purchase restoration.');
      }
      await _purchaseCoordinator.savePurchaseIntent(
        token: purchaseIntentToken,
        platform: platform,
        productId: '*',
        ownerUid: initiatingOwnerUid,
        restore: true,
      );
      intentSavedByThisAttempt = true;
      releaseIntentOnError = false;
      await _iap.restorePurchases(applicationUserName: accountToken);
    } catch (error) {
      if (releaseIntentOnError &&
          purchaseIntentToken.isNotEmpty &&
          !intentWasReused) {
        await _purchaseCoordinator.releasePurchaseIntent(purchaseIntentToken);
      }
      if (releaseIntentOnError &&
          intentSavedByThisAttempt &&
          !intentWasReused) {
        await _purchaseCoordinator.clearPurchaseIntentIfMatches(
          intentToken: purchaseIntentToken,
          ownerUid: initiatingOwnerUid,
        );
      }
      if (mounted) {
        _showMessage('Store purchases could not be restored right now.');
      }
    } finally {
      if (mounted && _restoreBusy) {
        setState(() => _restoreBusy = false);
      }
    }
  }

  Future<void> _openLegalDocument(String url, String label) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showMessage('$label could not be opened.');
    }
  }

  Future<void> _openStoreSubscriptionManagement() async {
    final platform = nativeMembershipPlatformName();
    final uri = switch (platform) {
      'ios' => Uri.parse('https://apps.apple.com/account/subscriptions'),
      'android' => Uri.parse(
          'https://play.google.com/store/account/subscriptions?package=Pipe.Buyerapp'),
      _ => null,
    };
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('Your app store subscription settings could not be opened.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
