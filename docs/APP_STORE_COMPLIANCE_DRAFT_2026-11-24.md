# Pipe Buyer App Store compliance-answer record

> **CONFIRMED BATCH SAVED - PRIVACY, BUILD, AND SUBMISSION STILL OPEN**
>
> The owner confirmed the exact Content Rights and age-rating batch below, and
> it was saved and verified in App Store Connect on 2026-11-24. This record does
> not authorize App Privacy edits, media/build upload, review submission, public
> release, paid-product activation, or a region change.

Prepared: 2026-11-24.

## Interpretation rules

- **Current observed** means the value was visible in the authenticated live
  App Store Connect audit and was recorded in the release-readiness documents.
- **Saved Yes/No** is an owner-confirmed answer visibly persisted in the live
  App Store Connect record.
- **Unresolved** means the repository evidence does not safely determine how
  Apple's current definition should be applied.
- Apple recalculated the current-framework result to **13+ for 171 countries or
  regions** and **16+ for 2 countries or regions**, with a **15+ Korea** row.
  The earlier-OS section remains global **12+ with regional exceptions**.
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
| Does the app contain, show, or access third-party content? | **Yes - saved 2026-11-24** | **Saved Yes** | Pipe Buyer broadly displays user-created listings, photographs, descriptions, and public seller information; participant-only messages also contain user-created content without being public. The app additionally exposes administrator-managed affiliate/vendor product content. Evidence: `docs/MOBILE_STORE_RELEASE_READINESS_2026-11-23.md:58-73`; `firebase/FIRESTORE_SCHEMA.md:32-67`; `firebase/FIRESTORE_SCHEMA.md:290-308`. |
| Does Pipe Buyer have the necessary rights or other legal permission for that content in every offered region? | **Owner confirmed; live summary says the app has the necessary rights** | **Saved Yes** | Candidate Terms say users retain ownership, grant Pipe Buyer a platform-operating licence, and represent that they have submission rights (`web/terms.html:79-82`). Continue maintaining effective Terms, moderation/takedown controls, vendor/affiliate agreements, brand permissions, and regional review; the saved declaration does not replace those obligations. |

## Age-rating capabilities

| Capability | Current observed | Recommended draft | Source evidence and boundary |
| --- | --- | --- | --- |
| User-Generated Content | **Yes - saved** | **Saved Yes** | Users create public listings and selected public locations, submit listing media and descriptions, send messages, and create reports. Evidence: `firebase/FIRESTORE_SCHEMA.md:32-41`, `firebase/FIRESTORE_SCHEMA.md:59-67`, and `docs/PHASE_1_LAUNCH_FINALIZATION_PLAN.md:202-213`. |
| Messaging and Chat | **Yes - retained** | **Saved Yes** | Listing-scoped buyer/seller chats are an intended feature and are created through verified communication commands. Evidence: `README.md:1-4`; `firebase/FIRESTORE_SCHEMA.md:59-65`. |
| Shared Location | **Yes - saved** | **Saved Yes** | Sellers may explicitly show an exact location or an approximate area; exact and approximate public listing locations can appear on the public map. Dispatch profiles can publish an approximate home base while keeping the exact point private. Evidence: `lib/marketplace/marketplace_location.dart:4-19`, `lib/marketplace/marketplace_location.dart:76-95`, `firebase/FIRESTORE_SCHEMA.md:108-115`, and `lib/marketplace/marketplace_dispatch_company_profile.dart:379-408`. |
| Advertising | **Yes - retained** | **Saved Yes** | The product exposes sponsor placements/corporate advertising and a public catalog containing monetized affiliate URLs, vendor/brand channels, disclosures, and outbound-click telemetry. Evidence: `lib/marketplace/marketplace_home_welcome.dart:507-512`; `firebase/FIRESTORE_SCHEMA.md:290-308`. Re-audit if all paid-promotion surfaces are disabled in a later candidate. |
| Social Media | **Yes - saved conservatively** | **Saved Yes** | The app has public seller profiles, followed sellers, marketplace discovery, public user listings, and direct messages (`firebase/FIRESTORE_SCHEMA.md:54-60`, `firebase/FIRESTORE_SCHEMA.md:99-114`). This applies Apple's broad feed/similar-discovery definition conservatively. |
| Dating and Relationships | **No - saved** | **Saved No** | The audited scope is an industrial equipment, materials, wanted-ad, offer, timed-buying, and Dispatch marketplace (`README.md:1-4`; `docs/PHASE_1_LAUNCH_FINALIZATION_PLAN.md:191-223`). No dating, romantic matching, relationship-introduction, or romantic-companion feature was found. |

During the confirmed save, the following existing answers were observed and
left unchanged: Parental Controls No; Age Assurance No; Unrestricted Web Access
No; Social Media Disabled for Users Under 13 No; Profanity/Crude Humor None;
Horror/Fear None; Alcohol/Tobacco/Drug references Infrequent; Medical/Treatment
Information None; Health/Wellness Topics No; all Sexuality/Nudity descriptors
None; all Violence descriptors None; Simulated Gambling None; Contests
Infrequent; Gambling No; Loot Boxes No; age override Not Applicable; and no Age
Suitability URL.

## Rating effect and regional caution

- The saved answers produced the live current-framework regional rating mix
  recorded above. Do not override it merely to lower or simplify the result.
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

The confirmed batch was saved after the owner reviewed the exact proposed
answers. Before build selection or review submission, release owners must:

1. inspect the exact live questionnaire wording and every existing answer;
2. reconcile the exact signed candidate, enabled feature flags, regions, public
   Terms/Privacy versions, affiliate/vendor agreements, and moderation path;
3. maintain evidence for content rights and the conservative Social Media
   classification;
4. recheck every preserved content descriptor against the exact candidate;
5. review the recalculated global and regional ratings; and
6. obtain a new action-time approval for any later questionnaire change.

No App Privacy edit, build upload, review submission, public release,
paid-product activation, or region change is authorized by this record.
