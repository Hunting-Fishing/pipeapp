import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'marketplace_dispatch_repository.dart';
import 'marketplace_dispatch_distance.dart';
import 'marketplace_money.dart';
import 'marketplace_service_area.dart';
import 'marketplace_freight_quote.dart';
import 'marketplace_dispatch_dashboard.dart';
import 'marketplace_dispatch_transaction.dart';
import 'industrial_icon_assets.dart';
import 'regional_phone_field.dart';

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

class MarketplaceDispatchPage extends StatefulWidget {
  const MarketplaceDispatchPage({super.key});
  @override
  State<MarketplaceDispatchPage> createState() =>
      _MarketplaceDispatchPageState();
}

class _MarketplaceDispatchPageState extends State<MarketplaceDispatchPage> {
  final repo = MarketplaceDispatchRepository();
  int section = 0;

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Center(child: Text('Sign in to use Dispatch.'));
    }
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
                          'Professional trucking services, load opportunities and carrier bids.',
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.dashboard_outlined),
                      label: Text('Dashboard'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.local_shipping_outlined),
                      label: Text('Jobs'),
                    ),
                    ButtonSegment(
                      value: 2,
                      icon: Icon(Icons.add_road_outlined),
                      label: Text('Post'),
                    ),
                    ButtonSegment(
                      value: 3,
                      icon: Icon(Icons.local_shipping_outlined),
                      label: Text('Signup'),
                    ),
                    ButtonSegment(
                      value: 4,
                      icon: Icon(Icons.assistant_direction_outlined),
                      label: Text('Pilot'),
                    ),
                  ],
                  selected: {section},
                  onSelectionChanged: (value) =>
                      setState(() => section = value.first),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: section == 0
              ? MarketplaceDispatchDashboard(repo: repo)
              : section == 1
                  ? _JobBoard(repo: repo)
                  : section == 2
                      ? _PostJob(repo: repo)
                      : section == 3
                          ? _CarrierEnrollment(repo: repo)
                          : _PilotTruckSection(repo: repo),
        ),
      ],
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
                                'Open Signup, add a truck, and enable Pilot / escort services.',
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
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: repo.openJobs(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Dispatch jobs could not load.'));
                }
                final jobs = snapshot.data?.docs ?? [];
                if (jobs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IndustrialAssetIcon(
                          label: 'Dispatch load board',
                          assetPath: IndustrialIconAssets.dispatchLoadBoard,
                          size: 108,
                          fallback: Icon(
                            Icons.local_shipping_outlined,
                            size: 56,
                            color: Color(0xFF0878E8),
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No open trucking jobs yet.',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 4),
                        Text('New loads will appear here for carrier bidding.'),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                  itemCount: jobs.length,
                  itemBuilder: (_, index) {
                    final job = jobs[index];
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
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => data['createdByUid'] ==
                                FirebaseAuth.instance.currentUser?.uid
                            ? _showJobManager(context, job)
                            : _openCarrierJob(context, job),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );

  Widget _myDispatchActivity(BuildContext context) => Container(
        color: const Color(0xFFEAF4FD),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: repo.myJobs(),
                builder: (context, snapshot) => _activityCard(
                  icon: Icons.route_outlined,
                  title: 'My requests',
                  count: snapshot.data?.docs.length ?? 0,
                  onTap: () => _showMyRequests(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: repo.myBids(),
                builder: (context, snapshot) => _activityCard(
                  icon: Icons.request_quote_outlined,
                  title: 'My carrier quotes',
                  count: snapshot.data?.docs.length ?? 0,
                  onTap: () => _showMyQuotes(context),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _activityCard({
    required IconData icon,
    required String title,
    required int count,
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
          subtitle: Text('$count total'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );

  Future<void> _showMyRequests(BuildContext context) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('dispatch_jobs')
        .where(
          'createdByUid',
          isEqualTo: FirebaseAuth.instance.currentUser?.uid,
        )
        .get();
    if (!context.mounted) return;
    final jobs = [...snapshot.docs]..sort(
        (a, b) => _dispatchDate(b.data()).compareTo(_dispatchDate(a.data())),
      );
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
                child: jobs.isEmpty
                    ? const Center(child: Text('No Dispatch requests yet.'))
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: jobs.map((job) {
                          final data = job.data();
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.local_shipping_outlined),
                              ),
                              title: Text(
                                '${data['title'] ?? 'Dispatch request'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
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
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMyQuotes(BuildContext context) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('dispatch_bids')
        .where('carrierUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .get();
    if (!context.mounted) return;
    final bids = [...snapshot.docs]..sort(
        (a, b) => _dispatchDate(b.data()).compareTo(_dispatchDate(a.data())),
      );
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
                child: bids.isEmpty
                    ? const Center(
                        child: Text('No carrier quotes submitted yet.'),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: bids.map((bid) {
                          final data = bid.data();
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.request_quote_outlined),
                              ),
                              title: Text(
                                marketplaceMoney(data['amount'] as num? ?? 0),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
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
                        }).toList(),
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
    final distance = TextEditingController(
      text: data['distanceKm'] == null ? '' : '${data['distanceKm']}',
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
                            child: TextField(
                              controller: distance,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Route distance',
                                suffixText: 'km',
                                prefixIcon: Icon(Icons.route_outlined),
                              ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complete all required job fields.')),
        );
      }
      return;
    }
    await repo.updateJob(
      jobId: job.id,
      title: title.text,
      pickup: pickup.text,
      delivery: delivery.text,
      truckingDate: date,
      loadDetails: details.text,
      estimatedWeightKg: num.tryParse(weight.text),
      distanceKm: num.tryParse(distance.text),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Dispatch request updated. Revision saved.'),
        ),
      );
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
      stream: repo.jobHistory(jobId),
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
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('dispatch_bids')
                .where('jobId', isEqualTo: jobId)
                .snapshots(),
            builder: (_, snapshot) {
              final bids = snapshot.data?.docs ?? [];
              return Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.local_shipping_outlined),
                    title: Text(
                      'Carrier bids',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: bids.isEmpty
                        ? const Center(child: Text('No carrier bids yet.'))
                        : ListView(
                            children: bids.map((bid) {
                              final data = bid.data();
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                child: ListTile(
                                  title: Text(
                                    '${data['carrierName'] ?? 'Carrier'} • ${marketplaceMoney(data['amount'] as num? ?? 0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
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
                                          stream: repo.bidHistory(bid.id),
                                          amountLabel: 'Quoted total',
                                        ),
                                        icon: const Icon(
                                          Icons.history_outlined,
                                        ),
                                      ),
                                      if (data['status'] == 'pending')
                                        FilledButton(
                                          onPressed: () async {
                                            final confirmed =
                                                await showDialog<bool>(
                                                      context: sheetContext,
                                                      builder:
                                                          (dialogContext) =>
                                                              AlertDialog(
                                                        title: const Text(
                                                          'Select this carrier?',
                                                        ),
                                                        content: const Text(
                                                          'The carrier will be notified and this dispatch job will close to new bids.',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                              dialogContext,
                                                              false,
                                                            ),
                                                            child: const Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          FilledButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                              dialogContext,
                                                              true,
                                                            ),
                                                            child: const Text(
                                                              'Award job',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ) ??
                                                    false;
                                            if (!confirmed) {
                                              return;
                                            }
                                            await repo.awardBid(
                                              jobId: jobId,
                                              bidId: bid.id,
                                              carrierUid:
                                                  '${data['carrierUid']}',
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
                            }).toList(),
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
                            stream: repo.bidHistory(bid.id),
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
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required String? amountLabel,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              final revisions = snapshot.data?.docs ?? [];
              return Column(
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
                    subtitle: const Text(
                      'Permanent activity and revision history',
                    ),
                    trailing: IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  Expanded(
                    child: revisions.isEmpty
                        ? const Center(child: Text('No history recorded yet.'))
                        : ListView(
                            padding: const EdgeInsets.all(12),
                            children: revisions.map((revision) {
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_dispatchEventLabel('${data['event'] ?? 'updated'}')} • ${('${data['status'] ?? ''}').toUpperCase()}\n${_dispatchDateLabel(data)}${('${data['note'] ?? ''}').trim().isEmpty ? '' : '\n${data['note']}'}',
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            }).toList(),
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
        .get();
    if (fleet.docs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Create your Dispatch account and add a fleet vehicle before bidding.',
            ),
          ),
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
      await repo.bid(
        jobId: id,
        amount: value,
        note: note.text.trim(),
        availableDate: date,
        vehicleId: selectedVehicle.id,
        vehicleName: '${selectedVehicle.data()['name'] ?? 'Fleet vehicle'}',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              existing == null
                  ? 'Carrier quote submitted.'
                  : 'Carrier quote updated. Revision saved.',
            ),
          ),
        );
      }
    }
  }
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
  final distance = TextEditingController();
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
                for (final field in [
                  (title, 'Load title', Icons.inventory_2_outlined),
                  (pickup, 'Pickup location', Icons.trip_origin),
                  (delivery, 'Delivery location', Icons.flag_outlined),
                ]) ...[
                  TextFormField(
                    controller: field.$1,
                    decoration: InputDecoration(
                      labelText: '${field.$2} *',
                      prefixIcon: Icon(field.$3),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                ],
                TextFormField(
                  controller: distance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Estimated route distance *',
                    helperText:
                        'Enter the practical truck-route distance, not straight-line distance.',
                    suffixText: 'km',
                    prefixIcon: Icon(Icons.route_outlined),
                  ),
                  validator: (value) => (num.tryParse(value ?? '') ?? 0) <= 0
                      ? 'Enter the estimated route distance'
                      : null,
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
                    await widget.repo.createJob(
                      title: title.text.trim(),
                      pickup: pickup.text.trim(),
                      delivery: delivery.text.trim(),
                      truckingDate: date,
                      loadDetails: details.text.trim(),
                      distanceKm: num.parse(distance.text),
                      distanceSource: 'user_entered_route',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Dispatch job published for carrier bids.'),
                        ),
                      );
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Listings could not be loaded. Check your connection and try again.')));
      return;
    }
    if (!mounted) return;
    final listings = result.docs;
    if (listings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No eligible listings found. Open any listing and choose Get trucking quote.',
          ),
        ),
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
                      ? 'Showing the 50 newest active Marketplace and Auction listings'
                      : 'Choose any active Marketplace or Auction listing',
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
  String? signupError;

  @override
  Widget build(
    BuildContext context,
  ) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.repo.carrierProfile(),
        builder: (context, snapshot) {
          final signedUp = snapshot.data?.exists == true;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                signedUp ? 'Dispatch account' : 'Dispatch Signup',
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
                  title: Text('Privacy-minimal signup'),
                  subtitle: Text(
                    'Pipe does not request insurance policy details or personal identity documents here.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!signedUp)
                _signupForm()
              else ...[
                _accountSummary(snapshot.data!.data()!),
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
                decoration: InputDecoration(
                  labelText: '${field.$2} *',
                  prefixIcon: Icon(field.$3),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
            ],
            RegionalPhoneField(
              label: 'Dispatch phone',
              initialValue: phone.text,
              required: true,
              onChanged: (value) => phone.text = value,
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Complete the signup and service area.'),
                          ),
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
                          phone: phone.text.trim(),
                          email: email.text.trim(),
                          serviceArea: area!,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Colors.green,
                              content: Text(
                                'Dispatch account created. Welcome to Dispatch.',
                              ),
                            ),
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
                        if (mounted) setState(() => signupError = '$error');
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
                    ? 'Creating Dispatch account…'
                    : 'Create Dispatch account',
              ),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
            ),
            if (signupError != null)
              Card(
                color: const Color(0xFFFFE9E7),
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.red),
                  title: const Text('Dispatch signup was not completed'),
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

  Widget _accountSummary(Map<String, dynamic> data) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
          title: Text(
            '${data['operatingName'] ?? 'Dispatch provider'}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '${data['companyName'] ?? ''}\n${data['serviceAreaLabel'] ?? ''}',
          ),
          isThreeLine: true,
          trailing: const Chip(label: Text('ACTIVE')),
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter valid tare, registered gross and rated payload weights, then select at least one service.',
            ),
          ),
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
