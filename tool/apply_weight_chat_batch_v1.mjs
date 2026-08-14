"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function read(relative) {
  return fs.readFileSync(path.join(root, relative), "utf8");
}

function write(relative, value) {
  fs.writeFileSync(path.join(root, relative), value, "utf8");
}

function replaceOnce(source, before, after, label) {
  if (source.includes(after)) return source;
  const index = source.indexOf(before);
  if (index < 0) throw new Error(`Patch anchor not found: ${label}`);
  return source.slice(0, index) + after + source.slice(index + before.length);
}

function replaceRegexOnce(source, pattern, replacement, label) {
  if (!pattern.test(source)) throw new Error(`Patch regex not found: ${label}`);
  return source.replace(pattern, replacement);
}

function patchListingPolicy() {
  const file = "firebase/functions/marketplace_listing_policy.js";
  let source = read(file);
  source = replaceOnce(
      source,
      `  "quantityAndLength",\n`,
      `  "quantityAndLength",\n  // Client weight preference only. The trusted weightSnapshot is generated\n  // after publication by the server and is never accepted as client input.\n  "weightInputMode",\n  "sellerEstimatedWeightKg",\n  "sellerWeightSource",\n  "jointLengthFt",\n  "jointLengthM",\n  "nominalWeightLbFt",\n  "outsideDiameterMm",\n  "wallThicknessMm",\n`,
      "listing weight fields");
  source = replaceOnce(
      source,
      `  listing.transactionType = transactionType;\n`,
      `  listing.transactionType = transactionType;\n\n  // PIPEBUYER_WEIGHT_INPUT_V1\n  const weightInputMode = String(listing.weightInputMode || "catalog_estimate");\n  if (!["catalog_estimate", "seller_estimate", "unknown"].includes(weightInputMode)) {\n    invalid("Weight preference is invalid.");\n  }\n  listing.weightInputMode = weightInputMode;\n  if (weightInputMode === "seller_estimate") {\n    const sellerWeight = Number(listing.sellerEstimatedWeightKg);\n    if (!Number.isFinite(sellerWeight) || sellerWeight <= 0 || sellerWeight > 100000000) {\n      invalid("Seller estimated shipping weight must be greater than zero.");\n    }\n    listing.sellerEstimatedWeightKg = sellerWeight;\n    listing.sellerWeightSource = "seller_estimate";\n  } else {\n    delete listing.sellerEstimatedWeightKg;\n    delete listing.sellerWeightSource;\n  }\n  for (const field of [\n    "jointLengthFt", "jointLengthM", "nominalWeightLbFt",\n    "outsideDiameterMm", "wallThicknessMm",\n  ]) {\n    if (listing[field] == null || listing[field] === "") continue;\n    const number = Number(listing[field]);\n    if (!Number.isFinite(number) || number <= 0 || number > 1000000) {\n      invalid(\`\${field} must be greater than zero.\`);\n    }\n    listing[field] = number;\n  }\n`,
      "weight preference validation");
  write(file, source);
}

