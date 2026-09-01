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
      serviceAreaCenterLabel: '${publicServiceArea['centerLabel'] ?? ''}'
          .trim(),
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
  const DispatchPublicDetailCard({super.key, required this.detail});

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
