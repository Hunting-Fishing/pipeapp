[CmdletBinding()]
param(
    [string]$ProjectPath = "",

    [ValidateRange(0.25, 24)]
    [double]$Hours = 3,

    [ValidateRange(1, 50)]
    [int]$MaxTasks = 8,

    [ValidateRange(0, 5)]
    [int]$MaxRepairAttempts = 2,

    [switch]$Push,

    [string]$Branch = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-LastExitCode {
    param([string]$Operation)
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation failed with exit code $LASTEXITCODE."
    }
}

function Invoke-Git {
    param([string[]]$GitArgs)
    & git @GitArgs
    Assert-LastExitCode "git $($GitArgs -join ' ')"
}

function Get-WorkingTreeText {
    $lines = @(& git status --porcelain)
    Assert-LastExitCode "git status --porcelain"
    return ($lines -join [Environment]::NewLine).Trim()
}

function Escape-SingleQuotedPowerShell {
    param([string]$Value)
    return $Value.Replace("'", "''")
}

function Stop-ProcessTreeSafe {
    param([System.Diagnostics.Process]$Process)
    if ($null -eq $Process -or $Process.HasExited) { return }

    if ($env:OS -eq "Windows_NT") {
        $taskkill = Get-Command taskkill.exe -ErrorAction SilentlyContinue
        if ($taskkill) {
            & $taskkill.Source /PID $Process.Id /T /F 2>$null | Out-Null
            return
        }
    }

    try { $Process.Kill() } catch { }
}

function Invoke-TimedPowerShell {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptText,
        [Parameter(Mandatory = $true)][int]$TimeoutMinutes,
        [Parameter(Mandatory = $true)][string]$LogPath,
        [int]$NoOutputMinutes = 0
    )

    $shell = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $shell) { $shell = Get-Command powershell.exe -ErrorAction SilentlyContinue }
    if (-not $shell) { throw "PowerShell is required for autonomous execution." }

    $stdoutPath = "$LogPath.stdout"
    $stderrPath = "$LogPath.stderr"
    foreach ($path in @($stdoutPath, $stderrPath, $LogPath)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }

    $bytes = [Text.Encoding]::Unicode.GetBytes($ScriptText)
    $encoded = [Convert]::ToBase64String($bytes)
    $process = Start-Process `
        -FilePath $shell.Source `
        -ArgumentList @("-NoProfile", "-EncodedCommand", $encoded) `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru `
        -NoNewWindow

    $started = Get-Date
    $lastActivity = $started
    $lastLength = 0L
    $timedOut = $false
    $stalled = $false

    while (-not $process.HasExited) {
        Start-Sleep -Seconds 5
        $length = 0L
        foreach ($path in @($stdoutPath, $stderrPath)) {
            if (Test-Path -LiteralPath $path) {
                $length += (Get-Item -LiteralPath $path).Length
            }
        }

        if ($length -ne $lastLength) {
            $lastLength = $length
            $lastActivity = Get-Date
        }

        if (((Get-Date) - $started).TotalMinutes -ge $TimeoutMinutes) {
            $timedOut = $true
            Stop-ProcessTreeSafe -Process $process
            break
        }

        if ($NoOutputMinutes -gt 0 -and ((Get-Date) - $lastActivity).TotalMinutes -ge $NoOutputMinutes) {
            $stalled = $true
            Stop-ProcessTreeSafe -Process $process
            break
        }
    }

    try { $process.WaitForExit() } catch { }

    $combined = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath $stdoutPath) {
        foreach ($line in @(Get-Content -LiteralPath $stdoutPath)) { $combined.Add($line) }
    }
    if (Test-Path -LiteralPath $stderrPath) {
        foreach ($line in @(Get-Content -LiteralPath $stderrPath)) { $combined.Add("[stderr] $line") }
    }
    $combined | Set-Content -LiteralPath $LogPath
    foreach ($line in $combined) { Write-Host $line }

    $exitCode = if ($timedOut -or $stalled) { 124 } else { $process.ExitCode }
    return [pscustomobject]@{
        ExitCode = $exitCode
        TimedOut = $timedOut
        Stalled = $stalled
        LogPath = $LogPath
    }
}

