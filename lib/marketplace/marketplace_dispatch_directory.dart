import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/data/bounded_firestore_query.dart';
import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_dispatch_service_taxonomy.dart';

class DispatchDirectoryEntry {
  const DispatchDirectoryEntry({
    required this.id,
    required this.operatingName,
    required this.description,
    required this.website,
    required this.businessTypeCode,
    required this.serviceCodes,
    required this.serviceAreaLabel,
    required this.availabilityCode,
    required this.emergencyCallout,
    required this.remoteSiteCapable,
    required this.homeBaseLabel,
    required this.homeBasePoint,
  });

  factory DispatchDirectoryEntry.fromPublicBusinessProfile(
    String id,
    Map<String, dynamic> data,
  ) {
    final dispatch = _map(data['dispatchProfile']);
    final serviceCodes = dispatch['serviceCodes'] is Iterable
        ? (dispatch['serviceCodes'] as Iterable)
            .map((value) => '$value'.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
        : <String>[];
    serviceCodes.sort();

    final home = _map(dispatch['homeLocation']);
    final point = home['point'];

    return DispatchDirectoryEntry(
      id: id,
      operatingName: _firstText([
        dispatch['operatingName'],
        data['publicName'],
      ]),
      description: _firstText([
        dispatch['description'],
        data['description'],
      ]),
      website: _firstText([
        dispatch['website'],
        data['website'],
      ]),
      businessTypeCode: '${dispatch['businessType'] ?? ''}'.trim(),
      serviceCodes: serviceCodes,
      serviceAreaLabel: _firstText([
        dispatch['serviceAreaLabel'],
        data['serviceAreaLabel'],
      ]),
      availabilityCode: '${dispatch['availability'] ?? ''}'.trim(),
      emergencyCallout: dispatch['emergencyCallout'] == true,
      remoteSiteCapable: dispatch['remoteSiteCapable'] == true,
      homeBaseLabel: '${home['label'] ?? ''}'.trim(),
      homeBasePoint: point is GeoPoint ? point : null,
    );
  }

  final String id;
  final String operatingName;
  final String description;
  final String website;
  final String businessTypeCode;
  final List<String> serviceCodes;
  final String serviceAreaLabel;
  final String availabilityCode;
  final bool emergencyCallout;
  final bool remoteSiteCapable;
  final String homeBaseLabel;
  final GeoPoint? homeBasePoint;

  bool get isDirectoryReady =>
      operatingName.isNotEmpty &&
      serviceCodes.isNotEmpty &&
      serviceAreaLabel.isNotEmpty;

  bool matches(DispatchDirectoryFilters filters) {
    if (filters.serviceCode.isNotEmpty &&
        !serviceCodes.contains(filters.serviceCode)) {
      return false;
    }
    if (filters.availabilityCode.isNotEmpty &&
        availabilityCode != filters.availabilityCode) {
      return false;
    }
    if (filters.businessTypeCode.isNotEmpty &&
        businessTypeCode != filters.businessTypeCode) {
      return false;
    }
    if (filters.emergencyOnly && !emergencyCallout) return false;
    if (filters.remoteOnly && !remoteSiteCapable) return false;

    final query = filters.searchText.trim().toLowerCase();
    if (query.isEmpty) return true;
    final haystack = <String>[
      operatingName,
      description,
      serviceAreaLabel,
      homeBaseLabel,
      ...serviceCodes.map(_serviceLabel),
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = '${value ?? ''}'.trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}

class DispatchDirectoryFilters {
  const DispatchDirectoryFilters({
    this.searchText = '',
    this.serviceCode = '',
    this.availabilityCode = '',
    this.businessTypeCode = '',
    this.emergencyOnly = false,
    this.remoteOnly = false,
  });

  final String searchText;
  final String serviceCode;
  final String availabilityCode;
  final String businessTypeCode;
  final bool emergencyOnly;
  final bool remoteOnly;

  bool get hasActiveFilters =>
      searchText.trim().isNotEmpty ||
      serviceCode.isNotEmpty ||
      availabilityCode.isNotEmpty ||
      businessTypeCode.isNotEmpty ||
      emergencyOnly ||
      remoteOnly;

  DispatchDirectoryFilters copyWith({
    String? searchText,
    String? serviceCode,
    String? availabilityCode,
    String? businessTypeCode,
    bool? emergencyOnly,
    bool? remoteOnly,
  }) =>
      DispatchDirectoryFilters(
        searchText: searchText ?? this.searchText,
        serviceCode: serviceCode ?? this.serviceCode,
        availabilityCode: availabilityCode ?? this.availabilityCode,
        businessTypeCode: businessTypeCode ?? this.businessTypeCode,
        emergencyOnly: emergencyOnly ?? this.emergencyOnly,
        remoteOnly: remoteOnly ?? this.remoteOnly,
      );
}

class DispatchDirectoryPageData {
  const DispatchDirectoryPageData({
    required this.entries,
    required this.cursor,
    required this.hasMore,
  });

  final List<DispatchDirectoryEntry> entries;
  final QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}

class MarketplaceDispatchDirectoryRepository {
  MarketplaceDispatchDirectoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<DispatchDirectoryPageData> loadPage({
    QueryDocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 60,
  }) async {
    final page = await loadFirestoreDocumentPage(
      _firestore.collection('public_business_profiles'),
      after: after,
      pageSize: pageSize,
    );
    final entries = page.documents
        .map(
          (document) => DispatchDirectoryEntry.fromPublicBusinessProfile(
            document.id,
            document.data(),
          ),
        )
        .where((entry) => entry.isDirectoryReady)
        .toList(growable: false);
    return DispatchDirectoryPageData(
      entries: entries,
      cursor: page.cursor,
      hasMore: page.hasMore,
    );
  }
}

class MarketplaceDispatchDirectoryPage extends StatefulWidget {
  const MarketplaceDispatchDirectoryPage({
    super.key,
    this.repository,
    this.seedEntries,
    this.legacyProviderTools,
  });

  final MarketplaceDispatchDirectoryRepository? repository;
  final List<DispatchDirectoryEntry>? seedEntries;
  final Widget? legacyProviderTools;

  @override
  State<MarketplaceDispatchDirectoryPage> createState() =>
      _MarketplaceDispatchDirectoryPageState();
}

class _MarketplaceDispatchDirectoryPageState
    extends State<MarketplaceDispatchDirectoryPage> {
  late final MarketplaceDispatchDirectoryRepository _repository;
  late Future<DispatchDirectoryPageData> _loadFuture;
  final TextEditingController _search = TextEditingController();
  DispatchDirectoryFilters _filters = const DispatchDirectoryFilters();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MarketplaceDispatchDirectoryRepository();
    _loadFuture = _load();
  }

  Future<DispatchDirectoryPageData> _load() {
    final seed = widget.seedEntries;
    if (seed != null) {
      return Future.value(
        DispatchDirectoryPageData(
          entries: seed,
          cursor: null,
          hasMore: false,
        ),
      );
    }
    return _repository.loadPage();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _loadFuture = _load());

  void _setFilters(DispatchDirectoryFilters value) =>
      setState(() => _filters = value);

  void _clearFilters() {
    _search.clear();
    _setFilters(const DispatchDirectoryFilters());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DispatchDirectoryPageData>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 42),
                  const SizedBox(height: 10),
                  const Text(
                    'Directory could not be loaded.',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check the connection and retry. No private provider data is used by this Directory view.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Retry directory'),
                  ),
                ],
              ),
            ),
          );
        }

        final allEntries = snapshot.data?.entries ?? const <DispatchDirectoryEntry>[];
        final filtered = allEntries
            .where((entry) => entry.matches(_filters))
            .toList(growable: false);

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          children: [
            const PipeBuyerPageHeader(
              eyebrow: 'PIPE BUYER SERVICE DIRECTORY',
              title: 'Find industrial service companies',
              subtitle:
                  'Search structured provider profiles by service, operating area and availability. This first Directory slice uses only public company profile data.',
              icon: Icons.business_outlined,
            ),
            const SizedBox(height: 14),
            _DirectoryFilterCard(
              searchController: _search,
              filters: _filters,
              onChanged: _setFilters,
              onClear: _clearFilters,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${filtered.length} ${filtered.length == 1 ? 'company' : 'companies'} shown',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const PipeBuyerStatusBadge(
                  label: 'LIST VIEW',
                  icon: Icons.view_list_outlined,
                  tone: PipeBuyerStatusTone.info,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (allEntries.isEmpty)
              const _DirectoryEmptyState(
                title: 'No companies are listed yet',
                message:
                    'Provider profiles become eligible after they contain an operating name, at least one structured service, and a service area.',
              )
            else if (filtered.isEmpty)
              _DirectoryEmptyState(
                title: 'No companies match these filters',
                message:
                    'Clear one or more filters or search a broader service or location.',
                action: _filters.hasActiveFilters
                    ? OutlinedButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Clear filters'),
                      )
                    : null,
              )
            else
              ...filtered.map((entry) => _DirectoryCompanyCard(entry: entry)),
            if (snapshot.data?.hasMore == true) ...[
              const SizedBox(height: 8),
              const Text(
                'More public provider profiles are available. Pagination will be wired into the next Directory data slice.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PipeBuyerColors.muted, fontSize: 12),
              ),
            ],
            if (widget.legacyProviderTools != null) ...[
              const SizedBox(height: 20),
              const PipeBuyerPageHeader(
                eyebrow: 'CURRENT PROVIDER TOOLS',
                title: 'Pilot and escort equipment',
                subtitle:
                    'Existing provider equipment remains available while the full Directory map and company detail workflow are added.',
                icon: Icons.assistant_direction_outlined,
              ),
              const SizedBox(height: 10),
              widget.legacyProviderTools!,
            ],
          ],
        );
      },
    );
  }
}

