import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/data/bounded_firestore_query.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'industrial_icon_assets.dart';
import 'marketplace_auction_repository.dart';
import 'marketplace_auction_settlement.dart';
import 'marketplace_avatar_image.dart';
import 'marketplace_command_client.dart';
import 'marketplace_data_state.dart';
import 'marketplace_deep_links.dart';
import 'marketplace_freight_quote.dart';
import 'marketplace_grid_density.dart';
import 'marketplace_listing_media.dart';
import 'marketplace_listing_status.dart';
import 'marketplace_listing_specs.dart';
import 'marketplace_money.dart';
import 'marketplace_timed_buying_presentation.dart';
import 'marketplace_timed_buying_engagement.dart';
import 'marketplace_timed_buying_trust.dart';
import 'marketplace_trucking_plan.dart';

DateTime? parseAuctionDate(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is num && value > 0) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
  }
  return null;
}

DateTime? parseAuctionStart(Map<String, dynamic> data) => parseAuctionDate(
      data,
      const [
        'auctionStartAt',
        'auctionStart',
        'startsAt',
        'startAt',
        'createdAt',
      ],
    );

DateTime? parseAuctionEnd(Map<String, dynamic> data) => parseAuctionDate(
      data,
      const [
        'auctionEndAt',
        'auctionEnd',
        'endsAt',
        'endAt',
        'closingAt',
        'endTime',
      ],
    );

bool isAuctionEnded(Map<String, dynamic> data, DateTime now) {
  final end = parseAuctionEnd(data);
  final status =
      '${data['status'] ?? data['auctionStatus'] ?? data['saleStatus'] ?? ''}'
          .toLowerCase();
  final statusEnded = const {
    'ended',
    'closed',
    'settled',
    'sold',
    'bought_now',
    'won',
    'completed',
    'cancelled',
    'expired',
  }.contains(status);
  return statusEnded || (end != null && !now.isBefore(end));
}

bool isAuctionUpcoming(Map<String, dynamic> data, DateTime now) {
  final start = parseAuctionStart(data);
  return start != null && now.isBefore(start) && !isAuctionEnded(data, now);
}

bool isAuctionLive(Map<String, dynamic> data, DateTime now) =>
    !isAuctionUpcoming(data, now) && !isAuctionEnded(data, now);

class MarketplaceAuctionRoutePage extends StatefulWidget {
  const MarketplaceAuctionRoutePage({super.key, required this.listingId});

  final String listingId;

  @override
  State<MarketplaceAuctionRoutePage> createState() =>
      _MarketplaceAuctionRoutePageState();
}

class _MarketplaceAuctionRoutePageState
    extends State<MarketplaceAuctionRoutePage> {
  late Future<QuerySnapshot<Map<String, dynamic>>> _auction;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _auction = FirebaseFirestore.instance
        .collection('public_listings')
        .where(FieldPath.documentId, isEqualTo: widget.listingId)
        .where('transactionType', isEqualTo: 'Auction')
        .limit(1)
        .get();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: _auction,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: MarketplaceDataStateView.loading(
                title: 'Loading Timed Buying',
                message:
                    'Retrieving current timed offers, timing, and listing details…',
              ),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Timed Buying')),
              body: _AuctionLoadError(
                details:
                    'Check your connection or account access, then try again.',
                onRetry: () => setState(_load),
              ),
            );
          }
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Timed Buying'),
                actions: [
                  IconButton(
                    tooltip: 'Marketplace home',
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home_outlined),
                  ),
                ],
              ),
              body: _AuctionLoadError(
                details:
                    'This Timed Buying listing may have closed, been removed, or the link may be incorrect.',
                onRetry: () => setState(_load),
              ),
            );
          }
          return _AuctionDetails(document: docs.single);
        },
      );
}

class MarketplaceAuctionsPage extends StatefulWidget {
  const MarketplaceAuctionsPage({
    super.key,
    required this.onCreateAuction,
  });

  final VoidCallback onCreateAuction;

  @override
  State<MarketplaceAuctionsPage> createState() =>
      _MarketplaceAuctionsPageState();
}

class _MarketplaceAuctionsPageState extends State<MarketplaceAuctionsPage> {
  String _filter = 'Live';
  int _gridColumns = 0;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _documents = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loading = false;
  bool _hasMore = true;
  String? _loadError;
  int _queryGeneration = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadPage(reset: true);
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Query<Map<String, dynamic>> _query() => FirebaseFirestore.instance
      .collection('public_listings')
      .orderBy('createdAt', descending: true);

