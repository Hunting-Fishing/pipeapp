import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Request Service restores the taxonomy menu without removing trucking', () {
    final page = File(
      'lib/marketplace/marketplace_dispatch_page.dart',
    ).readAsStringSync();
    final selector = File(
      'lib/marketplace/marketplace_dispatch_multi_service_selector.dart',
    ).readAsStringSync();
    final taxonomy = File(
      'lib/marketplace/marketplace_dispatch_service_taxonomy.dart',
    ).readAsStringSync();

    for (final marker in [
      'MarketplaceDispatchMultiServiceSelector(',
      "label: 'Choose service(s)'",
      'List<String> requestedServiceCodes',
      r'Services requested: $services',
      "'Select a listing for quote'",
      'MarketplaceFreightQuote.show(',
      "'Post a trucking job'",
    ]) {
      expect(page, contains(marker), reason: 'Request Service missing $marker');
    }

    for (final marker in [
      "label: const Text('+ Add Service')",
      'allowedServiceCodes',
      'initialServiceCodes',
      'dispatchServiceCategoryLabel',
      'dispatchServiceLabelForCode',
    ]) {
      expect(selector, contains(marker), reason: 'Selector missing $marker');
    }

    for (final service in [
      "label: 'Hotshot'",
      "label: 'Mobile Crane'",
      "label: 'Road Maintenance'",
      "label: 'Grading'",
      "label: 'Pilot / Escort Vehicle'",
    ]) {
      expect(taxonomy, contains(service), reason: 'Taxonomy missing $service');
    }
  });

  test('Directory Get Quote uses only the providers service menu and multi-items', () {
    final directory = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/marketplace/marketplace_dispatch_directory_actions.dart',
    ).readAsStringSync();

    expect(directory, contains('serviceCodes: entry.serviceCodes,'));
    expect(actions, contains('required this.serviceCodes'));
    expect(actions, contains('allowedServiceCodes: widget.serviceCodes'));
    expect(actions, contains('MarketplaceDispatchMultiServiceSelector('));
    expect(actions, contains("label: 'Services from this company'"));
    expect(actions, contains('Services requested:'));
    expect(actions, contains('Requested date:'));
    expect(actions, contains('Priority:'));
    expect(actions, contains("label: const Text('Send Quote Request')"));
  });

  test('service restoration does not invent a second server request model', () {
    final repository = File(
      'lib/marketplace/marketplace_dispatch_repository.dart',
    ).readAsStringSync();
    final page = File(
      'lib/marketplace/marketplace_dispatch_page.dart',
    ).readAsStringSync();

    expect(repository, contains("_commands.execute('createDispatchJob'"));
    expect(page, contains('widget.repo.createJob('));
    expect(
      page,
      contains('loadDetails: _requestDetailsWithServices(details.text.trim())'),
    );
  });
}
