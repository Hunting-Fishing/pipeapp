import 'package:flutter/material.dart';

import 'pipe_buyer_theme.dart';

/// Adaptive shell for the Messages / Deal Room experience.
///
/// The caller owns conversation loading, offer commands, attachments,
/// inspection, payments, Dispatch actions and security enforcement.
class PipeBuyerDealRoomShell extends StatelessWidget {
  const PipeBuyerDealRoomShell({
    super.key,
    required this.conversations,
    required this.conversation,
    this.summary,
    this.mobileSummaryLabel = 'Deal Summary',
    this.onOpenSummary,
  });

  final Widget conversations;
  final Widget conversation;
  final Widget? summary;
  final String mobileSummaryLabel;
  final VoidCallback? onOpenSummary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1180 && summary != null) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 310, child: conversations),
                VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
                Expanded(child: conversation),
                VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
                SizedBox(width: 350, child: summary),
              ],
            );
          }

          if (constraints.maxWidth >= 760) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 300, child: conversations),
                VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: conversation),
                      if (summary != null && onOpenSummary != null)
                        Positioned(
                          right: 16,
                          top: 14,
                          child: FilledButton.tonalIcon(
                            onPressed: onOpenSummary,
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: Text(mobileSummaryLabel),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              Positioned.fill(child: conversation),
              if (summary != null && onOpenSummary != null)
                Positioned(
                  right: 12,
                  top: 10,
                  child: FilledButton.tonalIcon(
                    onPressed: onOpenSummary,
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text(mobileSummaryLabel),
                  ),
                ),
            ],
          );
        },
      );
}

class PipeBuyerConversationHeader extends StatelessWidget {
  const PipeBuyerConversationHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.avatar,
    this.online = false,
    this.listingContext,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final Widget? avatar;
  final bool online;
  final Widget? listingContext;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: PipeBuyerColors.orangeSoft,
                    child: avatar ??
                        const Icon(
                          Icons.business_outlined,
                          color: PipeBuyerColors.orangePressed,
                        ),
                  ),
                  if (online)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: PipeBuyerColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: .58),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions.isNotEmpty)
                Wrap(spacing: 2, runSpacing: 2, children: actions),
            ],
          ),
          if (listingContext != null) ...[
            const SizedBox(height: 12),
            listingContext!,
          ],
        ],
      ),
    );
  }
}

class PipeBuyerDealSummaryCard extends StatelessWidget {
  const PipeBuyerDealSummaryCard({
    super.key,
    required this.title,
    this.thumbnail,
    this.subtitle,
    this.rows = const <PipeBuyerDealRowData>[],
    this.sections = const <Widget>[],
    this.status,
  });

  final String title;
  final Widget? thumbnail;
  final String? subtitle;
  final List<PipeBuyerDealRowData> rows;
  final List<Widget> sections;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumbnail != null) ...[
                SizedBox(width: 82, height: 66, child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: thumbnail,
                )),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: .58),
                        ),
                      ),
                    ],
                    if (status != null) ...[
                      const SizedBox(height: 8),
                      status!,
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            for (final row in rows) _DealRow(data: row),
          ],
          if (sections.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var index = 0; index < sections.length; index++) ...[
              const SizedBox(height: 10),
              sections[index],
            ],
          ],
        ],
      ),
    );
  }
}

class PipeBuyerDealRowData {
  const PipeBuyerDealRowData({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;
}

class _DealRow extends StatelessWidget {
  const _DealRow({required this.data});

  final PipeBuyerDealRowData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              data.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: .60),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              data.value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: data.emphasize ? FontWeight.w900 : FontWeight.w800,
                color: data.emphasize ? PipeBuyerColors.orangePressed : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PipeBuyerOfferCard extends StatelessWidget {
  const PipeBuyerOfferCard({
    super.key,
    required this.title,
    required this.items,
    this.expiryLabel,
    this.onCounter,
    this.onAccept,
    this.onDecline,
    this.tone = PipeBuyerColors.orange,
  });

  final String title;
  final List<PipeBuyerDealRowData> items;
  final String? expiryLabel;
  final VoidCallback? onCounter;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: .32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.handshake_outlined, color: tone, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map(
                  (item) => Container(
                    constraints: const BoxConstraints(minWidth: 130),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: .55),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.value,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: item.emphasize ? tone : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          if (expiryLabel != null && expiryLabel!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule_outlined, size: 17, color: tone),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    expiryLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (onCounter != null || onAccept != null || onDecline != null) ...[
            const SizedBox(height: 13),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                final buttons = <Widget>[
                  if (onDecline != null)
                    TextButton(onPressed: onDecline, child: const Text('Decline')),
                  if (onCounter != null)
                    OutlinedButton(onPressed: onCounter, child: const Text('Counter Offer')),
                  if (onAccept != null)
                    FilledButton(onPressed: onAccept, child: const Text('Accept Offer')),
                ];
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < buttons.length; index++) ...[
                        buttons[index],
                        if (index != buttons.length - 1) const SizedBox(height: 7),
                      ],
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var index = 0; index < buttons.length; index++) ...[
                      buttons[index],
                      if (index != buttons.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class PipeBuyerDealStatusSection extends StatelessWidget {
  const PipeBuyerDealStatusSection({
    super.key,
    required this.title,
    required this.statusLabel,
    required this.child,
    this.icon = Icons.verified_user_outlined,
    this.tone = PipeBuyerColors.industrialBlue,
    this.action,
  });

  final String title;
  final String statusLabel;
  final Widget child;
  final IconData icon;
  final Color tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: tone),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: tone,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
          if (action != null) ...[
            const SizedBox(height: 10),
            action!,
          ],
        ],
      ),
    );
  }
}
