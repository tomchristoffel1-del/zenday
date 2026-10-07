import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'accent_options.dart';
import 'app_settings.dart';
import 'onboarding_screen.dart';
import 'planner_screen.dart';
import 'storage.dart';
import 'sync/sync_service.dart';
import 'theme.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Uncaught Flutter error: ${details.exceptionAsString()}');
    };
    await initializeDateFormatting('de_DE', null);
    await SyncService.instance.init();
    await AppSettings.load(ZenStorage());
    runApp(const ZenDayApp());
  }, (error, stack) {
    // Ein einzelner unerwarteter Fehler darf ZenDay nie komplett beenden.
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

class ZenDayApp extends StatelessWidget {
  const ZenDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<int>(
          valueListenable: AppSettings.accentIndex,
          builder: (context, accentIdx, _) {
            final accent = accentOptions[accentIdx];
            return MaterialApp(
              title: 'ZenDay',
              debugShowCheckedModeBanner: false,
              theme: buildZenTheme(ZenColors.light.copyWith(accent: accent.light), Brightness.light),
              darkTheme: buildZenTheme(ZenColors.dark.copyWith(accent: accent.dark), Brightness.dark),
              themeMode: mode,
              home: const _RootRouter(),
            );
          },
        );
      },
    );
  }
}

class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  final _storage = ZenStorage();
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    _checkOnboarded();
    SyncService.instance.revision.addListener(_checkOnboarded);
  }

  @override
  void dispose() {
    SyncService.instance.revision.removeListener(_checkOnboarded);
    super.dispose();
  }

  /// Kommen beim ersten Abgleich bereits eingerichtete Daten aus der Cloud,
  /// wechselt die App vom Onboarding direkt zum Planer.
  Future<void> _checkOnboarded() async {
    final done = await _storage.isOnboarded();
    if (!mounted) return;
    if (_onboarded == null || (_onboarded == false && done)) setState(() => _onboarded = done);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboarded == null) {
      final colors = Theme.of(context).extension<ZenTheme>()!.colors;
      return Scaffold(backgroundColor: colors.background);
    }
    if (_onboarded == false) {
      return OnboardingScreen(onDone: () => setState(() => _onboarded = true));
    }
    return const PlannerScreen();
  }
}
