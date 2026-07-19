# Pipe Buyer North America Property, Rights, and Business Marketplace Roadmap

Status: Approved planning baseline  
Geographic scope: Canada, United States, and Mexico  
Operating model: One Pipe Buyer platform with eXp-controlled real-estate workflows  
Plan date: July 19, 2026

## 1. Product outcome

Pipe Buyer will remain one professional platform with connected marketplaces for:

1. Equipment, materials, and industrial goods
2. Timed auctions and wanted ads
3. Dispatch, trucking jobs, and carrier quotes
4. Real property
5. Mineral, royalty, surface, lease, and related interests
6. Regulated energy assets
7. Industrial and energy-related businesses
8. Professional services supporting these transactions

The Property and Rights area will be controlled through eXp for Canada, the United States, and Mexico. All three countries are in scope from the beginning. A shared product and data model will support North America, while country, province, state, board, brokerage, and transaction requirements will be activated through jurisdiction-specific policy packs.

The platform will not represent that one brokerage licence, agent licence, form set, or closing process applies across North America. eXp's own published privacy structure identifies different responsible entities for the U.S., Canada, and Mexico. The platform must preserve those boundaries.

## 2. Meaning of “eXp-controlled”

A real-property listing, property offer, or brokerage-controlled transaction cannot become publicly active unless the platform can resolve all of the following:

- Country and province/state
- Responsible eXp legal entity
- Applicable eXp brokerage and office
- Supervising broker or compliance queue
- Assigned agent and valid jurisdictional licence, where required
- Approved listing authority
- Required disclosures, forms, consents, and advertising language
- Approved data-source and syndication permissions
- Applicable privacy, record-retention, AML, identity, and beneficial-ownership controls
- Approved offer, deposit, escrow/trust, title, notary, and closing path

eXp compliance users must be able to:

- Approve, return, reject, pause, or unpublish a listing
- Require corrections or additional documents
- Control the permitted listing and offer features by jurisdiction
- Assign or replace an agent or supervising reviewer
- Review a permanent audit trail
- Suspend a jurisdiction, brokerage, office, agent, listing class, or form version

Pipe Buyer must not:

- Present equipment-style “Buy Now” as a completed transfer of real property or property rights
- Hold real-estate deposits or trust money until the required legal, brokerage, banking, accounting, and regulatory structure is separately approved
- Allow unlicensed users to perform activities reserved for licensed professionals
- Publish confidential title, identity, beneficial-owner, banking, or due-diligence documents
- Claim that a platform acceptance itself transfers title, mineral rights, surface rights, a regulated licence, or an energy asset

## 3. Jurisdiction architecture

Every controlled feature will resolve through this hierarchy:

```text
Country
└── Province / state / territory
    ├── Real-estate regulator
    ├── Board / association / MLS or listing-data authority
    ├── Land-title / recorder / registry system
    ├── Energy / mineral / environmental regulator
    ├── eXp legal entity and brokerage
    │   ├── Brokerage licence
    │   ├── Supervising broker / compliance team
    │   ├── Office or service area
    │   └── Licensed agent
    └── Jurisdiction policy pack
```

Mexico also requires state and municipal context, applicable Registro Público de la Propiedad and cadastre references, a notary workflow, and restricted-zone/foreign-ownership handling where applicable.

### Jurisdiction policy pack

Each policy pack is versioned, dated, reviewable, and independently switchable. It contains:

- Country, subdivision, municipalities/counties, and effective dates
- Responsible eXp entity and brokerage legal names
- Brokerage, office, agent, and supervising licences
- Permitted listing and transaction classes
- Required roles and approval sequence
- Advertising, representation, agency, and attribution rules
- Required disclosures, agreements, forms, and signatures
- Listing-data display, retention, and syndication permissions
- Identity, authority-to-sell, KYC, AML, sanctions, and beneficial-owner requirements
- Currency, language, timezone, tax, and measurement rules
- Offer, deposit, trust/escrow, title, notary, and closing rules
- Record-retention and audit requirements
- Privacy and data-residency requirements
- Property, mineral, surface, and energy-regulator references
- Feature flags and emergency kill switches

No jurisdiction will silently fall back to another jurisdiction's rules. If a valid policy pack cannot be resolved, the listing remains a private draft and is routed to compliance.

## 4. Transaction classes

These classes share identity, messaging, reporting, maps, notifications, and audit infrastructure, but they do not share transaction finality.

