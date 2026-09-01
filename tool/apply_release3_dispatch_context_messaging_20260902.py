from pathlib import Path
from textwrap import dedent

ROOT = Path('.')


def replace_once(path: str, old: str, new: str, label: str) -> None:
    target = ROOT / path
    source = target.read_text(encoding='utf-8')
    count = source.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one anchor, found {count}')
    target.write_text(source.replace(old, new, 1), encoding='utf-8')


# Server: deterministic Dispatch conversation identity.
replace_once(
    'firebase/functions/communication_commands.js',
    '''function businessConversationIdFor(firstUid, secondUid) {
  const members = [String(firstUid), String(secondUid)].sort();
  const digest = crypto.createHash("sha256")
      .update(members.join("|"))
      .digest("hex")
      .slice(0, 40);
  return `business_${digest}`;
}
''',
    '''function businessConversationIdFor(firstUid, secondUid) {
  const members = [String(firstUid), String(secondUid)].sort();
  const digest = crypto.createHash("sha256")
      .update(members.join("|"))
      .digest("hex")
      .slice(0, 40);
  return `business_${digest}`;
}

function dispatchConversationIdFor(jobId, firstUid, secondUid) {
  const members = [String(firstUid), String(secondUid)].sort();
  const digest = crypto.createHash("sha256")
      .update(`${jobId}|${members.join("|")}`)
      .digest("hex")
      .slice(0, 40);
  return `dispatch_${digest}`;
}
''',
    'Dispatch conversation identity helper',
)

open_dispatch = r'''  const openDispatchConversation = secured(
      "messaging",
      async (request, {uid}) => {
        const jobId = requiredId(request.data, "jobId");
        const requestedBidId = String(
            request.data && request.data.bidId || "",
        ).trim();
        if (requestedBidId &&
            (requestedBidId.length > 180 || requestedBidId.includes("/"))) {
          throw new HttpsError(
              "invalid-argument",
              "bidId is invalid.",
          );
        }

        const jobRef = db.collection("dispatch_jobs").doc(jobId);
        const dispatchRef = db.collection("dispatch_transactions").doc(jobId);
        return db.runTransaction(async (transaction) => {
          const jobSnapshot = await transaction.get(jobRef);
          if (!jobSnapshot.exists) {
            throw new HttpsError(
                "not-found",
                "This Dispatch job is unavailable.",
            );
          }
          const job = jobSnapshot.data() || {};
          const customerUid = String(job.createdByUid || "").trim();
          if (!customerUid) {
            throw new HttpsError(
                "failed-precondition",
                "This Dispatch job has no available customer.",
            );
          }

          let bidId = requestedBidId;
          let dispatchTransaction = null;
          if (!bidId) {
            const dispatchSnapshot = await transaction.get(dispatchRef);
            if (!dispatchSnapshot.exists) {
              throw new HttpsError(
                  "failed-precondition",
                  "Select a carrier quote before starting this Dispatch conversation.",
              );
            }
            dispatchTransaction = dispatchSnapshot.data() || {};
            bidId = String(dispatchTransaction.bidId || "").trim();
          }

          let bid = null;
          if (bidId) {
            const bidSnapshot = await transaction.get(
                db.collection("dispatch_bids").doc(bidId),
            );
            if (!bidSnapshot.exists ||
                String(bidSnapshot.data().jobId || "") !== jobId) {
              throw new HttpsError(
                  "permission-denied",
                  "This carrier quote does not belong to the Dispatch job.",
              );
            }
            bid = bidSnapshot.data() || {};
          }

          const carrierUid = String(
              bid && bid.carrierUid ||
              dispatchTransaction && dispatchTransaction.carrierUid ||
              "",
          ).trim();
          if (!carrierUid || carrierUid === customerUid) {
            throw new HttpsError(
                "failed-precondition",
                "This Dispatch job has no available carrier participant.",
            );
          }
          if (uid !== customerUid && uid !== carrierUid) {
            throw new HttpsError(
                "permission-denied",
                "Only this Dispatch job's customer and carrier can open its conversation.",
            );
          }

          const conversationId = dispatchConversationIdFor(
              jobId,
              customerUid,
              carrierUid,
          );
          const conversationRef = db.collection("conversations")
              .doc(conversationId);
          const [
            conversationSnapshot,
            customerBusiness,
            customerPersonal,
            carrierBusiness,
          ] = await Promise.all([
            transaction.get(conversationRef),
            transaction.get(
                db.collection("public_business_profiles").doc(customerUid),
            ),
            transaction.get(
                db.collection("public_seller_profiles").doc(customerUid),
            ),
            transaction.get(
                db.collection("public_business_profiles").doc(carrierUid),
            ),
          ]);
          const customerName = profileName(
              customerBusiness.exists ? customerBusiness.data() :
                customerPersonal.exists ? customerPersonal.data() : {},
              "Dispatch customer",
          );
          const carrierName = String(bid && bid.carrierName || "").trim() ||
            profileName(
                carrierBusiness.exists ? carrierBusiness.data() : {},
                "Dispatch carrier",
            );
          const jobTitle = String(job.title || "Transport job")
              .trim()
              .slice(0, 180) || "Transport job";
          const contextTitle = `Dispatch · ${jobTitle}`;
          const quoteReference = String(
              bid && bid.quoteReference || "",
          ).trim();

          if (!conversationSnapshot.exists) {
            const memberUids = [customerUid, carrierUid].sort();
            transaction.create(conversationRef, {
              memberUids,
              contextType: "dispatch_job",
              contextId: jobId,
              contextTitle,
              dispatchJobId: jobId,
              dispatchBidId: bidId || null,
              dispatchQuoteReference: quoteReference || null,
              customerUid,
              carrierUid,
              requesterUid: customerUid,
              requesterDisplayName: customerName,
              providerUid: carrierUid,
              sellerUid: carrierUid,
              sellerName: carrierName,
              buyerDisplayName: customerName,
              listingId: null,
              listingTitle: contextTitle,
              openedByUid: uid,
              openedAt: FieldValue.serverTimestamp(),
              messageCount: 0,
              unreadCounts: {[customerUid]: 0, [carrierUid]: 0},
            });
          } else {
            const existing = conversationSnapshot.data() || {};
            const members = Array.isArray(existing.memberUids) ?
              existing.memberUids.map(String) : [];
            if (existing.contextType !== "dispatch_job" ||
                existing.contextId !== jobId ||
                !members.includes(customerUid) ||
                !members.includes(carrierUid)) {
              throw new HttpsError(
                  "permission-denied",
                  "This Dispatch conversation is unavailable.",
              );
            }
          }
          return {conversationId};
        });
      },
  );

'''
replace_once(
    'firebase/functions/communication_commands.js',
    '  const markMarketplaceConversationRead = secured(\n',
    open_dispatch + '  const markMarketplaceConversationRead = secured(\n',
    'Dispatch conversation opener',
)
replace_once(
    'firebase/functions/communication_commands.js',
    '    openMarketplaceConversation,\n    openBusinessConversation,\n    sendMarketplaceMessage,\n',
    '    openMarketplaceConversation,\n    openBusinessConversation,\n    openDispatchConversation,\n    sendMarketplaceMessage,\n',
    'Communication command export',
)

