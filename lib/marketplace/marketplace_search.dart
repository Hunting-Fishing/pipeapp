String _foldMarketplaceSearchLatin(String value) {
  var folded = value
      .toLowerCase()
      .replaceAll('æ', 'ae')
      .replaceAll('œ', 'oe')
      .replaceAll('ß', 'ss')
      .replaceAll('ø', 'o')
      .replaceAll('ł', 'l')
      .replaceAll('ð', 'd')
      .replaceAll('þ', 'th');
  const groups = <String, String>{
    'a': 'àáâãäåāăą',
    'c': 'çćĉċč',
    'd': 'ďđ',
    'e': 'èéêëēĕėęě',
    'g': 'ĝğġģ',
    'h': 'ĥħ',
    'i': 'ìíîïĩīĭįı',
    'j': 'ĵ',
    'k': 'ķ',
    'l': 'ĺļľŀ',
    'n': 'ñńņňŉŋ',
    'o': 'òóôõöōŏő',
    'r': 'ŕŗř',
    's': 'śŝşš',
    't': 'ţťŧ',
    'u': 'ùúûüũūŭůűų',
    'w': 'ŵ',
    'y': 'ýÿŷ',
    'z': 'źżž',
  };
  for (final entry in groups.entries) {
    for (final character in entry.value.split('')) {
      folded = folded.replaceAll(character, entry.key);
    }
  }
  return folded;
}

String normalizeMarketplaceSearchQuery(String value) {
  final words = _foldMarketplaceSearchLatin(value)
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
