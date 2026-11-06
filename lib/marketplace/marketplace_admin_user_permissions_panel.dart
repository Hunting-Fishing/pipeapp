import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_navigation.dart';

class AdminManagedUserRecord {
  const AdminManagedUserRecord({
    required this.uid,
    required this.email,
    required this.displayName,
    this.emailVerified = false,
    this.loginDisabled = false,
    this.restricted = false,
    this.restrictions = const <String>[],
    this.restrictionReason = '',
    this.providers = const <String>[],
    this.hasFederatedProvider = false,
    this.mfaEnrolled = false,
    this.isPrimaryAdmin = false,
    this.isAdmin = false,
    this.canGrantPermissions = false,
    this.accountType = 'personal',
    this.accountVerified = false,
    this.shopRole = 'none',
    this.allowedAffiliatePlatforms = const <String>[],
    this.yellowPagesRole = 'none',
    this.permissions = const <String, bool>{},
    this.createdAt = '',
    this.lastSignInAt = '',
  });

  final String uid;
  final String email;
  final String displayName;
  final bool emailVerified;
  final bool loginDisabled;
  final bool restricted;
  final List<String> restrictions;
  final String restrictionReason;
  final List<String> providers;
  final bool hasFederatedProvider;
  final bool mfaEnrolled;
  final bool isPrimaryAdmin;
  final bool isAdmin;
  final bool canGrantPermissions;
  final String accountType;
  final bool accountVerified;
  final String shopRole;
  final List<String> allowedAffiliatePlatforms;
  final String yellowPagesRole;
  final Map<String, bool> permissions;
  final String createdAt;
  final String lastSignInAt;

  bool get hasStoreAccess =>
      isAdmin ||
      shopRole == 'store_manager' ||
      shopRole == 'catalog_editor' ||
      shopRole == 'affiliate_contributor' ||
      permissions['addAffiliateProducts'] == true;

  bool get hasAnyRestriction =>
      restricted || loginDisabled || restrictions.isNotEmpty;

  bool get isGoogleSignIn => providers.contains('google.com');

  String get titleLabel {
    if (displayName.trim().isNotEmpty && email.trim().isNotEmpty) {
      return '${displayName.trim()} (${email.trim()})';
    }
    if (email.trim().isNotEmpty) return email.trim();
    if (displayName.trim().isNotEmpty) return displayName.trim();
    return uid;
  }

