import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/public_release_config.dart';
import '../design/pipe_buyer_theme.dart';
import '../diagnostics/app_diagnostics.dart';

enum PipeStartupState { running, complete, failed }

@immutable
class PipeStartupStageRecord {
  const PipeStartupStageRecord({
    required this.id,
    required this.label,
    required this.progressPercent,
    required this.elapsed,
    required this.duration,
    required this.status,
  });

  final String id;
  final String label;
  final int progressPercent;
  final Duration elapsed;
  final Duration duration;
  final String status;
}

/// Tracks startup milestones without collecting account or marketplace data.
///
/// Progress is milestone-driven and monotonic. The watchdog reports a delayed
/// stage after eight seconds so startup problems can be isolated in logs.
class PipeStartupMonitor extends ChangeNotifier {
  PipeStartupMonitor({
    this.slowStageThreshold = const Duration(seconds: 8),
    this.tickInterval = const Duration(seconds: 1),
  }) {
    _totalStopwatch.start();
    _stageStopwatch.start();
    _ticker = Timer.periodic(tickInterval, (_) => _onTick());
    AppDiagnostics.recordStartupEvent(
      stage: _stageId,
      label: _stageLabel,
      status: 'started',
      progressPercent: progressPercent,
      elapsed: elapsed,
    );
  }

  final Duration slowStageThreshold;
  final Duration tickInterval;
  final Stopwatch _totalStopwatch = Stopwatch();
  final Stopwatch _stageStopwatch = Stopwatch();
  final List<PipeStartupStageRecord> _history = [];

  Timer? _ticker;
  PipeStartupState _state = PipeStartupState.running;
  String _stageId = 'flutter_startup';
  String _stageLabel = 'Starting application services';
  double _progress = .32;
  bool _currentStageDelayed = false;
  Object? _failure;

  PipeStartupState get state => _state;
  String get stageId => _stageId;
  String get stageLabel => _stageLabel;
  double get progress => _progress;
  int get progressPercent => (_progress * 100).round().clamp(0, 100);
  Duration get elapsed => _totalStopwatch.elapsed;
  Duration get currentStageElapsed => _stageStopwatch.elapsed;
  bool get isDelayed => _currentStageDelayed;
  Object? get failure => _failure;
  List<PipeStartupStageRecord> get history => List.unmodifiable(_history);

  void startStage({
    required String id,
    required String label,
    required double progress,
  }) {
    if (_state != PipeStartupState.running) return;
    final normalizedProgress = progress.clamp(0.0, 1.0);
    if (normalizedProgress < _progress) {
      throw ArgumentError.value(
        progress,
        'progress',
        'Startup progress must not move backwards.',
      );
    }

    _finishCurrentStage(status: 'completed');
    _stageId = id;
    _stageLabel = label;
    _progress = normalizedProgress;
    _currentStageDelayed = false;
    _stageStopwatch
      ..reset()
      ..start();
    AppDiagnostics.recordStartupEvent(
      stage: id,
      label: label,
      status: 'started',
      progressPercent: progressPercent,
      elapsed: elapsed,
    );
    notifyListeners();
  }

  void complete() {
    if (_state != PipeStartupState.running) return;
    _progress = 1;
    _finishCurrentStage(status: 'completed');
    _state = PipeStartupState.complete;
    _totalStopwatch.stop();
    _ticker?.cancel();
    AppDiagnostics.recordStartupEvent(
      stage: 'application_ready',
      label: 'Application ready',
      status: 'completed',
      progressPercent: 100,
      elapsed: elapsed,
    );
    notifyListeners();
  }

  void fail(Object error) {
    if (_state != PipeStartupState.running) return;
    _failure = error;
    _finishCurrentStage(status: 'failed');
    _state = PipeStartupState.failed;
    _totalStopwatch.stop();
    _ticker?.cancel();
    AppDiagnostics.recordStartupEvent(
      stage: _stageId,
      label: _stageLabel,
      status: 'failed',
      progressPercent: progressPercent,
      elapsed: elapsed,
      stageElapsed: currentStageElapsed,
      error: error,
    );
    notifyListeners();
  }

  String get diagnosticSummary {
    final buffer = StringBuffer()
      ..writeln('Pipe Buyer startup diagnostics')
      ..writeln(PublicReleaseConfiguration.formattedReleaseLabel)
      ..writeln('State: ${_state.name}')
      ..writeln('Current stage: $_stageId ($_stageLabel)')
      ..writeln('Progress: $progressPercent%')
      ..writeln('Elapsed: ${elapsed.inMilliseconds} ms');
    for (final record in _history) {
      buffer.writeln(
        '${record.progressPercent}% ${record.id}: ${record.status} '
        '(${record.duration.inMilliseconds} ms)',
      );
    }
    if (_failure != null) {
      buffer.writeln('Failure type: ${_failure.runtimeType}');
    }
    return buffer.toString().trimRight();
  }

