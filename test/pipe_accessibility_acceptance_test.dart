import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/accessibility/pipe_accessibility_theme.dart';
import 'package:pipe_app/marketplace/marketplace_auth_page.dart';
import 'package:pipe_app/marketplace/marketplace_offer_schedule.dart';

void main() {
  for (final viewport in const <String, Size>{
    'compact portrait': Size(320, 568),
    'phone portrait': Size(390, 844),
    'phone landscape': Size(844, 390),
    'tablet landscape': Size(1024, 768),
  }.entries) {
    testWidgets(
        'sign-in remains operable at 200 percent text on ${viewport.key}',
        (tester) async {
      tester.view.physicalSize = viewport.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: PipeAccessibilityTheme.apply(ThemeData.light()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: PipeAccessibilityRoot(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const MarketplaceAuthPage(),
      ));
      await tester.pump();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in securely'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(PipeAccessibilityTheme.minimumTouchTarget),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sign-in supports keyboard navigation and labelled icon actions',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: PipeAccessibilityTheme.apply(ThemeData.light()),
      builder: (context, child) => PipeAccessibilityRoot(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const MarketplaceAuthPage(),
    ));
    await tester.pump();

    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList(growable: false);
    expect(fields, hasLength(2));

    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    expect(fields.first.focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(fields[1].focusNode.hasFocus, isTrue);

    for (final button
        in tester.widgetList<IconButton>(find.byType(IconButton))) {
      if (button.onPressed != null) {
        expect(button.tooltip, isNotEmpty,
            reason: 'Enabled icon actions need a visible and semantic label.');
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('account creation remains usable on compact high-text viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: PipeAccessibilityTheme.apply(ThemeData.light()),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
        ),
        child: PipeAccessibilityRoot(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const MarketplaceAuthPage(),
    ));

    final createAccount = find.text('New to Pipe Buyer? Create an account');
    await tester.ensureVisible(createAccount);
    await tester.pump();
    await tester.tap(createAccount);
    await tester.pump();

    expect(find.text('Join Pipe Buyer'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);
    expect(find.text('Create personal account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offer schedule remains readable on a compact high-text viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final milestones = marketplaceOfferMilestones({
      'purchaseDate': DateTime(2026, 8, 14),
      'moneyTransferDate': DateTime(2026, 8, 10),
      'truckingDate': DateTime(2026, 9, 2),
    });

    await tester.pumpWidget(MaterialApp(
      theme: PipeAccessibilityTheme.apply(ThemeData.light()),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
        ),
        child: PipeAccessibilityRoot(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarketplaceOfferScheduleCard(milestones: milestones),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Purchase'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Trucking'), findsOneWidget);
    expect(find.text('Open calendar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offer decision remains actionable on compact high-text viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: PipeAccessibilityTheme.apply(ThemeData.light()),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
        ),
        child: PipeAccessibilityRoot(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => MarketplaceAcceptOfferDialog(offer: {
                'offeredTotal': 3942,
                'requestedQuantity': 54,
                'purchaseDate': DateTime(2026, 8, 14),
                'moneyTransferDate': DateTime(2026, 8, 10),
                'truckingDate': DateTime(2026, 9, 2),
              }),
            ),
            child: const Text('Review offer'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Review offer'));
    await tester.pumpAndSettle();

    expect(find.text('Make counter offer'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Accept offer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