  Future<void> _loadPage({bool reset = false}) async {
    if (_loading && !reset) return;
    if (!reset && !_hasMore) return;
    final generation = reset ? ++_queryGeneration : _queryGeneration;
    setState(() {
      _loading = true;
      _loadError = null;
      if (reset) {
        _documents.clear();
        _cursor = null;
        _hasMore = true;
      }
    });
    try {
      final page = await loadFirestoreDocumentPage(
        _query(),
        after: reset ? null : _cursor,
      );
      if (!mounted || generation != _queryGeneration) return;
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
        _cursor = page.cursor;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted || generation != _queryGeneration) return;
      setState(() {
        _loadError = error is FirebaseException &&
                error.code == 'failed-precondition'
            ? 'The Timed Buying index is still being prepared. Try again shortly.'
            : 'Check your connection and try again.';
      });
    } finally {
      if (mounted && generation == _queryGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final all = _documents
        .where((doc) => doc.data()['transactionType'] == 'Auction')
        .toList(growable: false);
    final liveCount = all.where((doc) => isAuctionLive(doc.data(), now)).length;
    final upcomingCount =
        all.where((doc) => isAuctionUpcoming(doc.data(), now)).length;
    final endedCount =
        all.where((doc) => isAuctionEnded(doc.data(), now)).length;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final auctions = all.where((doc) {
      final data = doc.data();
      if (_filter == 'My Timed Buying')
        return uid != null && data['sellerUid'] == uid;
      if (_filter == 'Live') return isAuctionLive(data, now);
      if (_filter == 'Upcoming') return isAuctionUpcoming(data, now);
      if (_filter == 'Ended') return isAuctionEnded(data, now);
      return true;
    }).toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AuctionPageHero(
                liveCount: liveCount,
                upcomingCount: upcomingCount,
                endedCount: endedCount,
                onCreateAuction: widget.onCreateAuction,
                onShowLegend: () => showTimedBuyingAttentionLegend(context),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  final filters = SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'Live',
                          icon: Icon(Icons.fiber_manual_record),
                          label: Text('Live'),
                        ),
                        ButtonSegment(
                          value: 'Upcoming',
                          icon: Icon(Icons.schedule_outlined),
                          label: Text('Upcoming'),
                        ),
                        ButtonSegment(
                          value: 'Ended',
                          icon: Icon(Icons.history_outlined),
                          label: Text('Ended'),
                        ),
                        ButtonSegment(
                          value: 'My Timed Buying',
                          icon: Icon(Icons.person_outline),
                          label: Text('My Timed Buying'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (values) {
                        final next = values.first;
                        if (next == _filter) return;
                        setState(() => _filter = next);
                      },
                    ),
                  );
                  final density = MarketplaceGridDensityBar(
                    selectedColumns: _gridColumns,
                    onChanged: (value) => setState(() => _gridColumns = value),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        filters,
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerRight, child: density),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: filters),
                      const SizedBox(width: 10),
                      density,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: TimedBuyingViewerParticipationScope(
            viewerUid: uid,
            child: _body(auctions),
          ),
        ),
      ],
    );
  }

  Widget _body(List<QueryDocumentSnapshot<Map<String, dynamic>>> auctions) {
    if (_loading && _documents.isEmpty) {
      return const MarketplaceDataStateView.loading(
        title: 'Loading Timed Buying',
        message: 'Retrieving current timed offers and closing times…',
      );
    }
    if (_loadError != null && _documents.isEmpty) {
      return _AuctionLoadError(
        details: _loadError!,
        onRetry: () => _loadPage(reset: true),
      );
    }
    if (auctions.isEmpty) {
      return _AuctionEmpty(
        filter: _filter,
        onCreate: widget.onCreateAuction,
        onLoadMore: _hasMore && !_loading ? () => _loadPage() : null,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = MarketplaceGridDensityBar.resolveColumns(
          constraints.maxWidth,
          _gridColumns,
        );
        if (columns <= 1) {
          return RefreshIndicator(
            onRefresh: () => _loadPage(reset: true),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
              itemCount: auctions.length + 1,
              itemBuilder: (context, index) {
                if (index < auctions.length) {
                  return _AuctionCard(document: auctions[index]);
                }
                return _loadMoreFooter();
              },
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => _loadPage(reset: true),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: columns == 2 ? 402 : 378,
            ),
            itemCount: auctions.length + 1,
            itemBuilder: (context, index) {
              if (index < auctions.length) {
                return _AuctionCard(document: auctions[index]);
              }
              return _loadMoreFooter();
            },
          ),
        );
      },
    );
  }

  Widget _loadMoreFooter() {
    if (_loadError != null) {
      return _AuctionPageError(
        onRetry: () => _loadPage(),
        details: _loadError!,
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Text(
            'All Timed Buying listings loaded.',
            style: TextStyle(color: PipeBuyerColors.muted),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: FilledButton.tonalIcon(
          onPressed: _loading ? null : () => _loadPage(),
          icon: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more),
          label: Text(_loading ? 'Loading more…' : 'Load more Timed Buying'),
        ),
      ),
    );
  }
}

class _AuctionPageHero extends StatelessWidget {
  const _AuctionPageHero({
    required this.liveCount,
    required this.upcomingCount,
    required this.endedCount,
    required this.onCreateAuction,
    required this.onShowLegend,
  });

  final int liveCount;
  final int upcomingCount;
  final int endedCount;
  final VoidCallback onCreateAuction;
  final VoidCallback onShowLegend;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1D000000),
              blurRadius: 20,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PIPE BUYER TIMED BUYING',
                  style: TextStyle(
                    color: PipeBuyerColors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Timed Buying',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Use timed offers for oilfield pipe, equipment and industrial inventory with clear closing times and auditable offer activity.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AuctionMetric(label: 'LIVE', value: liveCount),
                    _AuctionMetric(label: 'UPCOMING', value: upcomingCount),
                    _AuctionMetric(label: 'ENDED', value: endedCount),
                  ],
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onShowLegend,
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('Time legend'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onCreateAuction,
                  icon: const Icon(Icons.add),
                  label: const Text('Create timed listing'),
                ),
              ],
            );
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 16), actions],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: copy),
                const SizedBox(width: 18),
                actions,
              ],
            );
          },
        ),
      );
}

