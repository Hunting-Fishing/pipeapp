import fs from 'node:fs';

function patch(path, replacements) {
  let text = fs.readFileSync(path, 'utf8');
  for (const [before, after, label] of replacements) {
    if (!text.includes(before)) {
      if (text.includes(after)) {
        console.log(`${path}: ${label} already applied`);
        continue;
      }
      throw new Error(`${path}: missing patch anchor: ${label}`);
    }
    text = text.replace(before, after);
    console.log(`${path}: applied ${label}`);
  }
  fs.writeFileSync(path, text);
}

patch('firebase/functions/index.js', [
  [
    'const { createModerationCommands } = require("./moderation_commands");\n',
    'const { createModerationCommands } = require("./moderation_commands");\nconst {\n  createMarketplaceUserBlockCommands,\n} = require("./marketplace_user_block_commands");\n',
    'import marketplace user block commands',
  ],
  [
    'const marketplaceCommands = createMarketplaceCommands(admin);\n',
    'const marketplaceCommands = createMarketplaceCommands(admin);\nconst marketplaceUserBlockCommands = createMarketplaceUserBlockCommands(admin);\n',
    'initialize marketplace user block commands',
  ],
  [
    'exports.sendMarketplaceMessage = onCall(\n  protectedCallableOptions,\n  policyAcceptanceCommands.requireCurrentPolicies(\n    communicationCommands.sendMarketplaceMessage,\n  ),\n);\n',
    'exports.readMarketplaceUserBlockStatus = onCall(\n  protectedCallableOptions,\n  marketplaceUserBlockCommands.readMarketplaceUserBlockStatus,\n);\nexports.setMarketplaceUserBlocked = onCall(\n  protectedCallableOptions,\n  marketplaceUserBlockCommands.setMarketplaceUserBlocked,\n);\nconst sendMarketplaceMessageWithBlockGuard = async (request) => {\n  await marketplaceUserBlockCommands.requireConversationMessagingAllowed(request);\n  return communicationCommands.sendMarketplaceMessage(request);\n};\nexports.sendMarketplaceMessage = onCall(\n  protectedCallableOptions,\n  policyAcceptanceCommands.requireCurrentPolicies(\n    sendMarketplaceMessageWithBlockGuard,\n  ),\n);\n',
    'guard marketplace messages and export block commands',
  ],
]);

patch('lib/marketplace/marketplace_actions_repository.dart', [
  [
    "  Future<void> markConversationRead(String conversationId) async {\n    await _commands.execute('markMarketplaceConversationRead', {\n      'conversationId': conversationId,\n    });\n  }\n",
    "  Future<void> markConversationRead(String conversationId) async {\n    await _commands.execute('markMarketplaceConversationRead', {\n      'conversationId': conversationId,\n    });\n  }\n\n  Future<Map<String, dynamic>> readConversationBlockStatus(\n    String conversationId,\n  ) =>\n      _commands.execute('readMarketplaceUserBlockStatus', {\n        'conversationId': conversationId,\n      });\n\n  Future<Map<String, dynamic>> setConversationBlocked(\n    String conversationId, {\n    required bool blocked,\n  }) =>\n      _commands.execute('setMarketplaceUserBlocked', {\n        'conversationId': conversationId,\n        'blocked': blocked,\n      });\n",
    'add conversation block repository methods',
  ],
]);

