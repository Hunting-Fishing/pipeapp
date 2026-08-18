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

function Remove-LegacyAnalyticsShortcuts {
  param([Parameter(Mandatory = $true)][string]$Source)
  $text = Normalize-Lf $Source
  $titleMarker = "title: 'Analytics & alerts',"
  $buttonMarker = "label: const Text('Open analytics & alerts'),"
  $cardMarker = "          PipeBuyerSectionCard("
  $afterMarker = "          const SizedBox(height: 12),"
  $removed = 0

  while ($true) {
    $buttonIndex = $text.IndexOf($buttonMarker, [System.StringComparison]::Ordinal)
    if ($buttonIndex -lt 0) { break }

    $titleIndex = $text.LastIndexOf(
      $titleMarker,
      $buttonIndex,
      [System.StringComparison]::Ordinal
    )
    if ($titleIndex -lt 0) {
      throw 'STOP: Analytics shortcut button exists without its expected card title. No guessing.'
    }

    $start = $text.LastIndexOf(
      $cardMarker,
      $titleIndex,
      [System.StringComparison]::Ordinal
    )
    if ($start -lt 0) {
      throw 'STOP: Could not locate the start of the legacy Analytics shortcut card. No guessing.'
    }

    $endStart = $text.IndexOf(
      $afterMarker,
      $buttonIndex,
      [System.StringComparison]::Ordinal
    )
    if ($endStart -lt 0) {
      throw 'STOP: Could not locate the end of the legacy Analytics shortcut card. No guessing.'
    }

    $end = $endStart + $afterMarker.Length
    if ($end -lt $text.Length -and $text[$end] -eq "`n") { $end++ }
    $text = $text.Remove($start, $end - $start)
    $removed++
  }

  return [pscustomobject]@{
    Text = $text
    Removed = $removed
  }
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, (Normalize-Lf $Text), $utf8NoBom)
}

$sourcePath = Join-Path $script:PipeBuyerRepoRoot 'lib\marketplace\marketplace_dispatch_credentials.dart'
$templatePath = Join-Path $script:PipeBuyerRepoRoot 'tool\templates\marketplace_dispatch_credentials_intelligence.dart.txt'
foreach ($required in @($sourcePath, $templatePath)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "STOP: Required credential analytics file is missing: $required"
  }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $script:PipeBuyerRepoRoot "_local_backups\dispatch-credential-analytics-actions-v3-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $backupDir 'marketplace_dispatch_credentials.dart')
Copy-Item -LiteralPath $templatePath -Destination (Join-Path $backupDir 'marketplace_dispatch_credentials_intelligence.dart.txt')
Write-Host "Backup created: $backupDir" -ForegroundColor Green

$variablesBefore = @'
    final evidenceCount = _records.where((record) => record.hasPrivateEvidence).length;
    final insurance = _records.where((record) => record.type.isInsurance).toList();
    final insuredWithLimits = insurance
        .where(
          (record) => record.isCurrentOn(now) && record.hasDeclaredCoverage,
        )
        .length;
'@
$variablesAfter = @'
    final evidenceRecords =
        _records.where((record) => record.hasPrivateEvidence).toList();
    final insurance = _records.where((record) => record.type.isInsurance).toList();
    final insuranceWithLimits = insurance
        .where(
          (record) => record.isCurrentOn(now) && record.hasDeclaredCoverage,
        )
        .toList();
    final insuredWithLimits = insuranceWithLimits.length;
'@

$readinessBefore = @'
              Text(
                '${(readiness * 100).round()}% of credential records addressed',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metricTile('Current', current.length, Icons.check_circle_outline),
                  _metricTile('Expired', expired.length, Icons.event_busy_outlined),
                  _metricTile('Not provided', missing.length, Icons.help_outline),
                  _metricTile('Evidence files', evidenceCount, Icons.lock_outline),
                  _metricTile(
                    'Insurance limits',
                    insuredWithLimits,
                    Icons.shield_outlined,
                  ),
                ],
              ),
'@
$readinessAfter = @'
              Text(
                '${(readiness * 100).round()}% of credential records addressed',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              const Text(
                'Select any status tile below to see the credential records behind the number and take action.',
                style: TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metricTile(
                    label: 'Current',
                    records: current,
                    icon: Icons.check_circle_outline,
                    emptyMessage: 'No credentials are currently marked current.',
                  ),
                  _metricTile(
                    label: 'Expired',
                    records: expired,
                    icon: Icons.event_busy_outlined,
                    emptyMessage: 'No supplied credential is currently expired.',
                  ),
                  _metricTile(
                    label: 'Not provided',
                    records: missing,
                    icon: Icons.help_outline,
                    emptyMessage: 'Every credential record has been addressed.',
                  ),
                  _metricTile(
                    label: 'Evidence files',
                    records: evidenceRecords,
                    icon: Icons.lock_outline,
                    emptyMessage: 'No private credential evidence is currently on file.',
                  ),
                  _metricTile(
                    label: 'Insurance limits',
                    records: insuranceWithLimits,
                    icon: Icons.shield_outlined,
                    emptyMessage: 'No current insurance record has a declared primary coverage limit.',
                  ),
                ],
              ),
'@

$metricBefore = @'
  Widget _metricTile(String label, int value, IconData icon) => Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
