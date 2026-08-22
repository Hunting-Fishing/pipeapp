import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy Dashboard quote planner stays superseded by shared Quote V2',
      () {
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
    expect(
      dashboard,
      contains("import 'marketplace_dispatch_quote_form.dart';"),
    );
    expect(page, contains('MarketplaceDispatchQuoteForm.show('));
    expect(dashboard, contains('MarketplaceDispatchQuoteForm.show('));

    expect(
      dashboard,
      isNot(contains('class _DispatchQuoteDialog extends StatefulWidget')),
    );
    expect(
      dashboard,
      isNot(contains('class _DispatchUnitRequirementDraft')),
    );
    expect(dashboard, isNot(contains('_dispatchQuoteUnitTypes')));

    for (final marker in [
      "'distanceKm'",
      "'deadheadKm'",
      "'mileageRate'",
      "'deadheadRate'",
      "'weightKg'",
      "'weightRate'",
      "'hourlyRate'",
      "'pilotCount'",
      "'permitFee'",
      "'surchargePercent'",
      "'taxPercent'",
      "'manualTotal'",
      "'formulaVersion': 2",
      "ButtonSegment(value: 'CAD'",
      "ButtonSegment(value: 'USD'",
    ]) {
      expect(form, contains(marker),
          reason: 'Missing Quote V2 marker: $marker');
    }
  });

  test('Quote V2 sends a complete versionable server-validated breakdown', () {
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

    expect(
      repository,
      contains('required Map<String, dynamic> quoteBreakdown'),
    );
    expect(repository, contains("'quoteBreakdown': quoteBreakdown"));
    expect(repository, contains("'currency': currency"));
    expect(page, contains('quoteBreakdown: draft.breakdown'));
    expect(page, contains('currency: draft.currency'));

    expect(policy, contains('function validateDispatchQuoteBreakdown('));
    expect(
      policy,
      contains(
        'Carrier quote total does not match the server-calculated quote form.',
      ),
    );
    expect(commands, contains('quoteBreakdown: quote.quoteBreakdown'));
    expect(commands, contains('quoteReference:'));
    expect(commands, contains('quoteVersion: revision'));
    expect(commands, contains('validityStatus: "active"'));
  });

  test(
      'Dispatch build plan is not coupled to retired Dashboard editor internals',
      () {
    final plan =
        File('docs/DISPATCH_NETWORK_MASTER_PLAN.md').readAsStringSync();
    final handoff =
        File('docs/PIPEBUYER_ACTIVE_BUILD_HANDOFF.md').readAsStringSync();

    expect(plan, contains('PHASE 5'));
    expect(plan, contains('Request Service'));
    expect(handoff, contains('Phase 3'));
    expect(handoff, contains('Phase 4'));

    // The active architecture is the shared Quote V2 form. A plan document
    // must not force dead private Dashboard classes back into production.
    final dashboard = File(
      'lib/marketplace/marketplace_dispatch_dashboard.dart',
    ).readAsStringSync();
    expect(dashboard, isNot(contains('class _DispatchUnitRequirementDraft')));
  });
}
