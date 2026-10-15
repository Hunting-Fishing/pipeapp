"use strict";

const DEFAULT_NATIVE_RECONCILIATION_PAGE_SIZE = 200;
const DEFAULT_NATIVE_RECONCILIATION_MAX_PAGES = 10;

function normalizedPageSize(value) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) {
    return DEFAULT_NATIVE_RECONCILIATION_PAGE_SIZE;
  }
  return Math.min(parsed, 500);
}

function normalizedMaxPages(value) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) {
    return DEFAULT_NATIVE_RECONCILIATION_MAX_PAGES;
  }
  return Math.min(parsed, 100);
}

async function reconcileNativeMembershipPages({
  loadPage,
  reconcileDocument,
  startAfter = "",
  pageSize = DEFAULT_NATIVE_RECONCILIATION_PAGE_SIZE,
  maxPages = DEFAULT_NATIVE_RECONCILIATION_MAX_PAGES,
}) {
  if (typeof loadPage !== "function" || typeof reconcileDocument !== "function") {
    throw new TypeError("Native membership reconciliation is not configured.");
  }
  const limit = normalizedPageSize(pageSize);
  const pageLimit = normalizedMaxPages(maxPages);
  let cursor = String(startAfter || "");
  let checked = 0;
  let updated = 0;
  let failed = 0;
  let pages = 0;

  while (pages < pageLimit) {
    const documents = await loadPage({startAfter: cursor, limit});
    if (!Array.isArray(documents)) {
      throw new TypeError("Native membership reconciliation page must be an array.");
    }
    if (documents.length > limit) {
      throw new RangeError("Native membership reconciliation page exceeded its limit.");
    }
    pages += 1;
    for (const document of documents) {
      const documentId = String(document && document.id || "");
      if (!documentId) {
        throw new TypeError("Native membership reconciliation document has no ID.");
      }
      checked += 1;
      try {
        const result = await reconcileDocument(document);
        if (!result || result.skipped !== true) updated += 1;
      } catch (_) {
        failed += 1;
      }
      cursor = documentId;
    }
    if (documents.length < limit) {
      return {
        checked,
        updated,
        failed,
        pages,
        complete: true,
        nextCursor: "",
      };
    }
  }

  return {
    checked,
    updated,
    failed,
    pages,
    complete: false,
    nextCursor: cursor,
  };
}

module.exports = {
  DEFAULT_NATIVE_RECONCILIATION_MAX_PAGES,
  DEFAULT_NATIVE_RECONCILIATION_PAGE_SIZE,
  reconcileNativeMembershipPages,
};
