import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/data/bounded_firestore_query.dart';

import 'marketplace_command_client.dart';
import 'marketplace_dispatch_repository.dart';
import 'marketplace_dispatch_company_profile_page.dart';
import 'marketplace_dispatch_distance.dart';
import 'marketplace_money.dart';
import 'marketplace_service_area.dart';
import 'marketplace_freight_quote.dart';
import 'marketplace_dispatch_dashboard.dart';
import 'marketplace_dispatch_navigation.dart';
import 'marketplace_deep_links.dart';
import 'marketplace_data_state.dart';
import 'marketplace_dispatch_transaction.dart';
import 'marketplace_location.dart';
import 'marketplace_location_picker.dart';
import 'industrial_icon_assets.dart';

const _dispatchServices = <({String name, IconData icon})>[
  (name: 'Flat deck', icon: Icons.view_stream_outlined),
  (name: 'Step deck', icon: Icons.stairs_outlined),
  (name: 'Lowboy', icon: Icons.horizontal_rule),
  (name: 'Winch', icon: Icons.settings_outlined),
  (name: 'Hotshot', icon: Icons.speed_outlined),
  (name: 'Pipe hauling', icon: Icons.linear_scale_outlined),
  (name: 'Heavy equipment', icon: Icons.precision_manufacturing_outlined),
  (name: 'Oversize load', icon: Icons.open_in_full_outlined),
  (name: 'General freight', icon: Icons.inventory_2_outlined),
  (name: 'Oilfield service', icon: Icons.oil_barrel_outlined),
  (name: 'Picker / crane', icon: Icons.construction_outlined),
  (name: 'Towing / recovery', icon: Icons.car_repair_outlined),
  (name: 'Local haul', icon: Icons.location_city_outlined),
  (name: 'Long distance', icon: Icons.route_outlined),
  (name: 'Pilot / escort', icon: Icons.assistant_direction_outlined),
  (name: 'Route survey', icon: Icons.map_outlined),
  (name: 'Traffic control', icon: Icons.signpost_outlined),
  (name: 'Hazmat qualified', icon: Icons.warning_amber_outlined),
];

IconData _dispatchServiceIcon(String service) => _dispatchServices
    .firstWhere(
      (item) => item.name == service,
      orElse: () => (name: service, icon: Icons.local_shipping_outlined),
    )
    .icon;

IconData _vehicleTypeFallbackIcon(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('pilot')) return Icons.assistant_direction_outlined;
  if (normalized.contains('pickup')) return Icons.local_shipping_outlined;
  if (normalized.contains('hotshot')) return Icons.speed_outlined;
  return Icons.local_shipping_outlined;
}

IconData _weightSourceIcon(String source) {
  final normalized = source.toLowerCase();
  if (normalized.contains('registration') ||
      normalized.contains('vehicle plate')) {
    return Icons.badge_outlined;
  }
  if (normalized.contains('manufacturer')) return Icons.factory_outlined;
  if (normalized.contains('scale')) return Icons.scale_outlined;
  return Icons.edit_note_outlined;
}

DateTime _dispatchDate(Map<String, dynamic> data) {
  final value = data['updatedAt'] ?? data['createdAt'];
  return value is Timestamp
      ? value.toDate()
      : DateTime.fromMillisecondsSinceEpoch(0);
}

String _dispatchDateLabel(Map<String, dynamic> data) {
  final date = _dispatchDate(data).toLocal();
  if (date.millisecondsSinceEpoch == 0) return 'Timestamp pending';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}

String _dispatchEventLabel(String event) => switch (event) {
      'request_created' => 'Request published',
      'request_activated' || 'request_published' => 'Request opened',
      'request_updated' => 'Request edited',
      'quote_submitted' => 'Carrier quote submitted',
      'quote_updated' => 'Carrier quote edited',
      'quote_awarded' => 'Carrier selected',
      'quote_archived' => 'Quote archived',
      'carrier_awarded' => 'Dispatch job awarded',
      _ => event.replaceAll('_', ' '),
    };

class MarketplaceDispatchJobRoutePage extends StatefulWidget {
  const MarketplaceDispatchJobRoutePage({super.key, required this.jobId});

  final String jobId;

  @override
  State<MarketplaceDispatchJobRoutePage> createState() =>
      _MarketplaceDispatchJobRoutePageState();
}

class _MarketplaceDispatchJobRoutePageState
    extends State<MarketplaceDispatchJobRoutePage> {
  final _repository = MarketplaceDispatchRepository();
  late Future<DocumentSnapshot<Map<String, dynamic>>> _job;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _job = FirebaseFirestore.instance
        .collection('dispatch_jobs')
        .doc(widget.jobId)
        .get();
  }

  void _retry() => setState(_load);

  Future<void> _copyLink() async {
    final target = MarketplaceDeepLinks.shareTarget(
        MarketplaceDeepLinks.dispatchJob(widget.jobId));
    await Clipboard.setData(ClipboardData(text: target));
    if (!mounted) return;
    PipeFeedback.show(
      context,
      message: target.startsWith('http')
          ? 'Dispatch job link copied.'
          : 'Dispatch app route copied.',
      tone: PipeStatusTone.success,
    );
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _job,
          builder: (context, snapshot) {
            final document = snapshot.data;
            return Scaffold(
              appBar: AppBar(
                title: const Text('Dispatch job'),
                leading: IconButton(
                    tooltip: 'Back',
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                    icon: const Icon(Icons.arrow_back)),
                actions: [
                  IconButton(
                      tooltip: 'Copy job link',
                      onPressed: snapshot.hasData ? _copyLink : null,
                      icon: const Icon(Icons.share_outlined)),
                  IconButton(
                      tooltip: 'Marketplace home',
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.home_outlined)),
                ],
              ),
              body: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : snapshot.hasError
                      ? _DispatchRouteFailure(
                          message: snapshot.error is FirebaseException &&
                                  (snapshot.error as FirebaseException).code ==
                                      'permission-denied'
                              ? 'This Dispatch job is private or your account is not a participant.'
                              : 'The Dispatch job could not be loaded. Check your connection and retry.',
                          onRetry: _retry)
                      : document == null || !document.exists
                          ? _DispatchRouteFailure(
                              message:
                                  'This Dispatch job may have been removed, archived, or the link may be incorrect.',
                              onRetry: _retry)
                          : _DispatchJobRouteDetails(
                              document: document, repository: _repository),
            );
          });
}

class _DispatchRouteFailure extends StatelessWidget {
  const _DispatchRouteFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_shipping_outlined,
                size: 52, color: Color(0xFF66758A)),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry')),
              FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Marketplace home')),
            ])
          ]),
        ),
      );
}

class _DispatchJobRouteDetails extends StatelessWidget {
  const _DispatchJobRouteDetails(
      {required this.document, required this.repository});

  final DocumentSnapshot<Map<String, dynamic>> document;
  final MarketplaceDispatchRepository repository;

