import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PipeBuyerYellowPagesAccess {
  const PipeBuyerYellowPagesAccess({
    required this.authorized,
    required this.role,
    required this.isAdmin,
    required this.reason,
  });

  final bool authorized;
  final String? role;
  final bool isAdmin;
  final String? reason;

  bool get isAdministrator => isAdmin || role == 'administrator';
  bool get isManager => role == 'manager' || isAdministrator;
  bool get isAgent => role == 'agent' || isManager;

  factory PipeBuyerYellowPagesAccess.fromJson(Map<String, dynamic> json) {
    return PipeBuyerYellowPagesAccess(
      authorized: json['authorized'] == true,
      role: json['role']?.toString(),
      isAdmin: json['isAdmin'] == true || json['role'] == 'administrator',
      reason: json['reason']?.toString(),
    );
  }
}

class PipeBuyerYellowPagesPage<T> {
  const PipeBuyerYellowPagesPage({
    required this.items,
    this.totalMatched = 0,
    this.nextCursor,
    this.expandedCategories = const <String>[],
  });

  final List<T> items;
  final int totalMatched;
  final String? nextCursor;
  final List<String> expandedCategories;
}

class PipeBuyerYellowPagesClient {
  PipeBuyerYellowPagesClient({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions,
        _auth = auth;

  FirebaseFunctions? _functions;
  FirebaseAuth? _auth;

  FirebaseFunctions get _resolvedFunctions =>
      _functions ??= FirebaseFunctions.instance;

  FirebaseAuth get _resolvedAuth => _auth ??= FirebaseAuth.instance;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> payload, {
    bool requiresAuthentication = true,
  }) async {
    if (requiresAuthentication && _resolvedAuth.currentUser == null) {
      throw StateError('Sign in to continue.');
    }
    try {
      final response = await _resolvedFunctions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 30),
            ),
          )
          .call(payload);
      if (response.data is! Map) {
        throw StateError(
            'The Oilfield Directory service returned an invalid response.');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (error) {
      final serverMessage = error.message?.trim();
      if (error.code != 'internal' &&
          serverMessage != null &&
          serverMessage.isNotEmpty &&
          serverMessage.toLowerCase() != error.code.toLowerCase()) {
        throw StateError(serverMessage);
      }
      throw StateError(switch (error.code) {
        'unauthenticated' => 'Sign in to continue.',
        'permission-denied' =>
          'Your account does not have permission for this Oilfield Directory action.',
        'not-found' => 'The requested Oilfield Directory record was not found.',
        'failed-precondition' =>
          'This Oilfield Directory action is blocked until required conditions are met.',
        'invalid-argument' =>
          'Check the entered company details and try again.',
        _ =>
          'The PipeBuyer Oilfield Directory service is temporarily unavailable.',
      });
    }
  }

  Future<PipeBuyerYellowPagesAccess> getAccess() async {
    if (_resolvedAuth.currentUser == null) {
      return const PipeBuyerYellowPagesAccess(
        authorized: false,
        role: null,
        isAdmin: false,
        reason: 'signed_out',
      );
    }
    final result =
        await _call('getYellowPagesAccess', const <String, Object?>{});
    return PipeBuyerYellowPagesAccess.fromJson(result);
  }

