import 'dart:math' as math;

/// All amounts are fictional whole game dollars. No network or payment code.
enum Commodity { oil, gas }

enum EmployeeRole { operator, driver, engineer, mechanic }

enum ContractStatus { available, active, completed, failed }

class AssetSpec {
  const AssetSpec(this.id, this.name, this.description, this.price, this.upkeep,
      this.category,
      {this.commodity,
      this.production = 0,
      this.transport = 0,
      this.oilStorage = 0,
      this.gasStorage = 0});
  final String id, name, description, category;
  final int price, upkeep, production, transport, oilStorage, gasStorage;
  final Commodity? commodity;
}

class LeaseSpec {
  const LeaseSpec(this.id, this.name, this.region, this.commodity, this.price,
      this.developmentCost, this.dailyOutput, this.reserves);
  final String id, name, region;
  final Commodity commodity;
  final int price, developmentCost, dailyOutput, reserves;
}

class BusinessSpec {
  const BusinessSpec(this.id, this.name, this.description, this.price,
      this.dailyIncome, this.upkeep);
  final String id, name, description;
  final int price, dailyIncome, upkeep;
}

abstract final class TycoonCatalog {
  static const assets = <AssetSpec>[
    AssetSpec('pumpjack', 'Prairie pumpjack',
        'Produces up to 180 bbl each shift.', 45000, 180, 'equipment',
        commodity: Commodity.oil, production: 180),
    AssetSpec('gas_compressor', 'Gas gathering skid',
        'Produces up to 1,000 Mcf each shift.', 52000, 200, 'equipment',
        commodity: Commodity.gas, production: 1000),
    AssetSpec('heavy_pumpjack', 'High-output pumpjack',
        'Produces up to 450 bbl each shift.', 105000, 350, 'equipment',
        commodity: Commodity.oil, production: 450),
    AssetSpec(
        'drill_rig',
        'Drilling rig',
        'An owned rig reduces new lease development costs by 35%.',
        120000,
        300,
        'equipment'),
    AssetSpec(
        'tanker',
        'Field haul fleet',
        'Oil tankers and gas transport; one driver moves 500 haul units.',
        35000,
        140,
        'vehicle',
        transport: 500),
    AssetSpec(
        'heavy_hauler',
        'Heavy haul fleet',
        'One driver moves 1,200 haul units; 10 Mcf uses one haul unit.',
        80000,
        260,
        'vehicle',
        transport: 1200),
    AssetSpec('service_truck', 'Workshop truck',
        'Cuts repairs by 10% and slows equipment wear.', 28000, 90, 'vehicle'),
    AssetSpec(
        'storage_tank',
        'Storage terminal',
        'Adds space for 2,500 bbl of oil and 10,000 Mcf of gas.',
        45000,
        80,
        'storage',
        oilStorage: 2500,
        gasStorage: 10000),
  ];
  static const leases = <LeaseSpec>[
    LeaseSpec('cedar', 'Cedar Creek', 'Alberta foothills', Commodity.oil, 55000,
        30000, 160, 24000),
    LeaseSpec('prairie', 'Prairie Bend', 'Saskatchewan plains', Commodity.oil,
        80000, 42000, 220, 42000),
    LeaseSpec('dry_creek', 'Dry Creek Gas', 'Western basin', Commodity.gas,
        60000, 36000, 1100, 220000),
    LeaseSpec('mesa', 'Red Mesa', 'Permian basin', Commodity.oil, 160000, 65000,
        420, 85000),
    LeaseSpec('pines', 'Pine Ridge Gas', 'Northern basin', Commodity.gas,
        125000, 55000, 1500, 380000),
    LeaseSpec('copper', 'Copper Flats', 'High desert', Commodity.oil, 210000,
        85000, 480, 120000),
    LeaseSpec('frontier', 'Frontier Deep', 'Continental shelf', Commodity.oil,
        350000, 120000, 650, 200000),
    LeaseSpec('summit', 'Summit Gas', 'Rocky Mountain basin', Commodity.gas,
        260000, 95000, 2000, 600000),
  ];
  static const businesses = <BusinessSpec>[
    BusinessSpec(
        'refinery',
        'Refinery',
        'Earns daily income and improves oil sale prices by 1% per level.',
        240000,
        3000,
        650),
    BusinessSpec(
        'logistics',
        'Logistics company',
        'Earns daily income and adds 250 staffed haul units per level.',
        130000,
        2100,
        450),
    BusinessSpec(
        'parts_yard',
        'Parts & repair yard',
        'Earns daily income and cuts repair prices by 10% per level.',
        95000,
        1700,
        350),
  ];
  static AssetSpec asset(String id) => assets.firstWhere((v) => v.id == id,
      orElse: () => throw FormatException('Unknown asset: $id'));
  static LeaseSpec lease(String id) => leases.firstWhere((v) => v.id == id,
      orElse: () => throw FormatException('Unknown lease: $id'));
  static BusinessSpec business(String id) =>
      businesses.firstWhere((v) => v.id == id,
          orElse: () => throw FormatException('Unknown business: $id'));
}

class OwnedAsset {
  OwnedAsset({required this.id, required this.catalogId, this.condition = 100});
  final String id, catalogId;
  int condition;
  AssetSpec get spec => TycoonCatalog.asset(catalogId);
  Map<String, dynamic> toJson() =>
      {'id': id, 'catalogId': catalogId, 'condition': condition};
}

class OwnedLease {
  OwnedLease(
      {required this.id,
      required this.reserves,
      this.developed = false,
      this.running = false,
      this.assetId,
      this.employeeId});
  final String id;
  int reserves;
  bool developed, running;
  String? assetId, employeeId;
  LeaseSpec get spec => TycoonCatalog.lease(id);
  Map<String, dynamic> toJson() => {
        'id': id,
        'reserves': reserves,
        'developed': developed,
        'running': running,
        'assetId': assetId,
        'employeeId': employeeId
      };
}

class Employee {
  Employee(
      {required this.id,
      required this.name,
      required this.role,
      this.level = 1});
  final String id, name;
  final EmployeeRole role;
  int level;
  int get salary =>
      (switch (role) {
        EmployeeRole.operator => 180,
        EmployeeRole.driver => 160,
        EmployeeRole.engineer => 280,
        EmployeeRole.mechanic => 220,
      }) +
      (level - 1) * 45;
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'role': role.name, 'level': level};
}

class OwnedBusiness {
  OwnedBusiness({required this.id, this.level = 1});
  final String id;
  int level;
  BusinessSpec get spec => TycoonCatalog.business(id);
  Map<String, dynamic> toJson() => {'id': id, 'level': level};
}

class GameContract {
  GameContract(
      {required this.id,
      required this.title,
      required this.commodity,
      required this.quantity,
      required this.unitPrice,
      required this.deadlineDay,
      required this.deposit,
      this.status = ContractStatus.available});
  final String id, title;
  final Commodity commodity;
  final int quantity, unitPrice, deadlineDay, deposit;
  ContractStatus status;
  int get payout => quantity * unitPrice;
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'commodity': commodity.name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'deadlineDay': deadlineDay,
        'deposit': deposit,
        'status': status.name
      };
}

