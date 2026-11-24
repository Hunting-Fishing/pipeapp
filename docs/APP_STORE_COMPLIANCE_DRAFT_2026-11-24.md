# Pipe Buyer App Store compliance-answer draft

> **DRAFT - OWNER AND LEGAL APPROVAL REQUIRED BEFORE ANY LIVE SAVE**
>
> This is a local evidence worksheet, not a completed App Store Connect
> questionnaire. Do not copy an answer into the live console, change Content
> Rights, edit Age Ratings, submit the version, or infer the final age rating
> without owner/legal review of the exact signed candidate and its enabled
> feature flags.

Prepared: 2026-11-24.

## Interpretation rules

- **Current observed** means the value was visible in the authenticated live
  App Store Connect audit and was recorded in the release-readiness documents.
- **Provisional Yes/No** is the evidence-backed answer to review, not approval
  to save it.
- **Unresolved** means the repository evidence does not safely determine how
  Apple's current definition should be applied.
- Apple calculates global and region-specific ratings from the complete
  questionnaire. The currently displayed **12+** is an observation only; this
  worksheet does not predict the rating after corrected answers.
- If the live console asks for frequency, intensity, age gating, or another
  qualifier beyond the capability's presence, stop and classify that exact
  wording separately. Do not convert a Yes/No conclusion into an unsupported
  frequency answer.

Current Apple definitions are linked in
[Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)
and [App and compliance information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-compliance-information/).

## Content Rights

| App Store question/boundary | Current observed | Recommended draft | Evidence and remaining approval gate |
| --- | --- | --- | --- |
| Does the app contain, show, or access third-party content? | **No** | **Provisional Yes** | Pipe Buyer broadly displays user-created listings, photographs, descriptions, and public seller information; participant-only messages also contain user-created content without being public. The app additionally exposes administrator-managed affiliate/vendor product content. The current No conflicts with the audited product. Evidence: `docs/MOBILE_STORE_RELEASE_READINESS_2026-11-23.md:58-71`; `firebase/FIRESTORE_SCHEMA.md:32-67`; `firebase/FIRESTORE_SCHEMA.md:290-308`. |
| Does Pipe Buyer have the necessary rights or other legal permission for that content in every offered region? | Not observed in the live audit | **Unresolved - legal approval required** | Candidate Terms say users retain ownership, grant Pipe Buyer a platform-operating licence, and represent that they have submission rights (`web/terms.html:79-82`). That is relevant evidence, but it does not by itself prove rights for every user upload, affiliate/vendor catalog item, brand asset, region, or exact effective policy version. Legal must reconcile the published Terms, moderation/takedown process, vendor/affiliate agreements, and 174-region scope before any live confirmation. |

## Age-rating capabilities

| Capability | Current observed | Recommended draft | Source evidence and boundary |
| --- | --- | --- | --- |
| User-Generated Content | **No** | **Provisional Yes** | Users create public listings and selected public locations, submit listing media and descriptions, send messages, and create reports. Evidence: `firebase/FIRESTORE_SCHEMA.md:32-41`, `firebase/FIRESTORE_SCHEMA.md:59-67`, and `docs/PHASE_1_LAUNCH_FINALIZATION_PLAN.md:202-213`. Apple defines UGC as broadly distributed user-created text, photos, video, or audio. |
| Messaging and Chat | **Yes** | **Provisional Yes** | Listing-scoped buyer/seller chats are an intended feature and are created through verified communication commands. Evidence: `README.md:1-4`; `firebase/FIRESTORE_SCHEMA.md:59-65`. This matches Apple's direct-communication definition. |
| Shared Location | **Unset** | **Provisional Yes** | Sellers may explicitly show an exact location or an approximate area; exact and approximate public listing locations can appear on the public map. Dispatch profiles can publish an approximate home base while keeping the exact point private. Evidence: `lib/marketplace/marketplace_location.dart:4-19`, `lib/marketplace/marketplace_location.dart:76-95`, `firebase/FIRESTORE_SCHEMA.md:108-115`, and `lib/marketplace/marketplace_dispatch_company_profile.dart:379-408`. Apple expressly includes precise or approximate real-world location shared with another person or group. |
| Advertising | **Yes** | **Provisional Yes, conservatively** | The product exposes sponsor placements/corporate advertising and a public catalog containing monetized affiliate URLs, vendor/brand channels, disclosures, and outbound-click telemetry. Evidence: `lib/marketplace/marketplace_home_welcome.dart:507-512`; `firebase/FIRESTORE_SCHEMA.md:290-308`. Confirm the exact candidate exposes these surfaces; if all paid-promotion surfaces are disabled, re-audit rather than automatically changing this to No. |
| Social Media | **No** | **Unresolved - possible Yes** | The app has public seller profiles, followed sellers, marketplace discovery, public user listings, and direct messages (`firebase/FIRESTORE_SCHEMA.md:54-60`, `firebase/FIRESTORE_SCHEMA.md:99-114`). Apple defines Social Media as redistribution, amplification, or interaction with UGC through a social feed or similar discovery method. Product/legal must decide whether marketplace browse/follow behavior meets that definition in the exact candidate; this worksheet does not guess. |
| Dating and Relationships | Not captured in the live audit | **Provisional No** | The audited scope is an industrial equipment, materials, wanted-ad, offer, timed-buying, and Dispatch marketplace (`README.md:1-4`; `docs/PHASE_1_LAUNCH_FINALIZATION_PLAN.md:191-223`). No dating, romantic matching, relationship-introduction, or romantic-companion feature was found in the audited source/docs. Reconfirm against the exact candidate before saving. |

## Rating effect and regional caution

- Do not preserve **12+** merely because it is the current display. Let App
  Store Connect recalculate after the complete, approved questionnaire.
- Apple's current framework treats Shared Location and Dating and Relationships
  as explicit descriptors. Ratings can differ by OS generation and region.
- Shared Location has a specific higher-rating effect in Brazil under Apple's
  current regional guidance. Do not remove Brazil or change availability merely
  to avoid the answer; release-region changes require a separate owner decision.
- User-generated listings and chat can contain unanticipated material. This
  worksheet records feature capability, not a frequency claim about profanity,
  mature themes, illegal goods, or other content descriptors. Review moderation
  controls and actual controlled-test content before answering those sections.

## Evidence limitations and required approval

The live observations are summarized in:

- `docs/MOBILE_STORE_RELEASE_READINESS_2026-11-23.md:47-78`;
- `docs/STORE_RELEASE_METADATA.md:59-74`.

Before any live save, the owner/legal review must:

1. inspect the exact live questionnaire wording and every existing answer;
2. reconcile the exact signed candidate, enabled feature flags, regions, public
   Terms/Privacy versions, affiliate/vendor agreements, and moderation path;
3. decide the unresolved Social Media and content-rights-permission items;
4. classify every remaining content descriptor rather than assuming None;
5. review the recalculated global and regional ratings; and
6. give action-time approval for the exact answer batch before App Store
   Connect is changed.

No build upload, review submission, public release, paid-product activation, or
region change is authorized by this draft.
