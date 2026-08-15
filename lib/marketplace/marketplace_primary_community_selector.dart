import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'industrial_icon_assets.dart';
import 'marketplace_location.dart';
import 'marketplace_location_picker.dart';
import 'marketplace_profile_community.dart';
import 'open_address_autocomplete.dart';

class MarketplacePrimaryCommunitySelector extends StatelessWidget {
  const MarketplacePrimaryCommunitySelector({
    super.key,
    required this.selected,
    required this.initialQuery,
    required this.enabled,
    required this.onQueryChanged,
    required this.onSelected,
  });

  final MarketplaceLocation? selected;
  final String initialQuery;
  final bool enabled;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<MarketplaceLocation> onSelected;

  @override
  Widget build(BuildContext context) {
    final location = selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OpenAddressAutocomplete(
          initialValue: initialQuery,
          enabled: enabled,
          label: 'Primary community or operating area',
          hint: 'Start typing a city, town, municipality, or county',
          searchType: OpenAddressSearchType.settlement,
          onChanged: onQueryChanged,
          onSelected: (address) =>
              onSelected(marketplaceCommunityFromOpenAddress(address)),
        ),
        const SizedBox(height: 10),
        if (location == null)
          const _CommunitySelectionNotice()
        else
          _SelectedCommunityCard(
            location: location,
            enabled: enabled,
            onMapSelected: onSelected,
          ),
      ],
    );
  }
}

class _CommunitySelectionNotice extends StatelessWidget {
  const _CommunitySelectionNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PipeBuyerColors.orangeSoft,
          border: Border.all(
            color: PipeBuyerColors.orange.withValues(alpha: .28),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 42,
              child: IndustrialAssetIcon(
                label: 'Map location pin',
                assetPath: IndustrialIconAssets.locationPin,
                size: 42,
                borderRadius: 10,
                fallback: Icon(
                  Icons.location_searching,
                  color: PipeBuyerColors.orangePressed,
                ),
              ),
            ),
            SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirm a marketplace location',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Choose an address prediction or confirm a pin on the map. Typed text alone is not stored as a marketplace location.',
                    style: TextStyle(fontSize: 12.5, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SelectedCommunityCard extends StatelessWidget {
  const _SelectedCommunityCard({
    required this.location,
    required this.enabled,
    required this.onMapSelected,
  });

  final MarketplaceLocation location;
  final bool enabled;
  final ValueChanged<MarketplaceLocation> onMapSelected;

  @override
  Widget build(BuildContext context) {
    final secondary = [location.region, location.country]
        .where((part) => part.trim().isNotEmpty)
        .join(' • ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PipeBuyerColors.success.withValues(alpha: .30),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final artwork = Container(
            width: compact ? 64 : 78,
            height: compact ? 64 : 78,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: PipeBuyerColors.ink,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const IndustrialAssetIcon(
              label: 'Primary community location',
              assetPath: IndustrialIconAssets.routeMap,
              size: 66,
              borderRadius: 10,
              fallback: Icon(
                Icons.map_outlined,
                color: Colors.white,
                size: 34,
              ),
            ),
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PRIMARY MARKETPLACE AREA',
                      style: TextStyle(
                        color: PipeBuyerColors.orangePressed,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .65,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.success.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: PipeBuyerColors.success,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'PIN CONFIRMED',
                          style: TextStyle(
                            color: PipeBuyerColors.success,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                primaryCommunityLabel(location),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (secondary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  secondary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .62),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: PipeBuyerColors.industrialBlue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Exact coordinates stay private. Pipe Buyer uses the approximate community for nearby results, discovery, and service-area matching.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: !enabled
                    ? null
                    : () async {
                        final selected =
                            await MarketplaceLocationPicker.showCommunity(
                          context,
                          location,
                        );
                        if (selected != null) {
                          onMapSelected(
                            normalizePrimaryCommunityLocation(selected),
                          );
                        }
                      },
                icon: const Icon(Icons.map_outlined),
                label: const Text('Check or adjust map pin'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                artwork,
                const SizedBox(height: 12),
                details,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              artwork,
              const SizedBox(width: 14),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}
