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

@immutable
class YellowPagesContinentOption {
  const YellowPagesContinentOption({
    required this.code,
    required this.label,
    required this.shortLabel,
  });

  final String code;
  final String label;
  final String shortLabel;
}

@immutable
class YellowPagesCountryOption {
  const YellowPagesCountryOption({
    required this.code,
    required this.name,
    required this.continentCode,
    this.isMiddleEast = false,
    this.alsoAsia = false,
    this.alsoEurope = false,
    this.isPopularOilGas = false,
    this.dialCode = '+1',
  });

  final String code;
  final String name;
  final String continentCode;
  final bool isMiddleEast;
  final bool alsoAsia;
  final bool alsoEurope;
  final bool isPopularOilGas;
  final String dialCode;

  String get displayLabel => '$name ($code)';
}

abstract final class PipeBuyerYellowPagesTaxonomy {
  static const categories = <YellowPagesCategoryItem>[
    YellowPagesCategoryItem(
      code: 'trucking_heavy_haul',
      label: 'Trucking, Towing, Winch & Heavy Haul',
      shortLabel: 'Trucking, Towing & Winch',
      icon: Icons.local_shipping_outlined,
      sampleServices: [
        'Winch Trucks',
        'Heavy Towing & Recovery',
        'Bed Trucks',
        'Rig Moving',
        'Lowboy / Step Deck',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'vacuum_hydrovac_fluid',
      label: 'Vacuum, Hydrovac & Fluid Hauling',
      shortLabel: 'Vac, Hydrovac & Fluid',
      icon: Icons.water_drop_outlined,
      sampleServices: [
        'Hydrovac Excavation',
        'Combo Vac',
        'Water Hauling',
        'Hot Oilers',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'hotshot_pilot_logistics',
      label: 'Hot Shot, Pilot Cars & Logistics',
      shortLabel: 'Hot Shot & Pilot Cars',
      icon: Icons.speed_outlined,
      sampleServices: [
        '24/7 Hot Shot',
        'Pilot / Escort Cars',
        'High Pole',
        'Route Survey',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'crane_picker_rigging',
      label: 'Cranes, Picker Trucks & Rigging',
      shortLabel: 'Cranes, Pickers & Rigging',
      icon: Icons.construction_outlined,
      sampleServices: [
        'Picker / Boom Trucks',
        'Mobile Cranes',
        'Heavy Rigging',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'pipe_octg_supply',
      label: 'Pipe, OCTG, Casing & Tubing Supply',
      shortLabel: 'Pipe, OCTG & Casing',
      icon: Icons.plumbing_outlined,
      sampleServices: [
        'Drill Pipe',
        'Casing & Tubing',
        'Line Pipe',
        'Sucker Rod',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'pipe_inspection_ndt',
      label: 'Pipe Inspection, NDT & Reclamation',
      shortLabel: 'Pipe Inspection & NDT',
      icon: Icons.fact_check_outlined,
      sampleServices: [
        'EMI / Ultrasonic NDT',
        'Threading',
        'Straightening',
        'Hydrotesting',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'drilling_rigs_directional',
      label: 'Drilling, Service Rigs & Directional',
      shortLabel: 'Drilling & Service Rigs',
      icon: Icons.precision_manufacturing_outlined,
      sampleServices: [
        'Drilling Contractors',
        'Service / Workover Rigs',
        'Directional / MWD',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'completions_frac_wireline',
      label: 'Completions, Frac, Coil & Wireline',
      shortLabel: 'Frac, Coil & Wireline',
      icon: Icons.bolt_outlined,
      sampleServices: [
        'Fracturing',
        'Coiled Tubing',
        'Wireline & Slickline',
        'Well Testing',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'wellhead_valves_pressure',
      label: 'Wellheads, Valves & Pressure Control',
      shortLabel: 'Wellheads & Valves',
      icon: Icons.tune_outlined,
      sampleServices: [
        'Wellhead Service',
        'Valves & Actuators',
        'BOP / Snubbing',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'pumps_artificial_lift',
      label: 'Artificial Lift, Pumps & Compression',
      shortLabel: 'Pumps & Compression',
      icon: Icons.settings_input_component_outlined,
      sampleServices: [
        'Rod Pumps / ESP',
        'Gas Compression',
        'Generators / Gensets',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'tanks_vessels_process',
      label: 'Tanks, Vessels & Process Equipment',
      shortLabel: 'Tanks & Vessels',
      icon: Icons.propane_tank_outlined,
      sampleServices: [
        'Frac & Storage Tanks',
        'Separators & Treaters',
        'Pressure Vessels',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'welding_machining_fab',
      label: 'Mobile Welding, Machining & Fabrication',
      shortLabel: 'Welding & Fabrication',
      icon: Icons.handyman_outlined,
      sampleServices: [
        'B-Pressure Rig Welding',
        'CNC Machine Shop',
        'Custom Skid Fab',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'equipment_rentals_tools',
      label: 'Oilfield Rentals, Boilers & Downhole Tools',
      shortLabel: 'Oilfield Rentals & Tools',
      icon: Icons.home_repair_service_outlined,
      sampleServices: [
        'Light Towers & Heaters',
        'Boilers',
        'Downhole & Fishing Tools',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'matting_lease_civil',
      label: 'Access Matting, Civil & Lease Construction',
      shortLabel: 'Matting & Lease Civil',
      icon: Icons.terrain_outlined,
      sampleServices: [
        'Rig & Swamp Mats',
        'Lease Building',
        'Earthworks & Mulching',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'pipeline_facility_construction',
      label: 'Pipeline & Facility Construction',
      shortLabel: 'Pipeline & Facilities',
      icon: Icons.account_tree_outlined,
      sampleServices: [
        'Pipeline Contractors',
        'Facility Turnarounds',
        'HDD & Integrity',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'electrical_automation_scada',
      label: 'Electrical, Instrumentation & SCADA',
      shortLabel: 'Electrical & SCADA',
      icon: Icons.memory_outlined,
      sampleServices: [
        'Oilfield Electrical',
        'Instrumentation',
        'SCADA / PLC Controls',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'safety_h2s_medics',
      label: 'Safety, H2S, Industrial Medics & Fire',
      shortLabel: 'Safety, H2S & Medics',
      icon: Icons.health_and_safety_outlined,
      sampleServices: [
        'H2S / Breathing Air',
        'Industrial Medics / MTC',
        'Fire & Spill',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'environmental_remediation_waste',
      label: 'Environmental, Waste & Remediation',
      shortLabel: 'Environmental & Waste',
      icon: Icons.eco_outlined,
      sampleServices: [
        'Remediation & Reclamation',
        'Oilfield Waste Disposal',
        'Abandonment',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'chemical_mud_lubricants',
      label: 'Drilling Fluids, Chemicals & Fuel',
      shortLabel: 'Chemicals, Mud & Fuel',
      icon: Icons.science_outlined,
      sampleServices: [
        'Production Chemicals',
        'Drilling Mud',
        'Bulk Fuel & Lubricants',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'fleet_heavy_duty_repair',
      label: 'Heavy-Duty Mechanics, Hydraulics & Fleet',
      shortLabel: 'Heavy-Duty Mechanics',
      icon: Icons.build_circle_outlined,
      sampleServices: [
        'Mobile Heavy-Duty Mechanics',
        'CVIP / DOT',
        'Hydraulics & Tires',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'camps_catering_accommodations',
      label: 'Remote Camps, Catering & Portable Buildings',
      shortLabel: 'Camps & Portable Buildings',
      icon: Icons.cabin_outlined,
      sampleServices: [
        'Workforce Camps',
        'Wellsite Trailers',
        'Skid Shacks & Catering',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'surveying_engineering_geomatics',
      label: 'Engineering, Surveying & Line Locating',
      shortLabel: 'Engineering & Surveying',
      icon: Icons.explore_outlined,
      sampleServices: [
        'Land Surveying',
        'Line Locating',
        'Oilfield Engineering',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'oil_gas_training_courses',
      label: 'Oil & Gas Training Facilities & Courses',
      shortLabel: 'Oil & Gas Training & Courses',
      icon: Icons.school_outlined,
      sampleServices: [
        'H2S Alive & Well Control (IWCF / WellSharp)',
        'Safety Tickets (CSO, Confined Space, Fall Protection)',
        'Offshore Survival (OPITO / BOSIET / HUET)',
        'Polytechnics, Rig Tech, Welding & Class 1 / CDL',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'staffing_training_compliance',
      label: 'Staffing, Crew Logistics & Compliance',
      shortLabel: 'Staffing & Compliance',
      icon: Icons.groups_outlined,
      sampleServices: [
        'Oilfield Staffing & Manpower',
        'Crew Transport & Aviation',
        'ISNetworld / ComplyWorks / Drug Testing',
      ],
    ),
    YellowPagesCategoryItem(
      code: 'explorers_producers_midstream',
      label: 'Explorers, Producers (E&P) & Midstream',
      shortLabel: 'E&P & Midstream',
      icon: Icons.oil_barrel_outlined,
      sampleServices: [
        'Operating Companies',
        'Gas Plants',
        'Midstream Terminals',
      ],
    ),
  ];

  static const continents = <YellowPagesContinentOption>[
    YellowPagesContinentOption(
      code: 'north_america',
      label: 'North America',
      shortLabel: 'North America',
    ),
    YellowPagesContinentOption(
      code: 'middle_east',
      label: 'Middle East',
      shortLabel: 'Middle East',
    ),
    YellowPagesContinentOption(
      code: 'europe',
      label: 'Europe',
      shortLabel: 'Europe',
    ),
    YellowPagesContinentOption(
      code: 'asia',
      label: 'Asia',
      shortLabel: 'Asia',
    ),
    YellowPagesContinentOption(
      code: 'south_america',
      label: 'South America',
      shortLabel: 'South America',
    ),
    YellowPagesContinentOption(
      code: 'africa',
      label: 'Africa',
      shortLabel: 'Africa',
    ),
    YellowPagesContinentOption(
      code: 'oceania',
      label: 'Australia & Oceania',
      shortLabel: 'Australia & Oceania',
    ),
  ];

  /// Complete alphabetical (A-Z) sovereign country catalog matching
  /// countries-ofthe-world.com across all 6 continents + Middle East tags.
  static const countries = <YellowPagesCountryOption>[
    YellowPagesCountryOption(
        code: 'AF',
        name: 'Afghanistan',
        continentCode: 'asia',
        dialCode: '+93'),
    YellowPagesCountryOption(
        code: 'AL', name: 'Albania', continentCode: 'europe', dialCode: '+355'),
    YellowPagesCountryOption(
        code: 'DZ',
        name: 'Algeria',
        continentCode: 'africa',
        isPopularOilGas: true,
        dialCode: '+213'),
    YellowPagesCountryOption(
        code: 'AD', name: 'Andorra', continentCode: 'europe', dialCode: '+376'),
    YellowPagesCountryOption(
        code: 'AO',
        name: 'Angola',
        continentCode: 'africa',
        isPopularOilGas: true,
        dialCode: '+244'),
    YellowPagesCountryOption(
        code: 'AG',
        name: 'Antigua and Barbuda',
        continentCode: 'north_america',
        dialCode: '+1'),
    YellowPagesCountryOption(
        code: 'AR',
        name: 'Argentina',
        continentCode: 'south_america',
        isPopularOilGas: true,
        dialCode: '+54'),
    YellowPagesCountryOption(
        code: 'AM',
        name: 'Armenia',
        continentCode: 'europe',
        alsoAsia: true,
        dialCode: '+374'),
    YellowPagesCountryOption(
        code: 'AU',
        name: 'Australia',
        continentCode: 'oceania',
        isPopularOilGas: true,
        dialCode: '+61'),
    YellowPagesCountryOption(
        code: 'AT',
        name: 'Austria',
        continentCode: 'europe',
        isPopularOilGas: true,
        dialCode: '+43'),
    YellowPagesCountryOption(
        code: 'AZ',
        name: 'Azerbaijan',
        continentCode: 'europe',
        alsoAsia: true,
        isPopularOilGas: true,
        dialCode: '+994'),
    YellowPagesCountryOption(
        code: 'BS',
        name: 'Bahamas',
        continentCode: 'north_america',
        dialCode: '+1'),
    YellowPagesCountryOption(
        code: 'BH',
        name: 'Bahrain',
        continentCode: 'asia',
        isMiddleEast: true,
        isPopularOilGas: true,
        dialCode: '+973'),
    YellowPagesCountryOption(
        code: 'BD',
        name: 'Bangladesh',
        continentCode: 'asia',
        dialCode: '+880'),
    YellowPagesCountryOption(
        code: 'BB',
        name: 'Barbados',
        continentCode: 'north_america',
        dialCode: '+1'),
    YellowPagesCountryOption(
        code: 'BY', name: 'Belarus', continentCode: 'europe', dialCode: '+375'),
    YellowPagesCountryOption(
        code: 'BE', name: 'Belgium', continentCode: 'europe', dialCode: '+32'),
    YellowPagesCountryOption(
        code: 'BZ',
        name: 'Belize',
        continentCode: 'north_america',
        dialCode: '+501'),
    YellowPagesCountryOption(
        code: 'BJ', name: 'Benin', continentCode: 'africa', dialCode: '+229'),
    YellowPagesCountryOption(
        code: 'BT', name: 'Bhutan', continentCode: 'asia', dialCode: '+975'),
    YellowPagesCountryOption(
        code: 'BO',
        name: 'Bolivia',
        continentCode: 'south_america',
        dialCode: '+591'),
    YellowPagesCountryOption(
        code: 'BA',
        name: 'Bosnia and Herzegovina',
        continentCode: 'europe',
        dialCode: '+387'),
    YellowPagesCountryOption(
        code: 'BW',
        name: 'Botswana',
        continentCode: 'africa',
        dialCode: '+267'),
    YellowPagesCountryOption(
        code: 'BR',
        name: 'Brazil',
        continentCode: 'south_america',
        isPopularOilGas: true,
        dialCode: '+55'),
    YellowPagesCountryOption(
        code: 'BN',
        name: 'Brunei',
        continentCode: 'asia',
        isPopularOilGas: true,
        dialCode: '+673'),
    YellowPagesCountryOption(
        code: 'BG',
        name: 'Bulgaria',
        continentCode: 'europe',
        dialCode: '+359'),
    YellowPagesCountryOption(
        code: 'BF',
        name: 'Burkina Faso',
        continentCode: 'africa',
        dialCode: '+226'),
    YellowPagesCountryOption(
        code: 'BI', name: 'Burundi', continentCode: 'africa', dialCode: '+257'),
    YellowPagesCountryOption(
        code: 'CV',
        name: 'Cabo Verde',
        continentCode: 'africa',
        dialCode: '+238'),
    YellowPagesCountryOption(
        code: 'KH', name: 'Cambodia', continentCode: 'asia', dialCode: '+855'),
    YellowPagesCountryOption(
        code: 'CM',
        name: 'Cameroon',
        continentCode: 'africa',
        dialCode: '+237'),
    YellowPagesCountryOption(
        code: 'CA',
        name: 'Canada',
        continentCode: 'north_america',
        isPopularOilGas: true,
        dialCode: '+1'),
    YellowPagesCountryOption(
        code: 'CF',
        name: 'Central African Republic',
        continentCode: 'africa',
        dialCode: '+236'),
    YellowPagesCountryOption(
        code: 'TD', name: 'Chad', continentCode: 'africa', dialCode: '+235'),
    YellowPagesCountryOption(
        code: 'CL',
        name: 'Chile',
        continentCode: 'south_america',
        dialCode: '+56'),
    YellowPagesCountryOption(
        code: 'CN',
        name: 'China',
        continentCode: 'asia',
        isPopularOilGas: true,
        dialCode: '+86'),
    YellowPagesCountryOption(
        code: 'CO',
        name: 'Colombia',
        continentCode: 'south_america',
        isPopularOilGas: true,
        dialCode: '+57'),
    YellowPagesCountryOption(
        code: 'KM', name: 'Comoros', continentCode: 'africa', dialCode: '+269'),
    YellowPagesCountryOption(
        code: 'CG',
        name: 'Congo (Republic of the)',
        continentCode: 'africa',
        dialCode: '+242'),
    YellowPagesCountryOption(
        code: 'CD',
        name: 'Congo (Democratic Republic)',
        continentCode: 'africa',
        dialCode: '+243'),
    YellowPagesCountryOption(
        code: 'CR',
        name: 'Costa Rica',
        continentCode: 'north_america',
        dialCode: '+506'),
    YellowPagesCountryOption(
        code: 'CI',
        name: "Cote d'Ivoire",
        continentCode: 'africa',
        dialCode: '+225'),
    YellowPagesCountryOption(
        code: 'HR', name: 'Croatia', continentCode: 'europe', dialCode: '+385'),
    YellowPagesCountryOption(
        code: 'CU',
        name: 'Cuba',
        continentCode: 'north_america',
        dialCode: '+53'),
    YellowPagesCountryOption(
        code: 'CY',
        name: 'Cyprus',
        continentCode: 'europe',
        alsoAsia: true,
        isMiddleEast: true,
        dialCode: '+357'),
    YellowPagesCountryOption(
        code: 'CZ', name: 'Czechia', continentCode: 'europe', dialCode: '+420'),
    YellowPagesCountryOption(
        code: 'DK',
        name: 'Denmark',
        continentCode: 'europe',
        isPopularOilGas: true,
        dialCode: '+45'),
    YellowPagesCountryOption(
        code: 'DJ',
        name: 'Djibouti',
        continentCode: 'africa',
        dialCode: '+253'),
    YellowPagesCountryOption(
        code: 'DM',
        name: 'Dominica',
        continentCode: 'north_america',
        dialCode: '+1'),
    YellowPagesCountryOption(
        code: 'DO',
        name: 'Dominican Republic',
        continentCode: 'north_america',
        dialCode: '+1'),
    YellowPagesCountryOption(
        code: 'EC',
        name: 'Ecuador',
        continentCode: 'south_america',
        isPopularOilGas: true,
        dialCode: '+593'),
    YellowPagesCountryOption(
        code: 'EG',
        name: 'Egypt',
        continentCode: 'africa',
        isMiddleEast: true,
        isPopularOilGas: true,
        dialCode: '+20'),
    YellowPagesCountryOption(
        code: 'SV',
        name: 'El Salvador',
        continentCode: 'north_america',
        dialCode: '+503'),
    YellowPagesCountryOption(
        code: 'GQ',
        name: 'Equatorial Guinea',
        continentCode: 'africa',
        dialCode: '+240'),
    YellowPagesCountryOption(
        code: 'ER', name: 'Eritrea', continentCode: 'africa', dialCode: '+291'),
    YellowPagesCountryOption(
        code: 'EE', name: 'Estonia', continentCode: 'europe', dialCode: '+372'),
    YellowPagesCountryOption(
        code: 'SZ',
        name: 'Eswatini',
        continentCode: 'africa',
        dialCode: '+268'),
    YellowPagesCountryOption(
        code: 'ET',
        name: 'Ethiopia',
        continentCode: 'africa',
        dialCode: '+251'),
    YellowPagesCountryOption(
        code: 'FJ', name: 'Fiji', continentCode: 'oceania', dialCode: '+679'),
    YellowPagesCountryOption(
        code: 'FI', name: 'Finland', continentCode: 'europe', dialCode: '+358'),
    YellowPagesCountryOption(
        code: 'FR',
        name: 'France',
        continentCode: 'europe',
        isPopularOilGas: true,
        dialCode: '+33'),
    YellowPagesCountryOption(
        code: 'GA', name: 'Gabon', continentCode: 'africa', dialCode: '+241'),
    YellowPagesCountryOption(
        code: 'GM', name: 'Gambia', continentCode: 'africa', dialCode: '+220'),
    YellowPagesCountryOption(
        code: 'GE',
        name: 'Georgia',
        continentCode: 'europe',
        alsoAsia: true,
        dialCode: '+995'),
    YellowPagesCountryOption(
        code: 'DE',
        name: 'Germany',
        continentCode: 'europe',
        isPopularOilGas: true,
        dialCode: '+49'),
    YellowPagesCountryOption(
        code: 'GH',
        name: 'Ghana',
        continentCode: 'africa',
        isPopularOilGas: true,
        dialCode: '+233'),
    YellowPagesCountryOption(
        code: 'GR',
        name: 'Greece',
        continentCode: 'europe',
        isPopularOilGas: true,
        dialCode: '+30'),
    YellowPagesCountryOption(
        code: 'GD',
        name: 'Grenada',
        continentCode: 'north_america',
        dialCode: '+1'),
    YellowPagesCountryOption(
        code: 'GT',
        name: 'Guatemala',
        continentCode: 'north_america',
        dialCode: '+502'),
    YellowPagesCountryOption(
        code: 'GN', name: 'Guinea', continentCode: 'africa', dialCode: '+224'),
    YellowPagesCountryOption(
        code: 'GW',
        name: 'Guinea-Bissau',
        continentCode: 'africa',
        dialCode: '+245'),
    YellowPagesCountryOption(
        code: 'GY',
        name: 'Guyana',
        continentCode: 'south_america',
        isPopularOilGas: true,
        dialCode: '+592'),
    YellowPagesCountryOption(
        code: 'HT',
        name: 'Haiti',
        continentCode: 'north_america',
        dialCode: '+509'),
    YellowPagesCountryOption(
        code: 'HN',
        name: 'Honduras',
        continentCode: 'north_america',
        dialCode: '+504'),
    YellowPagesCountryOption(
        code: 'HU', name: 'Hungary', continentCode: 'europe', dialCode: '+36'),
    YellowPagesCountryOption(
        code: 'IS', name: 'Iceland', continentCode: 'europe', dialCode: '+354'),
    YellowPagesCountryOption(
        code: 'IN',
        name: 'India',
        continentCode: 'asia',
        isPopularOilGas: true,
        dialCode: '+91'),
    YellowPagesCountryOption(
        code: 'ID',
        name: 'Indonesia',
        continentCode: 'asia',
        isPopularOilGas: true,
        dialCode: '+62'),
    YellowPagesCountryOption(
        code: 'IR',
        name: 'Iran',
        continentCode: 'asia',
        isMiddleEast: true,
        dialCode: '+98'),
    YellowPagesCountryOption(
        code: 'IQ',
        name: 'Iraq',
        continentCode: 'asia',
        isMiddleEast: true,
        isPopularOilGas: true,
        dialCode: '+964'),
    YellowPagesCountryOption(
        code: 'IE', name: 'Ireland', continentCode: 'europe', dialCode: '+353'),
    YellowPagesCountryOption(
        code: 'IL',
        name: 'Israel',
        continentCode: 'asia',
        isMiddleEast: true,
        isPopularOilGas: true,
        dialCode: '+972'),
    YellowPagesCountryOption(
        code: 'IT',
        name: 'Italy',
        continentCode: 'europe',
        isPopularOilGas: true,
        dialCode: '+39'),
    YellowPagesCountryOption(
        code: 'JM',
        name: 'Jamaica',
        continentCode: 'north_america',
        dialCode: '+1'),
    YellowPagesCountryOption(
        code: 'JP',
        name: 'Japan',
        continentCode: 'asia',
        isPopularOilGas: true,
        dialCode: '+81'),
    YellowPagesCountryOption(
        code: 'JO',
        name: 'Jordan',
        continentCode: 'asia',
        isMiddleEast: true,
        dialCode: '+962'),
    YellowPagesCountryOption(
        code: 'KZ',
        name: 'Kazakhstan',
        continentCode: 'asia',
        alsoEurope: true,
        isPopularOilGas: true,
        dialCode: '+7'),
    YellowPagesCountryOption(
        code: 'KE', name: 'Kenya', continentCode: 'africa', dialCode: '+254'),
    YellowPagesCountryOption(
        code: 'KI',
        name: 'Kiribati',
        continentCode: 'oceania',
        dialCode: '+686'),
    YellowPagesCountryOption(
        code: 'XK', name: 'Kosovo', continentCode: 'europe', dialCode: '+383'),
    YellowPagesCountryOption(
        code: 'KW',
        name: 'Kuwait',
        continentCode: 'asia',
        isMiddleEast: true,
        isPopularOilGas: true,
        dialCode: '+965'),
    YellowPagesCountryOption(
        code: 'KG',
        name: 'Kyrgyzstan',
        continentCode: 'asia',
        dialCode: '+996'),
    YellowPagesCountryOption(
        code: 'LA', name: 'Laos', continentCode: 'asia', dialCode: '+856'),
    YellowPagesCountryOption(
        code: 'LV', name: 'Latvia', continentCode: 'europe', dialCode: '+371'),
    YellowPagesCountryOption(
        code: 'LB',
        name: 'Lebanon',
        continentCode: 'asia',
        isMiddleEast: true,
        dialCode: '+961'),
    YellowPagesCountryOption(
        code: 'LS', name: 'Lesotho', continentCode: 'africa', dialCode: '+266'),
    YellowPagesCountryOption(
        code: 'LR', name: 'Liberia', continentCode: 'africa', dialCode: '+231'),
    YellowPagesCountryOption(
        code: 'LY',
        name: 'Libya',
        continentCode: 'africa',
        isPopularOilGas: true,
        dialCode: '+218'),
    YellowPagesCountryOption(
        code: 'LI',
        name: 'Liechtenstein',
        continentCode: 'europe',
        dialCode: '+423'),
    YellowPagesCountryOption(
        code: 'LT',
        name: 'Lithuania',
        continentCode: 'europe',
        dialCode: '+370'),
    YellowPagesCountryOption(
        code: 'LU',
        name: 'Luxembourg',
        continentCode: 'europe',
        dialCode: '+352'),
    YellowPagesCountryOption(
        code: 'MG',
        name: 'Madagascar',
        continentCode: 'africa',
        dialCode: '+261'),
    YellowPagesCountryOption(
        code: 'MW', name: 'Malawi', continentCode: 'africa', dialCode: '+265'),
    YellowPagesCountryOption(
        code: 'MY',
        name: 'Malaysia',
        continentCode: 'asia',
        isPopularOilGas: true,
        dialCode: '+60'),
    YellowPagesCountryOption(
        code: 'MV', name: 'Maldives', continentCode: 'asia', dialCode: '+960'),
    YellowPagesCountryOption(
        code: 'ML', name: 'Mali', continentCode: 'africa', dialCode: '+223'),
    YellowPagesCountryOption(
        code: 'MT', name: 'Malta', continentCode: 'europe', dialCode: '+356'),
    YellowPagesCountryOption(
        code: 'MH',
        name: 'Marshall Islands',
        continentCode: 'oceania',
        dialCode: '+692'),
    YellowPagesCountryOption(
        code: 'MR',
        name: 'Mauritania',
        continentCode: 'africa',
        dialCode: '+222'),
    YellowPagesCountryOption(
        code: 'MU',
        name: 'Mauritius',
        continentCode: 'africa',
        dialCode: '+230'),
    YellowPagesCountryOption(
        code: 'MX',
        name: 'Mexico',
        continentCode: 'north_america',
        isPopularOilGas: true,
        dialCode: '+52'),
    YellowPagesCountryOption(
        code: 'FM',
        name: 'Micronesia',
        continentCode: 'oceania',
        dialCode: '+691'),
    YellowPagesCountryOption(
        code: 'MD', name: 'Moldova', continentCode: 'europe', dialCode: '+373'),
    YellowPagesCountryOption(
        code: 'MC', name: 'Monaco', continentCode: 'europe', dialCode: '+377'),
    YellowPagesCountryOption(
        code: 'MN', name: 'Mongolia', continentCode: 'asia', dialCode: '+976'),
    YellowPagesCountryOption(
        code: 'ME',
        name: 'Montenegro',
        continentCode: 'europe',
        dialCode: '+382'),
    YellowPagesCountryOption(
        code: 'MA', name: 'Morocco', continentCode: 'africa', dialCode: '+212'),
    YellowPagesCountryOption(
        code: 'MZ',
        name: 'Mozambique',
        continentCode: 'africa',
        isPopularOilGas: true,
        dialCode: '+258'),
    YellowPagesCountryOption(
        code: 'MM', name: 'Myanmar', continentCode: 'asia', dialCode: '+95'),
    YellowPagesCountryOption(
        code: 'NA',
        name: 'Namibia',
        continentCode: 'africa',
        isPopularOilGas: true,
        dialCode: '+264'),
    YellowPagesCountryOption(
        code: 'NR', name: 'Nauru', continentCode: 'oceania', dialCode: '+674'),
    YellowPagesCountryOption(
        code: 'NP', name: 'Nepal', continentCode: 'asia', dialCode: '+977'),
    YellowPagesCountryOption(
        code: 'NL',
        name: 'Netherlands',
        continentCode: 'europe',
        isPopularOilGas: true,
        dialCode: '+31'),
    YellowPagesCountryOption(
        code: 'NZ',
        name: 'New Zealand',
        continentCode: 'oceania',
        isPopularOilGas: true,
        dialCode: '+64'),
    YellowPagesCountryOption(
        code: 'NI',
        name: 'Nicaragua',
        continentCode: 'north_america',
        dialCode: '+505'),
    YellowPagesCountryOption(
        code: 'NE', name: 'Niger', continentCode: 'africa', dialCode: '+227'),
    YellowPagesCountryOption(
        code: 'NG',
        name: 'Nigeria',
        continentCode: 'africa',
        isPopularOilGas: true,
        dialCode: '+234'),
    YellowPagesCountryOption(
        code: 'KP',
        name: 'North Korea',
        continentCode: 'asia',
        dialCode: '+850'),
    YellowPagesCountryOption(
        code: 'MK',
        name: 'North Macedonia',
        continentCode: 'europe',
        dialCode: '+389'),
    YellowPagesCountryOption(
        code: 'NO',
        name: 'Norway',
        continentCode: 'europe',
        isPopularOilGas: true,
        dialCode: '+47'),
    YellowPagesCountryOption(
        code: 'OM',
        name: 'Oman',
        continentCode: 'asia',
        isMiddleEast: true,
        isPopularOilGas: true,
        dialCode: '+968'),
    YellowPagesCountryOption(
        code: 'PK', name: 'Pakistan', continentCode: 'asia', dialCode: '+92'),
    YellowPagesCountryOption(
        code: 'PW', name: 'Palau', continentCode: 'oceania', dialCode: '+680'),
    YellowPagesCountryOption(
        code: 'PS',
        name: 'Palestine',
        continentCode: 'asia',
        isMiddleEast: true,
        dialCode: '+970'),
    YellowPagesCountryOption(
        code: 'PA',
        name: 'Panama',
        continentCode: 'north_america',
        dialCode: '+507'),
    YellowPagesCountryOption(
        code: 'PG',
        name: 'Papua New Guinea',
        continentCode: 'oceania',
        isPopularOilGas: true,
        dialCode: '+675'),
    YellowPagesCountryOption(
        code: 'PY',
        name: 'Paraguay',
        continentCode: 'south_america',
        dialCode: '+595'),
    YellowPagesCountryOption(
        code: 'PE',
        name: 'Peru',
        continentCode: 'south_america',
        isPopularOilGas: true,
        dialCode: '+51'),
    YellowPagesCountryOption(
        code: 'PH',
        name: 'Philippines',
        continentCode: 'asia',
        dialCode: '+63'),
    YellowPagesCountryOption(
        code: 'PL',
        name: 'Poland',
        continentCode: 'europe',
        isPopularOilGas: true,
        dialCode: '+48'),
    YellowPagesCountryOption(
        code: 'PT',
        name: 'Portugal',
        continentCode: 'europe',
        dialCode: '+351'),
    YellowPagesCountryOption(
        code: 'QA',
        name: 'Qatar',
        continentCode: 'asia',
        isMiddleEast: true,
        isPopularOilGas: true,
        dialCode: '+974'),
    YellowPagesCountryOption(
        code: 'RO',
        name: 'Romania',
        continentCode: 'europe',
        isPopularOilGas: true,
        dialCode: '+40'),
    YellowPagesCountryOption(
        code: 'RU',
        name: 'Russia',
        continentCode: 'europe',
        alsoAsia: true,
        dialCode: '+7'),
    YellowPagesCountryOption(
        code: 'RW', name: 'Rwanda', continentCode: 'africa', dialCode: '+250'),
    YellowPagesCountryOption(
        code: 'KN',
        name: 'Saint Kitts and Nevis',
        continentCode: 'north_america',
        dialCode: '+1'),
    YellowPagesCountryOption(
        code: 'LC',
        name: 'Saint Lucia',
        continentCode: 'north_america',
        dialCode: '+1'),
    YellowPagesCountryOption(
        code: 'VC',
        name: 'Saint Vincent and the Grenadines',
        continentCode: 'north_america',
        dialCode: '+1'),
    YellowPagesCountryOption(
        code: 'WS', name: 'Samoa', continentCode: 'oceania', dialCode: '+685'),
    YellowPagesCountryOption(
        code: 'SM',
        name: 'San Marino',
        continentCode: 'europe',
        dialCode: '+378'),
    YellowPagesCountryOption(
        code: 'ST',
        name: 'Sao Tome and Principe',
        continentCode: 'africa',
        dialCode: '+239'),
    YellowPagesCountryOption(
        code: 'SA',
        name: 'Saudi Arabia',
        continentCode: 'asia',
        isMiddleEast: true,
        isPopularOilGas: true,
        dialCode: '+966'),
    YellowPagesCountryOption(
        code: 'SN', name: 'Senegal', continentCode: 'africa', dialCode: '+221'),
    YellowPagesCountryOption(
        code: 'RS', name: 'Serbia', continentCode: 'europe', dialCode: '+381'),
    YellowPagesCountryOption(
        code: 'SC',
        name: 'Seychelles',
        continentCode: 'africa',
        dialCode: '+248'),
    YellowPagesCountryOption(
        code: 'SL',
        name: 'Sierra Leone',
        continentCode: 'africa',
        dialCode: '+232'),
    YellowPagesCountryOption(
        code: 'SG',
        name: 'Singapore',
        continentCode: 'asia',
        isPopularOilGas: true,
        dialCode: '+65'),
    YellowPagesCountryOption(
        code: 'SK',
        name: 'Slovakia',
        continentCode: 'europe',
        dialCode: '+421'),
    YellowPagesCountryOption(
        code: 'SI',
        name: 'Slovenia',
        continentCode: 'europe',
        dialCode: '+386'),
    YellowPagesCountryOption(
        code: 'SB',
        name: 'Solomon Islands',
        continentCode: 'oceania',
        dialCode: '+677'),
    YellowPagesCountryOption(
        code: 'SO', name: 'Somalia', continentCode: 'africa', dialCode: '+252'),
    YellowPagesCountryOption(
        code: 'ZA',
        name: 'South Africa',
        continentCode: 'africa',
        isPopularOilGas: true,
        dialCode: '+27'),
    YellowPagesCountryOption(
        code: 'KR',
        name: 'South Korea',
        continentCode: 'asia',
        isPopularOilGas: true,
        dialCode: '+82'),
    YellowPagesCountryOption(
        code: 'SS',
        name: 'South Sudan',
        continentCode: 'africa',
        dialCode: '+211'),
    YellowPagesCountryOption(
        code: 'ES',
        name: 'Spain',
        continentCode: 'europe',
        isPopularOilGas: true,
        dialCode: '+34'),
    YellowPagesCountryOption(
        code: 'LK', name: 'Sri Lanka', continentCode: 'asia', dialCode: '+94'),
    YellowPagesCountryOption(
        code: 'SD', name: 'Sudan', continentCode: 'africa', dialCode: '+249'),
    YellowPagesCountryOption(
        code: 'SR',
        name: 'Suriname',
        continentCode: 'south_america',
        isPopularOilGas: true,
        dialCode: '+597'),
    YellowPagesCountryOption(
        code: 'SE', name: 'Sweden', continentCode: 'europe', dialCode: '+46'),
    YellowPagesCountryOption(
        code: 'CH',
        name: 'Switzerland',
        continentCode: 'europe',
        isPopularOilGas: true,
        dialCode: '+41'),
    YellowPagesCountryOption(
        code: 'SY',
        name: 'Syria',
        continentCode: 'asia',
        isMiddleEast: true,
        dialCode: '+963'),
    YellowPagesCountryOption(
        code: 'TW', name: 'Taiwan', continentCode: 'asia', dialCode: '+886'),
    YellowPagesCountryOption(
        code: 'TJ',
        name: 'Tajikistan',
        continentCode: 'asia',
        dialCode: '+992'),
    YellowPagesCountryOption(
        code: 'TZ',
        name: 'Tanzania',
        continentCode: 'africa',
        dialCode: '+255'),
    YellowPagesCountryOption(
        code: 'TH', name: 'Thailand', continentCode: 'asia', dialCode: '+66'),
    YellowPagesCountryOption(
        code: 'TL',
        name: 'Timor-Leste',
        continentCode: 'asia',
        dialCode: '+670'),
    YellowPagesCountryOption(
        code: 'TG', name: 'Togo', continentCode: 'africa', dialCode: '+228'),
    YellowPagesCountryOption(
        code: 'TO', name: 'Tonga', continentCode: 'oceania', dialCode: '+676'),
    YellowPagesCountryOption(
        code: 'TT',
        name: 'Trinidad and Tobago',
        continentCode: 'north_america',
        isPopularOilGas: true,
        dialCode: '+1'),
    YellowPagesCountryOption(
        code: 'TN', name: 'Tunisia', continentCode: 'africa', dialCode: '+216'),
    YellowPagesCountryOption(
        code: 'TR',
        name: 'Turkey',
        continentCode: 'asia',
        alsoEurope: true,
        isMiddleEast: true,
        isPopularOilGas: true,
        dialCode: '+90'),
    YellowPagesCountryOption(
        code: 'TM',
        name: 'Turkmenistan',
        continentCode: 'asia',
        dialCode: '+993'),
    YellowPagesCountryOption(
        code: 'TV', name: 'Tuvalu', continentCode: 'oceania', dialCode: '+688'),
    YellowPagesCountryOption(
        code: 'UG', name: 'Uganda', continentCode: 'africa', dialCode: '+256'),
    YellowPagesCountryOption(
        code: 'UA', name: 'Ukraine', continentCode: 'europe', dialCode: '+380'),
    YellowPagesCountryOption(
        code: 'AE',
        name: 'United Arab Emirates',
        continentCode: 'asia',
        isMiddleEast: true,
        isPopularOilGas: true,
        dialCode: '+971'),
    YellowPagesCountryOption(
        code: 'GB',
        name: 'United Kingdom',
        continentCode: 'europe',
        isPopularOilGas: true,
        dialCode: '+44'),
    YellowPagesCountryOption(
        code: 'US',
        name: 'United States',
        continentCode: 'north_america',
        isPopularOilGas: true,
        dialCode: '+1'),
    YellowPagesCountryOption(
        code: 'UY',
        name: 'Uruguay',
        continentCode: 'south_america',
        dialCode: '+598'),
    YellowPagesCountryOption(
        code: 'UZ',
        name: 'Uzbekistan',
        continentCode: 'asia',
        dialCode: '+998'),
    YellowPagesCountryOption(
        code: 'VU',
        name: 'Vanuatu',
        continentCode: 'oceania',
        dialCode: '+678'),
    YellowPagesCountryOption(
        code: 'VA',
        name: 'Vatican City',
        continentCode: 'europe',
        dialCode: '+379'),
    YellowPagesCountryOption(
        code: 'VE',
        name: 'Venezuela',
        continentCode: 'south_america',
        dialCode: '+58'),
    YellowPagesCountryOption(
        code: 'VN',
        name: 'Vietnam',
        continentCode: 'asia',
        isPopularOilGas: true,
        dialCode: '+84'),
    YellowPagesCountryOption(
        code: 'YE',
        name: 'Yemen',
        continentCode: 'asia',
        isMiddleEast: true,
        dialCode: '+967'),
    YellowPagesCountryOption(
        code: 'ZM', name: 'Zambia', continentCode: 'africa', dialCode: '+260'),
    YellowPagesCountryOption(
        code: 'ZW',
        name: 'Zimbabwe',
        continentCode: 'africa',
        dialCode: '+263'),
  ];

  // Ordered Global Top Oil & Gas Quick-Search priority when Worldwide is selected
  static const _globalTopQuickOrder = <String>[
    'CA',
    'US',
    'MX',
    'GB',
    'DE',
    'NO',
    'AE',
    'SA',
    'AU',
    'IN',
    'NG',
    'BR',
    'AR',
    'NL',
    'IT',
    'TT',
    'QA',
    'SG',
    'MY',
    'GY',
    'CO',
    'KW',
    'OM',
    'EG',
  ];

  static const regions = <YellowPagesRegionOption>[
    // Canada
    YellowPagesRegionOption(
        countryCode: 'CA', regionCode: 'AB', name: 'Alberta'),
    YellowPagesRegionOption(
        countryCode: 'CA', regionCode: 'BC', name: 'British Columbia'),
    YellowPagesRegionOption(
        countryCode: 'CA', regionCode: 'SK', name: 'Saskatchewan'),
    YellowPagesRegionOption(
        countryCode: 'CA', regionCode: 'MB', name: 'Manitoba'),
    YellowPagesRegionOption(
        countryCode: 'CA', regionCode: 'ON', name: 'Ontario'),
    YellowPagesRegionOption(
        countryCode: 'CA', regionCode: 'QC', name: 'Quebec'),
    YellowPagesRegionOption(
        countryCode: 'CA', regionCode: 'NL', name: 'Newfoundland & Labrador'),
    YellowPagesRegionOption(
        countryCode: 'CA', regionCode: 'NS', name: 'Nova Scotia'),
    YellowPagesRegionOption(
        countryCode: 'CA', regionCode: 'NB', name: 'New Brunswick'),
    YellowPagesRegionOption(
        countryCode: 'CA', regionCode: 'PE', name: 'Prince Edward Island'),
    YellowPagesRegionOption(
        countryCode: 'CA', regionCode: 'NT', name: 'Northwest Territories'),
    YellowPagesRegionOption(countryCode: 'CA', regionCode: 'YT', name: 'Yukon'),
    YellowPagesRegionOption(
        countryCode: 'CA', regionCode: 'NU', name: 'Nunavut'),
    // USA
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'TX', name: 'Texas'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'ND', name: 'North Dakota'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'OK', name: 'Oklahoma'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'NM', name: 'New Mexico'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'WY', name: 'Wyoming'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'LA', name: 'Louisiana'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'PA', name: 'Pennsylvania'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'CO', name: 'Colorado'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'OH', name: 'Ohio'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'WV', name: 'West Virginia'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'AK', name: 'Alaska'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'CA', name: 'California'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'MT', name: 'Montana'),
    YellowPagesRegionOption(countryCode: 'US', regionCode: 'UT', name: 'Utah'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'KS', name: 'Kansas'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'AR', name: 'Arkansas'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'MS', name: 'Mississippi'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'IL', name: 'Illinois'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'IN', name: 'Indiana'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'KY', name: 'Kentucky'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'MI', name: 'Michigan'),
    YellowPagesRegionOption(
        countryCode: 'US', regionCode: 'AL', name: 'Alabama'),
    // Mexico & Trinidad
    YellowPagesRegionOption(
        countryCode: 'MX', regionCode: 'TAB', name: 'Tabasco (Villahermosa)'),
    YellowPagesRegionOption(
        countryCode: 'MX',
        regionCode: 'CAM',
        name: 'Campeche (Ciudad del Carmen)'),
    YellowPagesRegionOption(
        countryCode: 'MX',
        regionCode: 'TAM',
        name: 'Tamaulipas (Reynosa / Tampico)'),
    YellowPagesRegionOption(
        countryCode: 'MX', regionCode: 'VER', name: 'Veracruz (Poza Rica)'),
    YellowPagesRegionOption(
        countryCode: 'MX', regionCode: 'NL', name: 'Nuevo Leon (Monterrey)'),
    YellowPagesRegionOption(
        countryCode: 'MX', regionCode: 'CDMX', name: 'Ciudad de Mexico'),
    YellowPagesRegionOption(
        countryCode: 'TT',
        regionCode: 'SFO',
        name: 'San Fernando / Point Lisas'),
    YellowPagesRegionOption(
        countryCode: 'TT', regionCode: 'POS', name: 'Port of Spain'),
    // Europe (UK, Norway, Germany, Netherlands, Italy)
    YellowPagesRegionOption(
        countryCode: 'GB',
        regionCode: 'SCT',
        name: 'Scotland (Aberdeen / North Sea)'),
    YellowPagesRegionOption(
        countryCode: 'GB',
        regionCode: 'ENG',
        name: 'England (London / Great Yarmouth)'),
    YellowPagesRegionOption(
        countryCode: 'GB', regionCode: 'WLS', name: 'Wales (Milford Haven)'),
    YellowPagesRegionOption(
        countryCode: 'GB', regionCode: 'NIR', name: 'Northern Ireland'),
    YellowPagesRegionOption(
        countryCode: 'NO', regionCode: 'RO', name: 'Rogaland (Stavanger)'),
    YellowPagesRegionOption(
        countryCode: 'NO', regionCode: 'VL', name: 'Vestland (Bergen)'),
    YellowPagesRegionOption(
        countryCode: 'NO', regionCode: 'OS', name: 'Oslo / Akershus'),
    YellowPagesRegionOption(
        countryCode: 'NO',
        regionCode: 'TR',
        name: 'Troms & Finnmark (Hammerfest)'),
    YellowPagesRegionOption(
        countryCode: 'DE',
        regionCode: 'NI',
        name: 'Lower Saxony (Celle / Lingen)'),
    YellowPagesRegionOption(
        countryCode: 'DE', regionCode: 'NW', name: 'North Rhine-Westphalia'),
    YellowPagesRegionOption(
        countryCode: 'DE', regionCode: 'HH', name: 'Hamburg'),
    YellowPagesRegionOption(
        countryCode: 'DE', regionCode: 'BY', name: 'Bavaria (Munich)'),
    YellowPagesRegionOption(
        countryCode: 'NL', regionCode: 'ZH', name: 'South Holland (Rotterdam)'),
    YellowPagesRegionOption(
        countryCode: 'NL',
        regionCode: 'NH',
        name: 'North Holland (Den Helder / Amsterdam)'),
    YellowPagesRegionOption(
        countryCode: 'NL', regionCode: 'GR', name: 'Groningen / Drenthe'),
    YellowPagesRegionOption(
        countryCode: 'IT', regionCode: 'LOM', name: 'Lombardy (Milan)'),
    YellowPagesRegionOption(
        countryCode: 'IT', regionCode: 'EMR', name: 'Emilia-Romagna (Ravenna)'),
    // Middle East (UAE, Saudi Arabia, Qatar, Oman, Kuwait, Bahrain)
    YellowPagesRegionOption(
        countryCode: 'AE',
        regionCode: 'AZ',
        name: 'Abu Dhabi (Mussafah / Ruwais)'),
    YellowPagesRegionOption(countryCode: 'AE', regionCode: 'DU', name: 'Dubai'),
    YellowPagesRegionOption(
        countryCode: 'AE', regionCode: 'SH', name: 'Sharjah'),
    YellowPagesRegionOption(
        countryCode: 'AE', regionCode: 'FU', name: 'Fujairah'),
    YellowPagesRegionOption(
        countryCode: 'SA',
        regionCode: 'EP',
        name: 'Eastern Province (Dammam / Al Khobar)'),
    YellowPagesRegionOption(
        countryCode: 'SA', regionCode: 'RI', name: 'Riyadh'),
    YellowPagesRegionOption(
        countryCode: 'SA', regionCode: 'MK', name: 'Makkah / Yanbu / Jeddah'),
    YellowPagesRegionOption(countryCode: 'QA', regionCode: 'DA', name: 'Doha'),
    YellowPagesRegionOption(
        countryCode: 'QA', regionCode: 'RL', name: 'Al Khor / Ras Laffan'),
    YellowPagesRegionOption(
        countryCode: 'QA', regionCode: 'MS', name: 'Mesaieed'),
    YellowPagesRegionOption(
        countryCode: 'OM', regionCode: 'MA', name: 'Muscat'),
    YellowPagesRegionOption(
        countryCode: 'OM', regionCode: 'BN', name: 'Al Batinah (Sohar)'),
    YellowPagesRegionOption(
        countryCode: 'OM', regionCode: 'WU', name: 'Al Wusta (Duqm)'),
    YellowPagesRegionOption(
        countryCode: 'OM', regionCode: 'DA', name: 'Ad Dakhiliyah (Nizwa)'),
    YellowPagesRegionOption(
        countryCode: 'KW', regionCode: 'AH', name: 'Al Ahmadi / Shuaiba'),
    YellowPagesRegionOption(
        countryCode: 'KW', regionCode: 'KU', name: 'Kuwait City'),
    YellowPagesRegionOption(
        countryCode: 'BH', regionCode: 'CA', name: 'Manama / Sitra / Awali'),
    // South America (Brazil, Argentina, Colombia, Guyana)
    YellowPagesRegionOption(
        countryCode: 'BR',
        regionCode: 'RJ',
        name: 'Rio de Janeiro (Macae / Pre-Salt)'),
    YellowPagesRegionOption(
        countryCode: 'BR', regionCode: 'SP', name: 'Sao Paulo (Santos)'),
    YellowPagesRegionOption(
        countryCode: 'BR', regionCode: 'ES', name: 'Espirito Santo (Vitoria)'),
    YellowPagesRegionOption(countryCode: 'BR', regionCode: 'BA', name: 'Bahia'),
    YellowPagesRegionOption(
        countryCode: 'AR', regionCode: 'NQ', name: 'Neuquen (Vaca Muerta)'),
    YellowPagesRegionOption(
        countryCode: 'AR',
        regionCode: 'CH',
        name: 'Chubut (Comodoro Rivadavia)'),
    YellowPagesRegionOption(
        countryCode: 'AR', regionCode: 'BA', name: 'Buenos Aires'),
    YellowPagesRegionOption(
        countryCode: 'CO', regionCode: 'DC', name: 'Bogota D.C.'),
    YellowPagesRegionOption(
        countryCode: 'CO', regionCode: 'CAS', name: 'Casanare / Meta (Llanos)'),
    YellowPagesRegionOption(
        countryCode: 'CO',
        regionCode: 'SAN',
        name: 'Santander (Barrancabermeja)'),
    YellowPagesRegionOption(
        countryCode: 'GY',
        regionCode: 'DE',
        name: 'Demerara-Mahaica (Georgetown)'),
    // Australia & Asia-Pacific + Caspian
    YellowPagesRegionOption(
        countryCode: 'AU',
        regionCode: 'WA',
        name: 'Western Australia (Perth / Karratha)'),
    YellowPagesRegionOption(
        countryCode: 'AU',
        regionCode: 'QLD',
        name: 'Queensland (Brisbane / Surat)'),
    YellowPagesRegionOption(
        countryCode: 'AU',
        regionCode: 'NT',
        name: 'Northern Territory (Darwin)'),
    YellowPagesRegionOption(
        countryCode: 'AU',
        regionCode: 'SA',
        name: 'South Australia (Cooper Basin)'),
    YellowPagesRegionOption(
        countryCode: 'AU', regionCode: 'VIC', name: 'Victoria (Gippsland)'),
    YellowPagesRegionOption(
        countryCode: 'SG', regionCode: 'SGP', name: 'Central Singapore'),
    YellowPagesRegionOption(
        countryCode: 'SG', regionCode: 'JRG', name: 'Jurong & Tuas Marine'),
    YellowPagesRegionOption(
        countryCode: 'SG',
        regionCode: 'LYG',
        name: 'Loyang Offshore Supply Base'),
    YellowPagesRegionOption(
        countryCode: 'IN', regionCode: 'MH', name: 'Maharashtra (Mumbai)'),
    YellowPagesRegionOption(
        countryCode: 'IN',
        regionCode: 'GJ',
        name: 'Gujarat (Vadodara / Hazira)'),
    YellowPagesRegionOption(
        countryCode: 'IN', regionCode: 'AS', name: 'Assam (Duliajan)'),
    YellowPagesRegionOption(
        countryCode: 'IN',
        regionCode: 'AP',
        name: 'Andhra Pradesh (Kakinada / KG)'),
    YellowPagesRegionOption(
        countryCode: 'MY', regionCode: 'KUL', name: 'Kuala Lumpur'),
    YellowPagesRegionOption(
        countryCode: 'MY',
        regionCode: 'SLG',
        name: 'Selangor (Shah Alam / Klang)'),
    YellowPagesRegionOption(
        countryCode: 'MY', regionCode: 'SWK', name: 'Sarawak (Miri / Bintulu)'),
    YellowPagesRegionOption(
        countryCode: 'MY', regionCode: 'SBH', name: 'Sabah (Labuan / KK)'),
    YellowPagesRegionOption(
        countryCode: 'MY', regionCode: 'TRG', name: 'Terengganu (Kemaman)'),
    YellowPagesRegionOption(
        countryCode: 'MY',
        regionCode: 'JHR',
        name: 'Johor (Pasir Gudang / Pengerang)'),
    YellowPagesRegionOption(
        countryCode: 'ID', regionCode: 'JK', name: 'Jakarta'),
    YellowPagesRegionOption(
        countryCode: 'ID',
        regionCode: 'KI',
        name: 'East Kalimantan (Balikpapan)'),
    YellowPagesRegionOption(
        countryCode: 'ID', regionCode: 'KR', name: 'Riau Islands (Batam)'),
    YellowPagesRegionOption(
        countryCode: 'ID', regionCode: 'RIU', name: 'Riau (Duri / Pekanbaru)'),
    YellowPagesRegionOption(
        countryCode: 'ID',
        regionCode: 'JI',
        name: 'East Java (Surabaya / Cepu)'),
    YellowPagesRegionOption(
        countryCode: 'BN',
        regionCode: 'BEL',
        name: 'Belait (Kuala Belait / Seria)'),
    YellowPagesRegionOption(
        countryCode: 'BN',
        regionCode: 'BM',
        name: 'Brunei-Muara (Bandar Seri Begawan)'),
    YellowPagesRegionOption(
        countryCode: 'TH', regionCode: 'RYG', name: 'Rayong / Map Ta Phut'),
    YellowPagesRegionOption(
        countryCode: 'TH', regionCode: 'SKA', name: 'Songkhla Offshore Base'),
    YellowPagesRegionOption(
        countryCode: 'TH', regionCode: 'BKK', name: 'Bangkok'),
    YellowPagesRegionOption(
        countryCode: 'VN',
        regionCode: 'BRV',
        name: 'Ba Ria-Vung Tau (Offshore)'),
    YellowPagesRegionOption(
        countryCode: 'VN', regionCode: 'SGN', name: 'Ho Chi Minh City'),
    YellowPagesRegionOption(
        countryCode: 'KZ',
        regionCode: 'ATY',
        name: 'Atyrau (Tengiz / Kashagan)'),
    YellowPagesRegionOption(
        countryCode: 'KZ',
        regionCode: 'MAN',
        name: 'Mangystau (Aktau / Caspian)'),
    YellowPagesRegionOption(
        countryCode: 'KZ',
        regionCode: 'ZAP',
        name: 'West Kazakhstan (Uralsk / Aksai)'),
    YellowPagesRegionOption(
        countryCode: 'KZ', regionCode: 'ALA', name: 'Almaty'),
    YellowPagesRegionOption(
        countryCode: 'AZ',
        regionCode: 'BAK',
        name: 'Baku / Absheron (Sangachal)'),
    YellowPagesRegionOption(
        countryCode: 'AZ', regionCode: 'SMQ', name: 'Sumqayit'),
    // Africa (West, North, East & Southern Energy Basins)
    YellowPagesRegionOption(
        countryCode: 'NG',
        regionCode: 'RI',
        name: 'Rivers (Port Harcourt / Onne)'),
    YellowPagesRegionOption(countryCode: 'NG', regionCode: 'LA', name: 'Lagos'),
    YellowPagesRegionOption(
        countryCode: 'NG', regionCode: 'DE', name: 'Delta (Warri)'),
    YellowPagesRegionOption(
        countryCode: 'NG', regionCode: 'AK', name: 'Akwa Ibom (Eket)'),
    YellowPagesRegionOption(
        countryCode: 'NG', regionCode: 'FC', name: 'Abuja FCT'),
    YellowPagesRegionOption(
        countryCode: 'AO',
        regionCode: 'LUA',
        name: 'Luanda (Sonils / Offshore)'),
    YellowPagesRegionOption(
        countryCode: 'AO', regionCode: 'CAB', name: 'Cabinda (Malongo)'),
    YellowPagesRegionOption(
        countryCode: 'AO', regionCode: 'ZAI', name: 'Zaire (Soyo / LNG)'),
    YellowPagesRegionOption(
        countryCode: 'AO', regionCode: 'BGU', name: 'Benguela (Lobito)'),
    YellowPagesRegionOption(
        countryCode: 'EG',
        regionCode: 'CAI',
        name: 'Cairo (Maadi / New Cairo)'),
    YellowPagesRegionOption(
        countryCode: 'EG',
        regionCode: 'ALX',
        name: 'Alexandria (Mediterranean)'),
    YellowPagesRegionOption(
        countryCode: 'EG', regionCode: 'SUZ', name: 'Suez / Ain Sokhna'),
    YellowPagesRegionOption(
        countryCode: 'EG', regionCode: 'PTS', name: 'Port Said (East Med)'),
    YellowPagesRegionOption(
        countryCode: 'EG', regionCode: 'BA', name: 'Red Sea (Ras Gharib)'),
    YellowPagesRegionOption(
        countryCode: 'GH', regionCode: 'WP', name: 'Western Region (Takoradi)'),
    YellowPagesRegionOption(
        countryCode: 'GH',
        regionCode: 'AA',
        name: 'Greater Accra (Accra / Tema)'),
    YellowPagesRegionOption(
        countryCode: 'DZ',
        regionCode: 'OUA',
        name: 'Ouargla (Hassi Messaoud)'),
    YellowPagesRegionOption(
        countryCode: 'DZ', regionCode: 'ALG', name: 'Algiers'),
    YellowPagesRegionOption(
        countryCode: 'DZ', regionCode: 'ORA', name: 'Oran / Arzew'),
    YellowPagesRegionOption(
        countryCode: 'ZA',
        regionCode: 'WC',
        name: 'Western Cape (Cape Town / Saldanha)'),
    YellowPagesRegionOption(
        countryCode: 'ZA', regionCode: 'KZN', name: 'KwaZulu-Natal (Durban)'),
    YellowPagesRegionOption(
        countryCode: 'ZA',
        regionCode: 'GP',
        name: 'Gauteng (Johannesburg / Secunda)'),
    YellowPagesRegionOption(
        countryCode: 'NA', regionCode: 'ER', name: 'Erongo (Walvis Bay)'),
    YellowPagesRegionOption(
        countryCode: 'NA',
        regionCode: 'KA',
        name: 'Karas (Luderitz / Orange Basin)'),
    YellowPagesRegionOption(
        countryCode: 'NA', regionCode: 'KH', name: 'Khomas (Windhoek)'),
    YellowPagesRegionOption(
        countryCode: 'MZ', regionCode: 'MPM', name: 'Maputo'),
    YellowPagesRegionOption(
        countryCode: 'MZ',
        regionCode: 'CD',
        name: 'Cabo Delgado (Pemba / Rovuma)'),
    YellowPagesRegionOption(
        countryCode: 'GA',
        regionCode: 'OG',
        name: 'Ogooue-Maritime (Port-Gentil)'),
    YellowPagesRegionOption(
        countryCode: 'GA', regionCode: 'ES', name: 'Estuaire (Libreville)'),
    YellowPagesRegionOption(
        countryCode: 'CG', regionCode: 'PNR', name: 'Pointe-Noire'),
    YellowPagesRegionOption(
        countryCode: 'CI', regionCode: 'AB', name: 'Abidjan'),
    YellowPagesRegionOption(
        countryCode: 'SN', regionCode: 'DK', name: 'Dakar (Sangomar / GTA)'),
    YellowPagesRegionOption(
        countryCode: 'UG', regionCode: 'CMP', name: 'Kampala / Albertine'),
    YellowPagesRegionOption(
        countryCode: 'TZ', regionCode: 'DAR', name: 'Dar es Salaam'),
    YellowPagesRegionOption(
        countryCode: 'LY', regionCode: 'TB', name: 'Tripoli (Sirte Basin)'),
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
    'Gulf of Mexico / Sureste (MX)',
    'Burgos & Tampico-Misantla (MX)',
    'Columbus Basin (Trinidad)',
    'North Sea (UK & Norway)',
    'Norwegian & Barents Sea',
    'Caspian Basin',
    'Black Sea & Carpathian',
    'Eastern Mediterranean',
    'Middle East / Arabian Basin',
    'Mesopotamian Basin (Iraq)',
    'Guyana-Suriname Basin',
    'Brazil Pre-Salt (Santos & Campos)',
    'Vaca Muerta / Neuquen',
    'Llanos & Magdalena (Colombia)',
    'Talara & Oriente (Peru / Ecuador)',
    'West Africa / Niger Delta',
    'Lower Congo & Gulf of Guinea',
    'Hassi Messaoud & Berkine',
    'Gulf of Suez & Nile Delta',
    'Rovuma & Orange Basins',
    'North West Shelf / Carnarvon (AU)',
    'Cooper & Surat / Bowen (AU)',
    'Taranaki & Papuan Basins',
    'Southeast Asia / Borneo',
    'Mumbai High & KG Basin (India)',
    'Bohai / Tarim / Ordos',
  ];

  static const certifications = <String>[
    'COR / SECOR',
    'ISNetworld',
    'ComplyWorks',
    'Avetta',
    'ABSA',
    'Energy Safety Canada / H2S Alive',
    'IWCF / IADC WellSharp',
    'PEC SafeLand / Veriforce',
    'API Spec Q1 / Q2',
    'API Certified',
    'ISO 9001 / ISO 45001',
    'DNV Certified',
    'OPITO / IWCF',
    'Achilles / FPAL',
    'Aramco IKTVA / ADNOC ICV',
    'PETRONAS / NIOSH',
    'NCDMB / NIPEX',
    'MIGAS / BNSP',
    'CSA / CWB',
  ];

  static const oilfieldHubs =
      <({String city, String regionCode, String countryCode})>[
    // Canada Oilfield Town Index
    (city: 'Acheson', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Athabasca', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Blackfalds', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Bonnyville', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Brooks', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Calgary', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Camrose', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Clairmont', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Cold Lake', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Consort', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Dawson Creek', regionCode: 'BC', countryCode: 'CA'),
    (city: 'Devon', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Drayton Valley', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Drumheller', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Edmonton', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Edson', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Elk Point', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Estevan', regionCode: 'SK', countryCode: 'CA'),
    (city: 'Fairview', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Fort McMurray', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Fort Nelson', regionCode: 'BC', countryCode: 'CA'),
    (city: 'Fort Saskatchewan', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Fort St. John', regionCode: 'BC', countryCode: 'CA'),
    (city: 'Fox Creek', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Grande Cache', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Grande Prairie', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Grimshaw', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Hanna', regionCode: 'AB', countryCode: 'CA'),
    (city: 'High Level', regionCode: 'AB', countryCode: 'CA'),
    (city: 'High Prairie', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Hinton', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Innisfail', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Kindersley', regionCode: 'SK', countryCode: 'CA'),
    (city: 'Lac La Biche', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Lacombe', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Leduc', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Lethbridge', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Lloydminster', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Macklin', regionCode: 'SK', countryCode: 'CA'),
    (city: 'Manning', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Mayerthorpe', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Medicine Hat', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Moosomin', regionCode: 'SK', countryCode: 'CA'),
    (city: 'Nisku', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Olds', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Peace River', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Pincher Creek', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Ponoka', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Provost', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Rainbow Lake', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Red Deer', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Redwater', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Regina', regionCode: 'SK', countryCode: 'CA'),
    (city: 'Rimbey', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Rocky Mountain House', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Sarnia', regionCode: 'ON', countryCode: 'CA'),
    (city: 'Saskatoon', regionCode: 'SK', countryCode: 'CA'),
    (city: 'Sherwood Park', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Slave Lake', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Spruce Grove', regionCode: 'AB', countryCode: 'CA'),
    (city: "St. John's", regionCode: 'NL', countryCode: 'CA'),
    (city: 'Stettler', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Stony Plain', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Sundre', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Swan Hills', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Swift Current', regionCode: 'SK', countryCode: 'CA'),
    (city: 'Sylvan Lake', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Taber', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Three Hills', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Tumbler Ridge', regionCode: 'BC', countryCode: 'CA'),
    (city: 'Unity', regionCode: 'SK', countryCode: 'CA'),
    (city: 'Valleyview', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Vegreville', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Vermilion', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Virden', regionCode: 'MB', countryCode: 'CA'),
    (city: 'Wabasca', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Wainwright', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Wetaskiwin', regionCode: 'AB', countryCode: 'CA'),
    (city: 'Weyburn', regionCode: 'SK', countryCode: 'CA'),
    (city: 'Whitecourt', regionCode: 'AB', countryCode: 'CA'),
    // USA Oilfield Town Index
    (city: 'Abilene', regionCode: 'TX', countryCode: 'US'),
    (city: 'Alice', regionCode: 'TX', countryCode: 'US'),
    (city: 'Amarillo', regionCode: 'TX', countryCode: 'US'),
    (city: 'Anchorage', regionCode: 'AK', countryCode: 'US'),
    (city: 'Andrews', regionCode: 'TX', countryCode: 'US'),
    (city: 'Ardmore', regionCode: 'OK', countryCode: 'US'),
    (city: 'Artesia', regionCode: 'NM', countryCode: 'US'),
    (city: 'Bakersfield', regionCode: 'CA', countryCode: 'US'),
    (city: 'Beaumont', regionCode: 'TX', countryCode: 'US'),
    (city: 'Big Spring', regionCode: 'TX', countryCode: 'US'),
    (city: 'Billings', regionCode: 'MT', countryCode: 'US'),
    (city: 'Bossier City', regionCode: 'LA', countryCode: 'US'),
    (city: 'Brighton', regionCode: 'CO', countryCode: 'US'),
    (city: 'Broussard', regionCode: 'LA', countryCode: 'US'),
    (city: 'Butte', regionCode: 'MT', countryCode: 'US'),
    (city: 'Canonsburg', regionCode: 'PA', countryCode: 'US'),
    (city: 'Canton', regionCode: 'OH', countryCode: 'US'),
    (city: 'Carlsbad', regionCode: 'NM', countryCode: 'US'),
    (city: 'Casper', regionCode: 'WY', countryCode: 'US'),
    (city: 'Cheyenne', regionCode: 'WY', countryCode: 'US'),
    (city: 'Chickasha', regionCode: 'OK', countryCode: 'US'),
    (city: 'Corpus Christi', regionCode: 'TX', countryCode: 'US'),
    (city: 'Dallas', regionCode: 'TX', countryCode: 'US'),
    (city: 'Denver', regionCode: 'CO', countryCode: 'US'),
    (city: 'Dickinson', regionCode: 'ND', countryCode: 'US'),
    (city: 'Douglas', regionCode: 'WY', countryCode: 'US'),
    (city: 'Elk City', regionCode: 'OK', countryCode: 'US'),
    (city: 'Enid', regionCode: 'OK', countryCode: 'US'),
    (city: 'Evanston', regionCode: 'WY', countryCode: 'US'),
    (city: 'Farmington', regionCode: 'NM', countryCode: 'US'),
    (city: 'Fort Worth', regionCode: 'TX', countryCode: 'US'),
    (city: 'Gillette', regionCode: 'WY', countryCode: 'US'),
    (city: 'Grand Junction', regionCode: 'CO', countryCode: 'US'),
    (city: 'Great Bend', regionCode: 'KS', countryCode: 'US'),
    (city: 'Greeley', regionCode: 'CO', countryCode: 'US'),
    (city: 'Hobbs', regionCode: 'NM', countryCode: 'US'),
    (city: 'Houma', regionCode: 'LA', countryCode: 'US'),
    (city: 'Houston', regionCode: 'TX', countryCode: 'US'),
    (city: 'Kenai', regionCode: 'AK', countryCode: 'US'),
    (city: 'Kilgore', regionCode: 'TX', countryCode: 'US'),
    (city: 'Lafayette', regionCode: 'LA', countryCode: 'US'),
    (city: 'Lake Charles', regionCode: 'LA', countryCode: 'US'),
    (city: 'Laredo', regionCode: 'TX', countryCode: 'US'),
    (city: 'Longview', regionCode: 'TX', countryCode: 'US'),
    (city: 'Lovington', regionCode: 'NM', countryCode: 'US'),
    (city: 'Midland', regionCode: 'TX', countryCode: 'US'),
    (city: 'Minot', regionCode: 'ND', countryCode: 'US'),
    (city: 'Monahans', regionCode: 'TX', countryCode: 'US'),
    (city: 'Morgantown', regionCode: 'WV', countryCode: 'US'),
    (city: 'New Iberia', regionCode: 'LA', countryCode: 'US'),
    (city: 'Odessa', regionCode: 'TX', countryCode: 'US'),
    (city: 'Oklahoma City', regionCode: 'OK', countryCode: 'US'),
    (city: 'Pecos', regionCode: 'TX', countryCode: 'US'),
    (city: 'Pittsburgh', regionCode: 'PA', countryCode: 'US'),
    (city: 'Pleasanton', regionCode: 'TX', countryCode: 'US'),
    (city: 'Rawlins', regionCode: 'WY', countryCode: 'US'),
    (city: 'Rifle', regionCode: 'CO', countryCode: 'US'),
    (city: 'Rock Springs', regionCode: 'WY', countryCode: 'US'),
    (city: 'San Angelo', regionCode: 'TX', countryCode: 'US'),
    (city: 'San Antonio', regionCode: 'TX', countryCode: 'US'),
    (city: 'Shreveport', regionCode: 'LA', countryCode: 'US'),
    (city: 'Sidney', regionCode: 'MT', countryCode: 'US'),
    (city: 'Snyder', regionCode: 'TX', countryCode: 'US'),
    (city: 'Stanley', regionCode: 'ND', countryCode: 'US'),
    (city: 'Tioga', regionCode: 'ND', countryCode: 'US'),
    (city: 'Tulsa', regionCode: 'OK', countryCode: 'US'),
    (city: 'Tyler', regionCode: 'TX', countryCode: 'US'),
    (city: 'Vernal', regionCode: 'UT', countryCode: 'US'),
    (city: 'Victoria', regionCode: 'TX', countryCode: 'US'),
    (city: 'Washington', regionCode: 'PA', countryCode: 'US'),
    (city: 'Watford City', regionCode: 'ND', countryCode: 'US'),
    (city: 'Wichita', regionCode: 'KS', countryCode: 'US'),
    (city: 'Wichita Falls', regionCode: 'TX', countryCode: 'US'),
    (city: 'Wiggins', regionCode: 'CO', countryCode: 'US'),
    (city: 'Williamsport', regionCode: 'PA', countryCode: 'US'),
    (city: 'Williston', regionCode: 'ND', countryCode: 'US'),
    (city: 'Woodward', regionCode: 'OK', countryCode: 'US'),
    // International Oil & Gas Hub Cities across all 7 World Regions
    (city: 'Aberdeen', regionCode: 'SCT', countryCode: 'GB'),
    (city: 'Abidjan', regionCode: 'AB', countryCode: 'CI'),
    (city: 'Abu Dhabi', regionCode: 'AZ', countryCode: 'AE'),
    (city: 'Accra', regionCode: 'AA', countryCode: 'GH'),
    (city: 'Adelaide', regionCode: 'SA', countryCode: 'AU'),
    (city: 'Ahmadi', regionCode: 'AH', countryCode: 'KW'),
    (city: 'Aktau', regionCode: 'MAN', countryCode: 'KZ'),
    (city: 'Al Khobar', regionCode: 'EP', countryCode: 'SA'),
    (city: 'Alexandria', regionCode: 'ALX', countryCode: 'EG'),
    (city: 'Algiers', regionCode: 'ALG', countryCode: 'DZ'),
    (city: 'Almaty', regionCode: 'ALA', countryCode: 'KZ'),
    (city: 'Amman', regionCode: '', countryCode: 'JO'),
    (city: 'Amsterdam', regionCode: 'NH', countryCode: 'NL'),
    (city: 'Ankara', regionCode: '', countryCode: 'TR'),
    (city: 'Antwerp', regionCode: '', countryCode: 'BE'),
    (city: 'Athens', regionCode: '', countryCode: 'GR'),
    (city: 'Atyrau', regionCode: 'ATY', countryCode: 'KZ'),
    (city: 'Auckland', regionCode: '', countryCode: 'NZ'),
    (city: 'Baghdad', regionCode: '', countryCode: 'IQ'),
    (city: 'Baku', regionCode: 'BAK', countryCode: 'AZ'),
    (city: 'Balikpapan', regionCode: 'KI', countryCode: 'ID'),
    (city: 'Bandar Seri Begawan', regionCode: 'BM', countryCode: 'BN'),
    (city: 'Bangkok', regionCode: 'BKK', countryCode: 'TH'),
    (city: 'Barrancabermeja', regionCode: 'SAN', countryCode: 'CO'),
    (city: 'Basra', regionCode: '', countryCode: 'IQ'),
    (city: 'Batam', regionCode: 'KR', countryCode: 'ID'),
    (city: 'Beijing', regionCode: '', countryCode: 'CN'),
    (city: 'Bergen', regionCode: 'VL', countryCode: 'NO'),
    (city: 'Bilbao', regionCode: '', countryCode: 'ES'),
    (city: 'Bintulu', regionCode: 'SWK', countryCode: 'MY'),
    (city: 'Bogota', regionCode: 'DC', countryCode: 'CO'),
    (city: 'Bridgetown', regionCode: '', countryCode: 'BB'),
    (city: 'Brisbane', regionCode: 'QLD', countryCode: 'AU'),
    (city: 'Bucharest', regionCode: '', countryCode: 'RO'),
    (city: 'Buenos Aires', regionCode: 'BA', countryCode: 'AR'),
    (city: 'Cabinda', regionCode: 'CAB', countryCode: 'AO'),
    (city: 'Cairo', regionCode: 'CAI', countryCode: 'EG'),
    (city: 'Cape Town', regionCode: 'WC', countryCode: 'ZA'),
    (city: 'Cartagena', regionCode: '', countryCode: 'CO'),
    (city: 'Casablanca', regionCode: '', countryCode: 'MA'),
    (city: 'Celle', regionCode: 'NI', countryCode: 'DE'),
    (city: 'Chennai', regionCode: '', countryCode: 'IN'),
    (city: 'Ciudad del Carmen', regionCode: 'CAM', countryCode: 'MX'),
    (city: 'Comodoro Rivadavia', regionCode: 'CH', countryCode: 'AR'),
    (city: 'Constanta', regionCode: '', countryCode: 'RO'),
    (city: 'Copenhagen', regionCode: '', countryCode: 'DK'),
    (city: 'Dakar', regionCode: 'DK', countryCode: 'SN'),
    (city: 'Dammam', regionCode: 'EP', countryCode: 'SA'),
    (city: 'Dampier', regionCode: 'WA', countryCode: 'AU'),
    (city: 'Dar es Salaam', regionCode: 'DAR', countryCode: 'TZ'),
    (city: 'Darwin', regionCode: 'NT', countryCode: 'AU'),
    (city: 'Den Helder', regionCode: 'NH', countryCode: 'NL'),
    (city: 'Dhahran', regionCode: 'EP', countryCode: 'SA'),
    (city: 'Doha', regionCode: 'DA', countryCode: 'QA'),
    (city: 'Dubai', regionCode: 'DU', countryCode: 'AE'),
    (city: 'Duqm', regionCode: 'WU', countryCode: 'OM'),
    (city: 'Durban', regionCode: 'KZN', countryCode: 'ZA'),
    (city: 'Duri', regionCode: 'RIU', countryCode: 'ID'),
    (city: 'Dusseldorf', regionCode: 'NW', countryCode: 'DE'),
    (city: 'Erbil', regionCode: '', countryCode: 'IQ'),
    (city: 'Esbjerg', regionCode: '', countryCode: 'DK'),
    (city: 'Fujairah', regionCode: 'FU', countryCode: 'AE'),
    (city: 'Gdansk', regionCode: '', countryCode: 'PL'),
    (city: 'Geneva', regionCode: '', countryCode: 'CH'),
    (city: 'Georgetown', regionCode: 'DE', countryCode: 'GY'),
    (city: 'Gladstone', regionCode: 'QLD', countryCode: 'AU'),
    (city: 'Great Yarmouth', regionCode: 'ENG', countryCode: 'GB'),
    (city: 'Haifa', regionCode: '', countryCode: 'IL'),
    (city: 'Hamburg', regionCode: 'HH', countryCode: 'DE'),
    (city: 'Hammerfest', regionCode: 'TR', countryCode: 'NO'),
    (city: 'Hassi Messaoud', regionCode: 'OUA', countryCode: 'DZ'),
    (city: 'Haugesund', regionCode: 'RO', countryCode: 'NO'),
    (city: 'Ho Chi Minh City', regionCode: 'SGN', countryCode: 'VN'),
    (city: 'Istanbul', regionCode: '', countryCode: 'TR'),
    (city: 'Jakarta', regionCode: 'JK', countryCode: 'ID'),
    (city: 'Johannesburg', regionCode: 'GP', countryCode: 'ZA'),
    (city: 'Johor Bahru', regionCode: 'JHR', countryCode: 'MY'),
    (city: 'Jubail', regionCode: 'EP', countryCode: 'SA'),
    (city: 'Jurong', regionCode: 'JRG', countryCode: 'SG'),
    (city: 'Kakinada', regionCode: 'AP', countryCode: 'IN'),
    (city: 'Kampala', regionCode: 'CMP', countryCode: 'UG'),
    (city: 'Karachi', regionCode: '', countryCode: 'PK'),
    (city: 'Karratha', regionCode: 'WA', countryCode: 'AU'),
    (city: 'Kemaman', regionCode: 'TRG', countryCode: 'MY'),
    (city: 'Kingston', regionCode: '', countryCode: 'JM'),
    (city: 'Kota Kinabalu', regionCode: 'SBH', countryCode: 'MY'),
    (city: 'Kuala Belait', regionCode: 'BEL', countryCode: 'BN'),
    (city: 'Kuala Lumpur', regionCode: 'KUL', countryCode: 'MY'),
    (city: 'Kuwait City', regionCode: 'KU', countryCode: 'KW'),
    (city: 'Labuan', regionCode: 'SBH', countryCode: 'MY'),
    (city: 'Lagos', regionCode: 'LA', countryCode: 'NG'),
    (city: 'Libreville', regionCode: 'ES', countryCode: 'GA'),
    (city: 'Lima', regionCode: '', countryCode: 'PE'),
    (city: 'Lingen', regionCode: 'NI', countryCode: 'DE'),
    (city: 'London', regionCode: 'ENG', countryCode: 'GB'),
    (city: 'Loyang', regionCode: 'LYG', countryCode: 'SG'),
    (city: 'Luanda', regionCode: 'LUA', countryCode: 'AO'),
    (city: 'Macae', regionCode: 'RJ', countryCode: 'BR'),
    (city: 'Madrid', regionCode: '', countryCode: 'ES'),
    (city: 'Malabo', regionCode: '', countryCode: 'GQ'),
    (city: 'Manama', regionCode: 'CA', countryCode: 'BH'),
    (city: 'Manila', regionCode: '', countryCode: 'PH'),
    (city: 'Maputo', regionCode: 'MPM', countryCode: 'MZ'),
    (city: 'Marseille', regionCode: '', countryCode: 'FR'),
    (city: 'Melbourne', regionCode: 'VIC', countryCode: 'AU'),
    (city: 'Mesaieed', regionCode: 'MS', countryCode: 'QA'),
    (city: 'Mexico City', regionCode: 'CDMX', countryCode: 'MX'),
    (city: 'Milan', regionCode: 'LOM', countryCode: 'IT'),
    (city: 'Miri', regionCode: 'SWK', countryCode: 'MY'),
    (city: 'Monterrey', regionCode: 'NL', countryCode: 'MX'),
    (city: 'Montevideo', regionCode: '', countryCode: 'UY'),
    (city: 'Mumbai', regionCode: 'MH', countryCode: 'IN'),
    (city: 'Munich', regionCode: 'BY', countryCode: 'DE'),
    (city: 'Muscat', regionCode: 'MA', countryCode: 'OM'),
    (city: 'Mussafah', regionCode: 'AZ', countryCode: 'AE'),
    (city: 'Nairobi', regionCode: '', countryCode: 'KE'),
    (city: 'Nassau', regionCode: '', countryCode: 'BS'),
    (city: 'Neuquen', regionCode: 'NQ', countryCode: 'AR'),
    (city: 'New Delhi', regionCode: '', countryCode: 'IN'),
    (city: 'New Plymouth', regionCode: '', countryCode: 'NZ'),
    (city: 'Onne', regionCode: 'RI', countryCode: 'NG'),
    (city: 'Oran', regionCode: 'ORA', countryCode: 'DZ'),
    (city: 'Oslo', regionCode: 'OS', countryCode: 'NO'),
    (city: 'Panama City', regionCode: '', countryCode: 'PA'),
    (city: 'Paramaribo', regionCode: '', countryCode: 'SR'),
    (city: 'Paris', regionCode: '', countryCode: 'FR'),
    (city: 'Pau', regionCode: '', countryCode: 'FR'),
    (city: 'Pemba', regionCode: 'CD', countryCode: 'MZ'),
    (city: 'Perth', regionCode: 'WA', countryCode: 'AU'),
    (city: 'Peterhead', regionCode: 'SCT', countryCode: 'GB'),
    (city: 'Piraeus', regionCode: '', countryCode: 'GR'),
    (city: 'Ploiesti', regionCode: '', countryCode: 'RO'),
    (city: 'Point Lisas', regionCode: 'SFO', countryCode: 'TT'),
    (city: 'Pointe-Noire', regionCode: 'PNR', countryCode: 'CG'),
    (city: 'Port Harcourt', regionCode: 'RI', countryCode: 'NG'),
    (city: 'Port Moresby', regionCode: '', countryCode: 'PG'),
    (city: 'Port Said', regionCode: 'PTS', countryCode: 'EG'),
    (city: 'Port of Spain', regionCode: 'POS', countryCode: 'TT'),
    (city: 'Port-Gentil', regionCode: 'OG', countryCode: 'GA'),
    (city: 'Poza Rica', regionCode: 'VER', countryCode: 'MX'),
    (city: 'Quito', regionCode: '', countryCode: 'EC'),
    (city: 'Ras Laffan', regionCode: 'RL', countryCode: 'QA'),
    (city: 'Ravenna', regionCode: 'EMR', countryCode: 'IT'),
    (city: 'Rayong', regionCode: 'RYG', countryCode: 'TH'),
    (city: 'Reynosa', regionCode: 'TAM', countryCode: 'MX'),
    (city: 'Rio de Janeiro', regionCode: 'RJ', countryCode: 'BR'),
    (city: 'Riyadh', regionCode: 'RI', countryCode: 'SA'),
    (city: 'Roma', regionCode: 'QLD', countryCode: 'AU'),
    (city: 'Rome', regionCode: '', countryCode: 'IT'),
    (city: 'Rotterdam', regionCode: 'ZH', countryCode: 'NL'),
    (city: 'Ruwais', regionCode: 'AZ', countryCode: 'AE'),
    (city: 'San Fernando', regionCode: 'SFO', countryCode: 'TT'),
    (city: 'Santa Cruz de la Sierra', regionCode: '', countryCode: 'BO'),
    (city: 'Santiago', regionCode: '', countryCode: 'CL'),
    (city: 'Sao Paulo', regionCode: 'SP', countryCode: 'BR'),
    (city: 'Seoul', regionCode: '', countryCode: 'KR'),
    (city: 'Shah Alam', regionCode: 'SLG', countryCode: 'MY'),
    (city: 'Shanghai', regionCode: '', countryCode: 'CN'),
    (city: 'Sharjah', regionCode: 'SH', countryCode: 'AE'),
    (city: 'Shenzhen', regionCode: '', countryCode: 'CN'),
    (city: 'Singapore', regionCode: 'SGP', countryCode: 'SG'),
    (city: 'Sohar', regionCode: 'BN', countryCode: 'OM'),
    (city: 'Songkhla', regionCode: 'SKA', countryCode: 'TH'),
    (city: 'Soyo', regionCode: 'ZAI', countryCode: 'AO'),
    (city: 'Stavanger', regionCode: 'RO', countryCode: 'NO'),
    (city: 'Suez', regionCode: 'SUZ', countryCode: 'EG'),
    (city: 'Surabaya', regionCode: 'JI', countryCode: 'ID'),
    (city: 'Takoradi', regionCode: 'WP', countryCode: 'GH'),
    (city: 'Talara', regionCode: '', countryCode: 'PE'),
    (city: 'Tampico', regionCode: 'TAM', countryCode: 'MX'),
    (city: 'Tel Aviv', regionCode: '', countryCode: 'IL'),
    (city: 'Tema', regionCode: 'AA', countryCode: 'GH'),
    (city: 'Tianjin', regionCode: '', countryCode: 'CN'),
    (city: 'Tokyo', regionCode: '', countryCode: 'JP'),
    (city: 'Tripoli', regionCode: 'TB', countryCode: 'LY'),
    (city: 'Tuas', regionCode: 'JRG', countryCode: 'SG'),
    (city: 'Tunis', regionCode: '', countryCode: 'TN'),
    (city: 'Ulsan', regionCode: '', countryCode: 'KR'),
    (city: 'Uralsk', regionCode: 'ZAP', countryCode: 'KZ'),
    (city: 'Vadodara', regionCode: 'GJ', countryCode: 'IN'),
    (city: 'Veracruz', regionCode: 'VER', countryCode: 'MX'),
    (city: 'Vienna', regionCode: '', countryCode: 'AT'),
    (city: 'Villahermosa', regionCode: 'TAB', countryCode: 'MX'),
    (city: 'Vitoria', regionCode: 'ES', countryCode: 'BR'),
    (city: 'Vung Tau', regionCode: 'BRV', countryCode: 'VN'),
    (city: 'Walvis Bay', regionCode: 'ER', countryCode: 'NA'),
    (city: 'Warri', regionCode: 'DE', countryCode: 'NG'),
    (city: 'Warsaw', regionCode: '', countryCode: 'PL'),
    (city: 'Windhoek', regionCode: 'KH', countryCode: 'NA'),
    (city: 'Yanbu', regionCode: 'MK', countryCode: 'SA'),
    (city: 'Yopal', regionCode: 'CAS', countryCode: 'CO'),
    (city: 'Zurich', regionCode: '', countryCode: 'CH'),
  ];

  /// Formats a provider's location cleanly across both North American and
  /// international countries (e.g., `Nisku, AB` or `Aberdeen, SCT • UK` or `Doha, Qatar`).
  static String formatLocationLabel({
    required String city,
    required String regionCode,
    required String countryCode,
    bool includeCountryForNorthAmerica = false,
  }) {
    final cleanCity = city.trim();
    final cleanRegion = regionCode.trim();
    final cleanCountry = countryCode.trim().toUpperCase();
    final countryMeta = countryByCode(cleanCountry);
    final shortCountryName = switch (cleanCountry) {
      'AE' => 'UAE',
      'GB' => 'UK',
      'US' => 'USA',
      'TT' => 'Trinidad & Tobago',
      _ => countryMeta?.name ?? cleanCountry,
    };

    if (cleanCountry == 'CA' || cleanCountry == 'US') {
      final parts = <String>[
        if (cleanCity.isNotEmpty) cleanCity,
        if (cleanRegion.isNotEmpty) cleanRegion,
        if ((includeCountryForNorthAmerica ||
                (cleanCity.isEmpty && cleanRegion.isEmpty)) &&
            shortCountryName.isNotEmpty)
          shortCountryName,
      ];
      return parts.join(', ');
    }

    final parts = <String>[
      if (cleanCity.isNotEmpty) cleanCity,
      if (cleanRegion.isNotEmpty &&
          cleanRegion.toUpperCase() != cleanCountry &&
          cleanRegion.toLowerCase() != shortCountryName.toLowerCase() &&
          cleanRegion.toLowerCase() != cleanCity.toLowerCase())
        cleanRegion,
      if (shortCountryName.isNotEmpty &&
          shortCountryName.toLowerCase() != cleanCity.toLowerCase())
        shortCountryName,
    ];
    return parts.join(', ');
  }

  static YellowPagesContinentOption? continentByCode(String code) {
    final norm = code.trim().toLowerCase();
    for (final item in continents) {
      if (item.code == norm) return item;
    }
    return null;
  }

  static YellowPagesCountryOption? countryByCode(String code) {
    final norm = code.trim().toUpperCase();
    for (final item in countries) {
      if (item.code == norm) return item;
    }
    return null;
  }

  static bool _matchesContinent(
      YellowPagesCountryOption c, String continentCode) {
    if (continentCode.isEmpty) return true;
    if (continentCode == 'middle_east') return c.isMiddleEast;
    if (c.continentCode == continentCode) return true;
    if (continentCode == 'asia' && c.alsoAsia) return true;
    if (continentCode == 'europe' && c.alsoEurope) return true;
    return false;
  }

  /// Complete alphabetical (A-Z) list of countries for the given continent
  /// (or all 197 worldwide when empty). Popular Oil & Gas countries remain in
  /// their exact alphabetical position here as well as in the Quick-Search strip.
  static List<YellowPagesCountryOption> countriesForContinent(
      String continentCode) {
    final norm = continentCode.trim().toLowerCase();
    final filtered =
        countries.where((c) => _matchesContinent(c, norm)).toList();
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(filtered);
  }

  /// Popular Oil & Gas Quick-Search countries pinned at the top of the selector.
  static List<YellowPagesCountryOption> popularCountriesForContinent(
    String continentCode,
  ) {
    final norm = continentCode.trim().toLowerCase();
    if (norm.isEmpty) {
      final result = <YellowPagesCountryOption>[];
      for (final code in _globalTopQuickOrder) {
        final match = countryByCode(code);
        if (match != null) result.add(match);
      }
      return List.unmodifiable(result);
    }
    final filtered = countries
        .where((c) => c.isPopularOilGas && _matchesContinent(c, norm))
        .toList();
    // Put Canada & United States first inside North America quick search
    if (norm == 'north_america') {
      const naPriority = ['CA', 'US', 'MX', 'TT'];
      filtered.sort((a, b) {
        final ia = naPriority.indexOf(a.code);
        final ib = naPriority.indexOf(b.code);
        if (ia != -1 && ib != -1) return ia.compareTo(ib);
        if (ia != -1) return -1;
        if (ib != -1) return 1;
        return a.name.compareTo(b.name);
      });
    } else {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    }
    return List.unmodifiable(filtered);
  }

  static List<({String city, String regionCode, String countryCode})>
      hubsForLocation({
    String continentCode = '',
    String countryCode = '',
    String regionCode = '',
  }) {
    final cont = continentCode.trim().toLowerCase();
    final c = countryCode.trim().toUpperCase();
    final r = regionCode.trim().toUpperCase();
    final allowedCountries = cont.isEmpty
        ? null
        : countriesForContinent(cont).map((item) => item.code).toSet();
    final filtered = oilfieldHubs.where((hub) {
      if (allowedCountries != null &&
          !allowedCountries.contains(hub.countryCode)) {
        return false;
      }
      if (c.isNotEmpty && hub.countryCode != c) return false;
      if (r.isNotEmpty && hub.regionCode != r) return false;
      return true;
    }).toList();
    filtered.sort((a, b) => a.city.compareTo(b.city));
    return List.unmodifiable(filtered);
  }

  /// Converts long category strings into crisp, non-truncated card badges
  /// while keeping full category names inside the Service dropdown & detail sheet.
  static String conciseCategoryLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    for (final cat in categories) {
      if (cat.label.toLowerCase() == lower || cat.code == lower) {
        return cat.shortLabel;
      }
    }
    if (lower == 'trucking, winch & heavy haul') {
      return 'Trucking, Towing & Winch';
    }
    return trimmed;
  }

  static IconData iconForCategory(String code) {
    switch (code) {
      case 'trucking_heavy_haul':
        return Icons.local_shipping_outlined;
      case 'vacuum_hydrovac_fluid':
        return Icons.water_drop_outlined;
      case 'hotshot_pilot_logistics':
        return Icons.speed_outlined;
      case 'crane_picker_rigging':
        return Icons.construction_outlined;
      case 'pipe_octg_supply':
        return Icons.plumbing_outlined;
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
      case 'oil_gas_training_courses':
        return Icons.school_outlined;
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
    return regions
        .where((r) => r.countryCode == normalized)
        .toList(growable: false);
  }
}
