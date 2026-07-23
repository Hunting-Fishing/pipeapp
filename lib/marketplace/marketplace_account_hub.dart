import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'marketplace_messages_page.dart';
import 'marketplace_account_security_page.dart';
import 'marketplace_auction_repository.dart';
import 'marketplace_profile_page.dart';
import 'marketplace_reporting.dart';
import 'marketplace_navigation.dart';
import 'marketplace_listing_media.dart';
import 'marketplace_money.dart';
import 'marketplace_property_details.dart';
import 'marketplace_command_client.dart';

class MarketplaceAccountHub extends StatefulWidget {
  const MarketplaceAccountHub(
      {super.key,
      required this.onAddListing,
      required this.onBrowse,
      required this.auctionsEnabled,
      required this.paidFeaturesEnabled});

  final VoidCallback onAddListing;
  final VoidCallback onBrowse;
  final bool auctionsEnabled;
  final bool paidFeaturesEnabled;

  @override
  State<MarketplaceAccountHub> createState() => _MarketplaceAccountHubState();
}

class _MarketplaceAccountHubState extends State<MarketplaceAccountHub>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: const [
              Tab(
                  icon: Icon(Icons.dashboard_outlined, size: 20),
                  text: 'Overview'),
              Tab(icon: Icon(Icons.badge_outlined, size: 20), text: 'Profile'),
              Tab(
                  icon: _AccountTabBadge(
                      types: {'offer'}, icon: Icons.inventory_2_outlined),
                  text: 'Listings'),
              Tab(
                  icon: _AccountTabBadge(
                      types: {'message'}, icon: Icons.forum_outlined),
                  text: 'Messages'),
              Tab(
                  icon: _AccountTabBadge(
                      types: {}, icon: Icons.notifications_outlined),
                  text: 'Notifications'),
              Tab(
                  icon: Icon(Icons.settings_outlined, size: 20),
                  text: 'Settings'),
            ],
          ),
        ),
        Expanded(
            child: TabBarView(controller: _tabs, children: [
          _Overview(onOpen: _tabs.animateTo),
          const MarketplaceProfilePage(),
          _MyListings(
              onAddListing: widget.onAddListing,
              auctionsEnabled: widget.auctionsEnabled,
              paidFeaturesEnabled: widget.paidFeaturesEnabled),
          const MarketplaceMessagesPage(),
          _AccountNotifications(
              onOpenTab: _tabs.animateTo, onBrowse: widget.onBrowse),
          const _AccountSettings(),
        ]))
      ]);
}

class _Overview extends StatelessWidget {
  const _Overview({required this.onOpen});
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in to view account.'));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final completion =
              ((data['profileCompletion'] as num?)?.toInt() ?? 0).clamp(0, 100);
          final userScore =
              ((data['userScore'] as num?)?.toInt() ?? 70).clamp(0, 100);
          final isAdmin = data['isAdmin'] == true ||
              data['admin'] == true ||
              (user.email ?? '').toLowerCase() == 'jordilwbailey@gmail.com';
          return ListView(padding: const EdgeInsets.all(18), children: [
            Text('Hello, ${user.displayName ?? user.email ?? 'seller'}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            Text('${data['accountType'] ?? 'personal'} account'),
            const SizedBox(height: 18),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      Row(children: [
                        const Text('Profile completion',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text('$completion%')
                      ]),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: completion / 100),
                    ]))),
            Card(
                child: ListTile(
              onTap: () => _showUserScore(context, onOpen),
              leading: CircleAvatar(child: Text('$userScore')),
              title: const Text('User Score',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(userScore > 80
                  ? 'Strong marketplace standing'
                  : userScore > 50
                      ? 'Standard marketplace standing'
                      : 'Auction buying is restricted'),
              trailing: data['accountVerified'] == true
                  ? const Icon(Icons.verified, color: Colors.green)
                  : const Chip(label: Text('Not verified')),
            )),
            const SizedBox(height: 12),
            _AccountShortcut(
                icon: Icons.badge_outlined,
                title: 'Edit profile, tags and service areas',
                onTap: () => onOpen(1)),
            _AccountShortcut(
                icon: Icons.inventory_2_outlined,
                title: 'Manage my listings',
                onTap: () => onOpen(2)),
            _AccountShortcut(
                icon: Icons.forum_outlined,
                title: 'Marketplace messages',
                onTap: () => onOpen(3)),
            _AccountShortcut(
                icon: Icons.notifications_outlined,
                title: 'Notifications and activity',
                onTap: () => onOpen(4)),
            _AccountShortcut(
                icon: Icons.settings_outlined,
                title: 'Account settings',
                onTap: () => onOpen(5)),
            if (isAdmin)
              _AccountShortcut(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Trust & Safety admin dashboard',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => Scaffold(
                            appBar:
                                AppBar(title: const Text('Admin moderation')),
                            body: const AdminModerationDashboard(),
                          )))),
          ]);
        });
  }
}

