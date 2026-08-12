from pathlib import Path
import re


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected one literal match, found {count}: {old[:100]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


def regex_once(path, pattern, replacement):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f'{path}: expected one regex match, found {count}: {pattern[:120]!r}')
    p.write_text(updated, encoding='utf-8')


# ---------------------------------------------------------------------------
# Server-side Dispatch policy: no admin review, 70% signup, paid bids.
# ---------------------------------------------------------------------------
policy = 'firebase/functions/dispatch_command_policy.js'
replace_once(
    policy,
    '    companyName: requireText(data.companyName, "Company name", 160),',
    '    companyName: optionalText(data.companyName, "Company name", 160) ||\n'
    '      requireText(data.operatingName, "Operating name", 160),',
)
replace_once(
    policy,
    '  carrier,\n  vehicle,\n  existingBid,',
    '  carrier,\n  membership,\n  vehicle,\n  existingBid,',
)
replace_once(
    policy,
    '    carrier.status !== "active" ||\n'
    '    carrier.providerReviewVersion !== 1 ||\n'
    '    carrier.availableForHire === false\n'
    '  ) {\n'
    '    throw new CommandPolicyError(\n'
    '        "permission-denied",\n'
    '        "Dispatch provider approval and availability are required before quoting.",\n'
    '    );\n'
    '  }',
    '    carrier.status !== "active" ||\n'
    '    carrier.availableForHire === false\n'
    '  ) {\n'
    '    throw new CommandPolicyError(\n'
    '        "permission-denied",\n'
    '        "Join Dispatch and keep your provider profile available before bidding.",\n'
    '    );\n'
    '  }\n'
    '  const membershipEnd = timestampMillis(\n'
    '      membership && membership.currentPeriodEnd,\n'
    '  );\n'
    '  if (\n'
    '    !membership ||\n'
    '    membership.ownerUid !== actorUid ||\n'
    '    membership.active !== true ||\n'
    '    membershipEnd == null ||\n'
    '    membershipEnd <= timestampMillis(now)\n'
    '  ) {\n'
    '    throw new CommandPolicyError(\n'
    '        "permission-denied",\n'
    '        "An active Dispatch monthly or yearly membership is required before bidding.",\n'
    '    );\n'
    '  }',
)

commands = 'firebase/functions/dispatch_commands.js'
replace_once(
    commands,
    'function requireAuth(request) {\n  return requireAuthenticatedIdentity(request).uid;\n}\n',
    '''function requireAuth(request) {\n  return requireAuthenticatedIdentity(request).uid;\n}\n\nfunction nonEmpty(value) {\n  return String(value || "").trim().length > 0;\n}\n\nfunction dispatchSignupCompletion({identity, user, seller, business, privateBusiness}) {\n  const accountType = user && user.accountType === "business" ?\n    "business" : "personal";\n  const fields = accountType === "business" ? [\n    business && business.publicName,\n    privateBusiness && privateBusiness.legalName,\n    business && business.publicPhone,\n    business && business.publicEmail,\n    business && business.website,\n    business && (business.serviceArea || business.serviceAreaLabel),\n    privateBusiness && privateBusiness.privateAddress,\n    business && business.description,\n  ] : [\n    user && (user.display_name || seller && seller.displayName),\n    user && (user.verifiedPhoneE164 || user.pendingPhoneE164 ||\n      user.phone_number) || identity.phoneNumber,\n    user && (user.primaryCommunityLocation || user.baseCommunity) ||\n      seller && seller.baseCommunity,\n    user && user.sellerBio || seller && seller.description,\n  ];\n  const completed = fields.filter((value) => {\n    if (value && typeof value === "object") return true;\n    return nonEmpty(value);\n  }).length;\n  return Math.round(completed / fields.length * 100);\n}\n\nasync function requireActiveDispatchAccount(db, uid) {\n  const snapshot = await db.collection("dispatch_carriers").doc(uid).get();\n  if (!snapshot.exists || snapshot.data().status !== "active") {\n    throw new HttpsError(\n        "failed-precondition",\n        "Join Dispatch before viewing or posting Dispatch opportunities.",\n    );\n  }\n  return snapshot.data();\n}\n''',
)

