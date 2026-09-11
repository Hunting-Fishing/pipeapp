import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'marketplace_dispatch_repository.dart';
import 'marketplace_money.dart';

enum DispatchProviderInboxBucket {
  needsAction,
  waiting,
  active,
  complete,
  closed,
}

class DispatchProviderInboxState {
  const DispatchProviderInboxState({
    required this.bucket,
    required this.label,
    required this.nextAction,
    required this.icon,
  });

  final DispatchProviderInboxBucket bucket;
  final String label;
  final String nextAction;
  final IconData icon;
}

DispatchProviderInboxState dispatchProviderInboxState(String rawStatus) {
  final status = rawStatus.trim().toLowerCase();
  return switch (status) {
    'awarded' => const DispatchProviderInboxState(
        bucket: DispatchProviderInboxBucket.needsAction,
        label: 'Awarded',
        nextAction: 'Accept award',
        icon: Icons.handshake_outlined,
      ),
    'accepted' => const DispatchProviderInboxState(
        bucket: DispatchProviderInboxBucket.needsAction,
        label: 'Accepted',
        nextAction: 'Schedule pickup',
        icon: Icons.event_available_outlined,
      ),
    'scheduled' => const DispatchProviderInboxState(
        bucket: DispatchProviderInboxBucket.needsAction,
        label: 'Scheduled',
        nextAction: 'Start transport when ready',
        icon: Icons.event_outlined,
      ),
    'in_transit' => const DispatchProviderInboxState(
        bucket: DispatchProviderInboxBucket.needsAction,
        label: 'In transit',
        nextAction: 'Record delivery',
        icon: Icons.local_shipping_outlined,
      ),
    'delivered' => const DispatchProviderInboxState(
        bucket: DispatchProviderInboxBucket.waiting,
        label: 'Delivered',
        nextAction: 'Waiting for customer confirmation',
        icon: Icons.inventory_2_outlined,
      ),
    'pending' => const DispatchProviderInboxState(
        bucket: DispatchProviderInboxBucket.waiting,
        label: 'Quote pending',
        nextAction: 'Waiting for customer decision',
        icon: Icons.hourglass_top_outlined,
      ),
    'closed' || 'completed' => const DispatchProviderInboxState(
        bucket: DispatchProviderInboxBucket.complete,
        label: 'Completed',
        nextAction: 'No action required',
        icon: Icons.check_circle_outline,
      ),
    'not_selected' => const DispatchProviderInboxState(
        bucket: DispatchProviderInboxBucket.closed,
        label: 'Not selected',
        nextAction: 'No action required',
        icon: Icons.archive_outlined,
      ),
    'cancelled' => const DispatchProviderInboxState(
        bucket: DispatchProviderInboxBucket.closed,
        label: 'Cancelled',
        nextAction: 'No action required',
        icon: Icons.cancel_outlined,
      ),
    'disputed' => const DispatchProviderInboxState(
        bucket: DispatchProviderInboxBucket.needsAction,
        label: 'Disputed',
        nextAction: 'Review the Dispatch record',
        icon: Icons.gavel_outlined,
      ),
    _ => const DispatchProviderInboxState(
        bucket: DispatchProviderInboxBucket.active,
        label: 'Active',
        nextAction: 'Open Dispatch for details',
        icon: Icons.route_outlined,
      ),
  };
}

class DispatchProviderInboxCounts {
  const DispatchProviderInboxCounts({
    required this.needsAction,
    required this.waiting,
    required this.active,
    required this.complete,
  });

  final int needsAction;
  final int waiting;
  final int active;
  final int complete;

  factory DispatchProviderInboxCounts.fromQuotes(
    Iterable<Map<String, dynamic>> quotes,
  ) {
    var needsAction = 0;
    var waiting = 0;
    var active = 0;
    var complete = 0;
    for (final quote in quotes) {
      final state = dispatchProviderInboxState('${quote['status'] ?? ''}');
      switch (state.bucket) {
        case DispatchProviderInboxBucket.needsAction:
          needsAction += 1;
        case DispatchProviderInboxBucket.waiting:
          waiting += 1;
        case DispatchProviderInboxBucket.active:
          active += 1;
        case DispatchProviderInboxBucket.complete:
          complete += 1;
        case DispatchProviderInboxBucket.closed:
          break;
      }
    }
    return DispatchProviderInboxCounts(
      needsAction: needsAction,
      waiting: waiting,
      active: active,
      complete: complete,
    );
  }
}

class MarketplaceDispatchProviderInbox extends StatelessWidget {
  const MarketplaceDispatchProviderInbox({
    super.key,
    required this.repository,
    required this.onOpenJobs,
  });

  final MarketplaceDispatchRepository repository;
  final VoidCallback onOpenJobs;

  @override
  Widget build(BuildContext context) => StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: repository.myBidsQuery().limit(60).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Loading provider inbox…'),
                  ],
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Provider inbox unavailable',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Your quotes were not changed. Open Jobs to retry the existing Dispatch feed.',
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: onOpenJobs,
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('Open Jobs'),
                    ),
                  ],
                ),
              ),
            );
          }

          final quotes = snapshot.data?.docs ?? const [];
          final quoteData = quotes.map((quote) => quote.data()).toList();
          final counts = DispatchProviderInboxCounts.fromQuotes(quoteData);
          final actionable = quotes
              .where((quote) =>
                  dispatchProviderInboxState('${quote.data()['status'] ?? ''}')
                      .bucket ==
                  DispatchProviderInboxBucket.needsAction)
              .take(4)
              .toList(growable: false);
          final recent = (actionable.isNotEmpty ? actionable : quotes.take(4))
              .toList(growable: false);

          return Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        child: Icon(Icons.inbox_outlined),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Provider inbox',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Carrier quotes and awarded-work actions from the existing Dispatch record.',
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onOpenJobs,
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open jobs'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InboxCountChip(
                        label: 'Needs action',
                        count: counts.needsAction,
                        icon: Icons.priority_high_rounded,
                      ),
                      _InboxCountChip(
                        label: 'Waiting',
                        count: counts.waiting,
                        icon: Icons.hourglass_top_outlined,
                      ),
                      _InboxCountChip(
                        label: 'Active',
                        count: counts.active,
                        icon: Icons.route_outlined,
                      ),
                      _InboxCountChip(
                        label: 'Completed',
                        count: counts.complete,
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (quotes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No carrier quotes yet. Open Jobs to review available service requests.',
                      ),
                    )
                  else ...[
                    Text(
                      actionable.isNotEmpty
                          ? 'Needs your attention'
                          : 'Recent carrier quotes',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    ...recent.map((quote) {
                      final data = quote.data();
                      final state = dispatchProviderInboxState(
                        '${data['status'] ?? ''}',
                      );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(state.icon),
                        title: Text(
                          '${data['quoteReference'] ?? 'Carrier quote'} · ${marketplaceMoney(data['amount'] as num? ?? 0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${state.label} · ${state.nextAction}\n${data['vehicleName'] ?? 'Fleet vehicle'} · Version ${data['quoteVersion'] ?? data['revision'] ?? 1}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: onOpenJobs,
                      );
                    }),
                  ],
                  const Divider(height: 20),
                  const Text(
                    'Financial charging and provider proceeds are not handled by this inbox. Those remain a separate Dispatch financial-ledger release.',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _InboxCountChip extends StatelessWidget {
  const _InboxCountChip({
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 17),
        label: Text('$label: $count'),
      );
}
