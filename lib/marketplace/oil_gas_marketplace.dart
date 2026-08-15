import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/phase1_feature_flags.dart';
import '../core/accessibility/pipe_accessibility_theme.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/data/bounded_firestore_query.dart';
import '../core/diagnostics/app_diagnostics.dart';
import 'marketplace_actions_repository.dart';
import 'marketplace_auth_page.dart';
import 'marketplace_catalog_repository.dart';
import 'marketplace_command_client.dart';
import 'marketplace_location.dart';
import 'marketplace_location_picker.dart';
import 'marketplace_media_repository.dart';
import 'marketplace_search.dart';
import 'marketplace_money.dart';
import 'marketplace_navigation.dart';
import 'marketplace_reporting.dart';
import 'marketplace_messages_page.dart';
import 'marketplace_account_hub.dart';
import 'marketplace_grid_density.dart';
import 'marketplace_adaptive_shell.dart';
import 'marketplace_account_device_repository.dart';
import 'marketplace_admin_access.dart';
import 'marketplace_avatar_image.dart';
import 'marketplace_auctions_page.dart';
import 'marketplace_browse_filters.dart';
import 'marketplace_dispatch_page.dart';
import 'marketplace_deep_links.dart';
import 'marketplace_data_state.dart';
import 'marketplace_freight_quote.dart';
import 'industrial_icon_assets.dart';
import 'marketplace_listing_status.dart';
import 'marketplace_listing_media.dart';
import 'marketplace_offer_analysis.dart';
import 'marketplace_offer_commerce_summary.dart';
import 'marketplace_property_details.dart';
import 'marketplace_trucking_plan.dart';

const _navy = Color(0xFFF8FAFC);
const _panel = Colors.white;
const _orange = Color(0xFF0F52BA);
const _muted = Color(0xFF64748B);
const _otherCatalogValue = 'Other / not listed';

List<String> marketplaceConditionsFor(String? category, String? productType) {
  if (category == 'Pipe, Tubing & Materials' ||
      const {
        'Drill Pipe',
        'Casing',
        'Tubing',
        'Line Pipe',
        'OCTG',
        'Sucker Rod'
      }.contains(productType)) {
    return const [
      'New / never used',
      'New surplus',
      'Used — Premium class',
      'Used — Class 2',
      'Used — serviceable, class unknown',
      'Used — structural / farm use only',
      'Fair — wear or corrosion present',
      'Poor — repair or sorting required',
      'Reject / salvage / scrap',
    ];
  }
  if (category == 'Tanks & Containers') {
    return const [
      'New',
      'Like new',
      'Used — cleaned and inspected',
      'Used — leak tested',
      'Used — serviceable',
      'Fair — repairs recommended',
      'Poor — repair required',
      'For parts / salvage',
    ];
  }
  if (category == 'Site & Property') {
    return const [
      'Ready for use',
      'Developed / serviced',
      'Partially developed',
      'Vacant / undeveloped',
      'Repairs or remediation required',
    ];
  }
  return const [
    'New',
    'New surplus',
    'Like new',
    'Excellent',
    'Good',
    'Fair',
    'Poor — repair required',
    'For parts / not operational',
    'Salvage / scrap',
  ];
}

int naturalCompare(String left, String right) {
  final pattern = RegExp(r'(\d+(?:\.\d+)?)|([^\d]+)');
  final a = pattern.allMatches(left.toLowerCase()).toList();
  final b = pattern.allMatches(right.toLowerCase()).toList();
  for (var i = 0; i < a.length && i < b.length; i++) {
    final av = a[i].group(0)!;
    final bv = b[i].group(0)!;
    final an = num.tryParse(av);
    final bn = num.tryParse(bv);
    final result =
        an != null && bn != null ? an.compareTo(bn) : av.compareTo(bv);
    if (result != 0) return result;
  }
  return a.length.compareTo(b.length);
}

class MarketplaceCategory {
  const MarketplaceCategory(this.name, this.icon, this.types, this.description);

  final String name;
  final IconData icon;
  final List<String> types;
  final String description;
}

const marketplaceCategories = <MarketplaceCategory>[
  MarketplaceCategory(
      'Heavy Equipment',
      Icons.precision_manufacturing,
      [
        'Excavator',
        'Bulldozer',
        'Loader',
        'Backhoe',
        'Skid Steer',
        'Crane',
        'Telehandler',
        'Grader',
        'Compactor',
        'Forklift',
        'Drilling Rig'
      ],
      'Excavators, loaders, dozers, cranes and other industrial machinery.'),
  MarketplaceCategory(
      'Oil & Gas Equipment',
      Icons.oil_barrel,
      [
        'Wellhead',
        'Valves',
        'Manifold',
        'Separator',
        'Heater Treater',
        'Compressor',
        'Generator',
        'Pump',
        'Pressure Vessel',
        'Flare Stack'
      ],
      'Production, processing, pressure-control and field equipment.'),
  MarketplaceCategory(
      'Pipe, Tubing & Materials',
      Icons.horizontal_rule,
      [
        'Drill Pipe',
        'Drill Stem',
        'Casing',
        'Tubing',
        'Sucker Rod',
        'Line Pipe',
        'OCTG',
        'Culverts',
        'Fittings',
        'Flanges',
        'Steel Plate'
      ],
      'Pipe, OCTG, fittings, steel products and surplus materials.'),
  MarketplaceCategory(
      'Farm & Ranch Products',
      Icons.fence,
      [
        'Cattle Panel',
        'Buffalo / Bison Panel',
        'Windbreak Panel',
        'Fence Post',
        'Continuous Fence',
        'Cattle Feeder',
        'Bale Feeder',
        'Farm Gate',
        'Corral Panel',
        'Livestock Shelter',
        'Custom Pipe Fabrication'
      ],
      'Fencing, livestock systems, feeders, gates and fabricated products.'),
  MarketplaceCategory(
      'Tanks & Containers',
      Icons.propane_tank,
      [
        'Fuel Tank',
        'Water Tank',
        'Frac Tank',
        'Chemical Tank',
        'IBC Tote',
        'Propane Tank',
        'Vault Tank',
        'Tank Skid'
      ],
      'Fuel, water, chemical and process storage tanks or containers.'),
  MarketplaceCategory(
      'Transport & Hauling',
      Icons.local_shipping,
      [
        'Semi Truck',
        'Flatbed Trailer',
        'Lowboy Trailer',
        'Roll Off Truck',
        'Winch Truck',
        'Step Deck',
        'Drop Deck',
        'Vacuum Truck',
        'Water Truck'
      ],
      'Highway trucks, trailers, hauling units and specialized transport.'),
  MarketplaceCategory(
      'Portable Buildings',
      Icons.cabin,
      [
        'Portable Office',
        'Crew Shack',
        'Lunchroom',
        'Bathroom Unit',
        'Storage Unit',
        'Guard Shack',
        'Modular Building',
        'Container Office'
      ],
      'Offices, crew facilities, storage and modular site buildings.'),
  MarketplaceCategory(
      'Site Support',
      Icons.construction,
      [
        'Light Tower',
        'Air Compressor',
        'Welding Machine',
        'Generator',
        'Tool Room',
        'Scissor Lift',
        'Boom Lift',
        'Material Cage',
        'Spill Kit'
      ],
      'Power, lighting, access, safety and job-site support equipment.'),
  MarketplaceCategory(
      'Oilfield & Drilling',
      Icons.factory,
      [
        'Derrick',
        'Drill Rig',
        'Mud Pump',
        'Shale Shaker',
        'BOP',
        'Kelly Bar',
        'Drill Bit',
        'Fishing Tools',
        'Cementing Unit',
        'Mud Tank'
      ],
      'Drilling rigs, pressure control, mud systems and downhole tools.'),
  MarketplaceCategory(
      'Site & Property',
      Icons.location_city,
      [
        'Business for Sale',
        'Commercial Property',
        'Farm & Ranch Land',
        'Oil & Gas Lease',
        'Mineral Rights',
        'Surface Rights',
        'Lease Land',
        'Well Site',
        'Pipeline',
        'Battery Site',
        'Access Road',
        'Fenced Yard',
        'Gate',
        'Storage Yard',
        'Industrial Real Estate'
      ],
      'Industrial, commercial and agricultural property, businesses, leases and rights.'),
];

List<MarketplaceCategory> phase1MarketplaceCategories(
        {required bool regulatedListingsEnabled}) =>
    marketplaceCategories
        .where((category) =>
            category.name != 'Site & Property' || regulatedListingsEnabled)
        .toList(growable: false);

String marketplaceProductTypeDescription(
    String type, MarketplaceCategory category) {
  if (type == _otherCatalogValue) {
    return 'Enter the missing product type and send it for catalog review.';
  }
  final propertyDescription = propertyProductTypeDescriptions[type];
  if (propertyDescription != null) return propertyDescription;
  switch (category.name) {
    case 'Heavy Equipment':
      return 'Include year, hours, operating condition and attachments.';
    case 'Pipe, Tubing & Materials':
      return 'Include size, grade, length, inspection and available quantity.';
    case 'Farm & Ranch Products':
      return 'Include dimensions, material, quantity and intended use.';
    case 'Oil & Gas Equipment':
      return 'Include capacity, rating, certification and service condition.';
    case 'Tanks & Containers':
      return 'Include capacity, material, previous service and inspection.';
    case 'Transport & Hauling':
      return 'Include year, configuration, payload and operating condition.';
    case 'Portable Buildings':
      return 'Include dimensions, layout, utilities and transport condition.';
    case 'Site Support':
      return 'Include capacity, power source, runtime and operating condition.';
    case 'Oilfield & Drilling':
      return 'Include manufacturer, model, inspection and operating condition.';
    default:
      return category.description;
  }
}

const pipeNominalSizes = <String>[
  '1/4 in',
  '3/8 in',
  '1/2 in',
  '5/8 in',
  '3/4 in',
  '7/8 in',
  '1 in',
  '1-1/4 in',
  '1-1/2 in',
  '1-3/4 in',
  '2 in',
  '2-1/8 in',
  '2-3/8 in',
  '2-1/2 in',
  '2-7/8 in',
  '3 in',
  '3-1/2 in',
  '3-7/8 in',
  '4 in',
  '4-1/2 in',
  '5 in',
  '5-1/2 in',
  '5-7/8 in',
  '6 in',
  '6-5/8 in',
  '7 in',
  '7-5/8 in',
  '8 in',
  '8-5/8 in',
  '9-5/8 in',
  '10 in',
  '10-3/4 in',
  '11-3/4 in',
  '12 in',
  '13-3/8 in',
  '14 in',
  '16 in',
  '18 in',
  '20 in',
  '24 in',
  '30 in',
  '36 in',
  '42 in',
  '48 in'
];

const suckerRodSizes = <String>[
  '5/8 in',
  '3/4 in',
  '7/8 in',
  '1 in',
  '1-1/8 in'
];

const sellerFriendlyPipeTypes = <String>[
  'Not sure — buyer can verify',
  'Thin wall / light wall',
  'Standard wall',
  'Heavy wall',
  'Extra heavy wall',
  'Drill stem / drill pipe',
  'Production tubing',
  'Casing',
  'Sucker rod',
  'Yellow band / yellow coated',
  'Painted or powder coated',
  'Galvanized',
  'New surplus',
  'Used oilfield pipe'
];

const pipeSchedules = <String>[
  '5',
  '5S',
  '10',
  '10S',
  '20',
  '30',
  '40',
  '40S',
  '60',
  '80',
  '80S',
  '100',
  '120',
  '140',
  '160',
  'STD',
  'XS',
  'XXS'
];

const equipmentBrandModels = <String, List<String>>{
  'Caterpillar': ['301.8', '305 CR', '320', '336', '950 GC', '966', 'D6', 'D8'],
  'Komatsu': ['PC55MR-5', 'PC210LC-11', 'PC360LC-11', 'WA270-8', 'D65EX-18'],
  'Volvo CE': ['EC18E', 'ECR58', 'EC220E', 'EC300E', 'L90H', 'A40G'],
  'John Deere': ['35 P-Tier', '210 P-Tier', '350 P-Tier', '544 P-Tier', '850K'],
  'Hitachi': ['ZX50U-5N', 'ZX210LC-7', 'ZX350LC-7', 'ZW220-6'],
  'JCB': ['3CX', '4CX', '220X', '540-170', '270T'],
  'Bobcat': ['E35', 'E60', 'S650', 'T76', 'TL619'],
  'Case': ['580SV', 'CX210D', '621G', 'TV450B'],
  'Sullair': ['185 Series', '375 Series', '900H'],
  'Atlas Copco': ['XAS 188', 'XAS 400', 'QAS 45', 'QAS 150'],
  'Lincoln Electric': ['Ranger 250', 'Vantage 322', 'Air Vantage 600'],
  'Miller': ['Bobcat 265', 'Trailblazer 330', 'Big Blue 600'],
  'National Oilwell Varco': ['TDS-11SA', '14-P-220', 'FD-1600'],
  'Weatherford': ['MPD Package', 'Wellhead System', 'Rod Pump'],
};

IconData marketplaceIconFor(String? value) {
  final label = (value ?? '').toLowerCase();
  if (label.contains('excavator') || label.contains('backhoe')) {
    return Icons.precision_manufacturing;
  }
  if (label.contains('bulldozer') ||
      label.contains('loader') ||
      label.contains('grader')) {
    return Icons.agriculture;
  }
  if (label.contains('crane') ||
      label.contains('telehandler') ||
      label.contains('lift')) {
    return Icons.construction;
  }
  if (label.contains('forklift')) return Icons.forklift;
  if (label.contains('drill') ||
      label.contains('derrick') ||
      label.contains('rig')) {
    return Icons.factory;
  }
  if (label.contains('pipe') ||
      label.contains('tubing') ||
      label.contains('casing') ||
      label.contains('sucker rod')) {
    return Icons.horizontal_rule;
  }
  if (label.contains('tank') ||
      label.contains('vessel') ||
      label.contains('separator')) {
    return Icons.propane_tank;
  }
  if (label.contains('truck') ||
      label.contains('trailer') ||
      label.contains('deck')) {
    return Icons.local_shipping;
  }
  if (label.contains('office') ||
      label.contains('shack') ||
      label.contains('building') ||
      label.contains('shelter')) {
    return Icons.cabin;
  }
  if (label.contains('panel') ||
      label.contains('fence') ||
      label.contains('gate') ||
      label.contains('feeder')) {
    return Icons.fence;
  }
  if (label.contains('pump') ||
      label.contains('wellhead') ||
      label.contains('oil') ||
      label.contains('bop')) {
    return Icons.oil_barrel;
  }
  if (label.contains('generator') ||
      label.contains('compressor') ||
      label.contains('welding')) {
    return Icons.electrical_services;
  }
  if (label.contains('land') ||
      label.contains('site') ||
      label.contains('yard') ||
      label.contains('real estate')) {
    return Icons.location_city;
  }
  return Icons.warning_amber_rounded;
}

({IconData icon, Color color}) _conditionVisual(String value) {
  final label = value.toLowerCase();
  if (label.contains('new') ||
      label.contains('excellent') ||
      label.contains('ready for use')) {
    return (icon: Icons.verified_outlined, color: Colors.green);
  }
  if (label.contains('like new') ||
      label.contains('premium') ||
      label.contains('serviceable') ||
      label.contains('developed')) {
    return (icon: Icons.check_circle_outline, color: _orange);
  }
  if (label.contains('fair') ||
      label.contains('class 2') ||
      label.contains('partially') ||
      label.contains('wear')) {
    return (icon: Icons.warning_amber_outlined, color: Colors.orange);
  }
  if (label.contains('poor') ||
      label.contains('repair') ||
      label.contains('reject') ||
      label.contains('salvage') ||
      label.contains('scrap') ||
      label.contains('not operational')) {
    return (icon: Icons.build_circle_outlined, color: Colors.red);
  }
  return (icon: Icons.inventory_2_outlined, color: _orange);
}

({IconData icon, Color color}) _operatingStatusVisual(String value) {
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
    return (icon: Icons.handyman_outlined, color: _orange);
  }
  return (icon: Icons.help_outline, color: const Color(0xFF66758A));
}

({IconData icon, Color color}) _inspectionVisual(String value) {
  final label = value.toLowerCase();
  if (label.contains('report available') &&
      !label.contains('no report available')) {
    return (icon: Icons.task_alt_outlined, color: Colors.green);
  }
  if (label.contains('no report') || label.contains('required')) {
    return (icon: Icons.warning_amber_outlined, color: Colors.orange);
  }
  if (label.contains('visual')) {
    return (icon: Icons.visibility_outlined, color: _orange);
  }
  if (label.contains('previously')) {
    return (icon: Icons.history_outlined, color: const Color(0xFF66758A));
  }
  return (icon: Icons.help_outline, color: const Color(0xFF66758A));
}

IconData _listingTypeIcon(String value) => switch (value) {
      'For Sale' => Icons.sell_outlined,
      'For Rent' => Icons.event_available_outlined,
      'Request for Quote' => Icons.request_quote_outlined,
      _ => Icons.inventory_2_outlined,
    };

IconData _priceBasisIcon(String value) {
  final label = value.toLowerCase();
  if (label.contains('call')) return Icons.phone_outlined;
  if (label.contains('foot') || label.contains('metre')) {
    return Icons.straighten_outlined;
  }
  if (label.contains('joint')) return Icons.linear_scale_outlined;
  if (label.contains('bundle') || label.contains('piece')) {
    return Icons.inventory_2_outlined;
  }
  return Icons.calculate_outlined;
}

({IconData icon, Color color}) _pipeBandVisual(String value) {
  final label = value.toLowerCase();
  if (label.contains('multiple')) {
    return (icon: Icons.palette_outlined, color: _orange);
  }
  if (label.contains('white')) {
    return (icon: Icons.circle, color: const Color(0xFFB0BEC5));
  }
  if (label.contains('yellow')) {
    return (icon: Icons.circle, color: const Color(0xFFF9A825));
  }
  if (label.contains('blue')) {
    return (icon: Icons.circle, color: const Color(0xFF1976D2));
  }
  if (label.contains('green')) {
    return (icon: Icons.circle, color: const Color(0xFF2E7D32));
  }
  if (label.contains('orange')) {
    return (icon: Icons.circle, color: const Color(0xFFEF6C00));
  }
  if (label.contains('red')) {
    return (icon: Icons.circle, color: const Color(0xFFC62828));
  }
  if (label.contains('other')) {
    return (icon: Icons.edit_outlined, color: _orange);
  }
  return (icon: Icons.help_outline, color: const Color(0xFF66758A));
}

class CatalogIcon extends StatelessWidget {
  const CatalogIcon({
    super.key,
    this.label,
    this.fallbackLabel,
    this.size = 22,
  });
  final String? label;
  final String? fallbackLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = marketplaceIconFor(label);
    return IndustrialAssetIcon(
        label: label,
        assetPath: IndustrialIconAssets.forLabel(label) ??
            IndustrialIconAssets.forLabel(fallbackLabel),
        size: size,
        borderRadius: size < 28 ? 4 : 7,
        fallback: Icon(icon,
            size: size,
            color: icon == Icons.warning_amber_rounded
                ? const Color(0xFFFFC107)
                : _orange));
  }
}

class MarketplaceListing {
  const MarketplaceListing({
    this.documentId,
    required this.title,
    required this.category,
    required this.location,
    required this.price,
    required this.condition,
    required this.icon,
    this.badge,
    this.productType = '',
    this.description = '',
    this.details = const <String, dynamic>{},
    this.sellerUid = '',
    this.sellerName = 'Marketplace seller',
    this.sellerVerified = false,
    this.locationVisibility = LocationVisibility.approximate,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.createdAt,
    this.views = 0,
    this.saves = 0,
    this.shares = 0,
    this.messages = 0,
    this.boosted = false,
    this.numericPrice,
    this.quantity,
    this.priceBasis = '',
    this.transactionType = 'For Sale',
    this.offerCount = 0,
    this.pendingOfferCount = 0,
    this.saleStatus = '',
    this.acceptedOfferId = '',
    this.originalPrice,
    this.auctionEndAt,
  });

  final String? documentId;
  final String title;
  final String category;
  final String location;
  final String price;
  final String condition;
  final IconData icon;
  final String? badge;
  final String productType;
  final String description;
  final Map<String, dynamic> details;
  final String sellerUid;
  final String sellerName;
  final bool sellerVerified;
  final LocationVisibility locationVisibility;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final DateTime? createdAt;
  final int views;
  final int saves;
  final int shares;
  final int messages;
  final bool boosted;
  final num? numericPrice;
  final int? quantity;
  final String priceBasis;
  final String transactionType;
  final int offerCount;
  final int pendingOfferCount;
  final String saleStatus;
  final String acceptedOfferId;
  final num? originalPrice;
  final DateTime? auctionEndAt;
  String get id =>
      documentId ?? title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  List<String> get summaryFacts {
    final facts = <String>[];
    final acres = details['landAreaAcres'] as num?;
    final hectares = details['landAreaHectares'] as num?;
    final buildingArea = details['buildingAreaValue'] as num?;
    final buildingUnit = '${details['buildingAreaUnit'] ?? ''}';
    final annualRevenue = details['annualRevenue'] as num?;
    if (acres != null && acres > 0) {
      facts.add('${propertyMeasure(acres)} ac');
    } else if (hectares != null && hectares > 0) {
      facts.add('${propertyMeasure(hectares)} ha');
    }
    if (buildingArea != null && buildingArea > 0) {
      facts.add(
          '${propertyMeasure(buildingArea)} ${buildingUnit == 'Square metres' ? 'm²' : 'ft²'} building');
    }
    if (annualRevenue != null && annualRevenue > 0) {
      facts.add('${marketplaceMoney(annualRevenue)}/yr revenue');
    }
    return facts;
  }

