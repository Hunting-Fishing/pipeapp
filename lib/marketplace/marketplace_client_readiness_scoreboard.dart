import 'package:flutter/material.dart';

/// Client-facing project progress snapshot.
///
/// This screen is intentionally read-only. It does not query or mutate payment,
/// messaging, Dispatch, Marketplace, or release configuration. The values are a
/// dated project audit snapshot so they cannot be confused with live telemetry.
class MarketplaceClientReadinessScoreboard extends StatelessWidget {
  const MarketplaceClientReadinessScoreboard({super.key});

  static const auditDate = 'August 21, 2026';
  static const overallCompletion = 81;
  static const foundationCompletion = 95;
  static const softLaunchReadiness = 80;

  static const workstreams = <_ReadinessWorkstream>[
    _ReadinessWorkstream(
      title: 'Firebase / Backend / Security',
      percent: 95,
      status: _ReadinessStatus.substantiallyComplete,
      summary:
          'Authentication, Firestore, Storage, Functions, App Check, rules, emulator tooling and controlled release foundations are substantially built.',
      remaining:
          'Reconcile active branches, restore dependable CI execution, and rerun the exact release gate.',
    ),
    _ReadinessWorkstream(
      title: 'Accounts / Profiles / Admin',
      percent: 92,
      status: _ReadinessStatus.substantiallyComplete,
      summary:
          'Personal/business profiles, identity verification, MFA-capable admin access, recovery, deletion and export foundations are in place.',
      remaining:
          'Physical-device MFA acceptance and final multi-account soft-launch verification.',
    ),
    _ReadinessWorkstream(
      title: 'Marketplace / Listings',
      percent: 92,
      status: _ReadinessStatus.substantiallyComplete,
      summary:
          'Pipe, equipment, buildings, vehicles, listing lifecycle, media, saved listings and owner controls are substantially implemented.',
      remaining:
          'Reconcile the current behavior stack and finish formal UI integration and acceptance.',
    ),
    _ReadinessWorkstream(
      title: 'Search / Filters / Discovery',
      percent: 90,
      status: _ReadinessStatus.substantiallyComplete,
      summary:
          'Indexed search, structured filtering, sorting, pagination, map discovery and approximate geography are implemented.',
      remaining:
          'Radius/geospatial indexing, current backfill verification and representative-volume acceptance.',
    ),
    _ReadinessWorkstream(
      title: 'Wanted Ads / Smart Matching',
      percent: 90,
      status: _ReadinessStatus.substantiallyComplete,
      summary:
          'Wanted lifecycle, ranked matching, explainable scoring, privacy and notifications are substantially built.',
      remaining:
          'Match-quality review, saved structured criteria and full end-user acceptance.',
    ),
    _ReadinessWorkstream(
      title: 'Offers / Transactions',
      percent: 88,
      status: _ReadinessStatus.inProgress,
      summary:
          'Offer, counteroffer, acceptance, privacy, history and transaction-generation foundations are built.',
      remaining:
          'Reconcile Smart Offers, formal Deal Room integration and final settlement/device acceptance.',
    ),
    _ReadinessWorkstream(
      title: 'Messaging / Deal Room',
      percent: 85,
      status: _ReadinessStatus.inProgress,
      summary:
          'Conversations, listing context, notifications, attachment foundations and offer relationships are built.',
      remaining:
          'Reconcile PR #82 behavior, integrate the formal Deal Room from PR #84, and complete multi-user/mobile acceptance.',
      parallelNote:
          'Do not start a competing Messaging branch while PR #82 and PR #84 still own this surface.',
    ),
    _ReadinessWorkstream(
      title: 'Anti-Scam / Trust / Moderation',
      percent: 82,
      status: _ReadinessStatus.inProgress,
      summary:
          'Reporting, moderation commands, evidence, appeals, support cases and basic risk policy foundations are in place.',
      remaining:
          'Perceptual-image matching, cross-account/device signals, suspicious pricing and payment-risk scoring.',
    ),
    _ReadinessWorkstream(
      title: 'Trucking / Dispatch',
      percent: 82,
      status: _ReadinessStatus.inProgress,
      summary:
          'Requests, load board, providers, quotes, bids, awards, service areas and job lifecycle foundations are built.',
      remaining:
          'Routing acceptance, saved lanes, capacity matching, proof/signatures and final non-payment workflow acceptance.',
    ),
    _ReadinessWorkstream(
      title: 'Stripe / Payments / Tax',
      percent: 75,
      status: _ReadinessStatus.activeSeparateBranch,
      summary:
          'Stripe Billing, Connect, fee collection, webhooks, payment-readiness gates, refunds/disputes and tax controls have substantial foundations.',
      remaining:
          'Subscription lifecycle, reconciliation, tax readiness and controlled payment acceptance are being completed separately.',
      parallelNote:
          'ACTIVE SEPARATE WORKSTREAM — keep scoreboard changes out of payment files and PR #87.',
    ),
    _ReadinessWorkstream(
      title: 'Formal Product UI Integration',
      percent: 70,
      status: _ReadinessStatus.inProgress,
      summary:
          'Formal Home, Browse, Listing, Create Listing, Deal Room, Dispatch and Buyer/Seller Center components exist.',
      remaining:
          'Wire them around the reconciled behavior stack without replacing newer logic.',
    ),
    _ReadinessWorkstream(
      title: 'Mobile / Store Release',
      percent: 65,
      status: _ReadinessStatus.inProgress,
      summary:
          'Mobile layouts, release foundations and prior signed artifacts exist.',
      remaining:
          'Exact release-candidate builds, current physical-device acceptance and store submission/final release gates.',
    ),
    _ReadinessWorkstream(
      title: 'Analytics / Market Intelligence',
      percent: 48,
      status: _ReadinessStatus.future,
      summary:
          'Basic Marketplace analytics surfaces exist.',
      remaining:
          'Versioned definitions, server aggregation, data-quality tests, regional demand, price trends and seller conversion intelligence.',
    ),
    _ReadinessWorkstream(
      title: 'Verified Catalog Intelligence',
      percent: 46,
      status: _ReadinessStatus.future,
      summary:
          'Pipe/equipment data structures and some calculation foundations exist.',
      remaining:
          'Verified specifications, source attribution, confidence scoring, approval history and broad catalog coverage.',
    ),
    _ReadinessWorkstream(
      title: 'International Expansion',
      percent: 20,
      status: _ReadinessStatus.future,
      summary:
          'The architecture is intended for international growth and location/currency foundations have begun.',
      remaining:
          'Country-by-country tax, payments, legal terms, currencies, localization and regional operating rules.',
    ),
  ];

