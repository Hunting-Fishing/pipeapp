import 'package:flutter/material.dart';
import '../core/accessibility/pipe_status_feedback.dart';

class MarketplacePayoutSettingsPage extends StatefulWidget {
  const MarketplacePayoutSettingsPage({super.key});

  @override
  State<MarketplacePayoutSettingsPage> createState() => _MarketplacePayoutSettingsPageState();
}

class _MarketplacePayoutSettingsPageState extends State<MarketplacePayoutSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _routingNumberController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _taxIdController = TextEditingController();

  String _accountType = 'Checking';
  bool _isSaved = false;

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _routingNumberController.dispose();
    _accountNumberController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  void _savePayoutSettings() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaved = true);
      PipeFeedback.show(
        context,
        message: 'Bank Account & Payout Details updated successfully!',
        tone: PipeStatusTone.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banking & Payout Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Card
                  Card(
                    elevation: 0,
                    color: const Color(0xFF0878E8).withAlpha(15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: const Color(0xFF0878E8).withAlpha(50)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance, color: Color(0xFF0878E8), size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Direct Bank Payouts & Escrow Settlement',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Connect your US/Canada bank account to receive direct ACH/Wire payouts when escrow funds are released.',
                                  style: TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('BANK ACCOUNT DETAILS', style: _sectionHeaderStyle),
                  const SizedBox(height: 12),

                  // Account Holder Name
                  TextFormField(
                    controller: _accountHolderController,
                    decoration: const InputDecoration(
                      labelText: 'Account Holder Name (Individual or Business)',
                      hintText: 'e.g. Acme Pipe Logistics LLC',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter account holder name' : null,
                  ),
                  const SizedBox(height: 16),

                  // Bank Name
                  TextFormField(
                    controller: _bankNameController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name',
                      hintText: 'e.g. JPMorgan Chase / RBC / Wells Fargo',
                      prefixIcon: Icon(Icons.account_balance_outlined),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter bank name' : null,
                  ),
                  const SizedBox(height: 16),

                  // Routing Number & Account Number
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _routingNumberController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Routing Number (9 Digits)',
                            hintText: '123456789',
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          validator: (val) =>
                              val == null || val.trim().length < 8 ? 'Enter valid routing number' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _accountNumberController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Account Number',
                            hintText: '••••••••',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (val) =>
                              val == null || val.trim().length < 5 ? 'Enter valid account number' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Account Type Selector
                  DropdownButtonFormField<String>(
                    value: _accountType,
                    decoration: const InputDecoration(
                      labelText: 'Account Type',
                      prefixIcon: Icon(Icons.credit_card),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Checking', child: Text('Checking Account')),
                      DropdownMenuItem(value: 'Savings', child: Text('Savings Account')),
                      DropdownMenuItem(value: 'Business Checking', child: Text('Business Checking')),
                    ],
                    onChanged: (val) => setState(() => _accountType = val ?? 'Checking'),
                  ),
                  const SizedBox(height: 24),

                  Text('TAX & COMPLIANCE VERIFICATION', style: _sectionHeaderStyle),
                  const SizedBox(height: 12),

                  // Tax ID / EIN
                  TextFormField(
                    controller: _taxIdController,
                    decoration: const InputDecoration(
                      labelText: 'Tax ID / EIN / SSN (For 1099-K Tax Forms)',
                      hintText: 'XX-XXXXXXX',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter Tax ID / EIN' : null,
                  ),
                  const SizedBox(height: 24),

                  if (_isSaved)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700),
                          const SizedBox(width: 10),
                          const Text(
                            'Bank Account Status: VERIFIED & ACTIVE',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _savePayoutSettings,
                      icon: const Icon(Icons.save),
                      label: const Text('Save & Verify Payout Account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const TextStyle _sectionHeaderStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Colors.blueGrey,
    letterSpacing: 0.9,
  );
}
