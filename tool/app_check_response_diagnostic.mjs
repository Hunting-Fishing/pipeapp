import {spawn} from "node:child_process";
import {existsSync, mkdtempSync, rmSync} from "node:fs";
import net from "node:net";
import os from "node:os";
import path from "node:path";

const targetUrl = process.argv[2] || "https://www.pipebuyer.com";
const endpointMarker = "content-firebaseappcheck.googleapis.com";

const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

function browserPath() {
  const candidates = [
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
  ];
  const browser = candidates.find(existsSync);
  if (!browser) throw new Error("Chrome or Edge was not found.");
  return browser;
}

async function freePort() {
  return await new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      server.close((error) => error ? reject(error) : resolve(address.port));
    });
  });
}

async function targetFor(port) {
  const deadline = Date.now() + 15_000;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}/json/list`);
      const targets = response.ok ? await response.json() : [];
      const target = targets.find((entry) => entry.type === "page");
      if (target?.webSocketDebuggerUrl) return target;
    } catch {}
    await delay(250);
  }
  throw new Error("Could not connect to browser debugging endpoint.");
}

const port = await freePort();
const profile = mkdtempSync(path.join(os.tmpdir(), "pipe-app-check-body-"));
const browser = spawn(browserPath(), [
  "--headless=new",
  "--disable-extensions",
  "--no-first-run",
  "--no-default-browser-check",
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${profile}`,
  "about:blank",
], {stdio: "ignore"});

let socket;
try {
  const target = await targetFor(port);
  socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("WebSocket open timed out.")), 15_000);
    socket.addEventListener("open", () => {
      clearTimeout(timer);
      resolve();
    }, {once: true});
    socket.addEventListener("error", () => {
      clearTimeout(timer);
      reject(new Error("WebSocket open failed."));
    }, {once: true});
  });

  let nextId = 0;
  const pending = new Map();
  const appCheckResponses = [];
  const finishedRequests = new Set();

  socket.addEventListener("message", (event) => {
    const message = JSON.parse(String(event.data));
    if (message.id && pending.has(message.id)) {
      const request = pending.get(message.id);
      pending.delete(message.id);
      clearTimeout(request.timer);
      if (message.error) request.reject(new Error(message.error.message));
      else request.resolve(message.result || {});
      return;
    }
    if (message.method === "Network.responseReceived") {
      const response = message.params?.response;
      if (String(response?.url || "").includes(endpointMarker)) {
        appCheckResponses.push({
          requestId: message.params.requestId,
          url: response.url,
          status: response.status,
          statusText: response.statusText,
          mimeType: response.mimeType,
          body: null,
          bodyError: null,
        });
      }
    }
    if (message.method === "Network.loadingFinished") {
      finishedRequests.add(message.params.requestId);
    }
  });

  function command(method, params = {}) {
    nextId += 1;
    const id = nextId;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        pending.delete(id);
        reject(new Error(`CDP command timed out: ${method}`));
      }, 30_000);
      pending.set(id, {resolve, reject, timer});
      socket.send(JSON.stringify({id, method, params}));
    });
  }

  await command("Network.enable");
  await command("Page.enable");
  await command("Runtime.enable");
  await command("Page.navigate", {url: targetUrl});

  const deadline = Date.now() + 45_000;
  while (Date.now() < deadline && appCheckResponses.length === 0) {
    await delay(500);
  }
  await delay(2_000);

  for (const response of appCheckResponses) {
    try {
      if (!finishedRequests.has(response.requestId)) await delay(1_000);
      const bodyResult = await command("Network.getResponseBody", {
        requestId: response.requestId,
      });
      response.body = bodyResult.base64Encoded
        ? Buffer.from(bodyResult.body, "base64").toString("utf8")
        : bodyResult.body;
    } catch (error) {
      response.bodyError = String(error.message || error);
    }
    delete response.requestId;
    response.url = response.url.replace(/([?&]key=)[^&]+/u, "$1[REDACTED]");
  }

  const page = await command("Runtime.evaluate", {
    expression: `JSON.stringify({
      title: document.title,
      readyState: document.readyState,
      text: (document.body?.innerText || '').trim().slice(0, 500),
      href: location.href
    })`,
    returnByValue: true,
  });

  process.stdout.write(`${JSON.stringify({
    targetUrl,
    page: page.result?.value ? JSON.parse(page.result.value) : {},
    appCheckResponses,
  }, null, 2)}\n`);

  if (appCheckResponses.length === 0) process.exitCode = 2;
} finally {
  try { socket?.close(); } catch {}
  if (!browser.killed) browser.kill();
  await delay(1_000);
  try { rmSync(profile, {recursive: true, force: true}); } catch {}
}
