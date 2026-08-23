import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_timed_buying_trust.dart';

void main() {
  test('viewer participation reports outbid position from offer sequence', () {
    final state = deriveTimedBuyingViewerParticipation(
      viewerUid: 'buyer-1',
      listing: const {
        'highBidderUid': 'buyer-2',
        'currentBid': 44500,
        'bidCount': 8,
      },
      viewerOffers: const [
        {
          'bidderUid': 'buyer-1',
          'amount': 39000,
          'sequenceNumber': 3,
        },
        {
          'bidderUid': 'buyer-1',
          'amount': 43500,
          'sequenceNumber': 7,
        },
      ],
    );

    expect(state.hasParticipated, isTrue);
    expect(state.leading, isFalse);
    expect(state.outbid, isTrue);
    expect(state.viewerTopOffer, 43500);
    expect(state.currentLead, 44500);
    expect(state.offersAhead, 1);
    expect(state.amountBehind, 1000);
    expect(state.compactStatusLabel, 'OUTBID • 1 OFFER AHEAD');
  });

  test('viewer participation reports leading state', () {
    final state = deriveTimedBuyingViewerParticipation(
      viewerUid: 'buyer-1',
      listing: const {
        'highBidderUid': 'buyer-1',
        'currentBid': 45500,
        'bidCount': 9,
      },
      viewerOffers: const [
        {
          'bidderUid': 'buyer-1',
          'amount': 45500,
          'sequenceNumber': 9,
        },
      ],
    );

    expect(state.leading, isTrue);
    expect(state.offersAhead, 0);
    expect(state.amountBehind, 0);
    expect(state.compactStatusLabel, 'YOU’RE LEADING');
  });

  test('participant identity uses You for the signed-in viewer', () {
    final identity = TimedBuyingParticipantIdentity.fromBid(
      const {
        'bidderUid': 'buyer-1',
        'bidderPublicName': 'Alex B.',
        'bidderVerified': true,
        'bidderAccountType': 'personal',
      },
      viewerUid: 'buyer-1',
    );

    expect(identity.displayName, 'You');
    expect(identity.verified, isTrue);
    expect(identity.isViewer, isTrue);
  });

  testWidgets('outbid participation badge exposes offers ahead', (tester) async {
    const state = TimedBuyingViewerParticipation(
      hasParticipated: true,
      leading: false,
      viewerTopOffer: 43500,
      currentLead: 44500,
      ownOfferCount: 4,
      offersAhead: 1,
      amountBehind: 1000,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimedBuyingParticipationBadge(participation: state),
        ),
      ),
    );

    expect(find.text('OUTBID • 1 OFFER AHEAD'), findsOneWidget);
  });

  testWidgets('activity header identifies verified viewer offer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimedBuyingOfferActivityHeader(
            viewerUid: 'buyer-1',
            bid: {
              'bidderUid': 'buyer-1',
              'bidderPublicName': 'Alex B.',
              'bidderVerified': true,
              'bidderAccountType': 'personal',
              'amount': 43500,
              'status': 'outbid',
              'sequenceNumber': 7,
            },
          ),
        ),
      ),
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.text('Verified member'), findsOneWidget);
    expect(find.text('YOU • OUTBID'), findsOneWidget);
    expect(find.text('Offer #7'), findsOneWidget);
  });

  testWidgets('trust strip states authenticated non-anonymous activity',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TimedBuyingTrustStrip()),
      ),
    );

    expect(find.textContaining('signed-in PipeBuyer account'), findsOneWidget);
    expect(find.textContaining('No anonymous timed offers'), findsOneWidget);
  });
}
