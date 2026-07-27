import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
      color: Colors.green.shade700,
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
      color: const Color(0xFF0878E8),
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
      color: Colors.deepOrange.shade700,
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
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      icon: const Icon(Icons.handshake_outlined,
          size: 40, color: Color(0xFF00BFA5)),
      title: const Text('Accept this offer?'),
      content: SizedBox(
        width: 520,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFEAF8F1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB7E4CB))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('OFFER TOTAL',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.green)),
              Text(
                  '${marketplaceMoney(offer['offeredTotal'] as num? ?? 0)} '
                  'for ${offer['requestedQuantity'] ?? 0} units',
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w900)),
            ]),
          ),
          if (milestones.isNotEmpty) ...[
            const SizedBox(height: 12),
            MarketplaceOfferScheduleCard(
                milestones: milestones, compact: false),
          ],
          const SizedBox(height: 12),
          const Text(
              'The buyer will be notified, all competing offers for this listing will be archived, and their conversation will open so you can finalize the purchase.'),
        ]),
      ),
      actions: [
        OutlinedButton.icon(
            onPressed: () =>
                Navigator.pop(context, MarketplaceOfferDecision.counter),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Make counter offer')),
        TextButton(
            onPressed: () =>
                Navigator.pop(context, MarketplaceOfferDecision.cancel),
            child: const Text('Cancel')),
        FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, MarketplaceOfferDecision.accept),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Accept offer')),
      ],
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
    final title = const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.calendar_month_outlined, size: 19, color: Color(0xFF0878E8)),
      SizedBox(width: 7),
      Flexible(
          child: Text('Offer schedule',
              style: TextStyle(fontWeight: FontWeight.w900))),
    ]);
    final openCalendar = TextButton.icon(
      onPressed: () => _openCalendar(context, milestones.first),
      icon: const Icon(Icons.open_in_full, size: 15),
      label: const Text('Open calendar'),
      style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5)),
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
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E3ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stackedHeader) ...[
            title,
            Align(alignment: Alignment.centerLeft, child: openCalendar),
          ] else
            Row(children: [
              Expanded(child: title),
              openCalendar,
            ]),
          const SizedBox(height: 7),
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
            Wrap(spacing: 7, runSpacing: 7, children: milestoneTiles),
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
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: milestone.color.withValues(alpha: .35)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
            child: Row(
                mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_monthShort(milestone.date.month).toUpperCase(),
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: milestone.color)),
                      Text('${milestone.date.day}',
                          style: const TextStyle(
                              height: 1,
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                    ]),
                  ),
                  const SizedBox(width: 7),
                  Icon(milestone.icon, size: 17, color: milestone.color),
                  const SizedBox(width: 5),
                  if (expanded)
                    Expanded(
                      child: Text(milestone.shortLabel,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                    )
                  else
                    Text(milestone.shortLabel,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                ]),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const CircleAvatar(
                    backgroundColor: Color(0xFFE6F2FD),
                    foregroundColor: Color(0xFF0878E8),
                    child: Icon(Icons.calendar_month_outlined)),
                const SizedBox(width: 10),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Offer schedule',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w900)),
                      Text('Select a milestone to review its date',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF66758A))),
                    ])),
                IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: widget.milestones
                    .map((milestone) => ChoiceChip(
                          selected: identical(milestone, _selected),
                          avatar: Icon(milestone.icon,
                              size: 17, color: milestone.color),
                          label: Text(
                              '${milestone.shortLabel} ${_formatDate(milestone.date)}'),
                          onSelected: (_) => setState(() => _select(milestone)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFD),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD8E3ED))),
                child: Column(children: [
                  Row(children: [
                    IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => setState(() => _visibleMonth =
                            DateTime(
                                _visibleMonth.year, _visibleMonth.month - 1)),
                        icon: const Icon(Icons.chevron_left)),
                    Expanded(
                        child: Text(
                            '${_monthLong(_visibleMonth.month)} ${_visibleMonth.year}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w900))),
                    IconButton(
                        tooltip: 'Next month',
                        onPressed: () => setState(() => _visibleMonth =
                            DateTime(
                                _visibleMonth.year, _visibleMonth.month + 1)),
                        icon: const Icon(Icons.chevron_right)),
                  ]),
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
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _selected.color.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _selected.color.withValues(alpha: .3))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_selected.icon, color: _selected.color),
                      const SizedBox(width: 9),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(_selected.label,
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: _selected.color)),
                            Text(_formatLongDate(_selected.date),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            Text(_selected.description,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF53657A))),
                          ])),
                    ]),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done')),
              ),
            ]),
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
              ? _selected.color.withValues(alpha: .14)
              : events.isNotEmpty
                  ? const Color(0xFFEAF4FD)
                  : Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                  color: selected
                      ? _selected.color
                      : events.isNotEmpty
                          ? const Color(0xFFB8D9F8)
                          : Colors.transparent)),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: events.isEmpty
                ? null
                : () => setState(() => _select(events.first)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Column(children: [
                Text('$day',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: events.isNotEmpty
                            ? FontWeight.w900
                            : FontWeight.w500)),
                if (events.isNotEmpty)
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: events
                              .map((event) => Tooltip(
                                  message: event.label,
                                  child: Icon(event.icon,
                                      size: 13, color: event.color)))
                              .toList()),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
    });
  }
}

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF66758A))),
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
