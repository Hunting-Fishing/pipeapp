import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'licenses.dart';
import 'save_store.dart';
import 'tycoon_engine.dart';
import 'ui/oil_field_scene.dart';
import 'ui/tycoon_game_page.dart';
import 'ui/tycoon_theme.dart';

class OilGasTycoonApp extends StatelessWidget {
  const OilGasTycoonApp({super.key, this.saveStore, this.initialEngine});

  final TycoonSaveStore? saveStore;
  final GameEngine? initialEngine;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Oil & Gas Tycoon',
        debugShowCheckedModeBanner: false,
        theme: TycoonPalette.theme,
        home: OilGasTycoonScreen(
          saveStore: saveStore,
          initialEngine: initialEngine,
        ),
      );
}

/// Embeddable screen used by Pipe Buyer's /tycoon route and the standalone app.
/// This entrypoint has no Firebase, payment, auth, or server dependency.
class OilGasTycoonScreen extends StatefulWidget {
  const OilGasTycoonScreen({
    super.key,
    this.onExit,
    this.saveStore,
    this.initialEngine,
  });

  final VoidCallback? onExit;
  final TycoonSaveStore? saveStore;
  final GameEngine? initialEngine;

  @override
  State<OilGasTycoonScreen> createState() => _OilGasTycoonScreenState();
}

class _OilGasTycoonScreenState extends State<OilGasTycoonScreen>
    with WidgetsBindingObserver {
  TycoonSaveStore? _store;
  GameEngine? _engine;
  bool _loading = true;
  bool _restoring = false;
  bool _leaving = false;
  bool _allowPop = false;
  String? _warning;
  String? _loadError;
  int _session = 0;
  int _saveRequest = 0;

  @override
  void initState() {
    super.initState();
    registerTycoonLicenses();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _engine != null) {
      unawaited(_save());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final store = widget.saveStore ??
          TycoonSaveStore(await PreferencesSaveStorage.open());
      final saved = await store.load();
      if (!mounted) return;
      setState(() {
        _store = store;
        _engine = widget.initialEngine ??
            (saved.state == null ? null : GameEngine(saved.state!));
        _warning = saved.warning;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Device storage is unavailable. Retry to restore your '
            'company, or play a temporary session and export a backup.';
      });
    }
  }

  Future<bool> _save() async {
    if (_restoring) return false;
    final engine = _engine;
    final store = _store;
    if (engine == null) return true;
    if (store == null) return false;
    final request = ++_saveRequest;
    try {
      await store.save(engine.state);
      if (mounted && request == _saveRequest && _warning != null) {
        setState(() => _warning = null);
      }
      return true;
    } on Object {
      if (mounted && request == _saveRequest) {
        setState(() => _warning = 'This change could not be saved to your '
            'device. Use Export backup in Settings before closing the game.');
      }
      return false;
    }
  }

  void _changed() {
    unawaited(_save());
  }

  Future<void> _start(String companyName) async {
    final engine = GameEngine.newGame(companyName: companyName);
    setState(() {
      _engine = engine;
      _session++;
    });
    await _save();
  }

  Future<void> _leave() async {
    if (_restoring || _leaving) return;
    _leaving = true;
    try {
      final saved = await _save();
      if (!mounted) return;
      if (!saved) {
        final decision = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Your latest changes are not saved'),
            content: const Text('Device storage could not save this company. '
                'Export a backup before leaving to keep your progress.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'stay'),
                child: const Text('Keep playing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'leave'),
                child: const Text('Leave anyway'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'export'),
                child: const Text('Export backup'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (decision == 'export') await _export();
        if (decision != 'leave') return;
      }
      if (mounted) {
        setState(() => _allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) widget.onExit?.call();
      }
    } finally {
      _leaving = false;
    }
  }

  Future<void> _reset() async {
    final companyName = await showDialog<String>(
      context: context,
      builder: (_) => const _NewCompanyDialog(),
    );
    if (!mounted || companyName == null) return;
    await _start(companyName);
  }

  Future<void> _export() async {
    final engine = _engine;
    if (engine == null) return;
    final source = TycoonSaveStore.encode(engine.state);
    await showDialog<void>(
      context: context,
      builder: (_) => _BackupExportDialog(source: source),
    );
  }

  Future<void> _import() async {
    final state = await showDialog<GameState>(
      context: context,
      builder: (_) => const _BackupImportDialog(),
    );
    if (!mounted || state == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this company?'),
        content: Text(
          '${state.companyName} · Day ${state.day}'
          '\n\nThis will replace the company saved on this device. '
          'Your previous save is kept as the recovery copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore company'),
          ),
        ],
      ),
    );
    if (!mounted || approved != true) return;
    setState(() {
      _restoring = true;
      _saveRequest++;
    });
    try {
      final store = _store;
      if (store != null) await store.save(state);
      if (!mounted) return;
      setState(() {
        _engine = GameEngine(state);
        _session++;
        _warning = store == null
            ? 'Temporary session: export a backup before closing the game.'
            : null;
      });
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('The backup is valid, but storage could not save it. '
            'Your current company is still open.'),
      ));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Widget _restoreGuard(Widget child) => PopScope(
        canPop: !_restoring && (widget.onExit == null || _allowPop),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !_restoring && widget.onExit != null) {
            unawaited(_leave());
          }
        },
        child: Stack(children: [
          ExcludeFocus(
            excluding: _restoring,
            child: AbsorbPointer(absorbing: _restoring, child: child),
          ),
          if (_restoring)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xCCF4F1E9),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 18),
                    Text('Restoring your company…'),
                  ]),
                ),
              ),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) => Theme(
        data: TycoonPalette.theme,
        child: Builder(builder: (context) {
          if (_loading) {
            return const Scaffold(
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Opening your company…'),
                ]),
              ),
            );
          }
          if (_loadError != null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Oil & Gas Tycoon')),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.save_outlined, size: 48),
                      const SizedBox(height: 20),
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry saved game'),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _loadError = null;
                          _warning = 'Temporary session: device saving is '
                              'unavailable. Export a backup before closing.';
                        }),
                        child: const Text('Play a temporary session'),
                      ),
                      if (widget.onExit != null)
                        TextButton(
                          onPressed: widget.onExit,
                          child: const Text('Back to Pipe Buyer'),
                        ),
                    ]),
                  ),
                ),
              ),
            );
          }
          final engine = _engine;
          if (engine == null) {
            return _restoreGuard(_CompanyWelcome(
              onStart: _start,
              onImport: _import,
              onExit: widget.onExit,
              warning: _warning,
            ));
          }
          return _restoreGuard(TycoonGamePage(
            key: ValueKey(_session),
            engine: engine,
            onChanged: _changed,
            onExit: widget.onExit == null ? null : () => unawaited(_leave()),
            onReset: _reset,
            onExport: _export,
            onImport: _import,
            saveWarning: _warning,
          ));
        }),
      );
}

