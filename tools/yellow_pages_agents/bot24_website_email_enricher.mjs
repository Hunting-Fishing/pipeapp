#!/usr/bin/env node
/**
 * Bot 24 — Safe Public-Website B2B Contact-Email Enricher
 *
 * Scans active `yellow_pages_companies` records that have a public `website` URL on file
 * (`38,510` businesses) and no valid `publicEmail` / `generalEmail` yet.
 * Crawls homepage `/` and `/contact` (`/contact-us`) with strict timeouts, skips directory
 * aggregators/social profiles/placeholder domains/noreply addresses, prioritizes domain-matching
 * B2B contact addresses (`info@`, `sales@`, `dispatch@`, `office@`, `contact@`, `quotes@`),
 * checkpoints scanned IDs to `data/yellow_pages/ledger/24_website_email_enrichment.json`, and
 * non-destructively writes `generalEmail` + `emailSource: "company_website_public"` when `--apply`
 * is passed. Never alters `verified` or `effectiveTier`.
 */
import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";
import {resolveAccessToken, toFirestoreValue} from "./global_shared_utils.mjs";

const require = createRequire(import.meta.url);
const {normalizeOutreachEmail, resolveCompanyOutreachEmail} = require("../../firebase/functions/yellow_pages_outreach.js");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const LEDGER_PATH = path.join(REPO_ROOT, "data/yellow_pages/ledger/24_website_email_enrichment.json");

const args = process.argv.slice(2);
const argVal = (k, d) => {
  const i = args.indexOf(k);
  return i !== -1 && args[i + 1] ? args[i + 1] : d;
};
const APPLY = args.includes("--apply");
const PROJECT_ID = argVal("--project", "flutter-flow-pipe");
const LIMIT = Math.max(1, Number(argVal("--limit", "500")) || 500);
const CONCURRENCY = Math.max(1, Math.min(40, Number(argVal("--concurrency", "25")) || 25));
const COUNTRY_FILTER = String(argVal("--country", "")).trim().toUpperCase();
const REGION_FILTER = String(argVal("--region", "")).trim().toUpperCase();

const SKIP_WEBSITE_HOSTS = new Set([
  "facebook.com",
  "m.facebook.com",
  "linkedin.com",
  "instagram.com",
  "twitter.com",
  "x.com",
  "youtube.com",
  "tiktok.com",
  "yellowpages.ca",
  "yellowpages.com",
  "yelp.ca",
  "yelp.com",
  "mapquest.com",
  "bbb.org",
  "manta.com",
  "dnb.com",
  "411.ca",
  "canada411.ca",
  "cylex-canada.ca",
  "profilecanada.com",
  "google.com",
  "goo.gl",
  "bit.ly",
]);

const EXTRA_BLOCKED_EMAIL_HOSTS = new Set([
  "godaddy.com",
  "secureserver.net",
  "wordpress.org",
  "wordpress.com",
  "wix.com",
  "squarespace.com",
  "shopify.com",
  "cloudflare.com",
  "bootstrap.com",
  "jquery.com",
  "fontawesome.com",
  "latofonts.com",
  "typogama.com",
]);

const PREFERRED_PREFIX_WEIGHTS = [
  ["dispatch", 45],
  ["sales", 42],
  ["quotes", 40],
  ["estimating", 38],
  ["info", 36],
  ["contact", 35],
  ["office", 34],
  ["service", 33],
  ["services", 33],
  ["inquiries", 32],
  ["enquiries", 32],
  ["orders", 31],
  ["rentals", 30],
  ["reception", 28],
  ["admin", 25],
  ["hello", 22],
  ["support", 20],
];

const strVal = (f, k) => f?.[k]?.stringValue || "";
const boolVal = (f, k, d = false) => (f?.[k]?.booleanValue !== undefined ? f[k].booleanValue : d);

function registrableRoot(hostname) {
  const clean = String(hostname || "").toLowerCase().replace(/^www\./u, "").trim();
  const parts = clean.split(".").filter(Boolean);
  if (parts.length <= 2) return clean;
  const lastTwo = parts.slice(-2).join(".");
  if (/^(?:co|com|org|net|gov|edu)\.[a-z]{2}$/u.test(lastTwo) && parts.length >= 3) {
    return parts.slice(-3).join(".");
  }
  return lastTwo;
}

