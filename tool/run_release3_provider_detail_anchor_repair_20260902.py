import re
from pathlib import Path

PATCH = Path('tool/apply_release3_provider_detail_surface_20260902.py')
source = PATCH.read_text(encoding='utf-8')

anchor_variables = (
    'old_return',
    'new_return',
    'metric_anchor',
    'metric_replacement',
    'old_data',
    'new_data',
)

for name in anchor_variables:
    pattern = re.compile(
        rf'{name} = dedent\("""\n(.*?)\n"""\)\.lstrip\(\)',
        re.DOTALL,
    )
    match = pattern.search(source)
    if match is None:
        raise SystemExit(f'Expected temporary normalized anchor variable: {name}')
    replacement = f'{name} = """\n{match.group(1)}\n"""'
    source = source[: match.start()] + replacement + source[match.end() :]

compiled = compile(source, str(PATCH), 'exec')
exec(compiled, {'__name__': '__main__'})