regex_once(
    commands,
    r'  async function notifyAdministratorsOfProvider\(profile, revision\) \{.*?\n  const reviewDispatchProvider = dispatchCommand',
    '''  const submitDispatchProviderApplication = dispatchCommand(async (request) => {\n    const identity = requireAuthenticatedIdentity(request);\n    const requestId = requiredId(request.data, "requestId");\n    const profile = validateDispatchProviderApplication(request.data, identity);\n    const [userSnapshot, sellerSnapshot, businessSnapshot, privateBusinessSnapshot] =\n      await Promise.all([\n        db.collection("users").doc(identity.uid).get(),\n        db.collection("public_seller_profiles").doc(identity.uid).get(),\n        db.collection("public_business_profiles").doc(identity.uid).get(),\n        db.collection("business_private").doc(identity.uid).get(),\n      ]);\n    const completion = dispatchSignupCompletion({\n      identity,\n      user: userSnapshot.exists ? userSnapshot.data() : {},\n      seller: sellerSnapshot.exists ? sellerSnapshot.data() : {},\n      business: businessSnapshot.exists ? businessSnapshot.data() : {},\n      privateBusiness: privateBusinessSnapshot.exists ? privateBusinessSnapshot.data() : {},\n    });\n    if (completion < 70) {\n      throw new HttpsError(\n          "failed-precondition",\n          `Complete at least 70% of your Pipe Buyer profile before joining Dispatch. Current completion: ${completion}%.`,\n      );\n    }\n    const carrierRef = db.collection("dispatch_carriers").doc(identity.uid);\n    const receiptRef = receiptReference(\n        db, identity.uid, "submitDispatchProviderApplication", requestId,\n    );\n    return db.runTransaction(async (transaction) => {\n      const [receipt, carrierSnapshot] = await Promise.all([\n        transaction.get(receiptRef),\n        transaction.get(carrierRef),\n      ]);\n      if (receipt.exists) return receipt.data().result;\n      const current = carrierSnapshot.exists ? carrierSnapshot.data() : {};\n      const revision = Number(current.signupRevision || current.reviewRevision || 0) + 1;\n      const result = {\n        providerUid: identity.uid,\n        status: "active",\n        revision,\n        submitted: true,\n        profileCompletion: completion,\n      };\n      const verifiedContactMethod = identity.email && identity.phoneNumber ?\n        "email_and_phone" : identity.email ? "email" : "phone";\n      transaction.set(carrierRef, {\n        ownerUid: identity.uid,\n        ...profile,\n        serviceArea: providerServiceAreaValue(profile.serviceArea),\n        phone: profile.phoneE164,\n        status: "active",\n        availableForHire: true,\n        signupVersion: 2,\n        signupRevision: revision,\n        profileCompletionAtSignup: completion,\n        verifiedContactMethod,\n        privacyVersion: 3,\n        joinedAt: current.joinedAt || FieldValue.serverTimestamp(),\n        updatedAt: FieldValue.serverTimestamp(),\n        providerReviewVersion: FieldValue.delete(),\n        reviewReason: FieldValue.delete(),\n        reviewedAt: FieldValue.delete(),\n        reviewedByUid: FieldValue.delete(),\n        ...(carrierSnapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),\n      }, {merge: true});\n      transaction.create(\n          db.collection("dispatch_provider_review_events")\n              .doc(`${identity.uid}-${revision}-joined`),\n          {\n            providerUid: identity.uid,\n            revision,\n            event: "joined",\n            status: "active",\n            actorUid: identity.uid,\n            profileCompletion: completion,\n            createdAt: FieldValue.serverTimestamp(),\n          },\n      );\n      transaction.create(receiptRef, {\n        actorUid: identity.uid,\n        command: "submitDispatchProviderApplication",\n        result,\n        createdAt: FieldValue.serverTimestamp(),\n      });\n      return result;\n    });\n  });\n\n  const reviewDispatchProvider = dispatchCommand''',
)

