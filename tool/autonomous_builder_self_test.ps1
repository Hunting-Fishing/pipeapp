[CmdletBinding()]
param(
    [string]$ProjectRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Read-JsonFile {
    param([string]$Path)
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "Missing JSON file: $Path"
    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
    catch { throw "Invalid JSON in $Path`: $($_.Exception.Message)" }
}

function Get-LineCount {
    param([string]$Path)
    return @(Get-Content -LiteralPath $Path).Count
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
else {
    $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
}

$engineFiles = @(
    "tool/autonomous_build.ps1",
    "tool/autonomous_build_v2.ps1",
    "tool/autonomous_process.ps1",
    "tool/autonomous_guard.ps1",
    "tool/autonomous_builder_self_test.ps1",
    "tool/autonomous_guard_test.ps1",
    "automation/agent/project.schema.json",
    "automation/agent/result.schema.json",
    "automation/agent/review.schema.json",
    "automation/agent/task_prompt.md",
    "automation/agent/review_prompt.md"
)

foreach ($relative in $engineFiles) {
    $full = Join-Path $ProjectRoot $relative
    Assert-True (Test-Path -LiteralPath $full -PathType Leaf) "Missing builder engine file: $relative"
}

$configPath = Join-Path $ProjectRoot ".autobuild/project.json"
$riskPath = Join-Path $ProjectRoot ".autobuild/risk_policy.json"
$config = Read-JsonFile -Path $configPath
$risk = Read-JsonFile -Path $riskPath
$resultSchema = Read-JsonFile -Path (Join-Path $ProjectRoot "automation/agent/result.schema.json")
$reviewSchema = Read-JsonFile -Path (Join-Path $ProjectRoot "automation/agent/review.schema.json")
$projectSchema = Read-JsonFile -Path (Join-Path $ProjectRoot "automation/agent/project.schema.json")

Assert-True ([int]$config.schema_version -eq 2) "Project schema_version must be 2."
Assert-True (-not [bool]$config.git.allow_direct_main) "Autonomous direct-main writes must remain disabled."
Assert-True ([bool]$config.git.single_writer_required) "Single-writer protection must remain enabled."
Assert-True ([bool]$config.independent_review_required) "Independent review must remain enabled."
Assert-True ([string]$config.safety.production_activation -eq "human-only") "Production activation must remain human-only."
Assert-True ([string]$config.safety.live_provider_mutations -eq "human-only") "Live provider mutations must remain human-only."
Assert-True ([string]$config.safety.merge_to_main -eq "human-only") "Merge to main must remain human-only."
Assert-True ([string]$config.safety.critical_risk_changes -eq "human-only") "Critical-risk changes must remain human-only."
Assert-True (-not [bool]$risk.critical_changes_allowed) "Risk policy must reject critical autonomous changes."

Assert-True ([int]$config.quality.max_source_lines -le 600) "Configured source ceiling must not exceed 600 lines."
Assert-True ([int]$config.quality.max_document_lines -le 600) "Configured documentation ceiling must not exceed 600 lines."
Assert-True ([int]$config.quality.refactor_warning_lines -lt [int]$config.quality.max_source_lines) "Refactor warning must be below source ceiling."
Assert-True ([int]$config.quality.max_files_touched -gt 0) "Changed-file budget must be positive."
Assert-True ([int]$config.quality.max_changed_lines -gt 0) "Changed-line budget must be positive."

$knowledgePaths = New-Object System.Collections.Generic.List[string]
$knowledgePaths.Add([string]$config.agent_policy)
$knowledgePaths.Add([string]$config.risk_policy)
foreach ($property in $config.knowledge.PSObject.Properties) {
    if ($property.Name -eq "feature_registry") {
        $knowledgePaths.Add([string]$property.Value)
        continue
    }
    foreach ($item in @($property.Value)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$item)) {
            $knowledgePaths.Add([string]$item)
        }
    }
}

foreach ($relative in $knowledgePaths | Sort-Object -Unique) {
    $full = Join-Path $ProjectRoot $relative
    Assert-True (Test-Path -LiteralPath $full -PathType Leaf) "Configured knowledge file is missing: $relative"
}

foreach ($pattern in @($risk.forbidden_path_patterns) + @($risk.secret_content_patterns)) {
    try { [regex]::new([string]$pattern) | Out-Null }
    catch { throw "Invalid risk-policy regular expression '$pattern': $($_.Exception.Message)" }
}
foreach ($rule in @($risk.path_risk_rules)) {
    Assert-True (@("low", "medium", "high", "critical") -contains [string]$rule.risk) "Invalid path risk level: $($rule.risk)"
    try { [regex]::new([string]$rule.pattern) | Out-Null }
    catch { throw "Invalid path risk regex '$($rule.pattern)': $($_.Exception.Message)" }
}

