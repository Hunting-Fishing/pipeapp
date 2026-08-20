function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function count(text, marker) {
  return text.split(marker).length - 1;
}

function normalizeDropdown(source, variableName) {
  const pattern = new RegExp(
    `^(\\s*)final\\s+${variableName}\\s*=\\s*DropdownButtonFormField<String>\\(\\s*$`,
    'm',
  );
  const match = source.match(pattern);
  if (!match) {
    fail(`Directory ${variableName} dropdown declaration was not found.`);
  }

  const declaration = match[0];
  const start = match.index;
  const nextDeclarationCandidates = [
    source.indexOf('\n              final ', start + declaration.length),
    source.indexOf('\n\n              if (!wide)', start + declaration.length),
  ].filter((value) => value >= 0);
  if (nextDeclarationCandidates.length === 0) {
    fail(`Directory ${variableName} dropdown boundary was not found.`);
  }
  const end = Math.min(...nextDeclarationCandidates);
  const block = source.slice(start, end);
  const isExpandedCount = count(block, 'isExpanded: true,');
  if (isExpandedCount > 1) {
    fail(`Directory ${variableName} dropdown contains multiple isExpanded controls.`);
  }
  if (isExpandedCount === 1) return source;

  const indent = match[1];
  const replacement = `${declaration}\n${indent}  isExpanded: true,`;
  return source.slice(0, start) + replacement + source.slice(start + declaration.length);
}

function validate(source) {
  const filterStart = source.indexOf('class _DirectoryFilterCard extends StatelessWidget');
  const companyStart = source.indexOf('class _DirectoryCompanyCard extends StatelessWidget');
  if (filterStart < 0 || companyStart <= filterStart) {
    fail('Directory filter-card boundaries were not found.');
  }
  const filterSection = source.slice(filterStart, companyStart);

  for (const variableName of ['service', 'availability', 'businessType']) {
    const declaration = new RegExp(
      `final\\s+${variableName}\\s*=\\s*DropdownButtonFormField<String>\\([\\s\\S]*?isExpanded:\\s*true,`,
      'm',
    );
    if (!declaration.test(filterSection)) {
      fail(`Directory ${variableName} dropdown is not width-bounded with isExpanded: true.`);
    }
  }

  const expandedCount = count(filterSection, 'isExpanded: true,');
  if (expandedCount !== 3) {
    fail(`Expected exactly three expanded Directory filter dropdowns, found ${expandedCount}.`);
  }

  if (!filterSection.includes("labelText: 'Service'")) {
    fail('Directory Service filter is missing.');
  }
  if (!filterSection.includes("labelText: 'Availability'")) {
    fail('Directory Availability filter is missing.');
  }
  if (!filterSection.includes("labelText: 'Business type'")) {
    fail('Directory Business type filter is missing.');
  }
}

export function stabilizeDirectoryDropdownLayout(input) {
  let source = input.replace(/\r\n/g, '\n');

  if (!source.includes('class MarketplaceDispatchDirectoryPage extends StatefulWidget')) {
    fail('Dispatch Directory page was not found.');
  }
  if (!source.includes('class _DirectoryFilterCard extends StatelessWidget')) {
    fail('Dispatch Directory filter card was not found.');
  }

  for (const variableName of ['service', 'availability', 'businessType']) {
    source = normalizeDropdown(source, variableName);
  }

  validate(source);
  return source;
}
