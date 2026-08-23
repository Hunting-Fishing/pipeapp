import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');
const expectedBranch = 'design/formal-beautification-foundation';

function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function normalizeLf(text) {
  return text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
}

function countOf(text, marker) {
  return text.split(marker).length - 1;
}

function requireExactlyOne(text, marker, label) {
  const count = countOf(text, marker);
  if (count !== 1) {
    fail(`${label}: expected exactly one '${marker}' marker, found ${count}. No guessing.`);
  }
}

function currentBranch() {
  return execFileSync('git', ['branch', '--show-current'], {
    cwd: repoRoot,
    encoding: 'utf8',
  }).trim();
}

function findMatchingParen(text, openIndex) {
  if (text[openIndex] !== '(') fail('Internal parser expected an opening parenthesis.');
  let depth = 0;
  let quote = null;
  let escaped = false;
  let lineComment = false;
  let blockComment = false;

  for (let index = openIndex; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1] ?? '';

    if (lineComment) {
      if (char === '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (char === '*' && next === '/') {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (quote !== null) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char === '\\') {
        escaped = true;
        continue;
      }
      if (char === quote) quote = null;
      continue;
    }
    if (char === '/' && next === '/') {
      lineComment = true;
      index += 1;
      continue;
    }
    if (char === '/' && next === '*') {
      blockComment = true;
      index += 1;
      continue;
    }
    if (char === "'" || char === '"') {
      quote = char;
      continue;
    }
    if (char === '(') depth += 1;
    if (char === ')') {
      depth -= 1;
      if (depth === 0) return index;
    }
  }
  fail('Could not find the matching parenthesis for a bounded Dart widget expression.');
}

function removeLegacyAnalyticsShortcuts(source, label) {
  let text = source;
  const buttonMarker = "label: const Text('Open analytics & alerts'),";
  const titleMarker = "title: 'Analytics & alerts',";
  const cardMarker = '          PipeBuyerSectionCard(';
  const afterMarker = '          const SizedBox(height: 12),';
  let removed = 0;

  while (text.includes(buttonMarker)) {
    const buttonIndex = text.indexOf(buttonMarker);
    const titleIndex = text.lastIndexOf(titleMarker, buttonIndex);
    if (titleIndex < 0) fail(`${label}: Analytics shortcut button has no matching card title.`);
    const start = text.lastIndexOf(cardMarker, titleIndex);
    if (start < 0) fail(`${label}: Could not bound the legacy Analytics shortcut card start.`);
    const endStart = text.indexOf(afterMarker, buttonIndex);
    if (endStart < 0) fail(`${label}: Could not bound the legacy Analytics shortcut card end.`);
    let end = endStart + afterMarker.length;
    if (text[end] === '\n') end += 1;
    text = text.slice(0, start) + text.slice(end);
    removed += 1;
  }

  return { text, removed };
}

const variableReplacement = `    final evidenceRecords =\n        _records.where((record) => record.hasPrivateEvidence).toList();\n    final insurance = _records.where((record) => record.type.isInsurance).toList();\n    final insuranceWithLimits = insurance\n        .where(\n          (record) => record.isCurrentOn(now) && record.hasDeclaredCoverage,\n        )\n        .toList();\n    final insuredWithLimits = insuranceWithLimits.length;\n`;

const readinessReplacement = `Wrap(\n                spacing: 10,\n                runSpacing: 10,\n                children: [\n                  _metricTile(\n                    label: 'Current',\n                    records: current,\n                    icon: Icons.check_circle_outline,\n                    emptyMessage: 'No credentials are currently marked current.',\n                  ),\n                  _metricTile(\n                    label: 'Expired',\n                    records: expired,\n                    icon: Icons.event_busy_outlined,\n                    emptyMessage: 'No supplied credential is currently expired.',\n                  ),\n                  _metricTile(\n                    label: 'Not provided',\n                    records: missing,\n                    icon: Icons.help_outline,\n                    emptyMessage: 'Every credential record has been addressed.',\n                  ),\n                  _metricTile(\n                    label: 'Evidence files',\n                    records: evidenceRecords,\n                    icon: Icons.lock_outline,\n                    emptyMessage: 'No private credential evidence is currently on file.',\n                  ),\n                  _metricTile(\n                    label: 'Insurance limits',\n                    records: insuranceWithLimits,\n                    icon: Icons.shield_outlined,\n                    emptyMessage: 'No current insurance record has a declared primary coverage limit.',\n                  ),\n                ],\n              )`;

