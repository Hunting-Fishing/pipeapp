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
import '../core/diagnostics/app_diagnostics.dart';
import 'marketplace_reporting.dart';

import 'marketplace_actions_repository.dart';
import 'marketplace_command_client.dart';
import 'marketplace_navigation.dart';
import 'marketplace_avatar_image.dart';
import 'marketplace_offer_ranking.dart';
import 'marketplace_offer_schedule.dart';
import 'marketplace_account_hub.dart';
import 'marketplace_trucking_plan.dart';
import 'marketplace_location.dart';
import 'marketplace_deep_links.dart';
import 'marketplace_data_state.dart';

class MarketplaceMessagesPage extends StatelessWidget {
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
        .map((snapshot) => snapshot.docs.fold<int>(0, (total, doc) {
              final counts = doc.data()['unreadCounts'] as Map? ?? {};
              return total + ((counts[uid] as num?)?.toInt() ?? 0);
            }));
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
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _SignedOutMessages();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('memberUids', arrayContains: uid)
          .orderBy('lastMessageAt', descending: true)
          .limit(defaultActivityFeedLimit)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadFailure(error: snapshot.error);
        }
        if (!snapshot.hasData) {
          return const MarketplaceDataStateView.loading(
            title: 'Loading conversations',
            message: 'Retrieving your latest marketplace messages…',
          );
        }
        final conversations = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTime = a.data()['lastMessageAt'] as Timestamp?;
            final bTime = b.data()['lastMessageAt'] as Timestamp?;
            return (bTime?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
          });
        if (conversations.isEmpty) return const _EmptyMessages();
        final atLimit = conversations.length == defaultActivityFeedLimit;
        final list = ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 5),
          itemBuilder: (context, index) {
            final doc = conversations[index];
            final data = doc.data();
            final unread =
                ((data['unreadCounts'] as Map?)?[uid] as num?)?.toInt() ?? 0;
            final sellerName = '${data['sellerName'] ?? 'Marketplace seller'}';
            final title = '${data['listingTitle'] ?? 'Marketplace listing'}';
            final memberUids =
                List<String>.from(data['memberUids'] ?? const <String>[]);
            final otherUid =
                memberUids.where((member) => member != uid).firstOrNull ?? '';
            return Card(
              child: ListTile(
                leading: MarketplaceUserAvatar(
                    userUid: otherUid,
                    size: 40,
                    fallback: Center(
                        child: Text(sellerName.isEmpty ? '?' : sellerName[0]))),
                title: Text(title,
                    maxLines: 1,
                    style: TextStyle(
                        fontWeight:
                            unread > 0 ? FontWeight.w900 : FontWeight.w700)),
                subtitle: Text('${data['lastMessage'] ?? ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: unread > 0
                    ? Badge(label: Text('$unread'))
                    : const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push(MarketplaceDeepLinks.conversation(doc.id)),
              ),
            );
          },
        );
        if (!atLimit) return list;
        return Column(children: [
          const _ActivityLimitNotice(
            message: 'Showing the 100 most recent conversations.',
          ),
          Expanded(child: list),
        ]);
      },
    );
  }
}

class _ActivityLimitNotice extends StatelessWidget {
  const _ActivityLimitNotice({required this.message});

