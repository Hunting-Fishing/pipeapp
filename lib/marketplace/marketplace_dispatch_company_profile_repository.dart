import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'marketplace_dispatch_company_profile.dart';
import 'marketplace_dispatch_service_taxonomy.dart';

class MarketplaceDispatchCompanyProfileRepository {
  MarketplaceDispatchCompanyProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Sign in to manage a Dispatch company profile.');
    }
    return uid;
  }

  Future<DispatchCompanyProfileDraft> load() async {
    final uid = _uid;
    final snapshots = await Future.wait([
      _firestore.collection('dispatch_carriers').doc(uid).get(),
      _firestore.collection('public_business_profiles').doc(uid).get(),
      _firestore.collection('business_private').doc(uid).get(),
    ]);

    final carrier = snapshots[0].data() ?? const <String, dynamic>{};
    final publicBusiness = snapshots[1].data() ?? const <String, dynamic>{};
    final privateBusiness = snapshots[2].data() ?? const <String, dynamic>{};

    final publicDispatch = _nestedMap(publicBusiness['dispatchProfile']);
    final privateDispatch = _nestedMap(privateBusiness['dispatchProfile']);

    final rawServiceCodes = publicDispatch['serviceCodes'];
    final serviceCodes = rawServiceCodes is Iterable
        ? rawServiceCodes
            .map((value) => '$value'.trim())
            .where((value) => value.isNotEmpty)
            .toList()
        : _legacyServiceCodes(carrier['services']);

    return DispatchCompanyProfileDraft(
      companyName: _firstText([
        privateDispatch['companyName'],
        privateBusiness['legalName'],
        carrier['companyName'],
      ]),
      operatingName: _firstText([
        publicDispatch['operatingName'],
        publicBusiness['publicName'],
        carrier['operatingName'],
      ]),
      businessType: _businessType(publicDispatch['businessType']),
      description: _firstText([
        publicDispatch['description'],
        publicBusiness['description'],
      ]),
      website: _firstText([
        publicDispatch['website'],
        publicBusiness['website'],
      ]),
      serviceCodes: serviceCodes,
      serviceAreaLabel: _firstText([
        publicDispatch['serviceAreaLabel'],
        publicBusiness['serviceAreaLabel'],
        carrier['serviceAreaLabel'],
      ]),
      availability: _availability(publicDispatch['availability']),
      emergencyCallout: publicDispatch['emergencyCallout'] == true,
      remoteSiteCapable: publicDispatch['remoteSiteCapable'] == true,
    );
  }

  Future<void> save(DispatchCompanyProfileDraft draft) async {
    final uid = _uid;
    final carrierRef = _firestore.collection('dispatch_carriers').doc(uid);
    final publicRef =
        _firestore.collection('public_business_profiles').doc(uid);
    final privateRef = _firestore.collection('business_private').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final carrierSnapshot = await transaction.get(carrierRef);
      if (!carrierSnapshot.exists) {
        throw StateError(
          'Join Pipe Buyer Dispatch before publishing a Dispatch company profile.',
        );
      }

      final publicProfile = <String, dynamic>{
        'schemaVersion': 1,
        'operatingName': draft.operatingName.trim(),
        'businessType': draft.businessType.code,
        'description': draft.description.trim(),
        'website': draft.website.trim(),
        'serviceCodes': draft.normalizedServiceCodes,
        'serviceAreaLabel': draft.serviceAreaLabel.trim(),
        'availability': draft.availability.code,
        'emergencyCallout': draft.emergencyCallout,
        'remoteSiteCapable': draft.remoteSiteCapable,
        'profileCompleteness': draft.completionPercent,
      };
      final privateProfile = <String, dynamic>{
        'schemaVersion': 1,
        'companyName': draft.companyName.trim(),
      };

      transaction.set(
        publicRef,
        {
          'ownerUid': uid,
          'publicName': draft.operatingName.trim(),
          'website': draft.website.trim(),
          'description': draft.description.trim(),
          'serviceAreaLabel': draft.serviceAreaLabel.trim(),
          'dispatchProfile': publicProfile,
          'dispatchProfileUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(
        privateRef,
        {
          'ownerUid': uid,
          'memberUids': FieldValue.arrayUnion([uid]),
          'legalName': draft.companyName.trim(),
          'dispatchProfile': privateProfile,
          'dispatchProfileUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  static Map<String, dynamic> _nestedMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = '${value ?? ''}'.trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static List<String> _legacyServiceCodes(Object? value) {
    if (value is! Iterable) return const <String>[];
    final codes = <String>{};
    for (final item in value) {
      final service = DispatchServiceTaxonomy.fromLegacyLabel('$item');
      if (service != null) codes.add(service.code);
    }
    final result = codes.toList()..sort();
    return result;
  }

  static DispatchBusinessType _businessType(Object? value) {
    final code = '${value ?? ''}'.trim();
    for (final type in DispatchBusinessType.values) {
      if (type.code == code) return type;
    }
    return DispatchBusinessType.ownerOperator;
  }

  static DispatchAvailability _availability(Object? value) {
    final code = '${value ?? ''}'.trim();
    for (final availability in DispatchAvailability.values) {
      if (availability.code == code) return availability;
    }
    return DispatchAvailability.availableThisWeek;
  }
}
