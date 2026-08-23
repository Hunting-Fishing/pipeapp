$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

function Normalize-Lf([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-SingleCapture {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Label,
    [int]$Group = 1
  )
  $matches = [regex]::Matches($Text, $Pattern)
  if ($matches.Count -ne 1) {
    throw "STOP: Expected exactly one $Label marker, found $($matches.Count). No guessing."
  }
  return $matches[0].Groups[$Group].Value
}

function Assert-AllowedNumber {
  param(
    [Parameter(Mandatory = $true)][string]$Value,
    [Parameter(Mandatory = $true)][int[]]$Allowed,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $number = 0
  if (-not [int]::TryParse($Value, [ref]$number) -or -not ($Allowed -contains $number)) {
    throw "STOP: $Label is '$Value'. Expected one of: $($Allowed -join ', '). Refusing to move the tracker backward or skip ahead."
  }
  return $number
}

function Replace-SingleRegex {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Replacement,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $matches = [regex]::Matches($Text, $Pattern)
  if ($matches.Count -ne 1) {
    throw "STOP: Expected exactly one $Label target, found $($matches.Count). No guessing."
  }
  return [regex]::Replace($Text, $Pattern, $Replacement, 1)
}

function Replace-KnownText {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$Before,
    [Parameter(Mandatory = $true)][string]$After,
    [Parameter(Mandatory = $true)][string]$Label
  )
  if ($Text.Contains($After)) {
    return $Text
  }
  $count = ([regex]::Matches($Text, [regex]::Escape($Before))).Count
  if ($count -ne 1) {
    throw "STOP: Expected exactly one known $Label source target, found $count. No guessing."
  }
  return $Text.Replace($Before, $After)
}

$masterPlanPath = Join-Path $script:PipeBuyerRepoRoot 'docs\DISPATCH_NETWORK_MASTER_PLAN.md'
if (-not (Test-Path -LiteralPath $masterPlanPath)) {
  throw "STOP: Dispatch master plan is missing: $masterPlanPath"
}

$plan = Normalize-Lf ([System.IO.File]::ReadAllText($masterPlanPath))

# Read the semantic tracker state first. The recorder accepts only the known
# pre-acceptance (50/13) or accepted (51/14) values, including a mixed partial
# state from an interrupted earlier acceptance update. Anything beyond that is
# a safety stop rather than a downgrade or phase skip.
$overall = Assert-AllowedNumber (Get-SingleCapture $plan '\*\*Current verified completion:\*\* \*\*(\d+)%\*\*' 'overall completion') @(50, 51) 'Overall completion'
$phase3 = Assert-AllowedNumber (Get-SingleCapture $plan '(?m)^\| 3 \| Provider/company profile system \| 15 \| (\d+) \| IN PROGRESS \|$' 'Phase 3 ledger') @(13, 14) 'Phase 3 ledger'
$totalEarned = Assert-AllowedNumber (Get-SingleCapture $plan '(?m)^\| \*\*TOTAL\*\* \|  \| \*\*100\*\* \| \*\*(\d+)\*\* \| \*\*(\d+)% COMPLETE\*\* \|$' 'total ledger') @(50, 51) 'Total earned'
$totalPercent = Assert-AllowedNumber (Get-SingleCapture $plan '(?m)^\| \*\*TOTAL\*\* \|  \| \*\*100\*\* \| \*\*(\d+)\*\* \| \*\*(\d+)% COMPLETE\*\* \|$' 'total ledger percentage' 2) @(50, 51) 'Total percentage'
$currentVerified = Assert-AllowedNumber (Get-SingleCapture $plan '\*\*Current verified:\*\* (\d+)/15' 'Phase 3 current verified') @(13, 14) 'Phase 3 current verified'
$reportOverall = Assert-AllowedNumber (Get-SingleCapture $plan '(?m)^Overall: (\d+)/100 = (\d+)%$' 'current report overall') @(50, 51) 'Current report overall'
$reportPercent = Assert-AllowedNumber (Get-SingleCapture $plan '(?m)^Overall: (\d+)/100 = (\d+)%$' 'current report percent' 2) @(50, 51) 'Current report percent'
$reportPhase = Assert-AllowedNumber (Get-SingleCapture $plan '(?m)^Phase completion: (\d+)/15 points verified$' 'current report Phase 3') @(13, 14) 'Current report Phase 3'

Write-Host "`nKnown Phase 3 tracker state detected:" -ForegroundColor Cyan
Write-Host "  Overall completion: $overall%" -ForegroundColor DarkGray
Write-Host "  Phase 3 ledger: $phase3/15" -ForegroundColor DarkGray
Write-Host "  Total ledger: $totalEarned / $totalPercent%" -ForegroundColor DarkGray
Write-Host "  Current verified: $currentVerified/15" -ForegroundColor DarkGray
Write-Host "  Current report: $reportOverall% / $reportPhase/15" -ForegroundColor DarkGray

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $script:PipeBuyerRepoRoot "_local_backups\dispatch-service-area-acceptance-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $masterPlanPath -Destination (Join-Path $backupDir 'DISPATCH_NETWORK_MASTER_PLAN.md')
Write-Host "Backup created: $backupDir" -ForegroundColor Green

# Normalize every known tracker location to the browser-accepted service-area
# state. This intentionally does not award the credential point or unlock Phase 4.
$plan = Replace-SingleRegex $plan '\*\*Current verified completion:\*\* \*\*(?:50|51)%\*\*' '**Current verified completion:** **51%**' 'overall verified completion'
$plan = Replace-SingleRegex $plan '(?m)^\| 3 \| Provider/company profile system \| 15 \| (?:13|14) \| IN PROGRESS \|$' '| 3 | Provider/company profile system | 15 | 14 | IN PROGRESS |' 'Phase 3 ledger'
$plan = Replace-SingleRegex $plan '(?m)^\| \*\*TOTAL\*\* \|  \| \*\*100\*\* \| \*\*(?:50|51)\*\* \| \*\*(?:50|51)% COMPLETE\*\* \|$' '| **TOTAL** |  | **100** | **51** | **51% COMPLETE** |' 'total ledger'
$plan = Replace-SingleRegex $plan '\*\*Current verified:\*\* (?:13|14)/15' '**Current verified:** 14/15' 'Phase 3 verified points'
$plan = Replace-SingleRegex $plan '(?m)^- \[[ x]\] Service area and home-base map setup\. \*\*1 pt\*\*$' '- [x] Service area and home-base map setup. **1 pt**' 'service-area checklist'
$plan = Replace-SingleRegex $plan '(?m)^Overall: (?:50|51)/100 = (?:50|51)%$' 'Overall: 51/100 = 51%' 'current report overall'
$plan = Replace-SingleRegex $plan '(?m)^Phase completion: (?:13|14)/15 points verified$' 'Phase completion: 14/15 points verified' 'current report Phase 3'

$plan = Replace-KnownText $plan 'Blockers: mapped service area/home base and credential metadata remain' 'Blockers: credential/insurance intelligence and private-document browser acceptance remain' 'current report blocker'
$plan = Replace-KnownText $plan 'Next permitted task: build mapped service area/home-base persistence with privacy projection' 'Next permitted task: complete credential/insurance coverage, expiry alerts, analytics, and private-data acceptance' 'current report next task'

$acceptanceNote = 'Phase 3 service-area/home-base browser acceptance passed on 2026-08-18 after the Towns/Regions classification repair. Town selections no longer substitute the broader parent district, regional selections require real polygon geometry, and saved coverage restores correctly.'
if (-not $plan.Contains($acceptanceNote)) {
  $fleetNote = 'Phase 3 equipment/fleet capability browser acceptance passed on 2026-08-17. Existing and newly created fleet capability records remain available through Company Profile -> Manage fleet.'
  $plan = Replace-KnownText $plan $fleetNote "$fleetNote`n`n$acceptanceNote" 'service-area browser acceptance evidence anchor'
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($masterPlanPath, $plan, $utf8NoBom)

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH PHASE 3 SERVICE-AREA ACCEPTANCE RECORDED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Overall Dispatch tracker: 51/100 = 51%' -ForegroundColor Green
Write-Host 'Phase 3 tracker: 14/15' -ForegroundColor Green
Write-Host 'Service-area checklist: PASS' -ForegroundColor Green
Write-Host 'Credential point awarded: NO' -ForegroundColor Green
Write-Host 'Phase 4 unlocked: NO' -ForegroundColor Green
Write-Host ''
