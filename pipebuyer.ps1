[CmdletBinding()]
param(
    [ValidateSet('Prepare','Validate','Deploy','Probe','WebLegal','SyncWebhook','CreatePortal','Status')]
    [string]$Action = 'Status',

    [switch]$AllowDirty,
    [switch]$ConfirmControlledDeploy,
    [switch]$ConfirmWebLegalDeploy,
    [switch]$ConfirmWebhookSync,
    [switch]$ConfirmPortalCreate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Find-PipeBuyerBash {
    $command = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $candidates = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "$env:ProgramFiles\Git\usr\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }

    if ($candidates.Count -gt 0) { return $candidates[0] }
    throw 'PIPE BUYER RELEASE ERROR: Git Bash was not found. Install Git for Windows or add bash.exe to PATH.'
}

function Assert-Node22 {
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    if (-not $node) {
        throw "PIPE BUYER RELEASE ERROR: Node.js 22 is required but node.exe is not on PATH. Install the Node 22 Windows package (for winget: winget install --id OpenJS.NodeJS.22 -e --source winget), then close and reopen PowerShell before retrying."
    }

    $powerShellVersion = (& $node.Source --version).Trim()
    if ($powerShellVersion -notmatch '^v22\.') {
        throw "PIPE BUYER RELEASE ERROR: Firebase Functions requires Node.js 22, but PowerShell resolves $powerShellVersion at $($node.Source). Install/select Node 22 before continuing."
    }

    $bash = Find-PipeBuyerBash
    $bashVersion = (& $bash -lc 'node --version 2>/dev/null' 2>$null | Select-Object -First 1)
    if (-not $bashVersion) {
        throw "PIPE BUYER RELEASE ERROR: PowerShell can see Node $powerShellVersion, but Git Bash cannot resolve node. Close and reopen PowerShell after installing Node 22 so Git Bash inherits the updated PATH."
    }
    $bashVersion = $bashVersion.Trim()
    if ($bashVersion -notmatch '^v22\.') {
        throw "PIPE BUYER RELEASE ERROR: Git Bash resolves $bashVersion, but Firebase Functions requires Node.js 22. Fix PATH/runtime selection before continuing."
    }

    Write-Host "Node preflight: PowerShell $powerShellVersion; Git Bash $bashVersion" -ForegroundColor Green
}

if ($Action -in @('Validate','Deploy','Probe','WebLegal','SyncWebhook','CreatePortal')) {
    Assert-Node22
}

$controller = Join-Path $PSScriptRoot 'scripts\payments\pipebuyer_revenue_windows.ps1'
if (-not (Test-Path -LiteralPath $controller)) {
    throw "Pipe Buyer Windows revenue controller is missing: $controller"
}

$arguments = @{
    Action = $Action
    RepoRoot = $PSScriptRoot
}
if ($AllowDirty) { $arguments.AllowDirty = $true }
if ($ConfirmControlledDeploy) { $arguments.ConfirmControlledDeploy = $true }
if ($ConfirmWebLegalDeploy) { $arguments.ConfirmWebLegalDeploy = $true }
if ($ConfirmWebhookSync) { $arguments.ConfirmWebhookSync = $true }
if ($ConfirmPortalCreate) { $arguments.ConfirmPortalCreate = $true }

& $controller @arguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
