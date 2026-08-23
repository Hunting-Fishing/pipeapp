$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

$toolRoot = Join-Path $script:PipeBuyerRepoRoot 'tool'
$files = @(Get-ChildItem -LiteralPath $toolRoot -Filter '*.ps1' -File -Recurse)
if ($files.Count -eq 0) {
  throw 'STOP: No PowerShell tools found under tool/.'
}

$foreignControlPattern = '(?mi)^\s*(elif|fi|then)\b'
$issues = @()

foreach ($file in $files) {
  $tokens = $null
  $parseErrors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $file.FullName,
    [ref]$tokens,
    [ref]$parseErrors
  )

  foreach ($parseError in $parseErrors) {
    $issues += [pscustomobject]@{
      File = $file.FullName
      Kind = 'Parse'
      Message = $parseError.Message
    }
  }

  $raw = Get-Content -LiteralPath $file.FullName -Raw
  $foreignMatch = [regex]::Match($raw, $foreignControlPattern)
  if ($foreignMatch.Success) {
    $issues += [pscustomobject]@{
      File = $file.FullName
      Kind = 'ForeignShellKeyword'
      Message = "Found '$($foreignMatch.Groups[1].Value)'"
    }
  }

  $badCommands = @(
    $ast.FindAll({
      param($node)
      if ($node -isnot [System.Management.Automation.Language.CommandAst]) { return $false }
      $name = $node.GetCommandName()
      return $name -in @('elif', 'fi')
    }, $true)
  )
  foreach ($bad in $badCommands) {
    $issues += [pscustomobject]@{
      File = $file.FullName
      Kind = 'InvalidCommand'
      Message = "Would execute '$($bad.GetCommandName())'"
    }
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'PIPE BUYER POWERSHELL TOOL AUDIT' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host "Scripts scanned: $($files.Count)" -ForegroundColor White

if ($issues.Count -eq 0) {
  Write-Host 'Issues found: 0' -ForegroundColor Green
  Write-Host 'Repository-wide PowerShell audit: PASS' -ForegroundColor Green
  exit 0
}

Write-Host "Issues found: $($issues.Count)" -ForegroundColor Red
$issues |
  Sort-Object File, Kind, Message |
  Format-Table -AutoSize File, Kind, Message

Write-Host ''
Write-Host 'Repository-wide PowerShell audit: FAIL' -ForegroundColor Red
Write-Host 'This report is batch-oriented: fix the listed scripts together rather than discovering them one at a time during unrelated subsystem work.' -ForegroundColor Yellow
exit 1
