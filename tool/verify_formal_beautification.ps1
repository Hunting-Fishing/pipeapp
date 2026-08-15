param(
  [switch]$FullGate,
  [switch]$SkipPubGet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
      throw "Required command '$Name' was not found on PATH."
    }
  }

  Require-Command 'flutter'
  Require-Command 'dart'

  Write-Host 'Pipe Buyer formal beautification verification' -ForegroundColor Cyan
  Write-Host "Repository: $repoRoot" -ForegroundColor DarkGray

  if (-not $SkipPubGet) {
    Write-Host 'Restoring Flutter dependencies...' -ForegroundColor Yellow
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
  }

  Write-Host 'Running Dart analyzer across application and tests...' -ForegroundColor Yellow
  dart analyze lib test
  if ($LASTEXITCODE -ne 0) { throw 'Dart analyzer failed.' }

  $formalTests = @(
    'test/pipe_buyer_design_barrel_test.dart',
    'test/pipe_buyer_commerce_components_test.dart',
    'test/pipe_buyer_browse_components_test.dart',
    'test/pipe_buyer_analytics_components_test.dart',
    'test/marketplace_timed_buying_presentation_test.dart',
    'test/pipe_buyer_formal_sequence_test.dart',
    'test/pipe_buyer_theme_test.dart'
  ) | Where-Object { Test-Path $_ }

  if ($formalTests.Count -eq 0) {
    throw 'No formal Pipe Buyer widget tests were found.'
  }

  Write-Host 'Running formal Pipe Buyer widget contracts...' -ForegroundColor Yellow
  foreach ($testFile in $formalTests) {
    Write-Host "  flutter test $testFile" -ForegroundColor DarkGray
    & flutter test $testFile `
      --dart-define=PIPE_ENV=formal-beautification-local `
      --dart-define=PIPE_RELEASE_SHA=local-formal-beautification
    if ($LASTEXITCODE -ne 0) {
      throw "Formal widget test failed: $testFile"
    }
  }

  if ($FullGate) {
    $fullVerifier = Join-Path $PSScriptRoot 'verify.ps1'
    if (-not (Test-Path $fullVerifier)) {
      throw 'tool/verify.ps1 is missing; full production gate cannot run.'
    }
    Write-Host 'Running the repository full verification gate...' -ForegroundColor Yellow
    & powershell -ExecutionPolicy Bypass -File $fullVerifier
    if ($LASTEXITCODE -ne 0) { throw 'Full repository verification gate failed.' }
  }

  Write-Host 'Formal beautification verification completed successfully.' -ForegroundColor Green
  Write-Host 'This is verification evidence only; it does not deploy or promote a release.' -ForegroundColor DarkGray
}
finally {
  Pop-Location
}
