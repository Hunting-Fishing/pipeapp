# Pipe Buyer Push, Test, and Production Release Playbook

## Why this file exists

On 2026-08-17 the Dispatch build reached production, but the path exposed several different classes of failures that looked similar in the terminal. This playbook records the proven sequence so the same problems are not diagnosed repeatedly.

The core rule is simple:

> Separate product defects, test defects, Git/source-state defects, clean-worktree defects, deployment defects, and post-deploy proof defects. Do not repair one layer by randomly changing another.

## Proven production checkpoint

The formal Dispatch branch release at SHA:

```text
dae95c1323d47a1d531840e7e75d62ad96c8408c
```

was deployed to Firebase Hosting and was proven present on both:

```text
https://flutter-flow-pipe.web.app
https://www.pipebuyer.com
```

The live `main.dart.js` bundle on both hosts had the same byte length and contained all of these accepted Dispatch markers:

```text
Set service area on map
Approximate home base:
Fleet capabilities saved.
Dispatch company profile saved.
Sign in to use Dispatch.
```

That proved the new Flutter web bundle was live even though the auxiliary `pipe-release.json` proof failed.

---

# 1. Git and dirty-worktree rules

The main development worktree may contain intentional uncommitted work. Never use destructive Git commands to make a release look clean.

## Do not use

```text
git reset --hard
git stash pop
force push
normal git pull over a dirty worktree
bulk restore of marketplace files
```

## Safe publish pattern

1. `git fetch` the target branch.
2. Create a clean temporary worktree from `origin/<branch>`.
3. Copy or generate only the approved files into that clean worktree.
4. Run formatter/analyzer/tests in the clean worktree.
5. Restore deterministic Flutter-generated plugin files before checking Git status.
6. Allowlist the exact files that may remain changed.
7. Run `git diff --check`.
8. Stage only the allowlisted files.
9. Commit with `[skip ci]` when GitHub Actions are intentionally not needed for that synchronization commit.
10. Push without `--force`.
11. Fetch again and verify the remote branch SHA equals the commit just pushed.
12. Remove the temporary worktree.

This process keeps unrelated local work out of GitHub and prevents an old local parent commit from causing a non-fast-forward release failure.

---

# 2. Clean Flutter worktree dependency bootstrap

## Symptom that occurred

A clean release worktree produced a cascade of analyzer failures such as missing `package:flutter/material.dart` and missing `flutter_lints`.

## Root cause

`.dart_tool/package_config.json` is generated locally and intentionally not stored in Git. A newly-created clean worktree therefore cannot analyze Flutter source until package resolution runs.

## Permanent rule

Before any formatter/analyzer/test/build command in a clean worktree:

```text
hash pubspec.lock
flutter pub get
require .dart_tool/package_config.json
hash pubspec.lock again
STOP if pubspec.lock changed
```

A package update notice is not a failure. A changed lockfile during a release verification is a safety stop and must be reviewed separately.

---

# 3. Flutter generated plugin registrants

## Symptom that occurred

All Dispatch tests passed, but the clean canonicalization gate stopped because files such as this changed:

```text
linux/flutter/generated_plugin_registrant.cc
```

## Root cause

`flutter pub get`, Flutter tests, or Flutter tooling can regenerate tracked platform plugin registrant files even when the product change is web-only.

## Permanent rule

After Flutter dependency/test/build commands and before evaluating Git status, restore only the known deterministic generated plugin files:

```text
linux/flutter/generated_plugin_registrant.cc
linux/flutter/generated_plugin_registrant.h
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugin_registrant.h
windows/flutter/generated_plugins.cmake
```

Then check the worktree again. Any other unexpected tracked file remains a real stop condition.

---

# 4. Canonical product source must be on GitHub

## Symptom that occurred

Local browser acceptance passed, but a clean production worktree failed the Dispatch auth-reactivity regression.

## Root cause

The accepted local `marketplace_dispatch_page.dart` contained the auth-reactive and Company Profile wiring, but the formal GitHub branch still contained an older synchronous auth guard.

A clean production build correctly exposed that source drift.

## Permanent rule

