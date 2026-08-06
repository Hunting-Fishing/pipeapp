import 'package:flutter/material.dart';

import 'marketplace_admin_access.dart';
import 'marketplace_payment_readiness.dart';

class MarketplaceAdminTransactionPortal extends StatefulWidget {
  const MarketplaceAdminTransactionPortal({super.key});

  @override
  State<MarketplaceAdminTransactionPortal> createState() =>
      _MarketplaceAdminTransactionPortalState();
}

class _MarketplaceAdminTransactionPortalState
    extends State<MarketplaceAdminTransactionPortal> {
  bool _isAuthorized = false;
  bool _isLoadingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAdminAuth();
  }

  Future<void> _checkAdminAuth() async {
    final authorized = await marketplaceAdministratorAccess(
      forceRefresh: true,
    );
    if (!mounted) return;
    setState(() {
      _isAuthorized = authorized;
      _isLoadingAuth = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAuth) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Access Required')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 64,
                    color: Colors.red,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Administrator privileges required',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sign in with an approved administrator account and complete multi-factor authentication.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Billing and payment readiness'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.rule_folder_outlined),
                text: 'Provider readiness',
              ),
              Tab(
                icon: Icon(Icons.receipt_long_outlined),
                text: 'Transaction records',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MarketplacePaymentReadinessPanel(),
            MarketplaceTransactionRecordsPanel(),
          ],
        ),
      ),
    );
  }
}
