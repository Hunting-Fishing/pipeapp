import 'package:flutter/foundation.dart';

const marketplaceNativeSubscriptionUnavailableMessage =
    'Subscription purchasing and provider billing management are unavailable in this app build.';

bool marketplaceHostedMembershipBillingAllowed({bool? isWeb}) =>
    isWeb ?? kIsWeb;
