import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory filter selection is same-tree and avoids overlay dropdown churn', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync();
    final filterStart = source.indexOf(
      'class _DirectoryFilterCard extends StatelessWidget',
    );
    final companyStart = source.indexOf(
      'class _DirectoryCompanyCard extends StatelessWidget',
    );

    expect(filterStart, greaterThanOrEqualTo(0));
    expect(companyStart, greaterThan(filterStart));
    final section = source.substring(filterStart, companyStart);

    expect(section, contains('class _DirectoryInlineSelect extends StatefulWidget'));
    expect(section, contains("id: 'directory-service-filter'"));
    expect(section, contains("id: 'directory-availability-filter'"));
    expect(section, contains("id: 'directory-business-type-filter'"));
    expect(section, contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(section, contains('GestureDetector('));
    expect(section, contains('ListView.separated('));

    for (final forbidden in [
      'DropdownButtonFormField<',
      'DropdownMenu<',
      'PopupMenuButton<',
      'showMenu(',
      'OverlayEntry(',
    ]) {
      expect(section, isNot(contains(forbidden)));
    }
  });
}
