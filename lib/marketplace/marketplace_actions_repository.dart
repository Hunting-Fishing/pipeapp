import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/data/bounded_firestore_query.dart';
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
        .limit(defaultReferenceDataLimit)
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
    final conversationId = await ensureConversation(
        listingId: listingId,
        listingTitle: listingTitle,
        sellerUid: sellerUid,
        sellerName: sellerName);
    await sendChatMessage(conversationId, text);
    return conversationId;
  }

  Future<String> ensureConversation({
    required String listingId,
    required String listingTitle,
    required String sellerUid,
    required String sellerName,
  }) async {
    final result = await _commands.execute('openMarketplaceConversation', {
      'listingId': listingId,
    });
    return '${result['conversationId']}';
  }

  Future<void> sendChatMessage(String conversationId, String text,
      {Map<String, dynamic>? attachment}) async {
    await _commands.execute('sendMarketplaceMessage', {
      'requestId': _firestore.collection('messages').doc().id,
      'conversationId': conversationId,
      'text': text,
      if (attachment != null) 'attachment': attachment,
    });
  }

  Future<void> markConversationRead(String conversationId) async {
    await _commands.execute('markMarketplaceConversationRead', {
      'conversationId': conversationId,
    });
  }

  Future<Map<String, dynamic>> readConversationBlockStatus(
    String conversationId,
  ) =>
      _commands.execute('readMarketplaceUserBlockStatus', {
        'conversationId': conversationId,
      });

  Future<Map<String, dynamic>> setConversationBlocked(
    String conversationId, {
    required bool blocked,
  }) =>
      _commands.execute('setMarketplaceUserBlocked', {
        'conversationId': conversationId,
        'blocked': blocked,
      });

  Future<String> ensureOfferConversation({
    required String listingId,
    required String listingTitle,
    required String sellerUid,
    required String buyerUid,
    required String buyerDisplayName,
    required String offerId,
  }) async {
    if (uid != sellerUid && uid != buyerUid) {
      throw StateError('Only offer participants can open this conversation.');
    }
    final result = await _commands.execute('openMarketplaceConversation', {
      'listingId': listingId,
      'participantUid': buyerUid,
      'offerId': offerId,
    });
    return '${result['conversationId']}';
  }

  Future<String> openBusinessConversation({
    required String providerUid,
  }) async {
    final normalized = providerUid.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
          providerUid, 'providerUid', 'Provider is required.');
    }
    final result = await _commands.execute('openBusinessConversation', {
      'providerUid': normalized,
    });
    return '${result['conversationId']}';
  }

  Future<Map<String, dynamic>> authorizeUpload({
    required String purpose,
    required String originalName,
    required String contentType,
    required int sizeBytes,
    String? conversationId,
    String? reportId,
  }) =>
      _commands.execute('authorizeMarketplaceUpload', {
        'requestId':
            _firestore.collection('media_upload_authorizations').doc().id,
        'purpose': purpose,
        'originalName': originalName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
        if (conversationId != null) 'conversationId': conversationId,
        if (reportId != null) 'reportId': reportId,
      });

  Future<void> confirmUpload({
    required String authorizationId,
    required String url,
  }) async {
    await _commands.execute('confirmMarketplaceUpload', {
      'authorizationId': authorizationId,
      'url': url,
    });
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
