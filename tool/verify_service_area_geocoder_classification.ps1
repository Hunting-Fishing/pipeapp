$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$fixer = Join-Path $PSScriptRoot 'fix_service_area_geocoder_classification.ps1'
$openAddress = Join-Path $script:PipeBuyerRepoRoot 'lib\marketplace\open_address_autocomplete.dart'
$serviceArea = Join-Path $script:PipeBuyerRepoRoot 'lib\marketplace\marketplace_service_area.dart'
$classificationTest = Join-Path $script:PipeBuyerRepoRoot 'test\service_area_geocoder_classification_test.dart'
$geographyTest = Join-Path $script:PipeBuyerRepoRoot 'test\marketplace_dispatch_geography_test.dart'
$persistenceTest = Join-Path $script:PipeBuyerRepoRoot 'test\marketplace_dispatch_service_area_persistence_contract_test.dart'
$profileTest = Join-Path $script:PipeBuyerRepoRoot 'test\marketplace_dispatch_company_profile_test.dart'
$navigationTest = Join-Path $script:PipeBuyerRepoRoot 'test\marketplace_dispatch_navigation_test.dart'
$authTest = Join-Path $script:PipeBuyerRepoRoot 'test\dispatch_auth_reactivity_contract_test.dart'

foreach ($required in @(
  $fixer,
  $openAddress,
  $serviceArea,
  $classificationTest,
  $geographyTest,
  $persistenceTest,
  $profileTest,
  $navigationTest,
  $authTest
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "STOP: Required verification file is missing: $required"
  }
}

Write-Step 'Applying the guarded town/region geocoder correction'
& powershell -ExecutionPolicy Bypass -File $fixer
if ($LASTEXITCODE -ne 0) {
  throw 'Service-area geocoder correction failed. Stop at the first error above.'
}

Write-Step 'Formatting only the affected Dart source and regression test'
& dart format $openAddress $serviceArea $classificationTest
if ($LASTEXITCODE -ne 0) {
  throw 'Service-area geocoder formatter failed.'
}

Write-Step 'Confirming formatter stability'
& dart format --output=none --set-exit-if-changed $openAddress $serviceArea $classificationTest
if ($LASTEXITCODE -ne 0) {
  throw 'Service-area geocoder files are not formatter stable.'
}

Write-Step 'Running strict analyzer on the affected source and regression test'
foreach ($target in @($openAddress, $serviceArea, $classificationTest)) {
  & dart analyze --fatal-infos --fatal-warnings $target
  if ($LASTEXITCODE -ne 0) {
    throw "Strict analyzer failed for $target"
  }
}

Write-Step 'Running the new town-versus-region classification regression suite'
& flutter test $classificationTest
if ($LASTEXITCODE -ne 0) {
  throw 'Town/region classification regression test failed.'
}

Write-Step 'Re-running Dispatch service-area privacy and persistence regressions'
foreach ($target in @($geographyTest, $persistenceTest, $profileTest)) {
  & flutter test $target
  if ($LASTEXITCODE -ne 0) {
    throw "Dispatch Phase 3 service-area regression failed for $target"
  }
}

Write-Step 'Re-running Dispatch navigation and auth regressions'
foreach ($target in @($navigationTest, $authTest)) {
  & flutter test $target
  if ($LASTEXITCODE -ne 0) {
    throw "Dispatch regression failed for $target"
  }
}

Write-Step 'Checking source-level safety contracts'
$openText = Get-Content -LiteralPath $openAddress -Raw
foreach ($marker in @(
  'final String district;',
  'OpenAddressSearchType.settlement =>',
  '_settlementPlaceTypes.contains(item.placeType.toLowerCase())',
  'dedupeOpenAddressResults',
  'openAddressFromPhotonFeature'
)) {
  if (-not $openText.Contains($marker)) {
    throw "Open-address classification contract missing: $marker"
  }
}

$serviceText = Get-Content -LiteralPath $serviceArea -Raw
foreach ($marker in @(
  'selectServiceAreaBoundaryCandidate',
  "'city': requestedName",
  "'countrycodes': address.countryCode.toLowerCase()",
  'adminLevel.isNotEmpty && adminLevel !=',
  'a surrounding district will not be substituted',
  'it was not added. Choose another region result with a mapped boundary',
  '_regionName(address)'
)) {
  if (-not $serviceText.Contains($marker)) {
    throw "Service-area boundary safety contract missing: $marker"
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'SERVICE AREA TOWN + REGION MAP CLASSIFICATION PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Town search excludes district/county results: PASS' -ForegroundColor Green
Write-Host 'Photon town identity no longer becomes parent district: PASS' -ForegroundColor Green
Write-Host 'Duplicate node/relation town results prefer relation: PASS' -ForegroundColor Green
Write-Host 'Canadian town boundary rejects broader regional-district polygon: PASS' -ForegroundColor Green
Write-Host 'Town boundary lookup uses structured city/state/country search: PASS' -ForegroundColor Green
Write-Host 'Region selection preserves selected region identity: PASS' -ForegroundColor Green
Write-Host 'Region without polygon is not silently saved as a pin: PASS' -ForegroundColor Green
Write-Host 'Dispatch service-area regressions: PASS' -ForegroundColor Green
Write-Host 'Dispatch navigation/auth regressions: PASS' -ForegroundColor Green
Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
Write-Host ''
Write-Host 'Browser acceptance is still required for Fort St. John, Dawson Creek, Peace River Regional District, and British Columbia before Phase 3 service-area credit is awarded.' -ForegroundColor Yellow