function normalizeWebsiteUrl(raw) {
  let s = String(raw || "").trim();
  if (!s) return "";
  if (!/^https?:\/\//iu.test(s)) s = `https://${s}`;
  try {
    const u = new URL(s);
    const host = u.hostname.toLowerCase().replace(/^www\./u, "");
    if (!host || !host.includes(".")) return "";
    if (SKIP_WEBSITE_HOSTS.has(host) || SKIP_WEBSITE_HOSTS.has(registrableRoot(host))) {
      return "";
    }
    u.hash = "";
    return u.toString();
  } catch (_) {
    return "";
  }
}

function extractEmailsFromHtml(html, siteHostname) {
  const decoded = String(html || "")
    .slice(0, 450000)
    .replace(/&#64;|&#x40;/giu, "@")
    .replace(/&#46;|&#x2e;/giu, ".")
    .replace(/\[at\]|\(at\)/giu, "@");

  const candidates = new Map();
  const siteRoot = registrableRoot(siteHostname);

  const recordCandidate = (raw, fromMailto) => {
    const email = normalizeOutreachEmail(raw);
    if (!email) return;
    const [local, domain] = email.split("@");
    const emailRoot = registrableRoot(domain);
    if (EXTRA_BLOCKED_EMAIL_HOSTS.has(domain) || EXTRA_BLOCKED_EMAIL_HOSTS.has(emailRoot)) return;
    if (/^[0-9a-f]{24,}$/iu.test(local)) return; // UUID / Sentry / tracking hash
    if (/\b(?:privacy|abuse|dmca|webmaster|hostmaster|careers|hr|jobs|recruiting)\b/iu.test(local)) return;

    let score = fromMailto ? 35 : 10;
    if (siteRoot && emailRoot === siteRoot) {
      score += 50;
    } else if (
      !/^(?:gmail\.com|yahoo\.com|yahoo\.ca|hotmail\.com|outlook\.com|telus\.net|shaw\.ca|sasktel\.net|mcsnet\.ca|bellnet\.ca|live\.ca|live\.com|icloud\.com|aol\.com)$/iu.test(domain)
    ) {
      // Unrelated third-party corporate domain (often web agency in footer): penalize heavily unless mailto
      if (!fromMailto) return;
      score -= 20;
    }

    for (const [prefix, bonus] of PREFERRED_PREFIX_WEIGHTS) {
      if (local === prefix || local.startsWith(`${prefix}.`) || local.startsWith(`${prefix}_`) || local.startsWith(`${prefix}-`)) {
        score += bonus;
        break;
      }
    }

    const prev = candidates.get(email);
    if (!prev || score > prev) candidates.set(email, score);
  };

  const mailtoRe = /href\s*=\s*["']mailto:([^"'?#>\s]+)/giu;
  let m;
  while ((m = mailtoRe.exec(decoded)) !== null) {
    recordCandidate(decodeURIComponent(m[1]).trim(), true);
  }

  const rawEmailRe = /\b[a-z0-9._%+-]{1,64}@(?:[a-z0-9-]+\.)+[a-z]{2,18}\b/giu;
  while ((m = rawEmailRe.exec(decoded)) !== null) {
    recordCandidate(m[0], false);
  }

  const sorted = [...candidates.entries()]
    .filter(([, sc]) => sc >= 25)
    .sort((a, b) => b[1] - a[1]);
  return sorted.length > 0 ? sorted[0][0] : "";
}

function discoverContactPageUrl(html, baseUrl) {
  try {
    const base = new URL(baseUrl);
    const linkRe = /<a\b[^>]*href\s*=\s*["']([^"'#]+)["'][^>]*>([\s\S]{0,80}?)<\/a>/giu;
    let m;
    while ((m = linkRe.exec(String(html || "").slice(0, 250000))) !== null) {
      const href = m[1].trim();
      const label = m[2].replace(/<[^>]+>/gu, " ").trim();
      if (/\b(?:contact|reach\s+us|get\s+in\s+touch|locations?)\b/iu.test(`${href} ${label}`)) {
        const resolved = new URL(href, base.origin);
        if (registrableRoot(resolved.hostname) === registrableRoot(base.hostname)) {
          resolved.hash = "";
          return resolved.toString();
        }
      }
    }
    return new URL("/contact", base.origin).toString();
  } catch (_) {
    return "";
  }
}

async function fetchHtml(url) {
  const res = await fetch(url, {
    method: "GET",
    redirect: "follow",
    headers: {
      "User-Agent": "Mozilla/5.0 (compatible; PipeBuyerDirectoryVerifier/1.0; +https://pipebuyer.com)",
      "Accept": "text/html,application/xhtml+xml;q=0.9,*/*;q=0.5",
    },
    signal: AbortSignal.timeout(7000),
  });
  if (!res.ok) return "";
  const ct = String(res.headers.get("content-type") || "").toLowerCase();
  if (ct && !ct.includes("html") && !ct.includes("text") && !ct.includes("xml")) return "";
  const text = await res.text();
  return text.slice(0, 450000);
}

async function enrichWebsiteEmail(websiteUrl) {
  const normalizedUrl = normalizeWebsiteUrl(websiteUrl);
  if (!normalizedUrl) return {email: "", status: "skipped_host"};
  const host = new URL(normalizedUrl).hostname;
  try {
    const homeHtml = await fetchHtml(normalizedUrl);
    if (!homeHtml) return {email: "", status: "unreachable"};
    const homeEmail = extractEmailsFromHtml(homeHtml, host);
    if (homeEmail) return {email: homeEmail, status: "found_home"};

    const contactUrl = discoverContactPageUrl(homeHtml, normalizedUrl);
    if (contactUrl && contactUrl !== normalizedUrl) {
      const contactHtml = await fetchHtml(contactUrl).catch(() => "");
      if (contactHtml) {
        const contactEmail = extractEmailsFromHtml(contactHtml, host);
        if (contactEmail) return {email: contactEmail, status: "found_contact"};
      }
    }
    return {email: "", status: "no_public_email"};
  } catch (_) {
    return {email: "", status: "timeout_or_error"};
  }
}

async function fetchAllCandidateCompanies() {
  const token = await resolveAccessToken();
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`;
  const out = [];
  let last = null;
  while (true) {
    const sq = {
      from: [{collectionId: "yellow_pages_companies"}],
      select: {
        fields: [
          {fieldPath: "companyName"},
          {fieldPath: "website"},
          {fieldPath: "publicEmail"},
          {fieldPath: "generalEmail"},
          {fieldPath: "countryCode"},
          {fieldPath: "regionCode"},
          {fieldPath: "city"},
          {fieldPath: "publicationStatus"},
          {fieldPath: "operationalStatus"},
          {fieldPath: "isFlaggedProhibited"},
          {fieldPath: "doNotContact"},
        ],
      },
      orderBy: [{field: {fieldPath: "__name__"}, direction: "ASCENDING"}],
      limit: 3000,
    };
    if (last) sq.startAt = {values: [{referenceValue: last}], before: false};
    const res = await fetch(url, {
      method: "POST",
      headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
      body: JSON.stringify({structuredQuery: sq}),
      signal: AbortSignal.timeout(60000),
    });
    if (!res.ok) throw new Error(`runQuery HTTP ${res.status}: ${await res.text()}`);
    const docs = (await res.json()).filter((r) => r.document).map((r) => r.document);
    if (!docs.length) break;
    out.push(...docs);
    last = docs[docs.length - 1].name;
    if (docs.length < 3000) break;
  }
  return out;
}

async function commitUpdates(writes) {
  const byDoc = new Map();
  for (const w of writes) {
    if (w.update && w.update.name) {
      const key = w.update.name;
      const prev = byDoc.get(key);
      if (prev && prev.update) {
        prev.update.fields = {...prev.update.fields, ...w.update.fields};
        const mergedPaths = new Set([
          ...(prev.updateMask?.fieldPaths || []),
          ...(w.updateMask?.fieldPaths || []),
        ]);
        prev.updateMask = {fieldPaths: [...mergedPaths]};
      } else {
        byDoc.set(key, w);
      }
    }
  }
  const deduped = [...byDoc.values()];
  for (let i = 0; i < deduped.length; i += 400) {
    const chunk = deduped.slice(i, i + 400);
    const token = await resolveAccessToken();
    const res = await fetch(
      `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:commit`,
      {
        method: "POST",
        headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
        body: JSON.stringify({writes: chunk}),
        signal: AbortSignal.timeout(60000),
      },
    );
    if (!res.ok) throw new Error(`commit HTTP ${res.status}: ${await res.text()}`);
  }
}

async function main() {
  let ledger = {scannedIds: {}, foundCount: 0, updatedAt: null};
  if (fs.existsSync(LEDGER_PATH)) {
    try {
      ledger = JSON.parse(await fsp.readFile(LEDGER_PATH, "utf8"));
      if (!ledger.scannedIds) ledger.scannedIds = {};
    } catch (_) {
      ledger = {scannedIds: {}, foundCount: 0, updatedAt: null};
    }
  }

  console.log(`[bot24] Loading active businesses with websites (limit=${LIMIT}, apply=${APPLY})...`);
  const docs = await fetchAllCandidateCompanies();
  const queue = [];

  for (const doc of docs) {
    const id = doc.name.split("/").pop();
    if (ledger.scannedIds[id]) continue;
    const f = doc.fields || {};
    if (boolVal(f, "isFlaggedProhibited") || boolVal(f, "doNotContact")) continue;
    const pubStatus = strVal(f, "publicationStatus");
    if (pubStatus && pubStatus !== "published") continue;
    const cc = strVal(f, "countryCode").toUpperCase();
    const rc = strVal(f, "regionCode").toUpperCase();
    if (COUNTRY_FILTER && cc !== COUNTRY_FILTER) continue;
    if (REGION_FILTER && rc !== REGION_FILTER) continue;

    const existingEmail = resolveCompanyOutreachEmail({
      publicEmail: strVal(f, "publicEmail"),
      generalEmail: strVal(f, "generalEmail"),
    });
    if (existingEmail) continue;

    const website = normalizeWebsiteUrl(strVal(f, "website"));
    if (!website) continue;

    queue.push({
      id,
      docName: doc.name,
      companyName: strVal(f, "companyName"),
      website,
      countryCode: cc,
      regionCode: rc,
      city: strVal(f, "city"),
    });
    if (queue.length >= LIMIT) break;
  }

  console.log(`[bot24] Scanning ${queue.length} company websites with concurrency=${CONCURRENCY}...`);
  const enriched = [];
  const statusCounts = {};
  const domainCache = new Map();
  let idx = 0;

  async function worker() {
    while (idx < queue.length) {
      const current = queue[idx++];
      const hostKey = new URL(current.website).origin;
      let outcome = domainCache.get(hostKey);
      if (!outcome) {
        outcome = await enrichWebsiteEmail(current.website);
        domainCache.set(hostKey, outcome);
      }
      statusCounts[outcome.status] = (statusCounts[outcome.status] || 0) + 1;
      ledger.scannedIds[current.id] = outcome.email ? outcome.email : outcome.status;
      if (outcome.email) {
        enriched.push({...current, email: outcome.email, sourceStatus: outcome.status});
      }
    }
  }

  await Promise.all(Array.from({length: Math.min(CONCURRENCY, queue.length || 1)}, () => worker()));

  if (APPLY && enriched.length > 0) {
    const nowIso = new Date().toISOString();
    const writes = enriched.map((item) => ({
      update: {
        name: item.docName,
        fields: {
          generalEmail: toFirestoreValue(item.email),
          emailSource: toFirestoreValue("company_website_public"),
          emailEnrichedAt: toFirestoreValue(nowIso),
          updatedAt: toFirestoreValue(nowIso),
        },
      },
      updateMask: {
        fieldPaths: ["generalEmail", "emailSource", "emailEnrichedAt", "updatedAt"],
      },
    }));
    console.log(`[bot24] Committing ${writes.length} enriched B2B emails to yellow_pages_companies...`);
    await commitUpdates(writes);

    ledger.foundCount = Number(ledger.foundCount || 0) + enriched.length;
    ledger.updatedAt = nowIso;
    await fsp.mkdir(path.dirname(LEDGER_PATH), {recursive: true});
    await fsp.writeFile(LEDGER_PATH, JSON.stringify(ledger, null, 2));
  }

  console.log(JSON.stringify({
    ok: true,
    applied: APPLY,
    scannedWebsites: queue.length,
    newlyEnrichedEmails: enriched.length,
    yieldPercent: queue.length > 0 ? Number(((enriched.length / queue.length) * 100).toFixed(1)) : 0,
    statusCounts,
    sampleEnriched: enriched.slice(0, 12).map((e) => ({
      id: e.id,
      companyName: e.companyName,
      city: e.city,
      regionCode: e.regionCode,
      website: e.website,
      email: e.email,
    })),
  }, null, 2));
}

main().catch((err) => {
  console.error("[bot24] Error:", err.message);
  process.exit(1);
});