  factory MarketplaceListing.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? const <String, dynamic>{};
    final price = data['price'];
    final basis = '${data['priceBasis'] ?? ''}';
    final transactionType = '${data['transactionType'] ?? 'For Sale'}';
    final isWanted = transactionType == 'Wanted / Seeking';
    return MarketplaceListing(
      documentId: document.id,
      title: '${data['title'] ?? 'Untitled listing'}',
      category: '${data['category'] ?? 'Other'}',
      location:
          '${data['publicLocationName'] ?? data['nearestTown'] ?? 'Location by request'}',
      price: price == null
          ? (isWanted ? 'Budget open' : 'Contact seller')
          : '${isWanted ? 'Target ' : ''}${marketplaceMoney(price as num)}${basis.isEmpty ? '' : ' • $basis'}',
      condition: '${data['condition'] ?? 'Condition not provided'}',
      icon: marketplaceIconFor('${data['productType'] ?? data['category']}'),
      productType: '${data['productType'] ?? ''}',
      description: '${data['description'] ?? ''}',
      details: Map<String, dynamic>.unmodifiable(data),
      badge: isWanted
          ? 'Wanted'
          : data['boostStatus'] == 'active'
              ? 'Boosted'
              : null,
      sellerUid: '${data['sellerUid'] ?? ''}',
      sellerName: '${data['sellerName'] ?? 'Marketplace seller'}',
      sellerVerified: data['sellerVerified'] == true,
      locationVisibility: locationVisibilityFromValue(
          '${data['locationVisibility'] ?? 'approximate'}'),
      latitude: (data['publicGeoPoint'] as GeoPoint?)?.latitude,
      longitude: (data['publicGeoPoint'] as GeoPoint?)?.longitude,
      imageUrl: marketplaceListingThumbnailUrl(data),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      views: (data['viewCount'] as num?)?.toInt() ?? 0,
      saves: (data['saveCount'] as num?)?.toInt() ?? 0,
      shares: (data['shareCount'] as num?)?.toInt() ?? 0,
      messages: (data['messageCount'] as num?)?.toInt() ?? 0,
      boosted: data['boostStatus'] == 'active',
      numericPrice: price as num?,
      quantity: (data['quantity'] as num?)?.toInt(),
      priceBasis: basis,
      transactionType: transactionType,
      offerCount: (data['offerCount'] as num?)?.toInt() ?? 0,
      pendingOfferCount: (data['pendingOfferCount'] as num?)?.toInt() ?? 0,
      saleStatus: '${data['saleStatus'] ?? data['offerStatus'] ?? ''}',
      acceptedOfferId: '${data['acceptedOfferId'] ?? ''}',
      originalPrice: data['originalPrice'] as num? ??
          data['initialPrice'] as num? ??
          data['previousPrice'] as num?,
      auctionEndAt: (data['auctionEndAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Full-page listing destination used by browser refreshes and shared links.
class MarketplaceListingRoutePage extends StatefulWidget {
  const MarketplaceListingRoutePage({super.key, required this.listingId});

  final String listingId;

  @override
  State<MarketplaceListingRoutePage> createState() =>
      _MarketplaceListingRoutePageState();
}

class _MarketplaceListingRoutePageState
    extends State<MarketplaceListingRoutePage> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _listing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _listing = FirebaseFirestore.instance
        .collection('public_listings')
        .doc(widget.listingId)
        .get();
  }

  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          title: const Text('Marketplace listing'),
          actions: [
            IconButton(
              tooltip: 'Marketplace home',
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_outlined),
            ),
          ],
        ),
        body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _listing,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MarketplaceRouteLoadFailure(
                title: 'Listing could not be loaded',
                message:
                    'Check your connection or account access, then try again.',
                onRetry: _retry,
              );
            }
            final document = snapshot.data;
            if (document == null || !document.exists) {
              return _MarketplaceRouteLoadFailure(
                title: 'Listing unavailable',
                message:
                    'This listing may have been removed, archived, or the link may be incorrect.',
                onRetry: _retry,
              );
            }
            return _ListingDetails(
              MarketplaceListing.fromFirestore(document),
              fullPage: true,
            );
          },
        ),
      );
}

class _MarketplaceRouteLoadFailure extends StatelessWidget {
  const _MarketplaceRouteLoadFailure({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.link_off_outlined,
                size: 48, color: Colors.deepOrange),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Return to Marketplace'),
            ),
          ]),
        ),
      );
}

class OilGasMarketplaceApp extends StatefulWidget {
  const OilGasMarketplaceApp({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<OilGasMarketplaceApp> createState() => _OilGasMarketplaceAppState();
}

class _OilGasMarketplaceAppState extends State<OilGasMarketplaceApp> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _tab;
  String _search = '';
  String? _category;
  final Set<String> _saved = {};
  final Set<String> _savingListingIds = {};
  final Map<String, String> _savedRequestIds = {};
  final _actions = MarketplaceActionsRepository();
  final _featureRepository = Phase1FeatureFlagRepository();
  final _deviceRepository = MarketplaceAccountDeviceRepository();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<Set<String>>? _savedSubscription;
  StreamSubscription<Phase1FeatureFlags>? _featureSubscription;
  Phase1FeatureFlags _features = Phase1FeatureFlags.safeDefaults;
  bool _createAuctionRequested = false;
  bool _createWantedRequested = false;
  bool _savedLoading = false;
  Object? _savedLoadError;

  void _openCreate({bool auction = false, bool wanted = false}) {
    if (!_features.marketplace) {
      _showFeatureUnavailable('Marketplace');
      return;
    }
    if (auction && !_features.auctions) {
      _showFeatureUnavailable('Auctions');
      return;
    }
    if (wanted && !_features.wantedAds) {
      _showFeatureUnavailable('Wanted ads');
      return;
    }
    setState(() {
      _createAuctionRequested = auction;
      _createWantedRequested = wanted;
      _tab = 2;
    });
  }

  void _handleHomeRequest() {
    if (mounted && _tab != 0) setState(() => _tab = 0);
  }

  void _selectTab(int index) {
    setState(() => _tab = index);
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _selectControlledTab(int index, bool enabled, String label) {
    if (!enabled) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      _showFeatureUnavailable(label);
      return;
    }
    _selectTab(index);
  }

  void _showFeatureUnavailable(String label) {
    PipeFeedback.show(
      context,
      message:
          '$label is temporarily unavailable. No account or listing data was changed.',
      tone: PipeStatusTone.warning,
    );
  }

  void _handleFeatureFlags(Phase1FeatureFlags flags) {
    if (!mounted) return;
    setState(() {
      _features = flags;
      if ((_tab == 1 || _tab == 2 || _tab == 3) && !flags.marketplace) {
        _tab = 0;
      } else if (_tab == 6 && !flags.auctions) {
        _tab = 0;
      } else if (_tab == 7 && !flags.dispatch) {
        _tab = 0;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 6);
    MarketplaceNavigation.homeRequests.addListener(_handleHomeRequest);
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(_handleAuthChanged);
    _featureSubscription = _featureRepository.watch().listen(
      _handleFeatureFlags,
      onError: (Object error, StackTrace stackTrace) {
        AppDiagnostics.record(
          error,
          stackTrace,
          subsystem: 'feature_flags',
          operation: 'watch_phase1_configuration',
          fatal: false,
        );
        _handleFeatureFlags(Phase1FeatureFlags.safeDefaults);
      },
    );
  }

  @override
  void dispose() {
    MarketplaceNavigation.homeRequests.removeListener(_handleHomeRequest);
    _authSubscription?.cancel();
    _savedSubscription?.cancel();
    _featureSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(
          onBrowse: () =>
              _selectControlledTab(1, _features.marketplace, 'Marketplace'),
          onList: () => _openCreate(),
          onAuctions: () =>
              _selectControlledTab(6, _features.auctions, 'Auctions'),
          onDispatch: () =>
              _selectControlledTab(7, _features.dispatch, 'Dispatch'),
          features: _features,
          saved: _saved,
          onSaved: _toggleSaved,
          onCategory: (value) => setState(() {
                _category = value;
                _tab = 1;
              })),
      _features.marketplace
          ? _BrowsePage(
              features: _features,
              search: _search,
              category: _category,
              saved: _saved,
              onSearch: (value) => setState(() => _search = value),
              onCategory: (value) => setState(() => _category = value),
              onSaved: _toggleSaved)
          : const _FeatureUnavailablePage(feature: 'Marketplace'),
      _features.marketplace
          ? _StableCreateListingPage(
              key: ValueKey(
                  '${_createAuctionRequested}_${_createWantedRequested}_${_features.revision}'),
              initialAuction: _createAuctionRequested,
              initialWanted: _createWantedRequested,
              auctionsEnabled: _features.auctions,
              wantedAdsEnabled: _features.wantedAds,
              regulatedListingsEnabled: _features.regulatedListings,
              paidFeaturesEnabled: _features.paidFeatures,
              onHome: () => setState(() => _tab = 0))
          : const _FeatureUnavailablePage(feature: 'Marketplace'),
      _features.marketplace
          ? _SavedPage(
              saved: _saved,
              signedIn: FirebaseAuth.instance.currentUser != null,
              loading: _savedLoading,
              error: _savedLoadError,
              onBrowse: () => _selectControlledTab(
                1,
                _features.marketplace,
                'Marketplace',
              ),
              onSaved: _toggleSaved,
              onRemove: _removeSavedListing,
              onAccount: () => _selectTab(5),
              onRetry: () =>
                  _handleAuthChanged(FirebaseAuth.instance.currentUser),
            )
          : const _FeatureUnavailablePage(feature: 'Marketplace'),
      const MarketplaceMessagesPage(),
      MarketplaceAccountHub(
          onAddListing: () => _openCreate(),
          auctionsEnabled: _features.auctions,
          paidFeaturesEnabled: _features.paidFeatures,
          onBrowse: () =>
              _selectControlledTab(1, _features.marketplace, 'Marketplace')),
      _features.auctions
          ? MarketplaceAuctionsPage(
              onCreateAuction: () => _openCreate(auction: true))
          : const _FeatureUnavailablePage(feature: 'Auctions'),
      _features.dispatch
          ? const MarketplaceDispatchPage()
          : const _FeatureUnavailablePage(feature: 'Dispatch'),
    ];

    return Theme(
      data: PipeAccessibilityTheme.apply(
        ThemeData.light(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: _navy,
          colorScheme: const ColorScheme.light(
            primary: _orange,
            surface: _panel,
            onSurface: Color(0xFF17202A),
          ),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF0F5FA),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none)),
        ),
      ),
      child: MarketplaceAdaptiveShell(
        scaffoldKey: _scaffoldKey,
        selectedPageIndex: _tab,
        title: const [
          'Home',
          'Marketplace',
          'Create Listing',
          'Saved',
          'Messages',
          'Profile',
          'Auctions',
          'Dispatch'
        ][_tab],
        backgroundColor: _navy,
        navigationBackgroundColor: Colors.white,
        indicatorColor: _orange.withValues(alpha: .18),
        onDestinationSelected: (target) {
          if (target == 2) {
            _openCreate();
            return;
          }
          if (target == 1 || target == 3) {
            _selectControlledTab(
              target,
              _features.marketplace,
              'Marketplace',
            );
            return;
          }
          if (target == 6) {
            _selectControlledTab(target, _features.auctions, 'Auctions');
            return;
          }
          if (target == 7) {
            _selectControlledTab(target, _features.dispatch, 'Dispatch');
            return;
          }
          _selectTab(target);
        },
        compactDestinations: <MarketplaceShellDestination>[
          const MarketplaceShellDestination(
            pageIndex: 0,
            label: 'Home',
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
          ),
          if (_features.marketplace) ...[
            const MarketplaceShellDestination(
              pageIndex: 1,
              label: 'Browse',
              icon: Icon(Icons.search),
            ),
            const MarketplaceShellDestination(
              pageIndex: 2,
              label: 'List',
              icon: Icon(Icons.add_box_outlined),
              selectedIcon: Icon(Icons.add_box),
            ),
          ],
          const MarketplaceShellDestination(
            pageIndex: 4,
            label: 'Messages',
            icon: _NavMessageIcon(selected: false),
            selectedIcon: _NavMessageIcon(selected: true),
          ),
          const MarketplaceShellDestination(
            pageIndex: 5,
            label: 'Profile',
            icon: _NavAccountIcon(selected: false),
            selectedIcon: _NavAccountIcon(selected: true),
          ),
        ],
        railDestinations: <MarketplaceShellDestination>[
          const MarketplaceShellDestination(
            pageIndex: 0,
            label: 'Home',
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
          ),
          if (_features.marketplace) ...[
            const MarketplaceShellDestination(
              pageIndex: 1,
              label: 'Browse Marketplace',
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
            ),
            const MarketplaceShellDestination(
              pageIndex: 2,
              label: 'Create Listing',
              icon: Icon(Icons.add_box_outlined),
              selectedIcon: Icon(Icons.add_box),
            ),
            const MarketplaceShellDestination(
              pageIndex: 3,
              label: 'Saved Listings',
              icon: Icon(Icons.bookmark_border),
              selectedIcon: Icon(Icons.bookmark),
            ),
          ],
          const MarketplaceShellDestination(
            pageIndex: 4,
            label: 'Messages',
            icon: _NavMessageIcon(selected: false),
            selectedIcon: _NavMessageIcon(selected: true),
          ),
          const MarketplaceShellDestination(
            pageIndex: 5,
            label: 'Profile',
            icon: _NavAccountIcon(selected: false),
            selectedIcon: _NavAccountIcon(selected: true),
          ),
          if (_features.auctions)
            const MarketplaceShellDestination(
              pageIndex: 6,
              label: 'Auctions',
              icon: Icon(Icons.gavel_outlined),
              selectedIcon: Icon(Icons.gavel),
            ),
          if (_features.dispatch)
            const MarketplaceShellDestination(
              pageIndex: 7,
              label: 'Dispatch',
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping),
            ),
        ],
        railLeading: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Tooltip(
            message: 'Pipe Buyer marketplace',
            child: Image.asset(
              'assets/images/pipe_buyer_logo.png',
              width: 54,
              height: 42,
              fit: BoxFit.contain,
            ),
          ),
        ),
        railFooter: LayoutBuilder(
          builder: (context, constraints) {
            final signedIn = FirebaseAuth.instance.currentUser != null;
            final extended = constraints.maxWidth >= 180;
            final icon = signedIn ? Icons.logout : Icons.login;
            final label = signedIn ? 'Sign out' : 'Sign in';
            final onPressed = signedIn ? _signOut : _openAuth;
            if (!extended) {
              return IconButton(
                tooltip: label,
                onPressed: onPressed,
                icon: Icon(icon),
              );
            }
            return OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            );
          },
        ),
        actions: [
          if (_features.marketplace)
            PipeAccessibleIconButton(
              label: 'Search Marketplace',
              onTapHint: 'Opens Marketplace search',
              onPressed: () => _selectTab(1),
              icon: const Icon(Icons.search_rounded),
            ),
        ],
        drawer: Drawer(
          backgroundColor: Colors.white,
          child: SafeArea(
            child: Column(children: [
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(20, 10, 16, 14),
                leading: Image.asset(
                  'assets/images/pipe_buyer_logo.png',
                  width: 54,
                  height: 42,
                  fit: BoxFit.contain,
                ),
                title: const Text(
                  'PIPE BUYER',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('Oilfield marketplace'),
              ),
              const Divider(height: 1),
              _DrawerDestination(
                icon: Icons.home_outlined,
                label: 'Home',
                selected: _tab == 0,
                onTap: () => _selectTab(0),
              ),
              if (_features.marketplace) ...[
                _DrawerDestination(
                  icon: Icons.storefront_outlined,
                  label: 'Browse Marketplace',
                  selected: _tab == 1,
                  onTap: () => _selectTab(1),
                ),
                _DrawerDestination(
                  icon: Icons.add_box_outlined,
                  label: 'Create Listing',
                  selected: _tab == 2,
                  onTap: () {
                    Navigator.of(context).pop();
                    _openCreate();
                  },
                ),
                _DrawerDestination(
                  icon: Icons.request_quote_outlined,
                  label: 'Wanted ads & RFQs',
                  selected: false,
                  onTap: () {
                    Navigator.of(context).pop();
                    _openCreate(wanted: true);
                  },
                ),
                _DrawerDestination(
                  icon: Icons.bookmark_border,
                  label: 'Saved Listings',
                  selected: _tab == 3,
                  onTap: () => _selectTab(3),
                ),
              ],
              if (_features.auctions)
                _DrawerDestination(
                  icon: Icons.gavel_outlined,
                  label: 'Auctions',
                  selected: _tab == 6,
                  onTap: () => _selectTab(6),
                ),
              if (_features.dispatch)
                _DrawerDestination(
                  icon: Icons.local_shipping_outlined,
                  label: 'Dispatch',
                  selected: _tab == 7,
                  onTap: () => _selectTab(7),
                ),
              _DrawerDestination(
                icon: Icons.forum_outlined,
                label: 'Messages',
                selected: _tab == 4,
                trailing: _unreadBadge(),
                onTap: () => _selectTab(4),
              ),
              const Spacer(),
              const Divider(height: 1),
              _DrawerDestination(
                icon: Icons.person_outline,
                label: 'Account & Seller Profile',
                selected: _tab == 5,
                trailing: const _ProfileCompletionBadge(),
                onTap: () => _selectTab(5),
              ),
              if (FirebaseAuth.instance.currentUser != null)
                _DrawerDestination(
                  icon: Icons.logout,
                  label: 'Sign out',
                  selected: false,
                  onTap: _signOut,
                )
              else
                _DrawerDestination(
                  icon: Icons.login,
                  label: 'Sign in / Create account',
                  selected: false,
                  onTap: _openAuth,
                ),
            ]),
          ),
        ),
        body: IndexedStack(index: _tab, children: pages),
      ),
    );
  }

  Future<void> _toggleSaved(MarketplaceListing listing) async {
    final saving = !_saved.contains(listing.id);
    if (_savingListingIds.contains(listing.id)) return;
    _savingListingIds.add(listing.id);
    setState(() => saving ? _saved.add(listing.id) : _saved.remove(listing.id));
    final requestKey = '${listing.id}:$saving';
    final requestId = _savedRequestIds[requestKey] ??=
        'saved-${listing.id}-$saving-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await _actions.setSavedListing(
        listing.id,
        saving,
        requestId: requestId,
      );
      _savedRequestIds.remove(requestKey);
    } catch (error) {
      if (!mounted) return;
      setState(
          () => saving ? _saved.remove(listing.id) : _saved.add(listing.id));
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(
          error,
          fallback: 'Could not update saved listings. Try again.',
        ),
        tone: PipeStatusTone.error,
      );
    } finally {
      _savingListingIds.remove(listing.id);
    }
  }

  Future<void> _removeSavedListing(String listingId) async {
    if (_savingListingIds.contains(listingId)) return;
    _savingListingIds.add(listingId);
    setState(() => _saved.remove(listingId));
    final requestKey = '$listingId:false';
    final requestId = _savedRequestIds[requestKey] ??=
        'saved-$listingId-false-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await _actions.setSavedListing(
        listingId,
        false,
        requestId: requestId,
      );
      _savedRequestIds.remove(requestKey);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saved.add(listingId));
      PipeFeedback.show(
        context,
        message: 'Could not remove the saved listing. Try again.',
        tone: PipeStatusTone.error,
      );
    } finally {
      _savingListingIds.remove(listingId);
    }
  }

  void _handleAuthChanged(User? user) {
    _savedSubscription?.cancel();
    _savedSubscription = null;
    if (!mounted) return;
    setState(() {
      _saved.clear();
      _savedLoadError = null;
      _savedLoading = user != null;
    });
    if (user == null) return;
    unawaited(_registerCurrentDevice(user));
    final userUid = user.uid;
    _savedSubscription = _actions.watchSavedListingIds(userUid).listen(
      (listingIds) {
        if (!mounted || FirebaseAuth.instance.currentUser?.uid != userUid) {
          return;
        }
        setState(() {
          _saved
            ..clear()
            ..addAll(listingIds);
          _savedLoading = false;
          _savedLoadError = null;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        AppDiagnostics.record(
          error,
          stackTrace,
          subsystem: 'marketplace',
          operation: 'watch_saved_listings',
          fatal: false,
        );
        if (!mounted || FirebaseAuth.instance.currentUser?.uid != userUid) {
          return;
        }
        setState(() {
          _savedLoading = false;
          _savedLoadError = error;
        });
      },
    );
  }

  Future<void> _registerCurrentDevice(User user) async {
    try {
      await _deviceRepository.registerCurrentDevice();
    } catch (error, stackTrace) {
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;
      AppDiagnostics.record(
        error,
        stackTrace,
        subsystem: 'account_security',
        operation: 'register_account_device',
        fatal: false,
      );
    }
  }

  Widget _unreadBadge() => StreamBuilder<int>(
      stream: MarketplaceMessagesPage.unreadCountStream(),
      builder: (_, snapshot) => (snapshot.data ?? 0) > 0
          ? Badge(label: Text('${snapshot.data}'))
          : const SizedBox.shrink());

  Future<void> _openAuth() async {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    final signedIn = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MarketplaceAuthPage()));
    if (mounted) {
      setState(() {});
      if (signedIn == true) {
        PipeFeedback.show(
          context,
          message: 'Signed in successfully. Your account is ready.',
          tone: PipeStatusTone.success,
        );
      }
    }
  }

  Future<void> _signOut() async {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.logout, size: 34),
            title: const Text('Sign out?'),
            content:
                const Text('You can sign back in from the marketplace menu.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Sign out'))
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() => _tab = 0);
      PipeFeedback.show(
        context,
        message: 'Signed out successfully. Sign in again from the menu.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(
          error,
          fallback: 'Sign out failed. Check your connection and try again.',
        ),
        tone: PipeStatusTone.error,
      );
    }
  }
}

class _NavAccountIcon extends StatelessWidget {
  const _NavAccountIcon({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) => StreamBuilder<int>(
      stream: MarketplaceMessagesPage.accountNotificationCountStream(),
      builder: (_, notificationSnapshot) =>
          _ProfileCompletionStream(builder: (completion) {
            final notifications = notificationSnapshot.data ?? 0;
            return Badge(
                isLabelVisible: notifications > 0 || completion < 100,
                label:
                    Text(notifications > 0 ? '$notifications' : '$completion%'),
                backgroundColor:
                    notifications > 0 ? Colors.red : const Color(0xFF0878E8),
                child: Icon(selected ? Icons.person : Icons.person_outline));
          }));
}

class _ProfileCompletionBadge extends StatelessWidget {
  const _ProfileCompletionBadge();

  @override
  Widget build(BuildContext context) => _ProfileCompletionStream(
      builder: (completion) => completion < 100
          ? Badge(label: Text('$completion%'))
          : const Icon(Icons.check_circle, color: Colors.green, size: 20));
}

class _ProfileCompletionStream extends StatelessWidget {
  const _ProfileCompletionStream({required this.builder});
  final Widget Function(int completion) builder;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return builder(0);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return builder(100);
          }
          final user = FirebaseAuth.instance.currentUser;
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          return builder(calculateProfileCompletion(user, data));
        });
  }
}

