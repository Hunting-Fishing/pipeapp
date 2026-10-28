import 'package:flutter/material.dart';

@immutable
class PartnerBrandCategoryOption {
  const PartnerBrandCategoryOption({
    required this.code,
    required this.label,
    required this.shortLabel,
    required this.subtitle,
    required this.icon,
  });

  final String code;
  final String label;
  final String shortLabel;
  final String subtitle;
  final IconData icon;
}

@immutable
class PartnerProgramPillar {
  const PartnerProgramPillar({
    required this.code,
    required this.title,
    required this.tagline,
    required this.description,
    required this.examples,
    required this.icon,
  });

  final String code;
  final String title;
  final String tagline;
  final String description;
  final List<String> examples;
  final IconData icon;
}

@immutable
class PartnerCommercialModelOption {
  const PartnerCommercialModelOption({
    required this.code,
    required this.label,
    required this.description,
  });

  final String code;
  final String label;
  final String description;
}

@immutable
class PartnerShowcaseDeal {
  const PartnerShowcaseDeal({
    required this.showcaseId,
    required this.partnerName,
    required this.brandCategory,
    required this.programTypes,
    required this.headline,
    required this.summary,
    required this.offerBadge,
    this.discountDetails = '',
    this.productHighlights = const <String>[],
    this.targetRegions = const <String>['North America'],
    this.ctaLabel = 'Request Fleet / Deal Info',
    this.ctaUrl = '',
    this.logoUrl = '',
    this.bannerUrl = '',
    this.featured = false,
    this.active = true,
    this.priorityRank = 100,
    this.isProgramPreview = false,
  });

  final String showcaseId;
  final String partnerName;
  final String brandCategory;
  final List<String> programTypes;
  final String headline;
  final String summary;
  final String offerBadge;
  final String discountDetails;
  final List<String> productHighlights;
  final List<String> targetRegions;
  final String ctaLabel;
  final String ctaUrl;
  final String logoUrl;
  final String bannerUrl;
  final bool featured;
  final bool active;
  final int priorityRank;
  final bool isProgramPreview;