Future<void> _showUserScore(
    BuildContext context, ValueChanged<int> onOpenTab) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  final user =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final results = await Future.wait([
    FirebaseFirestore.instance
        .collection('user_score_events')
        .where('userUid', isEqualTo: uid)
        .get(),
    FirebaseFirestore.instance
        .collection('public_business_profiles')
        .doc(uid)
        .get(),
    FirebaseFirestore.instance
        .collection('public_seller_profiles')
        .doc(uid)
        .get(),
    FirebaseFirestore.instance
        .collection('verification_requests')
        .doc(uid)
        .get()
  ]);
  if (!context.mounted) return;
  final data = user.data() ?? const <String, dynamic>{};
  final business =
      (results[1] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};
  final seller =
      (results[2] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};
  final verification =
      (results[3] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};
  final score = (data['userScore'] as num?)?.toInt() ?? 70;
  final history =
      (results[0] as QuerySnapshot<Map<String, dynamic>>).docs.toList()
        ..sort((a, b) {
          final at = a.data()['createdAt'] as Timestamp?;
          final bt = b.data()['createdAt'] as Timestamp?;
          return (bt?.millisecondsSinceEpoch ?? 0)
              .compareTo(at?.millisecondsSinceEpoch ?? 0);
        });
  final accountType = '${data['accountType'] ?? 'personal'}';
  final checks = <(String, bool, String)>[
    (
      'Profile details',
      (data['profileCompletion'] as num? ?? 0) >= 100,
      'Complete every required field in Profile.'
    ),
    (
      'Profile photo',
      '${seller['photoUrl'] ?? ''}'.startsWith('http'),
      'Add a clear profile or business photo.'
    ),
    (
      'Marketplace specialties',
      List<String>.from(seller['approvedTagIds'] ?? const <String>[])
          .isNotEmpty,
      'Select at least one approved marketplace tag.'
    ),
    if (accountType == 'business') ...[
      (
        'Public business identity',
        '${business['publicName'] ?? ''}'.trim().isNotEmpty &&
            '${business['description'] ?? ''}'.trim().isNotEmpty,
        'Add your public business name and description.'
      ),
      (
        'Business contact',
        '${business['publicPhone'] ?? ''}'.trim().isNotEmpty &&
            '${business['publicEmail'] ?? ''}'.trim().isNotEmpty,
        'Add a public business phone and email.'
      ),
      (
        'Service area',
        '${business['serviceAreaLabel'] ?? ''}'.trim().isNotEmpty,
        'Select the area where your business operates.'
      ),
    ],
  ];
  final readyForReview = checks.every((item) => item.$2);
  final verificationStatus = '${verification['status'] ?? 'not_requested'}';
  showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
              child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(children: [
                    Row(children: [
                      CircleAvatar(radius: 28, child: Text('$score')),
                      const SizedBox(width: 12),
                      const Expanded(
                          child: Text('User Score history',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w900))),
                      IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close))
                    ]),
                    if (data['accountVerified'] != true)
                      Card(
                          color: const Color(0xFFFFF4E5),
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 360),
                              child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(
                                              Icons.verified_user_outlined),
                                          title: Text(
                                              'Verification needs attention'),
                                          subtitle: Text(
                                              'Complete the checklist below. Verification is reviewed separately from your User Score.'),
                                        ),
                                        ...checks.map((item) => ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                                item.$2
                                                    ? Icons.check_circle
                                                    : Icons.error_outline,
                                                color: item.$2
                                                    ? Colors.green
                                                    : Colors.deepOrange),
                                            title: Text(item.$1,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            subtitle: item.$2
                                                ? null
                                                : Text(item.$3))),
                                        if (verificationStatus == 'pending')
                                          const Chip(
                                              avatar: Icon(Icons.schedule,
                                                  size: 17),
                                              label: Text(
                                                  'Verification review pending'))
                                        else
                                          SizedBox(
                                              width: double.infinity,
                                              child: FilledButton.icon(
                                                  onPressed: readyForReview
                                                      ? () async {
                                                          await _requestVerification(
                                                              uid, accountType);
                                                          if (dialogContext
                                                              .mounted) {
                                                            Navigator.pop(
                                                                dialogContext);
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                                    const SnackBar(
                                                                        content:
                                                                            Text('Verification submitted for review.')));
                                                          }
                                                        }
                                                      : () {
                                                          Navigator.pop(
                                                              dialogContext);
                                                          onOpenTab(1);
                                                        },
                                                  icon: Icon(readyForReview
                                                      ? Icons.send_outlined
                                                      : Icons.edit_outlined),
                                                  label: Text(readyForReview
                                                      ? 'Submit verification for review'
                                                      : 'Complete missing profile items')))
                                      ])))),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            'Only reviewed decisions change your score. Pending reports do not.')),
                    const SizedBox(height: 12),
                    Expanded(
                        child: history.isEmpty
                            ? const Center(
                                child: Text('No score movements yet.'))
                            : ListView.builder(
                                itemCount: history.length,
                                itemBuilder: (_, index) {
                                  final event = history[index].data();
                                  final change =
                                      (event['change'] as num?)?.toInt() ?? 0;
                                  return ListTile(
                                    leading: CircleAvatar(
                                        backgroundColor: change >= 0
                                            ? Colors.green.shade50
                                            : Colors.red.shade50,
                                        child: Text(
                                            '${change >= 0 ? '+' : ''}$change')),
                                    title: Text(
                                        '${event['reason'] ?? 'Score adjustment'}'),
                                    subtitle: Text(
                                        '${event['createdAt'] is Timestamp ? (event['createdAt'] as Timestamp).toDate().toLocal() : ''}'),
                                    trailing:
                                        Text('${event['scoreAfter'] ?? ''}'),
                                  );
                                }))
                  ])))));
}

Future<void> _requestVerification(String uid, String accountType) =>
    FirebaseFirestore.instance
        .collection('verification_requests')
        .doc(uid)
        .set({
      'userUid': uid,
      'accountType': accountType,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

class _AccountShortcut extends StatelessWidget {
  const _AccountShortcut(
      {required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap));
}

class _MyListings extends StatelessWidget {
  const _MyListings(
      {required this.onAddListing,
      required this.auctionsEnabled,
      required this.paidFeaturesEnabled});

  final VoidCallback onAddListing;
  final bool auctionsEnabled;
  final bool paidFeaturesEnabled;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in to view listings.'));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('public_listings')
            .where('sellerUid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.sync_problem_outlined,
                          size: 48, color: Colors.deepOrange),
                      const SizedBox(height: 10),
                      const Text('Could not load your listings.',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54)),
                    ])));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final listings = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              return (bTime?.millisecondsSinceEpoch ?? 0)
                  .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
            });
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(children: [
                const Expanded(
                    child: Text('My listings',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900))),
                FilledButton.icon(
                    onPressed: onAddListing,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Listing')),
              ]),
            ),
            Expanded(
              child: listings.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 44, color: Colors.black38),
                        const SizedBox(height: 10),
                        const Text('You have not published a listing yet.'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                            onPressed: onAddListing,
                            icon: const Icon(Icons.add),
                            label: const Text('Add your first listing')),
                      ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: listings.length,
                      itemBuilder: (_, index) {
                        final document = listings[index];
                        final data = document.data();
                        final thumbnail = marketplaceListingThumbnailUrl(data);
                        final createdAt =
                            (data['createdAt'] as Timestamp?)?.toDate();
                        final isAuction = data['transactionType'] == 'Auction';
                        return Card(
                            child: ListTile(
                          onTap: () async {
                            await _markListingNotificationsRead(document.id);
                            if (!context.mounted) return;
                            showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => _OwnerListingDetails(
                                    listingId: document.id,
                                    data: data,
                                    auctionsEnabled: auctionsEnabled,
                                    paidFeaturesEnabled: paidFeaturesEnabled));
                          },
                          leading: SizedBox.square(
                              dimension: 54,
                              child: Stack(fit: StackFit.expand, children: [
                                thumbnail == null
                                    ? const Icon(Icons.inventory_2_outlined)
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(thumbnail,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons
                                                    .inventory_2_outlined))),
                                Positioned(
                                    right: 1,
                                    bottom: 1,
                                    child: CircleAvatar(
                                        radius: 11,
                                        backgroundColor: isAuction
                                            ? Colors.deepOrange
                                            : const Color(0xFF0878E8),
                                        child: Icon(
                                            isAuction
                                                ? Icons.gavel
                                                : Icons.storefront,
                                            size: 13,
                                            color: Colors.white)))
                              ])),
                          title: Text('${data['title'] ?? 'Untitled listing'}'),
                          subtitle: Text(
                              '${isAuction ? 'TIMED AUCTION' : 'MARKETPLACE'} • ${data['category'] ?? ''} • ${data['status'] ?? 'active'}\n'
                              '${_ownerListingTime(data, createdAt)}\n${_analyticsLine(data)}'),
                          isThreeLine: createdAt != null,
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            _ListingNotificationBadge(listingId: document.id),
                            const Icon(Icons.chevron_right),
                          ]),
                        ));
                      }),
            ),
          ]);
        });
  }
}

