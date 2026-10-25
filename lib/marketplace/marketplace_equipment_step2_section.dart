import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'industrial_icon_assets.dart';
import 'marketplace_equipment_catalog.dart';
import 'marketplace_searchable_select.dart';
import 'marketplace_serial_decoder.dart';

/// Atomic selection payload for equipment manufacturer, year, model, and
/// optional product-type inference (from VIN/PIN decode or catalog quick-search).
@immutable
class EquipmentSpecSelection {
  const EquipmentSpecSelection({
    required this.brand,
    required this.year,
    required this.model,
    this.inferredProductType,
  });

  final String? brand;
  final int? year;
  final String? model;
  final String? inferredProductType;
}

/// Executive-grade Create Listing Step 2 equipment specification section:
/// 1. `# Serial number / PIN (optional)` with free hybrid NHTSA VIN + OEM PIN auto-fill
/// 2. Live 50+ year (`1970–2026`) quick-search bar across Make, Model & Year
/// 3. Searchable `Brand or manufacturer` selector (with manual fallback notice)
/// 4. `Model year` ABOVE `Model` (searchable year selector or manual 4-digit input)
/// 5. `Model` BELOW `Model year` (strictly year-filtered or manual Model # input)
/// 6. Selectable / adaptive `Engine / powertrain details` ABOVE `Machine hours`
/// 7. `Machine hours`, `Attachments`, `Operating status`, and `Maintenance history`
class MarketplaceEquipmentStep2Section extends StatefulWidget {
  const MarketplaceEquipmentStep2Section({
    super.key,
    required this.category,
    required this.productType,
    required this.catalog,
    required this.serialDecoder,
    required this.requiredSpecs,
    required this.selectedBrand,
    required this.selectedYear,
    required this.selectedModel,
    required this.operatingStatus,
    required this.maintenanceHistory,
    required this.serialNumberController,
    required this.customBrandController,
    required this.manualYearController,
    required this.manualModelController,
    required this.engineDetailsController,
    required this.machineHoursController,
    required this.attachmentsController,
    required this.onSelectionChanged,
    required this.onOperatingStatusChanged,
    required this.onMaintenanceHistoryChanged,
  });

  final String? category;
  final String? productType;
  final EquipmentCatalog catalog;
  final MarketplaceSerialDecoder serialDecoder;
  final bool requiredSpecs;
  final String? selectedBrand;
  final int? selectedYear;
  final String? selectedModel;
  final String operatingStatus;
  final String maintenanceHistory;
  final TextEditingController serialNumberController;
  final TextEditingController customBrandController;
  final TextEditingController manualYearController;
  final TextEditingController manualModelController;
  final TextEditingController engineDetailsController;
  final TextEditingController machineHoursController;
  final TextEditingController attachmentsController;
  final ValueChanged<EquipmentSpecSelection> onSelectionChanged;
  final ValueChanged<String> onOperatingStatusChanged;
  final ValueChanged<String> onMaintenanceHistoryChanged;

  @override
  State<MarketplaceEquipmentStep2Section> createState() =>
      _MarketplaceEquipmentStep2SectionState();
}