A release is built from GitHub, not from the dirty local worktree. If an accepted local product repair is not canonical on the branch, publish that exact product source first through a clean-worktree verification step.

Tests/support files being on GitHub is not enough; the actual product file must contain the accepted implementation.

---

# 5. Tests must verify behavior, not one exact repair spelling

## Failures that occurred

- long-form widget tests tried to tap controls below the viewport;
- a verifier required one exact source string for an analyzer repair;
- a repair script failed when Dart formatting changed whitespace.

## Permanent rule

Use this hierarchy:

1. strict analyzer/compiler result;
2. behavior/model/widget tests;
3. stable privacy/security contracts;
4. source-shape checks only when they protect an architectural rule.

Do not use fragile exact whitespace or implementation-string checks where analyzer/tests already prove the behavior.

For long `ListView` forms:

- use `ensureVisible` for existing off-screen widgets;
- use `dragUntilVisible` for lazily-built children;
- do not enlarge the test viewport just to hide scrolling behavior.

---

# 6. Production deployment versus production proof

These are separate states.

## A. Deployment did not start

Examples:

- analyzer failed;
- tests failed;
- build failed;
- production variable validation failed.

Result: production Hosting was not changed.

## B. Firebase says `Deploy complete!`

Result: a new Hosting version was released. A later proof failure does not mean the deployment was rolled back.

## C. Post-deploy proof failed

On 2026-08-17 Firebase reported a successful Hosting release, but `/pipe-release.json` returned the Flutter `index.html` fallback instead of JSON on both the Firebase default host and the custom domain.

The exact reason the auxiliary file was not served was not proven, so do not invent a root cause.

What was proven:

- Firebase Hosting release completed;
- both hosts served the same new `main.dart.js` size;
- the live bundle contained the accepted new Dispatch feature strings.

Therefore the product deployment was live and the remaining defect was in the release-proof mechanism.

## Permanent proof rule

Do not redeploy a successful build only because one secondary proof mechanism failed.

For the current web architecture, prove the live release with:

1. Firebase default host returns JavaScript for `main.dart.js`;
2. `www.pipebuyer.com` returns JavaScript for `main.dart.js`;
3. both bundle hashes/lengths match;
4. the bundle contains the compiled `PIPE_RELEASE_SHA` when available;
5. the bundle contains a small set of release-critical feature markers;
6. `/`, `/about`, `/privacy`, and `/terms` return HTTP 200.

The auxiliary JSON marker may remain as a secondary diagnostic, but it must not be the only proof.

---

# 7. GitHub Actions billing control

The manual local release path does not need GitHub Actions.

Use `[skip ci]` only for synchronization commits where skipping push/PR workflows is intentional. Do not treat `[skip ci]` as a way to evade required release checks or service charges.

Production Hosting can be deployed manually from the verified clean worktree with Firebase CLI.

---

# 8. PowerShell rule

All Windows PowerShell 5.1 `.ps1` files in this workflow must remain ASCII-only.

Before handing a new runner to the developer:

```text
tool/assert_windows_powershell_safe.ps1
```

must pass.

Do not place em dashes, curly quotes, typographic bullets, or other non-ASCII punctuation in Windows PowerShell runner source.

---

# 9. Standard Dispatch feature gate sequence

For a new Dispatch slice:

```text
exact current branch
-> clean/approved source
-> formatter
-> formatter stability
-> strict analyzer
-> focused new tests
-> Phase 3 regressions
-> Phase 2 regression
-> Phase 1/auth regression
-> privacy/security source contracts
-> browser persistence acceptance
-> tracker update
-> production release only when requested
```

If a gate fails, fix the first failing layer only. Do not restart the whole repair chain or change unrelated Firebase/Auth/data unless the evidence points there.

---

# 10. Current Dispatch status at creation of this playbook

```text
Overall: 50/100 = 50%
Phase 3: 13/15 verified
Service-area engineering gate: PASS
Service-area code in production bundle: PASS
Service-area production persistence acceptance: still requires an actual save/reopen check
Credential/insurance engineering slice: being built
Phase 4 Directory: BLOCKED
```

Phase 4 remains blocked until Phase 3 is 15/15 and both remaining browser acceptance checks are green.
