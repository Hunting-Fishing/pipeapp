$ErrorActionPreference = 'Stop'

$authPort = 19099
$email = 'carrier.visual@pipebuyer.test'
$password = 'PipeBuyerDemo!2026'
$expectedUid = 'visual-carrier'

$listener = Get-NetTCPConnection -State Listen -LocalPort $authPort -ErrorAction SilentlyContinue |
  Select-Object -First 1
if ($null -eq $listener) {
  throw "Auth emulator is not listening on port $authPort."
}

$body = @{
  email = $email
  password = $password
  returnSecureToken = $true
} | ConvertTo-Json

Write-Host ''
Write-Host '==> Testing the exact carrier fixture against the Auth emulator' -ForegroundColor Cyan

try {
  $result = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$authPort/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=pipebuyer-local" `
    -ContentType 'application/json' `
    -Body $body
}
catch {
  throw "Carrier fixture authentication failed directly against the Auth emulator: $($_.Exception.Message)"
}

if ($result.localId -ne $expectedUid) {
  throw "Carrier fixture returned unexpected UID: $($result.localId)"
}
if ([string]::IsNullOrWhiteSpace($result.idToken)) {
  throw 'Carrier fixture did not return an ID token.'
}

Write-Host 'FORMAL CARRIER AUTH FIXTURE PASS' -ForegroundColor Green
Write-Host "Email: $email" -ForegroundColor DarkGray
Write-Host "UID: $($result.localId)" -ForegroundColor DarkGray
Write-Host "Auth emulator: 127.0.0.1:$authPort" -ForegroundColor DarkGray
