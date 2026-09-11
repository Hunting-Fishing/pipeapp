enum DispatchQuoteValidityKind {
  active,
  superseded,
  cancelled,
  archived,
}

class DispatchQuoteVersionPresentation {
  const DispatchQuoteVersionPresentation({
    required this.kind,
    required this.version,
    required this.label,
    required this.watermark,
    this.supersededByVersion,
  });

  final DispatchQuoteValidityKind kind;
  final int version;
  final int? supersededByVersion;
  final String label;
  final String watermark;

  bool get isCurrent => kind == DispatchQuoteValidityKind.active;
  bool get isInvalid =>
      kind == DispatchQuoteValidityKind.superseded ||
      kind == DispatchQuoteValidityKind.cancelled;
}

String dispatchQuoteValidityStatus(Map<String, dynamic> quote) {
  final raw = '${quote['validityStatus'] ?? ''}'.trim().toLowerCase();
  // B1 quotes deployed before validity transitions did not always persist the
  // field. They remain active unless a server-owned terminal status says
  // otherwise.
  if (raw.isEmpty) {
    return '${quote['status'] ?? ''}'.trim().toLowerCase() == 'cancelled'
        ? 'cancelled'
        : 'active';
  }
  return raw;
}

int dispatchQuoteVersion(Map<String, dynamic> quote) {
  final raw = quote['quoteVersion'] ?? quote['revision'] ?? 1;
  final value = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 1;
  return value < 1 ? 1 : value;
}

bool dispatchQuoteIsCurrentAndAwardable(Map<String, dynamic> quote) =>
    '${quote['status'] ?? ''}'.trim().toLowerCase() == 'pending' &&
    dispatchQuoteValidityStatus(quote) == 'active';

DispatchQuoteVersionPresentation dispatchQuoteVersionPresentation({
  required Map<String, dynamic> currentQuote,
  required Map<String, dynamic> revision,
}) {
  final currentVersion = dispatchQuoteVersion(currentQuote);
  final version = dispatchQuoteVersion(revision);
  final event = '${revision['event'] ?? ''}'.trim().toLowerCase();
  final currentValidity = dispatchQuoteValidityStatus(currentQuote);
  final currentStatus = '${currentQuote['status'] ?? ''}'.trim().toLowerCase();

  if (event == 'quote_cancelled' ||
      (version == currentVersion &&
          (currentValidity == 'cancelled' || currentStatus == 'cancelled'))) {
    return DispatchQuoteVersionPresentation(
      kind: DispatchQuoteValidityKind.cancelled,
      version: version,
      label: 'Version $version · Cancelled',
      watermark: 'QUOTE CANCELLED - NO LONGER VALID',
    );
  }

  if (version < currentVersion) {
    return DispatchQuoteVersionPresentation(
      kind: DispatchQuoteValidityKind.superseded,
      version: version,
      supersededByVersion: version + 1,
      label: 'Version $version · Superseded by Version ${version + 1}',
      watermark: 'QUOTE UPDATED - NO LONGER VALID',
    );
  }

  if (version == currentVersion && currentValidity == 'active') {
    return DispatchQuoteVersionPresentation(
      kind: DispatchQuoteValidityKind.active,
      version: version,
      label: 'Version $version · Current',
      watermark: '',
    );
  }

  return DispatchQuoteVersionPresentation(
    kind: DispatchQuoteValidityKind.archived,
    version: version,
    label: 'Version $version · Archived',
    watermark: '',
  );
}