class _DirectoryFilterCard extends StatelessWidget {
  const _DirectoryFilterCard({
    required this.searchController,
    required this.filters,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final DispatchDirectoryFilters filters;
  final ValueChanged<DispatchDirectoryFilters> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return PipeBuyerSectionCard(
      title: 'Search & filters',
      subtitle:
          'Start with the service you need, then narrow by availability or business type.',
      leading: const Icon(Icons.tune_outlined, color: PipeBuyerColors.orange),
      trailing: filters.hasActiveFilters
          ? TextButton(onPressed: onClear, child: const Text('Clear'))
          : null,
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: (value) => onChanged(filters.copyWith(searchText: value)),
            decoration: const InputDecoration(
              labelText: 'Search company, service or area',
              prefixIcon: Icon(Icons.search_outlined),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final service = DropdownButtonFormField<String>(
                initialValue: filters.serviceCode,
                decoration: const InputDecoration(labelText: 'Service'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All services')),
                  ...DispatchServiceTaxonomy.services.map(
                    (service) => DropdownMenuItem(
                      value: service.code,
                      child: Text(service.label),
                    ),
                  ),
                ],
                onChanged: (value) => onChanged(
                  filters.copyWith(serviceCode: value ?? ''),
                ),
              );
              final availability = DropdownButtonFormField<String>(
                initialValue: filters.availabilityCode,
                decoration: const InputDecoration(labelText: 'Availability'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Any availability')),
                  DropdownMenuItem(
                    value: 'available_now',
                    child: Text('Available now'),
                  ),
                  DropdownMenuItem(
                    value: 'available_today',
                    child: Text('Available today'),
                  ),
                  DropdownMenuItem(
                    value: 'available_this_week',
                    child: Text('Available this week'),
                  ),
                  DropdownMenuItem(
                    value: 'unavailable',
                    child: Text('Unavailable'),
                  ),
                ],
                onChanged: (value) => onChanged(
                  filters.copyWith(availabilityCode: value ?? ''),
                ),
              );
              final businessType = DropdownButtonFormField<String>(
                initialValue: filters.businessTypeCode,
                decoration: const InputDecoration(labelText: 'Business type'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All business types')),
                  DropdownMenuItem(
                    value: 'owner_operator',
                    child: Text('Owner / operator'),
                  ),
                  DropdownMenuItem(
                    value: 'sole_proprietorship',
                    child: Text('Sole proprietorship'),
                  ),
                  DropdownMenuItem(
                    value: 'partnership',
                    child: Text('Partnership'),
                  ),
                  DropdownMenuItem(
                    value: 'corporation',
                    child: Text('Corporation / company'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) => onChanged(
                  filters.copyWith(businessTypeCode: value ?? ''),
                ),
              );

              if (!wide) {
                return Column(
                  children: [
                    service,
                    const SizedBox(height: 10),
                    availability,
                    const SizedBox(height: 10),
                    businessType,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: service),
                  const SizedBox(width: 10),
                  Expanded(child: availability),
                  const SizedBox(width: 10),
                  Expanded(child: businessType),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('Emergency callout'),
                selected: filters.emergencyOnly,
                onSelected: (value) =>
                    onChanged(filters.copyWith(emergencyOnly: value)),
              ),
              FilterChip(
                label: const Text('Remote-site capable'),
                selected: filters.remoteOnly,
                onSelected: (value) =>
                    onChanged(filters.copyWith(remoteOnly: value)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectoryCompanyCard extends StatelessWidget {
  const _DirectoryCompanyCard({required this.entry});

  final DispatchDirectoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final services = entry.serviceCodes.take(5).map(_serviceLabel).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PipeBuyerSectionCard(
        title: entry.operatingName,
        subtitle: entry.serviceAreaLabel,
        leading: const Icon(
          Icons.business_center_outlined,
          color: PipeBuyerColors.industrialBlue,
        ),
        trailing: _AvailabilityBadge(code: entry.availabilityCode),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.description.isNotEmpty) ...[
              Text(
                entry.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                ...services.map((label) => Chip(label: Text(label))),
                if (entry.emergencyCallout)
                  const Chip(
                    avatar: Icon(Icons.bolt_outlined, size: 18),
                    label: Text('Emergency callout'),
                  ),
                if (entry.remoteSiteCapable)
                  const Chip(
                    avatar: Icon(Icons.terrain_outlined, size: 18),
                    label: Text('Remote-site capable'),
                  ),
              ],
            ),
            if (entry.homeBaseLabel.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Approximate home base: ${entry.homeBaseLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Provider-supplied profile information. Verification badges are not shown in this Directory foundation.',
              style: TextStyle(color: PipeBuyerColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final label = switch (code) {
      'available_now' => 'AVAILABLE NOW',
      'available_today' => 'TODAY',
      'available_this_week' => 'THIS WEEK',
      'unavailable' => 'UNAVAILABLE',
      _ => 'AVAILABILITY UNKNOWN',
    };
    final tone = switch (code) {
      'available_now' || 'available_today' => PipeBuyerStatusTone.success,
      'available_this_week' => PipeBuyerStatusTone.info,
      'unavailable' => PipeBuyerStatusTone.neutral,
      _ => PipeBuyerStatusTone.neutral,
    };
    return PipeBuyerStatusBadge(
      label: label,
      icon: Icons.schedule_outlined,
      tone: tone,
    );
  }
}

class _DirectoryEmptyState extends StatelessWidget {
  const _DirectoryEmptyState({
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => PipeBuyerSectionCard(
        title: title,
        subtitle: message,
        leading: const Icon(Icons.search_off_outlined),
        child: action ?? const SizedBox.shrink(),
      );
}

String _serviceLabel(String code) {
  for (final service in DispatchServiceTaxonomy.services) {
    if (service.code == code) return service.label;
  }
  return code;
}
