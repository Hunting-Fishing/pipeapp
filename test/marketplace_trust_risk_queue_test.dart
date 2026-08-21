import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_trust_risk_policy.dart';
import 'package:pipe_app/marketplace/marketplace_trust_risk_queue.dart';

void main() {
  testWidgets('risk card explains priority and human-review boundary',
      (tester) async {
    final assessment = MarketplaceTrustRiskPolicy.assess(
      report: const {
        'reason': 'fraud_or_scam',
        'reasonLabel': 'Fraud, scam, or impersonation',
        'source': 'automated',
        'priority': 'high',
        'moderationSignals': ['possible_payment_fraud'],
      },
    );
    final item = TrustRiskQueueItem(
      reportId: 'report-123',
      report: const {
        'reason': 'fraud_or_scam',
        'reasonLabel': 'Fraud, scam, or impersonation',
        'source': 'automated',
        'targetType': 'listing',
      },
      listing: const {
        'title': '2 7/8 Tubing Package',
        'category': 'Pipe',
        'currency': 'CAD',
        'price': 250,
        'priceBasis': 'Per item',
      },
      assessment: assessment,
      createdAtMillis: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrustRiskCaseCard(item: item),
          ),
        ),
      ),
    );

    expect(find.text('Fraud, scam, or impersonation'), findsOneWidget);
    expect(find.text('HIGH REVIEW PRIORITY'), findsOneWidget);
    expect(find.textContaining('possible fraud pre-screen'), findsOneWidget);
    expect(find.textContaining('Human decision required'), findsOneWidget);
    expect(find.textContaining('2 7/8 Tubing Package'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
