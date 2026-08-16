import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_spec_assist.dart';

void main() {
  test('extracts an explicit equipment year from free-form details', () {
    expect(
      dispatchSpecAssistYearFromText('CAT D6 LGP, 2021 model, cab and ripper'),
      2021,
    );
    expect(dispatchSpecAssistYearFromText('CAT D6, year unknown'), isNull);
  });

  test('listing snapshot converts imperial transport dimensions to metres', () {
    final snapshot = dispatchSpecAssistSnapshotFromListing({
      'brand': 'Caterpillar',
      'model': 'D6',
      'modelYear': 2021,
      'transportLengthFt': 20,
      'transportWidthIn': 120,
      'transportHeightFt': 10,
    });

    expect(snapshot.equipmentSummary, '2021 Caterpillar D6');
    expect(snapshot.lengthM, closeTo(6.096, 0.001));
    expect(snapshot.widthM, closeTo(3.048, 0.001));
    expect(snapshot.heightM, closeTo(3.048, 0.001));
  });

  test('carrier notes record approximate specs and unknown weight clearly', () {
    const snapshot = DispatchSpecAssistSnapshot(
      make: 'Caterpillar',
      model: 'D6',
      year: 2021,
      description: 'LGP undercarriage, PAT blade, rear ripper',
      lengthM: 6.1,
      widthM: 3.05,
      heightM: 3.1,
      source: 'Pipe Buyer approved catalog',
      confidence: 'admin reviewed',
    );

    final notes = snapshot.appendToNotes(
      'Machine loads from seller yard.',
      weightUnknown: true,
    );

    expect(notes, contains('Equipment: 2021 Caterpillar D6'));
    expect(notes, contains('Approx. transport dimensions:'));
    expect(notes, contains('Planning spec source: Pipe Buyer approved catalog'));
    expect(notes, contains('Shipping weight: TO CONFIRM'));
  });
}
