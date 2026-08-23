import 'marketplace_command_client.dart';

bool isValidStripeCheckoutUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'checkout.stripe.com' &&
      uri.userInfo.isEmpty;
}

bool isValidStripeBillingPortalUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'billing.stripe.com' &&
      uri.userInfo.isEmpty;
}

class MarketplaceDispatchSubscriptionPlan {
  const MarketplaceDispatchSubscriptionPlan({
    required this.currency,
    required this.unitAmountMinor,
    required this.interval,
  });

  final String currency;
  final int unitAmountMinor;
  final String interval;

  factory MarketplaceDispatchSubscriptionPlan.fromMap(
    Map<String, dynamic> data,
  ) {
    final currency = '${data['currency'] ?? ''}'.trim().toUpperCase();
    final amount = data['unitAmountMinor'];
    final interval = '${data['interval'] ?? ''}'.trim().toLowerCase();
    if (currency.isEmpty ||
        amount is! num ||
        amount.toInt() <= 0 ||
        amount.toInt() != amount ||
        !const {'month', 'year'}.contains(interval)) {
      throw StateError('The Dispatch billing catalog is unavailable.');
    }
    return MarketplaceDispatchSubscriptionPlan(
      currency: currency,
      unitAmountMinor: amount.toInt(),
      interval: interval,
    );
  }

  String get formattedPrice {
    final major = unitAmountMinor / 100;
    final amount = major == major.roundToDouble()
        ? major.toStringAsFixed(0)
        : major.toStringAsFixed(2);
    return '$currency \$$amount';
  }
}

class MarketplaceDispatchSubscriptionStatus {
  const MarketplaceDispatchSubscriptionStatus({
    required this.hasRecord,
    required this.plan,
    required this.providerStatus,
    required this.billingStatus,
    required this.entitlementActive,
    required this.paymentIssue,
    required this.reviewRequired,
    required this.checkoutOpen,
    required this.processing,
    required this.alreadySubscribed,
    required this.billingAvailable,
    required this.canStartCheckout,
    required this.canManageBilling,
    required this.monthly,
    required this.yearly,
  });

  final bool hasRecord;
  final String plan;
  final String providerStatus;
  final String billingStatus;
  final bool entitlementActive;
  final bool paymentIssue;
  final bool reviewRequired;
  final bool checkoutOpen;
  final bool processing;
  final bool alreadySubscribed;
  final bool billingAvailable;
  final bool canStartCheckout;
  final bool canManageBilling;
  final MarketplaceDispatchSubscriptionPlan monthly;
  final MarketplaceDispatchSubscriptionPlan yearly;

  factory MarketplaceDispatchSubscriptionStatus.fromMap(
    Map<String, dynamic> data,
  ) {
    bool requiredBool(String key) {
      final value = data[key];
      if (value is! bool) {
        throw StateError('Dispatch subscription status is unavailable.');
      }
      return value;
    }

    final rawPlans = data['plans'];
    if (rawPlans is! Map) {
      throw StateError('The Dispatch billing catalog is unavailable.');
    }
    final plans = Map<String, dynamic>.from(rawPlans);
    final rawMonthly = plans['monthly'];
    final rawYearly = plans['yearly'];
    if (rawMonthly is! Map || rawYearly is! Map) {
      throw StateError('The Dispatch billing catalog is unavailable.');
    }

    final plan = '${data['plan'] ?? ''}'.trim().toLowerCase();
    if (plan.isNotEmpty && !const {'monthly', 'yearly'}.contains(plan)) {
      throw StateError('Dispatch subscription status is unavailable.');
    }

    return MarketplaceDispatchSubscriptionStatus(
      hasRecord: requiredBool('hasRecord'),
      plan: plan,
      providerStatus: '${data['providerStatus'] ?? ''}'.trim().toLowerCase(),
      billingStatus: '${data['billingStatus'] ?? ''}'.trim().toLowerCase(),
      entitlementActive: requiredBool('entitlementActive'),
      paymentIssue: requiredBool('paymentIssue'),
      reviewRequired: requiredBool('reviewRequired'),
      checkoutOpen: requiredBool('checkoutOpen'),
      processing: requiredBool('processing'),
      alreadySubscribed: requiredBool('alreadySubscribed'),
      // Missing on an older backend deployment means unavailable, not enabled.
      billingAvailable: data['billingAvailable'] == true,
      canStartCheckout: requiredBool('canStartCheckout'),
      canManageBilling: requiredBool('canManageBilling'),
      monthly: MarketplaceDispatchSubscriptionPlan.fromMap(
        Map<String, dynamic>.from(rawMonthly),
      ),
      yearly: MarketplaceDispatchSubscriptionPlan.fromMap(
        Map<String, dynamic>.from(rawYearly),
      ),
    );
  }
}