class _CompanyWelcome extends StatefulWidget {
  const _CompanyWelcome({
    required this.onStart,
    required this.onImport,
    this.onExit,
    this.warning,
  });

  final Future<void> Function(String) onStart;
  final Future<void> Function() onImport;
  final VoidCallback? onExit;
  final String? warning;

  @override
  State<_CompanyWelcome> createState() => _CompanyWelcomeState();
}

class _CompanyWelcomeState extends State<_CompanyWelcome> {
  final _name = TextEditingController(text: 'Frontier Energy');
  final _form = GlobalKey<FormState>();
  bool _starting = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting || !_form.currentState!.validate()) return;
    setState(() => _starting = true);
    await widget.onStart(_name.text.trim());
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.onExit == null
            ? null
            : AppBar(
                leading: IconButton(
                  tooltip: 'Back to Pipe Buyer',
                  onPressed: widget.onExit,
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 800;
                  final intro = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TycoonTag('BUILD YOUR ENERGY EMPIRE',
                          icon: Icons.bolt_rounded),
                      const SizedBox(height: 20),
                      Text('Oil & Gas\nTycoon',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall!
                              .copyWith(
                                  fontSize: wide ? 56 : 42, height: 1.05)),
                      const SizedBox(height: 18),
                      Text('Start with one field.\nThink like an empire.',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      const Text('Produce oil and gas, make your next trade, '
                          'and put your crew to work. Every shift is a new '
                          'chance to grow.'),
                      const SizedBox(height: 24),
                      const OilFieldScene(compact: true),
                    ],
                  );
                  final form = Form(
                    key: _form,
                    child: TycoonPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Your company starts here',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          const Text('Your starter lease, pump, truck and crew '
                              'are ready. Run a shift to produce your first '
                              'oil, then sell it at the Exchange.'),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _name,
                            maxLength: 32,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.go,
                            decoration: const InputDecoration(
                              labelText: 'Company name',
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                            validator: _validateCompanyName,
                            onFieldSubmitted: (_) => _start(),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _starting ? null : _start,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(_starting
                                ? 'Opening your company…'
                                : 'Start my company'),
                          ),
                          const SizedBox(height: 14),
                          TextButton.icon(
                            onPressed: widget.onImport,
                            icon: const Icon(Icons.restore_rounded),
                            label: const Text('Restore a backup'),
                          ),
                          if (widget.warning != null) ...[
                            const SizedBox(height: 14),
                            Text(widget.warning!,
                                style:
                                    const TextStyle(color: TycoonPalette.red)),
                          ],
                          const Divider(height: 32),
                          const Text('SINGLE PLAYER · PLAY OFFLINE',
                              style: TextStyle(
                                  color: TycoonPalette.teal,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 8),
                          const Text(
                              'All money, prices, companies and leases '
                              'are fictional. Progress stays on this device; '
                              'export a backup to move your company.',
                              style: TextStyle(
                                  color: TycoonPalette.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: intro),
                        const SizedBox(width: 48),
                        Expanded(child: form),
                      ],
                    );
                  }
                  return Column(children: [
                    intro,
                    const SizedBox(height: 24),
                    form,
                  ]);
                }),
              ),
            ),
          ),
        ),
      );
}

