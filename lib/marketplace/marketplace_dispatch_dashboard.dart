import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_dispatch_repository.dart';
import 'marketplace_dispatch_onboarding.dart';
import 'industrial_icon_assets.dart';
import 'marketplace_location_picker.dart';
import 'marketplace_money.dart';

class MarketplaceDispatchDashboard extends StatefulWidget {
  const MarketplaceDispatchDashboard({
    super.key,
    required this.repo,
    required this.onPostLoad,
    required this.onBrowseJobs,
    required this.onJoinCarrier,
  });

  final MarketplaceDispatchRepository repo;
  final VoidCallback onPostLoad;
  final VoidCallback onBrowseJobs;
  final VoidCallback onJoinCarrier;

  @override
  State<MarketplaceDispatchDashboard> createState() =>
      _MarketplaceDispatchDashboardState();
}

class _MarketplaceDispatchDashboardState
    extends State<MarketplaceDispatchDashboard> {
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: widget.repo.carrierProfile(),
          builder: (context, account) {
            if (account.connectionState == ConnectionState.waiting &&
                !account.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (account.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: PipeBuyerSectionCard(
                      title: 'Dispatch profile unavailable',
                      subtitle: 'Check your connection and reload Dispatch.',
                      leading: const Icon(
                        Icons.cloud_off_outlined,
                        color: PipeBuyerColors.danger,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ),
                  ),
                ),
              );
            }
            if (account.data?.exists != true) {
              return MarketplaceDispatchOnboarding(
                onPostLoad: widget.onPostLoad,
                onBrowseJobs: widget.onBrowseJobs,
                onJoinCarrier: widget.onJoinCarrier,
              );
            }
            final data = account.data!.data()!;
            final serviceArea =
                Map<String, dynamic>.from(data['serviceArea'] ?? const {});
            final center = serviceArea['center'] as GeoPoint?;
            final mapCenter = center == null
                ? const LatLng(55.1707, -118.7947)
                : LatLng(center.latitude, center.longitude);
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
              children: [
                _DispatchDashboardHero(
                  onNewQuote: _newQuote,
                  onBrowseJobs: widget.onBrowseJobs,
                  onPostLoad: widget.onPostLoad,
                ),
                const SizedBox(height: 16),
                _summaryCards(),
                const SizedBox(height: 16),
                _operationsMap(mapCenter),
                const SizedBox(height: 20),
                PipeBuyerPageHeader(
                  eyebrow: 'RATE PLANNING',
                  title: 'Saved lanes & quotes',
                  subtitle:
                      'Reuse regular routes, then update distance, weight, permits and current charges before publishing.',
                  icon: Icons.route_outlined,
                  actions: [
                    FilledButton.icon(
                      onPressed: _newQuote,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New quote'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _savedQuotes(),
              ],
            );
          });

  Widget _summaryCards() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.repo.fleet(),
      builder: (context, fleet) {
        final vehicles = fleet.data?.docs ?? [];
        final pilotCount =
            vehicles.where((doc) => doc.data()['pilotTruck'] == true).length;
        final payload = vehicles.fold<num>(
            0,
            (total, doc) =>
                total + (doc.data()['maximumPayloadKg'] as num? ?? 0));
        return PipeBuyerMetricGrid(
          children: [
            PipeBuyerMetricCard(
              label: 'Fleet units',
              value: '${vehicles.length}',
              icon: Icons.local_shipping_outlined,
              caption: 'Registered carrier equipment',
              tone: PipeBuyerStatusTone.premium,
            ),
            PipeBuyerMetricCard(
              label: 'Pilot trucks',
              value: '$pilotCount',
              icon: Icons.assistant_direction_outlined,
              caption: 'Escort / pilot capacity',
              tone: PipeBuyerStatusTone.info,
            ),
            PipeBuyerMetricCard(
              label: 'Combined payload',
              value: '${payload.toStringAsFixed(0)} kg',
              icon: Icons.scale_outlined,
              caption: 'Declared maximum payload',
              tone: PipeBuyerStatusTone.success,
            ),
          ],
        );
      });

  Widget _operationsMap(LatLng center) => StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('dispatch_scales')
          .where('status', isEqualTo: 'verified')
          .limit(500)
          .snapshots(),
      builder: (context, snapshot) {
        final scales = snapshot.data?.docs ?? [];
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 22,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.ink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const IndustrialAssetIcon(
                        label: 'Dispatch operations map',
                        assetPath: IndustrialIconAssets.routeMap,
                        size: 42,
                        borderRadius: 9,
                        fallback: Icon(
                          Icons.map_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Operations map',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Service region and verified scale locations for route planning.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: .60),
                                ),
                          ),
                        ],
                      ),
                    ),
                    PipeBuyerStatusBadge(
                      label: '${scales.length} scales',
                      icon: Icons.scale_outlined,
                      tone: PipeBuyerStatusTone.info,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 340,
                child: FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: 6),
                  children: [
                    TileLayer(
                      urlTemplate: pipeBuyerTileUrl,
                      userAgentPackageName: 'ca.pipebuyer.marketplace',
                    ),
                    MarkerLayer(
                      markers: scales
                          .where((doc) => doc.data()['point'] is GeoPoint)
                          .map((doc) {
                        final point = doc.data()['point'] as GeoPoint;
                        return Marker(
                          point: LatLng(point.latitude, point.longitude),
                          width: 48,
                          height: 48,
                          child: Tooltip(
                            message:
                                '${doc.data()['name'] ?? 'Verified scale'}',
                            child: const _VerifiedScaleMarker(),
                          ),
                        );
                      }).toList(),
                    ),
                    const SimpleAttributionWidget(
                      source: Text('© OpenStreetMap contributors'),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: .48),
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: PipeBuyerColors.industrialBlue,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${scales.length} verified scales loaded. Confirm current hours, legal access, permits and truck-route restrictions before travel.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.35,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      });

  Widget _savedQuotes() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.repo.savedQuotes(),
      builder: (context, snapshot) {
        final quotes = snapshot.data?.docs ?? [];
        if (quotes.isEmpty) {
          return _EmptySavedLanes(onCreate: _newQuote);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1060
                ? 3
                : constraints.maxWidth >= 680
                    ? 2
                    : 1;
            const gap = 12.0;
            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: quotes.map((quote) {
                final data = quote.data();
                return SizedBox(
                  width: width,
                  child: _SavedLaneCard(
                    data: data,
                    onHistory: () =>
                        _showSavedQuoteHistory(quote.id, data),
                    onOpen: () =>
                        _newQuote(template: data, quoteId: quote.id),
                  ),
                );
              }).toList(),
            );
          },
        );
      });

  Future<void> _newQuote(
      {Map<String, dynamic>? template, String? quoteId}) async {
    await showDialog<void>(
        context: context,
        builder: (_) => _DispatchQuoteDialog(
            repo: widget.repo,
            template: template ?? const {},
            quoteId: quoteId));
  }

  Future<void> _showSavedQuoteHistory(
      String quoteId, Map<String, dynamic> quote) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .76,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.repo.savedQuoteHistory(quoteId),
            builder: (context, snapshot) {
              final revisions = snapshot.data?.docs ?? [];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 10, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: PipeBuyerColors.orangeSoft,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.history_outlined,
                            color: PipeBuyerColors.orangePressed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${quote['name'] ?? 'Saved quote'} history',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                'Every saved pricing revision is retained.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: revisions.isEmpty
                        ? const Center(
                            child: Text('No revisions recorded yet.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: revisions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 9),
                            itemBuilder: (context, index) {
                              final revision = revisions[index];
                              final data = revision.data();
                              final created = data['createdAt'] as Timestamp?;
                              return Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          PipeBuyerColors.orangeSoft,
                                      foregroundColor:
                                          PipeBuyerColors.orangePressed,
                                      child:
                                          Text('${data['revision'] ?? '—'}'),
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            marketplaceMoney(
                                              data['total'] as num? ?? 0,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Text(
                                            '${data['origin'] ?? ''} → ${data['destination'] ?? ''}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${created?.toDate().toLocal() ?? 'Pending timestamp'}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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

class _DispatchDashboardHero extends StatelessWidget {
  const _DispatchDashboardHero({
    required this.onNewQuote,
    required this.onBrowseJobs,
    required this.onPostLoad,
  });

  final VoidCallback onNewQuote;
  final VoidCallback onBrowseJobs;
  final VoidCallback onPostLoad;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 26,
              offset: Offset(0, 11),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -65,
              top: -85,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PipeBuyerColors.orange.withValues(alpha: .08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  final artwork = Container(
                    width: compact ? 112 : 150,
                    height: compact ? 92 : 118,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IndustrialAssetIcon(
                      label: 'Pipe Buyer Dispatch',
                      assetPath: IndustrialIconAssets.semiTruck,
                      size: compact ? 96 : 132,
                      borderRadius: 11,
                      fallback: const Icon(
                        Icons.local_shipping_outlined,
                        color: PipeBuyerColors.orange,
                        size: 56,
                      ),
                    ),
                  );
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PipeBuyerStatusBadge(
                        label: 'DISPATCH OPERATIONS',
                        icon: Icons.route_outlined,
                        tone: PipeBuyerStatusTone.premium,
                      ),
                      const SizedBox(height: 11),
                      const Text(
                        'Dispatch Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Plan rates, lanes, fleet capacity and oilfield freight quotes from one operating workspace.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: onNewQuote,
                            icon: const Icon(Icons.calculate_outlined),
                            label: const Text('New quote'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                            ),
                            onPressed: onBrowseJobs,
                            icon: const Icon(Icons.search_outlined),
                            label: const Text('Browse jobs'),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            onPressed: onPostLoad,
                            icon: const Icon(Icons.add_road_outlined),
                            label: const Text('Post load'),
                          ),
                        ],
                      ),
                    ],
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        artwork,
                        const SizedBox(height: 18),
                        copy,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: copy),
                      const SizedBox(width: 20),
                      artwork,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class _VerifiedScaleMarker extends StatelessWidget {
  const _VerifiedScaleMarker();

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: PipeBuyerColors.ink,
          shape: BoxShape.circle,
          border: Border.all(color: PipeBuyerColors.industrialBlue, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.scale_rounded,
          color: PipeBuyerColors.industrialBlue,
          size: 22,
        ),
      );
}

class _EmptySavedLanes extends StatelessWidget {
  const _EmptySavedLanes({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final artwork = Container(
              width: 86,
              height: 72,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: PipeBuyerColors.ink,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const IndustrialAssetIcon(
                label: 'Saved freight lane',
                assetPath: IndustrialIconAssets.routeMap,
                size: 76,
                borderRadius: 9,
                fallback: Icon(
                  Icons.route_outlined,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            );
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No saved lanes yet',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create a quote and save it for repeat pickup/delivery pairs, then revise rates as conditions change.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Create first quote'),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [artwork, const SizedBox(height: 12), copy],
              );
            }
            return Row(
              children: [
                artwork,
                const SizedBox(width: 15),
                Expanded(child: copy),
              ],
            );
          },
        ),
      );
}

class _SavedLaneCard extends StatelessWidget {
  const _SavedLaneCard({
    required this.data,
    required this.onHistory,
    required this.onOpen,
  });

  final Map<String, dynamic> data;
  final VoidCallback onHistory;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.orangeSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.route_outlined,
                        color: PipeBuyerColors.orangePressed,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${data['name'] ?? 'Saved lane'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: 'View quote history',
                      onPressed: onHistory,
                      icon: const Icon(Icons.history_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${data['origin'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 3),
                  child: Icon(
                    Icons.south_rounded,
                    size: 16,
                    color: PipeBuyerColors.orange,
                  ),
                ),
                Text(
                  '${data['destination'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _LaneChip(
                      icon: Icons.straighten_outlined,
                      label: '${data['distanceKm'] ?? 0} km',
                    ),
                    _LaneChip(
                      icon: Icons.payments_outlined,
                      label: marketplaceMoney(data['total'] as num? ?? 0),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Open quote'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _LaneChip extends StatelessWidget {
  const _LaneChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: PipeBuyerColors.slate),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}

class _DispatchQuoteDialog extends StatefulWidget {
  const _DispatchQuoteDialog(
      {required this.repo, required this.template, this.quoteId});
  final MarketplaceDispatchRepository repo;
  final Map<String, dynamic> template;
  final String? quoteId;

  @override
  State<_DispatchQuoteDialog> createState() => _DispatchQuoteDialogState();
}

class _DispatchQuoteDialogState extends State<_DispatchQuoteDialog> {
  late final Map<String, TextEditingController> c;
  bool manual = false;

  @override
  void initState() {
    super.initState();
    String initial(String key, [Object fallback = '0']) =>
        '${widget.template[key] ?? fallback}';
    c = {
      'name': TextEditingController(text: initial('name', '')),
      'origin': TextEditingController(text: initial('origin', '')),
      'destination': TextEditingController(text: initial('destination', '')),
      'distanceKm': TextEditingController(text: initial('distanceKm')),
      'deadheadKm': TextEditingController(text: initial('deadheadKm')),
      'mileageRate': TextEditingController(text: initial('mileageRate')),
      'deadheadRate': TextEditingController(text: initial('deadheadRate')),
      'weightKg': TextEditingController(text: initial('weightKg')),
      'weightRate': TextEditingController(text: initial('weightRate')),
      'hours': TextEditingController(text: initial('hours')),
      'hourlyRate': TextEditingController(text: initial('hourlyRate')),
      'areaFee': TextEditingController(text: initial('areaFee')),
      'pilotCount': TextEditingController(text: initial('pilotCount')),
      'pilotKmRate': TextEditingController(text: initial('pilotKmRate')),
      'pilotHourlyRate':
          TextEditingController(text: initial('pilotHourlyRate')),
      'pilotAreaFee': TextEditingController(text: initial('pilotAreaFee')),
      'permitFee': TextEditingController(text: initial('permitFee')),
      'baseFee': TextEditingController(text: initial('baseFee')),
      'surchargePercent':
          TextEditingController(text: initial('surchargePercent')),
      'taxPercent': TextEditingController(text: initial('taxPercent')),
      'manualTotal': TextEditingController(text: initial('manualTotal')),
    };
    for (final controller in c.values) {
      controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final controller in c.values) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() => setState(() {});
  double n(String key) => double.tryParse(c[key]!.text) ?? 0;

  Map<String, double> get calculation {
    final loadedMileage = n('distanceKm') * n('mileageRate');
    final deadhead = n('deadheadKm') * n('deadheadRate');
    final weight = n('weightKg') / 1000 * n('weightRate');
    final time = n('hours') * n('hourlyRate');
    final pilot = n('pilotCount') *
        (n('distanceKm') * n('pilotKmRate') +
            n('hours') * n('pilotHourlyRate') +
            n('pilotAreaFee'));
    final subtotal = n('baseFee') +
        loadedMileage +
        deadhead +
        weight +
        time +
        n('areaFee') +
        n('permitFee') +
        pilot;
    final surcharge = subtotal * n('surchargePercent') / 100;
    final beforeTax = subtotal + surcharge;
    final tax = beforeTax * n('taxPercent') / 100;
    return {
      'loadedMileage': loadedMileage,
      'deadhead': deadhead,
      'weight': weight,
      'time': time,
      'pilot': pilot,
      'subtotal': subtotal,
      'surcharge': surcharge,
      'tax': tax,
      'total': manual ? n('manualTotal') : beforeTax + tax
    };
  }

  @override
  Widget build(BuildContext context) {
    final total = calculation;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.orangeSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.calculate_outlined,
                      color: PipeBuyerColors.orangePressed,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.quoteId == null
                              ? 'Dispatch quote calculator'
                              : 'Edit dispatch quote',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const Text(
                          'Build a transparent planning quote from route, load, truck, pilot, permit and tax inputs.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _QuoteSection(
                      title: 'Lane identity',
                      icon: Icons.route_outlined,
                      child: Column(
                        children: [
                          _field('name', 'Saved quote / lane name'),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stack = constraints.maxWidth < 560;
                              final origin = _field('origin', 'Origin');
                              final destination =
                                  _field('destination', 'Destination');
                              if (stack) {
                                return Column(
                                  children: [origin, destination],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: origin),
                                  const SizedBox(width: 8),
                                  Expanded(child: destination),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _QuoteSection(
                      title: 'Route & load',
                      icon: Icons.straighten_outlined,
                      child: _numberRow([
                        ('distanceKm', 'Loaded distance', 'km'),
                        ('deadheadKm', 'Deadhead distance', 'km'),
                        ('weightKg', 'Shipping weight', 'kg'),
                        ('hours', 'Estimated time', 'hours')
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _QuoteSection(
                      title: 'Truck charges',
                      icon: Icons.local_shipping_outlined,
                      child: _numberRow([
                        ('baseFee', 'Base / call-out', '\$'),
                        ('mileageRate', 'Loaded mileage', '\$/km'),
                        ('deadheadRate', 'Deadhead', '\$/km'),
                        ('weightRate', 'Weight charge', '\$/tonne'),
                        ('hourlyRate', 'Time charge', '\$/hour'),
                        ('areaFee', 'Area / zone fee', '\$'),
                        ('permitFee', 'Permits / fixed costs', '\$')
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _QuoteSection(
                      title: 'Pilot vehicles',
                      icon: Icons.assistant_direction_outlined,
                      child: _numberRow([
                        ('pilotCount', 'Pilot vehicles needed', '#'),
                        ('pilotKmRate', 'Pilot mileage', '\$/km each'),
                        ('pilotHourlyRate', 'Pilot time', '\$/hour each'),
                        ('pilotAreaFee', 'Pilot area fee', '\$ each')
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _QuoteSection(
                      title: 'Adjustments',
                      icon: Icons.tune_rounded,
                      child: Column(
                        children: [
                          _numberRow([
                            ('surchargePercent', 'Fuel / service surcharge', '%'),
                            ('taxPercent', 'Tax', '%')
                          ]),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Manual quote override',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text(
                              'Overrides the calculated total; the calculation remains visible for comparison.',
                            ),
                            value: manual,
                            onChanged: (value) =>
                                setState(() => manual = value),
                          ),
                          if (manual)
                            _field('manualTotal', 'Manual quoted total'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _QuoteTotalCard(total: total, lineBuilder: _line),
                    const SizedBox(height: 10),
                    const _RoutePlanningNotice(),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: Icon(widget.quoteId == null
                        ? Icons.bookmark_add_outlined
                        : Icons.save_outlined),
                    label: Text(widget.quoteId == null
                        ? 'Save quote'
                        : 'Save changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String key, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
          controller: c[key], decoration: InputDecoration(labelText: label)));

  Widget _numberRow(List<(String, String, String)> fields) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720
              ? 3
              : constraints.maxWidth >= 470
                  ? 2
                  : 1;
          const gap = 8.0;
          final width = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: fields
                .map((field) => SizedBox(
                    width: width,
                    child: TextField(
                        controller: c[field.$1],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: field.$2, suffixText: field.$3))))
                .toList(),
          );
        },
      );

  Widget _line(String label, double amount, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: strong ? FontWeight.w900 : FontWeight.normal))),
        Text(marketplaceMoney(amount),
            style: TextStyle(
                fontSize: strong ? 18 : 14, fontWeight: FontWeight.w900))
      ]));

  Future<void> _save() async {
    if (c['name']!.text.trim().isEmpty ||
        c['origin']!.text.trim().isEmpty ||
        c['destination']!.text.trim().isEmpty ||
        calculation['total']! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Add a name, both locations and a valid quote total.')));
      return;
    }
    await widget.repo.saveQuote({
      for (final entry in c.entries)
        entry.key: ['name', 'origin', 'destination'].contains(entry.key)
            ? entry.value.text.trim()
            : double.tryParse(entry.value.text) ?? 0,
      ...calculation,
      'manual': manual,
      'formulaVersion': 1
    }, quoteId: widget.quoteId);
    if (mounted) Navigator.pop(context);
  }
}

class _QuoteSection extends StatelessWidget {
  const _QuoteSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.orangeSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    color: PipeBuyerColors.orangePressed,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _QuoteTotalCard extends StatelessWidget {
  const _QuoteTotalCard({required this.total, required this.lineBuilder});

  final Map<String, double> total;
  final Widget Function(String, double, {bool strong}) lineBuilder;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: PipeBuyerColors.success.withValues(alpha: .065),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: PipeBuyerColors.success.withValues(alpha: .22),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.success.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: PipeBuyerColors.success,
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Calculated quote',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            lineBuilder('Loaded mileage', total['loadedMileage']!),
            lineBuilder('Deadhead', total['deadhead']!),
            lineBuilder('Weight', total['weight']!),
            lineBuilder('Time', total['time']!),
            lineBuilder('Pilot vehicles', total['pilot']!),
            lineBuilder('Subtotal', total['subtotal']!),
            lineBuilder('Surcharge', total['surcharge']!),
            lineBuilder('Tax', total['tax']!),
            const Divider(),
            lineBuilder('QUOTE TOTAL', total['total']!, strong: true),
          ],
        ),
      );
}

class _RoutePlanningNotice extends StatelessWidget {
  const _RoutePlanningNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: PipeBuyerColors.warning.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: PipeBuyerColors.warning.withValues(alpha: .20),
          ),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 19,
              color: PipeBuyerColors.warning,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Map distance is a planning input. Confirm the legal truck route, restrictions, permits, borders and scale access before issuing a binding quote.',
                style: TextStyle(fontSize: 11.5, height: 1.35),
              ),
            ),
          ],
        ),
      );
}
