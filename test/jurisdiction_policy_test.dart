import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/property_rights/domain/jurisdiction_policy.dart';
import 'package:pipe_app/property_rights/north_america_design_registry.dart';

void main() {
  final now = DateTime.utc(2026, 7, 19);

  test('country codes are explicit and unsupported codes are rejected', () {
    expect(NorthAmericaCountry.fromCode('ca'), NorthAmericaCountry.canada);
    expect(
        NorthAmericaCountry.fromCode('US'), NorthAmericaCountry.unitedStates);
    expect(NorthAmericaCountry.fromCode('mx'), NorthAmericaCountry.mexico);
    expect(
      () => NorthAmericaCountry.fromCode('GB'),
      throwsA(isA<FormatException>()),
    );
  });

  test('North American design policies never authorize public publishing', () {
    expect(
      NorthAmericaDesignPolicies.all.map((policy) => policy.jurisdiction.value),
      containsAll(<String>['CA', 'US', 'MX']),
    );

    for (final policy in NorthAmericaDesignPolicies.all) {
      final decision = policy.decisionFor(
        ControlledPropertyFeature.publicPropertyListings,
        at: now,
      );
      expect(decision.allowed, isFalse);
      expect(decision.reasons, isNotEmpty);
    }
  });

  test('registry requires an exact subdivision policy and never falls back',
      () {
    final decision = NorthAmericaDesignPolicies.registry.decide(
      jurisdiction: JurisdictionKey(
        country: NorthAmericaCountry.canada,
        subdivisionCode: 'AB',
      ),
      feature: ControlledPropertyFeature.publicPropertyListings,
      at: now,
    );

    expect(decision.allowed, isFalse);
    expect(
      decision.reasons.single,
      contains('Country policies never act as jurisdiction fallbacks'),
    );
  });

  test('complete active policy can authorize its enabled feature', () {
    final policy = _approvedAlbertaPolicy();

    final decision = policy.decisionFor(
      ControlledPropertyFeature.publicPropertyListings,
      at: now,
    );

    expect(decision.allowed, isTrue);
    expect(decision.reasons, isEmpty);
  });

  test('licence/entity jurisdiction mismatch blocks publishing', () {
    final valid = _approvedAlbertaPolicy();
    final invalid = JurisdictionPolicy(
      schemaVersion: valid.schemaVersion,
      id: valid.id,
      jurisdiction: valid.jurisdiction,
      status: valid.status,
      responsibleEntity: const ResponsibleBrokerageEntity(
        id: 'exp-realty-us',
        legalName: 'eXp Realty, LLC',
        country: NorthAmericaCountry.unitedStates,
        active: true,
      ),
      features: valid.features,
      brokerageLicense: valid.brokerageLicense,
      complianceOwnerId: valid.complianceOwnerId,
      requiredFormSetVersion: valid.requiredFormSetVersion,
      legalReviewVersion: valid.legalReviewVersion,
      effectiveAt: valid.effectiveAt,
      expiresAt: valid.expiresAt,
    );

    final decision = invalid.decisionFor(
      ControlledPropertyFeature.publicPropertyListings,
      at: now,
    );

    expect(decision.allowed, isFalse);
    expect(
      decision.reasons,
      contains('Responsible entity does not match the jurisdiction country.'),
    );
  });

  test('client funds need a separate trust approval', () {
    final base = _approvedAlbertaPolicy();
    final policy = JurisdictionPolicy(
      schemaVersion: base.schemaVersion,
      id: base.id,
      jurisdiction: base.jurisdiction,
      status: base.status,
      responsibleEntity: base.responsibleEntity,
      brokerageLicense: base.brokerageLicense,
      complianceOwnerId: base.complianceOwnerId,
      requiredFormSetVersion: base.requiredFormSetVersion,
      legalReviewVersion: base.legalReviewVersion,
      effectiveAt: base.effectiveAt,
      expiresAt: base.expiresAt,
      features: JurisdictionFeaturePolicy(
        enabledFeatures: const {
          ControlledPropertyFeature.clientFunds,
        },
      ),
    );

    final decision = policy.decisionFor(
      ControlledPropertyFeature.clientFunds,
      at: now,
    );

    expect(decision.allowed, isFalse);
    expect(
      decision.reasons,
      contains(
        'Client-funds handling requires a separate trust approval version.',
      ),
    );
  });
}

JurisdictionPolicy _approvedAlbertaPolicy() {
  final jurisdiction = JurisdictionKey(
    country: NorthAmericaCountry.canada,
    subdivisionCode: 'AB',
  );
  const entity = ResponsibleBrokerageEntity(
    id: 'exp-realty-canada',
    legalName: 'eXp Realty of Canada, Inc.',
    country: NorthAmericaCountry.canada,
    active: true,
  );
  return JurisdictionPolicy(
    schemaVersion: 1,
    id: 'ca-ab-v1',
    jurisdiction: jurisdiction,
    status: JurisdictionPolicyStatus.active,
    responsibleEntity: entity,
    brokerageLicense: BrokerageLicense(
      id: 'ca-ab-brokerage-license',
      entityId: entity.id,
      jurisdiction: jurisdiction,
      licenseNumber: 'TEST-ONLY',
      validFrom: DateTime.utc(2026),
      validUntil: DateTime.utc(2027),
      active: true,
    ),
    complianceOwnerId: 'test-supervising-broker',
    requiredFormSetVersion: 'test-forms-v1',
    legalReviewVersion: 'test-legal-v1',
    effectiveAt: DateTime.utc(2026),
    expiresAt: DateTime.utc(2027),
    features: JurisdictionFeaturePolicy(
      enabledFeatures: const {
        ControlledPropertyFeature.publicPropertyListings,
      },
    ),
  );
}
