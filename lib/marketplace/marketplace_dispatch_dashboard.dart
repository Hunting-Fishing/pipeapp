import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'marketplace_dispatch_repository.dart';
import 'industrial_icon_assets.dart';
import 'marketplace_location_picker.dart';
import 'marketplace_money.dart';

class MarketplaceDispatchDashboard extends StatefulWidget {
  const MarketplaceDispatchDashboard({super.key, required this.repo});
  final MarketplaceDispatchRepository repo;

  @override
  State<MarketplaceDispatchDashboard> createState() =>
      _MarketplaceDispatchDashboardState();
}

class _MarketplaceDispatchDashboardState
    extends State<MarketplaceDispatchDashboard> {
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: widget.repo.carrierProfile(),
          builder: (context, account) {
            if (account.data?.exists != true) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        IndustrialAssetIcon(
                            label: 'Dispatch dashboard',
                            assetPath: IndustrialIconAssets.dashboard,
                            size: 120,
                            borderRadius: 20,
                            fallback: Icon(Icons.dashboard_outlined,
                                size: 72, color: Color(0xFF0878E8))),
                        SizedBox(height: 16),
                        Text('Activate your Dispatch dashboard',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900)),
                        SizedBox(height: 6),
                        Text(
                            'Complete Dispatch Signup to manage rates, lanes, fleet capacity, pilot vehicles, and quotes.',
                            textAlign: TextAlign.center)
                      ])));
            }
            final data = account.data!.data()!;
            final serviceArea =
                Map<String, dynamic>.from(data['serviceArea'] ?? const {});
            final center = serviceArea['center'] as GeoPoint?;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Dispatch Dashboard',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900)),
                      Text('Rates, lanes, fleet capacity and quote planning')
                    ])),
                const SizedBox(width: 8),
                const IndustrialAssetIcon(
                    label: 'Dispatch dashboard',
                    assetPath: IndustrialIconAssets.dashboard,
                    size: 52,
                    borderRadius: 10,
                    fallback: Icon(Icons.dashboard_outlined,
                        size: 34, color: Color(0xFF0878E8))),
                const SizedBox(width: 8),
                FilledButton.icon(
                    onPressed: _newQuote,
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('New quote'))
              ]),
              const SizedBox(height: 12),
              _summaryCards(),
              const SizedBox(height: 14),
              _operationsMap(center == null
                  ? const LatLng(55.1707, -118.7947)
                  : LatLng(center.latitude, center.longitude)),
              const SizedBox(height: 16),
              const Text('Saved lanes and quotes',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const Text(
                  'Reuse regular routes, then update distance, weight and current charges before publishing.'),
              const SizedBox(height: 8),
              _savedQuotes()
            ]);
          });

  Widget _summaryCards() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.repo.fleet(),
      builder: (context, fleet) {
        final vehicles = fleet.data?.docs ?? [];
        final pilotCount =
            vehicles.where((doc) => doc.data()['pilotTruck'] == true).length;
        final payload = vehicles.fold<num>(
            0,
            (total, doc) =>
                total + (doc.data()['maximumPayloadKg'] as num? ?? 0));
        return Row(children: [
          _metric('Fleet', '${vehicles.length}', Icons.local_shipping_outlined),
          const SizedBox(width: 8),
          _metric('Pilot trucks', '$pilotCount',
              Icons.assistant_direction_outlined),
          const SizedBox(width: 8),
          _metric('Combined payload', '${payload.toStringAsFixed(0)} kg',
              Icons.scale_outlined)
        ]);
      });

  Widget _metric(String label, String value, IconData icon) => Expanded(
      child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                Icon(icon, color: const Color(0xFF0878E8)),
                Text(value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900)),
                Text(label,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFF66758A)))
              ]))));

  Widget _operationsMap(LatLng center) => StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('dispatch_scales')
          .where('status', isEqualTo: 'verified')
          .limit(500)
          .snapshots(),
      builder: (context, snapshot) {
        final scales = snapshot.data?.docs ?? [];
        return Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: Column(children: [
              const ListTile(
                  leading: Icon(Icons.map_outlined, color: Color(0xFF0878E8)),
                  title: Text('Operations map',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(
                      'Service region, recognized map boundaries and verified scale locations')),
              SizedBox(
                  height: 280,
                  child: FlutterMap(
                      options:
                          MapOptions(initialCenter: center, initialZoom: 6),
                      children: [
                        TileLayer(
                            urlTemplate: pipeBuyerTileUrl,
                            userAgentPackageName: 'ca.pipebuyer.marketplace'),
                        MarkerLayer(
                            markers: scales
                                .where((doc) => doc.data()['point'] is GeoPoint)
                                .map((doc) {
                          final point = doc.data()['point'] as GeoPoint;
                          return Marker(
                              point: LatLng(point.latitude, point.longitude),
                              width: 46,
                              height: 46,
                              child: Tooltip(
                                  message:
                                      '${doc.data()['name'] ?? 'Verified scale'}',
                                  child: const Icon(Icons.scale,
                                      size: 34, color: Color(0xFF0878E8))));
                        }).toList()),
                        const SimpleAttributionWidget(
                            source: Text('© OpenStreetMap contributors'))
                      ])),
              Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    const Icon(Icons.scale_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('${scales.length} verified scales in view'),
                    const Spacer(),
                    const Text('Confirm hours and access before travel',
                        style:
                            TextStyle(fontSize: 10, color: Color(0xFF66758A)))
                  ]))
            ]));
      });

  Widget _savedQuotes() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.repo.savedQuotes(),
      builder: (context, snapshot) {
        final quotes = snapshot.data?.docs ?? [];
        if (quotes.isEmpty) {
          return const Card(
              child: ListTile(
                  leading: Icon(Icons.bookmark_add_outlined),
                  title: Text('No saved lanes yet'),
                  subtitle: Text(
                      'Create a quote and save it for repeat locations such as Johns Farm → CJSM Yard.')));
        }
        return Column(
            children: quotes.map((quote) {
          final data = quote.data();
          return Card(
              child: ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.route_outlined)),
                  title: Text('${data['name'] ?? 'Saved lane'}',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(
                      '${data['origin'] ?? ''} → ${data['destination'] ?? ''}\n${data['distanceKm'] ?? 0} km • ${marketplaceMoney(data['total'] as num? ?? 0)}'),
                  isThreeLine: true,
                  trailing: IconButton(
                      tooltip: 'View quote history',
                      onPressed: () => _showSavedQuoteHistory(quote.id, data),
                      icon: const Icon(Icons.history_outlined)),
                  onTap: () => _newQuote(template: data, quoteId: quote.id)));
        }).toList());
      });

  Future<void> _newQuote(
      {Map<String, dynamic>? template, String? quoteId}) async {
    await showDialog<void>(
        context: context,
        builder: (_) => _DispatchQuoteDialog(
            repo: widget.repo,
            template: template ?? const {},
            quoteId: quoteId));
  }

  Future<void> _showSavedQuoteHistory(
      String quoteId, Map<String, dynamic> quote) async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * .72,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: widget.repo.savedQuoteHistory(quoteId),
                    builder: (context, snapshot) {
                      final revisions = snapshot.data?.docs ?? [];
                      return Column(children: [
                        ListTile(
                            leading: const Icon(Icons.history_outlined),
                            title: Text(
                                '${quote['name'] ?? 'Saved quote'} history',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            subtitle: const Text(
                                'Every saved pricing revision is retained.'),
                            trailing: IconButton(
                                tooltip: 'Close',
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.close))),
                        Expanded(
                            child: revisions.isEmpty
                                ? const Center(
                                    child: Text('No revisions recorded yet.'))
                                : ListView(
                                    padding: const EdgeInsets.all(12),
                                    children: revisions.map((revision) {
                                      final data = revision.data();
                                      final created =
                                          data['createdAt'] as Timestamp?;
                                      return Card(
                                          child: ListTile(
                                              leading: CircleAvatar(
                                                  child: Text(
                                                      '${data['revision'] ?? '—'}')),
                                              title: Text(
                                                  marketplaceMoney(
                                                      data['total'] as num? ??
                                                          0),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900)),
                                              subtitle: Text(
                                                  '${data['origin'] ?? ''} → ${data['destination'] ?? ''}\n${created?.toDate().toLocal() ?? 'Pending timestamp'}'),
                                              isThreeLine: true));
                                    }).toList()))
                      ]);
                    }))));
  }
}

