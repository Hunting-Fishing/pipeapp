import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../tycoon_engine.dart';
import '../tycoon_theme.dart';

/// Locally bundled, licensed art. The host chooses the actual files and package.
class DistrictArt {
  const DistrictArt({
    this.oilSite,
    this.gasSite,
    this.storage,
    this.warehouse,
    this.truck,
    this.ground,
    this.tree,
    this.package,
  });

  final String? oilSite, gasSite, storage, warehouse, truck, ground, tree;
  final String? package;
}

/// A selectable, illustrated overview of the existing game's lease network.
/// Selection is presentation state only; management remains with the host.
class TycoonDistrictMap extends StatefulWidget {
  const TycoonDistrictMap({
    super.key,
    required this.engine,
    required this.onLeaseSelected,
    this.art = const DistrictArt(),
    this.selectedLeaseId,
  });

  final GameEngine engine;
  final ValueChanged<LeaseSpec> onLeaseSelected;
  final DistrictArt art;
  final String? selectedLeaseId;

  @override
  State<TycoonDistrictMap> createState() => _TycoonDistrictMapState();
}

class _TycoonDistrictMapState extends State<TycoonDistrictMap> {
  final ScrollController _pan = ScrollController();
  late String _selected = widget.selectedLeaseId ??
      widget.engine.state.leases.firstOrNull?.id ??
      TycoonCatalog.leases.first.id;

  static const _navy = Color(0xFF102830);
  static const _copper = Color(0xFFF3B47F);
  static const _mint = Color(0xFF80D6BE);
  static const _muted = Color(0xFFA8BFBE);
  static const _sites = <Offset>[
    Offset(.13, .34),
    Offset(.37, .30),
    Offset(.61, .34),
    Offset(.85, .30),
    Offset(.17, .76),
    Offset(.41, .72),
    Offset(.65, .76),
    Offset(.87, .72),
  ];

