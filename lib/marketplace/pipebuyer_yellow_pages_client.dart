import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'pipebuyer_yellow_pages_taxonomy.dart';

class YellowPagesTownCount {
  const YellowPagesTownCount({
    required this.city,
    required this.regionCode,
    required this.countryCode,
    this.count,
  });

  final String city;
  final String regionCode;
  final String countryCode;
  final int? count;
}

class PipeBuyerYellowPagesDirectoryCounts {
  const PipeBuyerYellowPagesDirectoryCounts({
    this.totalBusinesses = 0,
    this.byContinent = const <String, int>{},
    this.byCountry = const <String, int>{},
    this.byRegion = const <String, int>{},
    this.byCategory = const <String, int>{},
    this.towns = const <YellowPagesTownCount>[],
  });

  static const empty = PipeBuyerYellowPagesDirectoryCounts();

  final int totalBusinesses;
  final Map<String, int> byContinent;
  final Map<String, int> byCountry;
  final Map<String, int> byRegion;
  final Map<String, int> byCategory;
  final List<YellowPagesTownCount> towns;

  bool get hasCounts => totalBusinesses > 0;

  int countForContinent(String continentCode) {
    final norm = continentCode.trim().toLowerCase();
    if (norm.isEmpty) return totalBusinesses;
    return byContinent[norm] ?? 0;
  }

  int countForCountry(String countryCode) {
    final norm = countryCode.trim().toUpperCase();
    if (norm.isEmpty) return totalBusinesses;
    return byCountry[norm] ?? 0;
  }

  int countForRegion(String countryCode, String regionCode) {
    final cc = countryCode.trim().toUpperCase();
    final rc = regionCode.trim().toUpperCase();
    if (rc.isEmpty) return countForCountry(cc);
    return byRegion['$cc:$rc'] ?? 0;
  }

  int countForLocation({
    String continentCode = '',
    String countryCode = '',
    String regionCode = '',
  }) {
    if (regionCode.trim().isNotEmpty && countryCode.trim().isNotEmpty) {
      return countForRegion(countryCode, regionCode);
    }
    if (countryCode.trim().isNotEmpty) {
      return countForCountry(countryCode);
    }
    return countForContinent(continentCode);
  }

  int countForCategory(String categoryCode) {
    final norm = categoryCode.trim();
    if (norm.isEmpty) return totalBusinesses;
    return byCategory[norm] ?? 0;
  }

  List<YellowPagesTownCount> townsForLocation({
    String continentCode = '',
    String countryCode = '',
    String regionCode = '',
  }) {
    final cont = continentCode.trim().toLowerCase();
    final cc = countryCode.trim().toUpperCase();
    final rc = regionCode.trim().toUpperCase();
    final allowedCountries = cont.isEmpty
        ? null
        : PipeBuyerYellowPagesTaxonomy.countriesForContinent(cont)
            .map((item) => item.code)
            .toSet();
    return towns.where((town) {
      if (allowedCountries != null &&
          !allowedCountries.contains(town.countryCode)) {
        return false;
      }
      if (cc.isNotEmpty && town.countryCode != cc) return false;
      if (rc.isNotEmpty && town.regionCode != rc) return false;
      return true;
    }).toList(growable: false);
  }

  factory PipeBuyerYellowPagesDirectoryCounts.fromJson(
    Map<String, dynamic> json,
  ) {
    Map<String, int> parseIntMap(Object? raw) {
      if (raw is! Map) return const <String, int>{};
      final out = <String, int>{};
      for (final entry in raw.entries) {
        final key = entry.key.toString().trim();
        final val = (entry.value as num?)?.toInt() ??
            int.tryParse('${entry.value}') ??
            0;
        if (key.isNotEmpty && val > 0) {
          out[key] = val;
        }
      }
      return Map<String, int>.unmodifiable(out);
    }

    final parsedTowns = <YellowPagesTownCount>[];
    final rawTowns = json['towns'];
    if (rawTowns is List) {
      for (final item in rawTowns) {
        if (item is List && item.length >= 4) {
          final city = '${item[0] ?? ''}'.trim();
          final regionCode = '${item[1] ?? ''}'.trim().toUpperCase();
          final countryCode = '${item[2] ?? ''}'.trim().toUpperCase();
          final count =
              (item[3] as num?)?.toInt() ?? int.tryParse('${item[3]}') ?? 0;
          if (city.isNotEmpty && countryCode.isNotEmpty && count > 0) {
            parsedTowns.add(
              YellowPagesTownCount(
                city: city,
                regionCode: regionCode,
                countryCode: countryCode,
                count: count,
              ),
            );
          }
        } else if (item is Map) {
          final city = '${item['city'] ?? ''}'.trim();
          final regionCode = '${item['regionCode'] ?? ''}'.trim().toUpperCase();
          final countryCode =
              '${item['countryCode'] ?? ''}'.trim().toUpperCase();
          final count = (item['count'] as num?)?.toInt() ??
              int.tryParse('${item['count']}') ??
              0;
          if (city.isNotEmpty && countryCode.isNotEmpty && count > 0) {
            parsedTowns.add(
              YellowPagesTownCount(
                city: city,
                regionCode: regionCode,
                countryCode: countryCode,
                count: count,
              ),
            );
          }
        }
      }
    }
    parsedTowns.sort(
      (a, b) => a.city.toLowerCase().compareTo(b.city.toLowerCase()),
    );

    return PipeBuyerYellowPagesDirectoryCounts(
      totalBusinesses: (json['totalBusinesses'] as num?)?.toInt() ??
          int.tryParse('${json['totalBusinesses']}') ??
          0,
      byContinent: parseIntMap(json['byContinent']),
      byCountry: parseIntMap(json['byCountry']),
      byRegion: parseIntMap(json['byRegion']),
      byCategory: parseIntMap(json['byCategory']),
      towns: List<YellowPagesTownCount>.unmodifiable(parsedTowns),
    );
  }
}

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

  Future<PipeBuyerYellowPagesDirectoryCounts> getDirectoryCounts() async {
    final result = await _call(
      'getYellowPagesTaxonomy',
      const <String, Object?>{},
      requiresAuthentication: false,
    );
    final rawCounts = result['counts'];
    if (rawCounts is Map) {
      return PipeBuyerYellowPagesDirectoryCounts.fromJson(
        Map<String, dynamic>.from(rawCounts),
      );
    }
    return PipeBuyerYellowPagesDirectoryCounts.empty;
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
    String logoUrl = '',
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
        'logoUrl': logoUrl,
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
