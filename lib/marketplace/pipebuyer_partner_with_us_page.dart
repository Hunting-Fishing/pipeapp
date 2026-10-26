import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_admin_access.dart';
import 'marketplace_navigation.dart';
import 'pipebuyer_business_logo_uploader.dart';
import 'pipebuyer_business_logo_widgets.dart';
import 'pipebuyer_partner_client.dart';
import 'pipebuyer_partner_taxonomy.dart';
import 'pipebuyer_site_footer.dart';

enum PartnerPageSection {
  overview,
  showcase,
  apply,
}

class PipeBuyerPartnerWithUsPage extends StatefulWidget {
  const PipeBuyerPartnerWithUsPage({
    super.key,
    this.initialSection = PartnerPageSection.overview,
    this.initialCategoryFilter = '',
    this.client,
    this.logoUploader,
    this.includeDefaultShowcases = true,
  });

  final PartnerPageSection initialSection;
  final String initialCategoryFilter;
  final PipeBuyerPartnerClient? client;
  final PipeBuyerBusinessLogoUploader? logoUploader;
  final bool includeDefaultShowcases;

  @override
  State<PipeBuyerPartnerWithUsPage> createState() =>
      _PipeBuyerPartnerWithUsPageState();
}

class _PipeBuyerPartnerWithUsPageState
    extends State<PipeBuyerPartnerWithUsPage> {
  late final PipeBuyerPartnerClient _client;
  final _scrollController = ScrollController();
  final _showcaseSectionKey = GlobalKey();
  final _applySectionKey = GlobalKey();
  final _formKey = GlobalKey<FormState>();

  final _searchController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _headlineController = TextEditingController();
  final _dealOfferController = TextEditingController();
  final _productSummaryController = TextEditingController();
  final _budgetController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactTitleController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _notesController = TextEditingController();

  late String _showcaseCategoryFilter;
  String _selectedBrandCategory = 'oem_fleet_crew_trucks';
  String _selectedCommercialModel = 'sponsored_showcase';
  String _logoUrl = '';
  final Set<String> _selectedProgramTypes = <String>{
    'promote_brand',
    'showcase_sell_products',
  };
  final Set<String> _selectedTargetRegions = <String>{
    'North America',
    'Permian Basin',
    'WCSB (Alberta / SK / BC)',
  };

  List<PartnerShowcaseDeal> _liveShowcases = const <PartnerShowcaseDeal>[];
  bool _loadingShowcases = true;
  bool _isAdmin = false;
  bool _submittingInquiry = false;
  String? _submittedInquiryId;
  String? _submittedCompanyName;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PipeBuyerPartnerClient();
    _showcaseCategoryFilter = widget.initialCategoryFilter;
    _prefillSignedInContact();
    _checkAdmin();
    _loadShowcases();

    if (widget.initialSection != PartnerPageSection.overview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSection(widget.initialSection);
      });
    }
  }

  void _prefillSignedInContact() {
    try {
      final email = _client.currentUserEmail?.trim() ?? '';
      final name = _client.currentUserDisplayName?.trim() ?? '';
      if (email.isNotEmpty) _emailController.text = email;
      if (name.isNotEmpty) _contactNameController.text = name;
    } catch (_) {
      // Safe no-op in isolated widget test environments without Firebase init.
    }
  }

  Future<void> _checkAdmin() async {
    try {
      final allowed = await marketplaceAdministratorAccess();
      if (mounted && allowed) {
        setState(() => _isAdmin = true);
      }
    } catch (_) {}
  }

  Future<void> _loadShowcases() async {
    setState(() => _loadingShowcases = true);
    try {
      final items = await _client.listShowcaseDeals();
      if (!mounted) return;
      setState(() {
        _liveShowcases = items;
        _loadingShowcases = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingShowcases = false);
    }
  }

  void _scrollToSection(PartnerPageSection section) {
    final targetContext = switch (section) {
      PartnerPageSection.showcase => _showcaseSectionKey.currentContext,
      PartnerPageSection.apply => _applySectionKey.currentContext,
      PartnerPageSection.overview => null,
    };
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _companyNameController.dispose();
    _headlineController.dispose();
    _dealOfferController.dispose();
    _productSummaryController.dispose();
    _budgetController.dispose();
    _contactNameController.dispose();
    _contactTitleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<PartnerShowcaseDeal> get _effectiveShowcases {
    final mergedById = <String, PartnerShowcaseDeal>{};
    for (final item in _liveShowcases) {
      if (item.active) mergedById[item.showcaseId] = item;
    }
    if (widget.includeDefaultShowcases) {
      for (final fallback in PipeBuyerPartnerTaxonomy.defaultShowcaseDeals) {
        mergedById.putIfAbsent(fallback.showcaseId, () => fallback);
      }
    }

    final query = _searchController.text.trim().toLowerCase();
    final filtered = mergedById.values.where((deal) {
      if (_showcaseCategoryFilter.isNotEmpty &&
          deal.brandCategory != _showcaseCategoryFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack = <String>[
          deal.partnerName,
          deal.headline,
          deal.summary,
          deal.offerBadge,
          deal.discountDetails,
          ...deal.productHighlights,
          ...deal.targetRegions,
        ].join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (a.featured != b.featured) return a.featured ? -1 : 1;
      if (a.priorityRank != b.priorityRank) {
        return a.priorityRank.compareTo(b.priorityRank);
      }
      return a.partnerName.compareTo(b.partnerName);
    });
    return filtered;
  }

  Future<void> _submitInquiry() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProgramTypes.isEmpty) {
      PipeFeedback.show(
        context,
        message: 'Select at least one partnership or advertising goal.',
        tone: PipeStatusTone.warning,
      );
      return;
    }

    int? parsedBudget;
    final rawBudget =
        _budgetController.text.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (rawBudget.isNotEmpty) {
      parsedBudget = int.tryParse(rawBudget);
    }

    setState(() => _submittingInquiry = true);
    try {
      final result = await _client.submitPartnerInquiry(
        companyName: _companyNameController.text.trim(),
        brandCategory: _selectedBrandCategory,
        programTypes: _selectedProgramTypes.toList(growable: false),
        commercialModel: _selectedCommercialModel,
        headline: _headlineController.text.trim(),
        productSummary: _productSummaryController.text.trim(),
        dealOrDiscountOffer: _dealOfferController.text.trim(),
        targetRegions: _selectedTargetRegions.isEmpty
            ? const <String>['North America']
            : _selectedTargetRegions.toList(growable: false),
        estimatedMonthlyBudgetUsd: parsedBudget,
        contactName: _contactNameController.text.trim(),
        contactTitle: _contactTitleController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        website: _websiteController.text.trim(),
        logoUrl: _logoUrl.trim(),
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _submittingInquiry = false;
        _submittedInquiryId = '${result['inquiryId'] ?? 'PB-PARTNER'}';
        _submittedCompanyName = _companyNameController.text.trim();
      });
      PipeFeedback.show(
        context,
        message:
            'Partner inquiry submitted. Our commercial partnerships team will follow up.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submittingInquiry = false);
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  Future<void> _openDealInterestDialog(PartnerShowcaseDeal deal) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _PartnerDealInterestDialog(
        deal: deal,
        client: _client,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showcases = _effectiveShowcases;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner With Us'),
        actions: [
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    MarketplaceNavigation.openPartnerAdmin(context),
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                label: const Text('Partner Admin'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PartnerHeroBanner(
                    onApplyTap: () =>
                        _scrollToSection(PartnerPageSection.apply),
                    onShowcaseTap: () =>
                        _scrollToSection(PartnerPageSection.showcase),
                  ),
                  const SizedBox(height: 20),
                  _PartnershipPillarsSection(
                    onSelectPillar: (code) {
                      setState(() => _selectedProgramTypes.add(code));
                      _scrollToSection(PartnerPageSection.apply);
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(
                    key: _showcaseSectionKey,
                    child: _PartnerShowcaseSection(
                      deals: showcases,
                      loading: _loadingShowcases,
                      selectedCategory: _showcaseCategoryFilter,
                      searchController: _searchController,
                      onCategorySelected: (code) =>
                          setState(() => _showcaseCategoryFilter = code),
                      onSearchChanged: (_) => setState(() {}),
                      onInquireDeal: _openDealInterestDialog,
                      onBecomePartner: () =>
                          _scrollToSection(PartnerPageSection.apply),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    key: _applySectionKey,
                    child: _submittedInquiryId != null
                        ? _PartnerSubmissionConfirmationCard(
                            inquiryId: _submittedInquiryId!,
                            companyName: _submittedCompanyName ?? 'Your brand',
                            onSubmitAnother: () {
                              setState(() {
                                _submittedInquiryId = null;
                                _headlineController.clear();
                                _dealOfferController.clear();
                                _productSummaryController.clear();
                                _notesController.clear();
                              });
                            },
                          )
                        : _buildPartnerApplicationForm(context),
                  ),
                  const SizedBox(height: 28),
                  PipeBuyerSiteFooter(
                    currentSurface: PipeBuyerFooterSurface.partner,
                    onOpenPartnerWithUs: () =>
                        _scrollToSection(PartnerPageSection.apply),
                    onOpenPartnerShowcase: () =>
                        _scrollToSection(PartnerPageSection.showcase),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerApplicationForm(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PipeBuyerColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.orangeSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.handshake_outlined,
                    color: PipeBuyerColors.orangePressed,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BRAND, OEM & ADVERTISING INTAKE',
                        style: TextStyle(
                          color: PipeBuyerColors.orange,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Apply to Partner, Advertise, or Showcase Products',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: PipeBuyerColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tell us how your company wants to collaborate with Pipe Buyer—from OEM commercial crew truck showcases (such as Ford fleet & upfit programs) to direct product sales, category advertising, and oilfield member discounts.',
              style: TextStyle(
                color: PipeBuyerColors.slate,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const Divider(height: 30),
            const _FormStepTitle(
              step: '1',
              title: 'Company & Partnership Goals',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCol = constraints.maxWidth >= 680;
                final companyField = TextFormField(
                  key: const Key('partner-company-name-input'),
                  controller: _companyNameController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Company / Brand Name *',
                    hintText:
                        'e.g., Ford Pro Commercial Fleet / Regional Dealer Group',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Enter your company or brand name.';
                    }
                    return null;
                  },
                );
                final categoryDropdown = DropdownButtonFormField<String>(
                  initialValue: _selectedBrandCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Brand / Product Category *',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: PipeBuyerPartnerTaxonomy.brandCategories
                      .map(
                        (cat) => DropdownMenuItem<String>(
                          value: cat.code,
                          child: Text(
                            cat.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedBrandCategory = value);
                    }
                  },
                );
                if (twoCol) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: companyField),
                      const SizedBox(width: 14),
                      Expanded(child: categoryDropdown),
                    ],
                  );
                }
                return Column(
                  children: [
                    companyField,
                    const SizedBox(height: 12),
                    categoryDropdown,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            PipeBuyerBusinessLogoField(
              fieldKeyPrefix: 'partner_brand_logo',
              logoUrl: _logoUrl,
              companyName: _companyNameController.text,
              purpose: 'partner_brand',
              uploader: widget.logoUploader,
              title: 'Company / Brand Logo (Optional — Recommended)',
              subtitle:
                  'Displayed on your Partner Showcase & Oilfield Deal card • PNG, JPG, or WebP (max 2 MB)',
              onChanged: (url) => setState(() => _logoUrl = url),
            ),
            const SizedBox(height: 14),
            const Text(
              'How would you like to partner with Pipe Buyer? *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: PipeBuyerColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PipeBuyerPartnerTaxonomy.programPillars.map((pillar) {
                final selected = _selectedProgramTypes.contains(pillar.code);
                return FilterChip(
                  selected: selected,
                  label: Text('${pillar.title} (${pillar.tagline})'),
                  selectedColor: PipeBuyerColors.orangeSoft,
                  checkmarkColor: PipeBuyerColors.orangePressed,
                  onSelected: (enabled) {
                    setState(() {
                      if (enabled) {
                        _selectedProgramTypes.add(pillar.code);
                      } else {
                        _selectedProgramTypes.remove(pillar.code);
                      }
                    });
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedCommercialModel,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Preferred Commercial / Placement Model *',
                prefixIcon: Icon(Icons.workspace_premium_outlined),
              ),
              items: PipeBuyerPartnerTaxonomy.commercialModels
                  .map(
                    (model) => DropdownMenuItem<String>(
                      value: model.code,
                      child: Text(
                        model.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCommercialModel = value);
                }
              },
            ),
            const SizedBox(height: 22),
            const _FormStepTitle(
              step: '2',
              title:
                  'Products, Crew Truck / Equipment Showcase & Oilfield Deals',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('partner-headline-input'),
              controller: _headlineController,
              decoration: const InputDecoration(
                labelText: 'Campaign or Product Showcase Headline *',
                hintText:
                    'e.g., 2026 Commercial Crew Trucks & Oilfield Fleet Rebate Program',
                prefixIcon: Icon(Icons.campaign_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 4) {
                  return 'Enter a short headline for your showcase or campaign.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCol = constraints.maxWidth >= 680;
                final dealField = TextFormField(
                  key: const Key('partner-deal-offer-input'),
                  controller: _dealOfferController,
                  decoration: const InputDecoration(
                    labelText:
                        'Oilfield Deal, Fleet Rebate, or Member Discount (Optional)',
                    hintText:
                        'e.g., Up to \$3,500 upfit allowance or 15% crew discount',
                    prefixIcon: Icon(Icons.local_offer_outlined),
                  ),
                );
                final budgetField = TextFormField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText:
                        'Estimated Monthly Ad / Campaign Budget USD (Optional)',
                    hintText: 'e.g., 5000',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                );
                if (twoCol) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: dealField),
                      const SizedBox(width: 14),
                      Expanded(flex: 2, child: budgetField),
                    ],
                  );
                }
                return Column(
                  children: [
                    dealField,
                    const SizedBox(height: 12),
                    budgetField,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('partner-summary-input'),
              controller: _productSummaryController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText:
                    'Products, Fleet Models, or Promotions to Showcase *',
                hintText:
                    'Describe the vehicles, equipment, tools, or oilfield deals you want to promote, advertise, or sell on Pipe Buyer...',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().length < 10) {
                  return 'Please provide at least 10 characters describing what you want to showcase.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'Target Energy Basins & Markets',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: PipeBuyerColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  PipeBuyerPartnerTaxonomy.targetRegionOptions.map((region) {
                final selected = _selectedTargetRegions.contains(region);
                return FilterChip(
                  selected: selected,
                  label: Text(region),
                  selectedColor: PipeBuyerColors.orangeSoft,
                  checkmarkColor: PipeBuyerColors.orangePressed,
                  onSelected: (enabled) {
                    setState(() {
                      if (enabled) {
                        _selectedTargetRegions.add(region);
                      } else {
                        _selectedTargetRegions.remove(region);
                      }
                    });
                  },
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 22),
            const _FormStepTitle(
              step: '3',
              title: 'Corporate Contact Information',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoCol = constraints.maxWidth >= 680;
                final nameField = TextFormField(
                  key: const Key('partner-contact-name-input'),
                  controller: _contactNameController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Full Name *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Enter a contact name.';
                    }
                    return null;
                  },
                );
                final titleField = TextFormField(
                  controller: _contactTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Role / Title',
                    hintText: 'e.g., Fleet Partnerships Manager / VP Marketing',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                );
                final emailField = TextFormField(
                  key: const Key('partner-email-input'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Corporate Email *',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Enter a valid corporate email address.';
                    }
                    return null;
                  },
                );
                final phoneField = TextFormField(
                  key: const Key('partner-phone-input'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Direct Phone *',
                    hintText: '+1 (800) 555-0199',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 7) {
                      return 'Enter a valid phone number.';
                    }
                    return null;
                  },
                );
                if (twoCol) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: nameField),
                          const SizedBox(width: 14),
                          Expanded(child: titleField),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: emailField),
                          const SizedBox(width: 14),
                          Expanded(child: phoneField),
                        ],
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    nameField,
                    const SizedBox(height: 12),
                    titleField,
                    const SizedBox(height: 12),
                    emailField,
                    const SizedBox(height: 12),
                    phoneField,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _websiteController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Company Website or Fleet Program URL',
                hintText: 'https://www.yourcompany.com/commercial-fleet',
                prefixIcon: Icon(Icons.language_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText:
                    'Timeline, Dealer Network, or Additional Notes (Optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('partner-submit-inquiry-button'),
                onPressed: _submittingInquiry ? null : _submitInquiry,
                style: FilledButton.styleFrom(
                  backgroundColor: PipeBuyerColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 15,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _submittingInquiry
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 19),
                label: Text(
                  _submittingInquiry
                      ? 'Submitting Proposal...'
                      : 'Submit Partnership Proposal',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerHeroBanner extends StatelessWidget {
  const _PartnerHeroBanner({
    required this.onApplyTap,
    required this.onShowcaseTap,
  });

  final VoidCallback onApplyTap;
  final VoidCallback onShowcaseTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PipeBuyerColors.ink,
            PipeBuyerColors.charcoal,
            PipeBuyerColors.graphite,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: PipeBuyerColors.orange.withValues(alpha: 0.42),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PipeBuyerColors.orange,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'PIPE BUYER COMMERCIAL PARTNERSHIPS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'OEM FLEETS • BRAND ADVERTISING • DIRECT PRODUCT SALES • OILFIELD DEALS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Partner With Pipe Buyer to Reach Oilfield & Industrial Buyers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.12,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: const Text(
              'Promote your brand, advertise commercial crew trucks and heavy equipment, showcase and sell products directly on our site, or launch exclusive oilfield fleet rebates and discounts for operators across North America and global basins.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14.5,
                height: 1.48,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onApplyTap,
                style: FilledButton.styleFrom(
                  backgroundColor: PipeBuyerColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(Icons.handshake_outlined, size: 19),
                label: const Text('Start Partnership Inquiry'),
              ),
              OutlinedButton.icon(
                onPressed: onShowcaseTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(Icons.local_offer_outlined, size: 18),
                label: const Text('Browse Partner Showcase & Deals'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartnershipPillarsSection extends StatelessWidget {
  const _PartnershipPillarsSection({required this.onSelectPillar});

  final ValueChanged<String> onSelectPillar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1040
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        const spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: PipeBuyerPartnerTaxonomy.programPillars.map((pillar) {
            return SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: PipeBuyerColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: PipeBuyerColors.orangeSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            pillar.icon,
                            color: PipeBuyerColors.orangePressed,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pillar.tagline.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PipeBuyerColors.orangePressed,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      pillar.title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: PipeBuyerColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pillar.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: PipeBuyerColors.slate,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final example in pillar.examples)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(
                                Icons.check_circle_outline_rounded,
                                size: 14,
                                color: PipeBuyerColors.success,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                example,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  height: 1.32,
                                  color: PipeBuyerColors.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => onSelectPillar(pillar.code),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Select Program'),
                    ),
                  ],
                ),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _PartnerShowcaseSection extends StatelessWidget {
  const _PartnerShowcaseSection({
    required this.deals,
    required this.loading,
    required this.selectedCategory,
    required this.searchController,
    required this.onCategorySelected,
    required this.onSearchChanged,
    required this.onInquireDeal,
    required this.onBecomePartner,
  });

  final List<PartnerShowcaseDeal> deals;
  final bool loading;
  final String selectedCategory;
  final TextEditingController searchController;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<PartnerShowcaseDeal> onInquireDeal;
  final VoidCallback onBecomePartner;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PipeBuyerColors.line),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FEATURED SHOWCASE & OILFIELD DEALS',
                    style: TextStyle(
                      color: PipeBuyerColors.industrialBlue,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Partner Fleet Programs, Product Showcases & Crew Discounts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: PipeBuyerColors.ink,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: onBecomePartner,
                icon: const Icon(Icons.add_business_outlined, size: 18),
                label: const Text('Showcase Your Brand Here'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText:
                  'Search crew trucks, fleet rebates, FR gear, modular skids, fuel deals...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All Categories'),
                selected: selectedCategory.isEmpty,
                onSelected: (_) => onCategorySelected(''),
              ),
              for (final cat in PipeBuyerPartnerTaxonomy.brandCategories)
                ChoiceChip(
                  label: Text(cat.shortLabel),
                  selected: selectedCategory == cat.code,
                  onSelected: (_) => onCategorySelected(
                    selectedCategory == cat.code ? '' : cat.code,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (loading && deals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (deals.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: PipeBuyerColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 40,
                    color: PipeBuyerColors.muted,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No partner showcases matched your filter.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      searchController.clear();
                      onCategorySelected('');
                    },
                    child: const Text('Reset Showcase Filters'),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 820 ? 2 : 1;
                const spacing = 14.0;
                final width =
                    (constraints.maxWidth - (spacing * (columns - 1))) /
                        columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: deals
                      .map(
                        (deal) => SizedBox(
                          width: width,
                          child: _PartnerShowcaseCard(
                            deal: deal,
                            onInquire: () => onInquireDeal(deal),
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PartnerShowcaseCard extends StatelessWidget {
  const _PartnerShowcaseCard({
    required this.deal,
    required this.onInquire,
  });

  final PartnerShowcaseDeal deal;
  final VoidCallback onInquire;

  @override
  Widget build(BuildContext context) {
    final category =
        PipeBuyerPartnerTaxonomy.categoryByCode(deal.brandCategory);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: deal.featured ? const Color(0xFFFFFBF7) : PipeBuyerColors.field,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: deal.featured
              ? PipeBuyerColors.orange.withValues(alpha: 0.48)
              : PipeBuyerColors.line,
          width: deal.featured ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (deal.isProgramPreview)
                const PipeBuyerVisualBadge(
                  variant: PipeBuyerBadgeVariant.programPreview,
                ),
              if (deal.featured)
                const PipeBuyerVisualBadge(
                  variant: PipeBuyerBadgeVariant.featured,
                ),
              PipeBuyerVisualBadge(
                variant: PipeBuyerBadgeVariant.verifiedPro,
                label: deal.offerBadge.toUpperCase(),
                customIcon: category?.icon ?? Icons.storefront_outlined,
              ),
              if (category != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: PipeBuyerColors.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        category.icon,
                        size: 13,
                        color: PipeBuyerColors.slate,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        category.shortLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PipeBuyerColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PipeBuyerCompanyLogoBadge(
                logoUrl: deal.logoUrl,
                companyName: deal.partnerName,
                size: 46,
                featured: deal.featured,
                fallbackIcon: category?.icon ?? Icons.storefront_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deal.partnerName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: PipeBuyerColors.muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      deal.headline,
                      style: const TextStyle(
                        fontSize: 16.5,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                        color: PipeBuyerColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (deal.discountDetails.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: PipeBuyerColors.success.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: PipeBuyerColors.success.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_offer_rounded,
                    size: 16,
                    color: PipeBuyerColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      deal.discountDetails,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: PipeBuyerColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            deal.summary,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.42,
              color: PipeBuyerColors.slate,
            ),
          ),
          if (deal.productHighlights.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: deal.productHighlights
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PipeBuyerColors.line),
                      ),
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PipeBuyerColors.ink,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.public_rounded,
                    size: 14,
                    color: PipeBuyerColors.muted,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      deal.targetRegions.take(3).join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: PipeBuyerColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (deal.ctaUrl.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        final uri = Uri.tryParse(deal.ctaUrl);
                        if (uri != null) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: const Text('Partner Site'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: onInquire,
                    icon: const Icon(Icons.request_quote_outlined, size: 16),
                    label: Text(deal.ctaLabel),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormStepTitle extends StatelessWidget {
  const _FormStepTitle({required this.step, required this.title});

  final String step;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PipeBuyerColors.ink,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              color: PipeBuyerColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _PartnerSubmissionConfirmationCard extends StatelessWidget {
  const _PartnerSubmissionConfirmationCard({
    required this.inquiryId,
    required this.companyName,
    required this.onSubmitAnother,
  });

  final String inquiryId;
  final String companyName;
  final VoidCallback onSubmitAnother;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('partner-submission-confirmation'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: PipeBuyerColors.success.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: PipeBuyerColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: PipeBuyerColors.success,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Partnership Proposal Received',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: PipeBuyerColors.ink,
                      ),
                    ),
                    Text(
                      'Reference ID: $inquiryId • $companyName',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: PipeBuyerColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Thank you for reaching out to Pipe Buyer. Our commercial partnerships and merchandising team will review your brand showcase, advertising, or oilfield deal proposal and connect with you directly.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: PipeBuyerColors.slate,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onSubmitAnother,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Submit Another Campaign / Product Line'),
          ),
        ],
      ),
    );
  }
}

class _PartnerDealInterestDialog extends StatefulWidget {
  const _PartnerDealInterestDialog({
    required this.deal,
    required this.client,
  });

  final PartnerShowcaseDeal deal;
  final PipeBuyerPartnerClient client;

  @override
  State<_PartnerDealInterestDialog> createState() =>
      _PartnerDealInterestDialogState();
}

class _PartnerDealInterestDialogState
    extends State<_PartnerDealInterestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _quantityController = TextEditingController();
  final _regionController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    try {
      _emailController.text = widget.client.currentUserEmail ?? '';
      _contactController.text = widget.client.currentUserDisplayName ?? '';
    } catch (_) {}
  }

  @override
  void dispose() {
    _companyController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _quantityController.dispose();
    _regionController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.client.submitDealInterest(
        showcaseId: widget.deal.showcaseId,
        partnerName: widget.deal.partnerName,
        companyName: _companyController.text.trim(),
        contactName: _contactController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        fleetOrQuantityNeed: _quantityController.text.trim(),
        region: _regionController.text.trim(),
        message: _messageController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      PipeFeedback.show(
        context,
        message: 'Inquiry sent for ${widget.deal.partnerName}.',
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
    return AlertDialog(
      title: Text(widget.deal.ctaLabel),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.deal.headline,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: PipeBuyerColors.slate,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _companyController,
                  decoration: const InputDecoration(
                    labelText: 'Your Company Name *',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Name *',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Work Email *'),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Valid email required'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone *'),
                  validator: (v) =>
                      ((v ?? '').replaceAll(RegExp(r'\D'), '').length < 7)
                          ? 'Valid phone required'
                          : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Fleet Size / Units Needed',
                    hintText: 'e.g., 4 Crew Trucks or 25 Crew Outfits',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _regionController,
                  decoration: const InputDecoration(
                    labelText: 'Basin / Operating Location',
                    hintText: 'e.g., Midland, TX or Nisku, AB',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _messageController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Questions or Specs Needed',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Sending...' : 'Send Fleet / Deal Request'),
        ),
      ],
    );
  }
}
