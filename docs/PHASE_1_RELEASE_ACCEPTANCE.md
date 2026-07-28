# Phase 1 release acceptance evidence

Phase 1 cannot be declared ready from source code or a successful build alone.
The final decision must be tied to one full Git commit SHA and retain evidence
for every acceptance journey, recovery rehearsal, defect review, and owner
approval.

## Evidence bundle

Create a private working directory outside source control, for example
`build/acceptance`. Store screenshots, test logs, device records, rollback
output, and restore output beneath that directory. Do not include passwords,
authentication codes, private identity documents, raw access tokens, or
customer data.

After generating the exact staging or production release manifest, prepare a
release-bound evidence workspace instead of copying the template by hand:

```powershell
node tool/prepare_phase1_acceptance.mjs `
  --release-manifest build/release-manifest.json `
  --version-name 1.0.0 `
  --build-number 1 `
  --output-root build/acceptance
```

When the approved public HTTPS origin is known, add
`--public-base-url https://YOUR_APPROVED_HOST` to prefill the support, privacy,
terms, and account-deletion paths. The preparer rejects local, example, and
non-HTTPS origins. It binds every candidate and device record to the manifest
SHA, creates the journey, recovery, store, privacy, device, defect, and signoff
evidence directories, and leaves every result pending. It refuses to overwrite
an existing bundle so a later run cannot silently erase collected evidence.

Every evidence path must be relative to `build/acceptance`; parent-directory
paths are rejected by the final validator.

The acceptance JSON and `build/release-manifest.json` must name the same:

- `staging` or `production` environment;
- full 40-character Git commit SHA; and
- tested release artifact.

## Required acceptance

The schema-version-2 bundle covers the ten product journeys plus explicit
mobile release evidence. Account ownership and profile media, listing
lifecycle, saved-state recovery, communications and moderation, offers,
auctions, Dispatch, failure/retry behavior, administrator security, and
deployment recovery all remain mandatory.

### Signed release candidates

Run the protected `Build signed mobile release candidates` workflow only after
the exact release SHA has passed Quality and is contained in `main`. The
workflow fails closed without the environment-specific Firebase values,
Android upload key, Apple distribution certificate, exact provisioning
profile, and manual export options. Its retained signature metadata still says
`storeValidated: false`; change the acceptance record to passed only after the
exact artifact succeeds in the appropriate store console.

Copy the exact Android AAB and exported Apple IPA into the private evidence
directory. Each record must name the current `Pipe.Buyerapp` identifier, exact
release SHA, semantic version, positive store build number, and retained
signature/store-validation output. A debug APK, unsigned archive, simulator
build, or declaration without the actual artifact cannot pass.

### Store and privacy review

Google Play and Apple App Store records each require a named reviewer,
timestamp, at least four retained screenshots, console-review evidence, and
public HTTPS support, privacy, terms, and account-deletion URLs. Placeholder,
localhost, example, and HTTP URLs fail closed.

Retain separate evidence for Google Play Data safety, Apple App Privacy, and a
reviewed inventory of every linked SDK. Repository privacy declarations are a
starting point; they do not substitute for these release-specific reviews.

### Physical-device and browser matrix

Every target below must be tied to the exact release SHA, a named tester,
device/OS details, an assistive technology, an execution timestamp, and at
least one retained evidence file:

- compact/current Android phones and an Android tablet using the signed AAB;
- compact/current iPhones and an iPad using the exported signed IPA;
- mobile/desktop Chromium and mobile/desktop Safari release sessions.

Every Android/iOS run must pass install/upgrade/launch, account/profile/avatar,
listing camera/gallery, messaging attachments, Offer/Auction/Dispatch,
permission denial, offline/slow retry, expired-session recovery, TalkBack or
VoiceOver, 200-percent text/orientation, and deep-link/notification scenarios.
Every web run must pass the corresponding account, media, messaging, commerce,
network/session, assistive-technology, keyboard-only, responsive large-text,
and deep-link/notification scenarios. The canonical identifiers are exported
from `tool/phase1_acceptance.mjs`; copy them into each `scenarios` array with a
`passed` status only after execution.

Recovery evidence must include measured Hosting rollback, Functions/Rules
rollback, and Firestore backup restore results. A release remains blocked while
any P0, critical, or high defect is not closed.

Named approvals are required from product, engineering, security, Trust &
Safety, support, privacy, and legal owners. Use organizational role names or
approved business identities in retained release evidence; do not put private
contact details in the repository.

## Validation

After the exact release build and its release manifest exist, run:

```powershell
node tool/phase1_acceptance.mjs `
  --release-manifest build/release-manifest.json `
  --evidence build/acceptance/phase1-acceptance.json `
  --evidence-root build/acceptance `
  --output build/acceptance/phase1-readiness.json
```

The command exits non-zero for missing, stale, incomplete, unsafe, or
mismatched evidence. A successful result includes SHA-256 hashes and sizes for
each retained artifact so the approval record can be audited later.

The resulting readiness JSON is release evidence, not a replacement for the
original screenshots, logs, restore records, approvals, or protected GitHub
Environment review.
