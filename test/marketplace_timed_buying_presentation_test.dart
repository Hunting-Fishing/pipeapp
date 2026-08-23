import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_timed_buying_presentation.dart';

void main() {
  final now = DateTime.utc(2026, 8, 15, 12);

  test('Timed Buying urgency follows closing-time bands', () {
    TimedBuyingUrgencyState state(Duration remaining) =>
        timedBuyingUrgencyState(
          start: now.subtract(const Duration(days: 1)),
          end: now.add(remaining),
          now: now,
        );

    expect(
        state(const Duration(days: 45)).urgency, TimedBuyingUrgency.monthPlus);
    expect(state(const Duration(days: 20)).urgency, TimedBuyingUrgency.weeks);
    expect(state(const Duration(days: 10)).urgency, TimedBuyingUrgency.week);
    expect(state(const Duration(days: 3)).urgency, TimedBuyingUrgency.day);
    expect(state(const Duration(hours: 8)).urgency, TimedBuyingUrgency.hours);
    expect(state(const Duration(minutes: 35)).urgency,
        TimedBuyingUrgency.finalHour);
    expect(
        state(const Duration(minutes: -1)).urgency, TimedBuyingUrgency.closed);
  });

  test('upcoming Timed Buying shows the start countdown', () {
    final state = timedBuyingUrgencyState(
      start: now.add(const Duration(days: 2)),
      end: now.add(const Duration(days: 4)),
      now: now,
    );
    expect(state.urgency, TimedBuyingUrgency.upcoming);
    expect(state.detail, startsWith('Starts in'));
  });

  test('public errors avoid auction and bid terminology', () {
    final message = timedBuyingPublicMessage(
      'This auction is no longer live. The winning bidder cannot place another bid.',
    );
    expect(message.toLowerCase(), isNot(contains('auction')));
    expect(message.toLowerCase(), isNot(contains('bid')));
    expect(message, contains('Timed Buying listing'));
    expect(message, contains('successful buyer'));
    expect(message, contains('timed offer'));
  });

  testWidgets('final-hour frame renders with reduced motion', (tester) async {
    final start = now.subtract(const Duration(hours: 1));
    final end = now.add(const Duration(minutes: 30));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: TimedBuyingUrgencyFrame(
              start: start,
              end: end,
              child: const SizedBox(width: 240, height: 120),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(TimedBuyingUrgencyFrame), findsOneWidget);
  });

  testWidgets('legend explains Timed Buying timing signals', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTimedBuyingLegend(context),
            child: const Text('Signals'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Signals'));
    await tester.pumpAndSettle();
    expect(find.text('Timed Buying time signals'), findsOneWidget);
    expect(find.text('Month+'), findsOneWidget);
    expect(find.text('Final hour'), findsOneWidget);
  });
}