  @override
  void didUpdateWidget(covariant TycoonDistrictMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLeaseId != oldWidget.selectedLeaseId &&
        widget.selectedLeaseId != null) {
      _selected = widget.selectedLeaseId!;
    }
  }

  @override
  void dispose() {
    _pan.dispose();
    super.dispose();
  }

  _SiteView _site(LeaseSpec spec) {
    final engine = widget.engine;
    final owned = engine.state.leases.where((l) => l.id == spec.id).firstOrNull;
    final reserves = engine.leaseAvailableReserves(spec.id);
    if (reserves == 0) {
      return _SiteView(spec, owned, reserves, 'Depleted', _muted);
    }
    if (owned == null) {
      return _SiteView(spec, null, reserves, 'Available', _copper);
    }
    if (!owned.developed) {
      return _SiteView(spec, owned, reserves, 'Undeveloped', _copper);
    }
    final equipment =
        engine.state.assets.where((a) => a.id == owned.assetId).firstOrNull;
    final operator = engine.state.employees
        .where((e) => e.id == owned.employeeId)
        .firstOrNull;
    if (equipment == null) {
      return _SiteView(spec, owned, reserves, 'Needs equipment', _copper);
    }
    if (operator == null) {
      return _SiteView(spec, owned, reserves, 'Needs operator', _copper);
    }
    if (equipment.condition <= 20) {
      return _SiteView(spec, owned, reserves, 'Repair needed', _copper);
    }
    if (!owned.running) {
      return _SiteView(spec, owned, reserves, 'Paused', _muted);
    }
    if (engine.transportCapacity <= 0) {
      return _SiteView(spec, owned, reserves, 'Needs transport', _copper);
    }
    final full = spec.commodity == Commodity.oil
        ? engine.state.oilInventory >= engine.oilStorageCapacity
        : engine.state.gasInventory >= engine.gasStorageCapacity;
    return _SiteView(spec, owned, reserves,
        full ? 'Storage full' : 'Ready to produce', full ? _copper : _mint);
  }

  void _select(LeaseSpec spec) {
    setState(() => _selected = spec.id);
    widget.onLeaseSelected(spec);
  }

  void _move(double direction) {
    if (!_pan.hasClients) return;
    final target =
        (_pan.offset + _pan.position.viewportDimension * .7 * direction)
            .clamp(0.0, _pan.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _pan.jumpTo(target);
    } else {
      _pan.animateTo(target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final views = TycoonCatalog.leases.map(_site).toList();
    final selected =
        views.where((v) => v.spec.id == _selected).firstOrNull ?? views.first;
    final ready = views.where((v) => v.status == 'Ready to produce').length;
    return DecoratedBox(
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: [
        BoxShadow(
            color: const Color(0xFF09252D).withValues(alpha: .12),
            blurRadius: 28,
            offset: const Offset(0, 12)),
      ]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ColoredBox(
          color: _navy,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('THE ENERGY FRONTIER',
                        style: TextStyle(
                            color: _copper,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2)),
                    const SizedBox(height: 6),
                    const Text('Your industrial district',
                        style: TextStyle(
                            color: Color(0xFFF4F2E7),
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.6)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _pill(
                          '${widget.engine.state.leases.length} OWNED', _mint),
                      _pill('$ready READY', _mint),
                      _pill(
                          'DAY ${widget.engine.state.day.toString().padLeft(3, '0')}',
                          _copper),
                    ]),
                  ]),
            ),
            LayoutBuilder(builder: (context, constraints) {
              final mapWidth = math.max(740.0, constraints.maxWidth);
              final textScale =
                  MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
              final mapHeight = 410.0 + (textScale - 1) * 150;
              final scrollable = mapWidth > constraints.maxWidth;
              return Column(children: [
                SizedBox(
                  height: mapHeight,
                  child: Scrollbar(
                    controller: _pan,
                    thumbVisibility: scrollable,
                    child: SingleChildScrollView(
                      key: const Key('district-pan'),
                      controller: _pan,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: mapWidth,
                        height: mapHeight,
                        child: Stack(clipBehavior: Clip.none, children: [
                          Positioned.fill(
                              child: CustomPaint(
                                  painter: _DistrictGroundPainter(
                                      centers: _sites,
                                      selectedIndex: views.indexOf(selected),
                                      owned: views
                                          .map((v) => v.owned != null)
                                          .toList()))),
                          if (widget.art.warehouse != null)
                            _decoration(widget.art.warehouse!, mapWidth * .47,
                                mapHeight * .48, 100, 80),
                          if (widget.art.storage != null)
                            _decoration(widget.art.storage!, mapWidth * .31,
                                mapHeight * .49, 76, 70),
                          if (widget.art.truck != null)
                            _decoration(widget.art.truck!, mapWidth * .67,
                                mapHeight * .53, 70, 52),
                          if (widget.art.tree != null) ...[
                            _decoration(widget.art.tree!, mapWidth * .04,
                                mapHeight * .48, 48, 65),
                            _decoration(widget.art.tree!, mapWidth * .95,
                                mapHeight * .46, 48, 65),
                          ],
                          for (var i = 0; i < views.length; i++)
                            Positioned(
                                left: _sites[i].dx * mapWidth - 77,
                                top: _sites[i].dy * mapHeight - 94,
                                width: 154,
                                child: _marker(views[i], i)),
                        ]),
                      ),
                    ),
                  ),
                ),
                if (scrollable)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                    child: Row(children: [
                      IconButton(
                          key: const Key('district-pan-left'),
                          tooltip: 'Pan district left',
                          color: _muted,
                          onPressed: () => _move(-1),
                          icon: const Icon(Icons.chevron_left_rounded)),
                      const Expanded(
                          child: Text('Swipe to explore · Tap a site',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _muted, fontSize: 11))),
                      IconButton(
                          key: const Key('district-pan-right'),
                          tooltip: 'Pan district right',
                          color: _muted,
                          onPressed: () => _move(1),
                          icon: const Icon(Icons.chevron_right_rounded)),
                    ]),
                  ),
              ]);
            }),
            _selection(selected),
          ]),
        ),
      ),
    );
  }

  Widget _marker(_SiteView view, int order) {
    final selected = view.spec.id == _selected;
    final image = view.spec.commodity == Commodity.oil
        ? widget.art.oilSite
        : widget.art.gasSite;
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Builder(builder: (tileContext) {
      return Semantics(
        key: Key('district-site-${view.spec.id}'),
        button: true,
        selected: selected,
        sortKey: OrdinalSortKey(order.toDouble()),
        label: '${view.spec.name}, ${view.status}. '
            '${tycoonNumber(view.reserves)} ${view.unit} reserves. '
            '${view.owned == null ? 'Explore lease' : 'Manage lease'}.',
        onTap: () => _select(view.spec),
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _select(view.spec),
              onFocusChange: (focused) {
                if (focused) {
                  Scrollable.ensureVisible(tileContext,
                      alignment: .5, duration: motion, curve: Curves.easeOut);
                }
              },
              borderRadius: BorderRadius.circular(16),
              splashColor: _copper.withValues(alpha: .2),
              focusColor: _copper.withValues(alpha: .15),
              child: AnimatedContainer(
                duration: motion,
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: selected
                            ? _copper.withValues(alpha: .7)
                            : Colors.transparent),
                    color: selected
                        ? _navy.withValues(alpha: .16)
                        : Colors.transparent),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    height: 98,
                    child: Stack(alignment: Alignment.bottomCenter, children: [
                      if (widget.art.ground != null)
                        Positioned(
                            bottom: -1,
                            width: 126,
                            height: 58,
                            child: _sprite(widget.art.ground!,
                                fit: BoxFit.contain)),
                      Opacity(
                          opacity: view.owned == null ? .48 : 1,
                          child: image == null
                              ? CustomPaint(
                                  size: const Size(112, 95),
                                  painter: _FacilityPainter(
                                      gas: view.spec.commodity == Commodity.gas,
                                      owned: view.owned != null))
                              : Transform.translate(
                                  offset: const Offset(0, 12),
                                  child:
                                      _sprite(image, height: 96, width: 120))),
                    ]),
                  ),
                  const SizedBox(height: 5),
                  Text(view.spec.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: selected
                              ? const Color(0xFFFFE4BE)
                              : const Color(0xFFE8F0E7),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.15)),
                  const SizedBox(height: 5),
                  _pill(view.status, view.color, small: true),
                ]),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _selection(_SiteView site) => Container(
        key: const Key('district-selection'),
        padding: const EdgeInsets.fromLTRB(20, 17, 20, 18),
        decoration: const BoxDecoration(
            color: Color(0xFF1B3940),
            border: Border(top: BorderSide(color: Color(0xFF355257)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 10, runSpacing: 8, children: [
            _pill(
                site.spec.commodity == Commodity.oil
                    ? 'OIL LEASE'
                    : 'GAS LEASE',
                _copper),
            _pill(site.status, site.color),
          ]),
          const SizedBox(height: 10),
          Text(site.spec.name,
              style: const TextStyle(
                  color: Color(0xFFF5F3E9),
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(site.spec.region,
              style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(spacing: 22, runSpacing: 12, children: [
            _metric('REMAINING RESERVES',
                '${tycoonNumber(site.reserves)} ${site.unit}'),
            _metric(
                site.owned == null ? 'LEASE PRICE' : 'BASE CAPACITY',
                site.owned == null
                    ? tycoonMoney(widget.engine.leasePurchaseCost(site.spec.id))
                    : '${tycoonNumber(site.spec.dailyOutput)} ${site.unit} / shift'),
          ]),
          const SizedBox(height: 14),
          OutlinedButton.icon(
              key: const Key('district-open-selected'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFE4BE),
                  side: const BorderSide(color: Color(0xFF8F7B60))),
              onPressed: () => widget.onLeaseSelected(site.spec),
              icon: Icon(
                  site.owned == null
                      ? Icons.explore_outlined
                      : Icons.tune_rounded,
                  size: 18),
              label: Text(site.owned == null
                  ? 'Explore this lease'
                  : 'Manage this site')),
        ]),
      );

  Widget _metric(String label, String value) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Color(0xFFF5F3E9),
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ]);

  Widget _pill(String text, Color color, {bool small = false}) => Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 9, vertical: small ? 4 : 6),
      decoration: BoxDecoration(
          color: _navy.withValues(alpha: small ? .88 : .38),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: .28))),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color,
              fontSize: small ? 9 : 9.5,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: small ? 0 : .6)));

  Widget _sprite(String path,
          {double? height, double? width, BoxFit fit = BoxFit.contain}) =>
      Image.asset(path,
          package: widget.art.package,
          height: height,
          width: width,
          fit: fit,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stack) => SizedBox(
              height: height ?? 70,
              width: width ?? 90,
              child:
                  const Icon(Icons.factory_outlined, size: 46, color: _muted)));

  Widget _decoration(
          String path, double x, double y, double width, double height) =>
      Positioned(
          left: x - width / 2,
          top: y - height,
          width: width,
          height: height,
          child: IgnorePointer(child: _sprite(path)));
}

