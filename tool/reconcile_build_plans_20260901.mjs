import fs from 'node:fs';

function replaceOnce(path, before, after, label) {
  let text = fs.readFileSync(path, 'utf8');
  if (text.includes(after)) {
    console.log(`${path}: ${label} already applied`);
    return;
  }
  if (!text.includes(before)) throw new Error(`${path}: missing ${label} anchor`);
  text = text.replace(before, after);
  fs.writeFileSync(path, text);
  console.log(`${path}: applied ${label}`);
}

replaceOnce(
  'docs/PHASE_1_LAUNCH_FINALIZATION_PLAN.md',
  '# Pipe Buyer Phase 1 Launch Finalization Plan\n\n',
  '# Pipe Buyer Phase 1 Launch Finalization Plan\n\n## 2026-09-01 reconciliation\n\nThis file began as the July Phase 1 engineering gate ledger. Its `99% provisional` / `Gate 7 86%` figures below are retained as historical checkpoint data and are **not the current launch-readiness measure**. The current authority is `docs/PIPE_BUYER_LAUNCH_READINESS_AUDIT_2026-08-30.md`, reconciled on 2026-09-01.\n\nCurrent verified state: the protected North American web release is launch-capable for controlled use; Stripe marketplace payments and seller Connect release, Timed Buying, web Dispatch/VIP memberships, OpenStreetMap/geolocation, reporting/moderation, production App Check/release gates, and the upgraded Marketplace home hero have all advanced beyond this July ledger. Native Apple/Google membership/store acceptance, physical-device push/deep links, fresh ordinary-user acceptance journeys, Dispatch production-data acceptance, and any freight-specific transaction charging remain separate launch work.\n\nThe current P1 trust slice is user block/unblock for Marketplace conversations. It is being implemented server-authoritatively so blocked parties cannot exchange new direct messages while existing messages and moderation/report evidence remain stored.\n\n',
  'Phase 1 reconciliation',
);

replaceOnce(
  'docs/PHASE_1_PROGRESS_AUDIT.md',
  '# Phase 1 progress audit\n\n',
  '# Phase 1 progress audit\n\n## 2026-09-01 reconciliation\n\nThis July 30 audit is preserved as a historical engineering checkpoint. Do not use its provisional percentages as current launch status. Current launch authority is `docs/PIPE_BUYER_LAUNCH_READINESS_AUDIT_2026-08-30.md`. Since this checkpoint, production has closed major gaps including protected App Check/release parity, server-authoritative marketplace payment/Connect flows, Timed Buying, web membership upgrades and promotion-code handling, OpenStreetMap/geolocation, substantial Dispatch Directory stabilization, and the brighter responsive Marketplace home hero.\n\nThe controlled North American web surface is now in late P1 acceptance. Native store publication and unrestricted international expansion remain separate readiness tracks.\n\n',
  'Phase 1 progress reconciliation',
);

replaceOnce(
  'docs/PIPEBUYER_ACTIVE_BUILD_HANDOFF.md',
  '**Updated:** 2026-08-20\n\n**Canonical repository:** `D:\\Game Development\\pipeapp`\n\n**Active branch:** `design/formal-beautification-foundation`\n\n**Canonical local app:** `http://127.0.0.1:5050`\n',
  '**Updated:** 2026-09-01\n\n**Canonical repository:** `D:\\Game Development\\pipeapp`\n\n**Production branch:** `main`\n\n**Current production baseline before this P1 slice:** `7c5398dc22ef42844058f17e2ee70882bb72e987`\n\n**Current implementation branch:** `feature/p1-user-blocking-build-plan-20260901`\n\n**Canonical local app:** `http://127.0.0.1:5050`\n\n## Current launch/build position\n\nThe older `design/formal-beautification-foundation` and Phase 4 Hotshot/geography blocker notes below are historical. Open-map/geolocation foundations and later Directory repairs have superseded that blocker. The current launch authority is `docs/PIPE_BUYER_LAUNCH_READINESS_AUDIT_2026-08-30.md`.\n\nControlled North American web launch is in late P1 acceptance. Current autonomous engineering priority: server-authoritative Marketplace user block/unblock, preserving conversation and moderation evidence. Remaining P1 acceptance after that includes ordinary-user buyer/seller/Timed Buying/report-admin/Dispatch journeys, physical mobile push/deep-link validation for native launch, and representative Dispatch provider data/privacy acceptance.\n',
  'active build handoff header',
);

const auditPath = 'docs/PIPE_BUYER_LAUNCH_READINESS_AUDIT_2026-08-30.md';
replaceOnce(auditPath, 'Last reconciled: 2026-08-31', 'Last reconciled: 2026-09-01', 'audit date');
replaceOnce(
  auditPath,
  '- Production source / release pointer: `3790fc600b6d83ac072486b9ca3b6a8e8c311898`\n- Protected Firebase production run: `33325938428`\n- Production deployment job: `99295953757` — **success**\n- Visual acceptance job: `99296786437` — **success**',
  '- Production source / release pointer: `7c5398dc22ef42844058f17e2ee70882bb72e987`\n- Latest protected Marketplace hero production run: `33428641770` — **success**\n- Subscription-card / Firebase Functions production run: `33388062795` — **success**\n- The latest hero release validated the approved desktop/mobile truck image payloads, full Flutter tests, exact production web build, Firebase Hosting deployment, and public production-page smoke checks.\n- The subscription release validated and deployed both configured Firebase Functions codebases before broad `--only functions` deployment.',
  'production baseline',
);
replaceOnce(
  auditPath,
  '| User block / mute | **YELLOW** | No clear current implementation was found by repository search during this audit. | No later repair record was found establishing this as complete. | Add a simple block/mute contract if launch policy requires users to stop direct contact from another account. Ensure it affects messaging/contact visibility without destroying evidence needed by moderation. |',
  '| User block / mute | **GREEN/YELLOW** | The 2026-09-01 P1 slice adds server-authoritative conversation block/unblock state, block/unblock controls in the chat safety menu, and send enforcement in Cloud Functions. Existing conversation history and Trust & Safety evidence are retained. | This closes the earlier “no clear implementation” finding. | Validate the block/unblock journey with two ordinary production-safe accounts after deployment. A separate notification-only mute preference can remain P2 unless user feedback shows it is needed. |',
  'user block readiness row',
);
