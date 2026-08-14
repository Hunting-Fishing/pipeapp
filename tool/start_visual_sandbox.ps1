param(
  [switch]$SeedOnly,
  [switch]$SkipSeed
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Require-Command([string]$Name, [string]$InstallHint) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name was not found. $InstallHint"
  }
}

function Test-LocalPort([int]$Port) {
  return $null -ne (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

Write-Step 'Checking Pipe Buyer sandbox branch'
$branch = (git branch --show-current).Trim()
if ($branch -ne 'pipebuyer-premium-ui') {
  throw "This launcher is for pipebuyer-premium-ui. Current branch: $branch"
}

Require-Command 'git' 'Install Git for Windows, then reopen PowerShell.'
Require-Command 'node' 'Install Node.js 22 or newer, then reopen PowerShell.'
Require-Command 'npm' 'npm is installed with Node.js.'
Require-Command 'firebase' 'Install the Firebase CLI with: npm install -g firebase-tools'
Require-Command 'flutter' 'Install Flutter and ensure flutter\bin is on PATH.'

$functionsDir = Join-Path $repoRoot 'firebase\functions'
$adminModule = Join-Path $functionsDir 'node_modules\firebase-admin'
if (-not (Test-Path $adminModule)) {
  Write-Step 'Installing local Firebase Functions dependencies'
  & npm --prefix $functionsDir install
  if ($LASTEXITCODE -ne 0) {
    throw 'npm install for firebase/functions failed.'
  }
}

$requiredPorts = @(9099, 8080, 5001, 9199)
$needsEmulators = $false
foreach ($port in $requiredPorts) {
  if (-not (Test-LocalPort $port)) {
    $needsEmulators = $true
    break
  }
}

if ($needsEmulators) {
  Write-Step 'Starting isolated Firebase emulators in a second PowerShell window'
  $safeRoot = $repoRoot.Replace("'", "''")
  $emulatorCommand = "Set-Location -LiteralPath '$safeRoot'; firebase emulators:start --only auth,firestore,functions,storage --project flutter-flow-pipe"
  Start-Process powershell.exe -ArgumentList @('-NoExit', '-Command', $emulatorCommand)

  Write-Host 'Waiting for Auth, Firestore, Functions and Storage emulators...' -ForegroundColor DarkGray
  $deadline = (Get-Date).AddMinutes(2)
  do {
    Start-Sleep -Seconds 2
    $ready = $true
    foreach ($port in $requiredPorts) {
      if (-not (Test-LocalPort $port)) {
        $ready = $false
        break
      }
    }
  } while (-not $ready -and (Get-Date) -lt $deadline)

  if (-not $ready) {
    throw 'Firebase emulators did not become ready within two minutes. Check the second PowerShell window for the first Firebase/Java/Node error.'
  }
} else {
  Write-Step 'Using Firebase emulators already running on this PC'
}

$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:9199'
$env:GCLOUD_PROJECT = 'flutter-flow-pipe'

if (-not $SkipSeed) {
  Write-Step 'Loading realistic Pipe Buyer demo accounts and marketplace records'
  & node (Join-Path $functionsDir 'scripts\seed_visual_sandbox.js')
  if ($LASTEXITCODE -ne 0) {
    throw 'Visual sandbox seed failed. Check the error above.'
  }
}

Write-Host ''
Write-Host 'Visual sandbox credentials' -ForegroundColor Yellow
Write-Host '  Buyer:   buyer.visual@pipebuyer.test' -ForegroundColor White
Write-Host '  Seller:  seller.visual@pipebuyer.test' -ForegroundColor White
Write-Host '  Carrier: carrier.visual@pipebuyer.test' -ForegroundColor White
Write-Host '  Password for all three: PipeBuyerDemo!2026' -ForegroundColor White
Write-Host ''
Write-Host 'Firebase Emulator UI: http://127.0.0.1:4000' -ForegroundColor DarkGray
Write-Host 'All seeded records are local-only and do not touch production.' -ForegroundColor Green

if ($SeedOnly) {
  Write-Step 'Seed complete'
  exit 0
}

Write-Step 'Launching Pipe Buyer in Chrome using local Firebase data'
& flutter run -d chrome --dart-define=PIPE_ENV=local
