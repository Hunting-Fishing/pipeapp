String normalizeMarketplaceSearchQuery(String value) {
  final words = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(3)
      .toList(growable: false);
  if (words.isEmpty) return '';
  final normalized = words.join(' ');
  if (normalized.length < 2) return '';
  return normalized.length <= 64 ? normalized : normalized.substring(0, 64);
}

bool marketplaceSearchNeedsServerReload(String previous, String next) =>
    normalizeMarketplaceSearchQuery(previous) !=
    normalizeMarketplaceSearchQuery(next);
