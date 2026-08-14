import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/data/bounded_firestore_query.dart';
import '../core/design/pipe_buyer_theme.dart';

import 'marketplace_auction_repository.dart';
import 'marketplace_auction_settlement.dart';
import 'marketplace_command_client.dart';
import 'marketplace_avatar_image.dart';
import 'marketplace_money.dart';
import 'marketplace_freight_quote.dart';
import 'industrial_icon_assets.dart';
import 'marketplace_listing_status.dart';
import 'marketplace_listing_media.dart';
import 'marketplace_property_details.dart';
import 'marketplace_trucking_plan.dart';
import 'marketplace_deep_links.dart';
import 'marketplace_data_state.dart';
import 'marketplace_grid_density.dart';

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
    data, const ['auctionStartAt', 'auctionStart', 'startsAt', 'startAt', 'createdAt']);

DateTime? parseAuctionEnd(Map<String, dynamic> data) => parseAuctionDate(
    data, const ['auctionEndAt', 'auctionEnd', 'endsAt', 'endAt', 'closingAt', 'endTime']);

bool isAuctionEnded(Map<String, dynamic> data, DateTime now) {
  final end = parseAuctionEnd(data);
  final status =
      '${data['status'] ?? data['auctionStatus'] ?? data['saleStatus'] ?? ''}'
          .toLowerCase();
  final isStatusEnded = const {
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
  final isTimeEnded = end != null && !now.isBefore(end);
  return isStatusEnded || isTimeEnded;
}

bool isAuctionUpcoming(Map<String, dynamic> data, DateTime now) {
  final start = parseAuctionStart(data);
  return start != null && now.isBefore(start) && !isAuctionEnded(data, now);
}

bool isAuctionLive(Map<String, dynamic> data, DateTime now) {
  return !isAuctionUpcoming(data, now) && !isAuctionEnded(data, now);
}

/// Full-page auction destination used by browser refreshes and shared links.
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

  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: _auction,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: MarketplaceDataStateView.loading(
                title: 'Loading timed auction',
                message:
                    'Retrieving current bids, timing, and listing details…',
              ),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Timed auction')),
              body: _AuctionLoadError(
                details:
                    'Check your connection or account access, then try again.',
                onRetry: _retry,
              ),
            );
          }
          final documents = snapshot.data?.docs ?? const [];
          if (documents.isEmpty) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Timed auction'),
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
                    'This auction may have ended, been removed, or the link may be incorrect.',
                onRetry: _retry,
              ),
            );
          }
          return _AuctionDetails(document: documents.single, fullPage: true);
        },
      );
}

class MarketplaceAuctionsPage extends StatefulWidget {
  const MarketplaceAuctionsPage({super.key, required this.onCreateAuction});
  final VoidCallback onCreateAuction;

  @override
  State<MarketplaceAuctionsPage> createState() =>
      _MarketplaceAuctionsPageState();
}

class _MarketplaceAuctionsPageState extends State<MarketplaceAuctionsPage> {
  String _filter = 'Live';
  int _gridColumns = 4;
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

