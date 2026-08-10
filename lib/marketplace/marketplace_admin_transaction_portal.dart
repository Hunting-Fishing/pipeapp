import 'package:flutter/material.dart';

import 'marketplace_admin_access.dart';
import 'marketplace_payment_readiness.dart';
import 'marketplace_tax_compliance_admin_page.dart';

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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: const Column(
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Billing, fees & tax'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                icon: Icon(Icons.price_check_outlined),
                text: 'Fees & Tax',
              ),
              Tab(
                icon: Icon(Icons.fact_check_outlined),
                text: 'Tax Compliance',
              ),
              Tab(
                icon: Icon(Icons.receipt_long_outlined),
                text: 'Transaction Records',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MarketplacePaymentReadinessPanel(),
            MarketplaceTaxComplianceAdminPage(),
            MarketplaceTransactionRecordsPanel(),
          ],
        ),
      ),
    );
  }
}
