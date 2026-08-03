import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/accessibility/pipe_status_feedback.dart';

class MarketplacePayoutSettingsPage extends StatefulWidget {
  const MarketplacePayoutSettingsPage({super.key});

  @override
  State<MarketplacePayoutSettingsPage> createState() => _MarketplacePayoutSettingsPageState();
}

class _MarketplacePayoutSettingsPageState extends State<MarketplacePayoutSettingsPage> {
  final _achFormKey = GlobalKey<FormState>();
  final _gccFormKey = GlobalKey<FormState>();
  final _swiftFormKey = GlobalKey<FormState>();
  final _taxFormKey = GlobalKey<FormState>();

  // US & Canada ACH Controllers
  final _achBankNameController = TextEditingController();
  final _achHolderController = TextEditingController();
  final _achRoutingController = TextEditingController();
  final _achAccountController = TextEditingController();
  String _achAccountType = 'Business Checking';

  // Saudi Arabia & GCC IBAN Controllers
  final _gccBankNameController = TextEditingController();
  final _gccHolderController = TextEditingController();
  final _gccIbanController = TextEditingController();
  final _gccSwiftController = TextEditingController();
  String _gccCurrency = 'SAR (Saudi Riyal)';

  // Global SWIFT / International Wire Controllers
  final _swiftBankNameController = TextEditingController();
  final _swiftHolderController = TextEditingController();
  final _swiftCodeController = TextEditingController();
  final _swiftIbanController = TextEditingController();
  final _swiftCountryController = TextEditingController();

  // Tax & 1099-K Compliance Controllers
  final _taxIdController = TextEditingController();
  final _legalEntityController = TextEditingController();
  String _taxFormType = 'W-9 (US Person / Entity)';

  bool _loading = true;
  bool _savingAch = false;
  bool _savingGcc = false;
  bool _savingSwift = false;
  bool _savingTax = false;

  bool _achSaved = false;
  bool _gccSaved = false;
  bool _swiftSaved = false;
  bool _taxSaved = false;

  @override
  void initState() {
    super.initState();
    _loadExistingPayoutSettings();
  }

