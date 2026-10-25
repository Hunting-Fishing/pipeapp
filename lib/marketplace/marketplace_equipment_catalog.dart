import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bundled 50+ year equipment & commercial vehicle catalog asset path.
const String kEquipmentCatalogAssetPath =
    'assets/data/equipment_catalog_50yr.json';

/// Sentinel option allowing sellers to manually specify an unlisted brand/model.
const String kManualCatalogOptionValue = 'Other / not listed';

/// Marketplace categories that surface the structured equipment catalog.
const Set<String> kStructuredEquipmentCategories = <String>{
  'Heavy Equipment',
  'Transport & Hauling',
  'Site Support',
  'Oil & Gas Equipment',
  'Oilfield & Drilling',
};

/// Marketplace categories where equipment year and model are required specs.
const Set<String> kRequiredEquipmentSpecCategories = <String>{
  'Heavy Equipment',
  'Transport & Hauling',
};

/// Returns `true` when [category] uses the structured equipment catalog.
bool categoryUsesStructuredEquipmentCatalog(String? category) {
  final normalized = category?.trim();
  if (normalized == null || normalized.isEmpty) return false;
  if (kStructuredEquipmentCategories.contains(normalized)) return true;
  final lower = normalized.toLowerCase();
  return kStructuredEquipmentCategories.any((c) => c.toLowerCase() == lower);
}

/// Returns `true` when [category] requires structured model year and model.
bool categoryRequiresEquipmentYearAndModel(String? category) {
  final normalized = category?.trim();
  if (normalized == null || normalized.isEmpty) return false;
  if (kRequiredEquipmentSpecCategories.contains(normalized)) return true;
  final lower = normalized.toLowerCase();
  return kRequiredEquipmentSpecCategories.any((c) => c.toLowerCase() == lower);
}

/// Verified OEM engine and powertrain specification option for a model range.
@immutable
class EquipmentEngineOption {
  const EquipmentEngineOption({
    required this.label,
    required this.manufacturer,
    required this.engineModel,
    this.displacementL,
    this.powerHp,
    required this.fuelType,
    this.transmission,
    required this.yearFrom,
    required this.yearTo,
  });

  final String label;
  final String manufacturer;
  final String engineModel;
  final double? displacementL;
  final int? powerHp;
  final String fuelType;
  final String? transmission;
  final int yearFrom;
  final int yearTo;

  /// Returns `true` when [year] is `null` or falls within `[yearFrom, yearTo]`.
  bool supportsYear(int? year) =>
      year == null || (year >= yearFrom && year <= yearTo);

  /// Human-readable model year window (`"2020"` or `"2006–2012"`).
  String get yearRangeLabel =>
      yearFrom == yearTo ? '$yearFrom' : '$yearFrom–$yearTo';

  /// Concise technical summary suitable for option subtitles.
  String get specsSubtitle {
    final parts = <String>[
      if (manufacturer.trim().isNotEmpty || engineModel.trim().isNotEmpty)
        [manufacturer.trim(), engineModel.trim()]
            .where((part) => part.isNotEmpty)
            .join(' '),
      if (displacementL != null && displacementL! > 0)
        '${_formatDisplacement(displacementL!)}L',
      if (powerHp != null && powerHp! > 0) '$powerHp HP',
      if (fuelType.trim().isNotEmpty) fuelType.trim(),
      if (transmission != null && transmission!.trim().isNotEmpty)
        transmission!.trim(),
    ];
    return parts.join(' • ');
  }

