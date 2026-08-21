[CmdletBinding()]
param(
    [ValidateSet('Prepare','Validate','Deploy','Probe','WebLegal','SyncWebhook','CreatePortal','Status')]
    [string]$Action = 'Status',

    [string]$RepoRoot = 'D:\Game Development\pipeapp',

    [switch]$AllowDirty,
    [switch]$ConfirmControlledDeploy,
    [switch]$ConfirmWebLegalDeploy,
    [switch]$ConfirmWebhookSync,
    [switch]$ConfirmPortalCreate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ExpectedRepo = 'Hunting-Fishing/pipeapp'
$ExpectedBranch = 'fix/dispatch-checkout-hardening'

function Fail([string]$Message) {
    throw "PIPE BUYER RELEASE ERROR: $Message"
}

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Fail "Required command '$Name' is not installed or is not on PATH."
    }
}

function Find-Bash {
    $command = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $candidates = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "$env:ProgramFiles\Git\usr\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }

    if ($candidates.Count -gt 0) { return $candidates[0] }
    Fail "Git Bash was not found. Install Git for Windows or add bash.exe to PATH."
}

function Enter-Repo {
    if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) {
        Fail "Repository folder not found: $RepoRoot"
    }
    Set-Location -LiteralPath $RepoRoot

    if (-not (Test-Path -LiteralPath 'firebase.json')) {
        Fail "firebase.json is missing. '$RepoRoot' is not the Pipe Buyer repository root."
    }
    if (-not (Test-Path -LiteralPath 'firebase/functions/package.json')) {
        Fail "firebase/functions/package.json is missing."
    }
    if (-not (Test-Path -LiteralPath 'scripts/payments/dispatch_revenue_local_release.sh')) {
        Fail "Payment release scripts are missing. Pull the latest $ExpectedBranch first."
    }
}

function Get-RemoteRepo {
    $url = (& git remote get-url origin 2>$null).Trim()
    if (-not $url) { return '' }
    if ($url -match 'github\.com[:/](?<repo>[^/]+/[^/.]+)(?:\.git)?$') {
        return $Matches.repo
    }
    return $url
}

function Assert-RepoIdentity {
    Require-Command 'git'
    $repo = Get-RemoteRepo
    if ($repo -ne $ExpectedRepo) {
        Fail "origin points to '$repo', expected '$ExpectedRepo'. Refusing payment release work in the wrong repository."
    }
}

function Get-Branch {
    return (& git branch --show-current).Trim()
}

function Assert-CleanForMutation {
    $dirty = (& git status --porcelain) -join "`n"
    if ($dirty -and -not $AllowDirty) {
        Fail "Working tree has uncommitted changes. Commit/stash them first, or deliberately pass -AllowDirty."
    }
}

function Assert-ReleaseBranch {
    $branch = Get-Branch
    if ($branch -ne $ExpectedBranch) {
        Fail "Current branch is '$branch'. Expected '$ExpectedBranch'. Run -Action Prepare first."
    }
}

function Show-Status {
    Enter-Repo
    Assert-RepoIdentity
    $branch = Get-Branch
    $head = (& git rev-parse --short HEAD).Trim()
    $dirty = (& git status --porcelain) -join "`n"

    Write-Host ''
    Write-Host 'PIPE BUYER LOCAL REVENUE WORKSTATION' -ForegroundColor Cyan
    Write-Host "Repository : $RepoRoot"
    Write-Host "Origin     : $ExpectedRepo"
    Write-Host "Branch     : $branch"
    Write-Host "Commit     : $head"
    Write-Host "Tree       : $(if ($dirty) { 'DIRTY' } else { 'CLEAN' })"
    Write-Host "Firebase   : flutter-flow-pipe"
    Write-Host 'GitHub Actions billing is not used by this controller.'
    Write-Host ''
}

function Prepare-Repo {
    Enter-Repo
    Assert-RepoIdentity
    Assert-CleanForMutation

    Write-Host 'Fetching Pipe Buyer repository...' -ForegroundColor Cyan
    & git fetch origin --prune
    if ($LASTEXITCODE -ne 0) { Fail 'git fetch failed.' }

    $branch = Get-Branch
    if ($branch -ne $ExpectedBranch) {
        Write-Host "Switching to $ExpectedBranch..." -ForegroundColor Cyan
        & git checkout $ExpectedBranch
        if ($LASTEXITCODE -ne 0) { Fail "Could not checkout $ExpectedBranch." }
    }

    Write-Host 'Fast-forwarding to the latest remote branch...' -ForegroundColor Cyan
    & git pull --ff-only origin $ExpectedBranch
    if ($LASTEXITCODE -ne 0) {
        Fail 'Fast-forward pull failed. No merge was attempted. Resolve the branch state before continuing.'
    }

    Show-Status
}

