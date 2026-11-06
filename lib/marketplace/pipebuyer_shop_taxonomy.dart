import 'package:flutter/material.dart';

@immutable
class PipeBuyerShopCategory {
  const PipeBuyerShopCategory({
    required this.code,
    required this.label,
    required this.shortLabel,
    required this.subtitle,
    required this.icon,
    required this.iconAsset,
    required this.accentColor,
    required this.marketplaceCategories,
    this.subcategories = const <String>[],
  });

  final String code;
  final String label;
  final String shortLabel;
  final String subtitle;
  final IconData icon;
  final String iconAsset;
  final Color accentColor;
  final List<String> marketplaceCategories;
  final List<String> subcategories;
}

enum PipeBuyerShopSourceType {
  amazonAffiliate('amazon_affiliate', 'Amazon Affiliate'),
  aliexpressAffiliate('aliexpress_affiliate', 'AliExpress Affiliate'),
  shopeeAffiliate('shopee_affiliate', 'Shopee Affiliate'),
  lazadaAffiliate('lazada_affiliate', 'Lazada LazAffiliate'),
  ebayPartner('ebay_partner', 'eBay Partner Network'),
  walmartAffiliate('walmart_affiliate', 'Walmart Affiliate'),
  temuAffiliate('temu_affiliate', 'Temu Affiliate'),
  tiktokShopAffiliate('tiktok_shop_affiliate', 'TikTok Shop Affiliate'),
  alibabaB2b('alibaba_b2b', 'Alibaba / DHgate B2B'),
  hardwareProRetail('hardware_pro_retail', 'Pro Hardware & Industrial Retail'),
  affiliateNetwork(
    'affiliate_network',
    'Affiliate Network (Involve Asia / Impact / CJ)',
  ),
  brandPartner('brand_partner', 'Brand Partner'),
  distributorAffiliate('distributor_affiliate', 'Authorized Distributor'),
  vendorCatalog('vendor_catalog', 'Verified Vendor');

  const PipeBuyerShopSourceType(this.code, this.label);
  final String code;
  final String label;

  static PipeBuyerShopSourceType fromCode(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final item in PipeBuyerShopSourceType.values) {
      if (item.code == normalized) return item;
    }
    return PipeBuyerShopSourceType.amazonAffiliate;
  }
}

@immutable
class PipeBuyerAffiliatePlatformInfo {
  const PipeBuyerAffiliatePlatformInfo({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.regions,
    required this.commissionRange,
    required this.cookieWindow,
    required this.signupUrl,
    required this.trackingHint,
    required this.bestFor,
    this.sampleDomains = const <String>[],
  });

  final String id;
  final String name;
  final PipeBuyerShopSourceType sourceType;
  final String regions;
  final String commissionRange;
  final String cookieWindow;
  final String signupUrl;
  final String trackingHint;
  final String bestFor;
  final List<String> sampleDomains;
}

@immutable
class PipeBuyerShopSettings {
  const PipeBuyerShopSettings({
    this.storeEnabled = true,
    this.vendorApplicationsOpen = true,
    this.amazonAssociateTagUs = 'pipebuyer-20',
    this.amazonAssociateTagCa = 'pipebuyer0c-20',
    this.amazonAssociateTagUk = '',
    this.amazonAssociateTagAu = '',
    this.amazonAssociateTagSg = '',
    this.aliexpressTrackingId = '',
    this.shopeeAffiliateSubId = '',
    this.lazadaAffiliateSubId = '',
    this.involveAsiaSubId = '',
    this.ebayCampaignId = '',
    this.skimlinksPublisherId = '',
    this.forceOverrideAmazonTag = false,
    this.defaultUtmSource = 'pipebuyer',
    this.defaultUtmMedium = 'affiliate_store',
    this.disclosureText =
        'As an Amazon Associate and authorized global affiliate partner (including AliExpress, Lazada, Shopee, eBay & industrial retailers), Pipe Buyer earns from qualifying purchases at no additional cost to you.',
    this.priceDisclaimerText =
        'Product prices and availability are accurate as of the time shown on the partner site and are subject to change.',
    this.hiddenStarterIds = const <String>[],
  });

  final bool storeEnabled;
  final bool vendorApplicationsOpen;
  final String amazonAssociateTagUs;
  final String amazonAssociateTagCa;
  final String amazonAssociateTagUk;
  final String amazonAssociateTagAu;
  final String amazonAssociateTagSg;
  final String aliexpressTrackingId;
  final String shopeeAffiliateSubId;
  final String lazadaAffiliateSubId;
  final String involveAsiaSubId;
  final String ebayCampaignId;
  final String skimlinksPublisherId;
  final bool forceOverrideAmazonTag;
  final String defaultUtmSource;
  final String defaultUtmMedium;
  final String disclosureText;
  final String priceDisclaimerText;
  final List<String> hiddenStarterIds;

  factory PipeBuyerShopSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PipeBuyerShopSettings();
    const defaults = PipeBuyerShopSettings();
    String str(String key, String fallback) {
      final raw = json[key]?.toString().trim() ?? '';
      return raw.isEmpty ? fallback : raw;
    }

    final rawHidden = json['hiddenStarterIds'];
    final hiddenIds = rawHidden is Iterable
        ? rawHidden
            .map((e) => e?.toString().trim().toLowerCase() ?? '')
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return PipeBuyerShopSettings(
      storeEnabled: json['storeEnabled'] is bool
          ? json['storeEnabled'] as bool
          : defaults.storeEnabled,
      vendorApplicationsOpen: json['vendorApplicationsOpen'] is bool
          ? json['vendorApplicationsOpen'] as bool
          : defaults.vendorApplicationsOpen,
      amazonAssociateTagUs:
          str('amazonAssociateTagUs', defaults.amazonAssociateTagUs),
      amazonAssociateTagCa:
          str('amazonAssociateTagCa', defaults.amazonAssociateTagCa),
      amazonAssociateTagUk:
          json['amazonAssociateTagUk']?.toString().trim() ?? '',
      amazonAssociateTagAu:
          json['amazonAssociateTagAu']?.toString().trim() ?? '',
      amazonAssociateTagSg:
          json['amazonAssociateTagSg']?.toString().trim() ?? '',
      aliexpressTrackingId:
          json['aliexpressTrackingId']?.toString().trim() ?? '',
      shopeeAffiliateSubId:
          json['shopeeAffiliateSubId']?.toString().trim() ?? '',
      lazadaAffiliateSubId:
          json['lazadaAffiliateSubId']?.toString().trim() ?? '',
      involveAsiaSubId: json['involveAsiaSubId']?.toString().trim() ?? '',
      ebayCampaignId: json['ebayCampaignId']?.toString().trim() ?? '',
      skimlinksPublisherId:
          json['skimlinksPublisherId']?.toString().trim() ?? '',
      forceOverrideAmazonTag: json['forceOverrideAmazonTag'] == true,
      defaultUtmSource: str('defaultUtmSource', defaults.defaultUtmSource),
      defaultUtmMedium: str('defaultUtmMedium', defaults.defaultUtmMedium),
      disclosureText: str('disclosureText', defaults.disclosureText),
      priceDisclaimerText:
          str('priceDisclaimerText', defaults.priceDisclaimerText),
      hiddenStarterIds: hiddenIds,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'storeEnabled': storeEnabled,
        'vendorApplicationsOpen': vendorApplicationsOpen,
        'amazonAssociateTagUs': amazonAssociateTagUs,
        'amazonAssociateTagCa': amazonAssociateTagCa,
        'amazonAssociateTagUk': amazonAssociateTagUk,
        'amazonAssociateTagAu': amazonAssociateTagAu,
        'amazonAssociateTagSg': amazonAssociateTagSg,
        'aliexpressTrackingId': aliexpressTrackingId,
        'shopeeAffiliateSubId': shopeeAffiliateSubId,
        'lazadaAffiliateSubId': lazadaAffiliateSubId,
        'involveAsiaSubId': involveAsiaSubId,
        'ebayCampaignId': ebayCampaignId,
        'skimlinksPublisherId': skimlinksPublisherId,
        'forceOverrideAmazonTag': forceOverrideAmazonTag,
        'defaultUtmSource': defaultUtmSource,
        'defaultUtmMedium': defaultUtmMedium,
        'disclosureText': disclosureText,
        'priceDisclaimerText': priceDisclaimerText,
        'hiddenStarterIds': hiddenStarterIds,
      };
}

@immutable
class PipeBuyerShopProduct {
  const PipeBuyerShopProduct({
    required this.id,
    required this.title,
    required this.brand,
    required this.vendorName,
    required this.sourceType,
    required this.categoryCode,
    required this.destinationUrl,
    this.destinationUrlCa = '',
    this.asin = '',
    this.subcategory = '',
    this.description = '',
    this.imageUrl = '',
    this.fallbackIconAsset = '',
    this.priceDisplay = '',
    this.badgeText = '',
    this.ctaLabel = '',
    this.featured = false,
    this.priorityRank = 100,
    this.status = 'active',
    this.highlights = const <String>[],
    this.tags = const <String>[],
    this.marketplaceCategories = const <String>[],
    this.clickCount = 0,
    this.isStarterSeed = false,
  });

  final String id;
  final String title;
  final String brand;
  final String vendorName;
  final PipeBuyerShopSourceType sourceType;
  final String categoryCode;
  final String destinationUrl;
  final String destinationUrlCa;
  final String asin;
  final String subcategory;
  final String description;
  final String imageUrl;
  final String fallbackIconAsset;
  final String priceDisplay;
  final String badgeText;
  final String ctaLabel;
  final bool featured;
  final int priorityRank;
  final String status;
  final List<String> highlights;
  final List<String> tags;
  final List<String> marketplaceCategories;
  final int clickCount;
  final bool isStarterSeed;

  String get effectiveCtaLabel {
    if (ctaLabel.trim().isNotEmpty) return ctaLabel.trim();
    return switch (sourceType) {
      PipeBuyerShopSourceType.amazonAffiliate => 'Buy on Amazon',
      PipeBuyerShopSourceType.aliexpressAffiliate => 'Buy on AliExpress',
      PipeBuyerShopSourceType.shopeeAffiliate => 'Buy on Shopee',
      PipeBuyerShopSourceType.lazadaAffiliate => 'Buy on Lazada',
      PipeBuyerShopSourceType.ebayPartner => 'Buy on eBay',
      PipeBuyerShopSourceType.walmartAffiliate => 'Buy at Walmart',
      PipeBuyerShopSourceType.temuAffiliate => 'Buy on Temu',
      PipeBuyerShopSourceType.tiktokShopAffiliate => 'View on TikTok Shop',
      PipeBuyerShopSourceType.alibabaB2b => 'Source on Alibaba',
      PipeBuyerShopSourceType.hardwareProRetail =>
        vendorName.isNotEmpty ? 'Shop $vendorName' : 'Shop Partner',
      PipeBuyerShopSourceType.affiliateNetwork =>
        vendorName.isNotEmpty ? 'Shop $vendorName' : 'View Partner Offer',
      PipeBuyerShopSourceType.brandPartner => 'Shop $brand',
      PipeBuyerShopSourceType.distributorAffiliate => 'Shop $vendorName',
      PipeBuyerShopSourceType.vendorCatalog => 'Shop Vendor',
    };
  }

  PipeBuyerShopCategory get category =>
      PipeBuyerShopTaxonomy.categoryByCode(categoryCode) ??
      PipeBuyerShopTaxonomy.categories.first;

  String get effectiveIconAsset => fallbackIconAsset.trim().isNotEmpty
      ? fallbackIconAsset.trim()
      : category.iconAsset;

  factory PipeBuyerShopProduct.fromJson(Map<String, dynamic> json) {
    List<String> strList(Object? raw) {
      if (raw is! Iterable) return const <String>[];
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    final catCode =
        json['categoryCode']?.toString().trim() ?? 'pipe_welding_fab';
    final cat = PipeBuyerShopTaxonomy.categoryByCode(catCode);
    final mktCats = strList(json['marketplaceCategories']);

    return PipeBuyerShopProduct(
      id: json['id']?.toString().trim() ?? '',
      title: json['title']?.toString().trim() ?? 'Industrial Product',
      brand: json['brand']?.toString().trim() ?? 'Industrial Select',
      vendorName: json['vendorName']?.toString().trim() ?? 'Amazon',
      sourceType:
          PipeBuyerShopSourceType.fromCode(json['sourceType']?.toString()),
      categoryCode: cat != null ? catCode : 'pipe_welding_fab',
      destinationUrl: json['destinationUrl']?.toString().trim() ?? '',
      destinationUrlCa: json['destinationUrlCa']?.toString().trim() ?? '',
      asin: json['asin']?.toString().trim() ?? '',
      subcategory: json['subcategory']?.toString().trim() ?? '',
      description: json['description']?.toString().trim() ?? '',
      imageUrl: json['imageUrl']?.toString().trim() ?? '',
      fallbackIconAsset: json['fallbackIconAsset']?.toString().trim() ?? '',
      priceDisplay: json['priceDisplay']?.toString().trim() ?? '',
      badgeText: json['badgeText']?.toString().trim() ?? '',
      ctaLabel: json['ctaLabel']?.toString().trim() ?? '',
      featured: json['featured'] == true,
      priorityRank: (json['priorityRank'] as num?)?.toInt() ?? 100,
      status: json['status']?.toString().trim() ?? 'active',
      highlights: strList(json['highlights']),
      tags: strList(json['tags']),
      marketplaceCategories: mktCats.isNotEmpty
          ? mktCats
          : (cat?.marketplaceCategories ?? const <String>[]),
      clickCount: (json['clickCount'] as num?)?.toInt() ?? 0,
      isStarterSeed: json['isStarterSeed'] == true,
    );
  }

  Map<String, Object?> toUpsertPayload() => <String, Object?>{
        'id': id,
        'title': title,
        'brand': brand,
        'vendorName': vendorName,
        'sourceType': sourceType.code,
        'status': status,
        'categoryCode': categoryCode,
        'subcategory': subcategory,
        'description': description,
        'asin': asin,
        'destinationUrl': destinationUrl,
        'destinationUrlCa': destinationUrlCa,
        'imageUrl': imageUrl,
        'fallbackIconAsset': effectiveIconAsset,
        'priceDisplay': priceDisplay,
        'badgeText': badgeText,
        'ctaLabel': effectiveCtaLabel,
        'featured': featured,
        'priorityRank': priorityRank,
        'highlights': highlights,
        'tags': tags,
        'marketplaceCategories': marketplaceCategories,
      };
}

@immutable
class PipeBuyerPartnerSpotlight {
  const PipeBuyerPartnerSpotlight({
    required this.id,
    required this.name,
    required this.channelLabel,
    required this.description,
    required this.statusLabel,
    required this.accentColor,
    required this.icon,
    this.filterBrand,
    this.filterSource,
    this.opensVendorPortal = false,
  });

