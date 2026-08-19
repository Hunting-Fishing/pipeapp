import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory repository is non-null and initialized before load use', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync();
    final compact = source.replaceAll(RegExp(r'\s+'), ' ');

    expect(
      compact,
      contains(
        'late final MarketplaceDispatchDirectoryRepository _repository;',
      ),
    );
    expect(
      compact,
      isNot(
        contains('MarketplaceDispatchDirectoryRepository? _repository;'),
      ),
    );
    expect(
      compact,
      contains(
        '_repository = widget.repository ?? MarketplaceDispatchDirectoryRepository();',
      ),
    );
    expect(compact, contains('_repository.loadPage('));
  });
}
