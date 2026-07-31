# Dispatch truck routing and location privacy

Last updated: July 31, 2026

## Current contract

Dispatch route analytics are server owned. Clients submit mapped pickup and
delivery points, but they cannot submit distance, route status, provider,
duration, or route-version fields.

New Dispatch jobs use two records:

- `dispatch_jobs/{jobId}` is the signed-in job board record. It contains broad
  pickup and delivery labels, non-sensitive town/region information, load
  details, and server-generated route status.
- `dispatch_job_private/{jobId}` contains exact pickup and delivery points,
  full delivery address, postal details, and access instructions. Firestore
  Rules allow only the requester, an administrator, or the awarded carrier to
  read it. All client writes are denied.

The public record initially contains a clearly labelled server Haversine
estimate when both points are mapped. It never presents that estimate as a
legal or drivable truck route. The exact coordinates are hashed into a
deterministic `routeInputHash`; the hash supports stale-result detection
without exposing the coordinates.

## Truck-routing provider boundary

The source includes a tested HERE Routing API v8 truck-request builder and
response validator. The adapter uses `transportMode=truck`, route summaries,
notices, and optional vehicle limits for weight, gross weight, dimensions, and
axle weight. See the official [HERE truck-routing documentation](https://docs.here.com/routing/docs/routing-v8-truck-routing),
[Routing API setup](https://docs.here.com/routing/docs/routing-v8-get-started),
and [transport modes](https://docs.here.com/routing/docs/routing-v8-transport-modes-overview).

No external route request is active in this checkpoint. The application keeps
`routeStatus=provider_not_configured` and shows a straight-line estimate until
an approved environment completes the activation checklist below.

## Activation checklist

1. Approve provider terms, data residency, retention, budget, and expected
   monthly route volume.
2. Create separate staging and production credentials. Store credentials in
   the approved secret manager; never place a key in Flutter, Git, a service
   worker, or ordinary Function environment text.
3. Add a protected server task/callable that reads
   `dispatch_job_private/{jobId}`, verifies the route input hash, calls the
   provider, validates notices, and updates only server-owned public route
   fields.
4. Require App Check, authenticated ownership/role checks, idempotency, bounded
   retry, per-user rate limits, provider timeout, and daily cost quotas.
5. Cache identical route inputs for a bounded period and record provider,
   provider response version, calculation time, and notice count.
6. Run staging acceptance with ordinary freight, border crossings, seasonal
   roads, overweight/oversize profiles, no-route responses, provider timeout,
   and critical restriction notices.
7. Keep `review_required` routes out of automatic quote math until a qualified
   dispatcher reviews the notices.
8. Activate production only through the normal reviewed deployment workflow
   with rollback and budget alerts ready.

## Existing-record migration gate

The source boundary protects newly created and revised jobs after deployment.
Before public Rules or Functions are promoted, inventory existing
`dispatch_jobs` for `pickupPoint`, `deliveryPoint`, `deliveryAddress`,
`deliveryPostalCode`, and `deliveryAccessNotes`. Copy those values to the
matching private record, verify counts and ownership, then remove only the
verified sensitive fields from the public record and every public `revisions`
record. Retain a protected rollback checkpoint and test
owner/awarded-carrier/other-carrier access in staging.

This migration has not been run by this local engineering checkpoint. Existing
production data must not be declared protected until the migration evidence is
reviewed.

## Operational disclosure

Routing output is planning information, not a permit, legal-load approval, or
guarantee of road access. Carriers remain responsible for current restrictions,
permits, borders, scales, bridge limits, weather, and safe operation. Missing
vehicle dimensions or weights reduce the restrictions a provider can evaluate,
so incomplete vehicle profiles must be visibly labelled and cannot be treated
as verified routes.
