import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin threshold panel uses server callables and warning bands', () {
    final panel = File(
      'lib/marketplace/marketplace_canada_gst_hst_threshold_panel.dart',
    ).readAsStringSync();

    expect(panel, contains('getCanadaGstHstThresholdAssessment'));
    expect(panel, contains('setCanadaGstHstThresholdAssessment'));
    expect(panel, contains('worldwideAndAssociatedIncluded'));
    expect(panel, contains('75%+ USED'));
    expect(panel, contains('90%+ USED'));
    expect(panel, contains('EXCEEDED'));
    expect(panel, contains('worldwide taxable supplies before expenses'));
    expect(panel, isNot(contains("package:cloud_firestore/cloud_firestore.dart")));
    expect(panel, isNot(contains('.collection(')));
  });

  test('threshold assessment callables are exported and MFA-admin guarded', () {
    final bootstrap =
        File('firebase/functions/bootstrap.js').readAsStringSync();
    final commands = File(
      'firebase/functions/canada_small_supplier_threshold_commands.js',
    ).readAsStringSync();

    expect(bootstrap, contains('getCanadaGstHstThresholdAssessment'));
    expect(bootstrap, contains('setCanadaGstHstThresholdAssessment'));
    expect(commands, contains('requireAdministrator(request)'));
    expect(commands, contains('tax_threshold_assessment_audit'));
    expect(commands, contains('worldwide taxable supplies and associated businesses'));
  });

  test('settlement admin page includes the threshold monitor even when queue is empty', () {
    final page = File(
      'lib/marketplace/marketplace_external_settlement_admin_page.dart',
    ).readAsStringSync();

    expect(page, contains('MarketplaceCanadaGstHstThresholdPanel'));
    expect(page, contains('External settlement queue is empty'));
  });
}
