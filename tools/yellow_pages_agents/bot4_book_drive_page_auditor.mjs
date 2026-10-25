#!/usr/bin/env node
/**
 * Bot 4 — 2015/2016 Physical Yellow Book & Google Drive Page Photo Tracker + Vision OCR Reconciler
 *
 * When Randall / Jordi take photos of the physical 2015/2016 COSSD 35th Anniversary Book
 * and upload them to a Google Drive folder (or local drop folder `data/yellow_pages/book_photos/`):
 * 1. Lists & syncs page photos from Google Drive (`--drive-folder <FOLDER_ID_OR_URL>`) or
 *    scans `--photos-dir <LOCAL_DIR>`.
 * 2. Computes SHA-256 hashes per photo so already-audited pages are never billed/processed twice.
 * 3. Calls Gemini Multimodal Vision (`GEMINI_API_KEY`) to extract structured JSON of every
 *    printed 2015/2016 listing on the page:
 *    `{ pageNumber, categoryHeader, listings: [{ companyName, phone2015, tollFree2015, city, region, services }] }`.
 * 4. Compares every 2015/2016 book listing against `03_audited_companies.json`:
 *    - Matches by normalized company name OR 10-digit NANPA phone.
 *    - Automatically flags `Old 2015/2016 Number -> New 2026 Number` updates!
 *    - Queues any book-only companies missing from web discovery for live operational audit!
 * 5. Writes `04_book_pages_manifest.json` and `04_book_drive_audit_status.md`.
 */

import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";

const require = createRequire(import.meta.url);
const {
  inferCountryAndRegion,
  classifyCategoriesFromText,
} = require("../../firebase/functions/yellow_pages_taxonomy.js");
const {
  normalizeNorthAmericanPhone,
  normalizedCompanyName,
} = require("../../firebase/functions/yellow_pages_policy.js");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const LEDGER_DIR = path.join(REPO_ROOT, "data/yellow_pages/ledger");
const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");
const DEFAULT_PHOTOS_DIR = path.join(REPO_ROOT, "data/yellow_pages/book_photos");

const IMAGE_EXTENSIONS = new Set([".jpg", ".jpeg", ".png", ".webp"]);

function extractDriveFolderId(input = "") {
  if (!input) return "";
  const match = String(input).match(/\/folders\/([a-zA-Z0-9_-]+)/u);
  if (match) return match[1];
  return String(input).trim();
}

async function listDriveFolderFiles(folderId) {
  const apiKey = process.env.GOOGLE_DRIVE_API_KEY || process.env.GEMINI_API_KEY || "";
  const bearer = process.env.GOOGLE_DRIVE_ACCESS_TOKEN || "";
  if (!apiKey && !bearer) {
    return {
      synced: false,
      files: [],
      note: "Set GOOGLE_DRIVE_ACCESS_TOKEN or GOOGLE_DRIVE_API_KEY to pull directly from Google Drive API, or drop synced Drive folder photos into data/yellow_pages/book_photos/.",
    };
  }
  const q = encodeURIComponent(`'${folderId}' in parents and trashed = false`);
  const url = `https://www.googleapis.com/drive/v3/files?q=${q}&fields=files(id,name,mimeType,webViewLink)&pageSize=200${apiKey && !bearer ? `&key=${apiKey}` : ""}`;
  const headers = bearer ? {Authorization: `Bearer ${bearer}`} : {};
  const res = await fetch(url, {headers});
  if (!res.ok) {
    return {synced: false, files: [], note: `Drive API returned HTTP ${res.status}`};
  }
  const data = await res.json();
  return {
    synced: true,
    files: (data.files || []).filter((f) => String(f.mimeType || "").startsWith("image/")),
  };
}

async function runGeminiVisionBookOcr(imageBytes, mimeType, fileName) {
  const apiKey = process.env.GEMINI_API_KEY || "";
  if (!apiKey) {
    return {
      ocrExecuted: false,
      reason: "GEMINI_API_KEY not set in environment; page registered as uploaded_pending_ocr.",
      pageNumber: inferPageNumberFromFilename(fileName),
      categoryHeader: "",
      listings: [],
    };
  }

  const prompt = [
    "You are auditing a photographed page from the 2015/2016 Oil & Gas Directory Book.",
    "Extract factual directory listings ONLY (never copy ad slogans or marketing paragraphs).",
    "Return strict JSON matching:",
    '{ "pageNumber": 1, "section": "yellow_services", "categoryHeader": "string", "listings": [ { "companyName": "string", "phone2015": "string", "tollFree2015": "string", "website2015": "string", "city": "string", "region": "string", "services": ["string"] } ] }',
  ].join("\n");

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({
        contents: [
          {
            parts: [
              {text: prompt},
              {
                inline_data: {
                  mime_type: mimeType,
                  data: imageBytes.toString("base64"),
                },
              },
            ],
          },
        ],
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0.1,
        },
      }),
    },
  );

  if (!res.ok) {
    return {
      ocrExecuted: false,
      reason: `Gemini Vision HTTP ${res.status}`,
      pageNumber: inferPageNumberFromFilename(fileName),
      categoryHeader: "",
      listings: [],
    };
  }
  const body = await res.json();
  const rawJson = body?.candidates?.[0]?.content?.parts?.[0]?.text || "{}";
  const parsed = JSON.parse(rawJson);
  return {
    ocrExecuted: true,
    pageNumber: Number(parsed.pageNumber) || inferPageNumberFromFilename(fileName),
    section: parsed.section || "yellow_services",
    categoryHeader: parsed.categoryHeader || "",
    listings: Array.isArray(parsed.listings) ? parsed.listings : [],
  };
}

