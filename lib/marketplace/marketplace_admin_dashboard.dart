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

  final _userSearchController = TextEditingController();
  String _userSearchQuery = '';

  bool _isAuthorized = false;
  bool _isLoadingAuth = true;
  bool _isSavingGateways = false;

  // System feature flags state
  bool _auctionsEnabled = true;
  bool _escrowEnabled = true;
  bool _wantedMatchingEnabled = true;
  bool _maintenanceMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _checkAdminAuth();
    _loadGatewayCredentials();
    _loadFeatureFlags();
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
    _userSearchController.dispose();
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

  Future<void> _loadFeatureFlags() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('feature_flags')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _auctionsEnabled = data['auctionsEnabled'] ?? true;
          _escrowEnabled = data['escrowEnabled'] ?? true;
          _wantedMatchingEnabled = data['wantedMatchingEnabled'] ?? true;
          _maintenanceMode = data['maintenanceMode'] ?? false;
        });
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
          message: 'Company Bank Account & Merchant Credentials saved successfully!',
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

  Future<void> _saveFeatureFlags() async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('feature_flags')
          .set({
        'auctionsEnabled': _auctionsEnabled,
        'escrowEnabled': _escrowEnabled,
        'wantedMatchingEnabled': _wantedMatchingEnabled,
        'maintenanceMode': _maintenanceMode,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
      }, SetOptions(merge: true));

      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'System Feature Flags updated!',
          tone: PipeStatusTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        PipeFeedback.show(context, message: 'Save flags failed: $e', tone: PipeStatusTone.error);
      }
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
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Marketplace Intelligence'),
            Tab(icon: Icon(Icons.gavel_outlined), text: 'Transactions & Escrow'),
            Tab(icon: Icon(Icons.account_balance_outlined), text: 'Banking & Merchant Setup'),
            Tab(icon: Icon(Icons.people_outline), text: 'Users Directory & Leaderboards'),
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Moderation & Safety'),
            Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Freight & Dispatch'),
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

  // 1. Marketplace Intelligence & Pipe Sizes Watchboard
  Widget _buildAnalyticsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('marketplace_transactions').snapshots(),
      builder: (context, snapshot) {
        final transactions = snapshot.data?.docs ?? [];
        double totalVolume = 0.0;
        double sellerFees = 0.0;
        double escrowFees = 0.0;

        // Regional Breakdown counters
        int usaCount = 0;
        int canadaCount = 0;
        int mexicoCount = 0;

        // Pipe Size piece counters
        final Map<String, int> pipeSizePieces = {
          '2 3/8" Tubing': 0,
          '2 7/8" Tubing': 0,
          '3 1/2" Casing': 0,
          '4 1/2" Casing': 0,
          '5 1/2" Casing': 0,
          '7" Casing': 0,
          '9 5/8" Casing': 0,
          '13 3/8" Casing': 0,
          'Structural & Line Pipe': 0,
        };

        for (final doc in transactions) {
          final data = doc.data();
          final subtotal = (data['offeredTotal'] as num?)?.toDouble() ??
              ((data['offeredUnitPrice'] as num?)?.toDouble() ?? 0.0) *
                  ((data['requestedQuantity'] as num?)?.toInt() ?? 1);
          totalVolume += subtotal;
          sellerFees += subtotal * 0.025;
          escrowFees += subtotal * 0.010;

          final region = '${data['region'] ?? data['location'] ?? ''}'.toLowerCase();
          if (region.contains('canada') || region.contains('ab') || region.contains('sk') || region.contains('bc')) {
            canadaCount++;
          } else if (region.contains('mexico') || region.contains('mx')) {
            mexicoCount++;
          } else {
            usaCount++;
          }

          final title = '${data['listingTitle'] ?? ''}'.toLowerCase();
          final qty = (data['requestedQuantity'] as num?)?.toInt() ?? 1;

          if (title.contains('2 3/8') || title.contains('2.375')) {
            pipeSizePieces['2 3/8" Tubing'] = (pipeSizePieces['2 3/8" Tubing'] ?? 0) + qty;
          } else if (title.contains('2 7/8') || title.contains('2.875')) {
            pipeSizePieces['2 7/8" Tubing'] = (pipeSizePieces['2 7/8" Tubing'] ?? 0) + qty;
          } else if (title.contains('3 1/2') || title.contains('3.5')) {
            pipeSizePieces['3 1/2" Casing'] = (pipeSizePieces['3 1/2" Casing'] ?? 0) + qty;
          } else if (title.contains('4 1/2') || title.contains('4.5')) {
            pipeSizePieces['4 1/2" Casing'] = (pipeSizePieces['4 1/2" Casing'] ?? 0) + qty;
          } else if (title.contains('5 1/2') || title.contains('5.5')) {
            pipeSizePieces['5 1/2" Casing'] = (pipeSizePieces['5 1/2" Casing'] ?? 0) + qty;
          } else if (title.contains('7"') || title.contains('7 in')) {
            pipeSizePieces['7" Casing'] = (pipeSizePieces['7" Casing'] ?? 0) + qty;
          } else if (title.contains('9 5/8') || title.contains('9.625')) {
            pipeSizePieces['9 5/8" Casing'] = (pipeSizePieces['9 5/8" Casing'] ?? 0) + qty;
          } else if (title.contains('13 3/8')) {
            pipeSizePieces['13 3/8" Casing'] = (pipeSizePieces['13 3/8" Casing'] ?? 0) + qty;
          } else {
            pipeSizePieces['Structural & Line Pipe'] = (pipeSizePieces['Structural & Line Pipe'] ?? 0) + qty;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _explanationBanner(
                title: 'Marketplace Intelligence & Watchboard',
                explanation:
                    'Monitors gross transaction volume (\$), total 3.5% company fee earnings, regional sales (USA, Canada, Mexico), and total Pipe Pieces sold categorized by outer diameter (OD) sizes.',
              ),
              const SizedBox(height: 16),

              const Text('PLATFORM FINANCIAL PERFORMANCE', style: _sectionTitleStyle),
              const SizedBox(height: 12),
              Row(
                children: [
                  _metricCard('GROSS MARKETPLACE VOLUME', '\$${totalVolume.toStringAsFixed(2)}', Icons.trending_up, Colors.blue),
                  const SizedBox(width: 12),
                  _metricCard('TOTAL COMPANY EARNINGS (3.5%)', '\$${(sellerFees + escrowFees).toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.green),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _metricCard('2.5% SELLER COMMISSIONS', '\$${sellerFees.toStringAsFixed(2)}', Icons.sell_outlined, Colors.purple),
                  const SizedBox(width: 12),
                  _metricCard('1.0% ESCROW PROTECTION', '\$${escrowFees.toStringAsFixed(2)}', Icons.shield_outlined, Colors.teal),
                ],
              ),
              const SizedBox(height: 24),

              const Text('REGIONAL SALES DISTRIBUTION', style: _sectionTitleStyle),
              const SizedBox(height: 12),
              Row(
                children: [
                  _metricCard('USA (US OIL & GAS BASINS)', '$usaCount Deals', Icons.flag, Colors.blue.shade800),
                  const SizedBox(width: 12),
                  _metricCard('CANADA (ALBERTA / SK)', '$canadaCount Deals', Icons.nature, Colors.red.shade700),
                  const SizedBox(width: 12),
                  _metricCard('MEXICO REGIONS', '$mexicoCount Deals', Icons.public, Colors.green.shade800),
                ],
              ),
              const SizedBox(height: 24),

              const Text('PIPE PIECES SOLD PER SIZE (OD BREAKDOWN)', style: _sectionTitleStyle),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: pipeSizePieces.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 10, color: Color(0xFF0878E8)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${entry.value} Pieces Sold',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _explanationBanner(
                title: 'Transactions & Escrow Control Board',
                explanation:
                    'Escrow holds money safely from a buyer until the buyer inspects and approves the pipe or equipment. As master admin (jordilwbailey@gmail.com), you can force release funds to the seller\'s bank account or force refund the buyer at any time.',
              ),
              const SizedBox(height: 16),
              const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No active escrow transactions recorded yet.'))),
            ],
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _explanationBanner(
              title: 'Transactions & Escrow Control Board',
              explanation:
                  'Escrow holds money safely from a buyer until the buyer inspects and approves the pipe or equipment. As master admin (jordilwbailey@gmail.com), you can force release funds to the seller\'s bank account or force refund the buyer at any time.',
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No transactions recorded yet.')))
            else
              ...docs.map((doc) {
                final data = doc.data();
                final offerId = doc.id;
                final title = '${data['listingTitle'] ?? 'Listing'}';
                final status = '${data['escrowStatus'] ?? data['status'] ?? 'pending'}';
                final total = (data['offeredTotal'] as num?)?.toDouble() ?? 0.0;
                final sellerFee = total * 0.025;
                final escrowFee = total * 0.010;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
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
                            Chip(
                              avatar: const Icon(Icons.shield_outlined, size: 14),
                              label: Text(status.toUpperCase()),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(child: Text('Total Value: \$${total.toStringAsFixed(2)}')),
                            Text(
                              'Company Fee (3.5%): \$${(sellerFee + escrowFee).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _adminEscrowAction(offerId, 'force_release'),
                              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                              label: const Text('Admin Force Release Funds'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _adminEscrowAction(offerId, 'force_refund'),
                              icon: const Icon(Icons.undo, color: Colors.red),
                              label: const Text('Admin Force Refund Buyer'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
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
              _explanationBanner(
                title: 'Company Banking & Merchant Processing Setup',
                explanation:
                    'Configure your company\'s bank account (Routing # & Account #) so that all 3.5% platform commission and escrow protection fees deposit directly into your bank account. Enter live Stripe & PayPal API keys to accept credit card payments.',
              ),
              const SizedBox(height: 16),

              const Text('COMPANY BANK ACCOUNT (FOR COMMISSION & ESCROW FEES)', style: _sectionTitleStyle),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyBankName,
                decoration: const InputDecoration(
                  labelText: 'Company Bank Name',
                  hintText: 'e.g. JPMorgan Chase / Royal Bank of Canada',
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
                        labelText: 'Routing / ABA # (9 Digits)',
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
                  label: Text(_isSavingGateways ? 'Saving Credentials…' : 'Save Company Bank & Merchant Keys'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. Users Directory & Leaderboards Tab
  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(200).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final currentUser = FirebaseAuth.instance.currentUser;
          final masterEmail = currentUser?.email ?? 'jordilwbailey@gmail.com';
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _explanationBanner(
                  title: 'Users Directory & Member Controls',
                  explanation:
                      'Search all Pipe Buyer members, view email/phone verification status, change user roles (Personal, Business, Hotshot Carrier, Admin), or suspend accounts.',
                ),
              ),
              ListTile(
                leading: CircleAvatar(backgroundColor: Colors.purple.shade100, child: const Icon(Icons.person, color: Colors.purple)),
                title: Text(masterEmail, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('UID: ${currentUser?.uid ?? 'master-admin-uid'} • Role: ADMINISTRATOR'),
                trailing: const Chip(label: Text('ADMINISTRATOR'), backgroundColor: Colors.purpleAccent),
              ),
            ],
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];

        final filtered = docs.where((doc) {
          if (_userSearchQuery.isEmpty) return true;
          final data = doc.data();
          final search = _userSearchQuery.toLowerCase();
          return '${data['email'] ?? ''}'.toLowerCase().contains(search) ||
              '${data['display_name'] ?? data['displayName'] ?? ''}'.toLowerCase().contains(search) ||
              doc.id.toLowerCase().contains(search);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _explanationBanner(
                    title: 'Users Directory & Member Controls',
                    explanation:
                        'Search all Pipe Buyer members, view email/phone verification status, change user roles (Personal, Business, Hotshot Carrier, Admin), or suspend accounts.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userSearchController,
                    onChanged: (val) => setState(() => _userSearchQuery = val.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Search users by email, name, or UID…',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final u = filtered[index].data();
                  final uid = filtered[index].id;
                  final email = '${u['email'] ?? u['displayName'] ?? u['display_name'] ?? uid}';
                  final role = '${u['accountType'] ?? u['role'] ?? 'personal'}';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: role == 'business' ? Colors.blue.shade100 : Colors.grey.shade200,
                      child: Icon(role == 'business' ? Icons.business : Icons.person),
                    ),
                    title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('UID: $uid • Role: ${role.toUpperCase()}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) => _updateUserRole(uid, val),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'personal', child: Text('Set Role: Personal')),
                        PopupMenuItem(value: 'business', child: Text('Set Role: Business')),
                        PopupMenuItem(value: 'carrier', child: Text('Set Role: Hotshot Carrier')),
                        PopupMenuItem(value: 'administrator', child: Text('Set Role: Administrator')),
                      ],
                      child: Chip(
                        label: Text(role.toUpperCase()),
                        backgroundColor: role == 'administrator' ? Colors.purple.shade100 : Colors.blue.shade50,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateUserRole(String uid, String role) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'accountType': role,
      'role': role,
    }, SetOptions(merge: true));

    if (mounted) {
      PipeFeedback.show(
        context,
        message: 'User role updated to ${role.toUpperCase()}',
        tone: PipeStatusTone.success,
      );
    }
  }

  // 5. Moderation & Trust Safety Tab
  Widget _buildModerationTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('reports').limit(50).snapshots(),
      builder: (context, snapshot) {
        final reports = snapshot.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _explanationBanner(
              title: 'Trust & Safety Moderation Intake',
              explanation:
                  'Review user reports, flagged listing photos, duplicate listings, or vulgar messages. Maintain marketplace trust and compliance.',
            ),
            const SizedBox(height: 12),
            if (reports.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No active moderation reports queued. System clean ✓')))
            else
              ...reports.map((r) {
                final data = r.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.flag, color: Colors.orange),
                    title: Text('${data['reason'] ?? 'Reported Content'}'),
                    subtitle: Text('Target: ${data['targetId'] ?? data['targetType']}'),
                  ),
                );
              }),
          ],
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
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _explanationBanner(
              title: 'Freight Dispatch & Logistics Board',
              explanation:
                  'Monitor all active hotshot trucking jobs, carrier per-mile freight quotes, and digital Bill of Lading (BOL) driver signatures.',
            ),
            const SizedBox(height: 12),
            if (jobs.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No freight dispatch jobs active currently.')))
            else
              ...jobs.map((j) {
                final data = j.data();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping, color: Color(0xFF0878E8)),
                    title: Text('${data['cargoDescription'] ?? 'Pipe Haul Job'}'),
                    subtitle: Text('Status: ${data['status'] ?? 'open'}'),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // 7. System Feature Flags & Maintenance Mode Tab
  Widget _buildSystemConfigTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _explanationBanner(
          title: 'System Feature Flags & Controls',
          explanation:
              'Control live platform capabilities in real time. Enable or disable the Auctions Engine, Escrow Protection, or Wanted Radar matching.',
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          value: _auctionsEnabled,
          onChanged: (val) => setState(() => _auctionsEnabled = val),
          title: const Text('Timed Auctions Engine Active', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Allow sellers to launch timed auctions with reserve prices'),
        ),
        SwitchListTile(
          value: _escrowEnabled,
          onChanged: (val) => setState(() => _escrowEnabled = val),
          title: const Text('Industrial Escrow Protection Active', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Enforce escrow holds on high-value equipment sales'),
        ),
        SwitchListTile(
          value: _wantedMatchingEnabled,
          onChanged: (val) => setState(() => _wantedMatchingEnabled = val),
          title: const Text('Wanted Request Radar Matching Active', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Pair buyer request ads with newly posted seller inventory'),
        ),
        SwitchListTile(
          value: _maintenanceMode,
          onChanged: (val) => setState(() => _maintenanceMode = val),
          title: const Text('Platform Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          subtitle: const Text('Temporarily pause new listing creation for maintenance'),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _saveFeatureFlags,
          icon: const Icon(Icons.save),
          label: const Text('Save System Feature Flags'),
        ),
      ],
    );
  }

  Widget _explanationBanner({required String title, required String explanation}) {
    return Card(
      elevation: 0,
      color: Colors.purple.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.purple.shade800, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple.shade900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    explanation,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _sectionTitleStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Colors.blueGrey,
    letterSpacing: 0.9,
  );
}
