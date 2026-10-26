import 'package:flutter/material.dart';

@immutable
class InsuranceCoverageLine {
  const InsuranceCoverageLine({
    required this.code,
    required this.label,
    required this.shortLabel,
    required this.description,
    required this.icon,
  });

  final String code;
  final String label;
  final String shortLabel;
  final String description;
  final IconData icon;
}

@immutable
class InsuranceMsaEndorsement {
  const InsuranceMsaEndorsement({
    required this.code,
    required this.label,
    required this.description,
  });

  final String code;
  final String label;
  final String description;
}

@immutable
class InsuranceBandOption {
  const InsuranceBandOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

@immutable
class InsuranceProviderListing {
  const InsuranceProviderListing({
    required this.providerId,
    required this.companyName,
    required this.providerType,
    this.publicEmail = '',
    this.publicPhone = '',
    this.website = '',
    this.countryCode = 'US',
    this.regionCode = '',
    this.headquartersCity = '',
    this.licensedCountries = const <String>['US'],
    this.licensedRegions = const <String>[],
    this.operatingBasins = const <String>[],
    this.coverageLines = const <String>[],
    this.coverageLabels = const <String>[],
    this.msaCapabilities = const <String>[],
    this.licenseSummary = '',
    this.amBestRating = '',
    this.maxLimitUsd = 0,
    this.minimumPremiumUsd = 0,
    this.fastCoi24x7 = false,
    this.msaCompliant = false,
    this.featured = false,
    this.verified = true,
    this.active = true,
    this.summary = '',
    this.highlights = const <String>[],
    this.priorityScore = 100,
    this.isSampleShowcase = false,
  });

  final String providerId;
  final String companyName;
  final String providerType;
  final String publicEmail;
  final String publicPhone;
  final String website;
  final String countryCode;
  final String regionCode;
  final String headquartersCity;
  final List<String> licensedCountries;
  final List<String> licensedRegions;
  final List<String> operatingBasins;
  final List<String> coverageLines;
  final List<String> coverageLabels;
  final List<String> msaCapabilities;
  final String licenseSummary;
  final String amBestRating;
  final double maxLimitUsd;
  final double minimumPremiumUsd;
  final bool fastCoi24x7;
  final bool msaCompliant;
  final bool featured;
  final bool verified;
  final bool active;
  final String summary;
  final List<String> highlights;
  final int priorityScore;
  final bool isSampleShowcase;

  String get providerTypeLabel => switch (providerType) {
        'carrier' => 'Commercial Carrier',
        'mga' => 'Managing General Agent (MGA)',
        'specialty_broker' => 'Oil & Gas Specialty Broker',
        _ => 'Insurance Provider',
      };

  String get providerTypeBadge => switch (providerType) {
        'carrier' => 'DIRECT CARRIER',
        'mga' => 'SPECIALTY MGA',
        'specialty_broker' => 'OILFIELD BROKER',
        _ => 'PROVIDER',
      };

  String get headquartersLabel {
    final parts = <String>[
      if (headquartersCity.trim().isNotEmpty) headquartersCity.trim(),
      if (regionCode.trim().isNotEmpty) regionCode.trim(),
      if (countryCode.trim().isNotEmpty) countryCode.trim(),
    ];
    return parts.isEmpty ? 'North America' : parts.join(', ');
  }

  String get formattedMaxLimit =>
      PipeBuyerInsuranceTaxonomy.formatCompactUsd(maxLimitUsd);

  String get formattedMinPremium => minimumPremiumUsd <= 0
      ? 'Flexible'
      : PipeBuyerInsuranceTaxonomy.formatCompactUsd(minimumPremiumUsd);

  List<String> get resolvedCoverageLabels {
    if (coverageLabels.isNotEmpty) return coverageLabels;
    return coverageLines
        .map(PipeBuyerInsuranceTaxonomy.coverageShortLabel)
        .toList(growable: false);
  }