  Query<Map<String, dynamic>> _query(DateTime now) {
    return FirebaseFirestore.instance
        .collection('public_listings')
        .orderBy('createdAt', descending: true);
  }

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
        _query(DateTime.now()),
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
      setState(() => _loadError =
          error is FirebaseException && error.code == 'failed-precondition'
              ? 'The auction index is still being prepared. Try again shortly.'
              : 'Check your connection and try again.');
    } finally {
      if (mounted && generation == _queryGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final auctionDocuments = _documents
        .where((doc) => doc.data()['transactionType'] == 'Auction')
        .toList(growable: false);
    final liveCount = auctionDocuments
        .where((doc) => isAuctionLive(doc.data(), now))
        .length;
    final upcomingCount = auctionDocuments
        .where((doc) => isAuctionUpcoming(doc.data(), now))
        .length;
    final endedCount = auctionDocuments
        .where((doc) => isAuctionEnded(doc.data(), now))
        .length;
    final auctions = auctionDocuments.where((doc) {
      final data = doc.data();
      final ended = isAuctionEnded(data, now);
      final upcoming = isAuctionUpcoming(data, now);
      final live = isAuctionLive(data, now);

      if (_filter == 'My auctions') {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        return uid != null && data['sellerUid'] == uid;
      }
      if (_filter == 'Live') return live;
      if (_filter == 'Upcoming') return upcoming;
      if (_filter == 'Ended') return ended;
      return true;
    }).toList(growable: false);

    return Column(children: [
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
              onShowLegend: () => showMarketplaceListingLegend(context),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final filterControl = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'Live',
                          icon: Icon(Icons.fiber_manual_record),
                          label: Text('Live')),
                      ButtonSegment(
                          value: 'Upcoming',
                          icon: Icon(Icons.schedule_outlined),
                          label: Text('Upcoming')),
                      ButtonSegment(
                          value: 'Ended',
                          icon: Icon(Icons.history_outlined),
                          label: Text('Ended')),
                      ButtonSegment(
                          value: 'My auctions',
                          icon: Icon(Icons.person_outline),
                          label: Text('My auctions')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (value) {
                      final next = value.first;
                      if (next == _filter) return;
                      setState(() => _filter = next);
                      _loadPage(reset: true);
                    },
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      filterControl,
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: MarketplaceGridDensityBar(
                          selectedColumns: _gridColumns,
                          onChanged: (cols) =>
                              setState(() => _gridColumns = cols),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: filterControl),
                    const SizedBox(width: 10),
                    MarketplaceGridDensityBar(
                      selectedColumns: _gridColumns,
                      onChanged: (cols) =>
                          setState(() => _gridColumns = cols),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      Expanded(
        child: _loading && _documents.isEmpty
            ? const MarketplaceDataStateView.loading(
                title: 'Loading auctions',
                message: 'Retrieving current bidding and closing times…',
              )
            : _loadError != null && _documents.isEmpty
                ? _AuctionLoadError(
                    details: _loadError!,
                    onRetry: () => _loadPage(reset: true),
                  )
                : auctions.isEmpty
                    ? _AuctionEmpty(
                        filter: _filter,
                        onCreate: widget.onCreateAuction,
                        onLoadMore:
                            _hasMore && !_loading ? () => _loadPage() : null,
                      )
                    : Builder(builder: (context) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final effectiveCols =
                            MarketplaceGridDensityBar.resolveColumns(
                                screenWidth, _gridColumns);
                        if (effectiveCols > 1) {
                          return RefreshIndicator(
                            onRefresh: () => _loadPage(reset: true),
                            child: GridView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 8, 14, 24),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: effectiveCols,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: effectiveCols == 2 ? 390 : 365,
                              ),
                              itemCount: auctions.length + 1,
                              itemBuilder: (context, index) {
                                if (index < auctions.length) {
                                  return _AuctionCard(
                                      document: auctions[index]);
                                }
                                if (_loadError != null) {
                                  return _AuctionPageError(
                                      onRetry: () => _loadPage(),
                                      details: _loadError!);
                                }
                                if (_hasMore) {
                                  return Center(
                                    child: FilledButton.tonalIcon(
                                      onPressed:
                                          _loading ? null : () => _loadPage(),
                                      icon: const Icon(Icons.expand_more),
                                      label:
                                          const Text('Load more auctions'),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          );
                        }
                        return RefreshIndicator(
                          onRefresh: () => _loadPage(reset: true),
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(14, 4, 14, 24),
                            itemCount: auctions.length + 1,
                            itemBuilder: (context, index) {
                              if (index < auctions.length) {
                                return _AuctionCard(document: auctions[index]);
                              }
                              if (_loadError != null) {
                                return _AuctionPageError(
                                    onRetry: () => _loadPage(),
                                    details: _loadError!);
                              }
                              if (_hasMore) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: FilledButton.tonalIcon(
                                      onPressed:
                                          _loading ? null : () => _loadPage(),
                                      icon: _loading
                                          ? const SizedBox.square(
                                              dimension: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : const Icon(Icons.expand_more),
                                      label: Text(_loading
                                          ? 'Loading more…'
                                          : 'Load more auctions'),
                                    ),
                                  ),
                                );
                              }
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text(
                                    'All auctions loaded.',
                                    style: TextStyle(
                                        color: PipeBuyerColors.muted),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }),
      ),
    ]);
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
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PIPE BUYER AUCTIONS',
                style: TextStyle(
                  color: PipeBuyerColors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Timed auctions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Bid on oilfield pipe, equipment and industrial inventory with clear timing and auditable bid history.',
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
                label: const Text('Signals'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                ),
              ),
              FilledButton.icon(
                onPressed: onCreateAuction,
                icon: const Icon(Icons.add),
                label: const Text('Create auction'),
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
        }),
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
            Text('$value',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .45)),
          ],
        ),
      );
}

class _AuctionLoadError extends StatelessWidget {
  const _AuctionLoadError({required this.details, required this.onRetry});
  final String details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.error,
        title: 'Auctions could not be loaded',
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
        title: 'More auctions could not be loaded',
        message: details,
        primaryLabel: 'Retry',
        primaryIcon: Icons.refresh,
        onPrimary: onRetry,
        compact: true,
      );
}

