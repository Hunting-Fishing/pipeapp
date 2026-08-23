param(
  [switch]$EnableDispatch,
  [switch]$EnablePaidFeatures
)

$ErrorActionPreference = 'Stop'

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$Operation,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )
  Write-Host "`n==> $Operation" -ForegroundColor Cyan
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Operation failed with exit code $LASTEXITCODE."
  }
}

function Get-ProductionVariable {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [switch]$Optional
  )
  $value = & gh variable get $Name --env production --repo Hunting-Fishing/pipeapp 2>$null
  if ($LASTEXITCODE -ne 0) {
    if ($Optional) { return '' }
    throw "Required GitHub production variable $Name is missing."
  }
  return (($value | Out-String).Trim())
}

function Assert-ProductionValue {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [AllowEmptyString()][string]$Value,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [switch]$Optional
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    if ($Optional) { return }
    throw "Production variable $Name is empty."
  }

  if ($Value -match '[\r\n\t]') {
    throw "Production variable $Name contains a newline/tab. Re-copy only the public key/value and update the GitHub production variable."
  }

  if ($Value -notmatch $Pattern) {
    throw "Production variable $Name contains unexpected characters. Re-copy only the intended public value before deploying."
  }
}

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $workspace

$generatedFiles = @(
  'linux/flutter/generated_plugin_registrant.cc',
  'linux/flutter/generated_plugin_registrant.h',
  'linux/flutter/generated_plugins.cmake',
  'macos/Flutter/GeneratedPluginRegistrant.swift',
  'windows/flutter/generated_plugin_registrant.cc',
  'windows/flutter/generated_plugin_registrant.h',
  'windows/flutter/generated_plugins.cmake'
)

Write-Host 'PIPE BUYER LOCAL PRODUCTION DEPLOY' -ForegroundColor Yellow
Write-Host 'GitHub Actions are not used by this script.' -ForegroundColor DarkGray
Write-Host "Dispatch build approval: $($EnableDispatch.IsPresent)" -ForegroundColor DarkGray
Write-Host "Paid features build approval: $($EnablePaidFeatures.IsPresent)" -ForegroundColor DarkGray

$branch = (git branch --show-current).Trim()
if ($branch -ne 'main') {
  throw "Production deploy must run from main. Current branch: $branch"
}

foreach ($generated in $generatedFiles) {
  git restore -- $generated 2>$null
}

$dirty = @(git status --porcelain)
if ($dirty.Count -gt 0) {
  Write-Host 'Working tree must be clean before production deploy:' -ForegroundColor Red
  $dirty | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  throw 'Commit/stash unrelated changes before deploying production.'
}

Invoke-Checked 'Synchronizing exact main branch' {
  git pull --ff-only origin main
}

$releaseSha = (git rev-parse HEAD).Trim()
$originMain = (git rev-parse origin/main).Trim()
if ($releaseSha -ne $originMain) {
  throw "Local main ($releaseSha) does not match origin/main ($originMain)."
}
Write-Host "Release SHA: $releaseSha" -ForegroundColor Green

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw 'GitHub CLI (gh) is required to load the configured production public variables.'
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter is required on PATH.'
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw 'Node.js is required on PATH.'
}
if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
  throw 'npx is required on PATH.'
}