  factory EquipmentEngineOption.fromJson(Map<String, dynamic> json) {
    final manufacturer = '${json['manufacturer'] ?? ''}'.trim();
    final engineModel = '${json['engineModel'] ?? ''}'.trim();
    final displacementL = _parseNullableDouble(json['displacementL']);
    final powerHp = _parseNullableInt(json['powerHp']);
    final fuelType = '${json['fuelType'] ?? 'Diesel'}'.trim();
    final rawTransmission = '${json['transmission'] ?? ''}'.trim();
    final transmission = rawTransmission.isEmpty ? null : rawTransmission;
    final parsedFrom = _parseNullableInt(json['yearFrom']) ?? 1970;
    final parsedTo = _parseNullableInt(json['yearTo']) ?? 2026;
    final yearFrom = parsedFrom <= parsedTo ? parsedFrom : parsedTo;
    final yearTo = parsedTo >= parsedFrom ? parsedTo : parsedFrom;

    var label = '${json['label'] ?? ''}'.trim();
    if (label.isEmpty) {
      final segments = <String>[
        if (manufacturer.isNotEmpty || engineModel.isNotEmpty)
          [manufacturer, engineModel].where((s) => s.isNotEmpty).join(' '),
        [
          if (displacementL != null && displacementL > 0)
            '${_formatDisplacement(displacementL)}L',
          if (fuelType.isNotEmpty) fuelType,
        ].join(' ').trim(),
        if (powerHp != null && powerHp > 0) '$powerHp HP',
        if (transmission != null) transmission,
      ].where((s) => s.isNotEmpty).toList(growable: false);
      label =
          segments.isEmpty ? 'Standard OEM Powertrain' : segments.join(' • ');
    }

    return EquipmentEngineOption(
      label: label,
      manufacturer: manufacturer,
      engineModel: engineModel,
      displacementL: displacementL,
      powerHp: powerHp,
      fuelType: fuelType.isEmpty ? 'Diesel' : fuelType,
      transmission: transmission,
      yearFrom: yearFrom,
      yearTo: yearTo,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'manufacturer': manufacturer,
        'engineModel': engineModel,
        'displacementL': displacementL,
        'powerHp': powerHp,
        'fuelType': fuelType,
        'transmission': transmission,
        'yearFrom': yearFrom,
        'yearTo': yearTo,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentEngineOption &&
          other.label == label &&
          other.manufacturer == manufacturer &&
          other.engineModel == engineModel &&
          other.displacementL == displacementL &&
          other.powerHp == powerHp &&
          other.fuelType == fuelType &&
          other.transmission == transmission &&
          other.yearFrom == yearFrom &&
          other.yearTo == yearTo;

  @override
  int get hashCode => Object.hash(
        label,
        manufacturer,
        engineModel,
        displacementL,
        powerHp,
        fuelType,
        transmission,
        yearFrom,
        yearTo,
      );
}

/// Verified OEM model generation entry with production year range and engines.
@immutable
class EquipmentModelEntry {
  const EquipmentModelEntry({
    required this.model,
    this.series = '',
    this.category = 'Heavy Equipment',
    this.productTypes = const <String>[],
    required this.yearFrom,
    required this.yearTo,
    this.aliases = const <String>[],
    this.source = '',
    this.engines = const <EquipmentEngineOption>[],
  });

  final String model;
  final String series;
  final String category;
  final List<String> productTypes;
  final int yearFrom;
  final int yearTo;
  final List<String> aliases;
  final String source;
  final List<EquipmentEngineOption> engines;

  /// Returns `true` when [year] is `null` or falls within `[yearFrom, yearTo]`.
  bool supportsYear(int? year) =>
      year == null || (year >= yearFrom && year <= yearTo);

  /// Human-readable model year window (`"2020"` or `"2006–2012"`).
  String get yearRangeLabel =>
      yearFrom == yearTo ? '$yearFrom' : '$yearFrom–$yearTo';

  /// Returns engine options supporting [year], falling back to [engines] if
  /// [year] is non-null and no engine sub-range explicitly matched.
  List<EquipmentEngineOption> enginesForYear(int? year) {
    if (year == null || engines.isEmpty) return engines;
    final matching =
        engines.where((e) => e.supportsYear(year)).toList(growable: false);
    return matching.isNotEmpty ? matching : engines;
  }

  /// Checks whether this model matches [productType] using exact and smart
  /// industrial equipment synonym groups.
  bool matchesProductType(String? productType) {
    final trimmed = productType?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed == kManualCatalogOptionValue) {
      return true;
    }
    if (productTypes.isEmpty) return false;

    final queryNorm = _normalizePhrase(trimmed);
    if (queryNorm.isEmpty) return true;

    final queryTags = _industrialProductTypeTags(queryNorm);
    for (final candidate in productTypes) {
      final candidateNorm = _normalizePhrase(candidate);
      if (candidateNorm.isEmpty) continue;
      if (candidateNorm == queryNorm) return true;
      final candidateTags = _industrialProductTypeTags(candidateNorm);
      if (queryTags.isNotEmpty &&
          candidateTags.isNotEmpty &&
          queryTags.any(candidateTags.contains)) {
        return true;
      }
    }
    return false;
  }

  factory EquipmentModelEntry.fromJson(Map<String, dynamic> json) {
    final parsedFrom = _parseNullableInt(json['yearFrom']) ?? 1970;
    final parsedTo = _parseNullableInt(json['yearTo']) ?? 2026;
    final yearFrom = parsedFrom <= parsedTo ? parsedFrom : parsedTo;
    final yearTo = parsedTo >= parsedFrom ? parsedTo : parsedFrom;

    final rawEngines = json['engines'];
    final engines = rawEngines is Iterable
        ? rawEngines
            .whereType<Map>()
            .map((e) =>
                EquipmentEngineOption.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <EquipmentEngineOption>[];

    return EquipmentModelEntry(
      model: '${json['model'] ?? ''}'.trim(),
      series: '${json['series'] ?? ''}'.trim(),
      category: '${json['category'] ?? 'Heavy Equipment'}'.trim(),
      productTypes: _parseStringList(json['productTypes']),
      yearFrom: yearFrom,
      yearTo: yearTo,
      aliases: _parseStringList(json['aliases']),
      source: '${json['source'] ?? ''}'.trim(),
      engines: engines,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'model': model,
        'series': series,
        'category': category,
        'productTypes': productTypes,
        'yearFrom': yearFrom,
        'yearTo': yearTo,
        'aliases': aliases,
        'source': source,
        'engines': engines.map((e) => e.toJson()).toList(growable: false),
      };
}

/// Equipment or commercial vehicle manufacturer entry in [EquipmentCatalog].
@immutable
class EquipmentManufacturerEntry {
  const EquipmentManufacturerEntry({
    required this.id,
    required this.name,
    this.aliases = const <String>[],
    this.categories = const <String>[],
    this.manualEntryOnly = false,
    this.manualEntryReason,
    this.wmiPrefixes = const <String>[],
    this.exampleModels = const <String>[],
    this.models = const <EquipmentModelEntry>[],
  });

  final String id;
  final String name;
  final List<String> aliases;
  final List<String> categories;
  final bool manualEntryOnly;
  final String? manualEntryReason;
  final List<String> wmiPrefixes;
  final List<String> exampleModels;
  final List<EquipmentModelEntry> models;

  /// `true` when this brand has verified year-bounded model entries.
  bool get hasVerifiedYearModelCatalog => !manualEntryOnly && models.isNotEmpty;

  /// Earliest model year across [models], or `null` if [models] is empty.
  int? get minModelYear {
    if (models.isEmpty) return null;
    var minYear = models.first.yearFrom;
    for (var i = 1; i < models.length; i++) {
      if (models[i].yearFrom < minYear) minYear = models[i].yearFrom;
    }
    return minYear;
  }

  /// Latest model year across [models], or `null` if [models] is empty.
  int? get maxModelYear {
    if (models.isEmpty) return null;
    var maxYear = models.first.yearTo;
    for (var i = 1; i < models.length; i++) {
      if (models[i].yearTo > maxYear) maxYear = models[i].yearTo;
    }
    return maxYear;
  }

  EquipmentManufacturerEntry copyWith({
    String? id,
    String? name,
    List<String>? aliases,
    List<String>? categories,
    bool? manualEntryOnly,
    String? manualEntryReason,
    List<String>? wmiPrefixes,
    List<String>? exampleModels,
    List<EquipmentModelEntry>? models,
  }) =>
      EquipmentManufacturerEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        aliases: aliases ?? this.aliases,
        categories: categories ?? this.categories,
        manualEntryOnly: manualEntryOnly ?? this.manualEntryOnly,
        manualEntryReason: manualEntryReason ?? this.manualEntryReason,
        wmiPrefixes: wmiPrefixes ?? this.wmiPrefixes,
        exampleModels: exampleModels ?? this.exampleModels,
        models: models ?? this.models,
      );

  factory EquipmentManufacturerEntry.fromJson(Map<String, dynamic> json) {
    final name = '${json['name'] ?? ''}'.trim();
    final rawId = '${json['id'] ?? ''}'.trim();
    final id = rawId.isNotEmpty ? rawId : _slugifyIdentifier(name);
    final rawReason = json['manualEntryReason'];
    final reasonText = rawReason == null ? '' : '$rawReason'.trim();
    final rawModels = json['models'];
    final models = rawModels is Iterable
        ? rawModels
            .whereType<Map>()
            .map((m) =>
                EquipmentModelEntry.fromJson(Map<String, dynamic>.from(m)))
            .where((m) => m.model.isNotEmpty)
            .toList(growable: false)
        : const <EquipmentModelEntry>[];

    return EquipmentManufacturerEntry(
      id: id,
      name: name,
      aliases: _parseStringList(json['aliases']),
      categories: _parseStringList(json['categories']),
      manualEntryOnly: json['manualEntryOnly'] == true,
      manualEntryReason: reasonText.isEmpty ? null : reasonText,
      wmiPrefixes: _parseStringList(json['wmiPrefixes']),
      exampleModels: _parseStringList(json['exampleModels']),
      models: models,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'aliases': aliases,
        'categories': categories,
        'manualEntryOnly': manualEntryOnly,
        'manualEntryReason': manualEntryReason,
        'wmiPrefixes': wmiPrefixes,
        'exampleModels': exampleModels,
        'models': models.map((m) => m.toJson()).toList(growable: false),
      };
}

/// Bidirectional 50+ year equipment catalog with O(1) brand lookup and
/// strict year/model/engine filtering.
class EquipmentCatalog {
  EquipmentCatalog({
    this.schemaVersion = 2,
    this.yearFloor = 1970,
    this.yearCeiling = 2026,
    required List<EquipmentManufacturerEntry> manufacturers,
    this.generatedAt,
    this.licensing,
  }) : manufacturers = List<EquipmentManufacturerEntry>.unmodifiable(
          manufacturers,
        ) {
    final sorted = List<EquipmentManufacturerEntry>.of(this.manufacturers)
      ..sort((a, b) => _compareNaturalCaseInsensitive(a.name, b.name));
    _sortedManufacturers =
        List<EquipmentManufacturerEntry>.unmodifiable(sorted);

    for (final entry in _sortedManufacturers) {
      _registerLookupKey(entry.id, entry);
      _registerLookupKey(entry.name, entry);
      for (final alias in entry.aliases) {
        _registerLookupKey(alias, entry);
      }
    }
  }

  final int schemaVersion;
  final int yearFloor;
  final int yearCeiling;
  final List<EquipmentManufacturerEntry> manufacturers;
  final String? generatedAt;
  final Map<String, dynamic>? licensing;

  late final List<EquipmentManufacturerEntry> _sortedManufacturers;
  final Map<String, EquipmentManufacturerEntry> _lookupByExactLower =
      <String, EquipmentManufacturerEntry>{};
  final Map<String, EquipmentManufacturerEntry> _lookupByCompact =
      <String, EquipmentManufacturerEntry>{};

  static EquipmentCatalog? _cachedCatalog;
  static Future<EquipmentCatalog>? _inFlightAssetLoad;

  /// Currently cached singleton catalog instance, if already loaded.
  static EquipmentCatalog? get cachedInstance => _cachedCatalog;

  /// Clears the in-memory singleton cache for isolated unit/widget testing.
  static void clearCacheForTesting() {
    _cachedCatalog = null;
    _inFlightAssetLoad = null;
  }

  /// Loads and parses [kEquipmentCatalogAssetPath] with in-memory singleton
  /// caching and optional [bundle] or [jsonLoader] injection for tests.
  static Future<EquipmentCatalog> loadFromAsset({
    AssetBundle? bundle,
    bool useCache = true,
    Future<String> Function(String assetPath)? jsonLoader,
    String assetPath = kEquipmentCatalogAssetPath,
  }) async {
    final canShareInFlight = useCache &&
        bundle == null &&
        jsonLoader == null &&
        assetPath == kEquipmentCatalogAssetPath;

    if (useCache && _cachedCatalog != null) {
      return _cachedCatalog!;
    }
    if (canShareInFlight && _inFlightAssetLoad != null) {
      return _inFlightAssetLoad!;
    }

    Future<EquipmentCatalog> performLoad() async {
      final rawJson = jsonLoader != null
          ? await jsonLoader(assetPath)
          : await (bundle ?? rootBundle).loadString(assetPath);
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        throw const FormatException(
          'Equipment catalog JSON root must be an object.',
        );
      }
      final catalog = EquipmentCatalog.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (useCache) {
        _cachedCatalog = catalog;
      }
      return catalog;
    }

    if (canShareInFlight) {
      final future = performLoad();
      _inFlightAssetLoad = future;
      try {
        return await future;
      } finally {
        if (identical(_inFlightAssetLoad, future)) {
          _inFlightAssetLoad = null;
        }
      }
    }

    return performLoad();
  }

  factory EquipmentCatalog.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _parseNullableInt(json['schemaVersion']) ?? 2;
    final parsedFloor = _parseNullableInt(json['yearFloor']) ?? 1970;
    final parsedCeiling = _parseNullableInt(json['yearCeiling']) ?? 2026;
    final yearFloor =
        parsedFloor <= parsedCeiling ? parsedFloor : parsedCeiling;
    final yearCeiling =
        parsedCeiling >= parsedFloor ? parsedCeiling : parsedFloor;

    final rawManufacturers = json['manufacturers'];
    final manufacturers = rawManufacturers is Iterable
        ? rawManufacturers
            .whereType<Map>()
            .map((m) => EquipmentManufacturerEntry.fromJson(
                  Map<String, dynamic>.from(m),
                ))
            .where((m) => m.name.isNotEmpty)
            .toList(growable: false)
        : const <EquipmentManufacturerEntry>[];

    final rawLicensing = json['licensing'];
    return EquipmentCatalog(
      schemaVersion: schemaVersion,
      yearFloor: yearFloor,
      yearCeiling: yearCeiling,
      manufacturers: manufacturers,
      generatedAt: json['generatedAt']?.toString(),
      licensing:
          rawLicensing is Map ? Map<String, dynamic>.from(rawLicensing) : null,
    );
  }

  /// Graceful fallback constructor built from a legacy `brand -> models` map
  /// before the full 50-year catalog asset finishes loading.
  factory EquipmentCatalog.fromLegacyBrandMap(
    Map<String, List<String>> brandModels, {
    int yearFloor = 1970,
    int yearCeiling = 2026,
  }) {
    final entries = <EquipmentManufacturerEntry>[];
    for (final mapEntry in brandModels.entries) {
      final brandName = mapEntry.key.trim();
      if (brandName.isEmpty || brandName == kManualCatalogOptionValue) {
        continue;
      }
      final cleanModels = mapEntry.value
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty && m != kManualCatalogOptionValue)
          .toSet()
          .toList(growable: false);

      entries.add(
        EquipmentManufacturerEntry(
          id: _slugifyIdentifier(brandName),
          name: brandName,
          categories: kStructuredEquipmentCategories.toList(growable: false),
          manualEntryOnly: cleanModels.isEmpty,
          manualEntryReason:
              cleanModels.isEmpty ? 'Enter model and year manually.' : null,
          exampleModels: cleanModels,
          models: cleanModels
              .map(
                (modelName) => EquipmentModelEntry(
                  model: modelName,
                  yearFrom: yearFloor,
                  yearTo: yearCeiling,
                  source: 'legacy_brand_map',
                ),
              )
              .toList(growable: false),
        ),
      );
    }
    return EquipmentCatalog(
      schemaVersion: 1,
      yearFloor: yearFloor,
      yearCeiling: yearCeiling,
      manufacturers: entries,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        if (generatedAt != null) 'generatedAt': generatedAt,
        'yearFloor': yearFloor,
        'yearCeiling': yearCeiling,
        if (licensing != null) 'licensing': licensing,
        'manufacturers':
            manufacturers.map((m) => m.toJson()).toList(growable: false),
      };

  /// All manufacturers in the catalog sorted alphabetically by name.
  List<EquipmentManufacturerEntry> get allManufacturers => _sortedManufacturers;

  /// Merges [overrides] into this catalog, replacing matching manufacturers
  /// (by ID, name, or alias) and appending new ones.
  EquipmentCatalog mergeManufacturerOverrides(
    Iterable<EquipmentManufacturerEntry> overrides,
  ) {
    final list = List<EquipmentManufacturerEntry>.of(manufacturers);
    for (final override in overrides) {
      if (override.name.trim().isEmpty) continue;
      final existing =
          findManufacturer(override.id) ?? findManufacturer(override.name);
      if (existing == null) {
        list.add(override);
      } else {
        final idx = list.indexWhere((m) => identical(m, existing));
        if (idx >= 0) {
          list[idx] = override;
        }
      }
    }
    return EquipmentCatalog(
      schemaVersion: schemaVersion,
      yearFloor: yearFloor,
      yearCeiling: yearCeiling,
      manufacturers: list,
      generatedAt: generatedAt,
      licensing: licensing,
    );
  }

  /// Merges legacy/Firestore brand maps so no brand from Firestore is ever lost.
  ///
  /// Any brand in [extraBrands] not already present in [manufacturers] is added
  /// with `manualEntryOnly: true` and `exampleModels`.
  EquipmentCatalog mergeLegacyBrandModels(
    Map<String, List<String>> extraBrands,
  ) {
    if (extraBrands.isEmpty) return this;
    final list = List<EquipmentManufacturerEntry>.of(manufacturers);
    var changed = false;

    for (final entry in extraBrands.entries) {
      final brandName = entry.key.trim();
      if (brandName.isEmpty || brandName == kManualCatalogOptionValue) {
        continue;
      }
      final examples = entry.value
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty && m != kManualCatalogOptionValue)
          .toSet()
          .toList(growable: false);

      final existing = findManufacturer(brandName);
      if (existing == null) {
        list.add(
          EquipmentManufacturerEntry(
            id: _slugifyIdentifier(brandName),
            name: brandName,
            categories: kStructuredEquipmentCategories.toList(growable: false),
            manualEntryOnly: true,
            manualEntryReason:
                'Unverified or custom manufacturer — enter exact model and year manually.',
            exampleModels: examples,
            models: const <EquipmentModelEntry>[],
          ),
        );
        changed = true;
      } else if (existing.manualEntryOnly && examples.isNotEmpty) {
        final mergedExamples = <String>{
          ...existing.exampleModels,
          ...examples,
        }.toList(growable: false);
        if (mergedExamples.length != existing.exampleModels.length) {
          final idx = list.indexWhere((m) => identical(m, existing));
          if (idx >= 0) {
            list[idx] = existing.copyWith(exampleModels: mergedExamples);
            changed = true;
          }
        }
      }
    }

    if (!changed) return this;
    return EquipmentCatalog(
      schemaVersion: schemaVersion,
      yearFloor: yearFloor,
      yearCeiling: yearCeiling,
      manufacturers: list,
      generatedAt: generatedAt,
      licensing: licensing,
    );
  }