class _MarketplaceEquipmentStep2SectionState
    extends State<MarketplaceEquipmentStep2Section> {
  final TextEditingController _quickSearchController = TextEditingController();
  Timer? _serialDebounce;
  bool _decodingSerial = false;
  String? _lastAutoDecodedNormalized;
  SerialDecodeResult? _lastDecodeResult;
  String _quickSearchQuery = '';
  int _decodeRequestToken = 0;

  bool get _usesManualModelAndYear =>
      widget.selectedBrand != null &&
      widget.catalog.requiresManualModelAndYear(widget.selectedBrand);

  int? get _effectiveYear {
    if (_usesManualModelAndYear) {
      final parsed = int.tryParse(widget.manualYearController.text.trim());
      if (parsed != null && parsed >= 1900 && parsed <= 2100) {
        return parsed;
      }
      return null;
    }
    return widget.selectedYear;
  }

  @override
  void dispose() {
    _serialDebounce?.cancel();
    _quickSearchController.dispose();
    super.dispose();
  }

  void _onSerialTextChanged(String raw) {
    _serialDebounce?.cancel();
    final normalized = MarketplaceSerialDecoder.normalizeSerial(raw);
    if (normalized.isEmpty) {
      if (_lastDecodeResult != null || _lastAutoDecodedNormalized != null) {
        setState(() {
          _lastDecodeResult = null;
          _lastAutoDecodedNormalized = null;
        });
      }
      return;
    }
    setState(() {});
    // Automatically decode 17-character VINs and ISO 10261 equipment PINs
    // after a brief typing/paste settle window.
    if (normalized.length == 17 && normalized != _lastAutoDecodedNormalized) {
      _serialDebounce = Timer(const Duration(milliseconds: 420), () {
        if (!mounted) return;
        _decodeSerialAndApply(autoTriggered: true);
      });
    }
  }

  Future<void> _decodeSerialAndApply({required bool autoTriggered}) async {
    _serialDebounce?.cancel();
    final raw = widget.serialNumberController.text;
    final normalized = MarketplaceSerialDecoder.normalizeSerial(raw);
    if (normalized.length < 6) return;

    final requestId = ++_decodeRequestToken;
    setState(() => _decodingSerial = true);

    try {
      final result = await widget.serialDecoder.decode(
        raw,
        categoryContext: widget.category,
        catalog: widget.catalog,
        currentBrand: widget.selectedBrand,
      );
      if (!mounted || requestId != _decodeRequestToken) return;

      _lastAutoDecodedNormalized = normalized;
      setState(() {
        _decodingSerial = false;
        _lastDecodeResult = result;
      });

      if (!result.hasAnyDecodedField) return;

      String? nextBrand = widget.selectedBrand;
      int? nextYear = widget.selectedYear;
      String? nextModel = widget.selectedModel;

      // 1. Resolve Manufacturer
      if (result.manufacturer != null &&
          result.manufacturer!.trim().isNotEmpty) {
        final mfrEntry = widget.catalog.findManufacturer(result.manufacturer);
        if (mfrEntry != null) {
          nextBrand = mfrEntry.name;
        } else {
          nextBrand = kManualCatalogOptionValue;
          widget.customBrandController.text = result.manufacturer!.trim();
        }
      }

      final brandRequiresManual = nextBrand != null &&
          widget.catalog.requiresManualModelAndYear(nextBrand);

      // 2. Resolve Model Year (ONLY when genuinely decoded — never hallucinated!)
      if (result.modelYear != null) {
        nextYear = result.modelYear;
        widget.manualYearController.text = '${result.modelYear}';
      } else if (brandRequiresManual) {
        nextYear = int.tryParse(widget.manualYearController.text.trim());
      }

      // 3. Resolve Model against 50-year catalog or manual fallback
      final candidateModel = result.effectiveModel?.trim();
      if (candidateModel != null && candidateModel.isNotEmpty) {
        if (brandRequiresManual) {
          nextModel = null;
          widget.manualModelController.text = candidateModel;
        } else {
          final matchedEntry = widget.catalog.findModel(
            nextBrand,
            candidateModel,
            modelYear: result.modelYear,
          );
          if (matchedEntry != null) {
            nextModel = matchedEntry.model;
            // If PIN did not encode year (e.g. Caterpillar), clear any stale
            // incompatible year or auto-select if single-year production run.
            if (result.modelYear == null) {
              if (matchedEntry.yearFrom == matchedEntry.yearTo) {
                nextYear = matchedEntry.yearFrom;
              } else if (nextYear != null &&
                  !matchedEntry.supportsYear(nextYear)) {
                nextYear = null;
              }
            }
          } else {
            nextModel = kManualCatalogOptionValue;
            widget.manualModelController.text = candidateModel;
          }
        }
      }

      // 4. Populate Engine / Powertrain if decoded from NHTSA vPIC or catalog
      if (result.engineSummary != null &&
          result.engineSummary!.trim().isNotEmpty) {
        widget.engineDetailsController.text = result.engineSummary!.trim();
      } else if (!brandRequiresManual &&
          nextBrand != null &&
          nextModel != null &&
          nextModel != kManualCatalogOptionValue) {
        final engines = widget.catalog.engineOptionsFor(
          brand: nextBrand,
          model: nextModel,
          modelYear: nextYear,
        );
        if (engines.length == 1) {
          widget.engineDetailsController.text = engines.first.label;
        }
      }

      widget.onSelectionChanged(
        EquipmentSpecSelection(
          brand: nextBrand,
          year: nextYear,
          model: nextModel,
          inferredProductType: result.productTypeHint,
        ),
      );
    } catch (_) {
      if (!mounted || requestId != _decodeRequestToken) return;
      setState(() => _decodingSerial = false);
      if (!autoTriggered) {
        setState(() {
          _lastDecodeResult = SerialDecodeResult(
            rawInput: raw,
            normalizedInput: normalized,
            confidence: SerialDecodeConfidence.none,
            source: SerialDecodeSource.unrecognized,
            userMessage:
                'Live VIN lookup is temporarily unavailable — select or enter Manufacturer, Model Year, and Model below.',
          );
        });
      }
    }
  }

  void _handleBrandSelected(String? nextBrand) {
    if (nextBrand == widget.selectedBrand) return;
    if (nextBrand != kManualCatalogOptionValue) {
      widget.customBrandController.clear();
    }
    widget.manualYearController.clear();
    widget.manualModelController.clear();
    widget.engineDetailsController.clear();
    widget.onSelectionChanged(
      EquipmentSpecSelection(
        brand: nextBrand,
        year: null,
        model: null,
      ),
    );
  }

  void _handleCatalogYearSelected(int? nextYear) {
    if (nextYear == widget.selectedYear) return;
    var nextModel = widget.selectedModel;
    if (nextYear != null &&
        nextModel != null &&
        nextModel != kManualCatalogOptionValue) {
      final entry = widget.catalog.findModel(
        widget.selectedBrand,
        nextModel,
        modelYear: nextYear,
      );
      if (entry == null || !entry.supportsYear(nextYear)) {
        nextModel = null;
        widget.engineDetailsController.clear();
      }
    }
    widget.onSelectionChanged(
      EquipmentSpecSelection(
        brand: widget.selectedBrand,
        year: nextYear,
        model: nextModel,
      ),
    );
  }

  void _handleCatalogModelSelected(String? nextModel) {
    if (nextModel == widget.selectedModel) return;
    if (nextModel == null) {
      widget.manualModelController.clear();
      widget.engineDetailsController.clear();
      widget.onSelectionChanged(
        EquipmentSpecSelection(
          brand: widget.selectedBrand,
          year: widget.selectedYear,
          model: null,
        ),
      );
      return;
    }
    if (nextModel != kManualCatalogOptionValue) {
      widget.manualModelController.clear();
    }
    var nextYear = widget.selectedYear;
    if (nextModel != kManualCatalogOptionValue) {
      final entry = widget.catalog.findModel(
        widget.selectedBrand,
        nextModel,
        modelYear: nextYear,
      );
      if (entry != null) {
        if (nextYear != null && !entry.supportsYear(nextYear)) {
          nextYear = entry.yearFrom == entry.yearTo ? entry.yearFrom : null;
          widget.engineDetailsController.clear();
        } else if (nextYear == null && entry.yearFrom == entry.yearTo) {
          nextYear = entry.yearFrom;
        }
      }
    }
    widget.onSelectionChanged(
      EquipmentSpecSelection(
        brand: widget.selectedBrand,
        year: nextYear,
        model: nextModel,
      ),
    );
  }

  void _applyQuickSearchHit(_QuickCatalogHit hit) {
    _quickSearchController.clear();
    setState(() => _quickSearchQuery = '');
    FocusScope.of(context).unfocus();

    if (hit.modelEntry == null) {
      // Manual-entry manufacturer selected from quick search
      widget.manualYearController.clear();
      widget.manualModelController.clear();
      widget.engineDetailsController.clear();
      if (hit.presetManualModel != null) {
        widget.manualModelController.text = hit.presetManualModel!;
      }
      if (hit.queryYear != null) {
        widget.manualYearController.text = '${hit.queryYear}';
      }
      widget.onSelectionChanged(
        EquipmentSpecSelection(
          brand: hit.manufacturer.name,
          year: hit.queryYear,
          model: null,
        ),
      );
      return;
    }

    final entry = hit.modelEntry!;
    int? resolvedYear = hit.queryYear;
    if (resolvedYear == null) {
      if (widget.selectedYear != null &&
          entry.supportsYear(widget.selectedYear)) {
        resolvedYear = widget.selectedYear;
      } else if (entry.yearFrom == entry.yearTo) {
        resolvedYear = entry.yearFrom;
      }
    }

    final engines = entry.enginesForYear(resolvedYear);
    if (engines.length == 1) {
      widget.engineDetailsController.text = engines.first.label;
    } else {
      widget.engineDetailsController.clear();
    }

    widget.onSelectionChanged(
      EquipmentSpecSelection(
        brand: hit.manufacturer.name,
        year: resolvedYear,
        model: entry.model,
        inferredProductType:
            entry.productTypes.isNotEmpty ? entry.productTypes.first : null,
      ),
    );
  }

  List<_QuickCatalogHit> _computeQuickSearchHits(String rawQuery) {
    final trimmed = rawQuery.trim();
    if (trimmed.length < 2) return const <_QuickCatalogHit>[];

    final rawTokens = trimmed
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    if (rawTokens.isEmpty) return const <_QuickCatalogHit>[];

    int? parsedYear;
    final textTokens = <String>[];
    for (final token in rawTokens) {
      final maybeYear = int.tryParse(token);
      if (parsedYear == null &&
          token.length == 4 &&
          maybeYear != null &&
          maybeYear >= widget.catalog.yearFloor &&
          maybeYear <= widget.catalog.yearCeiling) {
        parsedYear = maybeYear;
      } else {
        textTokens.add(token);
      }
    }

    // Require at least one non-year token unless a brand is already chosen.
    if (textTokens.isEmpty && widget.selectedBrand == null) {
      return const <_QuickCatalogHit>[];
    }

    final hits = <_QuickCatalogHit>[];
    final manufacturers = widget.catalog.manufacturersFor(
      category: widget.category,
      includeAllBrands: true,
    );

    for (final mfr in manufacturers) {
      final brandContextMatches = widget.selectedBrand != null &&
          widget.selectedBrand!.toLowerCase() == mfr.name.toLowerCase();

      if (mfr.hasVerifiedYearModelCatalog) {
        for (final mdl in mfr.models) {
          if (parsedYear != null && !mdl.supportsYear(parsedYear)) continue;

          final searchable = <String>[
            mfr.name,
            ...mfr.aliases,
            mdl.model,
            mdl.series,
            ...mdl.aliases,
            ...mdl.productTypes,
          ].join(' ').toLowerCase();
          final compact = searchable.replaceAll(RegExp(r'[^a-z0-9]'), '');

          var allMatch = true;
          for (final tok in textTokens) {
            final compactTok = tok.replaceAll(RegExp(r'[^a-z0-9]'), '');
            if (!searchable.contains(tok) &&
                (compactTok.isEmpty || !compact.contains(compactTok))) {
              allMatch = false;
              break;
            }
          }
          if (!allMatch) continue;

          var score = 0;
          final lowerModel = mdl.model.toLowerCase();
          final lowerBrandModel = '${mfr.name} ${mdl.model}'.toLowerCase();
          final joinedText = textTokens.join(' ');
          if (lowerModel == joinedText || lowerBrandModel == joinedText) {
            score += 120;
          } else if (lowerModel.startsWith(joinedText) ||
              lowerBrandModel.contains(joinedText)) {
            score += 70;
          }
          if (brandContextMatches) score += 35;
          if (widget.category != null && mdl.category == widget.category) {
            score += 25;
          }
          if (widget.productType != null &&
              mdl.matchesProductType(widget.productType)) {
            score += 20;
          }
          score += (mdl.yearTo - 1970) ~/ 10;

          hits.add(
            _QuickCatalogHit(
              manufacturer: mfr,
              modelEntry: mdl,
              queryYear: parsedYear,
              score: score,
            ),
          );
        }
      } else if (textTokens.isNotEmpty) {
        // Check manual-entry manufacturer & example models
        String? matchedExample;
        for (final ex in mfr.exampleModels) {
          final combined =
              '${mfr.name} ${mfr.aliases.join(' ')} $ex'.toLowerCase();
          if (textTokens.every((t) => combined.contains(t))) {
            matchedExample = ex;
            break;
          }
        }
        final brandOnly = '${mfr.name} ${mfr.aliases.join(' ')}'.toLowerCase();
        if (matchedExample != null ||
            textTokens.every((t) => brandOnly.contains(t))) {
          hits.add(
            _QuickCatalogHit(
              manufacturer: mfr,
              modelEntry: null,
              presetManualModel: matchedExample,
              queryYear: parsedYear,
              score: matchedExample != null ? 55 : 30,
            ),
          );
        }
      }
    }

    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byBrand = a.manufacturer.name.compareTo(b.manufacturer.name);
      if (byBrand != 0) return byBrand;
      return (a.modelEntry?.model ?? '').compareTo(b.modelEntry?.model ?? '');
    });

    return hits.take(8).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor =
        isDark ? PipeBuyerColors.darkMuted : PipeBuyerColors.muted;
    final isTransport = widget.category == 'Transport & Hauling';

    final categoryManufacturers = widget.catalog.manufacturersFor(
      category: widget.category,
      includeAllBrands: false,
    );
    final allManufacturers = widget.catalog.allManufacturers;

    MarketplaceSelectOption<String> toBrandOption(
      EquipmentManufacturerEntry mfr,
    ) {
      final hasCatalog = mfr.hasVerifiedYearModelCatalog;
      final yearSpan =
          hasCatalog && mfr.minModelYear != null && mfr.maxModelYear != null
              ? '${mfr.minModelYear}–${mfr.maxModelYear}'
              : null;
      return MarketplaceSelectOption<String>(
        value: mfr.name,
        label: mfr.name,
        subtitle: hasCatalog
            ? '${mfr.models.length} verified models${yearSpan != null ? ' ($yearSpan)' : ''}'
            : 'Manual Model # & Model Year entry',
        badge: hasCatalog ? yearSpan : 'Manual entry',
        searchKeywords: <String>[
          ...mfr.aliases,
          ...mfr.wmiPrefixes,
          ...mfr.exampleModels,
          ...mfr.categories,
        ],
      );
    }

    const manualBrandOption = MarketplaceSelectOption<String>(
      value: kManualCatalogOptionValue,
      label: kManualCatalogOptionValue,
      subtitle:
          'Manufacturer not listed — enter Brand, Model Year, and Model # manually',
      badge: 'Manual entry',
      isPinnedSpecial: true,
    );

    final primaryBrandOptions = <MarketplaceSelectOption<String>>[
      for (final mfr in categoryManufacturers) toBrandOption(mfr),
      manualBrandOption,
    ];
    final unfilteredBrandOptions =
        categoryManufacturers.length < allManufacturers.length
            ? <MarketplaceSelectOption<String>>[
                for (final mfr in allManufacturers) toBrandOption(mfr),
                manualBrandOption,
              ]
            : null;

    final selectedManufacturerEntry =
        widget.catalog.findManufacturer(widget.selectedBrand);
    final usesManual = _usesManualModelAndYear;

    // Year options (strictly locked to selected catalog model's manufactured years!)
    final catalogModelFilter = (!usesManual &&
            widget.selectedModel != null &&
            widget.selectedModel != kManualCatalogOptionValue)
        ? widget.selectedModel
        : null;
    final selectedModelEntry = catalogModelFilter != null
        ? widget.catalog.findModel(
            widget.selectedBrand,
            catalogModelFilter,
            modelYear: widget.selectedYear,
          )
        : null;
    final scopedYears = widget.catalog.yearsFor(
      brand: widget.selectedBrand,
      model: catalogModelFilter,
    );

    MarketplaceSelectOption<int> toYearOption(int year) {
      String? subtitle;
      String? badge;
      if (!usesManual && selectedModelEntry != null) {
        final enginesInYear = selectedModelEntry.enginesForYear(year);
        final enginePreview = enginesInYear.isEmpty
            ? null
            : enginesInYear.length == 1
                ? [
                    enginesInYear.first.manufacturer,
                    enginesInYear.first.engineModel,
                  ].where((s) => s.isNotEmpty).join(' ')
                : '${enginesInYear.length} engine options';
        final brandTitle =
            selectedManufacturerEntry?.name ?? widget.selectedBrand ?? '';
        subtitle = <String>[
          '$brandTitle ${selectedModelEntry.model}'.trim(),
          'Manufactured ${selectedModelEntry.yearRangeLabel}',
          if (enginePreview != null && enginePreview.isNotEmpty) enginePreview,
        ].join(' • ');
        badge = selectedModelEntry.yearRangeLabel;
      } else if (!usesManual &&
          selectedManufacturerEntry != null &&
          selectedManufacturerEntry.hasVerifiedYearModelCatalog) {
        final count = selectedManufacturerEntry.models
            .where((m) => m.supportsYear(year))
            .length;
        subtitle = '$count verified ${selectedManufacturerEntry.name} '
            '${count == 1 ? 'model' : 'models'} in $year';
      }
      return MarketplaceSelectOption<int>(
        value: year,
        label: '$year',
        subtitle: subtitle,
        badge: badge,
      );
    }

    final yearOptions = scopedYears.map(toYearOption).toList(growable: false);

    // Model options (strictly filtered to selectedYear!)
    final allYearModels = !usesManual && widget.selectedBrand != null
        ? widget.catalog.modelsFor(
            brand: widget.selectedBrand,
            modelYear: widget.selectedYear,
            productType: widget.productType,
            strictProductType: false,
          )
        : const <EquipmentModelEntry>[];

    final hasProductTypeScope = !usesManual &&
        widget.productType != null &&
        widget.productType!.trim().isNotEmpty &&
        widget.productType != kManualCatalogOptionValue;
    final strictTypeModels = hasProductTypeScope && widget.selectedBrand != null
        ? widget.catalog.modelsFor(
            brand: widget.selectedBrand,
            modelYear: widget.selectedYear,
            productType: widget.productType,
            strictProductType: true,
          )
        : const <EquipmentModelEntry>[];

    final useStrictTypeDefault = strictTypeModels.isNotEmpty &&
        strictTypeModels.length < allYearModels.length;

    MarketplaceSelectOption<String> toModelOption(EquipmentModelEntry entry) {
      final enginesInYear = entry.enginesForYear(widget.selectedYear);
      final enginePreview = enginesInYear.isEmpty
          ? null
          : enginesInYear.length == 1
              ? [
                  enginesInYear.first.manufacturer,
                  enginesInYear.first.engineModel,
                ].where((s) => s.isNotEmpty).join(' ')
              : '${enginesInYear.length} engine options';
      final subtitleParts = <String>[
        'Manufactured ${entry.yearRangeLabel}',
        if (entry.series.isNotEmpty) entry.series,
        if (enginePreview != null && enginePreview.isNotEmpty) enginePreview,
      ];
      return MarketplaceSelectOption<String>(
        value: entry.model,
        label: '${entry.model} (${entry.yearRangeLabel})',
        subtitle: subtitleParts.join(' • '),
        badge: entry.yearRangeLabel,
        searchKeywords: <String>[
          entry.model,
          ...entry.aliases,
          entry.series,
          ...entry.productTypes,
          entry.yearRangeLabel,
          for (int y = entry.yearFrom; y <= entry.yearTo; y++) '$y',
          for (final eng in entry.engines) ...<String>[
            eng.manufacturer,
            eng.engineModel,
            eng.fuelType,
          ],
        ],
      );
    }

    const manualModelOption = MarketplaceSelectOption<String>(
      value: kManualCatalogOptionValue,
      label: kManualCatalogOptionValue,
      subtitle: 'Model not listed for this year — enter Model # manually',
      badge: 'Manual entry',
      isPinnedSpecial: true,
    );

    final primaryModelEntries =
        useStrictTypeDefault ? strictTypeModels : allYearModels;
    final modelOptions = <MarketplaceSelectOption<String>>[
      for (final entry in primaryModelEntries) toModelOption(entry),
      manualModelOption,
    ];
    final unfilteredModelOptions = useStrictTypeDefault
        ? <MarketplaceSelectOption<String>>[
            for (final entry in allYearModels) toModelOption(entry),
            manualModelOption,
          ]
        : null;

    // Engine / Powertrain options for selected (brand, model, effectiveYear)
    final engineOptions = (!usesManual &&
            widget.selectedBrand != null &&
            widget.selectedModel != null &&
            widget.selectedModel != kManualCatalogOptionValue)
        ? widget.catalog.engineOptionsFor(
            brand: widget.selectedBrand,
            model: widget.selectedModel,
            modelYear: _effectiveYear,
          )
        : const <EquipmentEngineOption>[];

    final quickHits = _computeQuickSearchHits(_quickSearchQuery);
    final normalizedSerial = MarketplaceSerialDecoder.normalizeSerial(
      widget.serialNumberController.text,
    );

    final effectiveOperatingStatus =
        _operatingStatusOptions.contains(widget.operatingStatus)
            ? widget.operatingStatus
            : _operatingStatusOptions.first;
    final effectiveMaintenanceHistory =
        _maintenanceHistoryOptions.contains(widget.maintenanceHistory)
            ? widget.maintenanceHistory
            : _maintenanceHistoryOptions.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ====================================================================
        // 1. SERIAL NUMBER / PIN (FIRST ITEM IN STEP 2 — ABOVE MANUFACTURER)
        // ====================================================================
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? PipeBuyerColors.darkSurfaceMuted
                : PipeBuyerColors.industrialBlue.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? PipeBuyerColors.darkLine
                  : PipeBuyerColors.industrialBlue.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                key: const Key('step2_serial_pin_field'),
                controller: widget.serialNumberController,
                textCapitalization: TextCapitalization.characters,
                onChanged: _onSerialTextChanged,
                onFieldSubmitted: (_) =>
                    _decodeSerialAndApply(autoTriggered: false),
                decoration: InputDecoration(
                  labelText: '# Serial number / PIN (optional)',
                  hintText: isTransport
                      ? '17-character truck/trailer VIN or serial #'
                      : '17-character machine PIN / VIN or equipment serial #',
                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.serialNumberController.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear serial / PIN',
                          onPressed: () {
                            widget.serialNumberController.clear();
                            _onSerialTextChanged('');
                          },
                          icon: const Icon(Icons.clear_rounded, size: 18),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: TextButton.icon(
                          key: const Key('step2_serial_autofill_button'),
                          onPressed: _decodingSerial ||
                                  normalizedSerial.length < 6
                              ? null
                              : () =>
                                  _decodeSerialAndApply(autoTriggered: false),
                          icon: _decodingSerial
                              ? const SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_fix_high_rounded,
                                  size: 16,
                                ),
                          label: Text(
                            _decodingSerial ? 'Decoding…' : 'Auto-fill',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                key: const Key('step2_serial_autofill_note'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: isDark
                        ? PipeBuyerColors.orange
                        : PipeBuyerColors.industrialBlue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Attempt auto-fill with VIN # or equipment PIN: Enter a 17-character truck/trailer VIN (US DOT NHTSA) or heavy-equipment PIN / serial # (Caterpillar, John Deere, Bobcat, Komatsu, JCB, Case, Kubota, Volvo CE & more) to auto-detect Make, Model Year, Model, and Engine specs when encoded.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.32,
                        color: mutedColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (_lastDecodeResult != null) ...<Widget>[
                const SizedBox(height: 10),
                _SerialDecodeStatusBanner(
                  key: const Key('step2_serial_decode_banner'),
                  result: _lastDecodeResult!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ====================================================================
        // 2. STEP 2 QUICK CATALOG SEARCH BAR (ACROSS 50+ YEARS MAKE/MODEL/YEAR)
        // ====================================================================
        TextField(
          key: const Key('step2_catalog_quick_search_field'),
          controller: _quickSearchController,
          onChanged: (value) => setState(() => _quickSearchQuery = value),
          decoration: InputDecoration(
            labelText: 'Search make, model or year',
            hintText: isTransport
                ? 'Quick-find e.g. 2020 Peterbilt 389, Kenworth T880, Cascadia...'
                : 'Quick-find e.g. 2022 Bobcat T76, Cat 320D, Deere 333G...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _quickSearchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear catalog search',
                    onPressed: () {
                      _quickSearchController.clear();
                      setState(() => _quickSearchQuery = '');
                    },
                    icon: const Icon(Icons.clear_rounded, size: 18),
                  ),
          ),
        ),
        if (quickHits.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Container(
            key: const Key('step2_catalog_quick_search_results'),
            decoration: BoxDecoration(
              color: isDark ? PipeBuyerColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? PipeBuyerColors.darkLine : PipeBuyerColors.line,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < quickHits.length; i++) ...<Widget>[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: isDark
                          ? PipeBuyerColors.darkLine
                          : PipeBuyerColors.line,
                    ),
                  _QuickSearchHitTile(
                    hit: quickHits[i],
                    onTap: () => _applyQuickSearchHit(quickHits[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),

        // ====================================================================
        // 3. BRAND OR MANUFACTURER (SEARCHABLE SELECTOR)
        // ====================================================================
        MarketplaceSearchableSelectField<String>(
          key: const Key('step2_brand_select_field'),
          semanticKey: const Key('step2_brand_select_trigger'),
          label: widget.requiredSpecs
              ? 'Brand or manufacturer *'
              : 'Brand or manufacturer',
          hintText: 'Search or select manufacturer...',
          value: widget.selectedBrand,
          options: primaryBrandOptions,
          allOptionsWhenUnfiltered: unfilteredBrandOptions,
          filterChipLabel: unfilteredBrandOptions == null
              ? null
              : 'Showing ${widget.category ?? 'category'} manufacturers (${categoryManufacturers.length}) — Tap to show all ${allManufacturers.length}',
          prefixIcon: Icons.factory_outlined,
          searchHintText:
              'Search manufacturer or alias (e.g. CAT, Deere, Doosan, Peterbilt)...',
          emptyStateText:
              'No manufacturer matched — select "$kManualCatalogOptionValue" below.',
          onChanged: _handleBrandSelected,
          validator: (selectedValue) =>
              widget.requiredSpecs && selectedValue == null
                  ? 'Select a manufacturer'
                  : null,
        ),
        if (widget.selectedBrand == kManualCatalogOptionValue) ...<Widget>[
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('step2_custom_brand_field'),
            controller: widget.customBrandController,
            decoration: InputDecoration(
              labelText: widget.requiredSpecs
                  ? 'Enter manufacturer *'
                  : 'Enter manufacturer',
              hintText: 'Exact OEM or fabricator name',
              prefixIcon: const Icon(Icons.edit_outlined),
            ),
            validator: (value) =>
                widget.selectedBrand == kManualCatalogOptionValue &&
                        widget.requiredSpecs &&
                        (value == null || value.trim().isEmpty)
                    ? 'Enter the manufacturer'
                    : null,
          ),
        ],
        if (usesManual) ...<Widget>[
          const SizedBox(height: 10),
          _ManualEntryManufacturerBanner(
            key: const Key('step2_manual_entry_notice'),
            brandName: widget.selectedBrand == kManualCatalogOptionValue
                ? 'Custom manufacturer'
                : (widget.selectedBrand ?? ''),
            reason: selectedManufacturerEntry?.manualEntryReason,
            exampleModels:
                selectedManufacturerEntry?.exampleModels ?? const <String>[],
            onExampleModelSelected: (example) {
              setState(() => widget.manualModelController.text = example);
            },
          ),
        ],
        const SizedBox(height: 12),

        // ====================================================================
        // 4. MODEL YEAR (BROUGHT ABOVE MODEL!)
        // ====================================================================
        if (usesManual)
          TextFormField(
            key: const Key('step2_manual_year_field'),
            controller: widget.manualYearController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            onChanged: (raw) {
              final parsed = int.tryParse(raw.trim());
              final validYear =
                  (parsed != null && parsed >= 1900 && parsed <= 2100)
                      ? parsed
                      : null;
              widget.onSelectionChanged(
                EquipmentSpecSelection(
                  brand: widget.selectedBrand,
                  year: validYear,
                  model: null,
                ),
              );
            },
            decoration: InputDecoration(
              labelText: widget.requiredSpecs
                  ? 'Enter model year *'
                  : 'Enter model year (optional)',
              hintText: '4-digit model year (e.g. 2021)',
              prefixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) {
                return widget.requiredSpecs ? 'Enter the model year' : null;
              }
              final year = int.tryParse(trimmed);
              final maxYear = DateTime.now().year + 1;
              if (year == null || year < 1900 || year > maxYear) {
                return 'Enter a valid 4-digit year (1900–$maxYear)';
              }
              return null;
            },
          )
        else
          MarketplaceSearchableSelectField<int>(
            key: const Key('step2_year_select_field'),
            semanticKey: const Key('step2_year_select_trigger'),
            clearButtonKey: const Key('step2_year_clear_button'),
            allowClear: true,
            clearTooltip: 'Clear model year',
            label: widget.requiredSpecs ? 'Model year *' : 'Model year',
            modalTitle: selectedModelEntry != null
                ? '${widget.selectedBrand ?? ''} ${selectedModelEntry.model} — Manufactured Years (${selectedModelEntry.yearRangeLabel})'
                    .trim()
                : null,
            headerBadge: selectedModelEntry?.yearRangeLabel,
            hintText: selectedModelEntry != null
                ? 'Select year (${selectedModelEntry.yearRangeLabel})...'
                : catalogModelFilter != null && scopedYears.isNotEmpty
                    ? 'Select year (${scopedYears.last}–${scopedYears.first})...'
                    : 'Search or select model year...',
            helperText: selectedModelEntry != null
                ? 'Manufactured years for ${widget.selectedBrand ?? ''} ${selectedModelEntry.model}: ${selectedModelEntry.yearRangeLabel}'
                    .trim()
                : catalogModelFilter != null && scopedYears.isNotEmpty
                    ? 'Valid production window for $catalogModelFilter: '
                        '${scopedYears.last == scopedYears.first ? '${scopedYears.first}' : '${scopedYears.last}–${scopedYears.first}'}'
                    : null,
            value: widget.selectedYear,
            options: yearOptions,
            prefixIcon: Icons.calendar_today_outlined,
            searchHintText: selectedModelEntry != null
                ? 'Type 4-digit year in ${selectedModelEntry.yearRangeLabel}...'
                : 'Type 4-digit year (e.g. 2023, 2018, 1995)...',
            emptyStateText: selectedModelEntry != null
                ? 'No matching year — ${selectedModelEntry.model} was manufactured ${selectedModelEntry.yearRangeLabel}.'
                : 'No matching year in range.',
            onChanged: _handleCatalogYearSelected,
            validator: (selectedValue) =>
                widget.requiredSpecs && selectedValue == null
                    ? 'Select the model year'
                    : null,
          ),
        const SizedBox(height: 12),

        // ====================================================================
        // 5. MODEL (BELOW MODEL YEAR — STRICTLY COUPLED TO MODEL YEAR!)
        // ====================================================================
        if (usesManual)
          TextFormField(
            key: const Key('step2_manual_model_field'),
            controller: widget.manualModelController,
            decoration: InputDecoration(
              labelText:
                  widget.requiredSpecs ? 'Enter model # *' : 'Enter model #',
              hintText: selectedManufacturerEntry != null &&
                      selectedManufacturerEntry.exampleModels.isNotEmpty
                  ? 'Example: ${selectedManufacturerEntry.exampleModels.take(3).join(', ')}'
                  : 'Exact model number from unit data plate',
              prefixIcon: const Icon(Icons.precision_manufacturing_outlined),
            ),
            validator: (value) =>
                widget.requiredSpecs && (value == null || value.trim().isEmpty)
                    ? 'Enter the model #'
                    : null,
          )
        else ...<Widget>[
          MarketplaceSearchableSelectField<String>(
            key: const Key('step2_model_select_field'),
            semanticKey: const Key('step2_model_select_trigger'),
            clearButtonKey: const Key('step2_model_clear_button'),
            allowClear: true,
            clearTooltip: 'Clear model',
            label: widget.requiredSpecs ? 'Model *' : 'Model',
            hintText: widget.selectedBrand == null
                ? 'Select manufacturer first...'
                : widget.selectedYear != null
                    ? 'Search ${widget.selectedYear} ${widget.selectedBrand} models...'
                    : 'Search ${widget.selectedBrand} models (with manufactured years)...',
            helperText: widget.selectedBrand != null &&
                    widget.selectedYear != null
                ? 'Showing ${allYearModels.length} verified ${widget.selectedBrand} '
                    '${allYearModels.length == 1 ? 'model' : 'models'} manufactured in ${widget.selectedYear}'
                : widget.selectedBrand != null && allYearModels.isNotEmpty
                    ? 'Showing ${allYearModels.length} verified ${widget.selectedBrand} models with manufactured year ranges'
                    : null,
            enabled: widget.selectedBrand != null,
            value: widget.selectedModel,
            options: modelOptions,
            allOptionsWhenUnfiltered: unfilteredModelOptions,
            filterChipLabel: unfilteredModelOptions == null
                ? null
                : 'Showing ${widget.productType} models (${strictTypeModels.length}) — Tap to show all ${allYearModels.length} ${widget.selectedBrand} models',
            prefixIcon: Icons.precision_manufacturing_outlined,
            searchHintText:
                'Search model #, manufactured years, series, or engine (e.g. SV340B, 2022, T76)...',
            emptyStateText: widget.selectedYear != null
                ? 'No catalog model matched for ${widget.selectedYear} — select "$kManualCatalogOptionValue" below.'
                : 'No catalog model matched — select "$kManualCatalogOptionValue" below.',
            onChanged: _handleCatalogModelSelected,
            validator: (selectedValue) =>
                widget.requiredSpecs && selectedValue == null
                    ? 'Select a model'
                    : null,
          ),
          if (widget.selectedModel == kManualCatalogOptionValue) ...<Widget>[
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('step2_custom_model_field'),
              controller: widget.manualModelController,
              decoration: InputDecoration(
                labelText:
                    widget.requiredSpecs ? 'Enter model # *' : 'Enter model #',
                hintText: 'Exact model # from data plate',
                prefixIcon: const Icon(Icons.edit_outlined),
              ),
              validator: (value) =>
                  widget.selectedModel == kManualCatalogOptionValue &&
                          widget.requiredSpecs &&
                          (value == null || value.trim().isEmpty)
                      ? 'Enter the model #'
                      : null,
            ),
          ],
        ],
        const SizedBox(height: 12),

        // ====================================================================
        // 6. ENGINE / POWERTRAIN DETAILS (MOVED ABOVE MACHINE HOURS!)
        // ====================================================================
        MarketplaceEnginePowertrainField(
          key: const Key('step2_engine_powertrain_field'),
          engineOptions: engineOptions,
          controller: widget.engineDetailsController,
          brand: widget.selectedBrand,
          model: widget.selectedModel,
          modelYear: _effectiveYear,
        ),
        const SizedBox(height: 12),

        // ====================================================================
        // 7. MACHINE HOURS (BELOW ENGINE / POWERTRAIN DETAILS!)
        // ====================================================================
        TextFormField(
          key: const Key('step2_machine_hours_field'),
          controller: widget.machineHoursController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                isTransport ? 'Engine / PTO hours (optional)' : 'Machine hours',
            suffixText: 'hours',
            prefixIcon: const Icon(Icons.schedule),
          ),
        ),
        const SizedBox(height: 12),

        // ====================================================================
        // 8. ATTACHMENTS, OPERATING STATUS & MAINTENANCE HISTORY
        // ====================================================================
        TextFormField(
          key: const Key('step2_attachments_field'),
          controller: widget.attachmentsController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Attachments and included equipment',
            hintText: isTransport
                ? 'Wet kit, winch, headache rack, ramps, tarps, chains, etc.'
                : 'Buckets, forks, thumb, quick coupler, auxiliary hydraulics, etc.',
            prefixIcon: const Icon(Icons.construction_outlined),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('step2_operating_$effectiveOperatingStatus'),
          initialValue: effectiveOperatingStatus,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Operating status',
            prefixIcon: Icon(Icons.engineering_outlined),
          ),
          selectedItemBuilder: (context) => _operatingStatusOptions
              .map(
                (value) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(value),
                ),
              )
              .toList(growable: false),
          items: _operatingStatusOptions.map((value) {
            final visual = _operatingVisual(value);
            return DropdownMenuItem<String>(
              value: value,
              child: MarketplaceFormOption(
                label: value,
                icon: visual.icon,
                iconColor: visual.color,
              ),
            );
          }).toList(growable: false),
          onChanged: (value) =>
              widget.onOperatingStatusChanged(value ?? 'Operational'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey<String>(
            'step2_maintenance_$effectiveMaintenanceHistory',
          ),
          initialValue: effectiveMaintenanceHistory,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Maintenance history',
            prefixIcon: Icon(Icons.history_outlined),
          ),
          selectedItemBuilder: (context) => _maintenanceHistoryOptions
              .map(
                (value) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(value),
                ),
              )
              .toList(growable: false),
          items: _maintenanceHistoryOptions.map((value) {
            final visual = _maintenanceVisual(value);
            return DropdownMenuItem<String>(
              value: value,
              child: MarketplaceFormOption(
                label: value,
                icon: visual.icon,
                iconColor: visual.color,
              ),
            );
          }).toList(growable: false),
          onChanged: (value) => widget.onMaintenanceHistoryChanged(
            value ?? 'Unknown / not available',
          ),
        ),
      ],
    );
  }
}

