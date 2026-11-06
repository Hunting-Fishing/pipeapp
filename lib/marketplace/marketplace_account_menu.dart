import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_admin_access.dart';
import 'marketplace_navigation.dart';

class MarketplaceAccountMenuButton extends StatefulWidget {
  const MarketplaceAccountMenuButton({
    super.key,
    required this.extended,
    required this.onAccount,
    required this.onTrust,
    required this.onMemberships,
    required this.onSupport,
    this.onAdminSettings,
    this.onScopedStaffAdmin,
    this.onAffiliateLinks,
    required this.onSignOut,
    this.signedInOverride,
    this.displayNameOverride,
    this.emailOverride,
    this.adminAccessOverride,
    this.staffPermissionsOverride,
  });

  final bool extended;
  final VoidCallback onAccount;
  final VoidCallback onTrust;
  final VoidCallback onMemberships;
  final VoidCallback onSupport;
  final VoidCallback? onAdminSettings;
  final VoidCallback? onScopedStaffAdmin;
  final VoidCallback? onAffiliateLinks;
  final VoidCallback onSignOut;
  final bool? signedInOverride;
  final String? displayNameOverride;
  final String? emailOverride;
  final Future<bool> Function({bool forceRefresh})? adminAccessOverride;
  final MarketplaceStaffPermissionsState? staffPermissionsOverride;

  @override
  State<MarketplaceAccountMenuButton> createState() =>
      _MarketplaceAccountMenuButtonState();
}

