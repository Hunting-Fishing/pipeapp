[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location -LiteralPath $projectRoot

foreach ($commandName in @("git", "codex", "flutter", "node", "npm")) {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
        throw "Autonomous graduation requires '$commandName' on PATH."
    }
}

$fingerprintHelpers = Join-Path $PSScriptRoot "autonomous_fingerprint.ps1"
if (-not (Test-Path -LiteralPath $fingerprintHelpers)) { throw "Fingerprint helper missing: $fingerprintHelpers" }
. $fingerprintHelpers

$configPath = Join-Path $projectRoot ".autobuild/project.json"
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$dirty = (@(& git status --porcelain) -join [Environment]::NewLine).Trim()
if ($LASTEXITCODE -ne 0) { throw "git status failed before graduation." }
if (-not [string]::IsNullOrWhiteSpace($dirty)) {
    throw "Autonomous graduation requires a clean worktree. Commit/stash operator work first.`n$dirty"
}

$runDir = Join-Path $projectRoot ".agent-run"
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$evidencePath = Join-Path $projectRoot ([string]$config.graduation.evidence_path)
$evidenceParent = Split-Path -Parent $evidencePath
if (-not (Test-Path -LiteralPath $evidenceParent)) {
    New-Item -ItemType Directory -Path $evidenceParent -Force | Out-Null
}
if (Test-Path -LiteralPath $evidencePath) { Remove-Item -LiteralPath $evidencePath -Force }

$startedAt = [DateTimeOffset]::Now
$head = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw "git rev-parse HEAD failed." }
$branch = (& git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branch)) { throw "Graduation requires a named Git branch." }

Write-Host ""
Write-Host "Autonomous Builder graduation started"
Write-Host "  Project : $($config.project_name)"
Write-Host "  Branch  : $branch"
Write-Host "  HEAD    : $head"
Write-Host ""

Write-Host "[1/4] Running complete clean-baseline project verification..."
& (Join-Path $PSScriptRoot "verify.ps1")
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Full project verification failed during graduation." }

Write-Host "[2/4] Running real timeout, stall, and lock-contention fault tests..."
& (Join-Path $PSScriptRoot "autonomous_runtime_fault_test.ps1")
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Runtime containment fault suite failed." }

Write-Host "[3/4] Running seeded independent-reviewer regression/security/billing tests..."
& (Join-Path $PSScriptRoot "autonomous_reviewer_fault_test.ps1")
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Independent reviewer fault suite failed." }

Write-Host "[4/4] Rechecking clean repository and recording control fingerprint..."
$dirtyAfter = (@(& git status --porcelain) -join [Environment]::NewLine).Trim()
if ($LASTEXITCODE -ne 0) { throw "git status failed after graduation tests." }
if (-not [string]::IsNullOrWhiteSpace($dirtyAfter)) {
    throw "Graduation tests left tracked/unignored workspace changes; evidence will not be issued.`n$dirtyAfter"
}
$currentHead = (& git rev-parse HEAD).Trim()
if ($currentHead -ne $head) { throw "Repository HEAD changed during graduation ($head -> $currentHead). Evidence will not be issued." }

$fingerprint = Get-AutonomousControlFingerprint -ProjectRoot $projectRoot -Config $config
$codexVersion = Get-AutonomousCodexVersion
$flutterVersion = ((& flutter --version) | Select-Object -First 1).Trim()
$nodeVersion = (& node --version).Trim()
$npmVersion = (& npm --version).Trim()
$finishedAt = [DateTimeOffset]::Now

$evidence = [ordered]@{
    schema_version = 1
    status = "passed"
    project_id = [string]$config.project_id
    project_name = [string]$config.project_name
    branch = $branch
    verified_head = $head
    control_fingerprint = $fingerprint
    codex_version = $codexVersion
    flutter_version = $flutterVersion
    node_version = $nodeVersion
    npm_version = $npmVersion
    graduated_at = $finishedAt.ToString("o")
    elapsed_minutes = [Math]::Round(($finishedAt - $startedAt).TotalMinutes, 1)
    evidence = @(
        "complete tool/verify.ps1 passed",
        "guard and recovery fault suites passed",
        "route/Function compatibility suite passed",
        "real hard-timeout containment passed",
        "real no-output watchdog containment passed",
        "real cross-process lock contention passed",
        "seeded functionality-loss reviewer test blocked",
        "seeded administrator-security reviewer test blocked",
        "seeded Dispatch-billing reviewer test blocked"
    )
    restrictions = @(
        "human review and merge remain required",
        "production activation remains human-only",
        "live provider/money mutations remain human-only",
        "critical-risk autonomous changes remain prohibited"
    )
}
$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding UTF8

# Prove the evidence just issued is accepted by the same fail-closed validator
# used by the autonomous entry point.
Assert-AutonomousGraduationEvidence -ProjectRoot $projectRoot -Config $config

Write-Host ""
Write-Host "Autonomous Builder infrastructure graduation PASSED."
Write-Host "  Fingerprint : $fingerprint"
Write-Host "  Evidence    : $evidencePath"
Write-Host "  Elapsed     : $($evidence.elapsed_minutes) minute(s)"
Write-Host ""
Write-Host "Next: run one watched bounded worker before unattended multi-hour execution."