function patchWeightTrigger() {
  const file = "firebase/functions/index.js";
  let source = read(file);
  source = replaceOnce(
      source,
      `const {buildDispatchRouteState} = require("./dispatch_routing_policy");\n`,
      `const {buildDispatchRouteState} = require("./dispatch_routing_policy");\n`,
      "noop dispatch anchor");
  // index.js does not necessarily import routing directly on every branch. Use
  // a stable import that is present near the command factories instead.
  if (!source.includes('require("./marketplace_weight_policy")')) {
    const anchor = `const { createMarketplaceCommands } = require("./marketplace_commands");\n`;
    source = replaceOnce(
        source,
        anchor,
        `${anchor}const {\n  applyWeightSnapshot,\n  resolveListingWeightSnapshot,\n} = require("./marketplace_weight_policy");\n`,
        "weight policy import");
  }
  if (!source.includes("exports.onPublicListingWeightSnapshot")) {
    const anchor = `// Reserve amounts are seller-only. This guard also cleans legacy clients that\n`;
    const block = `// Freezes the best available planning-weight evidence onto a listing shortly\n// after publication. Later catalog corrections do not silently rewrite the\n// historical listing; sellers can publish a new listing or submit a reviewed\n// correction instead.\nexports.onPublicListingWeightSnapshot = onDocumentCreated(\n  "public_listings/{listingId}",\n  async (event) => {\n    const listing = event.data && event.data.data();\n    if (!listing || listing.weightSnapshot) return null;\n    const snapshot = await resolveListingWeightSnapshot(admin.firestore(), listing);\n    const weighted = applyWeightSnapshot(listing, snapshot);\n    await event.data.ref.set({\n      weightSnapshot: weighted.weightSnapshot,\n      weightStatus: weighted.weightStatus,\n      weightSource: weighted.weightSource,\n      weightConfidence: weighted.weightConfidence,\n      ...(weighted.shippingWeightKg ? {shippingWeightKg: weighted.shippingWeightKg} : {}),\n      ...(weighted.catalogWeightKg ? {catalogWeightKg: weighted.catalogWeightKg} : {}),\n      weightSnapshotCreatedAt: admin.firestore.FieldValue.serverTimestamp(),\n    }, {merge: true});\n    return null;\n  },\n);\n\n`;
    source = replaceOnce(source, anchor, block + anchor, "weight snapshot trigger");
  }
  write(file, source);
}

function patchListingForm() {
  const file = "lib/marketplace/oil_gas_marketplace.dart";
  let source = read(file);
  source = replaceOnce(
      source,
      `import 'marketplace_freight_quote.dart';\n`,
      `import 'marketplace_freight_quote.dart';\nimport 'marketplace_weight_catalog.dart';\n`,
      "listing weight import");
  source = replaceOnce(
      source,
      `  'Bobcat': ['E35', 'E60', 'S650', 'T76', 'TL619'],`,
      `  'Bobcat': ['E35', 'E60', 'S160', 'S650', 'T76', 'TL619'],`,
      "Bobcat S160 catalog option");
  source = replaceOnce(
      source,
      `  final _quantity = TextEditingController();\n`,
      `  final _quantity = TextEditingController();\n  final _jointLengthFt = TextEditingController();\n  final _weightInputKey = GlobalKey<MarketplaceListingWeightInputState>();\n`,
      "listing weight controllers");
  source = replaceOnce(
      source,
      `    _quantity.dispose();\n`,
      `    _quantity.dispose();\n    _jointLengthFt.dispose();\n`,
      "joint length dispose");

  if (!source.includes("PIPEBUYER_LISTING_WEIGHT_UI_V1")) {
    const anchor = `            if (isPipe) ...[\n              const SizedBox(height: 12),\n              DropdownButtonFormField<String>(`;
    const insert = `            // PIPEBUYER_LISTING_WEIGHT_UI_V1\n            if (!isProperty) ...[\n              const SizedBox(height: 12),\n              if (isPipe) ...[\n                TextFormField(\n                  controller: _jointLengthFt,\n                  keyboardType: const TextInputType.numberWithOptions(decimal: true),\n                  decoration: const InputDecoration(\n                    labelText: 'Approx. joint / piece length',\n                    hintText: 'Example: 31',\n                    suffixText: 'ft',\n                    prefixIcon: Icon(Icons.straighten_outlined),\n                    helperText: 'Used with approved pipe mass data to estimate total shipping weight.',\n                  ),\n                ),\n                const SizedBox(height: 10),\n              ],\n              MarketplaceListingWeightInput(\n                key: _weightInputKey,\n                category: _category ?? '',\n                productType: _productType == _otherCatalogValue\n                    ? _customProductType.text.trim()\n                    : (_productType ?? ''),\n                manufacturer: isMachine\n                    ? (_equipmentBrand == _otherCatalogValue\n                        ? _brand.text.trim()\n                        : (_equipmentBrand ?? ''))\n                    : '',\n                model: isMachine\n                    ? (_equipmentModel == _otherCatalogValue\n                        ? _model.text.trim()\n                        : (_equipmentModel ?? ''))\n                    : '',\n                modelYear: isMachine ? _equipmentYear : null,\n                pipeSize: isPipe\n                    ? (_pipeSize == _otherCatalogValue\n                        ? _customPipeSize.text.trim()\n                        : (_pipeSize ?? ''))\n                    : '',\n                quantity: int.tryParse(\n                      _quantity.text.replaceAll(RegExp(r'[^0-9]'), ''),\n                    ) ??\n                    1,\n                lengthM: isPipe\n                    ? (num.tryParse(_jointLengthFt.text.trim())?.toDouble() ?? 0) *\n                        0.3048\n                    : null,\n              ),\n            ],\n`;
    source = replaceOnce(source, anchor, insert + anchor, "active listing weight UI");
  }
  source = replaceOnce(
      source,
      `        'quantityAndLength': _quantity.text.trim(),\n`,
      `        'quantityAndLength': _quantity.text.trim(),\n        if (isPipeListing && num.tryParse(_jointLengthFt.text.trim()) != null)\n          'jointLengthFt': num.tryParse(_jointLengthFt.text.trim()),\n        ...(_weightInputKey.currentState?.listingFields ??\n            const <String, dynamic>{'weightInputMode': 'catalog_estimate'}),\n`,
      "listing weight payload");
  source = replaceOnce(
      source,
      `      _quantity.clear();\n`,
      `      _quantity.clear();\n      _jointLengthFt.clear();\n`,
      "listing weight reset");
  write(file, source);
}