function Invoke-CodexWorker {
    param(
        [string]$Prompt,
        [string]$ProjectRoot,
        [string]$SchemaPath,
        [string]$ResultPath,
        [string]$LogPath,
        [int]$TimeoutMinutes,
        [int]$NoOutputMinutes
    )

    if (Test-Path -LiteralPath $ResultPath) { Remove-Item -LiteralPath $ResultPath -Force }
    $promptPath = "$ResultPath.prompt.md"
    Set-Content -LiteralPath $promptPath -Value $Prompt -Encoding UTF8

    $rootEsc = Escape-SingleQuotedPowerShell $ProjectRoot
    $schemaEsc = Escape-SingleQuotedPowerShell $SchemaPath
    $resultEsc = Escape-SingleQuotedPowerShell $ResultPath
    $promptEsc = Escape-SingleQuotedPowerShell $promptPath

    $script = @"
`$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath '$rootEsc'
`$prompt = Get-Content -LiteralPath '$promptEsc' -Raw
& codex exec --sandbox workspace-write --json --output-schema '$schemaEsc' -o '$resultEsc' `$prompt
exit `$LASTEXITCODE
"@

    return Invoke-TimedPowerShell `
        -ScriptText $script `
        -TimeoutMinutes $TimeoutMinutes `
        -NoOutputMinutes $NoOutputMinutes `
        -LogPath $LogPath
}

function Invoke-ProjectCommand {
    param(
        [string]$ProjectRoot,
        [string]$CommandText,
        [int]$TimeoutMinutes,
        [string]$LogPath
    )

    $rootEsc = Escape-SingleQuotedPowerShell $ProjectRoot
    $commandEsc = Escape-SingleQuotedPowerShell $CommandText
    $script = @"
`$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath '$rootEsc'
try {
    Invoke-Expression '$commandEsc'
    if (`$LASTEXITCODE -and `$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }
    exit 0
}
catch {
    Write-Error (`$_ | Out-String)
    exit 1
}
"@

    return Invoke-TimedPowerShell -ScriptText $script -TimeoutMinutes $TimeoutMinutes -LogPath $LogPath
}

function Read-AgentResult {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Codex did not write the required structured result: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Codex wrote an empty structured result: $Path"
    }
    return $raw | ConvertFrom-Json
}

function Ensure-RunExclusion {
    param([string]$RepoRoot)
    $excludePath = Join-Path $RepoRoot ".git/info/exclude"
    $directory = Split-Path -Parent $excludePath
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $excludePath)) {
        New-Item -ItemType File -Path $excludePath -Force | Out-Null
    }
    $existing = Get-Content -LiteralPath $excludePath -Raw
    if ($existing -notmatch "(?m)^\.agent-run/$") {
        Add-Content -LiteralPath $excludePath -Value ".agent-run/"
    }
}

function Write-State {
    param(
        [string]$Path,
        [hashtable]$State
    )
    $State.updated_at = (Get-Date).ToString("o")
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Assert-ProjectKnowledge {
    param(
        [string]$ProjectRoot,
        [object]$Config
    )

    $paths = New-Object System.Collections.Generic.List[string]
    $paths.Add([string]$Config.agent_policy)
    foreach ($item in @($Config.knowledge.always)) { $paths.Add([string]$item) }
    $paths.Add([string]$Config.knowledge.feature_registry)

    foreach ($relative in $paths | Sort-Object -Unique) {
        $full = Join-Path $ProjectRoot $relative
        if (-not (Test-Path -LiteralPath $full)) {
            throw "Configured project knowledge is missing: $relative"
        }
    }
}

function Select-WriterBranch {
    param(
        [string]$DesiredBranch,
        [string]$BaseBranch,
        [bool]$AllowDirectMain
    )

    if (-not $AllowDirectMain -and $DesiredBranch -in @("main", "master")) {
        throw "Refusing to use $DesiredBranch as an autonomous writer branch."
    }

    $current = (& git branch --show-current).Trim()
    Assert-LastExitCode "git branch --show-current"
    if ([string]::IsNullOrWhiteSpace($current)) {
        throw "Detached HEAD is not supported."
    }

    & git show-ref --verify --quiet "refs/heads/$DesiredBranch"
    $localExists = ($LASTEXITCODE -eq 0)

    if (-not $localExists) {
        & git show-ref --verify --quiet "refs/remotes/origin/$DesiredBranch"
        $remoteExists = ($LASTEXITCODE -eq 0)
        if ($remoteExists) {
            Invoke-Git @("switch", "-c", $DesiredBranch, "--track", "origin/$DesiredBranch")
        }
        else {
            Invoke-Git @("switch", $BaseBranch)
            Invoke-Git @("switch", "-c", $DesiredBranch)
        }
    }
    elseif ($current -ne $DesiredBranch) {
        Invoke-Git @("switch", $DesiredBranch)
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

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is required but was not found on PATH."
}
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    throw "Codex CLI is required but was not found on PATH. Install/authenticate Codex first."
}

$engineRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$schemaPath = Join-Path $engineRoot "automation/agent/result.schema.json"
$taskPromptPath = Join-Path $engineRoot "automation/agent/task_prompt.md"
$guardPathInEngine = Join-Path $engineRoot "tool/autonomous_guard.ps1"
foreach ($required in @($schemaPath, $taskPromptPath)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Autonomous builder engine file is missing: $required"
    }
}

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = (& git rev-parse --show-toplevel).Trim()
    Assert-LastExitCode "git rev-parse --show-toplevel"
}
$projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
Set-Location -LiteralPath $projectRoot

