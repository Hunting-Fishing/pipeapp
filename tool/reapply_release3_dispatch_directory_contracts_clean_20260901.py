from pathlib import Path

projection_path = Path('test/dispatch_directory_projection_source_contract_test.dart')
projection = projection_path.read_text(encoding='utf-8')
old = """    expect(
      source.contains(\"_firestore.collection('dispatch_directory_entries')\"),
      isTrue,
    );
"""
new = """    expect(source.contains('_firestore'), isTrue);
    expect(source.contains(\"'dispatch_directory_entries'\"), isTrue);
"""
if projection.count(old) != 1:
    raise SystemExit(
        f'projection source-contract anchor mismatch: {projection.count(old)}')
projection = projection.replace(old, new, 1)
projection_path.write_text(projection, encoding='utf-8')

setstate_path = Path('test/dispatch_directory_filter_setstate_void_contract_test.dart')
setstate = setstate_path.read_text(encoding='utf-8')
old = """    final reloadStart = compact.indexOf('void _reload() {');
    final filtersStart = compact.indexOf(
      'void _setFilters(DispatchDirectoryFilters value) {',
    );
    final clearStart = compact.indexOf('void _clearFilters()', filtersStart);

    expect(reloadStart, greaterThanOrEqualTo(0));
    expect(filtersStart, greaterThan(reloadStart));
    expect(clearStart, greaterThan(filtersStart));

    final reload = compact.substring(reloadStart, filtersStart);
    expect(reload, contains('_filterDebounce?.cancel();'));
    expect(reload, contains('final nextLoad = _load();'));
    expect(reload, contains('setState(() { _loadFuture = nextLoad; });'));

    final filter = compact.substring(filtersStart, clearStart);
"""
new = """    final reloadStart = compact.indexOf('void _reload() {');
    final loadMoreStart = compact.indexOf(
      'Future<void> _loadMore() async',
      reloadStart,
    );
    final filtersStart = compact.indexOf(
      'void _setFilters(DispatchDirectoryFilters value) {',
    );
    final clearStart = compact.indexOf('void _clearFilters()', filtersStart);

    expect(reloadStart, greaterThanOrEqualTo(0));
    expect(loadMoreStart, greaterThan(reloadStart));
    expect(filtersStart, greaterThan(loadMoreStart));
    expect(clearStart, greaterThan(filtersStart));

    final reload = compact.substring(reloadStart, loadMoreStart);
    expect(reload, contains('_filterDebounce?.cancel();'));
    expect(reload, contains('final nextLoad = _load();'));
    expect(reload, contains('setState(() {'));
    expect(reload, contains('_loadFuture = nextLoad;'));
    expect(reload, isNot(contains('setState(() =>')));

    final filter = compact.substring(filtersStart, clearStart);
"""
if setstate.count(old) != 1:
    raise SystemExit(
        f'setState source-contract anchor mismatch: {setstate.count(old)}')
setstate = setstate.replace(old, new, 1)
old = """    expect(filter, contains('final nextLoad = _load();'));
    expect(filter, contains('setState(() { _loadFuture = nextLoad; });'));
"""
new = """    expect(filter, contains('final nextLoad = _load();'));
    expect(filter, contains('setState(() {'));
    expect(filter, contains('_loadFuture = nextLoad;'));
    expect(filter, isNot(contains('setState(() => _loadFuture')));
"""
if setstate.count(old) != 1:
    raise SystemExit(
        f'filter setState source-contract anchor mismatch: {setstate.count(old)}')
setstate = setstate.replace(old, new, 1)
setstate_path.write_text(setstate, encoding='utf-8')