function patchFreightQuote() {
  const file = "lib/marketplace/marketplace_freight_quote.dart";
  let source = read(file);
  source = replaceOnce(
      source,
      `import 'marketplace_trucking_plan.dart';\n`,
      `import 'marketplace_trucking_plan.dart';\nimport 'marketplace_weight_catalog.dart';\n`,
      "freight weight import");
  if (!source.includes("PIPEBUYER_WEIGHT_SNAPSHOT_V1")) {
    source = replaceOnce(
        source,
        `  static FreightWeightEstimate fromListing(Map<String, dynamic> data) {\n`,
        `  static FreightWeightEstimate fromListing(Map<String, dynamic> data) {\n    // PIPEBUYER_WEIGHT_SNAPSHOT_V1\n    final frozen = MarketplaceWeightEstimate.fromListing(data);\n    if (frozen.hasWeight) {\n      return FreightWeightEstimate(\n        kg: frozen.kg,\n        source: frozen.source,\n        confidence: frozen.confidence,\n      );\n    }\n    if (frozen.status == 'unknown') {\n      return FreightWeightEstimate(\n        kg: null,\n        source: frozen.source,\n        confidence: frozen.confidence,\n      );\n    }\n`,
        "freight frozen snapshot");
  }
  if (!source.includes("PIPEBUYER_WEIGHT_CATALOG_RESOLVER_V1")) {
    const old = `    final make = '\${data['brand'] ?? data['make'] ?? ''}'.trim();\n    final model = '\${data['model'] ?? ''}'.trim();\n    if (make.isEmpty || model.isEmpty) return listed;\n    final key = _catalogKey(make, model);\n    final catalog = await FirebaseFirestore.instance\n        .collection('weight_catalog')\n        .doc(key)\n        .get();\n    final value = catalog.data()?['operatingWeightKg'] as num? ??\n        catalog.data()?['shippingWeightKg'] as num?;\n    if (value == null || value <= 0) return listed;\n    return FreightWeightEstimate(\n        kg: value.toDouble(),\n        source:\n            '\${catalog.data()?['manufacturer'] ?? make} verified catalog • $make $model',\n        confidence: '\${catalog.data()?['verificationStatus'] ?? 'catalog'}');\n`;
    const replacement = `    // PIPEBUYER_WEIGHT_CATALOG_RESOLVER_V1\n    final resolved = await MarketplaceWeightCatalogRepository().resolve(\n      category: '\${data['category'] ?? ''}',\n      productType: '\${data['productType'] ?? ''}',\n      manufacturer: '\${data['brand'] ?? data['make'] ?? ''}',\n      model: '\${data['model'] ?? ''}',\n      modelYear: (data['modelYear'] as num?)?.toInt(),\n      pipeSize: '\${data['pipeSize'] ?? ''}',\n      quantity: (data['quantity'] as num?)?.toInt() ?? 1,\n      lengthM: _number(data['jointLengthM']) ??\n          ((_number(data['jointLengthFt']) ?? 0) * 0.3048),\n    );\n    if (!resolved.hasWeight) return listed;\n    return FreightWeightEstimate(\n      kg: resolved.kg,\n      source: resolved.source,\n      confidence: resolved.confidence,\n    );\n`;
    source = replaceOnce(source, old, replacement, "freight catalog resolver");
  }
  source = source.replace(/\n  static String _catalogKey\(String make, String model\) =>\n      '\$\{make\}_\$model'\.toLowerCase\(\)\.replaceAll\(RegExp\(r'\[\^a-z0-9\]\+'\), '_'\);\n/, "\n");
  source = replaceOnce(
      source,
      `    required this.weightChanged,\n  });\n\n  final String pickup;\n  final MarketplaceLocation delivery;\n  final double weightKg;\n`,
      `    required this.weightChanged,\n    required this.weightUnknown,\n  });\n\n  final String pickup;\n  final MarketplaceLocation delivery;\n  final double? weightKg;\n`,
      "nullable freight draft weight");
  source = replaceOnce(
      source,
      `  final bool weightChanged;\n}\n\nclass _FreightQuoteDialog`,
      `  final bool weightChanged;\n  final bool weightUnknown;\n}\n\nclass _FreightQuoteDialog`,
      "freight unknown field");
  source = replaceOnce(
      source,
      `  bool _weightChanged = false;\n`,
      `  bool _weightChanged = false;\n  bool _weightUnknown = false;\n`,
      "freight unknown state");
  source = replaceOnce(
      source,
      `  double? get _enteredWeight {\n    final value = double.tryParse(_weight.text.trim().replaceAll(',', ''));\n`,
      `  double? get _enteredWeight {\n    if (_weightUnknown) return null;\n    final value = double.tryParse(_weight.text.trim().replaceAll(',', ''));\n`,
      "unknown entered weight");
  source = replaceOnce(
      source,
      `            weightKg: _enteredWeight!,\n            details: _details.text.trim(),\n            truckingDate: _date,\n            weightChanged: _weightChanged));\n`,
      `            weightKg: _enteredWeight,\n            details: _details.text.trim(),\n            truckingDate: _date,\n            weightChanged: _weightChanged,\n            weightUnknown: _weightUnknown));\n`,
      "nullable draft construction");
  source = replaceOnce(
      source,
      `          weightSource:\n              draft.weightChanged ? 'shipper_adjusted' : estimate.source,\n`,
      `          weightSource: draft.weightUnknown\n              ? (estimate.kg == null\n                  ? 'shipper_unknown'\n                  : 'shipper_unknown_catalog_reference_available')\n              : draft.weightChanged\n                  ? 'shipper_adjusted'\n                  : estimate.source,\n`,
      "unknown dispatch source");
  source = replaceOnce(
      source,
      `              const SizedBox(height: 9),\n              TextFormField(\n                  controller: _weight,\n`,
      `              const SizedBox(height: 9),\n              Wrap(spacing: 8, runSpacing: 8, children: [\n                ChoiceChip(\n                  selected: !_weightUnknown,\n                  label: Text(widget.estimate.kg == null\n                      ? 'Enter approximate weight'\n                      : 'Use / adjust approximate weight'),\n                  avatar: const Icon(Icons.scale_outlined, size: 18),\n                  onSelected: (_) => setState(() => _weightUnknown = false),\n                ),\n                ChoiceChip(\n                  selected: _weightUnknown,\n                  label: const Text(\"I don't know the weight\"),\n                  avatar: const Icon(Icons.help_outline, size: 18),\n                  onSelected: (_) => setState(() {\n                    _weightUnknown = true;\n                    _weightChanged = false;\n                  }),\n                ),\n              ]),\n              const SizedBox(height: 9),\n              if (!_weightUnknown)\n                TextFormField(\n                  controller: _weight,\n`,
      "freight unknown choice");
  source = replaceOnce(
      source,
      `                  validator: (_) => _enteredWeight == null\n                      ? 'Enter a valid load weight'\n                      : null),\n              const SizedBox(height: 8),\n              _weightAnalytics(),\n`,
      `                  validator: (_) => _weightUnknown\n                      ? null\n                      : _enteredWeight == null\n                          ? 'Enter a valid load weight or choose “I don’t know”'\n                          : null),\n              if (_weightUnknown)\n                const Padding(\n                  padding: EdgeInsets.only(top: 4),\n                  child: Card(\n                    margin: EdgeInsets.zero,\n                    color: Color(0xFFFFF4E5),\n                    child: Padding(\n                      padding: EdgeInsets.all(11),\n                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                        Icon(Icons.warning_amber_rounded, color: Color(0xFFF08A24)),\n                        SizedBox(width: 8),\n                        Expanded(child: Text(\n                          'Weight will be marked TO CONFIRM. Carriers may quote subject to verified machine/load configuration and certified weights before transport.',\n                          style: TextStyle(fontSize: 11),\n                        )),\n                      ]),\n                    ),\n                  ),\n                ),\n              const SizedBox(height: 8),\n              _weightAnalytics(),\n`,
      "freight validation and unknown notice");
  source = replaceOnce(
      source,
      `  Widget _weightAnalytics() {\n    final kg = _enteredWeight;\n`,
      `  Widget _weightAnalytics() {\n    if (_weightUnknown) {\n      return const SizedBox.shrink();\n    }\n    final kg = _enteredWeight;\n`,
      "unknown analytics");
  source = replaceOnce(
      source,
      `    final kg = draft.weightKg;\n    final weight =\n        '\${_formatNumber(kg)} kg • \${(kg / 1000).toStringAsFixed(2)} t';\n`,
      `    final kg = draft.weightKg;\n    final weight = kg == null\n        ? 'TO CONFIRM — shipper does not know the load weight'\n        : '\${_formatNumber(kg)} kg • \${(kg / 1000).toStringAsFixed(2)} t';\n`,
      "review unknown weight");
  source = replaceOnce(
      source,
      `'The entered weight is for quote planning, not a certified legal load weight. The carrier remains responsible for axle, permit and route compliance.'`,
      `marketplaceWeightDisclaimer`,
      "shared legal weight disclaimer");
  write(file, source);
}

