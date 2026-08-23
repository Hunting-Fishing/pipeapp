import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';

class MarketplaceDispatchBillingPortalControl extends StatefulWidget {
  const MarketplaceDispatchBillingPortalControl({
    super.key,
    this.onChanged,
  });

  final VoidCallback? onChanged;

  @override
  State<MarketplaceDispatchBillingPortalControl> createState() =>
      _MarketplaceDispatchBillingPortalControlState();
}

class _MarketplaceDispatchBillingPortalControlState
    extends State<MarketplaceDispatchBillingPortalControl> {
  final MarketplaceCommandClient _commands = MarketplaceCommandClient();
  final TextEditingController _configurationId = TextEditingController();
  final TextEditingController _returnUrl = TextEditingController(
    text: 'https://pipebuyer.com/account',
  );

  Map<String, dynamic> _portal = const {};
  bool _loading = true;
  bool _working = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _configurationId.dispose();
    _returnUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final portal = await _commands.execute(
        'getDispatchBillingPortalReadiness',
        const {},
      );
      if (!mounted) return;
      final configurationId =
          '${portal['stripePortalConfigurationId'] ?? ''}'.trim();
      final returnUrl = '${portal['returnUrl'] ?? ''}'.trim();
      setState(() {
        _portal = portal;
        if (configurationId.isNotEmpty) {
          _configurationId.text = configurationId;
        }
        if (returnUrl.isNotEmpty) {
          _returnUrl.text = returnUrl;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Dispatch Billing Portal readiness could not be loaded.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _validConfigurationId(String value) =>
      RegExp(r'^bpc_[A-Za-z0-9]+$').hasMatch(value.trim());

  bool _validReturnUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'pipebuyer.com' || host.endsWith('.pipebuyer.com');
  }

  Future<void> _verifyAndEnable() async {
    if (_working) return;
    final configurationId = _configurationId.text.trim();
    final returnUrl = _returnUrl.text.trim();
    if (!_validConfigurationId(configurationId)) {
      setState(() {
        _error = 'Enter the exact LIVE Stripe Billing Portal bpc_ configuration ID.';
      });
      return;
    }
    if (!_validReturnUrl(returnUrl)) {
      setState(() {
        _error = 'Return URL must use HTTPS on pipebuyer.com or a Pipe Buyer subdomain.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verify live Stripe Billing Portal'),
            content: Text(
              'Pipe Buyer will re-read $configurationId directly from Stripe before enabling it. Continue only after creating this configuration in LIVE mode. It must allow payment-method updates and invoice history, cancel at the end of the billing period with no proration, and keep Monthly ↔ Yearly plan switching disabled.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Verify with Stripe'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() {
      _working = true;
      _error = null;
      _message = null;
    });
    try {
      final result = await _commands.execute(
        'verifyDispatchBillingPortalConfiguration',
        <String, Object?>{
          'stripePortalConfigurationId': configurationId,
          'returnUrl': returnUrl,
          'confirmProduction': true,
          'reason':
              'Administrator verified the exact live Dispatch Billing Portal configuration and launch-safe provider features.',
        },
        timeout: const Duration(seconds: 45),
      );
      if (!mounted) return;
      final verified = result['providerVerified'] == true;
      setState(() {
        _message = verified
            ? 'Stripe verified this exact Billing Portal configuration. Portal readiness is enabled.'
            : 'Stripe did not verify the requested Billing Portal configuration.';
      });
      await _load();
      if (verified) widget.onChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback:
              'The live Stripe Billing Portal configuration could not be verified.',
        );
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _disable() async {
    if (_working) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Disable Dispatch Billing Portal?'),
            content: const Text(
              'This revokes the stored provider verification and blocks new Dispatch subscription Checkout. Existing Stripe subscriptions and accounting evidence are preserved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep enabled'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Disable Portal'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() {
      _working = true;
      _error = null;
      _message = null;
    });
    try {
      await _commands.execute(
        'setDispatchBillingPortalReadiness',
        const <String, Object?>{
          'enabled': false,
          'reason':
              'Administrator revoked Dispatch Billing Portal readiness pending provider re-verification.',
        },
      );
      if (!mounted) return;
      setState(() {
        _message =
            'Dispatch Billing Portal readiness was disabled and provider proof revoked.';
      });
      await _load();
      widget.onChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Dispatch Billing Portal readiness could not be disabled.',
        );
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final enabled = _portal['enabled'] == true;
    final providerVerified = _portal['providerVerified'] == true;
    final storedConfiguration =
        '${_portal['stripePortalConfigurationId'] ?? ''}'.trim();
    final verifiedConfiguration =
        '${_portal['providerVerifiedConfigurationId'] ?? ''}'.trim();
    final verificationRevision =
        '${_portal['providerVerificationRevision'] ?? ''}'.trim();
    final featuresRaw = _portal['providerVerifiedFeatures'];
    final features = featuresRaw is Map
        ? Map<String, dynamic>.from(featuresRaw)
        : const <String, dynamic>{};
    final exactBinding = storedConfiguration.isNotEmpty &&
        verifiedConfiguration == storedConfiguration;
    final ready = enabled &&
        providerVerified &&
        exactBinding &&
        verificationRevision.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  ready ? Icons.verified_rounded : Icons.settings_outlined,
                  color: ready
                      ? PipeBuyerColors.success
                      : PipeBuyerColors.industrialBlue,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stripe Billing Portal verification',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Pipe Buyer verifies the exact LIVE Stripe configuration; a bpc_ ID by itself is not treated as readiness.',
                        style: TextStyle(
                          color: PipeBuyerColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _PortalStatusBadge(ready: ready),
              ],
            ),
            const SizedBox(height: 12),
            if (ready)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PipeBuyerColors.success.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: PipeBuyerColors.success.withValues(alpha: .22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      storedConfiguration,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 7),
                    _FeatureCheck(
                      label: 'Payment-method updates',
                      ready: features['paymentMethodUpdate'] == true,
                    ),
                    _FeatureCheck(
                      label: 'Invoice history',
                      ready: features['invoiceHistory'] == true,
                    ),
                    _FeatureCheck(
                      label: 'Cancellation at period end',
                      ready: features['subscriptionCancel'] == true &&
                          '${features['subscriptionCancelMode'] ?? ''}' ==
                              'at_period_end',
                    ),
                    _FeatureCheck(
                      label: 'Cancellation proration disabled',
                      ready:
                          '${features['subscriptionCancelProration'] ?? ''}' ==
                              'none',
                    ),
                    _FeatureCheck(
                      label: 'Monthly ↔ Yearly plan switching disabled',
                      ready: features['subscriptionUpdate'] != true,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This configuration is re-checked live with Stripe before a new Dispatch Checkout or Manage Billing session is allowed.',
                      style: TextStyle(
                        color: PipeBuyerColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            if (ready) const SizedBox(height: 12),
            TextField(
              controller: _configurationId,
              enabled: !_working,
              decoration: const InputDecoration(
                labelText: 'Stripe Portal configuration ID',
                helperText: 'Copy the exact LIVE configuration ID from Stripe.',
                hintText: 'bpc_...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _returnUrl,
              enabled: !_working,
              decoration: const InputDecoration(
                labelText: 'Pipe Buyer return URL',
                helperText: 'HTTPS on pipebuyer.com or an approved Pipe Buyer subdomain.',
                hintText: 'https://pipebuyer.com/account',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Required Stripe features: payment-method update ON • invoice history ON • cancellation at period end • cancellation proration NONE • subscription/plan update OFF.',
              style: TextStyle(color: PipeBuyerColors.muted, fontSize: 11.5),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              _PortalMessage(message: _message!, error: false),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              _PortalMessage(message: _error!, error: true),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _working ? null : _verifyAndEnable,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(
                    ready
                        ? 'Re-verify with Stripe'
                        : 'Verify & enable Billing Portal',
                  ),
                ),
                if (enabled)
                  OutlinedButton.icon(
                    onPressed: _working ? null : _disable,
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Disable Billing Portal'),
                  ),
                IconButton(
                  tooltip: 'Refresh Billing Portal readiness',
                  onPressed: _working ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalStatusBadge extends StatelessWidget {
  const _PortalStatusBadge({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? PipeBuyerColors.success : PipeBuyerColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Text(
        ready ? 'PROVIDER VERIFIED' : 'NOT VERIFIED',
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FeatureCheck extends StatelessWidget {
  const _FeatureCheck({required this.label, required this.ready});

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              ready ? Icons.check_circle_rounded : Icons.cancel_outlined,
              size: 17,
              color: ready ? PipeBuyerColors.success : PipeBuyerColors.danger,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
          ],
        ),
      );
}

class _PortalMessage extends StatelessWidget {
  const _PortalMessage({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? PipeBuyerColors.danger : PipeBuyerColors.success;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
