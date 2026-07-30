import {renameSync, writeFileSync} from "node:fs";
import path from "node:path";

function option(argumentsList, name) {
  const index = argumentsList.indexOf(name);
  if (index < 0 || !argumentsList[index + 1]) {
    throw new Error(`${name} is required.`);
  }
  return argumentsList[index + 1].trim();
}

export function messagingWorkerSource(configuration) {
  const required = ["apiKey", "authDomain", "projectId", "storageBucket",
    "messagingSenderId", "appId"];
  for (const field of required) {
    if (!String(configuration[field] || "").trim()) {
      throw new Error(`Messaging worker configuration is missing ${field}.`);
    }
  }
  const encoded = JSON.stringify(configuration, null, 2);
  return `/* Generated for the selected Pipe Buyer Firebase environment. */
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-messaging-compat.js');

firebase.initializeApp(${encoded});
firebase.messaging();
`;
}

function main(argumentsList) {
  const output = path.resolve(option(argumentsList, "--output"));
  const source = messagingWorkerSource({
    apiKey: option(argumentsList, "--api-key"),
    authDomain: option(argumentsList, "--auth-domain"),
    projectId: option(argumentsList, "--project-id"),
    storageBucket: option(argumentsList, "--storage-bucket"),
    messagingSenderId: option(argumentsList, "--messaging-sender-id"),
    appId: option(argumentsList, "--app-id"),
  });
  const temporary = `${output}.tmp`;
  writeFileSync(temporary, source);
  renameSync(temporary, output);
  process.stdout.write(`Firebase messaging worker written to ${output}\n`);
}

if (import.meta.url === new URL(`file://${process.argv[1].replaceAll("\\", "/")}`).href) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`Messaging worker generation failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
