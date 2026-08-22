import 'marketplace_command_client.dart';

class ExternalSettlementConfirmationResult {
  const ExternalSettlementConfirmationResult({
    required this.transactionId,
    required this.role,
    required this.buyerConfirmed,
    required this.sellerConfirmed,
    required this.fullyConfirmed,
  });

  final String transactionId;
  final String role;
  final bool buyerConfirmed;
  final bool sellerConfirmed;
  final bool fullyConfirmed;

  factory ExternalSettlementConfirmationResult.fromMap(
    Map<String, dynamic> data,
  ) =>
      ExternalSettlementConfirmationResult(
        transactionId: '${data['transactionId'] ?? ''}'.trim(),
        role: '${data['role'] ?? ''}'.trim(),
        buyerConfirmed: data['buyerConfirmed'] == true,
        sellerConfirmed: data['sellerConfirmed'] == true,
        fullyConfirmed: data['fullyConfirmed'] == true,
      );
}

class ExternalSettlementFeeCheckoutResult {
  const ExternalSettlementFeeCheckoutResult({
    required this.transactionId,
    required this.checkoutSessionId,
    required this.checkoutUri,
    required this.alreadyPaid,
    required this.taxCollectionStatus,
  });

  final String transactionId;
  final String checkoutSessionId;
  final Uri? checkoutUri;
  final bool alreadyPaid;
  final String taxCollectionStatus;

  factory ExternalSettlementFeeCheckoutResult.fromMap(
    Map<String, dynamic> data,
  ) {
    final alreadyPaid = data['alreadyPaid'] == true;
    final rawUrl = '${data['checkoutUrl'] ?? ''}'.trim();
    final uri = rawUrl.isEmpty ? null : validatedStripeCheckoutUri(rawUrl);
    if (!alreadyPaid && uri == null) {
      throw StateError('The secure Stripe checkout link is unavailable.');
    }
    return ExternalSettlementFeeCheckoutResult(
      transactionId: '${data['transactionId'] ?? ''}'.trim(),
      checkoutSessionId: '${data['checkoutSessionId'] ?? ''}'.trim(),
      checkoutUri: uri,
      alreadyPaid: alreadyPaid,
      taxCollectionStatus: '${data['taxCollectionStatus'] ?? ''}'.trim(),
    );
  }
}

Uri validatedStripeCheckoutUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.toLowerCase() != 'checkout.stripe.com') {
    throw StateError('The secure Stripe checkout link is invalid.');
  }
  return uri;
}

class MarketplaceExternalSettlementClient {
  MarketplaceExternalSettlementClient({MarketplaceCommandClient? commandClient})
      : _commands = commandClient ?? MarketplaceCommandClient();

  final MarketplaceCommandClient _commands;

  Future<ExternalSettlementConfirmationResult> confirm(
    String transactionId,
  ) async {
    final id = transactionId.trim();
    if (id.isEmpty) throw ArgumentError('Transaction ID is required.');
    final response = await _commands.execute('confirmExternalSettlement', {
      'transactionId': id,
    });
    final result = ExternalSettlementConfirmationResult.fromMap(response);
    if (result.transactionId.isEmpty) {
      throw StateError('The server returned an invalid settlement confirmation.');
    }
    return result;
  }

  Future<ExternalSettlementFeeCheckoutResult> createFeeCheckout(
    String transactionId,
  ) async {
    final id = transactionId.trim();
    if (id.isEmpty) throw ArgumentError('Transaction ID is required.');
    final response =
        await _commands.execute('createExternalSettlementFeeCheckout', {
      'transactionId': id,
    });
    final result = ExternalSettlementFeeCheckoutResult.fromMap(response);
    if (result.transactionId.isEmpty) {
      throw StateError('The server returned an invalid fee checkout response.');
    }
    return result;
  }
}
