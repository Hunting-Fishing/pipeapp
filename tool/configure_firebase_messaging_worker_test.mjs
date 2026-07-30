import test from "node:test";
import assert from "node:assert/strict";
import {messagingWorkerSource} from "./configure_firebase_messaging_worker.mjs";

test("messaging worker binds to exactly one selected Firebase project", () => {
  const source = messagingWorkerSource({
    apiKey: "public-key",
    authDomain: "staging.example.test",
    projectId: "pipe-staging",
    storageBucket: "pipe-staging.firebasestorage.app",
    messagingSenderId: "12345",
    appId: "1:12345:web:abcdef",
  });
  assert.match(source, /firebasejs\/12\.15\.0/);
  assert.match(source, /"projectId": "pipe-staging"/);
  assert.doesNotMatch(source, /flutter-flow-pipe/);
});

test("messaging worker fails closed on incomplete configuration", () => {
  assert.throws(() => messagingWorkerSource({
    apiKey: "public-key",
    projectId: "pipe-staging",
  }), /missing authDomain/);
});