replace_once(
    commands,
    '  const createDispatchJob = dispatchCommand(async (request) => {\n    const uid = requireAuth(request);',
    '  const createDispatchJob = dispatchCommand(async (request) => {\n    const uid = requireAuth(request);\n    await requireActiveDispatchAccount(db, uid);',
)
replace_once(
    commands,
    '    const vehicleRef = carrierRef.collection("vehicles").doc(vehicleId);\n\n'
    '    return db.runTransaction(async (transaction) => {',
    '    const vehicleRef = carrierRef.collection("vehicles").doc(vehicleId);\n'
    '    const membershipRef = db.collection("dispatch_memberships").doc(uid);\n\n'
    '    return db.runTransaction(async (transaction) => {',
)
replace_once(
    commands,
    '      const vehicleSnapshot = await transaction.get(vehicleRef);\n'
    '      const quotes = await transaction.get(',
    '      const vehicleSnapshot = await transaction.get(vehicleRef);\n'
    '      const membershipSnapshot = await transaction.get(membershipRef);\n'
    '      const quotes = await transaction.get(',
)
replace_once(
    commands,
    '      const vehicle =\n        vehicleSnapshot.exists ? vehicleSnapshot.data() : null;\n'
    '      const now = Timestamp.now();\n'
    '      const quote = validateDispatchQuote({\n'
    '        job,\n        carrier,\n        vehicle,',
    '      const vehicle =\n        vehicleSnapshot.exists ? vehicleSnapshot.data() : null;\n'
    '      const membership =\n        membershipSnapshot.exists ? membershipSnapshot.data() : null;\n'
    '      const now = Timestamp.now();\n'
    '      const quote = validateDispatchQuote({\n'
    '        job,\n        carrier,\n        membership,\n        vehicle,',
)

pilot_code = r'''
  const createDispatchPilotRequest = dispatchCommand(async (request) => {
    const identity = requireAuthenticatedIdentity(request);
    const requestId = requiredId(request.data, "requestId");
    await requireActiveDispatchAccount(db, identity.uid);
    const textField = (field, maximum) => {
      const value = String(request.data && request.data[field] || "").trim();
      if (!value || value.length > maximum) {
        throw new HttpsError(
            "invalid-argument",
            `${field} is required and must be ${maximum} characters or fewer.`,
        );
      }
      return value;
    };
    const pickupLabel = textField("pickupLabel", 500);
    const deliveryLabel = textField("deliveryLabel", 500);
    const details = textField("details", 2000);
    const requestedDate = Number(request.data && request.data.requestedDate);
    const nowMillis = Date.now();
    if (!Number.isInteger(requestedDate) ||
        requestedDate < nowMillis - 24 * 60 * 60 * 1000 ||
        requestedDate > nowMillis + 730 * 24 * 60 * 60 * 1000) {
      throw new HttpsError(
          "invalid-argument",
          "Pilot service date must be within the next two years.",
      );
    }
    const pilotVehicles = await db.collectionGroup("vehicles")
        .where("pilotTruck", "==", true)
        .limit(200)
        .get();
    const candidateUids = [...new Set(pilotVehicles.docs
        .filter((vehicle) => vehicle.data().available !== false)
        .map((vehicle) => vehicle.ref.parent.parent && vehicle.ref.parent.parent.id)
        .filter((uid) => uid && uid !== identity.uid))];
    const carrierSnapshots = candidateUids.length > 0 ?
      await db.getAll(...candidateUids.map((uid) =>
        db.collection("dispatch_carriers").doc(uid))) : [];
    const recipients = carrierSnapshots
        .filter((snapshot) => snapshot.exists &&
          snapshot.data().status === "active" &&
          snapshot.data().availableForHire !== false)
        .map((snapshot) => snapshot.id)
        .slice(0, 200);
    const requestRef = db.collection("dispatch_pilot_requests").doc(requestId);
    const receiptRef = receiptReference(
        db, identity.uid, "createDispatchPilotRequest", requestId,
    );
    const result = {
      requestId,
      notifiedPilotProviders: recipients.length,
      status: "open",
    };
    await db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return;
      transaction.create(requestRef, {
        requesterUid: identity.uid,
        pickupLabel,
        deliveryLabel,
        details,
        requestedDate: Timestamp.fromMillis(requestedDate),
        status: "open",
        schemaVersion: 1,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      for (const recipientUid of recipients) {
        transaction.set(
            db.collection("users").doc(recipientUid)
                .collection("notifications")
                .doc(`pilot-${requestId}`),
            {
              recipientUid,
              actorUid: identity.uid,
              type: "dispatch",
              pilotRequestId: requestId,
              title: "Pilot service requested",
              body: `${pickupLabel} → ${deliveryLabel}. Open Dispatch Pilot services for details.`,
              read: false,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
      }
      transaction.create(receiptRef, {
        actorUid: identity.uid,
        command: "createDispatchPilotRequest",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
    });
    return result;
  });

'''
replace_once(commands, '  return {\n    awardDispatchQuote,', pilot_code + '  return {\n    awardDispatchQuote,')
replace_once(
    commands,
    '    createDispatchJob,\n    reviewDispatchProvider,',
    '    createDispatchJob,\n    createDispatchPilotRequest,\n    reviewDispatchProvider,',
)

