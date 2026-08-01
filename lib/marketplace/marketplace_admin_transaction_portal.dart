import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/accessibility/pipe_status_feedback.dart';
import 'marketplace_admin_access.dart';
import 'marketplace_escrow_repository.dart';
import 'marketplace_money.dart';

class MarketplaceAdminTransactionPortal extends StatefulWidget {
  const MarketplaceAdminTransactionPortal({super.key});

  @override
  State<MarketplaceAdminTransactionPortal> createState() =>
      _MarketplaceAdminTransactionPortalState();
}

class _MarketplaceAdminTransactionPortalState
    extends State<MarketplaceAdminTransactionPortal> {
  final _companyBankName = TextEditingController();
  final _companyRoutingNumber = TextEditingController();
  final _companyAccountNumber = TextEditingController();

  final _stripePublishableKey = TextEditingController();
  final _stripeSecretKey = TextEditingController();
  final _paypalClientId = TextEditingController();
  final _paypalSecretKey = TextEditingController();

  bool _isAuthorized = false;
  bool _isLoadingAuth = true;
  bool _isSavingGateways = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAuth();
    _loadGatewayCredentials();
  }

  @override
  void dispose() {
    _companyBankName.dispose();
    _companyRoutingNumber.dispose();
    _companyAccountNumber.dispose();
    _stripePublishableKey.dispose();
    _stripeSecretKey.dispose();
    _paypalClientId.dispose();
    _paypalSecretKey.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAuth() async {
    final auth = await marketplaceAdministratorAccess();
    if (mounted) {
      setState(() {
        _isAuthorized = auth;
        _isLoadingAuth = false;
      });
    }
  }

  Future<void> _loadGatewayCredentials() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('payment_gateways')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _companyBankName.text = data['companyBankName'] ?? '';
        _companyRoutingNumber.text = data['companyRoutingNumber'] ?? '';
        _companyAccountNumber.text = data['companyAccountNumber'] ?? '';
        _stripePublishableKey.text = data['stripePublishableKey'] ?? '';
        _stripeSecretKey.text = data['stripeSecretKey'] ?? '';
        _paypalClientId.text = data['paypalClientId'] ?? '';
        _paypalSecretKey.text = data['paypalSecretKey'] ?? '';
      }
    } catch (_) {}
  }

  Future<void> _saveGatewayCredentials() async {
    setState(() => _isSavingGateways = true);
    try {
      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('payment_gateways')
          .set({
        'companyBankName': _companyBankName.text.trim(),
        'companyRoutingNumber': _companyRoutingNumber.text.trim(),
        'companyAccountNumber': _companyAccountNumber.text.trim(),
        'stripePublishableKey': _stripePublishableKey.text.trim(),
        'stripeSecretKey': _stripeSecretKey.text.trim(),
        'paypalClientId': _paypalClientId.text.trim(),
        'paypalSecretKey': _paypalSecretKey.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
      }, SetOptions(merge: true));

      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'Payment Gateway API Keys & Company Bank Account saved!',
          tone: PipeStatusTone.success,
        );
      }
    } catch (err) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'Failed to save credentials: $err',
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingGateways = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (_isLoadingAuth) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Access Required')),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_outlined,
                    size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Administrator Privileges Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Logged in as: ${user?.email ?? 'Unknown'}\nOnly master administrator account (jordilwbailey@gmail.com) can access transaction monitoring & bank settings.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Master Admin Transaction & Escrow Portal'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Revenue & Volume'),
              Tab(icon: Icon(Icons.gavel_outlined), text: 'Escrow Transactions'),
              Tab(icon: Icon(Icons.account_balance_outlined), text: 'Bank & Gateways Setup'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRevenueSummaryTab(),
            _buildEscrowTransactionsTab(),
            _buildGatewaysSetupTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueSummaryTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('marketplace_transactions')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        double totalVolume = 0.0;
        double sellerFeesCollected = 0.0;
        double escrowFeesCollected = 0.0;

        for (final doc in docs) {
          final data = doc.data();
          final subtotal = (data['offeredTotal'] as num?)?.toDouble() ??
              ((data['offeredUnitPrice'] as num?)?.toDouble() ?? 0.0) *
                  ((data['requestedQuantity'] as num?)?.toInt() ?? 1);
          totalVolume += subtotal;
          sellerFeesCollected += subtotal * 0.025; // 2.5%
          escrowFeesCollected += subtotal * 0.010; // 1.0%
        }

        final grandTotalRevenue = sellerFeesCollected + escrowFeesCollected;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _statCard(
                    'TOTAL GROSS VOLUME',
                    '\$${totalVolume.toStringAsFixed(2)}',
                    Icons.trending_up,
                    Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    'TOTAL COMPANY EARNINGS',
                    '\$${grandTotalRevenue.toStringAsFixed(2)}',
                    Icons.account_balance_wallet,
                    Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statCard(
                    '2.5% SELLER COMMISSION',
                    '\$${sellerFeesCollected.toStringAsFixed(2)}',
                    Icons.sell_outlined,
                    Colors.purple,
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    '1.0% ESCROW PROTECTION',
                    '\$${escrowFeesCollected.toStringAsFixed(2)}',
                    Icons.shield_outlined,
                    Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline, color: Color(0xFF0878E8)),
                  title: const Text('Automatic Company Revenue Allocation'),
                  subtitle: const Text(
                    'All platform seller commissions (2.5%) and escrow fees (1.0%) are automatically calculated upon offer acceptance or winning auction bid and routed to the company bank account configured in Gateways Setup.',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEscrowTransactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('marketplace_transactions')
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('No active escrow transactions recorded yet.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final offerId = doc.id;
            final title = '${data['listingTitle'] ?? 'Listing'}';
            final status = '${data['escrowStatus'] ?? data['status'] ?? 'pending'}';
            final total = (data['offeredTotal'] as num?)?.toDouble() ?? 0.0;
            final sellerFee = total * 0.025;
            final escrowFee = total * 0.010;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Chip(
                          avatar: const Icon(Icons.shield_outlined, size: 14),
                          label: Text(status.toUpperCase()),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Total Value: \$${total.toStringAsFixed(2)}'),
                        ),
                        Text(
                          'Company Fee (3.5%): \$${(sellerFee + escrowFee).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _adminOverrideAction(offerId, 'force_release'),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                          label: const Text('Admin Force Release Funds'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _adminOverrideAction(offerId, 'force_refund'),
                          icon: const Icon(Icons.undo, color: Colors.red),
                          label: const Text('Admin Force Refund Buyer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _adminOverrideAction(String offerId, String action) async {
    try {
      await FirebaseFirestore.instance
          .collection('marketplace_transactions')
          .doc(offerId)
          .set({
        'escrowStatus': action == 'force_release' ? 'funds_released' : 'refunded',
        'adminOverrideAt': FieldValue.serverTimestamp(),
        'adminOverrideBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
      }, SetOptions(merge: true));

      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'Admin transaction override executed: ${action.replaceAll('_', ' ')}',
          tone: PipeStatusTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        PipeFeedback.show(context, message: 'Override failed: $e', tone: PipeStatusTone.error);
      }
    }
  }

  Widget _buildGatewaysSetupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('COMPANY BANK ACCOUNT (FOR COMMISSIONS & FEES)', style: _headerStyle),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyBankName,
                decoration: const InputDecoration(
                  labelText: 'Company Bank Name',
                  hintText: 'e.g. Chase Commercial / Royal Bank of Canada',
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _companyRoutingNumber,
                      decoration: const InputDecoration(
                        labelText: 'Routing / ABA Number',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _companyAccountNumber,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Account Number',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text('STRIPE MERCHANT PROCESSING CREDENTIALS', style: _headerStyle),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stripePublishableKey,
                decoration: const InputDecoration(
                  labelText: 'Stripe Publishable Key (pk_live_... or pk_test_...)',
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stripeSecretKey,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Stripe Secret Key (sk_live_... or sk_test_...)',
                  prefixIcon: Icon(Icons.vpn_key),
                ),
              ),
              const SizedBox(height: 24),

              Text('PAYPAL COMMERCE CREDENTIALS', style: _headerStyle),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paypalClientId,
                decoration: const InputDecoration(
                  labelText: 'PayPal Client ID',
                  prefixIcon: Icon(Icons.payment),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paypalSecretKey,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'PayPal Secret Key',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSavingGateways ? null : _saveGatewayCredentials,
                  icon: const Icon(Icons.save),
                  label: Text(_isSavingGateways ? 'Saving Credentials…' : 'Save Merchant & Bank Credentials'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Colors.blueGrey,
    letterSpacing: 0.9,
  );
}
