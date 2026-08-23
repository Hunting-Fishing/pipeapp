import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_timed_buying_engagement.dart';
import 'package:pipe_app/marketplace/marketplace_timed_buying_presentation.dart';

void main() {
  test('legacy auction titles are converted to Timed Buying display titles',
      () {
    expect(
      timedBuyingDisplayTitle('Timed Auction — CAT D6 Dozer'),
      'Timed Buying — CAT D6 Dozer',
    );
    expect(
      timedBuyingDisplayTitle('Upcoming Auction — 2020 Bobcat T76'),
      'Timed Buying — Upcoming — 2020 Bobcat T76',
    );
    expect(timedBuyingDisplayTitle('Auction Lot 14'), 'Timed Buying Lot 14');
  });

  test('final day and final hour both animate while final week stays static',
      () {
    expect(timedBuyingAttentionAnimates(TimedBuyingUrgency.day), isFalse);
    expect(timedBuyingAttentionAnimates(TimedBuyingUrgency.hours), isTrue);
    expect(timedBuyingAttentionAnimates(TimedBuyingUrgency.finalHour), isTrue);
    expect(
      timedBuyingAttentionStroke(TimedBuyingUrgency.finalHour),
      greaterThan(timedBuyingAttentionStroke(TimedBuyingUrgency.hours)),
    );
    expect(
      timedBuyingAttentionStroke(TimedBuyingUrgency.hours),
      greaterThan(timedBuyingAttentionStroke(TimedBuyingUrgency.day)),
    );
  });

  testWidgets(
      'five-hour listing renders attention strip and viewer-leading badge',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TimedBuyingAttentionStrip(
                start: now.subtract(const Duration(hours: 2)),
                end: now.add(const Duration(hours: 5)),
                compact: true,
              ),
              const TimedBuyingViewerPositionBadge(
                position: TimedBuyingViewerPosition.leading,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('FINAL DAY'), findsOneWidget);
    expect(find.text('YOU’RE LEADING'), findsOneWidget);
  });

  testWidgets('final-hour attention frame renders with reduced motion',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: TimedBuyingAttentionFrame(
              start: now.subtract(const Duration(hours: 3)),
              end: now.add(const Duration(minutes: 45)),
              child: const SizedBox(width: 260, height: 180),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(TimedBuyingAttentionFrame), findsOneWidget);
  });
}