  @override
  void dispose() {
    _achBankNameController.dispose();
    _achHolderController.dispose();
    _achRoutingController.dispose();
    _achAccountController.dispose();
    _gccBankNameController.dispose();
    _gccHolderController.dispose();
    _gccIbanController.dispose();
    _gccSwiftController.dispose();
    _swiftBankNameController.dispose();
    _swiftHolderController.dispose();
    _swiftCodeController.dispose();
    _swiftIbanController.dispose();
    _swiftCountryController.dispose();
    _taxIdController.dispose();
    _legalEntityController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPayoutSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final payout = data['payoutSettings'] as Map<String, dynamic>? ?? {};

        // ACH
        _achBankNameController.text = payout['achBankName'] ?? '';
        _achHolderController.text = payout['achHolder'] ?? '';
        _achRoutingController.text = payout['achRouting'] ?? '';
        _achAccountController.text = payout['achAccount'] ?? '';
        if (payout['achType'] != null) _achAccountType = payout['achType'];
        _achSaved = _achBankNameController.text.isNotEmpty;

        // GCC
        _gccBankNameController.text = payout['gccBankName'] ?? '';
        _gccHolderController.text = payout['gccHolder'] ?? '';
        _gccIbanController.text = payout['gccIban'] ?? '';
        _gccSwiftController.text = payout['gccSwift'] ?? '';
        if (payout['gccCurrency'] != null) _gccCurrency = payout['gccCurrency'];
        _gccSaved = _gccIbanController.text.isNotEmpty;

        // SWIFT
        _swiftBankNameController.text = payout['swiftBankName'] ?? '';
        _swiftHolderController.text = payout['swiftHolder'] ?? '';
        _swiftCodeController.text = payout['swiftCode'] ?? '';
        _swiftIbanController.text = payout['swiftIban'] ?? '';
        _swiftCountryController.text = payout['swiftCountry'] ?? '';
        _swiftSaved = _swiftIbanController.text.isNotEmpty;

        // Tax
        _taxIdController.text = payout['taxId'] ?? '';
        _legalEntityController.text = payout['legalEntity'] ?? '';
        if (payout['taxFormType'] != null) _taxFormType = payout['taxFormType'];
        _taxSaved = _taxIdController.text.isNotEmpty;
      }
    } catch (_) {
      // Quiet fail if offline
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveCategory(String categoryKey, Map<String, dynamic> data, String successMsg) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      PipeFeedback.show(context, message: 'Please sign in to save banking details.', tone: PipeStatusTone.error);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'payoutSettings': {
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      if (mounted) {
        PipeFeedback.show(context, message: successMsg, tone: PipeStatusTone.success);
      }
    } catch (e) {
      if (mounted) {
        PipeFeedback.show(context, message: 'Could not save payout settings. Please try again.', tone: PipeStatusTone.error);
      }
    }
  }

  void _saveAch() async {
    if (_achFormKey.currentState?.validate() ?? false) {
      setState(() => _savingAch = true);
      await _saveCategory('ach', {
        'achBankName': _achBankNameController.text.trim(),
        'achHolder': _achHolderController.text.trim(),
        'achRouting': _achRoutingController.text.trim(),
        'achAccount': _achAccountController.text.trim(),
        'achType': _achAccountType,
      }, 'US & Canada Direct Deposit ACH updated!');
      setState(() {
        _savingAch = false;
        _achSaved = true;
      });
    }
  }

  void _saveGcc() async {
    if (_gccFormKey.currentState?.validate() ?? false) {
      setState(() => _savingGcc = true);
      await _saveCategory('gcc', {
        'gccBankName': _gccBankNameController.text.trim(),
        'gccHolder': _gccHolderController.text.trim(),
        'gccIban': _gccIbanController.text.trim(),
        'gccSwift': _gccSwiftController.text.trim(),
        'gccCurrency': _gccCurrency,
      }, 'Saudi & GCC IBAN Payout Vault updated!');
      setState(() {
        _savingGcc = false;
        _gccSaved = true;
      });
    }
  }

  void _saveSwift() async {
    if (_swiftFormKey.currentState?.validate() ?? false) {
      setState(() => _savingSwift = true);
      await _saveCategory('swift', {
        'swiftBankName': _swiftBankNameController.text.trim(),
        'swiftHolder': _swiftHolderController.text.trim(),
        'swiftCode': _swiftCodeController.text.trim(),
        'swiftIban': _swiftIbanController.text.trim(),
        'swiftCountry': _swiftCountryController.text.trim(),
      }, 'Global SWIFT International Wire updated!');
      setState(() {
        _savingSwift = false;
        _swiftSaved = true;
      });
    }
  }

  void _saveTax() async {
    if (_taxFormKey.currentState?.validate() ?? false) {
      setState(() => _savingTax = true);
      await _saveCategory('tax', {
        'taxId': _taxIdController.text.trim(),
        'legalEntity': _legalEntityController.text.trim(),
        'taxFormType': _taxFormType,
      }, 'Tax & 1099-K Compliance settings saved!');
      setState(() {
        _savingTax = false;
        _taxSaved = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banking & Merchant Payout Vault'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxConstraints.tightFor() != null
                                ? BoxShadow(
                                    color: Colors.black.withAlpha(40),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4))
                                : const BoxShadow(),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0878E8).withAlpha(40),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_outlined, color: Colors.white, size: 30),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Merchant Payout Vault & Escrow Setup',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Connect your company banking accounts and international payout methods. Escrow payouts post directly to your selected active account upon buyer inspection approval.',
                                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Card 1: Direct ACH & Wire (US & Canada)
                      _buildPayoutTile(
                        icon: Icons.account_balance,
                        iconColor: const Color(0xFF0878E8),
                        title: 'DIRECT ACH & WIRE (US & CANADA)',
                        subtitle: 'Direct deposit for US Dollars (USD) & Canadian Dollars (CAD)',
                        isConfigured: _achSaved,
                        child: Form(
                          key: _achFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _achHolderController,
                                decoration: const InputDecoration(
                                  labelText: 'Legal Account Holder / Entity Name',
                                  hintText: 'e.g. Apex Oilfield Supplies LLC',
                                  prefixIcon: Icon(Icons.business),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Enter account holder name' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _achBankNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Bank Name',
                                  hintText: 'e.g. JPMorgan Chase / Wells Fargo / RBC',
                                  prefixIcon: Icon(Icons.account_balance_outlined),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Enter bank name' : null,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _achRoutingController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Routing / ABA (9 Digits)',
                                        prefixIcon: Icon(Icons.numbers),
                                      ),
                                      validator: (val) => val == null || val.trim().length < 8 ? 'Invalid routing #' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _achAccountController,
                                      keyboardType: TextInputType.number,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Account Number',
                                        prefixIcon: Icon(Icons.lock_outline),
                                      ),
                                      validator: (val) => val == null || val.trim().length < 5 ? 'Invalid account #' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _achAccountType,
                                decoration: const InputDecoration(
                                  labelText: 'Account Category',
                                  prefixIcon: Icon(Icons.credit_card),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Business Checking', child: Text('Business Checking')),
                                  DropdownMenuItem(value: 'Checking', child: Text('Personal Checking')),
                                  DropdownMenuItem(value: 'Savings', child: Text('Savings Account')),
                                ],
                                onChanged: (val) => setState(() => _achAccountType = val ?? 'Business Checking'),
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _savingAch ? null : _saveAch,
                                  icon: const Icon(Icons.save),
                                  label: Text(_savingAch ? 'Saving…' : 'Save US/CA ACH Vault'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 2: Saudi Arabia & GCC IBAN Payout Vault
                      _buildPayoutTile(
                        icon: Icons.public,
                        iconColor: const Color(0xFF10B981),
                        title: 'SAUDI ARABIA & GCC IBAN PAYOUT VAULT',
                        subtitle: 'Direct payouts for Saudi Arabia (SAR), UAE (AED), Qatar, & Kuwait',
                        isConfigured: _gccSaved,
                        child: Form(
                          key: _gccFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: _gccCurrency,
                                decoration: const InputDecoration(
                                  labelText: 'Settlement Currency',
                                  prefixIcon: Icon(Icons.monetization_on_outlined),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'SAR (Saudi Riyal)', child: Text('SAR — Saudi Riyal (🇸🇦 Saudi Arabia)')),
                                  DropdownMenuItem(value: 'AED (UAE Dirham)', child: Text('AED — UAE Dirham (🇦🇪 United Arab Emirates)')),
                                  DropdownMenuItem(value: 'QAR (Qatari Riyal)', child: Text('QAR — Qatari Riyal (🇶🇦 Qatar)')),
                                  DropdownMenuItem(value: 'KWD (Kuwaiti Dinar)', child: Text('KWD — Kuwaiti Dinar (🇰🇼 Kuwait)')),
                                ],
                                onChanged: (val) => setState(() => _gccCurrency = val ?? 'SAR (Saudi Riyal)'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _gccHolderController,
                                decoration: const InputDecoration(
                                  labelText: 'Company Commercial Registration (CR) Holder Name',
                                  hintText: 'e.g. Al-Riyadh Petroleum Equipment Co.',
                                  prefixIcon: Icon(Icons.apartment),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Enter holder name' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _gccBankNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Bank Name in Middle East / GCC',
                                  hintText: 'e.g. Al Rajhi Bank / SNB / FAB',
                                  prefixIcon: Icon(Icons.account_balance),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Enter bank name' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _gccIbanController,
                                decoration: const InputDecoration(
                                  labelText: 'Full IBAN (24 Characters starting with SA/AE/QA)',
                                  hintText: 'SA0380000000608010167519',
                                  prefixIcon: Icon(Icons.numbers),
                                ),
                                validator: (val) => val == null || val.trim().length < 15 ? 'Enter valid IBAN' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _gccSwiftController,
                                decoration: const InputDecoration(
                                  labelText: 'SWIFT / BIC Code',
                                  hintText: 'e.g. RJHISE22',
                                  prefixIcon: Icon(Icons.code),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _savingGcc ? null : _saveGcc,
                                  icon: const Icon(Icons.save),
                                  label: Text(_savingGcc ? 'Saving…' : 'Save GCC IBAN Vault'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 3: International SWIFT / Global Wire
                      _buildPayoutTile(
                        icon: Icons.language,
                        iconColor: const Color(0xFF8B5CF6),
                        title: 'GLOBAL SWIFT WIRE (EUROPE, ASIA & LATAM)',
                        subtitle: 'Direct international wire transfers for Europe (EUR), UK (GBP), China (CNY), & Brazil (BRL)',
                        isConfigured: _swiftSaved,
                        child: Form(
                          key: _swiftFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _swiftCountryController,
                                decoration: const InputDecoration(
                                  labelText: 'Bank Country',
                                  hintText: 'e.g. United Kingdom / Germany / China / Australia',
                                  prefixIcon: Icon(Icons.flag_outlined),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Enter bank country' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _swiftHolderController,
                                decoration: const InputDecoration(
                                  labelText: 'Beneficiary Entity Name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Enter beneficiary name' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _swiftBankNameController,
                                decoration: const InputDecoration(
                                  labelText: 'International Bank Name',
                                  hintText: 'e.g. Deutsche Bank / HSBC / Industrial & Commercial Bank of China',
                                  prefixIcon: Icon(Icons.account_balance),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Enter bank name' : null,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _swiftCodeController,
                                      decoration: const InputDecoration(
                                        labelText: 'SWIFT / BIC Code (8-11 Chars)',
                                        prefixIcon: Icon(Icons.code),
                                      ),
                                      validator: (val) => val == null || val.trim().length < 8 ? 'Invalid SWIFT' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _swiftIbanController,
                                      decoration: const InputDecoration(
                                        labelText: 'IBAN / Account Number',
                                        prefixIcon: Icon(Icons.numbers),
                                      ),
                                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter IBAN/Account' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _savingSwift ? null : _saveSwift,
                                  icon: const Icon(Icons.save),
                                  label: Text(_savingSwift ? 'Saving…' : 'Save SWIFT Wire Vault'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 4: Tax & 1099-K Compliance
                      _buildPayoutTile(
                        icon: Icons.badge_outlined,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'TAX IDENTIFICATION & 1099-K COMPLIANCE',
                        subtitle: 'IRS 1099-K tax reporting & commercial VAT compliance',
                        isConfigured: _taxSaved,
                        child: Form(
                          key: _taxFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: _taxFormType,
                                decoration: const InputDecoration(
                                  labelText: 'Tax Classification',
                                  prefixIcon: Icon(Icons.assignment_outlined),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'W-9 (US Person / Entity)', child: Text('W-9 — US Person or Business (EIN/SSN)')),
                                  DropdownMenuItem(value: 'W-8BEN-E (Foreign Entity)', child: Text('W-8BEN-E — Foreign Commercial Company')),
                                  DropdownMenuItem(value: 'VAT / Tax Exempt', child: Text('International Commercial VAT / Exempt Entity')),
                                ],
                                onChanged: (val) => setState(() => _taxFormType = val ?? 'W-9 (US Person / Entity)'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _legalEntityController,
                                decoration: const InputDecoration(
                                  labelText: 'Legal Taxpayer Entity Name',
                                  prefixIcon: Icon(Icons.business),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Enter legal entity name' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _taxIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Federal EIN / Tax ID / SSN',
                                  hintText: 'XX-XXXXXXX',
                                  prefixIcon: Icon(Icons.shield_outlined),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Enter Tax ID / EIN' : null,
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _savingTax ? null : _saveTax,
                                  icon: const Icon(Icons.save),
                                  label: Text(_savingTax ? 'Saving…' : 'Save Tax Compliance Info'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPayoutTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isConfigured,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isConfigured ? iconColor.withAlpha(100) : Colors.grey.shade300),
      ),
      child: ExpansionTile(
        initiallyExpanded: isConfigured,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isConfigured ? Colors.green.shade100 : Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isConfigured ? Icons.check_circle : Icons.error_outline,
                    size: 12,
                    color: isConfigured ? Colors.green.shade800 : Colors.amber.shade900,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isConfigured ? 'ACTIVE' : 'NOT SET',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isConfigured ? Colors.green.shade800 : Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [child],
      ),
    );
  }
}
