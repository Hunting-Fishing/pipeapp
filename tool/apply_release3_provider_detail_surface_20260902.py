from pathlib import Path
from textwrap import dedent

ROOT = Path('.')
PAGE = ROOT / 'lib/marketplace/marketplace_public_profile_page.dart'
DETAIL = ROOT / 'lib/marketplace/marketplace_dispatch_public_detail.dart'
TEST = ROOT / 'test/marketplace_dispatch_public_detail_test.dart'
DOC = ROOT / 'docs/DISPATCH_RELEASE3_PROVIDER_DETAIL_SURFACE.md'


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one anchor, found {count}')
    return source.replace(old, new, 1)


page = PAGE.read_text(encoding='utf-8')
page = replace_once(
    page,
    "import 'marketplace_data_state.dart';\n",
    "import 'marketplace_data_state.dart';\nimport 'marketplace_dispatch_public_detail.dart';\n",
    'Dispatch public detail import',
)

old_return = dedent("""
    return _PublicProfileData(
        business: business,
        personal: personal,
        listings: _listings,
        tags: tags);
  }

  Future<void> _loadMoreListings() async {
""").lstrip()
new_return = dedent("""
    final dispatchDirectory = await _loadDispatchDirectoryDetail();
    return _PublicProfileData(
      business: business,
      personal: personal,
      listings: _listings,
      tags: tags,
      dispatchDirectory: dispatchDirectory,
    );
  }

  Future<Map<String, dynamic>> _loadDispatchDirectoryDetail() async {
    if (FirebaseAuth.instance.currentUser == null ||
        widget.userUid.trim().isEmpty) {
      return const <String, dynamic>{};
    }
    try {
      final document = await FirebaseFirestore.instance
          .collection('dispatch_directory_entries')
          .doc(widget.userUid)
          .get();
      return document.data() ?? const <String, dynamic>{};
    } catch (_) {
      // Dispatch Directory reads require a signed-in user and the Dispatch
      // feature flag. The public storefront must still work when that optional
      // projection is unavailable or access is intentionally held closed.
      return const <String, dynamic>{};
    }
  }

  Future<void> _loadMoreListings() async {
""").lstrip()
page = replace_once(page, old_return, new_return, 'Optional Dispatch detail loader')

page = replace_once(
    page,
    "            final loadedListings = _listings.length;\n",
    "            final loadedListings = _listings.length;\n"
    "            final dispatchDetail = DispatchPublicDetail.fromDirectoryProjection(\n"
    "              data.dispatchDirectory,\n"
    "            );\n",
    'Dispatch detail model creation',
)

metric_anchor = dedent("""
                        PipeBuyerMetricCard(
                          label: 'Account type',
                          value: isBusiness ? 'Business' : 'Personal',
                          icon: isBusiness
                              ? Icons.business_outlined
                              : Icons.person_outline,
                          caption: 'Public marketplace identity',
                          tone: PipeBuyerStatusTone.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
""").lstrip()
metric_replacement = dedent("""
                        PipeBuyerMetricCard(
                          label: 'Account type',
                          value: isBusiness ? 'Business' : 'Personal',
                          icon: isBusiness
                              ? Icons.business_outlined
                              : Icons.person_outline,
                          caption: 'Public marketplace identity',
                          tone: PipeBuyerStatusTone.success,
                        ),
                      ],
                    ),
                    if (dispatchDetail.hasContent) ...[
                      const SizedBox(height: 16),
                      DispatchPublicDetailCard(detail: dispatchDetail),
                    ],
                    const SizedBox(height: 16),
                    LayoutBuilder(
""").lstrip()
page = replace_once(page, metric_anchor, metric_replacement, 'Dispatch detail card placement')

old_data = dedent("""
class _PublicProfileData {
  const _PublicProfileData({
    required this.business,
    required this.personal,
    required this.listings,
    required this.tags,
  });

  final Map<String, dynamic> business;
  final Map<String, dynamic> personal;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> listings;
  final List<String> tags;
}
""").lstrip()
new_data = dedent("""
class _PublicProfileData {
  const _PublicProfileData({
    required this.business,
    required this.personal,
    required this.listings,
    required this.tags,
    required this.dispatchDirectory,
  });

  final Map<String, dynamic> business;
  final Map<String, dynamic> personal;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> listings;
  final List<String> tags;
  final Map<String, dynamic> dispatchDirectory;
}
""").lstrip()
page = replace_once(page, old_data, new_data, 'Public profile data Dispatch field')
PAGE.write_text(page, encoding='utf-8')

