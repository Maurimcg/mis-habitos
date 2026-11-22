import 'package:material_ui/material_ui.dart';

import '../core/dates.dart';
import '../data/habit_repository.dart';
import '../domain/habit_stats.dart';
import 'app_scope.dart';

/// Marca/desmarca un día y avisa si con eso se cumplió la meta semanal.
Future<void> toggleDay(BuildContext context, HabitWithDays item, DateTime day) async {
  final repo = AppScope.of(context).habits;
  final messenger = ScaffoldMessenger.of(context);
  final today = dateOnly(DateTime.now());
  final before = HabitStats.compute(
    days: item.days,
    goal: item.habit.weeklyGoal,
    createdAt: item.habit.createdAt,
    today: today,
  );

  final nowDone = await repo.toggleDay(item.habit.id, day);
  final sameWeek = isSameDay(startOfWeek(day), startOfWeek(today));
  if (nowDone && sameWeek && !before.goalMet && before.weekCount + 1 >= item.habit.weeklyGoal) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('¡Meta semanal cumplida en «${item.habit.name}»!')));
  }
}

/// Acción del botón "+1": registra hoy, o lo quita ofreciendo deshacer.
Future<void> plusOne(BuildContext context, HabitWithDays item) async {
  final today = dateOnly(DateTime.now());
  if (!item.days.contains(dayKey(today))) {
    await toggleDay(context, item, today);
    return;
  }
  final repo = AppScope.of(context).habits;
  final messenger = ScaffoldMessenger.of(context);
  await repo.setDay(item.habit.id, today, done: false);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Se quitó el registro de hoy en «${item.habit.name}»'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => repo.setDay(item.habit.id, today, done: true),
        ),
      ),
    );
}
