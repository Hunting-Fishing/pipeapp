import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/data/bounded_firestore_query.dart';

import 'marketplace_messages_page.dart';
import 'marketplace_auth_page.dart';
import 'marketplace_policy_center.dart';
import 'marketplace_admin_access.dart';
import 'marketplace_account_security_page.dart';
import 'marketplace_account_device_repository.dart';
import 'marketplace_auction_repository.dart';
import 'marketplace_profile_page.dart';
import 'marketplace_reporting.dart';
import 'marketplace_support.dart';
import 'marketplace_navigation.dart';
import 'marketplace_listing_media.dart';
import 'marketplace_money.dart';
import 'marketplace_notification_service.dart';
import 'marketplace_property_details.dart';
import 'marketplace_command_client.dart';
import 'account_export_downloader.dart';
import 'marketplace_data_state.dart';
import 'marketplace_deep_links.dart';
import 'marketplace_actions_repository.dart';
import 'marketplace_payout_settings.dart';
import 'marketplace_admin_transaction_portal.dart';
import 'marketplace_admin_dashboard.dart';

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
    with TickerProviderStateMixin {
  late TabController _tabs;
  bool _isAdminUser = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _isAdminUser = user?.email?.toLowerCase().trim() == 'jordilwbailey@gmail.com';
    _tabs = TabController(length: _isAdminUser ? 7 : 6, vsync: this);
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    final isMaster = user?.email?.toLowerCase().trim() == 'jordilwbailey@gmail.com';
    final isAdminClaim = await marketplaceAdministratorAccess();
    final isAuthorized = isMaster || isAdminClaim;
    if (isAuthorized && mounted && !_isAdminUser) {
      setState(() {
        _isAdminUser = true;
        _tabs.dispose();
        _tabs = TabController(length: 7, vsync: this);
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: [
              const Tab(
                  icon: Icon(Icons.dashboard_outlined, size: 20),
                  text: 'Overview'),
              const Tab(icon: Icon(Icons.badge_outlined, size: 20), text: 'Profile'),
              const Tab(
                  icon: _AccountTabBadge(
                      types: {'offer'}, icon: Icons.inventory_2_outlined),
                  text: 'Listings'),
              const Tab(
                  icon: _AccountTabBadge(
                      types: {'message'}, icon: Icons.forum_outlined),
                  text: 'Messages'),
              const Tab(
                  icon: _AccountTabBadge(
                      types: {}, icon: Icons.notifications_outlined),
                  text: 'Notifications'),
              const Tab(
                  icon: Icon(Icons.settings_outlined, size: 20),
                  text: 'Settings'),
              if (_isAdminUser)
                Tab(
                    icon: Icon(Icons.admin_panel_settings, color: Colors.purple.shade700, size: 20),
                    text: '👑 ADMIN PORTAL'),
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
          if (_isAdminUser)
            const MarketplaceAdminDashboard(),
        ]))
      ]);
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.onOpen});
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const MarketplaceAuthRequiredCard(
        title: 'Account Required',
        description:
            'Sign in or create a free Pipe Buyer account to manage your profile, view order history, and access seller tools.',
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final completion = calculateProfileCompletion(user, data);
          final userScore =
              ((data['userScore'] as num?)?.toInt() ?? 70).clamp(0, 100);
          final isMasterAdmin = user.email?.toLowerCase().trim() == 'jordilwbailey@gmail.com';

          return ListView(padding: const EdgeInsets.all(18), children: [
            if (isMasterAdmin) ...[
              Card(
                color: Colors.purple.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 36),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              '👑 MASTER ADMIN PORTAL ACTIVE',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Access revenue analytics, escrow overrides, bank accounts, merchant gateways & user controls.',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700),
                        onPressed: () => onOpen(6), // Switch to 7th Admin Portal Tab
                        icon: const Icon(Icons.launch, color: Colors.black, size: 16),
                        label: const Text(
                          'Open Admin Portal',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
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
              trailing: data['accountVerified'] == true &&
                      (data['accountVerificationReviewVersion'] as num? ?? 0) >=
                          1
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
            FutureBuilder<bool>(
                future: marketplaceAdministratorAccess(),
                builder: (context, access) => access.data == true || user.email?.toLowerCase().trim() == 'jordilwbailey@gmail.com'
                    ? Card(
                        color: Colors.purple.shade50,
                        margin: const EdgeInsets.only(top: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.purple.shade200),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.admin_panel_settings, color: Colors.purple.shade800, size: 26),
                          title: Text(
                            '👑 MASTER ADMIN PORTAL DASHBOARD',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                          ),
                          subtitle: const Text('Analytics, Escrow Overrides, Banking Setup, Users, Moderation & Config.'),
                          trailing: const Icon(Icons.chevron_right, color: Colors.purple),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MarketplaceAdminDashboard()),
                          ),
                        ),
                      )
                    : const SizedBox.shrink()),
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
        .orderBy('createdAt', descending: true)
        .limit(defaultActivityFeedLimit)
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
      'Verified email ownership',
      data['emailOwnershipVerified'] == true,
      'Open Account Security and verify the email address you own.',
    ),
    (
      'Verified mobile ownership',
      data['phoneOwnershipVerified'] == true,
      'Open Account Security and verify your mobile number by SMS.',
    ),
    (
      'Profile details',
      calculateProfileCompletion(FirebaseAuth.instance.currentUser, data) >= 100,
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
  final ownershipReady = data['emailOwnershipVerified'] == true &&
      data['phoneOwnershipVerified'] == true;
  final reviewApproved = data['accountVerified'] == true &&
      (data['accountVerificationReviewVersion'] as num? ?? 0) >= 1;
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
                          tooltip: 'Close score history',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close))
                    ]),
                    if (!reviewApproved)
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
                                                          try {
                                                            final result =
                                                                await _requestVerification();
                                                            if (dialogContext
                                                                .mounted) {
                                                              Navigator.pop(
                                                                  dialogContext);
                                                            }
                                                            if (context
                                                                .mounted) {
                                                              final status =
                                                                  '${result['status'] ?? 'pending'}';
                                                              ScaffoldMessenger
                                                                      .of(
                                                                          context)
                                                                  .showSnackBar(SnackBar(
                                                                      content: Text(status ==
                                                                              'approved'
                                                                          ? 'Your account is already verified.'
                                                                          : 'Verification submitted for secure administrator review.')));
                                                            }
                                                          } catch (error) {
                                                            if (context
                                                                .mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                                  content: Text('$error'
                                                                      .replaceFirst(
                                                                          'Bad state: ',
                                                                          '')),
                                                                  backgroundColor:
                                                                      Colors.red
                                                                          .shade700));
                                                            }
                                                          }
                                                        }
                                                      : () {
                                                          Navigator.pop(
                                                              dialogContext);
                                                          if (!ownershipReady) {
                                                            Navigator.of(
                                                                    context)
                                                                .push(MaterialPageRoute<
                                                                        void>(
                                                                    builder: (_) =>
                                                                        const MarketplaceAccountSecurityPage()));
                                                          } else {
                                                            onOpenTab(1);
                                                          }
                                                        },
                                                  icon: Icon(readyForReview
                                                      ? Icons.send_outlined
                                                      : Icons.edit_outlined),
                                                  label: Text(readyForReview
                                                      ? 'Submit verification for review'
                                                      : ownershipReady
                                                          ? 'Complete missing profile items'
                                                          : 'Verify email and mobile')))
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

