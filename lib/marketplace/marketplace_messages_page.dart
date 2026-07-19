import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'marketplace_reporting.dart';

import 'marketplace_actions_repository.dart';
import 'marketplace_auth_page.dart';
import 'marketplace_navigation.dart';
import 'marketplace_public_profile_page.dart';
import 'marketplace_avatar_image.dart';
import 'marketplace_trucking_plan.dart';
import 'marketplace_location.dart';

class MarketplaceMessagesPage extends StatelessWidget {
  const MarketplaceMessagesPage({super.key});

  static Stream<int> unreadCountStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('conversations')
        .where('memberUids', arrayContains: uid)
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
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadFailure(
              message: 'Could not load conversations.', error: snapshot.error);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final conversations = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTime = a.data()['lastMessageAt'] as Timestamp?;
            final bTime = b.data()['lastMessageAt'] as Timestamp?;
            return (bTime?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
          });
        if (conversations.isEmpty) return const _EmptyMessages();
        return ListView.separated(
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
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MarketplaceChatPage(
                        conversationId: doc.id, title: title))),
              ),
            );
          },
        );
      },
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, this.error});
  final String message;
  final Object? error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.sync_problem_outlined,
                size: 48, color: Colors.deepOrange),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text('$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.currentUser?.reload();
                  await FirebaseAuth.instance.currentUser?.getIdToken(true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                            'Account refreshed. Reopen Messages to retry.')));
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh account'))
          ]),
        ),
      );
}

class _ConversationNegotiationPanel extends StatefulWidget {
  const _ConversationNegotiationPanel({required this.conversationId});
  final String conversationId;

  @override
  State<_ConversationNegotiationPanel> createState() =>
      _ConversationNegotiationPanelState();
}

class _ConversationNegotiationPanelState
    extends State<_ConversationNegotiationPanel> {
  final _actions = MarketplaceActionsRepository();

  @override
  Widget build(BuildContext context) => StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
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
                            child: Icon(Icons.local_offer_outlined, size: 20)),
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

  Future<void> _openOffers(
      Map<String, dynamic> conversation, Map<String, dynamic> listing) async {
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
      Map<String, dynamic> conversation, Map<String, dynamic> listing) async {
    final latest = Map<String, dynamic>.from(
        conversation['latestNegotiation'] as Map? ?? {});
    final price = TextEditingController(
        text: '${latest['unitPrice'] ?? listing['price'] ?? ''}');
    final quantity = TextEditingController(
        text: '${latest['quantity'] ?? listing['quantity'] ?? 1}');
    final note = TextEditingController();
    MarketplaceLocation? dispatchDeliveryLocation;
    DateTime? purchaseDate;
    DateTime? moneyTransferDate;
    DateTime? truckingDate;
    MarketplaceTruckingPlan? truckingPlan;
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
          title: const Text('Make an offer'),
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
                child: const Text('Review offer'))
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
            title: const Text('Review and send offer'),
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
                  child: const Text('Send proposal'))
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  truckingPlan == MarketplaceTruckingPlan.requestDispatch
                      ? 'Offer submitted. Dispatch request saved as a draft.'
                      : 'Offer submitted and added to offer history.')));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('The proposal could not be sent.')));
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