| Class | Examples | Platform transaction model |
|---|---|---|
| Goods | Pipe, equipment, vehicles, parts, materials | Marketplace offer, auction, wanted ad, sale workflow |
| Services | Dispatch jobs, trucking, pilot vehicles, inspections | Quote, revision, acceptance, job completion |
| Real property | Industrial, commercial, farm, ranch, rural, residential | eXp-controlled listing, inquiry, brokerage offer/LOI, professional closing |
| Rights and interests | Mineral, royalty, surface, easement, right-of-way, tenure | Verified interest, controlled data room, qualified inquiry/offer, specialist review |
| Energy assets | Wells, facilities, pipelines, leases, production packages | Regulatory transfer workflow, liability and approval gates |
| Businesses | Oilfield services, trucking, fabrication, rentals, operators | Confidential marketing, NDA/data room, LOI, diligence, professional closing |

## 5. Marketplace taxonomy

### Property

- Industrial yards, shops, warehouses, laydown yards, and fabrication facilities
- Commercial property and income-producing property
- Farm, ranch, agricultural land, and rural acreage
- Residential and rural residential property
- Property with surface leases, rights-of-way, easements, or energy infrastructure
- Development land
- Rail-, highway-, pipeline-, port-, or utility-served sites
- Storage, terminal, and transload property
- Property for sale, lease, sublease, or wanted

### Rights and interests

- Freehold/fee mineral interests
- Crown, state, federal, or other tenure interests where transferable
- Royalty, gross overriding royalty, overriding royalty, and net-revenue interests
- Working interests and participation interests
- Surface lease income and surface rights
- Easements, rights-of-way, access rights, and utility corridors
- Water-related rights where legally listable
- Carbon, pore-space, solar, and wind interests after jurisdictional review

Every rights listing must state exactly what is being marketed. It must never imply ownership of minerals, royalties, surface, access, or operating rights that the supporting records do not establish.

### Regulated energy assets

- Wells and well packages
- Batteries, facilities, plants, compressors, and metering
- Pipelines, gathering systems, and related rights-of-way
- Producing and non-producing leases
- Reclamation, abandonment, and decommissioning packages
- Operating companies or asset packages

Regulated transfers require separate regulator, liability, environmental, and financial-capability gates. An accepted commercial offer is not a regulatory approval.

### Businesses

- Oilfield and industrial service businesses
- Trucking, dispatch, and pilot-car businesses
- Welding, machining, fabrication, and repair operations
- Equipment rental and fleet operations
- Property-holding and operating companies
- Farms, ranches, storage, terminal, and logistics businesses

The system must distinguish an asset sale, share/equity sale, real-property sale, and mixed transaction. Securities and business-brokerage review must be feature-gated by jurisdiction.

### Professional services

- Surveying, appraisal, inspection, and NDT
- Environmental assessment and reclamation
- Land, title, legal, tax, accounting, escrow, and notary services
- Engineering and regulatory consulting
- Dispatch, trucking, pilot, crane, and rigging services

## 6. Core roles and permissions

- Public visitor
- Registered buyer
- Verified seller
- Business account administrator
- Dispatch customer
- Dispatch company and fleet member
- eXp agent
- eXp commercial agent
- Supervising broker
- Brokerage compliance reviewer
- Property/rights document reviewer
- Lawyer, notary, title, escrow, or closing participant
- Energy/mineral/regulatory specialist
- Trust-and-safety reviewer
- Platform support administrator
- Platform security administrator
- Read-only auditor

Users may hold multiple roles, but each privileged action must use the role valid for that jurisdiction and transaction. Administrative access must use least privilege, multi-factor authentication, immutable audit events, and periodic access review.

## 7. Core records

The first design should preserve the current Firebase application while adding explicit domain boundaries. Operational records can continue in Firestore initially, behind repositories and server-controlled commands. Search, analytics, geospatial, and normalized property-rights data may later use specialized services without rewriting the UI.

### Control and jurisdiction

- `jurisdictionPolicies`
- `brokerageEntities`
- `brokerageLicenses`
- `brokerageOffices`
- `complianceQueues`
- `formTemplates`
- `formVersions`
- `featureFlags`

### Identity and authority

- `professionalProfiles`
- `agentLicenses`
- `roleAssignments`
- `sellerVerifications`
- `authorityToSell`
- `beneficialOwnershipReviews`
- `identityChecks`

### Property and rights

