import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_navigation.dart';

Widget _navigationSubject({
  required DispatchAccountState state,
  required DispatchSection selected,
  required ValueChanged<DispatchSection> onSelected,
  required VoidCallback onProviderAction,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: MarketplaceDispatchNavigation(
            selected: selected,
            accountState: state,
            onSelected: onSelected,
            onProviderAction: onProviderAction,
          ),
        ),
      ),
    );

void main() {
  test('missing provider profile resolves to customer-only Dispatch state', () {
    final state = DispatchAccountState.fromCarrierProfile(exists: false);
    expect(state.role, DispatchAccountRole.customerOnly);
    expect(state.providerRegistered, isFalse);
    expect(state.providerActionLabel, 'List your business');
  });

  test('legacy provider profile resolves to customer and provider', () {
    final state = DispatchAccountState.fromCarrierProfile(
      exists: true,
      data: const {'status': 'active'},
    );
    expect(state.role, DispatchAccountRole.customerAndProvider);
    expect(state.providerRegistered, isTrue);
    expect(state.providerActionLabel, 'Company Profile');
    expect(state.providerStatusLabel, 'Provider active');
  });

  test('explicit provider-only role remains supported', () {
    final state = DispatchAccountState.fromCarrierProfile(
      exists: true,
      data: const {
        'status': 'active',
        'dispatchRoles': ['provider'],
      },
    );
    expect(state.role, DispatchAccountRole.providerOnly);
    expect(state.canRequestServices, isFalse);
  });

  test('explicit customer and provider roles resolve to dual-role account', () {
    final state = DispatchAccountState.fromCarrierProfile(
      exists: true,
      data: const {
        'status': 'pending_review',
        'dispatchRoles': ['customer', 'provider'],
      },
    );
    expect(state.role, DispatchAccountRole.customerAndProvider);
    expect(state.providerStatusLabel, 'Review pending');
  });

  testWidgets('desktop navigation contains only four core Dispatch sections',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    DispatchSection? selected;
    var providerActionCount = 0;
    await tester.pumpWidget(_navigationSubject(
      state: DispatchAccountState.fromCarrierProfile(exists: false),
      selected: DispatchSection.dashboard,
      onSelected: (value) => selected = value,
      onProviderAction: () => providerActionCount += 1,
    ));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Request Service'), findsOneWidget);
    expect(find.text('Directory'), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Signup'), findsNothing);
    expect(find.text('Pilot'), findsNothing);
    expect(find.text('List your business'), findsOneWidget);

    await tester.ensureVisible(find.text('Directory'));
    await tester.tap(find.text('Directory'));
    await tester.pump();
    expect(selected, DispatchSection.directory);

    await tester.ensureVisible(find.text('List your business'));
    await tester.tap(find.text('List your business'));
    await tester.pump();
    expect(providerActionCount, 1);
  });

  testWidgets('registered provider sees Company Profile action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_navigationSubject(
      state: DispatchAccountState.fromCarrierProfile(
        exists: true,
        data: const {'status': 'active'},
      ),
      selected: DispatchSection.dashboard,
      onSelected: (_) {},
      onProviderAction: () {},
    ));

    expect(find.text('Company Profile'), findsOneWidget);
    expect(find.text('Customer + Provider'), findsOneWidget);
    expect(find.text('List your business'), findsNothing);
  });

  testWidgets('mobile Dispatch navigation remains horizontally scrollable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_navigationSubject(
      state: DispatchAccountState.fromCarrierProfile(exists: false),
      selected: DispatchSection.dashboard,
      onSelected: (_) {},
      onProviderAction: () {},
    ));

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Request Service'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer home exposes request, directory, jobs and business paths',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var directoryCount = 0;
    var jobsCount = 0;
    var businessCount = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarketplaceDispatchCustomerHome(
          onRequestService: () {},
          onBrowseDirectory: () => directoryCount += 1,
          onBrowseJobs: () => jobsCount += 1,
          onListBusiness: () => businessCount += 1,
        ),
      ),
    ));

    expect(find.text('I need a service'), findsOneWidget);
    expect(find.text('I provide services'), findsOneWidget);
    expect(find.text('Request a service'), findsOneWidget);
    expect(find.text('Browse directory'), findsOneWidget);
    expect(find.text('Browse Jobs'), findsOneWidget);
    expect(find.text('List your business'), findsOneWidget);

    // Request Service now opens the real R4 review-before-submit modal. This
    // Firebase-free presentation test verifies the entry is present, while the
    // dedicated R4 source contracts verify the modal routing itself.
    await tester.tap(find.text('Browse directory'));
    await tester.tap(find.text('Browse Jobs'));
    await tester.tap(find.text('List your business'));
    await tester.pump();

    expect(directoryCount, 1);
    expect(jobsCount, 1);
    expect(businessCount, 1);
    expect(tester.takeException(), isNull);
  });
}
