import 'package:material_ui/material_ui.dart';

import 'core/theme.dart';
import 'data/habit_repository.dart';
import 'data/settings_repository.dart';
import 'ui/app_scope.dart';
import 'ui/screens/habits_screen.dart';
import 'ui/screens/pin_flow.dart';

class MisHabitosApp extends StatefulWidget {
  const MisHabitosApp({
    super.key,
    required this.habits,
    required this.settings,
    this.lockAfter = const Duration(seconds: 30),
  });

  final HabitRepository habits;
  final SettingsRepository settings;

  /// Tiempo en segundo plano tras el cual se vuelve a pedir el PIN.
  final Duration lockAfter;

  @override
  State<MisHabitosApp> createState() => _MisHabitosAppState();
}

class _MisHabitosAppState extends State<MisHabitosApp> {
  bool _locked = true;
  DateTime? _hiddenAt;
  late final AppLifecycleListener _lifecycle;
  late final Stream<ThemeMode> _themeMode = widget.settings.watchThemeMode();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _hiddenAt = DateTime.now(),
      onShow: () {
        final hiddenAt = _hiddenAt;
        _hiddenAt = null;
        if (hiddenAt != null && DateTime.now().difference(hiddenAt) >= widget.lockAfter) {
          _lock();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _lock() => setState(() => _locked = true);

  @override
  Widget build(BuildContext context) {
    return AppScope(
      habits: widget.habits,
      settings: widget.settings,
      lockNow: _lock,
      child: StreamBuilder<ThemeMode>(
        stream: _themeMode,
        builder: (context, snapshot) => MaterialApp(
          title: 'Mis hábitos',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: snapshot.data ?? ThemeMode.system,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const HabitsScreen(),
          // La pantalla de PIN se dibuja encima de todo el navegador, así
          // cubre cualquier pantalla abierta cuando la app se bloquea.
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              ExcludeFocus(
                excluding: _locked,
                child: ExcludeSemantics(excluding: _locked, child: child!),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _locked
                    ? LockScreen(
                        key: const ValueKey('lock'),
                        onUnlocked: () => setState(() => _locked = false),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
