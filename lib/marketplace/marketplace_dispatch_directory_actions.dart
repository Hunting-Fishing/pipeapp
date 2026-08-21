import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_actions_repository.dart';
import 'marketplace_deep_links.dart';
import 'marketplace_dispatch_service_taxonomy.dart';
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
    this.serviceCode = '',
  });

  final String providerUid;
  final String operatingName;
  final String serviceCode;

  @override
  State<MarketplaceDispatchDirectoryBusinessActions> createState() =>
      _MarketplaceDispatchDirectoryBusinessActionsState();
}

class _MarketplaceDispatchDirectoryBusinessActionsState
    extends State<MarketplaceDispatchDirectoryBusinessActions> {
  final MarketplaceActionsRepository _actions = MarketplaceActionsRepository();
  late Future<Map<String, dynamic>> _publicProfile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _publicProfile = _loadPublicProfile();
  }

  Future<Map<String, dynamic>> _loadPublicProfile() async {
    final document = await FirebaseFirestore.instance
        .collection('public_business_profiles')
        .doc(widget.providerUid)
        .get();
    return document.data() ?? const <String, dynamic>{};
  }

  bool get _isOwnBusiness =>
      FirebaseAuth.instance.currentUser?.uid == widget.providerUid;

  Future<void> _openBusiness() async {
    context.push(MarketplaceDeepLinks.profile(widget.providerUid));
  }

  Future<void> _messageBusiness() async {
    if (_busy || _isOwnBusiness) return;
    setState(() => _busy = true);
    try {
      final conversationId = await _actions.openBusinessConversation(
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
    if (_busy || _isOwnBusiness) return;
    final request = await showDialog<_DirectoryQuoteRequest>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DirectoryQuoteRequestDialog(
        providerName: widget.operatingName,
        initialServiceCode: widget.serviceCode,
      ),
    );
    if (request == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final conversationId = await _actions.openBusinessConversation(
        providerUid: widget.providerUid,
      );
      await _actions.sendChatMessage(
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
    if (_isOwnBusiness) return;
    await showMarketplaceReportDialog(
      context,
      reportedUid: widget.providerUid,
      targetType: 'user',
    );
  }

  Future<void> _launch(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This contact action could not be opened.')),
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
        final websiteUri = _safeWebsite(website);

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
                      onPressed: _busy || _isOwnBusiness ? null : _requestQuote,
                      icon: const Icon(Icons.request_quote_outlined),
                      label: const Text('Get Quote'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy || _isOwnBusiness ? null : _messageBusiness,
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
                        onPressed: () => _launch(Uri(scheme: 'tel', path: phone)),
                        icon: const Icon(Icons.phone_outlined),
                      ),
                    if (email.isNotEmpty)
                      IconButton.filledTonal(
                        tooltip: 'Email published business address',
                        onPressed: () => _launch(Uri(scheme: 'mailto', path: email)),
                        icon: const Icon(Icons.email_outlined),
                      ),
                    if (websiteUri != null)
                      IconButton.filledTonal(
                        tooltip: 'Open business website',
                        onPressed: () => _launch(websiteUri),
                        icon: const Icon(Icons.language_outlined),
                      ),
                    if (!_isOwnBusiness)
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
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${tier.label} · Select score for legend',
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
    required this.serviceLabel,
    required this.location,
    required this.requestedDate,
    required this.details,
  });

  final String serviceLabel;
  final String location;
  final String requestedDate;
  final String details;

  String toMessage(String providerName) =>
      'GET QUOTE REQUEST\n'
      'Provider: $providerName\n'
      'Service: $serviceLabel\n'
      'Work location: $location\n'
      '${requestedDate.isEmpty ? '' : 'Requested date/window: $requestedDate\n'}'
      'Scope / details: $details\n\n'
      'Please reply in Pipe Buyer with availability, questions, and your quote.';
}

class _DirectoryQuoteRequestDialog extends StatefulWidget {
  const _DirectoryQuoteRequestDialog({
    required this.providerName,
    required this.initialServiceCode,
  });

  final String providerName;
  final String initialServiceCode;

  @override
  State<_DirectoryQuoteRequestDialog> createState() =>
      _DirectoryQuoteRequestDialogState();
}

class _DirectoryQuoteRequestDialogState
    extends State<_DirectoryQuoteRequestDialog> {
  late final TextEditingController _service;
  final TextEditingController _location = TextEditingController();
  final TextEditingController _date = TextEditingController();
  final TextEditingController _details = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = TextEditingController(
      text: _serviceLabel(widget.initialServiceCode),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    _location.dispose();
    _date.dispose();
    _details.dispose();
    super.dispose();
  }

  void _submit() {
    final service = _service.text.trim();
    final location = _location.text.trim();
    final details = _details.text.trim();
    if (service.isEmpty || location.isEmpty || details.length < 8) {
      setState(() => _error =
          'Add the service, work location, and enough detail for the provider to quote the work.');
      return;
    }
    Navigator.pop(
      context,
      _DirectoryQuoteRequest(
        serviceLabel: service,
        location: location,
        requestedDate: _date.text.trim(),
        details: details,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Get Quote · ${widget.providerName}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This sends a private quote request into a Pipe Buyer business conversation. The provider can reply with availability, questions, and pricing.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _service,
                  decoration: const InputDecoration(labelText: 'Service needed *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Work / pickup location *',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _date,
                  decoration: const InputDecoration(
                    labelText: 'Requested date or time window',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _details,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Scope, equipment, quantity, dimensions, notes *',
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

String _serviceLabel(String code) {
  if (code.trim().isEmpty) return '';
  for (final service in DispatchServiceTaxonomy.services) {
    if (service.code == code) return service.label;
  }
  return code;
}

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
