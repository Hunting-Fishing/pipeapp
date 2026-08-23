import 'package:flutter/material.dart';

import 'marketplace_command_client.dart';

class MarketplaceDispatchBillingPortalControl extends StatefulWidget {
  const MarketplaceDispatchBillingPortalControl({super.key});

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
        _error = 'Enter the exact live Stripe Billing Portal bpc_ configuration ID.';
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
              'Stripe will be re-read before Pipe Buyer enables this Portal configuration. Continue only after creating $configurationId in LIVE mode. It must allow payment-method updates and invoice history, cancel at the end of the billing period with no proration, and keep Monthly ↔ Yearly plan switching disabled.',
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
              'This revokes the stored provider verification and blocks new Dispatch subscription Checkout. Existing Stripe subscription and accounting evidence is preserved.',
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
        _message = 'Dispatch Billing Portal readiness was disabled and provider proof revoked.';
      });
      await _load();
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
    final exactBinding = storedConfiguration.isNotEmpty &&
        verifiedConfiguration == storedConfiguration;
    final ready = enabled && providerVerified && exactBinding;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  ready ? Icons.verified_rounded : Icons.settings_outlined,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Stripe Billing Portal verification',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ready
                  ? 'Provider-verified and bound to $storedConfiguration.'
                  : 'Enter the exact LIVE bpc_ configuration after creating it in Stripe Dashboard. Pipe Buyer will verify its provider features before enabling it.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _configurationId,
              enabled: !_working,
              decoration: const InputDecoration(
                labelText: 'Stripe Portal configuration ID',
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
                hintText: 'https://pipebuyer.com/account',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Required Stripe features: payment-method update ON • invoice history ON • cancellation at period end • cancellation proration NONE • subscription/plan update OFF.',
              style: TextStyle(fontSize: 12),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(_message!),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _working ? null : _verifyAndEnable,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Verify & enable Billing Portal'),
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
