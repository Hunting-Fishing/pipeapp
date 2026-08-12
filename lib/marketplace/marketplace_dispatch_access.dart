import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import 'marketplace_command_client.dart';

bool dispatchAccountIsActive(Map<String, dynamic>? data) =>
    data != null && data['status'] == 'active';

bool dispatchMembershipIsActive(Map<String, dynamic>? data,
    {DateTime? now}) {
  if (data == null || data['active'] != true) return false;
  final end = data['currentPeriodEnd'];
  if (end is! Timestamp) return false;
  return end.toDate().isAfter(now ?? DateTime.now());
}

class DispatchSignupEligibilityCard extends StatelessWidget {
  const DispatchSignupEligibilityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final completion = ((data['profileCompletion'] as num?)?.toInt() ?? 0)
            .clamp(0, 100);
        final emailVerified = user.emailVerified;
        final phoneVerified = (user.phoneNumber ?? '').trim().isNotEmpty;
        final contactReady = emailVerified || phoneVerified;
        final ready = completion >= 70 && contactReady;
        return Card(
          color: ready ? const Color(0xFFE8F7F1) : const Color(0xFFFFF4E5),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(ready ? Icons.verified_user_outlined : Icons.fact_check_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ready ? 'Ready for Dispatch signup' : 'Dispatch signup requirements',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('Profile completion: $completion% • minimum 70%'),
                Text(emailVerified
                    ? 'Email verified ✓'
                    : phoneVerified
                        ? 'Phone verified ✓'
                        : 'Verify either your email or phone number'),
                const SizedBox(height: 6),
                const Text(
                  'One verified contact method is enough. Pipe Buyer does not require administrator approval for Dispatch signup.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DispatchMembershipCard extends StatefulWidget {
  const DispatchMembershipCard({super.key});

  @override
  State<DispatchMembershipCard> createState() => _DispatchMembershipCardState();
}

class _DispatchMembershipCardState extends State<DispatchMembershipCard> {
  final _commands = MarketplaceCommandClient();
  String? _busyPlan;

  Future<void> _checkout(String plan) async {
    if (_busyPlan != null) return;
    setState(() => _busyPlan = plan);
    try {
      final result = await _commands.execute(
        'createDispatchSubscriptionCheckout',
        {'plan': plan},
        timeout: const Duration(seconds: 45),
      );
      final uri = Uri.tryParse('${result['checkoutUrl'] ?? ''}');
      if (uri == null || uri.scheme != 'https') {
        throw StateError('Stripe did not return a valid membership checkout.');
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw StateError('Stripe Checkout could not be opened.');
      }
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(
          error,
          fallback: 'Dispatch membership checkout could not be started.',
        ),
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) setState(() => _busyPlan = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('dispatch_memberships')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final active = dispatchMembershipIsActive(data);
        final plan = '${data?['plan'] ?? ''}'.trim();
        final periodEnd = data?['currentPeriodEnd'];
        final endDate = periodEnd is Timestamp ? periodEnd.toDate().toLocal() : null;
        return Card(
          color: active ? const Color(0xFFE8F7F1) : const Color(0xFFEAF4FD),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(active ? Icons.verified_outlined : Icons.workspace_premium_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      active ? 'Dispatch membership active' : 'Membership required to bid',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                  ),
                  if (active) const Chip(label: Text('ACTIVE')),
                ]),
                const SizedBox(height: 6),
                Text(active
                    ? 'Your ${plan.isEmpty ? 'Dispatch' : plan} membership allows carrier bidding.'
                    : 'You may join Dispatch and view jobs without paying. An active monthly or yearly membership is required before submitting a carrier bid.'),
                if (active && endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Paid through ${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                if (!active) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _busyPlan == null ? () => _checkout('monthly') : null,
                        icon: _busyPlan == 'monthly'
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.calendar_month_outlined),
                        label: const Text('CAD $25 / month'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busyPlan == null ? () => _checkout('yearly') : null,
                        icon: _busyPlan == 'yearly'
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.calendar_today_outlined),
                        label: const Text('CAD $300 / year'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Stripe securely processes the recurring membership payment. Any eligible Pipe Buyer promotional entitlement is applied by the server.',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class DispatchPilotRequestCard extends StatefulWidget {
  const DispatchPilotRequestCard({super.key});

  @override
  State<DispatchPilotRequestCard> createState() => _DispatchPilotRequestCardState();
}

class _DispatchPilotRequestCardState extends State<DispatchPilotRequestCard> {
  final _commands = MarketplaceCommandClient();
  bool _submitting = false;

  Future<void> _requestPilot() async {
    final pickup = TextEditingController();
    final delivery = TextEditingController();
    final details = TextEditingController();
    var requestedDate = DateTime.now().add(const Duration(days: 1));
    final formKey = GlobalKey<FormState>();
    final submitted = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          title: Row(children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.arrow_back),
            ),
            const Expanded(
              child: Text('Request Pilot Service',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ]),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: pickup,
                    decoration: const InputDecoration(
                      labelText: 'Pickup / start location *',
                      prefixIcon: Icon(Icons.trip_origin),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: delivery,
                    decoration: const InputDecoration(
                      labelText: 'Delivery / end location *',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Pilot service date'),
                    subtitle: Text(
                      '${requestedDate.year}-${requestedDate.month.toString().padLeft(2, '0')}-${requestedDate.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final value = await showDatePicker(
                        context: dialogContext,
                        initialDate: requestedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (value != null) refresh(() => requestedDate = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: details,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Load, route or escort details *',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    validator: (value) => (value ?? '').trim().length < 5
                        ? 'Add enough information for pilot providers.'
                        : null,
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(dialogContext, {
                  'pickupLabel': pickup.text.trim(),
                  'deliveryLabel': delivery.text.trim(),
                  'requestedDate': requestedDate.millisecondsSinceEpoch,
                  'details': details.text.trim(),
                });
              },
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Send pilot request'),
            ),
          ],
        ),
      ),
    );
    pickup.dispose();
    delivery.dispose();
    details.dispose();
    if (submitted == null || !mounted) return;
    setState(() => _submitting = true);
    try {
      final result = await _commands.execute(
        'createDispatchPilotRequest',
        submitted,
        timeout: const Duration(seconds: 45),
      );
      if (!mounted) return;
      final notified = (result['notifiedPilotProviders'] as num?)?.toInt() ?? 0;
      PipeFeedback.show(
        context,
        message: notified > 0
            ? 'Pilot request sent. $notified available pilot provider${notified == 1 ? '' : 's'} notified.'
            : 'Pilot request posted. No available pilot providers are registered yet.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(
          error,
          fallback: 'The pilot request could not be posted.',
        ),
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFEAF4FD),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.assistant_direction_outlined),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Need an escort or pilot truck?',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 6),
              const Text(
                'Request Pilot Service and Pipe Buyer will notify signed-up Dispatch providers with an assigned, available pilot truck.',
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _submitting ? null : _requestPilot,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.campaign_outlined),
                label: const Text('Request Pilot Service'),
              ),
            ],
          ),
        ),
      );
}
