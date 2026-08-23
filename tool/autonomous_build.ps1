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
if (-not (Test-Path -LiteralPath $v2)) {
    throw "Autonomous Builder V2 source is missing: $v2"
}

$forward = @{
    ProjectPath = $ProjectPath
    Hours = $Hours
    MaxTasks = $MaxTasks
    MaxRepairAttempts = $MaxRepairAttempts
    Push = $Push
    Branch = $Branch
}

& $v2 @forward