  /// Case-insensitive lookup matching manufacturer `name`, `id`, or `aliases`.
  EquipmentManufacturerEntry? findManufacturer(String? nameOrAlias) {
    final trimmed = nameOrAlias?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed == kManualCatalogOptionValue) {
      return null;
    }
    final exactLower = trimmed.toLowerCase();
    final direct = _lookupByExactLower[exactLower];
    if (direct != null) return direct;

    final compact = _compactAlphanumeric(trimmed);
    if (compact.isEmpty) return null;
    final byCompact = _lookupByCompact[compact];
    if (byCompact != null) return byCompact;

    // Built-in industrial brand synonym fallback if not explicitly in aliases.
    final canonicalFallback = _builtinBrandAliases[compact];
    if (canonicalFallback != null) {
      return _lookupByExactLower[canonicalFallback.toLowerCase()] ??
          _lookupByCompact[_compactAlphanumeric(canonicalFallback)];
    }
    return null;
  }

  /// Returns `true` when [brand] is non-null/non-empty and requires manual
  /// model and year entry (`'Other / not listed'` or lacks a verified catalog).
  bool requiresManualModelAndYear(String? brand) {
    final trimmed = brand?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;
    if (trimmed == kManualCatalogOptionValue) return true;
    return findManufacturer(trimmed)?.hasVerifiedYearModelCatalog != true;
  }

  /// Returns manufacturers matching [category] sorted alphabetically.
  ///
  /// When [includeAllBrands] is `true`, manufacturers matching [category] are
  /// returned first (alphabetically), followed by all remaining manufacturers
  /// (alphabetically). If [category] is `null`, empty, or matches no entries,
  /// returns [allManufacturers].
  List<EquipmentManufacturerEntry> manufacturersFor({
    String? category,
    bool includeAllBrands = false,
  }) {
    final trimmedCategory = category?.trim();
    if (trimmedCategory == null || trimmedCategory.isEmpty) {
      return _sortedManufacturers;
    }

    bool matchesCategory(EquipmentManufacturerEntry entry, String target) {
      final lowerTarget = target.toLowerCase();
      if (entry.categories.any((c) => c.toLowerCase() == lowerTarget)) {
        return true;
      }
      if (entry.models.any((m) => m.category.toLowerCase() == lowerTarget)) {
        return true;
      }
      // Oilfield & Drilling and Oil & Gas Equipment share upstream OEM brands.
      if (lowerTarget == 'oilfield & drilling' &&
          entry.categories
              .any((c) => c.toLowerCase() == 'oil & gas equipment')) {
        return true;
      }
      return false;
    }

    final primary = _sortedManufacturers
        .where((m) => matchesCategory(m, trimmedCategory))
        .toList(growable: false);

    if (primary.isEmpty) return _sortedManufacturers;
    if (!includeAllBrands) return primary;

    final primarySet = primary.toSet();
    final secondary = _sortedManufacturers
        .where((m) => !primarySet.contains(m))
        .toList(growable: false);
    return <EquipmentManufacturerEntry>[...primary, ...secondary];
  }

  /// Returns valid descending model years (`2026..1970`) for `(brand, model)`.
  ///
  /// - Verified manufacturer + matched catalog [model]: strictly returns that
  ///   model's valid production years `[entry.yearTo..entry.yearFrom]`.
  /// - Verified manufacturer + `model == null` (or `'Other / not listed'`):
  ///   returns years in `yearCeiling..yearFloor` supported by at least one
  ///   model of that manufacturer.
  /// - Unverified/manual brand or `brand == null`: returns full
  ///   `yearCeiling..yearFloor`.
  List<int> yearsFor({required String? brand, String? model}) {
    final mfr = findManufacturer(brand);
    if (mfr != null && mfr.hasVerifiedYearModelCatalog) {
      final trimmedModel = model?.trim();
      if (trimmedModel != null &&
          trimmedModel.isNotEmpty &&
          trimmedModel != kManualCatalogOptionValue) {
        final matchedEntries = _findAllMatchingModelEntries(mfr, trimmedModel);
        if (matchedEntries.isNotEmpty) {
          if (matchedEntries.length == 1) {
            final entry = matchedEntries.first;
            return <int>[
              for (int y = entry.yearTo; y >= entry.yearFrom; y--) y,
            ];
          }
          var minFrom = matchedEntries.first.yearFrom;
          var maxTo = matchedEntries.first.yearTo;
          for (final entry in matchedEntries.skip(1)) {
            if (entry.yearFrom < minFrom) minFrom = entry.yearFrom;
            if (entry.yearTo > maxTo) maxTo = entry.yearTo;
          }
          return <int>[
            for (int y = maxTo; y >= minFrom; y--)
              if (matchedEntries.any((e) => y >= e.yearFrom && y <= e.yearTo))
                y,
          ];
        }
      }

      final supportedManufacturerYears = <int>[
        for (int y = yearCeiling; y >= yearFloor; y--)
          if (mfr.models.any((m) => y >= m.yearFrom && y <= m.yearTo)) y,
      ];
      if (supportedManufacturerYears.isNotEmpty) {
        return supportedManufacturerYears;
      }
    }

    return <int>[for (int y = yearCeiling; y >= yearFloor; y--) y];
  }

  /// Returns verified catalog models for [brand], strictly filtered by
  /// [modelYear] (`m.supportsYear(modelYear)`).
  ///
  /// When [productType] is non-empty:
  /// - If [strictProductType] is `true`, returns only models matching
  ///   [productType].
  /// - If [strictProductType] is `false`, sorts models matching [productType]
  ///   first while keeping remaining models for that year accessible.
  List<EquipmentModelEntry> modelsFor({
    required String? brand,
    int? modelYear,
    String? productType,
    bool strictProductType = false,
  }) {
    final trimmedBrand = brand?.trim();
    if (trimmedBrand == null ||
        trimmedBrand.isEmpty ||
        trimmedBrand == kManualCatalogOptionValue) {
      return const <EquipmentModelEntry>[];
    }
    final mfr = findManufacturer(trimmedBrand);
    if (mfr == null || !mfr.hasVerifiedYearModelCatalog) {
      return const <EquipmentModelEntry>[];
    }

    final yearValid = mfr.models
        .where((m) => m.supportsYear(modelYear))
        .toList(growable: false);
    if (yearValid.isEmpty) return const <EquipmentModelEntry>[];

    final trimmedType = productType?.trim();
    final hasTypeFilter = trimmedType != null &&
        trimmedType.isNotEmpty &&
        trimmedType != kManualCatalogOptionValue;

    if (!hasTypeFilter) {
      final sorted = List<EquipmentModelEntry>.of(yearValid)
        ..sort(_compareModelEntries);
      return List<EquipmentModelEntry>.unmodifiable(sorted);
    }

    final matching = <EquipmentModelEntry>[];
    final others = <EquipmentModelEntry>[];
    for (final entry in yearValid) {
      if (entry.matchesProductType(trimmedType)) {
        matching.add(entry);
      } else if (!strictProductType) {
        others.add(entry);
      }
    }
    matching.sort(_compareModelEntries);
    if (strictProductType) {
      return List<EquipmentModelEntry>.unmodifiable(matching);
    }
    others.sort(_compareModelEntries);
    return List<EquipmentModelEntry>.unmodifiable(<EquipmentModelEntry>[
      ...matching,
      ...others,
    ]);
  }

  /// Counts verified models for [brand] and [modelYear] matching [productType].
  int countModelsMatchingProductType({
    required String? brand,
    int? modelYear,
    required String? productType,
  }) =>
      modelsFor(
        brand: brand,
        modelYear: modelYear,
        productType: productType,
        strictProductType: true,
      ).length;

  /// Resolves a catalog [EquipmentModelEntry] for [brand] and
  /// [rawModelOrAlias], preferring entries supporting [modelYear].
  ///
  /// Performs exact `model` match first, then exact `aliases` match, then
  /// normalized alphanumeric/leading-zero-stripped and OEM PIN VDS alias match
  /// (e.g., `"0320D"` -> `"320D"`, `"00352"` -> `"352"`,
  /// `"C0752"` -> `"SVL75-2"`, `"T880"` -> `"T880"`).
  EquipmentModelEntry? findModel(
    String? brand,
    String? rawModelOrAlias, {
    int? modelYear,
  }) {
    final trimmedModel = rawModelOrAlias?.trim();
    if (trimmedModel == null ||
        trimmedModel.isEmpty ||
        trimmedModel == kManualCatalogOptionValue) {
      return null;
    }
    final mfr = findManufacturer(brand);
    if (mfr == null || mfr.models.isEmpty) return null;

    // 1. Exact case-insensitive match on primary model name.
    final lowerTarget = trimmedModel.toLowerCase();
    final exactModelMatches = mfr.models
        .where((m) => m.model.toLowerCase() == lowerTarget)
        .toList(growable: false);
    if (exactModelMatches.isNotEmpty) {
      return _pickBestModelForYear(exactModelMatches, modelYear);
    }

    // 2. Exact case-insensitive match on aliases.
    final exactAliasMatches = mfr.models
        .where((m) => m.aliases.any((a) => a.toLowerCase() == lowerTarget))
        .toList(growable: false);
    if (exactAliasMatches.isNotEmpty) {
      return _pickBestModelForYear(exactAliasMatches, modelYear);
    }

    // 3. Normalized alphanumeric & leading-zero stripped match (incl. PIN codes).
    final candidateKeys = _normalizedModelCandidateKeys(trimmedModel);
    if (candidateKeys.isEmpty) return null;

    final normalizedPrimaryMatches = <EquipmentModelEntry>[];
    final normalizedAliasMatches = <EquipmentModelEntry>[];

    for (final entry in mfr.models) {
      final entryKeys = _normalizedModelEntryPrimaryKeys(entry.model);
      if (entryKeys.any(candidateKeys.contains)) {
        normalizedPrimaryMatches.add(entry);
        continue;
      }
      var matchedAlias = false;
      for (final alias in entry.aliases) {
        if (_normalizedModelEntryPrimaryKeys(alias)
            .any(candidateKeys.contains)) {
          matchedAlias = true;
          break;
        }
      }
      if (matchedAlias) {
        normalizedAliasMatches.add(entry);
      }
    }

    if (normalizedPrimaryMatches.isNotEmpty) {
      return _pickBestModelForYear(normalizedPrimaryMatches, modelYear);
    }
    if (normalizedAliasMatches.isNotEmpty) {
      return _pickBestModelForYear(normalizedAliasMatches, modelYear);
    }

    // 4. Unambiguous prefix fallback for 5-char PIN VDS truncations
    // (e.g., CAT "0259D" -> "259D" -> "259D3", JCB "540" -> "540-170") when
    // exactly one model (or one model for modelYear) shares that prefix.
    final strippedTarget = _compactAlphanumeric(trimmedModel)
        .replaceFirst(RegExp(r'^0+(?=[a-z0-9])'), '');
    if (strippedTarget.length >= 3) {
      final prefixMatches = mfr.models.where((entry) {
        final key = _compactAlphanumeric(entry.model)
            .replaceFirst(RegExp(r'^0+(?=[a-z0-9])'), '');
        return key.startsWith(strippedTarget);
      }).toList(growable: false);
      if (prefixMatches.length == 1) {
        return prefixMatches.first;
      }
      if (modelYear != null && prefixMatches.length > 1) {
        final yearScoped = prefixMatches
            .where((entry) => entry.supportsYear(modelYear))
            .toList(growable: false);
        if (yearScoped.length == 1) {
          return yearScoped.first;
        }
      }
    }

    return null;
  }

  /// Returns deduplicated [EquipmentEngineOption]s valid for
  /// `(brand, model, modelYear)`.
  List<EquipmentEngineOption> engineOptionsFor({
    required String? brand,
    required String? model,
    int? modelYear,
  }) {
    final trimmedModel = model?.trim();
    if (trimmedModel == null ||
        trimmedModel.isEmpty ||
        trimmedModel == kManualCatalogOptionValue) {
      return const <EquipmentEngineOption>[];
    }
    final mfr = findManufacturer(brand);
    if (mfr == null || mfr.models.isEmpty) {
      return const <EquipmentEngineOption>[];
    }

    final matchedEntries = _findAllMatchingModelEntries(mfr, trimmedModel);
    if (matchedEntries.isEmpty) return const <EquipmentEngineOption>[];

    final yearScopedEntries = modelYear == null
        ? matchedEntries
        : matchedEntries
            .where((e) => e.supportsYear(modelYear))
            .toList(growable: false);
    final effectiveEntries =
        yearScopedEntries.isNotEmpty ? yearScopedEntries : matchedEntries;

    final seenLabels = <String>{};
    final result = <EquipmentEngineOption>[];
    for (final entry in effectiveEntries) {
      for (final engine in entry.enginesForYear(modelYear)) {
        final dedupeKey = engine.label.trim().toLowerCase();
        if (dedupeKey.isNotEmpty && seenLabels.add(dedupeKey)) {
          result.add(engine);
        }
      }
    }
    return List<EquipmentEngineOption>.unmodifiable(result);
  }

  void _registerLookupKey(String rawKey, EquipmentManufacturerEntry entry) {
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) return;
    _lookupByExactLower.putIfAbsent(trimmed.toLowerCase(), () => entry);
    final compact = _compactAlphanumeric(trimmed);
    if (compact.isNotEmpty) {
      _lookupByCompact.putIfAbsent(compact, () => entry);
    }
  }

  List<EquipmentModelEntry> _findAllMatchingModelEntries(
    EquipmentManufacturerEntry mfr,
    String rawModelOrAlias,
  ) {
    final lower = rawModelOrAlias.trim().toLowerCase();
    final exact = mfr.models
        .where((m) => m.model.toLowerCase() == lower)
        .toList(growable: false);
    if (exact.isNotEmpty) return exact;

    final single = findModel(mfr.name, rawModelOrAlias);
    if (single == null) return const <EquipmentModelEntry>[];
    final singleLower = single.model.toLowerCase();
    return mfr.models
        .where((m) => m.model.toLowerCase() == singleLower)
        .toList(growable: false);
  }

  static EquipmentModelEntry _pickBestModelForYear(
    List<EquipmentModelEntry> candidates,
    int? modelYear,
  ) {
    if (candidates.length == 1) return candidates.first;
    if (modelYear != null) {
      for (final entry in candidates) {
        if (entry.supportsYear(modelYear)) return entry;
      }
    }
    final sorted = List<EquipmentModelEntry>.of(candidates)
      ..sort((a, b) => b.yearTo.compareTo(a.yearTo));
    return sorted.first;
  }

  static int _compareModelEntries(
    EquipmentModelEntry a,
    EquipmentModelEntry b,
  ) {
    final byName = _compareNaturalCaseInsensitive(a.model, b.model);
    if (byName != 0) return byName;
    return b.yearTo.compareTo(a.yearTo);
  }
}

