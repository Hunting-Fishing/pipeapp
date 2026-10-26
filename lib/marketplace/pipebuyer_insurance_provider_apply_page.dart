import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'pipebuyer_insurance_client.dart';
import 'pipebuyer_insurance_taxonomy.dart';
import 'pipebuyer_site_footer.dart';

class PipeBuyerInsuranceProviderApplyPage extends StatefulWidget {
  const PipeBuyerInsuranceProviderApplyPage({
    super.key,
    this.client,
    this.onSubmitted,
  });

  final PipeBuyerInsuranceClient? client;
  final VoidCallback? onSubmitted;

  @override
  State<PipeBuyerInsuranceProviderApplyPage> createState() =>
      _PipeBuyerInsuranceProviderApplyPageState();
}

class _PipeBuyerInsuranceProviderApplyPageState
    extends State<PipeBuyerInsuranceProviderApplyPage> {
  late final PipeBuyerInsuranceClient _client;
  final _formKey = GlobalKey<FormState>();

  final _companyNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactTitleController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _headquartersCityController = TextEditingController();
  final _regionCodeController = TextEditingController(text: 'TX');
  final _licensedRegionsController =
      TextEditingController(text: 'TX, NM, OK, ND, LA');
  final _licenseSummaryController = TextEditingController();
  final _amBestController = TextEditingController(text: 'A (Excellent)');
  final _maxLimitUsdController = TextEditingController(text: '25000000');
  final _minPremiumUsdController = TextEditingController(text: '5000');
  final _summaryController = TextEditingController();

  String _providerType = 'specialty_broker';
  final Set<String> _licensedCountries = <String>{'US'};
  final Set<String> _selectedBasins = <String>{'Permian Basin'};
  final Set<String> _selectedCoverageLines = <String>{
    'commercial_auto_fleet',
    'oilfield_general_liability',
  };
  bool _msaCompliant = true;
  bool _fastCoi24x7 = true;
  bool _submitting = false;
  PipeBuyerInsuranceProviderApplicationResult? _receipt;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PipeBuyerInsuranceClient();
    final email = _client.currentUserEmail;
    final displayName = _client.currentUserDisplayName;
    if (email.isNotEmpty) _emailController.text = email;
    if (displayName.isNotEmpty) _contactNameController.text = displayName;
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _contactNameController.dispose();
    _contactTitleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _headquartersCityController.dispose();
    _regionCodeController.dispose();
    _licensedRegionsController.dispose();
    _licenseSummaryController.dispose();
    _amBestController.dispose();
    _maxLimitUsdController.dispose();
    _minPremiumUsdController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_licensedCountries.isEmpty) {
      PipeFeedback.show(
        context,
        message: 'Select at least one licensed country.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    if (_selectedCoverageLines.isEmpty) {
      PipeFeedback.show(
        context,
        message: 'Select at least one commercial coverage line written.',
        tone: PipeStatusTone.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final regions = _licensedRegionsController.text
          .split(RegExp(r'[,;\s]+'))
          .map((item) => item.trim().toUpperCase())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      final maxLimit =
          double.tryParse(_maxLimitUsdController.text.replaceAll(',', '')) ?? 0;
      final minPremium =
          double.tryParse(_minPremiumUsdController.text.replaceAll(',', '')) ??
              0;

      final result = await _client.submitProviderApplication(
        companyName: _companyNameController.text.trim(),
        providerType: _providerType,
        contactName: _contactNameController.text.trim(),
        contactTitle: _contactTitleController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        website: _websiteController.text.trim(),
        licenseSummary: _licenseSummaryController.text.trim(),
        countryCode: _licensedCountries.first,
        regionCode: _regionCodeController.text.trim().toUpperCase(),
        headquartersCity: _headquartersCityController.text.trim(),
        licensedCountries: _licensedCountries.toList(growable: false),
        licensedRegions: regions,
        operatingBasins: _selectedBasins.toList(growable: false),
        coverageLines: _selectedCoverageLines.toList(growable: false),
        amBestRating: _amBestController.text.trim(),
        maxLimitUsd: maxLimit,
        fastCoi24x7: _fastCoi24x7,
        msaCompliant: _msaCompliant,
        minimumPremiumUsd: minPremium,
        summary: _summaryController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _receipt = result;
      });
      widget.onSubmitted?.call();
      PipeFeedback.show(
        context,
        message:
            'Insurance provider application submitted for compliance review.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      PipeFeedback.show(
        context,
        message: '$error'.replaceFirst('Bad state: ', ''),
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
        title: const Text('LIST YOUR INSURANCE COMPANY'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroCard(context),
                const SizedBox(height: 16),
                if (_receipt != null)
                  _buildConfirmationCard(context, _receipt!)
                else
                  _buildApplicationForm(context),
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

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            PipeBuyerColors.ink,
            PipeBuyerColors.graphite,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
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
              _PillBadge(
                icon: Icons.verified_user_outlined,
                label: 'CARRIER, MGA & BROKER ONBOARDING',
                backgroundColor: PipeBuyerColors.orange.withValues(alpha: .18),
                foregroundColor: PipeBuyerColors.orange,
              ),
              _PillBadge(
                icon: Icons.public_rounded,
                label: 'US & CANADA ENERGY MARKETS',
                backgroundColor:
                    PipeBuyerColors.industrialBlue.withValues(alpha: .28),
                foregroundColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Become a Verified Insurance Provider on Pipe Buyer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect directly with oilfield hauling fleets, drilling & workover contractors, pipe yards, and industrial operators actively requesting MSA-compliant commercial insurance quotes.',
            style: TextStyle(
              color: Color(0xFFD0D8E4),
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationCard(
    BuildContext context,
    PipeBuyerInsuranceProviderApplicationResult receipt,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.success.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: PipeBuyerColors.success,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Provider Onboarding Application Received',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reference ID: ${receipt.applicationId} • Status: ${receipt.status.toUpperCase()}',
                        style: const TextStyle(
                          color: PipeBuyerColors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Our compliance team verifies active carrier NAIC / producer licensing before publishing your company profile in the Commercial & Oilfield Insurance Directory and enabling direct company rate submissions.',
              style: TextStyle(height: 1.45),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(true),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Return to Insurance Hub'),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => _receipt = null),
                  child: const Text('Submit Another Provider Profile'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= 660;
              final fieldWidth = twoColumn
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FormSectionHeader(
                    number: '1',
                    title: 'Underwriting Organization & Licensing',
                    subtitle:
                        'Provide your carrier, MGA, or specialty brokerage credentials.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          key: const Key('provider_apply_company_name'),
                          controller: _companyNameController,
                          decoration: const InputDecoration(
                            labelText: 'Insurance Company / Brokerage Name *',
                            hintText: 'e.g. Lone Star Energy Risk MGA LLC',
                          ),
                          validator: (val) => (val == null || val.trim().length < 2)
                              ? 'Enter your company name.'
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          key: const Key('provider_apply_type'),
                          initialValue: _providerType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Provider Classification *',
                          ),
                          items: PipeBuyerInsuranceTaxonomy.providerTypes
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
                              setState(() => _providerType = val);
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          key: const Key('provider_apply_contact_name'),
                          controller: _contactNameController,
                          decoration: const InputDecoration(
                            labelText: 'Primary Underwriting Contact *',
                            hintText: 'Full name',
                          ),
                          validator: (val) => (val == null || val.trim().length < 2)
                              ? 'Enter a contact name.'
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: _contactTitleController,
                          decoration: const InputDecoration(
                            labelText: 'Title / Role',
                            hintText: 'e.g. VP Energy & Marine Underwriting',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          key: const Key('provider_apply_email'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Submissions / Underwriting Email *',
                            hintText: 'submissions@carrier.com',
                          ),
                          validator: (val) {
                            final trimmed = val?.trim() ?? '';
                            if (!trimmed.contains('@') || !trimmed.contains('.')) {
                              return 'Enter a valid business email.';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          key: const Key('provider_apply_phone'),
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Business Phone *',
                            hintText: '(432) 555-0180',
                          ),
                          validator: (val) {
                            final digits =
                                (val ?? '').replaceAll(RegExp(r'\D+'), '');
                            return digits.length < 7
                                ? 'Enter a valid business phone number.'
                                : null;
                          },
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: _websiteController,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'Website URL',
                            hintText: 'https://yourbrokerage.com',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: _headquartersCityController,
                          decoration: const InputDecoration(
                            labelText: 'Headquarters City',
                            hintText: 'e.g. Houston or Calgary',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('provider_apply_license_summary'),
                    controller: _licenseSummaryController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText:
                          'Carrier NAIC / State Surplus Lines / Provincial Producer Licenses *',
                      hintText:
                          'e.g. Texas TDI License #419082, Alberta AIC #77410, NAIC #30994',
                    ),
                    validator: (val) => (val == null || val.trim().length < 3)
                        ? 'Provide your producer or carrier license summary.'
                        : null,
                  ),
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 18),
                  const _FormSectionHeader(
                    number: '2',
                    title: 'Licensed Territories & Coverage Lines Written',
                    subtitle:
                        'Select jurisdictions, basins, and commercial lines your team quotes.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Licensed Countries *',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in const <MapEntry<String, String>>[
                        MapEntry('US', 'United States (US)'),
                        MapEntry('CA', 'Canada (CA)'),
                        MapEntry('MX', 'Mexico (MX)'),
                      ])
                        FilterChip(
                          label: Text(entry.value),
                          selected: _licensedCountries.contains(entry.key),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _licensedCountries.add(entry.key);
                              } else if (_licensedCountries.length > 1) {
                                _licensedCountries.remove(entry.key);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: _regionCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Primary HQ State / Province Code',
                            hintText: 'TX, AB, ND, OK...',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: _licensedRegionsController,
                          decoration: const InputDecoration(
                            labelText: 'Licensed States / Provinces (comma-separated)',
                            hintText: 'TX, NM, OK, ND, LA, AB, SK, BC',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Active Energy Basins Served',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PipeBuyerInsuranceTaxonomy.operatingBasins
                        .map(
                          (basin) => FilterChip(
                            label: Text(basin),
                            selected: _selectedBasins.contains(basin),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedBasins.add(basin);
                                } else {
                                  _selectedBasins.remove(basin);
                                }
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Commercial & Oilfield Coverage Lines Written *',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PipeBuyerInsuranceTaxonomy.coverageLines
                        .map(
                          (line) => FilterChip(
                            avatar: Icon(line.icon, size: 16),
                            label: Text(line.shortLabel),
                            selected:
                                _selectedCoverageLines.contains(line.code),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedCoverageLines.add(line.code);
                                } else {
                                  _selectedCoverageLines.remove(line.code);
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
                  const _FormSectionHeader(
                    number: '3',
                    title: 'Capacity, Ratings & MSA Readiness',
                    subtitle:
                        'Highlight your policy limits, A.M. Best security, and certificate speed.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: _amBestController,
                          decoration: const InputDecoration(
                            labelText: 'A.M. Best Security Rating',
                            hintText: 'e.g. A+ (Superior) or A- Panel',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: _maxLimitUsdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max Policy / Umbrella Limit (USD)',
                            hintText: '25000000',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextFormField(
                          controller: _minPremiumUsdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minimum Annual Premium (USD)',
                            hintText: '5000',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _msaCompliant,
                    onChanged: (val) => setState(() => _msaCompliant = val),
                    title: const Text(
                      'Operator MSA-Compliant Endorsements',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    subtitle: const Text(
                      'Can issue Blanket AI, Waiver of Subrogation, and Primary & Non-Contributory endorsements.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _fastCoi24x7,
                    onChanged: (val) => setState(() => _fastCoi24x7 = val),
                    title: const Text(
                      '24/7 Fast Certificate of Insurance (COI) Turnaround',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    subtitle: const Text(
                      'Rapid COI issuance for ISNetworld, Veriforce/PEC, Avetta, and ComplyWorks.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('provider_apply_summary'),
                    controller: _summaryController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Program Appetite & Underwriting Highlights',
                      hintText:
                          'Describe target classes (e.g. OCTG hauling fleets, workover rigs, midstream contractors, pipe yards)...',
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('provider_apply_submit_button'),
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
                          : const Icon(Icons.verified_outlined),
                      label: Text(
                        _submitting
                            ? 'Submitting Application...'
                            : 'Submit Insurance Provider Application',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({
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

class _FormSectionHeader extends StatelessWidget {
  const _FormSectionHeader({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
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
            number,
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