# Cloud Function export inherits the same policy-acceptance and App Check gate.
index_anchor = '''exports.openBusinessConversation = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    communicationCommands.openBusinessConversation,
  ),
);
'''
replace_once(
    'firebase/functions/index.js',
    index_anchor,
    index_anchor + '''exports.openDispatchConversation = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    communicationCommands.openDispatchConversation,
  ),
);
''',
    'Dispatch conversation callable export',
)

# Emulator integration proves participant authorization and deterministic reuse.
quote_anchor = '''  const quoteRetry = await call(
      "submitDispatchQuote",
      carrier.token,
      quoteData,
  );
  assert.deepEqual(quoteRetry, quoteFirst);
'''
quote_tests = quote_anchor + '''  const dispatchConversationFirst = await call(
      "openDispatchConversation",
      buyer.token,
      {jobId, bidId: quoteFirst.bidId},
  );
  const dispatchConversationCarrier = await call(
      "openDispatchConversation",
      carrier.token,
      {jobId, bidId: quoteFirst.bidId},
  );
  assert.deepEqual(dispatchConversationCarrier, dispatchConversationFirst);
  const dispatchConversationSnapshot = await db.doc(
      `conversations/${dispatchConversationFirst.conversationId}`,
  ).get();
  const dispatchConversation = dispatchConversationSnapshot.data();
  assert.equal(dispatchConversation.contextType, "dispatch_job");
  assert.equal(dispatchConversation.contextId, jobId);
  assert.equal(dispatchConversation.dispatchJobId, jobId);
  assert.equal(dispatchConversation.dispatchBidId, quoteFirst.bidId);
  assert.deepEqual(
      dispatchConversation.memberUids,
      [buyer.uid, carrier.uid].sort(),
  );
  assert.equal(dispatchConversation.listingId, null);
  assert.equal("pickupPoint" in dispatchConversation, false);
  assert.equal("deliveryPoint" in dispatchConversation, false);
  await expectCallableError(
      "openDispatchConversation",
      seller.token,
      {jobId, bidId: quoteFirst.bidId},
      "PERMISSION_DENIED",
  );
'''
replace_once(
    'firebase/functions/integration/callable_integration.mjs',
    quote_anchor,
    quote_tests,
    'Pre-award Dispatch messaging integration',
)
award_anchor = '  assert.deepEqual(awardRetry, awardFirst);\n'
replace_once(
    'firebase/functions/integration/callable_integration.mjs',
    award_anchor,
    award_anchor + '''  const dispatchConversationAfterAward = await call(
      "openDispatchConversation",
      buyer.token,
      {jobId},
  );
  assert.deepEqual(
      dispatchConversationAfterAward,
      dispatchConversationFirst,
  );
''',
    'Post-award Dispatch messaging integration',
)

