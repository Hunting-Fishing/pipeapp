import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_equipment_catalog.dart';

/// Structured selectable item for [MarketplaceSearchableSelectField].
@immutable
class MarketplaceSelectOption<T> {
  const MarketplaceSelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.badge,
    this.searchKeywords = const <String>[],
    this.isPinnedSpecial = false,
  });

  final T value;
  final String label;
  final String? subtitle;
  final String? badge;
  final List<String> searchKeywords;
  final bool isPinnedSpecial;

  /// Multi-token case-insensitive substring & alphanumeric match across
  /// [label], [subtitle], [badge], and [searchKeywords].
  bool matchesQueryTokens(List<String> lowerQueryTokens) {
    if (lowerQueryTokens.isEmpty) return true;
    final combinedLower = <String>[
      label,
      if (subtitle != null && subtitle!.isNotEmpty) subtitle!,
      if (badge != null && badge!.isNotEmpty) badge!,
      ...searchKeywords,
    ].join(' ').toLowerCase();

    final compactAlphaNum = combinedLower.replaceAll(RegExp(r'[^a-z0-9]'), '');

    for (final token in lowerQueryTokens) {
      if (combinedLower.contains(token)) continue;
      final compactToken = token.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (compactToken.isNotEmpty && compactAlphaNum.contains(compactToken)) {
        continue;
      }
      return false;
    }
    return true;
  }
}

/// Executive-grade searchable dropdown / modal sheet `FormField<T>` matching
/// `PipeBuyerTheme` (`useMaterial3: false`, Light & Dark mode, 120fps lists).
class MarketplaceSearchableSelectField<T> extends FormField<T> {
  MarketplaceSearchableSelectField({
    super.key,
    required this.label,
    this.hintText,
    this.helperText,
    this.value,
    required this.options,
    this.onChanged,
    super.validator,
    super.enabled = true,
    this.searchHintText = 'Search options...',
    this.emptyStateText = 'No matching options found.',
    this.prefixIcon,
    this.modalTitle,
    this.filterChipLabel,
    this.allOptionsWhenUnfiltered,
    this.semanticKey,
    this.headerBadge,
    this.allowClear = false,
    this.clearTooltip = 'Clear selection',
    this.clearButtonKey,
    super.onSaved,
    super.autovalidateMode,
  }) : super(
          initialValue: value,
          builder: (FormFieldState<T> field) {
            final state = field as _MarketplaceSearchableSelectFieldState<T>;
            return state._buildField(field.context);
          },
        );

  final String label;
  final String? hintText;
  final String? helperText;
  final T? value;
  final List<MarketplaceSelectOption<T>> options;
  final ValueChanged<T?>? onChanged;
  final String searchHintText;
  final String emptyStateText;
  final IconData? prefixIcon;
  final String? modalTitle;
  final String? filterChipLabel;
  final List<MarketplaceSelectOption<T>>? allOptionsWhenUnfiltered;
  final Key? semanticKey;
  final String? headerBadge;
  final bool allowClear;
  final String clearTooltip;
  final Key? clearButtonKey;

  @override
  FormFieldState<T> createState() =>
      _MarketplaceSearchableSelectFieldState<T>();
}

class _MarketplaceSearchableSelectFieldState<T> extends FormFieldState<T> {
  bool _isFocused = false;
  bool _isModalOpen = false;

  @override
  MarketplaceSearchableSelectField<T> get widget =>
      super.widget as MarketplaceSearchableSelectField<T>;

