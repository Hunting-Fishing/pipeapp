import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';

enum DispatchSection {
  dashboard,
  requestService,
  directory,
  jobs,
}

enum DispatchAccountRole {
  customerOnly,
  providerOnly,
  customerAndProvider,
}

class DispatchAccountState {
  const DispatchAccountState({
    required this.role,
    required this.providerRegistered,
    required this.providerStatus,
  });

  final DispatchAccountRole role;
  final bool providerRegistered;
  final String providerStatus;

  factory DispatchAccountState.fromCarrierProfile({
    required bool exists,
    Map<String, dynamic>? data,
  }) {
    if (!exists) {
      return const DispatchAccountState(
        role: DispatchAccountRole.customerOnly,
        providerRegistered: false,
        providerStatus: '',
      );
    }

    final profile = data ?? const <String, dynamic>{};
    final rawRoles = profile['dispatchRoles'] ?? profile['roles'];
    final roles = rawRoles is Iterable
        ? rawRoles
            .map((value) => value.toString().trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet()
        : const <String>{};
    final hasExplicitRoles = roles.isNotEmpty;
    final customer = roles.contains('customer');
    final provider = roles.contains('provider') || exists;

    final role = hasExplicitRoles && provider && !customer
        ? DispatchAccountRole.providerOnly
        : provider
            ? DispatchAccountRole.customerAndProvider
            : DispatchAccountRole.customerOnly;

    return DispatchAccountState(
      role: role,
      providerRegistered: provider,
      providerStatus: '${profile['status'] ?? ''}'.trim(),
    );
  }

  bool get isProvider => providerRegistered;

  bool get canRequestServices => role != DispatchAccountRole.providerOnly;

  String get roleLabel => switch (role) {
        DispatchAccountRole.customerOnly => 'Customer',
        DispatchAccountRole.providerOnly => 'Provider',
        DispatchAccountRole.customerAndProvider => 'Customer + Provider',
      };

  String get providerActionLabel =>
      providerRegistered ? 'Company Profile' : 'List your business';

  String get providerStatusLabel {
    if (!providerRegistered) return 'Not listed';
    return switch (providerStatus) {
      'active' => 'Provider active',
      'pending_review' => 'Review pending',
      'changes_requested' => 'Changes requested',
      'suspended' => 'Provider suspended',
      'rejected' => 'Application rejected',
      _ => 'Provider account',
    };
  }
}

class MarketplaceDispatchNavigation extends StatelessWidget {
  const MarketplaceDispatchNavigation({
    super.key,
    required this.selected,
    required this.accountState,
    required this.onSelected,
    required this.onProviderAction,
  });

  final DispatchSection selected;
  final DispatchAccountState accountState;
  final ValueChanged<DispatchSection> onSelected;
  final VoidCallback onProviderAction;

  @override
  Widget build(BuildContext context) {
    final navigation = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<DispatchSection>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: DispatchSection.dashboard,
            icon: Icon(Icons.dashboard_outlined),
            label: Text('Dashboard'),
          ),
          ButtonSegment(
            value: DispatchSection.requestService,
            icon: Icon(Icons.add_road_outlined),
            label: Text('Request Service'),
          ),
          ButtonSegment(
            value: DispatchSection.directory,
            icon: Icon(Icons.business_outlined),
            label: Text('Directory'),
          ),
          ButtonSegment(
            value: DispatchSection.jobs,
            icon: Icon(Icons.work_outline),
            label: Text('Jobs'),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (value) => onSelected(value.first),
      ),
    );

    final providerAction = OutlinedButton.icon(
      onPressed: onProviderAction,
      icon: Icon(
        accountState.providerRegistered
            ? Icons.business_center_outlined
            : Icons.add_business_outlined,
      ),
      label: Text(accountState.providerActionLabel),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              navigation,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: providerAction),
                  const SizedBox(width: 8),
                  PipeBuyerStatusBadge(
                    label: accountState.roleLabel,
                    icon: accountState.providerRegistered
                        ? Icons.swap_horiz_rounded
                        : Icons.person_outline,
                    tone: accountState.providerRegistered
                        ? PipeBuyerStatusTone.premium
                        : PipeBuyerStatusTone.info,
                  ),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: navigation),
            const SizedBox(width: 12),
            PipeBuyerStatusBadge(
              label: accountState.roleLabel,
              icon: accountState.providerRegistered
                  ? Icons.swap_horiz_rounded
                  : Icons.person_outline,
              tone: accountState.providerRegistered
                  ? PipeBuyerStatusTone.premium
                  : PipeBuyerStatusTone.info,
            ),
            const SizedBox(width: 8),
            providerAction,
          ],
        );
      },
    );
  }
}

class MarketplaceDispatchCustomerHome extends StatelessWidget {
  const MarketplaceDispatchCustomerHome({
    super.key,
    required this.onRequestService,
    required this.onBrowseDirectory,
    required this.onBrowseJobs,
    required this.onListBusiness,
  });