class LedgerEntry {
  LedgerEntry(this.day, this.title, this.amount);
  final int day, amount;
  final String title;
  Map<String, dynamic> toJson() =>
      {'day': day, 'title': title, 'amount': amount};
}

class DayReport {
  DayReport(
      {required this.day,
      required this.oilProduced,
      required this.gasProduced,
      required this.revenue,
      required this.expenses,
      required this.event,
      required this.notes});
  final int day, oilProduced, gasProduced, revenue, expenses;
  final String event;
  final List<String> notes;
  int get netIncome => revenue - expenses;
  Map<String, dynamic> toJson() => {
        'day': day,
        'oilProduced': oilProduced,
        'gasProduced': gasProduced,
        'revenue': revenue,
        'expenses': expenses,
        'event': event,
        'notes': notes
      };
}

class ObjectiveProgress {
  const ObjectiveProgress(this.id, this.title, this.description, this.current,
      this.target, this.reward, this.complete);
  final String id, title, description;
  final int current, target, reward;
  final bool complete;
}

class PricePoint {
  const PricePoint(this.day, this.oil, this.gas);
  final int day, oil, gas;
  Map<String, dynamic> toJson() => {'day': day, 'oil': oil, 'gas': gas};
}

class ActionResult {
  const ActionResult(this.success, this.message, {this.report});
  final bool success;
  final String message;
  final DayReport? report;
}

class GameState {
  GameState._(
      {required this.companyName,
      required this.day,
      required this.cash,
      required this.debt,
      required this.oilPrice,
      required this.gasPrice,
      required this.oilInventory,
      required this.gasInventory,
      required this.seed,
      required this.nextId,
      required this.assets,
      required this.leases,
      required this.employees,
      required this.businesses,
      required this.contracts,
      required this.ledger,
      required this.completedObjectives,
      required this.priceHistory,
      required this.leaseReserves,
      this.lastReport,
      this.careerComplete = false,
      this.totalRevenue = 0,
      this.totalProducedOil = 0,
      this.totalProducedGas = 0,
      this.totalTrades = 0,
      this.contractsCompleted = 0,
      this.restructures = 0});
  static const schemaVersion = 1;
  String companyName;
  int day,
      cash,
      debt,
      oilPrice,
      gasPrice,
      oilInventory,
      gasInventory,
      seed,
      nextId;
  int totalRevenue,
      totalProducedOil,
      totalProducedGas,
      totalTrades,
      contractsCompleted,
      restructures;
  final List<OwnedAsset> assets;
  final List<OwnedLease> leases;
  final List<Employee> employees;
  final List<OwnedBusiness> businesses;
  final List<GameContract> contracts;
  final List<LedgerEntry> ledger;
  final Set<String> completedObjectives;
  final List<PricePoint> priceHistory;

