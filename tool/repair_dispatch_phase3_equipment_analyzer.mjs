import fs from 'node:fs';

const path = 'lib/marketplace/marketplace_dispatch_equipment_capability.dart';
let source = fs.readFileSync(path, 'utf8');

const original = source;

source = source.replace(
  /if \(!mounted\) return;\s+Navigator\.of\(dialogContext\)\.pop\(\);/,
  `if (!mounted || !dialogContext.mounted) return;\n                                    Navigator.of(dialogContext).pop();`,
);

source = source.replace(
  'final canonical = value is num ? value : null;',
  `final Object? numberValue = value;\n        final canonical = numberValue is num ? numberValue : null;`,
);

source = source.replace(
  "final text = value is Iterable ? value.join(', ') : '${value ?? ''}';",
  `final Object? multiValue = value;\n        final text = multiValue is Iterable\n            ? multiValue.join(', ')\n            : '${multiValue ?? ''}';`,
);

const required = [
  'if (!mounted || !dialogContext.mounted) return;',
  'final Object? numberValue = value;',
  'final canonical = numberValue is num ? numberValue : null;',
  'final Object? multiValue = value;',
  "multiValue.join(', ')",
];

for (const marker of required) {
  if (!source.includes(marker)) {
    throw new Error(`Equipment analyzer repair marker missing: ${marker}`);
  }
}

if (source === original) {
  console.log('Dispatch Phase 3 equipment analyzer repair already applied.');
  process.exit(0);
}

fs.writeFileSync(path, source, 'utf8');
console.log('Dispatch Phase 3 equipment analyzer compatibility repair applied.');
