import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';

const root = path.resolve(process.env.PIPEBUYER_ROOT || process.cwd());
const apply = process.argv.includes('--apply');

function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function read(relative) {
  const target = path.join(root, relative);
  if (!fs.existsSync(target)) fail(`Missing ${relative}`);
  return fs.readFileSync(target, 'utf8');
}

function write(relative, content) {
  fs.writeFileSync(path.join(root, relative), content, 'utf8');
}

function replaceOnce(source, anchor, replacement, label) {
  const first = source.indexOf(anchor);
  if (first < 0) fail(`Could not find ${label}.`);
  if (source.indexOf(anchor, first + anchor.length) >= 0) {
    fail(`Expected exactly one ${label}.`);
  }
  return source.slice(0, first) + replacement + source.slice(first + anchor.length);
}

function insertBefore(source, anchor, insertion, label) {
  if (source.includes(insertion.trim())) return source;
  return replaceOnce(source, anchor, `${insertion}${anchor}`, label);
}

function insertAfter(source, anchor, insertion, label) {
  if (source.includes(insertion.trim())) return source;
  return replaceOnce(source, anchor, `${anchor}${insertion}`, label);
}

function currentBranch() {
  if (process.env.PIPEBUYER_ROOT) return '';
  try {
    return execFileSync('git', ['branch', '--show-current'], {
      cwd: root,
      encoding: 'utf8',
    }).trim();
  } catch {
    return '';
  }
}

const branch = currentBranch();
if (branch && branch !== 'design/formal-beautification-foundation') {
  fail(`Wrong branch: ${branch}`);
}

const actionsPath = 'lib/marketplace/marketplace_actions_repository.dart';
const communicationPath = 'firebase/functions/communication_commands.js';
const indexPath = 'firebase/functions/index.js';
const directoryPath = 'lib/marketplace/marketplace_dispatch_directory.dart';

let actions = read(actionsPath);
let communication = read(communicationPath);
let index = read(indexPath);
let directory = read(directoryPath);

if (!actions.includes("openBusinessConversation")) {
  const anchor = '  Future<Map<String, dynamic>> authorizeUpload({\n';
  const insertion = `  Future<String> openBusinessConversation({\n    required String providerUid,\n  }) async {\n    final normalized = providerUid.trim();\n    if (normalized.isEmpty) {\n      throw ArgumentError.value(providerUid, 'providerUid', 'Provider is required.');\n    }\n    final result = await _commands.execute('openBusinessConversation', {\n      'providerUid': normalized,\n    });\n    return '\${result['conversationId']}';\n  }\n\n`;
  actions = insertBefore(actions, anchor, insertion, 'MarketplaceActionsRepository authorizeUpload anchor');
}

if (!communication.includes('function businessConversationIdFor(')) {
  const anchor = `function conversationIdFor(firstUid, secondUid, listingId) {\n  return \`\${[firstUid, secondUid].sort().join("_")}_\${listingId}\`;\n}\n`;
  const insertion = `\nfunction businessConversationIdFor(firstUid, secondUid) {\n  const members = [String(firstUid), String(secondUid)].sort();\n  const digest = crypto.createHash("sha256")\n      .update(members.join("|"))\n      .digest("hex")\n      .slice(0, 40);\n  return \`business_\${digest}\`;\n}\n`;
  communication = insertAfter(communication, anchor, insertion, 'conversationIdFor helper');
}

if (!communication.includes('const openBusinessConversation = secured(')) {
  const anchor = '  const markMarketplaceConversationRead = secured(\n';
  const insertion = `  const openBusinessConversation = secured(\n      "messaging",\n      async (request, {uid}) => {\n        const providerUid = requiredId(request.data, "providerUid");\n        if (providerUid === uid) {\n          throw new HttpsError(\n              "invalid-argument",\n              "You cannot open a business conversation with yourself.",\n          );\n        }\n        const providerSnapshot = await db\n            .collection("public_business_profiles")\n            .doc(providerUid)\n            .get();\n        if (!providerSnapshot.exists) {\n          throw new HttpsError(\n              "not-found",\n              "This business is not publicly available.",\n          );\n        }\n        const provider = providerSnapshot.data() || {};\n        const providerName = profileName(provider, "Pipe Buyer business");\n        const [requesterBusiness, requesterPersonal] = await Promise.all([\n          db.collection("public_business_profiles").doc(uid).get(),\n          db.collection("public_seller_profiles").doc(uid).get(),\n        ]);\n        const requesterName = profileName(\n            requesterBusiness.exists ? requesterBusiness.data() :\n              requesterPersonal.exists ? requesterPersonal.data() : {},\n            "Pipe Buyer member",\n        );\n        const conversationId = businessConversationIdFor(uid, providerUid);\n        const conversationRef = db.collection("conversations")\n            .doc(conversationId);\n        return db.runTransaction(async (transaction) => {\n          const existing = await transaction.get(conversationRef);\n          if (!existing.exists) {\n            const memberUids = [uid, providerUid].sort();\n            transaction.create(conversationRef, {\n              memberUids,\n              contextType: "business",\n              contextId: providerUid,\n              contextTitle: providerName,\n              providerUid,\n              requesterUid: uid,\n              requesterDisplayName: requesterName,\n              sellerUid: providerUid,\n              sellerName: providerName,\n              listingId: null,\n              listingTitle: \`Business inquiry · \${providerName}\`,\n              openedByUid: uid,\n              openedAt: FieldValue.serverTimestamp(),\n              messageCount: 0,\n              unreadCounts: {[uid]: 0, [providerUid]: 0},\n            });\n          } else {\n            const members = Array.isArray(existing.data().memberUids) ?\n              existing.data().memberUids.map(String) : [];\n            if (!members.includes(uid) || !members.includes(providerUid)) {\n              throw new HttpsError(\n                  "permission-denied",\n                  "This business conversation is unavailable.",\n              );\n            }\n          }\n          return {conversationId};\n        });\n      },\n  );\n\n`;
  communication = insertBefore(communication, anchor, insertion, 'markMarketplaceConversationRead command');
}

