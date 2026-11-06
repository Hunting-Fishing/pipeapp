import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'marketplace_admin_access.dart';
import 'pipebuyer_shop_taxonomy.dart';

typedef ShopExternalUrlLauncher = Future<bool> Function(Uri uri);

class PipeBuyerShopRoleSession {
  const PipeBuyerShopRoleSession({
    required this.authorized,
    required this.reason,
    this.uid,
    this.role,
    this.isAdmin = false,
    this.allowedPlatforms = const <String>['all'],
  });

  const PipeBuyerShopRoleSession.signedOut()
      : authorized = false,
        reason = 'signed_out',
        uid = null,
        role = null,
        isAdmin = false,
        allowedPlatforms = const <String>[];

  const PipeBuyerShopRoleSession.authorizedAdmin({this.uid})
      : authorized = true,
        reason = 'authorized',
        role = 'administrator',
        isAdmin = true,
        allowedPlatforms = const <String>['all'];

  final bool authorized;
  final String reason;
  final String? uid;
  final String? role;
  final bool isAdmin;
  final List<String> allowedPlatforms;

  bool get canManageCatalog =>
      authorized &&
      (isAdmin ||
          role == 'administrator' ||
          role == 'store_manager' ||
          role == 'catalog_editor' ||
          role == 'affiliate_contributor');

  bool get canReviewVendors =>
      authorized &&
      (isAdmin || role == 'administrator' || role == 'store_manager');

  bool get canManageSettingsAndRoles =>
      authorized && (isAdmin || role == 'administrator');

  String get roleDisplayLabel => switch (role) {
        'administrator' => 'Platform Administrator',
        'store_manager' => 'Store Manager',
        'catalog_editor' => 'Affiliate Catalog Editor',
        'affiliate_contributor' => 'Affiliate Product Contributor',
        _ => isAdmin ? 'Platform Administrator' : 'No Store Role',
      };

  factory PipeBuyerShopRoleSession.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PipeBuyerShopRoleSession.signedOut();
    final rawPlatforms = json['allowedPlatforms'];
    final platforms = rawPlatforms is Iterable
        ? rawPlatforms
            .map((e) => e?.toString().trim().toLowerCase() ?? '')
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
        : const <String>['all'];
    return PipeBuyerShopRoleSession(
      authorized: json['authorized'] == true,
      reason: json['reason']?.toString() ?? 'role_missing',
      uid: json['uid']?.toString(),
      role: json['role']?.toString(),
      isAdmin: json['isAdmin'] == true || json['role'] == 'administrator',
      allowedPlatforms: platforms.isEmpty ? const <String>['all'] : platforms,
    );
  }
}

class PipeBuyerShopCatalogSnapshot {
  const PipeBuyerShopCatalogSnapshot({
    required this.settings,
    required this.products,
    required this.vendors,
    this.suppressedIds = const <String>{},
    this.fromLiveBackend = false,
  });

  final PipeBuyerShopSettings settings;
  final List<PipeBuyerShopProduct> products;
  final List<Map<String, dynamic>> vendors;
  final Set<String> suppressedIds;
  final bool fromLiveBackend;
}

class PipeBuyerShopAdminSnapshot {
  const PipeBuyerShopAdminSnapshot({
    required this.settings,
    required this.products,
    required this.applications,
    required this.vendors,
    required this.analytics,
    this.actor = const PipeBuyerShopRoleSession.authorizedAdmin(),
    this.staff = const <Map<String, dynamic>>[],
  });

  final PipeBuyerShopSettings settings;
  final List<PipeBuyerShopProduct> products;
  final List<Map<String, dynamic>> applications;
  final List<Map<String, dynamic>> vendors;
  final Map<String, dynamic> analytics;
  final PipeBuyerShopRoleSession actor;
  final List<Map<String, dynamic>> staff;
}

