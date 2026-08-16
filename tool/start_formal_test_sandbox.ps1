param(
  [switch]$SeedOnly,
  [switch]$SkipSeed,
  [switch]$SkipSmokeTest
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$branch = (git branch --show-current).Trim()
if ($branch -ne 'design/formal-beautification-foundation') {
  throw "This launcher tests the formal Pipe Buyer UI branch. Current branch: $branch"
}

$baseLauncher = Join-Path $PSScriptRoot 'start_live_test_sandbox.ps1'
if (-not (Test-Path $baseLauncher)) {
  throw 'tool/start_live_test_sandbox.ps1 is missing. Pull the latest branch first.'
}

# The established integration sandbox predates the formal UI branch and has a
# branch-name guard for pipebuyer-premium-ui. Reuse the exact tested launcher
# rather than duplicating emulator ports, seeds, smoke checks or Flutter flags.
$source = Get-Content -LiteralPath $baseLauncher -Raw
$oldGuard = "if (`$branch -ne 'pipebuyer-premium-ui') {"
$newGuard = "if (`$branch -notin @('pipebuyer-premium-ui', 'design/formal-beautification-foundation')) {"
if (-not $source.Contains($oldGuard)) {
  throw 'The integration sandbox launcher guard changed. Review it before running the formal wrapper.'
}
$source = $source.Replace($oldGuard, $newGuard)

# Force the discovery timeout into the generated launcher process so the
# separate Firebase emulator PowerShell inherits it reliably on Windows.
$oldErrorPreference = "`$ErrorActionPreference = 'Stop'"
$newErrorPreference = "`$ErrorActionPreference = 'Stop'`r`n`$env:FUNCTIONS_DISCOVERY_TIMEOUT = '60'"
if (-not $source.Contains($oldErrorPreference)) {
  throw 'The integration launcher error-preference header changed. Review it before running the formal wrapper.'
}
$source = $source.Replace($oldErrorPreference, $newErrorPreference)

# A Functions emulator can bind its TCP port before every callable has finished
# discovery/registration. Retry the known marketplace callable instead of
# treating a transient "does not exist" response as a failed sandbox.
$oldCallableBlock = @'
  $headers = @{ Authorization = "Bearer $($signIn.idToken)" }
  $callable = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$functionsPort/$projectId/us-central1/syncAccountVerification" `
    -Headers $headers `
    -ContentType 'application/json' `
    -Body '{"data":{}}'

  if ($null -eq $callable.result) {
    throw 'The Functions emulator answered, but syncAccountVerification did not return a callable result.'
  }
'@
$newCallableBlock = @'
  $headers = @{ Authorization = "Bearer $($signIn.idToken)" }
  $callable = $null
  $callableDeadline = (Get-Date).AddSeconds(90)
  Write-Host 'Waiting for marketplace Functions callables to finish registering...' -ForegroundColor DarkGray
  do {
    try {
      $callable = Invoke-RestMethod `
        -Method Post `
        -Uri "http://127.0.0.1:$functionsPort/$projectId/us-central1/syncAccountVerification" `
        -Headers $headers `
        -ContentType 'application/json' `
        -Body '{"data":{}}'
      break
    }
    catch {
      $details = ""
      if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
        $details = [string]$_.ErrorDetails.Message
      }
      $message = [string]$_.Exception.Message
      $missingCallable = $details -match 'does not exist' -or $message -match 'does not exist'
      if (-not $missingCallable) {
        throw
      }
      Start-Sleep -Seconds 2
    }
  } while ((Get-Date) -lt $callableDeadline)

  if ($null -eq $callable -or $null -eq $callable.result) {
    throw 'syncAccountVerification did not register within 90 seconds. Read the SECOND PowerShell emulator window and send the first Functions error.'
  }
'@
if (-not $source.Contains($oldCallableBlock)) {
  throw 'The integration launcher callable smoke-test block changed. Review it before running the formal wrapper.'
}
$source = $source.Replace($oldCallableBlock, $newCallableBlock)

$generatedLauncher = Join-Path $PSScriptRoot '.start_live_test_sandbox.formal.generated.ps1'
Set-Content -LiteralPath $generatedLauncher -Value $source -Encoding UTF8

$arguments = @()
if ($SeedOnly) { $arguments += '-SeedOnly' }
if ($SkipSeed) { $arguments += '-SkipSeed' }
if ($SkipSmokeTest) { $arguments += '-SkipSmokeTest' }

# Firebase CLI uses a short default discovery window for Functions source
# analysis. The administrative agent and marketplace codebase can take longer
# on Windows even when their source is valid. This override is local only.
$previousDiscoveryTimeout = $env:FUNCTIONS_DISCOVERY_TIMEOUT
$env:FUNCTIONS_DISCOVERY_TIMEOUT = '60'

try {
  Write-Host "Firebase Functions discovery timeout: $env:FUNCTIONS_DISCOVERY_TIMEOUT seconds" -ForegroundColor DarkGray
  Write-Host 'Starting the established Pipe Buyer Auth/Firestore/Functions/Storage sandbox against the formal UI branch.' -ForegroundColor Cyan
  & powershell -ExecutionPolicy Bypass -File $generatedLauncher @arguments
  $exitCode = $LASTEXITCODE
  if ($null -eq $exitCode) { $exitCode = 0 }
  exit $exitCode
}
finally {
  if ($null -eq $previousDiscoveryTimeout) {
    Remove-Item Env:FUNCTIONS_DISCOVERY_TIMEOUT -ErrorAction SilentlyContinue
  } else {
    $env:FUNCTIONS_DISCOVERY_TIMEOUT = $previousDiscoveryTimeout
  }
  Remove-Item -LiteralPath $generatedLauncher -Force -ErrorAction SilentlyContinue
}
