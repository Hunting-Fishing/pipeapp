import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'marketplace_command_client.dart';

const String marketplaceFeeScheduleRevision = '2026-10-16-sale-only-v4';
const String marketplaceSalePathDisclosure =
    'List with an asking price, receive an offer, and choose whether to accept it. '
    'An accepted offer creates the sale transaction; a message or offer by itself does not.';
const String timedBuyingSalePathDisclosure =
    'Set a timed bidding window, minimum increase, optional reserve, and optional Buy It Now price. '
    'A winning bid, an accepted below-reserve bid, or Buy It Now creates the sale transaction.';
const String sharedSaleFeeDisclosure =
    'Both paths list for free and use the same server-verified seller fee at settlement. '
    'With Pipe Buyer checkout, the fee is retained from seller proceeds after the buyer pays. '
    'With confirmed external settlement, the seller pays the fee separately before completion. '
    'Placing a bid does not create a fee.';
const String wantedDiscoveryDisclosure =
    'Wanted ads help buyers and sellers find matching inventory. They are not a third sale path: '
    'the purchase must continue through a matched Marketplace listing or Timed Buying.';

class MarketplaceFeeCatalog {
  const MarketplaceFeeCatalog({
    required this.revision,
    required this.listingFee,
    required this.pipeUnitFee,
    required this.pipePercentageCap,
    required this.pipeMaximumFee,
    required this.equipmentMinimumFee,
    required this.equipmentMaximumFee,
    required this.brackets,
    this.verified = true,
  });

