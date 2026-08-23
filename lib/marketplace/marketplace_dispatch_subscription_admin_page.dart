import 'package:flutter/material.dart';

import 'marketplace_admin_access.dart';
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
        ),
        body: FutureBuilder<MarketplaceAdministratorState>(
          future: _access,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final state = snapshot.data!;
            if (state != MarketplaceAdministratorState.authorized) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.admin_panel_settings_outlined, size: 54),
                        const SizedBox(height: 14),
                        const Text(
                          'Administrator access required',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _accessMessage(state),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _refreshAccess,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh administrator access'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                MarketplaceDispatchSubscriptionLaunchReadinessPanel(),
                SizedBox(height: 12),
                _DispatchReconciliationExplanation(),
                SizedBox(height: 12),
                MarketplaceDispatchSubscriptionAdminPanel(),
              ],
            );
          },
        ),
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
              const Icon(Icons.account_balance_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Provider-backed subscription accounting',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'A normal paid Dispatch invoice is reconciled server-side through Stripe Invoice → InvoicePayment → PaymentIntent → Charge → Balance Transaction. A 100% promotional invoice must prove a zero-dollar provider path instead. Flutter cannot mark an invoice balanced.',
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
