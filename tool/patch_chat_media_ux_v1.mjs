"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const file = path.join(root, "lib", "marketplace", "marketplace_messages_page.dart");
let source = fs.readFileSync(file, "utf8");

function replaceOnce(before, after, label) {
  if (source.includes(after)) return;
  const index = source.indexOf(before);
  if (index < 0) throw new Error(`Anchor not found: ${label}`);
  source = source.slice(0, index) + after + source.slice(index + before.length);
}

replaceOnce(
  `import 'package:image_picker/image_picker.dart';\n`,
  `import 'package:image_picker/image_picker.dart';\nimport 'package:url_launcher/url_launcher.dart';\n`,
  "url launcher import",
);
replaceOnce(
  `  bool _uploading = false;\n  Map<String, dynamic>? _attachment;\n`,
  `  bool _uploading = false;\n  Map<String, dynamic>? _attachment;\n  OverlayEntry? _attachmentToast;\n  Timer? _attachmentToastTimer;\n`,
  "attachment toast state",
);
replaceOnce(
  `  @override\n  void dispose() {\n    _controller.dispose();\n`,
  `  @override\n  void dispose() {\n    _attachmentToastTimer?.cancel();\n    _attachmentToast?.remove();\n    _controller.dispose();\n`,
  "attachment toast dispose",
);
replaceOnce(
  `            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),\n`,
  `            padding: const EdgeInsets.fromLTRB(10, 8, 8, 22),\n`,
  "lift message composer",
);
replaceOnce(
  `                    avatar: const Icon(Icons.image_outlined),\n`,
  `                    avatar: Icon(\n                      _attachment!['type'] == 'video'\n                          ? Icons.videocam_outlined\n                          : Icons.image_outlined,\n                    ),\n`,
  "attachment chip media icon",
);

if (!source.includes("message['attachment'] as Map)['type'] ==\n                                    'video'")) {
  const anchor = `                            if (hiddenByModeration)\n`;
  const videoCard = `                            if (!hiddenByModeration &&\n                                message['attachment'] is Map &&\n                                (message['attachment'] as Map)['type'] ==\n                                    'video')\n                              InkWell(\n                                onTap: () => _openAttachmentUrl(\n                                  '\${(message['attachment'] as Map)['url']}',\n                                ),\n                                borderRadius: BorderRadius.circular(10),\n                                child: Container(\n                                  width: 220,\n                                  padding: const EdgeInsets.all(12),\n                                  decoration: BoxDecoration(\n                                    color: mine\n                                        ? Colors.white12\n                                        : Colors.black.withValues(alpha: .04),\n                                    borderRadius: BorderRadius.circular(10),\n                                  ),\n                                  child: Row(children: [\n                                    Icon(\n                                      Icons.play_circle_outline,\n                                      color: mine ? Colors.white : Colors.black87,\n                                    ),\n                                    const SizedBox(width: 8),\n                                    Expanded(\n                                      child: Text(\n                                        '\${(message['attachment'] as Map)['name'] ?? 'Video attachment'}',\n                                        maxLines: 2,\n                                        overflow: TextOverflow.ellipsis,\n                                        style: TextStyle(\n                                          color: mine ? Colors.white : Colors.black87,\n                                          fontWeight: FontWeight.w800,\n                                        ),\n                                      ),\n                                    ),\n                                    Icon(\n                                      Icons.open_in_new,\n                                      size: 16,\n                                      color: mine ? Colors.white70 : Colors.black54,\n                                    ),\n                                  ]),\n                                ),\n                              ),\n`;
  const index = source.indexOf(anchor, source.indexOf("class _MarketplaceChatPageState"));
  if (index < 0) throw new Error("Anchor not found: chat message attachment renderer");
  source = source.slice(0, index) + videoCard + source.slice(index);
}

