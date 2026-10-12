# Pipe Buyer User Score Policy

## Purpose

The User Score is a 0–100 trust signal. It helps buyers and sellers assess marketplace history without treating an unverified accusation as proof. New accounts start at 70 (neutral), not 100.

## Inputs and fairness

- Verified identity/business: up to +10.
- Completed successful transactions: up to +10 over time.
- Consistent response and fulfillment history: up to +5.
- Confirmed minor conduct issue: -2 to -8.
- Confirmed misleading listing or repeated spam: -10 to -25.
- Confirmed fraud, scam, threats, or stolen goods: -25 to -100 and possible suspension.
- Duplicate, retaliatory, withdrawn, or unsubstantiated reports: no score change.

Reports begin as `pending` and never change a score automatically. An admin must review evidence, conflicts of interest, previous reports, and the reported user's response. One incident produces one adjustment even if reported several times. Adjustments are stored in `user_score_events`, are auditable, and can be reversed on appeal. Scores remain clamped to 0–100.

## Reporting

`trust_reports` can target a listing, message, offer, or user. A report records reporter, reported user, target IDs, reason, description, evidence references, timestamps, and review status. Reporters cannot report themselves. Abuse of reporting may itself be reviewed.

## Auction thresholds

- Create an auction listing: score greater than 80, profile completion 100%, and `accountVerified == true`.
- Place an auction bid/offer: score greater than 50.
- Falling below a threshold blocks new auction activity but does not silently erase transaction history.

## Visibility

Public profiles show the current score, verification state, and high-level standing. Private evidence, reporter identity, and internal moderation notes are not public.

## Appeals and retention

Users may appeal confirmed decisions. Admins record the reason, reviewer, evidence outcome, and any reversal. Pending reports are not displayed as guilt. Confirmed safety records are retained as required for fraud prevention and legal compliance.
## Implementation: public score v1

The public score is computed by `functions/public_trust_projection.js` (`scoreVersion` 1) and written to the
public seller and business profiles. It does not read `users.userScore`, which the server never adjusts.

- 70 neutral start.
- +10 when administrator-approved identity/business verification is on file (`accountVerified`).
- +2 per completed marketplace sale, capped at +10.
- Plus the sum of `change` values in `user_score_events` for the member. **A reversal on appeal must be
  recorded as an offsetting event**; editing history is not required.
- Clamped to 0..100. Published only from 3 completed sales, and not for accounts scheduled for deletion.
- Not yet implemented: consistent response and fulfillment history (up to +5).