# ---------------------------------------------------------------------------
# Stripe-paid Dispatch entitlement, driven by invoice.paid.
# ---------------------------------------------------------------------------
monetization = 'firebase/functions/subscription_monetization.js'
replace_once(
    monetization,
    'function subscriptionIdentityFromInvoice(invoice) {',
    '''function invoicePeriodBounds(invoice) {\n  const candidates = [];\n  const topStart = Number(invoice && invoice.period_start || 0);\n  const topEnd = Number(invoice && invoice.period_end || 0);\n  if (Number.isFinite(topStart) && topStart > 0) candidates.push({start: topStart});\n  if (Number.isFinite(topEnd) && topEnd > 0) candidates.push({end: topEnd});\n  const lines = invoice && invoice.lines && invoice.lines.data;\n  if (Array.isArray(lines)) {\n    for (const line of lines) {\n      const start = Number(line && line.period && line.period.start || 0);\n      const end = Number(line && line.period && line.period.end || 0);\n      if (Number.isFinite(start) && start > 0) candidates.push({start});\n      if (Number.isFinite(end) && end > 0) candidates.push({end});\n    }\n  }\n  const starts = candidates.map((item) => item.start).filter(Boolean);\n  const ends = candidates.map((item) => item.end).filter(Boolean);\n  return {\n    startMillis: starts.length ? Math.min(...starts) * 1000 : null,\n    endMillis: ends.length ? Math.max(...ends) * 1000 : null,\n  };\n}\n\nfunction subscriptionIdentityFromInvoice(invoice) {''',
)
replace_once(
    monetization,
    '    const sourceChargeId = sourceChargeFromInvoice(invoice);\n'
    '    const eligibleAfter = Timestamp.fromMillis(',
    '    const sourceChargeId = sourceChargeFromInvoice(invoice);\n'
    '    const period = invoicePeriodBounds(invoice);\n'
    '    const membershipRef = uid ?\n'
    '      db.collection("dispatch_memberships").doc(uid) : null;\n'
    '    const eligibleAfter = Timestamp.fromMillis(',
)
replace_once(
    monetization,
    '      const existingCommission = referrerUid && commissionMinor > 0 ?\n'
    '        await transaction.get(commissionRef) : null;\n'
    '      transaction.set(invoiceRef, {',
    '      const existingCommission = referrerUid && commissionMinor > 0 ?\n'
    '        await transaction.get(commissionRef) : null;\n'
    '      const existingMembership = membershipRef ?\n'
    '        await transaction.get(membershipRef) : null;\n'
    '      transaction.set(invoiceRef, {',
)
replace_once(
    monetization,
    '      if (referrerUid && commissionMinor > 0 &&\n'
    '          existingCommission && !existingCommission.exists) {',
    '''      if (membershipRef && period.endMillis) {\n        const currentEnd = existingMembership && existingMembership.exists &&\n          existingMembership.data().currentPeriodEnd &&\n          typeof existingMembership.data().currentPeriodEnd.toMillis === "function" ?\n          existingMembership.data().currentPeriodEnd.toMillis() : 0;\n        if (period.endMillis >= currentEnd) {\n          transaction.set(membershipRef, {\n            ownerUid: uid,\n            active: period.endMillis > Date.now(),\n            status: period.endMillis > Date.now() ? "active" : "expired",\n            plan: String(metadata.dispatchPlan || ""),\n            subscriptionId,\n            currentPeriodStart: period.startMillis ?\n              Timestamp.fromMillis(period.startMillis) : null,\n            currentPeriodEnd: Timestamp.fromMillis(period.endMillis),\n            lastPaidInvoiceId: invoiceId,\n            updatedAt: FieldValue.serverTimestamp(),\n          }, {merge: true});\n        }\n      }\n      if (referrerUid && commissionMinor > 0 &&\n          existingCommission && !existingCommission.exists) {''',
)
replace_once(
    monetization,
    '  invoiceCommissionBaseMinor,\n  retrieveStripeSubscription,',
    '  invoiceCommissionBaseMinor,\n  invoicePeriodBounds,\n  retrieveStripeSubscription,',
)