class MarketplaceNegotiationHistory extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final isSeller = uid == sellerUid;
    final roleField = isSeller ? 'sellerUid' : 'buyerUid';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('offers')
            .where(roleField, isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
                padding: EdgeInsets.all(12), child: LinearProgressIndicator());
          }
          final events = snapshot.data!.docs
              .where((doc) =>
                  doc.data()['listingId'] == listingId &&
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
            return Center(
                child: Text(
                    'Seller asks ${askingPrice == null ? 'contact for price' : '\$${askingPrice!.toStringAsFixed(2)}'}'
                    '${availableQuantity == null ? '' : ' for up to $availableQuantity units'}.\n'
                    'No offers have been submitted yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54)));
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
              (best, event) =>
                  (event.data()['offeredTotal'] as num? ?? 0) > best
                      ? event.data()['offeredTotal'] as num
                      : best);
          return Column(children: [
            if (isSeller)
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEAF4FD),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.analytics_outlined,
                        color: Color(0xFF0878E8)),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Text(
                            '${revisionsByBuyer.length} buyer${revisionsByBuyer.length == 1 ? '' : 's'} • '
                            '${events.length} total offer${events.length == 1 ? '' : 's'}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900))),
                    Text('Best \$${bestTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, color: Colors.green))
                  ])),
            Expanded(
                child: ListView.separated(
                    itemCount: displayed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final document = displayed[index];
                      final event = document.data();
                      final buyer = '${event['buyerUid'] ?? ''}';
                      return _offerCard(event,
                          context: context,
                          offerId: document.id,
                          isSeller: isSeller,
                          isBest:
                              (event['offeredTotal'] as num? ?? 0) == bestTotal,
                          revisions: revisionsByBuyer[buyer] ?? const []);
                    }))
          ]);
        });
  }

  Widget _offerCard(Map<String, dynamic> event,
      {required BuildContext context,
      required String offerId,
      required bool isSeller,
      required bool isBest,
      required List<QueryDocumentSnapshot<Map<String, dynamic>>> revisions}) {
    final price = event['offeredUnitPrice'] as num? ?? 0;
    final quantity = (event['requestedQuantity'] as num?)?.toInt() ?? 0;
    final total = event['offeredTotal'] as num? ?? price * quantity;
    final isAll = availableQuantity != null && quantity == availableQuantity;
    final purchase = event['purchaseDate'] as Timestamp?;
    final trucking = event['truckingDate'] as Timestamp?;
    final transfer = event['moneyTransferDate'] as Timestamp?;
    final revisionCount = revisions.length;
    final priceDifference = askingPrice == null ? 0 : price - askingPrice!;
    final quantityPercent = availableQuantity == null || availableQuantity == 0
        ? null
        : quantity / availableQuantity! * 100;
    return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: isBest ? const Color(0xFFEAF8F1) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color:
                    isBest ? Colors.green.shade400 : Colors.blueGrey.shade100,
                width: isBest ? 1.5 : 1)),
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
            if (event['status'] == 'accepted')
              const Chip(
                  avatar: Icon(Icons.check_circle, size: 17),
                  label: Text('ACCEPTED'))
            else if (isBest)
              const Chip(
                  avatar: Icon(Icons.emoji_events_outlined, size: 17),
                  label: Text('BEST PRICE')),
          ]),
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
          Wrap(spacing: 7, runSpacing: 7, children: [
            if (purchase != null)
              _dateChip('Purchase', purchase, Icons.event_available_outlined),
            if (transfer != null)
              _dateChip('Transfer', transfer, Icons.account_balance_outlined),
            if (trucking != null)
              _dateChip('Trucking', trucking, Icons.local_shipping_outlined),
            if ('${event['truckingPlan'] ?? ''}'.isNotEmpty &&
                event['truckingPlan'] != 'not_specified')
              _truckingPlanChip(event),
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
          if (isSeller) ...[
            const Divider(height: 20),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: () => _openBuyerConversation(context, event),
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Message buyer')),
              FilledButton.icon(
                  onPressed: event['status'] == 'accepted'
                      ? null
                      : () => _acceptSelectedOffer(context, offerId, event),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(event['status'] == 'accepted'
                      ? 'Accepted'
                      : 'Accept offer'))
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
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (offer['purchaseDate'] is Timestamp)
              _dateChip('Purchase', offer['purchaseDate'] as Timestamp,
                  Icons.event_available_outlined),
            if (offer['moneyTransferDate'] is Timestamp)
              _dateChip('Transfer', offer['moneyTransferDate'] as Timestamp,
                  Icons.account_balance_outlined),
            if (offer['truckingDate'] is Timestamp)
              _dateChip('Trucking', offer['truckingDate'] as Timestamp,
                  Icons.local_shipping_outlined),
            if ('${offer['truckingPlan'] ?? ''}'.isNotEmpty &&
                offer['truckingPlan'] != 'not_specified')
              _truckingPlanChip(offer),
          ])
        ]));
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
                    : Colors.blueGrey),
        label: Text(dispatch
            ? 'Dispatch requested'
            : buyerArranged
                ? 'Buyer has trucking'
                : 'Pickup / seller-arranged'));
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
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => MarketplacePublicProfilePage(
                                userUid: buyerUid,
                                fallbackName: name.isEmpty
                                    ? 'Marketplace buyer'
                                    : name)));
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('View full profile')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'))
                ]));
  }

  Future<void> _openBuyerConversation(
      BuildContext context, Map<String, dynamic> offer) async {
    final buyerUid = '${offer['buyerUid'] ?? ''}';
    if (buyerUid.isEmpty) return;
    final navigator = Navigator.of(context);
    try {
      final id = await MarketplaceActionsRepository().ensureOfferConversation(
          listingId: listingId,
          listingTitle: listingTitle,
          sellerUid: sellerUid,
          buyerUid: buyerUid,
          buyerDisplayName:
              '${offer['buyerDisplayName'] ?? 'Marketplace buyer'}');
      if (!context.mounted) return;
      navigator.pop();
      await navigator.push(MaterialPageRoute(
          builder: (_) =>
              MarketplaceChatPage(conversationId: id, title: listingTitle)));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('The buyer conversation could not be opened.')));
      }
    }
  }

  Future<void> _acceptSelectedOffer(
      BuildContext context, String offerId, Map<String, dynamic> offer) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
              icon: const Icon(Icons.handshake_outlined, size: 40),
              title: const Text('Accept this offer?'),
              content: Text(
                  'Accept \$${(offer['offeredTotal'] as num? ?? 0).toStringAsFixed(2)} '
                  'for ${offer['requestedQuantity'] ?? 0} units?\n\n'
                  'The buyer will be notified, all competing offers for this listing will be archived, '
                  'and their conversation will open so you can finalize the purchase.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Accept offer'))
              ]),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await MarketplaceActionsRepository().acceptOffer(offerId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Offer accepted. Other offers were archived.')));
        await _openBuyerConversation(context, offer);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.red,
            content: Text('The offer could not be accepted.')));
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

  Widget _dateChip(String label, Timestamp value, IconData icon) {
    final days = value.toDate().difference(DateTime.now()).inDays;
    final color = days <= 7
        ? Colors.green
        : days <= 30
            ? Colors.orange
            : Colors.blueGrey;
    return Chip(
        backgroundColor: color.withValues(alpha: .1),
        side: BorderSide(color: color.withValues(alpha: .35)),
        avatar: Icon(icon, size: 17, color: color),
        label: Text('$label ${_historyDate(value)} • '
            '${days <= 0 ? 'now' : '$days days'}'));
  }

  String _historyDate(Timestamp value) {
    final date = value.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
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
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.forum_outlined, size: 54),
            const SizedBox(height: 12),
            const Text('Sign in to view your marketplace messages.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            FilledButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const MarketplaceAuthPage())),
                child: const Text('Sign in or create account'))
          ])));
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();
  @override
  Widget build(BuildContext context) => const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.chat_bubble_outline, size: 52, color: Color(0xFF66758A)),
        SizedBox(height: 10),
        Text('No marketplace conversations yet.'),
        Text('Open a listing and message the seller.',
            style: TextStyle(color: Color(0xFF66758A), fontSize: 12))
      ]));
}

