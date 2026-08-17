# Dispatch Phase 3 Credential Intelligence

**Branch:** `design/formal-beautification-foundation`

**Phase state before browser acceptance:** 14/15 Phase 3 points, 51% overall.

## Accepted product direction

The Credentials & insurance area is not only a document locker. It must help a Dispatch provider understand whether their private records are complete, whether supplied credentials are close to expiry, and whether their self-reported insurance coverage can satisfy future customer minimums.

The UI is split into two tabs:

1. **Records** — private credential metadata and evidence.
2. **Analytics & alerts** — completeness, expiry risk, private evidence status, insurance matching readiness, reminder settings and suggested actions.

## Private insurance fields

Insurance credential records may store:

```text
coverageLimit
aggregateLimit?
coverageCurrency
```

Initial North American currency choices are CAD, USD and MXN. The storage field remains a three-letter currency code so international expansion does not require a schema replacement.

Coverage amounts remain under `business_private/{uid}.dispatchCredentials`. Policy/reference numbers, notes, exact coverage values and evidence paths are never copied into the public company profile or Dispatch Directory projection.

## Minimum-insurance matching rule

Future customers may request a minimum self-reported insurance amount. The provider-side model exposes deterministic eligibility logic:

```text
provider credential is current
AND credential type is an insurance type
AND coverage currency equals the request currency
AND coverageLimit >= requested minimum
```

No hidden FX conversion is allowed. A future approved FX service may be used only if conversion behavior is explicit and tested.

The future matching layer should return eligible providers without publishing the provider's private exact amount or policy number. This requirement is prepared in Phase 3 but does not award Phase 4/5/6 points early.

## Expiry reminder architecture

Reminder preferences stay private:

```text
dispatchCredentialReminderSettings
    enabled
    reminderDays[]
```

Supported reminder windows begin with:

```text
90, 60, 30, 14, 7, 1 days
```

The client asks the server to synchronize a single private next-due timestamp:

```text
dispatchCredentialNextReminderAt
```

The scheduled server monitor queries only due records using that field. It does not scan every provider credential record. This is the scaling control for future international growth.

Reminder deliveries are idempotent through a private sent-key map:

```text
dispatchCredentialReminderSent
```

When a reminder is due, the server writes a normal Pipe Buyer notification under the existing owner notification collection. Existing notification delivery can then send it to registered web/iOS/Android endpoints.

Uploading evidence or entering coverage does not make a credential Pipe Buyer verified.

## Analytics that are allowed

The Analytics & alerts tab may calculate from the owner's private data:

- number of current records;
- expired records;
- not-provided records;
- count with private evidence;
- insurance records with declared coverage limits;
- upcoming expiry dates;
- completion/readiness percentage;
- suggested next actions.

The readiness percentage is explicitly a completeness aid, not a rating, trust score or verification claim.

## Future analytics after request/matching data exists

Later phases may add:

- number of open requests the provider currently qualifies for;
- number excluded because a minimum insurance requirement is not met;
- number excluded because a required credential is missing/expired;
- credential-related lost-opportunity trend;
- renewal impact estimates based on actual Dispatch request history;
- company-specific compliance checklists by service type or geography when backed by reliable rule sources.

Do not fabricate benchmarks, ratings, opportunity counts or compliance requirements.

## Browser acceptance required before Phase 3 closes

1. Edit an insurance credential and save a primary coverage amount and currency.
2. Reopen it and confirm the amount persists.
3. Add an optional aggregate amount and confirm persistence.
4. Confirm the private Records tab still keeps policy/reference/evidence data private.
5. Open **Analytics & alerts** and confirm the metric counts reflect the entered records.
6. Confirm an upcoming expiry appears in the expiry list.
7. Enable reminder preferences and save them.
8. Enable device notifications if the test account/device permits it.
9. Confirm the UI still says self-reported data is not Pipe Buyer verification.
10. Confirm no private coverage amount or policy reference appears in any public Company Profile / Directory surface.

Only after those checks pass may the remaining Phase 3 credential point be awarded and Phase 4 be unlocked.