Future<Map<String, dynamic>> _requestVerification() {
  final requestId = FirebaseFirestore.instance
      .collection('account_verification_command_receipts')
      .doc()
      .id;
  return MarketplaceCommandClient().execute(
    'submitAccountVerification',
    {'requestId': requestId},
  );
}

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

class _MyListings extends StatefulWidget {
  const _MyListings(
      {required this.onAddListing,
      required this.auctionsEnabled,
      required this.paidFeaturesEnabled});

  final VoidCallback onAddListing;
  final bool auctionsEnabled;
  final bool paidFeaturesEnabled;

  @override
  State<_MyListings> createState() => _MyListingsState();
}

class _MyListingsState extends State<_MyListings> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _listings = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || (_loading && !reset) || (!reset && !_hasMore)) return;
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _listings.clear();
        _cursor = null;
        _hasMore = true;
      }
    });
    try {
      final query = FirebaseFirestore.instance
          .collection('public_listings')
          .where('sellerUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true);
      final draftsQuery = FirebaseFirestore.instance
          .collection('marketplace_listing_drafts')
          .where('sellerUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true);
      final page = await loadFirestoreDocumentPage(query, after: reset ? null : _cursor);
      QuerySnapshot<Map<String, dynamic>>? draftsSnap;
      try {
        draftsSnap = await draftsQuery.get();
      } catch (_) {}
      if (!mounted || generation != _generation) return;
      final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
        ...page.documents,
        ...?draftsSnap?.docs,
      ];
      final merged = appendUniqueById(
          reset
              ? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]
              : _listings,
          docs,
          (document) => document.id);
      setState(() {
        _listings
          ..clear()
          ..addAll(merged);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error is FirebaseException &&
                error.code == 'failed-precondition'
            ? 'Your listing index is still being prepared. Try again shortly.'
            : 'Check your connection and try again.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const MarketplaceAuthRequiredCard(
        title: 'Listings Dashboard',
        description:
            'Sign in to post equipment listings, track active buyers, and manage your inventory.',
      );
    }
    if (_error != null && _listings.isEmpty) {
      return MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.error,
        title: 'Your listings could not be loaded',
        message: _error!,
        primaryLabel: 'Try again',
        primaryIcon: Icons.refresh,
        onPrimary: () => _load(reset: true),
      );
    }
    if (_loading && _listings.isEmpty) {
      return const MarketplaceDataStateView.loading(
        title: 'Loading your listings',
        message: 'Retrieving listing status, activity, and offers…',
      );
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(children: [
          const Expanded(
              child: Text('My listings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          FilledButton.icon(
              onPressed: widget.onAddListing,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Listing')),
        ]),
      ),
      Expanded(
        child: _listings.isEmpty
            ? MarketplaceDataStateView(
                kind: MarketplaceDataStateKind.empty,
                icon: Icons.inventory_2_outlined,
                title: 'You have not published a listing yet',
                message:
                    'Create a Marketplace, Wanted, or approved Auction listing to begin.',
                primaryLabel: 'Add your first listing',
                primaryIcon: Icons.add,
                onPrimary: widget.onAddListing,
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: _listings.length + 1,
                itemBuilder: (_, index) {
                  if (index == _listings.length) {
                    if (_error != null) {
                      return ListTile(
                          leading: const Icon(Icons.sync_problem_outlined),
                          title:
                              const Text('More listings could not be loaded.'),
                          trailing: TextButton(
                              onPressed: () => _load(),
                              child: const Text('Retry')));
                    }
                    if (!_hasMore) {
                      return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                              child: Text('All your listings loaded.',
                                  style: TextStyle(color: Color(0xFF66758A)))));
                    }
                    return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                            child: FilledButton.tonalIcon(
                                onPressed: _loading ? null : () => _load(),
                                icon: _loading
                                    ? const SizedBox.square(
                                        dimension: 17,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.expand_more_rounded),
                                label: const Text('Load more listings'))));
                  }
                  final document = _listings[index];
                  final data = document.data();
                  final thumbnail = marketplaceListingThumbnailUrl(data);
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
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
                              auctionsEnabled: widget.auctionsEnabled,
                              paidFeaturesEnabled: widget.paidFeaturesEnabled));
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
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.inventory_2_outlined))),
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
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      _ListingNotificationBadge(listingId: document.id),
                      const Icon(Icons.chevron_right),
                    ]),
                  ));
                }),
      ),
    ]);
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
      .where('listingId', isEqualTo: listingId)
      .where('read', isEqualTo: false)
      .limit(defaultBatchMutationLimit)
      .get();
  final batch = FirebaseFirestore.instance.batch();
  for (final document in snapshot.docs) {
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
            .where('listingId', isEqualTo: listingId)
            .where('read', isEqualTo: false)
            .limit(defaultActivityFeedLimit)
            .snapshots(),
        builder: (_, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
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
    final isWanted = data['transactionType'] == 'Wanted / Seeking';
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
                        : isWanted
                            ? Icons.campaign_outlined
                            : Icons.storefront_outlined,
                    size: 17),
                label: Text(isAuction
                    ? 'TIMED AUCTION'
                    : isWanted
                        ? 'WANTED AD'
                        : 'MARKETPLACE')),
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
          if (!isAuction && !isWanted && widget.auctionsEnabled) ...[
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
          ],
          if (isAuction) ...[
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
          if (!isAuction && !isWanted) ...[
            const Text('Potential Wanted buyers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            _WantedMatchesPanel(
              listingId: widget.listingId,
              viewer: _WantedMatchViewer.seller,
            ),
            const SizedBox(height: 18),
          ],
          Text(
              isAuction
                  ? 'Bidding history'
                  : isWanted
                      ? 'Suggested Marketplace matches'
                      : 'Offer history',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          isAuction
              ? _OwnerBidHistory(listingId: widget.listingId)
              : isWanted
                  ? _WantedMatchesPanel(
                      listingId: widget.listingId,
                      viewer: _WantedMatchViewer.wantedOwner,
                    )
                  : SizedBox(
                      height: 620,
                      child: MarketplaceNegotiationHistory(
                        listingId: widget.listingId,
                        listingTitle:
                            '${data['title'] ?? 'Marketplace listing'}',
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
    final isWanted = data['transactionType'] == 'Wanted / Seeking';
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
      if (isWanted && (status == 'active' || status == 'paused'))
        FilledButton.tonalIcon(
            onPressed: busy ? null : () => _transitionListing('mark_fulfilled'),
            icon: const Icon(Icons.task_alt),
            label: const Text('Mark request fulfilled')),
      if (!isWanted && (status == 'active' || status == 'pending_sale'))
        FilledButton.tonalIcon(
            onPressed: busy ? null : () => _transitionListing('mark_sold'),
            icon: const Icon(Icons.task_alt),
            label: const Text('Mark sold')),
      if (status == 'active' ||
          status == 'paused' ||
          status == 'sold' ||
          status == 'fulfilled')
        OutlinedButton.icon(
            onPressed: busy ? null : () => _transitionListing('archive'),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive')),
      if (status == 'sold' || status == 'fulfilled' || status == 'archived')
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
                Expanded(
                    child: Text(
                        isWanted
                            ? 'Wanted request controls'
                            : 'Listing controls',
                        style: const TextStyle(fontWeight: FontWeight.w900))),
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
      PipeFeedback.show(
        context,
        message: 'Enter a title, valid price, and valid quantity.',
        tone: PipeStatusTone.warning,
      );
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
      'mark_fulfilled': 'Mark this wanted request as fulfilled?',
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
        PipeFeedback.show(
          context,
          message: success,
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(error),
          tone: PipeStatusTone.error,
        );
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
        PipeFeedback.show(
          context,
          message: 'Listing moved to Auctions.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The listing could not be moved to Auctions.',
          ),
          tone: PipeStatusTone.error,
        );
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

enum _WantedMatchViewer { wantedOwner, seller }

class _WantedMatchesPanel extends StatelessWidget {
  const _WantedMatchesPanel({required this.listingId, required this.viewer});

  final String listingId;
  final _WantedMatchViewer viewer;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('wanted_matches')
            .where(
              viewer == _WantedMatchViewer.wantedOwner
                  ? 'wantedListingId'
                  : 'supplyListingId',
              isEqualTo: listingId,
            )
            .orderBy('score', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return MarketplaceDataStateView.failure(
              error: snapshot.error,
              resource: 'Wanted matches',
              onRetry: () {},
              compact: true,
            );
          }
          if (!snapshot.hasData) {
            return const MarketplaceDataStateView.loading(
              title: 'Checking Marketplace listings',
              message: 'Comparing product details, quantity, and location…',
              compact: true,
            );
          }
          final matches = snapshot.data!.docs;
          if (matches.isEmpty) {
            return MarketplaceDataStateView(
              kind: MarketplaceDataStateKind.empty,
              icon: Icons.manage_search_outlined,
              title: viewer == _WantedMatchViewer.wantedOwner
                  ? 'No strong matches yet'
                  : 'No matching Wanted buyers yet',
              message: viewer == _WantedMatchViewer.wantedOwner
                  ? 'Your wanted ad remains active. You will be notified when a suitable listing is published.'
                  : 'This listing remains discoverable. You will be notified when a suitable Wanted Ad is published.',
              compact: true,
            );
          }
          final stateField = viewer == _WantedMatchViewer.wantedOwner
              ? 'wantedOwnerState'
              : 'sellerState';
          final active = matches
              .where((document) =>
                  '${document.data()[stateField] ?? 'suggested'}' !=
                  'dismissed')
              .toList(growable: false);
          final dismissed = matches
              .where((document) =>
                  '${document.data()[stateField] ?? 'suggested'}' ==
                  'dismissed')
              .toList(growable: false);
          return Column(children: [
            ...active.map((document) =>
                _WantedMatchCard(document: document, viewer: viewer)),
            if (dismissed.isNotEmpty)
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: Text('Dismissed matches (${dismissed.length})'),
                  subtitle: const Text('Restore a match at any time'),
                  children: dismissed
                      .map((document) => _WantedMatchCard(
                            document: document,
                            viewer: viewer,
                          ))
                      .toList(growable: false),
                ),
              ),
          ]);
        },
      );
}

