[CmdletBinding()]
param(
    [string]$ProjectPath = "",
    [ValidateRange(0.25, 24)][double]$Hours = 3,
    [ValidateRange(1, 50)][int]$MaxTasks = 8,
    [ValidateRange(0, 5)][int]$MaxRepairAttempts = 2,
    [switch]$Push,
    [string]$Branch = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$processHelpers = Join-Path $PSScriptRoot "autonomous_process.ps1"
$projectHelpers = Join-Path $PSScriptRoot "autonomous_project.ps1"
foreach ($helper in @($processHelpers, $projectHelpers)) {
    if (-not (Test-Path -LiteralPath $helper)) { throw "Autonomous helper file is missing: $helper" }
    . $helper
}

function Assert-LastExitCode {
    param([string]$Operation)
    if ($LASTEXITCODE -ne 0) { throw "$Operation failed with exit code $LASTEXITCODE." }
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

function Read-AgentResult {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Codex did not write the required structured result: $Path" }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "Codex wrote an empty structured result: $Path" }
    return $raw | ConvertFrom-Json
}

function Ensure-RunExclusion {
    param([string]$RepoRoot)
    $excludePath = Join-Path $RepoRoot ".git/info/exclude"
    $directory = Split-Path -Parent $excludePath
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $excludePath)) { New-Item -ItemType File -Path $excludePath -Force | Out-Null }
    $existing = Get-Content -LiteralPath $excludePath -Raw
    if ($existing -notmatch "(?m)^\.agent-run/$") { Add-Content -LiteralPath $excludePath -Value ".agent-run/" }
}

function Write-State {
    param([string]$Path, [hashtable]$State)
    $State.updated_at = (Get-Date).ToString("o")
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git is required but was not found on PATH." }
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) { throw "Codex CLI is required but was not found on PATH. Install/authenticate Codex first." }

$engineRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$schemaPath = Join-Path $engineRoot "automation/agent/result.schema.json"
$taskPromptPath = Join-Path $engineRoot "automation/agent/task_prompt.md"
$reviewSchemaPath = Join-Path $engineRoot "automation/agent/review.schema.json"
$reviewPromptPath = Join-Path $engineRoot "automation/agent/review_prompt.md"
$guardPathInEngine = Join-Path $engineRoot "tool/autonomous_guard.ps1"
foreach ($required in @($schemaPath, $taskPromptPath, $reviewSchemaPath, $reviewPromptPath)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Autonomous builder engine file is missing: $required" }
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
if (-not (Test-Path -LiteralPath $configPath)) { throw "Target project is not configured for Autonomous Builder V2: $configPath" }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
Assert-AutonomousProjectKnowledge -ProjectRoot $projectRoot -Config $config

$guardPath = Join-Path $projectRoot "tool/autonomous_guard.ps1"
if (-not (Test-Path -LiteralPath $guardPath)) {
    if (Test-Path -LiteralPath $guardPathInEngine) { $guardPath = $guardPathInEngine }
    else { throw "No autonomous quality guard is available for the target project." }
}

$dirty = Get-WorkingTreeText
if (-not [string]::IsNullOrWhiteSpace($dirty)) { throw "The target working tree must be clean before autonomous mode starts.`n$dirty" }

$desiredBranch = if ([string]::IsNullOrWhiteSpace($Branch)) { [string]$config.writer_branch } else { $Branch }
$baseBranch = [string]$config.git.base_branch
$remoteName = [string]$config.git.remote_name
$requireRemoteFreshness = [bool]$config.git.require_remote_freshness
$currentBranch = Select-AutonomousWriterBranch `
    -DesiredBranch $desiredBranch `
    -BaseBranch $baseBranch `
    -RemoteName $remoteName `
    -RequireRemoteFreshness $requireRemoteFreshness `
    -AllowDirectMain ([bool]$config.git.allow_direct_main)

$dirtyAfterBranch = Get-WorkingTreeText
if (-not [string]::IsNullOrWhiteSpace($dirtyAfterBranch)) { throw "Writer branch synchronization left uncommitted changes; refusing autonomous work.`n$dirtyAfterBranch" }

Ensure-RunExclusion -RepoRoot $projectRoot
$runDir = Join-Path $projectRoot ".agent-run"
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$statePath = Join-Path $runDir "state.json"
$runLock = Enter-AutonomousSingleWriterLock `
    -RunDirectory $runDir `
    -ProjectRoot $projectRoot `
    -CurrentBranch $currentBranch `
    -Required ([bool]$config.git.single_writer_required)

try {
    $workerMinutes = [int]$config.timeouts.worker_minutes
    $repairMinutes = [int]$config.timeouts.repair_minutes
    $reviewMinutes = [int]$config.timeouts.review_minutes
    $verifyMinutes = [int]$config.timeouts.verify_minutes
    $noOutputMinutes = [int]$config.timeouts.no_output_minutes
    $verifyCommand = [string]$config.verify_command
    $reviewRequired = [bool]$config.independent_review_required
    $preflightRequired = [bool]$config.preflight_verify_required

    $previousNextTask = ""
    if (Test-Path -LiteralPath $statePath) {
        try { $previousNextTask = [string](Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json).next_task }
        catch { $previousNextTask = "" }
    }

    $state = @{
        schema_version = 2
        project_id = [string]$config.project_id
        project_name = [string]$config.project_name
        run_id = "$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        started_at = (Get-Date).ToString("o")
        updated_at = (Get-Date).ToString("o")
        branch = $currentBranch
        base_branch = $baseBranch
        remote_name = $remoteName
        current_iteration = 0
        completed_tasks = 0
        phase = "preflight"
        last_task = ""
        next_task = $previousNextTask
        last_verified_commit = (& git rev-parse HEAD).Trim()
        last_review_verdict = ""
        last_review_risk = ""
        preflight_verified_commit = ""
        stop_reason = ""
    }
    Write-State -Path $statePath -State $state

    if ($preflightRequired) {
        $preflightStamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $preflightLog = Join-Path $runDir "preflight-verify-$preflightStamp.log"
        Write-Host "Running clean-baseline project verification before any worker edits..."
        $preflight = Invoke-ProjectCommand `
            -ProjectRoot $projectRoot `
            -CommandText $verifyCommand `
            -TimeoutMinutes $verifyMinutes `
            -LogPath $preflightLog
        if ($preflight.ExitCode -ne 0) {
            $state.phase = "blocked-preflight"
            $state.stop_reason = if ($preflight.TimedOut) { "preflight verification timed out" } else { "preflight verification failed" }
            Write-State -Path $statePath -State $state
            throw "Autonomous work is blocked because the clean baseline did not pass project verification. No worker edits were started. See $preflightLog"
        }
        $state.preflight_verified_commit = (& git rev-parse HEAD).Trim()
        Write-State -Path $statePath -State $state
    }

    $basePrompt = Get-Content -LiteralPath $taskPromptPath -Raw
    $baseReviewPrompt = Get-Content -LiteralPath $reviewPromptPath -Raw
    $startedAt = Get-Date
    $deadline = $startedAt.AddHours($Hours)
    $completedTasks = 0
    $stopReason = "time budget reached"
    $lastNextTask = $previousNextTask

    Write-Host ""
    Write-Host "Autonomous Builder V2 started"
    Write-Host "  Project    : $($config.project_name)"
    Write-Host "  Repository : $projectRoot"
    Write-Host "  Branch     : $currentBranch"
    Write-Host "  Base ref   : $baseBranch via $remoteName"
    Write-Host "  Time budget: $Hours hour(s) after preflight"
    Write-Host "  Task limit : $MaxTasks"
    Write-Host "  Worker cap : $workerMinutes minute(s)"
    Write-Host "  Review cap : $reviewMinutes minute(s)"
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
- The clean branch baseline passed the configured full verification before workers started.
- The outer supervisor will run the autonomous guard, an independent read-only review, and full project verification after your focused tests.
- Protected governance/control files may not be self-modified by an autonomous worker.
- The outer supervisor, not you, creates commits only after all gates pass.
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
        $activeResultPath = $resultPath
        $state.last_task = [string]$result.task
        $state.next_task = [string]$result.next_task
        $lastNextTask = [string]$result.next_task
        Write-State -Path $statePath -State $state
        Write-Host "Task       : $($result.task)"
        Write-Host "Status     : $($result.status)"
        Write-Host "Source     : $($result.source_doc) :: $($result.source_item)"
        Write-Host "Risk       : $($result.risk_level)"
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
        $gateStopReason = ""

        while (-not $verified) {
            $gateStamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $guardLog = Join-Path $runDir "guard-$iteration-attempt-$repairAttempt-$gateStamp.log"
            $verifyLog = Join-Path $runDir "verify-$iteration-attempt-$repairAttempt-$gateStamp.log"

            $state.phase = "autonomous-guard"
            Write-State -Path $statePath -State $state
            Write-Host "Running autonomous quality guard..."
            $guardEsc = Escape-SingleQuotedPowerShell $guardPath
            $rootEsc = Escape-SingleQuotedPowerShell $projectRoot
            $resultEsc = Escape-SingleQuotedPowerShell $activeResultPath
            $guardCommand = "& '$guardEsc' -ProjectRoot '$rootEsc' -ResultPath '$resultEsc'"
            $guard = Invoke-ProjectCommand -ProjectRoot $projectRoot -CommandText $guardCommand -TimeoutMinutes 10 -LogPath $guardLog

            if ($guard.ExitCode -eq 0 -and $reviewRequired) {
                $state.phase = "independent-review"
                Write-State -Path $statePath -State $state
                $reviewResultPath = Join-Path $runDir "review-$iteration-attempt-$repairAttempt-$gateStamp.json"
                $reviewLog = Join-Path $runDir "review-$iteration-attempt-$repairAttempt-$gateStamp.log"
                $relativeWorkerResult = ".agent-run/$([System.IO.Path]::GetFileName($activeResultPath))"
                $reviewPrompt = @"
$baseReviewPrompt

## Supervisor review context

- Target project: $($config.project_name)
- Worker task: $($result.task)
- Worker declared risk: $($result.risk_level)
- Worker structured result: `$relativeWorkerResult`
- Review the uncommitted diff against HEAD. Do not edit it.
"@
                Write-Host "Running independent read-only review..."
                $reviewRun = Invoke-CodexReviewer `
                    -Prompt $reviewPrompt `
                    -ProjectRoot $projectRoot `
                    -SchemaPath $reviewSchemaPath `
                    -ResultPath $reviewResultPath `
                    -LogPath $reviewLog `
                    -TimeoutMinutes $reviewMinutes `
                    -NoOutputMinutes $noOutputMinutes

                if ($reviewRun.ExitCode -ne 0) {
                    $gateStopReason = if ($reviewRun.TimedOut) { "independent reviewer timed out" } elseif ($reviewRun.Stalled) { "independent reviewer stalled" } else { "independent reviewer exited with code $($reviewRun.ExitCode)" }
                    $failureLog = $reviewLog
                    break
                }

                $reviewResult = Read-AgentResult -Path $reviewResultPath
                $state.last_review_verdict = [string]$reviewResult.verdict
                $state.last_review_risk = [string]$reviewResult.risk_level
                Write-State -Path $statePath -State $state
                Write-Host "Review     : $($reviewResult.verdict) / $($reviewResult.risk_level)"
                $reviewBlocks = ([string]$reviewResult.verdict -eq "block")
                $reviewRaisedRisk = (Get-AutonomousRiskRank -Risk ([string]$reviewResult.risk_level)) -gt (Get-AutonomousRiskRank -Risk ([string]$result.risk_level))
                if ($reviewBlocks -or $reviewRaisedRisk) { $failureLog = $reviewResultPath }
            }
            elseif ($guard.ExitCode -ne 0) { $failureLog = $guardLog }

            if ($guard.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($failureLog) -and [string]::IsNullOrWhiteSpace($gateStopReason)) {
                $state.phase = "full-verification"
                Write-State -Path $statePath -State $state
                Write-Host "Running project verification..."
                $verify = Invoke-ProjectCommand -ProjectRoot $projectRoot -CommandText $verifyCommand -TimeoutMinutes $verifyMinutes -LogPath $verifyLog
                if ($verify.ExitCode -eq 0) { $verified = $true; break }
                $failureLog = $verifyLog
            }

            if (-not [string]::IsNullOrWhiteSpace($gateStopReason)) { break }
            if ($repairAttempt -ge $MaxRepairAttempts) { break }
            $repairAttempt++
            $repairStamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $repairResultPath = Join-Path $runDir "repair-result-$iteration-$repairAttempt-$repairStamp.json"
            $repairLog = Join-Path $runDir "repair-$iteration-$repairAttempt-$repairStamp.log"
            $relativeFailureLog = ".agent-run/$([System.IO.Path]::GetFileName($failureLog))"
            $repairPrompt = @"
Read `.autobuild/project.json`, `docs/PROJECT_KNOWLEDGE_INDEX.md`, the configured agent policy, and relevant quality/risk/domain knowledge. You are repairing only the current increment: `$($result.task)`.

A supervisor guard, independent review, or full verification gate failed. Inspect `$relativeFailureLog` and the current Git diff. Fix only root causes associated with this increment or a directly exposed defect required for it to pass.

Do not modify protected governance/control files. Do not weaken tests, feature-preservation anchors, size rules, change budgets, risk classification, security, financial/data invariants, or product contracts. If the increment is too large, reduce/split the current work rather than bypassing the gate. Do not commit, branch, push, merge, deploy, spend money, or perform live-provider actions.

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

            if ($repair.ExitCode -ne 0) { $gateStopReason = "repair worker failed or timed out with code $($repair.ExitCode)"; break }
            $result = Read-AgentResult -Path $repairResultPath
            $activeResultPath = $repairResultPath
            $failureLog = ""
        }

        if (-not $verified) {
            $failurePatch = Join-Path $runDir "failed-iteration-$iteration.patch"
            @(& git diff --binary) | Set-Content -LiteralPath $failurePatch
            Assert-LastExitCode "git diff --binary"
            $stopReason = if (-not [string]::IsNullOrWhiteSpace($gateStopReason)) { $gateStopReason } else { "quality/review gates still failing; changes left uncommitted. Patch: $failurePatch" }
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
        if ($Push) { Invoke-Git @("push", "-u", $remoteName, $currentBranch) }

        $state.completed_tasks = $completedTasks
        $state.last_verified_commit = $currentSha
        $state.next_task = [string]$result.next_task
        $state.phase = "verified"
        Write-State -Path $statePath -State $state
        Write-Host "Verified commit: $currentSha  $commitMessage"
        Write-Host ""

        if ($result.status -eq "complete") { $stopReason = "agent reports all currently safe code work complete"; break }
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
    Write-Host "  Elapsed         : $([Math]::Round($elapsed.TotalMinutes, 1)) minute(s) after preflight"
    Write-Host "  Stop reason     : $stopReason"
    Write-Host "  State/logs      : $runDir"
    Write-Host ""
    Write-Host "Review the reusable writer branch before opening or updating its pull request. Production activation and merge to main remain human controlled."
}
finally {
    if ($null -ne $runLock) { $runLock.Dispose() }
}
