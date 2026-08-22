# Recovery Directory inline filter and Windows contract repair

Date: 2026-08-22

## Symptoms

After the recovered application source passed the Formal Fast Gate and strict
Dart analyzer, three focused Directory tests remained red.

1. The runtime-stability source contract could not locate an `@override`
   boundary on Windows because it searched for an LF-only literal while the
   working file used CRLF line endings.

2. Directory widget tests could not find:
   - `directory-service-filter-button`
   - `directory-service-filter-option-transport_hotshot`

3. Formal Directory interaction contracts required same-tree selectors and
   explicitly prohibited overlay dropdown controls in the Directory filter
   section.

## Root causes

The runtime source contract was line-ending-sensitive.

The recovered Directory source and the accepted formal tests were from
different points in the filter-control repair sequence. The source still used
`DropdownButtonFormField` while the formal tests required the later same-tree,
pointer-stable inline selector contract.

This was source/test checkpoint drift, not a Firebase, Dispatch data, or
Directory filtering-model failure.

## Permanent repairs

### Same-tree filter controls

The Directory Service, Availability, and Business Type controls now use
`_DirectoryInlineSelect`.

Each selector:

- stays in the widget tree rather than opening an overlay route;
- exposes stable button and option ValueKeys;
- closes itself before applying parent filter state;
- applies the parent update from a post-frame callback;
- uses a bounded `ListView.separated` for options;
- preserves responsive wide/stacked layout.

### Windows-safe source contract

The runtime-stability contract normalizes CRLF to LF before performing
source-boundary string assertions.

Repository `.gitattributes` policy is unchanged.

## Verification

The final recovery verification runs:

- Pipe Buyer Formal Fast Gate;
- startup single-surface contract;
- startup auth-loading contract;
- Request Service restore contract;
- Directory seed-safe repository contract;
- Directory runtime stability contract;
- Directory pointer-stable filter contract;
- Directory responsive dropdown-layout contract;
- Directory widget-harness hygiene contract;
- Directory widget behavior tests.

## Future rule

Do not repair pointer-sensitive Directory filter failures by reintroducing
overlay dropdowns or weakening accepted interaction tests.

Source-inspection tests that use newline-sensitive boundaries must normalize
line endings before assertions.