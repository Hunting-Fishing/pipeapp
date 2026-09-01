from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    target = Path(path)
    text = target.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"{label}: expected exactly one match in {path}, found {count}"
        )
    target.write_text(text.replace(old, new, 1), encoding="utf-8")


navigation = Path("lib/marketplace/marketplace_navigation.dart")
navigation.write_text(
    """import 'package:flutter/material.dart';

@immutable
class MarketplaceDestinationRequest {
  const MarketplaceDestinationRequest(this.pageIndex);

  final int pageIndex;
}

/// Coordinates top-level marketplace navigation from pages pushed above the
/// tab scaffold and from simple Home intent actions.
class MarketplaceNavigation {
  MarketplaceNavigation._();

  static final ValueNotifier<int> homeRequests = ValueNotifier<int>(0);
  static final ValueNotifier<MarketplaceDestinationRequest?> destinationRequests =
      ValueNotifier<MarketplaceDestinationRequest?>(null);
  static final ValueNotifier<int> wantedRequests = ValueNotifier<int>(0);

  static void goHome(BuildContext context) {
    homeRequests.value++;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static void goToDestination(BuildContext context, int pageIndex) {
    destinationRequests.value = MarketplaceDestinationRequest(pageIndex);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static void goToBrowse(BuildContext context) => goToDestination(context, 1);

  static void goToSell(BuildContext context) => goToDestination(context, 2);

  static void goToDispatch(BuildContext context) => goToDestination(context, 7);

  static void goToWanted(BuildContext context) {
    wantedRequests.value++;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
""",
    encoding="utf-8",
)

home = "lib/marketplace/marketplace_home_welcome.dart"
replace_once(
    home,
    "import 'marketplace_home_hero_assets.dart';\n",
    "import 'marketplace_home_hero_assets.dart';\nimport 'marketplace_navigation.dart';\n",
    "home navigation import",
)
replace_once(
    home,
    """    if (user == null) {
      return const MarketplaceHomeDiscoveryHero();
    }
""",
    """    if (user == null) {
      return MarketplaceHomeDiscoveryHero(
        onBrowse: () => MarketplaceNavigation.goToBrowse(context),
        onSell: () => MarketplaceNavigation.goToSell(context),
        onDispatch: () => MarketplaceNavigation.goToDispatch(context),
        onWanted: () => MarketplaceNavigation.goToWanted(context),
      );
    }
""",
    "signed-out home intents",
)
replace_once(
    home,
    """        return MarketplaceHomeDiscoveryHero(
          name: name,
          accountType: accountType,
        );
""",
    """        return MarketplaceHomeDiscoveryHero(
          name: name,
          accountType: accountType,
          onBrowse: () => MarketplaceNavigation.goToBrowse(context),
          onSell: () => MarketplaceNavigation.goToSell(context),
          onDispatch: () => MarketplaceNavigation.goToDispatch(context),
          onWanted: () => MarketplaceNavigation.goToWanted(context),
        );
""",
    "signed-in home intents",
)
replace_once(
    home,
    """  const MarketplaceHomeDiscoveryHero({
    super.key,
    this.name,
    this.accountType = 'personal',
  });

  final String? name;
  final String accountType;
""",
    """  const MarketplaceHomeDiscoveryHero({
    super.key,
    this.name,
    this.accountType = 'personal',
    this.onBrowse,
    this.onSell,
    this.onDispatch,
    this.onWanted,
  });

  final String? name;
  final String accountType;
  final VoidCallback? onBrowse;
  final VoidCallback? onSell;
  final VoidCallback? onDispatch;
  final VoidCallback? onWanted;
""",
    "hero callback contract",
)
replace_once(
    home,
    """        const SizedBox(height: 12),
        const PipeBuyerTrustBand(
""",
    """        const SizedBox(height: 12),
        MarketplaceHomeIntentActions(
          onBrowse: onBrowse,
          onSell: onSell,
          onDispatch: onDispatch,
          onWanted: onWanted,
        ),
        const SizedBox(height: 12),
        const PipeBuyerTrustBand(
""",
    "home intent placement",
)

