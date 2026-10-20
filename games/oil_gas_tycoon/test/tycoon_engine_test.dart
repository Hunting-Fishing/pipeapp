import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oil_gas_tycoon/src/tycoon_engine.dart';

String snapshot(GameEngine game) => jsonEncode(game.state.toJson());
Map<String, dynamic> save(GameEngine game) =>
    jsonDecode(snapshot(game)) as Map<String, dynamic>;

void expectFailureUnchanged(GameEngine game, ActionResult Function() action) {
  final before = snapshot(game);
  expect(action().success, isFalse);
  expect(snapshot(game), before, reason: 'A rejected command must be atomic.');
}

void expectLoadable(GameEngine game) {
  final restored = GameState.fromJson(save(game));
  expect(jsonEncode(restored.toJson()), snapshot(game));
  expect(game.state.oilInventory, inInclusiveRange(0, game.oilStorageCapacity));
  expect(game.state.gasInventory, inInclusiveRange(0, game.gasStorageCapacity));
}

GameEngine funded() {
  final game = GameEngine.newGame();
  game.state.cash = 2000000;
  // Test fixtures mark unrelated first-time rewards as claimed so economic
  // assertions compare only the command under test.
  game.state.completedObjectives.addAll([
    'first_shift',
    'first_trade',
    'second_lease',
    'team',
    'business',
    'contract',
    'million'
  ]);
  return game;
}

