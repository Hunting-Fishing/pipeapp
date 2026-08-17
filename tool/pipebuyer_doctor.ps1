$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\pipebuyer_context.ps1"

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repoRoot = $script:PipeBuyerRepoRoot
$expectedBranch = 'design/formal-beautification-foundation'

Write-Step 'Checking Pipe Buyer repository and branch'
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.git'))) {
  throw "STOP: $repoRoot is not the Pipe Buyer Git repository root."
}
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'pubspec.yaml'))) {
  throw 'STOP: pubspec.yaml is missing from the repository root.'
}
$currentBranch = Assert-PipeBuyerFormalBranch -ExpectedBranch $expectedBranch
Write-Host "Repository: $repoRoot" -ForegroundColor Green
Write-Host "Branch:     $currentBranch" -ForegroundColor Green
Write-Host "Process CWD: $([Environment]::CurrentDirectory)" -ForegroundColor Green
if ([Environment]::CurrentDirectory -ne $repoRoot) {
  throw 'STOP: PowerShell and .NET process working directories are not synchronized.'
}

Write-Step 'Checking pinned Node runtime'
$expectedNodeMajor = ((Get-Content -LiteralPath (Join-Path $repoRoot '.nvmrc') -Raw).Trim())
$nodeVersion = ((node --version | Out-String).Trim())
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($nodeVersion)) {
  throw 'STOP: Node.js is unavailable.'
}
$actualNodeMajor = $nodeVersion.TrimStart('v').Split('.')[0]
if ($actualNodeMajor -ne $expectedNodeMajor) {
  throw "STOP: Pipe Buyer requires Node major $expectedNodeMajor from .nvmrc. Current Node is $nodeVersion"
}
Write-Host "Node:       $nodeVersion" -ForegroundColor Green

Write-Step 'Checking Flutter and Dart availability'
$flutterVersion = ((flutter --version --machine | ConvertFrom-Json).frameworkVersion)
if ([string]::IsNullOrWhiteSpace($flutterVersion)) {
  throw 'STOP: Flutter is unavailable.'
}
$dartVersionOutput = ((dart --version 2>&1 | Out-String).Trim())
Write-Host "Flutter:    $flutterVersion" -ForegroundColor Green
Write-Host "Dart:       $dartVersionOutput" -ForegroundColor Green

Write-Step 'Checking protected line-ending policy'
$requiredAttributes = @(
  '*.dart text eol=lf',
  '*.js text eol=lf',
  '*.mjs text eol=lf',
  '*.json text eol=lf',
  '*.md text eol=lf',
  '*.yml text eol=lf',
  '*.yaml text eol=lf',
  '*.ps1 text eol=crlf'
)
$attributes = Get-Content -LiteralPath (Join-Path $repoRoot '.gitattributes') -Raw
foreach ($required in $requiredAttributes) {
  if (-not $attributes.Contains($required)) {
    throw "STOP: .gitattributes is missing required rule: $required"
  }
}
Write-Host '.gitattributes policy: PASS' -ForegroundColor Green

Write-Step 'Checking critical JavaScript/MJS tool syntax'
$criticalNodeTools = @(
  'tool/apply_dispatch_quote_planner_source_map_units.mjs',
  'tool/repair_dispatch_quote_planner_matchall.mjs',
  'firebase/functions/scripts/verify_formal_demo_auth_passwords.mjs',
  'firebase/functions/scripts/ensure_formal_demo_auth.js'
)
foreach ($tool in $criticalNodeTools) {
  $absoluteTool = Join-Path $repoRoot $tool
  if (Test-Path -LiteralPath $absoluteTool) {
    node --check $absoluteTool
    if ($LASTEXITCODE -ne 0) {
      throw "STOP: Node syntax failed for $tool"
    }
  }
}
Write-Host 'Critical Node tooling syntax: PASS' -ForegroundColor Green

Write-Step 'Checking all Pipe Buyer PowerShell tool controls before execution'
$toolRoot = Join-Path $repoRoot 'tool'
$powerShellTools = @(Get-ChildItem -LiteralPath $toolRoot -Filter '*.ps1' -File -Recurse)
if ($powerShellTools.Count -eq 0) {
  throw 'STOP: No Pipe Buyer PowerShell control scripts were found under tool/.'
}
$foreignControlPattern = '(?mi)^\s*(elif|fi|then)\b'
foreach ($toolFile in $powerShellTools) {
  $tokens = $null
  $parseErrors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $toolFile.FullName,
    [ref]$tokens,
    [ref]$parseErrors
  )
  if ($parseErrors.Count -gt 0) {
    $details = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
    throw "STOP: PowerShell parse failed for $($toolFile.FullName): $details"
  }

  $raw = Get-Content -LiteralPath $toolFile.FullName -Raw
  $foreignMatch = [regex]::Match($raw, $foreignControlPattern)
  if ($foreignMatch.Success) {
    throw "STOP: PowerShell control contains a foreign shell keyword '$($foreignMatch.Groups[1].Value)' in $($toolFile.FullName)."
  }

  $badCommands = @(
    $ast.FindAll({
      param($node)
      if ($node -isnot [System.Management.Automation.Language.CommandAst]) { return $false }
      $name = $node.GetCommandName()
      return $name -in @('elif', 'fi')
    }, $true)
  )
  if ($badCommands.Count -gt 0) {
    $name = $badCommands[0].GetCommandName()
    throw "STOP: PowerShell control would execute invalid shell command '$name' in $($toolFile.FullName)."
  }
}
Write-Host "PowerShell tool controls checked: $($powerShellTools.Count)" -ForegroundColor Green
Write-Host 'PowerShell parse/runtime-token preflight: PASS' -ForegroundColor Green

Write-Step 'Reporting local working-tree state without changing it'
$status = @(git status --short)
if ($status.Count -eq 0) {
  Write-Host 'Working tree: clean' -ForegroundColor Green
} else {
  Write-Host "Working tree: $($status.Count) changed/untracked entries" -ForegroundColor Yellow
  Write-Host 'This is allowed, but guarded repairs must use exact-file backups and must never run reset --hard, restore ., clean, or branch switching.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER DOCTOR PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Correct repository: PASS' -ForegroundColor Green
Write-Host 'Formal development branch: PASS' -ForegroundColor Green
Write-Host '.NET/PowerShell working directory sync: PASS' -ForegroundColor Green
Write-Host 'Pinned Node major: PASS' -ForegroundColor Green
Write-Host 'Flutter/Dart available: PASS' -ForegroundColor Green
Write-Host 'Line-ending controls: PASS' -ForegroundColor Green
Write-Host 'Critical Node syntax: PASS' -ForegroundColor Green
Write-Host 'All tool PowerShell parse/runtime-token checks: PASS' -ForegroundColor Green
