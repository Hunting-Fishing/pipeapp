import 'package:cloud_firestore/cloud_firestore.dart';

const defaultFirestorePageSize = 24;
const defaultActivityFeedLimit = 100;
const defaultReferenceDataLimit = 500;
const defaultBatchMutationLimit = 450;

class FirestoreDocumentPage {
  const FirestoreDocumentPage({
    required this.documents,
    required this.cursor,
    required this.hasMore,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents;
  final QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}

Future<FirestoreDocumentPage> loadFirestoreDocumentPage(
  Query<Map<String, dynamic>> query, {
  QueryDocumentSnapshot<Map<String, dynamic>>? after,
  int pageSize = defaultFirestorePageSize,
}) async {
  assert(pageSize > 0);
  var bounded = query.limit(pageSize);
  if (after != null) bounded = bounded.startAfterDocument(after);
  final snapshot = await bounded.get();
  return FirestoreDocumentPage(
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