& git rev-parse --is-inside-work-tree 2>$null | Out-Null
Assert-LastExitCode "git rev-parse --is-inside-work-tree"

$configPath = Join-Path $projectRoot ".autobuild/project.json"
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Target project is not configured for Autonomous Builder V2: $configPath"
}
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
Assert-ProjectKnowledge -ProjectRoot $projectRoot -Config $config

$guardPath = Join-Path $projectRoot "tool/autonomous_guard.ps1"
if (-not (Test-Path -LiteralPath $guardPath)) {
    if (Test-Path -LiteralPath $guardPathInEngine) { $guardPath = $guardPathInEngine }
    else { throw "No autonomous quality guard is available for the target project." }
}

$dirty = Get-WorkingTreeText
if (-not [string]::IsNullOrWhiteSpace($dirty)) {
    throw "The target working tree must be clean before autonomous mode starts.`n$dirty"
}

$desiredBranch = if ([string]::IsNullOrWhiteSpace($Branch)) { [string]$config.writer_branch } else { $Branch }
$baseBranch = [string]$config.git.base_branch
$currentBranch = Select-WriterBranch `
    -DesiredBranch $desiredBranch `
    -BaseBranch $baseBranch `
    -AllowDirectMain ([bool]$config.git.allow_direct_main)

$dirtyAfterBranch = Get-WorkingTreeText
if (-not [string]::IsNullOrWhiteSpace($dirtyAfterBranch)) {
    throw "Writer branch synchronization left uncommitted changes; refusing autonomous work.`n$dirtyAfterBranch"
}

Ensure-RunExclusion -RepoRoot $projectRoot
$runDir = Join-Path $projectRoot ".agent-run"
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$statePath = Join-Path $runDir "state.json"

$basePrompt = Get-Content -LiteralPath $taskPromptPath -Raw
$startedAt = Get-Date
$deadline = $startedAt.AddHours($Hours)
$completedTasks = 0
$stopReason = "time budget reached"
$lastNextTask = ""
if (Test-Path -LiteralPath $statePath) {
    try {
        $previousState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        $lastNextTask = [string]$previousState.next_task
    }
    catch { $lastNextTask = "" }
}

$state = @{
    schema_version = 2
    project_id = [string]$config.project_id
    project_name = [string]$config.project_name
    run_id = "$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    started_at = $startedAt.ToString("o")
    updated_at = $startedAt.ToString("o")
    branch = $currentBranch
    base_branch = $baseBranch
    current_iteration = 0
    completed_tasks = 0
    phase = "starting"
    last_task = ""
    next_task = $lastNextTask
    last_verified_commit = (& git rev-parse HEAD).Trim()
    stop_reason = ""
}
Write-State -Path $statePath -State $state

$workerMinutes = [int]$config.timeouts.worker_minutes
$repairMinutes = [int]$config.timeouts.repair_minutes
$verifyMinutes = [int]$config.timeouts.verify_minutes
$noOutputMinutes = [int]$config.timeouts.no_output_minutes
$verifyCommand = [string]$config.verify_command

Write-Host ""
Write-Host "Autonomous Builder V2 started"
Write-Host "  Project    : $($config.project_name)"
Write-Host "  Repository : $projectRoot"
Write-Host "  Branch     : $currentBranch"
Write-Host "  Time budget: $Hours hour(s)"
Write-Host "  Task limit : $MaxTasks"
Write-Host "  Worker cap : $workerMinutes minute(s)"
Write-Host "  Push       : $($Push.IsPresent)"
Write-Host "  Run state  : $statePath"
Write-Host ""

