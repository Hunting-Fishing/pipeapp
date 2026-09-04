import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory direct quote stays on private business conversation path', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory_actions.dart',
    ).readAsStringSync();

    final requestStart = source.indexOf('Future<void> _requestQuote() async');
    final reportStart = source.indexOf('Future<void> _reportBusiness()', requestStart);
    expect(requestStart, greaterThanOrEqualTo(0));
    expect(reportStart, greaterThan(requestStart));

    final requestBlock = source.substring(requestStart, reportStart);
    expect(requestBlock, contains('openBusinessConversation('));
    expect(requestBlock, contains('sendChatMessage('));
    expect(requestBlock, isNot(contains('createJob(')));
    expect(requestBlock, isNot(contains("collection('dispatch_jobs')")));
  });

  test('direct quote copy explicitly communicates private provider scope', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory_actions.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('The request stays private between you and the provider.'),
    );
  });
}
