import 'marketplace_notification_service.dart';

class MarketplaceNotificationPresentation {
  const MarketplaceNotificationPresentation({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.actionEnabled,
    this.refreshOnly = false,
  });

  final String title;
  final String description;
  final String actionLabel;
  final bool actionEnabled;
  final bool refreshOnly;
}

MarketplaceNotificationPresentation marketplaceNotificationPresentation(
  MarketplaceNotificationStatus? status,
) {
  return switch (status) {
    MarketplaceNotificationStatus.enabled =>
      const MarketplaceNotificationPresentation(
        title: 'Device notifications enabled',
        description:
            'Offer, message, auction, Dispatch, support, and account-security updates can arrive on this device.',
        actionLabel: 'Turn off',
        actionEnabled: true,
      ),
    MarketplaceNotificationStatus.missingWebConfiguration =>
      const MarketplaceNotificationPresentation(
        title: 'Web notifications are not available in this release',
        description:
            'In-app activity remains available below. Device alerts will become available after the approved web-push configuration is included in a future release.',
        actionLabel: 'Unavailable',
        actionEnabled: false,
      ),
    MarketplaceNotificationStatus.unsupported =>
      const MarketplaceNotificationPresentation(
        title: 'Device notifications are not supported here',
        description:
            'Use the in-app notification centre below to review account and marketplace activity.',
        actionLabel: 'Unsupported',
        actionEnabled: false,
      ),
    MarketplaceNotificationStatus.unavailable =>
      const MarketplaceNotificationPresentation(
        title: 'Notification status could not be checked',
        description:
            'Your in-app activity is still available. Check the connection and refresh the notification status.',
        actionLabel: 'Check again',
        actionEnabled: true,
        refreshOnly: true,
      ),
    MarketplaceNotificationStatus.denied =>
      const MarketplaceNotificationPresentation(
        title: 'Notifications are blocked for this site',
        description:
            'Allow notifications for Pipe Buyer in the browser or device settings, then try again.',
        actionLabel: 'Try again',
        actionEnabled: true,
      ),
    MarketplaceNotificationStatus.notEnabled =>
      const MarketplaceNotificationPresentation(
        title: 'Get important activity on this device',
        description:
            'Receive offer, message, auction, Dispatch, support, and account-security updates.',
        actionLabel: 'Enable',
        actionEnabled: true,
      ),
    null => const MarketplaceNotificationPresentation(
        title: 'Checking device notification availability',
        description:
            'In-app activity remains available while Pipe Buyer checks this device.',
        actionLabel: 'Checking…',
        actionEnabled: false,
      ),
  };
}
