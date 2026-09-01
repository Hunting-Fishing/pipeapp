from pathlib import Path

PRODUCTION_SHA = '996bd3f782a89639aaf12527193cb1ecf4d92f84'
RUN_ID = '33493435243'
RUN_NUMBER = '56'
FIREBASE_ARTIFACT = 'firebase-release-evidence-production-996bd3f782a89639aaf12527193cb1ecf4d92f84-33493435243'
FIREBASE_ARTIFACT_ID = '9794901956'
VISUAL_ARTIFACT = 'visual-acceptance-production-33493435243'
VISUAL_ARTIFACT_ID = '9794932834'

plan = Path('docs/PIPEBUYER_ACTIVE_PRODUCT_BUILD_PLAN_2026-09-01.md')
text = plan.read_text(encoding='utf-8')
anchor = '### Release 1 — Simple Pipe Buyer flow\n\n'
insert = (
    '### Release 1 — Simple Pipe Buyer flow\n\n'
    f'**Production status: COMPLETE.** PR #168 is deployed from exact application SHA `{PRODUCTION_SHA}` by protected production run `{RUN_ID}` (#{RUN_NUMBER}) with App Check `enforce`. The run passed analyzer/tests, release-manifest and Function-parity controls, both Functions codebases, Firestore rules, authenticated callable workflows/retries, exact web build, Firebase deployment, post-deploy parity, release identity, and production mobile/desktop visual acceptance. Evidence: `{FIREBASE_ARTIFACT}` (artifact `{FIREBASE_ARTIFACT_ID}`) and `{VISUAL_ARTIFACT}` (artifact `{VISUAL_ARTIFACT_ID}`).\n\n'
)
if text.count(anchor) != 1:
    raise SystemExit('build plan: Release 1 anchor mismatch')
text = text.replace(anchor, insert, 1)
plan.write_text(text, encoding='utf-8')

handoff = Path('docs/PIPEBUYER_ACTIVE_BUILD_HANDOFF.md')
text = handoff.read_text(encoding='utf-8')
anchor = '# Pipe Buyer Active Build Handoff\n\n'
insert = (
    '# Pipe Buyer Active Build Handoff\n\n'
    '## 2026-09-01 Release 1 simple-flow production release\n\n'
    f'Release 1 is **complete in production** at application SHA `{PRODUCTION_SHA}`, merged through PR #168 and deployed by protected Firebase run `{RUN_ID}` (#{RUN_NUMBER}) with App Check `enforce`. The release simplifies the ordinary-user entry flow to Browse inventory, Sell something, Request service, and Post wanted / RFQ; compact navigation uses Home, Browse, Sell, Messages, and Account while existing server-authoritative Firebase, Stripe, Trust & Safety, and release controls remain unchanged.\n\n'
    f'Production evidence: `{FIREBASE_ARTIFACT}` (artifact `{FIREBASE_ARTIFACT_ID}`) and `{VISUAL_ARTIFACT}` (artifact `{VISUAL_ARTIFACT_ID}`). Production passed full Flutter analysis/tests, release-manifest controls, deployed Function parity controls, both Functions codebases, Firestore security rules, authenticated callable workflows/retries, exact web build, Firebase deploy, post-deploy parity, release identity, and responsive mobile/desktop visual acceptance.\n\n'
    'Permanent Release 1 repair boundaries: keep the repository-wide analyzer strict and fix exact lint blockers rather than bypassing it; do not run broad formatter churn over the large Marketplace source for a tiny bounded edit because source-contract tests protect existing catalog-photo integration.\n\n'
)
if text.count(anchor) != 1:
    raise SystemExit('handoff: title anchor mismatch')
text = text.replace(anchor, insert, 1)
old = '**Current deployed production baseline:** `0dd8f9c4ab69868b4b8fc8e6cb2c05dbf1ca80de` (verified run `33464230471`)'
new = f'**Current deployed production baseline:** `{PRODUCTION_SHA}` (verified run `{RUN_ID}` #{RUN_NUMBER})'
if text.count(old) != 1:
    raise SystemExit('handoff: production baseline anchor mismatch')
text = text.replace(old, new, 1)
handoff.write_text(text, encoding='utf-8')

audit = Path('docs/PIPE_BUYER_LAUNCH_READINESS_AUDIT_2026-08-30.md')
text = audit.read_text(encoding='utf-8')
anchor = '# Pipe Buyer launch readiness audit — 2026-08-30\n\n'
insert = (
    '# Pipe Buyer launch readiness audit — 2026-08-30\n\n'
    '## 2026-09-01 Release 1 simple-flow production release\n\n'
    f'The current verified production application is `main` at `{PRODUCTION_SHA}`, deployed by `Deploy verified Firebase release` run `{RUN_ID}` (#{RUN_NUMBER}) with App Check `enforce`. Release 1 simplifies Home and compact navigation while preserving existing Firebase schemas, Stripe settlement, moderation evidence, Trust & Safety controls, and protected release architecture.\n\n'
    f'The production run passed full Flutter analysis/tests, generated release-manifest controls, Function-parity tests, both Functions codebase validation, Firestore security rules, authenticated callable workflows/retries, exact web build, notification-worker verification, Firebase deployment, post-deploy Function parity, release identity, and responsive production visual acceptance. Retained evidence: `{FIREBASE_ARTIFACT}` (artifact `{FIREBASE_ARTIFACT_ID}`) and `{VISUAL_ARTIFACT}` (artifact `{VISUAL_ARTIFACT_ID}`).\n\n'
    'Release 2 now owns ordinary-user Marketplace journey closure: buyer/seller offers and counteroffers, Timed Buying, Wanted, messaging/block/report, payment/support, and Dispatch handoff. The engineering rule is to expose current status, next action, and responsible party without making the client authoritative for transaction or payment state.\n\n'
)
if text.count(anchor) != 1:
    raise SystemExit('audit: title anchor mismatch')
text = text.replace(anchor, insert, 1)
old_pointer = '- Production source / release pointer: `0dd8f9c4ab69868b4b8fc8e6cb2c05dbf1ca80de`'
new_pointer = f'- Production source / release pointer: `{PRODUCTION_SHA}`'
if text.count(old_pointer) != 1:
    raise SystemExit('audit: production pointer anchor mismatch')
text = text.replace(old_pointer, new_pointer, 1)
old_run = '- Latest protected Firebase production run: `33464230471` (#55) — **success**, App Check `enforce`'
new_run = f'- Latest protected Firebase production run: `{RUN_ID}` (#{RUN_NUMBER}) — **success**, App Check `enforce`'
if text.count(old_run) != 1:
    raise SystemExit('audit: production run anchor mismatch')
text = text.replace(old_run, new_run, 1)
audit.write_text(text, encoding='utf-8')