class MarketplaceChatPage extends StatefulWidget {
  const MarketplaceChatPage(
      {super.key,
      required this.conversationId,
      required this.title,
      this.openedFromListing = false});
  final String conversationId;
  final String title;
  final bool openedFromListing;
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
        _ConversationNegotiationPanel(conversationId: widget.conversationId),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('conversations')
                .doc(widget.conversationId)
                .collection('messages')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.error_outline,
                              size: 42, color: Colors.red),
                          const SizedBox(height: 10),
                          const Text('Conversation could not be loaded.',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('$error', textAlign: TextAlign.center)
                        ])));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.waving_hand_outlined,
                              size: 42, color: Color(0xFF0878E8)),
                          SizedBox(height: 10),
                          Text('Start the conversation',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                          Text('Write a message below to contact the seller.',
                              textAlign: TextAlign.center)
                        ])));
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final message = snapshot.data!.docs[index].data();
                  final mine = message['senderUid'] == uid;
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
                            if (message['attachment'] is Map &&
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
                            if ('${message['text'] ?? ''}'.isNotEmpty)
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('The other member’s profile is unavailable.')));
      }
      return;
    }
    final fallbackName = currentUid == conversation['sellerUid']
        ? '${conversation['buyerDisplayName'] ?? 'Marketplace buyer'}'
        : '${conversation['sellerName'] ?? 'Marketplace seller'}';
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MarketplacePublicProfilePage(
            userUid: otherUid, fallbackName: fallbackName)));
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message could not be sent.')));
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
    try {
      final file = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 82, maxWidth: 1800);
      if (file == null) return;
      if (await file.length() > 15 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Attachment must be under 15 MB.')));
        }
        return;
      }
      setState(() => _uploading = true);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final extension = file.name.split('.').last.toLowerCase();
      final contentType = extension == 'png'
          ? 'image/png'
          : extension == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      final reference = FirebaseStorage.instance.ref(
          'chat_attachments/${widget.conversationId}/$uid/${DateTime.now().millisecondsSinceEpoch}_${file.name}');
      await reference.putData(
          await file.readAsBytes(),
          SettableMetadata(
              contentType: contentType,
              customMetadata: {'conversationId': widget.conversationId}));
      final url = await reference.getDownloadURL();
      if (mounted) {
        setState(() =>
            _attachment = {'type': 'image', 'url': url, 'name': file.name});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            content: Text('Image attached. Add a message or press Send.')));
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            content: Text(error.code == 'unauthorized'
                ? 'Image upload is not authorized. Refresh your account and try again.'
                : 'Image upload failed (${error.code}). Please try again.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            content: Text('Could not attach this image. Try another file.')));
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
