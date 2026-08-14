import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/data/bounded_firestore_query.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'industrial_icon_assets.dart';
import 'marketplace_admin_access.dart';

class MarketplaceProfileTags extends StatefulWidget {
  const MarketplaceProfileTags({super.key, required this.accountType});
  final String accountType;

  @override
  State<MarketplaceProfileTags> createState() => _MarketplaceProfileTagsState();
}

class _MarketplaceProfileTagsState extends State<MarketplaceProfileTags> {
  String _category = 'sales';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SpecialtiesHeader(
              accountType: widget.accountType,
              onSuggest: () => _requestTag(context, user),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('marketplace_tags')
                  .where('status', isEqualTo: 'approved')
                  .orderBy('label')
                  .limit(defaultReferenceDataLimit)
                  .snapshots(),
              builder: (context, catalogSnapshot) => StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('profile_tags')
                    .limit(defaultActivityFeedLimit)
                    .snapshots(),
                builder: (context, selectedSnapshot) {
                  if (!catalogSnapshot.hasData &&
                      catalogSnapshot.connectionState ==
                          ConnectionState.waiting) {
                    return const _TagLoadingState();
                  }
                  if (catalogSnapshot.hasError) {
                    return const _TagMessageState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Specialties unavailable',
                      message:
                          'The marketplace specialty catalog could not be loaded right now.',
                    );
                  }

                  final selected = {
                    for (final doc in selectedSnapshot.data?.docs ?? const [])
                      doc.id: doc.data()
                  };
                  final catalog = [...?catalogSnapshot.data?.docs]
                    ..sort((a, b) => '${a.data()['label']}'
                        .compareTo('${b.data()['label']}'));
                  final categories = catalog
                      .map((doc) => '${doc.data()['category']}')
                      .toSet()
                      .toList()
                    ..sort();
                  if (categories.isNotEmpty &&
                      !categories.contains(_category)) {
                    _category = categories.first;
                  }
                  final visible = catalog
                      .where((doc) => doc.data()['category'] == _category)
                      .toList();
                  final approvedCount = selected.values
                      .where((data) => data['status'] == 'approved')
                      .length;
                  final pending = selected.entries
                      .where((entry) => entry.value['status'] == 'pending')
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SpecialtySummary(
                        approvedCount: approvedCount,
                        pendingCount: pending.length,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        '1. Choose a specialty group',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (categories.isEmpty)
                        const _TagMessageState(
                          icon: Icons.sell_outlined,
                          title: 'Specialty catalog is being prepared',
                          message:
                              'Approved marketplace specialties will appear here when available.',
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categories
                              .map(
                                (category) => _CategoryChoice(
                                  category: category,
                                  selected: _category == category,
                                  onSelected: () =>
                                      setState(() => _category = category),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '2. Select ${_categoryLabel(_category)} specialties',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (visible.isNotEmpty)
                            Text(
                              '${visible.length} available',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: .54),
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (visible.isEmpty && categories.isNotEmpty)
                        const _TagMessageState(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'No specialties in this group yet',
                          message:
                              'You can suggest a specialty for administrator review.',
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: visible.map((doc) {
                            final data = doc.data();
                            final active = selected.containsKey(doc.id);
                            return _SpecialtyChip(
                              label: '${data['label']}',
                              category: '${data['category']}',
                              selected: active,
                              onSelected: (value) => _setApprovedTag(
                                user,
                                doc.id,
                                '${data['label']}',
                                value,
                              ),
                            );
                          }).toList(),
                        ),
                      if (pending.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Pending suggestions',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 7),
                        ...pending.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: PipeBuyerColors.warning
                                    .withValues(alpha: .07),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: PipeBuyerColors.warning
                                      .withValues(alpha: .24),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    color: PipeBuyerColors.warning,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${entry.value['label']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'AWAITING APPROVAL',
                                    style: TextStyle(
                                      color: PipeBuyerColors.warning,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            FutureBuilder<bool>(
              future: marketplaceAdministratorAccess(),
              builder: (context, access) => access.data == true
                  ? const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: _TagModerationPanel(),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setApprovedTag(
      User user, String tagId, String label, bool selected) async {
    final firestore = FirebaseFirestore.instance;
    final userTag = firestore
        .collection('users')
        .doc(user.uid)
        .collection('profile_tags')
        .doc(tagId);
    final publicProfile =
        firestore.collection('public_seller_profiles').doc(user.uid);
    final batch = firestore.batch();
    if (selected) {
      batch.set(userTag, {
        'tagId': tagId,
        'label': label,
        'status': 'approved',
        'selectedAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.delete(userTag);
    }
    batch.set(
        publicProfile,
        {
          'ownerUid': user.uid,
          'displayName': user.displayName ?? '',
          'accountType': widget.accountType,
          'approvedTagIds': selected
              ? FieldValue.arrayUnion([tagId])
              : FieldValue.arrayRemove([tagId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    if (widget.accountType == 'business') {
      batch.set(
          firestore.collection('public_business_profiles').doc(user.uid),
          {
            'approvedTagIds': selected
                ? FieldValue.arrayUnion([tagId])
                : FieldValue.arrayRemove([tagId]),
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _requestTag(BuildContext context, User user) async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              icon: const Icon(
                Icons.add_business_outlined,
                color: PipeBuyerColors.orange,
              ),
              title: const Text('Suggest a marketplace specialty'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suggest an industrial product, service, rental, or transport specialty that buyers should be able to find.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: 'Specialty name',
                        hintText: 'e.g. Mobile pipe inspection',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                FilledButton.icon(
                    onPressed: () =>
                        Navigator.pop(dialogContext, controller.text.trim()),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Submit for approval')),
              ],
            ));
    controller.dispose();
    if (label == null || label.length < 2) return;
    final normalized = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final firestore = FirebaseFirestore.instance;
    final request = firestore.collection('tag_requests').doc();
    final batch = firestore.batch();
    batch.set(request, {
      'label': label,
      'normalizedLabel': normalized,
      'requestedByUid': user.uid,
      'requestedByEmail': user.email ?? '',
      'accountType': widget.accountType,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
        firestore
            .collection('users')
            .doc(user.uid)
            .collection('profile_tags')
            .doc('request_${request.id}'),
        {
          'requestId': request.id,
          'label': label,
          'status': 'pending',
          'isSearchable': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
    await batch.commit();
  }
}

class _SpecialtiesHeader extends StatelessWidget {
  const _SpecialtiesHeader({
    required this.accountType,
    required this.onSuggest,
  });

  final String accountType;
  final VoidCallback onSuggest;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final artwork = Container(
            width: compact ? 62 : 76,
            height: compact ? 62 : 76,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: PipeBuyerColors.ink,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IndustrialAssetIcon(
              label: accountType == 'business'
                  ? 'Industrial business specialties'
                  : 'Marketplace specialties',
              assetPath: accountType == 'business'
                  ? IndustrialIconAssets.industrialSite
                  : IndustrialIconAssets.pipeBundle,
              size: compact ? 52 : 66,
              borderRadius: 10,
              fallback: const Icon(
                Icons.precision_manufacturing_outlined,
                color: Colors.white,
                size: 34,
              ),
            ),
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MARKETPLACE DISCOVERY',
                style: TextStyle(
                  color: PipeBuyerColors.orangePressed,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                accountType == 'business'
                    ? 'Business specialties'
                    : 'Marketplace specialties',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose what you sell, rent, transport, or service. Approved specialties help buyers discover your profile.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .62),
                      height: 1.35,
                    ),
              ),
            ],
          );
          final action = OutlinedButton.icon(
            onPressed: onSuggest,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Suggest specialty'),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    artwork,
                    const SizedBox(width: 12),
                    Expanded(child: copy),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: action),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              artwork,
              const SizedBox(width: 13),
              Expanded(child: copy),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      );
}

class _SpecialtySummary extends StatelessWidget {
  const _SpecialtySummary({
    required this.approvedCount,
    required this.pendingCount,
  });

  final int approvedCount;
  final int pendingCount;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _SummaryPill(
            icon: Icons.verified_outlined,
            label: '$approvedCount selected',
            color: PipeBuyerColors.success,
          ),
          if (pendingCount > 0)
            _SummaryPill(
              icon: Icons.schedule_rounded,
              label: '$pendingCount pending',
              color: PipeBuyerColors.warning,
            ),
          const _SummaryPill(
            icon: Icons.search_rounded,
            label: 'Improves marketplace search',
            color: PipeBuyerColors.industrialBlue,
          ),
        ],
      );
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .075),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _CategoryChoice extends StatelessWidget {
  const _CategoryChoice({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final String category;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PipeBuyerColors.orange : Theme.of(context).dividerColor;
    return Material(
      color: selected ? PipeBuyerColors.orangeSoft : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 7, 11, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? PipeBuyerColors.orange.withValues(alpha: .10)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  _tagIcon(category),
                  size: 18,
                  color: selected
                      ? PipeBuyerColors.orangePressed
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .62),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                _categoryLabel(category),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: selected
                      ? PipeBuyerColors.orangePressed
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({
    required this.label,
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String category;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
        selected: selected,
        showCheckmark: true,
        selectedColor: PipeBuyerColors.orangeSoft,
        checkmarkColor: PipeBuyerColors.orangePressed,
        side: BorderSide(
          color: selected
              ? PipeBuyerColors.orange.withValues(alpha: .55)
              : Theme.of(context).dividerColor,
        ),
        avatar: Icon(
          _tagIcon(category),
          size: 17,
          color: selected
              ? PipeBuyerColors.orangePressed
              : Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: .58),
        ),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        onSelected: onSelected,
      );
}

class _TagLoadingState extends StatelessWidget {
  const _TagLoadingState();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: SizedBox.square(
            dimension: 30,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
}

class _TagMessageState extends StatelessWidget {
  const _TagMessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: PipeBuyerColors.orangePressed),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(message, style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      );
}

IconData _tagIcon(String category) => switch (category) {
      'sales' => Icons.storefront_outlined,
      'rental' => Icons.event_repeat_outlined,
      'service' => Icons.build_outlined,
      'transport' => Icons.local_shipping_outlined,
      'pipe' => Icons.horizontal_rule,
      'community' => Icons.groups_outlined,
      _ => Icons.sell_outlined,
    };

String _categoryLabel(String category) => switch (category) {
      'sales' => 'Sales & Dealers',
      'rental' => 'Rentals',
      'service' => 'Services & Repairs',
      'transport' => 'Transport',
      'pipe' => 'Pipe & OCTG',
      'community' => 'Community Added',
      _ => category,
    };

class _TagModerationPanel extends StatelessWidget {
  const _TagModerationPanel();

  @override
  Widget build(BuildContext context) => StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tag_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(defaultActivityFeedLimit)
          .snapshots(),
      builder: (context, snapshot) {
        final requests = snapshot.data?.docs ?? const [];
        return Container(
          decoration: BoxDecoration(
            color: PipeBuyerColors.industrialBlue.withValues(alpha: .045),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: PipeBuyerColors.industrialBlue.withValues(alpha: .16),
            ),
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Badge(
                isLabelVisible: requests.isNotEmpty,
                label: Text('${requests.length}'),
                child: const Icon(Icons.admin_panel_settings_outlined)),
            title: const Text('Administrator specialty approvals',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${requests.length} pending request(s)'),
            children: requests
                .map((request) => ListTile(
                      title: Text('${request.data()['label']}'),
                      subtitle: Text('${request.data()['requestedByEmail']}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            tooltip: 'Reject',
                            onPressed: () => _moderate(request, false),
                            icon: const Icon(Icons.close,
                                color: PipeBuyerColors.danger)),
                        IconButton(
                            tooltip: 'Approve',
                            onPressed: () => _moderate(request, true),
                            icon: const Icon(Icons.check,
                                color: PipeBuyerColors.success)),
                      ]),
                    ))
                .toList(),
          ),
        );
      });

  Future<void> _moderate(
      QueryDocumentSnapshot<Map<String, dynamic>> request, bool approve) async {
    final data = request.data();
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    final tagId = '${data['normalizedLabel']}';
    batch.update(request.reference, {
      'status': approve ? 'approved' : 'rejected',
      'reviewedByEmail': FirebaseAuth.instance.currentUser?.email,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    final pendingRef = firestore
        .collection('users')
        .doc('${data['requestedByUid']}')
        .collection('profile_tags')
        .doc('request_${request.id}');
    if (approve) {
      batch.set(firestore.collection('marketplace_tags').doc(tagId), {
        'label': data['label'],
        'normalizedLabel': data['normalizedLabel'],
        'category': 'community',
        'status': 'approved',
        'source': 'user_request',
        'approvedAt': FieldValue.serverTimestamp(),
      });
      batch.update(pendingRef, {
        'status': 'approved',
        'tagId': tagId,
        'isSearchable': true,
      });
      batch.set(
          firestore
              .collection('public_seller_profiles')
              .doc('${data['requestedByUid']}'),
          {
            'ownerUid': data['requestedByUid'],
            'accountType': data['accountType'],
            'approvedTagIds': FieldValue.arrayUnion([tagId]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      if (data['accountType'] == 'business') {
        batch.set(
            firestore
                .collection('public_business_profiles')
                .doc('${data['requestedByUid']}'),
            {
              'approvedTagIds': FieldValue.arrayUnion([tagId]),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }
    } else {
      batch.update(pendingRef, {'status': 'rejected', 'isSearchable': false});
    }
    await batch.commit();
  }
}