String _analyticsLine(Map<String, dynamic> data) =>
    '${(data['viewCount'] as num?)?.toInt() ?? 0} views • '
    '${(data['saveCount'] as num?)?.toInt() ?? 0} saves • '
    '${(data['shareCount'] as num?)?.toInt() ?? 0} shares • '
    '${(data['likeCount'] as num?)?.toInt() ?? 0} likes • '
    '${(data['offerCount'] as num?)?.toInt() ?? 0} offers';

String _ownerListingTime(Map<String, dynamic> data, DateTime? createdAt) {
  if (data['transactionType'] == 'Auction') {
    final end = (data['auctionEndAt'] as Timestamp?)?.toDate();
    if (end == null) return 'Auction schedule unavailable';
    final remaining = end.difference(DateTime.now());
    if (remaining.isNegative) return 'Auction ended';
    if (remaining.inDays > 0) {
      return '${remaining.inDays}d ${remaining.inHours.remainder(24)}h remaining';
    }
    return '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m remaining';
  }
  if (createdAt == null) return 'Publish date unavailable';
  final age = DateTime.now().difference(createdAt);
  return 'Listed ${age.inDays == 0 ? 'today' : '${age.inDays} days ago'}';
}

Future<void> _markListingNotificationsRead(String listingId) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .where('read', isEqualTo: false)
      .get();
  final batch = FirebaseFirestore.instance.batch();
  for (final document in snapshot.docs) {
    if (document.data()['listingId'] != listingId) continue;
    batch.update(document.reference,
        {'read': true, 'readAt': FieldValue.serverTimestamp()});
  }
  await batch.commit();
}

class _ListingNotificationBadge extends StatelessWidget {
  const _ListingNotificationBadge({required this.listingId});
  final String listingId;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .snapshots(),
        builder: (_, snapshot) {
          final count = snapshot.data?.docs
                  .where((doc) => doc.data()['listingId'] == listingId)
                  .length ??
              0;
          return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.notifications_outlined)));
        });
  }
}

class _OwnerPropertyDetails extends StatelessWidget {
  const _OwnerPropertyDetails({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final facts = <({String label, String value})>[];
    void add(String label, Object? raw) {
      final value = '${raw ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') {
        facts.add((label: label, value: value));
      }
    }

    add('Offering', data['propertyOffering']);
    add('Interest', data['propertyInterest']);
    final acres = data['landAreaAcres'] as num?;
    final hectares = data['landAreaHectares'] as num?;
    if (acres != null && hectares != null) {
      add('Land',
          '${propertyMeasure(acres)} ac • ${propertyMeasure(hectares)} ha');
    }
    final building = data['buildingAreaValue'] as num?;
    if (building != null) {
      add('Building',
          '${propertyMeasure(building)} ${data['buildingAreaUnit'] ?? ''}');
    }
    add('Zoning / use', data['zoningOrUse']);
    for (final item in const [
      ('Monthly revenue', 'monthlyRevenue', ' / month'),
      ('Annual revenue', 'annualRevenue', ' / year'),
      ('Annual NOI', 'netOperatingIncome', ' / year'),
      ('Property tax', 'annualPropertyTax', ' / year'),
    ]) {
      final value = data[item.$2] as num?;
      if (value != null && value > 0) {
        add(item.$1, '${marketplaceMoney(value)}${item.$3}');
      }
    }
    final features = (data['propertyFeatures'] as Iterable?)
        ?.map((value) => '$value'.trim())
        .where((value) => value.isNotEmpty)
        .join(' • ');
    add('Features', features);

    if (facts.isEmpty) return const SizedBox.shrink();
    return Card(
      color: const Color(0xFFF3F8FD),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.real_estate_agent_outlined, color: Color(0xFF0878E8)),
            SizedBox(width: 8),
            Text('Property and business facts',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ]),
          const Divider(),
          ...facts.map((fact) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 2,
                          child: Text(fact.label,
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12))),
                      const SizedBox(width: 8),
                      Expanded(
                          flex: 3,
                          child: Text(fact.value,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700))),
                    ]),
              )),
        ]),
      ),
    );
  }
}

class _OwnerListingDetails extends StatefulWidget {
  const _OwnerListingDetails(
      {required this.listingId,
      required this.data,
      required this.auctionsEnabled,
      required this.paidFeaturesEnabled});

  final String listingId;
  final Map<String, dynamic> data;
  final bool auctionsEnabled;
  final bool paidFeaturesEnabled;

  @override
  State<_OwnerListingDetails> createState() => _OwnerListingDetailsState();
}

