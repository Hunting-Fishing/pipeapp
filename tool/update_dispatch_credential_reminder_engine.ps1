$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

function Normalize-Lf([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Read-GitObject([string]$Spec) {
  $content = (& git show $Spec | Out-String)
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: Could not read Git object $Spec"
  }
  return Normalize-Lf $content
}

$remote = 'origin/design/formal-beautification-foundation'
$relativeMonitor = 'firebase/functions/dispatch_credential_monitor.js'
$relativeTest = 'firebase/functions/test/dispatch_credential_monitor.test.js'
$monitorPath = Join-Path $script:PipeBuyerRepoRoot ($relativeMonitor.Replace('/', '\'))
$testPath = Join-Path $script:PipeBuyerRepoRoot ($relativeTest.Replace('/', '\'))
$knownBrokenBlob = '9de31cb0a6ab84c52b98a2bc192a75d8be13f341'

Write-Host "`n==> Fetching formal branch without merging" -ForegroundColor Cyan
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the formal branch.'
}

if (-not (Test-Path -LiteralPath $monitorPath)) {
  throw "STOP: Credential reminder monitor is missing: $monitorPath"
}

$local = Normalize-Lf ([System.IO.File]::ReadAllText($monitorPath))
$knownBroken = Read-GitObject $knownBrokenBlob
$remoteMonitor = Read-GitObject "$remote`:$relativeMonitor"

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $script:PipeBuyerRepoRoot "_local_backups\dispatch-reminder-engine-$stamp"

if ($local -eq $remoteMonitor) {
  Write-Host 'Credential reminder engine already matches the current formal revision.' -ForegroundColor DarkGray
}
elseif ($local -eq $knownBroken) {
  New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
  Copy-Item -LiteralPath $monitorPath -Destination (Join-Path $backupDir 'dispatch_credential_monitor.js')
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($monitorPath, $remoteMonitor, $utf8NoBom)
  Write-Host "Updated the one known broken credential reminder revision. Backup: $backupDir" -ForegroundColor Green
}
else {
  throw @"
STOP: Local credential reminder engine is neither the known broken revision nor the current formal revision.
No source was overwritten.
File: $monitorPath
This means the local file contains additional work and must be inspected before replacement.
"@
}

# Test/support code may be synchronized freely; production source is never
# checked out blindly by this updater.
& git checkout $remote -- $relativeTest
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize the credential reminder regression test.'
}
& git reset -q HEAD -- $relativeTest

Write-Host "`n==> Checking reminder engine syntax" -ForegroundColor Cyan
& node --check $monitorPath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential reminder engine syntax check failed.'
}

Write-Host "`n==> Running focused reminder scheduling regression" -ForegroundColor Cyan
& node --test $testPath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential reminder scheduling regression failed.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH CREDENTIAL REMINDER ENGINE READY' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Known broken revision overwritten blindly: NO' -ForegroundColor Green
Write-Host 'Unknown local revision overwritten: NO' -ForegroundColor Green
Write-Host 'Reminder next-due regression: PASS' -ForegroundColor Green
Write-Host 'Dispatch tracker modified: NO' -ForegroundColor Green
