import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'marketplace_command_client.dart';
import 'marketplace_location.dart';

class MarketplaceDispatchRequestRepository {
  MarketplaceDispatchRequestRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    MarketplaceCommandClient? commandClient,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _commands = commandClient ?? MarketplaceCommandClient();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final MarketplaceCommandClient _commands;

  String reserveJobId() => _firestore.collection('dispatch_jobs').doc().id;

  Future<Map<String, dynamic>> uploadAttachment({
    required String jobId,
    required String name,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final authorization = await _commands.execute(
      'authorizeDispatchRequestUpload',
      {
        'requestId':
            _firestore.collection('media_upload_authorizations').doc().id,
        'jobId': jobId,
        'originalName': name,
        'contentType': contentType,
        'sizeBytes': bytes.length,
      },
    );
    final authorizationId = '${authorization['authorizationId'] ?? ''}'.trim();
    final storagePath = '${authorization['storagePath'] ?? ''}'.trim();
    if (authorizationId.isEmpty || storagePath.isEmpty) {
      throw StateError('The Dispatch attachment authorization is incomplete.');
    }
    final reference = _storage.ref(storagePath);
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await reference.getDownloadURL();
    await _commands.execute('confirmMarketplaceUpload', {
      'authorizationId': authorizationId,
      'url': url,
    });
    return {
      'authorizationId': authorizationId,
      'url': url,
      'name': name,
    };
  }

  Future<String> createRequest({
    required String jobId,
    required List<String> serviceCodes,
    required String requestPath,
    required String contactPreference,
    required String title,
    required MarketplaceLocation pickupOrWorkSite,
    MarketplaceLocation? delivery,
    required DateTime requestedAt,
    required String details,
    required List<Map<String, dynamic>> attachments,
  }) async {
    final pickupLabel = _locationLabel(pickupOrWorkSite);
    final deliveryLabel = delivery == null ? '' : _locationLabel(delivery);
    final fieldService = requestPath == 'field_service';
    final result = await _commands.execute('createDispatchJob', {
      'requestId': jobId,
      'jobId': jobId,
      'title': title.trim(),
      'pickupLabel': pickupLabel,
      'deliveryLabel': deliveryLabel,
      'truckingDate': requestedAt.millisecondsSinceEpoch,
      'loadDetails': details.trim(),
      'sourceType': 'manual',
      'serviceCodes': serviceCodes,
      'requestPath': requestPath,
      'contactPreference': contactPreference,
      'attachments': attachments,
      'pickupPoint': {
        'latitude': pickupOrWorkSite.exactGeoPoint.latitude,
        'longitude': pickupOrWorkSite.exactGeoPoint.longitude,
      },
      if (fieldService) ...{
        'workSiteAddress': pickupOrWorkSite.address.trim(),
        'workSiteNearestTown': pickupOrWorkSite.nearestTown.trim(),
        'workSiteRegion': pickupOrWorkSite.region.trim(),
        'workSitePostalCode': pickupOrWorkSite.postalCode.trim(),
        'workSiteCountry': pickupOrWorkSite.country.trim(),
        'workSiteAccessNotes': pickupOrWorkSite.accessNotes.trim(),
      },
      if (delivery != null) ...{
        'deliveryPoint': {
          'latitude': delivery.exactGeoPoint.latitude,
          'longitude': delivery.exactGeoPoint.longitude,
        },
        'deliveryAddress': delivery.address.trim(),
        'deliveryNearestTown': delivery.nearestTown.trim(),
        'deliveryRegion': delivery.region.trim(),
        'deliveryPostalCode': delivery.postalCode.trim(),
        'deliveryCountry': delivery.country.trim(),
        'deliveryAccessNotes': delivery.accessNotes.trim(),
      },
    });
    return '${result['jobId'] ?? jobId}';
  }

  Future<void> updateFieldServiceRequest({
    required String jobId,
    required String title,
    required DateTime requestedAt,
    required String details,
  }) async {
    await _commands.execute('updateDispatchFieldRequest', {
      'requestId': _firestore.collection('dispatch_jobs').doc().id,
      'jobId': jobId,
      'title': title.trim(),
      'truckingDate': requestedAt.millisecondsSinceEpoch,
      'loadDetails': details.trim(),
    });
  }

  String _locationLabel(MarketplaceLocation location) {
    final publicName = location.publicName.trim();
    if (publicName.isNotEmpty) return publicName;
    final town = location.nearestTown.trim();
    if (town.isNotEmpty) return town;
    return 'Mapped Dispatch location';
  }
}
