#!/usr/bin/env node

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import {pathToFileURL} from 'node:url';

export const DEFAULT_PRODUCTION_PROJECT = 'flutter-flow-pipe';
export const DEFAULT_PRODUCTION_ACTION_URL = 'https://pipebuyer.com/auth/action';

export function defaultActionUrlForProject(projectId) {
  if (projectId === DEFAULT_PRODUCTION_PROJECT) {
    return DEFAULT_PRODUCTION_ACTION_URL;
  }
  return `https://${projectId}.web.app/auth/action`;
}

export function validateActionUrl(rawUrl, authorizedDomains = []) {
  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch {
    throw new Error(`Invalid --action-url "${rawUrl}". Expected a full HTTPS URL.`);
  }
  const isLocal = parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1';
  if (parsed.protocol !== 'https:' && !(isLocal && parsed.protocol === 'http:')) {
    throw new Error(`Action URL must use https:// (got "${parsed.protocol}").`);
  }
  if (parsed.pathname !== '/auth/action') {
    throw new Error(
      `Action URL path must be "/auth/action" so GoRouter dispatches MarketplaceAuthActionPage (got "${parsed.pathname}").`,
    );
  }
  if (parsed.hostname.endsWith('.firebaseapp.com')) {
    throw new Error(
      `Action URL host "${parsed.hostname}" still points at firebaseapp.com instead of the Pipe Buyer app domain.`,
    );
  }
  if (
    Array.isArray(authorizedDomains) &&
    authorizedDomains.length > 0 &&
    !authorizedDomains.includes(parsed.hostname)
  ) {
    throw new Error(
      `Action URL host "${parsed.hostname}" is not in Firebase Auth authorizedDomains: ${authorizedDomains.join(', ')}`,
    );
  }
  return parsed.toString();
}

export function buildVerifyEmailHtml() {
  return [
    "<div style='font-family:Inter,Segoe UI,Arial,sans-serif;max-width:560px;margin:0 auto;padding:24px;color:#0f172a;'>",
    "<p style='font-size:12px;font-weight:800;letter-spacing:1.2px;color:#ea580c;margin:0 0 8px 0;'>PIPE BUYER</p>",
    "<h2 style='font-size:22px;font-weight:800;margin:0 0 12px 0;color:#0f172a;'>Confirm your email address</h2>",
    "<p style='font-size:15px;line-height:1.55;margin:0 0 20px 0;color:#334155;'>Hello %DISPLAY_NAME%,</p>",
    "<p style='font-size:15px;line-height:1.55;margin:0 0 22px 0;color:#334155;'>Click the button below to confirm your email address and return straight to Pipe Buyer.</p>",
    "<p style='margin:0 0 24px 0;'><a href='%LINK%' style='display:inline-block;background-color:#ea580c;color:#ffffff;font-weight:700;font-size:15px;text-decoration:none;padding:12px 22px;border-radius:10px;'>Verify Email &amp; Open Pipe Buyer</a></p>",
    "<p style='font-size:13px;line-height:1.5;margin:0 0 8px 0;color:#64748b;'>If you did not create a %APP_NAME% account, you can safely ignore this email.</p>",
    "<p style='font-size:13px;line-height:1.5;margin:0;color:#64748b;'>Pipe Buyer Marketplace</p>",
    '</div>',
  ].join('\n');
}

export function buildResetPasswordHtml() {
  return [
    "<div style='font-family:Inter,Segoe UI,Arial,sans-serif;max-width:560px;margin:0 auto;padding:24px;color:#0f172a;'>",
    "<p style='font-size:12px;font-weight:800;letter-spacing:1.2px;color:#ea580c;margin:0 0 8px 0;'>PIPE BUYER</p>",
    "<h2 style='font-size:22px;font-weight:800;margin:0 0 12px 0;color:#0f172a;'>Reset your Pipe Buyer password</h2>",
    "<p style='font-size:15px;line-height:1.55;margin:0 0 22px 0;color:#334155;'>Use the button below to choose a new password for <strong>%EMAIL%</strong> on %APP_NAME%.</p>",
    "<p style='margin:0 0 24px 0;'><a href='%LINK%' style='display:inline-block;background-color:#0f52ba;color:#ffffff;font-weight:700;font-size:15px;text-decoration:none;padding:12px 22px;border-radius:10px;'>Reset Password</a></p>",
    "<p style='font-size:13px;line-height:1.5;margin:0 0 8px 0;color:#64748b;'>If you did not request a password reset, you can safely ignore this email.</p>",
    "<p style='font-size:13px;line-height:1.5;margin:0;color:#64748b;'>Pipe Buyer Marketplace</p>",
    '</div>',
  ].join('\n');
}

export function buildSendEmailConfig(existingSendEmail = {}, actionUrl) {
  const verifyExisting = existingSendEmail.verifyEmailTemplate ?? {};
  const resetExisting = existingSendEmail.resetPasswordTemplate ?? {};

  return {
    ...existingSendEmail,
    callbackUri: actionUrl,
    verifyEmailTemplate: {
      ...verifyExisting,
      senderLocalPart: verifyExisting.senderLocalPart || 'noreply',
      replyTo: verifyExisting.replyTo || 'noreply',
      subject: 'Confirm your email for %APP_NAME%',
      body: buildVerifyEmailHtml(),
      bodyFormat: 'HTML',
    },
    resetPasswordTemplate: {
      ...resetExisting,
      senderLocalPart: resetExisting.senderLocalPart || 'noreply',
      replyTo: resetExisting.replyTo || 'noreply',
      subject: 'Reset your password for %APP_NAME%',
      body: buildResetPasswordHtml(),
      bodyFormat: 'HTML',
    },
  };
}

