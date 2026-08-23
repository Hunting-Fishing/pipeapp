$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Require-Port([int]$Port, [string]$Label) {
  $listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($null -eq $listener) {
    throw "$Label is not listening on port $Port. Start the formal emulator environment first."
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
[Environment]::CurrentDirectory = $repoRoot

$expectedBranch = 'design/formal-beautification-foundation'
$currentBranch = ((git branch --show-current | Out-String).Trim())
if ($currentBranch -ne $expectedBranch) {
  throw "Formal demo Auth verification requires $expectedBranch. Current branch: $currentBranch"
}

Write-Step 'Checking local Auth emulator'
Require-Port 19099 'Auth emulator'

$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:19099'
$env:GCLOUD_PROJECT = 'flutter-flow-pipe'
$env:GOOGLE_CLOUD_PROJECT = 'flutter-flow-pipe'

$verifier = Join-Path $repoRoot 'firebase\functions\scripts\verify_formal_demo_auth_passwords.mjs'
if (-not (Test-Path -LiteralPath $verifier)) {
  throw 'Direct formal demo Auth password verifier is missing.'
}

Write-Step 'Probing all four demo accounts with the real email/password Auth endpoint'
& node $verifier
if ($LASTEXITCODE -ne 0) {
  throw @"
Formal demo Auth password verification failed.
Do not open Flutter and retry passwords manually.
The Auth emulator is listening, but one or more deterministic demo credentials are not usable.
"@
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER FORMAL DEMO AUTH PASSED' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'VIP buyer password login: PASS' -ForegroundColor Green
Write-Host 'Standard buyer password login: PASS' -ForegroundColor Green
Write-Host 'Seller password login: PASS' -ForegroundColor Green
Write-Host 'Carrier password login: PASS' -ForegroundColor Green
