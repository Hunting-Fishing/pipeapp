import 'marketplace_location.dart';
import 'open_address_autocomplete.dart';

String primaryCommunityLabel(MarketplaceLocation location) {
  final publicName = location.publicName.trim();
  if (publicName.isNotEmpty) return publicName;
  final townRegion = [location.nearestTown.trim(), location.region.trim()]
      .where((part) => part.isNotEmpty)
      .join(', ');
  return townRegion.isEmpty ? 'Primary community' : townRegion;
}

MarketplaceLocation normalizePrimaryCommunityLocation(
  MarketplaceLocation location,
) =>
    MarketplaceLocation(
      point: location.point,
      visibility: LocationVisibility.approximate,
      publicName: primaryCommunityLabel(location),
      address: location.address,
      nearestTown: location.nearestTown,
      accessNotes: location.accessNotes,
      region: location.region,
      postalCode: location.postalCode,
      country: location.country,
    );

Map<String, dynamic> primaryCommunityPrivateData(
  MarketplaceLocation location,
  String ownerUid,
) =>
    normalizePrimaryCommunityLocation(location).privateData(ownerUid);

Map<String, dynamic> primaryCommunityPublicData(
  MarketplaceLocation location,
) =>
    normalizePrimaryCommunityLocation(location).publicData();

MarketplaceLocation marketplaceCommunityFromOpenAddress(OpenAddress address) {
  final town = address.city.trim().isNotEmpty
      ? address.city.trim()
      : address.label.split(',').first.trim();
  final publicName = [town, address.region.trim()]
      .where((part) => part.isNotEmpty)
      .join(', ');
  return normalizePrimaryCommunityLocation(
    MarketplaceLocation(
      point: address.point,
      visibility: LocationVisibility.approximate,
      publicName: publicName.isEmpty ? address.label.trim() : publicName,
      address: address.label.trim(),
      nearestTown: town,
      region: address.region.trim(),
      postalCode: address.postalCode.trim(),
      country: address.country.trim(),
    ),
  );
}