class _AuctionCard extends StatelessWidget {
  const _AuctionCard({required this.document});
  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  @override
  Widget build(BuildContext context) {
    final data = document.data();
    final thumbnail = marketplaceListingThumbnailUrl(data);
    final current = data['currentBid'] as num? ?? 0;
    final starting = data['startingBid'] as num? ?? data['price'] as num? ?? 0;
    final start = parseAuctionStart(data);
    final end = parseAuctionEnd(data);
    final now = DateTime.now();
    final ended = isAuctionEnded(data, now);
    final live = isAuctionLive(data, now);
    final fallbackAssetPath = IndustrialIconAssets.forLabel(
            '${data['productType'] ?? data['title'] ?? ''}') ??
        IndustrialIconAssets.forLabel('${data['category'] ?? ''}') ??
        IndustrialIconAssets.complianceGavel;
    Widget fallbackArtwork() => DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
            ),
          ),
          child: Center(
            child: IndustrialAssetIcon(
              label: '${data['productType'] ?? data['title'] ?? 'Auction'}',
              assetPath: fallbackAssetPath,
              size: 118,
              fallback:
                  const Icon(Icons.gavel, size: 46, color: Colors.white70),
            ),
          ),
        );
    final presentation = MarketplaceListingPresentation.fromMap(data,
        currentUserUid: FirebaseAuth.instance.currentUser?.uid,
        isAuction: true,
        now: now);
    final statusColor = live
        ? PipeBuyerColors.danger
        : ended
            ? PipeBuyerColors.slate
            : PipeBuyerColors.industrialBlue;
    final statusLabel = live
        ? 'LIVE'
        : ended
            ? 'ENDED'
            : 'UPCOMING';

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
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
          children: [
            SizedBox(
              height: 174,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumbnail == null
                      ? fallbackArtwork()
                      : MarketplaceStorageMediaImage(
                          url: thumbnail,
                          fit: BoxFit.cover,
                          fallback: fallbackArtwork(),
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x62000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _AuctionStateBadge(
                      label: statusLabel,
                      color: statusColor,
                      icon: live
                          ? Icons.fiber_manual_record
                          : ended
                              ? Icons.flag_outlined
                              : Icons.schedule_outlined,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xD9111820),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  if (presentation.badges.isNotEmpty)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: MarketplaceListingBadges(
                        badges: presentation.badges,
                        compact: true,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data['title'] ?? 'Auction listing'}',
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
                      current > 0
                          ? marketplaceMoney(current)
                          : marketplaceMoney(starting),
                      style: const TextStyle(
                        color: PipeBuyerColors.orangePressed,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      current > 0 ? 'Current highest bid' : 'Starting bid',
                      style: const TextStyle(
                        color: PipeBuyerColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Divider(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.gavel_outlined,
                            size: 15, color: PipeBuyerColors.muted),
                        const SizedBox(width: 5),
                        Text('${data['bidCount'] ?? 0} bids',
                            style: const TextStyle(
                                color: PipeBuyerColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        const Icon(Icons.timer_outlined,
                            size: 15, color: PipeBuyerColors.muted),
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
                              fontWeight: live
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4)),
          ],
        ),
      );
}

class _AuctionDetails extends StatefulWidget {
  const _AuctionDetails({required this.document, this.fullPage = false});
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final bool fullPage;

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
  Widget build(BuildContext context) => StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.document.reference.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? widget.document.data();
        final current = data['currentBid'] as num? ?? 0;
        final starting =
            data['startingBid'] as num? ?? data['price'] as num? ?? 0;
        final displayedAmount = current > 0 ? current : starting;
        final pricingBasis =
            '${data['auctionPricingBasis'] ?? data['priceBasis'] ?? ''}';
        final auctionQuantity =
            (data['auctionQuantity'] as num? ?? data['quantity'] as num?)
                ?.toInt();
        final totalBasis = pricingBasis.toLowerCase().contains('total');
        final displayedTotal = totalBasis
            ? displayedAmount
            : displayedAmount * (auctionQuantity ?? 1);
        final increment = data['minimumBidIncrement'] as num? ?? 1;
        final buyNow = data['buyItNowPrice'] as num?;
        final next = current > 0 ? current + increment : starting;
        final start = parseAuctionStart(data);
        final end = parseAuctionEnd(data);
        final now = DateTime.now();
        final live = isAuctionLive(data, now);
        final ended = isAuctionEnded(data, now);
        final mine =
            data['sellerUid'] == FirebaseAuth.instance.currentUser?.uid;
        final auctionParticipant = mine ||
            data['highBidderUid'] == FirebaseAuth.instance.currentUser?.uid;
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
              final privateData = privateSnapshot.data?.data();
              final reserve =
                  mine ? (privateData?['reservePrice'] as num?) : null;
              final images = marketplaceListingImageUrls(data);
              final thumbnail = marketplaceListingThumbnailUrl(data);
              final orderedImages = thumbnail == null
                  ? images
                  : <String>[
                      thumbnail,
                      ...images.where((image) => image != thumbnail)
                    ];
              final content = SafeArea(
                  child: DraggableScrollableSheet(
                      expand: widget.fullPage,
                      initialChildSize: widget.fullPage ? 1 : .88,
                      minChildSize: widget.fullPage ? 1 : .55,
                      maxChildSize: widget.fullPage ? 1 : .96,
                      builder: (context, controller) => ListView(
                              controller: controller,
                              padding: const EdgeInsets.all(20),
                              children: [
                                _AuctionDetailHero(
                                  title:
                                      '${data['title'] ?? 'Auction listing'}',
                                  live: live,
                                  ended: ended,
                                  start: start,
                                  end: end,
                                  fullPage: widget.fullPage,
                                ),
                                const SizedBox(height: 14),
                                if (orderedImages.isNotEmpty)
                                  _AuctionMediaGallery(images: orderedImages),
                                if (orderedImages.isEmpty)
                                  Container(
                                      height: 230,
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              PipeBuyerColors.ink,
                                              PipeBuyerColors.graphite
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(18)),
                                      child: IndustrialAssetIcon(
                                          label:
                                              '${data['productType'] ?? data['title'] ?? 'Auction'}',
                                          assetPath: IndustrialIconAssets.forLabel(
                                                  '${data['productType'] ?? ''}') ??
                                              IndustrialIconAssets.forLabel(
                                                  '${data['category'] ?? ''}') ??
                                              IndustrialIconAssets
                                                  .complianceGavel,
                                          size: 174,
                                          borderRadius: 16,
                                          fallback: const Icon(Icons.gavel,
                                              color: Colors.white70,
                                              size: 76))),
                                const SizedBox(height: 14),
                                _AuctionBidSummary(
                                  displayedAmount: displayedAmount,
                                  current: current,
                                  pricingBasis: pricingBasis,
                                  auctionQuantity: auctionQuantity,
                                  totalBasis: totalBasis,
                                  displayedTotal: displayedTotal,
                                  live: live,
                                  start: start,
                                  end: end,
                                  bidCount:
                                      (data['bidCount'] as num?)?.toInt() ?? 0,
                                ),
                                if (mine && reserve != null && reserve > 0)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Card(
                                        margin: EdgeInsets.zero,
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                const Icon(
                                                    Icons.flag_outlined,
                                                    color: PipeBuyerColors
                                                        .orange),
                                                const SizedBox(width: 8),
                                                Text(
                                                  current >= reserve
                                                      ? 'Reserve has been met'
                                                      : 'Reserve not met',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900),
                                                ),
                                              ]),
                                              const SizedBox(height: 9),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                                child: LinearProgressIndicator(
                                                    minHeight: 8,
                                                    value: (current / reserve)
                                                        .clamp(0, 1),
                                                    color: current >= reserve
                                                        ? PipeBuyerColors.success
                                                        : PipeBuyerColors
                                                            .orange),
                                              ),
                                              const SizedBox(height: 7),
                                              Text(current >= reserve
                                                  ? 'The current leading bid satisfies your private reserve.'
                                                  : '${(current / reserve * 100).clamp(0, 100).toStringAsFixed(0)}% reached • ${marketplaceMoney((reserve - current).clamp(0, double.infinity))} remaining')
                                            ],
                                          ),
                                        ),
                                      )),
                                const SizedBox(height: 12),
                                _BidPricingAnalytics(
                                    askingPrice: data['price'] as num?,
                                    displayedBid: displayedAmount,
                                    nextBid: next,
                                    increment: increment,
                                    quantity: auctionQuantity,
                                    pricingBasis: pricingBasis,
                                    reserve: mine ? reserve : null,
                                    buyNow: buyNow),
                                if (!mine && reserve != null && reserve > 0)
                                  Align(
                                      alignment: Alignment.centerLeft,
                                      child: Chip(
                                          avatar: Icon(
                                              current >= reserve
                                                  ? Icons.check_circle_outline
                                                  : Icons.lock_outline,
                                              color: current >= reserve
                                                  ? PipeBuyerColors.success
                                                  : PipeBuyerColors.slate),
                                          label: Text(current >= reserve
                                              ? 'Reserve met'
                                              : 'Reserve not met'))),
                                if (mine &&
                                    current > 0 &&
                                    reserve != null &&
                                    current < reserve) ...[
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                      onPressed: _submitting
                                          ? null
                                          : () => _acceptBelowReserve(current),
                                      icon:
                                          const Icon(Icons.handshake_outlined),
                                      label: Text(
                                          'Accept leading bid • ${marketplaceMoney(current)}'),
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              PipeBuyerColors.orangePressed,
                                          minimumSize:
                                              const Size.fromHeight(50)))
                                ],
                                const SizedBox(height: 14),
                                Card(
                                  margin: EdgeInsets.zero,
                                  child: ListTile(
                                    leading: MarketplaceUserAvatar(
                                        userUid: '${data['sellerUid'] ?? ''}',
                                        photoUrl:
                                            '${data['sellerPhotoUrl'] ?? data['sellerAvatarUrl'] ?? ''}',
                                        size: 46,
                                        fallback: const Center(
                                            child: Icon(Icons.person_outline))),
                                    title: Text(
                                        '${data['sellerName'] ?? 'Marketplace seller'}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900)),
                                    subtitle: const Text(
                                        'View seller profile and active inventory'),
                                    trailing:
                                        const Icon(Icons.chevron_right_rounded),
                                    onTap: () => context.push(
                                        MarketplaceDeepLinks.profile(
                                            '${data['sellerUid'] ?? ''}')),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                MarketplaceDispatchQuoteCard(
                                    auction: true,
                                    onPressed: () =>
                                        MarketplaceFreightQuote.show(context,
                                            listingId: widget.document.id,
                                            listing: data,
                                            auction: true)),
                                const SizedBox(height: 14),
                                _AuctionListingDetails(data: data),
                                if (auctionParticipant &&
                                    (settlementReady || needsFinalization)) ...[
                                  const SizedBox(height: 14),
                                  MarketplaceAuctionSettlement(
                                    listingId: widget.document.id,
                                    listing: data,
                                  ),
                                ],
                                const SizedBox(height: 18),
                                if (!mine) ...[
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color:
                                              Theme.of(context).dividerColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Text('Place your bid',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 4),
                                        const Text(
                                            'Review the amount carefully before submitting a binding bid.',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: PipeBuyerColors.muted)),
                                        const SizedBox(height: 12),
                                        TextField(
                                            controller: _bid,
                                            enabled: live && !_submitting,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                                labelText:
                                                    'Your bid • minimum ${marketplaceMoney(next)}',
                                                prefixText: '\$ ',
                                                suffixText:
                                                    '${data['currency'] ?? 'CAD'}')),
                                        const SizedBox(height: 10),
                                        FilledButton.icon(
                                            onPressed: live && !_submitting
                                                ? _placeBid
                                                : null,
                                            icon: _submitting
                                                ? const SizedBox.square(
                                                    dimension: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white))
                                                : const Icon(Icons.gavel),
                                            label: Text(live
                                                ? 'Review and place bid'
                                                : 'Bidding unavailable'),
                                            style: FilledButton.styleFrom(
                                                minimumSize:
                                                    const Size.fromHeight(54))),
                                        if (live &&
                                            buyNow != null &&
                                            buyNow > 0) ...[
                                          const SizedBox(height: 8),
                                          OutlinedButton.icon(
                                              onPressed: _submitting
                                                  ? null
                                                  : () => _buyNow(buyNow),
                                              icon: const Icon(
                                                  Icons.flash_on_outlined),
                                              label: Text(
                                                  'Buy It Now • ${marketplaceMoney(buyNow)}'),
                                              style: OutlinedButton.styleFrom(
                                                  minimumSize: const Size
                                                      .fromHeight(52)))
                                        ],
                                        const SizedBox(height: 8),
                                        const Text(
                                            'Bids are binding. The seller and winning bidder finalize payment and logistics through marketplace messaging.',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: PipeBuyerColors.muted)),
                                      ],
                                    ),
                                  ),
                                ] else
                                  const Card(
                                      child: ListTile(
                                          leading: Icon(Icons.storefront),
                                          title: Text('This is your auction'),
                                          subtitle: Text(
                                              'Bid activity appears below.'))),
                                const SizedBox(height: 18),
                                const Text('Bid history',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 6),
                                _BidHistory(
                                    listingId: widget.document.id,
                                    listing: data)
                              ])));
              return widget.fullPage
                  ? Scaffold(
                      backgroundColor: PipeBuyerColors.canvas, body: content)
                  : content;
            });
      });

  Future<void> _placeBid() async {
    final amount = num.tryParse(_bid.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (amount == null) return;
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Place this bid?'),
                    content: Text(
                        'Submit a binding bid of ${marketplaceMoney(amount)} CAD?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Place bid'))
                    ])) ??
        false;
    if (!confirmed) return;
    setState(() => _submitting = true);
    try {
      await MarketplaceAuctionRepository()
          .placeBid(listingId: widget.document.id, amount: amount);
      if (mounted) {
        _bid.clear();
        PipeFeedback.show(
          context,
          message: 'Bid placed.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(error),
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
            builder: (context) => AlertDialog(
                    title: const Text('Buy this item now?'),
                    content: Text(
                        'Confirm purchase at ${marketplaceMoney(price)} CAD. This immediately closes the auction.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Confirm purchase'))
                    ])) ??
        false;
    if (!confirmed) return;
    setState(() => _submitting = true);
    try {
      await MarketplaceAuctionRepository()
          .buyNow(listingId: widget.document.id);
      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'Purchase confirmed. The auction is closed.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(error),
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
                    title: const Text('Accept below reserve?'),
                    content: Text(
                        'Accept the leading ${marketplaceMoney(amount)} bid and end this auction? The bidder will be notified immediately.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Keep auction open')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Accept and end auction'))
                    ])) ??
        false;
    if (!confirmed) return;
    setState(() => _submitting = true);
    try {
      await MarketplaceAuctionRepository()
          .acceptLeadingBidBelowReserve(listingId: widget.document.id);
      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'Leading bid accepted. The bidder was notified.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(error),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _AuctionDetailHero extends StatelessWidget {
  const _AuctionDetailHero({
    required this.title,
    required this.live,
    required this.ended,
    required this.start,
    required this.end,
    required this.fullPage,
  });

  final String title;
  final bool live;
  final bool ended;
  final DateTime? start;
  final DateTime? end;
  final bool fullPage;

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
            child: const Icon(Icons.gavel_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    const SizedBox(width: 8),
                    Flexible(
                      child: _AuctionCountdown(
                        start: start,
                        end: end,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
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
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: Icon(fullPage ? Icons.arrow_back : Icons.close,
                color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _AuctionBidSummary extends StatelessWidget {
  const _AuctionBidSummary({
    required this.displayedAmount,
    required this.current,
    required this.pricingBasis,
    required this.auctionQuantity,
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
  final int? auctionQuantity;
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final amount = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(current > 0 ? 'CURRENT HIGHEST BID' : 'STARTING BID',
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8)),
              const SizedBox(height: 4),
              Text(marketplaceMoney(displayedAmount),
                  style: const TextStyle(
                      color: PipeBuyerColors.orange,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5)),
              if (pricingBasis.isNotEmpty)
                Text(pricingBasis,
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w700)),
              if (!totalBasis && auctionQuantity != null)
                Text(
                    '$auctionQuantity units • Bid total ${marketplaceMoney(displayedTotal)}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white60)),
            ],
          );
          final timing = Column(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text('$bidCount ${bidCount == 1 ? 'bid' : 'bids'}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15)),
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
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [amount, const SizedBox(height: 14), timing],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [Expanded(child: amount), const SizedBox(width: 20), timing],
          );
        }),
      );
}

class _AuctionListingDetails extends StatelessWidget {
  const _AuctionListingDetails({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final details = <({IconData icon, String label, String value})>[];
    void add(IconData icon, String label, Object? raw) {
      final value = '${raw ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') {
        details.add((icon: icon, label: label, value: value));
      }
    }

    add(Icons.category_outlined, 'Category', data['category']);
    add(Icons.inventory_2_outlined, 'Item type', data['productType']);
    add(Icons.straighten_outlined, 'Pipe size', data['pipeSize']);
    add(Icons.layers_outlined, 'Pipe band', data['pipeBand']);
    add(Icons.factory_outlined, 'Brand', data['brand']);
    add(Icons.precision_manufacturing_outlined, 'Model', data['model']);
    add(Icons.calendar_today_outlined, 'Model year', data['modelYear']);
    final hours = data['machineHours'];
    if (hours != null) {
      add(Icons.timer_outlined, 'Machine hours', '$hours hours');
    }
    add(Icons.settings_outlined, 'Engine', data['engineDetails']);
    add(Icons.power_settings_new_outlined, 'Operating status',
        data['operatingStatus']);
    add(Icons.build_outlined, 'Maintenance history',
        data['maintenanceHistory']);
    add(Icons.confirmation_number_outlined, 'Serial number',
        data['serialNumber']);
    final quantity = data['quantity'];
    final basis = '${data['priceBasis'] ?? ''}'.trim();
    if (quantity != null) {
      add(Icons.numbers_outlined, 'Quantity',
          basis.isEmpty ? quantity : '$quantity • $basis');
    } else {
      add(Icons.numbers_outlined, 'Quantity / length',
          data['quantityAndLength']);
    }
    add(Icons.verified_outlined, 'Condition', data['condition']);
    add(Icons.fact_check_outlined, 'Inspection', data['inspectionStatus']);
    add(Icons.notes_outlined, 'Inspection details', data['inspectionDetails']);
    add(Icons.attachment_outlined, 'Included attachments', data['attachments']);
    add(Icons.real_estate_agent_outlined, 'Offering includes',
        data['propertyOffering']);
    add(Icons.account_balance_outlined, 'Interest offered',
        data['propertyInterest']);
    final acres = data['landAreaAcres'] as num?;
    final hectares = data['landAreaHectares'] as num?;
    final landInput = data['landAreaInputValue'] as num?;
    if (acres != null && hectares != null) {
      add(Icons.landscape_outlined, 'Land area',
          '${propertyMeasure(acres)} acres • ${propertyMeasure(hectares)} hectares');
    } else if (landInput != null) {
      add(Icons.landscape_outlined, 'Land area',
          '${propertyMeasure(landInput)} ${data['landAreaInputUnit'] ?? ''}');
    }
    final buildingArea = data['buildingAreaValue'] as num?;
    if (buildingArea != null) {
      add(Icons.warehouse_outlined, 'Building area',
          '${propertyMeasure(buildingArea)} ${data['buildingAreaUnit'] ?? ''}');
    }
    add(Icons.map_outlined, 'Zoning / permitted use', data['zoningOrUse']);
    void addMoney(IconData icon, String label, String field,
        {String period = ''}) {
      final value = data[field] as num?;
      if (value != null && value > 0) {
        add(icon, label, '${marketplaceMoney(value)}$period');
      }
    }

    addMoney(Icons.calendar_view_month_outlined, 'Monthly gross revenue',
        'monthlyRevenue',
        period: ' / month');
    addMoney(
        Icons.calendar_today_outlined, 'Annual gross revenue', 'annualRevenue',
        period: ' / year');
    addMoney(Icons.trending_up_outlined, 'Net operating income',
        'netOperatingIncome',
        period: ' / year');
    addMoney(
        Icons.receipt_long_outlined, 'Annual property tax', 'annualPropertyTax',
        period: ' / year');
    add(Icons.description_outlined, 'Lease / rights details',
        data['leaseDetails']);
    final propertyFeatures = (data['propertyFeatures'] as Iterable?)
        ?.map((value) => '$value'.trim())
        .where((value) => value.isNotEmpty)
        .join(' • ');
    add(Icons.check_circle_outline, 'Property features', propertyFeatures);
    final location = data['publicLocationName'] ??
        data['nearestTown'] ??
        data['publicLocation'] ??
        data['locationLabel'] ??
        data['location'] ??
        data['city'];
    add(Icons.location_on_outlined, 'Location', location);

    final description = '${data['description'] ?? ''}'.trim();
    if (details.isEmpty && description.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Listing details',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      if (details.isNotEmpty)
        Card(
            margin: EdgeInsets.zero,
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                    children: details
                        .map((detail) => ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: PipeBuyerColors.orangeSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(detail.icon,
                                  color: PipeBuyerColors.orange, size: 18),
                            ),
                            title: Text(detail.label,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: PipeBuyerColors.muted)),
                            subtitle: Text(detail.value,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700))))
                        .toList()))),
      if (description.isNotEmpty) ...[
        const SizedBox(height: 14),
        const Text('Description',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(description, style: const TextStyle(height: 1.4))
      ]
    ]);
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
    final asking = askingPrice;
    final difference = asking == null ? null : nextBid - asking;
    final percent =
        asking == null || asking == 0 ? null : (difference! / asking * 100);
    final comparisonColor = difference == null || difference == 0
        ? PipeBuyerColors.slate
        : difference > 0
            ? PipeBuyerColors.success
            : PipeBuyerColors.orange;

    return Card(
        margin: EdgeInsets.zero,
        child: Padding(
            padding: const EdgeInsets.all(15),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.analytics_outlined,
                    color: PipeBuyerColors.orange),
                SizedBox(width: 8),
                Text('Bid pricing analysis',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))
              ]),
              const SizedBox(height: 10),
              _analyticsRow('Next minimum bid', marketplaceMoney(nextBid)),
              _analyticsRow('Required increase', marketplaceMoney(increment)),
              if (quantity != null && !totalBasis)
                _analyticsRow('Next bid total',
                    '${marketplaceMoney(nextTotal)} • $quantity units'),
              if (asking != null)
                _analyticsRow('Compared with asking',
                    '${difference! >= 0 ? '↑' : '↓'} ${marketplaceMoney(difference.abs())} • ${percent!.abs().toStringAsFixed(1)}%',
                    color: comparisonColor),
              if (reserve != null && reserve! > 0)
                _analyticsRow(
                    'Reserve',
                    displayedBid >= reserve!
                        ? 'Met'
                        : '${marketplaceMoney(reserve! - displayedBid)} away',
                    color: displayedBid >= reserve!
                        ? PipeBuyerColors.success
                        : PipeBuyerColors.warning),
              if (buyNow != null && buyNow! > 0)
                _analyticsRow('Buy It Now', marketplaceMoney(buyNow!))
            ])));
  }

  Widget _analyticsRow(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(color: PipeBuyerColors.muted))),
        Text(value,
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w900, color: color))
      ]));
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
  Widget build(BuildContext context) => Column(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
                height: MediaQuery.sizeOf(context).width < 600 ? 250 : 340,
                width: double.infinity,
                child: Stack(children: [
                  PageView.builder(
                      itemCount: widget.images.length,
                      onPageChanged: (value) =>
                          setState(() => _selected = value),
                      itemBuilder: (context, index) =>
                          MarketplaceStorageMediaImage(
                              url: widget.images[index],
                              fit: BoxFit.cover,
                              fallback: const ColoredBox(
                                  color: PipeBuyerColors.graphite,
                                  child: Center(
                                      child: Icon(Icons.broken_image_outlined,
                                          color: Colors.white70, size: 48))))),
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
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: const Color(0xE6111820),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24)),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              child: Text(
                                  '${_selected + 1} / ${widget.images.length}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800)))))
                ]))),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 8),
          Text('Swipe to view all ${widget.images.length} seller photos',
              style: const TextStyle(
                  color: PipeBuyerColors.muted, fontSize: 12))
        ]
      ]);
}

