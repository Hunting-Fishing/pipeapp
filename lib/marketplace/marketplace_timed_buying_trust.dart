import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_money.dart';
import 'marketplace_timed_buying_engagement.dart';

const Color _timedBuyingGold = Color(0xFFFFC247);
const int _viewerOfferQueryLimit = 500;

class TimedBuyingViewerParticipation {
  const TimedBuyingViewerParticipation({
    required this.hasParticipated,
    required this.leading,
    required this.viewerTopOffer,
    required this.currentLead,
    required this.ownOfferCount,
    required this.offersAhead,
    required this.amountBehind,
  });

  const TimedBuyingViewerParticipation.none()
      : hasParticipated = false,
        leading = false,
        viewerTopOffer = 0,
        currentLead = 0,
        ownOfferCount = 0,
        offersAhead = null,
        amountBehind = 0;

  final bool hasParticipated;
  final bool leading;
  final num viewerTopOffer;
  final num currentLead;
  final int ownOfferCount;
  final int? offersAhead;
  final num amountBehind;

  bool get outbid =>
      hasParticipated && !leading && currentLead > viewerTopOffer;

  String get compactStatusLabel {
    if (!hasParticipated) return '';
    if (leading) return 'YOU’RE LEADING';
    if (outbid && offersAhead != null && offersAhead! > 0) {
      final noun = offersAhead == 1 ? 'OFFER' : 'OFFERS';
      return 'OUTBID • $offersAhead $noun AHEAD';
    }
    if (outbid) return 'YOU’VE BEEN SURPASSED';
    return 'YOU HAVE A TIMED OFFER';
  }
}

TimedBuyingViewerParticipation deriveTimedBuyingViewerParticipation({
  required String? viewerUid,
  required Map<String, dynamic> listing,
  required Iterable<Map<String, dynamic>> viewerOffers,
}) {
  if (viewerUid == null || viewerUid.isEmpty) {
    return const TimedBuyingViewerParticipation.none();
  }

  final offers = viewerOffers
      .where((offer) => offer['bidderUid'] == viewerUid)
      .toList(growable: false);
  final leading = listing['highBidderUid'] == viewerUid;
  if (offers.isEmpty && !leading) {
    return const TimedBuyingViewerParticipation.none();
  }

  num viewerTop = 0;
  int? latestSequence;
  for (final offer in offers) {
    final amount = offer['amount'];
    if (amount is num && amount > viewerTop) viewerTop = amount;
    final sequence = offer['sequenceNumber'];
    if (sequence is num) {
      final normalized = sequence.toInt();
      if (latestSequence == null || normalized > latestSequence) {
        latestSequence = normalized;
      }
    }
  }

  final currentLead = (listing['currentBid'] as num?) ?? viewerTop;
  if (leading && viewerTop == 0) viewerTop = currentLead;
  final bidCount = (listing['bidCount'] as num?)?.toInt();
  final offersAhead = leading
      ? 0
      : bidCount != null && latestSequence != null
          ? math.max(0, bidCount - latestSequence)
          : null;
  final behind = math.max<num>(0, currentLead - viewerTop);

  return TimedBuyingViewerParticipation(
    hasParticipated: true,
    leading: leading,
    viewerTopOffer: viewerTop,
    currentLead: currentLead,
    ownOfferCount: offers.length,
    offersAhead: offersAhead,
    amountBehind: behind,
  );
}

class TimedBuyingViewerParticipationScope extends StatelessWidget {
  const TimedBuyingViewerParticipationScope({
    super.key,
    required this.viewerUid,
    required this.child,
  });

  final String? viewerUid;
  final Widget child;

  static TimedBuyingParticipationData? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TimedBuyingParticipationData>();

  @override
  Widget build(BuildContext context) {
    final uid = viewerUid;
    if (uid == null || uid.isEmpty) {
      return TimedBuyingParticipationData(
        viewerUid: null,
        offersByListing: const {},
        child: child,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('auction_bids')
          .where('bidderUid', isEqualTo: uid)
          .limit(_viewerOfferQueryLimit)
          .snapshots(),
      builder: (context, snapshot) {
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final document in snapshot.data?.docs ?? const []) {
          final data = document.data();
          final listingId = '${data['listingId'] ?? ''}'.trim();
          if (listingId.isEmpty) continue;
          grouped.putIfAbsent(listingId, () => []).add(data);
        }
        return TimedBuyingParticipationData(
          viewerUid: uid,
          offersByListing: grouped,
          child: child,
        );
      },
    );
  }
}

