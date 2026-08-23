[CmdletBinding()]
param(
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

function Invoke-LoggedNative {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$CommandArgs,

        [string]$LogPath = ""
    )

    if ([string]::IsNullOrWhiteSpace($LogPath)) {
        & $Command @CommandArgs
    }
    else {
        & $Command @CommandArgs 2>&1 | Tee-Object -FilePath $LogPath
    }

    return $LASTEXITCODE
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$GitArgs
    )

    $exitCode = Invoke-LoggedNative -Command "git" -CommandArgs $GitArgs
    if ($exitCode -ne 0) {
        throw "git $($GitArgs -join ' ') failed with exit code $exitCode."
    }
}

function Invoke-CodexIteration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $true)]
        [string]$SchemaPath,

        [Parameter(Mandatory = $true)]
        [string]$ResultPath,

        [Parameter(Mandatory = $true)]
        [string]$EventLogPath
    )

    if (Test-Path -LiteralPath $ResultPath) {
        Remove-Item -LiteralPath $ResultPath -Force
    }

    $codexArgs = @(
        "exec",
        "--sandbox", "workspace-write",
        "--json",
        "--output-schema", $SchemaPath,
        "-o", $ResultPath,
        $Prompt
    )

    return Invoke-LoggedNative -Command "codex" -CommandArgs $codexArgs -LogPath $EventLogPath
}

function Read-AgentResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Codex did not write the required structured result: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Codex wrote an empty structured result: $Path"
    }

    return $raw | ConvertFrom-Json
}

function Get-WorkingTreeText {
    $statusLines = @(& git status --porcelain)
    if ($LASTEXITCODE -ne 0) {
        throw "git status --porcelain failed with exit code $LASTEXITCODE."
    }

    return ($statusLines -join [Environment]::NewLine).Trim()
}

function Ensure-LocalRunExclusion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $excludePath = Join-Path $RepoRoot ".git/info/exclude"
    $excludeDirectory = Split-Path -Parent $excludePath
    if (-not (Test-Path -LiteralPath $excludeDirectory)) {
        New-Item -ItemType Directory -Path $excludeDirectory -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $excludePath)) {
        New-Item -ItemType File -Path $excludePath -Force | Out-Null
    }

    $existing = Get-Content -LiteralPath $excludePath -Raw
    if ($existing -notmatch "(?m)^\.agent-run/$") {
        Add-Content -LiteralPath $excludePath -Value ".agent-run/"
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is required but was not found on PATH."
}

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    throw "Codex CLI is required but was not found on PATH. Install/authenticate Codex before starting the autonomous runner."
}

$verificationShell = $null
if (Get-Command powershell.exe -ErrorAction SilentlyContinue) {
    $verificationShell = "powershell.exe"
}
elseif (Get-Command pwsh -ErrorAction SilentlyContinue) {
    $verificationShell = "pwsh"
}
else {
    throw "A PowerShell executable is required to run tool/verify.ps1."
}

$repoRoot = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
    throw "This command must be run inside the Pipe Buyer Git repository."
}
Set-Location -LiteralPath $repoRoot

$verifyScript = Join-Path $repoRoot "tool/verify.ps1"
$schemaPath = Join-Path $repoRoot "automation/agent/result.schema.json"
$taskPromptPath = Join-Path $repoRoot "automation/agent/task_prompt.md"
$agentsPath = Join-Path $repoRoot "AGENTS.md"

foreach ($requiredPath in @($verifyScript, $schemaPath, $taskPromptPath, $agentsPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required autonomous build file is missing: $requiredPath"
    }
}

$initialDirty = Get-WorkingTreeText
if (-not [string]::IsNullOrWhiteSpace($initialDirty)) {
    throw "The working tree must be clean before autonomous mode starts. Commit, stash, or move existing changes first.`n$initialDirty"
}

$currentBranch = (& git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($currentBranch)) {
    throw "Autonomous mode requires a named Git branch; detached HEAD is not supported."
}

