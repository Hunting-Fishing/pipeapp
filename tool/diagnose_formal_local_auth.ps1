param(
  [string]$Email = 'carrier.visual@pipebuyer.test',
  [string]$Password = 'PipeBuyerDemo!2026'
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Require-Port([int]$Port, [string]$Label) {
  $listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($null -eq $listener) {
    throw "$Label is not listening on port $Port."
  }
  return $listener
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current | Out-String).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "This diagnostic is for design/formal-beautification-foundation. Current branch: $branch"
}

Write-Step 'Checking local emulator and Flutter listener ports'
$authListener = Require-Port 19099 'Auth emulator'
$webListener = Require-Port 5050 'Pipe Buyer Flutter web client'
Write-Host "Auth emulator PID: $($authListener.OwningProcess)" -ForegroundColor DarkGray
Write-Host "Flutter web PID: $($webListener.OwningProcess)" -ForegroundColor DarkGray

Write-Step 'Proving the exact fixture credentials against the Auth emulator'
$body = @{
  email = $Email.Trim()
  password = $Password
  returnSecureToken = $true
} | ConvertTo-Json

try {
  $result = Invoke-RestMethod `
    -Method Post `
    -Uri 'http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=pipebuyer-local' `
    -ContentType 'application/json' `
    -Body $body
}
catch {
  Write-Host 'AUTH EMULATOR CREDENTIAL CHECK: FAIL' -ForegroundColor Red
  if ($null -ne $_.ErrorDetails -and -not [string]::IsNullOrWhiteSpace($_.ErrorDetails.Message)) {
    Write-Host $_.ErrorDetails.Message -ForegroundColor Red
  } else {
    Write-Host $_.Exception.Message -ForegroundColor Red
  }
  throw 'Exact fixture credentials were rejected by the local Auth emulator. Do not change Flutter Auth code yet.'
}

if ([string]::IsNullOrWhiteSpace($result.localId) -or
    [string]::IsNullOrWhiteSpace($result.idToken)) {
  throw 'Auth emulator returned an incomplete sign-in response.'
}

Write-Host 'AUTH EMULATOR CREDENTIAL CHECK: PASS' -ForegroundColor Green
Write-Host "Email: $($Email.Trim())" -ForegroundColor White
Write-Host "Local UID: $($result.localId)" -ForegroundColor White

Write-Step 'Checking both browser origins served by the current Flutter listener'
foreach ($url in @('http://127.0.0.1:5050', 'http://localhost:5050')) {
  try {
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
    Write-Host "$url -> HTTP $($response.StatusCode)" -ForegroundColor Green
  }
  catch {
    Write-Host "$url -> REQUEST FAILED: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

Write-Host ''
Write-Host 'CANONICAL LOCAL ACCEPTANCE ORIGIN: http://127.0.0.1:5050' -ForegroundColor Green
Write-Host 'Do not use localhost:5050 for formal acceptance.' -ForegroundColor Yellow
Write-Host 'If the REST credential check passes but the Flutter sign-in form rejects the same manually typed credentials at 127.0.0.1:5050, capture the browser error and Flutter terminal output without reseeding.' -ForegroundColor Yellow