class _WantedMatchCard extends StatefulWidget {
  const _WantedMatchCard({required this.document, required this.viewer});

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final _WantedMatchViewer viewer;

  @override
  State<_WantedMatchCard> createState() => _WantedMatchCardState();
}

class _WantedMatchCardState extends State<_WantedMatchCard> {
  bool _busy = false;
  final Map<String, String> _requestIds = {};

  bool get _isWantedOwner => widget.viewer == _WantedMatchViewer.wantedOwner;

  @override
  Widget build(BuildContext context) {
    final data = widget.document.data();
    final detailsKey = _isWantedOwner ? 'supply' : 'wanted';
    final details = data[detailsKey] is Map
        ? Map<String, dynamic>.from(data[detailsKey] as Map)
        : const <String, dynamic>{};
    final state =
        '${data[_isWantedOwner ? 'wantedOwnerState' : 'sellerState'] ?? 'suggested'}';
    final reasons = data['reasons'] is List
        ? List<String>.from(
            (data['reasons'] as List).map((reason) => '$reason'),
          )
        : const <String>[];
    final score = (data['score'] as num?)?.round() ?? 0;
    final targetListingId =
        '${data[_isWantedOwner ? 'supplyListingId' : 'wantedListingId'] ?? ''}';
    final targetOwnerUid =
        '${data[_isWantedOwner ? 'sellerUid' : 'wantedOwnerUid'] ?? ''}';
    final thumbnail = '${details['thumbnailUrl'] ?? ''}'.trim();
    return Card(
      margin: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      color: state == 'dismissed'
          ? const Color(0xFFF2F2F2)
          : score >= 75
              ? const Color(0xFFE8F7F1)
              : const Color(0xFFF3F8FD),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundImage:
                    thumbnail.isEmpty ? null : NetworkImage(thumbnail),
                child: thumbnail.isEmpty
                    ? const Icon(Icons.auto_awesome_outlined)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${details['title'] ?? (_isWantedOwner ? 'Marketplace listing' : 'Wanted Ad')}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${details['productType'] ?? details['category'] ?? ''}',
                      style: const TextStyle(color: Color(0xFF66758A)),
                    ),
                  ],
                ),
              ),
              Chip(
                avatar: const Icon(Icons.analytics_outlined, size: 16),
                label: Text('$score% match'),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (details['price'] is num)
                Chip(
                  avatar: const Icon(Icons.payments_outlined, size: 16),
                  label: Text(marketplaceMoney(details['price'] as num)),
                ),
              if ('${details['quantity'] ?? ''}'.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.numbers_outlined, size: 16),
                  label: Text('${details['quantity']} units'),
                ),
              if ('${details['publicLocationName'] ?? ''}'.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.location_on_outlined, size: 16),
                  label: Text('${details['publicLocationName']}'),
                ),
              Chip(
                avatar: Icon(
                  state == 'contacted'
                      ? Icons.forum_outlined
                      : state == 'dismissed'
                          ? Icons.visibility_off_outlined
                          : Icons.auto_awesome_outlined,
                  size: 16,
                ),
                label: Text(state.replaceAll('_', ' ')),
              ),
            ]),
            if (reasons.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                reasons.take(3).join(' • '),
                style: const TextStyle(fontSize: 12, color: Color(0xFF52657A)),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (state != 'dismissed')
                FilledButton.icon(
                  onPressed:
                      _busy || targetListingId.isEmpty || targetOwnerUid.isEmpty
                          ? null
                          : () => _contact(
                                targetListingId,
                                targetOwnerUid,
                                '${details['title'] ?? 'Marketplace listing'}',
                                alreadyContacted: state == 'contacted',
                              ),
                  icon: const Icon(Icons.forum_outlined),
                  label: Text(state == 'contacted'
                      ? 'Open conversation'
                      : _isWantedOwner
                          ? 'Contact seller'
                          : 'Contact buyer'),
                ),
              if (state == 'dismissed')
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _manage('restore'),
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _manage('dismiss'),
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: const Text('Dismiss'),
                ),
              TextButton.icon(
                onPressed: _busy ? null : _showHistory,
                icon: const Icon(Icons.history),
                label: const Text('Activity'),
              ),
              TextButton.icon(
                onPressed: targetListingId.isEmpty
                    ? null
                    : () => context.push(
                          MarketplaceDeepLinks.listing(targetListingId),
                        ),
                icon: const Icon(Icons.open_in_new_outlined),
                label: Text(_isWantedOwner ? 'View listing' : 'View request'),
              ),
            ]),
            if (_busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  String _requestId(String action) => _requestIds.putIfAbsent(
      action,
      () => FirebaseFirestore.instance.collection('command_ids').doc().id);

  Future<void> _manage(String action) async {
    setState(() => _busy = true);
    try {
      await MarketplaceCommandClient().execute('manageWantedMatch', {
        'requestId': _requestId(action),
        'matchId': widget.document.id,
        'action': action,
      });
      _requestIds.remove(action);
      if (mounted) {
        PipeFeedback.show(
          context,
          message: action == 'dismiss'
              ? 'Match moved to Dismissed.'
              : 'Match restored.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(error),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _contact(
    String listingId,
    String ownerUid,
    String title, {
    required bool alreadyContacted,
  }) async {
    setState(() => _busy = true);
    try {
      final conversationId =
          await MarketplaceActionsRepository().ensureConversation(
        listingId: listingId,
        listingTitle: title,
        sellerUid: ownerUid,
        sellerName: 'Marketplace member',
      );
      if (!alreadyContacted) {
        await MarketplaceCommandClient().execute('manageWantedMatch', {
          'requestId': _requestId('mark_contacted'),
          'matchId': widget.document.id,
          'action': 'mark_contacted',
        });
        _requestIds.remove('mark_contacted');
      }
      if (mounted) {
        await context.push(MarketplaceDeepLinks.conversation(conversationId));
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The conversation could not be opened. Try again.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showHistory() async {
    try {
      final events = await widget.document.reference
          .collection('events')
          .orderBy('revision', descending: true)
          .limit(50)
          .get();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text('Match activity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (events.docs.isEmpty)
                const ListTile(
                  leading: Icon(Icons.auto_awesome_outlined),
                  title: Text('Match suggested'),
                  subtitle: Text('No participant actions yet.'),
                )
              else
                ...events.docs.map((event) {
                  final data = event.data();
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text('${data['action'] ?? 'Match updated'}'
                        .replaceAll('_', ' ')),
                    subtitle: Text(
                      '${data['actorRole'] ?? 'participant'} • ${data['state'] ?? ''}',
                    ),
                    trailing: Text('#${data['revision'] ?? ''}'),
                  );
                }),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'Match activity could not be loaded. Try again.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    }
  }
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
              .orderBy('createdAt', descending: true)
              .limit(defaultActivityFeedLimit)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const MarketplaceDataStateView(
                kind: MarketplaceDataStateKind.error,
                title: 'Bid history could not be loaded',
                message:
                    'The auction was not changed. Bid history will reconnect automatically.',
                compact: true,
              );
            }
            if (!snapshot.hasData) {
              return const MarketplaceDataStateView.loading(
                title: 'Loading bid history',
                message: 'Retrieving the latest auction bids…',
                compact: true,
              );
            }
            final bids = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final at = a.data()['createdAt'] as Timestamp?;
                final bt = b.data()['createdAt'] as Timestamp?;
                return (bt?.millisecondsSinceEpoch ?? 0)
                    .compareTo(at?.millisecondsSinceEpoch ?? 0);
              });
            if (bids.isEmpty) return const Text('No bids received yet.');
            return Column(children: [
              if (bids.length == defaultActivityFeedLimit)
                const ListTile(
                  dense: true,
                  leading: Icon(Icons.info_outline),
                  title: Text('Showing the latest 100 bids'),
                  subtitle:
                      Text('Older bids remain stored in the auction record.'),
                ),
              ...bids.map((bid) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const CircleAvatar(child: Icon(Icons.gavel, size: 18)),
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
            ]);
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

class _AccountNotifications extends StatefulWidget {
  const _AccountNotifications(
      {required this.onOpenTab, required this.onBrowse});
  final ValueChanged<int> onOpenTab;
  final VoidCallback onBrowse;

  @override
  State<_AccountNotifications> createState() => _AccountNotificationsState();
}

class _AccountNotificationsState extends State<_AccountNotifications> {
  MarketplaceNotificationStatus? _deviceStatus;
  bool _changing = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final status = await MarketplaceNotificationService.instance.status();
    if (mounted) setState(() => _deviceStatus = status);
  }

  Future<void> _changeDeviceNotifications() async {
    if (_changing) return;
    setState(() => _changing = true);
    try {
      final current = _deviceStatus ??
          await MarketplaceNotificationService.instance.status();
      final status = current == MarketplaceNotificationStatus.enabled
          ? await MarketplaceNotificationService.instance.disable()
          : await MarketplaceNotificationService.instance.enable();
      if (!mounted) return;
      setState(() => _deviceStatus = status);
      final message = switch (status) {
        MarketplaceNotificationStatus.enabled =>
          'Device notifications are enabled.',
        MarketplaceNotificationStatus.denied =>
          'Notifications were blocked. Allow Pipe Buyer in your device or browser settings, then try again.',
        MarketplaceNotificationStatus.missingWebConfiguration =>
          'Web notifications are not configured for this release yet.',
        MarketplaceNotificationStatus.unsupported =>
          'Device notifications are not supported on this platform.',
        _ => 'Device notifications are turned off.',
      };
      PipeFeedback.show(
        context,
        message: message,
        tone: status == MarketplaceNotificationStatus.enabled
            ? PipeStatusTone.success
            : status == MarketplaceNotificationStatus.notEnabled
                ? PipeStatusTone.info
                : PipeStatusTone.warning,
      );
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback:
                'Device notifications could not be updated. Check your connection and try again.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const MarketplaceAuthRequiredCard(
        title: 'Notifications & Alerts',
        description:
            'Sign in to receive instant price drop alerts, bid updates, and buyer messages.',
      );
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Card(
          color: const Color(0xFFEAF4FD),
          child: ListTile(
            leading: Icon(_deviceStatus == MarketplaceNotificationStatus.enabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_outlined),
            title: Text(_deviceStatus == MarketplaceNotificationStatus.enabled
                ? 'Device notifications enabled'
                : 'Get important activity on this device'),
            subtitle: Text(_deviceStatus ==
                    MarketplaceNotificationStatus.missingWebConfiguration
                ? 'This web release needs its approved push key before notifications can be enabled.'
                : 'Receive offer, message, auction, Dispatch, support, and account-security updates.'),
            trailing: _changing
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : FilledButton.tonal(
                    onPressed: _changeDeviceNotifications,
                    child: Text(
                        _deviceStatus == MarketplaceNotificationStatus.enabled
                            ? 'Turn off'
                            : 'Enable'),
                  ),
          ),
        ),
      ),
      Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(defaultActivityFeedLimit)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return MarketplaceDataStateView.failure(
                    error: snapshot.error,
                    resource: 'Notifications',
                    onRetry: () => setState(() {}),
                  );
                }
                if (!snapshot.hasData) {
                  return const MarketplaceDataStateView.loading(
                    title: 'Loading notifications',
                    message: 'Retrieving your latest account activity…',
                  );
                }
                final items = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final at = a.data()['createdAt'] as Timestamp?;
                    final bt = b.data()['createdAt'] as Timestamp?;
                    return (bt?.millisecondsSinceEpoch ?? 0)
                        .compareTo(at?.millisecondsSinceEpoch ?? 0);
                  });
                if (items.isEmpty) {
                  return const MarketplaceDataStateView(
                    kind: MarketplaceDataStateKind.empty,
                    title: 'No notifications yet',
                    message:
                        'Offer, message, auction, Dispatch, support, and account-security updates will appear here.',
                    icon: Icons.notifications_none_outlined,
                  );
                }
                final atLimit = items.length == defaultActivityFeedLimit;
                return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length + (atLimit ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (atLimit && index == 0) {
                        return const Card(
                          child: ListTile(
                            leading: Icon(Icons.info_outline),
                            title: Text(
                                'Showing the 100 most recent notifications.'),
                          ),
                        );
                      }
                      final document = items[index - (atLimit ? 1 : 0)];
                      final data = document.data();
                      final unread = data['read'] != true;
                      return Card(
                          color: unread ? const Color(0xFFEAF4FD) : null,
                          child: ListTile(
                            leading: Icon(data['type'] == 'offer'
                                ? Icons.handshake_outlined
                                : Icons.chat_bubble_outline),
                            title: Text(
                                '${data['title'] ?? 'Marketplace activity'}',
                                style: TextStyle(
                                    fontWeight: unread
                                        ? FontWeight.w900
                                        : FontWeight.w600)),
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
                                widget.onOpenTab(3);
                              } else if (type == 'offer') {
                                widget.onOpenTab(2);
                              } else if (type == 'new_listing_match' ||
                                  type == 'seller_new_listing') {
                                widget.onBrowse();
                              } else if (type == 'score_change') {
                                if (context.mounted) {
                                  _showUserScore(context, widget.onOpenTab);
                                }
                              } else {
                                widget.onOpenTab(1);
                              }
                            },
                          ));
                    });
              })),
    ]);
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
            .limit(defaultActivityFeedLimit)
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