function patchMessages() {
  const file = "lib/marketplace/marketplace_messages_page.dart";
  let source = read(file);
  source = replaceOnce(
      source,
      `import 'package:image_picker/image_picker.dart';\n`,
      `import 'package:image_picker/image_picker.dart';\nimport 'package:url_launcher/url_launcher.dart';\n`,
      "message video launcher import");
  source = replaceOnce(
      source,
      `  bool _uploading = false;\n  Map<String, dynamic>? _attachment;\n`,
      `  bool _uploading = false;\n  Map<String, dynamic>? _attachment;\n  OverlayEntry? _attachmentToast;\n  Timer? _attachmentToastTimer;\n`,
      "chat toast state");
  source = replaceOnce(
      source,
      `  @override\n  void initState() {\n`,
      `  @override\n  void initState() {\n`,
      "noop init anchor");
  // Only alter the chat state's dispose block by anchoring the controller.
  source = replaceOnce(
      source,
      `  @override\n  void dispose() {\n    _controller.dispose();\n`,
      `  @override\n  void dispose() {\n    _attachmentToastTimer?.cancel();\n    _attachmentToast?.remove();\n    _controller.dispose();\n`,
      "chat toast dispose");
  source = replaceOnce(
      source,
      `            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),\n`,
      `            padding: const EdgeInsets.fromLTRB(10, 8, 8, 22),\n`,
      "lift chat composer");
  if (!source.includes("message['attachment'] as Map)['type'] == 'video'")) {
    const anchor = `                            if (hiddenByModeration)\n`;
    const video = `                            if (!hiddenByModeration &&\n                                message['attachment'] is Map &&\n                                (message['attachment'] as Map)['type'] ==\n                                    'video')\n                              InkWell(\n                                onTap: () => _openAttachmentUrl(\n                                  '\${(message['attachment'] as Map)['url']}',\n                                ),\n                                borderRadius: BorderRadius.circular(10),\n                                child: Container(\n                                  width: 220,\n                                  padding: const EdgeInsets.all(12),\n                                  decoration: BoxDecoration(\n                                    color: mine ? Colors.white12 : Colors.black.withValues(alpha: .04),\n                                    borderRadius: BorderRadius.circular(10),\n                                  ),\n                                  child: Row(children: [\n                                    Icon(Icons.play_circle_outline,\n                                        color: mine ? Colors.white : Colors.black87),\n                                    const SizedBox(width: 8),\n                                    Expanded(child: Text(\n                                      '\${(message['attachment'] as Map)['name'] ?? 'Video attachment'}',\n                                      maxLines: 2,\n                                      overflow: TextOverflow.ellipsis,\n                                      style: TextStyle(\n                                        color: mine ? Colors.white : Colors.black87,\n                                        fontWeight: FontWeight.w800,\n                                      ),\n                                    )),\n                                    Icon(Icons.open_in_new, size: 16,\n                                        color: mine ? Colors.white70 : Colors.black54),\n                                  ]),\n                                ),\n                              ),\n`;
    source = replaceOnce(source, anchor, video + anchor, "video message card");
  }
  source = replaceOnce(
      source,
      `                    avatar: const Icon(Icons.image_outlined),\n`,
      `                    avatar: Icon(\n                      _attachment!['type'] == 'video'\n                          ? Icons.videocam_outlined\n                          : Icons.image_outlined,\n                    ),\n`,
      "attachment chip type");
  if (!source.includes("void _showAttachmentToast")) {
    const anchor = `  Future<void> _send() async {\n`;
    const helper = `  void _showAttachmentToast(String message, {required bool video}) {\n    _attachmentToastTimer?.cancel();\n    _attachmentToast?.remove();\n    final overlay = Overlay.of(context, rootOverlay: true);\n    late final OverlayEntry entry;\n    entry = OverlayEntry(\n      builder: (_) => Positioned.fill(\n        child: IgnorePointer(\n          child: Center(\n            child: Material(\n              color: Colors.transparent,\n              child: Container(\n                constraints: const BoxConstraints(maxWidth: 340),\n                margin: const EdgeInsets.all(24),\n                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),\n                decoration: BoxDecoration(\n                  color: const Color(0xFF151A20),\n                  borderRadius: BorderRadius.circular(14),\n                  boxShadow: const [\n                    BoxShadow(color: Color(0x33000000), blurRadius: 22, offset: Offset(0, 8)),\n                  ],\n                ),\n                child: Row(mainAxisSize: MainAxisSize.min, children: [\n                  Icon(video ? Icons.videocam_outlined : Icons.image_outlined,\n                      color: const Color(0xFFFF6A00), size: 21),\n                  const SizedBox(width: 9),\n                  Flexible(child: Text(message,\n                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),\n                ]),\n              ),\n            ),\n          ),\n        ),\n      ),\n    );\n    _attachmentToast = entry;\n    overlay.insert(entry);\n    _attachmentToastTimer = Timer(const Duration(milliseconds: 2300), () {\n      if (_attachmentToast == entry) _attachmentToast = null;\n      entry.remove();\n    });\n  }\n\n  Future<void> _openAttachmentUrl(String rawUrl) async {\n    final uri = Uri.tryParse(rawUrl);\n    if (uri == null || !await launchUrl(uri, mode: LaunchMode.platformDefault)) {\n      if (mounted) {\n        PipeFeedback.show(\n          context,\n          message: 'The attachment could not be opened.',\n          tone: PipeStatusTone.warning,\n        );\n      }\n    }\n  }\n\n`;
    source = replaceOnce(source, anchor, helper + anchor, "centered attachment toast helper");
  }
  // Replace the image-only picker with a media-aware picker.
  const pickerStart = source.indexOf("  Future<void> _pickAttachment() async {");
  const pickerEndMarker = "\n  Future<void> _reportConversation() async {";
  const pickerEnd = source.indexOf(pickerEndMarker, pickerStart);
  if (pickerStart < 0 || pickerEnd < 0) throw new Error("Chat attachment picker anchors not found");
  const currentPicker = source.slice(pickerStart, pickerEnd);
  if (!currentPicker.includes("gallery_video")) {
    const picker = `  Future<void> _pickAttachment() async {\n    final choice = await showModalBottomSheet<String>(\n      context: context,\n      shape: const RoundedRectangleBorder(\n        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),\n      ),\n      builder: (ctx) => SafeArea(\n        child: Column(\n          mainAxisSize: MainAxisSize.min,\n          children: [\n            const Padding(\n              padding: EdgeInsets.all(16),\n              child: Text('Attach media',\n                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),\n            ),\n            ListTile(\n              leading: const Icon(Icons.photo_library, color: Color(0xFFFF6A00)),\n              title: const Text('Choose photo'),\n              onTap: () => Navigator.pop(ctx, 'gallery_image'),\n            ),\n            ListTile(\n              leading: const Icon(Icons.camera_alt, color: Color(0xFF10B981)),\n              title: const Text('Take photo'),\n              onTap: () => Navigator.pop(ctx, 'camera_image'),\n            ),\n            ListTile(\n              leading: const Icon(Icons.video_library_outlined, color: Color(0xFFFF6A00)),\n              title: const Text('Choose video'),\n              subtitle: const Text('MP4 or MOV • maximum 25 MB'),\n              onTap: () => Navigator.pop(ctx, 'gallery_video'),\n            ),\n            ListTile(\n              leading: const Icon(Icons.videocam_outlined, color: Color(0xFF10B981)),\n              title: const Text('Record video'),\n              subtitle: const Text('Maximum 25 MB'),\n              onTap: () => Navigator.pop(ctx, 'camera_video'),\n            ),\n            const SizedBox(height: 12),\n          ],\n        ),\n      ),\n    );\n    if (choice == null) return;\n\n    try {\n      final isVideo = choice.endsWith('_video');\n      final sourceType = choice.startsWith('camera')\n          ? ImageSource.camera\n          : ImageSource.gallery;\n      final file = isVideo\n          ? await ImagePicker().pickVideo(\n              source: sourceType,\n              maxDuration: const Duration(minutes: 2),\n            )\n          : await ImagePicker().pickImage(\n              source: sourceType, imageQuality: 82, maxWidth: 1800);\n      if (file == null) return;\n      final sizeBytes = await file.length();\n      final maximumBytes = isVideo ? 25 * 1024 * 1024 : 15 * 1024 * 1024;\n      if (sizeBytes > maximumBytes) {\n        if (mounted) {\n          PipeFeedback.show(\n            context,\n            message: isVideo\n                ? 'Video attachments must be under 25 MB.'\n                : 'Image attachments must be under 15 MB.',\n            tone: PipeStatusTone.warning,\n          );\n        }\n        return;\n      }\n      setState(() => _uploading = true);\n      final extension = file.name.split('.').last.toLowerCase();\n      final contentType = isVideo\n          ? (extension == 'mov' ? 'video/quicktime' : 'video/mp4')\n          : extension == 'png'\n              ? 'image/png'\n              : extension == 'webp'\n                  ? 'image/webp'\n                  : 'image/jpeg';\n      final authorization = await _actions.authorizeUpload(\n          purpose: 'chat_attachment',\n          originalName: file.name,\n          contentType: contentType,\n          sizeBytes: sizeBytes,\n          conversationId: widget.conversationId);\n      final authorizationId = '\${authorization['authorizationId']}';\n      final reference =\n          FirebaseStorage.instance.ref('\${authorization['storagePath']}');\n      await reference.putData(\n          await file.readAsBytes(),\n          SettableMetadata(\n              contentType: contentType,\n              customMetadata: {'conversationId': widget.conversationId}));\n      final url = await reference.getDownloadURL();\n      await _actions.confirmUpload(authorizationId: authorizationId, url: url);\n      if (mounted) {\n        setState(() => _attachment = {\n              'type': isVideo ? 'video' : 'image',\n              'authorizationId': authorizationId,\n              'url': url,\n              'name': file.name,\n            });\n        _showAttachmentToast(\n          isVideo\n              ? 'Video attached • add a message or press Send'\n              : 'Image attached • add a message or press Send',\n          video: isVideo,\n        );\n      }\n    } on FirebaseException catch (error) {\n      if (mounted) {\n        PipeFeedback.show(\n          context,\n          message: error.code == 'unauthorized'\n              ? 'Media upload is not authorized. Refresh your account and try again.'\n              : 'Media upload failed. Please try again.',\n          tone: PipeStatusTone.error,\n        );\n      }\n    } catch (error) {\n      if (mounted) {\n        PipeFeedback.show(\n          context,\n          message: marketplaceCommandErrorMessage(\n            error,\n            fallback: 'Could not attach this media. Try another file.',\n          ),\n          tone: PipeStatusTone.error,\n        );\n      }\n    } finally {\n      if (mounted) setState(() => _uploading = false);\n    }\n  }\n`;
    source = source.slice(0, pickerStart) + picker + source.slice(pickerEnd);
  }
  write(file, source);
}

