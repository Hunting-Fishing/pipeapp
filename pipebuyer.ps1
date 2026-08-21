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
