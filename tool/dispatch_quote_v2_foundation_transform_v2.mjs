import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');

function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function replaceOnce(source, before, after, label) {
  const count = source.split(before).length - 1;
  if (count === 0) {
    if (source.includes(after)) return source;
    fail(`${label} anchor was not found.`);
  }
  if (count !== 1) fail(`${label} anchor matched ${count} times.`);
  return source.replace(before, after);
}

function ensureImport(source, anchor, importLine, label) {
  if (source.includes(importLine)) return source;
  if (!source.includes(anchor)) fail(`${label} import anchor was not found.`);
  return source.replace(anchor, `${anchor}${importLine}\n`);
}

function normalizeDispatchPage(input) {
  let source = input.replace(/\r\n/g, '\n');
  source = ensureImport(
    source,
    "import 'marketplace_freight_quote.dart';\n",
    "import 'marketplace_dispatch_quote_form.dart';",
    'Dispatch page quote form',
  );

  const start = source.indexOf('  Future<void> _bid(\n');
  const end = source.indexOf('\n}\n\ntypedef _DispatchDocumentBuilder', start);
  if (start < 0 || end <= start) {
    fail('Dispatch carrier _bid method boundary was not found.');
  }

  const replacement = `  Future<void> _bid(\n    BuildContext context,\n    String id,\n    Map<String, dynamic> data, {\n    QueryDocumentSnapshot<Map<String, dynamic>>? existing,\n  }) async {\n    final fleet = await FirebaseFirestore.instance\n        .collection('dispatch_carriers')\n        .doc(FirebaseAuth.instance.currentUser?.uid)\n        .collection('vehicles')\n        .limit(100)\n        .get();\n    if (fleet.docs.isEmpty) {\n      if (context.mounted) {\n        PipeFeedback.show(\n          context,\n          message:\n              'Create your Dispatch account and add a fleet vehicle before bidding.',\n          tone: PipeStatusTone.warning,\n        );\n      }\n      return;\n    }\n\n    final existingData = existing?.data();\n    final rawBreakdown = existingData?['quoteBreakdown'];\n    final previousBreakdown = rawBreakdown is Map\n        ? Map<String, dynamic>.from(rawBreakdown)\n        : <String, dynamic>{};\n    final existingVehicleId = '\${existingData?['vehicleId'] ?? ''}';\n    final selectedVehicle = fleet.docs\n            .where((vehicle) => vehicle.id == existingVehicleId)\n            .firstOrNull ??\n        fleet.docs.first;\n    final initialDate =\n        (existingData?['availableDate'] as Timestamp?)?.toDate() ??\n            (data['truckingDate'] as Timestamp?)?.toDate() ??\n            DateTime.now();\n    final routeDistance = data['routeDistanceKm'] ?? data['distanceKm'] ?? 0;\n    final initial = <String, dynamic>{\n      ...previousBreakdown,\n      'name': previousBreakdown['name'] ??\n          'Dispatch quote - \${data['title'] ?? 'job'}',\n      'origin': data['pickupLabel'] ?? previousBreakdown['origin'] ?? '',\n      'destination':\n          data['deliveryLabel'] ?? previousBreakdown['destination'] ?? '',\n      'distanceKm': previousBreakdown['distanceKm'] ?? routeDistance,\n      'weightKg': previousBreakdown['weightKg'] ??\n          data['estimatedWeightKg'] ??\n          data['catalogWeightKg'] ??\n          0,\n      'terms': existingData?['note'] ?? '',\n      'currency': existingData?['currency'] ??\n          previousBreakdown['currency'] ??\n          'CAD',\n    };\n    final vehicles = fleet.docs\n        .map(\n          (vehicle) {\n            final vehicleData = vehicle.data();\n            final vehicleType = '\${vehicleData['vehicleType'] ?? 'Truck'}';\n            return DispatchQuoteVehicleOption(\n              id: vehicle.id,\n              name: '\${vehicleData['name'] ?? 'Fleet vehicle'}',\n              subtitle:\n                  '\$vehicleType • \${vehicleData['maximumPayloadKg'] ?? 0} kg payload',\n            );\n          },\n        )\n        .toList(growable: false);\n\n    if (!context.mounted) return;\n    final draft = await MarketplaceDispatchQuoteForm.show(\n      context,\n      title: existing == null ? 'Build carrier quote' : 'Revise carrier quote',\n      subtitle: existing == null\n          ? 'Use the Pipe Buyer quote form. The submitted quote becomes Version 1.'\n          : 'The current quote is preserved. Saving creates the next immutable version.',\n      confirmLabel: existing == null ? 'Review Version 1' : 'Review new version',\n      initial: initial,\n      lockLaneIdentity: true,\n      vehicles: vehicles,\n      initialVehicleId: selectedVehicle.id,\n      initialAvailableDate: initialDate,\n    );\n    if (draft == null || !context.mounted) return;\n\n    final nextVersion = (existingData?['revision'] as num? ?? 0).toInt() + 1;\n    final confirmed = await showDialog<bool>(\n          context: context,\n          builder: (dialogContext) => AlertDialog(\n            title: Text(\n              existing == null\n                  ? 'Submit carrier quote Version 1?'\n                  : 'Submit carrier quote Version \$nextVersion?',\n            ),\n            content: Text(\n              '\${marketplaceMoney(draft.total)} \${draft.currency}. The job owner will see this version and the participant-only version history. Earlier versions remain preserved and are no longer the active quote.',\n            ),\n            actions: [\n              TextButton(\n                onPressed: () => Navigator.pop(dialogContext, false),\n                child: const Text('Go back'),\n              ),\n              FilledButton(\n                onPressed: () => Navigator.pop(dialogContext, true),\n                child: Text(existing == null\n                    ? 'Submit Version 1'\n                    : 'Save Version \$nextVersion'),\n              ),\n            ],\n          ),\n        ) ??\n        false;\n    if (!confirmed) return;\n\n    try {\n      await repo.bid(\n        jobId: id,\n        amount: draft.total,\n        note: draft.terms,\n        availableDate: draft.availableDate!,\n        vehicleId: draft.vehicleId!,\n        vehicleName: draft.vehicleName!,\n        quoteBreakdown: draft.breakdown,\n        currency: draft.currency,\n      );\n      if (context.mounted) {\n        PipeFeedback.show(\n          context,\n          message: existing == null\n              ? 'Carrier quote Version 1 submitted.'\n              : 'Carrier quote Version \$nextVersion submitted. Previous version preserved.',\n          tone: PipeStatusTone.success,\n        );\n      }\n    } catch (error) {\n      if (context.mounted) {\n        PipeFeedback.show(\n          context,\n          message: marketplaceCommandErrorMessage(\n            error,\n            fallback: 'The carrier quote could not be saved.',\n          ),\n          tone: PipeStatusTone.error,\n        );\n      }\n    }\n  }\n`;
  source = source.slice(0, start) + replacement + source.slice(end);

  if (source.includes("labelText: 'All-in transport price'")) {
    fail('Legacy all-in carrier quote dialog remains after quote v2 transform.');
  }
  if (!source.includes('MarketplaceDispatchQuoteForm.show(')) {
    fail('Dispatch Jobs are not wired to the reusable quote form.');
  }
  return source;
}

