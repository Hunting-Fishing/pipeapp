# Recovery Formal Fast Gate Git stderr repair

Date: 2026-08-22

## Symptom

The recovery Formal Fast Gate passed Pipe Buyer Doctor and then stopped while
executing its changed-file inventory:

`git diff --name-only --diff-filter=ACMR HEAD`

Git emitted a worktree line-ending warning for `firebase/firestore.rules`.

Windows PowerShell converted the native stderr warning into
`NativeCommandError` because the gate runs with `$ErrorActionPreference =
'Stop'`.

The Git operation itself had not reported an application or syntax failure.

## Root cause

The Fast Gate directly invoked Git changed-file discovery while inheriting the
developer machine's `core.autocrlf` behavior.

A harmless Git line-ending warning on stderr was therefore treated as a
terminating PowerShell failure before Node, Dart formatting, or analyzer checks
could begin.

## Permanent repair

The read-only tracked-file inventory now invokes Git with:

`-c core.autocrlf=false`
`-c core.safecrlf=false`

This prevents Git from performing or warning about worktree line-ending
conversion during inventory.

The script also checks `$LASTEXITCODE` explicitly for both tracked and
untracked Git enumeration commands.

The repository `.gitattributes` policy is unchanged.

## Verification rule

A successful repair must:

1. preserve the detached formal SHA safety check;
2. preserve all recovered application files;
3. allow the Formal Fast Gate to proceed past changed-file discovery;
4. still fail when Git itself returns a non-zero exit code.

## Recovery checkpoint

`2121fdd303cf879eda927e7c98dbf8726cb2e86d`