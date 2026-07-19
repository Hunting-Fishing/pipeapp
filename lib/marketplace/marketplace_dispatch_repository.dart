import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'marketplace_location.dart';
import 'marketplace_service_area.dart';
import 'marketplace_dispatch_distance.dart';
import 'marketplace_command_client.dart';
import 'regional_phone_field.dart';

class MarketplaceDispatchRepository {
  MarketplaceDispatchRepository({
    MarketplaceCommandClient? commandClient,
  }) : _commands = commandClient ?? MarketplaceCommandClient();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MarketplaceCommandClient _commands;
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<DocumentSnapshot<Map<String, dynamic>>> carrierProfile() =>
      _firestore.collection('dispatch_carriers').doc(uid).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> fleet() => _firestore
      .collection('dispatch_carriers')
      .doc(uid)
      .collection('vehicles')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> savedQuotes() => _firestore
      .collection('dispatch_carriers')
      .doc(uid)
      .collection('saved_quotes')
      .orderBy('updatedAt', descending: true)
      .snapshots();

  Future<String> saveQuote(Map<String, dynamic> quote,
      {String? quoteId}) async {
    final collection = _firestore
        .collection('dispatch_carriers')
        .doc(uid)
        .collection('saved_quotes');
    final reference =
        quoteId == null ? collection.doc() : collection.doc(quoteId);
    final existing = await reference.get();
    final revision = (existing.data()?['revision'] as num? ?? 0).toInt() + 1;
    final batch = _firestore.batch();
    batch.set(
        reference,
        {
          ...quote,
          'ownerUid': uid,
          'revision': revision,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.set(reference.collection('revisions').doc('$revision'), {
      ...quote,
      'ownerUid': uid,
      'revision': revision,
      'event': existing.exists ? 'quote_updated' : 'quote_created',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return reference.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> savedQuoteHistory(
          String quoteId) =>
      _firestore
          .collection('dispatch_carriers')
          .doc(uid)
          .collection('saved_quotes')
          .doc(quoteId)
          .collection('revisions')
          .orderBy('revision', descending: true)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> openJobs() => _firestore
      .collection('dispatch_jobs')
      .where('status', isEqualTo: 'open')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> myJobs() => _firestore
      .collection('dispatch_jobs')
      .where('createdByUid', isEqualTo: uid)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> myBids() => _firestore
      .collection('dispatch_bids')
      .where('carrierUid', isEqualTo: uid)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> jobHistory(String jobId) =>
      _firestore
          .collection('dispatch_jobs')
          .doc(jobId)
          .collection('revisions')
          .orderBy('revision', descending: true)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> bidHistory(String bidId) =>
      _firestore
          .collection('dispatch_bids')
          .doc(bidId)
          .collection('revisions')
          .orderBy('revision', descending: true)
          .snapshots();

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> myBidForJob(
      String jobId) async {
    final snapshot = await _firestore
        .collection('dispatch_bids')
        .where('carrierUid', isEqualTo: uid)
        .get();
    final matches = snapshot.docs
        .where((document) => document.data()['jobId'] == jobId)
        .toList()
      ..sort((a, b) {
        final aPending = a.data()['status'] == 'pending' ? 1 : 0;
        final bPending = b.data()['status'] == 'pending' ? 1 : 0;
        if (aPending != bPending) return bPending.compareTo(aPending);
        final aTime = a.data()['updatedAt'] as Timestamp?;
        final bTime = b.data()['updatedAt'] as Timestamp?;
        return (bTime?.millisecondsSinceEpoch ?? 0)
            .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
      });
    return matches.firstOrNull;
  }

  Future<void> activateMyPendingRequests() async {
    final snapshot = await _firestore
        .collection('dispatch_jobs')
        .where('createdByUid', isEqualTo: uid)
        .get();
    final drafts = snapshot.docs
        .where((document) => document.data()['status'] == 'draft')
        .toList();
    if (drafts.isEmpty) return;
    final batch = _firestore.batch();
    for (final document in drafts) {
      final revision = (document.data()['revision'] as num? ?? 1).toInt() + 1;
      batch.update(document.reference, {
        'status': 'open',
        'dispatchRequestStatus': 'accepting_carrier_bids',
        'revision': revision,
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(document.reference.collection('revisions').doc('$revision'), {
        ...document.data(),
        'status': 'open',
        'dispatchRequestStatus': 'accepting_carrier_bids',
        'revision': revision,
        'event': 'request_activated',
        'actorUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> publishDraftJob(String jobId) async {
    final reference = _firestore.collection('dispatch_jobs').doc(jobId);
    final snapshot = await reference.get();
    if (snapshot.data()?['createdByUid'] != uid) {
      throw StateError('Only the trucking request owner can publish it.');
    }
    if (snapshot.data()?['status'] != 'draft') {
      throw StateError('This trucking request is no longer a draft.');
    }
    final revision = (snapshot.data()?['revision'] as num? ?? 1).toInt() + 1;
    final batch = _firestore.batch();
    batch.update(reference, {
      'status': 'open',
      'dispatchRequestStatus': 'accepting_carrier_bids',
      'revision': revision,
      'publishedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(reference.collection('revisions').doc('$revision'), {
      ...?snapshot.data(),
      'status': 'open',
      'dispatchRequestStatus': 'accepting_carrier_bids',
      'revision': revision,
      'event': 'request_published',
      'actorUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> signupDispatch({
    required String operatingName,
    required String companyName,
    required String phone,
    required String email,
    required MarketplaceServiceArea serviceArea,
  }) async {
    final reference = _firestore.collection('dispatch_carriers').doc(uid);
    final existing = await reference.get();
    final values = <String, dynamic>{
      'ownerUid': uid,
      'operatingName': operatingName,
      'companyName': companyName,
      'phone': formatPhoneNumber(phone),
      'phoneE164': normalizePhoneNumber(phone),
      'email': email,
      'serviceArea': serviceArea.toMap(),
      'serviceAreaLabel': serviceArea.summary,
      'status': 'active',
      'availableForHire': true,
      'privacyVersion': 2,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    };
    if (existing.exists) {
      values.addAll({
        'legalName': FieldValue.delete(),
        'registrationNumber': FieldValue.delete(),
        'insuranceProvider': FieldValue.delete(),
        'insuranceExpiry': FieldValue.delete(),
        'equipment': FieldValue.delete(),
        'capacityKg': FieldValue.delete(),
      });
    }
    await reference.set(values, SetOptions(merge: true));
    final confirmed = await reference.get();
    if (!confirmed.exists || confirmed.data()?['ownerUid'] != uid) {
      throw StateError('Dispatch signup was not confirmed by the database.');
    }
  }

  Future<void> addVehicle({
    required String name,
    required String vehicleType,
    required num maximumPayloadKg,
    required num tareWeightKg,
    required num grossWeightKg,
    required String weightSource,
    required List<String> services,
    required bool pilotTruck,
    String notes = '',
  }) =>
      _firestore
          .collection('dispatch_carriers')
          .doc(uid)
          .collection('vehicles')
          .add({
        'ownerUid': uid,
        'name': name,
        'vehicleType': vehicleType,
        'maximumPayloadKg': maximumPayloadKg,
        'tareWeightKg': tareWeightKg,
        'grossWeightKg': grossWeightKg,
        'calculatedPayloadKg':
            (grossWeightKg - tareWeightKg).clamp(0, double.infinity),
        'weightSource': weightSource,
        'weightUnitStored': 'kg',
        'services': services,
        'pilotTruck': pilotTruck,
        'notes': notes,
        'available': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> removeVehicle(String vehicleId) => _firestore
      .collection('dispatch_carriers')
      .doc(uid)
      .collection('vehicles')
      .doc(vehicleId)
      .delete();

  Future<String> createJob({
    required String title,
    required String pickup,
    required String delivery,
    required DateTime truckingDate,
    required String loadDetails,
    String? listingId,
    String? offerId,
    String sourceType = 'manual',
    num? estimatedWeightKg,
    num? catalogWeightKg,
    String? weightSource,
    MarketplaceLocation? deliveryLocation,
    GeoPoint? pickupGeoPoint,
    num? distanceKm,
    String? distanceSource,
  }) async {
    final destination = deliveryLocation?.exactGeoPoint;
    final mappedDistance =
        distanceKm ?? dispatchDistanceKm(pickupGeoPoint, destination);
    final reference = _firestore.collection('dispatch_jobs').doc();
    final values = <String, dynamic>{
      'createdByUid': uid,
      'title': title,
      'pickupLabel': pickup,
      'deliveryLabel': delivery,
      'truckingDate': Timestamp.fromDate(truckingDate),
      'loadDetails': loadDetails,
      'listingId': listingId,
      'offerId': offerId,
      'sourceType': sourceType,
      'estimatedWeightKg': estimatedWeightKg,
      'catalogWeightKg': catalogWeightKg,
      'weightSource': weightSource,
      if (pickupGeoPoint != null) 'pickupPoint': pickupGeoPoint,
      if (mappedDistance != null) 'distanceKm': mappedDistance,
      if (mappedDistance != null)
        'distanceSource': distanceSource ??
            (distanceKm == null ? 'coordinate_estimate' : 'user_entered_route'),
      if (deliveryLocation != null) ...{
        'deliveryPoint': deliveryLocation.exactGeoPoint,
        'deliveryAddress': deliveryLocation.address.trim(),
        'deliveryNearestTown': deliveryLocation.nearestTown.trim(),
        'deliveryRegion': deliveryLocation.region.trim(),
        'deliveryPostalCode': deliveryLocation.postalCode.trim(),
        'deliveryCountry': deliveryLocation.country.trim(),
        'deliveryAccessNotes': deliveryLocation.accessNotes.trim(),
      },
      'status': 'open',
      'dispatchRequestStatus': 'accepting_carrier_bids',
      'bidCount': 0,
      'revision': 1,
      'publishedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final batch = _firestore.batch();
    batch.set(reference, values);
    batch.set(reference.collection('revisions').doc('1'), {
      ...values,
      'event': 'request_created',
      'actorUid': uid,
    });
    await batch.commit();
    return reference.id;
  }

  Future<void> updateJob({
    required String jobId,
    required String title,
    required String pickup,
    required String delivery,
    required DateTime truckingDate,
    required String loadDetails,
    num? estimatedWeightKg,
    num? distanceKm,
  }) async {
    final reference = _firestore.collection('dispatch_jobs').doc(jobId);
    final snapshot = await reference.get();
    final current = snapshot.data();
    if (current?['createdByUid'] != uid) {
      throw StateError('Only the request owner can edit this job.');
    }
    if (!['draft', 'open'].contains(current?['status'])) {
      throw StateError('Awarded or completed jobs cannot be edited.');
    }
    final revision = (current?['revision'] as num? ?? 1).toInt() + 1;
    final changes = <String, dynamic>{
      'title': title.trim(),
      'pickupLabel': pickup.trim(),
      'deliveryLabel': delivery.trim(),
      'truckingDate': Timestamp.fromDate(truckingDate),
      'loadDetails': loadDetails.trim(),
      'estimatedWeightKg': estimatedWeightKg,
      if (distanceKm != null) ...{
        'distanceKm': distanceKm,
        'distanceSource': 'user_entered_route',
      },
      'revision': revision,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final bids = await _firestore
        .collection('dispatch_bids')
        .where('jobId', isEqualTo: jobId)
        .get();
    final batch = _firestore.batch();
    batch.update(reference, changes);
    batch.set(reference.collection('revisions').doc('$revision'), {
      ...current!,
      ...changes,
      'event': 'request_updated',
      'actorUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (final bid in bids.docs
        .where((document) => document.data()['status'] == 'pending')) {
      final carrierUid = '${bid.data()['carrierUid'] ?? ''}';
      if (carrierUid.isEmpty || carrierUid == uid) continue;
      batch.set(
          _firestore
              .collection('users')
              .doc(carrierUid)
              .collection('notifications')
              .doc(),
          {
            'recipientUid': carrierUid,
            'actorUid': uid,
            'type': 'dispatch',
            'jobId': jobId,
            'bidId': bid.id,
            'title': 'Dispatch request updated',
            'body':
                'Review the revised route, date, distance or load details before keeping your quote.',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    }
    await batch.commit();
  }

  Future<void> bid({
    required String jobId,
    required num amount,
    required String note,
    required DateTime availableDate,
    required String vehicleId,
    required String vehicleName,
  }) async {
    await _commands.execute('submitDispatchQuote', {
      'requestId': _firestore.collection('dispatch_bids').doc().id,
      'jobId': jobId,
      'amount': amount,
      'note': note.trim(),
      'availableDate': availableDate.millisecondsSinceEpoch,
      'vehicleId': vehicleId,
    });
  }

  Future<void> updateBid({
    required String bidId,
    required num amount,
    required String note,
    required DateTime availableDate,
    required String vehicleId,
    required String vehicleName,
  }) async {
    final reference = _firestore.collection('dispatch_bids').doc(bidId);
    final snapshot = await reference.get();
    final jobId = '${snapshot.data()?['jobId'] ?? ''}';
    if (jobId.isEmpty) {
      throw StateError('This carrier quote is unavailable.');
    }
    await _commands.execute('submitDispatchQuote', {
      'requestId': _firestore.collection('dispatch_bids').doc().id,
      'jobId': jobId,
      'amount': amount,
      'note': note.trim(),
      'availableDate': availableDate.millisecondsSinceEpoch,
      'vehicleId': vehicleId,
    });
  }

  Future<void> awardBid(
      {required String jobId,
      required String bidId,
      required String carrierUid,
      required num amount}) async {
    await _commands.execute('awardDispatchQuote', {
      'requestId': _firestore.collection('dispatch_bids').doc().id,
      'jobId': jobId,
      'bidId': bidId,
    });
  }
}
