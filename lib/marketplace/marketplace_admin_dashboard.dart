import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/accessibility/pipe_status_feedback.dart';
import 'marketplace_admin_access.dart';
import 'marketplace_escrow_repository.dart';
import 'marketplace_invoice_generator.dart';

class MarketplaceAdminDashboard extends StatefulWidget {
  const MarketplaceAdminDashboard({super.key});

  @override
  State<MarketplaceAdminDashboard> createState() => _MarketplaceAdminDashboardState();
}

class _MarketplaceAdminDashboardState extends State<MarketplaceAdminDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    _tabController = TabController(length: 7, vsync: this);
    _checkAdminAuth();
    _loadGatewayCredentials();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          message: 'Company Bank & Merchant Credentials saved successfully!',
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
        appBar: AppBar(title: const Text('Admin Portal Access')),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Administrator Privileges Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Account: ${user?.email ?? 'Signed Out'}\nOnly master administrator (jordilwbailey@gmail.com) can access the Admin Portal Dashboard.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.purple.shade700,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'PIPE BUYER ADMIN PORTAL',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Analytics'),
            Tab(icon: Icon(Icons.gavel_outlined), text: 'Transactions & Escrow'),
            Tab(icon: Icon(Icons.account_balance_outlined), text: 'Banking & Gateways'),
            Tab(icon: Icon(Icons.people_outline), text: 'Users & Roles'),
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Moderation'),
            Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Dispatch Logistics'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'System Config'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnalyticsTab(),
          _buildTransactionsTab(),
          _buildBankingGatewaysTab(),
          _buildUsersTab(),
          _buildModerationTab(),
          _buildDispatchTab(),
          _buildSystemConfigTab(),
        ],
      ),
    );
  }

  // 1. Analytics & Revenue Tab
  Widget _buildAnalyticsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('marketplace_transactions').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        double totalVolume = 0.0;
        double sellerFees = 0.0;
        double escrowFees = 0.0;

        for (final doc in docs) {
          final data = doc.data();
          final subtotal = (data['offeredTotal'] as num?)?.toDouble() ??
              ((data['offeredUnitPrice'] as num?)?.toDouble() ?? 0.0) *
                  ((data['requestedQuantity'] as num?)?.toInt() ?? 1);
          totalVolume += subtotal;
          sellerFees += subtotal * 0.025;
          escrowFees += subtotal * 0.010;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PLATFORM FINANCIAL PERFORMANCE', style: _sectionTitleStyle),
              const SizedBox(height: 12),
              Row(
                children: [
                  _metricCard('GROSS MARKETPLACE VOLUME', '\$${totalVolume.toStringAsFixed(2)}', Icons.trending_up, Colors.blue),
                  const SizedBox(width: 12),
                  _metricCard('TOTAL EARNINGS (3.5%)', '\$${(sellerFees + escrowFees).toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.green),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _metricCard('2.5% SELLER COMMISSIONS', '\$${sellerFees.toStringAsFixed(2)}', Icons.sell_outlined, Colors.purple),
                  const SizedBox(width: 12),
                  _metricCard('1.0% ESCROW FEES', '\$${escrowFees.toStringAsFixed(2)}', Icons.shield_outlined, Colors.teal),
                ],
              ),
              const SizedBox(height: 24),
              const Text('PLATFORM ACTIVITY OVERVIEW', style: _sectionTitleStyle),
              const SizedBox(height: 12),
              Row(
                children: [
                  _countStreamCard('listings', 'ACTIVE LISTINGS', Icons.inventory_2_outlined, Colors.indigo),
                  const SizedBox(width: 12),
                  _countStreamCard('users', 'REGISTERED USERS', Icons.people_outline, Colors.orange),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _countStreamCard(String collection, String label, IconData icon, Color color) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection(collection).limit(500).snapshots(),
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          return _metricCard(label, '$count', icon, color);
        },
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
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
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Transactions & Escrow Management Tab
  Widget _buildTransactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('marketplace_transactions').limit(100).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No marketplace transactions recorded yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final offerId = docs[index].id;
            final title = '${data['listingTitle'] ?? 'Listing'}';
            final status = '${data['escrowStatus'] ?? data['status'] ?? 'pending'}';
            final total = (data['offeredTotal'] as num?)?.toDouble() ?? 0.0;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        Chip(label: Text(status.toUpperCase())),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Total Transaction: \$${total.toStringAsFixed(2)} • Company Fee (3.5%): \$${(total * 0.035).toStringAsFixed(2)}'),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _adminEscrowAction(offerId, 'force_release'),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                          label: const Text('Force Release Funds'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _adminEscrowAction(offerId, 'force_refund'),
                          icon: const Icon(Icons.undo, color: Colors.red),
                          label: const Text('Force Refund Buyer'),
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

  Future<void> _adminEscrowAction(String offerId, String action) async {
    await FirebaseFirestore.instance
        .collection('marketplace_transactions')
        .doc(offerId)
        .set({
      'escrowStatus': action == 'force_release' ? 'funds_released' : 'refunded',
      'adminActionBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
      'adminActionAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      PipeFeedback.show(
        context,
        message: 'Admin action executed: ${action.replaceAll('_', ' ')}',
        tone: PipeStatusTone.success,
      );
    }
  }

  // 3. Banking & Merchant Gateways Setup Tab
  Widget _buildBankingGatewaysTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('COMPANY BANK ACCOUNT (FOR COMMISSION FEES)', style: _sectionTitleStyle),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyBankName,
                decoration: const InputDecoration(
                  labelText: 'Company Bank Name',
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
                        labelText: 'Routing / ABA #',
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

              const Text('STRIPE LIVE / TEST CREDENTIALS', style: _sectionTitleStyle),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stripePublishableKey,
                decoration: const InputDecoration(
                  labelText: 'Stripe Publishable Key (pk_live_...)',
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stripeSecretKey,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Stripe Secret Key (sk_live_...)',
                  prefixIcon: Icon(Icons.vpn_key),
                ),
              ),
              const SizedBox(height: 24),

              const Text('PAYPAL COMMERCE CREDENTIALS', style: _sectionTitleStyle),
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
                  label: Text(_isSavingGateways ? 'Saving Setup…' : 'Save Company Bank & Merchant Keys'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. Users & Roles Management Tab
  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(100).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final users = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final u = users[index].data();
            final uid = users[index].id;
            final email = '${u['email'] ?? u['display_name'] ?? uid}';
            final role = '${u['accountType'] ?? u['role'] ?? 'personal'}';

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('UID: $uid • Role: $role'),
              trailing: Chip(
                label: Text(role.toUpperCase()),
                backgroundColor: role == 'business' ? Colors.blue.shade50 : Colors.grey.shade100,
              ),
            );
          },
        );
      },
    );
  }

  // 5. Moderation & Trust Safety Tab
  Widget _buildModerationTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('reports').limit(50).snapshots(),
      builder: (context, snapshot) {
        final reports = snapshot.data?.docs ?? [];
        if (reports.isEmpty) {
          return const Center(child: Text('No active moderation reports queued. System healthy ✓'));
        }
        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final r = reports[index].data();
            return ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: Text('${r['reason'] ?? 'Reported content'}'),
              subtitle: Text('Target: ${r['targetId'] ?? r['targetType']}'),
            );
          },
        );
      },
    );
  }

  // 6. Carrier Dispatch Logistics Tab
  Widget _buildDispatchTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('dispatch_jobs').limit(50).snapshots(),
      builder: (context, snapshot) {
        final jobs = snapshot.data?.docs ?? [];
        if (jobs.isEmpty) {
          return const Center(child: Text('No dispatch jobs currently active.'));
        }
        return ListView.builder(
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final j = jobs[index].data();
            return ListTile(
              leading: const Icon(Icons.local_shipping),
              title: Text('${j['cargoDescription'] ?? 'Freight Job'}'),
              subtitle: Text('Status: ${j['status'] ?? 'open'}'),
            );
          },
        );
      },
    );
  }

  // 7. System Config & Feature Flags Tab
  Widget _buildSystemConfigTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('SYSTEM FEATURE FLAGS & CONFIGURATION', style: _sectionTitleStyle),
        const SizedBox(height: 12),
        SwitchListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('Auctions Engine Active'),
          subtitle: const Text('Allow sellers to create and run timed auctions'),
        ),
        SwitchListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('Industrial Escrow Protection Active'),
          subtitle: const Text('Enforce escrow holds on high-value equipment sales'),
        ),
        SwitchListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('Wanted Request Radar Matching'),
          subtitle: const Text('Automatically pair buyer request ads with new inventory'),
        ),
      ],
    );
  }

  static const TextStyle _sectionTitleStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Colors.blueGrey,
    letterSpacing: 0.9,
  );
}
