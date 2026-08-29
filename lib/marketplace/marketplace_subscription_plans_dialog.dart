import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'marketplace_dispatch_subscription_checkout.dart';
import 'marketplace_vip_subscription_checkout.dart';

class MarketplaceSubscriptionPlansDialog extends StatelessWidget {
  const MarketplaceSubscriptionPlansDialog({super.key});

  static const _plans = <_MembershipPlanPresentation>[
    _MembershipPlanPresentation(
      title: 'Dispatch Monthly',
      subtitle: 'Dispatch access billed monthly',
      assetPath: 'assets/images/membership_dispatch_monthly_subscription.svg',
      kind: _MembershipPlanKind.dispatchMonthly,
    ),
    _MembershipPlanPresentation(
      title: 'Dispatch Yearly',
      subtitle: 'Dispatch access billed yearly',
      assetPath: 'assets/images/membership_dispatch_yearly_subscription.svg',
      kind: _MembershipPlanKind.dispatchYearly,
    ),
    _MembershipPlanPresentation(
      title: 'VIP Membership',
      subtitle: 'VIP early access and member benefits',
      assetPath: 'assets/images/membership_vip_subscription.svg',
      kind: _MembershipPlanKind.vipMonthly,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 900),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose a Pipe Buyer membership',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Secure recurring billing is handled by Stripe. '
                          'Membership access starts only after confirmed payment.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close memberships',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1040;
                    final cards = _plans
                        .map((plan) => _MembershipPlanCard(plan: plan))
                        .toList(growable: false);
                    if (wide) {
                      return SingleChildScrollView(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var index = 0; index < cards.length; index++) ...[
                              Expanded(child: cards[index]),
                              if (index != cards.length - 1)
                                const SizedBox(width: 16),
                            ],
                          ],
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          for (var index = 0; index < cards.length; index++) ...[
                            cards[index],
                            if (index != cards.length - 1)
                              const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembershipPlanCard extends StatelessWidget {
  const _MembershipPlanCard({required this.plan});

  final _MembershipPlanPresentation plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: ValueKey<String>('membership-artwork-${plan.title}'),
              height: 240,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SvgPicture.asset(
                    plan.assetPath,
                    fit: BoxFit.contain,
                    semanticsLabel: '${plan.title} membership artwork',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              plan.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(plan.subtitle),
            const SizedBox(height: 14),
            switch (plan.kind) {
              _MembershipPlanKind.dispatchMonthly =>
                const DispatchSubscriptionCheckoutButton(plan: 'monthly'),
              _MembershipPlanKind.dispatchYearly =>
                const DispatchSubscriptionCheckoutButton(plan: 'yearly'),
              _MembershipPlanKind.vipMonthly =>
                const VipSubscriptionCheckoutButton(),
            },
          ],
        ),
      ),
    );
  }
}

enum _MembershipPlanKind { dispatchMonthly, dispatchYearly, vipMonthly }

class _MembershipPlanPresentation {
  const _MembershipPlanPresentation({
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.kind,
  });

  final String title;
  final String subtitle;
  final String assetPath;
  final _MembershipPlanKind kind;
}