# Client repository exposes only job/bid context; the server resolves participants.
actions_anchor = '''  Future<String> openBusinessConversation({
    required String providerUid,
  }) async {
    final normalized = providerUid.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
          providerUid, 'providerUid', 'Provider is required.');
    }
    final result = await _commands.execute('openBusinessConversation', {
      'providerUid': normalized,
    });
    return '${result['conversationId']}';
  }
'''
actions_replacement = actions_anchor + '''
  Future<String> openDispatchConversation({
    required String jobId,
    String? bidId,
  }) async {
    final normalizedJobId = jobId.trim();
    final normalizedBidId = bidId?.trim() ?? '';
    if (normalizedJobId.isEmpty) {
      throw ArgumentError.value(jobId, 'jobId', 'Dispatch job is required.');
    }
    final result = await _commands.execute('openDispatchConversation', {
      'jobId': normalizedJobId,
      if (normalizedBidId.isNotEmpty) 'bidId': normalizedBidId,
    });
    return '${result['conversationId']}';
  }
'''
replace_once(
    'lib/marketplace/marketplace_actions_repository.dart',
    actions_anchor,
    actions_replacement,
    'Dispatch messaging repository method',
)

# Shared navigation/error handling keeps Dispatch UI entry points simple.
(ROOT / 'lib/marketplace/marketplace_dispatch_messaging.dart').write_text(
    dedent('''
    import 'package:flutter/material.dart';
    import 'package:go_router/go_router.dart';

    import '../core/accessibility/pipe_status_feedback.dart';
    import 'marketplace_actions_repository.dart';
    import 'marketplace_deep_links.dart';

    Future<void> openDispatchContextConversation(
      BuildContext context, {
      required String jobId,
      String? bidId,
    }) async {
      final normalizedJobId = jobId.trim();
      if (normalizedJobId.isEmpty) {
        PipeFeedback.show(
          context,
          message: 'This Dispatch job is unavailable.',
          tone: PipeStatusTone.error,
        );
        return;
      }
      try {
        final conversationId = await MarketplaceActionsRepository()
            .openDispatchConversation(jobId: normalizedJobId, bidId: bidId);
        if (!context.mounted) return;
        context.push(MarketplaceDeepLinks.conversation(conversationId));
      } catch (_) {
        if (!context.mounted) return;
        PipeFeedback.show(
          context,
          message:
              'The Dispatch conversation could not be opened. Confirm the job or quote is still available and try again.',
          tone: PipeStatusTone.error,
        );
      }
    }
    ''').lstrip(),
    encoding='utf-8',
)

# Customer bid comparison: message the carrier tied to that exact quote.
replace_once(
    'lib/marketplace/marketplace_dispatch_page.dart',
    "import 'marketplace_dispatch_transaction.dart';\n",
    "import 'marketplace_dispatch_transaction.dart';\nimport 'marketplace_dispatch_messaging.dart';\n",
    'Dispatch messaging page import',
)
customer_anchor = '''                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Quote history',
'''
customer_replacement = '''                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Message carrier',
                              onPressed: () async {
                                Navigator.pop(sheetContext);
                                await openDispatchContextConversation(
                                  context,
                                  jobId: jobId,
                                  bidId: bid.id,
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline),
                            ),
                            IconButton(
                              tooltip: 'Quote history',
'''
replace_once(
    'lib/marketplace/marketplace_dispatch_page.dart',
    customer_anchor,
    customer_replacement,
    'Customer quote messaging action',
)
carrier_anchor = '''                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: data['status'] == 'pending' &&
'''
carrier_replacement = '''                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await openDispatchContextConversation(
                        context,
                        jobId: job.id,
                        bidId: bid.id,
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message customer'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: data['status'] == 'pending' &&
'''
replace_once(
    'lib/marketplace/marketplace_dispatch_page.dart',
    carrier_anchor,
    carrier_replacement,
    'Carrier quote messaging action',
)

# Awarded transport card: both participants can reopen the same job conversation.
replace_once(
    'lib/marketplace/marketplace_dispatch_transaction.dart',
    "import 'marketplace_dispatch_repository.dart';\n",
    "import 'marketplace_dispatch_repository.dart';\nimport 'marketplace_dispatch_messaging.dart';\n",
    'Dispatch transaction messaging import',
)
transaction_anchor = '''                if (carrier || customer) ...[
                  const SizedBox(height: 20),
                  _participantActions(
                    carrier: carrier,
'''
transaction_replacement = '''                if (carrier || customer) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => openDispatchContextConversation(
                                context,
                                jobId: widget.jobId,
                              ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(
                        customer ? 'Message carrier' : 'Message customer',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _participantActions(
                    carrier: carrier,
'''
replace_once(
    'lib/marketplace/marketplace_dispatch_transaction.dart',
    transaction_anchor,
    transaction_replacement,
    'Awarded Dispatch messaging action',
)

