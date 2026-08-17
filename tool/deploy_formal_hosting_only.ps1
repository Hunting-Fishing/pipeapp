$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$Operation,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )
  Write-Step $Operation
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
    throw "Production variable $Name contains a newline or tab."
  }

  if ($Value -notmatch $Pattern) {
    throw "Production variable $Name contains unexpected characters."
  }
}

function Remove-WorktreeSafe {
  param([string]$RootRepo, [string]$WorktreePath)
  if ([string]::IsNullOrWhiteSpace($WorktreePath)) { return }
  if (-not (Test-Path -LiteralPath $WorktreePath)) { return }
  Push-Location $RootRepo
  try {
    git worktree remove --force $WorktreePath 2>$null
  }
  finally {
    Pop-Location
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $repoRoot

$branch = 'design/formal-beautification-foundation'
$projectId = 'flutter-flow-pipe'
$releaseMarkerName = 'pipe-release.json'
$generatedFiles = @(
  'linux/flutter/generated_plugin_registrant.cc',
  'linux/flutter/generated_plugin_registrant.h',
  'linux/flutter/generated_plugins.cmake',
  'macos/Flutter/GeneratedPluginRegistrant.swift',
  'windows/flutter/generated_plugin_registrant.cc',
  'windows/flutter/generated_plugin_registrant.h',
  'windows/flutter/generated_plugins.cmake'
)
$allowedVerifierChanges = @(
  'docs/DISPATCH_NETWORK_MASTER_PLAN.md',
  'lib/marketplace/marketplace_dispatch_company_profile.dart',
  'lib/marketplace/marketplace_dispatch_company_profile_repository.dart',
  'lib/marketplace/marketplace_dispatch_geography.dart',
  'test/marketplace_dispatch_geography_test.dart',
  'test/marketplace_dispatch_service_area_persistence_contract_test.dart'
)

Write-Host 'PIPE BUYER FORMAL BRANCH HOSTING-ONLY PRODUCTION DEPLOY' -ForegroundColor Yellow
Write-Host 'This publishes the current formal branch web application to www.pipebuyer.com.' -ForegroundColor Yellow
Write-Host 'It does NOT deploy Functions, Firestore rules/indexes, Storage rules, or Auth config.' -ForegroundColor Yellow
Write-Host 'GitHub Actions are not used by this script.' -ForegroundColor DarkGray

foreach ($command in @('git', 'gh', 'flutter', 'node', 'npx')) {
  if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "$command is required on PATH."
  }
}

Invoke-Checked 'Checking GitHub authentication' {
  gh auth status --hostname github.com
}

Invoke-Checked 'Fetching current formal branch' {
  git fetch origin $branch
}

$remoteHead = (git rev-parse "origin/$branch").Trim()
if ([string]::IsNullOrWhiteSpace($remoteHead)) {
  throw 'Could not resolve the current formal branch head.'
}
Write-Host "Formal branch head before verification: $remoteHead" -ForegroundColor DarkGray

$tempRoot = Join-Path $env:TEMP ("pipebuyer_formal_prod_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$worktreeAdded = $false

try {
  Invoke-Checked 'Creating clean temporary release worktree' {
    git worktree add --detach $tempRoot "origin/$branch"
  }
  $worktreeAdded = $true

  Push-Location $tempRoot
  try {
    $lockPath = '.\pubspec.lock'
    $packageConfigPath = '.\.dart_tool\package_config.json'

    if (-not (Test-Path -LiteralPath $lockPath)) {
      throw 'Clean release worktree is missing pubspec.lock.'
    }

    $lockHashBefore = (Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash

    Invoke-Checked 'Resolving Flutter dependencies in clean release worktree' {
      flutter pub get
    }

    if (-not (Test-Path -LiteralPath $packageConfigPath)) {
      throw 'Flutter dependency resolution completed without creating .dart_tool/package_config.json.'
    }

    $lockHashAfter = (Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash
    if ($lockHashAfter -ne $lockHashBefore) {
      throw 'SAFETY STOP: flutter pub get changed pubspec.lock in the clean release worktree. Review dependency drift before production deployment.'
    }

    Write-Host 'Flutter package configuration is ready and pubspec.lock is unchanged.' -ForegroundColor Green

    Write-Step 'Running the accepted Dispatch Phase 3 service-area gate in the clean release tree'
    powershell -ExecutionPolicy Bypass -File .\tool\verify_dispatch_phase3_service_area_map.ps1
    if ($LASTEXITCODE -ne 0) {
      throw 'Dispatch service-area release gate failed. Production hosting was not changed.'
    }

    foreach ($generated in $generatedFiles) {
      git restore -- $generated 2>$null
    }

    $changed = @(git status --porcelain | ForEach-Object {
      if ($_.Length -ge 4) { $_.Substring(3).Trim() } else { '' }
    } | Where-Object { $_ -ne '' })

    foreach ($path in $changed) {
      if ($allowedVerifierChanges -notcontains $path) {
        throw "Release verification changed an unexpected tracked file: $path"
      }
    }

    if ($changed.Count -gt 0) {
      Write-Step 'Publishing the exact verified formatter and tracker result back to GitHub'
      git add -- $allowedVerifierChanges
      git diff --cached --check
      if ($LASTEXITCODE -ne 0) {
        throw 'Verified source has whitespace or patch defects.'
      }

      git commit -m 'Record verified Dispatch service-area release state [skip ci]'
      if ($LASTEXITCODE -ne 0) {
        throw 'Could not commit the exact verified release state.'
      }

      $verifiedCommit = (git rev-parse HEAD).Trim()
      git push origin "HEAD:$branch"
      if ($LASTEXITCODE -ne 0) {
        throw 'Could not fast-forward the formal branch with the verified release state. Do not force push.'
      }
      $releaseSha = $verifiedCommit
    }
    else {
      $releaseSha = (git rev-parse HEAD).Trim()
    }

    git fetch origin $branch
    $confirmedRemote = (git rev-parse "origin/$branch").Trim()
    if ($confirmedRemote -ne $releaseSha) {
      throw "GitHub branch verification failed. Expected $releaseSha but found $confirmedRemote."
    }

    Write-Host "Verified release SHA: $releaseSha" -ForegroundColor Green

    Write-Step 'Loading production public Firebase configuration'
    $env:PIPE_ENV = 'production'
    $env:PIPE_RELEASE_SHA = $releaseSha
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

    if ($env:PIPE_FIREBASE_PROJECT_ID -ne $projectId) {
      throw "SAFETY STOP: production Firebase project must be $projectId."
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

    $workerPath = 'web/firebase-messaging-sw.js'
    $definesPath = Join-Path $env:TEMP ("pipebuyer-formal-production-defines-{0}.json" -f ([guid]::NewGuid().ToString('N')))
    $defineMap = [ordered]@{
      PIPE_ENV = 'production'
      PIPE_RELEASE_SHA = $releaseSha
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

      Invoke-Checked 'Building production Flutter web release from verified formal branch' {
        flutter build web --release "--dart-define-from-file=$definesPath"
      }
    }
    finally {
      git restore -- $workerPath 2>$null
      Remove-Item -LiteralPath $definesPath -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path '.\build\web\index.html')) {
      throw 'Production build/web/index.html is missing.'
    }
    if (-not (Test-Path '.\build\web\firebase-messaging-sw.js')) {
      throw 'Production Firebase Messaging worker is missing from build/web.'
    }

    $releaseMarker = [ordered]@{
      releaseSha = $releaseSha
      sourceBranch = $branch
      firebaseProject = $projectId
      deploymentScope = 'hosting-only'
      deployedAtUtc = [DateTime]::UtcNow.ToString('o')
    } | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText(
      (Join-Path '.\build\web' $releaseMarkerName),
      $releaseMarker,
      $utf8NoBom
    )

    Write-Host "`n======================================================" -ForegroundColor Yellow
    Write-Host ' DEPLOYING VERIFIED FORMAL WEB BUILD TO PRODUCTION' -ForegroundColor Yellow
    Write-Host " Project: $projectId" -ForegroundColor Yellow
    Write-Host " SHA: $releaseSha" -ForegroundColor Yellow
    Write-Host ' Scope: Firebase Hosting only' -ForegroundColor Yellow
    Write-Host '======================================================' -ForegroundColor Yellow

    Invoke-Checked 'Deploying Firebase Hosting only' {
      npx --yes firebase-tools@15.25.0 deploy `
        --project $projectId `
        --config firebase.json `
        --only hosting `
        --message "Pipe Buyer formal hosting $releaseSha verified local release" `
        --non-interactive
    }

    Write-Step 'Proving exact deployed release marker on www.pipebuyer.com'
    $markerUrl = "https://www.pipebuyer.com/$releaseMarkerName?sha=$releaseSha"
    $markerResponse = Invoke-RestMethod -Uri $markerUrl -Method Get
    if ($markerResponse.releaseSha -ne $releaseSha) {
      throw "Production marker mismatch. Expected $releaseSha but received $($markerResponse.releaseSha)."
    }
    if ($markerResponse.deploymentScope -ne 'hosting-only') {
      throw 'Production marker did not report hosting-only deployment scope.'
    }

    foreach ($path in @('/', '/about', '/privacy', '/terms')) {
      $url = "https://www.pipebuyer.com$path"
      $response = Invoke-WebRequest -Uri $url -UseBasicParsing
      if ($response.StatusCode -ne 200) {
        throw "Production HTTP verification failed for $url with status $($response.StatusCode)."
      }
    }

    Write-Host ''
    Write-Host '======================================================' -ForegroundColor Green
    Write-Host ' PIPE BUYER VERIFIED WEB RELEASE IS LIVE' -ForegroundColor Green
    Write-Host '======================================================' -ForegroundColor Green
    Write-Host "Release SHA: $releaseSha" -ForegroundColor Green
    Write-Host 'Site: https://www.pipebuyer.com' -ForegroundColor Green
    Write-Host 'Deployment scope: Hosting only' -ForegroundColor Green
    Write-Host 'GitHub Actions used: No' -ForegroundColor Green
    Write-Host 'Hard-refresh with Ctrl+Shift+R before browser acceptance.' -ForegroundColor Green
  }
  finally {
    Pop-Location
  }
}
finally {
  if ($worktreeAdded) {
    Remove-WorktreeSafe -RootRepo $repoRoot -WorktreePath $tempRoot
  }
}
