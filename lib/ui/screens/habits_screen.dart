import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/habit_icons.dart';
import '../../core/theme.dart';
import '../../data/habit_repository.dart';
import '../../domain/habit_stats.dart';
import '../app_scope.dart';
import '../habit_actions.dart';
import '../widgets/habit_widgets.dart';
import 'habit_detail_screen.dart';
import 'habit_form_screen.dart';
import 'settings_screen.dart';

/// Pantalla 2: lista de hábitos con el progreso de la semana.
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  Stream<List<HabitWithDays>>? _habits;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _habits ??= AppScope.of(context).habits.watchAll();
  }

  void _openForm() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HabitFormScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo hábito'),
      ),
      body: StreamBuilder<List<HabitWithDays>>(
        stream: _habits,
        builder: (context, snapshot) {
          final items = snapshot.data;
          return TodayBuilder(
            builder: (context, today) {
              final stats = {
                for (final item in items ?? const <HabitWithDays>[])
                  item.habit.id: HabitStats.compute(
                    days: item.days,
                    goal: item.habit.weeklyGoal,
                    createdAt: item.habit.createdAt,
                    today: today,
                  ),
              };
              return CustomScrollView(
                slivers: [
                  SliverSafeArea(
                    bottom: false,
                    sliver: SliverToBoxAdapter(child: _Header(today: today)),
                  ),
                  if (items == null)
                    const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                  else if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(onCreate: _openForm),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      sliver: SliverToBoxAdapter(
                        child: _SummaryCard(today: today, stats: stats.values.toList()),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Tus hábitos · ${items.length}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => HabitCard(
                          key: ValueKey(items[i].habit.id),
                          item: items[i],
                          stats: stats[items[i].habit.id]!,
                          today: today,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateFormat("EEEE d 'de' MMMM", 'es').format(today);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date[0].toUpperCase() + date.substring(1),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Mis hábitos', style: theme.textTheme.headlineMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Bloquear',
            onPressed: AppScope.of(context).lockNow,
            icon: const Icon(Icons.lock_outline_rounded),
          ),
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}

/// Resumen de la semana: cuántas metas se han cumplido y avance general.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.today, required this.stats});

  final DateTime today;
  final List<HabitStats> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final met = stats.where((s) => s.goalMet).length;
    final doneToday = stats.where((s) => s.doneToday).length;
    final totalGoal = stats.fold<int>(0, (sum, s) => sum + s.goal);
    final progress = totalGoal == 0
        ? 0.0
        : stats.fold<int>(0, (sum, s) => sum + s.weekCount.clamp(0, s.goal)) / totalGoal;
    final week = daysOfWeek(today);
    final range = DateFormat('d MMM', 'es');
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? scheme.primaryContainer : scheme.primary;
    final onCard = isDark ? scheme.onPrimaryContainer : scheme.onPrimary;

    Widget bubble(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: onCard.withValues(alpha: 0.07)),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? 0.12 : 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Círculos decorativos.
          Positioned(right: -40, top: -50, child: bubble(160)),
          Positioned(right: 50, bottom: -70, child: bubble(120)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _summaryRow(theme, onCard, progress, met, doneToday, week, range),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    ThemeData theme,
    Color onCard,
    double progress,
    int met,
    int doneToday,
    List<DateTime> week,
    DateFormat range,
  ) {
    return Row(
      children: [
        SizedBox.square(
          dimension: 84,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  color: onCard,
                  backgroundColor: onCard.withValues(alpha: 0.22),
                ),
              ),
              Center(
                child: Text(
                  '${(progress * 100).round()}%',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: onCard,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta semana · ${range.format(week.first)} – ${range.format(week.last)}',
                style: theme.textTheme.labelMedium?.copyWith(color: onCard.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 4),
              Text(
                '$met de ${stats.length} ${stats.length == 1 ? 'meta cumplida' : 'metas cumplidas'}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: onCard,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: onCard.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Hoy: $doneToday de ${stats.length} hechos',
                  style: theme.textTheme.labelMedium?.copyWith(color: onCard),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de un hábito en la lista.
class HabitCard extends StatelessWidget {
  const HabitCard({super.key, required this.item, required this.stats, required this.today});

  final HabitWithDays item;
  final HabitStats stats;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = HabitColors.of(context);
    final habit = item.habit;
    final color = colors.color(habit.colorIndex);
    final onColor = colors.onColor(habit.colorIndex);

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => HabitDetailScreen(habitId: habit.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            children: [
              Row(
                children: [
                  HabitAvatar(
                    icon: habitIcon(habit.icon),
                    color: color,
                    progress: stats.weekProgress,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          children: [
                            GoalProgressText(count: stats.weekCount, goal: stats.goal),
                            if (stats.currentStreak > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_fire_department_rounded, size: 16, color: color),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${stats.currentStreak} sem',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PlusOneButton(
                    done: stats.doneToday,
                    color: color,
                    onColor: onColor,
                    onPressed: () => plusOne(context, item),
                  ),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.spa_rounded, size: 52, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 24),
          Text(
            'Empieza con un hábito',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Elige algo pequeño y cuántos días a la semana quieres hacerlo. '
            'Cada día que lo cumplas, toca +1.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear mi primer hábito'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => AppScope.of(context).habits.seedDemoData(),
            child: const Text('Cargar hábitos de ejemplo'),
          ),
        ],
      ),
    );
  }
}
