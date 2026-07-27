import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/data/bounded_firestore_query.dart';
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Row(children: [
        const Expanded(
            child: Text('Business & marketplace tags',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
        TextButton.icon(
            onPressed: () => _requestTag(context, user),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Suggest tag')),
      ]),
      const Text(
          'Choose what you sell or provide. Approved tags help buyers find your profile.'),
      const SizedBox(height: 10),
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
                final selected = {
                  for (final doc in selectedSnapshot.data?.docs ?? const [])
                    doc.id: doc.data()
                };
                final catalog = [...?catalogSnapshot.data?.docs]..sort((a, b) =>
                    '${a.data()['label']}'.compareTo('${b.data()['label']}'));
                final categories = catalog
                    .map((doc) => '${doc.data()['category']}')
                    .toSet()
                    .toList()
                  ..sort();
                if (categories.isNotEmpty && !categories.contains(_category)) {
                  _category = categories.first;
                }
                final visible = catalog
                    .where((doc) => doc.data()['category'] == _category)
                    .toList();
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. Choose a category',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: categories
                              .map((category) => ChoiceChip(
                                  selected: _category == category,
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(_tagIcon(category), size: 16),
                                  label: Text(_categoryLabel(category),
                                      style: const TextStyle(fontSize: 12)),
                                  onSelected: (_) =>
                                      setState(() => _category = category)))
                              .toList()),
                      const SizedBox(height: 9),
                      Text('2. Select ${_categoryLabel(_category)} tags',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: visible.map((doc) {
                            final data = doc.data();
                            final active = selected.containsKey(doc.id);
                            return FilterChip(
                                selected: active,
                                avatar: Icon(_tagIcon('${data['category']}'),
                                    size: 17),
                                label: Text('${data['label']}'),
                                onSelected: (value) => _setApprovedTag(
                                    user, doc.id, '${data['label']}', value));
                          }).toList()),
                      ...selected.entries
                          .where((entry) => entry.value['status'] == 'pending')
                          .map((entry) => Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Chip(
                                  avatar: const Icon(Icons.schedule,
                                      color: Color(0xFFE56F00), size: 18),
                                  label: Text(
                                      '${entry.value['label']} • Awaiting admin approval'),
                                  backgroundColor: const Color(0xFFFFF4E5))))
                    ]);
              })),
      FutureBuilder<bool>(
          future: marketplaceAdministratorAccess(),
          builder: (context, access) => access.data == true
              ? const _TagModerationPanel()
              : const SizedBox.shrink()),
      const SizedBox(height: 12),
    ]);
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
              title: const Text('Suggest a marketplace tag'),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 50,
                  decoration: const InputDecoration(
                      labelText: 'Tag name',
                      hintText: 'e.g. Mobile pipe inspection')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(dialogContext, controller.text.trim()),
                    child: const Text('Submit for approval')),
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

  IconData _tagIcon(String category) => switch (category) {
        'sales' => Icons.storefront_outlined,
        'rental' => Icons.event_repeat_outlined,
        'service' => Icons.build_outlined,
        'transport' => Icons.local_shipping_outlined,
        'pipe' => Icons.horizontal_rule,
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
}

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
        return ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: Badge(
                isLabelVisible: requests.isNotEmpty,
                label: Text('${requests.length}'),
                child: const Icon(Icons.admin_panel_settings_outlined)),
            title: const Text('Developer tag approvals',
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
                            icon: const Icon(Icons.close, color: Colors.red)),
                        IconButton(
                            tooltip: 'Approve',
                            onPressed: () => _moderate(request, true),
                            icon: const Icon(Icons.check, color: Colors.green)),
                      ]),
                    ))
                .toList());
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
