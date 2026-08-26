/// Exact photographic artwork used by Marketplace category/product selectors.
///
/// These assets are deliberately separate from [IndustrialIconAssets].
/// Dispatch, messaging, administration, and other shared UI continue using
/// the general industrial artwork package.
///
/// Marketplace product resolution uses both category and product type so
/// ambiguous labels such as "Generator" and "Other / not listed" cannot
/// accidentally select artwork from the wrong catalog family.
abstract final class MarketplaceCatalogPhotoAssets {
  static const root =
      'assets/images/industrial_icons/26-marketplace-catalog-photos';

  static const Set<String> allAssetPaths = {
    '$root/air-compressor.svg',
    '$root/backhoe.svg',
    '$root/bale-feeder.svg',
    '$root/bathroom-unit.svg',
    '$root/boom-lift.svg',
    '$root/buffalo-bison-panel.svg',
    '$root/bulldozer.svg',
    '$root/casing.svg',
    '$root/cattle-panel.svg',
    '$root/chemical-tank.svg',
    '$root/compactor.svg',
    '$root/container-office.svg',
    '$root/continuous-fence.svg',
    '$root/corral-panel.svg',
    '$root/crane.svg',
    '$root/crew-shack.svg',
    '$root/custom-pipe-fabrication.svg',
    '$root/drilling-rig.svg',
    '$root/drill-pipe.svg',
    '$root/drill-stem.svg',
    '$root/drop-deck.svg',
    '$root/excavator.svg',
    '$root/farm-gate.svg',
    '$root/fence-post.svg',
    '$root/fittings.svg',
    '$root/flanges.svg',
    '$root/flatbed-trailer.svg',
    '$root/forklift.svg',
    '$root/frac-tank.svg',
    '$root/fuel-tank.svg',
    '$root/generator.svg',
    '$root/grader.svg',
    '$root/guard-shack.svg',
    '$root/ibc-tote.svg',
    '$root/light-tower.svg',
    '$root/line-pipe.svg',
    '$root/livestock-shelter.svg',
    '$root/loader.svg',
    '$root/lowboy-trailer.svg',
    '$root/lunchroom.svg',
    '$root/material-cage.svg',
    '$root/modular-building.svg',
    '$root/octg.svg',
    '$root/other-not-listed.svg',
    '$root/portable-buildings-other-not-listed.svg',
    '$root/portable-office.svg',
    '$root/propane-tank.svg',
    '$root/rig-mat.svg',
    '$root/roll-off-truck.svg',
    '$root/scissor-lift.svg',
    '$root/semi-truck.svg',
    '$root/skid-steer.svg',
    '$root/spill-kit.svg',
    '$root/steel-plate.svg',
    '$root/step-deck.svg',
    '$root/storage-unit.svg',
    '$root/sucker-rod.svg',
    '$root/tanks-containers-other-not-listed.svg',
    '$root/tank-skid.svg',
    '$root/tool-room.svg',
    '$root/transport-hauling-other-not-listed.svg',
    '$root/vacuum-truck.svg',
    '$root/vault-tank.svg',
    '$root/water-tank.svg',
    '$root/water-truck.svg',
    '$root/welding-machine.svg',
    '$root/winch-truck.svg',
  };

  /// Representative photographic artwork for Marketplace category rows.
  static String? forCategory(String? category) {
    final value = category?.trim().toLowerCase() ?? '';

    return switch (value) {
      'heavy equipment' => '$root/excavator.svg',
      'oil & gas equipment' => '$root/generator.svg',
      'oilfield & drilling' => '$root/drilling-rig.svg',
      'pipe, tubing & materials' => '$root/drill-pipe.svg',
      'farm & ranch products' => '$root/farm-gate.svg',
      'tanks & containers' => '$root/fuel-tank.svg',
      'transport & hauling' => '$root/semi-truck.svg',
      'portable buildings' => '$root/portable-office.svg',
      'site support' => '$root/light-tower.svg',
      _ => null,
    };
  }

