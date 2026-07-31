import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import 'marketplace_command_client.dart';
import 'marketplace_data_state.dart';
import 'marketplace_dispatch_repository.dart';
import 'marketplace_money.dart';

class MarketplaceDispatchTransactionCard extends StatefulWidget {
  const MarketplaceDispatchTransactionCard({
    super.key,
    required this.jobId,
    required this.job,
    required this.repository,
  });

  final String jobId;
  final Map<String, dynamic> job;
  final MarketplaceDispatchRepository repository;

  @override
  State<MarketplaceDispatchTransactionCard> createState() =>
      _MarketplaceDispatchTransactionCardState();
}

class _MarketplaceDispatchTransactionCardState
    extends State<MarketplaceDispatchTransactionCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.repository.dispatchTransaction(widget.jobId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return MarketplaceDataStateView.failure(
              error: snapshot.error,
              resource: 'Dispatch progress',
              onRetry: () => setState(() {}),
              compact: true,
            );
          }
          if (!snapshot.hasData) {
            return const MarketplaceDataStateView.loading(
              title: 'Loading Dispatch progress',
              message: 'Checking the latest job milestone…',
              compact: true,
            );
          }
          final transaction = snapshot.data!.data();
          if (transaction == null) {
            return const MarketplaceDataStateView(
              kind: MarketplaceDataStateKind.empty,
              title: 'Preparing awarded Dispatch job',
              message:
                  'The permanent job progress record will appear here when preparation finishes.',
              icon: Icons.hourglass_top_outlined,
              compact: true,
            );
          }
          return _card(transaction);
        },
      );

  Widget _card(Map<String, dynamic> transaction) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final carrier = uid == transaction['carrierUid'];
    final customer = uid == transaction['customerUid'];
    final status = '${transaction['status'] ?? 'awarded'}';
    final terminal = const {'closed', 'cancelled', 'disputed'}.contains(status);
    final scheduledDate =
        (transaction['scheduledDate'] as Timestamp?)?.toDate();
    final proof = transaction['proofOfDelivery'] is Map
        ? Map<String, dynamic>.from(transaction['proofOfDelivery'] as Map)
        : const <String, dynamic>{};
    return Card(
      color: const Color(0xFFEAF4FD),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF0878E8),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Awarded Dispatch job',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                Chip(label: Text(_statusLabel(status))),
              ],
            ),
            Text(
              '${marketplaceMoney(transaction['amount'] as num? ?? 0)} all-in',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            _PrivateDispatchRoute(
              jobId: widget.jobId,
              repository: widget.repository,
            ),
            if (scheduledDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Scheduled ${_dateLabel(scheduledDate)}'),
              ),
            const SizedBox(height: 12),
            _progress(status),
            if (proof.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Proof of delivery',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              Text('Received by ${proof['receiverName'] ?? '—'}'),
              Text('${proof['deliveryNote'] ?? ''}'),
            ],
            const SizedBox(height: 12),
            if (carrier && status == 'awarded')
              _primary(
                'Accept awarded job',
                Icons.handshake_outlined,
                () => _simpleAction('accept_award', 'Dispatch job accepted.'),
              ),
            if (carrier && status == 'accepted')
              _primary(
                'Schedule pickup',
                Icons.event_available_outlined,
                _schedule,
              ),
            if (carrier && status == 'scheduled')
              _primary(
                'Start transport',
                Icons.route_outlined,
                () => _confirmSimple(
                  title: 'Start transport?',
                  message:
                      'The customer will be notified that the load is in transit.',
                  action: 'start_transit',
                  success: 'Load marked in transit.',
                ),
              ),
            if (carrier && status == 'in_transit')
              _primary('Record delivery', Icons.inventory_outlined, _deliver),
            if (customer && status == 'delivered')
              _primary(
                'Confirm delivery and close job',
                Icons.verified_outlined,
                () => _confirmSimple(
                  title: 'Confirm delivery?',
                  message:
                      'This permanently closes the Dispatch job. It does not release or process payment.',
                  action: 'confirm_delivery',
                  success: 'Dispatch job completed.',
                ),
              ),
            if (!terminal && (carrier || customer)) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (const {
                    'awarded',
                    'accepted',
                    'scheduled',
                  }.contains(status))
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _reasonAction('cancel'),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel job'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _reasonAction('dispute'),
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('Open dispute'),
                  ),
                ],
              ),
            ],
            TextButton.icon(
              onPressed: () => _showHistory(context),
              icon: const Icon(Icons.history_outlined),
              label: const Text('View permanent Dispatch history'),
            ),
            const Text(
              'Dispatch status records logistics progress only. Payment, permits, insurance, route legality, and load compliance remain the parties’ responsibility.',
              style: TextStyle(fontSize: 11, color: Color(0xFF66758A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progress(String status) {
    const steps = [
      'awarded',
      'accepted',
      'scheduled',
      'in_transit',
      'delivered',
      'closed',
    ];
    final current = steps.indexOf(status);
    if (current < 0) {
      return Text(
        _statusLabel(status),
        style: const TextStyle(fontWeight: FontWeight.w800),
      );
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: steps.asMap().entries.map((entry) {
        final reached = entry.key <= current;
        return Chip(
          avatar: Icon(
            reached ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: reached ? Colors.green : Colors.grey,
          ),
          label: Text(
            _statusLabel(entry.value),
            style: const TextStyle(fontSize: 10),
          ),
          visualDensity: VisualDensity.compact,
        );
      }).toList(growable: false),
    );
  }

  Widget _primary(String label, IconData icon, VoidCallback action) =>
      FilledButton.icon(
        onPressed: _busy ? null : action,
        icon: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
      );

  Future<void> _schedule() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (selected == null) return;
    await _run(
      () => widget.repository.updateDispatchTransaction(
        jobId: widget.jobId,
        action: 'schedule',
        scheduledDate: selected,
      ),
      'Pickup schedule saved.',
    );
  }

  Future<void> _deliver() async {
    final receiver = TextEditingController();
    final note = TextEditingController();
    final details = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record proof of delivery'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: receiver,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Receiver name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              TextField(
                controller: note,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Delivery condition and location *',
                  hintText:
                      'Example: 54 joints unloaded at the north yard gate.',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (receiver.text.trim().isNotEmpty &&
                  note.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, [
                  receiver.text.trim(),
                  note.text.trim(),
                ]);
              }
            },
            child: const Text('Record delivery'),
          ),
        ],
      ),
    );
    receiver.dispose();
    note.dispose();
    if (details == null) return;
    await _run(
      () => widget.repository.updateDispatchTransaction(
        jobId: widget.jobId,
        action: 'mark_delivered',
        receiverName: details[0],
        deliveryNote: details[1],
      ),
      'Delivery recorded. Waiting for customer confirmation.',
    );
  }

  Future<void> _confirmSimple({
    required String title,
    required String message,
    required String action,
    required String success,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Go back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await _simpleAction(action, success);
  }

  Future<void> _simpleAction(String action, String success) => _run(
        () => widget.repository.updateDispatchTransaction(
          jobId: widget.jobId,
          action: action,
        ),
        success,
      );

  Future<void> _reasonAction(String action) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          action == 'cancel' ? 'Cancel Dispatch job?' : 'Open dispute',
        ),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Reason *',
            hintText: 'Describe what happened and any resolution attempted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 10) Navigator.pop(dialogContext, value);
            },
            child: Text(action == 'cancel' ? 'Cancel job' : 'Submit dispute'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    await _run(
      () => widget.repository.updateDispatchTransaction(
        jobId: widget.jobId,
        action: action,
        reason: reason,
      ),
      action == 'cancel' ? 'Dispatch job cancelled.' : 'Dispute opened.',
    );
  }

  Future<void> _run(Future<void> Function() command, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await command();
      if (mounted) {
        PipeFeedback.show(
          context,
          message: message,
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showHistory(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.repository.dispatchTransactionHistory(widget.jobId),
            builder: (_, snapshot) {
              final revisions = snapshot.data?.docs ?? [];
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history_outlined),
                    title: const Text(
                      'Dispatch transaction history',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: const Text('Permanent participant activity'),
                    trailing: IconButton(
                      tooltip: 'Close transaction history',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  Expanded(
                    child: revisions.isEmpty
                        ? const Center(child: Text('No activity recorded yet.'))
                        : ListView(
                            padding: const EdgeInsets.all(12),
                            children: revisions.map((revision) {
                              final data = revision.data();
                              final created =
                                  (data['createdAt'] as Timestamp?)?.toDate();
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      '${data['revision'] ?? '—'}',
                                    ),
                                  ),
                                  title: Text(
                                    _statusLabel(
                                      '${data['status'] ?? data['event'] ?? ''}',
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${data['event'] ?? 'updated'}'
                                    '${created == null ? '' : ' • ${_dateLabel(created)}'}'
                                    '${data['reason'] == null ? '' : '\n${data['reason']}'}',
                                  ),
                                ),
                              );
                            }).toList(growable: false),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'awarded' => 'AWARDED',
        'accepted' => 'ACCEPTED',
        'scheduled' => 'SCHEDULED',
        'in_transit' => 'IN TRANSIT',
        'delivered' => 'DELIVERED',
        'closed' => 'COMPLETED',
        'cancelled' => 'CANCELLED',
        'disputed' => 'DISPUTED',
        _ => status.replaceAll('_', ' ').toUpperCase(),
      };

  String _dateLabel(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _PrivateDispatchRoute extends StatelessWidget {
  const _PrivateDispatchRoute({
    required this.jobId,
    required this.repository,
  });

  final String jobId;
  final MarketplaceDispatchRepository repository;

  String _pointLabel(dynamic value) {
    if (value is! GeoPoint) return 'Mapped location unavailable';
    return '${value.latitude.toStringAsFixed(5)}, '
        '${value.longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: repository.privateDispatchJob(jobId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'Exact route details are temporarily unavailable.',
              style: TextStyle(fontSize: 12, color: Color(0xFF66758A)),
            );
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          final route = snapshot.data?.data();
          if (route == null) {
            return const Text(
              'Exact route details have not been mapped yet.',
              style: TextStyle(fontSize: 12, color: Color(0xFF66758A)),
            );
          }
          final address = '${route['deliveryAddress'] ?? ''}'.trim();
          final accessNotes = '${route['deliveryAccessNotes'] ?? ''}'.trim();
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB8D5EF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_open_outlined, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Awarded route details',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Pickup: ${_pointLabel(route['pickupPoint'])}'),
                Text(
                  'Delivery: ${address.isEmpty ? _pointLabel(route['deliveryPoint']) : address}',
                ),
                if (accessNotes.isNotEmpty) Text('Site access: $accessNotes'),
                const SizedBox(height: 4),
                const Text(
                  'Private details are shared only with the requester, administrators, and awarded carrier.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF66758A)),
                ),
              ],
            ),
          );
        },
      );
}
