import 'package:flutter/material.dart';

@immutable
class YellowPagesCategoryItem {
  const YellowPagesCategoryItem({
    required this.code,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.sampleServices,
  });

  final String code;
  final String label;
  final String shortLabel;
  final IconData icon;
  final List<String> sampleServices;
}

@immutable
class YellowPagesRegionOption {
  const YellowPagesRegionOption({
    required this.countryCode,
    required this.regionCode,
    required this.name,
  });

  final String countryCode;
  final String regionCode;
  final String name;

  String get displayLabel => '$name ($regionCode)';
}

abstract final class PipeBuyerYellowPagesTaxonomy {
  static const categories = <YellowPagesCategoryItem>[
    YellowPagesCategoryItem(
      code: 'trucking_heavy_haul',
      label: 'Trucking, Winch & Heavy Haul',
      shortLabel: 'Trucking & Heavy Haul',
      icon: Icons.local_shipping_outlined,
      sampleServices: ['Winch Trucks', 'Bed Trucks', 'Rig Moving', 'Lowboy / Step Deck'],
    ),
    YellowPagesCategoryItem(
      code: 'vacuum_hydrovac_fluid',
      label: 'Vacuum, Hydrovac & Fluid Hauling',
      shortLabel: 'Vac & Hydrovac',
      icon: Icons.water_drop_outlined,
      sampleServices: ['Hydrovac Excavation', 'Combo Vac', 'Water Hauling', 'Hot Oilers'],
    ),
    YellowPagesCategoryItem(
      code: 'hotshot_pilot_logistics',
      label: 'Hot Shot, Pilot Cars & Logistics',
      shortLabel: 'Hot Shot & Pilot',
      icon: Icons.speed_outlined,
      sampleServices: ['24/7 Hot Shot', 'Pilot / Escort Cars', 'High Pole', 'Route Survey'],
    ),
    YellowPagesCategoryItem(
      code: 'crane_picker_rigging',
      label: 'Cranes, Picker Trucks & Rigging',
      shortLabel: 'Cranes & Pickers',
      icon: Icons.construction_outlined,
      sampleServices: ['Picker / Boom Trucks', 'Mobile Cranes', 'Heavy Rigging'],
    ),
    YellowPagesCategoryItem(
      code: 'pipe_octg_supply',
      label: 'Pipe, OCTG, Casing & Tubing Supply',
      shortLabel: 'Pipe & OCTG',
      icon: Icons.linear_scale_outlined,
      sampleServices: ['Drill Pipe', 'Casing & Tubing', 'Line Pipe', 'Sucker Rod'],
    ),
    YellowPagesCategoryItem(
      code: 'pipe_inspection_ndt',
      label: 'Pipe Inspection, NDT & Reclamation',
      shortLabel: 'Pipe Inspection / NDT',
      icon: Icons.fact_check_outlined,
      sampleServices: ['EMI / Ultrasonic NDT', 'Threading', 'Straightening', 'Hydrotesting'],
    ),
    YellowPagesCategoryItem(
      code: 'drilling_rigs_directional',
      label: 'Drilling, Service Rigs & Directional',
      shortLabel: 'Drilling & Service Rigs',
      icon: Icons.precision_manufacturing_outlined,
      sampleServices: ['Drilling Contractors', 'Service / Workover Rigs', 'Directional / MWD'],
    ),
    YellowPagesCategoryItem(
      code: 'completions_frac_wireline',
      label: 'Completions, Frac, Coil & Wireline',
      shortLabel: 'Frac, Coil & Wireline',
      icon: Icons.bolt_outlined,
      sampleServices: ['Fracturing', 'Coiled Tubing', 'Wireline & Slickline', 'Well Testing'],
    ),
    YellowPagesCategoryItem(
      code: 'wellhead_valves_pressure',
      label: 'Wellheads, Valves & Pressure Control',
      shortLabel: 'Wellhead & Valves',
      icon: Icons.tune_outlined,
      sampleServices: ['Wellhead Service', 'Valves & Actuators', 'BOP / Snubbing'],
    ),
    YellowPagesCategoryItem(
      code: 'pumps_artificial_lift',
      label: 'Artificial Lift, Pumps & Compression',
      shortLabel: 'Pumps & Compression',
      icon: Icons.settings_input_component_outlined,
      sampleServices: ['Rod Pumps / ESP', 'Gas Compression', 'Generators / Gensets'],
    ),
    YellowPagesCategoryItem(
      code: 'tanks_vessels_process',
      label: 'Tanks, Vessels & Process Equipment',
      shortLabel: 'Tanks & Vessels',
      icon: Icons.propane_tank_outlined,
      sampleServices: ['Frac & Storage Tanks', 'Separators & Treaters', 'Pressure Vessels'],
    ),
    YellowPagesCategoryItem(
      code: 'welding_machining_fab',
      label: 'Mobile Welding, Machining & Fabrication',
      shortLabel: 'Welding & Fabrication',
      icon: Icons.handyman_outlined,
      sampleServices: ['B-Pressure Rig Welding', 'CNC Machine Shop', 'Custom Skid Fab'],
    ),
    YellowPagesCategoryItem(
      code: 'equipment_rentals_tools',
      label: 'Oilfield Rentals, Boilers & Downhole Tools',
      shortLabel: 'Oilfield Rentals',
      icon: Icons.home_repair_service_outlined,
      sampleServices: ['Light Towers & Heaters', 'Boilers', 'Downhole & Fishing Tools'],
    ),
    YellowPagesCategoryItem(
      code: 'matting_lease_civil',
      label: 'Access Matting, Civil & Lease Construction',
      shortLabel: 'Matting & Civil',
      icon: Icons.terrain_outlined,
      sampleServices: ['Rig & Swamp Mats', 'Lease Building', 'Earthworks & Mulching'],
    ),
    YellowPagesCategoryItem(
      code: 'pipeline_facility_construction',
      label: 'Pipeline & Facility Construction',
      shortLabel: 'Pipeline & Facilities',
      icon: Icons.account_tree_outlined,
      sampleServices: ['Pipeline Contractors', 'Facility Turnarounds', 'HDD & Integrity'],
    ),
    YellowPagesCategoryItem(
      code: 'electrical_automation_scada',
      label: 'Electrical, Instrumentation & SCADA',
      shortLabel: 'E&I / Automation',
      icon: Icons.memory_outlined,
      sampleServices: ['Oilfield Electrical', 'Instrumentation', 'SCADA / PLC Controls'],
    ),
    YellowPagesCategoryItem(
      code: 'safety_h2s_medics',
      label: 'Safety, H2S, Industrial Medics & Fire',
      shortLabel: 'Safety & Medics',
      icon: Icons.health_and_safety_outlined,
      sampleServices: ['H2S / Breathing Air', 'Industrial Medics / MTC', 'Fire & Spill'],
    ),
    YellowPagesCategoryItem(
      code: 'environmental_remediation_waste',
      label: 'Environmental, Waste & Remediation',
      shortLabel: 'Environmental',
      icon: Icons.eco_outlined,
      sampleServices: ['Remediation & Reclamation', 'Oilfield Waste Disposal', 'Abandonment'],
    ),
    YellowPagesCategoryItem(
      code: 'chemical_mud_lubricants',
      label: 'Drilling Fluids, Chemicals & Fuel',
      shortLabel: 'Chemicals & Fuel',
      icon: Icons.science_outlined,
      sampleServices: ['Production Chemicals', 'Drilling Mud', 'Bulk Fuel & Lubricants'],
    ),
    YellowPagesCategoryItem(
      code: 'fleet_heavy_duty_repair',
      label: 'Heavy-Duty Mechanics, Hydraulics & Fleet',
      shortLabel: 'Heavy-Duty Repair',
      icon: Icons.build_circle_outlined,
      sampleServices: ['Mobile Heavy-Duty Mechanics', 'CVIP / DOT', 'Hydraulics & Tires'],
    ),
    YellowPagesCategoryItem(
      code: 'camps_catering_accommodations',
      label: 'Remote Camps, Catering & Portable Buildings',
      shortLabel: 'Camps & Buildings',
      icon: Icons.cabin_outlined,
      sampleServices: ['Workforce Camps', 'Wellsite Trailers', 'Skid Shacks & Catering'],
    ),
    YellowPagesCategoryItem(
      code: 'surveying_engineering_geomatics',
      label: 'Engineering, Surveying & Line Locating',
      shortLabel: 'Survey & Engineering',
      icon: Icons.explore_outlined,
      sampleServices: ['Land Surveying', 'Line Locating', 'Oilfield Engineering'],
    ),
    YellowPagesCategoryItem(
      code: 'staffing_training_compliance',
      label: 'Staffing, Safety Training & Compliance',
      shortLabel: 'Staffing & Training',
      icon: Icons.groups_outlined,
      sampleServices: ['Oilfield Staffing', 'Safety Tickets', 'ISNetworld / ComplyWorks'],
    ),
    YellowPagesCategoryItem(
      code: 'explorers_producers_midstream',
      label: 'Explorers, Producers (E&P) & Midstream',
      shortLabel: 'E&P / Midstream',
      icon: Icons.oil_barrel_outlined,
      sampleServices: ['Operating Companies', 'Gas Plants', 'Midstream Terminals'],
    ),
  ];