class _AuctionMetric extends StatelessWidget {
  const _AuctionMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .45,
              ),
            ),
          ],
        ),
      );
}

class _AuctionCard extends StatelessWidget {
  const _AuctionCard({required this.document});

  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  @override
  Widget build(BuildContext context) {
    final data = document.data();
    final current = data['currentBid'] as num? ?? 0;
    final starting = data['startingBid'] as num? ?? data['price'] as num? ?? 0;
    final start = parseAuctionStart(data);
    final end = parseAuctionEnd(data);
    final now = DateTime.now();
    final ended = isAuctionEnded(data, now);
    final live = isAuctionLive(data, now);
    final viewerUid = FirebaseAuth.instance.currentUser?.uid;
    final viewerOwnsListing =
        viewerUid != null && data['sellerUid'] == viewerUid;
    final participation = TimedBuyingViewerParticipationScope.maybeOf(context)
            ?.forListing(document.id, data) ??
        deriveTimedBuyingViewerParticipation(
          viewerUid: viewerUid,
          listing: data,
          viewerOffers: const [],
        );
    final presentation = MarketplaceListingPresentation.fromMap(
      data,
      currentUserUid: FirebaseAuth.instance.currentUser?.uid,
      isAuction: true,
      now: now,
    );
    final statusColor = live
        ? PipeBuyerColors.danger
        : ended
            ? PipeBuyerColors.slate
            : PipeBuyerColors.industrialBlue;

    return TimedBuyingTrustFrame(
      participation: participation,
      start: start,
      end: end,
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        elevation: presentation.emphasized ? 2 : 0,
        shadowColor: presentation.shadowColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: presentation.borderColor,
            width: presentation.emphasized ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () => context.push(MarketplaceDeepLinks.auction(document.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  MarketplaceListingMedia(
                    listing: data,
                    height: 174,
                    borderRadius: 0,
                    showCategoryLabel: false,
                    showSourceLabel: true,
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    right: 10,
                    child: MarketplaceListingBadges(
                      badges: presentation.badges,
                      compact: true,
                    ),
                  ),
                  if (viewerOwnsListing || participation.hasParticipated)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: viewerOwnsListing
                          ? const TimedBuyingViewerPositionBadge(
                              position: TimedBuyingViewerPosition.seller,
                            )
                          : TimedBuyingParticipationBadge(
                              participation: participation,
                            ),
                    ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: _AuctionStateBadge(
                      label: live
                          ? 'LIVE'
                          : ended
                              ? 'ENDED'
                              : 'UPCOMING',
                      color: statusColor,
                      icon: live
                          ? Icons.fiber_manual_record
                          : ended
                              ? Icons.flag_outlined
                              : Icons.schedule_outlined,
                    ),
                  ),
                ],
              ),
              TimedBuyingAttentionStrip(
                start: start,
                end: end,
                compact: true,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timedBuyingDisplayTitle(data['title']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      marketplaceMoney(current > 0 ? current : starting),
                      style: const TextStyle(
                        color: PipeBuyerColors.orangePressed,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      current > 0 ? 'Leading offer' : 'Opening offer',
                      style: const TextStyle(
                        color: PipeBuyerColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 15,
                          color: PipeBuyerColors.muted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${data['bidCount'] ?? 0} timed offers',
                          style: const TextStyle(
                            color: PipeBuyerColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.timer_outlined,
                          size: 15,
                          color: PipeBuyerColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: _AuctionCountdown(
                            start: start,
                            end: end,
                            style: TextStyle(
                              color: live
                                  ? PipeBuyerColors.danger
                                  : PipeBuyerColors.muted,
                              fontSize: 11,
                              fontWeight:
                                  live ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuctionStateBadge extends StatelessWidget {
  const _AuctionStateBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xE6111820),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .82)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
              ),
            ),
          ],
        ),
      );
}

class _AuctionDetails extends StatefulWidget {
  const _AuctionDetails({required this.document});

  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  @override
  State<_AuctionDetails> createState() => _AuctionDetailsState();
}

class _AuctionDetailsState extends State<_AuctionDetails> {
  final _bid = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _bid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.document.reference.snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? widget.document.data();
          final current = data['currentBid'] as num? ?? 0;
          final starting =
              data['startingBid'] as num? ?? data['price'] as num? ?? 0;
          final displayedAmount = current > 0 ? current : starting;
          final pricingBasis =
              '${data['auctionPricingBasis'] ?? data['priceBasis'] ?? ''}';
          final quantity =
              (data['auctionQuantity'] as num? ?? data['quantity'] as num?)
                  ?.toInt();
          final totalBasis = pricingBasis.toLowerCase().contains('total');
          final displayedTotal =
              totalBasis ? displayedAmount : displayedAmount * (quantity ?? 1);
          final increment = data['minimumBidIncrement'] as num? ?? 1;
          final buyNow = data['buyItNowPrice'] as num?;
          final next = current > 0 ? current + increment : starting;
          final start = parseAuctionStart(data);
          final end = parseAuctionEnd(data);
          final now = DateTime.now();
          final live = isAuctionLive(data, now);
          final ended = isAuctionEnded(data, now);
          if (live && !_submitting && _bid.text.trim().isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _bid.text.trim().isNotEmpty) return;
              _bid.text = next.toStringAsFixed(2);
              _bid.selection =
                  TextSelection.collapsed(offset: _bid.text.length);
            });
          }
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final mine = data['sellerUid'] == uid;
          final participant = mine || data['highBidderUid'] == uid;
          final auctionStatus = '${data['auctionStatus'] ?? ''}';
          final settlementReady = const {
            'bought_now',
            'accepted_below_reserve',
            'won',
          }.contains(auctionStatus);
          final needsFinalization = end != null &&
              !now.isBefore(end) &&
              !const {
                'bought_now',
                'accepted_below_reserve',
                'won',
                'ended',
                'cancelled',
              }.contains(auctionStatus);

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: mine
                ? FirebaseFirestore.instance
                    .collection('auction_private')
                    .doc(widget.document.id)
                    .snapshots()
                : null,
            builder: (context, privateSnapshot) {
              final reserve = mine
                  ? (privateSnapshot.data?.data()?['reservePrice'] as num?)
                  : null;
              final images = marketplaceListingImageUrls(data);
              final thumbnail = marketplaceListingThumbnailUrl(data);
              final orderedImages = thumbnail == null
                  ? images
                  : <String>[
                      thumbnail,
                      ...images.where((item) => item != thumbnail),
                    ];

              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                appBar: AppBar(
                  title: const Text('Timed Buying'),
                  actions: [
                    IconButton(
                      tooltip: 'Marketplace home',
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.home_outlined),
                    ),
                  ],
                ),
                body: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                        children: [
                          _AuctionDetailHero(
                            title: timedBuyingDisplayTitle(data['title']),
                            live: live,
                            ended: ended,
                            start: start,
                            end: end,
                          ),
                          const SizedBox(height: 14),
                          if (orderedImages.isNotEmpty)
                            _AuctionMediaGallery(images: orderedImages)
                          else
                            _AuctionArtworkFallback(data: data),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final desktop = constraints.maxWidth >= 860;
                              final primary = Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _AuctionBidSummary(
                                    displayedAmount: displayedAmount,
                                    current: current,
                                    pricingBasis: pricingBasis,
                                    quantity: quantity,
                                    totalBasis: totalBasis,
                                    displayedTotal: displayedTotal,
                                    live: live,
                                    start: start,
                                    end: end,
                                    bidCount:
                                        (data['bidCount'] as num?)?.toInt() ??
                                            0,
                                  ),
                                  if (mine &&
                                      reserve != null &&
                                      reserve > 0) ...[
                                    const SizedBox(height: 12),
                                    _ReserveCard(
                                      current: current,
                                      reserve: reserve,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  _BidPricingAnalytics(
                                    askingPrice: data['price'] as num?,
                                    displayedBid: displayedAmount,
                                    nextBid: next,
                                    increment: increment,
                                    quantity: quantity,
                                    pricingBasis: pricingBasis,
                                    reserve: mine ? reserve : null,
                                    buyNow: buyNow,
                                  ),
                                  const SizedBox(height: 14),
                                  _AuctionListingDetails(data: data),
                                ],
                              );
                              final actions = Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _SellerCard(data: data),
                                  const SizedBox(height: 12),
                                  MarketplaceDispatchQuoteCard(
                                    auction: true,
                                    onPressed: () =>
                                        MarketplaceFreightQuote.show(
                                      context,
                                      listingId: widget.document.id,
                                      listing: data,
                                      auction: true,
                                    ),
                                  ),
                                  if (mine &&
                                      current > 0 &&
                                      reserve != null &&
                                      current < reserve) ...[
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _submitting
                                          ? null
                                          : () => _acceptBelowReserve(current),
                                      icon:
                                          const Icon(Icons.handshake_outlined),
                                      label: Text(
                                        'Accept leading offer • ${marketplaceMoney(current)}',
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  mine
                                      ? const Card(
                                          child: ListTile(
                                            leading: Icon(Icons.storefront),
                                            title: Text(
                                                'This is your Timed Buying listing'),
                                            subtitle: Text(
                                              'Timed-offer activity and seller controls appear here.',
                                            ),
                                          ),
                                        )
                                      : _BidActionPanel(
                                          bidController: _bid,
                                          live: live,
                                          submitting: _submitting,
                                          nextBid: next,
                                          currency:
                                              '${data['currency'] ?? 'CAD'}',
                                          buyNow: buyNow,
                                          onPlaceBid: _placeBid,
                                          onBuyNow: buyNow == null
                                              ? null
                                              : () => _buyNow(buyNow),
                                        ),
                                ],
                              );
                              if (!desktop) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    primary,
                                    const SizedBox(height: 14),
                                    actions,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: primary),
                                  const SizedBox(width: 16),
                                  SizedBox(width: 340, child: actions),
                                ],
                              );
                            },
                          ),
                          if (participant &&
                              (settlementReady || needsFinalization)) ...[
                            const SizedBox(height: 14),
                            MarketplaceAuctionSettlement(
                              listingId: widget.document.id,
                              listing: data,
                            ),
                          ],
                          const SizedBox(height: 20),
                          const Text(
                            'Timed offer activity',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _TimedBuyingBuyerTrustPosition(
                            listingId: widget.document.id,
                            listing: data,
                            nextOffer: next,
                            live: live,
                          ),
                          const TimedBuyingTrustStrip(),
                          const SizedBox(height: 8),
                          _BidHistory(
                            listingId: widget.document.id,
                            listing: data,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

  Future<void> _placeBid() async {
    final amount = num.tryParse(_bid.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (amount == null) {
      PipeFeedback.show(
        context,
        message: 'Enter a timed offer amount to continue.',
        tone: PipeStatusTone.error,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Submit this timed offer?'),
            content: Text(
              'Submit a binding timed offer of ${marketplaceMoney(amount)} CAD?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Submit timed offer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => _submitting = true);
    try {
      await MarketplaceAuctionRepository().placeBid(
        listingId: widget.document.id,
        amount: amount,
      );
      if (mounted) {
        _bid.clear();
        PipeFeedback.show(
          context,
          message: 'Timed offer submitted.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message:
              timedBuyingPublicMessage(marketplaceCommandErrorMessage(error)),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _buyNow(num price) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Buy this item now?'),
            content: Text(
              'Confirm purchase at ${marketplaceMoney(price)} CAD. This immediately closes the Timed Buying listing.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirm purchase'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => _submitting = true);
    try {
      await MarketplaceAuctionRepository().buyNow(
        listingId: widget.document.id,
      );
      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'Purchase confirmed. Timed Buying is closed.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message:
              timedBuyingPublicMessage(marketplaceCommandErrorMessage(error)),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _acceptBelowReserve(num amount) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Accept below seller minimum?'),
            content: Text(
              'Accept the leading ${marketplaceMoney(amount)} bid and close this Timed Buying listing? The bidder will be notified immediately.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep Timed Buying open'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Accept and close'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => _submitting = true);
    try {
      await MarketplaceAuctionRepository().acceptLeadingBidBelowReserve(
        listingId: widget.document.id,
      );
      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'Leading offer accepted. The buyer was notified.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message:
              timedBuyingPublicMessage(marketplaceCommandErrorMessage(error)),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _TimedBuyingBuyerTrustPosition extends StatelessWidget {
  const _TimedBuyingBuyerTrustPosition({
    required this.listingId,
    required this.listing,
    required this.nextOffer,
    required this.live,
  });

  final String listingId;
  final Map<String, dynamic> listing;
  final num nextOffer;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || listing['sellerUid'] == uid) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('auction_bids')
          .where('listingId', isEqualTo: listingId)
          .orderBy('createdAt', descending: true)
          .limit(defaultActivityFeedLimit)
          .snapshots(),
      builder: (context, snapshot) {
        final offers = (snapshot.data?.docs ?? const [])
            .map((document) => document.data())
            .toList(growable: false);
        final participation = deriveTimedBuyingViewerParticipation(
          viewerUid: uid,
          listing: listing,
          viewerOffers: offers,
        );
        if (!participation.hasParticipated) return const SizedBox.shrink();
        final color = participation.leading
            ? PipeBuyerColors.success
            : participation.outbid
                ? PipeBuyerColors.danger
                : PipeBuyerColors.orangePressed;
        final offersAhead = participation.offersAhead;
        final aheadText = offersAhead == null
            ? ''
            : ' • $offersAhead ${offersAhead == 1 ? 'offer' : 'offers'} ahead';
        final nextText =
            live ? ' • Next minimum: ${marketplaceMoney(nextOffer)}' : '';
        final positionText = participation.leading
            ? 'Your top timed offer is ${marketplaceMoney(participation.viewerTopOffer)} and it is the current lead.'
            : participation.outbid
                ? 'Your top: ${marketplaceMoney(participation.viewerTopOffer)} • Lead: ${marketplaceMoney(participation.currentLead)} • Behind by ${marketplaceMoney(participation.amountBehind)}$aheadText$nextText'
                : 'You have an active timed offer on this listing.';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: .5), width: 1.3),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                participation.leading
                    ? Icons.emoji_events_outlined
                    : Icons.trending_up_outlined,
                color: color,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participation.compactStatusLabel,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      positionText,
                      style: const TextStyle(
                        color: PipeBuyerColors.graphite,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuctionDetailHero extends StatelessWidget {
  const _AuctionDetailHero({
    required this.title,
    required this.live,
    required this.ended,
    required this.start,
    required this.end,
  });

  final String title;
  final bool live;
  final bool ended;
  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final statusColor = live
        ? PipeBuyerColors.danger
        : ended
            ? PipeBuyerColors.slate
            : PipeBuyerColors.industrialBlue;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: PipeBuyerColors.orange,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _AuctionStateBadge(
                      label: live
                          ? 'LIVE'
                          : ended
                              ? 'ENDED'
                              : 'UPCOMING',
                      color: statusColor,
                      icon: live
                          ? Icons.fiber_manual_record
                          : ended
                              ? Icons.flag_outlined
                              : Icons.schedule_outlined,
                    ),
                    _AuctionCountdown(
                      start: start,
                      end: end,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuctionArtworkFallback extends StatelessWidget {
  const _AuctionArtworkFallback({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final asset =
        IndustrialIconAssets.forLabel('${data['productType'] ?? ''}') ??
            IndustrialIconAssets.forLabel('${data['category'] ?? ''}') ??
            IndustrialIconAssets.inventory;
    return Container(
      height: 230,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: IndustrialAssetIcon(
        label: '${data['productType'] ?? data['title'] ?? 'Timed Buying'}',
        assetPath: asset,
        size: 174,
        borderRadius: 16,
        fallback: const Icon(
          Icons.timer_rounded,
          color: Colors.white70,
          size: 76,
        ),
      ),
    );
  }
}

class _AuctionBidSummary extends StatelessWidget {
  const _AuctionBidSummary({
    required this.displayedAmount,
    required this.current,
    required this.pricingBasis,
    required this.quantity,
    required this.totalBasis,
    required this.displayedTotal,
    required this.live,
    required this.start,
    required this.end,
    required this.bidCount,
  });

  final num displayedAmount;
  final num current;
  final String pricingBasis;
  final int? quantity;
  final bool totalBasis;
  final num displayedTotal;
  final bool live;
  final DateTime? start;
  final DateTime? end;
  final int bidCount;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: PipeBuyerColors.ink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Wrap(
          spacing: 24,
          runSpacing: 14,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    current > 0 ? 'LEADING OFFER' : 'OPENING OFFER',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    marketplaceMoney(displayedAmount),
                    style: const TextStyle(
                      color: PipeBuyerColors.orange,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (pricingBasis.isNotEmpty)
                    Text(
                      pricingBasis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (!totalBasis && quantity != null)
                    Text(
                      '$quantity units • Offer total ${marketplaceMoney(displayedTotal)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$bidCount ${bidCount == 1 ? 'timed offer' : 'timed offers'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                _AuctionCountdown(
                  start: start,
                  end: end,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: live ? PipeBuyerColors.danger : Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _ReserveCard extends StatelessWidget {
  const _ReserveCard({required this.current, required this.reserve});

  final num current;
  final num reserve;

  @override
  Widget build(BuildContext context) {
    final met = current >= reserve;
    final progress =
        reserve <= 0 ? 0.0 : (current / reserve).clamp(0, 1).toDouble();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_outlined, color: PipeBuyerColors.orange),
                const SizedBox(width: 8),
                Text(
                  met
                      ? 'Seller minimum has been met'
                      : 'Seller minimum not met',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress,
                color: met ? PipeBuyerColors.success : PipeBuyerColors.orange,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              met
                  ? 'The current leading timed offer satisfies your private reserve.'
                  : '${(progress * 100).toStringAsFixed(0)}% reached • ${marketplaceMoney((reserve - current).clamp(0, double.infinity))} remaining',
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: MarketplaceUserAvatar(
            userUid: '${data['sellerUid'] ?? ''}',
            photoUrl:
                '${data['sellerPhotoUrl'] ?? data['sellerAvatarUrl'] ?? ''}',
            size: 46,
            business: data['sellerAccountType'] == 'business',
            verified: data['sellerVerified'] == true,
            fallback: const Center(child: Icon(Icons.person_outline)),
          ),
          title: Text(
            '${data['sellerName'] ?? 'Marketplace seller'}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text('View seller profile and active inventory'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push(
            MarketplaceDeepLinks.profile('${data['sellerUid'] ?? ''}'),
          ),
        ),
      );
}

class _BidActionPanel extends StatelessWidget {
  const _BidActionPanel({
    required this.bidController,
    required this.live,
    required this.submitting,
    required this.nextBid,
    required this.currency,
    required this.buyNow,
    required this.onPlaceBid,
    required this.onBuyNow,
  });

  final TextEditingController bidController;
  final bool live;
  final bool submitting;
  final num nextBid;
  final String currency;
  final num? buyNow;
  final VoidCallback onPlaceBid;
  final VoidCallback? onBuyNow;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Submit a timed offer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Review the amount carefully before submitting a binding timed offer.',
                style: TextStyle(fontSize: 11, color: PipeBuyerColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bidController,
                enabled: live && !submitting,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText:
                      'Your timed offer • minimum ${marketplaceMoney(nextBid)}',
                  prefixText: '\$ ',
                  suffixText: currency,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: live && !submitting ? onPlaceBid : null,
                icon: submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.timer_rounded),
                label: Text(live
                    ? 'Review & submit timed offer'
                    : 'Timed offers unavailable'),
              ),
              if (live &&
                  buyNow != null &&
                  buyNow! > 0 &&
                  onBuyNow != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: submitting ? null : onBuyNow,
                  icon: const Icon(Icons.flash_on_outlined),
                  label: Text('Buy It Now • ${marketplaceMoney(buyNow!)}'),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Timed offers are binding. The seller and successful buyer finalize payment and logistics through marketplace messaging.',
                style: TextStyle(fontSize: 11, color: PipeBuyerColors.muted),
              ),
            ],
          ),
        ),
      );
}

class _AuctionListingDetails extends StatelessWidget {
  const _AuctionListingDetails({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final description =
        timedBuyingPublicMessage('${data['description'] ?? ''}');
    final hasSpecs = marketplaceListingSpecs(data).isNotEmpty;
    if (!hasSpecs && description.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasSpecs)
          MarketplaceListingSpecsGrid(
            listing: data,
            title: 'Asset overview',
            maxVisibleSpecs: 8,
          ),
        if (description.isNotEmpty) ...[
          if (hasSpecs) const SizedBox(height: 12),
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: PipeBuyerColors.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(
              color: PipeBuyerColors.graphite,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _BidPricingAnalytics extends StatelessWidget {
  const _BidPricingAnalytics({
    required this.askingPrice,
    required this.displayedBid,
    required this.nextBid,
    required this.increment,
    required this.quantity,
    required this.pricingBasis,
    required this.reserve,
    required this.buyNow,
  });

  final num? askingPrice;
  final num displayedBid;
  final num nextBid;
  final num increment;
  final int? quantity;
  final String pricingBasis;
  final num? reserve;
  final num? buyNow;

  @override
  Widget build(BuildContext context) {
    final totalBasis = pricingBasis.toLowerCase().contains('total');
    final multiplier = totalBasis ? 1 : (quantity ?? 1);
    final nextTotal = nextBid * multiplier;
    final difference = askingPrice == null ? null : nextBid - askingPrice!;
    final percent = askingPrice == null || askingPrice == 0
        ? null
        : difference! / askingPrice! * 100;
    final comparisonColor = difference == null || difference == 0
        ? PipeBuyerColors.slate
        : difference > 0
            ? PipeBuyerColors.success
            : PipeBuyerColors.orange;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics_outlined, color: PipeBuyerColors.orange),
                SizedBox(width: 8),
                Text(
                  'Timed offer analysis',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _row('Next minimum offer', marketplaceMoney(nextBid)),
            _row('Required increase', marketplaceMoney(increment)),
            if (quantity != null && !totalBasis)
              _row(
                'Next offer total',
                '${marketplaceMoney(nextTotal)} • $quantity units',
              ),
            if (difference != null && percent != null)
              _row(
                'Compared with asking',
                '${difference >= 0 ? 'â†‘' : 'â†“'} ${marketplaceMoney(difference.abs())} • ${percent.abs().toStringAsFixed(1)}%',
                color: comparisonColor,
              ),
            if (reserve != null && reserve! > 0)
              _row(
                'Reserve',
                displayedBid >= reserve!
                    ? 'Met'
                    : '${marketplaceMoney(reserve! - displayedBid)} away',
                color: displayedBid >= reserve!
                    ? PipeBuyerColors.success
                    : PipeBuyerColors.warning,
              ),
            if (buyNow != null && buyNow! > 0)
              _row('Buy It Now', marketplaceMoney(buyNow!)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: PipeBuyerColors.muted),
              ),
            ),
            Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      );
}

class _AuctionMediaGallery extends StatefulWidget {
  const _AuctionMediaGallery({required this.images});

  final List<String> images;

  @override
  State<_AuctionMediaGallery> createState() => _AuctionMediaGalleryState();
}

class _AuctionMediaGalleryState extends State<_AuctionMediaGallery> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).width < 600 ? 250 : 340,
              width: double.infinity,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: widget.images.length,
                    onPageChanged: (value) => setState(() => _selected = value),
                    itemBuilder: (context, index) =>
                        MarketplaceStorageMediaImage(
                      url: widget.images[index],
                      fit: BoxFit.cover,
                      fallback: const ColoredBox(
                        color: PipeBuyerColors.graphite,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 12,
                    top: 12,
                    child: _AuctionStateBadge(
                      label: 'SELLER PHOTOS',
                      color: PipeBuyerColors.success,
                      icon: Icons.photo_camera_outlined,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE6111820),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '${_selected + 1} / ${widget.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.images.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              'Swipe to view all ${widget.images.length} seller photos',
              style: const TextStyle(
                color: PipeBuyerColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      );
}

class _BidHistory extends StatelessWidget {
  const _BidHistory({required this.listingId, required this.listing});

  final String listingId;
  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('auction_bids')
            .where('listingId', isEqualTo: listingId)
            .orderBy('createdAt', descending: true)
            .limit(defaultActivityFeedLimit)
            .snapshots(),
        builder: (context, snapshot) {
          final bids = snapshot.data?.docs.toList() ?? []
            ..sort((a, b) {
              final at = a.data()['createdAt'] as Timestamp?;
              final bt = b.data()['createdAt'] as Timestamp?;
              return (bt?.millisecondsSinceEpoch ?? 0)
                  .compareTo(at?.millisecondsSinceEpoch ?? 0);
            });
          if (bids.isEmpty) {
            return const MarketplaceDataStateView(
              kind: MarketplaceDataStateKind.empty,
              title: 'No timed offers yet',
              message: 'The first eligible timed offer will appear here.',
              icon: Icons.timer_outlined,
              compact: true,
            );
          }
          return Column(
            children: [
              if (bids.length == defaultActivityFeedLimit)
                const ListTile(
                  dense: true,
                  leading: Icon(Icons.info_outline),
                  title: Text('Showing the latest 100 timed offers'),
                  subtitle: Text(
                    'The complete authoritative history remains stored for review.',
                  ),
                ),
              ...bids.map((bid) {
                final data = bid.data();
                final uid = FirebaseAuth.instance.currentUser?.uid;
                final start =
                    (listing['auctionStartAt'] as Timestamp?)?.toDate();
                final canWithdraw = listing['customAuction'] == true &&
                    start != null &&
                    !DateTime.now()
                        .isBefore(start.add(const Duration(days: 32))) &&
                    data['bidderUid'] == uid &&
                    data['status'] != 'withdrawn' &&
                    data['status'] != 'buy_now';
                final viewerOwnsOffer = uid != null && data['bidderUid'] == uid;
                final leadingOffer =
                    data['status'] == 'leading' || data['status'] == 'won';
                final surpassedOffer = data['status'] == 'outbid';
                final viewerRowColor = leadingOffer
                    ? PipeBuyerColors.success
                    : surpassedOffer
                        ? PipeBuyerColors.danger
                        : PipeBuyerColors.orangePressed;
                return Card(
                  color: viewerOwnsOffer
                      ? viewerRowColor.withValues(alpha: .07)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: viewerOwnsOffer
                          ? viewerRowColor.withValues(alpha: .58)
                          : Theme.of(context).dividerColor,
                      width: viewerOwnsOffer ? 1.4 : .7,
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -3),
                    minLeadingWidth: 32,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.orangeSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.timer_outlined,
                        color: PipeBuyerColors.orange,
                        size: 19,
                      ),
                    ),
                    title: TimedBuyingOfferActivityHeader(
                      bid: data,
                      viewerUid: uid,
                    ),
                    subtitle: Text(
                      data['status'] == 'withdrawn'
                          ? 'Withdrawn'
                          : data['createdAt'] is Timestamp
                              ? (data['createdAt'] as Timestamp)
                                  .toDate()
                                  .toLocal()
                                  .toString()
                              : 'Submitting…',
                    ),
                    trailing: data['status'] == 'withdrawn'
                        ? const Chip(label: Text('WITHDRAWN'))
                        : canWithdraw
                            ? TextButton.icon(
                                onPressed: () =>
                                    _confirmWithdrawal(context, bid.id),
                                icon: const Icon(Icons.undo, size: 18),
                                label: const Text('Withdraw'),
                              )
                            : null,
                  ),
                );
              }),
            ],
          );
        },
      );

  Future<void> _confirmWithdrawal(BuildContext context, String bidId) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Withdraw this timed offer?'),
            content: const Text(
              'This action is permanent. If this is the leading timed offer, the auction will return to the next eligible bid.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep timed offer'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Withdraw timed offer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    try {
      await MarketplaceAuctionRepository().withdrawBid(
        listingId: listingId,
        bidId: bidId,
      );
      if (context.mounted) {
        PipeFeedback.show(
          context,
          message: 'Timed offer withdrawn. Timed Buying totals were updated.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        PipeFeedback.show(
          context,
          message:
              timedBuyingPublicMessage(marketplaceCommandErrorMessage(error)),
          tone: PipeStatusTone.error,
        );
      }
    }
  }
}

class _AuctionLoadError extends StatelessWidget {
  const _AuctionLoadError({required this.details, required this.onRetry});

  final String details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.error,
        title: 'Timed Buying could not be loaded',
        message: details,
        primaryLabel: 'Try again',
        primaryIcon: Icons.refresh,
        onPrimary: onRetry,
      );
}

class _AuctionPageError extends StatelessWidget {
  const _AuctionPageError({required this.onRetry, required this.details});

  final VoidCallback onRetry;
  final String details;

  @override
  Widget build(BuildContext context) => MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.error,
        title: 'More Timed Buying listings could not be loaded',
        message: details,
        primaryLabel: 'Retry',
        primaryIcon: Icons.refresh,
        onPrimary: onRetry,
        compact: true,
      );
}

class _AuctionEmpty extends StatelessWidget {
  const _AuctionEmpty({
    required this.filter,
    required this.onCreate,
    this.onLoadMore,
  });

  final String filter;
  final VoidCallback onCreate;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) => MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.empty,
        icon: Icons.timer_outlined,
        title: 'No ${filter.toLowerCase()} Timed Buying listings',
        message:
            'Timed Buying listings will appear here separately from Marketplace inventory.',
        primaryLabel: 'Create a timed listing',
        primaryIcon: Icons.add,
        onPrimary: onCreate,
        secondaryLabel: onLoadMore == null ? null : 'Check more Timed Buying',
        onSecondary: onLoadMore,
      );
}

String _auctionTimeLabel(DateTime? start, DateTime? end) =>
    timedBuyingTimeLabel(start: start, end: end);

class _AuctionCountdown extends StatefulWidget {
  const _AuctionCountdown({required this.start, required this.end, this.style});

  final DateTime? start;
  final DateTime? end;
  final TextStyle? style;

  @override
  State<_AuctionCountdown> createState() => _AuctionCountdownState();
}

class _AuctionCountdownState extends State<_AuctionCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(_auctionTimeLabel(widget.start, widget.end), style: widget.style);
}
