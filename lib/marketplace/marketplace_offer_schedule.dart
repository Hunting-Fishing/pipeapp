import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_money.dart';

enum MarketplaceOfferDecision { counter, cancel, accept }

class MarketplaceOfferMilestone {
  const MarketplaceOfferMilestone({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.date,
    required this.icon,
    required this.color,
    required this.description,
  });

  final String key;
  final String label;
  final String shortLabel;
  final DateTime date;
  final IconData icon;
  final Color color;
  final String description;
}

DateTime? marketplaceOfferDate(dynamic value) => switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime date => date,
      int milliseconds => DateTime.fromMillisecondsSinceEpoch(milliseconds),
      _ => null,
    };

List<MarketplaceOfferMilestone> marketplaceOfferMilestones(
    Map<String, dynamic> offer) {
  final milestones = <MarketplaceOfferMilestone>[];
  final purchase = marketplaceOfferDate(offer['purchaseDate']);
  final transfer = marketplaceOfferDate(offer['moneyTransferDate']);
  final trucking = marketplaceOfferDate(offer['truckingDate']);
  if (purchase != null) {
    milestones.add(MarketplaceOfferMilestone(
      key: 'purchase',
      label: 'Purchase date',
      shortLabel: 'Purchase',
      date: purchase,
      icon: Icons.event_available_outlined,
      color: PipeBuyerColors.success,
      description: 'The proposed date to complete the purchase.',
    ));
  }
  if (transfer != null) {
    milestones.add(MarketplaceOfferMilestone(
      key: 'money_transfer',
      label: 'Money transfer',
      shortLabel: 'Transfer',
      date: transfer,
      icon: Icons.account_balance_outlined,
      color: PipeBuyerColors.industrialBlue,
      description: 'The proposed date for the purchase funds to transfer.',
    ));
  }
  if (trucking != null) {
    milestones.add(MarketplaceOfferMilestone(
      key: 'trucking',
      label: 'Trucking / pickup',
      shortLabel: 'Trucking',
      date: trucking,
      icon: Icons.local_shipping_outlined,
      color: PipeBuyerColors.orange,
      description: 'The proposed trucking, loading, or pickup date.',
    ));
  }
  milestones.sort((a, b) => a.date.compareTo(b.date));
  return milestones;
}

class MarketplaceAcceptOfferDialog extends StatelessWidget {
  const MarketplaceAcceptOfferDialog({super.key, required this.offer});

  final Map<String, dynamic> offer;

  @override
  Widget build(BuildContext context) {
    final milestones = marketplaceOfferMilestones(offer);
    final total = offer['offeredTotal'] as num? ?? 0;
    final quantity = offer['requestedQuantity'] ?? 0;
    final largeText = MediaQuery.textScalerOf(context).scale(12) >= 18;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OfferDialogHeader(
                title: 'Accept this offer?',
                subtitle:
                    'Review the total and proposed transaction schedule before committing.',
                onClose: () =>
                    Navigator.pop(context, MarketplaceOfferDecision.cancel),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.orange.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.handshake_outlined,
                        color: PipeBuyerColors.orange,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OFFER TOTAL',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            marketplaceMoney(total),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '$quantity units',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (largeText)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'NEGOTIATED',
                                style: TextStyle(
                                  color: PipeBuyerColors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .7,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!largeText)
                      const PipeBuyerStatusBadge(
                        label: 'NEGOTIATED',
                        icon: Icons.forum_outlined,
                        tone: PipeBuyerStatusTone.premium,
                      ),
                  ],
                ),
              ),
              if (milestones.isNotEmpty) ...[
                const SizedBox(height: 14),
                MarketplaceOfferScheduleCard(
                  milestones: milestones,
                  compact: false,
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PipeBuyerColors.success.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: PipeBuyerColors.success.withValues(alpha: .18),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: PipeBuyerColors.success,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'The buyer will be notified, all competing offers for this listing will be archived, and their conversation will open so you can finalize the purchase.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final counter = OutlinedButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      MarketplaceOfferDecision.counter,
                    ),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Make counter offer'),
                  );
                  final cancel = TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      MarketplaceOfferDecision.cancel,
                    ),
                    child: const Text('Cancel'),
                  );
                  final accept = FilledButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      MarketplaceOfferDecision.accept,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Accept offer'),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        accept,
                        const SizedBox(height: 8),
                        counter,
                        cancel,
                      ],
                    );
                  }
                  return Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [counter, cancel, accept],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MarketplaceOfferScheduleCard extends StatelessWidget {
  const MarketplaceOfferScheduleCard({
    super.key,
    required this.milestones,
    this.compact = true,
  });

  final List<MarketplaceOfferMilestone> milestones;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) return const SizedBox.shrink();
    final largeText = MediaQuery.textScalerOf(context).scale(12) >= 18;
    final stackedHeader = MediaQuery.sizeOf(context).width < 420 || largeText;
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          decoration: BoxDecoration(
            color: PipeBuyerColors.orangeSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.calendar_month_outlined,
            size: 19,
            color: PipeBuyerColors.orangePressed,
          ),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Offer schedule',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (!compact)
                Text(
                  '${milestones.length} proposed milestone${milestones.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
    final openCalendar = TextButton.icon(
      onPressed: () => _openCalendar(context, milestones.first),
      icon: const Icon(Icons.open_in_full, size: 15),
      label: const Text('Open calendar'),
    );
    final milestoneTiles = milestones
        .map((milestone) => _MarketplaceMilestoneTile(
              milestone: milestone,
              expanded: largeText,
              onTap: () => _openCalendar(context, milestone),
            ))
        .toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stackedHeader) ...[
            title,
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerLeft, child: openCalendar),
          ] else
            Row(
              children: [
                Expanded(child: title),
                openCalendar,
              ],
            ),
          const SizedBox(height: 9),
          if (largeText)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < milestoneTiles.length; index++) ...[
                  milestoneTiles[index],
                  if (index < milestoneTiles.length - 1)
                    const SizedBox(height: 7),
                ],
              ],
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: milestoneTiles,
            ),
        ],
      ),
    );
  }

  Future<void> _openCalendar(
          BuildContext context, MarketplaceOfferMilestone selected) =>
      showDialog<void>(
        context: context,
        builder: (_) => _MarketplaceOfferCalendarDialog(
          milestones: milestones,
          initiallySelected: selected,
        ),
      );
}