# Node contract test: messaging stays participant-scoped and privacy bounded.
(ROOT / 'firebase/functions/test/dispatch_context_messaging_contract.test.js').write_text(
    dedent(r'''
    "use strict";

    const assert = require("node:assert/strict");
    const fs = require("node:fs");
    const path = require("node:path");
    const test = require("node:test");

    const root = path.resolve(__dirname, "../../..");
    const read = (relativePath) => fs.readFileSync(
        path.join(root, relativePath),
        "utf8",
    );

    test("Dispatch conversations use existing safe messaging infrastructure", () => {
      const source = read("firebase/functions/communication_commands.js");
      const start = source.indexOf("const openDispatchConversation = secured(");
      const end = source.indexOf(
          "const markMarketplaceConversationRead = secured(",
          start,
      );
      assert.ok(start >= 0 && end > start, "Dispatch opener must exist");
      const opener = source.slice(start, end);

      assert.match(opener, /collection\("dispatch_jobs"\)/);
      assert.match(opener, /collection\("dispatch_bids"\)/);
      assert.match(opener, /collection\("dispatch_transactions"\)/);
      assert.match(opener, /uid !== customerUid && uid !== carrierUid/);
      assert.match(opener, /contextType: "dispatch_job"/);
      assert.match(opener, /memberUids/);
      assert.match(opener, /listingId: null/);
      assert.doesNotMatch(opener, /dispatch_job_private/);
      assert.doesNotMatch(opener, /pickupPoint/);
      assert.doesNotMatch(opener, /deliveryPoint/);
      assert.doesNotMatch(opener, /deliveryAddress/);
    });

    test("Dispatch conversation callable is exported through protected index", () => {
      const index = read("firebase/functions/index.js");
      assert.match(index, /exports\.openDispatchConversation = onCall\(/);
      assert.match(
          index,
          /communicationCommands\.openDispatchConversation/,
      );
      assert.match(index, /policyAcceptanceCommands\.requireCurrentPolicies/);
    });
    ''').lstrip(),
    encoding='utf-8',
)

# Flutter source contract protects all three user entry points and shared routing.
(ROOT / 'test/marketplace_dispatch_job_quote_messaging_test.dart').write_text(
    dedent('''
    import 'dart:io';

    import 'package:flutter_test/flutter_test.dart';

    void main() {
      test('Dispatch job and quote messaging reuses Marketplace conversations', () {
        final actions = File(
          'lib/marketplace/marketplace_actions_repository.dart',
        ).readAsStringSync();
        final helper = File(
          'lib/marketplace/marketplace_dispatch_messaging.dart',
        ).readAsStringSync();
        final dispatchPage = File(
          'lib/marketplace/marketplace_dispatch_page.dart',
        ).readAsStringSync();
        final transaction = File(
          'lib/marketplace/marketplace_dispatch_transaction.dart',
        ).readAsStringSync();

        expect(actions, contains('Future<String> openDispatchConversation'));
        expect(actions, contains("_commands.execute('openDispatchConversation'"));
        expect(helper, contains('MarketplaceActionsRepository()'));
        expect(helper, contains('MarketplaceDeepLinks.conversation'));
        expect(dispatchPage, contains("tooltip: 'Message carrier'"));
        expect(dispatchPage, contains("label: const Text('Message customer')"));
        expect(dispatchPage, contains('bidId: bid.id'));
        expect(transaction, contains("customer ? 'Message carrier' : 'Message customer'"));
        expect(transaction, contains('jobId: widget.jobId'));
      });

      test('Dispatch messaging does not introduce a second message datastore', () {
        final helper = File(
          'lib/marketplace/marketplace_dispatch_messaging.dart',
        ).readAsStringSync();
        final server = File(
          'firebase/functions/communication_commands.js',
        ).readAsStringSync();

        expect(helper, isNot(contains("collection('dispatch_messages')")));
        expect(server, contains('db.collection("conversations")'));
        expect(server, contains('contextType: "dispatch_job"'));
        expect(server, isNot(contains('dispatch_messages')));
      });
    }
    ''').lstrip(),
    encoding='utf-8',
)

# Permanent implementation record.
(ROOT / 'docs/DISPATCH_RELEASE3_JOB_QUOTE_MESSAGING.md').write_text(
    dedent('''
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
    ''').lstrip(),
    encoding='utf-8',
)
