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
    # Use a normal non-login shell here. `bash -l` can rebuild PATH from profile
    # files and hide a freshly installed Windows Node runtime even though the
    # release scripts themselves inherit the current PowerShell environment.
    $bashProbe = (& $bash -c 'printf "%s\n" "$(node --version 2>/dev/null)" "$(npm --version 2>/dev/null)"' 2>$null)
    $bashVersion = $bashProbe | Select-Object -First 1
    $bashNpmVersion = $bashProbe | Select-Object -Skip 1 -First 1
    if (-not $bashVersion) {
        $nodePath = $node.Source
        throw "PIPE BUYER RELEASE ERROR: PowerShell resolves Node $powerShellVersion at '$nodePath', but Git Bash cannot resolve node from the inherited PATH. Open a new PowerShell window after installing/selecting Node 22. If it still fails, run: & 'C:\Program Files\Git\bin\bash.exe' -c 'echo \$PATH; command -v node; node --version' and record the output."
    }
    $bashVersion = $bashVersion.Trim()
    if ($bashVersion -notmatch '^v22\.') {
        throw "PIPE BUYER RELEASE ERROR: Git Bash resolves $bashVersion, but Firebase Functions requires Node.js 22. Fix PATH/runtime selection before continuing."
    }
    if (-not $bashNpmVersion) {
        throw "PIPE BUYER RELEASE ERROR: Git Bash resolves Node $bashVersion but cannot resolve npm. Repair the Node 22/npm installation before continuing."
    }

    Write-Host "Node preflight: PowerShell $powerShellVersion; Git Bash $bashVersion; npm $($bashNpmVersion.Trim())" -ForegroundColor Green
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
