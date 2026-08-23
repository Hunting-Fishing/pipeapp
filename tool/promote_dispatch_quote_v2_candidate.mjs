import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const expectedBranch = 'design/formal-beautification-foundation';

function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function currentBranch() {
  const head = fs.readFileSync(path.join(repoRoot, '.git', 'HEAD'), 'utf8').trim();
  const prefix = 'ref: refs/heads/';
  return head.startsWith(prefix) ? head.slice(prefix.length) : '';
}

if (currentBranch() !== expectedBranch) {
  fail(`Quote V2 candidate promotion requires ${expectedBranch}.`);
}

const candidate = {
  repository: path.join(repoRoot, 'lib', 'marketplace', 'pipebuyer_dispatch_repository_quote_v2_preflight.dart'),
  dashboard: path.join(repoRoot, 'lib', 'marketplace', 'pipebuyer_dispatch_dashboard_quote_v2_preflight.dart'),
  page: path.join(repoRoot, 'lib', 'marketplace', 'pipebuyer_dispatch_page_quote_v2_preflight.dart'),
  policy: path.join(repoRoot, 'firebase', 'functions', 'dispatch_command_policy_quote_v2_preflight.js'),
  commands: path.join(repoRoot, 'firebase', 'functions', 'dispatch_commands_quote_v2_preflight.js'),
};
const production = {
  repository: path.join(repoRoot, 'lib', 'marketplace', 'marketplace_dispatch_repository.dart'),
  dashboard: path.join(repoRoot, 'lib', 'marketplace', 'marketplace_dispatch_dashboard.dart'),
  page: path.join(repoRoot, 'lib', 'marketplace', 'marketplace_dispatch_page.dart'),
  policy: path.join(repoRoot, 'firebase', 'functions', 'dispatch_command_policy.js'),
  commands: path.join(repoRoot, 'firebase', 'functions', 'dispatch_commands.js'),
};

for (const filePath of Object.values(candidate)) {
  if (!fs.existsSync(filePath)) fail(`Candidate file is missing: ${filePath}`);
}

const promoted = {
  repository: fs.readFileSync(candidate.repository, 'utf8'),
  dashboard: fs
    .readFileSync(candidate.dashboard, 'utf8')
    .replace(
      "import 'pipebuyer_dispatch_repository_quote_v2_preflight.dart';",
      "import 'marketplace_dispatch_repository.dart';",
    ),
  page: fs
    .readFileSync(candidate.page, 'utf8')
    .replace(
      "import 'pipebuyer_dispatch_repository_quote_v2_preflight.dart';",
      "import 'marketplace_dispatch_repository.dart';",
    )
    .replace(
      "import 'pipebuyer_dispatch_dashboard_quote_v2_preflight.dart';",
      "import 'marketplace_dispatch_dashboard.dart';",
    ),
  policy: fs.readFileSync(candidate.policy, 'utf8'),
  commands: fs
    .readFileSync(candidate.commands, 'utf8')
    .replace(
      'require("./dispatch_command_policy_quote_v2_preflight")',
      'require("./dispatch_command_policy")',
    ),
};

for (const [key, source] of Object.entries(promoted)) {
  if (source.includes('quote_v2_preflight')) {
    fail(`Preflight dependency leaked into promoted ${key} source.`);
  }
}
if (promoted.dashboard.includes('class _DispatchQuoteDialog extends StatefulWidget')) {
  fail('Retired Dashboard Quote V1 editor is still present in promoted source.');
}
if (promoted.dashboard.includes('class _DispatchUnitRequirementDraft')) {
  fail('Unreferenced Dispatch unit requirement draft leaked into promoted source.');
}
if (!promoted.dashboard.includes('MarketplaceDispatchQuoteForm.show(')) {
  fail('Reusable Quote V2 form wiring is missing from promoted Dashboard source.');
}
if (!promoted.page.includes('MarketplaceDispatchQuoteForm.show(')) {
  fail('Reusable Quote V2 form wiring is missing from promoted Jobs source.');
}

for (const [key, filePath] of Object.entries(production)) {
  fs.writeFileSync(filePath, promoted[key], 'utf8');
}

console.log('PIPE BUYER QUOTE V2 EXACT CANDIDATE PROMOTED');
console.log('Analyzed repository candidate promoted: YES');
console.log('Analyzed Dashboard candidate promoted: YES');
console.log('Analyzed Jobs candidate promoted: YES');
console.log('Candidate Functions policy/command promoted: YES');
console.log('Preflight-only imports leaked to production: NO');
