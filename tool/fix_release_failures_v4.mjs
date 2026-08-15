import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const rel = 'test/marketplace_grid_density_test.dart';
const full = path.join(root, rel);
let text = fs.readFileSync(full, 'utf8').replace(/\r\n/g, '\n');

const before = `      await tester.tap(find.byTooltip('3 columns'));
      await tester.pumpAndSettle();

      expect(option('Automatic responsive grid density').properties.selected, isFalse);
      expect(option('3 columns').properties.selected, isTrue);`;

const after = `      await tester.tap(find.byTooltip('2 columns'));
      await tester.pumpAndSettle();

      expect(option('Automatic responsive grid density').properties.selected, isFalse);
      expect(option('2 columns').properties.selected, isTrue);`;

if (text.includes(after)) {
  console.log('already applied: grid density semantic selection uses stable 2-column option');
} else if (text.includes(before)) {
  text = text.replace(before, after);
  fs.writeFileSync(full, text, 'utf8');
  console.log('patched: grid density semantic selection uses stable 2-column option');
} else {
  throw new Error(`Patch anchor not found in ${rel}`);
}