if (-not [string]::IsNullOrWhiteSpace($Branch)) {
    if ($Branch -in @("main", "master")) {
        throw "Refusing to use main/master as an autonomous build branch."
    }

    if ($Branch -ne $currentBranch) {
        & git show-ref --verify --quiet "refs/heads/$Branch"
        $branchExists = ($LASTEXITCODE -eq 0)
        if ($branchExists) {
            Invoke-Git -GitArgs @("switch", $Branch)
        }
        else {
            Invoke-Git -GitArgs @("switch", "-c", $Branch)
        }
        $currentBranch = $Branch
    }
}
elseif ($currentBranch -notlike "agent/autobuild-*") {
    $Branch = "agent/autobuild-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Invoke-Git -GitArgs @("switch", "-c", $Branch)
    $currentBranch = $Branch
}

if ($currentBranch -in @("main", "master")) {
    throw "Refusing to run autonomous editing directly on $currentBranch."
}

Ensure-LocalRunExclusion -RepoRoot $repoRoot
$runDir = Join-Path $repoRoot ".agent-run"
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

$basePrompt = Get-Content -LiteralPath $taskPromptPath -Raw
$startedAt = Get-Date
$deadline = $startedAt.AddHours($Hours)
$completedTasks = 0
$stopReason = "time budget reached"

Write-Host ""
Write-Host "Pipe Buyer autonomous build started"
Write-Host "  Repository : $repoRoot"
Write-Host "  Branch     : $currentBranch"
Write-Host "  Time budget: $Hours hour(s)"
Write-Host "  Task limit : $MaxTasks"
Write-Host "  Push       : $($Push.IsPresent)"
Write-Host "  Run logs   : $runDir"
Write-Host ""

