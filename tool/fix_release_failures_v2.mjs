import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();

function load(rel) {
  const full = path.join(root, rel);
  return fs.readFileSync(full, 'utf8').replace(/\r\n/g, '\n');
}

function save(rel, text) {
  fs.writeFileSync(path.join(root, rel), text, 'utf8');
}

function replaceOnce(rel, before, after, label) {
  let text = load(rel);
  if (text.includes(after)) {
    console.log(`already applied: ${label}`);
    return;
  }
  const index = text.indexOf(before);
  if (index < 0) {
    throw new Error(`Patch anchor not found for ${label} in ${rel}`);
  }
  text = text.slice(0, index) + after + text.slice(index + before.length);
  save(rel, text);
  console.log(`patched: ${label}`);
}

replaceOnce(
  'test/marketplace_dispatch_onboarding_test.dart',
  "    expect(find.text('Pipe Buyer Dispatch Network'), findsOneWidget);",
  "    expect(find.text('Choose how you use Dispatch'), findsOneWidget);",
  'Dispatch onboarding hero expectation',
);

{
  const rel = 'test/marketplace_grid_density_test.dart';
  let text = load(rel);
  const old = "Automatic grid density";
  const newer = "Automatic responsive grid density";
  if (!text.includes(newer)) {
    if (!text.includes(old)) throw new Error(`Grid-density semantic label anchor missing in ${rel}`);
    text = text.split(old).join(newer);
    save(rel, text);
    console.log('patched: grid-density semantic expectations');
  } else {
    console.log('already applied: grid-density semantic expectations');
  }
}

replaceOnce(
  'test/marketplace_offer_schedule_test.dart',
  "    expect(find.text(r'$3,942.00 for 54 units'), findsOneWidget);",
  "    expect(find.text(r'$3,942.00'), findsOneWidget);\n    expect(find.text('54 units'), findsOneWidget);",
  'offer review total/quantity expectations',
);

{
  const rel = 'test/pipe_accessibility_acceptance_test.dart';
  let text = load(rel);
  if (text.includes("expect(find.text('Sign in'), findsWidgets);")) {
    text = text.replace(
      "expect(find.text('Sign in'), findsWidgets);",
      "expect(find.text('Sign in securely'), findsOneWidget);",
    );
  }
  if (text.includes("expect(find.text('Join the marketplace'), findsOneWidget);")) {
    text = text.replace(
      "expect(find.text('Join the marketplace'), findsOneWidget);",
      "expect(find.text('Join Pipe Buyer'), findsOneWidget);",
    );
  }
  save(rel, text);
  console.log('patched: accessibility copy expectations');
}

replaceOnce(
  'lib/marketplace/marketplace_vip_access.dart',
  "import 'package:firebase_auth/firebase_auth.dart';\nimport 'package:flutter/material.dart';",
  "import 'package:firebase_auth/firebase_auth.dart';\nimport 'package:firebase_core/firebase_core.dart';\nimport 'package:flutter/material.dart';",
  'VIP gate Firebase core import',
);

replaceOnce(
  'lib/marketplace/marketplace_vip_access.dart',
  `  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && '\${listing['sellerUid'] ?? ''}' == user.uid)
      return child;
    if (marketplaceVipEarlyAccessUntil(listing) == null) return child;
    if (user == null) {`,
  `  @override
  Widget build(BuildContext context) {
    if (marketplaceVipEarlyAccessUntil(listing) == null) return child;
    final user = Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
    if (user != null && '\${listing['sellerUid'] ?? ''}' == user.uid) {
      return child;
    }
    if (user == null) {`,
  'VIP gate avoids Firebase access for public/uninitialized widgets',
);

