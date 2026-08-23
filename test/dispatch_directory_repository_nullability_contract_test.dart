import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory repository stays lazy so seed fixtures remain Firebase-free',
      () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final compact = source.replaceAll(RegExp(r'\s+'), ' ');

    expect(
      compact,
      contains('MarketplaceDispatchDirectoryRepository? _repository;'),
    );
    expect(compact, contains('_repository = widget.repository;'));
    expect(compact, contains('final seed = widget.seedEntries;'));
    expect(
      compact,
      contains(
        'final repository = _repository ??= MarketplaceDispatchDirectoryRepository();',
      ),
    );
    expect(
        compact, contains('request = repository.loadPage(filters: _filters);'));

    final seedIndex = compact.indexOf('final seed = widget.seedEntries;');
    final remoteIndex = compact.indexOf(
      'final repository = _repository ??= MarketplaceDispatchDirectoryRepository();',
    );
    expect(seedIndex, greaterThanOrEqualTo(0));
    expect(remoteIndex, greaterThan(seedIndex));

    expect(
      compact,
      isNot(
        contains(
          'late final MarketplaceDispatchDirectoryRepository _repository;',
        ),
      ),
    );
    expect(
      compact,
      isNot(
        contains(
          '_repository = widget.repository ?? MarketplaceDispatchDirectoryRepository();',
        ),
      ),
    );
  });
}