class _SiteView {
  const _SiteView(
      this.spec, this.owned, this.reserves, this.status, this.color);
  final LeaseSpec spec;
  final OwnedLease? owned;
  final int reserves;
  final String status;
  final Color color;
  String get unit => spec.commodity == Commodity.oil ? 'bbl' : 'Mcf';
}

class _DistrictGroundPainter extends CustomPainter {
  _DistrictGroundPainter(
      {required this.centers,
      required this.selectedIndex,
      required this.owned});
  final List<Offset> centers;
  final int selectedIndex;
  final List<bool> owned;

  @override
  void paint(Canvas canvas, Size size) {
    Offset p(double x, double y) => Offset(x * size.width, y * size.height);
    final ground = Path()
      ..moveTo(size.width * .015, size.height * .20)
      ..lineTo(size.width * .83, size.height * .08)
      ..lineTo(size.width * .99, size.height * .83)
      ..lineTo(size.width * .17, size.height * .97)
      ..close();
    canvas.drawPath(ground.shift(const Offset(0, 14)),
        Paint()..color = const Color(0xFF081D25));
    canvas.drawPath(
        ground,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF425A53), Color(0xFF304B4D)])
              .createShader(Offset.zero & size));
    final road = Path()
      ..moveTo(size.width * .03, size.height * .55)
      ..lineTo(size.width * .96, size.height * .50);
    for (final center in centers) {
      final junction = p(center.dx, .55 - center.dx * .05);
      road.moveTo(junction.dx, junction.dy);
      road.lineTo(center.dx * size.width, center.dy * size.height);
    }
    canvas.drawPath(
        road,
        Paint()
          ..color = const Color(0xFF223B42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(
        road,
        Paint()
          ..color = const Color(0xFF657470)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(
        road,
        Paint()
          ..color = const Color(0xFFAFA88C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    for (var i = 0; i < centers.length; i++) {
      final c = p(centers[i].dx, centers[i].dy);
      final tile = Path()
        ..moveTo(c.dx, c.dy - 24)
        ..lineTo(c.dx + 68, c.dy + 3)
        ..lineTo(c.dx, c.dy + 30)
        ..lineTo(c.dx - 68, c.dy + 3)
        ..close();
      canvas.drawPath(tile.shift(const Offset(0, 7)),
          Paint()..color = const Color(0xFF1B3439));
      canvas.drawPath(
          tile,
          Paint()
            ..color =
                owned[i] ? const Color(0xFFB7B291) : const Color(0xFF72837A));
      if (i == selectedIndex) {
        canvas.drawPath(
            tile,
            Paint()
              ..color = const Color(0xFFF3B47F)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
    }
    final pipe = Paint()
      ..color = const Color(0xFFCA9D70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(
        Path()
          ..moveTo(size.width * .02, size.height * .59)
          ..lineTo(size.width * .96, size.height * .54),
        pipe);
  }

  @override
  bool shouldRepaint(covariant _DistrictGroundPainter old) =>
      old.selectedIndex != selectedIndex ||
      old.owned.length != owned.length ||
      old.owned.asMap().entries.any((entry) => entry.value != owned[entry.key]);
}

/// Original fallback art keeps the map usable if an optional sprite is absent.
class _FacilityPainter extends CustomPainter {
  const _FacilityPainter({required this.gas, required this.owned});
  final bool gas, owned;
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = const Color(0xFF203D47);
    final copper = Paint()..color = const Color(0xFFE6A66C);
    final cream = Paint()..color = const Color(0xFFE0DFCE);
    final teal = Paint()..color = const Color(0xFF79AFAA);
    if (gas) {
      for (var i = 0; i < 3; i++) {
        final x = 17.0 + i * 29;
        final y = 30.0 - i * 5;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x, y, 24, 48), const Radius.circular(7)),
            i == 1 ? teal : cream);
        canvas.drawOval(Rect.fromLTWH(x, y - 2, 24, 10), ink);
        canvas.drawRect(Rect.fromLTWH(x + 3, y + 21, 18, 3), copper);
      }
      canvas.drawLine(
          const Offset(24, 82),
          const Offset(98, 82),
          Paint()
            ..color = copper.color
            ..strokeWidth = 6);
    } else {
      canvas.drawPath(
          Path()
            ..moveTo(46, 85)
            ..lineTo(64, 24)
            ..lineTo(79, 85)
            ..close(),
          ink);
      canvas.drawLine(
          const Offset(48, 67),
          const Offset(73, 67),
          Paint()
            ..color = cream.color
            ..strokeWidth = 3);
      canvas.drawLine(
          const Offset(53, 48),
          const Offset(70, 48),
          Paint()
            ..color = cream.color
            ..strokeWidth = 3);
      canvas.drawLine(
          const Offset(29, 35),
          const Offset(91, 24),
          Paint()
            ..color = copper.color
            ..strokeWidth = 11
            ..strokeCap = StrokeCap.round);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(21, 31, 18, 22), const Radius.circular(5)),
          copper);
      canvas.drawLine(
          const Offset(28, 50),
          const Offset(28, 85),
          Paint()
            ..color = cream.color
            ..strokeWidth = 2);
      canvas.drawRect(const Rect.fromLTWH(14, 81, 30, 7), teal);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(80, 56, 27, 27), const Radius.circular(4)),
          teal);
      canvas.drawCircle(const Offset(90, 70), 7, ink);
    }
  }

  @override
  bool shouldRepaint(covariant _FacilityPainter old) =>
      old.gas != gas || old.owned != owned;
}
