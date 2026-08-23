import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_admin_access.dart';
import 'marketplace_dispatch_billing_portal_control.dart';
import 'marketplace_dispatch_subscription_admin_panel.dart';
import 'marketplace_dispatch_subscription_launch_readiness_panel.dart';

class MarketplaceDispatchSubscriptionAdminPage extends StatefulWidget {
  const MarketplaceDispatchSubscriptionAdminPage({super.key});

  @override
  State<MarketplaceDispatchSubscriptionAdminPage> createState() =>
      _MarketplaceDispatchSubscriptionAdminPageState();
}

class _MarketplaceDispatchSubscriptionAdminPageState
    extends State<MarketplaceDispatchSubscriptionAdminPage> {
  late Future<MarketplaceAdministratorState> _access;

  @override
  void initState() {
    super.initState();
    _access = marketplaceAdministratorState(forceRefresh: true);
  }

  void _refreshAccess() {
    setState(() {
      _access = marketplaceAdministratorState(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Dispatch Billing Operations'),
          actions: [
            IconButton(
              tooltip: 'Re-check administrator access',
              onPressed: _refreshAccess,
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          ],
        ),
        body: FutureBuilder<MarketplaceAdministratorState>(
          future: _access,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final state = snapshot.data!;
            if (state != MarketplaceAdministratorState.authorized) {
              return _DispatchAdminAccessRequired(
                state: state,
                onRefresh: _refreshAccess,
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OperationsSafetyBanner(),
                        SizedBox(height: 16),
                        _SectionHeading(
                          number: '1',
                          title: 'Launch readiness',
                          description:
                              'Review the complete prerequisite chain and the recommended next action.',
                        ),
                        SizedBox(height: 8),
                        MarketplaceDispatchSubscriptionLaunchReadinessPanel(),
                        SizedBox(height: 18),
                        _SectionHeading(
                          number: '2',
                          title: 'Customer billing management',
                          description:
                              'Verify the exact LIVE Stripe Billing Portal configuration before it can be trusted by Checkout or Manage Billing.',
                        ),
                        SizedBox(height: 8),
                        MarketplaceDispatchBillingPortalControl(),
                        SizedBox(height: 18),
                        _SectionHeading(
                          number: '3',
                          title: 'Subscription accounting',
                          description:
                              'Reconcile recorded paid invoices against current Stripe provider evidence.',
                        ),
                        SizedBox(height: 8),
                        _DispatchReconciliationExplanation(),
                        SizedBox(height: 10),
                        MarketplaceDispatchSubscriptionAdminPanel(),
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _DispatchAdminAccessRequired extends StatelessWidget {
  const _DispatchAdminAccessRequired({
    required this.state,
    required this.onRefresh,
  });

  final MarketplaceAdministratorState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 54,
                      color: PipeBuyerColors.industrialBlue,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Administrator access required',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _accessMessage(state),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh administrator access'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _OperationsSafetyBanner extends StatelessWidget {
  const _OperationsSafetyBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PipeBuyerColors.industrialBlue.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: PipeBuyerColors.industrialBlue.withValues(alpha: .22),
          ),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.shield_outlined,
              color: PipeBuyerColors.industrialBlue,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Protected financial operations',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'This workspace verifies provider configuration and reconciles financial evidence. It does not contain a public subscription-activation button, and it does not let Flutter write authoritative payment state.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor:
                PipeBuyerColors.industrialBlue.withValues(alpha: .10),
            foregroundColor: PipeBuyerColors.industrialBlue,
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _DispatchReconciliationExplanation extends StatelessWidget {
  const _DispatchReconciliationExplanation();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.account_balance_outlined,
                color: PipeBuyerColors.industrialBlue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Provider-backed subscription accounting',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'A normal paid Dispatch invoice is reconciled server-side through Stripe Invoice → InvoicePayment → PaymentIntent → Charge → Balance Transaction. A legitimate 100% promotional invoice must prove a zero-dollar provider path instead. Flutter cannot mark an invoice balanced.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

String _accessMessage(MarketplaceAdministratorState state) {
  switch (state) {
    case MarketplaceAdministratorState.signedOut:
      return 'Sign in with an approved administrator account.';
    case MarketplaceAdministratorState.roleMissing:
      return 'This account does not have the approved administrator role.';
    case MarketplaceAdministratorState.mfaRequired:
      return 'Complete multi-factor authentication before opening financial operations.';
    case MarketplaceAdministratorState.unavailable:
      return 'Administrator claims could not be verified. Refresh after confirming your connection.';
    case MarketplaceAdministratorState.authorized:
      return 'Authorized.';
  }
}
