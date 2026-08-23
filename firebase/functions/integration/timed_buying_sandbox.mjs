import crypto from 'node:crypto';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';

function loopbackHost(value, label) {
  const normalized = String(value || '').trim();
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(normalized)) {
    throw new Error(`${label} must target a local emulator. Refusing ${normalized}`);
  }
  return normalized;
}

const authHost = loopbackHost(
  process.env.FIREBASE_AUTH_EMULATOR_HOST,
  'FIREBASE_AUTH_EMULATOR_HOST',
);
const firestoreHost = loopbackHost(
  process.env.FIRESTORE_EMULATOR_HOST,
  'FIRESTORE_EMULATOR_HOST',
);
const functionsHost = loopbackHost(
  process.env.FUNCTIONS_EMULATOR_HOST,
  'FUNCTIONS_EMULATOR_HOST',
);

process.env.FIRESTORE_EMULATOR_HOST = firestoreHost;
const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'flutter-flow-pipe';
if (projectId !== 'flutter-flow-pipe') {
  throw new Error(`Timed Buying sandbox test requires flutter-flow-pipe, not ${projectId}.`);
}

const app = initializeApp({projectId}, `timed-buying-smoke-${Date.now()}`);
const db = getFirestore(app);
const listingId = 'visual-auction-dozer';
const buyerUid = 'visual-buyer';
const buyerEmail = 'buyer.visual@pipebuyer.test';
const password = 'PipeBuyerDemo!2026';

function receiptId(amount) {
  return crypto
    .createHash('sha256')
    .update(`${buyerUid}|placeAuctionBid|${JSON.stringify({listingId, amount})}`)
    .digest('hex');
}

async function signIn() {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=pipebuyer-local`,
    {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({email: buyerEmail, password, returnSecureToken: true}),
    },
  );
  const data = await response.json();
  if (!response.ok || data.localId !== buyerUid || !data.idToken) {
    throw new Error(`Timed Buying test buyer could not sign in: ${JSON.stringify(data)}`);
  }
  return data.idToken;
}

async function callPlaceTimedOffer(idToken, amount) {
  const response = await fetch(
    `http://${functionsHost}/${projectId}/us-central1/placeAuctionBid`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${idToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({data: {listingId, amount}}),
    },
  );
  const payload = await response.json();
  if (!response.ok || !payload.result) {
    const details = payload?.error?.message || JSON.stringify(payload);
    throw new Error(`Submit Timed Offer callable failed: ${details}`);
  }
  return payload.result;
}

async function clearInterruptedSmokeArtifacts(amount, before) {
  const receipt = receiptId(amount);
  const receiptRef = db.collection('marketplace_command_receipts').doc(receipt);
  const receiptSnapshot = await receiptRef.get();
  if (!receiptSnapshot.exists) return;

  const staleResult = receiptSnapshot.data()?.result || {};
  const staleBidId = String(staleResult.bidId || '').trim();
  const deterministicLeadId = String(before.currentBidId || '').trim();
  const deletes = [
    receiptRef.delete(),
    db.collection('users')
      .doc(String(before.sellerUid || 'visual-seller'))
      .collection('notifications')
      .doc(receipt)
      .delete(),
  ];
  if (staleBidId && staleBidId !== deterministicLeadId) {
    deletes.push(db.collection('auction_bids').doc(staleBidId).delete());
  }
  await Promise.all(deletes);
  console.log('Cleared stale Timed Buying smoke-test receipt from an interrupted prior run.');
}

async function restoreFixture({before, previousBidRef, previousBidSnapshot, result, amount}) {
  const listingRef = db.collection('public_listings').doc(listingId);
  await listingRef.set(before, {merge: false});

  if (result?.bidId) {
    const generatedBidId = String(result.bidId);
    const deterministicLeadId = String(before.currentBidId || '').trim();
    if (generatedBidId && generatedBidId !== deterministicLeadId) {
      await db.collection('auction_bids').doc(generatedBidId).delete();
    }
  }

  if (previousBidRef && previousBidSnapshot?.exists) {
    await previousBidRef.set(previousBidSnapshot.data(), {merge: false});
  }

  const receipt = receiptId(amount);
  await Promise.all([
    db.collection('marketplace_command_receipts').doc(receipt).delete(),
    db.collection('users').doc(String(before.sellerUid || 'visual-seller'))
      .collection('notifications').doc(receipt).delete(),
  ]);
  await listingRef.update({
    lastBidAt: before.lastBidAt ?? FieldValue.delete(),
    updatedAt: before.updatedAt ?? FieldValue.delete(),
  });
}

async function main() {
  const listingRef = db.collection('public_listings').doc(listingId);
  const beforeSnapshot = await listingRef.get();
  if (!beforeSnapshot.exists) {
    throw new Error('Timed Buying smoke fixture is missing. Reseed the visual sandbox first.');
  }
  const before = beforeSnapshot.data();
  const current = Number(before.currentBid || before.startingBid || 0);
  const increment = Number(before.minimumBidIncrement || 1);
  if (!Number.isFinite(current) || !Number.isFinite(increment) || increment <= 0) {
    throw new Error('Timed Buying fixture has invalid offer pricing fields.');
  }
  const amount = current + increment;
  const previousBidId = String(before.currentBidId || '').trim();
  const previousBidRef = previousBidId
    ? db.collection('auction_bids').doc(previousBidId)
    : null;
  const previousBidSnapshot = previousBidRef ? await previousBidRef.get() : null;

  // The callable is intentionally idempotent. An interrupted prior smoke run can
  // leave its receipt behind even after the deterministic listing is reseeded.
  // Clear only this emulator-only smoke receipt (and its generated bid) before
  // exercising the callable again so a cached result cannot masquerade as a
  // fresh write.
  await clearInterruptedSmokeArtifacts(amount, before);

  const idToken = await signIn();
  let result = null;
  let passed = false;
  try {
    result = await callPlaceTimedOffer(idToken, amount);
    const after = await listingRef.get();
    const afterData = after.data() || {};
    if (Number(afterData.currentBid || 0) !== amount) {
      throw new Error(
        `Timed Buying callable returned but leading offer did not update. Expected ${amount}, found ${afterData.currentBid}.`,
      );
    }
    if (Number(afterData.bidCount || 0) !== Number(before.bidCount || 0) + 1) {
      throw new Error('Timed Buying offer count did not increment.');
    }
    if (!result.bidId || String(afterData.currentBidId || '') !== String(result.bidId)) {
      throw new Error('Timed Buying leading offer reference did not match callable result.');
    }

    console.log('Timed Buying callable smoke test passed.');
    console.log(`  Buyer: ${buyerEmail}`);
    console.log(`  Listing: ${listingId}`);
    console.log(`  Submitted timed offer: ${amount}`);
    console.log(`  Callable offer record: ${result.bidId}`);
    passed = true;
  } finally {
    // Restore the deterministic fixture even when an assertion fails after the
    // callable returns. This keeps the next emulator run from inheriting a
    // receipt, generated offer or half-mutated leading state.
    await restoreFixture({
      before,
      previousBidRef,
      previousBidSnapshot,
      result,
      amount,
    });
    console.log('Timed Buying sandbox fixture restored after smoke test.');
  }

  if (!passed) {
    throw new Error('Timed Buying callable smoke test did not complete.');
  }
}

main()
  .then(() => deleteApp(app))
  .catch(async (error) => {
    console.error(error?.stack || error);
    await deleteApp(app).catch(() => {});
    process.exitCode = 1;
  });