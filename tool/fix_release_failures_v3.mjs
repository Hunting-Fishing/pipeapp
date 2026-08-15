import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();

function load(rel) {
  return fs.readFileSync(path.join(root, rel), 'utf8').replace(/\r\n/g, '\n');
}

function save(rel, text) {
  fs.writeFileSync(path.join(root, rel), text, 'utf8');
}

function replaceOnce(rel, before, after, label) {
  let text = load(rel);
  if (text.includes(after)) {
    console.log(`already applied: ${label}`);
    return;
  }
  const index = text.indexOf(before);
  if (index < 0) {
    throw new Error(`Patch anchor not found for ${label} in ${rel}`);
  }
  text = text.slice(0, index) + after + text.slice(index + before.length);
  save(rel, text);
  console.log(`patched: ${label}`);
}

replaceOnce(
  'test/marketplace_grid_density_test.dart',
  `    testWidgets('exposes accessible density labels and selection state',
        (tester) async {
      var selected = 0;`,
  `    testWidgets('exposes accessible density labels and selection state',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = 0;`,
  'grid density test uses a viewport that supports 3/4-column selections',
);

replaceOnce(
  'test/marketplace_offer_schedule_test.dart',
  `    await tester.tap(find.text('Make counter offer'));
    await tester.pumpAndSettle();

    expect(decision, MarketplaceOfferDecision.counter);`,
  `    final counterButton = find.text('Make counter offer');
    await tester.ensureVisible(counterButton);
    await tester.pumpAndSettle();
    await tester.tap(counterButton);
    await tester.pumpAndSettle();

    expect(decision, MarketplaceOfferDecision.counter);`,
  'offer review scrolls action into the mobile viewport before tapping',
);

console.log('Final release test harness repairs applied.');