- `propertyListings`
- `parcels`
- `legalDescriptions`
- `propertyInterests`
- `rightsInterests`
- `surfaceInterests`
- `mineralInterests`
- `royaltyInterests`
- `energyAssets`
- `businessListings`

### Documents and compliance

- `listingDocuments`
- `documentVersions`
- `dataRooms`
- `dataRoomAccess`
- `complianceReviews`
- `requiredDisclosures`
- `signatureRequests`
- `auditEvents`
- `retentionPolicies`

### Transactions

- `inquiries`
- `offersAndLois`
- `offerRevisions`
- `representations`
- `dueDiligenceTasks`
- `conditions`
- `closingReferrals`
- `transactionMilestones`
- `feeInvoices`

Real-estate deposits, trust money, escrow balances, and title disbursements are deliberately excluded from the initial Pipe Buyer ledger.

## 8. Country-specific property identity

### Canada

Support provincial land-title and registry identifiers, including fields such as title number, parcel identifier, legal land description, lot/block/plan, and Alberta Township System descriptions where applicable. Regulatory, brokerage, privacy, and energy controls resolve by province or territory.

### United States

Support state, county/parish/borough, municipality, assessor parcel number, recorder/instrument references, legal description, subdivision, section-township-range where applicable, and tribal/federal land flags. Real-estate brokerage controls resolve by state and may additionally vary by MLS and local board.

### Mexico

Support state, municipality/alcaldía, locality, postal code, cadastral key, escritura, folio real, public-registry reference, notary reference, ejido/communal-property review flags, foreign-buyer status, and restricted-zone/fideicomiso flags. Spanish is a first-class product language, not a later translation overlay.

## 9. Controlled listing workflow

1. Seller creates a private draft.
2. The platform determines the country and subdivision from the parcel/location.
3. The jurisdiction policy pack selects the responsible eXp entity and workflow.
4. Seller identity and authority-to-list are verified.
5. A qualified agent and supervising compliance queue are assigned.
6. Required parcel, title, interest, disclosure, and supporting records are collected.
7. Automated checks identify missing, conflicting, expired, duplicate, or suspicious information.
8. An eXp reviewer approves, returns, rejects, or restricts the listing.
9. The approved public version is generated from reviewed fields.
10. Inquiries and qualified-buyer access are routed to the assigned agent/team.
11. Offers or LOIs use the jurisdiction-approved workflow and forms.
12. Conditions, due diligence, revisions, and communications are permanently versioned.
13. A qualified title/escrow/lawyer/notary/closing professional completes the legal transfer.
14. The listing is closed, withdrawn, expired, or suspended with a full audit history.

## 10. Secure data rooms

Business, rights, energy, and many commercial-property listings need controlled data rooms.

Access tiers:

1. Public summary
2. Registered user
3. Identity-verified user
4. NDA-approved prospect
5. Financially qualified prospect
6. Transaction party and advisers
7. Assigned agent and compliance

Required controls:

- Expiring signed file access
- Per-document permissions
- Visible and forensic watermarks
- Download/view restrictions
- Access-reason capture
- Access, download, print, and revocation audit events
- Document versioning and superseded-document warnings
- Malware scanning and content classification
- Personal, financial, title, and regulator information redaction
- Retention and legal-hold controls

## 11. Integrations

Integrations require an agreement, documented permitted use, and a revocation path.

- eXp entity, brokerage, office, agent, and licence roster
- eXp compliance and lead-routing systems
- Canadian board/MLS and CREA DDF feeds where authorized
- U.S. MLS feeds using RESO Data Dictionary and Web API standards where authorized
- eXp Mexico listing and agent systems where authorized
- Parcel, geocoding, route, mapping, and boundary providers
- Provincial/state/county/municipal land-title and public-record sources
- Energy, environmental, well, facility, pipeline, and mineral regulators
- Identity, business, sanctions, and AML providers
- Electronic signature and approved document providers
- Notification providers for in-app, email, SMS, and push
- Payment provider for Pipe Buyer fees and invoices only in the initial release

The system must record source, licence, update time, confidence, and permitted display/use for imported data.

## 12. North American compliance baseline

### Canada

- Provincial/territorial brokerage and agent licensing
- Board, association, MLS, CREA trademark, and listing-data rules
- FINTRAC obligations for applicable real-estate participants
- PIPEDA and applicable provincial privacy laws
- Provincial land-title/registry and closing practice
- Provincial energy, mineral, surface, environmental, and transfer approvals

