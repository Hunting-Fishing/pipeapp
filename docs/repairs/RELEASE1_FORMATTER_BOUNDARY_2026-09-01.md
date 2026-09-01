# Release 1 formatter boundary repair — 2026-09-01

## Symptom

The Release 1 focused tests passed, but the complete Flutter suite failed `marketplace_catalog_photo_integration_test.dart` after the builder formatted the entire `lib/marketplace/oil_gas_marketplace.dart` file.

## Root cause

Release 1 changes only a few navigation and shell lines in the large Marketplace source. Running the current Dart formatter across the entire pre-existing file changed unrelated catalog-photo call formatting. A source-contract test intentionally recognizes the established exact category + product-type call shape for both listing cards and listing details. The broad formatter mutation changed that textual shape even though Release 1 did not change catalog-photo behavior.

## Repair

Do not run whole-file formatting over `oil_gas_marketplace.dart` in this bounded Release 1 mutation. Preserve all unrelated production source byte-for-byte and mutate only the exact guarded anchors. Continue formatting the new/small Release 1 files where doing so cannot rewrite unrelated source.

## Verification

The unchanged full Flutter regression must pass, including `marketplace_catalog_photo_integration_test.dart`, before Release 1 can commit or merge.

## Do not repeat

A formatter is a source mutation. On large legacy/source-of-record files with source-contract tests, do not broaden a small repair into a whole-file formatting rewrite. Keep the formatter boundary aligned with the intended mutation or deliberately update the contract only when product behavior is actually changing.
