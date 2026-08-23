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
  ) {
    final transactionId = '${data['transactionId'] ?? ''}'.trim();
    final role = '${data['role'] ?? ''}'.trim();
    final buyerConfirmed = data['buyerConfirmed'] == true;
    final sellerConfirmed = data['sellerConfirmed'] == true;
    final fullyConfirmed = data['fullyConfirmed'] == true;
    if (transactionId.isEmpty || !const {'buyer', 'seller'}.contains(role)) {
      throw StateError('The server returned an invalid settlement confirmation.');
    }
    if (fullyConfirmed && !(buyerConfirmed && sellerConfirmed)) {
      throw StateError('The settlement confirmation state is inconsistent.');
    }
    return ExternalSettlementConfirmationResult(
      transactionId: transactionId,
      role: role,
      buyerConfirmed: buyerConfirmed,
      sellerConfirmed: sellerConfirmed,
      fullyConfirmed: fullyConfirmed,
    );
  }
}

class ExternalSettlementFeeCheckoutResult {
  const ExternalSettlementFeeCheckoutResult({
    required this.transactionId,
    required this.checkoutSessionId,
    required this.checkoutUri,
    required this.alreadyPaid,
    required this.alreadyCreated,
    required this.processing,
    required this.paymentFailed,
    required this.checkoutAttempt,
    required this.taxCollectionStatus,
  });

  final String transactionId;
  final String checkoutSessionId;
  final Uri? checkoutUri;
  final bool alreadyPaid;
  final bool alreadyCreated;
  final bool processing;
  final bool paymentFailed;
  final int? checkoutAttempt;
  final String taxCollectionStatus;

  bool get canLaunchCheckout =>
      checkoutUri != null && !alreadyPaid && !processing && !paymentFailed;

  factory ExternalSettlementFeeCheckoutResult.fromMap(
    Map<String, dynamic> data,
  ) {
    final transactionId = '${data['transactionId'] ?? ''}'.trim();
    final checkoutSessionId = '${data['checkoutSessionId'] ?? ''}'.trim();
    final alreadyPaid = data['alreadyPaid'] == true;
    final alreadyCreated = data['alreadyCreated'] == true;
    final processing = data['processing'] == true;
    final paymentFailed = data['paymentFailed'] == true;
    final rawAttempt = data['checkoutAttempt'];
    final checkoutAttempt = rawAttempt is num && rawAttempt.toInt() > 0
        ? rawAttempt.toInt()
        : null;
    final rawUrl = '${data['checkoutUrl'] ?? ''}'.trim();
    final uri = rawUrl.isEmpty ? null : validatedStripeCheckoutUri(rawUrl);

    if (transactionId.isEmpty) {
      throw StateError('The server returned an invalid fee checkout response.');
    }
    if (alreadyPaid && (processing || paymentFailed)) {
      throw StateError('The marketplace fee payment state is inconsistent.');
    }
    final stateAllowsNoUrl = alreadyPaid || processing || paymentFailed;
    if (!stateAllowsNoUrl && uri == null) {
      throw StateError('The secure Stripe checkout link is unavailable.');
    }
    if (uri != null && checkoutSessionId.isEmpty) {
      throw StateError('The Stripe checkout session reference is unavailable.');
    }

    return ExternalSettlementFeeCheckoutResult(
      transactionId: transactionId,
      checkoutSessionId: checkoutSessionId,
      checkoutUri: uri,
      alreadyPaid: alreadyPaid,
      alreadyCreated: alreadyCreated,
      processing: processing,
      paymentFailed: paymentFailed,
      checkoutAttempt: checkoutAttempt,
      taxCollectionStatus: '${data['taxCollectionStatus'] ?? ''}'.trim(),
    );
  }
}

class ExternalSettlementFeeReceiptResult {
  const ExternalSettlementFeeReceiptResult({
    required this.transactionId,
    required this.chargeId,
    required this.amountMinor,
    required this.currency,
    required this.receiptUri,
  });

  final String transactionId;
  final String chargeId;
  final int amountMinor;
  final String currency;
  final Uri? receiptUri;

  factory ExternalSettlementFeeReceiptResult.fromMap(
    Map<String, dynamic> data,
  ) {
    final transactionId = '${data['transactionId'] ?? ''}'.trim();
    final chargeId = '${data['chargeId'] ?? ''}'.trim();
    final amountMinor = (data['amountMinor'] as num?)?.toInt() ?? 0;
    final currency = '${data['currency'] ?? ''}'.trim().toUpperCase();
    final rawUrl = '${data['receiptUrl'] ?? ''}'.trim();
    final receiptUri = rawUrl.isEmpty ? null : validatedStripeReceiptUri(rawUrl);
    if (transactionId.isEmpty ||
        !chargeId.startsWith('ch_') ||
        amountMinor <= 0 ||
        currency.length != 3) {
      throw StateError('The server returned an invalid fee receipt response.');
    }
    return ExternalSettlementFeeReceiptResult(
      transactionId: transactionId,
      chargeId: chargeId,
      amountMinor: amountMinor,
      currency: currency,
      receiptUri: receiptUri,
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

Uri validatedStripeReceiptUri(String value) {
  final uri = Uri.tryParse(value.trim());
  final host = uri?.host.toLowerCase() ?? '';
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      !(host == 'stripe.com' || host.endsWith('.stripe.com'))) {
    throw StateError('The Stripe receipt link is invalid.');
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
    return ExternalSettlementConfirmationResult.fromMap(response);
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
    return ExternalSettlementFeeCheckoutResult.fromMap(response);
  }

  Future<ExternalSettlementFeeReceiptResult> getFeeReceipt(
    String transactionId,
  ) async {
    final id = transactionId.trim();
    if (id.isEmpty) throw ArgumentError('Transaction ID is required.');
    final response = await _commands.execute('getExternalSettlementFeeReceipt', {
      'transactionId': id,
    });
    return ExternalSettlementFeeReceiptResult.fromMap(response);
  }
}