const List<String> _operatingStatusOptions = <String>[
  'Operational',
  'Operational with known issues',
  'Not currently operational',
  'For parts / rebuild',
];

const List<String> _maintenanceHistoryOptions = <String>[
  'Full documented history',
  'Partial maintenance records',
  'Owner-maintained — no records',
  'Unknown / not available',
];

({IconData icon, Color color}) _operatingVisual(String value) {
  final label = value.toLowerCase();
  if (label == 'operational') {
    return (icon: Icons.check_circle_outline, color: Colors.green);
  }
  if (label.contains('known issues')) {
    return (icon: Icons.warning_amber_outlined, color: Colors.orange);
  }
  if (label.contains('not currently')) {
    return (icon: Icons.cancel_outlined, color: Colors.red);
  }
  return (icon: Icons.handyman_outlined, color: const Color(0xFF66758A));
}

({IconData icon, Color color}) _maintenanceVisual(String value) {
  final label = value.toLowerCase();
  if (label.contains('full documented')) {
    return (icon: Icons.fact_check_outlined, color: Colors.green);
  }
  if (label.contains('partial')) {
    return (icon: Icons.description_outlined, color: Colors.orange);
  }
  if (label.contains('owner-maintained')) {
    return (
      icon: Icons.handyman_outlined,
      color: PipeBuyerColors.industrialBlue
    );
  }
  return (icon: Icons.help_outline, color: const Color(0xFF66758A));
}

