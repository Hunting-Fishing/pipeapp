import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';

String officialRegulatorPortalUrl(String jurisdiction) {
  return switch (jurisdiction.trim()) {
    'CA-AB (Alberta)' => 'https://www.myreca.ca/public-search/',
    'CA-BC (British Columbia)' =>
      'https://www.bcfsa.ca/public-protection/find-professional',
    'CA-SK (Saskatchewan)' =>
      'https://www.srec.ca/consumers/find-a-registrant/',
    'CA-MB (Manitoba)' => 'https://mbrealestate.ca/',
    'CA-ON (Ontario)' => 'https://www.reco.on.ca/public-register',
    'CA-QC (Quebec)' => 'https://www.oaciq.com/en/find-a-broker',
    'CA-NB (New Brunswick)' => 'https://fcnb.ca/en/real-estate',
    'CA-NS (Nova Scotia)' => 'https://nsrec.ns.ca/consumers/licensee-search',
    'CA-NL (Newfoundland & Labrador)' =>
      'https://www.gov.nl.ca/dgsnl/licences/real-estate/',
    'US-TX (Texas)' => 'https://www.trec.texas.gov/apps/license-holder-search/',
    'US-ND (North Dakota)' => 'https://www.realestatend.org/licensee_search/',
    'US-OK (Oklahoma)' =>
      'https://orec.us.thentiacloud.net/webs/orec/register/',
    'US-NM (New Mexico)' =>
      'https://nmrld.my.site.com/bcd/s/public-search-license',
    'US-LA (Louisiana)' => 'https://lrec.gov/consumers/active-licensee-search/',
    'US-WY (Wyoming)' =>
      'https://realestate.wyo.gov/consumers/verify-a-license',
    'US-MT (Montana)' =>
      'https://ebizws.mt.gov/PUBLICPORTAL/searchform?mylist=licenses',
    'US-CO (Colorado)' =>
      'https://apps2.colorado.gov/dora/licensing/lookup/licenselookup.aspx',
    'US-PA (Pennsylvania)' => 'https://www.pals.pa.gov/#/page/search',
    'US-OH (Ohio)' => 'https://elicense3.com.ohio.gov/',
    'US-AK (Alaska)' =>
      'https://www.commerce.alaska.gov/cbp/main/search/professional',
    'US-CA (California)' => 'https://www2.dre.ca.gov/PublicASP/pplinfo.asp',
    'US-FL (Florida)' => 'https://www.myfloridalicense.com/wl11.asp',
    'MX (Mexico)' => 'https://ampi.org/',
    _ => 'https://www.arello.org/',
  };
}

class ExpBrokerageOption {
  const ExpBrokerageOption({
    required this.id,
    required this.legalName,
    required this.countryCode,
  });

  final String id;
  final String legalName;
  final String countryCode;
}

const kDefaultExpBrokerageOptions = <ExpBrokerageOption>[
  ExpBrokerageOption(
    id: 'exp-realty-canada',
    legalName: 'eXp Realty of Canada, Inc.',
    countryCode: 'CA',
  ),
  ExpBrokerageOption(
    id: 'exp-realty-us',
    legalName: 'eXp Realty, LLC',
    countryCode: 'US',
  ),
  ExpBrokerageOption(
    id: 'exp-realtors-mexico',
    legalName: 'Grupo eXp Realtors Mexico, S. DE R.L. DE CV',
    countryCode: 'MX',
  ),
  ExpBrokerageOption(
    id: 'other-licensed-brokerage',
    legalName: 'Other Licensed Brokerage',
    countryCode: 'NA',
  ),
];

const kNorthAmericaRealtorJurisdictions = <String>[
  'CA-AB (Alberta)',
  'CA-BC (British Columbia)',
  'CA-SK (Saskatchewan)',
  'CA-MB (Manitoba)',
  'CA-ON (Ontario)',
  'CA-QC (Quebec)',
  'CA-NB (New Brunswick)',
  'CA-NS (Nova Scotia)',
  'CA-NL (Newfoundland & Labrador)',
  'US-TX (Texas)',
  'US-ND (North Dakota)',
  'US-OK (Oklahoma)',
  'US-NM (New Mexico)',
  'US-LA (Louisiana)',
  'US-WY (Wyoming)',
  'US-MT (Montana)',
  'US-CO (Colorado)',
  'US-PA (Pennsylvania)',
  'US-OH (Ohio)',
  'US-AK (Alaska)',
  'US-CA (California)',
  'US-FL (Florida)',
  'MX (Mexico)',
  'Other Province / State',
];

class ExpRealtyProgramConfig {
  const ExpRealtyProgramConfig({
    required this.enabled,
    required this.agentApplicationsEnabled,
    required this.listingBrokerageAttributionEnabled,
    required this.buyerAgentLeadRoutingEnabled,
    required this.revision,
  });

  static const disabledDefault = ExpRealtyProgramConfig(
    enabled: false,
    agentApplicationsEnabled: true,
    listingBrokerageAttributionEnabled: true,
    buyerAgentLeadRoutingEnabled: true,
    revision: 0,
  );

  final bool enabled;
  final bool agentApplicationsEnabled;
  final bool listingBrokerageAttributionEnabled;
  final bool buyerAgentLeadRoutingEnabled;
  final int revision;

  factory ExpRealtyProgramConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return disabledDefault;
    return ExpRealtyProgramConfig(
      enabled: data['enabled'] == true,
      agentApplicationsEnabled:
          data['agentApplicationsEnabled'] as bool? ?? true,
      listingBrokerageAttributionEnabled:
          data['listingBrokerageAttributionEnabled'] as bool? ?? true,
      buyerAgentLeadRoutingEnabled:
          data['buyerAgentLeadRoutingEnabled'] as bool? ?? true,
      revision: ((data['revision'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30),
    );
  }
}

Stream<ExpRealtyProgramConfig> watchExpRealtyProgramConfig({
  FirebaseFirestore? firestore,
}) {
  final db = firestore ?? FirebaseFirestore.instance;
  return db
      .collection('platform_configuration')
      .doc('exp_realty_integration')
      .snapshots()
      .map((snap) => ExpRealtyProgramConfig.fromMap(snap.data()))
      .handleError((_) => ExpRealtyProgramConfig.disabledDefault);
}

/// Account Settings card allowing Realtors / eXp Realty Agents to apply for
/// license verification once the admin turns ON the eXp Realty program.
class ExpRealtyAccountApplicationCard extends StatefulWidget {
  const ExpRealtyAccountApplicationCard({super.key});