patch('lib/marketplace/marketplace_messages_page.dart', [
  [
    '  bool _uploading = false;\n  Map<String, dynamic>? _attachment;\n',
    '  bool _uploading = false;\n  bool _blockBusy = false;\n  bool _blockedByMe = false;\n  bool _blockedMe = false;\n  Map<String, dynamic>? _attachment;\n',
    'add block state',
  ],
  [
    '    _actions.markConversationRead(widget.conversationId).catchError((_) {});\n',
    '    _actions.markConversationRead(widget.conversationId).catchError((_) {});\n    _loadBlockStatus();\n',
    'load block status',
  ],
  [
    "            onSelected: (value) {\n              if (value == 'report') _reportConversation();\n              if (value == 'profile') _openParticipantProfile();\n            },\n            itemBuilder: (_) => const [\n              PopupMenuItem(\n                value: 'profile',\n                child: ListTile(\n                  leading: Icon(Icons.person_outline),\n                  title: Text('View member profile'),\n                ),\n              ),\n              PopupMenuItem(\n                value: 'report',\n                child: ListTile(\n                  leading: Icon(Icons.flag_outlined, color: Colors.deepOrange),\n                  title: Text('Report conversation'),\n                ),\n              ),\n            ],\n",
    "            onSelected: (value) {\n              if (value == 'report') _reportConversation();\n              if (value == 'profile') _openParticipantProfile();\n              if (value == 'block') _toggleBlock();\n            },\n            itemBuilder: (_) => [\n              const PopupMenuItem(\n                value: 'profile',\n                child: ListTile(\n                  leading: Icon(Icons.person_outline),\n                  title: Text('View member profile'),\n                ),\n              ),\n              PopupMenuItem(\n                value: 'block',\n                enabled: !_blockBusy && !_blockedMe,\n                child: ListTile(\n                  leading: Icon(\n                    _blockedByMe ? Icons.person_add_alt_1 : Icons.block_outlined,\n                    color: _blockedByMe ? Colors.green : Colors.deepOrange,\n                  ),\n                  title: Text(_blockedByMe ? 'Unblock member' : 'Block member'),\n                  subtitle: _blockedMe\n                      ? const Text('This member has blocked messaging')\n                      : null,\n                ),\n              ),\n              const PopupMenuItem(\n                value: 'report',\n                child: ListTile(\n                  leading: Icon(Icons.flag_outlined, color: Colors.deepOrange),\n                  title: Text('Report conversation'),\n                ),\n              ),\n            ],\n",
    'add chat block menu action',
  ],
  [
    '          Expanded(\n            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(\n',
    "          if (_blockedByMe || _blockedMe)\n            Material(\n              color: Colors.orange.shade50,\n              child: ListTile(\n                dense: true,\n                leading: const Icon(Icons.block_outlined, color: Colors.deepOrange),\n                title: Text(\n                  _blockedByMe\n                      ? 'You blocked this member'\n                      : 'Messaging is unavailable for this conversation',\n                  style: const TextStyle(fontWeight: FontWeight.w800),\n                ),\n                subtitle: Text(\n                  _blockedByMe\n                      ? 'Message history and reports stay saved. Use the menu to unblock.'\n                      : 'The other member has blocked direct messages. Existing history remains available.',\n                ),\n              ),\n            ),\n          Expanded(\n            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(\n",
    'show block status banner',
  ],
  [
    '                    onPressed: _uploading ? null : _pickAttachment,\n',
    '                    onPressed: _uploading || _blockedByMe || _blockedMe\n                        ? null\n                        : _pickAttachment,\n',
    'disable attachment while blocked',
  ],
  [
    "                    onPressed: _sending ? null : _send,\n",
    "                    onPressed: _sending || _blockedByMe || _blockedMe\n                        ? null\n                        : _send,\n",
    'disable send while blocked',
  ],
  [
    '  Future<void> _openParticipantProfile() async {\n',
    "  Future<void> _loadBlockStatus() async {\n    try {\n      final status = await _actions.readConversationBlockStatus(\n        widget.conversationId,\n      );\n      if (!mounted) return;\n      setState(() {\n        _blockedByMe = status['blockedByViewer'] == true;\n        _blockedMe = status['blockedViewer'] == true;\n      });\n    } catch (_) {\n      // Messaging remains protected server-side even if the status chip cannot load.\n    }\n  }\n\n  Future<void> _toggleBlock() async {\n    if (_blockBusy || _blockedMe) return;\n    final blocking = !_blockedByMe;\n    final confirmed = await showDialog<bool>(\n          context: context,\n          builder: (dialogContext) => AlertDialog(\n            icon: Icon(blocking ? Icons.block_outlined : Icons.person_add_alt_1),\n            title: Text(blocking ? 'Block this member?' : 'Unblock this member?'),\n            content: Text(\n              blocking\n                  ? 'They will no longer be able to exchange direct messages with you. Existing messages and any Trust & Safety reports stay saved.'\n                  : 'Direct messaging will be available again unless the other member has also blocked you.',\n            ),\n            actions: [\n              TextButton(\n                onPressed: () => Navigator.pop(dialogContext, false),\n                child: const Text('Cancel'),\n              ),\n              FilledButton(\n                onPressed: () => Navigator.pop(dialogContext, true),\n                child: Text(blocking ? 'Block member' : 'Unblock member'),\n              ),\n            ],\n          ),\n        ) ??\n        false;\n    if (!confirmed || !mounted) return;\n    setState(() => _blockBusy = true);\n    try {\n      final status = await _actions.setConversationBlocked(\n        widget.conversationId,\n        blocked: blocking,\n      );\n      if (!mounted) return;\n      setState(() {\n        _blockedByMe = status['blockedByViewer'] == true;\n        _blockedMe = status['blockedViewer'] == true;\n      });\n      PipeFeedback.show(\n        context,\n        message: blocking\n            ? 'Member blocked. Existing messages and reports were preserved.'\n            : 'Member unblocked.',\n        tone: PipeStatusTone.success,\n      );\n    } catch (error) {\n      if (mounted) {\n        PipeFeedback.show(\n          context,\n          message: marketplaceCommandErrorMessage(\n            error,\n            fallback: 'The block setting could not be changed. Try again.',\n          ),\n          tone: PipeStatusTone.error,\n        );\n      }\n    } finally {\n      if (mounted) setState(() => _blockBusy = false);\n    }\n  }\n\n  Future<void> _openParticipantProfile() async {\n",
    'add load and toggle block methods',
  ],
  [
    '  Future<void> _send() async {\n    final text = _controller.text.trim();\n',
    "  Future<void> _send() async {\n    if (_blockedByMe || _blockedMe) return;\n    final text = _controller.text.trim();\n",
    'guard client send while blocked',
  ],
]);