for ($iteration = 1; $iteration -le $MaxTasks; $iteration++) {
    if ((Get-Date) -ge $deadline) {
        $stopReason = "time budget reached"
        break
    }

    $remainingMinutes = [Math]::Max(0, [Math]::Floor(($deadline - (Get-Date)).TotalMinutes))
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $resultPath = Join-Path $runDir "result-$iteration-$stamp.json"
    $eventLogPath = Join-Path $runDir "codex-$iteration-$stamp.jsonl"

    $prompt = @"
$basePrompt

## Outer-run context

- Autonomous iteration: $iteration of $MaxTasks
- Current branch: $currentBranch
- Approximate time remaining: $remainingMinutes minute(s)
- The outer runner will execute `.\tool\verify.ps1` after your targeted verification.
- The outer runner, not you, will create a commit only if the complete quality gate passes.
- Temporary runner logs live under `.agent-run/` and must not be edited or committed.
"@

    Write-Host "=== Iteration $iteration / $MaxTasks ==="
    $codexExit = Invoke-CodexIteration -Prompt $prompt -SchemaPath $schemaPath -ResultPath $resultPath -EventLogPath $eventLogPath
    if ($codexExit -ne 0) {
        $stopReason = "Codex exited with code $codexExit"
        Write-Warning $stopReason
        break
    }

    $result = Read-AgentResult -Path $resultPath
    Write-Host "Task   : $($result.task)"
    Write-Host "Status : $($result.status)"
    Write-Host "Source : $($result.source_doc) :: $($result.source_item)"

    $dirty = Get-WorkingTreeText
    if ([string]::IsNullOrWhiteSpace($dirty)) {
        if ($result.status -eq "complete") {
            $stopReason = "agent reports no safe unfinished code work"
        }
        elseif ($result.status -eq "blocked" -or $result.requires_human) {
            $stopReason = "human blocker: $($result.blocker_classification) - $($result.human_reason)"
        }
        else {
            $stopReason = "agent returned no workspace changes for a continue iteration"
        }

        Write-Host $stopReason
        break
    }

    $verified = $false
    $repairAttempt = 0

    while (-not $verified) {
        $verifyStamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $verifyLog = Join-Path $runDir "verify-$iteration-attempt-$repairAttempt-$verifyStamp.log"
        $verifyArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $verifyScript)

        Write-Host "Running full repository quality gate..."
        $verifyExit = Invoke-LoggedNative -Command $verificationShell -CommandArgs $verifyArgs -LogPath $verifyLog
        if ($verifyExit -eq 0) {
            $verified = $true
            break
        }

        if ($repairAttempt -ge $MaxRepairAttempts) {
            break
        }

        $repairAttempt++
        $repairStamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $repairResultPath = Join-Path $runDir "repair-result-$iteration-$repairAttempt-$repairStamp.json"
        $repairEventLog = Join-Path $runDir "repair-codex-$iteration-$repairAttempt-$repairStamp.jsonl"
        $relativeVerifyLog = ".agent-run/$([System.IO.Path]::GetFileName($verifyLog))"

        $repairPrompt = @"
Read `AGENTS.md` and obey it. You are repairing only the current autonomous increment: `$($result.task)`.

The complete repository quality gate failed. Inspect the failure log at `$relativeVerifyLog`, inspect the current Git diff, and fix only root causes associated with the current increment or a directly exposed repository defect required for this increment to pass.

Do not delete, mute, skip, or weaken tests. Do not broaden product scope. Do not commit, branch, push, merge, deploy, or perform live-provider actions. Run focused verification after the repair.

Return only the structured result required by `automation/agent/result.schema.json`.
"@

        Write-Host "Quality gate failed; starting repair attempt $repairAttempt of $MaxRepairAttempts..."
        $repairExit = Invoke-CodexIteration -Prompt $repairPrompt -SchemaPath $schemaPath -ResultPath $repairResultPath -EventLogPath $repairEventLog
        if ($repairExit -ne 0) {
            $stopReason = "Codex repair attempt exited with code $repairExit"
            break
        }

        $result = Read-AgentResult -Path $repairResultPath
    }

    if (-not $verified) {
        $failurePatch = Join-Path $runDir "failed-iteration-$iteration.patch"
        $patchLines = @(& git diff --binary)
        if ($LASTEXITCODE -ne 0) {
            throw "git diff --binary failed with exit code $LASTEXITCODE."
        }
        $patchLines | Set-Content -LiteralPath $failurePatch

        $stopReason = "full quality gate still failing; changes left uncommitted for review. Patch: $failurePatch"
        Write-Warning $stopReason
        break
    }

    $dirtyAfterVerify = Get-WorkingTreeText
    if ([string]::IsNullOrWhiteSpace($dirtyAfterVerify)) {
        Write-Host "Verification passed but there are no changes to commit."
        if ($result.status -eq "complete") {
            $stopReason = "agent reports complete"
            break
        }
        continue
    }

    $commitMessage = [string]$result.commit_message
    if ([string]::IsNullOrWhiteSpace($commitMessage)) {
        $commitMessage = "agent: autonomous increment $iteration"
    }
    elseif (-not $commitMessage.StartsWith("agent:")) {
        $commitMessage = "agent: $commitMessage"
    }

    Invoke-Git -GitArgs @("add", "-A")
    Invoke-Git -GitArgs @("commit", "-m", $commitMessage)
    $completedTasks++

    if ($Push) {
        Invoke-Git -GitArgs @("push", "-u", "origin", $currentBranch)
    }

    Write-Host "Verified commit created: $commitMessage"
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
if ($LASTEXITCODE -ne 0) {
    throw "git rev-parse HEAD failed with exit code $LASTEXITCODE."
}

Write-Host ""
Write-Host "Pipe Buyer autonomous build finished"
Write-Host "  Branch          : $currentBranch"
Write-Host "  HEAD            : $currentSha"
Write-Host "  Verified commits: $completedTasks"
Write-Host "  Elapsed         : $([Math]::Round($elapsed.TotalMinutes, 1)) minute(s)"
Write-Host "  Stop reason     : $stopReason"
Write-Host "  Logs            : $runDir"
Write-Host ""
Write-Host "Review the branch and logs before opening or merging a pull request. Production activation remains a separate human-controlled action."
