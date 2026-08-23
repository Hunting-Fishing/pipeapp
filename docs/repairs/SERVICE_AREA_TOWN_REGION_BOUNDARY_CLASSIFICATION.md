# Service Area Town / Region Boundary Classification Repair

**Branch:** `design/formal-beautification-foundation`

**Status:** Engineering repair prepared; browser acceptance still required.

## Symptom

In Dispatch Company Profile -> Service area:

- searching **Fort St. John** or **Dawson Creek** under **Towns** could select/highlight the much larger Peace River administrative area instead of the municipality;
- the selected chip could become `Peace River, British Columbia, Canada` even though the user searched for Fort St. John;
- **Regions** could save/show only a reference pin without drawing the administrative boundary, which is misleading for an area-based mode.

## Root cause

There were two coupled classification errors.

### 1. Photon settlement parsing promoted district/county into the town field

`open_address_autocomplete.dart` built `OpenAddress.city` from this fallback sequence:

```text
city -> town -> village -> hamlet -> locality -> district -> county
```

For a Photon result such as Fort St. John, the feature can have:

```text
name     = Fort St. John
type     = city
district = Peace River
state    = British Columbia
```

When no explicit `city` property was present, the parser incorrectly assigned `Peace River` to `OpenAddress.city`. The service-area picker then treated the parent district as the selected town.

The settlement search filter also explicitly allowed `district` and `county`, so broader administrative results were permitted in the Towns tab.

### 2. Boundary selection used loose display-name matching

The service-area boundary loader searched Nominatim and accepted a polygon when its display name merely started with the requested text or when any address hierarchy field matched. That could admit a broader administrative polygon whose address hierarchy happened to mention the requested city.

Region mode also derived its identity from `address.region` (the parent state/province) instead of preserving the name of the selected administrative feature itself.

## Correct architecture

### Towns

- Settlement search types are only settlement-like values: city, town, village, hamlet, locality, municipality, borough.
- District/county values are administrative context, not the selected settlement.
- Photon `name` is retained independently from the parent district.
- Duplicate node/relation results representing the same place are collapsed; the relation is preferred because it can carry the municipal boundary directly.
- Nominatim fallback uses a structured `city + state + country` search rather than a broad free-form query.
- Candidate polygons must match the requested municipality identity and must not be classified as county/district/state/region/country.
- For Canada, a broader administrative polygon is rejected when its `admin_level` is not 8. Canadian incorporated municipalities are represented at admin level 8 in OpenStreetMap.
- If an official town boundary still cannot be found, the town pin may be saved, but the UI explicitly states that a surrounding district was not substituted.

### Regions

- The selected administrative feature name is preserved, e.g. `Peace River Regional District`, `British Columbia`, or `Canada`.
- Relation geometry is used directly when available, with an exact classified Nominatim fallback when necessary.
- A Regions selection without polygon geometry is **not** silently added as a bare pin. The user must choose a result with a mapped administrative boundary.

## Permanent regression controls

- `test/service_area_geocoder_classification_test.dart`
- `tool/fix_service_area_geocoder_classification.ps1`
- `tool/verify_service_area_geocoder_classification.ps1`

The regression suite locks the following examples:

- Fort St. John remains the town while Peace River remains parent administrative context;
- Peace River Regional District is not accepted in Towns mode;
- Dawson Creek duplicate node/relation results prefer the relation;
- a Canadian admin-level 6 polygon cannot be substituted for a town boundary;
- Peace River Regional District is accepted in Regions mode;
- British Columbia is accepted as a province/region boundary.

## Browser acceptance required

Before awarding the remaining Phase 3 service-area point, verify in the formal emulator/browser environment:

1. **Towns -> Fort St. John** selects/highlights only the Fort St. John municipality (or saves only the correct town reference point if OSM has no municipal polygon). It must never highlight Peace River Regional District.
2. **Towns -> Dawson Creek** behaves the same way.
3. **Regions -> Peace River Regional District** highlights the whole regional district boundary.
4. **Regions -> British Columbia** highlights the provincial boundary.
5. Save the service area, leave Company Profile, reopen it, and confirm the selected mode/areas/boundaries restore correctly.

If one of these fails, stop on that specific case. Do not loosen the classification rules to make a polygon appear.