class _OwnerListingDetailsState extends State<_OwnerListingDetails> {
  bool _convertingToAuction = false;
  String? _auctionConversionRequestId;
  String? _listingActionBusy;
  final Map<String, String> _listingRequestIds = {};

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('public_listings')
              .doc(widget.listingId)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? widget.data;
            if (data['transactionType'] == 'Auction') {
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('auction_private')
                      .doc(widget.listingId)
                      .snapshots(),
                  builder: (context, privateSnapshot) {
                    final privateData = privateSnapshot.data?.data();
                    return _body(context, {
                      ...data,
                      if (privateData != null) ...privateData,
                    });
                  });
            }
            return _body(context, data);
          });

  Widget _body(BuildContext context, Map<String, dynamic> data) {
    final thumbnail = marketplaceListingThumbnailUrl(data);
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final isAuction = data['transactionType'] == 'Auction';
    final currentBid = data['currentBid'] as num? ?? 0;
    final reserve = data['reservePrice'] as num?;
    final reserveProgress = reserve == null || reserve <= 0
        ? null
        : (currentBid / reserve).clamp(0, 1).toDouble();
    int count(String field) => (data[field] as num?)?.toInt() ?? 0;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .88,
      maxChildSize: .96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(18),
        children: [
          if (thumbnail != null)
            ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child:
                    Image.network(thumbnail, height: 210, fit: BoxFit.cover)),
          const SizedBox(height: 14),
          Row(children: [
            Chip(
                avatar: Icon(
                    isAuction
                        ? Icons.gavel_outlined
                        : Icons.storefront_outlined,
                    size: 17),
                label: Text(isAuction ? 'TIMED AUCTION' : 'MARKETPLACE')),
            const SizedBox(width: 7),
            Expanded(
                child: Text('${data['title'] ?? 'Untitled listing'}',
                    style: const TextStyle(
                        fontSize: 23, fontWeight: FontWeight.w900))),
            if (data['boostRequested'] == true)
              const Chip(
                  avatar: Icon(Icons.rocket_launch_outlined, size: 17),
                  label: Text('Boost')),
          ]),
          Text('${data['category'] ?? ''} • ${data['productType'] ?? ''}'),
          if (createdAt != null)
            Text(_ownerListingTime(data, createdAt),
                style: const TextStyle(color: Colors.black54)),
          if (data['category'] == 'Site & Property') ...[
            const SizedBox(height: 12),
            _OwnerPropertyDetails(data: data),
          ],
          if (!isAuction) ...[
            const SizedBox(height: 12),
            _listingLifecycleCard(data),
          ],
          if (!isAuction && widget.auctionsEnabled) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed:
                    _convertingToAuction ? null : () => _convertToAuction(data),
                icon: _convertingToAuction
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.gavel_outlined),
                label: Text(_convertingToAuction
                    ? 'Publishing timed auction…'
                    : 'Move listing to timed auction'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)))
          ] else ...[
            const SizedBox(height: 12),
            Card(
                color: const Color(0xFFFFF4E5),
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(
                                    'Current bid ${marketplaceMoney(currentBid)}',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900))),
                            Text('${data['bidCount'] ?? 0} bids')
                          ]),
                          if (reserve != null && reserve > 0) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                                value: reserveProgress,
                                color: currentBid >= reserve
                                    ? Colors.green
                                    : Colors.deepOrange),
                            const SizedBox(height: 5),
                            Text(currentBid >= reserve
                                ? 'Reserve met'
                                : '${marketplaceMoney(reserve - currentBid)} below reserve • ${(reserveProgress! * 100).toStringAsFixed(0)}% reached')
                          ] else
                            const Text('No reserve price'),
                          if (data['buyItNowPrice'] is num)
                            Text(
                                'Buy It Now: ${marketplaceMoney(data['buyItNowPrice'] as num)}'),
                          if (currentBid > 0 &&
                              reserve != null &&
                              currentBid < reserve) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                                onPressed: () =>
                                    _acceptBelowReserve(data, currentBid),
                                icon: const Icon(Icons.handshake_outlined),
                                label: const Text('Accept leading bid anyway'))
                          ]
                        ]))),
            _AuctionNotificationSettings(
                listingId: widget.listingId, data: data)
          ],
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Metric(
                icon: Icons.visibility_outlined,
                value: count('viewCount'),
                label: 'Views'),
            _Metric(
                icon: Icons.bookmark_border,
                value: count('saveCount'),
                label: 'Saves'),
            _Metric(
                icon: Icons.share_outlined,
                value: count('shareCount'),
                label: 'Shares'),
            _Metric(
                icon: Icons.favorite_border,
                value: count('likeCount'),
                label: 'Likes'),
            _Metric(
                icon: Icons.forum_outlined,
                value: count('messageCount'),
                label: 'Messages'),
            _Metric(
                icon: Icons.handshake_outlined,
                value: count('offerCount'),
                label: 'Offers'),
          ]),
          const SizedBox(height: 18),
          Text(isAuction ? 'Bidding history' : 'Offer history',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          isAuction
              ? _OwnerBidHistory(listingId: widget.listingId)
              : SizedBox(
                  height: 620,
                  child: MarketplaceNegotiationHistory(
                    listingId: widget.listingId,
                    listingTitle: '${data['title'] ?? 'Marketplace listing'}',
                    buyerUid: '',
                    sellerUid:
                        '${data['sellerUid'] ?? FirebaseAuth.instance.currentUser?.uid ?? ''}',
                    askingPrice: data['price'] as num?,
                    availableQuantity: (data['quantity'] as num?)?.toInt(),
                  ),
                ),
          const SizedBox(height: 18),
          Text('${data['description'] ?? 'No description supplied.'}'),
          const SizedBox(height: 18),
          SelectableText('Listing ID: ${widget.listingId}',
              style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ],
      ),
    );
  }

  Widget _listingLifecycleCard(Map<String, dynamic> data) {
    final status = '${data['status'] ?? 'active'}';
    final busy = _listingActionBusy != null;
    final actions = <Widget>[
      if (status == 'active' || status == 'paused')
        OutlinedButton.icon(
            onPressed: busy ? null : () => _editListing(data),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit details')),
      if (status == 'active')
        OutlinedButton.icon(
            onPressed: busy ? null : () => _transitionListing('pause'),
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text('Pause')),
      if (status == 'paused')
        FilledButton.tonalIcon(
            onPressed: busy ? null : () => _transitionListing('activate'),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Reactivate')),
      if (status == 'active' || status == 'pending_sale')
        FilledButton.tonalIcon(
            onPressed: busy ? null : () => _transitionListing('mark_sold'),
            icon: const Icon(Icons.task_alt),
            label: const Text('Mark sold')),
      if (status == 'active' || status == 'paused' || status == 'sold')
        OutlinedButton.icon(
            onPressed: busy ? null : () => _transitionListing('archive'),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive')),
      if (status == 'sold' || status == 'archived')
        FilledButton.icon(
            onPressed: busy ? null : _relistListing,
            icon: const Icon(Icons.refresh),
            label: const Text('Relist as new')),
    ];
    return Card(
        color: const Color(0xFFF3F8FD),
        child: Padding(
            padding: const EdgeInsets.all(13),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.inventory_2_outlined,
                    color: Color(0xFF0878E8)),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('Listing controls',
                        style: TextStyle(fontWeight: FontWeight.w900))),
                Chip(label: Text(status.replaceAll('_', ' ').toUpperCase())),
              ]),
              const SizedBox(height: 6),
              if (busy)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text(_listingActionBusy!),
                    ])),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ])));
  }

  Future<void> _editListing(Map<String, dynamic> data) async {
    final title = TextEditingController(text: '${data['title'] ?? ''}');
    final price = TextEditingController(text: '${data['price'] ?? ''}');
    final quantity = TextEditingController(text: '${data['quantity'] ?? ''}');
    final description =
        TextEditingController(text: '${data['description'] ?? ''}');
    final submitted = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                    title: const Text('Edit listing details'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: title,
                          decoration:
                              const InputDecoration(labelText: 'Title *')),
                      TextField(
                          controller: price,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Price *', prefixText: r'$ ')),
                      TextField(
                          controller: quantity,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Quantity *')),
                      TextField(
                          controller: description,
                          minLines: 3,
                          maxLines: 6,
                          decoration:
                              const InputDecoration(labelText: 'Description')),
                      const SizedBox(height: 8),
                      const Text(
                          'Changes are recorded in the permanent listing history.',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Save changes')),
                    ])) ??
        false;
    if (!submitted || !mounted) return;
    final amount = num.tryParse(price.text.trim());
    final count = int.tryParse(quantity.text.trim());
    if (title.text.trim().isEmpty ||
        amount == null ||
        amount <= 0 ||
        count == null ||
        count < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Enter a title, valid price, and valid quantity.')));
      return;
    }
    await _runListingCommand(
        key: 'edit-${data['revision'] ?? 1}',
        label: 'Saving listing…',
        command: 'updateMarketplaceListingDetails',
        data: {
          'listingId': widget.listingId,
          'expectedRevision': (data['revision'] as num?)?.toInt() ?? 1,
          'patch': {
            'title': title.text.trim(),
            'price': amount,
            'quantity': count,
            'description': description.text.trim(),
          },
        },
        success: 'Listing details updated.');
  }

  Future<void> _transitionListing(String action) async {
    const labels = {
      'pause': 'Pause this listing?',
      'activate': 'Reactivate this listing?',
      'mark_sold': 'Mark this listing as sold?',
      'archive': 'Archive this listing?',
    };
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                    title: Text(labels[action] ?? 'Change listing status?'),
                    content: const Text(
                        'This change is recorded in the permanent listing history.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Confirm')),
                    ])) ??
        false;
    if (!confirmed || !mounted) return;
    await _runListingCommand(
        key: action,
        label: 'Updating listing…',
        command: 'transitionMarketplaceListing',
        data: {'listingId': widget.listingId, 'action': action},
        success: 'Listing status updated.');
  }

  Future<void> _relistListing() async {
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                    title: const Text('Relist as a new listing?'),
                    content: const Text(
                        'The original history remains unchanged. A new active listing is created with fresh analytics and the same private pickup details.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Create new listing')),
                    ])) ??
        false;
    if (!confirmed || !mounted) return;
    final key = 'relist';
    final newListingId = _listingRequestIds['$key-listing'] ??=
        FirebaseFirestore.instance.collection('public_listings').doc().id;
    await _runListingCommand(
        key: key,
        label: 'Creating new listing…',
        command: 'relistMarketplaceListing',
        data: {
          'listingId': widget.listingId,
          'newListingId': newListingId,
        },
        success: 'New active listing created.');
  }

  Future<void> _runListingCommand(
      {required String key,
      required String label,
      required String command,
      required Map<String, dynamic> data,
      required String success}) async {
    final requestId = _listingRequestIds[key] ??=
        '${widget.listingId}-$key-${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _listingActionBusy = label);
    try {
      await MarketplaceCommandClient()
          .execute(command, {'requestId': requestId, ...data});
      _listingRequestIds.remove(key);
      if (key == 'relist') {
        _listingRequestIds.remove('$key-listing');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.green, content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red,
            content: Text('$error'.replaceFirst('Bad state: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _listingActionBusy = null);
    }
  }

  Future<void> _convertToAuction(Map<String, dynamic> data) async {
    final starting = TextEditingController(
        text: '${data['price'] ?? ''}'.replaceAll('.0', ''));
    final reserve = TextEditingController();
    final buyNow = TextEditingController();
    final customDays = TextEditingController(text: '30');
    final priceBasis = '${data['priceBasis'] ?? 'Per piece'}'.trim();
    final quantity = (data['quantity'] as num?)?.toInt();
    final askingPrice = data['price'] as num? ?? 0;
    final isTotalBasis = priceBasis.toLowerCase().contains('total');
    final increment = TextEditingController(text: isTotalBasis ? '25' : '0.50');
    var incrementSelection = isTotalBasis ? '25' : '0.50';
    final askingTotal =
        isTotalBasis ? askingPrice : askingPrice * (quantity ?? 1);
    var durationDays = 7;
    var customDuration = false;
    String? formError;
    final submitted = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => StatefulBuilder(
                builder: (context, update) => Dialog(
                    insetPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const CircleAvatar(
                                        radius: 25,
                                        backgroundColor: Color(0xFFE5F2FF),
                                        child: Icon(Icons.gavel_outlined,
                                            color: Color(0xFF0878E8))),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text('Move to timed auction',
                                              style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900)),
                                          Text('Review pricing and timing',
                                              style: TextStyle(
                                                  color: Color(0xFF66758A)))
                                        ])),
                                    IconButton(
                                        tooltip: 'Close',
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        icon: const Icon(Icons.close))
                                  ]),
                                  const SizedBox(height: 16),
                                  Container(
                                      padding: const EdgeInsets.all(13),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFFFF4E5),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: const Color(0xFFFFC46B))),
                                      child: const Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.info_outline,
                                                color: Color(0xFFE56F00)),
                                            SizedBox(width: 9),
                                            Expanded(
                                                child: Text(
                                                    'The listing moves from Marketplace to Auctions. Existing offers stay safely available in history.'))
                                          ])),
                                  const SizedBox(height: 18),
                                  const Text('Auction pricing',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 10),
                                  Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(13),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFEAF4FD),
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                                'Original listing pricing',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF66758A))),
                                            Text(
                                                '\$${askingPrice.toStringAsFixed(2)} • $priceBasis',
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w900)),
                                            if (quantity != null)
                                              Text(
                                                  '$quantity units • Asking total \$${askingTotal.toStringAsFixed(2)}'),
                                            const SizedBox(height: 4),
                                            const Text(
                                                'Bids, reserve, and Buy It Now use the same pricing basis.',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF315A7D)))
                                          ])),
                                  _auctionMoneyField(starting,
                                      label: 'Starting bid • $priceBasis',
                                      helper: 'The first acceptable bid amount',
                                      icon: Icons.play_circle_outline,
                                      onChanged: (_) => update(() {})),
                                  const SizedBox(height: 10),
                                  _auctionMoneyField(reserve,
                                      label: 'Reserve price (optional)',
                                      helper:
                                          'You are not required to sell below this amount',
                                      icon: Icons.shield_outlined,
                                      onChanged: (_) => update(() {})),
                                  if (num.tryParse(reserve.text) != null) ...[
                                    const SizedBox(height: 10),
                                    _priceAnalytics(
                                        title:
                                            'Reserve compared with asking price',
                                        valueLabel: 'Reserve',
                                        value: num.parse(reserve.text),
                                        askingTotal: askingTotal,
                                        quantity: quantity,
                                        isTotalBasis: isTotalBasis,
                                        priceBasis: priceBasis)
                                  ],
                                  const SizedBox(height: 10),
                                  _auctionMoneyField(buyNow,
                                      label: 'Buy It Now (optional)',
                                      helper:
                                          'A buyer can end the auction immediately',
                                      icon: Icons.flash_on_outlined,
                                      onChanged: (_) => update(() {})),
                                  if (num.tryParse(buyNow.text) != null) ...[
                                    const SizedBox(height: 10),
                                    _priceAnalytics(
                                        title:
                                            'Buy It Now compared with asking price',
                                        valueLabel: 'Buy It Now',
                                        value: num.parse(buyNow.text),
                                        askingTotal: askingTotal,
                                        quantity: quantity,
                                        isTotalBasis: isTotalBasis,
                                        priceBasis: priceBasis)
                                  ],
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                      initialValue: incrementSelection,
                                      decoration: InputDecoration(
                                          labelText:
                                              'Minimum bid increase • $priceBasis',
                                          helperText: isTotalBasis
                                              ? 'Increase applied to the total auction price'
                                              : 'Increase applied to each unit',
                                          prefixIcon:
                                              const Icon(Icons.trending_up),
                                          filled: true,
                                          fillColor: const Color(0xFFF1F6FC),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14))),
                                      items: const [
                                        ('0.50', '\$0.50'),
                                        ('1', '\$1.00'),
                                        ('2.50', '\$2.50'),
                                        ('5', '\$5.00'),
                                        ('10', '\$10.00'),
                                        ('25', '\$25.00'),
                                        ('50', '\$50.00'),
                                        ('100', '\$100.00'),
                                        ('250', '\$250.00'),
                                        ('500', '\$500.00'),
                                        ('1000', '\$1,000.00'),
                                        ('manual', 'Manual amount')
                                      ]
                                          .map((option) => DropdownMenuItem(
                                              value: option.$1,
                                              child: Text(option.$2)))
                                          .toList(),
                                      onChanged: (value) => update(() {
                                            incrementSelection =
                                                value ?? incrementSelection;
                                            if (incrementSelection !=
                                                'manual') {
                                              increment.text =
                                                  incrementSelection;
                                            }
                                            formError = null;
                                          })),
                                  if (incrementSelection == 'manual') ...[
                                    const SizedBox(height: 10),
                                    _auctionMoneyField(increment,
                                        label: 'Manual bid increase',
                                        helper:
                                            'Enter an amount from \$0.50 to \$1,000.00 • $priceBasis',
                                        icon: Icons.edit_outlined,
                                        onChanged: (_) => update(() {}))
                                  ],
                                  const SizedBox(height: 18),
                                  const Text('Auction duration',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 4),
                                  const Text(
                                      'Choose how long buyers can place bids.',
                                      style:
                                          TextStyle(color: Color(0xFF66758A))),
                                  const SizedBox(height: 10),
                                  Wrap(spacing: 8, runSpacing: 8, children: [
                                    ...[
                                      1,
                                      3,
                                      5,
                                      7,
                                      10,
                                      14,
                                      30
                                    ].map((days) => ChoiceChip(
                                        selected: durationDays == days,
                                        label: Text(
                                            '$days day${days == 1 ? '' : 's'}'),
                                        avatar: durationDays == days
                                            ? const Icon(Icons.check, size: 17)
                                            : null,
                                        onSelected: (_) => update(() {
                                              durationDays = days;
                                              customDuration = false;
                                              formError = null;
                                            }))),
                                    if (widget.paidFeaturesEnabled)
                                      ChoiceChip(
                                          selected: customDuration,
                                          avatar: const Icon(
                                              Icons.tune_outlined,
                                              size: 17),
                                          label: const Text('Custom'),
                                          onSelected: (_) => update(() {
                                                customDuration = true;
                                                durationDays = int.tryParse(
                                                        customDays.text) ??
                                                    30;
                                                formError = null;
                                              }))
                                  ]),
                                  if (customDuration) ...[
                                    const SizedBox(height: 12),
                                    TextField(
                                        controller: customDays,
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) => update(() =>
                                            durationDays =
                                                int.tryParse(value) ?? 0),
                                        decoration: InputDecoration(
                                            labelText:
                                                'Custom duration in days',
                                            helperText:
                                                'Enter 1–360 days. Eligible bids may be withdrawn after day 32.',
                                            prefixIcon: const Icon(
                                                Icons.calendar_month_outlined),
                                            suffixText: 'days',
                                            filled: true,
                                            fillColor: const Color(0xFFF1F6FC),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        14)))),
                                    const SizedBox(height: 12),
                                    Container(
                                        padding: const EdgeInsets.all(13),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFFFF4E5),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color:
                                                    const Color(0xFFFFC46B))),
                                        child: const Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Custom auction fees',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900)),
                                              SizedBox(height: 5),
                                              Text(
                                                  '• \$29.99 upfront listing fee\n• 5% of the completed sale\n• Additional auction-service fees may apply later'),
                                              SizedBox(height: 5),
                                              Text(
                                                  'The upfront fee and final sale fee are separate. Charges must be reviewed before payment.',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF7A4A00)))
                                            ]))
                                  ],
                                  if (formError != null) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(11),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFFFEBEE),
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: Text(formError!,
                                            style: const TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.w700)))
                                  ],
                                  const SizedBox(height: 22),
                                  Row(children: [
                                    Expanded(
                                        child: OutlinedButton(
                                            onPressed: () => Navigator.pop(
                                                dialogContext, false),
                                            style: OutlinedButton.styleFrom(
                                                minimumSize:
                                                    const Size.fromHeight(50)),
                                            child: const Text('Cancel'))),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        flex: 2,
                                        child: FilledButton.icon(
                                            onPressed: () {
                                              final start =
                                                  num.tryParse(starting.text);
                                              final step =
                                                  num.tryParse(increment.text);
                                              final reserveAmount =
                                                  num.tryParse(reserve.text);
                                              final buyNowAmount =
                                                  num.tryParse(buyNow.text);
                                              if (customDuration &&
                                                  (durationDays < 1 ||
                                                      durationDays > 360)) {
                                                update(() => formError =
                                                    'Custom duration must be between 1 and 360 days.');
                                                return;
                                              }
                                              if (start == null ||
                                                  start < 0 ||
                                                  step == null ||
                                                  step < .5 ||
                                                  step > 1000) {
                                                update(() => formError =
                                                    'Enter a valid starting bid. Bid increase must be between \$0.50 and \$1,000.00.');
                                                return;
                                              }
                                              if ((reserveAmount != null &&
                                                      reserveAmount < start) ||
                                                  (buyNowAmount != null &&
                                                      (buyNowAmount < start ||
                                                          (reserveAmount !=
                                                                  null &&
                                                              buyNowAmount <
                                                                  reserveAmount)))) {
                                                update(() => formError =
                                                    'Reserve must be at least the starting bid. Buy It Now must be at least the starting bid and reserve.');
                                                return;
                                              }
                                              Navigator.pop(
                                                  dialogContext, true);
                                            },
                                            icon: const Icon(
                                                Icons.fact_check_outlined),
                                            style: FilledButton.styleFrom(
                                                minimumSize:
                                                    const Size.fromHeight(50)),
                                            label:
                                                const Text('Review auction')))
                                  ])
                                ])))))) ??
        false;
    if (!submitted || !mounted) return;
    final startAmount = num.tryParse(starting.text);
    final increase = num.tryParse(increment.text);
    if (startAmount == null || increase == null || increase <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a starting bid and minimum increase.')));
      return;
    }
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    icon: const CircleAvatar(
                        backgroundColor: Color(0xFFEAF8F1),
                        child: Icon(Icons.gavel, color: Colors.green)),
                    title: const Text('Publish timed auction?'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      _auctionReviewRow('Starting bid',
                          '\$${startAmount.toStringAsFixed(2)} • $priceBasis'),
                      _auctionReviewRow(
                          'Reserve',
                          num.tryParse(reserve.text) == null
                              ? 'None'
                              : '\$${num.parse(reserve.text).toStringAsFixed(2)}'),
                      _auctionReviewRow(
                          'Buy It Now',
                          num.tryParse(buyNow.text) == null
                              ? 'None'
                              : '\$${num.parse(buyNow.text).toStringAsFixed(2)}'),
                      _auctionReviewRow(
                          'Bid increase', '\$${increase.toStringAsFixed(2)}'),
                      _auctionReviewRow('Duration', '$durationDays days'),
                      _auctionReviewRow('Auction type',
                          customDuration ? 'Custom' : 'Standard timed'),
                      if (customDuration) ...[
                        _auctionReviewRow('Upfront fee', '\$29.99'),
                        _auctionReviewRow('Sale fee', '5% of completed sale'),
                        const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                                'Bid withdrawal becomes available after day 32, subject to auction status and bid eligibility.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF7A4A00))))
                      ],
                      const Divider(height: 24),
                      const Text(
                          'Bidding starts immediately. Auction notifications will be enabled.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF66758A)))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Go back')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Publish auction'))
                    ])) ??
        false;
    if (!confirmed) return;
    final reserveAmount = num.tryParse(reserve.text);
    setState(() => _convertingToAuction = true);
    try {
      _auctionConversionRequestId ??=
          '${widget.listingId}-${DateTime.now().microsecondsSinceEpoch}';
      await MarketplaceCommandClient()
          .execute('convertMarketplaceListingToAuction', {
        'requestId': _auctionConversionRequestId,
        'listingId': widget.listingId,
        'startingBid': startAmount,
        'minimumBidIncrement': increase,
        'reservePrice': reserveAmount,
        'buyItNowPrice': num.tryParse(buyNow.text),
        'durationDays': durationDays,
        'customAuction': customDuration,
      });
      if (mounted) {
        _auctionConversionRequestId = null;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Listing moved to Auctions.')));
      }
    } catch (error) {
      if (mounted) {
        final message = '$error'.replaceFirst('Bad state: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red,
            content: Text(message.isEmpty
                ? 'The listing could not be moved to Auctions.'
                : message)));
      }
    } finally {
      if (mounted) setState(() => _convertingToAuction = false);
    }
  }

  Widget _auctionMoneyField(TextEditingController controller,
          {required String label,
          required String helper,
          required IconData icon,
          ValueChanged<String>? onChanged}) =>
      TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: label,
              helperText: helper,
              helperMaxLines: 2,
              prefixIcon: Icon(icon),
              prefixText: '\$ ',
              filled: true,
              fillColor: const Color(0xFFF1F6FC),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD9E5F2))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFF0878E8), width: 2))));

  Widget _priceAnalytics(
      {required String title,
      required String valueLabel,
      required num value,
      required num askingTotal,
      required int? quantity,
      required bool isTotalBasis,
      required String priceBasis}) {
    final calculatedTotal = isTotalBasis ? value : value * (quantity ?? 1);
    final difference = calculatedTotal - askingTotal;
    final percent = askingTotal == 0 ? 0 : difference / askingTotal * 100;
    final meetsAsk = difference >= 0;
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: meetsAsk ? const Color(0xFFEAF8F1) : const Color(0xFFFFF4E5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: meetsAsk
                    ? Colors.green.shade300
                    : const Color(0xFFFFC46B))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.analytics_outlined,
                color: meetsAsk ? Colors.green.shade700 : Colors.deepOrange),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)))
          ]),
          const SizedBox(height: 7),
          _auctionReviewRow(
              valueLabel,
              '\$${value.toStringAsFixed(2)} • $priceBasis'
              '${isTotalBasis || quantity == null ? '' : ' × $quantity'}'),
          _auctionReviewRow(
              '$valueLabel total', '\$${calculatedTotal.toStringAsFixed(2)}'),
          _auctionReviewRow(
              'Original asking total', '\$${askingTotal.toStringAsFixed(2)}'),
          Text(
              '${difference >= 0 ? '+' : '-'}\$${difference.abs().toStringAsFixed(2)} '
              '(${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%) versus asking',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: meetsAsk ? Colors.green.shade700 : Colors.deepOrange))
        ]));
  }

  Widget _auctionReviewRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(
            child:
                Text(label, style: const TextStyle(color: Color(0xFF66758A)))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900))
      ]));

  Future<void> _acceptBelowReserve(
      Map<String, dynamic> data, num currentBid) async {
    final bidderUid = '${data['highBidderUid'] ?? ''}';
    if (bidderUid.isEmpty) return;
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Accept below reserve?'),
                    content: Text(
                        'Accept the leading \$${currentBid.toStringAsFixed(2)} bid and end this auction now? The bidder will be notified.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Accept and end auction'))
                    ])) ??
        false;
    if (!confirmed) return;
    await MarketplaceAuctionRepository()
        .acceptLeadingBidBelowReserve(listingId: widget.listingId);
    if (mounted) Navigator.pop(context);
  }
}

