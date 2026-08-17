import fs from 'node:fs';

const repairPath = 'tool/apply_dispatch_quote_planner_source_map_units.mjs';
const source = fs.readFileSync(repairPath, 'utf8');

const broken = "  const matches = [...source.matchAll(pattern)];";
const fixed = [
  "  const globalFlags = pattern.flags.includes('g') ? pattern.flags : `${pattern.flags}g`;",
  "  const globalPattern = new RegExp(pattern.source, globalFlags);",
  "  const matches = [...source.matchAll(globalPattern)];",
].join('\n');

if (source.includes(fixed)) {
  console.log('Dispatch quote planner matchAll preflight already repaired.');
  process.exit(0);
}

const count = source.split(broken).length - 1;
if (count !== 1) {
  throw new Error(
    `Expected exactly one broken matchAll helper target, found ${count}. Stop instead of guessing.`,
  );
}

fs.writeFileSync(repairPath, source.replace(broken, fixed), 'utf8');
console.log('Repaired Dispatch quote planner RegExp matching helper for Node.js 22.');
