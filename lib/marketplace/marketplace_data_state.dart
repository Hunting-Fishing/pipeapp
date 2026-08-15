import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';

enum MarketplaceDataStateKind {
  loading,
  empty,
  offline,
  unavailable,
  error,
}

@immutable
class MarketplaceFailurePresentation {
  const MarketplaceFailurePresentation({
    required this.kind,
    required this.title,
    required this.message,
  });

  final MarketplaceDataStateKind kind;
  final String title;
  final String message;
}

MarketplaceFailurePresentation marketplaceFailurePresentation(
  Object? error, {
  required String resource,
}) {
  final code = error is FirebaseException ? error.code.toLowerCase() : '';
  if (const {
    'cancelled',
    'deadline-exceeded',
    'network-request-failed',
    'unavailable',
  }.contains(code)) {
    return MarketplaceFailurePresentation(
      kind: MarketplaceDataStateKind.offline,
      title: 'Connection interrupted',
      message:
          '$resource could not be refreshed. Check your connection and try again.',
    );
  }
  if (const {'permission-denied', 'unauthenticated'}.contains(code)) {
    return MarketplaceFailurePresentation(
      kind: MarketplaceDataStateKind.unavailable,
      title: 'Access needs attention',
      message:
          '$resource is unavailable for this account. Refresh your account or sign in again.',
    );
  }
  if (code == 'failed-precondition') {
    return MarketplaceFailurePresentation(
      kind: MarketplaceDataStateKind.unavailable,
      title: '$resource is preparing',
      message: 'This service is not ready yet. Wait a moment and try again.',
    );
  }
  return MarketplaceFailurePresentation(
    kind: MarketplaceDataStateKind.error,
    title: '$resource could not be loaded',
    message:
        'Nothing was changed. Try again, or return later if this continues.',
  );
}

class MarketplaceDataStateView extends StatelessWidget {
  const MarketplaceDataStateView({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.icon,
    this.primaryLabel,
    this.onPrimary,
    this.primaryIcon,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
  });

  const MarketplaceDataStateView.loading({
    super.key,
    this.title = 'Loading',
    this.message = 'Retrieving the latest information…',
    this.compact = false,
  })  : kind = MarketplaceDataStateKind.loading,
        icon = Icons.cloud_sync_outlined,
        primaryLabel = null,
        onPrimary = null,
        primaryIcon = null,
        secondaryLabel = null,
        onSecondary = null;

  factory MarketplaceDataStateView.failure({
    Key? key,
    required Object? error,
    required String resource,
    VoidCallback? onRetry,
    String retryLabel = 'Try again',
    bool compact = false,
  }) {
    final presentation = marketplaceFailurePresentation(
      error,
      resource: resource,
    );
    return MarketplaceDataStateView(
      key: key,
      kind: presentation.kind,
      title: presentation.title,
      message: presentation.message,
      primaryLabel: retryLabel,
      onPrimary: onRetry,
      primaryIcon: Icons.refresh,
      compact: compact,
    );
  }

  final MarketplaceDataStateKind kind;
  final String title;
  final String message;
  final IconData? icon;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final IconData? primaryIcon;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool compact;

  bool get _announce =>
      kind != MarketplaceDataStateKind.empty &&
      kind != MarketplaceDataStateKind.loading;

  IconData get _resolvedIcon =>
      icon ??
      switch (kind) {
        MarketplaceDataStateKind.loading => Icons.cloud_sync_outlined,
        MarketplaceDataStateKind.empty => Icons.inventory_2_outlined,
        MarketplaceDataStateKind.offline => Icons.cloud_off_outlined,
        MarketplaceDataStateKind.unavailable => Icons.lock_clock_outlined,
        MarketplaceDataStateKind.error => Icons.sync_problem_outlined,
      };

  Color _accent(BuildContext context) => switch (kind) {
        MarketplaceDataStateKind.loading => PipeBuyerColors.orange,
        MarketplaceDataStateKind.empty => PipeBuyerColors.industrialBlue,
        MarketplaceDataStateKind.offline => PipeBuyerColors.warning,
        MarketplaceDataStateKind.unavailable => PipeBuyerColors.slate,
        MarketplaceDataStateKind.error => Theme.of(context).colorScheme.error,
      };

  String get _eyebrow => switch (kind) {
        MarketplaceDataStateKind.loading => 'SYNCING',
        MarketplaceDataStateKind.empty => 'NOTHING HERE YET',
        MarketplaceDataStateKind.offline => 'CONNECTION',
        MarketplaceDataStateKind.unavailable => 'ACCESS',
        MarketplaceDataStateKind.error => 'RETRY NEEDED',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accent(context);
    final padding = compact ? 14.0 : 24.0;
    final iconSize = compact ? 42.0 : 58.0;

    final content = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: accent),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              padding + 4,
              padding,
              padding,
              padding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(compact ? 13 : 17),
                    border: Border.all(
                      color: accent.withValues(alpha: .22),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: kind == MarketplaceDataStateKind.loading
                      ? SizedBox.square(
                          dimension: compact ? 24 : 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: accent,
                          ),
                        )
                      : Icon(
                          _resolvedIcon,
                          size: compact ? 24 : 30,
                          color: accent,
                        ),
                ),
                SizedBox(height: compact ? 10 : 14),
                Text(
                  _eyebrow,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: (compact
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.titleLarge)
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .66),
                    height: 1.42,
                  ),
                ),
                if (onPrimary != null && primaryLabel != null) ...[
                  SizedBox(height: compact ? 10 : 16),
                  FilledButton.icon(
                    onPressed: onPrimary,
                    icon: Icon(primaryIcon ?? Icons.arrow_forward_rounded),
                    label: Text(primaryLabel!),
                  ),
                ],
                if (onSecondary != null && secondaryLabel != null) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      liveRegion: _announce,
      label: '$title. $message',
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 8 : 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 480 : 540),
            child: content,
          ),
        ),
      ),
    );
  }
}
