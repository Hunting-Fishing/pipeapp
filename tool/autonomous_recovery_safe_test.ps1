[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$recovery = Join-Path $PSScriptRoot "autonomous_recovery_safe.ps1"
if (-not (Test-Path -LiteralPath $recovery)) { throw "Safe recovery script missing: $recovery" }

function Invoke-Git([string]$Root, [string[]]$Args) {
    & git -C $Root @Args | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git $($Args -join ' ') failed" }
}

function New-Fixture {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) "pipe-recovery-safe-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    "baseline" | Set-Content -LiteralPath (Join-Path $root "tracked.txt")
    Invoke-Git $root @("init")
    Invoke-Git $root @("config", "user.email", "recovery@example.invalid")
    Invoke-Git $root @("config", "user.name", "Recovery Test")
    Invoke-Git $root @("add", "-A")
    Invoke-Git $root @("commit", "-m", "baseline")
    $head = (& git -C $root rev-parse HEAD).Trim()
    $branch = (& git -C $root branch --show-current).Trim()
    New-Item -ItemType Directory -Path (Join-Path $root ".agent-run") -Force | Out-Null
    return [pscustomobject]@{Root=$root; Head=$head; Branch=$branch}
}

function Write-State([object]$Fixture, [string]$Phase="worker", [string]$Head="") {
    if ([string]::IsNullOrWhiteSpace($Head)) { $Head = $Fixture.Head }
    [ordered]@{
        schema_version=2; project_id="fixture"; project_name="Fixture"; run_id="test";
        branch=$Fixture.Branch; current_iteration=1; completed_tasks=0; phase=$Phase;
        last_task="interrupted task"; next_task="retry task"; last_verified_commit=$Head; stop_reason=""
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Fixture.Root ".agent-run/state.json") -Encoding UTF8
}

function Expect-Failure([scriptblock]$Action, [string]$Name) {
    $failed = $false
    try { & $Action } catch { $failed = $true }
    if (-not $failed) { throw "Expected recovery refusal: $Name" }
    Write-Host "PASS recovery refusal: $Name"
}

$roots = New-Object System.Collections.Generic.List[string]
try {
    $f = New-Fixture; $roots.Add($f.Root); Write-State $f
    "partial tracked edit" | Set-Content -LiteralPath (Join-Path $f.Root "tracked.txt")
    "partial untracked" | Set-Content -LiteralPath (Join-Path $f.Root "new.txt")
    & $recovery -ProjectRoot $f.Root *> $null
    $status = ((& git -C $f.Root status --porcelain) -join "").Trim()
    if ($status) { throw "Safe recovery did not restore a clean worktree: $status" }
    if ((Get-Content -LiteralPath (Join-Path $f.Root "tracked.txt") -Raw).Trim() -ne "baseline") { throw "Tracked baseline not restored by stash." }
    $stash = ((& git -C $f.Root stash list) -join "`n")
    if ($stash -notmatch "autonomous-interrupted-") { throw "Interrupted work stash was not retained." }
    $recoveryDirs = @(Get-ChildItem -LiteralPath (Join-Path $f.Root ".agent-run") -Directory -Filter "recovery-*")
    if ($recoveryDirs.Count -ne 1) { throw "Recovery evidence directory missing." }
    Write-Host "PASS recovery: interrupted changes preserved in stash and clean HEAD restored"

    $f = New-Fixture; $roots.Add($f.Root); Write-State $f -Phase "finished"
    "operator edit" | Set-Content -LiteralPath (Join-Path $f.Root "tracked.txt")
    Expect-Failure { & $recovery -ProjectRoot $f.Root *> $null } "finished-state-dirty-worktree"
    $status = ((& git -C $f.Root status --porcelain) -join "").Trim()
    if (-not $status) { throw "Refused recovery unexpectedly modified operator work." }

    $f = New-Fixture; $roots.Add($f.Root); Write-State $f -Head ("0" * 40)
    "ambiguous edit" | Set-Content -LiteralPath (Join-Path $f.Root "tracked.txt")
    Expect-Failure { & $recovery -ProjectRoot $f.Root *> $null } "head-mismatch"

    $f = New-Fixture; $roots.Add($f.Root)
    "operator edit without state" | Set-Content -LiteralPath (Join-Path $f.Root "tracked.txt")
    Expect-Failure { & $recovery -ProjectRoot $f.Root *> $null } "missing-agent-state"

    Write-Host "Safe autonomous recovery fault suite passed."
}
finally {
    foreach ($root in $roots) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}
