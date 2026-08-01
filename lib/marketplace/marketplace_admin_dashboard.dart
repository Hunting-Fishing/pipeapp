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

  // Banking & Gateway controllers
  final _companyBankName = TextEditingController();
  final _companyRoutingNumber = TextEditingController();
  final _companyAccountNumber = TextEditingController();
  final _companySwiftIban = TextEditingController();

  final _stripePublishableKey = TextEditingController();
  final _stripeSecretKey = TextEditingController();
  final _stripeWebhookSecret = TextEditingController();

  final _paypalClientId = TextEditingController();
  final _paypalSecretKey = TextEditingController();
  final _paypalMerchantId = TextEditingController();

  final _authorizeApiLoginId = TextEditingController();
  final _authorizeTransactionKey = TextEditingController();

  final _userSearchController = TextEditingController();
  String _userSearchQuery = '';

  // Analytics timeframe and category filter states
  String _selectedTimeframe = 'All Time';
  String _selectedCategoryFilter = 'All Categories';

  bool _isAuthorized = false;
  bool _isLoadingAuth = true;

  // Modular saving states
  bool _isSavingBank = false;
  bool _isSavingStripe = false;
  bool _isSavingPaypal = false;
  bool _isSavingAuthorize = false;

  // System feature flags state
  bool _auctionsEnabled = true;
  bool _escrowEnabled = true;
  bool _wantedMatchingEnabled = true;
  bool _maintenanceMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
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
    _companySwiftIban.dispose();
    _stripePublishableKey.dispose();
    _stripeSecretKey.dispose();
    _stripeWebhookSecret.dispose();
    _paypalClientId.dispose();
    _paypalSecretKey.dispose();
    _paypalMerchantId.dispose();
    _authorizeApiLoginId.dispose();
    _authorizeTransactionKey.dispose();
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
        _companySwiftIban.text = data['companySwiftIban'] ?? '';

        _stripePublishableKey.text = data['stripePublishableKey'] ?? '';
        _stripeSecretKey.text = data['stripeSecretKey'] ?? '';
        _stripeWebhookSecret.text = data['stripeWebhookSecret'] ?? '';

        _paypalClientId.text = data['paypalClientId'] ?? '';
        _paypalSecretKey.text = data['paypalSecretKey'] ?? '';
        _paypalMerchantId.text = data['paypalMerchantId'] ?? '';

        _authorizeApiLoginId.text = data['authorizeApiLoginId'] ?? '';
        _authorizeTransactionKey.text = data['authorizeTransactionKey'] ?? '';
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

  Future<void> _saveBankCredentials() async {
    setState(() => _isSavingBank = true);
    try {
      await FirebaseFirestore.instance.collection('admin_settings').doc('payment_gateways').set({
        'companyBankName': _companyBankName.text.trim(),
        'companyRoutingNumber': _companyRoutingNumber.text.trim(),
        'companyAccountNumber': _companyAccountNumber.text.trim(),
        'companySwiftIban': _companySwiftIban.text.trim(),
        'bankUpdatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
        'bankUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        PipeFeedback.show(context, message: 'Company Bank Vault updated!', tone: PipeStatusTone.success);
      }
    } catch (e) {
      if (mounted) PipeFeedback.show(context, message: 'Failed: $e', tone: PipeStatusTone.error);
    } finally {
      if (mounted) setState(() => _isSavingBank = false);
    }
  }

  Future<void> _saveStripeCredentials() async {
    setState(() => _isSavingStripe = true);
    try {
      await FirebaseFirestore.instance.collection('admin_settings').doc('payment_gateways').set({
        'stripePublishableKey': _stripePublishableKey.text.trim(),
        'stripeSecretKey': _stripeSecretKey.text.trim(),
        'stripeWebhookSecret': _stripeWebhookSecret.text.trim(),
        'stripeUpdatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
        'stripeUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        PipeFeedback.show(context, message: 'Stripe Gateway credentials saved!', tone: PipeStatusTone.success);
      }
    } catch (e) {
      if (mounted) PipeFeedback.show(context, message: 'Failed: $e', tone: PipeStatusTone.error);
    } finally {
      if (mounted) setState(() => _isSavingStripe = false);
    }
  }

  Future<void> _savePaypalCredentials() async {
    setState(() => _isSavingPaypal = true);
    try {
      await FirebaseFirestore.instance.collection('admin_settings').doc('payment_gateways').set({
        'paypalClientId': _paypalClientId.text.trim(),
        'paypalSecretKey': _paypalSecretKey.text.trim(),
        'paypalMerchantId': _paypalMerchantId.text.trim(),
        'paypalUpdatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
        'paypalUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        PipeFeedback.show(context, message: 'PayPal Commerce setup saved!', tone: PipeStatusTone.success);
      }
    } catch (e) {
      if (mounted) PipeFeedback.show(context, message: 'Failed: $e', tone: PipeStatusTone.error);
    } finally {
      if (mounted) setState(() => _isSavingPaypal = false);
    }
  }

  Future<void> _saveAuthorizeCredentials() async {
    setState(() => _isSavingAuthorize = true);
    try {
      await FirebaseFirestore.instance.collection('admin_settings').doc('payment_gateways').set({
        'authorizeApiLoginId': _authorizeApiLoginId.text.trim(),
        'authorizeTransactionKey': _authorizeTransactionKey.text.trim(),
        'authorizeUpdatedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
        'authorizeUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        PipeFeedback.show(context, message: 'Authorize.Net Escrow gateway saved!', tone: PipeStatusTone.success);
      }
    } catch (e) {
      if (mounted) PipeFeedback.show(context, message: 'Failed: $e', tone: PipeStatusTone.error);
    } finally {
      if (mounted) setState(() => _isSavingAuthorize = false);
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
            Tab(icon: Icon(Icons.gavel_outlined), text: '🔨 Auctions Engine & Control Board'),
            Tab(icon: Icon(Icons.payments_outlined), text: '💰 Sales Payments & Escrow Transfers'),
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
          _buildAuctionsTab(),
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

  // 1. GLOBAL MARKETPLACE INTELLIGENCE & PIPE SIZES WATCHBOARD
  Widget _buildAnalyticsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('marketplace_transactions').snapshots(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
        final transactions = snapshot.data?.docs ?? [];

        double totalVolume = 0.0;
        double sellerFees = 0.0;
        double escrowFees = 0.0;

        // Global Energy & Mining Regional Counters
        int usaCount = 0;
        int canadaCount = 0;
        int mexicoCount = 0;
        int saudiMiddleEastCount = 0;
        int russiaEurasiaCount = 0;
        int europeNorthSeaCount = 0;
        int australiaOceaniaCount = 0;
        int asiaPacificCount = 0;
        int latinAmericaCount = 0;

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
          if (region.contains('saudi') || region.contains('uae') || region.contains('qatar') || region.contains('middle east')) {
            saudiMiddleEastCount++;
          } else if (region.contains('russia') || region.contains('yamal') || region.contains('eurasia')) {
            russiaEurasiaCount++;
          } else if (region.contains('uk') || region.contains('norway') || region.contains('north sea') || region.contains('europe')) {
            europeNorthSeaCount++;
          } else if (region.contains('australia') || region.contains('queensland') || region.contains('oceania')) {
            australiaOceaniaCount++;
          } else if (region.contains('china') || region.contains('asia') || region.contains('indonesia')) {
            asiaPacificCount++;
          } else if (region.contains('canada') || region.contains('ab') || region.contains('sk') || region.contains('bc')) {
            canadaCount++;
          } else if (region.contains('mexico') || region.contains('brazil') || region.contains('guyana')) {
            latinAmericaCount++;
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
                title: 'Global Energy & Mining Marketplace Intelligence',
                explanation:
                    'Monitors gross transaction volume (\$), total 3.5% company fee earnings, global energy sales across 9 major worldwide energy basins, and Pipe Pieces sold categorized by outer diameter (OD) sizes.',
              ),
              if (isLoading) const LinearProgressIndicator(),
              const SizedBox(height: 16),

              // Interactive Filters Header
              Card(
                elevation: 0,
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_alt_outlined, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('TIME & CATEGORY FILTERS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _selectedTimeframe,
                        onChanged: (val) => setState(() => _selectedTimeframe = val ?? 'All Time'),
                        items: ['All Time', 'Year-to-Date (YTD)', 'Last 30 Days', 'Last 7 Days']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12))))
                            .toList(),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _selectedCategoryFilter,
                        onChanged: (val) => setState(() => _selectedCategoryFilter = val ?? 'All Categories'),
                        items: ['All Categories', 'OCTG Casing & Tubing', 'Line Pipe', 'Structural Pipe', 'Valves & Wellheads', 'Rig & Drilling Equipment']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                            .toList(),
                      ),
                    ],
                  ),
                ),
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

              const Text('GLOBAL REGIONAL ENERGY SALES DISTRIBUTION', style: _sectionTitleStyle),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _globalRegionCard('🇺🇸 USA (PERMIAN/BAKKEN/GULF)', '$usaCount Deals', Colors.blue.shade800),
                  _globalRegionCard('🇨🇦 CANADA (WCSB ALBERTA/SK)', '$canadaCount Deals', Colors.red.shade700),
                  _globalRegionCard('🇸🇦 SAUDI ARABIA & MIDDLE EAST', '$saudiMiddleEastCount Deals', Colors.green.shade800),
                  _globalRegionCard('🇷🇺 EURASIA & RUSSIA (YAMAL)', '$russiaEurasiaCount Deals', Colors.purple.shade800),
                  _globalRegionCard('🇬🇧 EUROPE & NORTH SEA', '$europeNorthSeaCount Deals', Colors.teal.shade800),
                  _globalRegionCard('🇦🇺 AUSTRALIA & OCEANIA LNG', '$australiaOceaniaCount Deals', Colors.orange.shade800),
                  _globalRegionCard('🇨🇳 ASIA-PACIFIC (CHINA/INDONESIA)', '$asiaPacificCount Deals', Colors.indigo.shade800),
                  _globalRegionCard('🇲🇽 LATIN AMERICA & CARIBBEAN', '$latinAmericaCount Deals', Colors.deepOrange.shade800),
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

  Widget _globalRegionCard(String regionTitle, String countLabel, Color accentColor) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                regionTitle,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: accentColor),
              ),
              const SizedBox(height: 6),
              Text(
                countLabel,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.blueGrey.shade900),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. DEDICATED AUCTIONS MONITOR & CONTROL TAB
  Widget _buildAuctionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('public_listings')
          .where('transactionType', isEqualTo: 'Auction')
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
        final docs = snapshot.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _explanationBanner(
              title: '🔨 Timed Auctions Monitor & Master Admin Controls',
              explanation:
                  'Monitor all live timed auctions across Pipe Buyer. View active highest bids, reserve price status (Met / Not Met), and use master admin controls to force end auctions, extend time (+24h), or cancel auctions.',
            ),
            if (isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 16),

            Row(
              children: [
                _metricCard('TOTAL TIMED AUCTIONS', '${docs.length}', Icons.gavel, Colors.deepOrange),
                const SizedBox(width: 12),
                _metricCard('AUCTIONS ENGINE STATUS', _auctionsEnabled ? 'ACTIVE ✓' : 'PAUSED ✕', Icons.power_settings_new, _auctionsEnabled ? Colors.green : Colors.red),
              ],
            ),
            const SizedBox(height: 16),

            if (docs.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.gavel_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No Timed Auctions Currently Active',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sellers can launch timed pipe auctions anytime. Active auctions will appear here with live bidding controls.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final listingId = doc.id;
                final title = '${data['title'] ?? 'Pipe Auction'}';
                final currentBid = (data['highestBid'] as num?)?.toDouble() ??
                    ((data['unitPrice'] as num?)?.toDouble() ?? 0.0);
                final reserveMet = data['reserveMet'] == true;
                final sellerEmail = '${data['sellerEmail'] ?? data['sellerUid'] ?? 'Seller'}';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            Chip(
                              avatar: Icon(
                                reserveMet ? Icons.check_circle : Icons.error_outline,
                                size: 14,
                                color: reserveMet ? Colors.green : Colors.orange,
                              ),
                              label: Text(reserveMet ? 'RESERVE MET' : 'RESERVE NOT MET'),
                              backgroundColor: reserveMet ? Colors.green.shade50 : Colors.orange.shade50,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Current Highest Bid: \$${currentBid.toStringAsFixed(2)} • Seller: $sellerEmail',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _adminAuctionAction(listingId, 'force_end'),
                              icon: const Icon(Icons.gavel, color: Colors.purple),
                              label: const Text('Force End & Settle'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _adminAuctionAction(listingId, 'extend_24h'),
                              icon: const Icon(Icons.more_time, color: Colors.blue),
                              label: const Text('Extend +24 Hours'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _adminAuctionAction(listingId, 'cancel'),
                              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                              label: const Text('Cancel Auction'),
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

  Future<void> _adminAuctionAction(String listingId, String action) async {
    try {
      if (action == 'force_end') {
        await FirebaseFirestore.instance.collection('public_listings').doc(listingId).set({
          'status': 'Ended',
          'auctionEndedAt': FieldValue.serverTimestamp(),
          'endedByAdmin': FirebaseAuth.instance.currentUser?.email ?? 'admin',
        }, SetOptions(merge: true));
      } else if (action == 'extend_24h') {
        await FirebaseFirestore.instance.collection('public_listings').doc(listingId).set({
          'auctionExtendedCount': FieldValue.increment(1),
          'extendedByAdminAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (action == 'cancel') {
        await FirebaseFirestore.instance.collection('public_listings').doc(listingId).set({
          'status': 'Cancelled',
          'cancelledByAdminAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'Auction action executed: ${action.replaceAll('_', ' ')}',
          tone: PipeStatusTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        PipeFeedback.show(context, message: 'Auction action failed: $e', tone: PipeStatusTone.error);
      }
    }
  }

  // 3. Sales Payments & Escrow Transfers Tab
  Widget _buildTransactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('marketplace_transactions').limit(100).snapshots(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
        final docs = snapshot.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _explanationBanner(
              title: '💰 Sales Payments & Escrow Fund Transfers',
              explanation:
                  'This page monitors all marketplace funds (Buy-It-Now sales, accepted offers, and auction payouts). Funds are held safely in Escrow until the buyer inspects and approves the pipe. As Master Admin (jordilwbailey@gmail.com), you can click "Force Release Funds" to payout the seller or "Force Refund" to return money to the buyer.',
            ),
            if (isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.payments_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No Active Escrow Transactions',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'When buyers purchase pipe or equipment through Escrow Protection, transaction records and payout controls will appear here live.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final offerId = doc.id;
                final title = '${data['listingTitle'] ?? 'Pipe Listing'}';
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

  // 4. MODULAR BANKING & MERCHANT PROCESSING GATEWAYS TAB
  Widget _buildBankingGatewaysTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _explanationBanner(
                title: 'Company Banking & Merchant Processing Setup',
                explanation:
                    'Configure your company\'s bank account and payment gateway processors. Each provider has its own dedicated setup card with live status badges so you can configure banking, credit card processing, and escrow direct wires independently.',
              ),
              const SizedBox(height: 16),

              // Tile 1: Company Direct ACH / Wire Bank Vault
              _gatewayCard(
                brandIcon: Icons.account_balance,
                brandColor: Colors.blue.shade800,
                title: 'COMPANY DIRECT ACH / WIRE PAYOUT VAULT',
                subtitle: 'Direct deposit vault for all 3.5% seller commissions & escrow releases.',
                isConfigured: _companyBankName.text.isNotEmpty && _companyAccountNumber.text.isNotEmpty,
                onSave: _isSavingBank ? null : _saveBankCredentials,
                isSaving: _isSavingBank,
                children: [
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _companySwiftIban,
                    decoration: const InputDecoration(
                      labelText: 'SWIFT / BIC / IBAN Code (Global Payouts)',
                      hintText: 'e.g. CHASUS33 / BOFAUS3N',
                      prefixIcon: Icon(Icons.public),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tile 2: Stripe Commerce Payment Gateway
              _gatewayCard(
                brandIcon: Icons.credit_card,
                brandColor: Colors.deepPurple,
                title: 'STRIPE COMMERCE PAYMENT GATEWAY',
                subtitle: 'Accept Visa, Mastercard, AMEX, and instant ACH bank transfers.',
                isConfigured: _stripePublishableKey.text.isNotEmpty && _stripeSecretKey.text.isNotEmpty,
                onSave: _isSavingStripe ? null : _saveStripeCredentials,
                isSaving: _isSavingStripe,
                children: [
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stripeWebhookSecret,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Stripe Webhook Signing Secret (whsec_...)',
                      prefixIcon: Icon(Icons.webhook),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tile 3: PayPal Commerce & Venmo Gateway
              _gatewayCard(
                brandIcon: Icons.payment,
                brandColor: Colors.blue.shade900,
                title: 'PAYPAL COMMERCE & VENMO GATEWAY',
                subtitle: 'Accept PayPal Express Checkout, Venmo, and Pay in 4 installment financing.',
                isConfigured: _paypalClientId.text.isNotEmpty && _paypalSecretKey.text.isNotEmpty,
                onSave: _isSavingPaypal ? null : _savePaypalCredentials,
                isSaving: _isSavingPaypal,
                children: [
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _paypalMerchantId,
                    decoration: const InputDecoration(
                      labelText: 'PayPal Merchant Account ID',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tile 4: Authorize.Net Enterprise Escrow Gateway
              _gatewayCard(
                brandIcon: Icons.shield_outlined,
                brandColor: Colors.teal.shade800,
                title: 'AUTHORIZE.NET / ENTERPRISE ESCROW PROCESSING',
                subtitle: 'Enterprise escrow integration for multi-million dollar equipment purchases.',
                isConfigured: _authorizeApiLoginId.text.isNotEmpty && _authorizeTransactionKey.text.isNotEmpty,
                onSave: _isSavingAuthorize ? null : _saveAuthorizeCredentials,
                isSaving: _isSavingAuthorize,
                children: [
                  TextFormField(
                    controller: _authorizeApiLoginId,
                    decoration: const InputDecoration(
                      labelText: 'Authorize.Net API Login ID',
                      prefixIcon: Icon(Icons.fingerprint),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _authorizeTransactionKey,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Transaction Key',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gatewayCard({
    required IconData brandIcon,
    required Color brandColor,
    required String title,
    required String subtitle,
    required bool isConfigured,
    required VoidCallback? onSave,
    required bool isSaving,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isConfigured ? Colors.green.shade300 : Colors.grey.shade300),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: brandColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(brandIcon, color: brandColor, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            Chip(
              avatar: Icon(isConfigured ? Icons.check_circle : Icons.pending, size: 14, color: isConfigured ? Colors.green : Colors.orange),
              label: Text(isConfigured ? 'CONFIGURED ✓' : 'PENDING SETUP ⚙️', style: TextStyle(fontSize: 10, color: isConfigured ? Colors.green.shade900 : Colors.orange.shade900)),
              backgroundColor: isConfigured ? Colors.green.shade50 : Colors.orange.shade50,
            ),
          ],
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                ...children,
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save, size: 16),
                    label: Text(isSaving ? 'Saving…' : 'Save $title Credentials'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. Users Directory & Leaderboards Tab
  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(200).snapshots(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
        final docs = snapshot.data?.docs ?? [];
        final currentUser = FirebaseAuth.instance.currentUser;
        final masterEmail = currentUser?.email ?? 'jordilwbailey@gmail.com';

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
                  if (isLoading) const LinearProgressIndicator(),
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
              child: filtered.isEmpty
                  ? ListView(
                      children: [
                        ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.purple.shade100, child: const Icon(Icons.person, color: Colors.purple)),
                          title: Text(masterEmail, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('UID: ${currentUser?.uid ?? 'master-admin-uid'} • Role: ADMINISTRATOR'),
                          trailing: const Chip(label: Text('ADMINISTRATOR'), backgroundColor: Colors.purpleAccent),
                        ),
                      ],
                    )
                  : ListView.separated(
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

  // 6. Moderation & Trust Safety Tab
  Widget _buildModerationTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('reports').limit(50).snapshots(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
        final reports = snapshot.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _explanationBanner(
              title: 'Trust & Safety Moderation Intake',
              explanation:
                  'Review user reports, flagged listing photos, duplicate listings, or vulgar messages. Maintain marketplace trust and compliance.',
            ),
            if (isLoading) const LinearProgressIndicator(),
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

  // 7. Carrier Dispatch Logistics Tab
  Widget _buildDispatchTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('dispatch_jobs').limit(50).snapshots(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
        final jobs = snapshot.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _explanationBanner(
              title: 'Freight Dispatch & Logistics Board',
              explanation:
                  'Monitor all active hotshot trucking jobs, carrier per-mile freight quotes, and digital Bill of Lading (BOL) driver signatures.',
            ),
            if (isLoading) const LinearProgressIndicator(),
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

  // 8. System Feature Flags & Maintenance Mode Tab
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