class _NavMessageIcon extends StatelessWidget {
  const _NavMessageIcon({required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) => StreamBuilder<int>(
      stream: MarketplaceMessagesPage.unreadCountStream(),
      builder: (_, snapshot) => Badge(
          isLabelVisible: (snapshot.data ?? 0) > 0,
          label: Text('${snapshot.data ?? 0}'),
          child: Icon(selected ? Icons.forum : Icons.forum_outlined)));
}

class _DrawerDestination extends StatelessWidget {
  const _DrawerDestination(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap,
      this.trailing});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
          selected: selected,
          selectedColor: _orange,
          selectedTileColor: const Color(0xFFEAF4FD),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(icon, size: 21),
          trailing: trailing,
          title: Text(label,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          onTap: onTap));
}

class _FeatureUnavailablePage extends StatelessWidget {
  const _FeatureUnavailablePage({required this.feature});

  final String feature;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_clock_outlined,
                    size: 46,
                    color: _muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$feature is temporarily unavailable',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This section is safely paused while it is being reviewed. '
                    'Your account and existing information have not changed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => MarketplaceNavigation.goHome(context),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Return home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _HomePage extends StatelessWidget {
  const _HomePage(
      {required this.onBrowse,
      required this.onList,
      required this.onAuctions,
      required this.onDispatch,
      required this.features,
      required this.saved,
      required this.onSaved,
      required this.onCategory});
  final VoidCallback onBrowse;
  final VoidCallback onList;
  final VoidCallback onAuctions;
  final VoidCallback onDispatch;
  final Phase1FeatureFlags features;
  final Set<String> saved;
  final ValueChanged<MarketplaceListing> onSaved;
  final ValueChanged<String> onCategory;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Executive Hero Header Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F172A), // Slate Midnight
                      Color(0xFF0F52BA), // Deep Cobalt Blue
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x220F52BA),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 10,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset('assets/images/pipe_buyer_logo.png',
                                width: 44, height: 36, fit: BoxFit.contain),
                            const SizedBox(width: 8),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PIPE BUYER',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                Text(
                                  'Buy & Sell Marketplace for Oil & Gas Products Globally',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0x3338BDF8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x6638BDF8)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.monetization_on_outlined,
                                  size: 14, color: Color(0xFF38BDF8)),
                              SizedBox(width: 4),
                              Text(
                                'Low-Fee Marketplace',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Buy & Sell Marketplace for Oil & Gas Products Globally',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (features.marketplace) ...[
                      InkWell(
                        onTap: onBrowse,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.search, color: _orange, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Search pipe, valves, tanks, tubing…',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Spacer(),
                              Icon(Icons.tune_rounded,
                                  color: Color(0xFF64748B), size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: const [
                            ('Drill Pipe', Icons.horizontal_rule_rounded),
                            ('Frac Tanks', Icons.oil_barrel_outlined),
                            ('Choke Valves', Icons.settings_input_component),
                            ('Excavators', Icons.precision_manufacturing),
                            ('Tubing & Casing', Icons.view_stream_outlined),
                          ]
                              .map((item) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _HeroDiscoveryChip(
                                      label: item.$1,
                                      icon: item.$2,
                                      onTap: () => onCategory(item.$1),
                                    ),
                                  ))
                              .toList(growable: false),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _HomeQuickActions(
                features: features,
                onBrowse: onBrowse,
                onList: onList,
                onAuctions: onAuctions,
                onDispatch: onDispatch,
              ),
              if (features.marketplace) ...[
                const _CompactHeading('Categories'),
                _HomeCategoryStrip(
                  regulatedListingsEnabled: features.regulatedListings,
                  onCategory: onCategory,
                ),
                _CompactHeading(
                  'Featured near you',
                  action: 'See all',
                  onAction: onBrowse,
                ),
                _FeaturedListings(
                  regulatedListingsEnabled: features.regulatedListings,
                  onBrowse: onBrowse,
                  saved: saved,
                  onSaved: onSaved,
                ),
              ] else
                _HomeServiceNotice(
                  message:
                      'Marketplace browsing and listing are temporarily paused.',
                ),
            ],
          ),
        ),
      );
}

class _HeroDiscoveryChip extends StatelessWidget {
  const _HeroDiscoveryChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Browse $label listings',
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFF),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFB8D7FA)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: const Color(0xFF075EB8)),
                    const SizedBox(width: 7),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 11.5,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions({
    required this.features,
    required this.onBrowse,
    required this.onList,
    required this.onAuctions,
    required this.onDispatch,
  });

  final Phase1FeatureFlags features;
  final VoidCallback onBrowse;
  final VoidCallback onList;
  final VoidCallback onAuctions;
  final VoidCallback onDispatch;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (features.marketplace)
        _QuickAction(
          icon: Icons.storefront_outlined,
          assetPath: IndustrialIconAssets.forLabel('Browse'),
          label: 'Browse marketplace',
          color: _orange,
          onTap: onBrowse,
        ),
      if (features.marketplace)
        _QuickAction(
          icon: Icons.add_circle_outline,
          assetPath: IndustrialIconAssets.forLabel('Sell'),
          label: 'Create listing',
          color: const Color(0xFFF97316),
          onTap: onList,
        ),
      if (features.auctions)
        _QuickAction(
          icon: Icons.gavel_outlined,
          assetPath: IndustrialIconAssets.forLabel('Auctions'),
          label: 'Timed auctions',
          color: const Color(0xFF7557D3),
          onTap: onAuctions,
        ),
      if (features.dispatch)
        _QuickAction(
          icon: Icons.local_shipping_outlined,
          assetPath: IndustrialIconAssets.forLabel('Dispatch'),
          label: 'Dispatch services',
          color: const Color(0xFF008B78),
          onTap: onDispatch,
        ),
    ];

    if (actions.isEmpty) {
      return _HomeServiceNotice(
        message: 'Marketplace services are temporarily paused.',
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 12.0;
      final columns = constraints.maxWidth >= 760
          ? actions.length.clamp(1, 4)
          : constraints.maxWidth >= 430
              ? actions.length.clamp(1, 2)
              : 1;
      final width =
          (constraints.maxWidth - (spacing * (columns - 1))) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: actions
            .map((action) => SizedBox(width: width, child: action))
            .toList(growable: false),
      );
    });
  }
}

class _HomeCategoryStrip extends StatelessWidget {
  const _HomeCategoryStrip({
    required this.regulatedListingsEnabled,
    required this.onCategory,
  });

  final bool regulatedListingsEnabled;
  final ValueChanged<String> onCategory;

  @override
  Widget build(BuildContext context) {
    final categories = phase1MarketplaceCategories(
      regulatedListingsEnabled: regulatedListingsEnabled,
    );
    return SizedBox(
      height: 156,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = categories[index];
          final assetPath = IndustrialIconAssets.forLabel(item.name);
          return InkWell(
            onTap: () => onCategory(item.name),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 164,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x160F172A),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MarketplaceArtworkPanel(
                      label: item.name,
                      assetPath: assetPath,
                      fallbackIcon: item.icon,
                      borderRadius: 0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF172033),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: _orange,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeServiceNotice extends StatelessWidget {
  const _HomeServiceNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: _muted),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
}

class _MarketplaceArtworkPanel extends StatelessWidget {
  const _MarketplaceArtworkPanel({
    required this.label,
    required this.assetPath,
    required this.fallbackIcon,
    this.borderRadius = 16,
  });

  final String label;
  final String? assetPath;
  final IconData fallbackIcon;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final artSize = (constraints.biggest.shortestSide - 10)
              .clamp(44.0, 240.0)
              .toDouble();
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF041F3D),
                  Color(0xFF0B3A67),
                  Color(0xFF07559A),
                ],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned(
                  right: -30,
                  top: -42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x1738BDF8),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: 130),
                  ),
                ),
                const Positioned(
                  left: -48,
                  bottom: -62,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x12FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: 150),
                  ),
                ),
                Center(
                  child: IndustrialAssetIcon(
                    label: label,
                    assetPath: assetPath,
                    size: artSize,
                    borderRadius: borderRadius == 0 ? 12 : borderRadius - 2,
                    fit: BoxFit.contain,
                    fallback: Icon(
                      fallbackIcon,
                      size: artSize * .44,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    this.assetPath,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String? assetPath;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (description, actionLabel) = switch (label) {
      'Browse marketplace' => (
          'Shop equipment, materials and property',
          'Explore listings'
        ),
      'Create listing' => (
          'Sell, auction or post a wanted ad',
          'Start listing'
        ),
      'Timed auctions' => (
          'Live bids, reserve pricing and history',
          'View auctions'
        ),
      'Dispatch services' => (
          'Carrier quotes, jobs and fleet tools',
          'Open Dispatch'
        ),
      _ => ('Open Pipe Buyer services', 'Continue'),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 116),
          child: Ink(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: .16),
                  Colors.white,
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: .30)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: .12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF062A51),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26041F3D),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: IndustrialAssetIcon(
                    label: label,
                    assetPath: assetPath,
                    size: 76,
                    borderRadius: 15,
                    fallback: Icon(icon, color: Colors.white, size: 34),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.25,
                          color: Color(0xFF526278),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              actionLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactHeading extends StatelessWidget {
  const _CompactHeading(this.title, {this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 9),
      child: Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900))),
        if (action != null && action!.isNotEmpty)
          TextButton(onPressed: onAction, child: Text(action!))
      ]));
}

class _FeaturedListings extends StatelessWidget {
  const _FeaturedListings({
    required this.regulatedListingsEnabled,
    required this.onBrowse,
    required this.saved,
    required this.onSaved,
  });

  final bool regulatedListingsEnabled;
  final VoidCallback onBrowse;
  final Set<String> saved;
  final ValueChanged<MarketplaceListing> onSaved;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('public_listings')
            .where('status', isEqualTo: 'active')
            .limit(6)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _HomeFeedNotice(
              icon: Icons.cloud_off_outlined,
              message: 'Featured listings could not be loaded.',
              action: 'Browse marketplace',
              onAction: onBrowse,
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final live = snapshot.data!.docs
              .map((doc) {
                try {
                  return MarketplaceListing.fromFirestore(doc);
                } catch (_) {
                  return null;
                }
              })
              .whereType<MarketplaceListing>()
              .where((listing) =>
                  listing.transactionType != 'Auction' &&
                  (listing.category != 'Site & Property' ||
                      regulatedListingsEnabled))
              .take(3)
              .toList(growable: false);
          if (live.isEmpty) {
            return _HomeFeedNotice(
              icon: Icons.inventory_2_outlined,
              message: 'No active listings yet.',
              action: 'Browse marketplace',
              onAction: onBrowse,
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 860
                  ? 3
                  : (constraints.maxWidth >= 360 ? 2 : 1);
              const spacing = 14.0;
              final totalSpacing = spacing * (crossAxisCount - 1);
              final cardWidth =
                  (constraints.maxWidth - totalSpacing) / crossAxisCount;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: live
                    .map((item) => SizedBox(
                          width: cardWidth,
                          child: _ListingCard(
                            listing: item,
                            saved: saved.contains(item.id),
                            onSaved: () => onSaved(item),
                            isGrid: true,
                          ),
                        ))
                    .toList(growable: false),
              );
            },
          );
        },
      );
}

class _HomeFeedNotice extends StatelessWidget {
  const _HomeFeedNotice({
    required this.icon,
    required this.message,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: _muted),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
              TextButton(onPressed: onAction, child: Text(action)),
            ],
          ),
        ),
      );
}

class _BrowsePage extends StatefulWidget {
  const _BrowsePage(
      {required this.features,
      required this.search,
      required this.category,
      required this.saved,
      required this.onSearch,
      required this.onCategory,
      required this.onSaved});
  final Phase1FeatureFlags features;
  final String search;
  final String? category;
  final Set<String> saved;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onCategory;
  final ValueChanged<MarketplaceListing> onSaved;

  @override
  State<_BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<_BrowsePage> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _documents = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _cursor;
  MarketplaceBrowseFilters _filters = const MarketplaceBrowseFilters();
  bool _loading = false;
  bool _hasMore = true;
  String? _loadError;
  int _queryGeneration = 0;
  Timer? _searchDebounce;
  int _gridColumns = 4;

  @override
  void initState() {
    super.initState();
    _loadPage(reset: true);
  }

  @override
  void didUpdateWidget(covariant _BrowsePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      final allowedConditions = marketplaceConditionsFor(widget.category, null);
      if (_filters.condition != null &&
          !allowedConditions.contains(_filters.condition)) {
        _filters = _filters.copyWith(clearCondition: true);
      }
      _searchDebounce?.cancel();
      _loadPage(reset: true);
    } else if (marketplaceSearchNeedsServerReload(
        oldWidget.search, widget.search)) {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(
        const Duration(milliseconds: 350),
        () {
          if (mounted) _loadPage(reset: true);
        },
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Query<Map<String, dynamic>> _query() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('public_listings');
    final searchToken = normalizeMarketplaceSearchQuery(widget.search);
    if (searchToken.isNotEmpty) {
      query = query.where('searchTokens', arrayContains: searchToken);
    }
    return query.orderBy('createdAt', descending: true);
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_loading && !reset) return;
    if (!reset && !_hasMore) return;
    final generation = reset ? ++_queryGeneration : _queryGeneration;
    setState(() {
      _loading = true;
      _loadError = null;
      if (reset) {
        _documents.clear();
        _cursor = null;
        _hasMore = true;
      }
    });
    try {
      final page = await loadFirestoreDocumentPage(
        _query(),
        after: reset ? null : _cursor,
      );
      if (!mounted || generation != _queryGeneration) return;
      final merged = appendUniqueById(
          reset
              ? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]
              : _documents,
          page.documents,
          (document) => document.id);
      setState(() {
        _documents
          ..clear()
          ..addAll(merged);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
      });
    } on FirebaseException catch (error) {
      if (!mounted || generation != _queryGeneration) return;
      setState(() => _loadError = error.code == 'failed-precondition'
          ? 'Marketplace search is preparing its index. Try again shortly.'
          : 'Listings could not be loaded. Check your connection and retry.');
    } catch (_) {
      if (mounted && generation == _queryGeneration) {
        setState(() => _loadError =
            'Listings could not be loaded. Check your connection and retry.');
      }
    } finally {
      if (mounted && generation == _queryGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveListings =
        _documents.map(MarketplaceListing.fromFirestore).toList();
    final results = liveListings
        .where((item) =>
            item.transactionType != 'Auction' &&
            (item.category != 'Site & Property' ||
                widget.features.regulatedListings) &&
            (widget.category == null || item.category == widget.category) &&
            (_filters.transactionType == null ||
                item.transactionType == _filters.transactionType) &&
            (_filters.condition == null ||
                item.condition == _filters.condition) &&
            (_filters.minimumPrice == null ||
                (item.numericPrice != null &&
                    item.numericPrice! >= _filters.minimumPrice!)) &&
            (_filters.maximumPrice == null ||
                (item.numericPrice != null &&
                    item.numericPrice! <= _filters.maximumPrice!)))
        .toList();
    if (normalizeMarketplaceSearchQuery(widget.search).isNotEmpty) {
      results.sort((a, b) => switch (_filters.effectiveSort) {
            MarketplaceBrowseSort.newest => (b.createdAt ?? DateTime(2000))
                .compareTo(a.createdAt ?? DateTime(2000)),
            MarketplaceBrowseSort.priceLowToHigh =>
              (a.numericPrice ?? double.infinity)
                  .compareTo(b.numericPrice ?? double.infinity),
            MarketplaceBrowseSort.priceHighToLow =>
              (b.numericPrice ?? double.negativeInfinity)
                  .compareTo(a.numericPrice ?? double.negativeInfinity),
          });
    }
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _WelcomeUser(),
            const SizedBox(height: 4),
            const Text('Marketplace',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const Text('Find equipment quickly by search, category or map.',
                style: TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
                onChanged: widget.onSearch,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search all live listings…',
                    helperText:
                        'Indexed keyword search covers live Marketplace inventory.')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => _showCategoryPicker(
                          context,
                          widget.category,
                          widget.features.regulatedListings,
                          widget.onCategory),
                      icon: const Icon(Icons.grid_view_rounded, size: 18),
                      label: Text(widget.category ?? 'All categories'))),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                  tooltip: 'Listing color key',
                  onPressed: () => showMarketplaceListingLegend(context),
                  icon: const Icon(Icons.info_outline_rounded)),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                  tooltip: 'Map view',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MarketplaceMapSheet())),
                  icon: const Icon(Icons.map_outlined)),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                  tooltip: 'More filters',
                  onPressed: _showFilters,
                  icon: Badge(
                      isLabelVisible: _filters.activeCount > 0,
                      label: Text('${_filters.activeCount}'),
                      child: const Icon(Icons.tune_rounded))),
            ]),
            const SizedBox(height: 9),
            Row(children: [
              Text('${results.length} shown • ${_documents.length} loaded',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              MarketplaceGridDensityBar(
                selectedColumns: _gridColumns,
                onChanged: (cols) => setState(() => _gridColumns = cols),
              ),
              if (widget.category != null) ...[
                const SizedBox(width: 6),
                ActionChip(
                    avatar: const Icon(Icons.close, size: 15),
                    label: Text(widget.category!,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: () => widget.onCategory(null))
              ],
            ]),
            if (_filters.activeCount > 0) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (_filters.transactionType != null)
                  InputChip(
                      label: Text(_filters.transactionType!),
                      onDeleted: () => _applyFilters(
                          _filters.copyWith(clearTransactionType: true))),
                if (_filters.condition != null)
                  InputChip(
                      label: Text(_filters.condition!),
                      onDeleted: () => _applyFilters(
                          _filters.copyWith(clearCondition: true))),
                if (_filters.minimumPrice != null)
                  InputChip(
                      label: Text(
                          'From ${marketplaceMoney(_filters.minimumPrice!)}'),
                      onDeleted: () => _applyFilters(
                          _filters.copyWith(clearMinimumPrice: true))),
                if (_filters.maximumPrice != null)
                  InputChip(
                      label: Text(
                          'To ${marketplaceMoney(_filters.maximumPrice!)}'),
                      onDeleted: () => _applyFilters(
                          _filters.copyWith(clearMaximumPrice: true))),
                if (_filters.sort != MarketplaceBrowseSort.newest)
                  InputChip(
                      label: Text(marketplaceBrowseSortLabel(_filters.sort)),
                      onDeleted: () => _applyFilters(_filters.copyWith(
                          sort: MarketplaceBrowseSort.newest))),
              ])
            ]
          ])),
      Expanded(child: _buildResults(results)),
    ]);
  }

  Widget _buildResults(List<MarketplaceListing> results) {
    if (_loading && _documents.isEmpty) {
      return const MarketplaceDataStateView.loading(
        title: 'Loading Marketplace listings',
        message: 'Retrieving current sale and wanted inventory…',
      );
    }
    if (_loadError != null && _documents.isEmpty) {
      return MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.error,
        title: 'Marketplace listings could not be loaded',
        message: _loadError!,
        primaryLabel: 'Retry',
        primaryIcon: Icons.refresh,
        onPrimary: () => _loadPage(reset: true),
      );
    }
    if (results.isEmpty) {
      final wanted = _filters.transactionType == 'Wanted / Seeking';
      return MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.empty,
        icon: wanted ? Icons.campaign_outlined : Icons.search_off_outlined,
        title: wanted ? 'No wanted ads match' : 'No listings match',
        message: wanted
            ? 'Adjust the filters or check additional pages for buyer requests.'
            : 'Adjust the search or filters to broaden the Marketplace results.',
        primaryLabel: _hasMore ? 'Search more listings' : null,
        primaryIcon: Icons.expand_more_rounded,
        onPrimary: _hasMore && !_loading ? _loadPage : null,
      );
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveCols =
        MarketplaceGridDensityBar.resolveColumns(screenWidth, _gridColumns);
    if (effectiveCols > 1) {
      final aspectRatio = effectiveCols == 2
          ? 0.84
          : effectiveCols == 3
              ? 0.76
              : 0.68;
      return RefreshIndicator(
        onRefresh: () => _loadPage(reset: true),
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: effectiveCols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: results.length + 1,
          itemBuilder: (context, index) {
            if (index == results.length) {
              return Center(
                child: _hasMore
                    ? OutlinedButton(
                        onPressed: _loading ? null : _loadPage,
                        child: Text(_loading ? 'Loading…' : 'Load more'),
                      )
                    : const SizedBox.shrink(),
              );
            }
            final item = results[index];
            return _ListingCard(
              listing: item,
              saved: widget.saved.contains(item.id),
              onSaved: () => widget.onSaved(item),
              isGrid: true,
            );
          },
        ),
      );
    }
    return RefreshIndicator(
        onRefresh: () => _loadPage(reset: true),
        child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: results.length + 1,
            itemBuilder: (context, index) {
              if (index == results.length) {
                return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    child: _hasMore
                        ? OutlinedButton.icon(
                            onPressed: _loading ? null : _loadPage,
                            icon: _loading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.expand_more),
                            label: Text(_loading
                                ? 'Loading more…'
                                : 'Load more listings'))
                        : const Center(
                            child: Text('You have reached the end.',
                                style: TextStyle(color: _muted))));
              }
              final item = results[index];
              return _ListingCard(
                  listing: item,
                  saved: widget.saved.contains(item.id),
                  onSaved: () => widget.onSaved(item));
            }));
  }

  void _applyFilters(MarketplaceBrowseFilters filters) {
    setState(() => _filters = filters);
    _loadPage(reset: true);
  }

  Future<void> _showFilters() async {
    final minimumController = TextEditingController(
        text: _filters.minimumPrice?.toStringAsFixed(2) ?? '');
    final maximumController = TextEditingController(
        text: _filters.maximumPrice?.toStringAsFixed(2) ?? '');
    var draft = _filters;
    String? errorMessage;
    final conditions = <String>{
      ...marketplaceConditionsFor(null, null),
      ...marketplaceConditionsFor('Pipe, Tubing & Materials', null),
      ...marketplaceConditionsFor('Tanks & Containers', null),
      ...marketplaceConditionsFor('Site & Property', null),
    }.toList()
      ..sort();
    final selectedCondition =
        conditions.contains(draft.condition) ? draft.condition : null;
    if (selectedCondition == null && draft.condition != null) {
      draft = draft.copyWith(clearCondition: true);
    }

    final result = await showModalBottomSheet<MarketplaceBrowseFilters>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => StatefulBuilder(
            builder: (context, setSheetState) => Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 18, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Row(children: [
                        const Icon(Icons.tune_rounded, color: _orange),
                        const SizedBox(width: 10),
                        const Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Filter Marketplace',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900)),
                              Text('Filters search the complete live inventory',
                                  style:
                                      TextStyle(color: _muted, fontSize: 12)),
                            ])),
                        IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close))
                      ]),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                          initialValue: draft.transactionType ?? '__all__',
                          decoration: const InputDecoration(
                              labelText: 'Listing type',
                              prefixIcon: Icon(Icons.sell_outlined)),
                          items: const [
                            DropdownMenuItem(
                                value: '__all__',
                                child: Text('All Marketplace listings')),
                            DropdownMenuItem(
                                value: 'For Sale', child: Text('For sale')),
                            DropdownMenuItem(
                                value: 'Wanted / Seeking',
                                child: Text('Wanted / seeking')),
                          ],
                          onChanged: (value) => setSheetState(() => draft =
                              value == null || value == '__all__'
                                  ? draft.copyWith(clearTransactionType: true)
                                  : draft.copyWith(transactionType: value))),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          initialValue: draft.condition ?? '__all__',
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Condition / quality',
                              prefixIcon: Icon(Icons.fact_check_outlined)),
                          items: [
                            const DropdownMenuItem(
                                value: '__all__',
                                child: Text('All conditions')),
                            ...conditions.map((condition) => DropdownMenuItem(
                                value: condition,
                                child: Text(condition,
                                    overflow: TextOverflow.ellipsis)))
                          ],
                          onChanged: (value) => setSheetState(() => draft =
                              value == null || value == '__all__'
                                  ? draft.copyWith(clearCondition: true)
                                  : draft.copyWith(condition: value))),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: minimumController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Minimum price',
                                    prefixText: '\$ '))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: TextField(
                                controller: maximumController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Maximum price',
                                    prefixText: '\$ ')))
                      ]),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<MarketplaceBrowseSort>(
                          initialValue: draft.sort,
                          decoration: const InputDecoration(
                              labelText: 'Sort results',
                              prefixIcon: Icon(Icons.sort_rounded)),
                          items: MarketplaceBrowseSort.values
                              .map((sort) => DropdownMenuItem(
                                  value: sort,
                                  child:
                                      Text(marketplaceBrowseSortLabel(sort))))
                              .toList(),
                          onChanged: (value) => setSheetState(() => draft =
                              draft.copyWith(
                                  sort:
                                      value ?? MarketplaceBrowseSort.newest))),
                      const SizedBox(height: 12),
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: const Color(0xFFEAF4FF),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 19, color: _orange),
                                SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        'Listings without a numeric price are excluded from price ranges and price sorting. Price ranges use price order so every page remains accurate.',
                                        style: TextStyle(fontSize: 12)))
                              ])),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.w700))
                      ],
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () => Navigator.pop(sheetContext,
                                    const MarketplaceBrowseFilters()),
                                child: const Text('Clear all'))),
                        const SizedBox(width: 10),
                        Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                                onPressed: () {
                                  final minimumText =
                                      minimumController.text.trim();
                                  final maximumText =
                                      maximumController.text.trim();
                                  final minimum = minimumText.isEmpty
                                      ? null
                                      : marketplaceMoneyValue(minimumText)
                                          ?.toDouble();
                                  final maximum = maximumText.isEmpty
                                      ? null
                                      : marketplaceMoneyValue(maximumText)
                                          ?.toDouble();
                                  if ((minimumText.isNotEmpty &&
                                          minimum == null) ||
                                      (maximumText.isNotEmpty &&
                                          maximum == null)) {
                                    setSheetState(() => errorMessage =
                                        'Enter valid numeric price amounts.');
                                    return;
                                  }
                                  var candidate = MarketplaceBrowseFilters(
                                      transactionType: draft.transactionType,
                                      condition: draft.condition,
                                      minimumPrice: minimum,
                                      maximumPrice: maximum,
                                      sort: draft.sort);
                                  final validation =
                                      candidate.validationMessage;
                                  if (validation != null) {
                                    setSheetState(
                                        () => errorMessage = validation);
                                    return;
                                  }
                                  if (candidate.hasPriceRange &&
                                      candidate.sort ==
                                          MarketplaceBrowseSort.newest) {
                                    candidate = candidate.copyWith(
                                        sort: MarketplaceBrowseSort
                                            .priceLowToHigh);
                                  }
                                  Navigator.pop(sheetContext, candidate);
                                },
                                icon: const Icon(Icons.check),
                                label: const Text('Apply filters')))
                      ])
                    ])))));
    minimumController.dispose();
    maximumController.dispose();
    if (result != null && mounted) _applyFilters(result);
  }

  static Future<void> _showCategoryPicker(
      BuildContext context,
      String? selected,
      bool regulatedListingsEnabled,
      ValueChanged<String?> onCategory) async {
    final value = await showModalBottomSheet<String?>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Browse categories',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount:
                        MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
                    childAspectRatio: 1.05,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      _CategoryPickerTile(
                          label: 'All listings',
                          icon: Icons.apps,
                          selected: selected == null,
                          onTap: () => Navigator.pop(context, '__all__')),
                      ...phase1MarketplaceCategories(
                        regulatedListingsEnabled: regulatedListingsEnabled,
                      ).map((item) => _CategoryPickerTile(
                          label: item.name,
                          icon: item.icon,
                          selected: selected == item.name,
                          onTap: () => Navigator.pop(context, item.name)))
                    ],
                  )
                ]),
              ),
            ));
    if (value == '__all__') onCategory(null);
    if (value != null && value != '__all__') onCategory(value);
  }
}