class _BidHistory extends StatelessWidget {
  const _BidHistory({required this.listingId, required this.listing});
  final String listingId;
  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) => StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
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
          return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No bids yet. Be the first bidder.'));
        }
        return Column(children: [
          if (bids.length == defaultActivityFeedLimit)
            const ListTile(
              dense: true,
              leading: Icon(Icons.info_outline),
              title: Text('Showing the latest 100 bids'),
              subtitle: Text(
                  'The complete authoritative history remains stored for review.'),
            ),
          ...bids.map((bid) {
            final data = bid.data();
            final uid = FirebaseAuth.instance.currentUser?.uid;
            final start = (listing['auctionStartAt'] as Timestamp?)?.toDate();
            final canWithdraw = listing['customAuction'] == true &&
                start != null &&
                !DateTime.now().isBefore(start.add(const Duration(days: 32))) &&
                data['bidderUid'] == uid &&
                data['status'] != 'withdrawn' &&
                data['status'] != 'buy_now';
            return Card(
              margin: const EdgeInsets.only(bottom: 7),
              child: ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.orangeSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.gavel_outlined,
                        color: PipeBuyerColors.orange, size: 19),
                  ),
                  title: Text(marketplaceMoney(data['amount'] as num? ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(data['status'] == 'withdrawn'
                      ? 'Withdrawn'
                      : data['createdAt'] is Timestamp
                          ? (data['createdAt'] as Timestamp)
                              .toDate()
                              .toLocal()
                              .toString()
                          : 'Submitting…'),
                  trailing: data['status'] == 'withdrawn'
                      ? const Chip(label: Text('WITHDRAWN'))
                      : canWithdraw
                          ? TextButton.icon(
                              onPressed: () =>
                                  _confirmWithdrawal(context, bid.id),
                              icon: const Icon(Icons.undo, size: 18),
                              label: const Text('Withdraw'))
                          : null),
            );
          }),
        ]);
      });

  Future<void> _confirmWithdrawal(BuildContext context, String bidId) async {
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                    title: const Text('Withdraw this bid?'),
                    content: const Text(
                        'This action is permanent. If this is the leading bid, the auction will return to the next eligible bid.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Keep bid')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Withdraw bid'))
                    ])) ??
        false;
    if (!confirmed || !context.mounted) return;
    try {
      await MarketplaceAuctionRepository()
          .withdrawBid(listingId: listingId, bidId: bidId);
      if (context.mounted) {
        PipeFeedback.show(
          context,
          message: 'Bid withdrawn. Auction totals were updated.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(error),
          tone: PipeStatusTone.error,
        );
      }
    }
  }
}