class _AuctionNotificationSettings extends StatelessWidget {
  const _AuctionNotificationSettings(
      {required this.listingId, required this.data});
  final String listingId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => ExpansionTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Auction notifications',
              style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Choose which auction updates you receive'),
          children: [
            _setting(
                'New bids', 'notifyNewBids', data['notifyNewBids'] != false),
            _setting('Reserve reached', 'notifyReserveReached',
                data['notifyReserveReached'] != false),
            _setting('Auction ending soon', 'notifyAuctionEnding',
                data['notifyAuctionEnding'] != false),
          ]);

  Widget _setting(String label, String field, bool value) => SwitchListTile(
      value: value,
      title: Text(label),
      onChanged: (enabled) => FirebaseFirestore.instance
          .collection('public_listings')
          .doc(listingId)
          .update({field: enabled, 'updatedAt': FieldValue.serverTimestamp()}));
}

class _OwnerBidHistory extends StatelessWidget {
  const _OwnerBidHistory({required this.listingId});
  final String listingId;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('auction_bids')
              .where('listingId', isEqualTo: listingId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final bids = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final at = a.data()['createdAt'] as Timestamp?;
                final bt = b.data()['createdAt'] as Timestamp?;
                return (bt?.millisecondsSinceEpoch ?? 0)
                    .compareTo(at?.millisecondsSinceEpoch ?? 0);
              });
            if (bids.isEmpty) return const Text('No bids received yet.');
            return Column(
                children: bids
                    .map((bid) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                            child: Icon(Icons.gavel, size: 18)),
                        title: Text(
                            '\$${(bid.data()['amount'] as num? ?? 0).toStringAsFixed(2)}'),
                        subtitle: Text(bid.data()['createdAt'] is Timestamp
                            ? (bid.data()['createdAt'] as Timestamp)
                                .toDate()
                                .toLocal()
                                .toString()
                            : 'Submitting…'),
                        trailing: bid.data()['status'] == 'buy_now'
                            ? const Chip(label: Text('BUY NOW'))
                            : null))
                    .toList());
          });
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 17), label: Text('$value $label'));
}

