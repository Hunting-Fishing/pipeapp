import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'marketplace_money.dart';

class MarketplaceAuctionRepository {
  MarketplaceAuctionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to bid.');
    return uid;
  }

  Future<void> placeBid({
    required String listingId,
    required num amount,
  }) async {
    final listing = _firestore.collection('public_listings').doc(listingId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(listing);
      final data = snapshot.data();
      if (data == null || data['transactionType'] != 'Auction') {
        throw StateError('This auction is unavailable.');
      }
      if (data['sellerUid'] == _uid) {
        throw StateError('Sellers cannot bid on their own auction.');
      }
      final now = DateTime.now();
      final start = (data['auctionStartAt'] as Timestamp?)?.toDate();
      final end = (data['auctionEndAt'] as Timestamp?)?.toDate();
      if (start == null || end == null || now.isBefore(start)) {
        throw StateError('This auction has not started.');
      }
      if (!now.isBefore(end)) throw StateError('This auction has ended.');
      final starting =
          data['startingBid'] as num? ?? data['price'] as num? ?? 0;
      final current = data['currentBid'] as num? ?? 0;
      final increment = data['minimumBidIncrement'] as num? ?? 1;
      final minimum = current > 0 ? current + increment : starting;
      if (amount < minimum) {
        throw StateError(
            'The next bid must be at least ${marketplaceMoney(minimum)}.');
      }
      final bid = _firestore.collection('auction_bids').doc();
      transaction.set(bid, {
        'listingId': listingId,
        'sellerUid': data['sellerUid'],
        'bidderUid': _uid,
        'amount': amount,
        'currency': data['currency'] ?? 'CAD',
        'status': 'leading',
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(listing, {
        'currentBid': amount,
        'highBidderUid': _uid,
        'bidCount': FieldValue.increment(1),
        'lastBidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (data['notifyNewBids'] != false) {
        transaction.set(
            _firestore
                .collection('users')
                .doc('${data['sellerUid']}')
                .collection('notifications')
                .doc(),
            {
              'recipientUid': data['sellerUid'],
              'actorUid': _uid,
              'type': 'offer',
              'listingId': listingId,
              'title':
                  amount >= (data['reservePrice'] as num? ?? double.infinity)
                      ? 'Auction reserve reached'
                      : 'New auction bid',
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
      }
    });
  }

  Future<void> buyNow({required String listingId}) async {
    final listing = _firestore.collection('public_listings').doc(listingId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(listing);
      final data = snapshot.data() ?? {};
      final price = data['buyItNowPrice'] as num?;
      if (data['transactionType'] != 'Auction' || price == null || price <= 0) {
        throw StateError('Buy It Now is unavailable.');
      }
      if (data['sellerUid'] == _uid) {
        throw StateError('This is your auction.');
      }
      final end = (data['auctionEndAt'] as Timestamp?)?.toDate();
      if (end == null || !DateTime.now().isBefore(end)) {
        throw StateError('This auction has ended.');
      }
      final bid = _firestore.collection('auction_bids').doc();
      transaction.set(bid, {
        'listingId': listingId,
        'sellerUid': data['sellerUid'],
        'bidderUid': _uid,
        'amount': price,
        'currency': data['currency'] ?? 'CAD',
        'status': 'buy_now',
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(listing, {
        'currentBid': price,
        'highBidderUid': _uid,
        'buyNowBuyerUid': _uid,
        'acceptedBidAmount': price,
        'auctionStatus': 'bought_now',
        'auctionEndAt': FieldValue.serverTimestamp(),
        'bidCount': FieldValue.increment(1),
        'lastBidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
          _firestore
              .collection('users')
              .doc('${data['sellerUid']}')
              .collection('notifications')
              .doc(),
          {
            'recipientUid': data['sellerUid'],
            'actorUid': _uid,
            'type': 'offer',
            'listingId': listingId,
            'title': 'Auction purchased with Buy It Now',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    });
  }

  Future<void> acceptLeadingBidBelowReserve({required String listingId}) async {
    final listingRef = _firestore.collection('public_listings').doc(listingId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(listingRef);
      final data = snapshot.data() ?? {};
      if (data['sellerUid'] != _uid) {
        throw StateError('Only the seller can accept this bid.');
      }
      final current = data['currentBid'] as num? ?? 0;
      final reserve = data['reservePrice'] as num?;
      final bidderUid = '${data['highBidderUid'] ?? ''}';
      if (current <= 0 || bidderUid.isEmpty) {
        throw StateError('There is no leading bid to accept.');
      }
      if (reserve == null || current >= reserve) {
        throw StateError('The leading bid is not below the reserve.');
      }
      transaction.update(listingRef, {
        'auctionStatus': 'accepted_below_reserve',
        'acceptedBidAmount': current,
        'acceptedBidderUid': bidderUid,
        'auctionEndAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
          _firestore
              .collection('users')
              .doc(bidderUid)
              .collection('notifications')
              .doc(),
          {
            'recipientUid': bidderUid,
            'actorUid': _uid,
            'type': 'offer',
            'listingId': listingId,
            'title': 'Your auction bid was accepted',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    });
  }

  Future<void> withdrawBid({
    required String listingId,
    required String bidId,
  }) async {
    final listingRef = _firestore.collection('public_listings').doc(listingId);
    final bidRef = _firestore.collection('auction_bids').doc(bidId);
    final candidates = await _firestore
        .collection('auction_bids')
        .where('listingId', isEqualTo: listingId)
        .get();
    await _firestore.runTransaction((transaction) async {
      final listingSnapshot = await transaction.get(listingRef);
      final bidSnapshot = await transaction.get(bidRef);
      final listing = listingSnapshot.data() ?? {};
      final bid = bidSnapshot.data() ?? {};
      final start = (listing['auctionStartAt'] as Timestamp?)?.toDate();
      final end = (listing['auctionEndAt'] as Timestamp?)?.toDate();
      if (listing['customAuction'] != true ||
          start == null ||
          DateTime.now().isBefore(start.add(const Duration(days: 32)))) {
        throw StateError(
            'Bid withdrawal is available after day 32 of a custom auction.');
      }
      if (end == null || !DateTime.now().isBefore(end)) {
        throw StateError('This auction has ended.');
      }
      if (bid['bidderUid'] != _uid || bid['status'] == 'withdrawn') {
        throw StateError('This bid cannot be withdrawn.');
      }
      transaction.update(bidRef, {
        'status': 'withdrawn',
        'withdrawnByUid': _uid,
        'withdrawnAt': FieldValue.serverTimestamp(),
      });
      final isLeader = listing['highBidderUid'] == _uid &&
          (listing['currentBid'] as num? ?? 0) == (bid['amount'] as num? ?? -1);
      if (!isLeader) return;
      final remaining = candidates.docs
          .where((doc) =>
              doc.id != bidId &&
              doc.data()['status'] != 'withdrawn' &&
              doc.data()['status'] != 'buy_now')
          .toList()
        ..sort((a, b) => (b.data()['amount'] as num? ?? 0)
            .compareTo(a.data()['amount'] as num? ?? 0));
      final next = remaining.isEmpty ? null : remaining.first.data();
      transaction.update(listingRef, {
        'currentBid': next?['amount'] ?? 0,
        'highBidderUid': next?['bidderUid'] ?? '',
        'withdrawnBidCount': FieldValue.increment(1),
        'lastWithdrawalBidId': bidId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