function patchCommunicationPolicy() {
  const file = "firebase/functions/communication_command_policy.js";
  let source = read(file);
  source = replaceOnce(
      source,
      `    maximumBytes: 15 * 1024 * 1024,\n    contentTypes: new Set([\n      "image/jpeg",\n      "image/png",\n      "image/webp",\n      "application/pdf",\n    ]),\n`,
      `    maximumBytes: 25 * 1024 * 1024,\n    imageMaximumBytes: 15 * 1024 * 1024,\n    contentTypes: new Set([\n      "image/jpeg",\n      "image/png",\n      "image/webp",\n      "application/pdf",\n      "video/mp4",\n      "video/quicktime",\n    ]),\n`,
      "chat video policy");
  source = replaceOnce(
      source,
      `  if (!policy.contentTypes.has(contentType)) {\n`,
      `  if (policy.imageMaximumBytes &&\n      (contentType.startsWith("image/") || contentType === "application/pdf") &&\n      sizeBytes > policy.imageMaximumBytes) {\n    throw new CommunicationPolicyError(\n        "invalid-argument",\n        \`Images and documents must be \${policy.imageMaximumBytes} bytes or smaller.\`,\n    );\n  }\n  if (!policy.contentTypes.has(contentType)) {\n`,
      "chat image sublimit");
  write(file, source);
}