  static const nextPriorityOptions = <_PriorityOption>[
    _PriorityOption(
      rank: 1,
      title: 'Release-candidate reconciliation',
      description:
          'Resolve the active behavior stack and produce one exact, testable release candidate before adding broad new behavior.',
      state: 'Mandatory foundation',
    ),
    _PriorityOption(
      rank: 2,
      title: 'Messaging / Deal Room',
      description:
          'High customer value, but wait for PR #82 / PR #84 reconciliation before creating another implementation branch.',
      state: 'Queued behind active PRs',
    ),
    _PriorityOption(
      rank: 3,
      title: 'Mobile acceptance & soft launch',
      description:
          'Run real buyer, seller, carrier and administrator journeys on physical devices against the reconciled candidate.',
      state: 'Safe parallel planning',
    ),
    _PriorityOption(
      rank: 4,
      title: 'Advanced Anti-Scam / Trust',
      description:
          'Add image similarity, suspicious-price and relationship-risk intelligence after core release stability.',
      state: 'Independent future branch',
    ),
    _PriorityOption(
      rank: 5,
      title: 'Analytics / Market Intelligence',
      description:
          'Turn trusted Marketplace activity into client-facing demand, conversion and pricing intelligence.',
      state: 'Independent future branch',
    ),
  ];

  Color _statusColor(_ReadinessStatus status) => switch (status) {
        _ReadinessStatus.substantiallyComplete => const Color(0xFF15803D),
        _ReadinessStatus.inProgress => const Color(0xFFD97706),
        _ReadinessStatus.activeSeparateBranch => const Color(0xFF2563EB),
        _ReadinessStatus.future => const Color(0xFF64748B),
      };

