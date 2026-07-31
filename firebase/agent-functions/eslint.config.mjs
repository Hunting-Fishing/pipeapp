import globals from "globals";

export default [
  {ignores: ["node_modules/**"]},
  {
    files: ["**/*.js", "**/*.mjs"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "commonjs",
      globals: globals.node,
    },
    rules: {
      "no-dupe-keys": "error",
      "no-redeclare": "error",
      "no-unreachable": "error",
      "no-unused-vars": ["error", {argsIgnorePattern: "^_"}],
      "no-undef": "error",
      "valid-typeof": "error",
    },
  },
  {
    files: ["**/*.mjs"],
    languageOptions: {sourceType: "module", globals: globals.node},
  },
];
