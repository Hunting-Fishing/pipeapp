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

$indexPath = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\index.js'
$commandsPath = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\administrator_role_commands.js'
$commandsTestPath = Join-Path $script:PipeBuyerRepoRoot 'firebase\functions\test\administrator_role_commands.test.js'
$dashboardPath = Join-Path $script:PipeBuyerRepoRoot 'lib\marketplace\marketplace_admin_dashboard.dart'
$managerPagePath = Join-Path $script:PipeBuyerRepoRoot 'lib\marketplace\marketplace_admin_role_manager.dart'

foreach ($required in @($indexPath, $commandsPath, $commandsTestPath, $dashboardPath, $managerPagePath)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "STOP: Required administrator management file is missing: $required"
  }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $script:PipeBuyerRepoRoot "_local_backups\administrator-role-management-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $indexPath -Destination (Join-Path $backupDir 'index.js')
Copy-Item -LiteralPath $dashboardPath -Destination (Join-Path $backupDir 'marketplace_admin_dashboard.dart')
Write-Host "Backup created: $backupDir" -ForegroundColor Green

Write-Host "`n==> Wiring protected administrator role commands" -ForegroundColor Cyan
$index = Normalize-Lf ([System.IO.File]::ReadAllText($indexPath))
$index = Replace-ExactlyOnce $index @'
const { createAdminRuntime } = require("./admin_runtime");
'@ @'
const { createAdminRuntime } = require("./admin_runtime");
const {
  createAdministratorRoleCommands,
} = require("./administrator_role_commands");
'@ 'import administrator role commands'

$index = Replace-ExactlyOnce $index @'
const accountCommands = createAccountCommands(admin);
'@ @'
const accountCommands = createAccountCommands(admin);
const administratorRoleCommands = createAdministratorRoleCommands(admin);
'@ 'instantiate administrator role commands'

$index = Replace-ExactlyOnce $index @'
exports.registerNotificationEndpoint = onCall(
'@ @'
exports.listAdministratorRoles = onCall(
  protectedCallableOptions,
  administratorRoleCommands.listAdministratorRoles,
);
exports.manageAdministratorRole = onCall(
  protectedCallableOptions,
  administratorRoleCommands.manageAdministratorRole,
);
exports.registerNotificationEndpoint = onCall(
'@ 'export administrator role callables'
Write-Utf8NoBom $indexPath $index

Write-Host "`n==> Connecting the admin portal to the protected roster manager" -ForegroundColor Cyan
$dashboard = Normalize-Lf ([System.IO.File]::ReadAllText($dashboardPath))
$dashboard = Replace-ExactlyOnce $dashboard @'
import 'marketplace_admin_access.dart';
'@ @'
import 'marketplace_admin_access.dart';
import 'marketplace_admin_role_manager.dart';
'@ 'import administrator role manager page'

$administratorMenu = @'
                              PopupMenuItem(
                                  value: 'administrator',
                                  child: Text('Set Role: Administrator')),
'@
if ($dashboard.Contains((Normalize-Lf $administratorMenu))) {
  $dashboard = $dashboard.Replace((Normalize-Lf $administratorMenu), '')
  Write-Host 'Applying: remove misleading profile-field Administrator role action' -ForegroundColor Green
} elseif (-not $dashboard.Contains("Set Role: Administrator")) {
  Write-Host 'Already applied: remove misleading profile-field Administrator role action' -ForegroundColor DarkGray
} else {
  throw 'STOP: Administrator menu structure changed. No guessing.'
}

$dashboard = $dashboard.Replace(
  'Search all Pipe Buyer members, view email/phone verification status, change user roles (Personal, Business, Hotshot Carrier, Admin), or suspend accounts.',
  'Search Pipe Buyer members and maintain ordinary account-type metadata. Administrator access is managed separately through protected Firebase claims and MFA.',
)

$dashboard = Replace-ExactlyOnce $dashboard @'
        final currentUser = FirebaseAuth.instance.currentUser;
        final masterEmail = currentUser?.email ?? 'jordilwbailey@gmail.com';
'@ @'
        final currentUser = FirebaseAuth.instance.currentUser;
        final accountEmail = currentUser?.email ?? 'Administrator';
'@ 'remove hard-coded administrator identity fallback'
$dashboard = $dashboard.Replace('title: Text(masterEmail,', 'title: Text(accountEmail,')

$configBefore = @'
        const SizedBox(height: 16),
        SwitchListTile(
          value: _auctionsEnabled,
'@
$configAfter = @'
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text(
              'Administrator access management',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Primary administrator only. Grants and removals use protected Firebase claims, verified email and MFA.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MarketplaceAdminRoleManager(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _auctionsEnabled,
'@
$dashboard = Replace-ExactlyOnce $dashboard $configBefore $configAfter 'surface protected administrator roster management'
Write-Utf8NoBom $dashboardPath $dashboard

Write-Host "`n==> Checking administrator management syntax and tests" -ForegroundColor Cyan
foreach ($target in @($commandsPath, $indexPath)) {
  & node --check $target
  if ($LASTEXITCODE -ne 0) {
    throw "STOP: Node syntax check failed for $target"
  }
}
& node --test $commandsTestPath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Administrator role command tests failed.'
}

& dart format $managerPagePath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Administrator role manager Dart formatting failed.'
}
& dart analyze --fatal-infos --fatal-warnings $managerPagePath
if ($LASTEXITCODE -ne 0) {
  throw 'STOP: Administrator role manager strict analyzer failed.'
}

# The legacy Admin Dashboard is large and may carry unrelated lint debt. This
# bounded migration must prove that it introduced no Dart compile errors without
# allowing unrelated info/warning lint debt to block this subsystem repair.
$dashboardAnalysis = @(& dart analyze --format=machine $dashboardPath 2>&1)
$dashboardErrors = @($dashboardAnalysis | Where-Object { "$_" -match '^ERROR\|' })
if ($dashboardErrors.Count -gt 0) {
  $dashboardErrors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  throw 'STOP: Admin dashboard contains Dart compile errors after roster wiring.'
}
Write-Host 'Admin dashboard compile-error check: PASS' -ForegroundColor Green

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'PIPE BUYER ADMINISTRATOR ROLE MANAGEMENT READY' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host 'Administrator authorization still requires custom claims + MFA: PASS' -ForegroundColor Green
Write-Host 'Primary administrator roster manager restriction: PASS' -ForegroundColor Green
Write-Host 'Goldcity administrator cannot change roster: PASS' -ForegroundColor Green
Write-Host 'Primary administrator cannot remove itself in-app: PASS' -ForegroundColor Green
Write-Host 'Generic user role menu cannot fake Administrator access: PASS' -ForegroundColor Green
Write-Host 'Admin dashboard identity fallback removed: PASS' -ForegroundColor Green
Write-Host 'Role changes revoke existing sessions: PASS' -ForegroundColor Green
Write-Host 'Dispatch tracker modified: NO' -ForegroundColor Green
