import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_admin_access.dart';

@immutable
class MarketplaceBusinessProfileEntry {
  const MarketplaceBusinessProfileEntry({
    required this.id,
    this.publicName = '',
    this.legalName = '',
    this.publicPhone = '',
    this.publicEmail = '',
    this.website = '',
    this.serviceArea,
    this.serviceAreaLabel = '',
    this.serviceCountryCodes = const <String>[],
    this.serviceRegionKeys = const <String>[],
    this.servicePlaceKeys = const <String>[],
    this.privateAddress = '',
    this.yardLocation,
    this.description = '',
    this.photoUrl = '',
  });

  final String id;
  final String publicName;
  final String legalName;
  final String publicPhone;
  final String publicEmail;
  final String website;
  final Map<String, dynamic>? serviceArea;
  final String serviceAreaLabel;
  final List<String> serviceCountryCodes;
  final List<String> serviceRegionKeys;
  final List<String> servicePlaceKeys;
  final String privateAddress;
  final Map<String, dynamic>? yardLocation;
  final String description;
  final String photoUrl;

  bool get hasContent =>
      publicName.trim().isNotEmpty ||
      legalName.trim().isNotEmpty ||
      publicPhone.trim().isNotEmpty ||
      publicEmail.trim().isNotEmpty ||
      description.trim().isNotEmpty;

  String get displayTitle {
    final pub = publicName.trim();
    if (pub.isNotEmpty) return pub;
    final leg = legalName.trim();
    if (leg.isNotEmpty) return leg;
    return 'Business account';
  }

  String get displaySubtitle {
    final parts = <String>[
      if (serviceAreaLabel.trim().isNotEmpty) serviceAreaLabel.trim(),
      if (publicEmail.trim().isNotEmpty) publicEmail.trim(),
    ];
    return parts.isEmpty ? 'Marketplace business profile' : parts.join(' • ');
  }

