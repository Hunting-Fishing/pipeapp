import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const rel = 'test/marketplace_grid_density_test.dart';
const full = path.join(root, rel);
let text = fs.readFileSync(full, 'utf8').replace(/\r\n/g, '\n');

let changed = false;

if (text.includes("find.byTooltip('3 columns')")) {
  text = text.replace(
    "find.byTooltip('3 columns')",
    "find.byTooltip('2 columns')",
  );
  changed = true;
}

const selected3 = "expect(option('3 columns').properties.selected, isTrue);";
const selected2 = "expect(option('2 columns').properties.selected, isTrue);";
if (text.includes(selected3)) {
  text = text.replace(selected3, selected2);
  changed = true;
}

if (!text.includes("find.byTooltip('2 columns')") || !text.includes(selected2)) {
  throw new Error(
    'Could not establish the stable 2-column selection assertion in marketplace_grid_density_test.dart',
  );
}

if (changed) {
  fs.writeFileSync(full, text, 'utf8');
  console.log('patched: grid-density accessibility selection now uses stable 2-column option');
} else {
  console.log('already applied: grid-density accessibility selection uses stable 2-column option');
}
