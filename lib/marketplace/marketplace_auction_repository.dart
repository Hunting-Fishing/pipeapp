import 'marketplace_command_client.dart';

class MarketplaceAuctionRepository {
  MarketplaceAuctionRepository({
    MarketplaceCommandClient? commandClient,
  }) : _commands = commandClient ?? MarketplaceCommandClient();

  final MarketplaceCommandClient _commands;

  Future<void> placeBid({
    required String listingId,
    required num amount,
  }) async {
    await _commands.execute('placeAuctionBid', {
      'listingId': listingId,
      'amount': amount,
    });
  }

  Future<void> buyNow({required String listingId}) async {
    await _commands.execute('buyAuctionNow', {
      'listingId': listingId,
    });
  }

  Future<void> acceptLeadingBidBelowReserve({
    required String listingId,
  }) async {
    await _commands.execute('acceptAuctionBidBelowReserve', {
      'listingId': listingId,
    });
  }

  Future<void> withdrawBid({
    required String listingId,
    required String bidId,
  }) async {
    await _commands.execute('withdrawAuctionBid', {
      'listingId': listingId,
      'bidId': bidId,
    });
  }
}
