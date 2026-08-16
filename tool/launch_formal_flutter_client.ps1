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

$webPort = 5050
if (Port-In-Use $webPort) {
  $owner = Get-NetTCPConnection -State Listen -LocalPort $webPort -ErrorAction SilentlyContinue |
    Select-Object -First 1
  $pidText = if ($null -ne $owner) { " (PID $($owner.OwningProcess))" } else { '' }
  throw "Local Pipe Buyer web port $webPort is already in use$pidText. Stop the older Flutter client before starting another one."
}

Write-Host 'Launching Pipe Buyer Flutter client against the already-running local emulator suite.' -ForegroundColor Cyan
Write-Host 'Pipe Buyer local app: http://127.0.0.1:5050' -ForegroundColor Green
Write-Host 'Firebase Emulator UI: http://127.0.0.1:14000' -ForegroundColor DarkGray
Write-Host 'Stable debug mode: Flutter web experimental hot reload is disabled for this large app.' -ForegroundColor Yellow
Write-Host 'Use R in this terminal for a hot restart after code changes.' -ForegroundColor DarkGray

& flutter run -d chrome `
  --no-web-experimental-hot-reload `
  --web-port=$webPort `
  --dart-define=PIPE_ENV=local `
  --dart-define=PIPE_ENABLE_DISPATCH=true `
  --dart-define=PIPE_ENABLE_AUCTIONS=true `
  --dart-define=PIPE_FIREBASE_EMULATOR_HOST=127.0.0.1 `
  --dart-define=PIPE_FIREBASE_AUTH_EMULATOR_PORT=19099 `
  --dart-define=PIPE_FIREBASE_FIRESTORE_EMULATOR_PORT=18080 `
  --dart-define=PIPE_FIREBASE_FUNCTIONS_EMULATOR_PORT=15001 `
  --dart-define=PIPE_FIREBASE_STORAGE_EMULATOR_PORT=19199