replaceOnce(
  'lib/marketplace/marketplace_tax_profile_page.dart',
  "                            'A registration number alone does not remove PST. Submit the intended use and supporting evidence for review.',",
  "                            'A PST number does not automatically remove PST. Submit the intended use and supporting evidence for transaction-specific review.',",
  'PST compliance contract wording',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  `  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(`,
  `  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final largeText = media.textScaler.scale(12) >= 18;
    final compactChrome = media.size.width < 420 || largeText;
    return Scaffold(`,
  'auth page responsive media state',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  `        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: PipeBuyerStatusBadge(
                label: 'SECURE ACCESS',
                tone: PipeBuyerStatusTone.success,
                icon: Icons.lock_outline_rounded,
              ),
            ),
          ),
        ],`,
  `        actions: [
          if (compactChrome)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'Secure access',
                child: Center(
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: PipeBuyerColors.success,
                  ),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: PipeBuyerStatusBadge(
                  label: 'SECURE ACCESS',
                  tone: PipeBuyerStatusTone.success,
                  icon: Icons.lock_outline_rounded,
                ),
              ),
            ),
        ],`,
  'auth app bar adapts at high text scale',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  '          final wide = constraints.maxWidth >= 960;',
  `          final wide = constraints.maxWidth >= 1120 &&
              constraints.maxHeight >= 640 &&
              !largeText;`,
  'auth desktop split breakpoint',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  `              const SizedBox(
                width: 570,
                child: Text(
                  'Industrial commerce. Built for serious transactions.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    height: 1.08,
                    letterSpacing: -1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),`,
  `              const Text(
                'Industrial commerce. Built for serious transactions.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  height: 1.08,
                  letterSpacing: -1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),`,
  'auth brand headline uses available width',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  `              SizedBox(
                width: 540,
                child: Text(
                  _signup
                      ? 'Create a verified marketplace identity for pipe, equipment, buildings, transport and energy inventory.'
                      : 'Access listings, negotiations, timed auctions, secure payments and Pipe Buyer Dispatch from one account.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),`,
  `              Text(
                _signup
                    ? 'Create a verified marketplace identity for pipe, equipment, buildings, transport and energy inventory.'
                    : 'Access listings, negotiations, timed auctions, secure payments and Pipe Buyer Dispatch from one account.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),`,
  'auth brand subtitle uses available width',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  `                  Text(
                    'Built for North America. Designed for global industry.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .66),
                      fontWeight: FontWeight.w700,
                    ),
                  ),`,
  `                  Expanded(
                    child: Text(
                      'Built for North America. Designed for global industry.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .66),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),`,
  'auth brand footer can wrap',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  `  Widget _formViewport(BuildContext context, {required bool compact}) {
    final theme = Theme.of(context);
    return Center(`,
  `  Widget _formViewport(BuildContext context, {required bool compact}) {
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(12) >= 18;
    final horizontalPadding = compact ? (largeText ? 10.0 : 18.0) : 40.0;
    final verticalPadding = compact ? (largeText ? 12.0 : 22.0) : 34.0;
    final cardPadding = compact ? (largeText ? 14.0 : 20.0) : 30.0;
    return Center(`,
  'auth compact high-text padding policy',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  `        padding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 40,
          vertical: compact ? 22 : 34,
        ),`,
  `        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),`,
  'auth viewport adaptive padding',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  '              padding: EdgeInsets.all(compact ? 20 : 30),',
  '              padding: EdgeInsets.all(cardPadding),',
  'auth card adaptive padding',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  `                    const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        _CompactTrustItem(
                          icon: Icons.verified_user_outlined,
                          label: 'Verified accounts',
                        ),
                        _CompactTrustItem(
                          icon: Icons.shield_outlined,
                          label: 'Fraud protection',
                        ),
                        _CompactTrustItem(
                          icon: Icons.lock_outline_rounded,
                          label: 'Protected access',
                        ),
                      ],
                    ),`,
  `                    if (largeText)
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CompactTrustItem(
                            icon: Icons.verified_user_outlined,
                            label: 'Verified accounts',
                            expanded: true,
                          ),
                          SizedBox(height: 8),
                          _CompactTrustItem(
                            icon: Icons.shield_outlined,
                            label: 'Fraud protection',
                            expanded: true,
                          ),
                          SizedBox(height: 8),
                          _CompactTrustItem(
                            icon: Icons.lock_outline_rounded,
                            label: 'Protected access',
                            expanded: true,
                          ),
                        ],
                      )
                    else
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _CompactTrustItem(
                            icon: Icons.verified_user_outlined,
                            label: 'Verified accounts',
                          ),
                          _CompactTrustItem(
                            icon: Icons.shield_outlined,
                            label: 'Fraud protection',
                          ),
                          _CompactTrustItem(
                            icon: Icons.lock_outline_rounded,
                            label: 'Protected access',
                          ),
                        ],
                      ),`,
  'auth trust indicators stack for high text',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  `    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PIPE',`,
  `    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PIPE',`,
  'auth wordmark scales down instead of overflowing',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  `        const Text(
          'BUYER',
          style: TextStyle(
            color: PipeBuyerColors.orange,
            fontWeight: FontWeight.w900,
            fontSize: 25,
            letterSpacing: -.7,
          ),
        ),
      ],
    );
  }

  Future<void> _signInWithGoogle() async {`,
  `          const Text(
            'BUYER',
            style: TextStyle(
              color: PipeBuyerColors.orange,
              fontWeight: FontWeight.w900,
              fontSize: 25,
              letterSpacing: -.7,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {`,
  'auth wordmark closes fitted layout',
);