const Map<String, String> _builtinBrandAliases = <String, String>{
  'cat': 'Caterpillar',
  'caterpillarinc': 'Caterpillar',
  'deere': 'John Deere',
  'johndeereconstruction': 'John Deere',
  'casece': 'Case',
  'caseconstruction': 'Case',
  'caseih': 'Case',
  'newhollandconstruction': 'New Holland',
  'doosan': 'Develon',
  'develondoosan': 'Develon',
  'volvoconstruction': 'Volvo CE',
  'volvoce': 'Volvo CE',
  'volvotruck': 'Volvo Trucks',
  'navistar': 'International',
  'internationalharvester': 'International',
  'charlesmachineworks': 'Ditch Witch',
  'thecharlesmachineworks': 'Ditch Witch',
  'genie': 'Genie / JLG',
  'jlg': 'Genie / JLG',
  'grove': 'Grove / Manitowoc',
  'manitowoc': 'Grove / Manitowoc',
  'nov': 'National Oilwell Varco',
  'cameron': 'Cameron / SLB',
  'schlumberger': 'Cameron / SLB',
  'spm': 'SPM / Weir',
  'weir': 'SPM / Weir',
};

/// Known compact/heavy PIN VDS codes mapped to normalized catalog model keys.
const Map<String, String> _oemPinCodeToCatalogCompact = <String, String>{
  'k0334': 'kx0334',
  'k0404': 'kx0404',
  'k0574': 'kx0574',
  'k0804': 'kx0804',
  'u0173': 'u173',
  'u0354': 'u354',
  'u0554': 'u554',
  'c0652': 'svl652',
  'c0752': 'svl752',
  'c0753': 'svl753',
  'c0902': 'svl902',
  'c0952': 'svl952',
  'c0972': 'svl972',
  'c220e': 'ec220e',
  'c300e': 'ec300e',
  'c350e': 'ec350e',
  'c380e': 'ec380e',
};

