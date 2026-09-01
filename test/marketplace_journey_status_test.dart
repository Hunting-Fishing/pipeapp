import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_journey_status.dart';

void main() {
  group('offer journey status', () {
    test('seller sees a pending offer as their next action', () {
      final status = marketplaceOfferJourneyStatus(
        status: 'pending',
        viewerIsSeller: true,
      );

      expect(status.currentStatus, 'Offer waiting for your review');
      expect(status.responsibleParty, 'Seller (you)');
      expect(status.nextAction, contains('accept'));
      expect(status.nextAction, contains('counter'));
    });

    test('buyer sees a pending offer as waiting on seller', () {
      final status = marketplaceOfferJourneyStatus(
        status: 'pending',
        viewerIsSeller: false,
      );

      expect(status.currentStatus, 'Offer sent to the seller');
      expect(status.responsibleParty, 'Seller');
      expect(status.nextAction, contains('Wait for the seller'));
    });

    test('unknown offer status fails safe to support', () {
      final status = marketplaceOfferJourneyStatus(
        status: 'mystery_state',
        viewerIsSeller: false,
      );

      expect(status.currentStatus, 'Offer status needs review');
      expect(status.responsibleParty, 'Pipe Buyer support');
    });
  });

  group('Wanted journey status', () {
    test(
      'open request with no activity keeps matching responsibility clear',
      () {
        final status = marketplaceWantedJourneyStatus({
          'status': 'active',
          'matchCount': 0,
          'responseCount': 0,
        });

        expect(
          status.currentStatus,
          'Wanted request open • matching in progress',
        );
        expect(status.responsibleParty, 'Pipe Buyer matching');
        expect(status.nextAction, contains('continue matching'));
      },
    );

    test('open request with matches tells buyer to review them', () {
      final status = marketplaceWantedJourneyStatus({
        'status': 'active',
        'matchCount': 3,
        'responseCount': 1,
      });

      expect(status.currentStatus, 'Wanted request open • matches available');
      expect(status.responsibleParty, 'Buyer (you)');
      expect(
        status.nextAction,
        contains('Review the suggested Marketplace matches'),
      );
    });

    test('paused request assigns reactivate or fulfill decision to buyer', () {
      final status = marketplaceWantedJourneyStatus({'status': 'paused'});

      expect(status.currentStatus, 'Wanted request paused');
      expect(status.responsibleParty, 'Buyer (you)');
      expect(status.nextAction, contains('Reactivate'));
      expect(status.nextAction, contains('mark it fulfilled'));
    });

    test('fulfilled request is terminal without calling it sold', () {
      final status = marketplaceWantedJourneyStatus({'status': 'fulfilled'});

      expect(status.currentStatus, 'Wanted request fulfilled');
      expect(status.currentStatus, isNot(contains('sold')));
      expect(status.responsibleParty, 'No action required');
      expect(status.tone, MarketplaceJourneyTone.success);
    });

    test('expired request points to the existing renew path', () {
      final status = marketplaceWantedJourneyStatus({'status': 'expired'});

      expect(status.currentStatus, 'Wanted request expired');
      expect(status.responsibleParty, 'Buyer (you)');
      expect(status.nextAction, contains('Use Renew'));
    });

    test('unknown Wanted state fails safe to support', () {
      final status = marketplaceWantedJourneyStatus({'status': 'mystery'});

      expect(status.currentStatus, 'Wanted request status needs review');
      expect(status.responsibleParty, 'Pipe Buyer support');
    });
  });

  group('transaction journey status', () {
    test('unpaid transaction clearly assigns payment to buyer', () {
      final buyer = marketplaceTransactionJourneyStatus({
        'status': 'pending_completion',
        'paymentProviderStatus': 'not_started',
      }, viewerIsBuyer: true);
      final seller = marketplaceTransactionJourneyStatus({
        'status': 'pending_completion',
        'paymentProviderStatus': 'not_started',
      }, viewerIsBuyer: false);

      expect(buyer.currentStatus, 'Payment not started');
      expect(buyer.responsibleParty, 'Buyer (you)');
      expect(buyer.nextAction, contains('Complete secure payment'));
      expect(seller.responsibleParty, 'Buyer');
      expect(seller.nextAction, contains('Wait for the buyer'));
    });

    test('checkout-created payment remains a buyer action', () {
      final status = marketplaceTransactionJourneyStatus({
        'status': 'pending_completion',
        'paymentProviderStatus': 'checkout_created',
      }, viewerIsBuyer: true);

      expect(status.currentStatus, 'Secure payment still required');
      expect(status.responsibleParty, 'Buyer (you)');
    });

    test('paid buyer confirmation moves next action to seller', () {
      final status = marketplaceTransactionJourneyStatus({
        'status': 'awaiting_seller_confirmation',
        'paymentProviderStatus': 'paid',
        'buyerConfirmed': true,
        'sellerConfirmed': false,
      }, viewerIsBuyer: false);

      expect(status.currentStatus, 'Buyer confirmation recorded');
      expect(status.responsibleParty, 'Seller (you)');
      expect(status.nextAction, contains('Confirm the sale was fulfilled'));
    });

    test('paid seller confirmation moves next action to buyer', () {
      final status = marketplaceTransactionJourneyStatus({
        'status': 'awaiting_buyer_confirmation',
        'paymentProviderStatus': 'paid',
        'buyerConfirmed': false,
        'sellerConfirmed': true,
      }, viewerIsBuyer: true);

      expect(status.currentStatus, 'Seller confirmation recorded');
      expect(status.responsibleParty, 'Buyer (you)');
      expect(status.nextAction, contains('Confirm the purchase was received'));
    });

    test(
      'external settlement permits completion without claiming Stripe paid',
      () {
        final status = marketplaceTransactionJourneyStatus({
          'status': 'pending_completion',
          'paymentProviderStatus': 'external_agreed',
          'buyerConfirmed': false,
          'sellerConfirmed': false,
        }, viewerIsBuyer: true);

        expect(
          status.currentStatus,
          'External settlement confirmed • completion pending',
        );
        expect(
          status.nextAction,
          contains('Confirm the purchase was received'),
        );
        expect(status.responsibleParty, 'Buyer and Seller');
      },
    );

    test('payment review takes precedence over completion actions', () {
      final status = marketplaceTransactionJourneyStatus({
        'status': 'pending_completion',
        'paymentProviderStatus': 'paid',
        'financialStatus': 'refund_requested',
      }, viewerIsBuyer: true);

      expect(status.currentStatus, 'Payment review in progress');
      expect(status.responsibleParty, 'Pipe Buyer support');
      expect(status.nextAction, contains('Wait for Pipe Buyer review'));
    });

    test('disputed transaction points to support review', () {
      final status = marketplaceTransactionJourneyStatus({
        'status': 'disputed',
        'paymentProviderStatus': 'paid',
      }, viewerIsBuyer: false);

      expect(status.currentStatus, 'Transaction is under review');
      expect(status.responsibleParty, 'Pipe Buyer support');
      expect(status.tone, MarketplaceJourneyTone.danger);
    });

    test('completed Dispatch-selected deal has a bounded Dispatch handoff', () {
      final status = marketplaceTransactionJourneyStatus(
        {
          'status': 'completed',
          'paymentProviderStatus': 'paid',
          'buyerConfirmed': true,
          'sellerConfirmed': true,
        },
        viewerIsBuyer: true,
        dispatchRequested: true,
      );

      expect(status.currentStatus, 'Marketplace transaction complete');
      expect(status.nextAction, contains('Continue the requested delivery'));
      expect(status.nextAction, contains('does not create or charge'));
      expect(status.responsibleParty, 'Buyer and seller');
    });

    test('Timed Buying uses successful-buyer wording', () {
      final status = marketplaceTransactionJourneyStatus(
        {
          'status': 'awaiting_buyer_confirmation',
          'paymentProviderStatus': 'paid',
          'sellerConfirmed': true,
        },
        viewerIsBuyer: false,
        timedBuying: true,
      );

      expect(status.responsibleParty, 'Successful buyer');
    });

    test(
      'unknown active transaction state fails safe instead of inventing action',
      () {
        final status = marketplaceTransactionJourneyStatus({
          'status': 'unexpected_server_state',
          'paymentProviderStatus': 'paid',
        }, viewerIsBuyer: true);

        expect(status.currentStatus, 'Transaction status needs review');
        expect(status.responsibleParty, 'Pipe Buyer support');
        expect(status.nextAction, contains('before confirming completion'));
      },
    );
  });

  test('Wanted owner lifecycle wires the shared guidance card', () {
    final accountHub = File(
      'lib/marketplace/marketplace_account_hub.dart',
    ).readAsStringSync();

    expect(accountHub, contains("import 'marketplace_journey_status.dart';"));
    expect(accountHub, contains('marketplaceWantedJourneyStatus(data)'));
    expect(
      accountHub,
      contains('MarketplaceJourneyStatusCard(status: wantedJourneyStatus)'),
    );
    expect(accountHub, contains("_transitionListing('mark_fulfilled')"));
    expect(accountHub, contains("_transitionListing('pause')"));
    expect(accountHub, contains("_transitionListing('activate')"));
  });

  testWidgets('journey card exposes the three simple user questions', (
    tester,
  ) async {
    const status = MarketplaceJourneyStatus(
      currentStatus: 'Payment received',
      nextAction: 'Confirm the purchase was received.',
      responsibleParty: 'Buyer (you)',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarketplaceJourneyStatusCard(status: status)),
      ),
    );

    expect(find.text('What happens next'), findsOneWidget);
    expect(find.text('Current status'), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);
    expect(find.text('Who acts next'), findsOneWidget);
    expect(find.text('Buyer (you)'), findsOneWidget);
  });

  test(
    'ordinary and Timed Buying surfaces wire the shared journey component',
    () {
      final messages = File(
        'lib/marketplace/marketplace_messages_page.dart',
      ).readAsStringSync();
      final timedBuying = File(
        'lib/marketplace/marketplace_auction_settlement.dart',
      ).readAsStringSync();

      expect(messages, contains("import 'marketplace_journey_status.dart';"));
      expect(messages, contains('marketplaceOfferJourneyStatus('));
      expect(messages, contains('marketplaceTransactionJourneyStatus('));
      expect(messages, contains('MarketplaceJourneyStatusCard('));
      expect(messages, contains('Continue to Dispatch'));
      expect(messages, contains('MarketplaceNavigation.goToDispatch(context)'));

      expect(
        timedBuying,
        contains("import 'marketplace_journey_status.dart';"),
      );
      expect(timedBuying, contains('marketplaceTransactionJourneyStatus('));
      expect(timedBuying, contains('timedBuying: true'));
      expect(timedBuying, contains('MarketplaceJourneyStatusCard('));
    },
  );
}
