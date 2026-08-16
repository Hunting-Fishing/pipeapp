$ErrorActionPreference = 'Stop'

function Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Need([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found."
  }
}

function Port([int]$Number) {
  return $null -ne (
    Get-NetTCPConnection -State Listen -LocalPort $Number -ErrorAction SilentlyContinue |
      Select-Object -First 1
  )
}

function FileHash([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Restore-IfChanged {
  param(
    [Parameter(Mandatory=$true)][string]$Target,
    [Parameter(Mandatory=$true)][string]$Backup,
    [Parameter(Mandatory=$true)][string]$OriginalHash
  )

  $currentHash = FileHash $Target
  if ($currentHash -eq $OriginalHash) {
    Write-Host "Rollback skip (unchanged): $Target" -ForegroundColor DarkGray
    return $true
  }

  $bytes = [System.IO.File]::ReadAllBytes($Backup)
  for ($attempt = 1; $attempt -le 12; $attempt++) {
    try {
      [System.IO.File]::WriteAllBytes($Target, $bytes)
      if ((FileHash $Target) -eq $OriginalHash) {
        Write-Host "Rollback restored: $Target" -ForegroundColor Yellow
        return $true
      }
    }
    catch [System.IO.IOException] {
      if ($attempt -lt 12) {
        Start-Sleep -Milliseconds 350
        continue
      }
      Write-Warning "Could not restore $Target after $attempt attempts. Exact backup remains at $Backup"
      return $false
    }
  }

  Write-Warning "Rollback hash check failed for $Target. Exact backup remains at $Backup"
  return $false
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
foreach ($name in @('git', 'node', 'dart', 'flutter')) { Need $name }

if ((git branch --show-current).Trim() -ne 'design/formal-beautification-foundation') {
  throw 'Run this only on design/formal-beautification-foundation.'
}

Write-Host 'Timed Buying trust + participant experience: v5-analyzer-clean-20260816' -ForegroundColor Green
Write-Host 'Recorded fix #1: exact-indentation card anchors replaced by structural migration anchors.' -ForegroundColor DarkGray
Write-Host 'Recorded fix #2: legacy Dart interpolation is parser-sanitized before Node imports it.' -ForegroundColor DarkGray
Write-Host 'Recorded fix #3: analyzer cleanup removes unused viewer state, string-composition infos, and private-type API lint.' -ForegroundColor DarkGray
Write-Host 'Recorded fix #4: every file formatted or migrated by this runner is hash-backed up and retry-restored only if changed.' -ForegroundColor DarkGray
Write-Host 'Canonical runner from this point: apply_timed_buying_trust_v5.ps1' -ForegroundColor DarkGray

$page = Join-Path $repoRoot 'lib\marketplace\marketplace_auctions_page.dart'
$engagement = Join-Path $repoRoot 'lib\marketplace\marketplace_timed_buying_engagement.dart'
$trust = Join-Path $repoRoot 'lib\marketplace\marketplace_timed_buying_trust.dart'
$presentation = Join-Path $repoRoot 'lib\marketplace\marketplace_timed_buying_presentation.dart'
$trustTest = Join-Path $repoRoot 'test\marketplace_timed_buying_trust_test.dart'
$engagementTest = Join-Path $repoRoot 'test\marketplace_timed_buying_engagement_test.dart'
$presentationTest = Join-Path $repoRoot 'test\marketplace_timed_buying_presentation_test.dart'
$compactTest = Join-Path $repoRoot 'test\marketplace_listing_specs_compact_test.dart'
$backend = Join-Path $repoRoot 'firebase\functions\marketplace_commands.js'
$seed = Join-Path $repoRoot 'firebase\functions\scripts\seed_visual_sandbox.js'
$loadCheck = Join-Path $repoRoot 'firebase\functions\load_check.js'
$patchV3 = Join-Path $PSScriptRoot 'apply_timed_buying_trust_v3.mjs'
$patchV4 = Join-Path $PSScriptRoot 'apply_timed_buying_trust_v4.mjs'
$analyzerFix = Join-Path $PSScriptRoot 'fix_timed_buying_analyzer_v5.mjs'

foreach ($path in @(
  $page,$engagement,$trust,$presentation,$trustTest,$engagementTest,
  $presentationTest,$compactTest,$backend,$seed,$patchV3,$patchV4,$analyzerFix
)) {
  if (-not (Test-Path -LiteralPath $path)) { throw "Missing required file: $path" }
}

$source = Get-Content -LiteralPath $page -Raw
if (-not $source.Contains('Review & submit timed offer')) { throw 'Verified Timed Buying offer flow is missing.' }
if (-not $source.Contains('Asset overview')) { throw 'Verified compact Asset Overview is missing.' }

Step 'Current local work before analyzer-clean trust pass'
git status --short

$backupRoot = Join-Path $env:TEMP "pipebuyer-trust-v5-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$tracked = @{}
$protectedFiles = @($page,$backend,$seed,$engagement,$trust,$trustTest,$engagementTest)
foreach ($file in $protectedFiles) {
  $backup = Join-Path $backupRoot ((Split-Path -Leaf $file) + '.' + $tracked.Count + '.bak')
  Copy-Item -LiteralPath $file -Destination $backup -Force
  $tracked[$file] = @{
    Backup = $backup
    Hash = FileHash $file
  }
}
Write-Host "Exact pre-run backups: $backupRoot" -ForegroundColor DarkGray

$complete = $false
try {
  Step 'Syntax-checking parser-safe migration and analyzer cleanup entrypoints'
  foreach ($script in @($patchV3,$patchV4,$analyzerFix)) {
    & node --check $script
    if ($LASTEXITCODE -ne 0) { throw "Node syntax check failed: $script" }
  }
  Write-Host 'Migration entrypoints passed Node syntax checks.' -ForegroundColor Green

  Step 'Applying Timed Buying viewer trust and participation enhancements'
  & node $patchV4
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying structural trust migration failed.' }

  Step 'Normalizing generated Dart for zero-warning analyzer contract'
  & node $analyzerFix
  if ($LASTEXITCODE -ne 0) { throw 'Timed Buying analyzer cleanup failed.' }

  Step 'Verifying required UI markers before format/analyze'
  $after = Get-Content -LiteralPath $page -Raw
  foreach ($marker in @(
    'TimedBuyingTrustFrame(',
    'TimedBuyingParticipationBadge(',
    'TimedBuyingOfferActivityHeader(',
    'TimedBuyingTrustStrip()',
    '_TimedBuyingBuyerTrustPosition(',
    'TimedBuyingAttentionStrip('
  )) {
    if (-not $after.Contains($marker)) { throw "Missing marker: $marker" }
  }
  if ($after.Contains('final viewerLeading =')) { throw 'Unused viewerLeading marker remained after cleanup.' }
  Write-Host 'All Timed Buying trust markers are present and obsolete viewer state is absent.' -ForegroundColor Green

  Step 'Formatting only files intentionally touched by this trust pass'
  & dart format $page $engagement $trust $trustTest $engagementTest
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed.' }

  Step 'Analyzing Timed Buying and compact Asset Overview with zero-issue gate'
  & dart analyze $page $engagement $trust $presentation $trustTest $engagementTest $presentationTest $compactTest
  if ($LASTEXITCODE -ne 0) { throw 'dart analyze failed.' }

  Step 'Running Timed Buying trust contract'
  & flutter test $trustTest --dart-define=PIPE_ENV=formal-beautification-local --dart-define=PIPE_RELEASE_SHA=timed-buying-trust-v5
  if ($LASTEXITCODE -ne 0) { throw 'Trust widget test failed.' }

  Step 'Running urgency and viewer-position regression contract'
  & flutter test $engagementTest --dart-define=PIPE_ENV=formal-beautification-local --dart-define=PIPE_RELEASE_SHA=timed-buying-trust-v5
  if ($LASTEXITCODE -ne 0) { throw 'Engagement widget test failed.' }

  Step 'Running Timed Buying action regression contract'
  & flutter test $presentationTest --dart-define=PIPE_ENV=formal-beautification-local --dart-define=PIPE_RELEASE_SHA=timed-buying-trust-v5
  if ($LASTEXITCODE -ne 0) { throw 'Presentation widget test failed.' }

  Step 'Rechecking compact professional Asset Overview'
  & flutter test $compactTest --dart-define=PIPE_ENV=formal-beautification-local --dart-define=PIPE_RELEASE_SHA=timed-buying-trust-v5
  if ($LASTEXITCODE -ne 0) { throw 'Compact Asset Overview regression test failed.' }

  Step 'Checking server-side participant identity changes'
  & node --check $backend
  if ($LASTEXITCODE -ne 0) { throw 'marketplace_commands.js syntax check failed.' }
  & node --check $seed
  if ($LASTEXITCODE -ne 0) { throw 'seed_visual_sandbox.js syntax check failed.' }
  if (Test-Path -LiteralPath $loadCheck) {
    & node $loadCheck
    if ($LASTEXITCODE -ne 0) { throw 'Functions load check failed.' }
  }

  if ((Port 19099) -and (Port 18080)) {
    Step 'Reseeding authenticated multi-participant Timed Buying fixture'
    $env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:19099'
    $env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:18080'
    $env:GCLOUD_PROJECT = 'flutter-flow-pipe'
    $env:GOOGLE_CLOUD_PROJECT = 'flutter-flow-pipe'
    & node $seed
    if ($LASTEXITCODE -ne 0) { throw 'Sandbox reseed failed.' }
  }
  else {
    Write-Host 'Auth/Firestore emulator not both running; reseed skipped.' -ForegroundColor Yellow
  }

  Step 'TIMED BUYING TRUST V5 PASSED'
  Write-Host 'Gold participation border: enabled for viewers who submitted a timed offer.' -ForegroundColor Green
  Write-Host 'Card status: YOU’RE LEADING / OUTBID + offer-ahead position enabled.' -ForegroundColor Green
  Write-Host 'Activity rows: You + verified participant identity + leading/outbid state enabled.' -ForegroundColor Green
  Write-Host 'Detail summary: your top offer, lead, amount behind, offers ahead, and next minimum enabled.' -ForegroundColor Green
  Write-Host 'Authenticated-member trust strip enabled; no anonymous timed-offer presentation.' -ForegroundColor Green
  Write-Host 'Analyzer gate passed with no warnings/infos/errors.' -ForegroundColor Green
  git diff --stat
  git status --short
  $complete = $true
}
finally {
  if (-not $complete) {
    Write-Host "`nTrust v5 failed; checking every protected/format-target file before rollback." -ForegroundColor Red
    $rollbackOkay = $true
    foreach ($entry in $tracked.GetEnumerator()) {
      $ok = Restore-IfChanged -Target $entry.Key -Backup $entry.Value.Backup -OriginalHash $entry.Value.Hash
      if (-not $ok) { $rollbackOkay = $false }
    }
    if ($rollbackOkay) {
      Write-Host 'All protected files are back at their exact pre-run SHA256 hashes.' -ForegroundColor Yellow
    }
    else {
      Write-Warning "One or more files could not be restored automatically. Exact backups are retained at $backupRoot"
    }
  }
  else {
    Remove-Item -LiteralPath $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
