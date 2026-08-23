$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Test-DartFormattingEquivalent {
  param(
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  $comparisonRoot = Join-Path $env:TEMP "pipebuyer-format-equivalence-$([guid]::NewGuid().ToString('N'))"
  New-Item -ItemType Directory -Path $comparisonRoot -Force | Out-Null
  $headCopy = Join-Path $comparisonRoot 'head.dart'
  $workCopy = Join-Path $comparisonRoot 'work.dart'

  try {
    $headLines = @(& git show "HEAD:$RelativePath")
    if ($LASTEXITCODE -ne 0) {
      throw "Could not read HEAD:$RelativePath for formatter-equivalence comparison."
    }
    [IO.File]::WriteAllText($headCopy, (($headLines -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath (Join-Path $RepoRoot $RelativePath) -Destination $workCopy -Force

    & dart format $headCopy $workCopy *> $null
    if ($LASTEXITCODE -ne 0) {
      throw "dart format could not normalize $RelativePath for safe comparison."
    }

    $headFormatted = (Get-Content -LiteralPath $headCopy -Raw) -replace "`r`n", "`n"
    $workFormatted = (Get-Content -LiteralPath $workCopy -Raw) -replace "`r`n", "`n"
    return $headFormatted -ceq $workFormatted
  }
  finally {
    Remove-Item -LiteralPath $comparisonRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$expectedBranch = 'design/formal-beautification-foundation'
$remoteRef = "origin/$expectedBranch"
$branch = (git branch --show-current).Trim()
if ($branch -ne $expectedBranch) {
  throw "This repair is for $expectedBranch. Current branch: $branch"
}

Write-Host 'Professional Asset Overview repair: v3-20260816' -ForegroundColor Green
Write-Host 'Scope: only marketplace_listing_specs.dart + its compact widget test.' -ForegroundColor DarkGray
Write-Host 'No emulator, Firebase, admin shell, or product-page reset is required.' -ForegroundColor DarkGray
Write-Host 'Safety: local edits are compared after running the Dart formatter on both HEAD and the working copy.' -ForegroundColor DarkGray

Write-Step 'Fetching the latest formal branch without touching the working tree'
& git fetch origin $expectedBranch
if ($LASTEXITCODE -ne 0) { throw 'git fetch failed.' }

$localHead = (& git rev-parse HEAD).Trim()
$remoteHead = (& git rev-parse $remoteRef).Trim()
Write-Host "Local HEAD : $localHead" -ForegroundColor Yellow
Write-Host "Remote HEAD: $remoteHead" -ForegroundColor Yellow

$specRelative = 'lib/marketplace/marketplace_listing_specs.dart'
$testRelative = 'test/marketplace_listing_specs_compact_test.dart'
$files = @($specRelative, $testRelative)

foreach ($relative in $files) {
  if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relative))) {
    throw "Required professional file is missing: $relative"
  }
}

Write-Step 'Checking the two professional files for real local edits'
$dirty = @(git status --porcelain -- $files)
if ($dirty.Count -gt 0) {
  $untracked = @($dirty | Where-Object { $_ -match '^\?\?' })
  if ($untracked.Count -gt 0) {
    Write-Host 'Untracked professional files were found; refusing to replace them automatically:' -ForegroundColor Red
    $untracked | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    throw 'STOP: untracked professional Asset Overview files require manual review.'
  }

  $semanticEdits = @()
  foreach ($relative in $files) {
    $isDirty = @(git status --porcelain -- $relative).Count -gt 0
    if (-not $isDirty) { continue }

    $equivalent = Test-DartFormattingEquivalent -RepoRoot $repoRoot -RelativePath $relative
    if ($equivalent) {
      Write-Host "Formatting-only local difference confirmed: $relative" -ForegroundColor Yellow
    } else {
      $semanticEdits += $relative
    }
  }

  if ($semanticEdits.Count -gt 0) {
    Write-Host 'These professional files contain real local code/content edits, so this repair will not replace them automatically:' -ForegroundColor Red
    $semanticEdits | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "`nDiff for review:" -ForegroundColor Yellow
    git diff -- $semanticEdits
    throw 'STOP: professional Asset Overview files contain semantic local edits. Preserve/reconcile those edits before this repair.'
  }

  Write-Host 'All local differences in the professional files normalize to the same Dart-formatted source as local HEAD.' -ForegroundColor Green
  Write-Host 'They are formatter-only, so the repaired formal versions can be applied safely after exact TEMP backup.' -ForegroundColor DarkGray
} else {
  Write-Host 'Professional Asset Overview files are clean relative to the current local HEAD.' -ForegroundColor Green
}

$changedFromRemote = @(git diff --name-only HEAD $remoteRef -- $files)
if ($changedFromRemote.Count -eq 0) {
  Write-Host 'Local HEAD already contains the current professional Asset Overview files.' -ForegroundColor Green
} else {
  Write-Host 'The local branch is behind the professional Asset Overview implementation in the remote formal branch.' -ForegroundColor Yellow
  $changedFromRemote | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}

$backupRoot = Join-Path $env:TEMP "pipebuyer-professional-asset-overview-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$backups = @{}
foreach ($relative in $files) {
  $source = Join-Path $repoRoot $relative
  $backup = Join-Path $backupRoot ([IO.Path]::GetFileName($relative))
  Copy-Item -LiteralPath $source -Destination $backup -Force
  $backups[$source] = $backup
}
Write-Host "Exact pre-repair backups: $backupRoot" -ForegroundColor DarkGray

$completed = $false
try {
  Write-Step 'Updating only the professional Asset Overview component + test from the formal branch'
  & git restore --source=$remoteRef --worktree -- $files
  if ($LASTEXITCODE -ne 0) {
    throw 'Could not update the professional Asset Overview files from the remote formal branch.'
  }

  $specPath = Join-Path $repoRoot $specRelative
  $specSource = Get-Content -LiteralPath $specPath -Raw
  if (-not $specSource.Contains('class _ListingSpecsDisclosure extends StatefulWidget') -or
      -not $specSource.Contains('AnimatedSize(') -or
      $specSource.Contains('ExpansionTile(') -or
      $specSource.Contains('AnimatedCrossFade(')) {
    throw 'The repaired Asset Overview source does not match the expected InkWell + AnimatedSize implementation.'
  }
  Write-Host 'Verified source: custom disclosure + AnimatedSize; no ExpansionTile/ListTile disclosure.' -ForegroundColor Green

  Write-Step 'Formatting only the repaired professional files'
  & dart format (Join-Path $repoRoot $specRelative) (Join-Path $repoRoot $testRelative)
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed for the repaired professional files.' }

  Write-Step 'Analyzing only the repaired professional files'
  & dart analyze (Join-Path $repoRoot $specRelative) (Join-Path $repoRoot $testRelative)
  if ($LASTEXITCODE -ne 0) { throw 'dart analyze failed for the repaired professional files.' }

  Write-Step 'Running the exact compact Asset Overview widget contract'
  & flutter test (Join-Path $repoRoot $testRelative) `
    --dart-define=PIPE_ENV=formal-beautification-local `
    --dart-define=PIPE_RELEASE_SHA=professional-asset-overview-repair
  if ($LASTEXITCODE -ne 0) {
    throw 'Professional Asset Overview widget test failed after the targeted repair.'
  }

  Write-Step 'Professional Asset Overview repair passed'
  Write-Host 'The repaired professional files remain in the working tree for visual review.' -ForegroundColor Green
  git diff --stat -- $files
  git status --short -- $files
  $completed = $true
}
finally {
  if (-not $completed) {
    Write-Host "`nRepair failed; restoring the exact two pre-repair files from TEMP." -ForegroundColor Red
    foreach ($entry in $backups.GetEnumerator()) {
      if (Test-Path -LiteralPath $entry.Value) {
        Copy-Item -LiteralPath $entry.Value -Destination $entry.Key -Force
      }
    }
    Write-Host "Backup directory retained for inspection: $backupRoot" -ForegroundColor Yellow
  } else {
    Remove-Item -LiteralPath $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