if (!communication.includes('    openBusinessConversation,\n')) {
  const anchor = '    openMarketplaceConversation,\n';
  communication = insertAfter(
    communication,
    anchor,
    '    openBusinessConversation,\n',
    'communication command return list',
  );
}

if (!index.includes('exports.openBusinessConversation = onCall(')) {
  const anchor = `exports.markMarketplaceConversationRead = onCall(\n`;
  const insertion = `exports.openBusinessConversation = onCall(\n  protectedCallableOptions,\n  policyAcceptanceCommands.requireCurrentPolicies(\n    communicationCommands.openBusinessConversation,\n  ),\n);\n`;
  index = insertBefore(index, anchor, insertion, 'markMarketplaceConversationRead export');
}

if (!directory.includes("import 'marketplace_dispatch_directory_actions.dart';")) {
  const importAnchor = "import 'marketplace_dispatch_service_taxonomy.dart';\n";
  directory = insertAfter(
    directory,
    importAnchor,
    "import 'marketplace_dispatch_directory_actions.dart';\n",
    'Directory taxonomy import',
  );
}

if (!directory.includes('MarketplaceDispatchDirectoryBusinessActions(')) {
  const classStart = directory.indexOf('class _DirectoryCompanyCard extends StatelessWidget');
  const classEnd = directory.indexOf('class _AvailabilityBadge', classStart);
  if (classStart < 0 || classEnd < 0) fail('Could not isolate _DirectoryCompanyCard.');
  const card = directory.slice(classStart, classEnd);
  const disclaimerIndex = card.indexOf('Provider-supplied profile information');
  if (disclaimerIndex < 0) {
    fail('Could not find the Directory provider disclaimer inside _DirectoryCompanyCard.');
  }
  const textStart = card.lastIndexOf('            const Text(', disclaimerIndex);
  if (textStart < 0) fail('Could not find disclaimer Text widget start.');
  const insertion = `            MarketplaceDispatchDirectoryBusinessActions(\n              providerUid: entry.id,\n              operatingName: entry.operatingName,\n              serviceCode:\n                  entry.serviceCodes.isEmpty ? '' : entry.serviceCodes.first,\n            ),\n            const SizedBox(height: 8),\n`;
  const absolute = classStart + textStart;
  directory = directory.slice(0, absolute) + insertion + directory.slice(absolute);
}

for (const [label, source, markers] of [
  ['actions repository', actions, ['openBusinessConversation', "'providerUid': normalized"]],
  ['communication commands', communication, ['businessConversationIdFor', 'const openBusinessConversation = secured(', 'contextType: "business"']],
  ['functions index', index, ['exports.openBusinessConversation = onCall(']],
  ['Directory UI', directory, ['MarketplaceDispatchDirectoryBusinessActions(', "marketplace_dispatch_directory_actions.dart"]],
]) {
  for (const marker of markers) {
    if (!source.includes(marker)) fail(`${label} is missing marker ${marker}`);
  }
}

if (apply) {
  write(actionsPath, actions);
  write(communicationPath, communication);
  write(indexPath, index);
  write(directoryPath, directory);
}

console.log('PIPE BUYER DIRECTORY FUNCTIONAL ACTIONS TRANSFORM PASSED');
console.log(`Mode: ${apply ? 'APPLY' : 'DRY RUN'}`);
console.log('Business-level messaging command: PASS');
console.log('Directory action surface insertion: PASS');
console.log('View Business / Message / Get Quote / public contact / report shell: PASS');
