import net from 'node:net';

const endpoints = [
  ['Auth', 9099],
  ['Firestore', 8080],
  ['Functions', 5001],
  ['Storage', 9199],
];

async function assertPortOpen(name, port) {
  await new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: '127.0.0.1', port });
    const timeout = setTimeout(() => {
      socket.destroy();
      reject(new Error(`${name} emulator did not accept connections on ${port}.`));
    }, 5000);
    socket.once('connect', () => {
      clearTimeout(timeout);
      socket.end();
      resolve();
    });
    socket.once('error', (error) => {
      clearTimeout(timeout);
      reject(new Error(`${name} emulator port ${port} failed: ${error.message}`));
    });
  });
}

for (const [name, port] of endpoints) {
  await assertPortOpen(name, port);
}

const callableUrl =
  'http://127.0.0.1:5001/flutter-flow-pipe/us-central1/createDispatchJob';
const response = await fetch(callableUrl, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ data: {} }),
});
const body = await response.text();
if (response.status === 404 || /not[ -]?found/i.test(body)) {
  throw new Error(
    `Functions emulator did not load createDispatchJob: ${response.status} ${body}`,
  );
}

console.log(
  `Firebase emulator smoke passed; callable responded ${response.status}.`,
);
