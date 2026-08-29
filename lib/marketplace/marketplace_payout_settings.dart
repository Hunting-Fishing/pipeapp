import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';

class MarketplacePayoutSettingsPage extends StatefulWidget {
  const MarketplacePayoutSettingsPage({super.key});

  @override
  State<MarketplacePayoutSettingsPage> createState() =>
      _MarketplacePayoutSettingsPageState();
}

class _MarketplacePayoutSettingsPageState
    extends State<MarketplacePayoutSettingsPage> {
  final _commands = MarketplaceCommandClient();
  String _country = 'CA';
  String _accountId = '';
  String _transferStatus = 'not_checked';
  bool? _payoutReady;
  bool _startingOnboarding = false;
  bool _refreshing = false;

  bool get _hasAccount => _accountId.startsWith('acct_');

  Future<void> _startOnboarding() async {
    if (_startingOnboarding || _refreshing) return;
    setState(() => _startingOnboarding = true);
    try {
      final result = await _commands.execute(
        'createStripeSellerOnboardingLink',
        {'country': _country},
        timeout: const Duration(seconds: 45),
      );
      final accountId = '${result['accountId'] ?? ''}'.trim();
      final uri = Uri.tryParse('${result['onboardingUrl'] ?? ''}');
      final host = uri?.host.toLowerCase() ?? '';
      if (uri == null ||
          uri.scheme != 'https' ||
          !(host == 'stripe.com' || host.endsWith('.stripe.com'))) {
        throw StateError('Stripe did not return a valid seller setup link.');
      }
      if (accountId.startsWith('acct_') && mounted) {
        setState(() => _accountId = accountId);
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw StateError('Secure Stripe seller setup could not be opened.');
      }
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(
          error,
          fallback: 'Seller payout setup could not be started.',
        ),
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) setState(() => _startingOnboarding = false);
    }
  }

  Future<void> _refreshStatus() async {
    if (_refreshing || _startingOnboarding) return;
    setState(() => _refreshing = true);
    try {
      final result = await _commands.execute(
        'refreshStripeSellerStatus',
        const {},
        timeout: const Duration(seconds: 30),
      );
      if (!mounted) return;
      final accountId = '${result['accountId'] ?? ''}'.trim();
      final transferStatus = '${result['transferStatus'] ?? 'pending'}'.trim();
      final ready = result['payoutReady'] == true;
      setState(() {
        if (accountId.startsWith('acct_')) _accountId = accountId;
        _transferStatus = transferStatus.isEmpty ? 'pending' : transferStatus;
        _payoutReady = ready;
      });
      PipeFeedback.show(
        context,
        message: ready
            ? 'Stripe seller payouts are ready.'
            : 'Stripe still needs information before payouts can be enabled.',
        tone: ready ? PipeStatusTone.success : PipeStatusTone.warning,
      );
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(
          error,
          fallback: 'Seller payout status could not be refreshed.',
        ),
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to set up seller payouts.')),
      );
    }

    final payoutReady = _payoutReady == true;
    final statusChecked = _payoutReady != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Seller payouts')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF101721),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.orange.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_outlined,
                    color: Color(0xFFFFB21A),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payoutReady
                            ? 'Seller payouts are ready'
                            : _hasAccount
                                ? 'Finish seller payout setup'
                                : 'Seller payout setup',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Banking, identity and tax information is entered securely with Stripe. Pipe Buyer does not ask you to type bank account numbers or tax IDs into this app.',
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        payoutReady
                            ? Icons.verified_rounded
                            : Icons.pending_actions_outlined,
                        color: payoutReady
                            ? PipeBuyerColors.success
                            : PipeBuyerColors.orangePressed,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          payoutReady
                              ? 'PAYOUT READY'
                              : _hasAccount
                                  ? 'STRIPE SETUP IN PROGRESS'
                                  : statusChecked
                                      ? 'ACTION REQUIRED'
                                      : 'STATUS NOT CHECKED',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: .4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (!_hasAccount) ...[
                    const Text(
                      'Seller country',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Used only if Stripe needs to create a new seller payout account.',
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _country,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.public_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CA',
                          child: Text('Canada'),
                        ),
                        DropdownMenuItem(
                          value: 'US',
                          child: Text('United States'),
                        ),
                      ],
                      onChanged: _startingOnboarding
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _country = value);
                              }
                            },
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    const _StatusRow(
                      label: 'Provider',
                      value: 'Stripe',
                    ),
                    const SizedBox(height: 8),
                    _StatusRow(
                      label: 'Transfer status',
                      value: _friendlyStatus(_transferStatus),
                    ),
                    const SizedBox(height: 14),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _startingOnboarding || _refreshing
                          ? null
                          : _startOnboarding,
                      icon: _startingOnboarding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_new_rounded),
                      label: Text(
                        _startingOnboarding
                            ? 'Opening Stripe…'
                            : payoutReady
                                ? 'Review payout details with Stripe'
                                : _hasAccount
                                    ? 'Continue setup with Stripe'
                                    : 'Set up payouts with Stripe',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _startingOnboarding || _refreshing
                          ? null
                          : _refreshStatus,
                      icon: _refreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(
                        _refreshing ? 'Checking…' : 'Check payout status',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security_rounded),
                      SizedBox(width: 10),
                      Text(
                        'How seller payouts work',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _InfoLine(
                    number: '1',
                    text: 'Stripe verifies the seller and payout account.',
                  ),
                  _InfoLine(
                    number: '2',
                    text:
                        'Pipe Buyer keeps Stripe account identifiers and payout readiness server-side. The app requests only the status it needs through authenticated commands.',
                  ),
                  _InfoLine(
                    number: '3',
                    text:
                        'Marketplace payments and seller transfers remain controlled by server-side transaction and readiness rules.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'For launch, Stripe seller onboarding is available in Canada and the United States. More countries can be enabled after their payout and compliance requirements are configured.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
          ),
        ],
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
      case 'not_started':
      case '':
        return 'Not started';
      default:
        return value.replaceAll('_', ' ');
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PipeBuyerColors.orangeSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: PipeBuyerColors.orangePressed,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