class _QuickCatalogHit {
  const _QuickCatalogHit({
    required this.manufacturer,
    required this.modelEntry,
    required this.score,
    this.queryYear,
    this.presetManualModel,
  });

  final EquipmentManufacturerEntry manufacturer;
  final EquipmentModelEntry? modelEntry;
  final int? queryYear;
  final String? presetManualModel;
  final int score;
}

class _QuickSearchHitTile extends StatelessWidget {
  const _QuickSearchHitTile({
    required this.hit,
    required this.onTap,
  });

  final _QuickCatalogHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? PipeBuyerColors.darkMuted : PipeBuyerColors.muted;
    final entry = hit.modelEntry;

    final title = entry != null
        ? '${hit.manufacturer.name} ${entry.model} (${entry.yearRangeLabel})'
        : hit.presetManualModel != null
            ? '${hit.manufacturer.name} ${hit.presetManualModel}'
            : hit.manufacturer.name;
    final subtitle = entry != null
        ? entry.series
        : 'Manual Model # & Model Year entry required';
    final badge = entry != null
        ? (hit.queryYear != null
            ? '${hit.queryYear} (${entry.yearRangeLabel})'
            : entry.yearRangeLabel)
        : 'Manual entry';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: <Widget>[
            Icon(
              entry != null
                  ? Icons.precision_manufacturing_outlined
                  : Icons.edit_note_rounded,
              size: 18,
              color: PipeBuyerColors.orange,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: PipeBuyerColors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: PipeBuyerColors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SerialDecodeStatusBanner extends StatelessWidget {
  const _SerialDecodeStatusBanner({
    super.key,
    required this.result,
  });

  final SerialDecodeResult result;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent;
    final IconData icon;
    switch (result.confidence) {
      case SerialDecodeConfidence.high:
        accent = PipeBuyerColors.success;
        icon = Icons.verified_rounded;
        break;
      case SerialDecodeConfidence.medium:
      case SerialDecodeConfidence.partial:
        accent = PipeBuyerColors.industrialBlue;
        icon = Icons.info_outline_rounded;
        break;
      case SerialDecodeConfidence.none:
        accent = PipeBuyerColors.warning;
        icon = Icons.help_outline_rounded;
        break;
    }

    final chips = <String>[
      if (result.manufacturer != null) 'Make: ${result.manufacturer}',
      if (result.modelYear != null) 'Year: ${result.modelYear}',
      if (result.effectiveModel != null) 'Model: ${result.effectiveModel}',
      if (result.engineSummary != null && result.engineSummary!.isNotEmpty)
        'Engine matched',
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 17, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.userMessage,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : PipeBuyerColors.ink,
                  ),
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: chips
                  .map(
                    (label) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? PipeBuyerColors.darkSurface
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManualEntryManufacturerBanner extends StatelessWidget {
  const _ManualEntryManufacturerBanner({
    super.key,
    required this.brandName,
    required this.reason,
    required this.exampleModels,
    required this.onExampleModelSelected,
  });

  final String brandName;
  final String? reason;
  final List<String> exampleModels;
  final ValueChanged<String> onExampleModelSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final description = (reason != null && reason!.trim().isNotEmpty)
        ? reason!.trim()
        : 'Verified year-by-year production tables are not available for $brandName — please enter the exact Model Year and Model # manually from the unit data plate or title.';

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: PipeBuyerColors.orange.withValues(alpha: isDark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: PipeBuyerColors.orange.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.edit_note_rounded,
                size: 18,
                color: PipeBuyerColors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : PipeBuyerColors.ink,
                  ),
                ),
              ),
            ],
          ),
          if (exampleModels.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  'Common models:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? PipeBuyerColors.darkMuted
                        : PipeBuyerColors.muted,
                  ),
                ),
                for (final example in exampleModels.take(6))
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(
                      example,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () => onExampleModelSelected(example),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