  Future<PipeBuyerYellowPagesPage<Map<String, dynamic>>> searchPublic({
    String query = '',
    String continentCode = '',
    String countryCode = '',
    String regionCode = '',
    String city = '',
    String categoryCode = '',
    String basin = '',
    String certification = '',
    bool emergency24x7 = false,
    bool paidOnly = false,
    String tierFilter = '',
    bool hasTollFree = false,
    String startsWith = '',
    String sortBy = 'priority',
    int offset = 0,
    int pageSize = 60,
  }) async {
    final result = await _call(
      'searchPipeBuyerYellowPages',
      <String, Object?>{
        'query': query,
        'continentCode': continentCode,
        'countryCode': countryCode,
        'regionCode': regionCode,
        'city': city,
        'categoryCode': categoryCode,
        'basin': basin,
        'certification': certification,
        'emergency24x7': emergency24x7,
        'paidOnly': paidOnly,
        'tierFilter': tierFilter,
        'hasTollFree': hasTollFree,
        'startsWith': startsWith,
        'sortBy': sortBy,
        'offset': offset,
        'pageSize': pageSize,
      },
      requiresAuthentication: false,
    );
    final raw = result['entries'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final expandedRaw = result['expandedCategories'];
    final expanded = expandedRaw is List
        ? expandedRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return PipeBuyerYellowPagesPage<Map<String, dynamic>>(
      items: items,
      totalMatched: (result['totalMatched'] as num?)?.toInt() ?? items.length,
      nextCursor: result['nextCursor']?.toString(),
      expandedCategories: expanded,
    );
  }

  Future<void> recordLeadInteraction({
    required String companyId,
    required String interactionType,
  }) async {
    try {
      await _call(
        'recordYellowPagesLeadInteraction',
        <String, Object?>{
          'companyId': companyId,
          'interactionType': interactionType,
        },
        requiresAuthentication: false,
      );
    } catch (_) {
      // Non-blocking analytics telemetry
    }
  }

  Future<Map<String, dynamic>> submitServiceListingRequest({
    String? claimedCompanyId,
    required String companyName,
    required String contactName,
    required String phone,
    String tollFreePhone = '',
    required String email,
    String website = '',
    required String countryCode,
    required String regionCode,
    required String city,
    List<String> serviceAreas = const <String>[],
    List<String> basins = const <String>[],
    List<String> categories = const <String>[],
    List<String> services = const <String>[],
    List<String> certifications = const <String>[],
    bool emergency24x7 = false,
    String description = '',
    required String requestedTier,
    String billingInterval = 'yearly',
  }) {
    return _call(
      'submitYellowPagesServiceListingRequest',
      <String, Object?>{
        if (claimedCompanyId != null && claimedCompanyId.isNotEmpty)
          'claimedCompanyId': claimedCompanyId,
        'companyName': companyName,
        'contactName': contactName,
        'phone': phone,
        'tollFreePhone': tollFreePhone,
        'email': email,
        'website': website,
        'countryCode': countryCode,
        'regionCode': regionCode,
        'city': city,
        'serviceAreas': serviceAreas,
        'basins': basins,
        'categories': categories,
        'services': services,
        'certifications': certifications,
        'emergency24x7': emergency24x7,
        'description': description,
        'requestedTier': requestedTier,
        'billingInterval': billingInterval,
      },
    );
  }

  Future<Map<String, dynamic>> createListingCheckout({
    required String requestId,
    String? requestedTier,
    String? billingInterval,
    String? currency,
  }) {
    return _call(
      'createYellowPagesListingCheckout',
      <String, Object?>{
        'requestId': requestId,
        if (requestedTier != null && requestedTier.isNotEmpty)
          'requestedTier': requestedTier,
        if (billingInterval != null && billingInterval.isNotEmpty)
          'billingInterval': billingInterval,
        if (currency != null && currency.isNotEmpty) 'currency': currency,
      },
    );
  }

  Future<Map<String, dynamic>> createBillingPortalSession({
    String? requestId,
    String? companyId,
  }) {
    return _call(
      'createYellowPagesBillingPortalSession',
      <String, Object?>{
        if (requestId != null && requestId.isNotEmpty) 'requestId': requestId,
        if (companyId != null && companyId.isNotEmpty) 'companyId': companyId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> searchAdminCompanies({
    required String query,
    String filterState = '',
    int pageSize = 60,
  }) async {
    final result = await _call(
      'searchAdminYellowPagesCompanies',
      <String, Object?>{
        'query': query,
        'filterState': filterState,
        'pageSize': pageSize,
      },
    );
    final raw = result['companies'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> listDashboardViewRaw(
    String view, {
    int pageSize = 50,
  }) {
    return _call(
      'listYellowPagesDashboardView',
      <String, Object?>{
        'view': view,
        'pageSize': pageSize,
      },
    );
  }

  Future<Map<String, dynamic>> getCompany(String companyId) {
    return _call(
      'getYellowPagesCompany',
      <String, Object?>{'companyId': companyId},
    );
  }

  Future<String> upsertCompany({
    String? companyId,
    required Map<String, Object?> company,
  }) async {
    final result = await _call(
      'upsertYellowPagesCompany',
      <String, Object?>{
        if (companyId != null) 'companyId': companyId,
        'company': company,
      },
    );
    return result['companyId']?.toString() ?? '';
  }

  Future<void> setCompanyVisibility(
    String companyId, {
    required bool visible,
    bool publishImmediately = false,
    String reason = '',
  }) {
    return _call(
      'setYellowPagesCompanyVisibility',
      <String, Object?>{
        'companyId': companyId,
        'visible': visible,
        'publishImmediately': publishImmediately,
        'reason': reason,
      },
    ).then((_) {});
  }

  Future<void> setFlaggedStatus(
    String companyId, {
    required bool flagged,
    required String reason,
    bool blockPhones = true,
  }) {
    return _call(
      'setYellowPagesFlaggedStatus',
      <String, Object?>{
        'companyId': companyId,
        'flagged': flagged,
        'reason': reason,
        'blockPhones': blockPhones,
      },
    ).then((_) {});
  }

  Future<void> manageBlockedNumber({
    required String phone,
    required bool active,
    String reason = '',
    String companyName = '',
  }) {
    return _call(
      'manageYellowPagesBlockedNumber',
      <String, Object?>{
        'phone': phone,
        'active': active,
        'reason': reason,
        'companyName': companyName,
      },
    ).then((_) {});
  }

  Future<List<Map<String, dynamic>>> listBlockedNumbers() async {
    final result = await _call(
      'listYellowPagesBlockedNumbers',
      const <String, Object?>{},
    );
    final raw = result['blockedNumbers'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> assignCompany(String companyId, {String? assignedAgentUid}) {
    return _call(
      'assignYellowPagesCompany',
      <String, Object?>{
        'companyId': companyId,
        'assignedAgentUid': assignedAgentUid,
      },
    ).then((_) {});
  }

  Future<void> recordContactEvent({
    required String companyId,
    required String eventType,
    String? disposition,
    String? summary,
    String? contactId,
    DateTime? nextFollowUpAt,
  }) {
    return _call(
      'recordYellowPagesContactEvent',
      <String, Object?>{
        'companyId': companyId,
        'eventType': eventType,
        if (disposition != null) 'disposition': disposition,
        if (summary != null) 'summary': summary,
        if (contactId != null) 'contactId': contactId,
        if (nextFollowUpAt != null)
          'nextFollowUpAt': nextFollowUpAt.toUtc().toIso8601String(),
      },
    ).then((_) {});
  }

  Future<void> setDoNotContact(
    String companyId, {
    required bool enabled,
    required String reason,
  }) {
    return _call(
      'setYellowPagesDoNotContact',
      <String, Object?>{
        'companyId': companyId,
        'enabled': enabled,
        'reason': reason,
      },
    ).then((_) {});
  }

  Future<void> reviewVerification(
    String companyId, {
    required String status,
    String? operationalStatus,
    String? reviewNote,
  }) {
    return _call(
      'reviewYellowPagesVerification',
      <String, Object?>{
        'companyId': companyId,
        'status': status,
        if (operationalStatus != null) 'operationalStatus': operationalStatus,
        if (reviewNote != null) 'reviewNote': reviewNote,
      },
    ).then((_) {});
  }

  Future<void> setBillingStatus(
    String companyId, {
    required String status,
    String listingTier = 'paid_verified',
    DateTime? paidThrough,
    bool nonExpiringPaid = false,
    bool allowUnpaidPublic = true,
    String? paymentReference,
    String? reviewNote,
  }) {
    return _call(
      'setYellowPagesBillingStatus',
      <String, Object?>{
        'companyId': companyId,
        'status': status,
        'listingTier': listingTier,
        'nonExpiringPaid': nonExpiringPaid,
        'allowUnpaidPublic': allowUnpaidPublic,
        if (paidThrough != null)
          'paidThrough': paidThrough.toUtc().toIso8601String(),
        if (paymentReference != null) 'paymentReference': paymentReference,
        if (reviewNote != null) 'reviewNote': reviewNote,
      },
    ).then((_) {});
  }

  Future<void> setPublicationStatus(
    String companyId, {
    required String status,
    String? reviewNote,
  }) {
    return _call(
      'setYellowPagesPublicationStatus',
      <String, Object?>{
        'companyId': companyId,
        'status': status,
        if (reviewNote != null) 'reviewNote': reviewNote,
      },
    ).then((_) {});
  }

  Future<void> reviewListingRequest({
    required String requestId,
    required String decision,
    bool markPaid = false,
    String reviewNote = '',
  }) {
    return _call(
      'reviewYellowPagesListingRequest',
      <String, Object?>{
        'requestId': requestId,
        'decision': decision,
        'markPaid': markPaid,
        'reviewNote': reviewNote,
      },
    ).then((_) {});
  }

  Future<void> upsertBookPageAudit({
    required int pageNumber,
    String bookEdition = '2015-2016-35th-anniversary',
    String section = 'yellow_services',
    String categoryHeader = '',
    String driveFileId = '',
    String driveFileUrl = '',
    int extractedCompanyCount = 0,
    int matchedDatabaseCount = 0,
    int activeConfirmedCount = 0,
    int numberChangedCount = 0,
    String auditStatus = 'uploaded',
    String notes = '',
  }) {
    return _call(
      'upsertYellowPagesBookPageAudit',
      <String, Object?>{
        'pageNumber': pageNumber,
        'bookEdition': bookEdition,
        'section': section,
        'categoryHeader': categoryHeader,
        'driveFileId': driveFileId,
        'driveFileUrl': driveFileUrl,
        'extractedCompanyCount': extractedCompanyCount,
        'matchedDatabaseCount': matchedDatabaseCount,
        'activeConfirmedCount': activeConfirmedCount,
        'numberChangedCount': numberChangedCount,
        'auditStatus': auditStatus,
        'notes': notes,
      },
    ).then((_) {});
  }

  Future<List<Map<String, dynamic>>> listStaff() async {
    final result = await _call(
      'listYellowPagesStaff',
      const <String, Object?>{},
    );
    final raw = result['staff'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> manageStaff({
    required String email,
    required bool active,
    String role = 'agent',
  }) {
    return _call(
      'manageYellowPagesStaff',
      <String, Object?>{
        'email': email,
        'active': active,
        'role': role,
      },
    ).then((_) {});
  }
}
