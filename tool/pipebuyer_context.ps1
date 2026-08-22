$ErrorActionPreference = 'Stop'

# Canonicalize both PowerShell's provider location and the process working
# directory used by .NET APIs such as [System.IO.File]::ReadAllText().
# Windows PowerShell can otherwise show D:\... in the prompt while .NET still
# resolves relative paths from the process' older C:\Users\... working folder.
$script:PipeBuyerRepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $script:PipeBuyerRepoRoot
[Environment]::CurrentDirectory = $script:PipeBuyerRepoRoot

function Assert-PipeBuyerFormalBranch {
  param(
    [string]$ExpectedBranch = 'design/formal-beautification-foundation'
  )

  if (-not (Test-Path -LiteralPath (Join-Path $script:PipeBuyerRepoRoot '.git'))) {
    throw "STOP: $script:PipeBuyerRepoRoot is not the Pipe Buyer Git repository root."
  }

  $currentBranch = ((git branch --show-current | Out-String).Trim())

  if ([string]::IsNullOrWhiteSpace($currentBranch)) {
    $headSha = ((git rev-parse HEAD | Out-String).Trim())
    $expectedRef = "origin/$ExpectedBranch"
    $expectedSha = ((git rev-parse $expectedRef 2>$null | Out-String).Trim())

    if (
      [string]::IsNullOrWhiteSpace($headSha) -or
      [string]::IsNullOrWhiteSpace($expectedSha) -or
      $headSha -ne $expectedSha
    ) {
      throw "STOP: Detached Pipe Buyer worktree must exactly match $expectedRef. HEAD: $headSha Expected: $expectedSha"
    }

    Write-Host "Detached worktree verified at $expectedRef ($headSha)." -ForegroundColor DarkGray
    return $ExpectedBranch
  }

  if ($currentBranch -ne $ExpectedBranch) {
    throw "STOP: Expected branch $ExpectedBranch but found $currentBranch"
  }

  return $currentBranch
}
