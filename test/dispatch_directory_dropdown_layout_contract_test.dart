import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory filter controls remain responsive without overlay dropdowns', () {
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

    expect(filterSection, contains('class _DirectoryInlineSelect extends StatefulWidget'));
    expect(filterSection, contains("id: 'directory-service-filter'"));
    expect(filterSection, contains("id: 'directory-availability-filter'"));
    expect(filterSection, contains("id: 'directory-business-type-filter'"));
    expect(filterSection, contains('Expanded(child: service)'));
    expect(filterSection, contains('Expanded(child: availability)'));
    expect(filterSection, contains('Expanded(child: businessType)'));

    expect(filterSection, isNot(contains('DropdownButtonFormField<')));
    expect(filterSection, isNot(contains('DropdownMenu<')));
    expect(filterSection, isNot(contains('PopupMenuButton<')));
  });
}
