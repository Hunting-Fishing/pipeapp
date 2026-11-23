import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

export const APPLE_APPLICATION_ID = "4L3S6Y2KGQ.Pipe.Buyerapp";
export const ANDROID_PACKAGE_NAME = "Pipe.Buyerapp";

const APPLE_COMPONENTS = Object.freeze([
  {
    "/": "/__/auth/action",
    exclude: true,
    comment: "Keep Firebase Auth's reserved action endpoint in the browser.",
  },
  {
    "/": "/__/auth/action/*",
    exclude: true,
    comment: "Keep descendants of Firebase Auth's action endpoint in the browser.",
  },
  {
    "/": "/__/auth/handler",
    exclude: true,
    comment: "Keep Firebase Auth's reserved callback endpoint in the browser.",
  },
  {
    "/": "/__/auth/handler/*",
    exclude: true,
    comment: "Keep descendants of Firebase Auth's callback endpoint in the browser.",
  },
  {
    "/": "/_/*",
    exclude: true,
    comment: "Do not claim Firebase Hosting's reserved internal namespace.",
  },
  {
    "/": "/admin/*",
    exclude: true,
    comment: "Keep privileged administrative routes browser-only.",
  },
  {
    "/": "/account/*",
    exclude: true,
    comment: "Keep private account-management routes browser-only.",
  },
  {
    "/": "/payments/*",
    exclude: true,
    comment: "Keep payment return routes browser-only.",
  },
  {"/": "/", comment: "Open the Pipe Buyer home route."},
  {"/": "/listings/*", comment: "Open shared Marketplace listings."},
  {"/": "/auctions/*", comment: "Open shared auction listings."},
  {"/": "/profiles/*", comment: "Open shared business profiles."},
  {"/": "/conversations/*", comment: "Open shared conversations."},
  {"/": "/dispatch/jobs/*", comment: "Open shared Dispatch jobs."},
  {"/": "/about"},
  {"/": "/privacy"},
  {"/": "/terms"},
  {"/": "/support"},
  {"/": "/account-deletion"},
  {"/": "/services"},
  {"/": "/services/*"},
  {"/": "/contact-center"},
  {"/": "/partner"},
  {"/": "/partner/*"},
  {"/": "/insurance"},
  {"/": "/insurance/*"},
  {"/": "/shop"},
  {"/": "/shop/*"},
  {"/": "/auth/action"},
]);

const SHA256_FINGERPRINT = /^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$/;

export function normalizeAndroidFingerprints(values) {
  const normalized = [...new Set(
    values
        .flatMap((value) => String(value || "").split(","))
        .map((value) => value.trim().toUpperCase())
        .filter(Boolean),
  )];
  if (normalized.length === 0) {
    throw new Error(
        "At least one Play App Signing SHA-256 certificate fingerprint is required.",
    );
  }
  for (const fingerprint of normalized) {
    if (!SHA256_FINGERPRINT.test(fingerprint)) {
      throw new Error(
          `Invalid Play App Signing SHA-256 fingerprint: ${fingerprint}`,
      );
    }
  }
  return normalized.sort();
}

export function appleAssociation() {
  return {
    applinks: {
      details: [
        {
          appIDs: [APPLE_APPLICATION_ID],
          components: APPLE_COMPONENTS,
        },
      ],
    },
  };
}

export function androidAssociation(fingerprints) {
  return [
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: {
        namespace: "android_app",
        package_name: ANDROID_PACKAGE_NAME,
        sha256_cert_fingerprints: normalizeAndroidFingerprints(fingerprints),
      },
    },
  ];
}

export function writeAssociations({outputDir, androidFingerprints}) {
  const resolvedOutput = path.resolve(String(outputDir || ""));
  const buildRoot = `${path.resolve("build")}${path.sep}`;
  if (!resolvedOutput.startsWith(buildRoot) ||
      path.basename(resolvedOutput) !== ".well-known") {
    throw new Error(
        "Association output must be an explicit .well-known directory under build/.",
    );
  }
  const android = androidAssociation(androidFingerprints);
  const apple = appleAssociation();
  fs.mkdirSync(resolvedOutput, {recursive: true});
  fs.writeFileSync(
      path.join(resolvedOutput, "assetlinks.json"),
      `${JSON.stringify(android)}\n`,
  );
  fs.writeFileSync(
      path.join(resolvedOutput, "apple-app-site-association"),
      `${JSON.stringify(apple)}\n`,
  );
  return {outputDir: resolvedOutput, android, apple};
}

function optionValues(argv, name) {
  const values = [];
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === name && argv[index + 1]) {
      values.push(argv[index + 1]);
      index += 1;
    } else if (argument.startsWith(`${name}=`)) {
      values.push(argument.slice(name.length + 1));
    }
  }
  return values;
}

function main(argv) {
  const outputDir = optionValues(argv, "--output-dir").at(-1);
  const commandLineFingerprints = optionValues(argv, "--android-sha256");
  const environmentFingerprints = process.env.PIPE_ANDROID_APP_SIGNING_SHA256 ?
    [process.env.PIPE_ANDROID_APP_SIGNING_SHA256] : [];
  const result = writeAssociations({
    outputDir,
    androidFingerprints: [
      ...commandLineFingerprints,
      ...environmentFingerprints,
    ],
  });
  process.stdout.write(
      `Prepared mobile link association files in ${result.outputDir}\n`,
  );
}

const executedPath = process.argv[1] ? path.resolve(process.argv[1]) : "";
if (executedPath && fileURLToPath(import.meta.url) === executedPath) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : error}\n`);
    process.exitCode = 1;
  }
}
