param(
  [switch]$SeedOnly,
  [switch]$SkipSeed,
  [switch]$SkipSmokeTest
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
  return $null -ne (
    Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
      Select-Object -First 1
  )
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$projectId = 'flutter-flow-pipe'
$authPort = 19099
$firestorePort = 18080
$functionsPort = 15001
$storagePort = 19199
$uiPort = 14000
$hubPort = 4400
$sandboxConfig = Join-Path $repoRoot 'firebase.sandbox.json'

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
Require-Command 'java' 'Install a Java JDK 11 or newer, then reopen PowerShell.'
if (-not (Test-Path $sandboxConfig)) {
  throw 'firebase.sandbox.json is missing. Pull the latest pipebuyer-premium-ui branch.'
}

$firebaseGlobal = Get-Command 'firebase' -ErrorAction SilentlyContinue
if ($firebaseGlobal) {
  $firebaseInvocation = 'firebase'
  Write-Step 'Using installed Firebase CLI'
  & firebase --version
} else {
  $firebaseInvocation = 'npx --yes firebase-tools'
  Write-Step 'Using Firebase CLI through npx'
  & npx --yes firebase-tools --version
}
if ($LASTEXITCODE -ne 0) {
  throw 'Firebase CLI could not start.'
}

$functionsDir = Join-Path $repoRoot 'firebase\functions'
$agentFunctionsDir = Join-Path $repoRoot 'firebase\agent-functions'
foreach ($directory in @($functionsDir, $agentFunctionsDir)) {
  $adminModule = Join-Path $directory 'node_modules\firebase-admin'
  if (-not (Test-Path $adminModule)) {
    Write-Step "Installing Firebase function dependencies in $directory"
    & npm --prefix $directory install
    if ($LASTEXITCODE -ne 0) {
      throw "npm install failed in $directory"
    }
  }
}

$requiredSandboxPorts = @($authPort, $firestorePort, $functionsPort, $storagePort, $uiPort)
$runningSandboxPorts = @($requiredSandboxPorts | Where-Object { Test-LocalPort $_ })
$allSandboxServicesRunning = $runningSandboxPorts.Count -eq $requiredSandboxPorts.Count

if (-not $allSandboxServicesRunning) {
  if (Test-LocalPort $hubPort) {
    throw @"
Another Firebase Emulator Suite is already running on hub port $hubPort.
This is usually an earlier PipeBuyer sandbox. In that emulator window press Ctrl+C, wait for it to stop, then run this command again.
Your separate service on port 8080 does NOT need to be stopped; the full PipeBuyer sandbox uses Firestore port $firestorePort.
"@
  }

  if ($runningSandboxPorts.Count -gt 0) {
    throw "A partial PipeBuyer sandbox is already listening on: $($runningSandboxPorts -join ', '). Close that old sandbox window and retry."
  }

  Write-Step 'Starting the FULL Pipe Buyer integration emulator suite'
  Write-Host "Auth      : 127.0.0.1:$authPort" -ForegroundColor DarkGray
  Write-Host "Firestore : 127.0.0.1:$firestorePort (port 8080 is intentionally untouched)" -ForegroundColor DarkGray
  Write-Host "Functions : 127.0.0.1:$functionsPort" -ForegroundColor DarkGray
  Write-Host "Storage   : 127.0.0.1:$storagePort" -ForegroundColor DarkGray
  Write-Host "UI        : http://127.0.0.1:$uiPort" -ForegroundColor DarkGray

  $safeRoot = $repoRoot.Replace("'", "''")
  $emulatorCommand = "Set-Location -LiteralPath '$safeRoot'; `$env:PIPE_ENFORCE_APP_CHECK='false'; $firebaseInvocation emulators:start --only auth,firestore,functions,storage --config firebase.sandbox.json --project $projectId"
  Start-Process powershell.exe -ArgumentList @('-NoExit', '-Command', $emulatorCommand)

  Write-Host 'Waiting for Auth, Firestore, Functions, Storage and Emulator UI...' -ForegroundColor DarkGray
  $deadline = (Get-Date).AddMinutes(5)
  do {
    Start-Sleep -Seconds 2
    $ready = $true
    foreach ($port in $requiredSandboxPorts) {
      if (-not (Test-LocalPort $port)) {
        $ready = $false
        break
      }
    }
  } while (-not $ready -and (Get-Date) -lt $deadline)

  if (-not $ready) {
    throw 'The full Firebase sandbox did not become ready within five minutes. Read the SECOND PowerShell window and send the first red error.'
  }
} else {
  Write-Step 'Using the full Pipe Buyer integration sandbox already running'
}

$env:FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:$authPort"
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:$firestorePort"
$env:FIREBASE_STORAGE_EMULATOR_HOST = "127.0.0.1:$storagePort"
$env:FUNCTIONS_EMULATOR_HOST = "127.0.0.1:$functionsPort"
$env:GCLOUD_PROJECT = $projectId
$env:GOOGLE_CLOUD_PROJECT = $projectId

if (-not $SkipSeed) {
  Write-Step 'Loading full Pipe Buyer integration test data'
  & node (Join-Path $functionsDir 'scripts\seed_visual_sandbox.js')
  if ($LASTEXITCODE -ne 0) {
    throw 'Pipe Buyer integration seed failed. Check the error above.'
  }

  & node (Join-Path $functionsDir 'scripts\seed_live_test_memberships.js')
  if ($LASTEXITCODE -ne 0) {
    throw 'VIP/standard membership seed failed. Check the error above.'
  }

  & node (Join-Path $functionsDir 'scripts\seed_live_test_dispatch_access.js')
  if ($LASTEXITCODE -ne 0) {
    throw 'Dispatch carrier-access seed failed. Check the error above.'
  }
}

if (-not $SkipSmokeTest) {
  Write-Step 'Verifying Auth + Functions + Dispatch rules before opening Flutter'
  $signInBody = @{
    email = 'buyer.visual@pipebuyer.test'
    password = 'PipeBuyerDemo!2026'
    returnSecureToken = $true
  } | ConvertTo-Json
  $signIn = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$authPort/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=pipebuyer-local" `
    -ContentType 'application/json' `
    -Body $signInBody

  if ($signIn.localId -ne 'visual-buyer' -or [string]::IsNullOrWhiteSpace($signIn.idToken)) {
    throw 'The VIP buyer fixture could not authenticate against the Pipe Buyer Auth emulator.'
  }

  $standardBody = @{
    email = 'standard.visual@pipebuyer.test'
    password = 'PipeBuyerDemo!2026'
    returnSecureToken = $true
  } | ConvertTo-Json
  $standardSignIn = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$authPort/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=pipebuyer-local" `
    -ContentType 'application/json' `
    -Body $standardBody
  if ($standardSignIn.localId -ne 'visual-standard') {
    throw 'The standard-user fixture could not authenticate against the Pipe Buyer Auth emulator.'
  }

  $carrierBody = @{
    email = 'carrier.visual@pipebuyer.test'
    password = 'PipeBuyerDemo!2026'
    returnSecureToken = $true
  } | ConvertTo-Json
  $carrierSignIn = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$authPort/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=pipebuyer-local" `
    -ContentType 'application/json' `
    -Body $carrierBody
  if ($carrierSignIn.localId -ne 'visual-carrier' -or [string]::IsNullOrWhiteSpace($carrierSignIn.idToken)) {
    throw 'The Dispatch carrier fixture could not authenticate against the Pipe Buyer Auth emulator.'
  }

  $headers = @{ Authorization = "Bearer $($signIn.idToken)" }
  $callable = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$functionsPort/$projectId/us-central1/syncAccountVerification" `
    -Headers $headers `
    -ContentType 'application/json' `
    -Body '{"data":{}}'

  if ($null -eq $callable.result) {
    throw 'The Functions emulator answered, but syncAccountVerification did not return a callable result.'
  }

  $carrierHeaders = @{ Authorization = "Bearer $($carrierSignIn.idToken)" }
  $firestoreBase = "http://127.0.0.1:$firestorePort/v1/projects/$projectId/databases/(default)/documents"
  $carrierDocument = Invoke-RestMethod `
    -Method Get `
    -Uri "$firestoreBase/dispatch_carriers/visual-carrier" `
    -Headers $carrierHeaders
  if ([string]::IsNullOrWhiteSpace($carrierDocument.name)) {
    throw 'Carrier-authenticated Firestore access could not read the Dispatch carrier profile.'
  }

  $dispatchJobs = Invoke-RestMethod `
    -Method Get `
    -Uri "$firestoreBase/dispatch_jobs?pageSize=2" `
    -Headers $carrierHeaders
  if ($null -eq $dispatchJobs) {
    throw 'Carrier-authenticated Firestore access could not read the Dispatch job board.'
  }

  Write-Host 'VIP + Standard + Carrier Auth verification passed.' -ForegroundColor Green
  Write-Host 'Carrier-authenticated Firestore rules can read the Dispatch profile and job board.' -ForegroundColor Green
}

Write-Host ''
Write-Host 'FULL Pipe Buyer integration sandbox' -ForegroundColor Yellow
Write-Host "  Emulator UI: http://127.0.0.1:$uiPort" -ForegroundColor White
Write-Host "  VIP Buyer:    buyer.visual@pipebuyer.test" -ForegroundColor White
Write-Host "  Standard:     standard.visual@pipebuyer.test" -ForegroundColor White
Write-Host "  Seller:       seller.visual@pipebuyer.test" -ForegroundColor White
Write-Host "  Carrier:      carrier.visual@pipebuyer.test  (approved Dispatch provider)" -ForegroundColor White
Write-Host '  Password:     PipeBuyerDemo!2026' -ForegroundColor White
Write-Host ''
Write-Host 'Marketplace, Wanted, Offers, Auctions, Messaging, Dispatch and VIP early access are enabled locally.' -ForegroundColor Green
Write-Host 'Use the Standard account to verify locked 24-hour teaser cards; use the VIP Buyer to verify immediate access.' -ForegroundColor Green
Write-Host 'The Carrier fixture is approved, available for hire and has a test Dispatch entitlement.' -ForegroundColor Green
Write-Host 'Production customer data is not read or written by this sandbox.' -ForegroundColor Green
Write-Host 'External payment-processor calls require separate TEST-mode provider credentials; never use production payment secrets here.' -ForegroundColor Yellow

if ($SeedOnly) {
  Write-Step 'Integration seed and smoke test complete'
  exit 0
}

Write-Step 'Launching Pipe Buyer Chrome integration test'
& flutter run -d chrome `
  --dart-define=PIPE_ENV=local `
  --dart-define=PIPE_ENABLE_DISPATCH=true `
  --dart-define=PIPE_ENABLE_AUCTIONS=true `
  --dart-define=PIPE_FIREBASE_EMULATOR_HOST=127.0.0.1 `
  --dart-define=PIPE_FIREBASE_AUTH_EMULATOR_PORT=$authPort `
  --dart-define=PIPE_FIREBASE_FIRESTORE_EMULATOR_PORT=$firestorePort `
  --dart-define=PIPE_FIREBASE_FUNCTIONS_EMULATOR_PORT=$functionsPort `
  --dart-define=PIPE_FIREBASE_STORAGE_EMULATOR_PORT=$storagePort
