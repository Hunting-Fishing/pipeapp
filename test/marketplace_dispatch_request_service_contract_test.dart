import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Request Service uses service-first review-before-submit workflow', () {
    final wizard = source(
      'lib/marketplace/marketplace_dispatch_request_service_page.dart',
    );
    expect(wizard, contains('MarketplaceDispatchMultiServiceSelector'));
    expect(wizard, contains('DispatchRequestFlow.reviewIssues'));
    expect(wizard, contains("title: const Text('Review request')"));
    expect(wizard, contains("label: const Text('Submit request')"));
    expect(wizard, contains('DispatchRequestPath.freightRoute'));
    expect(wizard, contains("'Work-site location'"));
    expect(wizard, contains("'Delivery location'"));
  });

  test('request photos reuse the existing locked image picker', () {
    final wizard = source(
      'lib/marketplace/marketplace_dispatch_request_service_page.dart',
    );
    final pubspec = source('pubspec.yaml');
    expect(wizard, contains("package:image_picker/image_picker.dart"));
    expect(wizard, contains('ImagePicker().pickMultiImage'));
    expect(wizard, contains('_maximumAttachments = 5'));
    expect(wizard, contains('_maximumAttachmentBytes = 15 * 1024 * 1024'));
    expect(wizard, contains('provider file access is not opened broadly'));
    expect(wizard, isNot(contains('file_picker')));
    expect(pubspec, isNot(contains('file_picker:')));
  });

  test('request repository uses the protected existing Dispatch command chain', () {
    final repository = source(
      'lib/marketplace/marketplace_dispatch_request_repository.dart',
    );
    expect(repository, contains("'authorizeDispatchRequestUpload'"));
    expect(repository, contains("'confirmMarketplaceUpload'"));
    expect(repository, contains("'createDispatchJob'"));
    expect(repository, contains("'requestId': jobId"));
    expect(repository, contains("'jobId': jobId"));
    expect(repository, contains("'serviceCodes': serviceCodes"));
    expect(repository, contains("'contactPreference': contactPreference"));
  });

  test('shared Dispatch navigation cannot leave users on the legacy request form', () {
    final navigation = source(
      'lib/marketplace/marketplace_dispatch_navigation.dart',
    );
    expect(navigation, contains('MarketplaceDispatchRequestServicePage'));
    expect(navigation, contains('MarketplaceDispatchMyRequestsPage'));
    expect(navigation, contains('_scheduleLegacyRequestInterception'));
    expect(navigation, contains('widget.selected != DispatchSection.requestService'));
    expect(navigation, contains("label: const Text('My Requests')"));
  });

  test('My Requests exposes bounded edit history and dedicated cancellation', () {
    final requests = source(
      'lib/marketplace/marketplace_dispatch_my_requests_page.dart',
    );
    expect(requests, contains("data['requestPath'] == 'field_service'"));
    expect(requests, contains("label: const Text('Cancel request')"));
    expect(requests, contains('_repository.cancelJob'));
    expect(requests, contains('_repository.updateJob'));
    expect(requests, contains('.jobHistoryQuery(request.id)'));
    expect(requests, contains('Cancel and create a new request'));
  });

  test('field-service requests never advertise freight quote state in My Requests', () {
    final requests = source(
      'lib/marketplace/marketplace_dispatch_my_requests_page.dart',
    );
    expect(requests, contains("'Matching'"));
    expect(requests, contains("'Not opened yet'"));
    expect(requests, contains("'RECEIVED'"));
    expect(requests, contains('Directory → Get Quote'));
    expect(requests, contains('before provider matching is opened'));
  });

  test('client contact choices are backed by server verified-contact policy', () {
    final wizard = source(
      'lib/marketplace/marketplace_dispatch_request_service_page.dart',
    );
    final adapter = source(
      'firebase/functions/dispatch_request_input_adapter.js',
    );
    expect(wizard, contains('DispatchContactPreference.inApp'));
    expect(wizard, contains('DispatchContactPreference.phone'));
    expect(wizard, contains('DispatchContactPreference.email'));
    expect(adapter, contains('identity.phoneVerified !== true'));
    expect(adapter, contains('identity.emailVerified !== true'));
  });
}
