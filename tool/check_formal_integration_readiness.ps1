param(
  [string]$BehaviorReference = 'db7489ed111325c17305e3d87c1889f42cdfb39c',
  [string]$TargetReference = 'origin/main',
  [switch]$AllowDirty
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git is required to evaluate the formal integration gate.'
  }

  $inside = git rev-parse --is-inside-work-tree 2>$null
  if ($LASTEXITCODE -ne 0 -or $inside.Trim() -ne 'true') {
    throw 'Run this tool from a Pipe Buyer Git working tree.'
  }

  if (-not $AllowDirty) {
    $dirty = git status --porcelain
    if ($dirty) {
      throw 'Working tree is not clean. Commit or stash local work before integration.'
    }
  }

  $requiredFiles = @(
    'lib/core/design/pipe_buyer_design.dart',
    'lib/core/design/pipe_buyer_commerce_components.dart',
    'lib/core/design/pipe_buyer_browse_components.dart',
    'lib/core/design/pipe_buyer_listing_components.dart',
    'lib/core/design/pipe_buyer_form_components.dart',
    'lib/core/design/pipe_buyer_deal_room_components.dart',
    'lib/core/design/pipe_buyer_dispatch_components.dart',
    'lib/core/design/pipe_buyer_account_components.dart',
    'docs/FORMAL_CONSTRUCTION_STATUS.md'
  )

  foreach ($path in $requiredFiles) {
    if (-not (Test-Path $path)) {
      throw "Formal design file is missing: $path"
    }
  }

  git cat-file -e "$BehaviorReference^{commit}" 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Behavior reference $BehaviorReference is not available locally. Fetch the active Pipe Buyer branches first."
  }

  git cat-file -e "$TargetReference^{commit}" 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Target reference $TargetReference is not available locally. Run git fetch origin first."
  }

  git merge-base --is-ancestor $BehaviorReference $TargetReference
  $behaviorIntegrated = $LASTEXITCODE -eq 0

  Write-Host 'Pipe Buyer formal integration readiness' -ForegroundColor Cyan
  Write-Host "Target:   $TargetReference" -ForegroundColor DarkGray
  Write-Host "Behavior: $BehaviorReference" -ForegroundColor DarkGray

  if (-not $behaviorIntegrated) {
    Write-Host ''
    Write-Host 'BLOCKED: the validated smart-offer/activity behavior reference is not an ancestor of the target.' -ForegroundColor Yellow
    Write-Host 'Do not overwrite Marketplace, Messages, Dispatch or account behavior with older screen copies.' -ForegroundColor Yellow
    Write-Host 'Reconcile the active behavior stack first, then rerun this check.' -ForegroundColor Yellow
    exit 2
  }

  $mainSha = git rev-parse $TargetReference
  $headSha = git rev-parse HEAD
  $mergeBase = git merge-base HEAD $TargetReference

  Write-Host ''
  Write-Host 'Behavior integration gate: PASS' -ForegroundColor Green
  Write-Host "Target SHA:     $mainSha" -ForegroundColor DarkGray
  Write-Host "Current SHA:    $headSha" -ForegroundColor DarkGray
  Write-Host "Common base:    $mergeBase" -ForegroundColor DarkGray
  Write-Host ''
  Write-Host 'Next safe step: rebase the formal design branch onto the target, resolve presentation conflicts by retaining newer behavior, then run tool/verify_formal_beautification.ps1 -FullGate.' -ForegroundColor Green
  Write-Host 'This tool does not merge, rebase, deploy, or modify repository state.' -ForegroundColor DarkGray
}
finally {
  Pop-Location
}