### United States

- State brokerage, agent, advertising, agency, escrow, and disclosure rules
- MLS and local-board agreements; RESO-compatible data transport where available
- Federal and state AML, sanctions, beneficial-owner, and fraud controls
- State privacy and breach requirements
- County/state land records, title/escrow, attorney, and closing practices
- State and federal energy/mineral/environmental regulators

The platform must treat changing rules as versioned policy, not hard-coded assumptions. For example, FinCEN currently states that a March 19, 2026 federal court order vacated its Residential Real Estate Rule and that the government appealed. That status can change and therefore requires monitored policy configuration rather than permanent application logic.

### Mexico

- eXp Mexico brokerage and agent/adviser controls
- State and municipal property, registry, cadastral, and tax requirements
- Public notary workflow
- SAT vulnerable-activity/AML requirements where applicable
- SRE restricted-zone and fideicomiso workflow for applicable foreign ownership
- Ejido/communal-property and authority-to-transfer review
- Federal and state energy, mining, environmental, and foreign-investment requirements

This roadmap is a product and engineering control plan. Country and jurisdiction launches require written review by the responsible eXp brokerage/compliance leadership and qualified local legal professionals.

## 13. Delivery phases

All three countries remain in scope. The waves are release controls, not scope reductions.

### Phase 0 — Engineering control foundation

Goal: Make every future change reproducible, reviewable, testable, and reversible.

Work:

- Create a private Git repository and protected main branch
- Record the current working tree as an auditable baseline
- Archive and remove route access to legacy duplicate implementations
- Separate local, development, staging, and production Firebase projects
- Make one documented build and deployment pipeline
- Correct Hosting source-of-truth and deployment manifests
- Add automated Flutter analyze, unit/widget tests, Functions tests, rules tests, and web builds
- Add dependency, secret, and vulnerability checks
- Add release version, migration, rollback, backup, and recovery procedures

Exit gate:

- A clean checkout builds without manual SDK changes
- Staging and production deploy from identified commits
- Rollback is tested
- No production route imports retired duplicate modules
- Firestore and Storage emulator tests run in CI

### Phase 1 — Production safety and identity

Goal: Protect accounts, files, messages, offers, auctions, dispatch, and administrative actions.

Work:

- App Check for supported clients and protected backend endpoints
- Verified email plus phone verification and controlled account recovery
- Duplicate-account, bot, abuse, and rate-limit controls
- Server-controlled commands for sensitive state changes
- Least-privilege Firestore and Storage rules
- Idempotency and transaction controls for offers, bids, acceptance, and dispatch quotes
- Deploy and monitor all moderation functions
- Add real image/text risk classification with human review and appeal
- Add permanent audit events and structured error reporting
- Add in-app, email, push, and critical SMS notification architecture
- Publish versioned terms, privacy, marketplace, auction, dispatch, moderation, and consent records
- Complete mobile signing, permissions, product identity, and store-readiness controls

Exit gate:

- Critical state transitions cannot be forged by a client
- Rules and callable functions have emulator coverage
- Account, upload, moderation, notification, offer, bid, and dispatch failures are observable
- Users can recover without duplicate identities or orphaned data
- Administrative access and actions are auditable

### Phase 2 — Complete the current marketplace

Goal: Finish and stabilize the existing equipment/materials/auction/wanted/dispatch product.

Work:

- Replace demo/fallback data with explicit empty, loading, offline, and error states
- Add indexed server-side search, filters, pagination, sorting, and geospatial querying
- Complete offer, revision, acceptance, archive, and conversation workflows
- Complete auction lifecycle, bid withdrawal rules, reserve-owner privacy, fees, settlement status, and notifications
- Complete wanted-ad matching and alerts
- Complete dispatch job/quote revision history, map routing, road distance, saved routes, fleet capacity, and job notifications
- Expand weight/catalog confidence, correction suggestions, and administrator review
- Add analytics with documented calculation definitions
- Add end-to-end tests for buyer, seller, bidder, dispatcher, reporter, and administrator journeys

Exit gate:

- Every current primary workflow passes web and mobile acceptance tests
- Search and lists work beyond small client-side datasets
- No demo record is shown as real data
- Offers, auctions, and dispatch histories are consistent and immutable

### Phase 3 — North American jurisdiction engine

Goal: Build the common control system before public property listings.

