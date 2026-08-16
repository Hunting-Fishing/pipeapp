enum DispatchServiceCategoryCode {
  transportation,
  pilotOversizeSupport,
  craneLifting,
  industrialFieldServices,
}

enum DispatchCapabilityValueType {
  boolean,
  number,
  singleChoice,
  multiChoice,
  shortText,
}

enum DispatchCapabilityUnit {
  kilogram,
  pound,
  metricTonne,
  usTon,
  metre,
  foot,
  kilometre,
  mile,
  litre,
  usGallon,
  hour,
}

class DispatchServiceCategoryDefinition {
  const DispatchServiceCategoryDefinition({
    required this.code,
    required this.label,
    required this.description,
  });

  final DispatchServiceCategoryCode code;
  final String label;
  final String description;
}

class DispatchCapabilityFieldDefinition {
  const DispatchCapabilityFieldDefinition({
    required this.code,
    required this.label,
    required this.valueType,
    this.canonicalUnit,
    this.acceptedUnits = const <DispatchCapabilityUnit>[],
    this.options = const <String>[],
    this.helpText = '',
  });

  final String code;
  final String label;
  final DispatchCapabilityValueType valueType;
  final DispatchCapabilityUnit? canonicalUnit;
  final List<DispatchCapabilityUnit> acceptedUnits;
  final List<String> options;
  final String helpText;
}

class DispatchServiceDefinition {
  const DispatchServiceDefinition({
    required this.code,
    required this.label,
    required this.category,
    required this.subcategoryCode,
    required this.subcategoryLabel,
    this.capabilityFieldCodes = const <String>[],
    this.legacyLabels = const <String>[],
    this.featuredInDirectory = false,
  });

  final String code;
  final String label;
  final DispatchServiceCategoryCode category;
  final String subcategoryCode;
  final String subcategoryLabel;
  final List<String> capabilityFieldCodes;
  final List<String> legacyLabels;
  final bool featuredInDirectory;
}

abstract final class DispatchServiceTaxonomy {
  static const categories = <DispatchServiceCategoryDefinition>[
    DispatchServiceCategoryDefinition(
      code: DispatchServiceCategoryCode.transportation,
      label: 'Transportation',
      description:
          'Freight, equipment hauling, specialized transport and local or long-distance movement.',
    ),
    DispatchServiceCategoryDefinition(
      code: DispatchServiceCategoryCode.pilotOversizeSupport,
      label: 'Pilot & Oversize Support',
      description:
          'Escort, high-pole, route survey, traffic control and permit-support services.',
    ),
    DispatchServiceCategoryDefinition(
      code: DispatchServiceCategoryCode.craneLifting,
      label: 'Crane & Lifting',
      description:
          'Picker, crane, telehandler, forklift and rigging support for industrial work.',
    ),
    DispatchServiceCategoryDefinition(
      code: DispatchServiceCategoryCode.industrialFieldServices,
      label: 'Oilfield & Industrial Field Services',
      description:
          'Road, site, vacuum, mobile repair, maintenance and field-support services.',
    ),
  ];

