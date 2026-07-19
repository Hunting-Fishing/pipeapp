enum NorthAmericaCountry {
  canada('CA'),
  unitedStates('US'),
  mexico('MX');

  const NorthAmericaCountry(this.code);

  final String code;

  static NorthAmericaCountry fromCode(String value) {
    final normalized = value.trim().toUpperCase();
    return NorthAmericaCountry.values.firstWhere(
      (country) => country.code == normalized,
      orElse: () => throw FormatException(
        'Unsupported North American country code: $value',
      ),
    );
  }
}

enum JurisdictionPolicyStatus {
  designOnly,
  pendingApproval,
  active,
  suspended,
  retired,
}

enum ControlledPropertyFeature {
  propertyDraftIntake,
  publicPropertyListings,
  propertyOffers,
  rightsListings,
  regulatedEnergyAssets,
  businessSales,
  clientFunds,
}

class JurisdictionKey {
  JurisdictionKey({
    required this.country,
    String? subdivisionCode,
  }) : subdivisionCode = _normalizeSubdivision(subdivisionCode);

  final NorthAmericaCountry country;
  final String? subdivisionCode;

  bool get isCountryBaseline => subdivisionCode == null;

  String get value => subdivisionCode == null
      ? country.code
      : '${country.code}-$subdivisionCode';

  Map<String, Object?> toMap() => <String, Object?>{
        'countryCode': country.code,
        'subdivisionCode': subdivisionCode,
      };

  factory JurisdictionKey.fromMap(Map<String, Object?> map) {
    return JurisdictionKey(
      country: NorthAmericaCountry.fromCode(map['countryCode'] as String),
      subdivisionCode: map['subdivisionCode'] as String?,
    );
  }

  static String? _normalizeSubdivision(String? value) {
    final normalized = value?.trim().toUpperCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  bool operator ==(Object other) =>
      other is JurisdictionKey &&
      other.country == country &&
      other.subdivisionCode == subdivisionCode;

  @override
  int get hashCode => Object.hash(country, subdivisionCode);

  @override
  String toString() => value;
}

class ResponsibleBrokerageEntity {
  const ResponsibleBrokerageEntity({
    required this.id,
    required this.legalName,
    required this.country,
    required this.active,
  });

  final String id;
  final String legalName;
  final NorthAmericaCountry country;
  final bool active;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'legalName': legalName,
        'countryCode': country.code,
        'active': active,
      };

  factory ResponsibleBrokerageEntity.fromMap(Map<String, Object?> map) {
    return ResponsibleBrokerageEntity(
      id: map['id'] as String,
      legalName: map['legalName'] as String,
      country: NorthAmericaCountry.fromCode(map['countryCode'] as String),
      active: map['active'] as bool? ?? false,
    );
  }
}

class BrokerageLicense {
  BrokerageLicense({
    required this.id,
    required this.entityId,
    required this.jurisdiction,
    required this.licenseNumber,
    required this.validFrom,
    this.validUntil,
    required this.active,
  });

  final String id;
  final String entityId;
  final JurisdictionKey jurisdiction;
  final String licenseNumber;
  final DateTime validFrom;
  final DateTime? validUntil;
  final bool active;

  bool isValidAt(DateTime at) {
    return active &&
        !at.isBefore(validFrom) &&
        (validUntil == null || at.isBefore(validUntil!));
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'entityId': entityId,
        'jurisdiction': jurisdiction.toMap(),
        'licenseNumber': licenseNumber,
        'validFrom': validFrom.toUtc().toIso8601String(),
        'validUntil': validUntil?.toUtc().toIso8601String(),
        'active': active,
      };

  factory BrokerageLicense.fromMap(Map<String, Object?> map) {
    return BrokerageLicense(
      id: map['id'] as String,
      entityId: map['entityId'] as String,
      jurisdiction: JurisdictionKey.fromMap(
        Map<String, Object?>.from(map['jurisdiction'] as Map),
      ),
      licenseNumber: map['licenseNumber'] as String,
      validFrom: DateTime.parse(map['validFrom'] as String),
      validUntil: map['validUntil'] == null
          ? null
          : DateTime.parse(map['validUntil'] as String),
      active: map['active'] as bool? ?? false,
    );
  }
}

class JurisdictionFeaturePolicy {
  JurisdictionFeaturePolicy({
    Set<ControlledPropertyFeature> enabledFeatures = const {},
  }) : enabledFeatures = Set.unmodifiable(enabledFeatures);

  final Set<ControlledPropertyFeature> enabledFeatures;

  bool enables(ControlledPropertyFeature feature) =>
      enabledFeatures.contains(feature);

  Map<String, Object?> toMap() => <String, Object?>{
        'enabledFeatures': enabledFeatures
            .map((feature) => feature.name)
            .toList(growable: false)
          ..sort(),
      };

  factory JurisdictionFeaturePolicy.fromMap(Map<String, Object?> map) {
    final raw = (map['enabledFeatures'] as List<Object?>? ?? const [])
        .whereType<String>();
    return JurisdictionFeaturePolicy(
      enabledFeatures: raw
          .map(
            (name) => ControlledPropertyFeature.values.firstWhere(
              (feature) => feature.name == name,
              orElse: () => throw FormatException(
                'Unsupported controlled property feature: $name',
              ),
            ),
          )
          .toSet(),
    );
  }
}

class FeatureDecision {
  FeatureDecision({
    required this.allowed,
    Iterable<String> reasons = const [],
  }) : reasons = List.unmodifiable(reasons);

  final bool allowed;
  final List<String> reasons;
}