class TimedBuyingParticipationData extends InheritedWidget {
  const TimedBuyingParticipationData({
    super.key,
    required this.viewerUid,
    required this.offersByListing,
    required super.child,
  });

  final String? viewerUid;
  final Map<String, List<Map<String, dynamic>>> offersByListing;

  TimedBuyingViewerParticipation forListing(
    String listingId,
    Map<String, dynamic> listing,
  ) =>
      deriveTimedBuyingViewerParticipation(
        viewerUid: viewerUid,
        listing: listing,
        viewerOffers: offersByListing[listingId] ?? const [],
      );

  @override
  bool updateShouldNotify(covariant TimedBuyingParticipationData oldWidget) =>
      oldWidget.viewerUid != viewerUid ||
      !identical(oldWidget.offersByListing, offersByListing);
}

class TimedBuyingTrustFrame extends StatefulWidget {
  const TimedBuyingTrustFrame({
    super.key,
    required this.start,
    required this.end,
    required this.participation,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.radius = 18,
  });

  final DateTime? start;
  final DateTime? end;
  final TimedBuyingViewerParticipation participation;
  final Widget child;
  final EdgeInsetsGeometry margin;
  final double radius;

  @override
  State<TimedBuyingTrustFrame> createState() => _TimedBuyingTrustFrameState();
}

class _TimedBuyingTrustFrameState extends State<TimedBuyingTrustFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (widget.participation.hasParticipated) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant TimedBuyingTrustFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.participation.hasParticipated &&
        widget.participation.hasParticipated) {
      _controller.repeat();
    } else if (oldWidget.participation.hasParticipated &&
        !widget.participation.hasParticipated) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (widget.participation.hasParticipated &&
        !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TimedBuyingAttentionFrame(
        start: widget.start,
        end: widget.end,
        margin: widget.margin,
        radius: widget.radius,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => CustomPaint(
            foregroundPainter: widget.participation.hasParticipated
                ? _TimedBuyingParticipationPainter(
                    progress: _controller.value,
                    motion: _controller.isAnimating,
                    radius: math.max(4, widget.radius - 3).toDouble(),
                    leading: widget.participation.leading,
                  )
                : null,
            child: child,
          ),
          child: widget.child,
        ),
      );
}

class _TimedBuyingParticipationPainter extends CustomPainter {
  const _TimedBuyingParticipationPainter({
    required this.progress,
    required this.motion,
    required this.radius,
    required this.leading,
  });

  final double progress;
  final bool motion;
  final double radius;
  final bool leading;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(5.2);
    if (rect.width <= 0 || rect.height <= 0) return;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = leading ? 2.6 : 2.2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: [
          _timedBuyingGold.withValues(alpha: .35),
          _timedBuyingGold,
          Colors.white,
          const Color(0xFFFFE29A),
          _timedBuyingGold,
          _timedBuyingGold.withValues(alpha: .35),
        ],
        stops: const [0, .25, .42, .52, .66, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);

    final staticPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = _timedBuyingGold.withValues(alpha: leading ? .80 : .58);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(3.3), Radius.circular(radius - 2)),
      staticPaint,
    );

    if (!motion) return;
    final sparkle = Paint()..color = Colors.white.withValues(alpha: .96);
    final center = rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    for (var index = 0; index < 4; index++) {
      final angle = progress * math.pi * 2 + index * math.pi / 2;
      final point = Offset(
        center.dx + math.cos(angle) * rx,
        center.dy + math.sin(angle) * ry,
      );
      canvas.drawCircle(point, index == 0 ? 2.6 : 1.6, sparkle);
    }
  }

  @override
  bool shouldRepaint(covariant _TimedBuyingParticipationPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.motion != motion ||
      oldDelegate.leading != leading ||
      oldDelegate.radius != radius;
}

class TimedBuyingParticipationBadge extends StatelessWidget {
  const TimedBuyingParticipationBadge({
    super.key,
    required this.participation,
  });

  final TimedBuyingViewerParticipation participation;

