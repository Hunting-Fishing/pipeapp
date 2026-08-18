# Windows PowerShell 5.1 compatibility rule: keep this file ASCII-only.
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

function Normalize-Lf([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Replace-ExactlyOnce {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Before,
    [Parameter(Mandatory = $true)][string]$After,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $sourceLf = Normalize-Lf $Source
  $beforeLf = Normalize-Lf $Before
  $afterLf = Normalize-Lf $After
  if ($sourceLf.Contains($afterLf)) {
    Write-Host "Already applied: $Label" -ForegroundColor DarkGray
    return $sourceLf
  }
  $count = ([regex]::Matches($sourceLf, [regex]::Escape($beforeLf))).Count
  if ($count -ne 1) {
    throw "STOP: Expected exactly one source target for '$Label', found $count. No guessing."
  }
  Write-Host "Applying: $Label" -ForegroundColor Green
  return $sourceLf.Replace($beforeLf, $afterLf)
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, (Normalize-Lf $Text), $utf8NoBom)
}

$baseApply = Join-Path $PSScriptRoot 'apply_dispatch_credential_intelligence.ps1'
$sourcePath = Join-Path $script:PipeBuyerRepoRoot 'lib\marketplace\marketplace_dispatch_credentials.dart'
$templatePath = Join-Path $script:PipeBuyerRepoRoot 'tool\templates\marketplace_dispatch_credentials_intelligence.dart.txt'

foreach ($required in @($baseApply, $sourcePath, $templatePath)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "STOP: Required credential acceptance file is missing: $required"
  }
}

Write-Host "`n==> Ensuring the complete credential intelligence foundation is installed" -ForegroundColor Cyan
& powershell -NoProfile -ExecutionPolicy Bypass -File $baseApply
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential intelligence foundation could not be installed safely.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $script:PipeBuyerRepoRoot "_local_backups\dispatch-credential-acceptance-v2-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $backupDir 'marketplace_dispatch_credentials.dart')
Copy-Item -LiteralPath $templatePath -Destination (Join-Path $backupDir 'marketplace_dispatch_credentials_intelligence.dart.txt')
Write-Host "Backup created: $backupDir" -ForegroundColor Green

$persistBefore = @'
  void _replaceRecord(DispatchCredentialRecord record) {
    setState(() {
      _records = _records
          .map((item) => item.type == record.type ? record : item)
          .toList(growable: false);
    });
  }

  Future<String?> _syncReminderSchedule() async {
'@
$persistAfter = @'
  void _replaceRecord(DispatchCredentialRecord record) {
    setState(() {
      _records = _records
          .map((item) => item.type == record.type ? record : item)
          .toList(growable: false);
    });
  }

  Future<void> _persistRecordUpdate(DispatchCredentialRecord updated) async {
    if (_saving) return;
    final previousRecords = _records;
    final nextRecords = _records
        .map((item) => item.type == updated.type ? updated : item)
        .toList(growable: false);
    setState(() {
      _records = nextRecords;
      _saving = true;
    });
    try {
      await _repository.saveAll(nextRecords, _reminderSettings);
      final scheduleWarning = await _syncReminderSchedule();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scheduleWarning ?? 'Credential metadata saved privately.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _records = previousRecords);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Credential metadata was not saved: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _syncReminderSchedule() async {
'@

$editBefore = @'
      if (!mounted || updated == null) return;
      _replaceRecord(updated);
'@
$editAfter = @'
      if (!mounted || updated == null) return;
      await _persistRecordUpdate(updated);
'@

$discoverBefore = @'
          const SizedBox(height: 12),
          ..._records.map(_credentialCard),
'@
$discoverAfter = @'
          const SizedBox(height: 12),
          PipeBuyerSectionCard(
            title: 'Analytics & alerts',
            subtitle:
                'Review credential readiness, insurance coverage, upcoming expiries and reminder settings.',
            leading: const Icon(
              Icons.insights_outlined,
              color: PipeBuyerColors.orange,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () =>
                    DefaultTabController.of(context).animateTo(1),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Open analytics & alerts'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._records.map(_credentialCard),
'@

foreach ($path in @($sourcePath, $templatePath)) {
  $text = Normalize-Lf ([System.IO.File]::ReadAllText($path))
  foreach ($marker in @(
    'class DispatchCredentialReminderSettings',
    "text: 'Analytics & alerts'",
    'final double? coverageLimit;'
  )) {
    if (-not $text.Contains($marker)) {
      throw "STOP: Credential intelligence foundation marker is missing in $path`: $marker"
    }
  }
  $text = Replace-ExactlyOnce $text $persistBefore $persistAfter 'persist dialog edits immediately'
  $text = Replace-ExactlyOnce $text $editBefore $editAfter 'await immediate credential persistence after dialog save'
  $text = Replace-ExactlyOnce $text $discoverBefore $discoverAfter 'surface analytics and alerts from the records view'
  $text = $text.Replace("child: const Text('Save metadata'),", "child: const Text('Save & close'),")
  Write-Utf8NoBom $path $text
}

Write-Host "`n==> Formatting the final credential source" -ForegroundColor Cyan
& dart format $sourcePath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential source formatter failed.'
}
& dart format --output=none --set-exit-if-changed $sourcePath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential source is not formatter stable.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH CREDENTIAL ACCEPTANCE V2 SOURCE READY' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Dialog Save persists immediately: INSTALLED' -ForegroundColor Green
Write-Host 'Save failure rolls local record back: INSTALLED' -ForegroundColor Green
Write-Host 'Analytics & alerts tab: INSTALLED' -ForegroundColor Green
Write-Host 'Records-view analytics shortcut: INSTALLED' -ForegroundColor Green
Write-Host 'Insurance coverage fields: INSTALLED' -ForegroundColor Green
Write-Host 'Dispatch tracker modified: NO' -ForegroundColor Green
