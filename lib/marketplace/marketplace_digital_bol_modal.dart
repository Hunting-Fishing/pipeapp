import 'package:flutter/material.dart';
import '../core/accessibility/pipe_status_feedback.dart';

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
  State<MarketplaceDigitalBolModal> createState() => _MarketplaceDigitalBolModalState();
}

class _MarketplaceDigitalBolModalState extends State<MarketplaceDigitalBolModal> {
  final _driverNameController = TextEditingController();
  final _truckNumberController = TextEditingController();
  final _notesController = TextEditingController();

  bool _cargoInspected = false;
  bool _securingStrapsVerified = false;
  bool _driverSigned = false;

  @override
  void dispose() {
    _driverNameController.dispose();
    _truckNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitBol() {
    if (_driverNameController.text.trim().isEmpty) {
      PipeFeedback.show(context, message: 'Driver Name is required.', tone: PipeStatusTone.warning);
      return;
    }
    if (_truckNumberController.text.trim().isEmpty) {
      PipeFeedback.show(context, message: 'Truck/Trailer # is required.', tone: PipeStatusTone.warning);
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
      PipeFeedback.show(context, message: 'Driver signature is required.', tone: PipeStatusTone.warning);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.description, color: Colors.deepOrange.shade800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DIGITAL BILL OF LADING (BOL)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Job #${widget.jobId}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Origin & Destination Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _locRow(Icons.location_on, 'PICKUP ORIGIN', widget.pickupAddress, Colors.green),
                    const SizedBox(height: 10),
                    _locRow(Icons.flag, 'DELIVERY DESTINATION', widget.deliveryAddress, Colors.red),
                    const Divider(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cargo: ${widget.cargoDescription}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Driver & Truck Info
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _driverNameController,
                      decoration: const InputDecoration(
                        labelText: 'Driver Full Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _truckNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Truck / Trailer Unit #',
                        prefixIcon: Icon(Icons.local_shipping),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Inspection Checklist
              const Text('PRE-TRIP INSPECTION SIGN-OFF', style: _subHeaderStyle),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _cargoInspected,
                title: const Text('Cargo count & condition verified at pickup'),
                onChanged: (val) => setState(() => _cargoInspected = val ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _securingStrapsVerified,
                title: const Text('Pipe dunnage & tie-down straps secured according to DOT specs'),
                onChanged: (val) => setState(() => _securingStrapsVerified = val ?? false),
              ),

              const SizedBox(height: 16),

              // Photo Inspection Attachments
              OutlinedButton.icon(
                onPressed: () {
                  PipeFeedback.show(
                    context,
                    message: 'Photo inspection capture ready. Select origin photos.',
                    tone: PipeStatusTone.info,
                  );
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Attach Pickup Photo Inspection (Required for Escrow Release)'),
              ),

              const SizedBox(height: 16),

              // Driver Digital Signature Box
              const Text('DRIVER DIGITAL SIGNATURE', style: _subHeaderStyle),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() => _driverSigned = true),
                child: Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _driverSigned ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _driverSigned ? Colors.green.shade400 : Colors.grey.shade400,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: _driverSigned
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.draw, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Digital Signature Captured ✓',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.touch_app, color: Colors.grey),
                              SizedBox(height: 4),
                              Text(
                                'Tap here to sign Digital BOL',
                                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Submit & Cancel
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submitBol,
                      icon: const Icon(Icons.verified),
                      label: const Text('Sign & Submit BOL'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const TextStyle _subHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Colors.blueGrey,
    letterSpacing: 0.8,
  );

  Widget _locRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
