from pathlib import Path

ONBOARDING = Path('lib/marketplace/marketplace_dispatch_onboarding.dart')
TEST = Path('test/marketplace_dispatch_onboarding_test.dart')

onboarding = ONBOARDING.read_text(encoding='utf-8')
replacements = {
    "title: r'$10 per awarded job',": "title: r'$10 per dispatched job',",
    "subtitle: 'Platform Dispatch fee',": "subtitle: 'Paid to Pipebuddy',",
    "Pricing is displayed for pilot planning only. Billing and fee collection are not active in this release. No charge is collected until payment and fee features receive separate approval, final terms are published, and the user explicitly accepts them.": "The $10 Dispatch fee is paid to Pipebuddy for each dispatched job. Pricing is displayed for pilot planning only. Billing and fee collection are not active in this release. No charge is collected until payment and fee features receive separate approval, final terms are published, and the user explicitly accepts them.",
}
for old, new in replacements.items():
    count = onboarding.count(old)
    if count != 1:
        raise SystemExit(f'Expected exactly one onboarding occurrence of {old!r}, found {count}')
    onboarding = onboarding.replace(old, new)
ONBOARDING.write_text(onboarding, encoding='utf-8')

test = TEST.read_text(encoding='utf-8')
old = "expect(find.text(r'$10 per awarded job'), findsOneWidget);"
new = "expect(find.text(r'$10 per dispatched job'), findsOneWidget);\n    expect(find.text('Paid to Pipebuddy'), findsOneWidget);\n    expect(\n      find.textContaining('paid to Pipebuddy for each dispatched job'),\n      findsOneWidget,\n    );"
count = test.count(old)
if count != 1:
    raise SystemExit(f'Expected exactly one test occurrence, found {count}')
test = test.replace(old, new)
TEST.write_text(test, encoding='utf-8')