class _MarketplaceAccountMenuButtonState
    extends State<MarketplaceAccountMenuButton> {
  StreamSubscription<User?>? _tokenSubscription;
  StreamSubscription<MarketplaceStaffPermissionsState>? _staffSubscription;
  bool _isAdmin = false;
  MarketplaceStaffPermissionsState _staffState =
      const MarketplaceStaffPermissionsState.none();

  @override
  void initState() {
    super.initState();
    marketplaceAdminViewAsUserMode.addListener(_onViewModeChanged);
    if (widget.staffPermissionsOverride != null) {
      _staffState = widget.staffPermissionsOverride!;
    }
    if (widget.adminAccessOverride == null && widget.signedInOverride == null) {
      _tokenSubscription =
          FirebaseAuth.instance.idTokenChanges().listen((_) => _refreshAdmin());
      if (widget.staffPermissionsOverride == null) {
        _staffSubscription = watchMarketplaceStaffPermissions().listen((next) {
          if (!mounted) return;
          setState(() {
            _staffState = next;
            if (next.isFullAdmin != _isAdmin) {
              _isAdmin = next.isFullAdmin;
            }
          });
        });
      }
    }
    _refreshAdmin(forceRefresh: true);
  }

  @override
  void didUpdateWidget(covariant MarketplaceAccountMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.staffPermissionsOverride != oldWidget.staffPermissionsOverride &&
        widget.staffPermissionsOverride != null) {
      setState(() => _staffState = widget.staffPermissionsOverride!);
    }
  }

  @override
  void dispose() {
    marketplaceAdminViewAsUserMode.removeListener(_onViewModeChanged);
    _tokenSubscription?.cancel();
    _staffSubscription?.cancel();
    super.dispose();
  }

  void _onViewModeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshAdmin({bool forceRefresh = false}) async {
    final authorized = widget.adminAccessOverride != null
        ? await widget.adminAccessOverride!(forceRefresh: forceRefresh)
        : await marketplaceAdministratorAccess(forceRefresh: forceRefresh);
    MarketplaceStaffPermissionsState? resolvedStaff;
    if (widget.staffPermissionsOverride != null) {
      resolvedStaff = widget.staffPermissionsOverride!;
    } else if (widget.adminAccessOverride == null &&
        widget.signedInOverride == null) {
      resolvedStaff =
          await resolveMarketplaceStaffPermissions(forceRefresh: forceRefresh);
    }
    if (!mounted) return;
    setState(() {
      _isAdmin = authorized || (resolvedStaff?.isFullAdmin ?? false);
      if (resolvedStaff != null) {
        _staffState = resolvedStaff;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool signedIn;
    final String rawName;
    final String email;
    if (widget.signedInOverride != null) {
      signedIn = widget.signedInOverride!;
      email = widget.emailOverride ?? '';
      final overrideName = widget.displayNameOverride?.trim() ?? '';
      rawName = overrideName.isNotEmpty
          ? overrideName
          : (email.isNotEmpty ? email.split('@').first : 'Account');
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return const SizedBox.shrink();
      signedIn = true;
      email = widget.emailOverride ?? user.email ?? '';
      final display = (widget.displayNameOverride ?? user.displayName)?.trim();
      rawName = (display != null && display.isNotEmpty)
          ? display
          : (email.isNotEmpty ? email.split('@').first : 'Account');
    }
    if (!signedIn) return const SizedBox.shrink();

    final name = rawName;
    final initial = name.isEmpty ? 'P' : name.substring(0, 1).toUpperCase();
    final hasAnyStaffOrAdmin = _isAdmin || _staffState.hasScopedStaffAccess;
    final isViewingAsRegularUser =
        hasAnyStaffOrAdmin && marketplaceAdminViewAsUserMode.value;
    final showAdminChrome = _isAdmin && !isViewingAsRegularUser;
    final showScopedStaffChrome = !_isAdmin &&
        _staffState.hasScopedStaffAccess &&
        !isViewingAsRegularUser;

    final footerSub = showAdminChrome
        ? 'Administrator • Full access'
        : showScopedStaffChrome
            ? _staffState.footerSubtitle
            : 'Account & membership';

    return PopupMenuButton<_AccountMenuAction>(
      tooltip: 'Open account menu',
      position: PopupMenuPosition.over,
      onSelected: (action) {
        switch (action) {
          case _AccountMenuAction.account:
            widget.onAccount();
            return;
          case _AccountMenuAction.trust:
            widget.onTrust();
            return;
          case _AccountMenuAction.memberships:
            widget.onMemberships();
            return;
          case _AccountMenuAction.support:
            widget.onSupport();
            return;
          case _AccountMenuAction.adminSettings:
            setMarketplaceAdminViewAsUserMode(false);
            widget.onAdminSettings?.call();
            return;
          case _AccountMenuAction.scopedStaffAdmin:
            setMarketplaceAdminViewAsUserMode(false);
            if (widget.onScopedStaffAdmin != null) {
              widget.onScopedStaffAdmin!();
            } else {
              MarketplaceNavigation.openScopedStaffAdmin(context);
            }
            return;
          case _AccountMenuAction.affiliateLinks:
            setMarketplaceAdminViewAsUserMode(false);
            if (widget.onAffiliateLinks != null) {
              widget.onAffiliateLinks!();
            } else {
              MarketplaceNavigation.openShopAdmin(context, initialTabIndex: 1);
            }
            return;
          case _AccountMenuAction.toggleViewAsRegularUser:
            final enterUserView = !marketplaceAdminViewAsUserMode.value;
            setMarketplaceAdminViewAsUserMode(enterUserView);
            PipeFeedback.show(
              context,
              message: enterUserView
                  ? 'Viewing what everyone else sees. Open your account menu anytime to switch back.'
                  : 'Workspace view restored.',
              tone: PipeStatusTone.info,
            );
            return;
          case _AccountMenuAction.signOut:
            widget.onSignOut();
            return;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AccountMenuAction>(
          enabled: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 270),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: PipeBuyerColors.orangeSoft,
                  foregroundColor: PipeBuyerColors.orangePressed,
                  child: Text(
                    initial,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (showAdminChrome) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: Colors.purple.shade800,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ] else if (showScopedStaffChrome &&
                              _staffState.roleBadgeLabel.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEDD5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _staffState.roleBadgeLabel,
                                style: const TextStyle(
                                  color: Color(0xFF9A3412),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PipeBuyerColors.muted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _AccountMenuAction.account,
          child: _MenuRow(
            icon: Icons.person_outline_rounded,
            title: 'Profile & account',
            subtitle: 'Listings, activity and settings',
          ),
        ),
        const PopupMenuItem(
          value: _AccountMenuAction.trust,
          child: _MenuRow(
            icon: Icons.verified_user_outlined,
            title: 'Verification & security',
            subtitle: 'Email, mobile and sign-in protection',
          ),
        ),
        const PopupMenuItem(
          value: _AccountMenuAction.memberships,
          child: _MenuRow(
            icon: Icons.workspace_premium_outlined,
            title: 'Memberships & upgrades',
            subtitle: 'VIP and Dispatch memberships',
            accent: PipeBuyerColors.orangePressed,
          ),
        ),
        const PopupMenuItem(
          value: _AccountMenuAction.support,
          child: _MenuRow(
            icon: Icons.support_agent_outlined,
            title: 'Support',
            subtitle: 'Help, safety and account assistance',
          ),
        ),
        if (showAdminChrome) ...[
          const PopupMenuDivider(),
          if (widget.onAdminSettings != null)
            PopupMenuItem(
              value: _AccountMenuAction.adminSettings,
              child: _MenuRow(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin settings',
                subtitle:
                    'All admin portals, directory, insurance, eXp Realty & roles',
                accent: Colors.purple.shade800,
              ),
            ),
          if (widget.onAffiliateLinks != null)
            const PopupMenuItem(
              value: _AccountMenuAction.affiliateLinks,
              child: _MenuRow(
                icon: Icons.add_link_rounded,
                title: 'Add / Manage Affiliate Links',
                subtitle:
                    'Amazon, AliExpress, Lazada, Shopee & 25+ passive-income platforms',
                accent: Color(0xFF9A3412),
              ),
            ),
          const PopupMenuItem(
            value: _AccountMenuAction.toggleViewAsRegularUser,
            child: _MenuRow(
              icon: Icons.visibility_outlined,
              title: 'View what everyone else sees',
              subtitle: 'Preview regular customer mode (hides admin UI)',
            ),
          ),
        ] else if (showScopedStaffChrome) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: _AccountMenuAction.scopedStaffAdmin,
            child: _MenuRow(
              icon: Icons.dashboard_customize_outlined,
              title: 'Admin workspace (My roles)',
              subtitle:
                  'Restricted to only the permissions assigned to your account',
              accent: Color(0xFF9A3412),
            ),
          ),
          if (_staffState.hasShopAccess)
            const PopupMenuItem(
              value: _AccountMenuAction.affiliateLinks,
              child: _MenuRow(
                icon: Icons.add_link_rounded,
                title: 'Add / Manage Affiliate Links',
                subtitle:
                    'Amazon, AliExpress, Lazada, Shopee & 25+ affiliate platforms',
                accent: PipeBuyerColors.orangePressed,
              ),
            ),
          const PopupMenuItem(
            value: _AccountMenuAction.toggleViewAsRegularUser,
            child: _MenuRow(
              icon: Icons.visibility_outlined,
              title: 'View what everyone else sees',
              subtitle: 'Preview regular customer mode (hides staff tools)',
            ),
          ),
        ] else if (isViewingAsRegularUser) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _AccountMenuAction.toggleViewAsRegularUser,
            child: _MenuRow(
              icon: Icons.admin_panel_settings_outlined,
              title: _isAdmin
                  ? 'Switch back to Admin view'
                  : 'Switch back to Staff workspace',
              subtitle: 'Currently viewing what everyone else sees',
              accent: Colors.purple.shade800,
            ),
          ),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _AccountMenuAction.signOut,
          child: _MenuRow(
            icon: Icons.logout_rounded,
            title: 'Sign out',
            subtitle: 'End this Pipe Buyer session',
            accent: PipeBuyerColors.danger,
          ),
        ),
      ],
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        padding: EdgeInsets.symmetric(
          horizontal: widget.extended ? 11 : 7,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: PipeBuyerColors.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCE3EB)),
        ),
        child: widget.extended
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: PipeBuyerColors.orangeSoft,
                    foregroundColor: PipeBuyerColors.orangePressed,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          footerSub,
                          style: TextStyle(
                            color: showAdminChrome
                                ? Colors.purple.shade700
                                : showScopedStaffChrome
                                    ? const Color(0xFF9A3412)
                                    : PipeBuyerColors.muted,
                            fontSize: 10,
                            fontWeight:
                                (showAdminChrome || showScopedStaffChrome)
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_less_rounded, size: 19),
                ],
              )
            : CircleAvatar(
                radius: 17,
                backgroundColor: PipeBuyerColors.orangeSoft,
                foregroundColor: PipeBuyerColors.orangePressed,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
      ),
    );
  }
}

enum _AccountMenuAction {
  account,
  trust,
  memberships,
  support,
  adminSettings,
  scopedStaffAdmin,
  affiliateLinks,
  toggleViewAsRegularUser,
  signOut,
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
