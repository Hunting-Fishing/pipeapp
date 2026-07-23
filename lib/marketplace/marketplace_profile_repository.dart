import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    return _firestore.collection('users').doc(_uid).set({
      'accountType': accountType,
      'profileComplete': false,
      'roleVersion': 0,
      'accountTypeChangedAt': FieldValue.serverTimestamp(),
      'roleSyncRequestedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  Future<void> savePersonal(Map<String, dynamic> values) async {
    final phone = normalizePhoneNumber('${values['phone_number'] ?? ''}');
    final verifiedPhone = normalizePhoneNumber(
        FirebaseAuth.instance.currentUser?.phoneNumber ?? '');
    values = {...values}
      ..remove('phone_number')
      ..remove('phoneE164');
    if (phone.isNotEmpty && phone != verifiedPhone) {
      values['pendingPhoneE164'] = phone;
    } else if (phone == verifiedPhone && phone.isNotEmpty) {
      values['pendingPhoneE164'] = FieldValue.delete();
    }
    final batch = _firestore.batch();
    batch.set(
        _firestore.collection('users').doc(_uid),
        {
          ...values,
          'uid': _uid,
          'profileUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.set(
        _firestore.collection('public_seller_profiles').doc(_uid),
        {
          'ownerUid': _uid,
          'displayName': values['display_name'],
          'description': values['sellerBio'],
          'baseCommunity': values['baseCommunity'],
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
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
    final batch = _firestore.batch();
    batch.set(
        _firestore.collection('public_business_profiles').doc(_uid),
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
          'ownerUid': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.set(
        _firestore.collection('business_private').doc(_uid),
        {
          'legalName': values['legalName'],
          'privateAddress': values['privateAddress'],
          'yardLocation': values['yardLocation'],
          'ownerUid': _uid,
          'memberUids': FieldValue.arrayUnion([_uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.set(
        _firestore.collection('users').doc(_uid),
        {
          'businessProfileComplete': true,
          'profileComplete': true,
          'profileCompletion': values['profileCompletion'],
          'profileUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
  }
}
