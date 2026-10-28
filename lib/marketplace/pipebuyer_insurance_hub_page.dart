import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_deep_links.dart';
import 'marketplace_public_information.dart';
import 'pipebuyer_business_logo_widgets.dart';
import 'pipebuyer_insurance_client.dart';
import 'pipebuyer_insurance_provider_apply_page.dart';
import 'pipebuyer_insurance_taxonomy.dart';
import 'pipebuyer_site_footer.dart';

enum InsuranceHubTab {
  browseProviders,
  applyForRates,
  myApplicationsAndCarriers,
}

class PipeBuyerInsuranceHubPage extends StatefulWidget {
  const PipeBuyerInsuranceHubPage({
    super.key,
    this.client,
    this.initialTab = InsuranceHubTab.browseProviders,
    this.initialQuery = '',
    this.initialCoverageLine = '',
    this.initialCountryCode = '',
    this.useShowcaseFallbackWhenEmpty = false,
  });

  final PipeBuyerInsuranceClient? client;
  final InsuranceHubTab initialTab;
  final String initialQuery;
  final String initialCoverageLine;
  final String initialCountryCode;
  final bool useShowcaseFallbackWhenEmpty;

  @override
  State<PipeBuyerInsuranceHubPage> createState() =>
      _PipeBuyerInsuranceHubPageState();
}

class _PipeBuyerInsuranceHubPageState extends State<PipeBuyerInsuranceHubPage> {
  late final PipeBuyerInsuranceClient _client;
  late InsuranceHubTab _activeTab;

  // Browse filters
  late final TextEditingController _searchController;
  String _selectedCoverageLineFilter = '';
  String _selectedCountryFilter = '';
  String _selectedRegionFilter = '';
  String _selectedProviderTypeFilter = '';
  bool _msaOnlyFilter = false;
  bool _fastCoiOnlyFilter = false;

  bool _loadingProviders = true;
  bool _usingShowcaseFallback = false;
  bool _hasSeenLiveProviders = false;
  String? _providerLoadError;
  List<InsuranceProviderListing> _providers =
      const <InsuranceProviderListing>[];

  // Rate application form state
  final _rateFormKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _regionController = TextEditingController(text: 'TX');
  final _cityController = TextEditingController();
  final _fleetCountController = TextEditingController(text: '5');
  final _equipmentValueController = TextEditingController(text: '750000');
  final _dotOrMcController = TextEditingController();
  final _effectiveDateController = TextEditingController();
  final _claimsSummaryController = TextEditingController();
  final _notesController = TextEditingController();

  String _rateCountryCode = 'US';
  String _annualRevenueBand = '2m_10m';
  final Set<String> _rateOperatingBasins = <String>{'Permian Basin'};
  final Set<String> _rateCoverageLines = <String>{
    'commercial_auto_fleet',
    'oilfield_general_liability',
  };
  final Set<String> _rateMsaRequirements = <String>{
    'waiver_of_subrogation',
    'additional_insured',
    'primary_non_contributory',
  };

  InsuranceProviderListing? _selectedTargetProvider;
  bool _submittingRateApp = false;
  PipeBuyerInsuranceRateSubmissionResult? _latestReceipt;

  // My rate applications state
  bool _loadingMyApps = false;
  final List<InsuranceRateApplicationSummary> _sessionSubmittedApps =
      <InsuranceRateApplicationSummary>[];
  List<InsuranceRateApplicationSummary> _serverMyApps =
      const <InsuranceRateApplicationSummary>[];

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PipeBuyerInsuranceClient();
    _activeTab = widget.initialTab;
    _searchController = TextEditingController(text: widget.initialQuery);
    _selectedCoverageLineFilter = widget.initialCoverageLine.trim();
    _selectedCountryFilter = widget.initialCountryCode.trim().toUpperCase();

    final email = _client.currentUserEmail;
    final name = _client.currentUserDisplayName;
    if (email.isNotEmpty) _emailController.text = email;
    if (name.isNotEmpty) _contactNameController.text = name;

