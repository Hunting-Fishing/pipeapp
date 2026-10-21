import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../assets.dart';
import '../audio_feedback.dart';
import '../tycoon_engine.dart';
import 'polish/asset_illustration.dart';
import 'polish/district_map.dart';
import 'tycoon_theme.dart';

class TycoonGamePage extends StatefulWidget {
  const TycoonGamePage({
    super.key,
    required this.engine,
    required this.onChanged,
    required this.onReset,
    required this.onExport,
    required this.onImport,
    this.onExit,
    this.saveWarning,
  });
  final GameEngine engine;
  final VoidCallback onChanged;
  final Future<void> Function() onReset, onExport, onImport;
  final VoidCallback? onExit;
  final String? saveWarning;

  @override
  State<TycoonGamePage> createState() => _TycoonGamePageState();
}

class _TycoonGamePageState extends State<TycoonGamePage> {
  int _tab = 0;
  String _fleetFilter = 'all';
  TycoonAssets _assets = TycoonAssets.current;
  final ValueNotifier<int> _revision = ValueNotifier(0);
  bool _siteSheetOpen = false;
  ActionResult? _siteFeedback;
  late final TycoonAudioFeedback _audio = TycoonAudioFeedback(
    assets: {
      TycoonSound.tap: TycoonAssets.sounds['tap']!,
      TycoonSound.success: TycoonAssets.sounds['success']!,
      TycoonSound.shift: TycoonAssets.sounds['shift']!,
      TycoonSound.error: TycoonAssets.sounds['error']!,
    },
    resolveAssetPath: (path) => _assets.resolve(path),
  );
  GameEngine get game => widget.engine;
  GameState get state => game.state;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPresentation());
  }

  Future<void> _loadPresentation() async {
    final assets = await TycoonAssets.load();
    if (!mounted) return;
    setState(() => _assets = assets);
    await _audio.load();
  }

  @override
  void dispose() {
    _audio.dispose();
    _revision.dispose();
    super.dispose();
  }

  void _navigate(int tab) {
    if (_tab == tab) return;
    _audio.play(TycoonSound.tap);
    setState(() => _tab = tab);
  }

  static const _destinations = [
    NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view_rounded),
        label: 'Operations'),
    NavigationDestination(
        icon: Icon(Icons.swap_horiz_rounded), label: 'Exchange'),
    NavigationDestination(
        icon: Icon(Icons.local_shipping_outlined),
        selectedIcon: Icon(Icons.local_shipping_rounded),
        label: 'Fleet'),
    NavigationDestination(
        icon: Icon(Icons.business_outlined),
        selectedIcon: Icon(Icons.business_rounded),
        label: 'Company'),
  ];

  void _act(ActionResult result,
      {bool toast = true, TycoonSound sound = TycoonSound.success}) {
    if (result.success) {
      widget.onChanged();
      setState(() {});
      HapticFeedback.selectionClick();
    }
    if (_siteSheetOpen) _siteFeedback = result;
    _revision.value++;
    _audio.play(result.success ? sound : TycoonSound.error);
    if (toast && mounted && !_siteSheetOpen) {
      final viewport = MediaQuery.sizeOf(context);
      final compactFeedback = viewport.height < 600 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.35;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: compactFeedback
            ? SnackBarBehavior.fixed
            : SnackBarBehavior.floating,
        showCloseIcon: compactFeedback,
        content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: viewport.height * .25),
            child: SingleChildScrollView(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(
                      result.success
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      color: Colors.white,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(result.message)),
                ]))),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep playing')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action))
          ],
        ),
      ) ??
      false;

  Future<void> _quantity(
      {required String title,
      required String label,
      required int initial,
      required String Function(int) summary,
      required ActionResult Function(int) action,
      required String button,
      int? maximum}) async {
    final controller = TextEditingController(text: '${math.max(1, initial)}');
    String? error;
    await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(builder: (context, update) {
              final quantity = int.tryParse(controller.text) ?? 0;
              return AlertDialog(
                scrollable: true,
                title: Text(title),
                content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: controller,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9)
                            ],
                            onChanged: (_) => update(() {
                              error = null;
                            }),
                            decoration: InputDecoration(
                                labelText: label,
                                errorText: error,
                                errorMaxLines: 3),
                          ),
                          const SizedBox(height: 12),
                          Text(summary(quantity),
                              style: Theme.of(context).textTheme.bodyMedium),
                          if (maximum != null && maximum > 0)
                            Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () {
                                    controller.text = '$maximum';
                                    update(() {
                                      error = null;
                                    });
                                  },
                                  child: Text(
                                      'Use maximum · ${tycoonNumber(maximum)}'),
                                )),
                        ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        final enteredQuantity =
                            int.tryParse(controller.text) ?? 0;
                        if (enteredQuantity <= 0) {
                          update(() {
                            error = 'Enter a whole number greater than zero.';
                          });
                          return;
                        }
                        final result = action(enteredQuantity);
                        if (!result.success) {
                          update(() {
                            error = result.message;
                          });
                          return;
                        }
                        Navigator.pop(context);
                        _act(result);
                      },
                      child: Text(button))
                ],
              );
            }));
    // The dialog route may still be animating and reading its controller.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
  }

  Future<void> _advance() async {
    final result = game.advanceDay();
    _act(result, toast: !result.success, sound: TycoonSound.shift);
    if (result.success && result.report != null && mounted) {
      _showReport(result.report!);
    }
  }

  void _showReport(DayReport report) {
    _sheet('Shift ${report.day} complete', [
      TycoonTag(report.event,
          color: TycoonPalette.orange, icon: Icons.campaign_outlined),
      const SizedBox(height: 18),
      _adaptiveGrid([
        _smallStat('OIL PRODUCED', '${tycoonNumber(report.oilProduced)} bbl',
            Icons.water_drop_outlined),
        _smallStat('GAS PRODUCED', '${tycoonNumber(report.gasProduced)} Mcf',
            Icons.local_fire_department_outlined),
      ], minWidth: 140),
      const SizedBox(height: 14),
      _detailRow('Business revenue', tycoonMoney(report.revenue)),
      _detailRow('Operating expenses', tycoonMoney(report.expenses)),
      _detailRow('Operating cash flow', tycoonMoney(report.netIncome),
          color:
              report.netIncome >= 0 ? TycoonPalette.teal : TycoonPalette.red),
      const SizedBox(height: 8),
      const Text(
          'Production is now in storage. Sell it on the Exchange or fulfill a contract to earn cash.',
          style: TextStyle(color: TycoonPalette.muted, height: 1.5)),
      if (report.notes.isNotEmpty) ...[
        const Divider(),
        ...report.notes.map((note) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.arrow_right_rounded,
                  size: 20, color: TycoonPalette.orange),
              const SizedBox(width: 5),
              Expanded(child: Text(note)),
            ]))),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            setState(() {
              _tab = 1;
            });
          },
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Open the Exchange')),
    ]);
  }

  Future<void> _sheet(String title, List<Widget> children) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: .72,
        minChildSize: .35,
        maxChildSize: .94,
        expand: false,
        builder: (context, scroll) => ListView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(
                24, 0, 24, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              ...children,
            ]),
      ),
    );
  }

  void _settings() => _sheet('Company settings', [
        ListenableBuilder(
          listenable: _audio,
          builder: (context, _) => SwitchListTile(
            key: const Key('sound-effects-toggle'),
            contentPadding: const EdgeInsets.symmetric(vertical: 5),
            secondary: Icon(
                _audio.enabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: TycoonPalette.teal),
            title: const Text('Sound effects',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Subtle cues for trades and shifts.'),
            value: _audio.enabled,
            onChanged: (enabled) => unawaited(_audio.setEnabled(enabled)),
          ),
        ),
        _menuAction(Icons.flag_outlined, 'Career guide',
            'Objectives, rewards, and your path to tycoon.', () {
          Navigator.pop(context);
          _guide();
        }),
        _menuAction(Icons.file_upload_outlined, 'Export backup',
            'Keep a portable backup of this company.', () {
          Navigator.pop(context);
          widget.onExport();
        }),
        _menuAction(Icons.file_download_outlined, 'Restore backup',
            'Restore a previously exported company.', () {
          Navigator.pop(context);
          widget.onImport();
        }),
        _menuAction(Icons.restart_alt_rounded, 'Start a new company',
            'Replace this career and begin again.', () async {
          Navigator.pop(context);
          await widget.onReset();
        }),
        _menuAction(Icons.description_outlined, 'Licenses',
            'Art, sound, software, and font credits.', () {
          Navigator.pop(context);
          showLicensePage(
              context: context,
              applicationName: 'Oil & Gas Tycoon',
              applicationVersion: '1.2.0');
        }),
        if (widget.onExit != null)
          _menuAction(Icons.arrow_back_rounded, 'Return to Pipe Buyer',
              'Leave the game with your progress saved.', () {
            Navigator.pop(context);
            widget.onExit!();
          }),
        const Divider(),
        const Text('OIL & GAS TYCOON',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        const Text('Version 1.2.0 · The industrial district',
            style: TextStyle(color: TycoonPalette.muted, fontSize: 12)),
        const SizedBox(height: 8),
        const Text(
            'Buyer & Trader · Single-player career\nAll prices, companies, leases, and money are fictional game systems. Each shift advances one game day. Your company waits for you when you leave.',
            style: TextStyle(color: TycoonPalette.muted, height: 1.6)),
      ]);

  Widget _menuAction(
          IconData icon, String title, String subtitle, VoidCallback onTap) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 5),
        leading: Icon(icon, color: TycoonPalette.teal),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );

  void _guide() => _sheet('Your road to tycoon', [
        const Text(
            'Start with a working oilfield. Run a shift, sell your production, then grow into new leases and businesses. Keep enough cash for wages, upkeep, and interest.',
            style: TextStyle(height: 1.5)),
        const SizedBox(height: 20),
        ...game.objectives.map((goal) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _objectiveCard(goal))),
        const Divider(),
        const Text('A productive field needs',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...[
          (
            '1',
            'Acquire and develop a lease',
            'Drilling uses a contractor, or your own drilling rig at a lower cost.'
          ),
          (
            '2',
            'Assign equipment and an operator',
            'Oil wells need a pumpjack. Gas wells need a gathering skid.'
          ),
          (
            '3',
            'Provide transport and storage',
            'Hire drivers for haul fleets and expand storage before it fills.'
          ),
          (
            '4',
            'Run a shift and trade',
            'Production uses reserves. Prices change each day. Sell inventory or fulfill supply contracts.'
          ),
        ].map((step) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                  radius: 14,
                  backgroundColor: TycoonPalette.paleTeal,
                  child: Text(step.$1,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: TycoonPalette.teal))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(step.$2,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(step.$3,
                        style: const TextStyle(color: TycoonPalette.muted))
                  ])),
            ]))),
        const Divider(),
        const Text('Build your competitive edge',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const Text(
            'Used equipment auctions are in the Exchange. Inspect condition and compare the bid with the new-equipment price. Your leading bid is held from available cash. If a simulated rival outbids you, that money returns in full; a winning lot joins your fleet automatically. Rivals and deadlines advance only when you run a shift.',
            style: TextStyle(height: 1.5)),
        const SizedBox(height: 14),
        const Text(
            'Research & technology is in Company. Hire an engineer, fund one project at a time, then run shifts to finish it. Research pauses if no engineer remains on your team. Completed levels improve your company permanently and survive restructuring. Cancelling unfinished research does not refund its funding.',
            style: TextStyle(height: 1.5)),
        const SizedBox(height: 14),
        const Text(
            'Keep a copy of your company with Settings → Export backup, especially before an update or moving to another browser or device. Existing version 1 companies carry forward into this update.',
            style: TextStyle(color: TycoonPalette.muted, height: 1.5)),
      ]);

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: desktop ? 28 : 16,
        title: Row(children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: TycoonPalette.ink,
                  borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.oil_barrel_rounded,
                  color: TycoonPalette.gold, size: 25)),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('OIL & GAS TYCOON',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0)),
                const SizedBox(height: 3),
                Text(state.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: TycoonPalette.muted)),
              ])),
        ]),
        actions: [
          IconButton(
              tooltip: 'Career guide',
              onPressed: _guide,
              icon: const Icon(Icons.help_outline_rounded, size: 22)),
          IconButton(
              tooltip: 'Company settings',
              onPressed: _settings,
              icon: const Icon(Icons.tune_rounded, size: 22)),
          const SizedBox(width: 6),
        ],
      ),
      body: Row(children: [
        if (desktop)
          NavigationRail(
            extended: true,
            backgroundColor: TycoonPalette.canvas,
            selectedIndex: _tab,
            onDestinationSelected: _navigate,
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: Text('Operations')),
              NavigationRailDestination(
                  icon: Icon(Icons.swap_horiz_rounded),
                  label: Text('Exchange')),
              NavigationRailDestination(
                  icon: Icon(Icons.local_shipping_outlined),
                  selectedIcon: Icon(Icons.local_shipping_rounded),
                  label: Text('Fleet & equipment')),
              NavigationRailDestination(
                  icon: Icon(Icons.business_outlined),
                  selectedIcon: Icon(Icons.business_rounded),
                  label: Text('Company')),
            ],
            trailing: Expanded(
                child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('BUYER & TRADER\nBUILD YOUR EMPIRE',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: TycoonPalette.muted,
                                    height: 1.8))))),
          ),
        Expanded(
            child: Column(children: [
          Expanded(
              child: SingleChildScrollView(
            key: PageStorageKey<String>('tycoon-section-$_tab'),
            padding: EdgeInsets.fromLTRB(
                desktop ? 24 : 16, 6, desktop ? 32 : 16, 24),
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _balanceStrip(),
                          if (widget.saveWarning != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _notice(widget.saveWarning!,
                                    Icons.save_outlined, TycoonPalette.red)),
                          if (game.isInsolvent)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _insolvency()),
                          if (state.careerComplete)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _notice(
                                    'Tycoon status achieved! Your empire is yours to keep growing.',
                                    Icons.emoji_events_rounded,
                                    TycoonPalette.teal)),
                          const SizedBox(height: 22),
                          ...switch (_tab) {
                            0 => _operations(),
                            1 => _exchange(),
                            2 => _fleet(),
                            _ => _company()
                          },
                        ]))),
          )),
          if (desktop) _shiftBar(),
        ])),
      ]),
      bottomNavigationBar: desktop
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: [
              _shiftBar(),
              NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: _navigate,
                  destinations: _destinations),
            ]),
    );
  }

  Widget _balanceStrip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
            color: TycoonPalette.ink, borderRadius: BorderRadius.circular(18)),
        child: LayoutBuilder(builder: (context, bounds) {
          return Wrap(runSpacing: 15, spacing: 12, children: [
            SizedBox(
                width: (bounds.maxWidth - 12) / 2,
                child: _balance(
                    'AVAILABLE CASH',
                    tycoonMoney(state.cash, compact: true),
                    state.cash < 0
                        ? const Color(0xFFFFBEAA)
                        : const Color(0xFFF3E6C8),
                    exact: tycoonMoney(state.cash))),
            SizedBox(
                width: (bounds.maxWidth - 12) / 2,
                child: _balance('COMPANY VALUE',
                    tycoonMoney(game.netWorth, compact: true), Colors.white,
                    exact: tycoonMoney(game.netWorth))),
          ]);
        }),
      );

  Widget _balance(String label, String value, Color color,
          {required String exact}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFFACC1C3),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
        const SizedBox(height: 7),
        Tooltip(
            message: exact,
            child: Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8))),
      ]);

  Widget _shiftBar() => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: const BoxDecoration(
            color: TycoonPalette.surface,
            border: Border(top: BorderSide(color: TycoonPalette.line))),
        child: SafeArea(
            top: false,
            bottom: false,
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final details = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DAY ${state.day.toString().padLeft(3, '0')}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: TycoonPalette.muted,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(
                                '${tycoonMoney(game.dailyPayroll + game.dailyUpkeep + game.dailyInterest, compact: true)} daily costs',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                          ]);
                      final button = FilledButton.icon(
                          key: const Key('advance-shift'),
                          onPressed: game.isInsolvent ? null : _advance,
                          style: FilledButton.styleFrom(
                              backgroundColor: TycoonPalette.teal,
                              foregroundColor: Colors.white),
                          label: const Text('Run next shift'),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20));
                      if (constraints.maxWidth < 310 &&
                          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              details,
                              const SizedBox(height: 10),
                              button
                            ]);
                      }
                      return Row(children: [
                        Expanded(child: details),
                        const SizedBox(width: 12),
                        Flexible(child: button)
                      ]);
                    })))),
      );

  List<Widget> _operations() {
    final goals = game.objectives.where((v) => !v.complete).toList();
    return [
      TycoonSectionTitle('The next great energy empire.',
          subtitle: 'Make the right moves. Build it one shift at a time.',
          trailing: TycoonTag(
              '${state.leases.length} ${state.leases.length == 1 ? 'LEASE' : 'LEASES'}')),
      TycoonDistrictMap(
        engine: game,
        onLeaseSelected: _openSiteFromMap,
        art: DistrictArt(
          oilSite: _assets.art('pumpjack'),
          gasSite: _assets.art('gas_skid'),
          storage: _assets.art('storage_tank'),
          warehouse: _assets.art('warehouse'),
          truck: _assets.art('field_tanker'),
        ),
      ),
      const SizedBox(height: 16),
      InkWell(
          onTap: _guide,
          borderRadius: BorderRadius.circular(16),
          child: TycoonPanel(
              padding: const EdgeInsets.all(14),
              color: TycoonPalette.paleTeal,
              borderColor: const Color(0xFFCFDED2),
              child: Row(children: [
                const Icon(Icons.explore_outlined,
                    color: TycoonPalette.teal, size: 27),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          goals.isEmpty
                              ? 'YOUR EMPIRE, YOUR RULES'
                              : 'YOUR NEXT MOVE',
                          style: const TextStyle(
                              color: TycoonPalette.teal,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1)),
                      const SizedBox(height: 4),
                      Text(game.gameHint,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ])),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: TycoonPalette.teal),
              ]))),
      const SizedBox(height: 18),
      _adaptiveGrid([
        _smallStat('OIL IN STORAGE', '${tycoonNumber(state.oilInventory)} bbl',
            Icons.water_drop_outlined,
            detail: 'Capacity ${tycoonNumber(game.oilStorageCapacity)}'),
        _smallStat('GAS IN STORAGE', '${tycoonNumber(state.gasInventory)} Mcf',
            Icons.local_fire_department_outlined,
            detail: 'Capacity ${tycoonNumber(game.gasStorageCapacity)}'),
        _smallStat(
            'TRANSPORT READY',
            '${tycoonNumber(game.transportCapacity)} units',
            Icons.local_shipping_outlined,
            detail: '1 bbl or 10 Mcf / unit'),
      ], minWidth: 165),
      const SizedBox(height: 24),
      TycoonSectionTitle('Your lease sites',
          subtitle: 'Develop, staff, and keep every well working.',
          trailing: state.lastReport == null
              ? null
              : IconButton(
                  tooltip: 'Last shift report',
                  onPressed: () => _showReport(state.lastReport!),
                  icon: const Icon(Icons.receipt_long_outlined))),
      ...state.leases.map((lease) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _leaseCard(lease))),
      const SizedBox(height: 14),
      const TycoonSectionTitle('Explore the frontier',
          subtitle: 'Acquire new oil and gas rights to grow your operation.'),
      _adaptiveGrid(
          TycoonCatalog.leases
              .where((spec) =>
                  !state.leases.any((v) => v.id == spec.id) &&
                  game.leaseAvailableReserves(spec.id) > 0)
              .map(_leaseOpportunity)
              .toList(),
          minWidth: 255),
    ];
  }

  Widget _smallStat(String label, String value, IconData icon,
          {String? detail}) =>
      TycoonPanel(
          padding: const EdgeInsets.all(15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: TycoonPalette.teal, size: 20),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    color: TycoonPalette.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6)),
            const SizedBox(height: 5),
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4)),
            if (detail != null)
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(detail,
                      style: const TextStyle(
                          color: TycoonPalette.muted, fontSize: 11))),
          ]));

  Widget _adaptiveGrid(List<Widget> children, {double minWidth = 260}) =>
      LayoutBuilder(builder: (context, constraints) {
        if (children.isEmpty) return const SizedBox.shrink();
        final adjusted =
            minWidth * math.min(MediaQuery.textScalerOf(context).scale(1), 1.5);
        final columns = math.max(
            1,
            math.min(
                3, ((constraints.maxWidth + 14) / (adjusted + 14)).floor()));
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: children
                .map((child) => SizedBox(width: width, child: child))
                .toList());
      });

  String? _wellIssue(OwnedLease lease) {
    if (lease.reserves <= 0) return 'DEPLETED';
    if (!lease.developed) return 'UNDEVELOPED';
    final asset = state.assets.where((v) => v.id == lease.assetId).firstOrNull;
    final employee =
        state.employees.where((v) => v.id == lease.employeeId).firstOrNull;
    if (asset == null || employee == null) return 'NEEDS SETUP';
    if (asset.condition <= 20) return 'REPAIR NEEDED';
    if (!lease.running) return 'PAUSED';
    if (game.transportCapacity <= 0) return 'NEEDS TRANSPORT';
    final commodity = TycoonCatalog.lease(lease.id).commodity;
    if (commodity == Commodity.oil &&
            state.oilInventory >= game.oilStorageCapacity ||
        commodity == Commodity.gas &&
            state.gasInventory >= game.gasStorageCapacity) {
      return 'STORAGE FULL';
    }
    return null;
  }

  Future<void> _openSiteFromMap(LeaseSpec spec) async {
    if (_siteSheetOpen) return;
    _siteSheetOpen = true;
    _siteFeedback = null;
    _audio.play(TycoonSound.tap);
    try {
      await _sheet(spec.name, [
        TycoonAssetIllustration(
          path: _assets
              .art(spec.commodity == Commodity.oil ? 'pumpjack' : 'gas_skid'),
          height: 180,
          fallbackIcon: _commodityIcon(spec.commodity),
        ),
        const SizedBox(height: 18),
        ValueListenableBuilder<int>(
          valueListenable: _revision,
          builder: (context, _, child) {
            final owned =
                state.leases.where((v) => v.id == spec.id).firstOrNull;
            final feedback = _siteFeedback;
            // A merged progress-bar role hides descendant buttons on the web.
            // Keep the reserve meter, live feedback, and actions independent.
            return Semantics(
              container: true,
              explicitChildNodes: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (feedback != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: _notice(
                          feedback.message,
                          feedback.success
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          feedback.success
                              ? TycoonPalette.teal
                              : TycoonPalette.red),
                    ),
                    const SizedBox(height: 14),
                  ],
                  owned == null ? _leaseOpportunity(spec) : _leaseCard(owned),
                ],
              ),
            );
          },
        ),
      ]);
    } finally {
      _siteSheetOpen = false;
    }
  }

  Widget _equipmentArt(AssetSpec spec, {double height = 150}) =>
      TycoonAssetIllustration(
        path: _assets.equipment(spec.id),
        height: height,
        fallbackIcon: _assetIcon(spec),
      );

  Widget _leaseCard(OwnedLease lease) {
    final spec = TycoonCatalog.lease(lease.id);
    final asset = state.assets.where((v) => v.id == lease.assetId).firstOrNull;
    final employee =
        state.employees.where((v) => v.id == lease.employeeId).firstOrNull;
    final issue = _wellIssue(lease);
    final ready = issue == null;
    final status = issue ?? 'READY TO PRODUCE';
    return TycoonPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _iconTile(
            _commodityIcon(spec.commodity),
            spec.commodity == Commodity.oil
                ? TycoonPalette.orange
                : TycoonPalette.teal),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(spec.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(spec.region, style: Theme.of(context).textTheme.bodySmall)
        ])),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: [
        TycoonTag(status,
            color: ready && lease.running
                ? TycoonPalette.teal
                : TycoonPalette.orange),
        TycoonTag(
            '${_commodityName(spec.commodity).toUpperCase()} · UP TO ${tycoonNumber(spec.dailyOutput)} ${_unit(spec.commodity).toUpperCase()}/DAY',
            color: TycoonPalette.muted)
      ]),
      const SizedBox(height: 16),
      ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
              value: (lease.reserves / spec.reserves).clamp(0, 1),
              minHeight: 5,
              color: spec.commodity == Commodity.oil
                  ? TycoonPalette.orange
                  : TycoonPalette.teal)),
      const SizedBox(height: 7),
      Text(
          '${tycoonNumber(lease.reserves)} ${_unit(spec.commodity)} reserves remaining',
          style: Theme.of(context).textTheme.bodySmall),
      if (lease.developed) ...[
        const Divider(),
        _detailRow(
            'Equipment',
            asset == null
                ? 'Assign equipment'
                : TycoonCatalog.asset(asset.catalogId).name),
        _detailRow('Field operator', employee?.name ?? 'Assign an operator'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
              onPressed: () => _assignLease(lease),
              icon: const Icon(Icons.settings_outlined, size: 17),
              label: const Text('Manage well')),
          FilledButton.tonalIcon(
              onPressed: lease.reserves <= 0
                  ? null
                  : () => _act(game.setLeaseRunning(lease.id, !lease.running)),
              icon: Icon(
                  lease.running
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 18),
              label: Text(lease.running ? 'Pause' : 'Start well')),
        ]),
      ] else ...[
        const SizedBox(height: 16),
        Text(
            'Develop this site, then assign compatible equipment and an operator.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        FilledButton.icon(
            onPressed: () async {
              final cost = game.leaseDevelopmentCost(lease.id);
              if (await _confirm(
                  'Develop ${spec.name}?',
                  'Drilling costs ${tycoonMoney(cost)}. You will also need compatible production equipment and a field operator before this site can produce.',
                  'Develop lease')) {
                _act(game.developLease(lease.id));
              }
            },
            icon: const Icon(Icons.construction_rounded, size: 18),
            label: Text(
                'Develop · ${tycoonMoney(game.leaseDevelopmentCost(lease.id))}')),
      ],
      const SizedBox(height: 6),
      Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
              onPressed: () async {
                if (await _confirm(
                    'Sell ${spec.name}?',
                    'Receive ${tycoonMoney(game.leaseSaleValue(lease.id))}. Your equipment and employees remain with the company and become available for reassignment. If you buy this site back, depleted reserves stay depleted and development is required again.',
                    'Sell lease')) {
                  _act(game.sellLease(lease.id));
                }
              },
              icon: const Icon(Icons.sell_outlined, size: 16),
              label: Text(
                  'Sell lease · ${tycoonMoney(game.leaseSaleValue(lease.id), compact: true)}'))),
    ]));
  }

  Future<void> _assignLease(OwnedLease lease) async {
    String assetId = lease.assetId ?? '';
    String employeeId = lease.employeeId ?? '';
    final commodity = TycoonCatalog.lease(lease.id).commodity;
    final assets = state.assets
        .where((v) =>
            TycoonCatalog.asset(v.catalogId).commodity == commodity &&
            TycoonCatalog.asset(v.catalogId).production > 0)
        .toList();
    final employees =
        state.employees.where((v) => v.role == EmployeeRole.operator).toList();
    String? error;
    await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  scrollable: true,
                  title: Text('Set up ${TycoonCatalog.lease(lease.id).name}'),
                  content: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            const Text(
                                'Each field needs its own compatible machine and operator. Drivers and haul capacity serve the whole company.'),
                            const SizedBox(height: 18),
                            _select(
                                'Production equipment',
                                assetId,
                                [
                                  const DropdownMenuItem(
                                      value: '', child: Text('Unassigned')),
                                  ...assets.map((v) => DropdownMenuItem(
                                      value: v.id,
                                      child: Text(
                                          '${TycoonCatalog.asset(v.catalogId).name} · ${v.condition}%',
                                          overflow: TextOverflow.ellipsis)))
                                ],
                                (value) => update(() {
                                      assetId = value ?? '';
                                    })),
                            const SizedBox(height: 16),
                            _select(
                                'Field operator',
                                employeeId,
                                [
                                  const DropdownMenuItem(
                                      value: '', child: Text('Unassigned')),
                                  ...employees.map((v) => DropdownMenuItem(
                                      value: v.id,
                                      child: Text('${v.name} · L${v.level}',
                                          overflow: TextOverflow.ellipsis)))
                                ],
                                (value) => update(() {
                                      employeeId = value ?? '';
                                    })),
                            if (assets.isEmpty || employees.isEmpty) ...[
                              const SizedBox(height: 14),
                              const Text(
                                  'Buy compatible equipment in Fleet and hire an operator in Company.',
                                  style: TextStyle(color: TycoonPalette.orange))
                            ],
                            if (error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Text(error!,
                                      style: const TextStyle(
                                          color: TycoonPalette.red))),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          final result = game.assignLease(lease.id,
                              assetId: assetId.isEmpty ? null : assetId,
                              employeeId:
                                  employeeId.isEmpty ? null : employeeId);
                          if (!result.success) {
                            update(() {
                              error = result.message;
                            });
                            return;
                          }
                          Navigator.pop(context);
                          _act(result);
                        },
                        child: const Text('Save assignment'))
                  ],
                )));
  }

  Widget _select(
          String label,
          String value,
          List<DropdownMenuItem<String>> items,
          ValueChanged<String?> onChanged) =>
      InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5)),
        child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: items,
                onChanged: onChanged)),
      );

  Widget _leaseOpportunity(LeaseSpec spec) => TycoonPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _iconTile(
              _commodityIcon(spec.commodity),
              spec.commodity == Commodity.oil
                  ? TycoonPalette.orange
                  : TycoonPalette.teal,
              small: true),
          const SizedBox(width: 10),
          Expanded(
              child: Text(spec.region.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 9,
                      color: TycoonPalette.muted,
                      letterSpacing: .8,
                      fontWeight: FontWeight.w800)))
        ]),
        const SizedBox(height: 14),
        Text(spec.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 7),
        Text(
            '${tycoonNumber(game.leaseAvailableReserves(spec.id))} ${_unit(spec.commodity)} reserves\nUp to ${tycoonNumber(spec.dailyOutput)} ${_unit(spec.commodity)} per shift',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Text(
            'Development ${tycoonMoney(spec.developmentCost)} before rig savings',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        OutlinedButton(
            onPressed: () async {
              if (await _confirm(
                  'Acquire ${spec.name}?',
                  'The lease costs ${tycoonMoney(game.leasePurchaseCost(spec.id))}. Base development adds ${tycoonMoney(spec.developmentCost)}, plus equipment and staff. The lease produces only after development and setup.',
                  'Acquire lease')) {
                _act(game.acquireLease(spec.id));
              }
            },
            child: Text(
                'Acquire · ${tycoonMoney(game.leasePurchaseCost(spec.id))}')),
      ]));

  List<Widget> _exchange() => [
        const TycoonSectionTitle('Buy smart. Sell stronger.',
            subtitle:
                'Prices move every shift. Watch your margins and storage.'),
        _auctionBoard(),
        const SizedBox(height: 20),
        _adaptiveGrid(Commodity.values.map(_commodityCard).toList(),
            minWidth: 275),
        const SizedBox(height: 24),
        const TycoonSectionTitle('Supply contracts',
            subtitle: 'Lock a price, reserve your stock, and deliver on time.'),
        _notice(
            'Accepting a contract locks a refundable deposit. Deliver the full quantity by its deadline to receive the payout and deposit back. Missing the deadline loses the deposit.',
            Icons.assignment_outlined,
            TycoonPalette.teal),
        const SizedBox(height: 14),
        ...state.contracts.where((v) => v.status == ContractStatus.active).map(
            (v) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _contractCard(v))),
        _adaptiveGrid(
            state.contracts
                .where((v) => v.status == ContractStatus.available)
                .map(_contractCard)
                .toList(),
            minWidth: 285),
        if (!state.contracts.any((v) =>
            v.status == ContractStatus.available ||
            v.status == ContractStatus.active))
          const TycoonPanel(
              child: Text('New supply offers arrive as you advance shifts.')),
        if (state.contracts.any((v) =>
            v.status == ContractStatus.completed ||
            v.status == ContractStatus.failed)) ...[
          const SizedBox(height: 22),
          TycoonPanel(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                  title: const Text('Contract history',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  children: state.contracts
                      .where((v) =>
                          v.status == ContractStatus.completed ||
                          v.status == ContractStatus.failed)
                      .map((v) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: _detailRow(
                              v.title,
                              v.status == ContractStatus.completed
                                  ? 'Delivered'
                                  : 'Expired',
                              color: v.status == ContractStatus.completed
                                  ? TycoonPalette.teal
                                  : TycoonPalette.red)))
                      .toList())),
        ],
      ];

  Widget _auctionBoard() {
    final open = state.auctions
        .where((auction) => auction.status == AuctionStatus.open)
        .toList();
    final history = state.auctions
        .where((auction) => auction.status != AuctionStatus.open)
        .toList()
      ..sort((a, b) => b.closingDay.compareTo(a.closingDay));
    return TycoonPanel(
        padding: EdgeInsets.zero,
        borderColor: const Color(0xFFE6C8A4),
        child: ExpansionTile(
            key: const PageStorageKey<String>('auction-board'),
            leading:
                const Icon(Icons.gavel_rounded, color: TycoonPalette.orange),
            title: const Text('Used equipment auctions',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
                '${open.length} open lots · ${tycoonMoney(game.auctionEscrow)} held'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              _notice(
                  'Bid against simulated rivals for used machinery. Rivals bid and lots close when you run shifts. Leading bids are held from your cash; being outbid refunds the full amount. Winning equipment goes straight to your fleet.',
                  Icons.info_outline_rounded,
                  TycoonPalette.orange),
              const SizedBox(height: 14),
              _adaptiveGrid(open.map(_auctionCard).toList(), minWidth: 285),
              if (open.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('New lots arrive as you run shifts.')),
              if (history.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Recent auction results',
                        style: TextStyle(fontWeight: FontWeight.w800))),
                const SizedBox(height: 8),
                ...history.take(6).map((auction) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: _detailRow(
                        '${auction.spec.name} · day ${auction.closingDay}',
                        switch (auction.status) {
                          AuctionStatus.won =>
                            'Won · ${tycoonMoney(auction.currentBid)}',
                          AuctionStatus.lost =>
                            '${auction.leaderName} · ${tycoonMoney(auction.currentBid)}',
                          AuctionStatus.unsold => 'No sale',
                          AuctionStatus.open => 'Open',
                        },
                        color: auction.status == AuctionStatus.won
                            ? TycoonPalette.teal
                            : TycoonPalette.muted))),
              ],
            ]));
  }

  Widget _auctionCard(AssetAuction auction) {
    final spec = auction.spec;
    final shiftsLeft = math.max(0, auction.closingDay - state.day);
    final minimum = game.minimumAuctionBid(auction.id);
    final canRaise = minimum <= spec.price;
    return TycoonPanel(
        key: Key('auction-${auction.id}'),
        borderColor: auction.playerLeading ? const Color(0xFFBDDAC9) : null,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _equipmentArt(spec, height: 140),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _iconTile(_assetIcon(spec), TycoonPalette.orange, small: true),
            const SizedBox(width: 10),
            Expanded(
                child: Text(spec.name,
                    style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 7, runSpacing: 7, children: [
            TycoonTag('${auction.condition}% CONDITION',
                color: auction.condition < 50
                    ? TycoonPalette.orange
                    : TycoonPalette.teal),
            TycoonTag(auction.playerLeading ? 'YOU LEAD' : 'OPEN LOT',
                color: auction.playerLeading
                    ? TycoonPalette.teal
                    : TycoonPalette.muted),
          ]),
          const SizedBox(height: 12),
          Text(spec.description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          _detailRow('New-equipment price', tycoonMoney(spec.price)),
          _detailRow(
              auction.currentBid == 0 ? 'Opening bid' : 'Leading bid',
              tycoonMoney(auction.currentBid == 0
                  ? auction.openingBid
                  : auction.currentBid)),
          _detailRow('Leading bidder',
              auction.playerLeading ? 'Your company' : auction.leaderName),
          _detailRow('Closes day ${auction.closingDay}',
              '$shiftsLeft ${shiftsLeft == 1 ? 'shift' : 'shifts'} to go',
              color:
                  shiftsLeft <= 1 ? TycoonPalette.orange : TycoonPalette.muted),
          if (auction.playerLeading)
            _detailRow('Your cash held', tycoonMoney(auction.currentBid),
                color: TycoonPalette.teal),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
              key: Key('bid-${auction.id}'),
              onPressed: canRaise ? () => _bidAtAuction(auction) : null,
              icon: const Icon(Icons.gavel_rounded, size: 18),
              label: Text(
                  canRaise
                      ? '${auction.playerLeading ? 'Raise bid' : 'Place bid'} · ${tycoonMoney(minimum)}+'
                      : 'Maximum bid reached',
                  textAlign: TextAlign.center)),
        ]));
  }

  Future<void> _bidAtAuction(AssetAuction auction) => _quantity(
      title: 'Bid on ${auction.spec.name}',
      label: 'Your bid (game dollars)',
      initial: game.minimumAuctionBid(auction.id),
      summary: (amount) {
        final alreadyHeld = auction.playerLeading ? auction.currentBid : 0;
        final extra = math.max(0, amount - alreadyHeld);
        return '${auction.condition}% condition · closes on day ${auction.closingDay}\n'
            'Minimum ${tycoonMoney(game.minimumAuctionBid(auction.id))}; maximum ${tycoonMoney(auction.spec.price)}.\n'
            '${tycoonMoney(extra)} more cash will be held. '
            'Bids cannot be withdrawn. If a rival outbids you, your full bid is returned.';
      },
      action: (amount) => game.bidAtAuction(auction.id, amount),
      button: 'Confirm bid');

  Widget _commodityCard(Commodity commodity) {
    final oil = commodity == Commodity.oil;
    final price = oil ? state.oilPrice : state.gasPrice;
    final inventory = oil ? state.oilInventory : state.gasInventory;
    final capacity = oil ? game.oilStorageCapacity : game.gasStorageCapacity;
    final color = oil ? TycoonPalette.orange : TycoonPalette.teal;
    final prices = state.priceHistory
        .map((point) => (oil ? point.oil : point.gas).toDouble())
        .toList();
    return TycoonPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        _iconTile(_commodityIcon(commodity), color),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(oil ? 'Crude oil' : 'Natural gas',
              style: Theme.of(context).textTheme.titleMedium),
          Text('Reference market · per ${_unit(commodity)}',
              style: Theme.of(context).textTheme.bodySmall)
        ]))
      ]),
      const SizedBox(height: 18),
      Text(tycoonMoney(price),
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontSize: 32)),
      const SizedBox(height: 5),
      Row(children: [
        Text('DAY ${state.day}',
            style: const TextStyle(
                fontSize: 9,
                color: TycoonPalette.muted,
                letterSpacing: 1,
                fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
                prices.length <= 1
                    ? 'Trend begins after your first shift'
                    : 'Last ${prices.length} shifts',
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 10, color: TycoonPalette.muted)))
      ]),
      const SizedBox(height: 10),
      Semantics(
          label:
              '${_commodityName(commodity)} price history: ${prices.map((v) => v.round()).join(', ')} game dollars',
          child: SizedBox(
              height: 72,
              child: CustomPaint(painter: _PricePainter(prices, color)))),
      const SizedBox(height: 15),
      _detailRow('Stored / capacity',
          '${tycoonNumber(inventory)} / ${tycoonNumber(capacity)} ${_unit(commodity)}'),
      const SizedBox(height: 5),
      ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
              value: capacity == 0 ? 0 : (inventory / capacity).clamp(0, 1),
              minHeight: 5,
              color: inventory >= capacity ? TycoonPalette.orange : color)),
      const SizedBox(height: 15),
      _detailRow('Buy quote',
          '${tycoonMoney(game.commodityBuyPrice(commodity))} / ${_unit(commodity)}'),
      _detailRow('Sell quote',
          '${tycoonMoney(game.commoditySellPrice(commodity))} / ${_unit(commodity)}'),
      const SizedBox(height: 13),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
            onPressed: () => _trade(commodity, true),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Buy stock')),
        FilledButton.icon(
            onPressed: inventory == 0 ? null : () => _trade(commodity, false),
            icon: const Icon(Icons.north_east_rounded, size: 17),
            label: const Text('Sell stock')),
      ]),
    ]));
  }

  void _trade(Commodity commodity, bool buy) {
    final inventory =
        commodity == Commodity.oil ? state.oilInventory : state.gasInventory;
    final capacity = commodity == Commodity.oil
        ? game.oilStorageCapacity
        : game.gasStorageCapacity;
    final price = buy
        ? game.commodityBuyPrice(commodity)
        : game.commoditySellPrice(commodity);
    final max = buy
        ? math.max(0, math.min(capacity - inventory, state.cash ~/ price))
        : inventory;
    _quantity(
        title:
            '${buy ? 'Buy' : 'Sell'} ${_commodityName(commodity).toLowerCase()}',
        label: 'Quantity (${_unit(commodity)})',
        initial: buy ? math.min(100, math.max(1, max)) : inventory,
        summary: (quantity) =>
            '${tycoonMoney(price)} per ${_unit(commodity)} · ${buy ? 'Total cost' : 'You receive'} ${tycoonMoney(quantity * price)}\n${buy ? '${tycoonNumber(capacity - inventory)} ${_unit(commodity)} storage available' : '${tycoonNumber(inventory)} ${_unit(commodity)} in storage'}',
        action: (quantity) =>
            game.tradeCommodity(commodity, quantity, buy: buy),
        button: buy ? 'Buy stock' : 'Sell stock',
        maximum: max);
  }

  Widget _contractCard(GameContract contract) {
    final active = contract.status == ContractStatus.active;
    final inventory = contract.commodity == Commodity.oil
        ? state.oilInventory
        : state.gasInventory;
    final daysLeft = contract.deadlineDay - state.day;
    return TycoonPanel(
        borderColor: active ? const Color(0xFFBDDAC9) : null,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _iconTile(Icons.assignment_outlined,
                active ? TycoonPalette.teal : TycoonPalette.muted,
                small: true),
            const SizedBox(width: 10),
            Expanded(
                child: Text(contract.title,
                    style: Theme.of(context).textTheme.titleMedium))
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 7, runSpacing: 7, children: [
            TycoonTag(active ? 'ACCEPTED' : 'NEW OFFER',
                color: active ? TycoonPalette.teal : TycoonPalette.orange),
            TycoonTag(
                daysLeft == 0 ? 'DUE TODAY' : 'DUE DAY ${contract.deadlineDay}',
                color: daysLeft <= 1 ? TycoonPalette.red : TycoonPalette.muted)
          ]),
          const SizedBox(height: 15),
          Text(
              '${tycoonNumber(contract.quantity)} ${_unit(contract.commodity)} of ${_commodityName(contract.commodity).toLowerCase()}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _detailRow('Contract payout',
              tycoonMoney(contract.quantity * contract.unitPrice),
              color: TycoonPalette.teal),
          _detailRow('Locked price',
              '${tycoonMoney(contract.unitPrice)} / ${_unit(contract.commodity)}'),
          _detailRow(active ? 'Deposit held' : 'Deposit required',
              tycoonMoney(contract.deposit)),
          if (active) ...[
            const SizedBox(height: 8),
            Text(
                '${tycoonNumber(inventory)} of ${tycoonNumber(contract.quantity)} ${_unit(contract.commodity)} ready',
                style: Theme.of(context).textTheme.bodySmall)
          ],
          const SizedBox(height: 15),
          FilledButton.tonal(
              onPressed: () async {
                if (active) {
                  _act(game.deliverContract(contract.id));
                } else if (await _confirm(
                    'Accept this supply contract?',
                    'A ${tycoonMoney(contract.deposit)} deposit will be held. Deliver ${tycoonNumber(contract.quantity)} ${_unit(contract.commodity)} by day ${contract.deadlineDay} to earn ${tycoonMoney(contract.quantity * contract.unitPrice)} and recover your deposit. A missed deadline loses the deposit.',
                    'Accept contract')) {
                  _act(game.acceptContract(contract.id));
                }
              },
              child: Text(active ? 'Deliver contract' : 'Accept offer')),
        ]));
  }

  List<Widget> _fleet() => [
        const TycoonSectionTitle('Built for the hard work.',
            subtitle:
                'Productive wells need capable equipment and reliable transport.'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final filter in [
            ('all', 'All assets'),
            ('equipment', 'Equipment'),
            ('vehicle', 'Vehicles'),
            ('storage', 'Storage')
          ])
            ChoiceChip(
                label: Text(filter.$2),
                selected: _fleetFilter == filter.$1,
                onSelected: (_) => setState(() {
                      _fleetFilter = filter.$1;
                    })),
        ]),
        const SizedBox(height: 22),
        TycoonSectionTitle('Your fleet',
            subtitle:
                '${state.assets.length} assets · ${tycoonMoney(game.dailyUpkeep)} total daily upkeep'),
        _adaptiveGrid(
            state.assets
                .where((asset) =>
                    _fleetFilter == 'all' ||
                    TycoonCatalog.asset(asset.catalogId).category ==
                        _fleetFilter)
                .map(_ownedAssetCard)
                .toList(),
            minWidth: 265),
        if (!state.assets.any((asset) =>
            _fleetFilter == 'all' ||
            TycoonCatalog.asset(asset.catalogId).category == _fleetFilter))
          const TycoonPanel(
              child: Text(
                  'Your company does not own any assets in this category yet.')),
        const SizedBox(height: 26),
        const TycoonSectionTitle('Equipment & vehicle exchange',
            subtitle:
                'Buy production, transport, drilling, and storage capacity.'),
        _adaptiveGrid(
            TycoonCatalog.assets
                .where((spec) =>
                    _fleetFilter == 'all' || spec.category == _fleetFilter)
                .map(_assetOpportunity)
                .toList(),
            minWidth: 265),
      ];

  Widget _ownedAssetCard(OwnedAsset asset) {
    final spec = TycoonCatalog.asset(asset.catalogId);
    final assigned =
        state.leases.where((lease) => lease.assetId == asset.id).firstOrNull;
    return TycoonPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _equipmentArt(spec, height: 132),
      const SizedBox(height: 14),
      Row(children: [
        _iconTile(_assetIcon(spec), TycoonPalette.teal),
        const SizedBox(width: 12),
        Expanded(
            child:
                Text(spec.name, style: Theme.of(context).textTheme.titleMedium))
      ]),
      const SizedBox(height: 14),
      Text(spec.description, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 15),
      Wrap(spacing: 7, runSpacing: 7, children: [
        TycoonTag(assigned == null
            ? 'COMPANY ASSET'
            : TycoonCatalog.lease(assigned.id).name.toUpperCase()),
        TycoonTag('${asset.condition}% CONDITION',
            color:
                asset.condition < 35 ? TycoonPalette.red : TycoonPalette.muted)
      ]),
      const SizedBox(height: 12),
      ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
              value: asset.condition / 100,
              minHeight: 5,
              color: asset.condition < 35
                  ? TycoonPalette.red
                  : TycoonPalette.teal)),
      const SizedBox(height: 10),
      _detailRow('Daily upkeep', tycoonMoney(spec.upkeep)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
            onPressed: asset.condition == 100
                ? null
                : () => _act(game.repairAsset(asset.id)),
            icon: const Icon(Icons.build_outlined, size: 16),
            label:
                Text('Repair ${tycoonMoney(game.assetRepairCost(asset.id))}')),
        TextButton(
            onPressed: () async {
              final value = game.assetSaleValue(asset.id);
              if (await _confirm(
                  'Sell ${spec.name}?',
                  'Receive ${tycoonMoney(value)}. ${assigned == null ? 'Your production, haul, or storage capacity may decrease.' : '${TycoonCatalog.lease(assigned.id).name} will need replacement equipment.'} Storage assets cannot be sold while their capacity is needed.',
                  'Sell asset')) {
                _act(game.sellAsset(asset.id));
              }
            },
            child: Text(
                'Sell ${tycoonMoney(game.assetSaleValue(asset.id), compact: true)}')),
      ]),
    ]));
  }

  Widget _assetOpportunity(AssetSpec spec) => TycoonPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Stack(children: [
          _equipmentArt(spec, height: 162),
          Positioned(
            top: 10,
            left: 10,
            child: TycoonTag(spec.category.toUpperCase(),
                color: TycoonPalette.muted),
          ),
        ]),
        const SizedBox(height: 16),
        Text(spec.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 7),
        Text(spec.description, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        _detailRow('Daily upkeep', tycoonMoney(spec.upkeep)),
        const SizedBox(height: 13),
        OutlinedButton(
            onPressed: () async {
              if (await _confirm(
                  'Buy ${spec.name}?',
                  '${tycoonMoney(spec.price)} purchase price and ${tycoonMoney(spec.upkeep)} daily upkeep. ${spec.description}',
                  'Buy asset')) {
                _act(game.buyAsset(spec.id));
              }
            },
            child: Text('Buy · ${tycoonMoney(spec.price)}')),
      ]));

  List<Widget> _company() => [
        const TycoonSectionTitle('People. Assets. Ambition.',
            subtitle: 'Build the company behind your energy empire.'),
        _adaptiveGrid([
          _smallStat('TEAM SIZE', '${state.employees.length} people',
              Icons.groups_outlined,
              detail: '${tycoonMoney(game.dailyPayroll)} daily payroll'),
          _smallStat('BUSINESSES', '${state.businesses.length} owned',
              Icons.business_outlined,
              detail: 'Income and operational bonuses'),
          _smallStat(
              'CAREER PROGRESS',
              '${game.objectives.where((v) => v.complete).length}/${game.objectives.length} goals',
              Icons.emoji_events_outlined,
              detail:
                  '${tycoonNumber(state.contractsCompleted)} contracts delivered'),
        ], minWidth: 170),
        const SizedBox(height: 20),
        _researchBoard(),
        const SizedBox(height: 24),
        const TycoonSectionTitle('Your team',
            subtitle:
                'Operators run wells. Drivers move production. Specialists improve the whole company.'),
        ...state.employees.map((employee) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _employeeCard(employee))),
        const SizedBox(height: 12),
        const TycoonSectionTitle('Hire talent'),
        _adaptiveGrid(EmployeeRole.values.map(_hireCard).toList(),
            minWidth: 220),
        const SizedBox(height: 26),
        const TycoonSectionTitle('Business portfolio',
            subtitle:
                'Own the supporting businesses and create new income streams.'),
        _adaptiveGrid(TycoonCatalog.businesses.map(_businessCard).toList(),
            minWidth: 265),
        const SizedBox(height: 26),
        const TycoonSectionTitle('Finance desk',
            subtitle: 'Borrow for growth. Protect your operating cash.'),
        _finance(),
        const SizedBox(height: 24),
        TycoonPanel(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
                title: const Text('Career objectives',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                leading: const Icon(Icons.emoji_events_outlined,
                    color: TycoonPalette.orange),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: game.objectives
                    .map((goal) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _objectiveCard(goal)))
                    .toList())),
        const SizedBox(height: 14),
        TycoonPanel(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
                title: const Text('Company ledger',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                leading: const Icon(Icons.receipt_long_outlined,
                    color: TycoonPalette.teal),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                children: [
                  const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                          'Most recent company transactions. Amounts are fictional game dollars.',
                          style: TextStyle(
                              color: TycoonPalette.muted, fontSize: 12))),
                  ...state.ledger.take(40).map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                                width: 44,
                                child: Text('D${entry.day}',
                                    style: const TextStyle(
                                        color: TycoonPalette.muted,
                                        fontSize: 11))),
                            Expanded(
                                child: Text(entry.title,
                                    style: const TextStyle(fontSize: 12))),
                            const SizedBox(width: 10),
                            Flexible(
                                child: Text(
                                    '${entry.amount > 0 ? '+' : ''}${tycoonMoney(entry.amount)}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: entry.amount >= 0
                                            ? TycoonPalette.teal
                                            : TycoonPalette.ink))),
                          ]))),
                ])),
      ];

  Widget _researchBoard() {
    final project = state.researchProject;
    final completed = TycoonCatalog.research
        .fold<int>(0, (sum, spec) => sum + game.researchLevel(spec.id));
    final total =
        TycoonCatalog.research.fold<int>(0, (sum, spec) => sum + spec.maxLevel);
    final projectSpec = project == null
        ? null
        : TycoonCatalog.research
            .firstWhere((spec) => spec.id == project.researchId);
    final summary = project == null
        ? '$completed / $total levels completed · One project at a time'
        : '${game.researchCanProgress ? 'In progress' : 'Paused'}: ${projectSpec!.name} · ${project.remainingShifts} shifts left';
    return TycoonPanel(
        padding: EdgeInsets.zero,
        borderColor: const Color(0xFFCFC3E2),
        child: ExpansionTile(
            key: const PageStorageKey<String>('research-board'),
            leading:
                const Icon(Icons.science_outlined, color: Color(0xFF7764A9)),
            title: const Text('Research & technology',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(summary),
            childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              const Text(
                  'Fund permanent improvements to your company. One employed engineer is needed to start a project and advance it each shift. Learned technologies survive restructuring.',
                  style: TextStyle(color: TycoonPalette.muted, height: 1.5)),
              const SizedBox(height: 14),
              if (project != null) ...[
                _activeResearch(project, projectSpec!),
                const SizedBox(height: 14),
              ],
              if (!game.researchCanProgress) ...[
                _notice(
                    project == null
                        ? 'Hire an engineer to unlock research. Engineers also improve your field production.'
                        : 'Research is paused because no engineer is employed. Hire one to resume; your funding and completed shifts are kept.',
                    Icons.engineering_outlined,
                    TycoonPalette.orange),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    key: const Key('research-hire-engineer'),
                    onPressed: () async {
                      final role = EmployeeRole.engineer;
                      if (await _confirm(
                          'Hire an engineer?',
                          'Hiring costs ${tycoonMoney(game.employeeHiringCost(role))}. '
                              'An engineer earns ${tycoonMoney(game.employeeBaseSalary(role))} each shift, improves production, and advances research.',
                          'Hire engineer')) {
                        if (!mounted) return;
                        _act(game.hireEmployee(role));
                      }
                    },
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(
                        'Hire an engineer · ${tycoonMoney(game.employeeHiringCost(EmployeeRole.engineer))}',
                        textAlign: TextAlign.center)),
                const SizedBox(height: 14),
              ],
              ...TycoonCatalog.research.map((spec) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _researchCard(spec))),
            ]));
  }

  Widget _activeResearch(ResearchProject project, ResearchSpec spec) {
    final finished = project.totalShifts - project.remainingShifts;
    return TycoonPanel(
        key: const Key('active-research'),
        color: const Color(0xFFF2EEF8),
        borderColor: const Color(0xFFD9CDE8),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            TycoonTag(game.researchCanProgress ? 'RESEARCHING' : 'PAUSED',
                icon: game.researchCanProgress
                    ? Icons.science_outlined
                    : Icons.pause_rounded,
                color: game.researchCanProgress
                    ? const Color(0xFF7764A9)
                    : TycoonPalette.orange),
            TycoonTag('LEVEL ${project.targetLevel}',
                color: const Color(0xFF7764A9)),
          ]),
          const SizedBox(height: 12),
          Text(spec.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(spec.benefitAtLevel(project.targetLevel),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          LinearProgressIndicator(
              value: finished / project.totalShifts,
              semanticsLabel:
                  '${spec.name}: $finished of ${project.totalShifts} shifts completed',
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF7764A9)),
          const SizedBox(height: 10),
          Text(
              '$finished / ${project.totalShifts} shifts completed · ${project.remainingShifts} remaining',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          TextButton(
              key: const Key('cancel-research'),
              onPressed: () async {
                if (await _confirm(
                    'Cancel ${spec.name}?',
                    'The research funding will not be refunded and progress on this level will be lost. Previously completed technology levels remain yours.',
                    'Cancel research')) {
                  if (!mounted) return;
                  _act(game.cancelResearch());
                }
              },
              child: const Text('Cancel project')),
        ]));
  }

  Widget _researchCard(ResearchSpec spec) {
    final level = game.researchLevel(spec.id);
    final complete = level >= spec.maxLevel;
    final active = state.researchProject?.researchId == spec.id;
    return TycoonPanel(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
            key: PageStorageKey<String>('technology-${spec.id}'),
            leading: Icon(
                complete ? Icons.check_circle_outline : _researchIcon(spec.id),
                color: complete ? TycoonPalette.teal : const Color(0xFF7764A9)),
            title: Text(spec.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                'Level $level / ${spec.maxLevel}${active ? ' · Researching next level' : complete ? ' · Complete' : ''}'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(spec.description,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              _detailRow('Current benefit', spec.benefitAtLevel(level)),
              if (!complete) ...[
                _detailRow(
                    'At level ${level + 1}', spec.benefitAtLevel(level + 1),
                    color: TycoonPalette.teal),
                _detailRow('Research funding',
                    tycoonMoney(game.researchCost(spec.id))),
                _detailRow('Research time',
                    '${game.researchDuration(spec.id)} staffed shifts'),
                const SizedBox(height: 12),
                FilledButton.tonal(
                    key: Key('research-${spec.id}'),
                    onPressed: state.researchProject == null &&
                            game.researchCanProgress
                        ? () => _startResearch(spec)
                        : null,
                    child: Text(
                        active
                            ? 'Project in progress'
                            : state.researchProject != null
                                ? 'Finish your current project first'
                                : !game.researchCanProgress
                                    ? 'Engineer required'
                                    : 'Research level ${level + 1}',
                        textAlign: TextAlign.center)),
              ],
            ]));
  }

  Future<void> _startResearch(ResearchSpec spec) async {
    final next = game.researchLevel(spec.id) + 1;
    if (await _confirm(
        'Research ${spec.name} level $next?',
        'Fund this project for ${tycoonMoney(game.researchCost(spec.id))}. '
            'It takes ${game.researchDuration(spec.id)} shifts with an engineer employed. '
            '${spec.benefitAtLevel(next)}. '
            'Funding is spent immediately and is not refunded if you cancel.',
        'Fund research')) {
      if (!mounted) return;
      _act(game.startResearch(spec.id));
    }
  }

  IconData _researchIcon(String id) => switch (id) {
        'production' => Icons.precision_manufacturing_outlined,
        'logistics' => Icons.route_outlined,
        'storage' => Icons.storage_outlined,
        'maintenance' => Icons.build_outlined,
        'drilling' => Icons.cell_tower_outlined,
        'trading' => Icons.insights_outlined,
        _ => Icons.science_outlined,
      };

  Widget _employeeCard(Employee employee) {
    final assignment =
        state.leases.where((v) => v.employeeId == employee.id).firstOrNull;
    return TycoonPanel(
        padding: const EdgeInsets.all(15),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: _roleColor(employee.role).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13)),
                child: Center(
                    child: Text(
                        employee.name
                            .split(RegExp(r'\s+'))
                            .where((word) => word.isNotEmpty)
                            .map((word) => word[0])
                            .take(2)
                            .join(),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _roleColor(employee.role))))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(employee.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                      '${_roleName(employee.role)} · Level ${employee.level} · ${tycoonMoney(employee.salary)}/day',
                      style: Theme.of(context).textTheme.bodySmall)
                ])),
          ]),
          const SizedBox(height: 12),
          Text(
              assignment == null
                  ? (employee.role == EmployeeRole.operator
                      ? 'Ready for field assignment'
                      : 'Supporting company operations')
                  : 'Assigned to ${TycoonCatalog.lease(assignment.id).name}',
              style: const TextStyle(fontSize: 12, color: TycoonPalette.teal)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            OutlinedButton.icon(
                onPressed: employee.level >= 5
                    ? null
                    : () async {
                        if (await _confirm(
                            'Train ${employee.name}?',
                            'Training costs ${tycoonMoney(game.employeeTrainingCost(employee.id))}. Their skill rises to level ${employee.level + 1} and salary increases to ${tycoonMoney(employee.salary + 45)} per day.',
                            'Train employee')) {
                          _act(game.trainEmployee(employee.id));
                        }
                      },
                icon: const Icon(Icons.school_outlined, size: 17),
                label: Text(employee.level >= 5
                    ? 'Fully trained'
                    : 'Train ${tycoonMoney(game.employeeTrainingCost(employee.id))}')),
            TextButton(
                onPressed: () async {
                  if (await _confirm(
                      'Release ${employee.name}?',
                      'Their wages stop immediately. ${assignment == null ? 'Company capacity or support bonuses may decrease.' : '${TycoonCatalog.lease(assignment.id).name} will need a replacement operator.'}',
                      'Release employee')) {
                    _act(game.fireEmployee(employee.id));
                  }
                },
                child: const Text('Release')),
          ]),
        ]));
  }

  Widget _hireCard(EmployeeRole role) => TycoonPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _iconTile(_roleIcon(role), _roleColor(role)),
        const SizedBox(height: 12),
        Text(_roleName(role), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 7),
        Text(_roleDescription(role),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Text('${tycoonMoney(game.employeeBaseSalary(role))} daily wage',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: () async {
              if (await _confirm(
                  'Hire a ${_roleName(role).toLowerCase()}?',
                  'Recruitment costs ${tycoonMoney(game.employeeHiringCost(role))}. Daily wages begin at ${tycoonMoney(game.employeeBaseSalary(role))}. ${_roleDescription(role)}',
                  'Hire employee')) {
                _act(game.hireEmployee(role));
              }
            },
            child:
                Text('Hire · ${tycoonMoney(game.employeeHiringCost(role))}')),
      ]));

  Widget _businessCard(BusinessSpec spec) {
    final owned = state.businesses.where((v) => v.id == spec.id).firstOrNull;
    final icon = spec.id == 'refinery'
        ? Icons.factory_outlined
        : spec.id == 'logistics'
            ? Icons.local_shipping_outlined
            : Icons.home_repair_service_outlined;
    return TycoonPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TycoonAssetIllustration(
          path: _assets.business(spec.id), height: 160, fallbackIcon: icon),
      const SizedBox(height: 14),
      Row(children: [
        _iconTile(icon, TycoonPalette.orange),
        const SizedBox(width: 10),
        Expanded(
            child:
                Text(spec.name, style: Theme.of(context).textTheme.titleMedium))
      ]),
      const SizedBox(height: 12),
      Text(spec.description, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 14),
      TycoonTag(
          owned == null
              ? 'ACQUISITION OPPORTUNITY'
              : 'OWNED · LEVEL ${owned.level}',
          color: owned == null ? TycoonPalette.muted : TycoonPalette.teal),
      const SizedBox(height: 12),
      _detailRow('Daily gross income',
          tycoonMoney(spec.dailyIncome * (owned?.level ?? 1)),
          color: TycoonPalette.teal),
      _detailRow(
          'Daily upkeep', tycoonMoney(spec.upkeep * (owned?.level ?? 1))),
      const SizedBox(height: 13),
      if (owned == null)
        OutlinedButton(
            onPressed: () async {
              if (await _confirm(
                  'Acquire ${spec.name}?',
                  'Purchase price ${tycoonMoney(spec.price)}. Base daily gross income is ${tycoonMoney(spec.dailyIncome)}, with ${tycoonMoney(spec.upkeep)} upkeep. ${spec.description}',
                  'Acquire business')) {
                _act(game.buyBusiness(spec.id));
              }
            },
            child: Text('Acquire · ${tycoonMoney(spec.price)}'))
      else
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonal(
              onPressed: owned.level >= 3
                  ? null
                  : () async {
                      if (await _confirm(
                          'Expand ${spec.name}?',
                          'Upgrade to level ${owned.level + 1} for ${tycoonMoney(game.businessUpgradeCost(owned.id))}. Income, upkeep, and company benefits increase with each level.',
                          'Expand business')) {
                        _act(game.upgradeBusiness(owned.id));
                      }
                    },
              child: Text(owned.level >= 3
                  ? 'Fully expanded'
                  : 'Expand ${tycoonMoney(game.businessUpgradeCost(owned.id), compact: true)}')),
          TextButton(
              onPressed: () async {
                if (await _confirm(
                    'Sell ${spec.name}?',
                    'Receive ${tycoonMoney(game.businessSaleValue(owned.id))}. Its daily income and company bonuses end immediately.',
                    'Sell business')) {
                  _act(game.sellBusiness(owned.id));
                }
              },
              child: const Text('Sell business')),
        ]),
    ]));
  }

  Widget _finance() => TycoonPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _detailRow('Available cash', tycoonMoney(state.cash)),
        _detailRow('Total company value', tycoonMoney(game.netWorth)),
        _detailRow('Loan balance', tycoonMoney(state.debt),
            color: state.debt > 0 ? TycoonPalette.orange : null),
        _detailRow('New borrowing available', tycoonMoney(game.availableLoan)),
        _detailRow('Current daily interest', tycoonMoney(game.dailyInterest)),
        const Divider(),
        Text(
            'Loans charge ${(GameEngine.dailyLoanInterestRate * 100).toStringAsFixed(1)}% interest per game day. Borrow only what your production and business income can support.',
            style: TextStyle(
                color: TycoonPalette.muted, fontSize: 12, height: 1.5)),
        const SizedBox(height: 13),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
              onPressed: game.availableLoan <= 0
                  ? null
                  : () => _quantity(
                      title: 'Company loan',
                      label: 'Amount to borrow',
                      initial: math.min(25000, game.availableLoan),
                      maximum: game.availableLoan,
                      summary: (amount) =>
                          'Borrow ${tycoonMoney(amount)}. Loan balance becomes ${tycoonMoney(state.debt + amount)}. At ${(GameEngine.dailyLoanInterestRate * 100).toStringAsFixed(1)}% per day, total loan interest will be ${tycoonMoney(GameEngine.loanInterestFor(state.debt + amount))} each shift.',
                      action: game.borrow,
                      button: 'Borrow funds'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Borrow funds')),
          FilledButton.tonal(
              onPressed: state.debt == 0 || state.cash <= 0
                  ? null
                  : () => _quantity(
                      title: 'Repay company loan',
                      label: 'Repayment amount',
                      initial: math.min(state.debt, math.max(0, state.cash)),
                      maximum: math.min(state.debt, math.max(0, state.cash)),
                      summary: (amount) =>
                          'Repay ${tycoonMoney(amount)}. Keep enough cash for your next shift: ${tycoonMoney(game.dailyPayroll + game.dailyUpkeep + game.dailyInterest)} including interest.',
                      action: game.repayLoan,
                      button: 'Repay loan'),
              child: const Text('Repay loan')),
        ]),
      ]));

  Widget _objectiveCard(ObjectiveProgress objective) => TycoonPanel(
      padding: const EdgeInsets.all(14),
      color:
          objective.complete ? TycoonPalette.paleTeal : TycoonPalette.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
              objective.complete
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color:
                  objective.complete ? TycoonPalette.teal : TycoonPalette.gold,
              size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(objective.title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(objective.description,
                    style: Theme.of(context).textTheme.bodySmall)
              ]))
        ]),
        const SizedBox(height: 12),
        ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
                value: objective.target <= 0
                    ? 0
                    : (objective.current / objective.target).clamp(0, 1),
                minHeight: 5)),
        const SizedBox(height: 8),
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 5,
            children: [
              Text(
                  objective.complete
                      ? 'COMPLETE'
                      : '${tycoonNumber(math.min(objective.current, objective.target))} / ${tycoonNumber(objective.target)}',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: TycoonPalette.muted)),
              Text(
                  objective.complete
                      ? 'Reward received'
                      : '+${tycoonMoney(objective.reward)} reward',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: TycoonPalette.teal))
            ]),
      ]));

  Widget _insolvency() => TycoonPanel(
      color: const Color(0xFFFFEBDF),
      borderColor: const Color(0xFFEABBA7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Cash flow needs your attention',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: TycoonPalette.red)),
        const SizedBox(height: 8),
        const Text(
            'Sell inventory or surplus assets, or arrange financing. If you cannot recover, restructuring provides a fresh starter operation and clears debt.'),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: () async {
              if (await _confirm(
                  'Restructure the company?',
                  'Your current leases, assets, businesses, contracts, and employees are replaced by a starter operation. '
                      'Auction cash held (${tycoonMoney(game.auctionEscrow)}) is forfeited. Any active research is cancelled without a refund. '
                      'Debt is cleared. Learned technologies, career achievements, and the current day are preserved.',
                  'Restructure')) {
                _act(game.restructureCompany());
              }
            },
            child: const Text('Restructure company')),
      ]));

  Widget _notice(String message, IconData icon, Color color) => TycoonPanel(
      padding: const EdgeInsets.all(14),
      color: color.withValues(alpha: .07),
      borderColor: color.withValues(alpha: .20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 21, color: color),
        const SizedBox(width: 11),
        Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontSize: 12, height: 1.5)))
      ]));

  Widget _detailRow(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 270 &&
            MediaQuery.textScalerOf(context).scale(1) > 1.35) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: TycoonPalette.muted)),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color ?? TycoonPalette.ink))
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: TycoonPalette.muted))),
          const SizedBox(width: 10),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color ?? TycoonPalette.ink)))
        ]);
      }));

  Widget _iconTile(IconData icon, Color color, {bool small = false}) =>
      Container(
          width: small ? 35 : 43,
          height: small ? 35 : 43,
          decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(small ? 10 : 13)),
          child: Icon(icon, color: color, size: small ? 20 : 25));
  IconData _commodityIcon(Commodity commodity) => commodity == Commodity.oil
      ? Icons.water_drop_rounded
      : Icons.local_fire_department_rounded;
  String _commodityName(Commodity commodity) =>
      commodity == Commodity.oil ? 'Oil' : 'Gas';
  String _unit(Commodity commodity) =>
      commodity == Commodity.oil ? 'bbl' : 'Mcf';
  IconData _assetIcon(AssetSpec spec) => spec.category == 'storage'
      ? Icons.storage_rounded
      : spec.id == 'drill_rig'
          ? Icons.cell_tower_rounded
          : spec.id == 'service_truck'
              ? Icons.home_repair_service_rounded
              : spec.category == 'vehicle'
                  ? Icons.local_shipping_rounded
                  : spec.commodity == Commodity.gas
                      ? Icons.gas_meter_rounded
                      : Icons.precision_manufacturing_rounded;
  String _roleName(EmployeeRole role) => switch (role) {
        EmployeeRole.operator => 'Field operator',
        EmployeeRole.driver => 'Haul driver',
        EmployeeRole.engineer => 'Engineer',
        EmployeeRole.mechanic => 'Mechanic'
      };
  Color _roleColor(EmployeeRole role) => switch (role) {
        EmployeeRole.operator => TycoonPalette.orange,
        EmployeeRole.driver => TycoonPalette.teal,
        EmployeeRole.engineer => const Color(0xFF7764A9),
        EmployeeRole.mechanic => const Color(0xFF4C81A8)
      };
  IconData _roleIcon(EmployeeRole role) => switch (role) {
        EmployeeRole.operator => Icons.engineering_outlined,
        EmployeeRole.driver => Icons.local_shipping_outlined,
        EmployeeRole.engineer => Icons.architecture_rounded,
        EmployeeRole.mechanic => Icons.build_outlined
      };
  String _roleDescription(EmployeeRole role) => switch (role) {
        EmployeeRole.operator =>
          'Assign to one developed oil or gas well to run production.',
        EmployeeRole.driver =>
          'Staff haul fleets to move oil and gas from your fields.',
        EmployeeRole.engineer =>
          'Improve field output and advance your research projects.',
        EmployeeRole.mechanic =>
          'Reduce equipment wear and improve maintenance efficiency.'
      };
}

class _PricePainter extends CustomPainter {
  _PricePainter(this.values, this.color);
  final List<double> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = TycoonPalette.line
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4),
          Offset(size.width, size.height * i / 4), grid);
    }
    if (values.isEmpty) return;
    final min = values.reduce(math.min), max = values.reduce(math.max);
    final range = math.max(2.0, max - min);
    final path = Path();
    final points = <Offset>[];
    if (values.length == 1) {
      points.addAll(
          [Offset(0, size.height * .5), Offset(size.width, size.height * .5)]);
    } else {
      for (var i = 0; i < values.length; i++) {
        points.add(Offset(
            size.width * i / (values.length - 1),
            size.height -
                10 -
                (values[i] - min + (range - (max - min)) / 2) /
                    range *
                    (size.height - 20)));
      }
    }
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: .19),
                color.withValues(alpha: 0)
              ]).createShader(Offset.zero & size));
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(points.last, 4, Paint()..color = color);
    canvas.drawCircle(points.last, 2, Paint()..color = TycoonPalette.surface);
  }

  @override
  bool shouldRepaint(covariant _PricePainter old) =>
      old.color != color ||
      old.values.length != values.length ||
      old.values
          .asMap()
          .entries
          .any((entry) => entry.value != values[entry.key]);
}
