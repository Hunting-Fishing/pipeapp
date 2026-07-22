import 'package:intl/intl.dart';

const propertyAreaUnits = <String>[
  'Acres',
  'Hectares',
  'Square feet',
  'Square metres',
];

const propertyBuildingAreaUnits = <String>[
  'Square feet',
  'Square metres',
];

const propertyInterestOptions = <String>[
  'Freehold / fee simple',
  'Freehold with active lease(s)',
  'Leasehold interest',
  'Oil and gas lease',
  'Surface rights',
  'Mineral rights',
  'Easement / right-of-way',
  'Business interest',
  'Other interest',
];

const propertyOfferingOptions = <String>[
  'Land only',
  'Land and buildings',
  'Business and property',
  'Business only',
  'Assets and goodwill',
  'Lease or tenancy interest',
  'Rights or royalty interest',
];

const propertyFeatureOptions = <String>[
  'Power',
  'Water',
  'Natural gas',
  'Sewer / septic',
  'All-season road access',
  'Rail access',
  'Fenced / gated',
  'Buildings included',
  'Equipment included',
  'Income producing',
  'Active lease(s)',
  'Environmental reports',
];

const propertyProductTypeDescriptions = <String, String>{
  'Access Road':
      'Private or industrial access roads, road allowances and access interests.',
  'Battery Site':
      'Producing or inactive battery sites, land interests and site improvements.',
  'Business for Sale':
      'Operating businesses, assets, goodwill and optional real property.',
  'Commercial Property':
      'Shops, offices, mixed-use buildings and income-producing commercial sites.',
  'Farm & Ranch Land':
      'Agricultural land, farm sites, ranches and land with surface leases.',
  'Fenced Yard':
      'Secured industrial yards with access, services and optional buildings.',
  'Gate': 'Controlled-access gates and associated land or access interests.',
  'Industrial Real Estate':
      'Industrial buildings, shops, service yards and investment property.',
  'Lease Land':
      'Land offered with an existing lease or land available for lease.',
  'Mineral Rights':
      'Mineral interests, royalties and related subsurface rights.',
  'Oil & Gas Lease':
      'Oil and gas lease interests, royalties and producing or prospective land.',
  'Pipeline':
      'Pipeline assets, corridors, easements and right-of-way interests.',
  'Storage Yard':
      'Outdoor storage yards, laydown areas and serviced industrial lots.',
  'Surface Rights':
      'Surface leases, rights-of-way and other registered surface interests.',
  'Well Site':
      'Producing, suspended or reclaimed well sites and associated interests.',
};

double? propertyNumber(String value) {
  final clean = value.replaceAll(RegExp(r'[^0-9.]'), '');
  if (clean.isEmpty) return null;
  return double.tryParse(clean);
}

class PropertyAreaConversion {
  const PropertyAreaConversion({this.acres, this.hectares});

  final double? acres;
  final double? hectares;

  bool get hasLandMeasure => acres != null && hectares != null;
}

PropertyAreaConversion convertPropertyArea(num? value, String unit) {
  if (value == null || value <= 0) return const PropertyAreaConversion();
  switch (unit) {
    case 'Acres':
      return PropertyAreaConversion(
          acres: value.toDouble(), hectares: value / 2.4710538147);
    case 'Hectares':
      return PropertyAreaConversion(
          acres: value * 2.4710538147, hectares: value.toDouble());
    default:
      return const PropertyAreaConversion();
  }
}

final NumberFormat _propertyMeasureFormat = NumberFormat('#,##0.##', 'en_CA');

String propertyMeasure(num value) => _propertyMeasureFormat.format(value);
