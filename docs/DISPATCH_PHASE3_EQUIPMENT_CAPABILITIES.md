# Dispatch Phase 3 - Fleet and Equipment Capabilities

## Status

The company-profile persistence engineering gate and browser acceptance are complete. The local master-plan finalizer advances verified Dispatch completion to **48%** and Phase 3 to **11/15** before this equipment slice is evaluated.

Phase 3 remains the only active Dispatch phase. Phase 4 Directory work stays blocked.

## Purpose

This slice turns the existing `dispatch_carriers/{uid}/vehicles/{vehicleId}` fleet records into structured equipment profiles that can later power Directory filtering and service matching without replacing the proven quote/fleet collection.

## Compatibility strategy

Existing fleet documents remain in place. No fleet migration or destructive rewrite is required.

The structured additions are:

- `equipmentTypeCode` - stable equipment class;
- `serviceCodes[]` - stable Phase 2 service taxonomy codes;
- `capabilityProfile.schemaVersion`;
- `capabilityProfile.serviceCodes[]`;
- `capabilityProfile.capabilities` - only known Phase 2 capability codes;
- `capabilityProfile.source = provider_declared`;
- existing `available` remains the operational availability switch.

The legacy `services[]`, `vehicleType`, `pilotTruck`, and `maximumPayloadKg` fields remain populated for compatibility with the existing Dispatch dashboard and quote flow.

## Equipment types

The initial stable equipment types are:

- truck / tractor;
- trailer;
- pilot / escort vehicle;
- crane / picker;
- hydrovac / vacuum;
- service truck;
- heavy equipment;
- other equipment.

Legacy vehicle type text is mapped conservatively when a structured type is not yet present.

## Capability rules

Capabilities come only from `MarketplaceDispatchServiceTaxonomy`.

Unknown capability keys are discarded. Invalid numeric values are discarded. Boolean values must actually be booleans. Multi-value fields are bounded and normalized.

Canonical storage continues to use the Phase 2 units. The North America-first editor presents common values in:

- pounds for canonical kilograms;
- feet for canonical metres;
- miles for canonical kilometres;
- US gallons for canonical litres.

Values convert back to the canonical units before Firestore persistence.

## Privacy and trust boundary

This slice stores provider-declared operational capabilities only. It does not claim that a payload, lift rating, dangerous-goods status, permit status, or other capability has been independently verified.

Credential and insurance verification remains a separate protected Phase 3 task.

## User flow

`Dispatch -> Company Profile -> Manage fleet`

A provider can:

1. open an existing fleet item or add equipment;
2. select a stable equipment type;
3. mark current operational availability;
4. select the stable Dispatch services the unit can perform;
5. enter structured capabilities relevant to those services;
6. save and reopen the fleet item.

## Engineering gate

`tool/verify_dispatch_phase3_equipment_capabilities.ps1` verifies:

- the accepted profile slice is recorded locally at 48%;
- strict analyzer for the equipment model/page and Company Profile integration;
- legacy service compatibility;
- known-code-only capability normalization;
- canonical/display unit round trips;
- Company Profile -> Manage fleet wiring;
- Firestore owner-rule anchors for carrier vehicles;
- Phase 3 company-profile regressions;
- Phase 2 taxonomy regression;
- Phase 1 navigation regression;
- Dispatch auth-reactivity regression.

## Acceptance requirement

After the engineering gate passes, browser acceptance must prove that an existing carrier fleet item can be opened, structured services/capabilities can be saved, and those values remain after leaving and reopening the page. Only then are the **2 equipment/fleet capability points** awarded.