  @override
  Widget build(BuildContext context) {
    final data = document.data() ?? const <String, dynamic>{};
    final status = '${data['status'] ?? 'open'}';
    final truckingDate = data['truckingDate'] is Timestamp
        ? (data['truckingDate'] as Timestamp).toDate().toLocal()
        : null;
    final owner =
        data['createdByUid'] == FirebaseAuth.instance.currentUser?.uid;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const IndustrialAssetIcon(
            label: 'Dispatch load board',
            assetPath: IndustrialIconAssets.dispatchLoadBoard,
            size: 62,
            fallback: Icon(Icons.local_shipping_outlined, size: 42)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${data['title'] ?? 'Dispatch load'}',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(owner ? 'Your Dispatch request' : 'Carrier opportunity',
              style: const TextStyle(color: Color(0xFF66758A))),
        ])),
        Chip(label: Text(status.toUpperCase()))
      ]),
      const SizedBox(height: 14),
      Card(
          color: const Color(0xFFEAF4FD),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _DispatchRouteFact(
                    icon: Icons.trip_origin,
                    label: 'Pickup',
                    value: '${data['pickupLabel'] ?? 'To be confirmed'}'),
                _DispatchRouteFact(
                    icon: Icons.flag_outlined,
                    label: 'Delivery',
                    value: '${data['deliveryLabel'] ?? 'To be confirmed'}'),
                _DispatchRouteFact(
                    icon: Icons.route_outlined,
                    label: 'Distance',
                    value: dispatchDistanceLabel(data)),
                _DispatchRouteFact(
                    icon: Icons.scale_outlined,
                    label: 'Estimated weight',
                    value: data['estimatedWeightKg'] == null
                        ? 'Weight to confirm'
                        : '${data['estimatedWeightKg']} kg'),
                _DispatchRouteFact(
                    icon: Icons.calendar_month_outlined,
                    label: 'Requested trucking date',
                    value: truckingDate == null
                        ? 'Date to confirm'
                        : '${truckingDate.year}-${truckingDate.month.toString().padLeft(2, '0')}-${truckingDate.day.toString().padLeft(2, '0')}'),
                _DispatchRouteFact(
                    icon: Icons.request_quote_outlined,
                    label: 'Carrier bids',
                    value: '${data['bidCount'] ?? 0} submitted'),
              ]))),
      if ('${data['loadDetails'] ?? ''}'.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('Load details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('${data['loadDetails']}'),
      ],
      if (!const {'draft', 'open'}.contains(status)) ...[
        const SizedBox(height: 14),
        MarketplaceDispatchTransactionCard(
            jobId: document.id, job: data, repository: repository),
      ],
      const SizedBox(height: 18),
      FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Dispatch')),
                  body: const MarketplaceDispatchPage()))),
          icon: const Icon(Icons.dashboard_outlined),
          label: Text(
              owner ? 'Open Dispatch management' : 'Open Dispatch to quote')),
      const SizedBox(height: 8),
      const Text(
          'Exact private locations and participant-only transaction details remain protected by account access.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFF66758A))),
    ]);
  }
}

class _DispatchRouteFact extends StatelessWidget {
  const _DispatchRouteFact(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: const Color(0xFF0878E8)),
          const SizedBox(width: 10),
          SizedBox(
              width: 116,
              child: Text(label,
                  style: const TextStyle(
                      color: Color(0xFF66758A), fontWeight: FontWeight.w700))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
      );
}

class MarketplaceDispatchPage extends StatefulWidget {
  const MarketplaceDispatchPage({super.key});
  @override
  State<MarketplaceDispatchPage> createState() =>
      _MarketplaceDispatchPageState();
}

class _MarketplaceDispatchPageState extends State<MarketplaceDispatchPage> {
  final repo = MarketplaceDispatchRepository();
  DispatchSection section = DispatchSection.dashboard;

