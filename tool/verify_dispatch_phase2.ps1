$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "Dispatch Phase 2 verification requires design/formal-beautification-foundation. Current branch: $branch"
}

$taxonomy = '.\lib\marketplace\marketplace_dispatch_service_taxonomy.dart'
$navigation = '.\lib\marketplace\marketplace_dispatch_navigation.dart'
$page = '.\lib\marketplace\marketplace_dispatch_page.dart'
$taxonomyTest = '.\test\marketplace_dispatch_service_taxonomy_test.dart'
$navigationTest = '.\test\marketplace_dispatch_navigation_test.dart'
$phase2Doc = '.\docs\DISPATCH_PHASE2_SERVICE_TAXONOMY.md'

foreach ($required in @(
  $taxonomy,
  $navigation,
  $page,
  $taxonomyTest,
  $navigationTest,
  $phase2Doc
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required Dispatch Phase 2 file is missing: $required"
  }
}

Write-Step 'Formatting Phase 2 Dart files'
& dart format $taxonomy $navigation $taxonomyTest
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch Phase 2 Dart format failed.'
}

Write-Step 'Confirming Phase 2 formatting is stable'
& dart format --output=none --set-exit-if-changed $taxonomy $navigation $taxonomyTest
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch Phase 2 formatting stability check failed.'
}

Write-Step 'Running strict analyzer for taxonomy and integrated Dispatch surfaces'
foreach ($target in @($taxonomy, $navigation, $page)) {
  Write-Host "Analyzing $target" -ForegroundColor DarkGray
  & dart analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "Dispatch Phase 2 strict analyzer failed for $target"
  }
}

Write-Step 'Running stable taxonomy contract tests'
& flutter test $taxonomyTest
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch Phase 2 taxonomy tests failed.'
}

Write-Step 'Re-running Phase 1 navigation widget contracts'
& flutter test $navigationTest
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch Phase 1 navigation regression failed during Phase 2.'
}

Write-Step 'Checking taxonomy source contracts'
$taxonomySource = Get-Content -LiteralPath $taxonomy -Raw
$navigationSource = Get-Content -LiteralPath $navigation -Raw

foreach ($requiredText in @(
  "code: 'transport_lowboy'",
  "code: 'pilot_escort_vehicle'",
  "code: 'crane_picker_truck'",
  "code: 'field_grading'",
  "code: 'field_mobile_mechanic'",
  "code: 'max_payload'",
  "code: 'rated_lift_capacity'",
  'fromLegacyLabel',
  'featuredDirectoryServices'
)) {
  if (-not $taxonomySource.Contains($requiredText)) {
    throw "Dispatch Phase 2 taxonomy source contract missing: $requiredText"
  }
}

if (-not $navigationSource.Contains('DispatchServiceTaxonomy.featuredDirectoryServices')) {
  throw 'Dispatch Directory preview is not wired to the Phase 2 taxonomy.'
}
if (-not $navigationSource.Contains('DispatchServiceTaxonomy.categories')) {
  throw 'Dispatch Directory category preview is not wired to the Phase 2 taxonomy.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH PHASE 2 ENGINEERING GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Stable service codes: PASS' -ForegroundColor Green
Write-Host 'Category and subcategory hierarchy: PASS' -ForegroundColor Green
Write-Host 'Structured capability fields: PASS' -ForegroundColor Green
Write-Host 'Canonical capacity and distance units: PASS' -ForegroundColor Green
Write-Host 'Legacy service label compatibility: PASS' -ForegroundColor Green
Write-Host 'Directory taxonomy integration: PASS' -ForegroundColor Green
Write-Host 'Taxonomy tests: PASS' -ForegroundColor Green
Write-Host 'Phase 1 navigation regression: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host ''
Write-Host 'Official Dispatch progress remains 33% until Phase 2 browser acceptance.' -ForegroundColor Yellow
Write-Host 'After browser acceptance, Phase 2 becomes 10/10 and overall becomes 41%.' -ForegroundColor Yellow
