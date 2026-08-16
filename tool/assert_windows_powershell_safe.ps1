param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

$ErrorActionPreference = 'Stop'

$resolved = (Resolve-Path -LiteralPath $Path).Path
$bytes = [System.IO.File]::ReadAllBytes($resolved)
$nonAscii = $bytes | Where-Object { $_ -gt 127 } | Select-Object -First 1
if ($null -ne $nonAscii) {
  throw "PowerShell safety gate failed: $resolved contains non-ASCII bytes. Keep Windows PowerShell 5.1 runner files ASCII-only."
}

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  $resolved,
  [ref]$tokens,
  [ref]$errors
) | Out-Null

if ($errors.Count -gt 0) {
  foreach ($error in $errors) {
    Write-Host $error.Message -ForegroundColor Red
  }
  throw "PowerShell safety gate failed: parser errors were found in $resolved"
}

Write-Host "WINDOWS POWERSHELL 5.1 SAFETY CHECK PASSED: $resolved" -ForegroundColor Green
