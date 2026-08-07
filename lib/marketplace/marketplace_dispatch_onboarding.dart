import 'package:flutter/material.dart';

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
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _hero(context),
        const SizedBox(height: 18),
        const Text(
          'Choose how you use Dispatch',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
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
                    title: 'Request trucking service',
                    description:
                        'Post a load for pipe, equipment, buildings, vehicles, or field freight. Add pickup, delivery, timing, weight, and load details so qualified providers can respond.',
                    actionLabel: 'Post a load request',
                    onPressed: onPostLoad,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _AudienceCard(
                    icon: Icons.local_shipping_outlined,
                    title: 'Offer trucking services',
                    description:
                        'Join the Dispatch network as a carrier, hotshot operator, pilot-car provider, equipment hauler, towing company, or oilfield service transporter.',
                    actionLabel: 'Join the Dispatch network',
                    onPressed: onJoinCarrier,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        const Text(
          'How Dispatch works',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
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
                  number: '1',
                  icon: Icons.assignment_outlined,
                  title: 'Publish or match',
                  description:
                      'Customers publish a trucking request. Network providers receive opportunities matching their services and operating areas.',
                ),
                _StepCard(
                  width: width,
                  number: '2',
                  icon: Icons.request_quote_outlined,
                  title: 'Review and quote',
                  description:
                      'Providers review the route and load, then submit a quote. No job is accepted automatically.',
                ),
                _StepCard(
                  width: width,
                  number: '3',
                  icon: Icons.fact_check_outlined,
                  title: 'Customer approves',
                  description:
                      'The customer compares responses and selects a provider. Both sides receive the award and scheduling details.',
                ),
                _StepCard(
                  width: width,
                  number: '4',
                  icon: Icons.forum_outlined,
                  title: 'Coordinate the job',
                  description:
                      'Use in-app messages and Dispatch notifications for updates, pickup coordination, route changes, and completion records.',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _pricingCard(context),
        const SizedBox(height: 12),
        _notificationsCard(context),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_user_outlined),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Carrier profile requirements',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
          ),
        ),
      ],
    );
  }

  Widget _hero(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF0B2440),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pipe Buyer Dispatch Network',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Request transportation or offer professional trucking services for oilfield, industrial, construction, agricultural, and remote-site freight.',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                      ),
                      onPressed: onPostLoad,
                      icon: const Icon(Icons.add_road_outlined),
                      label: const Text('Request a truck'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      onPressed: onJoinCarrier,
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Offer services'),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: onBrowseJobs,
                      icon: const Icon(Icons.search_outlined),
                      label: const Text('Browse jobs'),
                    ),
                  ],
                ),
              ],
            );
            const art = Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.route_outlined,
                size: 92,
                color: Color(0xFF40D9C5),
              ),
            );
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [copy, const SizedBox(height: 12), art],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 20),
                art,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pricingCard(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF4E5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sell_outlined, color: Color(0xFFB35B00)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Proposed pilot network pricing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _PriceChip(
                  title: r'$25 per year',
                  subtitle: 'Dispatch network membership',
                ),
                _PriceChip(
                  title: r'$10 per dispatched job',
                  subtitle: 'Paid to Pipe Buyer',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              r'The $10 Dispatch fee is paid to Pipe Buyer for each dispatched job. Pricing is displayed for pilot planning only. Billing and fee collection are not active in this release. No charge is collected until payment and fee features receive separate approval, final terms are published, and the user explicitly accepts them.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationsCard(BuildContext context) {
    return Card(
      color: const Color(0xFFEAF4FD),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    color: Color(0xFF0878E8)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dispatch notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              'In-app notifications can alert providers to matching opportunities, new messages, quote changes, job awards, schedule updates, and completion activity. Browser push notifications are optional and appear only when the current web release is configured and the user grants permission.',
            ),
          ],
        ),
      ),
    );
  }
}

class _AudienceCard extends StatelessWidget {
  const _AudienceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(description),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: const Icon(Icons.arrow_forward),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      );
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
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 16, child: Text(number)),
                    const SizedBox(width: 8),
                    Icon(icon),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      );
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFC46B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900)),
            Text(subtitle, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}
