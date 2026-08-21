import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_dispatch_subscription_billing.dart';

class MarketplaceDispatchOnboarding extends StatelessWidget {
  const MarketplaceDispatchOnboarding({
    super.key,
    required this.onPostLoad,
    required this.onBrowseJobs,
    required this.onJoinCarrier,
  });

  final VoidCallback onPostLoad;
  final VoidCallback onBrowseJobs;
  final VoidCallback onJoinCarrier;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          children: [
            _hero(context),
            const SizedBox(height: 22),
            const PipeBuyerPageHeader(
              eyebrow: 'Dispatch Network',
              title: 'Choose how you use Dispatch',
              subtitle:
                  'Post industrial freight or join the network as a transportation provider.',
              icon: Icons.route_outlined,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 820;
                final width = wide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: _AudienceCard(
                        icon: Icons.add_road_outlined,
                        eyebrow: 'SHIPPER / CUSTOMER',
                        title: 'Request trucking service',
                        description:
                            'Post a load for pipe, equipment, buildings, vehicles, or field freight. Add pickup, delivery, timing, weight, and load details so qualified providers can respond.',
                        actionLabel: 'Post a load request',
                        onPressed: onPostLoad,
                        tone: PipeBuyerStatusTone.premium,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _AudienceCard(
                        icon: Icons.local_shipping_outlined,
                        eyebrow: 'CARRIER / SERVICE PROVIDER',
                        title: 'Offer trucking services',
                        description:
                            'Join the Dispatch network as a carrier, hotshot operator, pilot-car provider, equipment hauler, towing company, or oilfield service transporter.',
                        actionLabel: 'Join the Dispatch network',
                        onPressed: onJoinCarrier,
                        tone: PipeBuyerStatusTone.info,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const PipeBuyerPageHeader(
              eyebrow: 'Workflow',
              title: 'How Dispatch works',
              subtitle:
                  'A transparent job flow from load request through quote, award, coordination, and completion.',
              icon: Icons.alt_route_outlined,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1050
                    ? 4
                    : constraints.maxWidth >= 620
                        ? 2
                        : 1;
                final width =
                    (constraints.maxWidth - ((columns - 1) * 10)) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StepCard(
                      width: width,
                      number: '01',
                      icon: Icons.assignment_outlined,
                      title: 'Publish or match',
                      description:
                          'Customers publish a trucking request. Network providers receive opportunities matching their services and operating areas.',
                    ),
                    _StepCard(
                      width: width,
                      number: '02',
                      icon: Icons.request_quote_outlined,
                      title: 'Review and quote',
                      description:
                          'Providers review the route and load, then submit a quote. No job is accepted automatically.',
                    ),
                    _StepCard(
                      width: width,
                      number: '03',
                      icon: Icons.fact_check_outlined,
                      title: 'Customer approves',
                      description:
                          'The customer compares responses and selects a provider. Both sides receive the award and scheduling details.',
                    ),
                    _StepCard(
                      width: width,
                      number: '04',
                      icon: Icons.forum_outlined,
                      title: 'Coordinate the job',
                      description:
                          'Use in-app messages and Dispatch notifications for updates, pickup coordination, route changes, and completion records.',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            PipeBuyerMetricGrid(
              children: const [
                PipeBuyerMetricCard(
                  label: 'Load types',
                  value: 'Industrial',
                  icon: Icons.precision_manufacturing_outlined,
                  caption: 'Pipe, equipment, buildings, vehicles and field freight',
                  tone: PipeBuyerStatusTone.premium,
                ),
                PipeBuyerMetricCard(
                  label: 'Provider network',
                  value: 'Flexible',
                  icon: Icons.local_shipping_outlined,
                  caption: 'Carrier, hotshot, hauling, towing and escort services',
                  tone: PipeBuyerStatusTone.info,
                ),
                PipeBuyerMetricCard(
                  label: 'Job records',
                  value: 'In-app',
                  icon: Icons.fact_check_outlined,
                  caption: 'Quotes, messages, awards and completion activity',
                  tone: PipeBuyerStatusTone.success,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _pricingCard(context),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 820;
                final notifications = _notificationsCard(context);
                final requirements = _carrierRequirementsCard(context);
                if (!wide) {
                  return Column(
                    children: [
                      notifications,
                      const SizedBox(height: 12),
                      requirements,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: notifications),
                    const SizedBox(width: 12),
                    Expanded(child: requirements),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _trustCard(context),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -72,
            top: -90,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PipeBuyerColors.orange.withValues(alpha: .08),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -34,
            child: Icon(
              Icons.local_shipping_outlined,
              size: 190,
              color: Colors.white.withValues(alpha: .035),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 6, color: PipeBuyerColors.orange),
          ),
          Padding(
            padding: const EdgeInsets.all(26),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PipeBuyerStatusBadge(
                      label: 'PIPE BUYER DISPATCH',
                      icon: Icons.route_outlined,
                      tone: PipeBuyerStatusTone.premium,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Move oilfield and industrial freight with fewer phone calls.',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                height: 1.08,
                              ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Request transportation or offer professional trucking services for oilfield, industrial, construction, agricultural, and remote-site freight.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: onPostLoad,
                          icon: const Icon(Icons.add_road_outlined),
                          label: const Text('Request a truck'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                          ),
                          onPressed: onJoinCarrier,
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: const Text('Offer services'),
                        ),
                        TextButton.icon(
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.white),
                          onPressed: onBrowseJobs,
                          icon: const Icon(Icons.search_outlined),
                          label: const Text('Browse jobs'),
                        ),
                      ],
                    ),
                  ],
                );

                final art = Container(
                  width: 220,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 34,
                        left: 26,
                        child: Icon(
                          Icons.location_on,
                          color: PipeBuyerColors.orange,
                          size: 34,
                        ),
                      ),
                      Positioned(
                        bottom: 30,
                        right: 28,
                        child: Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      Icon(
                        Icons.route_outlined,
                        size: 86,
                        color: Colors.white70,
                      ),
                      Positioned(
                        bottom: 20,
                        left: 28,
                        child: Icon(
                          Icons.local_shipping_outlined,
                          size: 48,
                          color: PipeBuyerColors.orange,
                        ),
                      ),
                    ],
                  ),
                );

                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      copy,
                      const SizedBox(height: 18),
                      art,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 28),
                    art,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricingCard(BuildContext context) {
    return const MarketplaceDispatchSubscriptionBilling();
  }

  Widget _notificationsCard(BuildContext context) {
    return const PipeBuyerSectionCard(
      title: 'Dispatch notifications',
      subtitle: 'Stay informed without relying on phone calls and text chains.',
      leading: _SectionIcon(
        Icons.notifications_active_outlined,
        tone: PipeBuyerStatusTone.info,
      ),
      child: Text(
        'In-app notifications can alert providers to matching opportunities, new messages, quote changes, job awards, schedule updates, and completion activity. Browser push notifications are optional and appear only when the current web release is configured and the user grants permission.',
      ),
    );
  }

  Widget _carrierRequirementsCard(BuildContext context) {
    return PipeBuyerSectionCard(
      title: 'Carrier profile requirements',
      subtitle: 'Publish enough operating detail for customers to make a decision.',
      leading: const _SectionIcon(
        Icons.verified_user_outlined,
        tone: PipeBuyerStatusTone.success,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Providers identify their service areas, equipment, payload limits, insurance and operating details. Job-specific permits, licensing, hours-of-service, escort, and safety requirements remain the provider’s responsibility.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onJoinCarrier,
                icon: const Icon(Icons.app_registration_outlined),
                label: const Text('Start carrier signup'),
              ),
              OutlinedButton.icon(
                onPressed: onBrowseJobs,
                icon: const Icon(Icons.search_outlined),
                label: const Text('View open jobs'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trustCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PipeBuyerColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final trustPoints = [
            const _TrustPoint(
              icon: Icons.forum_outlined,
              title: 'Keep coordination in-app',
              text: 'Messages and job activity stay easier to reference.',
            ),
            const _TrustPoint(
              icon: Icons.request_quote_outlined,
              title: 'Compare quotes',
              text: 'A posted request does not automatically award a carrier.',
            ),
            const _TrustPoint(
              icon: Icons.fact_check_outlined,
              title: 'Record completion activity',
              text: 'Job status and completion records remain tied to Dispatch.',
            ),
          ];
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'A clearer record for both sides',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                ...trustPoints.expand(
                  (point) => [point, const SizedBox(height: 12)],
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 220,
                child: Text(
                  'A clearer record for both sides',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              ...trustPoints.expand(
                (point) => [
                  Expanded(child: point),
                  const SizedBox(width: 12),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AudienceCard extends StatelessWidget {
  const _AudienceCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
    required this.tone,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;
  final PipeBuyerStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = pipeBuyerToneColor(tone);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 27),
              ),
              const SizedBox(height: 16),
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.48,
                    ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.width,
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  final double width;
  final String number;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.orangeSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        number,
                        style: const TextStyle(
                          color: PipeBuyerColors.orangePressed,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(icon, color: PipeBuyerColors.slate),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon(this.icon, {required this.tone});

  final IconData icon;
  final PipeBuyerStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = pipeBuyerToneColor(tone);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: accent),
    );
  }
}

class _TrustPoint extends StatelessWidget {
  const _TrustPoint({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PipeBuyerColors.orange.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: PipeBuyerColors.orange, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
