function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function compact(text) {
  return text.replace(/\s+/g, ' ').trim();
}

function replaceUnsafeCallbacks(source) {
  const pattern = /^([ \t]*)setState\(\(\)\s*=>\s*_loadFuture\s*=\s*_load\(\)\s*\);[ \t]*$/gm;
  return source.replace(pattern, (_, indent) =>
    `${indent}final nextLoad = _load();\n` +
    `${indent}setState(() {\n` +
    `${indent}  _loadFuture = nextLoad;\n` +
    `${indent}});`,
  );
}

function validateReload(source) {
  const start = source.indexOf('  void _reload() {');
  const end = source.indexOf('  void _setFilters(', start);
  if (start < 0 || end <= start) {
    fail('Directory _reload lifecycle boundaries were not found.');
  }
  const segment = compact(source.slice(start, end));
  const expected =
    'void _reload() { _filterDebounce?.cancel(); final nextLoad = _load(); setState(() { _loadFuture = nextLoad; }); }';
  if (!segment.includes(expected)) {
    fail('Directory _reload does not install the next Future through a void-returning setState callback.');
  }
}

function validateFilterTimer(source) {
  const start = source.indexOf('  void _setFilters(DispatchDirectoryFilters value) {');
  const end = source.indexOf('  void _clearFilters()', start);
  if (start < 0 || end <= start) {
    fail('Directory _setFilters lifecycle boundaries were not found.');
  }
  const segment = compact(source.slice(start, end));
  const required = [
    '_filters = value;',
    '_loadGeneration++;',
    '_filterDebounce?.cancel();',
    'Timer(const Duration(milliseconds: 180), () {',
    'if (!mounted) return;',
    'final nextLoad = _load();',
    'setState(() { _loadFuture = nextLoad; });',
  ];
  for (const marker of required) {
    if (!segment.includes(marker)) {
      fail(`Directory debounced filter lifecycle is missing: ${marker}`);
    }
  }
}

export function normalizeDirectoryFilterSetStateCallbacks(input) {
  let source = input.replace(/\r\n/g, '\n');

  if (!source.includes('DispatchDirectoryPageData? _lastSuccessfulData;')) {
    fail('Directory retained-results runtime lifecycle is not installed.');
  }
  if (!source.includes('Timer? _filterDebounce;')) {
    fail('Directory filter debounce lifecycle is not installed.');
  }

  source = replaceUnsafeCallbacks(source);

  const unsafe = /setState\(\s*\(\)\s*=>\s*_loadFuture\s*=\s*_load\(\)\s*\)/m;
  if (unsafe.test(source)) {
    fail('A setState callback still returns the Future assigned by _load().');
  }

  validateReload(source);
  validateFilterTimer(source);
  return source;
}