class _DispatchQuoteDialog extends StatefulWidget {
  const _DispatchQuoteDialog(
      {required this.repo, required this.template, this.quoteId});
  final MarketplaceDispatchRepository repo;
  final Map<String, dynamic> template;
  final String? quoteId;

  @override
  State<_DispatchQuoteDialog> createState() => _DispatchQuoteDialogState();
}

class _DispatchQuoteDialogState extends State<_DispatchQuoteDialog> {
  late final Map<String, TextEditingController> c;
  bool manual = false;

  @override
  void initState() {
    super.initState();
    String initial(String key, [Object fallback = '0']) =>
        '${widget.template[key] ?? fallback}';
    c = {
      'name': TextEditingController(text: initial('name', '')),
      'origin': TextEditingController(text: initial('origin', '')),
      'destination': TextEditingController(text: initial('destination', '')),
      'distanceKm': TextEditingController(text: initial('distanceKm')),
      'deadheadKm': TextEditingController(text: initial('deadheadKm')),
      'mileageRate': TextEditingController(text: initial('mileageRate')),
      'deadheadRate': TextEditingController(text: initial('deadheadRate')),
      'weightKg': TextEditingController(text: initial('weightKg')),
      'weightRate': TextEditingController(text: initial('weightRate')),
      'hours': TextEditingController(text: initial('hours')),
      'hourlyRate': TextEditingController(text: initial('hourlyRate')),
      'areaFee': TextEditingController(text: initial('areaFee')),
      'pilotCount': TextEditingController(text: initial('pilotCount')),
      'pilotKmRate': TextEditingController(text: initial('pilotKmRate')),
      'pilotHourlyRate':
          TextEditingController(text: initial('pilotHourlyRate')),
      'pilotAreaFee': TextEditingController(text: initial('pilotAreaFee')),
      'permitFee': TextEditingController(text: initial('permitFee')),
      'baseFee': TextEditingController(text: initial('baseFee')),
      'surchargePercent':
          TextEditingController(text: initial('surchargePercent')),
      'taxPercent': TextEditingController(text: initial('taxPercent')),
      'manualTotal': TextEditingController(text: initial('manualTotal')),
    };
    for (final controller in c.values) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});
  double n(String key) => double.tryParse(c[key]!.text) ?? 0;

  Map<String, double> get calculation {
    final loadedMileage = n('distanceKm') * n('mileageRate');
    final deadhead = n('deadheadKm') * n('deadheadRate');
    final weight = n('weightKg') / 1000 * n('weightRate');
    final time = n('hours') * n('hourlyRate');
    final pilot = n('pilotCount') *
        (n('distanceKm') * n('pilotKmRate') +
            n('hours') * n('pilotHourlyRate') +
            n('pilotAreaFee'));
    final subtotal = n('baseFee') +
        loadedMileage +
        deadhead +
        weight +
        time +
        n('areaFee') +
        n('permitFee') +
        pilot;
    final surcharge = subtotal * n('surchargePercent') / 100;
    final beforeTax = subtotal + surcharge;
    final tax = beforeTax * n('taxPercent') / 100;
    return {
      'loadedMileage': loadedMileage,
      'deadhead': deadhead,
      'weight': weight,
      'time': time,
      'pilot': pilot,
      'subtotal': subtotal,
      'surcharge': surcharge,
      'tax': tax,
      'total': manual ? n('manualTotal') : beforeTax + tax
    };
  }

  @override
  Widget build(BuildContext context) {
    final total = calculation;
    return AlertDialog(
        title: const Text('Dispatch quote calculator'),
        content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
                child: Column(children: [
              _field('name', 'Saved quote / lane name'),
              Row(children: [
                Expanded(child: _field('origin', 'Origin')),
                const SizedBox(width: 8),
                Expanded(child: _field('destination', 'Destination'))
              ]),
              _section('Route and load'),
              _numberRow([
                ('distanceKm', 'Loaded distance', 'km'),
                ('deadheadKm', 'Deadhead distance', 'km'),
                ('weightKg', 'Shipping weight', 'kg'),
                ('hours', 'Estimated time', 'hours')
              ]),
              _section('Truck charges'),
              _numberRow([
                ('baseFee', 'Base / call-out', '\$'),
                ('mileageRate', 'Loaded mileage', '\$/km'),
                ('deadheadRate', 'Deadhead', '\$/km'),
                ('weightRate', 'Weight charge', '\$/tonne'),
                ('hourlyRate', 'Time charge', '\$/hour'),
                ('areaFee', 'Area / zone fee', '\$'),
                ('permitFee', 'Permits / fixed costs', '\$')
              ]),
              _section('Pilot vehicles'),
              _numberRow([
                ('pilotCount', 'Pilot vehicles needed', '#'),
                ('pilotKmRate', 'Pilot mileage', '\$/km each'),
                ('pilotHourlyRate', 'Pilot time', '\$/hour each'),
                ('pilotAreaFee', 'Pilot area fee', '\$ each')
              ]),
              _section('Adjustments'),
              _numberRow([
                ('surchargePercent', 'Fuel / service surcharge', '%'),
                ('taxPercent', 'Tax', '%')
              ]),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Manual quote'),
                  subtitle: const Text(
                      'Overrides the calculated total; the calculation remains visible for comparison.'),
                  value: manual,
                  onChanged: (value) => setState(() => manual = value)),
              if (manual) _field('manualTotal', 'Manual quoted total'),
              Card(
                  color: const Color(0xFFEAF7EE),
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        _line('Loaded mileage', total['loadedMileage']!),
                        _line('Deadhead', total['deadhead']!),
                        _line('Weight', total['weight']!),
                        _line('Time', total['time']!),
                        _line('Pilot vehicles', total['pilot']!),
                        _line('Subtotal', total['subtotal']!),
                        _line('Surcharge', total['surcharge']!),
                        _line('Tax', total['tax']!),
                        const Divider(),
                        _line('QUOTE TOTAL', total['total']!, strong: true)
                      ]))),
              const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'Map distance is a planning input. Confirm the legal truck route, restrictions, permits, borders and scale access before issuing a binding quote.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF66758A))))
            ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          FilledButton.icon(
              onPressed: _save,
              icon: Icon(widget.quoteId == null
                  ? Icons.bookmark_add_outlined
                  : Icons.save_outlined),
              label:
                  Text(widget.quoteId == null ? 'Save quote' : 'Save changes'))
        ]);
  }

  Widget _section(String value) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Align(
          alignment: Alignment.centerLeft,
          child: Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))));

  Widget _field(String key, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
          controller: c[key], decoration: InputDecoration(labelText: label)));

  Widget _numberRow(List<(String, String, String)> fields) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: fields
          .map((field) => SizedBox(
              width: 205,
              child: TextField(
                  controller: c[field.$1],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: field.$2, suffixText: field.$3))))
          .toList());

  Widget _line(String label, double amount, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: strong ? FontWeight.w900 : FontWeight.normal))),
        Text(marketplaceMoney(amount),
            style: TextStyle(
                fontSize: strong ? 18 : 14, fontWeight: FontWeight.w900))
      ]));

  Future<void> _save() async {
    if (c['name']!.text.trim().isEmpty ||
        c['origin']!.text.trim().isEmpty ||
        c['destination']!.text.trim().isEmpty ||
        calculation['total']! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Add a name, both locations and a valid quote total.')));
      return;
    }
    await widget.repo.saveQuote({
      for (final entry in c.entries)
        entry.key: ['name', 'origin', 'destination'].contains(entry.key)
            ? entry.value.text.trim()
            : double.tryParse(entry.value.text) ?? 0,
      ...calculation,
      'manual': manual,
      'formulaVersion': 1
    }, quoteId: widget.quoteId);
    if (mounted) Navigator.pop(context);
  }
}
