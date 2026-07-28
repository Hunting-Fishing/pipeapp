# Pipe Buyer store release metadata

Status: Engineering draft; product, privacy, legal, and store approval pending

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

Privacy and Terms show only server-published policy metadata and link to the
exact reviewed HTTPS document. They fail closed when a policy is missing or
unpublished. Legal owners must approve and publish the complete documents
before the URLs are submitted to a store.

Support and account-deletion pages are usable without authentication. Every
controlled staging or production build requires `PIPE_PUBLIC_SUPPORT_EMAIL`;
local development can omit it without presenting the build as release-ready.

## Proposed English listing copy

This copy is a product draft. It must be reviewed in both store consoles before
its status is changed to approved in the Phase 1 acceptance evidence.

Application name:

> Pipe Buyer

Google Play short description:

> Buy, sell, auction and dispatch industrial equipment and materials.

Apple subtitle:

> Industrial marketplace

Promotional summary:

> Find industrial equipment and materials, negotiate documented offers, bid in timed auctions, and request professional trucking quotes in one focused marketplace.

Full description:

> Pipe Buyer connects verified buyers, sellers, and approved Dispatch providers across the industrial marketplace.
>
> Browse equipment and materials, post wanted ads, save listings, message securely, attach supporting photos, and negotiate price, quantity, purchase, transfer, and trucking dates with permanent offer history.
>
> Timed auctions support clear increments, bidding history, Buy It Now options, and controlled completion. Dispatch requests let users publish load details, receive carrier quote revisions, award work, and follow delivery milestones.
>
> Reporting, evidence attachments, administrator review, appeals, account privacy controls, and versioned marketplace policies help keep participation professional and accountable.
>
> Pipe Buyer does not hold purchase funds, provide escrow, or replace carrier, legal, tax, safety, inspection, or regulatory advice. Buyers, sellers, and service providers remain responsible for verification, final contracts, payment, permits, loading, and transportation compliance.

Suggested Apple keywords:

> industrial,equipment,materials,auction,trucking,dispatch,pipe,machinery

## Screenshot plan

Capture original screenshots from the exact signed release candidate, not from
demo artwork or a development build. Remove or anonymize personal information.

1. Marketplace Browse with real release-safe empty or approved sample data.
2. Detailed equipment or materials listing with user media.
3. Offer comparison showing price, quantity, and schedule analytics.
4. Timed auction detail and bid history.
5. Dispatch request and carrier quote workflow.
6. Account safety, reporting, and privacy controls.

Retain the original image files, store-console previews, review timestamp, and
reviewer identity in the private release acceptance bundle. At least four
screenshots per store are mandatory; this plan does not count as execution.

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
