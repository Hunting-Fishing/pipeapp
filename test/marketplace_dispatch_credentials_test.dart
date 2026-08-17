import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_credentials.dart';

void main() {
  test('Dispatch credential type codes are stable and unique', () {
    final codes = DispatchCredentialType.values.map((value) => value.code).toList();

    expect(codes.toSet().length, codes.length);
    expect(codes, contains('general_liability_insurance'));
    expect(codes, contains('cargo_insurance'));
    expect(codes, contains('commercial_auto_insurance'));
    expect(codes, contains('workers_compensation'));
    expect(codes, contains('operating_authority'));
    expect(codes, contains('safety_certificate'));
    expect(codes, contains('pilot_escort_certification'));
    expect(codes, contains('crane_rigging_qualification'));
  });

  test('credential metadata round-trips as private self-reported data', () {
    final original = DispatchCredentialRecord(
      type: DispatchCredentialType.generalLiabilityInsurance,
      state: DispatchCredentialSelfReportedState.current,
      issuer: 'Example Insurer',
      referenceNumber: 'POL-1234',
      expiryDate: DateTime(2027, 5, 31),
      notes: 'Private account note',
      documentStoragePath:
          'business_documents/user-1/dispatch_credential_general_liability_insurance_evidence',
    );

    final encoded = original.toPrivateMap();
    final decoded = DispatchCredentialRecord.fromPrivateMap(
      DispatchCredentialType.generalLiabilityInsurance,
      encoded,
    );

    expect(encoded['state'], 'self_reported_current');
    expect(encoded['expiryDate'], '2027-05-31');
    expect(encoded, isNot(contains('verified')));
    expect(encoded, isNot(contains('public')));
    expect(decoded.issuer, original.issuer);
    expect(decoded.referenceNumber, original.referenceNumber);
    expect(decoded.expiryLabel, '2027-05-31');
    expect(decoded.hasPrivateEvidence, isTrue);
  });

  test('unknown credential state never becomes verified or current', () {
    final decoded = DispatchCredentialRecord.fromPrivateMap(
      DispatchCredentialType.operatingAuthority,
      const {
        'state': 'verified',
        'issuer': 'Unknown authority',
      },
    );

    expect(decoded.state, DispatchCredentialSelfReportedState.notProvided);
  });
}
