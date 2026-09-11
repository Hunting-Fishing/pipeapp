import fs from 'node:fs';

function load(path) { return fs.readFileSync(path, 'utf8'); }
function save(path, value) { fs.writeFileSync(path, value); }
function replaceOnce(source, oldValue, newValue, label) {
  const count = source.split(oldValue).length - 1;
  if (count !== 1) throw new Error(`${label}: expected one marker, found ${count}`);
  return source.replace(oldValue, newValue);
}
function insertBeforeOnce(source, marker, insertion, label) {
  const count = source.split(marker).length - 1;
  if (count !== 1) throw new Error(`${label}: expected one marker, found ${count}`);
  return source.replace(marker, `${insertion}${marker}`);
}

// Server-owned BOL transition and R5 transit gate.
{
  const path = 'firebase/functions/dispatch_command_policy.js';
  let s = load(path);
  const bolAction = `  if (action === "record_bol") {\n    if (actorRole !== "carrier") {\n      throw new CommandPolicyError(\n          "permission-denied",\n          "Only the awarded carrier can record the bill of lading.",\n      );\n    }\n    if (!["accepted", "scheduled"].includes(status)) {\n      throw new CommandPolicyError(\n          "failed-precondition",\n          "The bill of lading can only be recorded after award acceptance and before transport starts.",\n      );\n    }\n    const bolNumber = requireText(data.bolNumber, "Bill of lading number", 120);\n    const shipperReference = optionalText(\n        data.bolShipperReference,\n        "BOL shipper reference",\n        160,\n    );\n    const notes = optionalText(data.bolNotes, "BOL notes", 2000);\n    let pieceCount = null;\n    if (data.bolPieceCount !== null && data.bolPieceCount !== undefined &&\n        String(data.bolPieceCount).trim() !== "") {\n      pieceCount = Number(data.bolPieceCount);\n      if (!Number.isInteger(pieceCount) || pieceCount <= 0 || pieceCount > 1000000) {\n        throw new CommandPolicyError(\n            "invalid-argument",\n            "BOL piece count must be a positive whole number.",\n        );\n      }\n    }\n    const billOfLading = {\n      number: bolNumber,\n      shipperReference,\n      pieceCount,\n      notes,\n    };\n    const existing = dispatchTransaction.billOfLading;\n    const alreadyApplied = Boolean(existing &&\n      String(existing.number || "") === bolNumber &&\n      String(existing.shipperReference || "") === shipperReference &&\n      Number(existing.pieceCount || 0) === Number(pieceCount || 0) &&\n      String(existing.notes || "") === notes);\n    return {status, actorRole, alreadyApplied, billOfLading};\n  }\n`;
  if (!s.includes('if (action === "record_bol")')) {
    s = insertBeforeOnce(s, '  if (action === "start_transit") {', bolAction, 'BOL action');
  }
  const startMarker = `    if (status !== "scheduled") {\n      throw new CommandPolicyError(\n          "failed-precondition",\n          "Schedule pickup before marking this load in transit.",\n      );\n    }\n    return {status: "in_transit", actorRole, alreadyApplied: false};`;
  const startReplacement = `    if (status !== "scheduled") {\n      throw new CommandPolicyError(\n          "failed-precondition",\n          "Schedule pickup before marking this load in transit.",\n      );\n    }\n    if (Number(dispatchTransaction.workflowVersion || 1) >= 2 &&\n        (!dispatchTransaction.billOfLading ||\n         !String(dispatchTransaction.billOfLading.number || "").trim())) {\n      throw new CommandPolicyError(\n          "failed-precondition",\n          "Record the bill of lading before starting transport.",\n      );\n    }\n    return {status: "in_transit", actorRole, alreadyApplied: false};`;
  if (!s.includes('Record the bill of lading before starting transport.')) {
    s = replaceOnce(s, startMarker, startReplacement, 'R5 transit BOL gate');
  }
  save(path, s);
}

// Award new jobs into workflow v2 and persist BOL revisions through the existing command.
{
  const path = 'firebase/functions/dispatch_commands.js';
  let s = load(path);
  if (!s.includes('workflowVersion: 2,')) {
    s = replaceOnce(
      s,
      `        status: "awarded",\n        proposedAvailableDate: bid.availableDate || null,`,
      `        status: "awarded",\n        workflowVersion: 2,\n        billOfLading: null,\n        proposedAvailableDate: bid.availableDate || null,`,
      'award workflow v2',
    );
  }
  if (!s.includes('...(transition.billOfLading ? {\n          billOfLading: transition.billOfLading,')) {
    s = replaceOnce(
      s,
      `        ...(transition.proofOfDelivery ? {\n          proofOfDelivery: transition.proofOfDelivery,\n          deliveredAt: FieldValue.serverTimestamp(),\n        } : {}),`,
      `        ...(transition.proofOfDelivery ? {\n          proofOfDelivery: transition.proofOfDelivery,\n          deliveredAt: FieldValue.serverTimestamp(),\n        } : {}),\n        ...(transition.billOfLading ? {\n          billOfLading: transition.billOfLading,\n          bolRecordedAt: FieldValue.serverTimestamp(),\n        } : {}),`,
      'persist BOL transaction',
    );
    s = replaceOnce(
      s,
      `            ...(transition.proofOfDelivery ? {\n              proofOfDelivery: transition.proofOfDelivery,\n            } : {}),`,
      `            ...(transition.proofOfDelivery ? {\n              proofOfDelivery: transition.proofOfDelivery,\n            } : {}),\n            ...(transition.billOfLading ? {\n              billOfLading: transition.billOfLading,\n            } : {}),`,
      'persist BOL revision',
    );
  }
  save(path, s);
}