if (!source.includes("void _showAttachmentToast")) {
  const anchor = `  Future<void> _send() async {\n`;
  const helper = `  void _showAttachmentToast(String message, {required bool video}) {\n    _attachmentToastTimer?.cancel();\n    _attachmentToast?.remove();\n    final overlay = Overlay.of(context, rootOverlay: true);\n    late final OverlayEntry entry;\n    entry = OverlayEntry(\n      builder: (_) => Positioned.fill(\n        child: IgnorePointer(\n          child: Center(\n            child: Material(\n              color: Colors.transparent,\n              child: Container(\n                constraints: const BoxConstraints(maxWidth: 340),\n                margin: const EdgeInsets.all(24),\n                padding:\n                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),\n                decoration: BoxDecoration(\n                  color: const Color(0xFF151A20),\n                  borderRadius: BorderRadius.circular(14),\n                  boxShadow: const [\n                    BoxShadow(\n                      color: Color(0x33000000),\n                      blurRadius: 22,\n                      offset: Offset(0, 8),\n                    ),\n                  ],\n                ),\n                child: Row(mainAxisSize: MainAxisSize.min, children: [\n                  Icon(\n                    video\n                        ? Icons.videocam_outlined\n                        : Icons.image_outlined,\n                    color: const Color(0xFFFF6A00),\n                    size: 21,\n                  ),\n                  const SizedBox(width: 9),\n                  Flexible(\n                    child: Text(\n                      message,\n                      style: const TextStyle(\n                        color: Colors.white,\n                        fontWeight: FontWeight.w800,\n                      ),\n                    ),\n                  ),\n                ]),\n              ),\n            ),\n          ),\n        ),\n      ),\n    );\n    _attachmentToast = entry;\n    overlay.insert(entry);\n    _attachmentToastTimer = Timer(const Duration(milliseconds: 2300), () {\n      if (_attachmentToast == entry) _attachmentToast = null;\n      entry.remove();\n    });\n  }\n\n  Future<void> _openAttachmentUrl(String rawUrl) async {\n    final uri = Uri.tryParse(rawUrl);\n    if (uri == null ||\n        !await launchUrl(uri, mode: LaunchMode.platformDefault)) {\n      if (mounted) {\n        PipeFeedback.show(\n          context,\n          message: 'The attachment could not be opened.',\n          tone: PipeStatusTone.warning,\n        );\n      }\n    }\n  }\n\n`;
  const index = source.indexOf(anchor, source.indexOf("class _MarketplaceChatPageState"));
  if (index < 0) throw new Error("Anchor not found: chat send method");
  source = source.slice(0, index) + helper + source.slice(index);
}

