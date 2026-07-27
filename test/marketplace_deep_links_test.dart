import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/flutter_flow/nav/nav.dart';
import 'package:pipe_app/marketplace/marketplace_deep_links.dart';

void main() {
  test('Marketplace entity links use stable encoded paths', () {
    expect(
        MarketplaceDeepLinks.listing('listing 42'), '/listings/listing%2042');
    expect(MarketplaceDeepLinks.auction('auction-1'), '/auctions/auction-1');
    expect(MarketplaceDeepLinks.profile('member-1'), '/profiles/member-1');
    expect(MarketplaceDeepLinks.conversation('conversation-1'),
        '/conversations/conversation-1');
    expect(MarketplaceDeepLinks.dispatchJob('dispatch job 1'),
        '/dispatch/jobs/dispatch%20job%201');
  });

  test('Marketplace entity links reject unsafe identifiers', () {
    expect(() => MarketplaceDeepLinks.listing(''), throwsArgumentError);
    expect(() => MarketplaceDeepLinks.listing('collection/document'),
        throwsArgumentError);
    expect(
      () => MarketplaceDeepLinks.profile(List.filled(257, 'x').join()),
      throwsArgumentError,
    );
  });

  test('router registers every Phase 1 entity destination', () {
    final router = createRouter(AppStateNotifier.instance);
    addTearDown(router.dispose);
    final paths = router.configuration.routes
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toSet();
    expect(
      paths,
      containsAll(const {
        '/',
        '/listings/:listingId',
        '/auctions/:listingId',
        '/profiles/:userUid',
        '/conversations/:conversationId',
        '/dispatch/jobs/:jobId',
      }),
    );
  });
}
