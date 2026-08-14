import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/data/bounded_firestore_query.dart';
import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';

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
        appBar: AppBar(title: const Text('Seller storefront')),
        body: FutureBuilder<_PublicProfileData>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const MarketplaceDataStateView.loading(
                title: 'Loading seller storefront',
                message: 'Retrieving public details, specialties, and listings…',
              );
            }
            if (snapshot.hasError) {
              return MarketplaceDataStateView.failure(
                error: snapshot.error,
                resource: 'Seller storefront',
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
            final isBusiness = data.business.isNotEmpty;
            final loadedListings = _listings.length;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                  children: [
                    _StorefrontHero(
                      name: name.isEmpty ? 'Marketplace member' : name,
                      description: description,
                      photoUrl: photoUrl,
                      location: location,
                      isBusiness: isBusiness,
                      isOwnProfile: isOwnProfile,
                      listingCount: loadedListings,
                      hasMoreListings: _hasMoreListings,
                      specialtyCount: data.tags.length,
                      onAvatarTap: photoUrl.isEmpty
                          ? isOwnProfile
                              ? () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const MarketplaceProfilePage(),
                                    ),
                                  )
                              : null
                          : () => _showAvatar(context, photoUrl),
                      onEdit: isOwnProfile
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const MarketplaceProfilePage(),
                                ),
                              )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    PipeBuyerMetricGrid(
                      children: [
                        PipeBuyerMetricCard(
                          label: 'Active listings',
                          value:
                              '$loadedListings${_hasMoreListings ? '+' : ''}',
                          icon: Icons.inventory_2_outlined,
                          caption: 'Published inventory',
                          tone: PipeBuyerStatusTone.premium,
                        ),
                        PipeBuyerMetricCard(
                          label: 'Specialties',
                          value: '${data.tags.length}',
                          icon: Icons.workspace_premium_outlined,
                          caption: data.tags.isEmpty
                              ? 'No specialties published yet'
                              : 'Approved marketplace tags',
                          tone: PipeBuyerStatusTone.info,
                        ),
                        PipeBuyerMetricCard(
                          label: 'Account type',
                          value: isBusiness ? 'Business' : 'Personal',
                          icon: isBusiness
                              ? Icons.business_outlined
                              : Icons.person_outline,
                          caption: 'Public marketplace identity',
                          tone: PipeBuyerStatusTone.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 850;
                        final about = PipeBuyerSectionCard(
                          title: 'About this seller',
                          subtitle:
                              'Public information supplied for marketplace buyers.',
                          leading: const _SectionIcon(Icons.storefront_outlined),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                description.isEmpty
                                    ? 'No public description has been supplied.'
                                    : description,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(height: 1.55),
                              ),
                              if (location.isNotEmpty) ...[
                                const SizedBox(height: 18),
                                _DetailRow(
                                  icon: Icons.location_on_outlined,
                                  label: 'Service area',
                                  text: location,
                                ),
                              ],
                            ],
                          ),
                        );
                        final contact = PipeBuyerSectionCard(
                          title: 'Public contact',
                          subtitle:
                              'Contact details the seller has chosen to publish.',
                          leading:
                              const _SectionIcon(Icons.contact_phone_outlined),
                          child: Column(
                            children: [
                              if (publicPhone.isNotEmpty)
                                _DetailRow(
                                  icon: Icons.phone_outlined,
                                  label: 'Phone',
                                  text: formatPhoneNumber(publicPhone),
                                ),
                              if (publicPhone.isNotEmpty &&
                                  (publicEmail.isNotEmpty ||
                                      website.isNotEmpty))
                                const Divider(height: 24),
                              if (publicEmail.isNotEmpty)
                                _DetailRow(
                                  icon: Icons.email_outlined,
                                  label: 'Email',
                                  text: publicEmail,
                                ),
                              if (publicEmail.isNotEmpty && website.isNotEmpty)
                                const Divider(height: 24),
                              if (website.isNotEmpty)
                                _DetailRow(
                                  icon: Icons.language_outlined,
                                  label: 'Website',
                                  text: website,
                                ),
                              if (publicPhone.isEmpty &&
                                  publicEmail.isEmpty &&
                                  website.isEmpty)
                                const _PrivateContactNotice(),
                            ],
                          ),
                        );

                        if (!wide) {
                          return Column(
                            children: [
                              about,
                              const SizedBox(height: 12),
                              contact,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: about),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: contact),
                          ],
                        );
                      },
                    ),
                    if (data.tags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      PipeBuyerSectionCard(
                        title: 'Specialties & services',
                        subtitle:
                            'Approved marketplace categories associated with this storefront.',
                        leading: const _SectionIcon(
                            Icons.workspace_premium_outlined),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: data.tags
                              .map(
                                (tag) => PipeBuyerStatusBadge(
                                  label: tag,
                                  icon: Icons.check_circle_outline,
                                  tone: PipeBuyerStatusTone.info,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    PipeBuyerPageHeader(
                      eyebrow: 'Inventory',
                      title: 'Active listings',
                      subtitle:
                          'Browse equipment, pipe, property, and other inventory published by this seller.',
                      icon: Icons.inventory_2_outlined,
                      actions: [
                        PipeBuyerStatusBadge(
                          label:
                              '$loadedListings${_hasMoreListings ? '+' : ''} ACTIVE',
                          icon: Icons.storefront_outlined,
                          tone: PipeBuyerStatusTone.premium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_listings.isEmpty)
                      const MarketplaceDataStateView(
                        kind: MarketplaceDataStateKind.empty,
                        icon: Icons.inventory_2_outlined,
                        title: 'No active listings',
                        message:
                            'This seller does not currently have a published listing.',
                        compact: true,
                      )
                    else
                      _ListingsGrid(
                        documents: _listings,
                        sellerName: name,
                      ),
                    if (_listingLoadError != null) ...[
                      const SizedBox(height: 12),
                      MarketplaceDataStateView(
                        kind: MarketplaceDataStateKind.error,
                        title: 'More listings could not be loaded',
                        message:
                            'The storefront remains available. Try loading the next page again.',
                        primaryLabel: 'Retry',
                        primaryIcon: Icons.refresh,
                        onPrimary: _loadMoreListings,
                        compact: true,
                      ),
                    ],
                    if (_hasMoreListings) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.center,
                        child: OutlinedButton.icon(
                          onPressed:
                              _loadingMoreListings ? null : _loadMoreListings,
                          icon: _loadingMoreListings
                              ? const SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.expand_more_rounded),
                          label: const Text('Load more inventory'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );

  static Future<void> _showAvatar(BuildContext context, String photoUrl) async {
    final bytes = await MarketplaceAvatarImage.loadBytes(photoUrl);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: bytes == null
                    ? const Material(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Text('The profile photo could not be loaded.'),
                        ),
                      )
                    : Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            IconButton.filled(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorefrontHero extends StatelessWidget {
  const _StorefrontHero({
    required this.name,
    required this.description,
    required this.photoUrl,
    required this.location,
    required this.isBusiness,
    required this.isOwnProfile,
    required this.listingCount,
    required this.hasMoreListings,
    required this.specialtyCount,
    required this.onAvatarTap,
    required this.onEdit,
  });

  final String name;
  final String description;
  final String photoUrl;
  final String location;
  final bool isBusiness;
  final bool isOwnProfile;
  final int listingCount;
  final bool hasMoreListings;
  final int specialtyCount;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -52,
            top: -58,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PipeBuyerColors.orange.withValues(alpha: .08),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 5, color: PipeBuyerColors.orange),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final identity = Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onAvatarTap,
                      child: Container(
                        width: compact ? 86 : 104,
                        height: compact ? 86 : 104,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PipeBuyerColors.orange,
                            width: 2,
                          ),
                          color: Colors.white,
                        ),
                        child: ClipOval(
                          child: MarketplaceAvatarImage(
                            photoUrl: photoUrl,
                            size: compact ? 78 : 96,
                            fallback: ColoredBox(
                              color: PipeBuyerColors.orangeSoft,
                              child: Center(
                                child: Text(
                                  name.isEmpty ? '?' : name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: PipeBuyerColors.ink,
                                    fontSize: compact ? 28 : 34,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              PipeBuyerStatusBadge(
                                label: isBusiness
                                    ? 'BUSINESS STOREFRONT'
                                    : 'SELLER PROFILE',
                                icon: isBusiness
                                    ? Icons.business_outlined
                                    : Icons.person_outline,
                                tone: PipeBuyerStatusTone.premium,
                              ),
                              if (specialtyCount > 0)
                                PipeBuyerStatusBadge(
                                  label: '$specialtyCount SPECIALTIES',
                                  icon: Icons.workspace_premium_outlined,
                                  tone: PipeBuyerStatusTone.info,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    location,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );

                final actions = Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$listingCount${hasMoreListings ? '+' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'ACTIVE LISTINGS',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .9,
                      ),
                    ),
                    if (isOwnProfile && onEdit != null) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit storefront'),
                      ),
                    ],
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 10),
                      actions,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 22),
                    actions,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingsGrid extends StatelessWidget {
  const _ListingsGrid({required this.documents, required this.sellerName});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents;
  final String sellerName;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 680
                ? 2
                : 1;
        const gap = 12.0;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: documents
              .map(
                (document) => SizedBox(
                  width: width,
                  child: _ListingCard(
                    document: document,
                    sellerName: sellerName,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
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
    final category = '${listing['category'] ?? ''}'.trim();
    final transactionType = '${listing['transactionType'] ?? 'Marketplace'}';
    final isAuction = transactionType == 'Auction';
    final location = '${listing['publicLocationName'] ?? ''}'.trim();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: thumbnail == null
                ? Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 44,
                      color: PipeBuyerColors.slate,
                    ),
                  )
                : Image.network(
                    thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.inventory_2_outlined, size: 44),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    PipeBuyerStatusBadge(
                      label: isAuction ? 'AUCTION' : 'MARKETPLACE',
                      icon: isAuction
                          ? Icons.gavel_outlined
                          : Icons.storefront_outlined,
                      tone: isAuction
                          ? PipeBuyerStatusTone.warning
                          : PipeBuyerStatusTone.info,
                    ),
                    if (category.isNotEmpty)
                      PipeBuyerStatusBadge(
                        label: category.toUpperCase(),
                        tone: PipeBuyerStatusTone.neutral,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 7),
                if (price != null)
                  Text(
                    marketplaceMoney(price),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: PipeBuyerColors.orangePressed,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 17,
                        color: PipeBuyerColors.slate,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context
                            .push(MarketplaceDeepLinks.listing(document.id)),
                        icon: const Icon(Icons.open_in_new_outlined),
                        label: const Text('View'),
                      ),
                    ),
                    if (FirebaseAuth.instance.currentUser?.uid !=
                        '${listing['sellerUid']}') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _message(context, listing, title),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Message'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _message(
      BuildContext context, Map<String, dynamic> listing, String title) async {
    try {
      final id = await MarketplaceActionsRepository().ensureConversation(
        listingId: document.id,
        listingTitle: title,
        sellerUid: '${listing['sellerUid']}',
        sellerName: sellerName,
      );
      if (!context.mounted) return;
      await context.push(MarketplaceDeepLinks.conversation(id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The conversation could not be opened.'),
          ),
        );
      }
    }
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: PipeBuyerColors.orangeSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: PipeBuyerColors.orange),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PipeBuyerColors.orangeSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: PipeBuyerColors.orangePressed, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .52),
                        fontWeight: FontWeight.w800,
                        letterSpacing: .6,
                      ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _PrivateContactNotice extends StatelessWidget {
  const _PrivateContactNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: PipeBuyerColors.slate),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This seller keeps direct contact information private. Open one of their listings and use Pipe Buyer messaging to contact them.',
              ),
            ),
          ],
        ),
      );
}

class _PublicProfileData {
  const _PublicProfileData({
    required this.business,
    required this.personal,
    required this.listings,
    required this.tags,
  });

  final Map<String, dynamic> business;
  final Map<String, dynamic> personal;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> listings;
  final List<String> tags;
}
