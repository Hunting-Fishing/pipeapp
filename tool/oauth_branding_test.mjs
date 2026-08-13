import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(path, 'utf8');

function requireExactAppIdentity(html, pageName) {
  assert.match(
    html,
    /<title>\s*Pipe Buyer\s*<\/title>/u,
    `${pageName} must use the exact OAuth app name in the document title`,
  );
  assert.match(
    html,
    /<h1[^>]*>\s*Pipe Buyer\s*<\/h1>/u,
    `${pageName} must visibly identify the application as Pipe Buyer`,
  );
}

test('root homepage visibly identifies Pipe Buyer and explains its purpose before Flutter loads', () => {
  const index = read('web/index.html');
  requireExactAppIdentity(index, 'web/index.html');
  assert.match(index, /Application Purpose & Identity:/u);
  assert.match(index, /B2B industrial marketplace/u);
  assert.match(index, /timed auctions/u);
  assert.match(index, /freight trucking dispatch/u);
  assert.match(index, /href="https:\/\/www\.pipebuyer\.com\/privacy"/u);
  assert.match(index, /href="https:\/\/www\.pipebuyer\.com\/terms"/u);
  assert.match(index, /<meta property="og:title" content="Pipe Buyer">/u);
  assert.match(index, /"name": "Pipe Buyer"/u);
});

test('static OAuth homepage uses exact branding, explains Google Sign-In, and uses canonical clean URLs', () => {
  const about = read('web/about.html');
  requireExactAppIdentity(about, 'web/about.html');
  assert.match(about, /Application purpose and functionality/u);
  assert.match(about, /B2B industrial marketplace serving the United States and Canada/u);
  assert.match(about, /Google Sign-In and Google user data/u);
  assert.match(about, /Google email address, full name, and profile photo/u);
  assert.match(about, /rel="canonical" href="https:\/\/www\.pipebuyer\.com\/about"/u);
  assert.match(about, /href="https:\/\/www\.pipebuyer\.com\/privacy"/u);
  assert.match(about, /href="https:\/\/www\.pipebuyer\.com\/terms"/u);
  assert.doesNotMatch(about, /pipebuyer\.com\/(?:about|privacy|terms)\.html/u);
});

test('application metadata uses the exact Pipe Buyer name', () => {
  const manifest = JSON.parse(read('web/manifest.json'));
  assert.equal(manifest.name, 'Pipe Buyer');
  assert.equal(manifest.short_name, 'Pipe Buyer');

  const main = read('lib/main.dart');
  assert.match(main, /title:\s*'Pipe Buyer'/u);

  const firebase = JSON.parse(read('firebase.json'));
  assert.equal(firebase.hosting.cleanUrls, true);
  assert.equal(firebase.hosting.trailingSlash, false);
});

test('native Google Sign-In callback and active marketplace entry point are configured', () => {
  const googleServiceInfo = read('ios/Runner/GoogleService-Info.plist');
  const reversedClientId = googleServiceInfo.match(
    /<key>REVERSED_CLIENT_ID<\/key>\s*<string>([^<]+)<\/string>/u,
  )?.[1];
  assert.ok(reversedClientId, 'GoogleService-Info.plist must declare REVERSED_CLIENT_ID');

  const iosInfo = read('ios/Runner/Info.plist');
  assert.match(
    iosInfo,
    new RegExp(`<string>${reversedClientId.replaceAll('.', '\\.')}</string>`, 'u'),
    'Info.plist must register the Google callback URL scheme',
  );

  const authPage = read('lib/marketplace/marketplace_auth_page.dart');
  assert.match(authPage, /Continue with Google/u);
  assert.match(authPage, /googleSignInFunc\(\)/u);
});

test('native Google Sign-In uses the initialized 7.x API and preserves cancellation', () => {
  const googleAuth = read('lib/auth/firebase_auth/google_auth.dart');

  assert.match(googleAuth, /GoogleSignIn\.instance/u);
  assert.match(googleAuth, /_googleSignIn\.initialize\(\)/u);
  assert.match(googleAuth, /_googleSignIn\.authenticate\(/u);
  assert.match(googleAuth, /GoogleSignInExceptionCode\.canceled/u);
  assert.match(googleAuth, /GoogleAuthProvider\.credential\(idToken:\s*idToken\)/u);
  assert.doesNotMatch(googleAuth, /GoogleSignIn\(scopes:/u);
  assert.doesNotMatch(googleAuth, /_googleSignIn\.signIn\(\)/u);
});

test('sitemap publishes the exact non-redirecting branding and legal URLs', () => {
  const sitemap = read('web/sitemap.xml');
  for (const url of [
    'https://www.pipebuyer.com/',
    'https://www.pipebuyer.com/about',
    'https://www.pipebuyer.com/privacy',
    'https://www.pipebuyer.com/terms',
  ]) {
    assert.match(sitemap, new RegExp(`<loc>${url.replaceAll('.', '\\.')}</loc>`, 'u'));
  }
  assert.doesNotMatch(sitemap, /\.html<\/loc>/u);
});
