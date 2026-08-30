import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:url_launcher/url_launcher.dart';

import 'marketplace_command_client.dart';
import 'marketplace_subscription_billing_policy.dart';

const nativeMembershipProductIds = <String, String>{
  'dispatch_monthly': 'pipebuyer_dispatch_monthly',
  'dispatch_yearly': 'pipebuyer_dispatch_yearly',
  'vip_monthly': 'pipebuyer_vip_monthly',
};

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
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  late Future<Map<String, dynamic>> _viewFuture;
  Map<String, dynamic>? _lastView;
  bool _busy = false;
  bool _restoreBusy = false;

  @override
  void initState() {
    super.initState();
    _viewFuture = _loadView();
    if (!kIsWeb && nativeMembershipPlatformName() != null) {
      _purchaseSubscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (Object error) {
          if (mounted) {
            _showMessage('The app store purchase could not be completed.');
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadView() async {
    final platform = nativeMembershipPlatformName();
    if (kIsWeb || platform == null) {
      return const <String, dynamic>{'supported': false};
    }
    final status = await _commands.execute(
      'getNativeMembershipBillingStatus',
      const <String, Object?>{},
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
    final productIds = (status['productIds'] is List)
        ? (status['productIds'] as List)
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
          final product = targetProductId == null ? null : products[targetProductId];
          final targetLabel = nativeMembershipPlanLabel(widget.targetPlan);

          if (!enabled) {
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.phone_iphone_rounded),
                label: const Text(marketplaceNativeSubscriptionUnavailableMessage),
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
            ],
          );
        },
      );

  Future<void> _startPurchase(ProductDetails product) async {
    final view = _lastView;
    if (view == null || _busy) return;
    final status = view['status'] is Map
        ? Map<String, dynamic>.from(view['status'] as Map)
        : const <String, dynamic>{};
    final accountToken = '${status['storeAccountToken'] ?? ''}'.trim();
    final currentPlan = '${status['currentPlan'] ?? 'free'}'.trim();
    if (accountToken.isEmpty) {
      _showMessage('Pipe Buyer could not prepare secure store billing.');
      return;
    }
    setState(() => _busy = true);
    try {
      PurchaseParam purchaseParam;
      if (nativeMembershipPlatformName() == 'android') {
        GooglePlayPurchaseDetails? oldPurchase;
        if (currentPlan != 'free') {
          final addition = _iap.getPlatformAddition<
              InAppPurchaseAndroidPlatformAddition>();
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
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started) {
        throw StateError('The app store did not start the subscription purchase.');
      }
    } catch (error) {
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

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!nativeMembershipProductIds.values.contains(purchase.productID)) continue;
      if (purchase.status == PurchaseStatus.pending) continue;
      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        if (mounted) {
          setState(() => _busy = false);
          _showMessage(
            purchase.error?.message ?? 'The store purchase was not completed.',
          );
        }
        continue;
      }
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        continue;
      }
      try {
        final platform = nativeMembershipPlatformName();
        if (platform == null) continue;
        final payload = <String, Object?>{
          'platform': platform,
          'productId': purchase.productID,
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
          throw StateError('The store purchase was not verified by Pipe Buyer.');
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        if (!mounted) continue;
        setState(() {
          _busy = false;
          _restoreBusy = false;
        });
        final currentPlan = '${result['currentPlan'] ?? ''}';
        final pendingPlan = '${result['pendingPlan'] ?? ''}';
        _showMessage(
          pendingPlan.isNotEmpty
              ? '${nativeMembershipPlanLabel(pendingPlan)} is scheduled for the end of the current paid period.'
              : '${nativeMembershipPlanLabel(currentPlan)} membership verified.',
        );
        _reload();
      } catch (error) {
        if (!mounted) continue;
        setState(() {
          _busy = false;
          _restoreBusy = false;
        });
        _showMessage(
          marketplaceCommandErrorMessage(
            error,
            fallback:
                'The purchase is still with the store but Pipe Buyer could not verify it yet. Use Restore store purchase to retry.',
          ),
        );
      }
    }
  }

  Future<void> _restorePurchases() async {
    final view = _lastView;
    if (view == null || _restoreBusy) return;
    final status = view['status'] is Map
        ? Map<String, dynamic>.from(view['status'] as Map)
        : const <String, dynamic>{};
    final accountToken = '${status['storeAccountToken'] ?? ''}'.trim();
    if (accountToken.isEmpty) {
      _showMessage('Pipe Buyer could not prepare purchase restoration.');
      return;
    }
    setState(() => _restoreBusy = true);
    try {
      await _iap.restorePurchases(applicationUserName: accountToken);
    } catch (error) {
      if (!mounted) return;
      setState(() => _restoreBusy = false);
      _showMessage('Store purchases could not be restored right now.');
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
