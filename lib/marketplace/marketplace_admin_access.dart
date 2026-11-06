import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Reactive toggle allowing an authorized administrator to preview the exact
/// customer-facing UI ("View what everyone else sees" mode) without signing out.
///
/// Enabling this mode only suppresses admin UI chrome in the client so an
/// administrator can inspect the exact regular-user experience; it never grants
/// privileges to non-admin accounts.
final ValueNotifier<bool> marketplaceAdminViewAsUserMode =
    ValueNotifier<bool>(false);

void setMarketplaceAdminViewAsUserMode(bool enabled) {
  if (marketplaceAdminViewAsUserMode.value != enabled) {
    marketplaceAdminViewAsUserMode.value = enabled;
  }
}

enum MarketplaceAdministratorState {
  signedOut,
  roleMissing,
  mfaRequired,
  authorized,
  unavailable,
}

MarketplaceAdministratorState marketplaceAdministratorClaimsState(
  Map<String, dynamic>? claims,
) {
  final values = claims ?? const <String, dynamic>{};
  if (values['restricted'] == true) {
    return MarketplaceAdministratorState.roleMissing;
  }
  final hasAdministratorRole =
      values['admin'] == true && values['role'] == 'administrator';
  if (!hasAdministratorRole) {
    return MarketplaceAdministratorState.roleMissing;
  }

  final hasPrimaryAdminClaim =
      values['primaryAdmin'] == true && values['email_verified'] == true;
  if (hasPrimaryAdminClaim) {
    return MarketplaceAdministratorState.authorized;
  }

  final hasFederatedAdminApproval = values['federatedAdminApproved'] == true &&
      values['email_verified'] == true;
  if (hasFederatedAdminApproval) {
    return MarketplaceAdministratorState.authorized;
  }

  final firebase = values['firebase'];
  final secondFactor = firebase is Map
      ? firebase['sign_in_second_factor']?.toString().trim()
      : null;
  if (secondFactor == null || secondFactor.isEmpty) {
    return MarketplaceAdministratorState.mfaRequired;
  }
  return MarketplaceAdministratorState.authorized;
}

bool marketplaceAdministratorClaims(Map<String, dynamic>? claims) =>
    marketplaceAdministratorClaimsState(claims) ==
    MarketplaceAdministratorState.authorized;

/// Checks the current user's administrator-token state without trusting email,
/// public profile data, or client-writable Firestore fields.
Future<MarketplaceAdministratorState> marketplaceAdministratorState({
  FirebaseAuth? auth,
  bool forceRefresh = false,
}) async {
  final user = (auth ?? FirebaseAuth.instance).currentUser;
  if (user == null) {
    setMarketplaceAdminViewAsUserMode(false);
    return MarketplaceAdministratorState.signedOut;
  }

  try {
    final result = await user.getIdTokenResult(forceRefresh);
    return marketplaceAdministratorClaimsState(result.claims);
  } on FirebaseAuthException {
    return MarketplaceAdministratorState.unavailable;
  } catch (_) {
    return MarketplaceAdministratorState.unavailable;
  }
}

/// Returns true only when the current token contains the complete approved
/// administrator role and evidence that this sign-in completed MFA.
Future<bool> marketplaceAdministratorAccess({
  FirebaseAuth? auth,
  bool forceRefresh = false,
}) async =>
    await marketplaceAdministratorState(
      auth: auth,
      forceRefresh: forceRefresh,
    ) ==
    MarketplaceAdministratorState.authorized;

/// Returns true when the current user is an authorized administrator AND is
/// not currently previewing the app in "View what everyone else sees" mode.
Future<bool> marketplaceEffectiveAdminUiAccess({
  FirebaseAuth? auth,
  bool forceRefresh = false,
}) async {
  if (marketplaceAdminViewAsUserMode.value) return false;
  return marketplaceAdministratorAccess(
    auth: auth,
    forceRefresh: forceRefresh,
  );
}

const Set<String> _kActiveShopRoles = <String>{
  'affiliate_contributor',
  'catalog_editor',
  'store_manager',
};

const Set<String> _kActiveDirectoryRoles = <String>{
  'agent',
  'manager',
};

/// Scoped permissions assigned to non-owner staff/contributors so UI menus and
/// workspaces expose ONLY the exact modules granted to that user.
@immutable
class MarketplaceStaffPermissionsState {
  const MarketplaceStaffPermissionsState({
    this.signedIn = false,
    this.isFullAdmin = false,
    this.restricted = false,
    this.shopRole = 'none',
    this.allowedAffiliatePlatforms = const <String>[],
    this.yellowPagesRole = 'none',
    this.canGrantPermissions = false,
  });

  const MarketplaceStaffPermissionsState.none()
      : signedIn = false,
        isFullAdmin = false,
        restricted = false,
        shopRole = 'none',
        allowedAffiliatePlatforms = const <String>[],
        yellowPagesRole = 'none',
        canGrantPermissions = false;

