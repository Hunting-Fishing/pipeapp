# Windows PowerShell 5.1 compatibility rule: keep this file ASCII-only.
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
[Environment]::CurrentDirectory = $repoRoot

$expectedBranch = 'design/formal-beautification-foundation'
$branch = (git branch --show-current).Trim()
if ($branch -ne $expectedBranch) {
  throw "STOP: Wrong branch. Expected $expectedBranch, found $branch"
}

Write-Host ''
Write-Host 'Directory repository nullability repair is superseded.' -ForegroundColor Yellow
Write-Host 'Seeded Directory mode must remain Firebase-independent, so repository creation is now lazy.' -ForegroundColor Yellow
Write-Host 'Redirecting to the canonical seed-safe repository repair gate...' -ForegroundColor Cyan

$remote = 'origin/design/formal-beautification-foundation'
& git fetch origin design/formal-beautification-foundation
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not fetch the canonical seed-safe Directory repair gate.'
}
& git checkout $remote -- 'tool/run_dispatch_directory_seed_safe_repository_repair.ps1'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not synchronize the canonical seed-safe Directory repair gate.'
}
& git reset -q HEAD -- 'tool/run_dispatch_directory_seed_safe_repository_repair.ps1'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Could not unstage the canonical seed-safe Directory repair gate.'
}

& powershell -NoProfile -ExecutionPolicy Bypass -File '.\tool\run_dispatch_directory_seed_safe_repository_repair.ps1'
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Canonical seed-safe Directory repository repair failed.'
}
