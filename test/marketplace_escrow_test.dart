import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_escrow_repository.dart';

void main() {
  group('EscrowStatus Parsing & Formatting Tests', () {
    test('parses escrow statuses correctly from strings', () {
      expect(parseEscrowStatus('secured'), EscrowStatus.secured);
      expect(parseEscrowStatus('escrow_secured'), EscrowStatus.secured);
      expect(parseEscrowStatus('dispatched'), EscrowStatus.dispatched);
      expect(parseEscrowStatus('inspection_pending'), EscrowStatus.inspectionPending);
      expect(parseEscrowStatus('approved'), EscrowStatus.approved);
      expect(parseEscrowStatus('released'), EscrowStatus.released);
      expect(parseEscrowStatus('disputed'), EscrowStatus.disputed);
      expect(parseEscrowStatus('refunded'), EscrowStatus.refunded);
      expect(parseEscrowStatus('unknown'), EscrowStatus.initiated);
    });

    test('formats escrow status human-readable labels', () {
      expect(formatEscrowStatus(EscrowStatus.secured), 'Escrow Secured');
      expect(formatEscrowStatus(EscrowStatus.released), 'Funds Released to Seller');
      expect(formatEscrowStatus(EscrowStatus.inspectionPending), 'Pending Buyer Inspection');
      expect(formatEscrowStatus(EscrowStatus.disputed), 'Under Dispute Review');
    });

    test('constructs EscrowTransaction from document map', () {
      final now = Timestamp.now();
      final map = {
        'listingId': 'listing-123',
        'buyerUid': 'buyer-456',
        'sellerUid': 'seller-789',
        'amount': 25000,
        'status': 'secured',
        'currency': 'CAD',
        'createdAt': now,
        'inspectionDays': 5,
      };

      final escrow = EscrowTransaction.fromMap('escrow-001', map);

      expect(escrow.id, 'escrow-001');
      expect(escrow.listingId, 'listing-123');
      expect(escrow.amount, 25000);
      expect(escrow.status, EscrowStatus.secured);
      expect(escrow.inspectionDays, 5);
      expect(escrow.formattedAmount, contains('25,000'));
    });
  });
}
