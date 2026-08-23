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

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
foreach ($name in @('git', 'node', 'dart', 'flutter')) { Need $name }

if ((git branch --show-current).Trim() -ne 'design/formal-beautification-foundation') {
  throw 'Run this only on design/formal-beautification-foundation.'
}

Write-Host 'Timed Buying trust + participant experience: v3-hardened-local-layout-20260816' -ForegroundColor Green
Write-Host 'Recorded root cause: old migration assumed exact indentation around the LIVE status badge.' -ForegroundColor DarkGray
Write-Host 'This runner uses structural anchors and exact TEMP rollback.' -ForegroundColor DarkGray

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
$patchV2 = Join-Path $PSScriptRoot 'apply_timed_buying_trust_v2.mjs'
$patchV3 = Join-Path $PSScriptRoot 'apply_timed_buying_trust_v3.mjs'
$patchV4 = Join-Path $PSScriptRoot 'apply_timed_buying_trust_v4.mjs'

foreach ($path in @($page,$engagement,$trust,$presentation,$trustTest,$engagementTest,$presentationTest,$compactTest,$backend,$seed,$patchV2,$patchV3,$patchV4)) {
  if (-not (Test-Path -LiteralPath $path)) { throw "Missing required file: $path" }
}

$source = Get-Content -LiteralPath $page -Raw
if (-not $source.Contains('Review & submit timed offer')) { throw 'Verified Timed Buying offer flow is missing.' }
if (-not $source.Contains('Asset overview')) { throw 'Verified compact Asset Overview is missing.' }

Step 'Current local work before hardened trust pass'
git status --short

$backupRoot = Join-Path $env:TEMP "pipebuyer-trust-v3-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$backups = @{}
foreach ($file in @($page,$backend,$seed)) {
  $copy = Join-Path $backupRoot ((Split-Path -Leaf $file) + '.' + $backups.Count + '.bak')
  Copy-Item -LiteralPath $file -Destination $copy -Force
  $backups[$file] = $copy
}
Write-Host "Exact pre-run backups: $backupRoot" -ForegroundColor DarkGray

$complete = $false
try {
  Step 'Syntax-checking hardened migration helpers'
  foreach ($script in @($patchV2,$patchV3,$patchV4)) {
    & node --check $script
    if ($LASTEXITCODE -ne 0) { throw "Node syntax check failed: $script" }
  }

  Step 'Applying Timed Buying viewer trust and participation enhancements'
  & node $patchV4
  if ($LASTEXITCODE -ne 0) { throw 'Hardened Timed Buying migration failed.' }

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
  Write-Host 'All Timed Buying trust markers are present.' -ForegroundColor Green

  Step 'Formatting changed Timed Buying surfaces'
  & dart format $page $engagement $trust $trustTest $engagementTest
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed.' }

  Step 'Analyzing Timed Buying and compact Asset Overview'
  & dart analyze $page $engagement $trust $presentation $trustTest $engagementTest $presentationTest $compactTest
  if ($LASTEXITCODE -ne 0) { throw 'dart analyze failed.' }

  Step 'Running Timed Buying trust contract'
  & flutter test $trustTest --dart-define=PIPE_ENV=formal-beautification-local --dart-define=PIPE_RELEASE_SHA=timed-buying-trust-v3
  if ($LASTEXITCODE -ne 0) { throw 'Trust widget test failed.' }

  Step 'Running urgency and viewer-position regression contract'
  & flutter test $engagementTest --dart-define=PIPE_ENV=formal-beautification-local --dart-define=PIPE_RELEASE_SHA=timed-buying-trust-v3
  if ($LASTEXITCODE -ne 0) { throw 'Engagement widget test failed.' }

  Step 'Running Timed Buying action regression contract'
  & flutter test $presentationTest --dart-define=PIPE_ENV=formal-beautification-local --dart-define=PIPE_RELEASE_SHA=timed-buying-trust-v3
  if ($LASTEXITCODE -ne 0) { throw 'Presentation widget test failed.' }

  Step 'Rechecking compact professional Asset Overview'
  & flutter test $compactTest --dart-define=PIPE_ENV=formal-beautification-local --dart-define=PIPE_RELEASE_SHA=timed-buying-trust-v3
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

  Step 'TIMED BUYING TRUST V3 PASSED'
  Write-Host 'Gold participation border: enabled for viewers who submitted a timed offer.' -ForegroundColor Green
  Write-Host 'Card status: leading/outbid/offer-ahead state enabled.' -ForegroundColor Green
  Write-Host 'Activity rows: You + verified participant identity + leading/outbid state enabled.' -ForegroundColor Green
  Write-Host 'Detail summary: your top offer, lead, amount behind and offers ahead enabled.' -ForegroundColor Green
  Write-Host 'Common mojibake characters on the Timed Buying page are repaired by this pass.' -ForegroundColor Green
  git diff --stat
  git status --short
  $complete = $true
}
finally {
  if (-not $complete) {
    Write-Host "`nTrust v3 failed; restoring exact pre-run product/backend files." -ForegroundColor Red
    foreach ($entry in $backups.GetEnumerator()) {
      if (Test-Path -LiteralPath $entry.Value) {
        Copy-Item -LiteralPath $entry.Value -Destination $entry.Key -Force
      }
    }
    Write-Host "Backup retained: $backupRoot" -ForegroundColor Yellow
  }
  else {
    Remove-Item -LiteralPath $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
