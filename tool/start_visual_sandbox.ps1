param(
  [switch]$SeedOnly,
  [switch]$SkipSeed,
  [switch]$WithFunctions
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
Require-Command 'node' 'Install Node.js 20 or 22, then reopen PowerShell.'
Require-Command 'npm' 'npm is installed with Node.js.'
Require-Command 'npx' 'npx is installed with Node.js/npm.'
Require-Command 'flutter' 'Install Flutter and ensure flutter\bin is on PATH.'
Require-Command 'java' 'Install a Java JDK 11 or newer, then reopen PowerShell. The Firestore/Storage emulators require Java.'

$firebaseGlobal = Get-Command 'firebase' -ErrorAction SilentlyContinue
if ($firebaseGlobal) {
  $firebaseCommand = 'firebase'
  Write-Step 'Using installed Firebase CLI'
  & firebase --version
  if ($LASTEXITCODE -ne 0) {
    throw 'The installed Firebase CLI could not run.'
  }
} else {
  $firebaseCommand = 'npx --yes firebase-tools'
  Write-Step 'Firebase CLI is not installed globally; using npx firebase-tools for this sandbox'
  & npx --yes firebase-tools --version
  if ($LASTEXITCODE -ne 0) {
    throw 'Firebase CLI could not be started with npx. Run npm install -g firebase-tools, then retry.'
  }
}

$functionsDir = Join-Path $repoRoot 'firebase\functions'
$adminModule = Join-Path $functionsDir 'node_modules\firebase-admin'
if (-not (Test-Path $adminModule)) {
  Write-Step 'Installing the Firebase Admin dependency used by the local data seeder'
  & npm --prefix $functionsDir install
  if ($LASTEXITCODE -ne 0) {
    throw 'npm install for firebase/functions failed.'
  }
}

$emulatorNames = 'auth,firestore,storage'
$requiredPorts = @(9099, 8080, 9199)
if ($WithFunctions) {
  $agentFunctionsDir = Join-Path $repoRoot 'firebase\agent-functions'
  $agentAdminModule = Join-Path $agentFunctionsDir 'node_modules\firebase-admin'
  if (-not (Test-Path $agentAdminModule)) {
    Write-Step 'Installing the optional administrative Functions dependencies'
    & npm --prefix $agentFunctionsDir install
    if ($LASTEXITCODE -ne 0) {
      throw 'npm install for firebase/agent-functions failed.'
    }
  }
  $emulatorNames = 'auth,firestore,functions,storage'
  $requiredPorts += 5001
}

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
  $emulatorCommand = "Set-Location -LiteralPath '$safeRoot'; $firebaseCommand emulators:start --only $emulatorNames --project flutter-flow-pipe"
  Start-Process powershell.exe -ArgumentList @('-NoExit', '-Command', $emulatorCommand)

  Write-Host "Waiting for $emulatorNames emulators..." -ForegroundColor DarkGray
  $deadline = (Get-Date).AddMinutes(3)
  $ready = $false
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
    throw 'Firebase emulators did not become ready within three minutes. Check the second PowerShell window for the first Firebase/Java/Node error.'
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
if (-not $WithFunctions) {
  Write-Host 'Function-backed write actions are intentionally disabled in this visual-only run.' -ForegroundColor DarkGray
  Write-Host 'Use -WithFunctions later when you want to test sending offers/messages and Dispatch commands.' -ForegroundColor DarkGray
}

if ($SeedOnly) {
  Write-Step 'Seed complete'
  exit 0
}

Write-Step 'Launching Pipe Buyer in Chrome using local Firebase data'
& flutter run -d chrome --dart-define=PIPE_ENV=local