  @override
  State<ExpRealtyAccountApplicationCard> createState() =>
      _ExpRealtyAccountApplicationCardState();
}

class _ExpRealtyAccountApplicationCardState
    extends State<ExpRealtyAccountApplicationCard> {
  String _brokerageId = kDefaultExpBrokerageOptions.first.id;
  final _customBrokerage = TextEditingController();
  String _jurisdiction = kNorthAmericaRealtorJurisdictions.first;
  String _role = 'Commercial & Land Agent';
  final _licenseNumber = TextEditingController();
  final _boardOrMls = TextEditingController();
  final _phone = TextEditingController();
  bool _submitting = false;
  bool _seededFromDoc = false;

  @override
  void dispose() {
    _customBrokerage.dispose();
    _licenseNumber.dispose();
    _boardOrMls.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submitApplication(User user) async {
    final license = _licenseNumber.text.trim();
    if (license.isEmpty) {
      PipeFeedback.show(
        context,
        message: 'Enter your provincial or state real estate license number.',
        tone: PipeStatusTone.error,
      );
      return;
    }
    final selectedBrokerage = kDefaultExpBrokerageOptions.firstWhere(
      (b) => b.id == _brokerageId,
      orElse: () => kDefaultExpBrokerageOptions.first,
    );
    final brokerageName = _brokerageId == 'other-licensed-brokerage'
        ? (_customBrokerage.text.trim().isEmpty
            ? 'Licensed Brokerage'
            : _customBrokerage.text.trim())
        : selectedBrokerage.legalName;

    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance
          .collection('realtor_agent_applications')
          .doc(user.uid)
          .set({
        'ownerUid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'brokerageEntityId': _brokerageId,
        'brokerageName': brokerageName,
        'jurisdiction': _jurisdiction,
        'role': _role,
        'licenseNumber': license,
        'boardOrMls': _boardOrMls.text.trim(),
        'phone': _phone.text.trim(),
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message:
            'Realtor verification submitted! An administrator will review your license.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: 'Could not submit Realtor application: $error',
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<ExpRealtyProgramConfig>(
      stream: watchExpRealtyProgramConfig(),
      builder: (context, configSnap) {
        final config =
            configSnap.data ?? ExpRealtyProgramConfig.disabledDefault;
        if (!config.enabled || !config.agentApplicationsEnabled) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('verified_realtor_profiles')
              .doc(user.uid)
              .snapshots(),
          builder: (context, verifiedSnap) {
            final verifiedData = verifiedSnap.data?.data();
            final isVerifiedRealtor = verifiedData?['active'] == true;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('realtor_agent_applications')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, appSnap) {
                final appData = appSnap.data?.data();
                if (!_seededFromDoc && appData != null) {
                  _seededFromDoc = true;
                  final savedBrokerage =
                      '${appData['brokerageEntityId'] ?? ''}'.trim();
                  if (kDefaultExpBrokerageOptions
                      .any((b) => b.id == savedBrokerage)) {
                    _brokerageId = savedBrokerage;
                  }
                  _licenseNumber.text =
                      '${appData['licenseNumber'] ?? ''}'.trim();
                  _boardOrMls.text = '${appData['boardOrMls'] ?? ''}'.trim();
                  _phone.text = '${appData['phone'] ?? ''}'.trim();
                }

                final status = '${appData?['status'] ?? ''}'.trim();
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isVerifiedRealtor
                          ? Colors.green.shade400
                          : const Color(0xFF0878E8).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isVerifiedRealtor
                                  ? Icons.verified_rounded
                                  : Icons.real_estate_agent_outlined,
                              color: isVerifiedRealtor
                                  ? Colors.green.shade700
                                  : const Color(0xFF0878E8),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isVerifiedRealtor
                                    ? 'Verified Realtor / eXp Realty Profile Active'
                                    : 'eXp Realty & Licensed Realtor Program',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (isVerifiedRealtor)
                              Chip(
                                label: const Text('Verified Realtor'),
                                backgroundColor: Colors.green.shade50,
                              )
                            else if (status == 'pending')
                              Chip(
                                label: const Text('Pending Review'),
                                backgroundColor: Colors.amber.shade50,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (isVerifiedRealtor) ...[
                          Text(
                            'Brokerage: ${verifiedData?['brokerageName'] ?? 'eXp Realty'}\n'
                            'Jurisdiction: ${verifiedData?['jurisdiction'] ?? ''} • License #: ${verifiedData?['licenseNumber'] ?? ''}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ] else ...[
                          const Text(
                            'Connect your eXp Realty or licensed real estate brokerage credentials to display verified brokerage attribution on Land, Property & Business listings and receive buyer/seller representation leads.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: PipeBuyerColors.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _brokerageId,
                            decoration: const InputDecoration(
                              labelText: 'Brokerage entity',
                              border: OutlineInputBorder(),
                            ),
                            items: kDefaultExpBrokerageOptions
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item.id,
                                    child: Text(item.legalName),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _brokerageId = value);
                              }
                            },
                          ),
                          if (_brokerageId == 'other-licensed-brokerage') ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: _customBrokerage,
                              decoration: const InputDecoration(
                                labelText: 'Registered brokerage legal name *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _jurisdiction,
                            decoration: const InputDecoration(
                              labelText: 'Licensed province / state',
                              border: OutlineInputBorder(),
                            ),
                            items: kNorthAmericaRealtorJurisdictions
                                .map(
                                  (j) => DropdownMenuItem(
                                    value: j,
                                    child: Text(j),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _jurisdiction = value);
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _role,
                            decoration: const InputDecoration(
                              labelText: 'Agent role',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              'Commercial & Land Agent',
                              'Real Estate Agent / Realtor',
                              'Business Broker / Advisor',
                              'Supervising / Managing Broker',
                            ]
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) setState(() => _role = value);
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _licenseNumber,
                            decoration: const InputDecoration(
                              labelText: 'License / registration number *',
                              hintText: 'e.g. RECA / BCFSA / TREC license #',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _boardOrMls,
                                  decoration: const InputDecoration(
                                    labelText: 'Board / MLS® ID (optional)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Direct agent phone',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _submitting
                                ? null
                                : () => _submitApplication(user),
                            icon: const Icon(Icons.verified_user_outlined),
                            label: Text(
                              _submitting
                                  ? 'Submitting...'
                                  : (status == 'pending'
                                      ? 'Update Pending Realtor Application'
                                      : 'Apply for Verified eXp / Realtor Access'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Optional Step 2 section inside Create Listing for `Site & Property`, active
/// ONLY when `exp_realty_integration.enabled` is turned ON in Admin Settings.
class ExpRealtyListingRepresentationSection extends StatelessWidget {
  const ExpRealtyListingRepresentationSection({
    super.key,
    required this.representation,
    required this.brokerageEntityId,
    required this.brokerageNameController,
    required this.agentLicenseController,
    required this.agentJurisdiction,
    required this.mlsNumberController,
    required this.onRepresentationChanged,
    required this.onBrokerageEntityChanged,
    required this.onJurisdictionChanged,
  });

  final String representation;
  final String brokerageEntityId;
  final TextEditingController brokerageNameController;
  final TextEditingController agentLicenseController;
  final String agentJurisdiction;
  final TextEditingController mlsNumberController;
  final ValueChanged<String> onRepresentationChanged;
  final ValueChanged<String> onBrokerageEntityChanged;
  final ValueChanged<String> onJurisdictionChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ExpRealtyProgramConfig>(
      stream: watchExpRealtyProgramConfig(),
      builder: (context, snap) {
        final config = snap.data ?? ExpRealtyProgramConfig.disabledDefault;
        if (!config.enabled || !config.listingBrokerageAttributionEnabled) {
          return const SizedBox.shrink();
        }
        final isBrokered = representation == 'Licensed Realtor / Brokerage';
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD0DFEE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.real_estate_agent_outlined,
                    size: 20,
                    color: Color(0xFF0878E8),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Listing Representation & eXp Realty Brokerage',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Select whether this property or business is offered directly by the owner or represented by an eXp Realty / licensed real estate agent.',
                style: TextStyle(fontSize: 12, color: PipeBuyerColors.muted),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: representation,
                decoration: const InputDecoration(
                  labelText: 'Listed by',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Owner / Principal',
                    child: Text('Direct Owner / Principal (For Sale by Owner)'),
                  ),
                  DropdownMenuItem(
                    value: 'Licensed Realtor / Brokerage',
                    child: Text('Licensed Realtor / eXp Realty Brokerage'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) onRepresentationChanged(val);
                },
              ),
              if (isBrokered) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: brokerageEntityId,
                  decoration: const InputDecoration(
                    labelText: 'Representing brokerage',
                    border: OutlineInputBorder(),
                  ),
                  items: kDefaultExpBrokerageOptions
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.legalName),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (val) {
                    if (val != null) {
                      onBrokerageEntityChanged(val);
                      if (val != 'other-licensed-brokerage') {
                        final match = kDefaultExpBrokerageOptions
                            .firstWhere((e) => e.id == val);
                        brokerageNameController.text = match.legalName;
                      } else {
                        brokerageNameController.clear();
                      }
                    }
                  },
                ),
                if (brokerageEntityId == 'other-licensed-brokerage') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: brokerageNameController,
                    decoration: const InputDecoration(
                      labelText: 'Brokerage legal name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: agentJurisdiction,
                  decoration: const InputDecoration(
                    labelText: 'Province / state jurisdiction',
                    border: OutlineInputBorder(),
                  ),
                  items: kNorthAmericaRealtorJurisdictions
                      .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                      .toList(growable: false),
                  onChanged: (val) {
                    if (val != null) onJurisdictionChanged(val);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: agentLicenseController,
                        decoration: const InputDecoration(
                          labelText: 'Agent license #',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: mlsNumberController,
                        decoration: const InputDecoration(
                          labelText: 'MLS® / listing ID (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Shown on `Site & Property` listing detail pages ONLY when the eXp Realty
/// integration is enabled in Admin Settings.
class ExpRealtyLeadInquiryCard extends StatefulWidget {
  const ExpRealtyLeadInquiryCard({
    super.key,
    required this.listingId,
    required this.listingTitle,
    required this.locationLabel,
    required this.sellerUid,
  });

  final String listingId;
  final String listingTitle;
  final String locationLabel;
  final String sellerUid;

  @override
  State<ExpRealtyLeadInquiryCard> createState() =>
      _ExpRealtyLeadInquiryCardState();
}

class _ExpRealtyLeadInquiryCardState extends State<ExpRealtyLeadInquiryCard> {
  bool _busy = false;

  Future<void> _openInquiryDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      PipeFeedback.show(
        context,
        message:
            'Sign in first to request an eXp Realty commercial/land agent.',
        tone: PipeStatusTone.warning,
      );
      return;
    }

    final phoneController = TextEditingController(text: user.phoneNumber ?? '');
    final notesController = TextEditingController();
    String inquiryRole = 'Buyer seeking agent representation';

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setModalState) => AlertDialog(
              title: const Text('Connect with an eXp Realty Agent'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Property: ${widget.listingTitle}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: inquiryRole,
                      decoration: const InputDecoration(
                        labelText: 'How can an agent help?',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        'Buyer seeking agent representation',
                        'Property/Business owner seeking listing agent',
                        'Valuation, title, or due-diligence inquiry',
                      ]
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(growable: false),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => inquiryRole = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Best callback phone number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Questions, timeline, or financing notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Send to eXp Realty Desk'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    final phone = phoneController.text.trim();
    final notes = notesController.text.trim();
    phoneController.dispose();
    notesController.dispose();
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('exp_realty_leads').add({
        'requesterUid': user.uid,
        'requesterEmail': user.email ?? '',
        'requesterName': user.displayName ?? '',
        'requesterPhone': phone,
        'inquiryType': inquiryRole,
        'notes': notes,
        'listingId': widget.listingId,
        'listingTitle': widget.listingTitle,
        'locationLabel': widget.locationLabel,
        'sellerUid': widget.sellerUid,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: 'Your eXp Realty agent inquiry has been submitted!',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: 'Could not submit inquiry: $error',
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ExpRealtyProgramConfig>(
      stream: watchExpRealtyProgramConfig(),
      builder: (context, snap) {
        final config = snap.data ?? ExpRealtyProgramConfig.disabledDefault;
        if (!config.enabled || !config.buyerAgentLeadRoutingEnabled) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F8FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF0878E8).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.real_estate_agent_rounded,
                color: Color(0xFF0878E8),
                size: 26,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need Licensed Commercial, Land or Business Representation?',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Connect with a verified eXp Realty Land & Commercial agent for offers, valuation, and closing support.',
                      style: TextStyle(
                        fontSize: 12,
                        color: PipeBuyerColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _openInquiryDialog,
                icon: const Icon(Icons.handshake_outlined, size: 18),
                label: Text(_busy ? 'Sending...' : 'Request Agent'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Mandatory CREA DDF® / REALTOR.ca display attribution & deep-link notice
/// rendered automatically when a Site & Property listing originates from CREA
/// DDF® or displays a Canadian MLS® number while eXp Realty is enabled.
class CreaDdfComplianceAttributionNotice extends StatelessWidget {
  const CreaDdfComplianceAttributionNotice({
    super.key,
    required this.details,
  });

  final Map<String, dynamic> details;

  @override
  Widget build(BuildContext context) {
    final ddfSynced = details['ddfSynced'] == true;
    final realtorCaUrl = '${details['realtorCaUrl'] ?? ''}'.trim();
    final mlsNumber = '${details['mlsNumber'] ?? ''}'.trim();
    if (!ddfSynced && realtorCaUrl.isEmpty && mlsNumber.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<ExpRealtyProgramConfig>(
      stream: watchExpRealtyProgramConfig(),
      builder: (context, snap) {
        final config = snap.data ?? ExpRealtyProgramConfig.disabledDefault;
        if (!config.enabled && !ddfSynced) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD8E0E9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    size: 16,
                    color: Color(0xFF0878E8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ddfSynced || realtorCaUrl.isNotEmpty
                          ? 'Powered by REALTOR.ca${mlsNumber.isNotEmpty ? " • MLS® #$mlsNumber" : ""}'
                          : 'MLS® Attribution • #$mlsNumber',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  if (realtorCaUrl.startsWith('https://'))
                    TextButton.icon(
                      onPressed: () {
                        final uri = Uri.tryParse(realtorCaUrl);
                        if (uri != null) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 15),
                      label: const Text('View on REALTOR.ca'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'MLS®, Multiple Listing Service® and the associated logos are owned by The Canadian Real Estate Association (CREA) and identify the quality of services provided by real estate professionals who are members of CREA. REALTOR®, REALTORS®, and the REALTOR® logo are controlled by CREA and identify real estate professionals who are members of CREA.',
                style: TextStyle(fontSize: 10.5, color: PipeBuyerColors.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Admin Settings panel for controlling the eXp Realty & Licensed Realtor
/// Program (off by default; toggleable ON anytime by the administrator).
class ExpRealtyAdminControlPanel extends StatefulWidget {
  const ExpRealtyAdminControlPanel({super.key});

  @override
  State<ExpRealtyAdminControlPanel> createState() =>
      _ExpRealtyAdminControlPanelState();
}

class _ExpRealtyAdminControlPanelState
    extends State<ExpRealtyAdminControlPanel> {
  final MarketplaceCommandClient _commandClient = MarketplaceCommandClient();
  final TextEditingController _boldTrailTokenCtrl = TextEditingController();
  final TextEditingController _loftyKeyCtrl = TextEditingController();
  final TextEditingController _webhookUrlCtrl = TextEditingController();
  final TextEditingController _webhookSecretCtrl = TextEditingController();
  final TextEditingController _creaClientIdCtrl = TextEditingController();
  final TextEditingController _creaClientSecretCtrl = TextEditingController();
  final TextEditingController _creaFilterCtrl = TextEditingController();
  final TextEditingController _lookupLicenseCtrl = TextEditingController();
  final TextEditingController _lookupAgentNameCtrl = TextEditingController();

  bool _saving = false;
  bool _loadingIntegrations = true;
  bool _busyIntegrationAction = false;

  bool _boldTrailEnabled = false;
  bool _boldTrailConfigured = false;
  bool _loftyEnabled = false;
  bool _loftyConfigured = false;
  bool _webhookEnabled = false;
  bool _webhookConfigured = false;
  bool _webhookSigningConfigured = false;
  bool _creaDdfAutoSyncEnabled = false;
  bool _creaDdfConfigured = false;
  String? _lastDdfSyncAt;
  String _lookupJurisdiction = 'US-TX (Texas)';
  Map<String, dynamic>? _lastLicenseCheckResult;

  @override
  void initState() {
    super.initState();
    _loadIntegrationStatus();
  }

  @override
  void dispose() {
    _boldTrailTokenCtrl.dispose();
    _loftyKeyCtrl.dispose();
    _webhookUrlCtrl.dispose();
    _webhookSecretCtrl.dispose();
    _creaClientIdCtrl.dispose();
    _creaClientSecretCtrl.dispose();
    _creaFilterCtrl.dispose();
    _lookupLicenseCtrl.dispose();
    _lookupAgentNameCtrl.dispose();
    super.dispose();
  }

  void _applyStatusPayload(Map<String, dynamic> status) {
    _boldTrailEnabled = status['boldTrailEnabled'] == true;
    _boldTrailConfigured = status['boldTrailConfigured'] == true;
    _loftyEnabled = status['loftyEnabled'] == true;
    _loftyConfigured = status['loftyConfigured'] == true;
    _webhookEnabled = status['webhookEnabled'] == true;
    _webhookConfigured = status['webhookConfigured'] == true;
    _webhookSigningConfigured = status['webhookSigningConfigured'] == true;
    _creaDdfAutoSyncEnabled = status['creaDdfAutoSyncEnabled'] == true;
    _creaDdfConfigured = status['creaDdfConfigured'] == true;
    _lastDdfSyncAt = status['lastDdfSyncAt'] as String?;
    final webhookUrl = '${status['webhookUrl'] ?? ''}'.trim();
    if (webhookUrl.isNotEmpty && _webhookUrlCtrl.text.trim().isEmpty) {
      _webhookUrlCtrl.text = webhookUrl;
    }
    final odataFilter = '${status['creaDdfOdataFilter'] ?? ''}'.trim();
    if (odataFilter.isNotEmpty && _creaFilterCtrl.text.trim().isEmpty) {
      _creaFilterCtrl.text = odataFilter;
    }
  }

  Future<void> _loadIntegrationStatus() async {
    try {
      final status = await _commandClient.execute(
        'manageExpRealtyIntegrations',
        const {'action': 'getStatus'},
      );
      if (!mounted) return;
      setState(() {
        _applyStatusPayload(status);
        _loadingIntegrations = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingIntegrations = false);
      }
    }
  }

  Future<void> _saveExternalIntegrations({String? successMessage}) async {
    setState(() => _busyIntegrationAction = true);
    try {
      final status = await _commandClient.execute(
        'manageExpRealtyIntegrations',
        {
          'action': 'saveCredentials',
          'boldTrailEnabled': _boldTrailEnabled,
          'boldTrailApiToken': _boldTrailTokenCtrl.text.trim(),
          'loftyEnabled': _loftyEnabled,
          'loftyApiKey': _loftyKeyCtrl.text.trim(),
          'webhookEnabled': _webhookEnabled,
          'webhookUrl': _webhookUrlCtrl.text.trim(),
          'webhookSigningSecret': _webhookSecretCtrl.text.trim(),
          'creaDdfAutoSyncEnabled': _creaDdfAutoSyncEnabled,
          'creaDdfClientId': _creaClientIdCtrl.text.trim(),
          'creaDdfClientSecret': _creaClientSecretCtrl.text.trim(),
          'creaDdfOdataFilter': _creaFilterCtrl.text.trim(),
        },
      );
      _boldTrailTokenCtrl.clear();
      _loftyKeyCtrl.clear();
      _webhookSecretCtrl.clear();
      _creaClientIdCtrl.clear();
      _creaClientSecretCtrl.clear();
      if (!mounted) return;
      setState(() => _applyStatusPayload(status));
      PipeFeedback.show(
        context,
        message:
            successMessage ?? 'External Realtor CRM & DDF® settings saved.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(error),
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) setState(() => _busyIntegrationAction = false);
    }
  }

  Future<void> _sendTestCrmLead() async {
    setState(() => _busyIntegrationAction = true);
    try {
      await _saveExternalIntegrations(
        successMessage: 'Saved CRM configuration — sending test lead...',
      );
      final result = await _commandClient.execute(
        'manageExpRealtyIntegrations',
        const {'action': 'testCrmLead'},
      );
      if (!mounted) return;
      final attempted = result['attempted'] ?? 0;
      final succeeded = result['succeeded'] ?? 0;
      final status = '${result['status'] ?? ''}';
      PipeFeedback.show(
        context,
        message: status == 'no_crm_configured'
            ? 'Enable BoldTrail, Lofty, or an HTTPS Webhook and add a token first.'
            : 'CRM test complete: $succeeded/$attempted connector(s) delivered (${result['status']}).',
        tone: status == 'synced'
            ? PipeStatusTone.success
            : PipeStatusTone.warning,
      );
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(error),
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) setState(() => _busyIntegrationAction = false);
    }
  }

  Future<void> _runCreaDdfAction({required bool dryRun}) async {
    setState(() => _busyIntegrationAction = true);
    try {
      if (_creaClientIdCtrl.text.trim().isNotEmpty ||
          _creaClientSecretCtrl.text.trim().isNotEmpty) {
        await _saveExternalIntegrations();
      }
      final result = await _commandClient.execute(
        'manageExpRealtyIntegrations',
        {'action': dryRun ? 'testCreaDdf' : 'syncCreaDdf'},
        timeout: const Duration(seconds: 60),
      );
      if (!mounted) return;
      if (dryRun) {
        PipeFeedback.show(
          context,
          message:
              'CREA DDF® OAuth2 verified! ${result['totalAvailableInFeed'] ?? 0} feed properties available (${result['mappableCount'] ?? 0} previewed).',
          tone: PipeStatusTone.success,
        );
      } else {
        setState(() {
          _lastDdfSyncAt = '${result['syncedAt'] ?? ''}';
        });
        PipeFeedback.show(
          context,
          message:
              'CREA DDF® sync complete: ${result['upsertedCount'] ?? 0} synced, ${result['archivedCount'] ?? 0} stale listings archived.',
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(error),
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) setState(() => _busyIntegrationAction = false);
    }
  }

  Future<void> _verifyLicenseRegistry({
    required String jurisdiction,
    required String licenseNumber,
    String agentName = '',
    String? applicantUid,
  }) async {
    if (licenseNumber.trim().isEmpty) {
      PipeFeedback.show(
        context,
        message: 'Enter a license number first.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    setState(() => _busyIntegrationAction = true);
    try {
      final result = await _commandClient.execute(
        'manageExpRealtyIntegrations',
        {
          'action': 'verifyLicense',
          'jurisdiction': jurisdiction,
          'licenseNumber': licenseNumber.trim(),
          'agentName': agentName.trim(),
          if (applicantUid != null) 'applicantUid': applicantUid,
        },
      );
      if (!mounted) return;
      setState(() => _lastLicenseCheckResult = result);
      final liveGov = result['liveGovApi'] == true;
      final matched = result['matched'] == true;
      PipeFeedback.show(
        context,
        message: liveGov
            ? (matched
                ? 'Gov API Verified (${result['status']}): ${result['holderName']} • ${result['sponsoringBrokerage'] ?? ''}'
                : 'Gov API checked: ${result['status']}')
            : 'Official portal ready: ${result['regulatorName']}',
        tone: (!liveGov || matched)
            ? PipeStatusTone.success
            : PipeStatusTone.warning,
      );
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(error),
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) setState(() => _busyIntegrationAction = false);
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _updateConfig({
    required ExpRealtyProgramConfig current,
    bool? enabled,
    bool? agentApplicationsEnabled,
    bool? listingBrokerageAttributionEnabled,
    bool? buyerAgentLeadRoutingEnabled,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('platform_configuration')
          .doc('exp_realty_integration')
          .set({
        'enabled': enabled ?? current.enabled,
        'agentApplicationsEnabled':
            agentApplicationsEnabled ?? current.agentApplicationsEnabled,
        'listingBrokerageAttributionEnabled':
            listingBrokerageAttributionEnabled ??
                current.listingBrokerageAttributionEnabled,
        'buyerAgentLeadRoutingEnabled': buyerAgentLeadRoutingEnabled ??
            current.buyerAgentLeadRoutingEnabled,
        'revision': current.revision + 1,
        'updatedByUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: 'eXp Realty integration settings saved.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: 'Failed to update eXp Realty settings: $error',
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _decideRealtorApplication(
    String applicantUid,
    Map<String, dynamic> data,
    bool approve,
  ) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final batch = FirebaseFirestore.instance.batch();
    final appRef = FirebaseFirestore.instance
        .collection('realtor_agent_applications')
        .doc(applicantUid);
    final profileRef = FirebaseFirestore.instance
        .collection('verified_realtor_profiles')
        .doc(applicantUid);

    batch.set(
      appRef,
      {
        'status': approve ? 'approved' : 'rejected',
        'reviewedByUid': adminUid,
        'reviewedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      profileRef,
      {
        'ownerUid': applicantUid,
        'active': approve,
        'brokerageEntityId': data['brokerageEntityId'] ?? 'exp-realty-canada',
        'brokerageName': data['brokerageName'] ?? 'eXp Realty',
        'jurisdiction': data['jurisdiction'] ?? '',
        'role': data['role'] ?? 'Real Estate Agent',
        'licenseNumber': data['licenseNumber'] ?? '',
        'boardOrMls': data['boardOrMls'] ?? '',
        'verifiedByUid': adminUid,
        'verifiedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    if (!mounted) return;
    PipeFeedback.show(
      context,
      message: approve
          ? 'Realtor verified and badge activated!'
          : 'Realtor verification revoked.',
      tone: PipeStatusTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ExpRealtyProgramConfig>(
      stream: watchExpRealtyProgramConfig(),
      builder: (context, snap) {
        final config = snap.data ?? ExpRealtyProgramConfig.disabledDefault;
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: config.enabled
                  ? Colors.green.shade400
                  : Colors.blueGrey.shade200,
              width: 1.4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.real_estate_agent_rounded,
                      color: config.enabled
                          ? Colors.green.shade700
                          : const Color(0xFF0878E8),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'eXp Realty & Licensed Realtor Integration',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Pre-built for eXp Realty of Canada, Inc., eXp Realty, LLC (US), and Grupo eXp Realtors Mexico. Keep OFF until ready to launch.',
                            style: TextStyle(
                              fontSize: 12,
                              color: PipeBuyerColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(config.enabled ? 'LIVE' : 'STANDBY (OFF)'),
                      backgroundColor: config.enabled
                          ? Colors.green.shade50
                          : Colors.grey.shade200,
                    ),
                  ],
                ),
                const Divider(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: config.enabled,
                  onChanged: _saving
                      ? null
                      : (val) => _updateConfig(current: config, enabled: val),
                  title: const Text(
                    'Enable eXp Realty Agent & Brokerage Program (Master Switch)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Turns on Realtor onboarding, brokerage/MLS attribution on Site & Property listings, and buyer/seller agent lead routing across the app.',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: config.agentApplicationsEnabled,
                  onChanged: _saving
                      ? null
                      : (val) => _updateConfig(
                            current: config,
                            agentApplicationsEnabled: val,
                          ),
                  title:
                      const Text('Realtor License Verification Applications'),
                  subtitle: const Text(
                    'Allow Realtors to submit provincial/state license credentials in Account Settings.',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: config.listingBrokerageAttributionEnabled,
                  onChanged: _saving
                      ? null
                      : (val) => _updateConfig(
                            current: config,
                            listingBrokerageAttributionEnabled: val,
                          ),
                  title: const Text(
                    'Brokerage & MLS® Attribution on Site & Property Listings',
                  ),
                  subtitle: const Text(
                    'Show eXp Realty brokerage entity, license #, and MLS® fields on property listings.',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: config.buyerAgentLeadRoutingEnabled,
                  onChanged: _saving
                      ? null
                      : (val) => _updateConfig(
                            current: config,
                            buyerAgentLeadRoutingEnabled: val,
                          ),
                  title: const Text(
                    'Buyer & Seller "Connect with an eXp Realty Agent" Lead Desk',
                  ),
                  subtitle: const Text(
                    'Allow property buyers and sellers to request representation from a verified eXp agent.',
                  ),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(
                      Icons.hub_outlined,
                      size: 18,
                      color: Color(0xFF0878E8),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Free External CRM, CREA DDF® & Government Registry APIs',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (_loadingIntegrations)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pre-wired \$0 integrations. API tokens are vaulted server-side (never exposed to browsers) and activate automatically when configured.',
                  style: TextStyle(fontSize: 12, color: PipeBuyerColors.muted),
                ),
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  leading: const Icon(
                    Icons.sync_alt_rounded,
                    color: Color(0xFF0878E8),
                  ),
                  title: const Text(
                    '1. eXp Realty CRM Auto-Lead Sync (BoldTrail / Lofty / Webhook)',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    [
                      if (_boldTrailConfigured) 'BoldTrail Ready',
                      if (_loftyConfigured) 'Lofty Ready',
                      if (_webhookConfigured) 'Webhook Ready',
                    ].isEmpty
                        ? 'Standby — paste your free BoldTrail, Lofty, or Zapier webhook token anytime'
                        : [
                            if (_boldTrailConfigured) 'BoldTrail Ready ✓',
                            if (_loftyConfigured) 'Lofty Ready ✓',
                            if (_webhookConfigured) 'Webhook Ready ✓',
                          ].join(' • '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _boldTrailEnabled,
                      onChanged: _busyIntegrationAction
                          ? null
                          : (val) => setState(() => _boldTrailEnabled = val),
                      title: Text(
                        'BoldTrail / kvCORE Public API v2 ${_boldTrailConfigured ? "(Token Vaulted ✓)" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Pushes new property leads straight to https://api.kvcore.com/v2/public/contact',
                      ),
                    ),
                    TextField(
                      controller: _boldTrailTokenCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: _boldTrailConfigured
                            ? 'Replace BoldTrail / kvCORE Bearer Token (leave blank to keep)'
                            : 'BoldTrail / kvCORE Bearer API Token',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _loftyEnabled,
                      onChanged: _busyIntegrationAction
                          ? null
                          : (val) => setState(() => _loftyEnabled = val),
                      title: Text(
                        'Lofty (formerly Chime) Open API v1 ${_loftyConfigured ? "(Key Vaulted ✓)" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Pushes new property leads straight to https://api.lofty.com/v1.0/leads',
                      ),
                    ),
                    TextField(
                      controller: _loftyKeyCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: _loftyConfigured
                            ? 'Replace Lofty Bearer API Key (leave blank to keep)'
                            : 'Lofty Bearer API Key',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _webhookEnabled,
                      onChanged: _busyIntegrationAction
                          ? null
                          : (val) => setState(() => _webhookEnabled = val),
                      title: Text(
                        'Universal HTTPS Lead Webhook (Zapier / Make / Rechat) ${_webhookConfigured ? "(Ready ✓)" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Delivers JSON + optional X-PipeBuyer-Signature HMAC-SHA256 header',
                      ),
                    ),
                    TextField(
                      controller: _webhookUrlCtrl,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'HTTPS Webhook URL (https://...)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _webhookSecretCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: _webhookSigningConfigured
                            ? 'Replace HMAC Signing Secret (leave blank to keep)'
                            : 'Optional Webhook HMAC Signing Secret',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _busyIntegrationAction
                              ? null
                              : () => _saveExternalIntegrations(),
                          icon: const Icon(Icons.lock_outline, size: 18),
                          label: const Text('Save CRM Credentials'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _busyIntegrationAction ? null : _sendTestCrmLead,
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: const Text('Send Test CRM Lead'),
                        ),
                      ],
                    ),
                  ],
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  leading: const Icon(
                    Icons.cloud_sync_outlined,
                    color: Colors.teal,
                  ),
                  title: const Text(
                    '2. Canadian REALTOR.ca CREA DDF® OData v4 Auto-Sync',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    _creaDdfConfigured
                        ? 'Credentials vaulted ✓${_lastDdfSyncAt != null ? " • Last sync: $_lastDdfSyncAt" : ""}'
                        : 'Free for CREA REALTORS® (RealtorLink → DDF® Dashboard Client ID & Secret)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _creaDdfAutoSyncEnabled,
                      onChanged: _busyIntegrationAction
                          ? null
                          : (val) =>
                              setState(() => _creaDdfAutoSyncEnabled = val),
                      title: const Text(
                        'Enable Automatic 24-Hour CREA DDF® Refresh & Expired Purge',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Syncs active commercial/land/business listings from ddfapi.realtor.ca and archives sold/expired listings every 24h per CREA rules.',
                      ),
                    ),
                    TextField(
                      controller: _creaClientIdCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: _creaDdfConfigured
                            ? 'Replace CREA DDF® Client ID (leave blank to keep)'
                            : 'CREA DDF® OAuth2 Client ID',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _creaClientSecretCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: _creaDdfConfigured
                            ? 'Replace CREA DDF® Client Secret (leave blank to keep)'
                            : 'CREA DDF® OAuth2 Client Secret',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _creaFilterCtrl,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText:
                            'Optional OData \$filter (e.g. StateOrProvince eq \'Alberta\')',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _busyIntegrationAction
                              ? null
                              : () => _saveExternalIntegrations(
                                    successMessage:
                                        'CREA DDF® settings vaulted.',
                                  ),
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('Save DDF® Settings'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busyIntegrationAction
                              ? null
                              : () => _runCreaDdfAction(dryRun: true),
                          icon: const Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                          ),
                          label: const Text('Test CREA OAuth2'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _busyIntegrationAction
                              ? null
                              : () => _runCreaDdfAction(dryRun: false),
                          icon: const Icon(Icons.sync_rounded, size: 18),
                          label: const Text('Sync DDF® Listings Now'),
                        ),
                      ],
                    ),
                  ],
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  leading: const Icon(
                    Icons.policy_outlined,
                    color: Colors.deepPurple,
                  ),
                  title: const Text(
                    '3. Live Government License API & Regulator Portal Lookup',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  subtitle: const Text(
                    'Live \$0 Gov REST APIs active now for Texas (TREC) & Colorado (DORA) + 1-click portals for RECA, BCFSA, SREC, RECO & 23 jurisdictions',
                    style: TextStyle(fontSize: 12),
                  ),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _lookupJurisdiction,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Province / State Jurisdiction',
                        border: OutlineInputBorder(),
                      ),
                      items: kNorthAmericaRealtorJurisdictions
                          .map(
                            (j) => DropdownMenuItem<String>(
                              value: j,
                              child: Text(j, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _lookupJurisdiction = val);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _lookupLicenseCtrl,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'License # (e.g. 679418-B)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _lookupAgentNameCtrl,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Agent Name (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _busyIntegrationAction
                              ? null
                              : () => _verifyLicenseRegistry(
                                    jurisdiction: _lookupJurisdiction,
                                    licenseNumber: _lookupLicenseCtrl.text,
                                    agentName: _lookupAgentNameCtrl.text,
                                  ),
                          icon: const Icon(Icons.fact_check_outlined, size: 18),
                          label: const Text('Run Live Registry Check'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openExternalUrl(
                            officialRegulatorPortalUrl(_lookupJurisdiction),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open Official Regulator Portal'),
                        ),
                      ],
                    ),
                    if (_lastLicenseCheckResult != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7FC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD0DFEE)),
                        ),
                        child: Text(
                          'Result (${_lastLicenseCheckResult!['apiProvider'] ?? ''}): '
                          'Status: ${_lastLicenseCheckResult!['status'] ?? ''} '
                          '${(_lastLicenseCheckResult!['holderName'] ?? '').toString().isNotEmpty ? "• Holder: ${_lastLicenseCheckResult!['holderName']} " : ""}'
                          '${(_lastLicenseCheckResult!['sponsoringBrokerage'] ?? '').toString().isNotEmpty ? "• Brokerage: ${_lastLicenseCheckResult!['sponsoringBrokerage']} " : ""}'
                          '${(_lastLicenseCheckResult!['expirationDate'] ?? '').toString().isNotEmpty ? "• Expires: ${_lastLicenseCheckResult!['expirationDate']}" : ""}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Realtor License Verification Queue',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('realtor_agent_applications')
                      .limit(25)
                      .snapshots(),
                  builder: (context, appSnap) {
                    final docs = appSnap.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return const Text(
                        'No Realtor license applications submitted yet.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: PipeBuyerColors.muted,
                        ),
                      );
                    }
                    return Column(
                      children: docs.map((doc) {
                        final d = doc.data();
                        final status = '${d['status'] ?? 'pending'}';
                        final jurisdiction = '${d['jurisdiction'] ?? ''}';
                        final licenseNumber = '${d['licenseNumber'] ?? ''}';
                        final regVerify = d['registryVerification'] is Map
                            ? Map<String, dynamic>.from(
                                d['registryVerification'] as Map,
                              )
                            : null;
                        final portalUrl =
                            '${d['registryLookupUrl'] ?? ''}'.trim().isNotEmpty
                                ? '${d['registryLookupUrl']}'
                                : officialRegulatorPortalUrl(jurisdiction);
                        final regSummary = regVerify != null
                            ? '\nRegistry Check: ${regVerify['status'] ?? ''}'
                                '${(regVerify['holderName'] ?? '').toString().isNotEmpty ? " (${regVerify['holderName']})" : ""}'
                            : '';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            status == 'approved'
                                ? Icons.verified_rounded
                                : Icons.pending_actions_outlined,
                            color: status == 'approved'
                                ? Colors.green
                                : Colors.orange,
                          ),
                          title: Text(
                            '${d['displayName'] ?? d['email'] ?? doc.id} — ${d['brokerageName'] ?? 'eXp Realty'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            'Jurisdiction: $jurisdiction • License: $licenseNumber • Status: $status$regSummary',
                          ),
                          trailing: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              IconButton(
                                tooltip: 'Open Official Regulator Registry',
                                onPressed: () => _openExternalUrl(portalUrl),
                                icon: const Icon(Icons.open_in_new, size: 18),
                              ),
                              IconButton(
                                tooltip: 'Run Live Registry Check',
                                onPressed: _busyIntegrationAction
                                    ? null
                                    : () => _verifyLicenseRegistry(
                                          jurisdiction: jurisdiction,
                                          licenseNumber: licenseNumber,
                                          agentName:
                                              '${d['agentName'] ?? d['displayName'] ?? ''}',
                                          applicantUid: doc.id,
                                        ),
                                icon: const Icon(
                                  Icons.fact_check_outlined,
                                  size: 18,
                                ),
                              ),
                              if (status != 'approved')
                                FilledButton.tonal(
                                  onPressed: () => _decideRealtorApplication(
                                    doc.id,
                                    d,
                                    true,
                                  ),
                                  child: const Text('Verify'),
                                ),
                              if (status == 'approved')
                                OutlinedButton(
                                  onPressed: () => _decideRealtorApplication(
                                    doc.id,
                                    d,
                                    false,
                                  ),
                                  child: const Text('Revoke'),
                                ),
                            ],
                          ),
                        );
                      }).toList(growable: false),
                    );
                  },
                ),
                const Divider(height: 24),
                const Text(
                  'eXp Realty Buyer & Seller Representation Leads',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('exp_realty_leads')
                      .limit(20)
                      .snapshots(),
                  builder: (context, leadSnap) {
                    final leads = leadSnap.data?.docs ?? const [];
                    if (leads.isEmpty) {
                      return const Text(
                        'No representation leads submitted yet.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: PipeBuyerColors.muted,
                        ),
                      );
                    }
                    return Column(
                      children: leads.map((leadDoc) {
                        final l = leadDoc.data();
                        final status = '${l['status'] ?? 'open'}';
                        final crmSync = '${l['crmSyncStatus'] ?? ''}'.trim();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.contact_mail_outlined),
                          title: Text(
                            '${l['listingTitle'] ?? 'Property Inquiry'} (${l['inquiryType'] ?? ''})',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            'From: ${l['requesterEmail'] ?? ''} • Phone: ${l['requesterPhone'] ?? 'N/A'} • Status: $status'
                            '${crmSync.isNotEmpty ? " • CRM: $crmSync" : ""}\n${l['notes'] ?? ''}',
                          ),
                          trailing: status == 'open'
                              ? TextButton(
                                  onPressed: () => leadDoc.reference.update({
                                    'status': 'assigned',
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }),
                                  child: const Text('Mark Assigned'),
                                )
                              : const Chip(label: Text('Assigned')),
                        );
                      }).toList(growable: false),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
