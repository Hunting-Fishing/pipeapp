import fs from 'node:fs';

const path = 'lib/marketplace/marketplace_dispatch_page.dart';
let source = fs.readFileSync(path, 'utf8');

function replaceOnce(oldValue, newValue, label) {
  const count = source.split(oldValue).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one marker, found ${count}`);
  }
  source = source.replace(oldValue, newValue);
}

function insertBeforeOnce(marker, insertion, label) {
  const count = source.split(marker).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one marker, found ${count}`);
  }
  source = source.replace(marker, `${insertion}${marker}`);
}

if (!source.includes("import 'marketplace_dispatch_quote_validity.dart';")) {
  replaceOnce(
      "import 'marketplace_dispatch_repository.dart';\n",
      "import 'marketplace_dispatch_repository.dart';\nimport 'marketplace_dispatch_quote_validity.dart';\n",
      'quote validity import',
  );
}

replaceOnce(
    `                        subtitle: Text(\n                          '\${data['vehicleName'] ?? 'Fleet vehicle'} • \${('\${data['status'] ?? 'pending'}').toUpperCase()}\\n\${data['note'] ?? ''}',\n                        ),`,
    `                        subtitle: Text(\n                          '\${data['vehicleName'] ?? 'Fleet vehicle'} • \${('\${data['status'] ?? 'pending'}').toUpperCase()} • Version \${dispatchQuoteVersion(data)}\\n\${dispatchQuoteValidityStatus(data) == 'cancelled' ? 'QUOTE CANCELLED - NO LONGER VALID\\n' : ''}\${data['note'] ?? ''}',\n                        ),`,
    'my quote history version label',
);

replaceOnce(
    `                        subtitle: Text(\n                          '\${data['vehicleName'] ?? 'Fleet vehicle'} • \${('\${data['status'] ?? 'pending'}').toUpperCase()} • \${data['revision'] ?? 1} revision(s)\\n\${data['note'] ?? ''}',\n                        ),`,
    `                        subtitle: Text(\n                          '\${data['vehicleName'] ?? 'Fleet vehicle'} • \${('\${data['status'] ?? 'pending'}').toUpperCase()} • Version \${dispatchQuoteVersion(data)}\\n\${dispatchQuoteValidityStatus(data) == 'cancelled' ? 'QUOTE CANCELLED - NO LONGER VALID\\n' : ''}\${data['note'] ?? ''}',\n                        ),`,
    'customer bid version label',
);

replaceOnce(
    `                                title:\n                                    '\${data['carrierName'] ?? 'Carrier'} quote history',\n                                query: () => repo.bidHistoryQuery(bid.id),\n                                amountLabel: 'Quoted total',`,
    `                                title:\n                                    '\${data['carrierName'] ?? 'Carrier'} quote history',\n                                query: () => repo.bidHistoryQuery(bid.id),\n                                amountLabel: 'Quoted total',\n                                currentQuote: data,`,
    'customer quote history authoritative state',
);

replaceOnce(
    `                            if (data['status'] == 'pending')`,
    `                            if (dispatchQuoteIsCurrentAndAwardable(data))`,
    'customer select validity guard',
);

replaceOnce(
    `    final jobData = job.data() ?? const <String, dynamic>{};\n    final data = bid.data();\n    await showModalBottomSheet<void>(`,
    `    final jobData = job.data() ?? const <String, dynamic>{};\n    final data = bid.data();\n    final quoteVersion = dispatchQuoteVersion(data);\n    final quoteValidity = dispatchQuoteValidityStatus(data);\n    final quoteCancelled = quoteValidity == 'cancelled';\n    await showModalBottomSheet<void>(`,
    'carrier quote validity locals',
);

replaceOnce(
    `                Card(\n                  color: const Color(0xFFEAF4FD),\n                  child: ListTile(`,
    `                Card(\n                  color: quoteCancelled\n                      ? const Color(0xFFFFEBEE)\n                      : const Color(0xFFEAF4FD),\n                  child: ListTile(`,
    'carrier quote invalid card color',
);

replaceOnce(
    `                    subtitle: Text(\n                      '\${data['vehicleName'] ?? 'Fleet vehicle'} • \${('\${data['status'] ?? 'pending'}').toUpperCase()}\\n\${data['note'] ?? ''}',\n                    ),\n                    isThreeLine: true,\n                    trailing: Chip(label: Text('REV \${data['revision'] ?? 1}')),`,
    `                    subtitle: Text(\n                      '\${data['vehicleName'] ?? 'Fleet vehicle'} • \${('\${data['status'] ?? 'pending'}').toUpperCase()}\\nVersion $quoteVersion • \${quoteCancelled ? 'CANCELLED - NO LONGER VALID' : 'Current server validity: ACTIVE'}\\n\${data['note'] ?? ''}',\n                    ),\n                    isThreeLine: true,\n                    trailing: Chip(label: Text('Version $quoteVersion')),`,
    'carrier current quote version display',
);

