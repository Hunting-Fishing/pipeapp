import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/accessibility/pipe_accessibility_theme.dart';
import 'package:pipe_app/core/accessibility/pipe_status_feedback.dart';

void main() {
  test('semantic status colors meet AA text contrast in both themes', () {
    for (final palette in const [
      PipeStatusColors.light(),
      PipeStatusColors.dark(),
    ]) {
      for (final tone in PipeStatusTone.values) {
        final colors = palette.forTone(tone);
        expect(
          _contrastRatio(colors.foreground, colors.background),
          greaterThanOrEqualTo(4.5),
          reason: '$tone text must not rely on color without readable contrast',
        );
      }
    }
  });

  test('release theme installs the brightness-matched status palette', () {
    final light = PipeAccessibilityTheme.apply(ThemeData.light())
        .extension<PipeStatusColors>();
    final dark = PipeAccessibilityTheme.apply(ThemeData.dark())
        .extension<PipeStatusColors>();

    expect(light, isNotNull);
    expect(dark, isNotNull);
    expect(light!.error.background, const Color(0xFFFFEBEF));
    expect(dark!.error.background, const Color(0xFF441824));
  });

  test('critical commerce commands use controlled semantic feedback', () {
    for (final path in const [
      'lib/marketplace/marketplace_auction_settlement.dart',
      'lib/marketplace/marketplace_dispatch_transaction.dart',
      'lib/marketplace/marketplace_auctions_page.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('PipeFeedback.show('), reason: path);
      expect(source, contains('marketplaceCommandErrorMessage('), reason: path);
      expect(source, isNot(contains('ScaffoldMessenger.of(')), reason: path);
    }

    final messages = File(
      'lib/marketplace/marketplace_messages_page.dart',
    ).readAsStringSync();
    expect(RegExp(r'PipeFeedback\.show\(').allMatches(messages).length,
        greaterThanOrEqualTo(10));
    expect(
      messages,
      contains('The transaction could not be updated. Nothing was changed.'),
    );
  });

  test('marketplace feedback does not reintroduce color-only snackbars', () {
    final marketplace =
        File('lib/marketplace/oil_gas_marketplace.dart').readAsStringSync();
    expect(
      RegExp(r'PipeFeedback\.show\(').allMatches(marketplace).length,
      greaterThanOrEqualTo(7),
    );
    expect(
      marketplace,
      isNot(contains('ScaffoldMessenger.of(context).showSnackBar')),
      reason:
          'The primary marketplace shell must use the accessible feedback system.',
    );
  });

  testWidgets('status surfaces announce meaning and survive 200 percent text',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: PipeAccessibilityTheme.apply(ThemeData.light()),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: PipeStatusSurface(
                tone: PipeStatusTone.error,
                title: 'Upload did not finish',
                message: 'Check your connection and try again.',
                liveRegion: true,
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.byType(PipeStatusSurface));
    expect(node.label, contains('Error'));
    expect(node.label, contains('Upload did not finish'));
    expect(node.label, contains('Check your connection and try again'));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('feedback snackbars are dismissible live regions',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: PipeAccessibilityTheme.apply(ThemeData.light()),
      home: Builder(builder: (context) {
        return Scaffold(
          body: FilledButton(
            onPressed: () => PipeFeedback.show(
              context,
              message: 'Profile photo updated.',
              tone: PipeStatusTone.success,
            ),
            child: const Text('Save'),
          ),
        );
      }),
    ));

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(Semantics),
      ),
      findsWidgets,
    );
    expect(find.text('Profile photo updated.'), findsOneWidget);
    expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).showCloseIcon, isTrue);
    semantics.dispose();
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
