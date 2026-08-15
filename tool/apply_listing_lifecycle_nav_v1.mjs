"use strict";

import fs from "node:fs";
import path from "node:path";

const root = process.cwd();

function file(rel) {
  return path.join(root, rel);
}

function read(rel) {
  return fs.readFileSync(file(rel), "utf8");
}

function write(rel, text) {
  fs.writeFileSync(file(rel), text, "utf8");
  console.log(`patched: ${rel}`);
}

function replaceOnce(text, before, after, label) {
  if (text.includes(after)) return text;
  const index = text.indexOf(before);
  if (index < 0) throw new Error(`Patch anchor not found: ${label}`);
  if (text.indexOf(before, index + before.length) >= 0) {
    throw new Error(`Patch anchor is not unique: ${label}`);
  }
  return text.slice(0, index) + after + text.slice(index + before.length);
}

function replaceRegexOnce(text, pattern, replacement, label) {
  if (typeof replacement === "string" && text.includes(replacement)) return text;
  const matches = [...text.matchAll(new RegExp(pattern.source, pattern.flags.includes("g") ? pattern.flags : `${pattern.flags}g`))];
  if (matches.length !== 1) {
    throw new Error(`Expected one ${label} anchor, found ${matches.length}`);
  }
  return text.replace(pattern, replacement);
}

function patchIndex() {
  const rel = "firebase/functions/index.js";
  let text = read(rel);
  text = replaceOnce(
      text,
      'const { createMarketplaceCommands } = require("./marketplace_commands");',
      'const { createMarketplaceCommands } = require("./marketplace_commands");\n' +
      'const {\n' +
      '  createMarketplaceListingLifecycle,\n' +
      '} = require("./marketplace_listing_lifecycle");\n' +
      'const {\n' +
      '  createMarketplaceListingInsights,\n' +
      '} = require("./marketplace_listing_insights");',
      "index lifecycle imports",
  );
  text = replaceOnce(
      text,
      "const marketplaceCommands = createMarketplaceCommands(admin);",
      "const marketplaceCommands = createMarketplaceCommands(admin);\n" +
      "const marketplaceListingLifecycle = createMarketplaceListingLifecycle(admin);\n" +
      "const marketplaceListingInsights = createMarketplaceListingInsights(admin);",
      "index lifecycle initialization",
  );
  text = replaceOnce(
      text,
      'exports.cleanupExpiredMarketplaceListingDrafts = onSchedule(\n  "every 24 hours",\n  async () => marketplaceCommands.cleanupExpiredMarketplaceListingDrafts(),\n);',
      'exports.cleanupExpiredMarketplaceListingDrafts = onSchedule(\n  "every 24 hours",\n  async () => marketplaceCommands.cleanupExpiredMarketplaceListingDrafts(),\n);\nexports.monitorMarketplaceListingLifecycle = onSchedule(\n  "every 1 hours",\n  async () => {\n    await marketplaceListingLifecycle.notifyExpiringListings();\n    await marketplaceListingLifecycle.expireMarketplaceListings();\n  },\n);',
      "listing lifecycle schedule",
  );
  text = replaceOnce(
      text,
      'exports.relistMarketplaceListing = onCall(\n  protectedCallableOptions,\n  policyAcceptanceCommands.requireCurrentPolicies(\n    marketplaceCommands.relistMarketplaceListing,\n  ),\n);',
      'exports.relistMarketplaceListing = onCall(\n  protectedCallableOptions,\n  policyAcceptanceCommands.requireCurrentPolicies(\n    marketplaceCommands.relistMarketplaceListing,\n  ),\n);\nexports.renewMarketplaceListing = onCall(\n  protectedCallableOptions,\n  policyAcceptanceCommands.requireCurrentPolicies(\n    marketplaceListingLifecycle.renewMarketplaceListing,\n  ),\n);\nexports.getMarketplaceListingInsights = onCall(\n  protectedCallableOptions,\n  policyAcceptanceCommands.requireCurrentPolicies(\n    marketplaceListingInsights.getMarketplaceListingInsights,\n  ),\n);',
      "renew and insights callables",
  );
  text = replaceOnce(
      text,
      '  async (event) => {\n    const listing = event.data.data();\n    const sellerUid = listing.sellerUid;',
      '  async (event) => {\n    const listing = event.data.data();\n    await marketplaceListingLifecycle.initializeListing(\n      event.params.listingId,\n      listing,\n    );\n    const sellerUid = listing.sellerUid;',
      "initialize listing lifecycle on create",
  );
  write(rel, text);
}

