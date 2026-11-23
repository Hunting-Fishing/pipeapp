"use strict";

function environmentBoolean(name, defaultValue = false) {
  const value = process.env[name];
  if (value == null || String(value).trim() === "") return defaultValue;
  return String(value).trim().toLowerCase() === "true";
}

// onCall expects a concrete boolean in its deployment options. Passing a
// parameter expression makes the Functions SDK evaluate it while discovering
// every callable, which can time out deployment and emulator startup.
const enforceAppCheck = environmentBoolean("PIPE_ENFORCE_APP_CHECK", false);
const CALLABLE_TIMEOUT_SECONDS = 60;

const protectedCallableOptions = Object.freeze({
  enforceAppCheck,
  // Account deletion waits two minutes after creating its tombstone before
  // finalization. Keep every user callable below that drain window so a
  // request already in flight cannot commit after destructive cleanup.
  timeoutSeconds: CALLABLE_TIMEOUT_SECONDS,
});

module.exports = {
  CALLABLE_TIMEOUT_SECONDS,
  environmentBoolean,
  enforceAppCheck,
  protectedCallableOptions,
};
