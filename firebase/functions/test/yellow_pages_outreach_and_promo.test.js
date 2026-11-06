"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");

const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");
const {
  assertPromotionCompatibleWithBillingInterval,
  promotionCodeTargetsProduct,
} = require("../subscription_promotion_resolver");
const {isYellowPagesCheckoutSessionPaid} = require("../yellow_pages_billing");
const {
  DEFAULT_PROMO_CODE,
  buildYellowPagesOutreachEmail,
  evaluateOutreachEligibility,
  normalizeOutreachEmail,
  signUnsubscribeToken,
  verifySvixWebhookSignature,
  verifyUnsubscribeToken,
} = require("../yellow_pages_outreach");

test("pipebuyer2026 promotion config targets Dispatch, Verified Pro, and Featured Platinum for 6 months at 100% off", () => {
  const spec = stripeMarketplaceConfig.promotions.pipebuyer2026;
  assert.equal(spec.code, "pipebuyer2026");
  assert.equal(spec.promotionCodeId, "promo_1UYidsDkO07WMXyRU671qy2n");
  assert.equal(spec.couponId, "PIPEBUYER_2026_6M_FREE");
  assert.equal(spec.percentOff, 100);
  assert.equal(spec.duration, "repeating");
  assert.equal(spec.durationInMonths, 6);

  const mockStripePromo = {
    id: spec.promotionCodeId,
    code: spec.code,
    active: true,
    promotion: {
      coupon: {
        id: spec.couponId,
        percent_off: 100,
        duration: "repeating",
        duration_in_months: 6,
        applies_to: {
          products: [
            stripeMarketplaceConfig.products.dispatchMonthlyCad.productId,
            stripeMarketplaceConfig.products.yellowPagesVerifiedProMonthly.productId,
            stripeMarketplaceConfig.products.yellowPagesFeaturedMonthly.productId,
          ],
        },
      },
    },
  };

  assert.equal(
      promotionCodeTargetsProduct(
          mockStripePromo,
          stripeMarketplaceConfig.products.dispatchMonthlyCad.productId,
      ),
      true,
  );
  assert.equal(
      promotionCodeTargetsProduct(
          mockStripePromo,
          stripeMarketplaceConfig.products.yellowPagesVerifiedProMonthly.productId,
      ),
      true,
  );
  assert.equal(
      promotionCodeTargetsProduct(
          mockStripePromo,
          stripeMarketplaceConfig.products.yellowPagesFeaturedMonthly.productId,
      ),
      true,
  );
  assert.equal(
      promotionCodeTargetsProduct(
          mockStripePromo,
          stripeMarketplaceConfig.products.vipMonthlyCad.productId,
      ),
      false,
  );

  // Allowed on Monthly, rejected on Yearly so a 6-month coupon never discounts a 12-month invoice
  assert.doesNotThrow(() =>
    assertPromotionCompatibleWithBillingInterval(mockStripePromo, "monthly"),
  );
  assert.throws(
      () => assertPromotionCompatibleWithBillingInterval(mockStripePromo, "yearly"),
      /Monthly billing/i,
  );
});

test("Yellow Pages $0.00 first-invoice 100%-off promo checkouts settle as paid", () => {
  assert.equal(isYellowPagesCheckoutSessionPaid({payment_status: "paid"}), true);
  assert.equal(
      isYellowPagesCheckoutSessionPaid({payment_status: "no_payment_required"}),
      true,
  );
  assert.equal(isYellowPagesCheckoutSessionPaid({payment_status: "unpaid"}), false);
});

test("outreach email normalization, eligibility compliance, unsubscribe HMAC, and Svix verification", () => {
  assert.equal(
      normalizeOutreachEmail("mailto:Sales@FoothillsPipe.ca?subject=Quote"),
      "sales@foothillspipe.ca",
  );
  assert.equal(normalizeOutreachEmail("noreply@company.ca"), "");
  assert.equal(normalizeOutreachEmail("logo@2x.png"), "");
  assert.equal(normalizeOutreachEmail("user@sentry.io"), "");

  const baseCompany = {
    companyName: "Foothills Oilfield Supply Ltd.",
    publicationStatus: "published",
    operationalStatus: "unverified",
    countryCode: "CA",
    regionCode: "AB",
    city: "Nisku",
    publicEmail: "dispatch@foothillssupply.ca",
    categoryCodes: ["oilfield_supply_stores"],
  };

  assert.equal(evaluateOutreachEligibility(baseCompany).eligible, true);
  assert.equal(
      evaluateOutreachEligibility({...baseCompany, operationalStatus: "active_in_operation"}).eligible,
      true,
  );
  assert.equal(
      evaluateOutreachEligibility({...baseCompany, operationalStatus: "closed_inactive"}).reason,
      "inactive_business",
  );
  assert.equal(
      evaluateOutreachEligibility({...baseCompany, doNotContact: true}).reason,
      "do_not_contact",
  );
  assert.equal(
      evaluateOutreachEligibility({...baseCompany, isFlaggedProhibited: true}).reason,
      "flagged_prohibited",
  );
  assert.equal(
      evaluateOutreachEligibility({...baseCompany, emailBounced: true}).reason,
      "bounced_or_complained",
  );
  assert.equal(
      evaluateOutreachEligibility({...baseCompany, countryCode: "IR"}).reason,
      "sanctioned_jurisdiction",
  );
  assert.equal(
      evaluateOutreachEligibility({...baseCompany, claimedByUid: "uid_1"}).reason,
      "already_claimed_or_paid",
  );

  const secret = "test_hmac_secret_key_for_unsubscribe";
  const token = signUnsubscribeToken("comp_abc123", secret);
  assert.equal(verifyUnsubscribeToken("comp_abc123", token, secret), true);
  assert.equal(verifyUnsubscribeToken("comp_other", token, secret), false);
  assert.equal(verifyUnsubscribeToken("comp_abc123", `${token}x`, secret), false);

  const rendered = buildYellowPagesOutreachEmail({
    companyId: "comp_abc123",
    company: baseCompany,
    promoCode: DEFAULT_PROMO_CODE,
    siteOrigin: "https://pipebuyer.com",
    unsubscribeUrl: `https://pipebuyer.com/api/outreach/unsubscribe?cid=comp_abc123&t=${token}`,
  });
  assert.match(rendered.subject, /pipebuyer2026/);
  assert.equal(
      rendered.claimUrl,
      "https://pipebuyer.com/services/list?claim=comp_abc123&promo=pipebuyer2026",
  );
  assert.equal(
      rendered.dispatchUrl,
      "https://pipebuyer.com/payments/dispatch?promo=pipebuyer2026",
  );
  assert.match(rendered.html, /One-click Unsubscribe/);

  // Svix webhook verification
  const rawKey = Buffer.from("0123456789abcdef0123456789abcdef").toString("base64");
  const whsec = `whsec_${rawKey}`;
  const bodyBuf = Buffer.from(JSON.stringify({type: "email.delivered"}), "utf8");
  const nowSec = String(Math.floor(Date.now() / 1000));
  const msgId = "msg_test_1";
  const sig = crypto
      .createHmac("sha256", Buffer.from(rawKey, "base64"))
      .update(`${msgId}.${nowSec}.${bodyBuf.toString("utf8")}`)
      .digest("base64");
  assert.equal(
      verifySvixWebhookSignature(
          bodyBuf,
          {
            "svix-id": msgId,
            "svix-timestamp": nowSec,
            "svix-signature": `v1,${sig}`,
          },
          whsec,
      ),
      true,
  );
});
