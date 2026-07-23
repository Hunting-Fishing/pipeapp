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

const protectedCallableOptions = Object.freeze({
  enforceAppCheck,
});

module.exports = {
  environmentBoolean,
  enforceAppCheck,
  protectedCallableOptions,
};
