import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_auth_page.dart';
import 'pipebuyer_shop_client.dart';
import 'pipebuyer_shop_taxonomy.dart';

class PipeBuyerShopVendorApplyPage extends StatefulWidget {
  const PipeBuyerShopVendorApplyPage({
    super.key,
    this.client,
    this.initialTrack = 'industrial_distributor',
    this.initialBrand = '',
    this.skipAuthGateForTest = false,
  });

  final PipeBuyerShopClient? client;
  final String initialTrack;
  final String initialBrand;
  final bool skipAuthGateForTest;

  @override
  State<PipeBuyerShopVendorApplyPage> createState() =>
      _PipeBuyerShopVendorApplyPageState();
}

class _PipeBuyerShopVendorApplyPageState
    extends State<PipeBuyerShopVendorApplyPage> {
  late final PipeBuyerShopClient _client;
  final _formKey = GlobalKey<FormState>();

  final _companyController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  late final TextEditingController _brandsController;
  final _affiliateDetailsController = TextEditingController();
  final _notesController = TextEditingController();

  late String _selectedTrack;
  String _selectedSkuTier = '50–250 SKUs';
  final Set<String> _selectedCategories = <String>{
    'pipe_welding_fab',
    'power_hand_tools',
  };
  final Set<String> _selectedRegions = <String>{'US', 'CA'};

  bool _submitting = false;
  String? _submittedApplicationId;

  static const List<({String code, String title, String subtitle, IconData icon})>
      _tracks = <({String code, String title, String subtitle, IconData icon})>[
    (
      code: 'brand_manufacturer',
      title: 'Tool / Equipment Brand',
      subtitle: 'OEMs & brand reps (e.g., Milwaukee, RIDGID, Lincoln Electric, PPE)',
      icon: Icons.precision_manufacturing_outlined,
    ),
    (
      code: 'industrial_distributor',
      title: 'Authorized Distributor',
      subtitle: 'Regional or national industrial, rigging, welding & oilfield supply houses',
      icon: Icons.warehouse_outlined,
    ),
    (
      code: 'verified_business_vendor',
      title: 'Business Vendor Storefront',
      subtitle: 'Businesses selling tools, fabricated parts, consumables, or shop kits',
      icon: Icons.storefront_outlined,
    ),
    (
      code: 'affiliate_network_partner',
      title: 'Affiliate / Feed Partner',
      subtitle: 'Impact, CJ, AvantLink, Rakuten, or custom revenue-share catalog feed',
      icon: Icons.hub_outlined,
    ),
  ];

  static const List<String> _skuTiers = <String>[
    '1–50 SKUs',
    '50–250 SKUs',
    '250–1,000 SKUs',
    '1,000+ Full Catalog Feed',
  ];

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PipeBuyerShopClient();
    _selectedTrack = _tracks.any((t) => t.code == widget.initialTrack)
        ? widget.initialTrack
        : 'industrial_distributor';
    _brandsController = TextEditingController(text: widget.initialBrand);

    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _emailController.text = user.email ?? '';
        _contactController.text = user.displayName ?? '';
      }
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _brandsController.dispose();
    _affiliateDetailsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!widget.skipAuthGateForTest && Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const MarketplaceAuthPage()),
        );
        if (!mounted || FirebaseAuth.instance.currentUser == null) return;
      }
    }

    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      PipeFeedback.show(
        context,
        message: 'Select at least one Store product category.',
        tone: PipeStatusTone.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final brands = _brandsController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);

      final result = await _client.submitVendorApplication(
        companyName: _companyController.text.trim(),
        contactName: _contactController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        websiteUrl: _websiteController.text.trim(),
        partnershipTrack: _selectedTrack,
        categories: _selectedCategories.toList(growable: false),
        brandsCarried: brands,
        fulfillmentRegions: _selectedRegions.toList(growable: false),
        estimatedSkuCount: _selectedSkuTier,
        affiliateProgramDetails: _affiliateDetailsController.text.trim(),
        catalogNotes: _notesController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submittedApplicationId =
            result['applicationId']?.toString() ?? 'submitted';
      });
      PipeFeedback.show(
        context,
        message: 'Partner application received. Our Store team will review shortly.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PipeBuyerColors.canvas,
      appBar: AppBar(
        backgroundColor: PipeBuyerColors.ink,
        foregroundColor: Colors.white,
        title: const Text('Vendor, Distributor & Brand Portal'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: _submittedApplicationId != null
              ? _buildConfirmation(context)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
                  children: [
                    _buildHeroBanner(context),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTrackSelector(context),
                          const SizedBox(height: 16),
                          _buildBusinessDetailsCard(context),
                          const SizedBox(height: 16),
                          _buildCategoriesAndCatalogCard(context),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _submitting
                                  ? 'Submitting Partner Application...'
                                  : 'Submit Store Partner Application',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[PipeBuyerColors.ink, PipeBuyerColors.graphite],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: PipeBuyerColors.orange.withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: PipeBuyerColors.orange.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'PIPE BUYER PARTNER STORE ONBOARDING',
              style: TextStyle(
                color: PipeBuyerColors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'List Your Tools, Industrial Supplies & Brand Catalog on Pipe Buyer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Put Milwaukee-grade cordless tools, pipefitting & welding gear, DOT rigging, PPE, and shop supplies directly in front of active pipe buyers, contractors, haulers, and oilfield operators across North America.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .82),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackSelector(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Partnership Track',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose how your company or brand wants to partner with the Pipe Buyer Store.',
              style: TextStyle(color: PipeBuyerColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCol = constraints.maxWidth >= 580;
                final itemWidth =
                    twoCol ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _tracks.map((track) {
                    final selected = _selectedTrack == track.code;
                    return SizedBox(
                      width: itemWidth,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selectedTrack = track.code),
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: selected
                                ? PipeBuyerColors.orangeSoft
                                : PipeBuyerColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? PipeBuyerColors.orange
                                  : PipeBuyerColors.line,
                              width: selected ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                track.icon,
                                color: selected
                                    ? PipeBuyerColors.orangePressed
                                    : PipeBuyerColors.slate,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      track.subtitle,
                                      style: const TextStyle(
                                        color: PipeBuyerColors.muted,
                                        fontSize: 11.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessDetailsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '2. Company & Partner Contact',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Company, Distributor, or Brand Name *',
                hintText: 'e.g., Apex Industrial Supply / Milwaukee Authorized Dealer',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Enter your company or brand name.'
                  : null,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 560;
                final contactField = TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Primary Contact Name *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter a contact name.'
                      : null,
                );
                final phoneField = TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Direct Phone *',
                    hintText: '+1 (403) 555-0190',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.replaceAll(RegExp(r'\D'), '').length < 7)
                          ? 'Enter a valid business phone.'
                          : null,
                );
                if (!wide) {
                  return Column(
                    children: [
                      contactField,
                      const SizedBox(height: 12),
                      phoneField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: contactField),
                    const SizedBox(width: 12),
                    Expanded(child: phoneField),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Business Email *',
                hintText: 'partnerships@yourcompany.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) => (v == null || !v.contains('@') || !v.contains('.'))
                  ? 'Enter a valid business email.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _websiteController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Online Storefront or Catalog URL',
                hintText: 'https://www.yourcompany.com',
                prefixIcon: Icon(Icons.language_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesAndCatalogCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '3. Categories, Brands & Commercial Model',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select all Store categories your products fit:',
              style: TextStyle(color: PipeBuyerColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PipeBuyerShopTaxonomy.categories.map((cat) {
                final selected = _selectedCategories.contains(cat.code);
                return FilterChip(
                  selected: selected,
                  selectedColor: PipeBuyerColors.orangeSoft,
                  checkmarkColor: PipeBuyerColors.orangePressed,
                  label: Text(
                    cat.shortLabel,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedCategories.add(cat.code);
                      } else {
                        _selectedCategories.remove(cat.code);
                      }
                    });
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _brandsController,
              decoration: const InputDecoration(
                labelText: 'Brands Carried or Manufactured (comma-separated)',
                hintText: 'e.g., Milwaukee, RIDGID, Lincoln Electric, Crosby, House Brand',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedSkuTier,
              decoration: const InputDecoration(
                labelText: 'Estimated Catalog Size',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              items: _skuTiers
                  .map(
                    (tier) => DropdownMenuItem<String>(
                      value: tier,
                      child: Text(tier),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSkuTier = val);
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Fulfillment Regions',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: <({String code, String label})>[
                (code: 'US', label: 'United States'),
                (code: 'CA', label: 'Canada'),
                (code: 'GLOBAL', label: 'International Shipping'),
              ].map((region) {
                final selected = _selectedRegions.contains(region.code);
                return FilterChip(
                  selected: selected,
                  selectedColor: PipeBuyerColors.orangeSoft,
                  label: Text(region.label),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedRegions.add(region.code);
                      } else if (_selectedRegions.length > 1) {
                        _selectedRegions.remove(region.code);
                      }
                    });
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _affiliateDetailsController,
              decoration: const InputDecoration(
                labelText: 'Affiliate Network or Wholesale / Commission Structure',
                hintText:
                    'e.g., Impact / CJ affiliate program, 8% partner referral, or direct dealer feed',
                prefixIcon: Icon(Icons.percent_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catalog Highlights & Notes',
                hintText:
                    'Share top product lines, jobsite delivery SLA, or distributor authorization details.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmation(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.success.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: PipeBuyerColors.success,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Store Partner Application Submitted',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reference ID: $_submittedApplicationId\n\n'
                  'Our Pipe Buyer Store & Partnerships team will review your catalog, affiliate/commission setup, and brand authorization and reach out directly.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PipeBuyerColors.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Return to Pipe Buyer Store'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