class _WelcomeUser extends StatelessWidget {
  const _WelcomeUser();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final candidates = [
            data['businessName'],
            data['displayName'],
            data['fullName'],
            data['name'],
            user.displayName,
            user.email?.split('@').first,
          ];
          final name = candidates
              .map((value) => '${value ?? ''}'.trim())
              .firstWhere((value) => value.isNotEmpty, orElse: () => 'User');
          return Text('Welcome, $name',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _orange, fontSize: 15, fontWeight: FontWeight.w800));
        });
  }
}

class _CategoryPickerTile extends StatelessWidget {
  const _CategoryPickerTile(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: selected ? const Color(0xFFF0F7FF) : Colors.white,
      shape: RoundedRectangleBorder(
          side: BorderSide(
              color: selected ? _orange : const Color(0xFFD8E0E9),
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
                child: _MarketplaceArtworkPanel(
                    label: label,
                    assetPath: IndustrialIconAssets.forLabel(label),
                    fallbackIcon: icon,
                    borderRadius: 0)),
            Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 8, 10),
                child: Row(children: [
                  Expanded(
                      child: Text(label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              height: 1.15,
                              fontSize: 12,
                              fontWeight: FontWeight.w800))),
                  if (selected)
                    const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child:
                            Icon(Icons.check_circle, size: 18, color: _orange))
                ]))
          ])));
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.listing,
    required this.saved,
    required this.onSaved,
    this.isGrid = false,
  });

  final MarketplaceListing listing;
  final bool saved;
  final VoidCallback onSaved;
  final bool isGrid;

  @override
  Widget build(BuildContext context) {
    final fallbackAssetPath = listing.transactionType == 'Wanted / Seeking'
        ? IndustrialIconAssets.wantedEquipment
        : IndustrialIconAssets.forLabel(listing.title) ??
            IndustrialIconAssets.forLabel(listing.category);
    Widget fallbackArtwork() => _MarketplaceArtworkPanel(
          label: listing.title,
          assetPath: fallbackAssetPath,
          fallbackIcon: listing.icon,
          borderRadius: 0,
        );
    final presentation = MarketplaceListingPresentation.fromMap({
      'sellerUid': listing.sellerUid,
      'createdAt': listing.createdAt,
      'price': listing.numericPrice,
      'originalPrice': listing.originalPrice,
      'offerCount': listing.offerCount,
      'pendingOfferCount': listing.pendingOfferCount,
      'saleStatus': listing.saleStatus,
      'acceptedOfferId': listing.acceptedOfferId,
      'auctionEndAt': listing.auctionEndAt,
    }, currentUserUid: FirebaseAuth.instance.currentUser?.uid);
    return Container(
      margin:
          isGrid ? EdgeInsets.zero : const EdgeInsets.fromLTRB(14, 6, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: presentation.emphasized
              ? presentation.borderColor
              : const Color(0xFFE2E8F0),
          width: presentation.emphasized ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: presentation.emphasized
                ? presentation.shadowColor.withValues(alpha: .25)
                : const Color(0x0F0F172A),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => listing.documentId == null
              ? showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: _panel,
                  builder: (_) => _ListingDetails(listing))
              : context.push(MarketplaceDeepLinks.listing(listing.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Hero Thumbnail Header
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: isGrid ? 1.34 : 2.1,
                    child: listing.imageUrl == null
                        ? fallbackArtwork()
                        : Image.network(
                            listing.imageUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, __, ___) => fallbackArtwork(),
                          ),
                  ),
                  // Gradient Overlay for readability
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x33000000),
                            Colors.transparent,
                            Color(0x22000000),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Top Left Badges
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xE60F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            listing.condition.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        if (presentation.badges.isNotEmpty)
                          MarketplaceListingBadges(
                              badges: presentation.badges, compact: true),
                      ],
                    ),
                  ),
                  // Top Right Save Heart Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xCCFFFFFF),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: IconButton(
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        tooltip: saved
                            ? 'Remove from saved listings'
                            : 'Save listing',
                        onPressed: onSaved,
                        icon: Icon(
                          saved ? Icons.bookmark : Icons.bookmark_border,
                          size: 20,
                          color: saved ? _orange : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Card Details Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (listing.badge ?? listing.category).toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _orange,
                              fontSize: 10,
                              fontWeight: listing.badge != null
                                  ? FontWeight.w900
                                  : FontWeight.w800,
                              letterSpacing: listing.badge != null ? 0.5 : 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: _muted,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  listing.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (listing.summaryFacts.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        listing.summaryFacts.take(3).join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            listing.price,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF075EB8),
                              fontSize: 18,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8),
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFE8EEF5)),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        // Seller Avatar & Info
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFFEFF6FF),
                          child: Text(
                            listing.sellerName.isNotEmpty
                                ? listing.sellerName[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              color: _orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  listing.sellerName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (listing.sellerVerified)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.verified,
                                      size: 13, color: _orange),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.storefront_outlined,
                            size: 15, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListingDetails extends StatefulWidget {
  const _ListingDetails(this.listing, {this.fullPage = false});
  final MarketplaceListing listing;
  final bool fullPage;
  @override
  State<_ListingDetails> createState() => _ListingDetailsState();
}

class _ListingDetailsState extends State<_ListingDetails> {
  final _actions = MarketplaceActionsRepository();
  final _featureRepository = Phase1FeatureFlagRepository();
  StreamSubscription<Phase1FeatureFlags>? _featureSubscription;
  Phase1FeatureFlags _features = Phase1FeatureFlags.safeDefaults;
  bool _following = false;
  bool _notifications = false;
  String? _statusMessage;
  MarketplaceListing get listing => widget.listing;
  bool get _isWanted => listing.transactionType == 'Wanted / Seeking';

  @override
  void initState() {
    super.initState();
    _featureSubscription = _featureRepository.watch().listen(
      (features) {
        if (mounted) setState(() => _features = features);
      },
      onError: (Object error, StackTrace stackTrace) {
        AppDiagnostics.record(
          error,
          stackTrace,
          subsystem: 'feature_flags',
          operation: 'watch_listing_details_configuration',
          fatal: false,
        );
        if (mounted) {
          setState(() => _features = Phase1FeatureFlags.safeDefaults);
        }
      },
    );
    if (listing.documentId != null &&
        FirebaseAuth.instance.currentUser != null) {
      _actions.recordListingEvent(listing.id, 'view').catchError((_) {});
    }
  }

  @override
  void dispose() {
    _featureSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullPage) return _buildDetails(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      minChildSize: .55,
      maxChildSize: .96,
      builder: (context, controller) => _buildDetails(
        context,
        controller: controller,
      ),
    );
  }

  Widget _buildDetails(BuildContext context, {ScrollController? controller}) =>
      ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
              18, 12, 18, MediaQuery.viewPaddingOf(context).bottom + 24),
          children: [
            if (!widget.fullPage)
              Center(
                  child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4)))),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton.filledTonal(
                  tooltip: 'Copy shareable listing link',
                  onPressed: _copyShareLink,
                  icon: const Icon(Icons.link_outlined)),
              const SizedBox(width: 6),
              Stack(clipBehavior: Clip.none, children: [
                IconButton.filledTonal(
                    tooltip: 'Listing messages',
                    onPressed: _messageSeller,
                    icon: const Icon(Icons.chat_bubble_outline)),
                Positioned(
                    right: -2,
                    top: -2,
                    child: ListingMessageBadge(
                        listingId: listing.id, sellerUid: listing.sellerUid))
              ])
            ]),
            if (_statusMessage != null)
              Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEAF8F1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_statusMessage!)),
                    IconButton(
                        tooltip: 'Dismiss status message',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _statusMessage = null),
                        icon: const Icon(Icons.close, size: 18))
                  ])),
            const SizedBox(height: 16),
            Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: const Color(0xFFEAF4FD),
                    borderRadius: BorderRadius.circular(18)),
                child: listing.imageUrl == null
                    ? Center(
                        child: IndustrialAssetIcon(
                            label: listing.title,
                            assetPath: _isWanted
                                ? IndustrialIconAssets.wantedEquipment
                                : IndustrialIconAssets.forLabel(
                                        listing.title) ??
                                    IndustrialIconAssets.forLabel(
                                        listing.category),
                            size: 136,
                            borderRadius: 18,
                            fallback:
                                Icon(listing.icon, size: 90, color: _orange)))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(listing.imageUrl!,
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                                child: Icon(listing.icon,
                                    size: 90, color: _orange))))),
            const SizedBox(height: 20),
            Text(listing.category.toUpperCase(),
                style: const TextStyle(
                    color: _orange, fontWeight: FontWeight.w800, fontSize: 11)),
            Text(listing.title,
                style:
                    const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('${listing.condition}  •  ${listing.location}',
                style: const TextStyle(color: _muted)),
            const SizedBox(height: 10),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                    color: const Color(0xFFEAF4FD),
                    borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.payments_outlined, color: _orange),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('LISTING PRICE',
                            style: TextStyle(
                                color: _muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                        Text(listing.price,
                            style: const TextStyle(
                                color: Color(0xFF16324F),
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                      ]))
                ])),
            const SizedBox(height: 14),
            Material(
                color: const Color(0xFFF4F7FA),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _showSellerProfile,
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          MarketplaceUserAvatar(
                              userUid: listing.sellerUid,
                              size: 40,
                              fallback: Center(
                                  child: Text(
                                      listing.sellerName.isEmpty
                                          ? '?'
                                          : listing.sellerName[0],
                                      style: const TextStyle(
                                          color: _orange,
                                          fontWeight: FontWeight.w900)))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(children: [
                                  Flexible(
                                      child: Text(listing.sellerName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800))),
                                  if (listing.sellerVerified)
                                    const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.verified,
                                            size: 16, color: _orange))
                                ]),
                                Text(
                                    _isWanted
                                        ? 'View buyer profile and wanted ads'
                                        : 'View seller profile and listings',
                                    style: const TextStyle(
                                        color: _muted, fontSize: 11))
                              ])),
                          const Icon(Icons.chevron_right)
                        ])))),
            const SizedBox(height: 14),
            Text(listing.description.trim().isNotEmpty
                ? listing.description.trim()
                : _isWanted
                    ? 'Buyer-provided requirements, acceptable specifications, quantity, and delivery needs are shown below. Confirm final terms in secure messages.'
                    : 'Seller-provided specifications, inspection documents, serial information, and logistics details are available on request.'),
            if (_hasStructuredDetails) ...[
              const SizedBox(height: 16),
              _structuredDetailsPanel(),
            ],
            const SizedBox(height: 16),
            _locationPanel(),
            const SizedBox(height: 16),
            if (_isWanted)
              FilledButton.icon(
                  onPressed: _messageSeller,
                  icon: const Icon(Icons.reply_outlined),
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7557D3),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50)),
                  label: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Respond to wanted ad'),
                    const SizedBox(width: 6),
                    ListingMessageBadge(
                        listingId: listing.id, sellerUid: listing.sellerUid)
                  ]))
            else
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _messageSeller,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('Message seller'),
                          const SizedBox(width: 6),
                          ListingMessageBadge(
                              listingId: listing.id,
                              sellerUid: listing.sellerUid)
                        ]))),
                if (_features.offers) ...[
                  const SizedBox(width: 10),
                  Expanded(
                      child: FilledButton(
                          onPressed: _makeOffer,
                          style: FilledButton.styleFrom(
                              backgroundColor: _orange,
                              foregroundColor: Colors.white),
                          child: const Text('Make offer')))
                ],
              ]),
            if (_features.dispatch) ...[
              const SizedBox(height: 10),
              MarketplaceDispatchQuoteCard(onPressed: _getTruckingQuote),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => _setFollow(!_following),
                      icon: Icon(_following
                          ? Icons.person_remove_outlined
                          : Icons.person_add_alt),
                      label: Text(_following
                          ? 'Following ${_isWanted ? 'buyer' : 'seller'}'
                          : 'Save ${_isWanted ? 'buyer' : 'seller'} profile'))),
              if (_following) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                    tooltip: _notifications
                        ? 'New listing alerts on'
                        : 'Notify me of new listings',
                    onPressed: () => _setNotifications(!_notifications),
                    icon: Icon(_notifications
                        ? Icons.notifications_active
                        : Icons.notifications_none))
              ]
            ]),
            Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                    onPressed: _reportListing,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Report listing')))
          ]);

  Future<void> _copyShareLink() async {
    if (listing.documentId == null) return;
    final target = MarketplaceDeepLinks.shareTarget(
      MarketplaceDeepLinks.listing(listing.id),
    );
    await Clipboard.setData(ClipboardData(text: target));
    if (FirebaseAuth.instance.currentUser != null) {
      _actions.recordListingEvent(listing.id, 'share').catchError((_) {});
    }
    if (mounted) {
      PipeFeedback.show(
        context,
        message: target.startsWith('http')
            ? 'Shareable listing link copied.'
            : 'Listing route copied. Public mobile links activate after the app domain is approved.',
        tone: PipeStatusTone.success,
      );
    }
  }

  bool get _hasStructuredDetails {
    const fields = [
      'productType',
      'brand',
      'model',
      'modelYear',
      'machineHours',
      'quantity',
      'inspectionStatus',
      'propertyOffering',
      'propertyInterest',
      'landAreaInputValue',
      'buildingAreaValue',
      'zoningOrUse',
      'monthlyRevenue',
      'annualRevenue',
      'netOperatingIncome',
      'annualPropertyTax',
      'leaseDetails',
      'propertyFeatures',
    ];
    return fields.any((field) {
      final value = listing.details[field];
      if (value is Iterable) return value.isNotEmpty;
      return value != null && '$value'.trim().isNotEmpty;
    });
  }

  Widget _structuredDetailsPanel() {
    final details = listing.details;
    final rows = <Widget>[];
    void addRow(String label, Object? value, IconData icon) {
      final text = '${value ?? ''}'.trim();
      if (text.isEmpty || text == 'null') return;
      rows.add(_listingDetailRow(label, text, icon));
    }

    addRow('Product type', details['productType'], Icons.inventory_2_outlined);
    final brand = '${details['brand'] ?? ''}'.trim();
    final model = '${details['model'] ?? ''}'.trim();
    if (brand.isNotEmpty || model.isNotEmpty) {
      addRow(
          'Make and model',
          [brand, model].where((v) => v.isNotEmpty).join(' '),
          Icons.precision_manufacturing_outlined);
    }
    addRow('Model year', details['modelYear'], Icons.calendar_today_outlined);
    final machineHours = details['machineHours'] as num?;
    if (machineHours != null) {
      addRow('Machine hours', '${propertyMeasure(machineHours)} hours',
          Icons.schedule);
    }
    final quantity = details['quantity'] as num?;
    if (quantity != null && listing.category != 'Site & Property') {
      addRow('Available quantity', propertyMeasure(quantity), Icons.numbers);
    }
    addRow(
        'Inspection', details['inspectionStatus'], Icons.fact_check_outlined);

    final landInput = details['landAreaInputValue'] as num?;
    final landUnit = '${details['landAreaInputUnit'] ?? ''}';
    final acres = details['landAreaAcres'] as num?;
    final hectares = details['landAreaHectares'] as num?;
    if (landInput != null) {
      var display = '${propertyMeasure(landInput)} $landUnit';
      if (acres != null && hectares != null) {
        display =
            '${propertyMeasure(acres)} acres • ${propertyMeasure(hectares)} hectares';
      }
      addRow('Land area', display, Icons.landscape_outlined);
    }
    final buildingArea = details['buildingAreaValue'] as num?;
    if (buildingArea != null) {
      addRow(
          'Building area',
          '${propertyMeasure(buildingArea)} ${details['buildingAreaUnit'] ?? ''}',
          Icons.warehouse_outlined);
    }
    addRow('Offering includes', details['propertyOffering'],
        Icons.real_estate_agent_outlined);
    addRow('Interest offered', details['propertyInterest'],
        Icons.account_balance_outlined);
    addRow(
        'Zoning / permitted use', details['zoningOrUse'], Icons.map_outlined);

    void addMoney(String label, String field, IconData icon,
        {String suffix = ''}) {
      final value = details[field] as num?;
      if (value != null && value > 0) {
        addRow(label, '${marketplaceMoney(value)}$suffix', icon);
      }
    }

    addMoney('Monthly gross revenue', 'monthlyRevenue',
        Icons.calendar_view_month_outlined,
        suffix: ' / month');
    addMoney(
        'Annual gross revenue', 'annualRevenue', Icons.calendar_today_outlined,
        suffix: ' / year');
    addMoney('Net operating income', 'netOperatingIncome',
        Icons.trending_up_outlined,
        suffix: ' / year');
    addMoney(
        'Annual property tax', 'annualPropertyTax', Icons.receipt_long_outlined,
        suffix: ' / year');
    addRow('Lease / rights details', details['leaseDetails'],
        Icons.description_outlined);

    final features = (details['propertyFeatures'] as Iterable?)
            ?.map((value) => '$value')
            .where((value) => value.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          border: Border.all(color: const Color(0xFFD8E0E9)),
          borderRadius: BorderRadius.circular(15)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.info_outline, color: _orange),
          SizedBox(width: 8),
          Text('Listing details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...rows,
        ],
        if (features.isNotEmpty) ...[
          const Divider(height: 20),
          const Text('Property features',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: features
                  .map((feature) => Chip(
                      avatar: const Icon(Icons.check_circle_outline,
                          size: 16, color: Colors.green),
                      label: Text(feature),
                      visualDensity: VisualDensity.compact))
                  .toList()),
        ],
      ]),
    );
  }

  Widget _listingDetailRow(String label, String value, IconData icon) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 19, color: _orange),
          const SizedBox(width: 9),
          Expanded(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: _muted))),
          const SizedBox(width: 8),
          Expanded(
              flex: 3,
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
      );

  Widget _locationPanel() {
    final hasPoint = listing.latitude != null && listing.longitude != null;
    final canMap = hasPoint &&
        (listing.locationVisibility == LocationVisibility.exact ||
            listing.locationVisibility == LocationVisibility.approximate);
    if (canMap) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_isWanted ? 'Requested delivery area' : 'Pickup location',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(
              listing.locationVisibility == LocationVisibility.approximate
                  ? 'Approximate area'
                  : 'Exact location',
              style: const TextStyle(color: _muted, fontSize: 11))
        ]),
        const SizedBox(height: 8),
        ListingLocationMap(
            point: LatLng(listing.latitude!, listing.longitude!),
            approximate:
                listing.locationVisibility == LocationVisibility.approximate)
      ]);
    }
    return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: const Color(0xFFFFF5E8),
            borderRadius: BorderRadius.circular(15)),
        child: Row(children: [
          const Icon(Icons.location_off_outlined, color: Color(0xFFFF5A00)),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    listing.locationVisibility == LocationVisibility.hidden
                        ? (_isWanted
                            ? 'Delivery area hidden for privacy'
                            : 'Location hidden for site security')
                        : (_isWanted
                            ? 'Exact delivery area available by request'
                            : 'Exact location available by request'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                    _isWanted
                        ? 'Ask the buyer to confirm the destination or service area.'
                        : 'Ask the seller for pickup directions.',
                    style: const TextStyle(fontSize: 11, color: _muted))
              ])),
          IconButton.filled(
              tooltip: 'Request location',
              onPressed: _requestLocation,
              icon: const Icon(Icons.send_outlined))
        ]));
  }

  Future<void> _setFollow(bool value) async {
    try {
      await _actions.followSeller(listing.sellerUid,
          follow: value, notify: value && _notifications);
      if (mounted) setState(() => _following = value);
      _notice(value
          ? '${_isWanted ? 'Buyer' : 'Seller'} profile saved.'
          : '${_isWanted ? 'Buyer' : 'Seller'} removed.');
    } catch (error) {
      _notice(_actionError(error));
    }
  }

  Future<void> _setNotifications(bool value) async {
    try {
      await _actions.followSeller(listing.sellerUid,
          follow: true, notify: value);
      if (mounted) setState(() => _notifications = value);
      _notice(value
          ? '${_isWanted ? 'New wanted ad' : 'New listing'} alerts enabled.'
          : 'Listing alerts disabled.');
    } catch (error) {
      _notice(_actionError(error));
    }
  }

  Future<void> _messageSeller() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const MarketplaceAuthPage()));
      if (FirebaseAuth.instance.currentUser == null) return;
    }
    try {
      final conversationId = await _actions.ensureConversation(
          listingId: listing.id,
          listingTitle: listing.title,
          sellerUid: listing.sellerUid,
          sellerName: listing.sellerName);
      if (!mounted) return;
      await context.push(MarketplaceDeepLinks.conversation(conversationId));
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                icon: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text('Message could not be opened'),
                content: Text(_actionError(error)),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('OK'))
                ],
              ));
    }
  }

  Future<void> _makeOffer() async {
    if (!_features.offers) {
      _notice('Offers are temporarily unavailable.');
      return;
    }
    if (listing.transactionType == 'Auction') {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return _notice('Sign in to participate in auctions.');
      final user =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final score = (user.data()?['userScore'] as num?)?.toInt() ?? 70;
      if (score <= 50) {
        return _notice(
            'A User Score above 50 is required to participate in auctions.');
      }
    }
    if (!mounted) return;
    final amount =
        TextEditingController(text: listing.numericPrice?.toStringAsFixed(2));
    final quantity = TextEditingController(
        text: listing.quantity == null ? '1' : '${listing.quantity}');
    final note = TextEditingController();
    MarketplaceLocation? dispatchDeliveryLocation;
    DateTime? purchaseDate;
    DateTime? moneyTransferDate;
    DateTime? truckingDate;
    MarketplaceTruckingPlan? truckingPlan;
    final submitted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(builder: (context, refresh) {
              final offeredUnit =
                  num.tryParse(amount.text.replaceAll(',', '')) ?? 0;
              final requestedQty = int.tryParse(
                      quantity.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
                  0;
              final askingUnit = listing.numericPrice ?? 0;
              final listedQty =
                  listing.quantity ?? (requestedQty > 0 ? requestedQty : 1);
              final basisLower = listing.priceBasis.toLowerCase();
              final unitLabel = basisLower.contains('joint')
                  ? 'joints'
                  : basisLower.contains('piece') || basisLower.contains('each')
                      ? 'pieces'
                      : 'units';
              // PIPEBUYER_OFFER_SUMMARY_V4: original listing values remain static.
              final analysis = MarketplaceOfferAnalysis(
                listedQuantity: listedQty,
                requestedQuantity: requestedQty,
                askingUnitPrice: askingUnit,
                offeredUnitPrice: offeredUnit,
              );
              return AlertDialog(
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
                  title: const Text('Make an offer'),
                  content: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFFEAF4FD),
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Seller asks ${listing.price}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900)),
                                  if (listing.quantity != null)
                                    Text(
                                        '${listing.quantity} pieces available'),
                                ])),
                        const SizedBox(height: 10),
                        MarketplaceOfferQuantityField(
                          controller: quantity,
                          availableQuantity: listedQty,
                          unitLabel: unitLabel,
                          errorText: requestedQty <= 0
                              ? 'Enter at least 1 $unitLabel.'
                              : requestedQty > listedQty
                                  ? 'Only $listedQty $unitLabel are available.'
                                  : null,
                          onChanged: (_) => refresh(() {}),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                            controller: amount,
                            onChanged: (_) => refresh(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                                labelText: 'Offer price',
                                hintText: 'e.g. 70.00',
                                helperText: listing.priceBasis.isEmpty
                                    ? 'Enter your price using the listing’s pricing unit.'
                                    : 'Price ${listing.priceBasis.toLowerCase()}',
                                prefixText: '\$ ')),
                        const SizedBox(height: 10),
                        if (requestedQty > 0 && offeredUnit > 0)
                          MarketplaceOfferCommerceSummary(
                            analysis: analysis,
                            unitLabel: unitLabel,
                          ),
                        const SizedBox(height: 10),
                        TextField(
                            controller: note,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'Conditions or message (optional)',
                                hintText:
                                    'e.g. Conditional on inspection, documents, loading or pickup access')),
                        const SizedBox(height: 14),
                        MarketplaceTruckingPlanSelector(
                            dispatchEnabled: _features.dispatch,
                            value: truckingPlan,
                            onChanged: (value) => refresh(() {
                                  truckingPlan = value;
                                  if (value !=
                                      MarketplaceTruckingPlan.requestDispatch) {
                                    dispatchDeliveryLocation = null;
                                  }
                                })),
                        if (truckingPlan ==
                            MarketplaceTruckingPlan.requestDispatch) ...[
                          const SizedBox(height: 4),
                          MarketplaceDeliveryLocationSelector(
                              value: dispatchDeliveryLocation,
                              onChanged: (value) => refresh(
                                  () => dispatchDeliveryLocation = value)),
                          const SizedBox(height: 8),
                          const Card(
                              color: Color(0xFFEAF8F1),
                              child: Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Row(children: [
                                    Icon(Icons.verified_user_outlined,
                                        color: Colors.green),
                                    SizedBox(width: 8),
                                    Expanded(
                                        child: Text(
                                            'Carrier bidding remains separate from the purchase price. You choose the winning trucking quote.',
                                            style: TextStyle(fontSize: 11)))
                                  ])))
                        ],
                        const SizedBox(height: 8),
                        const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Proposed dates',
                                style: TextStyle(fontWeight: FontWeight.w900))),
                        const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                'Add dates that matter to this purchase. A trucking date is required when requesting Dispatch.',
                                style: TextStyle(
                                    color: Color(0xFF66758A), fontSize: 11))),
                        const SizedBox(height: 6),
                        _listingOfferDateButton(
                            label: 'Purchase date',
                            value: purchaseDate,
                            icon: Icons.event_available_outlined,
                            onTap: () async {
                              final selected = await showDatePicker(
                                  context: context,
                                  initialDate: purchaseDate ??
                                      DateTime.now()
                                          .add(const Duration(days: 1)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 730)));
                              if (selected != null) {
                                purchaseDate = selected;
                                refresh(() {});
                              }
                            }),
                        _listingOfferDateButton(
                            label: 'Money transfer date',
                            value: moneyTransferDate,
                            icon: Icons.account_balance_outlined,
                            onTap: () async {
                              final selected = await showDatePicker(
                                  context: context,
                                  initialDate: moneyTransferDate ??
                                      DateTime.now()
                                          .add(const Duration(days: 1)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 730)));
                              if (selected != null) {
                                moneyTransferDate = selected;
                                refresh(() {});
                              }
                            }),
                        _listingOfferDateButton(
                            label: 'Trucking / pickup date',
                            value: truckingDate,
                            icon: Icons.local_shipping_outlined,
                            onTap: () async {
                              final selected = await showDatePicker(
                                  context: context,
                                  initialDate: truckingDate ??
                                      DateTime.now()
                                          .add(const Duration(days: 1)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 730)));
                              if (selected != null) {
                                truckingDate = selected;
                                refresh(() {});
                              }
                            })
                      ]))),
                  actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  actionsOverflowDirection: VerticalDirection.down,
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: requestedQty <= 0 ||
                                offeredUnit <= 0 ||
                                truckingPlan == null ||
                                (truckingPlan ==
                                        MarketplaceTruckingPlan
                                            .requestDispatch &&
                                    (dispatchDeliveryLocation == null ||
                                        truckingDate == null))
                            ? null
                            : () => Navigator.pop(context, true),
                        child: const Text('Submit offer'))
                  ]);
            }));
    if (submitted != true) {
      amount.dispose();
      quantity.dispose();
      note.dispose();
      return;
    }
    final value = num.tryParse(amount.text.replaceAll(',', ''));
    final requestedQty =
        int.tryParse(quantity.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (value == null || value <= 0) {
      return _notice('Enter a valid offer amount.');
    }
    if (requestedQty == null || requestedQty <= 0) {
      return _notice('Enter a valid quantity.');
    }
    try {
      await _actions.makeOffer(
          listingId: listing.id,
          sellerUid: listing.sellerUid,
          offeredUnitPrice: value,
          requestedQuantity: requestedQty,
          askingUnitPrice: listing.numericPrice,
          availableQuantity: listing.quantity,
          priceBasis: listing.priceBasis,
          note: note.text,
          purchaseDate: purchaseDate,
          moneyTransferDate: moneyTransferDate,
          truckingDate: truckingDate,
          truckingPlan: truckingPlan!.storageValue,
          dispatchDelivery: dispatchDeliveryLocation?.publicName.trim() ?? '',
          dispatchDeliveryLocation: dispatchDeliveryLocation,
          listingTitle: listing.title,
          pickupLabel: listing.location);
      _notice(truckingPlan == MarketplaceTruckingPlan.requestDispatch
          ? 'Offer submitted. Your Dispatch request is live for carrier bids.'
          : 'Offer submitted to the seller.');
    } catch (error) {
      _notice(_actionError(error));
    } finally {
      amount.dispose();
      quantity.dispose();
      note.dispose();
    }
  }

  Future<void> _reportListing() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _notice('Sign in to report a listing.');
    if (uid == listing.sellerUid) {
      return _notice('You cannot report your own listing.');
    }
    if (!mounted) return;
    final submitted = await showMarketplaceReportDialog(context,
        reportedUid: listing.sellerUid,
        targetType: 'listing',
        listingId: listing.id);
    if (submitted) {
      _notice(
          'Thank you. Your report and evidence were sent for private review.');
    }
  }

  Future<void> _getTruckingQuote() async {
    final id = listing.documentId;
    if (id == null) return;
    final document = await FirebaseFirestore.instance
        .collection('public_listings')
        .doc(id)
        .get();
    if (!mounted || !document.exists) return;
    await MarketplaceFreightQuote.show(context,
        listingId: id, listing: document.data()!);
  }

  Widget _listingOfferDateButton(
          {required String label,
          required DateTime? value,
          required IconData icon,
          required VoidCallback onTap}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  alignment: Alignment.centerLeft),
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(value == null
                  ? 'Select $label'
                  : '$label: ${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}')));

  Future<void> _requestLocation() async {
    final note = await _textDialog(
        _isWanted ? 'Confirm delivery area' : 'Request pickup location',
        _isWanted
            ? 'Please confirm the delivery destination or service area for this request.'
            : 'Please share pickup directions and an available viewing time.',
        'Send request');
    if (note == null) return;
    try {
      await _actions.requestLocation(
          listingId: listing.id, sellerUid: listing.sellerUid, note: note);
      _notice(
          'Location request sent to the ${_isWanted ? 'buyer' : 'seller'}.');
    } catch (error) {
      _notice(_actionError(error));
    }
  }

  Future<String?> _textDialog(
      String title, String initial, String action) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(title),
                content: TextField(controller: controller, maxLines: 4),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: Text(action))
                ]));
    controller.dispose();
    return result == null || result.isEmpty ? null : result;
  }

  void _showSellerProfile() {
    context.push(MarketplaceDeepLinks.profile(listing.sellerUid));
  }

  String _actionError(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is FirebaseException) {
      return '${error.message ?? 'Firebase rejected this action.'}\nCode: ${error.code}';
    }
    return 'Action failed. Check your connection and try again.';
  }

  void _notice(String text) {
    if (!mounted) return;
    setState(() => _statusMessage = text);
  }
}

