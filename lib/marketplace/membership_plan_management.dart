import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'marketplace_command_client.dart';
import 'marketplace_subscription_billing_policy.dart';

String membershipPlanDisplayName(String plan) => switch (plan) {
      'free' => 'Free',
      'dispatch_monthly' => 'Monthly',
      'dispatch_yearly' => 'Yearly',
      'vip_monthly' => 'VIP',
      _ => 'Membership',
    };

String _priceLabel(Map<String, dynamic>? plan) {
  if (plan == null) return '';
  final amount = num.tryParse('${plan['amount'] ?? ''}');
  final currency = '${plan['currency'] ?? 'CAD'}'.toUpperCase();
  final interval = '${plan['interval'] ?? ''}'.trim().toLowerCase();
  if (amount == null || amount < 0 || interval.isEmpty) return '';
  final value = amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  final money = currency == 'CAD' ? 'CA\$$value' : '$currency \$$value';
  return '$money / $interval';
}

class MembershipPlanManagementButton extends StatefulWidget {
  const MembershipPlanManagementButton({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<MembershipPlanManagementButton> createState() =>
      _MembershipPlanManagementButtonState();
}

class _MembershipPlanManagementButtonState
    extends State<MembershipPlanManagementButton> {
  final _commands = MarketplaceCommandClient();
  bool _busy = false;

  Future<Map<String, dynamic>> _status() => _commands.execute(
        'getMembershipPlanStatus',
        const <String, Object?>{},
      );

  @override
  Widget build(BuildContext context) {
    if (!marketplaceHostedMembershipBillingAllowed()) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _status(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.hasError ||
            data?['paid'] != true) {
          return const SizedBox.shrink();
        }
        final current = '${data?['currentPlan'] ?? ''}'.trim();
        final pending = '${data?['pendingPlan'] ?? ''}'.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _openPlanPicker(current),
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.swap_horiz_rounded),
              label: Text(_busy ? 'Updating plan…' : 'Change plan'),
            ),
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Scheduled: ${membershipPlanDisplayName(pending)} at the end of the current paid period.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openPlanPicker(String currentPlan) async {
    try {
      final results = await Future.wait([
        _commands.execute('getDispatchSubscriptionCatalog', const <String, Object?>{}),
        _commands.execute('getVipSubscriptionCatalog', const <String, Object?>{}),
      ]);
      if (!mounted) return;
      final dispatchPlans = results[0]['plans'] is Map
          ? Map<String, dynamic>.from(results[0]['plans'] as Map)
          : const <String, dynamic>{};
      final vipPlans = results[1]['plans'] is Map
          ? Map<String, dynamic>.from(results[1]['plans'] as Map)
          : const <String, dynamic>{};
      Map<String, dynamic>? planMap(Map<String, dynamic> source, String key) =>
          source[key] is Map ? Map<String, dynamic>.from(source[key] as Map) : null;
      final choices = <_MembershipPlanChoice>[
        const _MembershipPlanChoice(
          id: 'free',
          title: 'Free',
          subtitle: 'No recurring membership charge. Your paid benefits continue through the current paid period.',
          icon: Icons.person_outline_rounded,
        ),
        _MembershipPlanChoice(
          id: 'dispatch_monthly',
          title: 'Monthly',
          subtitle: '${_priceLabel(planMap(dispatchPlans, 'monthly'))} • Dispatch access',
          icon: Icons.calendar_month_outlined,
        ),
        _MembershipPlanChoice(
          id: 'dispatch_yearly',
          title: 'Yearly',
          subtitle: '${_priceLabel(planMap(dispatchPlans, 'yearly'))} • Dispatch access',
          icon: Icons.event_repeat_outlined,
        ),
        _MembershipPlanChoice(
          id: 'vip_monthly',
          title: 'VIP',
          subtitle: '${_priceLabel(planMap(vipPlans, 'monthly'))} • VIP marketplace benefits + Dispatch access',
          icon: Icons.workspace_premium_outlined,
        ),
      ];
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change membership plan'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose the plan you want. Upgrades are confirmed by Stripe before access changes. Downgrades and Free take effect at the end of the period you already paid for.',
                ),
                const SizedBox(height: 12),
                for (final choice in choices)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(choice.icon),
                      title: Text(choice.title),
                      subtitle: Text(choice.subtitle),
                      trailing: choice.id == currentPlan
                          ? const Chip(label: Text('Current'))
                          : const Icon(Icons.chevron_right_rounded),
                      enabled: choice.id != currentPlan,
                      onTap: choice.id == currentPlan
                          ? null
                          : () => Navigator.of(context).pop(choice.id),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      await _confirmAndChange(selected);
    } catch (error) {
      if (!mounted) return;
      _showError(error, 'Membership plans could not be loaded.');
    }
  }

  Future<void> _confirmAndChange(String targetPlan) async {
    final name = membershipPlanDisplayName(targetPlan);
    final free = targetPlan == 'free';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(free ? 'Move to Free?' : 'Change to $name?'),
        content: Text(
          free
              ? 'Your current paid benefits stay active through the period you already paid for. Renewal stops after that date.'
              : targetPlan == 'vip_monthly'
                  ? 'Stripe will calculate any upgrade proration and confirm payment before VIP access is granted. Dispatch-only promo discounts do not carry into VIP.'
                  : 'This change is scheduled for the end of your current paid period so you keep the benefits you already paid for.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep current plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(free ? 'Move to Free' : 'Confirm change'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await _commands.execute(
        'changeMembershipPlan',
        <String, Object?>{'targetPlan': targetPlan},
      );
      if (!mounted) return;
      final effective = '${result['effective'] ?? ''}';
      final message = switch (effective) {
        'period_end' => '$name is scheduled for the end of your current paid period.',
        'after_payment_confirmation' => 'Stripe confirmed the plan update. VIP activates from the paid invoice confirmation.',
        'already_selected' => '$name is already your current plan.',
        _ => 'Membership plan updated.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      widget.onChanged?.call();
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showError(error, 'Membership plan could not be changed safely.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error, String fallback) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          marketplaceCommandErrorMessage(error, fallback: fallback),
        ),
      ),
    );
  }
}

class _MembershipPlanChoice {
  const _MembershipPlanChoice({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}