  bool matchesFilters({
    String query = '',
    String coverageLine = '',
    String countryFilter = '',
    String regionFilter = '',
    String providerTypeFilter = '',
    bool msaOnly = false,
    bool fastCoiOnly = false,
  }) {
    if (!active) return false;
    if (coverageLine.isNotEmpty && !coverageLines.contains(coverageLine)) {
      return false;
    }
    if (countryFilter.isNotEmpty) {
      final upper = countryFilter.toUpperCase();
      final matchesCountry = countryCode.toUpperCase() == upper ||
          licensedCountries.any((c) => c.toUpperCase() == upper);
      if (!matchesCountry) return false;
    }
    if (regionFilter.isNotEmpty) {
      final upper = regionFilter.toUpperCase();
      final matchesRegion = regionCode.toUpperCase() == upper ||
          licensedRegions.any((r) => r.toUpperCase() == upper);
      if (!matchesRegion) return false;
    }
    if (providerTypeFilter.isNotEmpty &&
        providerType.toLowerCase() != providerTypeFilter.toLowerCase()) {
      return false;
    }
    if (msaOnly && !msaCompliant) return false;
    if (fastCoiOnly && !fastCoi24x7) return false;

    final trimmedQuery = query.trim().toLowerCase();
    if (trimmedQuery.isNotEmpty) {
      final haystack = <String>[
        companyName,
        providerTypeLabel,
        headquartersCity,
        regionCode,
        countryCode,
        amBestRating,
        summary,
        licenseSummary,
        ...licensedCountries,
        ...licensedRegions,
        ...operatingBasins,
        ...coverageLines,
        ...resolvedCoverageLabels,
        ...highlights,
      ].join(' ').toLowerCase();
      final words =
          trimmedQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      if (!words.every(haystack.contains)) {
        return false;
      }
    }
    return true;
  }

