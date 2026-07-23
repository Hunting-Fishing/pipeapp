param()

$ErrorActionPreference = 'Stop'

function Assert-NativeSuccess([string]$Operation) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Operation failed with exit code $LASTEXITCODE."
  }
}

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $workspace

$java = Get-Command java -ErrorAction SilentlyContinue
if (-not $java) {
  $androidStudioJdk = 'C:\Program Files\Android\Android Studio\jbr'
  if (Test-Path (Join-Path $androidStudioJdk 'bin\java.exe')) {
    $env:JAVA_HOME = $androidStudioJdk
    $env:Path = "$androidStudioJdk\bin;$env:Path"
    $java = Get-Command java -ErrorAction SilentlyContinue
  }
}
if (-not $java) {
  throw 'Callable emulator integration requires Java 21 or newer.'
}

$nodeVersion = (node --version).TrimStart('v')
Assert-NativeSuccess 'Node runtime inspection'
$nodeMajor = [int]($nodeVersion.Split('.')[0])
$env:PIPE_ENFORCE_APP_CHECK = 'false'
$arguments = @(
  'emulators:exec',
  '--project', 'demo-pipe-buyer-integration',
  '--config', 'firebase.json',
  '--only', 'auth,firestore,functions',
  'node firebase/functions/integration/callable_integration.mjs'
)

if ($nodeMajor -eq 22 -and (Get-Command firebase -ErrorAction SilentlyContinue)) {
  firebase @arguments
} else {
  Write-Host "Using isolated Node 22 for Functions integration (host is $nodeVersion)."
  npx --yes -p node@22 -p firebase-tools@15.24.0 firebase @arguments
}
Assert-NativeSuccess 'Authenticated callable emulator integration'
