import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';

class MarketplaceHomeWelcome extends StatelessWidget {
  const MarketplaceHomeWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final candidates = [
          data['displayName'],
          data['display_name'],
          data['businessName'],
          user.displayName,
          user.email?.split('@').first,
        ];
        final name = candidates
            .map((value) => '${value ?? ''}'.trim())
            .firstWhere((value) => value.isNotEmpty,
                orElse: () => 'Pipe Buyer member');
        final accountType = '${data['accountType'] ?? 'personal'}';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: PipeBuyerColors.orange.withValues(alpha: .28),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 22,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 650;
              final greeting = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PIPE BUYER WORKSPACE',
                    style: TextStyle(
                      color: PipeBuyerColors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Welcome back, $name',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 24 : 30,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Find inventory, manage listings, negotiate deals and coordinate Dispatch from one industrial marketplace.',
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _WelcomeChip(
                        icon: Icons.person_outline_rounded,
                        label: accountType == 'business'
                            ? 'Business account'
                            : 'Marketplace account',
                      ),
                      const _WelcomeChip(
                        icon: Icons.event_available_outlined,
                        label: '30-day active listings',
                      ),
                      const _WelcomeChip(
                        icon: Icons.workspace_premium_outlined,
                        label: 'VIP priority access available',
                      ),
                    ],
                  ),
                ],
              );
              final mark = Container(
                width: compact ? 62 : 82,
                height: compact ? 62 : 82,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .05),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PipeBuyerColors.orange.withValues(alpha: .45),
                  ),
                ),
                child: const Icon(
                  Icons.factory_outlined,
                  color: PipeBuyerColors.orange,
                  size: 36,
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    mark,
                    const SizedBox(height: 14),
                    greeting,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: greeting),
                  const SizedBox(width: 24),
                  mark,
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _WelcomeChip extends StatelessWidget {
  const _WelcomeChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: PipeBuyerColors.orange, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}
