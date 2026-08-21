[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$BaseUrl = 'https://www.pipebuyer.com'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Fail([string]$Message) {
    throw "PIPE BUYER POLICY VERIFY ERROR: $Message"
}

Set-Location -LiteralPath $RepoRoot

$policies = @(
    @{ Id = 'terms_of_service'; File = 'terms.html'; Path = '/terms' },
    @{ Id = 'privacy_notice'; File = 'privacy.html'; Path = '/privacy' },
    @{ Id = 'prohibited_items'; File = 'prohibited-items.html'; Path = '/prohibited-items' },
    @{ Id = 'mapping_location'; File = 'mapping-location.html'; Path = '/mapping-location' },
    @{ Id = 'communications'; File = 'communications.html'; Path = '/communications' }
)

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('pipebuyer-policy-verify-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    $results = foreach ($policy in $policies) {
        $localPath = Join-Path $RepoRoot ('build\web\' + $policy.File)
        if (-not (Test-Path -LiteralPath $localPath -PathType Leaf)) {
            Fail "Missing $localPath. Run .\pipebuyer.ps1 -Action WebLegal -ConfirmWebLegalDeploy first so the exact release build exists locally."
        }

        $livePath = Join-Path $tempRoot $policy.File
        $url = $BaseUrl.TrimEnd('/') + $policy.Path

        try {
            Invoke-WebRequest -Uri $url -OutFile $livePath -MaximumRedirection 5 | Out-Null
        } catch {
            Fail "Could not fetch $url. $($_.Exception.Message)"
        }

        if (-not (Test-Path -LiteralPath $livePath -PathType Leaf) -or (Get-Item -LiteralPath $livePath).Length -le 0) {
            Fail "The public policy URL returned no document: $url"
        }

        $localHash = (Get-FileHash -LiteralPath $localPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $liveHash = (Get-FileHash -LiteralPath $livePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $match = $localHash -eq $liveHash

        [pscustomobject]@{
            Policy = $policy.Id
            Url = $url
            LocalSha256 = $localHash
            LiveSha256 = $liveHash
            Match = $match
        }
    }

    $results | Format-Table Policy, Match, LocalSha256, LiveSha256 -AutoSize

    $mismatches = @($results | Where-Object { -not $_.Match })
    if ($mismatches.Count -gt 0) {
        $ids = ($mismatches | ForEach-Object { $_.Policy }) -join ', '
        Fail "Live policy bytes do not match the local release build for: $ids. Do not publish policy records."
    }

    Write-Host ''
    Write-Host 'All five public policy documents exactly match the local release build.' -ForegroundColor Green
    Write-Host 'Policy publication may proceed only after owner/legal review and the guarded operator dry run.' -ForegroundColor Yellow
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
