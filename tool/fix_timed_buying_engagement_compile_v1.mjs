import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const relative = 'lib/marketplace/marketplace_timed_buying_engagement.dart';
const target = path.join(process.cwd(), relative);
if (!fs.existsSync(target)) throw new Error(`Missing ${relative}`);

let source = fs.readFileSync(target, 'utf8');
source = source.replace(
  'Radius.circular(math.max(2, radius - 4)),',
  'Radius.circular(math.max(2.0, radius - 4).toDouble()),',
);
if (!source.includes('math.max(2.0, radius - 4).toDouble()')) {
  throw new Error('Timed Buying attention painter compile correction was not applied.');
}
fs.writeFileSync(target, source, 'utf8');
console.log(`updated ${relative}`);
