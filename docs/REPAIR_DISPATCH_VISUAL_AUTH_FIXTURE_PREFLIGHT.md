# Dispatch Visual Sandbox Auth Fixture Preflight Repair

**Date:** 2026-08-17

## Symptom

The formal visual client opened normally and the Firebase emulator suite was listening, but `carrier.visual@pipebuyer.test` with the documented `PipeBuyerDemo!2026` password returned the application's incorrect-email-or-password message.

## Root cause

The formal visual launcher previously checked only that Auth, Firestore, Functions, and Storage emulator ports were listening. A listening Auth emulator does not prove that the deterministic visual users are currently loaded. Firebase emulator state is ephemeral unless it is imported/persisted, and the base sandbox start command does not use `--import` or `--export-on-exit`.

This allowed a healthy but freshly restarted or stale Auth emulator to reach Flutter without the `visual-carrier` fixture. The displayed credentials were correct; the local fixture state was not.

This is a local acceptance-environment defect, not a production authentication, Dispatch profile, Phase 3 persistence, password, or Firebase Functions defect.

## Permanent repair

`tool/launch_formal_visual_client.ps1` now performs an Auth-emulator sign-in preflight for the approved carrier fixture before Flutter starts.

- If the fixture authenticates, the launcher proceeds without changing test data.
- If the fixture is missing or stale, the launcher runs `tool/reseed_formal_test_data.ps1` once.
- The launcher then authenticates the carrier fixture again.
- If authentication still fails after reseeding, Flutter is not started and the operator is told to inspect the Auth emulator instead of repeatedly changing app code or passwords.

This preserves profile-persistence browser testing: a normal cold Flutter restart does not reseed when the existing carrier fixture is healthy, so saved emulator data is not reset merely because Flutter is relaunched.

## Permanent rule

Do not diagnose the documented visual-test credentials as an application password bug until the launcher Auth fixture preflight has failed after one deterministic reseed. Port availability alone is not sufficient evidence that the Auth fixture exists.
