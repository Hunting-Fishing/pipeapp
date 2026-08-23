Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Escape-SingleQuotedPowerShell {
    param([string]$Value)
    return $Value.Replace("'", "''")
}

function Stop-ProcessTreeSafe {
    param([System.Diagnostics.Process]$Process)
    if ($null -eq $Process -or $Process.HasExited) { return }

    if ($env:OS -eq "Windows_NT") {
        $taskkill = Get-Command taskkill.exe -ErrorAction SilentlyContinue
        if ($taskkill) {
            & $taskkill.Source /PID $Process.Id /T /F 2>$null | Out-Null
            return
        }
    }

    try { $Process.Kill() } catch { }
}

function Invoke-TimedPowerShell {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptText,
        [Parameter(Mandatory = $true)][int]$TimeoutMinutes,
        [Parameter(Mandatory = $true)][string]$LogPath,
        [int]$NoOutputMinutes = 0
    )

    $shell = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $shell) { $shell = Get-Command powershell.exe -ErrorAction SilentlyContinue }
    if (-not $shell) { throw "PowerShell is required for autonomous execution." }

    $stdoutPath = "$LogPath.stdout"
    $stderrPath = "$LogPath.stderr"
    foreach ($path in @($stdoutPath, $stderrPath, $LogPath)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }

    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ScriptText))
    $process = Start-Process `
        -FilePath $shell.Source `
        -ArgumentList @("-NoProfile", "-EncodedCommand", $encoded) `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru `
        -NoNewWindow

    $started = Get-Date
    $lastActivity = $started
    $lastLength = 0L
    $timedOut = $false
    $stalled = $false

    while (-not $process.HasExited) {
        Start-Sleep -Seconds 5
        $length = 0L
        foreach ($path in @($stdoutPath, $stderrPath)) {
            if (Test-Path -LiteralPath $path) {
                $length += (Get-Item -LiteralPath $path).Length
            }
        }

        if ($length -ne $lastLength) {
            $lastLength = $length
            $lastActivity = Get-Date
        }
        if (((Get-Date) - $started).TotalMinutes -ge $TimeoutMinutes) {
            $timedOut = $true
            Stop-ProcessTreeSafe -Process $process
            break
        }
        if ($NoOutputMinutes -gt 0 -and ((Get-Date) - $lastActivity).TotalMinutes -ge $NoOutputMinutes) {
            $stalled = $true
            Stop-ProcessTreeSafe -Process $process
            break
        }
    }

    try { $process.WaitForExit() } catch { }

    $combined = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath $stdoutPath) {
        foreach ($line in @(Get-Content -LiteralPath $stdoutPath)) { $combined.Add($line) }
    }
    if (Test-Path -LiteralPath $stderrPath) {
        foreach ($line in @(Get-Content -LiteralPath $stderrPath)) { $combined.Add("[stderr] $line") }
    }
    $combined | Set-Content -LiteralPath $LogPath
    foreach ($line in $combined) { Write-Host $line }

    return [pscustomobject]@{
        ExitCode = if ($timedOut -or $stalled) { 124 } else { $process.ExitCode }
        TimedOut = $timedOut
        Stalled = $stalled
        LogPath = $LogPath
    }
}

function Invoke-CodexStructured {
    param(
        [string]$Prompt,
        [string]$ProjectRoot,
        [string]$SchemaPath,
        [string]$ResultPath,
        [string]$LogPath,
        [int]$TimeoutMinutes,
        [int]$NoOutputMinutes,
        [ValidateSet("workspace-write", "read-only")][string]$Sandbox
    )

    if (Test-Path -LiteralPath $ResultPath) { Remove-Item -LiteralPath $ResultPath -Force }
    $promptPath = "$ResultPath.prompt.md"
    Set-Content -LiteralPath $promptPath -Value $Prompt -Encoding UTF8

    $rootEsc = Escape-SingleQuotedPowerShell $ProjectRoot
    $schemaEsc = Escape-SingleQuotedPowerShell $SchemaPath
    $resultEsc = Escape-SingleQuotedPowerShell $ResultPath
    $promptEsc = Escape-SingleQuotedPowerShell $promptPath
    $sandboxEsc = Escape-SingleQuotedPowerShell $Sandbox
    $script = @"
`$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath '$rootEsc'
`$prompt = Get-Content -LiteralPath '$promptEsc' -Raw
& codex exec --sandbox '$sandboxEsc' --json --output-schema '$schemaEsc' -o '$resultEsc' `$prompt
exit `$LASTEXITCODE
"@

    return Invoke-TimedPowerShell `
        -ScriptText $script `
        -TimeoutMinutes $TimeoutMinutes `
        -NoOutputMinutes $NoOutputMinutes `
        -LogPath $LogPath
}

function Invoke-CodexWorker {
    param(
        [string]$Prompt,
        [string]$ProjectRoot,
        [string]$SchemaPath,
        [string]$ResultPath,
        [string]$LogPath,
        [int]$TimeoutMinutes,
        [int]$NoOutputMinutes
    )

    return Invoke-CodexStructured `
        -Prompt $Prompt `
        -ProjectRoot $ProjectRoot `
        -SchemaPath $SchemaPath `
        -ResultPath $ResultPath `
        -LogPath $LogPath `
        -TimeoutMinutes $TimeoutMinutes `
        -NoOutputMinutes $NoOutputMinutes `
        -Sandbox "workspace-write"
}

function Invoke-CodexReviewer {
    param(
        [string]$Prompt,
        [string]$ProjectRoot,
        [string]$SchemaPath,
        [string]$ResultPath,
        [string]$LogPath,
        [int]$TimeoutMinutes,
        [int]$NoOutputMinutes
    )

    return Invoke-CodexStructured `
        -Prompt $Prompt `
        -ProjectRoot $ProjectRoot `
        -SchemaPath $SchemaPath `
        -ResultPath $ResultPath `
        -LogPath $LogPath `
        -TimeoutMinutes $TimeoutMinutes `
        -NoOutputMinutes $NoOutputMinutes `
        -Sandbox "read-only"
}

function Invoke-ProjectCommand {
    param(
        [string]$ProjectRoot,
        [string]$CommandText,
        [int]$TimeoutMinutes,
        [string]$LogPath
    )

    $rootEsc = Escape-SingleQuotedPowerShell $ProjectRoot
    $commandEsc = Escape-SingleQuotedPowerShell $CommandText
    $script = @"
`$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath '$rootEsc'
try {
    Invoke-Expression '$commandEsc'
    if (`$LASTEXITCODE -and `$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }
    exit 0
}
catch {
    Write-Error (`$_ | Out-String)
    exit 1
}
"@

    return Invoke-TimedPowerShell -ScriptText $script -TimeoutMinutes $TimeoutMinutes -LogPath $LogPath
}