intent_widget = r'''
class MarketplaceHomeIntentActions extends StatelessWidget {
  const MarketplaceHomeIntentActions({
    super.key,
    this.onBrowse,
    this.onSell,
    this.onDispatch,
    this.onWanted,
  });

  final VoidCallback? onBrowse;
  final VoidCallback? onSell;
  final VoidCallback? onDispatch;
  final VoidCallback? onWanted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980 ? 4 : 2;
        const spacing = 10.0;
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What do you want to do?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start with one simple action. Pipe Buyer will guide the rest of the workflow.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: PipeBuyerColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: Icons.search_rounded,
                        title: 'Browse inventory',
                        subtitle: 'Find pipe, equipment and industrial assets.',
                        onTap: onBrowse,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: Icons.add_box_outlined,
                        title: 'Sell something',
                        subtitle: 'Create a guided Marketplace listing.',
                        onTap: onSell,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: Icons.local_shipping_outlined,
                        title: 'Request service',
                        subtitle: 'Find trucking and industrial service providers.',
                        onTap: onDispatch,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: Icons.campaign_outlined,
                        title: 'Post wanted / RFQ',
                        subtitle: 'Tell the market exactly what you need.',
                        onTap: onWanted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MarketplaceIntentCard extends StatelessWidget {
  const _MarketplaceIntentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PipeBuyerColors.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 118),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.orangeSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: PipeBuyerColors.orangePressed,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

'''
replace_once(
    home,
    "class _MarketplaceHomeHeroSurface extends StatelessWidget {\n",
    intent_widget + "class _MarketplaceHomeHeroSurface extends StatelessWidget {\n",
    "intent widget insertion",
)

shell = "lib/marketplace/oil_gas_marketplace.dart"
replace_once(
    shell,
    """    MarketplaceNavigation.homeRequests.addListener(_handleHomeRequest);
    _authSubscription =
""",
    """    MarketplaceNavigation.homeRequests.addListener(_handleHomeRequest);
    MarketplaceNavigation.destinationRequests
        .addListener(_handleDestinationRequest);
    MarketplaceNavigation.wantedRequests.addListener(_handleWantedRequest);
    _authSubscription =
""",
    "destination listener registration",
)
replace_once(
    shell,
    """    MarketplaceNavigation.homeRequests.removeListener(_handleHomeRequest);
    _authSubscription?.cancel();
""",
    """    MarketplaceNavigation.homeRequests.removeListener(_handleHomeRequest);
    MarketplaceNavigation.destinationRequests
        .removeListener(_handleDestinationRequest);
    MarketplaceNavigation.wantedRequests.removeListener(_handleWantedRequest);
    _authSubscription?.cancel();
""",
    "destination listener cleanup",
)
replace_once(
    shell,
    """  void _handleHomeRequest() {
    if (mounted && _tab != 0) setState(() => _tab = 0);
  }

  void _selectTab(int index) {
""",
    """  void _handleHomeRequest() {
    if (mounted && _tab != 0) setState(() => _tab = 0);
  }

  void _handleDestinationRequest() {
    final request = MarketplaceNavigation.destinationRequests.value;
    if (!mounted || request == null) return;
    final target = request.pageIndex;
    if ((target == 1 || target == 2 || target == 3) && !_features.marketplace) {
      return;
    }
    if (target == 6 && !_features.auctions) return;
    if (target == 7 && !_features.dispatch) return;
    if (_tab != target) _selectTab(target);
  }

  void _handleWantedRequest() {
    if (!mounted || !_features.marketplace) return;
    _openCreate(wanted: true);
  }

  void _selectTab(int index) {
""",
    "destination handlers",
)
replace_once(
    shell,
    """            const MarketplaceShellDestination(
              pageIndex: 2,
              label: 'List',
""",
    """            const MarketplaceShellDestination(
              pageIndex: 2,
              label: 'Sell',
""",
    "mobile Sell label",
)
replace_once(
    shell,
    """          const MarketplaceShellDestination(
            pageIndex: 5,
            label: 'Profile',
""",
    """          const MarketplaceShellDestination(
            pageIndex: 5,
            label: 'Account',
""",
    "mobile Account label",
)

hero_test = "test/marketplace_home_hero_responsive_test.dart"
replace_once(
    hero_test,
    """  expect(find.text('Business account'), findsOneWidget);
  expect(find.text('Verified Businesses'), findsOneWidget);
""",
    """  expect(find.text('Business account'), findsOneWidget);
  expect(find.text('Browse inventory'), findsOneWidget);
  expect(find.text('Sell something'), findsOneWidget);
  expect(find.text('Request service'), findsOneWidget);
  expect(find.text('Post wanted / RFQ'), findsOneWidget);
  expect(find.text('Verified Businesses'), findsOneWidget);
""",
    "hero intent assertions",
)

