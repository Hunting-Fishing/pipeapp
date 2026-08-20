function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function count(text, marker) {
  return text.split(marker).length - 1;
}

function validate(source) {
  const filterStart = source.indexOf('class _DirectoryFilterCard extends StatelessWidget');
  const companyStart = source.indexOf('class _DirectoryCompanyCard extends StatelessWidget');
  if (filterStart < 0 || companyStart <= filterStart) {
    fail('Directory filter-card boundaries were not found.');
  }
  const section = source.slice(filterStart, companyStart);

  for (const marker of [
    'class _DirectoryInlineSelect extends StatefulWidget',
    "id: 'directory-service-filter'",
    "id: 'directory-availability-filter'",
    "id: 'directory-business-type-filter'",
    'WidgetsBinding.instance.addPostFrameCallback',
    'GestureDetector(',
    'ListView.separated(',
  ]) {
    if (!section.includes(marker)) {
      fail(`Pointer-stable Directory filter is missing: ${marker}`);
    }
  }

  for (const forbidden of [
    'DropdownButtonFormField<',
    'DropdownMenu<',
    'PopupMenuButton<',
    'showMenu(',
    'OverlayEntry(',
  ]) {
    if (section.includes(forbidden)) {
      fail(`Pointer-stable Directory filter still contains overlay selector code: ${forbidden}`);
    }
  }

  if (count(section, '_DirectoryInlineSelect(') < 4) {
    // One constructor declaration plus three filter instances.
    fail('Expected the inline selector constructor plus three Directory filter instances.');
  }
}

const replacement = `class _DirectoryFilterCard extends StatelessWidget {
  const _DirectoryFilterCard({
    required this.searchController,
    required this.filters,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final DispatchDirectoryFilters filters;
  final ValueChanged<DispatchDirectoryFilters> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final serviceOptions = <_DirectorySelectOption>[
      const _DirectorySelectOption(value: '', label: 'All services'),
      ...DispatchServiceTaxonomy.services.map(
        (service) => _DirectorySelectOption(
          value: service.code,
          label: service.label,
        ),
      ),
    ];
    const availabilityOptions = <_DirectorySelectOption>[
      _DirectorySelectOption(value: '', label: 'Any availability'),
      _DirectorySelectOption(value: 'available_now', label: 'Available now'),
      _DirectorySelectOption(value: 'available_today', label: 'Available today'),
      _DirectorySelectOption(
        value: 'available_this_week',
        label: 'Available this week',
      ),
      _DirectorySelectOption(value: 'unavailable', label: 'Unavailable'),
    ];
    const businessTypeOptions = <_DirectorySelectOption>[
      _DirectorySelectOption(value: '', label: 'All business types'),
      _DirectorySelectOption(value: 'owner_operator', label: 'Owner / operator'),
      _DirectorySelectOption(
        value: 'sole_proprietorship',
        label: 'Sole proprietorship',
      ),
      _DirectorySelectOption(value: 'partnership', label: 'Partnership'),
      _DirectorySelectOption(
        value: 'corporation',
        label: 'Corporation / company',
      ),
      _DirectorySelectOption(value: 'other', label: 'Other'),
    ];

    return PipeBuyerSectionCard(
      title: 'Search & filters',
      subtitle:
          'Start with the service you need, then narrow by availability or business type.',
      leading: const Icon(Icons.tune_outlined, color: PipeBuyerColors.orange),
      trailing: filters.hasActiveFilters
          ? TextButton(onPressed: onClear, child: const Text('Clear'))
          : null,
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: (value) => onChanged(filters.copyWith(searchText: value)),
            decoration: const InputDecoration(
              labelText: 'Search company, service or area',
              prefixIcon: Icon(Icons.search_outlined),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final service = _DirectoryInlineSelect(
                id: 'directory-service-filter',
                label: 'Service',
                value: filters.serviceCode,
                options: serviceOptions,
                onChanged: (value) => onChanged(
                  filters.copyWith(serviceCode: value),
                ),
              );
              final availability = _DirectoryInlineSelect(
                id: 'directory-availability-filter',
                label: 'Availability',
                value: filters.availabilityCode,
                options: availabilityOptions,
                onChanged: (value) => onChanged(
                  filters.copyWith(availabilityCode: value),
                ),
              );
              final businessType = _DirectoryInlineSelect(
                id: 'directory-business-type-filter',
                label: 'Business type',
                value: filters.businessTypeCode,
                options: businessTypeOptions,
                onChanged: (value) => onChanged(
                  filters.copyWith(businessTypeCode: value),
                ),
              );

              if (!wide) {
                return Column(
                  children: [
                    service,
                    const SizedBox(height: 10),
                    availability,
                    const SizedBox(height: 10),
                    businessType,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: service),
                  const SizedBox(width: 10),
                  Expanded(child: availability),
                  const SizedBox(width: 10),
                  Expanded(child: businessType),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('Emergency callout'),
                selected: filters.emergencyOnly,
                onSelected: (value) =>
                    onChanged(filters.copyWith(emergencyOnly: value)),
              ),
              FilterChip(
                label: const Text('Remote-site capable'),
                selected: filters.remoteOnly,
                onSelected: (value) =>
                    onChanged(filters.copyWith(remoteOnly: value)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectorySelectOption {
  const _DirectorySelectOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _DirectoryInlineSelect extends StatefulWidget {
  const _DirectoryInlineSelect({
    required this.id,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String id;
  final String label;
  final String value;
  final List<_DirectorySelectOption> options;
  final ValueChanged<String> onChanged;

  @override
  State<_DirectoryInlineSelect> createState() => _DirectoryInlineSelectState();
}

class _DirectoryInlineSelectState extends State<_DirectoryInlineSelect> {
  bool _expanded = false;
  int _interactionGeneration = 0;

  @override
  void didUpdateWidget(covariant _DirectoryInlineSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _expanded = false;
    }
  }

  _DirectorySelectOption get _selectedOption {
    for (final option in widget.options) {
      if (option.value == widget.value) return option;
    }
    return widget.options.first;
  }

  void _toggle() {
    final generation = ++_interactionGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _interactionGeneration) return;
      setState(() => _expanded = !_expanded);
    });
  }

  void _select(String value) {
    final generation = ++_interactionGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _interactionGeneration) return;
      setState(() => _expanded = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _interactionGeneration) return;
        widget.onChanged(value);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: '\${widget.label}: \${selected.label}',
          child: GestureDetector(
            key: ValueKey('\${widget.id}-button'),
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: widget.label,
                suffixIcon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                ),
              ),
              child: Text(
                selected.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: widget.options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  final isSelected = option.value == widget.value;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    child: GestureDetector(
                      key: ValueKey('\${widget.id}-option-\${option.value}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _select(option.value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check, size: 18),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

`;

export function stabilizeDirectoryPointerSelection(input) {
  let source = input.replace(/\r\n/g, '\n');
  if (!source.includes('class MarketplaceDispatchDirectoryPage extends StatefulWidget')) {
    fail('Dispatch Directory page was not found.');
  }

  if (source.includes('class _DirectoryInlineSelect extends StatefulWidget')) {
    validate(source);
    return source;
  }

  const startMarker = 'class _DirectoryFilterCard extends StatelessWidget {';
  const endMarker = 'class _DirectoryCompanyCard extends StatelessWidget {';
  const start = source.indexOf(startMarker);
  const end = source.indexOf(endMarker, start);
  if (start < 0 || end <= start) {
    fail('Directory filter-card replacement boundaries were not found.');
  }

  source = source.slice(0, start) + replacement + source.slice(end);
  validate(source);
  return source;
}