function normalizeDashboard(input) {
  let source = input.replace(/\r\n/g, '\n');
  source = ensureImport(
    source,
    "import 'marketplace_dispatch_repository.dart';\n",
    "import 'marketplace_dispatch_quote_form.dart';",
    'Dispatch dashboard quote form',
  );
  const start = source.indexOf('  Future<void> _newQuote(\n');
  const end = source.indexOf('\n  Future<void> _showSavedQuoteHistory', start);
  if (start < 0 || end <= start) fail('Dashboard _newQuote boundary was not found.');
  const replacement = `  Future<void> _newQuote(\n      {Map<String, dynamic>? template, String? quoteId}) async {\n    final draft = await MarketplaceDispatchQuoteForm.show(\n      context,\n      title: quoteId == null\n          ? 'Dispatch quote calculator'\n          : 'Revise saved Dispatch quote',\n      subtitle: quoteId == null\n          ? 'Build a reusable rate plan from the Pipe Buyer quote form.'\n          : 'Saving creates the next saved-quote version and preserves the prior one.',\n      confirmLabel: quoteId == null ? 'Save Version 1' : 'Save new version',\n      initial: template ?? const <String, dynamic>{},\n    );\n    if (draft == null) return;\n    await widget.repo.saveQuote(\n      {\n        ...draft.breakdown,\n        'terms': draft.terms,\n        'currency': draft.currency,\n      },\n      quoteId: quoteId,\n    );\n  }\n`;
  source = source.slice(0, start) + replacement + source.slice(end);
  if (!source.includes('MarketplaceDispatchQuoteForm.show(')) {
    fail('Dashboard saved quotes are not wired to the reusable quote form.');
  }
  return source;
}