const helperText = `const Text(\n                'Select any status tile below to see the credential records behind the number and take action.',\n                style: TextStyle(\n                  color: PipeBuyerColors.muted,\n                  fontSize: 12,\n                ),\n              ),\n              const SizedBox(height: 12),\n              `;

const metricReplacement = `  String _analyticsRecordSummary(DispatchCredentialRecord record) {\n    final parts = <String>[record.state.label];\n    if (record.expiryDate != null) parts.add('Expiry \${record.expiryLabel}');\n    if (record.hasDeclaredCoverage) parts.add(record.coverageLabel);\n    parts.add(\n      record.hasPrivateEvidence\n          ? 'Private evidence on file'\n          : 'No private evidence',\n    );\n    return parts.join(' | ');\n  }\n\n  String _metricExplanation(String label) => switch (label) {\n        'Current' =>\n          'Credentials currently marked current from your private self-reported records.',\n        'Expired' =>\n          'Credentials marked expired or whose supplied expiry date has passed.',\n        'Not provided' =>\n          'Credential categories that still need a status or supporting information.',\n        'Evidence files' =>\n          'Credential records with a private supporting image on file. These files are not public verification.',\n        'Insurance limits' =>\n          'Current insurance records with a declared primary coverage limit for future private matching.',\n        _ => 'Credential records included in this private analytics total.',\n      };\n\n  Future<void> _showCredentialMetricDetails({\n    required String label,\n    required List<DispatchCredentialRecord> records,\n    required IconData icon,\n    required String emptyMessage,\n  }) async {\n    await showModalBottomSheet<void>(\n      context: context,\n      isScrollControlled: true,\n      showDragHandle: true,\n      builder: (sheetContext) {\n        final listHeight = records.isEmpty\n            ? 96.0\n            : (records.length * 82.0).clamp(96.0, 410.0).toDouble();\n        return SafeArea(\n          child: Padding(\n            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),\n            child: Column(\n              mainAxisSize: MainAxisSize.min,\n              crossAxisAlignment: CrossAxisAlignment.start,\n              children: [\n                Row(\n                  children: [\n                    Icon(icon, color: PipeBuyerColors.orange),\n                    const SizedBox(width: 10),\n                    Expanded(\n                      child: Text(\n                        '$label (\${records.length})',\n                        style: const TextStyle(\n                          fontSize: 20,\n                          fontWeight: FontWeight.w900,\n                        ),\n                      ),\n                    ),\n                  ],\n                ),\n                const SizedBox(height: 6),\n                Text(_metricExplanation(label)),\n                const SizedBox(height: 12),\n                SizedBox(\n                  height: listHeight,\n                  child: records.isEmpty\n                      ? Center(child: Text(emptyMessage))\n                      : ListView.separated(\n                          itemCount: records.length,\n                          separatorBuilder: (_, __) => const Divider(height: 1),\n                          itemBuilder: (context, index) {\n                            final record = records[index];\n                            return ListTile(\n                              contentPadding: EdgeInsets.zero,\n                              leading: Icon(record.type.icon),\n                              title: Text(record.type.label),\n                              subtitle: Text(_analyticsRecordSummary(record)),\n                              trailing:\n                                  const Icon(Icons.chevron_right_rounded),\n                              onTap: () {\n                                Navigator.of(sheetContext).pop();\n                                Future<void>.delayed(Duration.zero, () async {\n                                  if (!mounted) return;\n                                  await _showCredentialQuickActions(record);\n                                });\n                              },\n                            );\n                          },\n                        ),\n                ),\n              ],\n            ),\n          ),\n        );\n      },\n    );\n  }\n\n  Future<void> _showCredentialQuickActions(\n    DispatchCredentialRecord record,\n  ) async {\n    final action = await showDialog<String>(\n      context: context,\n      builder: (dialogContext) => AlertDialog(\n        title: Text(record.type.label),\n        content: Column(\n          mainAxisSize: MainAxisSize.min,\n          crossAxisAlignment: CrossAxisAlignment.start,\n          children: [\n            Text(_analyticsRecordSummary(record)),\n            if (record.issuer.isNotEmpty) ...[\n              const SizedBox(height: 8),\n              Text('Issuer: \${record.issuer}'),\n            ],\n            if (record.hasPrivateEvidence) ...[\n              const SizedBox(height: 8),\n              const Text(\n                'Private evidence is on file for this credential. You can replace or remove it here.',\n              ),\n            ],\n          ],\n        ),\n        actions: [\n          TextButton(\n            onPressed: () => Navigator.of(dialogContext).pop(),\n            child: const Text('Close'),\n          ),\n          if (record.hasPrivateEvidence)\n            TextButton(\n              onPressed: () =>\n                  Navigator.of(dialogContext).pop('remove_evidence'),\n              child: const Text('Remove evidence'),\n            ),\n          OutlinedButton(\n            onPressed: () => Navigator.of(dialogContext).pop('evidence'),\n            child: Text(\n              record.hasPrivateEvidence ? 'Replace evidence' : 'Upload evidence',\n            ),\n          ),\n          FilledButton(\n            onPressed: () => Navigator.of(dialogContext).pop('edit'),\n            child: const Text('Edit metadata'),\n          ),\n        ],\n      ),\n    );\n    if (!mounted || action == null) return;\n    switch (action) {\n      case 'edit':\n        await _editMetadata(record);\n        break;\n      case 'evidence':\n        await _uploadEvidence(record);\n        break;\n      case 'remove_evidence':\n        await _removeEvidence(record);\n        break;\n    }\n  }\n\n  Widget _metricTile({\n    required String label,\n    required List<DispatchCredentialRecord> records,\n    required IconData icon,\n    required String emptyMessage,\n  }) {\n    final value = records.length;\n    return Semantics(\n      button: true,\n      label: '$label: $value. View credential details.',\n      child: SizedBox(\n        width: 190,\n        child: Material(\n          color: Theme.of(context).colorScheme.surfaceContainerHighest,\n          borderRadius: BorderRadius.circular(12),\n          child: InkWell(\n            borderRadius: BorderRadius.circular(12),\n            onTap: () {\n              _showCredentialMetricDetails(\n                label: label,\n                records: records,\n                icon: icon,\n                emptyMessage: emptyMessage,\n              );\n            },\n            child: Padding(\n              padding: const EdgeInsets.all(12),\n              child: Row(\n                children: [\n                  Icon(icon, size: 20),\n                  const SizedBox(width: 8),\n                  Expanded(\n                    child: Column(\n                      crossAxisAlignment: CrossAxisAlignment.start,\n                      children: [\n                        Text(\n                          '$value',\n                          style: const TextStyle(\n                            fontSize: 18,\n                            fontWeight: FontWeight.w900,\n                          ),\n                        ),\n                        Text(\n                          label,\n                          style: Theme.of(context).textTheme.bodySmall,\n                        ),\n                        const SizedBox(height: 2),\n                        const Text(\n                          'View details',\n                          style: TextStyle(\n                            color: PipeBuyerColors.orange,\n                            fontSize: 11,\n                            fontWeight: FontWeight.w800,\n                          ),\n                        ),\n                      ],\n                    ),\n                  ),\n                  const Icon(Icons.chevron_right_rounded, size: 18),\n                ],\n              ),\n            ),\n          ),\n        ),\n      ),\n    );\n  }\n`;