// Client repository stays on the existing protected updateDispatchTransaction command.
{
  const path = 'lib/marketplace/marketplace_dispatch_repository.dart';
  let s = load(path);
  if (!s.includes('String bolNumber =')) {
    s = replaceOnce(
      s,
      `    String reason = '',\n    String receiverName = '',\n    String deliveryNote = '',\n    String proofStoragePath = '',\n  }) async {`,
      `    String reason = '',\n    String receiverName = '',\n    String deliveryNote = '',\n    String proofStoragePath = '',\n    String bolNumber = '',\n    String bolShipperReference = '',\n    int? bolPieceCount,\n    String bolNotes = '',\n  }) async {`,
      'repository BOL parameters',
    );
    s = replaceOnce(
      s,
      `      if (proofStoragePath.trim().isNotEmpty)\n        'proofStoragePath': proofStoragePath.trim(),`,
      `      if (proofStoragePath.trim().isNotEmpty)\n        'proofStoragePath': proofStoragePath.trim(),\n      if (bolNumber.trim().isNotEmpty) 'bolNumber': bolNumber.trim(),\n      if (bolShipperReference.trim().isNotEmpty)\n        'bolShipperReference': bolShipperReference.trim(),\n      if (bolPieceCount != null) 'bolPieceCount': bolPieceCount,\n      if (bolNotes.trim().isNotEmpty) 'bolNotes': bolNotes.trim(),`,
      'repository BOL payload',
    );
  }
  save(path, s);
}

