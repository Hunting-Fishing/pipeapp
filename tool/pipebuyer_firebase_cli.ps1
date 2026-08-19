# Windows PowerShell 5.1 compatibility rule: keep this file ASCII-only.
$ErrorActionPreference = 'Stop'

function Get-PipeBuyerFirebaseCliMode {
  if (Get-Command 'firebase' -ErrorAction SilentlyContinue) {
    return 'global'
  }
  if (Get-Command 'npx' -ErrorAction SilentlyContinue) {
    return 'npx'
  }
  throw 'STOP: Firebase CLI is unavailable. Neither firebase nor npx is on PATH.'
}

function Invoke-PipeBuyerFirebaseCli {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,
    [string]$FailureMessage = 'Firebase CLI command failed.'
  )

  $mode = Get-PipeBuyerFirebaseCliMode
  if ($mode -eq 'global') {
    & firebase @Arguments
  } else {
    & npx --yes firebase-tools @Arguments
  }

  if ($LASTEXITCODE -ne 0) {
    throw "STOP: $FailureMessage"
  }
}

function Assert-PipeBuyerFirebaseCli {
  $mode = Get-PipeBuyerFirebaseCliMode
  if ($mode -eq 'global') {
    Write-Host 'Firebase CLI resolution: installed firebase command' -ForegroundColor DarkGray
  } else {
    Write-Host 'Firebase CLI resolution: npx --yes firebase-tools fallback' -ForegroundColor DarkGray
  }

  Invoke-PipeBuyerFirebaseCli `
    -Arguments @('--version') `
    -FailureMessage 'Firebase CLI was found but could not start.'

  Write-Host 'Firebase CLI preflight: PASS' -ForegroundColor Green
}