# ---------------------------------------------------------------------------
# Callable export.
# ---------------------------------------------------------------------------
index = 'firebase/functions/index.js'
replace_once(
    index,
    'exports.reviewDispatchProvider = onCall(\n',
    'exports.createDispatchPilotRequest = onCall(\n'
    '  protectedCallableOptions,\n'
    '  policyAcceptanceCommands.requireCurrentPolicies(\n'
    '    dispatchCommands.createDispatchPilotRequest,\n'
    '  ),\n'
    ');\n'
    'exports.reviewDispatchProvider = onCall(\n',
)

# ---------------------------------------------------------------------------
# Firestore: jobs are Dispatch-member-only; entitlements are server-owned.
# ---------------------------------------------------------------------------
rules = 'firebase/firestore.rules'
replace_once(
    rules,
    '    function validPhase1FeatureConfiguration() {',
    '''    function dispatchSignedUp() {\n      return signedIn() &&\n        exists(/databases/$(database)/documents/dispatch_carriers/$(request.auth.uid)) &&\n        get(/databases/$(database)/documents/dispatch_carriers/$(request.auth.uid)).data.status == 'active';\n    }\n\n    function validPhase1FeatureConfiguration() {''',
)
replace_once(
    rules,
    "    match /dispatch_jobs/{jobId} {\n      allow read: if phase1FeatureEnabled('dispatch') && signedIn();",
    "    match /dispatch_jobs/{jobId} {\n      allow read: if phase1FeatureEnabled('dispatch') &&\n        (dispatchSignedUp() || isAdmin());",
)
replace_once(
    rules,
    "        allow read: if phase1FeatureEnabled('dispatch') && signedIn();\n        allow create, update, delete: if false;\n      }\n    }\n\n    // Exact route points",
    "        allow read: if phase1FeatureEnabled('dispatch') &&\n          (dispatchSignedUp() || isAdmin());\n        allow create, update, delete: if false;\n      }\n    }\n\n    match /dispatch_memberships/{uid} {\n      allow read: if owns(uid) || isAdmin();\n      allow create, update, delete: if false;\n    }\n\n    match /dispatch_pilot_requests/{requestId} {\n      allow read: if phase1FeatureEnabled('dispatch') &&\n        (dispatchSignedUp() || isAdmin());\n      allow create, update, delete: if false;\n    }\n\n    // Exact route points",
)

