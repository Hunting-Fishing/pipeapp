import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'marketplace_trust_risk_policy.dart';

/// Administrator-facing, read-only Trust & Safety prioritization queue.
///
/// The queue intentionally performs no moderation write and exposes no
/// automatic enforcement action. Existing moderation commands remain the only
/// path for final human decisions.
class MarketplaceTrustRiskQueue extends StatefulWidget {
  const MarketplaceTrustRiskQueue({super.key});

  @override
  State<MarketplaceTrustRiskQueue> createState() =>
      _MarketplaceTrustRiskQueueState();
}

class _MarketplaceTrustRiskQueueState extends State<MarketplaceTrustRiskQueue> {
  TrustRiskTier? _tierFilter;

  static const _reviewStatuses = {
    'pending',
    'information_requested',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('trust_reports')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, reportSnapshot) {
        if (reportSnapshot.hasError) {
          return _StateMessage(
            icon: Icons.error_outline,
            title: 'Trust review queue unavailable',
            message: '${reportSnapshot.error}',
          );
        }
        if (!reportSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('public_listings')
              .limit(250)
              .snapshots(),
          builder: (context, listingSnapshot) {
            if (listingSnapshot.hasError) {
              return _StateMessage(
                icon: Icons.error_outline,
                title: 'Listing comparison data unavailable',
                message: '${listingSnapshot.error}',
              );
            }
            if (!listingSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final cases = _buildCases(
              reportSnapshot.data!.docs,
              listingSnapshot.data!.docs,
            );
            final visible = _tierFilter == null
                ? cases
                : cases
                    .where((item) => item.assessment.tier == _tierFilter)
                    .toList(growable: false);

            final high = cases
                .where((item) => item.assessment.tier == TrustRiskTier.high)
                .length;
            final elevated = cases
                .where((item) => item.assessment.tier == TrustRiskTier.elevated)
                .length;
            final normal = cases
                .where((item) => item.assessment.tier == TrustRiskTier.normal)
                .length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
              children: [
                _buildHeader(context),
                const SizedBox(height: 14),
                _buildMetrics(high, elevated, normal),
                const SizedBox(height: 12),
                _buildFilterBar(),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  const _StateMessage(
                    icon: Icons.verified_user_outlined,
                    title: 'No cases in this review tier',
                    message:
                        'Open Trust & Safety reports will appear here when they match the selected priority tier.',
                  )
                else
                  ...visible.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TrustRiskCaseCard(item: item),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF17212B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                icon: Icons.gpp_maybe_outlined,
                label: 'ANTI-SCAM REVIEW',
                color: Color(0xFFFF6A00),
              ),
              _StatusPill(
                icon: Icons.person_search_outlined,
                label: 'HUMAN REVIEW ONLY',
                color: Color(0xFF38BDF8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Trust & Safety risk priority',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Orders open safety cases by explainable review signals. The score is not a guilt score and never removes a listing, suspends an account, or blocks a transaction automatically.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 10),
          const Text(
            'Policy: ${MarketplaceTrustRiskPolicy.revision}',
            style: TextStyle(
              color: Color(0xFFFFB47A),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(int high, int elevated, int normal) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final width = wide
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'High priority',
                value: '$high',
                icon: Icons.priority_high,
                color: const Color(0xFFB91C1C),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Elevated',
                value: '$elevated',
                icon: Icons.warning_amber_outlined,
                color: const Color(0xFFD97706),
              ),
            ),
            SizedBox(
              width: width,
              child: _MetricCard(
                label: 'Normal',
                value: '$normal',
                icon: Icons.fact_check_outlined,
                color: const Color(0xFF475569),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('All open cases'),
          selected: _tierFilter == null,
          onSelected: (_) => setState(() => _tierFilter = null),
        ),
        ChoiceChip(
          label: const Text('High'),
          selected: _tierFilter == TrustRiskTier.high,
          onSelected: (_) => setState(() => _tierFilter = TrustRiskTier.high),
        ),
        ChoiceChip(
          label: const Text('Elevated'),
          selected: _tierFilter == TrustRiskTier.elevated,
          onSelected: (_) =>
              setState(() => _tierFilter = TrustRiskTier.elevated),
        ),
        ChoiceChip(
          label: const Text('Normal'),
          selected: _tierFilter == TrustRiskTier.normal,
          onSelected: (_) =>
              setState(() => _tierFilter = TrustRiskTier.normal),
        ),
      ],
    );
  }

  List<TrustRiskQueueItem> _buildCases(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reportDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> listingDocs,
  ) {
    final listingsById = {
      for (final document in listingDocs)
        document.id: {'id': document.id, ...document.data()},
    };
    final allListings = listingsById.values.toList(growable: false);
    final items = <TrustRiskQueueItem>[];

    for (final reportDoc in reportDocs) {
      final report = {'id': reportDoc.id, ...reportDoc.data()};
      final status = '${report['status'] ?? ''}'.trim().toLowerCase();
      if (!_reviewStatuses.contains(status)) continue;

      final listingId = '${report['listingId'] ?? ''}'.trim();
      final listing = listingId.isEmpty ? null : listingsById[listingId];
      final peerPrices = <double>[];
      if (listing != null) {
        for (final candidate in allListings) {
          if (candidate['id'] == listingId) continue;
          if (!MarketplaceTrustRiskPolicy.comparableListing(candidate, listing)) {
            continue;
          }
          final price = MarketplaceTrustRiskPolicy.normalizedUnitPrice(candidate);
          if (price != null) peerPrices.add(price);
        }
      }

      final assessment = MarketplaceTrustRiskPolicy.assess(
        report: report,
        listing: listing,
        comparableUnitPrices: peerPrices,
      );
      items.add(
        TrustRiskQueueItem(
          reportId: reportDoc.id,
          report: report,
          listing: listing,
          assessment: assessment,
          createdAtMillis: _timestampMillis(report['createdAt']),
        ),
      );
    }

    items.sort((left, right) {
      final risk = right.assessment.score.compareTo(left.assessment.score);
      if (risk != 0) return risk;
      return right.createdAtMillis.compareTo(left.createdAtMillis);
    });
    return items;
  }

  int _timestampMillis(Object? value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return 0;
  }
}

class TrustRiskQueueItem {
  const TrustRiskQueueItem({
    required this.reportId,
    required this.report,
    required this.listing,
    required this.assessment,
    required this.createdAtMillis,
  });

  final String reportId;
  final Map<String, dynamic> report;
  final Map<String, dynamic>? listing;
  final TrustRiskAssessment assessment;
  final int createdAtMillis;
}

class TrustRiskCaseCard extends StatelessWidget {
  const TrustRiskCaseCard({super.key, required this.item});

  final TrustRiskQueueItem item;

  @override
  Widget build(BuildContext context) {
    final tierColor = switch (item.assessment.tier) {
      TrustRiskTier.high => const Color(0xFFB91C1C),
      TrustRiskTier.elevated => const Color(0xFFD97706),
      TrustRiskTier.normal => const Color(0xFF475569),
    };
    final report = item.report;
    final listing = item.listing;
    final reasonLabel = '${report['reasonLabel'] ?? report['reason'] ?? 'Safety report'}';
    final source = '${report['source'] ?? 'user'}';
    final target = '${report['targetType'] ?? 'unknown'}';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tierColor.withValues(alpha: .22)),
                  ),
                  child: Text(
                    '${item.assessment.score}',
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _StatusPill(
                            icon: Icons.flag_outlined,
                            label: item.assessment.tierLabel,
                            color: tierColor,
                          ),
                          _StatusPill(
                            icon: source == 'automated'
                                ? Icons.memory_outlined
                                : Icons.person_outline,
                            label: source.toUpperCase(),
                            color: const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reasonLabel,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Report ${item.reportId} • ${target.toUpperCase()}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (listing != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    Text(
                      '${listing['title'] ?? 'Marketplace listing'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (MarketplaceTrustRiskPolicy.normalizedUnitPrice(listing) case final unitPrice?)
                      Text(
                        'Unit basis: ${_money(unitPrice, '${listing['currency'] ?? 'CAD'}')}',
                        style: const TextStyle(color: Color(0xFF475569)),
                      ),
                    if ('${listing['category'] ?? ''}'.trim().isNotEmpty)
                      Text(
                        '${listing['category']}',
                        style: const TextStyle(color: Color(0xFF475569)),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Why this case is prioritized',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 7),
            ...item.assessment.signals.map(
              (signal) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right, size: 19, color: tierColor),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${signal.label} (+${signal.points})',
                        style: const TextStyle(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'Human decision required. A risk score is only a review-order signal; it is not proof of fraud and cannot enforce an account or listing action.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _money(double amount, String currency) {
    final formatted = amount >= 1000
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '${currency.toUpperCase()} \$$formatted';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .25,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: const Color(0xFF64748B)),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
