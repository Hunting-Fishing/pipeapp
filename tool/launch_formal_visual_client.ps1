param()

$ErrorActionPreference = 'Stop'

function Require-Port([int]$Port, [string]$Label) {
  $listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($null -eq $listener) {
    throw "$Label is not listening on port $Port. Start tool/start_formal_acceptance_environment.ps1 first."
  }
}

function Port-In-Use([int]$Port) {
  return $null -ne (
    Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
      Select-Object -First 1
  )
}

function Test-CarrierFixture {
  $body = @{
    email = 'carrier.visual@pipebuyer.test'
    password = 'PipeBuyerDemo!2026'
    returnSecureToken = $true
  } | ConvertTo-Json

  try {
    $result = Invoke-RestMethod `
      -Method Post `
      -Uri 'http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=pipebuyer-local' `
      -ContentType 'application/json' `
      -Body $body
    return $result.localId -eq 'visual-carrier' -and -not [string]::IsNullOrWhiteSpace($result.idToken)
  }
  catch {
    return $false
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "This helper is for design/formal-beautification-foundation. Current branch: $branch"
}

Require-Port 19099 'Auth emulator'
Require-Port 18080 'Firestore emulator'
Require-Port 15001 'Functions emulator'
Require-Port 19199 'Storage emulator'

Write-Host 'Checking the approved Dispatch carrier fixture before opening Flutter...' -ForegroundColor DarkGray
if (-not (Test-CarrierFixture)) {
  Write-Host 'The local Auth fixture is missing or stale. Reseeding the deterministic formal sandbox now.' -ForegroundColor Yellow
  $reseedHelper = Join-Path $PSScriptRoot 'reseed_formal_test_data.ps1'
  if (-not (Test-Path -LiteralPath $reseedHelper)) {
    throw 'tool/reseed_formal_test_data.ps1 is missing. Pull the latest formal branch.'
  }
  & powershell -ExecutionPolicy Bypass -File $reseedHelper
  if ($LASTEXITCODE -ne 0) {
    throw 'Formal sandbox reseed failed. Read the first failing section above.'
  }
  if (-not (Test-CarrierFixture)) {
    throw 'The carrier fixture still cannot authenticate after reseeding. Do not start Flutter; inspect the Auth emulator first.'
  }
  Write-Host 'Carrier fixture restored and verified.' -ForegroundColor Green
} else {
  Write-Host 'Carrier fixture authentication verified.' -ForegroundColor Green
}

$webPort = 5050
if (Port-In-Use $webPort) {
  $owner = Get-NetTCPConnection -State Listen -LocalPort $webPort -ErrorAction SilentlyContinue |
    Select-Object -First 1
  $pidText = if ($null -ne $owner) { " (PID $($owner.OwningProcess))" } else { '' }
  throw "Local Pipe Buyer web port $webPort is already in use$pidText. Stop the older Flutter client before starting visual acceptance mode."
}

Write-Host 'Launching Pipe Buyer in PROFILE mode for stable visual acceptance.' -ForegroundColor Cyan
Write-Host 'This avoids the large DDC debug-module startup path that can stall before the Dart entrypoint loads.' -ForegroundColor Yellow
Write-Host 'Pipe Buyer local app: http://127.0.0.1:5050' -ForegroundColor Green
Write-Host 'Firebase Emulator UI: http://127.0.0.1:14000' -ForegroundColor DarkGray
Write-Host 'Profile mode does not support Flutter hot reload; stop/relaunch after source changes.' -ForegroundColor DarkGray

$loginReference = Join-Path $PSScriptRoot 'show_formal_test_logins.ps1'
if (Test-Path -LiteralPath $loginReference) {
  & powershell -ExecutionPolicy Bypass -File $loginReference
} else {
  Write-Host 'Test login reference helper is missing; pull the latest formal branch.' -ForegroundColor Yellow
}

& flutter run --profile -d chrome `
  --web-port=$webPort `
  --dart-define=PIPE_ENV=local `
  --dart-define=PIPE_ENABLE_DISPATCH=true `
  --dart-define=PIPE_ENABLE_AUCTIONS=true `
  --dart-define=PIPE_FIREBASE_EMULATOR_HOST=127.0.0.1 `
  --dart-define=PIPE_FIREBASE_AUTH_EMULATOR_PORT=19099 `
  --dart-define=PIPE_FIREBASE_FIRESTORE_EMULATOR_PORT=18080 `
  --dart-define=PIPE_FIREBASE_FUNCTIONS_EMULATOR_PORT=15001 `
  --dart-define=PIPE_FIREBASE_STORAGE_EMULATOR_PORT=19199