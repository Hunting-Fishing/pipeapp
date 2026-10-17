"use strict";

const {
  loadProviderReadiness,
  providerUsesAccountsV2,
  refreshStripeRecipientAccountStatus,
} = require("./stripe_marketplace_commands");
const {
  requireStripeProviderMode,
  stripeSecretValueForMode,
} = require("./stripe_runtime_environment");
const {
  createStripeWebhookEventStore,
} = require("./stripe_webhook_event_store");
const {
  STRIPE_ACCOUNTS_V2_THIN_EVENTS,
} = require("./stripe_webhook_event_catalog");
const {
  stripeModeFromLivemode,
  verifyStripeSignature,
} = require("./stripe_webhook");

const STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_PRODUCTION_NAME =
  "STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_PRODUCTION";
const STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_SANDBOX_NAME =
  "STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_SANDBOX";

function createAccountsV2WebhookSecret(name, mode) {
  return Object.freeze({
    name,
    value() {
      const value = String(process.env[name] || "").trim();
      if (!value) {
        throw new Error(
            `Stripe Accounts v2 ${mode} webhook credentials are unavailable.`,
        );
      }
      return value;
    },
  });
}

const stripeAccountsV2ProductionWebhookSecret = createAccountsV2WebhookSecret(
    STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_PRODUCTION_NAME,
    "production",
);
const stripeAccountsV2SandboxWebhookSecret = createAccountsV2WebhookSecret(
    STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_SANDBOX_NAME,
    "sandbox",
);
const stripeAccountsV2WebhookSecretNames = Object.freeze([
  STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_PRODUCTION_NAME,
  STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_SANDBOX_NAME,
]);
const accountsV2ThinEventTypes = new Set(STRIPE_ACCOUNTS_V2_THIN_EVENTS);

function stripeAccountsV2WebhookSecretForMode(mode) {
  const normalized = String(mode || "").trim().toLowerCase();
  if (normalized === "production") {
    return stripeAccountsV2ProductionWebhookSecret;
  }
  if (normalized === "sandbox") return stripeAccountsV2SandboxWebhookSecret;
  throw new Error("Stripe Accounts v2 webhook processing is disabled.");
}

function stripeAccountIdFromThinEvent(event) {
  if (!event || event.object !== "v2.core.event") {
    throw new Error("Stripe Accounts v2 event object is invalid.");
  }
  const related = event.related_object;
  const accountId = String(related && related.id || "").trim();
  if (!accountId.startsWith("acct_") ||
      !related || related.type !== "v2.core.account" ||
      related.url !== `/v2/core/accounts/${accountId}`) {
    throw new Error("Stripe Accounts v2 related account is invalid.");
  }
  return accountId;
}

function stripeContextFromThinEvent(event) {
  const context = event && event.context;
  if (context == null) return null;
  if (typeof context !== "string" || !context.trim() ||
      context.length > 500 || /[\r\n]/u.test(context)) {
    throw new Error("Stripe Accounts v2 event context is invalid.");
  }
  return context.trim();
}

