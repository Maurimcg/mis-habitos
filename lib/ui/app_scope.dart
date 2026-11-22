import 'package:material_ui/material_ui.dart';

import '../data/habit_repository.dart';
import '../data/settings_repository.dart';

/// Pone los repositorios al alcance de cualquier pantalla con
/// `AppScope.of(context)`, sin variables globales.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.habits,
    required this.settings,
    required this.lockNow,
    required super.child,
  });

  final HabitRepository habits;
  final SettingsRepository settings;

  /// Muestra de nuevo la pantalla de PIN.
  final VoidCallback lockNow;

  static AppScope of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No hay un AppScope en el árbol de widgets');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      habits != oldWidget.habits || settings != oldWidget.settings;
}
