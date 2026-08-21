# Dispatch Request Service Restore + Multi-Service Quote

Status: implementation slice after Directory D1 browser acceptance.

## Decision

The Dispatch Directory expansion does **not** replace the existing Request Service / trucking request workflow.

The correct product structure is additive:

1. **Request Service keeps the existing listing-to-freight-quote and trucking request flow.**
2. Request Service regains a structured service menu from the canonical Dispatch taxonomy.
3. Directory **Get Quote** uses the same taxonomy, but is restricted to services that the selected provider actually advertises.
4. Directory Get Quote supports multiple requested service items with `+ Add Service`.
5. No second client-written service-request database is invented in this slice.

## Request Service acceptance

At the top of the existing `_PostJob` flow, show **Choose service(s)**.

The selector uses `DispatchServiceTaxonomy.services`, including Transportation, Pilot & Oversize Support, Crane & Lifting, and Oilfield & Industrial Field Services. Examples include Hotshot, Mobile Crane, Road Maintenance, Grading, Mobile Mechanic and Pilot / Escort Vehicle.

The existing controls below must remain:

- Select a listing for quote;
- manual load title;
- mapped pickup;
- mapped delivery;
- route-distance notice;
- load/equipment details;
- requested date;
- Publish Dispatch job;
- `MarketplaceFreightQuote.show(...)` listing workflow.

For the current compatibility slice, selected service names are prepended to the authoritative request `loadDetails`. This preserves the existing server-controlled `createDispatchJob` path and makes the service selection visible in the request without creating a parallel unsecured write path.

A later generic industrial-service request model may separate non-transport work from trucking-specific route fields. That later model must be server-controlled and migration-safe; it is not fabricated in this restoration slice.

## Directory Get Quote acceptance

The selected business provides the allowed service-code list. The quote dialog must not show unrelated services.

The form contains:

- one provider service dropdown;
- `+ Add Service` to add additional service lines;
- duplicate service prevention;
- work / pickup location;
- requested date picker;
- priority: Flexible, Scheduled, Urgent, Emergency;
- scope/equipment/quantity/dimensions/notes;
- Send Quote Request.

The sent private business-conversation message lists every selected service separately.

## Repair control

This slice may modify only:

- `lib/marketplace/marketplace_dispatch_page.dart`;
- `lib/marketplace/marketplace_dispatch_directory.dart`;
- `lib/marketplace/marketplace_dispatch_directory_actions.dart`;
- additive `lib/marketplace/marketplace_dispatch_multi_service_selector.dart`.

It must not modify Firebase Functions, Quote V2, authentication, Firestore rules, Directory reputation logic, or the Dispatch completion tracker.

Before production mutation, build a canonical-filename mirror of the exact local `lib/` tree, apply the transformation there, install the candidate action/selector files there, format and strictly analyze the complete candidate. Production hashes must remain unchanged until that mirror is green.

If a post-promotion analyzer or contract test fails, restore the three existing source files from the gate backup and remove the additive selector when it did not exist before the gate.
