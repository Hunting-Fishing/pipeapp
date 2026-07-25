import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/data/bounded_firestore_query.dart';

import 'marketplace_auction_repository.dart';
import 'marketplace_auction_settlement.dart';
import 'marketplace_avatar_image.dart';
import 'marketplace_money.dart';
import 'marketplace_public_profile_page.dart';
import 'marketplace_freight_quote.dart';
import 'industrial_icon_assets.dart';
import 'marketplace_listing_status.dart';
import 'marketplace_listing_media.dart';
import 'marketplace_property_details.dart';
import 'marketplace_trucking_plan.dart';

class MarketplaceAuctionsPage extends StatefulWidget {
  const MarketplaceAuctionsPage({super.key, required this.onCreateAuction});
  final VoidCallback onCreateAuction;

  @override
  State<MarketplaceAuctionsPage> createState() =>
      _MarketplaceAuctionsPageState();
}

class _MarketplaceAuctionsPageState extends State<MarketplaceAuctionsPage> {
  String _filter = 'Live';
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _documents = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loading = false;
  bool _hasMore = true;
  String? _loadError;
  int _queryGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadPage(reset: true);
  }

  Query<Map<String, dynamic>> _query(DateTime now) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('public_listings')
        .where('status', isEqualTo: 'active')
        .where('transactionType', isEqualTo: 'Auction');
    switch (_filter) {
      case 'Upcoming':
        return query
            .where('auctionStartAt', isGreaterThan: Timestamp.fromDate(now))
            .orderBy('auctionStartAt');
      case 'Ended':
        return query
            .where('auctionEndAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
            .orderBy('auctionEndAt', descending: true);
      case 'My auctions':
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return query.where('sellerUid', isEqualTo: '__none__');
        return query
            .where('sellerUid', isEqualTo: uid)
            .orderBy('createdAt', descending: true);
      default:
        return query
            .where('auctionEndAt', isGreaterThan: Timestamp.fromDate(now))
            .orderBy('auctionEndAt');
    }
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
    final auctions = _documents.where((doc) {
      if (_filter != 'Live') return true;
      final start = (doc.data()['auctionStartAt'] as Timestamp?)?.toDate();
      return start != null && !now.isBefore(start);
    }).toList(growable: false);
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Timed auctions',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w900)),
                    Text('Bid live on verified oilfield inventory.',
                        style:
                            TextStyle(color: Color(0xFF66758A), fontSize: 12))
                  ])),
              IconButton.outlined(
                  tooltip: 'Listing color key',
                  onPressed: () => showMarketplaceListingLegend(context),
                  icon: const Icon(Icons.info_outline_rounded)),
              const SizedBox(width: 7),
              FilledButton.icon(
                  onPressed: widget.onCreateAuction,
                  icon: const Icon(Icons.add),
                  label: const Text('Sell'))
            ]),
            const SizedBox(height: 12),
            SingleChildScrollView(
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
                          label: Text('My auctions'))
                    ],
                    selected: {
                      _filter
                    },
                    onSelectionChanged: (value) {
                      final next = value.first;
                      if (next == _filter) return;
                      setState(() => _filter = next);
                      _loadPage(reset: true);
                    }))
          ])),
      Expanded(
          child: _loading && _documents.isEmpty
              ? const Center(child: CircularProgressIndicator())
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
                              _hasMore && !_loading ? () => _loadPage() : null)
                      : RefreshIndicator(
                          onRefresh: () => _loadPage(reset: true),
                          child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
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
                                  return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Center(
                                          child: FilledButton.tonalIcon(
                                              onPressed:
                                                  _loading ? null : _loadPage,
                                              icon: _loading
                                                  ? const SizedBox.square(
                                                      dimension: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2))
                                                  : const Icon(Icons
                                                      .expand_more_rounded),
                                              label: const Text(
                                                  'Load more auctions'))));
                                }
                                return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: Center(
                                        child: Text('All auctions loaded.',
                                            style: TextStyle(
                                                color: Color(0xFF66758A)))));
                              })))
    ]);
  }
}

