import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'marketplace_dispatch_distance.dart';
import 'marketplace_location.dart';

class MarketplaceActionsRepository {
  MarketplaceActionsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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

  Future<void> setSavedListing(String listingId, bool saved) async {
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_listings')
        .doc(listingId);
    if (saved) {
      await ref.set(
          {'listingId': listingId, 'savedAt': FieldValue.serverTimestamp()});
      await recordListingEvent(listingId, 'save');
    } else {
      await ref.delete();
      await recordListingEvent(listingId, 'unsave');
    }
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
    final offer = _firestore.collection('offers').doc(offerId);
    final snapshot = await offer.get();
    final data = snapshot.data() ?? {};
    if (data['sellerUid'] != uid) {
      throw StateError('Only the seller can accept this offer.');
    }
    final buyerUid = '${data['buyerUid'] ?? ''}';
    final listingId = '${data['listingId'] ?? ''}';
    final competing = await _firestore
        .collection('offers')
        .where('sellerUid', isEqualTo: uid)
        .get();
    final batch = _firestore.batch();
    batch.update(offer, {
      'status': 'accepted',
      'acceptedByUid': uid,
      'acceptedAt': FieldValue.serverTimestamp(),
      if (data['dispatchRequested'] == true)
        'dispatchRequestStatus': 'accepting_carrier_bids',
    });
    for (final document in competing.docs) {
      if (document.id == offerId ||
          '${document.data()['listingId'] ?? ''}' != listingId) {
        continue;
      }
      batch.update(document.reference, {
        'status': 'archived',
        'archivedReason': 'another_offer_accepted',
        'acceptedOfferId': offerId,
        'archivedAt': FieldValue.serverTimestamp(),
      });
    }
    if (buyerUid.isNotEmpty) {
      batch.set(
          _firestore
              .collection('users')
              .doc(buyerUid)
              .collection('notifications')
              .doc(),
          {
            'recipientUid': buyerUid,
            'actorUid': uid,
            'type': 'offer',
            'offerId': offerId,
            'listingId': listingId,
            'conversationId': data['conversationId'],
            'title': data['dispatchRequested'] == true
                ? 'Offer accepted — trucking request remains live'
                : 'Your offer was accepted',
            if (data['dispatchRequested'] == true)
              'body':
                  'Open Dispatch → Jobs to review carrier quotes and manage the route.',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    }
    await batch.commit();
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
    if (unitPrice <= 0 || quantity <= 0) {
      throw ArgumentError('Price and quantity must be greater than zero.');
    }
    final conversation =
        _firestore.collection('conversations').doc(conversationId);
    final snapshot = await conversation.get();
    final members =
        List<String>.from(snapshot.data()?['memberUids'] ?? const []);
    if (!members.contains(uid)) throw StateError('Conversation access denied.');
    final buyerUid =
        members.where((member) => member != sellerUid).firstOrNull ?? uid;
    final buyerDisplayName = uid == buyerUid
        ? await _currentOfferDisplayName()
        : '${snapshot.data()?['buyerDisplayName'] ?? 'Marketplace buyer'}';
    final offer = _firestore.collection('offers').doc();
    final recipientUid = members.where((member) => member != uid).firstOrNull;
    final notification = recipientUid == null
        ? null
        : _firestore
            .collection('users')
            .doc(recipientUid)
            .collection('notifications')
            .doc();
    final listing =
        await _firestore.collection('public_listings').doc(listingId).get();
    final total = unitPrice * quantity;
    final askingUnitPrice = listing.data()?['price'] as num?;
    final askingTotal = (askingUnitPrice ?? 0) * quantity;
    final differenceAmount = total - askingTotal;
    final batch = _firestore.batch();
    batch.set(offer, {
      'conversationId': conversationId,
      'listingId': listingId,
      'sellerUid': sellerUid,
      'buyerUid': buyerUid,
      'buyerDisplayName': buyerDisplayName,
      'proposedByUid': uid,
      'askingUnitPrice': askingUnitPrice,
      'offeredUnitPrice': unitPrice,
      'requestedQuantity': quantity,
      'offeredTotal': total,
      'askingTotal': askingTotal,
      'differenceAmount': differenceAmount,
      'differencePercent':
          askingTotal == 0 ? null : differenceAmount / askingTotal * 100,
      'currency': 'CAD',
      'priceBasis': priceBasis,
      'note': note.trim(),
      'purchaseDate':
          purchaseDate == null ? null : Timestamp.fromDate(purchaseDate),
      'moneyTransferDate': moneyTransferDate == null
          ? null
          : Timestamp.fromDate(moneyTransferDate),
      'truckingDate':
          truckingDate == null ? null : Timestamp.fromDate(truckingDate),
      'truckingPlan': truckingPlan,
      'dispatchRequested': truckingPlan == 'request_dispatch',
      if (truckingPlan == 'request_dispatch')
        'dispatchRequestStatus': 'accepting_carrier_bids',
      if (dispatchDelivery.isNotEmpty)
        'dispatchDeliveryLabel': dispatchDelivery,
      if (dispatchDeliveryLocation != null)
        'dispatchDelivery': _dispatchLocationData(dispatchDeliveryLocation),
      'status': 'pending',
      'version': 1,
      'source': 'conversation',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(conversation, {
      'latestNegotiation.unitPrice': unitPrice,
      'latestNegotiation.quantity': quantity,
      'latestNegotiation.total': total,
      'latestNegotiation.proposedByUid': uid,
      'latestNegotiation.status': 'proposed',
      'latestNegotiation.updatedAt': FieldValue.serverTimestamp(),
    });
    if (notification != null) {
      batch.set(notification, {
        'recipientUid': recipientUid,
        'actorUid': uid,
        'type': 'offer',
        'listingId': listingId,
        'offerId': offer.id,
        'conversationId': conversationId,
        'title': uid == sellerUid
            ? 'Seller sent a counter-offer'
            : 'New offer received',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (truckingPlan == 'request_dispatch' &&
        truckingDate != null &&
        dispatchDelivery.isNotEmpty) {
      final dispatchJob = _firestore.collection('dispatch_jobs').doc();
      final pickupPoint = listing.data()?['publicGeoPoint'];
      final deliveryPoint = dispatchDeliveryLocation?.exactGeoPoint;
      final distance = dispatchDistanceKm(
          pickupPoint is GeoPoint ? pickupPoint : null, deliveryPoint);
      final jobValues = <String, dynamic>{
        'createdByUid': uid,
        'title': '${listing.data()?['title'] ?? 'Offer trucking request'}',
        'listingId': listingId,
        'offerId': offer.id,
        'pickupLabel':
            '${listing.data()?['publicLocationName'] ?? listing.data()?['nearestTown'] ?? 'Pickup location to confirm'}',
        'deliveryLabel': dispatchDelivery,
        if (pickupPoint is GeoPoint) 'pickupPoint': pickupPoint,
        if (dispatchDeliveryLocation != null) ...{
          'deliveryPoint': dispatchDeliveryLocation.exactGeoPoint,
          'deliveryAddress': dispatchDeliveryLocation.address.trim(),
          'deliveryTown': dispatchDeliveryLocation.nearestTown.trim(),
          'deliveryRegion': dispatchDeliveryLocation.region.trim(),
          'deliveryPostalCode': dispatchDeliveryLocation.postalCode.trim(),
          'deliveryCountry': dispatchDeliveryLocation.country.trim(),
          'deliveryAccessNotes': dispatchDeliveryLocation.accessNotes.trim(),
        },
        if (distance != null) ...{
          'distanceKm': distance,
          'distanceSource': 'coordinate_estimate',
        },
        'loadDetails':
            '${listing.data()?['title'] ?? 'Marketplace load'} • ${quantity.toString()} units',
        'truckingDate': Timestamp.fromDate(truckingDate),
        'status': 'open',
        'bidCount': 0,
        'revision': 1,
        'source': 'offer',
        'sourceType': 'offer',
        'activationTrigger': 'user_requested',
        'dispatchRequestStatus': 'accepting_carrier_bids',
        'publishedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.set(dispatchJob, jobValues);
      batch.set(dispatchJob.collection('revisions').doc('1'), {
        ...jobValues,
        'event': 'request_created',
        'actorUid': uid,
      });
    }
    await batch.commit();
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
    final listing =
        await _firestore.collection('public_listings').doc(listingId).get();
    final askingTotal = (askingUnitPrice ?? 0) * requestedQuantity;
    final offeredTotal = offeredUnitPrice * requestedQuantity;
    final differenceAmount = offeredTotal - askingTotal;
    final differencePercent =
        askingTotal == 0 ? null : differenceAmount / askingTotal * 100;
    final offer = _firestore.collection('offers').doc();
    final buyerDisplayName = await _currentOfferDisplayName();
    final notification = _firestore
        .collection('users')
        .doc(sellerUid)
        .collection('notifications')
        .doc();
    final batch = _firestore.batch();
    batch.set(offer, {
      'listingId': listingId,
      'buyerUid': uid,
      'buyerDisplayName': buyerDisplayName,
      'sellerUid': sellerUid,
      'proposedByUid': uid,
      'askingUnitPrice': askingUnitPrice,
      'offeredUnitPrice': offeredUnitPrice,
      'requestedQuantity': requestedQuantity,
      'availableQuantityAtOffer': availableQuantity,
      'priceBasis': priceBasis,
      'askingTotal': askingTotal,
      'offeredTotal': offeredTotal,
      'differenceAmount': differenceAmount,
      'differencePercent': differencePercent,
      'currency': 'CAD',
      'note': note,
      'purchaseDate':
          purchaseDate == null ? null : Timestamp.fromDate(purchaseDate),
      'moneyTransferDate': moneyTransferDate == null
          ? null
          : Timestamp.fromDate(moneyTransferDate),
      'truckingDate':
          truckingDate == null ? null : Timestamp.fromDate(truckingDate),
      'truckingPlan': truckingPlan,
      'dispatchRequested': truckingPlan == 'request_dispatch',
      if (truckingPlan == 'request_dispatch')
        'dispatchRequestStatus': 'accepting_carrier_bids',
      if (dispatchDelivery.isNotEmpty)
        'dispatchDeliveryLabel': dispatchDelivery,
      if (dispatchDeliveryLocation != null)
        'dispatchDelivery': _dispatchLocationData(dispatchDeliveryLocation),
      'status': 'pending',
      'version': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(notification, {
      'recipientUid': sellerUid,
      'actorUid': uid,
      'type': 'offer',
      'listingId': listingId,
      'offerId': offer.id,
      'title': 'New offer received',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (truckingPlan == 'request_dispatch' &&
        truckingDate != null &&
        dispatchDelivery.isNotEmpty) {
      final dispatchJob = _firestore.collection('dispatch_jobs').doc();
      final pickupPoint = listing.data()?['publicGeoPoint'];
      final deliveryPoint = dispatchDeliveryLocation?.exactGeoPoint;
      final distance = dispatchDistanceKm(
          pickupPoint is GeoPoint ? pickupPoint : null, deliveryPoint);
      final jobValues = <String, dynamic>{
        'createdByUid': uid,
        'title': listingTitle.isEmpty ? 'Offer trucking request' : listingTitle,
        'listingId': listingId,
        'offerId': offer.id,
        'pickupLabel':
            pickupLabel.isEmpty ? 'Pickup location to confirm' : pickupLabel,
        'deliveryLabel': dispatchDelivery,
        if (pickupPoint is GeoPoint) 'pickupPoint': pickupPoint,
        if (dispatchDeliveryLocation != null) ...{
          'deliveryPoint': dispatchDeliveryLocation.exactGeoPoint,
          'deliveryAddress': dispatchDeliveryLocation.address.trim(),
          'deliveryTown': dispatchDeliveryLocation.nearestTown.trim(),
          'deliveryRegion': dispatchDeliveryLocation.region.trim(),
          'deliveryPostalCode': dispatchDeliveryLocation.postalCode.trim(),
          'deliveryCountry': dispatchDeliveryLocation.country.trim(),
          'deliveryAccessNotes': dispatchDeliveryLocation.accessNotes.trim(),
        },
        if (distance != null) ...{
          'distanceKm': distance,
          'distanceSource': 'coordinate_estimate',
        },
        'loadDetails':
            '${listingTitle.isEmpty ? 'Marketplace load' : listingTitle} • $requestedQuantity units',
        'truckingDate': Timestamp.fromDate(truckingDate),
        'status': 'open',
        'bidCount': 0,
        'revision': 1,
        'source': 'offer',
        'sourceType': 'offer',
        'activationTrigger': 'user_requested',
        'dispatchRequestStatus': 'accepting_carrier_bids',
        'publishedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.set(dispatchJob, jobValues);
      batch.set(dispatchJob.collection('revisions').doc('1'), {
        ...jobValues,
        'event': 'request_created',
        'actorUid': uid,
      });
    }
    await batch.commit();
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

Map<String, dynamic> _dispatchLocationData(MarketplaceLocation location) => {
      'label': location.publicName.trim(),
      'address': location.address.trim(),
      'nearestTown': location.nearestTown.trim(),
      'region': location.region.trim(),
      'postalCode': location.postalCode.trim(),
      'country': location.country.trim(),
      'point': location.exactGeoPoint,
      'accessNotes': location.accessNotes.trim(),
      'privacy': 'offer_participants_and_awarded_carrier',
    };
