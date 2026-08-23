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

$v2 = Join-Path $PSScriptRoot "autonomous_build_v2.ps1"
$recovery = Join-Path $PSScriptRoot "autonomous_recovery.ps1"
$fingerprint = Join-Path $PSScriptRoot "autonomous_fingerprint.ps1"
foreach ($required in @($v2, $recovery, $fingerprint)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Autonomous Builder source is missing: $required"
    }
}
. $fingerprint

$targetProject = $ProjectPath
if ([string]::IsNullOrWhiteSpace($targetProject)) {
    $targetProject = (& git rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($targetProject)) {
        throw "ProjectPath was not supplied and the current directory is not a Git repository."
    }
}
$targetProject = (Resolve-Path -LiteralPath $targetProject).Path

# Clean worktrees are a no-op. Dirty worktrees are recovered only when prior
# autonomous state proves the interrupted changes belong to this writer branch
# and HEAD is still the last verified commit. Operator-owned changes fail closed.
& $recovery -ProjectRoot $targetProject

$configPath = Join-Path $targetProject ".autobuild/project.json"
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Target project is missing autonomous configuration: $configPath"
}
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
Assert-AutonomousGraduationEvidence -ProjectRoot $targetProject -Config $config

$forward = @{
    ProjectPath = $targetProject
    Hours = $Hours
    MaxTasks = $MaxTasks
    MaxRepairAttempts = $MaxRepairAttempts
    Push = $Push
    Branch = $Branch
}

& $v2 @forward