  static const regions = <YellowPagesRegionOption>[
    // Canada
    YellowPagesRegionOption(countryCode: 'CA', regionCode: 'AB', name: 'Alberta'),
    YellowPagesRegionOption(countryCode: 'CA', regionCode: 'BC', name: 'British Columbia'),
    YellowPagesRegionOption(countryCode: 'CA', regionCode: 'SK', name: 'Saskatchewan'),
    YellowPagesRegionOption(countryCode: 'CA', regionCode: 'MB', name: 'Manitoba'),
    YellowPagesRegionOption(countryCode: 'CA', regionCode: 'ON', name: 'Ontario'),
    YellowPagesRegionOption(countryCode: 'CA', regionCode: 'NL', name: 'Newfoundland & Labrador'),
    YellowPagesRegionOption(countryCode: 'CA', regionCode: 'NS', name: 'Nova Scotia'),
    YellowPagesRegionOption(countryCode: 'CA', regionCode: 'NT', name: 'Northwest Territories'),
    // USA
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'TX', name: 'Texas'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'ND', name: 'North Dakota'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'OK', name: 'Oklahoma'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'NM', name: 'New Mexico'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'WY', name: 'Wyoming'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'LA', name: 'Louisiana'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'PA', name: 'Pennsylvania'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'CO', name: 'Colorado'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'OH', name: 'Ohio'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'WV', name: 'West Virginia'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'AK', name: 'Alaska'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'CA', name: 'California'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'MT', name: 'Montana'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'UT', name: 'Utah'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'KS', name: 'Kansas'),
  ];

  static const basins = <String>[
    'WCSB (Western Canada)',
    'Montney',
    'Duvernay',
    'Oil Sands / Athabasca',
    'Bakken / Williston',
    'Permian Basin',
    'Eagle Ford',
    'Haynesville',
    'DJ / Niobrara',
    'Powder River',
    'Anadarko / SCOOP-STACK',
    'Marcellus / Utica',
    'Gulf Coast / Offshore',
  ];

  static const certifications = <String>[
    'COR / SECOR',
    'ISNetworld',
    'ComplyWorks',
    'Avetta',
    'ABSA',
    'API Certified',
    'CSA / CWB',
  ];

  static const oilfieldHubs = <({String city, String regionCode, String countryCode})>[
    // Canada Oilpatch Hubs
    (city: 'Edmonton', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Calgary', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Nisku', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Leduc', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Grande Prairie', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Red Deer', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Fort McMurray', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Lloydminster', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Drayton Valley', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Medicine Hat', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Brooks', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Sylvan Lake', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Fort St. John', regionCode: 'BC', countryCode: 'CA'),
    (city: 'Dawson Creek', regionCode: 'BC', countryCode: 'CA'),
    (city: 'Estevan', regionCode: 'SK', countryCode: 'CA'),
    (city: 'Weyburn', regionCode: 'SK', countryCode: 'CA'),
    (city: 'Kindersley', regionCode: 'SK', countryCode: 'CA'),
    (city: 'Swift Current', regionCode: 'SK', countryCode: 'CA'),
    (city: 'Virden', regionCode: 'MB', countryCode: 'CA'),
    (city: 'Sarnia', regionCode: 'ON', countryCode: 'CA'),
    (city: "St. John's", regionCode: 'NL', countryCode: 'CA'),
    // USA Oilpatch Hubs
    (city: 'Houston', regionCode: 'TX', countryCode: 'US'),
    (city: 'Midland', regionCode: 'TX', countryCode: 'US'),
    (city: 'Odessa', regionCode: 'TX', countryCode: 'US'),
    (city: 'Corpus Christi', regionCode: 'TX', countryCode: 'US'),
    (city: 'Dallas', regionCode: 'TX', countryCode: 'US'),
    (city: 'Fort Worth', regionCode: 'TX', countryCode: 'US'),
    (city: 'San Antonio', regionCode: 'TX', countryCode: 'US'),
    (city: 'Kilgore', regionCode: 'TX', countryCode: 'US'),
    (city: 'Pecos', regionCode: 'TX', countryCode: 'US'),
    (city: 'Oklahoma City', regionCode: 'OK', countryCode: 'US'),
    (city: 'Tulsa', regionCode: 'OK', countryCode: 'US'),
    (city: 'Enid', regionCode: 'OK', countryCode: 'US'),
    (city: 'Elk City', regionCode: 'OK', countryCode: 'US'),
    (city: 'Williston', regionCode: 'ND', countryCode: 'US'),
    (city: 'Dickinson', regionCode: 'ND', countryCode: 'US'),
    (city: 'Minot', regionCode: 'ND', countryCode: 'US'),
    (city: 'Hobbs', regionCode: 'NM', countryCode: 'US'),
    (city: 'Carlsbad', regionCode: 'NM', countryCode: 'US'),
    (city: 'Artesia', regionCode: 'NM', countryCode: 'US'),
    (city: 'Farmington', regionCode: 'NM', countryCode: 'US'),
    (city: 'Casper', regionCode: 'WY', countryCode: 'US'),
    (city: 'Gillette', regionCode: 'WY', countryCode: 'US'),
    (city: 'Rock Springs', regionCode: 'WY', countryCode: 'US'),
    (city: 'Lafayette', regionCode: 'LA', countryCode: 'US'),
    (city: 'Shreveport', regionCode: 'LA', countryCode: 'US'),
    (city: 'Houma', regionCode: 'LA', countryCode: 'US'),
    (city: 'Denver', regionCode: 'CO', countryCode: 'US'),
    (city: 'Greeley', regionCode: 'CO', countryCode: 'US'),
    (city: 'Grand Junction', regionCode: 'CO', countryCode: 'US'),
    (city: 'Pittsburgh', regionCode: 'PA', countryCode: 'US'),
    (city: 'Canonsburg', regionCode: 'PA', countryCode: 'US'),
    (city: 'Williamsport', regionCode: 'PA', countryCode: 'US'),
    (city: 'Morgantown', regionCode: 'WV', countryCode: 'US'),
    (city: 'Canton', regionCode: 'OH', countryCode: 'US'),
    (city: 'Bakersfield', regionCode: 'CA', countryCode: 'US'),
    (city: 'Wichita', regionCode: 'KS', countryCode: 'US'),
    (city: 'Billings', regionCode: 'MT', countryCode: 'US'),
    (city: 'Vernal', regionCode: 'UT', countryCode: 'US'),
    (city: 'Anchorage', regionCode: 'AK', countryCode: 'US'),
  ];

  static List<({String city, String regionCode, String countryCode})> hubsForLocation({
    String countryCode = '',
    String regionCode = '',
  }) {
    final c = countryCode.trim().toUpperCase();
    final r = regionCode.trim().toUpperCase();
    return oilfieldHubs.where((hub) {
      if (c.isNotEmpty && hub.countryCode != c) return false;
      if (r.isNotEmpty && hub.regionCode != r) return false;
      return true;
    }).toList(growable: false);
  }

  static IconData iconForCategory(String code) {
    switch (code) {
      case 'trucking_heavy_haul':
        return Icons.local_shipping_outlined;
      case 'vacuum_hydrovac_fluid':
        return Icons.opacity_outlined;
      case 'hotshot_pilot_logistics':
        return Icons.speed_outlined;
      case 'crane_picker_rigging':
        return Icons.construction_outlined;
      case 'pipe_octg_supply':
        return Icons.linear_scale_outlined;
      case 'pipe_inspection_ndt':
        return Icons.fact_check_outlined;
      case 'drilling_rigs_directional':
        return Icons.precision_manufacturing_outlined;
      case 'completions_frac_wireline':
        return Icons.bolt_outlined;
      case 'wellhead_valves_pressure':
        return Icons.tune_outlined;
      case 'pumps_artificial_lift':
        return Icons.settings_input_component_outlined;
      case 'tanks_vessels_process':
        return Icons.propane_tank_outlined;
      case 'welding_machining_fab':
        return Icons.handyman_outlined;
      case 'equipment_rentals_tools':
        return Icons.home_repair_service_outlined;
      case 'matting_lease_civil':
        return Icons.terrain_outlined;
      case 'pipeline_facility_construction':
        return Icons.account_tree_outlined;
      case 'electrical_automation_scada':
        return Icons.memory_outlined;
      case 'safety_h2s_medics':
        return Icons.health_and_safety_outlined;
      case 'environmental_remediation_waste':
        return Icons.eco_outlined;
      case 'chemical_mud_lubricants':
        return Icons.science_outlined;
      case 'fleet_heavy_duty_repair':
        return Icons.build_circle_outlined;
      case 'camps_catering_accommodations':
        return Icons.cabin_outlined;
      case 'surveying_engineering_geomatics':
        return Icons.explore_outlined;
      case 'staffing_training_compliance':
        return Icons.groups_outlined;
      case 'explorers_producers_midstream':
        return Icons.oil_barrel_outlined;
      default:
        return Icons.business_outlined;
    }
  }

  static YellowPagesCategoryItem? byCode(String code) {
    for (final item in categories) {
      if (item.code == code) return item;
    }
    return null;
  }

  static List<YellowPagesRegionOption> regionsForCountry(String countryCode) {
    final normalized = countryCode.trim().toUpperCase();
    if (normalized.isEmpty) return regions;
    return regions.where((r) => r.countryCode == normalized).toList(growable: false);
  }
}
