import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_navigation.dart';

void main() {
  testWidgets('home intent navigation emits repeated destination requests', (
    tester,
  ) async {
    var notifications = 0;
    void listener() => notifications++;
    MarketplaceNavigation.destinationRequests.addListener(listener);
    addTearDown(
      () => MarketplaceNavigation.destinationRequests.removeListener(listener),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => MarketplaceNavigation.goToBrowse(context),
                child: const Text('Browse'),
              ),
              TextButton(
                onPressed: () => MarketplaceNavigation.goToBrowse(context),
                child: const Text('Browse again'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Browse'));
    await tester.pump();
    await tester.tap(find.text('Browse again'));
    await tester.pump();

    expect(notifications, 2);
    expect(MarketplaceNavigation.destinationRequests.value?.pageIndex, 1);
  });

  testWidgets('wanted intent emits a distinct request', (tester) async {
    final before = MarketplaceNavigation.wantedRequests.value;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => MarketplaceNavigation.goToWanted(context),
            child: const Text('Wanted'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Wanted'));
    await tester.pump();

    expect(MarketplaceNavigation.wantedRequests.value, before + 1);
  });
}