export function parseCliArgs(argv) {
  let projectId = DEFAULT_PRODUCTION_PROJECT;
  let actionUrl = null;
  let apply = false;
  let skipLiveBundleCheck = false;

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--project') {
      projectId = argv[++i] ?? '';
    } else if (arg === '--action-url') {
      actionUrl = argv[++i] ?? '';
    } else if (arg === '--apply') {
      apply = true;
    } else if (arg === '--dry-run') {
      apply = false;
    } else if (arg === '--skip-live-bundle-check') {
      skipLiveBundleCheck = true;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!projectId.trim()) {
    throw new Error('--project must not be empty.');
  }

  return {
    projectId: projectId.trim(),
    actionUrl: (actionUrl && actionUrl.trim()) || defaultActionUrlForProject(projectId.trim()),
    apply,
    skipLiveBundleCheck,
  };
}

function resolveAccessToken() {
  if (process.env.GOOGLE_OAUTH_ACCESS_TOKEN?.trim()) {
    return process.env.GOOGLE_OAUTH_ACCESS_TOKEN.trim();
  }
  const configPath = path.join(
    os.homedir(),
    '.config',
    'configstore',
    'firebase-tools.json',
  );
  if (!fs.existsSync(configPath)) {
    throw new Error(
      `No GOOGLE_OAUTH_ACCESS_TOKEN set and Firebase CLI config not found at ${configPath}. Run "firebase login" first.`,
    );
  }
  const parsed = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const accessToken = parsed?.tokens?.access_token;
  if (!accessToken || typeof accessToken !== 'string') {
    throw new Error(
      'Firebase CLI access_token is missing. Run "firebase projects:list" or "firebase login --reauth" to refresh it.',
    );
  }
  return accessToken;
}

export async function assertLiveHostedAuthActionRoute(actionUrl, fetchImpl = fetch) {
  const parsed = new URL(actionUrl);
  const bundleUrl = new URL('/main.dart.js', parsed.origin).toString();
  const pageRes = await fetchImpl(actionUrl);
  if (!pageRes.ok) {
    throw new Error(
      `Refusing to switch Firebase Auth callbackUri: ${actionUrl} returned HTTP ${pageRes.status}. Deploy Hosting first.`,
    );
  }
  const bundleRes = await fetchImpl(bundleUrl);
  if (!bundleRes.ok) {
    throw new Error(
      `Refusing to switch Firebase Auth callbackUri: ${bundleUrl} returned HTTP ${bundleRes.status}.`,
    );
  }
  const bundleSource = await bundleRes.text();
  if (!bundleSource.includes('marketplace-auth-action')) {
    throw new Error(
      `Refusing to switch Firebase Auth callbackUri: ${bundleUrl} does not yet include the "marketplace-auth-action" route. Deploy the updated web bundle to ${parsed.origin} BEFORE running with --apply.`,
    );
  }
}

async function runCli(argv) {
  const options = parseCliArgs(argv);
  const accessToken = resolveAccessToken();
  const headers = {
    Authorization: `Bearer ${accessToken}`,
    'x-goog-user-project': options.projectId,
  };
  const configEndpoint = `https://identitytoolkit.googleapis.com/admin/v2/projects/${encodeURIComponent(options.projectId)}/config`;
  const getRes = await fetch(configEndpoint, {headers});
  if (!getRes.ok) {
    const body = await getRes.text();
    throw new Error(
      `Failed to read Identity Toolkit config for ${options.projectId} (HTTP ${getRes.status}): ${body}`,
    );
  }
  const currentConfig = await getRes.json();
  const validatedActionUrl = validateActionUrl(
    options.actionUrl,
    currentConfig.authorizedDomains ?? [],
  );
  const existingSendEmail = currentConfig.notification?.sendEmail ?? {};
  const nextSendEmail = buildSendEmailConfig(existingSendEmail, validatedActionUrl);

  const summary = {
    mode: options.apply ? 'apply' : 'dry-run',
    projectId: options.projectId,
    previousCallbackUri: existingSendEmail.callbackUri ?? null,
    nextCallbackUri: nextSendEmail.callbackUri,
    verifyEmailSubject: nextSendEmail.verifyEmailTemplate.subject,
    resetPasswordSubject: nextSendEmail.resetPasswordTemplate.subject,
  };

  if (!options.apply) {
    process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
    return;
  }

  if (!options.skipLiveBundleCheck) {
    await assertLiveHostedAuthActionRoute(validatedActionUrl);
  }

  const patchUrl = `${configEndpoint}?updateMask=notification.sendEmail`;
  const patchRes = await fetch(patchUrl, {
    method: 'PATCH',
    headers: {
      ...headers,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      notification: {
        sendEmail: nextSendEmail,
      },
    }),
  });
  if (!patchRes.ok) {
    const body = await patchRes.text();
    throw new Error(
      `Failed to update Identity Toolkit sendEmail config (HTTP ${patchRes.status}): ${body}`,
    );
  }
  const updatedConfig = await patchRes.json();
  process.stdout.write(
    `${JSON.stringify(
      {
        ...summary,
        appliedCallbackUri: updatedConfig?.notification?.sendEmail?.callbackUri ?? null,
      },
      null,
      2,
    )}\n`,
  );
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runCli(process.argv.slice(2)).catch((error) => {
    console.error(`configure_firebase_auth_email_action_url: ${error.message}`);
    process.exitCode = 1;
  });
}
