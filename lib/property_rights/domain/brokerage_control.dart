import 'jurisdiction_policy.dart';

enum ProfessionalRole {
  realEstateAgent,
  commercialAgent,
  supervisingBroker,
  complianceReviewer,
  documentReviewer,
}

class ProfessionalLicense {
  ProfessionalLicense({
    required this.id,
    required this.userId,
    required this.brokerageEntityId,
    required this.role,
    required this.jurisdiction,
    required this.licenseNumber,
    required this.validFrom,
    this.validUntil,
    required this.active,
    this.verifiedAt,
    this.verifiedBy,
  });

  final String id;
  final String userId;
  final String brokerageEntityId;
  final ProfessionalRole role;
  final JurisdictionKey jurisdiction;
  final String licenseNumber;
  final DateTime validFrom;
  final DateTime? validUntil;
  final bool active;
  final DateTime? verifiedAt;
  final String? verifiedBy;

  bool isVerifiedAndValidAt(DateTime at) {
    return active &&
        verifiedAt != null &&
        (verifiedBy ?? '').trim().isNotEmpty &&
        !at.isBefore(validFrom) &&
        (validUntil == null || at.isBefore(validUntil!));
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'userId': userId,
        'brokerageEntityId': brokerageEntityId,
        'role': role.name,
        'jurisdiction': jurisdiction.toMap(),
        'licenseNumber': licenseNumber,
        'validFrom': validFrom.toUtc().toIso8601String(),
        'validUntil': validUntil?.toUtc().toIso8601String(),
        'active': active,
        'verifiedAt': verifiedAt?.toUtc().toIso8601String(),
        'verifiedBy': verifiedBy,
      };
}

class ComplianceAssignment {
  const ComplianceAssignment({
    required this.id,
    required this.policyId,
    required this.professionalUserId,
    required this.role,
    required this.active,
  });

  final String id;
  final String policyId;
  final String professionalUserId;
  final ProfessionalRole role;
  final bool active;

  bool get mayApprove =>
      active &&
      (role == ProfessionalRole.supervisingBroker ||
          role == ProfessionalRole.complianceReviewer);
}
