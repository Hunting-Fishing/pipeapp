import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'marketplace_command_client.dart';
import 'marketplace_location.dart';

class MarketplaceCatalogRepository {
  MarketplaceCatalogRepository({
    FirebaseFirestore? firestore,
    MarketplaceCommandClient? commandClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _commands = commandClient ?? MarketplaceCommandClient();

  final FirebaseFirestore _firestore;
  final MarketplaceCommandClient _commands;

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
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> updateListingMedia(String listingId,
      {required List<String> imageUrls,
      List<String> imageHashes = const [],
      String? thumbnailUrl,
      String? videoUrl,
      required String status,
      String? error}) async {
    await _commands.execute('updateMarketplaceListingMedia', {
      'listingId': listingId,
      'imageUrls': imageUrls,
      'imageHashes': imageHashes,
      'thumbnailUrl': thumbnailUrl,
      'videoUrl': videoUrl,
      'status': status,
      'error': error,
    });
  }

  Future<void> createListingDraft(Map<String, dynamic> values,
      {required MarketplaceLocation location,
      required String listingId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to save a listing draft.');
    final response = await _commands.execute('createMarketplaceListingDraft', {
      'listingId': listingId,
      'listing': _callableValue(values),
      'location': _locationValue(location),
    });
    if ('${response['listingId'] ?? ''}'.trim() != listingId) {
      throw StateError(
          'The listing service returned an invalid draft confirmation.');
    }
  }

  Future<void> updateListingDraftMedia(String listingId,
      {required List<String> imageUrls,
      List<String> imageHashes = const [],
      String? thumbnailUrl,
      String? videoUrl,
      required String status,
      String? error}) async {
    await _commands.execute(
        'updateMarketplaceListingDraftMedia',
        {
          'listingId': listingId,
          'imageUrls': imageUrls,
          'imageHashes': imageHashes,
          'thumbnailUrl': thumbnailUrl,
          'videoUrl': videoUrl,
          'status': status,
          'error': error,
        },
        timeout: const Duration(seconds: 60));
  }

  Future<void> publishListingDraft(String listingId,
      {required String requestId}) async {
    final response = await _commands.execute(
        'publishMarketplaceListingDraft',
        {
          'listingId': listingId,
          'requestId': requestId,
        },
        timeout: const Duration(seconds: 60));
    if ('${response['listingId'] ?? ''}'.trim() != listingId) {
      throw StateError(
          'The listing service returned an invalid publication confirmation.');
    }
  }

  Future<String> publishListing(Map<String, dynamic> values,
      {MarketplaceLocation? location, String? listingId}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to save a listing.');
    if (location == null) {
      throw StateError('Set a pickup or search location before publishing.');
    }
    final id = listingId ?? newListingId();
    final response = await _commands.execute('createMarketplaceListing', {
      'listingId': id,
      'listing': _callableValue(values),
      'location': _locationValue(location),
    });
    final publishedId = '${response['listingId'] ?? ''}'.trim();
    if (publishedId != id) {
      throw StateError(
          'The listing service returned an invalid confirmation. Try again.');
    }
    return publishedId;
  }

  Map<String, Object?> _locationValue(MarketplaceLocation location) => {
        'visibility': location.visibility.value,
        'point': {
          'latitude': location.point.latitude,
          'longitude': location.point.longitude,
        },
        'publicName': location.publicName,
        'address': location.address,
        'nearestTown': location.nearestTown,
        'accessNotes': location.accessNotes,
        'region': location.region,
        'postalCode': location.postalCode,
        'country': location.country,
      };

  Object? _callableValue(Object? value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is GeoPoint) {
      return {
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is Map) {
      return value
          .map((key, item) => MapEntry(key.toString(), _callableValue(item)));
    }
    if (value is Iterable) {
      return value.map(_callableValue).toList(growable: false);
    }
    return value;
  }
}