  @override
  void didUpdateWidget(MarketplaceSearchableSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      setValue(widget.value);
      if (hasError) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            validate();
          }
        });
      }
    }
  }

  MarketplaceSelectOption<T>? _findSelectedOption(T? target) {
    if (target == null) return null;
    for (final opt in widget.options) {
      if (opt.value == target) return opt;
    }
    final unfiltered = widget.allOptionsWhenUnfiltered;
    if (unfiltered != null) {
      for (final opt in unfiltered) {
        if (opt.value == target) return opt;
      }
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    if (!widget.enabled || _isModalOpen) return;
    FocusScope.of(context).unfocus();
    setState(() => _isModalOpen = true);

    final viewportWidth = MediaQuery.sizeOf(context).width;
    final title =
        (widget.modalTitle != null && widget.modalTitle!.trim().isNotEmpty)
            ? widget.modalTitle!.trim()
            : widget.label;

    _PickerSelection<T>? result;
    try {
      if (viewportWidth >= 720) {
        result = await showDialog<_PickerSelection<T>>(
          context: context,
          builder: (dialogContext) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 620),
              child: _MarketplacePickerModalContent<T>(
                title: title,
                selectedValue: value,
                options: widget.options,
                allOptionsWhenUnfiltered: widget.allOptionsWhenUnfiltered,
                filterChipLabel: widget.filterChipLabel,
                searchHintText: widget.searchHintText,
                emptyStateText: widget.emptyStateText,
                showDragHandle: false,
              ),
            ),
          ),
        );
      } else {
        result = await showModalBottomSheet<_PickerSelection<T>>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: false,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) {
            final mediaQuery = MediaQuery.of(sheetContext);
            final maxSheetHeight = mediaQuery.size.height * 0.82;
            final availableHeight = math.max(
              280.0,
              mediaQuery.size.height - mediaQuery.viewInsets.bottom - 24,
            );
            final effectiveHeight = math.min(maxSheetHeight, availableHeight);

            return Padding(
              padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
              child: Container(
                height: effectiveHeight,
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _MarketplacePickerModalContent<T>(
                  title: title,
                  selectedValue: value,
                  options: widget.options,
                  allOptionsWhenUnfiltered: widget.allOptionsWhenUnfiltered,
                  filterChipLabel: widget.filterChipLabel,
                  searchHintText: widget.searchHintText,
                  emptyStateText: widget.emptyStateText,
                  showDragHandle: true,
                ),
              ),
            );
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isModalOpen = false);
      }
    }

    if (!mounted || result == null) return;
    didChange(result.value);
    if (hasError) {
      validate();
    }
    widget.onChanged?.call(result.value);
  }

  void _clearSelection() {
    if (!widget.enabled) return;
    didChange(null);
    if (hasError) {
      validate();
    }
    widget.onChanged?.call(null);
  }

  Widget _buildField(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedOption = _findSelectedOption(value);
    final displayText =
        selectedOption?.label ?? (value != null ? '$value'.trim() : '');
    final isEmpty = value == null || displayText.isEmpty;
    final activeBadge = selectedOption?.badge ?? widget.headerBadge;
    final trimmedBadge = activeBadge?.trim() ?? '';
    final showClosedBadge = trimmedBadge.isNotEmpty &&
        (isEmpty || !displayText.contains(trimmedBadge));
    final arrowColor = widget.enabled
        ? (_isModalOpen || _isFocused
            ? PipeBuyerColors.orange
            : theme.inputDecorationTheme.suffixIconColor)
        : theme.disabledColor;

    final Widget suffixWidget = widget.allowClear && widget.enabled && !isEmpty
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                key: widget.clearButtonKey,
                tooltip: widget.clearTooltip,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _clearSelection,
                icon: Icon(
                  Icons.clear_rounded,
                  size: 18,
                  color: isDark
                      ? PipeBuyerColors.darkMuted
                      : PipeBuyerColors.muted,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: arrowColor,
                ),
              ),
            ],
          )
        : Icon(Icons.keyboard_arrow_down_rounded, color: arrowColor);

    final borderColor =
        isDark ? PipeBuyerColors.darkLine : const Color(0xFFCFD9E6);
    final inheritedBorder = theme.inputDecorationTheme.border;
    final needsVisibleOutline = inheritedBorder == null ||
        (inheritedBorder is OutlineInputBorder &&
            inheritedBorder.borderSide == BorderSide.none);
    final fallbackRadius = BorderRadius.circular(10);

    final baseDecoration = InputDecoration(
      labelText: widget.label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      helperText: widget.helperText,
      errorText: errorText,
      enabled: widget.enabled,
      prefixIcon:
          widget.prefixIcon != null ? Icon(widget.prefixIcon, size: 20) : null,
      suffixIcon: suffixWidget,
      border: needsVisibleOutline
          ? OutlineInputBorder(
              borderRadius: fallbackRadius,
              borderSide: BorderSide(color: borderColor),
            )
          : null,
      enabledBorder: needsVisibleOutline
          ? OutlineInputBorder(
              borderRadius: fallbackRadius,
              borderSide: BorderSide(color: borderColor),
            )
          : null,
      disabledBorder: needsVisibleOutline
          ? OutlineInputBorder(
              borderRadius: fallbackRadius,
              borderSide: BorderSide(color: borderColor.withValues(alpha: 0.6)),
            )
          : null,
      focusedBorder: needsVisibleOutline
          ? OutlineInputBorder(
              borderRadius: fallbackRadius,
              borderSide: const BorderSide(
                color: PipeBuyerColors.orange,
                width: 1.8,
              ),
            )
          : null,
      errorBorder: needsVisibleOutline
          ? OutlineInputBorder(
              borderRadius: fallbackRadius,
              borderSide: const BorderSide(color: PipeBuyerColors.danger),
            )
          : null,
      focusedErrorBorder: needsVisibleOutline
          ? OutlineInputBorder(
              borderRadius: fallbackRadius,
              borderSide: const BorderSide(
                color: PipeBuyerColors.danger,
                width: 1.8,
              ),
            )
          : null,
    ).applyDefaults(theme.inputDecorationTheme);

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      value: isEmpty ? (widget.hintText ?? '') : displayText,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: widget.semanticKey,
          borderRadius: BorderRadius.circular(12),
          onTap: widget.enabled ? () => _openPicker(context) : null,
          onFocusChange: (focused) {
            if (_isFocused != focused) {
              setState(() => _isFocused = focused);
            }
          },
          child: InputDecorator(
            isEmpty: false,
            isFocused: _isFocused || _isModalOpen,
            decoration: baseDecoration,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    isEmpty ? (widget.hintText ?? '') : displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isEmpty ? FontWeight.w500 : FontWeight.w700,
                      color: isEmpty
                          ? (isDark
                              ? PipeBuyerColors.darkMuted
                              : PipeBuyerColors.muted)
                          : (widget.enabled
                              ? theme.colorScheme.onSurface
                              : theme.disabledColor),
                    ),
                  ),
                ),
                if (showClosedBadge) ...[
                  const SizedBox(width: 8),
                  _SubtleBadgePill(text: trimmedBadge),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class _PickerSelection<T> {
  const _PickerSelection(this.value);
  final T value;
}

class _MarketplacePickerModalContent<T> extends StatefulWidget {
  const _MarketplacePickerModalContent({
    required this.title,
    required this.selectedValue,
    required this.options,
    required this.allOptionsWhenUnfiltered,
    required this.filterChipLabel,
    required this.searchHintText,
    required this.emptyStateText,
    required this.showDragHandle,
  });

  final String title;
  final T? selectedValue;
  final List<MarketplaceSelectOption<T>> options;
  final List<MarketplaceSelectOption<T>>? allOptionsWhenUnfiltered;
  final String? filterChipLabel;
  final String searchHintText;
  final String emptyStateText;
  final bool showDragHandle;

  @override
  State<_MarketplacePickerModalContent<T>> createState() =>
      _MarketplacePickerModalContentState<T>();
}

class _MarketplacePickerModalContentState<T>
    extends State<_MarketplacePickerModalContent<T>> {
  late final TextEditingController _searchController;
  bool _showingAllUnfiltered = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // If current selection exists only in the unfiltered catalog list, default
    // to showing all options so the active selection is immediately visible.
    if (widget.selectedValue != null &&
        widget.allOptionsWhenUnfiltered != null &&
        !widget.options.any((o) => o.value == widget.selectedValue) &&
        widget.allOptionsWhenUnfiltered!.any(
          (o) => o.value == widget.selectedValue,
        )) {
      _showingAllUnfiltered = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasUnfilteredToggle {
    final unfiltered = widget.allOptionsWhenUnfiltered;
    if (unfiltered == null) return false;
    final filteredRegularCount =
        widget.options.where((o) => !o.isPinnedSpecial).length;
    final unfilteredRegularCount =
        unfiltered.where((o) => !o.isPinnedSpecial).length;
    return unfilteredRegularCount > filteredRegularCount ||
        (widget.filterChipLabel != null &&
            widget.filterChipLabel!.trim().isNotEmpty);
  }

  List<MarketplaceSelectOption<T>> get _activeSourceOptions =>
      (_showingAllUnfiltered && widget.allOptionsWhenUnfiltered != null)
          ? widget.allOptionsWhenUnfiltered!
          : widget.options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor =
        isDark ? PipeBuyerColors.darkMuted : PipeBuyerColors.muted;
    final lineColor = isDark ? PipeBuyerColors.darkLine : PipeBuyerColors.line;

    final queryTokens = _query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    final regularOptions = <MarketplaceSelectOption<T>>[];
    final pinnedSpecials = <MarketplaceSelectOption<T>>[];
    final seenPinnedValues = <T>{};

    for (final opt in _activeSourceOptions) {
      if (opt.isPinnedSpecial) {
        if (seenPinnedValues.add(opt.value)) {
          pinnedSpecials.add(opt);
        }
      } else {
        regularOptions.add(opt);
      }
    }

    // Also ensure pinned specials from primary options are never lost when toggled.
    for (final opt in widget.options) {
      if (opt.isPinnedSpecial && seenPinnedValues.add(opt.value)) {
        pinnedSpecials.add(opt);
      }
    }

    final matchingRegular = queryTokens.isEmpty
        ? regularOptions
        : regularOptions
            .where((opt) => opt.matchesQueryTokens(queryTokens))
            .toList(growable: false);

    final filteredRegularCount =
        widget.options.where((o) => !o.isPinnedSpecial).length;
    final totalUnfilteredRegularCount = widget.allOptionsWhenUnfiltered
            ?.where((o) => !o.isPinnedSpecial)
            .length ??
        filteredRegularCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showDragHandle)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: mutedColor.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SubtleBadgePill(text: '${matchingRegular.length}'),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (next) => setState(() => _query = next),
            onSubmitted: (_) {
              if (matchingRegular.isNotEmpty) {
                Navigator.of(context)
                    .pop(_PickerSelection<T>(matchingRegular.first.value));
              }
            },
            decoration: InputDecoration(
              hintText: widget.searchHintText,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear_rounded, size: 19),
                    ),
              isDense: true,
            ),
          ),
        ),
        if (_hasUnfilteredToggle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _FilterScopeToggleBanner(
              showingAll: _showingAllUnfiltered,
              filteredLabel: widget.filterChipLabel ??
                  'Showing filtered options ($filteredRegularCount) — Tap to show all $totalUnfilteredRegularCount',
              unfilteredLabel:
                  'Showing all $totalUnfilteredRegularCount options — Tap to filter ($filteredRegularCount)',
              onToggle: () => setState(
                () => _showingAllUnfiltered = !_showingAllUnfiltered,
              ),
            ),
          ),
        Divider(height: 1, thickness: 1, color: lineColor),
        Expanded(
          child: matchingRegular.isEmpty
              ? _buildEmptyState(
                  context,
                  mutedColor: mutedColor,
                  canExpandScope:
                      _hasUnfilteredToggle && !_showingAllUnfiltered,
                  totalUnfilteredCount: totalUnfilteredRegularCount,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  itemCount: matchingRegular.length,
                  itemBuilder: (context, index) {
                    final option = matchingRegular[index];
                    final isSelected = option.value == widget.selectedValue;
                    return _OptionTile<T>(
                      option: option,
                      isSelected: isSelected,
                      onTap: () => Navigator.of(context)
                          .pop(_PickerSelection<T>(option.value)),
                    );
                  },
                ),
        ),
        if (pinnedSpecials.isNotEmpty) ...[
          Divider(height: 1, thickness: 1, color: lineColor),
          Container(
            color: isDark
                ? PipeBuyerColors.darkSurfaceMuted
                : PipeBuyerColors.surfaceMuted,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: pinnedSpecials
                  .map(
                    (special) => _OptionTile<T>(
                      option: special,
                      isSelected: special.value == widget.selectedValue,
                      isPinnedFooter: true,
                      onTap: () => Navigator.of(context)
                          .pop(_PickerSelection<T>(special.value)),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required Color mutedColor,
    required bool canExpandScope,
    required int totalUnfilteredCount,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_off_rounded, size: 36, color: mutedColor),
            const SizedBox(height: 10),
            Text(
              widget.emptyStateText,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: mutedColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (canExpandScope) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showingAllUnfiltered = true),
                icon: const Icon(Icons.layers_outlined, size: 18),
                label: Text('Show all $totalUnfilteredCount options'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterScopeToggleBanner extends StatelessWidget {
  const _FilterScopeToggleBanner({
    required this.showingAll,
    required this.filteredLabel,
    required this.unfilteredLabel,
    required this.onToggle,
  });

  final bool showingAll;
  final String filteredLabel;
  final String unfilteredLabel;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        showingAll ? PipeBuyerColors.orange : PipeBuyerColors.industrialBlue;
    final bgColor = accent.withValues(alpha: isDark ? 0.16 : 0.08);
    final borderColor = accent.withValues(alpha: isDark ? 0.42 : 0.26);

    return Semantics(
      button: true,
      toggled: showingAll,
      label: showingAll ? unfilteredLabel : filteredLabel,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  showingAll ? Icons.layers_rounded : Icons.filter_alt_outlined,
                  size: 17,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    showingAll ? unfilteredLabel : filteredLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? PipeBuyerColors.darkText
                              : PipeBuyerColors.ink,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.swap_horiz_rounded, size: 17, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionTile<T> extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
    this.isPinnedFooter = false,
  });

  final MarketplaceSelectOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isPinnedFooter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedBg = isDark
        ? PipeBuyerColors.orange.withValues(alpha: 0.16)
        : PipeBuyerColors.orangeSoft;
    final mutedColor =
        isDark ? PipeBuyerColors.darkMuted : PipeBuyerColors.muted;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isPinnedFooter ? 0 : 2),
      child: Material(
        color: isSelected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: <Widget>[
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : (option.isPinnedSpecial
                          ? Icons.edit_note_rounded
                          : Icons.radio_button_unchecked_rounded),
                  size: 20,
                  color: isSelected
                      ? PipeBuyerColors.orange
                      : mutedColor.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        option.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w900 : FontWeight.w700,
                          color: isSelected && !isDark
                              ? PipeBuyerColors.orangePressed
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      if (option.subtitle != null &&
                          option.subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          option.subtitle!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: mutedColor,
                            height: 1.28,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (option.badge != null &&
                    option.badge!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _SubtleBadgePill(
                    text: option.badge!.trim(),
                    emphasized: isSelected,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtleBadgePill extends StatelessWidget {
  const _SubtleBadgePill({
    required this.text,
    this.emphasized = false,
    this.tone,
  });

  final String text;
  final bool emphasized;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTone = tone ??
        (emphasized
            ? PipeBuyerColors.orange
            : (isDark ? PipeBuyerColors.darkMuted : PipeBuyerColors.slate));
    final bgColor = tone != null || emphasized
        ? effectiveTone.withValues(alpha: isDark ? 0.18 : 0.12)
        : (isDark
            ? PipeBuyerColors.darkSurfaceMuted
            : PipeBuyerColors.surfaceMuted);
    final borderColor = tone != null || emphasized
        ? effectiveTone.withValues(alpha: 0.34)
        : (isDark ? PipeBuyerColors.darkLine : PipeBuyerColors.line);
    final textColor = tone != null
        ? effectiveTone
        : (emphasized
            ? (isDark ? PipeBuyerColors.orange : PipeBuyerColors.orangePressed)
            : effectiveTone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
          height: 1.15,
        ),
      ),
    );
  }
}

/// Smart adaptive Engine & Powertrain field supporting multi-option catalog
/// selection, single-spec auto-match with custom override, and manual entry.
class MarketplaceEnginePowertrainField extends StatefulWidget {
  const MarketplaceEnginePowertrainField({
    super.key,
    required this.engineOptions,
    required this.controller,
    this.onChanged,
    this.modelYear,
    this.brand,
    this.model,
  });

  /// Sentinel value representing custom/manual engine & powertrain entry.
  static const String customEngineOptionValue = '__custom_engine_powertrain__';

  /// Display label for the custom engine/powertrain option.
  static const String customEngineOptionLabel =
      'Other / custom engine or powertrain';

  final List<EquipmentEngineOption> engineOptions;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int? modelYear;
  final String? brand;
  final String? model;

  @override
  State<MarketplaceEnginePowertrainField> createState() =>
      _MarketplaceEnginePowertrainFieldState();
}

class _MarketplaceEnginePowertrainFieldState
    extends State<MarketplaceEnginePowertrainField> {
  bool _customModeExplicitlyChosen = false;
  bool _suppressControllerListener = false;
  String? _lastAutoAppliedSingleSpec;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _syncSingleCatalogOptionIfAppropriate(isInitialMount: true);
  }

  @override
  void didUpdateWidget(covariant MarketplaceEnginePowertrainField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }

    final contextChanged = widget.brand != oldWidget.brand ||
        widget.model != oldWidget.model ||
        widget.modelYear != oldWidget.modelYear ||
        !_sameEngineLabels(widget.engineOptions, oldWidget.engineOptions);

    if (contextChanged) {
      // Reset explicit custom toggle if new options match current text or empty.
      final trimmed = widget.controller.text.trim();
      if (trimmed.isEmpty ||
          widget.engineOptions.any((e) => e.label.trim() == trimmed)) {
        _customModeExplicitlyChosen = false;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncSingleCatalogOptionIfAppropriate(isInitialMount: false);
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (_suppressControllerListener || !mounted) return;
    setState(() {});
  }

  void _syncSingleCatalogOptionIfAppropriate({required bool isInitialMount}) {
    if (widget.engineOptions.length != 1) {
      if (!isInitialMount &&
          _lastAutoAppliedSingleSpec != null &&
          widget.controller.text.trim() == _lastAutoAppliedSingleSpec) {
        _lastAutoAppliedSingleSpec = null;
        _setControllerTextSilently('');
      }
      return;
    }
    final singleLabel = widget.engineOptions.first.label.trim();
    if (singleLabel.isEmpty) return;

    final current = widget.controller.text.trim();
    final canAutoPopulate = current.isEmpty ||
        (!isInitialMount &&
            _lastAutoAppliedSingleSpec != null &&
            current == _lastAutoAppliedSingleSpec);

    if (canAutoPopulate) {
      _lastAutoAppliedSingleSpec = singleLabel;
      _setControllerTextSilently(singleLabel);
    } else if (current == singleLabel) {
      _lastAutoAppliedSingleSpec = singleLabel;
    }
  }

  void _setControllerTextSilently(String nextText) {
    _suppressControllerListener = true;
    try {
      widget.controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    } finally {
      _suppressControllerListener = false;
    }
  }

  static bool _sameEngineLabels(
    List<EquipmentEngineOption> a,
    List<EquipmentEngineOption> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].label != b[i].label) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.engineOptions;

    // Case C: No structured catalog engine options -> clean standard TextFormField.
    if (options.isEmpty) {
      return TextFormField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        decoration: const InputDecoration(
          labelText: 'Engine / powertrain details',
          hintText: 'Engine make/model, HP, fuel type, tier or transmission',
          prefixIcon: Icon(Icons.settings_outlined),
        ),
      );
    }

    // Case B: Exactly 1 catalog engine option -> compact single-row TextFormField
    // with inline 'Matched' pill or one-tap 'Reset' icon button inside suffixIcon!
    if (options.length == 1) {
      final singleSpec = options.first;
      final currentTrimmed = widget.controller.text.trim();
      final matchesCatalogSpec = currentTrimmed == singleSpec.label.trim();

      return TextFormField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          labelText: 'Engine / powertrain details',
          hintText: 'Engine make/model, HP, fuel type, tier or transmission',
          prefixIcon: const Icon(Icons.settings_outlined),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (matchesCatalogSpec)
                  const _SubtleBadgePill(
                    text: 'Matched',
                    tone: PipeBuyerColors.success,
                  )
                else
                  IconButton(
                    tooltip: 'Reset to catalog spec',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _lastAutoAppliedSingleSpec = singleSpec.label;
                      _setControllerTextSilently(singleSpec.label);
                      setState(() {});
                      widget.onChanged?.call(singleSpec.label);
                    },
                    icon: const Icon(
                      Icons.restart_alt_rounded,
                      size: 18,
                      color: PipeBuyerColors.industrialBlue,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Case A: Multiple catalog engine options -> searchable selector + custom override!
    final currentText = widget.controller.text.trim();
    EquipmentEngineOption? matchedPreset;
    for (final opt in options) {
      if (opt.label.trim() == currentText) {
        matchedPreset = opt;
        break;
      }
    }

    final isCustomActive = _customModeExplicitlyChosen ||
        (currentText.isNotEmpty && matchedPreset == null);
    final selectedDropdownValue = isCustomActive
        ? MarketplaceEnginePowertrainField.customEngineOptionValue
        : matchedPreset?.label;

    final selectOptions = <MarketplaceSelectOption<String>>[
      for (final opt in options)
        MarketplaceSelectOption<String>(
          value: opt.label,
          label: opt.label,
          subtitle: opt.specsSubtitle,
          badge: opt.yearRangeLabel,
          searchKeywords: <String>[
            opt.manufacturer,
            opt.engineModel,
            opt.fuelType,
            if (opt.transmission != null) opt.transmission!,
            if (opt.powerHp != null) '${opt.powerHp} hp',
            if (opt.displacementL != null) '${opt.displacementL}l',
          ],
        ),
      const MarketplaceSelectOption<String>(
        value: MarketplaceEnginePowertrainField.customEngineOptionValue,
        label: MarketplaceEnginePowertrainField.customEngineOptionLabel,
        subtitle:
            'Enter custom, swapped, rebuilt, or VIN-decoded engine & transmission details',
        badge: 'Manual entry',
        isPinnedSpecial: true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MarketplaceSearchableSelectField<String>(
          semanticKey: const Key('step2_engine_config_trigger'),
          label: 'Engine / powertrain configuration',
          hintText: 'Select verified engine / powertrain...',
          value: selectedDropdownValue,
          options: selectOptions,
          headerBadge: '${options.length} options for year',
          prefixIcon: Icons.settings_outlined,
          searchHintText:
              'Search engine model, HP, liters, fuel, transmission...',
          emptyStateText:
              'No catalog engine matched that search — select "${MarketplaceEnginePowertrainField.customEngineOptionLabel}" below.',
          onChanged: (selected) {
            if (selected == null) return;
            if (selected ==
                MarketplaceEnginePowertrainField.customEngineOptionValue) {
              setState(() => _customModeExplicitlyChosen = true);
              return;
            }
            _customModeExplicitlyChosen = false;
            _setControllerTextSilently(selected);
            setState(() {});
            widget.onChanged?.call(selected);
          },
        ),
        if (isCustomActive) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.controller,
            onChanged: widget.onChanged,
            decoration: const InputDecoration(
              labelText: 'Custom engine / powertrain details',
              hintText:
                  'Refine or enter exact engine make/model, HP, fuel type, rebuild hours or transmission',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
        ],
      ],
    );
  }
}
