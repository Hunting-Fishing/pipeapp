import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';
import 'marketplace_data_state.dart';
import 'marketplace_dispatch_repository.dart';
import 'marketplace_dispatch_messaging.dart';
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
    final amount = marketplaceMoney(transaction['amount'] as num? ?? 0);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hero(status: status, amount: amount, scheduledDate: scheduledDate),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeading(
                  icon: Icons.route_outlined,
                  title: 'Awarded route',
                  subtitle:
                      'Exact logistics details unlock only for job participants.',
                ),
                const SizedBox(height: 10),
                _PrivateDispatchRoute(
                  jobId: widget.jobId,
                  repository: widget.repository,
                ),
                const SizedBox(height: 20),
                _sectionHeading(
                  icon: Icons.alt_route_outlined,
                  title: 'Transport progress',
                  subtitle:
                      'Permanent milestone history from award through closeout.',
                ),
                const SizedBox(height: 10),
                _progress(status),
                if (proof.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _proofOfDelivery(proof),
                ],
                if (carrier || customer) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => openDispatchContextConversation(
                                context,
                                jobId: widget.jobId,
                              ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(
                        customer ? 'Message carrier' : 'Message customer',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _participantActions(
                    carrier: carrier,
                    customer: customer,
                    status: status,
                    terminal: terminal,
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showHistory(context),
                    icon: const Icon(Icons.history_outlined),
                    label: const Text('View permanent Dispatch history'),
                  ),
                ),
                const SizedBox(height: 12),
                _responsibilityNotice(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero({
    required String status,
    required String amount,
    required DateTime? scheduledDate,
  }) {
    final tone = _statusColor(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: PipeBuyerColors.orange.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: PipeBuyerColors.orange.withValues(alpha: .42),
                  ),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: PipeBuyerColors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISPATCH JOB',
                      style: TextStyle(
                        color: PipeBuyerColors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Awarded Transport',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Job ${widget.jobId.length > 10 ? widget.jobId.substring(0, 10) : widget.jobId}',
                      style: const TextStyle(
                        color: Color(0xFFB7C1CE),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final statusBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tone.withValues(alpha: .55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon(status), size: 16, color: tone),
                const SizedBox(width: 6),
                Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: tone,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ),
          );

          final metrics = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroMetric(
                label: 'AWARDED RATE',
                value: '$amount all-in',
                icon: Icons.payments_outlined,
              ),
              _heroMetric(
                label: 'PICKUP',
                value: scheduledDate == null
                    ? 'Not scheduled'
                    : _dateLabel(scheduledDate),
                icon: Icons.event_outlined,
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 14),
                statusBadge,
                const SizedBox(height: 16),
                metrics,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 18),
                  statusBadge,
                ],
              ),
              const SizedBox(height: 18),
              metrics,
            ],
          );
        },
      ),
    );
  }

  Widget _heroMetric({
    required String label,
    required String value,
    required IconData icon,
  }) =>
      Container(
        constraints: const BoxConstraints(minWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: PipeBuyerColors.orange),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF9AA7B6),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _sectionHeading({
    required IconData icon,
    required String title,
    required String subtitle,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PipeBuyerColors.orangeSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: PipeBuyerColors.orange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _proofOfDelivery(Map<String, dynamic> proof) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FAF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: PipeBuyerColors.success.withValues(alpha: .28),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: PipeBuyerColors.success,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Proof of delivery recorded',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Received by ${proof['receiverName'] ?? '—'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  finalDeliveryNote(proof),
                ],
              ),
            ),
          ],
        ),
      );

  Widget finalDeliveryNote(Map<String, dynamic> proof) {
    final note = '${proof['deliveryNote'] ?? ''}'.trim();
    if (note.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        note,
        style: const TextStyle(color: PipeBuyerColors.slate, height: 1.4),
      ),
    );
  }

  Widget _participantActions({
    required bool carrier,
    required bool customer,
    required String status,
    required bool terminal,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? PipeBuyerColors.darkSurfaceMuted
            : PipeBuyerColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            carrier ? 'Carrier actions' : 'Customer actions',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            carrier
                ? 'Update the job as the load moves through each logistics milestone.'
                : 'Review the carrier milestone and confirm delivery when the load arrives.',
            style: const TextStyle(
              color: PipeBuyerColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
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
          if (terminal)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(_statusIcon(status), color: _statusColor(status)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This job is ${_statusLabel(status).toLowerCase()}. The permanent history remains available below.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          if (!terminal) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (const {'awarded', 'accepted', 'scheduled'}.contains(status))
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
        ],
      ),
    );
  }

  Widget _responsibilityNotice() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PipeBuyerColors.industrialBlue.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: PipeBuyerColors.industrialBlue.withValues(alpha: .18),
          ),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: PipeBuyerColors.industrialBlue,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Dispatch status records logistics progress only. Payment, permits, insurance, route legality, and load compliance remain the parties’ responsibility.',
                style: TextStyle(
                  fontSize: 11,
                  color: PipeBuyerColors.slate,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );

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
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _statusColor(status).withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(_statusIcon(status), color: _statusColor(status)),
            const SizedBox(width: 8),
            Text(
              _statusLabel(status),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        if (wide) {
          return Row(
            children: steps.asMap().entries.map((entry) {
              final reached = entry.key <= current;
              final active = entry.key == current;
              return Expanded(
                child: _progressStep(
                  label: _statusLabel(entry.value),
                  reached: reached,
                  active: active,
                  last: entry.key == steps.length - 1,
                ),
              );
            }).toList(growable: false),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: steps.asMap().entries.map((entry) {
            final reached = entry.key <= current;
            final active = entry.key == current;
            return _compactProgressStep(
              label: _statusLabel(entry.value),
              reached: reached,
              active: active,
            );
          }).toList(growable: false),
        );
      },
    );
  }

  Widget _progressStep({
    required String label,
    required bool reached,
    required bool active,
    required bool last,
  }) {
    final color = reached ? PipeBuyerColors.orange : PipeBuyerColors.line;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 3,
                color: reached ? PipeBuyerColors.orange : PipeBuyerColors.line,
              ),
            ),
            Container(
              width: active ? 30 : 24,
              height: active ? 30 : 24,
              decoration: BoxDecoration(
                color: reached ? PipeBuyerColors.orange : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: active ? 3 : 2),
              ),
              child: Icon(
                reached ? Icons.check : Icons.circle_outlined,
                size: active ? 17 : 13,
                color: reached ? Colors.white : PipeBuyerColors.muted,
              ),
            ),
            Expanded(
              child: Container(
                height: 3,
                color: last
                    ? Colors.transparent
                    : reached
                        ? PipeBuyerColors.orange
                        : PipeBuyerColors.line,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? PipeBuyerColors.ink : PipeBuyerColors.muted,
            fontSize: 9,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _compactProgressStep({
    required String label,
    required bool reached,
    required bool active,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? PipeBuyerColors.orangeSoft
              : reached
                  ? const Color(0xFFF6F7F9)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? PipeBuyerColors.orange.withValues(alpha: .55)
                : PipeBuyerColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              reached ? Icons.check_circle : Icons.circle_outlined,
              size: 15,
              color: reached ? PipeBuyerColors.orange : PipeBuyerColors.muted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _primary(String label, IconData icon, VoidCallback action) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _busy ? null : action,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
          label: Text(label),
        ),
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
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: PipeBuyerColors.orange),
            SizedBox(width: 9),
            Expanded(child: Text('Record proof of delivery')),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Record who received the load and the delivery condition/location. This becomes part of the permanent Dispatch history.',
                style: TextStyle(color: PipeBuyerColors.muted, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: receiver,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Receiver name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 8),
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
          FilledButton.icon(
            onPressed: () {
              if (receiver.text.trim().isNotEmpty &&
                  note.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, [
                  receiver.text.trim(),
                  note.text.trim(),
                ]);
              }
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Record delivery'),
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
        title: Row(
          children: [
            Icon(
              action == 'cancel'
                  ? Icons.cancel_outlined
                  : Icons.report_problem_outlined,
              color: action == 'cancel'
                  ? PipeBuyerColors.muted
                  : PipeBuyerColors.warning,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                action == 'cancel' ? 'Cancel Dispatch job?' : 'Open dispute',
              ),
            ),
          ],
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
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          height: MediaQuery.sizeOf(sheetContext).height * .76,
          margin: const EdgeInsets.fromLTRB(10, 24, 10, 10),
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).cardColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.repository.dispatchTransactionHistory(widget.jobId),
            builder: (_, snapshot) {
              final revisions = snapshot.data?.docs ?? [];
              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                    decoration: const BoxDecoration(
                      color: PipeBuyerColors.ink,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: PipeBuyerColors.orange.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.history_outlined,
                            color: PipeBuyerColors.orange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dispatch transaction history',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Permanent participant activity',
                                style: TextStyle(
                                  color: Color(0xFF9AA7B6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close transaction history',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: revisions.isEmpty
                        ? const MarketplaceDataStateView(
                            kind: MarketplaceDataStateKind.empty,
                            title: 'No Dispatch activity yet',
                            message:
                                'Milestone revisions will appear here as participants update the awarded job.',
                            icon: Icons.history_toggle_off_outlined,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: revisions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 9),
                            itemBuilder: (_, index) {
                              final data = revisions[index].data();
                              final created =
                                  (data['createdAt'] as Timestamp?)?.toDate();
                              final revision = '${data['revision'] ?? '—'}';
                              final historyStatus =
                                  '${data['status'] ?? data['event'] ?? ''}';
                              final reason = '${data['reason'] ?? ''}'.trim();
                              return Container(
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: Theme.of(sheetContext).brightness ==
                                          Brightness.dark
                                      ? PipeBuyerColors.darkSurfaceMuted
                                      : PipeBuyerColors.field,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: Theme.of(sheetContext).dividerColor,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: PipeBuyerColors.orangeSoft,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        revision,
                                        style: const TextStyle(
                                          color: PipeBuyerColors.orange,
                                          fontSize: 11,
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
                                            _statusLabel(historyStatus),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${data['event'] ?? 'updated'}'
                                            '${created == null ? '' : ' • ${_dateLabel(created)}'}',
                                            style: const TextStyle(
                                              color: PipeBuyerColors.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (reason.isNotEmpty) ...[
                                            const SizedBox(height: 5),
                                            Text(
                                              reason,
                                              style: const TextStyle(height: 1.4),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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

  Color _statusColor(String status) => switch (status) {
        'closed' || 'delivered' => PipeBuyerColors.success,
        'cancelled' => PipeBuyerColors.muted,
        'disputed' => PipeBuyerColors.danger,
        'in_transit' => PipeBuyerColors.industrialBlue,
        _ => PipeBuyerColors.orange,
      };

  IconData _statusIcon(String status) => switch (status) {
        'awarded' => Icons.emoji_events_outlined,
        'accepted' => Icons.handshake_outlined,
        'scheduled' => Icons.event_available_outlined,
        'in_transit' => Icons.local_shipping_outlined,
        'delivered' => Icons.inventory_2_outlined,
        'closed' => Icons.verified_outlined,
        'cancelled' => Icons.cancel_outlined,
        'disputed' => Icons.report_problem_outlined,
        _ => Icons.info_outline,
      };

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
            return _routeNotice(
              context,
              icon: Icons.cloud_off_outlined,
              message: 'Exact route details are temporarily unavailable.',
            );
          }
          if (!snapshot.hasData) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? PipeBuyerColors.darkSurfaceMuted
                    : PipeBuyerColors.field,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loading private route…',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  LinearProgressIndicator(minHeight: 3),
                ],
              ),
            );
          }
          final route = snapshot.data?.data();
          if (route == null) {
            return _routeNotice(
              context,
              icon: Icons.location_searching_outlined,
              message: 'Exact route details have not been mapped yet.',
            );
          }
          final address = '${route['deliveryAddress'] ?? ''}'.trim();
          final accessNotes = '${route['deliveryAccessNotes'] ?? ''}'.trim();
          final pickup = _pointLabel(route['pickupPoint']);
          final delivery = address.isEmpty
              ? _pointLabel(route['deliveryPoint'])
              : address;

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? PipeBuyerColors.darkSurfaceMuted
                  : PipeBuyerColors.field,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lock_open_outlined,
                      size: 18,
                      color: PipeBuyerColors.orange,
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Participant-only route details',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                _RoutePoint(
                  label: 'PICKUP',
                  value: pickup,
                  icon: Icons.trip_origin,
                  accent: PipeBuyerColors.orange,
                ),
                Container(
                  margin: const EdgeInsets.only(left: 10),
                  height: 16,
                  width: 2,
                  color: PipeBuyerColors.line,
                ),
                _RoutePoint(
                  label: 'DELIVERY',
                  value: delivery,
                  icon: Icons.location_on_outlined,
                  accent: PipeBuyerColors.industrialBlue,
                ),
                if (accessNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.warning.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.construction_outlined,
                          size: 18,
                          color: PipeBuyerColors.warning,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Site access: $accessNotes',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: PipeBuyerColors.muted,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Private details are shared only with the requester, administrators, and awarded carrier.',
                        style: TextStyle(
                          fontSize: 11,
                          color: PipeBuyerColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );

  Widget _routeNotice(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? PipeBuyerColors.darkSurfaceMuted
              : PipeBuyerColors.field,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: PipeBuyerColors.muted, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: accent),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      );
}
