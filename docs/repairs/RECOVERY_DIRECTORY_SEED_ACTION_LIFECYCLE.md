# Recovery Directory seeded business-action lifecycle

Date: 2026-08-22

## Symptom

Seeded Dispatch Directory widget tests can construct provider cards without a
Firebase app, but the provider-card business action child eagerly constructed
MarketplaceActionsRepository and eagerly loaded the public business profile.

That bypassed the parent Directory's accepted seed-safe repository lifecycle
and could raise:

`[core/no-app] No Firebase App '[DEFAULT]' has been created`

## Root cause

The Directory parent had already been repaired to avoid constructing its
Firestore repository when `seedEntries` are supplied.

The business-action child was a second Firebase dependency island:

- MarketplaceActionsRepository was constructed eagerly;
- public_business_profiles was read during initState;
- FirebaseAuth was consulted during normal widget build.

Seed fixtures therefore remained coupled to Firebase even though the Directory
data source itself was seed-only.

## Permanent repair

MarketplaceDispatchDirectoryBusinessActions now accepts `remoteDataEnabled`,
defaulting to true for production.

When Directory `seedEntries` are supplied, the parent passes
`remoteDataEnabled: false`.

In that mode:

- MarketplaceActionsRepository is not constructed;
- public profile Firestore is not loaded;
- FirebaseAuth is not accessed;
- remote message, quote and report actions are disabled.

Production Directory behavior remains unchanged because live Directory cards
use the default remote-data-enabled path.

## Verification

The consolidated recovery verification must pass:

- Pipe Buyer Formal Fast Gate;
- startup single-surface contract;
- startup auth-loading contract;
- Request Service restore contract;
- Directory seed-safe repository contract;
- Directory filter runtime stability contract;
- Directory widget tests.

## Future rule

A seeded widget-test path must not require global Firebase initialization just
to render deterministic fixture data.

Remote dependencies belong behind explicit production/runtime paths or
injectable/lazy boundaries.