function transform(source, label) {
  let text = normalizeLf(source);
  for (const marker of [
    "text: 'Analytics & alerts'",
    "title: 'Credential readiness'",
    'Widget _metricTile',
    'final insuredWithLimits',
  ]) {
    if (!text.includes(marker)) fail(`${label}: missing required semantic marker '${marker}'.`);
  }

  const cleanup = removeLegacyAnalyticsShortcuts(text, label);
  text = cleanup.text;

  const fullyInteractive = [
    'Future<void> _showCredentialMetricDetails',
    'Future<void> _showCredentialQuickActions',
    "const Text('View details')",
    'final evidenceRecords =',
    'final insuranceWithLimits =',
    'records: current',
    'records: evidenceRecords',
  ].every((marker) => text.includes(marker));

  if (!fullyInteractive) {
    if (!text.includes('final evidenceRecords =')) {
      requireExactlyOne(text, 'final evidenceCount', `${label} evidence-count source`);
      requireExactlyOne(text, 'final upcoming', `${label} upcoming-expiry boundary`);
      const start = text.indexOf('final evidenceCount');
      const end = text.indexOf('final upcoming', start);
      if (end <= start) fail(`${label}: could not bound analytics collection variables.`);
      const lineStart = text.lastIndexOf('\n', start) + 1;
      const endLineStart = text.lastIndexOf('\n', end) + 1;
      text = text.slice(0, lineStart) + variableReplacement + text.slice(endLineStart);
    }

    if (!text.includes('records: current')) {
      const readinessTitle = text.indexOf("title: 'Credential readiness'");
      const expiryTitle = text.indexOf("title: 'Expiry reminders'", readinessTitle);
      if (readinessTitle < 0 || expiryTitle < 0) {
        fail(`${label}: could not bound Credential readiness before Expiry reminders.`);
      }
      const currentMetricIndex = text.indexOf('_metricTile', readinessTitle);
      if (currentMetricIndex < 0 || currentMetricIndex > expiryTitle) {
        fail(`${label}: old readiness metric calls were not found inside Credential readiness.`);
      }
      const wrapIndex = text.lastIndexOf('Wrap(', currentMetricIndex);
      if (wrapIndex < readinessTitle) fail(`${label}: could not locate readiness metric Wrap.`);
      const openParen = wrapIndex + 'Wrap'.length;
      const closeParen = findMatchingParen(text, openParen);
      if (closeParen > expiryTitle) fail(`${label}: readiness metric Wrap escaped its section boundary.`);
      text = text.slice(0, wrapIndex) + helperText + readinessReplacement + text.slice(closeParen + 1);
    }

    if (!text.includes('Future<void> _showCredentialMetricDetails')) {
      const startMarker = '  Widget _metricTile(';
      const endMarker = '  Widget _credentialCard(';
      requireExactlyOne(text, startMarker, `${label} legacy metric widget`);
      requireExactlyOne(text, endMarker, `${label} credential-card boundary`);
      const start = text.indexOf(startMarker);
      const end = text.indexOf(endMarker, start);
      if (end <= start) fail(`${label}: could not bound the legacy metric widget.`);
      text = text.slice(0, start) + metricReplacement + '\n' + text.slice(end);
    }
  }

  const requiredAfter = [
    "text: 'Analytics & alerts'",
    "title: 'Credential readiness'",
    'Select any status tile below',
    'Future<void> _showCredentialMetricDetails',
    'Future<void> _showCredentialQuickActions',
    "const Text('View details')",
    'button: true',
    'records: current',
    'records: expired',
    'records: missing',
    'records: evidenceRecords',
    'records: insuranceWithLimits',
    "pop('edit')",
    "pop('evidence')",
    "pop('remove_evidence')",
  ];
  for (const marker of requiredAfter) {
    if (!text.includes(marker)) fail(`${label}: transformed source is missing '${marker}'.`);
  }
  if (text.includes('Open analytics & alerts')) {
    fail(`${label}: duplicate Records-view Analytics shortcut remains after normalization.`);
  }

  return { text, removedShortcuts: cleanup.removed, alreadyInteractive: fullyInteractive };
}

