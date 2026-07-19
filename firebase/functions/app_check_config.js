"use strict";

const {defineBoolean} = require("firebase-functions/params");

const enforceAppCheck = defineBoolean("PIPE_ENFORCE_APP_CHECK", {
  default: false,
  description:
    "Require valid Firebase App Check tokens for marketplace callables.",
});

const protectedCallableOptions = Object.freeze({
  enforceAppCheck,
});

module.exports = {
  enforceAppCheck,
  protectedCallableOptions,
};
