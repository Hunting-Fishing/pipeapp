[CmdletBinding()]
param(
    [string]$ProjectRoot = "",
    [string]$ResultPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-NativeSuccess {
    param([string]$Operation)
    if ($LASTEXITCODE -ne 0) { throw "$Operation failed with exit code $LASTEXITCODE." }
}

function Get-LineCount {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 0 }
    return @(Get-Content -LiteralPath $Path).Count
}

function Test-GeneratedPath {
    param([string]$RelativePath, [object[]]$Markers)
    $normalized = $RelativePath.Replace("\", "/")
    foreach ($marker in $Markers) {
        if ($normalized.Contains([string]$marker)) { return $true }
    }
    return $false
}

function Test-AnyPattern {
    param([string]$Value, [object[]]$Patterns)
    foreach ($pattern in $Patterns) {
        if ($Value -match [string]$pattern) { return $true }
    }
    return $false
}

function Get-RiskRank {
    param([string]$Risk)
    switch ($Risk.ToLowerInvariant()) {
        "low" { return 1 }
        "medium" { return 2 }
        "high" { return 3 }
        "critical" { return 4 }
        default { throw "Unknown risk level: $Risk" }
    }
}

function Resolve-PathRisk {
    param([string[]]$ChangedPaths, [object[]]$Rules)
    $bestRisk = "low"
    $bestRank = 1
    $reasons = New-Object System.Collections.Generic.List[string]
    foreach ($relative in $ChangedPaths) {
        $normalized = $relative.Replace("\", "/")
        foreach ($rule in $Rules) {
            $pattern = [string]$rule.pattern
            if ($normalized -notmatch $pattern) { continue }
            $risk = [string]$rule.risk
            $rank = Get-RiskRank -Risk $risk
            if ($rank -gt $bestRank) {
                $bestRank = $rank
                $bestRisk = $risk
            }
            $reason = "$relative: $([string]$rule.reason)"
            if (-not $reasons.Contains($reason)) { $reasons.Add($reason) }
        }
    }
    return [pscustomobject]@{ Risk = $bestRisk; Rank = $bestRank; Reasons = @($reasons) }
}

function Read-HeadLineCount {
    param([string]$RelativePath)
    & git cat-file -e "HEAD:$RelativePath" 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    $lines = @(& git show "HEAD:$RelativePath")
    Assert-NativeSuccess "git show HEAD:$RelativePath"
    return $lines.Count
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git is required." }
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (& git rev-parse --show-toplevel).Trim()
    Assert-NativeSuccess "git rev-parse --show-toplevel"
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
Set-Location -LiteralPath $ProjectRoot

$configPath = Join-Path $ProjectRoot ".autobuild/project.json"
if (-not (Test-Path -LiteralPath $configPath)) { throw "Missing autonomous project config: $configPath" }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

$riskPolicyRelative = [string]$config.risk_policy
$riskPolicyPath = Join-Path $ProjectRoot $riskPolicyRelative
if (-not (Test-Path -LiteralPath $riskPolicyPath)) { throw "Missing autonomous risk policy: $riskPolicyRelative" }
$riskPolicy = Get-Content -LiteralPath $riskPolicyPath -Raw | ConvertFrom-Json

$quality = $config.quality
$maxFiles = [int]$quality.max_files_touched
$maxChangedLines = [int]$quality.max_changed_lines
$maxSourceLines = [int]$quality.max_source_lines
$warningLines = [int]$quality.refactor_warning_lines
$maxDocumentLines = [int]$quality.max_document_lines
$sourceExtensions = @($quality.source_extensions | ForEach-Object { ([string]$_).ToLowerInvariant() })
$generatedMarkers = @($quality.generated_path_markers)
$protectedGovernance = @()
if ($riskPolicy.PSObject.Properties.Name -contains "protected_governance_paths") {
    $protectedGovernance = @($riskPolicy.protected_governance_paths | ForEach-Object { ([string]$_).Replace("\", "/") })
}

$trackedChanges = @(& git diff --name-only HEAD --)
Assert-NativeSuccess "git diff --name-only"
$untrackedChanges = @(& git ls-files --others --exclude-standard)
Assert-NativeSuccess "git ls-files --others"
$changedPaths = @($trackedChanges + $untrackedChanges | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
if ($changedPaths.Count -eq 0) { throw "Autonomous guard was invoked with no workspace changes." }
if ($changedPaths.Count -gt $maxFiles) {
    throw "Autonomous increment touches $($changedPaths.Count) files; configured maximum is $maxFiles. Split the increment."
}

& git diff --check HEAD --
if ($LASTEXITCODE -ne 0) { throw "git diff --check found whitespace or conflict-marker errors." }

foreach ($relative in $changedPaths) {
    $normalized = $relative.Replace("\", "/")
    if ($protectedGovernance -contains $normalized) {
        throw "Autonomous workers may not modify protected governance/control file: $relative"
    }
    foreach ($pattern in @($riskPolicy.forbidden_path_patterns)) {
        if ($normalized -match [string]$pattern) {
            throw "Autonomous change touches forbidden credential/secret path: $relative"
        }
    }
}

$added = 0
$deleted = 0
$numstat = @(& git diff --numstat HEAD --)
Assert-NativeSuccess "git diff --numstat"
foreach ($line in $numstat) {
    $parts = $line -split "`t"
    if ($parts.Count -lt 3) { continue }
    if ($parts[0] -match '^\d+$') { $added += [int]$parts[0] }
    if ($parts[1] -match '^\d+$') { $deleted += [int]$parts[1] }
}
foreach ($relative in $untrackedChanges) {
    $full = Join-Path $ProjectRoot $relative
    if (Test-Path -LiteralPath $full -PathType Leaf) { $added += Get-LineCount -Path $full }
}
$totalChanged = $added + $deleted
if ($totalChanged -gt $maxChangedLines) {
    throw "Autonomous increment changes $totalChanged lines ($added added, $deleted deleted); configured maximum is $maxChangedLines. Split the increment."
}

$warnings = New-Object System.Collections.Generic.List[string]
foreach ($relative in $changedPaths) {
    $full = Join-Path $ProjectRoot $relative
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
    if (Test-GeneratedPath -RelativePath $relative -Markers $generatedMarkers) { continue }

    $text = Get-Content -LiteralPath $full -Raw
    if ($text -match '(?m)^(<<<<<<< |=======\s*$|>>>>>>> )') { throw "Conflict marker detected in changed file: $relative" }
    foreach ($secretPattern in @($riskPolicy.secret_content_patterns)) {
        if ($text -match [string]$secretPattern) { throw "Potential credential/secret content detected in changed file: $relative" }
    }

    $extension = [System.IO.Path]::GetExtension($relative).ToLowerInvariant()
    $currentLines = Get-LineCount -Path $full
    $baselineLines = Read-HeadLineCount -RelativePath $relative

    if ($extension -eq ".md" -and $currentLines -gt $maxDocumentLines) {
        if ($null -eq $baselineLines) { throw "New documentation file $relative is $currentLines lines; documentation maximum is $maxDocumentLines. Split by responsibility." }
        if ($currentLines -gt [int]$baselineLines) { throw "Legacy oversized documentation $relative grew ($baselineLines -> $currentLines). Split or reduce it rather than adding more content." }
        $warnings.Add("Legacy oversized documentation $relative remains $currentLines lines; split it in a dedicated documentation refactor.")
    }

    if ($sourceExtensions -notcontains $extension) { continue }
    if ($currentLines -gt $warningLines) { $warnings.Add("$relative is $currentLines lines; refactoring warning starts at $warningLines.") }
    if ($currentLines -le $maxSourceLines) { continue }
    if ($null -eq $baselineLines) { throw "New source file $relative is $currentLines lines; maximum is $maxSourceLines. Split by responsibility." }
    if ($currentLines -ge [int]$baselineLines) { throw "Oversized source file $relative grew or did not shrink ($baselineLines -> $currentLines lines). Files above $maxSourceLines must be reduced before adding responsibility." }
    $warnings.Add("Legacy oversized source $relative was reduced from $baselineLines to $currentLines lines; continue refactoring later.")
}

$featureContractPath = Join-Path $ProjectRoot ".autobuild/feature_contract.json"
if (Test-Path -LiteralPath $featureContractPath) {
    $contract = Get-Content -LiteralPath $featureContractPath -Raw | ConvertFrom-Json
    foreach ($relative in @($contract.required_paths)) {
        if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot ([string]$relative)))) {
            throw "Feature preservation contract failed: required path is missing: $relative"
        }
    }
    foreach ($rule in @($contract.required_text)) {
        $relative = [string]$rule.path
        $pattern = [string]$rule.pattern
        $full = Join-Path $ProjectRoot $relative
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Feature preservation contract failed: required text file is missing: $relative" }
        $text = Get-Content -LiteralPath $full -Raw
        if (-not $text.Contains($pattern)) { throw "Feature preservation contract failed: '$pattern' is missing from $relative" }
    }
}

$detected = Resolve-PathRisk -ChangedPaths $changedPaths -Rules @($riskPolicy.path_risk_rules)
$dependencyDetected = @($changedPaths | Where-Object { Test-AnyPattern -Value $_ -Patterns @($riskPolicy.dependency_path_patterns) }).Count -gt 0
$dataDetected = @($changedPaths | Where-Object { Test-AnyPattern -Value $_ -Patterns @($riskPolicy.data_path_patterns) }).Count -gt 0
$securityDetected = @($changedPaths | Where-Object { Test-AnyPattern -Value $_ -Patterns @($riskPolicy.security_path_patterns) }).Count -gt 0
$billingDetected = @($changedPaths | Where-Object { Test-AnyPattern -Value $_ -Patterns @($riskPolicy.billing_path_patterns) }).Count -gt 0
$providerDetected = @($changedPaths | Where-Object { Test-AnyPattern -Value $_ -Patterns @($riskPolicy.provider_path_patterns) }).Count -gt 0

if (-not [string]::IsNullOrWhiteSpace($ResultPath)) {
    if (-not [System.IO.Path]::IsPathRooted($ResultPath)) { $ResultPath = Join-Path $ProjectRoot $ResultPath }
    if (-not (Test-Path -LiteralPath $ResultPath -PathType Leaf)) { throw "Structured worker result not found for risk validation: $ResultPath" }
    $result = Get-Content -LiteralPath $ResultPath -Raw | ConvertFrom-Json
    $declaredRisk = [string]$result.risk_level
    $declaredRank = Get-RiskRank -Risk $declaredRisk

    if ($declaredRank -lt $detected.Rank) { throw "Worker under-classified risk: declared $declaredRisk, path policy requires at least $($detected.Risk)." }
    if ($declaredRisk -eq "critical" -and -not [bool]$riskPolicy.critical_changes_allowed) { throw "Critical-risk changes are human-only and cannot be autonomously committed." }
    if (@($result.knowledge_used).Count -eq 0) { throw "Worker result did not record knowledge used." }
    if ($declaredRank -ge 2 -and @($result.compatibility_checks).Count -eq 0) { throw "Medium/high-risk work must record compatibility checks." }
    if ($declaredRank -ge 3 -and [string]::IsNullOrWhiteSpace([string]$result.rollback_notes)) { throw "High-risk work must record rollback/recovery implications." }
    if ($dependencyDetected -and -not [bool]$result.dependency_change) { throw "Dependency manifest/lockfile changed but worker declared dependency_change=false." }
    if ($dataDetected -and -not [bool]$result.data_change) { throw "Data/schema-related path changed but worker declared data_change=false." }
    if ($securityDetected -and -not [bool]$result.security_change) { throw "Security/auth/rules-related path changed but worker declared security_change=false." }
    if ($billingDetected -and -not [bool]$result.billing_change) { throw "Billing/payment-related path changed but worker declared billing_change=false." }
    if ($providerDetected -and -not [bool]$result.provider_change) { throw "Provider-related path changed but worker declared provider_change=false." }
    if ($declaredRank -ge 3) {
        $passedFocused = @($result.verification | Where-Object { $_.result -eq "passed" }).Count
        if ($passedFocused -eq 0) { throw "High-risk work must include at least one passed focused verification before supervisor review." }
    }
}

Write-Host "Autonomous quality guard passed."
Write-Host "  Files touched : $($changedPaths.Count) / $maxFiles"
Write-Host "  Changed lines : $totalChanged / $maxChangedLines ($added added, $deleted deleted)"
Write-Host "  Source ceiling: $maxSourceLines lines"
Write-Host "  Document max  : $maxDocumentLines lines"
Write-Host "  Detected risk : $($detected.Risk)"
foreach ($reason in $detected.Reasons) { Write-Host "  Risk reason   : $reason" }
foreach ($warning in $warnings) { Write-Warning $warning }
