# Dispatch Phase 3 - Service Area and Home-Base Map

## Purpose

This slice connects the Dispatch Company Profile to the existing Pipe Buyer open-map service-area system instead of creating a second mapping stack.

The provider can define coverage with the existing `MarketplaceServiceAreaPicker` using radius, towns, or regions. That picker already uses the project's OpenStreetMap/open-address/geolocation stack and returns a structured `MarketplaceServiceArea`.

## Data flow

```text
Dispatch -> Company Profile -> Set/Edit service area on map
    -> MarketplaceServiceAreaPicker
    -> DispatchCompanyProfileDraft.serviceArea
    -> MarketplaceDispatchCompanyProfileRepository.save()
```

The structured service area is persisted in two different privacy projections.

### Private owner-scoped projection

`business_private/{uid}.dispatchProfile.serviceArea`

This stores the full `MarketplaceServiceArea.toMap()` value so the provider can reopen and edit the same mapped coverage later. Exact center points and selected-area geometry remain owner-scoped.

### Public Dispatch projection

`public_business_profiles/{uid}.dispatchProfile`

The public projection stores:

- service-area summary;
- approximate home-base label and point;
- coverage mode;
- radius;
- country/region/place keys for future Directory matching;
- selected place names and OSM identifiers without exact selected-place points or boundary rings.

Public home-base coordinates are rounded to two decimal places and marked `approximate_1km`. The purpose is Directory discovery and regional matching, not publishing an exact private yard, residence, or staging location.

## Compatibility

- Existing `serviceAreaLabel` remains for display/backward compatibility.
- Existing structured `dispatch_carriers/{uid}.serviceArea` is read as a fallback when a newer profile record does not yet exist.
- `dispatch_carriers` approval/enrollment state is not modified.
- The existing `MarketplaceServiceAreaPicker` remains the single map editor; no duplicate Dispatch-only map implementation is introduced.

## Phase 3 gate

Equipment browser acceptance advances Phase 3 to 13/15 and overall Dispatch to 50%.

This mapped service-area slice earns its 1 point only after:

1. formatter and strict analyzer pass;
2. geography privacy/model tests pass;
3. Phase 3/2/1 regressions pass;
4. provider browser acceptance confirms a mapped service area can be saved, left, reopened, and restored.

After browser acceptance, Phase 3 becomes 14/15 and overall Dispatch becomes 51%. The final Phase 3 point remains credential/insurance metadata with private document separation.