  final bool signedIn;
  final bool isFullAdmin;
  final bool restricted;
  final String shopRole;
  final List<String> allowedAffiliatePlatforms;
  final String yellowPagesRole;
  final bool canGrantPermissions;

  bool get hasShopAccess =>
      !restricted && (isFullAdmin || _kActiveShopRoles.contains(shopRole));

  bool get hasDirectoryAccess =>
      !restricted &&
      (isFullAdmin || _kActiveDirectoryRoles.contains(yellowPagesRole));

  bool get hasScopedStaffAccess =>
      signedIn &&
      !isFullAdmin &&
      !restricted &&
      (_kActiveShopRoles.contains(shopRole) ||
          _kActiveDirectoryRoles.contains(yellowPagesRole) ||
          canGrantPermissions);

  String get roleBadgeLabel {
    if (isFullAdmin) return 'ADMIN';
    if (shopRole == 'store_manager') return 'STORE MANAGER';
    if (shopRole == 'catalog_editor') return 'CATALOG EDITOR';
    if (shopRole == 'affiliate_contributor') return 'AFFILIATE STAFF';
    if (yellowPagesRole == 'manager') return 'DIRECTORY MANAGER';
    if (yellowPagesRole == 'agent') return 'DIRECTORY AGENT';
    if (canGrantPermissions) return 'PERMISSIONS STAFF';
    return '';
  }

  String get footerSubtitle {
    if (isFullAdmin) return 'Administrator • Full access';
    if (shopRole == 'store_manager' && hasDirectoryAccess) {
      return 'Store & Directory Manager';
    }
    if (shopRole == 'store_manager') return 'Store Manager • Affiliate access';
    if (shopRole == 'catalog_editor')
      return 'Catalog Editor • Affiliate access';
    if (shopRole == 'affiliate_contributor') {
      return 'Affiliate Contributor • Store';
    }
    if (yellowPagesRole == 'manager') return 'Directory Manager • Staff access';
    if (yellowPagesRole == 'agent') return 'Directory Agent • Staff access';
    if (canGrantPermissions) return 'User Permissions • Staff access';
    return 'Account & membership';
  }