$env:PIPE_ENV = 'production'
$env:PIPE_RELEASE_SHA = $releaseSha
$env:PIPE_ENABLE_DISPATCH = if ($EnableDispatch.IsPresent) { 'true' } else { 'false' }
$env:PIPE_ENABLE_PAID_FEATURES = if ($EnablePaidFeatures.IsPresent) { 'true' } else { 'false' }
$env:PIPE_FIREBASE_API_KEY = Get-ProductionVariable 'PIPE_FIREBASE_API_KEY'
$env:PIPE_FIREBASE_AUTH_DOMAIN = Get-ProductionVariable 'PIPE_FIREBASE_AUTH_DOMAIN'
$env:PIPE_FIREBASE_PROJECT_ID = Get-ProductionVariable 'PIPE_FIREBASE_PROJECT_ID'
$env:PIPE_FIREBASE_STORAGE_BUCKET = Get-ProductionVariable 'PIPE_FIREBASE_STORAGE_BUCKET'
$env:PIPE_FIREBASE_MESSAGING_SENDER_ID = Get-ProductionVariable 'PIPE_FIREBASE_MESSAGING_SENDER_ID'
$env:PIPE_FIREBASE_WEB_APP_ID = Get-ProductionVariable 'PIPE_FIREBASE_WEB_APP_ID'
$env:PIPE_FIREBASE_MEASUREMENT_ID = Get-ProductionVariable 'PIPE_FIREBASE_MEASUREMENT_ID' -Optional
$env:PIPE_PUBLIC_SUPPORT_EMAIL = Get-ProductionVariable 'PIPE_PUBLIC_SUPPORT_EMAIL'
$env:PIPE_APP_CHECK_WEB_RECAPTCHA_KEY = Get-ProductionVariable 'PIPE_APP_CHECK_WEB_RECAPTCHA_KEY'
$env:PIPE_FIREBASE_WEB_PUSH_VAPID_KEY = Get-ProductionVariable 'PIPE_FIREBASE_WEB_PUSH_VAPID_KEY'
$env:PIPE_APP_CHECK_MODE = 'enforce'
$env:PIPE_APP_CHECK_REQUIRED = 'true'
$env:PIPE_ENFORCE_APP_CHECK = 'true'
$env:PIPE_REMOTE_DIAGNOSTICS_ENABLED = 'true'
$env:FUNCTIONS_DISCOVERY_TIMEOUT = '30000'

if ($env:PIPE_FIREBASE_PROJECT_ID -ne 'flutter-flow-pipe') {
  throw "SAFETY STOP: production project must be flutter-flow-pipe, received $env:PIPE_FIREBASE_PROJECT_ID"
}
if ($env:PIPE_FIREBASE_AUTH_DOMAIN -ne 'pipebuyer.com') {
  Write-Host "Production auth domain is $env:PIPE_FIREBASE_AUTH_DOMAIN (expected intentional custom domain pipebuyer.com)." -ForegroundColor Yellow
}

Assert-ProductionValue 'PIPE_FIREBASE_API_KEY' $env:PIPE_FIREBASE_API_KEY '^[A-Za-z0-9_-]+$'
Assert-ProductionValue 'PIPE_FIREBASE_AUTH_DOMAIN' $env:PIPE_FIREBASE_AUTH_DOMAIN '^[A-Za-z0-9.-]+$'
Assert-ProductionValue 'PIPE_FIREBASE_PROJECT_ID' $env:PIPE_FIREBASE_PROJECT_ID '^[A-Za-z0-9-]+$'
Assert-ProductionValue 'PIPE_FIREBASE_STORAGE_BUCKET' $env:PIPE_FIREBASE_STORAGE_BUCKET '^[A-Za-z0-9.-]+$'
Assert-ProductionValue 'PIPE_FIREBASE_MESSAGING_SENDER_ID' $env:PIPE_FIREBASE_MESSAGING_SENDER_ID '^\d+$'
Assert-ProductionValue 'PIPE_FIREBASE_WEB_APP_ID' $env:PIPE_FIREBASE_WEB_APP_ID '^[A-Za-z0-9:_-]+$'
Assert-ProductionValue 'PIPE_FIREBASE_MEASUREMENT_ID' $env:PIPE_FIREBASE_MEASUREMENT_ID '^[A-Za-z0-9_-]+$' -Optional
Assert-ProductionValue 'PIPE_PUBLIC_SUPPORT_EMAIL' $env:PIPE_PUBLIC_SUPPORT_EMAIL '^[^\s@]+@[^\s@]+$'
Assert-ProductionValue 'PIPE_APP_CHECK_WEB_RECAPTCHA_KEY' $env:PIPE_APP_CHECK_WEB_RECAPTCHA_KEY '^[A-Za-z0-9_-]+$'
Assert-ProductionValue 'PIPE_FIREBASE_WEB_PUSH_VAPID_KEY' $env:PIPE_FIREBASE_WEB_PUSH_VAPID_KEY '^[A-Za-z0-9_-]+$'