  String _statusLabel(_ReadinessStatus status) => switch (status) {
        _ReadinessStatus.substantiallyComplete => 'SUBSTANTIALLY COMPLETE',
        _ReadinessStatus.inProgress => 'IN PROGRESS',
        _ReadinessStatus.activeSeparateBranch => 'ACTIVE SEPARATE BRANCH',
        _ReadinessStatus.future => 'FUTURE / NOT COMPLETE',
      };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F7FA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 980;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              desktop ? 28 : 16,
              20,
              desktop ? 28 : 16,
              40,
            ),
            children: [
              _hero(context),
              const SizedBox(height: 18),
              _summaryMetrics(desktop),
              const SizedBox(height: 18),
              _parallelWorkBanner(context),
              const SizedBox(height: 26),
              _sectionHeader(
                context,
                title: 'Project workstream scoreboard',
                subtitle:
                    'Audit snapshot, not live telemetry. Percentages are working estimates based on implemented behavior, verification and remaining launch acceptance.',
                icon: Icons.scoreboard_outlined,
              ),
              const SizedBox(height: 12),
              ...workstreams.map(
                (workstream) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _workstreamCard(context, workstream),
                ),
              ),
              const SizedBox(height: 16),
              _sectionHeader(
                context,
                title: 'Recommended client priority order',
                subtitle:
                    'These are intentionally sequenced to reduce merge collisions and avoid destabilizing payment work.',
                icon: Icons.low_priority_outlined,
              ),
              const SizedBox(height: 12),
              ...nextPriorityOptions.map(
                (priority) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _priorityCard(context, priority),
                ),
              ),
              const SizedBox(height: 18),
              _definitionOfDone(context),
            ],
          );
        },
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF263445)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Pill(
                label: 'CLIENT-READY PROJECT SNAPSHOT',
                icon: Icons.fact_check_outlined,
                color: Color(0xFFFF6A00),
              ),
              const SizedBox(height: 14),
              Text(
                'Pipe Buyer Launch Readiness',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A simple view of what is substantially complete, what is still being integrated, and where the client can choose the next investment priority.',
                style: TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 12),
              const Text(
                'Audit date: $auditDate',
                style: TextStyle(
                  color: Color(0xFFFFB47A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );

          final gauge = Container(
            width: compact ? double.infinity : 190,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: const Column(
              children: [
                Text(
                  '$overallCompletion%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Overall current project estimate',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.3),
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 18), gauge],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              const SizedBox(width: 22),
              gauge,
            ],
          );
        },
      ),
    );
  }

  Widget _summaryMetrics(bool desktop) {
    const cards = [
      _Metric(
        label: 'Overall project',
        value: '$overallCompletion%',
        caption: 'Current working estimate',
        icon: Icons.donut_large_outlined,
      ),
      _Metric(
        label: 'Core foundation',
        value: '$foundationCompletion%',
        caption: 'Backend / platform foundation',
        icon: Icons.foundation_outlined,
      ),
      _Metric(
        label: 'Soft-launch readiness',
        value: '~$softLaunchReadiness%',
        caption: 'Controlled colleague testing',
        icon: Icons.rocket_launch_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = desktop
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((metric) => SizedBox(width: width, child: _metricCard(metric)))
              .toList(growable: false),
        );
      },
    );
  }

  Widget _metricCard(_Metric metric) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEE2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(metric.icon, color: const Color(0xFFE85D00)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric.label,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  metric.value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  metric.caption,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _parallelWorkBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.call_split_outlined, color: Color(0xFF2563EB)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Parallel work rule: Stripe / Payments / Tax is being completed in its own branch. This scoreboard is deliberately read-only and must not change payment commands, Stripe configuration, webhooks, tax policy, Messaging behavior, or Dispatch behavior.',
              style: TextStyle(height: 1.45, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFE85D00)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _workstreamCard(BuildContext context, _ReadinessWorkstream workstream) {
    final color = _statusColor(workstream.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  workstream.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${workstream.percent}%',
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: workstream.percent / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
            color: color,
            backgroundColor: color.withValues(alpha: .10),
          ),
          const SizedBox(height: 10),
          _Pill(
            label: _statusLabel(workstream.status),
            icon: workstream.status == _ReadinessStatus.substantiallyComplete
                ? Icons.check_circle_outline
                : workstream.status == _ReadinessStatus.activeSeparateBranch
                    ? Icons.call_split_outlined
                    : workstream.status == _ReadinessStatus.future
                        ? Icons.schedule_outlined
                        : Icons.construction_outlined,
            color: color,
          ),
          const SizedBox(height: 12),
          Text(workstream.summary, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 8),
          Text(
            'Remaining: ${workstream.remaining}',
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          if (workstream.parallelNote != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                workstream.parallelNote!,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priorityCard(BuildContext context, _PriorityOption priority) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${priority.rank}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  priority.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(priority.description,
                    style: const TextStyle(height: 1.4)),
                const SizedBox(height: 8),
                Text(
                  priority.state,
                  style: const TextStyle(
                    color: Color(0xFFE85D00),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _definitionOfDone(BuildContext context) {
    const items = [
      'One reconciled release candidate is identified by exact commit SHA.',
      'Automated Flutter/Firebase gates pass or a documented infrastructure blocker is recorded.',
      'Buyer, seller, Messaging, Dispatch and administrator journeys pass controlled acceptance.',
      'Payment work remains governed by its separate readiness and reconciliation gates.',
      'Every material repair records root cause, exact fix, verification and commit/PR.',
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Soft-launch definition of done',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFFFF6A00),
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ReadinessStatus {
  substantiallyComplete,
  inProgress,
  activeSeparateBranch,
  future,
}

class _ReadinessWorkstream {
  const _ReadinessWorkstream({
    required this.title,
    required this.percent,
    required this.status,
    required this.summary,
    required this.remaining,
    this.parallelNote,
  });

  final String title;
  final int percent;
  final _ReadinessStatus status;
  final String summary;
  final String remaining;
  final String? parallelNote;
}

class _PriorityOption {
  const _PriorityOption({
    required this.rank,
    required this.title,
    required this.description,
    required this.state,
  });

  final int rank;
  final String title;
  final String description;
  final String state;
}

class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