  factory MarketplaceBusinessProfileEntry.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    List<String> strings(Object? raw) => raw is Iterable
        ? raw
            .map((e) => '${e ?? ''}'.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    final rawArea = map['serviceArea'];
    final rawYard = map['yardLocation'];
    return MarketplaceBusinessProfileEntry(
      id: id.trim().isEmpty ? 'primary' : id.trim(),
      publicName: '${map['publicName'] ?? ''}'.trim(),
      legalName: '${map['legalName'] ?? ''}'.trim(),
      publicPhone: '${map['publicPhone'] ?? ''}'.trim(),
      publicEmail: '${map['publicEmail'] ?? ''}'.trim(),
      website: '${map['website'] ?? ''}'.trim(),
      serviceArea: rawArea is Map ? Map<String, dynamic>.from(rawArea) : null,
      serviceAreaLabel: '${map['serviceAreaLabel'] ?? ''}'.trim(),
      serviceCountryCodes: strings(map['serviceCountryCodes']),
      serviceRegionKeys: strings(map['serviceRegionKeys']),
      servicePlaceKeys: strings(map['servicePlaceKeys']),
      privateAddress: '${map['privateAddress'] ?? ''}'.trim(),
      yardLocation: rawYard is Map ? Map<String, dynamic>.from(rawYard) : null,
      description: '${map['description'] ?? ''}'.trim(),
      photoUrl: '${map['photoUrl'] ?? ''}'.trim(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'publicName': publicName,
        'legalName': legalName,
        'publicPhone': publicPhone,
        'publicEmail': publicEmail,
        'website': website,
        'serviceArea': serviceArea,
        'serviceAreaLabel': serviceAreaLabel,
        'serviceCountryCodes': serviceCountryCodes,
        'serviceRegionKeys': serviceRegionKeys,
        'servicePlaceKeys': servicePlaceKeys,
        'privateAddress': privateAddress,
        'yardLocation': yardLocation,
        'description': description,
        'photoUrl': photoUrl,
      };
}

enum MarketplaceWebsiteRoleTarget {
  adminPortal,
  shopAdmin,
  directoryAdmin,
}

@immutable
class MarketplaceWebsiteRoleEntry {
  const MarketplaceWebsiteRoleEntry({
    required this.id,
    required this.target,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.authorized,
    required this.mfaRequired,
    required this.badgeLabel,
  });

  final String id;
  final MarketplaceWebsiteRoleTarget target;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool authorized;
  final bool mfaRequired;
  final String badgeLabel;
}

List<MarketplaceWebsiteRoleEntry> resolveWebsiteRolesFromClaims(
  Map<String, dynamic>? claims,
) {
  final values = claims ?? const <String, dynamic>{};
  final adminState = marketplaceAdministratorClaimsState(values);
  final firebase = values['firebase'];
  final secondFactor = firebase is Map
      ? (firebase['sign_in_second_factor']?.toString().trim() ?? '')
      : '';
  final signInProvider = firebase is Map
      ? (firebase['sign_in_provider']?.toString().trim().toLowerCase() ?? '')
      : '';
  final hasSecondFactor = secondFactor.isNotEmpty;
  final isFederatedProvider = const <String>{
    'google.com',
    'apple.com',
    'microsoft.com',
  }.contains(signInProvider);
  final emailVerified = values['email_verified'] == true;

  final roles = <MarketplaceWebsiteRoleEntry>[];

  if (adminState == MarketplaceAdministratorState.authorized) {
    roles.add(
      const MarketplaceWebsiteRoleEntry(
        id: 'role_admin_portal',
        target: MarketplaceWebsiteRoleTarget.adminPortal,
        title: 'Administrator Portal',
        subtitle:
            'Platform moderation, revenue analytics, users & system controls',
        icon: Icons.admin_panel_settings_outlined,
        authorized: true,
        mfaRequired: false,
        badgeLabel: 'ROLE LIVE',
      ),
    );
    roles.add(
      const MarketplaceWebsiteRoleEntry(
        id: 'role_shop_admin',
        target: MarketplaceWebsiteRoleTarget.shopAdmin,
        title: 'Store & Affiliate Admin',
        subtitle:
            'Add/remove Amazon affiliate links, manage 1,000-item catalog & vendors',
        icon: Icons.shopping_bag_outlined,
        authorized: true,
        mfaRequired: false,
        badgeLabel: 'ROLE LIVE',
      ),
    );
  } else if (adminState == MarketplaceAdministratorState.mfaRequired) {
    roles.add(
      const MarketplaceWebsiteRoleEntry(
        id: 'role_admin_portal',
        target: MarketplaceWebsiteRoleTarget.adminPortal,
        title: 'Administrator Portal',
        subtitle:
            'Administrator role assigned • Complete 2-step SMS in Verification & Security to unlock',
        icon: Icons.admin_panel_settings_outlined,
        authorized: false,
        mfaRequired: true,
        badgeLabel: '2-STEP SMS NEEDED',
      ),
    );
    roles.add(
      const MarketplaceWebsiteRoleEntry(
        id: 'role_shop_admin',
        target: MarketplaceWebsiteRoleTarget.shopAdmin,
        title: 'Store & Affiliate Admin',
        subtitle:
            'Store & affiliate role assigned • Complete 2-step SMS to add/remove affiliate links',
        icon: Icons.shopping_bag_outlined,
        authorized: false,
        mfaRequired: true,
        badgeLabel: '2-STEP SMS NEEDED',
      ),
    );
  } else {
    final shopRole = '${values['shopRole'] ?? ''}'.trim().toLowerCase();
    if (shopRole == 'store_manager' ||
        shopRole == 'catalog_editor' ||
        shopRole == 'affiliate_contributor') {
      final ready = emailVerified && values['restricted'] != true;
      final title = switch (shopRole) {
        'store_manager' => 'Store Manager',
        'catalog_editor' => 'Store Catalog Editor',
        _ => 'Affiliate Product Contributor',
      };
      roles.add(
        MarketplaceWebsiteRoleEntry(
          id: 'role_shop_staff_$shopRole',
          target: MarketplaceWebsiteRoleTarget.shopAdmin,
          title: title,
          subtitle: ready
              ? 'Manage PipeBuyer Store products & 25+ affiliate platforms'
              : 'Store role assigned • Verify your email address to unlock',
          icon: Icons.shopping_bag_outlined,
          authorized: ready,
          mfaRequired: false,
          badgeLabel: ready ? 'ROLE LIVE' : 'VERIFY EMAIL',
        ),
      );
    }
  }

  final ypRole = '${values['yellowPagesRole'] ?? ''}'.trim().toLowerCase();
  if (ypRole == 'manager' || ypRole == 'agent') {
    final ready = emailVerified &&
        values['restricted'] != true &&
        (hasSecondFactor || isFederatedProvider);
    roles.add(
      MarketplaceWebsiteRoleEntry(
        id: 'role_directory_$ypRole',
        target: MarketplaceWebsiteRoleTarget.directoryAdmin,
        title: ypRole == 'manager'
            ? 'Oilfield Directory Manager'
            : 'Oilfield Directory Agent',
        subtitle: ready
            ? 'Directory verification queue, contact center & flagged entries'
            : 'Directory role assigned • Sign in via Google or complete 2-step SMS',
        icon: Icons.contact_phone_outlined,
        authorized: ready,
        mfaRequired: !ready,
        badgeLabel: ready ? 'ROLE LIVE' : '2-STEP SMS NEEDED',
      ),
    );
  }

  return roles;
}

enum MarketplaceAccountSwitcherActionKind {
  switchPersonal,
  switchBusiness,
  createBusiness,
  openRole,
}

@immutable
class MarketplaceAccountSwitcherSelection {
  const MarketplaceAccountSwitcherSelection._({
    required this.kind,
    this.businessProfileId = '',
    this.newBusinessName = '',
    this.role,
  });

  const MarketplaceAccountSwitcherSelection.personal()
      : this._(kind: MarketplaceAccountSwitcherActionKind.switchPersonal);

  const MarketplaceAccountSwitcherSelection.business(String profileId)
      : this._(
          kind: MarketplaceAccountSwitcherActionKind.switchBusiness,
          businessProfileId: profileId,
        );

  const MarketplaceAccountSwitcherSelection.createBusiness(String businessName)
      : this._(
          kind: MarketplaceAccountSwitcherActionKind.createBusiness,
          newBusinessName: businessName,
        );

  const MarketplaceAccountSwitcherSelection.role(
    MarketplaceWebsiteRoleEntry selectedRole,
  ) : this._(
          kind: MarketplaceAccountSwitcherActionKind.openRole,
          role: selectedRole,
        );

  final MarketplaceAccountSwitcherActionKind kind;
  final String businessProfileId;
  final String newBusinessName;
  final MarketplaceWebsiteRoleEntry? role;
}

class MarketplaceAccountRoleSwitcherDialog extends StatefulWidget {
  const MarketplaceAccountRoleSwitcherDialog({
    super.key,
    required this.activeAccountType,
    required this.activeBusinessProfileId,
    required this.accountEmail,
    required this.personalDisplayName,
    required this.personalCommunity,
    required this.businessProfiles,
    required this.websiteRoles,
  });

  final String activeAccountType;
  final String activeBusinessProfileId;
  final String accountEmail;
  final String personalDisplayName;
  final String personalCommunity;
  final List<MarketplaceBusinessProfileEntry> businessProfiles;
  final List<MarketplaceWebsiteRoleEntry> websiteRoles;

  static Future<MarketplaceAccountSwitcherSelection?> show(
    BuildContext context, {
    required String activeAccountType,
    required String activeBusinessProfileId,
    required String accountEmail,
    required String personalDisplayName,
    required String personalCommunity,
    required List<MarketplaceBusinessProfileEntry> businessProfiles,
    required List<MarketplaceWebsiteRoleEntry> websiteRoles,
  }) {
    return showDialog<MarketplaceAccountSwitcherSelection>(
      context: context,
      builder: (_) => MarketplaceAccountRoleSwitcherDialog(
        activeAccountType: activeAccountType,
        activeBusinessProfileId: activeBusinessProfileId,
        accountEmail: accountEmail,
        personalDisplayName: personalDisplayName,
        personalCommunity: personalCommunity,
        businessProfiles: businessProfiles,
        websiteRoles: websiteRoles,
      ),
    );
  }

  @override
  State<MarketplaceAccountRoleSwitcherDialog> createState() =>
      _MarketplaceAccountRoleSwitcherDialogState();
}

class _MarketplaceAccountRoleSwitcherDialogState
    extends State<MarketplaceAccountRoleSwitcherDialog> {
  final TextEditingController _newBusinessController = TextEditingController();
  bool _addingNewBusiness = false;
  String? _newBusinessError;

  @override
  void dispose() {
    _newBusinessController.dispose();
    super.dispose();
  }

  void _submitNewBusiness() {
    final trimmed = _newBusinessController.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _newBusinessError = 'Enter a business or company name.');
      return;
    }
    Navigator.of(context).pop(
      MarketplaceAccountSwitcherSelection.createBusiness(trimmed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPersonalActive = widget.activeAccountType != 'business';
    final personalTitle = widget.personalDisplayName.trim().isEmpty
        ? 'Personal account'
        : widget.personalDisplayName.trim();
    final personalMeta = <String>[
      'Personal account',
      if (widget.accountEmail.trim().isNotEmpty) widget.accountEmail.trim(),
      if (widget.personalCommunity.trim().isNotEmpty)
        widget.personalCommunity.trim(),
    ].join(' • ');

    final businesses = widget.businessProfiles.isEmpty
        ? const <MarketplaceBusinessProfileEntry>[
            MarketplaceBusinessProfileEntry(id: 'primary'),
          ]
        : widget.businessProfiles;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.orange.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      color: PipeBuyerColors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Switch account, business or role',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (widget.accountEmail.trim().isNotEmpty)
                          Text(
                            widget.accountEmail.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SwitcherSectionHeading('PERSONAL ACCOUNT'),
                    _SwitcherOptionCard(
                      tileKey: const Key('switcher-personal-account'),
                      icon: Icons.person_outline_rounded,
                      title: personalTitle,
                      subtitle: personalMeta,
                      badgeText: isPersonalActive ? 'ACTIVE' : 'LIVE',
                      active: isPersonalActive,
                      accentColor: PipeBuyerColors.orange,
                      onTap: () => Navigator.of(context).pop(
                        const MarketplaceAccountSwitcherSelection.personal(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _SwitcherSectionHeading('BUSINESS ACCOUNTS'),
                    ...businesses.map((business) {
                      final isActiveBiz = !isPersonalActive &&
                          (business.id == widget.activeBusinessProfileId ||
                              (widget.activeBusinessProfileId.isEmpty &&
                                  business.id == businesses.first.id));
                      final title = business.hasContent
                          ? business.displayTitle
                          : 'Set up business account';
                      final subtitle = business.hasContent
                          ? business.displaySubtitle
                          : 'Create your public company storefront & coverage area';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SwitcherOptionCard(
                          tileKey: Key('switcher-business-${business.id}'),
                          icon: Icons.business_center_outlined,
                          title: title,
                          subtitle: subtitle,
                          badgeText: isActiveBiz
                              ? 'ACTIVE'
                              : (business.hasContent ? 'LIVE' : 'SETUP'),
                          active: isActiveBiz,
                          accentColor: PipeBuyerColors.industrialBlue,
                          onTap: () => Navigator.of(context).pop(
                            MarketplaceAccountSwitcherSelection.business(
                              business.id,
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_addingNewBusiness)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              key: const Key('switcher-new-business-input'),
                              controller: _newBusinessController,
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submitNewBusiness(),
                              decoration: InputDecoration(
                                labelText: 'New business or company name',
                                hintText: 'e.g. Bailey Oilfield Supply Ltd.',
                                errorText: _newBusinessError,
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                TextButton(
                                  onPressed: () => setState(() {
                                    _addingNewBusiness = false;
                                    _newBusinessError = null;
                                  }),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton.icon(
                                  key: const Key(
                                    'switcher-create-business-submit',
                                  ),
                                  onPressed: _submitNewBusiness,
                                  icon:
                                      const Icon(Icons.add_business, size: 17),
                                  label: const Text('Create & switch'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: const Key('switcher-add-business-button'),
                          onPressed: () =>
                              setState(() => _addingNewBusiness = true),
                          icon:
                              const Icon(Icons.add_business_outlined, size: 18),
                          label: const Text('Add another business account'),
                        ),
                      ),
                    if (widget.websiteRoles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _SwitcherSectionHeading(
                        'WEBSITE ROLES & WORKSPACES',
                      ),
                      ...widget.websiteRoles.map(
                        (role) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SwitcherOptionCard(
                            tileKey: Key('switcher-${role.id}'),
                            icon: role.icon,
                            title: role.title,
                            subtitle: role.subtitle,
                            badgeText: role.badgeLabel,
                            active: false,
                            accentColor: role.authorized
                                ? Colors.purple.shade700
                                : Colors.orange.shade800,
                            trailingIcon: role.authorized
                                ? Icons.open_in_new_rounded
                                : Icons.lock_open_rounded,
                            onTap: () => Navigator.of(context).pop(
                              MarketplaceAccountSwitcherSelection.role(role),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitcherSectionHeading extends StatelessWidget {
  const _SwitcherSectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.05,
            color: PipeBuyerColors.muted,
          ),
        ),
      );
}

class _SwitcherOptionCard extends StatelessWidget {
  const _SwitcherOptionCard({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.active,
    required this.accentColor,
    required this.onTap,
    this.trailingIcon = Icons.chevron_right_rounded,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final bool active;
  final Color accentColor;
  final VoidCallback onTap;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final bg = active ? accentColor.withValues(alpha: 0.08) : Colors.white;
    final border = active ? accentColor : const Color(0xFFE2E8F0);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: tileKey,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: active ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accentColor, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: PipeBuyerColors.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                active ? Icons.check_circle_rounded : trailingIcon,
                color: active ? accentColor : PipeBuyerColors.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
