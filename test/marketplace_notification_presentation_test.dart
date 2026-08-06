import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_notification_presentation.dart';
import 'package:pipe_app/marketplace/marketplace_notification_service.dart';

void main() {
  test('missing web configuration never exposes an active Enable action', () {
    final presentation = marketplaceNotificationPresentation(
      MarketplaceNotificationStatus.missingWebConfiguration,
    );
    expect(presentation.actionEnabled, isFalse);
    expect(presentation.actionLabel, 'Unavailable');
    expect(presentation.title, contains('not available'));
  });

  test('temporary status failure offers refresh rather than enable', () {
    final presentation = marketplaceNotificationPresentation(
      MarketplaceNotificationStatus.unavailable,
    );
    expect(presentation.actionEnabled, isTrue);
    expect(presentation.refreshOnly, isTrue);
    expect(presentation.actionLabel, 'Check again');
  });
}
