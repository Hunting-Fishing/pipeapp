import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_dispatch_service_taxonomy.dart';
import 'marketplace_service_area.dart';

enum DispatchBusinessType {
  ownerOperator,
  soleProprietorship,
  partnership,
  corporation,
  other,
}

enum DispatchAvailability {
  availableNow,
  availableToday,
  availableThisWeek,
  unavailable,
}

extension DispatchBusinessTypeLabel on DispatchBusinessType {
  String get label => switch (this) {
        DispatchBusinessType.ownerOperator => 'Owner / operator',
        DispatchBusinessType.soleProprietorship => 'Sole proprietorship',
        DispatchBusinessType.partnership => 'Partnership',
        DispatchBusinessType.corporation => 'Corporation / company',
        DispatchBusinessType.other => 'Other business type',
      };

  String get code => switch (this) {
        DispatchBusinessType.ownerOperator => 'owner_operator',
        DispatchBusinessType.soleProprietorship => 'sole_proprietorship',
        DispatchBusinessType.partnership => 'partnership',
        DispatchBusinessType.corporation => 'corporation',
        DispatchBusinessType.other => 'other',
      };
}

extension DispatchAvailabilityLabel on DispatchAvailability {
  String get label => switch (this) {
        DispatchAvailability.availableNow => 'Available now',
        DispatchAvailability.availableToday => 'Available today',
        DispatchAvailability.availableThisWeek => 'Available this week',
        DispatchAvailability.unavailable => 'Unavailable',
      };

  String get code => switch (this) {
        DispatchAvailability.availableNow => 'available_now',
        DispatchAvailability.availableToday => 'available_today',
        DispatchAvailability.availableThisWeek => 'available_this_week',
        DispatchAvailability.unavailable => 'unavailable',
      };
}

class DispatchCompanyProfileDraft {
  const DispatchCompanyProfileDraft({
    required this.companyName,
    required this.operatingName,
    required this.businessType,
    required this.description,
    required this.website,
    required this.serviceCodes,
    required this.serviceAreaLabel,
    required this.availability,
    required this.emergencyCallout,
    required this.remoteSiteCapable,
    this.serviceArea,
  });

  final String companyName;
  final String operatingName;
  final DispatchBusinessType businessType;
  final String description;
  final String website;
  final List<String> serviceCodes;
  final String serviceAreaLabel;
  final DispatchAvailability availability;
  final bool emergencyCallout;
  final bool remoteSiteCapable;
  final MarketplaceServiceArea? serviceArea;

  List<String> get normalizedServiceCodes {
    final known = DispatchServiceTaxonomy.services.map((item) => item.code).toSet();
    final values = serviceCodes
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && known.contains(value))
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  String get effectiveServiceAreaLabel {
    final structuredSummary = serviceArea?.summary.trim() ?? '';
    if (structuredSummary.isNotEmpty) return structuredSummary;
    return serviceAreaLabel.trim();
  }

  String get homeBaseLabel {
    final label = serviceArea?.centerLabel.trim() ?? '';
    return label.isNotEmpty ? label : effectiveServiceAreaLabel;
  }

  int get completionPercent {
    final checks = <bool>[
      operatingName.trim().isNotEmpty,
      companyName.trim().isNotEmpty,
      description.trim().length >= 40,
      normalizedServiceCodes.isNotEmpty,
      effectiveServiceAreaLabel.isNotEmpty,
      true,
      true,
      website.trim().isNotEmpty,
    ];
    final completed = checks.where((value) => value).length;
    return ((completed / checks.length) * 100).round();
  }

  bool get readyForDirectoryFoundation =>
      operatingName.trim().isNotEmpty &&
      companyName.trim().isNotEmpty &&
      normalizedServiceCodes.isNotEmpty &&
      effectiveServiceAreaLabel.isNotEmpty;

  Map<String, dynamic> toPublicProfileMap() => {
        'operatingName': operatingName.trim(),
        'businessType': businessType.code,
        'description': description.trim(),
        'website': website.trim(),
        'serviceCodes': normalizedServiceCodes,
        'serviceAreaLabel': effectiveServiceAreaLabel,
        'availability': availability.code,
        'emergencyCallout': emergencyCallout,
        'remoteSiteCapable': remoteSiteCapable,
        'profileCompleteness': completionPercent,
      };
}

class MarketplaceDispatchCompanyProfileEditor extends StatefulWidget {
  const MarketplaceDispatchCompanyProfileEditor({
    super.key,
    required this.initial,
    required this.onSave,
    this.saving = false,
  });

  final DispatchCompanyProfileDraft initial;
  final ValueChanged<DispatchCompanyProfileDraft> onSave;
  final bool saving;

  @override
  State<MarketplaceDispatchCompanyProfileEditor> createState() =>
      _MarketplaceDispatchCompanyProfileEditorState();
}

