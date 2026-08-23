import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_credentials.dart';

void main() {
  test('insurance coverage limits round-trip only through private credential data', () {
    final record = DispatchCredentialRecord(
      type: DispatchCredentialType.generalLiabilityInsurance,
      state: DispatchCredentialSelfReportedState.current,
      issuer: 'Example Insurer',
      referenceNumber: 'POL-500',
      expiryDate: DateTime(2027, 8, 18),
      notes: 'Private note',
      documentStoragePath: '',
      coverageLimit: 5000000,
      aggregateLimit: 10000000,
      coverageCurrency: 'CAD',
    );

    final encoded = record.toPrivateMap();
    final decoded = DispatchCredentialRecord.fromPrivateMap(
      DispatchCredentialType.generalLiabilityInsurance,
      encoded,
    );

    expect(encoded['coverageLimit'], 5000000);
    expect(encoded['aggregateLimit'], 10000000);
    expect(encoded['coverageCurrency'], 'CAD');
    expect(decoded.coverageLimit, 5000000);
    expect(decoded.aggregateLimit, 10000000);
    expect(decoded.coverageCurrency, 'CAD');
    expect(encoded, isNot(contains('verified')));
    expect(encoded, isNot(contains('public')));
  });

  test('minimum insurance requirement is deterministic and does not perform hidden FX conversion', () {
    final record = DispatchCredentialRecord(
      type: DispatchCredentialType.cargoInsurance,
      state: DispatchCredentialSelfReportedState.current,
      issuer: '',
      referenceNumber: '',
      expiryDate: DateTime(2027, 8, 18),
      notes: '',
      documentStoragePath: '',
      coverageLimit: 2000000,
      coverageCurrency: 'CAD',
    );

    expect(record.meetsMinimumCoverage(1500000, 'CAD'), isTrue);
    expect(record.meetsMinimumCoverage(2500000, 'CAD'), isFalse);
    expect(record.meetsMinimumCoverage(1000000, 'USD'), isFalse);
  });

  test('non-insurance credential never qualifies for an insurance limit', () {
    final record = DispatchCredentialRecord(
      type: DispatchCredentialType.operatingAuthority,
      state: DispatchCredentialSelfReportedState.current,
      issuer: '',
      referenceNumber: '',
      expiryDate: DateTime(2027, 8, 18),
      notes: '',
      documentStoragePath: '',
      coverageLimit: 5000000,
      coverageCurrency: 'CAD',
    );

    expect(record.type.isInsurance, isFalse);
    expect(record.meetsMinimumCoverage(1, 'CAD'), isFalse);
  });

  test('credential reminder settings stay bounded and private', () {
    final settings = DispatchCredentialReminderSettings.fromPrivateMap(const {
      'enabled': true,
      'reminderDays': [90, 30, 14, 7, 7, -5, 999],
    });

    expect(settings.enabled, isTrue);
    expect(settings.reminderDays, [90, 30, 14, 7]);
    expect(settings.toPrivateMap(), {
      'enabled': true,
      'reminderDays': [90, 30, 14, 7],
    });
  });
}
