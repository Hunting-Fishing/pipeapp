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
    foreach ($item in @($Config.knowledge.always)) { $paths.Add([string]$item) }
    $paths.Add([string]$Config.knowledge.feature_registry)

    foreach ($relative in $paths | Sort-Object -Unique) {
        $full = Join-Path $ProjectRoot $relative
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            throw "Configured project knowledge is missing: $relative"
        }
    }
}

function Update-AutonomousRemoteRefs {
    param(
        [string]$RemoteName,
        [bool]$Required
    )

    if (-not $Required) { return }
    & git remote get-url $RemoteName 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Remote freshness is required but Git remote '$RemoteName' is not configured."
    }

    Write-Host "Refreshing Git remote references from $RemoteName..."
    & git fetch --no-tags $RemoteName
    if ($LASTEXITCODE -ne 0) {
        throw "Remote freshness is required but 'git fetch $RemoteName' failed. No autonomous edits were started."
    }
}

function Resolve-AutonomousBaseRef {
    param(
        [string]$BaseBranch,
        [string]$RemoteName,
        [bool]$RequireRemoteFreshness
    )

    if ($RequireRemoteFreshness) {
        $remoteRef = "refs/remotes/$RemoteName/$BaseBranch"
        & git show-ref --verify --quiet $remoteRef
        if ($LASTEXITCODE -ne 0) {
            throw "Required remote base branch is missing after fetch: $RemoteName/$BaseBranch"
        }
        return "$RemoteName/$BaseBranch"
    }

    & git show-ref --verify --quiet "refs/heads/$BaseBranch"
    if ($LASTEXITCODE -ne 0) {
        throw "Configured local base branch does not exist: $BaseBranch"
    }
    return $BaseBranch
}

function Sync-AutonomousWriterWithRemote {
    param(
        [string]$DesiredBranch,
        [string]$RemoteName,
        [bool]$RequireRemoteFreshness
    )

    if (-not $RequireRemoteFreshness) { return }
    $remoteWriterRef = "refs/remotes/$RemoteName/$DesiredBranch"
    & git show-ref --verify --quiet $remoteWriterRef
    if ($LASTEXITCODE -ne 0) { return }

    $remoteWriter = "$RemoteName/$DesiredBranch"
    & git merge-base --is-ancestor $DesiredBranch $remoteWriter
    $localBehindOrEqual = ($LASTEXITCODE -eq 0)
    & git merge-base --is-ancestor $remoteWriter $DesiredBranch
    $remoteBehindOrEqual = ($LASTEXITCODE -eq 0)

    if ($localBehindOrEqual -and -not $remoteBehindOrEqual) {
        Write-Host "Fast-forwarding local writer branch from $remoteWriter..."
        & git merge --ff-only $remoteWriter
        if ($LASTEXITCODE -ne 0) {
            throw "Could not fast-forward $DesiredBranch from $remoteWriter."
        }
        return
    }
    if ($remoteBehindOrEqual) { return }

    throw "Local and remote writer branches have diverged ($DesiredBranch vs $remoteWriter). Resolve this manually before autonomous work."
}

function Select-AutonomousWriterBranch {
    param(
        [string]$DesiredBranch,
        [string]$BaseBranch,
        [string]$RemoteName,
        [bool]$RequireRemoteFreshness,
        [bool]$AllowDirectMain
    )

    if (-not $AllowDirectMain -and $DesiredBranch -in @("main", "master")) {
        throw "Refusing to use $DesiredBranch as an autonomous writer branch."
    }

    Update-AutonomousRemoteRefs -RemoteName $RemoteName -Required $RequireRemoteFreshness
    $baseRef = Resolve-AutonomousBaseRef `
        -BaseBranch $BaseBranch `
        -RemoteName $RemoteName `
        -RequireRemoteFreshness $RequireRemoteFreshness

    $current = (& git branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($current)) {
        throw "Autonomous development requires a named Git branch; detached HEAD is not supported."
    }

    & git show-ref --verify --quiet "refs/heads/$DesiredBranch"
    $localExists = ($LASTEXITCODE -eq 0)
    $remoteWriterRef = "refs/remotes/$RemoteName/$DesiredBranch"
    & git show-ref --verify --quiet $remoteWriterRef
    $remoteExists = ($LASTEXITCODE -eq 0)

    if (-not $localExists) {
        if ($RequireRemoteFreshness -and $remoteExists) {
            & git switch -c $DesiredBranch --track "$RemoteName/$DesiredBranch"
            if ($LASTEXITCODE -ne 0) {
                throw "Could not create local writer branch from $RemoteName/$DesiredBranch."
            }
        }
        else {
            & git switch -c $DesiredBranch $baseRef
            if ($LASTEXITCODE -ne 0) {
                throw "Could not create writer branch $DesiredBranch from $baseRef."
            }
        }
    }
    elseif ($current -ne $DesiredBranch) {
        & git switch $DesiredBranch
        if ($LASTEXITCODE -ne 0) { throw "Could not switch to writer branch $DesiredBranch." }
    }

    Sync-AutonomousWriterWithRemote `
        -DesiredBranch $DesiredBranch `
        -RemoteName $RemoteName `
        -RequireRemoteFreshness $RequireRemoteFreshness

    & git merge-base --is-ancestor $baseRef $DesiredBranch
    $baseAlreadyIncluded = ($LASTEXITCODE -eq 0)
    if (-not $baseAlreadyIncluded) {
        Write-Host "Synchronizing $baseRef into reusable writer branch $DesiredBranch..."
        & git merge --no-edit $baseRef
        if ($LASTEXITCODE -ne 0) {
            & git merge --abort 2>$null
            throw "Could not synchronize $baseRef into $DesiredBranch without conflicts. Resolve branch synchronization manually."
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
