import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_about_page.dart';

void main() {
  testWidgets('shows release identity in the Account About destination',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MarketplaceAboutPage()),
    );

    expect(find.text('About Pipe Buyer'), findsWidgets);
    expect(find.textContaining('v1.0.0+1'), findsOneWidget);
    expect(find.text('Release revision'), findsOneWidget);
    expect(find.text('support@pipebuyer.com'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Terms of Service'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
  });
}