Work:

- Implement jurisdiction policies, effective versions, feature flags, and kill switches
- Implement eXp country entities, brokerages, offices, licences, agents, and compliance roles
- Implement assignment and escalation queues
- Implement form/disclosure requirements and signed acknowledgements
- Implement CAD, USD, and MXN money objects with locale-safe formatting
- Implement English, French, and Spanish content architecture
- Implement country-specific address, parcel, legal-description, timezone, and measurement models
- Implement source attribution, data licensing, and retention rules
- Build compliance dashboards and audit reports

Exit gate:

- The system cannot publish outside an active, approved policy pack
- Licence and form expiry automatically prevents affected actions
- eXp reviewers can control listings without platform engineering intervention
- Country and subdivision tests prove that data and rules do not bleed across jurisdictions

### Phase 4 — Property and rights core

Goal: Deliver the reusable eXp-controlled property workflow.

Work:

- Property, parcel, legal-description, ownership-interest, and encumbrance schemas
- Guided listing forms by property class
- Identity, authority-to-list, agent assignment, and compliance review
- Public listing, private marketing, coming-soon, suspended, and closed states
- Secure data rooms and qualified-buyer access
- Inquiry, showing/inspection request, LOI, offer, revision, and condition tracking
- Brokerage-controlled communications and notifications
- Referral to approved closing professionals
- Listing, lead, compliance, and transaction analytics

Exit gate:

- A complete test property moves from draft to professional closing referral
- Unauthorized documents and private fields never appear publicly
- eXp can approve, reject, correct, pause, and unpublish
- Offers remain brokerage-controlled and do not incorrectly imply legal transfer

### Phase 5 — Canada activation

Goal: Activate every supported Canadian province/territory through controlled waves.

Recommended first operational wave: Alberta and British Columbia, followed by additional provinces as their eXp, form, board/MLS, FINTRAC, privacy, land-title, and closing configurations are approved.

Work per jurisdiction:

- eXp brokerage entity, licence, office, agent, and supervising broker records
- Provincial regulator, advertising, representation, disclosure, and deposit rules
- Board/MLS/CREA data permissions
- FINTRAC and beneficial-owner workflow
- Privacy, consent, retention, and breach controls
- Land-title identity and closing workflow
- Energy/mineral/surface regulator mapping
- French experience and Quebec-specific review before Quebec activation

Exit gate per province/territory:

- Written eXp brokerage/compliance approval
- Valid licence and agent roster
- Approved forms and public wording
- AML, privacy, title, and closing review complete
- End-to-end tests and rollback completed

### Phase 6 — United States activation

Goal: Activate all U.S. states and applicable territories through state/MLS waves.

Recommended energy/commercial-first wave for planning: Texas, Oklahoma, New Mexico, North Dakota, Wyoming, Colorado, Pennsylvania, Ohio, and West Virginia. This does not exclude residential or the remaining states; it prioritizes where Pipe Buyer’s industrial and energy workflows have the strongest fit.

Work per state:

- Correct eXp entity, brokerage, office, supervising broker, and agent licences
- State commission and local advertising/disclosure rules
- MLS/board contract and RESO mapping
- Title, escrow, attorney, recorder, tax, and closing workflow
- Privacy, AML, sanctions, and beneficial-owner policy
- State and federal mineral/energy/environmental integration
- County/parish/borough parcel and recorder mapping

Exit gate per state:

- Written eXp brokerage/compliance approval
- State and MLS permissions verified
- State-specific forms and transaction path loaded
- Security, privacy, title/escrow, AML, and regulator tests passed

### Phase 7 — Mexico activation

Goal: Activate Mexico with Spanish-first workflows and state/municipality controls.

Work:

- Grupo eXp Realtors Mexico entity, approved agent/adviser, and compliance structure
- State, municipality, registry, cadastre, tax, and notary workflows
- Escritura, folio real, cadastral key, authority, lien, and document verification
- Restricted-zone, foreign-buyer, SRE permit, and fideicomiso decision flow
- Ejido/communal-property review and automatic hold when specialist review is required
- SAT vulnerable-activity/AML configuration
- Spanish legal content and bilingual support workflow
- MXN pricing with controlled USD/CAD display conversions

Exit gate per state/market:

- Written eXp Mexico and local legal approval
- Approved public wording, documents, and notary path
- Foreign-ownership and ejido controls tested
- AML, privacy, registry, and closing tests passed