  /// Remaining underground resources survive sale and reacquisition.
  final Map<String, int> leaseReserves;
  DayReport? lastReport;
  bool careerComplete;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'companyName': companyName,
        'day': day,
        'cash': cash,
        'debt': debt,
        'oilPrice': oilPrice,
        'gasPrice': gasPrice,
        'oilInventory': oilInventory,
        'gasInventory': gasInventory,
        'seed': seed,
        'nextId': nextId,
        'assets': assets.map((v) => v.toJson()).toList(),
        'leases': leases.map((v) => v.toJson()).toList(),
        'employees': employees.map((v) => v.toJson()).toList(),
        'businesses': businesses.map((v) => v.toJson()).toList(),
        'contracts': contracts.map((v) => v.toJson()).toList(),
        'ledger': ledger.map((v) => v.toJson()).toList(),
        'completedObjectives': completedObjectives.toList(),
        'priceHistory': priceHistory.map((v) => v.toJson()).toList(),
        'leaseReserves': Map<String, int>.from(leaseReserves),
        'lastReport': lastReport?.toJson(),
        'careerComplete': careerComplete,
        'totalRevenue': totalRevenue,
        'totalProducedOil': totalProducedOil,
        'totalProducedGas': totalProducedGas,
        'totalTrades': totalTrades,
        'contractsCompleted': contractsCompleted,
        'restructures': restructures,
      };

  /// Strictly validates imported or persisted saves before replacing live state.
  factory GameState.fromJson(Map<String, dynamic> json) {
    int number(Map<String, dynamic> m, String key, int min, int max) {
      final value = m[key];
      if (value is! int || value < min || value > max) {
        throw FormatException('Invalid $key.');
      }
      return value;
    }

    String string(Map<String, dynamic> m, String key, {int max = 120}) {
      final value = m[key];
      if (value is! String ||
          value.trim().isEmpty ||
          value.length > max ||
          RegExp(r'[\x00-\x1F]').hasMatch(value)) {
        throw FormatException('Invalid $key.');
      }
      return value;
    }

    bool boolean(Map<String, dynamic> m, String key) {
      final value = m[key];
      if (value is! bool) throw FormatException('Invalid $key.');
      return value;
    }

    Map<String, dynamic> object(dynamic value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid save object.');
      }
      return value;
    }

    List<dynamic> list(String key, int max) {
      final value = json[key];
      if (value is! List || value.length > max) {
        throw FormatException('Invalid $key.');
      }
      return value;
    }

    String? optionalId(Map<String, dynamic> m, String key) =>
        m[key] == null ? null : string(m, key, max: 64);
    T parseEnum<T extends Enum>(
        List<T> values, Map<String, dynamic> m, String key) {
      final name = string(m, key, max: 32);
      return values.firstWhere((v) => v.name == name,
          orElse: () => throw FormatException('Invalid $key.'));
    }

    void unique(Iterable<String> ids) {
      final values = ids.toList();
      if (values.toSet().length != values.length ||
          values.any((v) => !RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(v))) {
        throw const FormatException('Invalid or duplicate entity IDs.');
      }
    }

    number(json, 'schemaVersion', schemaVersion, schemaVersion);
    final day = number(json, 'day', 1, 100000);
    final assets = list('assets', 200).map((v) {
      final m = object(v);
      final id = string(m, 'catalogId', max: 64);
      TycoonCatalog.asset(id);
      return OwnedAsset(
          id: string(m, 'id', max: 64),
          catalogId: id,
          condition: number(m, 'condition', 0, 100));
    }).toList();
    final employees = list('employees', 100).map((v) {
      final m = object(v);
      return Employee(
          id: string(m, 'id', max: 64),
          name: string(m, 'name', max: 60),
          role: parseEnum(EmployeeRole.values, m, 'role'),
          level: number(m, 'level', 1, 5));
    }).toList();
    final leases = list('leases', TycoonCatalog.leases.length).map((v) {
      final m = object(v);
      final id = string(m, 'id', max: 64);
      final spec = TycoonCatalog.lease(id);
      return OwnedLease(
          id: id,
          reserves: number(m, 'reserves', 0, spec.reserves),
          developed: boolean(m, 'developed'),
          running: boolean(m, 'running'),
          assetId: optionalId(m, 'assetId'),
          employeeId: optionalId(m, 'employeeId'));
    }).toList();
    final rawReserves = object(json['leaseReserves']);
    if (rawReserves.length > TycoonCatalog.leases.length) {
      throw const FormatException('Invalid lease reserve history.');
    }
    final leaseReserves = <String, int>{};
    for (final id in rawReserves.keys) {
      leaseReserves[id] =
          number(rawReserves, id, 0, TycoonCatalog.lease(id).reserves);
    }
    for (final lease in leases) {
      if (leaseReserves[lease.id] != lease.reserves) {
        throw const FormatException(
            'Lease reserve history does not match its remaining resources.');
      }
    }
    final businesses =
        list('businesses', TycoonCatalog.businesses.length).map((v) {
      final m = object(v);
      final id = string(m, 'id', max: 64);
      TycoonCatalog.business(id);
      return OwnedBusiness(id: id, level: number(m, 'level', 1, 3));
    }).toList();
    final contracts = list('contracts', 30).map((v) {
      final m = object(v);
      final contract = GameContract(
          id: string(m, 'id', max: 64),
          title: string(m, 'title'),
          commodity: parseEnum(Commodity.values, m, 'commodity'),
          quantity: number(m, 'quantity', 1, 20000),
          unitPrice: number(m, 'unitPrice', 1, 250),
          deadlineDay: number(m, 'deadlineDay', 1, 100014),
          deposit: number(m, 'deposit', 0, 1000000),
          status: parseEnum(ContractStatus.values, m, 'status'));
      if ((contract.status == ContractStatus.active ||
              contract.status == ContractStatus.available) &&
          (contract.deadlineDay < day || contract.deadlineDay > day + 14)) {
        throw const FormatException(
            'Contract deadline is outside the active window.');
      }
      return contract;
    }).toList();
    unique(assets.map((v) => v.id));
    unique(employees.map((v) => v.id));
    unique(leases.map((v) => v.id));
    unique(businesses.map((v) => v.id));
    unique(contracts.map((v) => v.id));
    final assignedAssets = <String>{};
    final assignedPeople = <String>{};
    for (final lease in leases) {
      if (!lease.developed &&
          (lease.running ||
              lease.assetId != null ||
              lease.employeeId != null)) {
        throw const FormatException(
            'Undeveloped lease has an active assignment.');
      }
      if (lease.assetId != null) {
        final asset = assets.where((v) => v.id == lease.assetId).firstOrNull;
        if (asset == null ||
            asset.spec.commodity != lease.spec.commodity ||
            !assignedAssets.add(asset.id)) {
          throw const FormatException('Invalid equipment assignment.');
        }
      }
      if (lease.employeeId != null) {
        final employee =
            employees.where((v) => v.id == lease.employeeId).firstOrNull;
        if (employee == null ||
            employee.role != EmployeeRole.operator ||
            !assignedPeople.add(employee.id)) {
          throw const FormatException('Invalid crew assignment.');
        }
      }
    }
    const objectiveIds = {
      'first_shift',
      'first_trade',
      'second_lease',
      'team',
      'business',
      'contract',
      'million',
      'tycoon'
    };
    final rawObjectives = list('completedObjectives', objectiveIds.length);
    if (rawObjectives.any((v) => v is! String || !objectiveIds.contains(v)) ||
        rawObjectives.toSet().length != rawObjectives.length) {
      throw const FormatException('Invalid objectives.');
    }
    final ledger = list('ledger', 150).map((v) {
      final m = object(v);
      return LedgerEntry(number(m, 'day', 1, day), string(m, 'title', max: 160),
          number(m, 'amount', -1000000000000, 1000000000000));
    }).toList();
    final history = list('priceHistory', 30).map((v) {
      final m = object(v);
      return PricePoint(number(m, 'day', 1, day), number(m, 'oil', 30, 160),
          number(m, 'gas', 2, 20));
    }).toList();
    if (history.isEmpty ||
        history.last.day != day ||
        history.last.oil != json['oilPrice'] ||
        history.last.gas != json['gasPrice']) {
      throw const FormatException('Invalid market history.');
    }
    for (var i = 1; i < history.length; i++) {
      if (history[i].day != history[i - 1].day + 1) {
        throw const FormatException('Market history is not sequential.');
      }
    }
    DayReport? report;
    if (json['lastReport'] != null) {
      final m = object(json['lastReport']);
      final notes = m['notes'];
      if (notes is! List ||
          notes.length > 30 ||
          notes.any((v) => v is! String || v.length > 250)) {
        throw const FormatException('Invalid report notes.');
      }
      report = DayReport(
          day: number(m, 'day', 1, day),
          oilProduced: number(m, 'oilProduced', 0, 1000000),
          gasProduced: number(m, 'gasProduced', 0, 1000000),
          revenue: number(m, 'revenue', 0, 1000000000000),
          expenses: number(m, 'expenses', 0, 1000000000000),
          event: string(m, 'event', max: 200),
          notes: List<String>.from(notes));
    }
    final state = GameState._(
        companyName: string(json, 'companyName', max: 40),
        day: day,
        cash: number(json, 'cash', -1000000000000, 1000000000000),
        debt: number(json, 'debt', 0, 1000000000),
        oilPrice: number(json, 'oilPrice', 30, 160),
        gasPrice: number(json, 'gasPrice', 2, 20),
        oilInventory: number(json, 'oilInventory', 0, 1000000),
        gasInventory: number(json, 'gasInventory', 0, 10000000),
        seed: number(json, 'seed', 1, 2147483646),
        nextId: number(json, 'nextId', 1, 100000000),
        assets: assets,
        leases: leases,
        employees: employees,
        businesses: businesses,
        contracts: contracts,
        ledger: ledger,
        completedObjectives: Set<String>.from(rawObjectives),
        priceHistory: history,
        leaseReserves: leaseReserves,
        lastReport: report,
        careerComplete: boolean(json, 'careerComplete'),
        totalRevenue: number(json, 'totalRevenue', 0, 1000000000000),
        totalProducedOil: number(json, 'totalProducedOil', 0, 1000000000000),
        totalProducedGas: number(json, 'totalProducedGas', 0, 1000000000000),
        totalTrades: number(json, 'totalTrades', 0, 100000000),
        contractsCompleted: number(json, 'contractsCompleted', 0, 1000000),
        restructures: number(json, 'restructures', 0, 100000));
    final engine = GameEngine(state);
    if (state.oilInventory > engine.oilStorageCapacity ||
        state.gasInventory > engine.gasStorageCapacity ||
        (state.careerComplete !=
            state.completedObjectives.contains('tycoon'))) {
      throw const FormatException(
          'Save exceeds capacity or has inconsistent progress.');
    }
    return state;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

/// Synchronous command boundary. Failed commands leave the save untouched.
class GameEngine {
  GameEngine(this.state);
  final GameState state;
  static const dailyLoanInterestRate = .002;
  static const maximumCash = 1000000000000;
  static int loanInterestFor(int debt) =>
      (math.max(0, debt) * dailyLoanInterestRate).ceil();