adaptive_test = "test/marketplace_adaptive_shell_test.dart"
replace_once(
    adaptive_test,
    """      pageIndex: 2,
      label: 'List',
""",
    """      pageIndex: 2,
      label: 'Sell',
""",
    "adaptive Sell fixture",
)
replace_once(
    adaptive_test,
    """      pageIndex: 5,
      label: 'Profile',
""",
    """      pageIndex: 5,
      label: 'Account',
""",
    "adaptive Account fixture",
)

Path("test/marketplace_navigation_test.dart").write_text(
    r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_navigation.dart';

void main() {
  testWidgets('home intent navigation emits repeated destination requests',
      (tester) async {
    var notifications = 0;
    void listener() => notifications++;
    MarketplaceNavigation.destinationRequests.addListener(listener);
    addTearDown(
      () => MarketplaceNavigation.destinationRequests.removeListener(listener),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => MarketplaceNavigation.goToBrowse(context),
                child: const Text('Browse'),
              ),
              TextButton(
                onPressed: () => MarketplaceNavigation.goToBrowse(context),
                child: const Text('Browse again'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Browse'));
    await tester.pump();
    await tester.tap(find.text('Browse again'));
    await tester.pump();

    expect(notifications, 2);
    expect(MarketplaceNavigation.destinationRequests.value?.pageIndex, 1);
  });

  testWidgets('wanted intent emits a distinct request', (tester) async {
    final before = MarketplaceNavigation.wantedRequests.value;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => MarketplaceNavigation.goToWanted(context),
            child: const Text('Wanted'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Wanted'));
    await tester.pump();

    expect(MarketplaceNavigation.wantedRequests.value, before + 1);
  });
}
''',
    encoding="utf-8",
)

Path("docs/PIPEBUYER_ACTIVE_PRODUCT_BUILD_PLAN_2026-09-01.md").write_text(
    r'''# Pipe Buyer Active Product Build Plan — 2026-09-01

## Authority and scope

This file is the active implementation sequence for the current Pipe Buyer product build. Launch-readiness status remains governed by `docs/PIPE_BUYER_LAUNCH_READINESS_AUDIT_2026-08-30.md`; older Phase 1.1, Phase 2 and Dispatch percentages are historical checkpoints unless the current audit carries a requirement forward.

North America remains the first operating scope. The product must stay simple for non-technical field users while preserving server-authoritative payments, App Check, Firebase Rules, moderation evidence, exact release controls and existing repair boundaries.

## Release sequence

### Release 1 — Simple Pipe Buyer flow

- Make Home start with four understandable intents: Browse inventory, Sell something, Request service, Post wanted / RFQ.
- Keep mobile navigation to Home, Browse, Sell, Messages and Account.
- Keep the existing desktop grouped Marketplace / Deals / Logistics navigation.
- Route Home intents into existing Marketplace, listing, Wanted and Dispatch workflows instead of creating duplicate systems.
- Do not change Firebase schemas, Stripe settlement, moderation evidence or release controls.

### Release 2 — Marketplace journey closure

Prove and refine ordinary-user buyer, seller, offer/counteroffer, Timed Buying, Wanted, messaging/block/report, payment/support and Dispatch-handoff journeys. Every transaction surface must show current status, next action and responsible party.

### Release 3 — Dispatch Directory

Validate representative provider records, privacy classes, filters, location/radius behavior, list/map synchronization, company details and direct Request Quote.

### Release 4 — Dispatch Request Service

Finish the service-first wizard with taxonomy-driven questions, freight and non-freight paths, direct-provider requests, open requests, review, edit and cancel.

### Release 5 — Dispatch quotes and jobs

Complete provider inbox, structured quotes/revisions, quote comparison, messaging, award, schedule, work, proof/BOL and completion.

### Release 6 — Dispatch financial ledger

Only if per-job transaction fees are intended: build a freight-specific immutable ledger, charge/fee/provider-proceeds records, refunds, disputes, payout state and reconciliation before enabling job charging.

### Release 7 — Native store release

Complete physical Android/iOS acceptance, App Check attestation, notifications/deep links, native subscription verification/reconciliation, accessibility and store publication.

### Release 8 — Advanced platform

Truck routing/ETA, saved routes, fleet-capacity optimization, catalog provenance/confidence, analytics definitions and country-by-country international expansion.

## Build control

Every slice follows requirement -> existing-code inspection -> bounded change -> focused tests -> full regression -> acceptance -> repair record when a defect is found -> merge -> exact-SHA production release. Once a root cause and repair are proven, record and preserve that repair boundary instead of repeating speculative fixes.
''',
    encoding="utf-8",
)