Set<String> _normalizedModelEntryPrimaryKeys(String value) {
  final compact = _compactAlphanumeric(value);
  if (compact.isEmpty) return const <String>{};
  final strippedZeros = compact.replaceFirst(RegExp(r'^0+(?=[a-z0-9])'), '');
  return <String>{
    compact,
    if (strippedZeros.isNotEmpty) strippedZeros,
  };
}

Set<String> _normalizedModelCandidateKeys(String raw) {
  final compact = _compactAlphanumeric(raw);
  if (compact.isEmpty) return const <String>{};
  final strippedZeros = compact.replaceFirst(RegExp(r'^0+(?=[a-z0-9])'), '');
  final keys = <String>{
    compact,
    if (strippedZeros.isNotEmpty) strippedZeros,
  };
  final mappedPin = _oemPinCodeToCatalogCompact[compact] ??
      _oemPinCodeToCatalogCompact[strippedZeros];
  if (mappedPin != null) {
    keys.add(mappedPin);
  }
  return keys;
}

Set<String> _industrialProductTypeTags(String normalizedPhrase) {
  final tags = <String>{};

  // Excavators
  if (normalizedPhrase.contains('excavator') ||
      normalizedPhrase == 'trackhoe' ||
      normalizedPhrase == 'diggers') {
    tags.add('excavator');
  }

  // Dozers / Bulldozers
  if (normalizedPhrase.contains('dozer') ||
      normalizedPhrase.contains('bulldozer') ||
      normalizedPhrase.contains('pipelayer')) {
    tags.add('bulldozer');
  }

  // Backhoes (checked before generic loader so "backhoe loader" maps cleanly)
  final isBackhoe = normalizedPhrase.contains('backhoe') ||
      normalizedPhrase == 'tlb' ||
      normalizedPhrase == 'tractor loader backhoe';
  if (isBackhoe) {
    tags.add('backhoe');
  }

  // Skid Steers & Compact Track Loaders
  final isCompactTrackOrMultiTerrain =
      normalizedPhrase.contains('compact track loader') ||
          normalizedPhrase == 'track loader' ||
          normalizedPhrase == 'crawler loader' ||
          normalizedPhrase.contains('multi terrain loader') ||
          normalizedPhrase == 'ctl' ||
          normalizedPhrase == 'mtl';
  final isSkidSteer = normalizedPhrase.contains('skid steer') ||
      normalizedPhrase.contains('skidsteer') ||
      normalizedPhrase == 'ssl';

  if (isCompactTrackOrMultiTerrain) {
    tags.addAll(const <String>['loader', 'skid_steer', 'compact_track_loader']);
  } else if (isSkidSteer) {
    tags.add('skid_steer');
  } else if (!isBackhoe && normalizedPhrase.contains('loader')) {
    tags.add('loader');
  }

  // Graders
  if (normalizedPhrase.contains('grader')) {
    tags.add('grader');
  }

  // Cranes
  if (normalizedPhrase.contains('crane') || normalizedPhrase == 'boom truck') {
    tags.add('crane');
  }

  // Telehandlers
  if (normalizedPhrase.contains('telehandler') ||
      normalizedPhrase.contains('telescopic handler') ||
      normalizedPhrase.contains('reach forklift')) {
    tags.add('telehandler');
  }

  // Compactors / Rollers
  if (normalizedPhrase.contains('compactor') ||
      normalizedPhrase.contains('roller')) {
    tags.add('compactor');
  }

  // Forklifts
  if (normalizedPhrase.contains('forklift') &&
      !normalizedPhrase.contains('reach forklift')) {
    tags.add('forklift');
  }

  // Drilling Rigs / Trenchers / HDD
  if (normalizedPhrase.contains('drill') ||
      normalizedPhrase.contains('trencher') ||
      normalizedPhrase == 'hdd' ||
      normalizedPhrase.contains('workover rig') ||
      normalizedPhrase.contains('service rig')) {
    tags.add('drilling_rig');
  }

  // Highway & Vocational Trucks
  if (normalizedPhrase.contains('semi truck') ||
      normalizedPhrase.contains('truck tractor') ||
      normalizedPhrase.contains('highway tractor') ||
      normalizedPhrase.contains('day cab') ||
      normalizedPhrase.contains('sleeper') ||
      normalizedPhrase.contains('vocational truck') ||
      normalizedPhrase.contains('heavy truck') ||
      normalizedPhrase.contains('cab chassis')) {
    tags.addAll(const <String>['semi_truck', 'heavy_truck_chassis']);
  }
  if (normalizedPhrase.contains('winch truck')) {
    tags.addAll(const <String>['winch_truck', 'heavy_truck_chassis']);
  }
  if (normalizedPhrase.contains('vacuum truck')) {
    tags.addAll(const <String>['vacuum_truck', 'heavy_truck_chassis']);
  }
  if (normalizedPhrase.contains('water truck')) {
    tags.addAll(const <String>['water_truck', 'heavy_truck_chassis']);
  }
  if (normalizedPhrase.contains('roll off') ||
      normalizedPhrase.contains('dump truck')) {
    tags.addAll(const <String>['roll_off_truck', 'heavy_truck_chassis']);
  }

  // Trailers
  if (normalizedPhrase.contains('lowboy') ||
      normalizedPhrase == 'rgn' ||
      normalizedPhrase.contains('removable gooseneck') ||
      normalizedPhrase.contains('equipment trailer')) {
    tags.add('lowboy_trailer');
  }
  if (normalizedPhrase.contains('flatbed') ||
      normalizedPhrase.contains('platform trailer')) {
    tags.add('flatbed_trailer');
  }
  if (normalizedPhrase.contains('step deck') ||
      normalizedPhrase.contains('drop deck') ||
      normalizedPhrase.contains('single drop')) {
    tags.add('step_drop_deck');
  }

  // Site Support & Oilfield Equipment
  if (normalizedPhrase.contains('compressor')) {
    tags.add('compressor');
  }
  if (normalizedPhrase.contains('weld')) {
    tags.add('welder');
  }
  if (normalizedPhrase.contains('generator') ||
      normalizedPhrase.contains('genset')) {
    tags.add('generator');
  }
  if (normalizedPhrase.contains('light tower')) {
    tags.add('light_tower');
  }
  if (normalizedPhrase.contains('scissor lift')) {
    tags.add('scissor_lift');
  }
  if (normalizedPhrase.contains('boom lift') ||
      normalizedPhrase.contains('aerial lift') ||
      normalizedPhrase.contains('manlift')) {
    tags.add('boom_lift');
  }
  if (normalizedPhrase.contains('pump')) {
    tags.add('pump');
  }
  if (normalizedPhrase == 'bop' ||
      normalizedPhrase.contains('blowout preventer')) {
    tags.add('bop');
  }
  if (normalizedPhrase.contains('wellhead')) {
    tags.add('wellhead');
  }

  if (tags.isEmpty) {
    tags.add(normalizedPhrase);
  }
  return tags;
}

