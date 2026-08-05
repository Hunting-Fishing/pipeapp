import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'marketplace_location.dart';
import 'marketplace_profile_community.dart';
import 'regional_phone_field.dart';

class MarketplaceProfileRepository {
  MarketplaceProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to save a profile.');
    return uid;
  }

  Future<Map<String, dynamic>> loadPersonal() async =>
      (await _firestore.collection('users').doc(_uid).get()).data() ?? {};

  Future<Map<String, dynamic>> loadPublicSeller() async =>
      (await _firestore.collection('public_seller_profiles').doc(_uid).get())
          .data() ??
      {};

  Future<void> requestRoleSync(String accountType) =>
      _firestore.collection('users').doc(_uid).set({
        'accountType': accountType,
        'roleSyncRequestedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> changeAccountType(String accountType) {
    if (accountType != 'personal' && accountType != 'business') {
      throw ArgumentError.value(accountType, 'accountType');
    }
    final uid = _uid;
    final userRef = _firestore.collection('users').doc(uid);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final values = <String, dynamic>{
        'accountType': accountType,
        'profileComplete': false,
        'roleVersion': 0,
        'accountTypeChangedAt': FieldValue.serverTimestamp(),
        'roleSyncRequestedAt': FieldValue.serverTimestamp(),
      };
      if (!snapshot.exists) {
        values.addAll({
          'uid': uid,
          'userScore': 70,
          'accountVerified': false,
        });
      }
      transaction.set(userRef, values, SetOptions(merge: true));
    });
  }

  Future<void> updateProfileCompletion(int completion) =>
      _firestore.collection('users').doc(_uid).set({
        'profileCompletion': completion.clamp(0, 100),
        'profileCompletionUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> saveAvatarUrl(String photoUrl) async {
    final batch = _firestore.batch();
    batch.set(
        _firestore.collection('public_seller_profiles').doc(_uid),
        {
          'ownerUid': _uid,
          'photoUrl': photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.set(
        _firestore.collection('public_business_profiles').doc(_uid),
        {
          'ownerUid': _uid,
          'photoUrl': photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
    try {
      await _firestore.collection('users').doc(_uid).set({
        'photo_url': photoUrl,
        'profileUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException {
      // Legacy user documents may not yet satisfy the current private-profile
      // schema. The public marketplace avatar has still saved successfully.
    }
    try {
      await FirebaseAuth.instance.currentUser?.updatePhotoURL(photoUrl);
    } on FirebaseAuthException {
      // Firestore is the marketplace source of truth. An auth-profile refresh
      // can fail for an older session without invalidating the saved avatar.
    }
  }

  Future<String> loadPublicAvatarUrl() async {
    final profile =
        await _firestore.collection('public_seller_profiles').doc(_uid).get();
    return '${profile.data()?['photoUrl'] ?? ''}'.trim();
  }

  Future<List<Map<String, dynamic>>> loadSavedLocations() async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('saved_locations')
        .orderBy('createdAt')
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<void> saveLocation({
    required Map<String, dynamic> location,
    required String purpose,
    String? id,
  }) async {
    final ref = _firestore
        .collection('users')
        .doc(_uid)
        .collection('saved_locations')
        .doc(id);
    await ref.set({
      ...location,
      'ownerUid': _uid,
      'purpose': purpose,
      'notifyNearby': purpose == 'observed_interest',
      'notifyRadiusKm': 50,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteLocation(String id) => _firestore
      .collection('users')
      .doc(_uid)
      .collection('saved_locations')
      .doc(id)
      .delete();

  Future<void> savePersonal(
    Map<String, dynamic> values, {
    required MarketplaceLocation primaryCommunity,
  }) async {
    final uid = _uid;
    final phone = normalizePhoneNumber('${values['phone_number'] ?? ''}');
    final verifiedPhone = normalizePhoneNumber(
        FirebaseAuth.instance.currentUser?.phoneNumber ?? '');
    final normalizedCommunity =
        normalizePrimaryCommunityLocation(primaryCommunity);
    final publicCommunity = primaryCommunityPublicData(normalizedCommunity);
    values = {...values}
      ..remove('phone_number')
      ..remove('phoneE164');
    final userRef = _firestore.collection('users').doc(uid);
    final publicRef =
        _firestore.collection('public_seller_profiles').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final userValues = <String, dynamic>{
        ...values,
        'uid': uid,
        'accountType': 'personal',
        'baseCommunity': primaryCommunityLabel(normalizedCommunity),
        'primaryCommunityLocation':
            primaryCommunityPrivateData(normalizedCommunity, uid),
        'profileUpdatedAt': FieldValue.serverTimestamp(),
      };
      if (!userSnapshot.exists) {
        userValues.addAll({
          'userScore': 70,
          'accountVerified': false,
        });
      }
      if (phone.isNotEmpty && phone != verifiedPhone) {
        userValues['pendingPhoneE164'] = phone;
      } else if (userSnapshot.exists) {
        userValues['pendingPhoneE164'] = FieldValue.delete();
      }
      transaction.set(userRef, userValues, SetOptions(merge: true));
      transaction.set(
          publicRef,
          {
            'ownerUid': uid,
            'displayName': values['display_name'],
            'description': values['sellerBio'],
            'baseCommunity': primaryCommunityLabel(normalizedCommunity),
            'primaryCommunity': publicCommunity,
            'primaryCommunityGeoPoint': publicCommunity['publicGeoPoint'],
            'primaryCommunityTown': publicCommunity['nearestTown'],
            'primaryCommunityRegion': publicCommunity['region'],
            'primaryCommunityCountry': publicCommunity['country'],
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Future<Map<String, dynamic>> loadPublicBusiness() async =>
      (await _firestore.collection('public_business_profiles').doc(_uid).get())
          .data() ??
      {};

  Future<Map<String, dynamic>> loadPrivateBusiness() async =>
      (await _firestore.collection('business_private').doc(_uid).get())
          .data() ??
      {};

  Future<void> saveBusiness(Map<String, dynamic> values) async {
    final uid = _uid;
    final publicRef =
        _firestore.collection('public_business_profiles').doc(uid);
    final privateRef = _firestore.collection('business_private').doc(uid);
    final userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      transaction.set(
        publicRef,
        {
          'publicName': values['publicName'],
          'publicPhone': values['publicPhone'],
          'publicEmail': values['publicEmail'],
          'website': values['website'],
          'serviceArea': values['serviceArea'],
          'serviceAreaLabel': values['serviceAreaLabel'],
          'serviceCountryCodes': values['serviceCountryCodes'],
          'serviceRegionKeys': values['serviceRegionKeys'],
          'servicePlaceKeys': values['servicePlaceKeys'],
          'description': values['description'],
          'ownerUid': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(
        privateRef,
        {
          'legalName': values['legalName'],
          'privateAddress': values['privateAddress'],
          'yardLocation': values['yardLocation'],
          'ownerUid': uid,
          'memberUids': FieldValue.arrayUnion([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      final userValues = <String, dynamic>{
        'uid': uid,
        'accountType': 'business',
        'businessProfileComplete': true,
        'profileComplete': true,
        'profileCompletion': values['profileCompletion'],
        'profileUpdatedAt': FieldValue.serverTimestamp(),
      };
      if (!userSnapshot.exists) {
        userValues.addAll({
          'userScore': 70,
          'accountVerified': false,
        });
      }
      transaction.set(userRef, userValues, SetOptions(merge: true));
    });
  }
}
