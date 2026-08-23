[CmdletBinding()]
param([string]$ProjectRoot = "")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-NativeSuccess([string]$Operation) {
    if ($LASTEXITCODE -ne 0) { throw "$Operation failed with exit code $LASTEXITCODE." }
}

function Ensure-RunExclusion([string]$RepoRoot) {
    $excludePath = Join-Path $RepoRoot ".git/info/exclude"
    $directory = Split-Path -Parent $excludePath
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $excludePath)) { New-Item -ItemType File -Path $excludePath -Force | Out-Null }
    $existing = Get-Content -LiteralPath $excludePath -Raw
    if ($existing -notmatch "(?m)^\.agent-run/$") { Add-Content -LiteralPath $excludePath -Value ".agent-run/" }
}

function Get-StatusText {
    $lines = @(& git status --porcelain)
    Assert-NativeSuccess "git status --porcelain"
    return ($lines -join [Environment]::NewLine).Trim()
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (& git rev-parse --show-toplevel).Trim()
    Assert-NativeSuccess "git rev-parse --show-toplevel"
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
Set-Location -LiteralPath $ProjectRoot
Ensure-RunExclusion $ProjectRoot

$status = Get-StatusText
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "Autonomous recovery: worktree is clean; no recovery required."
    return
}

$runDir = Join-Path $ProjectRoot ".agent-run"
$statePath = Join-Path $runDir "state.json"
if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
    throw "Dirty worktree has no autonomous state; changes are treated as operator-owned and were not touched.`n$status"
}
try { $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json }
catch { throw "Autonomous state is unreadable; changes were not touched." }

$currentBranch = (& git branch --show-current).Trim()
Assert-NativeSuccess "git branch --show-current"
$currentHead = (& git rev-parse HEAD).Trim()
Assert-NativeSuccess "git rev-parse HEAD"
$stateBranch = [string]$state.branch
$lastVerified = [string]$state.last_verified_commit
$phase = [string]$state.phase

if ($phase -eq "finished") { throw "Previous autonomous run is marked finished; dirty changes are operator-owned and were not touched." }
if ($currentBranch -ne $stateBranch) { throw "Current branch does not match interrupted autonomous state; changes were not touched." }
if ([string]::IsNullOrWhiteSpace($lastVerified) -or $currentHead -ne $lastVerified) {
    throw "HEAD does not match the last verified autonomous commit; changes were not touched."
}

New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$lockPath = Join-Path $runDir "supervisor.lock"
$lock = $null
try {
    try {
        $lock = [System.IO.File]::Open($lockPath,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
    } catch { throw "Another supervisor owns this worktree; recovery did not touch it." }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $recoveryDir = Join-Path $runDir "recovery-$stamp"
    New-Item -ItemType Directory -Path $recoveryDir -Force | Out-Null
    $status | Set-Content -LiteralPath (Join-Path $recoveryDir "status-before.txt") -Encoding UTF8
    @(& git diff --binary HEAD --) | Set-Content -LiteralPath (Join-Path $recoveryDir "working-tree.patch") -Encoding UTF8
    Assert-NativeSuccess "git diff --binary"
    @(& git diff --cached --binary HEAD --) | Set-Content -LiteralPath (Join-Path $recoveryDir "staged.patch") -Encoding UTF8
    Assert-NativeSuccess "git diff --cached --binary"

    $stashMessage = "autonomous-interrupted-$stamp-$currentHead"
    & git stash push --include-untracked --message $stashMessage | Out-Null
    Assert-NativeSuccess "git stash interrupted autonomous work"

    $after = Get-StatusText
    if (-not [string]::IsNullOrWhiteSpace($after)) {
        throw "Recovery stash completed but worktree is still dirty. Stop and inspect manually.`n$after"
    }
    $stashRef = (& git stash list --format='%gd %s' | Select-Object -First 1).Trim()

    $record = [ordered]@{
        schema_version = 1
        recovered_at = (Get-Date).ToString("o")
        branch = $currentBranch
        restored_head = $currentHead
        previous_phase = $phase
        previous_task = [string]$state.last_task
        previous_next_task = [string]$state.next_task
        stash_message = $stashMessage
        stash_reference = $stashRef
        recovery_directory = $recoveryDir
    }
    $record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $recoveryDir "recovery.json") -Encoding UTF8
    $state.phase = "recovered-interrupted-work"
    $state.stop_reason = "Interrupted unverified work preserved in Git stash; worktree returned to last verified HEAD."
    $state.updated_at = (Get-Date).ToString("o")
    $state | Add-Member -NotePropertyName recovery_stash -NotePropertyValue $stashRef -Force
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding UTF8

    Write-Host "Autonomous recovery preserved interrupted work and restored a clean worktree."
    Write-Host "  HEAD  : $currentHead"
    Write-Host "  Stash : $stashRef"
    Write-Host "  Logs  : $recoveryDir"
}
finally {
    if ($null -ne $lock) { $lock.Dispose() }
}
