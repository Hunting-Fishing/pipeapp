from pathlib import Path

shell_path = Path('lib/marketplace/oil_gas_marketplace.dart')
shell_text = shell_path.read_text(encoding='utf-8')
old = """          const MarketplaceShellDestination(
            pageIndex: 5,
            label: 'Profile',
"""
new = """          const MarketplaceShellDestination(
            pageIndex: 5,
            label: 'Account',
"""
count = shell_text.count(old)
if count != 2:
    raise SystemExit(
        f'account destination prepatch: expected two Profile destinations, found {count}'
    )
shell_path.write_text(shell_text.replace(old, new, 1), encoding='utf-8')

membership_path = Path('lib/marketplace/membership_plan_management.dart')
membership_text = membership_path.read_text(encoding='utf-8')
redundant_import = "import 'package:flutter/foundation.dart';\n"
if membership_text.count(redundant_import) != 1:
    raise SystemExit('membership analyzer repair: expected one foundation import')
membership_path.write_text(
    membership_text.replace(redundant_import, '', 1),
    encoding='utf-8',
)

Path('docs/repairs/RELEASE1_ANALYZER_BASELINE_2026-09-01.md').write_text(
    '''# Release 1 analyzer baseline repair — 2026-09-01

## Symptom

The guarded Release 1 builder reached the repository-wide Flutter analyzer and stopped on an existing `unnecessary_import` finding in `lib/marketplace/membership_plan_management.dart`.

## Root cause

`membership_plan_management.dart` imported both `package:flutter/foundation.dart` and `package:flutter/material.dart`. The symbols used by this file are already exported by Material, so the direct Foundation import was redundant. The canonical production deployment also runs a repository-wide analyzer, so suppressing or narrowing the gate would have deferred the same failure to release time.

## Repair

Remove only the redundant Foundation import. Do not weaken analyzer severity and do not alter membership behavior, Stripe logic, Firebase calls, entitlement state, or UI behavior.

## Verification

Release 1 must pass the unchanged repository-wide analyzer, focused Home/navigation tests, the full Flutter regression suite, and the canonical protected production deployment before this repair is considered closed.

## Do not repeat

When a bounded feature exposes an unrelated pre-existing analyzer blocker that would also fail the canonical deployment, repair the exact lint defect and record it. Do not bypass the full analyzer or expand into speculative refactoring.
''',
    encoding='utf-8',
)

Path('docs/repairs/RELEASE1_FORMATTER_BOUNDARY_2026-09-01.md').write_text(
    '''# Release 1 formatter boundary repair — 2026-09-01

## Symptom

The Release 1 focused tests passed, but the complete Flutter suite failed `marketplace_catalog_photo_integration_test.dart` after the builder formatted the entire `lib/marketplace/oil_gas_marketplace.dart` file.

## Root cause

Release 1 changes only a few navigation and shell lines in the large Marketplace source. Running the current Dart formatter across the entire pre-existing file changed unrelated catalog-photo call formatting. A source-contract test intentionally recognizes the established exact category + product-type call shape for both listing cards and listing details. The broad formatter mutation changed that textual shape even though Release 1 did not change catalog-photo behavior.

## Repair

Do not run whole-file formatting over `oil_gas_marketplace.dart` in this bounded Release 1 mutation. Preserve all unrelated production source byte-for-byte and mutate only the exact guarded anchors. Continue formatting the new/small Release 1 files where doing so cannot rewrite unrelated source.

## Verification

The unchanged full Flutter regression must pass, including `marketplace_catalog_photo_integration_test.dart`, before Release 1 can commit or merge.

## Do not repeat

A formatter is a source mutation. On large legacy/source-of-record files with source-contract tests, do not broaden a small repair into a whole-file formatting rewrite. Keep the formatter boundary aligned with the intended mutation or deliberately update the contract only when product behavior is actually changing.
''',
    encoding='utf-8',
)
