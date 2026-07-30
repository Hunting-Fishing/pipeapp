import 'dart:async';

import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'auth/firebase_auth/auth_util.dart';

import 'backend/firebase/firebase_config.dart';
import 'core/accessibility/pipe_accessibility_theme.dart';
import 'core/accessibility/pipe_status_feedback.dart';
import 'core/config/public_release_config.dart';
import 'core/diagnostics/app_diagnostics.dart';
import 'core/startup/pipe_startup_monitor.dart';
import 'marketplace/marketplace_notification_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/internationalization.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppDiagnostics.install();
  final startupMonitor = PipeStartupMonitor();
  runApp(PipeStartupMonitorApp(monitor: startupMonitor));
  AppDiagnostics.run(() => _bootstrapPipeBuyer(startupMonitor));
}

Future<void> _bootstrapPipeBuyer(PipeStartupMonitor startupMonitor) async {
  try {
    final appState = await _initializePipeBuyer(startupMonitor);
    startupMonitor.startStage(
      id: 'first_frame',
      label: 'Preparing the marketplace',
      progress: .99,
    );
    startupMonitor.complete();
    // Allow the completed 100% milestone to render once before replacing the
    // startup monitor with the marketplace application.
    await WidgetsBinding.instance.endOfFrame;
    runApp(ChangeNotifierProvider(
      create: (context) => appState,
      child: const MyApp(),
    ));
  } catch (error, stackTrace) {
    AppDiagnostics.record(
      error,
      stackTrace,
      subsystem: 'startup',
      operation: 'initialize_application',
      fatal: true,
    );
    startupMonitor.fail(error);
  }
}

Future<FFAppState> _initializePipeBuyer(
  PipeStartupMonitor startupMonitor,
) async {
  startupMonitor.startStage(
    id: 'release_configuration',
    label: 'Validating release configuration',
    progress: .36,
  );
  PublicReleaseConfiguration.current.validate();
  startupMonitor.startStage(
    id: 'runtime_guards',
    label: 'Installing navigation and safety controls',
    progress: .40,
  );
  ErrorWidget.builder = (details) => Builder(
        builder: (context) => Material(
          color: Theme.of(context).colorScheme.surface,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: PipeStatusSurface(
                  tone: PipeStatusTone.error,
                  icon: Icons.sync_problem_outlined,
                  title: 'This section could not be displayed',
                  message: kDebugMode
                      ? 'Your information is still saved. Refresh this page or try again in a moment. ${details.exceptionAsString().split('\n').first}'
                      : 'Your information is still saved. Refresh this page or try again in a moment.',
                ),
              ),
            ),
          ),
        ),
      );
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  await initFirebase(
    onCoreInitialized: AppDiagnostics.initializeRemoteReporting,
    onStartupProgress: (stageId, label, progress) => startupMonitor.startStage(
      id: stageId,
      label: label,
      progress: progress,
    ),
  );

  startupMonitor.startStage(
    id: 'theme',
    label: 'Loading display preferences',
    progress: .84,
  );
  await FlutterFlowTheme.initialize();

  startupMonitor.startStage(
    id: 'localization',
    label: 'Loading language resources',
    progress: .90,
  );
  await FFLocalizations.initialize();

  startupMonitor.startStage(
    id: 'persisted_state',
    label: 'Restoring your saved preferences',
    progress: .95,
  );
  final appState = FFAppState(); // Initialize FFAppState
  await appState.initializePersistedState();
  return appState;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  State<MyApp> createState() => MyAppState();

  static MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class MyAppState extends State<MyApp> {
  Locale? _locale = FFLocalizations.getStoredLocale();

  ThemeMode _themeMode = FlutterFlowTheme.themeMode;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.path;
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  late Stream<BaseAuthUser> userStream;

  final authUserSub = authenticatedUserStream.listen((_) {});

  @override
  void initState() {
    super.initState();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    unawaited(MarketplaceNotificationService.instance.initializeNavigation());
    userStream = pipeAppFirebaseUserStream()
      ..listen((user) {
        _appStateNotifier.update(user);
      });
    jwtTokenStream.listen((_) {});
    Future.delayed(
      const Duration(milliseconds: 3000),
      () => _appStateNotifier.stopShowingSplashImage(),
    );
  }

  @override
  void dispose() {
    authUserSub.cancel();

    super.dispose();
  }

  void setLocale(String language) {
    safeSetState(() => _locale = createLocale(language));
    FFLocalizations.storeLocale(language);
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Pipe Buyer',
      scrollBehavior: MyAppScrollBehavior(),
      localizationsDelegates: const [
        FFLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
      ],
      locale: _locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('ur'),
        Locale('hi'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        Locale('af'),
        Locale('es'),
        Locale('fr'),
        Locale('de'),
        Locale('da'),
        Locale('it'),
        Locale('sv'),
        Locale('tr'),
        Locale('nl'),
        Locale('ja'),
      ],
      theme: PipeAccessibilityTheme.apply(ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
      )),
      darkTheme: PipeAccessibilityTheme.apply(ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
      )),
      themeMode: _themeMode,
      builder: (context, child) => PipeAccessibilityRoot(
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: _router,
    );
  }
}
