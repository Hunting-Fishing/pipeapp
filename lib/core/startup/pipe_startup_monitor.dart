import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/public_release_config.dart';
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
            seedColor: const Color(0xFF0878E8),
            brightness: Brightness.dark,
          ),
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
            backgroundColor: const Color(0xFF061D49),
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _VersionBadge(
                      label: PublicReleaseConfiguration.formattedReleaseLabel,
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 76, 24, 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/pipe_buyer_logo.png',
                              width: 190,
                              height: 150,
                              fit: BoxFit.contain,
                              semanticLabel: 'Pipe Buyer',
                            ),
                            const SizedBox(height: 20),
                            Text(
                              failed
                                  ? 'Pipe Buyer could not start'
                                  : 'Starting Pipe Buyer',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              failed
                                  ? 'Your information has not been changed. '
                                      'Close and reopen the app, then try again.'
                                  : monitor.stageLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 15,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _ProgressCard(monitor: monitor),
                            if (monitor.isDelayed && !failed) ...[
                              const SizedBox(height: 12),
                              _DelayedStageNotice(stage: monitor.stageLabel),
                            ],
                            const SizedBox(height: 10),
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
                                foregroundColor: const Color(0xFF93C5FD),
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

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC03142F),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x6648A8FF)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x3DFFFFFF)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      monitor.state == PipeStartupState.failed
                          ? 'Stopped at ${monitor.stageLabel}'
                          : monitor.stageLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${monitor.progressPercent}%',
                    style: TextStyle(
                      color: monitor.state == PipeStartupState.failed
                          ? const Color(0xFFFFB4AB)
                          : const Color(0xFF55D9FF),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: monitor.progress,
                  minHeight: 10,
                  color: monitor.state == PipeStartupState.failed
                      ? const Color(0xFFFF5449)
                      : const Color(0xFF21C7E8),
                  backgroundColor: const Color(0xFF243B64),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Stage ${monitor.history.length + 1}',
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                  const Spacer(),
                  Text(
                    'Elapsed ${_durationLabel(monitor.elapsed)}',
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
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
          color: const Color(0x26FFB020),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x99FFB020)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_outlined, color: Color(0xFFFFC55C)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$stage is taking longer than expected. The watchdog has '
                'recorded this stage for diagnosis.',
                style: const TextStyle(
                  color: Color(0xFFFFE2A8),
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
          color: const Color(0xCC03142F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x3348A8FF)),
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
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
            if (monitor.history.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...monitor.history.reversed.take(5).map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${record.progressPercent}%  ${record.label}  '
                        '${record.duration.inMilliseconds} ms',
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 12,
                        ),
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
                foregroundColor: const Color(0xFF93C5FD),
                side: const BorderSide(color: Color(0x6648A8FF)),
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
