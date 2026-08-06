import 'package:flutter/material.dart';

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
        const SizedBox(height: 8),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E5),
          border: Border.all(color: const Color(0xFFFFC46B)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_searching, color: Color(0xFFE56F00)),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Choose a prediction or confirm a pin on the map. Typed text alone is not stored as a marketplace location.',
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
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFEAF4FD),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: Color(0xFF0878E8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      primaryCommunityLabel(location),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Color(0xFF148A55)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [location.region, location.country]
                    .where((part) => part.trim().isNotEmpty)
                    .join(' • '),
                style: const TextStyle(color: Color(0xFF58697E)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Coordinates selected • exact pin private • approximate area used for nearby results and listing discovery',
                style: TextStyle(fontSize: 12, color: Color(0xFF315A7D)),
              ),
              const SizedBox(height: 8),
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
          ),
        ),
      );
}
