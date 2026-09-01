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
