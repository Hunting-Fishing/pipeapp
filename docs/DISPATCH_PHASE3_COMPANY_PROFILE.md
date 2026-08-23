# Pipe Buyer Dispatch Phase 3 - Company Profile Foundation

**Master plan:** `docs/DISPATCH_NETWORK_MASTER_PLAN.md`  
**Phase:** 3 of 7  
**Phase 2 browser acceptance:** confirmed by developer 2026-08-17  
**Official overall progress entering Phase 3:** 41%  
**Phase 3 baseline:** 4/15  
**Phase 3 target for this engineering slice:** profile foundation only; do not advance to Phase 4.

---

## Purpose

Phase 3 turns a legacy Dispatch carrier record into a structured industrial company profile that can later feed the searchable Dispatch Directory. The profile must stay simple for field users while collecting normalized service and capability data.

This slice establishes the public company-profile model and editor without weakening the existing `dispatch_carriers` approval, quote, award, route-privacy, or transaction behavior.

## Added in this slice

`lib/marketplace/marketplace_dispatch_company_profile.dart` provides:

- business type codes for owner/operator, sole proprietor, partnership, corporation/company, and other;
- availability codes for available now, today, this week, or unavailable;
- normalized service selection backed by the Phase 2 service taxonomy;
- company/trade identity fields;
- public description and optional website;
- service-area summary compatibility with the existing Dispatch service-area workflow;
- emergency-callout and remote-site capability flags;
- deterministic profile completeness;
- a bounded public projection that deliberately excludes private account data;
- a responsive company-profile editor for desktop/mobile.

## Privacy boundary

The public profile model does not contain:

- private email or phone details;
- authentication identifiers;
- private addresses;
- insurance documents;
- credential documents;
- moderation/admin-only fields.

Credential metadata and private documents remain a separate Phase 3 task and must be protected independently.

## Compatibility boundary

This slice does not delete, migrate, or bypass `dispatch_carriers/{uid}`. Existing provider signup/approval remains authoritative while the normalized company model is built.

The next Phase 3 engineering slice must connect this editor to protected persistence and bridge approved legacy provider data into the normalized profile model before any public Directory projection is enabled.

## Remaining Phase 3 work

- protected company/profile persistence and compatibility bridge;
- equipment/fleet capability profile normalization;
- home-base and full service-area map integration;
- credential/insurance metadata with private document separation;
- connect Company Profile action to the new editor;
- emulator persistence tests and browser acceptance;
- update the master plan only after the corresponding gates are green.

## Acceptance for this slice

Required before continuing inside Phase 3:

- `dart format` stable;
- strict analyzer clean;
- company-profile unit/widget tests green;
- Phase 2 taxonomy regression green;
- Phase 1 navigation regression green;
- no private fields in the public profile projection.
