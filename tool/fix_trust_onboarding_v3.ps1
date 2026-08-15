$ErrorActionPreference = 'Stop'

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $workspace

if ((git branch --show-current).Trim() -ne 'main') {
  throw 'Run the trust onboarding repair from the main branch.'
}

$source = Join-Path $PSScriptRoot 'fix_trust_onboarding_v2.ps1'
$runtime = Join-Path ([System.IO.Path]::GetTempPath()) ("pipebuyer_fix_trust_onboarding_v3_{0}.ps1" -f ([guid]::NewGuid().ToString('N')))

$text = Get-Content $source -Raw
$before = '$tracked = git ls-files --error-unmatch -- $file 2>$null'
$after = '$tracked = @(git ls-files -- $file)'

if (-not $text.Contains($before)) {
  throw 'V2 new-file detection anchor was not found.'
}

$text = $text.Replace($before, $after)
$text = $text.Replace('if ($LASTEXITCODE -eq 0) {', 'if ($tracked.Count -gt 0) {')

# The runtime copy lives outside the repository so git status cannot see it.
# Inject the actual repository workspace because $PSScriptRoot now points to %TEMP%.
$workspaceAnchor = '$workspace = (Resolve-Path (Join-Path $PSScriptRoot ''..'')).Path'
$escapedWorkspace = $workspace.Replace("'", "''")
$workspaceReplacement = "`$workspace = '$escapedWorkspace'"
if (-not $text.Contains($workspaceAnchor)) {
  throw 'V2 workspace anchor was not found.'
}
$text = $text.Replace($workspaceAnchor, $workspaceReplacement)

Set-Content -Path $runtime -Value $text -Encoding UTF8

try {
  & powershell -ExecutionPolicy Bypass -File $runtime
  if ($LASTEXITCODE -ne 0) {
    throw "Corrected Trust onboarding V3 run failed with exit code $LASTEXITCODE."
  }
} finally {
  Remove-Item -Force $runtime -ErrorAction SilentlyContinue
}