    _loadProviders();
    if (_client.isSignedIn) {
      _loadMyApplications();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _companyNameController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _fleetCountController.dispose();
    _equipmentValueController.dispose();
    _dotOrMcController.dispose();
    _effectiveDateController.dispose();
    _claimsSummaryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _hasActiveBrowseFilters =>
      _searchController.text.trim().isNotEmpty ||
      _selectedCoverageLineFilter.isNotEmpty ||
      _selectedCountryFilter.isNotEmpty ||
      _selectedRegionFilter.isNotEmpty ||
      _selectedProviderTypeFilter.isNotEmpty ||
      _msaOnlyFilter ||
      _fastCoiOnlyFilter;

  Future<void> _loadProviders() async {
    setState(() {
      _loadingProviders = true;
      _providerLoadError = null;
    });

    try {
      final res = await _client.listProviders(
        query: _searchController.text.trim(),
        coverageLine: _selectedCoverageLineFilter,
        countryCode: _selectedCountryFilter,
        regionCode: _selectedRegionFilter,
        providerType: _selectedProviderTypeFilter,
        msaOnly: _msaOnlyFilter,
        fastCoiOnly: _fastCoiOnlyFilter,
      );
      if (!mounted) return;

      if (res.providers.isNotEmpty) {
        setState(() {
          _hasSeenLiveProviders = true;
          _usingShowcaseFallback = false;
          _providers = res.providers;
          _loadingProviders = false;
        });
        return;
      }

      if (!_hasSeenLiveProviders && widget.useShowcaseFallbackWhenEmpty) {
        final filteredShowcase = PipeBuyerInsuranceTaxonomy.showcaseProviders
            .where(
              (provider) => provider.matchesFilters(
                query: _searchController.text,
                coverageLine: _selectedCoverageLineFilter,
                countryFilter: _selectedCountryFilter,
                regionFilter: _selectedRegionFilter,
                providerTypeFilter: _selectedProviderTypeFilter,
                msaOnly: _msaOnlyFilter,
                fastCoiOnly: _fastCoiOnlyFilter,
              ),
            )
            .toList(growable: false);
        setState(() {
          _usingShowcaseFallback = true;
          _providers = filteredShowcase;
          _loadingProviders = false;
        });
        return;
      }

      setState(() {
        _usingShowcaseFallback = false;
        _providers = const <InsuranceProviderListing>[];
        _loadingProviders = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (widget.useShowcaseFallbackWhenEmpty && !_hasSeenLiveProviders) {
        final filteredShowcase = PipeBuyerInsuranceTaxonomy.showcaseProviders
            .where(
              (provider) => provider.matchesFilters(
                query: _searchController.text,
                coverageLine: _selectedCoverageLineFilter,
                countryFilter: _selectedCountryFilter,
                regionFilter: _selectedRegionFilter,
                providerTypeFilter: _selectedProviderTypeFilter,
                msaOnly: _msaOnlyFilter,
                fastCoiOnly: _fastCoiOnlyFilter,
              ),
            )
            .toList(growable: false);
        setState(() {
          _usingShowcaseFallback = true;
          _providers = filteredShowcase;
          _loadingProviders = false;
        });
      } else {
        setState(() {
          _providerLoadError = '$error'.replaceFirst('Bad state: ', '');
          _loadingProviders = false;
        });
      }
    }
  }

  Future<void> _loadMyApplications() async {
    if (!_client.isSignedIn) return;
    setState(() => _loadingMyApps = true);
    try {
      final apps = await _client.listMyRateApplications();
      if (!mounted) return;
      setState(() {
        _serverMyApps = apps;
        _loadingMyApps = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMyApps = false);
    }
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedCoverageLineFilter = '';
      _selectedCountryFilter = '';
      _selectedRegionFilter = '';
      _selectedProviderTypeFilter = '';
      _msaOnlyFilter = false;
      _fastCoiOnlyFilter = false;
    });
    _loadProviders();
  }

  void _startMultiCarrierQuote() {
    setState(() {
      _selectedTargetProvider = null;
      _latestReceipt = null;
      _activeTab = InsuranceHubTab.applyForRates;
    });
  }

  void _startCoverageLaneQuote(InsuranceCoverageLine line) {
    setState(() {
      _selectedTargetProvider = null;
      _latestReceipt = null;
      _rateCoverageLines
        ..clear()
        ..add(line.code);
      _activeTab = InsuranceHubTab.applyForRates;
    });
  }

  void _startTargetedProviderQuote(InsuranceProviderListing provider) {
    setState(() {
      _selectedTargetProvider = provider.isSampleShowcase ? null : provider;
      _latestReceipt = null;
      if (provider.coverageLines.isNotEmpty) {
        _rateCoverageLines
          ..clear()
          ..addAll(provider.coverageLines.take(3));
      }
      _activeTab = InsuranceHubTab.applyForRates;
    });
  }

  Future<void> _openProviderOnboarding() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PipeBuyerInsuranceProviderApplyPage(client: _client),
      ),
    );
  }

  Future<void> _pickEffectiveDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null && mounted) {
      final yyyy = picked.year.toString().padLeft(4, '0');
      final mm = picked.month.toString().padLeft(2, '0');
      final dd = picked.day.toString().padLeft(2, '0');
      setState(() {
        _effectiveDateController.text = '$yyyy-$mm-$dd';
      });
    }
  }

  Future<void> _submitRateApplication() async {
    if (!_rateFormKey.currentState!.validate()) return;
    if (_rateCoverageLines.isEmpty) {
      PipeFeedback.show(
        context,
        message: 'Select at least one commercial coverage line needed.',
        tone: PipeStatusTone.warning,
      );
      return;
    }

    setState(() => _submittingRateApp = true);
    try {
      final fleetCount = int.tryParse(
            _fleetCountController.text.replaceAll(',', '').trim(),
          ) ??
          0;
      final equipmentValue = double.tryParse(
            _equipmentValueController.text
                .replaceAll(',', '')
                .replaceAll('\$', '')
                .trim(),
          ) ??
          0;

      final targetProvider = _selectedTargetProvider;
      final isShowcaseTarget = targetProvider?.isSampleShowcase == true;

      final receipt = await _client.submitRateApplication(
        companyName: _companyNameController.text.trim(),
        contactName: _contactNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        countryCode: _rateCountryCode,
        regionCode: _regionController.text.trim().toUpperCase(),
        city: _cityController.text.trim(),
        operatingBasins: _rateOperatingBasins.toList(growable: false),
        coverageLines: _rateCoverageLines.toList(growable: false),
        msaRequirements: _rateMsaRequirements.toList(growable: false),
        fleetVehicleCount: fleetCount,
        equipmentValueUsd: equipmentValue,
        annualRevenueBand: _annualRevenueBand,
        dotOrMcNumber: _dotOrMcController.text.trim(),
        desiredEffectiveDate: _effectiveDateController.text.trim(),
        claimsSummary: _claimsSummaryController.text.trim(),
        targetProviderId: isShowcaseTarget ? null : targetProvider?.providerId,
        targetProviderName: targetProvider?.companyName ?? '',
        notes: _notesController.text.trim(),
      );

      final localSummary = InsuranceRateApplicationSummary(
        applicationId: receipt.applicationId,
        companyName: _companyNameController.text.trim(),
        contactName: _contactNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        countryCode: _rateCountryCode,
        regionCode: _regionController.text.trim().toUpperCase(),
        city: _cityController.text.trim(),
        operatingBasins: _rateOperatingBasins.toList(growable: false),
        coverageLines: _rateCoverageLines.toList(growable: false),
        msaRequirements: _rateMsaRequirements.toList(growable: false),
        fleetVehicleCount: fleetCount,
        equipmentValueUsd: equipmentValue,
        annualRevenueBand: _annualRevenueBand,
        dotOrMcNumber: _dotOrMcController.text.trim(),
        desiredEffectiveDate: _effectiveDateController.text.trim(),
        claimsSummary: _claimsSummaryController.text.trim(),
        targetProviderId:
            receipt.targetProviderId ?? targetProvider?.providerId,
        targetProviderName: receipt.targetProviderName.isNotEmpty
            ? receipt.targetProviderName
            : (targetProvider?.companyName ?? ''),
        distributionMode: receipt.distributionMode,
        status: receipt.status,
      );

      if (!mounted) return;
      setState(() {
        _submittingRateApp = false;
        _latestReceipt = receipt;
        _sessionSubmittedApps.insert(0, localSummary);
      });
      if (_client.isSignedIn) {
        _loadMyApplications();
      }
      PipeFeedback.show(
        context,
        message: 'Commercial insurance rate application submitted.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submittingRateApp = false);
      PipeFeedback.show(
        context,
        message: '$error'.replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  List<InsuranceRateApplicationSummary> get _combinedMyApplications {
    final seen = <String>{};
    final combined = <InsuranceRateApplicationSummary>[];
    for (final item in <InsuranceRateApplicationSummary>[
      ..._serverMyApps,
      ..._sessionSubmittedApps,
    ]) {
      if (item.applicationId.isNotEmpty && !seen.add(item.applicationId)) {
        continue;
      }
      combined.add(item);
    }
    return combined;
  }

  void _openPublicPolicy(
    String path,
    MarketplacePublicInformationKind fallbackKind,
  ) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(path);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketplacePublicInformationPage(kind: fallbackKind),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PipeBuyerColors.canvas,
      appBar: AppBar(
        backgroundColor: PipeBuyerColors.ink,
        foregroundColor: Colors.white,
        title: const Text('COMMERCIAL & OILFIELD INSURANCE'),
        actions: [
          if (MediaQuery.sizeOf(context).width >= 720)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _openProviderOnboarding,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(
                  Icons.domain_add_outlined,
                  size: 18,
                  color: PipeBuyerColors.orange,
                ),
                label: const Text('List Insurance Company'),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1220),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroBanner(context),
                const SizedBox(height: 16),
                _buildSectionSwitcher(context),
                const SizedBox(height: 16),
                switch (_activeTab) {
                  InsuranceHubTab.browseProviders =>
                    _buildBrowseProvidersSection(context),
                  InsuranceHubTab.applyForRates =>
                    _buildApplyForRatesSection(context),
                  InsuranceHubTab.myApplicationsAndCarriers =>
                    _buildMyApplicationsAndCarriersSection(context),
                },
                const SizedBox(height: 24),
                _buildComplianceFooter(context),
                const SizedBox(height: 24),
                const PipeBuyerSiteFooter(
                  currentSurface: PipeBuyerFooterSurface.insurance,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 640;
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            PipeBuyerColors.ink,
            PipeBuyerColors.charcoal,
            PipeBuyerColors.graphite,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PipeBuyerColors.orange.withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroBadge(
                icon: Icons.verified_user_rounded,
                label: 'MSA-READY COMMERCIAL COVERAGE',
                backgroundColor: PipeBuyerColors.orange.withValues(alpha: .20),
                foregroundColor: PipeBuyerColors.orange,
              ),
              _HeroBadge(
                icon: Icons.bolt_rounded,
                label: '24/7 COI & MULTI-CARRIER MATCHING',
                backgroundColor:
                    PipeBuyerColors.industrialBlue.withValues(alpha: .30),
                foregroundColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Commercial & Oilfield Insurance Rate Hub',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 23 : 32,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Browse verified commercial carriers, MGAs, and oil & gas specialty brokers across the US & Canada — or apply for fleet, rig, OCTG cargo, general liability, pollution, and umbrella rates directly from Pipe Buyer.',
            style: TextStyle(
              color: const Color(0xFFD5DCE6),
              fontSize: isMobile ? 13 : 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const Key('hero_get_multi_carrier_quotes'),
                onPressed: _startMultiCarrierQuote,
                icon: const Icon(Icons.request_quote_outlined, size: 19),
                label: const Text('Get Multi-Carrier Quotes'),
              ),
              OutlinedButton.icon(
                key: const Key('hero_list_insurance_company'),
                onPressed: _openProviderOnboarding,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: .35)),
                ),
                icon: const Icon(
                  Icons.workspace_premium_outlined,
                  size: 19,
                  color: PipeBuyerColors.orange,
                ),
                label: const Text('List Your Insurance Company'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSwitcher(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final tabs = <({
          InsuranceHubTab tab,
          IconData icon,
          String title,
          String subtitle,
          Key key,
        })>[
          (
            tab: InsuranceHubTab.browseProviders,
            icon: Icons.verified_user_outlined,
            title: 'Browse Insurance Providers',
            subtitle: 'Verified carriers, MGAs & brokers',
            key: const Key('insurance_tab_browse'),
          ),
          (
            tab: InsuranceHubTab.applyForRates,
            icon: Icons.assignment_outlined,
            title: 'Apply for Company Rates',
            subtitle: 'Direct commercial quote application',
            key: const Key('insurance_tab_apply_rates'),
          ),
          (
            tab: InsuranceHubTab.myApplicationsAndCarriers,
            icon: Icons.business_center_outlined,
            title: 'My Applications & Carrier Portal',
            subtitle: 'Track quotes or list your agency',
            key: const Key('insurance_tab_my_apps'),
          ),
        ];

        final cardWidth =
            wide ? (constraints.maxWidth - 20) / 3 : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 8,
          children: tabs
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: _HubTabCard(
                    key: item.key,
                    icon: item.icon,
                    title: item.title,
                    subtitle: item.subtitle,
                    selected: _activeTab == item.tab,
                    onTap: () {
                      setState(() => _activeTab = item.tab);
                      if (item.tab ==
                              InsuranceHubTab.myApplicationsAndCarriers &&
                          _client.isSignedIn) {
                        _loadMyApplications();
                      }
                    },
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildBrowseProvidersSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 680;
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSearchField(),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _loadProviders,
                          icon: const Icon(Icons.search_rounded, size: 18),
                          label: const Text('Filter Providers'),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: _buildSearchField()),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _loadProviders,
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text('Filter Providers'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 195,
                    child: DropdownButtonFormField<String>(
                      key: const Key('insurance_country_dropdown'),
                      initialValue: _selectedCountryFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '',
                          child: Text('All Countries'),
                        ),
                        DropdownMenuItem(
                          value: 'US',
                          child: Text('United States (US)'),
                        ),
                        DropdownMenuItem(
                          value: 'CA',
                          child: Text('Canada (CA)'),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedCountryFilter = val ?? '');
                        _loadProviders();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 175,
                    child: DropdownButtonFormField<String>(
                      key: const Key('insurance_region_dropdown'),
                      initialValue: _selectedRegionFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'State / Province',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All Regions'),
                        ),
                        ...PipeBuyerInsuranceTaxonomy.popularRegions.map(
                          (code) => DropdownMenuItem(
                            value: code,
                            child: Text(code),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedRegionFilter = val ?? '');
                        _loadProviders();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 225,
                    child: DropdownButtonFormField<String>(
                      key: const Key('insurance_provider_type_dropdown'),
                      initialValue: _selectedProviderTypeFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Provider Type',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All Provider Types'),
                        ),
                        ...PipeBuyerInsuranceTaxonomy.providerTypes.map(
                          (t) => DropdownMenuItem(
                            value: t.code,
                            child: Text(
                              t.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(
                          () => _selectedProviderTypeFilter = val ?? '',
                        );
                        _loadProviders();
                      },
                    ),
                  ),
                  FilterChip(
                    key: const Key('insurance_filter_msa_only'),
                    label: const Text('MSA-Ready Only'),
                    selected: _msaOnlyFilter,
                    onSelected: (val) {
                      setState(() => _msaOnlyFilter = val);
                      _loadProviders();
                    },
                  ),
                  FilterChip(
                    key: const Key('insurance_filter_fast_coi'),
                    label: const Text('24/7 Fast COI'),
                    selected: _fastCoiOnlyFilter,
                    onSelected: (val) {
                      setState(() => _fastCoiOnlyFilter = val);
                      _loadProviders();
                    },
                  ),
                  if (_hasActiveBrowseFilters)
                    TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Reset Filters'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'FILTER BY COVERAGE LINE',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: PipeBuyerColors.muted,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const Key('coverage_filter_all'),
                    label: const Text('All Coverage Lines'),
                    selected: _selectedCoverageLineFilter.isEmpty,
                    onSelected: (_) {
                      setState(() => _selectedCoverageLineFilter = '');
                      _loadProviders();
                    },
                  ),
                  ...PipeBuyerInsuranceTaxonomy.coverageLines.map(
                    (line) => ChoiceChip(
                      key: Key('coverage_filter_${line.code}'),
                      label: Text(line.shortLabel),
                      selected: _selectedCoverageLineFilter == line.code,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCoverageLineFilter =
                              selected ? line.code : '';
                        });
                        _loadProviders();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_usingShowcaseFallback) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: PipeBuyerColors.industrialBlue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: PipeBuyerColors.industrialBlue.withValues(alpha: .24),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: PipeBuyerColors.industrialBlue,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Featured Commercial & Oilfield Insurance Market Preview — Submit a rate application below to get matched across verified carriers & brokers.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: PipeBuyerColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (_loadingProviders)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 42),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_providerLoadError != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: PipeBuyerColors.danger,
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _providerLoadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loadProviders,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (_providers.isEmpty && !_hasSeenLiveProviders)
          _buildOnboardingCoverageLanesSection(context)
        else if (_providers.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const PipeBuyerCompanyLogoBadge(
                    logoUrl: '',
                    companyName: '',
                    width: 68,
                    height: 54,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No insurance providers match your current filters',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Clear active filters or submit a multi-carrier rate application and our commercial desk will match your company directly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: PipeBuyerColors.muted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _resetFilters,
                        child: const Text('Reset Filters'),
                      ),
                      FilledButton.icon(
                        onPressed: _startMultiCarrierQuote,
                        icon:
                            const Icon(Icons.request_quote_outlined, size: 18),
                        label: const Text('Get Multi-Carrier Quotes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= 900;
              final cardWidth = twoColumn
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _providers
                    .map(
                      (provider) => SizedBox(
                        width: cardWidth,
                        child: _InsuranceProviderCard(
                          provider: provider,
                          onApplyForRates: () =>
                              _startTargetedProviderQuote(provider),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      key: const Key('insurance_search_input'),
      controller: _searchController,
      onSubmitted: (_) => _loadProviders(),
      decoration: InputDecoration(
        hintText:
            'Search carriers, brokers, Permian, WCSB, OCTG cargo, rig equipment...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  _loadProviders();
                },
              ),
      ),
    );
  }

  Widget _buildOnboardingCoverageLanesSection(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredLanes =
        PipeBuyerInsuranceTaxonomy.coverageLines.where((line) {
      if (_selectedCoverageLineFilter.isNotEmpty &&
          line.code != _selectedCoverageLineFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack = '${line.label} ${line.shortLabel} ${line.description}'
            .toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('insurance_onboarding_program_banner'),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 5,
                child: ColoredBox(color: PipeBuyerColors.industrialBlue),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(23, 18, 18, 18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 780;
                    final copyBlock = const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            PipeBuyerVisualBadge(
                              variant: PipeBuyerBadgeVariant.programPreview,
                            ),
                            PipeBuyerVisualBadge(
                              variant: PipeBuyerBadgeVariant.verifiedPro,
                              label: 'VERIFIED CARRIER ONBOARDING',
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Commercial & Oilfield Coverage Lanes — Verified Carrier & Broker Onboarding',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: PipeBuyerColors.ink,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Only NAIC and provincially licensed insurance companies appear once verified. Select a coverage lane below to request quotes, or list your agency and upload your Business Logo.',
                          style: TextStyle(
                            fontSize: 12.6,
                            height: 1.45,
                            color: PipeBuyerColors.slate,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                    final actionsBlock = Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _startMultiCarrierQuote,
                          icon: const Icon(
                            Icons.request_quote_outlined,
                            size: 18,
                          ),
                          label: const Text('Apply for Commercial Rates'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openProviderOnboarding,
                          icon: const Icon(
                            Icons.add_business_outlined,
                            size: 18,
                          ),
                          label: const Text(
                            'List Insurance Company & Upload Logo',
                          ),
                        ),
                        if (_hasActiveBrowseFilters)
                          TextButton.icon(
                            onPressed: _resetFilters,
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 18,
                            ),
                            label: const Text('Reset Filters'),
                          ),
                      ],
                    );

                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          copyBlock,
                          const SizedBox(height: 14),
                          actionsBlock,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: copyBlock),
                        const SizedBox(width: 20),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: actionsBlock,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (filteredLanes.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'No commercial coverage lanes matched that search term.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _resetFilters,
                        child: const Text('Reset Filters'),
                      ),
                      FilledButton.icon(
                        onPressed: _startMultiCarrierQuote,
                        icon: const Icon(
                          Icons.request_quote_outlined,
                          size: 18,
                        ),
                        label: const Text('Submit Custom Rate Application'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= 900;
              final cardWidth = twoColumn
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: List<Widget>.generate(filteredLanes.length, (index) {
                  final line = filteredLanes[index];
                  final providerRole = switch (index % 3) {
                    0 => 'specialty_broker',
                    1 => 'mga',
                    _ => 'carrier',
                  };
                  return SizedBox(
                    width: cardWidth,
                    child: _CoverageProgramLaneCard(
                      line: line,
                      featuredLane: index < 2,
                      providerType: _selectedProviderTypeFilter.isNotEmpty
                          ? _selectedProviderTypeFilter
                          : providerRole,
                      onApplyForLane: () => _startCoverageLaneQuote(line),
                      onListAgency: _openProviderOnboarding,
                    ),
                  );
                }),
              );
            },
          ),
      ],
    );
  }

  Widget _buildApplyForRatesSection(BuildContext context) {
    if (_latestReceipt != null) {
      return _buildRateReceiptCard(context, _latestReceipt!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDistributionBanner(context),
        const SizedBox(height: 14),
        Form(
          key: _rateFormKey,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumn = constraints.maxWidth >= 660;
                  final halfWidth = twoColumn
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _StepHeading(
                        step: '1',
                        title: 'Company & Primary Contact',
                        subtitle:
                            'Enter the legal or operating company requesting commercial insurance quotes.',
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 16,
                        runSpacing: 14,
                        children: [
                          SizedBox(
                            width: halfWidth,
                            child: TextFormField(
                              key: const Key('rate_apply_company_name'),
                              controller: _companyNameController,
                              decoration: const InputDecoration(
                                labelText: 'Company Legal / Operating Name *',
                                hintText: 'e.g. Redwater Tubular & Hauling LLC',
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().length < 2)
                                      ? 'Enter your company name.'
                                      : null,
                            ),
                          ),
                          SizedBox(
                            width: halfWidth,
                            child: TextFormField(
                              key: const Key('rate_apply_contact_name'),
                              controller: _contactNameController,
                              decoration: const InputDecoration(
                                labelText: 'Contact Full Name *',
                                hintText: 'Safety / Operations / Owner Name',
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().length < 2)
                                      ? 'Enter your contact name.'
                                      : null,
                            ),
                          ),
                          SizedBox(
                            width: halfWidth,
                            child: TextFormField(
                              key: const Key('rate_apply_email'),
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Business Email *',
                                hintText: 'ops@yourcompany.com',
                              ),
                              validator: (val) {
                                final trimmed = val?.trim() ?? '';
                                if (!trimmed.contains('@') ||
                                    !trimmed.contains('.')) {
                                  return 'Enter a valid email address.';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(
                            width: halfWidth,
                            child: TextFormField(
                              key: const Key('rate_apply_phone'),
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Business Phone *',
                                hintText: '(432) 555-0194',
                              ),
                              validator: (val) {
                                final digits =
                                    (val ?? '').replaceAll(RegExp(r'\D+'), '');
                                return digits.length < 7
                                    ? 'Enter a valid phone number.'
                                    : null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Divider(),
                      const SizedBox(height: 18),
                      const _StepHeading(
                        step: '2',
                        title: 'Headquarters & Operating Basins',
                        subtitle:
                            'Where your crews, yards, rigs, or trucks operate.',
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 16,
                        runSpacing: 14,
                        children: [
                          SizedBox(
                            width: halfWidth,
                            child: DropdownButtonFormField<String>(
                              key: const Key('rate_apply_country'),
                              initialValue: _rateCountryCode,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Country *',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'US',
                                  child: Text('United States (US)'),
                                ),
                                DropdownMenuItem(
                                  value: 'CA',
                                  child: Text('Canada (CA)'),
                                ),
                                DropdownMenuItem(
                                  value: 'MX',
                                  child: Text('Mexico (MX)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _rateCountryCode = val);
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            width: halfWidth,
                            child: TextFormField(
                              key: const Key('rate_apply_region'),
                              controller: _regionController,
                              decoration: const InputDecoration(
                                labelText: 'State / Province Code *',
                                hintText: 'TX, AB, ND, OK, SK...',
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                      ? 'Enter state or province.'
                                      : null,
                            ),
                          ),
                          SizedBox(
                            width: halfWidth,
                            child: TextFormField(
                              key: const Key('rate_apply_city'),
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'Primary Yard / City',
                                hintText: 'Midland, Nisku, Williston...',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: halfWidth,
                            child: TextFormField(
                              key: const Key('rate_apply_dot_mc'),
                              controller: _dotOrMcController,
                              decoration: const InputDecoration(
                                labelText: 'USDOT / MC / NSC Number (Optional)',
                                hintText: 'e.g. USDOT 3981124',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Operating Energy Basins',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PipeBuyerInsuranceTaxonomy.operatingBasins
                            .map(
                              (basin) => FilterChip(
                                label: Text(basin),
                                selected: _rateOperatingBasins.contains(basin),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _rateOperatingBasins.add(basin);
                                    } else {
                                      _rateOperatingBasins.remove(basin);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 22),
                      const Divider(),
                      const SizedBox(height: 18),
                      const _StepHeading(
                        step: '3',
                        title: 'Commercial Coverage Lines & MSA Endorsements',
                        subtitle:
                            'Select every line and operator MSA endorsement you want priced.',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Coverage Lines Needed *',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PipeBuyerInsuranceTaxonomy.coverageLines
                            .map(
                              (line) => FilterChip(
                                key: Key('rate_line_${line.code}'),
                                label: Text(line.shortLabel),
                                selected:
                                    _rateCoverageLines.contains(line.code),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _rateCoverageLines.add(line.code);
                                    } else {
                                      _rateCoverageLines.remove(line.code);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Operator MSA Endorsements Required',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PipeBuyerInsuranceTaxonomy.msaEndorsements
                            .map(
                              (msa) => FilterChip(
                                key: Key('rate_msa_${msa.code}'),
                                label: Text(msa.label),
                                selected:
                                    _rateMsaRequirements.contains(msa.code),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _rateMsaRequirements.add(msa.code);
                                    } else {
                                      _rateMsaRequirements.remove(msa.code);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 22),
                      const Divider(),
                      const SizedBox(height: 18),
                      const _StepHeading(
                        step: '4',
                        title: 'Fleet, Equipment & Underwriting Snapshot',
                        subtitle:
                            'Helps carriers release accurate indicative commercial rates quickly.',
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 16,
                        runSpacing: 14,
                        children: [
                          SizedBox(
                            width: halfWidth,
                            child: TextFormField(
                              key: const Key('rate_apply_fleet_count'),
                              controller: _fleetCountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Power Units / Fleet Vehicles',
                                hintText: '0 if GL / equipment only',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: halfWidth,
                            child: TextFormField(
                              key: const Key('rate_apply_equipment_value'),
                              controller: _equipmentValueController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText:
                                    'Scheduled Equipment / Rig Value (USD)',
                                hintText: '750000',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: halfWidth,
                            child: DropdownButtonFormField<String>(
                              key: const Key('rate_apply_revenue_band'),
                              initialValue: _annualRevenueBand,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Estimated Annual Gross Revenue',
                              ),
                              items:
                                  PipeBuyerInsuranceTaxonomy.annualRevenueBands
                                      .map(
                                        (band) => DropdownMenuItem<String>(
                                          value: band.code,
                                          child: Text(band.label),
                                        ),
                                      )
                                      .toList(growable: false),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _annualRevenueBand = val);
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            width: halfWidth,
                            child: TextFormField(
                              key: const Key('rate_apply_effective_date'),
                              controller: _effectiveDateController,
                              decoration: InputDecoration(
                                labelText:
                                    'Desired Effective Date (YYYY-MM-DD)',
                                hintText: '2026-11-15',
                                suffixIcon: IconButton(
                                  tooltip: 'Pick date',
                                  onPressed: _pickEffectiveDate,
                                  icon: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('rate_apply_claims'),
                        controller: _claimsSummaryController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '3-Year Loss / Claims Summary (Optional)',
                          hintText:
                              'e.g. Zero reportable losses in past 36 months',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('rate_apply_notes'),
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText:
                              'Operations Description & Operator MSA Notes (Optional)',
                          hintText:
                              'Describe hauling radius, pipe/rig operations, or specific operator certificate requirements...',
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('rate_apply_submit_button'),
                          onPressed: _submittingRateApp
                              ? null
                              : _submitRateApplication,
                          icon: _submittingRateApp
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
                            _submittingRateApp
                                ? 'Submitting Rate Application...'
                                : 'Submit Commercial Rate Application',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionBanner(BuildContext context) {
    final target = _selectedTargetProvider;
    if (target != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PipeBuyerColors.orangeSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: PipeBuyerColors.orange.withValues(alpha: .35),
          ),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PipeBuyerCompanyLogoBadge(
                  logoUrl: target.logoUrl,
                  companyName: target.companyName,
                  width: 54,
                  height: 44,
                  featured: target.featured,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Targeted Provider Quote: ${target.companyName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${target.providerTypeLabel} • ${target.headquartersLabel}',
                        style: const TextStyle(
                          color: PipeBuyerColors.slate,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => setState(() => _selectedTargetProvider = null),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Switch to Multi-Carrier Quotes'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PipeBuyerColors.industrialBlue.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PipeBuyerColors.industrialBlue.withValues(alpha: .25),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.hub_outlined,
            color: PipeBuyerColors.industrialBlue,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multi-Carrier Commercial Rate Matching',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'One application matches your company with verified oilfield carriers, MGAs, and specialty brokers licensed in your operating jurisdictions.',
                  style: TextStyle(
                    color: PipeBuyerColors.slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateReceiptCard(
    BuildContext context,
    PipeBuyerInsuranceRateSubmissionResult receipt,
  ) {
    final targetLabel = receipt.targetProviderName.isNotEmpty
        ? 'Targeted Provider: ${receipt.targetProviderName}'
        : 'Multi-Carrier Commercial Market Distribution';

    return Card(
      key: const Key('rate_application_receipt_card'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.success.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: PipeBuyerColors.success,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Commercial Insurance Rate Application Submitted',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Application ID: ${receipt.applicationId} • Status: ${receipt.status.toUpperCase()}',
                        style: const TextStyle(
                          color: PipeBuyerColors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PipeBuyerColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    targetLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: receipt.coverageLines
                        .map(
                          (code) => Chip(
                            label: Text(
                              PipeBuyerInsuranceTaxonomy.coverageShortLabel(
                                code,
                              ),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _activeTab = InsuranceHubTab.myApplicationsAndCarriers;
                    });
                  },
                  icon:
                      const Icon(Icons.assignment_turned_in_outlined, size: 18),
                  label: const Text('View My Rate Applications'),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => _latestReceipt = null),
                  child: const Text('Submit Another Rate Request'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyApplicationsAndCarriersSection(BuildContext context) {
    final apps = _combinedMyApplications;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Commercial Insurance Rate Applications',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Track underwriting status, matched carriers, and broker quote notes.',
                          style: TextStyle(
                            color: PipeBuyerColors.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (_client.isSignedIn)
                      OutlinedButton.icon(
                        onPressed: _loadingMyApps ? null : _loadMyApplications,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Refresh'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loadingMyApps)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (apps.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _client.isSignedIn
                              ? 'No commercial rate applications submitted yet.'
                              : 'Sign in to sync rate applications across devices — or apply directly right now.',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Request commercial auto fleet, general liability, rig equipment, cargo, or umbrella quotes in minutes.',
                          style: TextStyle(
                            color: PipeBuyerColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _startMultiCarrierQuote,
                          icon: const Icon(Icons.request_quote_outlined,
                              size: 18),
                          label: const Text('Apply for Company Rates'),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: apps
                        .map(
                          (app) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _MyRateApplicationTile(application: app),
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: PipeBuyerColors.ink,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: PipeBuyerColors.orange.withValues(alpha: .35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FOR COMMERCIAL CARRIERS, MGAs & OILFIELD SPECIALTY BROKERS',
                style: TextStyle(
                  color: PipeBuyerColors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'List Your Insurance Company on Pipe Buyer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Publish your verified underwriting profile, highlight licensed states & provinces, A.M. Best security rating, MSA compliance, and receive structured commercial rate applications from Pipe Buyer companies.',
                style: TextStyle(
                  color: Color(0xFFD0D8E4),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('hub_open_provider_apply_button'),
                onPressed: _openProviderOnboarding,
                icon: const Icon(Icons.domain_add_outlined, size: 18),
                label: const Text('Apply to List Your Insurance Company'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComplianceFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PipeBuyerColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.gavel_rounded,
                size: 17,
                color: PipeBuyerColors.slate,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Commercial Insurance Marketplace Disclosure',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Pipe Buyer connects industrial and oilfield businesses with licensed insurance carriers, MGAs, and specialty producers. Policy terms, underwriting eligibility, limits, endorsements, and binding authority are governed solely by the licensed insurance provider.',
            style: TextStyle(
              color: PipeBuyerColors.muted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () => _openPublicPolicy(
                  MarketplaceDeepLinks.privacyPath,
                  MarketplacePublicInformationKind.privacy,
                ),
                child: const Text('Privacy Policy'),
              ),
              TextButton(
                onPressed: () => _openPublicPolicy(
                  MarketplaceDeepLinks.termsPath,
                  MarketplacePublicInformationKind.terms,
                ),
                child: const Text('Terms of Service'),
              ),
              TextButton(
                onPressed: () => _openPublicPolicy(
                  MarketplaceDeepLinks.supportPath,
                  MarketplacePublicInformationKind.support,
                ),
                child: const Text('Help & Support'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubTabCard extends StatelessWidget {
  const _HubTabCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PipeBuyerColors.orangeSoft : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? PipeBuyerColors.orange : PipeBuyerColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? PipeBuyerColors.orange
                      : PipeBuyerColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: selected ? Colors.white : PipeBuyerColors.slate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? PipeBuyerColors.ink
                            : PipeBuyerColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: PipeBuyerColors.muted,
                        fontWeight: FontWeight.w600,
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
}

class _InsuranceProviderCard extends StatelessWidget {
  const _InsuranceProviderCard({
    required this.provider,
    required this.onApplyForRates,
  });

  final InsuranceProviderListing provider;
  final VoidCallback onApplyForRates;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('provider_card_${provider.providerId}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: provider.featured
              ? const Color(0xFFCBD5E1)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: provider.featured
                    ? const <Color>[
                        PipeBuyerColors.orange,
                        Color(0xFFFF9A3D),
                      ]
                    : const <Color>[
                        PipeBuyerColors.ink,
                        PipeBuyerColors.industrialBlue,
                      ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (provider.isSampleShowcase)
                          const PipeBuyerVisualBadge(
                            variant: PipeBuyerBadgeVariant.programPreview,
                            compact: true,
                          ),
                        PipeBuyerVisualBadge.forInsuranceProviderType(
                          provider.providerType,
                          compact: true,
                        ),
                        if (provider.featured)
                          const PipeBuyerVisualBadge(
                            variant: PipeBuyerBadgeVariant.featured,
                            compact: true,
                          ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (provider.fastCoi24x7)
                          const PipeBuyerVisualBadge(
                            variant: PipeBuyerBadgeVariant.fastCoi24x7,
                            compact: true,
                          ),
                        if (provider.msaCompliant)
                          const PipeBuyerVisualBadge(
                            variant: PipeBuyerBadgeVariant.msaReady,
                            compact: true,
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PipeBuyerCompanyLogoBadge(
                      key: Key('provider_logo_${provider.providerId}'),
                      logoUrl: provider.logoUrl,
                      companyName: provider.companyName,
                      width: 84,
                      height: 66,
                      featured: provider.featured,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.companyName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: PipeBuyerColors.ink,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${provider.providerTypeLabel} • HQ: ${provider.headquartersLabel}',
                            style: const TextStyle(
                              color: PipeBuyerColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (provider.summary.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              provider.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: PipeBuyerColors.slate,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (provider.amBestRating.isNotEmpty)
                      _MetricChip(
                        icon: Icons.workspace_premium_outlined,
                        label: 'A.M. Best: ${provider.amBestRating}',
                      ),
                    if (provider.maxLimitUsd > 0)
                      _MetricChip(
                        icon: Icons.layers_outlined,
                        label: 'Limits up to ${provider.formattedMaxLimit}',
                      ),
                    if (provider.licensedRegions.isNotEmpty)
                      _MetricChip(
                        icon: Icons.map_outlined,
                        label:
                            'Licensed: ${provider.licensedRegions.take(6).join(', ')}${provider.licensedRegions.length > 6 ? '+' : ''}',
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: provider.coverageLines
                      .take(5)
                      .map(
                        (code) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.5,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            PipeBuyerInsuranceTaxonomy.coverageShortLabel(code),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: Key('apply_rates_${provider.providerId}'),
                    onPressed: onApplyForRates,
                    icon: const Icon(Icons.request_quote_outlined, size: 18),
                    label: const Text('Apply for Rates'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverageProgramLaneCard extends StatelessWidget {
  const _CoverageProgramLaneCard({
    required this.line,
    required this.featuredLane,
    required this.providerType,
    required this.onApplyForLane,
    required this.onListAgency,
  });

  final InsuranceCoverageLine line;
  final bool featuredLane;
  final String providerType;
  final VoidCallback onApplyForLane;
  final VoidCallback onListAgency;

  static List<String> _highlightsForLane(String code) {
    return switch (code) {
      'commercial_auto_fleet' => const <String>[
          'MCS-90 & DOT/NSC Filings',
          'Crew Pickups & Hotshots',
          'Vac & Heavy Haul Physical Damage',
        ],
      'oilfield_general_liability' => const <String>[
          'Occurrence Lease-Site CGL',
          'Blanket Additional Insured',
          'Waiver of Subrogation',
        ],
      'rig_equipment_inland_marine' => const <String>[
          'Drilling & Workover Rigs',
          'Blanket Contractors Iron',
          'OCTG & Yard Pipe Stock',
        ],
      'motor_truck_cargo_hazmat' => const <String>[
          'Broad-Form OCTG Cargo',
          'Rig Move & Loading Transit',
          'Spill & Hazmat Cleanup',
        ],
      'pollution_environmental' => const <String>[
          'Contractors Pollution (CPL)',
          'Sudden & Accidental Time-Element',
          'Site Remediation',
        ],
      'umbrella_excess_liability' => const <String>[
          '\$1M–\$25M+ Excess Towers',
          'Follow-Form MSA Schedules',
          'Auto, CGL & Employers Excess',
        ],
      'workers_comp_crew' => const <String>[
          'Statutory WC & Stop-Gap',
          'WCB & Multi-State Crew',
          'USL&H Extensions',
        ],
      _ => const <String>[
          'Fabrication Shops & Pipe Yards',
          'Modular Skids & Crew Camps',
          'Business Interruption',
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final highlights = _highlightsForLane(line.code);

    return Container(
      key: Key('coverage_lane_${line.code}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              featuredLane ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: featuredLane
                    ? const <Color>[PipeBuyerColors.orange, Color(0xFFFF9A3D)]
                    : const <Color>[
                        PipeBuyerColors.industrialBlue,
                        Color(0xFF3B82F6),
                      ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          PipeBuyerVisualBadge.forInsuranceProviderType(
                            providerType,
                            compact: true,
                          ),
                          if (featuredLane)
                            const PipeBuyerVisualBadge(
                              variant: PipeBuyerBadgeVariant.featured,
                              compact: true,
                            ),
                        ],
                      ),
                      const Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          PipeBuyerVisualBadge(
                            variant: PipeBuyerBadgeVariant.fastCoi24x7,
                            compact: true,
                          ),
                          PipeBuyerVisualBadge(
                            variant: PipeBuyerBadgeVariant.msaReady,
                            compact: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PipeBuyerCompanyLogoBadge(
                      key: Key('lane_placeholder_${line.code}'),
                      logoUrl: '',
                      companyName: line.label,
                      width: 84,
                      height: 66,
                      featured: featuredLane,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.label,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              color: PipeBuyerColors.ink,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'US & Canada Energy Markets  •  Carrier & Broker Slot Open',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: PipeBuyerColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            line.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.42,
                              color: PipeBuyerColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: highlights
                      .map(
                        (spec) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.5,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            spec,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        key: Key('apply_lane_${line.code}'),
                        onPressed: onApplyForLane,
                        icon: const Icon(
                          Icons.request_quote_outlined,
                          size: 17,
                        ),
                        label: const Text('Apply for Rates'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onListAgency,
                        icon: const Icon(Icons.upload_file_rounded, size: 17),
                        label: const Text('List Your Company'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PipeBuyerColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: PipeBuyerColors.slate),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PipeBuyerColors.orangeSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: PipeBuyerColors.orangePressed,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyRateApplicationTile extends StatelessWidget {
  const _MyRateApplicationTile({required this.application});

  final InsuranceRateApplicationSummary application;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (application.status.toLowerCase()) {
      'quoted' || 'bound' => PipeBuyerColors.success,
      'matching' => PipeBuyerColors.industrialBlue,
      'closed' => PipeBuyerColors.muted,
      _ => PipeBuyerColors.orangePressed,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PipeBuyerColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
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
                application.companyName,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              _MiniTag(
                label: application.statusLabel,
                backgroundColor: statusColor.withValues(alpha: .14),
                foregroundColor: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ref: ${application.applicationId} • ${application.isTargeted && application.targetProviderName.isNotEmpty ? 'Targeted: ${application.targetProviderName}' : 'Multi-Carrier Matching'}',
            style: const TextStyle(
              fontSize: 11.5,
              color: PipeBuyerColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: application.coverageLines
                .map(
                  (line) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      PipeBuyerInsuranceTaxonomy.coverageShortLabel(line),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          if (application.brokerResponseNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Underwriting Update: ${application.brokerResponseNotes}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: PipeBuyerColors.ink,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
