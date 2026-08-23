import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/design/pipe_buyer_account_components.dart';
import 'package:pipe_app/core/design/pipe_buyer_deal_room_components.dart';
import 'package:pipe_app/core/design/pipe_buyer_dispatch_components.dart';
import 'package:pipe_app/core/design/pipe_buyer_form_components.dart';
import 'package:pipe_app/core/design/pipe_buyer_listing_components.dart';
import 'package:pipe_app/core/design/pipe_buyer_theme.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
        theme: PipeBuyerTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      );

  testWidgets('listing detail stacks on mobile', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const PipeBuyerListingDetailShell(
      gallery: SizedBox(height: 180, child: Text('Gallery')),
      summary: SizedBox(height: 120, child: Text('Summary')),
      details: SizedBox(height: 100, child: Text('Details')),
    )));

    final gallery = tester.getRect(find.text('Gallery'));
    final summary = tester.getRect(find.text('Summary'));
    final details = tester.getRect(find.text('Details'));
    expect(summary.top, greaterThan(gallery.bottom));
    expect(details.top, greaterThan(summary.bottom));
  });

  testWidgets('listing detail uses two-column hero on desktop', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const PipeBuyerListingDetailShell(
      gallery: SizedBox(height: 240, child: Text('Gallery')),
      summary: SizedBox(height: 220, child: Text('Summary')),
      details: SizedBox(height: 120, child: Text('Details')),
      sidebar: SizedBox(height: 100, child: Text('Sidebar')),
    )));

    final gallery = tester.getRect(find.text('Gallery'));
    final summary = tester.getRect(find.text('Summary'));
    expect((gallery.top - summary.top).abs(), lessThan(2));
    expect(summary.left, greaterThan(gallery.right));
  });

  testWidgets('guided form reports current mobile step', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const PipeBuyerFormProgress(
      currentStep: 2,
      steps: [
        PipeBuyerFormStepData(label: 'Category', icon: Icons.category_outlined),
        PipeBuyerFormStepData(label: 'Details', icon: Icons.tune_outlined),
        PipeBuyerFormStepData(label: 'Media', icon: Icons.photo_library_outlined),
        PipeBuyerFormStepData(label: 'Location', icon: Icons.location_on_outlined),
        PipeBuyerFormStepData(label: 'Publish', icon: Icons.publish_outlined),
      ],
    )));

    expect(find.text('Step 3 of 5'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
  });

  testWidgets('form action bar prioritizes continue on mobile', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(PipeBuyerFormActionBar(
      onBack: () {},
      onSaveDraft: () {},
      onContinue: () {},
    )));

    final next = tester.getRect(find.text('Continue'));
    final draft = tester.getRect(find.text('Save Draft'));
    expect(draft.top, greaterThan(next.bottom));
  });

  testWidgets('deal room exposes three panes on wide screens', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: PipeBuyerTheme.light(),
      home: Scaffold(
        body: PipeBuyerDealRoomShell(
          conversations: const Center(child: Text('Conversations')),
          conversation: const Center(child: Text('Chat')),
          summary: const Center(child: Text('Deal Summary')),
        ),
      ),
    ));

    final conversations = tester.getRect(find.text('Conversations'));
    final chat = tester.getRect(find.text('Chat'));
    final summary = tester.getRect(find.text('Deal Summary'));
    expect(chat.left, greaterThan(conversations.right));
    expect(summary.left, greaterThan(chat.right));
  });

  testWidgets('offer card keeps counter and accept actions', (tester) async {
    await tester.pumpWidget(app(PipeBuyerOfferCard(
      title: 'New Offer Received',
      items: const [
        PipeBuyerDealRowData(label: 'Offer Price', value: r'$2.35 / ft', emphasize: true),
        PipeBuyerDealRowData(label: 'Quantity', value: '20,000 ft'),
      ],
      onCounter: () {},
      onAccept: () {},
    )));

    expect(find.text('Counter Offer'), findsOneWidget);
    expect(find.text('Accept Offer'), findsOneWidget);
  });

  testWidgets('dispatch workspace keeps loads before map on mobile', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const PipeBuyerDispatchWorkspace(
      loads: SizedBox(height: 120, child: Text('Loads')),
      map: SizedBox(height: 180, child: Text('Route Map')),
    )));

    final loads = tester.getRect(find.text('Loads'));
    final map = tester.getRect(find.text('Route Map'));
    expect(map.top, greaterThan(loads.bottom));
  });

  testWidgets('dispatch load row collapses into card on mobile', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(PipeBuyerLoadRow(
      payout: r'$8,450',
      commodity: 'OCTG Pipe',
      origin: 'Houston, TX',
      destination: 'Midland, TX',
      trailer: 'Flatbed 48 ft',
      loadSize: '45,000 lbs',
      onView: () {},
    )));

    expect(find.text(r'$8,450'), findsOneWidget);
    expect(find.text('Houston, TX'), findsOneWidget);
    expect(find.text('Midland, TX'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
  });

  testWidgets('center actions form three columns on desktop', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(PipeBuyerCenterActions(items: [
      PipeBuyerCenterActionData(
        icon: Icons.inventory_2_outlined,
        title: 'My Listings',
        subtitle: 'Manage inventory',
        onTap: () {},
      ),
      PipeBuyerCenterActionData(
        icon: Icons.handshake_outlined,
        title: 'Offers',
        subtitle: 'Review deal activity',
        onTap: () {},
      ),
      PipeBuyerCenterActionData(
        icon: Icons.favorite_border,
        title: 'Saved',
        subtitle: 'Watch inventory',
        onTap: () {},
      ),
    ])));

    final tops = <double>{
      tester.getRect(find.text('My Listings')).top,
      tester.getRect(find.text('Offers')).top,
      tester.getRect(find.text('Saved')).top,
    };
    expect(tops.length, 1);
  });

  testWidgets('listing health clamps completion', (tester) async {
    await tester.pumpWidget(app(const PipeBuyerListingHealthCard(
      title: 'Listing Health',
      completion: 140,
      items: [
        PipeBuyerHealthItemData(label: 'Photos', complete: true),
        PipeBuyerHealthItemData(label: 'Inspection', complete: false),
      ],
    )));

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Inspection'), findsOneWidget);
  });
}
