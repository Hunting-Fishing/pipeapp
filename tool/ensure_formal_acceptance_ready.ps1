param(
  [switch]$NoRepair
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Require-Port([int]$Port, [string]$Label) {
  $listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($null -eq $listener) {
    throw "$Label is not listening on port $Port. Run tool/start_formal_acceptance_environment.ps1 when the emulator suite is not already running."
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
[Environment]::CurrentDirectory = $repoRoot

$expectedBranch = 'design/formal-beautification-foundation'
$currentBranch = ((git branch --show-current | Out-String).Trim())
if ($currentBranch -ne $expectedBranch) {
  throw "Formal acceptance readiness requires $expectedBranch. Current branch: $currentBranch"
}

Write-Step 'Checking the already-running formal emulator suite'
Require-Port 19099 'Auth emulator'
Require-Port 18080 'Firestore emulator'
Require-Port 15001 'Functions emulator'
Require-Port 19199 'Storage emulator'
Require-Port 14000 'Emulator UI'

$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:19099'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:18080'
$env:FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:19199'
$env:FUNCTIONS_EMULATOR_HOST = '127.0.0.1:15001'
$env:GCLOUD_PROJECT = 'flutter-flow-pipe'
$env:GOOGLE_CLOUD_PROJECT = 'flutter-flow-pipe'

$fixtureVerifier = Join-Path $repoRoot 'firebase\functions\scripts\verify_visual_sandbox.js'
$authVerifier = Join-Path $PSScriptRoot 'verify_formal_demo_auth.ps1'
$authRepair = Join-Path $repoRoot 'firebase\functions\scripts\ensure_formal_demo_auth.js'
$reseed = Join-Path $PSScriptRoot 'reseed_formal_test_data.ps1'

foreach ($required in @($fixtureVerifier, $authVerifier, $authRepair, $reseed)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Formal readiness control is missing: $required"
  }
}

Write-Step 'Verifying the deterministic Firestore/Auth fixture set without changing it'
& node $fixtureVerifier
$fixtureCode = $LASTEXITCODE

if ($fixtureCode -ne 0) {
  if ($NoRepair) {
    throw 'Formal fixtures are missing or stale and -NoRepair was requested.'
  }

  Write-Step 'Fixture verification failed; performing one deterministic full reseed'
  & powershell -ExecutionPolicy Bypass -File $reseed
  if ($LASTEXITCODE -ne 0) {
    throw 'The one allowed deterministic fixture reseed failed. Stop and inspect the first error above.'
  }
} else {
  Write-Step 'Verifying the published demo email/password credentials'
  & powershell -ExecutionPolicy Bypass -File $authVerifier
  $authCode = $LASTEXITCODE

  if ($authCode -ne 0) {
    if ($NoRepair) {
      throw 'Formal demo Auth credentials failed and -NoRepair was requested.'
    }

    Write-Step 'Firestore fixtures are healthy; repairing Auth accounts only'
    & node $authRepair
    if ($LASTEXITCODE -ne 0) {
      throw 'Auth-only deterministic repair failed.'
    }

    Write-Step 'Re-proving all four demo passwords after Auth-only repair'
    & powershell -ExecutionPolicy Bypass -File $authVerifier
    if ($LASTEXITCODE -ne 0) {
      throw 'Demo Auth credentials still fail after the one allowed Auth-only repair.'
    }
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER FORMAL ACCEPTANCE READY' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Emulator ports: PASS' -ForegroundColor Green
Write-Host 'Deterministic fixtures: PASS' -ForegroundColor Green
Write-Host 'Four direct demo password logins: PASS' -ForegroundColor Green
Write-Host 'Safe to launch Flutter: PASS' -ForegroundColor Green
