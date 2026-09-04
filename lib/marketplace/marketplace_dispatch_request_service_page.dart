import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';
import 'marketplace_dispatch_multi_service_selector.dart';
import 'marketplace_dispatch_request_flow.dart';
import 'marketplace_dispatch_request_repository.dart';
import 'marketplace_location.dart';
import 'marketplace_location_picker.dart';

class MarketplaceDispatchRequestServicePage extends StatefulWidget {
  const MarketplaceDispatchRequestServicePage({super.key});

  @override
  State<MarketplaceDispatchRequestServicePage> createState() =>
      _MarketplaceDispatchRequestServicePageState();
}

class _MarketplaceDispatchRequestServicePageState
    extends State<MarketplaceDispatchRequestServicePage> {
  static const _maximumAttachments = 5;
  static const _maximumAttachmentBytes = 15 * 1024 * 1024;

  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _details = TextEditingController();
  final _repository = MarketplaceDispatchRequestRepository();

  late String _jobId;
  List<String> _serviceCodes = <String>[];
  MarketplaceLocation? _pickupOrWorkSite;
  MarketplaceLocation? _delivery;
  DateTime _requestedAt = DateTime.now().add(const Duration(days: 1));
  DispatchContactPreference _contactPreference =
      DispatchContactPreference.inApp;
  final List<XFile> _attachments = <XFile>[];
  List<Map<String, dynamic>>? _uploadedAttachmentReferences;
  bool _submitting = false;
  String? _error;

  DispatchRequestPath get _path =>
      DispatchRequestFlow.pathForServiceCodes(_serviceCodes);

  bool get _isFreight => _path == DispatchRequestPath.freightRoute;

  User? get _user => FirebaseAuth.instance.currentUser;

  bool get _emailAvailable =>
      _user?.emailVerified == true && (_user?.email?.trim().isNotEmpty ?? false);

  bool get _phoneAvailable => _user?.phoneNumber?.trim().isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    _jobId = _repository.reserveJobId();
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Request Service')),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              children: [
                const PipeBuyerPageHeader(
                  eyebrow: 'DISPATCH REQUEST',
                  title: 'Tell us what service you need',
                  subtitle:
                      'Choose the work first. Pipe Buyer only asks for a route when the selected service actually needs one.',
                  icon: Icons.handyman_outlined,
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: '1. Service',
                  icon: Icons.category_outlined,
                  child: MarketplaceDispatchMultiServiceSelector(
                    initialServiceCodes: _serviceCodes,
                    onChanged: (values) {
                      setState(() {
                        _serviceCodes = values;
                        _error = null;
                        if (_serviceCodes.isNotEmpty && !_isFreight) {
                          _delivery = null;
                        }
                      });
                    },
                    label: 'What do you need?',
                    helperText:
                        'Select one or more services. Transportation and pilot work use pickup/delivery; crane and field work use a work site.',
                  ),
                ),
                const SizedBox(height: 12),
                _pathCard(),
                if (_serviceCodes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _sectionCard(
                    title: _isFreight ? '2. Route' : '2. Work site',
                    icon: _isFreight
                        ? Icons.route_outlined
                        : Icons.location_on_outlined,
                    child: Column(
                      children: [
                        _LocationSelectionCard(
                          title:
                              _isFreight ? 'Pickup location' : 'Work-site location',
                          helper: _isFreight
                              ? 'Pin the loading point. Exact coordinates stay protected.'
                              : 'Pin where the service is needed. Exact coordinates stay protected.',
                          icon: _isFreight
                              ? Icons.trip_origin
                              : Icons.location_on_outlined,
                          location: _pickupOrWorkSite,
                          onTap: _choosePickupOrWorkSite,
                        ),
                        if (_isFreight) ...[
                          const SizedBox(height: 10),
                          _LocationSelectionCard(
                            title: 'Delivery location',
                            helper:
                                'Pin the destination and include access notes in the map form when needed.',
                            icon: Icons.flag_outlined,
                            location: _delivery,
                            onTap: _chooseDelivery,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _sectionCard(
                  title: '3. Timing & details',
                  icon: Icons.edit_note_outlined,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _title,
                        enabled: !_submitting,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'Request title *',
                          hintText: 'Example: Vacuum truck for tank cleanout',
                          prefixIcon: Icon(Icons.title_outlined),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Add a short request title.'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _details,
                        enabled: !_submitting,
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 4000,
                        decoration: InputDecoration(
                          labelText: _isFreight
                              ? 'Load and equipment details *'
                              : 'Work scope and equipment details *',
                          hintText: _isFreight
                              ? 'Describe the load, dimensions, approximate weight, loading conditions, and equipment needed.'
                              : 'Describe the work, site conditions, equipment or capacity needed, access restrictions, and special requirements.',
                          prefixIcon: const Icon(Icons.description_outlined),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Add enough detail for a provider to understand the request.'
                            : null,
                      ),
                      const SizedBox(height: 6),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.calendar_month_outlined),
                        ),
                        title: Text(
                          _isFreight ? 'Requested pickup date' : 'Service needed',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(_dateLabel(_requestedAt)),
                        trailing: const Icon(Icons.edit_calendar_outlined),
                        onTap: _submitting ? null : _pickDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: '4. Photos',
                  icon: Icons.add_photo_alternate_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _submitting ||
                                _attachments.length >= _maximumAttachments
                            ? null
                            : _pickAttachments,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          _attachments.isEmpty
                              ? 'Add request photos'
                              : 'Add another photo (${_attachments.length}/$_maximumAttachments)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Optional. Up to 5 JPG, PNG or WebP photos, 15 MB each. Photos are stored privately with your request; provider file access is not opened broadly in this release.',
                        style: TextStyle(
                          fontSize: 12,
                          color: PipeBuyerColors.muted,
                          height: 1.35,
                        ),
                      ),
                      if (_attachments.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (var index = 0;
                            index < _attachments.length;
                            index++)
                          _attachmentTile(index),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: '5. Contact preference',
                  icon: Icons.contact_phone_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'In-app messaging is the safest default. Phone and email are available only when that contact is verified on your Pipe Buyer account.',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _contactChip(
                            DispatchContactPreference.inApp,
                            'In-app',
                            Icons.chat_bubble_outline,
                            true,
                          ),
                          _contactChip(
                            DispatchContactPreference.phone,
                            'Phone',
                            Icons.phone_outlined,
                            _phoneAvailable,
                          ),
                          _contactChip(
                            DispatchContactPreference.email,
                            'Email',
                            Icons.email_outlined,
                            _emailAvailable,
                          ),
                        ],
                      ),
                      if (!_phoneAvailable || !_emailAvailable) ...[
                        const SizedBox(height: 8),
                        Text(
                          _verificationHint(),
                          style: const TextStyle(
                            color: PipeBuyerColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFFFFE9E7),
                    child: ListTile(
                      leading: const Icon(
                        Icons.error_outline,
                        color: PipeBuyerColors.danger,
                      ),
                      title: const Text(
                        'Request not ready',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(_error!),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submitting ? null : _review,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fact_check_outlined),
                  label: Text(
                    _submitting ? 'Submitting request…' : 'Review request',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nothing is submitted until you review the summary and select Submit request.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(child: Icon(icon)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );

  Widget _pathCard() {
    final selected = _serviceCodes.isNotEmpty;
    final fieldService = selected && !_isFreight;
    return Card(
      margin: EdgeInsets.zero,
      color: fieldService ? const Color(0xFFE8F7F1) : const Color(0xFFEAF4FD),
      child: ListTile(
        leading: Icon(
          fieldService ? Icons.engineering_outlined : Icons.route_outlined,
          color: fieldService
              ? PipeBuyerColors.success
              : PipeBuyerColors.industrialBlue,
        ),
        title: Text(
          !selected
              ? 'Choose a service to set up the request'
              : fieldService
                  ? 'On-site service request'
                  : 'Route-based request',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          !selected
              ? 'The form changes automatically after you choose the work needed.'
              : fieldService
                  ? 'One mapped work site is required. Submit saves it to My Requests; use Directory Get Quote when you need immediate provider-specific outreach.'
                  : 'Pickup and delivery locations are required for transportation or pilot/route work.',
        ),
      ),
    );
  }

  Widget _contactChip(
    DispatchContactPreference preference,
    String label,
    IconData icon,
    bool enabled,
  ) {
    return ChoiceChip(
      selected: _contactPreference == preference,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: enabled && !_submitting
          ? (selected) {
              if (selected) setState(() => _contactPreference = preference);
            }
          : null,
    );
  }

  Widget _attachmentTile(int index) {
    final file = _attachments[index];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.image_outlined)),
      title: Text(
        file.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: const Text('Private request photo'),
      trailing: IconButton(
        tooltip: 'Remove photo',
        onPressed: _submitting ? null : () => _removeAttachment(index),
        icon: const Icon(Icons.close),
      ),
    );
  }

  Future<void> _choosePickupOrWorkSite() async {
    final selected = await MarketplaceLocationPicker.show(
      context,
      _pickupOrWorkSite,
      title: _isFreight ? 'Pickup location' : 'Work-site location',
    );
    if (selected != null && mounted) {
      setState(() {
        _pickupOrWorkSite = selected;
        _error = null;
      });
    }
  }

  Future<void> _chooseDelivery() async {
    final selected = await MarketplaceLocationPicker.showDelivery(
      context,
      _delivery,
    );
    if (selected != null && mounted) {
      setState(() {
        _delivery = selected;
        _error = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final current = _requestedAt.isBefore(firstDate) ? firstDate : _requestedAt;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 730)),
    );
    if (selected != null && mounted) {
      setState(() {
        _requestedAt = selected;
        _error = null;
      });
    }
  }

  Future<void> _pickAttachments() async {
    final remaining = _maximumAttachments - _attachments.length;
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 88,
      maxWidth: 2400,
    );
    if (picked.isEmpty || !mounted) return;

    var rejected = 0;
    final additions = <XFile>[];
    for (final file in picked) {
      if (additions.length >= remaining) break;
      final extension = file.name.split('.').last.toLowerCase();
      final size = await file.length();
      final supported = const <String>{'jpg', 'jpeg', 'png', 'webp'}
          .contains(extension);
      if (!supported || size < 1 || size > _maximumAttachmentBytes) {
        rejected += 1;
        continue;
      }
      additions.add(file);
    }
    if (!mounted) return;
    setState(() {
      _attachments.addAll(additions);
      _uploadedAttachmentReferences = null;
      _error = null;
    });
    if (rejected > 0) {
      PipeFeedback.show(
        context,
        message:
            '$rejected photo${rejected == 1 ? '' : 's'} skipped. Use JPG, PNG or WebP photos up to 15 MB.',
        tone: PipeStatusTone.warning,
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
      _uploadedAttachmentReferences = null;
    });
  }

  Future<void> _review() async {
    FocusScope.of(context).unfocus();
    if (_form.currentState?.validate() != true) return;
    final pickupLabel = _locationLabel(_pickupOrWorkSite);
    final deliveryLabel = _locationLabel(_delivery);
    final issues = DispatchRequestFlow.reviewIssues(
      serviceCodes: _serviceCodes,
      pickupLabel: pickupLabel,
      deliveryLabel: deliveryLabel,
      requestedAt: _requestedAt,
      details: _details.text,
      contactPreference: _contactPreference,
      phone: _phoneAvailable ? _user!.phoneNumber! : '',
      email: _emailAvailable ? _user!.email! : '',
    );
    if (issues.isNotEmpty) {
      setState(() => _error = issues.first.message);
      return;
    }
    if (_pickupOrWorkSite == null || (_isFreight && _delivery == null)) {
      setState(() => _error = _isFreight
          ? 'Select mapped pickup and delivery locations.'
          : 'Select the mapped work-site location.');
      return;
    }

    setState(() => _error = null);
    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Review request'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _reviewRow(
                      'Services',
                      _serviceCodes
                          .map(dispatchServiceLabelForCode)
                          .join(', '),
                    ),
                    _reviewRow(
                      'Request type',
                      _isFreight ? 'Route-based' : 'On-site service',
                    ),
                    _reviewRow(
                      _isFreight ? 'Pickup' : 'Work site',
                      pickupLabel,
                    ),
                    if (_isFreight) _reviewRow('Delivery', deliveryLabel),
                    _reviewRow('Needed', _dateLabel(_requestedAt)),
                    _reviewRow('Contact', _contactLabel(_contactPreference)),
                    _reviewRow(
                      'Photos',
                      _attachments.isEmpty
                          ? 'None'
                          : '${_attachments.length} private photo${_attachments.length == 1 ? '' : 's'}',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Request details',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(_details.text.trim()),
                    const SizedBox(height: 12),
                    Card(
                      color: const Color(0xFFEAF4FD),
                      child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Submission creates Version 1'),
                        subtitle: Text(
                          _isFreight
                              ? 'You can manage or cancel the request before award. Earlier revisions remain preserved when an editable request is changed.'
                              : 'The on-site request is received into My Requests and remains editable or cancellable. Use Directory Get Quote for immediate provider-specific outreach.',
                        ),
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
                icon: const Icon(Icons.send_outlined),
                label: const Text('Submit request'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed && mounted) await _submit();
  }

  Future<void> _submit() async {
    final pickup = _pickupOrWorkSite;
    if (pickup == null || (_isFreight && _delivery == null)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      var uploaded = _uploadedAttachmentReferences;
      if (uploaded == null) {
        uploaded = <Map<String, dynamic>>[];
        for (final file in _attachments) {
          final bytes = await file.readAsBytes();
          uploaded.add(await _repository.uploadAttachment(
            jobId: _jobId,
            name: file.name,
            contentType: _contentType(file),
            bytes: bytes,
          ));
        }
        _uploadedAttachmentReferences = uploaded;
      }
      final jobId = await _repository.createRequest(
        jobId: _jobId,
        serviceCodes: List<String>.unmodifiable(_serviceCodes),
        requestPath: _isFreight ? 'freight_route' : 'field_service',
        contactPreference: _wireContact(_contactPreference),
        title: _title.text,
        pickupOrWorkSite: pickup,
        delivery: _isFreight ? _delivery : null,
        requestedAt: _requestedAt,
        details: _details.text,
        attachments: uploaded,
      );
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: _isFreight
            ? 'Dispatch request submitted for provider quotes.'
            : 'Service request received. Manage it in My Requests, or use Directory Get Quote for immediate provider-specific outreach.',
        tone: PipeStatusTone.success,
      );
      Navigator.pop(context, jobId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback:
              'The request could not be submitted. Your current entries are still here so you can retry.',
        );
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _reviewRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
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

  String _locationLabel(MarketplaceLocation? location) {
    if (location == null) return '';
    final publicName = location.publicName.trim();
    if (publicName.isNotEmpty) return publicName;
    return location.nearestTown.trim();
  }

  String _verificationHint() {
    if (!_phoneAvailable && !_emailAvailable) {
      return 'Verify a phone number or email in Account Settings to use those contact methods.';
    }
    if (!_phoneAvailable) {
      return 'Verify a mobile number in Account Settings to enable phone contact.';
    }
    return 'Verify your email address in Account Settings to enable email contact.';
  }

  String _contentType(XFile file) {
    final extension = file.name.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  String _wireContact(DispatchContactPreference preference) => switch (preference) {
        DispatchContactPreference.inApp => 'in_app',
        DispatchContactPreference.phone => 'phone',
        DispatchContactPreference.email => 'email',
      };

  String _contactLabel(DispatchContactPreference preference) =>
      switch (preference) {
        DispatchContactPreference.inApp => 'In-app messaging',
        DispatchContactPreference.phone => 'Verified phone',
        DispatchContactPreference.email => 'Verified email',
      };

  String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _LocationSelectionCard extends StatelessWidget {
  const _LocationSelectionCard({
    required this.title,
    required this.helper,
    required this.icon,
    required this.location,
    required this.onTap,
  });

  final String title;
  final String helper;
  final IconData icon;
  final MarketplaceLocation? location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = location != null;
    final label = selected
        ? (location!.publicName.trim().isNotEmpty
            ? location!.publicName.trim()
            : location!.nearestTown.trim())
        : 'Select on map';
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? const Color(0xFFE8F7F1) : const Color(0xFFF1F5F9),
      child: ListTile(
        minVerticalPadding: 14,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(
          '$title *',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('$label\n$helper'),
        isThreeLine: true,
        trailing: const Icon(Icons.map_outlined),
        onTap: onTap,
      ),
    );
  }
}
