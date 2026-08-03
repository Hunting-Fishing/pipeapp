import assert from 'node:assert/strict';

const APP_NAME = 'Pipe Buyer';
const URLS = {
  root: 'https://www.pipebuyer.com/',
  homepage: 'https://www.pipebuyer.com/about',
  privacy: 'https://www.pipebuyer.com/privacy',
  terms: 'https://www.pipebuyer.com/terms',
};

function extract(html, regex, label) {
  const match = html.match(regex);
  assert.ok(match, `Missing ${label}`);
  return match[1].replace(/<[^>]+>/gu, '').replace(/\s+/gu, ' ').trim();
}

async function fetchStatic(url) {
  const response = await fetch(url, {
    redirect: 'manual',
    headers: {
      'user-agent': 'PipeBuyer-Google-Branding-Diagnostic/1.0',
      accept: 'text/html,application/xhtml+xml',
    },
    signal: AbortSignal.timeout(15000),
  });

  assert.equal(
    response.status,
    200,
    `${url} must return HTTP 200 without redirecting; received ${response.status} ${response.headers.get('location') ?? ''}`,
  );
  assert.equal(response.headers.get('location'), null, `${url} must not redirect`);
  assert.match(
    response.headers.get('content-type') ?? '',
    /text\/html/iu,
    `${url} must return HTML`,
  );
  return await response.text();
}

function requireIdentityAndPurpose(html, pageLabel) {
  const title = extract(html, /<title[^>]*>([\s\S]*?)<\/title>/iu, `${pageLabel} title`);
  const h1 = extract(html, /<h1[^>]*>([\s\S]*?)<\/h1>/iu, `${pageLabel} H1`);
  assert.equal(title, APP_NAME, `${pageLabel} title must exactly match the OAuth app name`);
  assert.equal(h1, APP_NAME, `${pageLabel} H1 must exactly match the OAuth app name`);
  assert.match(html, /B2B industrial marketplace/iu, `${pageLabel} must explain the marketplace purpose`);
  assert.match(html, /oil\s*&\s*gas|oil and gas/iu, `${pageLabel} must identify the oil and gas market`);
  assert.match(html, /timed auctions/iu, `${pageLabel} must explain auctions`);
  assert.match(html, /dispatch/iu, `${pageLabel} must explain freight or trucking dispatch`);
}

async function main() {
  console.log('Checking live Pipe Buyer OAuth branding URLs…');

  const [root, homepage, privacy, terms] = await Promise.all([
    fetchStatic(URLS.root),
    fetchStatic(URLS.homepage),
    fetchStatic(URLS.privacy),
    fetchStatic(URLS.terms),
  ]);

  requireIdentityAndPurpose(root, 'Root homepage');
  requireIdentityAndPurpose(homepage, 'OAuth homepage');

  assert.match(homepage, /Google Sign-In/iu, 'OAuth homepage must explain Google Sign-In');
  assert.match(homepage, /email address/iu, 'OAuth homepage must explain requested Google email data');
  assert.match(homepage, /full name/iu, 'OAuth homepage must explain requested Google name data');
  assert.match(homepage, /profile photo/iu, 'OAuth homepage must explain requested Google profile-photo data');
  assert.match(homepage, new RegExp(`href=["']${URLS.privacy}["']`, 'iu'), 'OAuth homepage privacy link must exactly match the consent-screen URL');
  assert.match(homepage, new RegExp(`href=["']${URLS.terms}["']`, 'iu'), 'OAuth homepage terms link must exactly match the consent-screen URL');

  assert.match(privacy, /Privacy Policy for Pipe Buyer/iu, 'Privacy policy must identify Pipe Buyer');
  assert.match(privacy, /What Data We Access/iu, 'Privacy policy must disclose Google data access');
  assert.match(privacy, /Why We Need It/iu, 'Privacy policy must disclose Google data use');
  assert.match(privacy, /How We Store\s*&\s*Share It/iu, 'Privacy policy must disclose Google data storage and sharing');
  assert.match(terms, /Terms of Service for Pipe Buyer/iu, 'Terms must identify Pipe Buyer');

  console.log('PASS: Live website meets the simulated Google OAuth branding checks.');
  for (const [label, url] of Object.entries(URLS)) console.log(`- ${label}: ${url}`);
}

main().catch((error) => {
  console.error('FAIL: Live website does not meet the simulated Google OAuth branding checks.');
  console.error(error?.stack ?? error);
  process.exitCode = 1;
});
