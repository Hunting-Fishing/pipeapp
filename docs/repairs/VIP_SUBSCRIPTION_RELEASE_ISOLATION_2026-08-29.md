# VIP Subscription Release Isolation — 2026-08-29

## Symptom
The validated VIP subscription work was not live because it remained on a mixed feature branch that also contained deposit/split-payment changes. Merging that branch wholesale would have released unrelated financial work.

## Proven root cause
The validated feature branch was ahead of production `main` by unrelated financial commits. Production `main` therefore did not contain the VIP Checkout/UI lifecycle, and the mixed branch was not an acceptable release unit.

## Repair
A clean release branch was created from production `main`. Only the six VIP modules, VIP tests/UI, the deterministic five-file integration patch, and the exact approved VIP Stripe catalog entry were transferred from validated source commit `5cb06a71893cb361ed22d049feca2aa2b2dc1831`.

## Explicit exclusions
No marketplace deposit, split-payment, multi-charge, seller-release, refund/dispute automation, or unrelated financial-resolution files are part of this release.

## Validation contract
The release builder rejects any changed path outside the explicit VIP allowlist, validates exact live Stripe product/price identifiers and CAD $100/month pricing, runs Functions lint/check/tests, Dart analysis, targeted VIP/artwork tests, and the full Flutter test suite before committing.