  final String message;

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
          child: Row(children: [
            Icon(Icons.info_outline,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ]),
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Account refreshed. Messages will reconnect.'),
            ));
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
                if (widget.openComposerOnLoad &&
                    !_openedInitialComposer &&
                    conversation != null &&
                    listing.isNotEmpty) {
                  _openedInitialComposer = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _openProposal(conversation, listing,
                          initialOffer: widget.initialOffer);
                    }
                  });
                }
                final askingPrice = listing['price'] as num?;
                final available = (listing['quantity'] as num?)?.toInt();
                final basis = '${listing['priceBasis'] ?? ''}';
                final latest = Map<String, dynamic>.from(
                    conversation?['latestNegotiation'] as Map? ?? {});
                final currentPrice = latest['unitPrice'] as num? ?? askingPrice;
                final currentQuantity =
                    (latest['quantity'] as num?)?.toInt() ?? available;
                return Material(
                    color: const Color(0xFFF4F8FC),
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          const CircleAvatar(
                              radius: 20,
                              child:
                                  Icon(Icons.local_offer_outlined, size: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const Text('Offer',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w900)),
                                Text(
                                    currentPrice == null
                                        ? 'Price available on request'
                                        : '\$${currentPrice.toStringAsFixed(2)}'
                                            '${basis.isEmpty ? '' : ' • $basis'}'
                                            '${currentQuantity == null ? '' : ' • Qty $currentQuantity'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)
                              ])),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                              constraints: const BoxConstraints(
                                  minWidth: 160, minHeight: 50),
                              child: FilledButton.tonalIcon(
                                  onPressed: () =>
                                      _openOffers(conversation!, listing),
                                  icon: const Icon(Icons.handshake_outlined),
                                  label: Text(latest.isEmpty
                                      ? 'Make offer'
                                      : 'Offers & history')))
                        ])));
              });
        });
  }

  Future<void> _openOffers(
      Map<String, dynamic> conversation, Map<String, dynamic> listing) async {
    if (!_features.offers) return;
    final sellerUid = '${conversation['sellerUid'] ?? ''}';
    final members =
        List<String>.from(conversation['memberUids'] ?? const <String>[]);
    final buyerUid =
        members.where((member) => member != sellerUid).firstOrNull ?? '';
    final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 620, maxHeight: 720),
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const CircleAvatar(
                                child: Icon(Icons.local_offer_outlined)),
                            const SizedBox(width: 12),
                            const Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('Offers',
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900)),
                                  Text('Price and quantity history')
                                ])),
                            IconButton(
                                tooltip: 'Close offer history',
                                onPressed: () => Navigator.pop(dialogContext),
                                icon: const Icon(Icons.close))
                          ]),
                          const SizedBox(height: 14),
                          Expanded(
                              child: MarketplaceNegotiationHistory(
                                  listingTitle:
                                      '${conversation['listingTitle'] ?? 'Marketplace listing'}',
                                  buyerUid: buyerUid,
                                  sellerUid: sellerUid,
                                  listingId: '${conversation['listingId']}',
                                  askingPrice: listing['price'] as num?,
                                  availableQuantity:
                                      (listing['quantity'] as num?)?.toInt())),
                          const SizedBox(height: 14),
                          SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton.icon(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, 'offer'),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Make or revise offer')))
                        ])))));
    if (action == 'offer' && mounted) {
      await _openProposal(conversation, listing);
    }
  }

  Future<void> _openProposal(
      Map<String, dynamic> conversation, Map<String, dynamic> listing,
      {Map<String, dynamic>? initialOffer}) async {
    if (!_features.offers) return;
    final latest = Map<String, dynamic>.from(
        conversation['latestNegotiation'] as Map? ?? {});
    final price = TextEditingController(
        text:
            '${initialOffer?['offeredUnitPrice'] ?? latest['unitPrice'] ?? listing['price'] ?? ''}');
    final quantity = TextEditingController(
        text:
            '${initialOffer?['requestedQuantity'] ?? latest['quantity'] ?? listing['quantity'] ?? 1}');
    final note = TextEditingController();
    MarketplaceLocation? dispatchDeliveryLocation =
        marketplaceLocationFromOfferDelivery(initialOffer?['dispatchDelivery']);
    DateTime? purchaseDate =
        _currentOrFutureOfferDate(initialOffer?['purchaseDate']);
    DateTime? moneyTransferDate =
        _currentOrFutureOfferDate(initialOffer?['moneyTransferDate']);
    DateTime? truckingDate =
        _currentOrFutureOfferDate(initialOffer?['truckingDate']);
    MarketplaceTruckingPlan? truckingPlan = marketplaceTruckingPlanFromStorage(
        '${initialOffer?['truckingPlan'] ?? ''}');
    if (!_features.dispatch &&
        truckingPlan == MarketplaceTruckingPlan.requestDispatch) {
      truckingPlan = null;
      dispatchDeliveryLocation = null;
    }
    final formKey = GlobalKey<FormState>();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          StatefulBuilder(builder: (dialogContext, refresh) {
        final offeredUnit = num.tryParse(price.text.replaceAll(',', '')) ?? 0;
        final requestedQty =
            int.tryParse(quantity.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final askingUnit = listing['price'] as num? ?? 0;
        final askingTotal = askingUnit * requestedQty;
        final offeredTotal = offeredUnit * requestedQty;
        final difference = offeredTotal - askingTotal;
        final percent = askingTotal == 0 ? 0 : difference / askingTotal * 100;
        final available = (listing['quantity'] as num?)?.toInt();
        final basis = '${listing['priceBasis'] ?? ''}';
        final isFullQuantity = available != null && requestedQty == available;
        final isOverQuantity = available != null && requestedQty > available;
        final isFullPrice = askingUnit > 0 && offeredUnit == askingUnit;
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          title: Text(
              initialOffer == null ? 'Make an offer' : 'Make a counter offer'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEAF4FD),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              askingUnit == 0
                                  ? 'Seller price available on request'
                                  : 'Seller asks \$${askingUnit.toStringAsFixed(2)}'
                                      '${basis.isEmpty ? '' : ' • $basis'}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          if (available != null)
                            Text('$available pieces available')
                        ]),
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
                        suffixText: 'pieces'),
                    validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                        ? 'Enter a valid quantity'
                        : null,
                  ),
                  if (available != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ChoiceChip(
                        selected: isFullQuantity,
                        avatar: Icon(isFullQuantity
                            ? Icons.check_circle
                            : Icons.inventory_2_outlined),
                        label: Text(isFullQuantity
                            ? 'ALL — buying the full quantity ($available)'
                            : 'Buy ALL $available available pieces'),
                        onSelected: (_) {
                          quantity.text = '$available';
                          refresh(() {});
                        },
                      ),
                    )
                  ],
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: price,
                    autofocus: true,
                    onChanged: (_) => refresh(() {}),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Offer price',
                        hintText: 'e.g. 70.00',
                        prefixText: '\$ ',
                        helperText: basis.isEmpty
                            ? 'Enter your price using the listing’s pricing unit.'
                            : 'Price ${basis.toLowerCase()}'),
                    validator: (value) =>
                        (num.tryParse(value?.replaceAll(',', '') ?? '') ?? 0) <=
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
                        avatar: Icon(isFullPrice
                            ? Icons.check_circle
                            : Icons.price_check_outlined),
                        label: Text(isFullPrice
                            ? 'FULL ASKING PRICE'
                            : 'Match full asking price'),
                        onSelected: (_) {
                          price.text = askingUnit.toStringAsFixed(2);
                          refresh(() {});
                        },
                      ),
                    )
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
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        Row(children: [
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
                                      : Colors.orange.shade800),
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
                                              : Colors.orange.shade800)))
                        ]),
                        const Divider(),
                        _chatOfferLine('Asking total', askingTotal),
                        _chatOfferLine('Offer total', offeredTotal),
                        const Divider(),
                        Row(children: [
                          const Expanded(
                              child: Text('Difference',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800))),
                          Flexible(
                            child: Text(
                              '${difference >= 0 ? '+' : '-'}\$${difference.abs().toStringAsFixed(2)} '
                              '(${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%)',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: difference < 0
                                      ? Colors.deepOrange
                                      : Colors.green.shade700),
                            ),
                          )
                        ])
                      ]),
                    )
                  ],
                  const SizedBox(height: 10),
                  TextField(
                      controller: note,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Conditions or message (optional)',
                          hintText:
                              'e.g. Conditional on inspection, documents, loading or pickup access')),
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
                          })),
                  if (truckingPlan ==
                      MarketplaceTruckingPlan.requestDispatch) ...[
                    const SizedBox(height: 4),
                    MarketplaceDeliveryLocationSelector(
                        value: dispatchDeliveryLocation,
                        onChanged: (value) =>
                            refresh(() => dispatchDeliveryLocation = value)),
                  ],
                  const SizedBox(height: 8),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Proposed dates',
                          style: TextStyle(fontWeight: FontWeight.w900))),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          'Add dates that matter to this purchase. A trucking date is required when requesting Dispatch.',
                          style: TextStyle(
                              color: Color(0xFF66758A), fontSize: 11))),
                  const SizedBox(height: 6),
                  _offerDateTile(
                      label: 'Purchase date',
                      icon: Icons.event_available_outlined,
                      value: purchaseDate,
                      onTap: () async {
                        final selected =
                            await _pickOfferDate(dialogContext, purchaseDate);
                        if (selected != null) {
                          purchaseDate = selected;
                          refresh(() {});
                        }
                      }),
                  _offerDateTile(
                      label: 'Money transfer date',
                      icon: Icons.account_balance_outlined,
                      value: moneyTransferDate,
                      onTap: () async {
                        final selected = await _pickOfferDate(
                            dialogContext, moneyTransferDate);
                        if (selected != null) {
                          moneyTransferDate = selected;
                          refresh(() {});
                        }
                      }),
                  _offerDateTile(
                      label: 'Trucking / pickup date',
                      icon: Icons.local_shipping_outlined,
                      value: truckingDate,
                      onTap: () async {
                        final selected =
                            await _pickOfferDate(dialogContext, truckingDate);
                        if (selected != null) {
                          truckingDate = selected;
                          refresh(() {});
                        }
                      }),
                  const SizedBox(height: 10),
                  const Text(
                      'This offer will be added to the shared offer history.',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
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
                child: Text(initialOffer == null
                    ? 'Review offer'
                    : 'Review counter offer'))
          ],
        );
      }),
    );
    if (submitted != true || !mounted) {
      price.dispose();
      quantity.dispose();
      note.dispose();
      return;
    }
    final unitPrice = num.parse(price.text.replaceAll(',', ''));
    final requestedQuantity = int.parse(quantity.text);
    final askingUnit = listing['price'] as num? ?? 0;
    final available = (listing['quantity'] as num?)?.toInt();
    final difference = (unitPrice - askingUnit) * requestedQuantity;
    final differencePercent =
        askingUnit == 0 ? 0 : (unitPrice - askingUnit) / askingUnit * 100;
    final isAll = available != null && requestedQuantity == available;
    final isFullPrice = askingUnit > 0 && unitPrice == askingUnit;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (confirmationContext) => AlertDialog(
            icon: const Icon(Icons.analytics_outlined, size: 38),
            title: Text(initialOffer == null
                ? 'Review and send offer'
                : 'Review counter offer'),
            content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _offerReviewCard(
                          icon: isAll
                              ? Icons.check_circle
                              : Icons.pie_chart_outline,
                          color: isAll ? Colors.green : Colors.orange,
                          title: isAll
                              ? 'ALL — full available quantity'
                              : 'Partial quantity',
                          detail: available == null
                              ? '$requestedQuantity units'
                              : '$requestedQuantity of $available units'),
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
                          detail:
                              '\$${unitPrice.toStringAsFixed(2)} per unit • '
                              '${difference >= 0 ? '+' : '-'}\$${difference.abs().toStringAsFixed(2)} '
                              '(${differencePercent >= 0 ? '+' : ''}${differencePercent.toStringAsFixed(1)}%)'),
                      const SizedBox(height: 12),
                      _chatOfferLine(
                          'Offer total', unitPrice * requestedQuantity),
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
                              : truckingPlan!.description),
                      if (purchaseDate == null &&
                          moneyTransferDate == null &&
                          truckingDate == null)
                        const Text('No dates proposed',
                            style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 12),
                      const Text(
                          'The other party will see this offer immediately.',
                          style: TextStyle(color: Colors.black54))
                    ]))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(confirmationContext, false),
                  child: const Text('Go back')),
              FilledButton(
                  onPressed: () => Navigator.pop(confirmationContext, true),
                  child: Text(initialOffer == null
                      ? 'Send proposal'
                      : 'Send counter offer'))
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
            unitPrice: unitPrice,
            quantity: requestedQuantity,
            priceBasis: '${listing['priceBasis'] ?? ''}',
            note: note.text,
            purchaseDate: purchaseDate,
            moneyTransferDate: moneyTransferDate,
            truckingDate: truckingDate,
            truckingPlan: truckingPlan!.storageValue,
            dispatchDelivery: dispatchDeliveryLocation?.publicName.trim() ?? '',
            dispatchDeliveryLocation: dispatchDeliveryLocation);
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

  Widget _chatOfferLine(String label, num amount) => Row(children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 10),
        Text('\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w800))
      ]);

  Widget _offerDateTile(
          {required String label,
          required IconData icon,
          required DateTime? value,
          required VoidCallback onTap}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  alignment: Alignment.centerLeft),
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(value == null
                  ? 'Select $label'
                  : '$label: ${_formatOfferDate(value)}')));

  Future<DateTime?> _pickOfferDate(BuildContext context, DateTime? current) =>
      showDatePicker(
          context: context,
          initialDate: current ?? DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 730)));

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

  Widget _offerReviewCard(
          {required IconData icon,
          required Color color,
          required String title,
          required String detail}) =>
      Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: .35))),
          child: Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style:
                          TextStyle(fontWeight: FontWeight.w900, color: color)),
                  Text(detail)
                ]))
          ]));

  Widget _reviewDate(String label, DateTime date) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        const Icon(Icons.calendar_month_outlined, size: 18),
        const SizedBox(width: 7),
        Expanded(child: Text('$label: ${_formatOfferDate(date)}'))
      ]));
}

