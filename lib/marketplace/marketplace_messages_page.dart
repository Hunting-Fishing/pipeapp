import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../core/accessibility/pipe_status_feedback.dart';
import '../core/config/phase1_feature_flags.dart';
import '../core/data/bounded_firestore_query.dart';
import '../core/design/pipe_buyer_deal_room_components.dart';
import '../core/diagnostics/app_diagnostics.dart';
import 'marketplace_reporting.dart';

import 'marketplace_actions_repository.dart';
import 'marketplace_command_client.dart';
import 'marketplace_navigation.dart';
import 'marketplace_avatar_image.dart';
import 'marketplace_offer_schedule.dart';
import 'marketplace_offer_analysis.dart';
import 'marketplace_account_hub.dart';
import 'marketplace_trucking_plan.dart';
import 'marketplace_location.dart';
import 'marketplace_deep_links.dart';
import 'marketplace_data_state.dart';
import 'marketplace_journey_status.dart';
import 'marketplace_secure_payment.dart';

String marketplaceConversationParticipantName(
  Map<String, dynamic> conversation,
  String viewerUid,
) {
  final viewerIsSeller = viewerUid == '${conversation['sellerUid'] ?? ''}';
  final candidates = viewerIsSeller
      ? [conversation['buyerDisplayName'], conversation['requesterDisplayName']]
      : [conversation['sellerName']];
  for (final candidate in candidates) {
    final name = '${candidate ?? ''}'.trim();
    if (name.isNotEmpty) return name;
  }
  return viewerIsSeller ? 'Marketplace buyer' : 'Marketplace seller';
}

String marketplaceMessageTimestamp(
  BuildContext context,
  DateTime? value, {
  DateTime? now,
  bool includeTimeOnOlderDays = true,
}) {
  if (value == null) return '';
  final local = value.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final localizations = MaterialLocalizations.of(context);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local));
  final sameDay = local.year == current.year &&
      local.month == current.month &&
      local.day == current.day;
  if (sameDay) return time;
  final date = localizations.formatShortDate(local);
  return includeTimeOnOlderDays ? '$date • $time' : date;
}

class MarketplaceMessagesPage extends StatefulWidget {
  const MarketplaceMessagesPage({super.key});

  static Stream<int> unreadCountStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('conversations')
        .where('memberUids', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(defaultActivityFeedLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.fold<int>(0, (total, doc) {
            final counts = doc.data()['unreadCounts'] as Map? ?? {};
            return total + ((counts[uid] as num?)?.toInt() ?? 0);
          }),
        );
  }

  static Stream<int> accountNotificationCountStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .limit(defaultActivityFeedLimit)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  State<MarketplaceMessagesPage> createState() =>
      _MarketplaceMessagesPageState();
}

class _MarketplaceMessagesPageState extends State<MarketplaceMessagesPage> {
  bool _showUnreadOnly = false;

  Widget _header() => PipeBuyerConversationHeader(
        title: 'Messages',
        subtitle: 'Protected marketplace conversations and deal activity',
        avatar: const Icon(Icons.forum_outlined),
        actions: [
          FilterChip(
            selected: _showUnreadOnly,
            label: const Text('Unread'),
            avatar: const Icon(Icons.mark_chat_unread_outlined, size: 18),
            onSelected: (selected) =>
                setState(() => _showUnreadOnly = selected),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _SignedOutMessages();
    return _MarketplaceConversationFeed(
      key: ValueKey(uid),
      uid: uid,
      showUnreadOnly: _showUnreadOnly,
      header: _header(),
    );
  }
}

class _MarketplaceConversationFeed extends StatefulWidget {
  const _MarketplaceConversationFeed({
    super.key,
    required this.uid,
    required this.showUnreadOnly,
    required this.header,
  });

  final String uid;
  final bool showUnreadOnly;
  final Widget header;

  @override
  State<_MarketplaceConversationFeed> createState() =>
      _MarketplaceConversationFeedState();
}

class _MarketplaceConversationFeedState
    extends State<_MarketplaceConversationFeed> {
  late final Query<Map<String, dynamic>> _conversationQuery;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _conversationsStream;
  int _conversationLimit = defaultActivityFeedLimit;

  @override
  void initState() {
    super.initState();
    _conversationQuery = FirebaseFirestore.instance
        .collection('conversations')
        .where('memberUids', arrayContains: widget.uid)
        .orderBy('lastMessageAt', descending: true);
    _conversationsStream =
        _conversationQuery.limit(_conversationLimit).snapshots();
  }

  void _loadEarlier() {
    if (_conversationLimit >= maximumActivityHistoryLimit) return;
    final nextLimit = (_conversationLimit + defaultActivityFeedLimit)
        .clamp(defaultActivityFeedLimit, maximumActivityHistoryLimit)
        .toInt();
    setState(() {
      _conversationLimit = nextLimit;
      _conversationsStream =
          _conversationQuery.limit(_conversationLimit).snapshots();
    });
  }

  Widget _historyNotice(
    int loadedCount, {
    bool unreadWindowEmpty = false,
    required bool canLoadEarlier,
  }) {
    final capped = _conversationLimit >= maximumActivityHistoryLimit;
    return _ActivityLimitNotice(
      message: unreadWindowEmpty
          ? capped
              ? 'No unread messages in the latest $loadedCount conversations. Older records remain stored.'
              : 'No unread messages in the $loadedCount conversations checked so far.'
          : capped
              ? 'Showing the latest $loadedCount conversations. Older records remain stored.'
              : 'Showing $loadedCount recent conversations.',
      actionLabel: canLoadEarlier ? 'Load earlier' : null,
      onAction: canLoadEarlier ? _loadEarlier : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _conversationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _LoadFailure(error: snapshot.error);
        if (!snapshot.hasData) {
          return const MarketplaceDataStateView.loading(
            title: 'Loading conversations',
            message: 'Retrieving your latest marketplace messages…',
          );
        }
        final loadedConversations = snapshot.data!.docs;
        final conversations = widget.showUnreadOnly
            ? loadedConversations.where((document) {
                final counts = document.data()['unreadCounts'] as Map? ?? {};
                return ((counts[widget.uid] as num?)?.toInt() ?? 0) > 0;
              }).toList()
            : loadedConversations;
        final reachedWindow = loadedConversations.length == _conversationLimit;
        final canLoadEarlier =
            reachedWindow && _conversationLimit < maximumActivityHistoryLimit;
        if (loadedConversations.isEmpty) {
          return Column(
            children: [
              widget.header,
              const Expanded(child: _EmptyMessages()),
            ],
          );
        }
        if (conversations.isEmpty) {
          return Column(
            children: [
              widget.header,
              if (reachedWindow)
                _historyNotice(
                  loadedConversations.length,
                  unreadWindowEmpty: true,
                  canLoadEarlier: canLoadEarlier,
                ),
              Expanded(
                child: MarketplaceDataStateView(
                  kind: MarketplaceDataStateKind.empty,
                  icon: Icons.mark_chat_read_outlined,
                  title: reachedWindow
                      ? 'No unread messages in the conversations checked'
                      : 'No unread messages',
                  message: reachedWindow
                      ? canLoadEarlier
                          ? 'Load earlier conversations before considering the inbox clear.'
                          : 'The latest history window is clear; older records remain stored.'
                      : 'You are all caught up.',
                ),
              ),
            ],
          );
        }
        final list = ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 5),
          itemBuilder: (context, index) {
            final doc = conversations[index];
            final data = doc.data();
            final unread = ((data['unreadCounts'] as Map?)?[widget.uid] as num?)
                    ?.toInt() ??
                0;
            final participantName =
                marketplaceConversationParticipantName(data, widget.uid);
            final lastMessageAt = data['lastMessageAt'] is Timestamp
                ? (data['lastMessageAt'] as Timestamp).toDate()
                : null;
            final memberUids = List<String>.from(
              data['memberUids'] ?? const <String>[],
            );
            final otherUid = memberUids
                    .where((member) => member != widget.uid)
                    .firstOrNull ??
                '';
            return MarketplaceConversationTile(
              participantName: participantName,
              listingTitle: '${data['listingTitle'] ?? 'Marketplace listing'}',
              lastMessage: '${data['lastMessage'] ?? ''}'.trim(),
              timestamp: marketplaceMessageTimestamp(
                context,
                lastMessageAt,
                includeTimeOnOlderDays: false,
              ),
              unread: unread,
              avatar: MarketplaceUserAvatar(
                userUid: otherUid,
                size: 44,
                fallback: Center(
                  child: Text(
                    participantName.isEmpty
                        ? '?'
                        : participantName[0].toUpperCase(),
                  ),
                ),
              ),
              onTap: () =>
                  context.push(MarketplaceDeepLinks.conversation(doc.id)),
            );
          },
        );
        return Column(
          children: [
            widget.header,
            if (reachedWindow)
              _historyNotice(
                loadedConversations.length,
                canLoadEarlier: canLoadEarlier,
              ),
            Expanded(child: list),
          ],
        );
      },
    );
  }
}

class MarketplaceConversationTile extends StatelessWidget {
  const MarketplaceConversationTile({
    super.key,
    required this.participantName,
    required this.listingTitle,
    required this.lastMessage,
    required this.timestamp,
    required this.unread,
    required this.avatar,
    required this.onTap,
  });

  final String participantName;
  final String listingTitle;
  final String lastMessage;
  final String timestamp;
  final int unread;
  final Widget avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          minVerticalPadding: 12,
          leading: avatar,
          title: Text(
            participantName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Text(
                listingTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (lastMessage.isNotEmpty)
                Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          isThreeLine: lastMessage.isNotEmpty,
          trailing: SizedBox(
            width: 76,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (timestamp.isNotEmpty)
                  Text(
                    timestamp,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 7),
                if (unread > 0)
                  Badge(label: Text('$unread'))
                else
                  const Icon(Icons.chevron_right),
              ],
            ),
          ),
          onTap: onTap,
        ),
      );
}

