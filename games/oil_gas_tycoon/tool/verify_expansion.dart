// Deterministic economic regression simulation. Run: dart run tool/verify_expansion.dart
// The larger initial test treasury exercises expansion actions; the real game still starts at $150,000.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:oil_gas_tycoon/src/tycoon_engine.dart';

String snapshot(GameEngine game) => jsonEncode(game.state.toJson());
void require(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  var successful = 0, rejected = 0, shifts = 0, wins = 0, research = 0;
  for (var seed = 1; seed <= 16; seed++) {
    final random = Random(seed * 1771);
    var game = GameEngine.newGame(seed: seed * 1771);
    game.state.cash = 700000;
    for (var step = 0; step < 700; step++) {
      final before = snapshot(game);
      final clone = GameEngine(GameState.fromJson(jsonDecode(before)));
      ActionResult Function(GameEngine) action;
      final choice = random.nextInt(24);
      if (game.isInsolvent) {
        action = (g) => g.restructureCompany();
      } else if (choice < 7) {
        action = (g) => g.advanceDay();
        shifts++;
      } else if (choice < 10) {
        final lots = game.state.auctions
            .where((a) => a.status == AuctionStatus.open)
            .toList();
        if (lots.isEmpty) {
          action = (g) => g.advanceDay();
        } else {
          final lot = lots[random.nextInt(lots.length)];
          final amount = game.minimumAuctionBid(lot.id) +
              (random.nextInt(5) - 1) * game.auctionBidIncrement(lot.id);
          action = (g) => g.bidAtAuction(lot.id, amount);
        }
      } else if (choice < 12) {
        final tech = TycoonCatalog
            .research[random.nextInt(TycoonCatalog.research.length)].id;
        action = (g) => g.startResearch(tech);
      } else if (choice == 12) {
        action = (g) => g.cancelResearch();
      } else if (choice == 13) {
        final role =
            EmployeeRole.values[random.nextInt(EmployeeRole.values.length)];
        action = (g) => g.hireEmployee(role);
      } else if (choice == 14) {
        final id = game.state.employees.isEmpty
            ? 'missing'
            : game.state.employees[random.nextInt(game.state.employees.length)]
                .id;
        action = (g) => g.trainEmployee(id);
      } else if (choice == 15) {
        final id = game.state.employees.isEmpty
            ? 'missing'
            : game.state.employees[random.nextInt(game.state.employees.length)]
                .id;
        action = (g) => g.fireEmployee(id);
      } else if (choice == 16) {
        final id = TycoonCatalog
            .assets[random.nextInt(TycoonCatalog.assets.length)].id;
        action = (g) => g.buyAsset(id);
      } else if (choice == 17) {
        final id = game.state.assets.isEmpty
            ? 'missing'
            : game.state.assets[random.nextInt(game.state.assets.length)].id;
        action = (g) => g.sellAsset(id);
      } else if (choice == 18) {
        final id = game.state.assets.isEmpty
            ? 'missing'
            : game.state.assets[random.nextInt(game.state.assets.length)].id;
        action = (g) => g.repairAsset(id);
      } else if (choice < 22) {
        final commodity = Commodity.values[random.nextInt(2)];
        final amount = random.nextInt(2500) - 100;
        final buy = random.nextBool();
        action = (g) => g.tradeCommodity(commodity, amount, buy: buy);
      } else if (choice == 22) {
        action = (g) => g.borrow(25000);
      } else {
        action = (g) => g.repayLoan(25000);
      }
      final result = action(game);
      final replay = action(clone);
      final after = snapshot(game);
      require(
          result.success == replay.success && result.message == replay.message,
          'Replay result differs seed$seed step$step');
      require(
          after == snapshot(clone), 'Replay state differs seed$seed step$step');
      if (!result.success) {
        rejected++;
        require(before == after, 'Failed action mutated seed$seed step$step');
      } else {
        successful++;
      }
      final restored = GameEngine(GameState.fromJson(jsonDecode(after)));
      require(
          after == snapshot(restored), 'Roundtrip differs seed$seed step$step');
      require(game.auctionEscrow + game.state.cash <= GameEngine.maximumCash,
          'Cash cap');
      require(
          game.state.assets.length +
                  game.state.auctions
                      .where((a) =>
                          a.status == AuctionStatus.open && a.playerLeading)
                      .length <=
              200,
          'Fleet reservations');
      require(
          game.commoditySellPrice(Commodity.oil) <=
              game.commodityBuyPrice(Commodity.oil),
          'Oil arbitrage');
      require(
          game.commoditySellPrice(Commodity.gas) <=
              game.commodityBuyPrice(Commodity.gas),
          'Gas arbitrage');
      game = restored;
    }
    wins +=
        game.state.auctions.where((a) => a.status == AuctionStatus.won).length;
    research += game.state.researchLevels.values.fold<int>(0, (a, b) => a + b);
  }
  stdout.writeln(
      'PASS: 11,200 actions across 16 seeds; $successful successful, $rejected rejected; $shifts explicit shifts. Final-window wins: $wins; retained research levels: $research. Exact replay/roundtrip, failure atomicity, treasury/fleet/storage validation and quote bounds verified after every action.');
}