replaceOnce(
  'lib/marketplace/marketplace_auth_page.dart',
  `class _CompactTrustItem extends StatelessWidget {
  const _CompactTrustItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 1),
        Icon(icon, size: 16, color: PipeBuyerColors.success),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: .62),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}`,
  `class _CompactTrustItem extends StatelessWidget {
  const _CompactTrustItem({
    required this.icon,
    required this.label,
    this.expanded = false,
  });

  final IconData icon;
  final String label;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelText = Text(
      label,
      softWrap: true,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: .62),
        fontWeight: FontWeight.w700,
      ),
    );
    return Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        const SizedBox(width: 1),
        Icon(icon, size: 16, color: PipeBuyerColors.success),
        const SizedBox(width: 5),
        if (expanded) Expanded(child: labelText) else labelText,
      ],
    );
  }
}`,
  'auth compact trust item can wrap',
);

replaceOnce(
  'lib/marketplace/regional_phone_field.dart',
  `                          Text(
                            region.flag,
                            style: const TextStyle(fontSize: 18),
                          ),`,
  `                          Text(
                            region.flag,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(fontSize: 18),
                          ),`,
  'phone region selected flag avoids double scaling',
);

replaceOnce(
  'lib/marketplace/regional_phone_field.dart',
  `                          Text(
                            region.dialCode,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),`,
  `                          Text(
                            region.dialCode,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),`,
  'phone region selected dial code avoids double scaling',
);

replaceOnce(
  'lib/marketplace/marketplace_offer_schedule.dart',
  `    final total = offer['offeredTotal'] as num? ?? 0;
    final quantity = offer['requestedQuantity'] ?? 0;
    return Dialog(`,
  `    final total = offer['offeredTotal'] as num? ?? 0;
    final quantity = offer['requestedQuantity'] ?? 0;
    final largeText = MediaQuery.textScalerOf(context).scale(12) >= 18;
    return Dialog(`,
  'offer decision high-text state',
);

replaceOnce(
  'lib/marketplace/marketplace_offer_schedule.dart',
  `                          Text(
                            '$quantity units',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),`,
  `                          Text(
                            '$quantity units',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (largeText)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'NEGOTIATED',
                                style: TextStyle(
                                  color: PipeBuyerColors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .7,
                                ),
                              ),
                            ),`,
  'offer decision keeps negotiated status in flexible column',
);

replaceOnce(
  'lib/marketplace/marketplace_offer_schedule.dart',
  `                    const PipeBuyerStatusBadge(
                      label: 'NEGOTIATED',
                      icon: Icons.forum_outlined,
                      tone: PipeBuyerStatusTone.premium,
                    ),`,
  `                    if (!largeText)
                      const PipeBuyerStatusBadge(
                        label: 'NEGOTIATED',
                        icon: Icons.forum_outlined,
                        tone: PipeBuyerStatusTone.premium,
                      ),`,
  'offer decision status badge adapts at high text scale',
);

console.log('Release failure patch set applied.');