Write-Host 'Production configuration loaded and validated.' -ForegroundColor Green
Write-Host "Firebase project: $env:PIPE_FIREBASE_PROJECT_ID"
Write-Host "Auth domain: $env:PIPE_FIREBASE_AUTH_DOMAIN"
Write-Host 'App Check: enforce'
Write-Host "Dispatch build approval: $env:PIPE_ENABLE_DISPATCH"
Write-Host "Paid features build approval: $env:PIPE_ENABLE_PAID_FEATURES"
Write-Host 'Web Push: configured'

Invoke-Checked 'Running complete local release verification' {
  powershell -ExecutionPolicy Bypass -File .\tool\verify.ps1
}

foreach ($generated in $generatedFiles) {
  git restore -- $generated 2>$null
}
if (@(git status --porcelain).Count -gt 0) {
  git status --short
  throw 'Release verification left unexpected repository changes.'
}

New-Item -ItemType Directory -Force '.\build' | Out-Null

Write-Host "`n==> Recording current production inventory" -ForegroundColor Cyan
& npx --yes firebase-tools@15.25.0 functions:list --project flutter-flow-pipe --json | Set-Content '.\build\predeploy-functions.json'
if ($LASTEXITCODE -ne 0) { throw 'Could not read current production Functions inventory.' }

$workerPath = 'web/firebase-messaging-sw.js'
$definesPath = Join-Path $env:TEMP ("pipebuyer-production-defines-{0}.json" -f ([guid]::NewGuid().ToString('N')))

$defineMap = [ordered]@{
  PIPE_ENV = 'production'
  PIPE_RELEASE_SHA = $releaseSha
  PIPE_ENABLE_DISPATCH = $env:PIPE_ENABLE_DISPATCH
  PIPE_ENABLE_PAID_FEATURES = $env:PIPE_ENABLE_PAID_FEATURES
  PIPE_FIREBASE_API_KEY = $env:PIPE_FIREBASE_API_KEY
  PIPE_FIREBASE_AUTH_DOMAIN = $env:PIPE_FIREBASE_AUTH_DOMAIN
  PIPE_FIREBASE_PROJECT_ID = $env:PIPE_FIREBASE_PROJECT_ID
  PIPE_FIREBASE_STORAGE_BUCKET = $env:PIPE_FIREBASE_STORAGE_BUCKET
  PIPE_FIREBASE_MESSAGING_SENDER_ID = $env:PIPE_FIREBASE_MESSAGING_SENDER_ID
  PIPE_FIREBASE_WEB_APP_ID = $env:PIPE_FIREBASE_WEB_APP_ID
  PIPE_FIREBASE_MEASUREMENT_ID = $env:PIPE_FIREBASE_MEASUREMENT_ID
  PIPE_PUBLIC_SUPPORT_EMAIL = $env:PIPE_PUBLIC_SUPPORT_EMAIL
  PIPE_APP_CHECK_WEB_RECAPTCHA_KEY = $env:PIPE_APP_CHECK_WEB_RECAPTCHA_KEY
  PIPE_APP_CHECK_REQUIRED = 'true'
  PIPE_FIREBASE_WEB_PUSH_VAPID_KEY = $env:PIPE_FIREBASE_WEB_PUSH_VAPID_KEY
  PIPE_REMOTE_DIAGNOSTICS_ENABLED = 'true'
}

$json = $defineMap | ConvertTo-Json -Compress
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($definesPath, $json, $utf8NoBom)

