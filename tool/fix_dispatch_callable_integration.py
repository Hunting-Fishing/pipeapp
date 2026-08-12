from pathlib import Path

p = Path('firebase/functions/integration/callable_integration.mjs')
text = p.read_text(encoding='utf-8')

old = '''    db.doc(`users/${carrier.uid}`).set({
      displayName: "Production Carrier",
      userScore: 90,
      profileCompletion: 100,
      accountVerified: true,
      accountVerificationReviewVersion: 1,
    }),'''
new = '''    db.doc(`users/${carrier.uid}`).set({
      displayName: "Production Carrier",
      display_name: "Production Carrier",
      baseCommunity: "Dawson Creek, British Columbia",
      sellerBio: "Integration carrier providing regional trucking services.",
      userScore: 90,
      profileCompletion: 100,
      accountVerified: true,
      accountVerificationReviewVersion: 1,
    }),'''
if text.count(old) != 1:
    raise RuntimeError('carrier fixture block did not match exactly once')
text = text.replace(old, new, 1)

old = '''  assert.deepEqual(providerRetry, providerFirst);
  assert.equal(providerFirst.status, "pending_review");
  assert.equal(
      (await db.doc(`dispatch_carriers/${carrier.uid}`).get()).data().status,
      "pending_review",
  );
  const providerReviewRequest = {
    auth: reviewRequest.auth,
    data: {
      requestId: `dispatch-provider-review-${now}`,
      providerUid: carrier.uid,
      decision: "approved",
      reason: "Verified public operating information and service coverage.",
    },
  };
  const providerReviewFirst = await dispatchCommands
      .reviewDispatchProvider(providerReviewRequest);
  const providerReviewRetry = await dispatchCommands
      .reviewDispatchProvider(providerReviewRequest);
  assert.deepEqual(providerReviewRetry, providerReviewFirst);
  assert.equal(providerReviewFirst.status, "active");
  assert.equal(
      (await db.doc(`dispatch_carriers/${carrier.uid}`).get()).data().status,
      "active",
  );'''
new = '''  assert.deepEqual(providerRetry, providerFirst);
  assert.equal(providerFirst.status, "active");
  assert.ok(providerFirst.profileCompletion >= 70);
  const carrierProfile = (
    await db.doc(`dispatch_carriers/${carrier.uid}`).get()
  ).data();
  assert.equal(carrierProfile.status, "active");
  assert.ok(carrierProfile.profileCompletionAtSignup >= 70);
  assert.match(carrierProfile.verifiedContactMethod, /email|phone/);'''
if text.count(old) != 1:
    raise RuntimeError('legacy provider review integration block did not match exactly once')
text = text.replace(old, new, 1)

p.write_text(text, encoding='utf-8')
print('Dispatch callable integration fixture updated for immediate eligibility-based signup.')
