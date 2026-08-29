from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one match, found {count}\n--- needle ---\n{old[:700]}")
    p.write_text(text.replace(old, new, 1))


policy = "firebase/functions/marketplace_command_policy.js"
replace_once(
    policy,
    'function validateAuctionTransactionAction({\n  sale,\n  listing,\n  actorUid,\n  action,\n  reason,\n  administrator = false,\n}) {\n',
    'function paymentStatusAllowsCompletion(value) {\n'
    '  return ["paid", "external_agreed"].includes(String(value || ""));\n'
    '}\n\n'
    'function validateAuctionTransactionAction({\n'
    '  sale,\n'
    '  listing,\n'
    '  actorUid,\n'
    '  action,\n'
    '  reason,\n'
    '  paymentProviderStatus,\n'
    '  administrator = false,\n'
    '}) {\n',
)
replace_once(
    policy,
    '    if (status === "completed" && alreadyConfirmed) {\n      return {\n        actorRole,\n        alreadyApplied: true,\n        buyerConfirmed,\n        sellerConfirmed,\n        status,\n      };\n    }\n    if (!["pending_completion", "awaiting_buyer_confirmation",\n',
    '    if (status === "completed" && alreadyConfirmed) {\n'
    '      return {\n'
    '        actorRole,\n'
    '        alreadyApplied: true,\n'
    '        buyerConfirmed,\n'
    '        sellerConfirmed,\n'
    '        status,\n'
    '      };\n'
    '    }\n'
    '    if (!paymentStatusAllowsCompletion(paymentProviderStatus)) {\n'
    '      throw new CommandPolicyError(\n'
    '          "failed-precondition",\n'
    '          "The winning purchase must be paid before completion can be confirmed.",\n'
    '      );\n'
    '    }\n'
    '    if (!["pending_completion", "awaiting_buyer_confirmation",\n',
)
replace_once(
    policy,
    '    if (status === "completed" && alreadyConfirmed) {\n      return {\n        actorRole,\n        alreadyApplied: true,\n        buyerConfirmed,\n        sellerConfirmed,\n        status,\n      };\n    }\n    if (![\n      "pending_completion",\n',
    '    if (status === "completed" && alreadyConfirmed) {\n'
    '      return {\n'
    '        actorRole,\n'
    '        alreadyApplied: true,\n'
    '        buyerConfirmed,\n'
    '        sellerConfirmed,\n'
    '        status,\n'
    '      };\n'
    '    }\n'
    '    if (!paymentStatusAllowsCompletion(sale && sale.paymentProviderStatus)) {\n'
    '      throw new CommandPolicyError(\n'
    '          "failed-precondition",\n'
    '          "Secure payment or confirmed external settlement is required before completion.",\n'
    '      );\n'
    '    }\n'
    '    if (![\n'
    '      "pending_completion",\n',
)
replace_once(
    policy,
    '  minimumAuctionBid,\n  requireMoney,\n',
    '  minimumAuctionBid,\n  paymentStatusAllowsCompletion,\n  requireMoney,\n',
)

commands = "firebase/functions/marketplace_commands.js"
replace_once(
    commands,
    '    const listingRef = db.collection("public_listings").doc(listingId);\n    const saleRef = db.collection("auction_transactions").doc(listingId);\n    return db.runTransaction(async (transaction) => {\n',
    '    const listingRef = db.collection("public_listings").doc(listingId);\n'
    '    const saleRef = db.collection("auction_transactions").doc(listingId);\n'
    '    const paymentRef = db.collection("marketplace_transactions")\n'
    '        .doc(`auction_${listingId}`);\n'
    '    return db.runTransaction(async (transaction) => {\n',
)
replace_once(
    commands,
    '      const listingSnapshot = await transaction.get(listingRef);\n      const saleSnapshot = await transaction.get(saleRef);\n      const listing = listingSnapshot.exists ?\n',
    '      const listingSnapshot = await transaction.get(listingRef);\n'
    '      const saleSnapshot = await transaction.get(saleRef);\n'
    '      const paymentSnapshot = await transaction.get(paymentRef);\n'
    '      const listing = listingSnapshot.exists ?\n',
)
replace_once(
    commands,
    '        action,\n        reason,\n        administrator: isAdministrator(request),\n',
    '        action,\n'
    '        reason,\n'
    '        paymentProviderStatus: paymentSnapshot.exists ?\n'
    '          paymentSnapshot.data().paymentProviderStatus : "",\n'
    '        administrator: isAdministrator(request),\n',
)

