import 'package:cloud_firestore/cloud_firestore.dart';

const marketplaceListingPageSize = 24;

class MarketplaceListingDocumentPage {
  const MarketplaceListingDocumentPage({
    required this.documents,
    required this.cursor,
    required this.hasMore,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents;
  final QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}

Future<MarketplaceListingDocumentPage> loadMarketplaceListingPage(
  Query<Map<String, dynamic>> query, {
  QueryDocumentSnapshot<Map<String, dynamic>>? after,
  int pageSize = marketplaceListingPageSize,
}) async {
  assert(pageSize > 0);
  var bounded = query.limit(pageSize);
  if (after != null) bounded = bounded.startAfterDocument(after);
  final snapshot = await bounded.get();
  return MarketplaceListingDocumentPage(
    documents: snapshot.docs,
    cursor: snapshot.docs.lastOrNull,
    hasMore: snapshot.docs.length == pageSize,
  );
}

List<T> appendUniqueById<T>(
  Iterable<T> current,
  Iterable<T> incoming,
  String Function(T item) idOf,
) {
  final ids = current.map(idOf).toSet();
  return <T>[
    ...current,
    ...incoming.where((item) => ids.add(idOf(item))),
  ];
}
