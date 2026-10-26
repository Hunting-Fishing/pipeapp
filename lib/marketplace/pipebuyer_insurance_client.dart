import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'marketplace_admin_access.dart';
import 'pipebuyer_insurance_taxonomy.dart';

class PipeBuyerInsuranceProvidersResult {
  const PipeBuyerInsuranceProvidersResult({
    required this.providers,
    required this.totalMatched,
  });

  final List<InsuranceProviderListing> providers;
  final int totalMatched;
}

class PipeBuyerInsuranceRateSubmissionResult {
  const PipeBuyerInsuranceRateSubmissionResult({
    required this.applicationId,
    required this.status,
    required this.distributionMode,
    required this.coverageLines,
    this.targetProviderId,
    this.targetProviderName = '',
  });

  final String applicationId;
  final String status;
  final String distributionMode;
  final List<String> coverageLines;
  final String? targetProviderId;
  final String targetProviderName;

  factory PipeBuyerInsuranceRateSubmissionResult.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawLines = json['coverageLines'];
    final lines = rawLines is List
        ? rawLines
            .map((e) => '${e ?? ''}'.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final targetId = '${json['targetProviderId'] ?? ''}'.trim();
    return PipeBuyerInsuranceRateSubmissionResult(
      applicationId: '${json['applicationId'] ?? ''}'.trim(),
      status: '${json['status'] ?? 'new'}'.trim(),
      distributionMode: '${json['distributionMode'] ?? 'multi_carrier'}'.trim(),
      coverageLines: lines,
      targetProviderId: targetId.isEmpty ? null : targetId,
      targetProviderName: '${json['targetProviderName'] ?? ''}'.trim(),
    );
  }
}

class PipeBuyerInsuranceProviderApplicationResult {
  const PipeBuyerInsuranceProviderApplicationResult({
    required this.applicationId,
    required this.status,
  });

  final String applicationId;
  final String status;

  factory PipeBuyerInsuranceProviderApplicationResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return PipeBuyerInsuranceProviderApplicationResult(
      applicationId: '${json['applicationId'] ?? ''}'.trim(),
      status: '${json['status'] ?? 'pending_review'}'.trim(),
    );
  }
}

class PipeBuyerInsuranceAdminDashboardData {
  const PipeBuyerInsuranceAdminDashboardData({
    required this.providerApplications,
    required this.rateApplications,
    required this.providers,
    required this.counts,
  });

  final List<Map<String, dynamic>> providerApplications;
  final List<InsuranceRateApplicationSummary> rateApplications;
  final List<Map<String, dynamic>> providers;
  final Map<String, int> counts;

