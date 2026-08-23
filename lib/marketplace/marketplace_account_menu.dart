import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_admin_access.dart';
import 'marketplace_memberships_dialog.dart';

class MarketplaceAccountMenuButton extends StatefulWidget {
  const MarketplaceAccountMenuButton({
    super.key,
    required this.extended,
    required this.onAccount,
    required this.onTrust,
    required this.onMemberships,
    required this.onSupport,
    required this.onSignOut,
  });

  final bool extended;
  final VoidCallback onAccount;
  final VoidCallback onTrust;
  final VoidCallback onMemberships;
  final VoidCallback onSupport;
  final VoidCallback onSignOut;

  @override
  State<MarketplaceAccountMenuButton> createState() =>
      _MarketplaceAccountMenuButtonState();
}

class _MarketplaceAccountMenuButtonState
    extends State<MarketplaceAccountMenuButton> {
  late Future<MarketplaceAdministratorState> _administratorState;

  @override
  void initState() {
    super.initState();
    _administratorState = marketplaceAdministratorState();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    final name = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? 'Account');
    final email = user.email ?? '';
    final initial = name.isEmpty ? 'P' : name.substring(0, 1).toUpperCase();

    return FutureBuilder<MarketplaceAdministratorState>(
      future: _administratorState,
      builder: (context, snapshot) {
        final showDispatchBilling =
            snapshot.data == MarketplaceAdministratorState.authorized;
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
                showDialog<void>(
                  context: context,
                  builder: (_) => MarketplaceMembershipsDialog(
                    onVipDetails: widget.onMemberships,
                  ),
                );
                return;
              case _AccountMenuAction.support:
                widget.onSupport();
                return;
              case _AccountMenuAction.dispatchBilling:
                context.push('/admin/dispatch-billing');
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
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
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
                title: 'Trust & verification',
                subtitle: 'Ownership and account security',
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
            if (showDispatchBilling) ...[
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _AccountMenuAction.dispatchBilling,
                child: _MenuRow(
                  icon: Icons.local_shipping_outlined,
                  title: 'Dispatch Billing Operations',
                  subtitle: 'Launch readiness and reconciliation',
                  accent: PipeBuyerColors.orangePressed,
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const Text(
                              'Account & membership',
                              style: TextStyle(
                                color: PipeBuyerColors.muted,
                                fontSize: 10,
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
      },
    );
  }
}

enum _AccountMenuAction {
  account,
  trust,
  memberships,
  support,
  dispatchBilling,
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
