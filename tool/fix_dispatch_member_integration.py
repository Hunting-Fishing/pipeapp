from pathlib import Path

p = Path('firebase/functions/integration/callable_integration.mjs')
text = p.read_text(encoding='utf-8')

old = '''    db.doc(`users/${buyer.uid}`).set({
      displayName: "Production Buyer",
      userScore: 90,
      profileCompletion: 100,
      accountVerified: true,
      accountVerificationReviewVersion: 1,
    }),'''
new = '''    db.doc(`users/${buyer.uid}`).set({
      displayName: "Production Buyer",
      display_name: "Production Buyer",
      baseCommunity: "Grande Prairie, Alberta",
      sellerBio: "Integration Dispatch customer posting regional transport work.",
      userScore: 90,
      profileCompletion: 100,
      accountVerified: true,
      accountVerificationReviewVersion: 1,
    }),'''
if text.count(old) != 1:
    raise RuntimeError('buyer profile fixture did not match exactly once')
text = text.replace(old, new, 1)

old = '''  assert.equal(carrierProfile.status, "active");
  assert.ok(carrierProfile.profileCompletionAtSignup >= 70);
  assert.match(carrierProfile.verifiedContactMethod, /email|phone/);
  await assertCollectionSize("account_phone_registry", 3);'''
new = '''  assert.equal(carrierProfile.status, "active");
  assert.ok(carrierProfile.profileCompletionAtSignup >= 70);
  assert.match(carrierProfile.verifiedContactMethod, /email|phone/);

  const dispatchCustomerRequest = {
    requestId: `dispatch-customer-${now}`,
    operatingName: "Production Buyer Dispatch",
    serviceAreaLabel: "Grande Prairie and within 250 km",
    serviceArea: {
      mode: "radius",
      center: {latitude: 55.1707, longitude: -118.7947},
      centerLabel: "Grande Prairie, Alberta",
      radiusKm: 250,
      places: [],
    },
  };
  const dispatchCustomer = await call(
      "submitDispatchProviderApplication",
      buyer.token,
      dispatchCustomerRequest,
  );
  assert.equal(dispatchCustomer.status, "active");
  assert.ok(dispatchCustomer.profileCompletion >= 70);
  assert.equal(
      (await db.doc(`dispatch_carriers/${buyer.uid}`).get()).data().status,
      "active",
  );
  await assertCollectionSize("account_phone_registry", 3);'''
if text.count(old) != 1:
    raise RuntimeError('carrier signup assertion block did not match exactly once')
text = text.replace(old, new, 1)

old = '''  const quoteData = {
    requestId: `quote-${now}`,'''
new = '''  await db.doc(`dispatch_memberships/${carrier.uid}`).set({
    ownerUid: carrier.uid,
    active: true,
    status: "active",
    plan: "monthly",
    currentPeriodStart: Timestamp.fromMillis(now - 1000),
    currentPeriodEnd: Timestamp.fromMillis(
        now + 30 * 24 * 60 * 60 * 1000,
    ),
  });

  const quoteData = {
    requestId: `quote-${now}`,'''
if text.count(old) != 1:
    raise RuntimeError('quote fixture block did not match exactly once')
text = text.replace(old, new, 1)

p.write_text(text, encoding='utf-8')
print('Dispatch member and paid-membership integration fixtures updated.')
