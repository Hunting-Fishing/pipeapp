import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_actions_repository.dart';
import 'marketplace_deep_links.dart';
import 'marketplace_dispatch_multi_service_selector.dart';
import 'marketplace_reporting.dart';
import 'marketplace_reputation_badge.dart';

/// Functional action surface used by Dispatch Directory provider cards.
///
/// Direct contact actions come only from public fields the business explicitly
/// publishes. In-app messaging remains available when phone/email are private.
class MarketplaceDispatchDirectoryBusinessActions extends StatefulWidget {
  const MarketplaceDispatchDirectoryBusinessActions({
    super.key,
    required this.providerUid,
    required this.operatingName,
    required this.serviceCodes,
    this.remoteDataEnabled = true,
  });

  final String providerUid;
  final String operatingName;
  final List<String> serviceCodes;
  final bool remoteDataEnabled;

  @override
  State<MarketplaceDispatchDirectoryBusinessActions> createState() =>
      _MarketplaceDispatchDirectoryBusinessActionsState();
}

class _MarketplaceDispatchDirectoryBusinessActionsState
    extends State<MarketplaceDispatchDirectoryBusinessActions> {
  MarketplaceActionsRepository? _actions;
  Future<Map<String, dynamic>>? _publicProfile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.remoteDataEnabled) {
      _publicProfile = _loadPublicProfile();
    }
  }

  Future<Map<String, dynamic>> _loadPublicProfile() async {
    final document = await FirebaseFirestore.instance
        .collection('public_business_profiles')
        .doc(widget.providerUid)
        .get();
    return document.data() ?? const <String, dynamic>{};
  }

  MarketplaceActionsRepository get _actionRepository =>
      _actions ??= MarketplaceActionsRepository();

  bool get _isOwnBusiness =>
      widget.remoteDataEnabled &&
      FirebaseAuth.instance.currentUser?.uid == widget.providerUid;

  bool get _remoteActionsAvailable =>
      widget.remoteDataEnabled && !_isOwnBusiness;

  Future<void> _openBusiness() async {
    context.push(MarketplaceDeepLinks.profile(widget.providerUid));
  }

  Future<void> _messageBusiness() async {
    if (_busy || !_remoteActionsAvailable) return;
    setState(() => _busy = true);
    try {
      final conversationId = await _actionRepository.openBusinessConversation(
        providerUid: widget.providerUid,
      );
      if (!mounted) return;
      context.push(MarketplaceDeepLinks.conversation(conversationId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestQuote() async {
    if (_busy || !_remoteActionsAvailable) return;
    final request = await showDialog<_DirectoryQuoteRequest>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DirectoryQuoteRequestDialog(
        providerName: widget.operatingName,
        allowedServiceCodes: widget.serviceCodes,
      ),
    );
    if (request == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final conversationId = await _actionRepository.openBusinessConversation(
        providerUid: widget.providerUid,
      );
      await _actionRepository.sendChatMessage(
        conversationId,
        request.toMessage(widget.operatingName),
      );
      if (!mounted) return;
      context.push(MarketplaceDeepLinks.conversation(conversationId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportBusiness() async {
    if (!_remoteActionsAvailable) return;
    await showMarketplaceReportDialog(
      context,
      reportedUid: widget.providerUid,
      targetType: 'user',
    );
  }

  Future<void> _launch(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This contact action could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _publicProfile,
      builder: (context, snapshot) {
        final profile = snapshot.data ?? const <String, dynamic>{};
        final phone = '${profile['publicPhone'] ?? ''}'.trim();
        final email = '${profile['publicEmail'] ?? ''}'.trim();
        final website = '${profile['website'] ?? ''}'.trim();
        final membership = profile['membership'] is Map
            ? Map<String, dynamic>.from(profile['membership'] as Map)
            : const <String, dynamic>{};
        final tier = marketplaceMembershipTierFrom(
          profile['membershipTier'] ??
              profile['subscriptionTier'] ??
              membership['tier'],
        );
        final reputation = MarketplaceReputationSummary.fromMap(profile);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 640;
                final score = MarketplaceReputationBadge(
                  summary: reputation,
                  membershipTier: tier,
                  size: compact ? 62 : 70,
                  showLabel: !compact,
                );
                final actions = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy || !_remoteActionsAvailable
                          ? null
                          : _requestQuote,
                      icon: const Icon(Icons.request_quote_outlined),
                      label: const Text('Get Quote'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy || !_remoteActionsAvailable
                          ? null
                          : _messageBusiness,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Message'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openBusiness,
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('View Business'),
                    ),
                    if (phone.isNotEmpty)
                      IconButton.filledTonal(
                        tooltip: 'Call published business phone',
                        onPressed: () =>
                            _launch(Uri(scheme: 'tel', path: phone)),
                        icon: const Icon(Icons.phone_outlined),
                      ),
                    if (email.isNotEmpty)
                      IconButton.filledTonal(
                        tooltip: 'Email published business address',
                        onPressed: () =>
                            _launch(Uri(scheme: 'mailto', path: email)),
                        icon: const Icon(Icons.email_outlined),
                      ),
                    if (_safeWebsite(website) case final uri?)
                      IconButton.filledTonal(
                        tooltip: 'Open business website',
                        onPressed: () => _launch(uri),
                        icon: const Icon(Icons.language_outlined),
                      ),
                    if (_remoteActionsAvailable)
                      PopupMenuButton<String>(
                        tooltip: 'More business actions',
                        onSelected: (value) {
                          if (value == 'report') _reportBusiness();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'report',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.flag_outlined),
                              title: Text('Report Business'),
                            ),
                          ),
                        ],
                      ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          score,
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reputation.hasPublishedScore
                                      ? '${reputation.score}/100 · ${reputation.statusLabel}'
                                      : 'New provider · Building reputation',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${tier.label} member · Select score for legend',
                                  style: const TextStyle(
                                    color: PipeBuyerColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      actions,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    score,
                    const SizedBox(width: 16),
                    Expanded(child: actions),
                  ],
                );
              },
            ),
            if (_busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (snapshot.connectionState == ConnectionState.waiting) ...[
              const SizedBox(height: 8),
              const Text(
                'Loading published contact and reputation summary…',
                style: TextStyle(color: PipeBuyerColors.muted, fontSize: 11),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DirectoryQuoteRequest {
  const _DirectoryQuoteRequest({
    required this.serviceCodes,
    required this.location,
    required this.requestedDate,
    required this.urgency,
    required this.details,
  });

  final List<String> serviceCodes;
  final String location;
  final DateTime? requestedDate;
  final String urgency;
  final String details;

  String toMessage(String providerName) {
    final services = serviceCodes
        .map((code) => '- ${dispatchServiceLabelForCode(code)}')
        .join('\n');
    final dateLabel = requestedDate == null
        ? 'Flexible / to be confirmed'
        : '${requestedDate!.year}-${requestedDate!.month.toString().padLeft(2, '0')}-${requestedDate!.day.toString().padLeft(2, '0')}';
    return 'GET QUOTE REQUEST\n'
        'Provider: $providerName\n'
        'Services requested:\n$services\n'
        'Work / pickup location: $location\n'
        'Requested date: $dateLabel\n'
        'Priority: ${_urgencyLabel(urgency)}\n'
        'Scope / details: $details\n\n'
        'Please reply in Pipe Buyer with availability, questions, and your quote.';
  }
}

class _DirectoryQuoteRequestDialog extends StatefulWidget {
  const _DirectoryQuoteRequestDialog({
    required this.providerName,
    required this.allowedServiceCodes,
  });

  final String providerName;
  final List<String> allowedServiceCodes;

  @override
  State<_DirectoryQuoteRequestDialog> createState() =>
      _DirectoryQuoteRequestDialogState();
}

class _DirectoryQuoteRequestDialogState
    extends State<_DirectoryQuoteRequestDialog> {
  final TextEditingController _location = TextEditingController();
  final TextEditingController _details = TextEditingController();
  late List<String> _serviceCodes;
  DateTime? _requestedDate;
  String _urgency = 'flexible';
  String? _error;

  @override
  void initState() {
    super.initState();
    _serviceCodes = widget.allowedServiceCodes.isEmpty
        ? <String>[]
        : <String>[widget.allowedServiceCodes.first];
  }

  @override
  void dispose() {
    _location.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final current =
        _requestedDate ?? DateTime.now().add(const Duration(days: 1));
    final value = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (value != null && mounted) setState(() => _requestedDate = value);
  }

  void _submit() {
    final location = _location.text.trim();
    final details = _details.text.trim();
    if (_serviceCodes.isEmpty || location.isEmpty || details.length < 8) {
      setState(() => _error =
          'Choose at least one service, add the work location, and include enough detail for the provider to quote the work.');
      return;
    }
    Navigator.pop(
      context,
      _DirectoryQuoteRequest(
        serviceCodes: List<String>.unmodifiable(_serviceCodes),
        location: location,
        requestedDate: _requestedDate,
        urgency: _urgency,
        details: details,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Get Quote · ${widget.providerName}'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose one or more services this company provides. The request stays private between you and the provider.',
                ),
                const SizedBox(height: 14),
                MarketplaceDispatchMultiServiceSelector(
                  allowedServiceCodes: widget.allowedServiceCodes,
                  initialServiceCodes: _serviceCodes,
                  onChanged: (values) => _serviceCodes = values,
                  maximumItems: 6,
                  label: 'Services from this company',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Work / pickup location *',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final dateButton = OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        _requestedDate == null
                            ? 'Choose requested date'
                            : '${_requestedDate!.year}-${_requestedDate!.month.toString().padLeft(2, '0')}-${_requestedDate!.day.toString().padLeft(2, '0')}',
                      ),
                    );
                    final urgency = DropdownButtonFormField<String>(
                      initialValue: _urgency,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(
                          value: 'flexible',
                          child: Text('Flexible / planning'),
                        ),
                        DropdownMenuItem(
                          value: 'scheduled',
                          child: Text('Scheduled / date sensitive'),
                        ),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgent / ASAP'),
                        ),
                        DropdownMenuItem(
                          value: 'emergency',
                          child: Text('Emergency callout'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _urgency = value ?? 'flexible'),
                    );
                    if (constraints.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          dateButton,
                          const SizedBox(height: 10),
                          urgency,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: dateButton),
                        const SizedBox(width: 10),
                        Expanded(child: urgency),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _details,
                  minLines: 4,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText:
                        'Scope, equipment, quantity, dimensions, notes *',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: PipeBuyerColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send Quote Request'),
          ),
        ],
      );
}

String _urgencyLabel(String value) => switch (value) {
      'scheduled' => 'Scheduled / date sensitive',
      'urgent' => 'Urgent / ASAP',
      'emergency' => 'Emergency callout',
      _ => 'Flexible / planning',
    };

Uri? _safeWebsite(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}

String _friendlyError(Object error) {
  final text = '$error';
  if (text.contains('permission-denied')) {
    return 'This business action is not available for the current account.';
  }
  if (text.contains('failed-precondition')) {
    return 'Complete the required account steps before contacting this business.';
  }
  return 'The business action could not be completed. Please try again.';
}
