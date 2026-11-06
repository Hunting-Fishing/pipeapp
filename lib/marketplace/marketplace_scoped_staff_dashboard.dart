import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_admin_access.dart';
import 'marketplace_admin_user_permissions_panel.dart';
import 'marketplace_navigation.dart';
import 'pipebuyer_contact_center_dashboard.dart';
import 'pipebuyer_shop_admin_page.dart';
import 'pipebuyer_shop_client.dart';

/// Role-scoped Admin Workspace for non-owner staff & affiliate contributors.
///
/// Renders ONLY the modules explicitly granted to the signed-in user (such as
/// Store & Affiliate Links, Oilfield Directory Contact Center, or Delegated
/// User Permissions) and never exposes platform-wide moderation, payouts, or
/// owner settings.
class MarketplaceScopedStaffDashboard extends StatefulWidget {
  const MarketplaceScopedStaffDashboard({
    super.key,
    this.embedded = false,
    this.initialShopTabIndex = 1,
    this.permissionsOverride,
    this.shopClient,
    this.shopSessionOverride,
  });

  final bool embedded;
  final int initialShopTabIndex;
  final MarketplaceStaffPermissionsState? permissionsOverride;
  final PipeBuyerShopClient? shopClient;
  final Future<PipeBuyerShopRoleSession> Function()? shopSessionOverride;

  @override
  State<MarketplaceScopedStaffDashboard> createState() =>
      _MarketplaceScopedStaffDashboardState();
}

class _ScopedModuleSpec {
  const _ScopedModuleSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

class _MarketplaceScopedStaffDashboardState
    extends State<MarketplaceScopedStaffDashboard> {
  StreamSubscription<MarketplaceStaffPermissionsState>? _sub;
  MarketplaceStaffPermissionsState _state =
      const MarketplaceStaffPermissionsState.none();
  bool _loading = true;
  int _selectedModuleIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.permissionsOverride != null) {
      _state = widget.permissionsOverride!;
      _loading = false;
    } else {
      _loadInitialAndWatch();
    }
  }

  @override
  void didUpdateWidget(covariant MarketplaceScopedStaffDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.permissionsOverride != oldWidget.permissionsOverride &&
        widget.permissionsOverride != null) {
      setState(() {
        _state = widget.permissionsOverride!;
        _loading = false;
      });
    }
  }

  Future<void> _loadInitialAndWatch() async {
    final initial =
        await resolveMarketplaceStaffPermissions(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _state = initial;
      _loading = false;
    });
    _sub = watchMarketplaceStaffPermissions().listen((next) {
      if (!mounted) return;
      setState(() {
        _state = next;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<_ScopedModuleSpec> _buildModules() {
    final modules = <_ScopedModuleSpec>[];
    if (_state.hasShopAccess) {
      modules.add(
        _ScopedModuleSpec(
          id: 'shop_affiliate',
          label: 'Store & Affiliate Links',
          icon: Icons.shopping_bag_outlined,
          builder: (_) => PipeBuyerShopAdminPage(
            embedded: true,
            initialTabIndex: widget.initialShopTabIndex,
            client: widget.shopClient,
            sessionOverride: widget.shopSessionOverride,
          ),
        ),
      );
    }
    if (_state.hasDirectoryAccess) {
      modules.add(
        _ScopedModuleSpec(
          id: 'directory',
          label: 'Oilfield Directory (${_state.yellowPagesRole.toUpperCase()})',
          icon: Icons.contact_phone_outlined,
          builder: (_) => const PipeBuyerContactCenterDashboard(),
        ),
      );
    }
    if (_state.canGrantPermissions) {
      modules.add(
        _ScopedModuleSpec(
          id: 'user_permissions',
          label: 'User Permissions',
          icon: Icons.manage_accounts_rounded,
          builder: (_) => const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: MarketplaceAdminUserPermissionsPanel(),
          ),
        ),
      );
    }
    return modules;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.embedded
          ? const Center(child: CircularProgressIndicator())
          : const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final modules = _buildModules();
    if (_state.restricted || modules.isEmpty) {
      final unauthorized = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _state.restricted
                      ? Icons.block_rounded
                      : Icons.lock_outline_rounded,
                  size: 46,
                  color: _state.restricted
                      ? PipeBuyerColors.danger
                      : PipeBuyerColors.muted,
                ),
                const SizedBox(height: 12),
                Text(
                  _state.restricted
                      ? 'Account Permissions Restricted'
                      : 'No Staff Admin Roles Assigned',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _state.restricted
                      ? 'An Administrator has restricted staff actions on this account.'
                      : 'Ask a Pipe Buyer Administrator to grant Store, Affiliate, or Directory permissions to your account.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: PipeBuyerColors.muted),
                ),
              ],
            ),
          ),
        ),
      );
      if (widget.embedded) return unauthorized;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: PipeBuyerColors.ink,
          foregroundColor: Colors.white,
          title: const Text('My Admin Workspace'),
        ),
        body: unauthorized,
      );
    }

    final activeIdx = _selectedModuleIndex.clamp(0, modules.length - 1);
    final platformsSummary = _state.allowedAffiliatePlatforms.contains('all')
        ? 'All Affiliate Platforms (Amazon, AliExpress, Lazada, Shopee & 25+ More)'
        : '${_state.allowedAffiliatePlatforms.length} Affiliate Platform(s) Enabled';

    final content = Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            border: Border(
              bottom: BorderSide(color: Colors.orange.shade200),
            ),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: Color(0xFF9A3412),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Scoped Admin Workspace • Showing only your assigned permissions (${_state.roleBadgeLabel}${_state.hasShopAccess ? ' • $platformsSummary' : ''})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ],
              ),
              if (_state.hasShopAccess)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => MarketplaceNavigation.openShopStore(context),
                  icon: const Icon(Icons.storefront_outlined, size: 16),
                  label: const Text('View Live /shop'),
                ),
            ],
          ),
        ),
        if (modules.length > 1)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.white,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(modules.length, (index) {
                final mod = modules[index];
                final selected = index == activeIdx;
                return ChoiceChip(
                  selected: selected,
                  avatar: Icon(mod.icon, size: 17),
                  label: Text(
                    mod.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedModuleIndex = index),
                );
              }),
            ),
          ),
        Expanded(
          child: modules[activeIdx].builder(context),
        ),
      ],
    );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: PipeBuyerColors.canvas,
      appBar: AppBar(
        backgroundColor: PipeBuyerColors.ink,
        foregroundColor: Colors.white,
        title: const Text('My Admin Workspace (Role-Scoped)'),
      ),
      body: content,
    );
  }
}
