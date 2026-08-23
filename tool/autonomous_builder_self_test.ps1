[CmdletBinding()]
param([string]$ProjectRoot = "")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Read-Json([string]$Path) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "Missing JSON file: $Path"
    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
    catch { throw "Invalid JSON in $Path`: $($_.Exception.Message)" }
}
function Get-LineCount([string]$Path) { return @(Get-Content -LiteralPath $Path).Count }

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
} else {
    $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
}

$config = Read-Json (Join-Path $ProjectRoot ".autobuild/project.json")
$risk = Read-Json (Join-Path $ProjectRoot ".autobuild/risk_policy.json")
$resultSchema = Read-Json (Join-Path $ProjectRoot "automation/agent/result.schema.json")
$reviewSchema = Read-Json (Join-Path $ProjectRoot "automation/agent/review.schema.json")
$projectSchema = Read-Json (Join-Path $ProjectRoot "automation/agent/project.schema.json")

Assert-True ([int]$config.schema_version -eq 2) "Project schema_version must be 2."
Assert-True (-not [bool]$config.git.allow_direct_main) "Direct-main autonomous writes must remain disabled."
Assert-True ([bool]$config.git.single_writer_required) "Single-writer protection must remain enabled."
Assert-True ([bool]$config.git.require_remote_freshness) "Remote freshness must remain enabled."
Assert-True ([bool]$config.independent_review_required) "Independent review must remain enabled."
Assert-True ([bool]$config.preflight_verify_required) "Clean-baseline full verification must remain enabled."
Assert-True ([bool]$config.graduation.required) "Autonomous graduation evidence must remain required."
Assert-True ([double]$config.graduation.max_age_hours -le 168) "Graduation evidence may not be trusted longer than seven days."
Assert-True (@($config.graduation.control_paths).Count -ge 10) "Graduation fingerprint control set is unexpectedly small."
Assert-True ([string]$config.safety.production_activation -eq "human-only") "Production activation must remain human-only."
Assert-True ([string]$config.safety.live_provider_mutations -eq "human-only") "Live provider mutations must remain human-only."
Assert-True ([string]$config.safety.merge_to_main -eq "human-only") "Merge to main must remain human-only."
Assert-True ([string]$config.safety.critical_risk_changes -eq "human-only") "Critical risk must remain human-only."
Assert-True (-not [bool]$risk.critical_changes_allowed) "Critical autonomous changes must remain disabled."

Assert-True ([int]$config.quality.max_source_lines -le 600) "Source ceiling exceeds 600 lines."
Assert-True ([int]$config.quality.max_document_lines -le 600) "Documentation ceiling exceeds 600 lines."
Assert-True ([int]$config.quality.refactor_warning_lines -lt [int]$config.quality.max_source_lines) "Refactor warning must be below the hard source ceiling."
Assert-True ([int]$config.quality.max_files_touched -le 12) "Pipe Buyer autonomous file budget expanded beyond 12 without governance review."
Assert-True ([int]$config.quality.max_changed_lines -le 800) "Pipe Buyer autonomous line budget expanded beyond 800 without governance review."

$knowledgePaths = New-Object System.Collections.Generic.List[string]
$knowledgePaths.Add([string]$config.agent_policy)
$knowledgePaths.Add([string]$config.risk_policy)
foreach ($property in $config.knowledge.PSObject.Properties) {
    if ($property.Name -eq "feature_registry") {
        $knowledgePaths.Add([string]$property.Value)
    } else {
        foreach ($item in @($property.Value)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$item)) { $knowledgePaths.Add([string]$item) }
        }
    }
}
foreach ($relative in $knowledgePaths | Sort-Object -Unique) {
    Assert-True (Test-Path -LiteralPath (Join-Path $ProjectRoot $relative) -PathType Leaf) "Configured knowledge file missing: $relative"
}

foreach ($relative in @($config.graduation.control_paths)) {
    $full = Join-Path $ProjectRoot ([string]$relative)
    Assert-True (Test-Path -LiteralPath $full -PathType Leaf) "Graduation control file missing: $relative"
    $extension = [IO.Path]::GetExtension([string]$relative).ToLowerInvariant()
    if ($extension -eq ".ps1") {
        $tokens = $null; $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($full,[ref]$tokens,[ref]$errors) | Out-Null
        if ($errors.Count -gt 0) {
            throw "PowerShell syntax error in $relative`: $(($errors | ForEach-Object Message) -join '; ')"
        }
    }
    if ($extension -in @(".ps1", ".mjs", ".js", ".ts", ".tsx", ".dart")) {
        Assert-True ((Get-LineCount $full) -le [int]$config.quality.max_source_lines) "Control source $relative exceeds source ceiling."
    }
}