  factory GameEngine.newGame(
      {String companyName = 'Frontier Energy', int seed = 366}) {
    final cleanName = companyName.trim();
    if (cleanName.isEmpty ||
        cleanName.length > 40 ||
        RegExp(r'[\x00-\x1F]').hasMatch(cleanName)) {
      throw const FormatException(
          'Company name must contain 1–40 readable characters.');
    }
    final state = GameState._(
        companyName: cleanName,
        day: 1,
        cash: 150000,
        debt: 0,
        oilPrice: 84,
        gasPrice: 6,
        oilInventory: 0,
        gasInventory: 0,
        seed: seed.abs() % 2147483646 + 1,
        nextId: 5,
        assets: [
          OwnedAsset(id: 'asset_1', catalogId: 'pumpjack'),
          OwnedAsset(id: 'asset_2', catalogId: 'tanker')
        ],
        leases: [
          OwnedLease(
              id: 'cedar',
              reserves: TycoonCatalog.lease('cedar').reserves,
              developed: true,
              running: true,
              assetId: 'asset_1',
              employeeId: 'employee_3')
        ],
        employees: [
          Employee(
              id: 'employee_3',
              name: 'Alex Morgan',
              role: EmployeeRole.operator),
          Employee(
              id: 'employee_4', name: 'Casey Brooks', role: EmployeeRole.driver)
        ],
        businesses: [],
        contracts: [],
        ledger: [
          LedgerEntry(1, 'Starting capital', 150000)
        ],
        completedObjectives: {},
        priceHistory: [
          const PricePoint(1, 84, 6)
        ],
        leaseReserves: {
          'cedar': TycoonCatalog.lease('cedar').reserves
        });
    final engine = GameEngine(state);
    engine._refreshContracts();
    return engine;
  }

  int get oilStorageCapacity =>
      1500 + state.assets.fold<int>(0, (sum, a) => sum + a.spec.oilStorage);
  int get gasStorageCapacity =>
      6000 + state.assets.fold<int>(0, (sum, a) => sum + a.spec.gasStorage);
  int get dailyPayroll =>
      state.employees.fold<int>(0, (sum, e) => sum + e.salary);
  int get dailyUpkeep =>
      state.assets.fold<int>(0, (sum, a) => sum + a.spec.upkeep) +
      state.leases.length * 95 +
      state.businesses.fold<int>(0, (sum, b) => sum + b.spec.upkeep * b.level);
  int get dailyInterest => loanInterestFor(state.debt);
  bool get isInsolvent => state.cash < 0;
  int get transportCapacity {
    final fleets = state.assets
        .where((a) => a.spec.transport > 0 && a.condition > 20)
        .toList()
      ..sort((a, b) => (b.spec.transport * b.condition)
          .compareTo(a.spec.transport * a.condition));
    final drivers = state.employees
        .where((e) => e.role == EmployeeRole.driver)
        .toList()
      ..sort((a, b) => b.level.compareTo(a.level));
    var capacity = _businessLevel('logistics') * 250;
    for (var i = 0; i < math.min(fleets.length, drivers.length); i++) {
      capacity += (fleets[i].spec.transport *
              fleets[i].condition /
              100 *
              (1 + (drivers[i].level - 1) * .05))
          .floor();
    }
    return capacity;
  }

  int get netWorth =>
      state.cash -
      state.debt +
      state.oilInventory * commoditySellPrice(Commodity.oil) +
      state.gasInventory * commoditySellPrice(Commodity.gas) +
      state.assets.fold<int>(0, (sum, a) => sum + assetSaleValue(a.id)) +
      state.leases.fold<int>(0, (sum, l) => sum + leaseSaleValue(l.id)) +
      state.businesses.fold<int>(0, (sum, b) => sum + businessSaleValue(b.id)) +
      state.contracts
          .where((c) => c.status == ContractStatus.active)
          .fold<int>(0, (sum, c) => sum + c.deposit);
  int get availableLoan =>
      math.max(0, math.min(250000, math.max(0, netWorth ~/ 2)) - state.debt);
  int commodityBuyPrice(Commodity commodity) =>
      ((_marketPrice(commodity)) * 1.03).ceil();
  int commoditySellPrice(Commodity commodity) => (_marketPrice(commodity) *
          (.97 +
              (commodity == Commodity.oil
                  ? _businessLevel('refinery') * .01
                  : 0)))
      .floor();
  int employeeBaseSalary(EmployeeRole role) =>
      Employee(id: '_', name: '_', role: role).salary;
  int employeeHiringCost(EmployeeRole role) => employeeBaseSalary(role) * 12;
  int employeeTrainingCost(String id) => (_employee(id)?.level ?? 0) * 2500;
  int assetSaleValue(String id) {
    final asset = _asset(id);
    return asset == null
        ? 0
        : (asset.spec.price * .65 * (.2 + .8 * asset.condition / 100)).floor();
  }

  int assetRepairCost(String id) {
    final asset = _asset(id);
    if (asset == null || asset.condition == 100) return 0;
    final mechanicSkill = state.employees
        .where((e) => e.role == EmployeeRole.mechanic)
        .fold<int>(0, (sum, e) => sum + e.level);
    final discount = _businessLevel('parts_yard') * .1 +
        math.min(.2, mechanicSkill * .02) +
        (state.assets
                .any((a) => a.catalogId == 'service_truck' && a.condition > 20)
            ? .1
            : 0);
    return (asset.spec.price * (100 - asset.condition) * .004 * (1 - discount))
        .ceil();
  }

  int leaseDevelopmentCost(String id) {
    final lease = TycoonCatalog.leases.where((l) => l.id == id).firstOrNull;
    if (lease == null) return 0;
    final ownsRig =
        state.assets.any((a) => a.catalogId == 'drill_rig' && a.condition > 20);
    return (lease.developmentCost * (ownsRig ? .65 : 1)).ceil();
  }

  int leaseAvailableReserves(String id) =>
      state.leaseReserves[id] ??
      TycoonCatalog.leases.where((l) => l.id == id).firstOrNull?.reserves ??
      0;
  int leasePurchaseCost(String id) {
    final spec = TycoonCatalog.leases.where((l) => l.id == id).firstOrNull;
    if (spec == null) return 0;
    return (spec.price * (.2 + .8 * leaseAvailableReserves(id) / spec.reserves))
        .ceil();
  }

  int leaseSaleValue(String id) {
    final lease = _lease(id);
    if (lease == null) return 0;
    return (leasePurchaseCost(id) * .65).floor() +
        (lease.developed ? (lease.spec.developmentCost * .5).floor() : 0);
  }

  int businessUpgradeCost(String id) {
    final b = _business(id);
    return b == null || b.level >= 3
        ? 0
        : (b.spec.price * (.5 + b.level * .25)).ceil();
  }

  int businessSaleValue(String id) {
    final b = _business(id);
    if (b == null) return 0;
    var investment = b.spec.price;
    for (var level = 1; level < b.level; level++) {
      investment += (b.spec.price * (.5 + level * .25)).ceil();
    }
    return (investment * .65).floor();
  }

