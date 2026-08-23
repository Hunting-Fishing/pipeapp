import 'package:flutter_test/flutter_test.dart';

import 'package:pipe_app/marketplace/marketplace_dispatch_subscription_readiness_view.dart';

void main() {
  test('registered Stripe Tax state is described as authorized', () {
    expect(
      dispatchTaxReadinessDetail(
        stripeTaxReady: true,
        smallSupplierActive: false,
        smallSupplierEvidenceReady: false,
        pendingTaxApproved: false,
        evidenceReason: '',
        assessmentRevision: 0,
        boundRevision: 0,
      ),
      contains('Stripe Tax'),
    );
  });

  test('current small-supplier evidence shows matching revisions', () {
    final detail = dispatchTaxReadinessDetail(
      stripeTaxReady: false,
      smallSupplierActive: true,
      smallSupplierEvidenceReady: true,
      pendingTaxApproved: false,
      evidenceReason: 'authorized',
      assessmentRevision: 7,
      boundRevision: 7,
    );
    expect(detail, contains('assessment revision 7'));
    expect(detail, contains('bound revision 7'));
  });

  test('stale small-supplier evidence is explicit to operator', () {
    final detail = dispatchTaxReadinessDetail(
      stripeTaxReady: false,
      smallSupplierActive: true,
      smallSupplierEvidenceReady: false,
      pendingTaxApproved: false,
      evidenceReason: 'assessment_revision_mismatch',
      assessmentRevision: 8,
      boundRevision: 7,
    );
    expect(detail, contains('stale'));
    expect(detail, contains('assessment revision 8'));
    expect(detail, contains('bound revision 7'));
  });

  test('exceeded small-supplier evidence directs registration review', () {
    final detail = dispatchTaxReadinessDetail(
      stripeTaxReady: false,
      smallSupplierActive: true,
      smallSupplierEvidenceReady: false,
      pendingTaxApproved: false,
      evidenceReason: 'threshold_exceeded',
      assessmentRevision: 9,
      boundRevision: 9,
    );
    expect(detail, contains('threshold has been exceeded'));
    expect(detail, contains('registration review'));
  });

  test('pending registration approved state is explained separately', () {
    expect(
      dispatchTaxReadinessDetail(
        stripeTaxReady: false,
        smallSupplierActive: false,
        smallSupplierEvidenceReady: false,
        pendingTaxApproved: true,
        evidenceReason: '',
        assessmentRevision: 0,
        boundRevision: 0,
      ),
      contains('registration is pending'),
    );
  });
}