class _AuctionLoadError extends StatelessWidget {
  const _AuctionLoadError({required this.details, required this.onRetry});
  final String details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined,
                size: 46, color: Colors.deepOrange),
            const SizedBox(height: 10),
            const Text('Auctions could not be loaded.',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(details,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again')),
          ])));
}

class _AuctionPageError extends StatelessWidget {
  const _AuctionPageError({required this.onRetry, required this.details});
  final VoidCallback onRetry;
  final String details;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        const Text('More auctions could not be loaded.'),
        Text(details,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.black54)),
        TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry')),
      ]));
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
    final end = (data['auctionEndAt'] as Timestamp?)?.toDate();
    final start = (data['auctionStartAt'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final live = start != null &&
        end != null &&
        !now.isBefore(start) &&
        now.isBefore(end);
    final ended = end != null && !now.isBefore(end);
    final fallbackAssetPath = IndustrialIconAssets.forLabel(
            '${data['productType'] ?? data['title'] ?? ''}') ??
        IndustrialIconAssets.forLabel('${data['category'] ?? ''}') ??
        IndustrialIconAssets.complianceGavel;
    Widget fallbackArtwork() => ColoredBox(
        color: const Color(0xFFE5F2FF),
        child: Center(
            child: IndustrialAssetIcon(
                label: '${data['productType'] ?? data['title'] ?? 'Auction'}',
                assetPath: fallbackAssetPath,
                size: 110,
                fallback: const Icon(Icons.gavel, size: 42))));
    final presentation = MarketplaceListingPresentation.fromMap(data,
        currentUserUid: FirebaseAuth.instance.currentUser?.uid,
        isAuction: true,
        now: now);
    return Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 12),
        elevation: presentation.emphasized ? 3 : 1,
        shadowColor: presentation.shadowColor,
        shape: RoundedRectangleBorder(
            side: BorderSide(
                color: presentation.borderColor,
                width: presentation.emphasized ? 2 : 1),
            borderRadius: BorderRadius.circular(14)),
        child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    _AuctionDetails(document: document, fullPage: true))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 122,
                  height: 150,
                  child: thumbnail == null
                      ? fallbackArtwork()
                      : MarketplaceStorageMediaImage(
                          url: thumbnail,
                          fit: BoxFit.cover,
                          fallback: fallbackArtwork())),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Chip(
                                  backgroundColor: live
                                      ? Colors.red.shade50
                                      : const Color(0xFFF0F5FA),
                                  avatar: Icon(
                                      live
                                          ? Icons.fiber_manual_record
                                          : ended
                                              ? Icons.flag_outlined
                                              : Icons.schedule,
                                      size: 15,
                                      color: live ? Colors.red : null),
                                  label: Text(live
                                      ? 'LIVE'
                                      : ended
                                          ? 'ENDED'
                                          : 'UPCOMING')),
                              const Spacer(),
                              const Icon(Icons.chevron_right)
                            ]),
                            if (presentation.badges.isNotEmpty) ...[
                              MarketplaceListingBadges(
                                  badges: presentation.badges, compact: true),
                              const SizedBox(height: 7),
                            ],
                            Text('${data['title'] ?? 'Auction listing'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 5),
                            Text(
                                current > 0
                                    ? 'Current bid ${marketplaceMoney(current)}'
                                    : 'Starting bid ${marketplaceMoney(starting)}',
                                style: const TextStyle(
                                    color: Color(0xFF0878E8),
                                    fontWeight: FontWeight.w900)),
                            Row(children: [
                              Text('${data['bidCount'] ?? 0} bids • ',
                                  style: const TextStyle(
                                      color: Color(0xFF66758A), fontSize: 12)),
                              Flexible(
                                  child: _AuctionCountdown(
                                      start: start,
                                      end: end,
                                      style: const TextStyle(
                                          color: Color(0xFF66758A),
                                          fontSize: 12)))
                            ])
                          ])))
            ])));
  }
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
        final start = (data['auctionStartAt'] as Timestamp?)?.toDate();
        final end = (data['auctionEndAt'] as Timestamp?)?.toDate();
        final now = DateTime.now();
        final live = start != null &&
            end != null &&
            !now.isBefore(start) &&
            now.isBefore(end);
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
                                Row(children: [
                                  const CircleAvatar(
                                      child: Icon(Icons.gavel_outlined)),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                      child: Text('Timed auction',
                                          style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900))),
                                  IconButton(
                                      tooltip: 'Back',
                                      onPressed: () => Navigator.pop(context),
                                      icon: Icon(widget.fullPage
                                          ? Icons.arrow_back
                                          : Icons.close))
                                ]),
                                Text('${data['title'] ?? 'Auction listing'}',
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 12),
                                if (orderedImages.isNotEmpty)
                                  _AuctionMediaGallery(images: orderedImages),
                                if (orderedImages.isEmpty)
                                  Container(
                                      height: 180,
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFEAF4FD),
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      child: IndustrialAssetIcon(
                                          label:
                                              '${data['productType'] ?? data['title'] ?? 'Auction'}',
                                          assetPath: IndustrialIconAssets.forLabel(
                                                  '${data['productType'] ?? ''}') ??
                                              IndustrialIconAssets.forLabel(
                                                  '${data['category'] ?? ''}') ??
                                              IndustrialIconAssets
                                                  .complianceGavel,
                                          size: 164,
                                          borderRadius: 16,
                                          fallback: const Icon(Icons.gavel,
                                              size: 76))),
                                if (orderedImages.isNotEmpty)
                                  const SizedBox(height: 12),
                                if (orderedImages.isEmpty)
                                  const SizedBox(height: 12),
                                Card(
                                    color: const Color(0xFFEAF4FD),
                                    child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(children: [
                                          Text(
                                              marketplaceMoney(displayedAmount),
                                              style: const TextStyle(
                                                  fontSize: 30,
                                                  fontWeight: FontWeight.w900)),
                                          Text(current > 0
                                              ? 'Current highest bid'
                                              : 'Starting bid'),
                                          if (pricingBasis.isNotEmpty)
                                            Text(pricingBasis,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF315A7D))),
                                          if (!totalBasis &&
                                              auctionQuantity != null)
                                            Text(
                                                '$auctionQuantity units • Bid total ${marketplaceMoney(displayedTotal)}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF66758A))),
                                          const SizedBox(height: 8),
                                          _AuctionCountdown(
                                              start: start,
                                              end: end,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: live
                                                      ? Colors.red
                                                      : Colors.black87))
                                        ]))),
                                if (mine && reserve != null && reserve > 0)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Column(children: [
                                        LinearProgressIndicator(
                                            value:
                                                (current / reserve).clamp(0, 1),
                                            color: current >= reserve
                                                ? Colors.green
                                                : Colors.deepOrange),
                                        const SizedBox(height: 4),
                                        Text(current >= reserve
                                            ? 'Reserve has been met'
                                            : 'Reserve not met • ${(current / reserve * 100).clamp(0, 100).toStringAsFixed(0)}% reached • ${marketplaceMoney((reserve - current).clamp(0, double.infinity))} remaining')
                                      ])),
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
                                                  ? Colors.green
                                                  : Colors.blueGrey),
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
                                          foregroundColor: Colors.deepOrange,
                                          minimumSize:
                                              const Size.fromHeight(50)))
                                ],
                                const SizedBox(height: 12),
                                ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: MarketplaceUserAvatar(
                                        userUid: '${data['sellerUid'] ?? ''}',
                                        photoUrl:
                                            '${data['sellerPhotoUrl'] ?? data['sellerAvatarUrl'] ?? ''}',
                                        size: 42,
                                        fallback: const Center(
                                            child: Icon(Icons.person_outline))),
                                    title: Text(
                                        '${data['sellerName'] ?? 'Marketplace seller'}'),
                                    subtitle: const Text(
                                        'View seller profile and listings'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                MarketplacePublicProfilePage(
                                                    userUid:
                                                        '${data['sellerUid'] ?? ''}',
                                                    fallbackName:
                                                        '${data['sellerName'] ?? 'Marketplace seller'}')))),
                                const Divider(),
                                MarketplaceDispatchQuoteCard(
                                    auction: true,
                                    onPressed: () =>
                                        MarketplaceFreightQuote.show(context,
                                            listingId: widget.document.id,
                                            listing: data,
                                            auction: true)),
                                const SizedBox(height: 12),
                                _AuctionListingDetails(data: data),
                                if (auctionParticipant &&
                                    (settlementReady || needsFinalization)) ...[
                                  const SizedBox(height: 12),
                                  MarketplaceAuctionSettlement(
                                    listingId: widget.document.id,
                                    listing: data,
                                  ),
                                ],
                                const SizedBox(height: 18),
                                if (!mine) ...[
                                  TextField(
                                      controller: _bid,
                                      enabled: live && !_submitting,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
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
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : const Icon(Icons.gavel),
                                      label: Text(live
                                          ? 'Review and place bid'
                                          : 'Bidding unavailable'),
                                      style: FilledButton.styleFrom(
                                          minimumSize:
                                              const Size.fromHeight(54))),
                                  if (live && buyNow != null && buyNow > 0) ...[
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                        onPressed: _submitting
                                            ? null
                                            : () => _buyNow(buyNow),
                                        icon:
                                            const Icon(Icons.flash_on_outlined),
                                        label: Text(
                                            'Buy It Now • ${marketplaceMoney(buyNow)}'),
                                        style: OutlinedButton.styleFrom(
                                            minimumSize:
                                                const Size.fromHeight(52)))
                                  ],
                                  const Text(
                                      'Bids are binding. The seller and winning bidder finalize payment and logistics through marketplace messaging.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF66758A))),
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
                                _BidHistory(
                                    listingId: widget.document.id,
                                    listing: data)
                              ])));
              return widget.fullPage
                  ? Scaffold(
                      backgroundColor: const Color(0xFFF6F8FB), body: content)
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.green, content: Text('Bid placed.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Purchase confirmed. The auction is closed.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Leading bid accepted. The bidder was notified.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
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
                            leading: Icon(detail.icon,
                                color: const Color(0xFF0878E8)),
                            title: Text(detail.label,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF66758A))),
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
        ? Colors.blueGrey
        : difference > 0
            ? Colors.green
            : Colors.deepOrange;

    return Card(
        color: const Color(0xFFF7FAFD),
        margin: EdgeInsets.zero,
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.analytics_outlined, color: Color(0xFF0878E8)),
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
                        ? Colors.green
                        : Colors.orange),
              if (buyNow != null && buyNow! > 0)
                _analyticsRow('Buy It Now', marketplaceMoney(buyNow!))
            ])));
  }

  Widget _analyticsRow(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(children: [
        Expanded(
            child:
                Text(label, style: const TextStyle(color: Color(0xFF66758A)))),
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
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
                height: 260,
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
                                  color: Color(0xFFE5F2FF),
                                  child: Center(
                                      child: Icon(Icons.broken_image_outlined,
                                          size: 48))))),
                  Positioned(
                      right: 12,
                      bottom: 12,
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20)),
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
          Text('Swipe to view all ${widget.images.length} photos',
              style: const TextStyle(color: Color(0xFF66758A), fontSize: 12))
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
        return Column(
            children: bids.map((bid) {
          final data = bid.data();
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final start = (listing['auctionStartAt'] as Timestamp?)?.toDate();
          final canWithdraw = listing['customAuction'] == true &&
              start != null &&
              !DateTime.now().isBefore(start.add(const Duration(days: 32))) &&
              data['bidderUid'] == uid &&
              data['status'] != 'withdrawn' &&
              data['status'] != 'buy_now';
          return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(marketplaceMoney(data['amount'] as num? ?? 0)),
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
                          onPressed: () => _confirmWithdrawal(context, bid.id),
                          icon: const Icon(Icons.undo, size: 18),
                          label: const Text('Withdraw'))
                      : null);
        }).toList());
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Bid withdrawn. Auction totals were updated.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
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
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.gavel_outlined,
                size: 58, color: Color(0xFF66758A)),
            const SizedBox(height: 12),
            Text('No ${filter.toLowerCase()} auctions',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text(
                'Timed auction listings will appear here, separately from marketplace inventory.',
                textAlign: TextAlign.center),
            if (onLoadMore != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: onLoadMore,
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('Check more auctions')),
            ],
            const SizedBox(height: 15),
            FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create an auction'))
          ])));
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