class _AccountNotifications extends StatelessWidget {
  const _AccountNotifications(
      {required this.onOpenTab, required this.onBrowse});
  final ValueChanged<int> onOpenTab;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in to view notifications.'));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Could not load notifications: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final at = a.data()['createdAt'] as Timestamp?;
              final bt = b.data()['createdAt'] as Timestamp?;
              return (bt?.millisecondsSinceEpoch ?? 0)
                  .compareTo(at?.millisecondsSinceEpoch ?? 0);
            });
          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final document = items[index];
                final data = document.data();
                final unread = data['read'] != true;
                return Card(
                    color: unread ? const Color(0xFFEAF4FD) : null,
                    child: ListTile(
                      leading: Icon(data['type'] == 'offer'
                          ? Icons.handshake_outlined
                          : Icons.chat_bubble_outline),
                      title: Text('${data['title'] ?? 'Marketplace activity'}',
                          style: TextStyle(
                              fontWeight:
                                  unread ? FontWeight.w900 : FontWeight.w600)),
                      subtitle: Text(data['createdAt'] is Timestamp
                          ? (data['createdAt'] as Timestamp)
                              .toDate()
                              .toLocal()
                              .toString()
                          : ''),
                      trailing: unread
                          ? const Badge()
                          : const Icon(Icons.chevron_right),
                      onTap: () async {
                        await document.reference.update({
                          'read': true,
                          'readAt': FieldValue.serverTimestamp(),
                        });
                        final type = '${data['type'] ?? ''}';
                        if (type == 'message') {
                          onOpenTab(3);
                        } else if (type == 'offer') {
                          onOpenTab(2);
                        } else if (type == 'new_listing_match' ||
                            type == 'seller_new_listing') {
                          onBrowse();
                        } else if (type == 'score_change') {
                          if (context.mounted) {
                            _showUserScore(context, onOpenTab);
                          }
                        } else {
                          onOpenTab(1);
                        }
                      },
                    ));
              });
        });
  }
}

