import 'package:flutter/material.dart';

@immutable
class MarketplaceDestinationRequest {
  const MarketplaceDestinationRequest(this.pageIndex);

  final int pageIndex;
}

/// Coordinates top-level marketplace navigation from pages pushed above the
/// tab scaffold and from simple Home intent actions.
class MarketplaceNavigation {
  MarketplaceNavigation._();

  static final ValueNotifier<int> homeRequests = ValueNotifier<int>(0);
  static final ValueNotifier<MarketplaceDestinationRequest?>
  destinationRequests = ValueNotifier<MarketplaceDestinationRequest?>(null);
  static final ValueNotifier<int> wantedRequests = ValueNotifier<int>(0);

  static void goHome(BuildContext context) {
    homeRequests.value++;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static void goToDestination(BuildContext context, int pageIndex) {
    destinationRequests.value = MarketplaceDestinationRequest(pageIndex);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static void goToBrowse(BuildContext context) => goToDestination(context, 1);

  static void goToSell(BuildContext context) => goToDestination(context, 2);

  static void goToDispatch(BuildContext context) => goToDestination(context, 7);

  static void goToWanted(BuildContext context) {
    wantedRequests.value++;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
