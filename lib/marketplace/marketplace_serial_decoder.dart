import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'marketplace_equipment_catalog.dart';

/// Confidence level of a decoded highway VIN, off-highway PIN, or legacy serial.
enum SerialDecodeConfidence { high, medium, partial, none }

/// Source tier that produced a [SerialDecodeResult].
enum SerialDecodeSource {
  nhtsaVpic,
  isoEquipmentPin,
  legacyEquipmentSerial,
  invalidCheckDigit,
  unrecognized,
}

/// Structured result of decoding a vehicle VIN, heavy-equipment PIN, or serial.
@immutable
class SerialDecodeResult {
  const SerialDecodeResult({
    required this.rawInput,
    required this.normalizedInput,
    this.manufacturer,
    this.rawModelCode,
    this.matchedCatalogModel,
    this.modelYear,
    this.ambiguousCandidateYears = const <int>[],
    this.engineSummary,
    this.productTypeHint,
    required this.confidence,
    required this.source,
    required this.userMessage,
  });

  final String rawInput;
  final String normalizedInput;
  final String? manufacturer;
  final String? rawModelCode;
  final String? matchedCatalogModel;
  final int? modelYear;
  final List<int> ambiguousCandidateYears;
  final String? engineSummary;
  final String? productTypeHint;
  final SerialDecodeConfidence confidence;
  final SerialDecodeSource source;
  final String userMessage;

  /// Best resolved model identifier (`matchedCatalogModel` preferred over raw).
  String? get effectiveModel => matchedCatalogModel ?? rawModelCode;

  /// `true` when at least one listing specification field was decoded.
  bool get hasAnyDecodedField =>
      manufacturer != null ||
      effectiveModel != null ||
      modelYear != null ||
      (engineSummary != null && engineSummary!.isNotEmpty);

  SerialDecodeResult copyWith({
    String? rawInput,
    String? normalizedInput,
    String? manufacturer,
    String? rawModelCode,
    String? matchedCatalogModel,
    int? modelYear,
    List<int>? ambiguousCandidateYears,
    String? engineSummary,
    String? productTypeHint,
    SerialDecodeConfidence? confidence,
    SerialDecodeSource? source,
    String? userMessage,
  }) =>
      SerialDecodeResult(
        rawInput: rawInput ?? this.rawInput,
        normalizedInput: normalizedInput ?? this.normalizedInput,
        manufacturer: manufacturer ?? this.manufacturer,
        rawModelCode: rawModelCode ?? this.rawModelCode,
        matchedCatalogModel: matchedCatalogModel ?? this.matchedCatalogModel,
        modelYear: modelYear ?? this.modelYear,
        ambiguousCandidateYears:
            ambiguousCandidateYears ?? this.ambiguousCandidateYears,
        engineSummary: engineSummary ?? this.engineSummary,
        productTypeHint: productTypeHint ?? this.productTypeHint,
        confidence: confidence ?? this.confidence,
        source: source ?? this.source,
        userMessage: userMessage ?? this.userMessage,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rawInput': rawInput,
        'normalizedInput': normalizedInput,
        'manufacturer': manufacturer,
        'rawModelCode': rawModelCode,
        'matchedCatalogModel': matchedCatalogModel,
        'modelYear': modelYear,
        'ambiguousCandidateYears': ambiguousCandidateYears,
        'engineSummary': engineSummary,
        'productTypeHint': productTypeHint,
        'confidence': confidence.name,
        'source': source.name,
        'userMessage': userMessage,
      };
}