  factory AdminManagedUserRecord.fromJson(Map<String, dynamic> json) {
    List<String> strList(Object? raw) {
      if (raw is! Iterable) return const <String>[];
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    final rawPerms = json['permissions'];
    final perms = <String, bool>{};
    if (rawPerms is Map) {
      for (final entry in rawPerms.entries) {
        perms[entry.key.toString()] = entry.value == true;
      }
    }

    return AdminManagedUserRecord(
      uid: json['uid']?.toString().trim() ?? '',
      email: json['email']?.toString().trim() ?? '',
      displayName: json['displayName']?.toString().trim() ??
          json['display_name']?.toString().trim() ??
          '',
      emailVerified: json['emailVerified'] == true ||
          json['emailOwnershipVerified'] == true,
      loginDisabled: json['loginDisabled'] == true,
      restricted: json['restricted'] == true,
      restrictions: strList(json['restrictions']),
      restrictionReason: json['restrictionReason']?.toString().trim() ?? '',
      providers: strList(json['providers']),
      hasFederatedProvider: json['hasFederatedProvider'] == true ||
          strList(json['providers']).contains('google.com'),
      mfaEnrolled: json['mfaEnrolled'] == true,
      isPrimaryAdmin: json['isPrimaryAdmin'] == true,
      isAdmin: json['isAdmin'] == true || json['role'] == 'administrator',
      canGrantPermissions: json['canGrantPermissions'] == true ||
          json['isPrimaryAdmin'] == true ||
          perms['canGrantPermissions'] == true,
      accountType: json['accountType']?.toString().trim().isNotEmpty == true
          ? json['accountType'].toString().trim()
          : 'personal',
      accountVerified: json['accountVerified'] == true,
      shopRole: json['shopRole']?.toString().trim().isNotEmpty == true
          ? json['shopRole'].toString().trim()
          : 'none',
      allowedAffiliatePlatforms: strList(json['allowedAffiliatePlatforms']),
      yellowPagesRole:
          json['yellowPagesRole']?.toString().trim().isNotEmpty == true
              ? json['yellowPagesRole'].toString().trim()
              : 'none',
      permissions: perms,
      createdAt: json['createdAt']?.toString() ?? '',
      lastSignInAt: json['lastSignInAt']?.toString() ?? '',
    );
  }
}

abstract class AdminPermissionsRepository {
  Future<List<AdminManagedUserRecord>> listUsers({String query = ''});
  Future<AdminManagedUserRecord> updatePermissions(
      Map<String, Object?> payload);
}

class CloudFunctionsAdminPermissionsRepository
    implements AdminPermissionsRepository {
  CloudFunctionsAdminPermissionsRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  })  : _functions = functions,
        _firestore = firestore;

  FirebaseFunctions? _functions;
  FirebaseFirestore? _firestore;

  FirebaseFunctions get _resolvedFunctions =>
      _functions ??= FirebaseFunctions.instance;

  FirebaseFirestore get _resolvedFirestore =>
      _firestore ??= FirebaseFirestore.instance;

  @override
  Future<List<AdminManagedUserRecord>> listUsers({String query = ''}) async {
    try {
      final response = await _resolvedFunctions
          .httpsCallable(
        'listAdminUsersAndPermissions',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      )
          .call(<String, Object?>{
        'query': query.trim(),
        'limit': 350,
      });
      final data = response.data;
      if (data is Map && data['users'] is List) {
        return (data['users'] as List)
            .whereType<Map>()
            .map((e) =>
                AdminManagedUserRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      }
    } catch (_) {
      // Fallback to Firestore users collection if callable is temporarily unreachable
      if (Firebase.apps.isNotEmpty) {
        final snap =
            await _resolvedFirestore.collection('users').limit(200).get();
        return snap.docs
            .map(
              (doc) => AdminManagedUserRecord.fromJson(<String, dynamic>{
                'uid': doc.id,
                ...doc.data(),
              }),
            )
            .toList(growable: false);
      }
      rethrow;
    }
    return const <AdminManagedUserRecord>[];
  }

  @override
  Future<AdminManagedUserRecord> updatePermissions(
    Map<String, Object?> payload,
  ) async {
    try {
      final response = await _resolvedFunctions
          .httpsCallable(
            'updateAdminUserPermissions',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 30),
            ),
          )
          .call(payload);
      final data = response.data;
      if (data is Map && data['user'] is Map) {
        return AdminManagedUserRecord.fromJson(
          Map<String, dynamic>.from(data['user'] as Map),
        );
      }
      throw StateError('Permission update completed without a user record.');
    } on FirebaseFunctionsException catch (error) {
      final msg = error.message?.trim();
      throw StateError(
        (msg != null && msg.isNotEmpty)
            ? msg
            : 'Unable to update user permissions (${error.code}).',
      );
    }
  }
}

class MarketplaceAdminUserPermissionsPanel extends StatefulWidget {
  const MarketplaceAdminUserPermissionsPanel({
    super.key,
    this.repository,
  });

  final AdminPermissionsRepository? repository;

  @override
  State<MarketplaceAdminUserPermissionsPanel> createState() =>
      _MarketplaceAdminUserPermissionsPanelState();
}

