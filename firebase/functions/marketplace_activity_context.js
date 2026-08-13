"use strict";

function text(value, maximum = 180) {
  return String(value || "").trim().slice(0, maximum);
}

function finiteNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}

function listingThumbnail(listing) {
  const images = Array.isArray(listing && listing.imageUrls) ?
    listing.imageUrls.map((value) => text(value, 2048)).filter(Boolean) : [];
  const selected = text(listing && listing.thumbnailUrl, 2048);
  if (selected && images.includes(selected)) return selected;
  return images[0] || "";
}

/**
 * Denormalizes public listing context onto private activity documents.
 * Participant-only offer terms are intentionally excluded.
 * @param {Object} listing public listing data
 * @return {Object} bounded activity context
 */
function marketplaceListingActivityContext(listing = {}) {
  const title = text(listing.title);
  if (!title) return {};
  const quantity = finiteNumber(listing.quantity);
  const price = finiteNumber(listing.price);
  const thumbnail = listingThumbnail(listing);
  return {
    listingContextVersion: 1,
    listingTitle: title,
    ...(thumbnail ? {listingThumbnailUrl: thumbnail} : {}),
    ...(quantity == null ? {} : {listingQuantity: Math.round(quantity)}),
    ...(price == null ? {} : {listingPrice: price}),
    listingPriceBasis: text(listing.priceBasis, 100),
    listingCategory: text(listing.category, 160),
    listingSellerName: text(
        listing.sellerName || "Marketplace seller",
        160,
    ),
  };
}

function marketplaceMessagePreview(input = {}) {
  const message = text(input.text, 280);
  if (message) return message;
  if (input.attachment && input.attachment.type === "image") {
    return "Sent a photo about this listing.";
  }
  if (input.attachment) return "Sent an attachment about this listing.";
  return "Sent a new marketplace message.";
}

module.exports = {
  marketplaceListingActivityContext,
  marketplaceMessagePreview,
};
