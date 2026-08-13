import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/accessibility/pipe_accessibility_theme.dart';
import 'package:pipe_app/core/design/pipe_buyer_components.dart';
import 'package:pipe_app/core/design/pipe_buyer_theme.dart';

void main() {
  group('PipeBuyer premium theme', () {
    test('light theme uses the industrial brand palette', () {
      final theme = PipeAccessibilityTheme.apply(PipeBuyerTheme.light());

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, PipeBuyerColors.orange);
      expect(theme.colorScheme.secondary, PipeBuyerColors.industrialBlue);
      expect(theme.scaffoldBackgroundColor, PipeBuyerColors.canvas);
      expect(theme.appBarTheme.backgroundColor, PipeBuyerColors.ink);
      expect(theme.cardColor, PipeBuyerColors.surface);
    });

    test('dark theme keeps PipeBuyer orange as the action color', () {
      final theme = PipeAccessibilityTheme.apply(PipeBuyerTheme.dark());

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, PipeBuyerColors.orange);
      expect(theme.scaffoldBackgroundColor, PipeBuyerColors.darkCanvas);
      expect(theme.cardColor, PipeBuyerColors.darkSurface);
    });

    test('premium button styling survives accessibility enforcement', () {
      final theme = PipeAccessibilityTheme.apply(PipeBuyerTheme.light());
      final style = theme.filledButtonTheme.style!;
      final normalStates = <WidgetState>{};
      final focusedStates = <WidgetState>{WidgetState.focused};

      expect(
        style.backgroundColor?.resolve(normalStates),
        PipeBuyerColors.orange,
      );
      final minimum = style.minimumSize?.resolve(normalStates);
      expect(minimum, isNotNull);
      expect(minimum!.height, greaterThanOrEqualTo(48));
      expect(minimum.width, greaterThanOrEqualTo(64));

      final focusedSide = style.side?.resolve(focusedStates);
      expect(focusedSide, isNotNull);
      expect(focusedSide!.width, 3);
    });
  });

  Widget app(Widget child) => MaterialApp(
        theme: PipeAccessibilityTheme.apply(PipeBuyerTheme.light()),
        home: Scaffold(body: child),
      );

  group('PipeBuyer premium components', () {
    testWidgets('metric grid stacks on compact screens', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(const Padding(
        padding: EdgeInsets.all(16),
        child: PipeBuyerMetricGrid(
          children: [
            PipeBuyerMetricCard(
              label: 'Listings',
              value: '12',
              icon: Icons.inventory_2_outlined,
            ),
            PipeBuyerMetricCard(
              label: 'Offers',
              value: '4',
              icon: Icons.handshake_outlined,
            ),
          ],
        ),
      )));

      final first = tester.getRect(find.text('Listings'));
      final second = tester.getRect(find.text('Offers'));
      expect(second.top, greaterThan(first.bottom));
    });

    testWidgets('metric grid uses four columns on wide screens',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1300, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(const Padding(
        padding: EdgeInsets.all(20),
        child: PipeBuyerMetricGrid(
          children: [
            PipeBuyerMetricCard(
              label: 'Listings',
              value: '12',
              icon: Icons.inventory_2_outlined,
            ),
            PipeBuyerMetricCard(
              label: 'Offers',
              value: '4',
              icon: Icons.handshake_outlined,
            ),
            PipeBuyerMetricCard(
              label: 'Messages',
              value: '7',
              icon: Icons.forum_outlined,
            ),
            PipeBuyerMetricCard(
              label: 'Views',
              value: '1.8K',
              icon: Icons.visibility_outlined,
            ),
          ],
        ),
      )));

      final tops = <double>{
        tester.getRect(find.text('Listings')).top,
        tester.getRect(find.text('Offers')).top,
        tester.getRect(find.text('Messages')).top,
        tester.getRect(find.text('Views')).top,
      };
      expect(tops.length, 1);
    });

    testWidgets('account health clamps values and shows action state',
        (tester) async {
      await tester.pumpWidget(app(const Center(
        child: SizedBox(
          width: 720,
          child: PipeBuyerAccountHealthCard(
            completion: 150,
            score: -20,
            verified: false,
          ),
        ),
      )));

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('ACTION NEEDED'), findsOneWidget);
    });

    testWidgets('status badge renders verified state', (tester) async {
      await tester.pumpWidget(app(const Center(
        child: PipeBuyerStatusBadge(
          label: 'VERIFIED',
          tone: PipeBuyerStatusTone.success,
          icon: Icons.verified_rounded,
        ),
      )));

      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });
  });
}