class _ActivityLimitNotice extends StatelessWidget {
  const _ActivityLimitNotice({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: message,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) => MarketplaceDataStateView.failure(
        error: error,
        resource: 'Conversations',
        retryLabel: 'Refresh account',
        onRetry: () async {
          await FirebaseAuth.instance.currentUser?.reload();
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text('Account refreshed. Messages will reconnect.'),
              ),
            );
          }
        },
      );
}

class _ConversationNegotiationPanel extends StatefulWidget {
  const _ConversationNegotiationPanel({
    required this.conversationId,
    this.openComposerOnLoad = false,
    this.initialOffer,
  });

  final String conversationId;
  final bool openComposerOnLoad;
  final Map<String, dynamic>? initialOffer;

  @override
  State<_ConversationNegotiationPanel> createState() =>
      _ConversationNegotiationPanelState();
}

class _ConversationNegotiationPanelState
    extends State<_ConversationNegotiationPanel> {
  final _actions = MarketplaceActionsRepository();
  final _featureRepository = Phase1FeatureFlagRepository();
  StreamSubscription<Phase1FeatureFlags>? _featureSubscription;
  Phase1FeatureFlags _features = Phase1FeatureFlags.safeDefaults;
  bool _openedInitialComposer = false;

  @override
  void initState() {
    super.initState();
    _featureSubscription = _featureRepository.watch().listen(
      (features) {
        if (mounted) setState(() => _features = features);
      },
      onError: (Object error, StackTrace stackTrace) {
        AppDiagnostics.record(
          error,
          stackTrace,
          subsystem: 'feature_flags',
          operation: 'watch_message_offer_configuration',
          fatal: false,
        );
        if (mounted) {
          setState(() => _features = Phase1FeatureFlags.safeDefaults);
        }
      },
    );
  }

  @override
  void dispose() {
    _featureSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_features.offers) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .snapshots(),
      builder: (context, conversationSnapshot) {
        final conversation = conversationSnapshot.data?.data();
        final listingId = '${conversation?['listingId'] ?? ''}';
        if (listingId.isEmpty) return const SizedBox.shrink();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('public_listings')
              .doc(listingId)
              .snapshots(),
          builder: (context, listingSnapshot) {
            final listing = listingSnapshot.data?.data() ?? {};
            final supportsPurchaseOffers =
                marketplaceListingSupportsPurchaseOffers(listing);
            if (widget.openComposerOnLoad &&
                !_openedInitialComposer &&
                supportsPurchaseOffers &&
                conversation != null &&
                listing.isNotEmpty) {
              _openedInitialComposer = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _openProposal(
                    conversation,
                    listing,
                    initialOffer: widget.initialOffer,
                  );
                }
              });
            }
            final askingPrice = listing['price'] as num?;
            final available = (listing['quantity'] as num?)?.toInt();
            final basis = '${listing['priceBasis'] ?? ''}';
            final totalPriceBasis = marketplaceUsesTotalPriceBasis(basis);
            final latest = Map<String, dynamic>.from(
              conversation?['latestNegotiation'] as Map? ?? {},
            );
            final currentPrice = totalPriceBasis
                ? latest['total'] as num? ?? askingPrice
                : latest['unitPrice'] as num? ?? askingPrice;
            final currentQuantity =
                (latest['quantity'] as num?)?.toInt() ?? available;
            return Material(
              color: const Color(0xFFF4F8FC),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      child: Icon(Icons.local_offer_outlined, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Offer',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            currentPrice == null
                                ? 'Price available on request'
                                : '\$${currentPrice.toStringAsFixed(2)}'
                                    '${basis.isEmpty ? '' : ' • $basis'}'
                                    '${currentQuantity == null ? '' : ' • Qty $currentQuantity'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 160,
                        minHeight: 50,
                      ),
                      child: FilledButton.tonalIcon(
                        onPressed: () => _openOffers(conversation!, listing),
                        icon: const Icon(Icons.handshake_outlined),
                        label: Text(
                          latest.isEmpty
                              ? supportsPurchaseOffers
                                  ? marketplaceListingUsesFirmPrice(listing)
                                      ? 'Offer asking price'
                                      : 'Make offer'
                                  : 'Offer history'
                              : 'Offers & history',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openOffers(
    Map<String, dynamic> conversation,
    Map<String, dynamic> listing,
  ) async {
    if (!_features.offers) return;
    final supportsPurchaseOffers =
        marketplaceListingSupportsPurchaseOffers(listing);
    final firmPrice = marketplaceListingUsesFirmPrice(listing);
    final sellerUid = '${conversation['sellerUid'] ?? ''}';
    final members = List<String>.from(
      conversation['memberUids'] ?? const <String>[],
    );
    final buyerUid =
        members.where((member) => member != sellerUid).firstOrNull ?? '';
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.local_offer_outlined)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offers',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text('Price and quantity history'),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close offer history',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: MarketplaceNegotiationHistory(
                    listingTitle:
                        '${conversation['listingTitle'] ?? 'Marketplace listing'}',
                    buyerUid: buyerUid,
                    sellerUid: sellerUid,
                    listingId: '${conversation['listingId']}',
                    askingPrice: listing['price'] as num?,
                    availableQuantity: (listing['quantity'] as num?)?.toInt(),
                    priceBasis: '${listing['priceBasis'] ?? ''}',
                  ),
                ),
                const SizedBox(height: 14),
                if (supportsPurchaseOffers)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, 'offer'),
                      icon: Icon(firmPrice
                          ? Icons.price_check_outlined
                          : Icons.edit_outlined),
                      label: Text(firmPrice
                          ? 'Offer at asking price'
                          : 'Make or revise offer'),
                    ),
                  )
                else
                  const Text(
                    'New purchase offers are unavailable for this listing type. Existing offer history remains read-only.',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (action == 'offer' && mounted) {
      await _openProposal(conversation, listing);
    }
  }

  Future<void> _openProposal(
    Map<String, dynamic> conversation,
    Map<String, dynamic> listing, {
    Map<String, dynamic>? initialOffer,
  }) async {
    if (!_features.offers) return;
    if (!marketplaceListingSupportsPurchaseOffers(listing)) return;
    final firmPrice = marketplaceListingUsesFirmPrice(listing);
    final latest = Map<String, dynamic>.from(
      conversation['latestNegotiation'] as Map? ?? {},
    );
    final priceBasis = '${listing['priceBasis'] ?? ''}';
    final totalPriceBasis = marketplaceUsesTotalPriceBasis(priceBasis);
    final initialPriceAmount = totalPriceBasis
        ? (initialOffer?['offeredTotal'] ??
            latest['total'] ??
            listing['price'] ??
            '')
        : (initialOffer?['offeredUnitPrice'] ??
            latest['unitPrice'] ??
            listing['price'] ??
            '');
    final price = TextEditingController(
      text: '$initialPriceAmount',
    );
    final quantity = TextEditingController(
      text:
          '${initialOffer?['requestedQuantity'] ?? latest['quantity'] ?? listing['quantity'] ?? 1}',
    );
    final note = TextEditingController();
    MarketplaceLocation? dispatchDeliveryLocation =
        marketplaceLocationFromOfferDelivery(initialOffer?['dispatchDelivery']);
    DateTime? purchaseDate = _currentOrFutureOfferDate(
      initialOffer?['purchaseDate'],
    );
    DateTime? moneyTransferDate = _currentOrFutureOfferDate(
      initialOffer?['moneyTransferDate'],
    );
    DateTime? truckingDate = _currentOrFutureOfferDate(
      initialOffer?['truckingDate'],
    );
    MarketplaceTruckingPlan? truckingPlan = marketplaceTruckingPlanFromStorage(
      '${initialOffer?['truckingPlan'] ?? ''}',
    );
    if (!_features.dispatch &&
        truckingPlan == MarketplaceTruckingPlan.requestDispatch) {
      truckingPlan = null;
      dispatchDeliveryLocation = null;
    }
    final formKey = GlobalKey<FormState>();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) {
          final requestedQty =
              int.tryParse(quantity.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
                  0;
          final askingUnit = listing['price'] as num? ?? 0;
          final available = (listing['quantity'] as num?)?.toInt();
          if (firmPrice && requestedQty > 0 && available != null) {
            final firmAmount = marketplaceFirmOfferAmount(
              askingPrice: askingUnit,
              listedQuantity: available,
              requestedQuantity: requestedQty,
              priceBasis: priceBasis,
            );
            final firmText = firmAmount.toStringAsFixed(2);
            if (price.text != firmText) price.text = firmText;
          }
          final offeredUnit = num.tryParse(price.text.replaceAll(',', '')) ?? 0;
          final analysis = MarketplaceOfferAnalysis(
            listedQuantity: available ?? (requestedQty > 0 ? requestedQty : 1),
            requestedQuantity: requestedQty,
            askingUnitPrice: askingUnit,
            offeredUnitPrice: offeredUnit,
            priceBasis: priceBasis,
          );
          final askingTotal = analysis.requestedAskValue;
          final offeredTotal = analysis.offeredTotal;
          final difference = offeredTotal - askingTotal;
          final percent = askingTotal == 0 ? 0 : difference / askingTotal * 100;
          final isFullQuantity = available != null && requestedQty == available;
          final isOverQuantity = available != null && requestedQty > available;
          final isFullPrice = askingTotal > 0 && offeredTotal == askingTotal;
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 20,
            ),
            title: Text(
              firmPrice
                  ? 'Offer at the asking price'
                  : initialOffer == null
                      ? 'Make an offer'
                      : 'Make a counter offer',
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF4FD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              askingUnit == 0
                                  ? 'Seller price available on request'
                                  : 'Seller asks \$${askingUnit.toStringAsFixed(2)}'
                                      '${priceBasis.isEmpty ? '' : ' • $priceBasis'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (available != null)
                              Text('$available pieces available'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: quantity,
                        onChanged: (_) => refresh(() {}),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity requested',
                          hintText: 'e.g. 54',
                          helperText:
                              'Enter the number of pieces or units you want.',
                          suffixText: 'pieces',
                        ),
                        validator: (value) =>
                            (int.tryParse(value ?? '') ?? 0) <= 0
                                ? 'Enter a valid quantity'
                                : null,
                      ),
                      if (available != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ChoiceChip(
                            selected: isFullQuantity,
                            avatar: Icon(
                              isFullQuantity
                                  ? Icons.check_circle
                                  : Icons.inventory_2_outlined,
                            ),
                            label: Text(
                              isFullQuantity
                                  ? 'ALL — buying the full quantity ($available)'
                                  : 'Buy ALL $available available pieces',
                            ),
                            onSelected: (_) {
                              quantity.text = '$available';
                              refresh(() {});
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: price,
                        readOnly: firmPrice,
                        autofocus: true,
                        onChanged: (_) => refresh(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: totalPriceBasis
                              ? 'Offer total'
                              : 'Offer unit price',
                          hintText: 'e.g. 70.00',
                          prefixText: '\$ ',
                          helperText: firmPrice
                              ? 'Firm price set by the seller.'
                              : totalPriceBasis
                                  ? 'Enter the total you offer for the selected quantity.'
                                  : priceBasis.isEmpty
                                      ? 'Enter your price using the listing’s pricing unit.'
                                      : 'Price ${priceBasis.toLowerCase()}',
                        ),
                        validator: (value) =>
                            (num.tryParse(value?.replaceAll(',', '') ?? '') ??
                                        0) <=
                                    0
                                ? 'Enter a valid price'
                                : null,
                      ),
                      if (askingUnit > 0) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ChoiceChip(
                            selected: isFullPrice,
                            avatar: Icon(
                              isFullPrice
                                  ? Icons.check_circle
                                  : Icons.price_check_outlined,
                            ),
                            label: Text(
                              isFullPrice
                                  ? 'FULL ASKING PRICE'
                                  : totalPriceBasis
                                      ? 'Match prorated asking total'
                                      : 'Match asking unit price',
                            ),
                            onSelected: (_) {
                              price.text = (totalPriceBasis
                                      ? analysis.requestedAskValue
                                      : analysis.normalizedAskingUnitPrice)
                                  .toStringAsFixed(2);
                              refresh(() {});
                            },
                          ),
                        ),
                      ],
                      if (requestedQty > 0 && offeredUnit > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: difference < 0
                                ? const Color(0xFFFFF5E8)
                                : const Color(0xFFEAF8F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isOverQuantity
                                        ? Icons.error_outline
                                        : isFullQuantity
                                            ? Icons.check_circle
                                            : Icons.pie_chart_outline,
                                    size: 18,
                                    color: isOverQuantity
                                        ? Colors.red
                                        : isFullQuantity
                                            ? Colors.green.shade700
                                            : Colors.orange.shade800,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      isOverQuantity
                                          ? 'Quantity exceeds available inventory'
                                          : isFullQuantity
                                              ? 'ALL — full available quantity'
                                              : 'Partial quantity offer',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: isOverQuantity
                                            ? Colors.red
                                            : isFullQuantity
                                                ? Colors.green.shade700
                                                : Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              _chatOfferLine('Asking total', askingTotal),
                              _chatOfferLine('Offer total', offeredTotal),
                              const Divider(),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Difference',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      '${difference >= 0 ? '+' : '-'}\$${difference.abs().toStringAsFixed(2)} '
                                      '(${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%)',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: difference < 0
                                            ? Colors.deepOrange
                                            : Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: note,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Conditions or message (optional)',
                          hintText:
                              'e.g. Conditional on inspection, documents, loading or pickup access',
                        ),
                      ),
                      const SizedBox(height: 14),
                      MarketplaceTruckingPlanSelector(
                        dispatchEnabled: _features.dispatch,
                        value: truckingPlan,
                        onChanged: (value) => refresh(() {
                          truckingPlan = value;
                          if (value !=
                              MarketplaceTruckingPlan.requestDispatch) {
                            dispatchDeliveryLocation = null;
                          }
                        }),
                      ),
                      if (truckingPlan ==
                          MarketplaceTruckingPlan.requestDispatch) ...[
                        const SizedBox(height: 4),
                        MarketplaceDeliveryLocationSelector(
                          value: dispatchDeliveryLocation,
                          onChanged: (value) =>
                              refresh(() => dispatchDeliveryLocation = value),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Proposed dates',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Add dates that matter to this purchase. A trucking date is required when requesting Dispatch.',
                          style: TextStyle(
                            color: Color(0xFF66758A),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _offerDateTile(
                        label: 'Purchase date',
                        icon: Icons.event_available_outlined,
                        value: purchaseDate,
                        onTap: () async {
                          final selected = await _pickOfferDate(
                            dialogContext,
                            purchaseDate,
                          );
                          if (selected != null) {
                            purchaseDate = selected;
                            refresh(() {});
                          }
                        },
                      ),
                      _offerDateTile(
                        label: 'Money transfer date',
                        icon: Icons.account_balance_outlined,
                        value: moneyTransferDate,
                        onTap: () async {
                          final selected = await _pickOfferDate(
                            dialogContext,
                            moneyTransferDate,
                          );
                          if (selected != null) {
                            moneyTransferDate = selected;
                            refresh(() {});
                          }
                        },
                      ),
                      _offerDateTile(
                        label: 'Trucking / pickup date',
                        icon: Icons.local_shipping_outlined,
                        value: truckingDate,
                        onTap: () async {
                          final selected = await _pickOfferDate(
                            dialogContext,
                            truckingDate,
                          );
                          if (selected != null) {
                            truckingDate = selected;
                            refresh(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'This offer will be added to the shared offer history.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: requestedQty <= 0 ||
                        offeredUnit <= 0 ||
                        isOverQuantity ||
                        truckingPlan == null ||
                        (truckingPlan ==
                                MarketplaceTruckingPlan.requestDispatch &&
                            (dispatchDeliveryLocation == null ||
                                truckingDate == null))
                    ? null
                    : () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(dialogContext, true);
                        }
                      },
                child: Text(
                  initialOffer == null
                      ? 'Review offer'
                      : 'Review counter offer',
                ),
              ),
            ],
          );
        },
      ),
    );
    if (submitted != true || !mounted) {
      price.dispose();
      quantity.dispose();
      note.dispose();
      return;
    }
    final enteredOfferAmount = num.parse(price.text.replaceAll(',', ''));
    final requestedQuantity = int.parse(quantity.text);
    final askingUnit = listing['price'] as num? ?? 0;
    final available = (listing['quantity'] as num?)?.toInt();
    final reviewAnalysis = MarketplaceOfferAnalysis(
      listedQuantity: available ?? requestedQuantity,
      requestedQuantity: requestedQuantity,
      askingUnitPrice: askingUnit,
      offeredUnitPrice: enteredOfferAmount,
      priceBasis: priceBasis,
    );
    final difference = reviewAnalysis.requestedValueDifference;
    final differencePercent = reviewAnalysis.requestedAskValue == 0
        ? 0
        : difference / reviewAnalysis.requestedAskValue * 100;
    final isAll = available != null && requestedQuantity == available;
    final isFullPrice = reviewAnalysis.requestedAskValue > 0 &&
        reviewAnalysis.offeredTotal == reviewAnalysis.requestedAskValue;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (confirmationContext) => AlertDialog(
            icon: const Icon(Icons.analytics_outlined, size: 38),
            title: Text(
              initialOffer == null
                  ? 'Review and send offer'
                  : 'Review counter offer',
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _offerReviewCard(
                      icon:
                          isAll ? Icons.check_circle : Icons.pie_chart_outline,
                      color: isAll ? Colors.green : Colors.orange,
                      title: isAll
                          ? 'ALL — full available quantity'
                          : 'Partial quantity',
                      detail: available == null
                          ? '$requestedQuantity units'
                          : '$requestedQuantity of $available units',
                    ),
                    const SizedBox(height: 8),
                    _offerReviewCard(
                      icon: isFullPrice
                          ? Icons.check_circle
                          : difference < 0
                              ? Icons.trending_down
                              : Icons.trending_up,
                      color: isFullPrice
                          ? Colors.green
                          : difference < 0
                              ? Colors.deepOrange
                              : Colors.green,
                      title: isFullPrice
                          ? 'FULL ASKING PRICE'
                          : difference < 0
                              ? 'Below asking price'
                              : 'Above asking price',
                      detail: totalPriceBasis
                          ? '\$${enteredOfferAmount.toStringAsFixed(2)} total for selected quantity • '
                              '${difference >= 0 ? '+' : '-'}\$${difference.abs().toStringAsFixed(2)} '
                              '(${differencePercent >= 0 ? '+' : ''}${differencePercent.toStringAsFixed(1)}%)'
                          : '\$${enteredOfferAmount.toStringAsFixed(2)} per unit • '
                              '${difference >= 0 ? '+' : '-'}\$${difference.abs().toStringAsFixed(2)} '
                              '(${differencePercent >= 0 ? '+' : ''}${differencePercent.toStringAsFixed(1)}%)',
                    ),
                    const SizedBox(height: 12),
                    _chatOfferLine(
                      'Offer total',
                      reviewAnalysis.offeredTotal,
                    ),
                    const Divider(),
                    if (purchaseDate != null)
                      _reviewDate('Purchase', purchaseDate!),
                    if (moneyTransferDate != null)
                      _reviewDate('Money transfer', moneyTransferDate!),
                    if (truckingDate != null)
                      _reviewDate('Trucking / pickup', truckingDate!),
                    const SizedBox(height: 8),
                    _offerReviewCard(
                      icon: truckingPlan!.icon,
                      color: truckingPlan ==
                              MarketplaceTruckingPlan.requestDispatch
                          ? const Color(0xFF0878E8)
                          : Colors.blueGrey,
                      title: truckingPlan!.label,
                      detail: truckingPlan ==
                              MarketplaceTruckingPlan.requestDispatch
                          ? 'Dispatch destination: ${dispatchDeliveryLocation!.publicName}'
                          : truckingPlan!.description,
                    ),
                    if (purchaseDate == null &&
                        moneyTransferDate == null &&
                        truckingDate == null)
                      const Text(
                        'No dates proposed',
                        style: TextStyle(color: Colors.black54),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'The other party will see this offer immediately.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(confirmationContext, false),
                child: const Text('Go back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(confirmationContext, true),
                child: Text(
                  initialOffer == null ? 'Send proposal' : 'Send counter offer',
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      try {
        await _actions.makeConversationOffer(
          conversationId: widget.conversationId,
          listingId: '${conversation['listingId']}',
          sellerUid: '${conversation['sellerUid']}',
          unitPrice: enteredOfferAmount,
          quantity: requestedQuantity,
          priceBasis: '${listing['priceBasis'] ?? ''}',
          note: note.text,
          purchaseDate: purchaseDate,
          moneyTransferDate: moneyTransferDate,
          truckingDate: truckingDate,
          truckingPlan: truckingPlan!.storageValue,
          dispatchDelivery: dispatchDeliveryLocation?.publicName.trim() ?? '',
          dispatchDeliveryLocation: dispatchDeliveryLocation,
        );
        if (mounted) {
          PipeFeedback.show(
            context,
            message: truckingPlan == MarketplaceTruckingPlan.requestDispatch
                ? 'Offer submitted. Dispatch request is live for carrier bids.'
                : initialOffer == null
                    ? 'Offer submitted and added to offer history.'
                    : 'Counter offer sent and added to offer history.',
            tone: PipeStatusTone.success,
          );
        }
      } catch (error) {
        if (mounted) {
          PipeFeedback.show(
            context,
            message: marketplaceCommandErrorMessage(
              error,
              fallback: 'The proposal could not be sent. Try again.',
            ),
            tone: PipeStatusTone.error,
          );
        }
      }
    }
    price.dispose();
    quantity.dispose();
    note.dispose();
  }

  Widget _chatOfferLine(String label, num amount) => Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 10),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      );

  Widget _offerDateTile({
    required String label,
    required IconData icon,
    required DateTime? value,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            alignment: Alignment.centerLeft,
          ),
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(
            value == null
                ? 'Select $label'
                : '$label: ${_formatOfferDate(value)}',
          ),
        ),
      );

  Future<DateTime?> _pickOfferDate(BuildContext context, DateTime? current) =>
      showDatePicker(
        context: context,
        initialDate: current ?? DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 730)),
      );

  String _formatOfferDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime? _currentOrFutureOfferDate(dynamic value) {
    final date = marketplaceOfferDate(value);
    if (date == null) return null;
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final candidate = DateTime(date.year, date.month, date.day);
    return candidate.isBefore(startOfToday) ? null : candidate;
  }

  Widget _offerReviewCard({
    required IconData icon,
    required Color color,
    required String title,
    required String detail,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w900, color: color),
                  ),
                  Text(detail),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _reviewDate(String label, DateTime date) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 18),
            const SizedBox(width: 7),
            Expanded(child: Text('$label: ${_formatOfferDate(date)}')),
          ],
        ),
      );
}