function patchIndexes() {
  const rel = "firebase/firestore.indexes.json";
  const doc = JSON.parse(read(rel));
  const indexes = Array.isArray(doc.indexes) ? doc.indexes : [];
  const has = (fields) => indexes.some((index) =>
    index.collectionGroup === "public_listings" &&
    JSON.stringify(index.fields) === JSON.stringify(fields));
  const lifecycle = [
    {fieldPath: "status", order: "ASCENDING"},
    {fieldPath: "expiresAt", order: "ASCENDING"},
  ];
  const search = [
    {fieldPath: "status", order: "ASCENDING"},
    {fieldPath: "searchTokens", arrayConfig: "CONTAINS"},
    {fieldPath: "createdAt", order: "DESCENDING"},
  ];
  if (!has(lifecycle)) {
    indexes.push({collectionGroup: "public_listings", queryScope: "COLLECTION", fields: lifecycle});
  }
  if (!has(search)) {
    indexes.push({collectionGroup: "public_listings", queryScope: "COLLECTION", fields: search});
  }
  doc.indexes = indexes;
  write(rel, `${JSON.stringify(doc, null, 2)}\n`);
}

function patchAdaptiveShell() {
  const rel = "lib/marketplace/marketplace_adaptive_shell.dart";
  let text = read(rel);
  text = replaceOnce(
      text,
      "    this.railLeading,\n    this.railTrailing,\n    this.railFooter,",
      "    this.railLeading,\n    this.railTrailing,\n    this.railFooter,\n    this.expandedRailNavigation,",
      "adaptive shell constructor navigation slot",
  );
  text = replaceOnce(
      text,
      "  final Widget? railTrailing;\n  final Widget? railFooter;",
      "  final Widget? railTrailing;\n  final Widget? railFooter;\n  final Widget? expandedRailNavigation;",
      "adaptive shell navigation field",
  );
  const before = `                        Expanded(\n                          child: NavigationRailTheme(\n                            data: NavigationRailThemeData(`;
  const after = `                        Expanded(\n                          child: extendRail && expandedRailNavigation != null\n                              ? expandedRailNavigation!\n                              : NavigationRailTheme(\n                            data: NavigationRailThemeData(`;
  text = replaceOnce(text, before, after, "adaptive shell grouped rail start");
  write(rel, text);
}