function normalizeRepository(input) {
  let source = input.replace(/\r\n/g, '\n');
  const bidBefore = `  Future<void> bid({\n    required String jobId,\n    required num amount,\n    required String note,\n    required DateTime availableDate,\n    required String vehicleId,\n    required String vehicleName,\n  }) async {`;
  const bidAfter = `  Future<void> bid({\n    required String jobId,\n    required num amount,\n    required String note,\n    required DateTime availableDate,\n    required String vehicleId,\n    required String vehicleName,\n    required Map<String, dynamic> quoteBreakdown,\n    required String currency,\n  }) async {`;
  source = replaceOnce(source, bidBefore, bidAfter, 'Repository bid signature');

  const payloadAnchor = `      'availableDate': availableDate.millisecondsSinceEpoch,\n      'vehicleId': vehicleId,`;
  const payloadReplacement = `      'availableDate': availableDate.millisecondsSinceEpoch,\n      'vehicleId': vehicleId,\n      'quoteBreakdown': quoteBreakdown,\n      'currency': currency,`;
  if (!source.includes(payloadReplacement)) {
    const count = source.split(payloadAnchor).length - 1;
    if (count < 1) fail('Repository quote payload anchor was not found.');
    source = source.replace(payloadAnchor, payloadReplacement);
  }
  if ((source.match(/'quoteBreakdown': quoteBreakdown/g) || []).length !== 1) {
    fail('Repository bid must transmit exactly one quoteBreakdown payload.');
  }
  return source;
}