class _AccountTabBadge extends StatelessWidget {
  const _AccountTabBadge({required this.types, required this.icon});
  final Set<String> types;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Icon(icon, size: 20);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .snapshots(),
        builder: (_, snapshot) {
          final count = snapshot.data?.docs.where((doc) {
                final type = '${doc.data()['type'] ?? ''}';
                return types.isEmpty || types.contains(type);
              }).length ??
              0;
          return Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: Icon(icon, size: 20));
        });
  }
}

class _AccountSettings extends StatelessWidget {
  const _AccountSettings();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in.'));
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Account settings',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      ListTile(
          leading: const Icon(Icons.email_outlined),
          title: const Text('Sign-in email'),
          subtitle: Text(user.email ?? '')),
      ListTile(
          leading: Icon(
              user.emailVerified && user.phoneNumber != null
                  ? Icons.verified_user_outlined
                  : Icons.security_outlined,
              color: user.emailVerified && user.phoneNumber != null
                  ? Colors.green
                  : null),
          title: const Text('Account security and ownership'),
          subtitle: Text(user.emailVerified && user.phoneNumber != null
              ? 'Email and mobile phone verified'
              : 'Verification required for protected marketplace actions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MarketplaceAccountSecurityPage()))),
      ListTile(
          leading: const Icon(Icons.lock_reset_outlined),
          title: const Text('Send password reset email'),
          onTap: user.email == null
              ? null
              : () => FirebaseAuth.instance
                  .sendPasswordResetEmail(email: user.email!)),
      const SizedBox(height: 12),
      const _WatchKeywords(),
      const SizedBox(height: 12),
      OutlinedButton.icon(
          onPressed: () => _signOutFromSettings(context),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out')),
    ]);
  }
}