try {
  Invoke-Checked 'Configuring production Firebase Messaging worker' {
    node tool/configure_firebase_messaging_worker.mjs `
      --output $workerPath `
      --api-key $env:PIPE_FIREBASE_API_KEY `
      --auth-domain $env:PIPE_FIREBASE_AUTH_DOMAIN `
      --project-id $env:PIPE_FIREBASE_PROJECT_ID `
      --storage-bucket $env:PIPE_FIREBASE_STORAGE_BUCKET `
      --messaging-sender-id $env:PIPE_FIREBASE_MESSAGING_SENDER_ID `
      --app-id $env:PIPE_FIREBASE_WEB_APP_ID
  }

  Invoke-Checked 'Building exact production Flutter web release' {
    flutter build web --release "--dart-define-from-file=$definesPath"
  }
}
finally {
  git restore -- $workerPath 2>$null
  Remove-Item -LiteralPath $definesPath -Force -ErrorAction SilentlyContinue
}

foreach ($generated in $generatedFiles) {
  git restore -- $generated 2>$null
}
if (@(git status --porcelain).Count -gt 0) {
  git status --short
  throw 'Production build modified tracked repository source.'
}

if (-not (Test-Path '.\build\web\index.html')) {
  throw 'Production build/web/index.html is missing.'
}
if (-not (Test-Path '.\build\web\firebase-messaging-sw.js')) {
  throw 'Production Firebase Messaging worker is missing from build/web.'
}

Invoke-Checked 'Recording exact production release manifest' {
  node tool/release_manifest.mjs `
    --environment production `
    --release-sha $releaseSha `
    --firebase-project flutter-flow-pipe `
    --app-check-mode enforce `
    --dispatch-build-enabled $env:PIPE_ENABLE_DISPATCH `
    --paid-features-build-enabled $env:PIPE_ENABLE_PAID_FEATURES `
    --output build/release-manifest.json `
    --require-web
}

Write-Host "`n======================================================" -ForegroundColor Yellow
Write-Host ' DEPLOYING PIPE BUYER TO PRODUCTION' -ForegroundColor Yellow
Write-Host ' Project: flutter-flow-pipe' -ForegroundColor Yellow
Write-Host " SHA: $releaseSha" -ForegroundColor Yellow
Write-Host ' App Check: enforce' -ForegroundColor Yellow
Write-Host " Dispatch build: $env:PIPE_ENABLE_DISPATCH" -ForegroundColor Yellow
Write-Host " Paid features build: $env:PIPE_ENABLE_PAID_FEATURES" -ForegroundColor Yellow
Write-Host '======================================================' -ForegroundColor Yellow

Invoke-Checked 'Deploying Firebase Auth, Hosting, Functions, Firestore and Storage' {
  npx --yes firebase-tools@15.25.0 deploy `
    --project flutter-flow-pipe `
    --config firebase.json `
    --only 'auth,hosting,functions,firestore:rules,firestore:indexes,storage' `
    --message "Pipe Buyer production $releaseSha local verified release" `
    --non-interactive
}

Invoke-Checked 'Reading deployed Functions inventory' {
  npx --yes firebase-tools@15.25.0 functions:list `
    --project flutter-flow-pipe `
    --json | Set-Content '.\build\deployed-functions.json'
}

Invoke-Checked 'Proving marketplace Function parity' {
  node tool/function_parity.mjs `
    --manifest build/release-manifest.json `
    --inventory build/deployed-functions.json `
    --project flutter-flow-pipe `
    --codebase marketplace `
    --output build/function-parity-marketplace.json
}

Invoke-Checked 'Proving agent Function parity' {
  node tool/function_parity.mjs `
    --manifest build/release-manifest.json `
    --inventory build/deployed-functions.json `
    --project flutter-flow-pipe `
    --codebase functions `
    --output build/function-parity-agent.json
}

Write-Host "`n==> Checking www.pipebuyer.com" -ForegroundColor Cyan
$response = Invoke-WebRequest 'https://www.pipebuyer.com' -UseBasicParsing
if ($response.StatusCode -ne 200) {
  throw "www.pipebuyer.com returned HTTP $($response.StatusCode)."
}
foreach ($path in @('/about', '/privacy', '/terms')) {
  $publicUrl = "https://www.pipebuyer.com$path"
  $publicResponse = Invoke-WebRequest $publicUrl -UseBasicParsing
  if ($publicResponse.StatusCode -ne 200 -or $publicResponse.Content -notmatch 'Pipe Buyer') {
    throw "Public release check failed for $publicUrl."
  }
}

Write-Host ''
Write-Host '======================================================' -ForegroundColor Green
Write-Host ' PIPE BUYER PRODUCTION DEPLOYMENT COMPLETE' -ForegroundColor Green
Write-Host '======================================================' -ForegroundColor Green
Write-Host "Release SHA: $releaseSha" -ForegroundColor Green
Write-Host "Dispatch build approval: $env:PIPE_ENABLE_DISPATCH" -ForegroundColor Green
Write-Host "Paid features build approval: $env:PIPE_ENABLE_PAID_FEATURES" -ForegroundColor Green
Write-Host 'Site: https://www.pipebuyer.com' -ForegroundColor Green
Write-Host 'Hard-refresh the browser with Ctrl+Shift+R before visual review.' -ForegroundColor Green
