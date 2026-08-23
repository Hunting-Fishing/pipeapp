$ErrorActionPreference = 'Stop'

function Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Need([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found."
  }
}

function FileHash([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Restore-Bytes([string]$Target, [string]$Backup, [string]$ExpectedHash) {
  if ((FileHash $Target) -eq $ExpectedHash) { return $true }
  $bytes = [System.IO.File]::ReadAllBytes($Backup)
  for ($attempt = 1; $attempt -le 12; $attempt++) {
    try {
      [System.IO.File]::WriteAllBytes($Target, $bytes)
      if ((FileHash $Target) -eq $ExpectedHash) { return $true }
    }
    catch [System.IO.IOException] {
      if ($attempt -lt 12) { Start-Sleep -Milliseconds 350 }
    }
  }
  return $false
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
foreach ($name in @('git', 'node', 'dart', 'flutter')) { Need $name }

if ((git branch --show-current).Trim() -ne 'design/formal-beautification-foundation') {
  throw 'Run this only on design/formal-beautification-foundation.'
}

Write-Host 'Timed Buying trust finalizer: v5.1-strict-lint-20260816' -ForegroundColor Green
Write-Host 'Recorded final quality fix: dart analyze returns success for info-level lints unless --fatal-infos is used.' -ForegroundColor DarkGray
Write-Host 'This finalizer adds the missing public widget key and enforces fatal infos + fatal warnings.' -ForegroundColor DarkGray

$page = Join-Path $repoRoot 'lib\marketplace\marketplace_auctions_page.dart'
$trust = Join-Path $repoRoot 'lib\marketplace\marketplace_timed_buying_trust.dart'
$engagement = Join-Path $repoRoot 'lib\marketplace\marketplace_timed_buying_engagement.dart'
$presentation = Join-Path $repoRoot 'lib\marketplace\marketplace_timed_buying_presentation.dart'
$trustTest = Join-Path $repoRoot 'test\marketplace_timed_buying_trust_test.dart'
$engagementTest = Join-Path $repoRoot 'test\marketplace_timed_buying_engagement_test.dart'
$presentationTest = Join-Path $repoRoot 'test\marketplace_timed_buying_presentation_test.dart'
$compactTest = Join-Path $repoRoot 'test\marketplace_listing_specs_compact_test.dart'
$fixer = Join-Path $PSScriptRoot 'fix_timed_buying_analyzer_v5.mjs'

foreach ($path in @($page,$trust,$engagement,$presentation,$trustTest,$engagementTest,$presentationTest,$compactTest,$fixer)) {
  if (-not (Test-Path -LiteralPath $path)) { throw "Missing required file: $path" }
}

$requiredMarkers = @(
  'TimedBuyingTrustFrame(',
  'TimedBuyingParticipationBadge(',
  'TimedBuyingOfferActivityHeader(',
  'TimedBuyingTrustStrip()',
  '_TimedBuyingBuyerTrustPosition(',
  'TimedBuyingAttentionStrip('
)
$pageSource = Get-Content -LiteralPath $page -Raw
foreach ($marker in $requiredMarkers) {
  if (-not $pageSource.Contains($marker)) {
    throw "Timed Buying V5 enhancement is not fully applied; missing marker: $marker"
  }
}

$generatedFlutterFiles = @(
  'linux/flutter/generated_plugin_registrant.cc',
  'linux/flutter/generated_plugin_registrant.h',
  'linux/flutter/generated_plugins.cmake',
  'macos/Flutter/GeneratedPluginRegistrant.swift',
  'windows/flutter/generated_plugin_registrant.cc',
  'windows/flutter/generated_plugin_registrant.h',
  'windows/flutter/generated_plugins.cmake'
)

$backupRoot = Join-Path $env:TEMP "pipebuyer-trust-v5-final-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$tracked = @{}
foreach ($file in @($page,$trust)) {
  $backup = Join-Path $backupRoot ((Split-Path -Leaf $file) + '.' + $tracked.Count + '.bak')
  Copy-Item -LiteralPath $file -Destination $backup -Force
  $tracked[$file] = @{ Backup = $backup; Hash = FileHash $file }
}

$complete = $false
try {
  Step 'Applying final analyzer cleanup'
  & node --check $fixer
  if ($LASTEXITCODE -ne 0) { throw 'Analyzer cleanup helper syntax check failed.' }
  & node $fixer
  if ($LASTEXITCODE -ne 0) { throw 'Analyzer cleanup helper failed.' }

  Step 'Formatting the two finalizer targets'
  & dart format $page $trust
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed.' }

  Step 'Enforcing strict zero-issue analyzer gate'
  & dart analyze --fatal-infos --fatal-warnings $page $trust $engagement $presentation $trustTest $engagementTest $presentationTest $compactTest
  if ($LASTEXITCODE -ne 0) { throw 'Strict dart analyze failed.' }

  Step 'Running all Timed Buying + compact Asset Overview regression tests together'
  & flutter test $trustTest $engagementTest $presentationTest $compactTest `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=timed-buying-trust-v5-final
  if ($LASTEXITCODE -ne 0) { throw 'Final Timed Buying regression test bundle failed.' }

  Step 'Removing Flutter-generated working-tree noise only'
  & git restore -- $generatedFlutterFiles 2>$null

  Step 'TIMED BUYING TRUST V5 FINALIZED'
  Write-Host 'Strict analyzer: no infos, warnings, or errors.' -ForegroundColor Green
  Write-Host 'All Timed Buying trust/urgency/action and compact Asset Overview tests passed.' -ForegroundColor Green
  Write-Host 'Generated Flutter registrant noise restored without touching marketplace product files.' -ForegroundColor Green
  $complete = $true
}
finally {
  if (-not $complete) {
    Write-Host "`nFinalizer failed; restoring only page/trust files changed by this finalizer." -ForegroundColor Red
    $okay = $true
    foreach ($entry in $tracked.GetEnumerator()) {
      if (-not (Restore-Bytes -Target $entry.Key -Backup $entry.Value.Backup -ExpectedHash $entry.Value.Hash)) {
        $okay = $false
      }
    }
    if ($okay) {
      Write-Host 'Finalizer targets restored to exact pre-run hashes.' -ForegroundColor Yellow
    }
    else {
      Write-Warning "Automatic restore was incomplete. Exact backups remain at $backupRoot"
    }
  }
  else {
    Remove-Item -LiteralPath $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
