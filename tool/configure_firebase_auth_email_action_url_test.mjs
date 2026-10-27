import assert from 'node:assert/strict';
import test from 'node:test';

import {
  assertLiveHostedAuthActionRoute,
  buildSendEmailConfig,
  defaultActionUrlForProject,
  parseCliArgs,
  validateActionUrl,
} from './configure_firebase_auth_email_action_url.mjs';

test('defaults production project to pipebuyer.com/auth/action in dry-run mode', () => {
  const parsed = parseCliArgs([]);
  assert.equal(parsed.projectId, 'flutter-flow-pipe');
  assert.equal(parsed.actionUrl, 'https://pipebuyer.com/auth/action');
  assert.equal(parsed.apply, false);
  assert.equal(
    defaultActionUrlForProject('pipebuyer-5c77f'),
    'https://pipebuyer-5c77f.web.app/auth/action',
  );
});

test('validateActionUrl rejects firebaseapp.com and unauthorized hosts', () => {
  assert.throws(
    () =>
      validateActionUrl(
        'https://flutter-flow-pipe.firebaseapp.com/__/auth/action',
        ['pipebuyer.com', 'flutter-flow-pipe.firebaseapp.com'],
      ),
    /auth\/action/u,
  );
  assert.throws(
    () =>
      validateActionUrl(
        'https://flutter-flow-pipe.firebaseapp.com/auth/action',
        ['pipebuyer.com', 'flutter-flow-pipe.firebaseapp.com'],
      ),
    /firebaseapp\.com/u,
  );
  assert.throws(
    () =>
      validateActionUrl('https://evil.example.com/auth/action', [
        'pipebuyer.com',
      ]),
    /authorizedDomains/u,
  );
  assert.equal(
    validateActionUrl('https://pipebuyer.com/auth/action', ['pipebuyer.com']),
    'https://pipebuyer.com/auth/action',
  );
});

test('buildSendEmailConfig replaces raw %LINK% text with branded Pipe Buyer CTA buttons', () => {
  const next = buildSendEmailConfig(
    {
      method: 'DEFAULT',
      callbackUri: 'https://flutter-flow-pipe.firebaseapp.com/__/auth/action',
      verifyEmailTemplate: {
        senderLocalPart: 'noreply',
        replyTo: 'noreply',
        body: "<p><a href='%LINK%'>%LINK%</a></p>",
      },
    },
    'https://pipebuyer.com/auth/action',
  );

  assert.equal(next.callbackUri, 'https://pipebuyer.com/auth/action');
  assert.match(next.verifyEmailTemplate.body, /href='%LINK%'/u);
  assert.doesNotMatch(next.verifyEmailTemplate.body, />%LINK%</u);
  assert.match(next.resetPasswordTemplate.body, /href='%LINK%'/u);
  assert.match(next.resetPasswordTemplate.body, /%EMAIL%/u);
  assert.doesNotMatch(next.resetPasswordTemplate.body, />%LINK%</u);
});

test('assertLiveHostedAuthActionRoute blocks apply until deployed web bundle contains marketplace-auth-action', async () => {
  const oldBundleFetch = async (url) => ({
    ok: true,
    status: 200,
    text: async () =>
      url.endsWith('/main.dart.js') ? 'console.log("old bundle");' : '<html></html>',
  });

  await assert.rejects(
    () =>
      assertLiveHostedAuthActionRoute(
        'https://pipebuyer.com/auth/action',
        oldBundleFetch,
      ),
    /marketplace-auth-action/u,
  );

  const deployedBundleFetch = async (url) => ({
    ok: true,
    status: 200,
    text: async () =>
      url.endsWith('/main.dart.js')
        ? 'const route = "marketplace-auth-action";'
        : '<html></html>',
  });

  await assert.doesNotReject(() =>
    assertLiveHostedAuthActionRoute(
      'https://pipebuyer.com/auth/action',
      deployedBundleFetch,
    ),
  );
});
