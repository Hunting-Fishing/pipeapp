import 'package:flutter/material.dart';

import 'pipe_buyer_theme.dart';

/// Responsive listing-detail presentation primitives.
///
/// These components intentionally contain no marketplace commands, Firebase
/// reads, payment state, moderation, or Dispatch business logic. Existing
/// behavior owners supply the data and callbacks.
class PipeBuyerListingDetailShell extends StatelessWidget {
  const PipeBuyerListingDetailShell({
    super.key,
    required this.gallery,
    required this.summary,
    required this.details,
    this.sidebar,
    this.bottomContent,
    this.gap = 18,
  });

  final Widget gallery;
  final Widget summary;
  final Widget details;
  final Widget? sidebar;
  final Widget? bottomContent;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1120;
          final medium = constraints.maxWidth >= 760;

          if (wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [gallery, SizedBox(height: gap), details],
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          summary,
                          if (sidebar != null) ...[
                            SizedBox(height: gap),
                            sidebar!,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (bottomContent != null) ...[
                  SizedBox(height: gap),
                  bottomContent!,
                ],
              ],
            );
          }

          if (medium) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: gallery),
                    SizedBox(width: gap),
                    Expanded(flex: 4, child: summary),
                  ],
                ),
                SizedBox(height: gap),
                details,
                if (sidebar != null) ...[
                  SizedBox(height: gap),
                  sidebar!,
                ],
                if (bottomContent != null) ...[
                  SizedBox(height: gap),
                  bottomContent!,
                ],
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              gallery,
              SizedBox(height: gap),
              summary,
              SizedBox(height: gap),
              details,
              if (sidebar != null) ...[
                SizedBox(height: gap),
                sidebar!,
              ],
              if (bottomContent != null) ...[
                SizedBox(height: gap),
                bottomContent!,
              ],
            ],
          );
        },
      );
}

class PipeBuyerListingSummaryCard extends StatelessWidget {
  const PipeBuyerListingSummaryCard({
    super.key,
    required this.title,
    required this.price,
    required this.location,
    this.eyebrow,
    this.priceUnit,
    this.badges = const <Widget>[],
    this.metadata = const <Widget>[],
    this.actions = const <Widget>[],
    this.footer,
  });

  final String title;
  final String price;
  final String location;
  final String? eyebrow;
  final String? priceUnit;
  final List<Widget> badges;
  final List<Widget> metadata;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (eyebrow != null && eyebrow!.trim().isNotEmpty) ...[
              Text(
                eyebrow!.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: PipeBuyerColors.orangePressed,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (badges.isNotEmpty) ...[
              Wrap(spacing: 7, runSpacing: 7, children: badges),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.45,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    price,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.7,
                    ),
                  ),
                ),
                if (priceUnit != null && priceUnit!.trim().isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      priceUnit!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: .60),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 19,
                  color: PipeBuyerColors.orangePressed,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (metadata.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: metadata),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              for (var index = 0; index < actions.length; index++) ...[
                SizedBox(width: double.infinity, child: actions[index]),
                if (index != actions.length - 1) const SizedBox(height: 8),
              ],
            ],
            if (footer != null) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.colorScheme.outline),
              const SizedBox(height: 14),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class PipeBuyerListingActionBar extends StatelessWidget {
  const PipeBuyerListingActionBar({
    super.key,
    this.onMessage,
    this.onOffer,
    this.onQuote,
    this.onTrucking,
    this.offerLabel = 'Make an Offer',
    this.compact = false,
  });

  final VoidCallback? onMessage;
  final VoidCallback? onOffer;
  final VoidCallback? onQuote;
  final VoidCallback? onTrucking;
  final String offerLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (onMessage != null)
        FilledButton.icon(
          onPressed: onMessage,
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text('Message Seller'),
        ),
      if (onOffer != null)
        OutlinedButton.icon(
          onPressed: onOffer,
          icon: const Icon(Icons.handshake_outlined),
          label: Text(offerLabel),
        ),
      if (onQuote != null)
        OutlinedButton.icon(
          onPressed: onQuote,
          icon: const Icon(Icons.request_quote_outlined),
          label: const Text('Request Quote'),
        ),
      if (onTrucking != null)
        OutlinedButton.icon(
          onPressed: onTrucking,
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Get Trucking'),
        ),
    ];

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            actions[index],
            if (index != actions.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }
}

class PipeBuyerSpecItemData {
  const PipeBuyerSpecItemData({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;
}

class PipeBuyerSpecificationGrid extends StatelessWidget {
  const PipeBuyerSpecificationGrid({
    super.key,
    required this.items,
    this.title = 'Specifications',
  });

  final String title;
  final List<PipeBuyerSpecItemData> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 850
                    ? 3
                    : constraints.maxWidth >= 520
                        ? 2
                        : 1;
                const gap = 10.0;
                final width = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: items
                      .map(
                        (item) => SizedBox(
                          width: width,
                          child: _SpecificationCell(item: item),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PipeBuyerSellerTrustCard extends StatelessWidget {
  const PipeBuyerSellerTrustCard({
    super.key,
    required this.sellerName,
    this.location,
    this.verified = false,
    this.memberSince,
    this.responseTime,
    this.avatar,
    this.onViewProfile,
  });

  final String sellerName;
  final String? location;
  final bool verified;
  final String? memberSince;
  final String? responseTime;
  final Widget? avatar;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: PipeBuyerColors.orangeSoft,
                  child: avatar ??
                      const Icon(
                        Icons.business_outlined,
                        color: PipeBuyerColors.orangePressed,
                      ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sellerName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (verified) ...[
                        const SizedBox(height: 3),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: PipeBuyerColors.success,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verified Seller',
                              style: TextStyle(
                                color: PipeBuyerColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (location != null || memberSince != null || responseTime != null) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              if (location != null)
                _SellerMetaRow(
                  icon: Icons.location_on_outlined,
                  label: location!,
                ),
              if (memberSince != null)
                _SellerMetaRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Member since $memberSince',
                ),
              if (responseTime != null)
                _SellerMetaRow(
                  icon: Icons.schedule_outlined,
                  label: 'Response time $responseTime',
                ),
            ],
            if (onViewProfile != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onViewProfile,
                child: const Text('View Seller Profile'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PipeBuyerProtectionCard extends StatelessWidget {
  const PipeBuyerProtectionCard({
    super.key,
    this.title = 'Shop with Confidence',
    this.items = const <PipeBuyerProtectionItemData>[],
  });

  final String title;
  final List<PipeBuyerProtectionItemData> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 13),
            for (var index = 0; index < items.length; index++) ...[
              _ProtectionRow(item: items[index]),
              if (index != items.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class PipeBuyerProtectionItemData {
  const PipeBuyerProtectionItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _SpecificationCell extends StatelessWidget {
  const _SpecificationCell({required this.item});

  final PipeBuyerSpecItemData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.icon != null) ...[
            Icon(item.icon, size: 19, color: PipeBuyerColors.orangePressed),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .58),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerMetaRow extends StatelessWidget {
  const _SellerMetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: .52),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      );
}

class _ProtectionRow extends StatelessWidget {
  const _ProtectionRow({required this.item});

  final PipeBuyerProtectionItemData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: PipeBuyerColors.orangeSoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(item.icon, color: PipeBuyerColors.orangePressed, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: .60),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