DETAIL.write_text(dedent("""
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_dispatch_service_taxonomy.dart';

class DispatchPublicDetail {
  const DispatchPublicDetail({
    required this.serviceCodes,
    required this.serviceAreaSummary,
    required this.availabilityCode,
    required this.emergencyCallout,
    required this.remoteSiteCapable,
    required this.approximateHomeBase,
    required this.serviceAreaMode,
    required this.serviceAreaCenterLabel,
    required this.serviceAreaRadiusKm,
  });

  factory DispatchPublicDetail.fromDirectoryProjection(
    Map<String, dynamic> data,
  ) {
    final publicLocation = _map(data['publicLocation']);
    final publicServiceArea = _map(data['publicServiceArea']);
    final serviceCodes = data['serviceCodes'] is Iterable
        ? (data['serviceCodes'] as Iterable)
            .map((value) => '$value'.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
        : const <String>[];

    return DispatchPublicDetail(
      serviceCodes: serviceCodes,
      serviceAreaSummary: '${data['serviceAreaSummary'] ?? ''}'.trim(),
      availabilityCode: '${data['availability'] ?? ''}'.trim(),
      emergencyCallout: data['emergencyCallout'] == true,
      remoteSiteCapable: data['remoteSiteCapable'] == true,
      approximateHomeBase: '${publicLocation['label'] ?? ''}'.trim(),
      serviceAreaMode: '${publicServiceArea['mode'] ?? ''}'.trim(),
      serviceAreaCenterLabel:
          '${publicServiceArea['centerLabel'] ?? ''}'.trim(),
      serviceAreaRadiusKm:
          (publicServiceArea['radiusKm'] as num?)?.toDouble() ?? 0,
    );
  }

  final List<String> serviceCodes;
  final String serviceAreaSummary;
  final String availabilityCode;
  final bool emergencyCallout;
  final bool remoteSiteCapable;
  final String approximateHomeBase;
  final String serviceAreaMode;
  final String serviceAreaCenterLabel;
  final double serviceAreaRadiusKm;

  bool get hasContent =>
      serviceCodes.isNotEmpty ||
      serviceAreaSummary.isNotEmpty ||
      availabilityCode.isNotEmpty ||
      emergencyCallout ||
      remoteSiteCapable ||
      approximateHomeBase.isNotEmpty ||
      hasPublishedRadius;

  bool get hasPublishedRadius =>
      serviceAreaMode == 'radius' && serviceAreaRadiusKm > 0;

  String get availabilityLabel => switch (availabilityCode) {
        'available_now' => 'Available now',
        'available_today' => 'Available today',
        'available_this_week' => 'Available this week',
        'unavailable' => 'Unavailable',
        _ => availabilityCode.isEmpty ? '' : 'Availability published',
      };

  String serviceLabel(String code) =>
      DispatchServiceTaxonomy.findByCode(code)?.label ?? code;

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }
}

class DispatchPublicDetailCard extends StatelessWidget {
  const DispatchPublicDetailCard({
    super.key,
    required this.detail,
  });

  final DispatchPublicDetail detail;

  @override
  Widget build(BuildContext context) {
    final centerLabel = detail.serviceAreaCenterLabel.isNotEmpty
        ? detail.serviceAreaCenterLabel
        : detail.approximateHomeBase;

    return PipeBuyerSectionCard(
      title: 'Dispatch services',
      subtitle:
          'Published industrial-service information from Pipe Buyer’s server-owned Dispatch Directory.',
      leading: const Icon(
        Icons.local_shipping_outlined,
        color: PipeBuyerColors.orange,
      ),
      trailing: detail.availabilityLabel.isEmpty
          ? null
          : PipeBuyerStatusBadge(
              label: detail.availabilityLabel.toUpperCase(),
              icon: Icons.schedule_outlined,
              tone: _availabilityTone(detail.availabilityCode),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.serviceCodes.isNotEmpty) ...[
            const Text(
              'Services offered',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: detail.serviceCodes
                  .map((code) => Chip(label: Text(detail.serviceLabel(code))))
                  .toList(growable: false),
            ),
          ],
          if (detail.emergencyCallout || detail.remoteSiteCapable) ...[
            if (detail.serviceCodes.isNotEmpty) const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (detail.emergencyCallout)
                  const Chip(
                    avatar: Icon(Icons.bolt_outlined, size: 18),
                    label: Text('Emergency callout'),
                  ),
                if (detail.remoteSiteCapable)
                  const Chip(
                    avatar: Icon(Icons.terrain_outlined, size: 18),
                    label: Text('Remote-site capable'),
                  ),
              ],
            ),
          ],
          if (detail.serviceAreaSummary.isNotEmpty) ...[
            const SizedBox(height: 14),
            _DispatchPublicDetailRow(
              icon: Icons.radar_outlined,
              label: 'Published service area',
              value: detail.serviceAreaSummary,
            ),
          ],
          if (detail.approximateHomeBase.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DispatchPublicDetailRow(
              icon: Icons.location_on_outlined,
              label: 'Approximate home base',
              value: detail.approximateHomeBase,
            ),
          ],
          if (detail.hasPublishedRadius) ...[
            const SizedBox(height: 12),
            _DispatchPublicDetailRow(
              icon: Icons.social_distance_outlined,
              label: 'Published service radius',
              value: centerLabel.isEmpty
                  ? 'Within ${_distance(detail.serviceAreaRadiusKm)} km of the provider’s approximate public service centre.'
                  : 'Within ${_distance(detail.serviceAreaRadiusKm)} km of $centerLabel.',
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  size: 18,
                  color: PipeBuyerColors.industrialBlue,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Approximate public Directory information only. Exact yards, homes, private job locations, credentials, and private contact details are not shown here. Confirm exact coverage and job details directly with the company.',
                    style: TextStyle(fontSize: 12, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static PipeBuyerStatusTone _availabilityTone(String code) => switch (code) {
        'available_now' || 'available_today' => PipeBuyerStatusTone.success,
        'available_this_week' => PipeBuyerStatusTone.info,
        _ => PipeBuyerStatusTone.neutral,
      };

  static String _distance(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);
}

class _DispatchPublicDetailRow extends StatelessWidget {
  const _DispatchPublicDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: PipeBuyerColors.industrialBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: PipeBuyerColors.muted,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .55,
                      ),
                ),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      );
}
""").lstrip(), encoding='utf-8')