String? _validateCompanyName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Enter a company name.';
  if (name.length > 32) return 'Use 32 characters or fewer.';
  if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
    return 'Use a single line for the company name.';
  }
  return null;
}

class _NewCompanyDialog extends StatefulWidget {
  const _NewCompanyDialog();
  @override
  State<_NewCompanyDialog> createState() => _NewCompanyDialogState();
}

class _NewCompanyDialogState extends State<_NewCompanyDialog> {
  final _controller = TextEditingController(text: 'Frontier Energy');
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Start a new company?'),
        content: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('This replaces your current company. Export a backup '
                  'first if you want to return to it later.'),
              const SizedBox(height: 20),
              TextFormField(
                controller: _controller,
                maxLength: 32,
                decoration:
                    const InputDecoration(labelText: 'New company name'),
                validator: _validateCompanyName,
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep playing')),
          FilledButton(
            onPressed: () {
              if (_form.currentState!.validate()) {
                Navigator.pop(context, _controller.text.trim());
              }
            },
            child: const Text('Start new company'),
          ),
        ],
      );
}

class _BackupExportDialog extends StatefulWidget {
  const _BackupExportDialog({required this.source});
  final String source;
  @override
  State<_BackupExportDialog> createState() => _BackupExportDialogState();
}

class _BackupExportDialogState extends State<_BackupExportDialog> {
  String? _message;

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.source));
      if (mounted) {
        setState(() => _message = 'Copied. Keep it in a text file or note.');
      }
    } on Object {
      if (mounted) {
        setState(() => _message = 'Select and copy the backup below.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Export company backup'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Copy this backup into a text file or a private note. '
                  'Use Restore backup on another device to continue this company.'),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: SelectableText(widget.source,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 10)),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(_message!,
                    style: const TextStyle(color: TycoonPalette.teal)),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          FilledButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy backup')),
        ],
      );
}

class _BackupImportDialog extends StatefulWidget {
  const _BackupImportDialog();
  @override
  State<_BackupImportDialog> createState() => _BackupImportDialogState();
}

class _BackupImportDialogState extends State<_BackupImportDialog> {
  final _source = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  void _validate() {
    try {
      final game = TycoonSaveStore.decode(_source.text.trim());
      Navigator.pop(context, game);
    } on Object {
      setState(() => _error = 'That backup could not be restored. Paste the '
          'complete Oil & Gas Tycoon backup from Export backup. '
          'Your current company has not changed.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Restore a company backup'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Paste the complete backup text. You will review the '
                  'company before replacing your current progress.'),
              const SizedBox(height: 18),
              TextField(
                controller: _source,
                minLines: 5,
                maxLines: 9,
                maxLength: TycoonSaveStore.maximumSaveBytes,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Backup text',
                  alignLabelWithHint: true,
                  counterText: '',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: TycoonPalette.red)),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _validate, child: const Text('Review backup')),
        ],
      );
}
