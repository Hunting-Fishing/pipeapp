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

`dispatch_directory_entries` reads require a signed-in user and enabled Dispatch feature state under Firestore Rules. The ordinary Seller storefront can also be reached outside that context, so the Dispatch read is optional and isolated. Signed-out, feature-held, permission-denied, missing-document, or transient Dispatch-read failures must leave the existing storefront usable rather than failing the entire page.

## Scope

Exactly four durable files are allowed in this slice:

1. `lib/marketplace/marketplace_public_profile_page.dart`
2. `lib/marketplace/marketplace_dispatch_public_detail.dart`
3. `test/marketplace_dispatch_public_detail_test.dart`
4. `docs/DISPATCH_RELEASE3_PROVIDER_DETAIL_SURFACE.md`

No Firebase Functions, Firestore Rules/schema, messaging, payments, subscriptions, listings, Directory search, or provider-persistence changes are part of this slice.

## Verification gate

Before merge:

- temporary patch tooling must pass its own Python syntax check before mutation;
- exact four-file durable mutation scope must pass;
- `dart format` check must pass for the changed Dart files;
- `dart analyze lib test` must pass;
- focused provider-detail tests must pass;
- full Flutter regression must pass;
- repository release-contract tests must pass;
- both Firebase Functions codebases must install/lint/check successfully; and
- `git diff --check` must pass.

## Checklist

- [x] Existing `View Business` route audited; canonical Seller storefront retained.
- [x] Server-owned Directory projection field/privacy contract audited.
- [x] Signed-out/feature-held storefront failure mode identified and bounded.
- [ ] Provider-detail model/card implemented and verified.
- [ ] Seller storefront optional Dispatch integration verified.
- [ ] Temporary verifier tooling removed.
- [ ] Feature PR merged.
- [ ] Exact merged application SHA deployed through protected production workflow.
- [ ] Post-deploy Function parity and responsive visual acceptance confirmed.
- [ ] Final production evidence recorded here.

## Permanent implementation rule

Do not move this detail card to provider-owned private documents and do not make the public storefront depend on a successful Dispatch-only read. Display only bounded server-owned Directory projection labels/summaries, and keep the existing storefront functional whenever the optional Dispatch projection is unavailable.
