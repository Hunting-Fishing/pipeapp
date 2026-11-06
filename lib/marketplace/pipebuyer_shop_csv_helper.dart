import 'package:flutter/foundation.dart';

import 'pipebuyer_shop_taxonomy.dart';

@immutable
class PipeBuyerSpreadsheetParseResult {
  const PipeBuyerSpreadsheetParseResult({
    required this.readyPayloads,
    required this.totalDataRows,
    required this.pendingBlankLinkRows,
    required this.invalidRows,
  });

  final List<Map<String, Object?>> readyPayloads;
  final int totalDataRows;
  final int pendingBlankLinkRows;
  final List<String> invalidRows;
}

abstract final class PipeBuyerShopCsvHelper {
  static const List<String> csvHeaders = <String>[
    'item_id',
    'category_code',
    'category_name',
    'subcategory',
    'title',
    'brand',
    'amazon_search_helper_url',
    'amazon_affiliate_link',
    'image_url',
    'asin',
    'source_type',
    'featured',
    'priority_rank',
    'badge_text',
    'description',
    'highlights',
    'eligible_countries',
  ];

  static String exportProductsToCsv(List<PipeBuyerShopProduct> products) {
    final buffer = StringBuffer();
    buffer.writeln(csvHeaders.join(','));
    for (final item in products) {
      final searchQuery =
          Uri.encodeQueryComponent('${item.brand} ${item.title}');
      final helperUrl = 'https://www.amazon.com/s?k=$searchQuery';
      final row = <String>[
        item.id,
        item.categoryCode,
        item.category.label,
        item.subcategory,
        item.title,
        item.brand,
        helperUrl,
        item.destinationUrl,
        item.imageUrl,
        item.asin,
        item.sourceType.code,
        item.featured ? 'TRUE' : 'FALSE',
        '${item.priorityRank}',
        item.badgeText,
        item.description,
        item.highlights.join(' | '),
        item.effectiveEligibleCountries.join(' | '),
      ];
      buffer.writeln(row.map(_escapeCsvCell).join(','));
    }
    return buffer.toString();
  }

  static PipeBuyerSpreadsheetParseResult parseSpreadsheetText(
    String rawText,
    PipeBuyerShopSettings settings,
  ) {
    final trimmed = rawText.replaceFirst('\uFEFF', '').trim();
    if (trimmed.isEmpty) {
      return const PipeBuyerSpreadsheetParseResult(
        readyPayloads: <Map<String, Object?>>[],
        totalDataRows: 0,
        pendingBlankLinkRows: 0,
        invalidRows: <String>[],
      );
    }

    final firstNewline = trimmed.indexOf('\n');
    final firstLine =
        firstNewline >= 0 ? trimmed.substring(0, firstNewline) : trimmed;
    final delimiter = '\t'.allMatches(firstLine).length >= 3 ? '\t' : ',';

    final rows = _parseDelimited(trimmed, delimiter);
    if (rows.length < 2) {
      return const PipeBuyerSpreadsheetParseResult(
        readyPayloads: <Map<String, Object?>>[],
        totalDataRows: 0,
        pendingBlankLinkRows: 0,
        invalidRows: <String>[
          'Spreadsheet must include a header row and at least one item row.',
        ],
      );
    }

    final headerMap = <String, int>{};
    final headerCells = rows.first;
    for (var i = 0; i < headerCells.length; i++) {
      final norm = _normalizeHeader(headerCells[i]);
      if (norm.isNotEmpty) {
        headerMap[norm] = i;
      }
    }

    String cell(List<String> row, List<String> aliases) {
      for (final alias in aliases) {
        final idx = headerMap[alias];
        if (idx != null && idx < row.length) {
          final val = row[idx].trim();
          if (val.isNotEmpty) return val;
        }
      }
      return '';
    }

    final ready = <Map<String, Object?>>[];
    final invalid = <String>[];
    var totalDataRows = 0;
    var pendingBlank = 0;

    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((c) => c.trim().isEmpty)) continue;
      totalDataRows += 1;

      final rawLinkInput = cell(row, const <String>[
        'amazon_affiliate_link',
        'affiliate_link',
        'destination_url',
        'destinationurl',
        'amazon_link',
        'sitestripe_link',
        'partner_url',
        'url',
      ]);
      final rawAsinInput = cell(row, const <String>['asin', 'amazon_asin']);

      if (rawLinkInput.isEmpty && rawAsinInput.isEmpty) {
        pendingBlank += 1;
        continue;
      }

