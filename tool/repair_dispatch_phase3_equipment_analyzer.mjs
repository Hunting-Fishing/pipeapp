import fs from 'node:fs';

const path = 'lib/marketplace/marketplace_dispatch_equipment_capability.dart';

function repairEquipmentAnalyzerSource(input) {
  let source = input;

  const dialogAfter = [
    'if (!mounted || !dialogContext.mounted) return;',
    '                                    Navigator.of(dialogContext).pop();',
  ].join('\n');

  if (!source.includes(dialogAfter)) {
    const dialogPattern =
      /if \(!mounted\) return;\s+Navigator\.of\(dialogContext\)\.pop\(\);/;
    if (!dialogPattern.test(source)) {
      throw new Error(
        'Equipment analyzer repair anchor missing: dialog context guard',
      );
    }
    source = source.replace(dialogPattern, dialogAfter);
  }

  const numberBefore = 'final canonical = value is num ? value : null;';
  const numberAfter = [
    'final Object? numberValue = value;',
    '        final num? canonical = numberValue is num ? numberValue : null;',
  ].join('\n');
  if (!source.includes(numberAfter)) {
    if (!source.includes(numberBefore)) {
      throw new Error(
        'Equipment analyzer repair anchor missing: numeric capability promotion',
      );
    }
    source = source.replace(numberBefore, numberAfter);
  }

  const multiBefore =
    "final text = value is Iterable ? value.join(', ') : '${value ?? ''}';";
  const multiAfter = [
    'final Object? multiValue = value;',
    '        final text = multiValue is Iterable',
    "            ? multiValue.join(', ')",
    "            : '${multiValue ?? ''}';",
  ].join('\n');
  if (!source.includes(multiAfter)) {
    if (!source.includes(multiBefore)) {
      throw new Error(
        'Equipment analyzer repair anchor missing: multi-choice capability promotion',
      );
    }
    source = source.replace(multiBefore, multiAfter);
  }

  const required = [
    'if (!mounted || !dialogContext.mounted) return;',
    'final Object? numberValue = value;',
    'final num? canonical = numberValue is num ? numberValue : null;',
    'final Object? multiValue = value;',
    "multiValue.join(', ')",
  ];

  for (const marker of required) {
    if (!source.includes(marker)) {
      throw new Error(`Equipment analyzer repair marker missing: ${marker}`);
    }
  }

  return source;
}

function selfTest() {
  const fixture = [
    'if (!mounted) return;',
    'Navigator.of(dialogContext).pop();',
    'final canonical = value is num ? value : null;',
    "final text = value is Iterable ? value.join(', ') : '${value ?? ''}';",
  ].join('\n');

  const repaired = repairEquipmentAnalyzerSource(fixture);
  const repairedAgain = repairEquipmentAnalyzerSource(repaired);
  if (repaired !== repairedAgain) {
    throw new Error('Equipment analyzer repair is not idempotent.');
  }
}

selfTest();

const original = fs.readFileSync(path, 'utf8');
const repaired = repairEquipmentAnalyzerSource(original);

if (repaired === original) {
  console.log('Dispatch Phase 3 equipment analyzer repair already applied.');
  process.exit(0);
}

fs.writeFileSync(path, repaired, 'utf8');
console.log('Dispatch Phase 3 equipment analyzer compatibility repair applied.');