class MarketplaceNegotiationHistory extends StatelessWidget {
  const MarketplaceNegotiationHistory({
    super.key,
    required this.listingId,
    required this.listingTitle,
    required this.buyerUid,
    required this.sellerUid,
    this.askingPrice,
    this.availableQuantity,
    this.priceBasis = '',
  });
  final String listingId;
  final String listingTitle;
  final String buyerUid;
  final String sellerUid;
  final num? askingPrice;
  final int? availableQuantity;
  final String priceBasis;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final isSeller = uid == sellerUid;
    final roleField = isSeller ? 'sellerUid' : 'buyerUid';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('listingId', isEqualTo: listingId)
          .where(roleField, isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(defaultActivityFeedLimit)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const MarketplaceDataStateView(
            kind: MarketplaceDataStateKind.error,
            title: 'Offers could not be loaded',
            message:
                'The offer history was not changed. This panel will reconnect automatically.',
            compact: true,
          );
        }
        if (!snapshot.hasData) {
          return const MarketplaceDataStateView.loading(
            title: 'Loading offers',
            message: 'Retrieving current offers and revision history…',
            compact: true,
          );
        }
        final events = snapshot.data!.docs
            .where(
              (doc) =>
                  (isSeller || doc.data()['buyerUid'] == buyerUid) &&
                  doc.data()['sellerUid'] == sellerUid &&
                  doc.data()['status'] != 'archived',
            )
            .toList()
          ..sort((a, b) {
            final at = a.data()['createdAt'] as Timestamp?;
            final bt = b.data()['createdAt'] as Timestamp?;
            return (bt?.millisecondsSinceEpoch ?? 0).compareTo(
              at?.millisecondsSinceEpoch ?? 0,
            );
          });
        if (events.isEmpty) {
          final totalPriceBasis = marketplaceUsesTotalPriceBasis(priceBasis);
          return Center(
            child: Text(
              'Seller asks ${askingPrice == null ? 'contact for price' : '\$${askingPrice!.toStringAsFixed(2)}'}'
              '${totalPriceBasis ? ' total' : ''}'
              '${availableQuantity == null ? '' : ' for up to $availableQuantity units'}.\n'
              'No offers have been submitted yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          );
        }
        final revisionsByBuyer =
            <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        for (final event in events) {
          final buyer = '${event.data()['buyerUid'] ?? ''}';
          revisionsByBuyer.putIfAbsent(buyer, () => []).add(event);
        }
        final displayed = isSeller
            ? revisionsByBuyer.values.map((history) => history.first).toList()
            : events;
        final bestTotal = displayed.fold<num>(
          0,
          (best, event) => (event.data()['offeredTotal'] as num? ?? 0) > best
              ? event.data()['offeredTotal'] as num
              : best,
        );
        return Column(
          children: [
            if (snapshot.data!.docs.length == defaultActivityFeedLimit)
              const ListTile(
                dense: true,
                leading: Icon(Icons.info_outline),
                title: Text('Showing the latest 100 offer updates'),
                subtitle: Text(
                  'Older revisions remain in the authoritative transaction history.',
                ),
              ),
            if (isSeller)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      color: Color(0xFF0878E8),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${revisionsByBuyer.length} buyer${revisionsByBuyer.length == 1 ? '' : 's'} • '
                        '${events.length} total offer${events.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      'Best \$${bestTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: displayed.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final document = displayed[index];
                  final event = document.data();
                  final buyer = '${event['buyerUid'] ?? ''}';
                  return _offerCard(
                    event,
                    context: context,
                    offerId: document.id,
                    isSeller: isSeller,
                    isBest: (event['offeredTotal'] as num? ?? 0) == bestTotal,
                    revisions: revisionsByBuyer[buyer] ?? const [],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _offerCard(
    Map<String, dynamic> event, {
    required BuildContext context,
    required String offerId,
    required bool isSeller,
    required bool isBest,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> revisions,
  }) {
    final price = event['offeredUnitPrice'] as num? ?? 0;
    final quantity = (event['requestedQuantity'] as num?)?.toInt() ?? 0;
    final total = event['offeredTotal'] as num? ?? price * quantity;
    final totalPriceBasis = event['offerAmountType'] == 'total' ||
        marketplaceUsesTotalPriceBasis('${event['priceBasis'] ?? ''}');
    final availableAtOffer =
        (event['availableQuantityAtOffer'] as num?)?.toInt() ??
            availableQuantity;
    final isAll = availableAtOffer != null && quantity == availableAtOffer;
    final milestones = marketplaceOfferMilestones(event);
    final revisionCount = revisions.length;
    final offerStatus = '${event['status'] ?? 'pending'}';
    final hasTransaction = const {
      'accepted',
      'completed',
      'cancelled',
      'disputed',
    }.contains(offerStatus);
    final comparisonAmount = totalPriceBasis ? total : price;
    final askingComparison = totalPriceBasis
        ? event['askingTotal'] as num?
        : event['askingUnitPrice'] as num? ?? askingPrice;
    final priceDifference = event['differenceAmount'] as num? ??
        (askingComparison == null ? 0 : comparisonAmount - askingComparison);
    final quantityPercent = availableAtOffer == null || availableAtOffer == 0
        ? null
        : quantity / availableAtOffer * 100;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isBest ? const Color(0xFFEAF8F1) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBest ? Colors.green.shade400 : Colors.blueGrey.shade100,
          width: isBest ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: isSeller
                      ? () => _showOfferBuyerProfile(
                            context,
                            '${event['buyerUid'] ?? ''}',
                            '${event['buyerDisplayName'] ?? ''}',
                          )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        _BuyerOfferAvatar(
                          uid: '${event['buyerUid'] ?? ''}',
                          isBest: isBest,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: isSeller
                              ? _BuyerOfferName(
                                  uid: '${event['buyerUid'] ?? ''}',
                                  name: '${event['buyerDisplayName'] ?? ''}',
                                )
                              : const Text(
                                  'Your offer',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (offerStatus != 'pending' && offerStatus != 'archived')
                Chip(
                  avatar: Icon(
                    offerStatus == 'completed'
                        ? Icons.verified_outlined
                        : offerStatus == 'disputed'
                            ? Icons.report_problem_outlined
                            : offerStatus == 'cancelled'
                                ? Icons.cancel_outlined
                                : Icons.check_circle,
                    size: 17,
                  ),
                  label: Text(offerStatus.toUpperCase()),
                )
              else if (isBest)
                const Chip(
                  avatar: Icon(Icons.emoji_events_outlined, size: 17),
                  label: Text('BEST PRICE'),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _metric(
                  totalPriceBasis ? 'OFFER TOTAL' : 'UNIT PRICE',
                  '${priceDifference > 0 ? '↑ ' : priceDifference < 0 ? '↓ ' : '= '}\$${comparisonAmount.toStringAsFixed(2)}',
                  priceDifference > 0
                      ? Colors.green
                      : priceDifference < 0
                          ? Colors.deepOrange
                          : Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  'QUANTITY',
                  isAll
                      ? 'ALL • $quantity'
                      : availableAtOffer == null
                          ? '$quantity'
                          : '$quantity / $availableAtOffer'
                              '${quantityPercent == null ? '' : ' • ${quantityPercent.toStringAsFixed(0)}%'}',
                  isAll ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  totalPriceBasis ? 'UNIT PRICE' : 'TOTAL',
                  '\$${(totalPriceBasis ? price : total).toStringAsFixed(2)}',
                  isBest ? Colors.green : Colors.blueGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (milestones.isNotEmpty) ...[
            MarketplaceOfferScheduleCard(milestones: milestones),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if ('${event['truckingPlan'] ?? ''}'.isNotEmpty &&
                  event['truckingPlan'] != 'not_specified')
                _truckingPlanChip(event),
            ],
          ),
          if ('${event['dispatchDeliveryLabel'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: Color(0xFF0878E8),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Dispatch destination: ${event['dispatchDeliveryLabel']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF53657A),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if ('${event['note'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${event['note']}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (!hasTransaction) ...[
            const SizedBox(height: 10),
            MarketplaceJourneyStatusCard(
              status: marketplaceOfferJourneyStatus(
                status: offerStatus,
                viewerIsSeller: isSeller,
              ),
            ),
          ],
          if (hasTransaction) ...[
            const SizedBox(height: 10),
            MarketplaceTransactionPanel(
              offerId: offerId,
              offer: event,
              isSeller: isSeller,
            ),
          ],
          if (isSeller) ...[
            const Divider(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      _openBuyerConversation(context, event, offerId),
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Message buyer'),
                ),
                FilledButton.icon(
                  onPressed: offerStatus == 'pending'
                      ? () => _acceptSelectedOffer(context, offerId, event)
                      : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    offerStatus == 'pending'
                        ? 'Accept offer'
                        : offerStatus.replaceAll('_', ' '),
                  ),
                ),
              ],
            ),
            if (revisionCount > 1) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showRevisionHistory(context, revisions),
                  icon: const Icon(Icons.history),
                  label: Text('View all $revisionCount offers'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _showRevisionHistory(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> revisions,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Offer revision history'),
        content: SizedBox(
          width: 520,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: revisions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final offer = revisions[index].data();
              return _revisionAnalyticsCard(offer, index + 1);
            },
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _revisionAnalyticsCard(Map<String, dynamic> offer, int number) {
    final price = offer['offeredUnitPrice'] as num? ?? 0;
    final quantity = (offer['requestedQuantity'] as num?)?.toInt() ?? 0;
    final total = offer['offeredTotal'] as num? ?? price * quantity;
    final totalPriceBasis = offer['offerAmountType'] == 'total' ||
        marketplaceUsesTotalPriceBasis('${offer['priceBasis'] ?? ''}');
    final availableAtOffer =
        (offer['availableQuantityAtOffer'] as num?)?.toInt() ??
            availableQuantity;
    final comparisonAmount = totalPriceBasis ? total : price;
    final askingComparison = totalPriceBasis
        ? offer['askingTotal'] as num?
        : offer['askingUnitPrice'] as num? ?? askingPrice;
    final difference = offer['differenceAmount'] as num? ??
        (askingComparison == null ? 0 : comparisonAmount - askingComparison);
    final isAll = availableAtOffer != null && quantity == availableAtOffer;
    final percent = availableAtOffer == null || availableAtOffer == 0
        ? null
        : quantity / availableAtOffer * 100;
    final milestones = marketplaceOfferMilestones(offer);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 15, child: Text('$number')),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offer $number',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Chip(label: Text('${offer['status'] ?? 'pending'}')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metric(
                  totalPriceBasis ? 'OFFER TOTAL' : 'UNIT PRICE',
                  '${difference > 0 ? '↑ ' : difference < 0 ? '↓ ' : '= '}\$${comparisonAmount.toStringAsFixed(2)}',
                  difference > 0
                      ? Colors.green
                      : difference < 0
                          ? Colors.deepOrange
                          : Colors.blue,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _metric(
                  'QUANTITY',
                  isAll
                      ? 'ALL • $quantity'
                      : availableAtOffer == null
                          ? '$quantity'
                          : '$quantity / $availableAtOffer • ${percent?.toStringAsFixed(0)}%',
                  isAll ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _metric(
                  totalPriceBasis ? 'UNIT PRICE' : 'TOTAL',
                  '\$${(totalPriceBasis ? price : total).toStringAsFixed(2)}',
                  Colors.blueGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (milestones.isNotEmpty) ...[
            MarketplaceOfferScheduleCard(milestones: milestones),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if ('${offer['truckingPlan'] ?? ''}'.isNotEmpty &&
                  offer['truckingPlan'] != 'not_specified')
                _truckingPlanChip(offer),
            ],
          ),
        ],
      ),
    );
  }

  Widget _truckingPlanChip(Map<String, dynamic> offer) {
    final plan = '${offer['truckingPlan'] ?? ''}';
    final dispatch = plan == 'request_dispatch';
    final buyerArranged = plan == 'buyer_arranged';
    return Chip(
      avatar: Icon(
        dispatch
            ? Icons.route_outlined
            : buyerArranged
                ? Icons.local_shipping_outlined
                : Icons.handshake_outlined,
        size: 16,
        color: dispatch
            ? const Color(0xFF0878E8)
            : buyerArranged
                ? Colors.green.shade700
                : Colors.blueGrey,
      ),
      label: Text(
        dispatch
            ? 'Dispatch requested'
            : buyerArranged
                ? 'Buyer has trucking'
                : 'Pickup / seller-arranged',
      ),
    );
  }

  Future<void> _showOfferBuyerProfile(
    BuildContext context,
    String buyerUid,
    String storedName,
  ) async {
    final values = await Future.wait([
      FirebaseFirestore.instance
          .collection('public_business_profiles')
          .doc(buyerUid)
          .get(),
      FirebaseFirestore.instance
          .collection('public_seller_profiles')
          .doc(buyerUid)
          .get(),
    ]);
    if (!context.mounted) return;
    final business = values[0].data() ?? {};
    final personal = values[1].data() ?? {};
    final name =
        '${business['publicName'] ?? personal['displayName'] ?? storedName}'
            .trim();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.account_circle_outlined, size: 40),
        title: Text(name.isEmpty ? 'Marketplace buyer' : name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ('${business['description'] ?? personal['description'] ?? ''}'
                .isNotEmpty)
              Text('${business['description'] ?? personal['description']}'),
            if ('${business['serviceAreaLabel'] ?? personal['baseCommunity'] ?? ''}'
                .isNotEmpty)
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(
                  '${business['serviceAreaLabel'] ?? personal['baseCommunity']}',
                ),
              ),
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Direct contact details are protected'),
              subtitle: Text(
                'Use in-app messages. Eligible members can share contact details after a transaction relationship is established.',
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push(MarketplaceDeepLinks.profile(buyerUid));
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('View full profile'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openBuyerConversation(
    BuildContext context,
    Map<String, dynamic> offer,
    String offerId, {
    bool openOfferComposer = false,
  }) async {
    final buyerUid = '${offer['buyerUid'] ?? ''}';
    if (buyerUid.isEmpty) return;
    final navigator = Navigator.of(context);
    try {
      final id = await MarketplaceActionsRepository().ensureOfferConversation(
        listingId: listingId,
        listingTitle: listingTitle,
        sellerUid: sellerUid,
        buyerUid: buyerUid,
        offerId: offerId,
        buyerDisplayName: '${offer['buyerDisplayName'] ?? 'Marketplace buyer'}',
      );
      if (!context.mounted) return;
      navigator.pop();
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => MarketplaceChatPage(
            conversationId: id,
            title: listingTitle,
            participantName:
                '${offer['buyerDisplayName'] ?? 'Marketplace buyer'}',
            participantUid: buyerUid,
            openOfferComposer: openOfferComposer,
            initialOffer: openOfferComposer ? offer : null,
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The buyer conversation could not be opened.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    }
  }

  Future<void> _acceptSelectedOffer(
    BuildContext context,
    String offerId,
    Map<String, dynamic> offer,
  ) async {
    final decision = await showDialog<MarketplaceOfferDecision>(
      context: context,
      builder: (_) => MarketplaceAcceptOfferDialog(offer: offer),
    );
    if (!context.mounted) return;
    if (decision == MarketplaceOfferDecision.counter) {
      await _openBuyerConversation(
        context,
        offer,
        offerId,
        openOfferComposer: true,
      );
      return;
    }
    if (decision != MarketplaceOfferDecision.accept) return;
    try {
      await MarketplaceActionsRepository().acceptOffer(offerId);
      if (context.mounted) {
        PipeFeedback.show(
          context,
          message: 'Offer accepted. Other offers were archived.',
          tone: PipeStatusTone.success,
        );
        await _openBuyerConversation(context, offer, offerId);
      }
    } catch (error) {
      if (context.mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The offer could not be accepted. Nothing was changed.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    }
  }

  Widget _metric(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
}

class MarketplaceTransactionPanel extends StatefulWidget {
  const MarketplaceTransactionPanel({
    super.key,
    required this.offerId,
    required this.offer,
    required this.isSeller,
  });

  final String offerId;
  final Map<String, dynamic> offer;
  final bool isSeller;

  @override
  State<MarketplaceTransactionPanel> createState() =>
      _MarketplaceTransactionPanelState();
}

class _MarketplaceTransactionPanelState
    extends State<MarketplaceTransactionPanel> {
  bool _busy = false;

  @override
  Widget build(
    BuildContext context,
  ) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('marketplace_transactions')
            .doc(widget.offerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _notice(
              Icons.sync_problem_outlined,
              'Transaction details could not be loaded. Your offer was not changed.',
              Colors.red,
            );
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator(minHeight: 3);
          }
          final transaction = snapshot.data!.data() ??
              <String, dynamic>{
                'status': 'pending_completion',
                'buyerConfirmed': false,
                'sellerConfirmed': false,
              };
          final status = '${transaction['status'] ?? 'pending_completion'}';
          final buyerConfirmed = transaction['buyerConfirmed'] == true;
          final sellerConfirmed = transaction['sellerConfirmed'] == true;
          final terminal = const {
            'completed',
            'cancelled',
            'disputed',
          }.contains(status);
          final userConfirmed =
              widget.isSeller ? sellerConfirmed : buyerConfirmed;
          final paymentStatus =
              '${transaction['paymentProviderStatus'] ?? 'not_started'}';
          final paymentReadyForCompletion =
              paymentStatus == 'paid' || paymentStatus == 'external_agreed';
          final dispatchRequested =
              '${widget.offer['truckingPlan'] ?? ''}' == 'request_dispatch';
          final journeyStatus = marketplaceTransactionJourneyStatus(
            transaction,
            viewerIsBuyer: !widget.isSeller,
            dispatchRequested: dispatchRequested,
          );
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _statusColor(status).withValues(alpha: .55),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.fact_check_outlined,
                        color: _statusColor(status)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Transaction checklist',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Chip(label: Text(_statusLabel(status))),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${_money(transaction['agreedTotal'] ?? widget.offer['offeredTotal'])} • '
                  '${transaction['agreedQuantity'] ?? widget.offer['requestedQuantity'] ?? 0} units',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                MarketplaceJourneyStatusCard(status: journeyStatus),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _confirmation(
                        'Buyer',
                        buyerConfirmed,
                        'Purchase received',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _confirmation(
                        'Seller',
                        sellerConfirmed,
                        'Sale fulfilled',
                      ),
                    ),
                  ],
                ),
                if ('${transaction['reason'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    'Reason: ${transaction['reason']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                MarketplaceSecurePaymentPanel(
                  transactionId: widget.offerId,
                  isBuyer: !widget.isSeller,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (!terminal &&
                        !userConfirmed &&
                        paymentReadyForCompletion)
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _confirmCompletion(transaction),
                        icon: const Icon(Icons.verified_outlined),
                        label: Text(
                          widget.isSeller
                              ? 'Confirm fulfilled'
                              : 'Confirm received',
                        ),
                      ),
                    if (status == 'completed' && dispatchRequested)
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            MarketplaceNavigation.goToDispatch(context),
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: const Text('Continue to Dispatch'),
                      ),
                    if (!terminal && !buyerConfirmed && !sellerConfirmed)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _reasonAction('cancel'),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel'),
                      ),
                    if (!terminal)
                      OutlinedButton.icon(
                        onPressed:
                            _busy ? null : () => _reasonAction('dispute'),
                        icon: const Icon(Icons.report_problem_outlined),
                        label: const Text('Open dispute'),
                      ),
                    TextButton.icon(
                      onPressed: snapshot.data!.exists ? _showHistory : null,
                      icon: const Icon(Icons.history),
                      label: const Text('History'),
                    ),
                  ],
                ),
                if (_busy) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 3),
                ],
                const SizedBox(height: 6),
                Text(
                  paymentReadyForCompletion
                      ? 'For Pipe Buyer Stripe payments, seller proceeds remain pending until completion is confirmed. Pipe Buyer is not an escrow or trust account.'
                      : 'Secure payment is required before completion can be confirmed. Deposit/split payments are not enabled yet.',
                  style: const TextStyle(fontSize: 10.5, color: Colors.black54),
                ),
              ],
            ),
          );
        },
      );

  Widget _confirmation(String party, bool confirmed, String detail) =>
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: confirmed ? const Color(0xFFE8F7ED) : Colors.white,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(
              confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 19,
              color: confirmed ? Colors.green : Colors.blueGrey,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    party,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    confirmed ? detail : 'Awaiting confirmation',
                    style: const TextStyle(fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _notice(IconData icon, String message, Color color) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      );

  Future<void> _confirmCompletion(Map<String, dynamic> transaction) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.verified_outlined, size: 38),
            title: Text(
              widget.isSeller
                  ? 'Confirm the sale was fulfilled?'
                  : 'Confirm the purchase was received?',
            ),
            content: const Text(
              'Both parties must confirm before the listing is marked sold and the transaction is completed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Go back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await _runAction('confirm_completion');
  }

  Future<void> _reasonAction(String action) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          action == 'cancel'
              ? 'Cancel this transaction?'
              : 'Open a transaction dispute?',
        ),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          maxLength: action == 'cancel' ? 1000 : 2000,
          decoration: InputDecoration(
            labelText: 'Reason *',
            hintText: action == 'cancel'
                ? 'Explain why the transaction will not proceed.'
                : 'Describe what happened and what needs review.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 10) Navigator.pop(dialogContext, value);
            },
            child: Text(action == 'cancel' ? 'Cancel transaction' : 'Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null) await _runAction(action, reason: reason);
  }

  Future<void> _runAction(String action, {String reason = ''}) async {
    setState(() => _busy = true);
    try {
      await MarketplaceActionsRepository().updateMarketplaceTransaction(
        widget.offerId,
        action,
        reason: reason,
      );
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: action == 'confirm_completion'
            ? 'Your confirmation was recorded.'
            : action == 'cancel'
                ? 'The transaction was cancelled.'
                : 'The dispute was opened for review.',
        tone: PipeStatusTone.success,
      );
    } catch (error, stackTrace) {
      AppDiagnostics.record(
        error,
        stackTrace,
        subsystem: 'marketplace',
        operation: 'update_transaction_$action',
        fatal: false,
      );
      if (mounted) {
        PipeFeedback.show(
          context,
          message:
              'The transaction could not be updated. Nothing was changed. Try again.',
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showHistory() async {
    try {
      final revisions = await FirebaseFirestore.instance
          .collection('marketplace_transactions')
          .doc(widget.offerId)
          .collection('revisions')
          .orderBy('revision', descending: true)
          .limit(100)
          .get();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Transaction history'),
          content: SizedBox(
            width: 480,
            child: revisions.docs.isEmpty
                ? const Text('No transaction history is available yet.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: revisions.docs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, index) {
                      final data = revisions.docs[index].data();
                      final createdAt = data['createdAt'] as Timestamp?;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text('${data['revision'] ?? '?'}'),
                        ),
                        title: Text(
                          '${data['event'] ?? 'updated'}'.replaceAll('_', ' '),
                        ),
                        subtitle: Text(
                          [
                            if ('${data['status'] ?? ''}'.isNotEmpty)
                              '${data['status']}'.replaceAll('_', ' '),
                            if (createdAt != null)
                              _historyDate(createdAt.toDate()),
                          ].join(' • '),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'Transaction history could not be loaded.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    }
  }

  String _money(dynamic value) {
    final amount = value is num ? value : num.tryParse('$value') ?? 0;
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _historyDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  String _statusLabel(String status) => switch (status) {
        'pending_completion' => 'AWAITING BOTH',
        'awaiting_buyer_confirmation' => 'AWAITING BUYER',
        'awaiting_seller_confirmation' => 'AWAITING SELLER',
        'completed' => 'COMPLETED',
        'cancelled' => 'CANCELLED',
        'disputed' => 'DISPUTED',
        _ => status.replaceAll('_', ' ').toUpperCase(),
      };

  Color _statusColor(String status) => switch (status) {
        'completed' => Colors.green,
        'cancelled' => Colors.blueGrey,
        'disputed' => Colors.deepOrange,
        _ => const Color(0xFF0878E8),
      };
}

class _BuyerOfferName extends StatelessWidget {
  const _BuyerOfferName({required this.uid, required this.name});
  final String uid;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (name.trim().isNotEmpty) return _label(name.trim());
    return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
      future: Future.wait([
        FirebaseFirestore.instance
            .collection('public_business_profiles')
            .doc(uid)
            .get(),
        FirebaseFirestore.instance
            .collection('public_seller_profiles')
            .doc(uid)
            .get(),
      ]),
      builder: (context, snapshot) {
        final business = snapshot.data?[0].data() ?? {};
        final personal = snapshot.data?[1].data() ?? {};
        final resolved =
            '${business['publicName'] ?? personal['displayName'] ?? ''}'.trim();
        return _label(resolved.isEmpty ? 'Marketplace buyer' : resolved);
      },
    );
  }

  Widget _label(String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          const Text(
            'Current offer',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      );
}

class _BuyerOfferAvatar extends StatelessWidget {
  const _BuyerOfferAvatar({required this.uid, required this.isBest});
  final String uid;
  final bool isBest;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
        future: Future.wait([
          FirebaseFirestore.instance
              .collection('public_business_profiles')
              .doc(uid)
              .get(),
          FirebaseFirestore.instance
              .collection('public_seller_profiles')
              .doc(uid)
              .get(),
        ]),
        builder: (context, snapshot) {
          final business = snapshot.data?[0].data() ?? {};
          final personal = snapshot.data?[1].data() ?? {};
          final url =
              '${business['photoUrl'] ?? personal['photoUrl'] ?? ''}'.trim();
          return MarketplaceAvatarImage(
            photoUrl: url,
            size: 36,
            fallback: const Center(child: Icon(Icons.person_outline, size: 19)),
          );
        },
      );
}

class ListingMessageBadge extends StatelessWidget {
  const ListingMessageBadge({
    super.key,
    required this.listingId,
    required this.sellerUid,
  });
  final String listingId;
  final String sellerUid;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final conversationId = MarketplaceActionsRepository.conversationIdFor(
      uid,
      sellerUid,
      listingId,
    );
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.data() ?? {};
        final unread =
            ((data['unreadCounts'] as Map?)?[uid] as num?)?.toInt() ?? 0;
        final total = ((data['messageCount'] as num?)?.toInt() ?? 0);
        if (unread > 0) return Badge(label: Text('$unread'));
        if (total > 0) {
          return const Icon(
            Icons.chat_bubble,
            size: 17,
            color: Color(0xFF0878E8),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _SignedOutMessages extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MarketplaceAuthRequiredCard(
        title: 'Marketplace Messages',
        description:
            'Sign in or create a free account to chat directly with equipment buyers & sellers, send quotes, and negotiate deals.',
        icon: Icons.forum_outlined,
      );
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();
  @override
  Widget build(BuildContext context) => const MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.empty,
        icon: Icons.chat_bubble_outline,
        title: 'No marketplace conversations yet',
        message: 'Open a listing and message the seller to begin.',
      );
}

/// Participant-only full-page conversation destination for restored links.
class MarketplaceConversationRoutePage extends StatelessWidget {
  const MarketplaceConversationRoutePage({
    super.key,
    required this.conversationId,
  });

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Marketplace conversation')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Sign in to open this conversation'),
          ),
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ConversationRouteFailure(
            message:
                'This conversation could not be loaded. Check your account and connection.',
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: MarketplaceDataStateView.loading(
              title: 'Opening conversation',
              message: 'Confirming your access and loading messages…',
            ),
          );
        }
        final document = snapshot.data;
        final data = document?.data();
        final members = List<String>.from(
          data?['memberUids'] as List? ?? const <String>[],
        );
        if (document == null ||
            !document.exists ||
            !members.contains(user.uid)) {
          return const _ConversationRouteFailure(
            message:
                'This conversation is unavailable or your account is not a participant.',
          );
        }
        final title = '${data?['listingTitle'] ?? 'Marketplace conversation'}';
        final otherUid =
            members.where((member) => member != user.uid).firstOrNull ?? '';
        final participantName = marketplaceConversationParticipantName(
          data ?? const <String, dynamic>{},
          user.uid,
        );
        return MarketplaceChatPage(
          conversationId: conversationId,
          title: title,
          participantName: participantName,
          participantUid: otherUid,
        );
      },
    );
  }
}

class _ConversationRouteFailure extends StatelessWidget {
  const _ConversationRouteFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Marketplace conversation')),
        body: MarketplaceDataStateView(
          kind: MarketplaceDataStateKind.unavailable,
          icon: Icons.forum_outlined,
          title: 'Conversation unavailable',
          message: message,
          primaryLabel: 'Return to Marketplace',
          onPrimary: () => context.go('/'),
        ),
      );
}

class MarketplaceChatBubble extends StatelessWidget {
  const MarketplaceChatBubble({
    super.key,
    required this.text,
    required this.isMine,
    required this.hiddenByModeration,
    required this.timestamp,
    this.attachment,
  });

  final String text;
  final bool isMine;
  final bool hiddenByModeration;
  final String timestamp;
  final Map<String, dynamic>? attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isMine
        ? theme.colorScheme.secondary
        : theme.colorScheme.surfaceContainerHighest;
    final foreground =
        isMine ? theme.colorScheme.onSecondary : theme.colorScheme.onSurface;
    final attachmentType = '${attachment?['type'] ?? ''}'.trim();
    final attachmentName = '${attachment?['name'] ?? 'Message attachment'}';
    final availableWidth = MediaQuery.sizeOf(context).width;
    final bubbleWidth = availableWidth >= 720 ? 520.0 : availableWidth * .78;
    final semanticsText = hiddenByModeration
        ? 'Removed by Trust and Safety'
        : [
            if (text.trim().isNotEmpty) text.trim(),
            if (timestamp.isNotEmpty) timestamp
          ].join(', ');

    return Semantics(
      container: true,
      label: '${isMine ? 'Sent' : 'Received'} message, $semanticsText',
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: bubbleWidth),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            border:
                isMine ? null : Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hiddenByModeration && attachmentType == 'image')
                Semantics(
                  image: true,
                  label: 'Photo attachment: $attachmentName',
                  child: ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        '${attachment?['url'] ?? ''}',
                        width: 260,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 220,
                          height: 90,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (!hiddenByModeration && attachmentType.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        color: foreground,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          attachmentName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (hiddenByModeration)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.gpp_maybe_outlined,
                      size: 18,
                      color: foreground.withValues(alpha: .78),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Removed by Trust & Safety',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: foreground.withValues(alpha: .78),
                        ),
                      ),
                    ),
                  ],
                )
              else if (text.trim().isNotEmpty) ...[
                if (attachmentType.isNotEmpty) const SizedBox(height: 8),
                Text(text, style: TextStyle(color: foreground, height: 1.35)),
              ],
              if (timestamp.isNotEmpty) ...[
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    timestamp,
                    style: TextStyle(
                      color: foreground.withValues(alpha: .72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketplaceMessageTimeline extends StatefulWidget {
  const _MarketplaceMessageTimeline({
    required this.conversationId,
    required this.viewerUid,
  });

  final String conversationId;
  final String viewerUid;

  @override
  State<_MarketplaceMessageTimeline> createState() =>
      _MarketplaceMessageTimelineState();
}

class _MarketplaceMessageTimelineState
    extends State<_MarketplaceMessageTimeline> {
  late final Query<Map<String, dynamic>> _messageQuery;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;
  int _messageLimit = defaultActivityFeedLimit;

  @override
  void initState() {
    super.initState();
    _messageQuery = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true);
    _messagesStream = _messageQuery.limit(_messageLimit).snapshots();
  }

  void _loadEarlier() {
    if (_messageLimit >= maximumActivityHistoryLimit) return;
    final nextLimit = (_messageLimit + defaultActivityFeedLimit)
        .clamp(defaultActivityFeedLimit, maximumActivityHistoryLimit)
        .toInt();
    setState(() {
      _messageLimit = nextLimit;
      _messagesStream = _messageQuery.limit(_messageLimit).snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MarketplaceDataStateView.failure(
            error: snapshot.error,
            resource: 'Conversation messages',
            onRetry: () => setState(() {}),
            compact: true,
          );
        }
        if (!snapshot.hasData) {
          return const MarketplaceDataStateView.loading(
            title: 'Loading messages',
            message: 'Retrieving the conversation history…',
            compact: true,
          );
        }
        final messages = snapshot.data!.docs;
        if (messages.isEmpty) {
          return const MarketplaceDataStateView(
            kind: MarketplaceDataStateKind.empty,
            icon: Icons.waving_hand_outlined,
            title: 'Start the conversation',
            message: 'Write a message below to contact the seller.',
            compact: true,
          );
        }
        final reachedWindow = messages.length == _messageLimit;
        final canLoadEarlier =
            reachedWindow && _messageLimit < maximumActivityHistoryLimit;
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(12),
          itemCount: messages.length + (reachedWindow ? 1 : 0),
          itemBuilder: (context, index) {
            if (reachedWindow && index == messages.length) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.history_outlined),
                title: Text('Showing ${messages.length} recent messages'),
                subtitle: Text(
                  canLoadEarlier
                      ? 'Load the next 100 messages in the live conversation window.'
                      : 'Older messages remain stored in the conversation record.',
                ),
                trailing: canLoadEarlier
                    ? TextButton(
                        onPressed: _loadEarlier,
                        child: const Text('Load earlier'),
                      )
                    : null,
              );
            }
            final message = messages[index].data();
            return MarketplaceChatBubble(
              text: '${message['text'] ?? ''}',
              isMine: message['senderUid'] == widget.viewerUid,
              hiddenByModeration: message['moderationVisibility'] == 'hidden',
              timestamp: marketplaceMessageTimestamp(
                context,
                message['createdAt'] is Timestamp
                    ? (message['createdAt'] as Timestamp).toDate()
                    : null,
              ),
              attachment: message['attachment'] is Map
                  ? Map<String, dynamic>.from(message['attachment'] as Map)
                  : null,
            );
          },
        );
      },
    );
  }
}

