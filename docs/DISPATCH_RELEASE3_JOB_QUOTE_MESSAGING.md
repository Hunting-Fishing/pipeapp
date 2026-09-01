# Release 3 — Dispatch job and quote messaging

## Date

2026-09-02

## Verified production baseline before this slice

```text
62cf3075f53725ffafdd34e12c9d3875bfc53078
```

That application SHA is the verified production release from protected run
`33534730700` / #64 with App Check `enforce`.

## Product decision

Dispatch does not get a second messaging subsystem. Job/quote conversations
reuse the existing `conversations` collection, message send/read flow,
attachments, unread counts, reporting, anti-abuse controls, and Marketplace
user-block enforcement.

One deterministic conversation exists per Dispatch job + customer + carrier.
Quote revisions and the eventual awarded job therefore stay in the same chat
instead of creating duplicate threads.

## Authorization boundary

The server, never the client, resolves participants from existing Dispatch
records:

- customer from `dispatch_jobs/{jobId}.createdByUid`;
- carrier from the selected `dispatch_bids/{bidId}` quote before award; or
- carrier/bid from `dispatch_transactions/{jobId}` after award.

Only that customer or carrier may open the contextual conversation. The
conversation copies only a bounded job title, participant identity labels,
job/bid IDs, and quote reference. It does not copy private route points,
private addresses, exact yards/jobsites, or `dispatch_job_private` data.

## User entry points

- Customer quote comparison: **Message carrier** beside each carrier quote.
- Carrier quote view: **Message customer**.
- Awarded transport progress: participant-facing **Message carrier/customer**
  action that reopens the same deterministic job conversation.

## Scope

Durable files for this slice are limited to:

1. `firebase/functions/communication_commands.js`
2. `firebase/functions/index.js`
3. `firebase/functions/integration/callable_integration.mjs`
4. `firebase/functions/test/dispatch_context_messaging_contract.test.js`
5. `lib/marketplace/marketplace_actions_repository.dart`
6. `lib/marketplace/marketplace_dispatch_messaging.dart`
7. `lib/marketplace/marketplace_dispatch_page.dart`
8. `lib/marketplace/marketplace_dispatch_transaction.dart`
9. `test/marketplace_dispatch_job_quote_messaging_test.dart`
10. `docs/DISPATCH_RELEASE3_JOB_QUOTE_MESSAGING.md`

No Firestore Rules/schema rewrite, award-state redesign, carrier-status
redesign, payment changes, listing changes, or second chat datastore belongs
in this slice.

## Verification gate

Before merge:

- temporary patch tooling must parse in memory before mutation;
- exact ten-file durable mutation scope must pass;
- generated Dart files must be formatter-stable;
- `dart analyze lib test` must pass;
- focused Dispatch messaging tests must pass;
- full Flutter regression must pass;
- focused Node messaging contract tests must pass;
- both Functions codebases must install/lint/check successfully;
- repository release-contract tests must pass; and
- `git diff --check` must pass.

Protected production deployment must additionally prove authenticated callable
integration, post-deploy Function parity, exact release identity, and responsive
production visual acceptance.

## Checklist

- [x] Existing award and carrier milestone workflow audited; no rebuild needed.
- [x] Existing Marketplace messaging/block/attachment infrastructure audited.
- [ ] Participant-scoped `openDispatchConversation` implemented and verified.
- [ ] Customer quote `Message carrier` action verified.
- [ ] Carrier quote `Message customer` action verified.
- [ ] Awarded-job participant messaging action verified.
- [ ] Temporary verifier tooling removed.
- [ ] Feature PR merged.
- [ ] Exact merged application SHA deployed through protected production workflow.
- [ ] Post-deploy parity and responsive visual acceptance confirmed.
- [ ] Final production evidence recorded here.

## Permanent implementation rule

Do not create `dispatch_messages`, copy private Dispatch location data into chat,
or trust a client-supplied participant UID. Resolve participants from server-owned
job/quote/transaction records and continue using the existing conversation send,
block, report, upload, and unread-count infrastructure.