Future<void> _signOutFromSettings(BuildContext context) async {
  final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.logout, size: 34),
          title: const Text('Sign out?'),
          content: const Text(
              'You will return to the marketplace home page and can sign in again at any time.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Sign out'))
          ],
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted) return;
  try {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    MarketplaceNavigation.goHome(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.white),
          SizedBox(width: 10),
          Expanded(
              child: Text(
                  'Signed out successfully. You can sign in again from the menu.'))
        ])));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
        content: Text(
            'Sign out failed. Please check your connection and try again.')));
  }
}

class _WatchKeywords extends StatefulWidget {
  const _WatchKeywords();
  @override
  State<_WatchKeywords> createState() => _WatchKeywordsState();
}

class _WatchKeywordsState extends State<_WatchKeywords> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('watch_keywords');
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Watch marketplace keywords',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const Text(
                  'Get notified when a new listing matches equipment, pipe, brand, model or location words.'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                            hintText:
                                'Example: 2 7/8 drill pipe Grande Prairie'))),
                IconButton.filled(
                    onPressed: () async {
                      final words = controller.text
                          .toLowerCase()
                          .split(RegExp(r'[^a-z0-9/]+'))
                          .where((word) => word.length > 1)
                          .toSet()
                          .take(10)
                          .toList();
                      if (words.isEmpty) return;
                      await collection.add({
                        'keywords': words,
                        'label': controller.text.trim(),
                        'enabled': true,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      controller.clear();
                    },
                    icon: const Icon(Icons.add_alert_outlined))
              ]),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: collection.snapshots(),
                  builder: (_, snapshot) => Wrap(
                      spacing: 6,
                      children: (snapshot.data?.docs ?? const [])
                          .map((doc) => InputChip(
                              label: Text('${doc.data()['label'] ?? ''}'),
                              onDeleted: doc.reference.delete))
                          .toList()))
            ])));
  }
}
