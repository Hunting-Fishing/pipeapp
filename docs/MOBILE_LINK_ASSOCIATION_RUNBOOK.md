# Pipe Buyer mobile link association runbook

Status: source-side Android App Links and iOS Universal Links prepared; Apple
capability/profile and Play signing-certificate confirmation remain external
release gates.

## Approved identities and domains

- Android application ID: `Pipe.Buyerapp`
- Apple application identifier: `4L3S6Y2KGQ.Pipe.Buyerapp`
- Domains: `pipebuyer.com` and `www.pipebuyer.com`

The Android manifest declares separate verified HTTPS filters for both domains
and retains the historical `pipeapp://pipeapp.com` custom scheme. Android and
Apple use the same explicit route policy: home, entity links, public legal and
support pages, services, `/contact-center`, partner, insurance, shop, and the
app-owned `/auth/action` route are associated with the installed app.

There is no catch-all path claim. Firebase Hosting's `/_/` and
`/__/auth/` namespaces and the app's `/admin/*`, `/account/*`, and
`/payments/*` routes remain browser-only. This prevents a Firebase Auth handler
or an internal workflow URL from being delivered to a Flutter route that does
not own it. Any future route addition must update and test both platform
declarations together.

## November 23, 2026 read-only live finding

Both domains currently return HTTP 200 and `application/json` without a redirect
for `/.well-known/assetlinks.json` and
`/.well-known/apple-app-site-association`. The observed files identify the
correct Android package and Apple application ID. The Android file currently
publishes fingerprint
`07:B9:2E:02:75:D5:E2:F3:B3:51:EF:6C:44:C5:A6:74:C3:6B:E6:F4:36:9F:01:E0:13:34:AF:A3:7B:6D:6E:EF`.

That network observation is useful but is **not** Play Console proof. Confirm
that the same value is the Play App Signing certificate, not merely an upload
or historical certificate, before using it in a release build or acceptance
record.

## Fail-closed association generation

Do not check a guessed or upload-key fingerprint into `web/.well-known`.
Google Play signs installed bundles with the **Play App Signing certificate**,
which can differ from the upload certificate used by GitHub Actions.

After the Play Console application exists, open its App signing or Deep links
page and copy the uppercase SHA-256 fingerprint for the **app signing**
certificate. Add that public value as the protected GitHub production
Environment variable `PIPE_ANDROID_APP_SIGNING_SHA256`. Do not populate it from
the network observation above without console confirmation.

The protected production deployment runs the generator after
`flutter build web` and before the release manifest or `firebase deploy`. A
missing or malformed production variable therefore stops the deployment before
anything is published. Staging does not require the production signing value.

For a local candidate, prepare both association documents after
`flutter build web` with:

```powershell
node tool/mobile_link_associations.mjs `
  --android-sha256 "AA:BB:...:FF" `
  --output-dir build/web/.well-known
```

The generator rejects a missing or malformed fingerprint and refuses to write
outside an explicit `.well-known` directory under `build/`. It produces:

- `build/web/.well-known/assetlinks.json`
- `build/web/.well-known/apple-app-site-association`

Firebase Hosting explicitly allows the generated `.well-known` directory,
serves both files as non-cacheable `application/json`, and sets
`appAssociation` to `NONE` so Firebase cannot substitute different dynamic
bytes. Until a production release passes the new gate, the current deployed
configuration continues to serve its existing automatic documents. A future
production deployment must generate the static files first; staging is not an
iOS/Android associated domain and does not require the production certificate.

After Hosting deploys, CI requests both documents from `pipebuyer.com` and
`www.pipebuyer.com` without following redirects. It fails the release unless
all four responses are HTTP 200, have no `Location` header, use
`application/json`, and match the generated files byte-for-byte.

## Apple portal and provisioning prerequisite

The repository declares both approved domains in
`ios/Runner/Runner.entitlements`. The signed-candidate workflow decodes the
selected provisioning profile and fails before `flutter build ipa` unless the
profile contains both values. Source enforcement does not mutate or prove the
Apple Developer portal state.

Before building a signed candidate:

1. Enable **Associated Domains** for App ID `Pipe.Buyerapp` in Apple Developer.
2. Regenerate and install the App Store distribution provisioning profile.
3. Confirm the regenerated profile authorizes this exact checked-in
   entitlement:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:pipebuyer.com</string>
  <string>applinks:www.pipebuyer.com</string>
</array>
```

4. Replace the protected `IOS_PROVISIONING_PROFILE_BASE64` environment secret
   with that regenerated profile through the approved release-operator process.

Until the App ID capability is enabled and the profile is regenerated, the
checked-in entitlement can make local or candidate signing fail. That is the
intended fail-closed behavior; the external capability/profile mutation remains
a deliberate release-operator action.

## Hosted and device acceptance

For each domain, confirm HTTP 200, no redirect, `application/json`, the exact
Apple application identifier, Android package, and console-confirmed SHA-256.
Then test the signed store candidate, not a debug build.

Android examples:

```text
adb shell pm set-app-links --package Pipe.Buyerapp 0 all
adb shell pm verify-app-links --re-verify Pipe.Buyerapp
adb shell pm get-app-links Pipe.Buyerapp
adb shell am start -W -a android.intent.action.VIEW -d https://www.pipebuyer.com/listings/RELEASE_TEST_ID
```

On iOS, install the TestFlight build after the association files and entitlement
are live, then open approved links from Mail or Notes. Reinstall when testing
association changes because Apple and Android cache domain verification.

Record the console certificate page, hosted response headers and bytes, device
commands/results, route outcome, candidate SHA/version/build, tester, and time
in the private Phase 1 acceptance bundle.
