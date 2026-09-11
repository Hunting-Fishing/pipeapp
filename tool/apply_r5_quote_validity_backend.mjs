import fs from 'node:fs';

function read(path) {
  return fs.readFileSync(path, 'utf8');
}

function write(path, value) {
  fs.writeFileSync(path, value);
}

function replaceOnce(source, oldValue, newValue, label) {
  const count = source.split(oldValue).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one marker, found ${count}`);
  }
  return source.replace(oldValue, newValue);
}

function insertBeforeOnce(source, marker, insertion, label) {
  const count = source.split(marker).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one marker, found ${count}`);
  }
  return source.replace(marker, `${insertion}${marker}`);
}

// Server policy: explicit validity state, cancellation authority, fail-closed awards.
{
  const path = 'firebase/functions/dispatch_command_policy.js';
  let source = read(path);

  const oldExistingBidGuard = `  if (\n    existingBid &&\n    (existingBid.carrierUid !== actorUid ||\n     existingBid.jobId !== data.jobId ||\n     existingBid.status !== "pending")\n  ) {`;
  const newExistingBidGuard = `  if (\n    existingBid &&\n    (existingBid.carrierUid !== actorUid ||\n     existingBid.jobId !== data.jobId ||\n     !["pending", "cancelled"].includes(existingBid.status) ||\n     (existingBid.status === "pending" &&\n       dispatchQuoteValidityStatus(existingBid) !== "active") ||\n     (existingBid.status === "cancelled" &&\n       dispatchQuoteValidityStatus(existingBid) !== "cancelled"))\n  ) {`;
  source = replaceOnce(
      source,
      oldExistingBidGuard,
      newExistingBidGuard,
      'existing quote revision guard',
  );

  const helpers = `function dispatchQuoteValidityStatus(bid) {\n  const raw = String(bid && bid.validityStatus || "").trim().toLowerCase();\n  if (!raw) return "active";\n  if (["active", "cancelled"].includes(raw)) return raw;\n  return "invalid";\n}\n\nfunction validateDispatchQuoteCancellation({\n  job,\n  bid,\n  actorUid,\n  reason = "",\n}) {\n  if (!bid || !job || bid.jobId !== job.id) {\n    throw new CommandPolicyError(\n        "not-found",\n        "This carrier quote is unavailable.",\n    );\n  }\n  if (bid.carrierUid !== actorUid) {\n    throw new CommandPolicyError(\n        "permission-denied",\n        "Only the submitting carrier can cancel this quote.",\n    );\n  }\n  const validityStatus = dispatchQuoteValidityStatus(bid);\n  if (bid.status === "cancelled" && validityStatus === "cancelled") {\n    return {\n      alreadyApplied: true,\n      reason: String(bid.cancellationReason || reason || "").trim(),\n    };\n  }\n  if (job.status !== "open" ||\n      bid.status !== "pending" ||\n      validityStatus !== "active") {\n    throw new CommandPolicyError(\n        "failed-precondition",\n        "This carrier quote can no longer be cancelled.",\n    );\n  }\n  const cancellationReason = String(reason || "").trim();\n  if (cancellationReason.length > 500) {\n    throw new CommandPolicyError(\n        "invalid-argument",\n        "Quote cancellation reason must be 500 characters or fewer.",\n    );\n  }\n  return {alreadyApplied: false, reason: cancellationReason};\n}\n\n`;
  source = insertBeforeOnce(
      source,
      'function validateDispatchAward(job, bid, actorUid) {',
      helpers,
      'quote validity policy insertion',
  );

  source = replaceOnce(
      source,
      `    bid.jobId !== job.id ||\n    bid.status !== "pending" ||\n    !String(bid.carrierUid || "") ||`,
      `    bid.jobId !== job.id ||\n    bid.status !== "pending" ||\n    dispatchQuoteValidityStatus(bid) !== "active" ||\n    !String(bid.carrierUid || "") ||`,
      'award validity guard',
  );

  source = replaceOnce(
      source,
      `  rejectClientRouteFields,\n  validateDispatchAward,`,
      `  dispatchQuoteValidityStatus,\n  rejectClientRouteFields,\n  validateDispatchAward,`,
      'policy export validity status',
  );
  source = replaceOnce(
      source,
      `  validateDispatchQuote,\n  validateDispatchQuoteBreakdown,`,
      `  validateDispatchQuote,\n  validateDispatchQuoteBreakdown,\n  validateDispatchQuoteCancellation,`,
      'policy export cancellation',
  );
  write(path, source);
}

