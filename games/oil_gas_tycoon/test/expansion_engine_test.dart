import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oil_gas_tycoon/src/tycoon_engine.dart';

Map<String, dynamic> _save(GameEngine game) =>
    jsonDecode(jsonEncode(game.state.toJson())) as Map<String, dynamic>;

String _snapshot(GameEngine game) => jsonEncode(game.state.toJson());

void _loadable(GameEngine game) {
  final restored = GameState.fromJson(_save(game));
  expect(jsonEncode(restored.toJson()), _snapshot(game));
  expect(game.state.assets.length, lessThanOrEqualTo(200));
  expect(game.state.cash + game.auctionEscrow,
      lessThanOrEqualTo(GameEngine.maximumCash));
}

void _rejected(GameEngine game, ActionResult Function() command) {
  final before = _snapshot(game);
  expect(command().success, isFalse);
  expect(_snapshot(game), before);
}

GameEngine _funded() {
  final game = GameEngine.newGame();
  game.state.cash = 2000000;
  game.state.completedObjectives.addAll([
    'first_shift',
    'first_trade',
    'second_lease',
    'team',
    'business',
    'contract',
    'million',
  ]);
  return game;
}

void main() {
  group('Used equipment auctions', () {
    test('opening bid and raises hold only new cash and preserve net worth',
        () {
      final game = _funded();
      final auction = game.state.auctions.first;
      final cash = game.state.cash;
      final worth = game.netWorth;
      final credit = game.availableLoan;
      expect(game.bidAtAuction(auction.id, auction.openingBid).success, isTrue);
      expect(game.state.cash, cash - auction.openingBid);
      expect(game.auctionEscrow, auction.openingBid);
      expect(game.netWorth, worth);
      expect(game.availableLoan, credit);
      final raise = game.minimumAuctionBid(auction.id);
      expect(game.bidAtAuction(auction.id, raise).success, isTrue);
      expect(game.state.cash, cash - raise);
      expect(game.auctionEscrow, raise);
      expect(game.netWorth, worth);
      expect(auction.leaderName, 'Your company');
      _loadable(game);
    });

    test('invalid, unaffordable and expired bids leave everything unchanged',
        () {
      final game = _funded();
      final auction = game.state.auctions.first;
      _rejected(game, () => game.bidAtAuction('missing', 1000));
      _rejected(game, () => game.bidAtAuction(auction.id, 0));
      _rejected(game, () => game.bidAtAuction(auction.id, -1));
      _rejected(
          game, () => game.bidAtAuction(auction.id, auction.openingBid - 1));
      _rejected(
          game, () => game.bidAtAuction(auction.id, auction.spec.price + 1));
      game.state.cash = 10;
      _rejected(game, () => game.bidAtAuction(auction.id, auction.openingBid));
      game.state.cash = 2000000;
      while (game.state.day < auction.closingDay) {
        expect(game.advanceDay().success, isTrue);
      }
      _rejected(game, () => game.bidAtAuction(auction.id, auction.spec.price));
      _loadable(game);
    });

    test('rivals return held bids exactly once when they outbid the player',
        () {
      final game = _funded();
      final initialCash = game.state.cash;
      for (final auction in game.state.auctions) {
        expect(
            game.bidAtAuction(auction.id, auction.openingBid).success, isTrue);
      }
      final report = game.advanceDay().report!;
      expect(game.auctionEscrow, 0);
      expect(game.state.cash, initialCash - report.expenses);
      expect(report.notes.where((n) => n.contains('deposit was returned')),
          hasLength(3));
      expect(
          game.state.ledger
              .where((e) => e.title.startsWith('Auction bid returned')),
          hasLength(3));
      final next = game.advanceDay().report!;
      expect(game.state.cash, initialCash - report.expenses - next.expenses);
      expect(
          game.state.ledger
              .where((e) => e.title.startsWith('Auction bid returned')),
          hasLength(3));
      _loadable(game);
    });

    test(
        'winning delivers one asset in its advertised condition without another charge',
        () {
      final game = _funded();
      final auction = game.state.auctions.first;
      final originalAssets = game.state.assets.map((a) => a.id).toSet();
      final before = game.state.cash;
      expect(game.bidAtAuction(auction.id, auction.spec.price).success, isTrue);
      var expenses = 0;
      while (game.state.day < auction.closingDay) {
        expenses += game.advanceDay().report!.expenses;
      }
      expect(auction.status, AuctionStatus.won);
      expect(game.auctionEscrow, 0);
      expect(game.state.cash, before - auction.spec.price - expenses);
      final delivered =
          game.state.assets.where((a) => !originalAssets.contains(a.id)).single;
      expect(delivered.catalogId, auction.catalogId);
      expect(delivered.condition, auction.condition);
      game.advanceDay();
      expect(
          game.state.assets.where((a) => a.id == delivered.id), hasLength(1));
      _loadable(game);
    });

    test('held bids reserve both fleet capacity and treasury refund capacity',
        () {
      final game = _funded();
      while (game.state.assets.length < 199) {
        game.state.assets.add(OwnedAsset(
            id: 'spare_${game.state.assets.length}', catalogId: 'pumpjack'));
      }
      final first = game.state.auctions.first;
      expect(game.bidAtAuction(first.id, first.spec.price).success, isTrue);
      _rejected(game, () => game.buyAsset('tanker'));
      final second = game.state.auctions[1];
      _rejected(game, () => game.bidAtAuction(second.id, second.openingBid));
      while (game.state.day < first.closingDay) {
        game.advanceDay();
      }
      expect(game.state.assets, hasLength(200));
      _loadable(game);

      final capped = _funded();
      capped.buyBusiness('parts_yard');
      final bid = capped.state.auctions.first;
      capped.state.cash = GameEngine.maximumCash;
      expect(capped.bidAtAuction(bid.id, bid.openingBid).success, isTrue);
      _rejected(capped, () => capped.sellAsset(capped.state.assets.first.id));
      expect(capped.state.cash + capped.auctionEscrow, GameEngine.maximumCash);
      final report = capped.advanceDay().report!;
      expect(capped.auctionEscrow, 0);
      expect(capped.state.cash, GameEngine.maximumCash);
      expect(report.notes.join(' '), contains('Treasury limit'));
      expect(
          capped.state.ledger.any((e) =>
              e.title.startsWith('Auction bid returned') &&
              e.amount == bid.openingBid),
          isTrue);
      _loadable(capped);
    });

    test('auction history stays bounded and reloads replay identical rivals',
        () {
      final first = _funded();
      first.bidAtAuction(
          first.state.auctions.first.id, first.state.auctions.first.openingBid);
      var second = GameEngine(GameState.fromJson(_save(first)));
      for (var shift = 0; shift < 60; shift++) {
        for (final game in [first, second]) {
          expect(game.advanceDay().success, isTrue);
        }
        expect(_snapshot(second), _snapshot(first));
        expect(
            first.state.auctions.where((a) => a.status == AuctionStatus.open),
            hasLength(3));
        expect(first.state.auctions.length, lessThanOrEqualTo(12));
        second = GameEngine(GameState.fromJson(_save(second)));
      }
      _loadable(first);
    });
  });

  group('Research and technology', () {
    test(
        'requires an engineer, funding, free project slot and valid technology',
        () {
      final game = _funded();
      _rejected(game, () => game.startResearch('unknown'));
      _rejected(game, () => game.startResearch('production'));
      game.hireEmployee(EmployeeRole.engineer);
      game.state.cash = 0;
      _rejected(game, () => game.startResearch('production'));
      game.state.cash = 2000000;
      final cash = game.state.cash;
      expect(game.startResearch('production').success, isTrue);
      expect(game.state.cash, cash - 18000);
      expect(game.state.researchProject!.remainingShifts, 2);
      _rejected(game, () => game.startResearch('logistics'));
      _loadable(game);
    });

    test('work pauses without an engineer and applies a completed upgrade once',
        () {
      final game = _funded();
      game.hireEmployee(EmployeeRole.engineer);
      game.startResearch('storage');
      game.advanceDay();
      expect(game.state.researchProject!.remainingShifts, 1);
      expect(game.oilStorageCapacity, 1500);
      final engineer = game.state.employees
          .singleWhere((e) => e.role == EmployeeRole.engineer);
      game.fireEmployee(engineer.id);
      final paused = game.advanceDay().report!;
      expect(game.state.researchProject!.remainingShifts, 1);
      expect(paused.notes.join(' '), contains('research paused'));
      game.hireEmployee(EmployeeRole.engineer);
      game.advanceDay();
      expect(game.state.researchProject, isNull);
      expect(game.researchLevel('storage'), 1);
      expect(game.oilStorageCapacity, 1725);
      expect(game.gasStorageCapacity, 6900);
      game.advanceDay();
      expect(game.researchLevel('storage'), 1);
      expect(
          game.state.ledger
              .where((e) => e.title.startsWith('Research completed')),
          hasLength(1));
      _loadable(game);
    });

    test('cancel does not refund or erase previously completed technology', () {
      final game = _funded();
      game.hireEmployee(EmployeeRole.engineer);
      game.state.researchLevels['production'] = 1;
      final cash = game.state.cash;
      expect(game.researchCost('production'), 72000);
      expect(game.researchDuration('production'), 3);
      game.startResearch('production');
      expect(game.cancelResearch().success, isTrue);
      expect(game.state.cash, cash - 72000);
      expect(game.researchLevel('production'), 1);
      expect(game.state.researchProject, isNull);
      _rejected(game, game.cancelResearch);
      _loadable(game);
    });

    test('all six technologies can reach level three through staffed shifts',
        () {
      final game = _funded();
      game.hireEmployee(EmployeeRole.engineer);
      for (final technology in TycoonCatalog.research) {
        for (var level = 1; level <= 3; level++) {
          expect(game.startResearch(technology.id).success, isTrue);
          for (var shift = 0; shift < level + 1; shift++) {
            expect(game.advanceDay().success, isTrue);
            _loadable(game);
          }
          expect(game.researchLevel(technology.id), level);
        }
        expect(game.researchCost(technology.id), 0);
        expect(game.researchDuration(technology.id), 0);
        _rejected(game, () => game.startResearch(technology.id));
      }
      expect(game.state.researchLevels.values, everyElement(3));
    });

    test(
        'research bonuses affect production, transport, repairs and development',
        () {
      final baseline = _funded();
      baseline.hireEmployee(EmployeeRole.engineer);
      final improved = GameEngine(GameState.fromJson(_save(baseline)));
      improved.state.researchLevels.addAll({
        'production': 1,
        'logistics': 1,
        'maintenance': 1,
        'drilling': 1,
      });
      expect(improved.transportCapacity, 550);
      expect(baseline.transportCapacity, 500);
      expect(improved.leaseDevelopmentCost('prairie'), 39900);
      expect(baseline.leaseDevelopmentCost('prairie'), 42000);
      final normal = baseline.advanceDay().report!;
      final enhanced = improved.advanceDay().report!;
      expect(enhanced.oilProduced, greaterThan(normal.oilProduced));
      expect(improved.assetRepairCost('asset_1'),
          lessThan(baseline.assetRepairCost('asset_1')));
      improved.buyAsset('drill_rig');
      baseline.buyAsset('drill_rig');
      expect(improved.leaseDevelopmentCost('prairie'),
          lessThan(baseline.leaseDevelopmentCost('prairie')));
      _loadable(improved);
    });

    test('maximum trading technology never permits instant commodity profit',
        () {
      final game = _funded();
      game.buyBusiness('refinery');
      game.upgradeBusiness('refinery');
      game.upgradeBusiness('refinery');
      game.state.researchLevels['trading'] = 3;
      for (var oil = 30; oil <= 160; oil++) {
        game.state.oilPrice = oil;
        expect(game.commoditySellPrice(Commodity.oil),
            lessThanOrEqualTo(game.commodityBuyPrice(Commodity.oil)));
      }
      for (var gas = 2; gas <= 20; gas++) {
        game.state.gasPrice = gas;
        expect(game.commoditySellPrice(Commodity.gas),
            lessThanOrEqualTo(game.commodityBuyPrice(Commodity.gas)));
      }
      final before = game.state.cash;
      game.tradeCommodity(Commodity.oil, 10, buy: true);
      game.tradeCommodity(Commodity.oil, 10, buy: false);
      expect(game.state.cash, lessThanOrEqualTo(before));
    });

    test(
        'selling an upgraded storage terminal cannot strand stored commodities',
        () {
      final game = _funded();
      game.state.researchLevels['storage'] = 3;
      game.buyAsset('storage_tank');
      final tank = game.state.assets.last;
      expect(game.oilStorageCapacity, 5800);
      game.state.oilInventory = 2200;
      _rejected(game, () => game.sellAsset(tank.id));
      game.state.oilInventory = 2175;
      expect(game.sellAsset(tank.id).success, isTrue);
      expect(game.oilStorageCapacity, 2175);
      _loadable(game);
    });

    test(
        'restructuring keeps learned technology but cancels projects and old bids',
        () {
      final game = _funded();
      game.hireEmployee(EmployeeRole.engineer);
      game.state.researchLevels['production'] = 2;
      game.startResearch('storage');
      final auction = game.state.auctions.first;
      game.bidAtAuction(auction.id, auction.spec.price);
      game.state.cash = -1;
      expect(game.restructureCompany().success, isTrue);
      expect(game.state.cash, 25000);
      expect(game.researchLevel('production'), 2);
      expect(game.state.researchProject, isNull);
      expect(game.auctionEscrow, 0);
      expect(game.state.auctions.every((a) => a.currentBid == 0), isTrue);
      expect(game.researchCanProgress, isFalse);
      _loadable(game);
    });
  });

  group('Expansion save boundaries', () {
    test(
        'an actual v1 company migrates without altering any old field except schema',
        () {
      final fixture = jsonDecode(
              File('test/fixtures/legacy_v1_company.json').readAsStringSync())
          as Map<String, dynamic>;
      final old = fixture['game'] as Map<String, dynamic>;
      final before = jsonEncode(old);
      final state = GameState.fromJson(old);
      final migrated = state.toJson();
      expect(jsonEncode(old), before);
      for (final key in old.keys.where((key) => key != 'schemaVersion')) {
        expect(migrated[key], old[key], reason: 'Preserve legacy $key');
      }
      expect(migrated['schemaVersion'], 2);
      expect(state.researchLevels, isEmpty);
      expect(state.researchProject, isNull);
      expect(state.auctions, hasLength(3));
      _loadable(GameEngine(state));
    });

    test('malformed research and auction state is rejected before restore', () {
      final game = _funded();
      final cases = <void Function(Map<String, dynamic>)>[
        (j) => j.remove('researchLevels'),
        (j) => j.remove('researchProject'),
        (j) => j['researchLevels'] = {'magic': 1},
        (j) => j['researchLevels'] = {'production': 4},
        (j) => j['researchLevels'] = {'production': 1.5},
        (j) => j['researchProject'] = {
              'researchId': 'storage',
              'targetLevel': 2,
              'remainingShifts': 2,
              'totalShifts': 3
            },
        (j) => (j['auctions'] as List).first['currentBid'] = -1,
        (j) => (j['auctions'] as List).first['condition'] = 101,
        (j) => (j['auctions'] as List).first['closingDay'] = 1,
        (j) => (j['auctions'] as List).first['playerLeading'] = true,
        (j) => (j['auctions'] as List).first['status'] = 'won',
        (j) => (j['auctions'] as List).first['catalogId'] = 'unknown',
        (j) => (j['auctions'] as List).add((j['auctions'] as List).first),
      ];
      for (var i = 0; i < cases.length; i++) {
        final json = _save(game);
        cases[i](json);
        expect(() => GameState.fromJson(json), throwsFormatException,
            reason: 'Invalid expansion case $i');
      }
      final lot = game.state.auctions.first;
      game.bidAtAuction(lot.id, lot.openingBid);
      final overfull = _save(game)..['cash'] = GameEngine.maximumCash;
      expect(() => GameState.fromJson(overfull), throwsFormatException);
    });

    test(
        'last career shifts settle existing auctions and refuse impossible research',
        () {
      final game = _funded();
      game.hireEmployee(EmployeeRole.engineer);
      game.state.day = 99998;
      game.state.contracts.clear();
      game.state.auctions
        ..clear()
        ..add(AssetAuction(
            id: 'last_auction',
            catalogId: 'pumpjack',
            condition: 70,
            closingDay: 100000,
            openingBid: 18000));
      game.state.priceHistory
        ..clear()
        ..add(PricePoint(
            game.state.day, game.state.oilPrice, game.state.gasPrice));
      expect(game.bidAtAuction('last_auction', 45000).success, isTrue);
      expect(game.startResearch('storage').success, isTrue);
      game.advanceDay();
      game.advanceDay();
      expect(game.state.day, 100000);
      expect(game.auctionEscrow, 0);
      expect(game.state.researchProject, isNull);
      expect(game.researchLevel('storage'), 1);
      expect(game.state.auctions.where((a) => a.status == AuctionStatus.open),
          isEmpty);
      _rejected(game, () => game.startResearch('production'));
      _rejected(game, game.advanceDay);
      _loadable(game);
    });
  });
}