  void _onTick() {
    if (_state != PipeStartupState.running) return;
    if (!_currentStageDelayed && currentStageElapsed >= slowStageThreshold) {
      _currentStageDelayed = true;
      AppDiagnostics.recordStartupEvent(
        stage: _stageId,
        label: _stageLabel,
        status: 'delayed',
        progressPercent: progressPercent,
        elapsed: elapsed,
        stageElapsed: currentStageElapsed,
      );
    }
    notifyListeners();
  }

  void _finishCurrentStage({required String status}) {
    _stageStopwatch.stop();
    final record = PipeStartupStageRecord(
      id: _stageId,
      label: _stageLabel,
      progressPercent: progressPercent,
      elapsed: elapsed,
      duration: _stageStopwatch.elapsed,
      status: status,
    );
    _history.add(record);
    AppDiagnostics.recordStartupEvent(
      stage: record.id,
      label: record.label,
      status: record.status,
      progressPercent: record.progressPercent,
      elapsed: record.elapsed,
      stageElapsed: record.duration,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

class PipeStartupMonitorApp extends StatelessWidget {
  const PipeStartupMonitorApp({
    super.key,
    required this.monitor,
  });

  final PipeStartupMonitor monitor;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pipe Buyer startup',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: PipeBuyerColors.orange,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: PipeBuyerColors.ink,
          useMaterial3: true,
        ),
        home: _PipeStartupScreen(monitor: monitor),
      );
}

class _PipeStartupScreen extends StatefulWidget {
  const _PipeStartupScreen({required this.monitor});

  final PipeStartupMonitor monitor;

  @override
  State<_PipeStartupScreen> createState() => _PipeStartupScreenState();
}

class _PipeStartupScreenState extends State<_PipeStartupScreen> {
  bool _showDetails = false;
  bool _copied = false;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.monitor,
        builder: (context, _) {
          final monitor = widget.monitor;
          final failed = monitor.state == PipeStartupState.failed;
          return Scaffold(
            backgroundColor: PipeBuyerColors.ink,
            body: SafeArea(
              child: Stack(
                children: [
                  const Positioned.fill(child: _StartupBackdrop()),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _VersionBadge(
                      label: PublicReleaseConfiguration.formattedReleaseLabel,
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 70, 22, 30),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 206,
                              height: 126,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: PipeBuyerColors.orange
                                      .withValues(alpha: .38),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 30,
                                    offset: Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/pipe_buyer_logo.png',
                                fit: BoxFit.contain,
                                semanticLabel: 'Pipe Buyer',
                              ),
                            ),
                            const SizedBox(height: 22),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: PipeBuyerColors.orange
                                    .withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: PipeBuyerColors.orange
                                      .withValues(alpha: .30),
                                ),
                              ),
                              child: const Text(
                                'INDUSTRIAL MARKETPLACE • DISPATCH • AUCTIONS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: PipeBuyerColors.orange,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .75,
                                ),
                              ),
                            ),
                            const SizedBox(height: 13),
                            Text(
                              failed
                                  ? 'Pipe Buyer could not start'
                                  : 'Preparing Pipe Buyer',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.3,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              failed
                                  ? 'Your information has not been changed. Close and reopen the app, then try again.'
                                  : monitor.stageLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFB8C1CC),
                                fontSize: 14.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _ProgressCard(monitor: monitor),
                            if (monitor.isDelayed && !failed) ...[
                              const SizedBox(height: 12),
                              _DelayedStageNotice(stage: monitor.stageLabel),
                            ],
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => setState(
                                () => _showDetails = !_showDetails,
                              ),
                              icon: Icon(
                                _showDetails
                                    ? Icons.expand_less
                                    : Icons.monitor_heart_outlined,
                              ),
                              label: Text(
                                _showDetails
                                    ? 'Hide startup details'
                                    : 'Startup details',
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                              ),
                            ),
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 180),
                              crossFadeState: _showDetails
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              firstChild: const SizedBox.shrink(),
                              secondChild: _StartupDetails(
                                monitor: monitor,
                                copied: _copied,
                                onCopy: _copyDiagnostics,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Future<void> _copyDiagnostics() async {
    await Clipboard.setData(
      ClipboardData(text: widget.monitor.diagnosticSummary),
    );
    if (!mounted) return;
    setState(() => _copied = true);
  }
}

class _StartupBackdrop extends StatelessWidget {
  const _StartupBackdrop();

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B0E12),
                  PipeBuyerColors.ink,
                  Color(0xFF171B20),
                ],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Positioned(
            right: -110,
            top: -90,
            child: Container(
              width: 330,
              height: 330,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PipeBuyerColors.orange.withValues(alpha: .055),
              ),
            ),
          ),
          Positioned(
            left: -90,
            bottom: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .025),
                  width: 28,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _IndustrialGridPainter()),
            ),
          ),
        ],
      );
}