// Server commands: stable quote identity, separate quoteVersion/audit revision,
// cancellation event, customer notification, and callable exposure.
{
  const path = 'firebase/functions/dispatch_commands.js';
  let source = read(path);

  source = replaceOnce(
      source,
      `  validateDispatchQuote,\n  validateDispatchProviderApplication,`,
      `  validateDispatchQuote,\n  validateDispatchQuoteCancellation,\n  validateDispatchProviderApplication,`,
      'dispatch cancellation policy import',
  );

  source = replaceOnce(
      source,
      `          (candidate) =>\n            candidate.data().carrierUid === uid &&\n            candidate.data().status === "pending",`,
      `          (candidate) =>\n            candidate.data().carrierUid === uid &&\n            ["pending", "cancelled"].includes(candidate.data().status),`,
      'carrier quote identity lookup',
  );

  source = replaceOnce(
      source,
      `      const revision = existingBid ?\n        Number(existingBid.revision || 1) + 1 :\n        1;\n      const carrierName =`,
      `      const revision = existingBid ?\n        Number(existingBid.revision || 1) + 1 :\n        1;\n      const quoteVersion = existingBid ?\n        Number(existingBid.quoteVersion || existingBid.revision || 1) + 1 :\n        1;\n      const carrierName =`,
      'quote version counter',
  );

  source = replaceOnce(
      source,
      `        quoteVersion: revision,\n        validityStatus: "active",\n        note: quote.note,`,
      `        quoteVersion,\n        validityStatus: "active",\n        supersededThroughVersion: Math.max(0, quoteVersion - 1),\n        cancellationReason: null,\n        cancelledAt: null,\n        note: quote.note,`,
      'active quote validity values',
  );

  source = replaceOnce(
      source,
      `        revision,\n        quoteReference: values.quoteReference,\n        created: !existingBid,`,
      `        revision,\n        quoteVersion,\n        quoteReference: values.quoteReference,\n        created: !existingBid,`,
      'submit quote result version',
  );

  const cancellationCommand = `  const cancelDispatchQuote = dispatchCommand(async (request) => {\n    const uid = requireAuth(request);\n    const requestId = requiredId(request.data, "requestId");\n    const bidId = requiredId(request.data, "bidId");\n    const receiptRef = receiptReference(\n        db,\n        uid,\n        "cancelDispatchQuote",\n        requestId,\n    );\n    const bidRef = db.collection("dispatch_bids").doc(bidId);\n\n    return db.runTransaction(async (transaction) => {\n      const receipt = await transaction.get(receiptRef);\n      if (receipt.exists) return receipt.data().result;\n      const bidSnapshot = await transaction.get(bidRef);\n      const bidData = bidSnapshot.exists ? bidSnapshot.data() : null;\n      const jobId = String(bidData && bidData.jobId || "");\n      const jobRef = jobId ? db.collection("dispatch_jobs").doc(jobId) : null;\n      const jobSnapshot = jobRef ? await transaction.get(jobRef) : null;\n      const jobData = jobSnapshot && jobSnapshot.exists ? jobSnapshot.data() : null;\n      const job = jobData ? {...jobData, id: jobId} : null;\n      const cancellation = validateDispatchQuoteCancellation({\n        job,\n        bid: bidData,\n        actorUid: uid,\n        reason: request.data && request.data.reason,\n      });\n      const quoteVersion = Number(\n          bidData.quoteVersion || bidData.revision || 1,\n      );\n      if (cancellation.alreadyApplied) {\n        const result = {\n          bidId,\n          jobId,\n          quoteVersion,\n          status: "cancelled",\n          validityStatus: "cancelled",\n          alreadyCancelled: true,\n        };\n        transaction.create(receiptRef, {\n          actorUid: uid,\n          command: "cancelDispatchQuote",\n          result,\n          createdAt: FieldValue.serverTimestamp(),\n        });\n        return result;\n      }\n\n      const revision = Number(bidData.revision || 1) + 1;\n      const changes = {\n        status: "cancelled",\n        validityStatus: "cancelled",\n        cancellationReason: cancellation.reason || "",\n        cancelledAt: FieldValue.serverTimestamp(),\n        revision,\n        updatedAt: FieldValue.serverTimestamp(),\n      };\n      const result = {\n        bidId,\n        jobId,\n        revision,\n        quoteVersion,\n        status: "cancelled",\n        validityStatus: "cancelled",\n        alreadyCancelled: false,\n      };\n      transaction.update(bidRef, changes);\n      transaction.create(\n          bidRef.collection("revisions").doc(String(revision)),\n          {\n            ...bidData,\n            ...changes,\n            quoteVersion,\n            event: "quote_cancelled",\n            actorUid: uid,\n            createdAt: FieldValue.serverTimestamp(),\n          },\n      );\n      transaction.set(\n          db.collection("users")\n              .doc(job.createdByUid)\n              .collection("notifications")\n              .doc(receiptRef.id),\n          {\n            recipientUid: job.createdByUid,\n            actorUid: uid,\n            type: "dispatch",\n            jobId,\n            bidId,\n            title: "Carrier quote cancelled",\n            body: cancellation.reason ?\n              \`The carrier cancelled Version \${quoteVersion}: \${cancellation.reason}\` :\n              \`The carrier cancelled Version \${quoteVersion} of their Dispatch quote.\`,\n            read: false,\n            createdAt: FieldValue.serverTimestamp(),\n          },\n      );\n      transaction.create(receiptRef, {\n        actorUid: uid,\n        command: "cancelDispatchQuote",\n        result,\n        createdAt: FieldValue.serverTimestamp(),\n      });\n      return result;\n    });\n  });\n\n`;
  source = insertBeforeOnce(
      source,
      '  const awardDispatchQuote = dispatchCommand(async (request) => {',
      cancellationCommand,
      'cancel quote command insertion',
  );

  source = replaceOnce(
      source,
      `  return {\n    awardDispatchQuote,\n    createDispatchJob,`,
      `  return {\n    awardDispatchQuote,\n    cancelDispatchQuote,\n    createDispatchJob,`,
      'cancel quote command export',
  );
  write(path, source);
}

