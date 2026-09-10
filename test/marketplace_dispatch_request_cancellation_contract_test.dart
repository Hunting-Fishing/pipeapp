import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dispatch repository uses dedicated pre-award cancellation callable', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_repository.dart',
    ).readAsStringSync();

    expect(source, contains("Future<void> cancelJob({"));
    expect(source, contains("_commands.execute('cancelDispatchJob'"));

    final cancelStart = source.indexOf('Future<void> cancelJob({');
    final bidStart = source.indexOf('Future<void> bid({', cancelStart);
    final cancelBlock = source.substring(cancelStart, bidStart);
    expect(cancelBlock, isNot(contains("_commands.execute('updateDispatchJob'")));
    expect(cancelBlock, isNot(contains("'action': 'cancel_request'")));
  });
}