class MarketplaceChatPage extends StatefulWidget {
  const MarketplaceChatPage({
    super.key,
    required this.conversationId,
    required this.title,
    this.participantName,
    this.participantUid,
    this.openedFromListing = false,
    this.openOfferComposer = false,
    this.initialOffer,
  });
  final String conversationId;
  final String title;
  final String? participantName;
  final String? participantUid;
  final bool openedFromListing;
  final bool openOfferComposer;
  final Map<String, dynamic>? initialOffer;
  @override
  State<MarketplaceChatPage> createState() => _MarketplaceChatPageState();
}

class _MarketplaceChatPageState extends State<MarketplaceChatPage> {
  final _controller = TextEditingController();
  final _actions = MarketplaceActionsRepository();
  bool _sending = false;
  bool _uploading = false;
  bool _blockBusy = false;
  bool _blockedByMe = false;
  bool _blockedMe = false;
  Map<String, dynamic>? _attachment;

  @override
  void initState() {
    super.initState();
    _actions.markConversationRead(widget.conversationId).catchError((_) {});
    _loadBlockStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final suppliedParticipant = widget.participantName?.trim() ?? '';
    final participantName = suppliedParticipant.isEmpty
        ? 'Marketplace member'
        : suppliedParticipant;
    final blocked = _blockedByMe || _blockedMe;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          if (widget.openedFromListing)
            IconButton(
              tooltip: 'Return to ad',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.inventory_2_outlined),
            ),
          IconButton(
            tooltip: 'Marketplace home',
            onPressed: () => MarketplaceNavigation.goHome(context),
            icon: const Icon(Icons.home_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') _reportConversation();
              if (value == 'profile') _openParticipantProfile();
              if (value == 'block') _toggleBlock();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('View member profile'),
                ),
              ),
              PopupMenuItem(
                value: 'block',
                enabled: !_blockBusy,
                child: ListTile(
                  leading: Icon(
                    _blockedByMe
                        ? Icons.person_add_alt_1
                        : Icons.block_outlined,
                    color: _blockedByMe ? Colors.green : Colors.deepOrange,
                  ),
                  title: Text(_blockedByMe ? 'Unblock member' : 'Block member'),
                  subtitle: _blockedMe
                      ? const Text('This member has blocked messaging')
                      : null,
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: ListTile(
                  leading: Icon(Icons.flag_outlined, color: Colors.deepOrange),
                  title: Text('Report conversation'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          PipeBuyerConversationHeader(
            title: participantName,
            subtitle: 'Protected marketplace conversation',
            avatar: Text(
              participantName[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            listingContext: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          _ConversationNegotiationPanel(
            conversationId: widget.conversationId,
            openComposerOnLoad: widget.openOfferComposer,
            initialOffer: widget.initialOffer,
          ),
          if (_blockedByMe || _blockedMe)
            Material(
              color: Colors.orange.shade50,
              child: ListTile(
                dense: true,
                leading:
                    const Icon(Icons.block_outlined, color: Colors.deepOrange),
                title: Text(
                  _blockedByMe
                      ? 'You blocked this member'
                      : 'Messaging is unavailable for this conversation',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  _blockedByMe
                      ? 'Message history and reports stay saved. Use the menu to unblock.'
                      : 'The other member has blocked direct messages. Existing history remains available.',
                ),
              ),
            ),
          Expanded(
            child: _MarketplaceMessageTimeline(
              conversationId: widget.conversationId,
              viewerUid: uid,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, _, __) => _buildComposer(context, blocked),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context, bool blocked) {
    final canSend = !_sending &&
        !_uploading &&
        !blocked &&
        (_controller.text.trim().isNotEmpty || _attachment != null);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Add emoji',
                  onPressed: blocked ? null : _showEmojiPicker,
                  icon: const Icon(Icons.emoji_emotions_outlined),
                ),
                IconButton(
                  tooltip: 'Attach photo',
                  onPressed: _uploading || blocked ? null : _pickAttachment,
                  icon: _uploading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_attachment != null)
                        InputChip(
                          avatar: const Icon(Icons.image_outlined),
                          label: Text('${_attachment!['name']}'),
                          onDeleted: _sending
                              ? null
                              : () => setState(() => _attachment = null),
                        ),
                      TextField(
                        controller: _controller,
                        enabled: !blocked && !_sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 4000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: blocked
                              ? 'Messaging is unavailable'
                              : 'Write a message…',
                          counterText: '',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (MediaQuery.sizeOf(context).width >= 720)
                  FilledButton.icon(
                    onPressed: canSend ? _send : null,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text('Send'),
                  )
                else
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: canSend ? _send : null,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'For safety, keep deal and payment details inside Pipe Buyer.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadBlockStatus() async {
    try {
      final status = await _actions.readConversationBlockStatus(
        widget.conversationId,
      );
      if (!mounted) return;
      setState(() {
        _blockedByMe = status['blockedByViewer'] == true;
        _blockedMe = status['blockedViewer'] == true;
      });
    } catch (_) {
      // Messaging remains protected server-side even if the status chip cannot load.
    }
  }

  Future<void> _toggleBlock() async {
    if (_blockBusy) return;
    final blocking = !_blockedByMe;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon:
                Icon(blocking ? Icons.block_outlined : Icons.person_add_alt_1),
            title:
                Text(blocking ? 'Block this member?' : 'Unblock this member?'),
            content: Text(
              blocking
                  ? 'They will no longer be able to exchange direct messages with you. Existing messages and any Trust & Safety reports stay saved.'
                  : 'Direct messaging will be available again unless the other member has also blocked you.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(blocking ? 'Block member' : 'Unblock member'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _blockBusy = true);
    try {
      final status = await _actions.setConversationBlocked(
        widget.conversationId,
        blocked: blocking,
      );
      if (!mounted) return;
      setState(() {
        _blockedByMe = status['blockedByViewer'] == true;
        _blockedMe = status['blockedViewer'] == true;
      });
      PipeFeedback.show(
        context,
        message: blocking
            ? 'Member blocked. Existing messages and reports were preserved.'
            : 'Member unblocked.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The block setting could not be changed. Try again.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _blockBusy = false);
    }
  }

  Future<void> _openParticipantProfile() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .get();
    final conversation = snapshot.data() ?? {};
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final members = List<String>.from(
      conversation['memberUids'] ?? const <String>[],
    );
    final otherUid =
        members.where((member) => member != currentUid).firstOrNull;
    if (otherUid == null || !mounted) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'The other member’s profile is unavailable.',
          tone: PipeStatusTone.warning,
        );
      }
      return;
    }
    await context.push(MarketplaceDeepLinks.profile(otherUid));
  }

  Future<void> _send() async {
    if (_sending || _uploading || _blockedByMe || _blockedMe) return;
    final text = _controller.text.trim();
    if (text.isEmpty && _attachment == null) return;
    setState(() => _sending = true);
    try {
      await _actions.sendChatMessage(
        widget.conversationId,
        text,
        attachment: _attachment,
      );
      _controller.clear();
      setState(() => _attachment = null);
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'Message could not be sent. Try again.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showEmojiPicker() {
    const emojis = [
      '😀',
      '👍',
      '❤️',
      '😂',
      '🎉',
      '✅',
      '👀',
      '🤝',
      '🙏',
      '📍',
      '🚚',
      '💰',
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: emojis
                .map(
                  (emoji) => InkWell(
                    onTap: () {
                      _controller.text += emoji;
                      _controller.selection = TextSelection.collapsed(
                        offset: _controller.text.length,
                      );
                      Navigator.pop(context);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 30)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAttachment() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Attach a photo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF0878E8),
              ),
              title: const Text('Choose photo from gallery'),
              subtitle: const Text(
                'Select photos of pipe, valves, or equipment',
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF10B981)),
              title: const Text('Take photo with camera'),
              subtitle: const Text('Capture live photos at yard or jobsite'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (file == null) return;
      final sizeBytes = await file.length();
      if (sizeBytes > 15 * 1024 * 1024) {
        if (mounted) {
          PipeFeedback.show(
            context,
            message: 'Attachment must be under 15 MB.',
            tone: PipeStatusTone.warning,
          );
        }
        return;
      }
      setState(() => _uploading = true);
      final extension = file.name.split('.').last.toLowerCase();
      final contentType = extension == 'png'
          ? 'image/png'
          : extension == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      final authorization = await _actions.authorizeUpload(
        purpose: 'chat_attachment',
        originalName: file.name,
        contentType: contentType,
        sizeBytes: sizeBytes,
        conversationId: widget.conversationId,
      );
      final authorizationId = '${authorization['authorizationId']}';
      final reference = FirebaseStorage.instance.ref(
        '${authorization['storagePath']}',
      );
      await reference.putData(
        await file.readAsBytes(),
        SettableMetadata(
          contentType: contentType,
          customMetadata: {'conversationId': widget.conversationId},
        ),
      );
      final url = await reference.getDownloadURL();
      await _actions.confirmUpload(authorizationId: authorizationId, url: url);
      if (mounted) {
        setState(
          () => _attachment = {
            'type': 'image',
            'authorizationId': authorizationId,
            'url': url,
            'name': file.name,
          },
        );
        PipeFeedback.show(
          context,
          message: 'Image attached. Add a message or press Send.',
          tone: PipeStatusTone.success,
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: error.code == 'unauthorized'
              ? 'Image upload is not authorized. Refresh your account and try again.'
              : 'Image upload failed. Please try again.',
          tone: PipeStatusTone.error,
        );
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'Could not attach this image. Try another file.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _reportConversation() async {
    final conversation = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .get();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final members = List<String>.from(
      conversation.data()?['memberUids'] ?? const <String>[],
    );
    final reportedUid = members.where((member) => member != uid).firstOrNull;
    if (reportedUid == null) return;
    if (!mounted) return;
    final submitted = await showMarketplaceReportDialog(
      context,
      reportedUid: reportedUid,
      targetType: 'message',
      conversationId: widget.conversationId,
    );
    if (mounted && submitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thank you. The conversation and your evidence were sent for private review.',
          ),
        ),
      );
    }
  }
}