class MarketplaceNegotiationHistory extends StatefulWidget {
  const MarketplaceNegotiationHistory(
      {super.key,
      required this.listingId,
      required this.listingTitle,
      required this.buyerUid,
      required this.sellerUid,
      this.askingPrice,
      this.availableQuantity});
  final String listingId;
  final String listingTitle;
  final String buyerUid;
  final String sellerUid;
  final num? askingPrice;
  final int? availableQuantity;

  @override
  State<MarketplaceNegotiationHistory> createState() =>
      _MarketplaceNegotiationHistoryState();
}

class _MarketplaceNegotiationHistoryState
    extends State<MarketplaceNegotiationHistory> {
  RangeValues _percentOffRange = const RangeValues(0, 100);
  DateTimeRange? _pickupRange;
  MarketplaceOfferTruckingFilter _truckingFilter =
      MarketplaceOfferTruckingFilter.all;

  String get listingId => widget.listingId;
  String get listingTitle => widget.listingTitle;
  String get buyerUid => widget.buyerUid;
  String get sellerUid => widget.sellerUid;
  num? get askingPrice => widget.askingPrice;
  int? get availableQuantity => widget.availableQuantity;

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
              .where((doc) =>
                  (isSeller || doc.data()['buyerUid'] == buyerUid) &&
                  doc.data()['sellerUid'] == sellerUid &&
                  doc.data()['status'] != 'archived')
              .toList()
            ..sort((a, b) {
              final at = a.data()['createdAt'] as Timestamp?;
              final bt = b.data()['createdAt'] as Timestamp?;
              return (bt?.millisecondsSinceEpoch ?? 0)
                  .compareTo(at?.millisecondsSinceEpoch ?? 0);
            });
          if (events.isEmpty) {
            return MarketplaceDataStateView(
              kind: MarketplaceDataStateKind.empty,
              compact: true,
              icon: isSeller
                  ? Icons.auto_awesome_outlined
                  : Icons.handshake_outlined,
              title: isSeller ? 'Smart offers' : 'No offers yet',
              message: isSeller
                  ? 'New buyer offers will be ranked here by price, payment, pickup, and trucking readiness.'
                  : 'Seller asks ${askingPrice == null ? 'contact for price' : '\$${askingPrice!.toStringAsFixed(2)}'}'
                      '${availableQuantity == null ? '' : ' for up to $availableQuantity units'}.',
            );
          }
          final revisionsByBuyer =
              <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
          for (final event in events) {
            final buyer = '${event.data()['buyerUid'] ?? ''}';
            revisionsByBuyer.putIfAbsent(buyer, () => []).add(event);
          }
          if (isSeller) {
            final displayed = revisionsByBuyer.values.map((history) {
              return history.firstWhere(
                (document) {
                  final data = document.data();
                  return data['proposedByUid'] == data['buyerUid'];
                },
                orElse: () => history.first,
              );
            }).toList();
            return _sellerSmartHistory(
              context,
              displayed: displayed,
              revisionsByBuyer: revisionsByBuyer,
              totalUpdates: events.length,
              atLimit: snapshot.data!.docs.length == defaultActivityFeedLimit,
            );
          }
          return _buyerOfferHistory(
            context,
            events: events,
            revisionsByBuyer: revisionsByBuyer,
            atLimit: snapshot.data!.docs.length == defaultActivityFeedLimit,
          );
        });
  }

  Widget _sellerSmartHistory(
    BuildContext context, {
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> displayed,
    required Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        revisionsByBuyer,
    required int totalUpdates,
    required bool atLimit,
  }) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('dispatch_jobs')
            .where('listingId', isEqualTo: listingId)
            .limit(defaultActivityFeedLimit)
            .snapshots(),
        builder: (context, dispatchSnapshot) {
          final dispatchStatuses = <String, String>{};
          for (final document in dispatchSnapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
            final data = document.data();
            final offerId = '${data['offerId'] ?? document.id}';
            dispatchStatuses[offerId] =
                '${data['dispatchRequestStatus'] ?? data['status'] ?? ''}';
          }
          final ranked = rankMarketplaceOffers(
            now: DateTime.now(),
            askingUnitPrice: askingPrice,
            offers: displayed
                .map((document) => MarketplaceOfferRankingInput(
                      offerId: document.id,
                      data: document.data(),
                      dispatchStatus: dispatchStatuses[document.id] ?? '',
                    ))
                .toList(),
          );
          final filters = MarketplaceOfferRankingFilters(
            minimumPercentOff: _percentOffRange.start,
            maximumPercentOff: _percentOffRange.end,
            pickupFrom: _pickupRange?.start,
            pickupTo: _pickupRange?.end,
            trucking: _truckingFilter,
          );
          final filtered = ranked.where(filters.matches).toList();
          return Column(children: [
            if (atLimit)
              const ListTile(
                dense: true,
                leading: Icon(Icons.info_outline),
                title: Text('Showing the latest 100 offer updates'),
                subtitle: Text(
                    'Older revisions remain in the authoritative transaction history.'),
              ),
            _smartOffersHeader(
              buyerCount: revisionsByBuyer.length,
              totalUpdates: totalUpdates,
              shownCount: filtered.length,
              topOffer: filtered.isEmpty ? null : filtered.first,
              dispatchLoading:
                  dispatchSnapshot.connectionState == ConnectionState.waiting,
              dispatchError: dispatchSnapshot.hasError,
            ),
            const SizedBox(height: 9),
            _smartOfferFilters(context, filters),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? MarketplaceDataStateView(
                      kind: MarketplaceDataStateKind.empty,
                      compact: true,
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No offers match these filters',
                      message:
                          'Clear or widen the price, pickup, or trucking filters.',
                      primaryLabel: 'Clear filters',
                      primaryIcon: Icons.restart_alt,
                      onPrimary: _resetOfferFilters,
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final rank = filtered[index];
                        final document = displayed.firstWhere(
                            (candidate) => candidate.id == rank.input.offerId);
                        final event = document.data();
                        final buyer = '${event['buyerUid'] ?? ''}';
                        return _offerCard(
                          event,
                          context: context,
                          offerId: document.id,
                          isSeller: true,
                          isBest: rank.bestOverall,
                          smartRank: rank,
                          revisions: revisionsByBuyer[buyer] ?? const [],
                        );
                      },
                    ),
            ),
          ]);
        },
      );

  Widget _buyerOfferHistory(
    BuildContext context, {
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
    required Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        revisionsByBuyer,
    required bool atLimit,
  }) {
    final bestTotal = events.fold<num>(
        0,
        (best, event) => (event.data()['offeredTotal'] as num? ?? 0) > best
            ? event.data()['offeredTotal'] as num
            : best);
    return Column(children: [
      if (atLimit)
        const ListTile(
          dense: true,
          leading: Icon(Icons.info_outline),
          title: Text('Showing the latest 100 offer updates'),
          subtitle: Text('Older revisions remain in the transaction history.'),
        ),
      Expanded(
        child: ListView.separated(
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) {
            final document = events[index];
            final event = document.data();
            final buyer = '${event['buyerUid'] ?? ''}';
            return _offerCard(
              event,
              context: context,
              offerId: document.id,
              isSeller: false,
              isBest: (event['offeredTotal'] as num? ?? 0) == bestTotal,
              revisions: revisionsByBuyer[buyer] ?? const [],
            );
          },
        ),
      ),
    ]);
  }

  Widget _smartOffersHeader({
    required int buyerCount,
    required int totalUpdates,
    required int shownCount,
    required MarketplaceOfferRank? topOffer,
    required bool dispatchLoading,
    required bool dispatchError,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4FD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB8D9F8)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF0878E8)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Smart offers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            if (topOffer != null)
              Text(
                  'Top match #${topOffer.rank} • ${topOffer.score.round()}/100',
                  style: TextStyle(
                      color: _offerBandColor(topOffer.band),
                      fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 4),
          Text(
            '$buyerCount buyer${buyerCount == 1 ? '' : 's'} • '
            '$totalUpdates update${totalUpdates == 1 ? '' : 's'} • '
            '$shownCount shown',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Best overall is ranked by price (50%), payment date (20%), pickup date (20%), and trucking readiness (10%). Ranking is guidance—review every condition before accepting.',
            style: TextStyle(fontSize: 11, color: Color(0xFF53657A)),
          ),
          if (dispatchLoading)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (dispatchError)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Dispatch confirmation is temporarily unavailable; requested trucking is shown as pending.',
                style: TextStyle(fontSize: 11, color: Colors.deepOrange),
              ),
            ),
        ]),
      );

  Widget _smartOfferFilters(
          BuildContext context, MarketplaceOfferRankingFilters filters) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD8E3ED)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.tune, size: 19),
            const SizedBox(width: 7),
            const Expanded(
                child: Text('Filter offers',
                    style: TextStyle(fontWeight: FontWeight.w900))),
            if (filters.hasActiveFilters)
              TextButton(
                  onPressed: _resetOfferFilters,
                  child: const Text('Clear all')),
          ]),
          Text(
              '${_percentOffRange.start.round()}–${_percentOffRange.end.round()}% off asking price'),
          RangeSlider(
            values: _percentOffRange,
            min: 0,
            max: 100,
            divisions: 20,
            labels: RangeLabels(
              '${_percentOffRange.start.round()}%',
              '${_percentOffRange.end.round()}%',
            ),
            onChanged: (value) => setState(() => _percentOffRange = value),
          ),
          Wrap(spacing: 7, runSpacing: 7, children: [
            OutlinedButton.icon(
              onPressed: () => _selectPickupRange(context),
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(_pickupRange == null
                  ? 'Any pickup date'
                  : 'Pickup ${_shortDate(_pickupRange!.start)}–${_shortDate(_pickupRange!.end)}'),
            ),
            if (_pickupRange != null)
              IconButton.filledTonal(
                tooltip: 'Clear pickup dates',
                onPressed: () => setState(() => _pickupRange = null),
                icon: const Icon(Icons.event_busy_outlined, size: 18),
              ),
          ]),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: MarketplaceOfferTruckingFilter.values
                .map((filter) => ChoiceChip(
                      selected: _truckingFilter == filter,
                      label: Text(_truckingFilterLabel(filter)),
                      avatar: Icon(_truckingFilterIcon(filter), size: 16),
                      onSelected: (_) =>
                          setState(() => _truckingFilter = filter),
                    ))
                .toList(),
          ),
        ]),
      );

  Future<void> _selectPickupRange(BuildContext context) async {
    final today = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 730)),
      initialDateRange: _pickupRange,
      helpText: 'FILTER BY PICKUP DATE',
    );
    if (selected != null && mounted) {
      setState(() => _pickupRange = selected);
    }
  }

  void _resetOfferFilters() => setState(() {
        _percentOffRange = const RangeValues(0, 100);
        _pickupRange = null;
        _truckingFilter = MarketplaceOfferTruckingFilter.all;
      });

  String _shortDate(DateTime value) =>
      '${value.month}/${value.day}/${value.year}';

  String _truckingFilterLabel(MarketplaceOfferTruckingFilter filter) =>
      switch (filter) {
        MarketplaceOfferTruckingFilter.all => 'All trucking',
        MarketplaceOfferTruckingFilter.buyerArranged => 'Trucking arranged',
        MarketplaceOfferTruckingFilter.dispatchRequested => 'Seeking Dispatch',
        MarketplaceOfferTruckingFilter.dispatchConfirmed =>
          'Dispatch confirmed',
        MarketplaceOfferTruckingFilter.sellerArranged => 'Seller arranged',
      };

  IconData _truckingFilterIcon(MarketplaceOfferTruckingFilter filter) =>
      switch (filter) {
        MarketplaceOfferTruckingFilter.all => Icons.local_shipping_outlined,
        MarketplaceOfferTruckingFilter.buyerArranged => Icons.task_alt,
        MarketplaceOfferTruckingFilter.dispatchRequested =>
          Icons.route_outlined,
        MarketplaceOfferTruckingFilter.dispatchConfirmed =>
          Icons.verified_outlined,
        MarketplaceOfferTruckingFilter.sellerArranged =>
          Icons.handshake_outlined,
      };

  Color _offerBandColor(MarketplaceOfferBand band) => switch (band) {
        MarketplaceOfferBand.green => const Color(0xFF15803D),
        MarketplaceOfferBand.yellow => const Color(0xFFF9A825),
        MarketplaceOfferBand.orange => const Color(0xFFEA580C),
        MarketplaceOfferBand.red => const Color(0xFFDC2626),
      };

  Widget _offerCard(Map<String, dynamic> event,
      {required BuildContext context,
      required String offerId,
      required bool isSeller,
      required bool isBest,
      MarketplaceOfferRank? smartRank,
      required List<QueryDocumentSnapshot<Map<String, dynamic>>> revisions}) {
    final price = event['offeredUnitPrice'] as num? ?? 0;
    final quantity = (event['requestedQuantity'] as num?)?.toInt() ?? 0;
    final total = event['offeredTotal'] as num? ?? price * quantity;
    final isAll = availableQuantity != null && quantity == availableQuantity;
    final milestones = marketplaceOfferMilestones(event);
    final revisionCount = revisions.length;
    final offerStatus = '${event['status'] ?? 'pending'}';
    final hasTransaction = const {
      'accepted',
      'completed',
      'cancelled',
      'disputed',
    }.contains(offerStatus);
    final priceDifference = askingPrice == null ? 0 : price - askingPrice!;
    final quantityPercent = availableQuantity == null || availableQuantity == 0
        ? null
        : quantity / availableQuantity! * 100;
    final bandColor = smartRank == null
        ? (isBest ? Colors.green : Colors.blueGrey)
        : _offerBandColor(smartRank.band);
    return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: smartRank != null
                ? bandColor.withValues(alpha: .07)
                : isBest
                    ? const Color(0xFFEAF8F1)
                    : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: smartRank != null
                    ? bandColor.withValues(alpha: .72)
                    : isBest
                        ? Colors.green.shade400
                        : Colors.blueGrey.shade100,
                width: isBest ? 2 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: isSeller
                        ? () => _showOfferBuyerProfile(
                            context,
                            '${event['buyerUid'] ?? ''}',
                            '${event['buyerDisplayName'] ?? ''}')
                        : null,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          _BuyerOfferAvatar(
                              uid: '${event['buyerUid'] ?? ''}',
                              isBest: isBest),
                          const SizedBox(width: 9),
                          Expanded(
                              child: isSeller
                                  ? _BuyerOfferName(
                                      uid: '${event['buyerUid'] ?? ''}',
                                      name:
                                          '${event['buyerDisplayName'] ?? ''}')
                                  : const Text('Your offer',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900)))
                        ])))),
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
                      size: 17),
                  label: Text(offerStatus.toUpperCase()))
            else if (isBest)
              const Chip(
                  avatar: Icon(Icons.emoji_events_outlined, size: 17),
                  label: Text('BEST OVERALL')),
          ]),
          if (smartRank != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _offerComparisonChip(
                Icons.leaderboard_outlined,
                '#${smartRank.rank} • ${smartRank.score.round()}/100',
                bandColor,
              ),
              _offerComparisonChip(
                Icons.attach_money,
                smartRank.bestPrice
                    ? 'Best price'
                    : smartRank.percentOffAsking == null
                        ? 'Price compared'
                        : smartRank.percentOffAsking! <= .05
                            ? 'At / above asking'
                            : '${smartRank.percentOffAsking!.toStringAsFixed(0)}% off',
                smartRank.bestPrice ? Colors.green.shade700 : bandColor,
              ),
              _offerComparisonChip(
                Icons.local_shipping_outlined,
                smartRank.pickupDays == null
                    ? 'Pickup not set'
                    : smartRank.soonestPickup
                        ? 'Soonest pickup • ${smartRank.pickupDays}d'
                        : 'Pickup • ${smartRank.pickupDays}d',
                smartRank.soonestPickup
                    ? Colors.green.shade700
                    : smartRank.pickupDays == null
                        ? Colors.red.shade700
                        : bandColor,
              ),
              _offerComparisonChip(
                Icons.account_balance_outlined,
                smartRank.paymentDays == null
                    ? 'Payment not set'
                    : smartRank.soonestPayment
                        ? 'Soonest payment • ${smartRank.paymentDays}d'
                        : 'Payment • ${smartRank.paymentDays}d',
                smartRank.soonestPayment
                    ? Colors.green.shade700
                    : smartRank.paymentDays == null
                        ? Colors.red.shade700
                        : bandColor,
              ),
            ]),
          ],
          const SizedBox(height: 9),
          Row(children: [
            Expanded(
                child: _metric(
                    'UNIT PRICE',
                    '${priceDifference > 0 ? '↑ ' : priceDifference < 0 ? '↓ ' : '= '}\$${price.toStringAsFixed(2)}',
                    priceDifference > 0
                        ? Colors.green
                        : priceDifference < 0
                            ? Colors.deepOrange
                            : Colors.blue)),
            const SizedBox(width: 8),
            Expanded(
                child: _metric(
                    'QUANTITY',
                    isAll
                        ? 'ALL • $quantity'
                        : availableQuantity == null
                            ? '$quantity'
                            : '$quantity / $availableQuantity'
                                '${quantityPercent == null ? '' : ' • ${quantityPercent.toStringAsFixed(0)}%'}',
                    isAll ? Colors.green : Colors.orange)),
            const SizedBox(width: 8),
            Expanded(
                child: _metric('TOTAL', '\$${total.toStringAsFixed(2)}',
                    isBest ? Colors.green : Colors.blueGrey)),
          ]),
          const SizedBox(height: 10),
          if (milestones.isNotEmpty) ...[
            MarketplaceOfferScheduleCard(milestones: milestones),
            const SizedBox(height: 8),
          ],
          Wrap(spacing: 7, runSpacing: 7, children: [
            if ('${event['truckingPlan'] ?? ''}'.isNotEmpty &&
                event['truckingPlan'] != 'not_specified')
              _truckingPlanChip(event, smartRank: smartRank),
          ]),
          if ('${event['dispatchDeliveryLabel'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 17, color: Color(0xFF0878E8)),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(
                      'Dispatch destination: ${event['dispatchDeliveryLabel']}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF53657A))))
            ])
          ],
          if ('${event['note'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${event['note']}',
                maxLines: 3, overflow: TextOverflow.ellipsis)
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
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: () =>
                      _openBuyerConversation(context, event, offerId),
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Message buyer')),
              FilledButton.icon(
                  onPressed: offerStatus == 'pending'
                      ? () => _acceptSelectedOffer(context, offerId, event)
                      : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(offerStatus == 'pending'
                      ? 'Accept offer'
                      : offerStatus.replaceAll('_', ' ')))
            ]),
            if (revisionCount > 1) ...[
              const SizedBox(height: 8),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                      onPressed: () => _showRevisionHistory(context, revisions),
                      icon: const Icon(Icons.history),
                      label: Text('View all $revisionCount offers')))
            ]
          ]
        ]));
  }

  Widget _offerComparisonChip(IconData icon, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .32)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ]),
      );

  Future<void> _showRevisionHistory(BuildContext context,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> revisions) async {
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
                        })),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Done'))
                ]));
  }

  Widget _revisionAnalyticsCard(Map<String, dynamic> offer, int number) {
    final price = offer['offeredUnitPrice'] as num? ?? 0;
    final quantity = (offer['requestedQuantity'] as num?)?.toInt() ?? 0;
    final total = offer['offeredTotal'] as num? ?? price * quantity;
    final difference = askingPrice == null ? 0 : price - askingPrice!;
    final isAll = availableQuantity != null && quantity == availableQuantity;
    final percent = availableQuantity == null || availableQuantity == 0
        ? null
        : quantity / availableQuantity! * 100;
    final milestones = marketplaceOfferMilestones(offer);
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.shade100)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 15, child: Text('$number')),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Offer $number',
                    style: const TextStyle(fontWeight: FontWeight.w900))),
            Chip(label: Text('${offer['status'] ?? 'pending'}'))
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _metric(
                    'UNIT PRICE',
                    '${difference > 0 ? '↑ ' : difference < 0 ? '↓ ' : '= '}\$${price.toStringAsFixed(2)}',
                    difference > 0
                        ? Colors.green
                        : difference < 0
                            ? Colors.deepOrange
                            : Colors.blue)),
            const SizedBox(width: 7),
            Expanded(
                child: _metric(
                    'QUANTITY',
                    isAll
                        ? 'ALL • $quantity'
                        : availableQuantity == null
                            ? '$quantity'
                            : '$quantity / $availableQuantity • ${percent?.toStringAsFixed(0)}%',
                    isAll ? Colors.green : Colors.orange)),
            const SizedBox(width: 7),
            Expanded(
                child: _metric(
                    'TOTAL', '\$${total.toStringAsFixed(2)}', Colors.blueGrey))
          ]),
          const SizedBox(height: 8),
          if (milestones.isNotEmpty) ...[
            MarketplaceOfferScheduleCard(milestones: milestones),
            const SizedBox(height: 8),
          ],
          Wrap(spacing: 6, runSpacing: 6, children: [
            if ('${offer['truckingPlan'] ?? ''}'.isNotEmpty &&
                offer['truckingPlan'] != 'not_specified')
              _truckingPlanChip(offer),
          ])
        ]));
  }

  Widget _truckingPlanChip(Map<String, dynamic> offer,
      {MarketplaceOfferRank? smartRank}) {
    final plan = '${offer['truckingPlan'] ?? ''}';
    final dispatch = plan == 'request_dispatch';
    final buyerArranged = plan == 'buyer_arranged';
    final dispatchConfirmed = smartRank?.dispatchConfirmed == true;
    final color = buyerArranged
        ? Colors.green.shade700
        : dispatchConfirmed
            ? const Color(0xFF0878E8)
            : dispatch
                ? Colors.deepOrange.shade700
                : Colors.orange.shade800;
    return Chip(
        avatar: Icon(
            dispatch
                ? dispatchConfirmed
                    ? Icons.verified_outlined
                    : Icons.route_outlined
                : buyerArranged
                    ? Icons.local_shipping_outlined
                    : Icons.handshake_outlined,
            size: 16,
            color: color),
        label: Text(dispatch
            ? dispatchConfirmed
                ? 'Dispatch confirmed for requested dates'
                : 'Seeking Dispatch confirmation'
            : buyerArranged
                ? 'Trucking arranged'
                : 'Pickup / seller-arranged'),
        side: BorderSide(color: color.withValues(alpha: .4)));
  }

  Future<void> _showOfferBuyerProfile(
      BuildContext context, String buyerUid, String storedName) async {
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
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  if ('${business['description'] ?? personal['description'] ?? ''}'
                      .isNotEmpty)
                    Text(
                        '${business['description'] ?? personal['description']}'),
                  if ('${business['serviceAreaLabel'] ?? personal['baseCommunity'] ?? ''}'
                      .isNotEmpty)
                    ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(
                            '${business['serviceAreaLabel'] ?? personal['baseCommunity']}')),
                  if ('${business['website'] ?? ''}'.isNotEmpty)
                    ListTile(
                        leading: const Icon(Icons.language),
                        title: Text('${business['website']}')),
                ]),
                actions: [
                  OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        context.push(MarketplaceDeepLinks.profile(buyerUid));
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('View full profile')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'))
                ]));
  }

  Future<void> _openBuyerConversation(
      BuildContext context, Map<String, dynamic> offer, String offerId,
      {bool openOfferComposer = false}) async {
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
          buyerDisplayName:
              '${offer['buyerDisplayName'] ?? 'Marketplace buyer'}');
      if (!context.mounted) return;
      navigator.pop();
      await navigator.push(MaterialPageRoute(
          builder: (_) => MarketplaceChatPage(
              conversationId: id,
              title: listingTitle,
              openOfferComposer: openOfferComposer,
              initialOffer: openOfferComposer ? offer : null)));
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
      BuildContext context, String offerId, Map<String, dynamic> offer) async {
    final decision = await showDialog<MarketplaceOfferDecision>(
      context: context,
      builder: (_) => MarketplaceAcceptOfferDialog(offer: offer),
    );
    if (!context.mounted) return;
    if (decision == MarketplaceOfferDecision.counter) {
      await _openBuyerConversation(context, offer, offerId,
          openOfferComposer: true);
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
          borderRadius: BorderRadius.circular(9)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900))
      ]));
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
  Widget build(BuildContext context) =>
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
          final terminal =
              const {'completed', 'cancelled', 'disputed'}.contains(status);
          final userConfirmed =
              widget.isSeller ? sellerConfirmed : buyerConfirmed;
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
                Row(children: [
                  Icon(Icons.fact_check_outlined, color: _statusColor(status)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Transaction checklist',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Chip(label: Text(_statusLabel(status))),
                ]),
                const SizedBox(height: 5),
                Text(
                  '${_money(transaction['agreedTotal'] ?? widget.offer['offeredTotal'])} • '
                  '${transaction['agreedQuantity'] ?? widget.offer['requestedQuantity'] ?? 0} units',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                Row(children: [
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
                ]),
                if ('${transaction['reason'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    'Reason: ${transaction['reason']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  if (!terminal && !userConfirmed)
                    FilledButton.icon(
                      onPressed:
                          _busy ? null : () => _confirmCompletion(transaction),
                      icon: const Icon(Icons.verified_outlined),
                      label: Text(widget.isSeller
                          ? 'Confirm fulfilled'
                          : 'Confirm received'),
                    ),
                  if (!terminal && !buyerConfirmed && !sellerConfirmed)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _reasonAction('cancel'),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel'),
                    ),
                  if (!terminal)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _reasonAction('dispute'),
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('Open dispute'),
                    ),
                  TextButton.icon(
                    onPressed: snapshot.data!.exists ? _showHistory : null,
                    icon: const Icon(Icons.history),
                    label: const Text('History'),
                  ),
                ]),
                if (_busy) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 3),
                ],
                const SizedBox(height: 6),
                const Text(
                  'Payment and logistics remain between the parties. This checklist records confirmations; it does not hold or release funds.',
                  style: TextStyle(fontSize: 10.5, color: Colors.black54),
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
        child: Row(children: [
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
                Text(party,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(
                  confirmed ? detail : 'Awaiting confirmation',
                  style: const TextStyle(fontSize: 10.5),
                ),
              ],
            ),
          ),
        ]),
      );

  Widget _notice(IconData icon, String message, Color color) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
      );

  Future<void> _confirmCompletion(Map<String, dynamic> transaction) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.verified_outlined, size: 38),
            title: Text(widget.isSeller
                ? 'Confirm the sale was fulfilled?'
                : 'Confirm the purchase was received?'),
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
        title: Text(action == 'cancel'
            ? 'Cancel this transaction?'
            : 'Open a transaction dispute?'),
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
                        subtitle: Text([
                          if ('${data['status'] ?? ''}'.isNotEmpty)
                            '${data['status']}'.replaceAll('_', ' '),
                          if (createdAt != null)
                            _historyDate(createdAt.toDate()),
                        ].join(' • ')),
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
              '${business['publicName'] ?? personal['displayName'] ?? ''}'
                  .trim();
          return _label(resolved.isEmpty ? 'Marketplace buyer' : resolved);
        });
  }

  Widget _label(String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        const Text('Current offer',
            style: TextStyle(fontSize: 11, color: Colors.black54))
      ]);
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
                fallback:
                    const Center(child: Icon(Icons.person_outline, size: 19)));
          });
}