  @override
  Widget build(BuildContext context) {
    if (!participation.hasParticipated) return const SizedBox.shrink();
    final color = participation.leading
        ? PipeBuyerColors.success
        : participation.outbid
            ? PipeBuyerColors.danger
            : _timedBuyingGold;
    final icon = participation.leading
        ? Icons.emoji_events_outlined
        : participation.outbid
            ? Icons.trending_up_outlined
            : Icons.schedule_send_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xF20B1118),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1.3),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .28), blurRadius: 10)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            participation.compactStatusLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .25,
            ),
          ),
        ],
      ),
    );
  }
}

class TimedBuyingParticipantIdentity {
  const TimedBuyingParticipantIdentity({
    required this.displayName,
    required this.verified,
    required this.accountType,
    required this.isViewer,
  });

  factory TimedBuyingParticipantIdentity.fromBid(
    Map<String, dynamic> bid, {
    required String? viewerUid,
  }) {
    final bidderUid = '${bid['bidderUid'] ?? ''}'.trim();
    final isViewer = viewerUid != null && bidderUid == viewerUid;
    final rawName = '${bid['bidderPublicName'] ?? ''}'.trim();
    return TimedBuyingParticipantIdentity(
      displayName: isViewer
          ? 'You'
          : rawName.isNotEmpty
              ? rawName
              : 'Authenticated buyer',
      verified: bid['bidderVerified'] == true,
      accountType: '${bid['bidderAccountType'] ?? ''}'.trim(),
      isViewer: isViewer,
    );
  }

  final String displayName;
  final bool verified;
  final String accountType;
  final bool isViewer;
}

class TimedBuyingOfferActivityHeader extends StatelessWidget {
  const TimedBuyingOfferActivityHeader({
    super.key,
    required this.bid,
    required this.viewerUid,
  });

  final Map<String, dynamic> bid;
  final String? viewerUid;

  @override
  Widget build(BuildContext context) {
    final identity = TimedBuyingParticipantIdentity.fromBid(
      bid,
      viewerUid: viewerUid,
    );
    final status = '${bid['status'] ?? ''}'.trim().toLowerCase();
    final sequence = (bid['sequenceNumber'] as num?)?.toInt();
    final statusLabel = switch (status) {
      'leading' => identity.isViewer ? 'YOU • LEADING' : 'LEADING',
      'won' => identity.isViewer ? 'YOU • WINNING OFFER' : 'WINNING OFFER',
      'outbid' => identity.isViewer ? 'YOU • OUTBID' : 'PREVIOUS OFFER',
      'withdrawn' => identity.isViewer ? 'YOU • WITHDRAWN' : 'WITHDRAWN',
      'buy_now' => 'BUY IT NOW',
      _ => identity.isViewer ? 'YOUR OFFER' : 'TIMED OFFER',
    };
    final statusColor = switch (status) {
      'leading' || 'won' => PipeBuyerColors.success,
      'outbid' when identity.isViewer => PipeBuyerColors.danger,
      'withdrawn' => PipeBuyerColors.muted,
      _ => PipeBuyerColors.orangePressed,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                marketplaceMoney(bid['amount'] as num? ?? 0),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withValues(alpha: .55)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .25,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 5,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              identity.verified
                  ? Icons.verified_user_outlined
                  : Icons.person_outline,
              size: 13,
              color: identity.verified
                  ? PipeBuyerColors.success
                  : PipeBuyerColors.muted,
            ),
            Text(
              identity.displayName,
              style: TextStyle(
                color: identity.isViewer
                    ? PipeBuyerColors.orangePressed
                    : PipeBuyerColors.graphite,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (identity.verified)
              const Text(
                'Verified member',
                style: TextStyle(
                  color: PipeBuyerColors.success,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (sequence != null)
              Text(
                'Offer #$sequence',
                style: const TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class TimedBuyingTrustStrip extends StatelessWidget {
  const TimedBuyingTrustStrip({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: PipeBuyerColors.success.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: PipeBuyerColors.success.withValues(alpha: .30),
          ),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.shield_outlined,
              color: PipeBuyerColors.success,
              size: 18,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Authenticated member activity • Every timed offer is tied to a signed-in PipeBuyer account. Verified badges indicate approved account verification. No anonymous timed offers.',
                style: TextStyle(
                  color: PipeBuyerColors.graphite,
                  fontSize: 10.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}