function patchAdminCleanup() {
  const file = "lib/marketplace/marketplace_weight_catalog_admin.dart";
  let source = read(file);
  source = source.replace("import 'marketplace_money.dart';\n", "");
  write(file, source);
}

function patchSandboxLauncher() {
  const file = "tool/start_live_test_sandbox.ps1";
  let source = read(file);
  if (!source.includes("seed_live_test_weight_catalog.js")) {
    const anchor = `  & node (Join-Path $functionsDir 'scripts\\seed_live_test_dispatch_access.js')\n  if ($LASTEXITCODE -ne 0) {\n    throw 'Dispatch carrier-access seed failed. Check the error above.'\n  }\n`;
    const block = `${anchor}\n  & node (Join-Path $functionsDir 'scripts\\seed_live_test_weight_catalog.js')\n  if ($LASTEXITCODE -ne 0) {\n    throw 'Weight catalog seed failed. Check the error above.'\n  }\n`;
    source = replaceOnce(source, anchor, block, "weight catalog sandbox seed");
  }
  write(file, source);
}

patchListingPolicy();
patchWeightTrigger();
patchListingForm();
patchFreightQuote();
patchMessages();
patchCommunicationPolicy();
patchAdminCleanup();
patchSandboxLauncher();

console.log("Applied PipeBuyer weight-catalog, Dispatch unknown-weight, and chat media UX batch.");
