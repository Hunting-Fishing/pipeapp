import fs from 'node:fs';

const repairPath = 'tool/apply_dispatch_quote_planner_source_map_units.mjs';
let source = fs.readFileSync(repairPath, 'utf8');
let changed = false;

const brokenMatchAll = "  const matches = [...source.matchAll(pattern)];";
const fixedMatchAll = [
  "  const globalFlags = pattern.flags.includes('g') ? pattern.flags : `${pattern.flags}g`;",
  "  const globalPattern = new RegExp(pattern.source, globalFlags);",
  "  const matches = [...source.matchAll(globalPattern)];",
].join('\n');

if (source.includes(brokenMatchAll)) {
  const count = source.split(brokenMatchAll).length - 1;
  if (count !== 1) {
    throw new Error(
      `Expected exactly one broken matchAll helper target, found ${count}. Stop instead of guessing.`,
    );
  }
  source = source.replace(brokenMatchAll, fixedMatchAll);
  changed = true;
  console.log('Repaired Dispatch quote planner RegExp matching helper for Node.js 22.');
} else if (!source.includes(fixedMatchAll)) {
  throw new Error(
    'Dispatch quote planner matchAll helper is neither the known broken nor known repaired form. Stop instead of guessing.',
  );
} else {
  console.log('Dispatch quote planner matchAll helper already repaired.');
}

function escapeDartInterpolationBlock(name, startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  if (start < 0) {
    throw new Error(`Missing ${name} template start marker. Stop instead of guessing.`);
  }
  const bodyStart = start + startMarker.length;
  const end = source.indexOf(endMarker, bodyStart);
  if (end < 0) {
    throw new Error(`Missing ${name} template end marker. Stop instead of guessing.`);
  }

  const body = source.slice(bodyStart, end);
  const repaired = body.replace(/(?<!\\)\$\{/g, '\\${');
  if (repaired !== body) {
    source = source.slice(0, bodyStart) + repaired + source.slice(end);
    changed = true;
    console.log(`Escaped embedded Dart interpolation in ${name} generator template.`);
  } else {
    console.log(`${name} generator template Dart interpolation already escaped.`);
  }
}

const templateEnd = '`;\n    source = replaceOne(';
escapeDartInterpolationBlock('models', '    const models = `', templateEnd);
escapeDartInterpolationBlock('restore', '    const restore = `', templateEnd);
escapeDartInterpolationBlock('helpers', '    const helpers = `', templateEnd);

for (const marker of [
  "final type = '\\${data['unitTypeCode'] ?? 'hauling_tractor'}';",
  "sourceMode = '\\${widget.template['sourceType'] ?? 'standalone'}' == 'listing'",
  "final title = '\\${listing['title'] ?? 'Selected listing'}'.trim();",
  "child: Text(\n                      '\\${doc.data()['title'] ?? 'Untitled listing'}',",
]) {
  if (!source.includes(marker)) {
    throw new Error(
      `Dispatch quote planner generator interpolation marker is missing after preflight: ${marker}`,
    );
  }
}

if (changed) {
  fs.writeFileSync(repairPath, source, 'utf8');
  console.log('Dispatch quote planner generator compatibility preflight applied.');
} else {
  console.log('Dispatch quote planner generator compatibility preflight already satisfied.');
}
