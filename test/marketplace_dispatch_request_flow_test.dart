import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_request_flow.dart';

void main() {
  group('DispatchRequestFlow path selection', () {
    test('transport services use freight route questions', () {
      expect(
        DispatchRequestFlow.pathForServiceCodes(
          const <String>['transport_pipe_hauling'],
        ),
        DispatchRequestPath.freightRoute,
      );
      expect(
        DispatchRequestFlow.needsDelivery(
          const <String>['transport_pipe_hauling'],
        ),
        isTrue,
      );
    });

    test('pilot services preserve route questions', () {
      expect(
        DispatchRequestFlow.pathForServiceCodes(
          const <String>['pilot_route_survey'],
        ),
        DispatchRequestPath.freightRoute,
      );
    });

    test('crane and industrial services use field-service questions', () {
      expect(
        DispatchRequestFlow.pathForServiceCodes(
          const <String>['crane_picker_truck'],
        ),
        DispatchRequestPath.fieldService,
      );
      expect(
        DispatchRequestFlow.pathForServiceCodes(
          const <String>['field_vacuum_truck'],
        ),
        DispatchRequestPath.fieldService,
      );
    });

    test('a mixed request keeps route questions when freight is included', () {
      expect(
        DispatchRequestFlow.pathForServiceCodes(
          const <String>['field_vacuum_truck', 'transport_flat_deck'],
        ),
        DispatchRequestPath.freightRoute,
      );
    });
  });

  group('DispatchRequestFlow review validation', () {
    test('field service does not require a delivery point', () {
      final issues = DispatchRequestFlow.reviewIssues(
        serviceCodes: const <String>['field_vacuum_truck'],
        pickupLabel: 'Lease site 12-34',
        deliveryLabel: '',
        requestedAt: DateTime(2026, 9, 5, 8),
        details: 'Vacuum truck required for tank cleanout.',
        contactPreference: DispatchContactPreference.inApp,
      );
      expect(issues, isEmpty);
    });

    test('freight review requires pickup and delivery', () {
      final issues = DispatchRequestFlow.reviewIssues(
        serviceCodes: const <String>['transport_pipe_hauling'],
        pickupLabel: '',
        deliveryLabel: '',
        requestedAt: DateTime(2026, 9, 5, 8),
        details: 'Thirty joints of 4.5 inch tubing.',
        contactPreference: DispatchContactPreference.inApp,
      );
      expect(issues.map((issue) => issue.field), containsAll(<String>[
        'pickup',
        'delivery',
      ]));
    });

    test('phone preference requires a phone number', () {
      final issues = DispatchRequestFlow.reviewIssues(
        serviceCodes: const <String>['field_vacuum_truck'],
        pickupLabel: 'Lease site 12-34',
        deliveryLabel: '',
        requestedAt: DateTime(2026, 9, 5, 8),
        details: 'Vacuum truck required.',
        contactPreference: DispatchContactPreference.phone,
      );
      expect(issues.single.field, 'phone');
    });
  });
}
