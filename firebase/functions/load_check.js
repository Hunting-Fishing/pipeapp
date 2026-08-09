const functions = require("./bootstrap");

const names = Object.keys(functions).sort();
if (names.length === 0) {
  throw new Error("Functions entrypoint loaded without any exports.");
}

console.log(`Functions entrypoint loaded ${names.length} exports.`);