function inferPageNumberFromFilename(fileName = "") {
  const m = String(fileName).match(/(?:page|pg|p)[_-]?0*(\d{1,4})/iu) ||
    String(fileName).match(/(\d{1,4})/u);
  return m ? Number(m[1]) : 1;
}

export async function runBookDrivePageAuditor({
  photosDir = DEFAULT_PHOTOS_DIR,
  driveFolder = "",
} = {}) {
  await fs.mkdir(LEDGER_DIR, {recursive: true});
  await fs.mkdir(REPORTS_DIR, {recursive: true});
  await fs.mkdir(photosDir, {recursive: true});

  const manifestPath = path.join(LEDGER_DIR, "04_book_pages_manifest.json");
  let existingManifest = {pages: {}, bookOnlyAdditions: []};
  try {
    existingManifest = JSON.parse(await fs.readFile(manifestPath, "utf8"));
  } catch (_) {
    // First run
  }

  let auditedLedger = {companies: []};
  try {
    auditedLedger = JSON.parse(
      await fs.readFile(path.join(LEDGER_DIR, "03_audited_companies.json"), "utf8"),
    );
  } catch (_) {
    // No audited ledger yet
  }

  const byNormName = new Map();
  const byDigits10 = new Map();
  for (const comp of auditedLedger.companies || []) {
    if (comp.normalizedCompanyName) byNormName.set(comp.normalizedCompanyName, comp);
    for (const rawP of [comp.mainPhone, comp.oldDirectoryPhone, ...(comp.legacyPhones || [])]) {
      const p = normalizeNorthAmericanPhone(rawP);
      if (p.validNanpa) byDigits10.set(p.digits10, comp);
    }
  }

  let driveStatus = {synced: false, files: [], note: "No --drive-folder specified (local folder ready)."};
  const folderId = extractDriveFolderId(driveFolder);
  if (folderId) {
    driveStatus = await listDriveFolderFiles(folderId);
    for (const df of driveStatus.files) {
      const pageNum = inferPageNumberFromFilename(df.name);
      const key = `drive-${df.id}`;
      if (!existingManifest.pages[key]) {
        existingManifest.pages[key] = {
          pageId: key,
          bookEdition: "2015-2016-35th-anniversary",
          pageNumber: pageNum,
          fileName: df.name,
          driveFileId: df.id,
          driveFileUrl: df.webViewLink || `https://drive.google.com/file/d/${df.id}/view`,
          auditStatus: "drive_registered_ready_for_ocr",
          extractedCompanyCount: 0,
          matchedDatabaseCount: 0,
          activeConfirmedCount: 0,
          numberChangedCount: 0,
          updatedAt: new Date().toISOString(),
        };
      }
    }
  }

  // Scan local photos folder (supports Google Drive for Desktop synced folders or direct drops)
  const dirEntries = await fs.readdir(photosDir, {withFileTypes: true});
  const imageFiles = dirEntries
    .filter((d) => d.isFile() && IMAGE_EXTENSIONS.has(path.extname(d.name).toLowerCase()))
    .map((d) => d.name)
    .sort();

  const bookOnlyAdditions = [...(existingManifest.bookOnlyAdditions || [])];

  for (const fileName of imageFiles) {
    const fullPath = path.join(photosDir, fileName);
    const bytes = await fs.readFile(fullPath);
    const sha256 = crypto.createHash("sha256").update(bytes).digest("hex");

    if (
      existingManifest.pages[sha256] &&
      existingManifest.pages[sha256].auditStatus === "audited_and_reconciled"
    ) {
      continue;
    }

    const ext = path.extname(fileName).toLowerCase();
    const mimeType =
      ext === ".png" ? "image/png" : ext === ".webp" ? "image/webp" : "image/jpeg";
    const ocr = await runGeminiVisionBookOcr(bytes, mimeType, fileName);

    let matchedDb = 0;
    let activeConfirmed = 0;
    let numberChanged = 0;

    for (const item of ocr.listings || []) {
      const normName = normalizedCompanyName(item.companyName || "");
      const phone2015 = normalizeNorthAmericanPhone(item.phone2015 || "");
      const existing =
        byNormName.get(normName) ||
        (phone2015.validNanpa ? byDigits10.get(phone2015.digits10) : null);

      if (existing) {
        matchedDb += 1;
        if (
          existing.operationalStatus === "active_in_operation" ||
          existing.operationalStatus === "active_number_updated"
        ) {
          activeConfirmed += 1;
        }
        const currNorm = normalizeNorthAmericanPhone(existing.mainPhone);
        if (phone2015.validNanpa && currNorm.validNanpa && phone2015.digits10 !== currNorm.digits10) {
          numberChanged += 1;
          if (!existing.legacyPhones.includes(phone2015.display)) {
            existing.legacyPhones.push(phone2015.display);
          }
        }
      } else if (normName) {
        const geo = inferCountryAndRegion("", item.region || "AB");
        bookOnlyAdditions.push({
          recordId: `book2015-p${ocr.pageNumber}-${normName.slice(0, 28)}`,
          companyName: item.companyName,
          normalizedCompanyName: normName,
          countryCode: geo.countryCode,
          regionCode: geo.regionCode,
          city: item.city || "",
          directoryPhone: phone2015.display || item.phone2015 || "",
          tollFreePhone: normalizeNorthAmericanPhone(item.tollFree2015 || "").display,
          website: item.website2015 || "",
          categoryCodes: classifyCategoriesFromText(
            [ocr.categoryHeader || "", ...(item.services || [])],
            item.companyName,
          ),
          services: item.services || [],
          sourceReferences: [
            {
              sourceType: "physical_book_2015_2016",
              sourceLabel: `2015/2016 Book Page ${ocr.pageNumber}`,
              discoveredAt: new Date().toISOString(),
            },
          ],
        });
      }
    }

    existingManifest.pages[sha256] = {
      pageId: sha256.slice(0, 16),
      sha256,
      bookEdition: "2015-2016-35th-anniversary",
      pageNumber: ocr.pageNumber,
      categoryHeader: ocr.categoryHeader,
      fileName,
      auditStatus: ocr.ocrExecuted ? "audited_and_reconciled" : "uploaded_pending_ocr",
      extractedCompanyCount: (ocr.listings || []).length,
      matchedDatabaseCount: matchedDb,
      activeConfirmedCount: activeConfirmed,
      numberChangedCount: numberChanged,
      notes: ocr.reason || "",
      updatedAt: new Date().toISOString(),
    };
  }

  const outManifest = {
    updatedAt: new Date().toISOString(),
    photosDirectory: photosDir,
    driveFolderId: folderId || null,
    driveSyncNote: driveStatus.note || "Synced",
    totalPagesTracked: Object.keys(existingManifest.pages).length,
    pages: existingManifest.pages,
    bookOnlyAdditions,
  };

  await fs.writeFile(manifestPath, JSON.stringify(outManifest, null, 2), "utf8");

  const md = [
    "# Bot 4 — 2015/2016 Physical Yellow Book & Google Drive Page Tracker",
    "",
    `- **Updated At**: \`${outManifest.updatedAt}\``,
    `- **Local / Synced Drive Drop Folder**: \`${photosDir}\``,
    `- **Pages Tracked**: **${outManifest.totalPagesTracked}**`,
    `- **Book-Only Companies Queued for Live Audit**: **${bookOnlyAdditions.length}**`,
    "",
    "## How to Upload 2015/2016 Book Photos for Automated Page-by-Page Tracking",
    "1. Snap clear photos of pages from the **2015/2016 COSSD 35th Anniversary Book** (include the page number and category header at the top).",
    "2. Upload to your shared Google Drive folder (pass `--drive-folder <URL>` to Bot 4) OR drop/sync them into `pipeapp/data/yellow_pages/book_photos/`.",
    "3. Run `GEMINI_API_KEY=<key> node tools/yellow_pages_agents/bot4_book_drive_page_auditor.mjs` to OCR every listing, compare against our live audited database, record **2015 Old Number -> 2026 New Number** changes, and sync page status to the Admin Portal **2015/2016 Book Pages** tab.",
    "",
  ];
  await fs.writeFile(
    path.join(REPORTS_DIR, "04_book_drive_audit_status.md"),
    md.join("\n"),
    "utf8",
  );
  console.log(`[Bot 4] Book page manifest updated (${outManifest.totalPagesTracked} pages tracked) -> ${manifestPath}`);
  return outManifest;
}

if (process.argv[1]?.endsWith("bot4_book_drive_page_auditor.mjs")) {
  const driveIdx = process.argv.indexOf("--drive-folder");
  const dirIdx = process.argv.indexOf("--photos-dir");
  runBookDrivePageAuditor({
    driveFolder: driveIdx !== -1 ? process.argv[driveIdx + 1] : "",
    photosDir: dirIdx !== -1 ? path.resolve(process.argv[dirIdx + 1]) : DEFAULT_PHOTOS_DIR,
  }).catch((err) => {
    console.error("[Bot 4 Error]", err.message);
    process.exitCode = 1;
  });
}
