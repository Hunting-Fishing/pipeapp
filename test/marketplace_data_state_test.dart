import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_data_state.dart';

void main() {
  test('Firebase failures are classified without exposing internals', () {
    final offline = marketplaceFailurePresentation(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'PRIVATE_BACKEND_DETAIL',
      ),
      resource: 'Conversations',
    );
    expect(offline.kind, MarketplaceDataStateKind.offline);
    expect(offline.title, 'Connection interrupted');
    expect(offline.message, isNot(contains('PRIVATE_BACKEND_DETAIL')));

    final denied = marketplaceFailurePresentation(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      resource: 'Saved listings',
    );
    expect(denied.kind, MarketplaceDataStateKind.unavailable);
  });

  testWidgets('failure state is actionable and supports large text',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Scaffold(
          body: SizedBox(
            width: 320,
            height: 520,
            child: MarketplaceDataStateView.failure(
              error: FirebaseException(
                plugin: 'cloud_firestore',
                code: 'unavailable',
              ),
              resource: 'Messages',
              onRetry: () => retried = true,
            ),
          ),
        ),
      ),
    ));

    expect(find.text('Connection interrupted'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Connection interrupted. Messages could not be refreshed. '
        'Check your connection and try again.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading state explains the active work', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MarketplaceDataStateView.loading(
          title: 'Loading auctions',
          message: 'Retrieving current bids and closing times…',
        ),
      ),
    ));
    expect(find.text('Loading auctions'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('recovering streams can show a safe failure without an action',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarketplaceDataStateView.failure(
          error: FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'PRIVATE_RULE_DETAIL',
          ),
          resource: 'Account reviews',
        ),
      ),
    ));

    expect(find.text('Access needs attention'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.textContaining('PRIVATE_RULE_DETAIL'), findsNothing);
  });
}