class _MarketplaceDispatchCompanyProfileEditorState
    extends State<MarketplaceDispatchCompanyProfileEditor> {
  late final TextEditingController _companyName;
  late final TextEditingController _operatingName;
  late final TextEditingController _description;
  late final TextEditingController _website;
  late final TextEditingController _serviceAreaLabel;
  late DispatchBusinessType _businessType;
  late DispatchAvailability _availability;
  late Set<String> _serviceCodes;
  late bool _emergencyCallout;
  late bool _remoteSiteCapable;
  MarketplaceServiceArea? _serviceArea;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _companyName = TextEditingController(text: initial.companyName);
    _operatingName = TextEditingController(text: initial.operatingName);
    _description = TextEditingController(text: initial.description);
    _website = TextEditingController(text: initial.website);
    _serviceAreaLabel = TextEditingController(
      text: initial.effectiveServiceAreaLabel,
    );
    _businessType = initial.businessType;
    _availability = initial.availability;
    _serviceCodes = initial.normalizedServiceCodes.toSet();
    _emergencyCallout = initial.emergencyCallout;
    _remoteSiteCapable = initial.remoteSiteCapable;
    _serviceArea = initial.serviceArea;
  }

  @override
  void dispose() {
    _companyName.dispose();
    _operatingName.dispose();
    _description.dispose();
    _website.dispose();
    _serviceAreaLabel.dispose();
    super.dispose();
  }

  DispatchCompanyProfileDraft _draft() => DispatchCompanyProfileDraft(
        companyName: _companyName.text,
        operatingName: _operatingName.text,
        businessType: _businessType,
        description: _description.text,
        website: _website.text,
        serviceCodes: _serviceCodes.toList(),
        serviceAreaLabel: _serviceAreaLabel.text,
        availability: _availability,
        emergencyCallout: _emergencyCallout,
        remoteSiteCapable: _remoteSiteCapable,
        serviceArea: _serviceArea,
      );

  void _refresh() => setState(() {});

  Future<void> _editServiceArea() async {
    final selected = await MarketplaceServiceAreaPicker.show(
      context,
      _serviceArea,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _serviceArea = selected;
      _serviceAreaLabel.text = selected.summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
      children: [
        PipeBuyerPageHeader(
          eyebrow: 'DISPATCH COMPANY PROFILE',
          title: draft.operatingName.trim().isEmpty
              ? 'Build your service profile'
              : draft.operatingName.trim(),
          subtitle:
              'Structured company details power Directory search, service matching and future direct quote requests.',
          icon: Icons.business_center_outlined,
        ),
        const SizedBox(height: 14),
        PipeBuyerSectionCard(
          title: 'Profile completeness',
          subtitle:
              'Complete the core public fields first. Private credentials and account-only records are kept separate.',
          leading: const Icon(
            Icons.fact_check_outlined,
            color: PipeBuyerColors.orange,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: draft.completionPercent / 100),
              const SizedBox(height: 8),
              Text(
                '${draft.completionPercent}% complete',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PipeBuyerSectionCard(
          title: 'Business identity',
          subtitle:
              'Use the operating name customers know. Legal and private verification records remain separate.',
          leading: const Icon(Icons.storefront_outlined),
          child: Column(
            children: [
              TextField(
                controller: _operatingName,
                onChanged: (_) => _refresh(),
                decoration: const InputDecoration(
                  labelText: 'Operating / trade name',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _companyName,
                onChanged: (_) => _refresh(),
                decoration: const InputDecoration(
                  labelText: 'Legal company / owner name',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<DispatchBusinessType>(
                initialValue: _businessType,
                decoration: const InputDecoration(labelText: 'Business type'),
                items: DispatchBusinessType.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _businessType = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                onChanged: (_) => _refresh(),
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Company description',
                  hintText:
                      'What work do you do, what equipment do you operate, and what areas do you normally serve?',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _website,
                onChanged: (_) => _refresh(),
                decoration: const InputDecoration(
                  labelText: 'Website (optional)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PipeBuyerSectionCard(
          title: 'Services provided',
          subtitle:
              'Select every service customers should be able to find you for. These are stable Dispatch service codes, not free-text tags.',
          leading: const Icon(Icons.hub_outlined),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: DispatchServiceTaxonomy.categories.map((category) {
              final services = DispatchServiceTaxonomy.services
                  .where((service) => service.category == category.code)
                  .toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: services
                          .map(
                            (service) => FilterChip(
                              label: Text(service.label),
                              selected: _serviceCodes.contains(service.code),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _serviceCodes.add(service.code);
                                  } else {
                                    _serviceCodes.remove(service.code);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        PipeBuyerSectionCard(
          title: 'Service area & availability',
          subtitle:
              'Set your operating area on the existing Pipe Buyer open map. The public profile receives only an approximate home-base point; exact private location data stays protected.',
          leading: const Icon(Icons.location_on_outlined),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _serviceAreaLabel,
                readOnly: true,
                onTap: _editServiceArea,
                decoration: InputDecoration(
                  labelText: 'Service area',
                  hintText: 'Choose your service area on the map',
                  suffixIcon: IconButton(
                    tooltip: 'Edit service area map',
                    onPressed: _editServiceArea,
                    icon: const Icon(Icons.map_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: widget.saving ? null : _editServiceArea,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(
                  _serviceArea == null
                      ? 'Set service area on map'
                      : 'Edit service area on map',
                ),
              ),
              if (_serviceArea != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Approximate home base: ${draft.homeBaseLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: PipeBuyerColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              DropdownButtonFormField<DispatchAvailability>(
                initialValue: _availability,
                decoration: const InputDecoration(labelText: 'Availability'),
                items: DispatchAvailability.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _availability = value);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _emergencyCallout,
                onChanged: (value) =>
                    setState(() => _emergencyCallout = value ?? false),
                title: const Text('Emergency callout available'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _remoteSiteCapable,
                onChanged: (value) =>
                    setState(() => _remoteSiteCapable = value ?? false),
                title: const Text('Remote-site capable'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: widget.saving ? null : () => widget.onSave(_draft()),
          icon: widget.saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(widget.saving ? 'Saving...' : 'Save company profile'),
        ),
        const SizedBox(height: 8),
        const Text(
          'This editor never asks for private insurance files, authentication identifiers, or private contact data. Those remain in protected account and credential records.',
          textAlign: TextAlign.center,
          style: TextStyle(color: PipeBuyerColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}