# Update existing pure policy tests to model the new server payment prerequisite.
test_path = "firebase/functions/test/marketplace_command_policy.test.js"
replace_once(
    test_path,
    '    sellerConfirmed: false,\n  };\n  const buyer = validateAuctionTransactionAction({\n',
    '    sellerConfirmed: false,\n  };\n'
    '  assert.throws(\n'
    '      () => validateAuctionTransactionAction({\n'
    '        sale,\n'
    '        listing,\n'
    '        actorUid: "buyer",\n'
    '        action: "confirm_completion",\n'
    '        paymentProviderStatus: "checkout_created",\n'
    '      }),\n'
    '      (error) => error.code === "failed-precondition",\n'
    '  );\n'
    '  const buyer = validateAuctionTransactionAction({\n',
)
replace_once(
    test_path,
    '    actorUid: "buyer",\n    action: "confirm_completion",\n  });\n  assert.equal(buyer.status, "awaiting_seller_confirmation");\n',
    '    actorUid: "buyer",\n'
    '    action: "confirm_completion",\n'
    '    paymentProviderStatus: "paid",\n'
    '  });\n'
    '  assert.equal(buyer.status, "awaiting_seller_confirmation");\n',
)
replace_once(
    test_path,
    '    actorUid: "seller",\n    action: "confirm_completion",\n  });\n  assert.equal(seller.status, "completed");\n',
    '    actorUid: "seller",\n'
    '    action: "confirm_completion",\n'
    '    paymentProviderStatus: "paid",\n'
    '  });\n'
    '  assert.equal(seller.status, "completed");\n',
)
replace_once(
    test_path,
    '  const buyerResult = validateMarketplaceTransactionAction({\n    sale: null,\n    offer,\n    actorUid: "buyer",\n    action: "confirm_completion",\n  });\n',
    '  assert.throws(\n'
    '      () => validateMarketplaceTransactionAction({\n'
    '        sale: {\n'
    '          offerId: "offer",\n'
    '          buyerUid: "buyer",\n'
    '          sellerUid: "seller",\n'
    '          status: "pending_completion",\n'
    '          paymentProviderStatus: "checkout_created",\n'
    '        },\n'
    '        offer,\n'
    '        actorUid: "buyer",\n'
    '        action: "confirm_completion",\n'
    '      }),\n'
    '      (error) => error.code === "failed-precondition",\n'
    '  );\n'
    '  const buyerResult = validateMarketplaceTransactionAction({\n'
    '    sale: {\n'
    '      offerId: "offer",\n'
    '      buyerUid: "buyer",\n'
    '      sellerUid: "seller",\n'
    '      status: "pending_completion",\n'
    '      buyerConfirmed: false,\n'
    '      sellerConfirmed: false,\n'
    '      paymentProviderStatus: "paid",\n'
    '    },\n'
    '    offer,\n'
    '    actorUid: "buyer",\n'
    '    action: "confirm_completion",\n'
    '  });\n',
)
replace_once(
    test_path,
    '      status: buyerResult.status,\n      buyerConfirmed: true,\n      sellerConfirmed: false,\n',
    '      status: buyerResult.status,\n'
    '      buyerConfirmed: true,\n'
    '      sellerConfirmed: false,\n'
    '      paymentProviderStatus: "paid",\n',
)

print("Added server-side paid completion gates for marketplace and Timed Buying.")