const breakdownHelper = `\nfunction dispatchQuoteNumber(raw, fieldName, maximum = 100000000) {\n  const value = Number(raw && raw[fieldName] || 0);\n  if (!Number.isFinite(value) || value < 0 || value > maximum) {\n    throw new CommandPolicyError(\n        \"invalid-argument\",\n        \`Quote \${fieldName} must be a valid non-negative number.\`,\n    );\n  }\n  return value;\n}\n\nfunction validateDispatchQuoteBreakdown(data, submittedAmount) {\n  const raw = data && data.quoteBreakdown;\n  if (!raw || typeof raw !== \"object\" || Array.isArray(raw)) {\n    return {currency: \"CAD\", quoteBreakdown: null};\n  }\n  const currency = String(data.currency || raw.currency || \"CAD\")\n      .trim().toUpperCase();\n  if (![\"CAD\", \"USD\"].includes(currency)) {\n    throw new CommandPolicyError(\n        \"invalid-argument\",\n        \"Dispatch quote currency must be CAD or USD.\",\n    );\n  }\n  const formulaVersion = Number(raw.formulaVersion || 2);\n  if (formulaVersion !== 2) {\n    throw new CommandPolicyError(\n        \"invalid-argument\",\n        \"Dispatch quote formula version is unsupported.\",\n    );\n  }\n  const distanceKm = dispatchQuoteNumber(raw, \"distanceKm\");\n  const deadheadKm = dispatchQuoteNumber(raw, \"deadheadKm\");\n  const mileageRate = dispatchQuoteNumber(raw, \"mileageRate\", 1000000);\n  const deadheadRate = dispatchQuoteNumber(raw, \"deadheadRate\", 1000000);\n  const weightKg = dispatchQuoteNumber(raw, \"weightKg\");\n  const weightRate = dispatchQuoteNumber(raw, \"weightRate\", 1000000);\n  const hours = dispatchQuoteNumber(raw, \"hours\", 100000);\n  const hourlyRate = dispatchQuoteNumber(raw, \"hourlyRate\", 1000000);\n  const areaFee = dispatchQuoteNumber(raw, \"areaFee\");\n  const pilotCount = dispatchQuoteNumber(raw, \"pilotCount\", 100);\n  const pilotKmRate = dispatchQuoteNumber(raw, \"pilotKmRate\", 1000000);\n  const pilotHourlyRate = dispatchQuoteNumber(raw, \"pilotHourlyRate\", 1000000);\n  const pilotAreaFee = dispatchQuoteNumber(raw, \"pilotAreaFee\");\n  const permitFee = dispatchQuoteNumber(raw, \"permitFee\");\n  const baseFee = dispatchQuoteNumber(raw, \"baseFee\");\n  const surchargePercent = dispatchQuoteNumber(raw, \"surchargePercent\", 1000);\n  const taxPercent = dispatchQuoteNumber(raw, \"taxPercent\", 1000);\n  const manualTotal = dispatchQuoteNumber(raw, \"manualTotal\");\n  const manual = raw.manual === true;\n\n  const loadedMileage = distanceKm * mileageRate;\n  const deadhead = deadheadKm * deadheadRate;\n  const weight = weightKg / 1000 * weightRate;\n  const time = hours * hourlyRate;\n  const pilot = pilotCount *\n    (distanceKm * pilotKmRate + hours * pilotHourlyRate + pilotAreaFee);\n  const subtotal = baseFee + loadedMileage + deadhead + weight + time +\n    areaFee + permitFee + pilot;\n  const surcharge = subtotal * surchargePercent / 100;\n  const beforeTax = subtotal + surcharge;\n  const tax = beforeTax * taxPercent / 100;\n  const total = manual ? manualTotal : beforeTax + tax;\n  if (!Number.isFinite(total) || total <= 0 ||\n      Math.abs(total - Number(submittedAmount)) > 0.011) {\n    throw new CommandPolicyError(\n        \"failed-precondition\",\n        \"Carrier quote total does not match the server-calculated quote form.\",\n    );\n  }\n  const name = optionalText(raw.name, \"Quote name\", 200) || \"\";\n  const origin = optionalText(raw.origin, \"Quote origin\", 500) || \"\";\n  const destination = optionalText(raw.destination, \"Quote destination\", 500) || \"\";\n  return {\n    currency,\n    quoteBreakdown: {\n      name, origin, destination, currency, formulaVersion: 2, manual,\n      distanceKm, deadheadKm, mileageRate, deadheadRate, weightKg, weightRate,\n      hours, hourlyRate, areaFee, pilotCount, pilotKmRate, pilotHourlyRate,\n      pilotAreaFee, permitFee, baseFee, surchargePercent, taxPercent, manualTotal,\n      loadedMileage, deadhead, weight, time, pilot, subtotal, surcharge, tax, total,\n    },\n  };\n}\n`;

