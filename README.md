# Pipe Buyer

Pipe Buyer is a Flutter marketplace for industrial listings, timed auctions,
wanted ads, offers, messaging, reporting, and professional dispatch services.

## Production baseline

The production web release uses Firebase App Check enforcement, exact-release
manifest and Function parity controls, retained mobile/desktop visual evidence,
and published Google OAuth branding. Android and Apple store publication remain
separate release activities.

The current product-improvement work is tracked in the
[Phase 1.1 Experience Upgrade](docs/PHASE_1_1_EXPERIENCE_UPGRADE.md).

## Development

The supported local SDK is Flutter 3.44.6 stable. Restore dependencies and run
the complete quality gate from PowerShell:

```powershell
.\tool\verify.ps1
```

## Architecture and delivery controls

- [Phase 1.1 Experience Upgrade](docs/PHASE_1_1_EXPERIENCE_UPGRADE.md)
- [North America Property and Rights Roadmap](docs/NORTH_AMERICA_PROPERTY_RIGHTS_ROADMAP.md)
- [Phase 2 Progress Audit](docs/PHASE_2_PROGRESS_AUDIT.md)
- [Firebase App Check rollout](docs/APP_CHECK_ROLLOUT.md)
- [Local Firebase emulator workflow](docs/LOCAL_FIREBASE_EMULATORS.md)
- [Engineering Control Baseline](docs/ENGINEERING_CONTROL_BASELINE.md)
- [Firestore Schema](firebase/FIRESTORE_SCHEMA.md)

The Canada, United States, and Mexico property policies are design-only.
Property publishing remains disabled until the responsible eXp entity,
jurisdictional brokerage licence, supervising compliance owner, approved forms,
legal review, and server-controlled workflow are present.
