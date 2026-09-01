import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dispatch job and quote messaging reuses Marketplace conversations', () {
    final actions = File(
      'lib/marketplace/marketplace_actions_repository.dart',
    ).readAsStringSync();
    final helper = File(
      'lib/marketplace/marketplace_dispatch_messaging.dart',
    ).readAsStringSync();
    final dispatchPage = File(
      'lib/marketplace/marketplace_dispatch_page.dart',
    ).readAsStringSync();
    final transaction = File(
      'lib/marketplace/marketplace_dispatch_transaction.dart',
    ).readAsStringSync();

    expect(actions, contains('Future<String> openDispatchConversation'));
    expect(actions, contains("_commands.execute('openDispatchConversation'"));
    expect(helper, contains('MarketplaceActionsRepository()'));
    expect(helper, contains('MarketplaceDeepLinks.conversation'));
    expect(dispatchPage, contains("tooltip: 'Message carrier'"));
    expect(dispatchPage, contains("label: const Text('Message customer')"));
    expect(dispatchPage, contains('bidId: bid.id'));
    expect(
      transaction,
      contains("customer ? 'Message carrier' : 'Message customer'"),
    );
    expect(transaction, contains('jobId: widget.jobId'));
  });

  test('Dispatch messaging does not introduce a second message datastore', () {
    final helper = File(
      'lib/marketplace/marketplace_dispatch_messaging.dart',
    ).readAsStringSync();
    final server = File(
      'firebase/functions/communication_commands.js',
    ).readAsStringSync();

    expect(helper, isNot(contains("collection('dispatch_messages')")));
    expect(server, contains('db.collection("conversations")'));
    expect(server, contains('contextType: "dispatch_job"'));
    expect(server, isNot(contains('dispatch_messages')));
  });
}