// Public callable uses the same protected App Check + current-policy wrapper as
// the existing Dispatch quote commands.
{
  const path = 'firebase/functions/index.js';
  let source = read(path);
  const marker = `exports.submitDispatchQuote = onCall(\n  protectedCallableOptions,\n  policyAcceptanceCommands.requireCurrentPolicies(\n    dispatchCommands.submitDispatchQuote,\n  ),\n);\n`;
  const insertion = `exports.cancelDispatchQuote = onCall(\n  protectedCallableOptions,\n  policyAcceptanceCommands.requireCurrentPolicies(\n    dispatchCommands.cancelDispatchQuote,\n  ),\n);\n`;
  if (!source.includes(insertion)) {
    source = insertBeforeOnce(source, marker, insertion, 'cancel callable export');
  }
  write(path, source);
}

// Flutter repository command wrapper.
{
  const path = 'lib/marketplace/marketplace_dispatch_repository.dart';
  let source = read(path);
  const insertion = `  Future<void> cancelBid({\n    required String bidId,\n    String reason = '',\n  }) async {\n    await _commands.execute('cancelDispatchQuote', {\n      'requestId': _firestore.collection('dispatch_bids').doc().id,\n      'bidId': bidId,\n      if (reason.trim().isNotEmpty) 'reason': reason.trim(),\n    });\n  }\n\n`;
  if (!source.includes('Future<void> cancelBid({')) {
    source = insertBeforeOnce(
        source,
        '  Future<void> updateBid({',
        insertion,
        'repository cancel quote method',
    );
  }
  write(path, source);
}

console.log('R5 Quote V2 B2 backend validity/cancellation transform applied.');
