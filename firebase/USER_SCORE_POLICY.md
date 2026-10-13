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
## Implementation: automated User Score (v2)

Nothing is entered by hand. `functions/public_trust_projection.js` derives the score from server data and
writes it to the private `users/{uid}.userScore` (used by the auction thresholds above) and, from 3 completed
sales, to the public seller and business profiles (`scoreVersion` 2). It re-runs on every event that can change
it and once a day (`reconcilePublicTrust`, resumable) so nothing drifts.

| Input | Points | Source |
|---|---|---|
| Neutral start | 70 | policy |
| Administrator-approved verification | +10 | `users.accountVerified` |
| Completed marketplace sales | +2 each, max +10 | `marketplace_transactions` (`status == completed`) |
| Fulfillment | up to +5 from 3 sales: completed / (completed + cancelled by the seller) | `marketplace_transactions` (`cancelledByUid == seller`) |
| Confirmed moderation outcome | per incident, see below | `trust_reports` with status `violation_confirmed` or `appeal_upheld` |
| Exceptional administrator adjustment | any | `user_score_events` (optional) |

Result is clamped to 0..100. Membership is never an input. Disputes are accusations, not proof, so they are not
counted.

**Moderation points** (an administrator's review is the trigger; the points are applied and reversed
automatically): fraud or scam -40, hate/threats -25, prohibited or unsafe item -25, misleading information -15,
reused photos -15, duplicate listing -10, spam -10, vulgar or harassing content -5, other -3. One incident
(same listing, message, or offer) counts once, at its worst reason. The total penalty is floored at -100.
Pending, dismissed, under-appeal, and overturned reports never change a score, so an overturned appeal restores
the points by itself. These values sit inside the ranges above and live in `REPORT_REASON_PENALTIES`.

Public display: from 3 completed sales, unless the account is scheduled for deletion. Not implemented yet:
response-time history and verified reviews.
