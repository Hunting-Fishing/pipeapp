# Pipe Buyer store privacy answer matrix

Status: Engineering draft for controlled testing, November 23, 2026. This is
not an approved App Store Connect or Google Play Console submission. Privacy
and legal review must reconcile the exact signed candidate, active regions,
backend settings, processors, retention, and network capture before any answer
is saved in a store console.

## Controlled-test privacy defaults

- `PIPE_REMOTE_DIAGNOSTICS_ENABLED=false` for the admitted candidate.
- Native paid-membership and billing flags remain fail closed.
- The unused `firebase_performance` package is excluded. Firebase documents
  that merely adding its Flutter SDK starts automatic lifecycle and HTTP/S
  performance collection.
- Apple tracking remains **No** only while no provider links Pipe Buyer data
  with third-party data for targeted advertising or measurement.
- Crashlytics remains disabled by the native manifests and must not be enabled
  for this candidate without reopening the diagnostic answers below.
- The bundled Firebase Crashlytics Apple privacy manifest declares Crash Data
  and Other Diagnostic Data even when transmission is disabled. Keep the Apple
  draft conservatively at Yes/not linked/App Functionality unless the SDK is
  removed from the exact binary; the Google draft below describes the current
  candidate's disabled transmission behavior separately.

References: [Firebase Performance for Flutter](https://firebase.google.com/docs/perf-mon/flutter/get-started),
[Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/),
and [Google Play Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469).

## Apple App Privacy draft

Unless noted, every collected type is linked to the user's identity, is not
used for tracking, and is used for App Functionality. Collection is optional
overall because signed-out browsing exists, but some fields become required
when a user chooses a related account or marketplace workflow.

| Apple data type | Collected | Additional purpose or boundary |
| --- | --- | --- |
| Name | Yes | Account/profile and selected business workflows |
| Email Address | Yes | Authentication, account management, communications |
| Phone Number | Yes | Optional phone authentication, MFA, profile/workflows |
| Physical Address | Yes | Optional listings, business, delivery, and Dispatch workflows |
| Other User Contact Info | Yes | Optional marketplace/business contact fields |
| Other Financial Info | Yes | Tax/business identifiers, payout readiness, and transaction records; confirm Fraud Prevention purpose with legal |
| Payment Info | No direct collection, provisional | Card/bank entry must remain hosted by Stripe or the stores; reopen if the app or Pipe Buyer backend receives it |
| Purchase History | Yes | Membership and marketplace transaction records |
| Precise Location | Yes | Optional foreground pin/location workflows; Product Personalization where it drives nearby results |
| Coarse Location | Yes | Optional region, nearby-search, and map behavior; Product Personalization where applicable |
| Emails or Text Messages | Yes | In-app messages |
| Photos or Videos | Yes | User-selected listing, profile, message, report, credential, and Dispatch media |
| Customer Support | Yes | Private cases and replies |
| Other User Content | Yes | Listings, offers, reports, credentials, and Dispatch content |
| User ID | Yes | Authentication and ownership controls |
| Device ID | Yes, conservative | Firebase installation, App Check, messaging, and device registration; App Functionality plus Fraud Prevention/Security if approved |
| Product Interaction | Yes | **Linked; Analytics plus App Functionality.** Affiliate-click records include `actorUid` when signed in |
| Search History | Yes, conservative | Linked saved marketplace watch/search terms; App Functionality plus Product Personalization where they drive results |
| Crash Data | **Yes, conservative manifest declaration** | Not linked; App Functionality. Transmission remains disabled for this candidate, but the bundled Crashlytics Apple manifest declares this type |
| Performance Data | No | The unused automatic Performance Monitoring SDK is excluded |
| Other Diagnostic Data | **Yes, conservative manifest declaration** | Not linked; App Functionality. Transmission remains disabled for this candidate, but the bundled Crashlytics Apple manifest declares this type |

Do not select Developer Advertising or Marketing, Product Personalization for
affiliate clicks, or Tracking unless the business use and partner behavior
actually require those answers. The checked-in Apple privacy manifest records
Product Interaction as linked and used for Analytics and App Functionality.

## Google Play Data Safety draft

| Google category / type | Collected | Shared | Required or optional | Purposes |
| --- | --- | --- | --- | --- |
| Personal info: name, email, phone, address, other info | Yes | Provisional pending processor analysis | Optional overall | App functionality; Account management; Fraud prevention/security where applicable |
| Personal info: user IDs | Yes | Provisional pending processor analysis | Required after account use | App functionality; Account management; Fraud prevention/security |
| Financial info: other financial info | Yes | Provisional | Optional | App functionality; Account management; Fraud prevention/security |
| Financial info: user payment info | No direct collection, provisional | No | Not applicable | Reopen if hosted-payment boundary changes |
| Financial info: purchase history | Yes | Provisional | Optional | App functionality; Account management; Fraud prevention/security |
| Location: precise and approximate | Yes | **Yes provisionally** | Optional | App functionality; Personalization |
| Messages: other in-app messages | Yes | Provisional | Optional | App functionality |
| Photos and videos | Yes | Provisional | Optional | App functionality |
| App activity: in-app search history | Yes, conservative | **Yes provisionally** | Optional | App functionality; Personalization where nearby/search behavior uses it |
| App activity: app interactions | Yes | Provisional | Optional for voluntary affiliate clicks | **Analytics plus App functionality** |
| Other user-generated content | Yes | Provisional | Optional | App functionality |
| Device or other IDs | Yes | Provisional | Required, conservative | Fraud prevention/security; App functionality; Developer communications for messaging |
| App info and performance: crash logs | No for this candidate | No | Not applicable | Reopen if Crashlytics is enabled |
| App info and performance: diagnostics / performance | No for this candidate | No | Not applicable | Automatic Performance Monitoring SDK is excluded |

Top-level draft answers:

- App collects user data: **Yes**.
- App shares user data: **Yes, provisionally**, until Firebase/Google Cloud,
  identity providers, Stripe, Photon, Nominatim, OpenStreetMap, remote media,
  and retailer/affiliate transfers are each classified under Google's
  service-provider or user-initiated exceptions.
- All collected data encrypted in transit: **Unresolved; do not answer Yes**
  until signed-build capture proves every destination and transport.
- Users can request deletion: **Source implemented, not yet accepted.** The
  public page has a dedicated configured email request. For Apple-linked
  accounts, the client performs fresh Apple reauthentication and calls
  Firebase Auth's official revocation API before requesting immediate deletion;
  the backend enforces short-lived normal-client sequencing but does not
  receive the Apple authorization code or cryptographically prove revocation.
  Final Yes remains blocked until the updated web/Functions build is deployed,
  the address and ownership-verification runbook are proven operational, and a
  real Apple device demonstrates successful revocation/deletion against the
  exact candidate.
- Deletion scope: authentication, private profiles, and owner-only profile,
  listing, and business media are removed. Shared messages and attachments,
  participant references, Marketplace or Dispatch records, disputes, safety
  records, fraud-prevention data, and tax/accounting/legal records may remain
  where required for other users or approved retention. Anonymization is
  applied only where the record and implementation support it.
- Independent security review: **No**, unless a qualifying review is actually
  completed and retained.

## Evidence still required before console submission

1. Signed Android and iOS network capture with an exact destination inventory
   and HTTPS/TLS result.
2. Processor and user-initiated-exception classification for every listed
   external service and affiliate/retailer destination.
3. Confirmation of whether affiliate interactions affect recommendations,
   marketing, or partner reporting.
4. Exact retention and deletion behavior for Firebase installation IDs, App
   Check, messaging tokens, stored searches, click records, and diagnostics.
5. Deploy and accept immediate account deletion, including observed successful
   Sign in with Apple revocation on a physical Apple device, and the external
   web deletion-request email against the exact candidate.
6. Final archive/SBOM, merged manifest/plist, active feature flags, and all
   store regions/versions reconciled by the owner and privacy/legal reviewers.
