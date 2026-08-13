import 'initial_location_source_stub.dart'
    if (dart.library.html) 'initial_location_source_web.dart' as source;

String marketplaceInitialLocation() => marketplaceInitialLocationFromParts(
      source.marketplacePathname(),
      source.marketplaceSearch(),
    );

String marketplaceInitialLocationFromParts(String pathname, String search) {
  final path = pathname.trim().isEmpty ? '/' : pathname.trim();
  final query = search.trim();
  if (query.isEmpty || query == '?') return path;
  return '$path${query.startsWith('?') ? query : '?$query'}';
}