### Phase 8 — Mineral, surface, royalty, and energy interests

Goal: Add specialist rights and regulated-asset transaction paths without representing them as ordinary land sales.

Work:

- Interest type, percentage, depth/formation, legal location, term, encumbrance, and revenue schemas
- Ownership and chain-of-title evidence
- Production, reserve, royalty, operator, well, facility, and obligation data
- Confidential data rooms, NDA, qualification, and specialist review
- Country/state/province regulator transfer checklists
- Environmental, abandonment, reclamation, and liability disclosure
- Bid/LOI analytics that clearly distinguish gross value, net interest, and assumptions

Exit gate:

- Every listing identifies the exact interest and evidence
- Applicable regulatory transfer is a separate tracked condition
- Liability and environmental information cannot be omitted from a regulated-asset package

### Phase 9 — Business marketplace

Goal: Support confidential sales of industrial, energy, property, and service businesses.

Work:

- Asset sale, equity/share sale, property sale, and mixed-deal classification
- Teaser, NDA, qualification, confidential information memorandum, and data room
- Financial, customer, employee, fleet, licence, contract, litigation, and environmental diligence
- LOI, revisions, conditions, advisers, and closing milestones
- Jurisdictional business-brokerage and securities screening

Exit gate:

- The platform blocks unapproved securities-related promotion
- Confidential records use tiered access and complete auditing
- The deal structure is explicit before offers are accepted

### Phase 10 — Scale and operations

Goal: Operate the platform as critical professional infrastructure.

Work:

- Security program, threat modelling, penetration testing, and incident response
- Backup, restore, disaster recovery, and business-continuity testing
- Service-level objectives and on-call ownership
- Fraud, moderation, compliance, and customer-support case management
- Data-quality monitoring and integration reconciliation
- Financial reconciliation for platform fees
- Country and jurisdiction health dashboards
- Accessibility, localization, performance, and mobile quality programs

Exit gate:

- Recovery objectives are proven
- High-risk incidents have documented and tested playbooks
- Jurisdiction owners can see licences, forms, integrations, queues, and failures in one control dashboard

## 14. First implementation backlog

### Control

- `CTRL-001` Create the private source repository and baseline commit
- `CTRL-002` Create staging and production environment boundaries
- `CTRL-003` Establish CI checks and controlled deployment
- `CTRL-004` Create backup, rollback, and release records
- `CTRL-005` Archive duplicate legacy routes and implementations

### Security and reliability

- `SEC-001` Harden Firestore and Storage rules with emulator tests
- `SEC-002` Move sensitive state changes to authenticated server commands
- `SEC-003` Add App Check, verification, anti-bot, and rate-limit controls
- `SEC-004` Deploy and monitor all moderation functions
- `SEC-005` Add structured errors, correlation IDs, audit events, and alerts

### Marketplace foundation

- `MKT-001` Replace demo fallbacks with explicit states
- `MKT-002` Add indexed search, filters, pagination, and geospatial queries
- `MKT-003` Validate offer/auction/wanted workflows end to end
- `DSP-001` Complete live dispatch jobs, quote revisions, and history
- `DSP-002` Replace straight-line distance with routed distance

### eXp and jurisdiction foundation

- `JUR-001` Define jurisdiction-policy schema and resolver
- `JUR-002` Define eXp entity, brokerage, office, licence, and agent schemas
- `JUR-003` Define compliance roles, queues, decisions, and audit events
- `JUR-004` Define form/disclosure versions and expiry controls
- `JUR-005` Define North American money, locale, measurement, and property identity

### Property and rights

- `PRP-001` Define property, parcel, legal-description, and interest schemas
- `PRP-002` Define authority-to-list and compliance review workflow
- `PRP-003` Build data-room security model
- `PRP-004` Build inquiry, LOI/offer, revision, condition, and closing-referral model
- `PRP-005` Build country-specific policy-pack fixtures and tests

## 15. Definition of done for a jurisdiction

A jurisdiction is not production-ready until all items below are evidenced:

- Responsible eXp entity and brokerage identified
- Supervising broker/compliance owner assigned
- Brokerage and agent licences verified and expiry monitored
- Permitted listing classes documented
- Approved listing, advertising, representation, disclosure, offer, and closing workflow loaded
- Listing-data agreements and display rules recorded
- Identity, authority, AML, sanctions, and beneficial-owner controls approved
- Privacy, consent, retention, deletion, and breach procedures approved
- Parcel/title/registry and closing-professional workflow validated
- Mineral, surface, energy, and environmental controls configured where enabled
- Customer support and compliance escalation trained
- Automated policy, security, and end-to-end tests passed
- Staged launch, monitoring, suspension, and rollback tested
- Written eXp and qualified local legal/compliance approval recorded