  List<ObjectiveProgress> get objectives {
    ObjectiveProgress goal(String id, String title, String description,
            int current, int target, int reward) =>
        ObjectiveProgress(id, title, description, current, target, reward,
            state.completedObjectives.contains(id));
    final developed = state.leases.where((l) => l.developed).length;
    return [
      goal('first_shift', 'First oil', 'Run your first shift at Cedar Creek.',
          state.day - 1, 1, 5000),
      goal(
          'first_trade',
          'Make a trade',
          'Buy or sell a commodity on the exchange.',
          state.totalTrades,
          1,
          5000),
      goal('second_lease', 'Expand your footprint',
          'Own two oil or gas leases.', state.leases.length, 2, 10000),
      goal('team', 'Build your crew', 'Employ four people in your company.',
          state.employees.length, 4, 7500),
      goal('business', 'Diversify', 'Acquire your first supporting business.',
          state.businesses.length, 1, 15000),
      goal(
          'contract',
          'Reliable supplier',
          'Complete your first supply contract.',
          state.contractsCompleted,
          1,
          15000),
      goal('million', 'Million-dollar company', 'Reach 1,000,000 in net worth.',
          netWorth, 1000000, 100000),
      goal(
          'tycoon',
          'Oil & Gas Tycoon',
          'Reach 5,000,000 net worth and develop four leases.',
          developed < 4 ? 0 : netWorth,
          5000000,
          250000),
    ];
  }

  String get gameHint {
    if (isInsolvent) {
      return 'Cash is below zero. Sell inventory or assets, arrange credit, or restructure.';
    }
    if (state.oilInventory >= oilStorageCapacity * .85 ||
        state.gasInventory >= gasStorageCapacity * .85) {
      return 'Storage is nearly full. Sell commodities, deliver a contract, or add storage.';
    }
    if (state.assets.any((a) => a.condition <= 25)) {
      return 'Equipment needs attention. Repair worn assets before the next shift.';
    }
    if (state.contracts.any((c) =>
        c.status == ContractStatus.active && c.deadlineDay <= state.day + 1)) {
      return 'A supply contract is due soon. Deliver before its deadline to recover your deposit.';
    }
    return objectives.where((g) => !g.complete).firstOrNull?.description ??
        'Your tycoon career is complete. Keep expanding your company in endless play.';
  }

  ActionResult buyAsset(String catalogId) {
    final spec =
        TycoonCatalog.assets.where((v) => v.id == catalogId).firstOrNull;
    if (spec == null) return _fail('Choose a valid asset.');
    if (state.assets.length >= 200) {
      return _fail('Your fleet has reached its 200-asset limit.');
    }
    if (!_canSpend(spec.price)) {
      return _fail('You need ${spec.price} to buy ${spec.name}.');
    }
    _spend(spec.price, 'Bought ${spec.name}');
    state.assets.add(OwnedAsset(id: _newId('asset'), catalogId: spec.id));
    return _finish('${spec.name} added to your fleet.');
  }

  ActionResult sellAsset(String id) {
    final asset = _asset(id);
    if (asset == null) return _fail('That asset is no longer owned.');
    if (state.oilInventory > oilStorageCapacity - asset.spec.oilStorage ||
        state.gasInventory > gasStorageCapacity - asset.spec.gasStorage) {
      return _fail(
          'Sell enough stored commodities before removing this storage terminal.');
    }
    final value = assetSaleValue(id);
    if (!_canCredit(value)) {
      return _fail('Treasury is full. Spend funds before selling this asset.');
    }
    for (final lease in state.leases.where((l) => l.assetId == id)) {
      lease.assetId = null;
      lease.running = false;
    }
    state.assets.remove(asset);
    _receive(value, 'Sold ${asset.spec.name}');
    return _finish(
        '${asset.spec.name} sold for $value. Assigned sites are paused.');
  }

  ActionResult repairAsset(String id) {
    final asset = _asset(id);
    if (asset == null) return _fail('Choose an owned asset.');
    if (asset.condition == 100) {
      return _fail('This asset is already fully maintained.');
    }
    final cost = assetRepairCost(id);
    if (!_canSpend(cost)) return _fail('Repairs require $cost.');
    _spend(cost, 'Repaired ${asset.spec.name}');
    asset.condition = 100;
    return _finish('${asset.spec.name} restored to 100% condition.');
  }

  ActionResult acquireLease(String id) {
    final spec = TycoonCatalog.leases.where((v) => v.id == id).firstOrNull;
    if (spec == null) return _fail('Choose a valid lease.');
    if (_lease(id) != null) return _fail('You already own this lease.');
    final reserves = leaseAvailableReserves(id);
    if (reserves == 0) {
      return _fail('This lease is depleted and cannot be acquired again.');
    }
    final price = leasePurchaseCost(id);
    if (!_canSpend(price)) {
      return _fail('This lease costs $price, before development.');
    }
    _spend(price, 'Acquired ${spec.name}');
    state.leaseReserves[id] = reserves;
    state.leases.add(OwnedLease(id: id, reserves: reserves));
    return _finish(
        '${spec.name} acquired. Develop it, then assign equipment and an operator.');
  }

  ActionResult sellLease(String id) {
    final lease = _lease(id);
    if (lease == null) return _fail('You do not own this lease.');
    final price = leaseSaleValue(id);
    if (!_canCredit(price)) {
      return _fail('Treasury is full. Spend funds before selling this lease.');
    }
    state.leaseReserves[id] = lease.reserves;
    state.leases.remove(lease);
    _receive(price, 'Sold ${lease.spec.name}');
    return _finish(
        '${lease.spec.name} sold for $price. Equipment and crew remain yours; remaining underground reserves are preserved.');
  }

  ActionResult developLease(String id) {
    final lease = _lease(id);
    if (lease == null) return _fail('Acquire this lease first.');
    if (lease.developed) return _fail('This lease is already developed.');
    final cost = leaseDevelopmentCost(id);
    if (!_canSpend(cost)) return _fail('Development requires $cost.');
    _spend(cost, 'Developed ${lease.spec.name}');
    lease.developed = true;
    return _finish(
        '${lease.spec.name} is ready for equipment and an operator.');
  }

  ActionResult assignLease(String id, {String? assetId, String? employeeId}) {
    final lease = _lease(id);
    if (lease == null || !lease.developed) {
      return _fail('Develop this lease before assigning a crew.');
    }
    if (assetId != null) {
      final asset = _asset(assetId);
      if (asset == null || asset.spec.commodity != lease.spec.commodity) {
        return _fail('Choose production equipment for this lease’s commodity.');
      }
      if (state.leases.any((l) => l.id != id && l.assetId == assetId)) {
        return _fail(
            'This equipment is assigned to another lease. Unassign it first.');
      }
    }
    if (employeeId != null) {
      final employee = _employee(employeeId);
      if (employee == null || employee.role != EmployeeRole.operator) {
        return _fail('Choose an operator for this lease.');
      }
      if (state.leases.any((l) => l.id != id && l.employeeId == employeeId)) {
        return _fail(
            'This operator is assigned to another lease. Unassign them first.');
      }
    }
    lease.assetId = assetId;
    lease.employeeId = employeeId;
    lease.running = assetId != null && employeeId != null && lease.reserves > 0;
    return _finish(lease.running
        ? '${lease.spec.name} is ready for the next shift.'
        : '${lease.spec.name} assignments updated; site paused.');
  }

