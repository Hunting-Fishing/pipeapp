import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PipeBuyerYellowPagesAccess {
  const PipeBuyerYellowPagesAccess({
    required this.authorized,
    required this.role,
    required this.reason,
  });

  final bool authorized;
  final String? role;
  final String? reason;

  bool get isAdministrator => role == 'administrator';
  bool get isManager => role == 'manager' || isAdministrator;
  bool get isAgent => role == 'agent' || isManager;

  factory PipeBuyerYellowPagesAccess.fromJson(Map<String, dynamic> json) {
    return PipeBuyerYellowPagesAccess(
      authorized: json['authorized'] == true,
      role: json['role']?.toString(),
      reason: json['reason']?.toString(),
    );
  }
}

class PipeBuyerYellowPagesPage<T> {
  const PipeBuyerYellowPagesPage({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;
}

class PipeBuyerYellowPagesClient {
  PipeBuyerYellowPagesClient({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> payload, {
    bool requiresAuthentication = true,
  }) async {
    if (requiresAuthentication && _auth.currentUser == null) {
      throw StateError('Sign in to the PipeBuyer Contact Center to continue.');
    }
    try {
      final response = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 30),
            ),
          )
          .call(payload);
      if (response.data is! Map) {
        throw StateError('The Yellow Pages service returned an invalid response.');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (error) {
      final serverMessage = error.message?.trim();
      if (serverMessage != null &&
          serverMessage.isNotEmpty &&
          error.code != 'internal') {
        throw StateError(serverMessage);
      }
      final message = switch (error.code) {
        'unauthenticated' => 'Your session expired. Sign in and try again.',
        'permission-denied' =>
          'This account is not authorized for the PipeBuyer Contact Center.',
        'failed-precondition' =>
          'This action is blocked until the required account or company state is complete.',
        'not-found' => 'The requested Yellow Pages record was not found.',
        'resource-exhausted' =>
          'Too many requests were made in a short period. Wait and try again.',
        'deadline-exceeded' || 'unavailable' =>
          'The Yellow Pages service is temporarily unavailable. Try again.',
        _ => 'The Yellow Pages action could not be completed.',
      };
      throw StateError(message);
    }
  }

  Future<PipeBuyerYellowPagesAccess> getAccess() async {
    final result = await _call(
      'getYellowPagesAccess',
      const <String, Object?>{},
      requiresAuthentication: false,
    );
    return PipeBuyerYellowPagesAccess.fromJson(result);
  }

  Future<PipeBuyerYellowPagesPage<Map<String, dynamic>>> listPublic({
    String? cursor,
    int pageSize = 40,
  }) async {
    final result = await _call(
      'listPipeBuyerYellowPages',
      <String, Object?>{
        'pageSize': pageSize,
        if (cursor != null) 'cursor': cursor,
      },
      requiresAuthentication: false,
    );
    return _pageFromResult(result, 'entries');
  }

  Future<Map<String, dynamic>> getPublicEntry(String companyId) {
    return _call(
      'getPipeBuyerYellowPagesEntry',
      <String, Object?>{'companyId': companyId},
      requiresAuthentication: false,
    );
  }

  Future<PipeBuyerYellowPagesPage<Map<String, dynamic>>> listCompanies({
    String? cursor,
    int pageSize = 50,
    String? filterDimension,
    String? filterValue,
  }) async {
    final result = await _call(
      'listYellowPagesCompanies',
      <String, Object?>{
        'pageSize': pageSize,
        if (cursor != null) 'cursor': cursor,
        if (filterDimension != null) 'filterDimension': filterDimension,
        if (filterValue != null) 'filterValue': filterValue,
      },
    );
    return _pageFromResult(result, 'companies');
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
    String? reason,
  }) {
    return _call(
      'setYellowPagesDoNotContact',
      <String, Object?>{
        'companyId': companyId,
        'enabled': enabled,
        if (reason != null) 'reason': reason,
      },
    ).then((_) {});
  }

  Future<void> reviewVerification(
    String companyId, {
    required String status,
    String? reviewNote,
  }) {
    return _call(
      'reviewYellowPagesVerification',
      <String, Object?>{
        'companyId': companyId,
        'status': status,
        if (reviewNote != null) 'reviewNote': reviewNote,
      },
    ).then((_) {});
  }

  Future<void> setBillingStatus(
    String companyId, {
    required String status,
    DateTime? paidThrough,
    bool nonExpiringPaid = false,
    String? paymentReference,
    String? reviewNote,
  }) {
    return _call(
      'setYellowPagesBillingStatus',
      <String, Object?>{
        'companyId': companyId,
        'status': status,
        'nonExpiringPaid': nonExpiringPaid,
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

  PipeBuyerYellowPagesPage<Map<String, dynamic>> _pageFromResult(
    Map<String, dynamic> result,
    String key,
  ) {
    final raw = result[key];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    return PipeBuyerYellowPagesPage<Map<String, dynamic>>(
      items: items,
      nextCursor: result['nextCursor']?.toString(),
    );
  }
}