## 16. Product analytics

Analytics must explain their calculation and must not imply an appraisal, reserve report, legal opinion, or investment recommendation.

Recommended dashboards:

- Listing completeness and compliance readiness
- Time in compliance review and correction cycles
- Inquiry-to-qualified-buyer conversion
- Data-room access and due-diligence progress
- Offer/LOI value, conditions, dates, and revision comparisons
- Listing exposure by approved channel
- Jurisdiction, brokerage, agent, and listing health
- Licence/form/integration expiry risk
- Dispatch estimate versus accepted/final cost
- Rights and energy listing data quality and missing evidence
- Fraud, moderation, report, appeal, and resolution trends

## 17. Required business decisions

These decisions do not stop engineering-control work, but they must be resolved before public property activation:

1. Written relationship among Pipe Buyer and each applicable eXp country entity
2. Rights to eXp branding, agent roster, brokerage data, listings, leads, and APIs
3. Supervising brokerage and compliance owner in every jurisdiction
4. Referral, advertising, subscription, listing, success-fee, and transaction-fee model
5. Whether Pipe Buyer is a brokerage-facing technology provider, referral platform, advertising platform, or another approved role per jurisdiction
6. Who prepares and controls each form, signature, offer, deposit, and transaction record
7. Which title, escrow, lawyer, notary, identity, AML, and data providers are approved
8. Whether any deposits or client money will ever enter Pipe Buyer systems; initial recommendation is no
9. Insurance, indemnity, incident, record-retention, and customer-support ownership

## 18. Recommended starting sprint

Start with Phase 0 and the schema-only portion of Phase 3 in parallel:

1. Put the current application under controlled source, build, test, and deployment management.
2. Establish development, staging, and production boundaries.
3. Remove duplicate route implementations from active use while preserving a recoverable archive.
4. Fix the Hosting source-of-truth and deploy only tested build artifacts.
5. Add emulator coverage before changing security rules or sensitive transaction functions.
6. Create the jurisdiction-policy, eXp-entity, brokerage, licence, agent, compliance-role, and audit-event schemas.
7. Build Canada/U.S./Mexico fixture packs with publishing disabled.
8. Review those schemas with eXp and qualified country/jurisdiction compliance owners.

This sequence allows the full North American architecture to begin immediately without putting unapproved property transactions into production.

## 19. Official reference starting points

- [eXp World Holdings privacy and country responsible entities](https://expworldholdings.com/privacy-policy/)
- [eXp companies covered by its privacy and data-processing policy](https://expworldholdings.com/companies-subject-to-the-exp-world-holdings-inc-privacy-policy-and-data-processing-policy/)
- [eXp Realty Canada](https://join.exprealty.ca/)
- [eXp Mexico expansion announcement](https://expworldholdings.com/press-releases/exp-world-holdings-expands-real-estate-operations-into-mexico/)
- [RESO Web API](https://www.reso.org/reso-web-api/)
- [CREA DDF policy and rules](https://www.crea.ca/files/technology/english/DDFR-Policy-and-Rules-February-2024-ENG.pdf)
- [FINTRAC real-estate guidance](https://fintrac-canafe.canada.ca/re-ed/real-eng)
- [FinCEN Residential Real Estate Rule status](https://www.fincen.gov/rre)
- [Mexico SRE restricted-zone fideicomiso process](https://portales.sre.gob.mx/tramites-dgaj/art-27-constitucional/permiso-para-constitucion-de-fideicomiso-sobre-inmuebles-localizados-dentro-de-la-zona-restringida)
- [Mexico SAT vulnerable activities](https://wwwnp.sat.gob.mx/minisitio/ActividadesVulnerables/index.html)
- [Mexico property acquisition guidance](https://consulmex.sre.gob.mx/reinounido/index.php/en/servicios/218-acquisition-of-properties-in-mexico)
- [Alberta real-estate licensing information](https://www.reca.ca/which-industry/)
- [Alberta Energy Regulator asset transfers](https://www.aer.ca/regulations-and-compliance-enforcement/liability-management-programs/transfers)

