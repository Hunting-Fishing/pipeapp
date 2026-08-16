import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_dispatch_service_taxonomy.dart';

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

  int get completionPercent {
    final checks = <bool>[
      operatingName.trim().isNotEmpty,
      companyName.trim().isNotEmpty,
      description.trim().length >= 40,
      normalizedServiceCodes.isNotEmpty,
      serviceAreaLabel.trim().isNotEmpty,
      true, // business type is always explicit in the editor
      true, // availability is always explicit in the editor
      website.trim().isNotEmpty,
    ];
    final completed = checks.where((value) => value).length;
    return ((completed / checks.length) * 100).round();
  }

  bool get readyForDirectoryFoundation =>
      operatingName.trim().isNotEmpty &&
      companyName.trim().isNotEmpty &&
      normalizedServiceCodes.isNotEmpty &&
      serviceAreaLabel.trim().isNotEmpty;

  Map<String, dynamic> toPublicProfileMap() => {
        'companyName': companyName.trim(),
        'operatingName': operatingName.trim(),
        'businessType': businessType.code,
        'description': description.trim(),
        'website': website.trim(),
        'serviceCodes': normalizedServiceCodes,
        'serviceAreaLabel': serviceAreaLabel.trim(),
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
  late final TextEditingController _serviceArea;
  late DispatchBusinessType _businessType;
  late DispatchAvailability _availability;
  late Set<String> _serviceCodes;
  late bool _emergencyCallout;
  late bool _remoteSiteCapable;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _companyName = TextEditingController(text: initial.companyName);
    _operatingName = TextEditingController(text: initial.operatingName);
    _description = TextEditingController(text: initial.description);
    _website = TextEditingController(text: initial.website);
    _serviceArea = TextEditingController(text: initial.serviceAreaLabel);
    _businessType = initial.businessType;
    _availability = initial.availability;
    _serviceCodes = initial.normalizedServiceCodes.toSet();
    _emergencyCallout = initial.emergencyCallout;
    _remoteSiteCapable = initial.remoteSiteCapable;
  }

  @override
  void dispose() {
    _companyName.dispose();
    _operatingName.dispose();
    _description.dispose();
    _website.dispose();
    _serviceArea.dispose();
    super.dispose();
  }

  DispatchCompanyProfileDraft _draft() => DispatchCompanyProfileDraft(
        companyName: _companyName.text,
        operatingName: _operatingName.text,
        businessType: _businessType,
        description: _description.text,
        website: _website.text,
        serviceCodes: _serviceCodes.toList(),
        serviceAreaLabel: _serviceArea.text,
        availability: _availability,
        emergencyCallout: _emergencyCallout,
        remoteSiteCapable: _remoteSiteCapable,
      );

  void _refresh() => setState(() {});

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
              'Phase 3 keeps the existing service-area model intact while preparing structured Directory availability.',
          leading: const Icon(Icons.location_on_outlined),
          child: Column(
            children: [
              TextField(
                controller: _serviceArea,
                onChanged: (_) => _refresh(),
                decoration: const InputDecoration(
                  labelText: 'Service area summary',
                  hintText: 'Example: Grande Prairie + 300 km / Northern Alberta',
                ),
              ),
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