class _AccountSettings extends StatefulWidget {
  const _AccountSettings();

  @override
  State<_AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<_AccountSettings> {
  bool _exporting = false;
  bool _revoking = false;
  bool _deleting = false;

  void _notice(String message, {bool error = false}) {
    if (!mounted) return;
    PipeFeedback.show(
      context,
      message: message,
      tone: error ? PipeStatusTone.error : PipeStatusTone.success,
    );
  }

  Future<void> _exportData() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final result = await MarketplaceCommandClient().execute(
          'requestAccountDataExport', const {},
          timeout: const Duration(minutes: 2));
      final exportId = '${result['exportId'] ?? ''}';
      final fileName = '${result['fileName'] ?? 'pipe-account-export.json'}';
      if (exportId.isEmpty) {
        throw StateError('The export reference is missing.');
      }
      final chunks = await FirebaseFirestore.instance
          .collection('account_exports')
          .doc(exportId)
          .collection('chunks')
          .orderBy('index')
          .get();
      final content =
          chunks.docs.map((doc) => '${doc.data()['content'] ?? ''}').join();
      if (content.isEmpty) {
        throw StateError('The generated export was empty.');
      }
      final location = await downloadAccountExport(fileName, content);
      _notice('Your private account export was saved to $location.');
    } catch (error) {
      _notice('$error'.replaceFirst('Bad state: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _revokeSessions() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.devices_outlined, size: 34),
            title: const Text('Sign out all devices?'),
            content: const Text(
                'Your refresh sessions will be revoked, then this device will sign out. Other devices may remain active briefly until their current security token expires.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Sign out all devices')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _revoking = true);
    try {
      await MarketplaceCommandClient()
          .execute('revokeAccountSessions', const {});
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      MarketplaceNavigation.goHome(context);
    } catch (error) {
      _notice('$error'.replaceFirst('Bad state: ', ''), error: true);
      if (mounted) setState(() => _revoking = false);
    }
  }

  Future<void> _requestDeletion() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(Icons.delete_forever_outlined,
                size: 36, color: Colors.red.shade700),
            title: const Text('Schedule account deletion'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                  'Open listings, transactions, Dispatch jobs, and administrator responsibilities must be closed first. A 14-day cancellation period begins after this request.'),
              const SizedBox(height: 14),
              TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                      labelText: 'Enter DELETE MY ACCOUNT',
                      border: OutlineInputBorder())),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Keep account')),
              FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Schedule deletion')),
            ],
          ),
        ) ??
        false;
    final confirmation = controller.text.trim();
    controller.dispose();
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      final result = await MarketplaceCommandClient()
          .execute('requestAccountDeletion', {'confirmation': confirmation});
      _notice('Account deletion is scheduled for ${result['deleteAt']}.');
    } catch (error) {
      _notice('$error'.replaceFirst('Bad state: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _cancelDeletion() async {
    setState(() => _deleting = true);
    try {
      await MarketplaceCommandClient()
          .execute('cancelAccountDeletion', const {});
      _notice('Scheduled account deletion was cancelled.');
    } catch (error) {
      _notice('$error'.replaceFirst('Bad state: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

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
          leading: const Icon(Icons.account_balance_outlined, color: Color(0xFF0878E8)),
          title: const Text('Banking & Direct Payout Settings'),
          subtitle: const Text('Connect bank routing & account numbers for ACH / Wire escrow releases.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MarketplacePayoutSettingsPage()))),
      if (user.email?.toLowerCase().trim() == 'jordilwbailey@gmail.com')
        Card(
          color: Colors.purple.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.purple.shade200),
          ),
          child: ListTile(
              leading: Icon(Icons.admin_panel_settings, color: Colors.purple.shade800, size: 28),
              title: Text(
                'MASTER ADMIN PORTAL DASHBOARD',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade900),
              ),
              subtitle: const Text('Analytics, Escrow Overrides, Banking Setup, User Roles, Moderation & System Config.'),
              trailing: const Icon(Icons.chevron_right, color: Colors.purple),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MarketplaceAdminDashboard()))),
        ),
      ListTile(
          leading: const Icon(Icons.lock_reset_outlined),
          title: const Text('Send password reset email'),
          onTap: user.email == null
              ? null
              : () => FirebaseAuth.instance
                  .sendPasswordResetEmail(email: user.email!)),
      ListTile(
          leading: const Icon(Icons.support_agent_outlined),
          title: const Text('Help & Support'),
          subtitle:
              const Text('Submit a private case and review response history.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MarketplaceSupportPage()))),
      ListTile(
          leading: const Icon(Icons.policy_outlined),
          title: const Text('Policies and agreements'),
          subtitle: const Text(
              'Check current versions and review your account acceptance.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MarketplacePolicyCenterPage()))),
      const SizedBox(height: 12),
      const _WatchKeywords(),
      const SizedBox(height: 12),
      const _ModerationNoticesCard(),
      const SizedBox(height: 12),
      const _AccountDevicesCard(),
      const SizedBox(height: 12),
      Card(
          child: Column(children: [
        ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Download my account data'),
            subtitle: const Text(
                'Creates a private JSON export that expires after 7 days.'),
            trailing: _exporting
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _exporting ? null : _exportData),
        const Divider(height: 1),
        ListTile(
            leading: const Icon(Icons.devices_outlined),
            title: const Text('Sign out all devices'),
            subtitle:
                const Text('Revoke active refresh sessions for this account.'),
            trailing: _revoking
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _revoking ? null : _revokeSessions),
      ])),
      const SizedBox(height: 12),
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('account_deletion_requests')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final scheduled = data?['status'] == 'scheduled';
            return Card(
                color: Colors.red.shade50,
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.red.shade700),
                            const SizedBox(width: 10),
                            Text(
                                scheduled
                                    ? 'Deletion scheduled'
                                    : 'Delete account',
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800)),
                          ]),
                          const SizedBox(height: 6),
                          Text(scheduled
                              ? 'Your account remains available during the cancellation period.'
                              : 'Permanently remove your account after a 14-day cancellation period. Shared transaction and safety records may be retained where required.'),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                              onPressed: _deleting
                                  ? null
                                  : scheduled
                                      ? _cancelDeletion
                                      : _requestDeletion,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: scheduled
                                      ? Colors.blue.shade700
                                      : Colors.red.shade700),
                              icon: Icon(scheduled
                                  ? Icons.undo_outlined
                                  : Icons.delete_forever_outlined),
                              label: Text(scheduled
                                  ? 'Cancel scheduled deletion'
                                  : 'Schedule account deletion')),
                        ])));
          }),
      const SizedBox(height: 12),
      OutlinedButton.icon(
          onPressed: () => _signOutFromSettings(context),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out')),
    ]);
  }
}