class _MarketplaceAdminUserPermissionsPanelState
    extends State<MarketplaceAdminUserPermissionsPanel> {
  late AdminPermissionsRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  List<AdminManagedUserRecord> _users = const <AdminManagedUserRecord>[];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  String? _busyUid;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? CloudFunctionsAdminPermissionsRepository();
    _loadUsers();
  }

  @override
  void didUpdateWidget(
    covariant MarketplaceAdminUserPermissionsPanel oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository &&
        widget.repository != null) {
      _repository = widget.repository!;
      _loadUsers();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loaded = await _repository.listUsers();
      if (!mounted) return;
      setState(() {
        _users = loaded;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  List<AdminManagedUserRecord> get _filteredUsers {
    final q = _searchQuery.trim().toLowerCase();
    return _users.where((u) {
      if (_selectedFilter == 'google' && !u.hasFederatedProvider) {
        return false;
      }
      if (_selectedFilter == 'affiliate' && !u.hasStoreAccess) {
        return false;
      }
      if (_selectedFilter == 'admins' && !u.isAdmin) {
        return false;
      }
      if (_selectedFilter == 'restricted' && !u.hasAnyRestriction) {
        return false;
      }
      if (q.isEmpty) return true;
      final hay = [
        u.email,
        u.displayName,
        u.uid,
        u.shopRole,
        u.accountType,
        ...u.providers,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList(growable: false);
  }

  Future<void> _quickGrantAffiliateAccess(AdminManagedUserRecord user) async {
    setState(() => _busyUid = user.uid);
    try {
      await _repository.updatePermissions(<String, Object?>{
        'targetUid': user.uid,
        'email': user.email,
        'shopRole': 'catalog_editor',
        'allowedAffiliatePlatforms': const <String>['all'],
        'permissions': <String, bool>{
          ...user.permissions,
          'addAffiliateProducts': true,
          'bulkImportCatalog': true,
        },
      });
      if (!mounted) return;
      setState(() => _busyUid = null);
      PipeFeedback.show(
        context,
        message:
            'Granted Amazon, AliExpress, Lazada, Shopee & global affiliate product permissions to ${user.email.isNotEmpty ? user.email : user.uid}.',
        tone: PipeStatusTone.success,
      );
      await _loadUsers();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyUid = null);
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  Future<void> _quickToggleRestriction(AdminManagedUserRecord user) async {
    if (user.isPrimaryAdmin) return;
    final lifting = user.hasAnyRestriction;
    String reason = '';
    if (!lifting) {
      final controller = TextEditingController(
        text: 'Restricted by Administrator via Admin Pane',
      );
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Restrict ${user.titleLabel}?'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Restricting this user immediately blocks Store uploads, new Marketplace listings, offers/messages, and freight dispatch actions. You can also suspend login or set granular blocks inside "Manage Permissions".',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Restriction Reason',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: PipeBuyerColors.danger,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text('Restrict User'),
                ),
              ],
            ),
          ) ??
          false;
      reason = controller.text.trim();
      controller.dispose();
      if (!confirmed || !mounted) return;
    }

    setState(() => _busyUid = user.uid);
    try {
      await _repository.updatePermissions(<String, Object?>{
        'targetUid': user.uid,
        'email': user.email,
        'restricted': !lifting,
        if (lifting) 'loginDisabled': false,
        'restrictions': lifting
            ? const <String>[]
            : const <String>[
                'restrict_store_products',
                'restrict_marketplace_selling',
                'restrict_messaging_offers',
                'restrict_dispatch',
              ],
        'restrictionReason': lifting ? '' : reason,
      });
      if (!mounted) return;
      setState(() => _busyUid = null);
      PipeFeedback.show(
        context,
        message: lifting
            ? 'Restrictions lifted for ${user.titleLabel}.'
            : 'User ${user.titleLabel} is now restricted.',
        tone: lifting ? PipeStatusTone.success : PipeStatusTone.warning,
      );
      await _loadUsers();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyUid = null);
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  Future<void> _openPermissionsDialog(
      {AdminManagedUserRecord? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AdminUserPermissionsDialog(
        repository: _repository,
        existingUser: existing,
        availableUsers: _users,
      ),
    );
    if (saved == true && mounted) {
      await _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filteredUsers;
    final googleCount = _users.where((u) => u.hasFederatedProvider).length;
    final affiliateCount = _users.where((u) => u.hasStoreAccess).length;
    final adminCount = _users.where((u) => u.isAdmin).length;
    final restrictedCount = _users.where((u) => u.hasAnyRestriction).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Wrap(
            spacing: 14,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin User Permissions, Affiliate Access & User Restrictions',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.purple.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Shows every live Firebase Auth & Google Sign-in user immediately on signup. Grant permissions to add affiliate products (Amazon, AliExpress, Lazada, Shopee, Involve Asia, eBay, VEVOR, etc.), promote administrators, or restrict/suspend accounts.',
                      style: TextStyle(fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.purple.shade800,
                    ),
                    onPressed: () => _openPermissionsDialog(),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Grant Permissions by Email'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        MarketplaceNavigation.openShopAdmin(context),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: const Text('Affiliate Platforms & Store'),
                  ),
                  IconButton(
                    tooltip: 'Refresh Users & Permissions',
                    onPressed: _loading ? null : _loadUsers,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MiniStatChip(
              label: 'All Accounts',
              count: _users.length,
              color: PipeBuyerColors.industrialBlue,
            ),
            _MiniStatChip(
              label: 'Google / Federated Sign-In',
              count: googleCount,
              color: const Color(0xFF0F766E),
            ),
            _MiniStatChip(
              label: 'Store & Affiliate Access',
              count: affiliateCount,
              color: PipeBuyerColors.orangePressed,
            ),
            _MiniStatChip(
              label: 'Administrators',
              count: adminCount,
              color: Colors.purple.shade700,
            ),
            _MiniStatChip(
              label: 'Restricted / Suspended',
              count: restrictedCount,
              color: PipeBuyerColors.danger,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText:
                'Search users by email, Google Sign-in name, UID, or role…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: const Icon(Icons.clear_rounded),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterPill(
              label: 'All Users (${_users.length})',
              selected: _selectedFilter == 'all',
              onTap: () => setState(() => _selectedFilter = 'all'),
            ),
            _FilterPill(
              label: 'Google Sign-In ($googleCount)',
              selected: _selectedFilter == 'google',
              onTap: () => setState(() => _selectedFilter = 'google'),
            ),
            _FilterPill(
              label: 'Store & Affiliate Contributors ($affiliateCount)',
              selected: _selectedFilter == 'affiliate',
              onTap: () => setState(() => _selectedFilter = 'affiliate'),
            ),
            _FilterPill(
              label: 'Administrators ($adminCount)',
              selected: _selectedFilter == 'admins',
              onTap: () => setState(() => _selectedFilter = 'admins'),
            ),
            _FilterPill(
              label: 'Restricted / Suspended ($restrictedCount)',
              selected: _selectedFilter == 'restricted',
              onTap: () => setState(() => _selectedFilter = 'restricted'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: PipeBuyerColors.danger),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _loadUsers,
                    child: const Text('Retry Loading Users'),
                  ),
                ],
              ),
            ),
          )
        else if (visible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No matching accounts found. Use "Grant Permissions by Email" above to provision an email directly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PipeBuyerColors.muted),
              ),
            ),
          )
        else
          ...visible.map((user) {
            final isBusy = _busyUid == user.uid;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: user.hasAnyRestriction
                      ? PipeBuyerColors.danger.withValues(alpha: .45)
                      : user.isAdmin
                          ? Colors.purple.shade200
                          : PipeBuyerColors.line,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: user.hasAnyRestriction
                                  ? PipeBuyerColors.danger
                                      .withValues(alpha: .15)
                                  : user.isAdmin
                                      ? Colors.purple.shade100
                                      : user.hasStoreAccess
                                          ? const Color(0xFFFFEDD5)
                                          : Colors.blue.shade50,
                              child: Icon(
                                user.hasAnyRestriction
                                    ? Icons.block_rounded
                                    : user.isAdmin
                                        ? Icons.admin_panel_settings
                                        : user.hasStoreAccess
                                            ? Icons.shopping_bag_outlined
                                            : Icons.person_outline,
                                size: 19,
                                color: user.hasAnyRestriction
                                    ? PipeBuyerColors.danger
                                    : user.isAdmin
                                        ? Colors.purple.shade800
                                        : PipeBuyerColors.ink,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.titleLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  Text(
                                    'UID: ${user.uid} • Account: ${user.accountType.toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: PipeBuyerColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (user.isPrimaryAdmin)
                              _RoleBadge(
                                label: 'PRIMARY ADMIN',
                                bg: Colors.purple.shade900,
                                fg: Colors.white,
                              )
                            else if (user.isAdmin)
                              _RoleBadge(
                                label: 'ADMINISTRATOR',
                                bg: Colors.purple.shade100,
                                fg: Colors.purple.shade900,
                              ),
                            if (user.canGrantPermissions &&
                                !user.isPrimaryAdmin)
                              _RoleBadge(
                                label: 'CAN GRANT PERMISSIONS',
                                bg: Colors.indigo.shade50,
                                fg: Colors.indigo.shade900,
                              ),
                            if (user.isGoogleSignIn)
                              const _RoleBadge(
                                label: 'GOOGLE SIGN-IN',
                                bg: Color(0xFFE0F2FE),
                                fg: Color(0xFF0369A1),
                              ),
                            if (user.hasStoreAccess) ...[
                              if (!user.isAdmin)
                                _RoleBadge(
                                  label:
                                      'STORE: ${user.shopRole.toUpperCase()}',
                                  bg: const Color(0xFFFFEDD5),
                                  fg: const Color(0xFF9A3412),
                                ),
                              _RoleBadge(
                                label: (user.isAdmin ||
                                        user.allowedAffiliatePlatforms
                                            .isEmpty ||
                                        user.allowedAffiliatePlatforms
                                            .contains('all'))
                                    ? 'ALL AFFILIATE PLATFORMS'
                                    : '${user.allowedAffiliatePlatforms.length} AFFILIATE PLATFORMS',
                                bg: const Color(0xFFFFEDD5),
                                fg: const Color(0xFF9A3412),
                              ),
                            ],
                            if (user.accountVerified)
                              const _RoleBadge(
                                label: 'VERIFIED SELLER',
                                bg: Color(0xFFDCFCE7),
                                fg: Color(0xFF166534),
                              ),
                            if (user.loginDisabled)
                              const _RoleBadge(
                                label: 'LOGIN SUSPENDED',
                                bg: Color(0xFFFEE2E2),
                                fg: Color(0xFF991B1B),
                              ),
                            if (user.restricted || user.restrictions.isNotEmpty)
                              const _RoleBadge(
                                label: 'RESTRICTED',
                                bg: Color(0xFFFEE2E2),
                                fg: Color(0xFF991B1B),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (user.restrictionReason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Restriction Note: ${user.restrictionReason}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: PipeBuyerColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: isBusy
                              ? null
                              : () => _openPermissionsDialog(existing: user),
                          icon: const Icon(Icons.tune_rounded, size: 17),
                          label: const Text('Permissions & Restrictions'),
                        ),
                        if (!user.hasStoreAccess && !user.hasAnyRestriction)
                          OutlinedButton.icon(
                            onPressed: isBusy
                                ? null
                                : () => _quickGrantAffiliateAccess(user),
                            icon: const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 17,
                            ),
                            label: const Text(
                              'Grant Amazon / Affiliate Access',
                            ),
                          ),
                        if (!user.isPrimaryAdmin)
                          TextButton.icon(
                            onPressed: isBusy
                                ? null
                                : () => _quickToggleRestriction(user),
                            style: TextButton.styleFrom(
                              foregroundColor: user.hasAnyRestriction
                                  ? PipeBuyerColors.success
                                  : PipeBuyerColors.danger,
                            ),
                            icon: Icon(
                              user.hasAnyRestriction
                                  ? Icons.lock_open_rounded
                                  : Icons.block_rounded,
                              size: 17,
                            ),
                            label: Text(
                              user.hasAnyRestriction
                                  ? 'Unrestrict User'
                                  : 'Restrict User',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class AdminUserPermissionsDialog extends StatefulWidget {
  const AdminUserPermissionsDialog({
    super.key,
    required this.repository,
    this.existingUser,
    this.availableUsers = const <AdminManagedUserRecord>[],
  });

  final AdminPermissionsRepository repository;
  final AdminManagedUserRecord? existingUser;
  final List<AdminManagedUserRecord> availableUsers;

  @override
  State<AdminUserPermissionsDialog> createState() =>
      _AdminUserPermissionsDialogState();
}

class _AdminUserPermissionsDialogState
    extends State<AdminUserPermissionsDialog> {
  static const List<(String, String)> _platformOptions = <(String, String)>[
    ('amazon_affiliate', 'Amazon Associates (US/CA/Global)'),
    ('aliexpress_affiliate', 'AliExpress Portals'),
    ('shopee_affiliate', 'Shopee Affiliate'),
    ('lazada_affiliate', 'Lazada LazAffiliate'),
    ('affiliate_network', 'Involve Asia / Impact / CJ / ShareASale'),
    ('ebay_partner', 'eBay Partner Network'),
    ('walmart_affiliate', 'Walmart Affiliate'),
    ('temu_affiliate', 'Temu Affiliate'),
    ('tiktok_shop_affiliate', 'TikTok Shop Affiliate'),
    ('alibaba_b2b', 'Alibaba & DHgate B2B'),
    ('hardware_pro_retail', 'VEVOR / Home Depot / Acme / Zoro'),
    ('brand_partner', 'Direct Brand Partners'),
    ('distributor_affiliate', 'Authorized Distributors'),
  ];

  static const List<(String, String)> _restrictionOptions = <(String, String)>[
    ('restrict_store_products', 'Block Store & Affiliate Product Uploads'),
    ('restrict_marketplace_selling', 'Block Marketplace Listings & Auctions'),
    ('restrict_messaging_offers', 'Block Messaging & Buyer/Seller Offers'),
    ('restrict_dispatch', 'Block Freight & Hotshot Dispatch'),
  ];

  late final TextEditingController _emailController;
  late final TextEditingController _reasonController;
  AdminManagedUserRecord? _selectedCandidate;
  bool _showUserPickerList = false;

  late String _shopRole;
  late bool _allAffiliatePlatforms;
  late Set<String> _selectedPlatforms;
  late String _accountType;
  late String _yellowPagesRole;
  late bool _verifiedSeller;
  late bool _canGrantPermissions;
  late bool _grantAdmin;
  late bool _restricted;
  late bool _loginDisabled;
  late Set<String> _selectedRestrictions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.existingUser;
    _selectedCandidate = u;
    _emailController = TextEditingController(text: u?.email ?? '');
    _reasonController = TextEditingController(text: u?.restrictionReason ?? '');
    _shopRole = u?.shopRole ?? 'catalog_editor';
    final existingPlatforms =
        u?.allowedAffiliatePlatforms ?? const <String>['all'];
    _allAffiliatePlatforms =
        existingPlatforms.isEmpty || existingPlatforms.contains('all');
    _selectedPlatforms = _allAffiliatePlatforms
        ? _platformOptions.map((e) => e.$1).toSet()
        : existingPlatforms.toSet();
    _accountType = u?.accountType ?? 'personal';
    _yellowPagesRole = u?.yellowPagesRole ?? 'none';
    _verifiedSeller = u?.accountVerified ?? false;
    _canGrantPermissions = u?.canGrantPermissions ?? false;
    _grantAdmin = u?.isAdmin ?? false;
    _restricted = u?.restricted ?? false;
    _loginDisabled = u?.loginDisabled ?? false;
    _selectedRestrictions = (u?.restrictions ?? const <String>[]).toSet();
  }

  void _applySelectedUser(AdminManagedUserRecord candidate) {
    final existingPlatforms = candidate.allowedAffiliatePlatforms;
    final allPlats =
        existingPlatforms.isEmpty || existingPlatforms.contains('all');
    setState(() {
      _selectedCandidate = candidate;
      _showUserPickerList = false;
      _emailController.text = candidate.email;
      _emailController.selection = TextSelection.collapsed(
        offset: candidate.email.length,
      );
      _reasonController.text = candidate.restrictionReason;
      _shopRole =
          candidate.shopRole == 'none' ? 'catalog_editor' : candidate.shopRole;
      _allAffiliatePlatforms = allPlats;
      _selectedPlatforms = allPlats
          ? _platformOptions.map((e) => e.$1).toSet()
          : existingPlatforms.toSet();
      _accountType = candidate.accountType;
      _yellowPagesRole = candidate.yellowPagesRole;
      _verifiedSeller = candidate.accountVerified;
      _canGrantPermissions = candidate.canGrantPermissions;
      _grantAdmin = candidate.isAdmin;
      _restricted = candidate.restricted;
      _loginDisabled = candidate.loginDisabled;
      _selectedRestrictions = candidate.restrictions.toSet();
    });
  }

  void _onEmailTyped(String raw) {
    final trimmed = raw.trim().toLowerCase();
    AdminManagedUserRecord? exactMatch;
    if (trimmed.isNotEmpty) {
      for (final item in widget.availableUsers) {
        if (item.email.trim().toLowerCase() == trimmed) {
          exactMatch = item;
          break;
        }
      }
    }
    setState(() {
      _selectedCandidate = exactMatch;
      _showUserPickerList = trimmed.isNotEmpty && exactMatch == null;
    });
  }

  List<AdminManagedUserRecord> _predictiveCandidates() {
    final users = widget.availableUsers
        .where(
            (u) => u.email.trim().isNotEmpty || u.displayName.trim().isNotEmpty)
        .toList();
    final q = _emailController.text.trim().toLowerCase();
    if (q.isEmpty) {
      return users.take(12).toList(growable: false);
    }

    int score(AdminManagedUserRecord u) {
      final email = u.email.trim().toLowerCase();
      final name = u.displayName.trim().toLowerCase();
      if (email == q) return 0;
      if (email.startsWith(q)) return 1;
      if (name.startsWith(q)) return 2;
      if (email.contains(q)) return 3;
      if (name.contains(q)) return 4;
      if (u.uid.toLowerCase().contains(q)) return 5;
      return 99;
    }

    final matched = users.where((u) => score(u) < 99).toList();
    matched.sort((a, b) {
      final sa = score(a);
      final sb = score(b);
      if (sa != sb) return sa.compareTo(sb);
      return a.email.toLowerCase().compareTo(b.email.toLowerCase());
    });
    return matched.take(10).toList(growable: false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final existing = widget.existingUser ?? _selectedCandidate;
    final email = _emailController.text.trim().toLowerCase();
    if (existing == null && (email.isEmpty || !email.contains('@'))) {
      PipeFeedback.show(
        context,
        message: 'Select a registered user or enter a valid email address.',
        tone: PipeStatusTone.error,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final platformsPayload = _shopRole == 'none'
          ? const <String>[]
          : (_allAffiliatePlatforms
              ? const <String>['all']
              : _selectedPlatforms.toList(growable: false));

      await widget.repository.updatePermissions(<String, Object?>{
        if (existing != null) 'targetUid': existing.uid,
        if (email.isNotEmpty) 'email': email,
        'shopRole': _shopRole,
        'allowedAffiliatePlatforms': platformsPayload,
        'accountType': _accountType,
        'yellowPagesRole': _yellowPagesRole,
        'accountVerified': _verifiedSeller,
        'grantAdmin': _grantAdmin,
        'restricted': _restricted,
        'loginDisabled': _loginDisabled,
        'restrictions': _selectedRestrictions.toList(growable: false),
        'restrictionReason': _reasonController.text.trim(),
        'permissions': <String, bool>{
          'canGrantPermissions': _canGrantPermissions || _grantAdmin,
          'addAffiliateProducts': _shopRole != 'none' || _grantAdmin,
          'bulkImportCatalog': _shopRole == 'catalog_editor' ||
              _shopRole == 'store_manager' ||
              _grantAdmin,
          'reviewVendorApplications':
              _shopRole == 'store_manager' || _grantAdmin,
        },
      });
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message:
            'Updated permissions & restrictions for ${existing?.titleLabel ?? email}.',
        tone: PipeStatusTone.success,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  Widget _buildPredictiveEmailAndUserPicker() {
    final candidates = _predictiveCandidates();
    final matched = _selectedCandidate;
    final typed = _emailController.text.trim();
    final showSuggestions = _showUserPickerList && candidates.isNotEmpty;

    String resolvedUserName(AdminManagedUserRecord u) {
      final dn = u.displayName.trim();
      if (dn.isNotEmpty) return dn;
      if (u.email.contains('@')) return u.email.split('@').first;
      return 'Unnamed User';
    }

    Widget buildBesideUserNameBadge() {
      if (matched != null) {
        return Container(
          key: const Key('admin_matched_user_name_box'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 18,
                color: Color(0xFF15803D),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      resolvedUserName(matched),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: Color(0xFF14532D),
                      ),
                    ),
                    Text(
                      matched.isGoogleSignIn
                          ? 'Google Sign-in • ${matched.email}'
                          : matched.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      if (widget.availableUsers.isNotEmpty) {
        return OutlinedButton.icon(
          key: const Key('admin_select_registered_user_button'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onPressed: () =>
              setState(() => _showUserPickerList = !_showUserPickerList),
          icon: Icon(
            _showUserPickerList
                ? Icons.expand_less_rounded
                : Icons.person_search_rounded,
            size: 18,
          ),
          label: Text(
            typed.isNotEmpty && candidates.isNotEmpty
                ? '${candidates.length} Matching User(s)'
                : 'Select User (${widget.availableUsers.length})',
          ),
        );
      }

      return const SizedBox.shrink();
    }

    final emailField = TextField(
      key: const Key('admin_grant_email_input'),
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      onChanged: _onEmailTyped,
      onTap: () {
        if (widget.availableUsers.isNotEmpty && _selectedCandidate == null) {
          setState(() => _showUserPickerList = true);
        }
      },
      decoration: InputDecoration(
        labelText: 'User Account Email (Select User or Type to Auto-Fill) *',
        hintText: 'Start typing email or user name, or click Select User…',
        prefixIcon: const Icon(Icons.email_outlined),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (typed.isNotEmpty)
              IconButton(
                tooltip: 'Clear email',
                onPressed: () {
                  _emailController.clear();
                  setState(() {
                    _selectedCandidate = null;
                    _showUserPickerList = widget.availableUsers.isNotEmpty;
                  });
                },
                icon: const Icon(Icons.clear_rounded, size: 18),
              ),
            if (widget.availableUsers.isNotEmpty)
              IconButton(
                key: const Key('admin_toggle_user_picker_button'),
                tooltip: 'Select from registered users',
                onPressed: () =>
                    setState(() => _showUserPickerList = !_showUserPickerList),
                icon: Icon(
                  _showUserPickerList
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_circle_outlined,
                ),
              ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final badge = buildBesideUserNameBadge();
            if (constraints.maxWidth >= 460 &&
                (matched != null || widget.availableUsers.isNotEmpty)) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 3, child: emailField),
                  const SizedBox(width: 10),
                  Flexible(flex: 2, child: badge),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                emailField,
                if (matched != null || widget.availableUsers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  badge,
                ],
              ],
            );
          },
        ),
        if (matched != null) ...[
          const SizedBox(height: 6),
          Text(
            'Selected User: ${resolvedUserName(matched)} (${matched.email}) • UID: ${matched.uid}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF15803D),
            ),
          ),
        ],
        if (showSuggestions) ...[
          const SizedBox(height: 8),
          Container(
            key: const Key('admin_predictive_user_suggestions'),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: candidates.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                final uName = resolvedUserName(candidate);
                return InkWell(
                  key: Key('predictive_user_${candidate.uid}'),
                  onTap: () => _applySelectedUser(candidate),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.purple.shade50,
                          foregroundColor: Colors.purple.shade900,
                          child: Text(
                            uName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                candidate.email.isNotEmpty
                                    ? candidate.email
                                    : candidate.uid,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  uName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                    color: PipeBuyerColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (candidate.isGoogleSignIn)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: _RoleBadge(
                              label: 'GOOGLE',
                              bg: Color(0xFFE0F2FE),
                              fg: Color(0xFF0369A1),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ] else if (typed.isNotEmpty &&
            matched == null &&
            widget.availableUsers.isNotEmpty &&
            candidates.isEmpty) ...[
          const SizedBox(height: 6),
          const Text(
            'No matching user in current list — you can still type any registered Pipe Buyer email address.',
            style: TextStyle(fontSize: 11.5, color: PipeBuyerColors.muted),
          ),
        ],
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existingUser;
    final effectiveTarget = existing ?? _selectedCandidate;
    final isPrimary = effectiveTarget?.isPrimaryAdmin == true;

    return AlertDialog(
      title: Text(
        existing == null
            ? 'Grant User Permissions by Email'
            : 'Permissions & Restrictions — ${existing.titleLabel}',
      ),
      content: SizedBox(
        width: 660,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (existing == null) _buildPredictiveEmailAndUserPicker(),
              const Text(
                '1. Store & Multi-Platform Affiliate Product Permissions',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('shop_role_$_shopRole'),
                isExpanded: true,
                initialValue: _shopRole,
                decoration: const InputDecoration(
                  labelText: 'Store & Affiliate Role',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text('No Store Upload Access'),
                  ),
                  DropdownMenuItem(
                    value: 'affiliate_contributor',
                    child: Text(
                      'Affiliate Product Contributor (Add/Edit Affiliate Links)',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'catalog_editor',
                    child: Text(
                      'Affiliate Catalog Editor (Add/Edit/Remove + CSV Import)',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'store_manager',
                    child: Text(
                      'Store Manager (Full Catalog + Review Vendor Applications)',
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _shopRole = v);
                },
              ),
              if (_shopRole != 'none') ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Allow All Global Affiliate Platforms (Amazon, AliExpress, Lazada, Shopee, eBay, etc.)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  value: _allAffiliatePlatforms,
                  onChanged: (val) =>
                      setState(() => _allAffiliatePlatforms = val),
                ),
                if (!_allAffiliatePlatforms)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _platformOptions.map((opt) {
                      final selected = _selectedPlatforms.contains(opt.$1);
                      return FilterChip(
                        label: Text(
                          opt.$2,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        selected: selected,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _selectedPlatforms.add(opt.$1);
                            } else {
                              _selectedPlatforms.remove(opt.$1);
                            }
                          });
                        },
                      );
                    }).toList(growable: false),
                  ),
              ],
              const Divider(height: 24),
              const Text(
                '2. Platform Roles & Admin Delegation',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey<String>('acct_type_$_accountType'),
                      isExpanded: true,
                      initialValue: _accountType,
                      decoration: const InputDecoration(
                        labelText: 'Marketplace Account Type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'personal',
                          child: Text('Personal'),
                        ),
                        DropdownMenuItem(
                          value: 'business',
                          child: Text('Business'),
                        ),
                        DropdownMenuItem(
                          value: 'carrier',
                          child: Text('Hotshot Carrier'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _accountType = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey<String>('yp_role_$_yellowPagesRole'),
                      isExpanded: true,
                      initialValue: _yellowPagesRole,
                      decoration: const InputDecoration(
                        labelText: 'Oilfield Directory Role',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('None')),
                        DropdownMenuItem(
                          value: 'agent',
                          child: Text('Directory Agent'),
                        ),
                        DropdownMenuItem(
                          value: 'manager',
                          child: Text('Directory Manager'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _yellowPagesRole = v);
                      },
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Verified Marketplace Seller',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                value: _verifiedSeller,
                onChanged: (v) => setState(() => _verifiedSeller = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Can Grant User Permissions & Restrict Users',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                value: _canGrantPermissions || isPrimary,
                onChanged: isPrimary
                    ? null
                    : (v) => setState(() => _canGrantPermissions = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Full Platform Administrator Access (Admin Pane)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: const Text(
                  'Supports verified Google Sign-in accounts or MFA-enrolled accounts.',
                  style: TextStyle(fontSize: 11.5),
                ),
                value: _grantAdmin || isPrimary,
                onChanged:
                    isPrimary ? null : (v) => setState(() => _grantAdmin = v),
              ),
              if (!isPrimary) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '3. User Restrictions & Account Suspension',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: PipeBuyerColors.danger,
                        ),
                      ),
                    ),
                    if (_restricted ||
                        _loginDisabled ||
                        _selectedRestrictions.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _restricted = false;
                            _loginDisabled = false;
                            _selectedRestrictions.clear();
                            _reasonController.clear();
                          });
                        },
                        icon: const Icon(Icons.lock_open_rounded, size: 16),
                        label: const Text('Clear All Restrictions'),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Restrict Account Activity (Global Hold)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Blocks Store uploads, listings, offers, messages, and dispatch while keeping read-only access.',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  value: _restricted,
                  onChanged: (v) => setState(() => _restricted = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Suspend Sign-In (Disable Firebase Auth Login)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Immediately disables login and revokes active refresh tokens.',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  value: _loginDisabled,
                  onChanged: (v) => setState(() => _loginDisabled = v),
                ),
                const SizedBox(height: 4),
                ..._restrictionOptions.map((opt) {
                  final checked = _selectedRestrictions.contains(opt.$1);
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(opt.$2, style: const TextStyle(fontSize: 12.5)),
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedRestrictions.add(opt.$1);
                        } else {
                          _selectedRestrictions.remove(opt.$1);
                        }
                      });
                    },
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Restriction / Moderation Reason (Optional)',
                    hintText: 'Visible in Admin audit logs',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.verified_user_outlined, size: 18),
          label: Text(_saving ? 'Saving...' : 'Save User Permissions'),
        ),
      ],
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  const _MiniStatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PipeBuyerColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: PipeBuyerColors.slate,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}
