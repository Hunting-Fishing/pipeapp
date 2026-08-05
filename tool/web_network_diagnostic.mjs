import {spawn} from "node:child_process";
import {existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync} from "node:fs";
import net from "node:net";
import os from "node:os";
import path from "node:path";

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function findBrowser() {
  const candidates = [
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
  ];
  const browser = candidates.find((candidate) => existsSync(candidate));
  if (!browser) throw new Error("Chrome or Microsoft Edge was not found.");
  return browser;
}

async function getFreePort() {
  return await new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      const port = typeof address === "object" && address ? address.port : null;
      server.close((error) => error ? reject(error) : resolve(port));
    });
  });
}

async function waitForTarget(port) {
  const deadline = Date.now() + 15_000;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}/json/list`);
      if (response.ok) {
        const targets = await response.json();
        const target = targets.find((entry) => entry.type === "page");
        if (target?.webSocketDebuggerUrl) return target;
      }
    } catch {
      // Browser may still be starting.
    }
    await delay(250);
  }
  throw new Error("Could not connect to the headless browser.");
}

async function inspectUrl(url, screenshotPath) {
  const browserPath = findBrowser();
  const port = await getFreePort();
  const profilePath = mkdtempSync(path.join(os.tmpdir(), "pipe-buyer-net-"));
  const browser = spawn(browserPath, [
    "--headless=new",
    "--disable-extensions",
    "--no-first-run",
    "--no-default-browser-check",
    "--enable-webgl",
    "--ignore-gpu-blocklist",
    "--use-angle=swiftshader",
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profilePath}`,
    "about:blank",
  ], {stdio: ["ignore", "ignore", "pipe"]});

  const browserStderr = [];
  browser.stderr.setEncoding("utf8");
  browser.stderr.on("data", (chunk) => browserStderr.push(chunk.trim()));

  let socket;
  try {
    const target = await waitForTarget(port);
    socket = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error("WebSocket connection timed out.")), 15_000);
      socket.addEventListener("open", () => {
        clearTimeout(timer);
        resolve();
      }, {once: true});
      socket.addEventListener("error", () => {
        clearTimeout(timer);
        reject(new Error("WebSocket connection failed."));
      }, {once: true});
    });

    let nextId = 0;
    const pending = new Map();
    const httpErrors = [];
    const loadingFailures = [];
    const consoleErrors = [];
    const runtimeExceptions = [];

    socket.addEventListener("message", (event) => {
      const message = JSON.parse(String(event.data));
      if (message.id && pending.has(message.id)) {
        const request = pending.get(message.id);
        pending.delete(message.id);
        clearTimeout(request.timer);
        if (message.error) request.reject(new Error(message.error.message));
        else request.resolve(message.result ?? {});
        return;
      }
      if (message.method === "Network.responseReceived") {
        const response = message.params?.response;
        if (Number(response?.status) >= 400) {
          httpErrors.push({
            status: Number(response.status),
            statusText: String(response.statusText || ""),
            type: String(message.params?.type || ""),
            url: String(response.url || ""),
            mimeType: String(response.mimeType || ""),
            fromServiceWorker: Boolean(response.fromServiceWorker),
          });
        }
      }
      if (message.method === "Network.loadingFailed") {
        loadingFailures.push({
          type: String(message.params?.type || ""),
          errorText: String(message.params?.errorText || ""),
          canceled: Boolean(message.params?.canceled),
          blockedReason: String(message.params?.blockedReason || ""),
        });
      }
      if (message.method === "Log.entryAdded" && message.params?.entry?.level === "error") {
        const entry = message.params.entry;
        consoleErrors.push({
          source: String(entry.source || ""),
          text: String(entry.text || ""),
          url: String(entry.url || ""),
          lineNumber: Number(entry.lineNumber || 0),
        });
      }
      if (message.method === "Runtime.consoleAPICalled" && message.params?.type === "error") {
        consoleErrors.push({
          source: "console",
          text: (message.params.args || []).map((argument) =>
            String(argument.value ?? argument.description ?? "")).join(" "),
          url: "",
          lineNumber: 0,
        });
      }
      if (message.method === "Runtime.exceptionThrown") {
        const details = message.params?.exceptionDetails;
        runtimeExceptions.push({
          text: String(details?.exception?.description || details?.text || ""),
          url: String(details?.url || ""),
          lineNumber: Number(details?.lineNumber || 0),
        });
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

    await command("Runtime.enable");
    await command("Log.enable");
    await command("Network.enable");
    await command("Page.enable");
    await command("Emulation.setDeviceMetricsOverride", {
      width: 390,
      height: 844,
      deviceScaleFactor: 1,
      mobile: true,
      screenWidth: 390,
      screenHeight: 844,
    });
    await command("Page.navigate", {url});
    await delay(20_000);

    const evaluation = await command("Runtime.evaluate", {
      expression: `JSON.stringify({
        readyState: document.readyState,
        title: document.title,
        text: (document.body?.innerText || '').trim().slice(0, 1000),
        href: location.href
      })`,
      returnByValue: true,
    });
    const page = evaluation.result?.value ? JSON.parse(evaluation.result.value) : {};
    const screenshot = await command("Page.captureScreenshot", {
      format: "png",
      fromSurface: true,
      captureBeyondViewport: false,
    });
    mkdirSync(path.dirname(screenshotPath), {recursive: true});
    writeFileSync(screenshotPath, Buffer.from(screenshot.data, "base64"));

    return {
      requestedUrl: url,
      page,
      httpErrors,
      loadingFailures,
      consoleErrors,
      runtimeExceptions,
      screenshotPath,
      browserStderr: browserStderr.filter(Boolean).slice(-20),
    };
  } finally {
    try { socket?.close(); } catch {}
    if (!browser.killed) browser.kill();
    await delay(500);
    rmSync(profilePath, {recursive: true, force: true});
  }
}

const targets = process.argv.slice(2);
if (targets.length === 0) {
  process.stderr.write("Provide at least one URL.\n");
  process.exit(2);
}

const results = [];
for (let index = 0; index < targets.length; index += 1) {
  const target = targets[index];
  try {
    results.push(await inspectUrl(
      target,
      path.resolve("build", "diagnostic", `target-${index + 1}.png`),
    ));
  } catch (error) {
    results.push({requestedUrl: target, diagnosticFailure: String(error?.stack || error)});
  }
}
process.stdout.write(`${JSON.stringify(results, null, 2)}\n`);
