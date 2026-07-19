import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'marketplace_actions_repository.dart';
import 'marketplace_messages_page.dart';
import 'marketplace_money.dart';
import 'marketplace_avatar_image.dart';
import 'regional_phone_field.dart';
import 'marketplace_profile_page.dart';
import 'marketplace_listing_media.dart';

class MarketplacePublicProfilePage extends StatelessWidget {
  const MarketplacePublicProfilePage({
    super.key,
    required this.userUid,
    this.fallbackName = 'Marketplace member',
  });

  final String userUid;
  final String fallbackName;

  Future<_PublicProfileData> _load() async {
    final firestore = FirebaseFirestore.instance;
    final results = await Future.wait([
      firestore.collection('public_business_profiles').doc(userUid).get(),
      firestore.collection('public_seller_profiles').doc(userUid).get(),
      firestore
          .collection('public_listings')
          .where('sellerUid', isEqualTo: userUid)
          .get(),
    ]);
    final business =
        (results[0] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};
    final personal =
        (results[1] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};
    final listings =
        (results[2] as QuerySnapshot<Map<String, dynamic>>).docs.where((doc) {
      final status = '${doc.data()['status'] ?? 'active'}';
      return status == 'active' || status == 'published';
    }).toList()
          ..sort((a, b) {
            final at = a.data()['createdAt'] as Timestamp?;
            final bt = b.data()['createdAt'] as Timestamp?;
            return (bt?.millisecondsSinceEpoch ?? 0)
                .compareTo(at?.millisecondsSinceEpoch ?? 0);
          });
    final tagIds = <String>{
      ...List<String>.from(business['approvedTagIds'] ?? const <String>[]),
      ...List<String>.from(personal['approvedTagIds'] ?? const <String>[]),
    };
    final tagDocuments = await Future.wait(tagIds
        .take(30)
        .map((id) => firestore.collection('marketplace_tags').doc(id).get()));
    final tags = tagDocuments
        .where((doc) => doc.exists && doc.data()?['status'] == 'approved')
        .map((doc) => '${doc.data()?['label'] ?? ''}'.trim())
        .where((label) => label.isNotEmpty)
        .toList()
      ..sort();
    return _PublicProfileData(
        business: business, personal: personal, listings: listings, tags: tags);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Member profile')),
      body: FutureBuilder<_PublicProfileData>(
          future: _load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                  child: Text('This profile could not be loaded.'));
            }
            final data = snapshot.data!;
            final profile =
                data.business.isNotEmpty ? data.business : data.personal;
            final name =
                '${data.business['publicName'] ?? data.personal['displayName'] ?? fallbackName}'
                    .trim();
            final description =
                '${profile['description'] ?? 'Marketplace member'}'.trim();
            final location =
                '${data.business['serviceAreaLabel'] ?? data.personal['baseCommunity'] ?? ''}'
                    .trim();
            final website = '${data.business['website'] ?? ''}'.trim();
            final rawPhotoUrl =
                '${profile['photoUrl'] ?? profile['avatarUrl'] ?? ''}'.trim();
            final photoUrl = rawPhotoUrl.startsWith('https://') ||
                    rawPhotoUrl.startsWith('http://')
                ? rawPhotoUrl
                : '';
            final publicPhone = '${data.business['publicPhone'] ?? ''}'.trim();
            final publicEmail = '${data.business['publicEmail'] ?? ''}'.trim();
            final isOwnProfile =
                FirebaseAuth.instance.currentUser?.uid == userUid;
            return ListView(padding: const EdgeInsets.all(18), children: [
              Center(
                  child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: photoUrl.isEmpty
                          ? isOwnProfile
                              ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const MarketplaceProfilePage()))
                              : null
                          : () => _showAvatar(context, photoUrl),
                      child: CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFFE5F2FF),
                          child: MarketplaceAvatarImage(
                              photoUrl: photoUrl,
                              size: 96,
                              fallback: Center(
                                  child: Text(
                                      name.isEmpty
                                          ? '?'
                                          : name[0].toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900))))))),
              if (isOwnProfile) ...[
                const SizedBox(height: 10),
                Center(
                    child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const MarketplaceProfilePage())),
                        icon: Icon(photoUrl.isEmpty
                            ? Icons.add_a_photo_outlined
                            : Icons.edit_outlined),
                        label: Text(photoUrl.isEmpty
                            ? 'Add profile photo'
                            : 'Change profile photo')))
              ],
              const SizedBox(height: 12),
              Text(name.isEmpty ? 'Marketplace member' : name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900)),
              Text(data.business.isNotEmpty
                  ? 'Business marketplace account'
                  : 'Marketplace member'),
              const SizedBox(height: 10),
              Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (data.business.isNotEmpty)
                      const Chip(
                          avatar: Icon(Icons.business_outlined, size: 17),
                          label: Text('Business')),
                    Chip(
                        avatar:
                            const Icon(Icons.inventory_2_outlined, size: 17),
                        label: Text(
                            '${data.listings.length} active ${data.listings.length == 1 ? 'listing' : 'listings'}'))
                  ]),
              const SizedBox(height: 18),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(description,
                                style: const TextStyle(fontSize: 16)),
                            if (location.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _DetailRow(
                                  icon: Icons.location_on_outlined,
                                  text: location),
                            ],
                            if (website.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _DetailRow(icon: Icons.language, text: website),
                            ],
                            if (publicPhone.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _DetailRow(
                                  icon: Icons.phone_outlined,
                                  text: formatPhoneNumber(publicPhone)),
                            ],
                            if (publicEmail.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _DetailRow(
                                  icon: Icons.email_outlined,
                                  text: publicEmail),
                            ],
                          ]))),
              if (data.tags.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text('Specialties & services',
                    style:
                        TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: data.tags
                        .map((tag) => Chip(
                            avatar:
                                const Icon(Icons.verified_outlined, size: 17),
                            label: Text(tag)))
                        .toList()),
              ],
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(
                    child: Text('Active listings',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w900))),
                Chip(label: Text('${data.listings.length}'))
              ]),
              if (data.listings.isEmpty)
                const Card(
                    child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('This member has no active listings.')))
              else
                ...data.listings.map(
                    (doc) => _ListingCard(document: doc, sellerName: name)),
            ]);
          }));

  static Future<void> _showAvatar(BuildContext context, String photoUrl) async {
    final bytes = await MarketplaceAvatarImage.loadBytes(photoUrl);
    if (!context.mounted) return;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(alignment: Alignment.topRight, children: [
              InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: bytes == null
                          ? const Material(
                              child: Padding(
                                  padding: EdgeInsets.all(28),
                                  child: Text(
                                      'The profile photo could not be loaded.')))
                          : Image.memory(bytes, fit: BoxFit.contain))),
              IconButton.filled(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close))
            ])));
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.document, required this.sellerName});
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final String sellerName;

  @override
  Widget build(BuildContext context) {
    final listing = document.data();
    final thumbnail = marketplaceListingThumbnailUrl(listing);
    final title = '${listing['title'] ?? 'Marketplace listing'}';
    final price = (listing['price'] as num?)?.toDouble();
    return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (thumbnail != null)
            SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.network(thumbnail, fit: BoxFit.cover)),
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Row(children: [
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900))),
                if (price != null)
                  Text(marketplaceMoney(price),
                      style: const TextStyle(fontWeight: FontWeight.w900))
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                      onPressed: FirebaseAuth.instance.currentUser?.uid ==
                              '${listing['sellerUid']}'
                          ? null
                          : () => _message(context, listing, title),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Message about this listing'))))
        ]));
  }

  Future<void> _message(
      BuildContext context, Map<String, dynamic> listing, String title) async {
    try {
      final id = await MarketplaceActionsRepository().ensureConversation(
          listingId: document.id,
          listingTitle: title,
          sellerUid: '${listing['sellerUid']}',
          sellerName: sellerName);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              MarketplaceChatPage(conversationId: id, title: title)));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('The conversation could not be opened.')));
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: const Color(0xFF0878E8)),
        const SizedBox(width: 12),
        Expanded(child: Text(text))
      ]);
}

class _PublicProfileData {
  const _PublicProfileData(
      {required this.business,
      required this.personal,
      required this.listings,
      required this.tags});
  final Map<String, dynamic> business;
  final Map<String, dynamic> personal;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> listings;
  final List<String> tags;
}
