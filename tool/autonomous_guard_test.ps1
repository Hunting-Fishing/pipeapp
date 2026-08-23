[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$guardPath = Join-Path $projectRoot "tool/autonomous_guard.ps1"
if (-not (Test-Path -LiteralPath $guardPath)) { throw "Guard not found: $guardPath" }

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "pipe-autobuild-guard-test-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Invoke-GitTemp {
    param([string[]]$Args)
    & git -C $tempRoot @Args | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "temp git $($Args -join ' ') failed" }
}

function Write-Result {
    param(
        [string]$Risk = "medium",
        [bool]$Dependency = $false,
        [bool]$Data = $false,
        [bool]$Provider = $false,
        [bool]$Security = $false,
        [bool]$Billing = $false,
        [string]$Rollback = "Revert the branch commit; no live state is changed."
    )

    $result = [ordered]@{
        risk_level = $Risk
        knowledge_used = @("docs/QUALITY_GATES.md")
        compatibility_checks = @("critical feature anchor preserved")
        dependency_change = $Dependency
        data_change = $Data
        provider_change = $Provider
        security_change = $Security
        billing_change = $Billing
        rollback_notes = $Rollback
        verification = @(
            [ordered]@{ command = "focused-test"; result = "passed"; evidence = "fault-injection fixture" }
        )
    }
    $path = Join-Path $tempRoot "result.json"
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Reset-Fixture {
    Invoke-GitTemp @("reset", "--hard", "HEAD")
    Invoke-GitTemp @("clean", "-fd")
}

function Expect-Guard {
    param([string]$Name, [bool]$ShouldPass, [string]$ResultPath)
    $passed = $true
    $message = ""
    try { & $guardPath -ProjectRoot $tempRoot -ResultPath $ResultPath *> $null }
    catch { $passed = $false; $message = $_.Exception.Message }
    if ($passed -ne $ShouldPass) {
        throw "Guard test '$Name' expected pass=$ShouldPass but pass=$passed. $message"
    }
    Write-Host "PASS guard fault test: $Name"
}

try {
    New-Item -ItemType Directory -Path (Join-Path $tempRoot ".autobuild") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot "lib") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot "docs") -Force | Out-Null

    $config = @{
        risk_policy = ".autobuild/risk_policy.json"
        quality = @{
            max_files_touched = 12
            max_changed_lines = 800
            max_source_lines = 600
            refactor_warning_lines = 450
            max_document_lines = 600
            source_extensions = @(".dart", ".ps1", ".js")
            generated_path_markers = @("/generated/", ".g.dart")
        }
    }
    $config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $tempRoot ".autobuild/project.json") -Encoding UTF8

    $risk = @{
        critical_changes_allowed = $false
        protected_governance_paths = @("docs/QUALITY_GATES.md")
        forbidden_path_patterns = @("(^|/)\\.env($|\\.)", "service[-_]?account.*\\.json$")
        secret_content_patterns = @("sk_live_[A-Za-z0-9]{16,}", "-----BEGIN (RSA |EC |OPENSSH |)?PRIVATE KEY-----")
        path_risk_rules = @(
            @{ risk = "high"; pattern = "pubspec\\.ya?ml$"; reason = "dependency change" },
            @{ risk = "medium"; pattern = "(^|/)lib/"; reason = "application behavior" }
        )
        dependency_path_patterns = @("pubspec\\.ya?ml$")
        data_path_patterns = @("schema|migration|backfill")
        security_path_patterns = @("auth|rules")
        billing_path_patterns = @("payment|billing|stripe")
        provider_path_patterns = @("provider|stripe|firebase")
    }
    $risk | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $tempRoot ".autobuild/risk_policy.json") -Encoding UTF8

    @{
        required_paths = @("lib/safe.dart")
        required_text = @(@{ path = "lib/safe.dart"; pattern = "SAFE_ANCHOR" })
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $tempRoot ".autobuild/feature_contract.json") -Encoding UTF8

    @("// SAFE_ANCHOR", "void safeFeature() {}") | Set-Content -LiteralPath (Join-Path $tempRoot "lib/safe.dart")
    "# Feature Registry" | Set-Content -LiteralPath (Join-Path $tempRoot "docs/FEATURE_REGISTRY.md")
    "# Quality Gates" | Set-Content -LiteralPath (Join-Path $tempRoot "docs/QUALITY_GATES.md")

    Invoke-GitTemp @("init")
    Invoke-GitTemp @("config", "user.email", "autobuild-test@example.invalid")
    Invoke-GitTemp @("config", "user.name", "Autobuild Test")
    Invoke-GitTemp @("add", "-A")
    Invoke-GitTemp @("commit", "-m", "baseline")

    Add-Content -LiteralPath (Join-Path $tempRoot "lib/safe.dart") -Value "// bounded change"
    $resultPath = Write-Result -Risk "medium"
    Expect-Guard -Name "valid-medium-change" -ShouldPass $true -ResultPath $resultPath
    Reset-Fixture

    Add-Content -LiteralPath (Join-Path $tempRoot "lib/safe.dart") -Value "// bounded change"
    $resultPath = Write-Result -Risk "low"
    Expect-Guard -Name "risk-underclassification" -ShouldPass $false -ResultPath $resultPath
    Reset-Fixture

    1..601 | ForEach-Object { "// line $_" } | Set-Content -LiteralPath (Join-Path $tempRoot "lib/oversized.dart")
    $resultPath = Write-Result -Risk "medium"
    Expect-Guard -Name "new-source-over-600" -ShouldPass $false -ResultPath $resultPath
    Reset-Fixture

    $prefix = "sk" + "_live_"
    $fakeSecret = $prefix + ("A" * 26)
    "token=$fakeSecret" | Set-Content -LiteralPath (Join-Path $tempRoot "docs/secret.md")
    $resultPath = Write-Result -Risk "low"
    Expect-Guard -Name "secret-content" -ShouldPass $false -ResultPath $resultPath
    Reset-Fixture

    "DO_NOT_COMMIT=1" | Set-Content -LiteralPath (Join-Path $tempRoot ".env")
    $resultPath = Write-Result -Risk "low"
    Expect-Guard -Name "forbidden-env-path" -ShouldPass $false -ResultPath $resultPath
    Reset-Fixture

    "name: fixture" | Set-Content -LiteralPath (Join-Path $tempRoot "pubspec.yaml")
    $resultPath = Write-Result -Risk "high" -Dependency $false
    Expect-Guard -Name "dependency-metadata-required" -ShouldPass $false -ResultPath $resultPath
    Reset-Fixture

    "name: fixture" | Set-Content -LiteralPath (Join-Path $tempRoot "pubspec.yaml")
    $resultPath = Write-Result -Risk "high" -Dependency $true
    Expect-Guard -Name "declared-high-risk-dependency" -ShouldPass $true -ResultPath $resultPath
    Reset-Fixture

    Add-Content -LiteralPath (Join-Path $tempRoot "docs/FEATURE_REGISTRY.md") -Value "bounded doc change"
    $resultPath = Write-Result -Risk "critical"
    Expect-Guard -Name "critical-risk-human-only" -ShouldPass $false -ResultPath $resultPath
    Reset-Fixture

    "void safeFeature() {}" | Set-Content -LiteralPath (Join-Path $tempRoot "lib/safe.dart")
    $resultPath = Write-Result -Risk "medium"
    Expect-Guard -Name "feature-anchor-removal" -ShouldPass $false -ResultPath $resultPath
    Reset-Fixture

    1..601 | ForEach-Object { "documentation line $_" } | Set-Content -LiteralPath (Join-Path $tempRoot "docs/huge.md")
    $resultPath = Write-Result -Risk "low"
    Expect-Guard -Name "new-doc-over-600" -ShouldPass $false -ResultPath $resultPath
    Reset-Fixture

    Add-Content -LiteralPath (Join-Path $tempRoot "lib/safe.dart") -Value "<<<<<<< ours"
    $resultPath = Write-Result -Risk "medium"
    Expect-Guard -Name "conflict-marker" -ShouldPass $false -ResultPath $resultPath
    Reset-Fixture

    Add-Content -LiteralPath (Join-Path $tempRoot "docs/QUALITY_GATES.md") -Value "weaken the gate"
    $resultPath = Write-Result -Risk "high"
    Expect-Guard -Name "governance-self-modification" -ShouldPass $false -ResultPath $resultPath
    Reset-Fixture

    Write-Host "Autonomous guard fault-injection suite passed."
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