  factory MarketplaceFeeCatalog.fromMap(Map<String, dynamic> data) {
    final listingFees = Map<String, dynamic>.from(
      data['listingFeeByCurrency'] as Map? ?? const {},
    );
    final listingUsd = Map<String, dynamic>.from(
      listingFees['USD'] as Map? ?? const {},
    );
    final pipe = Map<String, dynamic>.from(data['pipe'] as Map? ?? const {});
    final equipment =
        Map<String, dynamic>.from(data['equipment'] as Map? ?? const {});
    final pipeUnits = Map<String, dynamic>.from(
      pipe['unitFeeByCurrency'] as Map? ?? const {},
    );
    final pipeUsd =
        Map<String, dynamic>.from(pipeUnits['USD'] as Map? ?? const {});
    final pipeMaximums = Map<String, dynamic>.from(
      pipe['maximumFeeByCurrency'] as Map? ?? const {},
    );
    final pipeMaximumUsd = Map<String, dynamic>.from(
      pipeMaximums['USD'] as Map? ?? const {},
    );
    final equipmentMaximums = Map<String, dynamic>.from(
      equipment['maximumFeeByCurrency'] as Map? ?? const {},
    );
    final equipmentMaximumUsd = Map<String, dynamic>.from(
      equipmentMaximums['USD'] as Map? ?? const {},
    );
    final equipmentMinimums = Map<String, dynamic>.from(
      equipment['minimumFeeByCurrency'] as Map? ?? const {},
    );
    final equipmentMinimumUsd = Map<String, dynamic>.from(
      equipmentMinimums['USD'] as Map? ?? const {},
    );
    final brackets = (equipment['brackets'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => MarketplaceFeeBracket(
            upperBound: (item['upToExclusive'] as num?)?.toDouble(),
            percentage: (item['feePercent'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList(growable: false);
    final revision = '${data['scheduleRevision'] ?? ''}'.trim();
    final listingFee = (listingUsd['amount'] as num?)?.toDouble();
    final pipeUnitFee = (pipeUsd['amount'] as num?)?.toDouble();
    final pipePercentageCap = (pipe['percentageCap'] as num?)?.toDouble();
    final pipeMaximumFee = (pipeMaximumUsd['amount'] as num?)?.toDouble();
    final equipmentMinimumFee =
        (equipmentMinimumUsd['amount'] as num?)?.toDouble();
    final equipmentMaximumFee =
        (equipmentMaximumUsd['amount'] as num?)?.toDouble();
    if (revision.isEmpty ||
        '${data['feePayer'] ?? ''}' != 'seller' ||
        '${data['collectionTiming'] ?? ''}' != 'sale_payment' ||
        listingFee == null ||
        listingFee < 0 ||
        pipeUnitFee == null ||
        pipeUnitFee <= 0 ||
        pipePercentageCap == null ||
        pipePercentageCap <= 0 ||
        pipeMaximumFee == null ||
        pipeMaximumFee <= 0 ||
        equipmentMinimumFee == null ||
        equipmentMinimumFee < 0 ||
        equipmentMaximumFee == null ||
        equipmentMaximumFee <= 0 ||
        equipmentMinimumFee > equipmentMaximumFee ||
        brackets.isEmpty ||
        brackets.last.upperBound != null) {
      throw const FormatException('The fee guide response is incomplete.');
    }
    var previousUpperBound = 0.0;
    for (final bracket in brackets) {
      final upperBound = bracket.upperBound;
      if (bracket.percentage < 0 ||
          (upperBound != null && upperBound <= previousUpperBound)) {
        throw const FormatException('The fee guide response is incomplete.');
      }
      if (upperBound != null) previousUpperBound = upperBound;
    }
    return MarketplaceFeeCatalog(
      revision: revision,
      listingFee: listingFee,
      pipeUnitFee: pipeUnitFee,
      pipePercentageCap: pipePercentageCap,
      pipeMaximumFee: pipeMaximumFee,
      equipmentMinimumFee: equipmentMinimumFee,
      equipmentMaximumFee: equipmentMaximumFee,
      brackets: brackets,
    );
  }

  static const fallback = MarketplaceFeeCatalog(
    revision: marketplaceFeeScheduleRevision,
    listingFee: 0,
    pipeUnitFee: 1,
    pipePercentageCap: 3,
    pipeMaximumFee: 2500,
    equipmentMinimumFee: 1,
    equipmentMaximumFee: 2500,
    verified: false,
    brackets: [
      MarketplaceFeeBracket(upperBound: 5000, percentage: 3),
      MarketplaceFeeBracket(upperBound: 25000, percentage: 2.5),
      MarketplaceFeeBracket(upperBound: 100000, percentage: 2),
      MarketplaceFeeBracket(upperBound: 250000, percentage: 1.5),
      MarketplaceFeeBracket(upperBound: null, percentage: 1),
    ],
  );

  final String revision;
  final double listingFee;
  final double pipeUnitFee;
  final double pipePercentageCap;
  final double pipeMaximumFee;
  final double equipmentMinimumFee;
  final double equipmentMaximumFee;
  final List<MarketplaceFeeBracket> brackets;
  final bool verified;

  double equipmentFeeFor(double saleAmount) {
    if (!saleAmount.isFinite || saleAmount <= 0) return 0;
    var lowerBound = 0.0;
    var progressiveFee = 0.0;
    for (final bracket in brackets) {
      final upperBound = bracket.upperBound;
      final bracketEnd =
          upperBound == null ? saleAmount : math.min(saleAmount, upperBound);
      final amountInBracket = math.max(0.0, bracketEnd - lowerBound);
      progressiveFee += amountInBracket * bracket.percentage / 100;
      if (upperBound == null || saleAmount <= upperBound) break;
      lowerBound = upperBound;
    }
    return math.min(
      saleAmount,
      math.min(
        equipmentMaximumFee,
        math.max(equipmentMinimumFee, progressiveFee),
      ),
    );
  }
}

class MarketplaceFeeBracket {
  const MarketplaceFeeBracket({
    required this.upperBound,
    required this.percentage,
  });

  final double? upperBound;
  final double percentage;
}

class MarketplaceFeeInfoButton extends StatelessWidget {
  const MarketplaceFeeInfoButton({
    super.key,
    this.compact = false,
    this.commandClient,
  });

  final bool compact;
  final MarketplaceCommandClient? commandClient;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Open marketplace fee guide',
        child: compact
            ? IconButton(
                tooltip: 'Marketplace fee guide',
                onPressed: () => showMarketplaceFeeGuide(
                  context,
                  commandClient: commandClient,
                ),
                icon: const Icon(Icons.info_outline),
              )
            : OutlinedButton.icon(
                onPressed: () => showMarketplaceFeeGuide(
                  context,
                  commandClient: commandClient,
                ),
                icon: const Icon(Icons.info_outline),
                label: const Text('Fee guide'),
              ),
      );
}

Future<void> showMarketplaceFeeGuide(
  BuildContext context, {
  MarketplaceCommandClient? commandClient,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => MarketplaceFeeGuideSheet(
        commandClient: commandClient,
      ),
    );

class MarketplaceFeeGuideSheet extends StatefulWidget {
  const MarketplaceFeeGuideSheet({super.key, this.commandClient});

  final MarketplaceCommandClient? commandClient;

  @override
  State<MarketplaceFeeGuideSheet> createState() =>
      _MarketplaceFeeGuideSheetState();
}

class _MarketplaceFeeGuideSheetState extends State<MarketplaceFeeGuideSheet> {
  late final Future<MarketplaceFeeCatalog> _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = _loadCatalog();
  }

  Future<MarketplaceFeeCatalog> _loadCatalog() async {
    final response = await (widget.commandClient ?? MarketplaceCommandClient())
        .execute('getPublicMarketplaceFeeCatalog', const {});
    return MarketplaceFeeCatalog.fromMap(response);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MarketplaceFeeCatalog>(
        future: _catalog,
        builder: (context, snapshot) {
          final catalog = snapshot.data ?? MarketplaceFeeCatalog.fallback;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .88,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 30),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Simple, sale-only marketplace fees',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          catalog.listingFee == 0
                              ? 'List free. The seller fee is collected at sale settlement, never for listing or bidding. With Pipe Buyer checkout, seller proceeds remain pending until fulfillment is confirmed.'
                              : 'The listing fee is ${_usd(catalog.listingFee)}. The seller sale fee is collected at settlement; with Pipe Buyer checkout, seller proceeds remain pending until fulfillment is confirmed.',
                          style: const TextStyle(fontSize: 16, height: 1.35),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'All amounts in this guide are shown in USD.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(),
                        ] else if (snapshot.hasError) ...[
                          const SizedBox(height: 12),
                          const _FeeNotice(
                            text:
                                'Showing the launch schedule saved in this app. The server will show and lock the current fee before payment.',
                          ),
                        ],
                        const SizedBox(height: 20),
                        _FeeSection(
                          title: 'Listing',
                          child: _FeeValueRow(
                            label: 'Marketplace and Timed Buying listing fee',
                            value: _usd(catalog.listingFee),
                            emphasized: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const _FeeSection(
                          title: 'Two ways to sell and buy',
                          child: Column(
                            children: [
                              _TransactionPathRow(
                                icon: Icons.storefront_outlined,
                                title: 'Marketplace',
                                description: marketplaceSalePathDisclosure,
                              ),
                              Divider(height: 24),
                              _TransactionPathRow(
                                icon: Icons.timer_outlined,
                                title: 'Timed Buying',
                                description: timedBuyingSalePathDisclosure,
                              ),
                              SizedBox(height: 12),
                              _FeeNotice(text: sharedSaleFeeDisclosure),
                              SizedBox(height: 8),
                              _FeeNotice(text: wantedDiscoveryDisclosure),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FeeSection(
                          title: 'Equipment and asset sales',
                          child: Column(
                            children: [
                              for (var index = 0;
                                  index < catalog.brackets.length;
                                  index++)
                                _FeeBracketRow(
                                  index: index,
                                  bracket: catalog.brackets[index],
                                  previousUpperBound: index == 0
                                      ? 0
                                      : catalog.brackets[index - 1].upperBound,
                                ),
                              const Divider(height: 22),
                              _FeeValueRow(
                                label: 'Minimum seller fee',
                                value: _usd(catalog.equipmentMinimumFee),
                              ),
                              _FeeValueRow(
                                label: 'Maximum seller fee',
                                value: _usd(catalog.equipmentMaximumFee),
                                emphasized: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FeeSection(
                          title: 'Pipe, tubing, and material lots',
                          child: Text(
                            '${_usd(catalog.pipeUnitFee)} per sold stick or item, capped at the lower of ${_percent(catalog.pipePercentageCap)} of the sale or ${_usd(catalog.pipeMaximumFee)}. This rate applies after Pipe Buyer verifies the pipe or material classification; otherwise the equipment schedule applies.',
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const _FeeSection(
                          title: 'How progressive fees work',
                          child: Text(
                            'Each percentage applies only to the part of the sale inside that band. A higher sale price never makes an earlier band more expensive.',
                            style: TextStyle(fontSize: 15, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FeeSection(
                          title: 'Examples',
                          child: Column(
                            children: [
                              for (final saleAmount in const [
                                5000.0,
                                25000.0,
                                100000.0,
                                250000.0,
                              ])
                                _FeeValueRow(
                                  label: '${_usd(saleAmount)} equipment sale',
                                  value:
                                      '${_usd(catalog.equipmentFeeFor(saleAmount))} seller fee',
                                  emphasized: catalog.equipmentFeeFor(
                                        saleAmount,
                                      ) >=
                                      catalog.equipmentMaximumFee,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const _FeeNotice(
                          text:
                              'Taxes, shipping, inspection, and payment-provider costs are separate when they apply. Your transaction shows the exact server-verified fee before payment. After buyer payment, seller proceeds remain pending until fulfillment is confirmed and release checks pass.',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Schedule ${catalog.revision}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _FeeSection extends StatelessWidget {
  const _FeeSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

class _TransactionPathRow extends StatelessWidget {
  const _TransactionPathRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(description, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ],
      );
}

class _FeeBracketRow extends StatelessWidget {
  const _FeeBracketRow({
    required this.index,
    required this.bracket,
    required this.previousUpperBound,
  });

  final int index;
  final MarketplaceFeeBracket bracket;
  final double? previousUpperBound;

  @override
  Widget build(BuildContext context) {
    final lower = previousUpperBound ?? 0;
    final label = bracket.upperBound == null
        ? 'Amount over ${_usd(lower)}'
        : index == 0
            ? 'First ${_usd(bracket.upperBound!)}'
            : '${_usd(lower)}–${_usd(bracket.upperBound!)} portion';
    return _FeeValueRow(
      label: label,
      value: '${_percent(bracket.percentage)}%',
    );
  }
}

class _FeeValueRow extends StatelessWidget {
  const _FeeValueRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _FeeNotice extends StatelessWidget {
  const _FeeNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(height: 1.35)),
      );
}

String _percent(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _usd(double value) {
  final whole = value.round();
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    buffer.write(digits[index]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return '\$${buffer.toString()}';
}
