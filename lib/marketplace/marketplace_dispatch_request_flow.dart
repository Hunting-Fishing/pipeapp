import 'marketplace_dispatch_service_taxonomy.dart';

enum DispatchRequestPath {
  freightRoute,
  fieldService,
}

enum DispatchContactPreference {
  inApp,
  phone,
  email,
}

class DispatchRequestAttachmentDraft {
  const DispatchRequestAttachmentDraft({
    required this.name,
    required this.contentType,
    required this.sizeBytes,
  });

  final String name;
  final String contentType;
  final int sizeBytes;
}

class DispatchRequestReviewIssue {
  const DispatchRequestReviewIssue({required this.field, required this.message});

  final String field;
  final String message;
}

class DispatchRequestFlow {
  const DispatchRequestFlow._();

  static DispatchRequestPath pathForServiceCodes(Iterable<String> codes) {
    var hasKnownService = false;
    for (final code in codes) {
      final service = DispatchServiceTaxonomy.findByCode(code);
      if (service == null) continue;
      hasKnownService = true;
      if (service.category == DispatchServiceCategoryCode.transportation ||
          service.category == DispatchServiceCategoryCode.pilotOversizeSupport) {
        return DispatchRequestPath.freightRoute;
      }
    }
    return hasKnownService
        ? DispatchRequestPath.fieldService
        : DispatchRequestPath.freightRoute;
  }

  static bool hasMixedRequestPaths(Iterable<String> codes) {
    var freight = false;
    var field = false;
    for (final code in codes) {
      final service = DispatchServiceTaxonomy.findByCode(code);
      if (service == null) continue;
      final routeBased =
          service.category == DispatchServiceCategoryCode.transportation ||
              service.category == DispatchServiceCategoryCode.pilotOversizeSupport;
      if (routeBased) {
        freight = true;
      } else {
        field = true;
      }
      if (freight && field) return true;
    }
    return false;
  }

  static bool needsDelivery(Iterable<String> codes) =>
      pathForServiceCodes(codes) == DispatchRequestPath.freightRoute;

  static bool supportsFieldServiceQuestions(Iterable<String> codes) =>
      pathForServiceCodes(codes) == DispatchRequestPath.fieldService;

  static List<DispatchRequestReviewIssue> reviewIssues({
    required Iterable<String> serviceCodes,
    required String pickupLabel,
    required String deliveryLabel,
    required DateTime? requestedAt,
    required String details,
    required DispatchContactPreference contactPreference,
    String phone = '',
    String email = '',
  }) {
    final codes = serviceCodes.where((code) => code.trim().isNotEmpty).toList();
    final issues = <DispatchRequestReviewIssue>[];
    if (codes.isEmpty) {
      issues.add(const DispatchRequestReviewIssue(
        field: 'services',
        message: 'Choose at least one service.',
      ));
    }
    if (hasMixedRequestPaths(codes)) {
      issues.add(const DispatchRequestReviewIssue(
        field: 'services',
        message:
            'Transportation or pilot work and on-site services need separate requests so the right providers receive each job.',
      ));
    }

    final path = pathForServiceCodes(codes);
    if (pickupLabel.trim().isEmpty) {
      issues.add(DispatchRequestReviewIssue(
        field: 'pickup',
        message: path == DispatchRequestPath.freightRoute
            ? 'Add the pickup location.'
            : 'Add the work-site location.',
      ));
    }
    if (path == DispatchRequestPath.freightRoute &&
        deliveryLabel.trim().isEmpty) {
      issues.add(const DispatchRequestReviewIssue(
        field: 'delivery',
        message: 'Add the delivery location.',
      ));
    }
    if (requestedAt == null) {
      issues.add(const DispatchRequestReviewIssue(
        field: 'timing',
        message: 'Choose when the service is needed.',
      ));
    }
    if (details.trim().isEmpty) {
      issues.add(const DispatchRequestReviewIssue(
        field: 'details',
        message: 'Add the load or service details.',
      ));
    }
    if (contactPreference == DispatchContactPreference.phone &&
        phone.trim().isEmpty) {
      issues.add(const DispatchRequestReviewIssue(
        field: 'phone',
        message: 'Add a phone number or choose another contact preference.',
      ));
    }
    if (contactPreference == DispatchContactPreference.email &&
        email.trim().isEmpty) {
      issues.add(const DispatchRequestReviewIssue(
        field: 'email',
        message: 'Add an email address or choose another contact preference.',
      ));
    }
    return issues;
  }
}