  ActionResult setLeaseRunning(String id, bool running) {
    final lease = _lease(id);
    if (lease == null) return _fail('Choose an owned lease.');
    if (running &&
        (!lease.developed ||
            lease.assetId == null ||
            lease.employeeId == null ||
            lease.reserves <= 0)) {
      return _fail(
          'The lease needs development, equipment, an operator, and remaining reserves.');
    }
    if (running && (_asset(lease.assetId!)?.condition ?? 0) <= 20) {
      return _fail(
          'Repair the assigned equipment above 20% condition before restarting.');
    }
    lease.running = running;
    return _finish('${lease.spec.name} ${running ? 'resumed' : 'paused'}.');
  }

  ActionResult hireEmployee(EmployeeRole role) {
    if (state.employees.length >= 100) {
      return _fail('Your company has reached its 100-person limit.');
    }
    final cost = employeeHiringCost(role);
    if (!_canSpend(cost)) {
      return _fail('Recruitment requires $cost plus daily wages.');
    }
    final names = [
      'Jordan Ellis',
      'Sam Rivera',
      'Avery Quinn',
      'Riley Chen',
      'Morgan Blake',
      'Drew Carter',
      'Taylor Reed',
      'Jamie Scott',
      'Skyler Hayes',
      'Charlie Park'
    ];
    final name = names[state.nextId % names.length];
    _spend(cost, 'Recruited $name (${role.name})');
    state.employees
        .add(Employee(id: _newId('employee'), name: name, role: role));
    return _finish(
        '$name joined as ${role.name}. Daily payroll is now $dailyPayroll.');
  }

  ActionResult trainEmployee(String id) {
    final employee = _employee(id);
    if (employee == null) return _fail('Choose an employee.');
    if (employee.level >= 5) {
      return _fail('This employee is already at level 5.');
    }
    final cost = employeeTrainingCost(id);
    if (!_canSpend(cost)) return _fail('Training requires $cost.');
    _spend(cost, 'Trained ${employee.name}');
    employee.level++;
    return _finish(
        '${employee.name} reached level ${employee.level}; salary is ${employee.salary} per shift.');
  }

  ActionResult fireEmployee(String id) {
    final employee = _employee(id);
    if (employee == null) return _fail('That employee is no longer employed.');
    for (final lease in state.leases.where((l) => l.employeeId == id)) {
      lease.employeeId = null;
      lease.running = false;
    }
    state.employees.remove(employee);
    _record('Released ${employee.name}', 0);
    return _finish('${employee.name} released. Affected sites are paused.');
  }

  ActionResult buyBusiness(String id) {
    final spec = TycoonCatalog.businesses.where((b) => b.id == id).firstOrNull;
    if (spec == null) return _fail('Choose a valid business.');
    if (_business(id) != null) return _fail('You already own this business.');
    if (!_canSpend(spec.price)) {
      return _fail('This business requires ${spec.price}.');
    }
    _spend(spec.price, 'Acquired ${spec.name}');
    state.businesses.add(OwnedBusiness(id: id));
    return _finish(
        '${spec.name} joins your company. Its staff costs are included in operating costs.');
  }

  ActionResult upgradeBusiness(String id) {
    final business = _business(id);
    if (business == null) return _fail('Acquire this business first.');
    if (business.level >= 3) return _fail('This business is fully upgraded.');
    final cost = businessUpgradeCost(id);
    if (!_canSpend(cost)) return _fail('This upgrade requires $cost.');
    _spend(cost, 'Upgraded ${business.spec.name}');
    business.level++;
    return _finish('${business.spec.name} is now level ${business.level}.');
  }

  ActionResult sellBusiness(String id) {
    final business = _business(id);
    if (business == null) return _fail('You do not own this business.');
    final value = businessSaleValue(id);
    if (!_canCredit(value)) {
      return _fail(
          'Treasury is full. Spend funds before selling this business.');
    }
    state.businesses.remove(business);
    _receive(value, 'Sold ${business.spec.name}');
    return _finish('${business.spec.name} sold for $value.');
  }

  ActionResult tradeCommodity(Commodity commodity, int quantity,
      {required bool buy}) {
    if (quantity <= 0 || quantity > 1000000) {
      return _fail('Enter a positive whole quantity up to 1,000,000.');
    }
    final inventory = _inventory(commodity);
    final price =
        buy ? commodityBuyPrice(commodity) : commoditySellPrice(commodity);
    final amount = quantity * price;
    if (buy) {
      final capacity =
          commodity == Commodity.oil ? oilStorageCapacity : gasStorageCapacity;
      if (inventory + quantity > capacity) {
        return _fail('There is not enough storage for this purchase.');
      }
      if (!_canSpend(amount)) return _fail('This purchase requires $amount.');
      _spend(amount, 'Bought $quantity ${commodity.name}');
      _setInventory(commodity, inventory + quantity);
    } else {
      if (quantity > inventory) {
        return _fail('You do not have enough ${commodity.name} to sell.');
      }
      if (!_canCredit(amount)) {
        return _fail(
            'Treasury is full. Spend funds before selling commodities.');
      }
      _setInventory(commodity, inventory - quantity);
      _receive(amount, 'Sold $quantity ${commodity.name}');
      state.totalRevenue += amount;
    }
    state.totalTrades++;
    return _finish(
        '${buy ? 'Bought' : 'Sold'} $quantity ${commodity.name} for $amount.');
  }

  ActionResult acceptContract(String id) {
    final contract = _contract(id);
    if (contract == null || contract.status != ContractStatus.available) {
      return _fail('This contract is no longer available.');
    }
    if (contract.deadlineDay < state.day) {
      return _fail('This contract has expired.');
    }
    if (state.contracts
            .where((c) => c.status == ContractStatus.active)
            .length >=
        5) {
      return _fail(
          'Complete an existing contract before accepting more than five.');
    }
    if (!_canSpend(contract.deposit)) {
      return _fail(
          'This contract requires a ${contract.deposit} refundable deposit.');
    }
    _spend(contract.deposit, 'Contract deposit: ${contract.title}');
    contract.status = ContractStatus.active;
    return _finish(
        'Accepted. Deliver ${contract.quantity} ${contract.commodity.name} by day ${contract.deadlineDay}; missed deposits are forfeited.');
  }