  /// Exact Marketplace product artwork.
  ///
  /// Returns null when this photographic package does not contain a dedicated
  /// image for the requested product. The caller may then use the existing
  /// industrial artwork as a controlled fallback.
  static String? forProductType(String? category, String? productType) {
    final categoryKey = category?.trim().toLowerCase() ?? '';
    final typeKey = productType?.trim().toLowerCase() ?? '';

    return switch (categoryKey) {
      'heavy equipment' => switch (typeKey) {
          'backhoe' => '$root/backhoe.svg',
          'bulldozer' => '$root/bulldozer.svg',
          'compactor' => '$root/compactor.svg',
          'crane' => '$root/crane.svg',
          'drilling rig' => '$root/drilling-rig.svg',
          'excavator' => '$root/excavator.svg',
          'forklift' => '$root/forklift.svg',
          'grader' => '$root/grader.svg',
          'loader' => '$root/loader.svg',
          'skid steer' => '$root/skid-steer.svg',
          _ => null,
        },
      'oil & gas equipment' => switch (typeKey) {
          'generator' => '$root/generator.svg',
          _ => null,
        },
      'oilfield & drilling' => switch (typeKey) {
          'derrick' => '$root/drilling-rig.svg',
          'drill rig' => '$root/drilling-rig.svg',
          _ => null,
        },
      'pipe, tubing & materials' => switch (typeKey) {
          'casing' => '$root/casing.svg',
          'drill pipe' => '$root/drill-pipe.svg',
          'drill stem' => '$root/drill-stem.svg',
          'fittings' => '$root/fittings.svg',
          'flanges' => '$root/flanges.svg',
          'line pipe' => '$root/line-pipe.svg',
          'octg' => '$root/octg.svg',
          'steel plate' => '$root/steel-plate.svg',
          'sucker rod' => '$root/sucker-rod.svg',
          _ => null,
        },
      'farm & ranch products' => switch (typeKey) {
          'bale feeder' => '$root/bale-feeder.svg',
          'buffalo / bison panel' => '$root/buffalo-bison-panel.svg',
          'cattle panel' => '$root/cattle-panel.svg',
          'continuous fence' => '$root/continuous-fence.svg',
          'corral panel' => '$root/corral-panel.svg',
          'custom pipe fabrication' => '$root/custom-pipe-fabrication.svg',
          'farm gate' => '$root/farm-gate.svg',
          'fence post' => '$root/fence-post.svg',
          'livestock shelter' => '$root/livestock-shelter.svg',
          _ => null,
        },
      'tanks & containers' => switch (typeKey) {
          'chemical tank' => '$root/chemical-tank.svg',
          'frac tank' => '$root/frac-tank.svg',
          'fuel tank' => '$root/fuel-tank.svg',
          'ibc tote' => '$root/ibc-tote.svg',
          'propane tank' => '$root/propane-tank.svg',
          'tank skid' => '$root/tank-skid.svg',
          'vault tank' => '$root/vault-tank.svg',
          'water tank' => '$root/water-tank.svg',
          'other / not listed' => '$root/tanks-containers-other-not-listed.svg',
          _ => null,
        },
      'transport & hauling' => switch (typeKey) {
          'drop deck' => '$root/drop-deck.svg',
          'flatbed trailer' => '$root/flatbed-trailer.svg',
          'lowboy trailer' => '$root/lowboy-trailer.svg',
          'roll off truck' => '$root/roll-off-truck.svg',
          'semi truck' => '$root/semi-truck.svg',
          'step deck' => '$root/step-deck.svg',
          'vacuum truck' => '$root/vacuum-truck.svg',
          'water truck' => '$root/water-truck.svg',
          'winch truck' => '$root/winch-truck.svg',
          'other / not listed' =>
            '$root/transport-hauling-other-not-listed.svg',
          _ => null,
        },
      'portable buildings' => switch (typeKey) {
          'bathroom unit' => '$root/bathroom-unit.svg',
          'container office' => '$root/container-office.svg',
          'crew shack' => '$root/crew-shack.svg',
          'guard shack' => '$root/guard-shack.svg',
          'lunchroom' => '$root/lunchroom.svg',
          'modular building' => '$root/modular-building.svg',
          'portable office' => '$root/portable-office.svg',
          'storage unit' => '$root/storage-unit.svg',
          'other / not listed' =>
            '$root/portable-buildings-other-not-listed.svg',
          _ => null,
        },
      'site support' => switch (typeKey) {
          'air compressor' => '$root/air-compressor.svg',
          'boom lift' => '$root/boom-lift.svg',
          'generator' => '$root/generator.svg',
          'light tower' => '$root/light-tower.svg',
          'material cage' => '$root/material-cage.svg',
          'scissor lift' => '$root/scissor-lift.svg',
          'spill kit' => '$root/spill-kit.svg',
          'tool room' => '$root/tool-room.svg',
          'welding machine' => '$root/welding-machine.svg',
          'rig mat' => '$root/rig-mat.svg',
          'other / not listed' => '$root/other-not-listed.svg',
          _ => null,
        },
      _ => null,
    };
  }
}
