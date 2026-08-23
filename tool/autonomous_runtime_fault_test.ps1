[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$helpers = Join-Path $PSScriptRoot "autonomous_process.ps1"
$projectHelpers = Join-Path $PSScriptRoot "autonomous_project.ps1"
foreach ($required in @($helpers, $projectHelpers)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing runtime helper: $required" }
    . $required
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "pipe-autobuild-runtime-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

try {
    Write-Host "Testing hard worker timeout with a real child process..."
    $timeoutLog = Join-Path $tempRoot "timeout.log"
    $timeoutResult = Invoke-TimedPowerShell `
        -ScriptText 'Write-Output "started"; Start-Sleep -Seconds 180' `
        -TimeoutMinutes 1 `
        -NoOutputMinutes 0 `
        -LogPath $timeoutLog
    Assert-True ($timeoutResult.ExitCode -eq 124) "Timed worker must exit with containment code 124."
    Assert-True ([bool]$timeoutResult.TimedOut) "Timed worker was not classified as timed out."
    Assert-True (-not [bool]$timeoutResult.Stalled) "Hard timeout was incorrectly classified as a stall."
    Write-Host "PASS runtime containment: hard timeout terminated the process."

    Write-Host "Testing no-output watchdog with a real silent process..."
    $stallLog = Join-Path $tempRoot "stall.log"
    $stallResult = Invoke-TimedPowerShell `
        -ScriptText 'Start-Sleep -Seconds 180' `
        -TimeoutMinutes 2 `
        -NoOutputMinutes 1 `
        -LogPath $stallLog
    Assert-True ($stallResult.ExitCode -eq 124) "Stalled worker must exit with containment code 124."
    Assert-True ([bool]$stallResult.Stalled) "Silent worker was not classified as stalled."
    Assert-True (-not [bool]$stallResult.TimedOut) "Stall watchdog should fire before the hard timeout."
    Write-Host "PASS runtime containment: no-output watchdog terminated the process."

    Write-Host "Testing exclusive lock contention across real PowerShell processes..."
    $lockDir = Join-Path $tempRoot "lock"
    New-Item -ItemType Directory -Path $lockDir -Force | Out-Null
    $lockPath = Join-Path $lockDir "supervisor.lock"
    $holderScript = @"
`$stream = [System.IO.File]::Open('$($lockPath.Replace("'", "''"))',[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
try { Start-Sleep -Seconds 20 } finally { `$stream.Dispose() }
"@
    $shell = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $shell) { $shell = Get-Command powershell.exe -ErrorAction Stop }
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($holderScript))
    $holder = Start-Process -FilePath $shell.Source -ArgumentList @("-NoProfile", "-EncodedCommand", $encoded) -PassThru -NoNewWindow
    Start-Sleep -Seconds 2

    $contentionFailed = $false
    $secondLock = $null
    try {
        $secondLock = [System.IO.File]::Open(
            $lockPath,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
    }
    catch { $contentionFailed = $true }
    finally { if ($null -ne $secondLock) { $secondLock.Dispose() } }
    Assert-True $contentionFailed "Second process unexpectedly acquired the autonomous supervisor lock."
    Stop-ProcessTreeSafe -Process $holder
    try { $holder.WaitForExit() } catch { }
    Write-Host "PASS runtime containment: real process contention was rejected."

    Write-Host "Autonomous runtime fault suite passed."
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