      final parsedLink = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
        rawLinkInput.isNotEmpty ? rawLinkInput : rawAsinInput,
        settings,
      );
      if (parsedLink == null) {
        if (invalid.length < 25) {
          invalid.add(
            'Row ${r + 1}: Invalid Amazon/HTTPS affiliate link or ASIN ("$rawLinkInput").',
          );
        }
        continue;
      }

      final rawId = cell(row, const <String>[
        'item_id',
        'id',
        'product_id',
        'sku',
      ]);
      final rawTitle = cell(row, const <String>[
        'title',
        'product_title',
        'item_name',
        'name',
      ]);
      final effectiveTitle =
          rawTitle.isNotEmpty ? rawTitle : parsedLink.suggestedTitle;
      if (effectiveTitle.trim().length < 3) {
        if (invalid.length < 25) {
          invalid.add('Row ${r + 1}: Product title is missing or too short.');
        }
        continue;
      }

      final rawCategoryCode = cell(row, const <String>[
        'category_code',
        'categorycode',
      ]);
      final rawCategoryName = cell(row, const <String>[
        'category_name',
        'category',
      ]);
      final categoryCode = _resolveCategoryCode(
        rawCategoryCode,
        rawCategoryName,
        parsedLink.suggestedCategoryCode,
      );

      final subcategory = cell(row, const <String>[
        'subcategory',
        'sub_category',
        'subcategory_name',
      ]);
      final rawBrand = cell(row, const <String>['brand', 'manufacturer']);
      final effectiveBrand =
          rawBrand.isNotEmpty ? rawBrand : parsedLink.suggestedBrand;

      final rawSource = cell(row, const <String>[
        'source_type',
        'sourcetype',
        'channel',
      ]);
      final sourceType = rawSource.isNotEmpty
          ? PipeBuyerShopSourceType.fromCode(rawSource)
          : parsedLink.sourceType;

      final rawImage = cell(row, const <String>[
        'image_url',
        'image_url_optional',
        'imageurl',
      ]);
      final effectiveImage =
          rawImage.isNotEmpty ? rawImage : parsedLink.imageUrl;

      final featuredStr =
          cell(row, const <String>['featured', 'is_featured']).toLowerCase();
      final featured = featuredStr == 'true' ||
          featuredStr == 'yes' ||
          featuredStr == '1' ||
          featuredStr == 'y';

      final rankRaw = cell(row, const <String>[
        'priority_rank',
        'priority',
        'rank',
      ]);
      final priorityRank = int.tryParse(rankRaw) ?? (100 + r);

      final badgeText = cell(row, const <String>['badge_text', 'badge']);
      final description = cell(row, const <String>[
        'description',
        'field_commentary',
        'commentary',
      ]);
      final highlightsRaw = cell(row, const <String>[
        'highlights',
        'key_specs',
        'specs',
      ]);
      final highlights = highlightsRaw
          .split(RegExp(r'\s*\|\s*|\r?\n'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(6)
          .toList(growable: false);

      final countriesRaw = cell(row, const <String>[
        'eligible_countries',
        'ships_to',
        'countries',
        'country',
        'region',
      ]);
      final eligibleCountries = countriesRaw.isNotEmpty
          ? PipeBuyerShopUrlBuilder.normalizeEligibleCountries(
              countriesRaw.split(RegExp(r'[,;|/\s]+')),
              fallback: parsedLink.eligibleCountries,
            )
          : parsedLink.eligibleCountries;

      ready.add(<String, Object?>{
        if (rawId.isNotEmpty) 'id': rawId,
        'rawAffiliateInput':
            rawLinkInput.isNotEmpty ? rawLinkInput : rawAsinInput,
        'title': effectiveTitle,
        'brand': effectiveBrand.isEmpty ? 'Industrial Select' : effectiveBrand,
        'vendorName': sourceType == PipeBuyerShopSourceType.amazonAffiliate
            ? 'Amazon'
            : (parsedLink.suggestedVendorName.isNotEmpty
                ? parsedLink.suggestedVendorName
                : (effectiveBrand.isEmpty ? 'Partner' : effectiveBrand)),
        'sourceType': sourceType.code,
        'status': 'active',
        'categoryCode': categoryCode,
        'subcategory': subcategory,
        'asin': rawAsinInput.isNotEmpty ? rawAsinInput : parsedLink.asin,
        'destinationUrl': parsedLink.destinationUrl,
        'imageUrl': effectiveImage,
        'badgeText': badgeText,
        'description': description,
        'highlights': highlights,
        'eligibleCountries': eligibleCountries,
        'featured': featured,
        'priorityRank': priorityRank,
      });
    }

    return PipeBuyerSpreadsheetParseResult(
      readyPayloads: ready,
      totalDataRows: totalDataRows,
      pendingBlankLinkRows: pendingBlank,
      invalidRows: invalid,
    );
  }

  static String _resolveCategoryCode(
    String rawCode,
    String rawName,
    String fallbackCode,
  ) {
    if (PipeBuyerShopTaxonomy.categoryByCode(rawCode) != null) {
      return rawCode.trim();
    }
    final lowerName = rawName.trim().toLowerCase();
    if (lowerName.isNotEmpty) {
      for (final cat in PipeBuyerShopTaxonomy.categories) {
        if (cat.code == lowerName ||
            cat.label.toLowerCase() == lowerName ||
            cat.shortLabel.toLowerCase() == lowerName) {
          return cat.code;
        }
      }
    }
    return PipeBuyerShopTaxonomy.categoryByCode(fallbackCode)?.code ??
        'pipe_welding_fab';
  }

  static String _normalizeHeader(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String _escapeCsvCell(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static List<List<String>> _parseDelimited(String input, String delimiter) {
    final rows = <List<String>>[];
    var currentRow = <String>[];
    final currentCell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            currentCell.write('"');
            i += 1;
          } else {
            inQuotes = false;
          }
        } else {
          currentCell.write(ch);
        }
      } else {
        if (ch == '"' && currentCell.isEmpty) {
          inQuotes = true;
        } else if (ch == delimiter) {
          currentRow.add(currentCell.toString());
          currentCell.clear();
        } else if (ch == '\r') {
          if (i + 1 < input.length && input[i + 1] == '\n') {
            i += 1;
          }
          currentRow.add(currentCell.toString());
          currentCell.clear();
          rows.add(currentRow);
          currentRow = <String>[];
        } else if (ch == '\n') {
          currentRow.add(currentCell.toString());
          currentCell.clear();
          rows.add(currentRow);
          currentRow = <String>[];
        } else {
          currentCell.write(ch);
        }
      }
    }
    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString());
      rows.add(currentRow);
    }
    return rows;
  }
}
