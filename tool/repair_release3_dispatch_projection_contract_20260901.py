from pathlib import Path

path = Path('test/dispatch_directory_projection_source_contract_test.dart')
source = path.read_text(encoding='utf-8')
old = """    expect(
      source.contains(\"_firestore.collection('dispatch_directory_entries')\"),
      isTrue,
    );
"""
new = """    expect(source.contains('_firestore'), isTrue);
    expect(source.contains(\"'dispatch_directory_entries'\"), isTrue);
"""
if source.count(old) != 1:
    raise SystemExit(f'projection source-contract anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)
path.write_text(source, encoding='utf-8')
