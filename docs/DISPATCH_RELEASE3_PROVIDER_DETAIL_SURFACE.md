# Release 3 — Dispatch provider detail surface

## Date

2026-09-02

## Verified deployed application baseline

```text
b54edc4b17a2feee67f67faaeb0aa1a78721d822
```

That application SHA was deployed by protected production workflow `33530088768` / run #63 with App Check `enforce`. Firebase release evidence is `9809595669` and responsive visual evidence is `9809629706`.

The current `main` parent may also contain documentation-only bookkeeping after that deployment. Documentation-only commits do not replace `b54edc4b17a2feee67f67faaeb0aa1a78721d822` as the deployed application baseline.

## Product decision

Do not create a second competing provider-detail route. `View Business` already opens the canonical Seller storefront at `/profiles/:userUid`. For non-technical field users, one business page is simpler and less error-prone than separate Marketplace and Dispatch detail pages.

This slice enriches the existing Seller storefront with optional structured Dispatch information from the server-owned `dispatch_directory_entries/{companyId}` projection.

## Public Dispatch detail shown

When the signed-in viewer is allowed to read the Dispatch Directory projection and an entry exists, the storefront may show:

- structured service names from the canonical Dispatch taxonomy;
- current published availability;
- emergency-callout capability;
- remote-site capability;
- published service-area summary;
- approximate public home-base label; and
- provider-published radius summary when the public service-area mode is `radius`.

## Privacy and access boundary

The storefront must not display or retain for this card:

- `mapPoint` coordinates;
- geohash;
- exact private service-area geometry;
- exact yard/home/job location;
- private email/phone;
- credentials, insurance records, policy numbers, or evidence paths;
- internal review/moderation fields; or
- unsupported verification claims.

`dispatch_directory_entries` reads require a signed-in user and enabled Dispatch feature state under Firestore Rules. The ordinary Seller storefront can also be reached outside that context, so the Dispatch read is optional and isolated. Signed-out, feature-held, permission-denied, missing-document, or transient Dispatch-read failures leave the existing storefront usable rather than failing the entire page.

## Scope

Exactly four durable files are allowed in this slice:

1. `lib/marketplace/marketplace_public_profile_page.dart`
2. `lib/marketplace/marketplace_dispatch_public_detail.dart`
3. `test/marketplace_dispatch_public_detail_test.dart`
4. `docs/DISPATCH_RELEASE3_PROVIDER_DETAIL_SURFACE.md`

No Firebase Functions, Firestore Rules/schema, messaging, payments, subscriptions, listings, Directory search, or provider-persistence changes are part of this slice.

## Verification gate

Verifier workflow `33531964067` / run #4 completed successfully and produced durable feature commit:

```text
824eece27375fe891a4da8e52d90c33f44db892e
```

The successful gate proved:

- temporary patch tools parsed before mutation without writing verification residue;
- exact four-file durable mutation scope;
- deterministic Dart formatting followed by a no-op formatter-stability check;
- `dart analyze lib test`;
- focused provider-detail tests;
- full Flutter regression;
- repository release-contract tests;
- Marketplace Functions install/lint/check;
- administrative Functions install/lint/check; and
- `git diff --check`.

Temporary verifier and patch files were removed after the green run and are not part of the feature PR.

## Verification repair record

Three verifier failures occurred before run #4 passed. None required a redesign of the runtime provider-detail feature.

1. **Existing-source anchor indentation was normalized away.** The temporary patch used `dedent(...).lstrip()` for exact Dart source anchors, so the guarded replacement could not find the real indented source. The repair was to preserve exact whitespace for anchors and reserve dedenting for newly generated file content.
2. **`py_compile` created untracked `tool/__pycache__/` residue.** The exact four-file mutation guard correctly rejected the fifth path. The repair was to compile the temporary Python source in memory using `compile(...)`, leaving no filesystem residue. The four-file guard was not weakened.
3. **Generated Dart needed formatter normalization.** The staged source was structurally valid but not formatter-stable. The repair was to run `dart format` only on the three approved changed Dart files, then immediately require a second `--set-exit-if-changed` pass to be a no-op before analyzer/tests.

Permanent lesson: distinguish runtime defects from release-tooling defects. Preserve exact source anchors, keep verification checks residue-free, and normalize generated Dart deterministically before analysis. Do not redesign the application when the first failing layer is temporary transformation tooling.

## Checklist

- [x] Existing `View Business` route audited; canonical Seller storefront retained.
- [x] Server-owned Directory projection field/privacy contract audited.
- [x] Signed-out/feature-held storefront failure mode identified and bounded.
- [x] Provider-detail model/card implemented and verified.
- [x] Seller storefront optional Dispatch integration verified.
- [x] Temporary verifier tooling removed.
- [ ] Feature PR merged.
- [ ] Exact merged application SHA deployed through protected production workflow.
- [ ] Post-deploy Function parity and responsive visual acceptance confirmed.
- [ ] Final production evidence recorded here.

## Permanent implementation rule

Do not move this detail card to provider-owned private documents and do not make the public storefront depend on a successful Dispatch-only read. Display only bounded server-owned Directory projection labels/summaries, and keep the existing storefront functional whenever the optional Dispatch projection is unavailable.