const branch = currentBranch();
if (branch !== expectedBranch) {
  fail(`Wrong branch. Expected ${expectedBranch}, found ${branch}.`);
}

const targets = [
  path.join(repoRoot, 'lib', 'marketplace', 'marketplace_dispatch_credentials.dart'),
  path.join(repoRoot, 'tool', 'templates', 'marketplace_dispatch_credentials_intelligence.dart.txt'),
];
for (const target of targets) {
  if (!fs.existsSync(target)) fail(`Required credential analytics file is missing: ${target}`);
}

// Preflight every transformation entirely in memory. Nothing is written unless
// both the live Dart source and its canonical template reach the same required
// semantic contract.
const planned = targets.map((target) => ({
  target,
  result: transform(fs.readFileSync(target, 'utf8'), path.basename(target)),
}));

const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
const backupDir = path.join(repoRoot, '_local_backups', `dispatch-credential-analytics-actions-v4-${stamp}`);
fs.mkdirSync(backupDir, { recursive: true });
for (const { target } of planned) {
  fs.copyFileSync(target, path.join(backupDir, path.basename(target)));
}
console.log(`Backup created: ${backupDir}`);

for (const { target, result } of planned) {
  fs.writeFileSync(target, result.text, 'utf8');
  const status = result.alreadyInteractive ? 'already interactive' : 'normalized';
  console.log(`${path.basename(target)}: ${status}; removed shortcut cards: ${result.removedShortcuts}`);
}

console.log('Credential analytics semantic preflight: PASS');
console.log('No production file was written until both source transformations validated: PASS');
console.log('Dispatch tracker modified: NO');