  static const capabilityFields = <DispatchCapabilityFieldDefinition>[
    DispatchCapabilityFieldDefinition(
      code: 'availability_24_7',
      label: '24/7 availability',
      valueType: DispatchCapabilityValueType.boolean,
    ),
    DispatchCapabilityFieldDefinition(
      code: 'emergency_callout',
      label: 'Emergency callout',
      valueType: DispatchCapabilityValueType.boolean,
    ),
    DispatchCapabilityFieldDefinition(
      code: 'remote_site_capable',
      label: 'Remote-site capable',
      valueType: DispatchCapabilityValueType.boolean,
    ),
    DispatchCapabilityFieldDefinition(
      code: 'cross_border_capable',
      label: 'Cross-border capable',
      valueType: DispatchCapabilityValueType.boolean,
    ),
    DispatchCapabilityFieldDefinition(
      code: 'dangerous_goods_capable',
      label: 'Dangerous goods / hazmat capable',
      valueType: DispatchCapabilityValueType.boolean,
      helpText:
          'Only select when the required driver, vehicle and documentation qualifications are current.',
    ),
    DispatchCapabilityFieldDefinition(
      code: 'max_payload',
      label: 'Maximum declared payload',
      valueType: DispatchCapabilityValueType.number,
      canonicalUnit: DispatchCapabilityUnit.kilogram,
      acceptedUnits: <DispatchCapabilityUnit>[
        DispatchCapabilityUnit.kilogram,
        DispatchCapabilityUnit.pound,
        DispatchCapabilityUnit.metricTonne,
        DispatchCapabilityUnit.usTon,
      ],
    ),
    DispatchCapabilityFieldDefinition(
      code: 'deck_length',
      label: 'Usable deck length',
      valueType: DispatchCapabilityValueType.number,
      canonicalUnit: DispatchCapabilityUnit.metre,
      acceptedUnits: <DispatchCapabilityUnit>[
        DispatchCapabilityUnit.metre,
        DispatchCapabilityUnit.foot,
      ],
    ),
    DispatchCapabilityFieldDefinition(
      code: 'deck_width',
      label: 'Usable deck width',
      valueType: DispatchCapabilityValueType.number,
      canonicalUnit: DispatchCapabilityUnit.metre,
      acceptedUnits: <DispatchCapabilityUnit>[
        DispatchCapabilityUnit.metre,
        DispatchCapabilityUnit.foot,
      ],
    ),
    DispatchCapabilityFieldDefinition(
      code: 'oversize_capable',
      label: 'Oversize / overweight capable',
      valueType: DispatchCapabilityValueType.boolean,
    ),
    DispatchCapabilityFieldDefinition(
      code: 'axle_configuration',
      label: 'Axle / trailer configuration',
      valueType: DispatchCapabilityValueType.shortText,
    ),
    DispatchCapabilityFieldDefinition(
      code: 'high_pole_capable',
      label: 'High-pole capable',
      valueType: DispatchCapabilityValueType.boolean,
    ),
    DispatchCapabilityFieldDefinition(
      code: 'lead_car_capable',
      label: 'Lead-car capable',
      valueType: DispatchCapabilityValueType.boolean,
    ),
    DispatchCapabilityFieldDefinition(
      code: 'chase_car_capable',
      label: 'Chase-car capable',
      valueType: DispatchCapabilityValueType.boolean,
    ),
    DispatchCapabilityFieldDefinition(
      code: 'route_survey_capable',
      label: 'Route survey capable',
      valueType: DispatchCapabilityValueType.boolean,
    ),
    DispatchCapabilityFieldDefinition(
      code: 'jurisdictions_served',
      label: 'Jurisdictions served',
      valueType: DispatchCapabilityValueType.multiChoice,
      helpText:
          'Store stable jurisdiction codes separately from the public display labels.',
    ),
    DispatchCapabilityFieldDefinition(
      code: 'rated_lift_capacity',
      label: 'Rated lift capacity',
      valueType: DispatchCapabilityValueType.number,
      canonicalUnit: DispatchCapabilityUnit.kilogram,
      acceptedUnits: <DispatchCapabilityUnit>[
        DispatchCapabilityUnit.kilogram,
        DispatchCapabilityUnit.pound,
        DispatchCapabilityUnit.metricTonne,
        DispatchCapabilityUnit.usTon,
      ],
    ),
    DispatchCapabilityFieldDefinition(
      code: 'maximum_reach',
      label: 'Maximum reach',
      valueType: DispatchCapabilityValueType.number,
      canonicalUnit: DispatchCapabilityUnit.metre,
      acceptedUnits: <DispatchCapabilityUnit>[
        DispatchCapabilityUnit.metre,
        DispatchCapabilityUnit.foot,
      ],
    ),
    DispatchCapabilityFieldDefinition(
      code: 'rigging_available',
      label: 'Rigging available',
      valueType: DispatchCapabilityValueType.boolean,
    ),
    DispatchCapabilityFieldDefinition(
      code: 'operator_included',
      label: 'Operator included',
      valueType: DispatchCapabilityValueType.boolean,
    ),
    DispatchCapabilityFieldDefinition(
      code: 'water_capacity',
      label: 'Water capacity',
      valueType: DispatchCapabilityValueType.number,
      canonicalUnit: DispatchCapabilityUnit.litre,
      acceptedUnits: <DispatchCapabilityUnit>[
        DispatchCapabilityUnit.litre,
        DispatchCapabilityUnit.usGallon,
      ],
    ),
    DispatchCapabilityFieldDefinition(
      code: 'vacuum_capacity',
      label: 'Vacuum tank capacity',
      valueType: DispatchCapabilityValueType.number,
      canonicalUnit: DispatchCapabilityUnit.litre,
      acceptedUnits: <DispatchCapabilityUnit>[
        DispatchCapabilityUnit.litre,
        DispatchCapabilityUnit.usGallon,
      ],
    ),
    DispatchCapabilityFieldDefinition(
      code: 'service_radius',
      label: 'Typical service radius',
      valueType: DispatchCapabilityValueType.number,
      canonicalUnit: DispatchCapabilityUnit.kilometre,
      acceptedUnits: <DispatchCapabilityUnit>[
        DispatchCapabilityUnit.kilometre,
        DispatchCapabilityUnit.mile,
      ],
    ),
  ];

