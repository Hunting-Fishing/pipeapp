import 'package:cloud_firestore/cloud_firestore.dart';
import 'marketplace_command_client.dart';
import 'marketplace_money.dart';

enum EscrowStatus {
  initiated,
  secured,
  dispatched,
  inspectionPending,
  approved,
  released,
  disputed,
  refunded,
}

EscrowStatus parseEscrowStatus(String? value) {
  final status = '${value ?? ''}'.toLowerCase().trim();
  switch (status) {
    case 'secured':
    case 'escrow_secured':
    case 'funded':
      return EscrowStatus.secured;
    case 'dispatched':
    case 'in_transit':
      return EscrowStatus.dispatched;
    case 'inspection_pending':
    case 'delivered':
      return EscrowStatus.inspectionPending;
    case 'approved':
    case 'inspection_approved':
      return EscrowStatus.approved;
    case 'released':
    case 'funds_released':
    case 'completed':
      return EscrowStatus.released;
    case 'disputed':
    case 'under_review':
      return EscrowStatus.disputed;
    case 'refunded':
    case 'cancelled':
      return EscrowStatus.refunded;
    case 'initiated':
    default:
      return EscrowStatus.initiated;
  }
}

String formatEscrowStatus(EscrowStatus status) => switch (status) {
      EscrowStatus.initiated => 'Funds Initiated',
      EscrowStatus.secured => 'Escrow Secured',
      EscrowStatus.dispatched => 'In Transit / Dispatched',
      EscrowStatus.inspectionPending => 'Pending Buyer Inspection',
      EscrowStatus.approved => 'Inspection Approved',
      EscrowStatus.released => 'Funds Released to Seller',
      EscrowStatus.disputed => 'Under Dispute Review',
      EscrowStatus.refunded => 'Funds Refunded',
    };

class EscrowTransaction {
  const EscrowTransaction({
    required this.id,
    required this.listingId,
    required this.buyerUid,
    required this.sellerUid,
    required this.amount,
    required this.status,
    required this.currency,
    this.createdAt,
    this.updatedAt,
    this.inspectionDays = 3,
    this.disputeReason,
  });

  final String id;
  final String listingId;
  final String buyerUid;
  final String sellerUid;
  final num amount;
  final EscrowStatus status;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int inspectionDays;
  final String? disputeReason;

  factory EscrowTransaction.fromMap(String id, Map<String, dynamic> map) {
    return EscrowTransaction(
      id: id,
      listingId: '${map['listingId'] ?? ''}',
      buyerUid: '${map['buyerUid'] ?? ''}',
      sellerUid: '${map['sellerUid'] ?? ''}',
      amount: map['amount'] as num? ?? map['price'] as num? ?? 0,
      status: parseEscrowStatus('${map['status'] ?? map['escrowStatus']}'),
      currency: '${map['currency'] ?? 'CAD'}',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      inspectionDays: (map['inspectionDays'] as num?)?.toInt() ?? 3,
      disputeReason: map['disputeReason'] as String?,
    );
  }

  String get formattedAmount => marketplaceMoney(amount);
}

class MarketplaceEscrowRepository {
  MarketplaceEscrowRepository({
    MarketplaceCommandClient? commandClient,
  }) : _commands = commandClient ?? MarketplaceCommandClient();

  final MarketplaceCommandClient _commands;

  Future<void> initiateEscrow({
    required String listingId,
    required num amount,
    required String buyerUid,
    required String sellerUid,
    int inspectionDays = 3,
  }) async {
    await _commands.execute('initiateEscrowPayment', {
      'requestId': 'escrow-initiate-$listingId',
      'listingId': listingId,
      'amount': amount,
      'buyerUid': buyerUid,
      'sellerUid': sellerUid,
      'inspectionDays': inspectionDays,
    });
  }

  Future<void> approveInspection({required String transactionId}) async {
    await _commands.execute('approveEscrowInspection', {
      'requestId': 'escrow-approve-$transactionId',
      'transactionId': transactionId,
    });
  }

  Future<void> releaseFunds({required String transactionId}) async {
    await _commands.execute('releaseEscrowFunds', {
      'requestId': 'escrow-release-$transactionId',
      'transactionId': transactionId,
    });
  }

  Future<void> openDispute({
    required String transactionId,
    required String reason,
  }) async {
    await _commands.execute('openEscrowDispute', {
      'requestId': 'escrow-dispute-$transactionId',
      'transactionId': transactionId,
      'reason': reason.trim(),
    });
  }
}
