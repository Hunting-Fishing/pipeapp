import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

import {
  ANDROID_PACKAGE_NAME,
  APPLE_APPLICATION_ID,
  androidAssociation,
  appleAssociation,
  normalizeAndroidFingerprints,
  writeAssociations,
} from "./mobile_link_associations.mjs";

const FINGERPRINT =
  "07:B9:2E:02:75:D5:E2:F3:B3:51:EF:6C:44:C5:A6:74:" +
  "C3:6B:E6:F4:36:9F:01:E0:13:34:AF:A3:7B:6D:6E:EF";

function applePathIsAssociated(components, routePath) {
  for (const component of components) {
    const pattern = component["/"];
    const expression = new RegExp(
        `^${pattern
            .replace(/[.+?^${}()|[\]\\]/g, "\\$&")
            .replaceAll("*", ".*")}$`,
    );
    if (expression.test(routePath)) return component.exclude !== true;
  }
  return false;
}

test("association documents use the approved application identities", () => {
  const apple = appleAssociation();
  const android = androidAssociation([FINGERPRINT.toLowerCase()]);
  assert.deepEqual(apple.applinks.details[0].appIDs, [APPLE_APPLICATION_ID]);
  assert.equal(android[0].target.package_name, ANDROID_PACKAGE_NAME);
  assert.deepEqual(android[0].target.sha256_cert_fingerprints, [FINGERPRINT]);
  assert.deepEqual(
      apple.applinks.details[0].components.map(
          (component) => [component["/"], component.exclude === true],
      ),
      [
        ["/__/auth/action", true],
        ["/__/auth/action/*", true],
        ["/__/auth/handler", true],
        ["/__/auth/handler/*", true],
        ["/_/*", true],
        ["/admin/*", true],
        ["/account/*", true],
        ["/payments/*", true],
        ["/", false],
        ["/listings/*", false],
        ["/auctions/*", false],
        ["/profiles/*", false],
        ["/conversations/*", false],
        ["/dispatch/jobs/*", false],
        ["/about", false],
        ["/privacy", false],
        ["/terms", false],
        ["/support", false],
        ["/account-deletion", false],
        ["/services", false],
        ["/services/*", false],
        ["/contact-center", false],
        ["/partner", false],
        ["/partner/*", false],
        ["/insurance", false],
        ["/insurance/*", false],
        ["/shop", false],
        ["/shop/*", false],
        ["/auth/action", false],
      ],
  );
});

test("Apple policy covers every registered Marketplace link path", () => {
  const deepLinks = fs.readFileSync(
      "lib/marketplace/marketplace_deep_links.dart",
      "utf8",
  );
  const constantPaths = [...deepLinks.matchAll(
      /static const \w+Path = '([^']+)'/g,
  )].map((match) => match[1]);
  const routeSentinels = [
    "/listings/release-test",
    "/auctions/release-test",
    "/profiles/release-test",
    "/conversations/release-test",
    "/dispatch/jobs/release-test",
  ];
  assert.ok(constantPaths.includes("/contact-center"));
  assert.ok(constantPaths.includes("/admin/shop"));
  const components = appleAssociation().applinks.details[0].components;
  assert.equal(applePathIsAssociated(components, "/"), true);
  for (const routePath of constantPaths) {
    const expected = !routePath.startsWith("/admin/");
    assert.equal(
        applePathIsAssociated(components, routePath),
        expected,
        `${routePath} has the documented public or browser-only policy`,
    );
  }
  for (const routePath of routeSentinels) {
    assert.equal(
        applePathIsAssociated(components, routePath),
        true,
        `${routePath} must be covered by the generated AASA policy`,
    );
  }
  assert.equal(applePathIsAssociated(components, "/__/auth/action"), false);
  assert.equal(applePathIsAssociated(components, "/__/auth/action/"), false);
  assert.equal(applePathIsAssociated(components, "/__/auth/handler"), false);
  assert.equal(applePathIsAssociated(components, "/__/auth/handler/"), false);
  assert.equal(applePathIsAssociated(components, "/_/reserved"), false);
  assert.equal(applePathIsAssociated(components, "/account/tax-profile"), false);
  assert.equal(applePathIsAssociated(components, "/payments/dispatch"), false);
  assert.equal(applePathIsAssociated(components, "/admin/tax-compliance"), false);
  assert.equal(
      components.some(
          (component) => component["/"] === "/*" && component.exclude !== true,
      ),
      false,
  );
});

test("fingerprints are required, normalized, deduplicated, and validated", () => {
  assert.throws(() => normalizeAndroidFingerprints([]), /required/);
  assert.throws(
      () => normalizeAndroidFingerprints(["REPLACE_WITH_PLAY_CERT"]),
      /Invalid Play App Signing/,
  );
  assert.deepEqual(
      normalizeAndroidFingerprints([FINGERPRINT, FINGERPRINT.toLowerCase()]),
      [FINGERPRINT],
  );
});

test("writer only emits complete files under an explicit build directory", () => {
  assert.throws(
      () => writeAssociations({
        outputDir: "web/.well-known",
        androidFingerprints: [FINGERPRINT],
      }),
      /under build/,
  );
  const outputDir = path.join(
      "build",
      `mobile-link-association-test-${process.pid}`,
      ".well-known",
  );
  try {
    writeAssociations({outputDir, androidFingerprints: [FINGERPRINT]});
    const android = JSON.parse(
        fs.readFileSync(path.join(outputDir, "assetlinks.json"), "utf8"),
    );
    const apple = JSON.parse(
        fs.readFileSync(
            path.join(outputDir, "apple-app-site-association"),
            "utf8",
        ),
    );
    assert.deepEqual(android[0].target.sha256_cert_fingerprints, [FINGERPRINT]);
    assert.deepEqual(apple.applinks.details[0].appIDs, [APPLE_APPLICATION_ID]);
  } finally {
    fs.rmSync(path.dirname(outputDir), {recursive: true, force: true});
  }
});
