import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';

class MarketplaceStripeConnectReturnPage extends StatefulWidget {
  const MarketplaceStripeConnectReturnPage({
    super.key,
    required this.connectAction,
  });

  final String connectAction;

  @override
  State<MarketplaceStripeConnectReturnPage> createState() =>
      _MarketplaceStripeConnectReturnPageState();
}

class _MarketplaceStripeConnectReturnPageState
    extends State<MarketplaceStripeConnectReturnPage> {
  final _commands = MarketplaceCommandClient();

  bool _loading = true;
  bool _openingStripe = false;
  bool _statusConfirmed = false;
  bool? _payoutReady;
  String _transferStatus = 'pending';
  String? _errorMessage;

  bool get _isRefresh => widget.connectAction.trim().toLowerCase() == 'refresh';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleCallback());
  }

  Future<void> _handleCallback() async {
    if (!mounted) return;
    if (_isRefresh) {
      await _continueOnboarding();
      return;
    }
    await _refreshStatus();
  }

  Future<void> _refreshStatus({bool userInitiated = false}) async {
    if (!mounted || (_loading && userInitiated)) return;
    setState(() {
      _loading = true;
      _statusConfirmed = false;
      _errorMessage = null;
    });
    try {
      final result = await _commands.execute(
        'refreshStripeSellerStatus',
        const {},
        timeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      final transferStatus = '${result['transferStatus'] ?? 'pending'}'.trim();
      final ready = result['payoutReady'] == true;
      setState(() {
        _transferStatus = transferStatus.isEmpty ? 'pending' : transferStatus;
        _payoutReady = ready;
        _loading = false;
        _statusConfirmed = userInitiated;
      });
      if (userInitiated) {
        PipeFeedback.show(
          context,
          message: ready
              ? 'Payout status checked. Stripe confirms this seller is payout ready.'
              : 'Payout status checked. Stripe still needs information before payouts can be enabled.',
          tone: ready ? PipeStatusTone.success : PipeStatusTone.warning,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = marketplaceCommandErrorMessage(
          error,
          fallback: 'Seller payout status could not be refreshed.',
        );
        _loading = false;
      });
      if (userInitiated) {
        PipeFeedback.show(
          context,
          message: _errorMessage!,
          tone: PipeStatusTone.error,
        );
      }
    }
  }

  Future<void> _continueOnboarding() async {
    if (_openingStripe) return;
    if (mounted) {
      setState(() {
        _openingStripe = true;
        _loading = false;
        _errorMessage = null;
      });
    }
    try {
      final result = await _commands.execute(
        'createStripeSellerOnboardingLink',
        const {},
        timeout: const Duration(seconds: 45),
      );
      final uri = Uri.tryParse('${result['onboardingUrl'] ?? ''}');
      final host = uri?.host.toLowerCase() ?? '';
      if (uri == null ||
          uri.scheme != 'https' ||
          !(host == 'stripe.com' || host.endsWith('.stripe.com'))) {
        throw StateError('Stripe did not return a valid seller setup link.');
      }

      // On web, keep Stripe in the same browser tab so the Pipe Buyer auth
      // context and return route stay together. Native apps still use the
      // system browser for Stripe-hosted onboarding.
      final opened = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_self' : null,
      );
      if (!opened) {
        throw StateError('Secure Stripe seller setup could not be opened.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = marketplaceCommandErrorMessage(
          error,
          fallback: 'Seller payout onboarding could not be continued.',
        );
        _openingStripe = false;
      });
      PipeFeedback.show(
        context,
        message: _errorMessage!,
        tone: PipeStatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _payoutReady == true;
    final statusLabel = _friendlyStatus(_transferStatus);

    return Scaffold(
      appBar: AppBar(title: const Text('Seller payouts')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(20),
              shrinkWrap: true,
              children: [
                Icon(
                  ready
                      ? Icons.verified_rounded
                      : _errorMessage != null
                          ? Icons.error_outline_rounded
                          : Icons.account_balance_outlined,
                  size: 64,
                  color: ready
                      ? PipeBuyerColors.success
                      : PipeBuyerColors.orangePressed,
                ),
                const SizedBox(height: 18),
                Text(
                  _loading
                      ? 'Checking your Stripe payout setup…'
                      : _openingStripe
                          ? 'Returning to Stripe…'
                          : _errorMessage != null
                              ? 'Seller payout setup needs attention'
                              : ready
                                  ? 'Seller payouts are ready'
                                  : 'Stripe setup saved',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (_loading || _openingStripe) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 14),
                  Text(
                    _openingStripe
                        ? 'Pipe Buyer is creating a fresh secure Stripe onboarding link.'
                        : 'Pipe Buyer is reading your current payout readiness from Stripe.',
                    textAlign: TextAlign.center,
                  ),
                ] else if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _isRefresh
                        ? _continueOnboarding
                        : () => _refreshStatus(userInitiated: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                        _isRefresh ? 'Continue with Stripe' : 'Check again'),
                  ),
                ] else ...[
                  Text(
                    ready
                        ? 'Stripe has confirmed that transfers and payouts are enabled for this seller account.'
                        : 'Your Stripe information was returned to Pipe Buyer. Current transfer status: $statusLabel. Stripe may still need information before payouts can be enabled.',
                    textAlign: TextAlign.center,
                  ),
                  if (_statusConfirmed) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          ready
                              ? Icons.check_circle_outline_rounded
                              : Icons.info_outline_rounded,
                          size: 20,
                          color: ready
                              ? PipeBuyerColors.success
                              : PipeBuyerColors.orangePressed,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            ready
                                ? 'Status checked just now — payout ready.'
                                : 'Status checked just now — more Stripe information is required.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (!ready)
                    FilledButton.icon(
                      onPressed: _continueOnboarding,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Continue setup with Stripe'),
                    ),
                  if (!ready) const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _refreshStatus(userInitiated: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Check payout status'),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Return to Pipe Buyer'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyStatus(String value) {
    switch (value.trim().toLowerCase()) {
      case 'active':
        return 'Ready';
      case 'pending':
        return 'Pending information';
      case 'restricted':
      case 'inactive':
        return 'Action required';
      case 'not_checked':
        return 'Not checked yet';
      default:
        return value.trim().isEmpty
            ? 'Pending information'
            : value.replaceAll('_', ' ');
    }
  }
}
