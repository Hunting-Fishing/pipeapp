"use strict";

// Grants or revokes the internal Apple Sandbox tester cohort claim.
//
// Safety properties:
// - dry-run is the default;
// - only the flutter-flow-pipe project is accepted;
// - a separate environment guard is required, including for dry-runs;
// - output never contains an email address, UID, unrelated claim values, or
//   credentials; the target is represented by a stable SHA-256 fingerprint;
// - --apply requires that dry-run fingerprint, rejects intervening claim drift,
//   and verifies the complete custom-claims object after a write.

const crypto = require("node:crypto");
const {isDeepStrictEqual} = require("node:util");

const EXPECTED_PROJECT_ID = "flutter-flow-pipe";
const GUARD_ENVIRONMENT_VARIABLE = "PIPE_APPLE_SANDBOX_CLAIM_GUARD";
const GUARD_CONFIRMATION_VALUE =
  "CONFIRM_FLUTTER_FLOW_PIPE_APPLE_SANDBOX_TESTER";
const CLAIM_NAME = "appleSandboxTester";

const USAGE = `Usage (PowerShell):
  $env:${GUARD_ENVIRONMENT_VARIABLE} = "${GUARD_CONFIRMATION_VALUE}"
  node scripts/set_apple_sandbox_tester_claim.js --project ${EXPECTED_PROJECT_ID} (--uid <exact-uid> | --email <exact-email>) (--grant | --revoke) [--apply --confirm-target <dry-run-fingerprint>]

Modes:
  default   Resolve one redacted target and print a dry-run plan. No write.
  --apply   Require the dry-run fingerprint, reject claim drift, then apply and verify.

Safety:
  --uid and --email are mutually exclusive. Existing custom claims are preserved.
  The environment guard is mandatory and is a confirmation value, not a secret.
  Output intentionally omits the target email, full UID, and unrelated claim values.
  The printed target fingerprint is non-secret and must be copied to --confirm-target.
  Use --help to print this message without initializing Firebase Admin.`;

class OperatorInputError extends Error {
  constructor(message) {
    super(message);
    this.name = "OperatorInputError";
  }
}

function parseArguments(argv) {
  const options = {
    apply: false,
    confirmTarget: "",
    email: "",
    grant: false,
    help: false,
    project: "",
    revoke: false,
    uid: "",
  };
  const seen = new Set();
  const valueArguments = new Map([
    ["--project", "project"],
    ["--uid", "uid"],
    ["--email", "email"],
    ["--confirm-target", "confirmTarget"],
  ]);
  const flagArguments = new Map([
    ["--apply", "apply"],
    ["--grant", "grant"],
    ["--help", "help"],
    ["--revoke", "revoke"],
  ]);

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (seen.has(argument)) {
      throw new OperatorInputError(`Duplicate argument: ${argument}.`);
    }
    if (valueArguments.has(argument)) {
      const value = argv[index + 1];
      if (!value || value.startsWith("--")) {
        throw new OperatorInputError(`${argument} requires a value.`);
      }
      options[valueArguments.get(argument)] = value;
      seen.add(argument);
      index += 1;
      continue;
    }
    if (flagArguments.has(argument)) {
      options[flagArguments.get(argument)] = true;
      seen.add(argument);
      continue;
    }
    throw new OperatorInputError("Unknown argument. Use --help for usage.");
  }
  return options;
}

function validateOptions(options, environment) {
  if (options.project !== EXPECTED_PROJECT_ID) {
    throw new OperatorInputError(
        `--project must be exactly ${EXPECTED_PROJECT_ID}.`,
    );
  }
  if (environment[GUARD_ENVIRONMENT_VARIABLE] !== GUARD_CONFIRMATION_VALUE) {
    throw new OperatorInputError(
        `${GUARD_ENVIRONMENT_VARIABLE} must exactly match the documented ` +
        "confirmation value.",
    );
  }
  if (Boolean(options.uid) === Boolean(options.email)) {
    throw new OperatorInputError(
        "Provide exactly one target selector: --uid or --email.",
    );
  }
  if (options.grant === options.revoke) {
    throw new OperatorInputError(
        "Choose exactly one action: --grant or --revoke.",
    );
  }
  if (options.apply && !/^[0-9a-f]{64}$/u.test(options.confirmTarget)) {
    throw new OperatorInputError(
        "--apply requires the exact 64-character fingerprint from the dry run " +
        "in --confirm-target.",
    );
  }
  if (!options.apply && options.confirmTarget) {
    throw new OperatorInputError(
        "--confirm-target is accepted only together with --apply.",
    );
  }
  if (options.uid && /[\s\x00-\x1f\x7f]/u.test(options.uid)) {
    throw new OperatorInputError("--uid must be one exact UID without whitespace.");
  }
  if (options.email &&
      (!/^[^\s@]+@[^\s@]+$/u.test(options.email) ||
       /[\x00-\x1f\x7f]/u.test(options.email))) {
    throw new OperatorInputError("--email must be one exact email address.");
  }
}

function claimsForAction(existingClaims, grant) {
  const nextClaims = {...(existingClaims || {})};
  if (grant) nextClaims[CLAIM_NAME] = true;
  else delete nextClaims[CLAIM_NAME];
  return nextClaims;
}

function normalizedEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function targetFingerprint(projectId, uid) {
  return crypto.createHash("sha256")
      .update("pipe-apple-sandbox-tester-v1\0", "utf8")
      .update(String(projectId || ""), "utf8")
      .update("\0", "utf8")
      .update(String(uid || ""), "utf8")
      .digest("hex");
}

async function resolveExactUser(auth, options) {
  const user = options.uid ?
    await auth.getUser(options.uid) :
    await auth.getUserByEmail(options.email);
  if (!user || typeof user.uid !== "string" || !user.uid) {
    throw new OperatorInputError("The exact target could not be resolved.");
  }
  if (options.uid && user.uid !== options.uid) {
    throw new OperatorInputError("The resolved target did not match --uid.");
  }
  if (options.email &&
      normalizedEmail(user.email) !== normalizedEmail(options.email)) {
    throw new OperatorInputError("The resolved target did not match --email.");
  }
  return user;
}

function redactedPlan(options, existingClaims, nextClaims, fingerprint) {
  return {
    action: options.grant ? "grant" : "revoke",
    mode: options.apply ? "apply" : "dry-run",
    projectId: EXPECTED_PROJECT_ID,
    selector: options.uid ? "uid" : "email",
    target: "resolved-redacted",
    targetFingerprint: fingerprint,
    claim: CLAIM_NAME,
    currentlyEnabled: existingClaims[CLAIM_NAME] === true,
    resultingEnabled: nextClaims[CLAIM_NAME] === true,
    changeRequired: !isDeepStrictEqual(existingClaims, nextClaims),
    unrelatedClaimsPreserved: true,
  };
}

async function operate(options, auth, writeLine) {
  const user = await resolveExactUser(auth, options);
  const existingClaims = {...(user.customClaims || {})};
  const nextClaims = claimsForAction(existingClaims, options.grant);
  const fingerprint = targetFingerprint(EXPECTED_PROJECT_ID, user.uid);
  const plan = redactedPlan(
      options,
      existingClaims,
      nextClaims,
      fingerprint,
  );
  writeLine(JSON.stringify(plan, null, 2));

  if (!options.apply) {
    writeLine("Dry run complete. No custom claims were written.");
    return {...plan, verified: false};
  }

  if (options.confirmTarget !== fingerprint) {
    throw new OperatorInputError(
        "--confirm-target did not match the resolved redacted target. " +
        "Run a new dry run and review its fingerprint.",
    );
  }
  const prewriteUser = await auth.getUser(user.uid);
  const prewriteClaims = {...(prewriteUser.customClaims || {})};
  if (prewriteUser.uid !== user.uid ||
      !isDeepStrictEqual(prewriteClaims, existingClaims)) {
    throw new OperatorInputError(
        "The target's custom claims changed after resolution. " +
        "No write occurred; run a new dry run and review it.",
    );
  }
  if (!plan.changeRequired) {
    writeLine(
        "No custom claims were written; the requested state was already verified.",
    );
    return {...plan, verified: true, writeSkipped: true};
  }

  await auth.setCustomUserClaims(user.uid, nextClaims);
  const verifiedUser = await auth.getUser(user.uid);
  const verifiedClaims = {...(verifiedUser.customClaims || {})};
  if (verifiedUser.uid !== user.uid ||
      !isDeepStrictEqual(verifiedClaims, nextClaims)) {
    throw new OperatorInputError(
        "The post-write verification did not match the requested claim state.",
    );
  }
  writeLine(
      "Apply complete. The redacted target's full custom-claim set was verified.",
  );
  writeLine(
      "The tester must refresh their Firebase ID token before Sandbox calls.",
  );
  return {...plan, verified: true, writeSkipped: false};
}

async function firebaseAuthForProject(projectId) {
  const {applicationDefault, getApps, initializeApp} =
    require("firebase-admin/app");
  const {getAuth} = require("firebase-admin/auth");
  const apps = getApps();
  let app;
  if (apps.length === 0) {
    app = initializeApp({credential: applicationDefault(), projectId});
  } else {
    app = apps.find((candidate) => candidate.name === "[DEFAULT]");
    if (!app || app.options.projectId !== projectId) {
      throw new OperatorInputError(
          "Firebase Admin is already initialized for a different project.",
      );
    }
  }
  return getAuth(app);
}

async function execute(argv, dependencies = {}) {
  const options = parseArguments(argv);
  const writeLine = dependencies.writeLine || console.log;
  if (options.help) {
    writeLine(USAGE);
    return {help: true};
  }
  validateOptions(options, dependencies.environment || process.env);
  const authFactory = dependencies.authFactory || firebaseAuthForProject;
  const auth = await authFactory(options.project);
  return operate(options, auth, writeLine);
}

function safeFailureMessage(error) {
  if (error instanceof OperatorInputError) return error.message;
  return "Operation failed. Target details remain redacted.";
}

if (require.main === module) {
  execute(process.argv.slice(2)).catch((error) => {
    console.error(safeFailureMessage(error));
    process.exitCode = 1;
  });
}

module.exports = {
  CLAIM_NAME,
  EXPECTED_PROJECT_ID,
  GUARD_CONFIRMATION_VALUE,
  GUARD_ENVIRONMENT_VARIABLE,
  OperatorInputError,
  USAGE,
  claimsForAction,
  execute,
  parseArguments,
  redactedPlan,
  safeFailureMessage,
  targetFingerprint,
  validateOptions,
};