// Participant UI: render current BOL and carrier create/edit control.
{
  const path = 'lib/marketplace/marketplace_dispatch_transaction.dart';
  let s = load(path);
  if (!s.includes("transaction['billOfLading']")) {
    s = replaceOnce(
      s,
      `    final proof = transaction['proofOfDelivery'] is Map\n        ? Map<String, dynamic>.from(transaction['proofOfDelivery'] as Map)\n        : const <String, dynamic>{};\n    final amount = marketplaceMoney(transaction['amount'] as num? ?? 0);`,
      `    final proof = transaction['proofOfDelivery'] is Map\n        ? Map<String, dynamic>.from(transaction['proofOfDelivery'] as Map)\n        : const <String, dynamic>{};\n    final bol = transaction['billOfLading'] is Map\n        ? Map<String, dynamic>.from(transaction['billOfLading'] as Map)\n        : const <String, dynamic>{};\n    final workflowVersion = (transaction['workflowVersion'] as num?)?.toInt() ?? 1;\n    final amount = marketplaceMoney(transaction['amount'] as num? ?? 0);`,
      'transaction BOL locals',
    );
    s = replaceOnce(
      s,
      `                _progress(status),\n                if (proof.isNotEmpty) ...[`,
      `                _progress(status),\n                if (workflowVersion >= 2 || bol.isNotEmpty) ...[\n                  const SizedBox(height: 20),\n                  _billOfLading(\n                    bol,\n                    carrier: carrier,\n                    editable: carrier && const {'accepted', 'scheduled'}.contains(status),\n                  ),\n                ],\n                if (proof.isNotEmpty) ...[`,
      'BOL card placement',
    );
    const widget = `  Widget _billOfLading(\n    Map<String, dynamic> bol, {\n    required bool carrier,\n    required bool editable,\n  }) {\n    final hasBol = bol.isNotEmpty && '\${bol['number'] ?? ''}'.trim().isNotEmpty;\n    return Container(\n      width: double.infinity,\n      padding: const EdgeInsets.all(15),\n      decoration: BoxDecoration(\n        color: hasBol ? const Color(0xFFF4F8FC) : PipeBuyerColors.orangeSoft,\n        borderRadius: BorderRadius.circular(14),\n        border: Border.all(\n          color: hasBol\n              ? PipeBuyerColors.industrialBlue.withValues(alpha: .24)\n              : PipeBuyerColors.orange.withValues(alpha: .30),\n        ),\n      ),\n      child: Column(\n        crossAxisAlignment: CrossAxisAlignment.start,\n        children: [\n          Row(\n            children: [\n              Icon(\n                Icons.description_outlined,\n                color: hasBol ? PipeBuyerColors.industrialBlue : PipeBuyerColors.orange,\n              ),\n              const SizedBox(width: 9),\n              const Expanded(\n                child: Text(\n                  'Bill of lading',\n                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),\n                ),\n              ),\n              if (hasBol) const Chip(label: Text('RECORDED')),\n            ],\n          ),\n          const SizedBox(height: 7),\n          if (hasBol) ...[\n            Text('BOL # \${bol['number']}', style: const TextStyle(fontWeight: FontWeight.w800)),\n            if ('\${bol['shipperReference'] ?? ''}'.trim().isNotEmpty)\n              Text('Shipper reference: \${bol['shipperReference']}'),\n            if (bol['pieceCount'] != null) Text('Pieces: \${bol['pieceCount']}'),\n            if ('\${bol['notes'] ?? ''}'.trim().isNotEmpty)\n              Padding(\n                padding: const EdgeInsets.only(top: 4),\n                child: Text('\${bol['notes']}'),\n              ),\n          ] else\n            const Text(\n              'A bill of lading must be recorded before a new R5 Dispatch load can start transport.',\n            ),\n          if (carrier && editable) ...[\n            const SizedBox(height: 10),\n            OutlinedButton.icon(\n              onPressed: _busy ? null : () => _recordBol(bol),\n              icon: const Icon(Icons.edit_document),\n              label: Text(hasBol ? 'Edit bill of lading' : 'Record bill of lading'),\n            ),\n          ],\n        ],\n      ),\n    );\n  }\n\n`;
    s = insertBeforeOnce(s, '  Widget _proofOfDelivery(Map<String, dynamic> proof)', widget, 'BOL display widget');
    const method = `  Future<void> _recordBol(Map<String, dynamic> existing) async {\n    final number = TextEditingController(text: '\${existing['number'] ?? ''}');\n    final reference = TextEditingController(text: '\${existing['shipperReference'] ?? ''}');\n    final pieces = TextEditingController(text: existing['pieceCount'] == null ? '' : '\${existing['pieceCount']}');\n    final notes = TextEditingController(text: '\${existing['notes'] ?? ''}');\n    final confirmed = await showDialog<bool>(\n          context: context,\n          builder: (dialogContext) => AlertDialog(\n            title: const Text('Bill of lading'),\n            content: SizedBox(\n              width: 520,\n              child: SingleChildScrollView(\n                child: Column(\n                  mainAxisSize: MainAxisSize.min,\n                  children: [\n                    TextField(\n                      controller: number,\n                      maxLength: 120,\n                      decoration: const InputDecoration(labelText: 'BOL number *'),\n                    ),\n                    TextField(\n                      controller: reference,\n                      maxLength: 160,\n                      decoration: const InputDecoration(labelText: 'Shipper / PO reference'),\n                    ),\n                    TextField(\n                      controller: pieces,\n                      keyboardType: TextInputType.number,\n                      decoration: const InputDecoration(labelText: 'Piece count'),\n                    ),\n                    TextField(\n                      controller: notes,\n                      maxLength: 2000,\n                      minLines: 2,\n                      maxLines: 5,\n                      decoration: const InputDecoration(labelText: 'Load notes'),\n                    ),\n                  ],\n                ),\n              ),\n            ),\n            actions: [\n              TextButton(\n                onPressed: () => Navigator.pop(dialogContext, false),\n                child: const Text('Cancel'),\n              ),\n              FilledButton(\n                onPressed: () {\n                  if (number.text.trim().isNotEmpty) {\n                    Navigator.pop(dialogContext, true);\n                  }\n                },\n                child: const Text('Save BOL'),\n              ),\n            ],\n          ),\n        ) ??\n        false;\n    final bolNumber = number.text.trim();\n    final bolReference = reference.text.trim();\n    final parsedPieces = int.tryParse(pieces.text.trim());\n    final bolNotes = notes.text.trim();\n    number.dispose();\n    reference.dispose();\n    pieces.dispose();\n    notes.dispose();\n    if (!confirmed || bolNumber.isEmpty) return;\n    await _run(\n      () => widget.repository.updateDispatchTransaction(\n        jobId: widget.jobId,\n        action: 'record_bol',\n        bolNumber: bolNumber,\n        bolShipperReference: bolReference,\n        bolPieceCount: parsedPieces,\n        bolNotes: bolNotes,\n      ),\n      'Bill of lading recorded.',\n    );\n  }\n\n`;
    s = insertBeforeOnce(s, '  Future<void> _schedule() async {', method, 'BOL dialog method');
  }
  save(path, s);
}

console.log('R5 BOL implementation applied.');