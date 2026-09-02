import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';
import 'marketplace_dispatch_distance.dart';
import 'marketplace_dispatch_multi_service_selector.dart';
import 'marketplace_dispatch_repository.dart';

class MarketplaceDispatchMyRequestsPage extends StatefulWidget {
  const MarketplaceDispatchMyRequestsPage({super.key});

  @override
  State<MarketplaceDispatchMyRequestsPage> createState() =>
      _MarketplaceDispatchMyRequestsPageState();
}

class _MarketplaceDispatchMyRequestsPageState
    extends State<MarketplaceDispatchMyRequestsPage> {
  final _repository = MarketplaceDispatchRepository();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Requests')),
        body: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _repository.myJobsQuery().limit(100).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _RequestState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Requests could not be loaded',
                  message:
                      'Check your connection and reopen My Requests. No request was changed.',
                  onRetry: () => setState(() {}),
                );
              }
              final requests = snapshot.data?.docs ?? const [];
              if (requests.isEmpty) {
                return const _RequestState(
                  icon: Icons.assignment_outlined,
                  title: 'No service requests yet',
                  message:
                      'Requests you submit through Pipe Buyer Dispatch will appear here.',
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                children: [
                  const PipeBuyerPageHeader(
                    eyebrow: 'DISPATCH',
                    title: 'My Requests',
                    subtitle:
                        'Review status, make safe pre-award changes, see revision history, or cancel a request you no longer need.',
                    icon: Icons.assignment_outlined,
                  ),
                  const SizedBox(height: 14),
                  for (final request in requests) ...[
                    _requestCard(request),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ),
      );

  Widget _requestCard(QueryDocumentSnapshot<Map<String, dynamic>> request) {
    final data = request.data();
    final status = '${data['status'] ?? 'open'}';
    final editable = const {'draft', 'open'}.contains(status);
    final fieldService = data['requestPath'] == 'field_service';
    final codes = data['serviceCodes'] is Iterable
        ? (data['serviceCodes'] as Iterable).map((value) => '$value').toList()
        : const <String>[];
    final services = codes.isEmpty
        ? (fieldService ? 'Industrial service' : 'Transportation')
        : codes.map(dispatchServiceLabelForCode).join(', ');
    final date = data['truckingDate'] is Timestamp
        ? (data['truckingDate'] as Timestamp).toDate().toLocal()
        : null;
    final location = '${data['pickupLabel'] ?? ''}'.trim();
    final destination = '${data['deliveryLabel'] ?? ''}'.trim();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Icon(
                    fieldService
                        ? Icons.engineering_outlined
                        : Icons.local_shipping_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['title'] ?? 'Dispatch request'}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        services,
                        style: const TextStyle(color: PipeBuyerColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 12),
            _fact(
              fieldService ? Icons.location_on_outlined : Icons.trip_origin,
              fieldService ? 'Work site' : 'Pickup',
              location.isEmpty ? 'To be confirmed' : location,
            ),
            if (!fieldService)
              _fact(
                Icons.flag_outlined,
                'Delivery',
                destination.isEmpty ? 'To be confirmed' : destination,
              ),
            if (!fieldService)
              _fact(Icons.route_outlined, 'Distance', dispatchDistanceLabel(data)),
            _fact(
              Icons.calendar_month_outlined,
              fieldService ? 'Service needed' : 'Pickup date',
              date == null ? 'To be confirmed' : _dateLabel(date),
            ),
            _fact(
              Icons.request_quote_outlined,
              'Quotes',
              '${data['bidCount'] ?? 0} submitted',
            ),
            if ((data['attachmentCount'] as num? ?? 0) > 0)
              _fact(
                Icons.attach_file_outlined,
                'Private files',
                '${data['attachmentCount']} stored',
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: editable ? () => _editRequest(request) : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showHistory(request),
                  icon: const Icon(Icons.history_outlined),
                  label: const Text('History'),
                ),
                if (editable)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PipeBuyerColors.danger,
                    ),
                    onPressed: () => _cancelRequest(request),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel request'),
                  ),
              ],
            ),
            if (editable) ...[
              const SizedBox(height: 8),
              const Text(
                'Service type and mapped route/site stay fixed during a quick edit. Cancel and create a new request if the required work or location has materially changed.',
                style: TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fact(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: PipeBuyerColors.industrialBlue),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: const TextStyle(
                  color: PipeBuyerColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );

  Future<void> _editRequest(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    final data = request.data();
    final fieldService = data['requestPath'] == 'field_service';
    final title = TextEditingController(text: '${data['title'] ?? ''}');
    final details = TextEditingController(text: '${data['loadDetails'] ?? ''}');
    final weight = TextEditingController(
      text: data['estimatedWeightKg'] == null
          ? ''
          : '${data['estimatedWeightKg']}',
    );
    var requestedAt = data['truckingDate'] is Timestamp
        ? (data['truckingDate'] as Timestamp).toDate().toLocal()
        : DateTime.now().add(const Duration(days: 1));

    final saved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: Text(fieldService ? 'Edit service request' : 'Edit Dispatch request'),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: title,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'Request title *',
                          prefixIcon: Icon(Icons.title_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: fieldService ? 'Work site' : 'Route',
                          prefixIcon: Icon(
                            fieldService
                                ? Icons.location_on_outlined
                                : Icons.route_outlined,
                          ),
                        ),
                        child: Text(
                          fieldService
                              ? '${data['pickupLabel'] ?? ''}'
                              : '${data['pickupLabel'] ?? ''} → ${data['deliveryLabel'] ?? ''}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!fieldService)
                        TextField(
                          controller: weight,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Estimated weight',
                            suffixText: 'kg',
                            prefixIcon: Icon(Icons.scale_outlined),
                          ),
                        ),
                      if (!fieldService) const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_month_outlined),
                        title: Text(
                          fieldService ? 'Service needed' : 'Requested pickup date',
                        ),
                        subtitle: Text(_dateLabel(requestedAt)),
                        trailing: const Icon(Icons.edit_calendar_outlined),
                        onTap: () async {
                          final now = DateTime.now();
                          final first = DateTime(now.year, now.month, now.day);
                          final selected = await showDatePicker(
                            context: dialogContext,
                            initialDate:
                                requestedAt.isBefore(first) ? first : requestedAt,
                            firstDate: first,
                            lastDate: first.add(const Duration(days: 730)),
                          );
                          if (selected != null) update(() => requestedAt = selected);
                        },
                      ),
                      TextField(
                        controller: details,
                        minLines: 3,
                        maxLines: 7,
                        maxLength: 4000,
                        decoration: InputDecoration(
                          labelText:
                              fieldService ? 'Work scope *' : 'Load details *',
                          prefixIcon: const Icon(Icons.notes_outlined),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Go back'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save revision'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!saved) {
      title.dispose();
      details.dispose();
      weight.dispose();
      return;
    }
    if (title.text.trim().isEmpty || details.text.trim().isEmpty) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'Add a request title and enough detail before saving.',
          tone: PipeStatusTone.warning,
        );
      }
      title.dispose();
      details.dispose();
      weight.dispose();
      return;
    }

    try {
      final pickup = '${data['pickupLabel'] ?? ''}'.trim();
      final delivery = fieldService
          ? pickup
          : '${data['deliveryLabel'] ?? ''}'.trim();
      await _repository.updateJob(
        jobId: request.id,
        title: title.text,
        pickup: pickup,
        delivery: delivery,
        truckingDate: requestedAt,
        loadDetails: details.text,
        estimatedWeightKg:
            fieldService ? data['estimatedWeightKg'] as num? : num.tryParse(weight.text),
      );
      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'Request updated. The previous revision was preserved.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The request could not be updated.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      title.dispose();
      details.dispose();
      weight.dispose();
    }
  }

  Future<void> _cancelRequest(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.warning_amber_outlined, size: 36),
            title: const Text('Cancel this request?'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This closes the request before award and invalidates pending carrier quotes. This action is recorded in request history.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reason,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      hintText: 'Example: Work postponed or duplicate request',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep request'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: PipeBuyerColors.danger,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel request'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      reason.dispose();
      return;
    }

    try {
      await _repository.cancelJob(
        jobId: request.id,
        reason: reason.text,
      );
      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'Request cancelled. Pending carrier quotes are no longer active.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The request could not be cancelled.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      reason.dispose();
    }
  }

  Future<void> _showHistory(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .74,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: Text(
                  '${request.data()['title'] ?? 'Request'} history',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('Permanent request revisions'),
                trailing: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _repository
                      .jobHistoryQuery(request.id)
                      .limit(100)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final revisions = snapshot.data?.docs ?? const [];
                    if (revisions.isEmpty) {
                      return const Center(child: Text('No revisions recorded.'));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: revisions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final data = revisions[index].data();
                        final created = data['createdAt'] is Timestamp
                            ? (data['createdAt'] as Timestamp).toDate().toLocal()
                            : null;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${data['revision'] ?? '—'}'),
                            ),
                            title: Text(
                              _eventLabel('${data['event'] ?? 'updated'}'),
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text(
                              '${('${data['status'] ?? ''}').toUpperCase()}'
                              '${created == null ? '' : ' • ${_dateTimeLabel(created)}'}',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _eventLabel(String event) => switch (event) {
        'request_created' => 'Request submitted',
        'request_updated' => 'Request edited',
        'request_cancelled' => 'Request cancelled',
        'request_published' => 'Request opened',
        _ => event.replaceAll('_', ' '),
      };

  String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _dateTimeLabel(DateTime date) =>
      '${_dateLabel(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = status.replaceAll('_', ' ').toUpperCase();
    final color = switch (status) {
      'open' => PipeBuyerColors.success,
      'cancelled' => PipeBuyerColors.danger,
      _ => PipeBuyerColors.industrialBlue,
    };
    return Chip(
      avatar: Icon(Icons.circle, size: 10, color: color),
      label: Text(label),
    );
  }
}

class _RequestState extends StatelessWidget {
  const _RequestState({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: PipeBuyerColors.muted),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center),
                if (onRetry != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}