for ($iteration = 1; $iteration -le $MaxTasks; $iteration++) {
    if ((Get-Date) -ge $deadline) { break }

    $remainingMinutes = [Math]::Max(0, [Math]::Floor(($deadline - (Get-Date)).TotalMinutes))
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $resultPath = Join-Path $runDir "result-$iteration-$stamp.json"
    $eventLogPath = Join-Path $runDir "worker-$iteration-$stamp.log"

    $prompt = @"
$basePrompt

## Supervisor context

- Target project: $($config.project_name) (`$($config.project_id)`)
- Project configuration: `.autobuild/project.json`
- Autonomous iteration: $iteration of $MaxTasks
- Reusable writer branch: $currentBranch
- Approximate supervisor time remaining: $remainingMinutes minute(s)
- Previous suggested next task: $lastNextTask
- The outer supervisor will run the autonomous guard and project verification after your focused tests.
- The outer supervisor, not you, creates commits only after both gates pass.
- Runtime logs/state are under `.agent-run/`; do not edit or commit them.
"@

    $state.current_iteration = $iteration
    $state.phase = "worker"
    Write-State -Path $statePath -State $state

    Write-Host "=== Worker $iteration / $MaxTasks ==="
    $worker = Invoke-CodexWorker `
        -Prompt $prompt `
        -ProjectRoot $projectRoot `
        -SchemaPath $schemaPath `
        -ResultPath $resultPath `
        -LogPath $eventLogPath `
        -TimeoutMinutes $workerMinutes `
        -NoOutputMinutes $noOutputMinutes

    if ($worker.ExitCode -ne 0) {
        $stopReason = if ($worker.TimedOut) { "worker timed out after $workerMinutes minutes" } elseif ($worker.Stalled) { "worker produced no output for $noOutputMinutes minutes" } else { "worker exited with code $($worker.ExitCode)" }
        Write-Warning $stopReason
        break
    }

    $result = Read-AgentResult -Path $resultPath
    $state.last_task = [string]$result.task
    $state.next_task = [string]$result.next_task
    $lastNextTask = [string]$result.next_task
    Write-State -Path $statePath -State $state

    Write-Host "Task       : $($result.task)"
    Write-Host "Status     : $($result.status)"
    Write-Host "Source     : $($result.source_doc) :: $($result.source_item)"
    Write-Host "Refactor   : $($result.refactor_mode)"

    $dirty = Get-WorkingTreeText
    if ([string]::IsNullOrWhiteSpace($dirty)) {
        if ($result.status -eq "complete") { $stopReason = "agent reports no safe unfinished code work" }
        elseif ($result.status -eq "blocked" -or $result.requires_human) { $stopReason = "human blocker: $($result.blocker_classification) - $($result.human_reason)" }
        else { $stopReason = "worker returned no workspace changes for a continue iteration" }
        Write-Host $stopReason
        break
    }

    $verified = $false
    $repairAttempt = 0
    $failureLog = ""

    while (-not $verified) {
        $gateStamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $guardLog = Join-Path $runDir "guard-$iteration-attempt-$repairAttempt-$gateStamp.log"
        $verifyLog = Join-Path $runDir "verify-$iteration-attempt-$repairAttempt-$gateStamp.log"

        $state.phase = "autonomous-guard"
        Write-State -Path $statePath -State $state
        Write-Host "Running autonomous quality guard..."
        $guardEsc = Escape-SingleQuotedPowerShell $guardPath
        $rootEsc = Escape-SingleQuotedPowerShell $projectRoot
        $guardCommand = "& '$guardEsc' -ProjectRoot '$rootEsc'"
        $guard = Invoke-ProjectCommand -ProjectRoot $projectRoot -CommandText $guardCommand -TimeoutMinutes 10 -LogPath $guardLog

        if ($guard.ExitCode -eq 0) {
            $state.phase = "full-verification"
            Write-State -Path $statePath -State $state
            Write-Host "Running project verification..."
            $verify = Invoke-ProjectCommand -ProjectRoot $projectRoot -CommandText $verifyCommand -TimeoutMinutes $verifyMinutes -LogPath $verifyLog
            if ($verify.ExitCode -eq 0) {
                $verified = $true
                break
            }
            $failureLog = $verifyLog
        }
        else {
            $failureLog = $guardLog
        }

        if ($repairAttempt -ge $MaxRepairAttempts) { break }
        $repairAttempt++
        $repairStamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $repairResultPath = Join-Path $runDir "repair-result-$iteration-$repairAttempt-$repairStamp.json"
        $repairLog = Join-Path $runDir "repair-$iteration-$repairAttempt-$repairStamp.log"
        $relativeFailureLog = ".agent-run/$([System.IO.Path]::GetFileName($failureLog))"

        $repairPrompt = @"
Read `.autobuild/project.json`, the configured agent policy, and the relevant quality/architecture knowledge. You are repairing only the current increment: `$($result.task)`.

A supervisor gate failed. Inspect `$relativeFailureLog` and the current Git diff. Fix only root causes associated with this increment or a directly exposed defect required for it to pass.

Do not weaken tests, feature-preservation anchors, source-size rules, change budgets, security, or product contracts. If the increment is too large, reduce/split the current work rather than bypassing the gate. Do not commit, branch, push, merge, deploy, or perform live-provider actions.

Return only the structured result required by the engine result schema.
"@

        $state.phase = "repair-$repairAttempt"
        Write-State -Path $statePath -State $state
        Write-Host "Gate failed; starting repair attempt $repairAttempt of $MaxRepairAttempts..."
        $repair = Invoke-CodexWorker `
            -Prompt $repairPrompt `
            -ProjectRoot $projectRoot `
            -SchemaPath $schemaPath `
            -ResultPath $repairResultPath `
            -LogPath $repairLog `
            -TimeoutMinutes $repairMinutes `
            -NoOutputMinutes $noOutputMinutes

        if ($repair.ExitCode -ne 0) {
            $stopReason = "repair worker failed or timed out with code $($repair.ExitCode)"
            break
        }
        $result = Read-AgentResult -Path $repairResultPath
    }

    if (-not $verified) {
        $failurePatch = Join-Path $runDir "failed-iteration-$iteration.patch"
        @(& git diff --binary) | Set-Content -LiteralPath $failurePatch
        Assert-LastExitCode "git diff --binary"
        $stopReason = "quality gates still failing; changes left uncommitted. Patch: $failurePatch"
        Write-Warning $stopReason
        break
    }

    $commitMessage = [string]$result.commit_message
    if ([string]::IsNullOrWhiteSpace($commitMessage)) { $commitMessage = "agent: autonomous increment $iteration" }
    elseif (-not $commitMessage.StartsWith("agent:")) { $commitMessage = "agent: $commitMessage" }

    $state.phase = "commit"
    Write-State -Path $statePath -State $state
    Invoke-Git @("add", "-A")
    Invoke-Git @("commit", "-m", $commitMessage)
    $completedTasks++
    $currentSha = (& git rev-parse HEAD).Trim()
    Assert-LastExitCode "git rev-parse HEAD"

    if ($Push) {
        Invoke-Git @("push", "-u", "origin", $currentBranch)
    }

    $state.completed_tasks = $completedTasks
    $state.last_verified_commit = $currentSha
    $state.next_task = [string]$result.next_task
    $state.phase = "verified"
    Write-State -Path $statePath -State $state
    Write-Host "Verified commit: $currentSha  $commitMessage"
    Write-Host ""

    if ($result.status -eq "complete") {
        $stopReason = "agent reports all currently safe code work complete"
        break
    }
    if ($result.status -eq "blocked" -and $result.requires_human) {
        $stopReason = "human blocker after verified increment: $($result.blocker_classification) - $($result.human_reason)"
        break
    }
}

$finishedAt = Get-Date
$elapsed = $finishedAt - $startedAt
$currentSha = (& git rev-parse HEAD).Trim()
Assert-LastExitCode "git rev-parse HEAD"
if ([string]::IsNullOrWhiteSpace($stopReason)) { $stopReason = "task limit reached" }

$state.phase = "finished"
$state.completed_tasks = $completedTasks
$state.last_verified_commit = $currentSha
$state.stop_reason = $stopReason
Write-State -Path $statePath -State $state

Write-Host ""
Write-Host "Autonomous Builder V2 finished"
Write-Host "  Project         : $($config.project_name)"
Write-Host "  Branch          : $currentBranch"
Write-Host "  HEAD            : $currentSha"
Write-Host "  Verified commits: $completedTasks"
Write-Host "  Elapsed         : $([Math]::Round($elapsed.TotalMinutes, 1)) minute(s)"
Write-Host "  Stop reason     : $stopReason"
Write-Host "  State/logs      : $runDir"
Write-Host ""
Write-Host "Review the reusable writer branch before opening or updating its pull request. Production activation and merge to main remain human controlled."
