import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/data/bounded_firestore_query.dart';

import 'marketplace_actions_repository.dart';
import 'marketplace_money.dart';
import 'marketplace_avatar_image.dart';
import 'regional_phone_field.dart';
import 'marketplace_profile_page.dart';
import 'marketplace_listing_media.dart';
import 'marketplace_deep_links.dart';
import 'marketplace_data_state.dart';

class MarketplacePublicProfilePage extends StatefulWidget {
  const MarketplacePublicProfilePage({
    super.key,
    required this.userUid,
    this.fallbackName = 'Marketplace member',
  });

  final String userUid;
  final String fallbackName;

  @override
  State<MarketplacePublicProfilePage> createState() =>
      _MarketplacePublicProfilePageState();
}

class _MarketplacePublicProfilePageState
    extends State<MarketplacePublicProfilePage> {
  late Future<_PublicProfileData> _profile;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _listings = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _listingCursor;
  bool _hasMoreListings = false;
  bool _loadingMoreListings = false;
  String? _listingLoadError;

  @override
  void initState() {
    super.initState();
    _profile = _load();
  }

  Query<Map<String, dynamic>> _listingQuery() => FirebaseFirestore.instance
      .collection('public_listings')
      .where('sellerUid', isEqualTo: widget.userUid)
      .where('status', whereIn: const ['active', 'published']).orderBy(
          'createdAt',
          descending: true);

  Future<_PublicProfileData> _load() async {
    final firestore = FirebaseFirestore.instance;
    final results = await Future.wait([
      firestore
          .collection('public_business_profiles')
          .doc(widget.userUid)
          .get(),
      firestore.collection('public_seller_profiles').doc(widget.userUid).get(),
      loadFirestoreDocumentPage(_listingQuery()),
    ]);
    final business =
        (results[0] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};
    final personal =
        (results[1] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};
    final listingPage = results[2] as FirestoreDocumentPage;
    _listings
      ..clear()
      ..addAll(listingPage.documents);
    _listingCursor = listingPage.cursor;
    _hasMoreListings = listingPage.hasMore;
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
        business: business,
        personal: personal,
        listings: _listings,
        tags: tags);
  }

  Future<void> _loadMoreListings() async {
    if (_loadingMoreListings || !_hasMoreListings) return;
    setState(() {
      _loadingMoreListings = true;
      _listingLoadError = null;
    });
    try {
      final page = await loadFirestoreDocumentPage(
        _listingQuery(),
        after: _listingCursor,
      );
      if (!mounted) return;
      final merged = appendUniqueById(
          _listings, page.documents, (document) => document.id);
      setState(() {
        _listings
          ..clear()
          ..addAll(merged);
        _listingCursor = page.cursor;
        _hasMoreListings = page.hasMore;
      });
    } catch (error) {
      if (mounted) setState(() => _listingLoadError = '$error');
    } finally {
      if (mounted) setState(() => _loadingMoreListings = false);
    }
  }

  void _retryProfile() {
    setState(() {
      _listingLoadError = null;
      _profile = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Member profile')),
      body: FutureBuilder<_PublicProfileData>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const MarketplaceDataStateView.loading(
                title: 'Loading member profile',
                message: 'Retrieving public details, tags, and listings…',
              );
            }
            if (snapshot.hasError) {
              return MarketplaceDataStateView.failure(
                error: snapshot.error,
                resource: 'Member profile',
                onRetry: _retryProfile,
              );
            }
            final data = snapshot.data!;
            final profile =
                data.business.isNotEmpty ? data.business : data.personal;
            final name =
                '${data.business['publicName'] ?? data.personal['displayName'] ?? widget.fallbackName}'
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
                FirebaseAuth.instance.currentUser?.uid == widget.userUid;
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
                            '${data.listings.length}${_hasMoreListings ? '+' : ''} active ${data.listings.length == 1 ? 'listing' : 'listings'}'))
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
                Chip(
                    label: Text(
                        '${data.listings.length}${_hasMoreListings ? '+' : ''} loaded'))
              ]),
              if (_listings.isEmpty)
                const MarketplaceDataStateView(
                  kind: MarketplaceDataStateKind.empty,
                  icon: Icons.inventory_2_outlined,
                  title: 'No active listings',
                  message:
                      'This member does not currently have a published listing.',
                  compact: true,
                )
              else
                ..._listings.map(
                    (doc) => _ListingCard(document: doc, sellerName: name)),
              if (_listingLoadError != null)
                MarketplaceDataStateView(
                  kind: MarketplaceDataStateKind.error,
                  title: 'More listings could not be loaded',
                  message:
                      'The profile remains available. Try loading the next page again.',
                  primaryLabel: 'Retry',
                  primaryIcon: Icons.refresh,
                  onPrimary: _loadMoreListings,
                  compact: true,
                ),
              if (_hasMoreListings)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                            onPressed:
                                _loadingMoreListings ? null : _loadMoreListings,
                            icon: _loadingMoreListings
                                ? const SizedBox.square(
                                    dimension: 17,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.expand_more_rounded),
                            label: const Text('Load more listings')))),
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
              child: Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () => context
                            .push(MarketplaceDeepLinks.listing(document.id)),
                        icon: const Icon(Icons.open_in_new_outlined),
                        label: const Text('View listing'))),
                if (FirebaseAuth.instance.currentUser?.uid !=
                    '${listing['sellerUid']}') ...[
                  const SizedBox(width: 8),
                  Expanded(
                      child: FilledButton.tonalIcon(
                          onPressed: () => _message(context, listing, title),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Message'))),
                ]
              ]))
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
      await context.push(MarketplaceDeepLinks.conversation(id));
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
