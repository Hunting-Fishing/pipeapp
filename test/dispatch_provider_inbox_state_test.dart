import 'package:flutter_test/flutter_test.dart';
import 'package:pipebuyer/marketplace/marketplace_dispatch_provider_inbox.dart';

void main() {
  test('carrier-owned workflow states surface the correct next action', () {
    expect(
      dispatchProviderInboxState('awarded').nextAction,
      'Accept award',
    );
    expect(
      dispatchProviderInboxState('accepted').nextAction,
      'Schedule pickup',
    );
    expect(
      dispatchProviderInboxState('scheduled').nextAction,
      'Start transport when ready',
    );
    expect(
      dispatchProviderInboxState('in_transit').nextAction,
      'Record delivery',
    );
  });

  test('customer-owned delivery confirmation is presented as waiting', () {
    final state = dispatchProviderInboxState('delivered');
    expect(state.bucket, DispatchProviderInboxBucket.waiting);
    expect(state.nextAction, 'Waiting for customer confirmation');
  });

  test('pending quotes wait for the customer rather than claiming carrier action', () {
    final state = dispatchProviderInboxState('pending');
    expect(state.bucket, DispatchProviderInboxBucket.waiting);
    expect(state.nextAction, 'Waiting for customer decision');
  });

  test('terminal quote states never enter actionable counts', () {
    final counts = DispatchProviderInboxCounts.fromQuotes([
      {'status': 'not_selected'},
      {'status': 'cancelled'},
      {'status': 'completed'},
      {'status': 'closed'},
    ]);

    expect(counts.needsAction, 0);
    expect(counts.waiting, 0);
    expect(counts.active, 0);
    expect(counts.complete, 2);
  });

  test('provider inbox counts actionable and waiting work independently', () {
    final counts = DispatchProviderInboxCounts.fromQuotes([
      {'status': 'awarded'},
      {'status': 'accepted'},
      {'status': 'scheduled'},
      {'status': 'in_transit'},
      {'status': 'disputed'},
      {'status': 'pending'},
      {'status': 'delivered'},
      {'status': 'unknown_future_state'},
    ]);

    expect(counts.needsAction, 5);
    expect(counts.waiting, 2);
    expect(counts.active, 1);
    expect(counts.complete, 0);
  });
}
