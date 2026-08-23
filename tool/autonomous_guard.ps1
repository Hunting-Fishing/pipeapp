[CmdletBinding()]
param(
    [string]$ProjectRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-NativeSuccess {
    param([string]$Operation)
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation failed with exit code $LASTEXITCODE."
    }
}

function Get-LineCount {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    return @(Get-Content -LiteralPath $Path).Count
}

function Test-GeneratedPath {
    param(
        [string]$RelativePath,
        [object[]]$Markers
    )

    $normalized = $RelativePath.Replace("\\", "/")
    foreach ($marker in $Markers) {
        if ($normalized.Contains([string]$marker)) { return $true }
    }
    return $false
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is required."
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (& git rev-parse --show-toplevel).Trim()
    Assert-NativeSuccess "git rev-parse --show-toplevel"
}

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
Set-Location -LiteralPath $ProjectRoot

$configPath = Join-Path $ProjectRoot ".autobuild/project.json"
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Missing autonomous project config: $configPath"
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$quality = $config.quality
$maxFiles = [int]$quality.max_files_touched
$maxChangedLines = [int]$quality.max_changed_lines
$maxSourceLines = [int]$quality.max_source_lines
$warningLines = [int]$quality.refactor_warning_lines
$sourceExtensions = @($quality.source_extensions | ForEach-Object { ([string]$_).ToLowerInvariant() })
$generatedMarkers = @($quality.generated_path_markers)

$trackedChanges = @(& git diff --name-only HEAD --)
Assert-NativeSuccess "git diff --name-only"
$untrackedChanges = @(& git ls-files --others --exclude-standard)
Assert-NativeSuccess "git ls-files --others"
$changedPaths = @($trackedChanges + $untrackedChanges | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

if ($changedPaths.Count -gt $maxFiles) {
    throw "Autonomous increment touches $($changedPaths.Count) files; configured maximum is $maxFiles. Split the increment."
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
    if (Test-Path -LiteralPath $full -PathType Leaf) {
        $added += Get-LineCount -Path $full
    }
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

    $extension = [System.IO.Path]::GetExtension($relative).ToLowerInvariant()
    if ($sourceExtensions -notcontains $extension) { continue }

    $currentLines = Get-LineCount -Path $full
    if ($currentLines -gt $warningLines) {
        $warnings.Add("$relative is $currentLines lines; refactoring warning starts at $warningLines.")
    }

    if ($currentLines -le $maxSourceLines) { continue }

    & git cat-file -e "HEAD:$relative" 2>$null
    $existedAtHead = ($LASTEXITCODE -eq 0)
    if (-not $existedAtHead) {
        throw "New source file $relative is $currentLines lines; maximum is $maxSourceLines. Split by responsibility."
    }

    $baselineLines = @(& git show "HEAD:$relative").Count
    Assert-NativeSuccess "git show HEAD:$relative"
    if ($currentLines -ge $baselineLines) {
        throw "Oversized source file $relative grew or did not shrink ($baselineLines -> $currentLines lines). Files above $maxSourceLines lines must be reduced before adding responsibility."
    }

    $warnings.Add("Legacy oversized file $relative was reduced from $baselineLines to $currentLines lines; continue refactoring in later increments.")
}

$featureContractPath = Join-Path $ProjectRoot ".autobuild/feature_contract.json"
if (Test-Path -LiteralPath $featureContractPath) {
    $contract = Get-Content -LiteralPath $featureContractPath -Raw | ConvertFrom-Json
    foreach ($relative in @($contract.required_paths)) {
        $full = Join-Path $ProjectRoot ([string]$relative)
        if (-not (Test-Path -LiteralPath $full)) {
            throw "Feature preservation contract failed: required path is missing: $relative"
        }
    }

    foreach ($rule in @($contract.required_text)) {
        $relative = [string]$rule.path
        $pattern = [string]$rule.pattern
        $full = Join-Path $ProjectRoot $relative
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            throw "Feature preservation contract failed: required text file is missing: $relative"
        }
        $text = Get-Content -LiteralPath $full -Raw
        if (-not $text.Contains($pattern)) {
            throw "Feature preservation contract failed: '$pattern' is missing from $relative"
        }
    }
}

Write-Host "Autonomous quality guard passed."
Write-Host "  Files touched : $($changedPaths.Count) / $maxFiles"
Write-Host "  Changed lines : $totalChanged / $maxChangedLines ($added added, $deleted deleted)"
Write-Host "  Source ceiling: $maxSourceLines lines"
foreach ($warning in $warnings) {
    Write-Warning $warning
}
