#!/usr/bin/env node
/**
 * Live Production Verification Script for PipeBuyer Global Oilfield Directory
 *
 * Calls the live deployed `searchPipeBuyerYellowPages` Cloud Function on
 * `flutter-flow-pipe` across Worldwide, all 7 World Continents/Regions, and
 * key Popular Oil & Gas countries to prove end-to-end live data availability.
 */

const ENDPOINT = "https://us-central1-flutter-flow-pipe.cloudfunctions.net/searchPipeBuyerYellowPages";

async function queryDirectory(data) {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({data: {limit: 5, ...data}}),
    signal: AbortSignal.timeout(20000),
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${await res.text()}`);
  }
  const json = await res.json();
  return json.result || {};
}

async function main() {
  console.log("=== Live Production Verification (`searchPipeBuyerYellowPages` on `flutter-flow-pipe`) ===\n");

  const world = await queryDirectory({});
  console.log(`Worldwide Total Matched: ${world.totalMatched}`);

  const continents = [
    ["north_america", "North America"],
    ["middle_east", "Middle East"],
    ["europe", "Europe"],
    ["asia", "Asia"],
    ["south_america", "South America"],
    ["africa", "Africa"],
    ["oceania", "Australia & Oceania"],
  ];

  console.log("\n--- By Continent / World Region ---");
  for (const [code, label] of continents) {
    const r = await queryDirectory({continentCode: code});
    const sample = (r.entries || []).slice(0, 2).map((e) => `${e.companyName} (${e.countryCode})`).join("; ");
    console.log(`  • ${label.padEnd(22)} [${code.padEnd(14)}]: ${String(r.totalMatched).padStart(6)} verified | Sample: ${sample}`);
  }

  const popularCountries = [
    "CA", "US", "MX", "TT",
    "AE", "SA", "QA", "KW", "OM", "IQ",
    "GB", "NO", "NL", "DE", "IT", "RO", "FR", "PL", "ES",
    "BR", "GY", "AR", "CO", "EC", "PE",
    "SG", "MY", "ID", "IN", "CN", "KZ", "AZ", "JP", "KR", "VN", "TH",
    "AU", "NZ", "PG",
    "NG", "EG", "AO", "DZ", "GH", "ZA",
  ];

  console.log("\n--- By Popular Oil & Gas Country ---");
  const countryRows = [];
  for (let i = 0; i < popularCountries.length; i += 8) {
    const slice = popularCountries.slice(i, i + 8);
    const resList = await Promise.all(
      slice.map(async (cc) => {
        const r = await queryDirectory({countryCode: cc});
        return {cc, count: r.totalMatched || 0};
      }),
    );
    countryRows.push(...resList);
  }
  for (const {cc, count} of countryRows) {
    process.stdout.write(`${cc}:${count}  `);
  }
  console.log("\n");
}

main().catch((err) => {
  console.error("Verification failed:", err);
  process.exit(1);
});
