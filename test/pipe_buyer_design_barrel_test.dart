import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/design/pipe_buyer_design.dart';

void main() {
  test('formal design barrel exports the complete marketplace presentation set', () {
    const step = PipeBuyerFormStepData(
      label: 'Category',
      icon: Icons.category_outlined,
    );
    const trust = PipeBuyerTrustItemData(
      icon: Icons.verified_outlined,
      title: 'Verified Businesses',
      subtitle: 'Identity and account checks',
    );
    const specification = PipeBuyerSpecItemData(
      label: 'Grade',
      value: 'J-55',
    );
    const dispatchMetric = PipeBuyerDispatchMetricData(
      label: 'Active Loads',
      value: '12',
      icon: Icons.local_shipping_outlined,
    );
    const dealRow = PipeBuyerDealRowData(
      label: 'Quantity',
      value: '20,000 ft',
    );
    const health = PipeBuyerHealthItemData(
      label: 'Photos',
      complete: true,
    );

    expect(step.label, 'Category');
    expect(trust.title, 'Verified Businesses');
    expect(specification.value, 'J-55');
    expect(dispatchMetric.value, '12');
    expect(dealRow.value, '20,000 ft');
    expect(health.complete, isTrue);
    expect(PipeBuyerColors.orange, const Color(0xFFFF6A00));
    expect(PipeBuyerBrowseMode.values, contains(PipeBuyerBrowseMode.map));
  });
}
