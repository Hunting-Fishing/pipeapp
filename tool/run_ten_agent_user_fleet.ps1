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
  throw '10-Agent emulator fleet requires Java 21 or newer.'
}

$tempConfigPath = Join-Path $workspace 'firebase.fleet-emulators.tmp.json'
$baseConfig = Get-Content -Raw (Join-Path $workspace 'firebase.json') | ConvertFrom-Json
$baseConfig.emulators.auth.port = 19099
$baseConfig.emulators.firestore.port = 18080
$baseConfig.emulators.functions.port = 15001
$baseConfig.emulators.storage.port = 19199
$baseConfig.emulators.ui.enabled = $false
$baseConfig | ConvertTo-Json -Depth 20 | Set-Content -Path $tempConfigPath -Encoding UTF8

try {
  $nodeVersion = (node --version).TrimStart('v')
  Assert-NativeSuccess 'Node runtime inspection'
  $nodeMajor = [int]($nodeVersion.Split('.')[0])
  $env:PIPE_ENFORCE_APP_CHECK = 'false'
  $env:FUNCTIONS_DISCOVERY_TIMEOUT = '45000'
  $env:NODE_OPTIONS = '--max-old-space-size=4096'
  $arguments = @(
    'emulators:exec',
    '--project', 'demo-pipe-buyer-integration',
    '--config', 'firebase.fleet-emulators.tmp.json',
    '--only', 'auth,firestore,functions,storage',
    'node firebase/functions/integration/ten_agent_user_fleet.mjs'
  )

  if ($nodeMajor -eq 22 -and (Get-Command firebase -ErrorAction SilentlyContinue)) {
    firebase @arguments
  } else {
    Write-Host "Using isolated Node 22 for 10-Agent Fleet integration (host is $nodeVersion)."
    npx --yes -p node@22 -p firebase-tools@15.25.0 firebase @arguments
  }
  Assert-NativeSuccess '10-Agent User Fleet emulator simulation'
} finally {
  if (Test-Path $tempConfigPath) {
    Remove-Item $tempConfigPath -Force -ErrorAction SilentlyContinue
  }
}
