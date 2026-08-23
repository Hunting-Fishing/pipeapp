# Dispatch Service Restore Mirror + Contract Repair

## Symptom

The Request Service restoration gate reached the canonical mirror, all four candidate Dart files analyzed cleanly, then `flutter test` printed many `unable to find directory entry in pubspec.yaml` messages for `assets/...` and failed the final source contract because it expected this exact one-line formatting:

`loadDetails: _requestDetailsWithServices(details.text.trim())`

Production source had not been mutated.

## Root causes

1. The canonical mirror copied `pubspec.yaml` and `lib/` but not the asset directory topology declared by the real pubspec. Flutter therefore validated a package whose pubspec referenced directories that did not exist inside the mirror.
2. The contract asserted an exact formatter layout. `dart format` legitimately wrapped the `loadDetails` expression across lines, so the semantic behavior was present but the text assertion failed.

## Permanent repair

- Canonical Flutter mirrors must reproduce the directory topology required by their copied pubspec before invoking `flutter test` or other package-aware Flutter commands. This gate mirrors only the asset directory structure; it does not duplicate asset bytes because the focused contract never loads those assets.
- Source contracts that verify Dart expressions must be formatter-tolerant. The service-request persistence assertion now uses a whitespace-tolerant regular expression around `_requestDetailsWithServices(details.text.trim())`.
- Analyzer success is not overridden by a formatting-shape assertion. Tests should verify behavior/structure, not a particular `dart format` line break.

## Layer boundary

This was a **preflight-control failure**, not a Request Service implementation failure, Firebase failure, or production runtime failure. The gate stopped before its mutation stage, so rerunning the corrected gate is safe: no prior production mutation needs to be repeated or rolled back.
