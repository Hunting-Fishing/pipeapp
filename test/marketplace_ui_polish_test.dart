import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/accessibility/pipe_accessibility_theme.dart';
import 'package:pipe_app/core/design/pipe_buyer_theme.dart';
import 'package:pipe_app/marketplace/marketplace_account_hub.dart';
import 'package:pipe_app/marketplace/marketplace_adaptive_shell.dart';
import 'package:pipe_app/marketplace/marketplace_messages_page.dart';

void main() {
  group('conversation participant labels', () {
    test('selects the other participant and safe role fallbacks', () {
      const cases = <({
        Map<String, dynamic> conversation,
        String viewerUid,
        String expected,
      })>[
        (
          conversation: {
            'sellerUid': 'seller-1',
            'buyerDisplayName': '  Ana Buyer  ',
            'requesterDisplayName': 'Request Contact',
            'sellerName': 'Sam Seller',
          },
          viewerUid: 'seller-1',
          expected: 'Ana Buyer',
        ),
        (
          conversation: {
            'sellerUid': 'seller-1',
            'buyerDisplayName': ' ',
            'requesterDisplayName': 'Request Contact',
          },
          viewerUid: 'seller-1',
          expected: 'Request Contact',
        ),
        (
          conversation: {'sellerUid': 'seller-1'},
          viewerUid: 'seller-1',
          expected: 'Marketplace buyer',
        ),
        (
          conversation: {
            'sellerUid': 'seller-1',
            'sellerName': '  Sam Seller  ',
          },
          viewerUid: 'buyer-1',
          expected: 'Sam Seller',
        ),
        (
          conversation: {'sellerUid': 'seller-1'},
          viewerUid: 'buyer-1',
          expected: 'Marketplace seller',
        ),
      ];

      for (final testCase in cases) {
        expect(
          marketplaceConversationParticipantName(
            testCase.conversation,
            testCase.viewerUid,
          ),
          testCase.expected,
        );
      }
    });
  });

  test('account greeting skips blank stored profile names', () {
    expect(
      marketplaceAccountDisplayName(
        const {'display_name': ' ', 'displayName': ''},
        authDisplayName: '  Jordan Bailey  ',
        email: 'fallback@example.com',
      ),
      'Jordan Bailey',
    );
    expect(
      marketplaceAccountDisplayName(
        const {'display_name': ''},
        email: ' fallback@example.com ',
      ),
      'fallback@example.com',
    );
  });

  testWidgets('message timestamps are compact today and dated on older days', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              Text(
                marketplaceMessageTimestamp(
                  context,
                  DateTime(2026, 10, 18, 14, 30),
                  now: DateTime(2026, 10, 18, 18),
                ),
                key: const Key('today-timestamp'),
              ),
              Text(
                marketplaceMessageTimestamp(
                  context,
                  DateTime(2026, 10, 17, 14, 30),
                  now: DateTime(2026, 10, 18, 18),
                ),
                key: const Key('older-timestamp'),
              ),
              Text(
                marketplaceMessageTimestamp(context, null),
                key: const Key('missing-timestamp'),
              ),
              Text(
                marketplaceMessageTimestamp(
                  context,
                  DateTime(2026, 10, 17, 14, 30),
                  now: DateTime(2026, 10, 18, 18),
                  includeTimeOnOlderDays: false,
                ),
                key: const Key('inbox-timestamp'),
              ),
            ],
          ),
        ),
      ),
    );

    final today = tester.widget<Text>(find.byKey(const Key('today-timestamp')));
    final older = tester.widget<Text>(find.byKey(const Key('older-timestamp')));
    final missing =
        tester.widget<Text>(find.byKey(const Key('missing-timestamp')));
    final inbox = tester.widget<Text>(find.byKey(const Key('inbox-timestamp')));

    expect(today.data, isNotEmpty);
    expect(today.data, isNot(contains('•')));
    expect(older.data, contains('•'));
    expect(older.data, isNot(equals(today.data)));
    expect(missing.data, isEmpty);
    expect(inbox.data, isNotEmpty);
    expect(inbox.data, isNot(contains('•')));
  });

  for (final width in <double>[390, 1200]) {
    testWidgets(
      'conversation tile remains readable and actionable at ${width.toInt()}px',
      (tester) async {
        var opened = false;
        await _setSurface(tester, width: width);
        await tester.pumpWidget(
          _testApp(
            ListView(
              padding: const EdgeInsets.all(12),
              children: [
                MarketplaceConversationTile(
                  participantName: 'Longtime Oilfield Equipment Buyer',
                  listingTitle: 'CAT 336 excavator with attachments',
                  lastMessage: 'Can you confirm the inspection window?',
                  timestamp: '10/18/2026 • 2:30 PM',
                  unread: 3,
                  avatar: const CircleAvatar(child: Text('L')),
                  onTap: () => opened = true,
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Longtime Oilfield Equipment Buyer'), findsOneWidget);
        expect(find.text('CAT 336 excavator with attachments'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byType(MarketplaceConversationTile));
        await tester.pump();
        expect(opened, isTrue);
      },
    );

    testWidgets(
      'chat bubbles use a responsive readable width at ${width.toInt()}px',
      (tester) async {
        await _setSurface(tester, width: width);
        await tester.pumpWidget(
          _testApp(
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  MarketplaceChatBubble(
                    text: 'The inspection report is ready for review.',
                    isMine: false,
                    hiddenByModeration: false,
                    timestamp: '2:30 PM',
                  ),
                  MarketplaceChatBubble(
                    text: 'Thank you. I will review it now.',
                    isMine: true,
                    hiddenByModeration: false,
                    timestamp: '2:32 PM',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final expectedMaxWidth = width >= 720 ? 520.0 : width * .78;
        final responsiveBubble = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth == expectedMaxWidth,
        );

        expect(responsiveBubble, findsNWidgets(2));
        expect(find.text('2:30 PM'), findsOneWidget);
        expect(find.text('2:32 PM'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('secondary commerce pages select Browse on compact navigation', (
    tester,
  ) async {
    await _setSurface(tester, width: 390);

    for (final pageIndex in const [3, 6, 7]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MarketplaceAdaptiveShell(
            scaffoldKey: GlobalKey<ScaffoldState>(),
            selectedPageIndex: pageIndex,
            title: 'Pipe Buyer',
            body: const SizedBox.expand(),
            drawer: const Drawer(child: Text('Marketplace navigation')),
            compactDestinations: _compactDestinations,
            railDestinations: _railDestinations,
            onDestinationSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navigation =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(
        navigation.selectedIndex,
        1,
        reason: 'page $pageIndex belongs under Browse on compact screens',
      );
    }
  });

  test('white action text meets WCAG AA against themed action colors', () {
    expect(
      _contrastRatio(Colors.white, PipeBuyerColors.orangeActionFill),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(PipeBuyerColors.orangePressed, PipeBuyerColors.darkCanvas),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(
        PipeBuyerColors.orangePressed,
        PipeBuyerColors.darkSurface,
      ),
      greaterThanOrEqualTo(4.5),
    );

    for (final theme in [
      PipeBuyerTheme.light(),
      PipeBuyerTheme.dark(),
      PipeAccessibilityTheme.apply(PipeBuyerTheme.light()),
      PipeAccessibilityTheme.apply(PipeBuyerTheme.dark()),
    ]) {
      final buttonStyle = theme.filledButtonTheme.style!;
      final background = buttonStyle.backgroundColor!.resolve({})!;
      final foreground = buttonStyle.foregroundColor!.resolve({})!;

      expect(_contrastRatio(foreground, background), greaterThanOrEqualTo(4.5));
      expect(
        _contrastRatio(theme.colorScheme.onPrimary, theme.colorScheme.primary),
        greaterThanOrEqualTo(4.5),
      );

      final selectedStates = <WidgetState>{WidgetState.selected};
      final actionForegrounds = <Color>[
        theme.colorScheme.primary,
        theme.textButtonTheme.style!.foregroundColor!.resolve({})!,
        theme.tabBarTheme.labelColor!,
        theme.navigationBarTheme.labelTextStyle!
            .resolve(selectedStates)!
            .color!,
        theme.navigationRailTheme.selectedLabelTextStyle!.color!,
      ];
      for (final actionForeground in actionForegrounds) {
        expect(
          _contrastRatio(actionForeground, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(actionForeground, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      }

      final selectedIcon =
          theme.navigationBarTheme.iconTheme!.resolve(selectedStates)!.color!;
      expect(
        _contrastRatio(
          selectedIcon,
          theme.navigationBarTheme.indicatorColor!,
        ),
        greaterThanOrEqualTo(3),
      );
    }
  });

  test('Account and Timed Buying sources reject mojibake markers', () {
    const paths = [
      'lib/marketplace/marketplace_account_hub.dart',
      'lib/marketplace/marketplace_auctions_page.dart',
    ];
    const suspiciousFragments = ['Ã', 'Â', 'â€', 'ðŸ', '�'];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      for (final fragment in suspiciousFragments) {
        expect(
          source,
          isNot(contains(fragment)),
          reason: '$path contains the mojibake fragment "$fragment"',
        );
      }
    }
  });
}

Future<void> _setSurface(
  WidgetTester tester, {
  required double width,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _testApp(Widget child) => MaterialApp(
      theme: PipeBuyerTheme.light(),
      home: Scaffold(body: child),
    );

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

const _compactDestinations = <MarketplaceShellDestination>[
  MarketplaceShellDestination(
    pageIndex: 0,
    label: 'Home',
    icon: Icon(Icons.home_outlined),
  ),
  MarketplaceShellDestination(
    pageIndex: 1,
    label: 'Browse',
    icon: Icon(Icons.search),
  ),
  MarketplaceShellDestination(
    pageIndex: 2,
    label: 'Sell',
    icon: Icon(Icons.add_box_outlined),
  ),
  MarketplaceShellDestination(
    pageIndex: 4,
    label: 'Messages',
    icon: Icon(Icons.forum_outlined),
  ),
  MarketplaceShellDestination(
    pageIndex: 5,
    label: 'Account',
    icon: Icon(Icons.person_outline),
  ),
];

const _railDestinations = <MarketplaceShellDestination>[
  ..._compactDestinations,
  MarketplaceShellDestination(
    pageIndex: 6,
    label: 'Timed Buying',
    icon: Icon(Icons.gavel_outlined),
  ),
  MarketplaceShellDestination(
    pageIndex: 7,
    label: 'Dispatch',
    icon: Icon(Icons.local_shipping_outlined),
  ),
];