String _normalizePhrase(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

String _compactAlphanumeric(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _slugifyIdentifier(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

String _formatDisplacement(double liters) {
  final fixed = liters.toStringAsFixed(1);
  if ((double.parse(fixed) - liters).abs() < 0.005) {
    return fixed;
  }
  return liters.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

int? _parseNullableInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw'.trim());
}

double? _parseNullableDouble(Object? raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw'.trim());
}

List<String> _parseStringList(Object? raw) {
  if (raw is! Iterable) return const <String>[];
  return raw
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

final RegExp _naturalTokenPattern = RegExp(r'(\d+|\D+)');

int _compareNaturalCaseInsensitive(String a, String b) {
  final aLower = a.toLowerCase();
  final bLower = b.toLowerCase();
  if (aLower == bLower) return a.compareTo(b);

  final aTokens = _naturalTokenPattern
      .allMatches(aLower)
      .map((m) => m.group(0)!)
      .toList(growable: false);
  final bTokens = _naturalTokenPattern
      .allMatches(bLower)
      .map((m) => m.group(0)!)
      .toList(growable: false);

  final len = aTokens.length < bTokens.length ? aTokens.length : bTokens.length;
  for (var i = 0; i < len; i++) {
    final ta = aTokens[i];
    final tb = bTokens[i];
    if (ta == tb) continue;
    final na = int.tryParse(ta);
    final nb = int.tryParse(tb);
    if (na != null && nb != null && na != nb) {
      return na.compareTo(nb);
    }
    return ta.compareTo(tb);
  }
  return aTokens.length.compareTo(bTokens.length);
}
