import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

import {
  loadDispatchQuoteV2Files,
  transformDispatchQuoteV2Foundation,
} from './dispatch_quote_v2_foundation_transform_v2.mjs';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const {files} = loadDispatchQuoteV2Files();
const transformed = transformDispatchQuoteV2Foundation(files);

const output = {
  repository: path.join(
    repoRoot,
    'lib',
    'marketplace',
    'pipebuyer_dispatch_repository_quote_v2_preflight.dart',
  ),
  dashboard: path.join(
    repoRoot,
    'lib',
    'marketplace',
    'pipebuyer_dispatch_dashboard_quote_v2_preflight.dart',
  ),
  page: path.join(
    repoRoot,
    'lib',
    'marketplace',
    'pipebuyer_dispatch_page_quote_v2_preflight.dart',
  ),
  policy: path.join(
    repoRoot,
    'firebase',
    'functions',
    'dispatch_command_policy_quote_v2_preflight.js',
  ),
  commands: path.join(
    repoRoot,
    'firebase',
    'functions',
    'dispatch_commands_quote_v2_preflight.js',
  ),
};

let dashboard = transformed.dashboard.replace(
  "import 'marketplace_dispatch_repository.dart';",
  "import 'pipebuyer_dispatch_repository_quote_v2_preflight.dart';",
);
if (!dashboard.includes("import 'pipebuyer_dispatch_repository_quote_v2_preflight.dart';")) {
  throw new Error('STOP: Candidate dashboard repository import was not isolated.');
}

let page = transformed.page
  .replace(
    "import 'marketplace_dispatch_repository.dart';",
    "import 'pipebuyer_dispatch_repository_quote_v2_preflight.dart';",
  )
  .replace(
    "import 'marketplace_dispatch_dashboard.dart';",
    "import 'pipebuyer_dispatch_dashboard_quote_v2_preflight.dart';",
  );
if (!page.includes("import 'pipebuyer_dispatch_repository_quote_v2_preflight.dart';") ||
    !page.includes("import 'pipebuyer_dispatch_dashboard_quote_v2_preflight.dart';")) {
  throw new Error('STOP: Candidate Dispatch page imports were not isolated.');
}

const commands = transformed.commands.replace(
  'require("./dispatch_command_policy")',
  'require("./dispatch_command_policy_quote_v2_preflight")',
);

fs.writeFileSync(output.repository, transformed.repository, 'utf8');
fs.writeFileSync(output.dashboard, dashboard, 'utf8');
fs.writeFileSync(output.page, page, 'utf8');
fs.writeFileSync(output.policy, transformed.policy, 'utf8');
fs.writeFileSync(output.commands, commands, 'utf8');

console.log('PIPE BUYER DISPATCH QUOTE V2 CANDIDATE BUILT');
for (const [key, value] of Object.entries(output)) {
  console.log(`${key}: ${path.relative(repoRoot, value)}`);
}
console.log('Production source modified by candidate builder: NO');
