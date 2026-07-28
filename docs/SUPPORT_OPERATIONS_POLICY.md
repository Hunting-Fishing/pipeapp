# Pipe Buyer Support Operations Policy

Status: Engineering-ready draft; operational and legal approval pending

## Purpose

This policy defines the Phase 1 in-app support workflow for authenticated Pipe
Buyer accounts. It is not an emergency service and must not be presented as a
substitute for police, fire, medical, roadside, or other emergency assistance.

## Intake and response targets

| Category | Server priority | First-response target |
| --- | --- | --- |
| Immediate marketplace safety | Urgent | 4 hours |
| Account access or security | High | 24 hours |
| Offer, auction, or transaction | High | 24 hours |
| Dispatch | Normal | 48 hours |
| Technical issue | Normal | 48 hours |
| Other | Normal | 48 hours |

Targets are measured from server receipt until the first administrator action.
They are service objectives, not guaranteed resolution times. The application
must show the target assigned to the selected category before submission.

## Required handling

1. Every case has one owner, category, server-derived priority, response target,
   status, revision, and immutable customer-visible event history.
2. Administrators require an approved role and current MFA session.
3. Administrator responses, escalation, resolution, and reopening require a
   meaningful customer-visible note.
4. Urgent or overdue cases remain visually distinct in the bounded queue.
5. A customer reply to `waiting_customer` returns the case to `in_review`.
6. Retry receipts prevent duplicate cases and messages.
7. Direct client writes to cases, events, status, and receipts are denied.

## Privacy and prohibited content

Support history is readable only by the case owner and MFA-authorized
administrators. Users are told not to submit passwords, one-time codes, banking
credentials, or government identification. The initial implementation accepts
text and entity references only; attachment intake stays disabled until a
purpose-bound upload policy and approved retention period are added.

## Escalation

- Threats, fraud in progress, or credible imminent harm: mark `escalated` and
  follow the approved Trust & Safety incident procedure.
- Account takeover: preserve access logs available to the platform, avoid
  disclosing account data, and route through the approved recovery procedure.
- Transaction or Dispatch dispute: preserve transaction history and use the
  corresponding controlled dispute workflow; support must not alter money or
  transaction state directly.
- Privacy or legal request: route to the designated privacy/legal owner.

## Launch evidence still required

- named operational owner and backup owner;
- approved support hours and escalation contacts;
- approved retention and deletion schedule;
- administrator staging acceptance using real MFA;
- alerting for urgent and overdue cases;
- volume and failure drills;
- reviewed public support and privacy language.

Until this evidence exists, the workflow is source- and emulator-verified but
not operationally approved for an unrestricted public launch.