  final String id;
  final String name;
  final String channelLabel;
  final String description;
  final String statusLabel;
  final Color accentColor;
  final IconData icon;
  final String? filterBrand;
  final PipeBuyerShopSourceType? filterSource;
  final bool opensVendorPortal;
}

abstract final class PipeBuyerShopUrlBuilder {
  static String extractAmazonAsin(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (RegExp(r'^[A-Za-z0-9]{10}$').hasMatch(trimmed)) {
      return trimmed.toUpperCase();
    }
    final patterns = <RegExp>[
      RegExp(r'/dp/([A-Za-z0-9]{10})(?:[/?#]|$)', caseSensitive: false),
      RegExp(r'/gp/product/([A-Za-z0-9]{10})(?:[/?#]|$)', caseSensitive: false),
      RegExp(r'/gp/aw/d/([A-Za-z0-9]{10})(?:[/?#]|$)', caseSensitive: false),
      RegExp(r'/product/([A-Za-z0-9]{10})(?:[/?#]|$)', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(trimmed);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.toUpperCase();
      }
    }
    return '';
  }

  static bool isSafeHttpsUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'https') return false;
    if (uri.userInfo.isNotEmpty) return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty ||
        !host.contains('.') ||
        host == 'localhost' ||
        host.endsWith('.local') ||
        host.endsWith('.localhost')) {
      return false;
    }
    final ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
        .firstMatch(host);
    if (ipv4 != null) {
      final a = int.tryParse(ipv4.group(1)!) ?? 0;
      final b = int.tryParse(ipv4.group(2)!) ?? 0;
      if (a == 10 || a == 127 || a == 0) return false;
      if (a == 169 && b == 254) return false;
      if (a == 192 && b == 168) return false;
      if (a == 172 && b >= 16 && b <= 31) return false;
    }
    return true;
  }

  static bool _hostMatches(String host, List<String> candidates) {
    final h = host.toLowerCase();
    for (final c in candidates) {
      if (h == c || h.endsWith('.$c')) return true;
    }
    return false;
  }

  static bool _isAmazonHost(String host) => _hostMatches(host, const <String>[
        'amazon.com',
        'amazon.ca',
        'amazon.co.uk',
        'amazon.com.au',
        'amazon.sg',
        'amazon.de',
        'amazon.co.jp',
        'amazon.ae',
        'amazon.sa',
        'amazon.com.mx',
        'amazon.com.br',
      ]);

  static bool _isAmazonShortHost(String host) =>
      _hostMatches(host, const <String>['amzn.to', 'a.co', 'link.amazon']);

  static ({
    String platformId,
    String platformName,
    PipeBuyerShopSourceType sourceType,
    String vendorName,
    bool isShortLink,
  }) detectPlatform(String host, [String path = '']) {
    final h = host.toLowerCase();
    if (_isAmazonShortHost(h)) {
      return (
        platformId: 'amazon_associates',
        platformName: 'Amazon',
        sourceType: PipeBuyerShopSourceType.amazonAffiliate,
        vendorName: 'Amazon',
        isShortLink: true,
      );
    }
    if (_isAmazonHost(h)) {
      return (
        platformId: 'amazon_associates',
        platformName: 'Amazon',
        sourceType: PipeBuyerShopSourceType.amazonAffiliate,
        vendorName: 'Amazon',
        isShortLink: false,
      );
    }
    if (_hostMatches(h, const <String>['s.click.aliexpress.com', 'ali.ski'])) {
      return (
        platformId: 'aliexpress_portals',
        platformName: 'AliExpress',
        sourceType: PipeBuyerShopSourceType.aliexpressAffiliate,
        vendorName: 'AliExpress',
        isShortLink: true,
      );
    }
    if (_hostMatches(h,
        const <String>['aliexpress.com', 'aliexpress.us', 'aliexpress.ru'])) {
      return (
        platformId: 'aliexpress_portals',
        platformName: 'AliExpress',
        sourceType: PipeBuyerShopSourceType.aliexpressAffiliate,
        vendorName: 'AliExpress',
        isShortLink: false,
      );
    }
    final isShopeeShort = _hostMatches(h, const <String>[
      'shope.ee',
      'shp.ee',
      's.shopee.ph',
      's.shopee.sg',
      's.shopee.com.my',
      's.shopee.co.th',
      's.shopee.vn',
      's.shopee.co.id',
      's.shopee.tw',
      's.shopee.com.br',
    ]);
    if (isShopeeShort ||
        _hostMatches(h, const <String>[
          'shopee.com',
          'shopee.ph',
          'shopee.sg',
          'shopee.com.my',
          'shopee.co.th',
          'shopee.vn',
          'shopee.co.id',
          'shopee.tw',
          'shopee.com.br',
          'shopee.com.mx',
        ])) {
      return (
        platformId: 'shopee_affiliate',
        platformName: 'Shopee',
        sourceType: PipeBuyerShopSourceType.shopeeAffiliate,
        vendorName: 'Shopee',
        isShortLink: isShopeeShort,
      );
    }
    final isLazadaShort = _hostMatches(h, const <String>[
          's.lazada.com.ph',
          's.lazada.sg',
          's.lazada.com.my',
          's.lazada.co.th',
          's.lazada.vn',
          's.lazada.co.id',
          'c.lazada.com.ph',
          'c.lazada.sg',
          'c.lazada.com.my',
        ]) ||
        path.startsWith('/s.');
    if (isLazadaShort ||
        _hostMatches(h, const <String>[
          'lazada.com',
          'lazada.com.ph',
          'lazada.sg',
          'lazada.com.my',
          'lazada.co.th',
          'lazada.vn',
          'lazada.co.id',
        ])) {
      return (
        platformId: 'lazada_lazaffiliate',
        platformName: 'Lazada',
        sourceType: PipeBuyerShopSourceType.lazadaAffiliate,
        vendorName: 'Lazada',
        isShortLink: isLazadaShort,
      );
    }
    if (_hostMatches(h, const <String>['invol.co', 'invl.io', 'invle.co'])) {
      return (
        platformId: 'involve_asia',
        platformName: 'Involve Asia',
        sourceType: PipeBuyerShopSourceType.affiliateNetwork,
        vendorName: 'Verified Marketplace Partner',
        isShortLink: true,
      );
    }
    final isEbayShort = _hostMatches(h, const <String>['ebay.us', 'ebay.to']);
    if (isEbayShort ||
        _hostMatches(h, const <String>[
          'ebay.com',
          'ebay.ca',
          'ebay.co.uk',
          'ebay.com.au',
          'ebay.ph',
          'ebay.com.sg',
          'ebay.com.my',
        ])) {
      return (
        platformId: 'ebay_partner_network',
        platformName: 'eBay',
        sourceType: PipeBuyerShopSourceType.ebayPartner,
        vendorName: 'eBay',
        isShortLink: isEbayShort,
      );
    }
    if (_hostMatches(
        h, const <String>['walmart.com', 'walmart.ca', 'goto.walmart.com'])) {
      return (
        platformId: 'walmart_affiliate',
        platformName: 'Walmart',
        sourceType: PipeBuyerShopSourceType.walmartAffiliate,
        vendorName: 'Walmart',
        isShortLink: h == 'goto.walmart.com',
      );
    }
    if (_hostMatches(h, const <String>['temu.com', 'temu.to'])) {
      return (
        platformId: 'temu_affiliate',
        platformName: 'Temu',
        sourceType: PipeBuyerShopSourceType.temuAffiliate,
        vendorName: 'Temu',
        isShortLink: h == 'temu.to' || h.endsWith('.temu.to'),
      );
    }
    if (_hostMatches(
        h, const <String>['tiktok.com', 'vt.tiktok.com', 'vm.tiktok.com'])) {
      return (
        platformId: 'tiktok_shop_affiliate',
        platformName: 'TikTok Shop',
        sourceType: PipeBuyerShopSourceType.tiktokShopAffiliate,
        vendorName: 'TikTok Shop',
        isShortLink: h == 'vt.tiktok.com' || h == 'vm.tiktok.com',
      );
    }
    if (_hostMatches(h, const <String>[
      'alibaba.com',
      's.click.alibaba.com',
      'dhgate.com',
      'dhg.to'
    ])) {
      final dhgate = h.contains('dhg');
      return (
        platformId: 'alibaba_dhgate_b2b',
        platformName: dhgate ? 'DHgate' : 'Alibaba',
        sourceType: PipeBuyerShopSourceType.alibabaB2b,
        vendorName: dhgate ? 'DHgate' : 'Alibaba',
        isShortLink: h == 's.click.alibaba.com' || h == 'dhg.to',
      );
    }
    if (_hostMatches(h, const <String>[
      'pxf.io',
      'sjv.io',
      '7eer.net',
      'evyy.net',
      'ojrq.net',
      'dpbolvw.net',
      'anrdoezrs.net',
      'jdoqocy.com',
      'tkqlhce.com',
      'kqzyfj.com',
      'shareasale.com',
      'shrsl.com',
      'awin1.com',
      'click.linksynergy.com',
      'go.redirectingat.com',
      'redirect.viglink.com',
      'partnerstack.com',
      'psxid.com',
      'flexoffers.com',
      'avantlink.com',
    ])) {
      return (
        platformId: 'affiliate_network',
        platformName: 'Affiliate Network',
        sourceType: PipeBuyerShopSourceType.affiliateNetwork,
        vendorName: 'Authorized Partner',
        isShortLink: true,
      );
    }
    const proRetail = <(List<String>, String)>[
      (<String>['vevor.com', 'vevor.ca'], 'VEVOR'),
      (<String>['homedepot.com', 'homedepot.ca', 'thd.co'], 'Home Depot'),
      (<String>['lowes.com', 'lowes.ca'], "Lowe's"),
      (<String>['tractorsupply.com'], 'Tractor Supply'),
      (<String>['northerntool.com'], 'Northern Tool'),
      (<String>['acmetools.com'], 'Acme Tools'),
      (<String>['zoro.com'], 'Zoro'),
      (<String>['grainger.com'], 'Grainger'),
      (<String>['bakersgas.com'], "Baker's Gas"),
      (<String>['etrailer.com'], 'etrailer'),
      (<String>['bootbarn.com'], 'Boot Barn'),
      (<String>['princessauto.com'], 'Princess Auto'),
      (<String>['canadiantire.ca'], 'Canadian Tire'),
    ];
    for (final entry in proRetail) {
      if (_hostMatches(h, entry.$1)) {
        return (
          platformId: 'hardware_pro_retail',
          platformName: entry.$2,
          sourceType: PipeBuyerShopSourceType.hardwareProRetail,
          vendorName: entry.$2,
          isShortLink: h == 'thd.co',
        );
      }
    }
    return (
      platformId: 'brand_partner',
      platformName: 'Brand Partner',
      sourceType: PipeBuyerShopSourceType.brandPartner,
      vendorName: '',
      isShortLink: false,
    );
  }

  static String _resolveTagForHost(
      String host, PipeBuyerShopSettings settings) {
    final h = host.toLowerCase();
    if (h == 'amazon.ca' || h.endsWith('.amazon.ca')) {
      return settings.amazonAssociateTagCa.isNotEmpty
          ? settings.amazonAssociateTagCa
          : settings.amazonAssociateTagUs;
    }
    if (h == 'amazon.co.uk' || h.endsWith('.amazon.co.uk')) {
      return settings.amazonAssociateTagUk.isNotEmpty
          ? settings.amazonAssociateTagUk
          : settings.amazonAssociateTagUs;
    }
    if (h == 'amazon.com.au' || h.endsWith('.amazon.com.au')) {
      return settings.amazonAssociateTagAu.isNotEmpty
          ? settings.amazonAssociateTagAu
          : settings.amazonAssociateTagUs;
    }
    if (h == 'amazon.sg' || h.endsWith('.amazon.sg')) {
      return settings.amazonAssociateTagSg.isNotEmpty
          ? settings.amazonAssociateTagSg
          : settings.amazonAssociateTagUs;
    }
    return settings.amazonAssociateTagUs;
  }

  static String buildMonetizedUrl(
    PipeBuyerShopProduct product,
    PipeBuyerShopSettings settings, {
    String regionCode = 'US',
  }) {
    final upperRegion = regionCode.trim().toUpperCase();
    final asin = extractAmazonAsin(
      product.asin.isNotEmpty ? product.asin : product.destinationUrl,
    );

    var rawUrl = product.destinationUrl.trim();
    if (upperRegion == 'CA' && product.destinationUrlCa.trim().isNotEmpty) {
      rawUrl = product.destinationUrlCa.trim();
    } else if (rawUrl.isEmpty && asin.isNotEmpty) {
      final host = upperRegion == 'CA' ? 'www.amazon.ca' : 'www.amazon.com';
      rawUrl = 'https://$host/dp/$asin';
    }

    if (!isSafeHttpsUrl(rawUrl)) return '';
    final uri = Uri.parse(rawUrl);
    final detected = detectPlatform(uri.host, uri.path);

    if (_isAmazonShortHost(uri.host)) {
      return uri.toString();
    }

    if (product.sourceType == PipeBuyerShopSourceType.amazonAffiliate ||
        _isAmazonHost(uri.host)) {
      var targetHost = uri.host;
      if (upperRegion == 'CA' &&
          product.destinationUrlCa.trim().isEmpty &&
          targetHost.toLowerCase().endsWith('amazon.com')) {
        targetHost = 'www.amazon.ca';
      }
      final tag = _resolveTagForHost(targetHost, settings).trim();
      final params = Map<String, String>.from(uri.queryParameters);
      final existingTag = (params['tag'] ?? '').trim();
      if (tag.isNotEmpty &&
          (existingTag.isEmpty || settings.forceOverrideAmazonTag)) {
        params['tag'] = tag;
      }
      return uri
          .replace(
            host: targetHost,
            queryParameters: params.isEmpty ? null : params,
          )
          .toString();
    }

    if (detected.platformId == 'involve_asia') {
      final sub = settings.involveAsiaSubId.trim();
      if (sub.isNotEmpty &&
          !uri.queryParameters.containsKey('subid') &&
          !uri.queryParameters.containsKey('aff_sub')) {
        final params = Map<String, String>.from(uri.queryParameters);
        params['subid'] = sub;
        return uri.replace(queryParameters: params).toString();
      }
      return uri.toString();
    }

    if (detected.isShortLink) {
      return uri.toString();
    }

    final campaign = product.categoryCode.isNotEmpty
        ? product.categoryCode
        : 'pipebuyer_shop';
    final params = Map<String, String>.from(uri.queryParameters);

    if (detected.platformId == 'aliexpress_portals' ||
        product.sourceType == PipeBuyerShopSourceType.aliexpressAffiliate) {
      final aliKey = settings.aliexpressTrackingId.trim();
      if (aliKey.isNotEmpty &&
          !params.containsKey('aff_fcid') &&
          !params.containsKey('sk')) {
        params['aff_platform'] = 'portals-tool';
        params['sk'] = aliKey;
      }
      params.putIfAbsent('af', () => campaign);
      return uri.replace(queryParameters: params).toString();
    }

    if (detected.platformId == 'shopee_affiliate' ||
        product.sourceType == PipeBuyerShopSourceType.shopeeAffiliate) {
      final rawSub = settings.shopeeAffiliateSubId
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      if (rawSub.isNotEmpty && !params.containsKey('sub_id')) {
        params['sub_id'] = rawSub;
      }
      params.putIfAbsent(
        'utm_source',
        () => settings.defaultUtmSource.isNotEmpty
            ? settings.defaultUtmSource
            : 'pipebuyer',
      );
      return uri.replace(queryParameters: params).toString();
    }

    if (detected.platformId == 'lazada_lazaffiliate' ||
        product.sourceType == PipeBuyerShopSourceType.lazadaAffiliate) {
      final lazSub = settings.lazadaAffiliateSubId.trim();
      if (lazSub.isNotEmpty &&
          !params.containsKey('aff_sub') &&
          !params.containsKey('sub_id')) {
        params['aff_sub'] = lazSub;
      }
      params.putIfAbsent(
        'utm_source',
        () => settings.defaultUtmSource.isNotEmpty
            ? settings.defaultUtmSource
            : 'pipebuyer',
      );
      return uri.replace(queryParameters: params).toString();
    }

    if (detected.platformId == 'ebay_partner_network' ||
        product.sourceType == PipeBuyerShopSourceType.ebayPartner) {
      final campId = settings.ebayCampaignId.trim();
      if (campId.isNotEmpty && !params.containsKey('campid')) {
        final h = uri.host.toLowerCase();
        params['mkcid'] = '1';
        params['mkrid'] = h.endsWith('ebay.ca')
            ? '706-53473-19255-0'
            : h.endsWith('ebay.co.uk')
                ? '710-53481-19255-0'
                : h.endsWith('ebay.com.au')
                    ? '705-53470-19255-0'
                    : '711-53200-19255-0';
        params['campid'] = campId;
        params['toolid'] = '10001';
        params['customid'] = campaign;
      }
      return uri.replace(queryParameters: params).toString();
    }

    params.putIfAbsent(
      'utm_source',
      () => settings.defaultUtmSource.isNotEmpty
          ? settings.defaultUtmSource
          : 'pipebuyer',
    );
    params.putIfAbsent(
      'utm_medium',
      () => settings.defaultUtmMedium.isNotEmpty
          ? settings.defaultUtmMedium
          : 'affiliate_store',
    );
    params.putIfAbsent('utm_campaign', () => campaign);
    return uri.replace(queryParameters: params).toString();
  }

  static const List<String> _knownBrands = <String>[
    'Lincoln Electric',
    'BW Technologies',
    'Klein Tools',
    'Milwaukee',
    'RIDGID',
    'DeWalt',
    'DEWALT',
    'Miller',
    'Carhartt',
    'Crosby',
    'Fluke',
    'Ariat',
    'Honeywell',
    'MSA',
    'Starrett',
    'Makita',
    'Bosch',
    'Knipex',
    'Proto',
    'Enerpac',
    'Fill-Rite',
    'Honda',
    'Pelican',
    'Midland',
    'Gallagher',
    'Sumner',
    'ESAB',
    'Hobart',
    'VEVOR',
    'Ingco',
    'Total Tools',
    'Stanley',
  ];

  static String decodeHtmlEntities(String raw) {
    return raw
        .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&')
        .replaceAll(RegExp(r'&quot;', caseSensitive: false), '"')
        .replaceAll(RegExp(r'&#39;|&apos;', caseSensitive: false), "'")
        .replaceAll(RegExp(r'&lt;', caseSensitive: false), '<')
        .replaceAll(RegExp(r'&gt;', caseSensitive: false), '>');
  }

  static String inferBrand(String text) {
    final lower = text.toLowerCase();
    if (lower.isEmpty) return '';
    for (final brand in _knownBrands) {
      final escaped = RegExp.escape(brand.toLowerCase());
      if (RegExp('(?:^|[^a-z0-9])$escaped(?:\$|[^a-z0-9])').hasMatch(lower)) {
        return brand == 'DEWALT' ? 'DeWalt' : brand;
      }
    }
    return '';
  }

  static String inferCategoryCode(String text) {
    final lower = text.toLowerCase();
    if (lower.isEmpty) return 'power_hand_tools';
    if (RegExp(
      r'\b(chain|binder|shackle|sling|rigging|winch|cargo|strap|tie[- ]down|clevis|tow)\b',
    ).hasMatch(lower)) {
      return 'rigging_hauling_cargo';
    }
    if (RegExp(
      r'\b(weld|welding|welder|tig|mig|stick|pipe wrench|straight wrench|ridgid|chain vise|tristand|bevel|flange|threader|threading|torch)\b',
    ).hasMatch(lower)) {
      return 'pipe_welding_fab';
    }
    if (RegExp(
      r'\b(fr\b|flame[- ]resistant|hardhat|hard hat|h2s|gas monitor|gas detector|gloves?|boots?|respirators?|ppe|eyewear|safety|harness|fall protection|spill)\b',
    ).hasMatch(lower)) {
      return 'ppe_fr_safety';
    }
    if (RegExp(
      r'\b(grease gun|transfer pump|diesel|fuel|hydraulic|hose|jump starter|oil filter|lubricat)\b',
    ).hasMatch(lower)) {
      return 'hydraulics_fleet_shop';
    }
    if (RegExp(
      r'\b(work light|floodlight|lantern|headlamp|generator|inverter|extension cord|radio|jobsite box)\b',
    ).hasMatch(lower)) {
      return 'lighting_power_jobsite';
    }
    if (RegExp(
      r'\b(ultrasonic|thickness gauge|caliper|micrometer|laser level|thermal|multimeter|clamp meter|pressure test|thread gauge)\b',
    ).hasMatch(lower)) {
      return 'measuring_inspection';
    }
    if (RegExp(
      r'\b(fence|fencing|post driver|ranch|livestock|gate latch|hinge|t-post|cattle)\b',
    ).hasMatch(lower)) {
      return 'ranch_fencing_ag';
    }
    return 'power_hand_tools';
  }

  static String _extractSlugTitle(Uri uri) {
    final match = RegExp(
      r'^/([^/]+)/(?:dp|gp/product)/[A-Za-z0-9]{10}',
      caseSensitive: false,
    ).firstMatch(uri.path);
    if (match != null && match.group(1) != null) {
      final slug = Uri.decodeComponent(match.group(1)!).trim();
      if (slug.isNotEmpty &&
          slug.toLowerCase() != 'dp' &&
          slug.toLowerCase() != 'gp') {
        return slug
            .replaceAll(RegExp(r'[-_]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }
    }
    for (final rawSeg in uri.pathSegments) {
      if (rawSeg.isEmpty) continue;
      final cleaned = rawSeg
          .replaceFirst(RegExp(r'\.html?$', caseSensitive: false), '')
          .replaceFirst(RegExp(r'-i\.\d+\.\d+$', caseSensitive: false), '')
          .replaceFirst(RegExp(r'-s\d+$', caseSensitive: false), '');
      if (RegExp(r'^(?:dp|gp|product|products|item|itm|ip|p|e|s|d|c)$',
              caseSensitive: false)
          .hasMatch(cleaned)) {
        continue;
      }
      if (RegExp(r'^\d{6,}$').hasMatch(cleaned)) continue;
      if (cleaned.contains('-') &&
          RegExp(r'[a-zA-Z]{3,}').hasMatch(cleaned) &&
          cleaned.length >= 8) {
        return cleaned
            .replaceAll(RegExp(r'[-_]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }
    }
    return '';
  }

  /// Parses affiliate submissions across Amazon, AliExpress, Lazada, Shopee,
  /// Involve Asia, eBay, Walmart, Temu, TikTok Shop, Alibaba/DHgate, VEVOR,
  /// Home Depot, Impact/CJ/ShareASale/Skimlinks, HTML snippets, and ASINs.
  static PipeBuyerParsedAffiliateSubmission? parseAffiliateSubmission(
    String rawInput,
    PipeBuyerShopSettings settings,
  ) {
    final decoded = decodeHtmlEntities(rawInput).trim();
    if (decoded.isEmpty) return null;

    if (RegExp(r'^[A-Za-z0-9]{10}$').hasMatch(decoded)) {
      final asin = decoded.toUpperCase();
      final baseUrl = 'https://www.amazon.com/dp/$asin';
      final draft = PipeBuyerShopProduct(
        id: 'draft',
        title: 'Draft',
        brand: '',
        vendorName: 'Amazon',
        sourceType: PipeBuyerShopSourceType.amazonAffiliate,
        categoryCode: 'power_hand_tools',
        asin: asin,
        destinationUrl: baseUrl,
      );
      return PipeBuyerParsedAffiliateSubmission(
        destinationUrl: baseUrl,
        asin: asin,
        sourceType: PipeBuyerShopSourceType.amazonAffiliate,
        platformName: 'Amazon',
        suggestedVendorName: 'Amazon',
        suggestedTitle: '',
        suggestedBrand: '',
        suggestedCategoryCode: 'power_hand_tools',
        imageUrl: '',
        isAmazonLink: true,
        isShortLink: false,
        embeddedAssociateTag: '',
        effectiveAssociateTag: settings.amazonAssociateTagUs.trim(),
        monetizedPreviewUs:
            buildMonetizedUrl(draft, settings, regionCode: 'US'),
        monetizedPreviewCa:
            buildMonetizedUrl(draft, settings, regionCode: 'CA'),
      );
    }

    var extractedHref = '';
    var extractedImg = '';
    var anchorTitle = '';

    final hrefMatch = RegExp(
      r'''href\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (hrefMatch != null && hrefMatch.group(1) != null) {
      extractedHref = hrefMatch.group(1)!.trim();
    }

    final imgMatch = RegExp(
      r'''<img[^>]*\ssrc\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (imgMatch != null && imgMatch.group(1) != null) {
      var candidate = imgMatch.group(1)!.trim();
      if (candidate.startsWith('//')) candidate = 'https:$candidate';
      if (isSafeHttpsUrl(candidate) &&
          !RegExp(
            r'ir-na\.amazon-adsystem\.com|assoc-amazon\.com',
            caseSensitive: false,
          ).hasMatch(candidate)) {
        extractedImg = candidate;
      }
    }

    final anchorMatch = RegExp(
      r'<a[^>]*>([\s\S]*?)</a>',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (anchorMatch != null && anchorMatch.group(1) != null) {
      anchorTitle = anchorMatch
          .group(1)!
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    var surroundingText = '';
    if (extractedHref.isEmpty) {
      final urlMatch = RegExp(
        r'''https?://[^\s"'<>]+''',
        caseSensitive: false,
      ).firstMatch(decoded);
      if (urlMatch != null && urlMatch.group(0) != null) {
        final rawMatched = urlMatch.group(0)!;
        extractedHref = rawMatched.replaceFirst(RegExp(r'[),.;!?]+$'), '');
        surroundingText = decoded
            .replaceFirst(rawMatched, ' ')
            .replaceFirst(
              RegExp(
                r'^(check (?:this )?out(?:\s+on\s+[a-z0-9.]+)?|just found this amazing item on aliexpress|deal(?:\s+of\s+the\s+day)?|amazon(?:\.com|\.ca)?|shopee|lazada|aliexpress)[\s:,-]*',
                caseSensitive: false,
              ),
              '',
            )
            .replaceAll(RegExp(r'#\w+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      } else {
        extractedHref = decoded;
      }
    }

    if (RegExp(
      r'^http://(?:www\.)?(?:amazon\.|amzn\.to|a\.co|link\.amazon|aliexpress\.|s\.click\.aliexpress\.com|shopee\.|shope\.ee|s\.shopee\.|lazada\.|s\.lazada\.|invol\.co|invl\.io|ebay\.|walmart\.|temu\.|vevor\.)',
      caseSensitive: false,
    ).hasMatch(extractedHref)) {
      extractedHref = extractedHref.replaceFirst(
        RegExp(r'^http://', caseSensitive: false),
        'https://',
      );
    } else if (RegExp(
      r'^(?:www\.)?(?:amazon\.com|amazon\.ca|amzn\.to|a\.co|link\.amazon|aliexpress\.com|s\.click\.aliexpress\.com|shopee\.|shope\.ee|lazada\.|invol\.co|ebay\.com|vevor\.com)/',
      caseSensitive: false,
    ).hasMatch(extractedHref)) {
      extractedHref = 'https://$extractedHref';
    }

    if (!isSafeHttpsUrl(extractedHref)) return null;
    final uri = Uri.parse(extractedHref);
    final detected = detectPlatform(uri.host, uri.path);
    final isShort = detected.isShortLink;
    final isFullAmazon = _isAmazonHost(uri.host);
    final isAmazon = _isAmazonShortHost(uri.host) || isFullAmazon;
    final sourceType = detected.sourceType;
    final asin = isAmazon ? extractAmazonAsin(uri.toString()) : '';
    final slugTitle = !isShort ? _extractSlugTitle(uri) : '';
    final suggestedTitle = anchorTitle.isNotEmpty
        ? anchorTitle
        : (surroundingText.isNotEmpty ? surroundingText : slugTitle);
    final hintText = [suggestedTitle, slugTitle, uri.path]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final suggestedBrand = inferBrand(hintText);
    final suggestedCategory = inferCategoryCode(hintText);

    final embeddedTag = (uri.queryParameters['tag'] ??
            uri.queryParameters['sk'] ??
            uri.queryParameters['sub_id'] ??
            uri.queryParameters['aff_sub'] ??
            uri.queryParameters['subid'] ??
            uri.queryParameters['campid'] ??
            '')
        .trim();
    final storeTag = _resolveTagForHost(uri.host, settings).trim();
    final effectiveTag = isAmazon
        ? (_isAmazonShortHost(uri.host)
            ? 'Embedded in Amazon Short Link (${uri.host})'
            : ((embeddedTag.isNotEmpty && !settings.forceOverrideAmazonTag)
                ? embeddedTag
                : storeTag))
        : (isShort
            ? 'Embedded in ${detected.platformName} Affiliate Link (${uri.host})'
            : (embeddedTag.isNotEmpty
                ? embeddedTag
                : '${detected.platformName} Auto-Attribution'));

    final suggestedVendor = detected.vendorName.isNotEmpty
        ? detected.vendorName
        : (suggestedBrand.isNotEmpty ? suggestedBrand : detected.platformName);

    final draft = PipeBuyerShopProduct(
      id: 'draft',
      title: suggestedTitle.isEmpty ? 'Draft' : suggestedTitle,
      brand: suggestedBrand,
      vendorName: suggestedVendor,
      sourceType: sourceType,
      categoryCode: suggestedCategory,
      asin: asin,
      destinationUrl: uri.toString(),
    );

    return PipeBuyerParsedAffiliateSubmission(
      destinationUrl: uri.toString(),
      asin: asin,
      sourceType: sourceType,
      platformName: detected.platformName,
      suggestedVendorName: suggestedVendor,
      suggestedTitle: suggestedTitle,
      suggestedBrand: suggestedBrand,
      suggestedCategoryCode: suggestedCategory,
      imageUrl: extractedImg,
      isAmazonLink: isAmazon,
      isShortLink: isShort,
      embeddedAssociateTag: embeddedTag,
      effectiveAssociateTag: effectiveTag,
      monetizedPreviewUs: buildMonetizedUrl(draft, settings, regionCode: 'US'),
      monetizedPreviewCa: buildMonetizedUrl(draft, settings, regionCode: 'CA'),
    );
  }
}

@immutable
class PipeBuyerParsedAffiliateSubmission {
  const PipeBuyerParsedAffiliateSubmission({
    required this.destinationUrl,
    required this.asin,
    required this.sourceType,
    required this.suggestedTitle,
    required this.suggestedBrand,
    required this.suggestedCategoryCode,
    required this.imageUrl,
    required this.isAmazonLink,
    required this.isShortLink,
    required this.embeddedAssociateTag,
    required this.effectiveAssociateTag,
    required this.monetizedPreviewUs,
    required this.monetizedPreviewCa,
    this.platformName = 'Amazon',
    this.suggestedVendorName = 'Amazon',
  });

  final String destinationUrl;
  final String asin;
  final PipeBuyerShopSourceType sourceType;
  final String platformName;
  final String suggestedVendorName;
  final String suggestedTitle;
  final String suggestedBrand;
  final String suggestedCategoryCode;
  final String imageUrl;
  final bool isAmazonLink;
  final bool isShortLink;
  final String embeddedAssociateTag;
  final String effectiveAssociateTag;
  final String monetizedPreviewUs;
  final String monetizedPreviewCa;
}

abstract final class PipeBuyerShopTaxonomy {
  static const List<PipeBuyerAffiliatePlatformInfo>
      affiliatePlatformsDirectory = <PipeBuyerAffiliatePlatformInfo>[
    PipeBuyerAffiliatePlatformInfo(
      id: 'amazon_associates',
      name: 'Amazon Associates (Global & OneLink)',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      regions: 'US, CA, UK, AU, SG, UAE, KSA, EU, JP, MX, BR',
      commissionRange: '3% – 10% (4.5%+ Industrial & Tools)',
      cookieWindow: '24 hours (90 days add-to-cart)',
      signupUrl: 'https://affiliate-program.amazon.com/',
      trackingHint: 'SiteStripe amzn.to shortlink or ?tag=pipebuyer-20',
      bestFor:
          'Milwaukee, RIDGID, Lincoln Electric, Crosby shackles, FR workwear & jobsite gear.',
      sampleDomains: <String>[
        'amazon.com',
        'amazon.ca',
        'amazon.sg',
        'amzn.to'
      ],
    ),
    PipeBuyerAffiliatePlatformInfo(
      id: 'aliexpress_portals',
      name: 'AliExpress Portals Affiliate Program',
      sourceType: PipeBuyerShopSourceType.aliexpressAffiliate,
      regions: 'Global (200+ Countries)',
      commissionRange: '3% – 9% standard • up to 50% Hot Products',
      cookieWindow: '3 days',
      signupUrl: 'https://portals.aliexpress.com/',
      trackingHint:
          's.click.aliexpress.com/e/... or AliExpress Tracking Key (sk=)',
      bestFor:
          'Ultrasonic pipe thickness gauges, welding positioners, hydraulic crimpers, laser levels & carbide tooling.',
      sampleDomains: <String>['aliexpress.com', 's.click.aliexpress.com'],
    ),
    PipeBuyerAffiliatePlatformInfo(
      id: 'shopee_affiliate',
      name: 'Shopee Affiliate Program',
      sourceType: PipeBuyerShopSourceType.shopeeAffiliate,
      regions: 'PH, SG, MY, TH, VN, ID, TW, BR, MX',
      commissionRange: '2% – 14%+ (Shopee Mall & Extra Comm Sellers)',
      cookieWindow: '7 days',
      signupUrl: 'https://affiliate.shopee.ph/',
      trackingHint:
          'shope.ee/... or s.shopee.* shortlink or alphanumeric ?sub_id=',
      bestFor:
          'Power tools (Bosch, Makita, Ingco, Total), welding helmets, PPE, safety boots & fleet accessories across SEA & LATAM.',
      sampleDomains: <String>[
        'shopee.ph',
        'shopee.sg',
        'shopee.com.my',
        'shope.ee'
      ],
    ),
    PipeBuyerAffiliatePlatformInfo(
      id: 'lazada_lazaffiliate',
      name: 'Lazada Affiliate Program (LazAffiliate)',
      sourceType: PipeBuyerShopSourceType.lazadaAffiliate,
      regions: 'PH, SG, MY, TH, VN, ID',
      commissionRange: '4% – 12% standard • up to 40% Sponsored LazMall',
      cookieWindow: '7 days',
      signupUrl:
          'https://pages.lazada.com.ph/wow/gcp/lazada/channel/ph/marketing/affiliate',
      trackingHint: 's.lazada.* / c.lazada.* shortlink or ?aff_sub=',
      bestFor:
          'LazMall official brand stores for heavy-duty tools, generators, inverters, work lights & shop equipment.',
      sampleDomains: <String>[
        'lazada.com.ph',
        'lazada.sg',
        'lazada.com.my',
        's.lazada.com.ph'
      ],
    ),
    PipeBuyerAffiliatePlatformInfo(
      id: 'involve_asia',
      name: 'Involve Asia (Unified Multi-Platform Hub)',
      sourceType: PipeBuyerShopSourceType.affiliateNetwork,
      regions: 'Southeast Asia & Global (500+ Brands)',
      commissionRange:
          '2% – 18% across Shopee, Lazada, AliExpress, TikTok & Zalora',
      cookieWindow: '7 – 30 days',
      signupUrl: 'https://involve.asia/',
      trackingHint: 'invol.co/... or invl.io/... deeplink with ?subid=',
      bestFor:
          'Single-wallet payouts combining Shopee, Lazada, AliExpress, TikTok Shop, Agoda (crew hotels) & hardware merchants.',
      sampleDomains: <String>['invol.co', 'invl.io'],
    ),
    PipeBuyerAffiliatePlatformInfo(
      id: 'ebay_partner_network',
      name: 'eBay Partner Network (EPN)',
      sourceType: PipeBuyerShopSourceType.ebayPartner,
      regions: 'US, CA, UK, AU, DE, Global',
      commissionRange: '1.5% – 4% (Business & Industrial MRO)',
      cookieWindow: '24 hours',
      signupUrl: 'https://partnernetwork.ebay.com/',
      trackingHint:
          'ebay.us/... shortlink or EPN 10-digit Campaign ID (?campid=)',
      bestFor:
          'Surplus oilfield valves, pipe bevelers, RIDGID threaders, Fluke test meters & hard-to-find industrial parts.',
      sampleDomains: <String>['ebay.com', 'ebay.ca', 'ebay.us'],
    ),
    PipeBuyerAffiliatePlatformInfo(
      id: 'vevor_affiliate',
      name: 'VEVOR Official Affiliate Program',
      sourceType: PipeBuyerShopSourceType.hardwareProRetail,
      regions: 'US, CA, UK, AU, EU',
      commissionRange: '5% – 8%+ (High \$180+ Average Order Value)',
      cookieWindow: '30 days',
      signupUrl: 'https://www.vevor.com/pages/affiliate-program',
      trackingHint: 'VEVOR Impact / ShareASale / in-house referral link',
      bestFor:
          'Pipe stands, chain vises, magnetic drills, hydraulic porta-powers, diesel transfer pumps & hoists.',
      sampleDomains: <String>['vevor.com', 'vevor.ca'],
    ),
    PipeBuyerAffiliatePlatformInfo(
      id: 'home_depot_pro',
      name: 'The Home Depot & Pro Xtra Affiliate (Impact)',
      sourceType: PipeBuyerShopSourceType.hardwareProRetail,
      regions: 'US, CA',
      commissionRange: '1% – 8% (Power Tools, Jobsite Storage & Pro Gear)',
      cookieWindow: '24 hours',
      signupUrl: 'https://www.homedepot.com/c/SF_MS_Affiliate_Program',
      trackingHint: 'homedepot.pxf.io/... or homedepot.com product link',
      bestFor:
          'Milwaukee PACKOUT, DeWalt FlexVolt, RIDGID wet/dry vacs, generators, ladders & jobsite boxes.',
      sampleDomains: <String>['homedepot.com', 'homedepot.ca', 'thd.co'],
    ),
    PipeBuyerAffiliatePlatformInfo(
      id: 'acme_zoro_industrial',
      name: 'Acme Tools, Northern Tool, Zoro & Tractor Supply',
      sourceType: PipeBuyerShopSourceType.hardwareProRetail,
      regions: 'US, CA',
      commissionRange: '3% – 7% (Impact / CJ / Rakuten)',
      cookieWindow: '7 – 30 days',
      signupUrl: 'https://www.acmetools.com/affiliate-program.html',
      trackingHint: 'Impact / CJ / Rakuten tracking link or product URL',
      bestFor:
          'Engine-driven welders, truck transfer tanks, Fill-Rite pumps, fencing & heavy MRO supplies.',
      sampleDomains: <String>[
        'acmetools.com',
        'northerntool.com',
        'zoro.com',
        'tractorsupply.com'
      ],
    ),
    PipeBuyerAffiliatePlatformInfo(
      id: 'bakers_gas_welding_ranch',
      name: "Baker's Gas & Welding, Boot Barn & etrailer",
      sourceType: PipeBuyerShopSourceType.hardwareProRetail,
      regions: 'US, CA',
      commissionRange:
          '4% – 8% (High-ticket \$1,000+ welders & gooseneck hitches)',
      cookieWindow: '14 – 30 days',
      signupUrl: 'https://bakersgas.com/',
      trackingHint: 'AvantLink / CJ / ShareASale partner URL',
      bestFor:
          'Miller & Lincoln pipeline welders, plasma cutters, Ariat FR work boots, gooseneck & flatbed trailer hitches.',
      sampleDomains: <String>['bakersgas.com', 'bootbarn.com', 'etrailer.com'],
    ),
    PipeBuyerAffiliatePlatformInfo(
      id: 'walmart_affiliate',
      name: 'Walmart Affiliate Program (Impact)',
      sourceType: PipeBuyerShopSourceType.walmartAffiliate,
      regions: 'US, CA, MX',
      commissionRange: '1% – 4%',
      cookieWindow: '3 days',
      signupUrl: 'https://affiliates.walmart.com/',
      trackingHint: 'goto.walmart.com/... or walmart.com link',
      bestFor:
          'Automotive batteries, motor oil, DEF fluid, coolers, camp gear & workwear.',
      sampleDomains: <String>['walmart.com', 'goto.walmart.com'],
    ),
    PipeBuyerAffiliatePlatformInfo(
      id: 'temu_tiktok_shop',
      name: 'Temu & TikTok Shop Affiliate Programs',
      sourceType: PipeBuyerShopSourceType.temuAffiliate,
      regions: 'US, CA, UK, AU, PH, SG, MY, TH, VN, ID, EU',
      commissionRange: '5% – 20% + new-app-install bonuses',
      cookieWindow: '7 – 14 days',
      signupUrl: 'https://www.temu.com/affiliate.html',
      trackingHint: 'temu.to/... or vt.tiktok.com/... affiliate share link',
      bestFor:
          'High-converting budget hand tools, LED headlamps, digital calipers, truck organizers & viral tool demos.',
      sampleDomains: <String>[
        'temu.com',
        'temu.to',
        'tiktok.com',
        'vt.tiktok.com'
      ],
    ),
    PipeBuyerAffiliatePlatformInfo(
      id: 'alibaba_dhgate_b2b',
      name: 'Alibaba.com & DHgate B2B Affiliate Programs',
      sourceType: PipeBuyerShopSourceType.alibabaB2b,
      regions: 'Global',
      commissionRange: '3% – 15% on wholesale & bulk orders',
      cookieWindow: '7 – 30 days',
      signupUrl: 'https://alliance.alibaba.com/',
      trackingHint: 's.click.alibaba.com/... or dhgate.com affiliate link',
      bestFor:
          'Bulk pipe flanges, valves, lifting slings, PPE pallets, solar light towers & factory-direct machinery.',
      sampleDomains: <String>[
        'alibaba.com',
        's.click.alibaba.com',
        'dhgate.com'
      ],
    ),
    PipeBuyerAffiliatePlatformInfo(
      id: 'global_networks_skimlinks',
      name: 'Impact, CJ, ShareASale/Awin, Rakuten, Skimlinks & PartnerStack',
      sourceType: PipeBuyerShopSourceType.affiliateNetwork,
      regions: 'Global (60,000+ Merchants & B2B SaaS)',
      commissionRange: '4% – 30% (up to 30% recurring on B2B fleet/field SaaS)',
      cookieWindow: '30 – 90 days',
      signupUrl: 'https://impact.com/',
      trackingHint:
          'pxf.io, sjv.io, shrsl.com, awin1.com, redirect.viglink.com, partnerstack.com',
      bestFor:
          'Automatic domain monetization + recurring passive income from ELD/fleet tracking, accounting & CAD/estimating SaaS.',
      sampleDomains: <String>[
        'pxf.io',
        'sjv.io',
        'shrsl.com',
        'awin1.com',
        'partnerstack.com'
      ],
    ),
  ];
  static const List<PipeBuyerShopCategory> categories = <PipeBuyerShopCategory>[
    PipeBuyerShopCategory(
      code: 'pipe_welding_fab',
      label: 'Pipefitting, Welding & Fab',
      shortLabel: 'Pipe & Welding',
      subtitle:
          'Pipe wrenches, chain vises, bevelers, pipeline welding helmets, leads & flange alignment tools.',
      icon: Icons.precision_manufacturing_outlined,
      iconAsset:
          'assets/images/industrial_icons/26-marketplace-catalog-photos/welding-machine.svg',
      accentColor: Color(0xFFFF6A00),
      marketplaceCategories: <String>['Pipe', 'Oilfield Equipment'],
      subcategories: <String>[
        'Pipe Wrenches, Chain Tongs & Vises',
        'Pipe Cutting, Threading & Beveling',
        'Pipe Alignment, Jacks & Fit-Up Tools',
        'Welding Machines, Leads & Torches',
        'Welding Rods, Wire & Abrasives',
        'Valves, Pipe Fittings, Flanges & Sealants',
      ],
    ),
    PipeBuyerShopCategory(
      code: 'power_hand_tools',
      label: 'Power & Cordless Tools',
      shortLabel: 'Power Tools',
      subtitle:
          'High-torque impacts, portable bandsaws, angle grinders, torque wrenches & cordless kits.',
      icon: Icons.handyman_outlined,
      iconAsset:
          'assets/images/industrial_icons/09-software-and-administration/04-maintenance-tools.svg',
      accentColor: Color(0xFFD92D20),
      marketplaceCategories: <String>[
        'Heavy Equipment',
        'Oilfield Equipment',
        'Pipe',
      ],
      subcategories: <String>[
        'Cordless Impact Wrenches & Socket Sets',
        'Angle Grinders, Bandsaws & Mag Drills',
        'Heavy Wrenches, Ratchets & Torque Tools',
        'Pliers, Hammers, Spuds & Pry Bars',
        'Mechanics, Electrician & Tap/Die Kits',
        'Cordless Batteries, Chargers & Packout',
      ],
    ),
    PipeBuyerShopCategory(
      code: 'rigging_hauling_cargo',
      label: 'Rigging, Chains & Cargo Control',
      shortLabel: 'Rigging & Hauling',
      subtitle:
          'DOT Grade 70/100 transport chains, ratchet binders, lifting slings, Crosby shackles & oversize load kits.',
      icon: Icons.link_rounded,
      iconAsset:
          'assets/images/industrial_icons/20-transport-and-dispatch-equipment/05-pipe-hauling-truck-trailer.svg',
      accentColor: Color(0xFF0F52BA),
      marketplaceCategories: <String>['Transport & Hauling'],
      subcategories: <String>[
        'Shackles, Hooks, Swivels & Hardware',
        'Web Slings, Round Slings & Wire Chokers',
        'Chain Hoists, Lever Pullers & Clamps',
        'Grade 70/100 Chains & Load Binders',
        'Flatbed Winch Straps, Tarps & Stakes',
        'Oversize Load Banners, Beacons & Safety',
      ],
    ),
    PipeBuyerShopCategory(
      code: 'ppe_fr_safety',
      label: 'FR Workwear, PPE & Gas Detection',
      shortLabel: 'FR & Safety PPE',
      subtitle:
          'NFPA 2112 FR garments, H2S 4-gas monitors, ANSI impact gloves, hard hats & truck spill kits.',
      icon: Icons.health_and_safety_outlined,
      iconAsset:
          'assets/images/industrial_icons/08-safety-and-security/06-safety-hardhat.svg',
      accentColor: Color(0xFF148A45),
      marketplaceCategories: <String>[
        'Oilfield Equipment',
        'Tanks & Containers',
        'Portable Buildings',
      ],
      subcategories: <String>[
        'FR Shirts, Coveralls & Winter Outerwear',
        'Pipeline & Oilfield Safety Work Boots',
        'Hard Hats, Welding Shields & Safety Glasses',
        'ANSI Impact, Rigging & Cut Gloves',
        'H2S / 4-Gas Monitors & Respiratory',
        'Fall Protection, Spill Kits & First Aid',
      ],
    ),
    PipeBuyerShopCategory(
      code: 'hydraulics_fleet_shop',
      label: 'Fleet, Hydraulics & Field Service',
      shortLabel: 'Fleet & Hydraulics',
      subtitle:
          'Cordless grease guns, 12V diesel transfer pumps, commercial jump packs & hydraulic test kits.',
      icon: Icons.oil_barrel_outlined,
      iconAsset:
          'assets/images/industrial_icons/03-fuel-and-fluid-equipment/05-industrial-pump.svg',
      accentColor: Color(0xFF008B78),
      marketplaceCategories: <String>[
        'Heavy Equipment',
        'Tanks & Containers',
        'Transport & Hauling',
      ],
      subcategories: <String>[
        'Diesel Transfer Pumps, Meters & Filters',
        'Grease Guns, Hose Reels & Lubrication',
        'Hydraulic Jacks, Rams, Pumps & Couplers',
        'Service Truck Compressors & Air Tools',
        '12V/24V Jump Packs, Chargers & HD Scanners',
        'Tire Service, Mud Flaps & Shop Consumables',
      ],
    ),
    PipeBuyerShopCategory(
      code: 'lighting_power_jobsite',
      label: 'Jobsite Lighting, Power & Storage',
      shortLabel: 'Lighting & Power',
      subtitle:
          'Magnetic LED work lights, inverter generators, cold-weather cords, radios & steel gang boxes.',
      icon: Icons.bolt_rounded,
      iconAsset:
          'assets/images/industrial_icons/07-oil-and-gas-equipment/05-generator-units.svg',
      accentColor: Color(0xFFD97706),
      marketplaceCategories: <String>[
        'Portable Buildings',
        'Heavy Equipment',
        'Land & Commercial Property',
      ],
      subcategories: <String>[
        'Cordless Tower, Magnetic & Flood Lights',
        'Intrinsically Safe Flashlights & Headlamps',
        'Generators, Power Stations & Spider Boxes',
        'Heavy Cold-Weather Cords & Welding Adapters',
        'Jobsite Gang Boxes, Truck Chests & Cases',
        'Two-Way Radios, Coolers & Jobsite Heaters',
      ],
    ),
    PipeBuyerShopCategory(
      code: 'measuring_inspection',
      label: 'Inspection, Gauges & Pipe Testing',
      shortLabel: 'Inspection & Gauges',
      subtitle:
          'Ultrasonic wall-thickness gauges, pipe OD calipers, API thread gauges & thermal imagers.',
      icon: Icons.straighten_rounded,
      iconAsset:
          'assets/images/industrial_icons/17-pipe-and-materials/12-pipe-inspection-equipment.svg',
      accentColor: Color(0xFF7557D3),
      marketplaceCategories: <String>['Pipe', 'Oilfield Equipment'],
      subcategories: <String>[
        'Ultrasonic Wall Thickness & NDT Kits',
        'Liquid-Filled Pressure Gauges & Hydrotest',
        'Pipe Calipers, Tally Tapes & Thread Gauges',
        'Borescopes, Sewer Cameras & Pipe Locators',
        'Thermal Imagers, Pyrometers & Leak Detectors',
        'Rotary Lasers, Digital Levels & Multimeters',
      ],
    ),
    PipeBuyerShopCategory(
      code: 'ranch_fencing_ag',
      label: 'Farm, Ranch & Pipe Fencing Gear',
      shortLabel: 'Ranch & Fencing',
      subtitle:
          'Gas post drivers, weld-on pipe gate hinges, latches, solar fencers & stock tank hardware.',
      icon: Icons.fence_rounded,
      iconAsset:
          'assets/images/industrial_icons/18-farm-ranch-listings/10-custom-pipe-fabrication.svg',
      accentColor: Color(0xFF854D0E),
      marketplaceCategories: <String>['Farm & Ranch'],
      subcategories: <String>[
        'Pipe Fence Coping, Saddles & Notchers',
        'Weld-On Hinges, Latches & Gate Hardware',
        'Gas Post Drivers, Augers & T-Post Tools',
        'Solar Fence Chargers, Wire & Strainers',
        'Stock Tank Valves, Waterers & Ag Pumps',
        'Livestock Chute, Trailer & Ranch Hardware',
      ],
    ),
  ];

  static List<String> subcategoriesForCategory(String? categoryCode) {
    final cat = categoryByCode(categoryCode);
    if (cat != null) return cat.subcategories;
    return categories.expand((c) => c.subcategories).toList(growable: false);
  }

  static PipeBuyerShopCategory? categoryByCode(String? code) {
    if (code == null || code.trim().isEmpty) return null;
    final clean = code.trim();
    for (final cat in categories) {
      if (cat.code == clean) return cat;
    }
    return null;
  }

  static PipeBuyerShopCategory categoryForMarketplaceCategory(
    String marketplaceCategory,
  ) {
    final lower = marketplaceCategory.trim().toLowerCase();
    if (lower.contains('pipe')) return categories[0];
    if (lower.contains('transport') || lower.contains('haul')) {
      return categories[2];
    }
    if (lower.contains('heavy')) return categories[1];
    if (lower.contains('tank')) return categories[4];
    if (lower.contains('building') || lower.contains('land')) {
      return categories[5];
    }
    if (lower.contains('farm') || lower.contains('ranch')) {
      return categories[7];
    }
    if (lower.contains('oilfield')) return categories[3];
    return categories[0];
  }

  static const List<PipeBuyerPartnerSpotlight> partnerSpotlights =
      <PipeBuyerPartnerSpotlight>[
    PipeBuyerPartnerSpotlight(
      id: 'amazon-industrial',
      name: 'Amazon Industrial & Trades',
      channelLabel: 'OFFICIAL AFFILIATE PARTNER',
      description:
          'Fast Prime jobsite delivery across North America on tools, welding gear, rigging & PPE.',
      statusLabel: 'Live Now',
      accentColor: Color(0xFFFF9900),
      icon: Icons.shopping_bag_outlined,
      filterSource: PipeBuyerShopSourceType.amazonAffiliate,
    ),
    PipeBuyerPartnerSpotlight(
      id: 'milwaukee-spotlight',
      name: 'Milwaukee Tool Selection',
      channelLabel: 'HEAVY-DUTY CORDLESS & PIPE',
      description:
          'M18 FUEL impacts, bandsaws, grinders, grease guns & pipe cutters. Direct distributor onboarding ready.',
      statusLabel: 'Featured Brand',
      accentColor: Color(0xFFD92D20),
      icon: Icons.bolt_rounded,
      filterBrand: 'Milwaukee',
    ),
    PipeBuyerPartnerSpotlight(
      id: 'ridgid-spotlight',
      name: 'RIDGID Pipe & Fab Gear',
      channelLabel: 'PIPELINE & THREADING STANDARD',
      description:
          'Heavy-duty aluminum & cast pipe wrenches, Tristand chain vises, pipe cutters & threading gear.',
      statusLabel: 'Featured Brand',
      accentColor: Color(0xFFE85F00),
      icon: Icons.build_circle_outlined,
      filterBrand: 'RIDGID',
    ),
    PipeBuyerPartnerSpotlight(
      id: 'lincoln-welding-spotlight',
      name: 'Welding & Pipeline Fab',
      channelLabel: 'LINCOLN / MILLER / JACKSON',
      description:
          'Auto-darkening pipeline hoods, electrode holders, ground clamps, flange pins & FR welding apparel.',
      statusLabel: 'Curated Line',
      accentColor: Color(0xFF0F52BA),
      icon: Icons.local_fire_department_outlined,
      filterBrand: 'Lincoln Electric',
    ),
    PipeBuyerPartnerSpotlight(
      id: 'vendor-distributor-onboarding',
      name: 'Distributors, Brands & Businesses',
      channelLabel: 'BECOME A STORE PARTNER',
      description:
          'Authorized tool dealers, industrial supply houses, and businesses: apply to list your catalog here.',
      statusLabel: 'Apply to List',
      accentColor: Color(0xFF148A45),
      icon: Icons.handshake_outlined,
      opensVendorPortal: true,
    ),
  ];

  static const List<PipeBuyerShopProduct> starterCatalog =
      <PipeBuyerShopProduct>[
    // 1. Pipefitting, Welding & Fab
    PipeBuyerShopProduct(
      id: 'ridgid-36-aluminum-pipe-wrench',
      title: 'RIDGID 31110 Model 836 36-Inch Aluminum Straight Pipe Wrench',
      brand: 'RIDGID',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'pipe_welding_fab',
      subcategory: 'Pipe Wrenches, Chain Tongs & Vises',
      destinationUrl: 'https://link.amazon/B0iZoQG46',
      badgeText: 'Pipeline Essential',
      featured: true,
      priorityRank: 10,
      description:
          '40% lighter than comparable cast-iron models with 5-inch pipe capacity for oilfield, rig floor, and mechanical pipefitting crews.',
      highlights: <String>[
        '36-inch length / 5-inch pipe OD capacity',
        'Lightweight forged aluminum housing',
        'Replaceable alloy steel hook & heel jaws',
      ],
      tags: <String>['ridgid', 'pipe wrench', 'tubular', 'casing', 'plumbing'],
      marketplaceCategories: <String>['Pipe', 'Oilfield Equipment'],
      fallbackIconAsset:
          'assets/images/industrial_icons/02-pipes-and-valves/07-pipe-cutter.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'ridgid-460-tristand-chain-vise',
      title: 'RIDGID 36273 Model 460-6 Portable TRISTAND Chain Pipe Vise',
      brand: 'RIDGID',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'pipe_welding_fab',
      subcategory: 'Pipe Wrenches, Chain Tongs & Vises',
      destinationUrl: 'https://link.amazon/B0dkMQ4Gm',
      badgeText: 'Fab Truck Favorite',
      featured: true,
      priorityRank: 15,
      description:
          'Field-ready folding tripod chain vise handling 1/8-inch through 6-inch pipe with integrated grounding lug for welding.',
      highlights: <String>[
        '1/8" to 6" pipe capacity',
        'Built-in welding ground lug & tool tray',
        'Folding legs with carry handle for rig trucks',
      ],
      tags: <String>[
        'ridgid',
        'tristand',
        'chain vise',
        'welding',
        'pipefitting'
      ],
      marketplaceCategories: <String>['Pipe', 'Oilfield Equipment'],
      fallbackIconAsset:
          'assets/images/industrial_icons/17-pipe-and-materials/11-pipe-threading-equipment.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'pb-0025-ridgid-31090-model-810-10-inch-aluminum-straight-pipe-wr',
      title:
          'RIDGID 31090 Model 810 10-Inch Aluminum Straight Pipe Wrench (1-1/2" Cap.)',
      brand: 'RIDGID',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'pipe_welding_fab',
      subcategory: 'Pipe Wrenches, Chain Tongs & Vises',
      destinationUrl: 'https://link.amazon/B02tpL9H0',
      badgeText: 'Rig Bag Staple',
      priorityRank: 42,
      description:
          'Compact forged aluminum pipe wrench for instrument tubing, 1-inch nipples, and tight manifold racks.',
      highlights: <String>[
        '10-inch handle / 1-1/2" pipe capacity',
        '40% lighter than cast-iron equivalents',
        'Self-cleaning hook jaw threads',
      ],
      tags: <String>['ridgid', 'pipe wrench', '10 inch', 'manifold', 'tubing'],
      marketplaceCategories: <String>['Pipe', 'Oilfield Equipment'],
      fallbackIconAsset:
          'assets/images/industrial_icons/02-pipes-and-valves/07-pipe-cutter.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'pb-0026-ridgid-31095-model-814-14-inch-aluminum-straight-pipe-wr',
      title:
          'RIDGID 31095 Model 814 14-Inch Aluminum Straight Pipe Wrench (2" Cap.)',
      brand: 'RIDGID',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'pipe_welding_fab',
      subcategory: 'Pipe Wrenches, Chain Tongs & Vises',
      destinationUrl: 'https://link.amazon/B0ia8erLT',
      badgeText: 'Pipefitter Standard',
      priorityRank: 43,
      description:
          'Everyday 14-inch aluminum straight wrench for 1/2" to 2" threaded black iron and galvanized pipe.',
      highlights: <String>[
        '14-inch length / 2" max pipe OD',
        'Forged aluminum housing',
        'Replaceable hardened alloy jaws',
      ],
      tags: <String>['ridgid', 'pipe wrench', '14 inch', 'pipefitter'],
      marketplaceCategories: <String>['Pipe', 'Oilfield Equipment'],
      fallbackIconAsset:
          'assets/images/industrial_icons/02-pipes-and-valves/07-pipe-cutter.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'pb-0027-ridgid-31100-model-818-18-inch-aluminum-straight-pipe-wr',
      title:
          'RIDGID 31100 Model 818 18-Inch Aluminum Straight Pipe Wrench (2-1/2" Cap.)',
      brand: 'RIDGID',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'pipe_welding_fab',
      subcategory: 'Pipe Wrenches, Chain Tongs & Vises',
      destinationUrl: 'https://link.amazon/B0bCNPX9o',
      badgeText: 'Lease Crew Pick',
      priorityRank: 44,
      description:
          'Balanced 18-inch aluminum wrench ideal for wellhead trim, 2-inch flowlines, and tank battery hookups.',
      highlights: <String>[
        '18-inch length / 2-1/2" pipe capacity',
        'High-strength I-beam handle',
        'Full-floating forged hook jaw',
      ],
      tags: <String>[
        'ridgid',
        'pipe wrench',
        '18 inch',
        'wellhead',
        'flowline'
      ],
      marketplaceCategories: <String>['Pipe', 'Oilfield Equipment'],
      fallbackIconAsset:
          'assets/images/industrial_icons/02-pipes-and-valves/07-pipe-cutter.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'pb-0028-ridgid-31105-model-824-24-inch-aluminum-straight-pipe-wr',
      title:
          'RIDGID 31105 Model 824 24-Inch Aluminum Straight Pipe Wrench (3" Cap.)',
      brand: 'RIDGID',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'pipe_welding_fab',
      subcategory: 'Pipe Wrenches, Chain Tongs & Vises',
      destinationUrl: 'https://link.amazon/B0emLXhCS',
      badgeText: 'Flowline Spec',
      priorityRank: 45,
      description:
          'Heavy-leverage 24-inch aluminum pipe wrench built for 2-inch and 3-inch threaded oilfield tubulars.',
      highlights: <String>[
        '24-inch length / 3" pipe OD capacity',
        'Weighs under 6 lbs for overhead work',
        'Graduated pipe scale on hook jaw',
      ],
      tags: <String>[
        'ridgid',
        'pipe wrench',
        '24 inch',
        'tubulars',
        'flowline'
      ],
      marketplaceCategories: <String>['Pipe', 'Oilfield Equipment'],
      fallbackIconAsset:
          'assets/images/industrial_icons/02-pipes-and-valves/07-pipe-cutter.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'pb-0029-ridgid-31115-model-848-48-inch-aluminum-straight-pipe-wr',
      title:
          'RIDGID 31115 Model 848 48-Inch Aluminum Straight Pipe Wrench (6" Cap.)',
      brand: 'RIDGID',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'pipe_welding_fab',
      subcategory: 'Pipe Wrenches, Chain Tongs & Vises',
      destinationUrl: 'https://link.amazon/B09Fd0TuQ',
      badgeText: 'Big Iron 6" Cap',
      priorityRank: 46,
      description:
          'Two-hand 48-inch aluminum pipe wrench for 4-inch to 6-inch casing collars, headers, and pump suction lines.',
      highlights: <String>[
        '48-inch length / 6" pipe OD capacity',
        '18.5 lb aluminum housing saves crew backs',
        'Heavy-duty replaceable heel jaw',
      ],
      tags: <String>['ridgid', 'pipe wrench', '48 inch', 'casing', 'header'],
      marketplaceCategories: <String>['Pipe', 'Oilfield Equipment'],
      fallbackIconAsset:
          'assets/images/industrial_icons/02-pipes-and-valves/07-pipe-cutter.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'pb-0030-ridgid-31020-model-14-14-inch-heavy-duty-cast-iron-strai',
      title:
          'RIDGID 31020 Model 14 14-Inch Heavy-Duty Cast-Iron Straight Pipe Wrench',
      brand: 'RIDGID',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'pipe_welding_fab',
      subcategory: 'Pipe Wrenches, Chain Tongs & Vises',
      destinationUrl: 'https://link.amazon/B0aLZDhdJ',
      badgeText: 'Cast-Iron Classic',
      priorityRank: 47,
      description:
          'Ductile-iron housing 14-inch straight wrench engineered for brutal rig-floor torque and stubborn unions.',
      highlights: <String>[
        '14-inch cast ductile-iron handle',
        '2-inch pipe capacity',
        'Lifetime-grade alloy steel jaws',
      ],
      tags: <String>[
        'ridgid',
        'pipe wrench',
        '14 inch',
        'cast iron',
        'rig floor'
      ],
      marketplaceCategories: <String>['Pipe', 'Oilfield Equipment'],
      fallbackIconAsset:
          'assets/images/industrial_icons/02-pipes-and-valves/07-pipe-cutter.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'lincoln-viking-3350-welding-helmet',
      title: 'Lincoln Electric VIKING 3350 4C Auto-Darkening Welding Helmet',
      brand: 'Lincoln Electric',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'pipe_welding_fab',
      subcategory: 'Welding Machines, Leads & Torches',
      destinationUrl:
          'https://www.amazon.com/s?k=Lincoln+Electric+VIKING+3350+Welding+Helmet',
      badgeText: 'Welder Top Pick',
      featured: true,
      priorityRank: 18,
      description:
          '1/1/1/1 optical clarity 4C lens technology with external grind button for pipeline, structural, and shop fabrication.',
      highlights: <String>[
        '4C lens technology — 1/1/1/1 optical rating',
        'Extra-large 12.5 sq. in. viewing area',
        'External low-profile grind mode control',
      ],
      tags: <String>[
        'lincoln electric',
        'welding helmet',
        'pipeline',
        'fabrication'
      ],
      marketplaceCategories: <String>[
        'Pipe',
        'Oilfield Equipment',
        'Farm & Ranch'
      ],
      fallbackIconAsset:
          'assets/images/industrial_icons/26-marketplace-catalog-photos/welding-machine.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'flange-wizard-two-hole-pins-level',
      title:
          'Flange Wizard Quick-Action Two-Hole Flange Alignment Pins & Magnetic Level Kit',
      brand: 'Flange Wizard',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'pipe_welding_fab',
      subcategory: 'Pipe Alignment, Jacks & Fit-Up Tools',
      destinationUrl:
          'https://www.amazon.com/s?k=Flange+Wizard+Two+Hole+Pins+Pipefitter+Level',
      badgeText: 'Pipefitter Spec',
      featured: false,
      priorityRank: 28,
      description:
          'Precision machined hardened steel two-hole flange alignment pins and magnetic pipefitter level for fast ASME flange fit-ups.',
      highlights: <String>[
        'Fits 1/2" to 1-7/16" ASME flange bolt holes',
        'ACME threads for rapid self-centering',
        'Rare-earth magnetic grooved pipe vial level',
      ],
      tags: <String>['flange', 'pipefitter', 'alignment pins', 'valves'],
      marketplaceCategories: <String>['Pipe'],
      fallbackIconAsset:
          'assets/images/industrial_icons/02-pipes-and-valves/04-pipe-flange.svg',
      isStarterSeed: true,
    ),

    // 2. Power & Cordless Tools (Milwaukee, DeWalt, etc.)
    PipeBuyerShopProduct(
      id: 'milwaukee-m18-fuel-high-torque-impact',
      title:
          'Milwaukee M18 FUEL 1/2-Inch High-Torque Impact Wrench w/ Friction Ring Kit',
      brand: 'Milwaukee',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'power_hand_tools',
      subcategory: 'Cordless Impact Wrenches & Socket Sets',
      destinationUrl:
          'https://www.amazon.com/s?k=Milwaukee+2767-20+M18+FUEL+High+Torque+Impact+Wrench',
      badgeText: '1,400 ft-lbs Nut-Busting',
      featured: true,
      priorityRank: 8,
      description:
          'Industry-standard cordless impact wrench delivering up to 1,400 ft-lbs of nut-busting torque for flange bolts, heavy equipment lugs, and field service.',
      highlights: <String>[
        'Up to 1,400 ft-lbs nut-busting torque',
        '4-Mode DRIVE CONTROL with Bolt Removal mode',
        'POWERSTATE brushless motor for rig & shop duty',
      ],
      tags: <String>[
        'milwaukee',
        'm18',
        'impact wrench',
        'flange bolts',
        'mechanic'
      ],
      marketplaceCategories: <String>[
        'Heavy Equipment',
        'Oilfield Equipment',
        'Pipe',
        'Transport & Hauling',
      ],
      fallbackIconAsset:
          'assets/images/industrial_icons/09-software-and-administration/04-maintenance-tools.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'milwaukee-m18-fuel-deep-cut-bandsaw',
      title:
          'Milwaukee M18 FUEL 5-Inch Deep Cut Dual-Trigger Portable Band Saw',
      brand: 'Milwaukee',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'power_hand_tools',
      subcategory: 'Angle Grinders, Bandsaws & Mag Drills',
      destinationUrl:
          'https://www.amazon.com/s?k=Milwaukee+M18+FUEL+Deep+Cut+Band+Saw',
      badgeText: 'Jobsite Safety Spec',
      featured: true,
      priorityRank: 14,
      description:
          'Cuts 4-inch black iron pipe, strut, and schedule 40 steel cleanly with spark-reduced cold cuts and jobsite-compliant dual-trigger control.',
      highlights: <String>[
        '5" x 5" deep cut capacity for pipe & strut',
        'Variable speed dial + tool-free shoe adjustment',
        'LED cut-line worklight & integrated hang hook',
      ],
      tags: <String>['milwaukee', 'bandsaw', 'pipe cutting', 'm18 fuel'],
      marketplaceCategories: <String>['Pipe', 'Oilfield Equipment'],
      fallbackIconAsset:
          'assets/images/industrial_icons/02-pipes-and-valves/07-pipe-cutter.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'milwaukee-m18-braking-grinder',
      title:
          'Milwaukee M18 FUEL 4-1/2" / 6" Braking Angle Grinder (Paddle Switch)',
      brand: 'Milwaukee',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'power_hand_tools',
      subcategory: 'Angle Grinders, Bandsaws & Mag Drills',
      destinationUrl:
          'https://www.amazon.com/s?k=Milwaukee+M18+FUEL+Braking+Grinder+Paddle+Switch',
      badgeText: 'RAPIDSTOP Brake',
      featured: false,
      priorityRank: 24,
      description:
          'Corded-class grinding power for pipe beveling, root pass prep, and weld cleanup with RAPIDSTOP disc braking under 2 seconds.',
      highlights: <String>[
        'RAPIDSTOP brake stops accessories in < 2 sec',
        'No-lock paddle switch required on major sites',
        'Electronic clutch for kickback protection',
      ],
      tags: <String>['milwaukee', 'grinder', 'pipe beveling', 'welding prep'],
      marketplaceCategories: <String>[
        'Pipe',
        'Heavy Equipment',
        'Farm & Ranch'
      ],
      fallbackIconAsset:
          'assets/images/industrial_icons/09-software-and-administration/04-maintenance-tools.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'dewalt-impact-socket-set-1-2',
      title:
          'DEWALT 1/2-Inch Drive Deep Impact Socket Set (SAE & Metric, Cr-Mo Steel)',
      brand: 'DEWALT',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'power_hand_tools',
      subcategory: 'Cordless Impact Wrenches & Socket Sets',
      destinationUrl:
          'https://www.amazon.com/s?k=DEWALT+1%2F2+Drive+Deep+Impact+Socket+Set+SAE+Metric',
      badgeText: 'Service Truck Kit',
      featured: false,
      priorityRank: 32,
      description:
          'Heat-treated CR-440 steel deep impact sockets with laser-etched high-visibility markings and lockable hard case.',
      highlights: <String>[
        'DirectTorque 6-point geometry prevents rounding',
        'Black oxide oil-resistant coating',
        'Heavy-duty stackable service truck case',
      ],
      tags: <String>['dewalt', 'impact sockets', 'sae', 'metric', 'mechanic'],
      marketplaceCategories: <String>['Heavy Equipment', 'Transport & Hauling'],
      fallbackIconAsset:
          'assets/images/industrial_icons/09-software-and-administration/04-maintenance-tools.svg',
      isStarterSeed: true,
    ),

    // 3. Rigging, Chains & Cargo Control
    PipeBuyerShopProduct(
      id: 'dot-grade-70-transport-chain-4pack',
      title:
          'DOT Grade 70 3/8-Inch x 20-Ft Heavy-Duty Transport Binder Chains (4-Pack, 6,600 lb WLL)',
      brand: 'Vulcan / Peerless',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'rigging_hauling_cargo',
      subcategory: 'Grade 70/100 Chains & Load Binders',
      destinationUrl:
          'https://www.amazon.com/s?k=3%2F8+x+20+Grade+70+Transport+Binder+Chain+6600+WLL',
      badgeText: 'DOT / CVSA Compliant',
      featured: true,
      priorityRank: 12,
      description:
          'NACM & FMCSA/DOT stamped Grade 70 yellow-chromate clevis grab-hook tie-down chains for hauling pipe, skid steers, and heavy iron.',
      highlights: <String>[
        '6,600 lb Working Load Limit / 26,400 lb break',
        'Embossed G70 links & forged clevis grab hooks',
        'Meets DOT, FMCSA & CVSA roadside inspection specs',
      ],
      tags: <String>[
        'grade 70',
        'chain',
        'tie down',
        'flatbed',
        'lowboy',
        'pipe hauling'
      ],
      marketplaceCategories: <String>[
        'Transport & Hauling',
        'Heavy Equipment',
        'Pipe'
      ],
      fallbackIconAsset:
          'assets/images/industrial_icons/20-transport-and-dispatch-equipment/05-pipe-hauling-truck-trailer.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'ratchet-load-binders-9200-wll',
      title:
          'Heavy-Duty Forged Ratchet Load Binders for 3/8"–1/2" Grade 70/80 Chain (4-Pack, 9,200 lb WLL)',
      brand: 'Vulcan',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'rigging_hauling_cargo',
      subcategory: 'Grade 70/100 Chains & Load Binders',
      destinationUrl:
          'https://www.amazon.com/s?k=Forged+Ratchet+Load+Binder+3%2F8+to+1%2F2+9200+WLL+4+Pack',
      badgeText: 'Hotshot & Lowboy',
      featured: false,
      priorityRank: 22,
      description:
          'Recoil-free ratcheting load binders stamped with 9,200 lb WLL for flatbed, hotshot gooseneck, and step-deck load securement.',
      highlights: <String>[
        '9,200 lb WLL — fits 3/8" G70 & 1/2" chain',
        'Safer ratcheting gear action vs lever snap-binders',
        'Forged steel grab hooks with powder-coat barrel',
      ],
      tags: <String>[
        'load binder',
        'ratchet binder',
        'hotshot',
        'flatbed',
        'dispatch'
      ],
      marketplaceCategories: <String>['Transport & Hauling', 'Heavy Equipment'],
      fallbackIconAsset:
          'assets/images/industrial_icons/11-heavy-haul-and-escort/01-lowboy-trailer.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'crosby-screw-pin-anchor-shackles',
      title:
          'Crosby G-209 Forged Carbon Steel Screw Pin Anchor Shackles (3/4" — 4.75 Ton WLL)',
      brand: 'Crosby',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'rigging_hauling_cargo',
      subcategory: 'Shackles, Hooks, Swivels & Hardware',
      destinationUrl:
          'https://www.amazon.com/s?k=Crosby+G-209+Screw+Pin+Anchor+Shackle+4.75+Ton',
      badgeText: 'Rigging Gold Standard',
      featured: false,
      priorityRank: 26,
      description:
          'Quenched and tempered forged alloy pin anchor shackles permanently stamped with WLL and PIC traceability code.',
      highlights: <String>[
        '4.75 Metric Ton Working Load Limit',
        'Hot-dip galvanized fatigue-rated body',
        'Forged in North America / ASME B30.26 compliant',
      ],
      tags: <String>['crosby', 'shackle', 'rigging', 'crane', 'lifting'],
      marketplaceCategories: <String>[
        'Transport & Hauling',
        'Oilfield Equipment',
        'Portable Buildings',
      ],
      fallbackIconAsset:
          'assets/images/industrial_icons/05-commercial-vehicles/03-crane-truck.svg',
      isStarterSeed: true,
    ),

    // 4. FR Workwear, PPE & Gas Detection
    PipeBuyerShopProduct(
      id: 'bw-clip4-multi-gas-detector-h2s',
      title: 'Honeywell BW Clip4 / Multi-Gas 4-Gas Detector (H2S, CO, O2, LEL)',
      brand: 'Honeywell BW',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'ppe_fr_safety',
      subcategory: 'H2S / 4-Gas Monitors & Respiratory',
      destinationUrl:
          'https://www.amazon.com/s?k=Honeywell+BW+4+Gas+Monitor+H2S+CO+O2+LEL',
      badgeText: 'Wellsite Mandatory PPE',
      featured: true,
      priorityRank: 11,
      description:
          'Intrinsically safe wearable 4-gas personal monitor for sour gas (H2S), carbon monoxide, oxygen deficiency, and combustible LEL hazards.',
      highlights: <String>[
        'Continuous real-time H2S, CO, O2 & LEL display',
        'IP68 waterproof / Class I, Div 1 intrinsically safe',
        '95 dB alarm + high-output strobe + vibration alert',
      ],
      tags: <String>['h2s monitor', '4 gas', 'ppe', 'wellsite', 'tank entry'],
      marketplaceCategories: <String>[
        'Oilfield Equipment',
        'Tanks & Containers'
      ],
      fallbackIconAsset:
          'assets/images/industrial_icons/08-safety-and-security/01-safety-shield.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'carhartt-fr-henley-work-shirt',
      title:
          'Carhartt / Ariat Flame-Resistant (FR) CAT 2 NFPA 2112 Long-Sleeve Work Shirt',
      brand: 'Carhartt FR',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'ppe_fr_safety',
      subcategory: 'FR Shirts, Coveralls & Winter Outerwear',
      destinationUrl:
          'https://www.amazon.com/s?k=NFPA+2112+CAT+2+FR+Work+Shirt+Men+Oilfield',
      badgeText: 'NFPA 2112 / CAT 2',
      featured: false,
      priorityRank: 25,
      description:
          'UL-classified NFPA 2112 and NFPA 70E Arc-Rated CAT 2 flame-resistant field shirt built for lease operators, welders, and haulers.',
      highlights: <String>[
        'Meets NFPA 2112 & NFPA 70E ATPV >= 8.0 cal/cm²',
        'Exterior CAT 2 / 2112 compliance labels on sleeve',
        'Breathable moisture-wicking FR cotton blend',
      ],
      tags: <String>[
        'fr clothing',
        'nfpa 2112',
        'carhartt',
        'safety',
        'oilfield'
      ],
      marketplaceCategories: <String>['Oilfield Equipment', 'Pipe'],
      fallbackIconAsset:
          'assets/images/industrial_icons/08-safety-and-security/06-safety-hardhat.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'ansi-a6-oilfield-impact-rigger-gloves',
      title:
          'HexArmor / Superior ANSI Cut A6 TPR Back-of-Hand Oilfield Impact Rigging Gloves',
      brand: 'HexArmor',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'ppe_fr_safety',
      subcategory: 'ANSI Impact, Rigging & Cut Gloves',
      destinationUrl:
          'https://www.amazon.com/s?k=Oilfield+TPR+Impact+Gloves+ANSI+Cut+A6',
      badgeText: 'Pinch-Point Protection',
      featured: false,
      priorityRank: 30,
      description:
          'Full dorsal TPR metacarpal impact armor with oil-grip palm and ANSI A6 cut protection for pipe handling and rig floor work.',
      highlights: <String>[
        'ANSI/ISEA 138 Impact Level 2 back-of-hand TPR',
        'ANSI A6 cut-resistant liner for sharp pipe burrs',
        'Hi-vis colors for hand-signal visibility',
      ],
      tags: <String>['impact gloves', 'rigger gloves', 'ppe', 'pipe handling'],
      marketplaceCategories: <String>[
        'Pipe',
        'Oilfield Equipment',
        'Transport & Hauling'
      ],
      fallbackIconAsset:
          'assets/images/industrial_icons/08-safety-and-security/06-safety-hardhat.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'dot-truck-oil-spill-containment-kit',
      title:
          'Universal & Oil-Only DOT Service Truck Emergency Spill Kit in Weatherproof Duffel',
      brand: 'PIG / Brady',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'ppe_fr_safety',
      subcategory: 'Fall Protection, Spill Kits & First Aid',
      destinationUrl:
          'https://www.amazon.com/s?k=DOT+Truck+Emergency+Oil+Spill+Kit+Bag',
      badgeText: 'Lease Road Compliant',
      featured: false,
      priorityRank: 36,
      description:
          'Compact cab-behind or side-box spill response kit with absorbent socks, pads, nitrile gloves, and disposal bags required on lease sites.',
      highlights: <String>[
        'Absorbs up to 5–10 gallons of oil/hydraulics',
        'Hi-vis water-resistant vinyl truck bag',
        'Includes containment socks, pads & hazmat bags',
      ],
      tags: <String>[
        'spill kit',
        'containment',
        'dot',
        'tanker',
        'vacuum truck'
      ],
      marketplaceCategories: <String>[
        'Tanks & Containers',
        'Transport & Hauling'
      ],
      fallbackIconAsset:
          'assets/images/industrial_icons/26-marketplace-catalog-photos/spill-kit.svg',
      isStarterSeed: true,
    ),

    // 5. Fleet, Hydraulics & Field Service
    PipeBuyerShopProduct(
      id: 'milwaukee-m18-cordless-grease-gun',
      title:
          'Milwaukee M18 2-Speed Cordless Grease Gun (10,000 PSI Max Operating Pressure)',
      brand: 'Milwaukee',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'hydraulics_fleet_shop',
      subcategory: 'Grease Guns, Hose Reels & Lubrication',
      destinationUrl:
          'https://www.amazon.com/s?k=Milwaukee+2646-20+M18+2-Speed+Grease+Gun',
      badgeText: '10,000 PSI Heavy Iron',
      featured: true,
      priorityRank: 16,
      description:
          'Clears clogged excavator, loader, and trailer kingpin zerks effortlessly with 10,000 PSI pressure and pre-set grease counter dial.',
      highlights: <String>[
        '10,000 PSI max pressure / up to 10 oz/min flow',
        '48-inch flexible high-pressure hose with coupler',
        'Dispenses up to 10 cartridges per M18 charge',
      ],
      tags: <String>[
        'milwaukee',
        'grease gun',
        'excavator',
        'preventive maintenance'
      ],
      marketplaceCategories: <String>[
        'Heavy Equipment',
        'Transport & Hauling',
        'Farm & Ranch'
      ],
      fallbackIconAsset:
          'assets/images/industrial_icons/10-heavy-equipment/01-crawler-excavator.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'fill-rite-12v-15gpm-fuel-transfer-pump',
      title:
          'Fill-Rite FR1210H 12V DC 15-GPM Heavy-Duty Cast-Iron Fuel Transfer Pump w/ Nozzle',
      brand: 'Fill-Rite',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'hydraulics_fleet_shop',
      subcategory: 'Diesel Transfer Pumps, Meters & Filters',
      destinationUrl:
          'https://www.amazon.com/s?k=Fill-Rite+FR1210H+12V+15+GPM+Fuel+Transfer+Pump',
      badgeText: 'Slip-Tank Standard',
      featured: false,
      priorityRank: 20,
      description:
          'USA-built cast-iron rotary vane 12V fuel transfer pump for pickup slip tanks, diesel generators, and yellow iron refueling.',
      highlights: <String>[
        '15 GPM flow rate — diesel, kerosene & biodiesel',
        'Explosion-proof UL/cUL listed 1/4 HP motor',
        '2-inch bung mount for truck slip tanks & drums',
      ],
      tags: <String>['fill-rite', 'diesel pump', 'slip tank', 'fuel tank'],
      marketplaceCategories: <String>[
        'Tanks & Containers',
        'Heavy Equipment',
        'Farm & Ranch'
      ],
      fallbackIconAsset:
          'assets/images/industrial_icons/03-fuel-and-fluid-equipment/04-fuel-nozzle.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'noco-boost-pro-commercial-jump-starter',
      title:
          'NOCO Boost Pro GB150 / GB250+ 3000A–5250A Commercial 12V Diesel Jump Starter',
      brand: 'NOCO',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'hydraulics_fleet_shop',
      subcategory: '12V/24V Jump Packs, Chargers & HD Scanners',
      destinationUrl:
          'https://www.amazon.com/s?k=NOCO+Boost+Pro+GB150+3000A+12V+Jump+Starter',
      badgeText: 'Winter Fleet Saver',
      featured: false,
      priorityRank: 29,
      description:
          'Compact lithium jump starter rated for commercial diesel pickups, skid steers, generators, and cold-weather lease starts.',
      highlights: <String>[
        'Starts diesel engines up to 10.0L+',
        'Spark-proof clamps + reverse polarity protection',
        'Built-in digital voltmeter & 500-lumen worklight',
      ],
      tags: <String>['noco', 'jump starter', 'diesel', 'winter', 'fleet'],
      marketplaceCategories: <String>['Heavy Equipment', 'Transport & Hauling'],
      fallbackIconAsset:
          'assets/images/industrial_icons/05-commercial-vehicles/04-pickup-flatbed-truck.svg',
      isStarterSeed: true,
    ),

    // 6. Jobsite Lighting, Power & Storage
    PipeBuyerShopProduct(
      id: 'milwaukee-m18-rover-magnetic-floodlight',
      title:
          'Milwaukee M18 ROVER Magnetic Folding Flood Light / Tower Jobsite Light',
      brand: 'Milwaukee',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'lighting_power_jobsite',
      subcategory: 'Cordless Tower, Magnetic & Flood Lights',
      destinationUrl:
          'https://www.amazon.com/s?k=Milwaukee+M18+ROVER+Magnetic+Flood+Light',
      badgeText: 'Night Shift Ready',
      featured: false,
      priorityRank: 27,
      description:
          'High-output TRUEVIEW LED floodlight with heavy rare-earth magnets that clamp directly onto steel pipe, beams, and service truck beds.',
      highlights: <String>[
        'High-definition TRUEVIEW neutral white output',
        'Heavy-duty magnetic base grips steel pipe & I-beams',
        'IP54 dust/water resistant + impact-rated lens',
      ],
      tags: <String>[
        'milwaukee',
        'led light',
        'rover',
        'night shift',
        'magnetic'
      ],
      marketplaceCategories: <String>[
        'Portable Buildings',
        'Oilfield Equipment',
        'Heavy Equipment',
      ],
      fallbackIconAsset:
          'assets/images/industrial_icons/26-marketplace-catalog-photos/light-tower.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'crescent-jobox-48-steel-gang-box',
      title:
          'Crescent JOBOX 48-Inch Heavy-Duty Lockable Steel Site-Vault Chest',
      brand: 'Crescent JOBOX',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'lighting_power_jobsite',
      subcategory: 'Jobsite Gang Boxes, Truck Chests & Cases',
      destinationUrl:
          'https://www.amazon.com/s?k=Crescent+JOBOX+48+Inch+Site+Vault+Piano+Box',
      badgeText: 'Site-Vault Security',
      featured: false,
      priorityRank: 34,
      description:
          '14-gauge steel jobsite tool chest with Site-Vault padlock housing and 4-way forklift skids for yards, crew shacks, and trailers.',
      highlights: <String>[
        'Recessed padlock bunker resists bolt cutters',
        '4-way forklift skid bolsters for fast yard loading',
        'EZ-Loader anti-tip skid design',
      ],
      tags: <String>['jobox', 'gang box', 'tool storage', 'yard security'],
      marketplaceCategories: <String>[
        'Portable Buildings',
        'Land & Commercial Property'
      ],
      fallbackIconAsset:
          'assets/images/industrial_icons/26-marketplace-catalog-photos/tool-room.svg',
      isStarterSeed: true,
    ),

    // 7. Inspection, Gauges & Pipe Testing
    PipeBuyerShopProduct(
      id: 'ultrasonic-pipe-wall-thickness-gauge',
      title:
          'Digital Ultrasonic Pipe Wall Thickness Gauge (0.04"–11.8" Steel & OCTG Inspection)',
      brand: 'REED / Industrial NDT',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'measuring_inspection',
      subcategory: 'Ultrasonic Wall Thickness & NDT Kits',
      destinationUrl:
          'https://www.amazon.com/s?k=Digital+Ultrasonic+Thickness+Gauge+Steel+Pipe+Wall',
      badgeText: 'Pipe Buyer Essential',
      featured: true,
      priorityRank: 17,
      description:
          'Verify used line pipe, OCTG casing, pressure vessel, and frac tank steel wall thickness on-site before closing a deal.',
      highlights: <String>[
        'Measures steel, cast iron, aluminum & PVC wall thickness',
        'Includes 5MHz transducer probe & calibration block',
        'Essential for inspecting used pipe & tank wall loss',
      ],
      tags: <String>[
        'ultrasonic',
        'wall thickness',
        'pipe inspection',
        'octg',
        'casing'
      ],
      marketplaceCategories: <String>[
        'Pipe',
        'Tanks & Containers',
        'Oilfield Equipment'
      ],
      fallbackIconAsset:
          'assets/images/industrial_icons/17-pipe-and-materials/12-pipe-inspection-equipment.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'mitutoyo-stainless-digital-pipe-caliper',
      title:
          'Mitutoyo 500-196-30 Absolute Digimatic 0–6" / 0–8" Stainless Vernier Caliper',
      brand: 'Mitutoyo',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'measuring_inspection',
      subcategory: 'Pipe Calipers, Tally Tapes & Thread Gauges',
      destinationUrl:
          'https://www.amazon.com/s?k=Mitutoyo+500-196-30+Digital+Caliper+Stainless',
      badgeText: 'Precision +/-0.001"',
      featured: false,
      priorityRank: 31,
      description:
          'Shop and yard standard stainless digital caliper for verifying pipe OD/ID, wall schedule, hydraulic fittings, and thread pitch.',
      highlights: <String>[
        '0.0005" / 0.01mm resolution with instant inch/mm',
        'Hardened stainless steel jaws resist shop grime',
        'ABSOLUTE electromagnetic scale — no re-zeroing',
      ],
      tags: <String>[
        'mitutoyo',
        'caliper',
        'pipe od',
        'fittings',
        'inspection'
      ],
      marketplaceCategories: <String>['Pipe', 'Oilfield Equipment'],
      fallbackIconAsset:
          'assets/images/industrial_icons/17-pipe-and-materials/05-generic-fittings-assortment.svg',
      isStarterSeed: true,
    ),

    // 8. Farm, Ranch & Pipe Fencing Gear
    PipeBuyerShopProduct(
      id: 'gas-powered-pipe-tpost-driver',
      title: 'Heavy-Duty 4-Stroke Gas Powered T-Post & Pipe Fence Post Driver',
      brand: 'Titan / Redi-Driver',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'ranch_fencing_ag',
      subcategory: 'Gas Post Drivers, Augers & T-Post Tools',
      destinationUrl:
          'https://www.amazon.com/s?k=4+Stroke+Gas+Powered+Post+Driver+Pipe+Fence+T+Post',
      badgeText: 'Ranch Pipe Crew',
      featured: false,
      priorityRank: 23,
      description:
          'Portable gas post driver with interchangeable sleeves for driving T-posts, ground rods, and drill-stem/pipe fence posts without air hoses.',
      highlights: <String>[
        'Up to 1,700+ blows per minute — no compressor needed',
        'Includes adapter sleeves up to 3"+ OD pipe/post',
        'Cushioned anti-vibration handles + carry case',
      ],
      tags: <String>[
        'post driver',
        'pipe fence',
        'drill stem',
        'ranch',
        'corral'
      ],
      marketplaceCategories: <String>['Farm & Ranch', 'Pipe'],
      fallbackIconAsset:
          'assets/images/industrial_icons/18-farm-ranch-listings/04-fence-post.svg',
      isStarterSeed: true,
    ),
    PipeBuyerShopProduct(
      id: 'weld-on-steel-barrel-gate-hinges',
      title:
          'Heavy-Duty 7-Inch Weld-On Steel Barrel Hinges w/ Grease Zerks for Pipe Ranch Gates (4-Pairs)',
      brand: 'Ranch Fab Select',
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: 'ranch_fencing_ag',
      subcategory: 'Weld-On Hinges, Latches & Gate Hardware',
      destinationUrl:
          'https://www.amazon.com/s?k=Heavy+Duty+7+Inch+Weld+On+Barrel+Gate+Hinges+Grease+Zerk',
      badgeText: 'Drill-Stem Gate Ready',
      featured: false,
      priorityRank: 35,
      description:
          'Thick-wall weldable steel barrel hinges with ball-bearing pivot and grease fittings rated for heavy drill-stem pipe corral gates.',
      highlights: <String>[
        '900+ lb gate weight capacity per pair',
        'Built-in grease zerk fitting for smooth swing',
        'Uncoated mild steel welds cleanly to drill pipe',
      ],
      tags: <String>['weld on hinges', 'pipe gate', 'corral', 'ranch gate'],
      marketplaceCategories: <String>['Farm & Ranch', 'Pipe'],
      fallbackIconAsset:
          'assets/images/industrial_icons/12-farm-and-ranch/08-ranch-gate.svg',
      isStarterSeed: true,
    ),
  ];

  static List<PipeBuyerShopProduct> contextualProductsForMarketplace(
    String marketplaceCategory, {
    List<PipeBuyerShopProduct>? catalog,
    int limit = 3,
  }) {
    final source = catalog ?? starterCatalog;
    final active = source.where((p) => p.status == 'active').toList();
    final targetCat = categoryForMarketplaceCategory(marketplaceCategory);

    final matched = active.where((product) {
      if (product.categoryCode == targetCat.code) return true;
      return product.marketplaceCategories.any(
        (mc) => mc.toLowerCase() == marketplaceCategory.trim().toLowerCase(),
      );
    }).toList();

    matched.sort((a, b) {
      final aPrimary = a.categoryCode == targetCat.code ? 0 : 1;
      final bPrimary = b.categoryCode == targetCat.code ? 0 : 1;
      if (aPrimary != bPrimary) return aPrimary.compareTo(bPrimary);
      if (a.featured != b.featured) return a.featured ? -1 : 1;
      return a.priorityRank.compareTo(b.priorityRank);
    });

    if (matched.length >= limit) {
      return matched.take(limit).toList(growable: false);
    }
    final ids = matched.map((e) => e.id).toSet();
    for (final fallback in active) {
      if (ids.add(fallback.id)) {
        matched.add(fallback);
        if (matched.length >= limit) break;
      }
    }
    return matched;
  }
}