function Invoke-BashScript([string]$Script, [string[]]$Arguments = @()) {
    Enter-Repo
    Assert-RepoIdentity
    Assert-ReleaseBranch
    $bash = Find-Bash

    Write-Host "Running $Script $($Arguments -join ' ')" -ForegroundColor Cyan
    & $bash $Script @Arguments
    if ($LASTEXITCODE -ne 0) {
        Fail "$Script failed with exit code $LASTEXITCODE. Stop here and repair the actual reported failure before retrying."
    }
}

function Validate-Release {
    Invoke-BashScript 'scripts/payments/dispatch_revenue_local_release.sh' @('validate')
}

function Deploy-Functions {
    if (-not $ConfirmControlledDeploy) {
        Fail 'Code deployment requires -ConfirmControlledDeploy. This deploys code but does not enable customer charging.'
    }
    Assert-CleanForMutation
    $env:PIPEBUYER_CONTROLLED_DEPLOY = 'YES'
    if ($AllowDirty) { $env:PIPEBUYER_ALLOW_DIRTY_DEPLOY = 'YES' }
    try {
        Invoke-BashScript 'scripts/payments/dispatch_revenue_local_release.sh' @('deploy')
    } finally {
        Remove-Item Env:PIPEBUYER_CONTROLLED_DEPLOY -ErrorAction SilentlyContinue
        Remove-Item Env:PIPEBUYER_ALLOW_DIRTY_DEPLOY -ErrorAction SilentlyContinue
    }
}

function Probe-Stripe {
    Invoke-BashScript 'scripts/payments/dispatch_revenue_local_release.sh' @('probe')
}

function Deploy-WebLegal {
    if (-not $ConfirmWebLegalDeploy) {
        Fail 'Hosting/legal deployment requires -ConfirmWebLegalDeploy after reviewing the current Terms and Privacy changes.'
    }
    Assert-CleanForMutation
    $env:PIPEBUYER_DEPLOY_WEB_LEGAL = 'YES'
    if ($AllowDirty) { $env:PIPEBUYER_ALLOW_DIRTY_DEPLOY = 'YES' }
    try {
        Invoke-BashScript 'scripts/payments/deploy_dispatch_web_legal_local.sh'
    } finally {
        Remove-Item Env:PIPEBUYER_DEPLOY_WEB_LEGAL -ErrorAction SilentlyContinue
        Remove-Item Env:PIPEBUYER_ALLOW_DIRTY_DEPLOY -ErrorAction SilentlyContinue
    }
}

function Sync-Webhook {
    if (-not $ConfirmWebhookSync) {
        Fail 'Live webhook synchronization requires -ConfirmWebhookSync and must only run after the new webhook Function is deployed.'
    }
    $env:PIPEBUYER_SYNC_LIVE_WEBHOOK = 'YES'
    try {
        Invoke-BashScript 'scripts/payments/sync_dispatch_stripe_webhook_local.sh'
    } finally {
        Remove-Item Env:PIPEBUYER_SYNC_LIVE_WEBHOOK -ErrorAction SilentlyContinue
    }
}

function Create-Portal {
    if (-not $ConfirmPortalCreate) {
        Fail 'Live Stripe Portal configuration creation requires -ConfirmPortalCreate after the current Terms/Privacy pages are live and reviewed.'
    }
    $env:PIPEBUYER_CREATE_LIVE_PORTAL_CONFIG = 'YES'
    try {
        Invoke-BashScript 'scripts/payments/create_dispatch_portal_config_local.sh'
    } finally {
        Remove-Item Env:PIPEBUYER_CREATE_LIVE_PORTAL_CONFIG -ErrorAction SilentlyContinue
    }
}

Require-Command 'git'
Enter-Repo
Assert-RepoIdentity

switch ($Action) {
    'Prepare'      { Prepare-Repo }
    'Validate'     { Validate-Release }
    'Deploy'       { Deploy-Functions }
    'Probe'        { Probe-Stripe }
    'WebLegal'     { Deploy-WebLegal }
    'SyncWebhook'  { Sync-Webhook }
    'CreatePortal' { Create-Portal }
    'Status'       { Show-Status }
}

Write-Host "Completed action: $Action" -ForegroundColor Green
