import 'domain/jurisdiction_policy.dart';

class JurisdictionPolicyRegistry {
  JurisdictionPolicyRegistry(Iterable<JurisdictionPolicy> policies)
      : _policies = _index(policies);

  final Map<String, JurisdictionPolicy> _policies;

  JurisdictionPolicy? findExact(JurisdictionKey jurisdiction) =>
      _policies[jurisdiction.value];

  FeatureDecision decide({
    required JurisdictionKey jurisdiction,
    required ControlledPropertyFeature feature,
    required DateTime at,
  }) {
    final policy = findExact(jurisdiction);
    if (policy == null) {
      return FeatureDecision(
        allowed: false,
        reasons: [
          'No exact policy exists for ${jurisdiction.value}. '
              'Country policies never act as jurisdiction fallbacks.',
        ],
      );
    }
    return policy.decisionFor(feature, at: at);
  }

  static Map<String, JurisdictionPolicy> _index(
    Iterable<JurisdictionPolicy> policies,
  ) {
    final indexed = <String, JurisdictionPolicy>{};
    for (final policy in policies) {
      if (indexed.containsKey(policy.jurisdiction.value)) {
        throw ArgumentError(
          'Duplicate policy for ${policy.jurisdiction.value}.',
        );
      }
      indexed[policy.jurisdiction.value] = policy;
    }
    return Map.unmodifiable(indexed);
  }
}

class NorthAmericaDesignPolicies {
  NorthAmericaDesignPolicies._();

  static final List<JurisdictionPolicy> all = List.unmodifiable([
    _countryDesignPolicy(
      country: NorthAmericaCountry.canada,
      id: 'north-america-ca-design',
      entityId: 'exp-realty-canada',
      legalName: 'eXp Realty of Canada, Inc.',
    ),
    _countryDesignPolicy(
      country: NorthAmericaCountry.unitedStates,
      id: 'north-america-us-design',
      entityId: 'exp-realty-us',
      legalName: 'eXp Realty, LLC',
    ),
    _countryDesignPolicy(
      country: NorthAmericaCountry.mexico,
      id: 'north-america-mx-design',
      entityId: 'exp-realtors-mexico',
      legalName: 'Grupo eXp Realtors Mexico, S. DE R.L. DE CV',
    ),
  ]);

  static final JurisdictionPolicyRegistry registry =
      JurisdictionPolicyRegistry(all);

  static JurisdictionPolicy _countryDesignPolicy({
    required NorthAmericaCountry country,
    required String id,
    required String entityId,
    required String legalName,
  }) {
    return JurisdictionPolicy(
      schemaVersion: 1,
      id: id,
      jurisdiction: JurisdictionKey(country: country),
      status: JurisdictionPolicyStatus.designOnly,
      responsibleEntity: ResponsibleBrokerageEntity(
        id: entityId,
        legalName: legalName,
        country: country,
        active: true,
      ),
      features: JurisdictionFeaturePolicy(
        enabledFeatures: const {
          ControlledPropertyFeature.propertyDraftIntake,
        },
      ),
    );
  }
}
