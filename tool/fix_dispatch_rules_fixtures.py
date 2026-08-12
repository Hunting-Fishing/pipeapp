from pathlib import Path

p = Path('firebase/rules-tests/firestore_rules.test.js')
text = p.read_text(encoding='utf-8')

old = '''    await setDoc(doc(db, "dispatch_carriers", "carrier"), {
      ownerUid: "carrier",
      operatingName: "Test Carrier",
      status: "active",
      availableForHire: true,
      providerReviewVersion: 1,
    });'''
new = '''    await setDoc(doc(db, "dispatch_carriers", "carrier"), {
      ownerUid: "carrier",
      operatingName: "Test Carrier",
      status: "active",
      availableForHire: true,
    });
    await setDoc(doc(db, "dispatch_carriers", "buyer"), {
      ownerUid: "buyer",
      operatingName: "Test Dispatch Customer",
      status: "active",
      availableForHire: false,
    });
    await setDoc(doc(db, "dispatch_memberships", "carrier"), {
      ownerUid: "carrier",
      active: true,
      status: "active",
      plan: "monthly",
      currentPeriodEnd: Timestamp.fromDate(new Date("2026-08-19T12:00:00.000Z")),
    });
    await setDoc(doc(db, "dispatch_pilot_requests", "pilot-request"), {
      requesterUid: "buyer",
      pickupLabel: "Grande Prairie",
      deliveryLabel: "Dawson Creek",
      details: "Oversize load escort",
      status: "open",
      requestedDate: Timestamp.fromDate(new Date("2026-07-20T12:00:00.000Z")),
    });'''
if text.count(old) != 1:
    raise RuntimeError('dispatch carrier fixture block not found exactly once')
text = text.replace(old, new, 1)

old = '''test("ownership verification and Dispatch provider approval cannot be forged", async () => {'''
new = '''test("ownership verification and Dispatch signup cannot be forged", async () => {'''
if text.count(old) != 1:
    raise RuntimeError('legacy dispatch signup test title not found')
text = text.replace(old, new, 1)

old = '''  await assertSucceeds(getDocs(query(
      collection(ownerDb, "dispatch_jobs"),
      where("createdByUid", "==", "buyer"),
      orderBy("updatedAt", "desc"),
      limit(24),
  )));
  await assertSucceeds(getDocs(query(
      collection(carrierDb, "dispatch_bids"),'''
new = '''  await assertSucceeds(getDocs(query(
      collection(ownerDb, "dispatch_jobs"),
      where("createdByUid", "==", "buyer"),
      orderBy("updatedAt", "desc"),
      limit(24),
  )));
  await assertFails(getDocs(query(
      collection(strangerDb, "dispatch_jobs"),
      where("status", "==", "open"),
      orderBy("createdAt", "desc"),
      limit(24),
  )));
  await assertSucceeds(getDocs(query(
      collection(carrierDb, "dispatch_bids"),'''
if text.count(old) != 1:
    raise RuntimeError('bounded dispatch discovery block not found')
text = text.replace(old, new, 1)

anchor = '''test("Dispatch transaction and proof history are participant-only", async () => {'''
insert = '''test("Dispatch membership and pilot-request access is server owned", async () => {
  const carrierDb = testEnvironment
      .authenticatedContext("carrier")
      .firestore();
  const customerDb = testEnvironment
      .authenticatedContext("buyer")
      .firestore();
  const strangerDb = testEnvironment
      .authenticatedContext("stranger")
      .firestore();

  await assertSucceeds(getDoc(doc(
      carrierDb,
      "dispatch_memberships",
      "carrier",
  )));
  await assertFails(getDoc(doc(
      customerDb,
      "dispatch_memberships",
      "carrier",
  )));
  await assertFails(updateDoc(doc(
      carrierDb,
      "dispatch_memberships",
      "carrier",
  ), {active: false}));

  await assertSucceeds(getDoc(doc(
      carrierDb,
      "dispatch_pilot_requests",
      "pilot-request",
  )));
  await assertSucceeds(getDoc(doc(
      customerDb,
      "dispatch_pilot_requests",
      "pilot-request",
  )));
  await assertFails(getDoc(doc(
      strangerDb,
      "dispatch_pilot_requests",
      "pilot-request",
  )));
  await assertFails(setDoc(doc(
      customerDb,
      "dispatch_pilot_requests",
      "forged",
  ), {requesterUid: "buyer", status: "open"}));
});

'''
if text.count(anchor) != 1:
    raise RuntimeError('dispatch transaction test anchor not found')
text = text.replace(anchor, insert + anchor, 1)

p.write_text(text, encoding='utf-8')
print('Dispatch rules fixtures updated for signed-up job visibility and pilot access.')
