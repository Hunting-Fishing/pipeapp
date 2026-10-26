"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {isAdministrator} = require("./administrator_authorization");
const {
  CATEGORY_BY_CODE,
  COUNTRY_BY_CODE,
  GLOBAL_COUNTRIES_LIST,
  WORLD_CONTINENTS,
  YELLOW_PAGES_CATEGORIES,
  canonicalizeCityName,
  checkB2BCallingWindow,
  classifyCategoriesFromText,
  countryCodesForContinent,
  expandServiceSearchTerms,
  inferCountryAndRegion,
  normalizeCityKey,
  normalizeText,
} = require("./yellow_pages_taxonomy");
const {
  BILLING_STATUSES,
  LISTING_TIERS,
  OPERATIONAL_STATUSES,
  PUBLICATION_STATUSES,
  STAFF_ROLES,
  VERIFICATION_STATUSES,
  buildAdminSearchTokens,
  buildPublicEntry,
  defaultCompanyWorkflow,
  isPublicEntryCurrent,
  isPublicationEligible,
  normalizeGlobalPhone,
  normalizeLogoUrl,
  normalizePhoneHistory,
  normalizedCompanyName,
  stringList,
  text,
} = require("./yellow_pages_policy");
const {
  GlobalPaymentPolicyError,
  assertCountryPayableWithStripe,
  isElevatedSanctionsCountry,
} = require("./global_payment_policy");

const PRIVATE_COMPANIES = "yellow_pages_companies";
const PRIVATE_CONTACT_EVENTS = "yellow_pages_contact_events";
const STAFF = "yellow_pages_staff";
const AUDIT = "yellow_pages_audit_events";
const PUBLIC_ENTRIES = "yellow_pages_public_entries";
const BLOCKED_NUMBERS = "yellow_pages_blocked_numbers";
const LISTING_REQUESTS = "yellow_pages_listing_requests";
const BOOK_PAGES = "yellow_pages_book_pages";
const DIRECTORY_META = "yellow_pages_meta";
const DIRECTORY_COUNTS_DOC = "directory_counts";
const COUNTS_MEMORY_TTL_MS = 10 * 60 * 1000;

function unpackTownsPacked(townsPacked) {
  if (typeof townsPacked !== "string" || !townsPacked.trim()) return [];
  return townsPacked
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean)
      .map((line) => {
        const [city = "", regionCode = "", countryCode = "", countStr = "0"] = line.split("\t");
        const count = Math.max(0, Math.trunc(Number(countStr) || 0));
        return city && countryCode && count > 0 ? [city, regionCode, countryCode, count] : null;
      })
      .filter(Boolean);
}

function packTownsList(towns) {
  if (!Array.isArray(towns)) return "";
  return towns
      .map(([city, regionCode, countryCode, count]) =>
        `${String(city || "").replace(/[\t\r\n]+/gu, " ")}\t${regionCode || ""}\t${countryCode || ""}\t${count}`,
      )
      .join("\n");
}

function aggregatePublicEntriesForCounts(entries) {
  let totalBusinesses = 0;
  const byContinent = {};
  const byCountry = {};
  const byRegion = {};
  const byCategory = {};
  const byTown = new Map();

  for (const entry of entries) {
    if (!isPublicEntryCurrent(entry)) continue;
    totalBusinesses += 1;

    const cc = String(entry.countryCode || "").trim().toUpperCase();
    const rawRc = String(entry.regionCode || "").trim().toUpperCase();
    const rc = rawRc === cc ? "" : rawRc;
    const countryMeta = COUNTRY_BY_CODE.get(cc);

    if (cc) byCountry[cc] = (byCountry[cc] || 0) + 1;
    if (countryMeta) {
      const cCode = countryMeta.continent || countryMeta.continentCode;
      if (cCode) byContinent[cCode] = (byContinent[cCode] || 0) + 1;
      if (countryMeta.alsoAsia && cCode !== "asia") {
        byContinent.asia = (byContinent.asia || 0) + 1;
      }
      if (countryMeta.alsoEurope && cCode !== "europe") {
        byContinent.europe = (byContinent.europe || 0) + 1;
      }
      if (countryMeta.isMiddleEast || entry.isMiddleEast === true) {
        byContinent.middle_east = (byContinent.middle_east || 0) + 1;
      }
    } else if (entry.continentCode) {
      const cCode = String(entry.continentCode).toLowerCase();
      byContinent[cCode] = (byContinent[cCode] || 0) + 1;
      if (entry.isMiddleEast === true) {
        byContinent.middle_east = (byContinent.middle_east || 0) + 1;
      }
    }

    if (cc && rc) {
      const rKey = `${cc}:${rc}`;
      byRegion[rKey] = (byRegion[rKey] || 0) + 1;
    }

    for (const cat of (entry.categoryCodes || [])) {
      if (cat) byCategory[cat] = (byCategory[cat] || 0) + 1;
    }

    const cleanCity = canonicalizeCityName(entry.city, rc, cc);
    if (cleanCity && cc) {
      const tKey = `${cc}|${rc}|${normalizeCityKey(cleanCity)}`;
      const existing = byTown.get(tKey);
      if (existing) {
        existing.count += 1;
      } else {
        byTown.set(tKey, {
          city: cleanCity,
          regionCode: rc,
          countryCode: cc,
          count: 1,
        });
      }
    }
  }

  const towns = [...byTown.values()]
      .sort((a, b) => a.city.localeCompare(b.city))
      .map((t) => [t.city, t.regionCode, t.countryCode, t.count]);

  return {
    totalBusinesses,
    byContinent,
    byCountry,
    byRegion,
    byCategory,
    towns,
  };
}

function secondFactor(token) {
  const value = token && token.firebase && token.firebase.sign_in_second_factor;
  return typeof value === "string" && value.trim().length > 0;
}

function jsonSafe(value) {
  if (value == null) return value;
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(jsonSafe);
  if (typeof value === "object") {
    return Object.fromEntries(
        Object.entries(value).map(([key, child]) => [key, jsonSafe(child)]),
    );
  }
  return value;
}

function pageSize(value, fallback = 50, max = 100) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.max(1, Math.min(max, Math.trunc(number)));
}

function sourceReferences(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 25).map((entry) => ({
    sourceType: text(entry && entry.sourceType, 80),
    sourceName: text(entry && entry.sourceName, 160),
    sourceUrl: text(entry && entry.sourceUrl, 1000),
    sourceExternalId: text(entry && entry.sourceExternalId, 200),
    observedAt: text(entry && entry.observedAt, 80),
    bookPage: text(entry && entry.bookPage, 40),
  })).filter((entry) => entry.sourceName || entry.sourceUrl || entry.sourceExternalId);
}

function enrichCompanyForClient(id, companyData) {
  const geo = inferCountryAndRegion(companyData.countryCode, companyData.regionCode);
  const callingWindow = checkB2BCallingWindow(geo.timeZone);
  return {
    id,
    ...jsonSafe(companyData),
    callingWindow,
  };
}