class _MarketplaceMilestoneTile extends StatelessWidget {
  const _MarketplaceMilestoneTile({
    required this.milestone,
    required this.onTap,
    this.expanded = false,
  });

  final MarketplaceOfferMilestone milestone;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) => Material(
        color: milestone.color.withValues(alpha: .07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(color: milestone.color.withValues(alpha: .25)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 11, 7),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: milestone.color.withValues(alpha: .16),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _monthShort(milestone.date.month).toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: milestone.color,
                        ),
                      ),
                      Text(
                        '${milestone.date.day}',
                        style: const TextStyle(
                          height: 1,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(milestone.icon, size: 17, color: milestone.color),
                const SizedBox(width: 6),
                if (expanded)
                  Expanded(
                    child: Text(
                      milestone.shortLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  Text(
                    milestone.shortLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _MarketplaceOfferCalendarDialog extends StatefulWidget {
  const _MarketplaceOfferCalendarDialog({
    required this.milestones,
    required this.initiallySelected,
  });

  final List<MarketplaceOfferMilestone> milestones;
  final MarketplaceOfferMilestone initiallySelected;

  @override
  State<_MarketplaceOfferCalendarDialog> createState() =>
      _MarketplaceOfferCalendarDialogState();
}

class _MarketplaceOfferCalendarDialogState
    extends State<_MarketplaceOfferCalendarDialog> {
  late MarketplaceOfferMilestone _selected;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _select(widget.initiallySelected);
  }

  void _select(MarketplaceOfferMilestone milestone) {
    _selected = milestone;
    _visibleMonth = DateTime(milestone.date.year, milestone.date.month);
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OfferDialogHeader(
                  title: 'Offer schedule',
                  subtitle: 'Select a milestone to review its proposed date.',
                  icon: Icons.calendar_month_outlined,
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: widget.milestones
                      .map((milestone) => ChoiceChip(
                            selected: identical(milestone, _selected),
                            avatar: Icon(
                              milestone.icon,
                              size: 17,
                              color: milestone.color,
                            ),
                            label: Text(
                              '${milestone.shortLabel} ${_formatDate(milestone.date)}',
                            ),
                            onSelected: (_) =>
                                setState(() => _select(milestone)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Previous month',
                            onPressed: () => setState(() => _visibleMonth =
                                DateTime(_visibleMonth.year,
                                    _visibleMonth.month - 1)),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Text(
                              '${_monthLong(_visibleMonth.month)} ${_visibleMonth.year}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Next month',
                            onPressed: () => setState(() => _visibleMonth =
                                DateTime(_visibleMonth.year,
                                    _visibleMonth.month + 1)),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      const Row(
                        children: [
                          _Weekday('M'),
                          _Weekday('T'),
                          _Weekday('W'),
                          _Weekday('T'),
                          _Weekday('F'),
                          _Weekday('S'),
                          _Weekday('S'),
                        ],
                      ),
                      GridView.count(
                        crossAxisCount: 7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: _calendarCells(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _selected.color.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selected.color.withValues(alpha: .24),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _selected.color.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _selected.icon,
                          color: _selected.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selected.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _selected.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatLongDate(_selected.date),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _selected.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  List<Widget> _calendarCells() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final leading = (first.weekday - DateTime.monday) % 7;
    final days = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    return List.generate(42, (index) {
      final day = index - leading + 1;
      if (day < 1 || day > days) return const SizedBox.shrink();
      final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
      final events = widget.milestones
          .where((milestone) => _sameDay(milestone.date, date))
          .toList();
      final selected = _sameDay(_selected.date, date);
      return Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: selected
              ? _selected.color.withValues(alpha: .13)
              : events.isNotEmpty
                  ? PipeBuyerColors.orangeSoft.withValues(alpha: .55)
                  : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected
                  ? _selected.color
                  : events.isNotEmpty
                      ? PipeBuyerColors.orange.withValues(alpha: .24)
                      : Colors.transparent,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: events.isEmpty
                ? null
                : () => setState(() => _select(events.first)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Column(
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          events.isNotEmpty ? FontWeight.w900 : FontWeight.w500,
                    ),
                  ),
                  if (events.isNotEmpty)
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: events
                              .map((event) => Tooltip(
                                    message: event.label,
                                    child: Icon(
                                      event.icon,
                                      size: 13,
                                      color: event.color,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _OfferDialogHeader extends StatelessWidget {
  const _OfferDialogHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
    this.icon = Icons.handshake_outlined,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: PipeBuyerColors.orangeSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: PipeBuyerColors.orangePressed, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .62),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      );
}

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: .55),
            ),
          ),
        ),
      );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _formatLongDate(DateTime date) =>
    '${_monthLong(date.month)} ${date.day}, ${date.year}';

String _monthShort(int month) => const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][month - 1];

String _monthLong(int month) => const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][month - 1];
