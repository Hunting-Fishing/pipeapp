$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

Write-Step 'Running Pipe Buyer environment doctor'
powershell -ExecutionPolicy Bypass -File '.\tool\pipebuyer_doctor.ps1'
if ($LASTEXITCODE -ne 0) {
  throw 'Pipe Buyer doctor failed.'
}

$tracked = @(git diff --name-only --diff-filter=ACMR HEAD)
$untracked = @(git ls-files --others --exclude-standard)
$changed = @($tracked + $untracked | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

Write-Step 'Checking changed Node generator syntax'
$nodeFiles = @($changed | Where-Object { $_ -match '\.(mjs|cjs|js)$' })
foreach ($file in $nodeFiles) {
  if (Test-Path -LiteralPath $file) {
    node --check $file
    if ($LASTEXITCODE -ne 0) {
      throw "Node syntax failed: $file"
    }
  }
}
Write-Host "Node files checked: $($nodeFiles.Count)" -ForegroundColor Green

Write-Step 'Checking changed PowerShell syntax'
$powerShellFiles = @($changed | Where-Object { $_ -match '\.ps1$' })
foreach ($file in $powerShellFiles) {
  if (-not (Test-Path -LiteralPath $file)) { continue }
  $tokens = $null
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path -LiteralPath $file),
    [ref]$tokens,
    [ref]$parseErrors
  ) | Out-Null
  if ($parseErrors.Count -gt 0) {
    $details = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
    throw "PowerShell syntax failed for $file`: $details"
  }
}
Write-Host "PowerShell files checked: $($powerShellFiles.Count)" -ForegroundColor Green

Write-Step 'Checking changed Dart formatting and analyzer health'
$dartFiles = @($changed | Where-Object { $_ -match '\.dart$' -and (Test-Path -LiteralPath $_) })
if ($dartFiles.Count -gt 0) {
  dart format --output=none --set-exit-if-changed @dartFiles
  if ($LASTEXITCODE -ne 0) {
    throw 'Changed Dart files are not formatter-stable. Run dart format on the reported files.'
  }

  dart analyze --fatal-infos --fatal-warnings @dartFiles
  if ($LASTEXITCODE -ne 0) {
    throw 'Strict analyzer failed for changed Dart files.'
  }
} else {
  Write-Host 'No changed Dart files to analyze.' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER FORMAL FAST GATE PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host "Changed files inspected: $($changed.Count)" -ForegroundColor Green
Write-Host "Dart files:              $($dartFiles.Count)" -ForegroundColor Green
Write-Host "Node files:              $($nodeFiles.Count)" -ForegroundColor Green
Write-Host "PowerShell files:        $($powerShellFiles.Count)" -ForegroundColor Green
