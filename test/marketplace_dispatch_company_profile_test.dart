import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_company_profile.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_service_taxonomy.dart';

DispatchCompanyProfileDraft _draft({
  List<String> serviceCodes = const <String>['pilot_escort_vehicle'],
}) =>
    DispatchCompanyProfileDraft(
      companyName: 'Northline Heavy Haul Ltd.',
      operatingName: 'Northline Heavy Haul',
      businessType: DispatchBusinessType.corporation,
      description:
          'Heavy haul, pilot support and industrial transport serving northern Alberta and remote sites.',
      website: 'https://example.test',
      serviceCodes: serviceCodes,
      serviceAreaLabel: 'Northern Alberta + 500 km',
      availability: DispatchAvailability.availableNow,
      emergencyCallout: true,
      remoteSiteCapable: true,
    );

void main() {
  test('company profile stores stable service codes only', () {
    final profile = _draft(serviceCodes: const <String>[
      'pilot_escort_vehicle',
      'transport_lowboy',
      'not_a_real_dispatch_service',
      'transport_lowboy',
    ]);

    expect(
      profile.normalizedServiceCodes,
      const <String>['pilot_escort_vehicle', 'transport_lowboy'],
    );
    for (final code in profile.normalizedServiceCodes) {
      expect(
        DispatchServiceTaxonomy.services.any((service) => service.code == code),
        isTrue,
      );
    }
  });

  test('public profile projection excludes private account data', () {
    final public = _draft().toPublicProfileMap();
    expect(public['businessType'], 'corporation');
    expect(public['availability'], 'available_now');
    expect(public['serviceCodes'], const <String>['pilot_escort_vehicle']);
    expect(public.containsKey('email'), isFalse);
    expect(public.containsKey('phone'), isFalse);
    expect(public.containsKey('ownerUid'), isFalse);
    expect(public.containsKey('insuranceDocument'), isFalse);
  });

  test('directory foundation requires identity, services and service area', () {
    expect(_draft().readyForDirectoryFoundation, isTrue);

    final incomplete = DispatchCompanyProfileDraft(
      companyName: '',
      operatingName: '',
      businessType: DispatchBusinessType.ownerOperator,
      description: '',
      website: '',
      serviceCodes: const <String>[],
      serviceAreaLabel: '',
      availability: DispatchAvailability.unavailable,
      emergencyCallout: false,
      remoteSiteCapable: false,
    );
    expect(incomplete.readyForDirectoryFoundation, isFalse);
    expect(incomplete.completionPercent, lessThan(100));
  });

  testWidgets('profile editor supports structured service selection',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    DispatchCompanyProfileDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketplaceDispatchCompanyProfileEditor(
            initial: _draft(serviceCodes: const <String>[]),
            onSave: (value) => saved = value,
          ),
        ),
      ),
    );

    expect(find.text('Transportation'), findsOneWidget);
    expect(find.text('Pilot & Oversize Support'), findsOneWidget);
    expect(find.text('Crane & Lifting'), findsOneWidget);
    expect(find.text('Oilfield & Industrial Field Services'), findsOneWidget);

    final pilotService = find.text('Pilot / Escort Vehicle');
    await tester.ensureVisible(pilotService);
    await tester.pumpAndSettle();
    await tester.tap(pilotService);
    await tester.pump();

    final scrollable = find.byType(Scrollable).first;
    final saveButton = find.text('Save company profile');
    await tester.dragUntilVisible(
      saveButton,
      scrollable,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.normalizedServiceCodes, contains('pilot_escort_vehicle'));
  });

  testWidgets('profile editor exposes business type and availability',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketplaceDispatchCompanyProfileEditor(
            initial: _draft(),
            onSave: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Business type'), findsOneWidget);
    expect(find.text('Corporation / company'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    final serviceAreaHeading = find.text('Service area & availability');
    await tester.dragUntilVisible(
      serviceAreaHeading,
      scrollable,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(find.text('Availability'), findsOneWidget);
    expect(find.text('Available now'), findsOneWidget);
    expect(find.text('Emergency callout available'), findsOneWidget);
    expect(find.text('Remote-site capable'), findsOneWidget);
  });
}