  static const services = <DispatchServiceDefinition>[
    DispatchServiceDefinition(
      code: 'transport_flat_deck',
      label: 'Flat Deck',
      category: DispatchServiceCategoryCode.transportation,
      subcategoryCode: 'deck_transport',
      subcategoryLabel: 'Deck Transport',
      legacyLabels: <String>['Flat deck'],
      capabilityFieldCodes: <String>[
        'max_payload',
        'deck_length',
        'deck_width',
        'oversize_capable',
        'cross_border_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'transport_step_deck',
      label: 'Step Deck',
      category: DispatchServiceCategoryCode.transportation,
      subcategoryCode: 'deck_transport',
      subcategoryLabel: 'Deck Transport',
      legacyLabels: <String>['Step deck'],
      capabilityFieldCodes: <String>[
        'max_payload',
        'deck_length',
        'deck_width',
        'oversize_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'transport_lowboy',
      label: 'Lowboy / Lowbed',
      category: DispatchServiceCategoryCode.transportation,
      subcategoryCode: 'heavy_haul',
      subcategoryLabel: 'Heavy Haul',
      legacyLabels: <String>['Lowboy'],
      featuredInDirectory: true,
      capabilityFieldCodes: <String>[
        'max_payload',
        'deck_length',
        'deck_width',
        'axle_configuration',
        'oversize_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'transport_winch_truck',
      label: 'Winch Truck',
      category: DispatchServiceCategoryCode.transportation,
      subcategoryCode: 'specialized_transport',
      subcategoryLabel: 'Specialized Transport',
      legacyLabels: <String>['Winch'],
      capabilityFieldCodes: <String>['max_payload', 'remote_site_capable'],
    ),
    DispatchServiceDefinition(
      code: 'transport_hotshot',
      label: 'Hotshot',
      category: DispatchServiceCategoryCode.transportation,
      subcategoryCode: 'expedited_transport',
      subcategoryLabel: 'Expedited Transport',
      legacyLabels: <String>['Hotshot'],
      featuredInDirectory: true,
      capabilityFieldCodes: <String>[
        'max_payload',
        'service_radius',
        'availability_24_7',
        'cross_border_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'transport_pipe_hauling',
      label: 'Pipe Hauling',
      category: DispatchServiceCategoryCode.transportation,
      subcategoryCode: 'oilfield_transport',
      subcategoryLabel: 'Oilfield Transport',
      legacyLabels: <String>['Pipe hauling'],
      capabilityFieldCodes: <String>[
        'max_payload',
        'deck_length',
        'oversize_capable',
        'remote_site_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'transport_heavy_equipment',
      label: 'Heavy Equipment Hauling',
      category: DispatchServiceCategoryCode.transportation,
      subcategoryCode: 'heavy_haul',
      subcategoryLabel: 'Heavy Haul',
      legacyLabels: <String>['Heavy equipment'],
      capabilityFieldCodes: <String>[
        'max_payload',
        'axle_configuration',
        'oversize_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'transport_general_freight',
      label: 'General Freight',
      category: DispatchServiceCategoryCode.transportation,
      subcategoryCode: 'general_transport',
      subcategoryLabel: 'General Transport',
      legacyLabels: <String>['General freight'],
      capabilityFieldCodes: <String>['max_payload', 'cross_border_capable'],
    ),
    DispatchServiceDefinition(
      code: 'transport_local_haul',
      label: 'Local Haul',
      category: DispatchServiceCategoryCode.transportation,
      subcategoryCode: 'general_transport',
      subcategoryLabel: 'General Transport',
      legacyLabels: <String>['Local haul'],
      capabilityFieldCodes: <String>['max_payload', 'service_radius'],
    ),
    DispatchServiceDefinition(
      code: 'transport_long_distance',
      label: 'Long Distance',
      category: DispatchServiceCategoryCode.transportation,
      subcategoryCode: 'general_transport',
      subcategoryLabel: 'General Transport',
      legacyLabels: <String>['Long distance'],
      capabilityFieldCodes: <String>[
        'max_payload',
        'cross_border_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'transport_oversize_overweight',
      label: 'Oversize / Overweight Transport',
      category: DispatchServiceCategoryCode.transportation,
      subcategoryCode: 'heavy_haul',
      subcategoryLabel: 'Heavy Haul',
      legacyLabels: <String>['Oversize load'],
      capabilityFieldCodes: <String>[
        'max_payload',
        'axle_configuration',
        'oversize_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'transport_dangerous_goods',
      label: 'Dangerous Goods / Hazmat Transport',
      category: DispatchServiceCategoryCode.transportation,
      subcategoryCode: 'specialized_transport',
      subcategoryLabel: 'Specialized Transport',
      legacyLabels: <String>['Hazmat qualified'],
      capabilityFieldCodes: <String>['dangerous_goods_capable'],
    ),
    DispatchServiceDefinition(
      code: 'pilot_escort_vehicle',
      label: 'Pilot / Escort Vehicle',
      category: DispatchServiceCategoryCode.pilotOversizeSupport,
      subcategoryCode: 'escort',
      subcategoryLabel: 'Escort Services',
      legacyLabels: <String>['Pilot / escort'],
      featuredInDirectory: true,
      capabilityFieldCodes: <String>[
        'lead_car_capable',
        'chase_car_capable',
        'high_pole_capable',
        'availability_24_7',
        'jurisdictions_served',
      ],
    ),
    DispatchServiceDefinition(
      code: 'pilot_lead_car',
      label: 'Lead Car',
      category: DispatchServiceCategoryCode.pilotOversizeSupport,
      subcategoryCode: 'escort',
      subcategoryLabel: 'Escort Services',
      capabilityFieldCodes: <String>[
        'lead_car_capable',
        'jurisdictions_served',
      ],
    ),
    DispatchServiceDefinition(
      code: 'pilot_chase_car',
      label: 'Chase Car',
      category: DispatchServiceCategoryCode.pilotOversizeSupport,
      subcategoryCode: 'escort',
      subcategoryLabel: 'Escort Services',
      capabilityFieldCodes: <String>[
        'chase_car_capable',
        'jurisdictions_served',
      ],
    ),
    DispatchServiceDefinition(
      code: 'pilot_high_pole',
      label: 'High-Pole Car',
      category: DispatchServiceCategoryCode.pilotOversizeSupport,
      subcategoryCode: 'escort',
      subcategoryLabel: 'Escort Services',
      capabilityFieldCodes: <String>[
        'high_pole_capable',
        'jurisdictions_served',
      ],
    ),
    DispatchServiceDefinition(
      code: 'pilot_route_survey',
      label: 'Route Survey',
      category: DispatchServiceCategoryCode.pilotOversizeSupport,
      subcategoryCode: 'route_support',
      subcategoryLabel: 'Route Support',
      legacyLabels: <String>['Route survey'],
      capabilityFieldCodes: <String>[
        'route_survey_capable',
        'jurisdictions_served',
      ],
    ),
    DispatchServiceDefinition(
      code: 'pilot_traffic_control',
      label: 'Traffic Control',
      category: DispatchServiceCategoryCode.pilotOversizeSupport,
      subcategoryCode: 'route_support',
      subcategoryLabel: 'Route Support',
      legacyLabels: <String>['Traffic control'],
      capabilityFieldCodes: <String>['jurisdictions_served'],
    ),
    DispatchServiceDefinition(
      code: 'pilot_permit_assistance',
      label: 'Permit Assistance',
      category: DispatchServiceCategoryCode.pilotOversizeSupport,
      subcategoryCode: 'route_support',
      subcategoryLabel: 'Route Support',
      capabilityFieldCodes: <String>['jurisdictions_served'],
    ),
    DispatchServiceDefinition(
      code: 'crane_picker_truck',
      label: 'Picker Truck',
      category: DispatchServiceCategoryCode.craneLifting,
      subcategoryCode: 'mobile_crane',
      subcategoryLabel: 'Mobile Crane & Picker',
      legacyLabels: <String>['Picker / crane'],
      featuredInDirectory: true,
      capabilityFieldCodes: <String>[
        'rated_lift_capacity',
        'maximum_reach',
        'rigging_available',
        'operator_included',
        'remote_site_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'crane_crane_truck',
      label: 'Crane Truck',
      category: DispatchServiceCategoryCode.craneLifting,
      subcategoryCode: 'mobile_crane',
      subcategoryLabel: 'Mobile Crane & Picker',
      capabilityFieldCodes: <String>[
        'rated_lift_capacity',
        'maximum_reach',
        'rigging_available',
        'operator_included',
      ],
    ),
    DispatchServiceDefinition(
      code: 'crane_mobile_crane',
      label: 'Mobile Crane',
      category: DispatchServiceCategoryCode.craneLifting,
      subcategoryCode: 'mobile_crane',
      subcategoryLabel: 'Mobile Crane & Picker',
      capabilityFieldCodes: <String>[
        'rated_lift_capacity',
        'maximum_reach',
        'rigging_available',
        'operator_included',
      ],
    ),
    DispatchServiceDefinition(
      code: 'crane_knuckle_boom',
      label: 'Knuckle Boom',
      category: DispatchServiceCategoryCode.craneLifting,
      subcategoryCode: 'mobile_crane',
      subcategoryLabel: 'Mobile Crane & Picker',
      capabilityFieldCodes: <String>[
        'rated_lift_capacity',
        'maximum_reach',
      ],
    ),
    DispatchServiceDefinition(
      code: 'crane_telehandler',
      label: 'Telehandler',
      category: DispatchServiceCategoryCode.craneLifting,
      subcategoryCode: 'material_handling',
      subcategoryLabel: 'Material Handling',
      capabilityFieldCodes: <String>['rated_lift_capacity', 'maximum_reach'],
    ),
    DispatchServiceDefinition(
      code: 'crane_forklift',
      label: 'Forklift',
      category: DispatchServiceCategoryCode.craneLifting,
      subcategoryCode: 'material_handling',
      subcategoryLabel: 'Material Handling',
      capabilityFieldCodes: <String>['rated_lift_capacity'],
    ),
    DispatchServiceDefinition(
      code: 'crane_rigging',
      label: 'Rigging',
      category: DispatchServiceCategoryCode.craneLifting,
      subcategoryCode: 'rigging',
      subcategoryLabel: 'Rigging',
      capabilityFieldCodes: <String>['rigging_available', 'operator_included'],
    ),
    DispatchServiceDefinition(
      code: 'field_grading',
      label: 'Grading',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'site_road',
      subcategoryLabel: 'Site & Road Work',
      featuredInDirectory: true,
      capabilityFieldCodes: <String>[
        'remote_site_capable',
        'service_radius',
      ],
    ),
    DispatchServiceDefinition(
      code: 'field_road_maintenance',
      label: 'Road Maintenance',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'site_road',
      subcategoryLabel: 'Site & Road Work',
      capabilityFieldCodes: <String>[
        'remote_site_capable',
        'service_radius',
      ],
    ),
    DispatchServiceDefinition(
      code: 'field_snow_removal',
      label: 'Snow Removal',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'site_road',
      subcategoryLabel: 'Site & Road Work',
      capabilityFieldCodes: <String>[
        'availability_24_7',
        'emergency_callout',
        'remote_site_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'field_water_truck',
      label: 'Water Truck',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'fluid_vacuum',
      subcategoryLabel: 'Fluid & Vacuum Services',
      capabilityFieldCodes: <String>[
        'water_capacity',
        'remote_site_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'field_vacuum_truck',
      label: 'Vacuum Truck',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'fluid_vacuum',
      subcategoryLabel: 'Fluid & Vacuum Services',
      capabilityFieldCodes: <String>[
        'vacuum_capacity',
        'remote_site_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'field_hydrovac',
      label: 'Hydrovac',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'fluid_vacuum',
      subcategoryLabel: 'Fluid & Vacuum Services',
      capabilityFieldCodes: <String>[
        'vacuum_capacity',
        'water_capacity',
        'remote_site_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'field_mobile_mechanic',
      label: 'Mobile Mechanic',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'mobile_repair',
      subcategoryLabel: 'Mobile Repair & Maintenance',
      featuredInDirectory: true,
      capabilityFieldCodes: <String>[
        'availability_24_7',
        'emergency_callout',
        'remote_site_capable',
        'service_radius',
      ],
    ),
    DispatchServiceDefinition(
      code: 'field_mobile_welding',
      label: 'Mobile Welding',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'mobile_repair',
      subcategoryLabel: 'Mobile Repair & Maintenance',
      capabilityFieldCodes: <String>[
        'availability_24_7',
        'emergency_callout',
        'remote_site_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'field_tire_service',
      label: 'Mobile Tire Service',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'mobile_repair',
      subcategoryLabel: 'Mobile Repair & Maintenance',
      capabilityFieldCodes: <String>[
        'availability_24_7',
        'emergency_callout',
        'service_radius',
      ],
    ),
    DispatchServiceDefinition(
      code: 'field_fuel_lube',
      label: 'Fuel / Lube Service',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'mobile_repair',
      subcategoryLabel: 'Mobile Repair & Maintenance',
      capabilityFieldCodes: <String>[
        'availability_24_7',
        'remote_site_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'field_towing_recovery',
      label: 'Towing / Recovery',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'mobile_repair',
      subcategoryLabel: 'Mobile Repair & Maintenance',
      legacyLabels: <String>['Towing / recovery'],
      capabilityFieldCodes: <String>[
        'availability_24_7',
        'emergency_callout',
        'remote_site_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'field_equipment_servicing',
      label: 'Equipment Servicing',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'mobile_repair',
      subcategoryLabel: 'Mobile Repair & Maintenance',
      capabilityFieldCodes: <String>[
        'remote_site_capable',
        'service_radius',
      ],
    ),
    DispatchServiceDefinition(
      code: 'field_labour',
      label: 'Field Labour',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'site_support',
      subcategoryLabel: 'Site Support',
      capabilityFieldCodes: <String>[
        'availability_24_7',
        'remote_site_capable',
      ],
    ),
    DispatchServiceDefinition(
      code: 'field_site_support',
      label: 'Site Support',
      category: DispatchServiceCategoryCode.industrialFieldServices,
      subcategoryCode: 'site_support',
      subcategoryLabel: 'Site Support',
      legacyLabels: <String>['Oilfield service'],
      capabilityFieldCodes: <String>[
        'availability_24_7',
        'remote_site_capable',
      ],
    ),
  ];

  static List<DispatchServiceDefinition> servicesForCategory(
    DispatchServiceCategoryCode category,
  ) => services.where((service) => service.category == category).toList();

  static List<DispatchServiceDefinition> get featuredDirectoryServices =>
      services.where((service) => service.featuredInDirectory).toList();

  static DispatchServiceDefinition? findByCode(String code) {
    for (final service in services) {
      if (service.code == code) return service;
    }
    return null;
  }

  static DispatchCapabilityFieldDefinition? capabilityByCode(String code) {
    for (final field in capabilityFields) {
      if (field.code == code) return field;
    }
    return null;
  }

  static DispatchServiceDefinition? fromLegacyLabel(String label) {
    final normalized = label.trim().toLowerCase();
    for (final service in services) {
      if (service.label.toLowerCase() == normalized ||
          service.legacyLabels.any(
            (legacy) => legacy.toLowerCase() == normalized,
          )) {
        return service;
      }
    }
    return null;
  }

  static List<DispatchCapabilityFieldDefinition> capabilitiesForService(
    String serviceCode,
  ) {
    final service = findByCode(serviceCode);
    if (service == null) return const <DispatchCapabilityFieldDefinition>[];
    return service.capabilityFieldCodes
        .map(capabilityByCode)
        .whereType<DispatchCapabilityFieldDefinition>()
        .toList();
  }
}
