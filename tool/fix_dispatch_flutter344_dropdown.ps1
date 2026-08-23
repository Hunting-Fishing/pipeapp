$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\pipebuyer_context.ps1"

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$branch = Assert-PipeBuyerFormalBranch
Write-Host "Repository: $script:PipeBuyerRepoRoot" -ForegroundColor Green
Write-Host "Branch:     $branch" -ForegroundColor Green

$sourcePath = Join-Path $script:PipeBuyerRepoRoot 'lib\marketplace\marketplace_dispatch_dashboard.dart'
$verifierPath = Join-Path $script:PipeBuyerRepoRoot 'tool\verify_dispatch_quote_planner_source_map_units.ps1'

if (-not (Test-Path -LiteralPath $sourcePath)) {
  throw "STOP: Dispatch dashboard source is missing: $sourcePath"
}
if (-not (Test-Path -LiteralPath $verifierPath)) {
  throw "STOP: Dispatch quote verifier is missing: $verifierPath"
}

Write-Step 'Backing up the Dispatch dashboard before the Flutter 3.44 migration'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $script:PipeBuyerRepoRoot "_local_backups\dispatch-flutter344-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $backupDir 'marketplace_dispatch_dashboard.dart')
Write-Host "Backup: $backupDir" -ForegroundColor Green

Write-Step 'Applying the exact Flutter 3.44 DropdownButtonFormField migration'
$text = [System.IO.File]::ReadAllText($sourcePath)

$targets = @(
  @{
    Label = 'Marketplace listing dropdown'
    OldPattern = '(?m)(return DropdownButtonFormField<String>\(\r?\n\s*)value: selectedValue,'
    NewPattern = '(?m)(return DropdownButtonFormField<String>\(\r?\n\s*)initialValue: selectedValue,'
    Replacement = '$1initialValue: selectedValue,'
  },
  @{
    Label = 'Requested unit type dropdown'
    OldPattern = '(?m)(final type = DropdownButtonFormField<String>\(\r?\n\s*)value: requirement\.typeCode,'
    NewPattern = '(?m)(final type = DropdownButtonFormField<String>\(\r?\n\s*)initialValue: requirement\.typeCode,'
    Replacement = '$1initialValue: requirement.typeCode,'
  }
)

foreach ($target in $targets) {
  $oldRegex = [regex]::new($target.OldPattern)
  $newRegex = [regex]::new($target.NewPattern)
  $oldCount = $oldRegex.Matches($text).Count
  $newCount = $newRegex.Matches($text).Count

  if ($oldCount -eq 1 -and $newCount -eq 0) {
    $text = $oldRegex.Replace($text, $target.Replacement, 1)
    Write-Host "Updated: $($target.Label)" -ForegroundColor Green
    continue
  }

  if ($oldCount -eq 0 -and $newCount -eq 1) {
    Write-Host "Already migrated: $($target.Label)" -ForegroundColor DarkGreen
    continue
  }

  throw "STOP: $($target.Label) is not in the known pre- or post-migration form. old=$oldCount new=$newCount"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($sourcePath, $text, $utf8NoBom)

Write-Step 'Formatting the Dispatch dashboard'
dart format $sourcePath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Dart formatter failed after the Flutter 3.44 migration.'
}

Write-Step 'Running the read-only Dispatch quote planner verifier'
powershell -ExecutionPolicy Bypass -File $verifierPath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Dispatch quote planner verification failed after the Flutter 3.44 migration.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH FLUTTER 3.44 DROPDOWN MIGRATION PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Absolute repository context: PASS' -ForegroundColor Green
Write-Host 'Marketplace listing dropdown: PASS' -ForegroundColor Green
Write-Host 'Requested-unit dropdown: PASS' -ForegroundColor Green
Write-Host 'Dispatch quote planner verifier: PASS' -ForegroundColor Green
