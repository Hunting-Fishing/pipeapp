import 'package:flutter/material.dart';

/// Coordinates top-level marketplace navigation from pages pushed above the
/// tab scaffold, such as a conversation opened from a listing sheet.
class MarketplaceNavigation {
  MarketplaceNavigation._();

  static final ValueNotifier<int> homeRequests = ValueNotifier<int>(0);

  static void goHome(BuildContext context) {
    homeRequests.value++;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