class PipeBuyerShopClient {
  PipeBuyerShopClient({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    ShopExternalUrlLauncher? urlLauncher,
  })  : _functions = functions,
        _auth = auth,
        _urlLauncher = urlLauncher;

  static const String _savedPrefsKey = 'pipebuyer_saved_shop_ids_v1';
  static const String _regionPrefsKey = 'pipebuyer_shop_region_v1';

  FirebaseFunctions? _functions;
  FirebaseAuth? _auth;
  final ShopExternalUrlLauncher? _urlLauncher;

  bool get _firebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFunctions get _resolvedFunctions =>
      _functions ??= FirebaseFunctions.instance;

  FirebaseAuth? get _resolvedAuth {
    if (_auth != null) return _auth;
    if (!_firebaseReady) return null;
    return _auth = FirebaseAuth.instance;
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> payload, {
    bool requiresAuthentication = true,
  }) async {
    final auth = _resolvedAuth;
    if (requiresAuthentication && auth?.currentUser == null) {
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
            'The PipeBuyer Store service returned an invalid response.');
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
          'Your account does not have permission for this Store action.',
        'not-found' => 'The requested Store item or application was not found.',
        'failed-precondition' =>
          'This Store action is temporarily unavailable.',
        'invalid-argument' =>
          'Check the entered product or partner details and try again.',
        _ => 'The PipeBuyer Store service is temporarily unavailable.',
      });
    }
  }

  Future<PipeBuyerShopRoleSession> resolveShopRoleSession({
    bool forceRefresh = false,
  }) async {
    final auth = _resolvedAuth;
    final user = auth?.currentUser;
    if (user == null) {
      return const PipeBuyerShopRoleSession.signedOut();
    }

    try {
      final tokenResult = await user.getIdTokenResult(forceRefresh);
      final claims = tokenResult.claims ?? const <String, dynamic>{};
      if (claims['restricted'] == true) {
        return PipeBuyerShopRoleSession(
          authorized: false,
          reason: 'restricted',
          uid: user.uid,
        );
      }
      final adminState = marketplaceAdministratorClaimsState(claims);
      if (adminState == MarketplaceAdministratorState.authorized) {
        return PipeBuyerShopRoleSession(
          authorized: true,
          reason: 'authorized',
          uid: user.uid,
          role: 'administrator',
          isAdmin: true,
        );
      }
      if (adminState == MarketplaceAdministratorState.mfaRequired) {
        return PipeBuyerShopRoleSession(
          authorized: false,
          reason: 'mfa_required',
          uid: user.uid,
          role: 'administrator',
        );
      }

      final shopRole =
          claims['shopRole']?.toString().trim().toLowerCase() ?? '';
      if (shopRole == 'store_manager' ||
          shopRole == 'catalog_editor' ||
          shopRole == 'affiliate_contributor') {
        try {
          final remote = await _call(
            'getShopSession',
            const <String, Object?>{},
          );
          return PipeBuyerShopRoleSession.fromJson(remote);
        } catch (_) {
          return PipeBuyerShopRoleSession(
            authorized: true,
            reason: 'authorized',
            uid: user.uid,
            role: shopRole,
          );
        }
      }

      // Check live server session for newly provisioned Google Sign-in users
      // whose cached ID token may not yet include their newly granted shopRole.
      if (user.emailVerified || claims['email_verified'] == true) {
        try {
          final remote = await _call(
            'getShopSession',
            const <String, Object?>{},
          );
          final parsed = PipeBuyerShopRoleSession.fromJson(remote);
          if (parsed.authorized) {
            return parsed;
          }
        } catch (_) {}
      }

      return PipeBuyerShopRoleSession(
        authorized: false,
        reason: 'role_missing',
        uid: user.uid,
      );
    } catch (_) {
      return PipeBuyerShopRoleSession(
        authorized: false,
        reason: 'unavailable',
        uid: user.uid,
      );
    }
  }

  static List<PipeBuyerShopProduct> mergeWithStarterCatalog(
    List<PipeBuyerShopProduct> liveProducts, {
    bool includeStarterFallback = true,
    Iterable<String> suppressedIds = const <String>[],
  }) {
    final suppressed = suppressedIds
        .map((id) => id.trim().toLowerCase())
        .where((id) => id.isNotEmpty)
        .toSet();
    final byId = <String, PipeBuyerShopProduct>{};
    if (includeStarterFallback) {
      for (final item in PipeBuyerShopTaxonomy.starterCatalog) {
        if (!suppressed.contains(item.id.toLowerCase())) {
          byId[item.id] = item;
        }
      }
    }
    for (final live in liveProducts) {
      if (live.id.isEmpty) continue;
      if (live.status != 'active' ||
          suppressed.contains(live.id.toLowerCase())) {
        byId.remove(live.id);
      } else {
        byId[live.id] = live;
      }
    }
    final merged = byId.values.toList();
    merged.sort((a, b) {
      if (a.featured != b.featured) return a.featured ? -1 : 1;
      final rankCmp = a.priorityRank.compareTo(b.priorityRank);
      if (rankCmp != 0) return rankCmp;
      return a.title.compareTo(b.title);
    });
    return merged;
  }

  /// Builds the complete Admin view combining custom Firestore items AND
  /// unhidden built-in starter items so an Admin can edit or remove any link
  /// without needing to seed first.
  static List<PipeBuyerShopProduct> mergeAdminCatalog(
    List<PipeBuyerShopProduct> firestoreProducts, {
    Iterable<String> hiddenStarterIds = const <String>[],
  }) {
    final hidden = hiddenStarterIds
        .map((id) => id.trim().toLowerCase())
        .where((id) => id.isNotEmpty)
        .toSet();
    final byId = <String, PipeBuyerShopProduct>{};
    for (final starter in PipeBuyerShopTaxonomy.starterCatalog) {
      if (!hidden.contains(starter.id.toLowerCase())) {
        byId[starter.id] = starter;
      }
    }
    for (final item in firestoreProducts) {
      if (item.id.isEmpty) continue;
      byId[item.id] = item;
    }
    final merged = byId.values.toList();
    merged.sort((a, b) {
      if ((a.status == 'active') != (b.status == 'active')) {
        return a.status == 'active' ? -1 : 1;
      }
      if (a.featured != b.featured) return a.featured ? -1 : 1;
      final rankCmp = a.priorityRank.compareTo(b.priorityRank);
      if (rankCmp != 0) return rankCmp;
      return a.title.compareTo(b.title);
    });
    return merged;
  }

  Future<PipeBuyerShopCatalogSnapshot> loadStoreCatalog() async {
    if (!_firebaseReady && _functions == null) {
      return PipeBuyerShopCatalogSnapshot(
        settings: const PipeBuyerShopSettings(),
        products: mergeWithStarterCatalog(const <PipeBuyerShopProduct>[]),
        vendors: const <Map<String, dynamic>>[],
      );
    }
    try {
      final result = await _call(
        'listShopStoreCatalog',
        const <String, Object?>{},
        requiresAuthentication: false,
      );
      final settings = PipeBuyerShopSettings.fromJson(
        result['settings'] is Map
            ? Map<String, dynamic>.from(result['settings'] as Map)
            : null,
      );
      final rawSuppressed = result['suppressedProductIds'];
      final suppressedIds = <String>{
        ...settings.hiddenStarterIds,
        if (rawSuppressed is Iterable)
          ...rawSuppressed
              .map((e) => e?.toString().trim().toLowerCase() ?? '')
              .where((e) => e.isNotEmpty),
      };

      final rawProducts = result['products'];
      final liveProducts = rawProducts is List
          ? rawProducts
              .whereType<Map>()
              .map(
                (item) => PipeBuyerShopProduct.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <PipeBuyerShopProduct>[];

      final rawVendors = result['vendors'];
      final vendors = rawVendors is List
          ? rawVendors
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];

      return PipeBuyerShopCatalogSnapshot(
        settings: settings,
        products: mergeWithStarterCatalog(
          liveProducts,
          suppressedIds: suppressedIds,
        ),
        vendors: vendors,
        suppressedIds: suppressedIds,
        fromLiveBackend: true,
      );
    } catch (_) {
      return PipeBuyerShopCatalogSnapshot(
        settings: const PipeBuyerShopSettings(),
        products: mergeWithStarterCatalog(const <PipeBuyerShopProduct>[]),
        vendors: const <Map<String, dynamic>>[],
      );
    }
  }

  static String inferDefaultShopperCountry() {
    try {
      final rawCountry = ui.PlatformDispatcher.instance.locale.countryCode
              ?.trim()
              .toUpperCase() ??
          '';
      if (rawCountry.isNotEmpty) {
        final match = PipeBuyerShopTaxonomy.countryOptionByCode(rawCountry);
        if (match != null && match.code != 'ALL') {
          return match.code;
        }
      }
    } catch (_) {}
    return 'US';
  }

  Future<String> loadPreferredRegion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_regionPrefsKey)?.trim().toUpperCase();
      if (saved != null && saved.isNotEmpty) {
        if (saved == 'ALL' ||
            PipeBuyerShopTaxonomy.countryOptionByCode(saved) != null) {
          return saved;
        }
      }
    } catch (_) {}
    return inferDefaultShopperCountry();
  }

  Future<void> savePreferredRegion(String regionCode) async {
    final upper = regionCode.trim().toUpperCase();
    final normalized = (upper == 'ALL' ||
            PipeBuyerShopTaxonomy.countryOptionByCode(upper) != null)
        ? upper
        : 'US';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_regionPrefsKey, normalized);
    } catch (_) {}
  }

  Future<PipeBuyerParsedAffiliateSubmission?> fetchRemoteAffiliatePreview(
    String rawInput,
  ) async {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;
    if (!_firebaseReady && _functions == null) return null;
    try {
      final result = await _call(
        'parseShopAffiliateLink',
        <String, Object?>{
          'rawInput': trimmed,
          'fetchMetadata': true,
        },
      );
      if (result.isEmpty ||
          (result['destinationUrl']?.toString().trim().isEmpty ?? true)) {
        return null;
      }
      return PipeBuyerParsedAffiliateSubmission.fromServerJson(result);
    } catch (_) {
      return null;
    }
  }

  Future<Set<String>> loadSavedProductIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_savedPrefsKey) ?? const <String>[];
      return list.where((e) => e.trim().isNotEmpty).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<Set<String>> toggleSavedProduct(
    PipeBuyerShopProduct product,
    Set<String> currentSaved,
  ) async {
    final next = Set<String>.from(currentSaved);
    final nowSaved = !next.contains(product.id);
    if (nowSaved) {
      next.add(product.id);
    } else {
      next.remove(product.id);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_savedPrefsKey, next.toList(growable: false));
    } catch (_) {}

    if (_resolvedAuth?.currentUser != null) {
      unawaited(
        _call(
          'toggleSavedShopProduct',
          <String, Object?>{
            'productId': product.id,
            'saved': nowSaved,
            'title': product.title,
            'categoryCode': product.categoryCode,
            'brand': product.brand,
          },
        ).catchError((_) => const <String, dynamic>{}),
      );
    }
    return next;
  }

  Future<bool> openProductAffiliateLink({
    required PipeBuyerShopProduct product,
    required PipeBuyerShopSettings settings,
    String regionCode = 'US',
    String placement = 'store_grid',
  }) async {
    final targetUrl = PipeBuyerShopUrlBuilder.buildMonetizedUrl(
      product,
      settings,
      regionCode: regionCode,
    );
    if (targetUrl.isEmpty) return false;
    final uri = Uri.tryParse(targetUrl);
    if (uri == null) return false;

    final launcher = _urlLauncher ??
        ((Uri target) => launchUrl(
              target,
              mode: LaunchMode.externalApplication,
            ));
    final opened = await launcher(uri);

    if (_firebaseReady || _functions != null) {
      unawaited(
        _call(
          'recordShopAffiliateClick',
          <String, Object?>{
            'productId': product.id,
            'categoryCode': product.categoryCode,
            'sourceType': product.sourceType.code,
            'brand': product.brand,
            'regionCode': regionCode,
            'placement': placement,
            'destinationHost': uri.host,
          },
          requiresAuthentication: false,
        ).catchError((_) => const <String, dynamic>{}),
      );
    }
    return opened;
  }

  Future<Map<String, dynamic>> submitVendorApplication({
    required String companyName,
    required String contactName,
    required String email,
    required String phone,
    required String websiteUrl,
    required String partnershipTrack,
    required List<String> categories,
    required List<String> brandsCarried,
    required List<String> fulfillmentRegions,
    required String estimatedSkuCount,
    String affiliateProgramDetails = '',
    String catalogNotes = '',
  }) {
    return _call(
      'submitShopVendorApplication',
      <String, Object?>{
        'companyName': companyName,
        'contactName': contactName,
        'email': email,
        'phone': phone,
        'websiteUrl': websiteUrl,
        'partnershipTrack': partnershipTrack,
        'categories': categories,
        'brandsCarried': brandsCarried,
        'fulfillmentRegions': fulfillmentRegions,
        'estimatedSkuCount': estimatedSkuCount,
        'affiliateProgramDetails': affiliateProgramDetails,
        'catalogNotes': catalogNotes,
      },
    );
  }

  Future<PipeBuyerShopAdminSnapshot> getAdminDashboard() async {
    final result = await _call(
      'getShopAdminDashboard',
      const <String, Object?>{},
    );
    final actor = result['actor'] is Map
        ? PipeBuyerShopRoleSession.fromJson(<String, dynamic>{
            'authorized': true,
            'reason': 'authorized',
            ...Map<String, dynamic>.from(result['actor'] as Map),
          })
        : const PipeBuyerShopRoleSession.authorizedAdmin();
    final settings = PipeBuyerShopSettings.fromJson(
      result['settings'] is Map
          ? Map<String, dynamic>.from(result['settings'] as Map)
          : null,
    );
    final rawProducts = result['products'];
    final products = rawProducts is List
        ? rawProducts
            .whereType<Map>()
            .map(
              (item) => PipeBuyerShopProduct.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false)
        : const <PipeBuyerShopProduct>[];
    final rawApps = result['applications'];
    final applications = rawApps is List
        ? rawApps
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final rawVendors = result['vendors'];
    final vendors = rawVendors is List
        ? rawVendors
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final rawStaff = result['staff'];
    final staff = rawStaff is List
        ? rawStaff
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final analytics = result['analytics'] is Map
        ? Map<String, dynamic>.from(result['analytics'] as Map)
        : const <String, dynamic>{};

    return PipeBuyerShopAdminSnapshot(
      actor: actor,
      settings: settings,
      products: products,
      applications: applications,
      vendors: vendors,
      staff: staff,
      analytics: analytics,
    );
  }

  Future<PipeBuyerShopSettings> updateStoreSettings(
    PipeBuyerShopSettings settings,
  ) async {
    final result = await _call('updateShopStoreSettings', settings.toJson());
    return PipeBuyerShopSettings.fromJson(
      result['settings'] is Map
          ? Map<String, dynamic>.from(result['settings'] as Map)
          : settings.toJson(),
    );
  }

  Future<Map<String, dynamic>> upsertProduct(Map<String, Object?> payload) {
    return _call('upsertShopProduct', payload);
  }

  Future<Map<String, dynamic>> bulkUpsertProducts(
    List<Map<String, Object?>> items, {
    void Function(int completed, int total)? onProgress,
  }) async {
    if (items.isEmpty) {
      return <String, dynamic>{
        'importedCount': 0,
        'skippedBlankCount': 0,
        'failedCount': 0,
        'errors': const <Object>[],
      };
    }

    const chunkSize = 200;
    var totalImported = 0;
    var totalSkipped = 0;
    var totalFailed = 0;
    final allErrors = <Map<String, dynamic>>[];

    for (var offset = 0; offset < items.length; offset += chunkSize) {
      final end = (offset + chunkSize > items.length)
          ? items.length
          : offset + chunkSize;
      final slice = items.sublist(offset, end);
      final result = await _call(
        'bulkUpsertShopProducts',
        <String, Object?>{'items': slice},
      );
      totalImported += (result['importedCount'] as num?)?.toInt() ?? 0;
      totalSkipped += (result['skippedBlankCount'] as num?)?.toInt() ?? 0;
      totalFailed += (result['failedCount'] as num?)?.toInt() ?? 0;
      final errs = result['errors'];
      if (errs is List && allErrors.length < 25) {
        for (final e in errs) {
          if (e is Map && allErrors.length < 25) {
            allErrors.add(Map<String, dynamic>.from(e));
          }
        }
      }
      onProgress?.call(end, items.length);
    }

    return <String, dynamic>{
      'importedCount': totalImported,
      'skippedBlankCount': totalSkipped,
      'failedCount': totalFailed,
      'errors': allErrors,
    };
  }

  Future<Map<String, dynamic>> setProductVisibility({
    required String productId,
    String? status,
    bool? featured,
    PipeBuyerShopProduct? starterProduct,
  }) {
    return _call(
      'setShopProductVisibility',
      <String, Object?>{
        'productId': productId,
        if (status != null) 'status': status,
        if (featured != null) 'featured': featured,
        if (starterProduct != null)
          'starterProduct': starterProduct.toUpsertPayload(),
      },
    );
  }

  Future<Map<String, dynamic>> deleteProduct({
    required String productId,
    String title = '',
    bool hideStarterFallback = true,
  }) {
    return _call(
      'deleteShopProduct',
      <String, Object?>{
        'productId': productId,
        'title': title,
        'hideStarterFallback': hideStarterFallback,
      },
    );
  }

  Future<Map<String, dynamic>> restoreStarterProducts({String? productId}) {
    return _call(
      'restoreStarterShopProducts',
      <String, Object?>{
        'mode': 'restore',
        if (productId != null && productId.trim().isNotEmpty)
          'productId': productId.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> hideStarterProducts(List<String> productIds) {
    return _call(
      'restoreStarterShopProducts',
      <String, Object?>{
        'mode': 'hide',
        'productIds': productIds,
      },
    );
  }

  Future<int> seedStarterCatalogToFirestore() async {
    var count = 0;
    for (final item in PipeBuyerShopTaxonomy.starterCatalog) {
      await upsertProduct(item.toUpsertPayload());
      count += 1;
    }
    return count;
  }

  Future<Map<String, dynamic>> reviewVendorApplication({
    required String applicationId,
    required String status,
    String reviewNotes = '',
  }) {
    return _call(
      'reviewShopVendorApplication',
      <String, Object?>{
        'applicationId': applicationId,
        'status': status,
        'reviewNotes': reviewNotes,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listShopStaff() async {
    final result = await _call('listShopStaff', const <String, Object?>{});
    final raw = result['staff'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> manageShopStaff({
    required String email,
    required String role,
    required bool active,
    List<String>? allowedPlatforms,
  }) {
    return _call(
      'manageShopStaff',
      <String, Object?>{
        'email': email.trim().toLowerCase(),
        'role': role.trim().toLowerCase(),
        'active': active,
        if (allowedPlatforms != null) 'allowedPlatforms': allowedPlatforms,
      },
    );
  }
}