  factory MarketplaceStaffPermissionsState.fromClaimsAndServerDoc({
    required bool signedIn,
    Map<String, dynamic>? claims,
    Map<String, dynamic>? serverPermissionsDoc,
  }) {
    if (!signedIn) return const MarketplaceStaffPermissionsState.none();
    final tokenClaims = claims ?? const <String, dynamic>{};
    final doc = serverPermissionsDoc;

    final restricted = tokenClaims['restricted'] == true ||
        (doc != null && doc['restricted'] == true);
    final isAdmin = !restricted &&
        marketplaceAdministratorClaimsState(tokenClaims) ==
            MarketplaceAdministratorState.authorized;

    String normRole(Object? raw, Set<String> allowed) {
      final v = '${raw ?? ''}'.trim().toLowerCase();
      return allowed.contains(v) ? v : 'none';
    }

    // Prefer the real-time server-only `user_permissions/{uid}` document when
    // present so newly granted or revoked roles take effect immediately before
    // the 1-hour Firebase JWT cache expires.
    final shopRole = doc != null && doc.containsKey('shopRole')
        ? normRole(doc['shopRole'], _kActiveShopRoles)
        : normRole(tokenClaims['shopRole'], _kActiveShopRoles);

    final ypRole = doc != null && doc.containsKey('yellowPagesRole')
        ? normRole(doc['yellowPagesRole'], _kActiveDirectoryRoles)
        : normRole(tokenClaims['yellowPagesRole'], _kActiveDirectoryRoles);

    final permsMap = doc != null && doc['permissions'] is Map
        ? Map<String, dynamic>.from(doc['permissions'] as Map)
        : const <String, dynamic>{};
    final canGrant = !restricted &&
        (isAdmin ||
            (doc != null
                ? permsMap['canGrantPermissions'] == true
                : tokenClaims['canGrantPermissions'] == true));

    final rawPlatforms =
        doc != null && doc['allowedAffiliatePlatforms'] is Iterable
            ? (doc['allowedAffiliatePlatforms'] as Iterable)
                .map((e) => '${e ?? ''}'.trim())
                .where((e) => e.isNotEmpty)
                .toList(growable: false)
            : const <String>['all'];

    return MarketplaceStaffPermissionsState(
      signedIn: true,
      isFullAdmin: isAdmin,
      restricted: restricted,
      shopRole: shopRole,
      allowedAffiliatePlatforms:
          rawPlatforms.isEmpty ? const <String>['all'] : rawPlatforms,
      yellowPagesRole: ypRole,
      canGrantPermissions: canGrant,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarketplaceStaffPermissionsState &&
          other.signedIn == signedIn &&
          other.isFullAdmin == isFullAdmin &&
          other.restricted == restricted &&
          other.shopRole == shopRole &&
          other.yellowPagesRole == yellowPagesRole &&
          other.canGrantPermissions == canGrantPermissions &&
          listEquals(
            other.allowedAffiliatePlatforms,
            allowedAffiliatePlatforms,
          ));

  @override
  int get hashCode => Object.hash(
        signedIn,
        isFullAdmin,
        restricted,
        shopRole,
        yellowPagesRole,
        canGrantPermissions,
        Object.hashAll(allowedAffiliatePlatforms),
      );
}

Future<MarketplaceStaffPermissionsState> resolveMarketplaceStaffPermissions({
  FirebaseAuth? auth,
  FirebaseFirestore? firestore,
  bool forceRefresh = false,
}) async {
  if (auth == null && Firebase.apps.isEmpty) {
    return const MarketplaceStaffPermissionsState.none();
  }
  final user = (auth ?? FirebaseAuth.instance).currentUser;
  if (user == null) {
    return const MarketplaceStaffPermissionsState.none();
  }

  Map<String, dynamic>? claims;
  try {
    final res = await user.getIdTokenResult(forceRefresh);
    claims = res.claims;
  } catch (_) {}

  Map<String, dynamic>? permDoc;
  if (firestore != null || Firebase.apps.isNotEmpty) {
    try {
      final snap = await (firestore ?? FirebaseFirestore.instance)
          .collection('user_permissions')
          .doc(user.uid)
          .get();
      if (snap.exists) {
        permDoc = snap.data();
      }
    } catch (_) {}
  }

  return MarketplaceStaffPermissionsState.fromClaimsAndServerDoc(
    signedIn: true,
    claims: claims,
    serverPermissionsDoc: permDoc,
  );
}

/// Streams real-time staff/contributor permissions for the signed-in user by
/// combining Firebase Auth token changes with the server-controlled
/// `user_permissions/{uid}` document (auto-refreshing the ID token whenever
/// an Administrator grants or updates roles).
Stream<MarketplaceStaffPermissionsState> watchMarketplaceStaffPermissions({
  FirebaseAuth? auth,
  FirebaseFirestore? firestore,
}) {
  if (auth == null && Firebase.apps.isEmpty) {
    return Stream<MarketplaceStaffPermissionsState>.value(
      const MarketplaceStaffPermissionsState.none(),
    );
  }
  final effectiveAuth = auth ?? FirebaseAuth.instance;
  final effectiveDb = firestore ?? FirebaseFirestore.instance;

  late final StreamController<MarketplaceStaffPermissionsState> controller;
  StreamSubscription<User?>? authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? permSub;
  Map<String, dynamic>? latestClaims;
  Map<String, dynamic>? latestPermDoc;
  String? activeUid;
  String? lastSyncedDocStamp;

  void emitCurrent(User? user) {
    if (controller.isClosed) return;
    if (user == null) {
      controller.add(const MarketplaceStaffPermissionsState.none());
      return;
    }
    controller.add(
      MarketplaceStaffPermissionsState.fromClaimsAndServerDoc(
        signedIn: true,
        claims: latestClaims,
        serverPermissionsDoc: latestPermDoc,
      ),
    );
  }

  controller = StreamController<MarketplaceStaffPermissionsState>.broadcast(
    onListen: () {
      authSub = effectiveAuth.idTokenChanges().listen((user) async {
        if (user == null) {
          activeUid = null;
          latestClaims = null;
          latestPermDoc = null;
          lastSyncedDocStamp = null;
          await permSub?.cancel();
          permSub = null;
          emitCurrent(null);
          return;
        }
        final uidChanged = activeUid != user.uid;
        activeUid = user.uid;
        try {
          final tokenRes = await user.getIdTokenResult(uidChanged);
          latestClaims = tokenRes.claims;
        } catch (_) {}
        emitCurrent(user);

        if (uidChanged) {
          await permSub?.cancel();
          permSub = effectiveDb
              .collection('user_permissions')
              .doc(user.uid)
              .snapshots()
              .listen(
            (snap) async {
              latestPermDoc = snap.exists ? snap.data() : null;
              final stamp = '${latestPermDoc?['updatedAt'] ?? ''}|'
                  '${latestPermDoc?['shopRole'] ?? ''}|'
                  '${latestPermDoc?['yellowPagesRole'] ?? ''}|'
                  '${latestPermDoc?['isAdmin'] ?? ''}|'
                  '${latestPermDoc?['restricted'] ?? ''}';
              final shouldRefreshJwt =
                  lastSyncedDocStamp != null && lastSyncedDocStamp != stamp;
              lastSyncedDocStamp = stamp;
              if (shouldRefreshJwt) {
                try {
                  final refreshed = await user.getIdTokenResult(true);
                  latestClaims = refreshed.claims;
                } catch (_) {}
              }
              emitCurrent(effectiveAuth.currentUser);
            },
            onError: (_) {},
          );
        }
      });
    },
    onCancel: () async {
      await permSub?.cancel();
      await authSub?.cancel();
    },
  );

  return controller.stream;
}
