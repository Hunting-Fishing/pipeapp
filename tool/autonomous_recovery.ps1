[CmdletBinding()]
param(
    [string]$ProjectRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-NativeSuccess {
    param([string]$Operation)
    if ($LASTEXITCODE -ne 0) { throw "$Operation failed with exit code $LASTEXITCODE." }
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

$status = Get-StatusText
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "Autonomous recovery: worktree is clean; no recovery required."
    return
}

$runDir = Join-Path $ProjectRoot ".agent-run"
$statePath = Join-Path $runDir "state.json"
if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
    throw "Dirty worktree has no autonomous run state. Refusing to assume the changes belong to an interrupted agent run.`n$status"
}

try { $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json }
catch { throw "Autonomous run state is unreadable; refusing recovery: $($_.Exception.Message)" }

$currentBranch = (& git branch --show-current).Trim()
Assert-NativeSuccess "git branch --show-current"
$currentHead = (& git rev-parse HEAD).Trim()
Assert-NativeSuccess "git rev-parse HEAD"
$stateBranch = String($state.branch)
$lastVerified = String($state.last_verified_commit)
$phase = String($state.phase)

if ([string]::IsNullOrWhiteSpace($stateBranch) -or $currentBranch -ne $stateBranch) {
    throw "Dirty worktree branch '$currentBranch' does not match interrupted autonomous state branch '$stateBranch'. Refusing recovery."
}
if ($phase -eq "finished") {
    throw "Dirty worktree exists but the previous autonomous state is marked finished. Treat changes as operator-owned until reviewed."
}
if ([string]::IsNullOrWhiteSpace($lastVerified) -or $currentHead -ne $lastVerified) {
    throw "Current HEAD $currentHead does not equal last verified autonomous commit $lastVerified. Refusing automatic recovery."
}

New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$lockPath = Join-Path $runDir "supervisor.lock"
$lock = $null
try {
    try {
        $lock = [System.IO.File]::Open(
            $lockPath,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
    }
    catch {
        throw "Cannot recover while another autonomous supervisor owns the worktree lock: $lockPath"
    }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $recoveryDir = Join-Path $runDir "recovery-$stamp"
    $quarantineDir = Join-Path $recoveryDir "untracked"
    New-Item -ItemType Directory -Path $quarantineDir -Force | Out-Null

    $status | Set-Content -LiteralPath (Join-Path $recoveryDir "status-before.txt") -Encoding UTF8
    @(& git diff --binary HEAD --) | Set-Content -LiteralPath (Join-Path $recoveryDir "working-tree.patch") -Encoding UTF8
    Assert-NativeSuccess "git diff --binary HEAD"
    @(& git diff --cached --binary HEAD --) | Set-Content -LiteralPath (Join-Path $recoveryDir "staged.patch") -Encoding UTF8
    Assert-NativeSuccess "git diff --cached --binary HEAD"

    $untracked = @(& git ls-files --others --exclude-standard)
    Assert-NativeSuccess "git ls-files --others"
    foreach ($relative in $untracked) {
        if ([string]::IsNullOrWhiteSpace($relative)) { continue }
        $normalized = $relative.Replace("\", "/")
        if ($normalized.StartsWith(".agent-run/")) { continue }
        $source = Join-Path $ProjectRoot $relative
        if (-not (Test-Path -LiteralPath $source)) { continue }
        $destination = Join-Path $quarantineDir $relative
        $parent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Move-Item -LiteralPath $source -Destination $destination -Force
    }

    & git restore --staged --worktree -- .
    Assert-NativeSuccess "git restore interrupted tracked changes"

    $after = Get-StatusText
    if (-not [string]::IsNullOrWhiteSpace($after)) {
        throw "Interrupted-work recovery could not restore a clean worktree. Recovery artifacts were preserved at $recoveryDir.`n$after"
    }

    $record = [ordered]@{
        schema_version = 1
        recovered_at = (Get-Date).ToString("o")
        branch = $currentBranch
        restored_head = $currentHead
        previous_phase = $phase
        previous_task = String($state.last_task)
        previous_next_task = String($state.next_task)
        untracked_quarantined = @($untracked).Count
        recovery_directory = $recoveryDir
    }
    $record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $recoveryDir "recovery.json") -Encoding UTF8

    $state | Add-Member -NotePropertyName recovered_at -NotePropertyValue $record.recovered_at -Force
    $state | Add-Member -NotePropertyName recovery_directory -NotePropertyValue $recoveryDir -Force
    $state.phase = "recovered-interrupted-work"
    $state.stop_reason = "Interrupted unverified work quarantined and worktree restored to last verified commit."
    $state.updated_at = (Get-Date).ToString("o")
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding UTF8

    Write-Host "Autonomous recovery completed safely."
    Write-Host "  Restored HEAD : $currentHead"
    Write-Host "  Quarantine    : $recoveryDir"
    Write-Host "  Untracked     : $(@($untracked).Count) item(s)"
}
finally {
    if ($null -ne $lock) { $lock.Dispose() }
}