class _StableCreateListingPage extends StatefulWidget {
  const _StableCreateListingPage({
    super.key,
    required this.onHome,
    required this.auctionsEnabled,
    required this.wantedAdsEnabled,
    required this.regulatedListingsEnabled,
    required this.paidFeaturesEnabled,
    this.initialAuction = false,
    this.initialWanted = false,
  });

  final VoidCallback onHome;
  final bool initialAuction;
  final bool initialWanted;
  final bool auctionsEnabled;
  final bool wantedAdsEnabled;
  final bool regulatedListingsEnabled;
  final bool paidFeaturesEnabled;

  @override
  State<_StableCreateListingPage> createState() =>
      _StableCreateListingPageState();
}

class _StableCreateListingPageState extends State<_StableCreateListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = MarketplaceCatalogRepository();
  final _mediaRepository = MarketplaceMediaRepository();
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _quantity = TextEditingController();
  final _inspectionDetails = TextEditingController();
  final _machineHours = TextEditingController();
  final _serialNumber = TextEditingController();
  final _engineDetails = TextEditingController();
  final _attachments = TextEditingController();
  final _customProductType = TextEditingController();
  final _customPipeSize = TextEditingController();
  final _customPipeBand = TextEditingController();
  final _reservePrice = TextEditingController();
  final _buyItNowPrice = TextEditingController();
  final _minimumBidIncrement = TextEditingController(text: '25');
  final _landArea = TextEditingController();
  final _buildingArea = TextEditingController();
  final _zoningOrUse = TextEditingController();
  final _monthlyRevenue = TextEditingController();
  final _annualRevenue = TextEditingController();
  final _netOperatingIncome = TextEditingController();
  final _annualPropertyTax = TextEditingController();
  final _leaseDetails = TextEditingController();
  DateTime? _auctionStartAt;
  DateTime? _auctionEndAt;
  String? _category;
  String? _productType;
  String? _pipeSize;
  String? _condition;
  String? _equipmentBrand;
  String? _equipmentModel;
  int? _equipmentYear;
  String _maintenanceHistory = 'Unknown / not available';
  String _operatingStatus = 'Operational';
  String _inspectionStatus = 'Not inspected / unknown';
  String _pipeBand = 'No band / unknown';
  String _listingType = 'For Sale';
  String _priceBasis = 'Per piece';
  String _priceFlexibility = 'Open to offers';
  String _landAreaUnit = 'Acres';
  String _buildingAreaUnit = 'Square feet';
  String _propertyInterest = 'Freehold / fee simple';
  String _propertyOffering = 'Land only';
  final Set<String> _propertyFeatures = <String>{};
  List<String> _pipeSizes = pipeNominalSizes;
  Map<String, List<String>> _equipmentBrands = equipmentBrandModels;
  final List<XFile> _photos = [];
  int? _thumbnailPhotoIndex;
  XFile? _video;
  bool _boostRequested = false;
  MarketplaceLocation? _location;
  bool _publishing = false;
  bool _selectingPhotos = false;
  bool _selectingVideo = false;
  int _mediaCompleted = 0;
  int _mediaTotal = 0;
  double _mediaProgress = 0;
  String? _backgroundUploadMessage;
  String? _pendingDraftId;
  String? _pendingPublishRequestId;

  bool get _isAuction => _listingType == 'Auction';
  bool get _isWanted => _listingType == 'Wanted / Seeking';
  bool get _isProperty => _category == 'Site & Property';

  String get _placement {
    if (_isAuction) return 'Auction';
    if (_isWanted) return 'Wanted';
    return 'Marketplace';
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialAuction && widget.auctionsEnabled) {
      _listingType = 'Auction';
      _auctionStartAt = DateTime.now().add(const Duration(minutes: 10));
      _auctionEndAt = DateTime.now().add(const Duration(days: 7));
    } else if (widget.initialWanted && widget.wantedAdsEnabled) {
      _listingType = 'Wanted / Seeking';
      _priceFlexibility = 'Open to offers';
    }
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    final results = await Future.wait([
      _repository.loadPipeSizes(pipeNominalSizes),
      _repository.loadBrandModels(equipmentBrandModels),
    ]);
    if (mounted) {
      setState(() {
        _pipeSizes = results[0] as List<String>;
        _equipmentBrands = results[1] as Map<String, List<String>>;
      });
    }
  }

  void _setPlacement(String placement) {
    if (placement == 'Auction' && !widget.auctionsEnabled) {
      _showDisabledFeature('Timed auctions');
      return;
    }
    if (placement == 'Wanted' && !widget.wantedAdsEnabled) {
      _showDisabledFeature('Wanted ads');
      return;
    }
    setState(() {
      switch (placement) {
        case 'Auction':
          _listingType = 'Auction';
          _auctionStartAt ??= DateTime.now().add(const Duration(minutes: 10));
          _auctionEndAt ??= DateTime.now().add(const Duration(days: 7));
          break;
        case 'Wanted':
          _listingType = 'Wanted / Seeking';
          _priceFlexibility = 'Open to offers';
          break;
        default:
          _listingType = 'For Sale';
      }
    });
  }

  void _showDisabledFeature(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature are temporarily unavailable.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _listingHeader(User user) {
    final icon = _isAuction
        ? Icons.gavel_outlined
        : _isWanted
            ? Icons.campaign_outlined
            : Icons.storefront_outlined;
    final accent = _isWanted
        ? const Color(0xFF7557D3)
        : _isAuction
            ? const Color(0xFFF08A24)
            : _orange;
    final description = _isWanted
        ? 'Tell suppliers what you need, the quantity, acceptable condition, budget, and delivery area.'
        : _isAuction
            ? 'Set a timed bidding window, starting bid, reserve, and optional Buy It Now price.'
            : 'Sell, rent, or request a quote through the main Marketplace.';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Create listing',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Listing as ${user.email ?? 'your marketplace account'}',
              style: const TextStyle(color: _muted)),
        ])),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          tooltip: 'Choose where this listing appears',
          onSelected: _setPlacement,
          itemBuilder: (context) => [
            const PopupMenuItem(
                value: 'Marketplace',
                child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.storefront_outlined),
                    title: Text('Marketplace'),
                    subtitle: Text('Sell, rent, or request a quote'))),
            if (widget.auctionsEnabled)
              const PopupMenuItem(
                  value: 'Auction',
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.gavel_outlined),
                      title: Text('Timed auction'),
                      subtitle: Text('Accept bids for a set time'))),
            if (widget.wantedAdsEnabled)
              const PopupMenuItem(
                  value: 'Wanted',
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.campaign_outlined),
                      title: Text('Wanted ad'),
                      subtitle: Text('Ask suppliers for an item'))),
          ],
          child: Container(
              constraints: const BoxConstraints(minHeight: 54, minWidth: 132),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: .09),
                  border: Border.all(color: accent, width: 1.4),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: accent),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('LISTING TYPE',
                      style: TextStyle(
                          color: _muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                  Text(_placement,
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: accent)
              ])),
        )
      ]),
      const SizedBox(height: 12),
      Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: accent.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(icon, color: accent, size: 21),
            const SizedBox(width: 10),
            Expanded(
                child: Text(description,
                    style: const TextStyle(fontSize: 12, color: _muted)))
          ]))
    ]);
  }

  Widget _wantedSetupCard() => const Card(
      margin: EdgeInsets.zero,
      color: Color(0xFFF3F0FF),
      child: Padding(
          padding: EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.campaign_outlined, color: Color(0xFF7557D3)),
              SizedBox(width: 8),
              Text('Wanted ad requirements',
                  style: TextStyle(fontWeight: FontWeight.w900))
            ]),
            SizedBox(height: 8),
            Text(
                'Enter the exact item, acceptable condition, quantity needed, target budget, and delivery or search area. Suppliers can open your public profile and respond through secure in-app messages.'),
            SizedBox(height: 8),
            Text(
                'Do not include private contact, payment, or site-access details in the public description.',
                style: TextStyle(fontSize: 11, color: _muted))
          ])));

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _description.dispose();
    _brand.dispose();
    _model.dispose();
    _quantity.dispose();
    _inspectionDetails.dispose();
    _machineHours.dispose();
    _serialNumber.dispose();
    _engineDetails.dispose();
    _attachments.dispose();
    _customProductType.dispose();
    _customPipeSize.dispose();
    _customPipeBand.dispose();
    _reservePrice.dispose();
    _buyItNowPrice.dispose();
    _minimumBidIncrement.dispose();
    _landArea.dispose();
    _buildingArea.dispose();
    _zoningOrUse.dispose();
    _monthlyRevenue.dispose();
    _annualRevenue.dispose();
    _netOperatingIncome.dispose();
    _annualPropertyTax.dispose();
    _leaseDetails.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _signInRequired();

    final categories = phase1MarketplaceCategories(
      regulatedListingsEnabled: widget.regulatedListingsEnabled,
    );
    final category =
        categories.where((item) => item.name == _category).firstOrNull;
    final isPipe = _category == 'Pipe, Tubing & Materials' ||
        const {
          'Drill Pipe',
          'Casing',
          'Tubing',
          'Line Pipe',
          'OCTG',
          'Sucker Rod'
        }.contains(_productType);
    final isMachine = _category == 'Heavy Equipment';
    final isProperty = _isProperty;
    final priceBasisOptions = isMachine
        ? const ['Total asking price', 'Price per machine', 'Call for price']
        : isProperty
            ? const [
                'Total asking price',
                'Per acre',
                'Per hectare',
                'Monthly lease',
                'Annual lease',
                'Call for price'
              ]
            : isPipe
                ? const [
                    'Per piece',
                    'Total for all',
                    'Per foot',
                    'Per metre',
                    'Per joint',
                    'Per bundle',
                    'Call for price'
                  ]
                : const ['Total asking price', 'Per item', 'Call for price'];
    final displayedPriceBasis = priceBasisOptions.contains(_priceBasis)
        ? _priceBasis
        : priceBasisOptions.first;
    final conditionOptions = marketplaceConditionsFor(_category, _productType);
    final isWanted = _isWanted;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _listingHeader(user),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(children: [
            TextFormField(
              controller: _title,
              decoration: InputDecoration(
                  labelText:
                      isWanted ? 'Wanted item title *' : 'Listing title *',
                  hintText: isWanted
                      ? 'Example: Wanted — 2-7/8 drill pipe, 40+ joints'
                      : 'Example: 2-7/8 drill pipe — 43 pieces',
                  prefixIcon: const Icon(Icons.title)),
              validator: (value) => value == null || value.trim().isEmpty
                  ? isWanted
                      ? 'Enter what you are looking for'
                      : 'Enter a listing title'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              itemHeight: 70,
              decoration: InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: _category == null
                      ? const Icon(Icons.category_outlined)
                      : Padding(
                          padding: const EdgeInsets.all(11),
                          child: CatalogIcon(label: _category, size: 28))),
              selectedItemBuilder: (context) => (categories.toList()
                    ..sort((a, b) => naturalCompare(a.name, b.name)))
                  .map((item) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(item.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis)))
                  .toList(),
              items: (categories.toList()
                    ..sort((a, b) => naturalCompare(a.name, b.name)))
                  .map((item) => DropdownMenuItem(
                      value: item.name,
                      child: Row(children: [
                        SizedBox.square(
                            dimension: 38,
                            child: Center(
                                child:
                                    CatalogIcon(label: item.name, size: 34))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              Text(item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: _muted, fontSize: 10.5)),
                            ]))
                      ])))
                  .toList(),
              onChanged: (value) => setState(() {
                _category = value;
                _productType = null;
                _pipeSize = null;
                _condition = null;
                _inspectionStatus = 'Not inspected / unknown';
                _pipeBand = 'No band / unknown';
                _equipmentBrand = null;
                _equipmentModel = null;
                _equipmentYear = null;
                _quantity.text =
                    value == 'Heavy Equipment' || value == 'Site & Property'
                        ? '1'
                        : '';
                _priceBasis = value == 'Heavy Equipment'
                    ? 'Total asking price'
                    : value == 'Pipe, Tubing & Materials'
                        ? 'Per piece'
                        : 'Total asking price';
              }),
              validator: (_) => _category == null ? 'Select a category' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _productType,
              isExpanded: true,
              itemHeight: 72,
              decoration: InputDecoration(
                  labelText: 'Product type *',
                  prefixIcon: _productType == null
                      ? const Icon(Icons.inventory_2_outlined)
                      : Padding(
                          padding: const EdgeInsets.all(11),
                          child: CatalogIcon(
                              label: _productType,
                              fallbackLabel: _category,
                              size: 28))),
              selectedItemBuilder: category == null
                  ? null
                  : (context) => (((category.types).toList()
                            ..sort(naturalCompare))
                          .followedBy(const [_otherCatalogValue]))
                      .map((type) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(type,
                              maxLines: 1, overflow: TextOverflow.ellipsis)))
                      .toList(),
              items: (((category?.types ?? const <String>[]).toList()
                        ..sort(naturalCompare))
                      .followedBy(const [_otherCatalogValue]))
                  .map((type) => DropdownMenuItem(
                      value: type,
                      child: Row(children: [
                        SizedBox.square(
                            dimension: 38,
                            child: Center(
                                child: CatalogIcon(
                                    label: type,
                                    fallbackLabel: _category,
                                    size: 34))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(type,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              if (category != null)
                                Text(
                                    marketplaceProductTypeDescription(
                                        type, category),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _muted, fontSize: 10.5)),
                            ]))
                      ])))
                  .toList(),
              onChanged: category == null
                  ? null
                  : (value) => setState(() {
                        _productType = value;
                        _pipeSize = null;
                        _condition = null;
                        _equipmentBrand = null;
                        _equipmentModel = null;
                        _equipmentYear = null;
                        if (_category == 'Heavy Equipment') {
                          _quantity.text = '1';
                          _priceBasis = 'Total asking price';
                        } else if (_category == 'Site & Property') {
                          _quantity.text = '1';
                          _priceBasis = 'Total asking price';
                          if (value == 'Business for Sale') {
                            _propertyOffering = 'Business only';
                            _propertyInterest = 'Business interest';
                          } else if (value == 'Mineral Rights' ||
                              value == 'Surface Rights' ||
                              value == 'Oil & Gas Lease' ||
                              value == 'Pipeline') {
                            _propertyOffering = 'Rights or royalty interest';
                            _propertyInterest = value == 'Mineral Rights'
                                ? 'Mineral rights'
                                : value == 'Surface Rights'
                                    ? 'Surface rights'
                                    : value == 'Pipeline'
                                        ? 'Easement / right-of-way'
                                        : 'Oil and gas lease';
                          }
                        }
                      }),
              validator: (_) =>
                  _productType == null ? 'Select a product type' : null,
            ),
            if (_productType == _otherCatalogValue) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customProductType,
                decoration: const InputDecoration(
                    labelText: 'Enter product type *',
                    prefixIcon: Icon(Icons.edit_outlined)),
                validator: (value) => _productType == _otherCatalogValue &&
                        (value == null || value.trim().isEmpty)
                    ? 'Enter the product type'
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            if (isProperty) ...[
              _propertyDetailsCard(),
              const SizedBox(height: 12),
            ],
            if (isMachine)
              DropdownButtonFormField<String>(
                initialValue: _equipmentBrand,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Brand or manufacturer *',
                    prefixIcon: Icon(Icons.factory_outlined)),
                items: ([..._equipmentBrands.keys]..sort(naturalCompare))
                    .followedBy(const [_otherCatalogValue])
                    .map((brand) =>
                        DropdownMenuItem(value: brand, child: Text(brand)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _equipmentBrand = value;
                  _equipmentModel = null;
                  _equipmentYear = null;
                }),
                validator: (_) => isMachine && _equipmentBrand == null
                    ? 'Select a manufacturer'
                    : null,
              )
            else if (!isProperty)
              TextFormField(
                controller: _brand,
                decoration: const InputDecoration(
                    labelText: 'Brand or manufacturer',
                    prefixIcon: Icon(Icons.factory_outlined)),
              ),
            if (isMachine && _equipmentBrand == _otherCatalogValue) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _brand,
                decoration: const InputDecoration(
                    labelText: 'Enter manufacturer *',
                    prefixIcon: Icon(Icons.edit_outlined)),
                validator: (value) => _equipmentBrand == _otherCatalogValue &&
                        (value == null || value.trim().isEmpty)
                    ? 'Enter the manufacturer'
                    : null,
              ),
            ],
            if (!isProperty) const SizedBox(height: 12),
            if (isPipe)
              DropdownButtonFormField<String>(
                initialValue: _pipeSize,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Pipe size *',
                    prefixIcon: Icon(Icons.straighten)),
                items: ((_productType == 'Sucker Rod'
                            ? suckerRodSizes
                            : _pipeSizes)
                        .toList()
                      ..sort(naturalCompare))
                    .followedBy(const [_otherCatalogValue])
                    .map((size) =>
                        DropdownMenuItem(value: size, child: Text(size)))
                    .toList(),
                onChanged: (value) => setState(() => _pipeSize = value),
                validator: (_) =>
                    isPipe && _pipeSize == null ? 'Select the pipe size' : null,
              )
            else if (isMachine)
              DropdownButtonFormField<String>(
                initialValue: _equipmentModel,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Model *',
                    prefixIcon: Icon(Icons.precision_manufacturing_outlined)),
                items: ((_equipmentBrands[_equipmentBrand] ?? const <String>[])
                        .toList()
                      ..sort(naturalCompare))
                    .followedBy(const [_otherCatalogValue])
                    .map((model) =>
                        DropdownMenuItem(value: model, child: Text(model)))
                    .toList(),
                onChanged: _equipmentBrand == null
                    ? null
                    : (value) => setState(() => _equipmentModel = value),
                validator: (_) => isMachine && _equipmentModel == null
                    ? 'Select a model'
                    : null,
              )
            else if (!isProperty)
              TextFormField(
                controller: _model,
                decoration: const InputDecoration(
                    labelText: 'Model, size or grade',
                    prefixIcon: Icon(Icons.precision_manufacturing_outlined)),
              ),
            if (isMachine && _equipmentModel == _otherCatalogValue) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _model,
                decoration: const InputDecoration(
                    labelText: 'Enter model *',
                    prefixIcon: Icon(Icons.edit_outlined)),
                validator: (value) => _equipmentModel == _otherCatalogValue &&
                        (value == null || value.trim().isEmpty)
                    ? 'Enter the model'
                    : null,
              ),
            ],
            if (isPipe && _pipeSize == _otherCatalogValue) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customPipeSize,
                decoration: const InputDecoration(
                    labelText: 'Enter pipe size *',
                    hintText: 'Include nominal size and unit',
                    prefixIcon: Icon(Icons.edit_outlined)),
                validator: (value) => _pipeSize == _otherCatalogValue &&
                        (value == null || value.trim().isEmpty)
                    ? 'Enter the pipe size'
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            if (isMachine) ...[
              DropdownButtonFormField<int>(
                initialValue: _equipmentYear,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Model year *',
                    prefixIcon: Icon(Icons.calendar_today_outlined)),
                items: List.generate(DateTime.now().year - 1949,
                        (index) => DateTime.now().year - index)
                    .map((year) =>
                        DropdownMenuItem(value: year, child: Text('$year')))
                    .toList(),
                onChanged: (value) => setState(() => _equipmentYear = value),
                validator: (_) => isMachine && _equipmentYear == null
                    ? 'Select the model year'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _machineHours,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Machine hours',
                    suffixText: 'hours',
                    prefixIcon: Icon(Icons.schedule)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serialNumber,
                decoration: const InputDecoration(
                    labelText: 'Serial number / PIN (optional)',
                    prefixIcon: Icon(Icons.numbers_outlined)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _engineDetails,
                decoration: const InputDecoration(
                    labelText: 'Engine / powertrain details',
                    hintText: 'Engine model, horsepower, transmission',
                    prefixIcon: Icon(Icons.settings_outlined)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _attachments,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Attachments and included equipment',
                    hintText: 'Buckets, forks, thumb, quick coupler, etc.',
                    prefixIcon: Icon(Icons.construction_outlined)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _operatingStatus,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Operating status',
                    prefixIcon: Icon(Icons.engineering_outlined)),
                selectedItemBuilder: (context) => const [
                  'Operational',
                  'Operational with known issues',
                  'Not currently operational',
                  'For parts / rebuild'
                ]
                    .map((value) => Align(
                        alignment: Alignment.centerLeft, child: Text(value)))
                    .toList(),
                items: const [
                  'Operational',
                  'Operational with known issues',
                  'Not currently operational',
                  'For parts / rebuild'
                ].map((value) {
                  final visual = _operatingStatusVisual(value);
                  return DropdownMenuItem(
                      value: value,
                      child: MarketplaceFormOption(
                          label: value,
                          icon: visual.icon,
                          iconColor: visual.color));
                }).toList(),
                onChanged: (value) =>
                    setState(() => _operatingStatus = value ?? 'Operational'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _maintenanceHistory,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Maintenance history',
                    prefixIcon: Icon(Icons.history_outlined)),
                selectedItemBuilder: (context) => const [
                  'Full documented history',
                  'Partial maintenance records',
                  'Owner-maintained — no records',
                  'Unknown / not available'
                ]
                    .map((value) => Align(
                        alignment: Alignment.centerLeft, child: Text(value)))
                    .toList(),
                items: const [
                  'Full documented history',
                  'Partial maintenance records',
                  'Owner-maintained — no records',
                  'Unknown / not available'
                ].map((value) {
                  final visual = _maintenanceVisual(value);
                  return DropdownMenuItem(
                      value: value,
                      child: MarketplaceFormOption(
                          label: value,
                          icon: visual.icon,
                          iconColor: visual.color));
                }).toList(),
                onChanged: (value) => setState(() =>
                    _maintenanceHistory = value ?? 'Unknown / not available'),
              ),
              const SizedBox(height: 12),
            ],
            if (!isProperty) ...[
              TextFormField(
                key: ValueKey('quantity-$isMachine-${_quantity.text}'),
                controller: _quantity,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: isMachine
                        ? (isWanted
                            ? 'Number of machines needed *'
                            : 'Number of identical machines *')
                        : (isWanted ? 'Quantity needed *' : 'Quantity *'),
                    hintText: isMachine ? '1' : 'Example: 43 pieces',
                    suffixText: isMachine ? 'machine(s)' : 'pieces',
                    prefixIcon: const Icon(Icons.numbers)),
                validator: (_) => _quantity.text.trim().isEmpty
                    ? isWanted
                        ? 'Enter the quantity needed'
                        : 'Enter the available quantity'
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              key: ValueKey(
                  'condition-${_category ?? ''}-${_productType ?? ''}-${_condition ?? ''}'),
              initialValue: _condition,
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: isWanted
                      ? 'Acceptable condition / quality *'
                      : 'Condition / quality *',
                  prefixIcon: const Icon(Icons.fact_check_outlined)),
              selectedItemBuilder: (context) => conditionOptions
                  .map((value) => Align(
                      alignment: Alignment.centerLeft, child: Text(value)))
                  .toList(),
              items: conditionOptions.map((value) {
                final visual = _conditionVisual(value);
                return DropdownMenuItem(
                    value: value,
                    child: MarketplaceFormOption(
                        label: value,
                        icon: visual.icon,
                        iconColor: visual.color));
              }).toList(),
              onChanged: (value) => setState(() => _condition = value),
              validator: (_) => _condition == null ? 'Select condition' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _inspectionStatus,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Inspection status',
                  prefixIcon: Icon(Icons.search_outlined)),
              selectedItemBuilder: (context) => const [
                'Not inspected / unknown',
                'Seller visual inspection only',
                'Third-party inspected — report available',
                'Third-party inspected — no report available',
                'Previously inspected — date unknown',
                'Inspection / recertification required'
              ]
                  .map((value) => Align(
                      alignment: Alignment.centerLeft, child: Text(value)))
                  .toList(),
              items: const [
                'Not inspected / unknown',
                'Seller visual inspection only',
                'Third-party inspected — report available',
                'Third-party inspected — no report available',
                'Previously inspected — date unknown',
                'Inspection / recertification required'
              ].map((value) {
                final visual = _inspectionVisual(value);
                return DropdownMenuItem(
                    value: value,
                    child: MarketplaceFormOption(
                        label: value,
                        icon: visual.icon,
                        iconColor: visual.color));
              }).toList(),
              onChanged: (value) => setState(
                  () => _inspectionStatus = value ?? 'Not inspected / unknown'),
            ),
            if (isPipe) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _pipeBand,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Pipe band / field colour',
                    prefixIcon: Icon(Icons.color_lens_outlined)),
                selectedItemBuilder: (context) => const [
                  'No band / unknown',
                  'White band',
                  'Yellow band',
                  'Blue band',
                  'Green band',
                  'Orange band',
                  'Red band / structural',
                  'Multiple bands',
                  'Other owner or operator marking'
                ]
                    .map((value) => Align(
                        alignment: Alignment.centerLeft, child: Text(value)))
                    .toList(),
                items: const [
                  'No band / unknown',
                  'White band',
                  'Yellow band',
                  'Blue band',
                  'Green band',
                  'Orange band',
                  'Red band / structural',
                  'Multiple bands',
                  'Other owner or operator marking'
                ].map((value) {
                  final visual = _pipeBandVisual(value);
                  return DropdownMenuItem(
                      value: value,
                      child: MarketplaceFormOption(
                          label: value,
                          icon: visual.icon,
                          iconColor: visual.color));
                }).toList(),
                onChanged: (value) =>
                    setState(() => _pipeBand = value ?? 'No band / unknown'),
              ),
              if (_pipeBand == 'Other owner or operator marking') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customPipeBand,
                  decoration: const InputDecoration(
                      labelText: 'Describe the pipe marking *',
                      hintText: 'Colour, band pattern, owner or operator',
                      prefixIcon: Icon(Icons.edit_outlined)),
                  validator: (value) =>
                      _pipeBand == 'Other owner or operator marking' &&
                              (value == null || value.trim().isEmpty)
                          ? 'Describe the marking'
                          : null,
                ),
              ],
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 6, 8, 0),
                child: Text(
                    'Band colours can vary by pipe type, inspector and operator. Add the inspection report or wall-loss details when known.',
                    style: TextStyle(fontSize: 11, color: _muted)),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _inspectionDetails,
              decoration: const InputDecoration(
                  labelText: 'Inspection details (optional)',
                  hintText: 'Inspector, date, report number, wall loss or test',
                  prefixIcon: Icon(Icons.description_outlined)),
            ),
            const SizedBox(height: 12),
            if (!_isAuction && !isWanted)
              DropdownButtonFormField<String>(
                initialValue: _listingType,
                decoration: const InputDecoration(
                    labelText: 'Marketplace listing type *',
                    prefixIcon: Icon(Icons.sell_outlined)),
                selectedItemBuilder: (context) => const [
                  'For Sale',
                  'For Rent',
                  'Request for Quote',
                ]
                    .map((value) => Align(
                        alignment: Alignment.centerLeft, child: Text(value)))
                    .toList(),
                items: const [
                  'For Sale',
                  'For Rent',
                  'Request for Quote',
                ]
                    .map((type) => DropdownMenuItem(
                        value: type,
                        child: MarketplaceFormOption(
                            label: type, icon: _listingTypeIcon(type))))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _listingType = value ?? 'For Sale'),
              )
            else if (_isAuction)
              _auctionSetupCard(),
            if (isWanted) _wantedSetupCard(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [MarketplaceMoneyInputFormatter()],
              enabled: _priceBasis != 'Call for price',
              decoration: InputDecoration(
                  labelText: isWanted
                      ? 'Target budget / price (CAD)'
                      : isMachine
                          ? (_isAuction
                              ? 'Starting bid (CAD) *'
                              : 'Equipment asking price (CAD)')
                          : (_isAuction
                              ? 'Starting bid (CAD) *'
                              : 'Price (CAD)'),
                  hintText: isWanted
                      ? 'Optional — helps suppliers assess the request'
                      : _isAuction
                          ? 'Required starting bid'
                          : 'Leave blank for contact seller',
                  prefixIcon: const Icon(Icons.attach_money)),
              validator: (value) => _isAuction &&
                      num.tryParse(value?.replaceAll(RegExp(r'[^0-9.]'), '') ??
                              '') ==
                          null
                  ? 'Enter a starting bid'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: displayedPriceBasis,
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: isWanted ? 'Budget is based on' : 'Price is',
                  prefixIcon: const Icon(Icons.calculate_outlined)),
              selectedItemBuilder: (context) => priceBasisOptions
                  .map((value) => Align(
                      alignment: Alignment.centerLeft, child: Text(value)))
                  .toList(),
              items: priceBasisOptions
                  .map((value) => DropdownMenuItem(
                      value: value,
                      child: MarketplaceFormOption(
                          label: value, icon: _priceBasisIcon(value))))
                  .toList(),
              onChanged: (value) => setState(() {
                _priceBasis = value ?? priceBasisOptions.first;
                if (_priceBasis == 'Call for price') _price.clear();
              }),
            ),
            const SizedBox(height: 12),
            if (!isWanted)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'Open to offers',
                      icon: Icon(Icons.handshake_outlined),
                      label: Text('Open to offers')),
                  ButtonSegment(
                      value: 'Firm',
                      icon: Icon(Icons.lock_outline),
                      label: Text('Firm')),
                ],
                selected: {_priceFlexibility},
                onSelectionChanged: (value) =>
                    setState(() => _priceFlexibility = value.first),
              )
            else
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEAF8F1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: Colors.green),
                    SizedBox(width: 9),
                    Expanded(
                        child: Text(
                            'A target budget is guidance only. Final pricing and terms are agreed securely with the responding supplier.',
                            style: TextStyle(fontSize: 12)))
                  ])),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 7,
              decoration: InputDecoration(
                  labelText: isWanted ? 'Requirements *' : 'Description *',
                  hintText: isWanted
                      ? 'Required specifications, acceptable substitutes, deadline, and delivery needs'
                      : 'Condition, specifications and pickup details',
                  alignLabelWithHint: true),
              validator: (value) => value == null || value.trim().isEmpty
                  ? isWanted
                      ? 'Describe what suppliers must provide'
                      : 'Add a description'
                  : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _chooseLocation,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(_location == null
                  ? isWanted
                      ? 'Set delivery or search area and privacy *'
                      : 'Set pickup location and privacy *'
                  : '${_location!.publicName} • ${_location!.visibility.label}'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  alignment: Alignment.centerLeft),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.photo_library_outlined),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Text(
                            '${isWanted ? 'Reference photos' : 'Photos'} ${_photos.length}/12',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800))),
                    TextButton.icon(
                        onPressed: _photos.length >= 12 || _selectingPhotos
                            ? null
                            : _selectPhotos,
                        icon: _selectingPhotos
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add),
                        label: Text(_selectingPhotos ? 'Loading…' : 'Add')),
                  ]),
                  const Text('JPEG or PNG • maximum 5 MB each',
                      style: TextStyle(fontSize: 11, color: _muted)),
                  if (_photos.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            'Choose the listing thumbnail by tapping a photo.',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                            _photos.length,
                            (index) => GestureDetector(
                                  onTap: () => setState(
                                      () => _thumbnailPhotoIndex = index),
                                  child: Container(
                                    width: 96,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                        border: Border.all(
                                            color: _thumbnailPhotoIndex == index
                                                ? _orange
                                                : const Color(0xFFD8E0E9),
                                            width: _thumbnailPhotoIndex == index
                                                ? 3
                                                : 1),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Stack(children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: FutureBuilder<Uint8List>(
                                          future: _photos[index].readAsBytes(),
                                          builder: (context, snapshot) =>
                                              SizedBox(
                                            width: 88,
                                            height: 76,
                                            child: snapshot.hasData
                                                ? Image.memory(snapshot.data!,
                                                    fit: BoxFit.cover)
                                                : const ColoredBox(
                                                    color: Color(0xFFE8EEF5),
                                                    child: Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth:
                                                                    2))),
                                          ),
                                        ),
                                      ),
                                      if (_thumbnailPhotoIndex == index)
                                        const Positioned(
                                            left: 3,
                                            bottom: 3,
                                            child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                    color: _orange,
                                                    borderRadius:
                                                        BorderRadius.all(
                                                            Radius.circular(
                                                                10))),
                                                child: Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 3),
                                                    child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .photo_size_select_actual_outlined,
                                                              size: 11,
                                                              color:
                                                                  Colors.white),
                                                          SizedBox(width: 3),
                                                          Text('Thumbnail',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 8,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900))
                                                        ])))),
                                      Positioned(
                                        right: 2,
                                        top: 2,
                                        child: InkWell(
                                          onTap: () => _removePhoto(index),
                                          child: const CircleAvatar(
                                            radius: 11,
                                            backgroundColor: Colors.black87,
                                            child: Icon(Icons.close,
                                                size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ]),
                                  ),
                                ))),
                  ],
                  const Divider(height: 20),
                  Row(children: [
                    const Icon(Icons.videocam_outlined),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Text(
                            _video == null ? 'Walk-around video' : _video!.name,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800))),
                    TextButton(
                        onPressed: _selectingVideo ? null : _selectVideo,
                        child: _selectingVideo
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(_video == null ? 'Add' : 'Replace')),
                    if (_video != null)
                      IconButton(
                          tooltip: 'Remove video',
                          onPressed: () => setState(() => _video = null),
                          icon: const Icon(Icons.close)),
                  ]),
                  const Text('One video • up to 45 seconds • maximum 25 MB',
                      style: TextStyle(fontSize: 11, color: _muted)),
                ]),
              ),
            ),
            if (_mediaTotal > 0) ...[
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_backgroundUploadMessage ?? 'Uploading media…',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                          value: _mediaTotal == 0
                              ? null
                              : _mediaProgress.clamp(0, 1)),
                      const SizedBox(height: 5),
                      Text(
                          '${(_mediaProgress * 100).round()}% • $_mediaCompleted of $_mediaTotal files complete',
                          style: const TextStyle(fontSize: 11, color: _muted)),
                    ],
                  ),
                ),
              ),
            ],
            if (widget.paidFeaturesEnabled) ...[
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                color: const Color(0xFFFFF5E8),
                child: SwitchListTile(
                  value: _boostRequested,
                  onChanged: (value) => setState(() => _boostRequested = value),
                  secondary:
                      const Icon(Icons.rocket_launch_outlined, color: _orange),
                  title: const Text('Boost listing — \$3',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: const Text(
                      'Marks this listing for checkout. Boost activates after payment is connected and confirmed.'),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _publishing ? null : _publish,
              icon: _publishing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.publish_outlined),
              label: Text(_publishing
                  ? _mediaTotal > 0 && _mediaCompleted < _mediaTotal
                      ? 'Uploading $_mediaCompleted of $_mediaTotal…'
                      : 'Publishing…'
                  : _pendingDraftId != null
                      ? 'Retry draft upload and publish'
                      : isWanted
                          ? 'Publish wanted ad'
                          : _isAuction
                              ? 'Publish timed auction'
                              : 'Publish listing'),
              style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56)),
            ),
          ]),
        ),
      ],
    );
  }

  bool get _propertyNeedsLandArea => const {
        'Commercial Property',
        'Farm & Ranch Land',
        'Fenced Yard',
        'Industrial Real Estate',
        'Lease Land',
        'Oil & Gas Lease',
        'Storage Yard',
        'Surface Rights',
      }.contains(_productType);

  Widget _propertyDetailsCard() {
    final areaValue = propertyNumber(_landArea.text);
    final conversion = convertPropertyArea(areaValue, _landAreaUnit);
    final monthlyRevenue = marketplaceMoneyValue(_monthlyRevenue.text);
    final enteredAnnualRevenue = marketplaceMoneyValue(_annualRevenue.text);
    final annualRevenue = enteredAnnualRevenue ??
        (monthlyRevenue == null ? null : monthlyRevenue * 12);
    final monthlyEquivalent = monthlyRevenue ??
        (enteredAnnualRevenue == null ? null : enteredAnnualRevenue / 12);
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFF7FAFE),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFE0F0FF),
                child: Icon(Icons.real_estate_agent_outlined, color: _orange)),
            SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Property, business and rights details',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  Text(
                      'These details appear as structured facts on the public listing.',
                      style: TextStyle(fontSize: 11, color: _muted)),
                ])),
          ]),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _propertyOffering,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'What is included in the offering? *',
                prefixIcon: Icon(Icons.inventory_outlined)),
            items: propertyOfferingOptions
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: (value) =>
                setState(() => _propertyOffering = value ?? 'Land only'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _propertyInterest,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Interest or title being offered *',
                prefixIcon: Icon(Icons.account_balance_outlined)),
            items: propertyInterestOptions
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: (value) => setState(
                () => _propertyInterest = value ?? 'Freehold / fee simple'),
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _landArea,
                onChanged: (_) => setState(() {}),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'Land area${_propertyNeedsLandArea ? ' *' : ''}',
                    hintText: 'Example: 160',
                    prefixIcon: const Icon(Icons.landscape_outlined)),
                validator: (value) {
                  if (!_propertyNeedsLandArea) return null;
                  final parsed = propertyNumber(value ?? '');
                  return parsed == null || parsed <= 0
                      ? 'Enter the land area'
                      : null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _landAreaUnit,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Area unit'),
                items: propertyAreaUnits
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _landAreaUnit = value ?? 'Acres'),
              ),
            ),
          ]),
          if (conversion.hasLandMeasure) ...[
            const SizedBox(height: 7),
            Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                    color: const Color(0xFFEAF4FD),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                    '${propertyMeasure(conversion.acres!)} acres • ${propertyMeasure(conversion.hectares!)} hectares',
                    style: const TextStyle(
                        color: Color(0xFF334E68),
                        fontWeight: FontWeight.w800))),
          ],
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _buildingArea,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Building area (optional)',
                    hintText: 'Total enclosed area',
                    prefixIcon: Icon(Icons.warehouse_outlined)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _buildingAreaUnit,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Building unit'),
                items: propertyBuildingAreaUnits
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _buildingAreaUnit = value ?? 'Square feet'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _zoningOrUse,
            decoration: const InputDecoration(
                labelText: 'Zoning or permitted use',
                hintText: 'Example: Heavy industrial, agricultural, mixed use',
                prefixIcon: Icon(Icons.map_outlined)),
          ),
          const SizedBox(height: 16),
          const Text('Income and operating information',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          const Text(
              'Optional seller-provided figures. Buyers should verify financial records during due diligence.',
              style: TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextFormField(
              controller: _monthlyRevenue,
              onChanged: (_) => setState(() {}),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [MarketplaceMoneyInputFormatter()],
              decoration: const InputDecoration(
                  labelText: 'Gross revenue / month',
                  hintText: '0.00',
                  prefixText: r'$ ',
                  prefixIcon: Icon(Icons.calendar_view_month_outlined)),
            )),
            const SizedBox(width: 8),
            Expanded(
                child: TextFormField(
              controller: _annualRevenue,
              onChanged: (_) => setState(() {}),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [MarketplaceMoneyInputFormatter()],
              decoration: const InputDecoration(
                  labelText: 'Gross revenue / year',
                  hintText: '0.00',
                  prefixText: r'$ ',
                  prefixIcon: Icon(Icons.calendar_today_outlined)),
            )),
          ]),
          if (annualRevenue != null || monthlyEquivalent != null) ...[
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFEAF8F1),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(
                  'Revenue equivalent: ${monthlyEquivalent == null ? '—' : '${marketplaceMoney(monthlyEquivalent)} / month'} • ${annualRevenue == null ? '—' : '${marketplaceMoney(annualRevenue)} / year'}',
                  style: const TextStyle(
                      color: Color(0xFF18794E), fontWeight: FontWeight.w800)),
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextFormField(
              controller: _netOperatingIncome,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [MarketplaceMoneyInputFormatter()],
              decoration: const InputDecoration(
                  labelText: 'Annual NOI',
                  hintText: 'Optional',
                  prefixText: r'$ ',
                  prefixIcon: Icon(Icons.trending_up_outlined)),
            )),
            const SizedBox(width: 8),
            Expanded(
                child: TextFormField(
              controller: _annualPropertyTax,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [MarketplaceMoneyInputFormatter()],
              decoration: const InputDecoration(
                  labelText: 'Annual property tax',
                  hintText: 'Optional',
                  prefixText: r'$ ',
                  prefixIcon: Icon(Icons.receipt_long_outlined)),
            )),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _leaseDetails,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Lease, rights or business details',
                hintText:
                    'Tenants, term, renewal, royalty, included assets or sale structure',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.description_outlined)),
          ),
          const SizedBox(height: 14),
          const Text('Property features',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Wrap(
              spacing: 7,
              runSpacing: 7,
              children: propertyFeatureOptions
                  .map((feature) => FilterChip(
                      selected: _propertyFeatures.contains(feature),
                      avatar: Icon(
                          _propertyFeatures.contains(feature)
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          size: 17),
                      label: Text(feature),
                      onSelected: (selected) => setState(() {
                            if (selected) {
                              _propertyFeatures.add(feature);
                            } else {
                              _propertyFeatures.remove(feature);
                            }
                          })))
                  .toList()),
        ]),
      ),
    );
  }

  Widget _signInRequired() => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 72),
          const Icon(Icons.lock_person_outlined, size: 64, color: _orange),
          const SizedBox(height: 18),
          const Text('Sign in to create a listing',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
              'Listings must be connected to a verified personal or business account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted)),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: _openSignIn,
              icon: const Icon(Icons.login),
              label: const Text('Sign in or create account')),
        ],
      );

  Future<void> _openSignIn() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MarketplaceAuthPage()));
    if (mounted) setState(() {});
  }

  Widget _auctionSetupCard() => Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFFFF4E5),
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.schedule, color: Color(0xFFF08A24)),
              SizedBox(width: 8),
              Text('Timed auction schedule',
                  style: TextStyle(fontWeight: FontWeight.w900))
            ]),
            const SizedBox(height: 8),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Bidding starts'),
                subtitle: Text(_formatAuctionDate(_auctionStartAt)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pickAuctionDate(start: true)),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Bidding ends'),
                subtitle: Text(_formatAuctionDate(_auctionEndAt)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pickAuctionDate(start: false)),
            TextFormField(
                controller: _minimumBidIncrement,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [MarketplaceMoneyInputFormatter()],
                decoration: const InputDecoration(
                    labelText: 'Minimum bid increase (CAD) *',
                    prefixIcon: Icon(Icons.trending_up)),
                validator: (value) {
                  final amount = num.tryParse(
                      value?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '');
                  return amount == null || amount <= 0
                      ? 'Enter an amount greater than zero'
                      : null;
                }),
            const SizedBox(height: 10),
            TextFormField(
                controller: _reservePrice,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [MarketplaceMoneyInputFormatter()],
                decoration: const InputDecoration(
                    labelText: 'Reserve price (optional)',
                    helperText:
                        'The item does not sell unless this amount is reached.',
                    prefixIcon: Icon(Icons.lock_outline))),
            const SizedBox(height: 10),
            TextFormField(
                controller: _buyItNowPrice,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [MarketplaceMoneyInputFormatter()],
                decoration: const InputDecoration(
                    labelText: 'Buy It Now price (optional)',
                    helperText:
                        'A buyer can immediately purchase and close the auction at this price.',
                    prefixIcon: Icon(Icons.flash_on_outlined))),
          ])));

  Future<void> _pickAuctionDate({required bool start}) async {
    final initial = (start ? _auctionStartAt : _auctionEndAt) ??
        DateTime.now().add(Duration(hours: start ? 1 : 24));
    final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    final selected =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _auctionStartAt = selected;
        if (_auctionEndAt == null || !_auctionEndAt!.isAfter(selected)) {
          _auctionEndAt = selected.add(const Duration(days: 7));
        }
      } else {
        _auctionEndAt = selected;
      }
    });
  }

  String _formatAuctionDate(DateTime? value) {
    if (value == null) return 'Select date and time';
    final time = TimeOfDay.fromDateTime(value).format(context);
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} • $time';
  }

  Future<void> _chooseLocation() async {
    final result = await MarketplaceLocationPicker.show(context, _location);
    if (result != null && mounted) setState(() => _location = result);
  }

  Future<void> _selectPhotos() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Add listing photos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Choose existing photos or use this device camera. You can select the thumbnail before publishing.'),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from device'),
              subtitle: const Text('Select one or more JPEG or PNG photos'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              subtitle: const Text('Open the camera for one new photo'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
          ]),
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _selectingPhotos = true);
    List<XFile> selected = const [];
    var pickerFailed = false;
    try {
      if (source == 'camera') {
        final photo = await _mediaRepository.capturePhoto(_photos.length);
        if (photo != null) selected = [photo];
      } else {
        selected = await _mediaRepository.pickPhotos(_photos.length);
      }
    } on MissingPluginException catch (error) {
      pickerFailed = true;
      _showMediaPickerError(error);
    } on PlatformException catch (error) {
      pickerFailed = true;
      _showMediaPickerError(error);
    } catch (error) {
      pickerFailed = true;
      _showMediaPickerError(error);
    } finally {
      if (mounted) setState(() => _selectingPhotos = false);
    }
    if (!mounted) return;
    setState(() {
      _photos.addAll(selected);
      if (_photos.isNotEmpty) _thumbnailPhotoIndex ??= 0;
    });
    if (selected.isEmpty && !pickerFailed) {
      PipeFeedback.show(
        context,
        message:
            'No photo was added. Use JPEG or PNG files no larger than 5 MB each.',
        tone: PipeStatusTone.warning,
      );
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      if (_photos.isEmpty) {
        _thumbnailPhotoIndex = null;
      } else if (_thumbnailPhotoIndex == index) {
        _thumbnailPhotoIndex = 0;
      } else if ((_thumbnailPhotoIndex ?? 0) > index) {
        _thumbnailPhotoIndex = _thumbnailPhotoIndex! - 1;
      }
    });
  }

  Future<void> _selectVideo() async {
    setState(() => _selectingVideo = true);
    XFile? selected;
    var pickerFailed = false;
    try {
      selected = await _mediaRepository.pickVideo();
    } on MissingPluginException catch (error) {
      pickerFailed = true;
      _showMediaPickerError(error);
    } on PlatformException catch (error) {
      pickerFailed = true;
      _showMediaPickerError(error);
    } catch (error) {
      pickerFailed = true;
      _showMediaPickerError(error);
    } finally {
      if (mounted) setState(() => _selectingVideo = false);
    }
    if (!mounted) return;
    if (selected == null && !pickerFailed) {
      PipeFeedback.show(
        context,
        message: 'Video must be 45 seconds or less and under 25 MB.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    if (selected == null) return;
    setState(() => _video = selected);
  }

  void _showMediaPickerError(Object error) {
    if (!mounted) return;
    final message = switch (error) {
      PlatformException(code: 'camera_access_denied') =>
        'Camera access was denied. Allow camera access in device settings and try again.',
      PlatformException(code: 'photo_access_denied') =>
        'Photo access was denied. Allow photo access in device settings and try again.',
      MissingPluginException() =>
        'The photo chooser is unavailable. Refresh the app or restart it after installation.',
      _ =>
        'The selected media could not be opened. Try another file or restart the chooser.',
    };
    PipeFeedback.show(
      context,
      message: message,
      tone: PipeStatusTone.error,
    );
  }

  Future<void> _publish() async {
    if (_isAuction && !widget.auctionsEnabled) {
      _showDisabledFeature('Timed auctions');
      return;
    }
    if (_isWanted && !widget.wantedAdsEnabled) {
      _showDisabledFeature('Wanted ads');
      return;
    }
    if (_isProperty && !widget.regulatedListingsEnabled) {
      _showDisabledFeature('Property and rights listings');
      return;
    }
    if (_boostRequested && !widget.paidFeaturesEnabled) {
      setState(() => _boostRequested = false);
      _showDisabledFeature('Paid listing boosts');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_location == null) {
      PipeFeedback.show(
        context,
        message: _isWanted
            ? 'Set the requested delivery or search area and privacy level.'
            : 'Set a pickup location and privacy level.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    if (_listingType == 'Auction') {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final user =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = user.data() ?? const <String, dynamic>{};
      if (!mounted) return;
      final score = (data['userScore'] as num?)?.toInt() ?? 70;
      final completion = (data['profileCompletion'] as num?)?.toInt() ?? 0;
      final isAdmin = await marketplaceAdministratorAccess();
      if (!mounted) return;
      if (!isAdmin &&
          (score <= 80 ||
              completion != 100 ||
              data['accountVerified'] != true ||
              (data['accountVerificationReviewVersion'] as num? ?? 0) < 1)) {
        PipeFeedback.show(
          context,
          message:
              'Auction listings require a User Score above 80, 100% profile completion, and verified account status.',
          tone: PipeStatusTone.warning,
        );
        return;
      }
      if (_auctionStartAt == null ||
          _auctionEndAt == null ||
          !_auctionEndAt!.isAfter(_auctionStartAt!)) {
        PipeFeedback.show(
          context,
          message:
              'Choose a valid auction start and end time. The end must be after the start.',
          tone: PipeStatusTone.warning,
        );
        return;
      }
    }
    setState(() => _publishing = true);
    try {
      final rawPrice = marketplaceMoneyValue(_price.text);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Sign in required.');
      final isPipeListing = _category == 'Pipe, Tubing & Materials' ||
          const {
            'Drill Pipe',
            'Casing',
            'Tubing',
            'Line Pipe',
            'OCTG',
            'Sucker Rod'
          }.contains(_productType);
      final isMachine = _category == 'Heavy Equipment';
      final isProperty = _isProperty;
      final landAreaInput = propertyNumber(_landArea.text);
      final landArea = convertPropertyArea(landAreaInput, _landAreaUnit);
      final monthlyRevenue = marketplaceMoneyValue(_monthlyRevenue.text);
      final enteredAnnualRevenue = marketplaceMoneyValue(_annualRevenue.text);
      final annualRevenue = enteredAnnualRevenue ??
          (monthlyRevenue == null ? null : monthlyRevenue * 12);
      final listingId = _pendingDraftId ?? _repository.newListingId();
      _pendingDraftId = listingId;
      _pendingPublishRequestId ??=
          FirebaseFirestore.instance.collection('draft_publications').doc().id;
      final queuedPhotos = List<XFile>.from(_photos);
      final selectedThumbnail = _thumbnailPhotoIndex;
      if (selectedThumbnail != null &&
          selectedThumbnail > 0 &&
          selectedThumbnail < queuedPhotos.length) {
        final thumbnail = queuedPhotos.removeAt(selectedThumbnail);
        queuedPhotos.insert(0, thumbnail);
      }
      final queuedVideo = _video;
      final hasQueuedMedia = queuedPhotos.isNotEmpty || queuedVideo != null;
      final listingValues = <String, dynamic>{
        'title': _title.text.trim(),
        'category': _category,
        'productType': _productType == _otherCatalogValue
            ? _customProductType.text.trim()
            : _productType,
        'brand': isMachine
            ? (_equipmentBrand == _otherCatalogValue
                ? _brand.text.trim()
                : _equipmentBrand)
            : _brand.text.trim(),
        'model': isMachine
            ? (_equipmentModel == _otherCatalogValue
                ? _model.text.trim()
                : _equipmentModel)
            : _model.text.trim(),
        'modelYear': isMachine ? _equipmentYear : null,
        'machineHours': isMachine
            ? int.tryParse(_machineHours.text.replaceAll(RegExp(r'[^0-9]'), ''))
            : null,
        'operatingStatus': isMachine ? _operatingStatus : null,
        'maintenanceHistory': isMachine ? _maintenanceHistory : null,
        'serialNumber': isMachine ? _serialNumber.text.trim() : null,
        'engineDetails': isMachine ? _engineDetails.text.trim() : null,
        'attachments': isMachine ? _attachments.text.trim() : null,
        'pipeSize': _pipeSize == _otherCatalogValue
            ? _customPipeSize.text.trim()
            : _pipeSize,
        'quantity':
            int.tryParse(_quantity.text.replaceAll(RegExp(r'[^0-9]'), '')),
        'quantityAndLength': _quantity.text.trim(),
        'condition': _condition,
        'inspectionStatus': _inspectionStatus,
        'inspectionDetails': _inspectionDetails.text.trim(),
        'pipeBand': isPipeListing
            ? (_pipeBand == 'Other owner or operator marking'
                ? _customPipeBand.text.trim()
                : _pipeBand)
            : null,
        if (isProperty) ...{
          'propertyOffering': _propertyOffering,
          'propertyInterest': _propertyInterest,
          'landAreaInputValue': landAreaInput,
          'landAreaInputUnit': _landAreaUnit,
          'landAreaAcres': landArea.acres,
          'landAreaHectares': landArea.hectares,
          'buildingAreaValue': propertyNumber(_buildingArea.text),
          'buildingAreaUnit': _buildingAreaUnit,
          'zoningOrUse': _zoningOrUse.text.trim(),
          'monthlyRevenue': monthlyRevenue,
          'annualRevenue': annualRevenue,
          'netOperatingIncome': marketplaceMoneyValue(_netOperatingIncome.text),
          'annualPropertyTax': marketplaceMoneyValue(_annualPropertyTax.text),
          'leaseDetails': _leaseDetails.text.trim(),
          'propertyFeatures': _propertyFeatures.toList()..sort(),
        },
        'transactionType': _listingType,
        if (_isWanted) ...{
          'wantedStatus': 'open',
          'responseCount': 0,
          'requestType': 'wanted_ad',
        },
        'price': rawPrice,
        if (_listingType == 'Auction') ...{
          'startingBid': rawPrice,
          'currentBid': 0,
          'minimumBidIncrement':
              marketplaceMoneyValue(_minimumBidIncrement.text) ?? 1,
          'reservePrice': marketplaceMoneyValue(_reservePrice.text),
          'buyItNowPrice': marketplaceMoneyValue(_buyItNowPrice.text),
          'auctionStartAt': Timestamp.fromDate(_auctionStartAt!),
          'auctionEndAt': Timestamp.fromDate(_auctionEndAt!),
          'bidCount': 0,
          'auctionStatus':
              _auctionStartAt!.isAfter(DateTime.now()) ? 'scheduled' : 'live',
        },
        'priceBasis': _priceBasis,
        'priceFlexibility': _priceFlexibility,
        'openToOffers': _priceFlexibility == 'Open to offers',
        'currency': 'CAD',
        'description': _description.text.trim(),
        'sellerName': user.displayName ?? user.email ?? 'Marketplace seller',
        'sellerPhotoUrl': user.photoURL,
        'sellerVerified': false,
        'imageUrls': const <String>[],
        'thumbnailUrl': null,
        'videoUrl': null,
        'mediaPhotoCount': queuedPhotos.length,
        'hasVideo': queuedVideo != null,
        'mediaUploadStatus': hasQueuedMedia ? 'queued' : 'none',
        'boostRequested': _boostRequested,
        'boostPrice': _boostRequested ? 3 : null,
        'boostCurrency': _boostRequested ? 'CAD' : null,
        'boostStatus': _boostRequested ? 'awaiting_payment_setup' : 'none',
        'viewCount': 0,
        'saveCount': 0,
        'shareCount': 0,
        'messageCount': 0,
        'offerCount': 0,
      };
      await _repository.createListingDraft(listingValues,
          location: _location!, listingId: listingId);
      if (hasQueuedMedia) {
        await _uploadDraftMedia(listingId, queuedPhotos, queuedVideo);
      }
      await _repository.publishListingDraft(listingId,
          requestId: _pendingPublishRequestId!);
      final catalogSuggestions = <Map<String, String>>[
        if (_productType == _otherCatalogValue)
          {
            'field': 'productType',
            'value': _customProductType.text.trim(),
            'category': _category ?? '',
            'context': 'Create listing'
          },
        if (_equipmentBrand == _otherCatalogValue)
          {
            'field': 'equipmentBrand',
            'value': _brand.text.trim(),
            'category': _category ?? '',
            'context': _productType ?? ''
          },
        if (_equipmentModel == _otherCatalogValue)
          {
            'field': 'equipmentModel',
            'value': _model.text.trim(),
            'category': _equipmentBrand == _otherCatalogValue
                ? _brand.text.trim()
                : (_equipmentBrand ?? ''),
            'context': _productType ?? ''
          },
        if (_pipeSize == _otherCatalogValue)
          {
            'field': 'pipeSize',
            'value': _customPipeSize.text.trim(),
            'category': _category ?? '',
            'context': _productType ?? ''
          },
        if (_pipeBand == 'Other owner or operator marking')
          {
            'field': 'pipeBand',
            'value': _customPipeBand.text.trim(),
            'category': _category ?? '',
            'context': _productType ?? ''
          },
      ];
      if (catalogSuggestions.isNotEmpty) {
        try {
          await _repository.submitCatalogSuggestions(
              listingId: listingId, suggestions: catalogSuggestions);
        } catch (error) {
          debugPrint('Catalog suggestion submission failed: $error');
        }
      }
      if (!mounted) return;
      _formKey.currentState!.reset();
      _title.clear();
      _price.clear();
      _description.clear();
      _brand.clear();
      _model.clear();
      _quantity.clear();
      _inspectionDetails.clear();
      _machineHours.clear();
      _serialNumber.clear();
      _engineDetails.clear();
      _attachments.clear();
      _customProductType.clear();
      _customPipeSize.clear();
      _customPipeBand.clear();
      _reservePrice.clear();
      _buyItNowPrice.clear();
      _minimumBidIncrement.text = '25';
      _landArea.clear();
      _buildingArea.clear();
      _zoningOrUse.clear();
      _monthlyRevenue.clear();
      _annualRevenue.clear();
      _netOperatingIncome.clear();
      _annualPropertyTax.clear();
      _leaseDetails.clear();
      _photos.clear();
      _thumbnailPhotoIndex = null;
      _video = null;
      setState(() {
        _category = null;
        _productType = null;
        _pipeSize = null;
        _condition = null;
        _inspectionStatus = 'Not inspected / unknown';
        _pipeBand = 'No band / unknown';
        _equipmentBrand = null;
        _equipmentModel = null;
        _equipmentYear = null;
        _maintenanceHistory = 'Unknown / not available';
        _operatingStatus = 'Operational';
        _priceBasis = 'Per piece';
        _priceFlexibility = 'Open to offers';
        _landAreaUnit = 'Acres';
        _buildingAreaUnit = 'Square feet';
        _propertyInterest = 'Freehold / fee simple';
        _propertyOffering = 'Land only';
        _propertyFeatures.clear();
        _boostRequested = false;
        _location = null;
        _auctionStartAt = null;
        _auctionEndAt = null;
        _listingType = widget.initialAuction ? 'Auction' : 'For Sale';
      });
      _pendingDraftId = null;
      _pendingPublishRequestId = null;
      _mediaCompleted = 0;
      _mediaTotal = 0;
      _mediaProgress = 0;
      _backgroundUploadMessage = null;
      try {
        await _showPublishedOptions(listingId);
      } catch (error) {
        if (mounted) {
          PipeFeedback.show(
            context,
            message:
                'Listing published successfully, but the preview could not open. View it from My Listings or Auctions.',
            tone: PipeStatusTone.warning,
          );
        }
      }
    } catch (error) {
      debugPrint('Listing publication failed: $error');
      if (mounted) {
        final message = switch (error) {
          StateError() => error.message.toString(),
          MarketplaceMediaUploadException() => error.userMessage,
          _ => 'The listing could not be published. Your form is still here; '
              'check your connection and try again.',
        };
        PipeFeedback.show(
          context,
          message: message,
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _uploadDraftMedia(
      String listingId, List<XFile> photos, XFile? video) async {
    final total = photos.length + (video == null ? 0 : 1);
    if (mounted) {
      setState(() {
        _mediaCompleted = 0;
        _mediaTotal = total;
        _mediaProgress = 0;
        _backgroundUploadMessage =
            'Uploading selected media before the listing becomes public…';
      });
    }
    try {
      await _repository.updateListingDraftMedia(listingId,
          imageUrls: const [], thumbnailUrl: null, status: 'uploading');
      final media = await _mediaRepository.upload(
        listingId: listingId,
        photos: photos,
        video: video,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _mediaCompleted = progress.completedFiles;
            _mediaProgress = progress.overallProgress;
            _backgroundUploadMessage = progress.retrying
                ? 'Connection interrupted — retrying ${progress.currentFile} (${progress.attempt} of ${progress.maxAttempts})'
                : 'Uploading ${progress.currentFile}…';
          });
        },
      );
      await _repository.updateListingDraftMedia(listingId,
          imageUrls: media.imageUrls,
          imageHashes: media.imageHashes,
          thumbnailUrl: media.imageUrls.firstOrNull,
          videoUrl: media.videoUrl,
          status: 'complete');
      if (mounted) {
        setState(() {
          _mediaCompleted = total;
          _mediaProgress = 1;
          _backgroundUploadMessage =
              'Media upload complete — finalizing publication…';
        });
      }
    } catch (error) {
      try {
        await _repository.updateListingDraftMedia(listingId,
            imageUrls: const [],
            thumbnailUrl: null,
            status: 'failed',
            error: error.toString());
      } catch (_) {}
      if (mounted) {
        setState(() => _backgroundUploadMessage =
            'Upload paused. The listing remains a private draft; retry when your connection is ready.');
      }
      rethrow;
    }
  }

  Future<void> _showPublishedOptions(String listingId) async {
    if (!mounted) return;
    final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
              title: const Text('Listing published'),
              content: const Text('Would you like to list another item?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, 'home'),
                    child: const Text('Go home')),
                OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'view'),
                    child: const Text('View listing')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, 'another'),
                    child: const Text('List another')),
              ],
            ));
    if (!mounted || choice == 'another') return;
    if (choice == 'home') {
      widget.onHome();
      return;
    }
    final result = await FirebaseFirestore.instance
        .collection('public_listings')
        .where(FieldPath.documentId, isEqualTo: listingId)
        .limit(1)
        .get();
    if (!mounted || result.docs.isEmpty) return;
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: _panel,
        builder: (_) => _ListingDetails(
            MarketplaceListing.fromFirestore(result.docs.first)));
  }
}