  final VoidCallback onRequestService;
  final VoidCallback onBrowseDirectory;
  final VoidCallback onBrowseJobs;
  final VoidCallback onListBusiness;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
              ),
              borderRadius: BorderRadius.circular(22),
              border: const Border(
                left: BorderSide(color: PipeBuyerColors.orange, width: 6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PipeBuyerStatusBadge(
                  label: 'PIPE BUYER DISPATCH',
                  icon: Icons.route_outlined,
                  tone: PipeBuyerStatusTone.premium,
                ),
                const SizedBox(height: 14),
                Text(
                  'Find the service you need without starting another account.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Request transportation, browse industrial service providers, or list your own business in the Dispatch network.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: onRequestService,
                      icon: const Icon(Icons.add_road_outlined),
                      label: const Text('Request Service'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                      ),
                      onPressed: onBrowseDirectory,
                      icon: const Icon(Icons.business_outlined),
                      label: const Text('Find Companies'),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: onBrowseJobs,
                      icon: const Icon(Icons.work_outline),
                      label: const Text('Browse Jobs'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const PipeBuyerPageHeader(
            eyebrow: 'DISPATCH NETWORK',
            title: 'Choose what you need to do',
            subtitle:
                'Customers and service providers use the same Pipe Buyer account.',
            icon: Icons.hub_outlined,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final width = wide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: PipeBuyerSectionCard(
                      title: 'I need a service',
                      subtitle:
                          'Start a Dispatch request or find a company by service and location.',
                      leading: const Icon(
                        Icons.search_outlined,
                        color: PipeBuyerColors.orange,
                      ),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: onRequestService,
                            icon: const Icon(Icons.add_road_outlined),
                            label: const Text('Request a service'),
                          ),
                          OutlinedButton.icon(
                            onPressed: onBrowseDirectory,
                            icon: const Icon(Icons.business_outlined),
                            label: const Text('Browse directory'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: PipeBuyerSectionCard(
                      title: 'I provide services',
                      subtitle:
                          'Create or manage a provider profile for your company or owner/operator business.',
                      leading: const Icon(
                        Icons.business_center_outlined,
                        color: PipeBuyerColors.industrialBlue,
                      ),
                      child: FilledButton.icon(
                        onPressed: onListBusiness,
                        icon: const Icon(Icons.add_business_outlined),
                        label: const Text('List your business'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      );
}

class MarketplaceDispatchDirectoryFoundation extends StatelessWidget {
  const MarketplaceDispatchDirectoryFoundation({
    super.key,
    required this.accountState,
    this.legacyProviderTools,
  });

  final DispatchAccountState accountState;
  final Widget? legacyProviderTools;

  @override
  Widget build(BuildContext context) {
    const servicePreview = [
      'Pilot / Escort',
      'Heavy Haul / Lowboy',
      'Crane / Picker',
      'Hotshot',
      'Grading / Road Work',
      'Mobile Mechanic',
      'Oilfield Services',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
      children: [
        const PipeBuyerPageHeader(
          eyebrow: 'PIPE BUYER SERVICE DIRECTORY',
          title: 'Industrial companies and owner/operators',
          subtitle:
              'The Directory is the searchable company network for transportation and field services. Phase 1 establishes its permanent navigation entry while taxonomy, company profiles, filters and map search are built in the gated phases that follow.',
          icon: Icons.business_outlined,
        ),
        const SizedBox(height: 14),
        PipeBuyerSectionCard(
          title: 'Directory foundation active',
          subtitle:
              'Search is intentionally not pretending to be complete before the service taxonomy and company profile model are verified.',
          leading: const Icon(
            Icons.manage_search_outlined,
            color: PipeBuyerColors.orange,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: servicePreview
                .map((service) => Chip(label: Text(service)))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        PipeBuyerSectionCard(
          title: accountState.providerRegistered
              ? 'Your business will be searchable here'
              : 'Need to add a business?',
          subtitle: accountState.providerRegistered
              ? 'Company services, service areas, equipment and availability will feed the Directory after the provider profile phase is complete.'
              : 'Use List your business to create the existing Dispatch provider record. The expanded company profile is built in Phase 3.',
          leading: Icon(
            accountState.providerRegistered
                ? Icons.business_center_outlined
                : Icons.add_business_outlined,
            color: PipeBuyerColors.industrialBlue,
          ),
          child: Text(
            accountState.providerStatusLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (legacyProviderTools != null) ...[
          const SizedBox(height: 20),
          const PipeBuyerPageHeader(
            eyebrow: 'CURRENT PROVIDER TOOLS',
            title: 'Pilot and escort equipment',
            subtitle:
                'Existing provider equipment remains available during the network restructure.',
            icon: Icons.assistant_direction_outlined,
          ),
          const SizedBox(height: 10),
          legacyProviderTools!,
        ],
      ],
    );
  }
}
