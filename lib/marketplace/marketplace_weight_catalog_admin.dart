import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_money.dart';
import 'marketplace_weight_catalog.dart';

class MarketplaceWeightCatalogAdminPage extends StatelessWidget {
  const MarketplaceWeightCatalogAdminPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: PipeBuyerPageHeader(
                eyebrow: 'ADMIN REFERENCE DATA',
                title: 'Weight Catalog',
                subtitle:
                    'Maintain reviewed planning weights for pipe, equipment and industrial inventory. Catalog values are estimates and never replace certified legal load weights.',
                icon: Icons.scale_outlined,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(icon: Icon(Icons.dataset_outlined), text: 'Catalog'),
                  Tab(icon: Icon(Icons.rate_review_outlined), text: 'Suggestions'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _WeightCatalogList(),
                  _WeightSuggestionList(),
                ],
              ),
            ),
          ],
        ),
      );
}

class _WeightCatalogList extends StatelessWidget {
  const _WeightCatalogList();

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('weight_catalog')
            .orderBy('updatedAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          return Stack(
            children: [
              if (snapshot.connectionState == ConnectionState.waiting && docs.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Weight catalog could not be loaded: ${snapshot.error}'),
                  ),
                )
              else if (docs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No reviewed weight references have been added yet.'),
                  ),
                )
              else
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 90),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _WeightCatalogCard(document: docs[index]),
                ),
              Positioned(
                right: 22,
                bottom: 20,
                child: FloatingActionButton.extended(
                  onPressed: () => _showWeightEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add weight reference'),
                ),
              ),
            ],
          );
        },
      );
}

class _WeightCatalogCard extends StatelessWidget {
  const _WeightCatalogCard({required this.document});
  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  @override
  Widget build(BuildContext context) {
    final data = document.data();
    final make = '${data['manufacturer'] ?? ''}'.trim();
    final model = '${data['model'] ?? ''}'.trim();
    final product = '${data['productType'] ?? ''}'.trim();
    final pipeSize = '${data['pipeSize'] ?? ''}'.trim();
    final title = [make, model].where((part) => part.isNotEmpty).join(' ').trim();
    final effectiveTitle = title.isNotEmpty
        ? title
        : [product, pipeSize].where((part) => part.isNotEmpty).join(' • ');
    final weight = _catalogWeightSummary(data);
    final active = data['active'] != false;
    return PipeBuyerSectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: PipeBuyerColors.industrialBlue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.scale_outlined,
                color: PipeBuyerColors.industrialBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    effectiveTitle.isEmpty ? document.id : effectiveTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
                PipeBuyerStatusBadge(
                  label: active ? 'ACTIVE' : 'INACTIVE',
                  icon: active ? Icons.check_circle_outline : Icons.pause_circle_outline,
                  tone: active
                      ? PipeBuyerStatusTone.success
                      : PipeBuyerStatusTone.neutral,
                ),
              ]),
              const SizedBox(height: 5),
              Text(weight,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                '${data['sourceName'] ?? 'Source not named'} • ${data['verificationStatus'] ?? 'review required'} • revision ${data['revision'] ?? 1}',
                style: const TextStyle(fontSize: 11, color: PipeBuyerColors.muted),
              ),
              if ('${data['variant'] ?? ''}'.trim().isNotEmpty)
                Text('Variant: ${data['variant']}',
                    style: const TextStyle(fontSize: 11, color: PipeBuyerColors.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Edit weight reference',
            onPressed: () => _showWeightEditor(
              context,
              documentId: document.id,
              existing: data,
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _WeightSuggestionList extends StatelessWidget {
  const _WeightSuggestionList();

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('weight_suggestions')
            .where('status', isEqualTo: 'pending')
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Suggestions could not be loaded: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No pending weight corrections.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final kg = data['suggestedWeightKg'] as num?;
              return PipeBuyerSectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.rate_review_outlined,
                        color: PipeBuyerColors.orangePressed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${data['listingTitle'] ?? 'Weight suggestion'}',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                    if (kg != null)
                      Text('${kg.toStringAsFixed(0)} kg',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    [data['make'], data['model'], data['productType']]
                        .where((value) => '${value ?? ''}'.trim().isNotEmpty)
                        .join(' • '),
                    style: const TextStyle(color: PipeBuyerColors.slate),
                  ),
                  if ('${data['evidenceSource'] ?? ''}'.trim().isNotEmpty)
                    Text('Evidence: ${data['evidenceSource']}',
                        style: const TextStyle(fontSize: 11)),
                  if ('${data['reason'] ?? ''}'.trim().isNotEmpty)
                    Text('${data['reason']}',
                        style: const TextStyle(fontSize: 11, color: PipeBuyerColors.muted)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await _showWeightEditor(
                          context,
                          suggestion: data,
                          suggestionId: doc.id,
                        );
                      },
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Review into catalog'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _resolveSuggestion(context, doc.id, 'rejected'),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                    ),
                  ]),
                ]),
              );
            },
          );
        },
      );
}

