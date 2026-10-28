import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'pipebuyer_partner_taxonomy.dart';

class PipeBuyerPartnerClient {
  PipeBuyerPartnerClient({
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

  String? get currentUserEmail => _safeCurrentUser?.email;
  String? get currentUserDisplayName => _safeCurrentUser?.displayName;
  bool get isSignedIn => _safeCurrentUser != null;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> payload, {
    bool requiresAuthentication = false,
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
            'The Partner Program service returned an invalid response.');
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
          'Your account does not have permission for this Partner Program action.',
        'not-found' => 'The requested Partner Program record was not found.',
        'resource-exhausted' =>
          'Too many requests were submitted recently. Please wait a moment and try again.',
        'invalid-argument' =>
          'Check the partnership details and contact fields, then try again.',
        _ =>
          'The Pipe Buyer Partner Program service is temporarily unavailable.',
      });
    }
  }

  Future<List<PartnerShowcaseDeal>> listShowcaseDeals({
    String brandCategory = '',
    String programType = '',
    String region = '',
    String query = '',
    bool featuredOnly = false,
  }) async {
    final result = await _call(
      'listPartnerShowcaseDeals',
      <String, Object?>{
        'brandCategory': brandCategory,
        'programType': programType,
        'region': region,
        'query': query,
        'featuredOnly': featuredOnly,
      },
    );
    final rawItems = result['items'];
    if (rawItems is! List) return const <PartnerShowcaseDeal>[];
    return rawItems
        .whereType<Map>()
        .map((item) =>
            PartnerShowcaseDeal.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> submitPartnerInquiry({
    required String companyName,
    required String brandCategory,
    required List<String> programTypes,
    required String commercialModel,
    required String headline,
    required String productSummary,
    String dealOrDiscountOffer = '',
    List<String> targetRegions = const <String>['North America'],
    int? estimatedMonthlyBudgetUsd,
    required String contactName,
    String contactTitle = '',
    required String email,
    required String phone,
    String website = '',
    String logoUrl = '',
    String bannerUrl = '',
    String notes = '',
  }) {
    return _call(
      'submitPartnerInquiry',
      <String, Object?>{
        'companyName': companyName,
        'brandCategory': brandCategory,
        'programTypes': programTypes,
        'commercialModel': commercialModel,
        'headline': headline,
        'productSummary': productSummary,
        'dealOrDiscountOffer': dealOrDiscountOffer,
        'targetRegions': targetRegions,
        if (estimatedMonthlyBudgetUsd != null)
          'estimatedMonthlyBudgetUsd': estimatedMonthlyBudgetUsd,
        'contactName': contactName,
        'contactTitle': contactTitle,
        'email': email,
        'phone': phone,
        'website': website,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'notes': notes,
      },
    );
  }

  Future<Map<String, dynamic>> submitDealInterest({
    required String showcaseId,
    required String partnerName,
    required String companyName,
    required String contactName,
    required String email,
    required String phone,
    String fleetOrQuantityNeed = '',
    String region = '',
    String message = '',
  }) {
    return _call(
      'submitPartnerDealInterest',
      <String, Object?>{
        'showcaseId': showcaseId,
        'partnerName': partnerName,
        'companyName': companyName,
        'contactName': contactName,
        'email': email,
        'phone': phone,
        'fleetOrQuantityNeed': fleetOrQuantityNeed,
        'region': region,
        'message': message,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listMyInquiries() async {
    final result = await _call(
      'listMyPartnerInquiries',
      const <String, Object?>{},
      requiresAuthentication: true,
    );
    final raw = result['items'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> listAdminDashboard() {
    return _call(
      'listAdminPartnerProgramDashboard',
      const <String, Object?>{},
      requiresAuthentication: true,
    );
  }

  Future<Map<String, dynamic>> reviewPartnerInquiry({
    required String inquiryId,
    required String status,
    String adminNotes = '',
    bool publishShowcase = false,
    bool featured = false,
    String offerBadge = '',
    List<String> productHighlights = const <String>[],
  }) {
    return _call(
      'reviewPartnerInquiry',
      <String, Object?>{
        'inquiryId': inquiryId,
        'status': status,
        'adminNotes': adminNotes,
        'publishShowcase': publishShowcase,
        'featured': featured,
        if (offerBadge.isNotEmpty) 'offerBadge': offerBadge,
        if (productHighlights.isNotEmpty)
          'productHighlights': productHighlights,
      },
      requiresAuthentication: true,
    );
  }

  Future<Map<String, dynamic>> upsertPartnerShowcaseDeal(
    Map<String, Object?> payload,
  ) {
    return _call(
      'upsertPartnerShowcaseDeal',
      payload,
      requiresAuthentication: true,
    );
  }
}