  factory PartnerShowcaseDeal.fromJson(Map<String, dynamic> json) {
    List<String> readList(Object? raw) {
      if (raw is! List) return const <String>[];
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return PartnerShowcaseDeal(
      showcaseId: '${json['showcaseId'] ?? json['id'] ?? ''}'.trim(),
      partnerName: '${json['partnerName'] ?? ''}'.trim(),
      brandCategory:
          '${json['brandCategory'] ?? 'oem_fleet_crew_trucks'}'.trim(),
      programTypes: readList(json['programTypes']),
      headline: '${json['headline'] ?? ''}'.trim(),
      summary: '${json['summary'] ?? ''}'.trim(),
      offerBadge: '${json['offerBadge'] ?? 'Featured Partner'}'.trim(),
      discountDetails: '${json['discountDetails'] ?? ''}'.trim(),
      productHighlights: readList(json['productHighlights']),
      targetRegions: readList(json['targetRegions']).isEmpty
          ? const <String>['North America']
          : readList(json['targetRegions']),
      ctaLabel: '${json['ctaLabel'] ?? 'Request Fleet / Deal Info'}'.trim(),
      ctaUrl: '${json['ctaUrl'] ?? ''}'.trim(),
      logoUrl: '${json['logoUrl'] ?? ''}'.trim(),
      bannerUrl: '${json['bannerUrl'] ?? ''}'.trim(),
      featured: json['featured'] == true,
      active: json['active'] != false,
      priorityRank: int.tryParse('${json['priorityRank'] ?? 100}') ?? 100,
      isProgramPreview: json['isProgramPreview'] == true,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'showcaseId': showcaseId,
        'partnerName': partnerName,
        'brandCategory': brandCategory,
        'programTypes': programTypes,
        'headline': headline,
        'summary': summary,
        'offerBadge': offerBadge,
        'discountDetails': discountDetails,
        'productHighlights': productHighlights,
        'targetRegions': targetRegions,
        'ctaLabel': ctaLabel,
        'ctaUrl': ctaUrl,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'featured': featured,
        'active': active,
        'priorityRank': priorityRank,
        'isProgramPreview': isProgramPreview,
      };
}

abstract final class PipeBuyerPartnerTaxonomy {
  static const List<PartnerBrandCategoryOption> brandCategories = [
    PartnerBrandCategoryOption(
      code: 'oem_fleet_crew_trucks',
      label: 'OEM Vehicles, Fleet & Crew Trucks',
      shortLabel: 'Fleet & Crew Trucks',
      subtitle:
          'OEM automakers, commercial truck dealers, chassis cabs, welding & service upfitters.',
      icon: Icons.directions_car_filled_outlined,
    ),
    PartnerBrandCategoryOption(
      code: 'oilfield_deals_discounts',
      label: 'Oilfield Crew Deals & Corporate Discounts',
      shortLabel: 'Oilfield Deals',
      subtitle:
          'Exclusive rebates, volume fleet pricing, and crew perks for oil & gas operators.',
      icon: Icons.local_offer_outlined,
    ),
    PartnerBrandCategoryOption(
      code: 'heavy_equipment_machinery',
      label: 'Heavy Equipment & Rig Machinery',
      shortLabel: 'Heavy Equipment',
      subtitle:
          'Excavators, loaders, telehandlers, generators, compressors, and rig packages.',
      icon: Icons.precision_manufacturing_outlined,
    ),
    PartnerBrandCategoryOption(
      code: 'pipe_valves_tubulars',
      label: 'Pipe, OCTG, Valves & Fittings',
      shortLabel: 'Pipe & OCTG',
      subtitle:
          'Manufacturers, mills, and stocking distributors of line pipe, casing, and valves.',
      icon: Icons.plumbing_outlined,
    ),
    PartnerBrandCategoryOption(
      code: 'tools_ppe_site_gear',
      label: 'Industrial Tools, Safety PPE & Crew Gear',
      shortLabel: 'Tools & Safety PPE',
      subtitle:
          'FR workwear, H2S gas detection, torque tools, welding gear, and rig consumables.',
      icon: Icons.health_and_safety_outlined,
    ),
    PartnerBrandCategoryOption(
      code: 'modular_site_buildings',
      label: 'Modular Offices, Camps & Site Buildings',
      shortLabel: 'Site Buildings',
      subtitle:
          'Wellsite skids, command trailers, workforce housing, and guard booths.',
      icon: Icons.cabin_outlined,
    ),
    PartnerBrandCategoryOption(
      code: 'fuel_fleet_logistics',
      label: 'Fuel Cards, Telematics & Fleet Logistics',
      shortLabel: 'Fuel & Fleet Ops',
      subtitle:
          'Commercial fuel cards, ELD/GPS fleet telematics, tires, and preventative maintenance.',
      icon: Icons.ev_station_outlined,
    ),
    PartnerBrandCategoryOption(
      code: 'industrial_tech_services',
      label: 'Field Software & Industrial Services',
      shortLabel: 'Tech & Services',
      subtitle:
          'Field ticketing, SCADA monitoring, inspection, and enterprise oilfield solutions.',
      icon: Icons.hub_outlined,
    ),
  ];

  static const List<PartnerProgramPillar> programPillars = [
    PartnerProgramPillar(
      code: 'promote_brand',
      title: 'Promote With Us',
      tagline: 'OEM & Brand Presence',
      description:
          'Position your brand directly in front of oilfield buyers, fleet managers, contractors, and procurement teams.',
      examples: [
        'OEM commercial vehicle & crew truck spotlights (e.g., Ford Super Duty / Chassis Cab)',
        'Dedicated brand showcase profile & regional dealer routing',
        'Co-branded basin & seasonal fleet readiness campaigns',
      ],
      icon: Icons.campaign_outlined,
    ),
    PartnerProgramPillar(
      code: 'advertise_campaigns',
      title: 'Advertise With Us',
      tagline: 'High-Intent Category Placements',
      description:
          'Reach decision-makers actively searching for trucks, heavy equipment, tubulars, and field services.',
      examples: [
        'Sponsored placements across Marketplace & Global Oilfield Directory',
        'Targeted basin visibility (Permian, WCSB, Bakken, Eagle Ford, Gulf Coast)',
        'Direct lead capture for commercial sales & fleet reps',
      ],
      icon: Icons.ads_click_rounded,
    ),
    PartnerProgramPillar(
      code: 'showcase_sell_products',
      title: 'Showcase & Sell Products',
      tagline: 'Direct Commercial Merchandising',
      description:
          'Display and sell new inventory, factory packages, commercial trucks, tools, and related items on Pipe Buyer.',
      examples: [
        'Turnkey crew trucks, service bodies, welders & trailer packages',
        'Direct product catalog & factory-authorized equipment listings',
        'Qualified commercial RFQ and fleet order routing',
      ],
      icon: Icons.storefront_outlined,
    ),
    PartnerProgramPillar(
      code: 'oilfield_deals_discounts',
      title: 'Oilfield Deals & Discounts',
      tagline: 'Exclusive Fleet & Crew Rebates',
      description:
          'Offer verified Pipe Buyer companies fleet allowances, upfit incentives, and volume oilfield discounts.',
      examples: [
        'Commercial upfit rebates & multi-unit crew truck fleet pricing',
        'Volume discounts on FR PPE, tires, fuel cards, and field tools',
        'Member-only seasonal oilfield promotions',
      ],
      icon: Icons.verified_outlined,
    ),
  ];

  static const List<PartnerCommercialModelOption> commercialModels = [
    PartnerCommercialModelOption(
      code: 'sponsored_showcase',
      label: 'Sponsored Brand / OEM Fleet Showcase',
      description:
          'Featured brand spotlight, fleet model showcase, and direct buyer lead routing.',
    ),
    PartnerCommercialModelOption(
      code: 'direct_marketplace_storefront',
      label: 'Showcase & Sell Products Directly on Site',
      description:
          'Dedicated partner merchandising to showcase and sell equipment, trucks, and gear.',
    ),
    PartnerCommercialModelOption(
      code: 'member_fleet_discount',
      label: 'Oilfield Deals, Rebates & Crew Discount Program',
      description:
          'Publish exclusive commercial rebates or volume pricing for Pipe Buyer companies.',
    ),
    PartnerCommercialModelOption(
      code: 'category_banner_ads',
      label: 'Targeted Category & Directory Advertising',
      description:
          'High-visibility sponsored placements across targeted categories and basins.',
    ),
    PartnerCommercialModelOption(
      code: 'custom_enterprise',
      label: 'Custom National / OEM Enterprise Partnership',
      description:
          'Tailored multi-region campaign for major OEMs, dealer groups, and manufacturers.',
    ),
  ];

  static const List<String> targetRegionOptions = [
    'North America',
    'United States',
    'Canada',
    'Permian Basin',
    'WCSB (Alberta / SK / BC)',
    'Bakken',
    'Eagle Ford & Haynesville',
    'Gulf Coast',
    'Appalachia / Marcellus',
    'Middle East / GCC',
    'Latin America',
    'Global',
  ];

  static PartnerBrandCategoryOption? categoryByCode(String code) {
    for (final category in brandCategories) {
      if (category.code == code) return category;
    }
    return null;
  }

  static PartnerProgramPillar? pillarByCode(String code) {
    for (final pillar in programPillars) {
      if (pillar.code == code) return pillar;
    }
    return null;
  }

  /// Representative showcase programs displayed alongside live Firestore-backed
  /// partner deals so corporate prospective partners and buyers can immediately
  /// preview OEM fleet, crew truck, product merchandising, and oilfield deal formats.
  static const List<PartnerShowcaseDeal> defaultShowcaseDeals = [
    PartnerShowcaseDeal(
      showcaseId: 'oem-crew-truck-fleet-program',
      partnerName: 'Commercial OEM & Fleet Truck Program',
      brandCategory: 'oem_fleet_crew_trucks',
      programTypes: [
        'promote_brand',
        'showcase_sell_products',
        'oilfield_deals_discounts',
      ],
      headline:
          'New 4x4 Crew Trucks, Super Duty Chassis Cabs & Oilfield Upfits',
      summary:
          'Explore factory fleet allocations for F-250 / F-350 / F-550 class crew trucks, mechanic crane bodies, and pipeline welding rigs built for lease-road duty.',
      offerBadge: 'OEM Fleet & Upfit Showcase',
      discountDetails:
          'Commercial Fleet Volume Allowances & Oilfield Upfit Incentives Available',
      productHighlights: [
        '4x4 Diesel Crew Cab',
        'Service & Crane Upfits',
        'Multi-Unit Fleet Pricing',
      ],
      targetRegions: [
        'North America',
        'Permian Basin',
        'WCSB (Alberta / SK / BC)'
      ],
      ctaLabel: 'Inquire on Fleet Allocation',
      featured: true,
      priorityRank: 1,
      isProgramPreview: true,
    ),
    PartnerShowcaseDeal(
      showcaseId: 'oilfield-diesel-fleet-discounts',
      partnerName: 'Basin Commercial Fuel & Tire Network',
      brandCategory: 'oilfield_deals_discounts',
      programTypes: ['oilfield_deals_discounts', 'promote_brand'],
      headline:
          'Oilfield Crew Diesel Rebates & Heavy-Duty Mud/All-Terrain Tires',
      summary:
          'Commercial cardlock fuel savings, roadside heavy truck support, and national account pricing on 10-ply LT and 22.5" commercial truck tires.',
      offerBadge: 'Oilfield Crew Deal',
      discountDetails:
          'Fleet Per-Gallon Rebates + National Tire Account Pricing',
      productHighlights: [
        'Cardlock & Truck Stop Access',
        '10-Ply Crew Truck Tires',
        'Consolidated Basin Billing',
      ],
      targetRegions: ['United States', 'Canada', 'Permian Basin'],
      ctaLabel: 'Request Crew Discount Terms',
      featured: true,
      priorityRank: 2,
      isProgramPreview: true,
    ),
    PartnerShowcaseDeal(
      showcaseId: 'rig-safety-fr-ppe-bundle',
      partnerName: 'Industrial FR Workwear & Gas Detection',
      brandCategory: 'tools_ppe_site_gear',
      programTypes: ['showcase_sell_products', 'oilfield_deals_discounts'],
      headline: 'Crew Outfitting: NFPA 2112 FR Garments & 4-Gas H2S Monitors',
      summary:
          'Outfit drilling, completions, and pipeline crews directly with compliant FR coveralls, winter parkas, impact gloves, and calibrated multi-gas detectors.',
      offerBadge: 'Direct Crew Bundle',
      discountDetails:
          'Volume Crew Outfitting & Corporate Safety Account Rates',
      productHighlights: [
        'NFPA 2112 / CGSB 155.20 FR',
        '4-Gas H2S Monitors',
        'Logo Embroidery Ready',
      ],
      targetRegions: ['North America', 'Global'],
      ctaLabel: 'Request Crew Bundle Quote',
      featured: false,
      priorityRank: 3,
      isProgramPreview: true,
    ),
    PartnerShowcaseDeal(
      showcaseId: 'wellsite-modular-command-skids',
      partnerName: 'Modular Wellsite Offices & Workforce Skids',
      brandCategory: 'modular_site_buildings',
      programTypes: ['showcase_sell_products', 'advertise_campaigns'],
      headline:
          'All-Season Wheeled & Skidded Crew Offices, Dry Shacks & Guard Booths',
      summary:
          'Factory-direct modular offices, mud labs, and artic-insulated crew quarters ready for rapid mobilization across active drilling corridors.',
      offerBadge: 'Product Showcase',
      discountDetails:
          'Direct Factory Purchase & Seasonal Fleet Lease Packages',
      productHighlights: [
        'Arctic & Desert Rated',
        'Plug-and-Play Generator Prep',
        'Fast Basin Delivery',
      ],
      targetRegions: ['WCSB (Alberta / SK / BC)', 'Permian Basin', 'Bakken'],
      ctaLabel: 'Request Spec Sheet & Pricing',
      featured: false,
      priorityRank: 4,
      isProgramPreview: true,
    ),
  ];
}
