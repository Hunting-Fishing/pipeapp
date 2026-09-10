# R3 Firebase Gen-2 transient rollout repair — 2026-09-03

## Release boundary

Release 3 — Dispatch Directory was application-complete at exact commit `a6bc1ffb4d887af39ac4e9a8ea75851e0a39d214`. Protected production run `33538007190` passed the analyzer, Flutter tests, release controls, Functions validation, Firestore rules, authenticated callable integration and exact web build before the first Firebase deployment attempt failed.

## Observed failure

Authentication, Firebase project selection, rules/Hosting packaging and most Functions deployment work succeeded. The first deployment attempt failed while Cloud Run was starting five unchanged Gen-2 Function revisions:

- `onConversationCreated`
- `onCatalogSuggestionCreated`
- `executeMarketplaceRefund`
- `onAuctionTransactionCreatedPaymentMirror`
- `createMarketplaceTaxRecoveryCase`

The five Functions had deployed successfully in the previous known-good full Firebase release. The R3 comparison contained no relevant runtime/package change and no implementation change to those five Function definitions.

## Repair decision

Do not reopen Dispatch Directory application code and do not make speculative Firebase/Function edits. The smallest justified repair is to rerun the failed protected deployment job against the same exact `main` SHA.

## Proven repair

The retry ran against exact SHA `a6bc1ffb4d887af39ac4e9a8ea75851e0a39d214` and completed successfully:

- all protected application and release gates passed again;
- Firebase deployment completed for project `flutter-flow-pipe`;
- deployed-Function parity passed;
- release identity/evidence retention passed;
- production mobile visual acceptance passed;
- production desktop visual acceptance passed.

Retained retry evidence:

- Firebase release evidence artifact `9848902855`
- visual acceptance artifact `9848948030`
- protected production run `33538007190`

## Preserved repair rule

If this exact failure signature appears again on unchanged Functions after all pre-deploy gates pass, first compare the failing Functions to the last known-good deployment and inspect the retained Firebase deployment log. If there is no relevant code/runtime/config change and the failure is isolated to Gen-2 revision startup during rollout, retry the protected deployment once against the exact same SHA before considering code changes.

Do **not** treat unrelated Gen-2 startup failures as proof that Dispatch Directory code is defective. Any repeated failure after a clean retry, or any changed runtime/config/function source, requires a new root-cause investigation rather than applying this repair blindly.