class ListingMessageBadge extends StatelessWidget {
  const ListingMessageBadge(
      {super.key, required this.listingId, required this.sellerUid});
  final String listingId;
  final String sellerUid;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final conversationId = MarketplaceActionsRepository.conversationIdFor(
        uid, sellerUid, listingId);
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
            return const Icon(Icons.chat_bubble,
                size: 17, color: Color(0xFF0878E8));
          }
          return const SizedBox.shrink();
        });
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
        return MarketplaceChatPage(
          conversationId: conversationId,
          title: title,
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

class MarketplaceChatPage extends StatefulWidget {
  const MarketplaceChatPage(
      {super.key,
      required this.conversationId,
      required this.title,
      this.openedFromListing = false,
      this.openOfferComposer = false,
      this.initialOffer});
  final String conversationId;
  final String title;
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
  Map<String, dynamic>? _attachment;

  @override
  void initState() {
    super.initState();
    _actions.markConversationRead(widget.conversationId).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, maxLines: 1), actions: [
        if (widget.openedFromListing)
          IconButton(
              tooltip: 'Return to ad',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.inventory_2_outlined)),
        IconButton(
            tooltip: 'Marketplace home',
            onPressed: () => MarketplaceNavigation.goHome(context),
            icon: const Icon(Icons.home_outlined)),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'report') _reportConversation();
            if (value == 'profile') _openParticipantProfile();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'profile',
                child: ListTile(
                    leading: Icon(Icons.person_outline),
                    title: Text('View member profile'))),
            PopupMenuItem(
                value: 'report',
                child: ListTile(
                    leading:
                        Icon(Icons.flag_outlined, color: Colors.deepOrange),
                    title: Text('Report conversation')))
          ],
        )
      ]),
      body: Column(children: [
        _ConversationNegotiationPanel(
          conversationId: widget.conversationId,
          openComposerOnLoad: widget.openOfferComposer,
          initialOffer: widget.initialOffer,
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('conversations')
                .doc(widget.conversationId)
                .collection('messages')
                .orderBy('createdAt', descending: true)
                .limit(defaultActivityFeedLimit)
                .snapshots(),
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
              if (snapshot.data!.docs.isEmpty) {
                return const MarketplaceDataStateView(
                  kind: MarketplaceDataStateKind.empty,
                  icon: Icons.waving_hand_outlined,
                  title: 'Start the conversation',
                  message: 'Write a message below to contact the seller.',
                  compact: true,
                );
              }
              final reachedWindow =
                  snapshot.data!.docs.length == defaultActivityFeedLimit;
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: snapshot.data!.docs.length + (reachedWindow ? 1 : 0),
                itemBuilder: (context, index) {
                  if (reachedWindow && index == snapshot.data!.docs.length) {
                    return const ListTile(
                      dense: true,
                      leading: Icon(Icons.info_outline),
                      title: Text('Showing the latest 100 messages'),
                      subtitle: Text(
                          'Older messages remain stored in the conversation record.'),
                    );
                  }
                  final message = snapshot.data!.docs[index].data();
                  final mine = message['senderUid'] == uid;
                  final hiddenByModeration =
                      message['moderationVisibility'] == 'hidden';
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 310),
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: mine
                            ? const Color(0xFF0878E8)
                            : const Color(0xFFEAF0F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!hiddenByModeration &&
                                message['attachment'] is Map &&
                                (message['attachment'] as Map)['type'] ==
                                    'image')
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  '${(message['attachment'] as Map)['url']}',
                                  width: 220,
                                  height: 160,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            if (hiddenByModeration)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.gpp_maybe_outlined,
                                        size: 17,
                                        color: mine
                                            ? Colors.white70
                                            : Colors.black54),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Removed by Trust & Safety',
                                        style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: mine
                                                ? Colors.white70
                                                : Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if ('${message['text'] ?? ''}'.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('${message['text'] ?? ''}',
                                    style: TextStyle(
                                        color: mine
                                            ? Colors.white
                                            : Colors.black87)),
                              ),
                          ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Row(children: [
              IconButton(
                  tooltip: 'Add emoji',
                  onPressed: _showEmojiPicker,
                  icon: const Icon(Icons.emoji_emotions_outlined)),
              IconButton(
                  tooltip: 'Attach photo',
                  onPressed: _uploading ? null : _pickAttachment,
                  icon: _uploading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.attach_file)),
              Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_attachment != null)
                  InputChip(
                    avatar: const Icon(Icons.image_outlined),
                    label: Text('${_attachment!['name']}'),
                    onDeleted: () => setState(() => _attachment = null),
                  ),
                TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration:
                        const InputDecoration(hintText: 'Write a message…')),
              ])),
              const SizedBox(width: 6),
              IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded))
            ]),
          ),
        )
      ]),
    );
  }

  Future<void> _openParticipantProfile() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .get();
    final conversation = snapshot.data() ?? {};
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final members =
        List<String>.from(conversation['memberUids'] ?? const <String>[]);
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
    final text = _controller.text.trim();
    if (text.isEmpty && _attachment == null) return;
    setState(() => _sending = true);
    try {
      await _actions.sendChatMessage(widget.conversationId, text,
          attachment: _attachment);
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
      '💰'
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
                        .map((emoji) => InkWell(
                            onTap: () {
                              _controller.text += emoji;
                              _controller.selection = TextSelection.collapsed(
                                  offset: _controller.text.length);
                              Navigator.pop(context);
                            },
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 30))))
                        .toList()))));
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
                'Attach Image or Spec Document',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF0878E8)),
              title: const Text('Choose Photo from Gallery'),
              subtitle:
                  const Text('Select photos of pipe, valves, or equipment'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF10B981)),
              title: const Text('Take Photo with Camera'),
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
      final file = await ImagePicker()
          .pickImage(source: source, imageQuality: 82, maxWidth: 1800);
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
          conversationId: widget.conversationId);
      final authorizationId = '${authorization['authorizationId']}';
      final reference =
          FirebaseStorage.instance.ref('${authorization['storagePath']}');
      await reference.putData(
          await file.readAsBytes(),
          SettableMetadata(
              contentType: contentType,
              customMetadata: {'conversationId': widget.conversationId}));
      final url = await reference.getDownloadURL();
      await _actions.confirmUpload(authorizationId: authorizationId, url: url);
      if (mounted) {
        setState(() => _attachment = {
              'type': 'image',
              'authorizationId': authorizationId,
              'url': url,
              'name': file.name
            });
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
        conversation.data()?['memberUids'] ?? const <String>[]);
    final reportedUid = members.where((member) => member != uid).firstOrNull;
    if (reportedUid == null) return;
    if (!mounted) return;
    final submitted = await showMarketplaceReportDialog(context,
        reportedUid: reportedUid,
        targetType: 'message',
        conversationId: widget.conversationId);
    if (mounted && submitted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Thank you. The conversation and your evidence were sent for private review.')));
    }
  }
}