replaceOnce(
    `                if (data['status'] == 'awarded' ||\n                    !const {'draft', 'open'}.contains(jobData['status'])) ...[`,
    `                if (quoteCancelled) ...[\n                  const SizedBox(height: 8),\n                  Container(\n                    width: double.infinity,\n                    padding: const EdgeInsets.symmetric(\n                      horizontal: 14,\n                      vertical: 12,\n                    ),\n                    decoration: BoxDecoration(\n                      color: const Color(0xFFFFCDD2),\n                      borderRadius: BorderRadius.circular(10),\n                    ),\n                    child: const Text(\n                      'QUOTE CANCELLED - NO LONGER VALID',\n                      textAlign: TextAlign.center,\n                      style: TextStyle(\n                        fontSize: 18,\n                        fontWeight: FontWeight.w900,\n                        letterSpacing: .5,\n                      ),\n                    ),\n                  ),\n                ],\n                if (data['status'] == 'awarded' ||\n                    !const {'draft', 'open'}.contains(jobData['status'])) ...[`,
    'cancelled current quote banner',
);

replaceOnce(
    `                        onPressed: data['status'] == 'pending' &&\n                                jobData['status'] == 'open'\n                            ? () {\n                                Navigator.pop(sheetContext);\n                                _bid(context, job.id, jobData, existing: bid);\n                              }\n                            : null,\n                        icon: const Icon(Icons.edit_outlined),\n                        label: const Text('Edit quote'),`,
    `                        onPressed: const {'pending', 'cancelled'}.contains(data['status']) &&\n                                jobData['status'] == 'open'\n                            ? () {\n                                Navigator.pop(sheetContext);\n                                _bid(context, job.id, jobData, existing: bid);\n                              }\n                            : null,\n                        icon: const Icon(Icons.edit_outlined),\n                        label: Text(quoteCancelled\n                            ? 'Create new version'\n                            : 'Edit quote'),`,
    'carrier re-quote action',
);

replaceOnce(
    `                            query: () => repo.bidHistoryQuery(bid.id),\n                            amountLabel: 'Quoted total',\n                          );`,
    `                            query: () => repo.bidHistoryQuery(bid.id),\n                            amountLabel: 'Quoted total',\n                            currentQuote: data,\n                          );`,
    'carrier history authoritative state',
);

replaceOnce(
    `                ),\n              ],\n            ),\n          ),\n        ),\n      ),\n    );\n  }\n\n  Future<void> _showRevisionHistory({`,
    `                ),\n                if (dispatchQuoteIsCurrentAndAwardable(data) &&\n                    jobData['status'] == 'open') ...[\n                  const SizedBox(height: 8),\n                  SizedBox(\n                    width: double.infinity,\n                    child: OutlinedButton.icon(\n                      onPressed: () async {\n                        Navigator.pop(sheetContext);\n                        await _cancelCarrierQuote(context, bid);\n                      },\n                      icon: const Icon(Icons.cancel_outlined),\n                      label: const Text('Cancel current quote'),\n                    ),\n                  ),\n                ],\n              ],\n            ),\n          ),\n        ),\n      ),\n    );\n  }\n\n  Future<void> _cancelCarrierQuote(\n    BuildContext context,\n    QueryDocumentSnapshot<Map<String, dynamic>> bid,\n  ) async {\n    final reason = TextEditingController();\n    final confirmed = await showDialog<bool>(\n          context: context,\n          builder: (dialogContext) => AlertDialog(\n            title: const Text('Cancel carrier quote?'),\n            content: Column(\n              mainAxisSize: MainAxisSize.min,\n              crossAxisAlignment: CrossAxisAlignment.start,\n              children: [\n                const Text(\n                  'This makes the current version immediately non-awardable. The historical version remains visible for audit.',\n                ),\n                const SizedBox(height: 12),\n                TextField(\n                  controller: reason,\n                  maxLength: 500,\n                  maxLines: 3,\n                  decoration: const InputDecoration(\n                    labelText: 'Reason (optional)',\n                    hintText: 'Equipment unavailable, scheduling conflict, etc.',\n                  ),\n                ),\n              ],\n            ),\n            actions: [\n              TextButton(\n                onPressed: () => Navigator.pop(dialogContext, false),\n                child: const Text('Keep quote'),\n              ),\n              FilledButton.icon(\n                onPressed: () => Navigator.pop(dialogContext, true),\n                icon: const Icon(Icons.cancel_outlined),\n                label: const Text('Cancel quote'),\n              ),\n            ],\n          ),\n        ) ??\n        false;\n    final cancellationReason = reason.text.trim();\n    reason.dispose();\n    if (!confirmed) return;\n    try {\n      await repo.cancelBid(bidId: bid.id, reason: cancellationReason);\n      if (context.mounted) {\n        PipeFeedback.show(\n          context,\n          message: 'Carrier quote cancelled. It can no longer be awarded.',\n          tone: PipeStatusTone.success,\n        );\n      }\n    } catch (error) {\n      if (context.mounted) {\n        PipeFeedback.show(\n          context,\n          message: marketplaceCommandErrorMessage(\n            error,\n            fallback: 'The carrier quote could not be cancelled.',\n          ),\n          tone: PipeStatusTone.error,\n        );\n      }\n    }\n  }\n\n  Future<void> _showRevisionHistory({`,
    'carrier cancellation workflow insertion',
);

