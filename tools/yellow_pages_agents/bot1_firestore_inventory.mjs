#!/usr/bin/env node
/**
 * Bot 1 — PipeBuyer Live Firestore Database Inventory Agent (Read-Only)
 *
 * Audits what is currently inside PipeBuyer's Firestore projects (`flutter-flow-pipe`
 * and `pipebuyer-5c77f`) across Dispatch, Profiles, Admin Roles, and Yellow Pages
 * collections without mutating any data, and writes structured JSON + Markdown reports.
 */

import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {fileURLToPath} from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");

const PROJECTS = [
  {id: "flutter-flow-pipe", label: "Production (flutter-flow-pipe)"},
  {id: "pipebuyer-5c77f", label: "Staging (pipebuyer-5c77f)"},
];

const COLLECTIONS_TO_CHECK = [
  "yellow_pages_companies",
  "yellow_pages_public_entries",
  "yellow_pages_blocked_numbers",
  "yellow_pages_listing_requests",
  "yellow_pages_book_pages",
  "yellow_pages_staff",
  "dispatch_directory_entries",
  "carrier_profiles",
  "public_business_profiles",
  "administrator_roles",
  "users",
];

async function resolveAccessToken() {
  if (process.env.FIREBASE_ACCESS_TOKEN) {
    return process.env.FIREBASE_ACCESS_TOKEN.trim();
  }
  const configPath = path.join(
    os.homedir(),
    ".config",
    "configstore",
    "firebase-tools.json",
  );
  const raw = JSON.parse(await fs.readFile(configPath, "utf8"));
  const tokens = raw?.tokens || {};
  if (tokens.access_token && Number(tokens.expires_at || 0) > Date.now() + 60_000) {
    return tokens.access_token;
  }
  throw new Error(
    "Firebase CLI access token missing or expired. Run `firebase login:ci` or `firebase projects:list` once to refresh.",
  );
}

function decodeFirestoreFields(fields = {}) {
  const out = {};
  for (const [k, v] of Object.entries(fields)) {
    if ("stringValue" in v) out[k] = v.stringValue;
    else if ("booleanValue" in v) out[k] = v.booleanValue;
    else if ("integerValue" in v) out[k] = Number(v.integerValue);
    else if ("doubleValue" in v) out[k] = Number(v.doubleValue);
    else if ("timestampValue" in v) out[k] = v.timestampValue;
    else if ("arrayValue" in v) {
      out[k] = (v.arrayValue.values || []).map((item) =>
        item.stringValue ?? item.integerValue ?? JSON.stringify(item),
      );
    } else if ("mapValue" in v) {
      out[k] = decodeFirestoreFields(v.mapValue.fields || {});
    } else {
      out[k] = null;
    }
  }
  return out;
}

async function inspectCollection(projectId, collectionId, token) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collectionId}?pageSize=50`;
  const res = await fetch(url, {
    headers: {Authorization: `Bearer ${token}`},
  });
  if (!res.ok) {
    return {
      collectionId,
      status: res.status,
      count: 0,
      sampleSummaries: [],
      error: `HTTP ${res.status}`,
    };
  }
  const body = await res.json();
  const docs = body.documents || [];
  const sampleSummaries = docs.slice(0, 10).map((doc) => {
    const id = doc.name.split("/").pop();
    const d = decodeFirestoreFields(doc.fields || {});
    return {
      id,
      name:
        d.companyName ||
        d.operatingName ||
        d.publicName ||
        d.businessName ||
        d.displayName ||
        d.display_name ||
        "",
      accountType: d.accountType || d.role || d.status || "",
      region: [d.city, d.regionCode || d.province || d.state, d.countryCode]
        .filter(Boolean)
        .join(", "),
      hasPhone: Boolean(d.mainPhone || d.publicPhone || d.phone_number || d.phoneNumber),
    };
  });
  return {
    collectionId,
    status: 200,
    count: docs.length,
    hasMore: Boolean(body.nextPageToken),
    sampleSummaries,
  };
}

export async function runFirestoreInventory() {
  await fs.mkdir(REPORTS_DIR, {recursive: true});
  const jsonPath = path.join(REPORTS_DIR, "01_database_inventory.json");
  let token;
  try {
    token = await resolveAccessToken();
  } catch (err) {
    try {
      const cached = JSON.parse(await fs.readFile(jsonPath, "utf8"));
      console.log(`[Bot 1] Reusing recent cached Firestore inventory (${cached.generatedAt}) -> ${jsonPath}`);
      return cached;
    } catch (_) {
      throw err;
    }
  }
  const generatedAt = new Date().toISOString();
  const report = {
    generatedAt,
    mode: "read_only",
    projects: {},
  };

  for (const proj of PROJECTS) {
    const collections = {};
    for (const col of COLLECTIONS_TO_CHECK) {
      collections[col] = await inspectCollection(proj.id, col, token);
    }
    report.projects[proj.id] = {
      label: proj.label,
      collections,
    };
  }

  await fs.writeFile(jsonPath, JSON.stringify(report, null, 2), "utf8");

  const mdLines = [
    "# Bot 1 — PipeBuyer Firestore Database Inventory Report",
    "",
    `- **Generated At**: \`${generatedAt}\``,
    `- **Mode**: Read-Only REST Inspection`,
    "",
  ];

  for (const proj of PROJECTS) {
    const pData = report.projects[proj.id];
    mdLines.push(`## ${pData.label}`);
    mdLines.push("");
    mdLines.push("| Collection | Document Count (Sampled up to 50) | Sample Records |");
    mdLines.push("| :--- | ---: | :--- |");
    for (const col of COLLECTIONS_TO_CHECK) {
      const c = pData.collections[col];
      const names = (c.sampleSummaries || [])
        .map((s) => `${s.name || s.id}${s.accountType ? ` (${s.accountType})` : ""}`)
        .slice(0, 4)
        .join("; ");
      mdLines.push(
        `| \`${col}\` | ${c.count}${c.hasMore ? "+" : ""} | ${names || "—"} |`,
      );
    }
    mdLines.push("");
  }

  const mdPath = path.join(REPORTS_DIR, "01_database_inventory.md");
  await fs.writeFile(mdPath, mdLines.join("\n"), "utf8");
  console.log(`[Bot 1] Saved Firestore inventory -> ${jsonPath}`);
  return report;
}

if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith("bot1_firestore_inventory.mjs")) {
  runFirestoreInventory().catch((err) => {
    console.error("[Bot 1 Error]", err.message);
    process.exitCode = 1;
  });
}