foreach ($pattern in @($risk.forbidden_path_patterns) + @($risk.secret_content_patterns)) {
    try { [regex]::new([string]$pattern) | Out-Null } catch { throw "Invalid risk regex: $pattern" }
}
foreach ($rule in @($risk.path_risk_rules)) {
    Assert-True (@("low","medium","high","critical") -contains [string]$rule.risk) "Invalid risk level in path rule."
    try { [regex]::new([string]$rule.pattern) | Out-Null } catch { throw "Invalid path risk regex: $($rule.pattern)" }
}
Assert-True (@($risk.forbidden_path_patterns | Where-Object { [string]$_ -match 'github/workflows' }).Count -gt 0) "Autonomous workers must be blocked from modifying CI workflows."

$resultRequired = @($resultSchema.required | ForEach-Object { [string]$_ })
foreach ($field in @("risk_level","risk_reasons","knowledge_used","compatibility_checks","data_change","dependency_change","provider_change","security_change","billing_change","rollback_notes")) {
    Assert-True ($resultRequired -contains $field) "Worker result schema missing safety field: $field"
}
$reviewRequired = @($reviewSchema.required | ForEach-Object { [string]$_ })
foreach ($field in @("verdict","risk_level","findings","functionality_loss_risk","security_risk","data_integrity_risk","billing_financial_risk","missing_tests")) {
    Assert-True ($reviewRequired -contains $field) "Review schema missing safety field: $field"
}
foreach ($property in @("risk_policy","independent_review_required","preflight_verify_required","graduation")) {
    Assert-True ($null -ne $projectSchema.properties.$property) "Project schema missing property: $property"
}

$wrapper = Get-Content -LiteralPath (Join-Path $ProjectRoot "tool/autonomous_build.ps1") -Raw
Assert-True ($wrapper.Contains("autonomous_build_v2.ps1")) "Stable wrapper must delegate to V2."
Assert-True ($wrapper.Contains("autonomous_recovery_safe.ps1")) "Stable wrapper must use stash-safe recovery."
Assert-True ($wrapper.Contains("Assert-AutonomousGraduationEvidence")) "Stable wrapper must reject ungraduated controls."
$supervisor = Get-Content -LiteralPath (Join-Path $ProjectRoot "tool/autonomous_build_v2.ps1") -Raw
Assert-True ($supervisor.Contains("Invoke-CodexReviewer")) "Supervisor must invoke independent reviewer."
Assert-True ($supervisor.Contains("Enter-AutonomousSingleWriterLock")) "Supervisor must acquire single-writer lock."
Assert-True ($supervisor.Contains("-ResultPath '$resultEsc'")) "Supervisor must pass worker result into deterministic guard."

$protected = @($risk.protected_governance_paths | ForEach-Object { [string]$_ })
foreach ($required in @(
    "docs/AUTONOMOUS_BUILDER_READINESS.md",
    "docs/SHIP_72_HOUR_PLAN.md",
    "tool/autonomous_build.ps1",
    "tool/autonomous_graduation.ps1",
    "tool/autonomous_recovery_safe.ps1",
    "tool/autonomous_compatibility.mjs",
    "tool/verify.ps1"
)) {
    Assert-True ($protected -contains $required) "Protected governance set missing: $required"
}

$contract = Read-Json (Join-Path $ProjectRoot ".autobuild/feature_contract.json")
foreach ($relative in @($contract.required_paths)) {
    Assert-True (Test-Path -LiteralPath (Join-Path $ProjectRoot ([string]$relative))) "Feature contract path missing: $relative"
}
foreach ($rule in @($contract.required_text)) {
    $full = Join-Path $ProjectRoot ([string]$rule.path)
    Assert-True (Test-Path -LiteralPath $full -PathType Leaf) "Feature contract file missing: $($rule.path)"
    Assert-True ((Get-Content -LiteralPath $full -Raw).Contains([string]$rule.pattern)) "Feature anchor missing: $($rule.pattern)"
}

$lockPath = Join-Path ([IO.Path]::GetTempPath()) "autobuild-lock-$([guid]::NewGuid().ToString('N')).lock"
$first = $null; $second = $null
try {
    $first = [IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $blocked = $false
    try { $second = [IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) } catch { $blocked = $true }
    Assert-True $blocked "Exclusive lock did not reject a second owner."
} finally {
    if ($null -ne $second) { $second.Dispose() }
    if ($null -ne $first) { $first.Dispose() }
    Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
}

Write-Host "Autonomous Builder static self-test passed."
Write-Host "  Project            : $($config.project_name)"
Write-Host "  Writer branch      : $($config.writer_branch)"
Write-Host "  Graduation required: $($config.graduation.required)"
Write-Host "  Control files      : $(@($config.graduation.control_paths).Count)"
Write-Host "  Knowledge files    : $(@($knowledgePaths | Sort-Object -Unique).Count)"
