import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';

class MarketplaceDigitalBolModal extends StatefulWidget {
  const MarketplaceDigitalBolModal({
    super.key,
    required this.jobId,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.cargoDescription,
  });

  final String jobId;
  final String pickupAddress;
  final String deliveryAddress;
  final String cargoDescription;

  @override
  State<MarketplaceDigitalBolModal> createState() =>
      _MarketplaceDigitalBolModalState();
}

class _MarketplaceDigitalBolModalState
    extends State<MarketplaceDigitalBolModal> {
  final _driverNameController = TextEditingController();
  final _truckNumberController = TextEditingController();
  final _notesController = TextEditingController();

  bool _cargoInspected = false;
  bool _securingStrapsVerified = false;
  bool _driverSigned = false;

  int get _completedChecks => [
        _cargoInspected,
        _securingStrapsVerified,
        _driverSigned,
      ].where((value) => value).length;

  @override
  void dispose() {
    _driverNameController.dispose();
    _truckNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitBol() {
    if (_driverNameController.text.trim().isEmpty) {
      PipeFeedback.show(
        context,
        message: 'Driver Name is required.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    if (_truckNumberController.text.trim().isEmpty) {
      PipeFeedback.show(
        context,
        message: 'Truck/Trailer # is required.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    if (!_cargoInspected || !_securingStrapsVerified) {
      PipeFeedback.show(
        context,
        message: 'Please complete cargo and securing inspection checkboxes.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    if (!_driverSigned) {
      PipeFeedback.show(
        context,
        message: 'Driver signature is required.',
        tone: PipeStatusTone.warning,
      );
      return;
    }

    Navigator.pop(context, true);
    PipeFeedback.show(
      context,
      message: 'Digital Bill of Lading (BOL) signed & verified!',
      tone: PipeStatusTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              const SizedBox(height: 16),
              _routeSummary(context),
              const SizedBox(height: 16),
              PipeBuyerSectionCard(
                title: 'Driver & equipment',
                subtitle:
                    'Identify the driver and truck/trailer unit attached to this Dispatch record.',
                leading: const _SectionIcon(
                  Icons.local_shipping_outlined,
                  tone: PipeBuyerStatusTone.info,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 620) {
                      return Column(
                        children: [
                          TextFormField(
                            controller: _driverNameController,
                            decoration: const InputDecoration(
                              labelText: 'Driver full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _truckNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Truck / trailer unit #',
                              prefixIcon:
                                  Icon(Icons.local_shipping_outlined),
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _driverNameController,
                            decoration: const InputDecoration(
                              labelText: 'Driver full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _truckNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Truck / trailer unit #',
                              prefixIcon:
                                  Icon(Icons.local_shipping_outlined),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              PipeBuyerSectionCard(
                title: 'Pre-trip inspection sign-off',
                subtitle:
                    'Complete the physical cargo and securement checks before applying the driver acknowledgement.',
                leading: const _SectionIcon(
                  Icons.fact_check_outlined,
                  tone: PipeBuyerStatusTone.warning,
                ),
                trailing: PipeBuyerStatusBadge(
                  label: '$_completedChecks / 3 READY',
                  icon: _completedChecks == 3
                      ? Icons.check_circle_outline
                      : Icons.pending_actions_outlined,
                  tone: _completedChecks == 3
                      ? PipeBuyerStatusTone.success
                      : PipeBuyerStatusTone.warning,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InspectionCheck(
                      value: _cargoInspected,
                      title: 'Cargo count & condition verified at pickup',
                      subtitle:
                          'Confirm the physical load matches the Dispatch record before departure.',
                      onChanged: (value) =>
                          setState(() => _cargoInspected = value),
                    ),
                    const SizedBox(height: 8),
                    _InspectionCheck(
                      value: _securingStrapsVerified,
                      title:
                          'Pipe dunnage & tie-down securement verified',
                      subtitle:
                          'Confirm the driver has completed the applicable load-securement inspection.',
                      onChanged: (value) =>
                          setState(() => _securingStrapsVerified = value),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        PipeFeedback.show(
                          context,
                          message:
                              'Photo inspection capture ready. Select origin photos.',
                          tone: PipeStatusTone.info,
                        );
                      },
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text(
                        'Attach pickup photo inspection',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pickup inspection photos may be required by the applicable escrow/job workflow before release.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: .60),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PipeBuyerSectionCard(
                title: 'Driver acknowledgement',
                subtitle:
                    'The current Dispatch workflow records an acknowledgement state. It does not capture a drawn signature image on this screen.',
                leading: const _SectionIcon(
                  Icons.draw_outlined,
                  tone: PipeBuyerStatusTone.premium,
                ),
                trailing: PipeBuyerStatusBadge(
                  label: _driverSigned ? 'ACKNOWLEDGED' : 'REQUIRED',
                  icon: _driverSigned
                      ? Icons.verified_outlined
                      : Icons.touch_app_outlined,
                  tone: _driverSigned
                      ? PipeBuyerStatusTone.success
                      : PipeBuyerStatusTone.warning,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _driverSigned = true),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 108),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (_driverSigned
                                  ? PipeBuyerColors.success
                                  : PipeBuyerColors.slate)
                              .withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: (_driverSigned
                                    ? PipeBuyerColors.success
                                    : PipeBuyerColors.slate)
                                .withValues(alpha: .24),
                          ),
                        ),
                        child: Center(
                          child: _driverSigned
                              ? const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_outlined,
                                      color: PipeBuyerColors.success,
                                      size: 32,
                                    ),
                                    SizedBox(height: 7),
                                    Text(
                                      'Driver acknowledgement applied',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: PipeBuyerColors.success,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                )
                              : const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.touch_app_outlined,
                                      color: PipeBuyerColors.slate,
                                      size: 30,
                                    ),
                                    SizedBox(height: 7),
                                    Text(
                                      'Tap to apply driver acknowledgement',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Driver / load notes (optional)',
                        prefixIcon: Icon(Icons.notes_outlined),
                        hintText:
                            'Record visible cargo condition, securement notes, or pickup exceptions.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final cancel = OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  );
                  final submit = FilledButton.icon(
                    onPressed: _submitBol,
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Verify & submit BOL'),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [submit, const SizedBox(height: 8), cancel],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: cancel),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: submit),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: PipeBuyerColors.orange.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: PipeBuyerColors.orange,
                size: 26,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PipeBuyerStatusBadge(
                    label: 'DISPATCH DOCUMENT',
                    icon: Icons.route_outlined,
                    tone: PipeBuyerStatusTone.premium,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Digital Bill of Lading',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Job #${widget.jobId}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close BOL',
              color: Colors.white70,
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );

  Widget _routeSummary(BuildContext context) => PipeBuyerSectionCard(
        title: 'Route & cargo summary',
        subtitle: 'Confirm the load attached to this Dispatch job.',
        leading: const _SectionIcon(
          Icons.alt_route_outlined,
          tone: PipeBuyerStatusTone.info,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _locRow(
              Icons.trip_origin,
              'PICKUP ORIGIN',
              widget.pickupAddress,
              PipeBuyerColors.success,
            ),
            const Padding(
              padding: EdgeInsets.only(left: 19),
              child: SizedBox(
                height: 22,
                child: VerticalDivider(width: 1, thickness: 2),
              ),
            ),
            _locRow(
              Icons.location_on_outlined,
              'DELIVERY DESTINATION',
              widget.deliveryAddress,
              PipeBuyerColors.danger,
            ),
            const Divider(height: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.orangeSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                    color: PipeBuyerColors.orangePressed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CARGO',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: PipeBuyerColors.orangePressed,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .7,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.cargoDescription,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _locRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InspectionCheck extends StatelessWidget {
  const _InspectionCheck({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: (value ? PipeBuyerColors.success : PipeBuyerColors.slate)
              .withValues(alpha: .05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (value ? PipeBuyerColors.success : PipeBuyerColors.slate)
                .withValues(alpha: .14),
          ),
        ),
        child: CheckboxListTile(
          value: value,
          onChanged: (next) => onChanged(next ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(subtitle),
        ),
      );
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon(this.icon, {required this.tone});

  final IconData icon;
  final PipeBuyerStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = pipeBuyerToneColor(tone);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }
}