const pickerStart = source.indexOf(
  "  Future<void> _pickAttachment() async {",
  source.indexOf("class _MarketplaceChatPageState"),
);
const pickerEndMarker = "\n  Future<void> _reportConversation() async {";
const pickerEnd = source.indexOf(pickerEndMarker, pickerStart);
if (pickerStart < 0 || pickerEnd < 0) {
  throw new Error("Chat media picker anchors not found");
}
const currentPicker = source.slice(pickerStart, pickerEnd);
if (!currentPicker.includes("gallery_video")) {
  const picker = `  Future<void> _pickAttachment() async {\n    final choice = await showModalBottomSheet<String>(\n      context: context,\n      shape: const RoundedRectangleBorder(\n        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),\n      ),\n      builder: (ctx) => SafeArea(\n        child: Column(\n          mainAxisSize: MainAxisSize.min,\n          children: [\n            const Padding(\n              padding: EdgeInsets.all(16),\n              child: Text(\n                'Attach media',\n                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),\n              ),\n            ),\n            ListTile(\n              leading: const Icon(Icons.photo_library, color: Color(0xFFFF6A00)),\n              title: const Text('Choose photo'),\n              onTap: () => Navigator.pop(ctx, 'gallery_image'),\n            ),\n            ListTile(\n              leading: const Icon(Icons.camera_alt, color: Color(0xFF10B981)),\n              title: const Text('Take photo'),\n              onTap: () => Navigator.pop(ctx, 'camera_image'),\n            ),\n            ListTile(\n              leading: const Icon(\n                Icons.video_library_outlined,\n                color: Color(0xFFFF6A00),\n              ),\n              title: const Text('Choose video'),\n              subtitle: const Text('MP4 or MOV • maximum 25 MB'),\n              onTap: () => Navigator.pop(ctx, 'gallery_video'),\n            ),\n            ListTile(\n              leading: const Icon(Icons.videocam_outlined, color: Color(0xFF10B981)),\n              title: const Text('Record video'),\n              subtitle: const Text('Maximum 25 MB'),\n              onTap: () => Navigator.pop(ctx, 'camera_video'),\n            ),\n            const SizedBox(height: 12),\n          ],\n        ),\n      ),\n    );\n    if (choice == null) return;\n\n    try {\n      final isVideo = choice.endsWith('_video');\n      final sourceType = choice.startsWith('camera')\n          ? ImageSource.camera\n          : ImageSource.gallery;\n      final file = isVideo\n          ? await ImagePicker().pickVideo(\n              source: sourceType,\n              maxDuration: const Duration(minutes: 2),\n            )\n          : await ImagePicker().pickImage(\n              source: sourceType,\n              imageQuality: 82,\n              maxWidth: 1800,\n            );\n      if (file == null) return;\n      final sizeBytes = await file.length();\n      final maximumBytes = isVideo ? 25 * 1024 * 1024 : 15 * 1024 * 1024;\n      if (sizeBytes > maximumBytes) {\n        if (mounted) {\n          PipeFeedback.show(\n            context,\n            message: isVideo\n                ? 'Video attachments must be under 25 MB.'\n                : 'Image attachments must be under 15 MB.',\n            tone: PipeStatusTone.warning,\n          );\n        }\n        return;\n      }\n      setState(() => _uploading = true);\n      final extension = file.name.split('.').last.toLowerCase();\n      final contentType = isVideo\n          ? (extension == 'mov' ? 'video/quicktime' : 'video/mp4')\n          : extension == 'png'\n              ? 'image/png'\n              : extension == 'webp'\n                  ? 'image/webp'\n                  : 'image/jpeg';\n      final authorization = await _actions.authorizeUpload(\n        purpose: 'chat_attachment',\n        originalName: file.name,\n        contentType: contentType,\n        sizeBytes: sizeBytes,\n        conversationId: widget.conversationId,\n      );\n      final authorizationId = '\${authorization['authorizationId']}';\n      final reference =\n          FirebaseStorage.instance.ref('\${authorization['storagePath']}');\n      await reference.putData(\n        await file.readAsBytes(),\n        SettableMetadata(\n          contentType: contentType,\n          customMetadata: {'conversationId': widget.conversationId},\n        ),\n      );\n      final url = await reference.getDownloadURL();\n      await _actions.confirmUpload(authorizationId: authorizationId, url: url);\n      if (mounted) {\n        setState(() => _attachment = {\n              'type': isVideo ? 'video' : 'image',\n              'authorizationId': authorizationId,\n              'url': url,\n              'name': file.name,\n            });\n        _showAttachmentToast(\n          isVideo\n              ? 'Video attached • add a message or press Send'\n              : 'Image attached • add a message or press Send',\n          video: isVideo,\n        );\n      }\n    } on FirebaseException catch (error) {\n      if (mounted) {\n        PipeFeedback.show(\n          context,\n          message: error.code == 'unauthorized'\n              ? 'Media upload is not authorized. Refresh your account and try again.'\n              : 'Media upload failed. Please try again.',\n          tone: PipeStatusTone.error,\n        );\n      }\n    } catch (error) {\n      if (mounted) {\n        PipeFeedback.show(\n          context,\n          message: marketplaceCommandErrorMessage(\n            error,\n            fallback: 'Could not attach this media. Try another file.',\n          ),\n          tone: PipeStatusTone.error,\n        );\n      }\n    } finally {\n      if (mounted) setState(() => _uploading = false);\n    }\n  }\n`;
  source = source.slice(0, pickerStart) + picker + source.slice(pickerEnd);
}

fs.writeFileSync(file, source, "utf8");
console.log("Patched chat composer spacing, centered media toast, and image/video attachments.");
