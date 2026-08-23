$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

function Normalize-Lf([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Replace-OneRegex {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Replacement,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $matches = [regex]::Matches($Text, $Pattern)
  if ($matches.Count -ne 1) {
    throw "STOP: Expected exactly one $Label marker, found $($matches.Count). No guessing."
  }
  return [regex]::Replace($Text, $Pattern, $Replacement, 1)
}

function Read-One([string]$Text, [string]$Pattern, [string]$Label, [int]$Group = 1) {
  $matches = [regex]::Matches($Text, $Pattern)
  if ($matches.Count -ne 1) {
    throw "STOP: Expected exactly one $Label marker, found $($matches.Count). No guessing."
  }
  return $matches[0].Groups[$Group].Value
}

$planPath = Join-Path $script:PipeBuyerRepoRoot 'docs\DISPATCH_NETWORK_MASTER_PLAN.md'
if (-not (Test-Path -LiteralPath $planPath)) {
  throw "STOP: Dispatch master plan is missing: $planPath"
}

$plan = Normalize-Lf ([System.IO.File]::ReadAllText($planPath))

# This reconciler is intentionally narrow. The accepted evidence at this point is:
# - service-area browser acceptance: PASS
# - expanded credential browser acceptance: NOT YET PASSED
# Therefore the only correct tracker state is 51% / Phase 3 14-of-15.
# A 52%/15-of-15 local state is treated as an over-award from interrupted tooling,
# but only while Phase 4 still has zero earned points and remains blocked.
$phase4Earned = [int](Read-One $plan '(?m)^\| 4 \| Dispatch Service Directory \+ map \| 20 \| (\d+) \| ([^|]+) \|$' 'Phase 4 ledger')
$phase4Status = (Read-One $plan '(?m)^\| 4 \| Dispatch Service Directory \+ map \| 20 \| (\d+) \| ([^|]+) \|$' 'Phase 4 status' 2).Trim()
if ($phase4Earned -ne 0 -or $phase4Status -notmatch '^BLOCKED') {
  throw "STOP: Phase 4 is no longer untouched/blocked ($phase4Earned earned, '$phase4Status'). Refusing to reconcile an older Phase 3 state."
}

$overall = [int](Read-One $plan '\*\*Current verified completion:\*\* \*\*(\d+)%\*\*' 'overall completion')
$phase3 = [int](Read-One $plan '(?m)^\| 3 \| Provider/company profile system \| 15 \| (\d+) \| [^|]+ \|$' 'Phase 3 ledger')
$reportOverall = [int](Read-One $plan '(?m)^Overall: (\d+)/100 = (\d+)%$' 'current report overall')
$reportPhase = [int](Read-One $plan '(?m)^Phase completion: (\d+)/15 points verified$' 'current report Phase 3')

foreach ($pair in @(
  @{Label='Overall completion'; Value=$overall; Allowed=@(50,51,52)},
  @{Label='Phase 3 ledger'; Value=$phase3; Allowed=@(13,14,15)},
  @{Label='Current report overall'; Value=$reportOverall; Allowed=@(50,51,52)},
  @{Label='Current report Phase 3'; Value=$reportPhase; Allowed=@(13,14,15)}
)) {
  if (-not ($pair.Allowed -contains $pair.Value)) {
    throw "STOP: $($pair.Label) is $($pair.Value), outside the known pre-credential-acceptance range."
  }
}

Write-Host "`nDetected local tracker before reconciliation:" -ForegroundColor Cyan
Write-Host "  Overall: $overall%" -ForegroundColor DarkGray
Write-Host "  Phase 3: $phase3/15" -ForegroundColor DarkGray
Write-Host "  Phase 4: $phase4Earned/20, $phase4Status" -ForegroundColor DarkGray

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $script:PipeBuyerRepoRoot "_local_backups\dispatch-phase3-tracker-reconcile-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $planPath -Destination (Join-Path $backupDir 'DISPATCH_NETWORK_MASTER_PLAN.md')
Write-Host "Backup created: $backupDir" -ForegroundColor Green

$plan = Replace-OneRegex $plan '\*\*Current verified completion:\*\* \*\*(?:50|51|52)%\*\*' '**Current verified completion:** **51%**' 'overall verified completion'
$plan = Replace-OneRegex $plan '(?m)^\| 3 \| Provider/company profile system \| 15 \| (?:13|14|15) \| [^|]+ \|$' '| 3 | Provider/company profile system | 15 | 14 | IN PROGRESS |' 'Phase 3 ledger'
$plan = Replace-OneRegex $plan '(?m)^\| \*\*TOTAL\*\* \|  \| \*\*100\*\* \| \*\*(?:50|51|52)\*\* \| \*\*(?:50|51|52)% COMPLETE\*\* \|$' '| **TOTAL** |  | **100** | **51** | **51% COMPLETE** |' 'total ledger'
$plan = Replace-OneRegex $plan '\*\*Current verified:\*\* (?:13|14|15)/15' '**Current verified:** 14/15' 'Phase 3 current verified'
$plan = Replace-OneRegex $plan '(?m)^- \[[ x]\] Service area and home-base map setup\. \*\*1 pt\*\*$' '- [x] Service area and home-base map setup. **1 pt**' 'service-area checklist'
$plan = Replace-OneRegex $plan '(?m)^- \[[ x]\] Credential/insurance metadata with private document separation\. \*\*1 pt\*\*$' '- [ ] Credential/insurance metadata with private document separation. **1 pt**' 'credential checklist'
$plan = Replace-OneRegex $plan '(?m)^Overall: (?:50|51|52)/100 = (?:50|51|52)%$' 'Overall: 51/100 = 51%' 'current report overall'
$plan = Replace-OneRegex $plan '(?m)^Phase completion: (?:13|14|15)/15 points verified$' 'Phase completion: 14/15 points verified' 'current report Phase 3'
$plan = Replace-OneRegex $plan '(?m)^Blockers: .*$' 'Blockers: expanded credential/insurance browser acceptance remains' 'current report blocker'
$plan = Replace-OneRegex $plan '(?m)^Next permitted task: .*$' 'Next permitted task: verify and browser-accept credential coverage, analytics, reminders, and private-data behavior' 'current report next task'

$acceptanceNote = 'Phase 3 service-area/home-base browser acceptance passed on 2026-08-18 after the Towns/Regions classification repair. Town selections no longer substitute the broader parent district, regional selections require real polygon geometry, and saved coverage restores correctly.'
if (-not $plan.Contains($acceptanceNote)) {
  $fleetNote = 'Phase 3 equipment/fleet capability browser acceptance passed on 2026-08-17. Existing and newly created fleet capability records remain available through Company Profile -> Manage fleet.'
  if (-not $plan.Contains($fleetNote)) {
    throw 'STOP: Could not find the known fleet-acceptance anchor for the service-area acceptance note.'
  }
  $plan = $plan.Replace($fleetNote, "$fleetNote`n`n$acceptanceNote")
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($planPath, $plan, $utf8NoBom)

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH PHASE 3 TRACKER RECONCILED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Accepted service-area point: RECORDED' -ForegroundColor Green
Write-Host 'Credential browser point: NOT AWARDED' -ForegroundColor Green
Write-Host 'Overall: 51/100 = 51%' -ForegroundColor Green
Write-Host 'Phase 3: 14/15 - IN PROGRESS' -ForegroundColor Green
Write-Host 'Phase 4: remains blocked' -ForegroundColor Green
