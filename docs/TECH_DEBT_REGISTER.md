# Pipe Buyer Technical Debt Register

Status: active register

Technical debt is tracked so autonomous development can reduce known problems without turning every feature task into an uncontrolled rewrite.

## Rules

- Debt does not automatically outrank product-critical work.
- A feature task may include a small prerequisite cleanup when necessary for safe implementation.
- Broad cleanup is a separate bounded task.
- Existing oversized files may shrink incrementally; they may not grow while above the configured ceiling.
- Do not replace stable architecture merely because a different framework/pattern is fashionable.
- Close debt only with repository evidence, not because code was moved elsewhere.

## Active debt

| ID | Area | Problem | Priority | Safe direction | Status |
| --- | --- | --- | --- | --- | --- |
| TD-001 | Source organization | Legacy/large files may exceed the new 600-line ordinary-source ceiling | HIGH | Characterization tests then responsibility-based extraction; no growth while oversized | ACTIVE |
| TD-002 | Autonomous builder | V2 engine is currently staged inside the Pipe Buyer repository | HIGH | Calibrate, then extract engine into dedicated `366-autonomous-builder` repo; keep thin project adapter here | ACTIVE |
| TD-003 | Autonomous builder | Independent reviewer gate not yet proven in a real calibration run | HIGH | Add read-only reviewer schema/prompt/gate and test blocking behavior | ACTIVE |
| TD-004 | Autonomous builder | Parallel-writer exclusion must be enforced at process level | HIGH | Exclusive supervisor lock per worktree | ACTIVE |
| TD-005 | Compatibility inventory | Machine feature anchors intentionally cover only critical subset | MEDIUM | Expand anchors/tests when high-risk surfaces are changed; do not try to regex the entire app at once | ACTIVE |
| TD-006 | CI | Current GitHub Actions runs are failing/terminating without usable step evidence | HIGH | Independently classify account/workflow issue; local full verification remains mandatory; restore remote required checks before production merge | ACTIVE |
| TD-007 | Release acceptance | Some environment/device/provider gates remain externally unverified | HIGH | Keep code preparation separate from human acceptance evidence | ACTIVE |
| TD-008 | Documentation | Historical runbooks/trackers can become large or overlapping | MEDIUM | Knowledge index + domain ownership; split files before they become retrieval-heavy; supersede rather than duplicate | ACTIVE |
| TD-009 | Payments | Remaining provider, tax, subscription, refund/dispute, and reconciliation acceptance gaps | HIGH | Follow `PAYMENTS_EXECUTION_TRACKER.md`; no shortcut from UI/code to completion | ACTIVE |
| TD-010 | Phase 2 | Multiple Marketplace/Dispatch/analytics workstreams remain provisional | MEDIUM | Continue bounded tracker-driven increments with end-to-end acceptance | ACTIVE |

## Debt creation rule

When an increment knowingly adds a workaround, duplication, compatibility shim, temporary adapter, dormant provider path, or deferred cleanup, record it here or in the authoritative domain tracker with:

- reason;
- impact;
- removal/exit condition;
- priority.

## Debt removal rule

A debt item can be closed when the repository demonstrates that the underlying problem is removed and relevant tests/verification pass. If the resolution changes architecture or product behavior, record the corresponding decision as well.