  ActionResult deliverContract(String id) {
    final contract = _contract(id);
    if (contract == null || contract.status != ContractStatus.active) {
      return _fail('This contract is not awaiting a delivery.');
    }
    if (contract.deadlineDay < state.day) {
      return _fail('The delivery deadline has passed.');
    }
    final available = _inventory(contract.commodity);
    if (available < contract.quantity) {
      return _fail(
          'You need ${contract.quantity} ${contract.commodity.name} in storage.');
    }
    if (!_canCredit(contract.payout + contract.deposit)) {
      return _fail(
          'Treasury is full. Spend funds before delivering this contract.');
    }
    _setInventory(contract.commodity, available - contract.quantity);
    contract.status = ContractStatus.completed;
    _receive(contract.payout, 'Delivered ${contract.title}');
    _receive(contract.deposit, 'Contract deposit returned');
    state.contractsCompleted++;
    state.totalRevenue += contract.payout;
    return _finish(
        'Delivered for ${contract.payout}; your ${contract.deposit} deposit was returned.');
  }

  ActionResult borrow(int amount) {
    if (amount <= 0 || amount > availableLoan) {
      return _fail('Borrow a positive amount up to $availableLoan.');
    }
    if (!_canCredit(amount)) {
      return _fail('Treasury is full. Spend funds before drawing more credit.');
    }
    state.debt += amount;
    _receive(amount, 'Business credit drawn');
    return _finish(
        'Borrowed $amount. Interest is 0.2% of outstanding debt per shift.');
  }

  ActionResult repayLoan(int amount) {
    if (amount <= 0 || amount > state.debt) {
      return _fail('Choose an amount between 1 and your outstanding debt.');
    }
    if (!_canSpend(amount)) {
      return _fail('You need $amount cash to make this repayment.');
    }
    state.debt -= amount;
    _spend(amount, 'Business credit repaid');
    return _finish('Repaid $amount; ${state.debt} remains outstanding.');
  }

  ActionResult advanceDay() {
    if (state.day >= 100000) {
      return _fail(
          'This company has reached its 100,000-day career limit. Export the save and start another company.');
    }
    if (isInsolvent) {
      return _fail(
          'Resolve negative cash through sales, credit, or restructuring before the next shift.');
    }
    final closingDay = state.day;
    final notes = <String>[];
    final weather = _nextRandom(100);
    final productionFactor = weather < 10
        ? .72
        : weather > 94
            ? 1.12
            : 1.0;
    final event = weather < 10
        ? 'Heavy weather: field output reduced 28%.'
        : weather > 94
            ? 'Clear conditions: field output increased 12%.'
            : 'Steady operations across the field.';
    var haul = transportCapacity * 10;
    var producedOil = 0, producedGas = 0;
    final usedAssets = <String>{};
    final engineering = state.employees
        .where((e) => e.role == EmployeeRole.engineer)
        .fold<int>(0, (sum, e) => sum + e.level);
    for (final lease in state.leases) {
      if (!lease.running || !lease.developed) continue;
      final asset = _asset(lease.assetId ?? '');
      final operator = _employee(lease.employeeId ?? '');
      if (asset == null ||
          operator == null ||
          operator.role != EmployeeRole.operator ||
          asset.spec.commodity != lease.spec.commodity) {
        notes.add(
            '${lease.spec.name}: assign suitable equipment and an operator.');
        continue;
      }
      if (asset.condition <= 20) {
        notes.add(
            '${lease.spec.name}: equipment needs repair above 20% condition.');
        continue;
      }
      if (lease.reserves == 0) {
        lease.running = false;
        notes.add('${lease.spec.name}: reserves are depleted.');
        continue;
      }
      final commodity = lease.spec.commodity;
      final unitHaul = commodity == Commodity.oil ? 10 : 1;
      final capacity =
          commodity == Commodity.oil ? oilStorageCapacity : gasStorageCapacity;
      final freeStorage = capacity - _inventory(commodity);
      final potential = (math.min(
                  asset.spec.production,
                  lease.spec.dailyOutput *
                      (1 +
                          (operator.level - 1) * .1 +
                          math.min(engineering, 10) * .02)) *
              asset.condition /
              100 *
              productionFactor)
          .floor();
      final output = [potential, lease.reserves, freeStorage, haul ~/ unitHaul]
          .reduce(math.min);
      if (output < potential) {
        notes.add(
            '${lease.spec.name}: limited by ${freeStorage < potential ? 'storage' : haul ~/ unitHaul < potential ? 'staffed transport' : 'remaining reserves'}; unused reserves stay in the ground.');
      }
      if (output <= 0) continue;
      haul -= output * unitHaul;
      lease.reserves -= output;
      state.leaseReserves[lease.id] = lease.reserves;
      _setInventory(commodity, _inventory(commodity) + output);
      if (commodity == Commodity.oil) {
        producedOil += output;
      } else {
        producedGas += output;
      }
      usedAssets.add(asset.id);
      if (lease.reserves == 0) {
        lease.running = false;
        notes.add('${lease.spec.name}: final reserves extracted.');
      }
    }
    if (producedOil > 0 || producedGas > 0) {
      final drivers =
          state.employees.where((e) => e.role == EmployeeRole.driver).length;
      final fleets = state.assets
          .where((a) => a.spec.transport > 0 && a.condition > 20)
          .toList()
        ..sort((a, b) => (b.spec.transport * b.condition)
            .compareTo(a.spec.transport * a.condition));
      usedAssets.addAll(fleets.take(drivers).map((a) => a.id));
    }
    final mechanics = state.employees
        .where((e) => e.role == EmployeeRole.mechanic)
        .fold<int>(0, (sum, e) => sum + e.level);
    final hasWorkshop = state.assets
        .any((a) => a.catalogId == 'service_truck' && a.condition > 20);
    final wear = mechanics > 0 || hasWorkshop ? 1 : 2;
    for (final asset in state.assets.where((a) => usedAssets.contains(a.id))) {
      asset.condition = math.max(0, asset.condition - wear);
    }
    final grossRevenue = state.businesses
        .fold<int>(0, (sum, b) => sum + b.spec.dailyIncome * b.level);
    final payroll = dailyPayroll,
        upkeep = dailyUpkeep,
        interest = dailyInterest;
    final expenses = payroll + upkeep + interest;
    if (payroll > 0) _spend(payroll, 'Crew payroll');
    if (upkeep > 0) _spend(upkeep, 'Assets, leases & business operating costs');
    if (interest > 0) _spend(interest, 'Business credit interest');
    final revenue = grossRevenue > 0
        ? _receive(grossRevenue, 'Business operating income')
        : 0;
    if (revenue < grossRevenue) {
      notes.add(
          'Treasury limit reached: ${grossRevenue - revenue} excess business income could not be credited.');
    }
    state.totalProducedOil += producedOil;
    state.totalProducedGas += producedGas;
    state.totalRevenue += revenue;
    state.day++;
    for (final contract in state.contracts) {
      if (contract.deadlineDay >= state.day) continue;
      if (contract.status == ContractStatus.active) {
        contract.status = ContractStatus.failed;
        notes.add(
            '${contract.title}: deadline missed; the ${contract.deposit} deposit was forfeited.');
        _record('Forfeited contract deposit: ${contract.title}', 0);
      } else if (contract.status == ContractStatus.available) {
        contract.status = ContractStatus.failed;
      }
    }
    state.oilPrice = (state.oilPrice +
            _nextRandom(15) -
            7 +
            ((84 - state.oilPrice) / 12).round())
        .clamp(30, 160)
        .toInt();
    state.gasPrice = (state.gasPrice +
            _nextRandom(3) -
            1 +
            ((7 - state.gasPrice) / 6).round())
        .clamp(2, 20)
        .toInt();
    state.priceHistory
        .add(PricePoint(state.day, state.oilPrice, state.gasPrice));
    if (state.priceHistory.length > 30) state.priceHistory.removeAt(0);
    _refreshContracts();
    if (state.cash < 0) {
      notes.add(
          'Your company has negative cash. Sell stock or assets, draw credit, or restructure before another shift.');
    }
    final report = DayReport(
        day: closingDay,
        oilProduced: producedOil,
        gasProduced: producedGas,
        revenue: revenue,
        expenses: expenses,
        event: event,
        notes: notes);
    state.lastReport = report;
    return _finish(
        'Shift $closingDay complete. Production is in storage, ready to sell or deliver.',
        report: report);
  }

