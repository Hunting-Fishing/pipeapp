# Autonomous Builder Project Bootstrap Checklist

Use this before enabling autonomous work on a new repository.

## 1. Repository baseline

- [ ] Default/base branch identified.
- [ ] Working tree clean.
- [ ] Current baseline builds/tests successfully or known failures are documented.
- [ ] Supported languages/framework/toolchain versions recorded.
- [ ] Generated/build/vendor directories identified.
- [ ] Existing oversized source/document files inventoried.

## 2. Product knowledge

- [ ] Product vision written.
- [ ] Major user roles/personas identified.
- [ ] Current active features inventoried.
- [ ] Intended future features/roadmap indexed.
- [ ] Explicit non-goals/disabled features recorded.
- [ ] Durable decisions imported/recorded.
- [ ] Known risks and technical debt recorded.

## 3. Architecture inventory

- [ ] Application/module boundaries documented.
- [ ] Client/server authority documented.
- [ ] State-management/routing conventions documented.
- [ ] Data stores and schema sources identified.
- [ ] Background jobs/functions/workers identified.
- [ ] API/provider integrations identified.
- [ ] Authentication/authorization model documented.
- [ ] Feature flags/safe defaults documented.

## 4. Compatibility inventory

- [ ] Routes/deep links identified.
- [ ] Public/internal APIs or server commands identified.
- [ ] Durable lifecycle states identified.
- [ ] Data fields/versions required by old/current clients identified.
- [ ] Webhook/event identifiers identified.
- [ ] User-role capabilities identified.
- [ ] Critical machine-readable feature anchors created.

## 5. UI/design inventory

- [ ] Canonical theme/tokens identified.
- [ ] Typography, spacing, radii, surfaces, semantic states documented.
- [ ] Shared components identified.
- [ ] Responsive breakpoints/layout policy documented.
- [ ] Accessibility expectations documented.
- [ ] Reference screens/evidence identified where available.

## 6. Testing baseline

- [ ] Static analysis/lint command identified.
- [ ] Unit test command identified.
- [ ] Component/widget/UI test command identified.
- [ ] Backend/server tests identified.
- [ ] Security/Rules/permission tests identified.
- [ ] Integration/emulator tests identified.
- [ ] Build/compile targets identified.
- [ ] Visual/accessibility acceptance identified.
- [ ] Full verify command defined and green.

## 7. Data safety

- [ ] Schema source of truth identified.
- [ ] Migration/backfill policy documented.
- [ ] Backup/restore procedure identified.
- [ ] Production data mutation human-only.
- [ ] Private/public data boundaries documented.
- [ ] Retention/deletion responsibilities identified.

## 8. Security/privacy

- [ ] Secret/config locations inventoried.
- [ ] Forbidden credential paths configured.
- [ ] Secret content patterns configured.
- [ ] Auth/authorization boundaries documented.
- [ ] Admin/privileged operations identified.
- [ ] User/private data categories identified.
- [ ] Logging/diagnostics privacy rules documented.

## 9. Dependencies/providers/cost

- [ ] Runtime/development dependency manifests identified.
- [ ] Provider/API integrations inventoried.
- [ ] Provider secrets/auth ownership identified.
- [ ] Quotas/rate limits identified for critical providers.
- [ ] Paid services and cost drivers identified.
- [ ] Budget/alert ownership identified where applicable.
- [ ] Provider failure/exit behavior documented.

## 10. Release/operations

- [ ] Local/dev/staging/production separation documented.
- [ ] Exact-SHA deployment process documented.
- [ ] Production activation human-only.
- [ ] Rollback process documented.
- [ ] Incident/diagnostics ownership documented.
- [ ] Required remote branch/environment protections identified.

## 11. Autonomous configuration

- [ ] `.autobuild/project.json` created and validated.
- [ ] `.autobuild/risk_policy.json` created and tailored.
- [ ] `AGENTS.md` created.
- [ ] 600-line (or deliberate project-specific) source/document policy configured.
- [ ] Change budget configured.
- [ ] Single reusable writer branch configured.
- [ ] Direct-main editing disabled.
- [ ] Single-writer lock enabled.
- [ ] Independent reviewer enabled.
- [ ] Critical-risk actions human-only.

## 12. Graduation tests

- [ ] Static builder self-test passes.
- [ ] Guard fault-injection suite passes.
- [ ] Full project verification passes before worker changes.
- [ ] Seeded bad change is blocked by independent reviewer.
- [ ] Second concurrent supervisor is rejected.
- [ ] Timeout/stall behavior tested.
- [ ] Interrupted-run recovery tested.
- [ ] Short supervised run produces bounded expected diff.
- [ ] Human owner approves unattended mode.

Do not check an item because a tool claims it exists. Verify from repository/configuration/provider evidence appropriate to the item.