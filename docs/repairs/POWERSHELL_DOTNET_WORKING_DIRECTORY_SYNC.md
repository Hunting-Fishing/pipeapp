# PowerShell / .NET working-directory sync repair

## Symptom

A PowerShell prompt correctly showed:

```text
PS D:\Game Development\pipeapp>
```

and normal PowerShell commands such as `Copy-Item` and `dart format` resolved project-relative paths correctly, but direct .NET file APIs failed with paths rooted under:

```text
C:\Users\jordi\lib\...
```

For example:

```text
[System.IO.File]::ReadAllText('.\lib\marketplace\marketplace_dispatch_dashboard.dart')
```

attempted to read from `C:\Users\jordi` even though PowerShell's provider location was the Pipe Buyer repository.

## Root cause

Windows PowerShell's provider current location and the process-level working directory used by some .NET APIs are separate state. `Set-Location` updates PowerShell's location, but code that relies on `[Environment]::CurrentDirectory` / relative `System.IO` paths can still resolve from an older process working directory.

## Permanent control

`tool/pipebuyer_context.ps1` is the canonical repository-context helper. It:

1. resolves the repository root from the script location;
2. calls `Set-Location` for PowerShell commands;
3. sets `[Environment]::CurrentDirectory` to the same repository root for .NET and child-process path resolution;
4. exposes `Assert-PipeBuyerFormalBranch` for branch locking.

Guarded PowerShell repair scripts should dot-source this helper rather than assuming the visible PowerShell prompt is sufficient.

`tool/pipebuyer_doctor.ps1` now also verifies that PowerShell and the process working directory are synchronized.

## Control rule

For direct .NET file APIs, prefer absolute paths built from `$script:PipeBuyerRepoRoot` even after context synchronization. Do not pass project-relative strings to `[System.IO.File]::*` in ad-hoc repair commands.
