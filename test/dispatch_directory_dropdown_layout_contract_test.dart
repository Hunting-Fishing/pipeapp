import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory filter dropdowns are width-bounded for responsive layouts', () {
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
    final filterSection = source.substring(filterStart, companyStart);
    final compact = filterSection.replaceAll(RegExp(r'\s+'), ' ');

    for (final variableName in ['service', 'availability', 'businessType']) {
      expect(
        compact,
        contains(
          'final $variableName = DropdownButtonFormField<String>( isExpanded: true,',
        ),
      );
    }

    expect(
      RegExp(r'isExpanded:\s*true,').allMatches(filterSection).length,
      3,
    );
  });
}