TEST.write_text(dedent("""
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_public_detail.dart';

void main() {
  test('Dispatch public detail parses only bounded display fields', () {
    final detail = DispatchPublicDetail.fromDirectoryProjection({
      'serviceCodes': ['transport_hotshot', 'field_mobile_mechanic'],
      'serviceAreaSummary': 'Grande Prairie and 250 km radius',
      'availability': 'available_today',
      'emergencyCallout': true,
      'remoteSiteCapable': true,
      'publicLocation': {'label': 'Grande Prairie, Alberta'},
      'publicServiceArea': {
        'mode': 'radius',
        'centerLabel': 'Grande Prairie, Alberta',
        'radiusKm': 250,
      },
      'mapPoint': {'latitude': 55.17, 'longitude': -118.79},
      'geohash': 'c3gjg0',
      'privateEmail': 'must-not-render@example.test',
      'policyNumber': 'PRIVATE-123',
    });

    expect(detail.hasContent, isTrue);
    expect(detail.serviceCodes, contains('transport_hotshot'));
    expect(detail.serviceLabel('transport_hotshot'), 'Hotshot');
    expect(detail.serviceAreaSummary, contains('Grande Prairie'));
    expect(detail.availabilityLabel, 'Available today');
    expect(detail.emergencyCallout, isTrue);
    expect(detail.remoteSiteCapable, isTrue);
    expect(detail.approximateHomeBase, 'Grande Prairie, Alberta');
    expect(detail.hasPublishedRadius, isTrue);
    expect(detail.serviceAreaRadiusKm, 250);
  });

  testWidgets('Dispatch detail card shows simple public service information', (
    tester,
  ) async {
    final detail = DispatchPublicDetail.fromDirectoryProjection({
      'serviceCodes': ['transport_hotshot'],
      'serviceAreaSummary': 'Grande Prairie region',
      'availability': 'available_now',
      'emergencyCallout': true,
      'remoteSiteCapable': true,
      'publicLocation': {'label': 'Grande Prairie, Alberta'},
      'publicServiceArea': {
        'mode': 'radius',
        'centerLabel': 'Grande Prairie, Alberta',
        'radiusKm': 250,
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DispatchPublicDetailCard(detail: detail),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dispatch services'), findsOneWidget);
    expect(find.text('Hotshot'), findsOneWidget);
    expect(find.text('Emergency callout'), findsOneWidget);
    expect(find.text('Remote-site capable'), findsOneWidget);
    expect(find.text('Grande Prairie region'), findsOneWidget);
    expect(find.textContaining('Within 250 km of Grande Prairie'), findsOneWidget);
    expect(find.textContaining('Exact yards, homes'), findsOneWidget);
    expect(find.textContaining('must-not-render'), findsNothing);
    expect(find.textContaining('PRIVATE-123'), findsNothing);
  });

  test('Seller storefront treats Dispatch projection as optional signed-in data', () {
    final source = File(
      'lib/marketplace/marketplace_public_profile_page.dart',
    ).readAsStringSync();
    final detailSource = File(
      'lib/marketplace/marketplace_dispatch_public_detail.dart',
    ).readAsStringSync();

    expect(source, contains('Future<Map<String, dynamic>> _loadDispatchDirectoryDetail()'));
    expect(source, contains('FirebaseAuth.instance.currentUser == null'));
    expect(source, contains(".collection('dispatch_directory_entries')"));
    expect(source, contains('catch (_)'));
    expect(source, contains('DispatchPublicDetailCard(detail: dispatchDetail)'));
    expect(detailSource, isNot(contains('mapPoint')));
    expect(detailSource, isNot(contains('geohash')));
    expect(detailSource, isNot(contains('privateEmail')));
    expect(detailSource, isNot(contains('policyNumber')));
  });
}
""").lstrip(), encoding='utf-8')

DOC.write_text(dedent("""
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
""").lstrip(), encoding='utf-8')

print('Release 3 provider detail surface staged successfully.')
