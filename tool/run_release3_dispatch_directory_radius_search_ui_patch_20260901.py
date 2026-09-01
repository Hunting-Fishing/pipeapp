from pathlib import Path

PATCH = Path('tool/apply_release3_dispatch_directory_radius_search_ui_20260901.py')
source = PATCH.read_text(encoding='utf-8')

# The staged patch script intentionally stays unchanged for auditability. Repair
# only its temporary Python-string quoting in memory before compiling it.
repairs = {
    '''"""'searchDispatchDirectoryRadius'"""''': r'''\"'searchDispatchDirectoryRadius'\"''',
    '''"""'Search this area'"""''': r'''\"'Search this area'\"''',
    '''"""'Change area'"""''': r'''\"'Change area'\"''',
}

for old, new in repairs.items():
    if source.count(old) != 1:
        raise SystemExit(f'Expected one temporary quoting defect for {old!r}')
    source = source.replace(old, new, 1)

exec(compile(source, str(PATCH), 'exec'), {'__name__': '__main__'})