Future<void> _resolveSuggestion(
  BuildContext context,
  String suggestionId,
  String status,
) async {
  try {
    await FirebaseFirestore.instance
        .collection('weight_suggestions')
        .doc(suggestionId)
        .set({
      'status': status,
      'reviewedByUid': FirebaseAuth.instance.currentUser?.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (context.mounted) {
      PipeFeedback.show(
        context,
        message: 'Weight suggestion marked $status.',
        tone: PipeStatusTone.success,
      );
    }
  } catch (error) {
    if (context.mounted) {
      PipeFeedback.show(
        context,
        message: 'Weight suggestion could not be updated: $error',
        tone: PipeStatusTone.error,
      );
    }
  }
}

Future<void> _showWeightEditor(
  BuildContext context, {
  String? documentId,
  Map<String, dynamic>? existing,
  Map<String, dynamic>? suggestion,
  String? suggestionId,
}) async {
  final seed = existing ?? suggestion ?? const <String, dynamic>{};
  final kind = ValueNotifier<String>('${seed['kind'] ?? ((seed['make'] ?? seed['manufacturer']) != null ? 'equipment' : 'pipe')}');
  final category = TextEditingController(text: '${seed['category'] ?? ''}');
  final productType = TextEditingController(text: '${seed['productType'] ?? ''}');
  final manufacturer = TextEditingController(text: '${seed['manufacturer'] ?? seed['make'] ?? ''}');
  final model = TextEditingController(text: '${seed['model'] ?? ''}');
  final yearFrom = TextEditingController(text: '${seed['modelYearFrom'] ?? ''}');
  final yearTo = TextEditingController(text: '${seed['modelYearTo'] ?? ''}');
  final variant = TextEditingController(text: '${seed['variant'] ?? ''}');
  final pipeSize = TextEditingController(text: '${seed['pipeSize'] ?? ''}');
  final operating = TextEditingController(text: '${seed['operatingWeightKg'] ?? ''}');
  final shipping = TextEditingController(
      text: '${seed['shippingWeightKg'] ?? seed['suggestedWeightKg'] ?? ''}');
  final minWeight = TextEditingController(text: '${seed['operatingWeightMinKg'] ?? ''}');
  final maxWeight = TextEditingController(text: '${seed['operatingWeightMaxKg'] ?? ''}');
  final unitWeight = TextEditingController(text: '${seed['unitWeightKg'] ?? ''}');
  final kgPerM = TextEditingController(text: '${seed['kgPerM'] ?? ''}');
  final lbFt = TextEditingController(text: '${seed['nominalWeightLbFt'] ?? ''}');
  final sourceName = TextEditingController(text: '${seed['sourceName'] ?? seed['evidenceSource'] ?? ''}');
  final sourceUrl = TextEditingController(text: '${seed['sourceUrl'] ?? ''}');
  final sourceReference = TextEditingController(text: '${seed['sourceReference'] ?? ''}');
  final verification = TextEditingController(
      text: '${seed['verificationStatus'] ?? 'admin reviewed'}');
  final formKey = GlobalKey<FormState>();
  bool active = seed['active'] != false;

  final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(documentId == null ? 'Add weight reference' : 'Edit weight reference'),
            content: SizedBox(
              width: 720,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ValueListenableBuilder<String>(
                      valueListenable: kind,
                      builder: (_, value, __) => SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'equipment', label: Text('Equipment')),
                          ButtonSegment(value: 'pipe', label: Text('Pipe')),
                          ButtonSegment(value: 'product', label: Text('Other product')),
                        ],
                        selected: {value},
                        onSelectionChanged: (values) => kind.value = values.first,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _editorRow([
                      _EditorField(controller: category, label: 'Category'),
                      _EditorField(controller: productType, label: 'Product type'),
                    ]),
                    _editorRow([
                      _EditorField(controller: manufacturer, label: 'Manufacturer / make'),
                      _EditorField(controller: model, label: 'Model'),
                    ]),
                    _editorRow([
                      _EditorField(controller: yearFrom, label: 'Model year from', numeric: true),
                      _EditorField(controller: yearTo, label: 'Model year to', numeric: true),
                      _EditorField(controller: variant, label: 'Variant / configuration'),
                    ]),
                    _EditorField(controller: pipeSize, label: 'Pipe size / designation'),
                    const Divider(height: 26),
                    const Text('Weight values (kg unless noted)',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    _editorRow([
                      _EditorField(controller: operating, label: 'Operating weight', numeric: true),
                      _EditorField(controller: shipping, label: 'Shipping weight', numeric: true),
                    ]),
                    _editorRow([
                      _EditorField(controller: minWeight, label: 'Minimum configuration', numeric: true),
                      _EditorField(controller: maxWeight, label: 'Maximum configuration', numeric: true),
                    ]),
                    _editorRow([
                      _EditorField(controller: unitWeight, label: 'Unit weight', numeric: true),
                      _EditorField(controller: kgPerM, label: 'kg / metre', numeric: true),
                      _EditorField(controller: lbFt, label: 'lb / foot', numeric: true),
                    ]),
                    const Divider(height: 26),
                    const Text('Source & review evidence',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    _EditorField(
                      controller: sourceName,
                      label: 'Source name *',
                      required: true,
                    ),
                    _EditorField(controller: sourceUrl, label: 'Source URL'),
                    _EditorField(controller: sourceReference,
                        label: 'Source reference / publication / table'),
                    _EditorField(controller: verification,
                        label: 'Verification status *', required: true),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      onChanged: (value) => setDialogState(() => active = value),
                      title: const Text('Active for new listing estimates'),
                      subtitle: const Text(
                          'Existing listing snapshots are not rewritten when this catalog entry changes.'),
                    ),
                    const SizedBox(height: 8),
                    const Text(marketplaceWeightDisclaimer,
                        style: TextStyle(fontSize: 10.5, color: PipeBuyerColors.muted)),
                  ]),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton.icon(
                onPressed: () {
                  if (formKey.currentState?.validate() != true) return;
                  Navigator.pop(dialogContext, true);
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save reviewed reference'),
              ),
            ],
          ),
        ),
      ) ??
      false;

  try {
    if (!save) return;
    num? number(TextEditingController controller) =>
        num.tryParse(controller.text.trim().replaceAll(',', ''));
    final resolvedId = documentId ??
        marketplaceWeightCatalogIds(
          category: category.text,
          productType: productType.text,
          manufacturer: manufacturer.text,
          model: model.text,
          modelYear: int.tryParse(yearFrom.text.trim()),
          pipeSize: pipeSize.text,
        ).firstOrNull;
    if (resolvedId == null || resolvedId.isEmpty) {
      throw StateError('Add enough identifying information to create a catalog key.');
    }
    final reference = FirebaseFirestore.instance.collection('weight_catalog').doc(resolvedId);
    final prior = await reference.get();
    final revision = ((prior.data()?['revision'] as num?)?.toInt() ?? 0) + 1;
    await reference.set({
      'kind': kind.value,
      'category': category.text.trim(),
      'productType': productType.text.trim(),
      'manufacturer': manufacturer.text.trim(),
      'model': model.text.trim(),
      if (int.tryParse(yearFrom.text.trim()) != null)
        'modelYearFrom': int.parse(yearFrom.text.trim()),
      if (int.tryParse(yearTo.text.trim()) != null)
        'modelYearTo': int.parse(yearTo.text.trim()),
      'variant': variant.text.trim(),
      'pipeSize': pipeSize.text.trim(),
      if (number(operating) != null) 'operatingWeightKg': number(operating),
      if (number(shipping) != null) 'shippingWeightKg': number(shipping),
      if (number(minWeight) != null) 'operatingWeightMinKg': number(minWeight),
      if (number(maxWeight) != null) 'operatingWeightMaxKg': number(maxWeight),
      if (number(unitWeight) != null) 'unitWeightKg': number(unitWeight),
      if (number(kgPerM) != null) 'kgPerM': number(kgPerM),
      if (number(lbFt) != null) 'nominalWeightLbFt': number(lbFt),
      'sourceName': sourceName.text.trim(),
      'sourceUrl': sourceUrl.text.trim(),
      'sourceReference': sourceReference.text.trim(),
      'verificationStatus': verification.text.trim(),
      'active': active,
      'revision': revision,
      'updatedByUid': FirebaseAuth.instance.currentUser?.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!prior.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (suggestionId != null) {
      await FirebaseFirestore.instance.collection('weight_suggestions').doc(suggestionId).set({
        'status': 'approved',
        'catalogId': resolvedId,
        'reviewedByUid': FirebaseAuth.instance.currentUser?.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (context.mounted) {
      PipeFeedback.show(
        context,
        message: 'Weight catalog reference saved as revision $revision.',
        tone: PipeStatusTone.success,
      );
    }
  } catch (error) {
    if (context.mounted) {
      PipeFeedback.show(
        context,
        message: 'Weight reference could not be saved: $error',
        tone: PipeStatusTone.error,
      );
    }
  } finally {
    kind.dispose();
    for (final controller in [
      category,
      productType,
      manufacturer,
      model,
      yearFrom,
      yearTo,
      variant,
      pipeSize,
      operating,
      shipping,
      minWeight,
      maxWeight,
      unitWeight,
      kgPerM,
      lbFt,
      sourceName,
      sourceUrl,
      sourceReference,
      verification,
    ]) {
      controller.dispose();
    }
  }
}

Widget _editorRow(List<Widget> children) => LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(children: [for (final child in children) child]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.controller,
    required this.label,
    this.numeric = false,
    this.required = false,
  });
  final TextEditingController controller;
  final String label;
  final bool numeric;
  final bool required;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextFormField(
          controller: controller,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          validator: required
              ? (value) => value == null || value.trim().isEmpty ? '$label is required' : null
              : null,
        ),
      );
}

String _catalogWeightSummary(Map<String, dynamic> data) {
  String moneyless(num value) => value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  final operating = data['operatingWeightKg'] as num?;
  final shipping = data['shippingWeightKg'] as num?;
  final min = data['operatingWeightMinKg'] as num?;
  final max = data['operatingWeightMaxKg'] as num?;
  final kgM = data['kgPerM'] as num?;
  final lbFt = data['nominalWeightLbFt'] as num?;
  if (operating != null) return '${moneyless(operating)} kg operating weight';
  if (shipping != null) return '${moneyless(shipping)} kg shipping weight';
  if (min != null && max != null) return '${moneyless(min)}–${moneyless(max)} kg configuration range';
  if (kgM != null) return '${moneyless(kgM)} kg/m';
  if (lbFt != null) return '${moneyless(lbFt)} lb/ft';
  return 'Reference metadata only — no numeric weight entered';
}
