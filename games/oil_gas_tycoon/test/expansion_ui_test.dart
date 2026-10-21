import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oil_gas_tycoon/src/tycoon_engine.dart';
import 'package:oil_gas_tycoon/src/ui/tycoon_game_page.dart';
import 'package:oil_gas_tycoon/src/ui/tycoon_theme.dart';

Future<void> _pump(WidgetTester tester, GameEngine engine,
    {double scale = 1, VoidCallback? onChanged}) async {
  await tester.pumpWidget(MaterialApp(
    theme: TycoonPalette.theme,
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale), disableAnimations: true),
        child: child!),
    home: TycoonGamePage(
        engine: engine,
        onChanged: onChanged ?? () {},
        onReset: () async {},
        onExport: () async {},
        onImport: () async {}),
  ));
  await tester.pumpAndSettle();
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String key) async {
  final tile = find.byKey(PageStorageKey<String>(key));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder _dialogButton(String text) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, text));

void main() {
  testWidgets(
      'auction bid explains invalid input then holds cash and autosaves',
      (tester) async {
    _size(tester, const Size(390, 844));
    final game = GameEngine.newGame();
    final auction = game.state.auctions
        .firstWhere((auction) => auction.status == AuctionStatus.open);
    final minimum = game.minimumAuctionBid(auction.id);
    final before = jsonEncode(game.state.toJson());
    final cash = game.state.cash;
    var saves = 0;
    await _pump(tester, game, onChanged: () => saves++);
    await _tab(tester, 'Exchange');
    expect(find.text('Used equipment auctions'), findsOneWidget);
    await _open(tester, 'auction-board');
    await _tap(tester, find.byKey(Key('bid-${auction.id}')));
    expect(find.text('Bid on ${auction.spec.name}'), findsOneWidget);
    final field = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));

    await tester.enterText(field, '${minimum - 1}');
    await _tap(tester, _dialogButton('Confirm bid'));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.widget<TextField>(field).decoration!.errorText, isNotNull);
    expect(jsonEncode(game.state.toJson()), before);
    expect(saves, 0);

    await tester.enterText(field, '${auction.spec.price + 1}');
    await _tap(tester, _dialogButton('Confirm bid'));
    expect(tester.widget<TextField>(field).decoration!.errorText, isNotNull);
    expect(jsonEncode(game.state.toJson()), before);
    expect(saves, 0);

    await tester.enterText(field, '$minimum');
    await _tap(tester, _dialogButton('Confirm bid'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(auction.playerLeading, isTrue);
    expect(game.auctionEscrow, minimum);
    expect(game.state.cash, cash - minimum);
    expect(find.text('YOU LEAD'), findsOneWidget);
    expect(saves, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settled auction result shows the asset delivered to the fleet',
      (tester) async {
    _size(tester, const Size(390, 844));
    final game = GameEngine.newGame();
    final auction = game.state.auctions.first;
    final initialAssets = game.state.assets.length;
    expect(game.bidAtAuction(auction.id, auction.spec.price).success, isTrue);
    while (game.state.day < auction.closingDay) {
      expect(game.advanceDay().success, isTrue);
    }
    expect(auction.status, AuctionStatus.won);
    expect(game.state.assets.length, initialAssets + 1);
    await _pump(tester, game);
    await _tab(tester, 'Exchange');
    await _open(tester, 'auction-board');
    expect(find.text('Recent auction results'), findsOneWidget);
    expect(
        find.text('Won · ${tycoonMoney(auction.currentBid)}'), findsOneWidget);
    await _tab(tester, 'Fleet');
    expect(find.text(auction.spec.name), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('research is funded once and cancellation needs confirmation',
      (tester) async {
    _size(tester, const Size(390, 844));
    final game = GameEngine.newGame();
    expect(game.hireEmployee(EmployeeRole.engineer).success, isTrue);
    final cost = game.researchCost('production');
    final cash = game.state.cash;
    var saves = 0;
    await _pump(tester, game, onChanged: () => saves++);
    await _tab(tester, 'Company');
    await _open(tester, 'research-board');
    await _open(tester, 'technology-production');
    await _tap(tester, find.byKey(const Key('research-production')));
    expect(find.textContaining('not refunded if you cancel'), findsOneWidget);
    await _tap(tester, _dialogButton('Fund research'));
    expect(game.state.researchProject!.researchId, 'production');
    expect(game.state.cash, cash - cost);
    expect(find.byKey(const Key('active-research')), findsOneWidget);
    expect(saves, 1);

    await _tap(tester, find.byKey(const Key('cancel-research')));
    await _tap(tester, find.widgetWithText(TextButton, 'Keep playing'));
    expect(game.state.researchProject, isNotNull);
    expect(saves, 1);
    await _tap(tester, find.byKey(const Key('cancel-research')));
    await _tap(tester, _dialogButton('Cancel research'));
    expect(game.state.researchProject, isNull);
    expect(game.state.cash, cash - cost);
    expect(saves, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused research explains the reason and can hire an engineer',
      (tester) async {
    _size(tester, const Size(390, 844));
    final game = GameEngine.newGame();
    expect(game.hireEmployee(EmployeeRole.engineer).success, isTrue);
    expect(game.startResearch('production').success, isTrue);
    final researcher = game.state.employees
        .firstWhere((employee) => employee.role == EmployeeRole.engineer);
    expect(game.fireEmployee(researcher.id).success, isTrue);
    final remaining = game.state.researchProject!.remainingShifts;
    var saves = 0;
    await _pump(tester, game, onChanged: () => saves++);
    await _tab(tester, 'Company');
    await _open(tester, 'research-board');
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.textContaining('Research is paused because no engineer'),
        findsOneWidget);
    await _tap(tester, find.byKey(const Key('research-hire-engineer')));
    await _tap(tester, _dialogButton('Hire engineer'));
    expect(game.researchCanProgress, isTrue);
    expect(find.text('RESEARCHING'), findsOneWidget);
    expect(game.state.researchProject!.remainingShifts, remaining);
    expect(saves, 1);
    await _tap(tester, find.byKey(const Key('advance-shift')));
    expect(game.state.researchProject!.remainingShifts, remaining - 1);
    expect(saves, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('technology rows show the earned benefit and next level',
      (tester) async {
    _size(tester, const Size(390, 844));
    final game = GameEngine.newGame();
    expect(game.hireEmployee(EmployeeRole.engineer).success, isTrue);
    expect(game.startResearch('storage').success, isTrue);
    while (game.state.researchProject != null) {
      expect(game.advanceDay().success, isTrue);
    }
    final spec = TycoonCatalog.research
        .firstWhere((research) => research.id == 'storage');
    await _pump(tester, game);
    await _tab(tester, 'Company');
    await _open(tester, 'research-board');
    await _open(tester, 'technology-storage');
    expect(find.text('Level 1 / 3'), findsOneWidget);
    expect(find.text(spec.benefitAtLevel(1)), findsOneWidget);
    expect(find.text(spec.benefitAtLevel(2)), findsOneWidget);
    expect(find.text('Research level 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'restructuring warns about held bids and research before replacing',
      (tester) async {
    _size(tester, const Size(390, 844));
    final game = GameEngine.newGame();
    expect(game.hireEmployee(EmployeeRole.engineer).success, isTrue);
    expect(game.startResearch('production').success, isTrue);
    final auction = game.state.auctions.first;
    final bid = game.minimumAuctionBid(auction.id);
    expect(game.bidAtAuction(auction.id, bid).success, isTrue);
    game.state.cash = -1;
    final before = jsonEncode(game.state.toJson());
    var saves = 0;
    await _pump(tester, game, onChanged: () => saves++);
    await _tap(
        tester, find.widgetWithText(OutlinedButton, 'Restructure company'));
    expect(
        find.textContaining(
            'Auction cash held (${tycoonMoney(bid)}) is forfeited'),
        findsOneWidget);
    expect(
        find.textContaining(
            'Any active research is cancelled without a refund'),
        findsOneWidget);
    expect(find.textContaining('Learned technologies'), findsOneWidget);
    await _tap(tester, find.widgetWithText(TextButton, 'Keep playing'));
    expect(jsonEncode(game.state.toJson()), before);
    expect(saves, 0);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in [const Size(320, 844), const Size(844, 390)]) {
    testWidgets('expansion controls fit $viewport with 200 percent text',
        (tester) async {
      _size(tester, viewport);
      final game = GameEngine.newGame();
      expect(game.hireEmployee(EmployeeRole.engineer).success, isTrue);
      await _pump(tester, game, scale: 2);
      await _tab(tester, 'Exchange');
      await _open(tester, 'auction-board');
      expect(tester.takeException(), isNull);
      await _tap(
          tester, find.byKey(Key('bid-${game.state.auctions.first.id}')));
      expect(tester.takeException(), isNull);
      await _tap(tester, find.widgetWithText(TextButton, 'Cancel'));
      await _tab(tester, 'Company');
      await _open(tester, 'research-board');
      for (final spec in TycoonCatalog.research) {
        await _open(tester, 'technology-${spec.id}');
        expect(tester.takeException(), isNull);
      }
      await _tap(tester, find.byKey(const Key('research-production')));
      expect(tester.takeException(), isNull);
      await _tap(tester, _dialogButton('Fund research'));
      expect(find.byKey(const Key('active-research')), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Let the visible action confirmation expire before interacting behind it.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('cancel-research')));
      expect(tester.takeException(), isNull);
      await _tap(tester, _dialogButton('Cancel research'));
      expect(game.state.researchProject, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
