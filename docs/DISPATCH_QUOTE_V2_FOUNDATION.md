# Dispatch Quote V2 Foundation

## Status

This document defines the first controlled Quote V2 slice for Pipe Buyer Dispatch on `design/formal-beautification-foundation`.

The purpose of this slice is to remove the competing carrier-quote editor in **Dispatch > Jobs** and make the existing detailed Pipe Buyer rate form the single active quote-authoring surface for both saved Dispatch rate plans and live carrier quotes.

This is **Quote V2 Slice B1**. It is not the final cancellation/watermark slice.

## Existing state retained

The existing server workflow already keeps carrier quote revisions under:

- `dispatch_bids/{bidId}` for the current quote state.
- `dispatch_bids/{bidId}/revisions/{revision}` for immutable revision history.

The existing Firestore security contract also limits carrier quote and quote-revision reads to the carrier that submitted the quote and the owner of the related Dispatch job. This slice does not loosen that access model.

Saved dashboard rate plans already keep their own revision history under the carrier's private `saved_quotes` collection. That behavior remains.

## Problem being corrected

Before this slice there were two materially different quote-authoring experiences:

1. The Dispatch Dashboard contained the detailed rate calculator with loaded distance, deadhead, weight, hourly, pilot, permit, surcharge, tax, and manual override inputs.
2. Dispatch > Jobs used a separate small dialog containing only an all-in price, assigned truck, available date, and terms.

That created two quote definitions and meant a live carrier quote did not retain the complete pricing calculation that produced the submitted amount.

## B1 target architecture

### One active quote form

`MarketplaceDispatchQuoteForm` is the shared quote-authoring component.

It is used by:

- Dispatch Dashboard saved quote/rate-plan creation and revision.
- Dispatch Jobs carrier quote creation and revision.

The legacy Jobs `All-in transport price` editor must no longer be reachable after B1.

### Quote fields

The reusable form records:

- Quote/lane name.
- Origin and destination.
- Currency (`CAD` or `USD` in B1).
- Loaded distance.
- Deadhead distance.
- Shipping weight.
- Estimated hours.
- Base/call-out fee.
- Loaded mileage rate.
- Deadhead rate.
- Weight rate.
- Hourly rate.
- Area/zone fee.
- Permit/fixed costs.
- Pilot vehicle count.
- Pilot mileage rate.
- Pilot hourly rate.
- Pilot area fee.
- Fuel/service surcharge percentage.
- Tax percentage.
- Optional manual total override.
- Equipment, timing, and quote terms.
- Assigned carrier fleet unit for live job quotes.
- Carrier available date for live job quotes.

### Formula version 2

The client displays the quote calculation, but the server recalculates the submitted Quote V2 total from the normalized rate inputs before accepting the command.

Formula:

```text
loadedMileage = distanceKm * mileageRate
deadhead = deadheadKm * deadheadRate
weight = (weightKg / 1000) * weightRate
time = hours * hourlyRate
pilot = pilotCount * (
  distanceKm * pilotKmRate
  + hours * pilotHourlyRate
  + pilotAreaFee
)
subtotal = baseFee + loadedMileage + deadhead + weight + time
         + areaFee + permitFee + pilot
surcharge = subtotal * surchargePercent / 100
beforeTax = subtotal + surcharge
tax = beforeTax * taxPercent / 100
total = manual ? manualTotal : beforeTax + tax
```

The submitted amount must match the server result within the bounded floating-point tolerance. A client cannot silently submit a different final amount from the detailed quote form.

Manual override remains allowed, but both the calculated components and the manual total are retained in the version record for audit comparison.

### Version identity

The server stores:

- `quoteReference`: stable per carrier quote, formatted from the bid identity as `PBQ-...`.
- `quoteVersion`: the current revision number.
- `revision`: existing authoritative revision number.
- `validityStatus`: `active` for the current B1 quote.
- `currency`.
- `quoteBreakdown`: complete normalized server-verified calculation snapshot.

A carrier quote revision continues to use the existing bid document rather than creating an unrelated duplicate quote. Version 1 remains in the revision collection when Version 2 becomes current, Version 2 remains when Version 3 becomes current, and so on.

## Privacy

B1 does not make quotes public.

The established access boundary remains:

- submitting carrier: read;
- Dispatch request owner/customer: read;
- unrelated signed-in users: no quote access;
- server commands: authoritative writes.

Do not move quote calculations, historical versions, terms, or invalidation state into the public Directory projection.

## Transaction safety

The B1 engineering gate must:

1. Verify the active branch.
2. Synchronize only the focused Quote V2 support bundle.
3. Parse all control scripts before mutation.
4. Fingerprint the five existing production source files and Dispatch master tracker.
5. Build transformed Dart/Node candidates without modifying production.
6. Format/analyze the candidate Dart dependency graph.
7. Syntax-check candidate Functions code.
8. Run server Quote V2 calculation tests against the candidate policy.
9. Prove production hashes are unchanged by candidate validation.
10. Create an independent gate backup.
11. Apply the already-proven transformation.
12. Format and strictly analyze production Dart before regressions.
13. Syntax-check production Functions code.
14. Run Quote V2 policy and existing Dispatch policy regressions.
15. Run the Quote V2 Flutter contract.
16. Restore all five pre-existing production sources automatically if any post-mutation gate fails.
17. Prove `docs/DISPATCH_NETWORK_MASTER_PLAN.md` was not modified.

A failed B1 gate is not permission to rerun older Directory or Dispatch repairs.

## Browser acceptance for B1

After the engineering gate is green, restart the formal acceptance environment so the Functions emulator loads the new server command code.

Carrier acceptance:

1. Open Dispatch > Jobs.
2. Open a carrier job with an existing or new quote.
3. Choose Edit quote / create quote.
4. Confirm the detailed Pipe Buyer quote form opens instead of the small all-in-price dialog.
5. Confirm route/load and rate fields are present.
6. Confirm fleet unit and available date are present on the live-job quote.
7. Submit a new version.
8. Re-open History and confirm the earlier revision is still present.
9. Confirm the active quote revision increments rather than overwriting/removing prior history.

Customer acceptance:

1. Open the matching Dispatch job as its owner.
2. Open Carrier bids.
3. Confirm the revised quote remains visible only through the existing participant access path.
4. Confirm the version/history remains available.

## Next slice: B2 validity, cancellation, and watermarking

B1 intentionally does **not** claim completion of the requested invalidation experience.

After B1 browser acceptance, Quote V2 Slice B2 will add:

- Explicit carrier quote cancellation command.
- Server-owned quote validity transitions.
- `QUOTE UPDATED - NO LONGER VALID` presentation for superseded versions.
- `QUOTE CANCELLED - NO LONGER VALID` presentation for cancelled quotes.
- Large invalidation watermark on historical/inactive quote rendering.
- Explicit `Version N` and `Superseded by Version N+1` labels.
- Participant notification when a quote is revised or cancelled.
- Current-version viewer driven by server validity state rather than client inference.
- PDF/export validity checks before generating a current quote artifact.

A static screenshot or file previously saved outside Pipe Buyer cannot be retroactively altered. The in-app viewer and newly generated artifacts must always resolve the latest server validity state.

## Request Service company matching follows Quote V2

Companies are providers, not a service taxonomy category.

After Quote V2 is accepted, Request Service will be connected to `dispatch_directory_entries` so the customer flow becomes:

```text
service category / service
  -> location and date
  -> matching Directory companies
  -> all matching / selected companies / open network
  -> review and publish request
```

This preserves the existing four service taxonomy groups and avoids adding a misleading `Companies` service category.