class _ModerationNoticesCard extends StatelessWidget {
  const _ModerationNoticesCard();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('moderation_notices')
          .where('reportedUid', isEqualTo: uid)
          .orderBy('updatedAt', descending: true)
          .limit(defaultActivityFeedLimit)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading:
                  Icon(Icons.gpp_maybe_outlined, color: Colors.red.shade700),
              title: const Text('Trust & Safety notices'),
              subtitle: const Text(
                  'Safety notices are temporarily unavailable. Try again shortly.'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Card(
            child: ListTile(
              leading: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Checking Trust & Safety notices'),
            ),
          );
        }
        final notices = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTime = a.data()['updatedAt'] as Timestamp?;
            final bTime = b.data()['updatedAt'] as Timestamp?;
            return (bTime?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
          });
        if (notices.isEmpty) return const SizedBox.shrink();
        return Card(
          color: Colors.orange.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ListTile(
                leading: Icon(Icons.gpp_maybe_outlined),
                title: Text('Trust & Safety notices',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle:
                    Text('Review decisions affecting your account or content.'),
              ),
              ...notices.map((notice) {
                final data = notice.data();
                final status = '${data['status'] ?? 'reviewed'}';
                final appealAvailable = data['appealAvailable'] == true &&
                    data['appealDeadline'] is Timestamp &&
                    (data['appealDeadline'] as Timestamp)
                        .toDate()
                        .isAfter(DateTime.now());
                return Column(
                  children: [
                    const Divider(height: 1),
                    ListTile(
                      title: Text('${data['reasonLabel'] ?? 'Safety decision'}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${status.replaceAll('_', ' ')} • ${data['enforcementAction'] ?? 'none'}\n'
                        '${data['reviewReason'] ?? ''}',
                      ),
                      isThreeLine: true,
                      trailing: appealAvailable
                          ? OutlinedButton(
                              onPressed: () => _appeal(context, notice.id),
                              child: const Text('Appeal'),
                            )
                          : null,
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _appeal(BuildContext context, String reportId) async {
    final pageContext = context;
    final reason = TextEditingController();
    var submitting = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          icon: const Icon(Icons.balance_outlined, size: 36),
          title: const Text('Appeal this decision?'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Explain what was misunderstood and identify any evidence an administrator should review.'),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  enabled: !submitting,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Appeal explanation *',
                    hintText:
                        'For example: I own the original photos and can provide the source files.',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null)
                  Text(error!,
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: submitting
                  ? null
                  : () async {
                      if (reason.text.trim().length < 20) {
                        setState(() => error =
                            'Provide at least 20 characters so the appeal can be reviewed fairly.');
                        return;
                      }
                      setState(() {
                        submitting = true;
                        error = null;
                      });
                      try {
                        final requestId = FirebaseFirestore.instance
                            .collection('moderation_command_receipts')
                            .doc()
                            .id;
                        await MarketplaceCommandClient()
                            .execute('appealModerationDecision', {
                          'requestId': requestId,
                          'reportId': reportId,
                          'reason': reason.text.trim(),
                        });
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Appeal submitted for administrator review.')),
                          );
                        }
                      } catch (caught) {
                        setState(() {
                          submitting = false;
                          error = '$caught'.replaceFirst('Bad state: ', '');
                        });
                      }
                    },
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: const Text('Submit appeal'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
  }
}

class _AccountDevicesCard extends StatefulWidget {
  const _AccountDevicesCard();

  @override
  State<_AccountDevicesCard> createState() => _AccountDevicesCardState();
}

class _AccountDevicesCardState extends State<_AccountDevicesCard> {
  final _repository = MarketplaceAccountDeviceRepository();
  String? _currentDeviceId;
  Object? _registrationError;
  bool _registering = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _registering = true;
        _registrationError = null;
      });
    }
    try {
      final registered = await _repository.registerCurrentDevice();
      final current = registered ?? await _repository.currentDeviceDocumentId();
      if (mounted) setState(() => _currentDeviceId = current);
    } catch (error) {
      if (mounted) setState(() => _registrationError = error);
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(
        leading: const Icon(Icons.devices_outlined),
        title: const Text('Remembered devices'),
        subtitle: const Text(
            'App installations seen in the last 180 days. No location, IP address, or hardware fingerprint is stored.'),
        trailing: _registering
            ? const SizedBox.square(
                dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
                tooltip: 'Refresh device history',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_outlined)),
      ),
      if (!user.emailVerified)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text('Verify your email to begin protected device history.',
              style: TextStyle(color: Colors.orange)),
        )
      else if (_registrationError != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Device history could not refresh. Check your connection and try again.',
            style: TextStyle(color: Colors.red.shade700),
          ),
        ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('account_devices')
            .orderBy('lastSeenAt', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Remembered devices are temporarily unavailable.',
                  style: TextStyle(color: Colors.red.shade700)),
            );
          }
          final devices = snapshot.data?.docs ?? const [];
          if (devices.isEmpty && !_registering) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('No remembered device activity is available yet.'),
            );
          }
          return Column(
              children: devices.map((device) {
            final data = device.data();
            final current = device.id == _currentDeviceId;
            final active = data['status'] != 'revoked';
            return ListTile(
              dense: true,
              leading: Icon(_deviceIcon('${data['platform'] ?? ''}'),
                  color: active ? Colors.blue.shade700 : Colors.grey),
              title: Row(children: [
                Flexible(
                    child: Text('${data['label'] ?? 'Pipe Buyer device'}')),
                if (current) ...[
                  const SizedBox(width: 8),
                  const Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('This device')),
                ],
              ]),
              subtitle: Text(active
                  ? 'Last active ${_deviceActivity(data['lastSeenAt'])}'
                  : 'Sessions revoked ${_deviceActivity(data['revokedAt'])}'),
            );
          }).toList(growable: false));
        },
      ),
    ]));
  }
}