'@
$metricAfter = @'
  String _analyticsRecordSummary(DispatchCredentialRecord record) {
    final parts = <String>[record.state.label];
    if (record.expiryDate != null) parts.add('Expiry ${record.expiryLabel}');
    if (record.hasDeclaredCoverage) parts.add(record.coverageLabel);
    parts.add(
      record.hasPrivateEvidence
          ? 'Private evidence on file'
          : 'No private evidence',
    );
    return parts.join(' | ');
  }

  String _metricExplanation(String label) => switch (label) {
        'Current' =>
          'Credentials currently marked current from your private self-reported records.',
        'Expired' =>
          'Credentials marked expired or whose supplied expiry date has passed.',
        'Not provided' =>
          'Credential categories that still need a status or supporting information.',
        'Evidence files' =>
          'Credential records with a private supporting image on file. These files are not public verification.',
        'Insurance limits' =>
          'Current insurance records with a declared primary coverage limit for future private matching.',
        _ => 'Credential records included in this private analytics total.',
      };

  Future<void> _showCredentialMetricDetails({
    required String label,
    required List<DispatchCredentialRecord> records,
    required IconData icon,
    required String emptyMessage,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final listHeight = records.isEmpty
            ? 96.0
            : (records.length * 82.0).clamp(96.0, 410.0).toDouble();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: PipeBuyerColors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$label (${records.length})',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_metricExplanation(label)),
                const SizedBox(height: 12),
                SizedBox(
                  height: listHeight,
                  child: records.isEmpty
                      ? Center(child: Text(emptyMessage))
                      : ListView.separated(
                          itemCount: records.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final record = records[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(record.type.icon),
                              title: Text(record.type.label),
                              subtitle: Text(_analyticsRecordSummary(record)),
                              trailing:
                                  const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                Future<void>.delayed(Duration.zero, () async {
                                  if (!mounted) return;
                                  await _showCredentialQuickActions(record);
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCredentialQuickActions(
    DispatchCredentialRecord record,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(record.type.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_analyticsRecordSummary(record)),
            if (record.issuer.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Issuer: ${record.issuer}'),
            ],
            if (record.hasPrivateEvidence) ...[
              const SizedBox(height: 8),
              const Text(
                'Private evidence is on file for this credential. You can replace or remove it here.',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          if (record.hasPrivateEvidence)
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop('remove_evidence'),
              child: const Text('Remove evidence'),
            ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop('evidence'),
            child: Text(
              record.hasPrivateEvidence ? 'Replace evidence' : 'Upload evidence',
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('edit'),
            child: const Text('Edit metadata'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _editMetadata(record);
        break;
      case 'evidence':
        await _uploadEvidence(record);
        break;
      case 'remove_evidence':
        await _removeEvidence(record);
        break;
    }
  }

  Widget _metricTile({
    required String label,
    required List<DispatchCredentialRecord> records,
    required IconData icon,
    required String emptyMessage,
  }) {
    final value = records.length;
    return Semantics(
      button: true,
      label: '$label: $value. View credential details.',
      child: SizedBox(
        width: 190,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _showCredentialMetricDetails(
                label: label,
                records: records,
                icon: icon,
                emptyMessage: emptyMessage,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$value',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'View details',
                          style: TextStyle(
                            color: PipeBuyerColors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
'@

foreach ($path in @($sourcePath, $templatePath)) {
  $text = Normalize-Lf ([System.IO.File]::ReadAllText($path))
  foreach ($marker in @(
    "text: 'Analytics & alerts'",
    "title: 'Credential readiness'",
    'Widget _metricTile',
    'final insuredWithLimits'
  )) {
    if (-not $text.Contains($marker)) {
      throw "STOP: Credential analytics source changed unexpectedly in $path. Missing marker: $marker"
    }
  }

  $cleanup = Remove-LegacyAnalyticsShortcuts $text
  $text = $cleanup.Text
  if ($cleanup.Removed -gt 0) {
    Write-Host "Removed $($cleanup.Removed) legacy Records-view Analytics shortcut card(s) from $(Split-Path $path -Leaf)." -ForegroundColor Green
  } else {
    Write-Host "No legacy Records-view Analytics shortcut cards found in $(Split-Path $path -Leaf)." -ForegroundColor DarkGray
  }

  $alreadyInteractive =
    $text.Contains('Future<void> _showCredentialMetricDetails') -and
    $text.Contains('Future<void> _showCredentialQuickActions') -and
    $text.Contains("const Text('View details')") -and
    $text.Contains('final evidenceRecords =') -and
    $text.Contains('final insuranceWithLimits =')

  if (-not $alreadyInteractive) {
    $text = Replace-ExactlyOnce $text $variablesBefore $variablesAfter 'create drill-down record collections'
    $text = Replace-ExactlyOnce $text $readinessBefore $readinessAfter 'make readiness metrics visibly actionable'
    $text = Replace-ExactlyOnce $text $metricBefore $metricAfter 'install analytics metric drill-down and actions'
  } else {
    Write-Host "Interactive credential analytics already installed in $(Split-Path $path -Leaf)." -ForegroundColor DarkGray
  }

  Write-Utf8NoBom $path $text
}

Write-Host "`n==> Formatting credential analytics source" -ForegroundColor Cyan
& dart format $sourcePath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential analytics Dart formatting failed.'
}
& dart format --output=none --set-exit-if-changed $sourcePath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Credential analytics source is not formatter stable.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'DISPATCH CREDENTIAL ANALYTICS ACTIONS V3 READY' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Top Records / Analytics & alerts tab navigation preserved: PASS' -ForegroundColor Green
Write-Host 'Duplicate Records-view Analytics shortcut cards removed: PASS' -ForegroundColor Green
Write-Host 'Current / Expired / Not provided metric drill-down: INSTALLED' -ForegroundColor Green
Write-Host 'Evidence file metric drill-down and management actions: INSTALLED' -ForegroundColor Green
Write-Host 'Insurance limit metric drill-down: INSTALLED' -ForegroundColor Green
Write-Host 'Metric tiles visibly identify View details action: INSTALLED' -ForegroundColor Green
Write-Host 'Dispatch tracker modified: NO' -ForegroundColor Green