  factory PipeBuyerInsuranceAdminDashboardData.fromJson(
    Map<String, dynamic> json,
  ) {
    List<Map<String, dynamic>> readMaps(Object? raw) {
      if (raw is! List) return const <Map<String, dynamic>>[];
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    final countsRaw = json['counts'];
    final parsedCounts = <String, int>{};
    if (countsRaw is Map) {
      for (final entry in countsRaw.entries) {
        parsedCounts['${entry.key}'] = (entry.value as num?)?.toInt() ?? 0;
      }
    }

    return PipeBuyerInsuranceAdminDashboardData(
      providerApplications: readMaps(json['providerApplications']),
      rateApplications: readMaps(json['rateApplications'])
          .map(InsuranceRateApplicationSummary.fromJson)
          .toList(growable: false),
      providers: readMaps(json['providers']),
      counts: parsedCounts,
    );
  }
}

class PipeBuyerInsuranceClient {
  PipeBuyerInsuranceClient({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions,
        _auth = auth;

  FirebaseFunctions? _functions;
  FirebaseAuth? _auth;

  FirebaseFunctions get _resolvedFunctions =>
      _functions ??= FirebaseFunctions.instance;

  FirebaseAuth get _resolvedAuth => _auth ??= FirebaseAuth.instance;

  User? get _safeCurrentUser {
    try {
      return _resolvedAuth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => _safeCurrentUser != null;

  String get currentUserEmail => _safeCurrentUser?.email?.trim() ?? '';

  String get currentUserDisplayName =>
      _safeCurrentUser?.displayName?.trim() ?? '';

  Future<bool> checkAdministratorAccess({bool forceRefresh = true}) async {
    try {
      return await marketplaceAdministratorAccess(
        auth: _auth,
        forceRefresh: forceRefresh,
      );
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> payload, {
    bool requiresAuthentication = true,
  }) async {
    if (requiresAuthentication && _safeCurrentUser == null) {
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
          'The Commercial Insurance service returned an invalid response.',
        );
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
          'Your account does not have permission for this Commercial Insurance action.',
        'not-found' =>
          'The requested Commercial Insurance record was not found.',
        'failed-precondition' =>
          'This Commercial Insurance action cannot be completed in its current state.',
        'resource-exhausted' =>
          'Too many submissions were made recently. Please wait and try again.',
        'invalid-argument' =>
          'Check the entered insurance application details and try again.',
        _ =>
          'The Pipe Buyer Commercial Insurance service is temporarily unavailable.',
      });
    }
  }

  Future<PipeBuyerInsuranceProvidersResult> listProviders({
    String query = '',
    String coverageLine = '',
    String countryCode = '',
    String regionCode = '',
    String providerType = '',
    bool msaOnly = false,
    bool fastCoiOnly = false,
    int pageSize = 60,
  }) async {
    final result = await _call(
      'listInsuranceProviders',
      <String, Object?>{
        'query': query,
        'coverageLine': coverageLine,
        'countryCode': countryCode,
        'regionCode': regionCode,
        'providerType': providerType,
        'msaOnly': msaOnly,
        'fastCoiOnly': fastCoiOnly,
        'pageSize': pageSize,
      },
      requiresAuthentication: false,
    );
    final raw = result['providers'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => InsuranceProviderListing.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false)
        : const <InsuranceProviderListing>[];
    return PipeBuyerInsuranceProvidersResult(
      providers: items,
      totalMatched: (result['totalMatched'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<PipeBuyerInsuranceRateSubmissionResult> submitRateApplication({
    required String companyName,
    required String contactName,
    required String email,
    required String phone,
    required String countryCode,
    required String regionCode,
    required String city,
    List<String> operatingBasins = const <String>[],
    required List<String> coverageLines,
    List<String> msaRequirements = const <String>[],
    int fleetVehicleCount = 0,
    double equipmentValueUsd = 0,
    String annualRevenueBand = '500k_2m',
    String dotOrMcNumber = '',
    String desiredEffectiveDate = '',
    String claimsSummary = '',
    String? targetProviderId,
    String targetProviderName = '',
    String notes = '',
  }) async {
    final result = await _call(
      'submitInsuranceRateApplication',
      <String, Object?>{
        'companyName': companyName,
        'contactName': contactName,
        'email': email,
        'phone': phone,
        'countryCode': countryCode,
        'regionCode': regionCode,
        'city': city,
        'operatingBasins': operatingBasins,
        'coverageLines': coverageLines,
        'msaRequirements': msaRequirements,
        'fleetVehicleCount': fleetVehicleCount,
        'equipmentValueUsd': equipmentValueUsd,
        'annualRevenueBand': annualRevenueBand,
        'dotOrMcNumber': dotOrMcNumber,
        'desiredEffectiveDate': desiredEffectiveDate,
        'claimsSummary': claimsSummary,
        if (targetProviderId != null && targetProviderId.trim().isNotEmpty)
          'targetProviderId': targetProviderId.trim(),
        'targetProviderName': targetProviderName,
        'notes': notes,
      },
      requiresAuthentication: false,
    );
    return PipeBuyerInsuranceRateSubmissionResult.fromJson(result);
  }

  Future<List<InsuranceRateApplicationSummary>> listMyRateApplications() async {
    final result = await _call(
      'listMyInsuranceRateApplications',
      const <String, Object?>{},
    );
    final raw = result['applications'];
    if (raw is! List) return const <InsuranceRateApplicationSummary>[];
    return raw
        .whereType<Map>()
        .map((item) => InsuranceRateApplicationSummary.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  Future<PipeBuyerInsuranceProviderApplicationResult>
      submitProviderApplication({
    required String companyName,
    required String providerType,
    required String contactName,
    String contactTitle = '',
    required String email,
    required String phone,
    String website = '',
    String logoUrl = '',
    required String licenseSummary,
    String countryCode = 'US',
    String regionCode = '',
    String headquartersCity = '',
    List<String> licensedCountries = const <String>['US'],
    List<String> licensedRegions = const <String>[],
    List<String> operatingBasins = const <String>[],
    required List<String> coverageLines,
    String amBestRating = '',
    double maxLimitUsd = 0,
    bool fastCoi24x7 = false,
    bool msaCompliant = false,
    double minimumPremiumUsd = 0,
    String summary = '',
  }) async {
    final result = await _call(
      'submitInsuranceProviderApplication',
      <String, Object?>{
        'companyName': companyName,
        'providerType': providerType,
        'contactName': contactName,
        'contactTitle': contactTitle,
        'email': email,
        'phone': phone,
        'website': website,
        'logoUrl': logoUrl,
        'licenseSummary': licenseSummary,
        'countryCode': countryCode,
        'regionCode': regionCode,
        'headquartersCity': headquartersCity,
        'licensedCountries': licensedCountries,
        'licensedRegions': licensedRegions,
        'operatingBasins': operatingBasins,
        'coverageLines': coverageLines,
        'amBestRating': amBestRating,
        'maxLimitUsd': maxLimitUsd,
        'fastCoi24x7': fastCoi24x7,
        'msaCompliant': msaCompliant,
        'minimumPremiumUsd': minimumPremiumUsd,
        'summary': summary,
      },
      requiresAuthentication: false,
    );
    return PipeBuyerInsuranceProviderApplicationResult.fromJson(result);
  }

  Future<PipeBuyerInsuranceAdminDashboardData> listAdminDashboard() async {
    final result = await _call(
      'listAdminInsuranceDashboard',
      const <String, Object?>{},
    );
    return PipeBuyerInsuranceAdminDashboardData.fromJson(result);
  }

  Future<Map<String, dynamic>> reviewProviderApplication({
    required String applicationId,
    required String decision,
    bool featured = false,
    String reviewNote = '',
  }) {
    return _call(
      'reviewInsuranceProviderApplication',
      <String, Object?>{
        'applicationId': applicationId,
        'decision': decision,
        'featured': featured,
        'reviewNote': reviewNote,
      },
    );
  }

  Future<String> upsertProvider({
    String? providerId,
    required Map<String, Object?> provider,
  }) async {
    final result = await _call(
      'upsertInsuranceProvider',
      <String, Object?>{
        if (providerId != null && providerId.trim().isNotEmpty)
          'providerId': providerId.trim(),
        'provider': provider,
      },
    );
    return '${result['providerId'] ?? ''}'.trim();
  }

  Future<void> updateRateApplicationStatus({
    required String applicationId,
    required String status,
    List<String>? matchedProviderIds,
    List<String>? matchedProviderNames,
    String? brokerResponseNotes,
  }) {
    return _call(
      'updateInsuranceRateApplicationStatus',
      <String, Object?>{
        'applicationId': applicationId,
        'status': status,
        if (matchedProviderIds != null)
          'matchedProviderIds': matchedProviderIds,
        if (matchedProviderNames != null)
          'matchedProviderNames': matchedProviderNames,
        if (brokerResponseNotes != null)
          'brokerResponseNotes': brokerResponseNotes,
      },
    ).then((_) {});
  }
}
