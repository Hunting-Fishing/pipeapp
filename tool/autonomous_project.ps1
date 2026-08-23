Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-AutonomousRiskRank {
    param([string]$Risk)
    switch ($Risk.ToLowerInvariant()) {
        "low" { return 1 }
        "medium" { return 2 }
        "high" { return 3 }
        "critical" { return 4 }
        default { throw "Unknown risk level: $Risk" }
    }
}

function Assert-AutonomousProjectKnowledge {
    param(
        [string]$ProjectRoot,
        [object]$Config
    )

    $paths = New-Object System.Collections.Generic.List[string]
    $paths.Add([string]$Config.agent_policy)
    $paths.Add([string]$Config.risk_policy)
    foreach ($item in @($Config.knowledge.always)) {
        $paths.Add([string]$item)
    }
    $paths.Add([string]$Config.knowledge.feature_registry)

    foreach ($relative in $paths | Sort-Object -Unique) {
        $full = Join-Path $ProjectRoot $relative
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            throw "Configured project knowledge is missing: $relative"
        }
    }
}

function Select-AutonomousWriterBranch {
    param(
        [string]$DesiredBranch,
        [string]$BaseBranch,
        [bool]$AllowDirectMain
    )

    if (-not $AllowDirectMain -and $DesiredBranch -in @("main", "master")) {
        throw "Refusing to use $DesiredBranch as an autonomous writer branch."
    }

    $current = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($current)) {
        throw "Autonomous development requires a named Git branch; detached HEAD is not supported."
    }

    & git show-ref --verify --quiet "refs/heads/$DesiredBranch"
    $localExists = ($LASTEXITCODE -eq 0)

    if (-not $localExists) {
        & git show-ref --verify --quiet "refs/remotes/origin/$DesiredBranch"
        $remoteExists = ($LASTEXITCODE -eq 0)
        if ($remoteExists) {
            & git switch -c $DesiredBranch --track "origin/$DesiredBranch"
            if ($LASTEXITCODE -ne 0) { throw "Could not create local writer branch from origin/$DesiredBranch." }
        }
        else {
            & git switch $BaseBranch
            if ($LASTEXITCODE -ne 0) { throw "Could not switch to base branch $BaseBranch." }
            & git switch -c $DesiredBranch
            if ($LASTEXITCODE -ne 0) { throw "Could not create writer branch $DesiredBranch from $BaseBranch." }
        }
    }
    elseif ($current -ne $DesiredBranch) {
        & git switch $DesiredBranch
        if ($LASTEXITCODE -ne 0) { throw "Could not switch to writer branch $DesiredBranch." }
    }

    & git merge-base --is-ancestor $BaseBranch $DesiredBranch
    $baseAlreadyIncluded = ($LASTEXITCODE -eq 0)
    if (-not $baseAlreadyIncluded) {
        Write-Host "Synchronizing $BaseBranch into reusable writer branch $DesiredBranch..."
        & git merge --no-edit $BaseBranch
        if ($LASTEXITCODE -ne 0) {
            & git merge --abort 2>$null
            throw "Could not synchronize $BaseBranch into $DesiredBranch without conflicts. Resolve branch synchronization manually."
        }
    }

    return $DesiredBranch
}

function Enter-AutonomousSingleWriterLock {
    param(
        [string]$RunDirectory,
        [string]$ProjectRoot,
        [string]$CurrentBranch,
        [bool]$Required
    )

    if (-not $Required) { return $null }

    $lockPath = Join-Path $RunDirectory "supervisor.lock"
    try {
        $stream = [System.IO.File]::Open(
            $lockPath,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
        $stream.SetLength(0)
        $lockText = "pid=$PID`nproject=$ProjectRoot`nbranch=$CurrentBranch`nstarted=$(Get-Date -Format o)`n"
        $lockBytes = [Text.Encoding]::UTF8.GetBytes($lockText)
        $stream.Write($lockBytes, 0, $lockBytes.Length)
        $stream.Flush()
        return $stream
    }
    catch {
        throw "Another autonomous supervisor appears to own this worktree. Single-writer lock could not be acquired: $lockPath"
    }
}