function patchMarketplaceApp() {
  const rel = "lib/marketplace/oil_gas_marketplace.dart";
  let text = read(rel);
  const importAnchor = "import 'marketplace_account_hub.dart';";
  const imports = "import 'marketplace_account_hub.dart';\n" +
      "import 'marketplace_account_menu.dart';\n" +
      "import 'marketplace_account_security_page.dart';\n" +
      "import 'marketplace_grouped_navigation.dart';\n" +
      "import 'marketplace_home_welcome.dart';\n" +
      "import 'marketplace_support.dart';\n" +
      "import 'marketplace_vip_access.dart';";
  text = replaceOnce(text, importAnchor, imports, "marketplace app imports");

  text = replaceOnce(
      text,
      "              onCategory: (value) => setState(() => _category = value),\n              onSaved: _toggleSaved)",
      "              onCategory: (value) => setState(() => _category = value),\n              onSaved: _toggleSaved,\n              onList: () => _openCreate(),\n              onWanted: () => _openCreate(wanted: true))",
      "browse callbacks",
  );

  text = replaceOnce(
      text,
      "      required this.onSearch,\n      required this.onCategory,\n      required this.onSaved});",
      "      required this.onSearch,\n      required this.onCategory,\n      required this.onSaved,\n      required this.onList,\n      required this.onWanted});",
      "browse constructor callbacks",
  );
  text = replaceOnce(
      text,
      "  final ValueChanged<String?> onCategory;\n  final ValueChanged<MarketplaceListing> onSaved;",
      "  final ValueChanged<String?> onCategory;\n  final ValueChanged<MarketplaceListing> onSaved;\n  final VoidCallback onList;\n  final VoidCallback onWanted;",
      "browse callback fields",
  );

  text = replaceOnce(
      text,
      "    Query<Map<String, dynamic>> query =\n        FirebaseFirestore.instance.collection('public_listings');\n    final searchToken = normalizeMarketplaceSearchQuery(widget.search);",
      "    Query<Map<String, dynamic>> query = FirebaseFirestore.instance\n        .collection('public_listings')\n        .where('status', isEqualTo: 'active');\n    final searchToken = normalizeMarketplaceSearchQuery(widget.search);",
      "browse active query",
  );

  text = replaceOnce(
      text,
      "        .where((item) =>\n            item.transactionType != 'Auction' &&",
      "        .where((item) =>\n            item.details['status'] == 'active' &&\n            item.transactionType != 'Auction' &&",
      "browse defensive active filter",
  );

  const oldEmpty = `    if (results.isEmpty) {\n      final wanted = _filters.transactionType == 'Wanted / Seeking';\n      return MarketplaceDataStateView(\n        kind: MarketplaceDataStateKind.empty,\n        icon: wanted ? Icons.campaign_outlined : Icons.search_off_outlined,\n        title: wanted ? 'No wanted ads match' : 'No listings match',\n        message: wanted\n            ? 'Adjust the filters or check additional pages for buyer requests.'\n            : 'Adjust the search or filters to broaden the Marketplace results.',\n        primaryLabel: _hasMore ? 'Search more listings' : null,\n        primaryIcon: Icons.expand_more_rounded,\n        onPrimary: _hasMore && !_loading ? _loadPage : null,\n      );\n    }`;
  const newEmpty = `    if (results.isEmpty) {\n      final wanted = _filters.transactionType == 'Wanted / Seeking';\n      final hasDiscoveryFilter =\n          normalizeMarketplaceSearchQuery(widget.search).isNotEmpty ||\n              widget.category != null ||\n              _filters.activeCount > 0;\n      if (_documents.isEmpty && !hasDiscoveryFilter) {\n        return MarketplaceDataStateView(\n          kind: MarketplaceDataStateKind.empty,\n          icon: Icons.inventory_2_outlined,\n          title: 'No Marketplace listings yet',\n          message:\n              'Be the first to publish inventory on Pipe Buyer, or post a Wanted Ad so sellers know what you need.',\n          primaryLabel: 'Create a listing',\n          primaryIcon: Icons.add_box_outlined,\n          onPrimary: widget.onList,\n          secondaryLabel: 'Post a Wanted Ad',\n          onSecondary: widget.onWanted,\n        );\n      }\n      return MarketplaceDataStateView(\n        kind: MarketplaceDataStateKind.empty,\n        icon: wanted ? Icons.campaign_outlined : Icons.search_off_outlined,\n        title: wanted ? 'No wanted ads match' : 'No listings match your filters',\n        message: wanted\n            ? 'Adjust the filters or check additional pages for buyer requests.'\n            : 'Adjust the search or filters to broaden the Marketplace results.',\n        primaryLabel: _hasMore ? 'Search more listings' : null,\n        primaryIcon: Icons.expand_more_rounded,\n        onPrimary: _hasMore && !_loading ? _loadPage : null,\n      );\n    }`;
  text = replaceOnce(text, oldEmpty, newEmpty, "smart marketplace empty state");

  const heroStart = text.indexOf("              // Executive Hero Header Banner");
  const quickActions = text.indexOf("              _HomeQuickActions(", heroStart);
  if (heroStart < 0 || quickActions < 0) {
    if (!text.includes("const MarketplaceHomeWelcome()")) {
      throw new Error("Home hero replacement anchors were not found.");
    }
  } else {
    text = text.slice(0, heroStart) +
      "              const MarketplaceHomeWelcome(),\n              const SizedBox(height: 20),\n\n" +
      text.slice(quickActions);
  }

  const footerStart = text.indexOf("        railFooter: LayoutBuilder(");
  const actionsStart = text.indexOf("        actions: [", footerStart);
  if (footerStart < 0 || actionsStart < 0) {
    if (!text.includes("MarketplaceAccountMenuButton(")) {
      throw new Error("Rail footer replacement anchors were not found.");
    }
  } else {
    const footer = `        railFooter: LayoutBuilder(\n          builder: (context, constraints) {\n            final signedIn = FirebaseAuth.instance.currentUser != null;\n            final extended = constraints.maxWidth >= 180;\n            if (!signedIn) {\n              if (!extended) {\n                return IconButton(\n                  tooltip: 'Sign in',\n                  onPressed: _openAuth,\n                  icon: const Icon(Icons.login),\n                );\n              }\n              return OutlinedButton.icon(\n                onPressed: _openAuth,\n                icon: const Icon(Icons.login),\n                label: const Text('Sign in'),\n              );\n            }\n            return MarketplaceAccountMenuButton(\n              extended: extended,\n              onAccount: () => _selectTab(5),\n              onTrust: () => Navigator.of(context).push(\n                MaterialPageRoute(\n                  builder: (_) => const MarketplaceAccountSecurityPage(),\n                ),\n              ),\n              onMemberships: () => showDialog<void>(\n                context: context,\n                builder: (_) => const MarketplaceSubscriptionPlansDialog(),\n              ),\n              onSupport: () => Navigator.of(context).push(\n                MaterialPageRoute(\n                  builder: (_) => const MarketplaceSupportPage(),\n                ),\n              ),\n              onSignOut: _signOut,\n            );\n          },\n        ),\n`;
    text = text.slice(0, footerStart) + footer + text.slice(actionsStart);
  }

  const railAnchor = "        railLeading: Padding(\n";
  if (!text.includes("expandedRailNavigation: MarketplaceGroupedNavigation(")) {
    const grouped = `        expandedRailNavigation: MarketplaceGroupedNavigation(\n          selectedPageIndex: _tab,\n          marketplaceEnabled: _features.marketplace,\n          auctionsEnabled: _features.auctions,\n          dispatchEnabled: _features.dispatch,\n          onDestinationSelected: (target) {\n            if (target == 2) {\n              _openCreate();\n            } else if (target == 6) {\n              _selectControlledTab(target, _features.auctions, 'Auctions');\n            } else if (target == 7) {\n              _selectControlledTab(target, _features.dispatch, 'Dispatch');\n            } else {\n              _selectTab(target);\n            }\n          },\n          onWanted: () => _openCreate(wanted: true),\n        ),\n`;
    text = replaceOnce(text, railAnchor, grouped + railAnchor, "grouped expanded web navigation");
  }
  write(rel, text);
}