  factory InsuranceProviderListing.fromJson(
    Map<String, dynamic> json, {
    bool isSampleShowcase = false,
  }) {
    List<String> readStrings(Object? raw) {
      if (raw is! List) return const <String>[];
      return raw
          .map((item) => '${item ?? ''}'.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final id = '${json['providerId'] ?? json['id'] ?? ''}'.trim();
    return InsuranceProviderListing(
      providerId: id,
      companyName: '${json['companyName'] ?? ''}'.trim(),
      providerType: '${json['providerType'] ?? 'specialty_broker'}'.trim(),
      publicEmail: '${json['publicEmail'] ?? json['email'] ?? ''}'.trim(),
      publicPhone: '${json['publicPhone'] ?? json['phone'] ?? ''}'.trim(),
      website: '${json['website'] ?? ''}'.trim(),
      countryCode: '${json['countryCode'] ?? 'US'}'.trim().toUpperCase(),
      regionCode: '${json['regionCode'] ?? ''}'.trim().toUpperCase(),
      headquartersCity:
          '${json['headquartersCity'] ?? json['city'] ?? ''}'.trim(),
      licensedCountries: readStrings(json['licensedCountries']),
      licensedRegions: readStrings(json['licensedRegions']),
      operatingBasins: readStrings(json['operatingBasins']),
      coverageLines: readStrings(json['coverageLines']),
      coverageLabels: readStrings(json['coverageLabels']),
      msaCapabilities: readStrings(json['msaCapabilities']),
      licenseSummary: '${json['licenseSummary'] ?? ''}'.trim(),
      amBestRating: '${json['amBestRating'] ?? ''}'.trim(),
      maxLimitUsd: (json['maxLimitUsd'] as num?)?.toDouble() ?? 0,
      minimumPremiumUsd: (json['minimumPremiumUsd'] as num?)?.toDouble() ?? 0,
      fastCoi24x7: json['fastCoi24x7'] == true,
      msaCompliant: json['msaCompliant'] == true,
      featured: json['featured'] == true,
      verified: json['verified'] != false,
      active: json['active'] != false,
      summary: '${json['summary'] ?? ''}'.trim(),
      highlights: readStrings(json['highlights']),
      priorityScore: (json['priorityScore'] as num?)?.toInt() ?? 100,
      isSampleShowcase: isSampleShowcase || json['isSampleShowcase'] == true,
    );
  }
}

@immutable
class InsuranceRateApplicationSummary {
  const InsuranceRateApplicationSummary({
    required this.applicationId,
    required this.companyName,
    required this.contactName,
    required this.email,
    required this.phone,
    required this.countryCode,
    required this.regionCode,
    required this.city,
    required this.coverageLines,
    required this.status,
    this.operatingBasins = const <String>[],
    this.msaRequirements = const <String>[],
    this.fleetVehicleCount = 0,
    this.equipmentValueUsd = 0,
    this.annualRevenueBand = '500k_2m',
    this.dotOrMcNumber = '',
    this.desiredEffectiveDate = '',
    this.claimsSummary = '',
    this.targetProviderId,
    this.targetProviderName = '',
    this.distributionMode = 'multi_carrier',
    this.matchedProviderNames = const <String>[],
    this.brokerResponseNotes = '',
    this.notes = '',
    this.createdAt = '',
  });

  final String applicationId;
  final String companyName;
  final String contactName;
  final String email;
  final String phone;
  final String countryCode;
  final String regionCode;
  final String city;
  final List<String> operatingBasins;
  final List<String> coverageLines;
  final List<String> msaRequirements;
  final int fleetVehicleCount;
  final double equipmentValueUsd;
  final String annualRevenueBand;
  final String dotOrMcNumber;
  final String desiredEffectiveDate;
  final String claimsSummary;
  final String? targetProviderId;
  final String targetProviderName;
  final String distributionMode;
  final String status;
  final List<String> matchedProviderNames;
  final String brokerResponseNotes;
  final String notes;
  final String createdAt;

  bool get isTargeted =>
      targetProviderId != null && targetProviderId!.trim().isNotEmpty;

  String get statusLabel => switch (status.toLowerCase()) {
        'new' => 'NEW SUBMISSION',
        'matching' => 'CARRIER MATCHING',
        'quoted' => 'RATES QUOTED',
        'bound' => 'COVERAGE BOUND',
        'closed' => 'CLOSED',
        _ => status.toUpperCase(),
      };

  factory InsuranceRateApplicationSummary.fromJson(Map<String, dynamic> json) {
    List<String> readStrings(Object? raw) {
      if (raw is! List) return const <String>[];
      return raw
          .map((item) => '${item ?? ''}'.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final rawTarget = '${json['targetProviderId'] ?? ''}'.trim();
    return InsuranceRateApplicationSummary(
      applicationId: '${json['applicationId'] ?? json['id'] ?? ''}'.trim(),
      companyName: '${json['companyName'] ?? ''}'.trim(),
      contactName: '${json['contactName'] ?? ''}'.trim(),
      email: '${json['email'] ?? ''}'.trim(),
      phone: '${json['phone'] ?? ''}'.trim(),
      countryCode: '${json['countryCode'] ?? 'US'}'.trim(),
      regionCode: '${json['regionCode'] ?? ''}'.trim(),
      city: '${json['city'] ?? ''}'.trim(),
      operatingBasins: readStrings(json['operatingBasins']),
      coverageLines: readStrings(json['coverageLines']),
      msaRequirements: readStrings(json['msaRequirements']),
      fleetVehicleCount: (json['fleetVehicleCount'] as num?)?.toInt() ?? 0,
      equipmentValueUsd: (json['equipmentValueUsd'] as num?)?.toDouble() ?? 0,
      annualRevenueBand: '${json['annualRevenueBand'] ?? '500k_2m'}'.trim(),
      dotOrMcNumber: '${json['dotOrMcNumber'] ?? ''}'.trim(),
      desiredEffectiveDate: '${json['desiredEffectiveDate'] ?? ''}'.trim(),
      claimsSummary: '${json['claimsSummary'] ?? ''}'.trim(),
      targetProviderId: rawTarget.isEmpty ? null : rawTarget,
      targetProviderName: '${json['targetProviderName'] ?? ''}'.trim(),
      distributionMode: '${json['distributionMode'] ?? 'multi_carrier'}'.trim(),
      status: '${json['status'] ?? 'new'}'.trim(),
      matchedProviderNames: readStrings(json['matchedProviderNames']),
      brokerResponseNotes: '${json['brokerResponseNotes'] ?? ''}'.trim(),
      notes: '${json['notes'] ?? ''}'.trim(),
      createdAt: '${json['createdAt'] ?? ''}'.trim(),
    );
  }
}

abstract final class PipeBuyerInsuranceTaxonomy {
  static const coverageLines = <InsuranceCoverageLine>[
    InsuranceCoverageLine(
      code: 'commercial_auto_fleet',
      label: 'Commercial Auto & Crew Truck Fleet',
      shortLabel: 'Commercial Auto & Fleet',
      description:
          'Primary auto liability, physical damage, MCS-90, and DOT/NSC filings for crew pickups, hotshots, vacuum trucks, and heavy haul tractors.',
      icon: Icons.local_shipping_outlined,
    ),
    InsuranceCoverageLine(
      code: 'oilfield_general_liability',
      label: 'Oilfield General Liability & MSA',
      shortLabel: 'General Liability & MSA',
      description:
          'Occurrence CGL structured for lease sites, upstream/midstream contractors, and Tier-1 E&P Master Service Agreements.',
      icon: Icons.shield_outlined,
    ),
    InsuranceCoverageLine(
      code: 'rig_equipment_inland_marine',
      label: 'Rig / Heavy Equipment & Inland Marine',
      shortLabel: 'Rig & Heavy Equipment',
      description:
          'Scheduled and blanket contractors equipment, drilling/workover rigs, yellow iron, pipe inventory, and mobile tools.',
      icon: Icons.precision_manufacturing_outlined,
    ),
    InsuranceCoverageLine(
      code: 'motor_truck_cargo_hazmat',
      label: 'Motor Truck Cargo & Hazmat',
      shortLabel: 'Cargo & Hazmat',
      description:
          'Broad-form OCTG pipe cargo, rig moves, fluid transit, loading/unloading, and hazmat cleanup extensions.',
      icon: Icons.inventory_2_outlined,
    ),
    InsuranceCoverageLine(
      code: 'pollution_environmental',
      label: 'Pollution & Environmental Liability',
      shortLabel: 'Pollution & Environmental',
      description:
          'Contractors pollution liability (CPL), site environmental coverage, sudden & accidental time-element, and fluid spill remediation.',
      icon: Icons.eco_outlined,
    ),
    InsuranceCoverageLine(
      code: 'umbrella_excess_liability',
      label: 'Umbrella / Excess Liability',
      shortLabel: 'Umbrella / Excess',
      description:
          'Follow-form excess liability towers from \$1M to \$25M+ satisfying operator and midstream pipeline MSA schedules.',
      icon: Icons.layers_outlined,
    ),
    InsuranceCoverageLine(
      code: 'workers_comp_crew',
      label: "Workers' Compensation & Crew Coverage",
      shortLabel: "Workers' Comp & Crew",
      description:
          "Statutory workers' compensation, employer's liability, stop-gap, USL&H offshore extensions, and WCB coordination.",
      icon: Icons.groups_outlined,
    ),
    InsuranceCoverageLine(
      code: 'commercial_property_yards',
      label: 'Commercial Property / Yards & Modulars',
      shortLabel: 'Property, Yards & Modulars',
      description:
          'Fabrication shops, pipe storage yards, skid offices, crew camps, modular buildings, and business interruption.',
      icon: Icons.warehouse_outlined,
    ),
  ];

  static const msaEndorsements = <InsuranceMsaEndorsement>[
    InsuranceMsaEndorsement(
      code: 'waiver_of_subrogation',
      label: 'Waiver of Subrogation',
      description: 'Blanket waiver across GL, Commercial Auto & Workers Comp.',
    ),
    InsuranceMsaEndorsement(
      code: 'additional_insured',
      label: 'Additional Insured (Ongoing & Completed Ops)',
      description: 'Blanket AI matching ISO CG 20 10 & CG 20 37 operator specs.',
    ),
    InsuranceMsaEndorsement(
      code: 'primary_non_contributory',
      label: 'Primary & Non-Contributory',
      description: 'Primary and non-contributory wording for operator MSAs.',
    ),
    InsuranceMsaEndorsement(
      code: 'thirty_day_cancellation_notice',
      label: '30-Day Notice of Cancellation',
      description: '30-day advance written notice to certificate holders.',
    ),
    InsuranceMsaEndorsement(
      code: 'hired_non_owned_auto',
      label: 'Hired & Non-Owned Auto',
      description: 'Hired and non-owned commercial auto liability extension.',
    ),
    InsuranceMsaEndorsement(
      code: 'sudden_accidental_pollution',
      label: 'Sudden & Accidental Pollution',
      description: 'Time-element sudden and accidental oilfield pollution buyback.',
    ),
  ];

  static const annualRevenueBands = <InsuranceBandOption>[
    InsuranceBandOption(code: 'under_500k', label: 'Under \$500K'),
    InsuranceBandOption(code: '500k_2m', label: '\$500K – \$2M'),
    InsuranceBandOption(code: '2m_10m', label: '\$2M – \$10M'),
    InsuranceBandOption(code: '10m_50m', label: '\$10M – \$50M'),
    InsuranceBandOption(code: '50m_plus', label: '\$50M+'),
  ];

  static const fleetSizeBands = <InsuranceBandOption>[
    InsuranceBandOption(
      code: 'no_fleet',
      label: '0 Vehicles (Equipment / GL Only)',
    ),
    InsuranceBandOption(code: '1_5_units', label: '1 – 5 Vehicles'),
    InsuranceBandOption(code: '6_25_units', label: '6 – 25 Vehicles'),
    InsuranceBandOption(code: '26_100_units', label: '26 – 100 Vehicles'),
    InsuranceBandOption(code: '100_plus_units', label: '100+ Vehicles'),
  ];

  static const providerTypes = <InsuranceBandOption>[
    InsuranceBandOption(code: 'carrier', label: 'Commercial Carrier'),
    InsuranceBandOption(
      code: 'mga',
      label: 'Managing General Agent (MGA)',
    ),
    InsuranceBandOption(
      code: 'specialty_broker',
      label: 'Oil & Gas Specialty Broker',
    ),
  ];

  static const operatingBasins = <String>[
    'Permian Basin',
    'WCSB (Alberta / BC / SK)',
    'Eagle Ford',
    'Williston / Bakken',
    'DJ / Niobrara',
    'Haynesville',
    'Anadarko / SCOOP-STACK',
    'Appalachian / Marcellus',
    'Gulf Coast & Offshore',
  ];

  static const popularRegions = <String>[
    'TX',
    'AB',
    'ND',
    'OK',
    'NM',
    'LA',
    'SK',
    'BC',
    'WY',
    'CO',
    'PA',
    'OH',
  ];

  static const rateStatuses = <String>[
    'new',
    'matching',
    'quoted',
    'bound',
    'closed',
  ];

  static InsuranceCoverageLine? lineByCode(String code) {
    final normalized = code.trim().toLowerCase();
    for (final line in coverageLines) {
      if (line.code == normalized) return line;
    }
    return null;
  }

  static String coverageLabel(String code) =>
      lineByCode(code)?.label ?? code;

  static String coverageShortLabel(String code) =>
      lineByCode(code)?.shortLabel ?? code;

  static String msaLabel(String code) {
    final normalized = code.trim().toLowerCase();
    for (final item in msaEndorsements) {
      if (item.code == normalized) return item.label;
    }
    return code;
  }

  static String revenueBandLabel(String code) {
    for (final item in annualRevenueBands) {
      if (item.code == code) return item.label;
    }
    return code;
  }

  static String formatCompactUsd(double amount) {
    if (amount <= 0) return 'Custom';
    if (amount >= 1000000) {
      final millions = amount / 1000000;
      final formatted = millions == millions.roundToDouble()
          ? millions.toInt().toString()
          : millions.toStringAsFixed(1);
      return '\$${formatted}M';
    }
    if (amount >= 1000) {
      final thousands = (amount / 1000).round();
      return '\$${thousands}K';
    }
    return '\$${amount.round()}';
  }

  /// Curated showcase providers displayed when a local/preview environment has
  /// not yet seeded `insurance_public_providers`.
  static const showcaseProviders = <InsuranceProviderListing>[
    InsuranceProviderListing(
      providerId: 'showcase_permian_energy_underwriters',
      companyName: 'Permian Energy & Fleet Underwriters',
      providerType: 'mga',
      publicEmail: 'submissions@permianunderwriters.example.com',
      publicPhone: '(432) 555-0180',
      website: 'https://permianunderwriters.example.com',
      countryCode: 'US',
      regionCode: 'TX',
      headquartersCity: 'Midland',
      licensedCountries: <String>['US'],
      licensedRegions: <String>['TX', 'NM', 'OK', 'LA', 'ND', 'WY', 'CO'],
      operatingBasins: <String>[
        'Permian Basin',
        'Eagle Ford',
        'Haynesville',
        'Anadarko / SCOOP-STACK',
      ],
      coverageLines: <String>[
        'commercial_auto_fleet',
        'oilfield_general_liability',
        'motor_truck_cargo_hazmat',
        'umbrella_excess_liability',
      ],
      msaCapabilities: <String>[
        'waiver_of_subrogation',
        'additional_insured',
        'primary_non_contributory',
        'thirty_day_cancellation_notice',
        'hired_non_owned_auto',
      ],
      licenseSummary: 'Texas TDI MGA #419082 • Multi-State Surplus & Admitted Binding',
      amBestRating: 'A+ (Superior)',
      maxLimitUsd: 25000000,
      minimumPremiumUsd: 8500,
      fastCoi24x7: true,
      msaCompliant: true,
      featured: true,
      summary:
          'Dedicated upstream & midstream oilfield hauling, OCTG cargo, and MSA excess facility with instant ISNetworld / Veriforce COI issuance.',
      highlights: <String>[
        'Same-day ISNetworld & PEC/Veriforce COI',
        'Hotshot, winch truck, vac & pipe haul fleets',
        'Up to \$25M follow-form MSA excess tower',
      ],
      priorityScore: 260,
      isSampleShowcase: true,
    ),
    InsuranceProviderListing(
      providerId: 'showcase_foothills_wcsb_specialty',
      companyName: 'Foothills WCSB Energy Risk Partners',
      providerType: 'specialty_broker',
      publicEmail: 'oilfield@foothillsrisk.example.ca',
      publicPhone: '(403) 555-0142',
      website: 'https://foothillsrisk.example.ca',
      countryCode: 'CA',
      regionCode: 'AB',
      headquartersCity: 'Calgary',
      licensedCountries: <String>['CA', 'US'],
      licensedRegions: <String>['AB', 'SK', 'BC', 'MB', 'ND', 'MT'],
      operatingBasins: <String>[
        'WCSB (Alberta / BC / SK)',
        'Williston / Bakken',
      ],
      coverageLines: <String>[
        'oilfield_general_liability',
        'rig_equipment_inland_marine',
        'commercial_auto_fleet',
        'pollution_environmental',
        'commercial_property_yards',
      ],
      msaCapabilities: <String>[
        'waiver_of_subrogation',
        'additional_insured',
        'primary_non_contributory',
        'thirty_day_cancellation_notice',
        'sudden_accidental_pollution',
      ],
      licenseSummary: 'Alberta AIC #77410 • SK RIBO • BC FinSA Cross-Border Energy Desk',
      amBestRating: 'A (Excellent) Markets',
      maxLimitUsd: 20000000,
      minimumPremiumUsd: 5000,
      fastCoi24x7: true,
      msaCompliant: true,
      featured: true,
      summary:
          'Cross-border Canadian & Bakken energy brokerage specializing in drilling rigs, pipe yards, ComplyWorks MSAs, and winter lease fleets.',
      highlights: <String>[
        'ComplyWorks & Avetta MSA compliance desk',
        'Cross-border CA/US fleet & cargo filings',
        'Scheduled rig, yellow iron & pipe yard stock',
      ],
      priorityScore: 255,
      isSampleShowcase: true,
    ),
    InsuranceProviderListing(
      providerId: 'showcase_ironclad_industrial_casualty',
      companyName: 'Ironclad Industrial & Rig Casualty Co.',
      providerType: 'carrier',
      publicEmail: 'energy.desk@ironcladcasualty.example.com',
      publicPhone: '(713) 555-0199',
      website: 'https://ironcladcasualty.example.com',
      countryCode: 'US',
      regionCode: 'TX',
      headquartersCity: 'Houston',
      licensedCountries: <String>['US'],
      licensedRegions: <String>[
        'TX',
        'LA',
        'OK',
        'NM',
        'ND',
        'PA',
        'OH',
        'WY',
      ],
      operatingBasins: <String>[
        'Permian Basin',
        'Gulf Coast & Offshore',
        'Appalachian / Marcellus',
      ],
      coverageLines: <String>[
        'rig_equipment_inland_marine',
        'oilfield_general_liability',
        'pollution_environmental',
        'umbrella_excess_liability',
        'workers_comp_crew',
      ],
      msaCapabilities: <String>[
        'waiver_of_subrogation',
        'additional_insured',
        'primary_non_contributory',
        'thirty_day_cancellation_notice',
        'sudden_accidental_pollution',
      ],
      licenseSummary: 'Admitted & E&S Carrier Group • NAIC #30994 (48 US States)',
      amBestRating: 'A+ (Superior)',
      maxLimitUsd: 50000000,
      minimumPremiumUsd: 15000,
      fastCoi24x7: false,
      msaCompliant: true,
      featured: false,
      summary:
          'Direct commercial carrier writing heavy contractors equipment, workover rigs, CPL environmental liability, and \$50M energy umbrella programs.',
      highlights: <String>[
        'In-house oilfield loss control engineers',
        'Blanket inland marine & downhole tool floaters',
        'USL&H & statutory crew workers compensation',
      ],
      priorityScore: 185,
      isSampleShowcase: true,
    ),
    InsuranceProviderListing(
      providerId: 'showcase_bakken_plains_fleet_brokers',
      companyName: 'High Plains Fleet & Cargo Insurance Group',
      providerType: 'specialty_broker',
      publicEmail: 'quotes@highplainsfleet.example.com',
      publicPhone: '(701) 555-0164',
      website: 'https://highplainsfleet.example.com',
      countryCode: 'US',
      regionCode: 'ND',
      headquartersCity: 'Williston',
      licensedCountries: <String>['US'],
      licensedRegions: <String>['ND', 'MT', 'WY', 'CO', 'SD', 'TX', 'OK'],
      operatingBasins: <String>[
        'Williston / Bakken',
        'DJ / Niobrara',
        'Anadarko / SCOOP-STACK',
      ],
      coverageLines: <String>[
        'commercial_auto_fleet',
        'motor_truck_cargo_hazmat',
        'workers_comp_crew',
        'commercial_property_yards',
      ],
      msaCapabilities: <String>[
        'waiver_of_subrogation',
        'additional_insured',
        'hired_non_owned_auto',
      ],
      licenseSummary: 'ND Insurance Producer #208841 • FMCSA BMC-91X Filing Desk',
      amBestRating: 'A- (Excellent) Panel',
      maxLimitUsd: 10000000,
      minimumPremiumUsd: 3500,
      fastCoi24x7: true,
      msaCompliant: true,
      featured: false,
      summary:
          'Fast-turnaround commercial trucking, owner-operator hotshot, pipe bunk flatbed cargo, and modular yard coverage with 24/7 digital COI portal.',
      highlights: <String>[
        'Instant FMCSA / DOT federal filings',
        '1-to-100+ unit commercial fleet programs',
        '24/7 automated certificate of insurance portal',
      ],
      priorityScore: 175,
      isSampleShowcase: true,
    ),
  ];
}