IconData _deviceIcon(String platform) => switch (platform) {
      'android' => Icons.phone_android_outlined,
      'ios' => Icons.phone_iphone_outlined,
      'windows' || 'macos' || 'linux' => Icons.computer_outlined,
      'web' => Icons.language_outlined,
      _ => Icons.devices_other_outlined,
    };

String _deviceActivity(Object? value) {
  if (value is! Timestamp) return 'recently';
  final difference = DateTime.now().difference(value.toDate());
  if (difference.inMinutes < 2) return 'now';
  if (difference.inHours < 1) return '${difference.inMinutes} min ago';
  if (difference.inDays < 1) return '${difference.inHours} hr ago';
  if (difference.inDays < 30) return '${difference.inDays} days ago';
  final date = value.toDate();
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
    PipeFeedback.show(
      context,
      message: 'Signed out successfully. You can sign in again from the menu.',
      tone: PipeStatusTone.success,
    );
  } catch (_) {
    if (!context.mounted) return;
    PipeFeedback.show(
      context,
      message: 'Sign out failed. Please check your connection and try again.',
      tone: PipeStatusTone.error,
    );
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
                    tooltip: 'Add listing alert',
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

class MarketplaceAuthRequiredCard extends StatelessWidget {
  const MarketplaceAuthRequiredCard({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.lock_outline_rounded,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0F172A),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF0F52BA)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: Colors.white),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MarketplaceAuthPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.login_rounded, color: Colors.white),
                  label: const Text(
                    'Sign In or Create Account',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F52BA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int calculateProfileCompletion(User? user, Map<String, dynamic> data) {
  final explicit = (data['profileCompletion'] as num?)?.toInt();
  if (explicit != null && explicit > 0) {
    return explicit.clamp(0, 100);
  }
  if (data['accountVerified'] == true) {
    return 100;
  }
  int score = 0;
  final name = (data['displayName'] ?? data['fullName'] ?? data['name'] ?? user?.displayName)?.toString().trim() ?? '';
  if (name.isNotEmpty) score += 35;

  final email = (data['email'] ?? user?.email)?.toString().trim() ?? '';
  if (email.isNotEmpty) score += 35;

  final photo = (data['photoUrl'] ?? data['avatarUrl'] ?? user?.photoURL)?.toString().trim() ?? '';
  if (photo.isNotEmpty) score += 15;

  final phone = (data['phone'] ?? data['phoneNumber'] ?? user?.phoneNumber)?.toString().trim() ?? '';
  if (phone.isNotEmpty) score += 15;

  if (score >= 70 || (name.isNotEmpty && email.isNotEmpty && (user?.emailVerified == true || data['emailOwnershipVerified'] == true))) {
    score = 100;
  } else if (score == 0 && (user?.email != null || user?.displayName != null)) {
    score = 100;
  }

  return score.clamp(0, 100);
}