class JurisdictionPolicy {
  JurisdictionPolicy({
    required this.schemaVersion,
    required this.id,
    required this.jurisdiction,
    required this.status,
    required this.responsibleEntity,
    required this.features,
    this.brokerageLicense,
    this.complianceOwnerId,
    this.requiredFormSetVersion,
    this.legalReviewVersion,
    this.trustFundsApprovalVersion,
    this.effectiveAt,
    this.expiresAt,
  });

  final int schemaVersion;
  final String id;
  final JurisdictionKey jurisdiction;
  final JurisdictionPolicyStatus status;
  final ResponsibleBrokerageEntity responsibleEntity;
  final JurisdictionFeaturePolicy features;
  final BrokerageLicense? brokerageLicense;
  final String? complianceOwnerId;
  final String? requiredFormSetVersion;
  final String? legalReviewVersion;
  final String? trustFundsApprovalVersion;
  final DateTime? effectiveAt;
  final DateTime? expiresAt;

  List<String> validationIssues(DateTime at) {
    final issues = <String>[];
    if (schemaVersion != 1) {
      issues.add('Unsupported jurisdiction policy schema version.');
    }
    if (id.trim().isEmpty) {
      issues.add('Policy identifier is missing.');
    }
    if (jurisdiction.isCountryBaseline) {
      issues.add(
        'Country baseline policies cannot authorize production features.',
      );
    }
    if (status != JurisdictionPolicyStatus.active) {
      issues.add('Jurisdiction policy is not active.');
    }
    if (!responsibleEntity.active) {
      issues.add('Responsible brokerage entity is not active.');
    }
    if (responsibleEntity.country != jurisdiction.country) {
      issues.add('Responsible entity does not match the jurisdiction country.');
    }
    if (brokerageLicense == null) {
      issues.add('Brokerage licence is missing.');
    } else {
      if (brokerageLicense!.entityId != responsibleEntity.id) {
        issues.add('Brokerage licence belongs to a different entity.');
      }
      if (brokerageLicense!.jurisdiction != jurisdiction) {
        issues.add('Brokerage licence does not match the jurisdiction.');
      }
      if (!brokerageLicense!.isValidAt(at)) {
        issues.add('Brokerage licence is not valid at the requested time.');
      }
    }
    if ((complianceOwnerId ?? '').trim().isEmpty) {
      issues.add('Supervising compliance owner is missing.');
    }
    if ((requiredFormSetVersion ?? '').trim().isEmpty) {
      issues.add('Approved form set version is missing.');
    }
    if ((legalReviewVersion ?? '').trim().isEmpty) {
      issues.add('Legal review version is missing.');
    }
    if (effectiveAt == null || at.isBefore(effectiveAt!)) {
      issues.add('Policy is not yet effective.');
    }
    if (expiresAt != null && !at.isBefore(expiresAt!)) {
      issues.add('Policy has expired.');
    }
    if (features.enables(ControlledPropertyFeature.clientFunds) &&
        (trustFundsApprovalVersion ?? '').trim().isEmpty) {
      issues.add(
        'Client-funds handling requires a separate trust approval version.',
      );
    }
    return issues;
  }

  FeatureDecision decisionFor(
    ControlledPropertyFeature feature, {
    required DateTime at,
  }) {
    final reasons = validationIssues(at);
    if (!features.enables(feature)) {
      reasons.add('Feature ${feature.name} is disabled for this jurisdiction.');
    }
    return FeatureDecision(
      allowed: reasons.isEmpty,
      reasons: reasons,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'id': id,
        'jurisdiction': jurisdiction.toMap(),
        'status': status.name,
        'responsibleEntity': responsibleEntity.toMap(),
        'features': features.toMap(),
        'brokerageLicense': brokerageLicense?.toMap(),
        'complianceOwnerId': complianceOwnerId,
        'requiredFormSetVersion': requiredFormSetVersion,
        'legalReviewVersion': legalReviewVersion,
        'trustFundsApprovalVersion': trustFundsApprovalVersion,
        'effectiveAt': effectiveAt?.toUtc().toIso8601String(),
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
      };

  factory JurisdictionPolicy.fromMap(Map<String, Object?> map) {
    final licenseMap = map['brokerageLicense'];
    return JurisdictionPolicy(
      schemaVersion: map['schemaVersion'] as int,
      id: map['id'] as String,
      jurisdiction: JurisdictionKey.fromMap(
        Map<String, Object?>.from(map['jurisdiction'] as Map),
      ),
      status: JurisdictionPolicyStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => throw FormatException(
          'Unsupported jurisdiction policy status: ${map['status']}',
        ),
      ),
      responsibleEntity: ResponsibleBrokerageEntity.fromMap(
        Map<String, Object?>.from(map['responsibleEntity'] as Map),
      ),
      features: JurisdictionFeaturePolicy.fromMap(
        Map<String, Object?>.from(map['features'] as Map),
      ),
      brokerageLicense: licenseMap == null
          ? null
          : BrokerageLicense.fromMap(
              Map<String, Object?>.from(licenseMap as Map),
            ),
      complianceOwnerId: map['complianceOwnerId'] as String?,
      requiredFormSetVersion: map['requiredFormSetVersion'] as String?,
      legalReviewVersion: map['legalReviewVersion'] as String?,
      trustFundsApprovalVersion: map['trustFundsApprovalVersion'] as String?,
      effectiveAt: map['effectiveAt'] == null
          ? null
          : DateTime.parse(map['effectiveAt'] as String),
      expiresAt: map['expiresAt'] == null
          ? null
          : DateTime.parse(map['expiresAt'] as String),
    );
  }
}