# ---------------------------------------------------------------------------
# Flutter Dispatch UI: gate jobs behind signup, add membership & pilot request.
# ---------------------------------------------------------------------------
page = 'lib/marketplace/marketplace_dispatch_page.dart'
replace_once(
    page,
    "import 'marketplace_dispatch_repository.dart';",
    "import 'marketplace_dispatch_repository.dart';\nimport 'marketplace_dispatch_access.dart';",
)
regex_once(
    page,
    r'class _MarketplaceDispatchPageState extends State<MarketplaceDispatchPage> \{.*?\n\}\n\nclass _PilotTruckSection',
    '''class _MarketplaceDispatchPageState extends State<MarketplaceDispatchPage> {\n  final repo = MarketplaceDispatchRepository();\n  int section = 0;\n\n  void _back(BuildContext context) {\n    if (context.canPop()) {\n      context.pop();\n    } else {\n      context.go('/');\n    }\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    if (FirebaseAuth.instance.currentUser == null) {\n      return const Center(child: Text('Sign in to use Dispatch.'));\n    }\n    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(\n      stream: repo.carrierProfile(),\n      builder: (context, carrierSnapshot) {\n        if (carrierSnapshot.connectionState == ConnectionState.waiting) {\n          return const Center(child: CircularProgressIndicator());\n        }\n        final joined = dispatchAccountIsActive(carrierSnapshot.data?.data());\n        return Column(\n          children: [\n            Padding(\n              padding: const EdgeInsets.fromLTRB(10, 12, 18, 10),\n              child: Column(\n                crossAxisAlignment: CrossAxisAlignment.start,\n                children: [\n                  Row(\n                    children: [\n                      IconButton(\n                        tooltip: 'Back',\n                        onPressed: () => _back(context),\n                        icon: const Icon(Icons.arrow_back),\n                      ),\n                      const SizedBox(width: 4),\n                      const Expanded(\n                        child: Column(\n                          crossAxisAlignment: CrossAxisAlignment.start,\n                          children: [\n                            Text('Dispatch',\n                                style: TextStyle(\n                                    fontSize: 28, fontWeight: FontWeight.w900)),\n                            Text(\n                              'Professional trucking services, load opportunities and carrier bids.',\n                            ),\n                          ],\n                        ),\n                      ),\n                      const SizedBox(width: 12),\n                      const IndustrialAssetIcon(\n                        label: 'Dispatch load board',\n                        assetPath: IndustrialIconAssets.dispatchLoadBoard,\n                        size: 62,\n                        borderRadius: 12,\n                        fallback: Icon(Icons.local_shipping_outlined,\n                            size: 42, color: Color(0xFF0878E8)),\n                      ),\n                    ],\n                  ),\n                  if (joined) ...[\n                    const SizedBox(height: 12),\n                    SingleChildScrollView(\n                      scrollDirection: Axis.horizontal,\n                      child: SegmentedButton<int>(\n                        showSelectedIcon: false,\n                        segments: const [\n                          ButtonSegment(value: 0, icon: Icon(Icons.dashboard_outlined), label: Text('Dashboard')),\n                          ButtonSegment(value: 1, icon: Icon(Icons.local_shipping_outlined), label: Text('Jobs')),\n                          ButtonSegment(value: 2, icon: Icon(Icons.add_road_outlined), label: Text('Post')),\n                          ButtonSegment(value: 3, icon: Icon(Icons.workspace_premium_outlined), label: Text('Membership')),\n                          ButtonSegment(value: 4, icon: Icon(Icons.assistant_direction_outlined), label: Text('Pilot')),\n                        ],\n                        selected: {section},\n                        onSelectionChanged: (value) =>\n                            setState(() => section = value.first),\n                      ),\n                    ),\n                  ],\n                ],\n              ),\n            ),\n            Expanded(\n              child: !joined\n                  ? _CarrierEnrollment(repo: repo)\n                  : section == 0\n                      ? MarketplaceDispatchDashboard(\n                          repo: repo,\n                          onPostLoad: () => setState(() => section = 2),\n                          onBrowseJobs: () => setState(() => section = 1),\n                          onJoinCarrier: () => setState(() => section = 3),\n                        )\n                      : section == 1\n                          ? _JobBoard(repo: repo)\n                          : section == 2\n                              ? _PostJob(repo: repo)\n                              : section == 3\n                                  ? _CarrierEnrollment(repo: repo)\n                                  : _PilotTruckSection(repo: repo),\n            ),\n          ],\n        );\n      },\n    );\n  }\n}\n\nclass _PilotTruckSection''',
)
replace_once(
    page,
    "          const SizedBox(height: 12),\n          const Card(\n            color: Color(0xFFFFF4E5),",
    "          const SizedBox(height: 12),\n          const DispatchPilotRequestCard(),\n          const SizedBox(height: 12),\n          const Card(\n            color: Color(0xFFFFF4E5),",
)
replace_once(
    page,
    "          final signedUp = snapshot.data?.exists == true;\n          final carrierData = snapshot.data?.data();\n          final storedStatus = '${carrierData?['status'] ?? ''}';\n          final effectiveStatus = storedStatus == 'active' &&\n                  carrierData?['providerReviewVersion'] != 1\n              ? 'review_required'\n              : storedStatus;",
    "          final carrierData = snapshot.data?.data();\n          final signedUp = dispatchAccountIsActive(carrierData);\n          final effectiveStatus = '${carrierData?['status'] ?? ''}';",
)
replace_once(
    page,
    "              const SizedBox(height: 12),\n              if (!signedUp || editingApplication)\n                _signupForm()",
    "              const SizedBox(height: 12),\n              const DispatchSignupEligibilityCard(),\n              const SizedBox(height: 10),\n              if (!signedUp || editingApplication)\n                _signupForm()",
)
replace_once(
    page,
    "                _accountSummary(snapshot.data!.data()!),\n                _providerReviewHistory(),",
    "                _accountSummary(snapshot.data!.data()!),\n                const DispatchMembershipCard(),\n                _providerReviewHistory(),",
)
replace_once(page, "(legal, 'Company name', Icons.business_outlined),", "(legal, 'Company / team name (optional)', Icons.business_outlined),")
replace_once(
    page,
    "                  labelText: '${field.$2} *',",
    "                  labelText:\n                      '${field.$2}${identical(field.$1, operating) ? ' *' : ''}',",
)
replace_once(
    page,
    "                validator: (v) =>\n                    v == null || v.trim().isEmpty ? 'Required' : null,",
    "                validator: (v) => identical(field.$1, operating) &&\n                        (v == null || v.trim().isEmpty)\n                    ? 'Required'\n                    : null,",
)
replace_once(
    page,
    "                labelText: 'Verified Dispatch phone *',\n                prefixIcon: Icon(Icons.phone_outlined),\n                helperText: 'Uses the mobile number verified on your account.',\n              ),\n              validator: (value) => value == null || value.trim().isEmpty\n                  ? 'Verify a mobile number in Account Settings first.'\n                  : null,",
    "                labelText: 'Verified Dispatch phone',\n                prefixIcon: Icon(Icons.phone_outlined),\n                helperText:\n                    'Either verified email or verified mobile is enough for Dispatch signup.',\n              ),",
)
replace_once(
    page,
    "                      if (!form.currentState!.validate() || area == null) {",
    "                      final authUser = FirebaseAuth.instance.currentUser;\n                      final verifiedContact = authUser?.emailVerified == true ||\n                          (authUser?.phoneNumber ?? '').trim().isNotEmpty;\n                      if (!verifiedContact) {\n                        PipeFeedback.show(\n                          context,\n                          message:\n                              'Verify either your email or phone number before joining Dispatch.',\n                          tone: PipeStatusTone.warning,\n                        );\n                        return;\n                      }\n                      if (!form.currentState!.validate() || area == null) {",
)
replace_once(
    page,
    "                                'Dispatch application submitted for administrator review.',\n                            tone: PipeStatusTone.info,",
    "                                'Dispatch signup complete. You can now view jobs; an active membership is required only before bidding.',\n                            tone: PipeStatusTone.success,",
)
replace_once(
    page,
    "                    ? 'Submitting Dispatch application…'\n                    : 'Submit for review',",
    "                    ? 'Joining Dispatch…'\n                    : 'Join Dispatch',",
)
replace_once(
    page,
    "    final storedStatus = '${data['status'] ?? 'pending_review'}';\n    final status =\n        storedStatus == 'active' && data['providerReviewVersion'] != 1\n            ? 'review_required'\n            : storedStatus;",
    "    final status = '${data['status'] ?? 'active'}';",
)
replace_once(page, "      'active' => 'APPROVED',", "      'active' => 'JOINED',")
replace_once(page, "              title: const Text('Application history'),", "              title: const Text('Dispatch signup history'),")
replace_once(page, "                    label: const Text('Update and resubmit application'),", "                    label: const Text('Update Dispatch signup'),")