$resultRequired = @($resultSchema.required | ForEach-Object { [string]$_ })
foreach ($field in @(
    "risk_level",
    "risk_reasons",
    "knowledge_used",
    "compatibility_checks",
    "data_change",
    "dependency_change",
    "provider_change",
    "security_change",
    "billing_change",
    "rollback_notes"
)) {
    Assert-True ($resultRequired -contains $field) "Worker result schema is missing required safety field: $field"
}

$reviewRequired = @($reviewSchema.required | ForEach-Object { [string]$_ })
foreach ($field in @("verdict", "risk_level", "findings", "functionality_loss_risk", "security_risk", "data_integrity_risk", "billing_financial_risk", "missing_tests")) {
    Assert-True ($reviewRequired -contains $field) "Review schema is missing required safety field: $field"
}

Assert-True ($null -ne $projectSchema.properties.risk_policy) "Project schema must include risk_policy."
Assert-True ($null -ne $projectSchema.properties.independent_review_required) "Project schema must include independent_review_required."

$powerShellScripts = @(
    "tool/autonomous_build.ps1",
    "tool/autonomous_build_v2.ps1",
    "tool/autonomous_process.ps1",
    "tool/autonomous_guard.ps1",
    "tool/autonomous_builder_self_test.ps1",
    "tool/autonomous_guard_test.ps1"
)
foreach ($relative in $powerShellScripts) {
    $full = Join-Path $ProjectRoot $relative
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($full, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        $detail = ($errors | ForEach-Object { $_.Message }) -join "; "
        throw "PowerShell syntax error in $relative`: $detail"
    }
    $lines = Get-LineCount -Path $full
    Assert-True ($lines -le [int]$config.quality.max_source_lines) "Builder source $relative is $lines lines; exceeds project source ceiling."
}

$wrapper = Get-Content -LiteralPath (Join-Path $ProjectRoot "tool/autonomous_build.ps1") -Raw
Assert-True ($wrapper.Contains("autonomous_build_v2.ps1")) "Stable autonomous_build.ps1 wrapper must delegate to V2 supervisor."

$supervisor = Get-Content -LiteralPath (Join-Path $ProjectRoot "tool/autonomous_build_v2.ps1") -Raw
Assert-True ($supervisor.Contains("Invoke-CodexReviewer")) "V2 supervisor must invoke the independent reviewer."
Assert-True ($supervisor.Contains("supervisor.lock")) "V2 supervisor must implement a single-writer lock."
Assert-True ($supervisor.Contains("-ResultPath '$resultEsc'")) "V2 supervisor must pass worker result metadata into the autonomous guard."

$featureContractPath = Join-Path $ProjectRoot ".autobuild/feature_contract.json"
if (Test-Path -LiteralPath $featureContractPath) {
    $contract = Read-JsonFile -Path $featureContractPath
    foreach ($relative in @($contract.required_paths)) {
        Assert-True (Test-Path -LiteralPath (Join-Path $ProjectRoot ([string]$relative))) "Feature contract required path missing: $relative"
    }
}

$lockTestPath = Join-Path ([System.IO.Path]::GetTempPath()) "autobuild-lock-test-$([guid]::NewGuid().ToString('N')).lock"
$firstLock = $null
$secondLock = $null
try {
    $firstLock = [System.IO.File]::Open($lockTestPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $secondFailed = $false
    try {
        $secondLock = [System.IO.File]::Open($lockTestPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    }
    catch {
        $secondFailed = $true
    }
    Assert-True $secondFailed "Exclusive single-writer file lock did not reject a second owner."
}
finally {
    if ($null -ne $secondLock) { $secondLock.Dispose() }
    if ($null -ne $firstLock) { $firstLock.Dispose() }
    Remove-Item -LiteralPath $lockTestPath -Force -ErrorAction SilentlyContinue
}

Write-Host "Autonomous Builder static self-test passed."
Write-Host "  Project           : $($config.project_name)"
Write-Host "  Writer branch     : $($config.writer_branch)"
Write-Host "  Independent review: $($config.independent_review_required)"
Write-Host "  Source ceiling    : $($config.quality.max_source_lines)"
Write-Host "  Document ceiling  : $($config.quality.max_document_lines)"
Write-Host "  Knowledge files   : $(@($knowledgePaths | Sort-Object -Unique).Count)"
