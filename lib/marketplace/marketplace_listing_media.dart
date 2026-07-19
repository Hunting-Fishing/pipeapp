/// Returns the ordered, non-empty listing photo URLs saved by the media service.
List<String> marketplaceListingImageUrls(Map<String, dynamic> listing) {
  final value = listing['imageUrls'];
  if (value is! Iterable) return const <String>[];
  return value
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

/// Uses the seller-selected thumbnail when it is still part of the listing.
///
/// Older listings do not have [thumbnailUrl], so their first uploaded photo
/// remains the backwards-compatible thumbnail.
String? marketplaceListingThumbnailUrl(Map<String, dynamic> listing) {
  final images = marketplaceListingImageUrls(listing);
  final selected = '${listing['thumbnailUrl'] ?? ''}'.trim();
  if (selected.isNotEmpty && images.contains(selected)) return selected;
  return images.firstOrNull;
}