function createStripeAccountsV2WebhookHandler(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const webhookEventStore = options.webhookEventStore ||
    createStripeWebhookEventStore({db, admin});
  const readWebhookSecret = options.webhookSecretForMode ||
    options.webhookSecret ||
    ((mode) => stripeAccountsV2WebhookSecretForMode(mode).value());
  const readStripeMode = options.stripeMode || (async () => {
    const readiness = await loadProviderReadiness(db);
    return readiness.stripeMode;
  });
  const readStripeSecret = options.stripeSecretForMode ||
    ((mode) => stripeSecretValueForMode(mode));
  const refreshRecipientStatus = options.refreshStripeRecipientStatus ||
    refreshStripeRecipientAccountStatus;
  const requestRecipientAccount = options.stripeConnectRequest || null;

  async function synchronizeConnectedAccount({
    accountId,
    stripeMode,
    stripeContext,
  }) {
    const providers = await db.collection("payment_provider_accounts")
        .where("stripeAccountId", "==", accountId)
        .limit(2)
        .get();
    if (!providers.docs.length) return {state: "unassigned"};
    if (providers.docs.length !== 1) {
      throw new Error("Stripe connected account is not uniquely assigned.");
    }
    const providerDocument = providers.docs[0];
    const provider = providerDocument.data();
    if (!providerUsesAccountsV2(provider)) {
      await providerDocument.ref.set({
        migrationRequired: true,
        recipientConfigurationReady: false,
        payoutReady: false,
        transferStatus: "legacy_migration_required",
        payoutStatus: "legacy_migration_required",
        onboardingStatus: "migration_required",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {state: "migration_required"};
    }
    requireStripeProviderMode(provider, stripeMode);
    return refreshRecipientStatus({
      providerRef: providerDocument.ref,
      providerData: provider,
      FieldValue,
      secretKey: readStripeSecret(stripeMode),
      expectedMode: stripeMode,
      ...(stripeContext ? {stripeContext} : {}),
      ...(requestRecipientAccount ? {requestFn: requestRecipientAccount} : {}),
    });
  }

  return async (request, response) => {
    const rawBody = request && request.rawBody;
    const signature = request && request.get &&
      request.get("stripe-signature");
    let configuredMode;
    try {
      configuredMode = String(await readStripeMode()).trim().toLowerCase();
    } catch (error) {
      console.error("Stripe Accounts v2 readiness unavailable", {error});
      response.status(500).send("Webhook readiness unavailable");
      return;
    }
    if (!["sandbox", "production"].includes(configuredMode)) {
      response.status(409).send("Stripe webhook processing is disabled");
      return;
    }
    let webhookSecret;
    try {
      webhookSecret = readWebhookSecret(configuredMode);
    } catch (error) {
      console.error("Stripe Accounts v2 webhook secret unavailable", {error});
      response.status(500).send("Webhook credentials unavailable");
      return;
    }
    if (!verifyStripeSignature(rawBody, signature, webhookSecret)) {
      response.status(400).send("Invalid Stripe signature");
      return;
    }
    let event;
    try {
      event = JSON.parse(rawBody.toString("utf8"));
    } catch (_) {
      response.status(400).send("Invalid JSON");
      return;
    }
    const eventId = String(event && event.id || "").trim();
    const eventType = String(event && event.type || "").trim();
    if (!eventId.startsWith("evt_") ||
        event.object !== "v2.core.event" ||
        !accountsV2ThinEventTypes.has(eventType)) {
      response.status(400).send("Invalid Stripe Accounts v2 event");
      return;
    }
    const eventMode = stripeModeFromLivemode(event.livemode);
    if (eventMode !== configuredMode) {
      response.status(409).send("Stripe event environment mismatch");
      return;
    }
    let accountId;
    let stripeContext;
    try {
      accountId = stripeAccountIdFromThinEvent(event);
      stripeContext = stripeContextFromThinEvent(event);
    } catch (_) {
      response.status(400).send("Invalid Stripe Accounts v2 event");
      return;
    }
    let claim;
    try {
      claim = await webhookEventStore.begin({eventId, type: eventType});
    } catch (error) {
      console.error("Stripe Accounts v2 webhook claim failed", {
        eventId,
        eventType,
        error,
      });
      response.status(500).send("Webhook claim failed");
      return;
    }
    if (claim.state === "duplicate") {
      response.status(200).send("Already processed");
      return;
    }
    if (claim.state !== "acquired") {
      response.status(409).send("Webhook processing in progress");
      return;
    }
    try {
      await synchronizeConnectedAccount({
        accountId,
        stripeMode: eventMode,
        stripeContext,
      });
      await webhookEventStore.complete(eventId, claim);
      response.status(200).send("OK");
    } catch (error) {
      console.error("Stripe Accounts v2 webhook processing failed", {
        eventId,
        eventType,
        accountId,
        error,
      });
      await webhookEventStore.fail(eventId, error, claim);
      response.status(500).send("Webhook processing failed");
    }
  };
}

module.exports = {
  STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_PRODUCTION_NAME,
  STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_SANDBOX_NAME,
  createStripeAccountsV2WebhookHandler,
  stripeAccountIdFromThinEvent,
  stripeContextFromThinEvent,
  stripeAccountsV2ProductionWebhookSecret,
  stripeAccountsV2SandboxWebhookSecret,
  stripeAccountsV2WebhookSecretForMode,
  stripeAccountsV2WebhookSecretNames,
};
