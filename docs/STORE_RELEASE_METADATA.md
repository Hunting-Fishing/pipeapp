# Pipe Buyer store release metadata

Status: Engineering draft re-audited November 24, 2026; product, privacy,
legal, release-bound artwork, and store approval pending

Owner: Product and release operations

## Public store URLs

The Flutter application owns unauthenticated, refresh-safe routes for the four
public destinations required by the mobile stores:

- Privacy: `/privacy`
- Terms: `/terms`
- Support: `/support`
- Account deletion: `/account-deletion`

For staging, prepend the approved staging origin such as
`https://pipebuyer-5c77f.web.app`. Production must use the approved public
production origin. Do not enter staging, localhost, a private console link, or
an unapproved redirect in either store.

The November 24 live Apple update saved and verified the production Marketing,
Support, and Privacy URLs shown below. This verifies the store fields only. The
production site still serves the older policy/release content, so publication
acceptance and policy/legal approval remain open before submission.

The November 23 production recheck returned HTTP 200 for the public root,
Privacy, Terms, Support, and Account Deletion routes, and for both mobile-link
association files. The prepared production store and review URLs are:

- Marketing: `https://www.pipebuyer.com`
- Support: `https://www.pipebuyer.com/support`
- Privacy: `https://www.pipebuyer.com/privacy`
- Account deletion evidence for Google Play and external review:
  `https://www.pipebuyer.com/account-deletion`

The owner approved this exact URL batch and the live Apple fields were saved and
verified on November 24. Apple does not provide a separate account-deletion URL
metadata field for this app;
App Review must verify the in-app deletion flow, with a direct web link used
only where the account type requires completion on the website.

The updated source also turns the public deletion route into a direct configured
email request path that does not require installing or opening the app. This is
prepared for Google Play but is not credited until the updated web release is
deployed, the inbox and ownership-verification runbook are proven operational,
and a real request is accepted through the support workflow.

Privacy and Terms show only server-published policy metadata and link to the
exact reviewed HTTPS document. They fail closed when a policy is missing or
unpublished. Legal owners must approve and publish the complete documents
before the URLs are submitted to a store.

Support and account-deletion pages are usable without authentication. Every
controlled staging or production build requires `PIPE_PUBLIC_SUPPORT_EMAIL`;
local development can omit it without presenting the build as release-ready.

## Submission field inventory

| Item | Repository state | Release action |
| --- | --- | --- |
| Product name and identifier | Apple app `Pipe Buyer`, bundle ID `Pipe.Buyerapp`, and SKU `PIPE-BUYER-001` are confirmed live; no Play app record exists | Reuse the Apple record; create the single matching Play record after publisher verification and organization conversion |
| App icon | Master and generated 1024-pixel Apple/512-pixel artwork exist | Review the exact console crop and rendered device icon |
| Privacy, Terms, Support, deletion URLs | Public refresh-safe routes exist | Publish approved policy documents, verify production HTTPS responses, and confirm monitored support ownership |
| Listing copy and keywords | The owner-approved English subtitle, promotional text, description, and cleaned keywords were saved and verified live on November 24 | Preserve the exact copy through signed-candidate preview; privacy/legal and screenshot approval remain open |
| Screenshots | The November 23 audit showed 0/3 previews and 0/10 screenshots for both Dynamic-Island iPhone and 13-inch iPad. The November 24 recheck reconfirmed the Dynamic-Island iPhone set and 0/1 header; the iPad set was not refreshed | Capture from the exact admitted candidate with approved or anonymized data |
| Google feature graphic | No dedicated 1024 x 500 store graphic exists | Design, approve, and upload before the Play listing is complete |
| Apple App Privacy | Privacy manifest exists; the live page publishes seven linked App Functionality data types, but that answer set is not yet reconciled or approved for the candidate | Reconcile runtime, backend, every linked SDK, the deployed policy, and deletion behavior, then have privacy/legal approve the answers |
| Google Data Safety | No approved console answer set exists | Reconcile all versions/regions, runtime, backend, and SDK behavior, then approve and submit |
| Review access | App Store Connect contains portal-only sign-in information, reviewer contact, and notes; none is retained in source | Validate least-privilege access against the exact build and create the separate Play review path after its app record exists |
| Ratings and audience | Shopping/Business categories and subtitle are saved. Content Rights is Yes; UGC, Social Media, Messaging/Chat, Shared Location, and Advertising are Yes; Dating is No. Apple recalculated the current-framework rating to 13+ for 171 regions and 16+ for 2 regions, with a 15+ Korea row. The earlier-OS section remains global 12+ with regional exceptions. China mainland is excluded from the 174-region initial scope | Recheck these declarations against the exact signed candidate and complete remaining privacy, audience, and regional declarations before submission |
| Release control | Apple version 1.0.5 is verified as Prepare for Submission with manual release and no selected build | Preserve manual release through review and require a separate owner go/no-go before publication |
| Signed and device evidence | Not yet available | Admit exact AAB/IPA through closed testing and retain the physical-device matrix |