class _AuctionEmpty extends StatelessWidget {
  const _AuctionEmpty(
      {required this.filter, required this.onCreate, this.onLoadMore});
  final String filter;
  final VoidCallback onCreate;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) => MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.empty,
        icon: Icons.gavel_outlined,
        title: 'No ${filter.toLowerCase()} auctions',
        message:
            'Timed auction listings will appear here separately from Marketplace inventory.',
        primaryLabel: 'Create an auction',
        primaryIcon: Icons.add,
        onPrimary: onCreate,
        secondaryLabel: onLoadMore == null ? null : 'Check more auctions',
        onSecondary: onLoadMore,
      );
}

String _auctionTimeLabel(DateTime? start, DateTime? end) {
  final now = DateTime.now();
  if (start == null || end == null) return 'Schedule unavailable';
  if (now.isBefore(start)) {
    return 'Starts in ${_duration(start.difference(now))}';
  }
  if (!now.isBefore(end)) return 'Ended';
  return 'Ends in ${_duration(end.difference(now))}';
}

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
        const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
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

String _duration(Duration value) {
  final days = value.inDays;
  final hours = value.inHours.remainder(24);
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  if (days > 0) return '${days}d ${hours}h ${minutes}m ${seconds}s';
  if (value.inHours > 0) {
    return '${value.inHours}h ${minutes}m ${seconds}s';
  }
  return '${value.inMinutes}m ${seconds}s';
}
