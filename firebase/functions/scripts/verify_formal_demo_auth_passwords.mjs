const authHost = String(
  process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:19099',
).trim();

if (!/^(127\.0\.0\.1|localhost):\d+$/.test(authHost)) {
  throw new Error(
    `FIREBASE_AUTH_EMULATOR_HOST must target a loopback emulator. Refusing ${authHost}`,
  );
}

const password = 'PipeBuyerDemo!2026';
const accounts = [
  ['buyer.visual@pipebuyer.test', 'visual-buyer'],
  ['standard.visual@pipebuyer.test', 'visual-standard'],
  ['seller.visual@pipebuyer.test', 'visual-seller'],
  ['carrier.visual@pipebuyer.test', 'visual-carrier'],
];

const endpoint =
  `http://${authHost}/identitytoolkit.googleapis.com/v1/` +
  'accounts:signInWithPassword?key=pipebuyer-local';

async function verifyAccount(email, expectedUid) {
  let response;
  try {
    response = await fetch(endpoint, {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({
        email,
        password,
        returnSecureToken: true,
      }),
    });
  } catch (error) {
    throw new Error(
      `Auth emulator request failed for ${email}: ${error?.message || error}`,
    );
  }

  let payload = {};
  try {
    payload = await response.json();
  } catch (_) {
    // Keep an empty payload; the HTTP status below remains diagnostic.
  }

  if (!response.ok) {
    const code = payload?.error?.message || `HTTP_${response.status}`;
    throw new Error(`Demo Auth login failed for ${email}: ${code}`);
  }

  if (payload.localId !== expectedUid) {
    throw new Error(
      `Demo Auth UID mismatch for ${email}. Expected ${expectedUid}, got ${payload.localId || '<empty>'}.`,
    );
  }

  if (!String(payload.idToken || '').trim()) {
    throw new Error(`Demo Auth did not return an ID token for ${email}.`);
  }

  console.log(`  PASS ${email} -> ${expectedUid}`);
}

async function main() {
  console.log(`Checking formal demo passwords against Auth emulator ${authHost}`);
  for (const [email, uid] of accounts) {
    await verifyAccount(email, uid);
  }
  console.log('FORMAL_DEMO_AUTH_PASSWORDS_PASSED');
}

main().catch((error) => {
  console.error(error?.stack || error);
  process.exitCode = 1;
});
