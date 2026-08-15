import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_admin_access.dart';
import 'marketplace_data_state.dart';
import 'marketplace_payment_readiness.dart';
import 'marketplace_tax_compliance_admin_page.dart';
import 'marketplace_weight_catalog_admin.dart';

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
        body: MarketplaceDataStateView.loading(
          title: 'Verifying administrator access',
          message: 'Checking role and security requirements…',
        ),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Access Required')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: PipeBuyerSectionCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.danger.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: PipeBuyerColors.danger.withValues(alpha: .20),
                        ),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 34,
                        color: PipeBuyerColors.danger,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const PipeBuyerStatusBadge(
                      label: 'PROTECTED ADMIN AREA',
                      icon: Icons.lock_outline,
                      tone: PipeBuyerStatusTone.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Administrator privileges required',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in with an approved administrator account and complete multi-factor authentication before accessing billing, fee, tax, transaction, or reference-data controls.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _isLoadingAuth = true);
                        _checkAdminAuth();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Re-check administrator access'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Administration'),
              SizedBox(width: 10),
              PipeBuyerStatusBadge(
                label: 'ADMIN',
                icon: Icons.admin_panel_settings_outlined,
                tone: PipeBuyerStatusTone.premium,
              ),
            ],
          ),
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
                icon: Icon(Icons.scale_outlined),
                text: 'Weight Catalog',
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
            MarketplaceWeightCatalogAdminPage(),
            MarketplaceTransactionRecordsPanel(),
          ],
        ),
      ),
    );
  }
}
