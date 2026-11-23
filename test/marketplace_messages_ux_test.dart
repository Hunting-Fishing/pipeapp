import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/data/bounded_firestore_query.dart';
import 'package:pipe_app/marketplace/marketplace_messages_page.dart';

void main() {
  group('marketplace conversation context', () {
    test('selects the other participant for buyers and sellers', () {
      const conversation = <String, dynamic>{
        'sellerUid': 'seller-1',
        'sellerName': 'Steel Supply Co.',
        'buyerDisplayName': 'Jordan Buyer',
        'requesterDisplayName': 'Fallback Buyer',
      };

      expect(
        marketplaceConversationParticipantName(conversation, 'seller-1'),
        'Jordan Buyer',
      );
      expect(
        marketplaceConversationParticipantName(conversation, 'buyer-1'),
        'Steel Supply Co.',
      );
      expect(
        marketplaceConversationParticipantName(
          const <String, dynamic>{'sellerUid': 'seller-1'},
          'buyer-1',
        ),
        'Marketplace seller',
      );
    });

    testWidgets('formats current-day and older timestamps compactly', (
      tester,
    ) async {
      final now = DateTime(2026, 11, 23, 14, 30);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Column(
              children: [
                Text(
                  marketplaceMessageTimestamp(
                    context,
                    DateTime(2026, 11, 23, 9, 5),
                    now: now,
                  ),
                  key: const Key('today'),
                ),
                Text(
                  marketplaceMessageTimestamp(
                    context,
                    DateTime(2026, 11, 22, 18, 15),
                    now: now,
                    includeTimeOnOlderDays: false,
                  ),
                  key: const Key('older'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(
          tester.widget<Text>(find.byKey(const Key('today'))).data, '9:05 AM');
      final older = tester.widget<Text>(find.byKey(const Key('older'))).data!;
      expect(older, contains('2026'));
      expect(older, isNot(contains('6:15')));
    });
  });

  testWidgets(
      'conversation tile keeps participant, listing, and unread context', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketplaceConversationTile(
            participantName: 'Jordan Buyer',
            listingTitle: '24-inch carbon steel pipe',
            lastMessage: 'Can we schedule pickup Friday?',
            timestamp: '2:15 PM',
            unread: 3,
            avatar: const CircleAvatar(child: Text('J')),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Jordan Buyer'), findsOneWidget);
    expect(find.text('24-inch carbon steel pipe'), findsOneWidget);
    expect(find.text('Can we schedule pickup Friday?'), findsOneWidget);
    expect(find.text('2:15 PM'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('chat bubbles adapt their maximum width to the viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(400, 600)),
          child: Scaffold(
            body: MarketplaceChatBubble(
              text: 'The delivery window works for me.',
              isMine: true,
              hiddenByModeration: false,
              timestamp: '10:12 AM',
            ),
          ),
        ),
      ),
    );

    expect(find.text('The delivery window works for me.'), findsOneWidget);
    expect(find.text('10:12 AM'), findsOneWidget);
    final narrowBubble = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('The delivery window works for me.'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(narrowBubble.constraints?.maxWidth, closeTo(312, 0.01));

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(1000, 700)),
          child: Scaffold(
            body: MarketplaceChatBubble(
              text: 'The delivery window works for me.',
              isMine: true,
              hiddenByModeration: false,
              timestamp: '10:12 AM',
            ),
          ),
        ),
      ),
    );

    final wideBubble = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('The delivery window works for me.'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(wideBubble.constraints?.maxWidth, 520);
  });

  test('messaging history and composer retain bounded safety guards', () {
    expect(maximumActivityHistoryLimit, 500);

    final source = File(
      'lib/marketplace/marketplace_messages_page.dart',
    ).readAsStringSync();
    expect(source, contains("const Text('Unread')"));
    expect(source, contains("child: const Text('Load earlier')"));
    expect(
      source,
      contains(
        'if (_sending || _uploading || _blockedByMe || _blockedMe) return;',
      ),
    );
    expect(source, contains('ValueListenableBuilder<TextEditingValue>'));
    expect(source, contains('maxLength: 4000'));
    expect(source, contains('participantUid: buyerUid'));
    expect(
      source,
      contains("offer['buyerDisplayName'] ?? 'Marketplace buyer'"),
    );
  });
}
