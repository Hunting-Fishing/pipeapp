import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'marketplace_location.dart';
import 'marketplace_command_client.dart';

class MarketplaceActionsRepository {
  MarketplaceActionsRepository({
    FirebaseFirestore? firestore,
    MarketplaceCommandClient? commandClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _commands = commandClient ?? MarketplaceCommandClient();

  final FirebaseFirestore _firestore;
  final MarketplaceCommandClient _commands;

  static String conversationIdFor(
      String userUid, String sellerUid, String listingId) {
    final members = [userUid, sellerUid]..sort();
    return '${members[0]}_${members[1]}_$listingId';
  }

  String get uid {
    final value = FirebaseAuth.instance.currentUser?.uid;
    if (value == null) throw StateError('Sign in to continue.');
    return value;
  }

  Stream<Set<String>> watchSavedListingIds(String userUid) {
    if (userUid.trim().isEmpty) {
      return Stream<Set<String>>.value(<String>{});
    }
    return _firestore
        .collection('users')
        .doc(userUid)
        .collection('saved_listings')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map(
            (snapshot) => snapshot.docs.map((document) => document.id).toSet());
  }

  Future<void> setSavedListing(
    String listingId,
    bool saved, {
    required String requestId,
  }) async {
    await _commands.execute('setMarketplaceListingSaved', {
      'requestId': requestId,
      'listingId': listingId,
      'saved': saved,
    });
  }

  Future<void> recordListingEvent(String listingId, String type,
          {Map<String, dynamic> metadata = const {}}) =>
      _firestore.collection('listing_events').add({
        'listingId': listingId,
        'actorUid': uid,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
        ...metadata,
      });

  Future<void> followSeller(String sellerUid,
      {required bool follow, required bool notify}) async {
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('followed_sellers')
        .doc(sellerUid);
    if (!follow) return ref.delete();
    await ref.set({
      'sellerUid': sellerUid,
      'notifyNewListings': notify,
      'followedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> sendMessage({
    required String listingId,
    required String listingTitle,
    required String sellerUid,
    required String sellerName,
    required String text,
  }) async {
    if (sellerUid == uid) throw StateError('This is your listing.');
    final members = [uid, sellerUid]..sort();
    final conversationId = conversationIdFor(uid, sellerUid, listingId);
    final conversation =
        _firestore.collection('conversations').doc(conversationId);
    final message = conversation.collection('messages').doc();
    final notification = _firestore
        .collection('users')
        .doc(sellerUid)
        .collection('notifications')
        .doc();
    final batch = _firestore.batch();
    batch.set(
        conversation,
        {
          'memberUids': members,
          'listingId': listingId,
          'listingTitle': listingTitle,
          'sellerUid': sellerUid,
          'sellerName': sellerName,
          'lastMessage': text,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'messageCount': FieldValue.increment(1),
          'unreadCounts.$sellerUid': FieldValue.increment(1),
          'unreadCounts.$uid': 0,
        },
        SetOptions(merge: true));
    batch.set(message, {
      'senderUid': uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(notification, {
      'recipientUid': sellerUid,
      'actorUid': uid,
      'type': 'message',
      'listingId': listingId,
      'conversationId': conversationId,
      'title': 'New message about $listingTitle',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return conversationId;
  }

  Future<String> ensureConversation({
    required String listingId,
    required String listingTitle,
    required String sellerUid,
    required String sellerName,
  }) async {
    if (sellerUid == uid) throw StateError('This is your listing.');
    final members = [uid, sellerUid]..sort();
    final conversationId = conversationIdFor(uid, sellerUid, listingId);
    final reference =
        _firestore.collection('conversations').doc(conversationId);
    final buyerDisplayName = await _currentOfferDisplayName();
    final existing = await reference.get();
    final existingData = existing.data() ?? const <String, dynamic>{};
    await reference.set({
      'memberUids': members,
      'listingId': listingId,
      'listingTitle': listingTitle,
      'sellerUid': sellerUid,
      'sellerName': sellerName,
      'buyerDisplayName': buyerDisplayName,
      'openedByUid': uid,
      'openedAt': FieldValue.serverTimestamp(),
      if (existingData['messageCount'] is! num) 'messageCount': 0,
      if (existingData['unreadCounts'] is! Map)
        'unreadCounts': {uid: 0, sellerUid: 0},
    }, SetOptions(merge: true));
    return conversationId;
  }

  Future<void> sendChatMessage(String conversationId, String text,
      {Map<String, dynamic>? attachment}) async {
    final conversation =
        _firestore.collection('conversations').doc(conversationId);
    final snapshot = await conversation.get();
    final members =
        List<String>.from(snapshot.data()?['memberUids'] ?? const []);
    final recipients = members.where((member) => member != uid);
    if (recipients.isEmpty) throw StateError('Conversation recipient missing.');
    final recipient = recipients.first;
    final unreadCounts = Map<String, dynamic>.from(
        snapshot.data()?['unreadCounts'] is Map
            ? snapshot.data()!['unreadCounts'] as Map
            : const {});
    unreadCounts[recipient] =
        ((unreadCounts[recipient] as num?)?.toInt() ?? 0) + 1;
    unreadCounts[uid] = 0;
    final messageCount =
        ((snapshot.data()?['messageCount'] as num?)?.toInt() ?? 0) + 1;
    final message = conversation.collection('messages').doc();
    final notification = _firestore
        .collection('users')
        .doc(recipient)
        .collection('notifications')
        .doc();
    final batch = _firestore.batch();
    batch.update(conversation, {
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'messageCount': messageCount,
      'unreadCounts': unreadCounts,
    });
    batch.set(message, {
      'senderUid': uid,
      'text': text,
      if (attachment != null) 'attachment': attachment,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(notification, {
      'recipientUid': recipient,
      'actorUid': uid,
      'type': 'message',
      'listingId': snapshot.data()?['listingId'],
      'conversationId': conversationId,
      'title': 'New marketplace message',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> markConversationRead(String conversationId) async {
    final reference =
        _firestore.collection('conversations').doc(conversationId);
    final snapshot = await reference.get();
    if (!snapshot.exists) return;
    final unreadCounts = Map<String, dynamic>.from(
        snapshot.data()?['unreadCounts'] is Map
            ? snapshot.data()!['unreadCounts'] as Map
            : const {});
    unreadCounts[uid] = 0;
    await reference.update({'unreadCounts': unreadCounts});
  }

  Future<String> ensureOfferConversation({
    required String listingId,
    required String listingTitle,
    required String sellerUid,
    required String buyerUid,
    required String buyerDisplayName,
  }) async {
    if (uid != sellerUid && uid != buyerUid) {
      throw StateError('Only offer participants can open this conversation.');
    }
    final conversationId = conversationIdFor(buyerUid, sellerUid, listingId);
    final reference =
        _firestore.collection('conversations').doc(conversationId);
    final existing = await reference.get();
    final existingData = existing.data() ?? const <String, dynamic>{};
    await reference.set({
      'memberUids': [buyerUid, sellerUid]..sort(),
      'listingId': listingId,
      'listingTitle': listingTitle,
      'sellerUid': sellerUid,
      'buyerDisplayName': buyerDisplayName,
      'openedAt': FieldValue.serverTimestamp(),
      if (existingData['messageCount'] is! num) 'messageCount': 0,
      if (existingData['unreadCounts'] is! Map)
        'unreadCounts': {buyerUid: 0, sellerUid: 0},
    }, SetOptions(merge: true));
    return conversationId;
  }

  Future<void> acceptOffer(String offerId) async {
    await _commands.execute('acceptMarketplaceOffer', {
      'offerId': offerId,
    });
  }

  Future<void> updateMarketplaceTransaction(
    String offerId,
    String action, {
    String reason = '',
  }) async {
    await _commands.execute('updateMarketplaceTransaction', {
      'requestId': 'transaction-$offerId-$action-$uid',
      'offerId': offerId,
      'action': action,
      if (reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<void> makeConversationOffer({
    required String conversationId,
    required String listingId,
    required String sellerUid,
    required num unitPrice,
    required int quantity,
    required String priceBasis,
    String note = '',
    DateTime? purchaseDate,
    DateTime? moneyTransferDate,
    DateTime? truckingDate,
    String truckingPlan = 'not_specified',
    String dispatchDelivery = '',
    MarketplaceLocation? dispatchDeliveryLocation,
  }) async {
    await _commands.execute('createMarketplaceOffer', {
      'requestId': _firestore.collection('offers').doc().id,
      'conversationId': conversationId,
      'listingId': listingId,
      'offeredUnitPrice': unitPrice,
      'requestedQuantity': quantity,
      'note': note.trim(),
      if (purchaseDate != null)
        'purchaseDate': purchaseDate.millisecondsSinceEpoch,
      if (moneyTransferDate != null)
        'moneyTransferDate': moneyTransferDate.millisecondsSinceEpoch,
      if (truckingDate != null)
        'truckingDate': truckingDate.millisecondsSinceEpoch,
      'truckingPlan': truckingPlan,
      if (dispatchDeliveryLocation != null)
        'dispatchDelivery':
            _dispatchCommandLocationData(dispatchDeliveryLocation),
    });
  }

  Future<void> makeOffer({
    required String listingId,
    required String sellerUid,
    required num offeredUnitPrice,
    required int requestedQuantity,
    required num? askingUnitPrice,
    required int? availableQuantity,
    required String priceBasis,
    String note = '',
    DateTime? purchaseDate,
    DateTime? moneyTransferDate,
    DateTime? truckingDate,
    String truckingPlan = 'not_specified',
    String dispatchDelivery = '',
    MarketplaceLocation? dispatchDeliveryLocation,
    String listingTitle = '',
    String pickupLabel = '',
  }) async {
    await _commands.execute('createMarketplaceOffer', {
      'requestId': _firestore.collection('offers').doc().id,
      'listingId': listingId,
      'offeredUnitPrice': offeredUnitPrice,
      'requestedQuantity': requestedQuantity,
      'note': note.trim(),
      if (purchaseDate != null)
        'purchaseDate': purchaseDate.millisecondsSinceEpoch,
      if (moneyTransferDate != null)
        'moneyTransferDate': moneyTransferDate.millisecondsSinceEpoch,
      if (truckingDate != null)
        'truckingDate': truckingDate.millisecondsSinceEpoch,
      'truckingPlan': truckingPlan,
      if (dispatchDeliveryLocation != null)
        'dispatchDelivery':
            _dispatchCommandLocationData(dispatchDeliveryLocation),
    });
  }

  Future<String> _currentOfferDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Marketplace buyer';
    try {
      final personal = await _firestore.collection('users').doc(user.uid).get();
      final accountType = '${personal.data()?['accountType'] ?? 'personal'}';
      if (accountType == 'business') {
        final business = await _firestore
            .collection('public_business_profiles')
            .doc(user.uid)
            .get();
        final businessName = '${business.data()?['publicName'] ?? ''}'.trim();
        if (businessName.isNotEmpty) return businessName;
      }
      final personalName =
          '${personal.data()?['display_name'] ?? user.displayName ?? ''}'
              .trim();
      if (personalName.isNotEmpty) return personalName;
    } catch (_) {}
    return user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'Marketplace buyer';
  }

  Future<void> requestLocation({
    required String listingId,
    required String sellerUid,
    String note = '',
  }) =>
      _firestore.collection('location_requests').add({
        'listingId': listingId,
        'requesterUid': uid,
        'sellerUid': sellerUid,
        'note': note,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
}

Map<String, dynamic> _dispatchCommandLocationData(
        MarketplaceLocation location) =>
    {
      'label': location.publicName.trim(),
      'address': location.address.trim(),
      'nearestTown': location.nearestTown.trim(),
      'region': location.region.trim(),
      'postalCode': location.postalCode.trim(),
      'country': location.country.trim(),
      'latitude': location.point.latitude,
      'longitude': location.point.longitude,
      'accessNotes': location.accessNotes.trim(),
    };
