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
  throw '10-Agent Wave 2 stress fleet requires Java 21 or newer.'
}

try {
  $nodeVersion = (node --version).TrimStart('v')
  Assert-NativeSuccess 'Node runtime inspection'
  $nodeMajor = [int]($nodeVersion.Split('.')[0])
  $env:PIPE_ENFORCE_APP_CHECK = 'false'
  $env:FUNCTIONS_DISCOVERY_TIMEOUT = '45000'
  $env:NODE_OPTIONS = '--max-old-space-size=4096'
  $arguments = @(
    'emulators:exec',
    '--project', 'demo-pipe-buyer-wave2',
    '--config', 'firebase.sandbox.json',
    '--only', 'auth,firestore,functions,storage',
    'node firebase/functions/integration/ten_agent_wave2_stress_fleet.mjs'
  )

  if ($nodeMajor -eq 22 -and (Get-Command firebase -ErrorAction SilentlyContinue)) {
    firebase @arguments
  } else {
    Write-Host "Using Firebase Tools for 10-Agent Wave 2 Stress Fleet integration (host is $nodeVersion)."
    npx --yes firebase-tools@15.25.0 @arguments
  }
  Assert-NativeSuccess '10-Agent Wave 2 Stress Fleet emulator simulation'
} finally {
}
