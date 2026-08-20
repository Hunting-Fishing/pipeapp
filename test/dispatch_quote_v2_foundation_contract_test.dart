import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Jobs and Dashboard share the Pipe Buyer quote form', () {
    final page = File(
      'lib/marketplace/marketplace_dispatch_page.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/marketplace/marketplace_dispatch_dashboard.dart',
    ).readAsStringSync();
    final form = File(
      'lib/marketplace/marketplace_dispatch_quote_form.dart',
    ).readAsStringSync();

    expect(page, contains("import 'marketplace_dispatch_quote_form.dart';"));
    expect(dashboard, contains("import 'marketplace_dispatch_quote_form.dart';"));
    expect(page, contains('MarketplaceDispatchQuoteForm.show('));
    expect(dashboard, contains('MarketplaceDispatchQuoteForm.show('));
    expect(page, isNot(contains("labelText: 'All-in transport price'")));
    expect(
      dashboard,
      isNot(contains('class _DispatchQuoteDialog extends StatefulWidget')),
      reason: 'The retired Dashboard quote editor must be removed after Quote V2 wiring.',
    );
    expect(
      dashboard,
      isNot(contains('class _QuoteSection extends StatelessWidget')),
      reason: 'Retired Quote V1-only helper widgets must not survive Quote V2 migration.',
    );
    expect(
      dashboard,
      isNot(contains('class _DispatchUnitRequirementDraft')),
      reason: 'Unreferenced local migration artifacts must not survive exact-candidate promotion.',
    );
    expect(
      dashboard,
      isNot(contains('quote_v2_preflight')),
      reason: 'Preflight-only imports must never leak into production Dashboard source.',
    );
    expect(
      page,
      isNot(contains('quote_v2_preflight')),
      reason: 'Preflight-only imports must never leak into production Jobs source.',
    );

    for (final marker in [
      "'distanceKm'",
      "'deadheadKm'",
      "'mileageRate'",
      "'deadheadRate'",
      "'weightKg'",
      "'weightRate'",
      "'hourlyRate'",
      "'pilotCount'",
      "'pilotKmRate'",
      "'permitFee'",
      "'surchargePercent'",
      "'taxPercent'",
      "'manualTotal'",
      "'formulaVersion': 2",
      "ButtonSegment(value: 'CAD'",
      "ButtonSegment(value: 'USD'",
    ]) {
      expect(form, contains(marker), reason: 'Missing quote-form marker: $marker');
    }
  });

  test('carrier quote command sends full versionable breakdown', () {
    final repository = File(
      'lib/marketplace/marketplace_dispatch_repository.dart',
    ).readAsStringSync();
    final page = File(
      'lib/marketplace/marketplace_dispatch_page.dart',
    ).readAsStringSync();
    final policy = File(
      'firebase/functions/dispatch_command_policy.js',
    ).readAsStringSync();
    final commands = File(
      'firebase/functions/dispatch_commands.js',
    ).readAsStringSync();

    expect(repository, contains('required Map<String, dynamic> quoteBreakdown'));
    expect(repository, contains("'quoteBreakdown': quoteBreakdown"));
    expect(repository, contains("'currency': currency"));
    expect(page, contains('quoteBreakdown: draft.breakdown'));
    expect(page, contains('currency: draft.currency'));

    expect(policy, contains('function validateDispatchQuoteBreakdown('));
    expect(
      policy,
      contains('Carrier quote total does not match the server-calculated quote form.'),
    );
    expect(commands, contains('quoteBreakdown: quote.quoteBreakdown'));
    expect(commands, contains('quoteReference:'));
    expect(commands, contains('quoteVersion: revision'));
    expect(commands, contains('validityStatus: "active"'));
    expect(commands, contains('bidRef.collection("revisions").doc(String(revision))'));
  });
}
