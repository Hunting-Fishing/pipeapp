import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory seed fixtures do not eagerly construct Firebase repository', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync();
    final compact = source.replaceAll(RegExp(r'\s+'), ' ');

    expect(
      compact,
      contains('MarketplaceDispatchDirectoryRepository? _repository;'),
    );
    expect(
      compact,
      contains('_repository = widget.repository;'),
    );
    expect(
      compact,
      isNot(
        contains(
          '_repository = widget.repository ?? MarketplaceDispatchDirectoryRepository();',
        ),
      ),
    );
    expect(
      compact,
      contains(
        'final repository = _repository ??= MarketplaceDispatchDirectoryRepository();',
      ),
    );
    expect(compact, contains('repository.loadPage('));
    expect(compact, isNot(contains('_repository.loadPage(')));

    final loadStart = compact.indexOf(
      'Future<DispatchDirectoryPageData> _load()',
    );
    expect(loadStart, greaterThanOrEqualTo(0));
    final loadSegment = compact.substring(loadStart);
    expect(
      loadSegment.indexOf('if (seed != null)'),
      lessThan(
        loadSegment.indexOf('MarketplaceDispatchDirectoryRepository()'),
      ),
    );
  });
}