function normalizePolicy(input) {
  let source = input.replace(/\r\n/g, '\n');
  if (!source.includes('function validateDispatchQuoteBreakdown(')) {
    const anchor = '\nfunction validateDispatchQuote({\n';
    if (!source.includes(anchor)) fail('Dispatch quote policy insertion anchor was not found.');
    source = source.replace(anchor, `${breakdownHelper}${anchor}`);
  }
  source = replaceOnce(
    source,
    `  const amount = requireMoney(data.amount, \"Carrier quote\");\n  const note = String(data.note || \"\").trim();`,
    `  const amount = requireMoney(data.amount, \"Carrier quote\");\n  const breakdown = validateDispatchQuoteBreakdown(data, amount);\n  const note = String(data.note || \"\").trim();`,
    'Dispatch quote policy calculation',
  );
  source = replaceOnce(
    source,
    '  return {amount, note, availableDate};',
    '  return {amount, note, availableDate, ...breakdown};',
    'Dispatch quote policy return',
  );
  if (!source.includes('  validateDispatchQuoteBreakdown,\n')) {
    source = replaceOnce(
      source,
      '  validateDispatchQuote,\n',
      '  validateDispatchQuote,\n  validateDispatchQuoteBreakdown,\n',
      'Dispatch quote policy export',
    );
  }
  return source;
}

function normalizeCommands(input) {
  let source = input.replace(/\r\n/g, '\n');
  const valuesAnchor = `        amount: quote.amount,\n        note: quote.note,\n        availableDate: Timestamp.fromMillis(quote.availableDate),`;
  const valuesReplacement = `        amount: quote.amount,\n        currency: quote.currency,\n        quoteBreakdown: quote.quoteBreakdown,\n        quoteReference: existingBid && existingBid.quoteReference ||\n          \`PBQ-\${bidRef.id.slice(0, 10).toUpperCase()}\`,\n        quoteVersion: revision,\n        validityStatus: \"active\",\n        note: quote.note,\n        availableDate: Timestamp.fromMillis(quote.availableDate),`;
  source = replaceOnce(source, valuesAnchor, valuesReplacement, 'Dispatch quote server values');
  source = replaceOnce(
    source,
    `        revision,\n        created: !existingBid,\n      };`,
    `        revision,\n        quoteReference: values.quoteReference,\n        created: !existingBid,\n      };`,
    'Dispatch quote server result',
  );
  return source;
}

export function transformDispatchQuoteV2Foundation(files) {
  const transformed = {
    page: normalizeDispatchPage(files.page),
    dashboard: normalizeDashboard(files.dashboard),
    repository: normalizeRepository(files.repository),
    policy: normalizePolicy(files.policy),
    commands: normalizeCommands(files.commands),
  };
  const second = {
    page: normalizeDispatchPage(transformed.page),
    dashboard: normalizeDashboard(transformed.dashboard),
    repository: normalizeRepository(transformed.repository),
    policy: normalizePolicy(transformed.policy),
    commands: normalizeCommands(transformed.commands),
  };
  for (const key of Object.keys(transformed)) {
    if (second[key] !== transformed[key]) {
      fail(`Quote v2 transform is not idempotent for ${key}.`);
    }
  }
  return transformed;
}

export function loadDispatchQuoteV2Files() {
  const paths = {
    page: path.join(repoRoot, 'lib', 'marketplace', 'marketplace_dispatch_page.dart'),
    dashboard: path.join(repoRoot, 'lib', 'marketplace', 'marketplace_dispatch_dashboard.dart'),
    repository: path.join(repoRoot, 'lib', 'marketplace', 'marketplace_dispatch_repository.dart'),
    policy: path.join(repoRoot, 'firebase', 'functions', 'dispatch_command_policy.js'),
    commands: path.join(repoRoot, 'firebase', 'functions', 'dispatch_commands.js'),
  };
  const files = {};
  for (const [key, filePath] of Object.entries(paths)) {
    if (!fs.existsSync(filePath)) fail(`Required quote v2 source is missing: ${filePath}`);
    files[key] = fs.readFileSync(filePath, 'utf8');
  }
  return {paths, files};
}
