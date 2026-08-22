import 'package:flutter/material.dart';

import 'marketplace_command_client.dart';

class MarketplaceCanadaGstHstThresholdPanel extends StatefulWidget {
  const MarketplaceCanadaGstHstThresholdPanel({super.key});

  @override
  State<MarketplaceCanadaGstHstThresholdPanel> createState() =>
      _MarketplaceCanadaGstHstThresholdPanelState();
}

class _MarketplaceCanadaGstHstThresholdPanelState
    extends State<MarketplaceCanadaGstHstThresholdPanel> {
  final MarketplaceCommandClient _commands = MarketplaceCommandClient();
  late Future<Map<String, dynamic>> _assessment;

  @override
  void initState() {
    super.initState();
    _assessment = _load();
  }

  Future<Map<String, dynamic>> _load() =>
      _commands.execute('getCanadaGstHstThresholdAssessment', const {});

  void _refresh() => setState(() {
        _assessment = _load();
      });

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _assessment,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Expanded(child: Text('Loading Canadian GST/HST threshold…')),
                  ],
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GST/HST threshold monitor unavailable',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      marketplaceCommandErrorMessage(
                        snapshot.error!,
                        fallback:
                            'The threshold assessment could not be loaded.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final response = snapshot.data ?? const <String, dynamic>{};
          final raw = response['assessment'];
          final assessment = raw is Map
              ? Map<String, dynamic>.from(raw)
              : const <String, dynamic>{};
          final smallSupplier = response['canadaGstHstSmallSupplier'] == true;
          final taxReady = response['stripeTaxReady'] == true;
          final registrationPending =
              response['stripeTaxRegistrationPending'] == true;
          final feeBilling = response['stripeFeeBillingEnabled'] == true;
          final subscriptions = response['stripeSubscriptionsEnabled'] == true;
          final boundRevision =
              (response['canadaGstHstSmallSupplierAssessmentRevision'] as num?)
                  ?.toInt();
          return _card(
            context,
            assessment: assessment,
            smallSupplier: smallSupplier,
            taxReady: taxReady,
            registrationPending: registrationPending,
            feeBilling: feeBilling,
            subscriptions: subscriptions,
            boundRevision: boundRevision,
          );
        },
      );

  Widget _card(
    BuildContext context, {
    required Map<String, dynamic> assessment,
    required bool smallSupplier,
    required bool taxReady,
    required bool registrationPending,
    required bool feeBilling,
    required bool subscriptions,
    required int? boundRevision,
  }) {
    final hasAssessment = assessment.isNotEmpty;
    final thresholdMinor =
        (assessment['thresholdCadMinor'] as num?)?.toInt() ?? 3000000;
    final governingMinor =
        (assessment['governingAmountCadMinor'] as num?)?.toInt() ?? 0;
    final remainingMinor =
        (assessment['remainingCadMinor'] as num?)?.toInt() ?? thresholdMinor;
    final level = '${assessment['level'] ?? 'not_assessed'}';
    final safetyAction = '${assessment['billingSafetyAction'] ?? 'none'}';
    final assessmentRevision = (assessment['revision'] as num?)?.toInt();
    final progress = thresholdMinor <= 0
        ? 0.0
        : (governingMinor / thresholdMinor).clamp(0.0, 1.0).toDouble();
    final state = _visualState(level, hasAssessment);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(state.icon, color: state.color),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Canadian GST/HST small-supplier monitor',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                Chip(label: Text(state.label)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              taxReady
                  ? 'GST/HST registration is marked tax-ready.'
                  : registrationPending
                      ? 'GST/HST registration is marked pending.'
                      : smallSupplier
                          ? 'Billing readiness is using the Canadian small-supplier state.'
                          : 'Small-supplier billing is not currently enabled.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (smallSupplier && assessmentRevision != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  boundRevision == assessmentRevision
                      ? 'Readiness is bound to audited assessment revision $assessmentRevision.'
                      : 'Readiness/assessment revision mismatch — review before billing.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: boundRevision == assessmentRevision
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 6),
            Text(
              hasAssessment
                  ? '${_money(governingMinor)} governing taxable supplies • ${_money(remainingMinor)} remaining to CAD 30,000'
                  : 'No audited threshold assessment has been recorded yet.',
              style: const TextStyle(fontSize: 12),
            ),
            if (hasAssessment) ...[
              const SizedBox(height: 6),
              Text(
                'Single quarter: ${_money((assessment['singleQuarterCadMinor'] as num?)?.toInt() ?? 0)} • '
                'Rolling four quarters: ${_money((assessment['rollingFourQuarterCadMinor'] as num?)?.toInt() ?? 0)}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Period: ${assessment['periodLabel'] ?? '—'} • Revision ${assessment['revision'] ?? '—'}',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              if (assessment['requiresRegistrationReview'] == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Threshold exceeded: GST/HST registration/effective-date review is required before relying on small-supplier billing.',
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              if (safetyAction == 'small_supplier_billing_disabled')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Safety shutdown applied: Marketplace-fee billing ${feeBilling ? 'still enabled — REVIEW' : 'disabled'} • Dispatch subscriptions ${subscriptions ? 'still enabled — REVIEW' : 'disabled'}.',
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 10),
            const Text(
              'The assessment must include worldwide taxable supplies before expenses and associated businesses. Stripe receipts alone are not sufficient evidence.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _showAssessmentDialog(context, assessment),
                  icon: const Icon(Icons.edit_note_outlined),
                  label: Text(hasAssessment
                      ? 'Update threshold assessment'
                      : 'Record threshold assessment'),
                ),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssessmentDialog(
    BuildContext context,
    Map<String, dynamic> current,
  ) async {
    final period = TextEditingController(
      text: '${current['periodLabel'] ?? ''}',
    );
    final quarter = TextEditingController(
      text: current.isEmpty
          ? ''
          : _dollars((current['singleQuarterCadMinor'] as num?)?.toInt() ?? 0),
    );
    final rolling = TextEditingController(
      text: current.isEmpty
          ? ''
          : _dollars((current['rollingFourQuarterCadMinor'] as num?)?.toInt() ?? 0),
    );
    final source = TextEditingController(
      text: '${current['sourceNote'] ?? ''}',
    );
    var attested = current['worldwideAndAssociatedIncluded'] == true;
    var saving = false;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('GST/HST threshold assessment'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: period,
                    decoration: const InputDecoration(
                      labelText: 'Period label',
                      hintText: '2026 Q3',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: quarter,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Single calendar quarter taxable supplies (CAD)',
                      prefixText: r'$ ',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: rolling,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Previous four consecutive quarters (CAD)',
                      prefixText: r'$ ',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: source,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Bookkeeping / evidence note',
                      hintText:
                          'Describe the books, statements, and external totals reviewed.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: attested,
                    contentPadding: EdgeInsets.zero,
                    onChanged: saving
                        ? null
                        : (value) => setDialogState(() {
                              attested = value == true;
                            }),
                    title: const Text(
                      'I confirm these figures include worldwide taxable supplies before expenses and associated businesses.',
                      style: TextStyle(fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final quarterMinor = _parseCadMinor(quarter.text);
                      final rollingMinor = _parseCadMinor(rolling.text);
                      if (quarterMinor == null || rollingMinor == null) {
                        setDialogState(() {
                          error = 'Enter valid CAD amounts with no more than two decimals.';
                        });
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await _commands.execute(
                          'setCanadaGstHstThresholdAssessment',
                          {
                            'periodLabel': period.text.trim(),
                            'singleQuarterCadMinor': quarterMinor,
                            'rollingFourQuarterCadMinor': rollingMinor,
                            'sourceNote': source.text.trim(),
                            'worldwideAndAssociatedIncluded': attested,
                          },
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (caught) {
                        setDialogState(() {
                          saving = false;
                          error = marketplaceCommandErrorMessage(
                            caught,
                            fallback:
                                'The threshold assessment could not be saved.',
                          );
                        });
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save audited assessment'),
            ),
          ],
        ),
      ),
    );

    period.dispose();
    quarter.dispose();
    rolling.dispose();
    source.dispose();
    if (saved == true && mounted) _refresh();
  }

  int? _parseCadMinor(String input) {
    final normalized = input.trim().replaceAll(',', '');
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
    if (match == null) return null;
    final dollars = int.tryParse(match.group(1)!);
    if (dollars == null) return null;
    final centsText = (match.group(2) ?? '').padRight(2, '0');
    final cents = centsText.isEmpty ? 0 : int.tryParse(centsText);
    if (cents == null) return null;
    final total = dollars * 100 + cents;
    return total <= 9007199254740991 ? total : null;
  }

  String _money(int minor) => 'CAD \$${(minor / 100).toStringAsFixed(2)}';
  String _dollars(int minor) => (minor / 100).toStringAsFixed(2);

  _ThresholdVisualState _visualState(String level, bool hasAssessment) {
    if (!hasAssessment) {
      return const _ThresholdVisualState(
        'NOT ASSESSED',
        Icons.help_outline,
        Colors.blueGrey,
      );
    }
    return switch (level) {
      'exceeded' => const _ThresholdVisualState(
          'EXCEEDED', Icons.error_outline, Colors.red),
      'high_warning' => const _ThresholdVisualState(
          '90%+ USED', Icons.warning_amber_outlined, Colors.deepOrange),
      'warning' => const _ThresholdVisualState(
          '75%+ USED', Icons.warning_outlined, Colors.orange),
      _ => const _ThresholdVisualState(
          'WITHIN THRESHOLD', Icons.check_circle_outline, Colors.green),
    };
  }
}

class _ThresholdVisualState {
  const _ThresholdVisualState(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}
