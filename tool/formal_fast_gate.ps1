$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\pipebuyer_context.ps1"

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = $script:PipeBuyerRepoRoot

Write-Step 'Running Pipe Buyer environment doctor'
powershell -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'tool\pipebuyer_doctor.ps1')
if ($LASTEXITCODE -ne 0) {
  throw 'Pipe Buyer doctor failed.'
}

# Changed-file discovery is read-only. Disable worktree line-ending
# conversion for these Git inventory commands so harmless autocrlf warnings
# on stderr cannot become terminating NativeCommandError records in Windows
# PowerShell when $ErrorActionPreference is Stop.
$tracked = @(
  git `
    -c core.autocrlf=false `
    -c core.safecrlf=false `
    diff `
    --name-only `
    --diff-filter=ACMR `
    HEAD
)
if ($LASTEXITCODE -ne 0) {
  throw 'Git failed while enumerating tracked changes for the Formal Fast Gate.'
}

$untracked = @(git ls-files --others --exclude-standard)
if ($LASTEXITCODE -ne 0) {
  throw 'Git failed while enumerating untracked files for the Formal Fast Gate.'
}

$changed = @(
  $tracked + $untracked |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Sort-Object -Unique
)

Write-Step 'Checking changed Node generator syntax'
$nodeFiles = @($changed | Where-Object { $_ -match '\.(mjs|cjs|js)$' })
foreach ($file in $nodeFiles) {
  $absoluteFile = Join-Path $repoRoot $file
  if (Test-Path -LiteralPath $absoluteFile) {
    node --check $absoluteFile
    if ($LASTEXITCODE -ne 0) {
      throw "Node syntax failed: $file"
    }
  }
}
Write-Host "Node files checked: $($nodeFiles.Count)" -ForegroundColor Green

Write-Step 'Checking changed PowerShell syntax'
$powerShellFiles = @($changed | Where-Object { $_ -match '\.ps1$' })
foreach ($file in $powerShellFiles) {
  $absoluteFile = Join-Path $repoRoot $file
  if (-not (Test-Path -LiteralPath $absoluteFile)) { continue }
  $tokens = $null
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile(
    $absoluteFile,
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
$dartFiles = @(
  $changed |
    Where-Object { $_ -match '\.dart$' -and (Test-Path -LiteralPath (Join-Path $repoRoot $_)) } |
    ForEach-Object { Join-Path $repoRoot $_ }
)
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