  ActionResult restructureCompany() {
    if (!isInsolvent) {
      return _fail(
          'Restructuring is available only when company cash is negative.');
    }
    final recovery =
        GameEngine.newGame(companyName: state.companyName, seed: state.seed)
            .state;
    state.assets
      ..clear()
      ..addAll(recovery.assets);
    state.leases
      ..clear()
      ..addAll(recovery.leases);
    state.leaseReserves
      ..clear()
      ..addAll(recovery.leaseReserves);
    state.employees
      ..clear()
      ..addAll(recovery.employees);
    state.businesses.clear();
    state.contracts.clear();
    state.oilInventory = 0;
    state.gasInventory = 0;
    state.debt = 0;
    state.cash = 25000;
    state.nextId = math.max(state.nextId, recovery.nextId);
    state.restructures++;
    state.lastReport = null;
    _record(
        'Company restructured: assets and stock returned to creditors; starter operation retained',
        25000);
    _refreshContracts();
    return _finish(
        'Fresh financing approved: starter lease, pumpjack, haul fleet, two staff and 25,000 cash. Previous holdings and stock went to creditors.');
  }

  OwnedAsset? _asset(String id) =>
      state.assets.where((a) => a.id == id).firstOrNull;
  OwnedLease? _lease(String id) =>
      state.leases.where((a) => a.id == id).firstOrNull;
  Employee? _employee(String id) =>
      state.employees.where((a) => a.id == id).firstOrNull;
  OwnedBusiness? _business(String id) =>
      state.businesses.where((a) => a.id == id).firstOrNull;
  GameContract? _contract(String id) =>
      state.contracts.where((a) => a.id == id).firstOrNull;
  int _businessLevel(String id) => _business(id)?.level ?? 0;
  int _marketPrice(Commodity commodity) =>
      commodity == Commodity.oil ? state.oilPrice : state.gasPrice;
  int _inventory(Commodity commodity) =>
      commodity == Commodity.oil ? state.oilInventory : state.gasInventory;
  void _setInventory(Commodity commodity, int value) {
    if (commodity == Commodity.oil) {
      state.oilInventory = value;
    } else {
      state.gasInventory = value;
    }
  }

  bool _canSpend(int value) => value >= 0 && state.cash >= value;
  bool _canCredit(int value) => value >= 0 && value <= maximumCash - state.cash;
  void _spend(int value, String title) {
    state.cash -= value;
    _record(title, -value);
  }

  int _receive(int value, String title) {
    final credited = math.min(value, maximumCash - state.cash);
    state.cash += credited;
    _record(title, credited);
    if (credited < value) {
      _record(
          'Treasury limit: ${value - credited} excess income not credited', 0);
    }
    return credited;
  }

  void _record(String title, int amount) {
    state.ledger.insert(0, LedgerEntry(state.day, title, amount));
    if (state.ledger.length > 150) state.ledger.removeLast();
  }

  String _newId(String prefix) {
    String id;
    do {
      id = '${prefix}_${state.nextId}';
      state.nextId = state.nextId >= 100000000 ? 1 : state.nextId + 1;
    } while (state.assets.any((a) => a.id == id) ||
        state.employees.any((a) => a.id == id) ||
        state.contracts.any((a) => a.id == id));
    return id;
  }

  int _nextRandom(int max) {
    state.seed = (state.seed * 48271) % 2147483647;
    return state.seed % max;
  }

  void _refreshContracts() {
    final finished = state.contracts
        .where((c) =>
            c.status == ContractStatus.completed ||
            c.status == ContractStatus.failed)
        .toList();
    while (finished.length > 8) {
      state.contracts.remove(finished.removeAt(0));
    }
    var available = state.contracts
        .where((c) => c.status == ContractStatus.available)
        .length;
    while (available < 3) {
      final commodity = available == 2 ? Commodity.gas : Commodity.oil;
      final quantity = commodity == Commodity.oil
          ? 180 + _nextRandom(5) * 80
          : 800 + _nextRandom(5) * 200;
      final price =
          (_marketPrice(commodity) * (1.13 + _nextRandom(6) / 100)).ceil();
      state.contracts.add(GameContract(
          id: _newId('contract'),
          title:
              '${commodity == Commodity.oil ? 'Refinery' : 'Utility'} supply ${state.day}.${available + 1}',
          commodity: commodity,
          quantity: quantity,
          unitPrice: price,
          deadlineDay: state.day + 3,
          deposit: (quantity * price * .08).ceil()));
      available++;
    }
  }

  ActionResult _fail(String message) => ActionResult(false, message);
  ActionResult _finish(String message, {DayReport? report}) {
    // Lifetime counters are telemetry, so saturate at the documented save limits.
    // This also makes imported boundary values safe to continue playing.
    state.totalRevenue = state.totalRevenue.clamp(0, 1000000000000).toInt();
    state.totalProducedOil =
        state.totalProducedOil.clamp(0, 1000000000000).toInt();
    state.totalProducedGas =
        state.totalProducedGas.clamp(0, 1000000000000).toInt();
    state.totalTrades = state.totalTrades.clamp(0, 100000000).toInt();
    state.contractsCompleted =
        state.contractsCompleted.clamp(0, 1000000).toInt();
    state.restructures = state.restructures.clamp(0, 100000).toInt();
    final rewards = <String>[];
    // Two passes allow one milestone's reward to meet the next financial goal.
    for (var pass = 0; pass < 2; pass++) {
      for (final goal in objectives) {
        if (!goal.complete &&
            goal.current >= goal.target &&
            state.completedObjectives.add(goal.id)) {
          final credited = _receive(goal.reward, 'Milestone: ${goal.title}');
          rewards.add('${goal.title} +$credited');
          if (goal.id == 'tycoon') state.careerComplete = true;
        }
      }
    }
    return ActionResult(
        true,
        rewards.isEmpty
            ? message
            : '$message Milestone: ${rewards.join(', ')}.',
        report: report);
  }
}
