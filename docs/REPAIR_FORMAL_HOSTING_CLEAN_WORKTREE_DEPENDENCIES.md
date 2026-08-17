# Formal Hosting Clean Worktree Dependency Bootstrap Repair

Date: 2026-08-17

## Symptom

`tool/deploy_formal_hosting_only.ps1` created a clean detached Git worktree and correctly entered the Phase 3 service-area release gate, but `dart format` warned that `package:flutter_lints/flutter.yaml` could not be resolved and `dart analyze` then reported `package:flutter/material.dart` as missing followed by cascading undefined Flutter classes.

Production Hosting was not changed because the deployment stopped before the Flutter release build and Firebase Hosting deploy.

## Root cause

A newly created Git worktree contains tracked repository files only. Flutter dependency state under `.dart_tool/`, including `.dart_tool/package_config.json`, is intentionally ignored by Git and therefore does not exist in the new worktree.

The release script ran the Dart/Flutter verification gate before bootstrapping dependencies in that clean worktree. The analyzer errors were environment-resolution failures, not source-code failures in `marketplace_dispatch_company_profile.dart` or the mapped service-area feature.

## Permanent repair

`tool/deploy_formal_hosting_only.ps1` now bootstraps Flutter dependencies inside the clean release worktree before running formatter, analyzer, or tests:

1. hash the tracked `pubspec.lock`;
2. run `flutter pub get` in the clean worktree;
3. require `.dart_tool/package_config.json` to exist;
4. hash `pubspec.lock` again and safety-stop if dependency resolution changed it;
5. only then run the accepted Dispatch Phase 3 service-area gate.

The ignored dependency state may be recreated, but tracked dependency resolution may not drift during a production release.

## Why this is the correct layer

The clean release worktree is created by the hosting deployment script, so environment bootstrap belongs to that release script. The product Dart files and the service-area implementation must not be modified to compensate for a missing package configuration.

## Expected next gate

After dependency bootstrap succeeds, the release must proceed through the real formatter/analyzer/tests, production Flutter web build, Firebase Hosting-only deployment, exact `pipe-release.json` SHA verification, and HTTP checks for the public site. Any later failure should be treated as the specific gate that failed rather than another dependency/bootstrap repair.
