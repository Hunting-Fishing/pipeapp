param()

$ErrorActionPreference = 'Stop'

function Require-Port([int]$Port, [string]$Label) {
  $listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($null -eq $listener) {
    throw "$Label is not listening on port $Port. Start tool/start_formal_acceptance_environment.ps1 first."
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

Write-Host 'Launching Pipe Buyer Flutter client against the already-running local emulator suite.' -ForegroundColor Cyan
Write-Host 'Firebase Emulator UI: http://127.0.0.1:14000' -ForegroundColor DarkGray
Write-Host 'Flutter will choose its own temporary local web port and open Chrome automatically.' -ForegroundColor DarkGray

& flutter run -d chrome `
  --dart-define=PIPE_ENV=local `
  --dart-define=PIPE_ENABLE_DISPATCH=true `
  --dart-define=PIPE_ENABLE_AUCTIONS=true `
  --dart-define=PIPE_FIREBASE_EMULATOR_HOST=127.0.0.1 `
  --dart-define=PIPE_FIREBASE_AUTH_EMULATOR_PORT=19099 `
  --dart-define=PIPE_FIREBASE_FIRESTORE_EMULATOR_PORT=18080 `
  --dart-define=PIPE_FIREBASE_FUNCTIONS_EMULATOR_PORT=15001 `
  --dart-define=PIPE_FIREBASE_STORAGE_EMULATOR_PORT=19199