/*
 * Retired FlutterFlow vehicle-listing form.
 * Kept temporarily as migration reference, but excluded from compilation so
 * the marketplace has one authoritative create-listing workflow.
class _AddListingPage extends StatefulWidget {
  const _AddListingPage();
  @override
  State<_AddListingPage> createState() => _AddListingPageState();
}

class _AddListingPageState extends State<_AddListingPage> {
  final _form = GlobalKey<FormState>();
  final _catalogRepository = MarketplaceCatalogRepository();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _gradeController = TextEditingController();
  String? _category;
  String? _type;
  String? _brand;
  String? _model;
  String? _pipeSize;
  String? _pipeSchedule;
  MarketplaceLocation? _location;
  String _transaction = 'For Sale';
  List<String> _pipeSizes = pipeNominalSizes;
  Map<String, List<String>> _brandModels = equipmentBrandModels;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final results = await Future.wait([
      _catalogRepository.loadPipeSizes(pipeNominalSizes),
      _catalogRepository.loadBrandModels(equipmentBrandModels),
    ]);
    if (!mounted) return;
    setState(() {
      _pipeSizes = results[0] as List<String>;
      _brandModels = results[1] as Map<String, List<String>>;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = marketplaceCategories
        .where((item) => item.name == _category)
        .firstOrNull;
    final isPipe = _category == 'Pipe, Tubing & Materials';
    final isFabricated = _category == 'Farm & Ranch Products';
    final availablePipeSizes =
        _type == 'Sucker Rod' ? suckerRodSizes : _pipeSizes;
    final availableModels = _brandModels[_brand] ?? const <String>[];
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Create listing',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      const Text('Reach qualified industrial buyers and operators.',
          style: TextStyle(color: _muted)),
      const SizedBox(height: 22),
      Form(
          key: _form,
          child: Column(children: [
            DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(
                    labelText: 'Product category',
                    prefixIcon: CatalogIcon(label: _category)),
                items: marketplaceCategories
                    .map((item) => DropdownMenuItem(
                        value: item.name,
                        child: Row(children: [
                          Icon(item.icon, color: _orange, size: 20),
                          const SizedBox(width: 9),
                          Flexible(child: Text(item.name))
                        ])))
                    .toList(),
                onChanged: (value) => setState(() {
                      _category = value;
                      _type = null;
                      _brand = null;
                      _model = null;
                      _pipeSize = null;
                      _pipeSchedule = null;
                    }),
                validator: (value) =>
                    value == null ? 'Select a category' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                value: _type,
                decoration: InputDecoration(
                    labelText: 'Product type',
                    prefixIcon: CatalogIcon(label: _type)),
                items: (selected?.types ?? const <String>[])
                    .map((item) => DropdownMenuItem(
                        value: item,
                        child: Row(children: [
                          CatalogIcon(label: item, size: 20),
                          const SizedBox(width: 9),
                          Text(item)
                        ])))
                    .toList(),
                onChanged: selected == null
                    ? null
                    : (value) => setState(() => _type = value),
                validator: (value) =>
                    value == null ? 'Select a product type' : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: 'Listing title',
                    hintText: 'e.g. CAT 320 Hydraulic Excavator'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a title'
                    : null),
            const SizedBox(height: 12),
            if (isPipe)
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<String>(
                        value: _pipeSize,
                        decoration: const InputDecoration(
                            labelText: 'Nominal pipe size'),
                        items: availablePipeSizes
                            .map((item) => DropdownMenuItem(
                                value: item, child: Text(item)))
                            .toList(),
                        onChanged: (value) => setState(() => _pipeSize = value),
                        validator: (value) =>
                            value == null ? 'Select size' : null)),
                const SizedBox(width: 10),
                Expanded(
                    child: DropdownButtonFormField<String>(
                        value: _pipeSchedule,
                        decoration: const InputDecoration(
                            labelText: 'Pipe type / wall',
                            hintText: 'Not sure is OK'),
                        items: sellerFriendlyPipeTypes
                            .map((item) => DropdownMenuItem(
                                value: item, child: Text(item)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _pipeSchedule = value),
                        validator: (value) =>
                            value == null ? 'Choose best description' : null)),
              ])
            else if (isFabricated)
              Column(children: [
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'Overall width / length',
                              hintText: "e.g. 16 ft"))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'Overall height',
                              hintText: "e.g. 5 ft"))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: DropdownButtonFormField<String>(
                          value: _pipeSize,
                          decoration: const InputDecoration(
                              labelText: 'Pipe / rod used'),
                          items: _pipeSizes
                              .map((item) => DropdownMenuItem(
                                  value: item, child: Text(item)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _pipeSize = value))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: DropdownButtonFormField<String>(
                          value: _pipeSchedule,
                          decoration:
                              const InputDecoration(labelText: 'Finish'),
                          items: const [
                            'Raw steel',
                            'Painted',
                            'Powder coated',
                            'Galvanized',
                            'Used oilfield pipe',
                            'Not sure'
                          ]
                              .map((item) => DropdownMenuItem(
                                  value: item, child: Text(item)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _pipeSchedule = value))),
                ]),
              ])
            else if (selected != null)
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<String>(
                        value: _brand,
                        decoration: InputDecoration(
                            labelText: 'Brand',
                            prefixIcon: const Icon(Icons.factory_outlined)),
                        items: _brandModels.keys
                            .map((item) => DropdownMenuItem(
                                value: item,
                                child: Row(children: [
                                  const Icon(Icons.factory_outlined,
                                      color: _orange, size: 20),
                                  const SizedBox(width: 9),
                                  Flexible(child: Text(item))
                                ])))
                            .toList(),
                        onChanged: (value) => setState(() {
                              _brand = value;
                              _model = null;
                            }))),
                const SizedBox(width: 10),
                Expanded(
                    child: DropdownButtonFormField<String>(
                        value: _model,
                        decoration: InputDecoration(
                            labelText: 'Model',
                            prefixIcon:
                                const Icon(Icons.precision_manufacturing)),
                        items: availableModels
                            .map((item) => DropdownMenuItem(
                                value: item, child: Text(item)))
                            .toList(),
                        onChanged: _brand == null
                            ? null
                            : (value) => setState(() => _model = value))),
              ])
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF5E8),
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Icon(Icons.touch_app_outlined, color: _orange),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          'Select a product category to load the correct listing fields.')),
                ]),
              ),
            const SizedBox(height: 12),
            if (isPipe) ...[
              TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                      labelText: 'Length and quantity',
                      hintText: 'e.g. 32 ft joints • 60 pieces')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _gradeController,
                  decoration: const InputDecoration(
                      labelText: 'Grade / schedule (optional)',
                      hintText: 'Only enter this if you know it')),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
                value: _transaction,
                decoration: const InputDecoration(labelText: 'Listing type'),
                items: const [
                  'For Sale',
                  'For Rent',
                  'Auction',
                  'Request for Quote',
                  'Wanted / Seeking'
                ]
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) => setState(() => _transaction = value!)),
            const SizedBox(height: 12),
            TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Price', prefixText: '\$ ')),
            const SizedBox(height: 12),
            FormField<MarketplaceLocation>(
                initialValue: _location,
                validator: (_) => _location == null
                    ? 'Choose a pickup location and privacy level'
                    : null,
                builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                              onPressed: () async {
                                final result =
                                    await MarketplaceLocationPicker.show(
                                        context, _location);
                                if (result == null) return;
                                setState(() => _location = result);
                                field.didChange(result);
                              },
                              icon: const Icon(Icons.add_location_alt_outlined),
                              label: Text(_location == null
                                  ? 'Set address, map pin & privacy'
                                  : '${_location!.publicName} • ${_location!.visibility.label}'),
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                  alignment: Alignment.centerLeft)),
                          if (field.hasError)
                            Padding(
                                padding:
                                    const EdgeInsets.only(left: 12, top: 6),
                                child: Text(field.errorText!,
                                    style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        fontSize: 12)))
                        ])),
            const SizedBox(height: 12),
            TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Description & specifications',
                    alignLabelWithHint: true)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Add photos and documents'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54))),
            const SizedBox(height: 18),
            FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  try {
                    final rawPrice = _priceController.text
                        .replaceAll(RegExp(r'[^0-9.]'), '');
                    final user = FirebaseAuth.instance.currentUser;
                    await _catalogRepository.publishListing({
                      'title': _titleController.text.trim(),
                      'category': _category,
                      'productType': _type,
                      'brand': _brand,
                      'model': _model,
                      'pipeSize': _pipeSize,
                      'pipeDescription': _pipeSchedule,
                      'quantityAndLength': _quantityController.text.trim(),
                      'gradeOrSchedule': _gradeController.text.trim(),
                      'transactionType': _transaction,
                      'price': num.tryParse(rawPrice),
                      'currency': 'CAD',
                      'description': _descriptionController.text.trim(),
                      'sellerName': user?.displayName ?? 'Marketplace seller',
                      'sellerVerified': false,
                      'imageUrls': const <String>[],
                    }, location: _location);
                    if (!context.mounted) return;
                    PipeFeedback.show(
                      context,
                      message: 'Listing published successfully.',
                      tone: PipeStatusTone.success,
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    PipeFeedback.show(
                      context,
                      message: marketplaceCommandErrorMessage(
                        error,
                        fallback:
                            'The listing could not be published. Check your connection and sign-in, then try again.',
                      ),
                      tone: PipeStatusTone.error,
                    );
                  }
                },
                style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56)),
                child: const Text('Publish listing',
                    style: TextStyle(fontWeight: FontWeight.w800)))
          ]))
    ]);
  }
}

*/
class _SavedPage extends StatelessWidget {
  const _SavedPage({
    required this.saved,
    required this.signedIn,
    required this.loading,
    required this.error,
    required this.onBrowse,
    required this.onSaved,
    required this.onRemove,
    required this.onAccount,
    required this.onRetry,
  });

