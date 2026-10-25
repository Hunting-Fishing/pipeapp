import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_auth_page.dart';
import 'pipebuyer_yellow_pages_client.dart';
import 'pipebuyer_yellow_pages_taxonomy.dart';

class PipeBuyerListServicesPage extends StatefulWidget {
  const PipeBuyerListServicesPage({
    super.key,
    this.claimedCompanyId,
    this.initialCompanyName = '',
    this.initialCity = '',
    this.initialCountryCode = 'CA',
    this.initialRegionCode = 'AB',
    this.initialPhone = '',
    this.initialTier = 'paid_verified',
  });

  final String? claimedCompanyId;
  final String initialCompanyName;
  final String initialCity;
  final String initialCountryCode;
  final String initialRegionCode;
  final String initialPhone;
  final String initialTier;

  @override
  State<PipeBuyerListServicesPage> createState() =>
      _PipeBuyerListServicesPageState();
}

class _PipeBuyerListServicesPageState extends State<PipeBuyerListServicesPage> {
  final PipeBuyerYellowPagesClient _client = PipeBuyerYellowPagesClient();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _companyNameController;
  final _contactNameController = TextEditingController();
  late final TextEditingController _phoneController;
  final _tollFreeController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  late final TextEditingController _cityController;
  final _customRegionController = TextEditingController();
  final _servicesController = TextEditingController();
  final _descriptionController = TextEditingController();

  late String _selectedTier;
  late String _countryCode;
  late String _regionCode;
  bool _annualBilling = true;
  bool _emergency24x7 = false;
  final Set<String> _selectedCategories = <String>{};
  final Set<String> _selectedBasins = <String>{};
  final Set<String> _selectedCertifications = <String>{};

  bool _submitting = false;
  String? _submittedRequestId;

  @override
  void initState() {
    super.initState();
    _companyNameController =
        TextEditingController(text: widget.initialCompanyName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _cityController = TextEditingController(text: widget.initialCity);
    _selectedTier = widget.initialTier;
    _countryCode =
        widget.initialCountryCode.isNotEmpty ? widget.initialCountryCode : 'CA';
    _regionCode =
        widget.initialRegionCode.isNotEmpty ? widget.initialRegionCode : 'AB';
    _customRegionController.text = _regionCode;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _contactNameController.text = user.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _tollFreeController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _cityController.dispose();
    _customRegionController.dispose();
    _servicesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const MarketplaceAuthPage()),
      );
      if (FirebaseAuth.instance.currentUser == null || !mounted) return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      PipeFeedback.show(
        context,
        message: 'Select at least one Oil & Gas service category.',
        tone: PipeStatusTone.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final services = _servicesController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);

