import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../../core/habit_icons.dart';
import '../../core/theme.dart';
import '../../data/habit_repository.dart';
import '../../domain/habit_stats.dart';
import '../app_scope.dart';
import '../habit_actions.dart';
import '../widgets/habit_widgets.dart';
import '../widgets/stats_widgets.dart';
import 'habit_form_screen.dart';

/// Detalle de un hábito: estadísticas, gráfica semanal e historial.
class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final int habitId;

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  Stream<HabitWithDays?>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= AppScope.of(context).habits.watchOne(widget.habitId);
  }

  Future<void> _confirmDelete(HabitWithDays item) async {
    final repo = AppScope.of(context).habits;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text('¿Eliminar «${item.habit.name}»?'),
        content: Text(
          'También se borrarán sus ${item.days.length} registros. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    navigator.pop();
    await repo.delete(item.habit.id);
    messenger.showSnackBar(SnackBar(content: Text('Se eliminó «${item.habit.name}»')));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HabitWithDays?>(
      stream: _stream,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: snapshot.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : const Center(child: Text('Este hábito ya no existe')),
          );
        }
        return TodayBuilder(builder: (context, today) => _buildContent(context, item, today));
      },
    );
  }

  Widget _buildContent(BuildContext context, HabitWithDays item, DateTime today) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = HabitColors.of(context);
    final habit = item.habit;
    final color = colors.color(habit.colorIndex);
    final onColor = colors.onColor(habit.colorIndex);
    final stats = HabitStats.compute(
      days: item.days,
      goal: habit.weeklyGoal,
      createdAt: habit.createdAt,
      today: today,
    );
    final rate = stats.completionRate;
    String weeks(int n) => n == 1 ? 'semana' : 'semanas';

    Widget section(String title, Widget child) => Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => HabitFormScreen(habit: habit))),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _confirmDelete(item),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              HabitAvatar(
                icon: habitIcon(habit.icon),
                color: color,
                progress: stats.weekProgress,
                size: 76,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.name, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Meta: ${habit.weeklyGoal} ${habit.weeklyGoal == 1 ? 'día' : 'días'} por semana',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    Text(
                      'Desde el ${DateFormat("d 'de' MMMM 'de' y", 'es').format(habit.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Esta semana', style: theme.textTheme.titleSmall)),
                      GoalProgressText(count: stats.weekCount, goal: stats.goal),
                    ],
                  ),
                  const SizedBox(height: 14),
                  WeekDots(
                    days: item.days,
                    today: today,
                    color: color,
                    onColor: onColor,
                    onToggle: (day) => toggleDay(context, item, day),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 116,
            ),
            children: [
              StatTile(
                icon: Icons.local_fire_department_rounded,
                color: color,
                label: 'Racha actual',
                value: '${stats.currentStreak}',
                unit: weeks(stats.currentStreak),
                caption: 'cumpliendo la meta',
              ),
              StatTile(
                icon: Icons.emoji_events_rounded,
                color: color,
                label: 'Mejor racha',
                value: '${stats.bestStreak}',
                unit: weeks(stats.bestStreak),
              ),
              StatTile(
                icon: Icons.event_available_rounded,
                color: color,
                label: 'Días registrados',
                value: '${stats.totalDays}',
                unit: stats.totalDays == 1 ? 'día' : 'días',
              ),
              StatTile(
                icon: Icons.insights_rounded,
                color: color,
                label: 'Semanas cumplidas',
                value: rate == null ? '—' : '${(rate * 100).round()} %',
                caption: rate == null
                    ? 'aún sin semanas completas'
                    : '${stats.weeksMet} de ${stats.weeksConsidered}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          section(
            'Últimas 8 semanas',
            WeeklyBarChart(weeks: stats.lastWeeks(8), goal: habit.weeklyGoal, color: color),
          ),
          const SizedBox(height: 12),
          section(
            'Historial',
            HistoryHeatmap(
              days: item.days,
              today: today,
              color: color,
              createdAt: habit.createdAt,
              onToggle: (day) => toggleDay(context, item, day),
            ),
          ),
        ],
      ),
    );
  }
}