Official current field references:

- Apple [platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information),
  [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications),
  and [App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/).
- Google [store listing fields](https://support.google.com/googleplay/android-developer/answer/9859152),
  [graphic assets](https://support.google.com/googleplay/android-developer/answer/9866151),
  [Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469),
  and [App content](https://support.google.com/googleplay/android-developer/answer/9859455).

## Canonical English listing and screenshot draft

The single current controlled-test copy packet and six-shot media plan are in
[`APP_STORE_LISTING_DRAFT_2026-11-24.md`](APP_STORE_LISTING_DRAFT_2026-11-24.md).
Its subtitle, promotional text, description, and keyword set were owner-approved,
saved, and verified live on November 24. Its screenshot plan remains a draft
until exact-candidate capture and approval. The packet supersedes earlier
embedded copy and screenshot-plan variants so release operations have one
canonical review surface.

## Privacy and reviewer worksheet

The checked-in Apple privacy manifest declares no tracking and records the
current account, contact, location, messaging, media, support, purchase,
interaction, identifier, and diagnostic data used for app functionality. It is
an engineering input, not a completed App Store Connect or Play Console answer.
The locked-version SDK and external-service evidence is maintained in
[`MOBILE_SDK_PRIVACY_INVENTORY_2026-11-23.md`](MOBILE_SDK_PRIVACY_INVENTORY_2026-11-23.md).
The conservative questionnaire draft and its unresolved answer gates are in
[`STORE_PRIVACY_ANSWER_MATRIX_2026-11-23.md`](STORE_PRIVACY_ANSWER_MATRIX_2026-11-23.md).

Before either questionnaire is approved:

1. Inventory the exact Flutter, native Apple/Android, Firebase, maps, media,
   notification, authentication, integrity, and payment-related SDK versions in
   the signed candidate.
2. Trace each collected data type through the client, Firebase project,
   Functions, support tooling, retention/deletion flow, and every third party.
3. Confirm collection, sharing, linkage to identity, tracking, purposes,
   optionality, encryption in transit, deletion handling, and regional/version
   differences.
4. Have privacy/legal owners compare the resulting matrix to the published
   policy and both console questionnaires. Fix the product or policy before
   answering if they differ.

For store review, provide a monitored contact name, email, and phone plus clear
steps for account creation, phone/email verification, MFA, role-gated screens,
sample listings, messaging, reporting, deletion, and any feature flag. If a
demo account is necessary, create a least-privilege temporary account and enter
its credentials only in App Store Connect and Play Console. Never commit them
to source, CI, screenshots, or this document.

## Controlled-test release notes

Draft for the first invited TestFlight/Play test build:

TestFlight build 9 currently has no **What to Test** text. The draft below is
ready for owner approval and entry with the new admitted candidate, not build 9.

> First controlled mobile test release of Pipe Buyer. Invited testers can try
> account creation and sign-in, marketplace browsing and listings, wanted ads,
> offers, timed buying, messaging, reporting, account deletion, and eligible
> Dispatch workflows. Native digital-subscription purchasing is not enabled in
> this free-core test cohort. Please report authentication, link routing,
> notification, upload, accessibility, performance, and device-layout issues.

This is tester-facing draft copy, not approval to advertise unavailable
features. Public copy must be regenerated from the exact enabled release flags.

## Repeatable update path

For every post-launch update, reuse the existing app records and package/bundle
identifier, increment the public version as appropriate and always increment
the store build/version code, rebuild from protected `main`, repeat the risk-
appropriate automated and device gates, update release notes, and preserve the
artifact-to-commit record. Apple's phased release and Google's staged rollout
are update controls; they do not replace the owner-controlled first-publication
decision. See Apple's [new version](https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version/)
and [phased release](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases)
guides and Google's [update](https://support.google.com/googleplay/android-developer/answer/9859350)
and [staged rollout](https://support.google.com/googleplay/android-developer/answer/6346149)
guides.

## Approval checklist

- Product verifies that copy matches the enabled Phase 1 feature flags.
- Privacy verifies Google Data Safety and Apple App Privacy answers against the
  final build and linked SDK inventory.
- Legal approves Terms, Privacy, prohibited-items, mapping/location, and
  communications policies and their public document URLs.
- Support approves the public mailbox, response expectations, and escalation
  coverage.
- Release operations verifies the public pages from the exact hosted release,
  including browser refresh and mobile layouts.
- Store reviewers validate the signed AAB and IPA. Repository tests and draft
  copy are not substituted for this evidence.
