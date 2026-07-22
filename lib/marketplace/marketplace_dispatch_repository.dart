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

  Future<void> publishDraftJob(String jobId) =>
      _commands.execute('publishDispatchJob', {
        'requestId': _firestore.collection('dispatch_jobs').doc().id,
        'jobId': jobId,
      });

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
    final jobId = _firestore.collection('dispatch_jobs').doc().id;
    final result = await _commands.execute('createDispatchJob', {
      'requestId': jobId,
      'jobId': jobId,
      'title': title,
      'pickupLabel': pickup,
      'deliveryLabel': delivery,
      'truckingDate': truckingDate.millisecondsSinceEpoch,
      'loadDetails': loadDetails,
      'listingId': listingId,
      'sourceType': sourceType,
      'estimatedWeightKg': estimatedWeightKg,
      'catalogWeightKg': catalogWeightKg,
      'weightSource': weightSource,
      if (pickupGeoPoint != null)
        'pickupPoint': {
          'latitude': pickupGeoPoint.latitude,
          'longitude': pickupGeoPoint.longitude,
        },
      if (mappedDistance != null) 'distanceKm': mappedDistance,
      if (mappedDistance != null)
        'distanceSource': distanceSource ??
            (distanceKm == null ? 'coordinate_estimate' : 'user_entered_route'),
      if (deliveryLocation != null) ...{
        'deliveryPoint': {
          'latitude': deliveryLocation.exactGeoPoint.latitude,
          'longitude': deliveryLocation.exactGeoPoint.longitude,
        },
        'deliveryAddress': deliveryLocation.address.trim(),
        'deliveryNearestTown': deliveryLocation.nearestTown.trim(),
        'deliveryRegion': deliveryLocation.region.trim(),
        'deliveryPostalCode': deliveryLocation.postalCode.trim(),
        'deliveryCountry': deliveryLocation.country.trim(),
        'deliveryAccessNotes': deliveryLocation.accessNotes.trim(),
      },
    });
    return '${result['jobId'] ?? jobId}';
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
    await _commands.execute('updateDispatchJob', {
      'requestId': _firestore.collection('dispatch_jobs').doc().id,
      'jobId': jobId,
      'title': title.trim(),
      'pickupLabel': pickup.trim(),
      'deliveryLabel': delivery.trim(),
      'truckingDate': truckingDate.millisecondsSinceEpoch,
      'loadDetails': loadDetails.trim(),
      'estimatedWeightKg': estimatedWeightKg,
      if (distanceKm != null) ...{
        'distanceKm': distanceKm,
        'distanceSource': 'user_entered_route',
      },
    });
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
