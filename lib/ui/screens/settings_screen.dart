import 'package:material_ui/material_ui.dart';

import '../app_scope.dart';
import 'pin_flow.dart';

/// Ajustes: tema, seguridad y datos.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Stream<ThemeMode>? _themeMode;
  Future<(int, int)>? _counts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _themeMode ??= AppScope.of(context).settings.watchThemeMode();
    _counts ??= _loadCounts();
  }

  Future<(int, int)> _loadCounts() async {
    final habits = AppScope.of(context).habits;
    return (await habits.countHabits(), await habits.countCheckIns());
  }

  Future<void> _confirmWipe() async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('¿Borrar todos los hábitos?'),
        content: const Text('Se eliminarán tus hábitos y su historial. Tu PIN se conserva.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await scope.habits.deleteAll();
    if (!mounted) return;
    setState(() => _counts = _loadCounts());
    messenger.showSnackBar(const SnackBar(content: Text('Se borraron todos los hábitos')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scope = AppScope.of(context);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          header('Apariencia'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tema', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  StreamBuilder<ThemeMode>(
                    stream: _themeMode,
                    builder: (context, snapshot) => SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_rounded),
                            label: Text('Sistema'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded),
                            label: Text('Claro'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded),
                            label: Text('Oscuro'),
                          ),
                        ],
                        selected: {snapshot.data ?? ThemeMode.system},
                        showSelectedIcon: false,
                        onSelectionChanged: (value) => scope.settings.setThemeMode(value.first),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          header('Seguridad'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.password_rounded),
                  title: const Text('Cambiar PIN'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const ChangePinScreen())),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Bloquear ahora'),
                  subtitle: const Text('La app también se bloquea tras 30 s en segundo plano'),
                  onTap: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    scope.lockNow();
                  },
                ),
              ],
            ),
          ),
          header('Datos'),
          Card(
            child: Column(
              children: [
                FutureBuilder<(int, int)>(
                  future: _counts,
                  builder: (context, snapshot) {
                    final (habits, checkIns) = snapshot.data ?? (0, 0);
                    return ListTile(
                      leading: const Icon(Icons.storage_rounded),
                      title: const Text('Base de datos local (SQLite)'),
                      subtitle: Text(
                        '$habits hábitos · $checkIns registros guardados en este dispositivo',
                      ),
                    );
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: scheme.error),
                  title: Text('Borrar todos los hábitos', style: TextStyle(color: scheme.error)),
                  onTap: _confirmWipe,
                ),
              ],
            ),
          ),
          header('Acerca de'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.spa_rounded),
              title: Text('Mis hábitos 1.0.0'),
              subtitle: Text('Equipo 5 · Flutter + SQLite (drift)'),
            ),
          ),
        ],
      ),
    );
  }
}