function patchAccountHub() {
  const rel = "lib/marketplace/marketplace_account_hub.dart";
  let text = read(rel);
  text = replaceOnce(
      text,
      "import 'marketplace_listing_media.dart';",
      "import 'marketplace_listing_media.dart';\n" +
      "import 'marketplace_listing_lifecycle.dart';\n" +
      "import 'marketplace_listing_insights.dart';",
      "account hub lifecycle imports",
  );

  const oldTime = `String _ownerListingTime(Map<String, dynamic> data, DateTime? createdAt) {\n  if (data['transactionType'] == 'Auction') {`;
  const newTime = `String _ownerListingTime(Map<String, dynamic> data, DateTime? createdAt) {\n  if (data['transactionType'] != 'Auction') {\n    final lifecycle = MarketplaceListingLifecycle.fromMap(data);\n    if (lifecycle.expiresAt != null || lifecycle.expired) {\n      return lifecycle.ownerLabel;\n    }\n  }\n  if (data['transactionType'] == 'Auction') {`;
  text = replaceOnce(text, oldTime, newTime, "owner listing lifecycle label");

  text = replaceOnce(
      text,
      "          if (createdAt != null)\n            Text(_ownerListingTime(data, createdAt),\n                style: const TextStyle(color: Colors.black54)),",
      "          if (createdAt != null)\n            Text(_ownerListingTime(data, createdAt),\n                style: const TextStyle(color: Colors.black54)),\n          if (!isAuction) ...[\n            const SizedBox(height: 7),\n            Align(\n              alignment: Alignment.centerLeft,\n              child: MarketplaceListingLifecyclePill(\n                data: data,\n                ownerView: true,\n              ),\n            ),\n          ],",
      "owner detail lifecycle pill",
  );

  text = replaceOnce(
      text,
      "      if (status == 'sold' || status == 'fulfilled' || status == 'archived')\n        FilledButton.icon(\n            onPressed: busy ? null : _relistListing,\n            icon: const Icon(Icons.refresh),\n            label: const Text('Relist as new')),",
      "      if (status == 'expired')\n        FilledButton.icon(\n            onPressed: busy ? null : _renewListing,\n            icon: const Icon(Icons.event_repeat_rounded),\n            label: const Text('Renew 30 days')),\n      if (status != 'expired')\n        OutlinedButton.icon(\n            onPressed: busy\n                ? null\n                : () => MarketplaceListingInsightsDialog.show(\n                      context,\n                      listingId: widget.listingId,\n                      listingTitle: String(data['title'] ?? 'Marketplace listing'),\n                    ),\n            icon: const Icon(Icons.auto_graph_rounded),\n            label: const Text('Smart suggestions')),\n      if (status == 'expired')\n        OutlinedButton.icon(\n            onPressed: busy\n                ? null\n                : () => MarketplaceListingInsightsDialog.show(\n                      context,\n                      listingId: widget.listingId,\n                      listingTitle: String(data['title'] ?? 'Marketplace listing'),\n                    ),\n            icon: const Icon(Icons.auto_graph_rounded),\n            label: const Text('Review suggestions')),\n      if (status == 'sold' || status == 'fulfilled' || status == 'archived')\n        FilledButton.icon(\n            onPressed: busy ? null : _relistListing,\n            icon: const Icon(Icons.refresh),\n            label: const Text('Relist as new')),",
      "expired renewal and smart suggestions",
  );

  const methodAnchor = "  Future<void> _relistListing() async {";
  if (!text.includes("Future<void> _renewListing()")) {
    const renewMethod = `  Future<void> _renewListing() async {\n    final confirmed = await showDialog<bool>(\n          context: context,\n          builder: (dialogContext) => AlertDialog(\n            title: const Text('Renew for another 30 days?'),\n            content: const Text(\n              'The same listing, saved links, history and analytics are retained. The listing becomes active for a new 30-day period.',\n            ),\n            actions: [\n              TextButton(\n                onPressed: () => Navigator.pop(dialogContext, false),\n                child: const Text('Cancel'),\n              ),\n              FilledButton(\n                onPressed: () => Navigator.pop(dialogContext, true),\n                child: const Text('Renew 30 days'),\n              ),\n            ],\n          ),\n        ) ??\n        false;\n    if (!confirmed || !mounted) return;\n    await _runListingCommand(\n      key: 'renew',\n      label: 'Renewing listing…',\n      command: 'renewMarketplaceListing',\n      data: {'listingId': widget.listingId},\n      success: 'Listing renewed for another 30 days.',\n    );\n  }\n\n`;
    text = replaceOnce(text, methodAnchor, renewMethod + methodAnchor, "renew listing method");
  }
  write(rel, text);
}

function patchInsightsLayout() {
  const rel = "lib/marketplace/marketplace_listing_insights.dart";
  let text = read(rel);
  text = text.replace(
    "crossAxisAlignment: CrossAxisAlignment.stretch,",
    "crossAxisAlignment: CrossAxisAlignment.start,",
  );
  write(rel, text);
}

patchIndex();
patchIndexes();
patchAdaptiveShell();
patchMarketplaceApp();
patchAccountHub();
patchInsightsLayout();

console.log("Listing lifecycle/navigation wiring completed.");