class MarketplaceDispatchCheckoutResult {
  const MarketplaceDispatchCheckoutResult({
    required this.plan,
    required this.alreadySubscribed,
    required this.processing,
    required this.alreadyCreated,
    required this.checkoutUrl,
  });

  final String plan;
  final bool alreadySubscribed;
  final bool processing;
  final bool alreadyCreated;
  final String checkoutUrl;

  bool get canLaunchCheckout => checkoutUrl.isNotEmpty;

  factory MarketplaceDispatchCheckoutResult.fromMap(
    Map<String, dynamic> data,
  ) {
    final plan = '${data['plan'] ?? ''}'.trim().toLowerCase();
    if (!const {'monthly', 'yearly'}.contains(plan)) {
      throw StateError('The Dispatch Checkout response is invalid.');
    }
    final alreadySubscribed = data['alreadySubscribed'] == true;
    final processing = data['processing'] == true;
    final alreadyCreated = data['alreadyCreated'] == true;
    final checkoutUrl = '${data['checkoutUrl'] ?? ''}'.trim();
    if (checkoutUrl.isNotEmpty && !isValidStripeCheckoutUrl(checkoutUrl)) {
      throw StateError('The secure Stripe Checkout link is invalid.');
    }
    if (!alreadySubscribed && !processing && checkoutUrl.isEmpty) {
      throw StateError('The secure Stripe Checkout link is unavailable.');
    }
    return MarketplaceDispatchCheckoutResult(
      plan: plan,
      alreadySubscribed: alreadySubscribed,
      processing: processing,
      alreadyCreated: alreadyCreated,
      checkoutUrl: checkoutUrl,
    );
  }
}

class MarketplaceDispatchBillingPortalResult {
  const MarketplaceDispatchBillingPortalResult({required this.portalUrl});

  final String portalUrl;

  factory MarketplaceDispatchBillingPortalResult.fromMap(
    Map<String, dynamic> data,
  ) {
    final portalUrl = '${data['portalUrl'] ?? ''}'.trim();
    if (!isValidStripeBillingPortalUrl(portalUrl)) {
      throw StateError('The secure Stripe billing management link is invalid.');
    }
    return MarketplaceDispatchBillingPortalResult(portalUrl: portalUrl);
  }
}

class MarketplaceDispatchSubscriptionClient {
  MarketplaceDispatchSubscriptionClient({MarketplaceCommandClient? commands})
      : _commands = commands ?? MarketplaceCommandClient();

  final MarketplaceCommandClient _commands;

  Future<MarketplaceDispatchSubscriptionStatus> getStatus() async {
    final data = await _commands.execute(
      'getDispatchSubscriptionStatus',
      const <String, Object?>{},
    );
    return MarketplaceDispatchSubscriptionStatus.fromMap(data);
  }

  Future<MarketplaceDispatchCheckoutResult> createCheckout(String plan) async {
    final normalized = plan.trim().toLowerCase();
    if (!const {'monthly', 'yearly'}.contains(normalized)) {
      throw ArgumentError.value(plan, 'plan', 'Choose Monthly or Yearly.');
    }
    final data = await _commands.execute(
      'createDispatchSubscriptionCheckout',
      <String, Object?>{'plan': normalized},
      timeout: const Duration(seconds: 45),
    );
    return MarketplaceDispatchCheckoutResult.fromMap(data);
  }

  Future<MarketplaceDispatchBillingPortalResult> createBillingPortal() async {
    final data = await _commands.execute(
      'createDispatchBillingPortalSession',
      const <String, Object?>{},
      timeout: const Duration(seconds: 30),
    );
    return MarketplaceDispatchBillingPortalResult.fromMap(data);
  }
}