      final result = await _client.submitServiceListingRequest(
        claimedCompanyId: widget.claimedCompanyId,
        companyName: _companyNameController.text.trim(),
        contactName: _contactNameController.text.trim(),
        phone: _phoneController.text.trim(),
        tollFreePhone: _tollFreeController.text.trim(),
        email: _emailController.text.trim(),
        website: _websiteController.text.trim(),
        countryCode: _countryCode,
        regionCode: _regionCode,
        city: _cityController.text.trim(),
        basins: _selectedBasins.toList(growable: false),
        categories: _selectedCategories.toList(growable: false),
        services: services,
        certifications: _selectedCertifications.toList(growable: false),
        emergency24x7: _emergency24x7,
        description: _descriptionController.text.trim(),
        requestedTier: _selectedTier,
      );

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submittedRequestId = result['requestId']?.toString() ?? 'submitted';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst(RegExp(r'^Bad state:\s*'), ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final regions = PipeBuyerYellowPagesTaxonomy.regionsForCountry(_countryCode);
    final validRegionCodes = regions.map((r) => r.regionCode).toSet();
    final activeRegion = validRegionCodes.contains(_regionCode)
        ? _regionCode
        : (regions.isNotEmpty ? regions.first.regionCode : '');

    final isCompactScreen = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      appBar: AppBar(
        leading: !Navigator.of(context).canPop() &&
                GoRouter.maybeOf(context) != null
            ? IconButton(
                tooltip: 'Back to Search Services',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => GoRouter.of(context).go('/services'),
              )
            : null,
        title: Text(
          isCompactScreen
              ? 'LIST SERVICES'
              : 'LIST SERVICES — OILFIELD DIRECTORY',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: _submittedRequestId != null
              ? _SuccessConfirmation(
                  requestId: _submittedRequestId!,
                  tier: _selectedTier,
                  onDone: () => Navigator.of(context).pop(true),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0B192C), Color(0xFF153462)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: PipeBuyerColors.orange,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'GLOBAL DIRECTORY • NORTH AMERICA & WORLDWIDE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Put Your Service Company First When Oilfield Buyers Search',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Paid Priority listings rank above all basic directory records across Search for Services and Dispatch discovery worldwide, with clickable website/email links, safety badges (COR, ISNetworld, API, ISO), and direct RFQ routing.',
                            style: TextStyle(color: Colors.white70, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          '1. Choose Directory Priority Plan (Founding Global Rates)',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Annual (Save 18%)'),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Monthly'),
                            ),
                          ],
                          selected: {_annualBilling},
                          onSelectionChanged: (selection) {
                            setState(() => _annualBilling = selection.first);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 760;
                        final cards = <Widget>[
                          _TierPlanCard(
                            selected: _selectedTier == 'paid_verified',
                            badge: 'MOST POPULAR • BEST VALUE',
                            title: 'Verified Pro',
                            priceLabel: _annualBilling
                                ? r'$24 / mo ($288/yr)'
                                : r'$29 / mo',
                            subtitle:
                                'Ranked above 100% of free listings with full clickable profile & RFQ leads.',
                            perks: const [
                              'Priority Rank #2 — above all unpaid basic records',
                              'Blue VERIFIED PRO + 24/7 Emergency Callout badges',
                              'Clickable Website SEO link, Dispatch Email & Call buttons',
                              '1-Click Request Dispatch Quote button on your card',
                              'Up to 10 service categories, 3 basins & COR/ISNetworld badges',
                            ],
                            accentColor: PipeBuyerColors.industrialBlue,
                            onSelect: () =>
                                setState(() => _selectedTier = 'paid_verified'),
                          ),
                          _TierPlanCard(
                            selected: _selectedTier == 'featured_platinum',
                            badge: 'TOP SPOTLIGHT • RANK #1',
                            title: 'Featured Partner',
                            priceLabel: _annualBilling
                                ? r'$65 / mo ($780/yr)'
                                : r'$79 / mo',
                            subtitle:
                                'Pinned #1 at the top of service, town & basin searches across Dispatch & the Oilfield Directory.',
                            perks: const [
                              'Pinned #1 top spotlight above standard & Pro results',
                              'Gold FEATURED PARTNER card highlight & founding rate lock',
                              'Unlimited categories & multi-basin Canada + USA reach',
                              'Direct Website, Email, Toll-Free & priority RFQ routing',
                              'Full safety badges: COR, ISNetworld, ComplyWorks, ABSA, API',
                            ],
                            accentColor: PipeBuyerColors.orange,
                            onSelect: () => setState(
                              () => _selectedTier = 'featured_platinum',
                            ),
                          ),
                          _TierPlanCard(
                            selected: _selectedTier == 'free_verified',
                            badge: 'BASIC • PHONE ONLY',
                            title: 'Submit Basic Listing',
                            priceLabel: r'$0 / mo',
                            subtitle:
                                'Submit a new business phone & town for directory verification below paid members.',
                            perks: const [
                              'Ranked below Featured Partner & Verified Pro members',
                              'Displays Company Name, Town/Province-State & Phone only',
                              'Verified by PipeBuyer Directory Admin before going live',
                            ],
                            accentColor: PipeBuyerColors.slate,
                            onSelect: () =>
                                setState(() => _selectedTier = 'free_verified'),
                          ),
                        ];
                        if (!wide) {
                          return Column(
                            children: cards
                                .map((c) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: c,
                                    ))
                                .toList(growable: false),
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 12),
                            Expanded(child: cards[1]),
                            const SizedBox(width: 12),
                            Expanded(child: cards[2]),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '2. Business & Dispatch Contact Information',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _companyNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Legal or Operating Company Name *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Enter company name'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, rowConstraints) {
                                  final contactField = TextFormField(
                                    controller: _contactNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Primary Contact Person',
                                      border: OutlineInputBorder(),
                                    ),
                                  );
                                  final emailField = TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: 'Dispatch / Sales Email *',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) =>
                                        (v == null || !v.contains('@'))
                                            ? 'Enter a valid business email'
                                            : null,
                                  );
                                  if (rowConstraints.maxWidth < 640) {
                                    return Column(
                                      children: [
                                        contactField,
                                        const SizedBox(height: 12),
                                        emailField,
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      Expanded(child: contactField),
                                      const SizedBox(width: 12),
                                      Expanded(child: emailField),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, rowConstraints) {
                                  final phoneField = TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      labelText: 'Main Dispatch / Office Phone *',
                                      hintText: '+1 (780) 555-0199 or +44 / +971',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) {
                                      final digits =
                                          (v ?? '').replaceAll(RegExp(r'\D'), '');
                                      if (digits.length < 7 || digits.length > 15) {
                                        return 'Enter a valid business phone with area or country code';
                                      }
                                      return null;
                                    },
                                  );
                                  final tollFreeField = TextFormField(
                                    controller: _tollFreeController,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      labelText: 'Toll-Free Number (Optional)',
                                      hintText: '1-800-555-0199',
                                      border: OutlineInputBorder(),
                                    ),
                                  );
                                  if (rowConstraints.maxWidth < 640) {
                                    return Column(
                                      children: [
                                        phoneField,
                                        const SizedBox(height: 12),
                                        tollFreeField,
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      Expanded(child: phoneField),
                                      const SizedBox(width: 12),
                                      Expanded(child: tollFreeField),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _websiteController,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                  labelText: 'Company Website',
                                  hintText: 'https://yourcompany.com',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                '3. Country, Province/State & Operating Basins',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Popular Oil & Gas Markets (Quick Select):',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: PipeBuyerYellowPagesTaxonomy
                                    .popularCountriesForContinent('')
                                    .take(12)
                                    .map((c) {
                                  final selected = _countryCode == c.code;
                                  return ChoiceChip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text('${c.name} (${c.code})'),
                                    selected: selected,
                                    onSelected: (_) {
                                      final nextRegions =
                                          PipeBuyerYellowPagesTaxonomy
                                              .regionsForCountry(c.code);
                                      setState(() {
                                        _countryCode = c.code;
                                        _regionCode = nextRegions.isNotEmpty
                                            ? nextRegions.first.regionCode
                                            : '';
                                        _customRegionController.text =
                                            _regionCode;
                                      });
                                    },
                                  );
                                }).toList(growable: false),
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, rowConstraints) {
                                  final validCountryCode =
                                      PipeBuyerYellowPagesTaxonomy.countryByCode(
                                                _countryCode,
                                              ) !=
                                              null
                                          ? _countryCode
                                          : 'CA';
                                  final countryField =
                                      DropdownButtonFormField<String>(
                                    key: ValueKey('country-$validCountryCode'),
                                    initialValue: validCountryCode,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Country (All Countries A–Z) *',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: PipeBuyerYellowPagesTaxonomy
                                        .countries
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c.code,
                                            child: Text(
                                              '${c.name} (${c.code})',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      final nextRegions =
                                          PipeBuyerYellowPagesTaxonomy
                                              .regionsForCountry(value);
                                      setState(() {
                                        _countryCode = value;
                                        _regionCode = nextRegions.isNotEmpty
                                            ? nextRegions.first.regionCode
                                            : '';
                                        _customRegionController.text =
                                            _regionCode;
                                      });
                                    },
                                  );
                                  final Widget regionField = regions.isNotEmpty
                                      ? DropdownButtonFormField<String>(
                                          key: ValueKey(
                                            'region-$_countryCode-$activeRegion',
                                          ),
                                          initialValue: activeRegion,
                                          isExpanded: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Province / State *',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: regions
                                              .map(
                                                (r) => DropdownMenuItem(
                                                  value: r.regionCode,
                                                  child: Text(r.displayLabel),
                                                ),
                                              )
                                              .toList(growable: false),
                                          onChanged: (v) {
                                            if (v != null) {
                                              setState(() => _regionCode = v);
                                            }
                                          },
                                        )
                                      : TextFormField(
                                          controller: _customRegionController,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'State / Province / Region (Optional)',
                                            hintText: 'e.g. Region 4 / Doha',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (v) =>
                                              _regionCode = v.trim(),
                                        );
                                  final cityField = TextFormField(
                                    controller: _cityController,
                                    decoration: const InputDecoration(
                                      labelText: 'Headquarters / Base Town *',
                                      hintText:
                                          'Nisku / Midland / Aberdeen / Abu Dhabi',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Enter town or city'
                                            : null,
                                  );
                                  if (rowConstraints.maxWidth < 680) {
                                    return Column(
                                      children: [
                                        countryField,
                                        const SizedBox(height: 12),
                                        regionField,
                                        const SizedBox(height: 12),
                                        cityField,
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      Expanded(child: countryField),
                                      const SizedBox(width: 12),
                                      Expanded(child: regionField),
                                      const SizedBox(width: 12),
                                      Expanded(child: cityField),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Operating Basins / Regions Served',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: PipeBuyerYellowPagesTaxonomy.basins
                                    .map((basin) {
                                  final selected =
                                      _selectedBasins.contains(basin);
                                  return FilterChip(
                                    label: Text(basin),
                                    selected: selected,
                                    onSelected: (val) => setState(() {
                                      if (val) {
                                        _selectedBasins.add(basin);
                                      } else {
                                        _selectedBasins.remove(basin);
                                      }
                                    }),
                                  );
                                }).toList(growable: false),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                '4. Service Categories & Capabilities',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: PipeBuyerYellowPagesTaxonomy.categories
                                    .map((cat) {
                                  final selected =
                                      _selectedCategories.contains(cat.label);
                                  return FilterChip(
                                    avatar: Icon(cat.icon, size: 16),
                                    label: Text(cat.shortLabel),
                                    selected: selected,
                                    onSelected: (val) => setState(() {
                                      if (val) {
                                        _selectedCategories.add(cat.label);
                                      } else {
                                        _selectedCategories.remove(cat.label);
                                      }
                                    }),
                                  );
                                }).toList(growable: false),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _servicesController,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Specific Equipment & Services (comma-separated)',
                                  hintText:
                                      'e.g. Tri-Drive Hydrovac, B-Pressure Rig Welding, 45-Ton Picker, EMI Inspection',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Safety & Industry Certifications',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: PipeBuyerYellowPagesTaxonomy
                                    .certifications
                                    .map((cert) {
                                  final selected =
                                      _selectedCertifications.contains(cert);
                                  return FilterChip(
                                    label: Text(cert),
                                    selected: selected,
                                    onSelected: (val) => setState(() {
                                      if (val) {
                                        _selectedCertifications.add(cert);
                                      } else {
                                        _selectedCertifications.remove(cert);
                                      }
                                    }),
                                  );
                                }).toList(growable: false),
                              ),
                              const SizedBox(height: 10),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _emergency24x7,
                                onChanged: (v) =>
                                    setState(() => _emergency24x7 = v),
                                title: const Text(
                                  '24/7 Emergency Oilfield Dispatch Available',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: const Text(
                                  'Highlights your listing when field supervisors filter for urgent 24-hour callout.',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Company Overview, Fleet Size & Yard Locations',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: FilledButton.icon(
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
                                      : const Icon(Icons.rocket_launch_outlined),
                                  label: Text(
                                    _submitting
                                        ? 'Submitting Listing...'
                                        : 'Submit Service Listing (${_tierTitle(_selectedTier)})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _tierTitle(String tier) => switch (tier) {
        'featured_platinum' => 'Featured Partner',
        'paid_verified' => 'Verified Pro',
        _ => 'Basic Verification',
      };
}

class _TierPlanCard extends StatelessWidget {
  const _TierPlanCard({
    required this.selected,
    required this.badge,
    required this.title,
    required this.priceLabel,
    required this.subtitle,
    required this.perks,
    required this.accentColor,
    required this.onSelect,
  });

  final bool selected;
  final String badge;
  final String title;
  final String priceLabel;
  final String subtitle;
  final List<String> perks;
  final Color accentColor;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accentColor : Theme.of(context).dividerColor,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              priceLabel,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: PipeBuyerColors.muted,
              ),
            ),
            const Divider(height: 20),
            ...perks.map(
              (perk) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 15, color: accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(perk, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessConfirmation extends StatelessWidget {
  const _SuccessConfirmation({
    required this.requestId,
    required this.tier,
    required this.onDone,
  });

  final String requestId;
  final String tier;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 64,
                color: PipeBuyerColors.success,
              ),
              const SizedBox(height: 16),
              const Text(
                'Service Listing Submitted for Priority Verification',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text(
                'Reference ID: $requestId\nOur PipeBuyer Directory team will confirm your active business phone & compliance details and activate your ${tier.replaceAll('_', ' ')} placement.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: PipeBuyerColors.muted, height: 1.4),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onDone,
                icon: const Icon(Icons.check),
                label: const Text('Return to Search for Services'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
