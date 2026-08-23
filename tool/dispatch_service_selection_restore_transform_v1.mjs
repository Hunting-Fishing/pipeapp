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

function branch() {
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

const currentBranch = branch();
if (currentBranch && currentBranch !== 'design/formal-beautification-foundation') {
  fail(`Wrong branch: ${currentBranch}`);
}

const pagePath = 'lib/marketplace/marketplace_dispatch_page.dart';
const directoryPath = 'lib/marketplace/marketplace_dispatch_directory.dart';

let page = read(pagePath);
let directory = read(directoryPath);

function transformPage(source) {
  let output = source;
  const selectorImport = "import 'marketplace_dispatch_multi_service_selector.dart';";
  if (!output.includes(selectorImport)) {
    const anchor = "import 'marketplace_dispatch_navigation.dart';";
    if (!output.includes(anchor)) fail('Request Service navigation import anchor is missing.');
    output = output.replace(anchor, `${anchor}\n${selectorImport}`);
  }

  const classStart = output.indexOf('class _PostJobState extends State<_PostJob> {');
  const classEnd = output.indexOf('class _MappedJobLocationField', classStart);
  if (classStart < 0 || classEnd < 0) fail('Could not isolate the existing Request Service _PostJobState.');
  let before = output.slice(0, classStart);
  let block = output.slice(classStart, classEnd);
  const after = output.slice(classEnd);

  if (!block.includes('List<String> requestedServiceCodes')) {
    const anchor = '  final details = TextEditingController();\n';
    if (!block.includes(anchor)) fail('Request Service details-controller anchor is missing.');
    block = block.replace(
      anchor,
      `${anchor}  List<String> requestedServiceCodes = <String>[];\n`,
    );
  }

  if (!block.includes('MarketplaceDispatchMultiServiceSelector(')) {
    const anchor = '          const SizedBox(height: 14),\n          Card(\n';
    if (!block.includes(anchor)) fail('Request Service listing-card anchor is missing.');
    const insertion = `          const SizedBox(height: 14),\n          Card(\n            color: const Color(0xFFF8FAFC),\n            child: Padding(\n              padding: const EdgeInsets.all(14),\n              child: MarketplaceDispatchMultiServiceSelector(\n                initialServiceCodes: requestedServiceCodes,\n                onChanged: (values) =>\n                    setState(() => requestedServiceCodes = values),\n                label: 'Choose service(s)',\n                helperText:\n                    'Keep the existing transportation request below, but select the actual work needed first — Hotshot, crane, pilot, road work, mobile service and more.',\n              ),\n            ),\n          ),\n          const SizedBox(height: 14),\n          Card(\n`;
    block = block.replace(anchor, insertion);
  }

  if (!block.includes("message: 'Choose at least one service before publishing this request.'")) {
    const anchor = '                    if (!form.currentState!.validate()) return;\n';
    if (!block.includes(anchor)) fail('Request Service publish validation anchor is missing.');
    const insertion = `${anchor}                    if (requestedServiceCodes.isEmpty) {\n                      PipeFeedback.show(\n                        context,\n                        message: 'Choose at least one service before publishing this request.',\n                        tone: PipeStatusTone.warning,\n                      );\n                      return;\n                    }\n`;
    block = block.replace(anchor, insertion);
  }

  if (!block.includes('loadDetails: _requestDetailsWithServices(')) {
    const anchor = '                        loadDetails: details.text.trim(),\n';
    if (!block.includes(anchor)) fail('Request Service createJob load-details anchor is missing.');
    block = block.replace(
      anchor,
      '                        loadDetails: _requestDetailsWithServices(details.text.trim()),\n',
    );
  }

  if (!block.includes('String _requestDetailsWithServices(String requestDetails)')) {
    const anchor = '  Future<void> _choosePickup() async {\n';
    if (!block.includes(anchor)) fail('Request Service helper insertion anchor is missing.');
    const helper = `  String _requestDetailsWithServices(String requestDetails) {\n    final services = requestedServiceCodes\n        .map(dispatchServiceLabelForCode)\n        .join(', ');\n    return 'Services requested: $services\\n$requestDetails';\n  }\n\n`;
    block = block.replace(anchor, `${helper}${anchor}`);
  }

  if (!block.includes("'Select a listing for quote'")) {
    fail('Existing listing-to-quote workflow was removed from Request Service.');
  }
  if (!block.includes('MarketplaceFreightQuote.show(')) {
    fail('Existing MarketplaceFreightQuote workflow was removed from Request Service.');
  }

  return `${before}${block}${after}`;
}

function transformDirectory(source) {
  let output = source;
  if (output.includes('serviceCodes: entry.serviceCodes,')) return output;
  const start = output.indexOf('MarketplaceDispatchDirectoryBusinessActions(');
  if (start < 0) fail('Directory functional action surface from D1 is missing.');
  const end = output.indexOf('),', start);
  if (end < 0) fail('Could not isolate the Directory action invocation.');
  const block = output.slice(start, end + 2);
  const normalized = block.replace(
    /\n\s*serviceCode:\s*\n?\s*entry\.serviceCodes\.isEmpty\s*\?\s*''\s*:\s*entry\.serviceCodes\.first,?/, 
    '\n              serviceCodes: entry.serviceCodes,',
  );
  if (normalized === block || !normalized.includes('serviceCodes: entry.serviceCodes,')) {
    fail('Could not upgrade the Directory action call from one service to the provider service list.');
  }
  return output.slice(0, start) + normalized + output.slice(end + 2);
}

page = transformPage(page);
directory = transformDirectory(directory);

for (const marker of [
  'MarketplaceDispatchMultiServiceSelector(',
  "label: 'Choose service(s)'",
  'List<String> requestedServiceCodes',
  'Services requested: $services',
  "'Select a listing for quote'",
  'MarketplaceFreightQuote.show(',
]) {
  if (!page.includes(marker)) fail(`Transformed Request Service is missing marker: ${marker}`);
}
if (!directory.includes('serviceCodes: entry.serviceCodes,')) {
  fail('Transformed Directory does not pass the full provider service list.');
}

if (apply) {
  write(pagePath, page);
  write(directoryPath, directory);
}

console.log('PIPE BUYER DISPATCH SERVICE SELECTION RESTORE TRANSFORM PASSED');
console.log(`Mode: ${apply ? 'APPLY' : 'DRY RUN'}`);
console.log('Request Service taxonomy selector: PASS');
console.log('Existing listing-to-trucking workflow preserved: PASS');
console.log('Directory passes provider service list to Get Quote: PASS');
