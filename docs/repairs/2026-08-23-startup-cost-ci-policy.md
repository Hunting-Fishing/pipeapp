# Repair record — Startup-cost GitHub Actions policy

Date: 2026-08-23
Branch: `chore/startup-cost-ci`

## Root cause

The repository automatically started multiple GitHub Actions workflows for ordinary pull-request updates. A small coding change could trigger overlapping Windows, macOS, Linux, Flutter, Firebase emulator, Android, web, and iOS work.

The account owner confirmed the GitHub Actions budget reached **$100 / $100**, `Stop usage` was enabled, and GitHub reported a failed payment authorization. New jobs then failed before step 1 because hosted Actions usage was blocked at the account level.

The application code was not the cause of the zero-step failures. Repeated automatic workflow execution was the cost/control problem.

## Exact repair

The following workflows are now **manual-only** (`workflow_dispatch`) and no longer start because code was pushed or a pull request changed:

- `.github/workflows/quality.yml`
- `.github/workflows/financial-safety.yml`
- `.github/workflows/callable-safety.yml`
- `.github/workflows/premium-ui-sandbox.yml`
- `.github/workflows/oauth-branding.yml`

### Quality gate

The normal Quality workflow is now Linux-first and manual.

Removed from ordinary Quality execution:

- Windows runner;
- automatic macOS/iOS compile;
- Android debug compile;
- release web compile;
- duplicate Firebase callable emulator execution.

The manual Quality gate retains source analysis, Flutter tests, repository contract tests, and Functions lint/check validation.

### Financial and emulator gates

Financial Safety and Callable Safety remain available as focused explicit manual gates. They do not run on every Firebase/payment edit.

Callable integration artifact retention was reduced from 7 days to 3 days.

### UI and branding gates

Premium UI Sandbox and OAuth Branding remain available but only run when explicitly requested.

### Release/deployment controls

The existing signed mobile release-candidate workflow was already manual and remains manual.

The existing Firebase deployment workflow was already manual and remains manual.

No production deployment or live provider/payment operation is added by this repair.

## Startup operating policy

During normal development:

1. make and review a coherent repair locally/in the connected development environment;
2. use focused tests where available;
3. do not spend hosted CI for each intermediate edit;
4. when a change is genuinely ready for acceptance, explicitly run only the required manual gate(s);
5. run signed Android/iOS release workflows only for an actual release candidate;
6. run production deployment only for an accepted exact commit.

## Cost guardrail

GitHub account budgets are controlled in GitHub Billing, not in repository source. Recommended startup posture is a low hard Actions spending cap with `Stop usage` enabled so an accidental workflow cannot create a large bill.

Do not increase the Actions budget to compensate for noisy automation. Fix trigger scope first.

## Do not repeat

- Do not add `pull_request:` or broad development `push:` triggers to expensive build/emulator/mobile workflows without an explicit cost review.
- Do not put macOS/iOS compilation in a workflow that runs for every code change.
- Do not duplicate the same emulator/build work across several automatically triggered workflows.
- Do not treat zero-step GitHub Actions failures as application test failures when account usage is blocked.
- Do not merge production payment changes solely because CI is unavailable; run the intentional manual acceptance gate after Actions access is restored.
