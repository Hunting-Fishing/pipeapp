$ErrorActionPreference = 'Stop'

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $workspace

if ((git branch --show-current).Trim() -ne 'main') {
  throw 'Run the trust onboarding repair from the main branch.'
}

$source = Join-Path $PSScriptRoot 'fix_trust_onboarding_v2.ps1'
$runtime = Join-Path $PSScriptRoot '.fix_trust_onboarding_v3_runtime.ps1'

$text = Get-Content $source -Raw
$before = '$tracked = git ls-files --error-unmatch -- $file 2>$null'
$after = '$tracked = @(git ls-files -- $file)'

if (-not $text.Contains($before)) {
  throw 'V2 new-file detection anchor was not found.'
}

$text = $text.Replace($before, $after)
$text = $text.Replace('if ($LASTEXITCODE -eq 0) {', 'if ($tracked.Count -gt 0) {')
Set-Content -Path $runtime -Value $text -Encoding UTF8

try {
  & powershell -ExecutionPolicy Bypass -File $runtime
  if ($LASTEXITCODE -ne 0) {
    throw "Corrected Trust onboarding V3 run failed with exit code $LASTEXITCODE."
  }
} finally {
  Remove-Item -Force $runtime -ErrorAction SilentlyContinue
}
