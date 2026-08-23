Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-AutonomousControlFingerprint {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][object]$Config
    )

    $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    if ($null -eq $Config.graduation -or $null -eq $Config.graduation.control_paths) {
        throw "Project configuration is missing graduation.control_paths."
    }

    $records = New-Object System.Collections.Generic.List[string]
    foreach ($relativeRaw in @($Config.graduation.control_paths | Sort-Object -Unique)) {
        $relative = [string]$relativeRaw
        if ([string]::IsNullOrWhiteSpace($relative)) {
            throw "Graduation control path cannot be empty."
        }
        $full = Join-Path $ProjectRoot $relative
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            throw "Graduation control file is missing: $relative"
        }
        $hash = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()
        $normalized = $relative.Replace("\", "/")
        $records.Add("$normalized`:$hash")
    }

    $joined = ($records -join "`n") + "`n"
    $bytes = [Text.Encoding]::UTF8.GetBytes($joined)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-AutonomousCodexVersion {
    $command = Get-Command codex -ErrorAction SilentlyContinue
    if (-not $command) { return "unavailable" }
    $output = (& codex --version 2>&1) -join " "
    if ($LASTEXITCODE -ne 0) { return "unavailable" }
    return $output.Trim()
}

function Assert-AutonomousGraduationEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][object]$Config
    )

    if ($null -eq $Config.graduation -or -not [bool]$Config.graduation.required) {
        return
    }

    $evidenceRelative = [string]$Config.graduation.evidence_path
    if ([string]::IsNullOrWhiteSpace($evidenceRelative)) {
        throw "Graduation is required but graduation.evidence_path is empty."
    }
    $evidencePath = Join-Path $ProjectRoot $evidenceRelative
    if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
        throw "Autonomous development is not graduated for the current controls. Run .\tool\autonomous_graduation.ps1 first."
    }

    try { $evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json }
    catch { throw "Autonomous graduation evidence is unreadable. Re-run .\tool\autonomous_graduation.ps1." }

    if ([string]$evidence.status -ne "passed") {
        throw "Autonomous graduation evidence is not marked passed. Re-run graduation."
    }

    $currentFingerprint = Get-AutonomousControlFingerprint -ProjectRoot $ProjectRoot -Config $Config
    if ([string]$evidence.control_fingerprint -ne $currentFingerprint) {
        throw "Autonomous controls changed after graduation. Re-run .\tool\autonomous_graduation.ps1 before starting workers."
    }

    $currentCodex = Get-AutonomousCodexVersion
    if ([string]$evidence.codex_version -ne $currentCodex) {
        throw "Codex CLI version changed after graduation ($($evidence.codex_version) -> $currentCodex). Re-run graduation."
    }

    $maximumAgeHours = [double]$Config.graduation.max_age_hours
    if ($maximumAgeHours -gt 0) {
        try { $graduatedAt = [DateTimeOffset]::Parse([string]$evidence.graduated_at) }
        catch { throw "Graduation timestamp is invalid. Re-run graduation." }
        if (([DateTimeOffset]::Now - $graduatedAt).TotalHours -gt $maximumAgeHours) {
            throw "Autonomous graduation evidence is older than $maximumAgeHours hour(s). Re-run graduation."
        }
    }
}