replaceOnce(
    `    required Query<Map<String, dynamic>> Function() query,\n    required String? amountLabel,\n  }) async {`,
    `    required Query<Map<String, dynamic>> Function() query,\n    required String? amountLabel,\n    Map<String, dynamic>? currentQuote,\n  }) async {`,
    'revision history current quote parameter',
);

replaceOnce(
    `                  itemBuilder: (_, revision) {\n                    final data = revision.data();\n                    final amount = data['amount'] as num?;\n                    return Card(\n                      child: ListTile(\n                        leading: CircleAvatar(\n                          child: Text('\${data['revision'] ?? '—'}'),\n                        ),\n                        title: Text(\n                          amountLabel != null && amount != null\n                              ? '$amountLabel • \${marketplaceMoney(amount)}'\n                              : _dispatchEventLabel(\n                                  '\${data['event'] ?? 'updated'}',\n                                ),\n                          style: const TextStyle(fontWeight: FontWeight.w900),\n                        ),\n                        subtitle: Text(\n                          '\${_dispatchEventLabel('\${data['event'] ?? 'updated'}')} • \${('\${data['status'] ?? ''}').toUpperCase()}\\n\${_dispatchDateLabel(data)}\${('\${data['note'] ?? ''}').trim().isEmpty ? '' : '\\n\${data['note']}',\n                        ),\n                        isThreeLine: true,\n                      ),\n                    );\n                  },`,
    `                  itemBuilder: (_, revision) {\n                    final data = revision.data();\n                    final amount = data['amount'] as num?;\n                    final presentation = currentQuote == null\n                        ? null\n                        : dispatchQuoteVersionPresentation(\n                            currentQuote: currentQuote,\n                            revision: data,\n                          );\n                    final versionLabel = presentation?.label;\n                    return Card(\n                      child: Stack(\n                        alignment: Alignment.center,\n                        children: [\n                          if (presentation?.isInvalid == true)\n                            IgnorePointer(\n                              child: Transform.rotate(\n                                angle: -0.10,\n                                child: Opacity(\n                                  opacity: .11,\n                                  child: Padding(\n                                    padding: const EdgeInsets.all(18),\n                                    child: Text(\n                                      presentation!.watermark,\n                                      textAlign: TextAlign.center,\n                                      style: const TextStyle(\n                                        fontSize: 18,\n                                        fontWeight: FontWeight.w900,\n                                        letterSpacing: 1.2,\n                                      ),\n                                    ),\n                                  ),\n                                ),\n                              ),\n                            ),\n                          ListTile(\n                            leading: CircleAvatar(\n                              child: Text(\n                                presentation == null\n                                    ? '\${data['revision'] ?? '—'}'\n                                    : '\${presentation.version}',\n                              ),\n                            ),\n                            title: Text(\n                              amountLabel != null && amount != null\n                                  ? '$amountLabel • \${marketplaceMoney(amount)}'\n                                  : _dispatchEventLabel(\n                                      '\${data['event'] ?? 'updated'}',\n                                    ),\n                              style: const TextStyle(fontWeight: FontWeight.w900),\n                            ),\n                            subtitle: Text(\n                              '\${versionLabel == null ? '' : '$versionLabel\\n'}\${_dispatchEventLabel('\${data['event'] ?? 'updated'}')} • \${('\${data['status'] ?? ''}').toUpperCase()}\\n\${_dispatchDateLabel(data)}\${('\${data['note'] ?? ''}').trim().isEmpty ? '' : '\\n\${data['note']}',\n                            ),\n                            isThreeLine: true,\n                          ),\n                        ],\n                      ),\n                    );\n                  },`,
    'history version watermark rendering',
);

fs.writeFileSync(path, source);
console.log('R5 Quote V2 B2 cancellation/version UI transform applied.');