void main() {
  group('A playable company', () {
    test('starts with an assigned, staffed oil operation and a valid save', () {
      final game =
          GameEngine.newGame(companyName: 'North Star Energy', seed: 9);
      expect(game.state.cash, 150000);
      expect(game.state.day, 1);
      expect(game.state.leases.single.running, isTrue);
      expect(game.state.contracts.length, 3);
      expect(game.transportCapacity, 500);
      expect(game.dailyPayroll, 340);
      expectLoadable(game);
    });

    test('first shift produces stock; a sale earns spendable cash', () {
      final game = GameEngine.newGame();
      final result = game.advanceDay();
      expect(result.success, isTrue);
      expect(result.report!.oilProduced, greaterThan(0));
      expect(game.state.oilInventory, result.report!.oilProduced);
      expect(result.report!.revenue, 0,
          reason: 'Extracted inventory is not automatically sold.');
      expect(game.state.completedObjectives, contains('first_shift'));
      final before = game.state.cash;
      final quantity = game.state.oilInventory;
      final proceeds = quantity * game.commoditySellPrice(Commodity.oil);
      expect(game.tradeCommodity(Commodity.oil, quantity, buy: false).success,
          isTrue);
      expect(game.state.cash, before + proceeds + 5000);
      expect(game.state.oilInventory, 0);
      expectLoadable(game);
    });

    test('the same seed and commands replay identically after restoring', () {
      final first = GameEngine.newGame(seed: 42);
      first.advanceDay();
      final second = GameEngine(GameState.fromJson(save(first)));
      for (var i = 0; i < 12; i++) {
        for (final game in [first, second]) {
          if (game.state.oilInventory > 0) {
            game.tradeCommodity(Commodity.oil, game.state.oilInventory,
                buy: false);
          }
          game.advanceDay();
        }
        expect(snapshot(first), snapshot(second));
      }
    });

    test('milestone rewards cannot be collected by repeated commands', () {
      final game = GameEngine.newGame();
      expect(game.tradeCommodity(Commodity.oil, 1, buy: true).success, isTrue);
      final before = game.state.cash;
      for (var i = 0; i < 10; i++) {
        game.tradeCommodity(Commodity.oil, 1, buy: true);
      }
      expect(
          game.state.cash, before - 10 * game.commodityBuyPrice(Commodity.oil));
      expect(
          game.state.ledger
              .where((l) => l.title == 'Milestone: Make a trade')
              .length,
          1);
    });
  });

  group('Production, crews and equipment', () {
    test('no driver means no extraction and reserves are not consumed', () {
      final game = GameEngine.newGame();
      final reserves = game.state.leases.single.reserves;
      game.fireEmployee(game.state.employees
          .firstWhere((e) => e.role == EmployeeRole.driver)
          .id);
      final report = game.advanceDay().report!;
      expect(report.oilProduced, 0);
      expect(game.state.leases.single.reserves, reserves);
      expect(report.notes.join(' '), contains('transport'));
    });

    test(
        'full storage leaves underground reserves and machine condition intact',
        () {
      final game = GameEngine.newGame();
      game.state.oilInventory = game.oilStorageCapacity;
      final reserves = game.state.leases.single.reserves;
      final condition = game.state.assets.first.condition;
      final report = game.advanceDay().report!;
      expect(report.oilProduced, 0);
      expect(game.state.leases.single.reserves, reserves);
      expect(game.state.assets.first.condition, condition);
      expect(report.notes.join(' '), contains('storage'));
      expectLoadable(game);
    });

    test('transport capacity and remaining reserves each cap production', () {
      final game = GameEngine.newGame();
      game.state.assets.firstWhere((a) => a.catalogId == 'tanker').condition =
          21;
      expect(game.advanceDay().report!.oilProduced, lessThanOrEqualTo(105));
      final lease = game.state.leases.single;
      lease.reserves = 7;
      game.state.leaseReserves[lease.id] = 7;
      game.repairAsset(
          game.state.assets.firstWhere((a) => a.catalogId == 'tanker').id);
      expect(game.advanceDay().report!.oilProduced, 7);
      expect(lease.reserves, 0);
      expect(lease.running, isFalse);
      expectLoadable(game);
    });

    test('selling assigned equipment and firing operators pause affected sites',
        () {
      final game = funded();
      final lease = game.state.leases.single;
      final operator = lease.employeeId!;
      final asset = lease.assetId!;
      expect(game.fireEmployee(operator).success, isTrue);
      expect(lease.employeeId, isNull);
      expect(lease.running, isFalse);
      expect(game.sellAsset(asset).success, isTrue);
      expect(lease.assetId, isNull);
      expectLoadable(game);
    });

    test('a gas site needs development, a gas skid, and its own operator', () {
      final game = funded();
      expect(game.acquireLease('dry_creek').success, isTrue);
      expectFailureUnchanged(game, () => game.assignLease('dry_creek'));
      game.developLease('dry_creek');
      expectFailureUnchanged(
          game,
          () => game.assignLease('dry_creek',
              assetId: game.state.assets.first.id,
              employeeId: game.state.employees.first.id));
      game.buyAsset('gas_compressor');
      game.hireEmployee(EmployeeRole.operator);
      final asset = game.state.assets.last;
      final employee = game.state.employees.last;
      expect(
          game
              .assignLease('dry_creek',
                  assetId: asset.id, employeeId: employee.id)
              .success,
          isTrue);
      final report = game.advanceDay().report!;
      expect(report.oilProduced, greaterThan(0));
      expect(report.gasProduced, greaterThan(0));
      expectLoadable(game);
    });

    test('an operator or asset cannot be assigned to two leases', () {
      final game = funded();
      game.acquireLease('prairie');
      game.developLease('prairie');
      final cedar = game.state.leases.first;
      expectFailureUnchanged(
          game,
          () => game.assignLease('prairie',
              assetId: cedar.assetId, employeeId: cedar.employeeId));
      game.buyAsset('pumpjack');
      expectFailureUnchanged(
          game,
          () => game.assignLease('prairie',
              assetId: game.state.assets.last.id,
              employeeId: cedar.employeeId));
    });

    test('assignment validation fails atomically if only the person is invalid',
        () {
      final game = funded();
      game.buyAsset('pumpjack');
      expectFailureUnchanged(
          game,
          () => game.assignLease('cedar',
              assetId: game.state.assets.last.id,
              employeeId: game.state.employees
                  .firstWhere((e) => e.role == EmployeeRole.driver)
                  .id));
    });

    test('unstaffed spare fleets do not wear and best usable fleet is chosen',
        () {
      final game = funded();
      game.buyAsset('heavy_hauler');
      final heavy = game.state.assets.last;
      heavy.condition = 21;
      expect(game.transportCapacity, 500,
          reason: 'A worn heavy hauler must not displace a healthier tanker.');
      game.advanceDay();
      expect(heavy.condition, 21);
      expect(
          game.state.assets
              .firstWhere((a) => a.catalogId == 'tanker')
              .condition,
          98);
    });

    test('mechanic training lowers repair cost and reduces operating wear', () {
      final game = funded();
      game.hireEmployee(EmployeeRole.mechanic);
      final mechanic = game.state.employees.last;
      final pump = game.state.assets.first;
      pump.condition = 70;
      final initialRepair = game.assetRepairCost(pump.id);
      game.trainEmployee(mechanic.id);
      expect(game.assetRepairCost(pump.id), lessThan(initialRepair));
      game.advanceDay();
      expect(pump.condition, 69);
    });

    test('owned drilling rig lowers lease development price by 35%', () {
      final game = funded();
      final original = game.leaseDevelopmentCost('mesa');
      game.buyAsset('drill_rig');
      expect(game.leaseDevelopmentCost('mesa'), (original * .65).ceil());
    });
  });

  group('Trading and company finances', () {
    test('asset and business round trips always lose resale spread', () {
      final game = funded();
      for (final spec in TycoonCatalog.assets) {
        final cash = game.state.cash;
        expect(game.buyAsset(spec.id).success, isTrue);
        expect(game.sellAsset(game.state.assets.last.id).success, isTrue);
        expect(game.state.cash, lessThan(cash));
      }
      for (final spec in TycoonCatalog.businesses) {
        final cash = game.state.cash;
        expect(game.buyBusiness(spec.id).success, isTrue);
        expect(game.sellBusiness(spec.id).success, isTrue);
        expect(game.state.cash, lessThan(cash));
      }
    });

    test('commodity bid stays below ask even with a level-three refinery', () {
      final game = funded();
      game.buyBusiness('refinery');
      game.upgradeBusiness('refinery');
      game.upgradeBusiness('refinery');
      for (final commodity in Commodity.values) {
        final before = game.state.cash;
        expect(game.commoditySellPrice(commodity),
            lessThan(game.commodityBuyPrice(commodity)));
        game.tradeCommodity(commodity, 100, buy: true);
        game.tradeCommodity(commodity, 100, buy: false);
        expect(game.state.cash, lessThan(before));
      }
    });

    test(
        'lease sale releases resources but reacquisition never replenishes oil',
        () {
      final game = funded();
      game.advanceDay();
      final lease = game.state.leases.single;
      final reserves = lease.reserves;
      final originalCash = game.state.cash;
      final sale = game.leaseSaleValue(lease.id);
      expect(game.sellLease(lease.id).success, isTrue);
      expect(game.state.cash, originalCash + sale);
      expect(game.state.assets.length, 2);
      expect(game.state.employees.length, 2);
      expect(game.acquireLease('cedar').success, isTrue);
      expect(game.state.leases.single.reserves, reserves);
      expect(game.state.leases.single.developed, isFalse);
      expect(game.state.cash, lessThan(originalCash));
      expectLoadable(game);
    });

    test(
        'depleted leased rights can be sold, but not reacquired with new reserves',
        () {
      final game = funded();
      game.state.leases.single.reserves = 0;
      game.state.leaseReserves['cedar'] = 0;
      game.sellLease('cedar');
      expectFailureUnchanged(game, () => game.acquireLease('cedar'));
      expectLoadable(game);
    });

    test('selling storage is blocked if owned stock would no longer fit', () {
      final game = funded();
      game.buyAsset('storage_tank');
      final terminal = game.state.assets.last;
      game.state.oilInventory = 2000;
      expectFailureUnchanged(game, () => game.sellAsset(terminal.id));
      game.tradeCommodity(Commodity.oil, 500, buy: false);
      expect(game.sellAsset(terminal.id).success, isTrue);
      expectLoadable(game);
    });

    test('loan draws do not create net worth and interest settles once per day',
        () {
      final game = funded();
      final worth = game.netWorth;
      final amount = 50000;
      expect(game.borrow(amount).success, isTrue);
      expect(game.netWorth, worth);
      expect(game.dailyInterest, 100);
      final before = game.state.cash;
      final expenses =
          game.dailyPayroll + game.dailyUpkeep + game.dailyInterest;
      expect(game.advanceDay().report!.expenses, expenses);
      expect(game.state.cash, before - expenses);
      expect(game.repayLoan(amount).success, isTrue);
      expect(game.state.debt, 0);
      expect(game.dailyInterest, 0);
    });

    test('upgraded businesses settle operating income and costs exactly once',
        () {
      final game = funded();
      game.buyBusiness('parts_yard');
      game.upgradeBusiness('parts_yard');
      final before = game.state.cash;
      final expenses = game.dailyPayroll + game.dailyUpkeep;
      final report = game.advanceDay().report!;
      expect(report.revenue, 3400);
      expect(report.expenses, expenses);
      expect(game.state.cash, before + 3400 - expenses);
    });

    test('negative, zero, overdrawn, and invalid-ID actions change nothing',
        () {
      final game = GameEngine.newGame();
      for (final amount in [-100, 0, 1000001]) {
        expectFailureUnchanged(
            game, () => game.tradeCommodity(Commodity.oil, amount, buy: true));
        expectFailureUnchanged(
            game, () => game.tradeCommodity(Commodity.gas, amount, buy: false));
      }
      expectFailureUnchanged(game, () => game.borrow(-1));
      expectFailureUnchanged(game, () => game.borrow(game.availableLoan + 1));
      expectFailureUnchanged(game, () => game.repayLoan(1));
      expectFailureUnchanged(game, () => game.acquireLease('unknown'));
      expectFailureUnchanged(game, () => game.acquireLease('cedar'));
      expectFailureUnchanged(game, () => game.buyAsset('unknown'));
      expectFailureUnchanged(game, () => game.repairAsset('unknown'));
      expectFailureUnchanged(game, () => game.sellAsset('unknown'));
      expectFailureUnchanged(game, () => game.buyBusiness('unknown'));
      expectFailureUnchanged(game, () => game.trainEmployee('unknown'));
      expectFailureUnchanged(
          game, () => game.tradeCommodity(Commodity.oil, 1, buy: false));
    });
  });

  group('Supply contracts', () {
    test('delivery consumes exact stock and returns the deposit once', () {
      final game = funded();
      final contract = game.state.contracts.first;
      final before = game.state.cash;
      expect(game.acceptContract(contract.id).success, isTrue);
      expect(game.state.cash, before - contract.deposit);
      expectFailureUnchanged(game, () => game.acceptContract(contract.id));
      expectFailureUnchanged(game, () => game.deliverContract(contract.id));
      game.tradeCommodity(contract.commodity, contract.quantity, buy: true);
      final deliveryCash = game.state.cash;
      expect(game.deliverContract(contract.id).success, isTrue);
      expect(
          game.state.cash, deliveryCash + contract.payout + contract.deposit);
      expect(game.state.oilInventory, 0);
      expect(game.state.contractsCompleted, 1);
      expectFailureUnchanged(game, () => game.deliverContract(contract.id));
      expectLoadable(game);
    });

    test(
        'the deadline is inclusive and missed deposits are forfeited only once',
        () {
      final game = funded();
      final contract = game.state.contracts.first;
      game.acceptContract(contract.id);
      while (game.state.day < contract.deadlineDay) {
        game.advanceDay();
      }
      expect(contract.status, ContractStatus.active);
      game.advanceDay();
      expect(contract.status, ContractStatus.failed);
      expect(game.state.lastReport!.notes.join(' '), contains('forfeited'));
      game.advanceDay();
      expect(
          game.state.lastReport!.notes.join(' '), isNot(contains('forfeited')));
      expect(
          game.state.ledger
              .where((l) => l.title.startsWith('Forfeited contract deposit'))
              .length,
          1);
      expectFailureUnchanged(game, () => game.deliverContract(contract.id));
      expectLoadable(game);
    });
  });

  group('Persistence validation and recoverability', () {
    test(
        'invalid version, nonfinite, fractional, negative, and overflow fields are rejected',
        () {
      final game = GameEngine.newGame();
      for (final entry in [
        MapEntry('schemaVersion', 2),
        MapEntry('cash', double.nan),
        MapEntry('debt', double.infinity),
        MapEntry('day', 1.5),
        MapEntry('oilInventory', -1),
        MapEntry('gasInventory', 10000001),
        MapEntry('companyName', ''),
        MapEntry('careerComplete', true),
      ]) {
        final data = save(game)..[entry.key] = entry.value;
        expect(() => GameState.fromJson(data), throwsFormatException,
            reason: entry.key);
      }
    });

    test('unknown assets, duplicate IDs and dangling assignments are rejected',
        () {
      final game = GameEngine.newGame();
      final unknown = save(game);
      (unknown['assets'] as List).first['catalogId'] = 'magic_money_machine';
      expect(() => GameState.fromJson(unknown), throwsFormatException);
      final duplicate = save(game);
      (duplicate['assets'] as List).add((duplicate['assets'] as List).first);
      expect(() => GameState.fromJson(duplicate), throwsFormatException);
      final dangling = save(game);
      (dangling['leases'] as List).first['employeeId'] = 'does_not_exist';
      expect(() => GameState.fromJson(dangling), throwsFormatException);
      final reserves = save(game);
      (reserves['leaseReserves'] as Map)['cedar'] = 1;
      expect(() => GameState.fromJson(reserves), throwsFormatException);
    });

    test(
        'backdated or inconsistent price history and active contracts are rejected',
        () {
      final game = GameEngine.newGame();
      final prices = save(game);
      (prices['priceHistory'] as List).first['oil'] = 85;
      expect(() => GameState.fromJson(prices), throwsFormatException);
      final contracts = save(game);
      (contracts['contracts'] as List).first['deadlineDay'] = 90;
      expect(() => GameState.fromJson(contracts), throwsFormatException);
    });

    test(
        'an imported overlapping or maximum counter never creates duplicate IDs',
        () {
      for (final nextId in [1, 100000000]) {
        final data = save(GameEngine.newGame())..['nextId'] = nextId;
        final game = GameEngine(GameState.fromJson(data));
        expect(game.buyAsset('pumpjack').success, isTrue);
        expect(game.hireEmployee(EmployeeRole.operator).success, isTrue);
        expectLoadable(game);
      }
    });

    test(
        'a full imported treasury rejects manual credits atomically and caps automatic income visibly',
        () {
      final game = funded();
      game.buyBusiness('parts_yard');
      final contract = game.state.contracts.first;
      game.acceptContract(contract.id);
      game.tradeCommodity(Commodity.oil, contract.quantity, buy: true);
      game.state.cash = GameEngine.maximumCash;
      expectFailureUnchanged(
          game, () => game.sellAsset(game.state.assets.first.id));
      expectFailureUnchanged(game, () => game.sellLease('cedar'));
      expectFailureUnchanged(game, () => game.sellBusiness('parts_yard'));
      expectFailureUnchanged(
          game, () => game.tradeCommodity(Commodity.oil, 1, buy: false));
      expectFailureUnchanged(game, () => game.deliverContract(contract.id));
      expectFailureUnchanged(game, () => game.borrow(1));
      final report = game.advanceDay().report!;
      expect(game.state.cash, GameEngine.maximumCash);
      expect(report.revenue, report.expenses);
      expect(report.notes.join(' '), contains('Treasury limit'));
      expectLoadable(game);
    });

    test(
        'maximum imported lifetime statistics saturate without invalidating the save',
        () {
      final game = funded();
      game.state.totalTrades = 100000000;
      game.state.totalRevenue = 1000000000000;
      game.state.totalProducedOil = 1000000000000;
      game.tradeCommodity(Commodity.oil, 1, buy: true);
      game.tradeCommodity(Commodity.oil, 1, buy: false);
      game.advanceDay();
      expect(game.state.totalTrades, 100000000);
      expect(game.state.totalRevenue, 1000000000000);
      expect(game.state.totalProducedOil, 1000000000000);
      expectLoadable(game);
    });

    test(
        'insolvency freezes shifts and offers explicit recoverable restructuring',
        () {
      final game = funded();
      game.advanceDay();
      game.buyBusiness('refinery');
      game.borrow(50000);
      game.state.cash = -100;
      final day = game.state.day;
      final goals = Set<String>.from(game.state.completedObjectives);
      expectFailureUnchanged(game, game.advanceDay);
      expect(game.restructureCompany().success, isTrue);
      expect(game.state.cash, 25000);
      expect(game.state.debt, 0);
      expect(game.state.businesses, isEmpty);
      expect(game.state.leases.length, 1);
      expect(game.state.assets.length, 2);
      expect(game.state.employees.length, 2);
      expect(game.state.day, day);
      expect(game.state.completedObjectives, goals);
      expect(game.advanceDay().report!.oilProduced, greaterThan(0));
      expectFailureUnchanged(game, game.restructureCompany);
      expectLoadable(game);
    });

    test('collection and career caps cannot create an unloadable game', () {
      final game = funded();
      game.state.day = 100000;
      game.state.contracts.clear();
      game.state.priceHistory
        ..clear()
        ..add(PricePoint(100000, game.state.oilPrice, game.state.gasPrice));
      expectFailureUnchanged(game, game.advanceDay);
      expectLoadable(game);
    });

    test('market and transaction histories stay bounded during continued play',
        () {
      final game = funded();
      for (var day = 0; day < 50; day++) {
        for (final asset in game.state.assets) {
          if (asset.condition < 80) game.repairAsset(asset.id);
        }
        if (game.state.oilInventory > 0) {
          game.tradeCommodity(Commodity.oil, game.state.oilInventory,
              buy: false);
        }
        game.advanceDay();
        expectLoadable(game);
      }
      expect(game.state.priceHistory.length, 30);
      expect(game.state.ledger.length, lessThanOrEqualTo(150));
      expect(game.state.contracts.length, lessThanOrEqualTo(30));
    });
  });

  test(
      'three seeded careers reach Tycoon through ordinary growth without injected money',
      () {
    for (final seed in [1, 366, 2147483645]) {
      final game = GameEngine.newGame(seed: seed);
      final state = game.state;
      for (var shift = 0; shift < 800; shift++) {
        expect(game.isInsolvent, isFalse,
            reason: 'Seed $seed, day ${state.day}');
        if (state.oilInventory > 0) {
          expect(
              game
                  .tradeCommodity(Commodity.oil, state.oilInventory, buy: false)
                  .success,
              isTrue);
        }
        if (state.gasInventory > 0) {
          expect(
              game
                  .tradeCommodity(Commodity.gas, state.gasInventory, buy: false)
                  .success,
              isTrue);
        }
        for (final spec in TycoonCatalog.businesses) {
          if (!state.businesses.any((b) => b.id == spec.id) &&
              state.cash > spec.price + 20000) {
            expect(game.buyBusiness(spec.id).success, isTrue);
          }
        }
        for (final business in state.businesses.toList()) {
          if (business.level < 3 &&
              state.cash > game.businessUpgradeCost(business.id) + 20000) {
            expect(game.upgradeBusiness(business.id).success, isTrue);
          }
        }
        if (!state.employees.any((e) => e.role == EmployeeRole.mechanic) &&
            state.cash > 10000) {
          game.hireEmployee(EmployeeRole.mechanic);
        }
        for (final asset in state.assets.toList()) {
          if (asset.condition < 65 &&
              state.cash > game.assetRepairCost(asset.id) + 15000) {
            expect(game.repairAsset(asset.id).success, isTrue);
          }
        }
        for (final spec in TycoonCatalog.leases) {
          if (!state.leases.any((l) => l.id == spec.id) &&
              state.cash >
                  game.leasePurchaseCost(spec.id) +
                      game.leaseDevelopmentCost(spec.id) +
                      120000) {
            expect(game.acquireLease(spec.id).success, isTrue);
            expect(game.developLease(spec.id).success, isTrue);
            expect(
                game
                    .buyAsset(spec.commodity == Commodity.oil
                        ? 'heavy_pumpjack'
                        : 'gas_compressor')
                    .success,
                isTrue);
            final asset = state.assets.last;
            expect(game.hireEmployee(EmployeeRole.operator).success, isTrue);
            expect(
                game
                    .assignLease(spec.id,
                        assetId: asset.id, employeeId: state.employees.last.id)
                    .success,
                isTrue);
          }
        }
        if (state.leases.length >= 3 &&
            !state.assets.any((a) => a.catalogId == 'heavy_hauler') &&
            state.cash > 100000) {
          game.buyAsset('heavy_hauler');
          game.hireEmployee(EmployeeRole.driver);
        }
        expect(game.advanceDay().success, isTrue);
        expect(
            state.oilInventory, inInclusiveRange(0, game.oilStorageCapacity));
        expect(
            state.gasInventory, inInclusiveRange(0, game.gasStorageCapacity));
        if (shift % 25 == 0) expectLoadable(game);
      }
      expect(state.careerComplete, isTrue,
          reason: 'Seed $seed must have a reachable end goal.');
      expect(state.leases.length, TycoonCatalog.leases.length);
      expect(state.businesses.length, TycoonCatalog.businesses.length);
      expect(state.businesses.every((b) => b.level == 3), isTrue);
      expect(state.restructures, 0);
      expect(state.totalProducedOil, greaterThan(0));
      expect(state.totalProducedGas, greaterThan(0));
      expectLoadable(game);
    }
  });
}
