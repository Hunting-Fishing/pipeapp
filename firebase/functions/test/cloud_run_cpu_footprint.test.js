"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {__getSpec} = require("firebase-functions/v2/options");
const productionExports = require("../production_bootstrap");

test("Gen 2 functions enforce fractional CPU footprint within regional Cloud Run quota", () => {
  const spec = __getSpec();
  assert.deepEqual(spec.globalOptions, {
    cpu: 0.25,
    concurrency: 1,
  });

  const exportNames = Object.keys(productionExports).sort();
  assert.ok(
    exportNames.length >= 192,
    `Expected at least 192 exported functions, found ${exportNames.length}`,
  );

  let totalRegionalVcpu = 0;
  for (const name of exportNames) {
    const fn = productionExports[name];
    const endpoint = fn && fn.__endpoint;
    assert.ok(endpoint, `Export ${name} must define a Gen 2 __endpoint`);
    assert.equal(endpoint.platform, "gcfv2", `Export ${name} must target gcfv2`);

    const cpu = Number(endpoint.cpu);
    const concurrency = Number(endpoint.concurrency);
    const memoryMb = Number(endpoint.availableMemoryMb || 256);

    assert.ok(
      Number.isFinite(cpu) && cpu >= 0.08,
      `Export ${name} has invalid cpu=${endpoint.cpu}`,
    );
    if (cpu < 1) {
      assert.equal(
        concurrency,
        1,
        `Export ${name} with fractional cpu=${cpu} must use concurrency=1`,
      );
    }
    if (memoryMb > 512) {
      assert.ok(
        cpu >= 0.5,
        `Export ${name} with memory=${memoryMb}MiB requires cpu >= 0.5`,
      );
    }
    if (memoryMb > 1024) {
      assert.ok(
        cpu >= 1,
        `Export ${name} with memory=${memoryMb}MiB requires cpu >= 1`,
      );
    }

    totalRegionalVcpu += cpu;
  }

  // Regional Cloud Run CPU quota defaults to 200 vCPUs; keeping the full stack
  // below 100 vCPUs guarantees >2x headroom even during overlapping rollouts.
  assert.ok(
    totalRegionalVcpu < 100,
    `Total Gen 2 CPU footprint (${totalRegionalVcpu} vCPUs) exceeds safe regional rollout budget`,
  );
});