  Future<void> _openProviderAccount(
    DispatchAccountState accountState,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(
              accountState.providerRegistered
                  ? 'Dispatch company profile'
                  : 'Join Pipe Buyer Dispatch',
            ),
          ),
          body: accountState.providerRegistered
              ? const MarketplaceDispatchCompanyProfilePage()
              : _CarrierEnrollment(repo: repo),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => section = DispatchSection.dashboard);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting &&
              !authSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (authSnapshot.data == null) {
            return const Center(child: Text('Sign in to use Dispatch.'));
          }
          return _buildAuthenticatedDispatch(context);
        },
      );

  Widget _buildAuthenticatedDispatch(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: repo.carrierProfile(),
      builder: (context, profile) {
        if (profile.connectionState == ConnectionState.waiting &&
            !profile.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (profile.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 42,
                    color: Color(0xFFB42318),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Dispatch account state could not be loaded.',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Check the connection and reload Dispatch before changing provider settings.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Reload Dispatch'),
                  ),
                ],
              ),
            ),
          );
        }

        final accountState = DispatchAccountState.fromCarrierProfile(
          exists: profile.data?.exists == true,
          data: profile.data?.data(),
        );

        final content = switch (section) {
          DispatchSection.dashboard => accountState.providerRegistered
              ? MarketplaceDispatchDashboard(
                  repo: repo,
                  onPostLoad: () =>
                      setState(() => section = DispatchSection.requestService),
                  onBrowseJobs: () =>
                      setState(() => section = DispatchSection.jobs),
                  onJoinCarrier: () => _openProviderAccount(accountState),
                )
              : MarketplaceDispatchCustomerHome(
                  onRequestService: () =>
                      setState(() => section = DispatchSection.requestService),
                  onBrowseDirectory: () =>
                      setState(() => section = DispatchSection.directory),
                  onBrowseJobs: () =>
                      setState(() => section = DispatchSection.jobs),
                  onListBusiness: () => _openProviderAccount(accountState),
                ),
          DispatchSection.requestService => _PostJob(repo: repo),
          DispatchSection.directory => MarketplaceDispatchDirectoryFoundation(
              accountState: accountState,
              legacyProviderTools: accountState.providerRegistered
                  ? _PilotTruckSection(repo: repo)
                  : null,
            ),
          DispatchSection.jobs => _JobBoard(repo: repo),
        };

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dispatch',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Industrial service requests, provider network and job opportunities.',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      IndustrialAssetIcon(
                        label: 'Dispatch load board',
                        assetPath: IndustrialIconAssets.dispatchLoadBoard,
                        size: 62,
                        borderRadius: 12,
                        fallback: Icon(
                          Icons.local_shipping_outlined,
                          size: 42,
                          color: Color(0xFF0878E8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MarketplaceDispatchNavigation(
                    selected: section,
                    accountState: accountState,
                    onSelected: (value) => setState(() => section = value),
                    onProviderAction: () => _openProviderAccount(accountState),
                  ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

class _PilotTruckSection extends StatelessWidget {
  const _PilotTruckSection({required this.repo});
  final MarketplaceDispatchRepository repo;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Pilot Truck Services',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Find or provide pilot and escort support for oversize and specialized loads.',
          ),
          const SizedBox(height: 12),
          const Card(
            color: Color(0xFFFFF4E5),
            child: ListTile(
              leading: Icon(Icons.warning_amber_outlined),
              title: Text('Job-specific requirements'),
              subtitle: Text(
                'Permit, signage, lighting and escort requirements vary by route and jurisdiction. Confirm requirements before accepting work.',
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'My pilot vehicles',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: repo.fleet(),
            builder: (context, snapshot) {
              final pilots = (snapshot.data?.docs ?? [])
                  .where(
                    (doc) =>
                        doc.data()['pilotTruck'] == true ||
                        List<String>.from(
                          doc.data()['services'] ?? const <String>[],
                        ).contains('Pilot / escort'),
                  )
                  .toList();
              if (pilots.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IndustrialAssetIcon(
                          label: 'Pilot truck',
                          assetPath: IndustrialIconAssets.pilotCar,
                          size: 64,
                          fallback: Icon(
                            Icons.assistant_direction_outlined,
                            size: 38,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No pilot truck added',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              Text(
                                'Open Company Profile, add a truck, and enable Pilot / escort services.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: pilots
                    .map(
                      (doc) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.assistant_direction_outlined),
                          ),
                          title: Text(
                            '${doc.data()['name'] ?? 'Pilot truck'}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${doc.data()['vehicleType'] ?? 'Pilot truck'} • Available for escort work',
                          ),
                          trailing: const Chip(label: Text('PILOT')),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      );
}

class _JobBoard extends StatefulWidget {
  const _JobBoard({required this.repo});
  final MarketplaceDispatchRepository repo;

  @override
  State<_JobBoard> createState() => _JobBoardState();
}

class _JobBoardState extends State<_JobBoard> {
  MarketplaceDispatchRepository get repo => widget.repo;
  late Future<({int jobs, int bids})> _activityCounts;

  @override
  void initState() {
    super.initState();
    _refreshActivityCounts();
  }

  void _refreshActivityCounts() {
    _activityCounts = Future.wait([
      repo.myJobCount(),
      repo.myBidCount(),
    ]).then((counts) => (jobs: counts[0], bids: counts[1]));
  }

  Future<void> _refreshBoard() async {
    setState(_refreshActivityCounts);
    try {
      await _activityCounts;
    } catch (_) {
      // The activity cards render their unavailable state independently.
    }
  }

  Future<void> _copyJobLink(String jobId) async {
    final target = MarketplaceDeepLinks.shareTarget(
        MarketplaceDeepLinks.dispatchJob(jobId));
    await Clipboard.setData(ClipboardData(text: target));
    if (!mounted) return;
    PipeFeedback.show(
      context,
      message: target.startsWith('http')
          ? 'Dispatch job link copied.'
          : 'Dispatch app route copied.',
      tone: PipeStatusTone.success,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _myDispatchActivity(context),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Open carrier jobs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Expanded(
            child: _DispatchPagedCollection(
              query: repo.openJobsQuery,
              onRefresh: _refreshBoard,
              empty: const _DispatchEmptyState(
                icon: Icons.local_shipping_outlined,
                title: 'No open trucking jobs yet.',
                message: 'New loads will appear here for carrier bidding.',
              ),
              itemBuilder: (context, job) {
                final data = job.data();
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.local_shipping_outlined),
                    ),
                    title: Text(
                      '${data['title'] ?? 'Dispatch load'}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${data['pickupLabel'] ?? ''} → ${data['deliveryLabel'] ?? ''}\n${dispatchDistanceLabel(data)} • ${data['estimatedWeightKg'] == null ? 'Weight to confirm' : '${data['estimatedWeightKg']} kg estimated'}\n${data['bidCount'] ?? 0} carrier bids',
                    ),
                    isThreeLine: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          tooltip: 'Copy job link',
                          onPressed: () => _copyJobLink(job.id),
                          icon: const Icon(Icons.share_outlined)),
                      const Icon(Icons.chevron_right),
                    ]),
                    onTap: () => data['createdByUid'] ==
                            FirebaseAuth.instance.currentUser?.uid
                        ? _showJobManager(context, job)
                        : _openCarrierJob(context, job),
                  ),
                );
              },
            ),
          ),
        ],
      );

  Widget _myDispatchActivity(BuildContext context) =>
      FutureBuilder<({int jobs, int bids})>(
        future: _activityCounts,
        builder: (context, counts) => Container(
          color: const Color(0xFFEAF4FD),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: _activityCard(
                  icon: Icons.route_outlined,
                  title: 'My requests',
                  count: counts.hasError ? -1 : counts.data?.jobs,
                  onTap: () => _showMyRequests(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _activityCard(
                  icon: Icons.request_quote_outlined,
                  title: 'My carrier quotes',
                  count: counts.hasError ? -1 : counts.data?.bids,
                  onTap: () => _showMyQuotes(context),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _activityCard({
    required IconData icon,
    required String title,
    required int? count,
    required VoidCallback onTap,
  }) =>
      Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          leading: Icon(icon, color: const Color(0xFF0878E8)),
          title: Text(
            title,
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            count == null
                ? 'Loading…'
                : count < 0
                    ? 'Unavailable'
                    : '$count total',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );

  Future<void> _showMyRequests(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .78,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.route_outlined),
                title: const Text(
                  'My Dispatch request history',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('Open, awarded and completed requests'),
                trailing: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: _DispatchPagedCollection(
                  query: repo.myJobsQuery,
                  padding: const EdgeInsets.all(12),
                  empty: const _DispatchEmptyState(
                    icon: Icons.route_outlined,
                    title: 'No Dispatch requests yet.',
                    message: 'Requests you publish will appear here.',
                  ),
                  itemBuilder: (_, job) {
                    final data = job.data();
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.local_shipping_outlined),
                        ),
                        title: Text(
                          '${data['title'] ?? 'Dispatch request'}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${data['pickupLabel'] ?? ''} → ${data['deliveryLabel'] ?? ''}\n${dispatchDistanceLabel(data)} • ${('${data['status'] ?? 'open'}').toUpperCase()}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _showJobManager(context, job);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMyQuotes(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .78,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.request_quote_outlined),
                title: const Text(
                  'My carrier quote history',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('Pending, awarded and archived quotes'),
                trailing: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: _DispatchPagedCollection(
                  query: repo.myBidsQuery,
                  padding: const EdgeInsets.all(12),
                  empty: const _DispatchEmptyState(
                    icon: Icons.request_quote_outlined,
                    title: 'No carrier quotes submitted yet.',
                    message: 'Quotes you submit will appear here.',
                  ),
                  itemBuilder: (_, bid) {
                    final data = bid.data();
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.request_quote_outlined),
                        ),
                        title: Text(
                          marketplaceMoney(data['amount'] as num? ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${data['vehicleName'] ?? 'Fleet vehicle'} • ${('${data['status'] ?? 'pending'}').toUpperCase()}\n${data['note'] ?? ''}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final job = await FirebaseFirestore.instance
                              .collection('dispatch_jobs')
                              .doc('${data['jobId']}')
                              .get();
                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext);
                          if (job.exists && context.mounted) {
                            _showCarrierQuote(context, job, bid);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showJobManager(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> job,
  ) async {
    final data = job.data() ?? const <String, dynamic>{};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const IndustrialAssetIcon(
                    label: 'Dispatch load board',
                    assetPath: IndustrialIconAssets.dispatchLoadBoard,
                    size: 52,
                    fallback: Icon(Icons.local_shipping_outlined, size: 34),
                  ),
                  title: Text(
                    '${data['title'] ?? 'Dispatch request'}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    '${data['pickupLabel'] ?? ''} → ${data['deliveryLabel'] ?? ''}\n${dispatchDistanceLabel(data)} • ${('${data['status'] ?? 'open'}').toUpperCase()}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ),
                const Divider(),
                if (!const {'draft', 'open'}.contains(data['status'])) ...[
                  MarketplaceDispatchTransactionCard(
                    jobId: job.id,
                    job: data,
                    repository: repo,
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: ['draft', 'open'].contains(data['status'])
                            ? () {
                                Navigator.pop(sheetContext);
                                _editJob(context, job);
                              }
                            : null,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit request'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _showJobHistory(context, job.id, data);
                        },
                        icon: const Icon(Icons.history_outlined),
                        label: const Text('History'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _showBids(context, job.id);
                  },
                  icon: const Icon(Icons.request_quote_outlined),
                  label: Text('View carrier bids (${data['bidCount'] ?? 0})'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editJob(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> job,
  ) async {
    final data = job.data() ?? const <String, dynamic>{};
    final title = TextEditingController(text: '${data['title'] ?? ''}');
    final pickup = TextEditingController(text: '${data['pickupLabel'] ?? ''}');
    final delivery = TextEditingController(
      text: '${data['deliveryLabel'] ?? ''}',
    );
    final details = TextEditingController(text: '${data['loadDetails'] ?? ''}');
    final weight = TextEditingController(
      text: data['estimatedWeightKg'] == null
          ? ''
          : '${data['estimatedWeightKg']}',
    );
    var date = (data['truckingDate'] as Timestamp?)?.toDate() ??
        DateTime.now().add(const Duration(days: 1));
    final saved = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: const Text('Edit Dispatch request'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: title,
                        decoration: const InputDecoration(
                          labelText: 'Job title *',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                      ),
                      TextField(
                        controller: pickup,
                        decoration: const InputDecoration(
                          labelText: 'Pickup *',
                          prefixIcon: Icon(Icons.trip_origin),
                        ),
                      ),
                      TextField(
                        controller: delivery,
                        decoration: const InputDecoration(
                          labelText: 'Delivery *',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Route calculation',
                                prefixIcon: Icon(Icons.route_outlined),
                              ),
                              child: Text(dispatchDistanceLabel(data)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: weight,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Estimated weight',
                                suffixText: 'kg',
                                prefixIcon: Icon(Icons.scale_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_month_outlined),
                        title: const Text('Requested trucking date'),
                        subtitle: Text(
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                        ),
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: dialogContext,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 730),
                            ),
                            initialDate: date.isBefore(DateTime.now())
                                ? DateTime.now()
                                : date,
                          );
                          if (selected != null) {
                            update(() => date = selected);
                          }
                        },
                      ),
                      TextField(
                        controller: details,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Load details *',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save changes'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!saved) return;
    if ([
      title,
      pickup,
      delivery,
      details,
    ].any((controller) => controller.text.trim().isEmpty)) {
      if (context.mounted) {
        PipeFeedback.show(
          context,
          message: 'Complete all required job fields.',
          tone: PipeStatusTone.warning,
        );
      }
      return;
    }
    try {
      await repo.updateJob(
        jobId: job.id,
        title: title.text,
        pickup: pickup.text,
        delivery: delivery.text,
        truckingDate: date,
        loadDetails: details.text,
        estimatedWeightKg: num.tryParse(weight.text),
      );
      if (context.mounted) {
        PipeFeedback.show(
          context,
          message: 'Dispatch request updated. Revision saved.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The Dispatch request could not be updated.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    }
  }

  Future<void> _showJobHistory(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
  ) async {
    await _showRevisionHistory(
      context: context,
      title: '${job['title'] ?? 'Dispatch request'} history',
      query: () => repo.jobHistoryQuery(jobId),
      amountLabel: null,
    );
  }

  Future<void> _showBids(BuildContext context, String jobId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .82,
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.local_shipping_outlined),
                title: Text(
                  'Carrier bids',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              Expanded(
                child: _DispatchPagedCollection(
                  query: () => repo.bidsForJobQuery(jobId),
                  empty: const _DispatchEmptyState(
                    icon: Icons.request_quote_outlined,
                    title: 'No carrier bids yet.',
                    message: 'Carrier quotes will appear here as they arrive.',
                  ),
                  itemBuilder: (_, bid) {
                    final data = bid.data();
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        title: Text(
                          '${data['carrierName'] ?? 'Carrier'} • ${marketplaceMoney(data['amount'] as num? ?? 0)}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${data['vehicleName'] ?? 'Fleet vehicle'} • ${('${data['status'] ?? 'pending'}').toUpperCase()} • ${data['revision'] ?? 1} revision(s)\n${data['note'] ?? ''}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Quote history',
                              onPressed: () => _showRevisionHistory(
                                context: sheetContext,
                                title:
                                    '${data['carrierName'] ?? 'Carrier'} quote history',
                                query: () => repo.bidHistoryQuery(bid.id),
                                amountLabel: 'Quoted total',
                              ),
                              icon: const Icon(Icons.history_outlined),
                            ),
                            if (data['status'] == 'pending')
                              FilledButton(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                        context: sheetContext,
                                        builder: (dialogContext) => AlertDialog(
                                          title: const Text(
                                            'Select this carrier?',
                                          ),
                                          content: const Text(
                                            'The carrier will be notified and this dispatch job will close to new bids.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                false,
                                              ),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                true,
                                              ),
                                              child: const Text('Award job'),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;
                                  if (!confirmed) return;
                                  await repo.awardBid(
                                    jobId: jobId,
                                    bidId: bid.id,
                                    carrierUid: '${data['carrierUid']}',
                                    amount: data['amount'] as num,
                                  );
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                },
                                child: const Text('Select'),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCarrierJob(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> job,
  ) async {
    final existing = await repo.myBidForJob(job.id);
    if (!context.mounted) return;
    if (existing == null) {
      await _bid(context, job.id, job.data());
      return;
    }
    await _showCarrierQuote(context, job, existing);
  }

  Future<void> _showCarrierQuote(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> job,
    QueryDocumentSnapshot<Map<String, dynamic>> bid,
  ) async {
    final jobData = job.data() ?? const <String, dynamic>{};
    final data = bid.data();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.request_quote_outlined,
                    color: Color(0xFF0878E8),
                    size: 36,
                  ),
                  title: const Text(
                    'Your carrier quote',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${jobData['title'] ?? 'Dispatch job'}\n${dispatchDistanceLabel(jobData)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Card(
                  color: const Color(0xFFEAF4FD),
                  child: ListTile(
                    title: Text(
                      marketplaceMoney(data['amount'] as num? ?? 0),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text(
                      '${data['vehicleName'] ?? 'Fleet vehicle'} • ${('${data['status'] ?? 'pending'}').toUpperCase()}\n${data['note'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: Chip(label: Text('REV ${data['revision'] ?? 1}')),
                  ),
                ),
                if (data['status'] == 'awarded' ||
                    !const {'draft', 'open'}.contains(jobData['status'])) ...[
                  const SizedBox(height: 8),
                  MarketplaceDispatchTransactionCard(
                    jobId: job.id,
                    job: jobData,
                    repository: repo,
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: data['status'] == 'pending' &&
                                jobData['status'] == 'open'
                            ? () {
                                Navigator.pop(sheetContext);
                                _bid(context, job.id, jobData, existing: bid);
                              }
                            : null,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit quote'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _showRevisionHistory(
                            context: context,
                            title: 'Carrier quote history',
                            query: () => repo.bidHistoryQuery(bid.id),
                            amountLabel: 'Quoted total',
                          );
                        },
                        icon: const Icon(Icons.history_outlined),
                        label: const Text('History'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRevisionHistory({
    required BuildContext context,
    required String title,
    required Query<Map<String, dynamic>> Function() query,
    required String? amountLabel,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: const Text('Permanent activity and revision history'),
                trailing: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: _DispatchPagedCollection(
                  query: query,
                  padding: const EdgeInsets.all(12),
                  empty: const _DispatchEmptyState(
                    icon: Icons.history_outlined,
                    title: 'No history recorded yet.',
                    message: 'Permanent revisions will appear here.',
                  ),
                  itemBuilder: (_, revision) {
                    final data = revision.data();
                    final amount = data['amount'] as num?;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${data['revision'] ?? '—'}'),
                        ),
                        title: Text(
                          amountLabel != null && amount != null
                              ? '$amountLabel • ${marketplaceMoney(amount)}'
                              : _dispatchEventLabel(
                                  '${data['event'] ?? 'updated'}',
                                ),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${_dispatchEventLabel('${data['event'] ?? 'updated'}')} • ${('${data['status'] ?? ''}').toUpperCase()}\n${_dispatchDateLabel(data)}${('${data['note'] ?? ''}').trim().isEmpty ? '' : '\n${data['note']}'}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _bid(
    BuildContext context,
    String id,
    Map<String, dynamic> data, {
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final fleet = await FirebaseFirestore.instance
        .collection('dispatch_carriers')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .collection('vehicles')
        .limit(100)
        .get();
    if (fleet.docs.isEmpty) {
      if (context.mounted) {
        PipeFeedback.show(
          context,
          message:
              'Create your Dispatch account and add a fleet vehicle before bidding.',
          tone: PipeStatusTone.warning,
        );
      }
      return;
    }
    final existingData = existing?.data();
    var selectedVehicle = fleet.docs
            .where((vehicle) => vehicle.id == existingData?['vehicleId'])
            .firstOrNull ??
        fleet.docs.first;
    final amount = TextEditingController(
      text: '${existingData?['amount'] ?? ''}',
    );
    final note = TextEditingController(text: '${existingData?['note'] ?? ''}');
    var date = (existingData?['availableDate'] as Timestamp?)?.toDate() ??
        (data['truckingDate'] as Timestamp?)?.toDate() ??
        DateTime.now();
    if (!context.mounted) return;
    final submit = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: Text(
                existing == null ? 'Bid on trucking job' : 'Edit carrier quote',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'All-in transport price',
                      prefixText: r'$ ',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: selectedVehicle.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Truck assigned to this bid',
                    ),
                    items: fleet.docs.map((vehicle) {
                      final vehicleData = vehicle.data();
                      final vehicleType =
                          '${vehicleData['vehicleType'] ?? 'Truck'}';
                      return DropdownMenuItem(
                        value: vehicle.id,
                        child: MarketplaceFormOption(
                          label: '${vehicleData['name'] ?? 'Fleet vehicle'}',
                          subtitle:
                              '$vehicleType • ${vehicleData['maximumPayloadKg'] ?? 0} kg payload',
                          icon: _vehicleTypeFallbackIcon(vehicleType),
                          assetPath: IndustrialIconAssets.forVehicleType(
                            vehicleType,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      selectedVehicle = fleet.docs.firstWhere(
                        (vehicle) => vehicle.id == value,
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Carrier available date'),
                    subtitle: Text(
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                    ),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                        initialDate: date.isBefore(DateTime.now())
                            ? DateTime.now()
                            : date,
                      );
                      if (selected != null) {
                        update(() => date = selected);
                      }
                    },
                  ),
                  TextField(
                    controller: note,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Equipment, timing and terms',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(
                    existing == null ? 'Review bid' : 'Review changes',
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!submit || !context.mounted) return;
    final value = num.tryParse(amount.text);
    if (value == null || value <= 0) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              existing == null
                  ? 'Submit carrier bid?'
                  : 'Save revised carrier quote?',
            ),
            content: Text(
              '${marketplaceMoney(value)} all-in. The job owner will see your carrier profile, terms, and revision history.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Go back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(existing == null ? 'Submit bid' : 'Save quote'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      try {
        await repo.bid(
          jobId: id,
          amount: value,
          note: note.text.trim(),
          availableDate: date,
          vehicleId: selectedVehicle.id,
          vehicleName: '${selectedVehicle.data()['name'] ?? 'Fleet vehicle'}',
        );
        if (context.mounted) {
          PipeFeedback.show(
            context,
            message: existing == null
                ? 'Carrier quote submitted.'
                : 'Carrier quote updated. Revision saved.',
            tone: PipeStatusTone.success,
          );
        }
      } catch (error) {
        if (context.mounted) {
          PipeFeedback.show(
            context,
            message: marketplaceCommandErrorMessage(
              error,
              fallback: 'The carrier quote could not be saved.',
            ),
            tone: PipeStatusTone.error,
          );
        }
      }
    }
  }
}

typedef _DispatchDocumentBuilder = Widget Function(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> document,
);

class _DispatchPagedCollection extends StatefulWidget {
  const _DispatchPagedCollection({
    required this.query,
    required this.itemBuilder,
    required this.empty,
    this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(14, 4, 14, 20),
  });

  final Query<Map<String, dynamic>> Function() query;
  final _DispatchDocumentBuilder itemBuilder;
  final Widget empty;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;

  @override
  State<_DispatchPagedCollection> createState() =>
      _DispatchPagedCollectionState();
}

class _DispatchPagedCollectionState extends State<_DispatchPagedCollection> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _documents = [];
  final Set<String> _firstPageIds = {};
  QueryDocumentSnapshot<Map<String, dynamic>>? _cursor;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firstPage;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _listenToFirstPage();
  }

  void _listenToFirstPage() {
    _loading = true;
    _firstPage =
        widget.query().limit(defaultFirestorePageSize).snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        final tail = _documents
            .where((document) => !_firstPageIds.contains(document.id))
            .toList();
        final merged = appendUniqueById(
          snapshot.docs,
          tail,
          (document) => document.id,
        );
        setState(() {
          _documents
            ..clear()
            ..addAll(merged);
          _firstPageIds
            ..clear()
            ..addAll(snapshot.docs.map((document) => document.id));
          if (tail.isEmpty) _cursor = snapshot.docs.lastOrNull;
          _hasMore = tail.isNotEmpty ||
              snapshot.docs.length == defaultFirestorePageSize;
          _loading = false;
          _error = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = error is FirebaseException &&
                  error.code == 'failed-precondition'
              ? 'The Dispatch index is still being prepared. Try again shortly.'
              : 'Dispatch records could not be loaded. Check your connection.';
        });
      },
    );
  }

  @override
  void dispose() {
    _firstPage?.cancel();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if ((_loading && !reset) || (!reset && !_hasMore)) return;
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _documents.clear();
        _cursor = null;
        _hasMore = true;
      }
    });
    try {
      final page = await loadFirestoreDocumentPage(
        widget.query(),
        after: reset ? null : _cursor,
      );
      if (!mounted || generation != _generation) return;
      final merged = appendUniqueById(
        reset
            ? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]
            : _documents,
        page.documents,
        (document) => document.id,
      );
      setState(() {
        _documents
          ..clear()
          ..addAll(merged);
        if (reset) {
          _firstPageIds
            ..clear()
            ..addAll(page.documents.map((document) => document.id));
        }
        _cursor = page.cursor;
        _hasMore = page.hasMore;
      });
    } on FirebaseException catch (error) {
      if (!mounted || generation != _generation) return;
      setState(
        () => _error = error.code == 'failed-precondition'
            ? 'The Dispatch index is still being prepared. Try again shortly.'
            : 'Dispatch records could not be loaded. Check your connection.',
      );
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'Dispatch records could not be loaded. Check your connection.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refresh() async {
    await _load(reset: true);
    await widget.onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _documents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _documents.isEmpty) {
      return _DispatchQueryError(error: _error!, onRetry: _refresh);
    }
    if (_documents.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: 420, child: Center(child: widget.empty))],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: _documents.length + 1,
        itemBuilder: (context, index) {
          if (index < _documents.length) {
            return widget.itemBuilder(context, _documents[index]);
          }
          if (_error != null) {
            return _DispatchQueryError(
              error: _error!,
              onRetry: () => _load(),
              compact: true,
            );
          }
          if (_hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: FilledButton.tonalIcon(
                  onPressed: _loading ? null : () => _load(),
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: const Text('Load more'),
                ),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                'All records loaded.',
                style: TextStyle(color: Color(0xFF66758A)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DispatchQueryError extends StatelessWidget {
  const _DispatchQueryError({
    required this.error,
    required this.onRetry,
    this.compact = false,
  });

  final String error;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) => MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.error,
        title: 'Dispatch records could not be loaded',
        message: error,
        primaryLabel: 'Try again',
        onPrimary: onRetry,
        compact: compact,
      );
}

class _DispatchEmptyState extends StatelessWidget {
  const _DispatchEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.empty,
        icon: icon,
        title: title,
        message: message,
        compact: true,
      );
}

class _PostJob extends StatefulWidget {
  const _PostJob({required this.repo});
  final MarketplaceDispatchRepository repo;
  @override
  State<_PostJob> createState() => _PostJobState();
}

class _PostJobState extends State<_PostJob> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final pickup = TextEditingController();
  final delivery = TextEditingController();
  final details = TextEditingController();
  MarketplaceLocation? pickupLocation;
  MarketplaceLocation? deliveryLocation;
  DateTime date = DateTime.now().add(const Duration(days: 1));
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Post a trucking job',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Only operational details are shared. Private offer and payment information stays protected.',
          ),
          const SizedBox(height: 14),
          Card(
            color: const Color(0xFFEAF4FD),
            child: ListTile(
              leading:
                  const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
              title: const Text(
                'Select a listing for quote',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'Use the listing details and weight estimate to prepare the load.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectListing,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'OR ENTER A LOAD MANUALLY',
                    style: TextStyle(fontSize: 11, color: Color(0xFF66758A)),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),
          Form(
            key: form,
            child: Column(
              children: [
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Load title *',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a load title'
                      : null,
                ),
                const SizedBox(height: 10),
                _MappedJobLocationField(
                  title: 'Pickup location',
                  helper:
                      'Pin the exact loading point. Carriers see the broad area until awarded.',
                  icon: Icons.trip_origin,
                  value: pickupLocation,
                  onTap: _choosePickup,
                ),
                const SizedBox(height: 10),
                _MappedJobLocationField(
                  title: 'Delivery location',
                  helper:
                      'Pin the delivery entrance and add access notes for the awarded carrier.',
                  icon: Icons.flag_outlined,
                  value: deliveryLocation,
                  onTap: _chooseDelivery,
                ),
                const SizedBox(height: 10),
                const Card(
                  color: Color(0xFFEAF4FD),
                  child: ListTile(
                    leading: Icon(Icons.route_outlined),
                    title: Text('Truck-route distance is calculated for you'),
                    subtitle: Text(
                      'Pipe Buyer records a server estimate now and will replace it with a reviewed truck route when routing is available.',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: details,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Load, dimensions and equipment needed *',
                    prefixIcon: Icon(Icons.straighten_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Requested trucking date'),
                  subtitle: Text('${date.year}-${date.month}-${date.day}'),
                  onTap: () async {
                    final value = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate: date,
                    );
                    if (value != null) setState(() => date = value);
                  },
                ),
                FilledButton.icon(
                  onPressed: () async {
                    if (!form.currentState!.validate()) return;
                    if (pickupLocation == null || deliveryLocation == null) {
                      PipeFeedback.show(
                        context,
                        message: 'Select mapped pickup and delivery locations.',
                        tone: PipeStatusTone.warning,
                      );
                      return;
                    }
                    try {
                      await widget.repo.createJob(
                        title: title.text.trim(),
                        pickup: pickup.text.trim(),
                        delivery: delivery.text.trim(),
                        truckingDate: date,
                        loadDetails: details.text.trim(),
                        pickupGeoPoint: pickupLocation!.exactGeoPoint,
                        deliveryLocation: deliveryLocation,
                      );
                      if (context.mounted) {
                        PipeFeedback.show(
                          context,
                          message: 'Dispatch job published for carrier bids.',
                          tone: PipeStatusTone.success,
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        PipeFeedback.show(
                          context,
                          message: marketplaceCommandErrorMessage(
                            error,
                            fallback:
                                'The Dispatch job could not be published.',
                          ),
                          tone: PipeStatusTone.error,
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.publish_outlined),
                  label: const Text('Publish dispatch job'),
                ),
              ],
            ),
          ),
        ],
      );

  Future<void> _choosePickup() async {
    final selected = await MarketplaceLocationPicker.show(
      context,
      pickupLocation,
      title: 'Pickup location',
    );
    if (selected == null || !mounted) return;
    setState(() {
      pickupLocation = selected;
      pickup.text = selected.publicName.trim().isNotEmpty
          ? selected.publicName.trim()
          : selected.nearestTown.trim();
    });
  }

  Future<void> _chooseDelivery() async {
    final selected = await MarketplaceLocationPicker.showDelivery(
      context,
      deliveryLocation,
    );
    if (selected == null || !mounted) return;
    setState(() {
      deliveryLocation = selected;
      delivery.text = selected.publicName.trim().isNotEmpty
          ? selected.publicName.trim()
          : selected.nearestTown.trim();
    });
  }

  Future<void> _selectListing() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    QuerySnapshot<Map<String, dynamic>> result;
    try {
      result = await FirebaseFirestore.instance
          .collection('public_listings')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(
          error,
          fallback:
              'Listings could not be loaded. Check your connection and try again.',
        ),
        tone: PipeStatusTone.error,
      );
      return;
    }
    if (!mounted) return;
    final listings = result.docs;
    if (listings.isEmpty) {
      PipeFeedback.show(
        context,
        message:
            'No eligible listings found. Open any listing and choose Get trucking quote.',
        tone: PipeStatusTone.info,
      );
      return;
    }
    final selected =
        await showModalBottomSheet<QueryDocumentSnapshot<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: const Text(
                  'Choose a listing',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  result.docs.length == 50
                      ? 'Showing the 50 newest active Marketplace and Timed Buying listings'
                      : 'Choose any active Marketplace or Timed Buying listing',
                ),
              ),
              Expanded(
                child: ListView(
                  children: listings
                      .map(
                        (doc) => ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.inventory_2_outlined),
                          ),
                          title: Text(
                            '${doc.data()['title'] ?? 'Listing'}',
                          ),
                          subtitle: Text(
                            '${doc.data()['sellerUid'] == uid ? 'Your listing' : 'Marketplace listing'} • ${doc.data()['category'] ?? ''} • ${doc.data()['publicLocationName'] ?? 'Location by request'}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(sheetContext, doc),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      await MarketplaceFreightQuote.show(
        context,
        listingId: selected.id,
        listing: selected.data(),
        auction: selected.data()['listingChannel'] == 'auction',
      );
    }
  }
}

class _MappedJobLocationField extends StatelessWidget {
  const _MappedJobLocationField({
    required this.title,
    required this.helper,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String helper;
  final IconData icon;
  final MarketplaceLocation? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final location = value;
    final label = location == null
        ? 'Select on map'
        : (location.publicName.trim().isNotEmpty
            ? location.publicName.trim()
            : location.nearestTown.trim());
    return Card(
      margin: EdgeInsets.zero,
      color:
          location == null ? const Color(0xFFF1F5F9) : const Color(0xFFE8F7F1),
      child: ListTile(
        minVerticalPadding: 14,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(
          '$title *',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('$label\n$helper'),
        isThreeLine: true,
        trailing: const Icon(Icons.map_outlined),
        onTap: onTap,
      ),
    );
  }
}

class _CarrierEnrollment extends StatefulWidget {
  const _CarrierEnrollment({required this.repo});
  final MarketplaceDispatchRepository repo;
  @override
  State<_CarrierEnrollment> createState() => _CarrierEnrollmentState();
}

class _CarrierEnrollmentState extends State<_CarrierEnrollment> {
  final form = GlobalKey<FormState>();
  final operating = TextEditingController();
  final legal = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  MarketplaceServiceArea? area;
  bool submitting = false;
  bool editingApplication = false;
  String? signupError;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    email.text = user?.email ?? '';
    phone.text = user?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    operating.dispose();
    legal.dispose();
    phone.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.repo.carrierProfile(),
        builder: (context, snapshot) {
          final signedUp = snapshot.data?.exists == true;
          final carrierData = snapshot.data?.data();
          final storedStatus = '${carrierData?['status'] ?? ''}';
          final effectiveStatus = storedStatus == 'active' &&
                  carrierData?['providerReviewVersion'] != 1
              ? 'review_required'
              : storedStatus;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                signedUp ? 'Dispatch account' : 'List your business',
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const Text(
                'Only the contact and service information needed to connect you with trucking work is collected.',
              ),
              const SizedBox(height: 10),
              const Card(
                color: Color(0xFFEAF4FD),
                child: ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Privacy-minimal provider setup'),
                  subtitle: Text(
                    'Pipe does not request insurance policy details or personal identity documents here.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!signedUp || editingApplication)
                _signupForm()
              else ...[
                _accountSummary(snapshot.data!.data()!),
                _providerReviewHistory(),
                if (const {
                  'changes_requested',
                  'rejected',
                  'suspended',
                  'review_required',
                }.contains(effectiveStatus)) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {
                      final data = snapshot.data!.data()!;
                      operating.text = '${data['operatingName'] ?? ''}';
                      legal.text = '${data['companyName'] ?? ''}';
                      email.text = '${data['email'] ?? ''}';
                      phone.text =
                          '${data['phoneE164'] ?? data['phone'] ?? ''}';
                      final rawArea = data['serviceArea'];
                      if (rawArea is Map) {
                        area = MarketplaceServiceArea.fromMap(
                          Map<String, dynamic>.from(rawArea),
                        );
                      }
                      setState(() => editingApplication = true);
                    },
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Update and resubmit application'),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'My fleet',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _addVehicle,
                      icon: const Icon(Icons.add),
                      label: const Text('Add truck'),
                    ),
                  ],
                ),
                const Text(
                  'Add every truck separately so its payload and services are accurate when bidding.',
                ),
                const SizedBox(height: 10),
                _fleet(),
              ],
            ],
          );
        },
      );

  Widget _signupForm() => Form(
        key: form,
        child: Column(
          children: [
            for (final field in [
              (operating, 'Public operating name', Icons.storefront_outlined),
              (legal, 'Company name', Icons.business_outlined),
              (email, 'Dispatch email', Icons.email_outlined),
            ]) ...[
              TextFormField(
                controller: field.$1,
                readOnly: identical(field.$1, email),
                decoration: InputDecoration(
                  labelText: '${field.$2} *',
                  prefixIcon: Icon(field.$3),
                  helperText: identical(field.$1, email)
                      ? 'Uses the email verified on your Pipe account.'
                      : null,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
            ],
            TextFormField(
              controller: phone,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Verified Dispatch phone *',
                prefixIcon: Icon(Icons.phone_outlined),
                helperText: 'Uses the mobile number verified on your account.',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Verify a mobile number in Account Settings first.'
                  : null,
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: const Color(0xFFF2F6FA),
              leading: const Icon(Icons.map_outlined),
              title: const Text('Area of service *'),
              subtitle: Text(area?.summary ?? 'Select operating area'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final value = await MarketplaceServiceAreaPicker.show(
                  context,
                  area,
                );
                if (value != null) setState(() => area = value);
              },
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!form.currentState!.validate() || area == null) {
                        PipeFeedback.show(
                          context,
                          message:
                              'Complete the business profile and service area.',
                          tone: PipeStatusTone.warning,
                        );
                        return;
                      }
                      setState(() {
                        submitting = true;
                        signupError = null;
                      });
                      try {
                        await widget.repo.signupDispatch(
                          operatingName: operating.text.trim(),
                          companyName: legal.text.trim(),
                          serviceArea: area!,
                        );
                        if (mounted) {
                          setState(() => editingApplication = false);
                          PipeFeedback.show(
                            context,
                            message:
                                'Dispatch application submitted for administrator review.',
                            tone: PipeStatusTone.info,
                          );
                        }
                      } on FirebaseException catch (error) {
                        if (mounted) {
                          setState(
                            () => signupError =
                                'Firebase ${error.code}: ${error.message ?? 'The signup could not be saved.'}',
                          );
                        }
                      } catch (error) {
                        if (mounted) {
                          setState(
                            () => signupError =
                                '$error'.replaceFirst('Bad state: ', ''),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => submitting = false);
                      }
                    },
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                submitting
                    ? 'Submitting Dispatch application…'
                    : 'Submit for review',
              ),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
            ),
            if (signupError != null)
              Card(
                color: const Color(0xFFFFE9E7),
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.red),
                  title:
                      const Text('Dispatch provider setup was not completed'),
                  subtitle: SelectableText(signupError!),
                  trailing: IconButton(
                    tooltip: 'Dismiss',
                    onPressed: () => setState(() => signupError = null),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _accountSummary(Map<String, dynamic> data) {
    final storedStatus = '${data['status'] ?? 'pending_review'}';
    final status =
        storedStatus == 'active' && data['providerReviewVersion'] != 1
            ? 'review_required'
            : storedStatus;
    final statusLabel = switch (status) {
      'active' => 'APPROVED',
      'changes_requested' => 'CHANGES NEEDED',
      'rejected' => 'NOT APPROVED',
      'suspended' => 'SUSPENDED',
      'review_required' => 'REVIEW REQUIRED',
      _ => 'IN REVIEW',
    };
    final statusColor = switch (status) {
      'active' => Colors.green,
      'changes_requested' || 'review_required' => Colors.orange,
      'rejected' || 'suspended' => Colors.red,
      _ => Colors.blue,
    };
    final reason = '${data['reviewReason'] ?? ''}'.trim();
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: .12),
          child: Icon(Icons.business_outlined, color: statusColor),
        ),
        title: Text(
          '${data['operatingName'] ?? 'Dispatch provider'}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${data['companyName'] ?? ''}\n${data['serviceAreaLabel'] ?? ''}'
          '${reason.isEmpty ? '' : '\nReview note: $reason'}',
        ),
        isThreeLine: reason.isNotEmpty,
        trailing: Chip(
          side: BorderSide(color: statusColor),
          label: Text(statusLabel),
        ),
      ),
    );
  }

  Widget _providerReviewHistory() =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.repo.providerReviewHistory(),
        builder: (context, snapshot) {
          final events = snapshot.data?.docs ?? const [];
          return Card(
            child: ExpansionTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('Application history'),
              subtitle: Text('${events.length} recorded event(s)'),
              children: [
                if (snapshot.hasError)
                  const ListTile(
                    title: Text('History could not be loaded.'),
                    subtitle: Text('Check your connection and try again.'),
                  )
                else if (!snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  )
                else
                  ...events.map((event) {
                    final data = event.data();
                    final status = '${data['status'] ?? data['event'] ?? ''}'
                        .replaceAll('_', ' ');
                    return ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: Text(status.toUpperCase()),
                      subtitle:
                          Text('${data['reason'] ?? 'Application submitted'}'),
                    );
                  }),
              ],
            ),
          );
        },
      );

  Widget _fleet() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.repo.fleet(),
        builder: (context, snapshot) {
          final vehicles = snapshot.data?.docs ?? [];
          if (vehicles.isEmpty) {
            return const Card(
              child: ListTile(
                leading: Icon(Icons.add_road_outlined),
                title: Text('Add your first truck'),
                subtitle: Text(
                  'A fleet vehicle is required before bidding on dispatch work.',
                ),
              ),
            );
          }
          return Column(
            children: vehicles.map((vehicle) {
              final data = vehicle.data();
              final services = List<String>.from(
                data['services'] ?? const <String>[],
              );
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: IndustrialAssetIcon(
                          label: '${data['vehicleType'] ?? 'Truck'}',
                          assetPath: IndustrialIconAssets.forVehicleType(
                            '${data['vehicleType'] ?? 'Truck'}',
                          ),
                          size: 42,
                          borderRadius: 10,
                          fallback: Icon(
                            _vehicleTypeFallbackIcon(
                              '${data['vehicleType'] ?? 'Truck'}',
                            ),
                          ),
                        ),
                        title: Text(
                          '${data['name'] ?? 'Fleet vehicle'}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${data['vehicleType'] ?? 'Truck'} • Safe payload ${data['maximumPayloadKg'] ?? 0} kg\nTare ${data['tareWeightKg'] ?? '—'} kg • Gross ${data['grossWeightKg'] ?? '—'} kg',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'remove') {
                              await widget.repo.removeVehicle(vehicle.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'remove',
                              child: MarketplaceFormOption(
                                label: 'Remove truck',
                                icon: Icons.delete_outline,
                                iconColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: services
                              .map(
                                (service) => Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(
                                    _dispatchServiceIcon(service),
                                    size: 17,
                                  ),
                                  label: Text(service),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      );

  Future<void> _addVehicle() async {
    final name = TextEditingController();
    final capacity = TextEditingController();
    final tare = TextEditingController();
    final gross = TextEditingController();
    final notes = TextEditingController();
    var type = 'Truck';
    var pilot = false;
    var usePounds = false;
    var weightSource = 'Vehicle plate / registration';
    final services = <String>{};
    final submitted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (_, setDialogState) => AlertDialog(
              title: const Text('Add fleet vehicle'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Truck name or unit number *',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle type',
                        ),
                        items: const [
                          'Truck',
                          'Pickup',
                          'Tractor',
                          'Hotshot',
                          'Pilot truck',
                        ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: MarketplaceFormOption(
                                  label: value,
                                  icon: _vehicleTypeFallbackIcon(value),
                                  assetPath:
                                      IndustrialIconAssets.forVehicleType(
                                    value,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => type = value ?? type),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Kilograms (kg)'),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Pounds (lb)'),
                          ),
                        ],
                        selected: {usePounds},
                        onSelectionChanged: (value) =>
                            setDialogState(() => usePounds = value.first),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: tare,
                              onChanged: (_) => setDialogState(() {}),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Tare / empty weight *',
                                prefixIcon: const Icon(Icons.scale_outlined),
                                suffixText: usePounds ? 'lb' : 'kg',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: gross,
                              onChanged: (_) => setDialogState(() {}),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Registered gross weight *',
                                prefixIcon: const Icon(
                                  Icons.monitor_weight_outlined,
                                ),
                                suffixText: usePounds ? 'lb' : 'kg',
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextField(
                        controller: capacity,
                        onChanged: (_) => setDialogState(() {}),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Manufacturer rated payload *',
                          prefixIcon: const Icon(Icons.fitness_center),
                          suffixText: usePounds ? 'lb' : 'kg',
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: weightSource,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Weight source',
                        ),
                        items: const [
                          'Vehicle plate / registration',
                          'Manufacturer specification',
                          'Certified scale ticket',
                          'Owner estimate',
                        ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: MarketplaceFormOption(
                                  label: value,
                                  icon: _weightSourceIcon(value),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setDialogState(
                          () => weightSource = value ?? weightSource,
                        ),
                      ),
                      Builder(
                        builder: (_) {
                          final empty = num.tryParse(tare.text) ?? 0;
                          final registered = num.tryParse(gross.text) ?? 0;
                          final rated = num.tryParse(capacity.text) ?? 0;
                          final calculated = (registered - empty).clamp(
                            0,
                            double.infinity,
                          );
                          final safe = calculated > 0 && rated > 0
                              ? calculated < rated
                                  ? calculated
                                  : rated
                              : 0;
                          return Card(
                            color: const Color(0xFFEAF4FD),
                            child: ListTile(
                              leading: const Icon(Icons.scale_outlined),
                              title: Text(
                                'Safe entered payload: ${safe.toStringAsFixed(0)} ${usePounds ? 'lb' : 'kg'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                'Gross − tare = ${calculated.toStringAsFixed(0)}. The lower of calculated and rated payload is used.',
                              ),
                            ),
                          );
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pilot / escort truck services'),
                        subtitle: const Text(
                          'Oversize-load pilot, route and escort support',
                        ),
                        value: pilot,
                        onChanged: (value) => setDialogState(() {
                          pilot = value;
                          if (value) {
                            type = 'Pilot truck';
                            services.add('Pilot / escort');
                          }
                        }),
                      ),
                      const Text(
                        'Services provided',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: _dispatchServices
                            .map(
                              (item) => FilterChip(
                                avatar: Icon(item.icon, size: 18),
                                label: Text(item.name),
                                selected: services.contains(item.name),
                                onSelected: (value) => setDialogState(
                                  () => value
                                      ? services.add(item.name)
                                      : services.remove(item.name),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      if (services.contains('Hazmat qualified'))
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Hazmat capability must only be selected when the driver, vehicle and documentation meet applicable requirements.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                      TextField(
                        controller: notes,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Capabilities or notes (optional)',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Add to fleet'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    final ratedInput = num.tryParse(capacity.text);
    final tareInput = num.tryParse(tare.text);
    final grossInput = num.tryParse(gross.text);
    const poundsToKg = 0.45359237;
    final ratedKg =
        ratedInput == null ? null : ratedInput * (usePounds ? poundsToKg : 1);
    final tareKg =
        tareInput == null ? null : tareInput * (usePounds ? poundsToKg : 1);
    final grossKg =
        grossInput == null ? null : grossInput * (usePounds ? poundsToKg : 1);
    final calculatedKg =
        tareKg == null || grossKg == null ? null : grossKg - tareKg;
    final payload = ratedKg == null || calculatedKg == null
        ? null
        : ratedKg < calculatedKg
            ? ratedKg
            : calculatedKg;
    if (!submitted ||
        name.text.trim().isEmpty ||
        payload == null ||
        payload <= 0 ||
        tareKg == null ||
        tareKg <= 0 ||
        grossKg == null ||
        grossKg <= tareKg ||
        services.isEmpty) {
      if (submitted && mounted) {
        PipeFeedback.show(
          context,
          message:
              'Enter valid tare, registered gross and rated payload weights, then select at least one service.',
          tone: PipeStatusTone.warning,
        );
      }
      return;
    }
    await widget.repo.addVehicle(
      name: name.text.trim(),
      vehicleType: type,
      maximumPayloadKg: payload,
      tareWeightKg: tareKg,
      grossWeightKg: grossKg,
      weightSource: weightSource,
      services: services.toList(),
      pilotTruck: pilot,
      notes: notes.text.trim(),
    );
  }
}
