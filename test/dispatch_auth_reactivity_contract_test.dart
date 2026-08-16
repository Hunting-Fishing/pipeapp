import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dispatch page reacts to Firebase sign-in and sign-out changes', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_page.dart',
    ).readAsStringSync();

    final start = source.indexOf(
      'class _MarketplaceDispatchPageState extends State<MarketplaceDispatchPage>',
    );
    final end = source.indexOf(
      'class _PilotTruckSection extends StatelessWidget',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final dispatchState = source.substring(start, end);

    expect(
      dispatchState,
      contains('FirebaseAuth.instance.authStateChanges()'),
    );
    expect(
      dispatchState,
      contains('initialData: FirebaseAuth.instance.currentUser'),
    );
    expect(
      dispatchState,
      contains('Widget _buildAuthenticatedDispatch(BuildContext context)'),
    );
    expect(
      dispatchState,
      isNot(contains('if (FirebaseAuth.instance.currentUser == null)')),
    );
  });
}