# Client pilot request idempotency key.
access = 'lib/marketplace/marketplace_dispatch_access.dart'
replace_once(
    access,
    "      final result = await _commands.execute(\n        'createDispatchPilotRequest',\n        submitted,",
    "      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'dispatch';\n      final result = await _commands.execute(\n        'createDispatchPilotRequest',\n        {\n          ...submitted,\n          'requestId': '${uid}_${DateTime.now().microsecondsSinceEpoch}',\n        },",
)

# ---------------------------------------------------------------------------
# Current Dispatch onboarding pricing and requirements.
# ---------------------------------------------------------------------------
onboarding = 'lib/marketplace/marketplace_dispatch_onboarding.dart'
replace_once(onboarding, "'Proposed pilot network pricing'", "'Dispatch membership pricing'")
replace_once(onboarding, "title: r'$25 per year',\n                  subtitle: 'Dispatch network membership',", "title: r'CAD $25 per month',\n                  subtitle: 'Monthly carrier bidding membership',")
replace_once(onboarding, "title: r'$10 per dispatched job',\n                  subtitle: 'Paid to Pipe Buyer',", "title: r'CAD $300 per year',\n                  subtitle: 'Yearly carrier bidding membership',")
replace_once(
    onboarding,
    "              r'The $10 Dispatch fee is paid to Pipe Buyer for each dispatched job. Pricing is displayed for pilot planning only. Billing and fee collection are not active in this release. No charge is collected until payment and fee features receive separate approval, final terms are published, and the user explicitly accepts them.',",
    "              'Joining Dispatch is free. Signed-up users can view and post Dispatch jobs. An active monthly or yearly Stripe membership is required only before a carrier submits a bid.',",
)
replace_once(onboarding, "'Carrier profile requirements'", "'Dispatch signup requirements'")
replace_once(
    onboarding,
    "'Providers identify their service areas, equipment, payload limits, insurance and operating details. Job-specific permits, licensing, hours-of-service, escort, and safety requirements remain the provider’s responsibility.'",
    "'Any user can join after completing at least 70% of their Pipe Buyer profile and verifying either their email or mobile number. Carrier equipment and service details are added when the user wants to bid or provide trucking services.'",
)
replace_once(onboarding, "label: const Text('Start carrier signup'),", "label: const Text('Join Dispatch'),")

