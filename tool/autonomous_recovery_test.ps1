[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$recovery = Join-Path $PSScriptRoot "autonomous_recovery.ps1"
if (-not (Test-Path -LiteralPath $recovery)) { throw "Recovery script missing: $recovery" }

function Invoke-Git {
    param([string]$Root, [string[]]$Args)
    & git -C $Root @Args | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git $($Args -join ' ') failed" }
}

function New-Fixture {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) "pipe-autobuild-recovery-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    "baseline" | Set-Content -LiteralPath (Join-Path $root "tracked.txt")
    Invoke-Git -Root $root -Args @("init")
    Invoke-Git -Root $root -Args @("config", "user.email", "recovery@example.invalid")
    Invoke-Git -Root $root -Args @("config", "user.name", "Recovery Test")
    Invoke-Git -Root $root -Args @("add", "-A")
    Invoke-Git -Root $root -Args @("commit", "-m", "baseline")
    $head = (& git -C $root rev-parse HEAD).Trim()
    $branch = (& git -C $root branch --show-current).Trim()
    New-Item -ItemType Directory -Path (Join-Path $root ".agent-run") -Force | Out-Null
    return [pscustomobject]@{ Root = $root; Head = $head; Branch = $branch }
}

function Write-State {
    param([object]$Fixture, [string]$Phase = "worker", [string]$Head = "")
    if ([string]::IsNullOrWhiteSpace($Head)) { $Head = $Fixture.Head }
    [ordered]@{
        schema_version = 2
        project_id = "fixture"
        project_name = "Fixture"
        run_id = "test"
        branch = $Fixture.Branch
        current_iteration = 1
        completed_tasks = 0
        phase = $Phase
        last_task = "interrupted task"
        next_task = "retry interrupted task"
        last_verified_commit = $Head
        stop_reason = ""
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Fixture.Root ".agent-run/state.json") -Encoding UTF8
}

function Expect-Failure {
    param([scriptblock]$Action, [string]$Name)
    $failed = $false
    try { & $Action } catch { $failed = $true }
    if (-not $failed) { throw "Expected recovery test to fail: $Name" }
    Write-Host "PASS recovery refusal: $Name"
}

$fixtures = New-Object System.Collections.Generic.List[string]
try {
    $fixture = New-Fixture
    $fixtures.Add($fixture.Root)
    Write-State -Fixture $fixture
    "partial tracked edit" | Set-Content -LiteralPath (Join-Path $fixture.Root "tracked.txt")
    New-Item -ItemType Directory -Path (Join-Path $fixture.Root "new") -Force | Out-Null
    "partial untracked" | Set-Content -LiteralPath (Join-Path $fixture.Root "new/untracked.txt")
    & $recovery -ProjectRoot $fixture.Root *> $null
    $status = (& git -C $fixture.Root status --porcelain) -join ""
    if (-not [string]::IsNullOrWhiteSpace($status)) { throw "Recovery fixture was not restored clean: $status" }
    $tracked = Get-Content -LiteralPath (Join-Path $fixture.Root "tracked.txt") -Raw
    if ($tracked.Trim() -ne "baseline") { throw "Tracked baseline was not restored." }
    $recoveryDirs = @(Get-ChildItem -LiteralPath (Join-Path $fixture.Root ".agent-run") -Directory -Filter "recovery-*")
    if ($recoveryDirs.Count -ne 1) { throw "Expected exactly one recovery artifact directory." }
    if (-not (Test-Path -LiteralPath (Join-Path $recoveryDirs[0].FullName "untracked/new/untracked.txt"))) {
        throw "Untracked file was not quarantined."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $recoveryDirs[0].FullName "working-tree.patch"))) {
        throw "Working-tree patch evidence missing."
    }
    Write-Host "PASS recovery: interrupted changes quarantined and last verified HEAD restored"

    $fixture = New-Fixture
    $fixtures.Add($fixture.Root)
    Write-State -Fixture $fixture -Phase "finished"
    "operator edit" | Set-Content -LiteralPath (Join-Path $fixture.Root "tracked.txt")
    Expect-Failure -Name "finished-state-dirty-worktree" -Action { & $recovery -ProjectRoot $fixture.Root *> $null }

    $fixture = New-Fixture
    $fixtures.Add($fixture.Root)
    Write-State -Fixture $fixture -Head ("0" * 40)
    "ambiguous edit" | Set-Content -LiteralPath (Join-Path $fixture.Root "tracked.txt")
    Expect-Failure -Name "head-does-not-match-last-verified" -Action { & $recovery -ProjectRoot $fixture.Root *> $null }

    $fixture = New-Fixture
    $fixtures.Add($fixture.Root)
    "operator edit without state" | Set-Content -LiteralPath (Join-Path $fixture.Root "tracked.txt")
    Expect-Failure -Name "dirty-worktree-without-agent-state" -Action { & $recovery -ProjectRoot $fixture.Root *> $null }

    Write-Host "Autonomous recovery fault suite passed."
}
finally {
    foreach ($root in $fixtures) {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}
