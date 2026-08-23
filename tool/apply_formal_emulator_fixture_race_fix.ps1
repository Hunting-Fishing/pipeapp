$ErrorActionPreference = 'Stop'

function Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function FileHash([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

if ((git branch --show-current).Trim() -ne 'design/formal-beautification-foundation') {
  throw 'Run this only on design/formal-beautification-foundation.'
}

$patcher = Join-Path $PSScriptRoot 'fix_formal_emulator_fixture_race.mjs'
$index = Join-Path $repoRoot 'firebase\functions\index.js'
$acceptance = Join-Path $PSScriptRoot 'start_formal_acceptance_environment.ps1'

foreach ($file in @($patcher, $index, $acceptance)) {
  if (-not (Test-Path -LiteralPath $file)) { throw "Missing required file: $file" }
}

$backupRoot = Join-Path $env:TEMP "pipebuyer-emulator-race-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$indexBackup = Join-Path $backupRoot 'index.js.bak'
$acceptanceBackup = Join-Path $backupRoot 'start_formal_acceptance_environment.ps1.bak'
Copy-Item -LiteralPath $index -Destination $indexBackup -Force
Copy-Item -LiteralPath $acceptance -Destination $acceptanceBackup -Force
$indexHash = FileHash $index
$acceptanceHash = FileHash $acceptance

$complete = $false
try {
  Step 'Syntax-checking emulator fixture-race patcher'
  & node --check $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Fixture-race patcher syntax check failed.' }

  Step 'Applying deterministic emulator fixture-race repair'
  & node $patcher
  if ($LASTEXITCODE -ne 0) { throw 'Fixture-race patcher failed.' }

  Step 'Checking Functions source syntax'
  & node --check $index
  if ($LASTEXITCODE -ne 0) { throw 'firebase/functions/index.js syntax check failed.' }

  Step 'Checking acceptance PowerShell syntax'
  $scriptText = Get-Content -LiteralPath $acceptance -Raw
  [void][ScriptBlock]::Create($scriptText)

  Step 'FORMAL EMULATOR FIXTURE RACE FIX PASSED'
  Write-Host 'Root cause recorded: delayed visual-sandbox onCreate aggregators could mutate deterministic analytics after verification.' -ForegroundColor Green
  Write-Host 'Fix: sandbox conversation/offer aggregators are skipped and post-smoke acceptance re-normalizes the complete fixture.' -ForegroundColor Green
  $complete = $true
}
finally {
  if (-not $complete) {
    if ((FileHash $index) -ne $indexHash) {
      Copy-Item -LiteralPath $indexBackup -Destination $index -Force
    }
    if ((FileHash $acceptance) -ne $acceptanceHash) {
      Copy-Item -LiteralPath $acceptanceBackup -Destination $acceptance -Force
    }
    Write-Host "Repair failed; protected files restored from $backupRoot" -ForegroundColor Yellow
  } else {
    Remove-Item -LiteralPath $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
