import fs from 'node:fs';

const path = 'lib/marketplace/marketplace_dispatch_equipment_capability.dart';

function repairEquipmentAnalyzerSource(input) {
  let source = input;

  const dialogMarker = 'if (!mounted || !dialogContext.mounted) return;';
  if (!source.includes(dialogMarker)) {
    const dialogPattern =
      /if \(!mounted\) return;\s+Navigator\.of\(dialogContext\)\.pop\(\);/;
    if (!dialogPattern.test(source)) {
      throw new Error(
        'Equipment analyzer repair anchor missing: dialog context guard',
      );
    }
    source = source.replace(
      dialogPattern,
      [dialogMarker, 'Navigator.of(dialogContext).pop();'].join('\n'),
    );
  }

  const numberMarker = 'final Object? numberValue = value;';
  const canonicalMarker =
    'final num? canonical = numberValue is num ? numberValue : null;';
  if (!source.includes(numberMarker) || !source.includes(canonicalMarker)) {
    const numberBefore = 'final canonical = value is num ? value : null;';
    if (!source.includes(numberBefore)) {
      throw new Error(
        'Equipment analyzer repair anchor missing: numeric capability promotion',
      );
    }
    source = source.replace(
      numberBefore,
      [numberMarker, canonicalMarker].join('\n'),
    );
  }

  const multiMarker = 'final Object? multiValue = value;';
  const joinMarker = "multiValue.join(', ')";
  if (!source.includes(multiMarker) || !source.includes(joinMarker)) {
    const multiBefore =
      "final text = value is Iterable ? value.join(', ') : '${value ?? ''}';";
    if (!source.includes(multiBefore)) {
      throw new Error(
        'Equipment analyzer repair anchor missing: multi-choice capability promotion',
      );
    }
    const multiAfter = [
      multiMarker,
      'final text = multiValue is Iterable',
      "    ? multiValue.join(', ')",
      "    : '${multiValue ?? ''}';",
    ].join('\n');
    source = source.replace(multiBefore, multiAfter);
  }

  const required = [
    dialogMarker,
    numberMarker,
    canonicalMarker,
    multiMarker,
    joinMarker,
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
  const formatterLike = repaired
    .replace('\nNavigator.of(dialogContext).pop();', '\n    Navigator.of(dialogContext).pop();')
    .replace('\nfinal num? canonical', '\n        final num? canonical')
    .replace('\nfinal text = multiValue', '\n        final text = multiValue');
  const repairedAgain = repairEquipmentAnalyzerSource(formatterLike);
  if (formatterLike !== repairedAgain) {
    throw new Error(
      'Equipment analyzer repair is not idempotent after formatter whitespace changes.',
    );
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