  final Set<String> saved;
  final bool signedIn;
  final bool loading;
  final Object? error;
  final VoidCallback onBrowse;
  final ValueChanged<MarketplaceListing> onSaved;
  final ValueChanged<String> onRemove;
  final VoidCallback onAccount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Saved listings',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(
            'Your saved items stay with your account on every device.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          Expanded(child: _body(context)),
        ]));
  }

  Widget _body(BuildContext context) {
    if (!signedIn) {
      return MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.unavailable,
        icon: Icons.account_circle_outlined,
        title: 'Sign in to see your saved listings',
        message: 'Saved items are private and linked to your account.',
        primaryLabel: 'Open account',
        onPrimary: onAccount,
      );
    }
    if (loading) {
      return const MarketplaceDataStateView.loading(
        title: 'Loading saved listings',
        message: 'Restoring the items saved to your account…',
      );
    }
    if (error != null) {
      return MarketplaceDataStateView.failure(
        error: error,
        resource: 'Saved listings',
        onRetry: onRetry,
      );
    }
    if (saved.isEmpty) {
      return MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.empty,
        icon: Icons.bookmark_border,
        title: 'No saved listings yet',
        message: 'Use the bookmark on a listing to keep it here.',
        primaryLabel: 'Browse marketplace',
        onPrimary: onBrowse,
      );
    }
    return ListView(
      children: saved
          .map((listingId) => _SavedListingCard(
                listingId: listingId,
                onSaved: onSaved,
                onRemove: onRemove,
              ))
          .toList(growable: false),
    );
  }
}

class _SavedListingCard extends StatelessWidget {
  const _SavedListingCard({
    required this.listingId,
    required this.onSaved,
    required this.onRemove,
  });

  final String listingId;
  final ValueChanged<MarketplaceListing> onSaved;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('public_listings')
            .doc(listingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _unavailable(
              context,
              'This saved listing could not be loaded.',
            );
          }
          if (!snapshot.hasData) {
            return const Card(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator())));
          }
          if (!snapshot.data!.exists) {
            return _unavailable(
              context,
              'This listing is no longer available.',
            );
          }
          final listing = MarketplaceListing.fromFirestore(snapshot.data!);
          return _ListingCard(
            listing: listing,
            saved: true,
            onSaved: () => onSaved(listing),
          );
        },
      );

  Widget _unavailable(BuildContext context, String message) => Card(
        child: ListTile(
          leading: const Icon(Icons.inventory_2_outlined, color: _muted),
          title: Text(message),
          subtitle: const Text('You can remove it from your saved items.'),
          trailing: IconButton(
            tooltip: 'Remove saved listing',
            onPressed: () => onRemove(listingId),
            icon: const Icon(Icons.bookmark_remove_outlined),
          ),
        ),
      );
}