class _IndustrialGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .018)
      ..strokeWidth = 1;
    const spacing = 48.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xD911151A),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: PipeBuyerColors.orange.withValues(alpha: .28),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.monitor});

  final PipeStartupMonitor monitor;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Application startup progress',
        value: '${monitor.progressPercent} percent',
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(17, 16, 17, 15),
          decoration: BoxDecoration(
            color: const Color(0xD9181D23),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0x26FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (monitor.state == PipeStartupState.failed
                              ? PipeBuyerColors.danger
                              : PipeBuyerColors.orange)
                          .withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      monitor.state == PipeStartupState.failed
                          ? Icons.error_outline
                          : Icons.settings_suggest_outlined,
                      color: monitor.state == PipeStartupState.failed
                          ? PipeBuyerColors.danger
                          : PipeBuyerColors.orange,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      monitor.state == PipeStartupState.failed
                          ? 'Stopped at ${monitor.stageLabel}'
                          : monitor.stageLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${monitor.progressPercent}%',
                    style: TextStyle(
                      color: monitor.state == PipeStartupState.failed
                          ? const Color(0xFFFFB4AB)
                          : PipeBuyerColors.orange,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _IndustrialTransportProgress(
                progress: monitor.progress,
                failed: monitor.state == PipeStartupState.failed,
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Text(
                    'Stage ${monitor.history.length + 1}',
                    style: const TextStyle(
                      color: Color(0xFF8D98A5),
                      fontSize: 11.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Elapsed ${_durationLabel(monitor.elapsed)}',
                    style: const TextStyle(
                      color: Color(0xFF8D98A5),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _IndustrialTransportProgress extends StatelessWidget {
  const _IndustrialTransportProgress({
    required this.progress,
    required this.failed,
  });

  final double progress;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    final accent = failed ? PipeBuyerColors.danger : PipeBuyerColors.orange;
    return SizedBox(
      height: 47,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF30363D),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment(-1 + (2 * value), -.12),
            child: Transform.translate(
              offset: Offset(value < .08 ? 17 : value > .92 ? -17 : 0, 0),
              child: _PipeHaulTruck(accent: accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _PipeHaulTruck extends StatelessWidget {
  const _PipeHaulTruck({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        width: 58,
        height: 34,
        padding: const EdgeInsets.fromLTRB(5, 3, 3, 2),
        decoration: BoxDecoration(
          color: const Color(0xFF11161C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: .52)),
          boxShadow: const [
            BoxShadow(color: Color(0x44000000), blurRadius: 6),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 2,
              top: 3,
              child: Column(
                children: List.generate(
                  3,
                  (_) => Container(
                    width: 29,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8C0C8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 1,
              child: Icon(
                Icons.local_shipping_rounded,
                color: accent,
                size: 28,
              ),
            ),
          ],
        ),
      );
}

class _DelayedStageNotice extends StatelessWidget {
  const _DelayedStageNotice({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PipeBuyerColors.warning.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: PipeBuyerColors.warning.withValues(alpha: .45),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.schedule_outlined,
              color: PipeBuyerColors.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$stage is taking longer than expected. The watchdog has recorded this stage for diagnosis.',
                style: const TextStyle(
                  color: Color(0xFFFFDEA0),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
}

class _StartupDetails extends StatelessWidget {
  const _StartupDetails({
    required this.monitor,
    required this.copied,
    required this.onCopy,
  });

  final PipeStartupMonitor monitor;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xE511151A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PipeBuyerColors.orange.withValues(alpha: .16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current: ${monitor.stageId}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Stage time ${_durationLabel(monitor.currentStageElapsed)} • '
              '${monitor.history.length} completed',
              style: const TextStyle(color: Color(0xFF8D98A5)),
            ),
            if (monitor.history.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...monitor.history.reversed.take(5).map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: record.status == 'failed'
                                  ? PipeBuyerColors.danger
                                  : PipeBuyerColors.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${record.progressPercent}%  ${record.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFC4CBD3),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            '${record.duration.inMilliseconds} ms',
                            style: const TextStyle(
                              color: Color(0xFF7F8995),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            if (monitor.failure != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PipeBuyerColors.danger.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: PipeBuyerColors.danger.withValues(alpha: .45),
                  ),
                ),
                child: Text(
                  'Diagnostic type: ${monitor.failure.runtimeType}',
                  style: const TextStyle(
                    color: Color(0xFFFFB4AB),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onCopy,
              icon: Icon(copied ? Icons.check : Icons.copy_outlined),
              label: Text(copied ? 'Diagnostics copied' : 'Copy diagnostics'),
              style: OutlinedButton.styleFrom(
                foregroundColor: PipeBuyerColors.orange,
                side: BorderSide(
                  color: PipeBuyerColors.orange.withValues(alpha: .35),
                ),
              ),
            ),
          ],
        ),
      );
}

String _durationLabel(Duration duration) {
  if (duration.inSeconds < 1) return '${duration.inMilliseconds} ms';
  return '${duration.inSeconds}s';
}