/// Free hybrid highway VIN (NHTSA vPIC) + off-highway heavy-equipment PIN &
/// legacy serial decoder with WMI collision protection and LRU caching.
class MarketplaceSerialDecoder {
  MarketplaceSerialDecoder({
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 5),
    this.maxCacheEntries = 128,
    this.maxAllowedModelYear = 2026,
  })  : _injectedClient = httpClient,
        _ownsClient = httpClient == null;

  final http.Client? _injectedClient;
  final bool _ownsClient;
  http.Client? _lazyOwnedClient;

  final Duration requestTimeout;
  final int maxCacheEntries;
  final int maxAllowedModelYear;

  final LinkedHashMap<String, Map<String, dynamic>> _vpicCache =
      LinkedHashMap<String, Map<String, dynamic>>();

  http.Client get _client =>
      _injectedClient ?? (_lazyOwnedClient ??= http.Client());

  /// Releases the internal HTTP client if one was lazily created.
  void dispose() {
    if (_ownsClient) {
      _lazyOwnedClient?.close();
      _lazyOwnedClient = null;
    }
  }

  /// Clears cached NHTSA vPIC responses (useful for tests).
  void clearCache() => _vpicCache.clear();

  /// Uppercases [input] and strips spaces, hyphens, dots, and non-alphanumerics.
  static String normalizeSerial(String input) =>
      input.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Validates the ISO 3779 / FMVSS 115 Mod-11 check digit at Position 9.
  static bool hasValidNorthAmericanVinCheckDigit(String vin) {
    if (vin.length != 17) return false;
    if (vin.contains('I') || vin.contains('O') || vin.contains('Q')) {
      return false;
    }
    var sum = 0;
    for (var i = 0; i < 17; i++) {
      final weight = _vinPositionWeights[i];
      final value = _vinCharTransliteration[vin[i]];
      if (value == null) return false;
      sum += value * weight;
    }
    final remainder = sum % 11;
    final expected = remainder == 10 ? 'X' : '$remainder';
    return vin[8] == expected;
  }

  /// Decodes a 17-character highway VIN, 17-character ISO 10261 heavy-equipment
  /// PIN, or supported 9/13-character OEM equipment serial number.
  Future<SerialDecodeResult> decode(
    String input, {
    String? categoryContext,
    EquipmentCatalog? catalog,
    String? currentBrand,
  }) async {
    final normalized = normalizeSerial(input);
    if (normalized.length < 5) {
      return SerialDecodeResult(
        rawInput: input,
        normalizedInput: normalized,
        confidence: SerialDecodeConfidence.none,
        source: SerialDecodeSource.unrecognized,
        userMessage:
            'Enter a 17-character VIN/PIN or manufacturer serial number to decode.',
      );
    }

    // Tier 1: 17-character inputs pass through Off-Highway & Collision Guard
    // BEFORE any network call to NHTSA vPIC.
    if (normalized.length == 17) {
      final wmi = normalized.substring(0, 3);
      final routeDirectlyToOffHighway = _shouldRoute17CharDirectlyToTier2(
        normalized,
        wmi: wmi,
        categoryContext: categoryContext,
      );

      if (routeDirectlyToOffHighway) {
        final tier2 = _decodeTier2Offline(
          rawInput: input,
          normalized: normalized,
          categoryContext: categoryContext,
          catalog: catalog,
          currentBrand: currentBrand,
        );
        if (tier2 != null) return tier2;
      } else if (!_containsDisallowedIsoVinLetters(normalized)) {
        final vpicResult = await _decodeTier1BNhtsaVpic(
          rawInput: input,
          normalized: normalized,
          wmi: wmi,
          catalog: catalog,
        );
        if (vpicResult != null) return vpicResult;
      }
    }

    // Tier 2: Deterministic offline Heavy Equipment PIN & Legacy Serial parser.
    final tier2Result = _decodeTier2Offline(
      rawInput: input,
      normalized: normalized,
      categoryContext: categoryContext,
      catalog: catalog,
      currentBrand: currentBrand,
    );
    if (tier2Result != null) return tier2Result;

    // Surface a dedicated check-digit typo warning if a 17-character highway-style
    // VIN failed Mod-11 verification and did not match any off-highway PIN rule.
    if (normalized.length == 17 &&
        !_containsDisallowedIsoVinLetters(normalized) &&
        !hasValidNorthAmericanVinCheckDigit(normalized)) {
      return SerialDecodeResult(
        rawInput: input,
        normalizedInput: normalized,
        confidence: SerialDecodeConfidence.none,
        source: SerialDecodeSource.invalidCheckDigit,
        userMessage:
            'Position 9 check digit did not validate and no heavy-equipment PIN matched. Verify the 17 characters for typos or select Manufacturer, Year, and Model below.',
      );
    }

    return SerialDecodeResult(
      rawInput: input,
      normalizedInput: normalized,
      confidence: SerialDecodeConfidence.none,
      source: SerialDecodeSource.unrecognized,
      userMessage:
          'Serial number recorded. Automatic decoding could not uniquely identify this format — please select Manufacturer, Model Year, and Model.',
    );
  }

  /// Tier 1A: Pure Off-Highway WMI check + NHTSA WMI Collision Guard.
  bool _shouldRoute17CharDirectlyToTier2(
    String pin, {
    required String wmi,
    required String? categoryContext,
  }) {
    if (_pureOffHighwayWmis.contains(wmi) || _isCnhNSeriesWmi(wmi)) {
      return true;
    }

    // Critical Collision Guard for:
    // - 1DW (John Deere Davenport vs Stoughton Trailers)
    // - 1T0 (John Deere Dubuque vs Trail-Rite)
    // - 1RW (John Deere Waterloo vs Rockwood)
    // - KMT (Komatsu vs Genesis passenger cars)
    if (wmi == 'KMT' || _collidingDeereWmis.contains(wmi)) {
      final trimmedCategory = categoryContext?.trim();
      if (trimmedCategory != null &&
          trimmedCategory.isNotEmpty &&
          trimmedCategory.toLowerCase() != 'transport & hauling') {
        return true;
      }

      if (wmi == 'KMT') {
        final chars4To5 = pin.substring(3, 5);
        if (_komatsuEquipmentPrefixes.contains(chars4To5) ||
            RegExp(r'^D\d$').hasMatch(chars4To5)) {
          return true;
        }
      }

      if (_collidingDeereWmis.contains(wmi)) {
        final chars4To7 = pin.substring(3, 7);
        final chars4To8 = pin.substring(3, 8);
        if (_looksLikeDeereEquipmentVds(chars4To7, chars4To8) ||
            !hasValidNorthAmericanVinCheckDigit(pin)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Tier 1B: Live NHTSA vPIC Extended Decode with 5s timeout and LRU cache.
  Future<SerialDecodeResult?> _decodeTier1BNhtsaVpic({
    required String rawInput,
    required String normalized,
    required String wmi,
    required EquipmentCatalog? catalog,
  }) async {
    Map<String, dynamic>? row = _readCache(normalized);
    if (row == null) {
      final uri = Uri.parse(
        'https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValuesExtended/$normalized?format=json',
      );
      try {
        final response = await _client.get(
          uri,
          headers: const <String, String>{'Accept': 'application/json'},
        ).timeout(requestTimeout);
        if (response.statusCode != 200) {
          return null;
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) return null;
        final results = decoded['Results'];
        if (results is! List || results.isEmpty || results.first is! Map) {
          return null;
        }
        row = Map<String, dynamic>.from(results.first as Map);
        _writeCache(normalized, row);
      } catch (_) {
        // Network offline, DNS failure, or 5s timeout -> fall through to Tier 2.
        return null;
      }
    }

    final makeRaw = _cleanVpicValue(row['Make']);
    final errorCodeStr = _cleanVpicValue(row['ErrorCode']);
    final errorCodes = errorCodeStr
        .split(RegExp(r'[,;\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();

    // Safety check: Genesis collision on KMT, unregistered WMI ('7'), or blank Make.
    if (makeRaw.isEmpty ||
        errorCodes.contains('7') ||
        (wmi == 'KMT' && makeRaw.toUpperCase() == 'GENESIS')) {
      return null;
    }

    final vehicleType = _cleanVpicValue(row['VehicleType']);
    final bodyClass = _cleanVpicValue(row['BodyClass']);
    final trailerType = _cleanVpicValue(row['TrailerBodyType']);
    final rawModelFromVpic = _cleanVpicValue(row['Model']);
    final seriesFromVpic = _cleanVpicValue(row['Series']);
    final effectiveRawModel = rawModelFromVpic.isNotEmpty
        ? rawModelFromVpic
        : (seriesFromVpic.isNotEmpty ? seriesFromVpic : null);

    var canonicalMake = _normalizeNhtsaMake(
      makeRaw,
      vehicleType: vehicleType,
      bodyClass: bodyClass,
      rawModel: effectiveRawModel,
    );
    if (catalog != null) {
      final catalogMfr = catalog.findManufacturer(canonicalMake);
      if (catalogMfr != null) {
        canonicalMake = catalogMfr.name;
      }
    }

    final parsedYear = int.tryParse(_cleanVpicValue(row['ModelYear']));
    final validYear = parsedYear != null &&
            parsedYear >= 1970 &&
            parsedYear <= maxAllowedModelYear
        ? parsedYear
        : null;

    EquipmentModelEntry? matchedEntry;
    if (catalog != null && effectiveRawModel != null) {
      matchedEntry = catalog.findModel(
        canonicalMake,
        effectiveRawModel,
        modelYear: validYear,
      );
    }

    var engineSummary = _buildNhtsaEngineSummary(row);
    if (engineSummary == null && matchedEntry != null) {
      final engines = matchedEntry.enginesForYear(validYear);
      final uniqueLabels = engines.map((e) => e.label).toSet();
      if (uniqueLabels.length == 1) {
        engineSummary = engines.first.label;
      }
    }

    final productTypeHint = _inferNhtsaProductTypeHint(
          vehicleType: vehicleType,
          bodyClass: bodyClass,
          trailerBodyType: trailerType,
        ) ??
        (matchedEntry != null && matchedEntry.productTypes.isNotEmpty
            ? matchedEntry.productTypes.first
            : null);

    final checkDigitFailed = !hasValidNorthAmericanVinCheckDigit(normalized) ||
        errorCodes.contains('1');

    final resolvedModel = matchedEntry?.model ?? effectiveRawModel;
    final identityParts = <String>[
      if (validYear != null) '$validYear',
      canonicalMake,
      if (resolvedModel != null && resolvedModel.isNotEmpty) resolvedModel,
    ];
    final identityLabel = identityParts.join(' ');

    if (checkDigitFailed) {
      return SerialDecodeResult(
        rawInput: rawInput,
        normalizedInput: normalized,
        manufacturer: canonicalMake,
        rawModelCode: effectiveRawModel,
        matchedCatalogModel: matchedEntry?.model,
        modelYear: validYear,
        engineSummary: engineSummary,
        productTypeHint: productTypeHint,
        confidence: SerialDecodeConfidence.partial,
        source: SerialDecodeSource.invalidCheckDigit,
        userMessage:
            'VIN check digit at position 9 did not validate (possible character typo). Tentatively matched $identityLabel via NHTSA vPIC — verify all specs before publishing.',
      );
    }

    final missingNotes = <String>[
      if (validYear == null) 'select Model Year',
      if (resolvedModel == null) 'select Model',
    ];
    final confidence = validYear != null && resolvedModel != null
        ? SerialDecodeConfidence.high
        : SerialDecodeConfidence.medium;
    final message = missingNotes.isEmpty
        ? 'Decoded $identityLabel from 17-character VIN via NHTSA vPIC.'
        : 'Decoded $identityLabel from 17-character VIN — please ${missingNotes.join(' and ')}.';

    return SerialDecodeResult(
      rawInput: rawInput,
      normalizedInput: normalized,
      manufacturer: canonicalMake,
      rawModelCode: effectiveRawModel,
      matchedCatalogModel: matchedEntry?.model,
      modelYear: validYear,
      engineSummary: engineSummary,
      productTypeHint: productTypeHint,
      confidence: confidence,
      source: SerialDecodeSource.nhtsaVpic,
      userMessage: message,
    );
  }

  /// Tier 2: 100% offline deterministic Heavy Equipment PIN & Legacy Serial parser.
  SerialDecodeResult? _decodeTier2Offline({
    required String rawInput,
    required String normalized,
    required String? categoryContext,
    required EquipmentCatalog? catalog,
    required String? currentBrand,
  }) {
    if (normalized.length == 17) {
      final wmi = normalized.substring(0, 3);

      // 1. Caterpillar 17-char (CAT / CPW)
      if (wmi == 'CAT' || wmi == 'CPW') {
        return _decodeCaterpillar17(rawInput, normalized, catalog);
      }

      // 2. John Deere 17-char (1DW, 1T0, 1FF, 1LV, 1PY, 1RW)
      if (_allDeere17Wmis.contains(wmi)) {
        return _decodeJohnDeere17(rawInput, normalized, catalog);
      }

      // 3. JCB 17-char (SLP) — Year at Position 8!
      if (wmi == 'SLP') {
        return _decodeJcb17(rawInput, normalized, catalog);
      }

      // 4. Komatsu 17-char (KMT)
      if (wmi == 'KMT') {
        return _decodeKomatsu17(rawInput, normalized, catalog);
      }

      // 5. Volvo CE 17-char (VCE, VCG)
      if (wmi == 'VCE' || wmi == 'VCG') {
        return _decodeVolvoCe17(rawInput, normalized, catalog);
      }

      // 6. Kubota 17-char (JKU vs KBC / KBU / KBG / KBT)
      if (wmi == 'JKU' || _kubotaIsoYearWmis.contains(wmi)) {
        return _decodeKubota17(rawInput, normalized,
            wmi: wmi, catalog: catalog);
      }

      // 7. Case / New Holland 17-char (JJG, JEE, FNH, ZEF, ZFH, NAA..NZ9)
      if (_cnh17Wmis.contains(wmi) || _isCnhNSeriesWmi(wmi)) {
        return _decodeCnh17(
          rawInput,
          normalized,
          wmi: wmi,
          catalog: catalog,
          currentBrand: currentBrand,
        );
      }

      // 8. Bobcat 17-char
      if (_bobcat17Wmis.contains(wmi)) {
        return _decodeBobcat(
          rawInput,
          normalized,
          catalog: catalog,
          is17CharPin: true,
        );
      }

      // 9. Develon / Doosan, Ditch Witch, Vermeer, Hitachi, Liebherr, Sany, Terex/Takeuchi
      if (wmi == 'DHK' || wmi == 'DWK') {
        return _decodeGenericIsoPin17(
          rawInput: rawInput,
          normalized: normalized,
          canonicalBrand: 'Develon',
          decodePos10Year: true,
          catalog: catalog,
        );
      }
      if (wmi == 'CMW' || wmi == 'DWP' || wmi == '1DS') {
        return _decodeGenericIsoPin17(
          rawInput: rawInput,
          normalized: normalized,
          canonicalBrand: 'Ditch Witch',
          decodePos10Year: true,
          defaultProductTypeHint: 'Drilling Rig',
          catalog: catalog,
        );
      }
      if (wmi == '1VR') {
        return _decodeGenericIsoPin17(
          rawInput: rawInput,
          normalized: normalized,
          canonicalBrand: 'Vermeer',
          decodePos10Year: true,
          defaultProductTypeHint: 'Drilling Rig',
          catalog: catalog,
        );
      }
      if (wmi == 'HCM' || wmi == 'JKM') {
        return _decodeHitachi17(rawInput, normalized, catalog);
      }
      if (wmi == 'WLH') {
        return _decodeGenericIsoPin17(
          rawInput: rawInput,
          normalized: normalized,
          canonicalBrand: 'Liebherr',
          decodePos10Year: false,
          noYearReason:
              'Liebherr PINs encode manufacturing plant codes at positions 10–11 rather than model year',
          catalog: catalog,
        );
      }
      if (wmi == 'SNY') {
        return _decodeGenericIsoPin17(
          rawInput: rawInput,
          normalized: normalized,
          canonicalBrand: 'Sany',
          decodePos10Year: false,
          noYearReason: 'Sany PINs do not reliably encode calendar model year',
          catalog: catalog,
        );
      }
      if (wmi == 'TWG') {
        final chars4To5 = normalized.substring(3, 5);
        final brand = (chars4To5 == 'TB' || chars4To5 == 'TL')
            ? 'Takeuchi'
            : 'Genie / JLG';
        return _decodeGenericIsoPin17(
          rawInput: rawInput,
          normalized: normalized,
          canonicalBrand: brand,
          decodePos10Year: normalized[9] != '0',
          catalog: catalog,
        );
      }
      if (wmi == 'KHR') {
        final preferred = currentBrand != null &&
                currentBrand.trim().toLowerCase().contains('link')
            ? 'Link-Belt'
            : 'Case';
        return _decodeGenericIsoPin17(
          rawInput: rawInput,
          normalized: normalized,
          canonicalBrand: preferred,
          decodePos10Year: false,
          defaultProductTypeHint: 'Excavator',
          noYearReason:
              'Sumitomo/CNH excavator PINs use position 10 for factory/sequence rather than model year',
          catalog: catalog,
        );
      }
    }

    // Legacy 13-char John Deere serial (T0, DW, FF, LV, RW, PY + 5 VDS + 6 seq)
    if (normalized.length == 13 &&
        RegExp(r'^(?:T0|DW|FF|LV|RW|PY)[A-Z0-9]{5}\d{6}$')
            .hasMatch(normalized)) {
      return _decodeJohnDeereLegacy13(rawInput, normalized, catalog);
    }

    // 9-char CNH Wichita SSL/CTL serial (^N[0-9A-HJ-NPR-Y]M\d{6}$)
    final wichitaMatch =
        RegExp(r'^N([0-9A-HJ-NPR-Y])M\d{6}$').firstMatch(normalized);
    if (wichitaMatch != null) {
      return _decodeCnhWichita9(
        rawInput,
        normalized,
        yearChar: wichitaMatch.group(1)!,
        catalog: catalog,
        currentBrand: currentBrand,
      );
    }

    // 9-char Bobcat module serial (A3L, A3N, B3Y, B4S, B4U, AJC, ALJ, A00, B3K, 51xx–53xx)
    if (normalized.length == 9 && _isBobcat9CharSerial(normalized)) {
      return _decodeBobcat(
        rawInput,
        normalized,
        catalog: catalog,
        is17CharPin: false,
      );
    }

    // Takeuchi prefixed serial hints (e.g., TWG... non-17)
    if (normalized.startsWith('TWG') &&
        normalized.length >= 11 &&
        RegExp(r'^TWG[25]\d+$').hasMatch(normalized)) {
      final brand = _resolveBrandName('Takeuchi', catalog);
      return SerialDecodeResult(
        rawInput: rawInput,
        normalizedInput: normalized,
        manufacturer: brand,
        confidence: SerialDecodeConfidence.partial,
        source: SerialDecodeSource.legacyEquipmentSerial,
        userMessage:
            'Identified $brand serial prefix. Select Model Year and Model below.',
      );
    }

    return null;
  }

  SerialDecodeResult _decodeCaterpillar17(
    String rawInput,
    String pin,
    EquipmentCatalog? catalog,
  ) {
    final brand = _resolveBrandName('Caterpillar', catalog);
    final vds = pin.substring(3, 8);
    final cleanedModel = _stripLeadingZerosAndFiller(vds);
    final rawModelCode = cleanedModel.isEmpty ? null : cleanedModel;

    final matchedEntry =
        rawModelCode == null ? null : catalog?.findModel(brand, rawModelCode);

    int? singleYear;
    if (matchedEntry != null && matchedEntry.yearFrom == matchedEntry.yearTo) {
      singleYear = matchedEntry.yearFrom;
    }

    String? engineSummary;
    if (matchedEntry != null) {
      final engines = matchedEntry.enginesForYear(singleYear);
      final uniqueLabels = engines.map((e) => e.label).toSet();
      if (uniqueLabels.length == 1) {
        engineSummary = engines.first.label;
      }
    }

    final productTypeHint =
        (matchedEntry != null && matchedEntry.productTypes.isNotEmpty)
            ? matchedEntry.productTypes.first
            : _inferCaterpillarProductType(rawModelCode);

    final effectiveModel = matchedEntry?.model ?? rawModelCode;
    final String message;
    if (matchedEntry != null && singleYear == null) {
      message =
          'Identified $brand ${matchedEntry.model} from 17-character PIN. Caterpillar PINs do not encode model year — select Model Year from the valid ${matchedEntry.yearRangeLabel} range.';
    } else if (effectiveModel != null && singleYear != null) {
      message =
          'Identified $singleYear $brand $effectiveModel from 17-character PIN.';
    } else if (effectiveModel != null) {
      message =
          'Identified $brand $effectiveModel from 17-character PIN. Caterpillar PINs do not encode model year — please select Model Year.';
    } else {
      message =
          'Identified $brand 17-character PIN. Caterpillar PINs do not encode model year — please select Model Year and Model.';
    }

    return SerialDecodeResult(
      rawInput: rawInput,
      normalizedInput: pin,
      manufacturer: brand,
      rawModelCode: rawModelCode,
      matchedCatalogModel: matchedEntry?.model,
      modelYear: singleYear,
      engineSummary: engineSummary,
      productTypeHint: productTypeHint,
      confidence: effectiveModel != null
          ? SerialDecodeConfidence.high
          : SerialDecodeConfidence.medium,
      source: SerialDecodeSource.isoEquipmentPin,
      userMessage: message,
    );
  }

  SerialDecodeResult _decodeJohnDeere17(
    String rawInput,
    String pin,
    EquipmentCatalog? catalog,
  ) {
    final brand = _resolveBrandName('John Deere', catalog);
    final vds5 = pin.substring(3, 8);
    final vds4 = pin.substring(3, 7);
    final clean5 = _stripLeadingZerosAndFiller(vds5);
    final clean4 = _stripLeadingZerosAndFiller(vds4);

    EquipmentModelEntry? matchedEntry;
    String? rawModelCode;

    if (catalog != null) {
      matchedEntry =
          catalog.findModel(brand, clean5) ?? catalog.findModel(brand, clean4);
    }

    if (matchedEntry != null) {
      rawModelCode =
          catalog!.findModel(brand, clean5) != null ? clean5 : clean4;
    } else if (RegExp(r'^\d{4}[A-Z]$').hasMatch(vds5) ||
        RegExp(r'^0?\d{2,3}(?:SL|HL|EL|LC|GL|GP|TC)$').hasMatch(vds5)) {
      rawModelCode = clean5;
    } else if (RegExp(r'^\d{3}[A-Z]$').hasMatch(vds4)) {
      rawModelCode = clean4;
    } else {
      rawModelCode = clean5.isNotEmpty ? clean5 : null;
    }

    final modernSeriesHint = rawModelCode != null &&
        RegExp(r'(?:G|K|L|M|P)$').hasMatch(rawModelCode);
    final pos7IsLetter = _isAsciiLetter(pin[6]);
    final pos9IsNonXLetter = _isAsciiLetter(pin[8]) && pin[8] != 'X';

    final yearResolution = _resolveIsoYear(
      pin[9],
      catalogEntry: matchedEntry,
      preferModernPost2010:
          pos7IsLetter || pos9IsNonXLetter || modernSeriesHint,
    );

    if (yearResolution.year != null &&
        catalog != null &&
        rawModelCode != null) {
      matchedEntry = catalog.findModel(
            brand,
            rawModelCode,
            modelYear: yearResolution.year,
          ) ??
          matchedEntry;
    }

    String? engineSummary;
    if (matchedEntry != null) {
      final engines = matchedEntry.enginesForYear(yearResolution.year);
      if (engines.map((e) => e.label).toSet().length == 1) {
        engineSummary = engines.first.label;
      }
    }

    final productTypeHint =
        (matchedEntry != null && matchedEntry.productTypes.isNotEmpty)
            ? matchedEntry.productTypes.first
            : _inferDeereProductType(rawModelCode);

    return _buildEquipmentPinResult(
      rawInput: rawInput,
      normalized: pin,
      brand: brand,
      rawModelCode: rawModelCode,
      matchedEntry: matchedEntry,
      yearResolution: yearResolution,
      engineSummary: engineSummary,
      productTypeHint: productTypeHint,
      source: SerialDecodeSource.isoEquipmentPin,
    );
  }

  SerialDecodeResult _decodeJohnDeereLegacy13(
    String rawInput,
    String serial,
    EquipmentCatalog? catalog,
  ) {
    final brand = _resolveBrandName('John Deere', catalog);
    final vds5 = serial.substring(2, 7);
    final vds4 = serial.substring(2, 6);
    final clean5 = _stripLeadingZerosAndFiller(vds5);
    final clean4 = _stripLeadingZerosAndFiller(vds4);

    final matched5 = catalog?.findModel(brand, clean5);
    final matched4 = catalog?.findModel(brand, clean4);
    final matchedEntry = matched5 ?? matched4;
    final rawModelCode = matched5 != null
        ? clean5
        : (matched4 != null
            ? clean4
            : (RegExp(r'^\d{3}[A-Z]$').hasMatch(vds4) ? clean4 : clean5));

    String? engineSummary;
    if (matchedEntry != null) {
      final engines = matchedEntry.engines;
      if (engines.map((e) => e.label).toSet().length == 1) {
        engineSummary = engines.first.label;
      }
    }

    final effectiveModel =
        matchedEntry?.model ?? (rawModelCode.isEmpty ? null : rawModelCode);
    final rangeNote = matchedEntry != null
        ? 'from the valid ${matchedEntry.yearRangeLabel} range'
        : 'below';

    return SerialDecodeResult(
      rawInput: rawInput,
      normalizedInput: serial,
      manufacturer: brand,
      rawModelCode: rawModelCode.isEmpty ? null : rawModelCode,
      matchedCatalogModel: matchedEntry?.model,
      engineSummary: engineSummary,
      productTypeHint:
          matchedEntry != null && matchedEntry.productTypes.isNotEmpty
              ? matchedEntry.productTypes.first
              : _inferDeereProductType(rawModelCode),
      confidence: effectiveModel != null
          ? SerialDecodeConfidence.medium
          : SerialDecodeConfidence.partial,
      source: SerialDecodeSource.legacyEquipmentSerial,
      userMessage: effectiveModel != null
          ? 'Identified $brand $effectiveModel from 13-character legacy PIN. Legacy 13-character Deere serials do not encode model year — select Model Year $rangeNote.'
          : 'Identified $brand 13-character legacy serial — please select Model Year and Model.',
    );
  }

  SerialDecodeResult _decodeJcb17(
    String rawInput,
    String pin,
    EquipmentCatalog? catalog,
  ) {
    final brand = _resolveBrandName('JCB', catalog);
    final vds4 = _stripLeadingZerosAndFiller(pin.substring(3, 7));
    final vds3 = _stripLeadingZerosAndFiller(pin.substring(3, 6));

    final matched4 = vds4.isEmpty ? null : catalog?.findModel(brand, vds4);
    final matched3 = vds3.isEmpty ? null : catalog?.findModel(brand, vds3);

    String? rawModelCode;
    EquipmentModelEntry? matchedEntry;
    if (matched4 != null) {
      rawModelCode = vds4;
      matchedEntry = matched4;
    } else if (matched3 != null) {
      rawModelCode = vds3;
      matchedEntry = matched3;
    } else if (RegExp(r'^(?:[1-5]CX|\d{3})$').hasMatch(vds3) &&
        _isAsciiLetter(pin[6])) {
      rawModelCode = vds3;
    } else {
      rawModelCode = vds4.isNotEmpty ? vds4 : null;
    }

    // CRITICAL: JCB encodes ISO Model Year at Position 8 (index 7), NOT Pos 10!
    final pos7IsLetter = _isAsciiLetter(pin[6]);
    final yearResolution = _resolveIsoYear(
      pin[7],
      catalogEntry: matchedEntry,
      preferModernPost2010: pos7IsLetter,
    );

    if (yearResolution.year != null &&
        catalog != null &&
        rawModelCode != null) {
      matchedEntry = catalog.findModel(
            brand,
            rawModelCode,
            modelYear: yearResolution.year,
          ) ??
          matchedEntry;
    }

    String? engineSummary;
    if (matchedEntry != null) {
      final engines = matchedEntry.enginesForYear(yearResolution.year);
      if (engines.map((e) => e.label).toSet().length == 1) {
        engineSummary = engines.first.label;
      }
    }

    final productTypeHint =
        (matchedEntry != null && matchedEntry.productTypes.isNotEmpty)
            ? matchedEntry.productTypes.first
            : _inferJcbProductType(rawModelCode);

    return _buildEquipmentPinResult(
      rawInput: rawInput,
      normalized: pin,
      brand: brand,
      rawModelCode: rawModelCode,
      matchedEntry: matchedEntry,
      yearResolution: yearResolution,
      engineSummary: engineSummary,
      productTypeHint: productTypeHint,
      source: SerialDecodeSource.isoEquipmentPin,
      yearPositionNote: 'position 8',
    );
  }

  SerialDecodeResult _decodeKomatsu17(
    String rawInput,
    String pin,
    EquipmentCatalog? catalog,
  ) {
    final brand = _resolveBrandName('Komatsu', catalog);
    final family2 = pin.substring(3, 5);
    final vds5 = pin.substring(3, 8);

    String? productTypeHint;
    if (family2 == 'PC' ||
        family2 == 'HB' ||
        family2 == 'PW' ||
        family2 == 'XT') {
      productTypeHint = 'Excavator';
    } else if (family2 == 'WA' || family2 == 'HM') {
      productTypeHint = 'Loader';
    } else if (family2 == 'GD') {
      productTypeHint = 'Grader';
    } else if (family2 == 'WB') {
      productTypeHint = 'Backhoe';
    } else if (RegExp(r'^D\d$').hasMatch(family2)) {
      productTypeHint = 'Bulldozer';
    }

    String? rawModelCode;
    final pcOrWaMatch =
        RegExp(r'^(?:PC|HB|PW|WA|GD|HM|WB)\d{2,4}').firstMatch(vds5);
    final dozerMatch = RegExp(r'^D0*(\d{2,3}[A-Z]?)').firstMatch(vds5);
    if (pcOrWaMatch != null) {
      rawModelCode = pcOrWaMatch.group(0);
    } else if (dozerMatch != null) {
      rawModelCode = 'D${dozerMatch.group(1)}';
    }

    final matchedEntry =
        rawModelCode == null ? null : catalog?.findModel(brand, rawModelCode);

    if (matchedEntry != null &&
        productTypeHint == null &&
        matchedEntry.productTypes.isNotEmpty) {
      productTypeHint = matchedEntry.productTypes.first;
    }

    String? engineSummary;
    if (matchedEntry != null) {
      final uniqueLabels = matchedEntry.engines.map((e) => e.label).toSet();
      if (uniqueLabels.length == 1) {
        engineSummary = matchedEntry.engines.first.label;
      }
    }

    final effectiveModel = matchedEntry?.model ?? rawModelCode;
    final rangeMsg = matchedEntry != null
        ? 'select Model Year from the valid ${matchedEntry.yearRangeLabel} range'
        : 'select exact Model Year and Model generation';

    return SerialDecodeResult(
      rawInput: rawInput,
      normalizedInput: pin,
      manufacturer: brand,
      rawModelCode: rawModelCode,
      matchedCatalogModel: matchedEntry?.model,
      // Komatsu 17-char PINs NEVER reliably encode calendar year at Pos 10.
      modelYear: null,
      engineSummary: engineSummary,
      productTypeHint: productTypeHint,
      confidence: matchedEntry != null
          ? SerialDecodeConfidence.high
          : SerialDecodeConfidence.medium,
      source: SerialDecodeSource.isoEquipmentPin,
      userMessage: effectiveModel != null
          ? 'Identified $brand $effectiveModel${productTypeHint != null ? ' ($productTypeHint)' : ''} from 17-character PIN. Komatsu PINs do not encode calendar year — $rangeMsg.'
          : 'Identified $brand${productTypeHint != null ? ' $productTypeHint' : ''} from 17-character PIN. Komatsu PINs do not encode calendar year — $rangeMsg.',
    );
  }

  SerialDecodeResult _decodeVolvoCe17(
    String rawInput,
    String pin,
    EquipmentCatalog? catalog,
  ) {
    final brand = _resolveBrandName('Volvo CE', catalog);
    final vds = pin.substring(3, 8);
    String? rawModelCode;

    final ecMatch = RegExp(r'^C(\d{2,3}[A-Z]?)$').firstMatch(vds);
    final ecrMatch = RegExp(r'^R(\d{2,3}[A-Z]?)$').firstMatch(vds);
    if (ecMatch != null) {
      rawModelCode = 'EC${ecMatch.group(1)}';
    } else if (ecrMatch != null) {
      rawModelCode = 'ECR${ecrMatch.group(1)}';
    } else {
      final stripped = _stripLeadingZerosAndFiller(vds);
      if (stripped.isNotEmpty) rawModelCode = stripped;
    }

    final matchedEntry =
        rawModelCode == null ? null : catalog?.findModel(brand, rawModelCode);

    String? productTypeHint;
    if (matchedEntry != null && matchedEntry.productTypes.isNotEmpty) {
      productTypeHint = matchedEntry.productTypes.first;
    } else if (rawModelCode != null) {
      if (rawModelCode.startsWith('EC')) {
        productTypeHint = 'Excavator';
      } else if (rawModelCode.startsWith('L')) {
        productTypeHint = 'Loader';
      }
    }

    String? engineSummary;
    if (matchedEntry != null) {
      final uniqueLabels = matchedEntry.engines.map((e) => e.label).toSet();
      if (uniqueLabels.length == 1) {
        engineSummary = matchedEntry.engines.first.label;
      }
    }

    final effectiveModel = matchedEntry?.model ?? rawModelCode;
    final yearRangeNote = matchedEntry != null
        ? 'select Model Year from the valid ${matchedEntry.yearRangeLabel} range'
        : 'please select Model Year';

    return SerialDecodeResult(
      rawInput: rawInput,
      normalizedInput: pin,
      manufacturer: brand,
      rawModelCode: rawModelCode,
      matchedCatalogModel: matchedEntry?.model,
      modelYear: null,
      engineSummary: engineSummary,
      productTypeHint: productTypeHint,
      confidence: effectiveModel != null
          ? SerialDecodeConfidence.high
          : SerialDecodeConfidence.medium,
      source: SerialDecodeSource.isoEquipmentPin,
      userMessage: effectiveModel != null
          ? 'Identified $brand $effectiveModel from 17-character PIN. Volvo CE PINs use 0 at position 10 rather than model year — $yearRangeNote.'
          : 'Identified $brand 17-character PIN — please select Model Year and Model.',
    );
  }

  SerialDecodeResult _decodeKubota17(
    String rawInput,
    String pin, {
    required String wmi,
    required EquipmentCatalog? catalog,
  }) {
    final brand = _resolveBrandName('Kubota', catalog);
    final vds = pin.substring(3, 8);

    if (wmi == 'JKU') {
      final mappedModel = _kubotaJkuModelCodes[vds];
      final rawModelCode = mappedModel ?? _stripLeadingZerosAndFiller(vds);
      final cleanRaw = rawModelCode.isEmpty ? null : rawModelCode;
      final matchedEntry = cleanRaw == null
          ? null
          : (catalog?.findModel(brand, cleanRaw) ??
              catalog?.findModel(brand, vds));

      String? productTypeHint;
      if (matchedEntry != null && matchedEntry.productTypes.isNotEmpty) {
        productTypeHint = matchedEntry.productTypes.first;
      } else if (vds.startsWith('K') || vds.startsWith('U')) {
        productTypeHint = 'Excavator';
      } else if (vds.startsWith('C')) {
        productTypeHint = 'Skid Steer';
      }

      String? engineSummary;
      if (matchedEntry != null) {
        final uniqueLabels = matchedEntry.engines.map((e) => e.label).toSet();
        if (uniqueLabels.length == 1) {
          engineSummary = matchedEntry.engines.first.label;
        }
      }

      final effectiveModel = matchedEntry?.model ?? mappedModel ?? cleanRaw;
      final rangeNote = matchedEntry != null
          ? 'select Model Year from the valid ${matchedEntry.yearRangeLabel} range'
          : 'please select Model Year';

      return SerialDecodeResult(
        rawInput: rawInput,
        normalizedInput: pin,
        manufacturer: brand,
        rawModelCode: mappedModel ?? cleanRaw,
        matchedCatalogModel: matchedEntry?.model,
        modelYear: null,
        engineSummary: engineSummary,
        productTypeHint: productTypeHint,
        confidence: effectiveModel != null
            ? SerialDecodeConfidence.high
            : SerialDecodeConfidence.medium,
        source: SerialDecodeSource.isoEquipmentPin,
        userMessage: effectiveModel != null
            ? 'Identified $brand $effectiveModel from 17-character JKU PIN. Kubota JKU compact equipment PINs do not encode model year — $rangeNote.'
            : 'Identified $brand 17-character JKU PIN — please select Model Year and Model.',
      );
    }

    // KBC / KBU / KBG / KBT encode ISO year at Position 10 when not '0'.
    return _decodeGenericIsoPin17(
      rawInput: rawInput,
      normalized: pin,
      canonicalBrand: brand,
      decodePos10Year: pin[9] != '0',
      catalog: catalog,
    );
  }

  SerialDecodeResult _decodeCnh17(
    String rawInput,
    String pin, {
    required String wmi,
    required EquipmentCatalog? catalog,
    required String? currentBrand,
  }) {
    final String targetBrand;
    final bool sharedCnhPrefix;
    if (wmi == 'FNH' || wmi == 'ZEF') {
      targetBrand = 'New Holland';
      sharedCnhPrefix = false;
    } else if (wmi == 'JJG' || wmi == 'JEE') {
      targetBrand = 'Case';
      sharedCnhPrefix = false;
    } else {
      sharedCnhPrefix = true;
      targetBrand = currentBrand != null &&
              currentBrand.trim().toLowerCase() == 'new holland'
          ? 'New Holland'
          : 'Case';
    }

    final brand = _resolveBrandName(targetBrand, catalog);
    final vds = _stripLeadingZerosAndFiller(pin.substring(3, 8));
    final matchedEntry = vds.isEmpty ? null : catalog?.findModel(brand, vds);
    final rawModelCode = matchedEntry != null ? vds : null;

    final yearResolution = pin[9] == '0'
        ? const _IsoYearResolution()
        : _resolveIsoYear(
            pin[9],
            catalogEntry: matchedEntry,
            preferModernPost2010: _isAsciiLetter(pin[6]) || wmi.startsWith('N'),
          );

    String? engineSummary;
    if (matchedEntry != null) {
      final engines = matchedEntry.enginesForYear(yearResolution.year);
      if (engines.map((e) => e.label).toSet().length == 1) {
        engineSummary = engines.first.label;
      }
    }

    final base = _buildEquipmentPinResult(
      rawInput: rawInput,
      normalized: pin,
      brand: brand,
      rawModelCode: rawModelCode,
      matchedEntry: matchedEntry,
      yearResolution: yearResolution,
      engineSummary: engineSummary,
      productTypeHint:
          matchedEntry != null && matchedEntry.productTypes.isNotEmpty
              ? matchedEntry.productTypes.first
              : null,
      source: SerialDecodeSource.isoEquipmentPin,
    );

    if (!sharedCnhPrefix) return base;
    return base.copyWith(
      userMessage:
          '${base.userMessage} (Note: CNH $wmi PINs are shared across Case and New Holland — switch Manufacturer if listing New Holland.)',
    );
  }

  SerialDecodeResult _decodeCnhWichita9(
    String rawInput,
    String serial, {
    required String yearChar,
    required EquipmentCatalog? catalog,
    required String? currentBrand,
  }) {
    final year = _cnhWichitaYearCodes[yearChar];
    final targetBrand = currentBrand != null &&
            currentBrand.trim().toLowerCase() == 'new holland'
        ? 'New Holland'
        : 'Case';
    final brand = _resolveBrandName(targetBrand, catalog);

    return SerialDecodeResult(
      rawInput: rawInput,
      normalizedInput: serial,
      manufacturer: brand,
      modelYear: year,
      productTypeHint: 'Skid Steer',
      confidence: year != null
          ? SerialDecodeConfidence.medium
          : SerialDecodeConfidence.partial,
      source: SerialDecodeSource.legacyEquipmentSerial,
      userMessage: year != null
          ? 'Decoded $year CNH Wichita SSL/CTL serial ($brand; shared across Case & New Holland skid steers and compact track loaders). Please select exact Model.'
          : 'Identified CNH Wichita SSL/CTL serial ($brand; shared across Case & New Holland). Please select Model Year and Model.',
    );
  }

  SerialDecodeResult _decodeBobcat(
    String rawInput,
    String serial, {
    required EquipmentCatalog? catalog,
    required bool is17CharPin,
  }) {
    final brand = _resolveBrandName('Bobcat', catalog);
    final module4 =
        is17CharPin ? serial.substring(3, 7) : serial.substring(0, 4);
    final prefix4FromStart = serial.substring(0, 4);

    final mapped = _bobcatModulePrefixes[module4] ??
        _bobcatModulePrefixes[prefix4FromStart] ??
        (module4.startsWith('B3K') || prefix4FromStart.startsWith('B3K')
            ? const _BobcatPrefixSpec('E35', 'Excavator')
            : null);

    final rawModelCode = mapped?.model;
    final matchedEntry =
        rawModelCode == null ? null : catalog?.findModel(brand, rawModelCode);

    String? engineSummary;
    if (matchedEntry != null) {
      final uniqueLabels = matchedEntry.engines.map((e) => e.label).toSet();
      if (uniqueLabels.length == 1) {
        engineSummary = matchedEntry.engines.first.label;
      }
    }

    final productTypeHint =
        (matchedEntry != null && matchedEntry.productTypes.isNotEmpty)
            ? matchedEntry.productTypes.first
            : mapped?.productType;

    final effectiveModel = matchedEntry?.model ?? rawModelCode;
    final rangeNote = matchedEntry != null
        ? 'select Model Year from the valid ${matchedEntry.yearRangeLabel} range'
        : 'select the exact Model Year';

    return SerialDecodeResult(
      rawInput: rawInput,
      normalizedInput: serial,
      manufacturer: brand,
      rawModelCode: rawModelCode,
      matchedCatalogModel: matchedEntry?.model,
      modelYear: null,
      engineSummary: engineSummary,
      productTypeHint: productTypeHint,
      confidence: effectiveModel != null
          ? SerialDecodeConfidence.high
          : SerialDecodeConfidence.medium,
      source: is17CharPin
          ? SerialDecodeSource.isoEquipmentPin
          : SerialDecodeSource.legacyEquipmentSerial,
      userMessage: effectiveModel != null
          ? 'Identified $brand $effectiveModel from ${is17CharPin ? '17-character PIN' : 'Bobcat module serial'}. Bobcat serial prefixes identify model generation rather than calendar year — $rangeNote.'
          : 'Identified $brand ${is17CharPin ? '17-character PIN' : 'equipment serial'}. Bobcat serial prefixes identify model generation — please $rangeNote and Model.',
    );
  }

  SerialDecodeResult _decodeHitachi17(
    String rawInput,
    String pin,
    EquipmentCatalog? catalog,
  ) {
    final brand = _resolveBrandName('Hitachi', catalog);
    final vds = _stripLeadingZerosAndFiller(pin.substring(3, 8));
    final matchedEntry = vds.isEmpty ? null : catalog?.findModel(brand, vds);
    final rawModelCode = matchedEntry != null ? vds : null;

    String? engineSummary;
    if (matchedEntry != null &&
        matchedEntry.engines.map((e) => e.label).toSet().length == 1) {
      engineSummary = matchedEntry.engines.first.label;
    }

    final effectiveModel = matchedEntry?.model ?? rawModelCode;
    final yearNote = matchedEntry != null
        ? 'select Model Year from the valid ${matchedEntry.yearRangeLabel} range'
        : 'please select Model Year and Model';

    return SerialDecodeResult(
      rawInput: rawInput,
      normalizedInput: pin,
      manufacturer: brand,
      rawModelCode: rawModelCode,
      matchedCatalogModel: matchedEntry?.model,
      modelYear: null,
      engineSummary: engineSummary,
      productTypeHint:
          matchedEntry != null && matchedEntry.productTypes.isNotEmpty
              ? matchedEntry.productTypes.first
              : 'Excavator',
      confidence: effectiveModel != null
          ? SerialDecodeConfidence.high
          : SerialDecodeConfidence.medium,
      source: SerialDecodeSource.isoEquipmentPin,
      userMessage: effectiveModel != null
          ? 'Identified $brand $effectiveModel from 17-character PIN. Hitachi PINs do not encode calendar year at position 10 — $yearNote.'
          : 'Identified $brand 17-character PIN — $yearNote.',
    );
  }

  SerialDecodeResult _decodeGenericIsoPin17({
    required String rawInput,
    required String normalized,
    required String canonicalBrand,
    required bool decodePos10Year,
    required EquipmentCatalog? catalog,
    String? defaultProductTypeHint,
    String? noYearReason,
  }) {
    final brand = _resolveBrandName(canonicalBrand, catalog);
    final vds5 = _stripLeadingZerosAndFiller(normalized.substring(3, 8));
    final vds4 = _stripLeadingZerosAndFiller(normalized.substring(3, 7));

    final matched5 = vds5.isEmpty ? null : catalog?.findModel(brand, vds5);
    final matched4 = vds4.isEmpty ? null : catalog?.findModel(brand, vds4);
    var matchedEntry = matched5 ?? matched4;
    final rawModelCode =
        matched5 != null ? vds5 : (matched4 != null ? vds4 : null);

    final yearResolution = (!decodePos10Year || normalized[9] == '0')
        ? const _IsoYearResolution()
        : _resolveIsoYear(
            normalized[9],
            catalogEntry: matchedEntry,
            preferModernPost2010: _isAsciiLetter(normalized[6]),
          );

    if (yearResolution.year != null &&
        catalog != null &&
        rawModelCode != null) {
      matchedEntry = catalog.findModel(
            brand,
            rawModelCode,
            modelYear: yearResolution.year,
          ) ??
          matchedEntry;
    }

    String? engineSummary;
    if (matchedEntry != null) {
      final engines = matchedEntry.enginesForYear(yearResolution.year);
      if (engines.map((e) => e.label).toSet().length == 1) {
        engineSummary = engines.first.label;
      }
    }

    return _buildEquipmentPinResult(
      rawInput: rawInput,
      normalized: normalized,
      brand: brand,
      rawModelCode: rawModelCode,
      matchedEntry: matchedEntry,
      yearResolution: yearResolution,
      engineSummary: engineSummary,
      productTypeHint:
          matchedEntry != null && matchedEntry.productTypes.isNotEmpty
              ? matchedEntry.productTypes.first
              : defaultProductTypeHint,
      source: SerialDecodeSource.isoEquipmentPin,
      noYearReason: noYearReason,
    );
  }

  SerialDecodeResult _buildEquipmentPinResult({
    required String rawInput,
    required String normalized,
    required String brand,
    required String? rawModelCode,
    required EquipmentModelEntry? matchedEntry,
    required _IsoYearResolution yearResolution,
    required String? engineSummary,
    required String? productTypeHint,
    required SerialDecodeSource source,
    String yearPositionNote = 'position 10',
    String? noYearReason,
  }) {
    final effectiveModel = matchedEntry?.model ?? rawModelCode;
    final resolvedYear = yearResolution.year ??
        (matchedEntry != null && matchedEntry.yearFrom == matchedEntry.yearTo
            ? matchedEntry.yearFrom
            : null);

    final String message;
    if (resolvedYear != null && effectiveModel != null) {
      message =
          'Decoded $resolvedYear $brand $effectiveModel from 17-character PIN ($yearPositionNote year code).';
    } else if (resolvedYear != null && effectiveModel == null) {
      message =
          'Decoded $resolvedYear $brand from 17-character PIN ($yearPositionNote year code) — please select exact Model.';
    } else if (yearResolution.ambiguousYears.isNotEmpty) {
      final candidatesLabel = yearResolution.ambiguousYears.join(' or ');
      message = effectiveModel != null
          ? 'Identified $brand $effectiveModel from 17-character PIN. ISO year code could be $candidatesLabel — please select the exact Model Year.'
          : 'Identified $brand from 17-character PIN. ISO year code could be $candidatesLabel — please select Model Year and Model.';
    } else {
      final reasonPrefix = noYearReason != null ? '$noYearReason — ' : '';
      if (matchedEntry != null) {
        message =
            'Identified $brand ${matchedEntry.model} from 17-character PIN. ${reasonPrefix}Select Model Year from the valid ${matchedEntry.yearRangeLabel} range.';
      } else if (effectiveModel != null) {
        message =
            'Identified $brand $effectiveModel from 17-character PIN. ${reasonPrefix}Please select Model Year.';
      } else {
        message =
            'Identified $brand 17-character PIN. ${reasonPrefix}Please select Model Year and Model.';
      }
    }

    final confidence = resolvedYear != null && effectiveModel != null
        ? SerialDecodeConfidence.high
        : SerialDecodeConfidence.medium;

    return SerialDecodeResult(
      rawInput: rawInput,
      normalizedInput: normalized,
      manufacturer: brand,
      rawModelCode: rawModelCode,
      matchedCatalogModel: matchedEntry?.model,
      modelYear: resolvedYear,
      ambiguousCandidateYears: yearResolution.ambiguousYears,
      engineSummary: engineSummary,
      productTypeHint: productTypeHint,
      confidence: confidence,
      source: source,
      userMessage: message,
    );
  }

  /// Resolves an ISO 3779 / ISO 10261 year character across the 30-year cycle
  /// (`1980–2009` vs `2010–2026`), never hallucinating beyond [maxAllowedModelYear].
  _IsoYearResolution _resolveIsoYear(
    String yearChar, {
    EquipmentModelEntry? catalogEntry,
    bool preferModernPost2010 = false,
  }) {
    if (_disallowedIsoYearChars.contains(yearChar)) {
      return const _IsoYearResolution();
    }

    // Digits '1'..'9' unambiguously map to 2001..2009 (next cycle is 2031..2039).
    final digit = int.tryParse(yearChar);
    if (digit != null && digit >= 1 && digit <= 9) {
      final year = 2000 + digit;
      return year <= maxAllowedModelYear
          ? _IsoYearResolution(year: year)
          : const _IsoYearResolution();
    }

    final baseEarlyYear = _isoLetterEarlyCycleYears[yearChar];
    if (baseEarlyYear == null) {
      return const _IsoYearResolution();
    }

    final lateYear = baseEarlyYear + 30;
    final candidates = <int>[
      if (lateYear <= maxAllowedModelYear) lateYear,
      if (baseEarlyYear <= maxAllowedModelYear) baseEarlyYear,
    ];
    if (candidates.isEmpty) {
      return const _IsoYearResolution();
    }
    if (candidates.length == 1) {
      // E.g. V=1997, W=1998, X=1999, Y=2000 (since 2027..2030 > 2026).
      return _IsoYearResolution(year: candidates.first);
    }

    // 1. Disambiguate using matched catalog model's [yearFrom, yearTo] range!
    if (catalogEntry != null) {
      final matchingCatalog = candidates
          .where((y) => catalogEntry.supportsYear(y))
          .toList(growable: false);
      if (matchingCatalog.length == 1) {
        return _IsoYearResolution(year: matchingCatalog.first);
      }
    }

    // 2. Disambiguate using Position 7 alphabetic / post-2010 OEM series heuristic.
    if (preferModernPost2010 && candidates.contains(lateYear)) {
      return _IsoYearResolution(year: lateYear);
    }

    // 3. Genuinely ambiguous between two valid years <= maxAllowedModelYear.
    return _IsoYearResolution(ambiguousYears: candidates);
  }

  Map<String, dynamic>? _readCache(String vin) {
    final existing = _vpicCache.remove(vin);
    if (existing != null) {
      _vpicCache[vin] = existing;
    }
    return existing;
  }

  void _writeCache(String vin, Map<String, dynamic> row) {
    if (maxCacheEntries <= 0) return;
    _vpicCache.remove(vin);
    while (_vpicCache.length >= maxCacheEntries) {
      _vpicCache.remove(_vpicCache.keys.first);
    }
    _vpicCache[vin] = row;
  }
}

@immutable
class _IsoYearResolution {
  const _IsoYearResolution({
    this.year,
    this.ambiguousYears = const <int>[],
  });

  final int? year;
  final List<int> ambiguousYears;
}

@immutable
class _BobcatPrefixSpec {
  const _BobcatPrefixSpec(this.model, this.productType);
  final String model;
  final String productType;
}

const Set<String> _pureOffHighwayWmis = <String>{
  // Caterpillar
  'CAT',
  'CPW',
  // John Deere Forestry / Compact / Ag
  '1FF',
  '1LV',
  '1PY',
  // JCB
  'SLP',
  // Kubota
  'KBC',
  'KBU',
  'KBG',
  'KBT',
  'JKU',
  // Case / New Holland
  'JJG',
  'JEE',
  'FNH',
  'ZEF',
  'ZFH',
  // Volvo CE
  'VCE',
  'VCG',
  // Ditch Witch
  'CMW',
  'DWP',
  // Liebherr
  'WLH',
  // Hitachi
  'HCM',
  'JKM',
  // Terex / Genie
  'TWG',
  // Develon / Doosan / Sumitomo / Link-Belt
  'DHK',
  'DWK',
  'KHR',
  // Bobcat
  'A3L',
  'A3N',
  'B3Y',
  'B4S',
  'B4U',
  'AJC',
  'ALJ',
  '527',
  // Sany
  'SNY',
};

const Set<String> _collidingDeereWmis = <String>{'1DW', '1T0', '1RW'};

const Set<String> _allDeere17Wmis = <String>{
  '1DW',
  '1T0',
  '1FF',
  '1LV',
  '1PY',
  '1RW',
};

const Set<String> _komatsuEquipmentPrefixes = <String>{
  'PC',
  'HB',
  'WA',
  'GD',
  'HM',
  'WB',
  'XT',
  'PW',
};

const Set<String> _kubotaIsoYearWmis = <String>{'KBC', 'KBU', 'KBG', 'KBT'};

const Set<String> _cnh17Wmis = <String>{'JJG', 'JEE', 'FNH', 'ZEF', 'ZFH'};

const Set<String> _bobcat17Wmis = <String>{
  'A3L',
  'A3N',
  'B3Y',
  'B4S',
  'B4U',
  'AJC',
  'ALJ',
  '527',
};

const Map<String, String> _kubotaJkuModelCodes = <String, String>{
  'K0334': 'KX033-4',
  'K0404': 'KX040-4',
  'K0574': 'KX057-4',
  'K0804': 'KX080-4',
  'U0354': 'U35-4',
  'U0554': 'U55-4',
  'C0652': 'SVL65-2',
  'C0752': 'SVL75-2',
  'C0753': 'SVL75-3',
  'C0902': 'SVL90-2',
  'C0952': 'SVL95-2s',
  'C0972': 'SVL97-2',
};

const Map<String, int> _cnhWichitaYearCodes = <String, int>{
  '9': 2009,
  'A': 2010,
  'B': 2011,
  'C': 2012,
  'D': 2013,
  'E': 2014,
  'F': 2015,
  'G': 2016,
  'H': 2017,
  'J': 2018,
  'K': 2019,
  'L': 2020,
  'M': 2021,
  'N': 2022,
  'P': 2023,
  'R': 2024,
  'S': 2025,
  'T': 2026,
};

const Map<String, _BobcatPrefixSpec> _bobcatModulePrefixes =
    <String, _BobcatPrefixSpec>{
  'A3NV': _BobcatPrefixSpec('S650', 'Skid Steer'),
  'A3NW': _BobcatPrefixSpec('S650', 'Skid Steer'),
  'ALJU': _BobcatPrefixSpec('T650', 'Skid Steer'),
  'B4SC': _BobcatPrefixSpec('T76', 'Skid Steer'),
  'B4SD': _BobcatPrefixSpec('S76', 'Skid Steer'),
  'B3YC': _BobcatPrefixSpec('T66', 'Skid Steer'),
  'A00E': _BobcatPrefixSpec('E35', 'Excavator'),
  'B3K8': _BobcatPrefixSpec('E35', 'Excavator'),
  'B3K9': _BobcatPrefixSpec('E35', 'Excavator'),
  'B3KA': _BobcatPrefixSpec('E35', 'Excavator'),
  '5144': _BobcatPrefixSpec('753', 'Skid Steer'),
  '5158': _BobcatPrefixSpec('763', 'Skid Steer'),
  '5190': _BobcatPrefixSpec('773', 'Skid Steer'),
  '5266': _BobcatPrefixSpec('S185', 'Skid Steer'),
  '5311': _BobcatPrefixSpec('T190', 'Skid Steer'),
};

const Set<String> _disallowedIsoYearChars = <String>{
  'I',
  'O',
  'Q',
  'U',
  'Z',
  '0',
};

const Map<String, int> _isoLetterEarlyCycleYears = <String, int>{
  'A': 1980,
  'B': 1981,
  'C': 1982,
  'D': 1983,
  'E': 1984,
  'F': 1985,
  'G': 1986,
  'H': 1987,
  'J': 1988,
  'K': 1989,
  'L': 1990,
  'M': 1991,
  'N': 1992,
  'P': 1993,
  'R': 1994,
  'S': 1995,
  'T': 1996,
  'V': 1997,
  'W': 1998,
  'X': 1999,
  'Y': 2000,
};

const List<int> _vinPositionWeights = <int>[
  8,
  7,
  6,
  5,
  4,
  3,
  2,
  10,
  0,
  9,
  8,
  7,
  6,
  5,
  4,
  3,
  2,
];

const Map<String, int> _vinCharTransliteration = <String, int>{
  '0': 0,
  '1': 1,
  '2': 2,
  '3': 3,
  '4': 4,
  '5': 5,
  '6': 6,
  '7': 7,
  '8': 8,
  '9': 9,
  'A': 1,
  'B': 2,
  'C': 3,
  'D': 4,
  'E': 5,
  'F': 6,
  'G': 7,
  'H': 8,
  'J': 1,
  'K': 2,
  'L': 3,
  'M': 4,
  'N': 5,
  'P': 7,
  'R': 9,
  'S': 2,
  'T': 3,
  'U': 4,
  'V': 5,
  'W': 6,
  'X': 7,
  'Y': 8,
  'Z': 9,
};

bool _isCnhNSeriesWmi(String wmi) =>
    wmi.length == 3 && RegExp(r'^N[A-Z][A-Z0-9]$').hasMatch(wmi);

bool _containsDisallowedIsoVinLetters(String value) =>
    value.contains('I') || value.contains('O') || value.contains('Q');

bool _isAsciiLetter(String char) =>
    char.length == 1 && RegExp(r'^[A-Z]$').hasMatch(char);

bool _looksLikeDeereEquipmentVds(String chars4To7, String chars4To8) {
  if (RegExp(r'^\d{3}[A-Z]$').hasMatch(chars4To7)) return true;
  if (RegExp(r'^\d{4}[A-Z]$').hasMatch(chars4To8)) return true;
  if (RegExp(r'^0?\d{2,3}(?:SL|HL|EL|LC|GL|GP|TC)$').hasMatch(chars4To8)) {
    return true;
  }
  return false;
}

bool _isBobcat9CharSerial(String serial) =>
    RegExp(
      r'^(?:A3L|A3N|B3Y|B4S|B4U|AJC|ALJ|A00|B3K|51\d|52\d|53\d)[A-Z0-9]\d{5}$',
    ).hasMatch(serial) ||
    _bobcatModulePrefixes.containsKey(serial.substring(0, 4)) &&
        RegExp(r'^\d{5}$').hasMatch(serial.substring(4));

String _stripLeadingZerosAndFiller(String rawVds) => rawVds
    .replaceAll(RegExp(r'[^A-Z0-9]'), '')
    .replaceFirst(RegExp(r'^0+(?=[A-Z0-9])'), '');

String _resolveBrandName(String fallbackBrand, EquipmentCatalog? catalog) {
  if (catalog == null) return fallbackBrand;
  return catalog.findManufacturer(fallbackBrand)?.name ?? fallbackBrand;
}

String _cleanVpicValue(Object? raw) {
  if (raw == null) return '';
  final text = '$raw'.trim();
  if (text.isEmpty ||
      text.toLowerCase() == 'null' ||
      text.toLowerCase() == 'not applicable') {
    return '';
  }
  return text;
}

String _normalizeNhtsaMake(
  String rawMake, {
  required String vehicleType,
  required String bodyClass,
  required String? rawModel,
}) {
  final upper = rawMake.trim().toUpperCase();
  switch (upper) {
    case 'PETERBILT':
      return 'Peterbilt';
    case 'KENWORTH':
      return 'Kenworth';
    case 'FREIGHTLINER':
      return 'Freightliner';
    case 'WESTERN STAR':
    case 'WESTERN STAR TRUCKS':
      return 'Western Star';
    case 'MACK':
    case 'MACK TRUCKS':
      return 'Mack';
    case 'INTERNATIONAL':
    case 'NAVISTAR':
    case 'INTERNATIONAL HARVESTER':
      return 'International';
    case 'VOLVO':
    case 'VOLVO TRUCK':
    case 'VOLVO TRUCKS':
      final vtUpper = '$vehicleType $bodyClass ${rawModel ?? ''}'.toUpperCase();
      if (upper.contains('TRUCK') ||
          vtUpper.contains('TRUCK') ||
          vtUpper.contains('TRACTOR') ||
          vtUpper.contains('INCOMPLETE') ||
          vtUpper.contains('VNL') ||
          vtUpper.contains('VNR') ||
          vtUpper.contains('VHD')) {
        return 'Volvo Trucks';
      }
      return 'Volvo';
    case 'FORD':
      return 'Ford';
    case 'CHEVROLET':
      return 'Chevrolet';
    case 'GMC':
      return 'GMC';
    case 'RAM':
      return 'Ram';
    case 'DODGE':
      return 'Dodge';
    case 'TRAIL KING':
    case 'TRAIL KING INDUSTRIES':
      return 'Trail King';
    case 'FONTAINE':
    case 'FONTAINE TRAILER':
    case 'FONTAINE HEAVY HAUL':
      return 'Fontaine';
    case 'GREAT DANE':
    case 'GREAT DANE TRAILERS':
      return 'Great Dane';
    case 'VERMEER':
    case 'VERMEER MANUFACTURING':
      return 'Vermeer';
    case 'DITCH WITCH':
    case 'THE CHARLES MACHINE WORKS':
    case 'CHARLES MACHINE WORKS':
      return 'Ditch Witch';
    case 'CATERPILLAR':
      return 'Caterpillar';
    case 'JOHN DEERE':
    case 'DEERE':
      return 'John Deere';
    case 'JLG':
    case 'GENIE':
      return 'Genie / JLG';
    case 'GROVE':
    case 'MANITOWOC':
      return 'Grove / Manitowoc';
    case 'SULLAIR':
      return 'Sullair';
    case 'ATLAS COPCO':
      return 'Atlas Copco';
    case 'LINCOLN ELECTRIC':
      return 'Lincoln Electric';
    case 'MILLER':
    case 'MILLER ELECTRIC':
      return 'Miller';
    default:
      return _titleCaseBrand(rawMake);
  }
}

String _titleCaseBrand(String raw) {
  final words = raw.trim().split(RegExp(r'\s+'));
  return words.map((word) {
    if (word.length <= 3 && RegExp(r'^[A-Z0-9]+$').hasMatch(word)) {
      return word;
    }
    if (word.isEmpty) return word;
    return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
  }).join(' ');
}

String? _buildNhtsaEngineSummary(Map<String, dynamic> row) {
  final engineMfr = _cleanVpicValue(row['EngineManufacturer']);
  final engineModel = _cleanVpicValue(row['EngineModel']);
  final dispRaw = double.tryParse(_cleanVpicValue(row['DisplacementL']));
  final cylinders = int.tryParse(_cleanVpicValue(row['EngineCylinders']));
  final hpFrom = double.tryParse(_cleanVpicValue(row['EngineHP']))?.round();
  final hpTo = double.tryParse(_cleanVpicValue(row['EngineHP_to']))?.round();
  final fuelRaw = _cleanVpicValue(row['FuelTypePrimary']);
  final driveRaw = _cleanVpicValue(row['DriveType']);

  String header = '';
  if (engineMfr.isNotEmpty && engineModel.isNotEmpty) {
    if (engineModel.toLowerCase().startsWith(engineMfr.toLowerCase())) {
      header = engineModel;
    } else {
      header = '${_titleCaseEngineMake(engineMfr)} $engineModel';
    }
  } else if (engineModel.isNotEmpty) {
    header = engineModel;
  } else if (engineMfr.isNotEmpty) {
    header = _titleCaseEngineMake(engineMfr);
  }

  final blockTokens = <String>[
    if (dispRaw != null && dispRaw > 0) '${dispRaw.toStringAsFixed(1)}L',
    if (cylinders != null && cylinders > 0) '$cylinders-Cyl',
    if (fuelRaw.isNotEmpty) _cleanFuelLabel(fuelRaw),
  ];
  final blockStr = blockTokens.join(' ');

  String hpStr = '';
  if (hpFrom != null && hpFrom > 0) {
    hpStr = (hpTo != null && hpTo > hpFrom) ? '$hpFrom–$hpTo HP' : '$hpFrom HP';
  }

  final segments = <String>[
    if (header.isNotEmpty) header,
    if (blockStr.isNotEmpty) blockStr,
    if (hpStr.isNotEmpty) hpStr,
    if (driveRaw.isNotEmpty && driveRaw.length <= 16) driveRaw,
  ];

  return segments.isEmpty ? null : segments.join(' • ');
}

String _titleCaseEngineMake(String value) {
  final upper = value.trim().toUpperCase();
  switch (upper) {
    case 'CUMMINS':
    case 'CUMMINS INC.':
      return 'Cummins';
    case 'PACCAR':
      return 'PACCAR';
    case 'DETROIT':
    case 'DETROIT DIESEL':
      return 'Detroit';
    case 'CATERPILLAR':
      return 'Caterpillar';
    case 'MACK':
      return 'Mack';
    case 'VOLVO':
      return 'Volvo';
    case 'NAVISTAR':
    case 'INTERNATIONAL':
      return 'International';
    default:
      return _titleCaseBrand(value);
  }
}

String _cleanFuelLabel(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('diesel')) return 'Diesel';
  if (lower.contains('gasoline')) return 'Gasoline';
  if (lower.contains('compressed natural gas') || lower == 'cng') return 'CNG';
  if (lower.contains('liquefied natural gas') || lower == 'lng') return 'LNG';
  if (lower.contains('electric')) return 'Electric';
  return raw;
}

String? _inferNhtsaProductTypeHint({
  required String vehicleType,
  required String bodyClass,
  required String trailerBodyType,
}) {
  final combined = '$vehicleType $bodyClass $trailerBodyType'.toLowerCase();
  if (combined.contains('lowboy') || combined.contains('gooseneck')) {
    return 'Lowboy Trailer';
  }
  if (combined.contains('step deck') || combined.contains('drop deck')) {
    return 'Step Deck';
  }
  if (combined.contains('flatbed') || combined.contains('platform')) {
    return 'Flatbed Trailer';
  }
  if (combined.contains('truck-tractor') ||
      combined.contains('truck tractor') ||
      (combined.contains('truck') && !combined.contains('trailer'))) {
    return 'Semi Truck';
  }
  return null;
}

String? _inferCaterpillarProductType(String? model) {
  if (model == null || model.isEmpty) return null;
  if (RegExp(r'^3\d{2}').hasMatch(model)) return 'Excavator';
  if (RegExp(r'^D\d').hasMatch(model)) return 'Bulldozer';
  if (RegExp(r'^9\d{2}').hasMatch(model)) return 'Loader';
  if (RegExp(r'^2\d{2}').hasMatch(model)) return 'Skid Steer';
  if (RegExp(r'^4\d{2}').hasMatch(model)) return 'Backhoe';
  if (RegExp(r'^1[246]\d').hasMatch(model)) return 'Grader';
  if (RegExp(r'^(?:TL|TH)').hasMatch(model)) return 'Telehandler';
  if (RegExp(r'^(?:CS|CP|CB|CW)').hasMatch(model)) return 'Compactor';
  return null;
}

String? _inferDeereProductType(String? model) {
  if (model == null || model.isEmpty) return null;
  if (RegExp(r'^(?:310|410|710)').hasMatch(model)) return 'Backhoe';
  if (RegExp(r'^3[1-3]\d[A-Z]$').hasMatch(model)) return 'Skid Steer';
  if (RegExp(r'^(?:450|550|650|700|750|850|950|1050)[A-Z]').hasMatch(model)) {
    return 'Bulldozer';
  }
  if (RegExp(r'^(?:444|524|544|624|644|724|744|824|844|944)').hasMatch(model)) {
    return 'Loader';
  }
  if (RegExp(r'^(?:670|672|770|772|870|872)').hasMatch(model)) return 'Grader';
  if (RegExp(
          r'^(?:17|26|30|35|50|60|75|85|130|135|160|180|200|210|245|250|300|345|350|380|470)')
      .hasMatch(model)) {
    return 'Excavator';
  }
  return null;
}

String? _inferJcbProductType(String? model) {
  if (model == null || model.isEmpty) return null;
  if (RegExp(r'^[1-5]CX').hasMatch(model)) return 'Backhoe';
  if (RegExp(r'^5\d{2}').hasMatch(model)) return 'Telehandler';
  if (RegExp(r'^(?:190|215|270|300)').hasMatch(model)) return 'Skid Steer';
  return null;
}
