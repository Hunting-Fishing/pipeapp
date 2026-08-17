$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$Operation,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )

  Write-Step $Operation
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Operation failed with exit code $LASTEXITCODE."
  }
}

function Remove-WorktreeSafe {
  param([string]$RootRepo, [string]$WorktreePath)
  if ([string]::IsNullOrWhiteSpace($WorktreePath)) { return }
  if (-not (Test-Path -LiteralPath $WorktreePath)) { return }

  Push-Location $RootRepo
  try {
    git worktree remove --force $WorktreePath 2>$null
  }
  finally {
    Pop-Location
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $repoRoot

$branch = 'design/formal-beautification-foundation'
$target = 'lib/marketplace/marketplace_dispatch_page.dart'
$tests = @(
  'test/dispatch_auth_reactivity_contract_test.dart',
  'test/marketplace_dispatch_navigation_test.dart',
  'test/marketplace_dispatch_service_taxonomy_test.dart',
  'test/marketplace_dispatch_company_profile_persistence_contract_test.dart'
)

Write-Host 'PIPE BUYER CANONICAL DISPATCH PAGE RELEASE SYNC' -ForegroundColor Yellow
Write-Host 'This updates only marketplace_dispatch_page.dart on the formal branch.' -ForegroundColor Yellow
Write-Host 'It applies the already-reviewed auth and company-profile integrations.' -ForegroundColor DarkGray

foreach ($command in @('git', 'node', 'dart', 'flutter')) {
  if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "$command is required on PATH."
  }
}

Invoke-Checked 'Fetching current formal branch' {
  git fetch origin $branch
}

$remoteHead = ((git rev-parse "origin/$branch" | Out-String).Trim())
if ([string]::IsNullOrWhiteSpace($remoteHead)) {
  throw 'Could not resolve the formal branch head.'
}
Write-Host "Formal branch head: $remoteHead" -ForegroundColor DarkGray

$tempRoot = Join-Path $env:TEMP ("pipebuyer_dispatch_canonical_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$worktreeAdded = $false

try {
  Invoke-Checked 'Creating clean canonicalization worktree' {
    git worktree add --detach $tempRoot "origin/$branch"
  }
  $worktreeAdded = $true

  Push-Location $tempRoot
  try {
    $lockPath = '.\pubspec.lock'
    $packageConfig = '.\.dart_tool\package_config.json'

    if (-not (Test-Path -LiteralPath $lockPath)) {
      throw 'pubspec.lock is missing from the clean worktree.'
    }

    $lockHashBefore = (Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash

    Invoke-Checked 'Resolving Flutter dependencies' {
      flutter pub get
    }

    if (-not (Test-Path -LiteralPath $packageConfig)) {
      throw 'Flutter dependency resolution did not create package_config.json.'
    }

    $lockHashAfter = (Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash
    if ($lockHashAfter -ne $lockHashBefore) {
      throw 'SAFETY STOP: flutter pub get changed pubspec.lock.'
    }

    Invoke-Checked 'Applying reviewed Dispatch auth reactivity integration' {
      node .\tool\repair_dispatch_auth_reactivity.mjs
    }

    Invoke-Checked 'Applying reviewed registered-provider Company Profile wiring' {
      node .\tool\apply_dispatch_phase3_profile_persistence.mjs
    }

    Invoke-Checked 'Formatting canonical Dispatch page' {
      dart format .\$target
    }

    Invoke-Checked 'Confirming canonical Dispatch page analyzer health' {
      dart analyze --fatal-infos --fatal-warnings .\$target
    }

    Write-Step 'Checking canonical Dispatch source contracts'
    $source = Get-Content -LiteralPath .\$target -Raw

    foreach ($requiredText in @(
      'FirebaseAuth.instance.authStateChanges()',
      'Widget _buildAuthenticatedDispatch(BuildContext context)',
      "import 'marketplace_dispatch_company_profile_page.dart';",
      'MarketplaceDispatchCompanyProfilePage()'
    )) {
      if (-not $source.Contains($requiredText)) {
        throw "Canonical Dispatch page is missing required integration: $requiredText"
      }
    }

    if ($source.Contains('if (FirebaseAuth.instance.currentUser == null)')) {
      throw 'Canonical Dispatch page still contains the obsolete synchronous auth guard.'
    }

    foreach ($test in $tests) {
      Invoke-Checked "Running $test" {
        flutter test $test
      }
    }

    $changed = @(git status --porcelain | ForEach-Object {
      if ($_.Length -ge 4) { $_.Substring(3).Trim() } else { '' }
    } | Where-Object { $_ -ne '' })

    foreach ($path in $changed) {
      if ($path -ne $target) {
        throw "Unexpected tracked file changed during Dispatch canonicalization: $path"
      }
    }

    if ($changed.Count -eq 0) {
      Write-Host 'Formal branch Dispatch page is already canonical. No commit required.' -ForegroundColor Green
      return
    }

    Invoke-Checked 'Checking canonical Dispatch diff' {
      git diff --check -- $target
    }

    Invoke-Checked 'Staging only canonical Dispatch page' {
      git add -- $target
    }

    $staged = @((git diff --cached --name-only) | Where-Object { $_ -ne '' })
    if ($staged.Count -ne 1 -or $staged[0] -ne $target) {
      throw 'Unexpected staged files detected. Refusing to publish.'
    }

    Invoke-Checked 'Committing canonical Dispatch page' {
      git commit -m 'Canonicalize accepted Dispatch auth and profile wiring [skip ci]'
    }

    $publishCommit = ((git rev-parse HEAD | Out-String).Trim())

    Invoke-Checked 'Fast-forwarding canonical Dispatch page to GitHub' {
      git push origin "HEAD:$branch"
    }

    Invoke-Checked 'Verifying canonical Dispatch commit on GitHub' {
      git fetch origin $branch
    }

    $confirmedRemote = ((git rev-parse "origin/$branch" | Out-String).Trim())
    if ($confirmedRemote -ne $publishCommit) {
      throw "Remote verification failed. Expected $publishCommit but found $confirmedRemote."
    }

    Write-Host ''
    Write-Host '======================================================' -ForegroundColor Green
    Write-Host ' CANONICAL DISPATCH PAGE IS ON GITHUB' -ForegroundColor Green
    Write-Host '======================================================' -ForegroundColor Green
    Write-Host "Commit: $publishCommit" -ForegroundColor Green
    Write-Host 'Auth reactivity: PASS' -ForegroundColor Green
    Write-Host 'Registered provider Company Profile wiring: PASS' -ForegroundColor Green
    Write-Host 'Strict analyzer: PASS' -ForegroundColor Green
    Write-Host 'Regression tests: PASS' -ForegroundColor Green
  }
  finally {
    Pop-Location
  }
}
finally {
  if ($worktreeAdded) {
    Remove-WorktreeSafe -RootRepo $repoRoot -WorktreePath $tempRoot
  }
}
