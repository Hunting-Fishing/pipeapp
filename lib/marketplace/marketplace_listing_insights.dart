import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';
import 'marketplace_money.dart';

class MarketplaceListingInsightsDialog extends StatefulWidget {
  const MarketplaceListingInsightsDialog({
    super.key,
    required this.listingId,
    required this.listingTitle,
  });

  final String listingId;
  final String listingTitle;

  static Future<void> show(
    BuildContext context, {
    required String listingId,
    required String listingTitle,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => MarketplaceListingInsightsDialog(
        listingId: listingId,
        listingTitle: listingTitle,
      ),
    );
  }

  @override
  State<MarketplaceListingInsightsDialog> createState() =>
      _MarketplaceListingInsightsDialogState();
}

class _MarketplaceListingInsightsDialogState
    extends State<MarketplaceListingInsightsDialog> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() => MarketplaceCommandClient().execute(
        'getMarketplaceListingInsights',
        {'listingId': widget.listingId},
        timeout: const Duration(seconds: 45),
      );

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 320,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _errorState(snapshot.error!);
              }
              return _content(snapshot.data ?? const {});
            },
          ),
        ),
      );

  Widget _errorState(Object error) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.analytics_outlined,
              size: 42,
              color: PipeBuyerColors.orange,
            ),
            const SizedBox(height: 12),
            const Text(
              'Listing insights could not be loaded',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              marketplaceCommandErrorMessage(
                error,
                fallback:
                    'Comparable Marketplace analytics are temporarily unavailable. Try again.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      );

  Widget _content(Map<String, dynamic> data) {
    final pricing = data['comparablePricing'] is Map
        ? Map<String, dynamic>.from(data['comparablePricing'] as Map)
        : const <String, dynamic>{};
    final engagement = data['engagement'] is Map
        ? Map<String, dynamic>.from(data['engagement'] as Map)
        : const <String, dynamic>{};
    final suggestions = (data['suggestions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final similar = (data['similarListings'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final comparableCount = (pricing['sampleCount'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: PipeBuyerColors.orangeSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: PipeBuyerColors.orangePressed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Smart listing suggestions',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.listingTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: PipeBuyerColors.industrialBlue.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: PipeBuyerColors.industrialBlue.withValues(alpha: .18),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: PipeBuyerColors.industrialBlue,
                  size: 20,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'These are Marketplace analytics based on seller-provided listings and activity. They are not an appraisal, certified valuation, legal limit, or guarantee of sale price.',
                    style: TextStyle(fontSize: 12.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _pricingSummary(pricing, engagement, comparableCount),
          const SizedBox(height: 18),
          const Text(
            'Recommended next steps',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          if (suggestions.isEmpty)
            _emptyCard(
              icon: Icons.check_circle_outline_rounded,
              title: 'No major changes suggested yet',
              message:
                  'As more comparable inventory and buyer activity accumulate, Pipe Buyer will have more signals to analyze.',
            )
          else
            ...suggestions.map(_suggestionCard),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Similar active listings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${similar.length} shown',
                style: const TextStyle(
                  color: PipeBuyerColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (similar.isEmpty)
            _emptyCard(
              icon: Icons.manage_search_outlined,
              title: 'Not enough comparable inventory yet',
              message:
                  'This is normal in a new marketplace. Suggestions will improve as matching inventory is listed and transacted.',
            )
          else
            ...similar.map(_similarCard),
        ],
      ),
    );
  }

  Widget _pricingSummary(
    Map<String, dynamic> pricing,
    Map<String, dynamic> engagement,
    int comparableCount,
  ) {
    final median = pricing['median'] as num?;
    final low = pricing['low'] as num?;
    final high = pricing['high'] as num?;
    Widget metric(String label, String value, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: PipeBuyerColors.canvas,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 19, color: PipeBuyerColors.orangePressed),
                const SizedBox(height: 8),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          metric(
            'Comparable median',
            median == null ? 'Building data' : marketplaceMoney(median),
            Icons.price_check_outlined,
          ),
          metric(
            'Comparable range',
            low == null || high == null
                ? '$comparableCount samples'
                : '${marketplaceMoney(low)} – ${marketplaceMoney(high)}',
            Icons.compare_arrows_rounded,
          ),
          metric(
            'Buyer signals',
            '${(engagement['views'] as num?)?.toInt() ?? 0} views · ${(engagement['saves'] as num?)?.toInt() ?? 0} saves · ${(engagement['offers'] as num?)?.toInt() ?? 0} offers',
            Icons.insights_outlined,
          ),
        ];
        if (constraints.maxWidth >= 680) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cards[0],
              const SizedBox(width: 10),
              cards[1],
              const SizedBox(width: 10),
              cards[2],
            ],
          );
        }
        return Column(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              SizedBox(width: double.infinity, child: cards[index]),
              if (index < cards.length - 1) const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _suggestionCard(Map<String, dynamic> suggestion) {
    final high = suggestion['priority'] == 'high';
    final color =
        high ? PipeBuyerColors.orange : PipeBuyerColors.industrialBlue;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            high ? Icons.bolt_rounded : Icons.lightbulb_outline_rounded,
            color: color,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${suggestion['title'] ?? 'Suggestion'}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${suggestion['detail'] ?? ''}',
                  style: const TextStyle(fontSize: 12.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _similarCard(Map<String, dynamic> listing) {
    final price = listing['price'] as num?;
    final score = (listing['similarityScore'] as num?)?.round() ?? 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PipeBuyerColors.orangeSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$score',
              style: const TextStyle(
                color: PipeBuyerColors.orangePressed,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${listing['title'] ?? 'Marketplace listing'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${listing['productType'] ?? ''} · ${listing['condition'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            price == null ? 'Price unavailable' : marketplaceMoney(price),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: PipeBuyerColors.canvas,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: PipeBuyerColors.industrialBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      );
}