function createYellowPagesCommands(admin, {notifyAdministrators} = {}) {
  const db = () => admin.firestore();
  const auth = () => admin.auth();
  const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp();
  const increment = (n) => admin.firestore.FieldValue.increment(n);

  let cachedDirectoryCounts = null;
  let cachedDirectoryCountsAt = 0;

  async function loadOrComputeDirectoryCounts({forceRefresh = false} = {}) {
    if (!forceRefresh && cachedDirectoryCounts &&
        Date.now() - cachedDirectoryCountsAt < COUNTS_MEMORY_TTL_MS) {
      return cachedDirectoryCounts;
    }

    if (!forceRefresh) {
      try {
        const metaSnap = await db()
            .collection(DIRECTORY_META)
            .doc(DIRECTORY_COUNTS_DOC)
            .get();
        if (metaSnap && metaSnap.exists) {
          const metaData = metaSnap.data() || {};
          if (typeof metaData.totalBusinesses === "number" && metaData.totalBusinesses > 0) {
            const unpacked = {
              totalBusinesses: metaData.totalBusinesses,
              byContinent: jsonSafe(metaData.byContinent || {}),
              byCountry: jsonSafe(metaData.byCountry || {}),
              byRegion: jsonSafe(metaData.byRegion || {}),
              byCategory: jsonSafe(metaData.byCategory || {}),
              towns: Array.isArray(metaData.towns) ?
                metaData.towns :
                unpackTownsPacked(metaData.townsPacked || ""),
            };
            cachedDirectoryCounts = unpacked;
            cachedDirectoryCountsAt = Date.now();
            return unpacked;
          }
        }
      } catch (_) {
        // Fallback to live collection scan if meta collection unavailable
      }
    }

    const col = db().collection(PUBLIC_ENTRIES);
    const query = typeof col.select === "function" ?
      col.select(
          "verified",
          "effectiveTier",
          "isPaidTier",
          "nonExpiringPaid",
          "paidThrough",
          "countryCode",
          "regionCode",
          "city",
          "continentCode",
          "isMiddleEast",
          "categoryCodes",
      ) :
      col;
    const snap = await query.limit(20000).get();
    const entries = snap.docs.map((doc) => doc.data() || {});
    const computed = aggregatePublicEntriesForCounts(entries);

    try {
      await db().collection(DIRECTORY_META).doc(DIRECTORY_COUNTS_DOC).set({
        schemaVersion: 1,
        totalBusinesses: computed.totalBusinesses,
        byContinent: computed.byContinent,
        byCountry: computed.byCountry,
        byRegion: computed.byRegion,
        byCategory: computed.byCategory,
        townsPacked: packTownsList(computed.towns),
        updatedAt: serverTimestamp(),
      });
    } catch (_) {
      // Non-fatal in read-only or mock environments
    }

    cachedDirectoryCounts = computed;
    cachedDirectoryCountsAt = Date.now();
    return computed;
  }

  function parseTimestamp(value, label) {
    if (value == null || value === "") return null;
    const date = value instanceof Date ? value : new Date(String(value));
    if (Number.isNaN(date.getTime())) {
      throw new HttpsError("invalid-argument", `A valid ${label} is required.`);
    }
    return admin.firestore.Timestamp.fromDate(date);
  }

  async function resolveActor(request) {
    if (!request || !request.auth) return {authorized: false, reason: "signed_out"};
    const uid = request.auth.uid;
    const token = request.auth.token || {};
    const verifiedEmail = token.email_verified === true;
    const mfa = secondFactor(token);

    if (isAdministrator(request)) {
      if (!verifiedEmail) return {authorized: false, reason: "verified_email_required"};
      return {authorized: true, uid, role: "administrator", isAdmin: true};
    }

    const claimRole = text(token.yellowPagesRole, 40).toLowerCase();
    if (!STAFF_ROLES.has(claimRole)) return {authorized: false, reason: "role_missing"};
    if (!verifiedEmail) return {authorized: false, reason: "verified_email_required"};
    if (!mfa) return {authorized: false, reason: "mfa_required"};

    const roster = await db().collection(STAFF).doc(uid).get();
    const rosterData = roster.data() || {};
    if (!roster.exists || rosterData.active !== true || rosterData.role !== claimRole) {
      return {authorized: false, reason: "roster_inactive"};
    }
    return {
      authorized: true,
      uid,
      role: claimRole,
      isAdmin: false,
    };
  }

  async function requireActor(request, roles = ["agent", "manager", "administrator"]) {
    if (!request || !request.auth) {
      throw new HttpsError("unauthenticated", "Sign in to access the PipeBuyer Contact Center.");
    }
    const actor = await resolveActor(request);
    if (!actor.authorized || !roles.includes(actor.role)) {
      const message = actor.reason === "mfa_required" ?
        "Multi-factor authentication is required for Contact Center access." :
        "Your account is not authorized for this Yellow Pages action.";
      throw new HttpsError("permission-denied", message);
    }
    return actor;
  }

  async function audit(actor, action, companyId, details = {}) {
    await db().collection(AUDIT).add({
      schemaVersion: 2,
      actorUid: actor.uid,
      actorRole: actor.role,
      action,
      companyId: companyId || null,
      details,
      createdAt: serverTimestamp(),
    });
  }

  async function checkBlockedPhones(phoneValues = [], countryCode = "") {
    const blockedMatches = [];
    for (const raw of phoneValues) {
      const parsed = normalizeGlobalPhone(raw, countryCode);
      const keysToCheck = new Set();
      if (parsed.digits10 && parsed.digits10.length >= 7) keysToCheck.add(parsed.digits10);
      if (parsed.digitsKey && parsed.digitsKey.length >= 7) keysToCheck.add(parsed.digitsKey);
      for (const key of keysToCheck) {
        const snap = await db().collection(BLOCKED_NUMBERS).doc(key).get();
        if (snap.exists && (snap.data() || {}).active !== false) {
          blockedMatches.push({
            key,
            display: parsed.display || raw,
            reason: (snap.data() || {}).reason || "Blocked phone number",
          });
          break;
        }
      }
    }
    return blockedMatches;
  }

  async function getCompanyForActor(actor, companyId) {
    const id = text(companyId, 200);
    if (!id || id.includes("/")) {
      throw new HttpsError("invalid-argument", "A valid company ID is required.");
    }
    const snapshot = await db().collection(PRIVATE_COMPANIES).doc(id).get();
    if (!snapshot.exists) throw new HttpsError("not-found", "Company record not found.");
    const company = snapshot.data() || {};
    if (actor.role === "agent" && company.assignedAgentUid !== actor.uid) {
      throw new HttpsError("permission-denied", "This company is not assigned to your queue.");
    }
    return {id, snapshot, company};
  }

  async function reconcilePublicProjection(companyId) {
    const companyRef = db().collection(PRIVATE_COMPANIES).doc(companyId);
    const publicRef = db().collection(PUBLIC_ENTRIES).doc(companyId);
    await db().runTransaction(async (transaction) => {
      const companySnapshot = await transaction.get(companyRef);
      if (!companySnapshot.exists) {
        transaction.delete(publicRef);
        return;
      }
      const company = companySnapshot.data() || {};
      const entry = buildPublicEntry(company, companyId, serverTimestamp());
      if (entry) transaction.set(publicRef, entry);
      else transaction.delete(publicRef);
    });
    cachedDirectoryCounts = null;
    cachedDirectoryCountsAt = 0;
  }

  function matchesPublicFilters(entry, {
    expanded,
    continentCode,
    continentCountrySet,
    countryCode,
    regionCode,
    city,
    exactCityOnly = false,
    categoryCode,
    basin,
    certification,
    emergency24x7,
    paidOnly,
    tierFilter,
    hasTollFree,
    startsWith,
  }) {
    if (!isPublicEntryCurrent(entry)) return false;
    if (continentCode && continentCountrySet && continentCountrySet.size > 0) {
      const entryCountry = String(entry.countryCode || "").toUpperCase();
      if (!continentCountrySet.has(entryCountry)) return false;
    }
    if (countryCode && String(entry.countryCode || "").toUpperCase() !== countryCode) {
      return false;
    }
    if (regionCode && String(entry.regionCode || "").toUpperCase() !== regionCode) {
      return false;
    }
    if (city) {
      const targetCity = normalizeCityKey(city);
      const entryCity = normalizeCityKey(entry.city || "");
      if (exactCityOnly) {
        if (targetCity && entryCity !== targetCity) return false;
      } else {
        const areas = (entry.serviceAreas || []).map((a) => normalizeCityKey(a));
        if (targetCity && !entryCity.includes(targetCity) &&
            !areas.some((a) => a.includes(targetCity))) {
          return false;
        }
      }
    }
    if (categoryCode) {
      const codes = Array.isArray(entry.categoryCodes) ? entry.categoryCodes : [];
      if (!codes.includes(categoryCode)) return false;
    }
    if (basin) {
      const basinsNorm = (entry.basins || []).map((b) => normalizeText(b));
      const targetBasin = normalizeText(basin);
      if (!basinsNorm.some((b) => b.includes(targetBasin) || targetBasin.includes(b))) {
        return false;
      }
    }
    if (certification) {
      const certsNorm = (entry.certifications || []).map((c) => normalizeText(c));
      const targetCert = normalizeText(certification);
      if (!certsNorm.some((c) => c.includes(targetCert))) return false;
    }
    if (emergency24x7 && entry.emergency24x7 !== true) return false;
    if (paidOnly && entry.isPaidTier !== true) return false;
    if (tierFilter === "featured_only" && entry.isFeatured !== true) return false;
    if (tierFilter === "paid_only" && entry.isPaidTier !== true) return false;
    if (tierFilter === "verified_only" && entry.verified !== true) return false;
    if (tierFilter === "claimable_only" && entry.isPaidTier === true) return false;
    if (hasTollFree && !String(entry.tollFreePhone || "").trim()) return false;
    if (startsWith) {
      const firstChar = String(entry.companyName || "").trim().charAt(0).toUpperCase();
      if (startsWith === "#") {
        if (!firstChar || (firstChar >= "A" && firstChar <= "Z")) return false;
      } else if (firstChar !== startsWith) {
        return false;
      }
    }

    if (expanded.normalized) {
      const tokenSet = new Set(entry.searchTokens || []);
      const hay = normalizeText([
        entry.companyName,
        entry.city,
        entry.regionCode,
        entry.regionName,
        ...(entry.categories || []),
        ...(entry.services || []),
        ...(entry.basins || []),
        entry.description,
        entry.publicPhone,
      ].join(" "));

      // Match if direct phrase matches, category code matches, or expanded synonym terms match
      const directHit = hay.includes(expanded.normalized);
      const catHit = expanded.matchedCategoryCodes.some(
          (code) => (entry.categoryCodes || []).includes(code),
      );
      const queryWords = expanded.normalized.split(" ").filter((w) => w.length >= 2);
      const allWordsOrSynonymsHit = queryWords.length > 0 && queryWords.every((word) => {
        if (tokenSet.has(word) || hay.includes(word)) return true;
        return expanded.terms.some((syn) => tokenSet.has(syn));
      });
      const digitsQuery = expanded.normalized.replace(/\D+/gu, "");
      const phoneHit = digitsQuery.length >= 4 && tokenSet.has(digitsQuery);

      if (!directHit && !catHit && !allWordsOrSynonymsHit && !phoneHit) {
        return false;
      }
    }

    return true;
  }

  return {
    async getYellowPagesTaxonomy(request) {
      const data = (request && request.data) || {};
      const forceRefresh = data.refreshCounts === true;
      const counts = await loadOrComputeDirectoryCounts({forceRefresh});
      return {
        categories: YELLOW_PAGES_CATEGORIES,
        continents: WORLD_CONTINENTS,
        countries: GLOBAL_COUNTRIES_LIST,
        counts,
      };
    },

    async searchPipeBuyerYellowPages(request) {
      const data = (request && request.data) || {};
      const limit = pageSize(data.pageSize, 60, 120);
      const queryText = text(data.query, 120);
      const continentCode = text(data.continentCode, 32).toLowerCase();
      const countryCode = text(data.countryCode, 8).toUpperCase();
      const regionCode = text(data.regionCode, 20).toUpperCase();
      const city = text(data.city, 80);
      const categoryCode = text(data.categoryCode, 80).toLowerCase();
      const basin = text(data.basin, 80);
      const certification = text(data.certification, 80);
      const emergency24x7 = data.emergency24x7 === true;
      const paidOnly = data.paidOnly === true;
      const tierFilter = text(data.tierFilter, 32).toLowerCase();
      const hasTollFree = data.hasTollFree === true;
      const startsWith = text(data.startsWith, 4).toUpperCase();
      const sortBy = text(data.sortBy, 32).toLowerCase() || "priority";

      const continentCountries = continentCode ? countryCodesForContinent(continentCode) : [];
      const continentCountrySet = new Set(continentCountries);

      const expanded = expandServiceSearchTerms(queryText);
      const filterOpts = {
        expanded,
        continentCode,
        continentCountrySet,
        countryCode,
        regionCode,
        city,
        categoryCode,
        basin,
        certification,
        emergency24x7,
        paidOnly,
        tierFilter,
        hasTollFree,
        startsWith,
      };

      // Single-field server constraint to avoid composite index explosion,
      // followed by strict priority-tier ranking in memory over bounded candidates.
      let query = db().collection(PUBLIC_ENTRIES);
      let serverConstrainedOnly = !queryText && !city && !basin && !certification &&
        !emergency24x7 && !paidOnly && !tierFilter && !hasTollFree && !startsWith;

      if (categoryCode && CATEGORY_BY_CODE.has(categoryCode)) {
        query = query.where("categoryCodes", "array-contains", categoryCode);
        if (continentCode || countryCode || regionCode) serverConstrainedOnly = false;
      } else if (expanded.matchedCategoryCodes.length === 1 && !city) {
        query = query.where("categoryCodes", "array-contains", expanded.matchedCategoryCodes[0]);
      } else if (expanded.terms.length > 0 && expanded.matchedCategoryCodes.length === 0) {
        const primaryToken = expanded.terms[0].slice(0, 32);
        if (primaryToken.length >= 2) {
          query = query.where("searchTokens", "array-contains", primaryToken);
        }
      } else if (city) {
        const canonicalCity = canonicalizeCityName(city, regionCode, countryCode);
        if (canonicalCity) {
          query = query.where("city", "==", canonicalCity);
          filterOpts.exactCityOnly = true;
        } else if (regionCode) {
          query = query.where("regionCode", "==", regionCode);
        } else if (countryCode) {
          query = query.where("countryCode", "==", countryCode);
        }
      } else if (emergency24x7) {
        query = query.where("emergency24x7", "==", true);
        if (continentCode || countryCode || regionCode) serverConstrainedOnly = false;
      } else if (paidOnly || tierFilter === "paid_only") {
        query = query.where("isPaidTier", "==", true);
        if (continentCode || countryCode || regionCode) serverConstrainedOnly = false;
      } else if (tierFilter === "featured_only") {
        query = query.where("isFeatured", "==", true);
        if (continentCode || countryCode || regionCode) serverConstrainedOnly = false;
      } else if (tierFilter === "verified_only") {
        query = query.where("verified", "==", true);
        if (continentCode || countryCode || regionCode) serverConstrainedOnly = false;
      } else if (startsWith && /^[A-Z]$/u.test(startsWith)) {
        query = query
            .where("companyName", ">=", startsWith)
            .where("companyName", "<=", `${startsWith}\uf8ff`);
        serverConstrainedOnly = !continentCode && !countryCode && !regionCode && !basin &&
          !certification && !emergency24x7 && !paidOnly && !tierFilter && !hasTollFree;
      } else if (regionCode) {
        query = query.where("regionCode", "==", regionCode);
      } else if (countryCode) {
        query = query.where("countryCode", "==", countryCode);
      } else if (continentCode) {
        if (continentCode === "middle_east") {
          query = query.where("isMiddleEast", "==", true);
        } else if (continentCountries.length > 0 && continentCountries.length <= 30) {
          query = query.where("countryCode", "in", continentCountries);
        } else {
          query = query.where("continentCode", "==", continentCode);
        }
      } else if (sortBy === "name_asc") {
        query = query.orderBy("companyName", "asc");
      } else if (sortBy === "name_desc") {
        query = query.orderBy("companyName", "desc");
      }

      const candidateCap = city ? 1600 : 1200;
      const snapshot = await query.limit(candidateCap).get();
      let matched = snapshot.docs
          .map((doc) => ({id: doc.id, ...doc.data()}))
          .filter((entry) => matchesPublicFilters(entry, filterOpts));

      // Fallback broad scan if synonym/token/exact-city constraint missed partial or service-area matches
      if (matched.length === 0 && (queryText || city) && snapshot.docs.length < candidateCap) {
        const looseOpts = {...filterOpts, exactCityOnly: false};
        const cityDistinctWord = city ?
          normalizeCityKey(city)
              .split(" ")
              .filter((w) => w.length >= 3 && !["fort", "saint", "mount", "point", "port", "san", "new"].includes(w))[0] :
          null;
        const fallbackQuery = cityDistinctWord && !regionCode && !countryCode ?
          db().collection(PUBLIC_ENTRIES).where("searchTokens", "array-contains", cityDistinctWord.slice(0, 32)) :
          regionCode ?
            db().collection(PUBLIC_ENTRIES).where("regionCode", "==", regionCode) :
            countryCode ?
              db().collection(PUBLIC_ENTRIES).where("countryCode", "==", countryCode) :
              db().collection(PUBLIC_ENTRIES);
        const broadSnap = await fallbackQuery.limit(1200).get();
        matched = broadSnap.docs
            .map((doc) => ({id: doc.id, ...doc.data()}))
            .filter((entry) => matchesPublicFilters(entry, looseOpts));
      }

      let exactServerTotal = matched.length;
      if (serverConstrainedOnly && snapshot.docs.length >= candidateCap &&
          typeof query.count === "function") {
        try {
          const countSnap = await query.count().get();
          const serverNum = Number(countSnap.data().count || 0);
          if (serverNum > exactServerTotal) exactServerTotal = serverNum;
        } catch (_) {
          // Fallback to candidate window count
        }
      }

      // Commercial Priority Ranking (or explicit user sort with Priority tie-break)
      matched.sort((left, right) => {
        if (sortBy === "name_asc") {
          const nDiff = String(left.companyName || "").localeCompare(String(right.companyName || ""));
          if (nDiff !== 0) return nDiff;
          return Number(right.priorityScore || 0) - Number(left.priorityScore || 0);
        }
        if (sortBy === "name_desc") {
          const nDiff = String(right.companyName || "").localeCompare(String(left.companyName || ""));
          if (nDiff !== 0) return nDiff;
          return Number(right.priorityScore || 0) - Number(left.priorityScore || 0);
        }
        if (sortBy === "city_asc") {
          const cLeft = String(left.city || "zzz");
          const cRight = String(right.city || "zzz");
          const cDiff = cLeft.localeCompare(cRight);
          if (cDiff !== 0) return cDiff;
          const pDiff = Number(right.priorityScore || 0) - Number(left.priorityScore || 0);
          if (pDiff !== 0) return pDiff;
          return String(left.companyName || "").localeCompare(String(right.companyName || ""));
        }
        if (sortBy === "region_asc") {
          const rLeft = `${left.countryCode || ""}-${left.regionCode || ""}-${left.city || ""}`;
          const rRight = `${right.countryCode || ""}-${right.regionCode || ""}-${right.city || ""}`;
          const rDiff = rLeft.localeCompare(rRight);
          if (rDiff !== 0) return rDiff;
          return String(left.companyName || "").localeCompare(String(right.companyName || ""));
        }
        const pDiff = Number(right.priorityScore || 0) - Number(left.priorityScore || 0);
        if (pDiff !== 0) return pDiff;
        return String(left.companyName || "").localeCompare(String(right.companyName || ""));
      });

      const offset = Math.max(0, Math.min(matched.length, Number(data.offset || 0) || 0));
      const pageItems = matched.slice(offset, offset + limit).map(jsonSafe);
      const nextOffset = offset + limit < matched.length ? String(offset + limit) : null;

      return {
        entries: pageItems,
        totalMatched: exactServerTotal,
        nextCursor: nextOffset,
        expandedCategories: expanded.matchedCategoryCodes,
      };
    },

    async getPipeBuyerYellowPagesEntry(request) {
      const data = (request && request.data) || {};
      const companyId = text(data.companyId, 200);
      if (!companyId || companyId.includes("/")) {
        throw new HttpsError("invalid-argument", "A valid company ID is required.");
      }
      const snapshot = await db().collection(PUBLIC_ENTRIES).doc(companyId).get();
      if (!snapshot.exists || !isPublicEntryCurrent(snapshot.data() || {})) {
        throw new HttpsError("not-found", "Yellow Pages listing not found.");
      }
      return {id: snapshot.id, ...jsonSafe(snapshot.data())};
    },

    async recordYellowPagesLeadInteraction(request) {
      const data = (request && request.data) || {};
      const companyId = text(data.companyId, 200);
      const interactionType = text(data.interactionType, 40).toLowerCase();
      const allowed = new Set(["call_click", "website_click", "email_click", "rfq_click", "profile_view"]);
      if (!companyId || companyId.includes("/") || !allowed.has(interactionType)) {
        throw new HttpsError("invalid-argument", "Invalid lead interaction parameters.");
      }
      const publicSnap = await db().collection(PUBLIC_ENTRIES).doc(companyId).get();
      if (!publicSnap.exists) return {recorded: false};
      const counterField = `metrics_${interactionType}`;
      await db().collection(PRIVATE_COMPANIES).doc(companyId).set({
        [counterField]: increment(1),
        lastLeadInteractionAt: serverTimestamp(),
      }, {merge: true});
      return {recorded: true};
    },

    async submitYellowPagesServiceListingRequest(request) {
      if (!request || !request.auth) {
        throw new HttpsError("unauthenticated", "Sign in to submit or claim a service listing.");
      }
      const data = request.data || {};
      const companyName = text(data.companyName, 200);
      const contactName = text(data.contactName, 140);
      const phoneRaw = text(data.phone, 80);
      const email = text(data.email || (request.auth.token && request.auth.token.email), 254);
      const requestedTier = LISTING_TIERS.has(text(data.requestedTier, 40)) ?
        text(data.requestedTier, 40) : "paid_verified";

      if (!companyName || !phoneRaw) {
        throw new HttpsError("invalid-argument", "Company name and business phone number are required.");
      }
      const geo = inferCountryAndRegion(data.countryCode, data.regionCode);
      const city = text(data.city, 120);
      const rawInterval = text(data.billingInterval, 20).toLowerCase();
      const isFreeTier = requestedTier === "free_verified" || requestedTier === "free_basic";
      const billingInterval = isFreeTier ?
        "none" :
        (rawInterval === "monthly" || rawInterval === "month" ? "monthly" : "yearly");
      if (!isFreeTier) {
        try {
          assertCountryPayableWithStripe(
              geo.countryCode,
              `${geo.regionCode || ""} ${city}`,
          );
        } catch (err) {
          if (err instanceof GlobalPaymentPolicyError) {
            throw new HttpsError(err.code, err.message);
          }
          throw err;
        }
      }
      const phoneParsed = normalizeGlobalPhone(phoneRaw, geo.countryCode);
      if (!phoneParsed.validPhone) {
        throw new HttpsError("invalid-argument", "Enter a valid business phone number (with country or area code).");
      }

      // Enforce prohibited phone blacklist & flagged company shield
      const blocked = await checkBlockedPhones([phoneRaw, data.tollFreePhone], geo.countryCode);
      if (blocked.length > 0) {
        throw new HttpsError(
            "permission-denied",
            "This phone number is restricted from listing in the PipeBuyer Oilfield Directory. Contact support if you believe this is an error.",
        );
      }

      const normName = normalizedCompanyName(companyName);
      const existingFlagged = await db().collection(PRIVATE_COMPANIES)
          .where("normalizedCompanyName", "==", normName)
          .limit(5)
          .get();
      for (const doc of existingFlagged.docs) {
        if ((doc.data() || {}).isFlaggedProhibited === true) {
          throw new HttpsError(
              "permission-denied",
              "This business is currently restricted from listing in the PipeBuyer Oilfield Directory.",
          );
        }
      }

      const categories = stringList(data.categories, 20, 120);
      const services = stringList(data.services, 40, 160);
      const categoryCodes = classifyCategoriesFromText([...categories, ...services], data.description || "");
      const logoUrl = normalizeLogoUrl(data.logoUrl, {
        ErrorClass: HttpsError,
        fieldName: "logoUrl",
      });

      const docRef = await db().collection(LISTING_REQUESTS).add({
        schemaVersion: 2,
        submitterUid: request.auth.uid,
        claimedCompanyId: text(data.claimedCompanyId, 200) || null,
        companyName,
        normalizedCompanyName: normName,
        contactName,
        phone: phoneParsed.display || phoneRaw,
        phoneE164: phoneParsed.e164,
        tollFreePhone: text(data.tollFreePhone, 80),
        email,
        website: text(data.website, 500),
        logoUrl,
        countryCode: geo.countryCode,
        regionCode: geo.regionCode,
        city,
        serviceAreas: stringList(data.serviceAreas, 20, 120),
        basins: stringList(data.basins, 12, 80),
        categoryCodes,
        categories,
        services,
        certifications: stringList(data.certifications, 15, 80),
        emergency24x7: data.emergency24x7 === true,
        description: text(data.description, 2500),
        requestedTier,
        billingInterval,
        paymentStatus: isFreeTier ?
          "not_required" :
          "pending_checkout",
        paidThrough: null,
        elevatedSanctionsReviewRequired: isElevatedSanctionsCountry(geo.countryCode),
        status: "pending_review",
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });

      if (typeof notifyAdministrators === "function") {
        await notifyAdministrators({
          notificationId: `yp-request-${docRef.id}`,
          type: "yellow_pages_listing_request",
          title: `New List Services Request: ${companyName}`,
          body: `${companyName} (${geo.regionCode || geo.countryCode}) requested ${requestedTier.replace(/_/gu, " ")} placement.`,
        });
      }

      return {
        requestId: docRef.id,
        status: "pending_review",
        requestedTier,
        billingInterval,
        paymentStatus: isFreeTier ?
          "not_required" :
          "pending_checkout",
      };
    },

    async getYellowPagesAccess(request) {
      if (!request || !request.auth) {
        return {authorized: false, reason: "signed_out"};
      }
      const actor = await resolveActor(request);
      return {
        authorized: actor.authorized === true,
        role: actor.authorized ? actor.role : null,
        isAdmin: actor.isAdmin === true,
        reason: actor.authorized ? null : actor.reason,
      };
    },

    async searchAdminYellowPagesCompanies(request) {
      const actor = await requireActor(request, ["manager", "administrator"]);
      const data = request.data || {};
      const queryRaw = text(data.query, 120);
      const filterState = text(data.filterState, 40).toLowerCase();
      const limit = pageSize(data.pageSize, 60, 100);

      const normQuery = normalizeText(queryRaw);
      const queryDigits = queryRaw.replace(/\D+/gu, "");

      let query = db().collection(PRIVATE_COMPANIES);
      if (queryDigits.length >= 4) {
        query = query.where("adminSearchTokens", "array-contains", queryDigits.length > 10 ? queryDigits.slice(-10) : queryDigits);
      } else if (normQuery.length >= 2) {
        const firstWord = normQuery.split(" ")[0].slice(0, 32);
        query = query.where("adminSearchTokens", "array-contains", firstWord);
      } else if (filterState === "flagged") {
        query = query.where("isFlaggedProhibited", "==", true);
      } else if (filterState === "hidden") {
        query = query.where("adminViewingEnabled", "==", false);
      }

      const snap = await query.limit(250).get();
      let companies = snap.docs.map((doc) => enrichCompanyForClient(doc.id, doc.data() || {}));

      // Fallback scan for legacy records created before adminSearchTokens backfill
      if (companies.length === 0 && queryRaw) {
        const fallbackSnap = await db().collection(PRIVATE_COMPANIES).limit(250).get();
        companies = fallbackSnap.docs
            .map((doc) => enrichCompanyForClient(doc.id, doc.data() || {}))
            .filter((comp) => {
              const hay = normalizeText([
                comp.companyName,
                comp.city,
                comp.regionCode,
                comp.mainPhone,
                comp.publicPhone,
                comp.tollFreePhone,
                ...(comp.legacyPhones || []),
                comp.website,
              ].join(" "));
              const phoneHay = [
                comp.mainPhone,
                comp.publicPhone,
                comp.tollFreePhone,
                ...(comp.legacyPhones || []),
              ].join(" ").replace(/\D+/gu, "");
              return (normQuery && hay.includes(normQuery)) ||
                (queryDigits.length >= 4 && phoneHay.includes(queryDigits));
            });
      }

      if (filterState === "flagged") {
        companies = companies.filter((c) => c.isFlaggedProhibited === true);
      } else if (filterState === "hidden") {
        companies = companies.filter((c) => c.adminViewingEnabled === false);
      } else if (filterState === "visible") {
        companies = companies.filter((c) => c.adminViewingEnabled !== false && c.isFlaggedProhibited !== true);
      } else if (filterState === "paid") {
        companies = companies.filter((c) => c.billingStatus === "paid");
      } else if (filterState === "number_changed") {
        companies = companies.filter((c) => c.operationalStatus === "active_number_updated" || (c.legacyPhones && c.legacyPhones.length > 0));
      }

      return {
        companies: companies.slice(0, limit),
        totalFound: companies.length,
        actorRole: actor.role,
      };
    },

    async listYellowPagesDashboardView(request) {
      const actor = await requireActor(request);
      const data = request.data || {};
      const requestedView = text(data.view, 40).toLowerCase() || "my_queue";
      const limit = pageSize(data.pageSize, 50, 100);

      if (requestedView === "listing_requests") {
        if (actor.role === "agent") {
          throw new HttpsError("permission-denied", "Only managers and administrators can review inbound listing requests.");
        }
        const reqSnap = await db().collection(LISTING_REQUESTS).limit(100).get();
        const items = reqSnap.docs
            .map((doc) => ({id: doc.id, ...jsonSafe(doc.data() || {})}))
            .sort((a, b) => String(b.createdAt || "").localeCompare(String(a.createdAt || "")));
        return {view: requestedView, listingRequests: items, companies: [], nextCursor: null};
      }

      if (requestedView === "book_pages") {
        if (actor.role === "agent") {
          throw new HttpsError("permission-denied", "Only managers and administrators can inspect Book Audit pages.");
        }
        const pageSnap = await db().collection(BOOK_PAGES).limit(200).get();
        const pages = pageSnap.docs
            .map((doc) => ({id: doc.id, ...jsonSafe(doc.data() || {})}))
            .sort((a, b) => Number(a.pageNumber || 0) - Number(b.pageNumber || 0));
        return {view: requestedView, bookPages: pages, companies: [], nextCursor: null};
      }

      // Single equality constraint on Firestore to prevent composite index errors,
      // then apply view-specific predicates cleanly in memory.
      let query = db().collection(PRIVATE_COMPANIES);
      if (actor.role === "agent" || requestedView === "my_queue") {
        query = query.where("assignedAgentUid", "==", actor.uid);
      } else {
        switch (requestedView) {
          case "not_contacted":
            query = query.where("outreachStatus", "==", "not_contacted");
            break;
          case "follow_up":
            query = query.where("outreachStatus", "==", "follow_up");
            break;
          case "unverified":
            query = query.where("verificationStatus", "==", "unverified");
            break;
          case "verified_unpaid":
            query = query.where("verificationStatus", "==", "verified");
            break;
          case "paid_confirmed":
            query = query.where("billingStatus", "==", "paid");
            break;
          case "published":
            query = query.where("publicationStatus", "==", "published");
            break;
          case "expired":
            query = query.where("billingStatus", "==", "expired");
            break;
          case "flagged_prohibited":
            query = query.where("isFlaggedProhibited", "==", true);
            break;
          case "hidden_disabled":
            query = query.where("adminViewingEnabled", "==", false);
            break;
          case "do_not_contact":
            query = query.where("doNotContact", "==", true);
            break;
          case "all":
          default:
            break;
        }
      }

      const snap = await query.limit(250).get();
      let companies = snap.docs.map((doc) => enrichCompanyForClient(doc.id, doc.data() || {}));

      companies = companies.filter((c) => {
        switch (requestedView) {
          case "not_contacted":
            return c.outreachStatus === "not_contacted" && !c.doNotContact && !c.isFlaggedProhibited;
          case "follow_up":
            return c.outreachStatus === "follow_up" && !c.doNotContact;
          case "unverified":
            return c.verificationStatus === "unverified";
          case "verified_unpaid":
            return c.verificationStatus === "verified" && c.billingStatus === "unpaid";
          case "paid_confirmed":
            return c.billingStatus === "paid";
          case "published":
            return c.publicationStatus === "published" && c.adminViewingEnabled !== false && !c.isFlaggedProhibited;
          case "expired":
            return c.billingStatus === "expired";
          case "flagged_prohibited":
            return c.isFlaggedProhibited === true;
          case "hidden_disabled":
            return c.adminViewingEnabled === false;
          case "do_not_contact":
            return c.doNotContact === true;
          case "my_queue":
            return c.assignedAgentUid === actor.uid && !c.isFlaggedProhibited;
          case "all":
          default:
            return true;
        }
      });

      companies.sort((a, b) => String(a.companyName || "").localeCompare(String(b.companyName || "")));
      return {
        view: requestedView,
        companies: companies.slice(0, limit),
        totalInView: companies.length,
        nextCursor: null,
      };
    },

    async getYellowPagesCompany(request) {
      const actor = await requireActor(request);
      const data = request.data || {};
      const record = await getCompanyForActor(actor, data.companyId);

      const eventsSnap = await db().collection(PRIVATE_CONTACT_EVENTS)
          .where("companyId", "==", record.id)
          .limit(30)
          .get();
      const contactEvents = eventsSnap.docs
          .map((doc) => ({id: doc.id, ...jsonSafe(doc.data() || {})}))
          .sort((a, b) => String(b.createdAt || "").localeCompare(String(a.createdAt || "")));

      return {
        ...enrichCompanyForClient(record.id, record.company),
        contactEvents,
      };
    },

    async upsertYellowPagesCompany(request) {
      const actor = await requireActor(request, ["manager", "administrator"]);
      const data = request.data || {};
      const payload = data.company || {};
      const companyName = text(payload.companyName, 200);
      if (!companyName) throw new HttpsError("invalid-argument", "Company name is required.");

      const requestedId = text(data.companyId, 200);
      if (requestedId.includes("/")) {
        throw new HttpsError("invalid-argument", "Invalid company ID.");
      }

      const blocked = await checkBlockedPhones([
        payload.mainPhone,
        payload.publicPhone,
        payload.tollFreePhone,
      ], payload.countryCode);
      if (blocked.length > 0 && payload.allowBlockedOverride !== true) {
        throw new HttpsError(
            "failed-precondition",
            `Blocked phone number detected (${blocked[0].display}: ${blocked[0].reason}).`,
        );
      }

      const ref = requestedId ?
        db().collection(PRIVATE_COMPANIES).doc(requestedId) :
        db().collection(PRIVATE_COMPANIES).doc();
      const existingSnap = await ref.get();
      const existingData = existingSnap.data() || {};

      const geo = inferCountryAndRegion(
          payload.countryCode || existingData.countryCode,
          payload.regionCode || existingData.regionCode,
      );
      const mainPhoneParsed = normalizeGlobalPhone(payload.mainPhone ?? existingData.mainPhone, geo.countryCode);
      const publicPhoneParsed = normalizeGlobalPhone(payload.publicPhone ?? existingData.publicPhone ?? mainPhoneParsed.display, geo.countryCode);
      const tollFreeParsed = normalizeGlobalPhone(payload.tollFreePhone ?? existingData.tollFreePhone, geo.countryCode);

      const legacyPhones = stringList(
          payload.legacyPhones !== undefined ? payload.legacyPhones : (existingData.legacyPhones || []),
          15,
          80,
      );
      // Automatically preserve previous mainPhone in legacyPhones if number changed!
      const prevMainParsed = normalizeGlobalPhone(existingData.mainPhone, existingData.countryCode || geo.countryCode);
      if (prevMainParsed.e164 && mainPhoneParsed.e164 && prevMainParsed.e164 !== mainPhoneParsed.e164) {
        if (!legacyPhones.includes(prevMainParsed.display)) {
          legacyPhones.unshift(prevMainParsed.display);
        }
      }

      const categories = stringList(payload.categories ?? existingData.categories, 30, 120);
      const services = stringList(payload.services ?? existingData.services, 60, 160);
      const description = text(payload.description ?? existingData.description, 2500);
      const categoryCodes = classifyCategoriesFromText(
          [...(payload.categoryCodes || []), ...categories, ...services],
          description,
      );
      const operationalStatus = OPERATIONAL_STATUSES.has(text(payload.operationalStatus, 40)) ?
        text(payload.operationalStatus, 40) :
        (existingData.operationalStatus || "unverified");

      const mergedForTokens = {
        ...existingData,
        companyName,
        normalizedCompanyName: normalizedCompanyName(companyName),
        website: text(payload.website ?? existingData.website, 500),
        logoUrl: payload.logoUrl !== undefined ?
          normalizeLogoUrl(payload.logoUrl, {
            ErrorClass: HttpsError,
            fieldName: "logoUrl",
          }) :
          normalizeLogoUrl(existingData.logoUrl),
        countryCode: geo.countryCode,
        regionCode: geo.regionCode,
        city: text(payload.city ?? existingData.city, 120),
        mainPhone: mainPhoneParsed.display || text(payload.mainPhone, 80),
        publicPhone: publicPhoneParsed.display || text(payload.publicPhone, 80),
        tollFreePhone: tollFreeParsed.display || text(payload.tollFreePhone, 80),
        legacyPhones,
        generalEmail: text(payload.generalEmail ?? existingData.generalEmail, 254),
        publicEmail: text(payload.publicEmail ?? existingData.publicEmail, 254),
        categoryCodes,
        categories,
        services,
        basins: stringList(payload.basins ?? existingData.basins ?? geo.defaultBasins, 12, 80),
        serviceAreas: stringList(payload.serviceAreas ?? existingData.serviceAreas, 20, 120),
        certifications: stringList(payload.certifications ?? existingData.certifications, 15, 80),
        description,
      };

      const writable = {
        schemaVersion: 2,
        ...mergedForTokens,
        postalCode: text(payload.postalCode ?? existingData.postalCode, 40),
        streetAddress: text(payload.streetAddress ?? existingData.streetAddress, 300),
        emergency24x7: payload.emergency24x7 !== undefined ?
          payload.emergency24x7 === true :
          existingData.emergency24x7 === true,
        operationalStatus,
        phoneHistory: normalizePhoneHistory(
            payload.phoneHistory || existingData.phoneHistory,
            legacyPhones,
            mergedForTokens.mainPhone,
            geo.countryCode,
        ),
        sourceReferences: payload.sourceReferences ?
          sourceReferences(payload.sourceReferences) :
          (existingData.sourceReferences || []),
        adminSearchTokens: buildAdminSearchTokens(mergedForTokens),
        updatedAt: serverTimestamp(),
        updatedByUid: actor.uid,
      };

      if (!existingSnap.exists) {
        Object.assign(writable, defaultCompanyWorkflow(), {
          operationalStatus,
          assignedAgentUid: null,
          paidThrough: null,
          verifiedAt: null,
          verifiedByUid: null,
          publishedAt: null,
          publishedByUid: null,
          createdAt: serverTimestamp(),
          createdByUid: actor.uid,
        });
      }

      await ref.set(writable, {merge: existingSnap.exists});
      await audit(actor, existingSnap.exists ? "company_updated" : "company_created", ref.id, {
        operationalStatus,
        legacyPhonesCount: legacyPhones.length,
      });
      await reconcilePublicProjection(ref.id);
      return {companyId: ref.id};
    },

    async setYellowPagesCompanyVisibility(request) {
      const actor = await requireActor(request, ["administrator"]);
      const data = request.data || {};
      const companyId = text(data.companyId, 200);
      const visible = data.visible === true;
      const reason = text(data.reason, 500);
      if (!companyId || companyId.includes("/")) {
        throw new HttpsError("invalid-argument", "A valid company ID is required.");
      }

      const ref = db().collection(PRIVATE_COMPANIES).doc(companyId);
      const snap = await ref.get();
      if (!snap.exists) throw new HttpsError("not-found", "Company record not found.");
      const company = snap.data() || {};

      if (visible && company.isFlaggedProhibited === true) {
        throw new HttpsError(
            "failed-precondition",
            "Clear the Flagged / Prohibited status before enabling public viewing for this company.",
        );
      }

      const updates = {
        adminViewingEnabled: visible,
        visibilityReason: reason,
        visibilityUpdatedAt: serverTimestamp(),
        visibilityUpdatedByUid: actor.uid,
        updatedAt: serverTimestamp(),
        updatedByUid: actor.uid,
      };
      // If Admin turns viewing ON and opts to quick-publish, ensure publicationStatus is published without pre-verifying
      if (visible && data.publishImmediately === true) {
        updates.publicationStatus = "published";
        if (!company.operationalStatus || company.operationalStatus === "unverified") {
          updates.operationalStatus = "active_in_operation";
        }
        updates.publishedAt = company.publishedAt || serverTimestamp();
        updates.publishedByUid = actor.uid;
      }

      await ref.update(updates);
      await audit(actor, visible ? "company_viewing_enabled" : "company_viewing_disabled", companyId, {
        visible,
        reason,
      });
      await reconcilePublicProjection(companyId);
      return {companyId, adminViewingEnabled: visible};
    },

    async setYellowPagesFlaggedStatus(request) {
      const actor = await requireActor(request, ["administrator"]);
      const data = request.data || {};
      const companyId = text(data.companyId, 200);
      const flagged = data.flagged === true;
      const reason = text(data.reason, 1000);
      const blockPhones = data.blockPhones !== false;

      if (!companyId || companyId.includes("/")) {
        throw new HttpsError("invalid-argument", "A valid company ID is required.");
      }
      if (flagged && !reason) {
        throw new HttpsError("invalid-argument", "Provide a reason when flagging/prohibiting a business.");
      }

      const ref = db().collection(PRIVATE_COMPANIES).doc(companyId);
      const snap = await ref.get();
      if (!snap.exists) throw new HttpsError("not-found", "Company record not found.");
      const company = snap.data() || {};

      await ref.update({
        isFlaggedProhibited: flagged,
        flagReason: flagged ? reason : "",
        adminViewingEnabled: flagged ? false : company.adminViewingEnabled !== false,
        publicationStatus: flagged ? "suspended" : company.publicationStatus || "unpublished",
        operationalStatus: flagged ? "flagged_prohibited" : (company.operationalStatus === "flagged_prohibited" ? "unverified" : company.operationalStatus),
        doNotContact: flagged ? true : company.doNotContact === true,
        flaggedAt: flagged ? serverTimestamp() : null,
        flaggedByUid: flagged ? actor.uid : null,
        updatedAt: serverTimestamp(),
        updatedByUid: actor.uid,
      });

      const blockedNumbersWritten = [];
      if (flagged && blockPhones) {
        const phonesToBlock = [
          company.mainPhone,
          company.publicPhone,
          company.tollFreePhone,
          ...(company.legacyPhones || []),
        ];
        for (const raw of phonesToBlock) {
          const parsed = normalizeGlobalPhone(raw, company.countryCode);
          const docKey = parsed.digitsKey || parsed.digits10;
          if (!docKey || docKey.length < 7) continue;
          await db().collection(BLOCKED_NUMBERS).doc(docKey).set({
            digits10: parsed.digits10,
            digitsKey: docKey,
            e164: parsed.e164,
            display: parsed.display,
            companyId,
            companyName: company.companyName || "",
            reason,
            active: true,
            updatedAt: serverTimestamp(),
            updatedByUid: actor.uid,
          }, {merge: true});
          blockedNumbersWritten.push(parsed.display);
        }
      }

      await audit(actor, flagged ? "company_flagged_prohibited" : "company_flag_cleared", companyId, {
        flagged,
        reason,
        blockedNumbersWritten,
      });
      await reconcilePublicProjection(companyId);
      return {companyId, isFlaggedProhibited: flagged, blockedNumbersWritten};
    },

    async manageYellowPagesBlockedNumber(request) {
      const actor = await requireActor(request, ["administrator"]);
      const data = request.data || {};
      const phoneRaw = text(data.phone, 80);
      const active = data.active !== false;
      const reason = text(data.reason, 500) || "Prohibited phone number";
      const companyName = text(data.companyName, 200);

      const parsed = normalizeGlobalPhone(phoneRaw, data.countryCode);
      const docKey = parsed.digitsKey || parsed.digits10;
      if (!parsed.validPhone || !docKey) {
        throw new HttpsError("invalid-argument", "Enter a valid phone number.");
      }

      await db().collection(BLOCKED_NUMBERS).doc(docKey).set({
        digits10: parsed.digits10,
        digitsKey: docKey,
        e164: parsed.e164,
        display: parsed.display,
        companyName,
        reason: active ? reason : "",
        active,
        updatedAt: serverTimestamp(),
        updatedByUid: actor.uid,
      }, {merge: true});

      await audit(actor, active ? "phone_number_blocked" : "phone_number_unblocked", null, {
        phone: parsed.display,
        e164: parsed.e164,
        reason,
      });
      return {digits10: docKey, display: parsed.display, active};
    },

    async listYellowPagesBlockedNumbers(request) {
      await requireActor(request, ["manager", "administrator"]);
      const snap = await db().collection(BLOCKED_NUMBERS).limit(200).get();
      const items = snap.docs
          .map((doc) => ({id: doc.id, ...jsonSafe(doc.data() || {})}))
          .filter((item) => item.active !== false);
      return {blockedNumbers: items};
    },

    async assignYellowPagesCompany(request) {
      const actor = await requireActor(request, ["manager", "administrator"]);
      const data = request.data || {};
      const companyId = text(data.companyId, 200);
      const assignedAgentUid = text(data.assignedAgentUid, 200);
      if (!companyId || companyId.includes("/")) {
        throw new HttpsError("invalid-argument", "A company ID is required.");
      }
      if (assignedAgentUid) {
        const staff = await db().collection(STAFF).doc(assignedAgentUid).get();
        const staffData = staff.data() || {};
        if (!staff.exists || staffData.active !== true || !STAFF_ROLES.has(staffData.role)) {
          throw new HttpsError("failed-precondition", "The selected employee is not active in the Contact Center.");
        }
      }
      const ref = db().collection(PRIVATE_COMPANIES).doc(companyId);
      const current = await ref.get();
      if (!current.exists) throw new HttpsError("not-found", "Company record not found.");
      const update = {
        assignedAgentUid: assignedAgentUid || null,
        updatedAt: serverTimestamp(),
        updatedByUid: actor.uid,
      };
      const currentData = current.data() || {};
      if (!currentData.doNotContact && currentData.outreachStatus === "not_contacted" && assignedAgentUid) {
        update.outreachStatus = "assigned";
      }
      await ref.update(update);
      await audit(actor, "company_assignment_changed", companyId, {assignedAgentUid: assignedAgentUid || null});
      return {companyId, assignedAgentUid: assignedAgentUid || null};
    },

    async recordYellowPagesContactEvent(request) {
      const actor = await requireActor(request);
      const data = request.data || {};
      const record = await getCompanyForActor(actor, data.companyId);
      if (record.company.doNotContact === true || record.company.isFlaggedProhibited === true) {
        throw new HttpsError("failed-precondition", "Outbound contact is blocked for this company (DNC / Flagged).");
      }
      const eventType = text(data.eventType, 80);
      const disposition = text(data.disposition, 120);
      const summary = text(data.summary, 3000);
      if (!eventType) throw new HttpsError("invalid-argument", "A contact event type is required.");
      const nextFollowUpRaw = data.nextFollowUpAt;
      const nextFollowUpAt = nextFollowUpRaw ? parseTimestamp(nextFollowUpRaw, "follow-up date") : null;
      if (nextFollowUpAt && nextFollowUpAt.toMillis() <= Date.now()) {
        throw new HttpsError("failed-precondition", "Follow-up time must be in the future.");
      }
      const event = await db().collection(PRIVATE_CONTACT_EVENTS).add({
        schemaVersion: 2,
        companyId: record.id,
        actorUid: actor.uid,
        actorRole: actor.role,
        eventType,
        disposition,
        summary,
        contactId: text(data.contactId, 200) || null,
        nextFollowUpAt,
        createdAt: serverTimestamp(),
      });
      const outreachStatus = disposition === "interested" ?
        "qualified_interested" :
        (nextFollowUpAt ? "follow_up" : "attempted");
      await record.snapshot.ref.update({
        outreachStatus,
        lastContactAt: serverTimestamp(),
        lastContactByUid: actor.uid,
        lastDisposition: disposition,
        nextFollowUpAt: nextFollowUpAt || null,
        updatedAt: serverTimestamp(),
        updatedByUid: actor.uid,
      });
      return {eventId: event.id, outreachStatus};
    },

    async setYellowPagesDoNotContact(request) {
      const actor = await requireActor(request);
      const data = request.data || {};
      const enabled = data.enabled === true;
      if (!enabled && actor.role !== "administrator") {
        throw new HttpsError("permission-denied", "Only an administrator can clear Do Not Contact.");
      }
      const record = await getCompanyForActor(
          actor.role === "administrator" ? {...actor, role: "administrator"} : actor,
          data.companyId,
      );
      const reason = text(data.reason, 1000);
      if (!reason) {
        throw new HttpsError("invalid-argument", "A reason is required when changing Do Not Contact status.");
      }
      await record.snapshot.ref.update({
        doNotContact: enabled,
        doNotContactReason: reason,
        outreachStatus: enabled ? "do_not_contact" : "not_contacted",
        updatedAt: serverTimestamp(),
        updatedByUid: actor.uid,
      });
      await audit(actor, enabled ? "dnc_enabled" : "dnc_cleared", record.id, {reason});
      return {companyId: record.id, doNotContact: enabled};
    },

    async reviewYellowPagesVerification(request) {
      const actor = await requireActor(request, ["manager", "administrator"]);
      const data = request.data || {};
      const companyId = text(data.companyId, 200);
      const status = text(data.status, 40).toLowerCase();
      if (!VERIFICATION_STATUSES.has(status)) {
        throw new HttpsError("invalid-argument", "Invalid verification status.");
      }
      const ref = db().collection(PRIVATE_COMPANIES).doc(companyId);
      const snap = await ref.get();
      if (!snap.exists) throw new HttpsError("not-found", "Company record not found.");
      const current = snap.data() || {};
      const operationalStatus = text(data.operationalStatus, 40) ||
        (status === "verified" ? (current.operationalStatus === "unverified" ? "active_in_operation" : current.operationalStatus) :
        status === "inactive" ? "closed_inactive" : current.operationalStatus || "unverified");

      await ref.update({
        verificationStatus: status,
        operationalStatus,
        verifiedAt: status === "verified" ? serverTimestamp() : null,
        verifiedByUid: status === "verified" ? actor.uid : null,
        verificationReviewNote: text(data.reviewNote, 2000),
        updatedAt: serverTimestamp(),
        updatedByUid: actor.uid,
      });
      await audit(actor, "verification_reviewed", companyId, {status, operationalStatus});
      await reconcilePublicProjection(companyId);
      return {companyId, verificationStatus: status, operationalStatus};
    },

    async setYellowPagesBillingStatus(request) {
      const actor = await requireActor(request, ["administrator"]);
      const data = request.data || {};
      const companyId = text(data.companyId, 200);
      const status = text(data.status, 40).toLowerCase();
      if (!BILLING_STATUSES.has(status)) {
        throw new HttpsError("invalid-argument", "Invalid billing status.");
      }
      const ref = db().collection(PRIVATE_COMPANIES).doc(companyId);
      const snap = await ref.get();
      if (!snap.exists) throw new HttpsError("not-found", "Company record not found.");
      const current = snap.data() || {};

      const listingTier = LISTING_TIERS.has(text(data.listingTier, 40)) ?
        text(data.listingTier, 40) :
        (status === "paid" ?
          "paid_verified" :
          (current.verificationStatus === "verified" ? "free_verified" : "free_basic"));
      const nonExpiringPaid = status === "paid" && data.nonExpiringPaid === true;
      const paidThrough = status === "paid" && !nonExpiringPaid ?
        parseTimestamp(data.paidThrough, "paid-through date") :
        null;
      if (status === "paid" && !nonExpiringPaid && (!paidThrough || paidThrough.toMillis() <= Date.now())) {
        throw new HttpsError("invalid-argument", "A future paid-through date is required for paid status.");
      }

      const billingUpdate = {
        billingStatus: status,
        listingTier,
        paidThrough,
        nonExpiringPaid,
        allowUnpaidPublic: data.allowUnpaidPublic !== undefined ? data.allowUnpaidPublic === true : true,
        paymentReference: text(data.paymentReference, 300) || null,
        billingReviewNote: text(data.reviewNote, 2000),
        updatedAt: serverTimestamp(),
        updatedByUid: actor.uid,
      };
      if (status === "paid" && current.verificationStatus !== "verified") {
        billingUpdate.verificationStatus = "verified";
        billingUpdate.verifiedAt = serverTimestamp();
        billingUpdate.verifiedByUid = actor.uid;
      }
      await ref.update(billingUpdate);
      await audit(actor, "billing_status_changed", companyId, {
        status,
        listingTier,
        paidThrough: paidThrough ? paidThrough.toDate().toISOString() : null,
        nonExpiringPaid,
      });
      await reconcilePublicProjection(companyId);
      return {companyId, billingStatus: status, listingTier};
    },

    async setYellowPagesPublicationStatus(request) {
      const actor = await requireActor(request, ["administrator"]);
      const data = request.data || {};
      const companyId = text(data.companyId, 200);
      const status = text(data.status, 40).toLowerCase();
      if (!PUBLICATION_STATUSES.has(status)) {
        throw new HttpsError("invalid-argument", "Invalid publication status.");
      }
      const ref = db().collection(PRIVATE_COMPANIES).doc(companyId);
      const snap = await ref.get();
      if (!snap.exists) throw new HttpsError("not-found", "Company record not found.");
      const company = snap.data() || {};
      if (status === "published" && !isPublicationEligible({...company, publicationStatus: "published"})) {
        throw new HttpsError(
            "failed-precondition",
            "Company must be operational, unflagged, and viewing-enabled before publishing.",
        );
      }
      await ref.update({
        publicationStatus: status,
        publishedAt: status === "published" ?
          (company.publishedAt || serverTimestamp()) : company.publishedAt || null,
        publishedByUid: status === "published" ? actor.uid : company.publishedByUid || null,
        publicationReviewNote: text(data.reviewNote, 2000),
        updatedAt: serverTimestamp(),
        updatedByUid: actor.uid,
      });
      await audit(actor, "publication_status_changed", companyId, {status});
      await reconcilePublicProjection(companyId);
      return {companyId, publicationStatus: status};
    },

    async reviewYellowPagesListingRequest(request) {
      const actor = await requireActor(request, ["administrator"]);
      const data = request.data || {};
      const requestId = text(data.requestId, 200);
      const decision = text(data.decision, 40).toLowerCase(); // approved | rejected
      if (!requestId || !["approved", "rejected"].includes(decision)) {
        throw new HttpsError("invalid-argument", "Valid requestId and decision (approved|rejected) are required.");
      }

      const reqRef = db().collection(LISTING_REQUESTS).doc(requestId);
      const reqSnap = await reqRef.get();
      if (!reqSnap.exists) throw new HttpsError("not-found", "Listing request not found.");
      const reqData = reqSnap.data() || {};

      let companyId = reqData.claimedCompanyId || null;
      if (decision === "approved") {
        const companyRef = companyId ?
          db().collection(PRIVATE_COMPANIES).doc(companyId) :
          db().collection(PRIVATE_COMPANIES).doc();
        companyId = companyRef.id;
        const isPaidTier = reqData.requestedTier === "featured_platinum" || reqData.requestedTier === "paid_verified";
        const stripePaid = reqData.paymentStatus === "paid";
        const markPaid = isPaidTier && (stripePaid || data.markPaid === true);
        const fallbackDays = reqData.billingInterval === "monthly" ? 31 : 365;
        const defaultPaidThrough = isPaidTier ?
          (reqData.paidThrough ||
            admin.firestore.Timestamp.fromMillis(Date.now() + fallbackDays * 24 * 60 * 60 * 1000)) :
          null;

        const merged = {
          schemaVersion: 2,
          companyName: reqData.companyName,
          normalizedCompanyName: reqData.normalizedCompanyName || normalizedCompanyName(reqData.companyName),
          website: reqData.website || "",
          ...(normalizeLogoUrl(reqData.logoUrl) ? {logoUrl: normalizeLogoUrl(reqData.logoUrl)} : {}),
          countryCode: reqData.countryCode || "CA",
          regionCode: reqData.regionCode || "",
          city: reqData.city || "",
          mainPhone: reqData.phone || "",
          publicPhone: reqData.phone || "",
          tollFreePhone: reqData.tollFreePhone || "",
          generalEmail: reqData.email || "",
          publicEmail: reqData.email || "",
          categoryCodes: reqData.categoryCodes || [],
          categories: reqData.categories || [],
          services: reqData.services || [],
          basins: reqData.basins || [],
          serviceAreas: reqData.serviceAreas || [],
          certifications: reqData.certifications || [],
          emergency24x7: reqData.emergency24x7 === true,
          description: reqData.description || "",
          legacyPhones: [],
          phoneHistory: normalizePhoneHistory([], [], reqData.phone || "", reqData.countryCode || "CA"),
          verificationStatus: "verified",
          operationalStatus: "active_in_operation",
          billingStatus: markPaid ? "paid" : "unpaid",
          listingTier: reqData.requestedTier || "free_verified",
          billingInterval: reqData.billingInterval || null,
          paidThrough: markPaid ? defaultPaidThrough : null,
          ...(reqData.stripeCustomerId ? {stripeCustomerId: reqData.stripeCustomerId} : {}),
          ...(reqData.stripeSubscriptionId ? {stripeSubscriptionId: reqData.stripeSubscriptionId} : {}),
          nonExpiringPaid: false,
          publicationStatus: "published",
          allowUnpaidPublic: true,
          adminViewingEnabled: true,
          isFlaggedProhibited: false,
          doNotContact: false,
          claimedByUid: reqData.submitterUid || null,
          verifiedAt: serverTimestamp(),
          verifiedByUid: actor.uid,
          publishedAt: serverTimestamp(),
          publishedByUid: actor.uid,
          updatedAt: serverTimestamp(),
          updatedByUid: actor.uid,
        };
        merged.adminSearchTokens = buildAdminSearchTokens(merged);
        await companyRef.set(merged, {merge: true});
        await reconcilePublicProjection(companyId);
      }

      await reqRef.update({
        status: decision,
        resolvedCompanyId: companyId,
        reviewedAt: serverTimestamp(),
        reviewedByUid: actor.uid,
        reviewNote: text(data.reviewNote, 1000),
      });
      await audit(actor, `listing_request_${decision}`, companyId, {requestId});
      return {requestId, decision, companyId};
    },

    async upsertYellowPagesBookPageAudit(request) {
      const actor = await requireActor(request, ["manager", "administrator"]);
      const data = request.data || {};
      const pageNumber = Math.max(1, Math.trunc(Number(data.pageNumber || 1)));
      const edition = text(data.bookEdition, 80) || "2015-2016-35th-anniversary";
      const docId = `${edition}-p${String(pageNumber).padStart(4, "0")}`;

      const record = {
        schemaVersion: 1,
        bookEdition: edition,
        pageNumber,
        section: text(data.section, 60) || "yellow_services",
        categoryHeader: text(data.categoryHeader, 160),
        driveFileId: text(data.driveFileId, 200),
        driveFileUrl: text(data.driveFileUrl, 1000),
        extractedCompanyCount: Math.max(0, Math.trunc(Number(data.extractedCompanyCount || 0))),
        matchedDatabaseCount: Math.max(0, Math.trunc(Number(data.matchedDatabaseCount || 0))),
        activeConfirmedCount: Math.max(0, Math.trunc(Number(data.activeConfirmedCount || 0))),
        numberChangedCount: Math.max(0, Math.trunc(Number(data.numberChangedCount || 0))),
        auditStatus: text(data.auditStatus, 40) || "uploaded",
        notes: text(data.notes, 2000),
        updatedAt: serverTimestamp(),
        updatedByUid: actor.uid,
      };
      await db().collection(BOOK_PAGES).doc(docId).set(record, {merge: true});
      await audit(actor, "book_page_audit_recorded", null, {docId, pageNumber, auditStatus: record.auditStatus});
      return {pageId: docId, pageNumber};
    },

    async listYellowPagesStaff(request) {
      await requireActor(request, ["manager", "administrator"]);
      const snap = await db().collection(STAFF).limit(200).get();
      return {staff: snap.docs.map((doc) => ({uid: doc.id, ...jsonSafe(doc.data() || {})}))};
    },

    async manageYellowPagesStaff(request) {
      const actor = await requireActor(request, ["administrator"]);
      const data = request.data || {};
      const email = text(data.email, 254).toLowerCase();
      const active = data.active !== false;
      const role = text(data.role, 40).toLowerCase();
      if (!email) throw new HttpsError("invalid-argument", "The employee email is required.");
      if (active && !STAFF_ROLES.has(role)) {
        throw new HttpsError("invalid-argument", "Contact Center role must be agent or manager.");
      }
      let user;
      try {
        user = await auth().getUserByEmail(email);
      } catch (error) {
        if (error && error.code === "auth/user-not-found") {
          throw new HttpsError("not-found", "The employee must create a Pipe Buyer account first.");
        }
        throw error;
      }
      if (active && user.emailVerified !== true) {
        throw new HttpsError("failed-precondition", "The employee must verify their email first.");
      }
      const factors = user.multiFactor && Array.isArray(user.multiFactor.enrolledFactors) ?
        user.multiFactor.enrolledFactors : [];
      if (active && factors.length === 0) {
        throw new HttpsError("failed-precondition", "The employee must enroll multi-factor authentication first.");
      }
      const claims = {...(user.customClaims || {})};
      if (active) claims.yellowPagesRole = role;
      else delete claims.yellowPagesRole;
      await auth().setCustomUserClaims(user.uid, claims);

      const rosterRef = db().collection(STAFF).doc(user.uid);
      const rosterSnap = await rosterRef.get();
      const rosterWrite = {
        uid: user.uid,
        email,
        displayName: text(user.displayName, 160),
        role: active ? role : null,
        active,
        updatedAt: serverTimestamp(),
        updatedByUid: actor.uid,
      };
      if (!rosterSnap.exists) {
        rosterWrite.createdAt = serverTimestamp();
        rosterWrite.createdByUid = actor.uid;
      }
      await rosterRef.set(rosterWrite, {merge: true});
      await auth().revokeRefreshTokens(user.uid);
      await audit(actor, active ? "staff_access_granted" : "staff_access_revoked", null, {
        targetUid: user.uid,
        targetEmail: email,
        role: active ? role : null,
      });
      return {uid: user.uid, email, active, role: active ? role : null};
    },
  };
}

module.exports = {
  createYellowPagesCommands,
  jsonSafe,
};
