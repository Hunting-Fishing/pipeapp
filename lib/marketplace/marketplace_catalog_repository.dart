import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'marketplace_location.dart';

class MarketplaceCatalogRepository {
  MarketplaceCatalogRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _catalog =>
      _firestore.collection('marketplace_catalog');

  Future<List<String>> loadPipeSizes(List<String> fallback) async {
    try {
      final snapshot = await _catalog.doc('pipe_sizes').get();
      final values = snapshot.data()?['values'];
      if (values is List && values.isNotEmpty) return values.cast<String>();
    } catch (_) {}
    return fallback;
  }

  Future<Map<String, List<String>>> loadBrandModels(
      Map<String, List<String>> fallback) async {
    try {
      final snapshot = await _catalog.doc('equipment_brands').get();
      final brands = snapshot.data()?['brands'];
      if (brands is Map) {
        return brands.map((key, value) =>
            MapEntry(key.toString(), List<String>.from(value as List)));
      }
    } catch (_) {}
    return fallback;
  }

  String newListingId() => _firestore.collection('public_listings').doc().id;

  Future<void> submitCatalogSuggestions({
    required String listingId,
    required List<Map<String, String>> suggestions,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || suggestions.isEmpty) return;
    final batch = _firestore.batch();
    for (final suggestion in suggestions) {
      final document = _firestore.collection('catalog_suggestions').doc();
      batch.set(document, {
        ...suggestion,
        'listingId': listingId,
        'requestedByUid': user.uid,
        'requestedByEmail': user.email ?? '',
        'adminEmail': 'jordilwbailey@gmail.com',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> updateListingMedia(String listingId,
          {required List<String> imageUrls,
          List<String> imageHashes = const [],
          String? videoUrl,
          required String status,
          String? error}) =>
      _firestore.collection('public_listings').doc(listingId).update({
        'imageUrls': imageUrls,
        'imageHashes': imageHashes,
        'videoUrl': videoUrl,
        'mediaPhotoCount': imageUrls.length,
        'hasVideo': videoUrl != null,
        'mediaUploadStatus': status,
        if (error != null) 'mediaUploadError': error,
        'mediaUpdatedAt': FieldValue.serverTimestamp(),
      });

  Future<String> publishListing(Map<String, dynamic> values,
      {MarketplaceLocation? location, String? listingId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to save a listing.');
    final listing = listingId == null
        ? _firestore.collection('public_listings').doc()
        : _firestore.collection('public_listings').doc(listingId);
    final batch = _firestore.batch();
    batch.set(listing, {
      ...values,
      if (values['price'] is num && values['initialPrice'] == null)
        'initialPrice': values['price'],
      if (location != null) ...location.publicData(),
      'sellerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'local_flutter_app',
      'status': 'active',
    });
    if (location != null) {
      batch.set(
          _firestore.collection('listing_private_locations').doc(listing.id),
          location.privateData(uid));
    }
    await batch.commit();
    return listing.id;
  }
}