# ---------------------------------------------------------------------------
# Tests: membership replaces admin approval as the quote gate.
# ---------------------------------------------------------------------------
test_policy = 'firebase/functions/test/dispatch_command_policy.test.js'
replace_once(
    test_policy,
    'test("carrier quote validates enrollment, fleet ownership, and payload", () => {',
    'test("carrier quote validates signup, paid membership, fleet ownership, and payload", () => {',
)
replace_once(
    test_policy,
    '      providerReviewVersion: 1,\n      availableForHire: true,\n    },\n    vehicle:',
    '      availableForHire: true,\n    },\n    membership: {\n      ownerUid: "carrier",\n      active: true,\n      currentPeriodEnd: now.getTime() + 30 * 24 * 60 * 60 * 1000,\n    },\n    vehicle:',
)
# Add membership to subsequent quote fixtures that exercise other failures.
text = Path(test_policy).read_text(encoding='utf-8')
text = text.replace(
    '        vehicle: {\n          ownerUid: "carrier",',
    '        membership: {\n          ownerUid: "carrier",\n          active: true,\n          currentPeriodEnd: now.getTime() + 30 * 24 * 60 * 60 * 1000,\n        },\n        vehicle: {\n          ownerUid: "carrier",',
)
text = text.replace('          providerReviewVersion: 1,\n', '')
Path(test_policy).write_text(text, encoding='utf-8')

# Add an explicit unpaid-membership assertion just before payload validation case.
needle = '''  assert.throws(\n      () => validateDispatchQuote({\n        job: {\n          createdByUid: "customer",\n          status: "open",\n          estimatedWeightKg: 30000,\n        },'''
insert = '''  assert.throws(\n      () => validateDispatchQuote({\n        job: {createdByUid: "customer", status: "open"},\n        carrier: {ownerUid: "carrier", status: "active", availableForHire: true},\n        membership: {\n          ownerUid: "carrier",\n          active: false,\n          currentPeriodEnd: now.getTime() - 1000,\n        },\n        vehicle: {ownerUid: "carrier", available: true, maximumPayloadKg: 25000},\n        existingBid: null,\n        actorUid: "carrier",\n        data: {\n          jobId: "job",\n          amount: 2500,\n          availableDate: now.getTime() + 24 * 60 * 60 * 1000,\n        },\n        now,\n      }),\n      (error) => error.code === "permission-denied" &&\n        /membership/.test(error.message),\n  );\n'''
replace_once(test_policy, needle, insert + needle)

print('Dispatch open-signup/membership/pilot patch applied successfully.')
