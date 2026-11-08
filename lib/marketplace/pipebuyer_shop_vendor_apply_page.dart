import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_navigation.dart';
import 'pipebuyer_shop_client.dart';
import 'pipebuyer_shop_taxonomy.dart';
import 'pipebuyer_site_footer.dart';

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
  final _contactTitleController = TextEditingController();
  final _headquartersController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _sampleCatalogUrlController = TextEditingController();
  late final TextEditingController _brandsController;
  final _affiliateDetailsController = TextEditingController();
  final _notesController = TextEditingController();

  late String _selectedTrack;
  String _selectedAuthLevel = 'authorized_dealer';
  String _selectedIntegrationMethod = 'direct_dealer_link';
  String _selectedSkuTier = '50–250 SKUs';

  final Set<String> _selectedPlacements = <String>{'shop_storefront'};
  final Set<String> _selectedCategories = <String>{
    'pipe_welding_fab',
    'power_hand_tools',
  };
  final Set<String> _selectedRegions = <String>{'US', 'CA'};

  bool _vendorApplicationsOpen = true;
  List<Map<String, dynamic>> _myApplications = const <Map<String, dynamic>>[];

  bool _submitting = false;
  String? _submittedApplicationId;
  Map<String, dynamic>? _submittedNotificationSummary;

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
    final tracks = PipeBuyerShopTaxonomy.vendorPartnershipTracks;
    _selectedTrack = tracks.any((t) => t.code == widget.initialTrack)
        ? widget.initialTrack
        : 'industrial_distributor';
    if (_selectedTrack == 'oem_heavy_equipment_dealer') {
      _selectedCategories.add('heavy_equipment_oem');
      _selectedPlacements.add('heavy_equipment_listings');
    } else if (_selectedTrack == 'brand_manufacturer') {
      _selectedAuthLevel = 'oem_direct';
    }
    _brandsController = TextEditingController(text: widget.initialBrand);

    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _emailController.text = user.email ?? '';
        _contactController.text = user.displayName ?? '';
      }
    }
    _loadPortalContext();
  }

  Future<void> _loadPortalContext() async {
    try {
      final catalogFuture = _client.loadStoreCatalog();
      final myAppsFuture = _client.listMyVendorApplications();
      final catalog = await catalogFuture;
      final myApps = await myAppsFuture;
      if (!mounted) return;
      setState(() {
        _vendorApplicationsOpen = catalog.settings.vendorApplicationsOpen;
        _myApplications = myApps;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _companyController.dispose();
    _contactController.dispose();
    _contactTitleController.dispose();
    _headquartersController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _sampleCatalogUrlController.dispose();
    _brandsController.dispose();
    _affiliateDetailsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Set<String> _parsedBrandSet() {
    return _brandsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  void _toggleSuggestedBrand(String brand) {
    final current = _brandsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final existingIdx = current.indexWhere(
      (b) => b.toLowerCase() == brand.toLowerCase(),
    );
    setState(() {
      if (existingIdx >= 0) {
        current.removeAt(existingIdx);
      } else {
        current.add(brand);
      }
      _brandsController.text = current.join(', ');
    });
  }

  String? _validateOptionalUrl(String? raw, String label) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return null;
    final candidate =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed.replaceFirst(
                RegExp(r'^http://', caseSensitive: false),
                'https://',
              )
            : 'https://$trimmed';
    if (!PipeBuyerShopUrlBuilder.isSafeHttpsUrl(candidate)) {
      return 'Enter a valid public $label (e.g., https://www.yourcompany.com).';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_vendorApplicationsOpen) {
      PipeFeedback.show(
        context,
        message:
            'Partner applications are temporarily paused while we onboard current catalogs.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      PipeFeedback.show(
        context,
        message: 'Select at least one product or equipment category.',
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
        contactTitle: _contactTitleController.text.trim(),
        headquartersLocation: _headquartersController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        websiteUrl: _websiteController.text.trim(),
        sampleCatalogUrl: _sampleCatalogUrlController.text.trim(),
        partnershipTrack: _selectedTrack,
        authorizationLevel: _selectedAuthLevel,
        requestedPlacements: _selectedPlacements.isEmpty
            ? const <String>['shop_storefront']
            : _selectedPlacements.toList(growable: false),
        categories: _selectedCategories.toList(growable: false),
        brandsCarried: brands,
        fulfillmentRegions: _selectedRegions.toList(growable: false),
        catalogIntegrationMethod: _selectedIntegrationMethod,
        estimatedSkuCount: _selectedSkuTier,
        affiliateProgramDetails: _affiliateDetailsController.text.trim(),
        catalogNotes: _notesController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submittedApplicationId =
            result['applicationId']?.toString() ?? 'submitted';
        _submittedNotificationSummary = result['notificationSummary'] is Map
            ? Map<String, dynamic>.from(result['notificationSummary'] as Map)
            : null;
      });
      PipeFeedback.show(
        context,
        message:
            'Listing request submitted! Pipe Buyer Administrators have been notified.',
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

  void _resetForAnotherRequest() {
    setState(() {
      _submittedApplicationId = null;
      _submittedNotificationSummary = null;
      _companyController.clear();
      _sampleCatalogUrlController.clear();
      _notesController.clear();
    });
    _loadPortalContext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PipeBuyerColors.canvas,
      appBar: AppBar(
        backgroundColor: PipeBuyerColors.ink,
        foregroundColor: Colors.white,
        title: const Text('Vendor, Distributor & Brand Portal'),
        bottom: const PipeBuyerGlobalHubBar(
          currentHub: PipeBuyerGlobalHub.shopVendorApply,
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: _submittedApplicationId != null
              ? _buildConfirmation(context)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                  children: [
                    const PipeBuyerOnboardingTrackBar(
                      currentTrack: PipeBuyerOnboardingTrack.storeVendorCatalog,
                    ),
                    const SizedBox(height: 14),
                    _buildHeroBanner(context),
                    if (!_vendorApplicationsOpen) ...[
                      const SizedBox(height: 14),
                      _buildApplicationsPausedBanner(),
                    ],
                    if (_myApplications.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildMySubmittedRequestsCard(),
                    ],
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
                            onPressed: (!_vendorApplicationsOpen || _submitting)
                                ? null
                                : _submit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                            ),
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
                    const SizedBox(height: 24),
                    const PipeBuyerSiteFooter(),
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
              'REQUEST TO LIST ON PIPE BUYER • OEM, DEALER & BRAND PORTAL',
              style: TextStyle(
                color: PipeBuyerColors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Request to List Your Equipment, Tools & Brand Catalog on Pipe Buyer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Built for heavy equipment OEMs & authorized dealers (Caterpillar, Brandt Tractor, John Deere, Komatsu), professional tool & diagnostic manufacturers (Milwaukee, Snap-on, RIDGID, Lincoln Electric), and industrial distributors across North America. No consumer sign-in required — your request notifies our Partnerships & Store Admin team immediately.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .84),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <Widget>[
              _HeroFeaturePill(
                icon: Icons.notifications_active_outlined,
                label: 'Instant Admin & Store Manager Alert',
              ),
              _HeroFeaturePill(
                icon: Icons.verified_outlined,
                label: 'OEM, Dealer & Brand Authorization',
              ),
              _HeroFeaturePill(
                icon: Icons.sync_alt_rounded,
                label: 'Direct Links, CSV, or Dealer XML Feeds',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsPausedBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PipeBuyerColors.warning.withValues(alpha: .5),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.pause_circle_outline_rounded,
            color: PipeBuyerColors.warning,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'New Store & Brand onboarding applications are temporarily paused while our team completes the current wave of partner reviews.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: PipeBuyerColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMySubmittedRequestsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 19,
                  color: PipeBuyerColors.industrialBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  'My Submitted Listing Requests (${_myApplications.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._myApplications.take(5).map((app) {
              final status =
                  (app['status']?.toString() ?? 'pending').toLowerCase();
              final statusColor = switch (status) {
                'approved' => PipeBuyerColors.success,
                'under_review' => PipeBuyerColors.industrialBlue,
                'declined' => PipeBuyerColors.danger,
                _ => PipeBuyerColors.orange,
              };
              final notes = app['reviewNotes']?.toString().trim() ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PipeBuyerColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PipeBuyerColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          app['companyName']?.toString() ?? 'Partner Request',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ref: ${app['id'] ?? ''} • ${PipeBuyerShopTaxonomy.vendorTrackLabel(app['partnershipTrack']?.toString())}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: PipeBuyerColors.muted,
                      ),
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Admin Note: $notes',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PipeBuyerColors.ink,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackSelector(BuildContext context) {
    final tracks = PipeBuyerShopTaxonomy.vendorPartnershipTracks;
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
              'Choose how your OEM, dealership, brand, or supply house wants to list on Pipe Buyer.',
              style: TextStyle(color: PipeBuyerColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCol = constraints.maxWidth >= 580;
                final itemWidth = twoCol
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: tracks.map((track) {
                    final selected = _selectedTrack == track.code;
                    return SizedBox(
                      width: itemWidth,
                      child: InkWell(
                        key: Key('vendor_track_${track.code}'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _selectedTrack = track.code;
                            if (track.code == 'oem_heavy_equipment_dealer') {
                              _selectedCategories.add(
                                'heavy_equipment_oem',
                              );
                              _selectedPlacements.add(
                                'heavy_equipment_listings',
                              );
                            } else if (track.code == 'brand_manufacturer') {
                              _selectedAuthLevel = 'oem_direct';
                            }
                          });
                        },
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
            const SizedBox(height: 4),
            const Text(
              'Provide direct corporate, dealer, or territory manager contact details for our Partnerships team.',
              style: TextStyle(color: PipeBuyerColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Company, Distributor, or Brand Name *',
                hintText:
                    'e.g., Caterpillar / Brandt Tractor / Milwaukee Tool / Snap-on Industrial',
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
                final titleField = TextFormField(
                  controller: _contactTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Role / Job Title',
                    hintText: 'e.g., VP Fleet Partnerships / Territory Manager',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                );
                if (!wide) {
                  return Column(
                    children: [
                      contactField,
                      const SizedBox(height: 12),
                      titleField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: contactField),
                    const SizedBox(width: 12),
                    Expanded(child: titleField),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 560;
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
                final emailField = TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Business Email *',
                    hintText: 'partnerships@yourcompany.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) =>
                      (v == null || !v.contains('@') || !v.contains('.'))
                          ? 'Enter a valid business email.'
                          : null,
                );
                if (!wide) {
                  return Column(
                    children: [
                      phoneField,
                      const SizedBox(height: 12),
                      emailField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: phoneField),
                    const SizedBox(width: 12),
                    Expanded(child: emailField),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _headquartersController,
              decoration: const InputDecoration(
                labelText: 'Headquarters or Authorized Dealer Territory',
                hintText:
                    'e.g., Regina, SK • Peoria, IL • Western Canada & US Permian',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 560;
                final websiteField = TextFormField(
                  controller: _websiteController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Online Storefront or Catalog URL',
                    hintText: 'https://www.yourcompany.com',
                    prefixIcon: Icon(Icons.language_outlined),
                  ),
                  validator: (v) => _validateOptionalUrl(v, 'website URL'),
                );
                final sampleCatalogField = TextFormField(
                  controller: _sampleCatalogUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Sample Product / Dealer Inventory URL',
                    hintText: 'https://www.yourcompany.com/equipment-lineup',
                    prefixIcon: Icon(Icons.inventory_outlined),
                  ),
                  validator: (v) =>
                      _validateOptionalUrl(v, 'sample catalog URL'),
                );
                if (!wide) {
                  return Column(
                    children: [
                      websiteField,
                      const SizedBox(height: 12),
                      sampleCatalogField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: websiteField),
                    const SizedBox(width: 12),
                    Expanded(child: sampleCatalogField),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesAndCatalogCard(BuildContext context) {
    final activeBrandsLower =
        _parsedBrandSet().map((b) => b.toLowerCase()).toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '3. App Placement, Categories, Brands & Integration',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Where would you like your products or equipment showcased on Pipe Buyer?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PipeBuyerShopTaxonomy.vendorRequestedPlacements
                  .map((placement) {
                final selected = _selectedPlacements.contains(
                  placement.code,
                );
                return FilterChip(
                  key: Key('vendor_placement_${placement.code}'),
                  selected: selected,
                  selectedColor: PipeBuyerColors.orangeSoft,
                  checkmarkColor: PipeBuyerColors.orangePressed,
                  label: Text(
                    placement.label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedPlacements.add(placement.code);
                      } else if (_selectedPlacements.length > 1) {
                        _selectedPlacements.remove(placement.code);
                      }
                    });
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select all equipment & Store categories your catalog fits:',
              style: TextStyle(color: PipeBuyerColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PipeBuyerShopTaxonomy.allVendorApplicationCategories
                  .map((cat) {
                final selected = _selectedCategories.contains(cat.code);
                return FilterChip(
                  key: Key('vendor_cat_${cat.code}'),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _brandsController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Brands Carried or Manufactured (comma-separated)',
                hintText:
                    'e.g., Caterpillar, Brandt Tractor, Milwaukee, Snap-on, RIDGID, Lincoln Electric',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quick-add major OEM & industrial brands:',
              style: TextStyle(fontSize: 11.5, color: PipeBuyerColors.muted),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: PipeBuyerShopTaxonomy.popularPartnerBrandSuggestions
                  .map((brand) {
                final selected = activeBrandsLower.contains(
                  brand.toLowerCase(),
                );
                return ActionChip(
                  key: Key(
                    'brand_chip_${brand.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
                  ),
                  backgroundColor: selected
                      ? PipeBuyerColors.orangeSoft
                      : PipeBuyerColors.surfaceMuted,
                  side: BorderSide(
                    color: selected
                        ? PipeBuyerColors.orange
                        : PipeBuyerColors.line,
                  ),
                  avatar: Icon(
                    selected ? Icons.check_rounded : Icons.add_rounded,
                    size: 15,
                    color: selected
                        ? PipeBuyerColors.orangePressed
                        : PipeBuyerColors.slate,
                  ),
                  label: Text(
                    brand,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _toggleSuggestedBrand(brand),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedAuthLevel,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Brand / Dealer Authorization Level',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
              items: PipeBuyerShopTaxonomy.vendorAuthorizationLevels
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.code,
                      child: Text(item.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (val) {
                if (val != null) setState(() => _selectedAuthLevel = val);
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 620;
                final skuDropdown = DropdownButtonFormField<String>(
                  initialValue: _selectedSkuTier,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Estimated Catalog Size',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  items: _skuTiers
                      .map(
                        (tier) => DropdownMenuItem<String>(
                          value: tier,
                          child: Text(tier, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSkuTier = val);
                  },
                );
                final feedDropdown = DropdownButtonFormField<String>(
                  initialValue: _selectedIntegrationMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Catalog Onboarding Method',
                    prefixIcon: Icon(Icons.sync_alt_rounded),
                  ),
                  items: PipeBuyerShopTaxonomy.vendorIntegrationMethods
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.code,
                          child: Text(
                            item.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedIntegrationMethod = val);
                    }
                  },
                );
                if (!wide) {
                  return Column(
                    children: [
                      skuDropdown,
                      const SizedBox(height: 12),
                      feedDropdown,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: skuDropdown),
                    const SizedBox(width: 12),
                    Expanded(child: feedDropdown),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Fulfillment & Dealer Coverage Regions',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                labelText:
                    'Dealer Lead Routing, Affiliate Network, or Commercial Structure',
                hintText:
                    'e.g., Direct OEM dealer quote routing, Impact / CJ program, or wholesale catalog feed',
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
                    'Share flagship equipment/tool lines, territory coverage, dealer branches, or onboarding timeline.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmation(BuildContext context) {
    final refId = _submittedApplicationId ?? 'submitted';
    final receiptSent =
        _submittedNotificationSummary?['applicantConfirmationSent'] == true;

    return SingleChildScrollView(
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
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: PipeBuyerColors.success.withValues(alpha: .35),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      size: 16,
                      color: PipeBuyerColors.success,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Pipe Buyer Administrators & Store Managers Notified',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: PipeBuyerColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: refId));
                  PipeFeedback.show(
                    context,
                    message: 'Copied Reference ID ($refId) to clipboard.',
                    tone: PipeStatusTone.info,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PipeBuyerColors.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Reference ID: $refId',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy_rounded, size: 15),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                receiptSent
                    ? 'A confirmation receipt has been sent to ${_emailController.text.trim()}. Our Pipe Buyer Store & Brand Partnerships team will review your product lines, dealer/brand authorization, and preferred integration method and reach out directly.'
                    : 'Our Pipe Buyer Store & Brand Partnerships team has received your listing request and will review your product lines, dealer/brand authorization, and preferred integration method and reach out directly.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PipeBuyerColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      final nav = Navigator.of(context);
                      if (nav.canPop()) {
                        nav.pop(true);
                      } else {
                        MarketplaceNavigation.openShopStore(context);
                      }
                    },
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Return to Pipe Buyer Store'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _resetForAnotherRequest,
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Submit Another Request'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroFeaturePill extends StatelessWidget {
  const _HeroFeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: PipeBuyerColors.orange),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
