from pathlib import Path

PATH = Path("firebase/functions/integration/callable_integration.mjs")
text = PATH.read_text(encoding="utf-8")

marketplace_old = '''  const buyerConfirmationData = {
    requestId: `buyer-confirm-${now}`,
    offerId,
    action: "confirm_completion",
  };
  const buyerConfirmation = await call(
      "updateMarketplaceTransaction",
      buyer.token,
      buyerConfirmationData,
  );
'''
marketplace_new = '''  const buyerConfirmationData = {
    requestId: `buyer-confirm-${now}`,
    offerId,
    action: "confirm_completion",
  };
  const unpaidMarketplaceCompletion = await expectCallableError(
      "updateMarketplaceTransaction",
      buyer.token,
      buyerConfirmationData,
      "FAILED_PRECONDITION",
  );
  assert.match(unpaidMarketplaceCompletion.message, /payment|settlement/i);
  await db.doc(`marketplace_transactions/${offerId}`).update({
    paymentProviderStatus: "external_agreed",
    financialStatus: "external_settlement_confirmed",
    updatedAt: FieldValue.serverTimestamp(),
  });
  const buyerConfirmation = await call(
      "updateMarketplaceTransaction",
      buyer.token,
      buyerConfirmationData,
  );
'''

auction_old = '''  const auctionBuyerConfirmation = {
    requestId: `auction-buyer-confirm-${now}`,
    listingId: finalizationListingId,
    action: "confirm_completion",
  };
  const auctionBuyerResult = await call(
      "updateAuctionTransaction",
      buyer.token,
      auctionBuyerConfirmation,
  );
'''
auction_new = '''  const auctionBuyerConfirmation = {
    requestId: `auction-buyer-confirm-${now}`,
    listingId: finalizationListingId,
    action: "confirm_completion",
  };
  const unpaidAuctionCompletion = await expectCallableError(
      "updateAuctionTransaction",
      buyer.token,
      auctionBuyerConfirmation,
      "FAILED_PRECONDITION",
  );
  assert.match(unpaidAuctionCompletion.message, /paid|payment/i);
  const auctionPaymentPath =
    `marketplace_transactions/auction_${finalizationListingId}`;
  await waitForDocument(
      auctionPaymentPath,
      (data) => data.listingId === finalizationListingId,
  );
  await db.doc(auctionPaymentPath).set({
    paymentProviderStatus: "external_agreed",
    financialStatus: "external_settlement_confirmed",
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  const auctionBuyerResult = await call(
      "updateAuctionTransaction",
      buyer.token,
      auctionBuyerConfirmation,
  );
'''

changed = False
if marketplace_old in text:
    text = text.replace(marketplace_old, marketplace_new, 1)
    changed = True
elif marketplace_new not in text:
    raise SystemExit("Marketplace completion fixture was not found; repair aborted.")

if auction_old in text:
    text = text.replace(auction_old, auction_new, 1)
    changed = True
elif auction_new not in text:
    raise SystemExit("Auction completion fixture was not found; repair aborted.")

if changed:
    PATH.write_text(text, encoding="utf-8")
    print("Updated callable integration for paid-before-completion gate.")
else:
    print("Callable payment gate integration repair already applied.")
