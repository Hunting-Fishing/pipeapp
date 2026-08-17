# Dispatch quote planner - source, maps, and multi-unit requirements

**Status:** foundation correction / shared Phase 5 requirement
**Branch:** `design/formal-beautification-foundation`
**Dispatch completion impact:** **no points awarded by this slice**

## Why this exists

The current provider rate-planning dialog can save a lane name, free-text origin/destination, pricing inputs, and a single pilot-vehicle count. That is insufficient for a real industrial Dispatch request or reusable job preset.

Pipe Buyer must let a user start from either:

1. an existing Marketplace listing; or
2. a custom / standalone job that can be prepared before a purchase exists.

The same structured route and unit requirements must be reusable later by the standalone Request Service workflow instead of creating a second incompatible form.

## Required source modes

Stable storage values:

```text
listing
standalone
```

UI labels:

- **Select Marketplace listing**
- **Custom / standalone job**

When a listing is selected, the planner may prefill the listing title and public pickup area. The user must still be able to refine the pickup pin because a public listing point can be approximate.

A custom job requires no Marketplace listing and can be saved as a reusable preset for the account owner.

## Route requirements

Origin and destination must not be plain free-text-only fields.

Both use the existing Pipe Buyer mapping stack:

```text
MarketplaceLocationPicker
OpenStreetMap tiles
open address autocomplete
manual map pin adjustment
current-location option
```

Required behavior:

- select origin on map;
- select destination on map;
- preserve a recognizable label plus exact owner-scoped point in the saved quote/preset;
- preserve nearest town / region / country / access notes where supplied;
- listing source may prefill an approximate public pickup point, then allow manual correction;
- standalone source starts with fully custom map selection;
- exact saved lane locations remain owner-scoped inside the provider/account saved-quote collection.

## Multi-unit job composition

A Dispatch job can require more than one equipment class and more than one unit of each class.

The planner therefore stores an array rather than one global truck count.

```text
requestedUnits[]
    unitTypeCode
    minQuantity
    maxQuantity
```

Examples:

```text
pilot_truck       min 2   max 4
hauling_tractor   min 1   max 12
lowboy_trailer    min 1   max 3
service_truck     min 1   max 2
```

`minQuantity == maxQuantity` means an exact quantity.

`minQuantity < maxQuantity` means an acceptable range.

This supports jobs such as:

- 2-4 pilot trucks;
- 1-12 hauling tractors / power units;
- multiple trailers;
- several service trucks;
- mixed crane / picker / transport support packages.

Initial stable unit-type codes:

```text
hauling_tractor
pilot_truck
hotshot_unit
winch_tractor
lowboy_trailer
flatbed_trailer
step_deck_trailer
picker_crane_truck
service_truck
crane_unit
loader
grader
excavator
custom_equipment
```

These codes are job-composition requirements. Existing pricing inputs remain separate. For example, the current Pilot Vehicles pricing section can still choose the exact pilot count used for one estimate even when the job requirement permits a range.

## Saved quote / preset storage

The existing owner-scoped saved quote gains:

```text
sourceType
listingId?
listingTitle?
originLocation {}
destinationLocation {}
requestedUnits[]
requirementsVersion
```

Existing text fields `origin` and `destination` remain as compatibility/display labels.

## Phase control

The Dispatch master plan currently has Phase 3 at 13/15 and does not permit Phase 5 completion points yet.

This change is treated as a **foundation correction to the existing saved quote planner** and a locked requirement for Phase 5. It does not mark Phase 4 or Phase 5 complete.

The completed Phase 5 Request Service workflow must reuse these concepts for all account types, including customers who are not registered Dispatch providers.

## Acceptance

The slice is complete only when:

- user can switch between listing and standalone source;
- listing selector reads active `public_listings` only;
- origin can be selected/changed using `MarketplaceLocationPicker`;
- destination can be selected/changed using the existing delivery map picker;
- both mapped locations survive saved-quote reopen;
- user can add/remove multiple unit requirement rows;
- each row validates `1 <= minQuantity <= maxQuantity`;
- saved quote stores all unit rows;
- legacy saved quotes without the new fields still open;
- existing pricing calculation still works;
- analyzer and focused Dispatch regressions pass;
- browser acceptance confirms map selection and a sample `2-4 pilot trucks + 1-3 hauling tractors` preset.
